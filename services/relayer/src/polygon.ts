import { ethers } from "ethers";
import { addresses, config } from "./config";

export interface DepositEvent {
  sender: string;
  solanaRecipient: string; // bytes32 hex string
  amount: bigint;
  nonce: bigint;
  blockNumber: number;
  txHash: string;
}

const bridgeAbi = [
  "event DepositedToSolana(address indexed sender, bytes32 indexed solanaRecipient, uint256 amount, uint256 nonce)",
  "function completeWithdrawalFromSolana(address polygonRecipient, uint256 amount, bytes32 solanaBurnTx) external",
];

const polygonProvider = new ethers.JsonRpcProvider(config.polygonRpcUrl);
const relayerWallet = new ethers.Wallet(
  config.polygonRelayerPrivateKey,
  polygonProvider
);

const bridgeAddress = addresses.polygon.GiftPolygonBridge.proxy;
export const bridgeContract = new ethers.Contract(
  bridgeAddress,
  bridgeAbi,
  relayerWallet
);

export async function getNewDeposits(
  lastBlock: number
): Promise<{ deposits: DepositEvent[]; latestBlock: number }> {
  const latestBlock = await polygonProvider.getBlockNumber();
  const fromBlock = Math.max(lastBlock + 1, 0);
  if (fromBlock > latestBlock) {
    return { deposits: [], latestBlock };
  }

  const events = (await bridgeContract.queryFilter(
    bridgeContract.filters.DepositedToSolana(),
    fromBlock,
    latestBlock
  )) as ethers.EventLog[];

  const deposits: DepositEvent[] = events.map((ev) => {
    const { sender, solanaRecipient, amount, nonce } = ev.args as any;
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

export async function completeWithdrawal(
  polygonRecipient: string,
  amount: bigint,
  solanaBurnTx: string
): Promise<string> {
  // solanaBurnTx is a hex string or tx signature; we hash to bytes32 for on-chain use.
  const burnTxBytes32 = ethers.keccak256(
    ethers.toUtf8Bytes(solanaBurnTx.toString())
  );

  const tx = await bridgeContract.completeWithdrawalFromSolana(
    polygonRecipient,
    amount,
    burnTxBytes32
  );
  const receipt = await tx.wait();
  return receipt.hash;
}


