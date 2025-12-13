// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/TestHelpers.sol";

contract GIFTTaxManagerTest is TestHelpers {
    function setUp() public {
        deployAll();
    }

    // ============ Initialization Tests ============

    function test_Initialize() public {
        assertEq(taxManager.owner(), owner);
        assertEq(taxManager.beneficiary(), beneficiary);
        
        // Check default tax percentages
        (uint256 t1, uint256 t2, uint256 t3, uint256 t4, uint256 t5) = taxManager.getTaxPercentages();
        assertEq(t1, 1618); // 1.618%
        assertEq(t2, 1200); // 1.2%
        assertEq(t3, 1000); // 1.0%
        assertEq(t4, 500);  // 0.5%
        assertEq(t5, 300);  // 0.3%
        
        // Check default tax tiers
        (uint256 tier1, uint256 tier2, uint256 tier3, uint256 tier4) = taxManager.getTaxTiers();
        assertEq(tier1, 2000 * 10 ** 18);
        assertEq(tier2, 10000 * 10 ** 18);
        assertEq(tier3, 20000 * 10 ** 18);
        assertEq(tier4, 200000 * 10 ** 18);
    }

    function test_OwnerExcludedByDefault() public {
        assertTrue(taxManager.isExcludedFromOutboundFees(owner));
    }

    function test_InboundFeesExemptByDefault() public {
        // According to architecture, inbound currently exempt
        assertTrue(taxManager.isExcludedFromInboundFees(user1));
        assertTrue(taxManager.isExcludedFromInboundFees(user2));
    }

    // ============ Tax Officer Tests ============

    function test_SetTaxOfficer() public {
        address officer = makeAddr("officer");
        taxManager.setTaxOfficer(officer);
        assertEq(taxManager.taxOfficer(), officer);
    }

    function test_RevertSetTaxOfficerZeroAddress() public {
        vm.expectRevert("GIFTTaxManager: Cannot set tax officer to address zero");
        taxManager.setTaxOfficer(address(0));
    }

    function test_RevertSetTaxOfficerNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        taxManager.setTaxOfficer(user1);
    }

    // ============ Beneficiary Tests ============

    function test_SetBeneficiary() public {
        address newBeneficiary = makeAddr("newBeneficiary");
        taxManager.setBeneficiary(newBeneficiary);
        assertEq(taxManager.beneficiary(), newBeneficiary);
    }

    function test_RevertSetBeneficiaryZeroAddress() public {
        vm.expectRevert("GIFTTaxManager: Cannot set beneficiary to address zero");
        taxManager.setBeneficiary(address(0));
    }

    function test_RevertSetBeneficiaryNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        taxManager.setBeneficiary(user1);
    }

    // ============ Tax Percentage Tests ============

    function test_UpdateTaxPercentages() public {
        taxManager.updateTaxPercentages(2000, 1500, 1200, 800, 500);
        
        (uint256 t1, uint256 t2, uint256 t3, uint256 t4, uint256 t5) = taxManager.getTaxPercentages();
        assertEq(t1, 2000);
        assertEq(t2, 1500);
        assertEq(t3, 1200);
        assertEq(t4, 800);
        assertEq(t5, 500);
    }

    function test_UpdateTaxPercentagesByTaxOfficer() public {
        address officer = makeAddr("officer");
        taxManager.setTaxOfficer(officer);
        
        vm.prank(officer);
        taxManager.updateTaxPercentages(2000, 1500, 1200, 800, 500);
        
        (uint256 t1, , , , ) = taxManager.getTaxPercentages();
        assertEq(t1, 2000);
    }

    function test_RevertUpdateTaxPercentagesNotAuthorized() public {
        vm.prank(user1);
        vm.expectRevert("GIFTTaxManager: Caller is not the owner or tax officer");
        taxManager.updateTaxPercentages(2000, 1500, 1200, 800, 500);
    }

    // ============ Tax Tier Tests ============

    function test_UpdateTaxTiers() public {
        uint256 newTier1 = 5000 * 10 ** 18;
        uint256 newTier2 = 15000 * 10 ** 18;
        uint256 newTier3 = 30000 * 10 ** 18;
        uint256 newTier4 = 300000 * 10 ** 18;
        
        taxManager.updateTaxTiers(newTier1, newTier2, newTier3, newTier4);
        
        (uint256 tier1, uint256 tier2, uint256 tier3, uint256 tier4) = taxManager.getTaxTiers();
        assertEq(tier1, newTier1);
        assertEq(tier2, newTier2);
        assertEq(tier3, newTier3);
        assertEq(tier4, newTier4);
    }

    function test_UpdateTaxTiersByTaxOfficer() public {
        address officer = makeAddr("officer");
        taxManager.setTaxOfficer(officer);
        
        vm.prank(officer);
        taxManager.updateTaxTiers(5000 * 10 ** 18, 15000 * 10 ** 18, 30000 * 10 ** 18, 300000 * 10 ** 18);
        
        (uint256 tier1, , , ) = taxManager.getTaxTiers();
        assertEq(tier1, 5000 * 10 ** 18);
    }

    function test_RevertUpdateTaxTiersNotAuthorized() public {
        vm.prank(user1);
        vm.expectRevert("GIFTTaxManager: Caller is not the owner or tax officer");
        taxManager.updateTaxTiers(5000 * 10 ** 18, 15000 * 10 ** 18, 30000 * 10 ** 18, 300000 * 10 ** 18);
    }

    // ============ Fee Exclusion Tests ============

    function test_SetFeeExclusionOutbound() public {
        taxManager.setFeeExclusion(user1, true, false);
        assertTrue(taxManager.isExcludedFromOutboundFees(user1));
    }

    function test_RemoveFeeExclusion() public {
        taxManager.setFeeExclusion(user1, true, false);
        taxManager.setFeeExclusion(user1, false, false);
        assertFalse(taxManager.isExcludedFromOutboundFees(user1));
    }

    function test_SetFeeExclusionByTaxOfficer() public {
        address officer = makeAddr("officer");
        taxManager.setTaxOfficer(officer);
        
        vm.prank(officer);
        taxManager.setFeeExclusion(user1, true, false);
        assertTrue(taxManager.isExcludedFromOutboundFees(user1));
    }

    function test_RevertSetFeeExclusionNotAuthorized() public {
        vm.prank(user1);
        vm.expectRevert("GIFTTaxManager: Caller is not the owner or tax officer");
        taxManager.setFeeExclusion(user1, true, false);
    }

    // ============ Liquidity Pool Tests ============

    function test_SetLiquidityPool() public {
        address pool = makeAddr("pool");
        taxManager.setLiquidityPool(pool, true);
        assertTrue(taxManager._isLiquidityPool(pool));
    }

    function test_RemoveLiquidityPool() public {
        address pool = makeAddr("pool");
        taxManager.setLiquidityPool(pool, true);
        taxManager.setLiquidityPool(pool, false);
        assertFalse(taxManager._isLiquidityPool(pool));
    }

    function test_RevertSetLiquidityPoolNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        taxManager.setLiquidityPool(user1, true);
    }

    // ============ Tax Calculation Scenarios ============

    function test_TaxCalculation_TierOne() public {
        // Transfer 1000 GIFT (within tier 1: <= 2000)
        // Expected tax: 1000 * 1618 / 100000 = 16.18 GIFT
        (uint256 t1, , , , ) = taxManager.getTaxPercentages();
        uint256 amount = 1000 * 10 ** 18;
        uint256 expectedTax = amount * t1 / 100000;
        
        assertEq(expectedTax, 16.18 ether);
    }

    function test_TaxCalculation_TierFive() public {
        // Transfer 300,000 GIFT (> tier 4: > 200,000)
        // Expected tax: 300,000 * 300 / 100000 = 900 GIFT
        (, , , , uint256 t5) = taxManager.getTaxPercentages();
        uint256 amount = 300000 * 10 ** 18;
        uint256 expectedTax = amount * t5 / 100000;
        
        assertEq(expectedTax, 900 ether);
    }

    // ============ Events Tests ============

    function test_EmitUpdateTaxPercentages() public {
        vm.expectEmit(true, true, true, true);
        emit GIFTTaxManager.UpdateTaxPercentages(2000, 1500, 1200, 800, 500);
        taxManager.updateTaxPercentages(2000, 1500, 1200, 800, 500);
    }

    function test_EmitUpdateTaxTiers() public {
        uint256 t1 = 5000 * 10 ** 18;
        uint256 t2 = 15000 * 10 ** 18;
        uint256 t3 = 30000 * 10 ** 18;
        uint256 t4 = 300000 * 10 ** 18;
        
        vm.expectEmit(true, true, true, true);
        emit GIFTTaxManager.UpdateTaxTiers(t1, t2, t3, t4);
        taxManager.updateTaxTiers(t1, t2, t3, t4);
    }

    function test_EmitNewTaxOfficer() public {
        address officer = makeAddr("officer");
        
        vm.expectEmit(true, false, false, false);
        emit GIFTTaxManager.NewTaxOfficer(officer);
        taxManager.setTaxOfficer(officer);
    }

    function test_EmitNewBeneficiary() public {
        address newBeneficiary = makeAddr("newBeneficiary");
        
        vm.expectEmit(true, false, false, false);
        emit GIFTTaxManager.NewBeneficiary(newBeneficiary);
        taxManager.setBeneficiary(newBeneficiary);
    }

    function test_EmitFeeExclusionSet() public {
        vm.expectEmit(true, false, false, true);
        emit GIFTTaxManager.FeeExclusionSet(user1, true, false);
        taxManager.setFeeExclusion(user1, true, false);
    }

    function test_EmitLiquidityPoolSet() public {
        address pool = makeAddr("pool");
        
        vm.expectEmit(true, false, false, true);
        emit GIFTTaxManager.LiquidityPoolSet(pool, true);
        taxManager.setLiquidityPool(pool, true);
    }

    // ============ Upgradability Tests ============

    function test_UpgradeContract() public {
        GIFTTaxManager newImpl = new GIFTTaxManager();
        
        vm.prank(owner);
        taxManager.upgradeTo(address(newImpl));
        
        // Verify state is preserved
        (uint256 t1, , , , ) = taxManager.getTaxPercentages();
        assertEq(t1, 1618);
    }

    function test_RevertUpgradeNotOwner() public {
        GIFTTaxManager newImpl = new GIFTTaxManager();
        
        vm.prank(user1);
        vm.expectRevert();
        taxManager.upgradeTo(address(newImpl));
    }
}

