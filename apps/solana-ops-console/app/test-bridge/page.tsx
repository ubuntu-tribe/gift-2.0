"use client";

import React, { useMemo, useState } from "react";
import { WalletMultiButton } from "@solana/wallet-adapter-react-ui";
import { useSolanaBridge } from "../../src/hooks/useSolanaBridge";
import {
  burnForPolygonUI,
  mintFromPolygonUI
} from "../../../../solana/lib/bridgeClient";

function parseAmountToBaseUnits(input: string): bigint {
  const trimmed = input.trim();
  if (!trimmed) {
    throw new Error("Amount is required");
  }
  if (!/^\d+(\.\d+)?$/.test(trimmed)) {
    throw new Error("Invalid amount format");
  }
  const [wholePart, fracPartRaw = ""] = trimmed.split(".");
  const decimals = 18;
  const fracPart = (fracPartRaw + "0".repeat(decimals)).slice(0, decimals);
  const whole = BigInt(wholePart);
  const frac = BigInt(fracPart || "0");
  const base = 10n ** BigInt(decimals);
  return whole * base + frac;
}

function parsePolygonRecipientHex(hex: string): Uint8Array {
  const cleaned = hex.trim().replace(/^0x/, "");
  if (!/^[0-9a-fA-F]{40}$/.test(cleaned)) {
    throw new Error("polygonRecipient must be a 40-character hex string (no 0x prefix)");
  }
  const out = new Uint8Array(20);
  for (let i = 0; i < 20; i++) {
    out[i] = parseInt(cleaned.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

function randomDepositId(): Uint8Array {
  const arr = new Uint8Array(32);
  if (typeof crypto !== "undefined" && "getRandomValues" in crypto) {
    crypto.getRandomValues(arr);
  } else {
    // Fallback (Node scripts should provide their own deposit id)
    for (let i = 0; i < 32; i++) {
      arr[i] = Math.floor(Math.random() * 256);
    }
  }
  return arr;
}

export default function TestBridgePage() {
  const { program, giftMint, configPda, walletPublicKey, rpcUrl, programId, configError } =
    useSolanaBridge();

  const [amountInput, setAmountInput] = useState("");
  const [polygonRecipient, setPolygonRecipient] = useState("");

  const [mintLoading, setMintLoading] = useState(false);
  const [burnLoading, setBurnLoading] = useState(false);

  const [mintResult, setMintResult] = useState<string | null>(null);
  const [burnResult, setBurnResult] = useState<string | null>(null);
  const [mintError, setMintError] = useState<string | null>(null);
  const [burnError, setBurnError] = useState<string | null>(null);

  const isReady = useMemo(
    () => !!program && !!giftMint && !!walletPublicKey,
    [program, giftMint, walletPublicKey]
  );

  const handleMint = async () => {
    setMintError(null);
    setMintResult(null);

    if (!configPda) {
      setMintError("Config not set; run Solana config scripts first.");
      return;
    }
    if (!program || !giftMint || !walletPublicKey) {
      setMintError("Wallet, program, or GIFT mint not ready.");
      return;
    }

    let amount: bigint;
    try {
      amount = parseAmountToBaseUnits(amountInput);
    } catch (e: any) {
      setMintError(e?.message ?? String(e));
      return;
    }

    const depositId = randomDepositId();

    setMintLoading(true);
    try {
      const sig = await mintFromPolygonUI(
        program,
        configPda,
        giftMint,
        walletPublicKey,
        amount,
        depositId
      );
      setMintResult(sig);
    } catch (e: any) {
      setMintError(e?.message ?? String(e));
    } finally {
      setMintLoading(false);
    }
  };

  const handleBurn = async () => {
    setBurnError(null);
    setBurnResult(null);

    if (!configPda) {
      setBurnError("Config not set; run Solana config scripts first.");
      return;
    }
    if (!program || !giftMint || !walletPublicKey) {
      setBurnError("Wallet, program, or GIFT mint not ready.");
      return;
    }

    let amount: bigint;
    try {
      amount = parseAmountToBaseUnits(amountInput);
    } catch (e: any) {
      setBurnError(e?.message ?? String(e));
      return;
    }

    let recipientBytes: Uint8Array;
    try {
      recipientBytes = parsePolygonRecipientHex(polygonRecipient);
    } catch (e: any) {
      setBurnError(e?.message ?? String(e));
      return;
    }

    setBurnLoading(true);
    try {
      const sig = await burnForPolygonUI(
        program,
        configPda,
        giftMint,
        walletPublicKey,
        amount,
        recipientBytes
      );
      setBurnResult(sig);
    } catch (e: any) {
      setBurnError(e?.message ?? String(e));
    } finally {
      setBurnLoading(false);
    }
  };

  return (
    <div>
      <div className="banner-warning">
        <div className="card-title">Mainnet-only bridge test</div>
        <div className="value">
          Mainnet. Only use these functions if the Solana bridge program, Config account,
          and mint authority are fully deployed and configured. Transactions may fail with
          on-chain errors until everything is wired.
        </div>
      </div>

      {configError && (
        <div className="banner-error">
          <div className="card-title">Solana configuration error</div>
          <div className="value">{configError}</div>
        </div>
      )}

      <div className="card">
        <div className="card-title">Connection</div>
        <div className="card-subtitle">
          Confirms you are connected to Solana mainnet via the configured RPC and program
          ID.
        </div>
        <div className="field-row">
          <WalletMultiButton />
        </div>
        <div className="grid">
          <div className="stack">
            <div className="label">RPC URL</div>
            <div className="value mono">{rpcUrl ?? "N/A"}</div>
          </div>
          <div className="stack">
            <div className="label">Program ID</div>
            <div className="value mono">{programId ?? "N/A"}</div>
          </div>
          <div className="stack">
            <div className="label">GIFT mint</div>
            <div className="value mono">{giftMint?.toBase58() ?? "N/A"}</div>
          </div>
          <div className="stack">
            <div className="label">Config PDA</div>
            <div className="value mono">
              {configPda ? configPda.toBase58() : "Not set in addresses.mainnet.json"}
            </div>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="card-title">Test bridge operations</div>
        <div className="card-subtitle">
          These actions call mintFromPolygon and burnForPolygon on the mainnet program.
        </div>

        <div className="field-row">
          <div className="label">Amount (GIFT, human-readable)</div>
          <input
            className="input"
            placeholder="0.1"
            value={amountInput}
            onChange={(e) => setAmountInput(e.target.value)}
          />
          <div className="muted">Converted to smallest units with 18 decimals.</div>
        </div>

        <div className="field-row">
          <div className="label">Polygon recipient (hex, 40 chars, no 0x)</div>
          <input
            className="input"
            placeholder="e.g. deadbeef..."
            value={polygonRecipient}
            onChange={(e) => setPolygonRecipient(e.target.value)}
          />
        </div>

        <div className="button-row">
          <button
            className="button"
            disabled={!isReady || mintLoading}
            onClick={handleMint}
          >
            {mintLoading ? "Calling mintFromPolygon…" : "Call mintFromPolygon (TEST)"}
          </button>
          <button
            className="button secondary"
            disabled={!isReady || burnLoading}
            onClick={handleBurn}
          >
            {burnLoading ? "Calling burnForPolygon…" : "Call burnForPolygon (TEST)"}
          </button>
        </div>

        {!walletPublicKey && (
          <div className="muted" style={{ marginTop: "0.75rem" }}>
            Connect a wallet to enable bridge test calls.
          </div>
        )}
      </div>

      {mintResult && (
        <div className="card">
          <div className="card-title">mintFromPolygon result</div>
          <div className="label">Transaction signature</div>
          <div className="value mono">{mintResult}</div>
        </div>
      )}
      {mintError && (
        <div className="banner-error">
          <div className="card-title">mintFromPolygon error</div>
          <div className="value">{mintError}</div>
        </div>
      )}

      {burnResult && (
        <div className="card">
          <div className="card-title">burnForPolygon result</div>
          <div className="label">Transaction signature</div>
          <div className="value mono">{burnResult}</div>
        </div>
      )}
      {burnError && (
        <div className="banner-error">
          <div className="card-title">burnForPolygon error</div>
          <div className="value">{burnError}</div>
        </div>
      )}
    </div>
  );
}


