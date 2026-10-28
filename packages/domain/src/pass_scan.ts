/**
 * `scanPass` (S30, plan #223 Decision 9; spec §6.2, S30.07): the server decides what a scan changes from
 * the scanner's roles, never the client. A pass can carry several parts (a booking and its entry tickets);
 * every part is evaluated and the scanner changes only the parts they own:
 * - the booking's shooter (its photographer; for a studio, the confirmed assignee) → `upcoming → shooting`
 *   with `checkedInAt` (the day, from start − 2 h to end + CHECKIN_GRACE_HOURS);
 * - an entry event's organizer or its active gate staff → the ticket's `checkedInAt` on its visit day, +
 *   `entry_days.checkedIn`; on a booking pass whose provider and/or guests a resident waived, the waived
 *   head count (no registration exists for them; the booking is never touched, Task 4 ruling);
 * - a normal event's manager (`isEventManager`) → the ticket's `checkedInAt` (startAt − 2 h … endAt + grace);
 * - the manager (or gate staff) of the spot an event is held at (`venue.spotId`) → `gateCheckedInAt`.
 * Anyone else gets `not_your_pass` and nothing changes. Gate staff scans count on their row
 * (`scansToday`). Responses carry names, titles and counts only: never a phone (Review Focus 3).
 * A legacy `VE-XXXX-MMDD` ticket code resolves through `ticket_codes` (Decision 7).
 */

import type { Booking, BookingEventRecord } from './booking.js';
import { decideTransition } from './booking_machine.js';
import { formatVnDate } from './booking_policy.js';
import { confirmedAssigneeId } from './collab_jobs.js';
import { entryDaysAfter, type EntryDayDelta } from './entry_days.js';
import type { EntryDay } from './entry_tickets.js';
import { DomainError, type ErrorCode } from './errors.js';
import { CHECKIN_GRACE_HOURS, isEventManager, type EventCaller, type EventRecord, type RegistrationDoc } from './event.js';
import type { EventStore } from './event_ports.js';
import { isId } from './ids.js';
import type { GateStaff } from './organizer.js';
import { SCAN_OPEN_BEFORE_HOURS, normalizePassCode, type PassRecord } from './pass.js';
import type { Clock, IdGenerator } from './ports.js';
import type { Spot } from './spot.js';
import type { DisplayNames } from './support_use_cases.js';
import { isTicketCode } from './ticket_code.js';

const HOUR_MS = 3_600_000;

export type ScannerKind = 'shooter' | 'event_manager' | 'entry_gate' | 'venue_gate';

/**
 * One part of a pass. `waived`: a booking pass at an organizer's ticketed spot whose provider and/or guests a
 * resident waived (`Booking.entry.waived`); `event` is the booking's entry event.
 */
export type ScanPart =
  | { readonly kind: 'booking'; readonly booking: Booking }
  | {
    readonly kind: 'registration';
    readonly registration: RegistrationDoc;
    readonly event: EventRecord;
    /** An entry ticket whose visit day the organizer closed (`entry_days.closed`): refunded, never let in. */
    readonly dayClosed?: boolean;
  }
  | {
    readonly kind: 'waived';
    readonly booking: Booking;
    readonly event: EventRecord;
    /** `passes/{code8}.waivedCheckedInAt`: the waived head count already went in (it scans once). */
    readonly checkedInAt?: string | null;
  };

/** What the scanner may act for, collected for this pass's parts only. */
export interface Scanner {
  readonly uid: string;
  /** Booking ids the scanner shoots. */
  readonly shooterOf: readonly string[];
  /** Normal (non-entry) event ids the scanner manages. */
  readonly managerOf: readonly string[];
  /** Organizer ids the scanner is, or is active gate staff of. */
  readonly gateOf: readonly string[];
  /** Spot ids managed by an organizer of `gateOf`. */
  readonly managesSpots: readonly string[];
}

export type ScanUpdate =
  | { readonly kind: 'booking_shooting'; readonly bookingId: string }
  | { readonly kind: 'registration_checked_in'; readonly eventId: string; readonly registrationId: string }
  | { readonly kind: 'registration_gate'; readonly eventId: string; readonly registrationId: string }
  | { readonly kind: 'waived_gate'; readonly bookingId: string; readonly eventId: string; readonly count: number };

