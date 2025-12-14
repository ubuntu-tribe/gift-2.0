import fs from "fs";
import path from "path";

export interface RelayerState {
  lastPolygonBlockProcessed: number;
  lastSolanaSlotProcessed: number;
  processedDepositIds: string[]; // hex-encoded deposit ids
  processedBurnSignatures: string[];
}

const STATE_PATH = path.resolve(__dirname, "../state.json");

const DEFAULT_STATE: RelayerState = {
  lastPolygonBlockProcessed: 0,
  lastSolanaSlotProcessed: 0,
  processedDepositIds: [],
  processedBurnSignatures: [],
};

export function loadState(): RelayerState {
  try {
    const raw = fs.readFileSync(STATE_PATH, "utf8");
    const parsed = JSON.parse(raw) as Partial<RelayerState>;
    return {
      ...DEFAULT_STATE,
      ...parsed,
      processedDepositIds: parsed.processedDepositIds ?? [],
      processedBurnSignatures: parsed.processedBurnSignatures ?? [],
    };
  } catch {
    return { ...DEFAULT_STATE };
  }
}

export function saveState(state: RelayerState): void {
  fs.writeFileSync(STATE_PATH, JSON.stringify(state, null, 2), "utf8");
}


