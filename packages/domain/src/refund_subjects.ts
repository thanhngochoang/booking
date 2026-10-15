/**
 * Subject-specific refund outcome recording and re-send handling.
 */

import type { Booking } from './booking.js';
import type { BookingDeps } from './booking_ports.js';
import { isEscrowRefund, type PaymentSubject, type Refund } from './escrow.js';
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