export interface ScanSummary {
  readonly booking: { readonly id: string; readonly customerName: string } | null;
  readonly registrations: readonly {
    readonly id: string;
    readonly eventTitle: string;
    readonly quantity: number;
    readonly kind: 'entry' | 'event' | 'venue_gate';
  }[];
  /** The waived head count let in on a booking pass (S30.07 "Vào cổng · {n} người"). */
  readonly waived: { readonly bookingId: string; readonly count: number } | null;
}

export interface ScanResult extends ScanSummary {
  /** After a gate scan of an entry day: `entry_days.checkedIn` of that day (S30.07 "Hôm nay"); else null. */
  readonly todayCount: number | null;
}

/** One transaction over the documents a scan reads and writes (every read before the first write). */
export interface ScanTx {
  getPass(code8: string): Promise<PassRecord | null>;
  /** `ticket_codes/{code}` (legacy `VE-XXXX-MMDD`). */
  findTicket(code: string): Promise<{ eventId: string; registrationId: string } | null>;
  getBooking(id: string): Promise<Booking | null>;
  getEvent(id: string): Promise<EventRecord | null>;
  getRegistration(eventId: string, regId: string): Promise<RegistrationDoc | null>;
  getSpot(id: string): Promise<Spot | null>;
  getEntryDay(eventId: string, day: string): Promise<EntryDay | null>;
  /** `organizers/{organizerId}/gate_staff/{staffUid}`. */
  getGateStaff(organizerId: string, staffUid: string): Promise<GateStaff | null>;
  /** `passes/{code8}` (the waived part's check-in mark, server-only). */
  putPass(p: PassRecord): Promise<void>;
  setBooking(b: Booking): Promise<void>;
  addBookingEvent(e: BookingEventRecord): Promise<void>;
  putRegistration(r: RegistrationDoc): Promise<void>;
  putEntryDay(d: EntryDay): Promise<void>;
  putGateStaff(organizerId: string, g: GateStaff): Promise<void>;
}

export interface ScanStore {
  runTransaction<T>(fn: (tx: ScanTx) => Promise<T>): Promise<T>;
}

export interface ScanDeps {
  readonly scans: ScanStore;
  /** The customer's display name for the shooter's result (no contact data). */
  readonly names: DisplayNames;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}

/** Who shoots a booking: its photographer, or for a studio booking the confirmed assignee (never the owner then). */
export function shooterIdOf(b: Booking): string | null {
  return b.isStudio === true ? confirmedAssigneeId(b) : b.photographerId;
}

const CLOSED_BOOKING: readonly string[] = ['cancelled', 'declined', 'expired'];
const PAST_SCAN: readonly string[] = ['shooting', 'shot', 'delivered', 'revision_requested', 'approved', 'completed', 'reviewed'];

/** The head count a resident's waiver lets in on a booking pass (0: nothing waived). */
export function waivedCount(b: Booking): number {
  const e = b.entry;
  if (e === undefined) return 0;
  const guests = e.waived.guests ? (e.waivedGuests ?? 1) : 0;
  return (e.waived.provider ? 1 : 0) + guests;
}

function ownerKind(p: ScanPart, s: Scanner): ScannerKind | null {
  if (p.kind === 'booking') return s.shooterOf.includes(p.booking.id) ? 'shooter' : null;
  const host = p.event.host;
  const gate = host.type === 'organizer' && host.id !== null && s.gateOf.includes(host.id);
  if (p.kind === 'waived') return gate ? 'entry_gate' : null;
  if (p.event.type === 'entry') return gate ? 'entry_gate' : null;
  if (s.managerOf.includes(p.event.id)) return 'event_manager';
  const spotId = p.event.venue?.spotId ?? null;
  return spotId !== null && s.managesSpots.includes(spotId) ? 'venue_gate' : null;
}

const fail = (code: ErrorCode, details?: Readonly<Record<string, unknown>>): never => {
  throw new DomainError(code, undefined, details);
};

function assertBookingPart(b: Booking, now: Date): void {
  if (CLOSED_BOOKING.includes(b.status)) fail('refunded');
  if (b.checkedInAt !== undefined || PAST_SCAN.includes(b.status)) fail('already_checked_in', { at: b.checkedInAt ?? null });
  if (b.status !== 'upcoming') fail('not_eligible');
  // Window, studio assignee and status, as the state machine decides `scan`.
  decideTransition(b, 'scan', { id: b.photographerId, role: 'photographer' }, now);
}

