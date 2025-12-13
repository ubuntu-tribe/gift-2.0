// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/TestHelpers.sol";

contract GiftPolygonBridgeTest is TestHelpers {
    function setUp() public {
        deployAll();
    }

    // ============ Initialization ============

    function test_Initialize() public {
        assertEq(address(bridge.gift()), address(gift));
        assertEq(address(bridge.taxManager()), address(taxManager));
        assertEq(bridge.relayer(), relayer);
        assertEq(bridge.owner(), owner);
        assertEq(bridge.depositNonce(), 0);
    }

    // ============ Relayer management ============

    function test_SetRelayer() public {
        address newRelayer = makeAddr("newRelayer");
        vm.expectEmit(true, false, false, false);
        emit GiftPolygonBridge.RelayerUpdated(newRelayer);
        bridge.setRelayer(newRelayer);
        assertEq(bridge.relayer(), newRelayer);
    }

    function test_RevertSetRelayerZeroAddress() public {
        vm.expectRevert("Bridge: relayer is zero");
        bridge.setRelayer(address(0));
    }

    function test_RevertSetRelayerNotOwner() public {
        address newRelayer = makeAddr("newRelayer");
        vm.prank(user1);
        vm.expectRevert();
        bridge.setRelayer(newRelayer);
    }

    // ============ Deposits ============

    function _mintGiftToUser(address to, uint256 amount) internal {
        minting.enforceRegistry(false);
        setupMinter(minter, vault1, DEFAULT_ALLOWANCE);
        vm.prank(minter);
        minting.mint(to, amount, vault1);
    }

    function test_DepositToSolana() public {
        uint256 amount = 1_000 * 10 ** 18;
        _mintGiftToUser(user1, amount);

        // Exclude user1 from outbound fees so bridge receives exact amount
        taxManager.setFeeExclusion(user1, true, true);

        vm.prank(user1);
        gift.approve(address(bridge), amount);

        bytes32 solanaRecipient = keccak256("solana-user");

        vm.expectEmit(true, true, false, true);
        emit GiftPolygonBridge.DepositedToSolana(user1, solanaRecipient, amount, 1);

        vm.prank(user1);
        bridge.depositToSolana(amount, solanaRecipient);

        assertEq(gift.balanceOf(user1), 0);
        assertEq(gift.balanceOf(address(bridge)), amount);
        assertEq(bridge.depositNonce(), 1);
    }

    function test_RevertDepositToSolanaZeroAmount() public {
        bytes32 solanaRecipient = keccak256("solana-user");
        vm.expectRevert("Bridge: amount is zero");
        bridge.depositToSolana(0, solanaRecipient);
    }

    function test_RevertDepositToSolanaZeroRecipient() public {
        vm.expectRevert("Bridge: invalid Solana recipient");
        bridge.depositToSolana(1_000 * 10 ** 18, bytes32(0));
    }

    function test_RevertDepositWhenPaused() public {
        vm.prank(owner);
        bridge.pause();

        bytes32 solanaRecipient = keccak256("solana-user");
        vm.expectRevert("Pausable: paused");
        bridge.depositToSolana(1_000 * 10 ** 18, solanaRecipient);
    }

    // ============ Withdrawals ============

    function test_CompleteWithdrawalFromSolana() public {
        uint256 amount = 2_000 * 10 ** 18;
        _mintGiftToUser(user1, amount);
        taxManager.setFeeExclusion(user1, true, true);

        // User deposits full amount to bridge
        vm.prank(user1);
        gift.approve(address(bridge), amount);

        bytes32 solanaRecipient = keccak256("solana-user");
        vm.prank(user1);
        bridge.depositToSolana(amount, solanaRecipient);

        assertEq(gift.balanceOf(address(bridge)), amount);

        // Relayer completes withdrawal back to user2 based on a Solana burn
        bytes32 burnTx = keccak256("solana-burn-tx");

        vm.expectEmit(true, false, true, true);
        emit GiftPolygonBridge.WithdrawalToPolygonCompleted(user2, amount, burnTx);

        vm.prank(relayer);
        bridge.completeWithdrawalFromSolana(user2, amount, burnTx);

        // Bridge should have zero balance; full amount goes to user2 (bridge is fee-exempt)
        assertEq(gift.balanceOf(address(bridge)), 0);
        assertEq(gift.balanceOf(user2), amount);
        assertTrue(bridge.processedBurns(burnTx));
    }

    function test_RevertCompleteWithdrawalWhenPaused() public {
        vm.prank(owner);
        bridge.pause();

        vm.prank(relayer);
        vm.expectRevert("Pausable: paused");
        bridge.completeWithdrawalFromSolana(user1, 1_000 * 10 ** 18, keccak256("burn"));
    }

    function test_RevertCompleteWithdrawalNotRelayer() public {
        vm.expectRevert("Bridge: caller is not relayer");
        bridge.completeWithdrawalFromSolana(user1, 1_000 * 10 ** 18, keccak256("burn"));
    }

    function test_RevertCompleteWithdrawalDoubleSpend() public {
        uint256 amount = 1_000 * 10 ** 18;
        _mintGiftToUser(user1, amount);
        taxManager.setFeeExclusion(user1, true, true);

        vm.prank(user1);
        gift.approve(address(bridge), amount);

        bytes32 solanaRecipient = keccak256("solana-user");
        vm.prank(user1);
        bridge.depositToSolana(amount, solanaRecipient);

        bytes32 burnTx = keccak256("solana-burn-tx");

        vm.prank(relayer);
        bridge.completeWithdrawalFromSolana(user2, amount, burnTx);

        vm.prank(relayer);
        vm.expectRevert("Bridge: burn already processed");
        bridge.completeWithdrawalFromSolana(user2, amount, burnTx);
    }

    function test_LockedBalanceView() public {
        uint256 amount = 500 * 10 ** 18;
        _mintGiftToUser(user1, amount);
        taxManager.setFeeExclusion(user1, true, true);

        vm.prank(user1);
        gift.approve(address(bridge), amount);

        bytes32 solanaRecipient = keccak256("solana-user");
        vm.prank(user1);
        bridge.depositToSolana(amount, solanaRecipient);

        assertEq(bridge.lockedBalance(), amount);
    }
}


