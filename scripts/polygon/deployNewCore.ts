import fs from "fs";
import path from "path";
import { ethers, upgrades } from "hardhat";

type AddressMap = {
  polygon?: {
    GIFT?: string;
    GIFTPoR?: string;
    GIFTTaxManager?: string;
    GIFTBatchRegistry?: string;
    MintingUpgradeable?: {
      proxy?: string;
      implementation?: string;
    };
    GiftRedemptionEscrowUpgradeable?: {
      proxy?: string;
      implementation?: string;
    };
    GIFTBarNFTDeferred?: string;
    GiftPolygonBridge?: {
      proxy?: string;
      implementation?: string;
    };
    // allow extra keys without typing them
    [key: string]: any;
  };
  solana?: {
    [key: string]: any;
  };
  [key: string]: any;
};

const ADDRESSES_PATH = path.join(__dirname, "..", "..", "addresses", "addresses.mainnet.json");

function loadAddresses(): AddressMap {
  if (!fs.existsSync(ADDRESSES_PATH)) {
    throw new Error(
      `addresses.mainnet.json not found at ${ADDRESSES_PATH}. Please ensure the file exists and contains polygon.GIFT, polygon.GIFTPoR, polygon.GIFTTaxManager, and polygon.GIFTBatchRegistry.`
    );
  }

  const raw = fs.readFileSync(ADDRESSES_PATH, "utf8");
  const parsed = JSON.parse(raw) as AddressMap;

  parsed.polygon = parsed.polygon || {};
  parsed.solana = parsed.solana || {};

  // Ensure nested objects exist so we can assign into them safely
  parsed.polygon.MintingUpgradeable = parsed.polygon.MintingUpgradeable || {};
  parsed.polygon.GiftRedemptionEscrowUpgradeable =
    parsed.polygon.GiftRedemptionEscrowUpgradeable || {};
  parsed.polygon.GiftPolygonBridge = parsed.polygon.GiftPolygonBridge || {};

  return parsed;
}

function saveAddresses(addresses: AddressMap) {
  const out = JSON.stringify(addresses, null, 2);
  fs.writeFileSync(ADDRESSES_PATH, out, { encoding: "utf8" });
}

function requirePolygonAddress(addresses: AddressMap, key: keyof NonNullable<AddressMap["polygon"]>): string {
  const value = addresses.polygon?.[key] as string | undefined;
  if (!value || value.trim() === "") {
    throw new Error(
      `Missing required polygon address for "${String(
        key
      )}" in addresses.mainnet.json. Please fill it in before running this script.`
    );
  }
  return value;
}

async function main() {
  const addresses = loadAddresses();

  const giftAddress = requirePolygonAddress(addresses, "GIFT");
  const giftPorAddress = requirePolygonAddress(addresses, "GIFTPoR");
  const taxManagerAddress = requirePolygonAddress(addresses, "GIFTTaxManager");
  const registryAddress = requirePolygonAddress(addresses, "GIFTBatchRegistry");

  console.log("Using existing Polygon core addresses:");
  console.log("  GIFT:", giftAddress);
  console.log("  GIFTPoR:", giftPorAddress);
  console.log("  GIFTTaxManager:", taxManagerAddress);
  console.log("  GIFTBatchRegistry:", registryAddress);

  // --- Deploy MintingUpgradeable (UUPS proxy) ---
  console.log("\nDeploying MintingUpgradeable (UUPS)...");
  const MintingFactory = await ethers.getContractFactory("MintingUpgradeable");
  const mintingProxy = await upgrades.deployProxy(
    MintingFactory,
    [giftPorAddress, giftAddress, registryAddress],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );
  await mintingProxy.waitForDeployment();
  const mintingProxyAddress = await mintingProxy.getAddress();
  const mintingImplAddress = await upgrades.erc1967.getImplementationAddress(mintingProxyAddress);

  console.log("  MintingUpgradeable proxy:", mintingProxyAddress);
  console.log("  MintingUpgradeable implementation:", mintingImplAddress);

  addresses.polygon!.MintingUpgradeable = {
    proxy: mintingProxyAddress,
    implementation: mintingImplAddress,
  };

  // --- Deploy GiftRedemptionEscrowUpgradeable (UUPS proxy) ---
  console.log("\nDeploying GiftRedemptionEscrowUpgradeable (UUPS)...");
  const EscrowFactory = await ethers.getContractFactory("GiftRedemptionEscrowUpgradeable");
  const escrowProxy = await upgrades.deployProxy(
    EscrowFactory,
    [giftAddress, mintingProxyAddress],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );
  await escrowProxy.waitForDeployment();
  const escrowProxyAddress = await escrowProxy.getAddress();
  const escrowImplAddress = await upgrades.erc1967.getImplementationAddress(escrowProxyAddress);

  console.log("  GiftRedemptionEscrowUpgradeable proxy:", escrowProxyAddress);
  console.log("  GiftRedemptionEscrowUpgradeable implementation:", escrowImplAddress);

  addresses.polygon!.GiftRedemptionEscrowUpgradeable = {
    proxy: escrowProxyAddress,
    implementation: escrowImplAddress,
  };

  // --- Deploy GIFTBarNFTDeferred (plain ERC721) ---
  console.log("\nDeploying GIFTBarNFTDeferred (ERC721)...");
  const NftFactory = await ethers.getContractFactory("GIFTBarNFTDeferred");
  const nft = await NftFactory.deploy(registryAddress);
  await nft.waitForDeployment();
  const nftAddress = await nft.getAddress();

  console.log("  GIFTBarNFTDeferred:", nftAddress);

  addresses.polygon!.GIFTBarNFTDeferred = nftAddress;

  // --- Deploy GiftPolygonBridge (UUPS proxy) ---
  console.log("\nDeploying GiftPolygonBridge (UUPS)...");

  const relayer = process.env.POLYGON_BRIDGE_RELAYER;
  const owner = process.env.POLYGON_BRIDGE_OWNER;

  if (!relayer || !owner) {
    throw new Error(
      "POLYGON_BRIDGE_RELAYER and POLYGON_BRIDGE_OWNER must be set in your environment before running this script."
    );
  }

  const BridgeFactory = await ethers.getContractFactory("GiftPolygonBridge");
  const bridgeProxy = await upgrades.deployProxy(
    BridgeFactory,
    [giftAddress, taxManagerAddress, relayer, owner],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );
  await bridgeProxy.waitForDeployment();
  const bridgeProxyAddress = await bridgeProxy.getAddress();
  const bridgeImplAddress = await upgrades.erc1967.getImplementationAddress(bridgeProxyAddress);

  console.log("  GiftPolygonBridge proxy:", bridgeProxyAddress);
  console.log("  GiftPolygonBridge implementation:", bridgeImplAddress);

  addresses.polygon!.GiftPolygonBridge = {
    proxy: bridgeProxyAddress,
    implementation: bridgeImplAddress,
  };

  // --- Persist updated addresses ---
  saveAddresses(addresses);
  console.log("\nUpdated addresses written to:", ADDRESSES_PATH);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


