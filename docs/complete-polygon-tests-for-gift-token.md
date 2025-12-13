## Complete Polygon Test Suite for GIFT Token and Related Contracts

This document describes the **full automated test suite** for the Polygon-side GIFT token ecosystem, and how to run those tests.  
It is written so that **non-developers** can understand what is being checked.

The suite currently runs **240 tests** across all core Polygon contracts and supporting components.

---

## How to run the tests

- **Run all Polygon tests**

  From the repository root:

  ```bash
  cd contracts/polygon
  forge test
  ```

  This compiles the Polygon contracts and runs **all 240 tests**.

- **Run tests for a single contract**

  ```bash
  cd contracts/polygon
  forge test --match-contract GIFTTest
  ```

  Replace `GIFTTest` with any of:

  - `GIFTPoRTest`
  - `GIFTBatchRegistryTest`
  - `GIFTTaxManagerTest`
  - `MintingUpgradeableTest`
  - `GiftRedemptionEscrowUpgradeableTest`
  - `GIFTBarNFTDeferredTest`
  - `GiftPolygonBridgeTest`

- **Run a single specific test**

  ```bash
  cd contracts/polygon
  forge test --match-contract GIFTTest --match-test test_Transfer_WithTax
  ```

  - `--match-contract` narrows to one test file.
  - `--match-test` narrows to one specific scenario inside that file.

---

## What the 240 tests cover (human-readable)

Below is a **plain‑English checklist** of what each test verifies, grouped by contract.

### 1. GIFT token (`GIFTTest`) – 30 tests

- **Initialization & basic properties**
  - Verify the GIFT token is initialized with the correct name, symbol, decimals, owner, and tax manager.
  - Verify the contract cannot be initialized a second time.

- **Supply control roles**
  - Check that the owner can set a **supply controller** address.
  - Check that setting the supply controller to the zero address is rejected.
  - Check that a non-owner cannot change the supply controller.
  - Check that the owner can set a **supply manager** address.
  - Check that setting the supply manager to the zero address is rejected.
  - Check that a non-owner cannot change the supply manager.

- **Minting and burning**
  - Ensure the supply controller can **increase an individual user’s balance** and the total supply.
  - Ensure that if a non–supply controller calls the same function, it is rejected.
  - Ensure the supply manager can **inflate the overall supply** to its own balance.
  - Ensure that if a non–supply manager calls this, it is rejected.
  - Ensure the supply controller can **burn tokens from a user** to redeem gold, and total supply decreases accordingly.
  - Ensure that if a non–supply controller tries to redeem (burn) someone’s tokens, it is rejected.

- **Pausing and unpausing**
  - Verify the owner can pause the contract and that transfers are blocked while paused.
  - Verify the owner can unpause the contract and transfers resume.
  - Verify that non-owners cannot pause the contract.

- **Manager role for delegated transfers**
  - Check that the owner can designate an address as a “manager” that is allowed to perform **delegate transfers** on behalf of users (with signatures).
  - Check that the owner can remove manager permissions and that the account no longer has elevated rights.

- **Transfers and tax logic**
  - Test a simple **transfer without tax** when both sender and recipient are exempt.
  - Test a **transferFrom without tax** when both parties are exempt.
  - Test a normal **taxed transfer** in the standard tier, ensuring:
    - The correct tax rate is applied based on amount size.
    - The correct tax amount is sent to the tax beneficiary.
    - The net amount received by the recipient is correct.
  - Test a **larger transfer in a higher tier** and verify the tax uses the correct tier thresholds and percentages.

- **Tax manager linking**
  - Verify the owner can change the tax manager to a new contract.
  - Verify that setting the tax manager to the zero address is rejected.

- **Delegated transfers & chain ID helper**
  - Check that an invalid signature on a delegated transfer is rejected and does not move funds.
  - Check that the `getChainID()` helper returns the actual current chain ID.

- **Upgradability protections**
  - Confirm that the owner can perform an upgrade call on the implementation when used behind a proxy.
  - Confirm that a non-owner cannot trigger an upgrade.

### 2. Proof‑of‑Reserves (`GIFTPoRTest`) – 51 tests

- **Initialization & roles**
  - Verify the PoR contract owner is set correctly on initialization.
  - Ensure the deployer is initially both an **auditor**, **admin**, and **minter**.
  - Confirm that `nextVaultId` starts at 1 and increments as vaults are created.

