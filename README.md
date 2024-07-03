# GIFT Smart Contract: Comprehensive User Manual

This manual provides detailed instructions for interacting with the GIFT smart contract. It covers all functions, including read-only functions, with specific input requirements.

## General Information
- **Contract Name**: GIFT
- **Token Symbol**: GIFT
- **Decimals**: 18 (1 GIFT = 1,000,000,000,000,000,000 wei)

## Tax Structure
### Tax Tiers and Percentages:
- **Tier One**: For transfers up to `tierOneMax` (2000 * 10^18 tokens), the tax rate is `tierOneTaxPercentage` (1618 basis points or 16.18%).
- **Tier Two**: For transfers between `tierOneMax` and `tierTwoMax` (10000 * 10^18 tokens), the tax rate is `tierTwoTaxPercentage` (1200 basis points or 12%).
- **Tier Three**: For transfers between `tierTwoMax` and `tierThreeMax` (20000 * 10^18 tokens), the tax rate is `tierThreeTaxPercentage` (1000 basis points or 10%).
- **Tier Four**: For transfers between `tierThreeMax` and `tierFourMax` (200000 * 10^18 tokens), the tax rate is `tierFourTaxPercentage` (500 basis points or 5%).
- **Tier Five**: For transfers exceeding `tierFourMax`, the tax rate is `tierFiveTaxPercentage` (300 basis points or 3%).

### Tax Calculation:
- The function `computeTax(uint256 _transferAmount)` determines the tax amount based on the transfer amount and the applicable tax tier.
- The tax is calculated as: `tax = _transferAmount * taxPercentage / 100000`, where `taxPercentage` is based on the tier.

### Fee Exclusion:
Here's a detailed, line-by-line explanation of the `_transferGIFT` function in the GIFT smart contract, focusing on how tax is handled:

```solidity
function _transferGIFT(
    address sender,
    address recipient,
    uint256 amount
) internal virtual returns (bool) {
```
1. This is an internal function named `_transferGIFT` that takes three parameters: the sender's address, the recipient's address, and the amount to transfer.
2. It's marked as `virtual`, allowing it to be overridden in derived contracts.
3. The function returns a boolean value.

```solidity
    uint256 tax = 0;
```
4. Initializes a `tax` variable to keep track of the total tax amount.

```solidity
    if (
        !isExcludedFromOutboundFees[sender] && !_isLiquidityPool[recipient]
    ) {
```
5. Checks if the sender is not excluded from outbound fees and the recipient is not a liquidity pool.

```solidity
        uint256 outboundTax = computeTax(amount);
        tax += outboundTax;
        _transfer(sender, beneficiary, outboundTax);
    }
```
6. If the condition is true, it calculates the outbound tax using the `computeTax` function.
7. Adds the outbound tax to the total tax.
8. Transfers the outbound tax amount from the sender to the beneficiary address.

```solidity
    if (!isExcludedFromInboundFees[recipient] && !_isLiquidityPool[sender]) {
```
9. Checks if the recipient is not excluded from inbound fees and the sender is not a liquidity pool.

```solidity
        uint256 inboundTax = computeTax(amount - tax);
        tax += inboundTax;
        _transfer(sender, beneficiary, inboundTax);
    }
```
10. If the condition is true, it calculates the inbound tax on the remaining amount after outbound tax.
11. Adds the inbound tax to the total tax.
12. Transfers the inbound tax amount from the sender to the beneficiary address.

```solidity
    _transfer(sender, recipient, amount - tax);
```
13. Transfers the remaining amount (original amount minus total tax) from the sender to the recipient.

```solidity
    return true;
}
```
14. Returns `true` to indicate that the transfer was successful.

#### Summary

The `_transferGIFT` function implements a complex tax system for token transfers, applying different taxes based on whether the sender or recipient is excluded from fees or if they are liquidity pools. The taxes are sent to a beneficiary address, and the remaining amount after taxes is transferred to the recipient. This ensures that the contract can handle taxes dynamically while allowing certain addresses to be excluded from these fees.

## Roles and Modifiers
### Supply Controller(minting smart contract)
- **Modifier**: `onlySupplyController`
- **Functions**: Manages the supply of tokens, including minting and burning tokens.
- **Responsibilities**:
  - Minting new tokens to user addresses.
  - Burning tokens from user addresses.

### Supply Manager
- **Modifier**: `onlySupplyManager`
- **Functions**: Manages the overall token supply by minting tokens to the supply manager's address.
- **Responsibilities**:
  - Inflating the supply by minting new tokens.

