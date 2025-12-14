// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import "../GIFT.sol";
import "../GIFTPoR.sol";
import "../src/GIFTBatchRegistry.sol";
import "../MintingUpgradeable.sol";
import "../GIFTBarNFTDeferred.sol";
import "../GiftRedemptionEscrowUpgradeable.sol";
import "../GiftPolygonBridge.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @notice Conceptual deployment script for the new Polygon core contracts.
/// @dev This is intended for future environments (testnets, staging, etc.).
///      Mainnet addresses are already deployed and tracked in addresses/addresses.mainnet.json.
contract DeployNewCore is Script {
    function run() external {
        // Core addresses are provided via environment variables.
        // These should typically come from addresses/addresses.mainnet.json or similar tooling.
        address gift             = vm.envAddress("GIFT_ADDRESS");
        address giftPoR          = vm.envAddress("GIFT_POR_ADDRESS");
        address giftTaxManager   = vm.envAddress("GIFT_TAX_MANAGER_ADDRESS");
        address giftBatchRegistry= vm.envAddress("GIFT_BATCH_REGISTRY_ADDRESS");
        address bridgeRelayer    = vm.envAddress("POLYGON_BRIDGE_RELAYER_ADDRESS");
        address bridgeOwner      = vm.envAddress("POLYGON_BRIDGE_OWNER_ADDRESS");

        vm.startBroadcast();

        // --- Minting implementation + proxy (UUPS behind ERC1967 proxy) ---
        MintingUpgradeable mintImpl = new MintingUpgradeable();
        ERC1967Proxy mintProxy = new ERC1967Proxy(
            address(mintImpl),
            abi.encodeCall(
                MintingUpgradeable.initialize,
                (giftPoR, gift, giftBatchRegistry)
            )
        );
        // MintingUpgradeable minting = MintingUpgradeable(address(mintProxy));

        // --- Escrow implementation + proxy (UUPS behind ERC1967 proxy) ---
        GiftRedemptionEscrowUpgradeable escrowImpl = new GiftRedemptionEscrowUpgradeable();
        ERC1967Proxy escrowProxy = new ERC1967Proxy(
            address(escrowImpl),
            abi.encodeCall(
                GiftRedemptionEscrowUpgradeable.initialize,
                (gift, address(mintProxy))
            )
        );
        // GiftRedemptionEscrowUpgradeable escrow = GiftRedemptionEscrowUpgradeable(address(escrowProxy));

        // --- NFT representing physical bars (non-upgradeable ERC721) ---
        GIFTBarNFTDeferred nft = new GIFTBarNFTDeferred(giftBatchRegistry);
        // Ownership transfer to the escrow (and other role wiring) is handled off-script by governance.
        nft; // silence unused variable warning

        // --- Polygon bridge implementation + proxy (UUPS behind ERC1967 proxy) ---
        GiftPolygonBridge bridgeImpl = new GiftPolygonBridge();
        ERC1967Proxy bridgeProxy = new ERC1967Proxy(
            address(bridgeImpl),
            abi.encodeCall(
                GiftPolygonBridge.initialize,
                (gift, giftTaxManager, bridgeRelayer, bridgeOwner)
            )
        );
        bridgeProxy; // silence unused variable warning

        vm.stopBroadcast();
    }
}


