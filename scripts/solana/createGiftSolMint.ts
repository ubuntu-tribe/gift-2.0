import { Connection, Keypair } from "@solana/web3.js";
import {
  createMint,
  getOrCreateAssociatedTokenAccount,
  mintTo,
} from "@solana/spl-token";
import * as fs from "fs";
import * as path from "path";
import dotenv from "dotenv";

dotenv.config({ path: path.resolve(__dirname, "../../.env") });

const ROOT = path.resolve(__dirname, "../..");
const ADDRESSES_PATH = path.join(ROOT, "addresses", "addresses.mainnet.json");

function loadPayer(): Keypair {
  const raw = process.env.SOLANA_RELAYER_KEYPAIR;
  if (!raw) {
    throw new Error("SOLANA_RELAYER_KEYPAIR env var is required");
  }

  // path to keypair json
  if (raw.includes("/") || raw.endsWith(".json")) {
    const full = path.isAbsolute(raw) ? raw : path.join(ROOT, raw);
    const secret = JSON.parse(fs.readFileSync(full, "utf8"));
    return Keypair.fromSecretKey(Uint8Array.from(secret));
  }

  // json array
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
  console.log("Payer:", payer.publicKey.toBase58());

  const decimals = 18;
  const mint = await createMint(
    connection,
    payer,
    payer.publicKey, // temporary mint authority (we'll later move to PDA)
    payer.publicKey, // freeze authority
    decimals
  );

  console.log("GIFT_SOL mint address:", mint.toBase58());

  // Mint 1 GIFT_SOL to the payer for testing
  const ata = await getOrCreateAssociatedTokenAccount(
    connection,
    payer,
    mint,
    payer.publicKey
  );

  await mintTo(
    connection,
    payer,
    mint,
    ata.address,
    payer.publicKey,
    1n * BigInt(10 ** decimals)
  );

  console.log("Minted 1 GIFT_SOL to:", ata.address.toBase58());

  // Update addresses.mainnet.json
  const raw = fs.readFileSync(ADDRESSES_PATH, "utf8");
  const json = JSON.parse(raw);
  if (!json.solana) json.solana = {};
  json.solana.giftMint = mint.toBase58();
  fs.writeFileSync(ADDRESSES_PATH, JSON.stringify(json, null, 2), "utf8");

  console.log(
    `Updated solana.giftMint in addresses.mainnet.json to ${mint.toBase58()}`
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
