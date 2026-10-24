/**
 * Studio bookings (#136, spec §5): the studio fields every order path gets through the booking-draft builder,
 * assignment of a member, the customer's one change request, "Trả việc" and the studio-fault refund right (the
 * clock sweeps are in studio_booking_sweeps.ts). S27 (#151) adds offers to collaborators: the booking names
 * the collaborator at once but stays unassigned until they accept within 6 hours; the fee lives in the collab
 * job, never on the booking. Every transaction reads everything before its first write.
 */

import type { Booking, StudioAssignment, StudioFaultKind } from './booking.js';
import { parseVnDateTime } from './booking_policy.js';
import type { BookingDeps, StudioBookingStore, StudioBookingTx } from './booking_ports.js';
import {
  confirmedAssigneeId,
  isLiveOffer,
  newCollabJob,
  offerExpiry,
  type CollabJob,
} from './collab_jobs.js';
import { DomainError } from './errors.js';
import { notifyCollabAssignmentOffer, notifyCollabAssignmentResult } from './notification_hooks.js';
import type { NotifyDeps } from './notification_ports.js';
import { orderBlocker } from './order_gate.js';
import type { ProviderType } from './provider_type.js';
import { isRecruitBlocked, isValidRecruitFee } from './recruit.js';
import { safely } from './recruit_shared.js';
import { studioDayLoadWith } from './studio_capacity.js';
import { fields, idField, optionalText, requiredText } from './studio_input.js';
import { vnHourDay } from './studio_notifications.js';
import type { StudioRoster } from './studio_ports.js';

export const STUDIO_ASSIGN_LEAD_HOURS = 24,
  STUDIO_LATE_BOOKING_GRACE_HOURS = 2,
  CHANGE_RESPOND_HOURS = 6,
  ASSIGN_REMINDER_HOURS = [48, 26] as const;
export { STUDIO_NOTE_MAX_LENGTH } from './studio_input.js';

const HOUR_MS = 60 * 60 * 1000;
const ASSIGNABLE_STATUSES: readonly string[] = ['accepted', 'upcoming'];

export interface StudioBookingDeps extends BookingDeps {
  readonly store: StudioBookingStore;
  readonly roster: StudioRoster;
  /**
   * S27: the collaborator-offer notices (`collab_assignment_offer`, `collab_assignment_result`) go out after the
   * commit through #138's hooks. Absent → they are not sent (member flows notify from the booking trigger).
   */
  readonly notify?: NotifyDeps;
}

/** max(startAt − 24 h, now + 2 h), never after startAt (Decision 8; a booking made less than a day ahead gives the studio two hours). */
export function assignDeadlineFor(startAt: Date, now: Date): Date {
  const lead = startAt.getTime() - STUDIO_ASSIGN_LEAD_HOURS * HOUR_MS;
  const grace = now.getTime() + STUDIO_LATE_BOOKING_GRACE_HOURS * HOUR_MS;
  return new Date(Math.min(startAt.getTime(), Math.max(lead, grace)));
}

/** The studio fields of a new booking draft (#199's `slot #136 (studio)`); {} unless the provider is a studio. */
export function studioDraftFields(
  i: { readonly providerType?: ProviderType | null; readonly now: Date },
  core: Pick<Booking, 'day' | 'start'>,
): Partial<Booking> {
  if (i.providerType !== 'studio') return {};
  const startAt = parseVnDateTime(core.day, core.start);
  return {
    isStudio: true,
    assigneeId: null,
    assigneeKind: null,
    assignStatus: 'unassigned',
    assignDeadline: assignDeadlineFor(startAt, i.now).toISOString(),
    assignOverdue: false,
    assignedAt: null,
    assignments: [],
    assignRemindersSent: [],
    changeRequest: null,
    studioFault: null,
    assignmentReturned: null,
  };
}

/**
 * Why the customer may cancel with a 100% refund now, or null. A recorded fault counts until the start; an
 * unassigned booking past its deadline counts even before the sweep marks it, and stops when the studio assigns.
 */
