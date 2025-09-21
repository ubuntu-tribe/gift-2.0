This section is a precise, engineering-grade description of the complete GIFT system on chain: the fungible token, the supply controller, the proof-of-reserve ledger, the provenance registry with Merkle roots, and the contract for on-chain **non-fungible gold bars**. Every function is documented with its purpose, access control, and effects so auditors, integrators, and regulators can understand exactly what moves state and why.

---

## 1) `GIFT` ;  ERC-20, UUPS-upgradeable, pausable, role-locked mint/burn

**Purpose.** GIFT is the fungible unit representing fine gold at ERC-20 precision. It is upgradeable via UUPS, pausable for incident response, and its mint/burn functions are locked to a single **Supply Controller** (the Minting proxy). Transfers optionally route through a policy module (“tax manager”) for tiered fees.

**Key inheritance.** `Initializable`, `ERC20Upgradeable`, `PausableUpgradeable`, `OwnableUpgradeable`, `UUPSUpgradeable`.

**Storage (selected).**
`supplyController`, `supplyManager` (optional operational role); `reserveFeed` (aggregator pointer, not used in the mint path); `taxManager` (external policy contract); `isManager` (delegated transfer operators); `nonces` (per-delegator).

**Events.** `NewSupplyController`, `NewSupplyManager`, `TaxManagerUpdated`, `DelegateTransfer`, `ManagerUpdated`.

### Initialization

```solidity
function initialize(
  address _aggregatorInterface,
  address _initialHolder, // reserved; not used
  address _taxManager
) public reinitializer(2)
```

Sets token name/symbol, owner, UUPS, pause, aggregator pointer, and tax manager. The owner is the deployer of the implementation when called through the proxy initializer. This is versioned `reinitializer(2)` to support safe re-inits.

### Role setters

```solidity
function setSupplyController(address _newSupplyController) external onlyOwner
```

Defines the **only** address allowed to call `increaseSupply` and `redeemGold`. In production this is the Minting proxy.

```solidity
function setSupplyManager(address _newSupplyManager) external onlyOwner
```

Defines an optional operational minter for `inflateSupply` (see below). If your policy forbids this path, set it to the zero address and do not call `inflateSupply`.

```solidity
function setManager(address _manager, bool _isManager) external onlyOwner
```

Grants or revokes the delegated-transfer **operator** role (used by `delegateTransfer`).

```solidity
function setTaxManager(address _newTaxManager) external onlyOwner
```

Points GIFT to a policy contract responsible for fee tiers, LP exemptions, exclusions, and beneficiary address.

### Mint & burn

```solidity
function increaseSupply(address _userAddress, uint256 _value)
  external onlySupplyController returns (bool)
```

Mints `_value` to `_userAddress`. This is the normal issuance path used by the Minting contract after PoR and Registry checks pass.

```solidity
function redeemGold(address _userAddress, uint256 _value)
  external onlySupplyController returns (bool)
```

Burns `_value` from `_userAddress`. Used for redemptions, cancellations, or corrections under governance control.

```solidity
function inflateSupply(uint256 _value)
  external onlySupplyManager returns (bool)
```

Optional operational mint to `supplyManager` itself. If not part of policy, keep `supplyManager` unset to render this unreachable.

### Pause controls

```solidity
function pause() external onlyOwner
function unpause() external onlyOwner
```

Halts / resumes transfers and delegated transfers. Mint/burn remain role-gated regardless.

### Transfers and fee pipeline

```solidity
function transfer(address recipient, uint256 amount)
  public override whenNotPaused returns (bool)

function transferFrom(address sender, address recipient, uint256 amount)
  public override whenNotPaused returns (bool)
```

Both route to `_transferGIFT`, which calculates outbound and inbound fees and forwards them to `taxManager.beneficiary()` unless a side is excluded or the counterparty is a designated liquidity pool.

```solidity
function _transferGIFT(address sender, address recipient, uint256 amount)
  internal returns (bool)
```

Fee logic in words:

* If the **sender** is not excluded **and** the **recipient** is not an LP, an **outbound** fee is computed on `amount` and transferred to the beneficiary.
* If the **recipient** is not excluded **and** the **sender** is not an LP, an **inbound** fee is computed on the **remaining** amount and transferred to the beneficiary.
* The final remainder transfers to `recipient`.

