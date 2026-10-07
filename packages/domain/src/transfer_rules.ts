/**
 * What to do with one incoming bank transfer for a payment (payments spec §3.3 mis-transfer
 * table, #129 Decisions 6 and 7). Pure: the caller does the matching, the writes and the refund.
 */

import type { PaymentStatus } from './escrow.js';

export type TransferDecision =
  | { readonly kind: 'paid'; readonly excess: number }
  | { readonly kind: 'partial'; readonly received: number }
  | {
      readonly kind: 'refund';
      readonly amount: number;
      readonly reason: 'late_transfer' | 'extra_transfer';
    };

/**
 * - Payment already paid or refunded (paid twice, or the old QR paid after "Tạo QR mới"):
 *   refund the whole transfer, `extra_transfer`.
 * - Payment expired, or `receivedAt` at or after `expiresAt` (even if no sweep has marked it
 *   `expired` yet): refund the whole transfer, `late_transfer`.
 * - Otherwise the transfer adds to `receivedBefore`: `paid` once the sum reaches `amount`
 *   (with the part above it as `excess`), else `partial` with the running total in `received`.
 * Times are ISO-8601 and compared as instants. A `needs_review` payment accepts nothing new
 * automatically, so it is treated like a closed one (`extra_transfer`).
 */
export function decideTransfer(p: {
  readonly status: PaymentStatus;
  readonly amount: number;
  readonly receivedBefore: number;
  readonly expiresAt: string;
  readonly transferAmount: number;
  readonly receivedAt: string;
}): TransferDecision {
  if (p.status === 'paid' || p.status === 'refunded' || p.status === 'partially_refunded' || p.status === 'needs_review') {
    return { kind: 'refund', amount: p.transferAmount, reason: 'extra_transfer' };
  }
  if (p.status === 'expired' || Date.parse(p.receivedAt) >= Date.parse(p.expiresAt)) {
    return { kind: 'refund', amount: p.transferAmount, reason: 'late_transfer' };
  }
  const total = p.receivedBefore + p.transferAmount;
  if (total >= p.amount) {
    return { kind: 'paid', excess: Math.min(p.transferAmount, total - p.amount) };
  }
  return { kind: 'partial', received: total };
}
