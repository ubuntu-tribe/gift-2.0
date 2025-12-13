// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

import "./GIFT.sol";
import "./MintingUpgradeable.sol";
import "./GIFTBarNFTDeferred.sol";

/**
 * @title GiftRedemptionEscrowUpgradeable
 * @notice
 *  - Locks GIFT tokens when users buy GIFTBar NFTs representing physical gold.
 *  - Stores a mapping from (nftContract, tokenId) → locked GIFT amount and metadata.
 *  - Accepts NFTs into escrow when users redeem via safeTransferFrom.
 *  - After physical shipment is confirmed, burns the locked GIFT via MintingUpgradeable.burnEscrowBalance(),
 *    and burns (or permanently locks) the NFT.
 *
 *  Cancel / exception paths:
 *   - adminRefundRedemption()     → NFT + GIFT back to redeemer (refund).
 *   - adminConfiscateRedemption() → NFT + GIFT to confiscationWallet (confiscation).
 *
 *  Requirements:
 *   - GIFT.supplyController must be the MintingUpgradeable contract.
 *   - MintingUpgradeable.setEscrow(address(this)) must be called after deployment.
 *   - For NFT burn, the escrow must be owner of the NFT contract (owner() on GIFTBarNFTDeferred),
 *     or the NFT contract must allow escrow to call burn(tokenId).
 */