Fees use fixed-point percentages with a denominator of `100_000` (i.e., 100,000 = 100%). Tier edges are read from the tax manager.

### Delegated transfer (optional operator path)

```solidity
function delegateTransfer(
  bytes memory signature,
  address delegator,
  address recipient,
  uint256 amount,
  uint256 networkFee
) external whenNotPaused onlyManager returns (bool)
```

Allows a trusted **manager** to forward a transfer on behalf of `delegator`, authenticated by an ECDSA signature over:

```
keccak256(abi.encodePacked(
  this, delegator, recipient, amount, networkFee, nonces[delegator]++
))
```

Signature is verified with Ethereum Signed Message prefix. On success, the manager is paid `networkFee` from `delegator`, and the main transfer proceeds.

Helper for off-chain signers:

```solidity
function delegateTransferProof(
  bytes32 token, address delegator, address spender,
  uint256 amount, uint256 networkFee
) public view returns (bytes32)
```

Returns a compact digest you can mirror in your signing layer.

### Miscellaneous

```solidity
function getChainID() public view returns (uint256)
```

Low-level chain id fetch; used by off-chain tooling.

```solidity
function _authorizeUpgrade(address) internal override onlyOwner {}
```

Standard UUPS authorization hook.

---

## 2) `MintingUpgradeable` ;  the Supply Controller (UUPS)

**Purpose.** This contract is the **only** entity allowed to mint/burn in GIFT. It will not mint until **both** (a) the Proof-of-Reserve authorizes the operation and (b) the Registry verifies and consumes a Merkle leaf inside an active batch. Once `registryEnforced` is true, the legacy mint path is disabled.

**Key storage.** `giftpor` (PoR), `gift` (ERC-20), `registry` (Merkle batches), `registryEnforced` (bool), `allowedBatches` (gate which batches can be used).

**Events.** `RegistrySet`, `RegistryEnforced`, `BatchAllowed`, `TokensMinted`.

### Initialization & upgrades

```solidity
function initialize(address giftPoR_, address giftToken_, address registry_)
  public initializer
```

Wires PoR, GIFT, and Registry pointers. Owner is set here (recommend a multisig).
`_authorizeUpgrade(address)` is `onlyOwner`.

### Governance knobs

```solidity
function setRegistry(address registry_) external onlyOwner
function enforceRegistry(bool on) external onlyOwner
function allowBatch(uint256 batchId, bool on) external onlyOwner
```

These set the Registry, enable/disable proof enforcement globally, and restrict minting to an approved set of batches.

### The mint path with proofs

```solidity
function mintWithProof(
  address to,
  uint256 amount,
  GIFTBatchRegistry.LeafInput calldata leaf,
  bytes32[] calldata proof
) external
```

Execution flow:

1. Verifies caller is a PoR-approved **minter**.
2. Reads caller’s **allowance** for `leaf.reserveId` and checks PoR **vault balance** ≥ `amount`.
3. Requires `registryEnforced == true` and `allowedBatches[leaf.batchId] == true`.
4. Calls `registry.verifyLeaf(leaf, proof)` and `registry.consume(leaf, proof, amount, to)`.
5. Calls `gift.increaseSupply(to, amount)` ;  succeeds only because `MintingUpgradeable` is the GIFT **supply controller**.
6. Reduces PoR **allowance** and **vault balance** with `setMintingAllowance(...)` and `updateReserveAfterMint(...)`.
7. Emits `TokensMinted(to, amount, reserveId, batchId, leafHash)`.

Any failure along this path reverts, guaranteeing that supply, reserves, and provenance counters remain coherent.

### Temporary migration path (optional)

```solidity
function mint(address to, uint256 amount, uint256 reserveId) external
```

Available only if `registryEnforced == false`. Preserves your current mint flow until you turn proofs on.

### Burn and PoR wiring passthroughs

```solidity
function burnFrom(address account, uint256 amount) external
```

Burns through GIFT; restricted so only PoR **owner** can trigger (centralized authority consistent with custody operations).

```solidity
function updatePoR(address newPoR) external
function getAdmin() external view returns (address)
function changeAdmin(address newAdmin) external
```

Administrative helpers to keep the Minting proxy aligned with PoR ownership and address changes.

---

