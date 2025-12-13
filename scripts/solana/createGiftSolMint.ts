import {
  Connection,
  Keypair,
  clusterApiUrl,
} from "@solana/web3.js";
import {
  createMint,
  getOrCreateAssociatedTokenAccount,
  mintTo,
} from "@solana/spl-token";
import * as fs from "fs";

async function main() {
  const connection = new Connection(clusterApiUrl("devnet"), "confirmed");

  // Use your default Solana keypair (~/.config/solana/id.json)
  const secret = JSON.parse(
    fs.readFileSync(process.env.HOME + "/.config/solana/id.json", "utf-8")
  );
  const payer = Keypair.fromSecretKey(new Uint8Array(secret));

  console.log("Payer:", payer.publicKey.toBase58());

  // Create mint with 18 decimals
  const decimals = 18;
  const mint = await createMint(
    connection,
    payer,
    payer.publicKey, // mint authority
    payer.publicKey, // freeze authority
    decimals
  );

  console.log("GIFT_SOL mint address:", mint.toBase58());

  // Optionally create your own associated token account and mint a small amount for testing
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
    1n * BigInt(10 ** decimals) // 1 token
  );

  console.log("Minted 1 GIFT_SOL to:", ata.address.toBase58());
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
