#!/usr/bin/env bash
set -euo pipefail

# Helper script to verify the new Polygon core contracts on Polygonscan
# using Foundry (forge) and the addresses in addresses/addresses.mainnet.json.
#
# Requirements:
#   - jq (for JSON parsing)
#   - cast / forge on PATH
#   - Env vars:
#       POLYGON_RPC_URL
#       POLYGONSCAN_API_KEY
#
# Notes:
#   - This script does NOT perform any role wiring or admin calls.
#   - It only derives implementation addresses (for UUPS proxies) and runs
#     forge verify-contract for the implementations and the NFT contract.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ADDR_FILE="$ROOT_DIR/addresses/addresses.mainnet.json"
IMPLEMENTATION_SLOT="0x360894A13BA1A3210667C828492DB98DCA3E2076CC3735A920A3CA505D382BBC"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required but not installed." >&2
  exit 1
fi

read_json() {
  jq -r "$1" "$ADDR_FILE"
}

derive_impl_if_missing() {
  local key="$1"        # e.g. MintingUpgradeable
  local proxy
  local impl

  proxy=$(read_json ".polygon.\"$key\".proxy")
  impl=$(read_json ".polygon.\"$key\".implementation // \"\"")

  if [[ -z "$proxy" || "$proxy" == "null" || "$proxy" == "0x" || "$proxy" == "\"\"" ]]; then
    echo "Skipping $key: proxy address missing in $ADDR_FILE"
    return
  fi

  if [[ -n "$impl" && "$impl" != "null" && "$impl" != "" && "$impl" != "\"\"" && "$impl" != "0x" ]]; then
    echo "$key implementation already set to $impl"
    return
  fi

  echo "Deriving implementation for $key from proxy $proxy ..."
  local raw
  raw=$(cast storage "$proxy" "$IMPLEMENTATION_SLOT")
  # raw is a 32-byte word. Replace the leading 12 bytes (24 hex chars) with 0x.
  local derived
  derived=$(echo "$raw" | sed 's/^0x000000000000000000000000/0x/')

  echo "  -> implementation = $derived"
  jq ".polygon.\"$key\".implementation = \"$derived\"" "$ADDR_FILE" > "$ADDR_FILE.tmp" \
    && mv "$ADDR_FILE.tmp" "$ADDR_FILE"
}

main() {
  echo "Using address file: $ADDR_FILE"

  # 1. Derive implementations for UUPS proxies if missing
  derive_impl_if_missing "MintingUpgradeable"
  derive_impl_if_missing "GiftRedemptionEscrowUpgradeable"
  derive_impl_if_missing "GiftPolygonBridge"

  local mint_impl escrow_impl bridge_impl nft_addr registry_addr
  mint_impl=$(read_json '.polygon.MintingUpgradeable.implementation')
  escrow_impl=$(read_json '.polygon.GiftRedemptionEscrowUpgradeable.implementation')
  bridge_impl=$(read_json '.polygon.GiftPolygonBridge.implementation')
  nft_addr=$(read_json '.polygon.GIFTBarNFTDeferred')
  registry_addr=$(read_json '.polygon.GIFTBatchRegistry')

  echo
  echo "Implementation addresses:"
  echo "  MintingUpgradeable implementation:           $mint_impl"
  echo "  GiftRedemptionEscrowUpgradeable implementation: $escrow_impl"
  echo "  GiftPolygonBridge implementation:             $bridge_impl"
  echo "  GIFTBarNFTDeferred (ERC721):                 $nft_addr"
  echo "  GIFTBatchRegistry (for NFT constructor):     $registry_addr"
  echo

  # 2. Run forge verify-contract from the Polygon contracts project
  cd "$ROOT_DIR/contracts/polygon"

  # MintingUpgradeable implementation
  if [[ -n "$mint_impl" && "$mint_impl" != "null" ]]; then
    echo "Verifying MintingUpgradeable implementation on Polygonscan ..."
    forge verify-contract \
      --chain-id 137 \
      --num-of-optimizations 200 \
      --watch \
      "$mint_impl" \
      "MintingUpgradeable.sol:MintingUpgradeable"
  else
    echo "Skipping MintingUpgradeable: implementation address missing."
  fi

  # GiftRedemptionEscrowUpgradeable implementation
  if [[ -n "$escrow_impl" && "$escrow_impl" != "null" ]]; then
    echo "Verifying GiftRedemptionEscrowUpgradeable implementation on Polygonscan ..."
    forge verify-contract \
      --chain-id 137 \
      --num-of-optimizations 200 \
      --watch \
      "$escrow_impl" \
      "GiftRedemptionEscrowUpgradeable.sol:GiftRedemptionEscrowUpgradeable"
  else
    echo "Skipping GiftRedemptionEscrowUpgradeable: implementation address missing."
  fi

  # GiftPolygonBridge implementation
  if [[ -n "$bridge_impl" && "$bridge_impl" != "null" ]]; then
    echo "Verifying GiftPolygonBridge implementation on Polygonscan ..."
    forge verify-contract \
      --chain-id 137 \
      --num-of-optimizations 200 \
      --watch \
      "$bridge_impl" \
      "GiftPolygonBridge.sol:GiftPolygonBridge"
  else
    echo "Skipping GiftPolygonBridge: implementation address missing."
  fi

  # GIFTBarNFTDeferred (constructor: address registry_)
  if [[ -n "$nft_addr" && "$nft_addr" != "null" ]]; then
    echo "Verifying GIFTBarNFTDeferred (ERC721) on Polygonscan ..."
    if [[ -z "$registry_addr" || "$registry_addr" == "null" ]]; then
      echo "ERROR: GIFTBatchRegistry address missing; cannot encode constructor args for GIFTBarNFTDeferred." >&2
      exit 1
    fi
    constructor_args=$(cast abi-encode "constructor(address)" "$registry_addr")
    forge verify-contract \
      --chain-id 137 \
      --num-of-optimizations 200 \
      --watch \
      "$nft_addr" \
      "GIFTBarNFTDeferred.sol:GIFTBarNFTDeferred" \
      --constructor-args "$constructor_args"
  else
    echo "Skipping GIFTBarNFTDeferred: address missing."
  fi

  echo
  echo "Verification helper completed."
}

main "$@"


