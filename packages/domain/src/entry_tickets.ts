/**
 * Entry tickets (S30, plan #223 Decisions 11–12): an `entry` event sells tickets per visit day of a
 * sale range at a managed spot. Pure rules: the entry fields, open days, prices of an order, the
 * daily capacity, the refund cutoff and the release of the money after the visit day.
 */

import { formatVnDate, isDateString, isTimeString, parseVnDateTime } from './booking_policy.js';
import { graphemeCount } from './booking_requests.js';
import { addDays } from './discovery_stats.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';
import type { EventRecord } from './event.js';

export const ENTRY_RANGE_MAX_DAYS = 180;
export const ENTRY_CLOSED_DAYS_MAX = 30;
export const TICKET_TYPES_MAX = 6;
export const TICKET_TYPE_NAME_MIN = 3;
export const TICKET_TYPE_NAME_MAX = 40;
export const ENTRY_TICKETS_PER_ORDER = 10;
export const ENTRY_HOLD_MINUTES = 15;
export const ENTRY_REFUND_CUTOFF_HOURS = 48;
export const ENTRY_RELEASE_DAYS = 1;
export const ENTRY_RELEASE_HOURS = 48;
/** Upper bounds of our own (not in the spec): a day's capacity and the refund cutoff (7 days). */
export const ENTRY_CAPACITY_MAX = 100_000;
export const ENTRY_REFUND_CUTOFF_MAX_HOURS = 168;
export const ENTRY_TICKET_PRICE_MAX = 100_000_000;
/** `closeEntryDay` refunds this many tickets at once; the event clock refunds the rest. */
export const ENTRY_CLOSE_BATCH = 20;

const HOUR_MS = 3_600_000;
const TYPE_ID = /^[A-Za-z0-9_-]{1,40}$/;

export interface TicketType {
  readonly id: string;
  readonly name: string;
  /** Integer VND > 0. */
  readonly price: number;
  /** Hidden types are kept for history (sold tickets) but cannot be bought. */
  readonly hidden: boolean;
}

export interface OpenHours {
  /** `HH:mm`, Vietnam. */
  readonly start: string;
  readonly end: string;
}

/** The entry part of an `entry` event. `startAt`/`endAt` are the first and last sale days (`yyyy-MM-dd`, Vietnam, inclusive). */
export interface EntryFields {
  readonly spotId: string;
  readonly startAt: string;
  readonly endAt: string;
  /** 0 = Sunday … 6 = Saturday. */
  readonly closedWeekdays: readonly number[];
  readonly closedDays: readonly string[];
  readonly openHours: OpenHours;
  readonly ticketTypes: readonly TicketType[];
  /** Null: no daily limit. */
  readonly dailyCapacity: number | null;
  readonly refundCutoffHours: number;
}

/** `entry_days/{eventId}_{day}`: written only inside the registration, settlement, expiry, refund and scan transactions. */
export interface EntryDay {
  readonly eventId: string;
  readonly day: string;
  readonly sold: number;
  readonly held: number;
  readonly checkedIn: number;
  readonly closed: boolean;
  readonly updatedAt: string;
}

export interface EntryItem {
  readonly ticketTypeId: string;
  readonly qty: number;
}

/** A priced line of an order, stored on the registration (`items`): the price paid, whatever later edits do. */
export interface EntryLine {
  readonly ticketTypeId: string;
  readonly name: string;
  readonly price: number;
  readonly qty: number;
}

export const entryDayId = (eventId: string, day: string): string => `${eventId}_${day}`;

export const emptyEntryDay = (eventId: string, day: string, now: Date): EntryDay =>
  ({ eventId, day, sold: 0, held: 0, checkedIn: 0, closed: false, updatedAt: now.toISOString() });

/** Days from `a` to `b` (calendar, `yyyy-MM-dd`). */
export function daysBetween(a: string, b: string): number {
  return Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 86_400_000);
}

/** 0 = Sunday … 6 = Saturday of a calendar day. */
export const weekdayOf = (day: string): number => new Date(`${day}T00:00:00Z`).getUTCDay();

const isRealDay = (v: unknown): v is string =>
  isDateString(v) && !Number.isNaN(Date.parse(`${v}T00:00:00Z`)) && new Date(`${v}T00:00:00Z`).toISOString().slice(0, 10) === v;

const isRecord = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

const fail = (field: string): never => {
  throw new DomainError('invalid_argument', field);
};

export interface ValidateEntryOptions {
  /** Id for a ticket type sent without one (the use case passes `deps.ids.newId`). */
  readonly newId?: () => string;
  /** An edit of a published event: its first day may already be in the past if unchanged. */
  readonly existingStartAt?: string;
}

