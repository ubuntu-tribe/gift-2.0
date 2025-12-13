// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./GIFT.sol";
import "./GIFTTaxManager.sol";

/**
 * @title GiftPolygonBridge
 * @notice Pooled bridge contract that:
 *  - Locks GIFT tokens on Polygon
 *  - Emits events for off-chain relayer / cross-chain protocol
 *  - Releases GIFT to users when Solana burns are proven
 *
 *  Pattern 1: PoR stays on Polygon, this contract just moves GIFT between
 *  Polygon users and a shared bridge pool.
 */
contract GiftPolygonBridge is Initializable, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    GIFT public gift;
    GIFTTaxManager public taxManager;

    // Address (off-chain or multi-sig) authorised to confirm Solana burns
    address public relayer;

    // Simple incremental nonce for uniqueness of deposits
    uint256 public depositNonce;

    // Track processed Solana burn references to avoid replays
    mapping(bytes32 => bool) public processedBurns;

    event RelayerUpdated(address indexed newRelayer);

    /// @dev Emitted when someone deposits GIFT on Polygon to be minted on Solana
    event DepositedToSolana(
        address indexed polygonSender,
        bytes32 indexed solanaRecipient,
        uint256 amount,
        uint256 nonce
    );

    /// @dev Emitted when GIFT is released from the bridge pool back to Polygon user
    ///      based on a verified burn on Solana
    event WithdrawalToPolygonCompleted(
        address indexed polygonRecipient,
        uint256 amount,
        bytes32 indexed solanaBurnTx
    );

    modifier onlyRelayer() {
        require(msg.sender == relayer, "Bridge: caller is not relayer");
        _;
    }

    function initialize(
        address _gift,
        address _taxManager,
        address _initialRelayer,
        address _owner
    ) external initializer {
        require(_gift != address(0), "Bridge: GIFT is zero");
        require(_owner != address(0), "Bridge: owner is zero");

        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __Pausable_init();

        gift = GIFT(_gift);
        taxManager = GIFTTaxManager(_taxManager);
        relayer = _initialRelayer;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setRelayer(address _relayer) external onlyOwner {
        require(_relayer != address(0), "Bridge: relayer is zero");
        relayer = _relayer;
        emit RelayerUpdated(_relayer);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice User (or admin) deposits GIFT on Polygon to “move” it to Solana.
     * @param amount Amount of GIFT to lock.
     * @param solanaRecipient 32-byte Solana public key of the recipient.
     *
     * Requirements:
     *  - Caller must have approved this contract for `amount` beforehand.
     */
    function depositToSolana(uint256 amount, bytes32 solanaRecipient) external whenNotPaused {
        require(amount > 0, "Bridge: amount is zero");
        require(solanaRecipient != bytes32(0), "Bridge: invalid Solana recipient");

        // Pull GIFT from sender to bridge (this is where tax exemption matters)
        bool ok = gift.transferFrom(msg.sender, address(this), amount);
        require(ok, "Bridge: transferFrom failed");

        uint256 currentNonce = ++depositNonce;

        emit DepositedToSolana(
            msg.sender,
            solanaRecipient,
            amount,
            currentNonce
        );
        // Off-chain relayer watches this event, mints on Solana side accordingly
    }

    /**
     * @notice Release locked GIFT from the bridge pool back to a Polygon user,
     *         based on a verified burn of GIFT on Solana.
     *
     * @param polygonRecipient Recipient on Polygon.
     * @param amount Amount to transfer.
     * @param solanaBurnTx Unique identifier of the burn transaction on Solana
     *                     (e.g. hash or VAA hash).
     *
     * Requirements:
     *  - Caller must be the authorised relayer.
     *  - `solanaBurnTx` must not have been processed before.
     */
    function completeWithdrawalFromSolana(
        address polygonRecipient,
        uint256 amount,
        bytes32 solanaBurnTx
    ) external whenNotPaused onlyRelayer {
        require(polygonRecipient != address(0), "Bridge: recipient is zero");
        require(amount > 0, "Bridge: amount is zero");
        require(!processedBurns[solanaBurnTx], "Bridge: burn already processed");

        processedBurns[solanaBurnTx] = true;

        bool ok = gift.transfer(polygonRecipient, amount);
        require(ok, "Bridge: transfer failed");

        emit WithdrawalToPolygonCompleted(polygonRecipient, amount, solanaBurnTx);
    }

    /**
     * @notice View helper: how many GIFT tokens are locked in the bridge pool.
     */
    function lockedBalance() external view returns (uint256) {
        return gift.balanceOf(address(this));
    }
}
