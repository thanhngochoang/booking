/** Earnings read model (S06.05): one row per payment and the three totals. Pure functions. */

import { isSettledPayment, type Payment, type PaymentSubject } from './escrow.js';
import type { Payout, PayoutStatus } from './payout.js';
import { payoutLineOf, type PayoutPolicy } from './payout_policy.js';
import type { ProviderType } from './provider_type.js';

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
  /** Released / all milestones of the booking; null when it has none (yet). */
  readonly milestones: { readonly done: number; readonly total: number } | null;
}

export interface EarningItem {
  readonly id: string;
  readonly payeeId: string;
  readonly subjectType: PaymentSubject;
  readonly subjectId: string;
  readonly counterpartName: string;
  readonly subjectLabel: string;
  readonly day: string;
  /** Gross (the booking money kept after refunds); KPIs add this. */
  readonly amount: number;
  /** Milestone amounts breakdown (when present, sum = amount). */
  readonly heldAmount?: number;
  readonly soonAmount?: number;
  readonly receivedAmount?: number;
  /** Breakdown: from the payout item once paid out (`estimated` false), else today's policy. */
  readonly platformFee: number;
  readonly taxWithheld: number;
  readonly netAmount: number;
  readonly feeRateBp: number;
  readonly taxRateBp: number;
  readonly estimated: boolean;
  readonly milestonesDone: number | null;
  readonly milestonesTotal: number | null;
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
  if (p.milestones) {
    if (p.milestones.some((m) => m.status === 'disputed')) return 'disputed';
    if (p.milestones.some((m) => m.status === 'released')) return 'released';
    if (p.milestones.some((m) => m.status === 'held')) return 'held';
    if (p.milestones.every((m) => m.status === 'refunded')) return null;
    return 'paid_out';
  }
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
  payeeType: ProviderType;
  policy: PayoutPolicy;
  now: Date;
}): EarningItem | null {
  const { payment, refunded, subject, payout, payeeType, policy, now } = i;
  const state = earningStateOf(payment);
  const net = payment.amount - refunded;
  const paid = isSettledPayment(payment) || payment.status === 'refunded';
  if (!payment.payeeId || !paid || state === null || net <= 0) return null;

  let holdReason: string | null = null;
  if (payment.milestones) {
    if (payment.milestones.some((m) => m.status === 'disputed')) {
      holdReason = HOLD_REASON_DISPUTE;
    } else if (state === 'released' && payout?.status === 'on_hold') {
      holdReason = HOLD_REASON_PAYOUT_ON_HOLD;
    }
  } else {
    if (state === 'disputed') holdReason = HOLD_REASON_DISPUTE;
    else if (state === 'released' && payout?.status === 'on_hold') holdReason = HOLD_REASON_PAYOUT_ON_HOLD;
  }

  let heldAmount: number | undefined;
  let soonAmount: number | undefined;
  let receivedAmount: number | undefined;

  let milestonesDone = subject.milestones?.done ?? null;
  let milestonesTotal = subject.milestones?.total ?? null;

  if (payment.milestones) {
    heldAmount = payment.milestones
      .filter((m) => m.status === 'held' || m.status === 'disputed')
      .reduce((s, m) => s + m.amount, 0);
    soonAmount = payment.milestones
      .filter((m) => m.status === 'released')
      .reduce((s, m) => s + m.amount, 0);
    receivedAmount = payment.milestones
      .filter((m) => m.status === 'paid_out')
      .reduce((s, m) => s + m.amount, 0);

    const doneCount = payment.milestones.filter((m) => m.status === 'released' || m.status === 'paid_out').length;
    milestonesDone = doneCount;
    milestonesTotal = payment.milestones.length;
  }

  const breakdown = breakdownOf(state, payment.id, net, payout, payeeType, policy);
  return {
    id: payment.id,
    payeeId: payment.payeeId,
    subjectType: payment.subjectType,
    subjectId: payment.subjectId,
    counterpartName: subject.counterpartName,
    subjectLabel: subject.label,
    day: subject.day,
    amount: net,
    heldAmount,
    soonAmount,
    receivedAmount,
    ...breakdown,
    milestonesDone,
    milestonesTotal,
    state,
    holdReason,
    paidOutAt: state === 'paid_out' ? (payout?.paidAt ?? payment.updatedAt) : null,
    updatedAt: now.toISOString(),
  };
}

/** What a paid-out row's payout item withheld, or the policy's estimate for any other row. */
function breakdownOf(
  state: EarningState,
  paymentId: string,
  gross: number,
  payout: Payout | null,
  payeeType: ProviderType,
  policy: PayoutPolicy,
): Pick<EarningItem, 'platformFee' | 'taxWithheld' | 'netAmount' | 'feeRateBp' | 'taxRateBp' | 'estimated'> {
  const item = state === 'paid_out' ? payout?.items.find((it) => it.paymentId === paymentId) : undefined;
  if (payout && item) {
    return {
      platformFee: item.fee,
      taxWithheld: item.tax,
      netAmount: item.net,
      feeRateBp: payout.feeRateBp,
      taxRateBp: payout.taxRateBp,
      estimated: false,
    };
  }
  const line = payoutLineOf(gross, payeeType, policy);
  return {
    platformFee: line.fee,
    taxWithheld: line.tax,
    netAmount: line.net,
    feeRateBp: line.feeRateBp,
    taxRateBp: line.taxRateBp,
    estimated: true,
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
    if (it.heldAmount !== undefined || it.soonAmount !== undefined || it.receivedAmount !== undefined) {
      heldAmount += it.heldAmount ?? 0;
      soonAmount += it.soonAmount ?? 0;
      receivedAmount += it.receivedAmount ?? 0;
    } else {
      if (it.state === 'held' || it.state === 'disputed') heldAmount += it.amount;
      else if (it.state === 'released') soonAmount += it.amount;
      else receivedAmount += it.amount;
    }
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
