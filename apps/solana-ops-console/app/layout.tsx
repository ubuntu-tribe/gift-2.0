import React, { ReactNode } from "react";
import "@solana/wallet-adapter-react-ui/styles.css";
import "./globals.css";
import { WalletContextProvider } from "../src/components/WalletContextProvider";

export const metadata = {
  title: "Solana Ops Console",
  description: "Internal Solana bridge operations console for GIFT"
};

export default function RootLayout({
  children
}: {
  children: ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <WalletContextProvider>
          <div className="app-root">
            <header className="app-header">
              <div className="app-header-inner">
                <div className="app-title">GIFT Solana Ops Console</div>
                <nav className="app-nav">
                  <a href="/" className="app-nav-link">
                    Dashboard
                  </a>
                  <a href="/config" className="app-nav-link">
                    Config
                  </a>
                  <a href="/test-bridge" className="app-nav-link">
                    Test Bridge
                  </a>
                </nav>
              </div>
            </header>
            <main className="app-main">{children}</main>
          </div>
        </WalletContextProvider>
      </body>
    </html>
  );
}


