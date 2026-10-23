/**
 * Studio bookings (#136, spec §5): the studio fields every order path gets through the booking-draft builder,
 * assignment of a member, the customer's one change request, "Trả việc" and the studio-fault refund right (the
 * clock sweeps are in studio_booking_sweeps.ts). Every transaction reads everything before its first write.
 */

import type { Booking, StudioAssignment, StudioFaultKind } from './booking.js';
import { parseVnDateTime } from './booking_policy.js';
import type { BookingDeps, StudioBookingStore } from './booking_ports.js';
import { DomainError } from './errors.js';
import { orderBlocker } from './order_gate.js';
import type { ProviderType } from './provider_type.js';
import { studioDayLoadWith } from './studio_capacity.js';
import { fields, idField, optionalText, requiredText } from './studio_input.js';
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
 * completed, and the clock cancels it at its start.
 */
export function waitsForAssignee(booking: Pick<Booking, 'isStudio' | 'assigneeId'>): boolean {
  return booking.isStudio === true && !booking.assigneeId;
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

/**
 * The studio owner assigns (or reassigns) a member (Decision 10). The studio must still take orders, the
 * assignee passes #198's gate (verified, not blocked with the customer) and must be free that day.
 */
export async function assignBooking(deps: StudioBookingDeps, callerId: string, raw: unknown): Promise<Booking> {
  const r = fields(raw);
  const bookingId = idField(r, 'bookingId');
  const assigneeId = idField(r, 'assigneeId');
  const now = deps.clock.now();
  const nowIso = now.toISOString();

  const booking = await studioBooking(deps, bookingId);
  if (booking.photographerId !== callerId) throw new DomainError('permission_denied');
  // #194 Decision 7: a spot booking keeps the schedule's member (cancel and book again to change it).
  if (booking.spotScheduleId !== undefined) throw new DomainError('not_eligible');
  const kind = await deps.roster.relationOf(booking.photographerId, assigneeId);
  if (kind === null) throw new DomainError('permission_denied');
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
    if (kind === 'member' && (await tx.getMemberStudio(assigneeId)) !== b.photographerId) {
      throw new DomainError('permission_denied');
    }
    const day = await tx.getAvailabilityDay(assigneeId, b.day);
    if (day && day.bookingId !== b.id) throw new DomainError('day_taken');
    const oldDay = b.assigneeId ? await tx.getAvailabilityDay(b.assigneeId, b.day) : null;
    const load = await tx.getStudioDayLoad(b.photographerId, b.day);
    // ---- writes ----
    const late = !!b.assigneeId && !!b.assignDeadline && now.getTime() >= Date.parse(b.assignDeadline);
    await tx.setAvailabilityDay(assigneeId, b.day, { state: 'booked', bookingId: b.id });
    if (b.assigneeId && oldDay?.bookingId === b.id) await tx.deleteAvailabilityDay(b.assigneeId, b.day);
    await tx.setStudioDayLoad(studioDayLoadWith(load, { studioId: b.photographerId, day: b.day }, b.id, 'assigned', nowIso));
    if (late) tx.incrementStudioCounter(b.photographerId, 'lateReassignCount');

    const entry: StudioAssignment = { assigneeId, assigneeKind: kind, at: nowIso, by: callerId, reason: null, late };
    const status =
      b.status === 'accepted' && startsAt.getTime() - now.getTime() <= STUDIO_ASSIGN_LEAD_HOURS * HOUR_MS
        ? 'upcoming'
        : b.status;
    const next: Booking = {
      ...b,
      assigneeId,
      assigneeKind: kind,
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
    if (!isOpenForAssignment(b, now) || !b.assigneeId) throw new DomainError('not_eligible');
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

/** The assignee hands the job back (Decision 14): the studio is told; `assigneeId` stays until it reassigns. */
export async function returnAssignment(deps: StudioBookingDeps, assigneeId: string, raw: unknown): Promise<Booking> {
  const r = fields(raw);
  const bookingId = idField(r, 'bookingId');
  const reason = optionalText(r.reason);
  const now = deps.clock.now();
  const nowIso = now.toISOString();

  const pre = await studioBooking(deps, bookingId);
  if (!pre.assigneeId || pre.assigneeId !== assigneeId) throw new DomainError('permission_denied');
  // #194 Decision 7: a spot booking keeps the schedule's member (cancel and book again to change it).
  if (pre.spotScheduleId !== undefined) throw new DomainError('not_eligible');

  return deps.store.runTransaction(async (tx) => {
    const b = await tx.getBooking(bookingId);
    if (!b) throw new DomainError('not_found');
    if (b.assigneeId !== assigneeId) throw new DomainError('permission_denied');
    if (!isOpenForAssignment(b, now)) throw new DomainError('not_eligible');
    if (b.assignmentReturned) throw new DomainError('conflict');
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
