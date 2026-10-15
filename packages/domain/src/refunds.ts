import { REFUND_MAX_ATTEMPTS } from './booking_policy.js';
import type { BookingDeps, PaymentGateway } from './booking_ports.js';
import type { Booking, PaymentProvider } from './booking.js';
import { isEscrowRefund, refundMethodOf, type LedgerEntry, type Payment, type Refund } from './escrow.js';
import { revealDestination } from './payer_account.js';
import type { AccountCipher } from './payout_ports.js';
import type { Clock } from './ports.js';

export interface RefundSendDeps {
  readonly gateway: PaymentGateway;
  readonly cipher: AccountCipher;
  readonly clock: Clock;
}

/** Decision 5. At most one gateway call under refund.id; never throws; non-pending → returned unchanged, no call. */
export async function sendRefundOnce(
  d: RefundSendDeps,
  refund: Refund,
  payment: Pick<Payment, 'id' | 'provider'>,
): Promise<Refund> {
  if (refund.status !== 'pending') return refund;
  const at = d.clock.now().toISOString();
  const attempts = refund.attempts + 1;
  const stop = (failureReason: string, n = attempts): Refund => ({
    ...refund,
    status: 'failed',
    manual: true,
    failureReason,
    attempts: n,
    lastAttemptAt: at,
    updatedAt: at,
  });
  if (refund.method === 'bank_transfer' && !refund.destination) return stop('no_destination', refund.attempts); // no call made
  let result: Awaited<ReturnType<PaymentGateway['issueRefund']>>;
  try {
    const destination =
      refund.method === 'bank_transfer' && refund.destination
        ? await revealDestination(d.cipher, refund.destination)
        : undefined;
    result = await d.gateway.issueRefund({
      paymentId: payment.id,
      refundId: refund.id,
      amount: refund.amount,
      provider: payment.provider,
      providerRef: refund.providerRef,
      method: refund.method,
      ...(destination ? { destination } : {}),
    });
  } catch {
    if (attempts >= REFUND_MAX_ATTEMPTS) return stop('gateway_unavailable');
    return { ...refund, attempts, lastAttemptAt: at, updatedAt: at };
  }
  if (!result.success) return stop(result.error ?? 'gateway_refused');
  const providerRef = result.providerRef ?? refund.providerRef;
  if (result.pending) return { ...refund, providerRef, attempts, lastAttemptAt: at, updatedAt: at };
  return { ...refund, status: 'done', manual: false, providerRef, attempts, lastAttemptAt: at, updatedAt: at };
}

/** Decision 6. What to store after an outcome; null = leave the stored refund as it is. */
export function mergeRefundOutcome(stored: Refund, next: Refund): Refund | null {
  if (stored.status === 'done' || stored.status === 'awaiting_account') return null;
  if (stored.status === 'failed' && next.status !== 'done') return null;

  const attempts = Math.max(stored.attempts, next.attempts);
  const outcomeFields: Partial<Refund> = {
    status: next.status,
    manual: next.status === 'done' ? false : next.status === 'failed' ? true : next.manual,
    providerRef: next.providerRef ?? stored.providerRef,
    failureReason: next.status === 'failed' ? next.failureReason : undefined,
    attempts,
    lastAttemptAt: next.lastAttemptAt ?? stored.lastAttemptAt,
    updatedAt: next.updatedAt,
  };

  return {
    ...stored,
    ...outcomeFields,
  };
}

/**
 * Why a booking payment's money went back without a cancellation (#129 Decisions 6–8):
 * - `overpaid_excess`: the part of a transfer above the amount;
 * - `underpaid_expired`: what an under-paid payment had received when it expired or was replaced;
 * - `late_transfer`: a transfer at or after `expiresAt`, or to an expired payment;
 * - `extra_transfer`: a transfer to a payment already paid or refunded;
 * - `late_payment_draft_expired`: the payment was paid but its draft was gone.
 */
export const PAYMENT_REFUND_REASONS = [
  'overpaid_excess',
  'underpaid_expired',
  'late_transfer',
  'extra_transfer',
  'late_payment_draft_expired',
  'provider_not_accepting',
] as const;
export type PaymentRefundReason = (typeof PAYMENT_REFUND_REASONS)[number];

/**
 * A refund of `amount` VND of what `payment` received, for a reason above, and its `refund_issued`
 * ledger entry. It does not change the payment's status (an over-paid payment stays `paid`).
 * `providerRef` is the provider transaction to send the money back from, when there is one.
 */
