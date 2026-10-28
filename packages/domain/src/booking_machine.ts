import type { Booking, BookingCancel, BookingStatus } from './booking.js';
import {
  formatVnDate,
  parseVnDateTime,
  refundPercent as computeRefundPercent,
  AUTO_COMPLETE_DELAY_HOURS,
  MAX_CANCEL_REASON_LENGTH,
} from './booking_policy.js';
import { DomainError } from './errors.js';
import { CHECKIN_GRACE_HOURS } from './event.js';
import { SCAN_OPEN_BEFORE_HOURS } from './pass.js';
import { studioFaultOf, waitsForAssignee } from './studio_assignment.js';

export type TransitionAction =
  | 'accept'
  | 'decline'
  | 'cancel'
  | 'upcoming'
  /**
   * S30 (Decision 10): the shooter scanned the customer's pass, `upcoming → shooting`. Only `scanPass`
   * decides it (in its own transaction); `transitionBooking` refuses it from clients.
   */
  | 'scan'
  | 'mark_shot'
  | 'complete' // alias of mark_shot
  | 'finish'
  | 'expire'
  /** The customer's 100% cancel after a studio fault (#136 Decision 12). */
  | 'cancel_studio_fault'
  /** The clock cancels a studio booking still without an assignee at its start: 100% back (#136 ruling). */
  | 'cancel_unassigned_at_start';

export type ActorRole = 'customer' | 'photographer' | 'system';

export interface TransitionActor {
  readonly id?: string;
  readonly role: ActorRole;
}

export interface TransitionDecision {
  readonly nextStatus: BookingStatus;
  readonly refundPercent: number;
  readonly cancelRecord?: BookingCancel;
  /** `shot` decided by the shoot question (answer or expiry): the shoot is dated at the booking's end. */
  readonly shotAt?: string;
}

const HOUR_MS = 3_600_000;

/**
 * The scan window of a booking (spec §6.2, Decision 10): its day, from `start − 2 h` to
 * `end + CHECKIN_GRACE_HOURS`. Throws `too_early` (`details.opensAt`) earlier that day and `wrong_day`
 * (`details.day`) on any other day or after the window.
 */
