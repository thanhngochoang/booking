/**
 * S22.01 payer payment history (#141, plan 2026-10-07-s22-payments-account Decisions 1–4): one
 * customer-readable row per payment that received money, at `users/{uid}/payments/{paymentId}`,
 * and the payer's totals at `users/{uid}/private/paymentTotals`. Server-written projection of
 * `payments` and `refunds`; it whitelists its fields, so it never carries the payer's account,
 * a refund candidate, gateway instructions or provider references.
 */

import { PLATFORM_PAYEE } from './payout.js';
import {
  escrowRefundedTotal,
  isEscrowRefund,
  type Payment,
  type PaymentMethod,
  type PaymentSubject,
  type Refund,
  type RefundMethod,
  type RefundStatus,
} from './escrow.js';
import type { Clock } from './ports.js';

export const PAYER_ROW_STATUSES = [
  'held',
  'disputed',
  'released',
  'refund_account_needed',
  'refunding',
  'refunded',
  'partially_refunded',
] as const;
export type PayerRowStatus = (typeof PAYER_ROW_STATUSES)[number];

/** Every payment subject on develop, `instant_request` included (#202). */
export type PayerSubjectType = PaymentSubject;

/** `policy`: out of escrow (`fromEscrow`: cancel, decline, expiry, dispute); `excess`: sent straight back on arrival. */
export type RefundKind = 'policy' | 'excess';
export const refundKindOf = (r: Pick<Refund, 'fromEscrow'>): RefundKind => (isEscrowRefund(r) ? 'policy' : 'excess');

export interface PayerRefundView {
  readonly refundId: string;
  readonly amount: number;
  readonly status: RefundStatus;
  readonly method: RefundMethod;
  readonly kind: RefundKind;
  /** "Vietcombank •••• 6789"; null for a wallet refund or one still waiting for an account. */
  readonly destinationLabel: string | null;
  readonly createdAt: string;
  /** When the refund reached `done`; null until then. */
  readonly doneAt: string | null;
}

/**
 * What the row shows about its subject, read by the adapter. Structured parts only: the app composes
 * the title with its own copy (`payTitleTicket`, `payTitleInstant`, `verifyFeeTitle`); a part that
 * does not apply to the subject is null.
 */
export interface PayerSubjectView {
  /** Booking: the photographer's display name. */
  readonly photographerName: string | null;
  /** Booking: the service snapshot's name. */
  readonly serviceName: string | null;
  /** Ticket: the event title. */
  readonly eventTitle: string | null;
  /** Ticket: the number of tickets. */
  readonly quantity: number | null;
  /** Chụp ngay: the request's area label. */
  readonly areaLabel: string | null;
  /** Vietnam day `yyyy-MM-dd` of the shoot or event; null when the subject has none (Chụp ngay, fee). */
  readonly day: string | null;
  readonly eventId: string | null;
  /** A Chụp ngay request still looking for a photographer ("đang tìm thợ"). */
  readonly searching: boolean;
  /** The booking, ticket or request was cancelled, declined or expired ("đã huỷ"). */
  readonly cancelled: boolean;
}

/** A subject with no parts (the S21 fee, or a subject whose document is gone and was never shown). */
export const EMPTY_PAYER_SUBJECT: PayerSubjectView = {
  photographerName: null,
  serviceName: null,
  eventTitle: null,
  quantity: null,
  areaLabel: null,
  day: null,
  eventId: null,
  searching: false,
  cancelled: false,
};

export interface PayerPaymentRow {
  readonly paymentId: string;
  readonly payerId: string;
  readonly subjectType: PayerSubjectType;
  readonly subjectId: string;
  readonly eventId: string | null;
  readonly photographerName: string | null;
  readonly serviceName: string | null;
  readonly eventTitle: string | null;
  readonly quantity: number | null;
  readonly areaLabel: string | null;
  readonly day: string | null;
  /** Null for a payment from before checkout methods existed. */
  readonly method: PaymentMethod | null;
  /** VND the customer sent for this payment, an over-transfer or late transfer included. */
  readonly amount: number;
  readonly status: PayerRowStatus;
  readonly open: boolean;
  /** The platform is the payee (S21 fee, platform event): "Đã thanh toán" instead of "Đã chuyển cho …". */
  readonly toPlatform: boolean;
  readonly heldAmount: number;
  readonly refundingAmount: number;
  readonly refundedAmount: number;
  readonly searching: boolean;
  readonly cancelled: boolean;
  readonly refunds: readonly PayerRefundView[];
  readonly createdAt: string;
  readonly paidAt: string | null;
  readonly updatedAt: string;
}

