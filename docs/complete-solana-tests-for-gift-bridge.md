## Complete Solana Test Plan for `gift_bridge_solana`

This document describes the **Solana test suite** for the bridge program `gift_bridge_solana`,
what it covers conceptually, and how to run it. It mirrors the style of the Polygon test doc so
that **non‑developers** can understand what is being checked.

---

## How Solana fits into the system

- Polygon is the **canonical chain** for:
  - The GIFT ERC‑20 token and its taxes.
  - Proof‑of‑Reserve (`GIFTPoR`), Merkle registry (`GIFTBatchRegistry`), and minting engine.
  - NFTs for physical bars and the redemption escrow.
  - The pooled bridge contract `GiftPolygonBridge` that **locks GIFT** backing Solana.
- Solana hosts **GIFT_SOL**, a bridged representation of GIFT:
  - Minted and burned by the `gift_bridge_solana` Anchor program.
  - Fully backed by GIFT locked in `GiftPolygonBridge` on Polygon.
  - Used for DeFi / ecosystem growth; physical redemption always routes back through Polygon.

On Solana, the core tasks of the bridge program are:

- Keep a **Config** account that wires:
  - The **admin** (relayer / governance),
  - The **GIFT_SOL mint**,
  - The **Polygon bridge address**.
- Maintain a list of **extra authorized minters** (e.g. backup multisigs).
- On Polygon deposits:
  - **Mint GIFT_SOL** via `mint_from_polygon` and remember which deposits were processed.
- On Solana burns:
  - **Burn GIFT_SOL** via `burn_for_polygon` and emit an event that the Polygon bridge relayer uses
    to unlock GIFT back on Polygon.

---

## How these tests will eventually be run

The Solana tests are currently implemented as **TypeScript integration tests** that talk to a
local validator or devnet using the Anchor TS client:

- Location: `tests/solana/gift_bridge_solana.test.ts`
- How to run:

  ```bash
  # From repo root (after installing Node deps with npm, pnpm, or yarn)
  npm install          # or pnpm install / yarn

  # Ensure a Solana cluster + wallet are configured, then:
  npm run test:solana
  ```

These tests use:

- The IDL at `idl/gift_bridge_solana.json`.
- `@coral-xyz/anchor` to talk to the deployed program.
- `@solana/web3.js` and `@solana/spl-token` to manage SPL token accounts and balances.

> Note: The Solana tests assume:
> - The `gift_bridge_solana` program is already deployed with ID
>   `EKAeT88SXnVSFT74MVgYG7tfLKuux271UURqN1FQa5Gf`.
> - Environment variables are set:
>   - `ANCHOR_PROVIDER_URL` – RPC URL (e.g. local validator or devnet).
>   - `ANCHOR_WALLET` – path to a funded keypair JSON file.
>   - `GIFT_SOL_MINT` – address of the GIFT_SOL SPL mint.
>   - `GIFT_BRIDGE_CONFIG` – address of the Config PDA, created via `scripts/solana/deployBridgeProgram.ts`.

---

## What the Solana tests will cover (human‑readable)

The test plan is organized by **instruction** and by **end‑to‑end scenario**, similar in style to
`docs/complete-polygon-tests-for-gift-token.md`.

### 1. Config initialization – `initialize_config`

These tests verify that the Solana bridge program is wired to the correct mint and Polygon bridge.

- **Initialization and wiring**
  - **test_InitializeConfig_SetsFieldsCorrectly**
    - Creates a GIFT_SOL mint on Solana.
    - Calls `initialize_config(admin, gift_mint, polygon_bridge)`:
      - `admin` is the relayer/governance signer.
      - `gift_mint` is the GIFT_SOL SPL mint.
      - `polygon_bridge` is the 20‑byte address of `GiftPolygonBridge` on Polygon.
    - Verifies that the on‑chain `Config` account stores:
      - `admin` = relayer pubkey.
      - `gift_mint` = the SPL mint pubkey.
      - `polygon_bridge` = correct 20‑byte value.
      - `extra_minters` is an empty list.

  - **test_InitializeConfig_UsesExpectedPDA**
    - Derives the `Config` PDA using the seed `b"config"` and the program ID.
    - Calls `initialize_config` and verifies that:
      - The created `Config` account lives exactly at that PDA.
      - The allocated space is big enough for:
        - Discriminator,
        - Admin pubkey,
        - GIFT_SOL mint pubkey,
        - Polygon bridge bytes,
        - Up to 16 extra minters (as configured in the program).

