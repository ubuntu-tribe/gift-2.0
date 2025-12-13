import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { expect } from "chai";
import {
  PublicKey,
  Keypair,
} from "@solana/web3.js";
import {
  getAccount,
  getOrCreateAssociatedTokenAccount,
} from "@solana/spl-token";
import idl from "../../idl/gift_bridge_solana.json";

// This test suite assumes:
// - A local validator or devnet is running and reachable via ANCHOR_PROVIDER_URL.
// - ANCHOR_WALLET points to a funded keypair JSON file.
// - The gift_bridge_solana program is deployed with ID = PROGRAM_ID.
// - GIFT_SOL_MINT and GIFT_BRIDGE_CONFIG env vars are set:
//     GIFT_SOL_MINT      = GIFT_SOL mint address (SPL token mint)
//     GIFT_BRIDGE_CONFIG = Config PDA address (created via deployBridgeProgram.ts)

const PROGRAM_ID = new PublicKey(
  "Brdg111111111111111111111111111111111111111"
);

// IDL type is any here to avoid generating TS types; this keeps things simple.
type GiftBridgeProgram = Program<any>;

describe("gift_bridge_solana (basic integration tests)", () => {
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const wallet = provider.wallet as anchor.Wallet;
  const connection = provider.connection;

  const program: GiftBridgeProgram = new anchor.Program(
    idl as anchor.Idl,
    PROGRAM_ID,
    provider
  );

  const giftMint = new PublicKey(process.env.GIFT_SOL_MINT!);
  const configPubkey = new PublicKey(process.env.GIFT_BRIDGE_CONFIG!);

  it("reads the Config account and checks wiring", async () => {
    const cfg: any = await (program.account as any).config.fetch(configPubkey);

    expect(cfg.admin.toBase58()).to.equal(wallet.publicKey.toBase58());
    expect(cfg.giftMint.toBase58()).to.equal(giftMint.toBase58());
    expect(cfg.extraMinters).to.be.an("array");
  });

  it("adds and removes an extra minter", async () => {
    const newMinter = Keypair.generate().publicKey;

    // Add minter
    await program.methods
      .addMinter(newMinter)
      .accounts({
        config: configPubkey,
        admin: wallet.publicKey,
      })
      .rpc();

    let cfg: any = await (program.account as any).config.fetch(configPubkey);
    const hasMinterAfterAdd = cfg.extraMinters.some(
      (k: PublicKey) => k.toBase58() === newMinter.toBase58()
    );
    expect(hasMinterAfterAdd).to.equal(true);

    // Remove minter
    await program.methods
      .removeMinter(newMinter)
      .accounts({
        config: configPubkey,
        admin: wallet.publicKey,
      })
      .rpc();

    cfg = await (program.account as any).config.fetch(configPubkey);
    const hasMinterAfterRemove = cfg.extraMinters.some(
      (k: PublicKey) => k.toBase58() === newMinter.toBase58()
    );
    expect(hasMinterAfterRemove).to.equal(false);
  });

  it("mints from a fake Polygon deposit and then burns back to Polygon", async () => {
    // Prepare recipient ATA (use the wallet itself for simplicity).
    const ata = await getOrCreateAssociatedTokenAccount(
      connection,
      wallet.payer,
      giftMint,
      wallet.publicKey
    );

    const before = (await getAccount(connection, ata.address)).amount;

    // Build a fake deposit id (32 bytes)
    const label = anchor.utils.bytes.utf8.encode(
      "test-deposit-" + Date.now().toString()
    );
    const depositIdPadded = new Uint8Array(32);
    depositIdPadded.set(label.slice(0, 32));

    // Derive PDAs used by the program
    const [mintAuthorityPda] = PublicKey.findProgramAddressSync(
      [Buffer.from("mint_authority"), configPubkey.toBuffer()],
      PROGRAM_ID
    );
    const [processedDepositPda] = PublicKey.findProgramAddressSync(
      [Buffer.from("processed_deposit"), Buffer.from(depositIdPadded)],
      PROGRAM_ID
    );

    // Mint 0.1 GIFT_SOL (assuming 18 decimals)
    const amount = new anchor.BN(100_000_000_000_000_000n); // 0.1 * 1e18

    await program.methods
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

    const afterMint = (await getAccount(connection, ata.address)).amount;
    expect(afterMint - before).to.equal(BigInt(amount.toString()));

    // Now burn half of it to simulate a withdrawal back to Polygon.
    const burnAmount = new anchor.BN(
      BigInt(amount.toString()) / 2n
    );

    // Example Polygon recipient bytes (all zeros here; replace in real env).
    const polygonRecipientBytes = new Uint8Array(20); // 20 zero bytes

    await program.methods
      .burnForPolygon(burnAmount, Array.from(polygonRecipientBytes) as any)
      .accounts({
        config: configPubkey,
        giftMint,
        userTokenAccount: ata.address,
        user: wallet.publicKey,
        tokenProgram: anchor.utils.token.TOKEN_PROGRAM_ID,
      })
      .rpc();

    const afterBurn = (await getAccount(connection, ata.address)).amount;
    expect(before + BigInt(amount.toString()) - BigInt(burnAmount.toString()))
      .to.equal(afterBurn);
  });
});