export function transferRefund(params: {
  readonly payment: Payment;
  readonly refundId: string;
  readonly ledgerEntryId: string;
  readonly amount: number;
  readonly reason: PaymentRefundReason;
  readonly providerRef?: string;
  readonly now: Date;
}): { readonly refund: Refund; readonly ledgerEntry: LedgerEntry } {
  const { payment, refundId, amount, reason, now } = params;
  const at = now.toISOString();
  const refund: Refund = {
    id: refundId,
    paymentId: payment.id,
    subjectType: payment.subjectType,
    amount,
    // The whole of the part being given back.
    percent: 100,
    status: 'pending',
    manual: false,
    // Sent straight back on arrival: this money never entered escrow.
    fromEscrow: false,
    method: refundMethodOf(payment.method),
    attempts: 0,
    lastAttemptAt: at,
    reason,
    providerRef: params.providerRef,
    createdAt: at,
    updatedAt: at,
  };
  const ledgerEntry: LedgerEntry = {
    id: params.ledgerEntryId,
    type: 'refund_issued',
    paymentId: payment.id,
    refundId,
    subjectType: payment.subjectType,
    subjectId: payment.subjectId,
    accountOwnerId: payment.payerId,
    amount: -amount,
    note: reason,
    at,
  };
  return { refund, ledgerEntry };
}

type GatewayRefundResult = Awaited<ReturnType<BookingDeps['gateway']['issueRefund']>>;

/**
 * Records the gateway's answer on the refund: `done`, or `failed` + `manual` for staff.
 * When an escrow refund of a booking payment is `done`, the booking gets `depositRefundedAt` once (in
 * the same transaction), which makes the booking trigger send `refund_done`. A booking that is gone (a
 * late payment whose draft expired) gets nothing: there is no booking to tell the customer about.
 */
async function recordDispatch(deps: BookingDeps, refund: Refund, gatewayResult: GatewayRefundResult): Promise<Refund> {
  const now = deps.clock.now();
  const at = now.toISOString();
  const updatedRefund: Refund = {
    ...refund,
    status: gatewayResult.success ? 'done' : 'failed',
    manual: !gatewayResult.success,
    providerRef: gatewayResult.providerRef ?? refund.providerRef,
    updatedAt: at,
  };

  await deps.store.runTransaction(async (tx) => {
    let booking: Booking | null = null;
    if (updatedRefund.status === 'done' && isEscrowRefund(updatedRefund)) {
      const payment = await tx.getPayment(updatedRefund.paymentId);
      if (payment?.subjectType === 'booking') booking = await tx.getBooking(payment.subjectId);
    }
    await tx.addRefund(updatedRefund);
    if (booking && !booking.depositRefundedAt) {
      // A server marker, not an edit: the version stays so a client's pending change is not refused.
      await tx.setBooking({ ...booking, depositRefundedAt: at, updatedAt: at });
    }
  });

  return updatedRefund;
}

/**
 * Sends a refund to the gateway (`refundId` is the idempotency key) and records the result.
 * Call it outside the transaction that created the refund. A gateway throw propagates.
 */
export async function dispatchRefund(
  deps: BookingDeps,
  refund: Refund,
  provider: PaymentProvider,
): Promise<Refund> {
  const gatewayResult = await deps.gateway.issueRefund({
    paymentId: refund.paymentId,
    refundId: refund.id,
    amount: refund.amount,
    provider,
    providerRef: refund.providerRef,
    method: refund.method,
  });
  return recordDispatch(deps, refund, gatewayResult);
}

/**
 * Sends each refund in turn; a gateway that throws is treated like one that answers
 * `success: false` (the refund becomes `failed` + `manual`, never stays `pending`), and the next
 * refunds still go out. Used by the payment paths, whose own result must not depend on the gateway.
 */
export async function dispatchRefunds(
  deps: BookingDeps,
  items: readonly { readonly refund: Refund; readonly provider: PaymentProvider }[],
): Promise<Refund[]> {
  const done: Refund[] = [];
  for (const { refund, provider } of items) {
    let gatewayResult: GatewayRefundResult;
    try {
      gatewayResult = await deps.gateway.issueRefund({
        paymentId: refund.paymentId,
        refundId: refund.id,
        amount: refund.amount,
        provider,
        providerRef: refund.providerRef,
        method: refund.method,
      });
    } catch (e) {
      gatewayResult = { success: false, error: e instanceof Error ? e.message : 'gateway_error' };
    }
    done.push(await recordDispatch(deps, refund, gatewayResult));
  }
  return done;
}
