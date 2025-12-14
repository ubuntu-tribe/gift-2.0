"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.program = exports.provider = exports.relayerKeypair = exports.connection = void 0;
exports.mintFromPolygonOnSolana = mintFromPolygonOnSolana;
exports.getNewBurnEvents = getNewBurnEvents;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const bs58_1 = __importDefault(require("bs58"));
const web3_js_1 = require("@solana/web3.js");
const anchor_1 = require("@coral-xyz/anchor");
const spl_token_1 = require("@solana/spl-token");
const config_1 = require("./config");
function loadRelayerKeypair() {
    const raw = config_1.config.solanaRelayerKeypair;
    // Treat as path if it looks like a path
    if (raw.includes("/") || raw.endsWith(".json")) {
        const fullPath = path_1.default.isAbsolute(raw)
            ? raw
            : path_1.default.resolve(__dirname, "../../", raw);
        const data = JSON.parse(fs_1.default.readFileSync(fullPath, "utf8"));
        const secret = Uint8Array.from(data);
        return web3_js_1.Keypair.fromSecretKey(secret);
    }
    // Treat as JSON array
    if (raw.trim().startsWith("[")) {
        const arr = JSON.parse(raw);
        return web3_js_1.Keypair.fromSecretKey(Uint8Array.from(arr));
    }
    // Otherwise assume base58-encoded secret key
    const bytes = bs58_1.default.decode(raw.trim());
    return web3_js_1.Keypair.fromSecretKey(bytes);
}
exports.connection = new web3_js_1.Connection(config_1.config.solanaRpcUrl, "confirmed");
exports.relayerKeypair = loadRelayerKeypair();
// Load IDL and program
const idlPath = path_1.default.resolve(__dirname, "../../idl/gift_bridge_solana.json");
const idl = JSON.parse(fs_1.default.readFileSync(idlPath, "utf8"));
const programId = new web3_js_1.PublicKey(config_1.addresses.solana.giftBridgeProgram);
const wallet = {
    publicKey: exports.relayerKeypair.publicKey,
    async signTransaction(tx) {
        tx.partialSign(exports.relayerKeypair);
        return tx;
    },
    async signAllTransactions(txs) {
        txs.forEach((tx) => tx.partialSign(exports.relayerKeypair));
        return txs;
    },
};
exports.provider = new anchor_1.AnchorProvider(exports.connection, wallet, anchor_1.AnchorProvider.defaultOptions());
exports.program = new anchor_1.Program(idl, programId, exports.provider);
const coder = new anchor_1.BorshCoder(idl);
const eventParser = new anchor_1.EventParser(programId, coder);
async function mintFromPolygonOnSolana(recipientBase58, amount, depositId) {
    const recipient = new web3_js_1.PublicKey(recipientBase58);
    const configPk = new web3_js_1.PublicKey(config_1.addresses.solana.giftBridgeConfig);
    const mintPk = new web3_js_1.PublicKey(config_1.addresses.solana.giftMint);
    const [mintAuthorityPda] = web3_js_1.PublicKey.findProgramAddressSync([Buffer.from("mint_authority"), configPk.toBuffer()], exports.program.programId);
    const [processedDepositPda] = web3_js_1.PublicKey.findProgramAddressSync([Buffer.from("processed_deposit"), Buffer.from(depositId)], exports.program.programId);
    const ata = (0, spl_token_1.getAssociatedTokenAddressSync)(mintPk, recipient, false, spl_token_1.TOKEN_PROGRAM_ID, spl_token_1.ASSOCIATED_TOKEN_PROGRAM_ID);
    const ixs = [];
    const ataInfo = await exports.connection.getAccountInfo(ata);
    if (!ataInfo) {
        ixs.push((0, spl_token_1.createAssociatedTokenAccountInstruction)(exports.relayerKeypair.publicKey, // payer
        ata, recipient, mintPk, spl_token_1.TOKEN_PROGRAM_ID, spl_token_1.ASSOCIATED_TOKEN_PROGRAM_ID));
    }
    const mintIx = await exports.program.methods
        .mintFromPolygon(new anchor_1.BN(amount.toString()), Array.from(depositId))
        .accounts({
        config: configPk,
        giftMint: mintPk,
        mintAuthority: mintAuthorityPda,
        recipientTokenAccount: ata,
        processedDeposit: processedDepositPda,
        admin: exports.relayerKeypair.publicKey,
        tokenProgram: spl_token_1.TOKEN_PROGRAM_ID,
        systemProgram: web3_js_1.SystemProgram.programId,
    })
        .instruction();
    const tx = new web3_js_1.Transaction().add(...ixs, mintIx);
    const sig = await exports.provider.sendAndConfirm(tx, [exports.relayerKeypair]);
    return sig;
}
async function getNewBurnEvents(lastSlotProcessed) {
    var _a;
    const sigInfos = await exports.connection.getSignaturesForAddress(programId, {
        limit: 1000,
    });
    const newInfos = sigInfos
        .filter((info) => info.slot > lastSlotProcessed)
        .sort((a, b) => a.slot - b.slot); // oldest -> newest
    const burns = [];
    let latestSlot = lastSlotProcessed;
    for (const info of newInfos) {
        const tx = await exports.connection.getTransaction(info.signature, {
            commitment: "confirmed",
            maxSupportedTransactionVersion: 0,
        });
        if (!tx || !((_a = tx.meta) === null || _a === void 0 ? void 0 : _a.logMessages))
            continue;
        for (const ev of eventParser.parseLogs(tx.meta.logMessages)) {
            if (ev.name === "BurnForPolygonEvent") {
                const data = ev.data;
                const user = data.user.toBase58();
                const amount = BigInt(data.amount.toString());
                const polygonRecipientBytes = data.polygonRecipient;
                const polygonRecipient = "0x" +
                    Buffer.from(polygonRecipientBytes).toString("hex");
                burns.push({
                    user,
                    amount,
                    polygonRecipient,
                    slot: info.slot,
                    signature: info.signature,
                });
                if (info.slot > latestSlot)
                    latestSlot = info.slot;
            }
        }
    }
    return { burns, latestSlot };
}