export interface PayerTotals {
  readonly held: number;
  readonly refunding: number;
}

const OPEN_STATUSES: readonly PayerRowStatus[] = ['held', 'disputed', 'refund_account_needed', 'refunding'];
const sum = (rs: readonly Refund[]): number => rs.reduce((s, r) => s + r.amount, 0);

/** The payment reached its amount at some point (a wallet payment may carry no `receivedAmount`). */
const everPaid = (p: Payment): boolean =>
  p.paidAt !== undefined || p.status === 'paid' || p.status === 'partially_refunded' || p.status === 'refunded';

/** Decision 2: money arrived (paid, part-paid, or a transfer that was sent back). */
export const paymentHasMoney = (p: Payment, refunds: readonly Refund[]): boolean =>
  everPaid(p) || (p.receivedAmount ?? 0) > 0 || refunds.length > 0;

export function destinationLabel(d: { readonly bankName: string; readonly accountLast4: string } | null | undefined): string | null {
  return d ? `${d.bankName} •••• ${d.accountLast4}` : null;
}

/** What escrow still holds of the payment for the payee (a part-paid open QR: what it received). */
function heldOf(p: Payment, refunds: readonly Refund[]): number {
  if (!everPaid(p)) return p.status === 'created' || p.status === 'needs_review' ? p.receivedAmount ?? 0 : 0;
  if (p.escrowStatus !== 'held' && p.escrowStatus !== 'partially_refunded' && p.escrowStatus !== 'disputed') return 0;
  // Booking milestones (split at the shot): only what is not released yet is held.
  if (p.milestones !== undefined && p.milestones.length > 0) {
    return p.milestones.reduce((s, m) => (m.status === 'held' || m.status === 'disputed' ? s + m.amount : s), 0);
  }
  return Math.max(0, p.amount - escrowRefundedTotal(refunds));
}

/** Decision 3, in this order. */
function statusOf(p: Payment, refunds: readonly Refund[], held: number): PayerRowStatus {
  if (refunds.some((r) => r.status === 'awaiting_account')) return 'refund_account_needed';
  if (refunds.some((r) => r.status === 'pending' || r.status === 'failed')) return 'refunding';
  if (p.escrowStatus === 'disputed') return 'disputed';
  // Never paid: a part-paid QR still open holds money; an expired one (or a late transfer) was given back.
  if (!everPaid(p)) return held > 0 ? 'held' : 'refunded';
  if (p.status === 'refunded' || p.escrowStatus === 'refunded') return 'refunded';
  if (p.escrowStatus === 'released' || p.escrowStatus === 'paid_out') {
    return refunds.some(isEscrowRefund) ? 'partially_refunded' : 'released';
  }
  return 'held';
}

function refundView(r: Refund): PayerRefundView {
  return {
    refundId: r.id,
    amount: r.amount,
    status: r.status,
    method: r.method,
    kind: refundKindOf(r),
    destinationLabel: r.method === 'bank_transfer' ? destinationLabel(r.destination) : null,
    createdAt: r.createdAt,
    doneAt: r.status === 'done' ? r.updatedAt : null,
  };
}