### Tax Officer
- **Modifier**: `onlyTaxOfficer`
- **Functions**: Manages tax-related settings and updates tax percentages and tiers.
- **Responsibilities**:
  - Updating tax percentages for different tiers.
  - Updating the maximum transfer amounts for each tax tier.

### Manager
- **Modifier**: `onlyManager`
- **Functions**: Encompasses general managerial permissions, allowing the execution of various administrative functions.
- **Responsibilities**:
  - Performing delegate transfers.

### Owner or Tax Officer
- **Modifier**: `onlyOwnerOrTaxOfficer`
- **Functions**: Allows either the owner or the tax officer to perform certain actions.
- **Responsibilities**:
  - Updating tax percentages and tiers.
  - Setting fee exclusions.

## Function Descriptions
### 1. `initialize`
- **Purpose**: Initializes the contract with necessary parameters.
- **Parameters**:
  - `_aggregatorInterface`: Address of the reserve feed aggregator.
  - `_initialHolder`: Address that receives the initial supply of tokens.

### 2. `computeTax`
- **Purpose**: Calculates the tax based on the transfer amount and the applicable tax tier.
- **Parameters**:
  - `_transferAmount`: The amount being transferred.
- **Returns**: The calculated tax amount.

### 3. `getChainID`
- **Purpose**: Retrieves the chain ID of the blockchain on which the contract is deployed.
- **Returns**: The chain ID as a `uint256` value.

### 4. `delegateTransferProof`
- **Purpose**: Generates a hash for the delegate transfer proof.
- **Parameters**:
  - `token`: Token identifier.
  - `delegator`: Address of the delegator.
  - `spender`: Address of the spender.
  - `amount`: The amount to be transferred.
  - `networkFee`: The network fee for the transfer.
- **Returns**: A hash representing the delegate transfer proof.

### 5. `updateTaxPercentages`
- **Purpose**: Updates the tax percentages for different tiers.
- **Parameters**:
  - `_tierOneTaxPercentage`, `_tierTwoTaxPercentage`, `_tierThreeTaxPercentage`, `_tierFourTaxPercentage`, `_tierFiveTaxPercentage`: New tax percentages for the respective tiers.
- **Access**: Only callable by the owner or tax officer.

### 6. `updateTaxTiers`
- **Purpose**: Updates the maximum transfer amounts for different tax tiers.
- **Parameters**:
  - `_tierOneMax`, `_tierTwoMax`, `_tierThreeMax`, `_tierFourMax`: New maximum amounts for the respective tiers.
- **Access**: Only callable by the owner or tax officer.

### 7. `setSupplyController`
- **Purpose**: Sets a new supply controller.
- **Parameters**:
  - `_newSupplyController`: Address of the new supply controller.
- **Access**: Only callable by the owner.

### 8. `setSupplyManager`
- **Purpose**: Sets a new supply manager.
- **Parameters**:
  - `_newSupplyManager`: Address of the new supply manager.
- **Access**: Only callable by the owner.

### 9. `setTaxOfficer`
- **Purpose**: Sets a new tax officer.
- **Parameters**:
  - `_newTaxOfficer`: Address of the new tax officer.
- **Access**: Only callable by the owner.

### 10. `setBeneficiary`
- **Purpose**: Sets a new beneficiary address to receive the collected taxes.
- **Parameters**:
  - `_newBeneficiary`: Address of the new beneficiary.
- **Access**: Only callable by the owner.

### 11. `setFeeExclusion`
- **Purpose**: Sets fee exclusion statuses for a specific address.
- **Parameters**:
  - `_address`: Address to set exclusions for.
  - `_isExcludedOutbound`: Boolean indicating outbound fee exclusion status.
  - `_isExcludedInbound`: Boolean indicating inbound fee exclusion status.
- **Access**: Only callable by the owner or tax officer.

### 12. `setLiquidityPool`
- **Purpose**: Marks an address as a liquidity pool.
- **Parameters**:
  - `_liquidityPool`: Address to mark as a liquidity pool.
  - `_isPool`: Boolean indicating if the address is a liquidity pool.
- **Access**: Only callable by the owner.

### 13. `inflateSupply`
- **Purpose**: Mints new tokens to the supply manager's address.
- **Parameters**:
  - `_value`: Amount of tokens to mint.
- **Access**: Only callable by the supply manager.

### 14. `increaseSupply`
- **Purpose**: Mints new tokens to a specific user address.
- **Parameters**:
  - `_userAddress`: Address to mint tokens to.
  - `_value`: Amount of tokens to mint.
- **Access**: Only callable by the supply controller.

### 15. `redeemGold`
- **Purpose**: Burns tokens from a specific user address.
- **Parameters**:
  - `_userAddress`: Address from which to burn tokens.
  - `_value`: Amount of tokens to burn.
