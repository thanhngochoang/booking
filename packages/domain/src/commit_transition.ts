/**
 * Internal helper to atomically commit a booking transition, financial mutations,
 * calendar updates, and contact lifecycle changes.
 */

import type { Booking } from './booking.js';
import type { TransitionDecision } from './booking_machine.js';
import { parseVnDateTime } from './booking_policy.js';
import type { BookingDeps } from './booking_ports.js';
import { DomainError } from './errors.js';
import { applyRefundToPayment, type Payment, type Refund } from './escrow.js';
import { dispatchRefund } from './refunds.js';

export async function commitTransition(
  deps: BookingDeps,
  booking: Booking,
  decision: TransitionDecision,
  actorId?: string,
): Promise<Booking> {
  const now = deps.clock.now();
  let pendingRefund: { refund: Refund; provider: Payment['provider'] } | undefined;

  const updatedBooking = await deps.store.runTransaction(async (tx) => {
    const current = await tx.getBooking(booking.id);
    if (!current) {
      throw new DomainError('not_found');
    }
    // Optimistic lock check
    if (current.version !== booking.version) {
      throw new DomainError('conflict');
    }

    const { nextStatus } = decision;
    const startsAt = parseVnDateTime(current.day, current.start);

    // 1. Calendar availability updates
    if (nextStatus === 'accepted') {
      await tx.setAvailabilityDay(current.photographerId, current.day, {
        state: 'booked',
        bookingId: current.id,
      });
    } else if (['declined', 'expired', 'cancelled'].includes(nextStatus)) {
      // Clear availability day if held by this booking
      const day = await tx.getAvailabilityDay(current.photographerId, current.day);
      if (day && day.bookingId === current.id) {
        await tx.deleteAvailabilityDay(current.photographerId, current.day);
      }
      // Remove contact copy on cancellation/decline/expiry (Assumption 9)
      await tx.deleteContactSnapshot(current.id);
    }

    // 2. Financial mutations
    let newEscrowStatus = current.escrowStatus;
    let depositRefunded = current.depositRefunded ?? 0;

    if (decision.refundPercent > 0) {
      const payments = await deps.store.getPaymentsForBooking(current.id);
      const payment = payments.find(
        (p) => p.status === 'paid' && (p.escrowStatus === 'held' || p.escrowStatus === 'partially_refunded'),
      );

      if (payment) {
        const refundResult = applyRefundToPayment({
          payment,
          refundId: deps.ids.newId(),
          percent: decision.refundPercent,
          ledgerEntryId: deps.ids.newId(),
          reason: decision.cancelRecord?.reason ?? nextStatus,
          now,
        });

        // If late cancel keeps partial deposit (e.g. 50%), the kept portion releases to photographer at start + 24h
        let updatedPayment = refundResult.payment;
        if (decision.refundPercent < 100) {
          const releaseAfter = new Date(startsAt.getTime() + 24 * 60 * 60 * 1000);
          updatedPayment = {
            ...updatedPayment,
            releaseAfter: releaseAfter.toISOString(),
          };
        }

        await tx.setPayment(updatedPayment);
        await tx.addRefund(refundResult.refund);
        await tx.addLedgerEntry(refundResult.ledgerEntry);

        newEscrowStatus = updatedPayment.escrowStatus;
        depositRefunded += refundResult.refund.amount;
        pendingRefund = { refund: refundResult.refund, provider: payment.provider };
      }
    } else if (nextStatus === 'completed') {
      // Completed booking: deposit releases after 24h dispute window
      const payments = await deps.store.getPaymentsForBooking(current.id);
      const payment = payments.find((p) => p.escrowStatus === 'held' || p.escrowStatus === 'partially_refunded');
      if (payment) {
        const releaseAfter = new Date(now.getTime() + 24 * 60 * 60 * 1000);
        const updatedPayment = {
          ...payment,
          releaseAfter: releaseAfter.toISOString(),
        };
        await tx.setPayment(updatedPayment);
      }
    }

    // 3. Update booking
    const resultBooking: Booking = {
      ...current,
      status: nextStatus,
      escrowStatus: newEscrowStatus,
      depositRefunded: depositRefunded > 0 ? depositRefunded : undefined,
      cancel: decision.cancelRecord ?? current.cancel,
      completedAt: nextStatus === 'completed' ? now.toISOString() : current.completedAt,
      reviewedAt: nextStatus === 'reviewed' ? now.toISOString() : current.reviewedAt,
      version: current.version + 1,
      updatedAt: now.toISOString(),
    };

    await tx.setBooking(resultBooking);
    await tx.addBookingEvent({
      id: deps.ids.newId(),
      bookingId: current.id,
      status: nextStatus,
      at: now.toISOString(),
      actorId,
    });

    return resultBooking;
  });

  // 4. Outside transaction: dispatch refund to gateway if queued
  if (pendingRefund) {
    await dispatchRefund(deps, pendingRefund.refund, pendingRefund.provider);
  }

  return updatedBooking;
}
