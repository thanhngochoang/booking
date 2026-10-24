import { HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import { dispatchDisputeRefund, openDispute, resolveDispute, type DisputeDeps } from '@photobooking/domain';
import { handleCallableError } from './booking.js';

/** The part of a callable request the dispute handlers use (a `CallableRequest` fits). */
export interface DisputeCallableInput {
  readonly auth?: { readonly uid: string; readonly token?: Readonly<Record<string, unknown>> } | undefined;
  readonly data: unknown;
}

function requireUid(request: DisputeCallableInput): string {
  const uid = request.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
  return uid;
}

/**
 * S18.01 (customer): `{disputeId, subjectType, subjectId, eventId?, reason, description, evidencePaths}`
 * → `{disputeId}`. The same id again by the same customer returns it unchanged (Decision 4).
 */
export async function handleOpenDispute(request: DisputeCallableInput, deps: DisputeDeps): Promise<{ disputeId: string }> {
  const uid = requireUid(request);
  try {
    const dispute = await openDispute(deps, uid, request.data);
    return { disputeId: dispute.id };
  } catch (e) {
    handleCallableError('openDispute', e);
  }
}

/**
 * Staff only (ID token claim `staffRole == 'admin'`): `{disputeId, outcome, refundPercent?, note}`
 * → `{disputeId, refundAmount, releaseAmount}`. The refund (if any) is sent after the commit; a send
 * that fails stays with V2's re-send (pending) or staff (failed + manual), the decision stands.
 */
export async function handleResolveDispute(
  request: DisputeCallableInput,
  deps: DisputeDeps,
): Promise<{ disputeId: string; refundAmount: number; releaseAmount: number }> {
  const uid = requireUid(request);
  if (request.auth?.token?.staffRole !== 'admin') {
    logger.info('resolveDispute refused', { code: 'permission_denied' });
    throw new HttpsError('permission-denied', 'permission_denied', { code: 'permission_denied' });
  }
  let resolved: Awaited<ReturnType<typeof resolveDispute>>;
  try {
    resolved = await resolveDispute(deps, uid, request.data);
  } catch (e) {
    handleCallableError('resolveDispute', e);
  }
  const { dispute, refund } = resolved;
  if (refund !== null) {
    try {
      const payment = await deps.store.runTransaction((tx) => tx.getPayment(dispute.paymentId));
      if (payment !== null) await dispatchDisputeRefund(deps, payment, refund);
    } catch {
      logger.error('dispute_refund_send_failed', { disputeId: dispute.id });
    }
  }
  logger.info('dispute_resolved', { disputeId: dispute.id });
  return {
    disputeId: dispute.id,
    refundAmount: dispute.outcome?.refundAmount ?? 0,
    releaseAmount: dispute.outcome?.releaseAmount ?? 0,
  };
}
