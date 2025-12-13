// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/TestHelpers.sol";

contract GiftRedemptionEscrowUpgradeableTest is TestHelpers {
    function setUp() public {
        deployAll();
        // Configure a default PoR minter for integration-style flows
        setupMinter(minter, vault1, DEFAULT_ALLOWANCE);
        // Whitelist the marketplace that will lock GIFT for NFTs
        escrow.setMarketplace(marketplace, true);
    }

    // ============ Initialization ============

    function test_Initialize() public {
        assertEq(address(escrow.gift()), address(gift));
        assertEq(address(escrow.minting()), address(minting));
        assertEq(escrow.owner(), owner);
    }

    // ============ Marketplace configuration ============

    function test_SetMarketplace() public {
        address newMarketplace = makeAddr("newMarketplace");
        escrow.setMarketplace(newMarketplace, true);
        assertTrue(escrow.isMarketplace(newMarketplace));
    }

    function test_RevertSetMarketplaceNotOwner() public {
        address other = makeAddr("other");
        vm.prank(other);
        vm.expectRevert();
        escrow.setMarketplace(other, true);
    }

    // ============ Locking GIFT for NFT purchase ============

    function _mintGiftToUser(address to, uint256 amount) internal {
        minting.enforceRegistry(false);
        vm.prank(minter);
        minting.mint(to, amount, vault1);
    }

    function _mintBarToUser(address to) internal returns (uint256 tokenId, GIFTBatchRegistry.LeafInput memory leaf, bytes32[] memory proof) {
        // Create a simple leaf for 1kg bar backed by 1000 GIFT
        leaf = GIFTBatchRegistry.LeafInput({
            batchId: 1,
            reserveId: vault1,
            quantity: 1000 * 10 ** 18,
            fineWeightMg: 1_000_000,
            serialHash: keccak256("BAR123"),
            mineHash: bytes32(0),
            barStandardHash: bytes32(0),
            docHash: bytes32(0),
            mintedAtISO: 0,
            presenceMask: 1
        });

        (bytes32 root, bytes32[] memory p) = generateMerkleTree(leaf);
        uint256 batchId = registry.registerBatch(root, leaf.quantity, "", bytes32(0), true);
        leaf.batchId = batchId;
        (root, p) = generateMerkleTree(leaf);
        proof = p;

        vm.prank(address(escrow));
        nft.mintBarsFromLeaf(to, 1, leaf, proof);

        tokenId = 1;
    }

    function test_LockGiftForNFT() public {
        uint256 price = 1_000 * 10 ** 18;
        _mintGiftToUser(user1, price);

        // No tax on this flow to keep accounting simple
        taxManager.setFeeExclusion(user1, true, true);
        taxManager.setFeeExclusion(address(escrow), true, true);

        // Approve marketplace and lock GIFT
        vm.prank(user1);
        gift.approve(address(escrow), price);

        uint256 tokenId;
        (tokenId, , ) = _mintBarToUser(user1);

        vm.expectEmit(true, true, false, true);
        emit GiftRedemptionEscrowUpgradeable.GiftLockedForNFT(address(nft), tokenId, price, user1);

        vm.prank(marketplace);
        escrow.lockGiftForNFT(address(nft), tokenId, price, user1);

        ( , , uint256 giftAmount, address purchaser, bool initialized, , , , ) =
            escrow.escrows(address(nft), tokenId);

        assertEq(giftAmount, price);
        assertEq(purchaser, user1);
        assertTrue(initialized);
        assertEq(gift.balanceOf(address(escrow)), price);
    }

    function test_RevertLockGiftForNFTNotMarketplace() public {
        uint256 price = 1_000 * 10 ** 18;
        _mintGiftToUser(user1, price);

        vm.prank(user1);
        gift.approve(address(escrow), price);

        (uint256 tokenId, , ) = _mintBarToUser(user1);

        vm.prank(user1);
        vm.expectRevert("Escrow: caller not marketplace");
        escrow.lockGiftForNFT(address(nft), tokenId, price, user1);
    }

    // ============ Redemption request (onERC721Received) ============

    function _setupLockedEscrowRecord(uint256 price)
        internal
        returns (uint256 tokenId)
    {
        _mintGiftToUser(user1, price);
        taxManager.setFeeExclusion(user1, true, true);
        taxManager.setFeeExclusion(address(escrow), true, true);

        vm.prank(user1);
        gift.approve(address(escrow), price);

        (tokenId, , ) = _mintBarToUser(user1);

        vm.prank(marketplace);
        escrow.lockGiftForNFT(address(nft), tokenId, price, user1);
    }

    function test_RedemptionRequest_onERC721Received() public {
        uint256 price = 1_000 * 10 ** 18;
        uint256 tokenId = _setupLockedEscrowRecord(price);

        vm.expectEmit(true, true, true, true);
        emit GiftRedemptionEscrowUpgradeable.RedemptionRequested(address(nft), tokenId, user1, price);

        vm.prank(user1);
        nft.safeTransferFrom(user1, address(escrow), tokenId);

        ( , , , , bool initialized, bool inRedemption, address redeemer, bool redeemed, bool cancelled ) =
            escrow.escrows(address(nft), tokenId);

        assertTrue(initialized);
        assertTrue(inRedemption);
        assertEq(redeemer, user1);
        assertFalse(redeemed);
        assertFalse(cancelled);
    }

    // ============ Cancel redemption ============

    function test_CancelRedemption() public {
        uint256 price = 1_000 * 10 ** 18;
        uint256 tokenId = _setupLockedEscrowRecord(price);

        vm.prank(user1);
        nft.safeTransferFrom(user1, address(escrow), tokenId);

        vm.expectEmit(true, true, true, true);
        emit GiftRedemptionEscrowUpgradeable.RedemptionCancelled(address(nft), tokenId, user1);

        vm.prank(owner);
        escrow.cancelRedemption(address(nft), tokenId);

        ( , , , , , bool inRedemption, address redeemer, bool redeemed, bool cancelled ) =
            escrow.escrows(address(nft), tokenId);

        assertFalse(inRedemption);
        assertTrue(cancelled);
        assertFalse(redeemed);
        assertEq(redeemer, user1);
        assertEq(nft.ownerOf(tokenId), user1);
    }

    function test_RevertCancelRedemptionNotOwner() public {
        uint256 price = 1_000 * 10 ** 18;
        uint256 tokenId = _setupLockedEscrowRecord(price);

        vm.prank(user1);
        nft.safeTransferFrom(user1, address(escrow), tokenId);

        vm.prank(user1);
        vm.expectRevert();
        escrow.cancelRedemption(address(nft), tokenId);
    }

    // ============ Complete redemption (full end-to-end flow) ============

    function test_CompleteRedemption_FullFlow() public {
        uint256 price = 1_000 * 10 ** 18;
        uint256 tokenId = _setupLockedEscrowRecord(price);

        // User sends NFT to escrow to request redemption
        vm.prank(user1);
        nft.safeTransferFrom(user1, address(escrow), tokenId);

        // Escrow holds locked GIFT backing the bar
        assertEq(gift.balanceOf(address(escrow)), price);

        vm.expectEmit(true, true, true, true);
        emit GiftRedemptionEscrowUpgradeable.RedemptionCompleted(address(nft), tokenId, user1, price);

        // Ops completes redemption: burns GIFT via MintingUpgradeable and burns the NFT
        vm.prank(owner);
        escrow.completeRedemption(address(nft), tokenId);

        // GIFT burned from escrow
        assertEq(gift.balanceOf(address(escrow)), 0);

        // NFT burned and record marked redeemed
        vm.expectRevert();
        nft.ownerOf(tokenId);

        ( , , uint256 giftAmount, , bool initialized, bool inRedemption, , bool redeemed, bool cancelled ) =
            escrow.escrows(address(nft), tokenId);

        assertTrue(initialized);
        assertFalse(inRedemption);
        assertTrue(redeemed);
        assertFalse(cancelled);
        assertEq(giftAmount, price);
    }
}


