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
 * A pending refund whose payment cannot be read any more: nothing can be sent, so it goes to staff
 * (`failed`, `manual`, `payment_missing`) and leaves the re-send queue.
 */
export function refundWithoutPayment(stored: Refund, now: Date): Refund {
  const at = now.toISOString();
  return {
    ...stored,
    status: 'failed',
    manual: true,
    failureReason: 'payment_missing',
    attempts: stored.attempts + 1,
    lastAttemptAt: at,
    updatedAt: at,
  };
}

/**
 * Booking refunds: record re-reads the refund in a BookingTx, merges, and sets booking.depositRefundedAt once
 * when an escrow refund becomes done (the rule refunds.ts has today).
 */
export function bookingRefundHandler(deps: BookingDeps): RefundSubjectHandler {
  return {
    async resend(refund: Refund): Promise<Refund> {
      // Re-read: a refund event (or staff) may have settled it since the clock's query. Sending a
      // refund that is no longer pending could pay twice (gateway + by hand).
      const stored = await deps.store.getRefund(refund.id);
      if (!stored || stored.status !== 'pending') return stored ?? refund;
      const payment = await deps.store.getPayment(stored.paymentId);
      if (!payment) {
        const gone = refundWithoutPayment(stored, deps.clock.now());
        return (await this.record(gone)) ?? gone;
      }
      const next = await sendRefundOnce(deps, stored, payment);
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
      // No handler yet for this subject: stamp the attempt so the row moves to the back of the
      // queue (oldest lastAttemptAt first) and never starves the refunds behind it.
      skipped += 1;
      try {
        await stampSkippedRefund(deps, r.id);
      } catch {
        failed += 1;
      }
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

/** Re-send skipped (no subject handler): `attempts + 1`, `lastAttemptAt = now`, only while still pending. */
async function stampSkippedRefund(deps: BookingDeps, refundId: string): Promise<void> {
  await deps.store.runTransaction(async (tx) => {
    const cur = await tx.getRefund(refundId);
    if (!cur || cur.status !== 'pending') return;
    const at = deps.clock.now().toISOString();
    await tx.addRefund({ ...cur, attempts: cur.attempts + 1, lastAttemptAt: at, updatedAt: at });
  });
}

export interface RefundEvent {
  readonly refundId: string;
  readonly provider: PaymentProvider;
  readonly status: RefundStatus;
  readonly providerRef?: string;
  readonly failureReason?: string;
}

/** `refund_unchanged`: the stored refund already holds a final state the event may not change (Decision 6). */
export type RefundEventOutcome = 'refund_applied' | 'refund_unchanged' | 'refund_unknown';

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

  const recorded = await handler.record(next);
  return recorded === null ? 'refund_unchanged' : 'refund_applied';
}
