/**
 * S27 collaborator offers on studio bookings (plan #151 Decisions 13, 14, 26), built on S26's assignment
 * (`studio_assignment.ts` routes `assignBooking` with `assigneeKind: 'collaborator'` here). The booking names
 * the collaborator at once but stays unassigned until they accept within 6 hours; the fee lives in the collab
 * job, never on the booking. Every transaction reads everything before its first write; notices go out after
 * the commit through #138's hooks.
 */

import type { Booking, StudioAssignment } from './booking.js';
import { parseVnDateTime } from './booking_policy.js';
import type { StudioBookingTx } from './booking_ports.js';
import { confirmedAssigneeId, newCollabJob, offerExpiry, type CollabJob } from './collab_jobs.js';
import { DomainError } from './errors.js';
import { notifyCollabAssignmentOffer, notifyCollabAssignmentResult } from './notification_hooks.js';
import { orderBlocker } from './order_gate.js';
import { isRecruitBlocked } from './recruit.js';
import { safely } from './recruit_shared.js';
import type { StudioBookingDeps } from './studio_assignment.js';
import {
  isAssignableStatus,
  isOpenForAssignment,
  liveJobOf,
  startOf,
  statusOnceAssigned,
  studioBooking,
} from './studio_booking_window.js';
import { studioDayLoadWith } from './studio_capacity.js';
import { fields, idField } from './studio_input.js';
import { vnHourDay } from './studio_notifications.js';

/** The assignments log with the latest entry of `uid` patched (the open offer). */
function patchLastEntry(
  entries: readonly StudioAssignment[] | undefined,
  uid: string,
  patch: Partial<StudioAssignment>,
): StudioAssignment[] {
  const list = [...(entries ?? [])];
  for (let i = list.length - 1; i >= 0; i--) {
    const e = list[i];
    if (e !== undefined && e.assigneeId === uid) {
      list[i] = { ...e, ...patch };
      break;
    }
  }
  return list;
}

/** "Giao người khác trước {deadline}": the assign deadline while ahead, else the start ('HH:mm dd/MM', VN). */
function reassignBy(b: Booking, now: Date): string {
  const deadline = b.assignDeadline ? Date.parse(b.assignDeadline) : NaN;
  return vnHourDay(now.getTime() < deadline ? new Date(deadline).toISOString() : startOf(b).toISOString());
}

/**
 * Decision 13, called by `assignBooking` once the caller is known to be the studio: the booking names the
 * collaborator (`assigneeAccepted: false`) and stays unassigned (no calendar block, chat membership or customer
 * notice; Decision 26) until they accept. Requires an active collaboration, the studio not recruit-blocked, the
 * collaborator verified, not blocked with the customer or the studio, free that day, and at least 15 minutes of
 * answer time. A confirmed assignee it replaces loses the day (late after the deadline, as S26) and hears it
 * through the booking write; an `upcoming` booking goes back to `accepted` until someone is confirmed.
 */
