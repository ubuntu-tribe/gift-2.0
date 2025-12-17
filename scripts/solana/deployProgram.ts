import { execSync } from "child_process";
import * as fs from "fs";
import * as path from "path";

const ROOT = path.resolve(__dirname, "../..");
const ADDRESSES_PATH = path.join(ROOT, "addresses", "addresses.mainnet.json");

const PROGRAM_ID = "EKAeT88SXnVSFT74MVgYG7tfLKuux271UURqN1FQa5Gf";

function run(cmd: string) {
  console.log(`\n$ ${cmd}`);
  const env = {
    ...process.env,
    // Ensure Anchor talks to the right RPC and wallet instead of localhost:8899
    ANCHOR_PROVIDER_URL:
      process.env.SOLANA_RPC_URL ||
      "https://api.mainnet-beta.solana.com",
    ANCHOR_WALLET:
      process.env.SOLANA_RELAYER_KEYPAIR &&
      !process.env.SOLANA_RELAYER_KEYPAIR.startsWith("http")
        ? require("path").resolve(
            ROOT,
            process.env.SOLANA_RELAYER_KEYPAIR
          )
        : process.env.ANCHOR_WALLET,
  };
  execSync(cmd, { stdio: "inherit", cwd: ROOT, env });
}

function main() {
  // Build & deploy the Anchor program
  run("anchor build -p gift_bridge_solana");
  run("anchor deploy -p gift_bridge_solana");

  // Update addresses.mainnet.json with program id
  const raw = fs.readFileSync(ADDRESSES_PATH, "utf8");
  const json = JSON.parse(raw);
  if (!json.solana) json.solana = {};
  json.solana.giftBridgeProgram = PROGRAM_ID;
  fs.writeFileSync(ADDRESSES_PATH, JSON.stringify(json, null, 2), "utf8");

  console.log(
    `\nUpdated solana.giftBridgeProgram in addresses.mainnet.json to ${PROGRAM_ID}`
  );
}

main();


