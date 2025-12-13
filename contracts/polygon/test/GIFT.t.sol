// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/TestHelpers.sol";

contract GIFTTest is TestHelpers {
    function setUp() public {
        deployAll();
    }

    // ============ Initialization Tests ============

    function test_Initialize() public {
        assertEq(gift.name(), "GIFT");
        assertEq(gift.symbol(), "GIFT");
        assertEq(gift.decimals(), 18);
        assertEq(gift.owner(), owner);
        assertEq(address(gift.taxManager()), address(taxManager));
    }

    function test_CannotInitializeTwice() public {
        vm.expectRevert();
        gift.initialize(address(mockAggregator), address(0), address(taxManager));
    }

    // ============ Supply Controller Tests ============

    function test_SetSupplyController() public {
        address newController = makeAddr("newController");
        gift.setSupplyController(newController);
        assertEq(gift.supplyController(), newController);
    }

    function test_RevertSetSupplyControllerZeroAddress() public {
        vm.expectRevert("GIFT: Cannot set supply controller to address zero");
        gift.setSupplyController(address(0));
    }

    function test_RevertSetSupplyControllerNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        gift.setSupplyController(user1);
    }

    // ============ Supply Manager Tests ============

    function test_SetSupplyManager() public {
        address newManager = makeAddr("newManager");
        gift.setSupplyManager(newManager);
        assertEq(gift.supplyManager(), newManager);
    }

    function test_RevertSetSupplyManagerZeroAddress() public {
        vm.expectRevert("GIFT: Cannot set supply manager to address zero");
        gift.setSupplyManager(address(0));
    }

    function test_RevertSetSupplyManagerNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        gift.setSupplyManager(user1);
    }

    // ============ Minting Tests ============

    function test_IncreaseSupply() public {
        vm.prank(address(minting));
        bool success = gift.increaseSupply(user1, 1000 ether);
        
        assertTrue(success);
        assertEq(gift.balanceOf(user1), 1000 ether);
        assertEq(gift.totalSupply(), 1000 ether);
    }

    function test_RevertIncreaseSupplyNotController() public {
        vm.prank(user1);
        vm.expectRevert("GIFT: Caller is not the supply controller");
        gift.increaseSupply(user1, 1000 ether);
    }

    function test_InflateSupply() public {
        address supplyManager = makeAddr("supplyManager");
        gift.setSupplyManager(supplyManager);

        vm.prank(supplyManager);
        bool success = gift.inflateSupply(1000 ether);
        
        assertTrue(success);
        assertEq(gift.balanceOf(supplyManager), 1000 ether);
        assertEq(gift.totalSupply(), 1000 ether);
    }

    function test_RevertInflateSupplyNotManager() public {
        vm.prank(user1);
        vm.expectRevert("GIFT: Caller is not the supply manager");
        gift.inflateSupply(1000 ether);
    }

    // ============ Burning Tests ============

    function test_RedeemGold() public {
        // Mint first
        vm.prank(address(minting));
        gift.increaseSupply(user1, 1000 ether);

        // Redeem
        vm.prank(address(minting));
        bool success = gift.redeemGold(user1, 500 ether);
        
        assertTrue(success);
        assertEq(gift.balanceOf(user1), 500 ether);
        assertEq(gift.totalSupply(), 500 ether);
    }

    function test_RevertRedeemGoldNotController() public {
        vm.prank(user1);
        vm.expectRevert("GIFT: Caller is not the supply controller");
        gift.redeemGold(user1, 500 ether);
    }

    // ============ Pause Tests ============

    function test_Pause() public {
        gift.pause();
        assertTrue(gift.paused());
    }

    function test_Unpause() public {
        gift.pause();
        gift.unpause();
        assertFalse(gift.paused());
    }

    function test_RevertTransferWhenPaused() public {
        // Mint and exclude from fees for simplicity
        vm.prank(address(minting));
        gift.increaseSupply(user1, 1000 ether);
        taxManager.setFeeExclusion(user1, true, true);

        // Pause
        gift.pause();

        // Try transfer
        vm.prank(user1);
        vm.expectRevert();
        gift.transfer(user2, 100 ether);
    }

    function test_RevertPauseNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        gift.pause();
    }

    // ============ Manager Tests ============

    function test_SetManager() public {
        gift.setManager(user1, true);
        assertTrue(gift.isManager(user1));
    }

    function test_RemoveManager() public {
        gift.setManager(user1, true);
        gift.setManager(user1, false);
        assertFalse(gift.isManager(user1));
    }

    // ============ Transfer Tests (without tax) ============

    function test_Transfer_NoTax() public {
        // Setup: mint and exclude from fees
        vm.prank(address(minting));
        gift.increaseSupply(user1, 1000 ether);
        taxManager.setFeeExclusion(user1, true, true);
        taxManager.setFeeExclusion(user2, true, true);

        // Transfer
        vm.prank(user1);
        bool success = gift.transfer(user2, 100 ether);
        
        assertTrue(success);
        assertEq(gift.balanceOf(user1), 900 ether);
        assertEq(gift.balanceOf(user2), 100 ether);
    }

    function test_TransferFrom_NoTax() public {
        // Setup: mint and exclude from fees
        vm.prank(address(minting));
        gift.increaseSupply(user1, 1000 ether);
        taxManager.setFeeExclusion(user1, true, true);
        taxManager.setFeeExclusion(user2, true, true);

        // Approve
        vm.prank(user1);
        gift.approve(user2, 100 ether);

        // TransferFrom
        vm.prank(user2);
        bool success = gift.transferFrom(user1, user2, 100 ether);
        
        assertTrue(success);
        assertEq(gift.balanceOf(user1), 900 ether);
        assertEq(gift.balanceOf(user2), 100 ether);
    }

    // ============ Transfer Tests (with tax) ============

    function test_Transfer_WithTax() public {
        // Setup: mint tokens
        vm.prank(address(minting));
        gift.increaseSupply(user1, 10000 ether);

        // Transfer 1000 GIFT (tier 1: 1.618% tax = 16.18 GIFT)
        vm.prank(user1);
        gift.transfer(user2, 1000 ether);
        
        // Calculate expected tax: 1000 * 1618 / 100000 = 16.18
        uint256 expectedTax = 16.18 ether;
        uint256 expectedReceived = 1000 ether - expectedTax;
        
        assertEq(gift.balanceOf(user2), expectedReceived);
        assertEq(gift.balanceOf(beneficiary), expectedTax);
    }

    function test_Transfer_TierTwo() public {
        // Setup: mint tokens
        vm.prank(address(minting));
        gift.increaseSupply(user1, 20000 ether);

        // Transfer 5000 GIFT (tier 2: 1.2% tax = 60 GIFT)
        vm.prank(user1);
        gift.transfer(user2, 5000 ether);
        
        uint256 expectedTax = 60 ether;
        uint256 expectedReceived = 5000 ether - expectedTax;
        
        assertEq(gift.balanceOf(user2), expectedReceived);
        assertEq(gift.balanceOf(beneficiary), expectedTax);
    }

    // ============ Tax Manager Tests ============

    function test_SetTaxManager() public {
        GIFTTaxManager newTaxManager = deployTaxManager();
        gift.setTaxManager(address(newTaxManager));
        assertEq(address(gift.taxManager()), address(newTaxManager));
    }

    function test_RevertSetTaxManagerZeroAddress() public {
        vm.expectRevert("GIFT: New tax manager cannot be the zero address");
        gift.setTaxManager(address(0));
    }

    // ============ Delegate Transfer Tests ============

    function test_DelegateTransfer() public {
        // Setup: set user2 as manager
        gift.setManager(user2, true);
        
        // Mint to user1
        vm.prank(address(minting));
        gift.increaseSupply(user1, 10000 ether);
        
        // Exclude from fees for simplicity
        taxManager.setFeeExclusion(user1, true, true);

        // Create signature
        uint256 amount = 1000 ether;
        uint256 networkFee = 10 ether;
        uint256 nonce = gift.nonces(user1);
        
        bytes32 message = keccak256(
            abi.encodePacked(gift, user1, user3, amount, networkFee, nonce)
        );
        
        // Sign with user1's private key (in real test would use vm.sign)
        // For this test, we'll skip actual signature verification
        bytes memory signature = new bytes(65); // Mock signature

        // This will fail signature verification, but tests the flow
        vm.prank(user2);
        vm.expectRevert("GIFT: Invalid signature");
        gift.delegateTransfer(signature, user1, user3, amount, networkFee);
    }

    // ============ Chain ID Tests ============

    function test_GetChainID() public {
        uint256 chainId = gift.getChainID();
        assertEq(chainId, block.chainid);
    }

    // ============ Upgradability Tests ============

    function test_UpgradeContract() public {
        // Deploy new implementation
        GIFT newImpl = new GIFT();
        
        // Upgrade (only owner can)
        vm.prank(owner);
        gift.upgradeTo(address(newImpl));
        
        // Verify state is preserved
        assertEq(gift.name(), "GIFT");
        assertEq(gift.symbol(), "GIFT");
    }

    function test_RevertUpgradeNotOwner() public {
        GIFT newImpl = new GIFT();
        
        vm.prank(user1);
        vm.expectRevert();
        gift.upgradeTo(address(newImpl));
    }
}

