"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadState = loadState;
exports.saveState = saveState;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const STATE_PATH = path_1.default.resolve(__dirname, "../state.json");
const DEFAULT_STATE = {
    lastPolygonBlockProcessed: 0,
    lastSolanaSlotProcessed: 0,
    processedDepositIds: [],
    processedBurnSignatures: [],
};
function loadState() {
    var _a, _b;
    try {
        const raw = fs_1.default.readFileSync(STATE_PATH, "utf8");
        const parsed = JSON.parse(raw);
        return {
            ...DEFAULT_STATE,
            ...parsed,
            processedDepositIds: (_a = parsed.processedDepositIds) !== null && _a !== void 0 ? _a : [],
            processedBurnSignatures: (_b = parsed.processedBurnSignatures) !== null && _b !== void 0 ? _b : [],
        };
    }
    catch {
        return { ...DEFAULT_STATE };
    }
}
function saveState(state) {
    fs_1.default.writeFileSync(STATE_PATH, JSON.stringify(state, null, 2), "utf8");
}
