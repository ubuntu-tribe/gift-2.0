
We started from a simple promise: every new gold bar must trace back to **specific gold in a specific vault**, and anyone regulator, investor, or customer should be able to verify that claim without calling us. To deliver that, we put two locks in front of issuance, and we made both locks publicly inspectable. The first lock is a **Proof-of-Reserve** contract that models gold vaults and their balances. The second lock is a **Merkle-anchored Registry** that commits, by cryptographic root, to the exact bars and lots that may back issuance. Only when both locks agree does the Supply Controller mint. Everything else upgradability, pausing, compliance controls, and optional delivery through on-chain **non-fungible gold bars** sits on top of that foundation.

We implemented the GIFT ERC-20 with OpenZeppelin’s UUPS pattern, which keeps the contract upgradeable under governance while making the bytecode you interact with stable through a proxy. The token can be paused by the owner for incident response, but the **only** address that can mint or burn is the Supply Controller a dedicated Minting contract. That controller is not trusted to mint arbitrarily. It must first satisfy the two locks, then it may call `increaseSupply`. This is deliberate: no ceremony, no slogans, just a narrow path that enforces, on-chain, that **paper must follow metal**.

## The Proof-of-Reserve: modeling vault gold on chain

The Proof-of-Reserve (PoR) contract is the on-chain twin of the real vault world. It enumerates vaults, tracks their balances in token units, and gives operational minters explicit **allowances** scoped to a specific vault ID. When the Supply Controller attempts to mint, it proves that (a) it’s an authorised minter, (b) its allowance for the chosen vault is sufficient, and (c) the vault’s balance covers the amount. After a successful mint, the allowance and the vault balance are reduced immediately. This keeps supply, allowances, and vault balances in perfect lock-step.

We designed the PoR to speak in the same units as the token, so the accounting is mechanical: if you see `X` more GIFT on chain, you will see `X` less available gold capacity in the PoR ledger, and the event stream will show **which vault** moved.

## The Registry: compressing bar lists into a 32-byte commitment

Reserves tell you “how much.” Provenance tells you “**which**.” For provenance we commit entire datasets (bar serials, lots, origins, documentation) into a single **Merkle root**. Off-chain, we prepare a structured dataset of “leaves”: one leaf per bar or lot. Each leaf is typed and slim by design to avoid stack complexity and gas bloat:

* `registry` address and `batchId` bind the data to this deployment and batch.
* `reserveId` points to the vault in PoR.
* `quantity` is the authorised ERC-20 amount this leaf may back (in smallest units).
* `fineWeightMg` fixes physical fine weight in milligrams for that leaf.
* `serialHash`, `mineHash`, `barStandardHash`, `docHash` are hashed strings anchoring serial, origin, delivery standard, and the dossier (assay + custody files).
* `mintedAtISO` and a compact **presence mask** indicate what was known at registration time. Unknowns hash to `keccak256("UNKNOWN")`, and their presence bits are zero.

We intentionally removed noisy fields like chain ID and refinery/custodian hashes from the leaf to keep it deterministic and lightweight; those details sit in the **document bundle** that `docHash` anchors. The order of fields is fixed and the encoding is **typed** (`abi.encode`) with a domain‐separating typehash, so there is no ambiguity about how the leaf hash is computed. The entire dataset and its proofs live off-chain in content-addressed storage (S3 with Object Lock and an IPFS mirror). On-chain, the Registry stores **just the root**, the batch cap (the sum of all `quantity` values), a dataset URI, and a schema hash. That’s all the chain ever needs to verify a claim.

When it’s time to mint, the Supply Controller submits the exact leaf fields and a short proof. The Registry recomputes the leaf hash, verifies the proof against the batch root, and then **consumes** part of that leaf’s authorisation, ensuring that no leaf can ever be overdrawn and no batch can exceed its cap. Only after this succeed-or-revert step does the Supply Controller mint GIFT.

## The mint path: two locks, one result

The lifecycle of a mint is precise and repeatable. First, the Minting contract asks PoR if it is allowed to mint against vault `reserveId` and whether the vault’s balance covers `amount`. If not, the transaction reverts. If yes, it sends the leaf data and proof to the Registry. The Registry verifies inclusion and checks that `amount` doesn’t push the leaf or batch over their limits; then it increments consumption and emits telemetry tying the mint to the specific batch and serial. Only then does the Supply Controller call `increaseSupply(to, amount)` on the ERC-20. Immediately after, PoR reduces both the minter’s allowance and the vault balance. The end result is that **for each mint, three contracts agree and three ledgers move**: the dataset consumption ledger in the Registry, the vault ledger in PoR, and the ERC-20 total supply.

For circulation that predates the Registry, we created a one-time **legacy batch** that acknowledges the initial three million units with a reason statement and a documentation hash. This squares the books without rewriting history and fixes a clean starting line for the Merkle era.

