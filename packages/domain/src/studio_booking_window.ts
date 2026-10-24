/**
 * The small S26 studio-booking helpers shared by member assignment (`studio_assignment.ts`) and S27
 * collaborator offers (`collab_offers.ts`). Internal: `studio_assignment.ts` re-exports the public ones.
 */

import type { Booking } from './booking.js';
import { parseVnDateTime } from './booking_policy.js';
import type { BookingDeps, StudioBookingTx } from './booking_ports.js';
import { isLiveOffer, type CollabJob } from './collab_jobs.js';
import { DomainError } from './errors.js';

export const STUDIO_ASSIGN_LEAD_HOURS = 24;

export const HOUR_MS = 60 * 60 * 1000;
const ASSIGNABLE_STATUSES: readonly string[] = ['accepted', 'upcoming'];

/** The booking of a studio, or not_found (an individual booking has nothing to assign). */
export async function studioBooking(deps: Pick<BookingDeps, 'store'>, bookingId: string): Promise<Booking> {
  const b = await deps.store.getBooking(bookingId);
  if (!b || b.isStudio !== true) throw new DomainError('not_found');
  return b;
}

export function startOf(b: Booking): Date {
  return parseVnDateTime(b.day, b.start);
}

/** accepted or upcoming (whatever the time): the statuses a studio booking can be (re)assigned in. */
export const isAssignableStatus = (status: string): boolean => ASSIGNABLE_STATUSES.includes(status);

/** accepted or upcoming, before the start: the window for assigning, changing and returning. */
export function isOpenForAssignment(b: Booking, now: Date): boolean {
  return isAssignableStatus(b.status) && now.getTime() < startOf(b).getTime();
}

/** The status once an assignee is confirmed: an accepted booking inside 24 h of its start becomes upcoming. */
export function statusOnceAssigned(b: Booking, now: Date): Booking['status'] {
  return b.status === 'accepted' && startOf(b).getTime() - now.getTime() <= STUDIO_ASSIGN_LEAD_HOURS * HOUR_MS
    ? 'upcoming'
    : b.status;
}

/** The current assignee's live collab job, read before any write (a member has none). */
export async function liveJobOf(tx: StudioBookingTx, b: Booking): Promise<CollabJob | null> {
  if (b.assigneeKind !== 'collaborator' || !b.assigneeId) return null;
  const job = await tx.getCollabJob(b.id, b.assigneeId);
  return job !== null && isLiveOffer(job) ? job : null;
}
