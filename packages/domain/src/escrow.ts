/**
 * Escrow and Ledger models and math.
 * Enforces Invariants 11 and 12 (data-model/domain-model.md §6).
 */

import type { EscrowStatus, PaymentProvider } from './booking.js';
import type { GatewayInstructions } from './booking_ports.js';
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
/** True for a method a customer can pay with today (reserved card methods are false). */
export const isPaymentMethod = (v: unknown): v is PaymentMethod =>
  typeof v === 'string' && (PAYMENT_METHODS as readonly string[]).includes(v);

/**
 * `verification_fee`: the S21 fee, platform revenue (payee `platform`), never earnings or payouts (#203).
 * `instant_request`: a Chụp ngay request (#202); payee `''` until a photographer is assigned.
 */
export const PAYMENT_SUBJECTS = ['booking', 'event_registration', 'verification_fee', 'instant_request'] as const;
export type PaymentSubject = (typeof PAYMENT_SUBJECTS)[number];
export const isPaymentSubject = (v: unknown): v is PaymentSubject =>
  typeof v === 'string' && (PAYMENT_SUBJECTS as readonly string[]).includes(v);

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
  /**
   * VND counted toward `amount` so far: the running total while under-paid, `amount` once paid.
   * Money sent straight back on arrival (a late or extra transfer, the excess over `amount`) is not
   * counted; the ledger has every transfer.
   */
  readonly receivedAmount?: number;
  /** Gateway instructions as answered when opened (server-only). */
  readonly instructions?: GatewayInstructions;
  readonly paidAt?: string;
  readonly releasedAt?: string;
  readonly releaseAfter?: string;
  /**
   * The last dispute on this payment (S18, `openDispute`); server-only, kept after resolution as history.
   * `milestone`: the frozen milestone (its own status is `disputed`); null for a payment without
   * milestones, which is frozen whole and keeps `prevEscrowStatus` to restore on resolution.
   * Rows from before S18 carry only `reason` (free text) and `openedAt`.
   */
  readonly dispute?: PaymentDispute | null;
  /** Current payout batch; cleared when that batch fails. */
  readonly payoutId?: string | null;
  /** Payer account info captured from notification (server-only). */
  readonly payer?: StoredBankAccount | null;
  /** VND refunded so far across all refunds on this payment. */
  readonly refundedAmount?: number;
  /** Two-layer booking milestones (fake rails): shoot and delivery. */
  readonly milestones?: readonly import('./milestones.js').PaymentMilestone[];
  /** VND of released, unbatched milestones available for payout. */
  readonly payableAmount?: number;
  /**
   * The platform fee rate this payment's payout takes, basis points (Decision 6 of #140/#202: an
   * `instant_request` payment snapshots its request's `platformFeeBp`); absent → the payout policy's.
   */
  readonly feeBp?: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export interface PaymentDispute {
  readonly reason: string;
  readonly openedAt: string;
  readonly disputeId?: string;
  readonly milestone?: import('./milestones.js').MilestoneKind | null;
  readonly prevEscrowStatus?: 'held' | 'partially_refunded';
}

export const REFUND_STATUSES = ['awaiting_account', 'pending', 'done', 'failed'] as const;
export type RefundStatus = (typeof REFUND_STATUSES)[number];

export const REFUND_METHODS = ['gateway', 'bank_transfer'] as const;

/** S22.04 (#141 Decision 5): hours a waiting policy refund with a payer account gives the customer to choose. */
export const REFUND_ACCOUNT_CONFIRM_HOURS = 24;
export type RefundMethod = (typeof REFUND_METHODS)[number];

export function refundMethodOf(method: PaymentMethod | undefined): RefundMethod {
  return method === 'bank_qr' ? 'bank_transfer' : 'gateway';
}

export interface StoredBankAccount {
  readonly bankCode: string;
  readonly bankName: string;
  readonly accountNumberEnc: string;
  readonly accountLast4: string;
  readonly holderName: string;
}

export type RefundDestination = StoredBankAccount & { readonly source: 'payer' | 'customer' };