export function studioFaultOf(b: Booking, now: Date): StudioFaultKind | null {
  if (b.isStudio !== true) return null;
  if (now.getTime() >= parseVnDateTime(b.day, b.start).getTime()) return null;
  if (b.studioFault) return b.studioFault.kind;
  if (b.assignStatus !== 'assigned' && b.assignDeadline && now.getTime() >= Date.parse(b.assignDeadline)) {
    return 'assign_overdue';
  }
  return null;
}

/**
 * A studio booking with nobody assigned: it never reaches `upcoming` (Decision 11), cannot be marked shot or
 * completed, and the clock cancels it at its start. A collaborator whose offer still waits is nobody yet (S27).
 */
export function waitsForAssignee(
  booking: Pick<Booking, 'isStudio' | 'assigneeId'> & Partial<Pick<Booking, 'assigneeKind' | 'assigneeAccepted'>>,
): boolean {
  return booking.isStudio === true && confirmedAssigneeId(booking) === null;
}

/**
 * The clock's cancel of a studio booking still unassigned at its start (`cancel_unassigned_at_start`): a
 * `studio_fault` cancel made at or after the start, which the customer's own cancel never is.
 */
export function isUnassignedStartCancel(b: Booking): boolean {
  return (
    b.isStudio === true &&
    b.cancel?.by === 'studio_fault' &&
    Date.parse(b.cancel.at) >= parseVnDateTime(b.day, b.start).getTime()
  );
}

/** The booking of a studio, or not_found (an individual booking has nothing to assign). */
async function studioBooking(deps: Pick<BookingDeps, 'store'>, bookingId: string): Promise<Booking> {
  const b = await deps.store.getBooking(bookingId);
  if (!b || b.isStudio !== true) throw new DomainError('not_found');
  return b;
}

function startOf(b: Booking): Date {
  return parseVnDateTime(b.day, b.start);
}

/** accepted or upcoming, before the start: the window for assigning, changing and returning. */
export function isOpenForAssignment(b: Booking, now: Date): boolean {
  return ASSIGNABLE_STATUSES.includes(b.status) && now.getTime() < startOf(b).getTime();
}

// ── assignment ──

/** The offer part of an `assignBooking` input: null for a member; the agreed fee for a collaborator (Decision 13). */
function collaboratorOfferOf(r: Record<string, unknown>): { readonly agreedFee: number } | null {
  const kind = r.assigneeKind ?? 'member';
  if (kind !== 'member' && kind !== 'collaborator') throw new DomainError('invalid_argument', 'assigneeKind');
  if (kind === 'member') return null;
  if (!isValidRecruitFee(r.agreedFee)) throw new DomainError('invalid_argument', 'agreedFee');
  return { agreedFee: r.agreedFee };
}

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

/** The current assignee's live collab job, read before any write (a member has none). */
async function liveJobOf(tx: StudioBookingTx, b: Booking): Promise<CollabJob | null> {
  if (b.assigneeKind !== 'collaborator' || !b.assigneeId) return null;
  const job = await tx.getCollabJob(b.id, b.assigneeId);
  return job !== null && isLiveOffer(job) ? job : null;
}

/** "Giao người khác trước {deadline}": the assign deadline while ahead, else the start ('HH:mm dd/MM', VN). */
function reassignBy(b: Booking, now: Date): string {
  const deadline = b.assignDeadline ? Date.parse(b.assignDeadline) : NaN;
  return vnHourDay(now.getTime() < deadline ? new Date(deadline).toISOString() : startOf(b).toISOString());
}

/**
 * The studio owner assigns (or reassigns) a member (Decision 10), or offers the booking to an active
 * collaborator with `{assigneeKind: 'collaborator', agreedFee}` (S27 Decision 13). The studio must still take
 * orders, the assignee passes #198's gate (verified, not blocked with the customer) and must be free that day.
 * A new assignment replaces a pending or accepted collaborator's job (`replaced`).
 */
