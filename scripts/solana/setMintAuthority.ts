import { Connection, PublicKey } from "@solana/web3.js";
import {
  setAuthority,
  AuthorityType,
} from "@solana/spl-token";
import * as fs from "fs";
import * as path from "path";
import { Keypair } from "@solana/web3.js";
import dotenv from "dotenv";

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
    "SOLANA_RELAYER_KEYPAIR must be a path or JSON array; base58 strings are not supported in this script."
  );
}

async function main() {
  const raw = fs.readFileSync(ADDRESSES_PATH, "utf8");
  const json = JSON.parse(raw);

  const programIdStr = json.solana?.giftBridgeProgram;
  const mintStr = json.solana?.giftMint;
  const configStr = json.solana?.giftBridgeConfig;

  if (!programIdStr || !mintStr || !configStr) {
    throw new Error(
      "addresses.solana.giftBridgeProgram / giftMint / giftBridgeConfig must all be set"
    );
  }

  const programId = new PublicKey(programIdStr);
  const mintPk = new PublicKey(mintStr);
  const configPda = new PublicKey(configStr);

  const [mintAuthorityPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("mint_authority"), configPda.toBuffer()],
    programId
  );

  const rpcUrl =
    process.env.SOLANA_RPC_URL || "https://api.mainnet-beta.solana.com";
  const connection = new Connection(rpcUrl, "confirmed");
  const payer = loadPayer();

  console.log("Payer:", payer.publicKey.toBase58());
  console.log("Mint:", mintPk.toBase58());
  console.log("New mint authority PDA:", mintAuthorityPda.toBase58());

  const txSig = await setAuthority(
    connection,
    payer,
    mintPk,
    payer.publicKey,
    AuthorityType.MintTokens,
    mintAuthorityPda
  );

  console.log("setAuthority tx:", txSig);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});


