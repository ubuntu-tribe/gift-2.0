# GIFT 2.0 – Cross-Chain, PoR, NFT & Escrow Architecture

## High-level overview

- **1 GIFT = 1 mg of gold**.
- Polygon is the **canonical chain** for:
  - GIFT ERC20 token.
  - Proof-of-Reserve (GIFTPoR).
  - Merkle-proof-based minting (MintingUpgradeable + GIFTBatchRegistry).
  - NFTs representing physical bars (GIFTBarNFTDeferred).
  - Escrow-backed physical redemption (GiftRedemptionEscrowUpgradeable).
- Solana hosts **GIFT_SOL**, a bridged representation of GIFT:
  - Fully backed by GIFT locked in a pooled bridge on Polygon.
  - Used for DeFi and ecosystem growth.
  - Physical redemption always routes back to Polygon.

## Polygon components

- **GIFT (ERC20Upgradeable, Pausable, Ownable, UUPS)**  
  - Main token, 18 decimals, 1 GIFT = 1 mg.  
  - Roles:
    - `supplyController`: allowed to call `redeemGold(address, uint256)` and burn tokens.
    - `supplyManager`: allowed to call `inflateSupply(uint256)` to mint to itself.
  - Transfers apply tiered taxes via `GIFTTaxManager`:
    - Outbound fees based on amount and tier.
    - Inbound currently exempt (see GIFTTaxManager).

- **GIFTTaxManager (OwnableUpgradeable, UUPS)**  
  - Holds tax configuration:
    - Tier thresholds: `tierOneMax`, `tierTwoMax`, `tierThreeMax`, `tierFourMax`.
    - Percentages: `tierOneTaxPercentage` … `tierFiveTaxPercentage`.
  - Manages:
    - `isExcludedFromOutboundFees` and liquidity pools.
  - On Polygon, the bridge and escrow contracts can be marked tax-exempt (outbound).

- **GIFTPoR (PoR, OwnableUpgradeable, UUPS)**  
  - Tracks physical vault balance:
    - `GIFT_reserve` = total mg in vaults.
    - Per-vault storage via `vaultsById` and `physicalVaultsById`.
  - Roles:
    - `auditors`, `admins`, `minters`.
  - Functions:
    - `addVault`, `updateVault`, `SupplyGold`, `RedeemGold`, `moveSupply`.
    - `setMintingAllowance`, `getMinterReservesAndAllowances`, `updateReserveAfterMint`.
  - Invariant:
    - Total minted GIFT should not exceed physical reserve (subject to governance policy).

- **GIFTBatchRegistry (OwnableUpgradeable, AccessControlUpgradeable, UUPS)**  
  - Registry of merkle batches that back minting:
    - `BatchMeta` stores:
      - `root`, `cap`, `minted`, `datasetURI`, `schemaHash`, flags, `createdAt`, `createdBy`.
  - Merkle leaf schema (`LeafInput`) covers:
    - `batchId`, `reserveId`, `quantity`, `fineWeightMg`, `serialHash`, `mineHash`, `barStandardHash`, `docHash`, `mintedAtISO`, `presenceMask`.
  - Functions:
    - `registerBatch`, `finalizeBatch`, `acknowledgeLegacySupply`.
    - `verifyLeaf`, `leafConsumed`, `consume`.
  - Only `minting` contract can call `consume`.

- **MintingUpgradeable (OwnableUpgradeable, UUPS)**  
  - Canonical issuance engine for GIFT.
  - Wires together:
    - `GIFTPoR` (reserve + allowances).
    - `GIFT` token.
    - `GIFTBatchRegistry` (Merkle proofs).
  - Core paths:
    - `mintWithProof`:
      - Enforces PoR allowances and vault balances.
      - Verifies merkle leaf and consumes registry capacity.
      - Calls `gift.increaseSupply(to, amount)`.
      - Updates PoR allowances and reserve.
    - `mint` (legacy, no registry) when `registryEnforced` is false.
  - Admin helpers:
    - `setRegistry`, `enforceRegistry`, `allowBatch`.
    - `burnFrom(account, amount)`:
      - Calls `gift.redeemGold(account, amount)`.
      - Used by PoR owner; requires this contract to be `supplyController`.
    - `setEscrow(escrow)`:
      - Configures the escrow contract.
    - `burnEscrowBalance(amount)`:
      - `onlyEscrow` path, used by escrow to burn tokens held by escrow via `gift.redeemGold(escrow, amount)`.

- **GIFTBarNFTDeferred (ERC721, Ownable, ReentrancyGuard)**  
  - ERC721 NFT representing physical bars.
  - Integrates with `GIFTBatchRegistry` to derive capacity from merkle leaves.
  - Minting:
    - `mintBarsFromLeaf(to, units, leaf, proof)`:
      - Owner-only function that mints `units` NFTs from a verified leaf.
      - Each NFT represents `unitMg` fine mg (default 1_000_000 mg = 1 kg).
  - Metadata:
    - `BarInfo` per token: batch, leafHash, reserveId, mg unit, hashes.
    - `tokenURI` derived from baseURI, batch, leafHash, tokenId.
  - Burn:
    - Recommended change:
      - `function burn(uint256 tokenId) external onlyOwner { _burn(tokenId); delete barInfo[tokenId]; }`
    - After deployment, ownership of NFT contract is transferred to `GiftRedemptionEscrowUpgradeable` so escrow can burn tokens on redemption.

