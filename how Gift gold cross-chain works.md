# How the GIFT cross-chain system works  
*(Story version for everyone, not just developers)*

## Characters

- **Mamadou** – founder / owner. Decides when more physical gold is added to the vaults and when new GIFT tokens should exist.  
- **Oliver** – CTO. Makes sure that on-chain actions follow policy.  
- **Kassy** – lead developer and security lead. Builds and maintains the smart contracts and cross-chain logic.  
- **GIFT** – gold-backed token on Polygon, where 1 GIFT = 1 mg of physical gold in vaults.  
- **Certificates** – digital certificates (implemented as Non Fungible Tokens under the hood) that represent specific bars or batches of gold.  
- **GIFT Wallet** – the company’s wallet app where users can hold, send, and receive GIFT tokens.

---

## 1. Life starts on Polygon

Everything begins on Polygon, which is the **canonical chain** for GIFT.

1. **Physical gold arrives**

   - Mamadou works with partners to bring new gold into the vaults.
   - When physical gold arrives, it is documented: vault location, bar details, weights, and supporting documents.

2. **Proof-of-Reserve is updated**

   - Auditors and operations update the **Proof-of-Reserve contract (GIFTPoR)** on Polygon.
   - This on-chain ledger records:
     - How much gold is in each vault.
     - How much of that gold is available to back tokens.
   - The numbers here are what the minting logic trusts.

3. **Decision to mint new GIFT**

   - Mamadou decides: “We have more physical gold; we need more GIFT tokens so users can access that value.”
   - Mamadou tells Oliver: “We have X mg of new gold; let’s mint GIFT against it.”
   - Oliver coordinates with Kassy to execute this carefully.

4. **Multi-signature approval**

   - Minting GIFT is **not** something a single person can do.
   - The company uses a **multi-signature wallet** on Polygon.  
   - For new minting operations, **Mamadou, Oliver, and Kassy all review and sign** the transaction so that:
     - The transaction is only executed when everyone has agreed.
     - There is a clear on-chain record that the owners and CTO and lead developer approved.

5. **Minting contract checks Proof-of-Reserve**

   - The **MintingUpgradeable** contract is the only contract allowed to create new GIFT tokens.
   - Before it mints anything, it checks:
     - Are we a registered minter in the Proof-of-Reserve contract?  
     - Do we still have enough allowance for this vault and reserve?  
     - Does the vault’s reserve balance cover the amount we want to mint?

6. **New GIFT tokens exist on Polygon**

   - Once all checks pass and the multi-signature is signed:
     - The minting contract increases the GIFT supply on Polygon.
     - GIFT tokens are minted to a chosen address (for example, a treasury or distribution wallet).
   - Users can then receive GIFT into their **GIFT Wallet** or other Polygon wallets, and:
     - Send and receive GIFT.  
     - Use GIFT in DeFi protocols that integrate it.  
     - Swap GIFT for other assets on Polygon.

---

## 2. Certificates: tying specific gold bars to tokens

While GIFT tokens represent claim to the *pool* of vaulted gold, some users want more specific gold bar claims: **certificates** that refer to specific bars or batches.

1. **Batch registry**

   - For each batch of gold, the team registers it in the **GIFTBatchRegistry** on Polygon.
   - This includes:
     - A merkle root representing all bars in the batch.
     - The total cap (maximum amount of tokens that can be associated with that batch).
     - Dataset links and hashed data for serial numbers, mines, standards, and documents.

2. **Certificates created from batches**

   - From this registry, the system can create **digital certificates** that correspond to:
     - A particular batch of gold.
     - A specific weight (e.g. 10 grams, 100 grams) in mg units.
     - Associated bar / serial information.

3. **Buying a certificate with GIFT**

   - When a user uses GIFT tokens to buy a certificate:
     - GIFT tokens move from the user’s wallet into a dedicated **escrow contract** on Polygon.
     - The escrow contract records:
       - “This certificate with ID X is backed by Y GIFT tokens, representing Y mg of gold.”
     - The user receives the certificate in their wallet.