export async function assignBooking(deps: StudioBookingDeps, callerId: string, raw: unknown): Promise<Booking> {
  const r = fields(raw);
  const bookingId = idField(r, 'bookingId');
  const assigneeId = idField(r, 'assigneeId');
  const offer = collaboratorOfferOf(r);
  const now = deps.clock.now();
  const nowIso = now.toISOString();

  const booking = await studioBooking(deps, bookingId);
  if (booking.photographerId !== callerId) throw new DomainError('permission_denied');
  // #194 Decision 7: a spot booking keeps the schedule's member (cancel and book again to change it).
  if (booking.spotScheduleId !== undefined) throw new DomainError('not_eligible');
  if (offer !== null) return offerToCollaborator(deps, booking, assigneeId, offer.agreedFee);
  const kind = await deps.roster.relationOf(booking.photographerId, assigneeId);
  if (kind !== 'member') throw new DomainError('permission_denied');
  if (!(await deps.providers.acceptsOrders(booking.photographerId))) throw new DomainError('not_accepting_orders');
  const blocker = await orderBlocker(deps, { customerId: booking.customerId, providerId: assigneeId });
  if (blocker !== null) throw new DomainError(blocker);

  return deps.store.runTransaction(async (tx) => {
    const b = await tx.getBooking(booking.id);
    if (!b || b.version !== booking.version) throw new DomainError('conflict');
    const startsAt = startOf(b);
    if (!isOpenForAssignment(b, now)) throw new DomainError('not_eligible');
    if (b.assigneeId === assigneeId) throw new DomainError('conflict');
    // The member may have been removed since the roster check: the member document is the membership lock.
    if ((await tx.getMemberStudio(assigneeId)) !== b.photographerId) {
      throw new DomainError('permission_denied');
    }
    const day = await tx.getAvailabilityDay(assigneeId, b.day);
    if (day && day.bookingId !== b.id) throw new DomainError('day_taken');
    // A collaborator whose offer still waits was never the assignee: no day, no late reassignment.
    const previous = confirmedAssigneeId(b);
    const oldDay = previous ? await tx.getAvailabilityDay(previous, b.day) : null;
    const load = await tx.getStudioDayLoad(b.photographerId, b.day);
    const oldJob = await liveJobOf(tx, b);
    // ---- writes ----
    const late = !!previous && !!b.assignDeadline && now.getTime() >= Date.parse(b.assignDeadline);
    await tx.setAvailabilityDay(assigneeId, b.day, { state: 'booked', bookingId: b.id });
    if (previous && oldDay?.bookingId === b.id) await tx.deleteAvailabilityDay(previous, b.day);
    await tx.setStudioDayLoad(studioDayLoadWith(load, { studioId: b.photographerId, day: b.day }, b.id, 'assigned', nowIso));
    if (late) tx.incrementStudioCounter(b.photographerId, 'lateReassignCount');
    if (oldJob) tx.putCollabJob({ ...oldJob, offerStatus: 'replaced', updatedAt: now });

    const entry: StudioAssignment = { assigneeId, assigneeKind: 'member', at: nowIso, by: callerId, reason: null, late };
    const status =
      b.status === 'accepted' && startsAt.getTime() - now.getTime() <= STUDIO_ASSIGN_LEAD_HOURS * HOUR_MS
        ? 'upcoming'
        : b.status;
    const next: Booking = {
      ...b,
      assigneeId,
      assigneeKind: 'member',
      assigneeAccepted: true,
      assignStatus: 'assigned',
      assignedAt: nowIso,
      assignments: [...(b.assignments ?? []), entry],
      changeRequest:
        b.changeRequest?.status === 'pending'
          ? { ...b.changeRequest, status: 'reassigned', answeredAt: nowIso }
          : (b.changeRequest ?? null),
      studioFault: late
        ? { kind: 'late_reassign', at: nowIso }
        : b.studioFault?.kind === 'assign_overdue'
          ? null
          : (b.studioFault ?? null),
      assignmentReturned: null,
      status,
      version: b.version + 1,
      updatedAt: nowIso,
    };
    await tx.setBooking(next);
    if (status !== b.status) {
      await tx.addBookingEvent({ id: deps.ids.newId(), bookingId: b.id, status, at: nowIso, actorId: callerId });
    }
    return next;
  });
}

