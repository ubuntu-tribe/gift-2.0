## GIFT 2.0 – Cross-Chain Gold Token Contracts

This repo contains the **on‑chain and program code** for the GIFT 2.0 system:

- **Polygon (canonical chain)** – ERC‑20 token, Proof‑of‑Reserve ledger, Merkle registry, minting engine,
  NFTs for physical bars, redemption escrow, pooled bridge, and an EU transfer‑agent.
- **Solana (bridge side)** – Anchor program `gift_bridge_solana` that mints/burns the bridged asset `GIFT_SOL`
  in sync with GIFT locked/unlocked on Polygon.
- **Scripts + IDL** – TypeScript helpers and Anchor IDL for localnet/devnet deployment and testing.

You can think of this as the **backend of the gold system**: all stateful actions that move balances,
prove reserves, or mint/burn across chains are in this repo.

---

## High‑level system overview

- **1 GIFT = 1 mg of gold.**
- **Polygon** is the **canonical chain** for:
  - GIFT ERC‑20 token (`contracts/polygon/GIFT.sol`)
  - Proof‑of‑Reserve (`GIFTPoR`)
  - Merkle‑based provenance registry (`GIFTBatchRegistry`)
  - Minting engine (`MintingUpgradeable`)
  - NFTs representing bars (`GIFTBarNFTDeferred`)
  - Escrow‑backed physical redemption (`GiftRedemptionEscrowUpgradeable`)
  - Pooled bridge to Solana (`GiftPolygonBridge`)
  - EU transfer agent for compliance flows (`Europe/EUTransferAgent.sol`)
- **Solana** hosts `GIFT_SOL`, a **bridged representation** of GIFT:
  - Fully backed by GIFT locked in `GiftPolygonBridge` on Polygon.
  - Minted/burned by the `gift_bridge_solana` Anchor program.
  - Used for DeFi and ecosystem activities; physical redemption always routes back through Polygon.

### Polygon: core contracts

All Polygon contracts live in a Foundry project under `contracts/polygon/`:

- **`GIFT.sol`** – Upgradeable ERC‑20 token (18 decimals, 1 GIFT = 1 mg):
  - Roles:
    - `supplyController`: can `increaseSupply` and `redeemGold` (burn).
    - `supplyManager`: optional inflation role via `inflateSupply`.
  - Applies **tiered outbound transfer taxes** via `GIFTTaxManager` and supports delegated transfers
    through signatures.

- **`GIFTPoR.sol`** – Proof‑of‑Reserve ledger:
  - Tracks **vaults**, **GIFT_reserve** totals, and **per‑minter allowances** per vault.
  - Roles: `auditors`, `admins`, `minters`.
  - Functions like `addVault`, `SupplyGold`, `RedeemGold`, `moveSupply`, `setMintingAllowance`,
    `getMinterReservesAndAllowances`, and `updateReserveAfterMint` enforce that **on‑chain supply
    cannot outrun physical reserves** once policy is active.

- **`GIFTBatchRegistry.sol`** (imported from `src/`):
  - Registry for **Merkle batches** that back minting.
  - Stores `BatchMeta` (root, cap, minted, dataset URI, schema hash, flags, timestamps).
  - Verifies Merkle leaves and ensures:
    - Per‑leaf consumption ≤ leaf’s `quantity`.
    - Per‑batch minted ≤ batch `cap`.
  - Only `MintingUpgradeable` may call `consume`.

- **`MintingUpgradeable.sol`** – canonical issuance engine:
  - Wires together:
    - `GIFTPoR` (reserves + minting allowances),
    - `GIFT` (ERC‑20),
    - `GIFTBatchRegistry` (Merkle proofs).
  - `mintWithProof()`:
    - Checks PoR minter role, allowance, and vault reserve.
    - Verifies and consumes a leaf in the registry.
    - Mints GIFT to `to` via `gift.increaseSupply`.
    - Updates PoR allowance and vault reserve.
  - `mint()` (legacy path) can be used when `registryEnforced == false`.
  - `burnFrom` and `burnEscrowBalance` burn via `GIFT.redeemGold`, used by PoR owner and the
    redemption escrow respectively.

- **`GIFTBarNFTDeferred.sol`** – ERC‑721 bar NFTs:
  - Each NFT represents a **fixed mg weight** (`unitMg`, default 1_000_000 mg = 1 kg).
  - Integrates with `GIFTBatchRegistry` to:
    - Verify leaves and capacity (`remainingUnits`).
    - Mint NFTs from a leaf via `mintBarsFromLeaf`.
  - Emits `BarsMinted` and supports metadata via `tokenURI`.
  - Owner (eventually the escrow contract) can `burn` tokens on redemption.

