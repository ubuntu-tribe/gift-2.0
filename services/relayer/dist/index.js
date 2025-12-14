"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const ethers_1 = require("ethers");
const bs58_1 = __importDefault(require("bs58"));
const store_1 = require("./store");
const polygon_1 = require("./polygon");
const solana_1 = require("./solana");
function makeDepositIdHex(deposit) {
    const encoded = ethers_1.ethers.AbiCoder.defaultAbiCoder().encode(["bytes32", "uint256"], [deposit.txHash, deposit.nonce]);
    return ethers_1.ethers.keccak256(encoded);
}
function hexToBytes32(hex) {
    const clean = hex.startsWith("0x") ? hex.slice(2) : hex;
    return Uint8Array.from(Buffer.from(clean, "hex"));
}
async function processDeposits() {
    const state = (0, store_1.loadState)();
    console.log(`Last Polygon block processed: ${state.lastPolygonBlockProcessed}`);
    const { deposits, latestBlock } = await (0, polygon_1.getNewDeposits)(state.lastPolygonBlockProcessed);
    if (deposits.length === 0) {
        console.log("No new deposits to process.");
        return;
    }
    console.log(`Found ${deposits.length} new deposits.`);
    for (const dep of deposits) {
        const depositIdHex = makeDepositIdHex(dep);
        if (state.processedDepositIds.includes(depositIdHex)) {
            console.log(`Skipping already-processed deposit ${depositIdHex} (tx=${dep.txHash})`);
            continue;
        }
        const depositIdBytes = hexToBytes32(depositIdHex);
        // solanaRecipient is bytes32; treat as 32-byte public key for Solana.
        const solanaRecipientPubkeyHex = dep.solanaRecipient;
        const solanaRecipientBytes = hexToBytes32(solanaRecipientPubkeyHex);
        const solanaRecipientPubkeyBase58 = bs58_1.default.encode(solanaRecipientBytes);
        console.log(`Processing deposit tx=${dep.txHash}, amount=${dep.amount.toString()}, nonce=${dep.nonce.toString()}`);
        const sig = await (0, solana_1.mintFromPolygonOnSolana)(solanaRecipientPubkeyBase58, dep.amount, depositIdBytes);
        console.log(`  -> minted on Solana, tx signature: ${sig}, depositId=${depositIdHex}`);
        state.processedDepositIds.push(depositIdHex);
        state.lastPolygonBlockProcessed = Math.max(state.lastPolygonBlockProcessed, dep.blockNumber);
        (0, store_1.saveState)(state);
    }
    console.log("Finished processing deposits.");
}
async function processBurns() {
    const state = (0, store_1.loadState)();
    console.log(`Last Solana slot processed: ${state.lastSolanaSlotProcessed}`);
    const { burns, latestSlot } = await (0, solana_1.getNewBurnEvents)(state.lastSolanaSlotProcessed);
    if (burns.length === 0) {
        console.log("No new burn events to process.");
        return;
    }
    console.log(`Found ${burns.length} new burn events.`);
    for (const burn of burns) {
        if (state.processedBurnSignatures.includes(burn.signature)) {
            console.log(`Skipping already-processed burn ${burn.signature}`);
            continue;
        }
        console.log(`Processing burn sig=${burn.signature}, amount=${burn.amount.toString()}, polygonRecipient=${burn.polygonRecipient}`);
        const txHash = await (0, polygon_1.completeWithdrawal)(burn.polygonRecipient, burn.amount, burn.signature);
        console.log(`  -> completed withdrawal on Polygon, tx hash: ${txHash}`);
        state.processedBurnSignatures.push(burn.signature);
        state.lastSolanaSlotProcessed = Math.max(state.lastSolanaSlotProcessed, burn.slot);
        (0, store_1.saveState)(state);
    }
    console.log("Finished processing burns.");
}
async function main() {
    const [, , cmd] = process.argv;
    if (cmd === "process-deposits") {
        await processDeposits();
    }
    else if (cmd === "process-burns") {
        await processBurns();
    }
    else {
        console.error('Usage: node dist/index.js [process-deposits | process-burns]');
        process.exit(1);
    }
}
main().catch((err) => {
    console.error("Relayer error:", err);
    process.exit(1);
});
