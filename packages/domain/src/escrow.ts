/**
 * Escrow and Ledger models and math.
 * Enforces Invariants 11 and 12 (data-model/domain-model.md §6).
 */

import type { EscrowStatus, PaymentProvider } from './booking.js';
import { computeRefund } from './booking_policy.js';
import { DomainError } from './errors.js';

/**
 * `expired`: nobody paid in time (or the QR was replaced). `needs_review` is reserved for staff
 * (S23.02); no code path writes it on a Payment yet.
 */
export const PAYMENT_STATUSES = [
  'created',
  'paid',
  'expired',
  'needs_review',
  'refunded',
  'partially_refunded',
] as const;
export type PaymentStatus = (typeof PAYMENT_STATUSES)[number];

/** Methods a customer can pay with today. */
export const PAYMENT_METHODS = ['bank_qr', 'momo', 'zalopay'] as const;
/** Card methods are in the product plan but never accepted yet. */
export const RESERVED_PAYMENT_METHODS = ['domestic_card', 'intl_card'] as const;
export type PaymentMethod = (typeof PAYMENT_METHODS)[number];

export type PaymentSubject = 'booking' | 'event_registration';

export interface Payment {
  readonly id: string;
  readonly subjectType: PaymentSubject;
  readonly subjectId: string;
  /** Ticket payments only: the event of the registration (`subjectId`), for the event's escrow sweeps. */
  readonly eventId?: string;
  readonly payerId: string;
  readonly payeeId: string;
  readonly provider: PaymentProvider;
  readonly amount: number;
  readonly status: PaymentStatus;
  readonly escrowStatus: EscrowStatus;
  readonly idempotencyKey: string;
  readonly providerRef?: string;
  /** Checkout payments: how the customer pays. */
  readonly method?: PaymentMethod;
  /** Bank QR: the memo to type, `PB XXXXXX` (see payment_code.ts). */
  readonly transferCode?: string;
  /** ISO-8601 UTC; transfers received at or after it are refunded. */
  readonly expiresAt?: string;
  /** Sum of the transfers received so far, VND (can differ from `amount` while under-paid or over-paid). */
  readonly receivedAmount?: number;
  readonly paidAt?: string;
  readonly releasedAt?: string;
  readonly releaseAfter?: string;
  /** Set by openDispute; server-only. */
  readonly dispute?: { readonly reason: string; readonly openedAt: string } | null;
  /** Current payout batch; cleared when that batch fails. */
  readonly payoutId?: string | null;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export const REFUND_STATUSES = ['pending', 'done', 'failed'] as const;
export type RefundStatus = (typeof REFUND_STATUSES)[number];

export interface Refund {
  readonly id: string;
  readonly paymentId: string;
  /** The payment's subject (the event clock re-sends ticket refunds left `pending`). */
  readonly subjectType?: PaymentSubject;
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
  'payment_received',
  'ticket_received',
  'refund_issued',
  'escrow_released',
  'payout_paid',
  'fee_charged',
  'adjustment',
] as const;
export type LedgerEntryType = (typeof LEDGER_ENTRY_TYPES)[number];

/** Old name of `payment_received`, still found in dev data; readers count it, nothing writes it. */
export const LEGACY_PAYMENT_RECEIVED_TYPE = 'deposit_received';

/**
 * Refund reasons that give back money which was never part of the payment's amount
 * (the over-payment, the under-payment of an expired QR, a late or duplicate transfer).
 */
export const EXCESS_REFUND_REASONS = [
  'overpaid_excess',
  'underpaid_expired',
  'late_transfer',
  'extra_transfer',
] as const;

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
 * Creates a paid Payment for the booking and its LedgerEntry (`payment_received`).
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
    type: 'payment_received',
    paymentId: params.paymentId,
    subjectType: 'booking',
    subjectId: params.bookingId,
    accountOwnerId: 'platform_escrow',
    amount: params.amount,
    note: `Payment for booking ${params.bookingId}`,
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
    subjectType: payment.subjectType,
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
 * Verifies Invariant 11 for one payment:
 * - ledger refunds add up to the refund records;
 * - an `expired` payment received nothing net (every transfer was given back);
 * - any other payment: sum(received) minus the refunds of excess money (`EXCESS_REFUND_REASONS`)
 *   equals `payment.amount`. Refunds for a cancellation are not counted here.
 * Both `payment_received` and the legacy `deposit_received` count as received.
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
      const type: string = entry.type;
      if (type === 'payment_received' || type === LEGACY_PAYMENT_RECEIVED_TYPE || type === 'ticket_received') {
        received += entry.amount;
      } else if (type === 'refund_issued') {
        refunded += Math.abs(entry.amount);
      }
    }
  }

  const totalRefundAmount = refunds.reduce((sum, r) => sum + r.amount, 0);
  if (refunded !== totalRefundAmount) return false;

  if (payment.status === 'expired') {
    return received === refunded;
  }
  const excessRefunded = refunds
    .filter((r) => r.reason !== undefined && (EXCESS_REFUND_REASONS as readonly string[]).includes(r.reason))
    .reduce((sum, r) => sum + r.amount, 0);
  return received - excessRefunded === payment.amount;
}
