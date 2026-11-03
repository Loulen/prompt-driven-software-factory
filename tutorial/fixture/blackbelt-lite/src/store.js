import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export const SEED_FILE = fileURLToPath(new URL('../data/seed.json', import.meta.url));
const DEFAULT_STATE_FILE = fileURLToPath(new URL('../.blackbelt-state.json', import.meta.url));

// Where the CLI keeps its state: $BLACKBELT_STATE, else .blackbelt-state.json at the project root.
export function stateFile(env = process.env) {
  return env.BLACKBELT_STATE || DEFAULT_STATE_FILE;
}

// The current state; the seed when no state was saved yet.
export function loadState(file = stateFile()) {
  return JSON.parse(readFileSync(existsSync(file) ? file : SEED_FILE, 'utf8'));
}

export function saveState(state, file = stateFile()) {
  writeFileSync(file, `${JSON.stringify(state, null, 2)}\n`);
}

export function resetState(file = stateFile()) {
  saveState(JSON.parse(readFileSync(SEED_FILE, 'utf8')), file);
}