4. **Redeeming certificates for physical gold**

   - Later, if the user wants **physical gold**:
     - They send the certificate back into the escrow contract.
     - The company verifies the request and ships the physical bar or equivalent gold to the user.
     - Once delivery is confirmed:
       - The escrow contract calls the minting logic to **burn** the corresponding GIFT tokens from escrow.
       - The certificate is destroyed or permanently locked so it cannot be used again.

This ensures:

- Physical gold leaves the vault.  
- The associated GIFT tokens and certificate are removed from circulation.  
- The Proof-of-Reserve and token supply stay aligned.

All of this, so far, happens on Polygon.

---

## 3. Solana users want GIFT too

As the ecosystem grows, GIFT is actively used on Polygon. However:

- Solana users, wallets, and protocols also want to work with GIFT.  
- They ask: “How can we get GIFT tokens on Solana without breaking the backing on Polygon?”

The key requirements:

- **Polygon must remain the source of truth**:
  - Minting tied to Proof-of-Reserve.
  - Certificates and physical redemption flow through Polygon.
- Solana should have GIFT tokens that:
  - Are always backed 1:1 by tokens locked on Polygon.
  - Can be held and traded just like on Polygon.

---

## 4. Kassy sets up the cross-chain bridge

To extend GIFT to Solana without compromising its backing, the team adds a **bridge**.

### 4.1. Bridge contract on Polygon

1. Kassy deploys a **bridge contract** on Polygon: `GiftPolygonBridge`.

2. This bridge contract:

   - Accepts GIFT tokens from users or from company wallets.  
   - Holds those GIFT tokens in a **locked pool**.  
     - They are not burned, but they are not in normal circulation; they are parked inside the bridge.  
   - Emits events whenever GIFT tokens are deposited for bridging to Solana.

3. At this point:

   - Some portion of GIFT can be voluntarily moved into the bridge and locked.  
   - This locked amount is what will back GIFT tokens on Solana.

### 4.2. Bridge program on Solana

1. On Solana, Kassy deploys a **bridge program** called `gift_bridge_solana`.

2. This program:

   - Is linked to a **GIFT SPL token mint** on Solana.  
     - The SPL mint uses:
       - Name: `"GIFT"`  
       - Symbol: `"GIFT"`  
       - Decimals: `18` (to match Polygon’s token units).
   - Knows which Polygon bridge contract it corresponds to.  
   - Can:
     - Mint GIFT tokens on Solana **only when a valid deposit event has been confirmed on Polygon**.  
     - Burn GIFT tokens on Solana when users want to move tokens back to Polygon.

Solana thus becomes a second home for GIFT, but it is always tied to the locked supply on Polygon.

---

## 5. The relayer: “connecting the dots” between chains

Polygon and Solana cannot talk to each other directly. They don’t read each other’s balances or events.

Instead, the team runs a small off-chain component called the **relayer**.

1. The relayer is a **small program** (for example, written in Node/TypeScript) that:

   - Listens to events on Polygon (from `GiftPolygonBridge`).  
   - Listens to events on Solana (from `gift_bridge_solana`).  
   - When it sees a deposit on Polygon:
     - It calls the Solana program to mint the corresponding amount of GIFT to the target Solana address.  
   - When it sees a burn on Solana:
     - It calls the Polygon bridge to release the corresponding GIFT back to a Polygon address.

2. The relayer has its own keys:

   - A Polygon key that is authorised as **relayer** in `GiftPolygonBridge`.  
   - A Solana key that sends transactions to the Solana program.

3. These keys are managed by the team:

   - They live in secure environment files or key management systems, **not** inside the public repository.  
   - On-chain, the relayer address has limited powers:
     - On Polygon, it can only move GIFT out of the **bridge pool** to users, not mint new GIFT.  
     - On Solana, it interacts with the bridge program following strict logic.

4. The relayer can run in two modes:

   - **Manual mode** (early stage):
     - When a bridging operation is needed, Kassy (or Oliver) runs the relayer locally.
     - The relayer processes all pending deposits and burns, then stops.  
   - **Automatic mode** (later, if needed):
     - The relayer runs on a server, continuously processing events.
     - The bridge contract on Polygon still has a pause function so the team can halt the bridge if anything looks suspicious.

---

## 6. Full story: bringing GIFT from Polygon to Solana

Let’s walk through a full example.

