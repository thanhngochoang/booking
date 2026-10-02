import type { Booking, BookingCancel, BookingStatus } from './booking.js';
import {
  parseVnDateTime,
  refundPercent as computeRefundPercent,
  AUTO_COMPLETE_DELAY_HOURS,
  MAX_CANCEL_REASON_LENGTH,
} from './booking_policy.js';
import { DomainError } from './errors.js';

export type TransitionAction =
  | 'accept'
  | 'decline'
  | 'cancel'
  | 'upcoming'
  | 'complete'
  | 'review'
  | 'expire';

export type ActorRole = 'customer' | 'photographer' | 'system';

export interface TransitionActor {
  readonly id?: string;
  readonly role: ActorRole;
}

export interface TransitionDecision {
  readonly nextStatus: BookingStatus;
  readonly refundPercent: number;
  readonly cancelRecord?: BookingCancel;
}

/** Determines whether a user id is customer, photographer, or null for a booking. */
export function roleOf(
  userId: string | undefined,
  booking: Pick<Booking, 'customerId' | 'photographerId'>,
): 'customer' | 'photographer' | null {
  if (!userId) return null;
  if (userId === booking.customerId) return 'customer';
  if (userId === booking.photographerId) return 'photographer';
  return null;
}

/**
 * Validates and calculates state machine transitions for bookings.
 * Follows data-model/domain-model.md §5 and spec conventions.
 */
export function decideTransition(
  booking: Booking,
  action: TransitionAction,
  actor: TransitionActor,
  now: Date,
  reason?: string,
): TransitionDecision {
  // 1. Authorize actor
  if (actor.role === 'customer') {
    if (actor.id && actor.id !== booking.customerId) {
      throw new DomainError('permission_denied');
    }
  } else if (actor.role === 'photographer') {
    if (actor.id && actor.id !== booking.photographerId) {
      throw new DomainError('permission_denied');
    }
  } else if (actor.role !== 'system') {
    throw new DomainError('permission_denied');
  }

  // 2. Validate reason length if provided
  if (reason && reason.length > MAX_CANCEL_REASON_LENGTH) {
    throw new DomainError('invalid_argument');
  }

  const startsAt = parseVnDateTime(booking.day, booking.start);
  const endsAt = parseVnDateTime(booking.day, booking.end);

  switch (action) {
    case 'accept': {
      if (booking.status !== 'requested') {
        throw new DomainError('conflict');
      }
      if (actor.role !== 'photographer') {
        throw new DomainError('permission_denied');
      }
      if (booking.acceptDeadline) {
        const deadline = new Date(booking.acceptDeadline);
        if (now.getTime() > deadline.getTime()) {
          throw new DomainError('deadline_passed');
        }
      }

      // If within 24h of start, transition directly to upcoming
      const hoursUntilStart = (startsAt.getTime() - now.getTime()) / (1000 * 60 * 60);
      const nextStatus: BookingStatus = hoursUntilStart <= 24 ? 'upcoming' : 'accepted';
      return { nextStatus, refundPercent: 0 };
    }

    case 'decline': {
      if (booking.status !== 'requested') {
        throw new DomainError('conflict');
      }
      if (actor.role !== 'photographer') {
        throw new DomainError('permission_denied');
      }
      return {
        nextStatus: 'declined',
        refundPercent: 100,
        cancelRecord: {
          by: 'photographer',
          reason,
          at: now.toISOString(),
          refundPercent: 100,
        },
      };
    }

    case 'expire': {
      if (booking.status !== 'requested') {
        throw new DomainError('conflict');
      }
      if (actor.role !== 'system') {
        throw new DomainError('permission_denied');
      }
      if (booking.acceptDeadline) {
        const deadline = new Date(booking.acceptDeadline);
        if (now.getTime() < deadline.getTime()) {
          throw new DomainError('conflict');
        }
      }
      return {
        nextStatus: 'expired',
        refundPercent: 100,
        cancelRecord: {
          by: 'system',
          reason: 'accept_deadline_passed',
          at: now.toISOString(),
          refundPercent: 100,
        },
      };
    }

    case 'upcoming': {
      if (booking.status !== 'accepted') {
        throw new DomainError('conflict');
      }
      if (actor.role !== 'system') {
        throw new DomainError('permission_denied');
      }
      const hoursUntilStart = (startsAt.getTime() - now.getTime()) / (1000 * 60 * 60);
      if (hoursUntilStart > 24) {
        throw new DomainError('conflict');
      }
      return { nextStatus: 'upcoming', refundPercent: 0 };
    }

    case 'cancel': {
      if (!['requested', 'accepted', 'upcoming'].includes(booking.status)) {
        throw new DomainError('conflict');
      }
      if (actor.role !== 'customer' && actor.role !== 'photographer') {
        throw new DomainError('permission_denied');
      }
      // Neither party can cancel at or after start
      if (now.getTime() >= startsAt.getTime()) {
        throw new DomainError('not_eligible');
      }

      if (actor.role === 'photographer') {
        return {
          nextStatus: 'cancelled',
          refundPercent: 100,
          cancelRecord: {
            by: 'photographer',
            reason,
            at: now.toISOString(),
            refundPercent: 100,
          },
        };
      }

      // Customer cancellation: refund based on hours before start
      const hoursBeforeStart = (startsAt.getTime() - now.getTime()) / (1000 * 60 * 60);
      const pct = computeRefundPercent(hoursBeforeStart);
      return {
        nextStatus: 'cancelled',
        refundPercent: pct,
        cancelRecord: {
          by: 'customer',
          reason,
          at: now.toISOString(),
          refundPercent: pct,
        },
      };
    }

    case 'complete': {
      if (!['accepted', 'upcoming'].includes(booking.status)) {
        throw new DomainError('conflict');
      }

      if (actor.role === 'photographer') {
        // Photographer can complete only after end time
        if (now.getTime() < endsAt.getTime()) {
          throw new DomainError('not_eligible');
        }
      } else if (actor.role === 'system') {
        // System auto-completes 24h after end time
        const autoTime = endsAt.getTime() + AUTO_COMPLETE_DELAY_HOURS * 60 * 60 * 1000;
        if (now.getTime() < autoTime) {
          throw new DomainError('conflict');
        }
      } else {
        throw new DomainError('permission_denied');
      }

      return { nextStatus: 'completed', refundPercent: 0 };
    }

    case 'review': {
      if (booking.status !== 'completed') {
        throw new DomainError('conflict');
      }
      if (actor.role !== 'customer') {
        throw new DomainError('permission_denied');
      }
      return { nextStatus: 'reviewed', refundPercent: 0 };
    }

    default:
      throw new DomainError('invalid_argument');
  }
}
