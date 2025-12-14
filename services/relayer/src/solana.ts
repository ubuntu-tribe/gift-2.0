import fs from "fs";
import path from "path";
import bs58 from "bs58";
import {
  Connection,
  Keypair,
  PublicKey,
  SystemProgram,
  Transaction,
  TransactionInstruction,
} from "@solana/web3.js";
import {
  AnchorProvider,
  Idl,
  Program,
  BorshCoder,
  EventParser,
  BN,
} from "@coral-xyz/anchor";
import {
  ASSOCIATED_TOKEN_PROGRAM_ID,
  TOKEN_PROGRAM_ID,
  createAssociatedTokenAccountInstruction,
  getAssociatedTokenAddressSync,
} from "@solana/spl-token";

import { addresses, config } from "./config";

export interface BurnEvent {
  user: string;
  amount: bigint;
  polygonRecipient: string; // 0x-prefixed hex (20 bytes)
  slot: number;
  signature: string;
}

function loadRelayerKeypair(): Keypair {
  const raw = config.solanaRelayerKeypair;

  // Treat as path if it looks like a path
  if (raw.includes("/") || raw.endsWith(".json")) {
    const fullPath = path.isAbsolute(raw)
      ? raw
      : path.resolve(__dirname, "../../", raw);
    const data = JSON.parse(fs.readFileSync(fullPath, "utf8"));
    const secret = Uint8Array.from(data);
    return Keypair.fromSecretKey(secret);
  }

  // Treat as JSON array
  if (raw.trim().startsWith("[")) {
    const arr = JSON.parse(raw);
    return Keypair.fromSecretKey(Uint8Array.from(arr));
  }

  // Otherwise assume base58-encoded secret key
  const bytes = bs58.decode(raw.trim());
  return Keypair.fromSecretKey(bytes);
}

export const connection = new Connection(config.solanaRpcUrl, "confirmed");
export const relayerKeypair = loadRelayerKeypair();

// Load IDL and program
const idlPath = path.resolve(
  __dirname,
  "../../idl/gift_bridge_solana.json"
);
const idl = JSON.parse(fs.readFileSync(idlPath, "utf8")) as Idl;

const programId = new PublicKey(addresses.solana.giftBridgeProgram);

const wallet = {
  publicKey: relayerKeypair.publicKey,
  async signTransaction(tx: Transaction): Promise<Transaction> {
    tx.partialSign(relayerKeypair);
    return tx;
  },
  async signAllTransactions(
    txs: Transaction[]
  ): Promise<Transaction[]> {
    txs.forEach((tx) => tx.partialSign(relayerKeypair));
    return txs;
  },
};

export const provider = new AnchorProvider(
  connection,
  wallet as any,
  AnchorProvider.defaultOptions()
);

export const program: Program = new (Program as any)(
  idl,
  programId,
  provider
);

const coder = new BorshCoder(idl);
const eventParser = new EventParser(programId, coder);

export async function mintFromPolygonOnSolana(
  recipientBase58: string,
  amount: bigint,
  depositId: Uint8Array
): Promise<string> {
  const recipient = new PublicKey(recipientBase58);
  const configPk = new PublicKey(addresses.solana.giftBridgeConfig);
  const mintPk = new PublicKey(addresses.solana.giftMint);

  const [mintAuthorityPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("mint_authority"), configPk.toBuffer()],
    program.programId
  );

  const [processedDepositPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("processed_deposit"), Buffer.from(depositId)],
    program.programId
  );

  const ata = getAssociatedTokenAddressSync(
    mintPk,
    recipient,
    false,
    TOKEN_PROGRAM_ID,
    ASSOCIATED_TOKEN_PROGRAM_ID
  );

  const ixs: TransactionInstruction[] = [];

  const ataInfo = await connection.getAccountInfo(ata);
  if (!ataInfo) {
    ixs.push(
      createAssociatedTokenAccountInstruction(
        relayerKeypair.publicKey, // payer
        ata,
        recipient,
        mintPk,
        TOKEN_PROGRAM_ID,
        ASSOCIATED_TOKEN_PROGRAM_ID
      )
    );
  }

  const mintIx = await program.methods
    .mintFromPolygon(new BN(amount.toString()), Array.from(depositId))
    .accounts({
      config: configPk,
      giftMint: mintPk,
      mintAuthority: mintAuthorityPda,
      recipientTokenAccount: ata,
      processedDeposit: processedDepositPda,
      admin: relayerKeypair.publicKey,
      tokenProgram: TOKEN_PROGRAM_ID,
      systemProgram: SystemProgram.programId,
    })
    .instruction();

  const tx = new Transaction().add(...ixs, mintIx);
  const sig = await provider.sendAndConfirm(tx, [relayerKeypair]);
  return sig;
}

export async function getNewBurnEvents(
  lastSlotProcessed: number
): Promise<{ burns: BurnEvent[]; latestSlot: number }> {
  const sigInfos = await connection.getSignaturesForAddress(programId, {
    limit: 1000,
  });

  const newInfos = sigInfos
    .filter((info) => info.slot > lastSlotProcessed)
    .sort((a, b) => a.slot - b.slot); // oldest -> newest

  const burns: BurnEvent[] = [];
  let latestSlot = lastSlotProcessed;

  for (const info of newInfos) {
    const tx = await connection.getTransaction(info.signature, {
      commitment: "confirmed",
      maxSupportedTransactionVersion: 0,
    });
    if (!tx || !tx.meta?.logMessages) continue;

    for (const ev of eventParser.parseLogs(tx.meta.logMessages)) {
      if (ev.name === "BurnForPolygonEvent") {
        const data: any = ev.data;
        const user = (data.user as PublicKey).toBase58();
        const amount = BigInt((data.amount as BN).toString());
        const polygonRecipientBytes: number[] = data.polygonRecipient;
        const polygonRecipient =
          "0x" +
          Buffer.from(polygonRecipientBytes).toString("hex");

        burns.push({
          user,
          amount,
          polygonRecipient,
          slot: info.slot,
          signature: info.signature,
        });
        if (info.slot > latestSlot) latestSlot = info.slot;
      }
    }
  }

  return { burns, latestSlot };
}


