## Scripts

This folder contains deployment + wiring scripts for both sides of the bridge.

- `scripts/polygon/*`: Polygon (EVM) deployment/wiring scripts (TypeScript stubs)
- `scripts/solana/*`: Solana deployment/client helpers (TypeScript stubs)

These are placeholders for now — wire them up to your preferred toolchain:
- Polygon: `ethers` + `viem` + Foundry `forge script`, or Hardhat-style TS scripts
- Solana: Anchor TS client (`@coral-xyz/anchor`) + `@solana/web3.js`


