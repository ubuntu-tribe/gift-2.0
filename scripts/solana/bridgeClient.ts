import * as anchor from "@coral-xyz/anchor";
import { PublicKey } from "@solana/web3.js";
import { getOrCreateAssociatedTokenAccount } from "@solana/spl-token";
import * as fs from "fs";
import * as path from "path";
import idl from "../../idl/gift_bridge_solana.json";
import {
  burnForPolygonUI,
  mintFromPolygonUI,
} from "../../solana/lib/bridgeClient";

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

  const amount = new anchor.BN(100_000_000_000_000_000n);

  console.log("Wallet:", wallet.publicKey.toBase58());
  console.log("GIFT_SOL mint:", giftMint.toBase58());
  console.log("Config:", configPubkey.toBase58());
  console.log("Recipient ATA:", ata.address.toBase58());

  const txSig = await mintFromPolygonUI(
    program,
    configPubkey,
    giftMint,
    wallet.publicKey,
    amount.toBigInt(),
    depositIdPadded
  );

  console.log("mint_from_polygon tx:", txSig);
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

  const burnTxSig = await burnForPolygonUI(
    program,
    configPubkey,
    giftMint,
    wallet.publicKey,
    burnAmount.toBigInt(),
    polygonRecipientBytes
  );

  console.log("burn_for_polygon tx:", burnTxSig);
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
