"use client";

import React, { ReactNode, useMemo } from "react";
import { ConnectionProvider, WalletProvider } from "@solana/wallet-adapter-react";
import { WalletModalProvider } from "@solana/wallet-adapter-react-ui";
import { PhantomWalletAdapter } from "@solana/wallet-adapter-wallets";
import { tryLoadMainnetConfig } from "../config";

type Props = {
  children: ReactNode;
};

export function WalletContextProvider({ children }: Props) {
  const { config, error } = useMemo(() => tryLoadMainnetConfig(), []);

  const wallets = useMemo(
    () => [
      // Primary expected wallet is Phantom; others can be added here if needed.
      new PhantomWalletAdapter()
    ],
    []
  );

  if (error) {
    return (
      <div className="app-root">
        <main className="app-main">
          <div className="banner-error">
            <div className="card-title">Solana configuration error</div>
            <div className="value">{error}</div>
          </div>
        </main>
      </div>
    );
  }

  return (
    <ConnectionProvider endpoint={config.rpcUrl}>
      <WalletProvider wallets={wallets} autoConnect>
        <WalletModalProvider>{children}</WalletModalProvider>
      </WalletProvider>
    </ConnectionProvider>
  );
}


