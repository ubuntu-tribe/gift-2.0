import * as anchor from "@coral-xyz/anchor";
import { PublicKey } from "@solana/web3.js";
import { getOrCreateAssociatedTokenAccount } from "@solana/spl-token";
import * as fs from "fs";
import * as path from "path";
import idl from "../../idl/gift_bridge_solana.json";

const ROOT = path.resolve(__dirname, "../..");
const ADDRESSES_PATH = path.join(ROOT, "addresses", "addresses.mainnet.json");

function loadAddresses() {
  const raw = fs.readFileSync(ADDRESSES_PATH, "utf8");
  return JSON.parse(raw);
}

export async function testMintFromPolygon() {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);
  const wallet = provider.wallet as anchor.Wallet;

  const json = loadAddresses();
  const programId = new PublicKey(json.solana.giftBridgeProgram);
  const giftMint = new PublicKey(json.solana.giftMint);
  const configPubkey = new PublicKey(json.solana.giftBridgeConfig);

  const program = new anchor.Program(
    idl as anchor.Idl,
    programId,
    provider
  );

  console.log("Wallet:", wallet.publicKey.toBase58());
  console.log("GIFT_SOL mint:", giftMint.toBase58());
  console.log("Config:", configPubkey.toBase58());

  const [mintAuthorityPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("mint_authority"), configPubkey.toBuffer()],
    programId
  );

  const ata = await getOrCreateAssociatedTokenAccount(
    provider.connection,
    wallet.payer,
    giftMint,
    wallet.publicKey
  );

  console.log("Recipient ATA:", ata.address.toBase58());

  const depositId = anchor.utils.bytes.utf8.encode("test-deposit-1");
  const depositIdPadded = new Uint8Array(32);
  depositIdPadded.set(depositId.slice(0, 32));

  const [processedDepositPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("processed_deposit"), Buffer.from(depositIdPadded)],
    programId
  );

  const amount = new anchor.BN(100_000_000_000_000_000n);

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
}

export async function testBurnForPolygon(polygonRecipientHex: string) {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);
  const wallet = provider.wallet as anchor.Wallet;

  const json = loadAddresses();
  const programId = new PublicKey(json.solana.giftBridgeProgram);
  const giftMint = new PublicKey(json.solana.giftMint);
  const configPubkey = new PublicKey(json.solana.giftBridgeConfig);

  const program = new anchor.Program(
    idl as anchor.Idl,
    programId,
    provider
  );

  const ata = await getOrCreateAssociatedTokenAccount(
    provider.connection,
    wallet.payer,
    giftMint,
    wallet.publicKey
  );

  console.log("Wallet:", wallet.publicKey.toBase58());
  console.log("User ATA:", ata.address.toBase58());

  const polygonRecipientBytes = Buffer.from(
    polygonRecipientHex.replace(/^0x/, ""),
    "hex"
  );
  if (polygonRecipientBytes.length !== 20) {
    throw new Error("polygonRecipientHex must be 20 bytes hex");
  }

  const burnAmount = new anchor.BN(50_000_000_000_000_000n);

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

if (require.main === module) {
  const [,, cmd, arg] = process.argv;
  if (cmd === "mint") {
    testMintFromPolygon().catch((err) => {
      console.error(err);
      process.exit(1);
    });
  } else if (cmd === "burn") {
    if (!arg) {
      console.error("Usage: ts-node bridgeClient.ts burn <polygonRecipientHex>");
      process.exit(1);
    }
    testBurnForPolygon(arg).catch((err) => {
      console.error(err);
      process.exit(1);
    });
  } else {
    console.error("Usage: ts-node bridgeClient.ts [mint|burn <polygonRecipientHex>]");
    process.exit(1);
  }
}
