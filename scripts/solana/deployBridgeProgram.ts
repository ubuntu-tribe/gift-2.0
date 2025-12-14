import {
  Connection,
  Keypair,
  PublicKey,
  SystemProgram,
  Transaction,
  TransactionInstruction,
} from "@solana/web3.js";
import * as fs from "fs";
import * as path from "path";
import dotenv from "dotenv";
import crypto from "crypto";

dotenv.config({ path: path.resolve(__dirname, "../../.env") });

const ROOT = path.resolve(__dirname, "../..");
const ADDRESSES_PATH = path.join(ROOT, "addresses", "addresses.mainnet.json");

function loadPayer(): Keypair {
  const raw = process.env.SOLANA_RELAYER_KEYPAIR;
  if (!raw) {
    throw new Error("SOLANA_RELAYER_KEYPAIR env var is required");
  }

  if (raw.includes("/") || raw.endsWith(".json")) {
    const full = path.isAbsolute(raw) ? raw : path.join(ROOT, raw);
    const secret = JSON.parse(fs.readFileSync(full, "utf8"));
    return Keypair.fromSecretKey(Uint8Array.from(secret));
  }

  if (raw.trim().startsWith("[")) {
    const secret = JSON.parse(raw.trim());
    return Keypair.fromSecretKey(Uint8Array.from(secret));
  }

  throw new Error(
    "SOLANA_RELAYER_KEYPAIR must be a path to a JSON keypair file or a JSON array"
  );
}

async function main() {
  const rpcUrl =
    process.env.SOLANA_RPC_URL || "https://api.mainnet-beta.solana.com";
  const connection = new Connection(rpcUrl, "confirmed");
  const payer = loadPayer();

  const walletPubkey = payer.publicKey;
  console.log("Wallet:", walletPubkey.toBase58());

  const raw = fs.readFileSync(ADDRESSES_PATH, "utf8");
  const json = JSON.parse(raw);

  const programIdStr = json.solana?.giftBridgeProgram;
  if (!programIdStr) {
    throw new Error("addresses.solana.giftBridgeProgram is not set");
  }
  const programId = new PublicKey(programIdStr);

  const giftMintStr = json.solana?.giftMint;
  if (!giftMintStr) {
    throw new Error("addresses.solana.giftMint is not set");
  }
  const giftMint = new PublicKey(giftMintStr);

  const polygonBridgeHex = json.polygon?.GiftPolygonBridge?.proxy;
  if (!polygonBridgeHex || !polygonBridgeHex.startsWith("0x")) {
    throw new Error("addresses.polygon.GiftPolygonBridge.proxy is not set");
  }
  const polygonBridgeBytes = Buffer.from(polygonBridgeHex.slice(2), "hex");
  if (polygonBridgeBytes.length !== 20) {
    throw new Error("Polygon bridge address must be 20 bytes");
  }

  const [configPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("config")],
    programId
  );

  console.log("Program ID:", programId.toBase58());
  console.log("Gift mint:", giftMint.toBase58());
  console.log("Polygon bridge (bytes20 hex):", polygonBridgeHex);
  console.log("Config PDA:", configPda.toBase58());

  // Manually encode Anchor instruction:
  // discriminator = first 8 bytes of sha256("global:initialize_config")
  const disc = crypto
    .createHash("sha256")
    .update("global:initialize_config")
    .digest()
    .slice(0, 8);

  const data = Buffer.concat([
    disc,
    giftMint.toBuffer(),          // 32 bytes
    polygonBridgeBytes,           // 20 bytes
  ]);

  const ix = new TransactionInstruction({
    programId,
    keys: [
      { pubkey: configPda, isSigner: false, isWritable: true },
      { pubkey: walletPubkey, isSigner: true, isWritable: true },
      { pubkey: SystemProgram.programId, isSigner: false, isWritable: false },
    ],
    data,
  });

  const tx = new Transaction().add(ix);
  const sig = await connection.sendTransaction(tx, [payer]);

  console.log("initialize_config tx:", sig);

  // Update addresses JSON with config PDA
  json.solana = json.solana || {};
  json.solana.giftBridgeConfig = configPda.toBase58();
  fs.writeFileSync(ADDRESSES_PATH, JSON.stringify(json, null, 2), "utf8");

  console.log(
    `Updated solana.giftBridgeConfig in addresses.mainnet.json to ${configPda.toBase58()}`
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
