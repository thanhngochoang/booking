import { HttpsError } from 'firebase-functions/v2/https';
import { DEV_PROJECT_ID, currentProjectId } from '../config.js';

type Env = Readonly<Record<string, string | undefined>>;

/**
 * Fake payment confirmation (`confirmFakePayment`, `confirmFakeTicketPayment`) lets the payer mark
 * their own payment paid, so it exists only where no real money moves: the emulator, or the dev
 * project. Everywhere else (production, any other project) it is refused.
 */
export function fakePaymentsAllowed(env: Env = process.env): boolean {
  if (env.FUNCTIONS_EMULATOR === 'true') return true;
  return currentProjectId(env) === DEV_PROJECT_ID;
}

/** Call before any read or write of a fake-payment callable. */
export function assertFakePaymentsAllowed(env: Env = process.env): void {
  if (!fakePaymentsAllowed(env)) {
    throw new HttpsError('failed-precondition', 'fake_payments_disabled', { code: 'fake_payments_disabled' });
  }
}