## 3) `GIFTBatchRegistry` ;  Merkle-anchored provenance, per-leaf caps

**Purpose.** Commits entire datasets of authorised bars/lots into a single on-chain **Merkle root** per batch, and prevents any leaf (or batch) from being over-consumed. It does not mint tokens; it only verifies proofs and updates consumption counters.

**Key storage.** A sequential `nextBatchId`; a mapping of `batchId => BatchMeta`; a mapping of `batchId => (leafHash => consumedAmount)`; a `minting` address that is the only actor allowed to `consume`.

**Events.** `BatchRegistered`, `BatchActivated`, `BatchFinalized`, `MintConsumed`, `LegacySupplyAcknowledged`.

### Batch metadata

```solidity
struct BatchMeta {
  bytes32 root;
  uint256 cap;           // sum(quantity) across all leaves
  uint256 minted;        // total consumed in this batch
  string  datasetURI;    // ipfs://... or https://... for dataset.json + proofs.json
  bytes32 schemaHash;    // keccak256(schema descriptor)
  bool    active;
  bool    finalized;
  bool    isLegacy;
  uint64  createdAt;
  address createdBy;
}
```

### Leaf schema and hashing

```solidity
struct LeafInput {
  uint256 batchId;
  uint256 reserveId;
  uint256 quantity;        // token smallest units authorised by this leaf
  uint256 fineWeightMg;    // physical fine weight in mg
  bytes32 serialHash;
  bytes32 mineHash;
  bytes32 barStandardHash;
  bytes32 docHash;
  uint256 mintedAtISO;     // or 0
  uint256 presenceMask;    // bits signal which optional fields are present
}
```

Leaf hash is:

```
keccak256(abi.encode(
  LEAF_TYPEHASH, address(this), batchId, reserveId, quantity, fineWeightMg,
  serialHash, mineHash, barStandardHash, docHash, mintedAtISO, presenceMask
))
```

All fields are **static types** and in a fixed order. Unknown strings are `keccak256("UNKNOWN")` with the corresponding bit **unset** in `presenceMask`.

### Administrative functions

```solidity
function setMinting(address m) external onlyOwner
```

Defines the single Supply Controller contract allowed to call `consume`.

```solidity
function registerBatch(
  bytes32 root,
  uint256 cap,
  string calldata datasetURI,
  bytes32 schemaHash,
  bool active
) external onlyOwner returns (uint256 batchId)
```

Creates a new batch, assigns the root and cap, records the dataset URI and schema hash, sets it active if requested, and returns `batchId`.

```solidity
function finalizeBatch(uint256 batchId) external onlyOwner
```

Marks a batch as inactive and finalized. Finalized batches cannot be consumed any further.

```solidity
function acknowledgeLegacySupply(
  uint256 amount, string calldata reason,
  string calldata datasetURI, bytes32 docHash
) external onlyOwner returns (uint256 batchId)
```

One-time accounting entry for historic circulation. Sets `minted = cap = amount`, `isLegacy = true`, and `finalized = true`.

### Views

```solidity
function getBatchMeta(uint256 batchId) external view returns (BatchMeta memory)
function leafConsumed(uint256 batchId, bytes32 leafHash) external view returns (uint256)
```

These expose batch headers and per-leaf consumption counters for indexers and bar-certificate capacity checks.

```solidity
function verifyLeaf(LeafInput calldata d, bytes32[] calldata proof)
  external view returns (bytes32 leafHash, bool ok)
```

Recomputes the leaf hash from `d` and verifies the path.

### Consumption (called by Minting only)

```solidity
function consume(
  LeafInput calldata d,
  bytes32[] calldata proof,
  uint256 amount,
  address to
) external
```

Requires `msg.sender == minting`, then:

1. Checks batch is `active` and not `finalized`.
2. Verifies Merkle proof for the leaf.
3. Ensures `consumed[batchId][leafHash] + amount ≤ d.quantity` and `batches[batchId].minted + amount ≤ cap`.
4. Increments both counters and emits `MintConsumed`.

---

## 4) `GIFTPoR` ;  Proof-of-Reserve ledger for vaults, allowances, and auditors

**Purpose.** Models vaults and balances in token units, grants minters per-vault allowances, and exposes auditor/admin controls for supply movements and vault management. The Minting contract reads from and updates this ledger on each issuance.

