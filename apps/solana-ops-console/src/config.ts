import addresses from "../../../addresses/addresses.mainnet.json";

export type SolanaBridgeConfig = {
  rpcUrl: string;
  programId: string;
  giftMint: string;
  giftBridgeConfig?: string;
};

export function loadMainnetConfig(): SolanaBridgeConfig {
  const rpcUrl =
    process.env.NEXT_PUBLIC_SOLANA_RPC_URL ?? process.env.SOLANA_RPC_URL;

  if (!rpcUrl) {
    throw new Error(
      "SOLANA_RPC_URL is missing. Set NEXT_PUBLIC_SOLANA_RPC_URL (or SOLANA_RPC_URL) in your .env file to a mainnet-beta RPC endpoint."
    );
  }

  // addresses.mainnet.json is expected to have a "solana" section
  const solana = (addresses as any).solana ?? {};

  const programId = solana.giftBridgeProgram as string | undefined;
  const giftMint = solana.giftMint as string | undefined;
  const giftBridgeConfig = solana.giftBridgeConfig as string | undefined;

  if (!programId) {
    throw new Error(
      "addresses.mainnet.json is missing solana.giftBridgeProgram. Update addresses/addresses.mainnet.json."
    );
  }

  if (!giftMint) {
    throw new Error(
      "addresses.mainnet.json is missing solana.giftMint. Update addresses/addresses.mainnet.json."
    );
  }

  return {
    rpcUrl,
    programId,
    giftMint,
    giftBridgeConfig
  };
}

export function tryLoadMainnetConfig():
  | { config: SolanaBridgeConfig; error?: undefined }
  | { config?: undefined; error: string } {
  try {
    const config = loadMainnetConfig();
    return { config };
  } catch (e: any) {
    return { error: e?.message ?? String(e) };
  }
}