function assertRegistrationPart(reg: RegistrationDoc, ev: EventRecord, kind: ScannerKind, now: Date, dayClosed: boolean): void {
  if (reg.status === 'refunded' || reg.status === 'cancelled') fail('refunded');
  if (reg.status !== 'paid') fail('not_found');
  const at = kind === 'venue_gate' ? (reg.gateCheckedInAt ?? null) : reg.checkedInAt;
  if (at !== null) fail('already_checked_in', { at: at.toISOString() });
  if (ev.type === 'entry') {
    // A cancelled entry event, a closed visit day or a ticket waiting for its refund lets nobody in.
    if (ev.status === 'cancelled' || dayClosed || reg.refundDue === true) fail('refunded');
    // An entry ticket scans on its visit day only.
    if (formatVnDate(now) !== reg.visitDay) fail('wrong_day', { day: reg.visitDay ?? null });
    return;
  }
  if (ev.status === 'cancelled') fail('refunded');
  const startAt = ev.startAt ?? reg.event.startAt;
  const endAt = ev.endAt ?? reg.event.endAt;
  const opens = startAt.getTime() - SCAN_OPEN_BEFORE_HOURS * HOUR_MS;
  const closes = endAt.getTime() + CHECKIN_GRACE_HOURS * HOUR_MS;
  const t = now.getTime();
  if (t >= opens && t <= closes) return;
  const day = ev.dayKey ?? formatVnDate(startAt);
  if (t < opens && formatVnDate(now) === day) fail('too_early', { opensAt: new Date(opens).toISOString() });
  fail('wrong_day', { day });
}

function assertWaivedPart(b: Booking, now: Date, checkedInAt: string | null): void {
  if (CLOSED_BOOKING.includes(b.status)) fail('refunded');
  if (checkedInAt !== null) fail('already_checked_in', { at: checkedInAt });
  if (b.status === 'draft' || b.status === 'requested' || b.status === 'accepted') fail('not_eligible');
  if (formatVnDate(now) !== b.day) fail('wrong_day', { day: b.day });
}

const regKind = (k: ScannerKind): 'entry' | 'event' | 'venue_gate' =>
  k === 'entry_gate' ? 'entry' : k === 'venue_gate' ? 'venue_gate' : 'event';

/**
 * Pure: evaluates every part, keeps the scanner's own, and returns the updates they allow with the
 * summary (`customerNames`: the booking customer's display name, by uid). `not_your_pass` when the
 * scanner owns no part; otherwise the first owned part that cannot be scanned throws its reason
 * (`refunded`, `already_checked_in` with `details.at`, `too_early` with `details.opensAt`, `wrong_day`
 * with `details.day`, `not_eligible`, `not_found`).
 */
export function resolveScan(
  parts: readonly ScanPart[],
  scanner: Scanner,
  now: Date,
  customerNames: Readonly<Record<string, string>> = {},
): { updates: ScanUpdate[]; summary: ScanSummary } {
  const mine = parts
    .map((p) => ({ p, kind: ownerKind(p, scanner) }))
    .filter((x): x is { p: ScanPart; kind: ScannerKind } => x.kind !== null);
  if (mine.length === 0) throw new DomainError('not_your_pass');

  const updates: ScanUpdate[] = [];
  let booking: ScanSummary['booking'] = null;
  let waived: ScanSummary['waived'] = null;
  const registrations: ScanSummary['registrations'][number][] = [];
  for (const { p, kind } of mine) {
    if (p.kind === 'booking') {
      assertBookingPart(p.booking, now);
      updates.push({ kind: 'booking_shooting', bookingId: p.booking.id });
      booking = { id: p.booking.id, customerName: customerNames[p.booking.customerId] ?? '' };
    } else if (p.kind === 'waived') {
      assertWaivedPart(p.booking, now, p.checkedInAt ?? null);
      const count = waivedCount(p.booking);
      updates.push({ kind: 'waived_gate', bookingId: p.booking.id, eventId: p.event.id, count });
      waived = { bookingId: p.booking.id, count };
    } else {
      assertRegistrationPart(p.registration, p.event, kind, now, p.dayClosed === true);
      updates.push({
        kind: kind === 'venue_gate' ? 'registration_gate' : 'registration_checked_in',
        eventId: p.event.id,
        registrationId: p.registration.id,
      });
      registrations.push({
        id: p.registration.id, eventTitle: p.event.title, quantity: p.registration.quantity, kind: regKind(kind),
      });
    }
  }
  return { updates, summary: { booking, registrations, waived } };
}

// ── The use case ──

/** A scanned code: a pass (`code8`) or a legacy ticket code. */
type ScanRef = { readonly code8: string } | { readonly ticketCode: string };