export interface Refund {
  readonly id: string;
  readonly paymentId: string;
  /** The payment's subject (the event clock re-sends ticket refunds left `pending`). */
  readonly subjectType?: PaymentSubject;
  readonly amount: number;
  readonly percent: number;
  readonly status: RefundStatus;
  readonly manual: boolean;
  /**
   * True when the money came out of what escrow held for the payee: a cancellation, decline,
   * expiry or dispute share, or a paid payment whose draft was gone (`applyRefundToPayment`).
   * False for money sent straight back on arrival, which never entered escrow (`transferRefund`:
   * the excess of an over-transfer, a second or late transfer, an under-paid payment that expired).
   * Release, payouts and earnings subtract only escrow refunds. Never derived from `reason`.
   * Rows stored before the field existed are read as true (see `isEscrowRefund`).
   */
  readonly fromEscrow: boolean;
  readonly method: RefundMethod;
  readonly destination?: RefundDestination | null;
  /**
   * `awaiting_account` with a payer destination (#141 Decision 5): the 24-hour default sends it to
   * the payer at this instant (`confirmDueRefundAccounts`); null when there is no payer (waits).
   */
  readonly confirmBy?: string | null;
  /**
   * Another account the customer looked up on S22.04 (`lookupRefundAccount`, number encrypted),
   * committed by `chooseRefundAccount({use: 'candidate'})`; cleared when the refund leaves
   * `awaiting_account`. Server-only, never in a customer-readable document.
   */
  readonly candidate?: StoredBankAccount | null;
  readonly attempts: number;
  readonly lastAttemptAt?: string;
  readonly failureReason?: string;
  readonly reason?: string;
  readonly providerRef?: string;
  readonly createdAt: string;
  readonly updatedAt: string;
}

/**
 * A payment the customer has actually paid (and that still holds some of it): only these are
 * scheduled for release, disputed or shown as earnings. A `created` QR payment already has escrow
 * `held` from creation but is not money yet.
 */
export const isSettledPayment = (p: Pick<Payment, 'status'>): boolean =>
  p.status === 'paid' || p.status === 'partially_refunded';

/** True unless the refund is marked as money that never entered escrow (a missing marker counts). */
export const isEscrowRefund = (r: Pick<Refund, 'fromEscrow'> | { readonly fromEscrow?: boolean }): boolean =>
  r.fromEscrow !== false;

/** What escrow gave back to the payer: the sum of the escrow refunds (release subtracts this). */
export function escrowRefundedTotal(refunds: readonly (Pick<Refund, 'amount'> & { readonly fromEscrow?: boolean })[]): number {
  return refunds.reduce((sum, r) => (isEscrowRefund(r) ? sum + r.amount : sum), 0);
}

export const LEDGER_ENTRY_TYPES = [
  'payment_received',
  'ticket_received',
  'refund_issued',
  'escrow_released',
  'payout_paid',
  'fee_charged',
  'adjustment',
  /** Tax withheld from a paid-out payment (negative, like `payout_paid`). */
  'tax_withheld',
  /** Platform commission kept from a paid-out payment (negative; only when > 0). */
  'platform_fee',
] as const;
export type LedgerEntryType = (typeof LEDGER_ENTRY_TYPES)[number];

