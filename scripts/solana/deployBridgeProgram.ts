import * as anchor from "@coral-xyz/anchor";
import { PublicKey } from "@solana/web3.js";
import * as fs from "fs";
import idl from "../../idl/gift_bridge_solana.json";

const PROGRAM_ID = new PublicKey(
  "Brdg111111111111111111111111111111111111111" // same as in lib.rs / Anchor.toml
);

async function main() {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const walletPubkey = provider.wallet.publicKey;
  console.log("Wallet:", walletPubkey.toBase58());

  const program = new anchor.Program(idl as anchor.Idl, PROGRAM_ID, provider);

  // Use the mint you created with createGiftSolMint.ts
  const giftMintStr = process.env.GIFT_SOL_MINT!;
  if (!giftMintStr) {
    throw new Error("Set GIFT_SOL_MINT env var to your mint address");
  }
  const giftMint = new PublicKey(giftMintStr);

  // Derive config PDA
  const [configPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("config")],
    PROGRAM_ID
  );

  // Example Polygon bridge address (20 bytes). Replace with actual.
  const polygonBridgeAddress = "0x0000000000000000000000000000000000000000".replace(
    "0x",
    ""
  );
  const polygonBridgeBytes = Buffer.from(polygonBridgeAddress, "hex");
  if (polygonBridgeBytes.length !== 20) throw new Error("Bad bridge address");

  const tx = await program.methods
    .initializeConfig(giftMint, Array.from(polygonBridgeBytes) as any)
    .accounts({
      config: configPda,
      admin: walletPubkey,
      systemProgram: anchor.web3.SystemProgram.programId,
    })
    .rpc();

  console.log("initialize_config tx:", tx);
  console.log("Config PDA:", configPda.toBase58());
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