## On-chain non-fungible gold bars, deliverable by design

Beyond fungibility lies possession. Some owners want a **specific bar** in a **specific weight**, and they want the certainty that it comes from the same authorised lot that backed issuance. We solved that with on-chain **non-fungible gold bars** that can be created later, at the operator’s pace, directly against the same Merkle leaves. Each certificate references `(batchId, leafHash, reserveId, serialHash)` and represents a clear weight, such as 1 kg, 100 g, or 1 g. The minting logic enforces a hard cap: you can never create more certificates than the leaf’s recorded **fine weight** allows, and you may choose an even stricter mode that also checks how much ERC-20 was actually minted from that leaf. From a customer’s perspective this is straightforward: you hold gold on chain; when you choose to **redeem your gold**, we complete KYC and custody procedures and hand over a specific, serialised bar from the vault. The contract trail shows exactly which lot it came from.

## Cryptography and engineering choices that make this robust

We used typed hashing with a domain-separating typehash to immunise leaves from concatenation ambiguities and variable length hazards. Every field in a leaf is a **static type** in a fixed order. Optional values are handled with a **presence mask** plus a sentinel hash for unknowns, which guarantees that leaves built by different toolchains hash to the same result. We build trees with sorted sibling pairs and verify proofs with OpenZeppelin’s `MerkleProof.verifyCalldata`, the well-audited industry default. Proofs are ephemeral: they are provided in calldata at mint time, verified, and discarded; the on-chain commitment remains the root and the consumption counters.

On the contract side, we paid off the “stack-too-deep” risk by passing leaf data as a single `struct` in calldata. We wrote the Registry to do one thing verify and consume and we kept storage to a minimum: a per-batch map from leaf hash to consumed amount, and a small batch header. The Minting contract is upgradable, but its authority is narrow: it cannot mint without passing both locks. The token can be paused, and upgrades are gated by the owner (we recommend a multisig). There are no external callbacks in the mint path, and event streams are rich enough to rebuild state externally.

## Data discipline and custody of evidence

Gold is not just a number; it’s bars in a vault with assays, receipts, and custody chains. We treat the **document bundle** as evidence and anchor it with `docHash` in each leaf. Datasets and proofs are published to **immutable storage**: S3 with Object Lock in compliance mode and an IPFS pin as a public, content-addressed mirror. The Registry records the dataset URI and a **schema hash**, so anyone can verify not only that a leaf was in the dataset, but that the parser they used read the same columns in the same order we committed. This is how we made “offline meets online” trustworthy: the chain stores the root; the world fetches the dataset and recomputes; the math agrees.

## Observability, auditability, and compliance posture

Every meaningful step emits events. When a batch is registered, you see the root, cap, and dataset location. When a mint consumes part of a leaf, you see the batch ID, leaf hash, reserve ID, amount, and the new consumption totals. When the PoR ledger moves, you see the vault and the delta. With this telemetry, auditors can replay supply and provenance end-to-end and regulators can confirm the headline invariants in minutes: for each batch, `minted ≤ cap`; for each leaf, `consumed ≤ quantity`; and for the system as a whole, **circulating supply never outruns vault gold**.

The marketplace surface is fully KYC’d. Users are verified at onboarding, and when they decide to **redeem their gold**, we perform KYC again and follow the custodian’s release process to the letter. By the time metal leaves a vault, identity, provenance, and entitlement have lined up across contracts, evidence bundles, and compliance controls.

## Safety controls and upgrade path

We built for change without sacrificing restraint. The GIFT ERC-20 is upgradeable under owner control and can be paused globally. The Supply Controller is a contract, not a human, and its authority is bounded by PoR and the Registry. Batches are **finalised** once fully consumed to freeze their roots. We recommend a governance process that treats upgrades as scheduled, monitored events with simulations, dry runs, and signed root snapshots. If something isn’t right, pausing is instant and visible.

## Performance, costs, and scale

Merkle verification is compact tens of thousands of gas depending on tree depth and independent of dataset size. Leaves are static and small, so calldata is efficient. Because the chain never stores the dataset itself, adding more bars to a batch increases tree depth logarithmically while keeping the on-chain footprint stable. The PoR math is constant time. In practice, the end-to-end cost is dominated by a single proof check, a couple of storage increments, and the token mint.

## The result

We took gold in a vault and made it **transparent, bounded, and deliverable**. We compressed full bar lists into a single on-chain commitment and tied every unit of issuance to specific serialised metal. We locked the mint path behind two independent systems reserves and provenance and made both verifiable by anyone. We gave savers the liquidity of a fungible asset and the satisfaction of a **non-fungible gold bar** when they want to hold the metal itself. And we wrote it all so that a regulator can follow the logic, an auditor can replay the numbers, and an investor can sleep well knowing the chain and the vault agree.

---

**Development**
Kassy Olisakwe - Utribe.one
For queries or inquiries, contact kassy@utribe.one