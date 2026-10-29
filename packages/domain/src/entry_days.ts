/**
 * `entry_days` counters inside an event transaction (S30 Decision 11): read the rows first, then write
 * the deltas of the registrations a transaction holds, pays, releases or refunds.
 */

import { emptyEntryDay, type EntryDay } from './entry_tickets.js';
import type { EventRecord, RegistrationDoc } from './event.js';
import type { EventTx } from './event_ports.js';

/** Visit day → its row (null: none yet). Only the days a write will touch. */
export type EntryDays = ReadonlyMap<string, EntryDay | null>;

export const NO_ENTRY_DAYS: EntryDays = new Map();

export interface EntryDayDelta {
  readonly day: string;
  readonly held?: number;
  readonly sold?: number;
  /** People let in at the gate (`scanPass`). */
  readonly checkedIn?: number;
}

/** The visit day of an entry ticket (null for every other registration). */
export const visitDayOf = (ev: Pick<EventRecord, 'type'> | null, r: Pick<RegistrationDoc, 'visitDay'>): string | null =>
  ev !== null && ev.type === 'entry' && typeof r.visitDay === 'string' ? r.visitDay : null;

/** Reads only: the rows of `days` of an entry event. */
export async function readEntryDaysOf(tx: EventTx, eventId: string, days: readonly string[]): Promise<EntryDays> {
  const out = new Map<string, EntryDay | null>();
  for (const d of days) if (!out.has(d)) out.set(d, await tx.getEntryDay(eventId, d));
  return out;
}

/** Reads only: the rows of the visit days of `regs` (nothing for a non-entry event). */
export async function readEntryDays(tx: EventTx, ev: EventRecord | null, regs: readonly RegistrationDoc[]): Promise<EntryDays> {
  if (ev === null || ev.type !== 'entry') return new Map();
  return readEntryDaysOf(tx, ev.id, regs.map((r) => visitDayOf(ev, r)).filter((d): d is string => d !== null));
}

/** Pure: the rows the deltas change (per day, never below 0), from the rows read before. */
export function entryDaysAfter(eventId: string, days: EntryDays, deltas: readonly EntryDayDelta[], now: Date): EntryDay[] {
  const sum = new Map<string, { held: number; sold: number; checkedIn: number }>();
  for (const d of deltas) {
    const s = sum.get(d.day) ?? { held: 0, sold: 0, checkedIn: 0 };
    sum.set(d.day, { held: s.held + (d.held ?? 0), sold: s.sold + (d.sold ?? 0), checkedIn: s.checkedIn + (d.checkedIn ?? 0) });
  }
  const out: EntryDay[] = [];
  for (const [day, s] of sum) {
    if (s.held === 0 && s.sold === 0 && s.checkedIn === 0) continue;
    if (!days.has(day)) throw new Error(`entry day ${day} was not read before the write`);
    const row = days.get(day) ?? emptyEntryDay(eventId, day, now);
    out.push({
      ...row,
      held: Math.max(0, row.held + s.held),
      sold: Math.max(0, row.sold + s.sold),
      checkedIn: Math.max(0, row.checkedIn + s.checkedIn),
      updatedAt: now.toISOString(),
    });
  }
  return out;
}

/** Writes only: adds the deltas per day (never below 0) to the rows read by `readEntryDays`. */
export function writeEntryDays(
  tx: Pick<EventTx, 'putEntryDay'>,
  eventId: string,
  days: EntryDays,
  deltas: readonly EntryDayDelta[],
  now: Date,
): void {
  for (const row of entryDaysAfter(eventId, days, deltas, now)) tx.putEntryDay(row);
}

/** The deltas of registrations leaving their state: a held one gives back `held`, a paid one `sold`. */
export function releaseDeltas(ev: Pick<EventRecord, 'type'> | null, regs: readonly RegistrationDoc[]): EntryDayDelta[] {
  const out: EntryDayDelta[] = [];
  for (const r of regs) {
    const day = visitDayOf(ev, r);
    if (day === null) continue;
    if (r.status === 'held') out.push({ day, held: -r.quantity });
    else if (r.status === 'paid') out.push({ day, sold: -r.quantity });
  }
  return out;
}
