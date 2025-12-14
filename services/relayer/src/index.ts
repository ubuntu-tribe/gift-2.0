import { ethers } from "ethers";
import bs58 from "bs58";
import { addresses } from "./config";
import { loadState, saveState } from "./store";
import {
  getNewDeposits,
  completeWithdrawal,
  DepositEvent,
} from "./polygon";
import {
  getNewBurnEvents,
  mintFromPolygonOnSolana,
} from "./solana";

function makeDepositIdHex(deposit: DepositEvent): string {
  const encoded = ethers.AbiCoder.defaultAbiCoder().encode(
    ["bytes32", "uint256"],
    [deposit.txHash as string, deposit.nonce]
  );
  return ethers.keccak256(encoded);
}

function hexToBytes32(hex: string): Uint8Array {
  const clean = hex.startsWith("0x") ? hex.slice(2) : hex;
  return Uint8Array.from(Buffer.from(clean, "hex"));
}

async function processDeposits() {
  const state = loadState();
  console.log(
    `Last Polygon block processed: ${state.lastPolygonBlockProcessed}`
  );

  const { deposits, latestBlock } = await getNewDeposits(
    state.lastPolygonBlockProcessed
  );

  if (deposits.length === 0) {
    console.log("No new deposits to process.");
    return;
  }

  console.log(`Found ${deposits.length} new deposits.`);

  for (const dep of deposits) {
    const depositIdHex = makeDepositIdHex(dep);
    if (state.processedDepositIds.includes(depositIdHex)) {
      console.log(
        `Skipping already-processed deposit ${depositIdHex} (tx=${dep.txHash})`
      );
      continue;
    }

    const depositIdBytes = hexToBytes32(depositIdHex);

    // solanaRecipient is bytes32; treat as 32-byte public key for Solana.
    const solanaRecipientPubkeyHex = dep.solanaRecipient as string;
    const solanaRecipientBytes = hexToBytes32(solanaRecipientPubkeyHex);
    const solanaRecipientPubkeyBase58 = bs58.encode(solanaRecipientBytes);

    console.log(
      `Processing deposit tx=${dep.txHash}, amount=${dep.amount.toString()}, nonce=${dep.nonce.toString()}`
    );

    const sig = await mintFromPolygonOnSolana(
      solanaRecipientPubkeyBase58,
      dep.amount,
      depositIdBytes
    );

    console.log(
      `  -> minted on Solana, tx signature: ${sig}, depositId=${depositIdHex}`
    );

    state.processedDepositIds.push(depositIdHex);
    state.lastPolygonBlockProcessed = Math.max(
      state.lastPolygonBlockProcessed,
      dep.blockNumber
    );
    saveState(state);
  }

  console.log("Finished processing deposits.");
}

async function processBurns() {
  const state = loadState();
  console.log(
    `Last Solana slot processed: ${state.lastSolanaSlotProcessed}`
  );

  const { burns, latestSlot } = await getNewBurnEvents(
    state.lastSolanaSlotProcessed
  );

  if (burns.length === 0) {
    console.log("No new burn events to process.");
    return;
  }

  console.log(`Found ${burns.length} new burn events.`);

  for (const burn of burns) {
    if (state.processedBurnSignatures.includes(burn.signature)) {
      console.log(
        `Skipping already-processed burn ${burn.signature}`
      );
      continue;
    }

    console.log(
      `Processing burn sig=${burn.signature}, amount=${burn.amount.toString()}, polygonRecipient=${burn.polygonRecipient}`
    );

    const txHash = await completeWithdrawal(
      burn.polygonRecipient,
      burn.amount,
      burn.signature
    );

    console.log(
      `  -> completed withdrawal on Polygon, tx hash: ${txHash}`
    );

    state.processedBurnSignatures.push(burn.signature);
    state.lastSolanaSlotProcessed = Math.max(
      state.lastSolanaSlotProcessed,
      burn.slot
    );
    saveState(state);
  }

  console.log("Finished processing burns.");
}

async function main() {
  const [, , cmd] = process.argv;

  if (cmd === "process-deposits") {
    await processDeposits();
  } else if (cmd === "process-burns") {
    await processBurns();
  } else {
    console.error(
      'Usage: node dist/index.js [process-deposits | process-burns]'
    );
    process.exit(1);
  }
}

main().catch((err) => {
  console.error("Relayer error:", err);
  process.exit(1);
});


