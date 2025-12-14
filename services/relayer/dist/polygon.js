"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.bridgeContract = void 0;
exports.getNewDeposits = getNewDeposits;
exports.completeWithdrawal = completeWithdrawal;
const ethers_1 = require("ethers");
const config_1 = require("./config");
const bridgeAbi = [
    "event DepositedToSolana(address indexed sender, bytes32 indexed solanaRecipient, uint256 amount, uint256 nonce)",
    "function completeWithdrawalFromSolana(address polygonRecipient, uint256 amount, bytes32 solanaBurnTx) external",
];
const polygonProvider = new ethers_1.ethers.JsonRpcProvider(config_1.config.polygonRpcUrl);
const relayerWallet = new ethers_1.ethers.Wallet(config_1.config.polygonRelayerPrivateKey, polygonProvider);
const bridgeAddress = config_1.addresses.polygon.GiftPolygonBridge.proxy;
exports.bridgeContract = new ethers_1.ethers.Contract(bridgeAddress, bridgeAbi, relayerWallet);
async function getNewDeposits(lastBlock) {
    const latestBlock = await polygonProvider.getBlockNumber();
    const fromBlock = Math.max(lastBlock + 1, 0);
    if (fromBlock > latestBlock) {
        return { deposits: [], latestBlock };
    }
    const events = (await exports.bridgeContract.queryFilter(exports.bridgeContract.filters.DepositedToSolana(), fromBlock, latestBlock));
    const deposits = events.map((ev) => {
        const { sender, solanaRecipient, amount, nonce } = ev.args;
        return {
            sender,
            solanaRecipient,
            amount: BigInt(amount.toString()),
            nonce: BigInt(nonce.toString()),
            blockNumber: ev.blockNumber,
            txHash: ev.transactionHash,
        };
    });
    return { deposits, latestBlock };
}
async function completeWithdrawal(polygonRecipient, amount, solanaBurnTx) {
    // solanaBurnTx is a hex string or tx signature; we hash to bytes32 for on-chain use.
    const burnTxBytes32 = ethers_1.ethers.keccak256(ethers_1.ethers.toUtf8Bytes(solanaBurnTx.toString()));
    const tx = await exports.bridgeContract.completeWithdrawalFromSolana(polygonRecipient, amount, burnTxBytes32);
    const receipt = await tx.wait();
    return receipt.hash;
}