export async function offerToCollaborator(
  deps: StudioBookingDeps,
  booking: Booking,
  collaboratorId: string,
  agreedFee: number,
): Promise<Booking> {
  const studioId = booking.photographerId;
  const now = deps.clock.now();
  const nowIso = now.toISOString();
  if (!(await deps.providers.acceptsOrders(studioId))) throw new DomainError('not_accepting_orders');
  const blocker = await orderBlocker(deps, { customerId: booking.customerId, providerId: collaboratorId });
  if (blocker !== null) throw new DomainError(blocker);
  if (await deps.blocks.isBlockedEitherWay(studioId, collaboratorId)) throw new DomainError('blocked');

  const { next, job } = await deps.store.runTransaction(async (tx) => {
    const b = await tx.getBooking(booking.id);
    if (!b || b.version !== booking.version) throw new DomainError('conflict');
    if (!isOpenForAssignment(b, now)) throw new DomainError('not_eligible');
    if (b.assigneeId === collaboratorId) throw new DomainError('conflict');
    const collab = await tx.getCollaboration(studioId, collaboratorId);
    if (collab?.status !== 'active') throw new DomainError('not_found');
    if (isRecruitBlocked(await tx.getRecruitCounters(studioId), now)) throw new DomainError('recruit_blocked');
    const startsAt = startOf(b);
    const expiresAt = offerExpiry(now, b.assignDeadline ? new Date(b.assignDeadline) : startsAt, startsAt);
    if (expiresAt === null) throw new DomainError('deadline_passed');
    const day = await tx.getAvailabilityDay(collaboratorId, b.day);
    if (day && day.bookingId !== b.id) throw new DomainError('day_taken');
    const previous = confirmedAssigneeId(b);
    const oldDay = previous ? await tx.getAvailabilityDay(previous, b.day) : null;
    const load = previous ? await tx.getStudioDayLoad(studioId, b.day) : null;
    const oldJob = await liveJobOf(tx, b);
    // ---- writes ----
    const late = !!previous && !!b.assignDeadline && now.getTime() >= Date.parse(b.assignDeadline);
    if (previous) {
      if (oldDay?.bookingId === b.id) await tx.deleteAvailabilityDay(previous, b.day);
      await tx.setStudioDayLoad(studioDayLoadWith(load, { studioId, day: b.day }, b.id, 'unassigned', nowIso));
    }
    if (late) tx.incrementStudioCounter(studioId, 'lateReassignCount');
    if (oldJob) tx.putCollabJob({ ...oldJob, offerStatus: 'replaced', updatedAt: now });
    const job = newCollabJob({
      booking: b,
      collaboratorId,
      studioName: collab.studio.name,
      collaboratorName: collab.collaborator.name,
      shootEndsAt: parseVnDateTime(b.day, b.end),
      agreedFee,
      offerExpiresAt: expiresAt,
      now,
    });
    tx.putCollabJob(job);
    const entry: StudioAssignment = {
      assigneeId: collaboratorId,
      assigneeKind: 'collaborator',
      at: nowIso,
      by: studioId,
      reason: null,
      late,
      offerExpiresAt: expiresAt.toISOString(),
    };
    const status = b.status === 'upcoming' ? 'accepted' : b.status;
    const next: Booking = {
      ...b,
      assigneeId: collaboratorId,
      assigneeKind: 'collaborator',
      assigneeAccepted: false,
      assignStatus: 'unassigned',
      assignments: [...(b.assignments ?? []), entry],
      changeRequest:
        b.changeRequest?.status === 'pending'
          ? { ...b.changeRequest, status: 'reassigned', answeredAt: nowIso }
          : (b.changeRequest ?? null),
      studioFault: late ? { kind: 'late_reassign', at: nowIso } : (b.studioFault ?? null),
      assignmentReturned: null,
      status,
      version: b.version + 1,
      updatedAt: nowIso,
    };
    await tx.setBooking(next);
    if (status !== b.status) {
      await tx.addBookingEvent({ id: deps.ids.newId(), bookingId: b.id, status, at: nowIso, actorId: studioId });
    }
    return { next, job };
  });

  const notify = deps.notify;
  if (notify) {
    await safely({ notify }, collaboratorId, () => notifyCollabAssignmentOffer(notify, {
      collaboratorId,
      studioId,
      bookingId: next.id,
      offerAt: job.offerAt.toISOString(),
      service: next.serviceSnapshot.name,
      day: next.day,
      start: next.start,
      fee: job.agreedFee,
      deadline: vnHourDay(job.offerExpiresAt.toISOString()),
    }));
  }
  return next;
}

/** The writes that end an open offer: the job closed, the booking's assignee cleared (deadline kept). */
async function closeOffer(
  tx: StudioBookingTx,
  b: Booking,
  job: CollabJob,
  to: 'declined' | 'expired' | 'cancelled',
  now: Date,
): Promise<void> {
  const nowIso = now.toISOString();
  tx.putCollabJob({
    ...job,
    offerStatus: to,
    declinedAt: to === 'declined' ? now : job.declinedAt,
    updatedAt: now,
  });
  await tx.setBooking({
    ...b,
    assigneeId: null,
    assigneeKind: null,
    assigneeAccepted: false,
    assignments: to === 'declined' ? patchLastEntry(b.assignments, job.collaboratorId, { declinedAt: nowIso }) : b.assignments,
    version: b.version + 1,
    updatedAt: nowIso,
  });
}

/** `collab_assignment_result` to the studio, keyed by the answered offer. */
async function notifyOfferResult(
  deps: StudioBookingDeps,
  b: Booking,
  job: CollabJob,
  outcome: 'accepted' | 'declined' | 'expired' | 'ended',
  now: Date,
): Promise<void> {
  const notify = deps.notify;
  if (!notify) return;
  await safely({ notify }, b.photographerId, () => notifyCollabAssignmentResult(notify, {
    studioId: b.photographerId,
    collaboratorId: job.collaboratorId,
    bookingId: b.id,
    offerAt: job.offerAt.toISOString(),
    outcome,
    service: b.serviceSnapshot.name,
    day: b.day,
    start: b.start,
    deadline: reassignBy(b, now),
  }));
}

type OfferAnswer = {
  readonly kind: 'accepted' | 'declined' | 'ended';
  readonly booking: Booking;
  readonly job: CollabJob;
};

/**
 * The collaborator answers the offer in S27.07 (`{bookingId, accept}`), before `offerExpiresAt`. Accepting
 * re-checks the gates and the day (`day_taken` leaves the offer pending; a day the collaborator marked off does
 * not stop them), then books their day, moves the booking to the studio's assigned load and confirms it
 * (S26's `booking_assigned`, or `booking_reassigned` when it replaced a confirmed assignee, reaches the customer
 * through the booking write; chat membership follows the same write). Declining clears the assignee; S26's
 * deadline and overdue path carry on. If the collaboration ended meanwhile, the offer is closed and the studio
 * told (`ended`): a decline then succeeds quietly, an accept is refused `not_found`.
 */