- **GiftRedemptionEscrowUpgradeable (OwnableUpgradeable, UUPS, IERC721ReceiverUpgradeable)**  
  - Locks GIFT tokens at NFT purchase and handles physical redemption.
  - State:
    - `gift` (GIFT token).
    - `minting` (MintingUpgradeable).
    - `isMarketplace` whitelist.
    - `escrows[nftContract][tokenId]` → `EscrowRecord`.
  - Flow:
    - NFT Purchase:
      - Marketplace:
        - Collects GIFT from purchaser.
        - Calls `lockGiftForNFT(nftContract, tokenId, giftAmount, purchaser)`:
          - Transfers GIFT from purchaser → escrow.
          - Creates `EscrowRecord`.
      - NFT minted/transferred to user by marketplace/NFT contract.
    - Redemption Request:
      - User calls `safeTransferFrom(user, escrowAddress, tokenId)` on NFT contract.
      - Escrow’s `onERC721Received`:
        - Verifies record exists and is not already redeemed.
        - Marks `inRedemption = true`, `redeemer = user`.
        - Emits `RedemptionRequested`.
    - Cancel:
      - `cancelRedemption` (onlyOwner) returns NFT to redeemer and marks `cancelled`.
    - Complete Redemption:
      - After physical gold shipped and confirmed:
        - Admin calls `completeRedemption(nftContract, tokenId)`:
          - Checks escrow holds `giftAmount` GIFT.
          - Calls `minting.burnEscrowBalance(giftAmount)`:
            - MintingUpgradeable calls `GIFT.redeemGold(escrow, giftAmount)` and burns tokens.
          - Attempts to `GIFTBarNFTDeferred(nftContract).burn(tokenId)`; if it fails, NFT is permanently locked.
          - Emits `RedemptionCompleted`.
  - Result:
    - GIFT used to buy that NFT is locked, then burned on redemption.
    - NFT is destroyed or permanently caged.
    - PoR can be updated to reflect physical outflow.

## Solana components

- **GIFT_SOL mint (token-2022 recommended)**  
  - 18 decimals.
  - Mint authority is a PDA owned by `gift_bridge_solana` program.

- **gift_bridge_solana (Anchor program)**  
  - `initialize_config`:
    - Creates a Config account with:
      - `admin` (relayer / governance).
      - `gift_mint` (GIFT_SOL).
      - `polygon_bridge` (GiftPolygonBridge address).
  - `mint_from_polygon`:
    - Called by relayer after Polygon’s `GiftPolygonBridge.depositToSolana`.
    - Mints `amount` GIFT_SOL to user’s token account.
    - Uses a `ProcessedDeposit` PDA to prevent replay.
  - `burn_for_polygon`:
    - Called by users on Solana when they want to move back to Polygon.
    - Burns GIFT_SOL and emits an event with `polygon_recipient`.

## Polygon bridge (pooled)

- **GiftPolygonBridge**  
  - Holds a pool of locked GIFT tokens that back GIFT_SOL on Solana.
  - `depositToSolana(amount, solanaRecipient)`:
    - Transfers `amount` GIFT from user → bridge.
    - Emits a `DepositedToSolana` event.
  - `completeWithdrawalFromSolana(polygonRecipient, amount, solanaBurnTx)`:
    - `onlyRelayer`.
    - Prevents replay with `processedBurns`.
    - Transfers `amount` GIFT from bridge → `polygonRecipient`.

## Off-chain relayer

- Listens to:
  - `GiftPolygonBridge.DepositedToSolana` on Polygon.
  - `gift_bridge_solana.BurnForPolygonEvent` on Solana.
- Executes:
  - Polygon → Solana:
    - `mint_from_polygon` for each deposit.
  - Solana → Polygon:
    - `completeWithdrawalFromSolana` for each burn.

## End-to-end flows

### A. Minting new GIFT

1. PoR admins and auditors update `GIFTPoR` vaults.
2. PoR admins set minters and minting allowances.
3. A minter calls `MintingUpgradeable.mintWithProof` with a valid merkle leaf and proof.
4. PoR checks, registry consumes, and GIFT is minted to `to`.

### B. Buying NFTs with GIFT

1. User holds GIFT on Polygon.
2. Marketplace computes price in mg and thus GIFT.
3. User approves marketplace/escrow to spend GIFT.
4. Marketplace:
   - Calls `GiftRedemptionEscrow.lockGiftForNFT(...)`.
   - Mints/transfers NFT to user via `GIFTBarNFTDeferred.mintBarsFromLeaf`.
5. Locked GIFT remains in escrow; NFT is freely tradable.

### C. Redeeming physical gold

1. User owns a GIFTBar NFT and wants physical gold.
2. User calls `safeTransferFrom(user, escrow, tokenId)` on NFT contract.
3. `GiftRedemptionEscrow` marks `inRedemption` and logs `RedemptionRequested`.
4. Ops ships the physical bar and collects confirmation.
5. Admin calls `completeRedemption`:
   - Escrow uses `MintingUpgradeable.burnEscrowBalance` to burn GIFT from its balance.
   - Escrow burns or permanently locks the NFT.

### D. Cross-chain usage (Solana)

1. User or admin calls `depositToSolana` on Polygon.
2. GIFT is locked in `GiftPolygonBridge`.
3. Relayer calls `mint_from_polygon` to mint GIFT_SOL on Solana.
4. Users use GIFT_SOL in Solana DeFi.
5. To redeem or go back:
   - User calls `burn_for_polygon` on Solana.
   - Relayer calls `completeWithdrawalFromSolana` on Polygon.
   - User receives GIFT ERC20 and can then buy NFTs or redeem via escrow.
