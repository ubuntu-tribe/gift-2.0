"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.config = exports.addresses = void 0;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config({ path: path_1.default.resolve(__dirname, "../../.env") });
function loadAddresses() {
    const filePath = path_1.default.resolve(__dirname, "../../addresses/addresses.mainnet.json");
    const raw = fs_1.default.readFileSync(filePath, "utf8");
    const parsed = JSON.parse(raw);
    return parsed;
}
exports.addresses = loadAddresses();
function requireEnv(name) {
    const value = process.env[name];
    if (!value || value.trim() === "") {
        throw new Error(`Missing required env var ${name}`);
    }
    return value.trim();
}
exports.config = {
    polygonRpcUrl: requireEnv("POLYGON_RPC_URL"),
    polygonRelayerPrivateKey: requireEnv("POLYGON_RELAYER_PRIVATE_KEY"),
    solanaRpcUrl: requireEnv("SOLANA_RPC_URL"),
    solanaRelayerKeypair: requireEnv("SOLANA_RELAYER_KEYPAIR"),
};