### 2. Minter management – `add_minter` / `remove_minter`

These tests mirror the **relayer / role management** checks that exist on Polygon for
`GiftPolygonBridge.setRelayer`, but on the Solana side for **GIFT_SOL minters**.

- **Admin can add extra minters**
  - **test_AddMinter_ByAdmin_AddsMinterAndDeduplicates**
    - Starts from a fresh `Config`.
    - Calls `add_minter(newMinter)` using `admin` as the signer.
    - Checks that `Config.extra_minters` now contains `newMinter`.
    - Calls `add_minter(newMinter)` again.
    - Confirms there are **no duplicate entries** (the list length does not grow).

- **Admin can remove minters**
  - **test_RemoveMinter_ByAdmin_RemovesMinter**
    - Starts from `extra_minters = [m1, m2]`.
    - Calls `remove_minter(m1)` using `admin` as the signer.
    - Confirms:
      - `m1` is no longer in `extra_minters`.
      - `m2` is still present.

- **Unauthorized callers are rejected**
  - **test_AddMinter_Unauthorized_Reverts**
    - Uses a signer that is **not** `Config.admin`.
    - Calls `add_minter`.
    - Expects a failure with the `UnauthorizedMinter` error.

  - **test_RemoveMinter_Unauthorized_Reverts**
    - Similar to above, but for `remove_minter`.
    - Ensures only `admin` can modify the minter list.

### 3. Polygon → Solana minting – `mint_from_polygon`

These tests are the Solana‑side mirror of Polygon’s `depositToSolana` and
`completeWithdrawalFromSolana` tests, ensuring that when a deposit is relayed, GIFT_SOL is minted
correctly and replays are prevented.

- **Happy path minting**
  - **test_MintFromPolygon_ByAdmin_MintsAndMarksDepositProcessed**
    - Setup:
      - Uses a real SPL GIFT_SOL mint.
      - Initializes `Config` with:
        - `admin` = relayer.
        - `gift_mint` = that mint.
        - `polygon_bridge` = correct address.
      - Creates a recipient token account for GIFT_SOL.
    - Calls `mint_from_polygon(amount, deposit_id)` with:
      - `config` = the config PDA.
      - `gift_mint` = the SPL mint.
      - `mint_authority` = PDA seeded as `["mint_authority", config.key()]`.
      - `recipient_token_account` = the recipient ATA.
      - `processed_deposit` = PDA seeded as `["processed_deposit", deposit_id]`.
      - `admin` = `Config.admin` signer.
    - Verifies:
      - The recipient token account balance increases by `amount`.
      - Total supply of GIFT_SOL increases by `amount`.
      - The `ProcessedDeposit` account is created at the expected PDA and has:
        - `used == true`.
        - `deposit_id` exactly equal to the input.

  - **test_MintFromPolygon_ByExtraMinter_MintsSuccessfully**
    - Setup as above, but calls `add_minter(extraMinter)` first.
    - Uses `extraMinter` as the signer in the `admin` slot.
    - Verifies that the behavior is identical to the admin path:
      - Tokens are minted.
      - The `ProcessedDeposit` PDA is set correctly.

- **Replay and safety checks**
  - **test_MintFromPolygon_ZeroAmount_Reverts**
    - Calls `mint_from_polygon` with `amount = 0`.
    - Expects a failure with the `ZeroAmount` error.

  - **test_MintFromPolygon_UnauthorizedMinter_Reverts**
    - Does **not** configure `extra_minters`.
    - Uses a signer that is not `Config.admin`.
    - Expects a failure with the `UnauthorizedMinter` error.

  - **test_MintFromPolygon_ReplaySameDepositId_Reverts**
    - Calls `mint_from_polygon(amount, deposit_id)` once (success).
    - Attempts to call it again with the **same** `deposit_id`.
    - Expects:
      - Either an account‑creation failure (the PDA already exists), or
      - An explicit `DepositAlreadyProcessed` style error if the implementation is extended.
    - This is the **Solana‑side replay protection**, mirroring Polygon’s `processedBurns` checks.

  - **test_MintFromPolygon_WrongGiftMint_Reverts**
    - Sets `Config.gift_mint = M`, but passes a different mint account `M'`.
    - Expects failure due to the `constraint = gift_mint.key() == config.gift_mint` check.

  - **test_MintFromPolygon_WrongRecipientMint_Reverts**
    - Uses a token account whose `mint` does not match `gift_mint`.
    - Expects failure due to `constraint = recipient_token_account.mint == gift_mint.key()`.

