## Project File Structure (High‑Level)

This is a **curated** file tree showing only the important, human‑relevant parts of the repo:

- Top‑level configs
- Polygon contracts and tests
- Solana program and IDL
- Deployment / client scripts
- Key documentation

It intentionally **omits** vendor libraries, build artifacts, and other noise (e.g. `lib/`, `out/`, `node_modules/`).

```text
.
├── Anchor.toml
├── Cargo.toml
├── Cargo.lock
├── README.md
├── filestructure.markdown
├── full system.txt
├── idl/
│   └── gift_bridge_solana.json          # Anchor IDL for Solana bridge program
├── docs/
│   ├── architecture/
│   │   ├── gift-crosschain-architecture.md   # Cross-chain design (Polygon ↔ Solana)
│   │   ├── redemption-flows.md              # Physical redemption flows
│   │   └── The GIFT contract ecosystem.md   # Deep design doc (all contracts)
│   ├── complete-polygon-tests-for-gift-token.md   # Human-readable Polygon test coverage
│   ├── complete-solana-tests-for-gift-bridge.md   # Human-readable Solana test coverage
│   └── Utribe Gift Gold Token Smart Contract Audit.pdf
├── contracts/
│   └── polygon/                       # Foundry project for Polygon (canonical chain)
│       ├── README.md
│       ├── foundry.toml
│       ├── foundry.lock
│       ├── remappings.txt
│       ├── GIFT.sol                   # Main ERC20 token (1 GIFT = 1 mg)
│       ├── GIFTTaxManager.sol         # Tax tiers and fee exclusions
│       ├── GIFTPoR.sol                # Proof-of-Reserve ledger
│       ├── MintingUpgradeable.sol     # Minting engine (PoR + registry)
│       ├── GIFTBarNFTDeferred.sol     # ERC721 bar NFTs
│       ├── GiftRedemptionEscrowUpgradeable.sol  # Escrow for physical redemption
│       ├── GiftPolygonBridge.sol      # Pooled bridge backing GIFT_SOL on Solana
│       ├── Europe/
│       │   └── EUTransferAgent.sol    # EU-region compliance transfer agent
│       ├── src/                       # Shared libs / internal solidity
│       ├── script/                    # Foundry deployment scripts (Polygon)
│       └── test/                      # Foundry tests (~240 tests total)
│           ├── GIFT.t.sol
│           ├── GIFTPoR.t.sol
│           ├── GIFTBatchRegistry.t.sol
│           ├── GIFTTaxManager.t.sol
│           ├── MintingUpgradeable.t.sol
│           ├── GIFTBarNFTDeferred.t.sol
│           ├── GiftRedemptionEscrowUpgradeable.t.sol
│           └── GiftPolygonBridge.t.sol
├── programs/
│   └── gift_bridge_solana/            # Solana bridge program (Anchor)
│       ├── Anchor.toml                # Program-specific Anchor config
│       ├── Cargo.toml
│       └── src/
│           └── lib.rs                 # Anchor program: config, mint_from_polygon, burn_for_polygon
├── scripts/
│   ├── README.md                      # High-level description of scripts
│   ├── polygon/                       # Polygon deployment / wiring scripts (TS stubs)
│   └── solana/
│       ├── createGiftSolMint.ts       # Creates GIFT_SOL mint and mints a test balance
│       ├── deployBridgeProgram.ts     # Calls initializeConfig to set up Config PDA
│       └── bridgeClient.ts            # Example client: mintFromPolygon + burnForPolygon
├── tests/
│   └── solana/
│       └── gift_bridge_solana.test.ts # TS integration tests for Solana bridge
└── package.json                       # JS/TS dev + test dependencies (Solana tests)
```