export function assertBookingScanWindow(booking: Pick<Booking, 'day' | 'start' | 'end'>, now: Date): void {
  const opens = parseVnDateTime(booking.day, booking.start).getTime() - SCAN_OPEN_BEFORE_HOURS * HOUR_MS;
  const closes = parseVnDateTime(booking.day, booking.end).getTime() + CHECKIN_GRACE_HOURS * HOUR_MS;
  const t = now.getTime();
  if (t >= opens && t <= closes) return;
  if (t < opens && formatVnDate(now) === booking.day) {
    throw new DomainError('too_early', undefined, { opensAt: new Date(opens).toISOString() });
  }
  throw new DomainError('wrong_day', undefined, { day: booking.day });
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

      // If within 24h of start, transition directly to upcoming (a studio booking needs its assignee first)
      const hoursUntilStart = (startsAt.getTime() - now.getTime()) / (1000 * 60 * 60);
      const nextStatus: BookingStatus = hoursUntilStart <= 24 && !waitsForAssignee(booking) ? 'upcoming' : 'accepted';
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
      if (hoursUntilStart > 24 || waitsForAssignee(booking)) {
        throw new DomainError('conflict');
      }
      return { nextStatus: 'upcoming', refundPercent: 0 };
    }

    case 'cancel_studio_fault': {
      if (!['requested', 'accepted', 'upcoming'].includes(booking.status)) {
        throw new DomainError('conflict');
      }
      if (actor.role !== 'customer') {
        throw new DomainError('permission_denied');
      }
      const fault = studioFaultOf(booking, now);
      if (fault === null) {
        throw new DomainError('not_eligible');
      }
      return {
        nextStatus: 'cancelled',
        refundPercent: 100,
        cancelRecord: { by: 'studio_fault', reason: fault, at: now.toISOString(), refundPercent: 100 },
      };
    }

    case 'cancel_unassigned_at_start': {
      if (!['requested', 'accepted', 'upcoming'].includes(booking.status)) {
        throw new DomainError('conflict');
      }
      if (actor.role !== 'system') {
        throw new DomainError('permission_denied');
      }
      if (!waitsForAssignee(booking) || now.getTime() < startsAt.getTime()) {
        throw new DomainError('not_eligible');
      }
      return {
        nextStatus: 'cancelled',
        refundPercent: 100,
        cancelRecord: { by: 'studio_fault', reason: 'assign_overdue', at: now.toISOString(), refundPercent: 100 },
      };
    }

    case 'scan': {
      if (booking.status !== 'upcoming') {
        throw new DomainError('conflict');
      }
      if (actor.role !== 'photographer') {
        throw new DomainError('permission_denied');
      }
      if (waitsForAssignee(booking)) {
        throw new DomainError('not_eligible');
      }
      assertBookingScanWindow(booking, now);
      return { nextStatus: 'shooting', refundPercent: 0 };
    }

    case 'cancel': {
      // Spec §6.3: once the shooter scanned the pass, only a dispute is left.
      if (booking.status === 'shooting') {
        throw new DomainError('not_eligible');
      }
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

    case 'mark_shot':
    case 'complete': {
      if (!['accepted', 'upcoming', 'shooting'].includes(booking.status)) {
        throw new DomainError('conflict');
      }
      // Nobody shot a studio booking without an assignee: no payout (the clock cancels it at the start instead).
      if (waitsForAssignee(booking)) {
        throw new DomainError('not_eligible');
      }
      const shooting = booking.status === 'shooting';
      let shotAt: string | undefined;

      if (actor.role === 'photographer') {
        // Spec §6.3, Decision 14: a booking with a pass is done only after its scan ("Đã chụp xong" from
        // `shooting`, any time); one paid before passes keeps the old rule (after its end time).
        if (!shooting && booking.passCode4 !== undefined) {
          throw new DomainError('not_eligible');
        }
        if (!shooting && now.getTime() < endsAt.getTime()) {
          throw new DomainError('not_eligible');
        }
      } else if (actor.role === 'system') {
        // A scanned booking nobody marked done is shot 24 h after its end (Needs the owner 5). An unscanned
        // one only through the shoot question: answered "Có" or left unanswered (shot at its end time).
        if (shooting) {
          const autoTime = endsAt.getTime() + AUTO_COMPLETE_DELAY_HOURS * HOUR_MS;
          if (now.getTime() < autoTime) {
            throw new DomainError('conflict');
          }
        } else {
          if (booking.shootQuestionAt === undefined || booking.shootDeniedAt !== undefined) {
            throw new DomainError('conflict');
          }
          shotAt = endsAt.toISOString();
        }
      } else {
        throw new DomainError('permission_denied');
      }

      return shotAt === undefined ? { nextStatus: 'shot', refundPercent: 0 } : { nextStatus: 'shot', refundPercent: 0, shotAt };
    }

    case 'finish': {
      if (booking.status !== 'approved') {
        throw new DomainError('conflict');
      }

      if (actor.role === 'customer') {
        throw new DomainError('permission_denied');
      }

      if (booking.escrowStatus === 'disputed') {
        throw new DomainError('not_eligible');
      }

      if (!booking.checkUntil) {
        throw new DomainError('conflict');
      }

      const checkTime = new Date(booking.checkUntil).getTime();
      if (now.getTime() < checkTime) {
        throw new DomainError('conflict');
      }

      return { nextStatus: 'completed', refundPercent: 0 };
    }

    // Includes the retired 'review' action: a review goes through submitReview, which
    // sets reviewedAt; `reviewed` stays a readable legacy status only.
    default:
      throw new DomainError('invalid_argument');
  }
}