### 4. Solana → Polygon burns – `burn_for_polygon`

These tests ensure that GIFT_SOL burns on Solana behave correctly and emit events that Polygon uses
to release GIFT back to users.

- **Happy path burn**
  - **test_BurnForPolygon_BurnsTokensAndEmitsEvent**
    - Setup:
      - Initializes `Config` with a GIFT_SOL mint.
      - Creates a user token account for GIFT_SOL.
      - Mints some GIFT_SOL to the user (e.g. via a prior `mint_from_polygon` call).
    - Calls `burn_for_polygon(amount, polygon_recipient)` with:
      - `config` = config PDA (enforcing `has_one = gift_mint`).
      - `gift_mint` = the SPL mint.
      - `user_token_account` = the user’s ATA.
      - `user` = owner/signing key.
      - `token_program` = SPL Token program.
    - Verifies:
      - User token balance decreases by exactly `amount`.
      - Total supply of GIFT_SOL decreases by `amount`.
      - The logs include a `BurnForPolygonEvent` with:
        - `user` = caller pubkey.
        - `amount` = burned amount.
        - `polygon_recipient` = the 20‑byte address passed in.
    - This event is what the relayer uses to call `GiftPolygonBridge.completeWithdrawalFromSolana`
      on Polygon.

- **Edge and constraint checks**
  - **test_BurnForPolygon_ZeroAmount_Reverts**
    - Calls `burn_for_polygon(0, someRecipient)`.
    - Expects failure with the `ZeroAmount` error.

  - **test_BurnForPolygon_WrongConfigMint_Reverts**
    - Passes a `gift_mint` account that does not match `Config.gift_mint`.
    - Expects failure because of the `has_one = gift_mint` constraint.

  - **test_BurnForPolygon_WrongTokenMint_Reverts**
    - Uses a user token account whose mint is not `gift_mint`.
    - Expects failure due to `constraint = user_token_account.mint == gift_mint.key()`.

  - **test_BurnForPolygon_WrongTokenOwner_Reverts**
    - Uses a token account whose owner is not the `user` signer.
    - Expects failure due to `constraint = user_token_account.owner == user.key()`.

### 5. Cross‑chain scenarios (Solana ↔ Polygon)

Finally, there are **scenario tests** that line up directly with the flows in
`docs/architecture/gift-crosschain-architecture.md`.

- **Scenario A – Polygon deposit → Solana mint**
  - Polygon side (already covered by existing Foundry tests):
    - User calls `depositToSolana(amount, solanaRecipient)` on `GiftPolygonBridge`.
    - Event `DepositedToSolana(sender, solanaRecipient, amount, nonce)` is emitted.
  - Off‑chain relayer:
    - Computes a unique `deposit_id` encoding `(sender, nonce, chain)`.
  - Solana side (new test):
    - Calls `mint_from_polygon(amount, deposit_id)` for the intended Solana recipient.
    - Verifies:
      - GIFT_SOL balance on Solana equals the deposited amount.
      - `ProcessedDeposit` is marked `used` for that `deposit_id`.

- **Scenario B – Solana burn → Polygon withdrawal**
  - Solana side:
    - User calls `burn_for_polygon(amount, polygon_recipient)`.
    - Off‑chain relayer observes `BurnForPolygonEvent`.
  - Polygon side (already covered in Foundry tests):
    - Relayer calls `completeWithdrawalFromSolana(polygon_recipient, amount, solanaBurnTx)`.
    - `GiftPolygonBridge`:
      - Ensures `solanaBurnTx` has not been processed before.
      - Releases GIFT from its pool to `polygon_recipient`.
  - Invariant:
    - Each **burn on Solana** at most once releases matching **GIFT on Polygon**.

---

## Summary

- The **Polygon side** already has a comprehensive, automated Foundry test suite described in
  `docs/complete-polygon-tests-for-gift-token.md`.
- This document defines a **matching Solana test plan** for the `gift_bridge_solana` program:
  - Config initialization and wiring.
  - Minter management and authorization.
  - Minting GIFT_SOL from Polygon deposits with replay protection.
  - Burning GIFT_SOL and emitting events for Polygon withdrawals.
  - End‑to‑end cross‑chain scenarios consistent with the architecture docs.
- Once implemented as Rust or Anchor TS tests, this plan will ensure the Solana bridge side is
  validated to the same standard as the Polygon contracts.