function parseTicketTypes(v: unknown, newId: () => string): TicketType[] {
  if (!Array.isArray(v) || v.length < 1 || v.length > TICKET_TYPES_MAX) return fail('ticketTypes');
  const seen = new Set<string>();
  return v.map((t: unknown): TicketType => {
    if (!isRecord(t) || typeof t.name !== 'string') return fail('ticketTypes');
    const id = t.id === undefined || t.id === null ? newId() : t.id;
    if (typeof id !== 'string' || !TYPE_ID.test(id) || seen.has(id)) return fail('ticketTypes');
    seen.add(id);
    const name = t.name.normalize('NFC').trim();
    const n = graphemeCount(name);
    if (n < TICKET_TYPE_NAME_MIN || n > TICKET_TYPE_NAME_MAX) return fail('ticketTypes');
    const price = t.price;
    if (typeof price !== 'number' || !Number.isSafeInteger(price) || price <= 0 || price > ENTRY_TICKET_PRICE_MAX) {
      return fail('ticketTypes');
    }
    if (t.hidden !== undefined && typeof t.hidden !== 'boolean') return fail('ticketTypes');
    return { id, name, price, hidden: t.hidden === true };
  });
}

/**
 * The entry fields of a save/publish request (`invalid_argument` with the field): a sale range of at
 * most 180 days that does not start before `today` (unless it is the unchanged start of a published
 * event), opening hours with the close after the open, 1–6 ticket types (name 3–40, integer VND > 0),
 * ≤ 30 closed days, `dailyCapacity` null or ≥ 1, `refundCutoffHours` default 48.
 */
export function validateEntryEvent(raw: unknown, today: string, options: ValidateEntryOptions = {}): EntryFields {
  if (!isRecord(raw)) return fail('entry');
  let n = 0;
  const newId = options.newId ?? ((): string => `t${++n}`);

  if (!isId(raw.spotId)) return fail('spotId');
  const spotId = raw.spotId;

  const startAt = raw.startAt;
  if (!isRealDay(startAt)) return fail('startAt');
  if (startAt < today && startAt !== options.existingStartAt) return fail('startAt');
  const endAt = raw.endAt;
  if (!isRealDay(endAt) || endAt < startAt) return fail('endAt');
  if (daysBetween(startAt, endAt) + 1 > ENTRY_RANGE_MAX_DAYS) return fail('endAt');

  const rawWeekdays = raw.closedWeekdays ?? [];
  if (!Array.isArray(rawWeekdays)) return fail('closedWeekdays');
  for (const d of rawWeekdays) if (typeof d !== 'number' || !Number.isInteger(d) || d < 0 || d > 6) fail('closedWeekdays');
  const closedWeekdays = [...new Set(rawWeekdays as number[])].sort((a, b) => a - b);
  if (closedWeekdays.length === 7) return fail('closedWeekdays');

  const rawDays = raw.closedDays ?? [];
  if (!Array.isArray(rawDays) || rawDays.length > ENTRY_CLOSED_DAYS_MAX) return fail('closedDays');
  for (const d of rawDays) if (!isRealDay(d)) fail('closedDays');
  const closedDays = [...new Set(rawDays as string[])].sort();

  const hours = raw.openHours;
  if (!isRecord(hours) || !isTimeString(hours.start) || !isTimeString(hours.end) || hours.end <= hours.start) {
    return fail('openHours');
  }
  const openHours: OpenHours = { start: hours.start, end: hours.end };

  const ticketTypes = parseTicketTypes(raw.ticketTypes, newId);

  const cap = raw.dailyCapacity ?? null;
  if (cap !== null && (typeof cap !== 'number' || !Number.isInteger(cap) || cap < 1 || cap > ENTRY_CAPACITY_MAX)) {
    return fail('dailyCapacity');
  }

  const cutoff = raw.refundCutoffHours ?? ENTRY_REFUND_CUTOFF_HOURS;
  if (typeof cutoff !== 'number' || !Number.isInteger(cutoff) || cutoff < 0 || cutoff > ENTRY_REFUND_CUTOFF_MAX_HOURS) {
    return fail('refundCutoffHours');
  }

  return {
    spotId, startAt, endAt, closedWeekdays, closedDays, openHours, ticketTypes,
    dailyCapacity: cap as number | null, refundCutoffHours: cutoff,
  };
}

/** A day of the sale range that is neither a closed weekday nor a closed day. */
export function isOpenDay(e: Pick<EntryFields, 'startAt' | 'endAt' | 'closedWeekdays' | 'closedDays'>, day: string): boolean {
  if (!isRealDay(day) || day < e.startAt || day > e.endAt) return false;
  return !e.closedWeekdays.includes(weekdayOf(day)) && !e.closedDays.includes(day);
}

