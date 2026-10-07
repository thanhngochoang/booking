/** Earnings read model (S06.05): one row per payment and the three totals. Pure functions. */

import { isSettledPayment, type Payment, type PaymentSubject } from './escrow.js';
import type { Payout, PayoutStatus } from './payout.js';

export const EARNING_STATES = ['held', 'disputed', 'released', 'paid_out'] as const;
export type EarningState = (typeof EARNING_STATES)[number];

/**
 * Fixed hold-reason codes (controller ruling R3): the app maps a code to a label; the
 * customer's free text and the staff note never reach the payee.
 */
export const HOLD_REASON_DISPUTE = 'dispute';
export const HOLD_REASON_PAYOUT_ON_HOLD = 'payout_on_hold';

export interface EarningSubject {
  readonly counterpartName: string;
  readonly label: string;
  readonly day: string;
}

export interface EarningItem {
  readonly id: string;
  readonly payeeId: string;
  readonly subjectType: PaymentSubject;
  readonly subjectId: string;
  readonly counterpartName: string;
  readonly subjectLabel: string;
  readonly day: string;
  readonly amount: number;
  readonly state: EarningState;
  readonly holdReason: string | null;
  readonly paidOutAt: string | null;
  readonly updatedAt: string;
}

export interface EarningsSummary {
  readonly payeeId: string;
  readonly heldAmount: number;
  readonly soonAmount: number;
  readonly receivedAmount: number;
  readonly lastPayout: { readonly id: string; readonly status: PayoutStatus; readonly at: string } | null;
  readonly updatedAt: string;
}

export function earningStateOf(p: Payment): EarningState | null {
  switch (p.escrowStatus) {
    case 'held':
    case 'partially_refunded':
      return 'held';
    case 'disputed':
      return 'disputed';
    case 'released':
      return 'released';
    case 'paid_out':
      return 'paid_out';
    default:
      return null;
  }
}

/**
 * The row for a payment, or null when it has no payee, is not paid yet (a `created` QR payment has
 * escrow `held` from creation), has no money state or nothing left after refunds. `refunded` is
 * what escrow gave back (escrow refunds only).
 */
export function earningItemOf(i: {
  payment: Payment;
  refunded: number;
  subject: EarningSubject;
  payout: Payout | null;
  now: Date;
}): EarningItem | null {
  const { payment, refunded, subject, payout, now } = i;
  const state = earningStateOf(payment);
  const net = payment.amount - refunded;
  const paid = isSettledPayment(payment) || payment.status === 'refunded';
  if (!payment.payeeId || !paid || state === null || net <= 0) return null;

  let holdReason: string | null = null;
  if (state === 'disputed') holdReason = HOLD_REASON_DISPUTE;
  else if (state === 'released' && payout?.status === 'on_hold') holdReason = HOLD_REASON_PAYOUT_ON_HOLD;

  return {
    id: payment.id,
    payeeId: payment.payeeId,
    subjectType: payment.subjectType,
    subjectId: payment.subjectId,
    counterpartName: subject.counterpartName,
    subjectLabel: subject.label,
    day: subject.day,
    amount: net,
    state,
    holdReason,
    paidOutAt: state === 'paid_out' ? (payout?.paidAt ?? payment.updatedAt) : null,
    updatedAt: now.toISOString(),
  };
}

/** Đang giữ = held + disputed; Sắp nhận = released; Đã nhận = paid_out. */
export function summarizeEarnings(
  payeeId: string,
  items: readonly EarningItem[],
  lastPayout: Payout | null,
  now: Date,
): EarningsSummary {
  let heldAmount = 0;
  let soonAmount = 0;
  let receivedAmount = 0;
  for (const it of items) {
    if (it.state === 'held' || it.state === 'disputed') heldAmount += it.amount;
    else if (it.state === 'released') soonAmount += it.amount;
    else receivedAmount += it.amount;
  }
  return {
    payeeId,
    heldAmount,
    soonAmount,
    receivedAmount,
    lastPayout:
      lastPayout === null
        ? null
        : { id: lastPayout.id, status: lastPayout.status, at: lastPayout.updatedAt },
    updatedAt: now.toISOString(),
  };
}
