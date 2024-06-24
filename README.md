# GIFT Smart Contract: Comprehensive User Manual

This manual provides detailed instructions for interacting with the GIFT smart contract. It covers all functions, including read-only functions, with specific input requirements.

## General Information

- Contract Name: GIFT
- Token Symbol: GIFT
- Decimals: 18 (1 GIFT = 1,000,000,000,000,000,000 wei)

## Write Functions

### 1. transfer

**Purpose:** Send GIFT tokens to another address.

**Inputs:**
- recipient (address): The receiving address
- amount (uint256): Number of tokens to send (in wei)

**Example:**
- recipient: 0x742d35Cc6634C0532925a3b844Bc454e4438f44e
- amount: 1000000000000000000 (1 GIFT)

### 2. transferFrom

**Purpose:** Transfer tokens on behalf of another address.

**Inputs:**
- sender (address): Address sending tokens
- recipient (address): Address receiving tokens
- amount (uint256): Number of tokens to send (in wei)

**Example:**
- sender: 0x123...
- recipient: 0x456...
- amount: 500000000000000000 (0.5 GIFT)

### 3. approve

**Purpose:** Approve an address to spend tokens on your behalf.

**Inputs:**
- spender (address): Address to approve
- amount (uint256): Maximum number of tokens they can spend (in wei)

**Example:**
- spender: 0x789...
- amount: 10000000000000000000 (10 GIFT)

### 4. delegateTransfer (Manager Only)

**Purpose:** Allow a manager to transfer tokens on behalf of another user.

**Inputs:**
- signature (bytes): Cryptographic signature from the token owner
- delegator (address): Address of the token owner
- recipient (address): Address receiving tokens
- amount (uint256): Number of tokens to transfer (in wei)
- networkFee (uint256): Fee paid to the manager (in wei)

**Note:** This function requires off-chain signature generation and is typically used by authorized managers only.

### 5. increaseSupply (Supply Controller Only)

**Purpose:** Mint new GIFT tokens.

**Inputs:**
- _value (uint256): Number of tokens to mint (in wei)

### 6. redeemGold (Supply Controller Only)

**Purpose:** Burn GIFT tokens from a user's address.

**Inputs:**
- _userAddress (address): Address to burn tokens from
- _value (uint256): Number of tokens to burn (in wei)

### 7. pause (Owner Only)

**Purpose:** Pause all token transfers.

**Inputs:** None

### 8. unpause (Owner Only)

**Purpose:** Unpause all token transfers.

**Inputs:** None

### 9. setFeeExclusion (Owner Only)

**Purpose:** Set whether an address is excluded from transfer fees.

**Inputs:**
- _address (address): Address to update
- _isExcludedOutbound (bool): true to exclude from outbound fees, false otherwise
- _isExcludedInbound (bool): true to exclude from inbound fees, false otherwise

**Example:**
- _address: 0xabc...
- _isExcludedOutbound: true
- _isExcludedInbound: false

### 10. setLiquidityPool (Owner Only)

**Purpose:** Designate an address as a liquidity pool.

**Inputs:**
- _liquidityPool (address): Address of the liquidity pool
- _isPool (bool): true to set as a liquidity pool, false to unset

**Example:**
- _liquidityPool: 0xdef...
- _isPool: true

### 11. setSupplyController (Owner Only)

**Purpose:** Set a new supply controller address.

**Inputs:**
- _newSupplyController (address): Address of the new supply controller

### 12. setBeneficiary (Owner Only)

**Purpose:** Set a new beneficiary address for receiving transfer taxes.

**Inputs:**
- _newBeneficiary (address): Address of the new beneficiary

### 13. setManager (Owner Only)

**Purpose:** Set or unset an address as a manager.

**Inputs:**
- _manager (address): Address to update
- _isManager (bool): true to set as manager, false to unset

### 14. updateTaxPercentages (Owner Only)

**Purpose:** Update the tax percentages for different tiers.

