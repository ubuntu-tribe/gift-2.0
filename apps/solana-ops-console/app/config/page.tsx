"use client";

import React, { useEffect, useState } from "react";
import { useSolanaBridge } from "../../src/hooks/useSolanaBridge";

type ConfigAccount = {
  admin: any;
  giftMint: any;
  polygonBridge: number[];
  extraMinters: any[];
};

function toHex(bytes: number[]): string {
  return bytes.map((b) => b.toString(16).padStart(2, "0")).join("");
}

export default function ConfigPage() {
  const { program, configPda, configError } = useSolanaBridge();
  const [configAccount, setConfigAccount] = useState<ConfigAccount | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!program || !configPda) return;

    let cancelled = false;
    setLoading(true);
    setError(null);

    (async () => {
      try {
        const acc = (await program.account.config.fetch(
          configPda
        )) as unknown as ConfigAccount;
        if (cancelled) return;
        setConfigAccount(acc);
      } catch (e: any) {
        if (cancelled) return;
        const msg = e?.message ?? String(e);
        if (msg.includes("Account does not exist") || msg.includes("AccountNotFound")) {
          setError(
            "Config account not found at expected PDA. Check on-chain Solana config deployment."
          );
        } else {
          setError(msg);
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [program, configPda]);

  if (configError) {
    return (
      <div className="banner-error">
        <div className="card-title">Solana configuration error</div>
        <div className="value">{configError}</div>
      </div>
    );
  }

  if (!configPda) {
    return (
      <div className="card">
        <div className="card-title">Bridge Config</div>
        <div className="card-subtitle">
          Config PDA is not recorded yet. You must run the Solana config initialization
          scripts before Config is available.
        </div>
      </div>
    );
  }

  return (
    <div>
      <div className="card">
        <div className="card-title">Bridge Config</div>
        <div className="card-subtitle">
          Reads the on-chain Config account at the PDA recorded in addresses.mainnet.json.
        </div>
        <div className="field-row">
          <div className="label">Config PDA</div>
          <div className="value mono">{configPda.toBase58()}</div>
        </div>
        {loading && <div className="muted">Loading config account…</div>}
        {error && (
          <div className="banner-error" style={{ marginTop: "0.75rem" }}>
            <div className="card-title">Error loading config</div>
            <div className="value">{error}</div>
          </div>
        )}

        {configAccount && !error && (
          <div className="grid" style={{ marginTop: "0.75rem" }}>
            <div className="stack">
              <div className="label">Admin</div>
              <div className="value mono">
                {"toBase58" in configAccount.admin
                  ? (configAccount.admin as any).toBase58()
                  : String(configAccount.admin)}
              </div>
            </div>
            <div className="stack">
              <div className="label">GIFT mint</div>
              <div className="value mono">
                {"toBase58" in configAccount.giftMint
                  ? (configAccount.giftMint as any).toBase58()
                  : String(configAccount.giftMint)}
              </div>
            </div>
            <div className="stack">
              <div className="label">Polygon bridge (hex)</div>
              <div className="value mono">{toHex(configAccount.polygonBridge)}</div>
            </div>
          </div>
        )}
      </div>

      {configAccount && configAccount.extraMinters && (
        <div className="card">
          <div className="card-title">Extra minters</div>
          {configAccount.extraMinters.length === 0 && (
            <div className="muted">No extra authorized minters configured.</div>
          )}
          {configAccount.extraMinters.length > 0 && (
            <ul className="mono" style={{ paddingLeft: "1.25rem", margin: 0 }}>
              {configAccount.extraMinters.map((m, idx) => (
                <li key={idx}>
                  {"toBase58" in m ? (m as any).toBase58() : String(m)}
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </div>
  );
}


