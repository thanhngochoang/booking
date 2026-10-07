/**
 * Dispatch refund to payment gateway and update refund status.
 */

import type { BookingDeps } from './booking_ports.js';
import type { PaymentProvider } from './booking.js';
import type { LedgerEntry, Payment, Refund } from './escrow.js';

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

/**
 * Sends a refund to the gateway (`refundId` is the idempotency key) and records the result.
 * Call it outside the transaction that created the refund.
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
  });

  const now = deps.clock.now();
  const updatedRefund: Refund = {
    ...refund,
    status: gatewayResult.success ? 'done' : 'failed',
    manual: !gatewayResult.success,
    providerRef: gatewayResult.providerRef ?? refund.providerRef,
    updatedAt: now.toISOString(),
  };

  await deps.store.runTransaction(async (tx) => {
    await tx.addRefund(updatedRefund);
  });

  return updatedRefund;
}
