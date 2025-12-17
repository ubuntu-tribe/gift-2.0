"use client";

import { useMemo } from "react";
import * as anchor from "@coral-xyz/anchor";
import { Connection, PublicKey } from "@solana/web3.js";
import { useAnchorWallet } from "@solana/wallet-adapter-react";
import { tryLoadMainnetConfig } from "../config";
import idl from "../../../../idl/gift_bridge_solana.json";

export function useSolanaBridge() {
  const anchorWallet = useAnchorWallet();

  const { config, error } = useMemo(() => tryLoadMainnetConfig(), []);

  const connection = useMemo(() => {
    if (!config) return null;
    return new Connection(config.rpcUrl, "confirmed");
  }, [config]);

  const provider = useMemo(() => {
    if (!connection || !anchorWallet) return null;
    return new anchor.AnchorProvider(connection, anchorWallet, {
      commitment: "confirmed"
    });
  }, [connection, anchorWallet]);

  const program = useMemo(() => {
    if (!provider || !config?.programId) return null;
    try {
      return new anchor.Program(
        idl as anchor.Idl,
        new PublicKey(config.programId),
        provider
      );
    } catch (e) {
      console.error("Failed to create Solana program from config", {
        error: e,
        config,
      });
      return null;
    }
  }, [provider, config]);

  const giftMint = useMemo(() => {
    if (!config) return undefined;
    return new PublicKey(config.giftMint);
  }, [config]);

  const configPda = useMemo(() => {
    if (!config?.giftBridgeConfig) return undefined;
    return new PublicKey(config.giftBridgeConfig);
  }, [config]);

  return {
    program,
    connection,
    walletPublicKey: anchorWallet?.publicKey,
    giftMint,
    configPda,
    rpcUrl: config?.rpcUrl,
    programId: config?.programId,
    configError: error
  };
}