- **Role management**
  - Admins can add and remove other **auditors**.
  - Admins can add and remove other **admins**.
  - Admins can add and remove **minters**.
  - Non-owners cannot add admins.
  - Non-owners cannot add auditors.
  - Non-admins cannot add minters.

- **Vault creation and query**
  - Admins can create new physical vault entries with names, IDs, and zero starting balances.
  - Attempting to create a vault as a non-admin is rejected.
  - Querying a vault’s state by ID returns name, ID, and balance.
  - Querying a non-existent vault ID reverts.
  - Total number of reserves and the aggregate reserve amount are reported correctly.

- **Digital reserve updates**
  - Auditors can **increase a vault’s digital balance**, and this also increases the global `GIFT_reserve`.
  - Attempting to update a vault’s digital balance as a non-auditor is rejected.
  - Attempting to update a non-existent vault ID is rejected.

- **Physical reserve tracking**
  - Auditors can **add physical gold** to a vault, and the physical amount increases accordingly.
  - Non-auditors cannot call the physical reserve add function.
  - Auditors can **redeem (remove) gold** from the physical vault and balances decrease appropriately.
  - Attempting to redeem more physical gold than available is rejected.
  - Non-auditors cannot redeem gold.

- **Moving supply between vaults**
  - Auditors can move digital and physical supply between vaults, decreasing one and increasing another.
  - Attempting to move more than one vault’s balance is rejected.
  - Moving supply from an invalid source vault ID reverts.
  - Moving supply to an invalid destination vault ID reverts.
  - Non-auditors cannot move supply.

- **Minting allowances**
  - Admins can set a minting allowance for a given minter and vault (reserve ID).
  - Non-admins cannot set minting allowances.
  - Setting an allowance for an invalid reserve ID is rejected.
  - Setting an allowance twice for the same minter and vault updates the allowance instead of duplicating it.
  - Querying minter reserves and allowances returns the full list of (reserve, allowance) pairs.

- **After‑mint accounting**
  - Minters can call `updateReserveAfterMint` to decrease a vault’s digital balance when tokens are minted.
  - Attempting to call `updateReserveAfterMint` from a non-minter reverts.
  - Trying to update a non-existing vault or with more than the current balance is rejected.

- **Lifecycle scenario**
  - A “complete vault lifecycle” test:
    - Creates a new vault.
    - Adds physical supply.
    - Increases digital reserve to match.
    - Sets a minting allowance.
    - Updates reserve after minting.
    - Redeems some physical gold.
    - Asserts the final digital and physical balances are consistent with the operations performed.

- **General queries**
  - Validate `retrieveReserve()` returns the global GIFT reserve.
  - Confirm `isMinter(account)` returns true only for configured minters.

- **Upgradability protections**
  - Confirm that an admin can perform an upgrade.
  - Confirm that non-admin callers cannot trigger an upgrade.

### 3. Batch registry / Merkle proofs (`GIFTBatchRegistryTest`) – 36 tests

- **Initialization & wiring**
  - Verify the registry owner and initial minting address are set correctly when initialized behind a proxy.
  - Confirm `nextBatchId` starts from 1.
  - Confirm the `minting` address stored in the registry matches the Minting contract.

- **Set minting contract**
  - Owner can change the `minting` address to a new contract.
  - Setting minting to the zero address is rejected.
  - A non-owner cannot change the minting address.

- **Batch registration**
  - Owner can register a new batch with:
    - a Merkle root,
    - total cap,
    - dataset URI,
    - schema hash,
    - active flag.
  - When `active` is true, a **BatchActivated** event is emitted.
  - When `active` is false, the batch is registered but not activated.
  - Registering with a zero root is rejected.
  - Registering with a zero cap is rejected.
  - Non-owners cannot register batches.
  - Multiple batch registrations advance `nextBatchId` and keep each batch’s metadata distinct.

- **Finalizing batches**
  - Owner or admin can mark a batch as finalized, which disables further consumption.
  - Finalizing the same batch twice is rejected.
  - Non-owner/non-admin callers cannot finalize a batch.

- **Legacy supply**
  - Owner/admin can record pre-existing (“legacy”) supply as a separate batch:
    - The cap and minted supply are immediately set to the legacy amount.
    - The batch is marked as finalized and legacy.
  - Legacy supply with zero amount is rejected.
  - Non-owner/non-admin callers cannot acknowledge legacy supply.

