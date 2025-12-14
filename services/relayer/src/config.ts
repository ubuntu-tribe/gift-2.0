import fs from "fs";
import path from "path";
import dotenv from "dotenv";

dotenv.config({ path: path.resolve(__dirname, "../../.env") });

export interface AddressesJson {
  polygon: {
    GIFT: string;
    GIFTPoR: string;
    GIFTTaxManager: string;
    GIFTBatchRegistry: string;
    MintingUpgradeable: {
      proxy: string;
      implementation: string;
    };
    GiftRedemptionEscrowUpgradeable: {
      proxy: string;
      implementation: string;
    };
    GIFTBarNFTDeferred: string;
    GiftPolygonBridge: {
      proxy: string;
      implementation: string;
    };
  };
  solana: {
    giftBridgeProgram: string;
    giftMint: string;
    giftBridgeConfig: string;
  };
}

function loadAddresses(): AddressesJson {
  const filePath = path.resolve(
    __dirname,
    "../../addresses/addresses.mainnet.json"
  );
  const raw = fs.readFileSync(filePath, "utf8");
  const parsed = JSON.parse(raw);
  return parsed as AddressesJson;
}

export const addresses = loadAddresses();

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value || value.trim() === "") {
    throw new Error(`Missing required env var ${name}`);
  }
  return value.trim();
}

export const config = {
  polygonRpcUrl: requireEnv("POLYGON_RPC_URL"),
  polygonRelayerPrivateKey: requireEnv("POLYGON_RELAYER_PRIVATE_KEY"),
  solanaRpcUrl: requireEnv("SOLANA_RPC_URL"),
  solanaRelayerKeypair: requireEnv("SOLANA_RELAYER_KEYPAIR"),
};


