/**
 * Use case: openDispute
 * Customer opens a dispute on a booking within the dispute window.
 */

import type { Booking } from './booking.js';
import { DISPUTE_WINDOW_HOURS, MIN_DISPUTE_REASON_LENGTH, MAX_DISPUTE_REASON_LENGTH } from './booking_policy.js';
import type { BookingDeps } from './booking_ports.js';
import { graphemeCount } from './booking_requests.js';
import { DomainError } from './errors.js';
import { disputeEscrowPayment, isSettledPayment } from './escrow.js';
import { disputeMilestone } from './milestones.js';
import { isId } from './ids.js';

export interface OpenDisputeInput {
  readonly bookingId: string;
  readonly customerId: string;
  readonly reason: string;
}

export async function openDispute(
  deps: BookingDeps,
  input: OpenDisputeInput,
): Promise<Booking> {
  if (!isId(input.bookingId) || !isId(input.customerId)) {
    throw new DomainError('invalid_argument');
  }

  const reasonTrimmed = input.reason ? input.reason.trim() : '';
  const count = graphemeCount(reasonTrimmed);
  if (count < MIN_DISPUTE_REASON_LENGTH || count > MAX_DISPUTE_REASON_LENGTH) {
    throw new DomainError('invalid_argument');
  }

  const now = deps.clock.now();

  return deps.store.runTransaction(async (tx) => {
    const booking = await tx.getBooking(input.bookingId);
    if (!booking) {
      throw new DomainError('not_found');
    }
    if (booking.customerId !== input.customerId) {
      throw new DomainError('permission_denied');
    }

    if (!['upcoming', 'shot', 'approved', 'completed'].includes(booking.status)) {
      throw new DomainError('conflict');
    }

    if (booking.status === 'shot') {
      if (!booking.shotAt) {
        throw new DomainError('conflict');
      }
      const shotTime = new Date(booking.shotAt).getTime();
      const elapsedHours = (now.getTime() - shotTime) / (1000 * 60 * 60);
      if (elapsedHours > DISPUTE_WINDOW_HOURS) {
        throw new DomainError('conflict');
      }
    } else if (booking.status === 'approved') {
      if (!booking.checkUntil) {
        throw new DomainError('conflict');
      }
      const checkUntilTime = new Date(booking.checkUntil).getTime();
      if (now.getTime() > checkUntilTime) {
        throw new DomainError('conflict');
      }
    } else if (booking.completedAt) {
      const completedTime = new Date(booking.completedAt).getTime();
      const elapsedHours = (now.getTime() - completedTime) / (1000 * 60 * 60);
      if (elapsedHours > DISPUTE_WINDOW_HOURS) {
        throw new DomainError('conflict');
      }
    }

    const payments = await deps.store.getPaymentsForBooking(booking.id);
    // The paid payment only: a `created` or stray row has escrow `held` from creation.
    const payment = payments.find(
      (p) => isSettledPayment(p) && (p.escrowStatus === 'held' || p.escrowStatus === 'partially_refunded' || (p.milestones && p.escrowStatus !== 'disputed' && p.escrowStatus !== 'refunded')),
    );
    if (!payment) {
      throw new DomainError('conflict');
    }

    let disputedPayment: Payment;
    if (payment.milestones && booking.status === 'approved') {
      disputedPayment = {
        ...disputeMilestone(payment, 'delivery', now),
        dispute: { reason: reasonTrimmed, openedAt: now.toISOString() },
      };
    } else if (payment.milestones && booking.status === 'shot') {
      disputedPayment = {
        ...disputeMilestone(payment, 'shoot', now),
        dispute: { reason: reasonTrimmed, openedAt: now.toISOString() },
      };
    } else {
      disputedPayment = {
        ...disputeEscrowPayment(payment, now),
        dispute: { reason: reasonTrimmed, openedAt: now.toISOString() },
      };
    }
    await tx.setPayment(disputedPayment);

    const updatedBooking: Booking = {
      ...booking,
      escrowStatus: 'disputed',
      version: booking.version + 1,
      updatedAt: now.toISOString(),
    };
    await tx.setBooking(updatedBooking);

    await tx.addBookingEvent({
      id: deps.ids.newId(),
      bookingId: booking.id,
      status: booking.status,
      at: now.toISOString(),
      actorId: input.customerId,
    });

    return updatedBooking;
  });
}