function scanRefOf(raw: string): ScanRef | null {
  const code8 = normalizePassCode(raw);
  if (code8 !== null) return { code8 };
  const upper = raw.trim().toUpperCase();
  return isTicketCode(upper) ? { ticketCode: upper } : null;
}

interface RunOptions {
  /** `checkInRegistration` (old clients): only this event's tickets, and only as its manager. */
  readonly onlyEventId?: string;
}

interface RunOut {
  readonly result: ScanResult;
  /** The registrations as written (the old callable answers with the attendee's name). */
  readonly written: readonly RegistrationDoc[];
}

async function runScan(deps: ScanDeps, caller: EventCaller, ref: ScanRef, opts: RunOptions = {}): Promise<RunOut> {
  return deps.scans.runTransaction(async (tx): Promise<RunOut> => {
    const now = deps.clock.now();
    const today = formatVnDate(now);
    const managerOnly = opts.onlyEventId !== undefined;

    // ---- reads: the pass and its parts ----
    let bookingId: string | null = null;
    let regRefs: { eventId: string; registrationId: string }[];
    let pass: PassRecord | null = null;
    if ('code8' in ref) {
      pass = await tx.getPass(ref.code8);
      if (pass === null) throw new DomainError('not_found');
      bookingId = pass.bookingId;
      const passEventId = pass.eventId;
      regRefs = passEventId === null ? [] : pass.registrationIds.map((id) => ({ eventId: passEventId, registrationId: id }));
    } else {
      const found = await tx.findTicket(ref.ticketCode);
      if (found === null) throw new DomainError('not_found');
      regRefs = [found];
    }
    if (managerOnly) {
      bookingId = null;
      regRefs = regRefs.filter((r) => r.eventId === opts.onlyEventId);
      if (regRefs.length === 0) throw new DomainError('not_found');
    }

    const events = new Map<string, EventRecord | null>();
    const eventOf = async (id: string): Promise<EventRecord | null> => {
      if (!events.has(id)) events.set(id, await tx.getEvent(id));
      return events.get(id) ?? null;
    };
    const dayRows = new Map<string, Map<string, EntryDay | null>>(); // eventId → day → row (read once)
    const dayOf = async (eventId: string, day: string): Promise<EntryDay | null> => {
      const rows = dayRows.get(eventId) ?? new Map<string, EntryDay | null>();
      dayRows.set(eventId, rows);
      if (!rows.has(day)) rows.set(day, await tx.getEntryDay(eventId, day));
      return rows.get(day) ?? null;
    };
    const parts: ScanPart[] = [];
    const booking = bookingId === null ? null : await tx.getBooking(bookingId);
    if (booking !== null) {
      parts.push({ kind: 'booking', booking });
      const entryEvent = booking.entry !== undefined && waivedCount(booking) > 0 ? await eventOf(booking.entry.eventId) : null;
      if (entryEvent !== null) {
        await dayOf(entryEvent.id, booking.day);
        parts.push({ kind: 'waived', booking, event: entryEvent, checkedInAt: pass?.waivedCheckedInAt ?? null });
      }
    }
    for (const r of regRefs) {
      const reg = await tx.getRegistration(r.eventId, r.registrationId);
      const ev = await eventOf(r.eventId);
      if (reg === null || ev === null) continue;
      const visitDay = ev.type === 'entry' && typeof reg.visitDay === 'string' ? reg.visitDay : null;
      const dayClosed = visitDay !== null && (await dayOf(ev.id, visitDay))?.closed === true;
      parts.push({ kind: 'registration', registration: reg, event: ev, dayClosed });
    }
    if (parts.length === 0) throw new DomainError('not_found');

    // ---- reads: the scanner's roles for these parts only ----
    const shooterOf = !managerOnly && booking !== null && shooterIdOf(booking) === caller.uid ? [booking.id] : [];
    const managerOf = [...events.values()]
      .filter((e): e is EventRecord => e !== null && e.type !== 'entry' && isEventManager(e, caller))
      .map((e) => e.id);
    const candidates = new Set<string>();
    const venueManagers = new Map<string, string>(); // spotId → manager
    if (!managerOnly) {
      for (const p of parts) {
        if (p.kind === 'booking') continue;
        const host = p.event.host;
        if ((p.kind === 'waived' || p.event.type === 'entry') && host.type === 'organizer' && host.id !== null) candidates.add(host.id);
        const spotId = p.kind === 'registration' && p.event.type !== 'entry' ? (p.event.venue?.spotId ?? null) : null;
        if (spotId !== null && !venueManagers.has(spotId)) {
          const manager = (await tx.getSpot(spotId))?.managedBy ?? null;
          if (manager !== null) {
            venueManagers.set(spotId, manager);
            candidates.add(manager);
          }
        }
      }
    }
    const staffRows = new Map<string, GateStaff>(); // organizerId → the caller's active row
    const gateOf: string[] = [];
    for (const org of candidates) {
      if (org === caller.uid) {
        gateOf.push(org);
        continue;
      }
      const row = await tx.getGateStaff(org, caller.uid);
      if (row !== null && row.status === 'active') {
        gateOf.push(org);
        staffRows.set(org, row);
      }
    }
    const managesSpots = [...venueManagers].filter(([, m]) => gateOf.includes(m)).map(([spotId]) => spotId);
    const scanner: Scanner = { uid: caller.uid, shooterOf, managerOf, gateOf, managesSpots };

    const names: Record<string, string> = {};
    if (booking !== null && shooterOf.length > 0) names[booking.customerId] = await deps.names.displayName(booking.customerId);
    const { updates, summary } = resolveScan(parts, scanner, now, names);

    // ---- reads: the entry days the gate updates touch ----
    const dayDeltas = new Map<string, EntryDayDelta[]>(); // eventId → deltas
    const addDelta = (eventId: string, d: EntryDayDelta) => dayDeltas.set(eventId, [...(dayDeltas.get(eventId) ?? []), d]);
    const gateOrgs = new Set<string>();
    for (const u of updates) {
      if (u.kind === 'booking_shooting') continue;
      const ev = events.get(u.eventId) ?? null;
      if (ev === null) continue;
      if (u.kind === 'waived_gate') {
        addDelta(ev.id, { day: (booking as Booking).day, checkedIn: u.count });
        if (ev.host.id !== null) gateOrgs.add(ev.host.id);
        continue;
      }
      const reg = parts.find((p): p is Extract<ScanPart, { kind: 'registration' }> =>
        p.kind === 'registration' && p.registration.id === u.registrationId)?.registration;
      if (reg === undefined) continue;
      if (u.kind === 'registration_checked_in' && ev.type === 'entry' && typeof reg.visitDay === 'string') {
        addDelta(ev.id, { day: reg.visitDay, checkedIn: reg.quantity });
        if (ev.host.id !== null) gateOrgs.add(ev.host.id);
      }
      if (u.kind === 'registration_gate') {
        const manager = venueManagers.get(ev.venue?.spotId ?? '');
        if (manager !== undefined) gateOrgs.add(manager);
      }
    }
    for (const [eventId, deltas] of dayDeltas) for (const d of deltas) await dayOf(eventId, d.day);

    // ---- writes ----
    const at = now.toISOString();
    const written: RegistrationDoc[] = [];
    for (const u of updates) {
      if (u.kind === 'waived_gate' && pass !== null) {
        // The waived head count goes in once per pass (Task 4 fix 3).
        await tx.putPass({ ...pass, waivedCheckedInAt: at });
      } else if (u.kind === 'booking_shooting' && booking !== null) {
        await tx.setBooking({ ...booking, status: 'shooting', checkedInAt: at, version: booking.version + 1, updatedAt: at });
        await tx.addBookingEvent({ id: deps.ids.newId(), bookingId: booking.id, status: 'shooting', at, actorId: caller.uid });
      } else if (u.kind === 'registration_checked_in' || u.kind === 'registration_gate') {
        const part = parts.find((p): p is Extract<ScanPart, { kind: 'registration' }> =>
          p.kind === 'registration' && p.registration.id === u.registrationId);
        if (part === undefined) continue;
        const reg = part.registration;
        const next: RegistrationDoc = u.kind === 'registration_gate'
          ? { ...reg, gateCheckedInAt: now, updatedAt: now, version: reg.version + 1 }
          : { ...reg, checkedInAt: now, updatedAt: now, version: reg.version + 1 };
        await tx.putRegistration(next);
        written.push(next);
      }
    }
    let todayCount: number | null = null;
    for (const [eventId, deltas] of dayDeltas) {
      for (const row of entryDaysAfter(eventId, dayRows.get(eventId) ?? new Map(), deltas, now)) {
        await tx.putEntryDay(row);
        if (row.day === today && todayCount === null) todayCount = row.checkedIn;
      }
    }
    for (const org of gateOrgs) {
      const row = staffRows.get(org);
      if (row === undefined) continue; // the organizer's own scan: no staff row
      const count = row.scansToday?.day === today ? row.scansToday.count + 1 : 1;
      await tx.putGateStaff(org, { ...row, scansToday: { day: today, count } });
    }
    return { result: { ...summary, todayCount }, written };
  });
}

