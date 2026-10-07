import { HttpsError } from 'firebase-functions/v2/https';
import { DEV_PROJECT_ID, currentProjectId } from '../config.js';

type Env = Readonly<Record<string, string | undefined>>;

/**
 * Fake payment confirmation (`confirmFakePayment`, `confirmFakeTicketPayment`) lets the payer mark
 * their own payment paid, so it exists only where no real money moves: the dev project, or the
 * emulator running a `demo-*` project. Everywhere else (production, any other project) it is
 * refused. `FUNCTIONS_EMULATOR` alone is not enough: it is not a reserved key, so a stray
 * `.env.<project>` could set it on a deployed project; the project id (`GCLOUD_PROJECT`, reserved,
 * set by the platform) must agree.
 */
export function fakePaymentsAllowed(env: Env = process.env): boolean {
  const project = currentProjectId(env);
  if (project === DEV_PROJECT_ID) return true;
  return env.FUNCTIONS_EMULATOR === 'true' && project !== undefined && project.startsWith('demo-');
}

/** Call before any read or write of a fake-payment callable. */
export function assertFakePaymentsAllowed(env: Env = process.env): void {
  if (!fakePaymentsAllowed(env)) {
    throw new HttpsError('failed-precondition', 'fake_payments_disabled', { code: 'fake_payments_disabled' });
  }
}
