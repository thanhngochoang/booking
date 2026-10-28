/**
 * Use case: transitionBooking
 * Transition booking lifecycle state driven by customer, photographer or system.
 */

import type { Booking } from './booking.js';
import { decideTransition, roleOf, type TransitionAction } from './booking_machine.js';
import type { BookingDeps } from './booking_ports.js';
import { confirmedAssigneeId } from './collab_jobs.js';
import { commitTransition } from './commit_transition.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';

/** What a studio booking's assignee may do through transitionBooking. */
const ASSIGNEE_ACTIONS: readonly TransitionAction[] = ['mark_shot', 'complete'];

export interface TransitionBookingInput {
  readonly bookingId: string;
  readonly action: TransitionAction;
  readonly actorId?: string;
  readonly reason?: string;
  /**
   * S30 (S05.03 "Giữ vé vào cửa"): a customer cancelling a booking with tickets keeps the tickets
   * (still paid, still usable). Ignored for every other cancel.
   */
  readonly keepTickets?: boolean;
}

export async function transitionBooking(
  deps: BookingDeps,
  input: TransitionBookingInput,
): Promise<Booking> {
  if (!isId(input.bookingId)) {
    throw new DomainError('invalid_argument');
  }
  // S30: `upcoming → shooting` happens only through scanPass (the customer's pass proves the meeting).
  if (input.action === 'scan') {
    throw new DomainError('invalid_argument');
  }

  const booking = await deps.store.getBooking(input.bookingId);
  if (!booking) {
    throw new DomainError('not_found');
  }

  // Determine actor role. A studio's assignee acts for the studio only to mark the shoot done (#136 Decision 15);
  // a collaborator only once the offer is accepted (S27).
  let role: 'customer' | 'photographer' | 'system';
  let actingId = input.actorId;
  if (!input.actorId) {
    role = 'system';
  } else {
    const determinedRole = roleOf(input.actorId, booking);
    if (determinedRole) {
      role = determinedRole;
    } else if (
      booking.isStudio === true &&
      confirmedAssigneeId(booking) === input.actorId &&
      ASSIGNEE_ACTIONS.includes(input.action)
    ) {
      role = 'photographer';
      actingId = booking.photographerId;
    } else {
      throw new DomainError('permission_denied');
    }
  }

  const now = deps.clock.now();
  const decision = decideTransition(
    booking,
    input.action,
    { id: actingId, role },
    now,
    input.reason,
  );

  return commitTransition(deps, booking, decision, input.actorId, { keepTickets: input.keepTickets === true });
}
