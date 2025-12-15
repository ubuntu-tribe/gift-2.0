"use client";

import React, { useEffect, useState } from "react";
import { PublicKey } from "@solana/web3.js";
import { getAssociatedTokenAddress } from "@solana/spl-token";
import { WalletMultiButton } from "@solana/wallet-adapter-react-ui";
import { useSolanaBridge } from "../src/hooks/useSolanaBridge";

function formatGiftAmount(rawAmount: bigint): string {
  const decimals = 18n;
  const base = 10n ** decimals;
  const whole = rawAmount / base;
  const frac = rawAmount % base;
  const fracStr = frac.toString().padStart(Number(decimals), "0").replace(/0+$/, "");
  return fracStr.length > 0 ? `${whole.toString()}.${fracStr}` : whole.toString();
}

async function fetchGiftBalance(
  connection: any,
  wallet: PublicKey,
  giftMint: PublicKey
): Promise<{ balance: string | null; noAccount: boolean }> {
  const ata = await getAssociatedTokenAddress(giftMint, wallet);
  const info = await connection.getAccountInfo(ata);
  if (!info) {
    return { balance: null, noAccount: true };
  }

  const balanceResp = await connection.getTokenAccountBalance(ata);
  const raw = BigInt(balanceResp.value.amount);
  return { balance: formatGiftAmount(raw), noAccount: false };
}

export default function DashboardPage() {
  const { connection, walletPublicKey, giftMint, rpcUrl, programId, configError } =
    useSolanaBridge();

  const [giftBalance, setGiftBalance] = useState<string | null>(null);
  const [noGiftAccount, setNoGiftAccount] = useState(false);
  const [balanceError, setBalanceError] = useState<string | null>(null);
  const [loadingBalance, setLoadingBalance] = useState(false);

  useEffect(() => {
    if (!connection || !walletPublicKey || !giftMint) {
      setGiftBalance(null);
      setNoGiftAccount(false);
      setBalanceError(null);
      return;
    }

    let cancelled = false;
    setLoadingBalance(true);
    setBalanceError(null);

    (async () => {
      try {
        const { balance, noAccount } = await fetchGiftBalance(
          connection,
          walletPublicKey,
          giftMint
        );
        if (cancelled) return;
        setNoGiftAccount(noAccount);
        setGiftBalance(balance);
      } catch (e: any) {
        if (cancelled) return;
        setBalanceError(e?.message ?? String(e));
      } finally {
        if (!cancelled) {
          setLoadingBalance(false);
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [connection, walletPublicKey, giftMint]);

  const showConfigBanner =
    !configError && (!programId || !giftMint || !rpcUrl);

  return (
    <div>
      {configError && (
        <div className="banner-error">
          <div className="card-title">Solana configuration error</div>
          <div className="value">{configError}</div>
        </div>
      )}

      {showConfigBanner && (
        <div className="banner-error">
          <div className="card-title">Solana addresses not fully configured</div>
          <div className="value">
            Solana addresses not fully configured. Update addresses.mainnet.json and
            your .env, then reload this page.
          </div>
        </div>
      )}

      <div className="card">
        <div className="card-title">Wallet</div>
        <div className="card-subtitle">
          Connect an admin wallet on Solana mainnet (e.g. Phantom).
        </div>
        <div className="field-row">
          <WalletMultiButton />
        </div>
        <div className="field-row">
          <div className="label">Connected wallet</div>
          <div className="value mono">
            {walletPublicKey ? walletPublicKey.toBase58() : "Not connected"}
          </div>
        </div>
        <div className="grid">
          <div>
            <div className="label">Current RPC URL</div>
            <div className="value mono">{rpcUrl ?? "N/A"}</div>
          </div>
          <div>
            <div className="label">Program ID</div>
            <div className="value mono">{programId ?? "N/A"}</div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="card-title">GIFT balance (Solana)</div>
        <div className="card-subtitle">
          Reads the GIFT SPL token balance for the connected wallet on Solana mainnet.
        </div>

        {!walletPublicKey && (
          <div className="muted">Connect a wallet to view GIFT balance.</div>
        )}

        {walletPublicKey && !giftMint && (
          <div className="muted">
            GIFT mint is not configured. Update addresses.mainnet.json.
          </div>
        )}

        {walletPublicKey && giftMint && (
          <>
            {loadingBalance && <div className="muted">Loading balance…</div>}
            {!loadingBalance && noGiftAccount && (
              <div className="muted">
                No GIFT token account for this wallet yet.
              </div>
            )}
            {!loadingBalance && !noGiftAccount && giftBalance && (
              <div className="value">
                <span className="section-title">Balance</span>{" "}
                <span className="mono">{giftBalance} GIFT</span>
              </div>
            )}
            {balanceError && (
              <div className="banner-error" style={{ marginTop: "0.75rem" }}>
                <div className="card-title">Error loading balance</div>
                <div className="value">{balanceError}</div>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}