export async function respondCollabOffer(
  deps: StudioBookingDeps,
  uid: string,
  raw: unknown,
): Promise<{ offerStatus: 'accepted' | 'declined' }> {
  const r = fields(raw);
  const bookingId = idField(r, 'bookingId');
  if (typeof r.accept !== 'boolean') throw new DomainError('invalid_argument', 'accept');
  const accept = r.accept;
  const now = deps.clock.now();
  const nowIso = now.toISOString();

  const pre = await studioBooking(deps, bookingId);
  if (pre.assigneeId !== uid || pre.assigneeKind !== 'collaborator') throw new DomainError('permission_denied');
  if (accept) {
    const blocker = await orderBlocker(deps, { customerId: pre.customerId, providerId: uid });
    if (blocker !== null) throw new DomainError(blocker);
    if (await deps.blocks.isBlockedEitherWay(pre.photographerId, uid)) throw new DomainError('blocked');
  }

  const answer = await deps.store.runTransaction(async (tx): Promise<OfferAnswer> => {
    const b = await tx.getBooking(bookingId);
    if (!b) throw new DomainError('not_found');
    if (b.assigneeId !== uid || b.assigneeKind !== 'collaborator') throw new DomainError('permission_denied');
    const job = await tx.getCollabJob(b.id, uid);
    if (!job) throw new DomainError('permission_denied');
    if (job.offerStatus !== 'pending' || job.offerExpiresAt.getTime() <= now.getTime()) {
      throw new DomainError('deadline_passed');
    }
    if (!isOpenForAssignment(b, now)) throw new DomainError('not_eligible');
    const collab = await tx.getCollaboration(b.photographerId, uid);
    if (collab?.status !== 'active') {
      await closeOffer(tx, b, job, 'cancelled', now);
      return { kind: 'ended', booking: b, job };
    }
    if (!accept) {
      await closeOffer(tx, b, job, 'declined', now);
      return { kind: 'declined', booking: b, job };
    }
    const day = await tx.getAvailabilityDay(uid, b.day);
    if (day && day.state !== 'off' && day.bookingId !== b.id) throw new DomainError('day_taken');
    const load = await tx.getStudioDayLoad(b.photographerId, b.day);
    // ---- writes ----
    await tx.setAvailabilityDay(uid, b.day, { state: 'booked', bookingId: b.id });
    await tx.setStudioDayLoad(studioDayLoadWith(load, { studioId: b.photographerId, day: b.day }, b.id, 'assigned', nowIso));
    tx.putCollabJob({ ...job, offerStatus: 'accepted', acceptedAt: now, updatedAt: now });
    const status = statusOnceAssigned(b, now);
    const next: Booking = {
      ...b,
      assigneeAccepted: true,
      assignStatus: 'assigned',
      assignedAt: nowIso,
      assignments: patchLastEntry(b.assignments, uid, { acceptedAt: nowIso }),
      studioFault: b.studioFault?.kind === 'assign_overdue' ? null : (b.studioFault ?? null),
      status,
      version: b.version + 1,
      updatedAt: nowIso,
    };
    await tx.setBooking(next);
    if (status !== b.status) {
      await tx.addBookingEvent({ id: deps.ids.newId(), bookingId: b.id, status, at: nowIso, actorId: uid });
    }
    return { kind: 'accepted', booking: next, job };
  });

  await notifyOfferResult(deps, answer.booking, answer.job, answer.kind, now);
  if (answer.kind === 'ended') {
    if (accept) throw new DomainError('not_found');
    return { offerStatus: 'declined' };
  }
  return { offerStatus: answer.kind };
}

/**
 * Sweep step (`runRecruitSweeps`): a pending offer past `offerExpiresAt` lapses like a decline (`expired`, the
 * assignee cleared, the studio told: `ended` when the collaboration ended meanwhile; not a violation). An offer
 * whose booking was cancelled or moved on closes quietly. False when it no longer qualifies.
 */
export async function expireCollabOffer(deps: StudioBookingDeps, bookingId: string, collaboratorId: string): Promise<boolean> {
  const now = deps.clock.now();
  const expired = await deps.store.runTransaction(async (tx) => {
    const job = await tx.getCollabJob(bookingId, collaboratorId);
    if (!job || job.offerStatus !== 'pending' || job.offerExpiresAt.getTime() > now.getTime()) return null;
    const b = await tx.getBooking(bookingId);
    const named = b !== null && b.assigneeId === collaboratorId && b.assigneeKind === 'collaborator' && b.assigneeAccepted !== true;
    if (b !== null && named && isAssignableStatus(b.status)) {
      const collab = await tx.getCollaboration(b.photographerId, collaboratorId);
      await closeOffer(tx, b, job, 'expired', now);
      return { booking: b, job, outcome: collab?.status === 'active' ? ('expired' as const) : ('ended' as const) };
    }
    tx.putCollabJob({ ...job, offerStatus: 'expired', updatedAt: now });
    return { booking: null, job, outcome: 'expired' as const };
  });
  if (expired === null) return false;
  if (expired.booking !== null) await notifyOfferResult(deps, expired.booking, expired.job, expired.outcome, now);
  return true;
}
