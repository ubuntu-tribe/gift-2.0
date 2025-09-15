// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title GIFTBatchRegistry
/// @notice Anchors Merkle roots for mint provenance and enforces per-leaf and per-batch caps.
contract GIFTBatchRegistry is Ownable, ReentrancyGuard {

  
    /// MintLeafV1(
    ///   uint256 chainId,
    ///   address registry,
    ///   uint256 batchId,
    ///   uint256 reserveId,
    ///   uint256 quantity,
    ///   uint256 fineWeightMg,
    ///   uint256 finenessPpm,
    ///   bytes32 serialHash,
    ///   bytes32 mineHash,
    ///   bytes32 refineryHash,
    ///   bytes32 custodianHash,
    ///   bytes32 barStandardHash,
    ///   bytes32 docHash,
    ///   uint256 mintedAtISO,
    ///   uint256 presenceMask
    /// )
    bytes32 public constant LEAF_TYPEHASH = keccak256(
        "MintLeafV1(uint256 chainId,address registry,uint256 batchId,uint256 reserveId,uint256 quantity,uint256 fineWeightMg,uint256 finenessPpm,bytes32 serialHash,bytes32 mineHash,bytes32 refineryHash,bytes32 custodianHash,bytes32 barStandardHash,bytes32 docHash,uint256 mintedAtISO,uint256 presenceMask)"
    );

    /// @dev Sentinel hash for unknown string fields. Use with presenceMask bit = 0.
    bytes32 public constant UNKNOWN = keccak256("UNKNOWN");

    

    struct BatchMeta {
        bytes32 root;
        uint256 cap;          
        uint256 minted;       
        string  datasetURI;   
        bytes32 schemaHash;   
        bool    active;       
        bool    finalized;    
        bool    isLegacy;     
        uint64  createdAt;
        address createdBy;
    }

    struct SupplementalRoot {
        bytes32 root;
        string uri;
        uint64 addedAt;
        address addedBy;
    }

    mapping(uint256 => BatchMeta) public batches;                 
    mapping(uint256 => mapping(bytes32 => uint256)) public consumed; 
    mapping(uint256 => SupplementalRoot[]) private _supplementals;  

    uint256 public nextBatchId = 1;
    address public minting; 

    // ========= Events =========

    event MintingSet(address indexed minting);
    event BatchRegistered(uint256 indexed batchId, bytes32 indexed root, uint256 cap, string datasetURI, bytes32 schemaHash, bool active, bool isLegacy);
    event BatchActivated(uint256 indexed batchId);
    event BatchDeactivated(uint256 indexed batchId);
    event BatchFinalized(uint256 indexed batchId);
    event SupplementalRootAdded(uint256 indexed batchId, bytes32 indexed supplementalRoot, string uri);
    event MintConsumed(
        uint256 indexed batchId,
        bytes32 indexed leafHash,
        uint256 indexed reserveId,
        address to,
        uint256 amount,
        uint256 leafConsumed,
        uint256 batchMinted
    );

  

    modifier onlyMinting() {
        require(msg.sender == minting, "Registry: not minting");
        _;
    }

    

    function setMinting(address minting_) external onlyOwner {
        require(minting_ != address(0), "Registry: zero minting");
        minting = minting_;
        emit MintingSet(minting_);
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
        require(bytes(datasetURI).length != 0, "Registry: empty URI");

        batchId = nextBatchId++;
        batches[batchId] = BatchMeta({
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

        emit BatchRegistered(batchId, root, cap, datasetURI, schemaHash, active, false);
        if (active) emit BatchActivated(batchId);
    }

    function finalizeBatch(uint256 batchId) external onlyOwner {
        BatchMeta storage b = _mustExist(batchId);
        b.active = false;
        b.finalized = true;
        emit BatchFinalized(batchId);
    }

    function setBatchActive(uint256 batchId, bool on) external onlyOwner {
        BatchMeta storage b = _mustExist(batchId);
        require(!b.finalized, "Registry: finalized");
        b.active = on;
        if (on) emit BatchActivated(batchId);
        else emit BatchDeactivated(batchId);
    }

    /// @notice One-time acknowledgment of already-minted legacy supply.
    function acknowledgeLegacySupply(
        uint256 amount,
        string calldata reason,
        string calldata datasetURI,
        bytes32 docHash
    ) external onlyOwner returns (uint256 batchId) {
        require(amount > 0, "Registry: amount=0");
        
        bytes32 legacyRoot = keccak256(abi.encode(reason, docHash, block.chainid, address(this)));
        batchId = nextBatchId++;
        batches[batchId] = BatchMeta({
            root: legacyRoot,
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
        emit BatchRegistered(batchId, legacyRoot, amount, datasetURI, bytes32(0), false, true);
        emit BatchFinalized(batchId);
    }

    function addSupplementalRoot(uint256 batchId, bytes32 supplementalRoot, string calldata uri) external onlyOwner {
        _mustExist(batchId);
        _supplementals[batchId].push(SupplementalRoot({
            root: supplementalRoot,
            uri: uri,
            addedAt: uint64(block.timestamp),
            addedBy: msg.sender
        }));
        emit SupplementalRootAdded(batchId, supplementalRoot, uri);
    }

    function getSupplementals(uint256 batchId) external view returns (SupplementalRoot[] memory) {
        return _supplementals[batchId];
    }


    function verifyLeaf(
        uint256 batchId,
        uint256 reserveId,
        uint256 quantity,
        uint256 fineWeightMg,
        uint256 finenessPpm,
        bytes32 serialHash,
        bytes32 mineHash,
        bytes32 refineryHash,
        bytes32 custodianHash,
        bytes32 barStandardHash,
        bytes32 docHash,
        uint256 mintedAtISO,
        uint256 presenceMask,
        bytes32[] calldata proof
    ) external view returns (bytes32 leafHash, bool ok) {
        BatchMeta storage b = _mustExist(batchId);
        leafHash = _leafHash(
            batchId,
            reserveId,
            quantity,
            fineWeightMg,
            finenessPpm,
            serialHash,
            mineHash,
            refineryHash,
            custodianHash,
            barStandardHash,
            docHash,
            mintedAtISO,
            presenceMask
        );
        ok = MerkleProof.verify(proof, b.root, leafHash);
    }

    /// callable only by the Minting contract.
    function consume(
        uint256 batchId,
        address to,
        uint256 amount,
        uint256 reserveId,
        uint256 quantity,
        uint256 fineWeightMg,
        uint256 finenessPpm,
        bytes32 serialHash,
        bytes32 mineHash,
        bytes32 refineryHash,
        bytes32 custodianHash,
        bytes32 barStandardHash,
        bytes32 docHash,
        uint256 mintedAtISO,
        uint256 presenceMask,
        bytes32[] calldata proof
    ) external onlyMinting nonReentrant returns (bytes32 leafHash) {
        BatchMeta storage b = _mustExist(batchId);
        require(b.active && !b.finalized, "Registry: inactive or finalized");
        require(amount > 0, "Registry: amount=0");

        leafHash = _leafHash(
            batchId,
            reserveId,
            quantity,
            fineWeightMg,
            finenessPpm,
            serialHash,
            mineHash,
            refineryHash,
            custodianHash,
            barStandardHash,
            docHash,
            mintedAtISO,
            presenceMask
        );

        // Verify proof
        require(MerkleProof.verify(proof, b.root, leafHash), "Registry: bad proof");

        // Enforce per-leaf and per-batch caps
        uint256 newLeafConsumed = consumed[batchId][leafHash] + amount;
        require(newLeafConsumed <= quantity, "Registry: leaf cap exceeded");

        uint256 newBatchMinted = b.minted + amount;
        require(newBatchMinted <= b.cap, "Registry: batch cap exceeded");

        // Effects
        consumed[batchId][leafHash] = newLeafConsumed;
        b.minted = newBatchMinted;

        emit MintConsumed(batchId, leafHash, reserveId, to, amount, newLeafConsumed, newBatchMinted);
    }

    

    function leafTypehash() external pure returns (bytes32) {
        return LEAF_TYPEHASH;
    }

    function unknownSentinel() external pure returns (bytes32) {
        return UNKNOWN;
    }

    function computeLeafHash(
        uint256 batchId,
        uint256 reserveId,
        uint256 quantity,
        uint256 fineWeightMg,
        uint256 finenessPpm,
        bytes32 serialHash,
        bytes32 mineHash,
        bytes32 refineryHash,
        bytes32 custodianHash,
        bytes32 barStandardHash,
        bytes32 docHash,
        uint256 mintedAtISO,
        uint256 presenceMask
    ) external view returns (bytes32) {
        return _leafHash(
            batchId,
            reserveId,
            quantity,
            fineWeightMg,
            finenessPpm,
            serialHash,
            mineHash,
            refineryHash,
            custodianHash,
            barStandardHash,
            docHash,
            mintedAtISO,
            presenceMask
        );
    }

  

    function _mustExist(uint256 batchId) internal view returns (BatchMeta storage b) {
        b = batches[batchId];
        require(b.createdAt != 0, "Registry: batch !exist");
    }

    function _leafHash(
        uint256 batchId,
        uint256 reserveId,
        uint256 quantity,
        uint256 fineWeightMg,
        uint256 finenessPpm,
        bytes32 serialHash,
        bytes32 mineHash,
        bytes32 refineryHash,
        bytes32 custodianHash,
        bytes32 barStandardHash,
        bytes32 docHash,
        uint256 mintedAtISO,
        uint256 presenceMask
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                LEAF_TYPEHASH,
                block.chainid,
                address(this),
                batchId,
                reserveId,
                quantity,
                fineWeightMg,
                finenessPpm,
                serialHash,
                mineHash,
                refineryHash,
                custodianHash,
                barStandardHash,
                docHash,
                mintedAtISO,
                presenceMask
            )
        );
    }
}