- **Access**: Only callable by the supply controller.

### 16. `pause`
- **Purpose**: Pauses the contract, preventing any token transfers.
- **Access**: Only callable by the owner.

### 17. `unpause`
- **Purpose**: Unpauses the contract, allowing token transfers to resume.
- **Access**: Only callable by the owner.

### 18. `setManager`
- **Purpose**: Sets the manager status for a specific address.
- **Parameters**:
  - `_manager`: Address to set as manager.
  - `_isManager`: Boolean indicating if the address is a manager.
- **Access**: Only callable by the owner.

### 19. `transfer`
- **Purpose**: Transfers tokens from the sender to the recipient, including tax handling.
- **Parameters**:
  - `recipient`: Address to receive the tokens.
  - `amount`: Amount of tokens to transfer.
- **Overrides**: Standard ERC-20 `transfer` function.
- **Conditions**: Can only be called when the contract is not paused.

### 20. `transferFrom`
- **Purpose**: Transfers tokens from one address to another on behalf of the sender, including tax handling.
- **Parameters**:
  - `sender`: Address sending the tokens.
  - `recipient`: Address to receive the tokens.
  - `amount`: Amount of tokens to transfer.
- **Overrides**: Standard ERC-20 `transferFrom` function.
- **Conditions**: Can only be called when the contract is not paused.

### 21. `recoverSigner`
- **Purpose**: Recovers the signer address from a given message and signature.
- **Parameters**:
  - `message`: The message hash.
  - `signature`: The signature.
- **Returns**: The address of the signer.
- **Internal**: Only used within the contract for delegate transfer verification.

### 22. `delegateTransfer`
- **Purpose**: Allows managers to perform delegate transfers on behalf of other users, including fee handling.
- **Parameters**:
  - `signature`: Signature of the delegator.
  - `delegator`: Address of the delegator.
  - `recipient`: Address to receive the tokens.
  - `amount`: Amount of tokens to transfer.
  - `networkFee`: Network fee for the transfer.
- **Access**: Only callable by managers.
- **Conditions**: Can only be called when the contract is not paused.

### 23. `_transferGIFT`
- **Purpose**: Internal function to handle token transfers with tax calculations.
- **Parameters**:
  - `sender`: Address sending the tokens.
  - `recipient`: Address to receive the tokens.
  - `amount`: Amount of tokens to transfer.
- **Internal**: Manages the calculation and distribution of taxes during transfers.

### 24. `_authorizeUpgrade`
- **Purpose**: Authorizes an upgrade to a new implementation of the contract.
- **Parameters**:
  - `newImplementation`: Address of the new implementation.
- **Access**: Only callable by the owner.

### 25. `decimals`
- **Purpose**: Retrieves the number of decimal places used by the token.
- **Returns**: Number of decimals as a `uint8` value.
- **Overrides**: Standard ERC-20 `decimals` function to ensure consistency with the upgradeable contract structure.

## User Manual for End Users

### 1. `transfer`
- **Purpose**: Send GIFT tokens to another address.
- **Inputs**:
  - `recipient` (address): The receiving address.
  - `amount` (uint256): Number of tokens to send (in wei).
- **Example**:
  - recipient: `0x742d35Cc6634C0532925a3b844Bc454e4438f44e`
  - amount: `1000000000000000000` (1 GIFT)

### 2. `transferFrom`
- **Purpose**: Transfer tokens on behalf of another address.
- **Inputs**:
  - `sender` (address): Address sending tokens.
  - `recipient` (address): Address receiving tokens.
  - `amount` (uint256): Number of tokens to send (in wei).
- **Example**:
  - sender: `0x123...`
  - recipient: `0x456...`
  - amount: `500000000000000000` (0.5 GIFT)

### 3. `setSupplyController`
- **Purpose**: Set a new supply controller.
- **Inputs**:
  - `newSupplyController` (address): Address of the new supply controller.
- **Example**:
  - newSupplyController: `0x987...`

### 4. `setSupplyManager`
- **Purpose**: Set a new supply manager.
- **Inputs**:
  - `newSupplyManager` (address): Address of the new supply manager.
- **Example**:
  - newSupplyManager: `0xabc...`

### 5. `setTaxOfficer`
- **Purpose**: Set a new tax officer.
- **Inputs**:
  - `newTaxOfficer` (address): Address of the new tax officer.
- **Example**:
  - newTaxOfficer: `0xdef...`

### 6. `setBeneficiary`
- **Purpose**: Set a new beneficiary address to receive collected taxes.
- **Inputs**:
  - `newBeneficiary` (address): Address of the new beneficiary.
- **Example**:
  - newBeneficiary: `0xghi...`

