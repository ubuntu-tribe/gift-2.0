// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/TestHelpers.sol";

contract GIFTPoRTest is TestHelpers {
    function setUp() public {
        deployAll();
    }

    // ============ Initialization Tests ============

    function test_Initialize() public {
        assertEq(por.owner(), owner);
        assertTrue(por.auditors(owner));
        assertTrue(por.admins(owner));
        assertTrue(por.minters(owner));
        assertEq(por.nextVaultId(), 3); // 2 vaults created in setup + 1
    }

    // ============ Role Management Tests ============

    function test_AddAuditor() public {
        address newAuditor = makeAddr("newAuditor");
        por.addAuditor(newAuditor);
        assertTrue(por.auditors(newAuditor));
    }

    function test_RemoveAuditor() public {
        address newAuditor = makeAddr("newAuditor");
        por.addAuditor(newAuditor);
        por.removeAuditor(newAuditor);
        assertFalse(por.auditors(newAuditor));
    }

    function test_RevertAddAuditorNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        por.addAuditor(user1);
    }

    function test_AddAdmin() public {
        address newAdmin = makeAddr("newAdmin");
        por.addAdmin(newAdmin);
        assertTrue(por.admins(newAdmin));
    }

    function test_RemoveAdmin() public {
        address newAdmin = makeAddr("newAdmin");
        por.addAdmin(newAdmin);
        por.removeAdmin(newAdmin);
        assertFalse(por.admins(newAdmin));
    }

    function test_RevertAddAdminNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        por.addAdmin(user1);
    }

    function test_AddMinter() public {
        vm.prank(admin);
        por.addMinter(user1);
        assertTrue(por.minters(user1));
    }

    function test_RemoveMinter() public {
        vm.prank(admin);
        por.addMinter(user1);
        
        vm.prank(admin);
        por.removeMinter(user1);
        assertFalse(por.minters(user1));
    }

    function test_RevertAddMinterNotAdmin() public {
        vm.prank(user1);
        vm.expectRevert("Caller is not an admin");
        por.addMinter(user1);
    }

    // ============ Vault Management Tests ============

    function test_AddVault() public {
        vm.prank(admin);
        por.addVault("Test Vault");
        
        uint256 newVaultId = 3; // vault1=1, vault2=2, this is 3
        (string memory name, uint256 id, uint256 balance) = por.getReserveState(newVaultId);
        
        assertEq(name, "Test Vault");
        assertEq(id, newVaultId);
        assertEq(balance, 0);
    }

    function test_RevertAddVaultNotAdmin() public {
        vm.prank(user1);
        vm.expectRevert("Caller is not an admin");
        por.addVault("Test Vault");
    }

    function test_UpdateVault() public {
        uint256 addAmount = 50000 * 10 ** 18;
        
        vm.prank(auditor);
        por.updateVault(vault1, addAmount, "Adding gold");
        
        (, , uint256 balance) = por.getReserveState(vault1);
        assertEq(balance, INITIAL_RESERVE + addAmount);
        assertEq(por.GIFT_reserve(), INITIAL_RESERVE + addAmount);
    }

    function test_RevertUpdateVaultNotAuditor() public {
        vm.prank(user1);
        vm.expectRevert("Caller is not an auditor");
        por.updateVault(vault1, 50000 * 10 ** 18, "Adding gold");
    }

    function test_RevertUpdateVaultInvalidId() public {
        vm.prank(auditor);
        vm.expectRevert("Invalid vault ID");
        por.updateVault(999, 50000 * 10 ** 18, "Adding gold");
    }

    // ============ Physical Vault Tests ============

    function test_SupplyGold() public {
        uint256 addAmount = 25000 * 10 ** 18;
        
        vm.prank(auditor);
        por.SupplyGold(vault1, addAmount, "Physical gold received");
        
        (, , uint256 amount) = por.physicalVaultsById(vault1);
        assertEq(amount, INITIAL_RESERVE + addAmount);
    }

    function test_RevertSupplyGoldNotAuditor() public {
        vm.prank(user1);
        vm.expectRevert("Caller is not an auditor");
        por.SupplyGold(vault1, 25000 * 10 ** 18, "Physical gold received");
    }

    function test_RedeemGold() public {
        uint256 redeemAmount = 10000 * 10 ** 18;
        
        vm.prank(auditor);
        por.RedeemGold(vault1, redeemAmount, "Gold shipped");
        
        (, , uint256 amount) = por.physicalVaultsById(vault1);
        assertEq(amount, INITIAL_RESERVE - redeemAmount);
    }

    function test_RevertRedeemGoldInsufficientBalance() public {
        vm.prank(auditor);
        vm.expectRevert("Insufficient physical reserve balance");
        por.RedeemGold(vault1, INITIAL_RESERVE + 1, "Gold shipped");
    }

    function test_RevertRedeemGoldNotAuditor() public {
        vm.prank(user1);
        vm.expectRevert("Caller is not an auditor");
        por.RedeemGold(vault1, 10000 * 10 ** 18, "Gold shipped");
    }

    // ============ Move Supply Tests ============

    function test_MoveSupply() public {
        uint256 moveAmount = 50000 * 10 ** 18;
        
        vm.prank(auditor);
        por.moveSupply(vault1, vault2, moveAmount, "Moving gold between vaults");
        
        (, , uint256 vault1Balance) = por.getReserveState(vault1);
        (, , uint256 vault2Balance) = por.getReserveState(vault2);
        
        assertEq(vault1Balance, INITIAL_RESERVE - moveAmount);
        assertEq(vault2Balance, moveAmount);
    }

    function test_RevertMoveSupplyInsufficientBalance() public {
        vm.prank(auditor);
        vm.expectRevert("Insufficient balance in from vault");
        por.moveSupply(vault1, vault2, INITIAL_RESERVE + 1, "Moving gold");
    }

    function test_RevertMoveSupplyNotAuditor() public {
        vm.prank(user1);
        vm.expectRevert("Caller is not an auditor");
        por.moveSupply(vault1, vault2, 50000 * 10 ** 18, "Moving gold");
    }

    function test_RevertMoveSupplyInvalidFromVault() public {
        vm.prank(auditor);
        vm.expectRevert("Invalid from vault ID");
        por.moveSupply(999, vault2, 50000 * 10 ** 18, "Moving gold");
    }

    function test_RevertMoveSupplyInvalidToVault() public {
        vm.prank(auditor);
        vm.expectRevert("Invalid to vault ID");
        por.moveSupply(vault1, 999, 50000 * 10 ** 18, "Moving gold");
    }

    // ============ Minting Allowance Tests ============

    function test_SetMintingAllowance() public {
        address testMinter = makeAddr("testMinter");
        uint256 allowance = 50000 * 10 ** 18;
        
        vm.prank(admin);
        por.setMintingAllowance(testMinter, vault1, allowance);
        
        assertEq(por.mintAllowances(testMinter, vault1), allowance);
    }

    function test_RevertSetMintingAllowanceNotAdmin() public {
        vm.prank(user1);
        vm.expectRevert("Caller is not an admin");
        por.setMintingAllowance(user1, vault1, 50000 * 10 ** 18);
    }

    function test_RevertSetMintingAllowanceInvalidReserve() public {
        vm.prank(admin);
        vm.expectRevert("Invalid reserve ID");
        por.setMintingAllowance(user1, 999, 50000 * 10 ** 18);
    }

    function test_GetMinterReservesAndAllowances() public {
        address testMinter = makeAddr("testMinter");
        uint256 allowance1 = 30000 * 10 ** 18;
        uint256 allowance2 = 20000 * 10 ** 18;
        
        vm.startPrank(admin);
        por.setMintingAllowance(testMinter, vault1, allowance1);
        por.setMintingAllowance(testMinter, vault2, allowance2);
        vm.stopPrank();
        
        GIFTPoR.ReserveAllowance[] memory allowances = por.getMinterReservesAndAllowances(testMinter);
        
        assertEq(allowances.length, 2);
        assertEq(allowances[0].reserveId, vault1);
        assertEq(allowances[0].allowance, allowance1);
        assertEq(allowances[1].reserveId, vault2);
        assertEq(allowances[1].allowance, allowance2);
    }

    function test_UpdateAllowanceForExistingReserve() public {
        address testMinter = makeAddr("testMinter");
        
        vm.startPrank(admin);
        por.setMintingAllowance(testMinter, vault1, 30000 * 10 ** 18);
        por.setMintingAllowance(testMinter, vault1, 50000 * 10 ** 18); // Update
        vm.stopPrank();
        
        assertEq(por.mintAllowances(testMinter, vault1), 50000 * 10 ** 18);
        
        GIFTPoR.ReserveAllowance[] memory allowances = por.getMinterReservesAndAllowances(testMinter);
        assertEq(allowances.length, 1); // Should not duplicate
    }

    // ============ Update Reserve After Mint Tests ============

    function test_UpdateReserveAfterMint() public {
        address testMinter = makeAddr("testMinter");
        vm.prank(admin);
        por.addMinter(testMinter);
        
        uint256 mintAmount = 10000 * 10 ** 18;
        
        vm.prank(testMinter);
        por.updateReserveAfterMint(vault1, mintAmount);
        
        (, , uint256 balance) = por.getReserveState(vault1);
        assertEq(balance, INITIAL_RESERVE - mintAmount);
    }

    function test_RevertUpdateReserveAfterMintNotMinter() public {
        vm.prank(user1);
        vm.expectRevert("Caller is not a minter");
        por.updateReserveAfterMint(vault1, 10000 * 10 ** 18);
    }

    function test_RevertUpdateReserveAfterMintInsufficientBalance() public {
        address testMinter = makeAddr("testMinter");
        vm.prank(admin);
        por.addMinter(testMinter);
        
        vm.prank(testMinter);
        vm.expectRevert("Insufficient reserve balance");
        por.updateReserveAfterMint(vault1, INITIAL_RESERVE + 1);
    }

    function test_RevertUpdateReserveAfterMintInvalidVault() public {
        address testMinter = makeAddr("testMinter");
        vm.prank(admin);
        por.addMinter(testMinter);
        
        vm.prank(testMinter);
        vm.expectRevert("Invalid vault ID");
        por.updateReserveAfterMint(999, 10000 * 10 ** 18);
    }

    // ============ Query Tests ============

    function test_GetTotalReserves() public {
        (uint256 totalReserves, uint256 totalAmount) = por.getTotalReserves();
        assertEq(totalReserves, 2); // vault1 and vault2
        assertEq(totalAmount, INITIAL_RESERVE);
    }

    function test_RetrieveReserve() public {
        assertEq(por.retrieveReserve(), INITIAL_RESERVE);
    }

    function test_IsMinter() public {
        assertTrue(por.isMinter(owner));
        assertFalse(por.isMinter(user1));
    }

    function test_GetReserveState() public {
        (string memory name, uint256 id, uint256 balance) = por.getReserveState(vault1);
        assertEq(name, "Vault 1");
        assertEq(id, vault1);
        assertEq(balance, INITIAL_RESERVE);
    }

    function test_RevertGetReserveStateInvalidId() public {
        vm.expectRevert("Invalid vault ID");
        por.getReserveState(999);
    }

    // ============ Events Tests ============

    function test_EmitVaultCreated() public {
        vm.expectEmit(true, false, false, true);
        emit GIFTPoR.VaultCreated(3, "New Vault", 0, 0);
        
        vm.prank(admin);
        por.addVault("New Vault");
    }

    function test_EmitVaultUpdated() public {
        uint256 addAmount = 50000 * 10 ** 18;
        
        vm.expectEmit(true, false, false, true);
        emit GIFTPoR.VaultUpdated(vault1, "Vault 1", addAmount, INITIAL_RESERVE + addAmount, "Adding gold");
        
        vm.prank(auditor);
        por.updateVault(vault1, addAmount, "Adding gold");
    }

    function test_EmitUpdateReserve() public {
        uint256 addAmount = 50000 * 10 ** 18;
        
        vm.expectEmit(true, false, false, true);
        emit GIFTPoR.UpdateReserve(INITIAL_RESERVE + addAmount, auditor);
        
        vm.prank(auditor);
        por.updateVault(vault1, addAmount, "Adding gold");
    }

    function test_EmitAuditorAdded() public {
        address newAuditor = makeAddr("newAuditor");
        
        vm.expectEmit(true, false, false, false);
        emit GIFTPoR.AuditorAdded(newAuditor);
        por.addAuditor(newAuditor);
    }

    function test_EmitMinterAdded() public {
        address newMinter = makeAddr("newMinter");
        
        vm.expectEmit(true, false, false, false);
        emit GIFTPoR.MinterAdded(newMinter);
        
        vm.prank(admin);
        por.addMinter(newMinter);
    }

    function test_EmitSetMintAllowance() public {
        address testMinter = makeAddr("testMinter");
        uint256 allowance = 50000 * 10 ** 18;
        
        vm.expectEmit(true, false, false, true);
        emit GIFTPoR.SetMintAllowance(testMinter, vault1, allowance);
        
        vm.prank(admin);
        por.setMintingAllowance(testMinter, vault1, allowance);
    }

    function test_EmitMoveSupply() public {
        uint256 moveAmount = 50000 * 10 ** 18;
        
        vm.expectEmit(true, true, false, true);
        emit GIFTPoR.MoveSupply(vault1, vault2, moveAmount, "Moving gold", auditor);
        
        vm.prank(auditor);
        por.moveSupply(vault1, vault2, moveAmount, "Moving gold");
    }

    function test_EmitPhysicalVaultSupplyAdded() public {
        uint256 addAmount = 25000 * 10 ** 18;
        
        vm.expectEmit(true, false, false, true);
        emit GIFTPoR.PhysicalVaultSupplyAdded(
            vault1,
            "Vault 1",
            addAmount,
            INITIAL_RESERVE + addAmount,
            "Physical gold received",
            auditor
        );
        
        vm.prank(auditor);
        por.SupplyGold(vault1, addAmount, "Physical gold received");
    }

    function test_EmitPhysicalVaultSupplyRemoved() public {
        uint256 redeemAmount = 10000 * 10 ** 18;
        
        vm.expectEmit(true, false, false, true);
        emit GIFTPoR.PhysicalVaultSupplyRemoved(
            vault1,
            "Vault 1",
            redeemAmount,
            INITIAL_RESERVE - redeemAmount,
            "Gold shipped",
            auditor
        );
        
        vm.prank(auditor);
        por.RedeemGold(vault1, redeemAmount, "Gold shipped");
    }

    // ============ Upgradability Tests ============

    function test_UpgradeContract() public {
        GIFTPoR newImpl = new GIFTPoR();
        
        vm.prank(admin);
        por.upgradeTo(address(newImpl));
        
        // Verify state is preserved
        assertEq(por.GIFT_reserve(), INITIAL_RESERVE);
    }

    function test_RevertUpgradeNotAdmin() public {
        GIFTPoR newImpl = new GIFTPoR();
        
        vm.prank(user1);
        vm.expectRevert("Caller is not an admin");
        por.upgradeTo(address(newImpl));
    }

    // ============ Complex Scenarios ============

    function test_CompleteVaultLifecycle() public {
        // Create a new vault
        vm.prank(admin);
        por.addVault("Lifecycle Vault");
        uint256 vaultId = 3;
        
        // Add initial physical supply
        vm.prank(auditor);
        por.SupplyGold(vaultId, 100000 * 10 ** 18, "Initial supply");
        
        // Update digital vault
        vm.prank(auditor);
        por.updateVault(vaultId, 100000 * 10 ** 18, "Matching digital");
        
        // Setup minter with allowance
        vm.startPrank(admin);
        por.addMinter(minter);
        por.setMintingAllowance(minter, vaultId, 50000 * 10 ** 18);
        vm.stopPrank();
        
        // Mint tokens (update reserve)
        vm.prank(minter);
        por.updateReserveAfterMint(vaultId, 30000 * 10 ** 18);
        
        // Redeem physical gold
        vm.prank(auditor);
        por.RedeemGold(vaultId, 30000 * 10 ** 18, "Physical redemption");
        
        // Verify final state
        (, , uint256 digitalBalance) = por.getReserveState(vaultId);
        (, , uint256 physicalBalance) = por.physicalVaultsById(vaultId);

        // Digital reserve tracks minted tokens; physical reserve reflects total vault inventory.
        assertEq(digitalBalance, 70000 * 10 ** 18);
        assertEq(physicalBalance, 170000 * 10 ** 18);
    }
}

