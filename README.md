# GIFT Token Contract Interaction Manual

This guide explains how to interact with each function of the GIFT Token contract through interfaces like Remix or Etherscan.

## General Input Guidelines:
- Address inputs: Use the full Ethereum address starting with "0x" (e.g., 0x123...abc)
- Boolean inputs: Use "true" or "false" (without quotes)
- Integer inputs: Enter the number directly without quotes (e.g., 1000)
- String inputs: Enter text without quotes (e.g., GIFT Token)

## Function Inputs Guide:

1. initialize
   - name: Enter the token name (e.g., GIFT Token)
   - symbol: Enter the token symbol (e.g., GIFT)
   - _supplyController: Enter the address of the supply controller
   - _beneficiary: Enter the address of the beneficiary
   - _reserveConsumer: Enter the address of the reserve consumer

2. setTaxParameters
   - _tiers: Enter five uint256 values separated by commas (e.g., 1000000000000000000000,5000000000000000000000,10000000000000000000000,50000000000000000000000,115792089237316195423570985008687907853269984665640564039457584007913129639935)
   - _percentages: Enter five uint256 values separated by commas (e.g., 1000,800,600,400,200)

3. setSupplyController
   - _newSupplyController: Enter the new supply controller address

4. setBeneficiary
   - _newBeneficiary: Enter the new beneficiary address

5. setFeeExclusion
   - _address: Enter the address to set exclusions for
   - _isExcludedOutbound: Enter true to exclude from outbound fees, false otherwise
   - _isExcludedInbound: Enter true to exclude from inbound fees, false otherwise

6. setLiquidityPool
   - _address: Enter the liquidity pool address
   - _isPool: Enter true to set as a liquidity pool, false to remove this status

7. setReserveConsumer
   - _newReserveConsumer: Enter the new reserve consumer address

8. setReserveCheckPeriod
   - _newPeriod: Enter the new period in seconds (e.g., 86400 for 1 day)

9. mint
   - _to: Enter the recipient address
   - _amount: Enter the amount to mint (in wei, e.g., 1000000000000000000 for 1 token)

10. burn
    - _amount: Enter the amount to burn (in wei)

11. burnFrom
    - _account: Enter the address to burn from
    - _amount: Enter the amount to burn (in wei)

12. pause
    - No inputs required

13. unpause
    - No inputs required

14. transfer
    - recipient: Enter the recipient address
    - amount: Enter the amount to transfer (in wei)

15. transferFrom
    - sender: Enter the sender's address
    - recipient: Enter the recipient's address
    - amount: Enter the amount to transfer (in wei)

16. approve
    - spender: Enter the address to approve
    - amount: Enter the amount to approve (in wei)

17. increaseAllowance
    - spender: Enter the address to increase allowance for
    - addedValue: Enter the amount to increase allowance by (in wei)

18. decreaseAllowance
    - spender: Enter the address to decrease allowance for
    - subtractedValue: Enter the amount to decrease allowance by (in wei)

19. transferAdminControl
    - newAdmin: Enter the address of the new admin

20. renounceAdminControl
    - No inputs required

## View Functions (No Transaction Required):

21. supplyController
    - Returns the current supply controller address

22. beneficiary
    - Returns the current beneficiary address

23. reserveConsumer
    - Returns the current reserve consumer address

24. isExcludedFromOutboundFees
    - address: Enter an address to check
    - Returns true if the address is excluded from outbound fees

25. isExcludedFromInboundFees
    - address: Enter an address to check
    - Returns true if the address is excluded from inbound fees

26. isLiquidityPool
    - address: Enter an address to check
    - Returns true if the address is set as a liquidity pool

27. taxTiers
    - index: Enter an index (0-4) to view a specific tier
    - Returns the amount for the specified tax tier

28. taxPercentages
    - index: Enter an index (0-4) to view a specific percentage
    - Returns the tax percentage for the specified tier

29. lastReserveCheck
    - Returns the timestamp of the last reserve check

30. reserveCheckPeriod
    - Returns the current reserve check period in seconds

31. owner
    - Returns the current owner's address

32. paused
    - Returns true if the contract is paused, false otherwise

33. balanceOf
    - account: Enter an address to check
    - Returns the token balance of the specified address

34. allowance
    - owner: Enter the owner's address
    - spender: Enter the spender's address
    - Returns the remaining allowance for the spender

Remember to always double-check inputs before submitting transactions, as most operations cannot be undone once executed. For view functions, no gas is required, and they can be called freely to check the contract's state.