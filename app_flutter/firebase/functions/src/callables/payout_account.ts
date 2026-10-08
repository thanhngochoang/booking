import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { savePayoutAccount, type PayoutAccountDeps, type SavedPayoutAccount } from '@photobooking/domain';
import { toHttpsError } from './errors.js';
import type { CallableInput } from './get_contact_link.js';

/** A callable request with the ID token's `auth_time` (seconds since the epoch). */
export interface PayoutAccountCallableInput extends Omit<CallableInput, 'auth'> {
  readonly auth?: { readonly uid: string; readonly token?: { readonly auth_time?: number } } | undefined;
}

/**
 * `{bankCode, accountNumber, otpCode?}` → `{accountId, accountLast4, activeFrom, nameStatus}`
 * (v2: the bank gives the holder name, a change needs an OTP; `auth_time` is no longer read). Logs
 * only the code of a refusal: never `request.data`, never a number, never the error's message.
 */
export async function handleSavePayoutAccount(
  request: PayoutAccountCallableInput,
  deps: PayoutAccountDeps,
): Promise<SavedPayoutAccount> {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  try {
    return await savePayoutAccount(deps, { uid }, request.data);
  } catch (e) {
    const error = toHttpsError(e);
    if (error.code === 'internal') logger.error('savePayoutAccount failed', { code: error.message });
    else logger.info('savePayoutAccount refused', { code: error.message });
    throw error;
  }
}
