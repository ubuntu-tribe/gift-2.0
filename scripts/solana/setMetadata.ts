import { Connection, Keypair, PublicKey, Transaction } from "@solana/web3.js";
import {
  PROGRAM_ID as TOKEN_METADATA_PROGRAM_ID,
  createUpdateMetadataAccountV2Instruction,
} from "@metaplex-foundation/mpl-token-metadata";
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

function loadAddresses() {
  const raw = fs.readFileSync(ADDRESSES_PATH, "utf8");
  return JSON.parse(raw);
}

async function main() {
  const rpcUrl =
    process.env.SOLANA_RPC_URL || "https://api.mainnet-beta.solana.com";
  const connection = new Connection(rpcUrl, "confirmed");
  const payer = loadPayer();

  const json = loadAddresses();
  const mintStr = json.solana?.giftMint;
  if (!mintStr) {
    throw new Error("addresses.solana.giftMint is not set");
  }

  const mint = new PublicKey(mintStr);

  // Derive metadata PDA for this mint
  const [metadataPda] = PublicKey.findProgramAddressSync(
    [
      Buffer.from("metadata"),
      TOKEN_METADATA_PROGRAM_ID.toBuffer(),
      mint.toBuffer(),
    ],
    TOKEN_METADATA_PROGRAM_ID
  );

  console.log("Setting metadata for mint:", mint.toBase58());
  console.log("Metadata PDA:", metadataPda.toBase58());
  console.log("Payer / update authority:", payer.publicKey.toBase58());

  const data = {
    name: "GIFT",
    symbol: "GIFT",
    uri: "ipfs://bafkreicgwbb4wzl4sqcq4dpxeffjoxbtsvpvgwidhs2xsp4gvhjfyds6ge",
    sellerFeeBasisPoints: 0,
    creators: null,
    collection: null,
    uses: null,
  };

  const ix = createUpdateMetadataAccountV2Instruction(
    {
      metadata: metadataPda,
      updateAuthority: payer.publicKey,
    },
    {
      updateMetadataAccountArgsV2: {
        // Replace full DataV2 (name, symbol, uri, etc.).
        data: data as any,
        // Leave these fields unchanged on-chain.
        updateAuthority: null,
        primarySaleHappened: null,
        isMutable: null,
      },
    }
  );

  const tx = new Transaction().add(ix);
  const sig = await connection.sendTransaction(tx, [payer]);

  console.log("Metadata tx signature:", sig);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});