**Inputs:**
- _tierOneTaxPercentage (uint256): New tax percentage for tier one
- _tierTwoTaxPercentage (uint256): New tax percentage for tier two
- _tierThreeTaxPercentage (uint256): New tax percentage for tier three
- _tierFourTaxPercentage (uint256): New tax percentage for tier four
- _tierFiveTaxPercentage (uint256): New tax percentage for tier five

**Note:** Tax percentages are in basis points (e.g., 1000 = 10%)

### 15. updateTaxTiers (Owner Only)

**Purpose:** Update the maximum amounts for each tax tier.

**Inputs:**
- _tierOneMax (uint256): New maximum amount for tier one (in wei)
- _tierTwoMax (uint256): New maximum amount for tier two (in wei)
- _tierThreeMax (uint256): New maximum amount for tier three (in wei)
- _tierFourMax (uint256): New maximum amount for tier four (in wei)

## Read Functions

### 1. balanceOf

**Purpose:** Check the token balance of an address.

**Inputs:**
- account (address): Address to check

**Returns:** uint256 (balance in wei)

### 2. allowance

**Purpose:** Check how many tokens an address can spend on behalf of another.

**Inputs:**
- owner (address): Token owner's address
- spender (address): Address approved to spend

**Returns:** uint256 (allowance in wei)

### 3. totalSupply

**Purpose:** View the total number of GIFT tokens in circulation.

**Inputs:** None

**Returns:** uint256 (total supply in wei)

### 4. owner

**Purpose:** See the address of the contract owner.

**Inputs:** None

**Returns:** address

### 5. supplyController

**Purpose:** View the address of the supply controller.

**Inputs:** None

**Returns:** address

### 6. beneficiary

**Purpose:** Check the address receiving transfer taxes.

**Inputs:** None

**Returns:** address

### 7. paused

**Purpose:** Check if transfers are currently paused.

**Inputs:** None

**Returns:** bool (true if paused, false if not)

### 8. isExcludedFromOutboundFees

**Purpose:** Check if an address is excluded from outbound fees.

**Inputs:**
- account (address): Address to check

**Returns:** bool (true if excluded, false if not)

### 9. isExcludedFromInboundFees

**Purpose:** Check if an address is excluded from inbound fees.

**Inputs:**
- account (address): Address to check

**Returns:** bool (true if excluded, false if not)

### 10. isLiquidityPool

**Purpose:** Check if an address is designated as a liquidity pool.

**Inputs:**
- account (address): Address to check

**Returns:** bool (true if liquidity pool, false if not)

### 11. isManager

**Purpose:** Check if an address is a manager.

**Inputs:**
- account (address): Address to check

**Returns:** bool (true if manager, false if not)

### 12. computeTax

**Purpose:** Calculate the tax for a given transfer amount.

**Inputs:**
- _transferAmount (uint256): Amount to calculate tax for (in wei)

**Returns:** uint256 (tax amount in wei)

### 13. getLatestReserve

**Purpose:** Get the latest reserve value from the Chainlink oracle.

**Inputs:** None

**Returns:** int256 (latest reserve value)

### 14. decimals

**Purpose:** Get the number of decimals for the token.

**Inputs:** None

**Returns:** uint8 (18 for GIFT)

### 15. name

**Purpose:** Get the name of the token.

**Inputs:** None

**Returns:** string ("GIFT")

### 16. symbol

**Purpose:** Get the symbol of the token.

**Inputs:** None

**Returns:** string ("GIFT")

## How to Interact with the Contract

1. Connect your wallet to Etherscan or Remix.
2. Navigate to the contract's page.
3. For write functions:
   - Go to the "Write Contract" section.
   - Find the function you want to use.
   - Enter the required inputs.
   - Click "Write" and confirm the transaction in your wallet.
4. For read functions:
   - Go to the "Read Contract" section.
   - Find the function you want to query.
   - Enter any required inputs.
   - Click "Query" to see the result.

## Important Notes

- Always double-check addresses and amounts before confirming transactions.
- Transfer taxes may apply unless your address is excluded.
- If unsure about a function, seek clarification before using it.
- Some functions are restricted to specific roles (Owner, Supply Controller, Manager).