/** Up to `count` open days from `from` (or the range start, whichever is later) to the range end. */
export function openDays(e: Pick<EntryFields, 'startAt' | 'endAt' | 'closedWeekdays' | 'closedDays'>, from: string, count: number): string[] {
  const out: string[] = [];
  for (let d = from > e.startAt ? from : e.startAt; d <= e.endAt && out.length < count; d = addDays(d, 1)) {
    if (isOpenDay(e, d)) out.push(d);
  }
  return out;
}

/**
 * Prices an order: `invalid_argument` (field `items`) for an empty order, an unknown or hidden type, a
 * repeated type or a quantity that is not an integer ≥ 1; `limit_exceeded` above 10 tickets.
 */
export function priceItems(
  types: readonly TicketType[],
  items: readonly EntryItem[],
): { lines: EntryLine[]; quantity: number; total: number } {
  if (!Array.isArray(items) || items.length < 1 || items.length > TICKET_TYPES_MAX) return fail('items');
  const seen = new Set<string>();
  const lines = items.map((it: unknown): EntryLine => {
    if (!isRecord(it) || typeof it.ticketTypeId !== 'string' || seen.has(it.ticketTypeId)) return fail('items');
    const qty = it.qty;
    if (typeof qty !== 'number' || !Number.isInteger(qty) || qty < 1) return fail('items');
    const t = types.find((x) => x.id === it.ticketTypeId);
    if (t === undefined || t.hidden) return fail('items');
    seen.add(t.id);
    return { ticketTypeId: t.id, name: t.name, price: t.price, qty };
  });
  const quantity = lines.reduce((s, l) => s + l.qty, 0);
  if (quantity > ENTRY_TICKETS_PER_ORDER) throw new DomainError('limit_exceeded');
  return { lines, quantity, total: lines.reduce((s, l) => s + l.price * l.qty, 0) };
}

/** `day_closed` when the organizer closed the day; `sold_out_day` when `sold + held + qty` passes the capacity. */
export function assertDailyCapacity(day: EntryDay | null, capacity: number | null, qty: number): void {
  if (day?.closed === true) throw new DomainError('day_closed');
  if (capacity === null) return;
  if ((day?.sold ?? 0) + (day?.held ?? 0) + qty > capacity) throw new DomainError('sold_out_day');
}

/** 00:00 of the visit day in Vietnam. */
export const visitDayStart = (visitDay: string): Date => parseVnDateTime(visitDay, '00:00');

/** 100 when cancelled at least `cutoffHours` before 00:00 (Vietnam) of the visit day, else 0. */
export function entryRefundPercent(visitDay: string, now: Date, cutoffHours: number): 100 | 0 {
  return now.getTime() <= visitDayStart(visitDay).getTime() - cutoffHours * HOUR_MS ? 100 : 0;
}

/** The ticket money goes to the organizer 1 day + 48 h after 00:00 (Vietnam) of the visit day. */
export function entryReleaseAt(visitDay: string): Date {
  return new Date(parseVnDateTime(addDays(visitDay, ENTRY_RELEASE_DAYS), '00:00').getTime() + ENTRY_RELEASE_HOURS * HOUR_MS);
}

/** The event's sale range as instants: 00:00 of the first day to 00:00 after the last day (Vietnam). */
export function entryRangeInstants(f: Pick<EntryFields, 'startAt' | 'endAt'>): { startAt: Date; endAt: Date } {
  return { startAt: parseVnDateTime(f.startAt, '00:00'), endAt: parseVnDateTime(addDays(f.endAt, 1), '00:00') };
}

/** The first and last sale days of stored instants (the inverse of `entryRangeInstants`). */
export function entryRangeDays(startAt: Date, endAt: Date): { startAt: string; endAt: string } {
  return { startAt: formatVnDate(startAt), endAt: formatVnDate(new Date(endAt.getTime() - 1)) };
}

/** The entry fields stored on an entry event (`not_found` for any other event). */
export function entryFieldsOf(ev: EventRecord): EntryFields {
  if (ev.type !== 'entry' || ev.startAt === null || ev.endAt === null || !ev.openHours || !ev.ticketTypes
    || typeof ev.spotId !== 'string') {
    throw new DomainError('not_found');
  }
  return {
    spotId: ev.spotId,
    ...entryRangeDays(ev.startAt, ev.endAt),
    closedWeekdays: ev.closedWeekdays ?? [],
    closedDays: ev.closedDays ?? [],
    openHours: ev.openHours,
    ticketTypes: ev.ticketTypes,
    dailyCapacity: ev.dailyCapacity ?? null,
    refundCutoffHours: ev.refundCutoffHours ?? ENTRY_REFUND_CUTOFF_HOURS,
  };
}
