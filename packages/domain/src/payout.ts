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

export const PAYOUT_STATUSES = ['pending', 'on_hold', 'processing', 'paid', 'failed'] as const;
export type PayoutStatus = (typeof PAYOUT_STATUSES)[number];

export interface PayoutItem {
  readonly paymentId: string;
  readonly amount: number;
}

export interface Payout {
  readonly id: string;
  readonly payeeId: string;
  readonly accountId: string;
  readonly amount: number;
  readonly status: PayoutStatus;
  readonly items: readonly PayoutItem[];
  readonly reference?: string;
  readonly failureReason?: string;
  readonly holdReason?: string;
  readonly createdBy: string;
  readonly createdAt: string;
  readonly updatedAt: string;
  readonly processingAt?: string;
  readonly paidAt?: string;
}