/** Null when no money ever arrived (Decision 2). Status by Decision 3. */
export function payerRowOf(
  p: Payment,
  refunds: readonly Refund[],
  subject: PayerSubjectView,
  now: Date,
): PayerPaymentRow | null {
  const mine = refunds.filter((r) => r.paymentId === p.id);
  if (!paymentHasMoney(p, mine)) return null;
  const excess = sum(mine.filter((r) => !isEscrowRefund(r)));
  // Paid: the amount plus anything sent above it. Never paid: every transfer (an expired QR's
  // received money is in its `underpaid_expired` refund, so only an open QR adds receivedAmount).
  const amount = everPaid(p)
    ? p.amount + excess
    : (p.status === 'expired' ? 0 : p.receivedAmount ?? 0) + sum(mine);
  const heldAmount = heldOf(p, mine);
  const status = statusOf(p, mine, heldAmount);
  const sorted = [...mine].sort((a, b) => a.createdAt.localeCompare(b.createdAt) || a.id.localeCompare(b.id));
  return {
    paymentId: p.id,
    payerId: p.payerId,
    subjectType: p.subjectType,
    subjectId: p.subjectId,
    eventId: p.eventId ?? subject.eventId,
    photographerName: subject.photographerName,
    serviceName: subject.serviceName,
    eventTitle: subject.eventTitle,
    quantity: subject.quantity,
    areaLabel: subject.areaLabel,
    day: subject.day,
    method: p.method ?? null,
    amount,
    status,
    open: OPEN_STATUSES.includes(status),
    toPlatform: p.payeeId === PLATFORM_PAYEE,
    heldAmount,
    refundingAmount: sum(mine.filter((r) => r.status !== 'done')),
    refundedAmount: sum(mine.filter((r) => r.status === 'done')),
    searching: subject.searching,
    cancelled: subject.cancelled,
    refunds: sorted.map(refundView),
    createdAt: p.createdAt,
    paidAt: p.paidAt ?? null,
    updatedAt: now.toISOString(),
  };
}

/** "Đang giữ" and "Đang hoàn" on S22.01: sums over the open rows. */
export function payerTotals(rows: readonly PayerPaymentRow[]): PayerTotals {
  let held = 0;
  let refunding = 0;
  for (const r of rows) {
    if (!r.open) continue;
    held += r.heldAmount;
    refunding += r.refundingAmount;
  }
  return { held, refunding };
}

/** One transaction: every read before the first write (Firestore refuses a read after a write). */
export interface PayerHistoryTx {
  payment(id: string): Promise<Payment | null>;
  refundsOf(paymentId: string): Promise<readonly Refund[]>;
  subjectOf(p: Payment): Promise<PayerSubjectView>;
  /** The payer's rows with `open == true`. */
  openRows(payerId: string): Promise<readonly PayerPaymentRow[]>;
  putRow(row: PayerPaymentRow): void;
  deleteRow(payerId: string, paymentId: string): void;
  putTotals(payerId: string, totals: PayerTotals, at: Date): void;
}

export interface PayerHistoryStore {
  runTransaction<T>(fn: (tx: PayerHistoryTx) => Promise<T>): Promise<T>;
  /** Ids of the payments of one subject (a booking's QR attempts), any status; outside a transaction. */
  paymentIdsOf(subjectType: PaymentSubject, subjectId: string): Promise<readonly string[]>;
}

export interface PayerHistoryDeps {
  readonly store: PayerHistoryStore;
  readonly clock: Clock;
}

/**
 * Rewrites the payer's row of one payment and their totals from the payment and its refunds.
 * Idempotent (a replayed trigger writes the same row). When the payment is gone: with `payerId`
 * (the deleted document's payer) its row is deleted, else `missing`.
 */
export async function refreshPayerHistory(
  deps: PayerHistoryDeps,
  paymentId: string,
  gone?: { readonly payerId: string },
): Promise<'written' | 'deleted' | 'missing'> {
  return deps.store.runTransaction(async (tx) => {
    const p = await tx.payment(paymentId);
    const payerId = p?.payerId ?? gone?.payerId;
    if (payerId === undefined || payerId === '') return 'missing';
    const refunds = p === null ? [] : await tx.refundsOf(paymentId);
    const subject = p !== null && paymentHasMoney(p, refunds) ? await tx.subjectOf(p) : null;
    const open = await tx.openRows(payerId);
    const now = deps.clock.now();
    const row = p === null || subject === null ? null : payerRowOf(p, refunds, subject, now);
    const others = open.filter((r) => r.paymentId !== paymentId);
    if (row === null) tx.deleteRow(payerId, paymentId);
    else tx.putRow(row);
    tx.putTotals(payerId, payerTotals(row === null ? others : [...others, row]), now);
    return row === null ? 'deleted' : 'written';
  });
}

/**
 * The subject changed without touching its payments (a booking cancelled with no refund, or
 * rescheduled): refreshes the row of each of its payments. Returns how many were refreshed.
 */
export async function refreshPayerHistoryOfSubject(
  deps: PayerHistoryDeps,
  subjectType: PaymentSubject,
  subjectId: string,
): Promise<number> {
  const ids = await deps.store.paymentIdsOf(subjectType, subjectId);
  for (const id of ids) await refreshPayerHistory(deps, id);
  return ids.length;
}