/** Old name of `payment_received`, still found in dev data; readers count it, nothing writes it. */
export const LEGACY_PAYMENT_RECEIVED_TYPE = 'deposit_received';

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
 * Without `amount`: `percent` of `payment.amount`. With `amount` (a dispute outcome): exactly that,
 * an integer from 1 to what escrow still holds (`payment.amount − escrowRefunded`, where
 * `escrowRefunded` is `escrowRefundedTotal` of the payment's refunds); the payment is fully refunded
 * once escrow refunds reach `payment.amount`. `percent` is then only recorded on the refund.
 *
 * `waitForAccount` (#141 Decision 5: a customer cancel, decline, expired request, event cancel or
 * dispute outcome): a bank-transfer refund starts `awaiting_account` (the customer confirms the
 * account on S22.04), prefilled with the payer and `confirmBy = now + 24 h`, or without a payer and
 * no `confirmBy`. Without it (late payments, Chụp ngay, the S21 fee) V2's rule stands: sent to the
 * payer at once, waiting only when there is no payer.
 */
export function applyRefundToPayment(params: {
  readonly payment: Payment;
  readonly refundId: string;
  readonly percent: number;
  readonly ledgerEntryId: string;
  readonly reason?: string;
  readonly now: Date;
  readonly waitForAccount?: boolean;
} & (
  | { readonly amount?: undefined; readonly escrowRefunded?: undefined }
  | { readonly amount: number; readonly escrowRefunded: number }
)): {
  readonly payment: Payment;
  readonly refund: Refund;
  readonly ledgerEntry: LedgerEntry;
} {
  const { payment, refundId, percent, ledgerEntryId, reason, now } = params;

  // Invariant 12: Only payments in held or partially_refunded escrow can be refunded
  if (payment.escrowStatus !== 'held' && payment.escrowStatus !== 'partially_refunded') {
    throw new DomainError('conflict');
  }

  let refundAmount: number;
  let isFullRefund: boolean;
  if (params.amount === undefined) {
    refundAmount = computeRefund(payment.amount, percent);
    isFullRefund = percent === 100 || refundAmount === payment.amount;
  } else {
    const before = params.escrowRefunded;
    const held = payment.amount - before;
    if (!Number.isSafeInteger(before) || before < 0 || !Number.isSafeInteger(params.amount) || params.amount < 1 || params.amount > held) {
      throw new DomainError('invalid_argument');
    }
    refundAmount = params.amount;
    isFullRefund = before + refundAmount === payment.amount;
  }
  const at = now.toISOString();

  const newStatus: PaymentStatus = isFullRefund ? 'refunded' : 'partially_refunded';
  const newEscrowStatus: EscrowStatus = isFullRefund ? 'refunded' : 'partially_refunded';

  const method = refundMethodOf(payment.method);
  const destination: RefundDestination | null =
    payment.payer ? { ...payment.payer, source: 'payer' } : null;
  const isAwaiting = method === 'bank_transfer' && (!destination || params.waitForAccount === true);
  const confirmBy =
    isAwaiting && destination && params.waitForAccount === true
      ? new Date(now.getTime() + REFUND_ACCOUNT_CONFIRM_HOURS * 3_600_000).toISOString()
      : null;

  const updatedPayment: Payment = {
    ...payment,
    status: newStatus,
    escrowStatus: newEscrowStatus,
    refundedAmount: (payment.refundedAmount ?? 0) + refundAmount,
    updatedAt: at,
  };

  const refund: Refund = {
    id: refundId,
    paymentId: payment.id,
    subjectType: payment.subjectType,
    amount: refundAmount,
    percent,
    status: isAwaiting ? 'awaiting_account' : 'pending',
    manual: false,
    fromEscrow: true,
    method,
    destination,
    ...(confirmBy !== null ? { confirmBy } : {}),
    attempts: 0,
    ...(isAwaiting ? {} : { lastAttemptAt: at }),
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
 * Verifies Invariant 11 for one payment from its status and the ledger, never from refund reasons
 * (a cancellation reason is free text typed by the customer):
 * - ledger refunds always equal the refund records;
 * - `expired`: sum(received) - sum(refunded) = 0 (every transfer was given back);
 * - `paid`: sum(received) - sum(refunded) = amount (an over-transfer is refunded and the payment stays paid);
 * - `refunded` / `partially_refunded`: the amount was received in full (received >= amount) and
 *   refunds never exceed what was received (refunds then also cover any over-transfer);
 * - `created` / `needs_review`: refunds never exceed what was received.
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
  if (payment.refundedAmount !== undefined && payment.refundedAmount !== totalRefundAmount) return false;

  switch (payment.status) {
    case 'expired':
      return received - refunded === 0;
    case 'paid':
      return received - refunded === payment.amount;
    case 'refunded':
    case 'partially_refunded':
      return received >= payment.amount && refunded <= received;
    case 'created':
    case 'needs_review':
      return refunded <= received;
  }
}
