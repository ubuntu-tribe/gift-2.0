// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract GIFTBatchRegistry is Initializable, OwnableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    struct BatchMeta {
        bytes32 root;
        uint256 cap; // sum of all leaf quantities (token smallest units)
        uint256 minted; // total consumed against this batch
        string datasetURI; // IPFS/HTTPS pointer to dataset & proofs
        bytes32 schemaHash; // keccak256 of column order/types used to build leaves
        bool active;
        bool finalized;
        bool isLegacy;
        uint64 createdAt;
        address createdBy;
    }

    // Matches the leaf schema (all STATIC types)
    struct LeafInput {
        uint256 batchId;
        uint256 reserveId;
        uint256 quantity;
        uint256 fineWeightMg;
        bytes32 serialHash;
        bytes32 mineHash;
        bytes32 barStandardHash;
        bytes32 docHash;
        uint256 mintedAtISO;
        uint256 presenceMask; // bit0: serial, bit1: mine, bit2: barStd, bit3: doc, bit4: mintedAtISO
    }

    mapping(uint256 => BatchMeta) private _batches;
    mapping(uint256 => mapping(bytes32 => uint256)) private _consumed; // batchId => leafHash => consumed
    uint256 public nextBatchId;
    address public minting; // the only contract allowed to consume

    bytes32 public constant LEAF_TYPEHASH =
        keccak256(
            "GiftMintLeafV1(address registry,uint256 batchId,uint256 reserveId,uint256 quantity,uint256 fineWeightMg,bytes32 serialHash,bytes32 mineHash,bytes32 barStandardHash,bytes32 docHash,uint256 mintedAtISO,uint256 presenceMask)"
        );

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    event BatchRegistered(
        uint256 indexed batchId,
        bytes32 root,
        uint256 cap,
        string datasetURI,
        bytes32 schemaHash,
        bool active
    );
    event BatchActivated(uint256 indexed batchId);
    event BatchFinalized(uint256 indexed batchId);
    event MintConsumed(
        uint256 indexed batchId,
        bytes32 indexed leafHash,
        uint256 reserveId,
        address to,
        uint256 amount,
        uint256 leafConsumed,
        uint256 batchMinted
    );
    event LegacySupplyAcknowledged(uint256 indexed batchId, uint256 amount, string reason, bytes32 docHash);

    modifier onlyMinting() {
        require(msg.sender == minting, "Registry: caller not minting");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_) public initializer {
        require(owner_ != address(0), "Registry: owner is zero");

        __Ownable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        // Ownable owner() should be the governance/admin EOA or multisig.
        if (owner_ != msg.sender) {
            transferOwnership(owner_);
        }

        nextBatchId = 1;

        _grantRole(DEFAULT_ADMIN_ROLE, owner());
        _grantRole(ADMIN_ROLE, owner_);
    }

    function setMinting(address m) external onlyOwner {
        require(m != address(0), "Registry: zero address");
        minting = m;
    }

    function registerBatch(
        bytes32 root,
        uint256 cap,
        string calldata datasetURI,
        bytes32 schemaHash,
        bool active
    ) external onlyOwner returns (uint256 batchId) {
        require(root != bytes32(0), "Registry: root=0");
        require(cap > 0, "Registry: cap=0");

        batchId = nextBatchId++;
        _batches[batchId] = BatchMeta({
            root: root,
            cap: cap,
            minted: 0,
            datasetURI: datasetURI,
            schemaHash: schemaHash,
            active: active,
            finalized: false,
            isLegacy: false,
            createdAt: uint64(block.timestamp),
            createdBy: msg.sender
        });

        emit BatchRegistered(batchId, root, cap, datasetURI, schemaHash, active);
        if (active) emit BatchActivated(batchId);
    }

    function finalizeBatch(uint256 batchId) external onlyOwnerOrAdmin {
        BatchMeta storage b = _requireBatch(batchId);
        require(!b.finalized, "Registry: finalized");
        b.active = false;
        b.finalized = true;
        emit BatchFinalized(batchId);
    }

    function acknowledgeLegacySupply(
        uint256 amount,
        string calldata reason,
        string calldata datasetURI,
        bytes32 docHash
    ) external onlyOwnerOrAdmin returns (uint256 batchId) {
        require(amount > 0, "Registry: amount=0");
        batchId = nextBatchId++;

        _batches[batchId] = BatchMeta({
            root: bytes32(0),
            cap: amount,
            minted: amount,
            datasetURI: datasetURI,
            schemaHash: bytes32(0),
            active: false,
            finalized: true,
            isLegacy: true,
            createdAt: uint64(block.timestamp),
            createdBy: msg.sender
        });

        emit LegacySupplyAcknowledged(batchId, amount, reason, docHash);
    }

    function getBatchMeta(uint256 batchId) external view returns (BatchMeta memory) {
        return _requireBatch(batchId);
    }

    function leafConsumed(uint256 batchId, bytes32 leafHash) external view returns (uint256) {
        return _consumed[batchId][leafHash];
    }

    function verifyLeaf(LeafInput calldata d, bytes32[] calldata proof) external view returns (bytes32 leafHash, bool ok) {
        BatchMeta storage b = _requireBatch(d.batchId);
        leafHash = _leafHash(d);
        ok = MerkleProof.verifyCalldata(proof, b.root, leafHash);
    }

    function consume(
        LeafInput calldata d,
        bytes32[] calldata proof,
        uint256 amount,
        address to
    ) external onlyMinting {
        require(amount > 0, "Registry: amount=0");
        BatchMeta storage b = _requireBatch(d.batchId);
        require(b.active && !b.finalized, "Registry: inactive");

        bytes32 leafHash = _leafHash(d);
        require(MerkleProof.verifyCalldata(proof, b.root, leafHash), "Registry: bad proof");

        uint256 used = _consumed[d.batchId][leafHash];
        require(used + amount <= d.quantity, "Registry: leaf cap");
        require(b.minted + amount <= b.cap, "Registry: batch cap");

        _consumed[d.batchId][leafHash] = used + amount;
        b.minted += amount;

        emit MintConsumed(d.batchId, leafHash, d.reserveId, to, amount, used + amount, b.minted);
    }

    function _leafHash(LeafInput calldata d) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    LEAF_TYPEHASH,
                    address(this),
                    d.batchId,
                    d.reserveId,
                    d.quantity,
                    d.fineWeightMg,
                    d.serialHash,
                    d.mineHash,
                    d.barStandardHash,
                    d.docHash,
                    d.mintedAtISO,
                    d.presenceMask
                )
            );
    }

    function grantAdminRole(address account) external onlyOwner {
        _grantRole(ADMIN_ROLE, account);
    }

    function revokeAdminRole(address account) external onlyOwner {
        _revokeRole(ADMIN_ROLE, account);
    }

    modifier onlyOwnerOrAdmin() {
        require(owner() == msg.sender || hasRole(ADMIN_ROLE, msg.sender), "Registry: not owner or admin");
        _;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function _requireBatch(uint256 batchId) internal view returns (BatchMeta storage b) {
        b = _batches[batchId];
        require(b.createdAt != 0, "Registry: unknown batch");
    }
}