/**
 * S27 Decision 13: the booking names the collaborator (`assigneeAccepted: false`) and stays unassigned (no
 * calendar block, chat membership or customer notice; Decision 26) until they accept. Requires an active
 * collaboration, the studio not recruit-blocked, the collaborator verified, not blocked with the customer or the
 * studio, free that day, and at least 15 minutes of answer time. A confirmed assignee it replaces loses the day
 * (late after the deadline, as S26); an `upcoming` booking goes back to `accepted` until someone is confirmed.
 */
async function offerToCollaborator(
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

  const done = await deps.store.runTransaction(async (tx) => {
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

  const { next, job } = done;
  const notify = deps.notify;
  if (notify) {
    await safely({ notify }, collaboratorId, () => notifyCollabAssignmentOffer(notify, {
      collaboratorId,
      studioId,
      bookingId: next.id,
      service: next.serviceSnapshot.name,
      day: next.day,
      start: next.start,
      fee: job.agreedFee,
      deadline: vnHourDay(job.offerExpiresAt.toISOString()),
    }));
  }
  return next;
}

type OfferClose = 'declined' | 'expired' | 'cancelled';

/** The writes that end an open offer: the job closed, the booking's assignee cleared (deadline kept). */
async function closeOffer(tx: StudioBookingTx, b: Booking, job: CollabJob, to: OfferClose, now: Date): Promise<void> {
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

async function notifyOfferResult(
  deps: StudioBookingDeps,
  b: Booking,
  collaboratorId: string,
  outcome: 'accepted' | 'declined' | 'expired',
  now: Date,
): Promise<void> {
  const notify = deps.notify;
  if (!notify) return;
  await safely({ notify }, b.photographerId, () => notifyCollabAssignmentResult(notify, {
    studioId: b.photographerId,
    collaboratorId,
    bookingId: b.id,
    outcome,
    service: b.serviceSnapshot.name,
    day: b.day,
    start: b.start,
    deadline: reassignBy(b, now),
  }));
}

type OfferAnswer =
  | { readonly kind: 'accepted'; readonly booking: Booking }
  | { readonly kind: 'declined'; readonly booking: Booking }
  | { readonly kind: 'ended'; readonly booking: Booking };

/**
 * The collaborator answers the offer in S27.07 (`{bookingId, accept}`), before `offerExpiresAt`. Accepting
 * re-checks the gates and the day (`day_taken` leaves the offer pending; a day the collaborator marked off does
 * not stop them), then books their day, moves the booking to the studio's assigned load and confirms it
 * (`booking_assigned` reaches the customer through the booking write; chat membership follows the same write).
 * Declining clears the assignee; S26's deadline and overdue path carry on. An offer whose collaboration ended
 * meanwhile is closed and refused (`not_found`).
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
      return { kind: 'ended', booking: b };
    }
    if (!accept) {
      await closeOffer(tx, b, job, 'declined', now);
      return { kind: 'declined', booking: b };
    }
    const day = await tx.getAvailabilityDay(uid, b.day);
    if (day && day.state !== 'off' && day.bookingId !== b.id) throw new DomainError('day_taken');
    const load = await tx.getStudioDayLoad(b.photographerId, b.day);
    // ---- writes ----
    await tx.setAvailabilityDay(uid, b.day, { state: 'booked', bookingId: b.id });
    await tx.setStudioDayLoad(studioDayLoadWith(load, { studioId: b.photographerId, day: b.day }, b.id, 'assigned', nowIso));
    tx.putCollabJob({ ...job, offerStatus: 'accepted', acceptedAt: now, updatedAt: now });
    const status =
      b.status === 'accepted' && startOf(b).getTime() - now.getTime() <= STUDIO_ASSIGN_LEAD_HOURS * HOUR_MS
        ? 'upcoming'
        : b.status;
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
    return { kind: 'accepted', booking: next };
  });

  await notifyOfferResult(deps, answer.booking, uid, answer.kind === 'ended' ? 'expired' : answer.kind, now);
  if (answer.kind === 'ended') throw new DomainError('not_found');
  return { offerStatus: answer.kind };
}

/**
 * Sweep step (`runRecruitSweeps`): a pending offer past `offerExpiresAt` lapses like a decline (`expired`, the
 * assignee cleared, the studio told; not a violation). False when it no longer qualifies.
 */
export async function expireCollabOffer(deps: StudioBookingDeps, bookingId: string, collaboratorId: string): Promise<boolean> {
  const now = deps.clock.now();
  const expired = await deps.store.runTransaction(async (tx) => {
    const job = await tx.getCollabJob(bookingId, collaboratorId);
    if (!job || job.offerStatus !== 'pending' || job.offerExpiresAt.getTime() > now.getTime()) return null;
    const b = await tx.getBooking(bookingId);
    const named = b !== null && b.assigneeId === collaboratorId && b.assigneeKind === 'collaborator' && b.assigneeAccepted !== true;
    if (b !== null && named && ASSIGNABLE_STATUSES.includes(b.status)) {
      await closeOffer(tx, b, job, 'expired', now);
      return { booking: b };
    }
    // The booking moved on (cancelled, or no longer naming this offer): close the job quietly.
    tx.putCollabJob({ ...job, offerStatus: 'expired', updatedAt: now });
    return { booking: null };
  });
  if (expired === null) return false;
  if (expired.booking !== null) await notifyOfferResult(deps, expired.booking, collaboratorId, 'expired', now);
  return true;
}

/** One member row of S26.04. */
export interface AssignmentOption {
  readonly uid: string;
  readonly name: string;
  readonly avatarUrl: string | null;
  readonly tomatoPct: number | null;
  readonly reviewCount: number;
  readonly state: 'free' | 'busy' | 'off' | 'unverified' | 'current';
  readonly busyStart: string | null;
  readonly busyEnd: string | null;
}

/** Reads behind S26.04 (Decision 18): the members, each member's own day (with the occupying booking's times) and stats. */
export interface MemberDayReader {
  /** Active member uids. */
  members(studioId: string): Promise<string[]>;
  /** `spot` (#194 Decision 6): the member holds the day for an open spot schedule; start/end = its window. */
  day(
    uid: string,
    day: string,
  ): Promise<{ state: 'off' | 'booked' | 'pending' | 'spot'; start: string | null; end: string | null } | null>;
  stats(uid: string): Promise<{ tomatoPct: number | null; reviewCount: number }>;
}

/** S26.04: every active member with whether they can take this booking. Studio owner only. */
export async function assignmentOptions(
  deps: StudioBookingDeps & { readonly availability: MemberDayReader },
  callerId: string,
  raw: unknown,
): Promise<AssignmentOption[]> {
  const bookingId = idField(fields(raw), 'bookingId');
  const b = await studioBooking(deps, bookingId);
  if (b.photographerId !== callerId) throw new DomainError('permission_denied');

  const uids = await deps.availability.members(b.photographerId);
  return Promise.all(
    uids.map(async (uid): Promise<AssignmentOption> => {
      const [person, stats, verified, day] = await Promise.all([
        deps.roster.person(uid),
        deps.availability.stats(uid),
        deps.providers.acceptsOrders(uid),
        deps.availability.day(uid, b.day),
      ]);
      const base = {
        uid,
        name: person?.name ?? '',
        avatarUrl: person?.avatarUrl ?? null,
        tomatoPct: stats.tomatoPct,
        reviewCount: stats.reviewCount,
        busyStart: null,
        busyEnd: null,
      };
      if (uid === b.assigneeId) return { ...base, state: 'current' };
      if (!verified) return { ...base, state: 'unverified' };
      if (day === null) return { ...base, state: 'free' };
      if (day.state === 'off') return { ...base, state: 'off' };
      return { ...base, state: 'busy', busyStart: day.start, busyEnd: day.end };
    }),
  );
}

// ── change request (S26.05) ──

/** The customer's one change request (Decision 13): booking assigned, accepted or upcoming, before the start. */
export async function requestAssigneeChange(deps: StudioBookingDeps, customerId: string, raw: unknown): Promise<Booking> {
  const r = fields(raw);
  const bookingId = idField(r, 'bookingId');
  const note = optionalText(r.note);
  const now = deps.clock.now();
  const nowIso = now.toISOString();

  const pre = await studioBooking(deps, bookingId);
  if (pre.customerId !== customerId) throw new DomainError('permission_denied');
  // #194 Decision 7: a spot booking keeps the schedule's member (cancel and book again to change it).
  if (pre.spotScheduleId !== undefined) throw new DomainError('not_eligible');

  return deps.store.runTransaction(async (tx) => {
    const b = await tx.getBooking(bookingId);
    if (!b) throw new DomainError('not_found');
    if (b.changeRequest) throw new DomainError('conflict');
    // The customer sees no assignee while a collaborator's offer waits.
    if (!isOpenForAssignment(b, now) || !confirmedAssigneeId(b)) throw new DomainError('not_eligible');
    const respondBy = Math.min(now.getTime() + CHANGE_RESPOND_HOURS * HOUR_MS, startOf(b).getTime());
    const next: Booking = {
      ...b,
      changeRequest: {
        at: nowIso,
        note,
        respondBy: new Date(respondBy).toISOString(),
        status: 'pending',
        declineReason: null,
        answeredAt: null,
      },
      version: b.version + 1,
      updatedAt: nowIso,
    };
    await tx.setBooking(next);
    return next;
  });
}

/** The studio keeps the assignee (reason 1–300): the customer gains the 100% cancel right (change_declined). */
export async function declineAssigneeChange(deps: StudioBookingDeps, studioId: string, raw: unknown): Promise<Booking> {
  const r = fields(raw);
  const bookingId = idField(r, 'bookingId');
  const reason = requiredText(r.reason);
  const now = deps.clock.now();
  const nowIso = now.toISOString();

  const pre = await studioBooking(deps, bookingId);
  if (pre.photographerId !== studioId) throw new DomainError('permission_denied');

  return deps.store.runTransaction(async (tx) => {
    const b = await tx.getBooking(bookingId);
    if (!b) throw new DomainError('not_found');
    const cr = b.changeRequest;
    if (!cr || cr.status !== 'pending') throw new DomainError('conflict');
    if (!isOpenForAssignment(b, now)) throw new DomainError('not_eligible');
    if (now.getTime() >= Date.parse(cr.respondBy)) throw new DomainError('deadline_passed');
    // ---- writes ----
    tx.incrementStudioCounter(b.photographerId, 'changeDeclinedCount');
    const next: Booking = {
      ...b,
      changeRequest: { ...cr, status: 'declined', declineReason: reason, answeredAt: nowIso },
      studioFault: { kind: 'change_declined', at: nowIso },
      version: b.version + 1,
      updatedAt: nowIso,
    };
    await tx.setBooking(next);
    return next;
  });
}

// ── "Trả việc" ──

/**
 * The assignee hands the job back (Decision 14): the studio is told; `assigneeId` stays until it reassigns. A
 * collaborator returns only an accepted job (a pending offer is declined instead): its collab job becomes
 * `returned`, with no pay record (S27 Decision 14).
 */
export async function returnAssignment(deps: StudioBookingDeps, assigneeId: string, raw: unknown): Promise<Booking> {
  const r = fields(raw);
  const bookingId = idField(r, 'bookingId');
  const reason = optionalText(r.reason);
  const now = deps.clock.now();
  const nowIso = now.toISOString();

  const pre = await studioBooking(deps, bookingId);
  if (confirmedAssigneeId(pre) !== assigneeId) throw new DomainError('permission_denied');
  // #194 Decision 7: a spot booking keeps the schedule's member (cancel and book again to change it).
  if (pre.spotScheduleId !== undefined) throw new DomainError('not_eligible');

  return deps.store.runTransaction(async (tx) => {
    const b = await tx.getBooking(bookingId);
    if (!b) throw new DomainError('not_found');
    if (confirmedAssigneeId(b) !== assigneeId) throw new DomainError('permission_denied');
    if (!isOpenForAssignment(b, now)) throw new DomainError('not_eligible');
    if (b.assignmentReturned) throw new DomainError('conflict');
    const job = await liveJobOf(tx, b);
    // ---- writes ----
    if (job) tx.putCollabJob({ ...job, offerStatus: 'returned', updatedAt: now });
    const next: Booking = {
      ...b,
      assignmentReturned: { at: nowIso, reason },
      version: b.version + 1,
      updatedAt: nowIso,
    };
    await tx.setBooking(next);
    return next;
  });
}
