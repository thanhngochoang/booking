import { readFileSync } from 'node:fs';

/**
 * The emulator-only payout account key from `.secret.local` (test value, committed on purpose).
 * Never use it against a real project: the deployed key lives in Secret Manager.
 */
export function emulatorPayoutKey(): string {
  const text = readFileSync(new URL('../.secret.local', import.meta.url), 'utf8');
  const line = text.split('\n').find((l) => l.startsWith('PAYOUT_ACCOUNT_KEY='));
  if (line === undefined) throw new Error('.secret.local has no PAYOUT_ACCOUNT_KEY');
  return line.slice('PAYOUT_ACCOUNT_KEY='.length).trim();
}
