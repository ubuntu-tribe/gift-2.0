// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./src/GIFTBatchRegistry.sol";

contract GIFTBarNFTDeferred is ERC721, Ownable, ReentrancyGuard {
    enum CapacityMode { LEAF_MAX, STRICT_CONSUMED }

    GIFTBatchRegistry public immutable registry;

    uint256 public unitMg = 1_000_000; // default 1 kg (1,000,000 mg)
    CapacityMode public capacityMode = CapacityMode.LEAF_MAX;

    // (batchId, leafHash) => minted units count
    mapping(bytes32 => uint256) public unitsMinted;
    uint256 public nextId = 1;
    string public baseURI;

    struct BarInfo {
        uint256 batchId;
        bytes32 leafHash;
        uint256 reserveId;
        uint256 unitMg;
        bytes32 serialHash;
        bytes32 mineHash;
        bytes32 barStandardHash;
        bytes32 docHash;
    }
    mapping(uint256 => BarInfo) public barInfo;

    event BarsMinted(
        uint256 indexed batchId,
        bytes32 indexed leafHash,
        uint256 reserveId,
        uint256 units,
        address to,
        uint256 fromTokenId,
        uint256 toTokenId
    );
    event UnitMgSet(uint256 mg);
    event BaseURISet(string uri);
    event CapacityModeSet(CapacityMode mode);

    constructor(address registry_) ERC721("GIFT Gold Bar", "GIFTBAR") Ownable() {
        registry = GIFTBatchRegistry(registry_);
    }

    // ---- Admin ----

    function setUnitMg(uint256 mg) external onlyOwner {
        require(mg > 0, "unitMg=0");
        unitMg = mg;
        emit UnitMgSet(mg);
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        baseURI = uri;
        emit BaseURISet(uri);
    }

    function setCapacityMode(CapacityMode mode) external onlyOwner {
        capacityMode = mode;
        emit CapacityModeSet(mode);
    }

    /**
     * @notice Burn a bar NFT permanently.
     * Intended to be called by the escrow contract once it becomes owner().
     */
    function burn(uint256 tokenId) external onlyOwner {
        _burn(tokenId);
        delete barInfo[tokenId];
    }

    // ---- Views ----

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        string memory b = baseURI;
        if (bytes(b).length == 0) return "";
        BarInfo memory info = barInfo[tokenId];
        return string(
            abi.encodePacked(
                b,
                "/",
                _u(info.batchId),
                "/",
                _hex(info.leafHash),
                "/",
                _u(tokenId),
                ".json"
            )
        );
    }

    function remainingUnits(GIFTBatchRegistry.LeafInput calldata leaf, bytes32[] calldata proof)
        external
        view
        returns (bytes32 leafHash, uint256 unitsLeft)
    {
        (leafHash, ) = registry.verifyLeaf(leaf, proof);
        uint256 cap = _capacityUnits(leaf.batchId, leafHash, leaf.quantity, leaf.fineWeightMg);
        uint256 minted = unitsMinted[_key(leaf.batchId, leafHash)];
        unitsLeft = cap > minted ? cap - minted : 0;
    }

    // ---- Core ----

    /// Mint `units` NFTs (each represents `unitMg` fine mg) from a verified leaf, anytime later.
    function mintBarsFromLeaf(
        address to,
        uint256 units,
        GIFTBatchRegistry.LeafInput calldata leaf,
        bytes32[] calldata proof
    ) external nonReentrant onlyOwner {
        require(units > 0, "units=0");
        (bytes32 leafHash, bool ok) = registry.verifyLeaf(leaf, proof);
        require(ok, "bad merkle proof");

        uint256 cap = _capacityUnits(leaf.batchId, leafHash, leaf.quantity, leaf.fineWeightMg);
        bytes32 key = _key(leaf.batchId, leafHash);
        uint256 minted = unitsMinted[key];
        require(minted + units <= cap, "exceeds capacity");

        uint256 fromId = nextId;
        for (uint256 i = 0; i < units; i++) {
            uint256 tokenId = nextId++;
            _safeMint(to, tokenId);
            barInfo[tokenId] = BarInfo({
                batchId: leaf.batchId,
                leafHash: leafHash,
                reserveId: leaf.reserveId,
                unitMg: unitMg,
                serialHash: leaf.serialHash,
                mineHash: leaf.mineHash,
                barStandardHash: leaf.barStandardHash,
                docHash: leaf.docHash
            });
        }
        unitsMinted[key] = minted + units;
        emit BarsMinted(leaf.batchId, leafHash, leaf.reserveId, units, to, fromId, nextId - 1);
    }

    // ---- Internals ----

    function _capacityUnits(
        uint256 batchId,
        bytes32 leafHash,
        uint256 quantitySmallest,
        uint256 fineWeightMg
    ) internal view returns (uint256) {
        if (capacityMode == CapacityMode.LEAF_MAX) {
            return fineWeightMg / unitMg;
        } else {
            // STRICT: cap by ERC20 minted from this leaf
            uint256 consumedSmall = registry.leafConsumed(batchId, leafHash);
            if (quantitySmallest == 0) return 0;
            uint256 mgBacked = (consumedSmall * fineWeightMg) / quantitySmallest;
            return mgBacked / unitMg;
        }
    }

    function _key(uint256 batchId, bytes32 leafHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(batchId, leafHash));
    }

    function _hex(bytes32 b32) internal pure returns (string memory) {
        bytes16 HEX = 0x30313233343536373839616263646566;
        bytes memory s = new bytes(66);
        s[0] = "0"; s[1] = "x";
        for (uint i = 0; i < 32; i++) {
            uint8 b = uint8(b32[i]);
            s[2 + i*2] = bytes1(HEX[b >> 4]);
            s[3 + i*2] = bytes1(HEX[b & 0x0f]);
        }
        return string(s);
    }

    function _u(uint256 v) internal pure returns (string memory) {
        if (v == 0) return "0";
        uint256 j = v;
        uint256 l;
        while (j != 0) { l++; j /= 10; }
        bytes memory b = new bytes(l);
        while (v != 0) {
            b[--l] = bytes1(uint8(48 + (v % 10)));
            v /= 10;
        }
        return string(b);
    }
}