**Key inheritance.** `Initializable`, `UUPSUpgradeable`, `OwnableUpgradeable`.

**Roles.** `onlyOwner` (grant roles), `onlyAdmin` (manage minters/allowances and authorize upgrades), `onlyAuditor` (move/adjust vault balances), `onlyMinter` (reduce balances after mint).

**Core state.**
`Vault` registry by id; `GIFT_reserve` (global running total); `minterReserves` (which vault ids a minter may touch); `mintAllowances[minter][reserveId]` (remaining capacity); mappings of role flags.

**Selected events.** `VaultCreated`, `VaultUpdated`, `VaultUpdatedaftermint`, `MoveSupply`, `SetMintAllowance`, role add/remove events, `PhysicalVaultSupplyAdded/Removed`, `UpdateReserve`.

### Initialization & upgrades

```solidity
function initialize() public initializer
```

Sets msg.sender as owner/admin/auditor/minter and initializes `nextVaultId = 1`.

```solidity
function _authorizeUpgrade(address) internal override onlyAdmin {}
```

Upgrades require admin.

### Role administration

```solidity
function addAuditor(address _auditor) external onlyOwner
function removeAuditor(address _auditor) external onlyOwner
function addAdmin(address _admin) external onlyOwner
function removeAdmin(address _admin) external onlyOwner
function addMinter(address minter) public onlyAdmin
function removeMinter(address minter) public onlyAdmin
```

Grants or revokes roles.

### Vault lifecycle

```solidity
function addVault(string memory _name) public onlyAdmin
```

Creates a new vault with a sequential id, and mirrors a “physical reserve” entry maintaining a separate physical figure.

```solidity
function getReserveState(uint256 _vaultId)
  public view returns (string memory reserveName, uint256 reserveId, uint256 balance)
```

Reads vault header and token balance.

```solidity
function updateVault(uint256 _vaultId, uint256 _amountAdded, string memory comment)
  public onlyAuditor
```

Increases a vault’s token balance and the global `GIFT_reserve`. Mirrors into the physical ledger as well.

```solidity
function SupplyGold(uint256 vaultId, uint256 amount, string memory comment) public onlyAuditor
function RedeemGold(uint256 vaultId, uint256 amount, string memory comment) public onlyAuditor
```

Adjust the **physical** ledger for inbound or outbound bar movements with comments. These do not mint/burn ERC-20 by themselves; they are the physical custody book.

```solidity
function moveSupply(uint256 fromVaultId, uint256 toVaultId, uint256 amount, string memory comment)
  external onlyAuditor
```

Moves balances between vaults in both token and physical ledgers.

### Global views

```solidity
function getTotalReserves() public view returns (uint256 totalReserves, uint256 totalAmount)
function retrieveReserve() public view returns (uint256)
```

Supply totals for dashboards and attestations.

### Minters and allowances

```solidity
function setMintingAllowance(address minter, uint256 reserveId, uint256 allowance)
  external onlyAdmin
```

Creates or updates a minter’s allowance for a given vault id. On first assignment, the reserve id is added to that minter’s list.

```solidity
function getMinterReservesAndAllowances(address minter)
  public view returns (ReserveAllowance[] memory)
```

Enumerates a minter’s assigned reserve ids and current allowances.

```solidity
function isMinter(address account) public view returns (bool)
```

Simple role flag.

```solidity
function updateReserveAfterMint(uint256 _vaultId, uint256 _amount)
  external onlyMinter
```

Reduces a vault’s token balance immediately after an ERC-20 mint. This is called by the Minting proxy once the token issuance succeeds.

---

## 5) `GIFTBarNFTDeferred` ;  on-chain **non-fungible gold bars** with per-leaf capacity

**Purpose.** Issues on-chain **non-fungible gold bars** later, at the operator’s discretion, referencing the same Merkle leaves that backed ERC-20 issuance. Each certificate represents a fixed physical unit (e.g., 1 kg, 100 g, 1 g), and capacity is capped by the leaf’s fine weight and, optionally, by the actual amount of ERC-20 consumed from that leaf.

**Key storage.** Pointer to the Registry; a global `unitMg` (default 1,000,000 mg = 1 kg); `CapacityMode` (either `LEAF_MAX` or `STRICT_CONSUMED`); a per-key counter `unitsMinted[ keccak256(batchId, leafHash) ]`; a `nextId`; and metadata base URI.

