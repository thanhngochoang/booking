/**
 * Escrow and Ledger models and math.
 * Enforces Invariants 11 and 12 (data-model/domain-model.md §6).
 */

import type { EscrowStatus, PaymentProvider } from './booking.js';
import { computeRefund } from './booking_policy.js';
import { DomainError } from './errors.js';

export const PAYMENT_STATUSES = [
  'created',
  'paid',
  'failed',
  'refunded',
  'partially_refunded',
] as const;
export type PaymentStatus = (typeof PAYMENT_STATUSES)[number];

export type PaymentSubject = 'booking' | 'event_registration';

export interface Payment {
  readonly id: string;
  readonly subjectType: PaymentSubject;
  readonly subjectId: string;
  readonly payerId: string;
  readonly payeeId: string;
  readonly provider: PaymentProvider;
  readonly amount: number;
  readonly status: PaymentStatus;
  readonly escrowStatus: EscrowStatus;
  readonly idempotencyKey: string;
  readonly providerRef?: string;
  readonly paidAt?: string;
  readonly releasedAt?: string;
  readonly releaseAfter?: string;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export const REFUND_STATUSES = ['pending', 'done', 'failed'] as const;
export type RefundStatus = (typeof REFUND_STATUSES)[number];

export interface Refund {
  readonly id: string;
  readonly paymentId: string;
  readonly amount: number;
  readonly percent: number;
  readonly status: RefundStatus;
  readonly manual: boolean;
  readonly reason?: string;
  readonly providerRef?: string;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export const LEDGER_ENTRY_TYPES = [
  'deposit_received',
  'ticket_received',
  'refund_issued',
  'escrow_released',
  'payout_paid',
  'fee_charged',
  'adjustment',
] as const;
export type LedgerEntryType = (typeof LEDGER_ENTRY_TYPES)[number];

export interface LedgerEntry {
  readonly id: string;
  readonly type: LedgerEntryType;
  readonly paymentId?: string;
  readonly refundId?: string;
  readonly payoutId?: string;
  readonly subjectType?: PaymentSubject;
  readonly subjectId?: string;
  readonly accountOwnerId: string;
  readonly amount: number;
  readonly note?: string;
  readonly at: string;
}

/**
 * Creates a paid deposit Payment and corresponding LedgerEntry (`deposit_received`).
 */
export function createDepositPayment(params: {
  readonly paymentId: string;
  readonly bookingId: string;
  readonly customerId: string;
  readonly photographerId: string;
  readonly provider: PaymentProvider;
  readonly amount: number;
  readonly idempotencyKey: string;
  readonly providerRef?: string;
  readonly ledgerEntryId: string;
  readonly now: Date;
}): { readonly payment: Payment; readonly ledgerEntry: LedgerEntry } {
  const at = params.now.toISOString();
  const payment: Payment = {
    id: params.paymentId,
    subjectType: 'booking',
    subjectId: params.bookingId,
    payerId: params.customerId,
    payeeId: params.photographerId,
    provider: params.provider,
    amount: params.amount,
    status: 'paid',
    escrowStatus: 'held',
    idempotencyKey: params.idempotencyKey,
    providerRef: params.providerRef,
    paidAt: at,
    createdAt: at,
    updatedAt: at,
  };

  const ledgerEntry: LedgerEntry = {
    id: params.ledgerEntryId,
    type: 'deposit_received',
    paymentId: params.paymentId,
    subjectType: 'booking',
    subjectId: params.bookingId,
    accountOwnerId: 'platform_escrow',
    amount: params.amount,
    note: `Deposit for booking ${params.bookingId}`,
    at,
  };

  return { payment, ledgerEntry };
}

/**
 * Applies a refund to an escrow payment (Invariant 12: only held or partially_refunded).
 */
export function applyRefundToPayment(params: {
  readonly payment: Payment;
  readonly refundId: string;
  readonly percent: number;
  readonly ledgerEntryId: string;
  readonly reason?: string;
  readonly now: Date;
}): {
  readonly payment: Payment;
  readonly refund: Refund;
  readonly ledgerEntry: LedgerEntry;
} {
  const { payment, refundId, percent, ledgerEntryId, reason, now } = params;

  // Invariant 12: Only payments in held or partially_refunded escrow can be refunded
  if (payment.escrowStatus !== 'held' && payment.escrowStatus !== 'partially_refunded') {
    throw new DomainError('conflict');
  }

  const refundAmount = computeRefund(payment.amount, percent);
  const at = now.toISOString();

  const isFullRefund = percent === 100 || refundAmount === payment.amount;
  const newStatus: PaymentStatus = isFullRefund ? 'refunded' : 'partially_refunded';
  const newEscrowStatus: EscrowStatus = isFullRefund ? 'refunded' : 'partially_refunded';

  const updatedPayment: Payment = {
    ...payment,
    status: newStatus,
    escrowStatus: newEscrowStatus,
    updatedAt: at,
  };

  const refund: Refund = {
    id: refundId,
    paymentId: payment.id,
    amount: refundAmount,
    percent,
    status: 'pending',
    manual: false,
    reason,
    createdAt: at,
    updatedAt: at,
  };

  const ledgerEntry: LedgerEntry = {
    id: ledgerEntryId,
    type: 'refund_issued',
    paymentId: payment.id,
    refundId,
    subjectType: payment.subjectType,
    subjectId: payment.subjectId,
    accountOwnerId: payment.payerId,
    amount: -refundAmount,
    note: reason,
    at,
  };

  return { payment: updatedPayment, refund, ledgerEntry };
}

/**
 * Releases held escrow payment to the payee (photographer).
 */
export function releaseEscrowPayment(params: {
  readonly payment: Payment;
  readonly refundAmount?: number;
  readonly ledgerEntryId: string;
  readonly now: Date;
}): { readonly payment: Payment; readonly ledgerEntry: LedgerEntry } {
  const { payment, refundAmount = 0, ledgerEntryId, now } = params;

  if (payment.escrowStatus !== 'held' && payment.escrowStatus !== 'partially_refunded') {
    throw new DomainError('conflict');
  }

  const at = now.toISOString();
  const payableAmount = payment.amount - refundAmount;

  const updatedPayment: Payment = {
    ...payment,
    escrowStatus: 'released',
    releasedAt: at,
    updatedAt: at,
  };

  const ledgerEntry: LedgerEntry = {
    id: ledgerEntryId,
    type: 'escrow_released',
    paymentId: payment.id,
    subjectType: payment.subjectType,
    subjectId: payment.subjectId,
    accountOwnerId: payment.payeeId,
    amount: payableAmount,
    note: `Escrow released to payee ${payment.payeeId}`,
    at,
  };

  return { payment: updatedPayment, ledgerEntry };
}

/**
 * Flags a payment as disputed.
 */
export function disputeEscrowPayment(payment: Payment, now: Date): Payment {
  if (payment.escrowStatus !== 'held' && payment.escrowStatus !== 'partially_refunded') {
    throw new DomainError('conflict');
  }

  return {
    ...payment,
    escrowStatus: 'disputed',
    updatedAt: now.toISOString(),
  };
}

/**
 * Verifies Invariant 11:
 * Total payment amount == sum(received) - sum(refund_issued)
 */
export function verifyPaymentLedgerInvariant(
  payment: Payment,
  refunds: readonly Refund[],
  entries: readonly LedgerEntry[],
): boolean {
  let received = 0;
  let refunded = 0;

  for (const entry of entries) {
    if (entry.paymentId === payment.id) {
      if (entry.type === 'deposit_received' || entry.type === 'ticket_received') {
        received += entry.amount;
      } else if (entry.type === 'refund_issued') {
        refunded += Math.abs(entry.amount);
      }
    }
  }

  const totalRefundAmount = refunds.reduce((sum, r) => sum + r.amount, 0);
  return received === payment.amount && refunded === totalRefundAmount;
}