- **Merkle proof verification**
  - For a correct leaf and properly registered batch, `verifyLeaf` returns the expected leaf hash and `ok = true`.
  - For an incorrect leaf or mismatched batch/root, `verifyLeaf` returns `ok = false`.

- **Consumption (minting against a batch)**
  - When called by the configured Minting contract:
    - Ensures the batch is active and not finalized.
    - Ensures the Merkle proof is valid.
    - Ensures the per-leaf consumption does not exceed that leaf’s quantity.
    - Ensures the total minted does not exceed the batch cap.
    - Updates consumed amounts and total minted.
    - Emits a `MintConsumed` event capturing leaf hash, reserve, recipient, and amounts.
  - Multiple calls can consume from the same leaf, as long as the sum stays within limits.
  - If the caller is not the minting contract, consumption is rejected.
  - Consuming with zero amount is rejected.
  - Consuming on an inactive or finalized batch is rejected.
  - Consuming with a bad proof is rejected.
  - Trying to exceed the per-leaf or per-batch cap is rejected with explicit errors.

- **Admin role on registry**
  - Owner can grant and revoke an `ADMIN_ROLE` which shares some privileges (e.g. finalize).
  - Non-owners cannot grant admin role.
  - Role assignments and revocations are properly recorded and can be queried.

- **Events & upgrades**
  - Tests that batch registration, activation, finalization, and legacy acknowledgment emit the expected events with correct parameters.
  - Confirms the registry can be upgraded by the owner.
  - Confirms non-owners cannot trigger an upgrade.

### 4. Tax manager (`GIFTTaxManagerTest`) – 32 tests

- **Initialization & defaults**
  - Verify the tax manager owner and beneficiary are set correctly.
  - Verify the default tax tier thresholds and percentages are set as intended.
  - Confirm the owner is excluded from outbound fees by default.
  - Confirm all inbound transfers are considered exempt by default.

- **Tax officer role**
  - Owner can assign a separate “tax officer” address.
  - Setting the tax officer to the zero address is rejected.
  - Non-owners cannot change the tax officer.

- **Beneficiary configuration**
  - Owner can change the address that receives tax proceeds.
  - Setting the beneficiary to the zero address is rejected.
  - Non-owners cannot change the beneficiary.

- **Tax percentage and tier updates**
  - Owner and tax officer can update tax percentages for all five tiers.
  - Owner and tax officer can update tier thresholds (amount brackets).
  - Unauthorized addresses cannot change tax percentages or tiers.
  - Events are emitted when percentages or tiers are updated.

- **Fee exclusions**
  - Owner or tax officer can exclude addresses from outbound fees and, logically, inbound fees.
  - Excluding and then re-including (removing exclusion) is supported and tested.
  - Inbound fee exclusion is always true (no inbound taxes) and this behavior is tested.
  - Non-authorized callers cannot change fee exclusions.

- **Liquidity pools**
  - Owner can label addresses as liquidity pools (affecting how taxes are applied).
  - Owner can remove liquidity pool status.
  - Non-owners cannot mark or unmark liquidity pools.

- **Tax calculation helpers**
  - Tests confirm that for small transfers, the tier-one tax rate is applied correctly.
  - Tests confirm that for large transfers, the top tier tax rate is applied correctly.

- **Events & upgrades**
  - Every major configuration change (tax percentages, tiers, tax officer, beneficiary, fee exclusion, liquidity pool status) is checked to emit its expected event.
  - Confirm the contract can be upgraded by the owner.
  - Confirm that non-owners cannot upgrade it.

### 5. Minting engine (`MintingUpgradeableTest`) – 43 tests

- **Initialization & wiring**
  - Verify the Minting contract is correctly initialized with:
    - a PoR contract,
    - the GIFT token,
    - a batch registry,
    - and that the escrow address starts as expected.

- **Registry configuration**
  - Owner can change the registry address and retrieve it.
  - Non-owners cannot change the registry.
  - Owner can toggle whether the registry must be enforced (`registryEnforced`).
  - Non-owners cannot toggle registry enforcement.

- **Batch allowlisting**
  - Owner can mark specific batch IDs as allowed for minting.
  - Owner can disable a previously allowed batch.
  - Non-owners cannot change the allowed batches.

- **Escrow configuration**
  - The PoR owner (not arbitrary callers) can set the escrow address that holds locked GIFT for NFT redemptions.
  - Setting escrow to the zero address is rejected.
  - Non–PoR owners cannot change the escrow address.

