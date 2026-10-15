import { REFUND_MAX_ATTEMPTS } from './booking_policy.js';
import type { BookingDeps, PaymentGateway } from './booking_ports.js';
import type { PaymentProvider } from './booking.js';
import {
  refundMethodOf,
  type LedgerEntry,
  type Payment,
  type Refund,
  type RefundDestination,
  type StoredBankAccount,
} from './escrow.js';
import { revealDestination } from './payer_account.js';
import type { AccountCipher } from './payout_ports.js';
import type { Clock } from './ports.js';
import { bookingRefundHandler } from './refund_subjects.js';

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
  readonly destination?: StoredBankAccount | null;
  readonly providerRef?: string;
  readonly now: Date;
}): { readonly refund: Refund; readonly ledgerEntry: LedgerEntry; readonly payment: Payment } {
  const { payment, refundId, amount, reason, destination, now } = params;
  const at = now.toISOString();
  const method = refundMethodOf(payment.method);
  const dest: RefundDestination | null = destination
    ? { ...destination, source: 'payer' }
    : null;
  const isAwaiting = method === 'bank_transfer' && !dest;

  const refund: Refund = {
    id: refundId,
    paymentId: payment.id,
    subjectType: payment.subjectType,
    amount,
    // The whole of the part being given back.
    percent: 100,
    status: isAwaiting ? 'awaiting_account' : 'pending',
    manual: false,
    // Sent straight back on arrival: this money never entered escrow.
    fromEscrow: false,
    method,
    destination: dest,
    attempts: 0,
    ...(isAwaiting ? {} : { lastAttemptAt: at }),
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
  const updatedPayment: Payment = {
    ...payment,
    refundedAmount: (payment.refundedAmount ?? 0) + amount,
  };
  return { refund, ledgerEntry, payment: updatedPayment };
}

/**
 * Sends a refund to the gateway (`refundId` is the idempotency key) and records the result.
 * Call it outside the transaction that created the refund.
 */
export async function dispatchRefund(
  deps: BookingDeps,
  refund: Refund,
  provider: PaymentProvider,
): Promise<Refund> {
  const next = await sendRefundOnce(deps, refund, { id: refund.paymentId, provider });
  const recorded = await bookingRefundHandler(deps).record(next);
  return recorded ?? next;
}

/**
 * Sends each refund in turn; gateway errors never throw.
 * Used by the payment paths, whose own result must not depend on the gateway.
 */
export async function dispatchRefunds(
  deps: BookingDeps,
  items: readonly { readonly refund: Refund; readonly provider: PaymentProvider }[],
): Promise<Refund[]> {
  const done: Refund[] = [];
  for (const { refund, provider } of items) {
    done.push(await dispatchRefund(deps, refund, provider));
  }
  return done;
}
