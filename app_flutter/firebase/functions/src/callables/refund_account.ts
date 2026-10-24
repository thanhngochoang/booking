import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import {
  chooseRefundAccount,
  lookupRefundAccount,
  pendingRefundFor,
  type PendingRefundView,
  type RefundAccountDeps,
  type RefundStatus,
} from '@photobooking/domain';
import { toHttpsError } from './errors.js';
import type { CallableInput } from './get_contact_link.js';

/** The part of a callable request the S22.04 handlers use (a `CallableRequest` fits). */
export type RefundAccountCallableInput = CallableInput;

/**
 * Runs one S22.04 use case for the signed-in caller. Logs only the code of a refusal: never
 * `request.data`, never an account number or a holder name, never the error's message.
 */
async function run<T>(name: string, request: RefundAccountCallableInput, call: (uid: string) => Promise<T>): Promise<T> {
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

/** `{bookingId}` | `{eventId, registrationId}` | `{disputeId}` → the refund waiting for the caller's account, or null. */
export async function handlePendingRefund(
  request: RefundAccountCallableInput,
  deps: RefundAccountDeps,
): Promise<PendingRefundView | null> {
  return run('pendingRefund', request, (uid) => pendingRefundFor(deps, { uid }, request.data));
}

/**
 * `{refundId, bankCode, accountNumber}` → `{holderName, bankName, accountLast4}`: the bank's holder
 * name for another account, kept encrypted on the refund until the customer chooses it.
 */
export async function handleLookupRefundAccount(
  request: RefundAccountCallableInput,
  deps: RefundAccountDeps,
): Promise<{ holderName: string; bankName: string; accountLast4: string }> {
  return run('lookupRefundAccount', request, (uid) => lookupRefundAccount(deps, { uid }, request.data));
}

/** `{refundId, use: 'payer' | 'candidate'}` → `{status}`: sends the waiting refund there (once). */
export async function handleChooseRefundAccount(
  request: RefundAccountCallableInput,
  deps: RefundAccountDeps,
): Promise<{ status: RefundStatus }> {
  return run('chooseRefundAccount', request, (uid) => chooseRefundAccount(deps, { uid }, request.data));
}