- **Minting with Merkle proofs**
  - A valid `mintWithProof` call:
    - Requires the caller to be a PoR-designated minter.
    - Requires `amount > 0`.
    - Requires registry enforcement to be enabled.
    - Requires the batch to be allowed.
    - Checks minting allowance and vault reserve in PoR.
    - Calls the registry to verify and consume a Merkle leaf.
    - Mints GIFT tokens to the recipient.
    - Decreases the minter’s allowance and vault’s reserve in PoR.
    - Emits a `TokensMinted` event with leaf hash and batch ID.
  - Tests for all main failure cases:
    - Caller is not a PoR minter.
    - Amount is zero.
    - Registry enforcement is disabled.
    - Batch not allowed.
    - Exceeds minting allowance.
    - Vault reserve is insufficient.

- **Minting without proofs (legacy path)**
  - `mint` without proof:
    - Only allowed when registry enforcement is disabled.
    - Still checks PoR minter status, allowance, and reserve.
    - Updates PoR allowance and reserves.
    - Emits `TokensMinted` with a zero leaf hash and batch ID.
  - Calls when registry must be enforced are rejected.
  - Calls by non-minters, with zero amounts, or exceeding allowance/reserve are rejected.

- **Burning tokens via Minting**
  - PoR owner can call `burnFrom` to burn tokens from any account (administrative burn).
  - Non–PoR owners cannot call `burnFrom`.
  - The escrow contract can call `burnEscrowBalance` to burn from its own GIFT balance upon redemption.
  - Non-escrow callers cannot use `burnEscrowBalance`.
  - Zero-amount burns via `burnEscrowBalance` are rejected.

- **PoR admin helpers**
  - `getAdmin()` returns the owner of the PoR contract.
  - `changeAdmin()` is only callable by the PoR owner, must not be zero address, and updates PoR ownership.
  - Tests also confirm that calls from the wrong party or with zero address revert.

- **Events & upgrades**
  - Emission of key events: `RegistrySet`, `RegistryEnforced`, `BatchAllowed`, `EscrowSet`, and `TokensMinted` is validated.
  - Upgrades are allowed only for the Minting owner and not for other callers.

- **Lifecycle scenario**
  - A combined mint/burn lifecycle test:
    - Establishes allowance and registry configuration.
    - Mints tokens against PoR and registry.
    - Then exercises burn and PoR accounting.

### 6. Escrow for redemptions (`GiftRedemptionEscrowUpgradeableTest`) – 9 tests

- **Initialization & wiring**
  - Verify escrow binds to the correct GIFT and Minting contracts.
  - Verify the escrow owner is set correctly.

- **Marketplace configuration**
  - Owner can whitelist marketplace addresses allowed to lock GIFT when NFTs are sold.
  - Non-owners cannot configure marketplace permissions.

- **Locking GIFT for NFT purchases**
  - In a typical purchase:
    - A user obtains GIFT (minted via Minting + PoR).
    - User approves the escrow to transfer GIFT on their behalf.
    - The marketplace mints an NFT representing a bar/batch.
    - The marketplace calls `lockGiftForNFT`, which:
      - Pulls GIFT from the purchaser to the escrow.
      - Creates a permanent record tying GIFT amount to `(nftContract, tokenId)`.
      - Emits `GiftLockedForNFT`.
  - Non-marketplace callers attempting to lock GIFT are rejected.

- **Redemption request (user sends NFT to escrow)**
  - When a user transfers the NFT to the escrow via `safeTransferFrom`:
    - Escrow checks that an associated record exists and isn’t already redeemed or in progress.
    - Flags the record as `inRedemption` and records the redeemer.
    - Emits `RedemptionRequested`.

- **Canceling redemption**
  - Owner can cancel a redemption in progress:
    - Escrow marks the record as cancelled and not in redemption.
    - NFT is safely transferred back to the redeemer.
    - Emits `RedemptionCancelled`.
  - Non-owners attempting to cancel are rejected.

- **Completing redemption (full flow)**
  - When owner calls `completeRedemption`:
    - Confirms there is a valid in-progress redemption.
    - Confirms escrow holds the required GIFT amount.
    - Instructs Minting to burn the escrow’s balance for that amount (backed by PoR).
    - Tries to burn the NFT (or at least permanently lock it).
    - Marks the redemption as completed and no longer in redemption.
    - Emits `RedemptionCompleted`.