contract GiftRedemptionEscrowUpgradeable is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    IERC721ReceiverUpgradeable
{
    struct EscrowRecord {
        address nftContract;
        uint256 tokenId;
        uint256 giftAmount;      // amount of GIFT locked (1 GIFT = 1 mg)
        address purchaser;       // original buyer who paid GIFT
        bool initialized;        // true once giftAmount is locked
        bool inRedemption;       // true while NFT is deposited for redemption
        address redeemer;        // address that deposited NFT for redemption
        bool redeemed;           // true once GIFT burned and redemption completed
        bool cancelled;          // true if redemption was cancelled (refund or confiscation)
        bool confiscated;        // true if admin confiscated NFT + GIFT
    }

    GIFT public gift;
    MintingUpgradeable public minting;

    // Allowed marketplace contracts that can lock GIFT when NFTs are bought
    mapping(address => bool) public isMarketplace;

    // Escrow state keyed by (nftContract → tokenId)
    mapping(address => mapping(uint256 => EscrowRecord)) public escrows;

    // Wallet that receives NFTs + GIFT on confiscation
    address public confiscationWallet;

    event MarketplaceSet(address indexed marketplace, bool allowed);
    event ConfiscationWalletSet(address indexed wallet);

    event GiftLockedForNFT(
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 giftAmount,
        address indexed purchaser
    );

    event RedemptionRequested(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed redeemer,
        uint256 giftAmount
    );

    // Admin-driven cancel (refund back to user)
    event RedemptionCancelledAndRefunded(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed redeemer,
        uint256 refundedAmount
    );

    // Admin-driven confiscation (NFT + GIFT to confiscation wallet)
    event RedemptionConfiscated(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed redeemer,
        uint256 confiscatedAmount
    );

    event RedemptionCompleted(
        address indexed nftContract,
        uint256 indexed tokenId,
        address indexed redeemer,
        uint256 giftAmount
    );

    // ---- Initializer / UUPS ----

    function initialize(address gift_, address minting_) public initializer {
        require(gift_ != address(0), "Escrow: GIFT is zero");
        require(minting_ != address(0), "Escrow: minting is zero");

        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();

        gift = GIFT(gift_);
        minting = MintingUpgradeable(minting_);

        // default confiscationWallet = owner; can be changed
        confiscationWallet = _msgSender();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    modifier onlyMarketplace() {
        require(isMarketplace[msg.sender], "Escrow: caller not marketplace");
        _;
    }

    // ---- Admin configuration ----

    function setMarketplace(address marketplace, bool allowed) external onlyOwner {
        require(marketplace != address(0), "Escrow: marketplace is zero");
        isMarketplace[marketplace] = allowed;
        emit MarketplaceSet(marketplace, allowed);
    }

    function setConfiscationWallet(address wallet) external onlyOwner {
        require(wallet != address(0), "Escrow: confiscation wallet zero");
        confiscationWallet = wallet;
        emit ConfiscationWalletSet(wallet);
    }

    // ---- Purchase phase: lock GIFT when NFT is bought ----

    /**
     * @notice Called by the marketplace contract when a user buys an NFT with GIFT.
     *
     * @param nftContract The NFT contract address (e.g. GIFTBarNFTDeferred).
     * @param tokenId     The NFT ID representing the bar/batch.
     * @param giftAmount  Amount of GIFT paid by the purchaser for this NFT.
     * @param purchaser   The buyer who paid in GIFT.
     *
     * Requirements:
     *  - msg.sender is a whitelisted marketplace.
     *  - NFT ID is not already initialized.
     *  - purchaser has approved the marketplace or this escrow for `giftAmount`.
     *
     * Effect:
     *  - Transfers `giftAmount` GIFT from `purchaser` to this escrow contract.
     *  - Creates an EscrowRecord tying that amount permanently to (nftContract, tokenId).
     */
    function lockGiftForNFT(
        address nftContract,
        uint256 tokenId,
        uint256 giftAmount,
        address purchaser
    ) external onlyMarketplace {
        require(nftContract != address(0), "Escrow: nftContract is zero");
        require(purchaser != address(0), "Escrow: purchaser is zero");
        require(giftAmount > 0, "Escrow: giftAmount is zero");

        EscrowRecord storage rec = escrows[nftContract][tokenId];
        require(!rec.initialized, "Escrow: NFT already initialized");

        bool ok = gift.transferFrom(purchaser, address(this), giftAmount);
        require(ok, "Escrow: GIFT transferFrom failed");

        rec.nftContract = nftContract;
        rec.tokenId = tokenId;
        rec.giftAmount = giftAmount;
        rec.purchaser = purchaser;
        rec.initialized = true;

        emit GiftLockedForNFT(nftContract, tokenId, giftAmount, purchaser);
    }

    // ---- Redemption request: NFT → escrow ----

    /**
     * @notice Called automatically when a user transfers the NFT to this contract
     *         using `safeTransferFrom(user, escrow, tokenId, data)`.
     *
     * We:
     *  - Verify an EscrowRecord exists.
     *  - Mark `inRedemption = true`.
     *  - Record `redeemer = from`.
     *  - Emit `RedemptionRequested`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata /* data */
    ) external override returns (bytes4) {
        address nftContract = msg.sender;

        EscrowRecord storage rec = escrows[nftContract][tokenId];
        require(rec.initialized, "Escrow: NFT not bound");
        require(!rec.redeemed, "Escrow: already redeemed");
        require(!rec.inRedemption, "Escrow: already in redemption");
        require(!rec.cancelled, "Escrow: already closed");
        require(from != address(0), "Escrow: invalid redeemer");

        rec.inRedemption = true;
        rec.redeemer = from;

        emit RedemptionRequested(nftContract, tokenId, from, rec.giftAmount);

        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }

    // ---- Admin-driven refund (NFT + GIFT back to redeemer) ----

    /**
     * @notice Admin-driven refund for a redemption in progress.
     *
     * Scenario:
     *  - NFT has been sent into escrow (inRedemption == true).
     *  - You decide to unwind the redemption and give the user back both NFT and GIFT.
     *
     * Effect:
     *  - NFT is returned to redeemer.
     *  - Locked GIFT is returned to redeemer.
     *  - EscrowRecord is marked as cancelled; giftAmount is zeroed.
     */
    function adminRefundRedemption(address nftContract, uint256 tokenId) external onlyOwner {
        EscrowRecord storage rec = escrows[nftContract][tokenId];
        require(rec.inRedemption, "Escrow: not in redemption");
        require(!rec.redeemed, "Escrow: already redeemed");
        require(!rec.cancelled, "Escrow: already closed");
        require(!rec.confiscated, "Escrow: already confiscated");

        rec.inRedemption = false;
        rec.cancelled = true;

        uint256 amount = rec.giftAmount;
        rec.giftAmount = 0;

        // Return NFT to redeemer
        GIFTBarNFTDeferred(nftContract).safeTransferFrom(address(this), rec.redeemer, tokenId);

        // Return locked GIFT to redeemer
        if (amount > 0) {
            bool ok = gift.transfer(rec.redeemer, amount);
            require(ok, "Escrow: refund transfer failed");
        }

        emit RedemptionCancelledAndRefunded(nftContract, tokenId, rec.redeemer, amount);
    }

    // ---- Admin-driven confiscation (NFT + GIFT to confiscation wallet) ----

    /**
     * @notice Admin-driven confiscation of NFT + locked GIFT for a redemption in progress.
     *
     * Scenario:
     *  - NFT is in escrow for redemption (inRedemption == true).
     *  - You discover user is sanctioned / terrorist / fraud, etc.
     *
     * Effect:
     *  - NFT is sent to `confiscationWallet`.
     *  - Locked GIFT is sent to `confiscationWallet`.
     *  - EscrowRecord is marked as cancelled + confiscated; giftAmount is zeroed.
     */
    function adminConfiscateRedemption(address nftContract, uint256 tokenId) external onlyOwner {
        EscrowRecord storage rec = escrows[nftContract][tokenId];
        require(rec.inRedemption, "Escrow: not in redemption");
        require(!rec.redeemed, "Escrow: already redeemed");
        require(!rec.cancelled, "Escrow: already closed");
        require(!rec.confiscated, "Escrow: already confiscated");

        rec.inRedemption = false;
        rec.cancelled = true;
        rec.confiscated = true;

        uint256 amount = rec.giftAmount;
        rec.giftAmount = 0;

        // Send NFT to confiscation wallet
        GIFTBarNFTDeferred(nftContract).safeTransferFrom(address(this), confiscationWallet, tokenId);

        // Send locked GIFT to confiscation wallet
        if (amount > 0) {
            bool ok = gift.transfer(confiscationWallet, amount);
            require(ok, "Escrow: confiscation transfer failed");
        }

        emit RedemptionConfiscated(nftContract, tokenId, rec.redeemer, amount);
    }

    // ---- Admin: complete redemption (burn tokens + burn NFT) ----

    /**
     * @notice Complete redemption after physical gold is shipped and confirmed.
     *
     * Steps:
     *  1. Ensure this contract holds at least `giftAmount` GIFT for the NFT.
     *  2. Call `minting.burnEscrowBalance(giftAmount)`:
     *      - MintingUpgradeable calls `GIFT.redeemGold(escrow, giftAmount)`
     *      - GIFT burns tokens from this escrow's balance (escrow is `escrow` in MintingUpgradeable).
     *  3. Attempt to burn the NFT via GIFTBarNFTDeferred.burn(tokenId).
     *     If burn fails (e.g. NFT contract not configured correctly), NFT remains locked.
     */
    function completeRedemption(address nftContract, uint256 tokenId) external onlyOwner {
        EscrowRecord storage rec = escrows[nftContract][tokenId];
        require(rec.inRedemption, "Escrow: not in redemption");
        require(!rec.redeemed, "Escrow: already redeemed");
        require(!rec.cancelled, "Escrow: redemption cancelled");

        uint256 amount = rec.giftAmount;
        require(amount > 0, "Escrow: zero amount");

        uint256 balance = gift.balanceOf(address(this));
        require(balance >= amount, "Escrow: insufficient GIFT");

        // Burn from escrow balance via MintingUpgradeable
        minting.burnEscrowBalance(amount);

        rec.redeemed = true;
        rec.inRedemption = false;
        rec.giftAmount = 0;

        // Try to burn NFT; escrow should be NFT owner for this to work.
        try GIFTBarNFTDeferred(nftContract).burn(tokenId) {
            // burned OK
        } catch {
            // If this fails, token remains locked in escrow forever
        }

        emit RedemptionCompleted(nftContract, tokenId, rec.redeemer, amount);
    }

    // ---- Views ----

    function lockedGiftForNFT(address nftContract, uint256 tokenId) external view returns (uint256) {
        return escrows[nftContract][tokenId].giftAmount;
    }

    function totalLockedGift() external view returns (uint256) {
        return gift.balanceOf(address(this));
    }
}
