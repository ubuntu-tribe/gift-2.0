// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/TestHelpers.sol";

contract GIFTBarNFTDeferredTest is TestHelpers {
    function setUp() public {
        deployAll();
    }

    // ============ Initialization Tests ============

    function test_Initialize() public {
        assertEq(nft.name(), "GIFT Gold Bar");
        assertEq(nft.symbol(), "GIFTBAR");
        assertEq(address(nft.registry()), address(registry));
        assertEq(nft.owner(), address(escrow)); // Transferred in setup
        assertEq(nft.unitMg(), 1_000_000); // 1 kg default
        assertEq(nft.nextId(), 1);
    }

    // ============ Unit Mg Configuration Tests ============

    function test_SetUnitMg() public {
        // Deploy new NFT contract that we control
        GIFTBarNFTDeferred testNft = new GIFTBarNFTDeferred(address(registry));
        
        testNft.setUnitMg(500_000); // 500g bars
        assertEq(testNft.unitMg(), 500_000);
    }

    function test_RevertSetUnitMgZero() public {
        GIFTBarNFTDeferred testNft = new GIFTBarNFTDeferred(address(registry));
        
        vm.expectRevert("unitMg=0");
        testNft.setUnitMg(0);
    }

    function test_RevertSetUnitMgNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.setUnitMg(500_000);
    }

    // ============ Base URI Tests ============

    function test_SetBaseURI() public {
        GIFTBarNFTDeferred testNft = new GIFTBarNFTDeferred(address(registry));
        
        string memory uri = "https://api.gift.gold/bars";
        testNft.setBaseURI(uri);
        assertEq(testNft.baseURI(), uri);
    }

    function test_RevertSetBaseURINotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.setBaseURI("https://test.com");
    }

    // ============ Capacity Mode Tests ============

    function test_SetCapacityMode() public {
        GIFTBarNFTDeferred testNft = new GIFTBarNFTDeferred(address(registry));
        
        testNft.setCapacityMode(GIFTBarNFTDeferred.CapacityMode.STRICT_CONSUMED);
        assertEq(uint(testNft.capacityMode()), uint(GIFTBarNFTDeferred.CapacityMode.STRICT_CONSUMED));
    }

    function test_RevertSetCapacityModeNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.setCapacityMode(GIFTBarNFTDeferred.CapacityMode.STRICT_CONSUMED);
    }

    // ============ Mint Bars From Leaf Tests ============

    function test_MintBarsFromLeaf() public {
        // Create leaf with 5kg gold (5 bars at 1kg each)
        GIFTBatchRegistry.LeafInput memory leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 5000 * 10 ** 18,
            fineWeightMg: 5_000_000, // 5 kg
            serialHash: keccak256("BAR123"),
            mineHash: keccak256("MINE1"),
            barStandardHash: keccak256("LBMA"),
            docHash: keccak256("DOC123"),
            mintedAtISO: 1234567890,
            presenceMask: 31
        });
        
        (bytes32 root, bytes32[] memory proof) = generateMerkleTree(leaf);
        uint256 batchId = registry.registerBatch(root, leaf.quantity, "ipfs://test", bytes32(0), true);
        leaf.batchId = batchId;
        (root, proof) = generateMerkleTree(leaf);
        
        // Mint 3 NFTs
        vm.prank(address(escrow));
        nft.mintBarsFromLeaf(user1, 3, leaf, proof);
        
        // Verify ownership
        assertEq(nft.balanceOf(user1), 3);
        assertEq(nft.ownerOf(1), user1);
        assertEq(nft.ownerOf(2), user1);
        assertEq(nft.ownerOf(3), user1);
        assertEq(nft.nextId(), 4);
        
        // Check bar info
        (
            uint256 bId,
            bytes32 lHash,
            uint256 rId,
            uint256 uMg,
            bytes32 serial,
            bytes32 mine,
            bytes32 barStd,
            bytes32 doc
        ) = nft.barInfo(1);
        
        assertEq(bId, batchId);
        assertEq(rId, vault1);
        assertEq(uMg, 1_000_000);
        assertEq(serial, leaf.serialHash);
        assertEq(mine, leaf.mineHash);
        assertEq(barStd, leaf.barStandardHash);
        assertEq(doc, leaf.docHash);
    }

    function test_MintMultipleBatches() public {
        // First batch
        GIFTBatchRegistry.LeafInput memory leaf1 = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 2000 * 10 ** 18,
            fineWeightMg: 2_000_000,
            serialHash: keccak256("BAR1"),
            mineHash: bytes32(0),
            barStandardHash: bytes32(0),
            docHash: bytes32(0),
            mintedAtISO: 0,
            presenceMask: 1
        });
        
        (bytes32 root1, bytes32[] memory proof1) = generateMerkleTree(leaf1);
        uint256 batchId1 = registry.registerBatch(root1, leaf1.quantity, "", bytes32(0), true);
        leaf1.batchId = batchId1;
        (root1, proof1) = generateMerkleTree(leaf1);
        
        // Second batch
        GIFTBatchRegistry.LeafInput memory leaf2 = GIFTBatchRegistry.LeafInput({
            batchId: 2,
            reserveId: vault1,
            quantity: 3000 * 10 ** 18,
            fineWeightMg: 3_000_000,
            serialHash: keccak256("BAR2"),
            mineHash: bytes32(0),
            barStandardHash: bytes32(0),
            docHash: bytes32(0),
            mintedAtISO: 0,
            presenceMask: 1
        });
        
        (bytes32 root2, bytes32[] memory proof2) = generateMerkleTree(leaf2);
        uint256 batchId2 = registry.registerBatch(root2, leaf2.quantity, "", bytes32(0), true);
        leaf2.batchId = batchId2;
        (root2, proof2) = generateMerkleTree(leaf2);
        
        // Mint from first batch
        vm.prank(address(escrow));
        nft.mintBarsFromLeaf(user1, 2, leaf1, proof1);
        
        // Mint from second batch
        vm.prank(address(escrow));
        nft.mintBarsFromLeaf(user2, 3, leaf2, proof2);
        
        assertEq(nft.balanceOf(user1), 2);
        assertEq(nft.balanceOf(user2), 3);
        assertEq(nft.nextId(), 6);
    }

    function test_RevertMintBarsFromLeafZeroUnits() public {
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
        
        vm.prank(address(escrow));
        vm.expectRevert("units=0");
        nft.mintBarsFromLeaf(user1, 0, leaf, proof);
    }

    function test_RevertMintBarsFromLeafBadProof() public {
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
        
        bytes32[] memory proof = new bytes32[](0);
        
        vm.prank(address(escrow));
        vm.expectRevert("bad merkle proof");
        nft.mintBarsFromLeaf(user1, 1, leaf, proof);
    }

    function test_RevertMintBarsFromLeafExceedsCapacity() public {
        // Leaf with 2kg gold = 2 bars
        GIFTBatchRegistry.LeafInput memory leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 2000 * 10 ** 18,
            fineWeightMg: 2_000_000,
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
        
        vm.prank(address(escrow));
        vm.expectRevert("exceeds capacity");
        nft.mintBarsFromLeaf(user1, 3, leaf, proof); // Trying to mint 3 bars from 2kg
    }

    function test_RevertMintBarsFromLeafNotOwner() public {
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
        vm.expectRevert();
        nft.mintBarsFromLeaf(user1, 1, leaf, proof);
    }

    // ============ Remaining Units Tests ============

    function test_RemainingUnits() public {
        GIFTBatchRegistry.LeafInput memory leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 5000 * 10 ** 18,
            fineWeightMg: 5_000_000, // 5 bars
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
        
        // Check initial remaining
        (, uint256 remaining) = nft.remainingUnits(leaf, proof);
        assertEq(remaining, 5);
        
        // Mint 2 bars
        vm.prank(address(escrow));
        nft.mintBarsFromLeaf(user1, 2, leaf, proof);
        
        // Check remaining after mint
        (, remaining) = nft.remainingUnits(leaf, proof);
        assertEq(remaining, 3);
    }

    // ============ Token URI Tests ============

    function test_TokenURI() public {
        GIFTBarNFTDeferred testNft = new GIFTBarNFTDeferred(address(registry));
        testNft.setBaseURI("https://api.gift.gold/bars");
        
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
        
        testNft.mintBarsFromLeaf(user1, 1, leaf, proof);
        
        string memory uri = testNft.tokenURI(1);
        assertTrue(bytes(uri).length > 0);
    }

    function test_TokenURIEmptyBase() public {
        // NFT without baseURI set
        string memory uri = nft.tokenURI(1);
        assertEq(bytes(uri).length, 0);
    }

    // ============ Burn Tests ============

    function test_Burn() public {
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
        
        vm.prank(address(escrow));
        nft.mintBarsFromLeaf(user1, 1, leaf, proof);
        
        uint256 tokenId = 1;
        assertEq(nft.ownerOf(tokenId), user1);
        
        // Burn
        vm.prank(address(escrow));
        nft.burn(tokenId);
        
        vm.expectRevert();
        nft.ownerOf(tokenId);
        
        assertEq(nft.balanceOf(user1), 0);
    }

    function test_RevertBurnNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        nft.burn(1);
    }

    // ============ ERC721 Standard Tests ============

    function test_TransferNFT() public {
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
        
        vm.prank(address(escrow));
        nft.mintBarsFromLeaf(user1, 1, leaf, proof);
        
        // Transfer
        vm.prank(user1);
        nft.transferFrom(user1, user2, 1);
        
        assertEq(nft.ownerOf(1), user2);
        assertEq(nft.balanceOf(user1), 0);
        assertEq(nft.balanceOf(user2), 1);
    }

    function test_ApproveAndTransfer() public {
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
        
        vm.prank(address(escrow));
        nft.mintBarsFromLeaf(user1, 1, leaf, proof);
        
        // Approve
        vm.prank(user1);
        nft.approve(user2, 1);
        
        // Transfer by approved address
        vm.prank(user2);
        nft.transferFrom(user1, user3, 1);
        
        assertEq(nft.ownerOf(1), user3);
    }

    // ============ Events Tests ============

    function test_EmitBarsMinted() public {
        GIFTBatchRegistry.LeafInput memory leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 2000 * 10 ** 18,
            fineWeightMg: 2_000_000,
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
        
        bytes32 leafHash = keccak256(
            abi.encode(
                registry.LEAF_TYPEHASH(),
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
        
        vm.expectEmit(true, true, false, true);
        emit GIFTBarNFTDeferred.BarsMinted(batchId, leafHash, vault1, 2, user1, 1, 2);
        
        vm.prank(address(escrow));
        nft.mintBarsFromLeaf(user1, 2, leaf, proof);
    }

    function test_EmitUnitMgSet() public {
        GIFTBarNFTDeferred testNft = new GIFTBarNFTDeferred(address(registry));
        
        vm.expectEmit(false, false, false, true);
        emit GIFTBarNFTDeferred.UnitMgSet(500_000);
        testNft.setUnitMg(500_000);
    }

    function test_EmitBaseURISet() public {
        GIFTBarNFTDeferred testNft = new GIFTBarNFTDeferred(address(registry));
        
        vm.expectEmit(false, false, false, true);
        emit GIFTBarNFTDeferred.BaseURISet("https://test.com");
        testNft.setBaseURI("https://test.com");
    }

    function test_EmitCapacityModeSet() public {
        GIFTBarNFTDeferred testNft = new GIFTBarNFTDeferred(address(registry));
        
        vm.expectEmit(false, false, false, true);
        emit GIFTBarNFTDeferred.CapacityModeSet(GIFTBarNFTDeferred.CapacityMode.STRICT_CONSUMED);
        testNft.setCapacityMode(GIFTBarNFTDeferred.CapacityMode.STRICT_CONSUMED);
    }

    // ============ Complex Scenarios ============

    function test_MintMultipleNFTsAndBurnSome() public {
        GIFTBatchRegistry.LeafInput memory leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 5000 * 10 ** 18,
            fineWeightMg: 5_000_000,
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
        
        // Mint 5 bars
        vm.prank(address(escrow));
        nft.mintBarsFromLeaf(user1, 5, leaf, proof);
        
        assertEq(nft.balanceOf(user1), 5);
        
        // Transfer some
        vm.prank(user1);
        nft.transferFrom(user1, user2, 2);
        
        vm.prank(user1);
        nft.transferFrom(user1, user3, 3);
        
        assertEq(nft.balanceOf(user1), 3);
        assertEq(nft.balanceOf(user2), 1);
        assertEq(nft.balanceOf(user3), 1);
        
        // Burn one
        vm.prank(address(escrow));
        nft.burn(1);
        
        assertEq(nft.balanceOf(user1), 2);
    }
}