function codeOf(raw: unknown): string {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) throw new DomainError('invalid_argument');
  const code = (raw as { code?: unknown }).code;
  if (typeof code !== 'string') throw new DomainError('invalid_argument');
  return code;
}

/**
 * S30.07: the scanner's scan of `{code}` (8 characters, `VE-XXXX-XXXX`, or a legacy `VE-XXXX-MMDD`).
 * `not_found` for an unknown code; the rest as `resolveScan`. One transaction.
 */
export async function scanPass(deps: ScanDeps, callerId: string, raw: unknown): Promise<ScanResult> {
  const ref = scanRefOf(codeOf(raw));
  if (ref === null) throw new DomainError('not_found');
  return (await runScan(deps, { uid: callerId, staffRole: null }, ref)).result;
}

/** The old callable's codes for the scan reasons (old clients map these). */
const OLD_CODES: Partial<Record<ErrorCode, ErrorCode>> = {
  not_your_pass: 'permission_denied',
  already_checked_in: 'conflict',
  too_early: 'not_eligible',
  wrong_day: 'not_eligible',
  refunded: 'not_found',
};

/**
 * `checkInRegistration({eventId, ticketCode})` for old clients (Decision 9): a manager-only scan of that
 * event's ticket through `runScan`, answered and refused as before (`permission_denied` for a
 * non-manager, `not_eligible` for a cancelled event or outside the window, `conflict` when already in,
 * `not_found` for another event's, an unpaid or a refunded ticket). The window is now the scan's:
 * startAt − 2 h to endAt + CHECKIN_GRACE_HOURS.
 */
