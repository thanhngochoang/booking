/**
 * Subject-specific refund outcome recording and re-send handling.
 */

import type { Booking, PaymentProvider } from './booking.js';
import type { BookingDeps } from './booking_ports.js';
import { REFUND_RESEND_AFTER_MINUTES } from './booking_policy.js';
import { isEscrowRefund, type PaymentSubject, type Refund, type RefundStatus } from './escrow.js';
import { mergeRefundOutcome, sendRefundOnce } from './refunds.js';

export interface RefundSubjectHandler {
  /** Sends a pending refund again under its id and stores the outcome in the subject's own transaction. */
  resend(refund: Refund): Promise<Refund>;
  /** Stores an outcome (mergeRefundOutcome + the subject's mirrors); null when nothing changed. */
  record(next: Refund): Promise<Refund | null>;
}

export type RefundSubjects = Readonly<Partial<Record<PaymentSubject, RefundSubjectHandler>>>;

/**
 * Booking refunds: record re-reads the refund in a BookingTx, merges, and sets booking.depositRefundedAt once
 * when an escrow refund becomes done (the rule refunds.ts has today).
 */
export function bookingRefundHandler(deps: BookingDeps): RefundSubjectHandler {
  return {
    async resend(refund: Refund): Promise<Refund> {
      const payment = await deps.store.getPayment(refund.paymentId);
      if (!payment) return refund;
      const next = await sendRefundOnce(deps, refund, payment);
      const recorded = await this.record(next);
      return recorded ?? next;
    },

    async record(next: Refund): Promise<Refund | null> {
      return deps.store.runTransaction(async (tx) => {
        // Reads first
        const stored = await tx.getRefund(next.id);
        const merged = stored ? mergeRefundOutcome(stored, next) : next;
        if (!merged) return null;

        let booking: Booking | null = null;
        if (merged.status === 'done' && isEscrowRefund(merged)) {
          const payment = await tx.getPayment(merged.paymentId);
          if (payment?.subjectType === 'booking') {
            booking = await tx.getBooking(payment.subjectId);
          }
        }

        // Writes
        await tx.addRefund(merged);
        if (booking && !booking.depositRefundedAt) {
          const at = deps.clock.now().toISOString();
          await tx.setBooking({ ...booking, depositRefundedAt: at, updatedAt: at });
        }

        return merged;
      });
    },
  };
}

/**
 * The payment clock: finds refunds left `pending` that have not been attempted for
 * REFUND_RESEND_AFTER_MINUTES, routes to the subject handler, and sends them again.
 */
export async function resendPendingRefunds(
  deps: BookingDeps,
  subjects: RefundSubjects = {},
  limit = 100,
): Promise<{ resent: number; failed: number; skipped: number }> {
  const cutoff = new Date(deps.clock.now().getTime() - REFUND_RESEND_AFTER_MINUTES * 60_000);
  const pending = await deps.store.findPendingRefunds(cutoff, limit);
  let resent = 0;
  let failed = 0;
  let skipped = 0;

  for (const r of pending) {
    const handler = (!r.subjectType || r.subjectType === 'booking')
      ? bookingRefundHandler(deps)
      : subjects[r.subjectType];

    if (!handler) {
      skipped += 1;
      continue;
    }

    try {
      await handler.resend(r);
      resent += 1;
    } catch {
      failed += 1;
    }
  }

  return { resent, failed, skipped };
}

export interface RefundEvent {
  readonly refundId: string;
  readonly provider: PaymentProvider;
  readonly status: RefundStatus;
  readonly providerRef?: string;
  readonly failureReason?: string;
}

export type RefundEventOutcome = 'refund_applied' | 'refund_unknown';

/**
 * Applies an asynchronous refund event (e.g. from webhook or gateway polling).
 * Missing refund/payment or mismatched provider returns `refund_unknown`.
 */
export async function applyRefundEvent(
  deps: BookingDeps,
  event: RefundEvent,
  subjects: RefundSubjects = {},
): Promise<RefundEventOutcome> {
  const stored = await deps.store.getRefund(event.refundId);
  if (!stored) return 'refund_unknown';

  const payment = await deps.store.getPayment(stored.paymentId);
  if (!payment || payment.provider !== event.provider) return 'refund_unknown';

  const next: Refund = {
    ...stored,
    status: event.status,
    manual: event.status === 'failed',
    providerRef: event.providerRef ?? stored.providerRef,
    failureReason: event.failureReason,
    updatedAt: deps.clock.now().toISOString(),
  };

  const handler = (!stored.subjectType || stored.subjectType === 'booking')
    ? bookingRefundHandler(deps)
    : subjects[stored.subjectType];

  if (!handler) return 'refund_unknown';

  await handler.record(next);
  return 'refund_applied';
}
