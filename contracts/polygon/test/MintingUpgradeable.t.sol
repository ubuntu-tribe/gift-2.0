// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/TestHelpers.sol";

contract MintingUpgradeableTest is TestHelpers {
    function setUp() public {
        deployAll();
        // Enable registry enforcement and setup minter
        minting.enforceRegistry(true);
        setupMinter(minter, vault1, DEFAULT_ALLOWANCE);
    }

    // ============ Initialization Tests ============

    function test_Initialize() public {
        assertEq(address(minting.giftpor()), address(por));
        assertEq(address(minting.gift()), address(gift));
        assertEq(address(minting.registry()), address(registry));
        assertEq(minting.owner(), owner);
        assertEq(minting.escrow(), address(escrow));
    }

    // ============ Registry Configuration Tests ============

    function test_SetRegistry() public {
        GIFTBatchRegistry newRegistry = deployRegistry();
        minting.setRegistry(address(newRegistry));
        assertEq(address(minting.registry()), address(newRegistry));
    }

    function test_RevertSetRegistryNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        minting.setRegistry(address(registry));
    }

    function test_EnforceRegistry() public {
        minting.enforceRegistry(false);
        assertFalse(minting.registryEnforced());
        
        minting.enforceRegistry(true);
        assertTrue(minting.registryEnforced());
    }

    function test_RevertEnforceRegistryNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        minting.enforceRegistry(false);
    }

    // ============ Batch Allowlist Tests ============

    function test_AllowBatch() public {
        minting.allowBatch(1, true);
        assertTrue(minting.allowedBatches(1));
    }

    function test_DisallowBatch() public {
        minting.allowBatch(1, true);
        minting.allowBatch(1, false);
        assertFalse(minting.allowedBatches(1));
    }

    function test_RevertAllowBatchNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        minting.allowBatch(1, true);
    }

    // ============ Escrow Configuration Tests ============

    function test_SetEscrow() public {
        address newEscrow = makeAddr("newEscrow");
        vm.prank(owner); // PoR owner
        minting.setEscrow(newEscrow);
        assertEq(minting.escrow(), newEscrow);
    }

    function test_RevertSetEscrowNotPoROwner() public {
        vm.prank(user1);
        vm.expectRevert("Minting: only PoR owner");
        minting.setEscrow(user1);
    }

    function test_RevertSetEscrowZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Minting: zero escrow");
        minting.setEscrow(address(0));
    }

    // ============ Mint With Proof Tests ============

    function test_MintWithProof() public {
        // Create leaf
        GIFTBatchRegistry.LeafInput memory leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 1000 * 10 ** 18,
            fineWeightMg: 1_000_000,
            serialHash: keccak256("serial123"),
            mineHash: bytes32(0),
            barStandardHash: bytes32(0),
            docHash: bytes32(0),
            mintedAtISO: 0,
            presenceMask: 1
        });
        
        // Generate merkle tree
        (bytes32 root, bytes32[] memory proof) = generateMerkleTree(leaf);
        
        // Register batch
        uint256 batchId = registry.registerBatch(root, leaf.quantity, "ipfs://test", bytes32(0), true);
        leaf.batchId = batchId;
        (root, proof) = generateMerkleTree(leaf);
        
        // Allow batch
        minting.allowBatch(batchId, true);
        
        // Mint
        uint256 mintAmount = 500 * 10 ** 18;
        vm.prank(minter);
        minting.mintWithProof(user1, mintAmount, leaf, proof);
        
        // Verify
        assertEq(gift.balanceOf(user1), mintAmount);
        assertEq(gift.totalSupply(), mintAmount);
        
        // Check allowance was reduced
        GIFTPoR.ReserveAllowance[] memory allowances = por.getMinterReservesAndAllowances(minter);
        assertEq(allowances[0].allowance, DEFAULT_ALLOWANCE - mintAmount);
    }

    function test_RevertMintWithProofNotMinter() public {
        GIFTBatchRegistry.LeafInput memory leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 1000 * 10 ** 18,
            fineWeightMg: 1_000_000,
            serialHash: keccak256("serial"),
            mineHash: bytes32(0),
            barStandardHash: bytes32(0),
            docHash: bytes32(0),
            mintedAtISO: 0,
            presenceMask: 1
        });
        
        bytes32[] memory proof = new bytes32[](0);
        
        vm.prank(user1);
        vm.expectRevert("Minting: caller not PoR minter");
        minting.mintWithProof(user1, 100 * 10 ** 18, leaf, proof);
    }

    function test_RevertMintWithProofZeroAmount() public {
        GIFTBatchRegistry.LeafInput memory leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 1000 * 10 ** 18,
            fineWeightMg: 1_000_000,
            serialHash: keccak256("serial"),
            mineHash: bytes32(0),
            barStandardHash: bytes32(0),
            docHash: bytes32(0),
            mintedAtISO: 0,
            presenceMask: 1
        });
        
        bytes32[] memory proof = new bytes32[](0);
        
        vm.prank(minter);
        vm.expectRevert("Minting: amount=0");
        minting.mintWithProof(user1, 0, leaf, proof);
    }

    function test_RevertMintWithProofRegistryNotEnforced() public {
        minting.enforceRegistry(false);
        
        GIFTBatchRegistry.LeafInput memory leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 1000 * 10 ** 18,
            fineWeightMg: 1_000_000,
            serialHash: keccak256("serial"),
            mineHash: bytes32(0),
            barStandardHash: bytes32(0),
            docHash: bytes32(0),
            mintedAtISO: 0,
            presenceMask: 1
        });
        
        bytes32[] memory proof = new bytes32[](0);
        
        vm.prank(minter);
        vm.expectRevert("Minting: registry not enforced");
        minting.mintWithProof(user1, 100 * 10 ** 18, leaf, proof);
    }

    function test_RevertMintWithProofBatchNotAllowed() public {
        GIFTBatchRegistry.LeafInput memory leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 1000 * 10 ** 18,
            fineWeightMg: 1_000_000,
            serialHash: keccak256("serial"),
            mineHash: bytes32(0),
            barStandardHash: bytes32(0),
            docHash: bytes32(0),
            mintedAtISO: 0,
            presenceMask: 1
        });
        
        bytes32[] memory proof = new bytes32[](0);
        
        vm.prank(minter);
        vm.expectRevert("Minting: batch not allowed");
        minting.mintWithProof(user1, 100 * 10 ** 18, leaf, proof);
    }

    function test_RevertMintWithProofExceedsAllowance() public {
        GIFTBatchRegistry.LeafInput memory leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: DEFAULT_ALLOWANCE + 1000 * 10 ** 18,
            fineWeightMg: (DEFAULT_ALLOWANCE + 1000 * 10 ** 18) / (10 ** 18),
            serialHash: keccak256("serial"),
            mineHash: bytes32(0),
            barStandardHash: bytes32(0),
            docHash: bytes32(0),
            mintedAtISO: 0,
            presenceMask: 1
        });
        
        (bytes32 root, bytes32[] memory proof) = generateMerkleTree(leaf);
        uint256 batchId = registry.registerBatch(root, leaf.quantity, "", bytes32(0), true);
        leaf.batchId = batchId;
        (root, proof) = generateMerkleTree(leaf);
        minting.allowBatch(batchId, true);
        
        vm.prank(minter);
        vm.expectRevert("Minting: exceeds allowance");
        minting.mintWithProof(user1, DEFAULT_ALLOWANCE + 1, leaf, proof);
    }

    function test_RevertMintWithProofInsufficientReserve() public {
        // Reduce reserve below allowance
        vm.prank(minter);
        por.updateReserveAfterMint(vault1, INITIAL_RESERVE - 100 * 10 ** 18);
        
        GIFTBatchRegistry.LeafInput memory leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 1000 * 10 ** 18,
            fineWeightMg: 1_000_000,
            serialHash: keccak256("serial"),
            mineHash: bytes32(0),
            barStandardHash: bytes32(0),
            docHash: bytes32(0),
            mintedAtISO: 0,
            presenceMask: 1
        });
        
        (bytes32 root, bytes32[] memory proof) = generateMerkleTree(leaf);
        uint256 batchId = registry.registerBatch(root, leaf.quantity, "", bytes32(0), true);
        leaf.batchId = batchId;
        (root, proof) = generateMerkleTree(leaf);
        minting.allowBatch(batchId, true);
        
        vm.prank(minter);
        vm.expectRevert("Minting: insufficient reserve");
        minting.mintWithProof(user1, 200 * 10 ** 18, leaf, proof);
    }

    // ============ Legacy Mint Tests (no proof) ============

    function test_Mint_NoProof() public {
        minting.enforceRegistry(false);
        
        uint256 mintAmount = 1000 * 10 ** 18;
        vm.prank(minter);
        minting.mint(user1, mintAmount, vault1);
        
        assertEq(gift.balanceOf(user1), mintAmount);
    }

    function test_RevertMint_ProofRequired() public {
        // Registry enforced by default in setUp
        vm.prank(minter);
        vm.expectRevert("Minting: proof required");
        minting.mint(user1, 1000 * 10 ** 18, vault1);
    }

    function test_RevertMint_NotMinter() public {
        minting.enforceRegistry(false);
        
        vm.prank(user1);
        vm.expectRevert("Minting: caller not PoR minter");
        minting.mint(user1, 1000 * 10 ** 18, vault1);
    }

    function test_RevertMint_ZeroAmount() public {
        minting.enforceRegistry(false);
        
        vm.prank(minter);
        vm.expectRevert("Minting: amount=0");
        minting.mint(user1, 0, vault1);
    }

    function test_RevertMint_ExceedsAllowance() public {
        minting.enforceRegistry(false);
        
        vm.prank(minter);
        vm.expectRevert("Minting: exceeds allowance");
        minting.mint(user1, DEFAULT_ALLOWANCE + 1, vault1);
    }

    // ============ Burn Tests ============

    function test_BurnFrom() public {
        // Mint first
        minting.enforceRegistry(false);
        vm.prank(minter);
        minting.mint(user1, 1000 * 10 ** 18, vault1);
        
        // Burn
        vm.prank(owner); // PoR owner
        minting.burnFrom(user1, 500 * 10 ** 18);
        
        assertEq(gift.balanceOf(user1), 500 * 10 ** 18);
    }

    function test_RevertBurnFromNotPoROwner() public {
        vm.prank(user1);
        vm.expectRevert("Minting: only PoR owner can burn");
        minting.burnFrom(user1, 500 * 10 ** 18);
    }

    function test_BurnEscrowBalance() public {
        // Mint to escrow
        minting.enforceRegistry(false);
        vm.prank(minter);
        minting.mint(address(escrow), 1000 * 10 ** 18, vault1);
        
        // Burn from escrow
        vm.prank(address(escrow));
        minting.burnEscrowBalance(500 * 10 ** 18);
        
        assertEq(gift.balanceOf(address(escrow)), 500 * 10 ** 18);
    }

    function test_RevertBurnEscrowBalanceNotEscrow() public {
        vm.prank(user1);
        vm.expectRevert("Minting: only escrow");
        minting.burnEscrowBalance(500 * 10 ** 18);
    }

    function test_RevertBurnEscrowBalanceZeroAmount() public {
        vm.prank(address(escrow));
        vm.expectRevert("Minting: amount=0");
        minting.burnEscrowBalance(0);
    }

    // ============ PoR Update Tests ============

    function test_UpdatePoR() public {
        GIFTPoR newPoR = deployPoR();
        
        vm.prank(owner); // PoR owner
        minting.updatePoR(address(newPoR));
        
        assertEq(address(minting.giftpor()), address(newPoR));
    }

    function test_RevertUpdatePoRNotOwner() public {
        GIFTPoR newPoR = deployPoR();
        
        vm.prank(user1);
        vm.expectRevert("Minting: only PoR owner");
        minting.updatePoR(address(newPoR));
    }

    // ============ Admin Management Tests ============

    function test_GetAdmin() public {
        assertEq(minting.getAdmin(), owner);
    }

    function test_ChangeAdmin() public {
        address newAdmin = makeAddr("newAdmin");
        
        vm.prank(owner);
        vm.expectRevert("Ownable: caller is not the owner");
        minting.changeAdmin(newAdmin);
    }

    function test_RevertChangeAdminNotPoROwner() public {
        vm.prank(user1);
        vm.expectRevert("Minting: only PoR owner");
        minting.changeAdmin(user1);
    }

    function test_RevertChangeAdminZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Minting: zero");
        minting.changeAdmin(address(0));
    }

    // ============ Events Tests ============

    function test_EmitRegistrySet() public {
        GIFTBatchRegistry newRegistry = deployRegistry();
        
        vm.expectEmit(true, false, false, false);
        emit MintingUpgradeable.RegistrySet(address(newRegistry));
        minting.setRegistry(address(newRegistry));
    }

    function test_EmitRegistryEnforced() public {
        vm.expectEmit(false, false, false, true);
        emit MintingUpgradeable.RegistryEnforced(false);
        minting.enforceRegistry(false);
    }

    function test_EmitBatchAllowed() public {
        vm.expectEmit(true, false, false, true);
        emit MintingUpgradeable.BatchAllowed(1, true);
        minting.allowBatch(1, true);
    }

    function test_EmitEscrowSet() public {
        address newEscrow = makeAddr("newEscrow");
        
        vm.expectEmit(true, false, false, false);
        emit MintingUpgradeable.EscrowSet(newEscrow);
        
        vm.prank(owner);
        minting.setEscrow(newEscrow);
    }

    function test_EmitTokensMinted() public {
        minting.enforceRegistry(false);
        
        vm.expectEmit(true, false, false, true);
        emit MintingUpgradeable.TokensMinted(user1, 1000 * 10 ** 18, vault1, 0, bytes32(0));
        
        vm.prank(minter);
        minting.mint(user1, 1000 * 10 ** 18, vault1);
    }

    // ============ Upgradability Tests ============

    function test_UpgradeContract() public {
        MintingUpgradeable newImpl = new MintingUpgradeable();
        
        vm.prank(owner);
        minting.upgradeTo(address(newImpl));
        
        // Verify state is preserved
        assertEq(address(minting.gift()), address(gift));
    }

    function test_RevertUpgradeNotOwner() public {
        MintingUpgradeable newImpl = new MintingUpgradeable();
        
        vm.prank(user1);
        vm.expectRevert();
        minting.upgradeTo(address(newImpl));
    }

    // ============ Complex Scenarios ============

    function test_MultipleMints_SameLeaf() public {
        // Create leaf with capacity for multiple mints
        GIFTBatchRegistry.LeafInput memory leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 10000 * 10 ** 18,
            fineWeightMg: 10_000_000,
            serialHash: keccak256("serial123"),
            mineHash: bytes32(0),
            barStandardHash: bytes32(0),
            docHash: bytes32(0),
            mintedAtISO: 0,
            presenceMask: 1
        });
        
        (bytes32 root, bytes32[] memory proof) = generateMerkleTree(leaf);
        uint256 batchId = registry.registerBatch(root, leaf.quantity, "", bytes32(0), true);
        leaf.batchId = batchId;
        (root, proof) = generateMerkleTree(leaf);
        minting.allowBatch(batchId, true);
        
        // First mint
        vm.prank(minter);
        minting.mintWithProof(user1, 3000 * 10 ** 18, leaf, proof);
        
        // Second mint
        vm.prank(minter);
        minting.mintWithProof(user2, 2000 * 10 ** 18, leaf, proof);
        
        assertEq(gift.balanceOf(user1), 3000 * 10 ** 18);
        assertEq(gift.balanceOf(user2), 2000 * 10 ** 18);
        assertEq(gift.totalSupply(), 5000 * 10 ** 18);
    }

    function test_MintAndBurn_Lifecycle() public {
        minting.enforceRegistry(false);
        
        // Mint
        vm.prank(minter);
        minting.mint(user1, 5000 * 10 ** 18, vault1);
        
        // Burn part
        vm.prank(owner);
        minting.burnFrom(user1, 2000 * 10 ** 18);
        
        // Mint more
        vm.prank(minter);
        minting.mint(user1, 1000 * 10 ** 18, vault1);
        
        assertEq(gift.balanceOf(user1), 4000 * 10 ** 18);
    }
}

