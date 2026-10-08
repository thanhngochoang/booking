import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  DomainError,
  lookupPayoutAccountName,
  requestPayoutOtp,
  savePayoutAccount,
  type HolderNameDecision,
  type PayoutAccountDeps,
  type SavedPayoutAccount,
} from '@photobooking/domain';
import { fakeOtpAllowed } from '../infra/otp.js';
import { toHttpsError } from './errors.js';
import type { CallableInput } from './get_contact_link.js';

type Env = Readonly<Record<string, string | undefined>>;

/** The part of a callable request the payout account handlers use (no token claim is read). */
export type PayoutAccountCallableInput = CallableInput;

/**
 * Runs one S06.06 use case for the signed-in caller. Logs only the code of a refusal: never
 * `request.data`, never a number or a name, never the error's message (10b rule).
 */
async function run<T>(
  name: string,
  request: PayoutAccountCallableInput,
  call: (uid: string) => Promise<T>,
): Promise<T> {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  try {
    return await call(uid);
  } catch (e) {
    const error = toHttpsError(e);
    if (error.code === 'internal') logger.error(`${name} failed`, { code: error.message });
    else logger.info(`${name} refused`, { code: error.message });
    throw error;
  }
}

/**
 * `{bankCode, accountNumber}` → `{decision, holderName, verifiedName}`. Photographers only; 20
 * lookups per Vietnam day (the 21st is `limit_exceeded`), so it cannot read strangers' names.
 */
export async function handleLookupPayoutAccountName(
  request: PayoutAccountCallableInput,
  deps: PayoutAccountDeps,
): Promise<{ decision: HolderNameDecision; holderName: string | null; verifiedName: string | null }> {
  return run('lookupPayoutAccountName', request, (uid) => lookupPayoutAccountName(deps, { uid }, request.data));
}

/**
 * `{bankCode, accountNumber}` → `{phoneLast4, expiresInSeconds, resendInSeconds}`: a code for a
 * change of account. Only where the fake OTP channel exists (Decision 10): elsewhere
 * `not_eligible` before the use case runs, so no send is counted against the caller.
 */
export async function handleRequestPayoutOtp(
  request: PayoutAccountCallableInput,
  deps: PayoutAccountDeps,
  env: Env = process.env,
): Promise<{ phoneLast4: string; expiresInSeconds: number; resendInSeconds: number }> {
  return run('requestPayoutOtp', request, (uid) => {
    if (!fakeOtpAllowed(env)) throw new DomainError('not_eligible');
    return requestPayoutOtp(deps, { uid }, request.data);
  });
}

/**
 * `{bankCode, accountNumber, otpCode?}` → `{accountId, accountLast4, activeFrom, nameStatus}`
 * (v2: the bank gives the holder name, a change needs an OTP and starts 72 hours later).
 */
export async function handleSavePayoutAccount(
  request: PayoutAccountCallableInput,
  deps: PayoutAccountDeps,
): Promise<SavedPayoutAccount> {
  return run('savePayoutAccount', request, (uid) => savePayoutAccount(deps, { uid }, request.data));
}
