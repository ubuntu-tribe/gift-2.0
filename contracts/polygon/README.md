## Polygon contracts (Foundry)

This folder contains the **Polygon side** of the GIFT 2.0 protocol, implemented as a Foundry project.

- Core production contracts live directly in `contracts/polygon/` (Foundry is configured with `src = "."`).
- Tests live under `contracts/polygon/test/`.
- Third‑party libraries (OpenZeppelin, forge‑std, etc.) are vendored under `contracts/polygon/lib/`,
  with remappings in `contracts/polygon/remappings.txt`.

### Main contracts

- `GIFT.sol`  
  Upgradeable ERC‑20 token (18 decimals, 1 GIFT = 1 mg of gold):
  - `supplyController` / `supplyManager` roles for mint/burn and optional inflation.
  - Calls `GIFTTaxManager` to apply tiered outbound transfer taxes.
  - Supports delegated transfers via signatures.

- `GIFTPoR.sol`  
  Proof‑of‑Reserve ledger:
  - Tracks vaults, global reserves, physical reserves, and per‑minter minting allowances.
  - Roles for `auditors`, `admins`, and `minters`.
  - Integrates with `MintingUpgradeable` to enforce supply ≤ reserves.

- `GIFTTaxManager.sol`  
  Tax configuration and routing policy:
  - Stores tax tiers and percentages.
  - Manages fee exclusions and liquidity pool flags.
  - Inbound transfers are currently globally exempted (no inbound tax).

- `MintingUpgradeable.sol`  
  Canonical issuance engine:
  - Wires `GIFTPoR`, `GIFT`, and `GIFTBatchRegistry`.
  - `mintWithProof()` enforces PoR + Merkle proofs + batch caps before minting GIFT.
  - Legacy `mint()` path exists for non‑proof minting when `registryEnforced == false`.
  - Also exposes controlled burn paths for PoR owner and the redemption escrow.

- `GIFTBarNFTDeferred.sol`  
  ERC‑721 NFTs for physical gold bars:
  - Integrates with `GIFTBatchRegistry` to derive capacity from Merkle leaves.
  - Each NFT encodes batch, leaf hash, reserve id, and hashes for metadata.
  - Owner (eventually the escrow) can mint/burn bar NFTs.

- `GiftRedemptionEscrowUpgradeable.sol`  
  Escrow that locks GIFT during NFT sales and burns on physical redemption:
  - Whitelists marketplaces that can call `lockGiftForNFT`.
  - Receives NFTs via `safeTransferFrom` (redemption request).
  - `completeRedemption` burns GIFT via `MintingUpgradeable` and attempts to burn the NFT.

- `GiftPolygonBridge.sol`  
  Pooled bridge contract that locks GIFT on Polygon:
  - `depositToSolana()` pulls GIFT from users and emits `DepositedToSolana`.
  - `completeWithdrawalFromSolana()` (onlyRelayer) releases GIFT after a verified Solana burn.

- `Europe/EUTransferAgent.sol`  
  Regional transfer agent for compliance‑filtered flows over GIFT:
  - Enforces blacklists, daily caps, SAR thresholds, and delayed/frozen/confiscated transfers.

### Tests

From `contracts/polygon/`:

```bash
forge test
```

This runs the full Foundry test suite (see `docs/complete-polygon-tests-for-gift-token.md`
for a human‑readable checklist of what’s covered).

