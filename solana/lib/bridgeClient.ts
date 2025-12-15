import * as anchor from "@coral-xyz/anchor";
import { PublicKey, SystemProgram } from "@solana/web3.js";
import {
  ASSOCIATED_TOKEN_PROGRAM_ID,
  TOKEN_PROGRAM_ID,
  getAssociatedTokenAddress
} from "@solana/spl-token";

export async function mintFromPolygonUI(
  program: anchor.Program,
  configPda: PublicKey,
  giftMint: PublicKey,
  walletPubkey: PublicKey,
  amount: bigint,
  depositId: Uint8Array
): Promise<string> {
  if (depositId.length !== 32) {
    throw new Error("depositId must be 32 bytes");
  }

  const [mintAuthority] = PublicKey.findProgramAddressSync(
    [Buffer.from("mint_authority"), configPda.toBuffer()],
    program.programId
  );

  const [processedDeposit] = PublicKey.findProgramAddressSync(
    [Buffer.from("processed_deposit"), depositId],
    program.programId
  );

  const recipientTokenAccount = await getAssociatedTokenAddress(
    giftMint,
    walletPubkey,
    false,
    TOKEN_PROGRAM_ID,
    ASSOCIATED_TOKEN_PROGRAM_ID
  );

  const amountBn = new anchor.BN(amount.toString());

  const txSig = await program.methods
    .mintFromPolygon(amountBn, Array.from(depositId))
    .accounts({
      config: configPda,
      giftMint,
      mintAuthority,
      recipientTokenAccount,
      processedDeposit,
      admin: walletPubkey,
      tokenProgram: TOKEN_PROGRAM_ID,
      systemProgram: SystemProgram.programId
    })
    .rpc();

  return txSig;
}

export async function burnForPolygonUI(
  program: anchor.Program,
  configPda: PublicKey,
  giftMint: PublicKey,
  walletPubkey: PublicKey,
  amount: bigint,
  polygonRecipientBytes: Uint8Array
): Promise<string> {
  if (polygonRecipientBytes.length !== 20) {
    throw new Error("polygonRecipientBytes must be 20 bytes");
  }

  const userTokenAccount = await getAssociatedTokenAddress(
    giftMint,
    walletPubkey,
    false,
    TOKEN_PROGRAM_ID,
    ASSOCIATED_TOKEN_PROGRAM_ID
  );

  const amountBn = new anchor.BN(amount.toString());

  const txSig = await program.methods
    .burnForPolygon(amountBn, Array.from(polygonRecipientBytes))
    .accounts({
      config: configPda,
      giftMint,
      userTokenAccount,
      user: walletPubkey,
      tokenProgram: TOKEN_PROGRAM_ID
    })
    .rpc();

  return txSig;
}


