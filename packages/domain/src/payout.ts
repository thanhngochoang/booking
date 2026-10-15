/** Payout batch model (domain-model.md §2.4 `Payout`, `PayoutItem`). */

import type { Payment } from './escrow.js';

/** Payee of a platform-hosted event's ticket money: the platform keeps it, no provider payout. */
export const PLATFORM_PAYEE = 'platform';

/**
 * A payment a provider payout may batch: released, not yet batched, and owed to a provider.
 * Bookings and event tickets (payee = host) alike; the platform payee never enters a payout.
 */
export function isPayoutPayable(p: Payment): boolean {
  return p.escrowStatus === 'released' && !p.payoutId && p.payeeId !== '' && p.payeeId !== PLATFORM_PAYEE;
}

/**
 * `needs_approval`: the first payout to an account (or one whose holder name staff must still
 * compare) waits for staff before it can be sent (payments spec M5).
 */
export const PAYOUT_STATUSES = ['pending', 'needs_approval', 'on_hold', 'processing', 'paid', 'failed'] as const;
export type PayoutStatus = (typeof PAYOUT_STATUSES)[number];

/** Hold code set by the system (not a staff note) after repeated failures to the same account. */
export const HOLD_REASON_REPEATED_FAILURE = 'repeated_failure';
/** This many failed payouts in a row to one account put its next payout on hold. */
export const MAX_CONSECUTIVE_FAILURES = 3;

/** One batched payment: `amount` is gross (after escrow refunds), `amount = fee + tax + net`. */
export interface PayoutItem {
  readonly paymentId: string;
  readonly amount: number;
  readonly fee: number;
  readonly tax: number;
  readonly net: number;
}

export interface Payout {
  readonly id: string;
  readonly payeeId: string;
  readonly accountId: string;
  /** Gross: the sum of the items' amounts. */
  readonly amount: number;
  readonly status: PayoutStatus;
  readonly items: readonly PayoutItem[];
  /** Sums of the items; `amountNet` is what the bank transfer sends. */
  readonly platformFee: number;
  readonly taxWithheld: number;
  readonly amountNet: number;
  /** The policy rates used, snapshotted so history never changes. */
  readonly feeRateBp: number;
  readonly taxRateBp: number;
  /** No payout to this account had been paid or approved when this one was created. */
  readonly firstPayout: boolean;
  readonly approvedBy?: string;
  readonly approvedAt?: string;
  readonly reference?: string;
  readonly failureReason?: string;
  readonly holdReason?: string;
  readonly createdBy: string;
  readonly createdAt: string;
  readonly updatedAt: string;
  readonly processingAt?: string;
  readonly paidAt?: string;
}