- **`GiftRedemptionEscrowUpgradeable.sol`** – GIFT‑backed redemption escrow:
  - Whitelists marketplaces that can call `lockGiftForNFT`:
    - Pulls GIFT from purchaser into escrow.
    - Binds amount to `(nftContract, tokenId)` via `EscrowRecord`.
  - Receives NFTs via `onERC721Received` to mark a **redemption request**.
  - `completeRedemption`:
    - Verifies escrow’s GIFT balance for that NFT.
    - Calls `minting.burnEscrowBalance` to burn GIFT from escrow’s balance.
    - Attempts to burn the NFT (`GIFTBarNFTDeferred.burn`), or locks it permanently if that fails.

- **`GiftPolygonBridge.sol`** – pooled bridge on Polygon:
  - Holds locked GIFT backing `GIFT_SOL` on Solana.
  - `depositToSolana(amount, solanaRecipient)`:
    - Pulls GIFT from the user into the bridge.
    - Emits `DepositedToSolana` with a nonce and Solana recipient.
  - `completeWithdrawalFromSolana(polygonRecipient, amount, solanaBurnTx)`:
    - `onlyRelayer`, marks `solanaBurnTx` as processed, and releases GIFT to the Polygon recipient.

- **`Europe/EUTransferAgent.sol`** – EU compliance transfer agent:
  - Push‑only relay over GIFT for region‑specific compliance:
    - Daily caps per address, SAR thresholds, and delayed/frozen transfers.
  - Roles:
    - `COMPLIANCE_ROLE`, `PAUSE_ROLE`, `JUDICIAL_ROLE`.
  - Maintains “tickets” for transfers and allows compliance/judicial actors
    to execute, freeze, unfreeze, or confiscate funds.

### Solana: bridge program and clients

- **`programs/gift_bridge_solana/src/lib.rs`** – Anchor program:
  - `initialize_config`:
    - Creates a `Config` PDA holding:
      - `admin` (relayer / governance),
      - `gift_mint` (the GIFT_SOL SPL mint),
      - `polygon_bridge` (GiftPolygonBridge address).
  - `add_minter` / `remove_minter`:
    - Admin‑managed list of extra authorized minters (e.g. backup multisigs).
  - `mint_from_polygon`:
    - Called by admin or an extra minter after a Polygon `depositToSolana`.
    - Mints `amount` GIFT_SOL to a recipient ATA using a PDA `mint_authority`.
    - Uses `ProcessedDeposit` PDA to prevent replay.
  - `burn_for_polygon`:
    - User burns GIFT_SOL from their token account.
    - Emits `BurnForPolygonEvent` with `polygon_recipient` for the relayer.

- **IDL (`idl/gift_bridge_solana.json`)**:
  - Describes all instructions (`initializeConfig`, `addMinter`, `removeMinter`,
    `mintFromPolygon`, `burnForPolygon`), accounts (`Config`, `ProcessedDeposit`),
    the `BurnForPolygonEvent`, and error codes.

- **TS scripts under `scripts/solana/`**:
  - `createGiftSolMint.ts`: creates the GIFT_SOL mint (18 decimals) and mints a test amount
    to the payer for devnet testing.
  - `deployBridgeProgram.ts`: derives the `config` PDA and calls `initializeConfig` on Solana.
  - `bridgeClient.ts`: uses the IDL to:
    - Derive `mint_authority` and `processed_deposit` PDAs.
    - Call `mintFromPolygon` with a test deposit ID to mint GIFT_SOL.
    - Call `burnForPolygon` to burn GIFT_SOL and emit `BurnForPolygonEvent`.

### Docs

- `docs/architecture/gift-crosschain-architecture.md` – end‑to‑end cross‑chain design and flows.
- `docs/architecture/redemption-flows.md` – detailed redemption and bar flows.
- `docs/complete-polygon-tests-for-gift-token.md` – human‑readable description of the full Polygon
  Foundry test suite (240 tests).
- `docs/architecture/The GIFT contract ecosystem.md` – deep, function‑by‑function design overview.

---

## Repository layout

- `contracts/polygon/` – **Foundry** project:
  - Core production contracts live directly in this folder.
  - Tests under `contracts/polygon/test/`.
  - Deps under `contracts/polygon/lib/`.