export async function checkInByManager(
  deps: { readonly events: EventStore; readonly clock: Clock; readonly ids: IdGenerator },
  caller: EventCaller,
  raw: unknown,
): Promise<{ name: string; quantity: number }> {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) throw new DomainError('invalid_argument');
  const r = raw as Record<string, unknown>;
  if (!isId(r.eventId)) throw new DomainError('invalid_argument');
  const eventId = r.eventId;
  if (typeof r.ticketCode !== 'string') throw new DomainError('invalid_argument');
  const ev = await deps.events.runTransaction((tx) => tx.getEvent(eventId));
  if (ev === null || ev.status === 'draft') throw new DomainError('not_found');
  if (!isEventManager(ev, caller)) throw new DomainError('permission_denied');
  if (ev.status === 'cancelled') throw new DomainError('not_eligible');
  const ref = scanRefOf(r.ticketCode);
  if (ref === null) throw new DomainError('not_found');
  try {
    const out = await runScan(
      { scans: eventScanStore(deps.events), names: { displayName: async () => '' }, clock: deps.clock, ids: deps.ids },
      caller,
      ref,
      { onlyEventId: eventId },
    );
    const reg = out.written[0];
    if (reg === undefined) throw new DomainError('not_found');
    return { name: reg.userName, quantity: reg.quantity };
  } catch (e) {
    const old = e instanceof DomainError ? OLD_CODES[e.code] : undefined;
    throw old !== undefined ? new DomainError(old) : e;
  }
}

/** A ScanStore over the event store alone (no bookings, no gate staff): what the old callable needs. */
export function eventScanStore(events: EventStore): ScanStore {
  return {
    runTransaction: (fn) => events.runTransaction((tx) => fn({
      getPass: (code8) => tx.getPass(code8),
      findTicket: (code) => tx.findTicket(code),
      getBooking: async () => null,
      getEvent: (id) => tx.getEvent(id),
      getRegistration: (eventId, regId) => tx.getRegistration(eventId, regId),
      getSpot: (id) => tx.getSpot(id),
      getEntryDay: (eventId, day) => tx.getEntryDay(eventId, day),
      getGateStaff: async () => null,
      putPass: async (p) => tx.putPass(p),
      setBooking: async () => {
        throw new Error('eventScanStore: no bookings');
      },
      addBookingEvent: async () => {
        throw new Error('eventScanStore: no bookings');
      },
      putRegistration: async (r) => tx.putRegistration(r),
      putEntryDay: async (d) => tx.putEntryDay(d),
      putGateStaff: async () => {
        throw new Error('eventScanStore: no gate staff');
      },
    })),
  };
}