### 7. `setFeeExclusion`
- **Purpose**: Set fee exclusion statuses for a specific address.
- **Inputs**:
  - `address` (address): Address to set exclusions for.
  - `isExcludedOutbound` (bool): Outbound fee exclusion status.
  - `isExcludedInbound` (bool): Inbound fee exclusion status.
- **Example**:
  - address: `0xjkl...`
  - isExcludedOutbound: `true`
  - isExcludedInbound: `false`

### 8. `setLiquidityPool`
- **Purpose**: Mark an address as a liquidity pool.
- **Inputs**:
  - `liquidityPool` (address): Address to mark as a liquidity pool.
  - `isPool` (bool): Boolean indicating if the address is a liquidity pool.
- **Example**:
  - liquidityPool: `0xmn...`
  - isPool: `true`

### 9. `inflateSupply`
- **Purpose**: Mint new tokens to the supply manager's address.
- **Inputs**:
  - `value` (uint256): Amount of tokens to mint (in wei).
- **Example**:
  - value: `1000000000000000000000` (1000 GIFT)

### 10. `increaseSupply`
- **Purpose**: Mint new tokens to a specific user address.
- **Inputs**:
  - `userAddress` (address): Address to mint tokens to.
  - `value` (uint256): Amount of tokens to mint (in wei).
- **Example**:
  - userAddress: `0xopq...`
  - value: `500000000000000000000` (500 GIFT)

### 11. `redeemGold`
- **Purpose**: Burn tokens from a specific user address.
- **Inputs**:
  - `userAddress` (address): Address from which to burn tokens.
  - `value` (uint256): Amount of tokens to burn (in wei).
- **Example**:
  - userAddress: `0xrst...`
  - value: `200000000000000000000` (200 GIFT)

### 12. `pause`
- **Purpose**: Pause the contract, preventing any token transfers.
- **No Inputs Required**

### 13. `unpause`
- **Purpose**: Unpause the contract, allowing token transfers to resume.
- **No Inputs Required**

### 14. `setManager`
- **Purpose**: Set the manager status for a specific address.
- **Inputs**:
  - `manager` (address): Address to set as manager.
  - `isManager` (bool): Boolean indicating if the address is a manager.
- **Example**:
  - manager: `0xuvw...`
  - isManager: `true`

### 15. `delegateTransfer`
- **Purpose**: Perform delegate transfers on behalf of other users, including fee handling.
- **Inputs**:
  - `signature` (bytes): Signature of the delegator.
  - `delegator` (address): Address of the delegator.
  - `recipient` (address): Address to receive the tokens.
  - `amount` (uint256): Amount of tokens to transfer (in wei).
  - `networkFee` (uint256): Network fee for the transfer (in wei).
- **Example**:
  - signature: `0x...`
  - delegator: `0xabc...`
  - recipient: `0xdef...`
  - amount: `1000000000000000000` (1 GIFT)
  - networkFee: `1000000000000000` (0.001 GIFT)

### 16. `updateTaxPercentages`
- **Purpose**: Update the tax percentages for different tiers.
- **Inputs**:
  - `tierOneTaxPercentage` (uint256): New tax percentage for tier one.
  - `tierTwoTaxPercentage` (uint256): New tax percentage for tier two.
  - `tierThreeTaxPercentage` (uint256): New tax percentage for tier three.
  - `tierFourTaxPercentage` (uint256): New tax percentage for tier four.
  - `tierFiveTaxPercentage` (uint256): New tax percentage for tier five.
- **Example**:
  - tierOneTaxPercentage: `1500`
  - tierTwoTaxPercentage: `1200`
  - tierThreeTaxPercentage: `1000`
  - tierFourTaxPercentage: `500`
  - tierFiveTaxPercentage: `300`

### 17. `updateTaxTiers`
- **Purpose**: Update the maximum transfer amounts for different tax tiers.
- **Inputs**:
  - `tierOneMax` (uint256): New maximum amount for tier one (in wei).
  - `tierTwoMax` (uint256): New maximum amount for tier two (in wei).
  - `tierThreeMax` (uint256): New maximum amount for tier three (in wei).
  - `tierFourMax` (uint256): New maximum amount for tier four (in wei).
- **Example**:
  - tierOneMax: `2000000000000000000000` (2000 GIFT)
  - tierTwoMax: `10000000000000000000000` (10000 GIFT)
  - tierThreeMax: `20000000000000000000000` (20000 GIFT)
  - tierFourMax: `200000000000000000000000` (200000 GIFT)

This manual provides the essential information needed for users to interact with the GIFT token contract. Each function is described with its purpose, required inputs, and an example for clarity.