**Events.** `BarsMinted`, `UnitMgSet`, `BaseURISet`, `CapacityModeSet`.

### Administration

```solidity
constructor(address registry_) ERC721("GIFT Gold Bar", "GIFTBAR")
function setUnitMg(uint256 mg) external onlyOwner
function setBaseURI(string calldata uri) external onlyOwner
function setCapacityMode(CapacityMode mode) external onlyOwner
```

Choose the physical unit for each certificate, the metadata base URI, and the capacity policy.

### Views

```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory)
```

Typically forms: `{baseURI}/{batchId}/{leafHash}/{tokenId}.json`.

```solidity
function remainingUnits(
  IGIFTBatchRegistry.LeafInput calldata leaf, bytes32[] calldata proof
) external view returns (bytes32 leafHash, uint256 unitsLeft)
```

Verifies the leaf and returns how many certificates of size `unitMg` remain under the current capacity policy.

### Issuance of bar certificates

```solidity
function mintBarsFromLeaf(
  address to,
  uint256 units,
  IGIFTBatchRegistry.LeafInput calldata leaf,
  bytes32[] calldata proof
) external nonReentrant onlyOwner
```

Verifies the leaf, computes capacity:

* In **LEAF\_MAX** mode: `floor(fineWeightMg / unitMg)`.
* In **STRICT\_CONSUMED** mode: `floor( (consumedSmallest * fineWeightMg / leaf.quantity) / unitMg )`, using `registry.leafConsumed(batchId, leafHash)`.

Then mints `units` certificates to `to`, each recorded with `{batchId, leafHash, reserveId, unitMg, serialHash, ...}`. Capacity can never be exceeded.

---

## 6) `GIFTTaxManager` ;  external policy module (interface expectations)

**Purpose.** Encapsulates transfer fee policy and liquidity pool detection for GIFT. This contract is **not** part of the critical mint path; it only influences **transfers**.

**Functions GIFT expects to call.**

```solidity
function getTaxTiers()
  external view returns (uint256 tierOneMax, uint256 tierTwoMax, uint256 tierThreeMax, uint256 tierFourMax)

function getTaxPercentages()
  external view returns (
    uint256 tierOneTax, uint256 tierTwoTax, uint256 tierThreeTax,
    uint256 tierFourTax, uint256 tierFiveTax
  )

function isExcludedFromOutboundFees(address account) external view returns (bool)
function isExcludedFromInboundFees(address account) external view returns (bool)
function _isLiquidityPool(address account) external view returns (bool)
function beneficiary() external view returns (address)
```

Percentages are fixed-point with denominator `100_000`. The manager defines tier thresholds and the per-tier fee figures. It also identifies LP addresses and exclusion lists so that routing and P2P transfers can be treated differently. The beneficiary receives collected fees.

---

## Cross-contract flow and invariants

When `registryEnforced` is enabled, a single issuance touches **three ledgers** atomically:

1. **Registry** verifies a Merkle proof and increments `leafConsumed` and `batch.minted`.
2. **GIFT** mints the exact amount through its **supply controller** (the Minting proxy).
3. **PoR** reduces the per-minter **allowance** and the vault **balance** for `reserveId`.

The invariants that must always hold are straightforward to verify on chain:

* For **each batch**: `minted ≤ cap`.
* For **each leaf**: `consumed ≤ quantity`.
* For the **system**: circulating supply cannot outrun PoR balances once proofs are enforced.

Bar certificates draw from the same Merkle leaves and enforce a physical cap derived from `fineWeightMg` (and optionally the exact ERC-20 consumed against the leaf), ensuring that on-chain, non-fungible gold bars never exceed the underlying metal.

---

## Upgradeability, pausing, and governance posture

GIFT and the Supply Controller are UUPS-upgradeable with `onlyOwner` authorization. We recommend a multisig owner, staged rollouts, and rehearsed pause/resume drills. The token can be **paused** to halt transfers during incidents; the supply path is always role-gated and anchored by the PoR and Registry even when unpaused.

---

**Development**
Kassy Olisakwe - Utribe.one
For queries or inquiries, contact kassy@utribe.one