import * as anchor from "@coral-xyz/anchor";
import { PublicKey, Keypair } from "@solana/web3.js";
import { getOrCreateAssociatedTokenAccount } from "@solana/spl-token";
import idl from "../../idl/gift_bridge_solana.json";

const PROGRAM_ID = new PublicKey(
  "Brdg111111111111111111111111111111111111111"
);

async function main() {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);
  const wallet = provider.wallet as anchor.Wallet;

  const program = new anchor.Program(idl as anchor.Idl, PROGRAM_ID, provider);

  const giftMint = new PublicKey(process.env.GIFT_SOL_MINT!);
  const configPubkey = new PublicKey(process.env.GIFT_BRIDGE_CONFIG!);

  console.log("Wallet:", wallet.publicKey.toBase58());
  console.log("GIFT_SOL mint:", giftMint.toBase58());
  console.log("Config:", configPubkey.toBase58());

  // Derive mint authority PDA
  const [mintAuthorityPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("mint_authority"), configPubkey.toBuffer()],
    PROGRAM_ID
  );

  // Get or create recipient token account (for testing, it's the same wallet)
  const ata = await getOrCreateAssociatedTokenAccount(
    provider.connection,
    wallet.payer,
    giftMint,
    wallet.publicKey
  );

  console.log("Recipient ATA:", ata.address.toBase58());

  // Simulate a deposit id (in production this must match Polygon side)
  const depositId = anchor.utils.bytes.utf8.encode("test-deposit-1");
  const depositIdPadded = new Uint8Array(32);
  depositIdPadded.set(depositId.slice(0, 32));

  // Derive processed_deposit PDA
  const [processedDepositPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("processed_deposit"), Buffer.from(depositIdPadded)],
    PROGRAM_ID
  );

  // Mint 100 GIFT_SOL (assuming 18 decimals you can scale as you like)
  const amount = new anchor.BN(100_000_000_000_000_000n); // 0.1 * 1e18, adjust as needed

  const tx = await program.methods
    .mintFromPolygon(amount, Array.from(depositIdPadded) as any)
    .accounts({
      config: configPubkey,
      giftMint,
      mintAuthority: mintAuthorityPda,
      recipientTokenAccount: ata.address,
      processedDeposit: processedDepositPda,
      admin: wallet.publicKey,
      tokenProgram: anchor.utils.token.TOKEN_PROGRAM_ID,
      systemProgram: anchor.web3.SystemProgram.programId,
    })
    .rpc();

  console.log("mint_from_polygon tx:", tx);

  // Now burn some to test burn_for_polygon
  const polygonRecipientHex =
    "0000000000000000000000000000000000000000"; // change to real address bytes
  const polygonRecipientBytes = Buffer.from(polygonRecipientHex, "hex");

  const burnAmount = new anchor.BN(50_000_000_000_000_000n); // 0.05 * 1e18

  const burnTx = await program.methods
    .burnForPolygon(burnAmount, Array.from(polygonRecipientBytes) as any)
    .accounts({
      config: configPubkey,
      giftMint,
      userTokenAccount: ata.address,
      user: wallet.publicKey,
      tokenProgram: anchor.utils.token.TOKEN_PROGRAM_ID,
    })
    .rpc();

  console.log("burn_for_polygon tx:", burnTx);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
