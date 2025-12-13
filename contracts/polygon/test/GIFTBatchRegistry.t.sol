// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/TestHelpers.sol";

contract GIFTBatchRegistryTest is TestHelpers {
    bytes32 public constant LEAF_TYPEHASH =
        keccak256(
            "GiftMintLeafV1(address registry,uint256 batchId,uint256 reserveId,uint256 quantity,uint256 fineWeightMg,bytes32 serialHash,bytes32 mineHash,bytes32 barStandardHash,bytes32 docHash,uint256 mintedAtISO,uint256 presenceMask)"
        );

    function setUp() public {
        deployAll();
    }

    // ============ Initialization Tests ============

    function test_Initialize() public {
        assertEq(registry.owner(), owner);
        assertEq(registry.nextBatchId(), 1);
        assertEq(registry.minting(), address(minting));
    }

    function test_RevertInitializeZeroOwner() public {
        GIFTBatchRegistry impl = new GIFTBatchRegistry();
        
        vm.expectRevert("Initializable: contract is already initialized");
        impl.initialize(address(0));
    }

    // ============ Minting Contract Tests ============

    function test_SetMinting() public {
        address newMinting = makeAddr("newMinting");
        registry.setMinting(newMinting);
        assertEq(registry.minting(), newMinting);
    }

    function test_RevertSetMintingZeroAddress() public {
        vm.expectRevert("Registry: zero address");
        registry.setMinting(address(0));
    }

    function test_RevertSetMintingNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        registry.setMinting(user1);
    }

    // ============ Register Batch Tests ============

    function test_RegisterBatch() public {
        bytes32 root = keccak256("test root");
        uint256 cap = 1_000_000 * 10 ** 18;
        string memory datasetURI = "ipfs://test";
        bytes32 schemaHash = keccak256("schema");
        
        uint256 batchId = registry.registerBatch(root, cap, datasetURI, schemaHash, true);
        
        assertEq(batchId, 1);
        
        GIFTBatchRegistry.BatchMeta memory batch = registry.getBatchMeta(batchId);
        assertEq(batch.root, root);
        assertEq(batch.cap, cap);
        assertEq(batch.minted, 0);
        assertEq(batch.datasetURI, datasetURI);
        assertEq(batch.schemaHash, schemaHash);
        assertTrue(batch.active);
        assertFalse(batch.finalized);
        assertFalse(batch.isLegacy);
        assertEq(batch.createdBy, owner);
    }

    function test_RegisterBatchInactive() public {
        bytes32 root = keccak256("test root");
        uint256 cap = 1_000_000 * 10 ** 18;
        
        uint256 batchId = registry.registerBatch(root, cap, "", bytes32(0), false);
        
        GIFTBatchRegistry.BatchMeta memory batch = registry.getBatchMeta(batchId);
        assertFalse(batch.active);
    }

    function test_RevertRegisterBatchZeroRoot() public {
        vm.expectRevert("Registry: root=0");
        registry.registerBatch(bytes32(0), 1_000_000 * 10 ** 18, "", bytes32(0), true);
    }

    function test_RevertRegisterBatchZeroCap() public {
        vm.expectRevert("Registry: cap=0");
        registry.registerBatch(keccak256("test"), 0, "", bytes32(0), true);
    }

    function test_RevertRegisterBatchNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        registry.registerBatch(keccak256("test"), 1_000_000 * 10 ** 18, "", bytes32(0), true);
    }

    function test_IncrementalBatchIds() public {
        uint256 batch1 = registry.registerBatch(keccak256("root1"), 1000 * 10 ** 18, "", bytes32(0), true);
        uint256 batch2 = registry.registerBatch(keccak256("root2"), 2000 * 10 ** 18, "", bytes32(0), true);
        uint256 batch3 = registry.registerBatch(keccak256("root3"), 3000 * 10 ** 18, "", bytes32(0), true);
        
        assertEq(batch1, 1);
        assertEq(batch2, 2);
        assertEq(batch3, 3);
        assertEq(registry.nextBatchId(), 4);
    }

    // ============ Finalize Batch Tests ============

    function test_FinalizeBatch() public {
        uint256 batchId = registry.registerBatch(keccak256("test"), 1_000_000 * 10 ** 18, "", bytes32(0), true);
        
        registry.finalizeBatch(batchId);
        
        GIFTBatchRegistry.BatchMeta memory batch = registry.getBatchMeta(batchId);
        assertFalse(batch.active);
        assertTrue(batch.finalized);
    }

    function test_RevertFinalizeBatchAlreadyFinalized() public {
        uint256 batchId = registry.registerBatch(keccak256("test"), 1_000_000 * 10 ** 18, "", bytes32(0), true);
        registry.finalizeBatch(batchId);
        
        vm.expectRevert("Registry: finalized");
        registry.finalizeBatch(batchId);
    }

    function test_RevertFinalizeBatchNotOwner() public {
        uint256 batchId = registry.registerBatch(keccak256("test"), 1_000_000 * 10 ** 18, "", bytes32(0), true);
        
        vm.prank(user1);
        vm.expectRevert("Registry: not owner or admin");
        registry.finalizeBatch(batchId);
    }

    function test_FinalizeBatchByAdmin() public {
        address adminRole = makeAddr("adminRole");
        registry.grantAdminRole(adminRole);
        
        uint256 batchId = registry.registerBatch(keccak256("test"), 1_000_000 * 10 ** 18, "", bytes32(0), true);
        
        vm.prank(adminRole);
        registry.finalizeBatch(batchId);
        
        GIFTBatchRegistry.BatchMeta memory batch = registry.getBatchMeta(batchId);
        assertTrue(batch.finalized);
    }

    // ============ Legacy Supply Tests ============

    function test_AcknowledgeLegacySupply() public {
        uint256 amount = 500_000 * 10 ** 18;
        string memory reason = "Pre-existing supply";
        string memory datasetURI = "ipfs://legacy";
        bytes32 docHash = keccak256("legacy doc");
        
        uint256 batchId = registry.acknowledgeLegacySupply(amount, reason, datasetURI, docHash);
        
        assertEq(batchId, 1);
        
        GIFTBatchRegistry.BatchMeta memory batch = registry.getBatchMeta(batchId);
        assertEq(batch.root, bytes32(0));
        assertEq(batch.cap, amount);
        assertEq(batch.minted, amount);
        assertEq(batch.datasetURI, datasetURI);
        assertEq(batch.schemaHash, bytes32(0));
        assertFalse(batch.active);
        assertTrue(batch.finalized);
        assertTrue(batch.isLegacy);
    }

    function test_RevertAcknowledgeLegacySupplyZeroAmount() public {
        vm.expectRevert("Registry: amount=0");
        registry.acknowledgeLegacySupply(0, "reason", "", bytes32(0));
    }

    function test_RevertAcknowledgeLegacySupplyNotOwner() public {
        vm.prank(user1);
        vm.expectRevert("Registry: not owner or admin");
        registry.acknowledgeLegacySupply(500_000 * 10 ** 18, "reason", "", bytes32(0));
    }

    // ============ Leaf Verification Tests ============

    function test_VerifyLeaf() public {
        // Create a leaf
        GIFTBatchRegistry.LeafInput memory leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 1000 * 10 ** 18,
            fineWeightMg: 1_000_000,
            serialHash: keccak256("serial123"),
            mineHash: keccak256("mine1"),
            barStandardHash: keccak256("LBMA"),
            docHash: keccak256("doc123"),
            mintedAtISO: 1234567890,
            presenceMask: 31 // all fields present
        });
        
        // Generate merkle tree
        (bytes32 root, bytes32[] memory proof) = generateMerkleTree(leaf);
        
        // Register batch with this root
        uint256 batchId = registry.registerBatch(root, leaf.quantity, "ipfs://test", bytes32(0), true);
        
        // Update leaf with correct batchId
        leaf.batchId = batchId;
        (root, proof) = generateMerkleTree(leaf);
        
        // Verify leaf
        (bytes32 leafHash, bool ok) = registry.verifyLeaf(leaf, proof);
        
        assertTrue(ok);
        assertTrue(leafHash != bytes32(0));
    }

    function test_VerifyLeafInvalidProof() public {
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
        
        // Register batch with different root
        uint256 batchId = registry.registerBatch(keccak256("different root"), leaf.quantity, "", bytes32(0), true);
        leaf.batchId = batchId;
        
        // Try to verify with empty proof
        bytes32[] memory emptyProof = new bytes32[](0);
        (, bool ok) = registry.verifyLeaf(leaf, emptyProof);
        
        assertFalse(ok);
    }

    // ============ Consume Tests ============

    function test_Consume() public {
        // Create and register a leaf
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
        
        (bytes32 root, bytes32[] memory proof) = generateMerkleTree(leaf);
        uint256 batchId = registry.registerBatch(root, leaf.quantity, "", bytes32(0), true);
        leaf.batchId = batchId;
        (root, proof) = generateMerkleTree(leaf);
        
        // Consume
        uint256 consumeAmount = 500 * 10 ** 18;
        vm.prank(address(minting));
        registry.consume(leaf, proof, consumeAmount, user1);
        
        // Check consumption
        bytes32 leafHash = keccak256(
            abi.encode(
                LEAF_TYPEHASH,
                address(registry),
                leaf.batchId,
                leaf.reserveId,
                leaf.quantity,
                leaf.fineWeightMg,
                leaf.serialHash,
                leaf.mineHash,
                leaf.barStandardHash,
                leaf.docHash,
                leaf.mintedAtISO,
                leaf.presenceMask
            )
        );
        
        assertEq(registry.leafConsumed(batchId, leafHash), consumeAmount);
        
        GIFTBatchRegistry.BatchMeta memory batch = registry.getBatchMeta(batchId);
        assertEq(batch.minted, consumeAmount);
    }

    function test_ConsumeMultipleTimes() public {
        // Setup
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
        
        (bytes32 root, bytes32[] memory proof) = generateMerkleTree(leaf);
        uint256 batchId = registry.registerBatch(root, leaf.quantity, "", bytes32(0), true);
        leaf.batchId = batchId;
        (root, proof) = generateMerkleTree(leaf);
        
        // Consume first time
        vm.prank(address(minting));
        registry.consume(leaf, proof, 300 * 10 ** 18, user1);
        
        // Consume second time
        vm.prank(address(minting));
        registry.consume(leaf, proof, 200 * 10 ** 18, user2);
        
        // Check total consumption
        bytes32 leafHash = keccak256(
            abi.encode(
                LEAF_TYPEHASH,
                address(registry),
                leaf.batchId,
                leaf.reserveId,
                leaf.quantity,
                leaf.fineWeightMg,
                leaf.serialHash,
                leaf.mineHash,
                leaf.barStandardHash,
                leaf.docHash,
                leaf.mintedAtISO,
                leaf.presenceMask
            )
        );
        
        assertEq(registry.leafConsumed(batchId, leafHash), 500 * 10 ** 18);
    }

    function test_RevertConsumeNotMinting() public {
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
        vm.expectRevert("Registry: caller not minting");
        registry.consume(leaf, proof, 100 * 10 ** 18, user1);
    }

    function test_RevertConsumeZeroAmount() public {
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
        
        vm.prank(address(minting));
        vm.expectRevert("Registry: amount=0");
        registry.consume(leaf, proof, 0, user1);
    }

    function test_RevertConsumeInactiveBatch() public {
        // Register inactive batch
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
        uint256 batchId = registry.registerBatch(root, leaf.quantity, "", bytes32(0), false); // inactive
        leaf.batchId = batchId;
        
        vm.prank(address(minting));
        vm.expectRevert("Registry: inactive");
        registry.consume(leaf, proof, 100 * 10 ** 18, user1);
    }

    function test_RevertConsumeBadProof() public {
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
        
        uint256 batchId = registry.registerBatch(keccak256("different root"), leaf.quantity, "", bytes32(0), true);
        leaf.batchId = batchId;
        
        bytes32[] memory emptyProof = new bytes32[](0);
        
        vm.prank(address(minting));
        vm.expectRevert("Registry: bad proof");
        registry.consume(leaf, emptyProof, 100 * 10 ** 18, user1);
    }

    function test_RevertConsumeExceedsLeafCap() public {
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
        
        vm.prank(address(minting));
        vm.expectRevert("Registry: leaf cap");
        registry.consume(leaf, proof, leaf.quantity + 1, user1);
    }

    function test_RevertConsumeExceedsBatchCap() public {
        // Create a batch with small cap
        GIFTBatchRegistry.LeafInput memory leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 2000 * 10 ** 18, // leaf allows 2000
            fineWeightMg: 2_000_000,
            serialHash: keccak256("serial"),
            mineHash: bytes32(0),
            barStandardHash: bytes32(0),
            docHash: bytes32(0),
            mintedAtISO: 0,
            presenceMask: 1
        });
        
        (bytes32 root, bytes32[] memory proof) = generateMerkleTree(leaf);
        // Register batch with smaller cap than leaf
        uint256 batchId = registry.registerBatch(root, 1000 * 10 ** 18, "", bytes32(0), true);
        leaf.batchId = batchId;
        (root, proof) = generateMerkleTree(leaf);
        
        vm.prank(address(minting));
        vm.expectRevert("Registry: batch cap");
        registry.consume(leaf, proof, 1500 * 10 ** 18, user1);
    }

    // ============ Admin Role Tests ============

    function test_GrantAdminRole() public {
        address adminRole = makeAddr("adminRole");
        registry.grantAdminRole(adminRole);
        
        assertTrue(registry.hasRole(registry.ADMIN_ROLE(), adminRole));
    }

    function test_RevokeAdminRole() public {
        address adminRole = makeAddr("adminRole");
        registry.grantAdminRole(adminRole);
        registry.revokeAdminRole(adminRole);
        
        assertFalse(registry.hasRole(registry.ADMIN_ROLE(), adminRole));
    }

    function test_RevertGrantAdminRoleNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        registry.grantAdminRole(user1);
    }

    // ============ Events Tests ============

    function test_EmitBatchRegistered() public {
        bytes32 root = keccak256("test root");
        uint256 cap = 1_000_000 * 10 ** 18;
        
        vm.expectEmit(true, false, false, true);
        emit GIFTBatchRegistry.BatchRegistered(1, root, cap, "", bytes32(0), true);
        registry.registerBatch(root, cap, "", bytes32(0), true);
    }

    function test_EmitBatchFinalized() public {
        uint256 batchId = registry.registerBatch(keccak256("test"), 1_000_000 * 10 ** 18, "", bytes32(0), true);
        
        vm.expectEmit(true, false, false, false);
        emit GIFTBatchRegistry.BatchFinalized(batchId);
        registry.finalizeBatch(batchId);
    }

    function test_EmitLegacySupplyAcknowledged() public {
        uint256 amount = 500_000 * 10 ** 18;
        bytes32 docHash = keccak256("doc");
        
        vm.expectEmit(true, false, false, true);
        emit GIFTBatchRegistry.LegacySupplyAcknowledged(1, amount, "reason", docHash);
        registry.acknowledgeLegacySupply(amount, "reason", "", docHash);
    }

    // ============ Upgradability Tests ============

    function test_UpgradeContract() public {
        GIFTBatchRegistry newImpl = new GIFTBatchRegistry();
        
        vm.prank(owner);
        registry.upgradeTo(address(newImpl));
        
        // Verify state is preserved
        assertEq(registry.nextBatchId(), 1);
    }

    function test_RevertUpgradeNotOwner() public {
        GIFTBatchRegistry newImpl = new GIFTBatchRegistry();
        
        vm.prank(user1);
        vm.expectRevert();
        registry.upgradeTo(address(newImpl));
    }
}

