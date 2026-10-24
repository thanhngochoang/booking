/**
 * Internal helper to atomically commit a booking transition, financial mutations,
 * calendar updates, and contact lifecycle changes.
 */

import type { Booking } from './booking.js';
import type { TransitionDecision } from './booking_machine.js';
import { parseVnDateTime } from './booking_policy.js';
import type { BookingDeps } from './booking_ports.js';
import { DomainError } from './errors.js';
import { applyRefundToPayment, isSettledPayment, type Payment, type Refund } from './escrow.js';
import { releaseMilestone, splitMilestones, withMilestones } from './milestones.js';
import { dispatchRefund } from './refunds.js';
import { withoutInterval } from './spot_booking.js';
import { studioDayLoadWith } from './studio_capacity.js';

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

    // 1. Calendar availability updates. A studio booking is held on the studio's day load, never on the
    // studio's own day, and its assignee's day is booked by assignBooking (#136 Decision 26). A spot booking
    // holds an interval of its schedule's spot day instead: accept writes nothing, the record stays `spot`
    // (#194 Decision 4), and a studio's spot booking is pre-assigned and never on the day load (Decision 7).
    const isStudio = current.isStudio === true;
    const isSpot = current.spotScheduleId !== undefined;
    if (nextStatus === 'accepted') {
      if (!isStudio && !isSpot) {
        await tx.setAvailabilityDay(current.photographerId, current.day, {
          state: 'booked',
          bookingId: current.id,
        });
      }
    } else if (['declined', 'expired', 'cancelled'].includes(nextStatus)) {
      // Every read before the first write
      const spotDay = current.spotScheduleId !== undefined ? await tx.getSpotDay(current.spotScheduleId, current.day) : null;
      const day = !isSpot ? await tx.getAvailabilityDay(current.photographerId, current.day) : null;
      const assigneeDay = isStudio && !isSpot && current.assigneeId
        ? await tx.getAvailabilityDay(current.assigneeId, current.day)
        : null;
      const load = isStudio && !isSpot ? await tx.getStudioDayLoad(current.photographerId, current.day) : null;
      // Clear availability days (or the spot interval) held by this booking
      if (isSpot && spotDay) {
        await tx.setSpotDay(withoutInterval(spotDay, current, now.toISOString()));
      } else if (day && day.bookingId === current.id) {
        await tx.deleteAvailabilityDay(current.photographerId, current.day);
      }
      if (current.assigneeId && assigneeDay?.bookingId === current.id) {
        await tx.deleteAvailabilityDay(current.assigneeId, current.day);
      }
      if (load) {
        await tx.setStudioDayLoad(
          studioDayLoadWith(load, { studioId: current.photographerId, day: current.day }, current.id, null, now.toISOString()),
        );
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
    } else if (nextStatus === 'shot') {
      const payments = await deps.store.getPaymentsForBooking(current.id);
      const payment = payments.find(
        (p) => isSettledPayment(p) && (p.escrowStatus === 'held' || p.escrowStatus === 'partially_refunded'),
      );
      if (payment) {
        const refunds = await deps.store.getRefundsForPayment(payment.id);
        const escrowRefunds = refunds.reduce((sum, r) => (r.fromEscrow !== false ? sum + r.amount : sum), 0);
        const net = payment.amount - escrowRefunds;
        const ms = splitMilestones(net, now);
        const updatedPayment = withMilestones(payment, ms, now.toISOString());
        await tx.setPayment(updatedPayment);
        newEscrowStatus = updatedPayment.escrowStatus;
      }
    } else if (nextStatus === 'completed') {
      const payments = await deps.store.getPaymentsForBooking(current.id);
      // A milestone payment whose shoot milestone is disputed (aggregate `disputed`) still gets its held
      // delivery milestone released; the disputed milestone is never touched (S18 Decision 1).
      const payment = payments.find(
        (p) =>
          isSettledPayment(p) &&
          (p.escrowStatus === 'held' ||
            p.escrowStatus === 'partially_refunded' ||
            p.escrowStatus === 'released' ||
            (p.milestones !== undefined && p.escrowStatus === 'disputed')),
      );
      if (payment) {
        if (payment.milestones) {
          const deliveryMs = payment.milestones.find((m) => m.kind === 'delivery');
          if (deliveryMs && deliveryMs.status === 'held') {
            const rel = releaseMilestone(payment, 'delivery', deps.ids.newId(), now);
            await tx.setPayment(rel.payment);
            await tx.addLedgerEntry(rel.ledgerEntry);
            newEscrowStatus = rel.payment.escrowStatus;
          }
        } else {
          // Legacy payments without milestones
          const releaseAfter = new Date(now.getTime() + 24 * 60 * 60 * 1000);
          const updatedPayment = {
            ...payment,
            releaseAfter: releaseAfter.toISOString(),
          };
          await tx.setPayment(updatedPayment);
        }
      }
    }

    // 3. Update booking
    const samplesPurgeAfter = nextStatus === 'completed'
      ? new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000).toISOString()
      : current.samplesPurgeAfter;

    const resultBooking: Booking = {
      ...current,
      status: nextStatus,
      escrowStatus: newEscrowStatus,
      depositRefunded: depositRefunded > 0 ? depositRefunded : undefined,
      cancel: decision.cancelRecord ?? current.cancel,
      shotAt: nextStatus === 'shot' ? (current.shotAt ?? now.toISOString()) : current.shotAt,
      completedAt: nextStatus === 'completed' ? now.toISOString() : current.completedAt,
      reviewedAt: nextStatus === 'reviewed' ? now.toISOString() : current.reviewedAt,
      samplesPurgeAfter,
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
