import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { savePayoutAccount, type PayoutAccountDeps } from '@photobooking/domain';
import { toHttpsError } from './errors.js';
import type { CallableInput } from './get_contact_link.js';

/** A callable request with the ID token's `auth_time` (seconds since the epoch). */
export interface PayoutAccountCallableInput extends Omit<CallableInput, 'auth'> {
  readonly auth?: { readonly uid: string; readonly token?: { readonly auth_time?: number } } | undefined;
}

/**
 * `{bankCode, accountNumber, holderName}` → `{accountId, accountLast4}`. Logs only the code of a
 * refusal: never `request.data`, never a number, never the error's message.
 */
export async function handleSavePayoutAccount(
  request: PayoutAccountCallableInput,
  deps: PayoutAccountDeps,
): Promise<{ accountId: string; accountLast4: string }> {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  const seconds = request.auth?.token?.auth_time;
  const authTime = typeof seconds === 'number' && Number.isFinite(seconds) ? new Date(seconds * 1000) : null;
  try {
    return await savePayoutAccount(deps, { uid, authTime }, request.data);
  } catch (e) {
    const error = toHttpsError(e);
    if (error.code === 'internal') logger.error('savePayoutAccount failed', { code: error.message });
    else logger.info('savePayoutAccount refused', { code: error.message });
    throw error;
  }
}