1. **Physical gold added and new GIFT minted on Polygon**

   - Mamadou organizes new gold for the vaults.  
   - Proof-of-Reserve is updated to reflect the new gold.  
   - Mamadou, Oliver, and Kassy **all sign** the multi-signature transaction to approve new minting.  
   - The minting contract checks the reserves and then mints new GIFT on Polygon.

2. **Users receive GIFT on Polygon**

   - GIFT tokens are distributed or sold on Polygon.  
   - Users hold GIFT in their GIFT Wallet and can:
     - Transfer it.  
     - Use it in DeFi.  
     - Purchase certificates tied to specific bars via the registry and escrow system.

3. **Company decides to seed GIFT on Solana**

   - Oliver and Kassy decide: “We want GIFT on Solana so Solana users and exchanges can use it.”  
   - They choose some amount of GIFT (let’s say from a company-controlled Polygon wallet) to move across.

4. **GIFT is deposited into the Polygon bridge**

   - Using the company’s Polygon wallet:
     - GIFT tokens are sent into the `GiftPolygonBridge` contract.  
   - Those tokens are now locked inside the bridge. They are still GIFT on Polygon but parked and not in normal circulation.

5. **Relayer mints GIFT on Solana**

   - The relayer sees the `DepositedToSolana` event from the Polygon bridge.  
   - It calls `mintFromPolygon` on the Solana bridge program.  
   - The Solana bridge program mints the same amount of GIFT tokens (SPL form) to the chosen Solana address (this could be:
     - The company’s Solana wallet,
     - A Solana exchange,
     - Or another designated wallet).

6. **Now GIFT exists in both ecosystems**

   - On Polygon:
     - GIFT supply is the same, but part of it is locked in the bridge.  
   - On Solana:
     - An equal amount of GIFT has been minted and is freely usable.

Because the Solana GIFT is always backed by GIFT locked in the Polygon bridge, the overall system remains backed by the same physical reserves.

---

## 7. Full story: going back from Solana to Polygon

Now suppose a Solana user wants to move back to Polygon.

1. They hold GIFT on Solana (the SPL token).  

2. In the Solana UI or dApp, they choose to “bridge back to Polygon” and enter their Polygon address.

3. The Solana bridge program:

   - Burns GIFT tokens from their Solana wallet.  
   - Emits an event indicating:
     - How much was burned.
     - Which Polygon address should receive the tokens.

4. The relayer sees this event on Solana, and calls `completeWithdrawalFromSolana` on the Polygon bridge contract.

5. The Polygon bridge contract:

   - Releases the corresponding amount of GIFT tokens from its locked pool to the user’s Polygon address.

6. The user now has GIFT on Polygon and can:

   - Send it in the GIFT Wallet.  
   - Use it in Polygon DeFi.  
   - Spend it on certificates that can be redeemed for physical gold.

Once back on Polygon, the usual certificate + escrow redemption flow applies.

---

## 8. Big-picture summary

- **Minting and backing**:
  - Mamadou, Oliver, and Kassy only allow new GIFT to be minted when the on-chain Proof-of-Reserve confirms enough physical gold in the vaults.
  - All three review and sign via multi-signature.

- **Certificates and redemption**:
  - Users can use GIFT to buy certificates that represent specific bars or batches.
  - Certificates are backed by locked GIFT in escrow.
  - When redeemed for physical gold, both the certificate and the corresponding GIFT tokens are destroyed.

- **Cross-chain**:
  - Polygon remains the canonical home of GIFT, Proof-of-Reserve, and certificates.
  - The Solana side is a second environment where GIFT exists as a token, always backed by GIFT locked in the Polygon bridge.
  - A small relayer program (run by the team) connects Polygon and Solana by:
    - Observing bridge events on each side.
    - Calling the appropriate contract/program on the other side.

- **User experience**:
  - Polygon users interact with GIFT and certificates directly in the GIFT Wallet and dApps.
  - Solana users and Solana-based exchanges have access to GIFT on Solana through the bridge, while the underlying reserves and redemption logic stay anchored on Polygon.

This document describes how GIFT moves across chains and how the team keeps it backed and consistent, from physical vaults to Polygon to Solana and back.
