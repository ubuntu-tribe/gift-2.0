// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../GIFT.sol";
import "../../GIFTPoR.sol";
import "../../src/GIFTBatchRegistry.sol";
import "../../GIFTTaxManager.sol";
import "../../MintingUpgradeable.sol";
import "../../GIFTBarNFTDeferred.sol";
import "../../GiftRedemptionEscrowUpgradeable.sol";
import "../../GiftPolygonBridge.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @dev Simple mock for the Chainlink AggregatorV3Interface used by GIFT.
contract MockAggregator is AggregatorV3Interface {
    function decimals() external pure override returns (uint8) {
        return 8;
    }

    function description() external pure override returns (string memory) {
        return "MOCK";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(
        uint80 _roundId
    )
        external
        pure
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, 0, 0, 0, _roundId);
    }

    function latestRoundData()
        external
        pure
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, 0, 0, 0, 0);
    }
}

/// @notice Shared Polygon-side test harness that wires contracts according to the architecture doc.
contract TestHelpers is Test {
    // ---- Addresses ----

    address internal owner;
    address internal admin;
    address internal auditor;
    address internal minter;
    address internal user1;
    address internal user2;
    address internal user3;
    address internal beneficiary;
    address internal marketplace;
    address internal relayer;

    // ---- Core contracts ----

    GIFT internal gift;
    GIFTPoR internal por;
    GIFTBatchRegistry internal registry;
    GIFTTaxManager internal taxManager;
    MintingUpgradeable internal minting;
    GIFTBarNFTDeferred internal nft;
    GiftRedemptionEscrowUpgradeable internal escrow;
    GiftPolygonBridge internal bridge;
    AggregatorV3Interface internal mockAggregator;

    // ---- PoR / vault config ----

    uint256 internal vault1;
    uint256 internal vault2;

    uint256 internal constant INITIAL_RESERVE = 100_000 * 10 ** 18;
    uint256 internal constant DEFAULT_ALLOWANCE = 50_000 * 10 ** 18;

    // ---- Top-level wiring ----

    /// @dev Deploy and wire all Polygon-side contracts for a clean test environment.
    function deployAll() internal {
        // Named actors
        owner = address(this);
        admin = makeAddr("admin");
        auditor = makeAddr("auditor");
        minter = makeAddr("minter");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        beneficiary = makeAddr("beneficiary");
        marketplace = makeAddr("marketplace");
        relayer = makeAddr("relayer");

        // ---- PoR (UUPS behind ERC1967 proxy) ----
        GIFTPoR porImpl = new GIFTPoR();
        ERC1967Proxy porProxy = new ERC1967Proxy(
            address(porImpl),
            abi.encodeCall(GIFTPoR.initialize, ())
        );
        por = GIFTPoR(address(porProxy));

        // roles
        por.addAdmin(admin);
        // allow the canonical `minter` EOA and the Minting contract itself to act as admins/minters
        por.addAdmin(minter);
        por.addAuditor(auditor);
        por.addMinter(minter);

        // create two vaults via admin to match tests (vault1=1, vault2=2, nextVaultId=3)
        vm.startPrank(admin);
        por.addVault("Vault 1");
        por.addVault("Vault 2");
        vm.stopPrank();

        vault1 = 1;
        vault2 = 2;

        // initialize digital + physical reserve on vault1 via auditor
        vm.prank(auditor);
        por.updateVault(vault1, INITIAL_RESERVE, "Initial reserve");

        // ---- Tax manager (UUPS behind ERC1967 proxy) ----
        GIFTTaxManager taxImpl = new GIFTTaxManager();
        ERC1967Proxy taxProxy = new ERC1967Proxy(
            address(taxImpl),
            abi.encodeCall(GIFTTaxManager.initialize, ())
        );
        taxManager = GIFTTaxManager(address(taxProxy));
        taxManager.setBeneficiary(beneficiary);

        // ---- GIFT token + price feed (UUPS behind ERC1967 proxy) ----
        MockAggregator agg = new MockAggregator();
        mockAggregator = AggregatorV3Interface(address(agg));

        GIFT giftImpl = new GIFT();
        ERC1967Proxy giftProxy = new ERC1967Proxy(
            address(giftImpl),
            abi.encodeCall(
                GIFT.initialize,
                (address(mockAggregator), address(0), address(taxManager))
            )
        );
        gift = GIFT(address(giftProxy));

        // ---- Registry ----
        // Registry (UUPS implementation deployed behind an ERC1967 proxy)
        GIFTBatchRegistry registryImpl = new GIFTBatchRegistry();
        ERC1967Proxy registryProxy = new ERC1967Proxy(
            address(registryImpl),
            abi.encodeCall(GIFTBatchRegistry.initialize, (owner))
        );
        registry = GIFTBatchRegistry(address(registryProxy));

        // ---- Minting engine (UUPS behind ERC1967 proxy) ----
        MintingUpgradeable mintImpl = new MintingUpgradeable();
        ERC1967Proxy mintProxy = new ERC1967Proxy(
            address(mintImpl),
            abi.encodeCall(
                MintingUpgradeable.initialize,
                (address(por), address(gift), address(registry))
            )
        );
        minting = MintingUpgradeable(address(mintProxy));

        // Allow the Minting contract itself to adjust allowances & reserves in PoR.
        por.addAdmin(address(minting));
        por.addMinter(address(minting));

        // allow minting to consume batches
        registry.setMinting(address(minting));

        // ---- Escrow (UUPS behind ERC1967 proxy) ----
        GiftRedemptionEscrowUpgradeable escrowImpl = new GiftRedemptionEscrowUpgradeable();
        ERC1967Proxy escrowProxy = new ERC1967Proxy(
            address(escrowImpl),
            abi.encodeCall(
                GiftRedemptionEscrowUpgradeable.initialize,
                (address(gift), address(minting))
            )
        );
        escrow = GiftRedemptionEscrowUpgradeable(address(escrowProxy));

        // PoR owner wires escrow into minting
        minting.setEscrow(address(escrow));

        // ---- NFT representing physical bars ----
        nft = new GIFTBarNFTDeferred(address(registry));
        // After deployment, ownership is transferred to escrow as per architecture
        nft.transferOwnership(address(escrow));

        // ---- Polygon bridge (UUPS behind ERC1967 proxy) ----
        GiftPolygonBridge bridgeImpl = new GiftPolygonBridge();
        ERC1967Proxy bridgeProxy = new ERC1967Proxy(
            address(bridgeImpl),
            abi.encodeCall(
                GiftPolygonBridge.initialize,
                (address(gift), address(taxManager), relayer, owner)
            )
        );
        bridge = GiftPolygonBridge(address(bridgeProxy));

        // ---- GIFT roles / tax exemptions ----

        // Minting contract is the only supply controller (canonical issuance + burns)
        gift.setSupplyController(address(minting));

        // Bridge & escrow are tax-exempt for outbound flows (no fees when they send)
        taxManager.setFeeExclusion(address(bridge), true, true);
        taxManager.setFeeExclusion(address(escrow), true, true);
    }

    // ---- Helper factories ----

    /// @dev Deploy a fresh PoR instance behind a proxy (used in some upgrade tests).
    function deployPoR() internal returns (GIFTPoR) {
        GIFTPoR impl = new GIFTPoR();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(GIFTPoR.initialize, ())
        );
        return GIFTPoR(address(proxy));
    }

    /// @dev Deploy a fresh registry instance via proxy (used in some upgrade tests).
    function deployRegistry() internal returns (GIFTBatchRegistry) {
        GIFTBatchRegistry impl = new GIFTBatchRegistry();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(GIFTBatchRegistry.initialize, (owner))
        );
        return GIFTBatchRegistry(address(proxy));
    }

    /// @dev Deploy a fresh tax manager instance behind a proxy (used in some upgrade tests).
    function deployTaxManager() internal returns (GIFTTaxManager) {
        GIFTTaxManager impl = new GIFTTaxManager();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(GIFTTaxManager.initialize, ())
        );
        return GIFTTaxManager(address(proxy));
    }

    /// @dev Configure a PoR minter with allowance on a given reserve.
    function setupMinter(
        address minter_,
        uint256 reserveId,
        uint256 allowance
    ) internal {
        vm.startPrank(admin);
        por.addMinter(minter_);
        por.setMintingAllowance(minter_, reserveId, allowance);
        vm.stopPrank();
    }

    // ---- Merkle helpers ----

    /// @dev Build a single-leaf Merkle tree for `leaf` matching the on-chain LEAF_TYPEHASH.
    /// Root is simply the leaf hash and proof is empty, which is valid for a 1-leaf tree.
    function generateMerkleTree(
        GIFTBatchRegistry.LeafInput memory leaf
    ) internal view returns (bytes32 root, bytes32[] memory proof) {
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

        root = leafHash;
        proof = new bytes32[](0);
    }
}


