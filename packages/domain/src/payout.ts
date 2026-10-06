/** Payout batch model (domain-model.md §2.4 `Payout`, `PayoutItem`). */

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