### 7. NFT representing gold bars (`GIFTBarNFTDeferredTest`) – 26 tests

- **Initialization & ownership**
  - Verify NFT name and symbol are correct.
  - Verify the registry address, default unit weight (mg), and `nextId` are configured.
  - Confirm that ownership of the NFT contract is transferred to the escrow as expected.

- **Admin settings**
  - Owner can update `unitMg` (the mg weight each NFT represents).
  - Setting `unitMg` to zero is rejected.
  - Non-owners cannot change `unitMg`.
  - Owner can set the base URI used for metadata.
  - Non-owners cannot change the base URI.
  - Owner can switch between capacity modes (leaf-based max vs strict consumed).
  - Non-owners cannot change capacity mode.

- **Minting bars from registry leaves**
  - Owner (escrow) can mint one or multiple NFTs from a valid Merkle leaf:
    - Validates the leaf via the registry.
    - Ensures capacity is not exceeded for the leaf or batch.
    - Creates `BarInfo` records linking each token to batch, leaf hash, reserve, and metadata hashes.
    - Tracks how many “units” have been minted for each leaf.
  - Minting with zero units is rejected.
  - Minting with an invalid proof is rejected.
  - Minting more units than allowed from a leaf is rejected.
  - Only the owner (escrow) can call the minting function.

- **Capacity calculations**
  - `remainingUnits` view function reports how many more NFTs can be minted under:
    - **LEAF_MAX** mode: capacity is determined by fine weight / unit mg.
    - **STRICT_CONSUMED** mode: capacity is tied to GIFT actually consumed from that leaf (via registry).

- **Metadata and URIs**
  - `tokenURI` returns a structured path combining base URI, batch ID, leaf hash, and token ID.
  - When base URI is empty, `tokenURI` returns an empty string.

- **Burning**
  - Owner (escrow) can burn a token and clear its `BarInfo`.
  - Non-owners cannot burn tokens.

- **Transfers and approvals**
  - Standard ERC‑721 transfers and approvals work between users for these bar NFTs.
  - A composed test ensures approval and transfer flows behave as expected.

- **Events**
  - Minting emits a `BarsMinted` event with batch, leaf, reserve, and token ID range.
  - Changing unit mg, base URI, and capacity mode each emit dedicated events.

### 8. Polygon bridge (`GiftPolygonBridgeTest`) – 13 tests

- **Initialization & wiring**
  - Verify the bridge binds to the correct GIFT token, tax manager, relayer, and owner.
  - Confirm the initial deposit nonce is zero.

- **Relayer management**
  - Owner can change the relayer address.
  - Setting the relayer to the zero address is rejected.
  - Non-owners cannot change the relayer.

- **Deposits to Solana**
  - A user with GIFT (minted via PoR+Minting) can:
    - Approve the bridge for a certain amount.
    - Call `depositToSolana`, which:
      - Transfers GIFT to the bridge contract.
      - Increments a nonce.
      - Emits `DepositedToSolana` including:
        - Polygon sender,
        - Solana recipient (as a 32-byte key),
        - amount,
        - nonce.
  - Deposits with zero amount are rejected.
  - Deposits with an invalid (zero) Solana recipient are rejected.
  - Deposits are blocked while the bridge is paused.

- **Withdrawals from Solana burns**
  - The designated relayer can call `completeWithdrawalFromSolana` to:
    - Confirm a burn transaction on Solana (by ID).
    - Transfer GIFT out of the bridge to a Polygon recipient.
    - Mark the burn transaction as processed.
    - Emit `WithdrawalToPolygonCompleted`.
  - Calling this while paused is rejected.
  - Calls from non-relayer addresses are rejected.
  - Calling again with the same burn transaction ID is rejected to prevent double-spend.

- **Locked-balance view**
  - `lockedBalance()` reports how many GIFT tokens are currently held by the bridge.

---

## Summary

- The **Polygon GIFT ecosystem** is covered by **240 automated tests** that:
  - Exercise **token behavior, supply & taxes**.
  - Validate **proof-of-reserves and vault accounting**.
  - Enforce **Merkle batch registry** rules.
  - Exercise **minting with and without proofs** against PoR.
  - Cover **NFT bar minting, escrow locking, and physical redemption**.
  - Validate the **Polygon bridge** deposit and withdrawal flows.
- These tests are designed so that:
  - **Developers** can run them with `forge test`, and
  - **Non-developers** can read this document to understand **what** is being tested and why it matters.