- `programs/gift_bridge_solana/` – **Anchor** program:
  - Rust code in `src/lib.rs`.
  - Program config in `Anchor.toml` and `Cargo.toml`.
- `scripts/solana/` – TS scripts for:
  - Creating the GIFT_SOL mint.
  - Initializing the Solana config.
  - Exercising `mintFromPolygon` / `burnForPolygon`.
- `idl/` – Anchor IDL JSON for the Solana bridge program.
- `docs/` – Protocol architecture and flow documentation.

---

## How to run Polygon tests (Foundry)

From the repo root:

```bash
cd contracts/polygon
forge test
```

This compiles the Polygon contracts and runs the full Foundry test suite (~240 tests) covering:

- GIFT token behavior, supply roles, pausing, tax wiring, and delegated transfers.
- Proof‑of‑Reserve roles, vault lifecycle, physical/digital updates, and allowances.
- GIFTBatchRegistry batch registration, Merkle proof verification, and consumption.
- Minting engine (with/without proofs), PoR integration, and burn paths.
- GIFTBarNFTDeferred NFT issuance, capacity modes, and burning.
- GiftRedemptionEscrowUpgradeable escrow flows and physical redemption.
- GiftPolygonBridge deposit/withdraw flows and replay‑protection.

---

## How to build the Solana program (Rust / Anchor)

From the repo root:

```bash
cargo build -p gift_bridge_solana
```

This compiles the `gift_bridge_solana` program using `anchor-lang = 0.30.1` and `anchor-spl = 0.30.1`.

> Note:
> - The installed `anchor-cli` version on your machine may be newer than `anchor-lang`. If you regenerate IDLs
>   with `anchor build`, ensure your CLI and `anchor-lang` versions are compatible (or pin via `[toolchain]`
>   in `Anchor.toml`).

---

## How to run Solana tests

Solana tests are implemented as **TypeScript integration tests** that talk to a local validator or
devnet using the Anchor TS client.

From the repo root:

```bash
npm install          # or pnpm install / yarn
npm run test:solana
```

Before running:

- Ensure a Solana cluster + wallet are configured:
  - `ANCHOR_PROVIDER_URL` – RPC URL (e.g. local `solana-test-validator` or devnet).
  - `ANCHOR_WALLET` – path to a funded keypair JSON file.
- Deploy the `gift_bridge_solana` program (ID must match `Brdg111111111111111111111111111111111111111`).
- Initialize the Solana side using the helper scripts:
  - `scripts/solana/createGiftSolMint.ts` – creates the GIFT_SOL SPL mint.
  - `scripts/solana/deployBridgeProgram.ts` – creates the Config PDA and wires admin/mint/Polygon bridge.

Then set:

- `GIFT_SOL_MINT` to the GIFT_SOL mint address.
- `GIFT_BRIDGE_CONFIG` to the Config PDA address.

The tests in `tests/solana/gift_bridge_solana.test.ts` will then:

- Read and validate the `Config` account wiring.
- Add and remove an extra authorized minter.
- Mint GIFT_SOL from a fake Polygon deposit (`mintFromPolygon`), then burn part of it
  (`burnForPolygon`) and check balances.

---

## Getting started (local dev outline)

1. **Polygon side**
   - Run Foundry tests: `cd contracts/polygon && forge test`.
   - Deploy the core contracts (GIFT, GIFTPoR, GIFTTaxManager, MintingUpgradeable,
     GIFTBarNFTDeferred, GiftRedemptionEscrowUpgradeable, GiftPolygonBridge) using your
     deployment tooling of choice (Foundry scripts or external).

2. **Solana side**
   - Build the program: `cargo build -p gift_bridge_solana`.
   - Use `scripts/solana/createGiftSolMint.ts` to create the GIFT_SOL mint on devnet/localnet.
   - Use `scripts/solana/deployBridgeProgram.ts` to initialize the `Config` PDA.
   - Ensure the GIFT_SOL mint authority is set to the program’s `mint_authority` PDA.

3. **Relayer**
   - Listen to:
     - `GiftPolygonBridge.DepositedToSolana` events on Polygon.
     - `gift_bridge_solana.BurnForPolygonEvent` events on Solana.
   - For each Polygon deposit, call `mintFromPolygon` on Solana.
   - For each Solana burn event, call `completeWithdrawalFromSolana` on Polygon.

This README is intentionally high‑level. For line‑by‑line behavior and invariants, see
`docs/architecture/The GIFT contract ecosystem.md`.

