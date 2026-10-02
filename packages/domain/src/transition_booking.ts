/**
 * Use case: transitionBooking
 * Transition booking lifecycle state driven by customer, photographer or system.
 */

import type { Booking } from './booking.js';
import { decideTransition, roleOf, type TransitionAction } from './booking_machine.js';
import type { BookingDeps } from './booking_ports.js';
import { commitTransition } from './commit_transition.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';

export interface TransitionBookingInput {
  readonly bookingId: string;
  readonly action: TransitionAction;
  readonly actorId?: string;
  readonly reason?: string;
}

export async function transitionBooking(
  deps: BookingDeps,
  input: TransitionBookingInput,
): Promise<Booking> {
  if (!isId(input.bookingId)) {
    throw new DomainError('invalid_argument');
  }

  const booking = await deps.store.getBooking(input.bookingId);
  if (!booking) {
    throw new DomainError('not_found');
  }

  // Determine actor role
  let role: 'customer' | 'photographer' | 'system';
  if (!input.actorId) {
    role = 'system';
  } else {
    const determinedRole = roleOf(input.actorId, booking);
    if (!determinedRole) {
      throw new DomainError('permission_denied');
    }
    role = determinedRole;
  }

  const now = deps.clock.now();
  const decision = decideTransition(
    booking,
    input.action,
    { id: input.actorId, role },
    now,
    input.reason,
  );

  return commitTransition(deps, booking, decision, input.actorId);
}
