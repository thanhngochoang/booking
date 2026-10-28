/**
 * Bookings with entry tickets (S30 Decision 15, spec §5.1, S04.03-entry): which tickets a booking at a
 * ticketed spot carries and whether its visit day can still be sold. Pure.
 */

import type { BookingEntry } from './booking.js';
import { formatVnDate, parseVnDateTime } from './booking_policy.js';
import {
  ENTRY_TICKETS_PER_ORDER,
  assertDailyCapacity,
  entryFieldsOf,
  isOpenDay,
  priceItems,
  type EntryDay,
  type EntryItem,
  type EntryLine,
} from './entry_tickets.js';
import { DomainError } from './errors.js';
import type { EventRecord } from './event.js';
import { waiverFor, type Resident } from './organizer.js';

/** The tickets part of `Booking.entry` (its event, day and registration are the caller's). */
export type BookingEntryDefaults = Pick<BookingEntry, 'items' | 'providerTicket' | 'waived' | 'amount'>;

/**
 * Spec §5.1: the customer's tickets (`customerItems`, S04.03's counters, by default one of the first
 * type) plus one ticket of the first visible type for the provider, unless the provider is a resident
 * of the spot who `waivesProvider`; a resident who `waivesGuests` waives the customer's tickets, at most
 * `maxGuests` of them (null: all), in the order given. A residency that ends (`validUntil`) before the visit day
 * waives nothing. At most
 * ENTRY_TICKETS_PER_ORDER tickets counting the provider's (`limit_exceeded`); unknown or hidden types
 * are `invalid_argument` (field `items`). `items` are the tickets charged, merged per type.
 */
export function bookingEntryDefaults(p: {
  readonly event: EventRecord;
  readonly resident: Resident | null;
  readonly customerItems: readonly EntryItem[];
  /** The booking's day: a residency that ends before it waives nothing. */
  readonly visitDay: string;
}): BookingEntryDefaults {
  const types = entryFieldsOf(p.event).ticketTypes;
  const priced = priceItems(types, p.customerItems);
  const waiver = waiverFor(p.resident, p.visitDay);
  const providerTicket = !waiver.provider;
  if (priced.quantity + (providerTicket ? 1 : 0) > ENTRY_TICKETS_PER_ORDER) throw new DomainError('limit_exceeded');

  let free = waiver.guests ? (waiver.maxGuests ?? Number.POSITIVE_INFINITY) : 0;
  let guestsWaived = 0;
  const lines: EntryLine[] = [];
  for (const l of priced.lines) {
    const waived = Math.min(free, l.qty);
    free -= waived;
    guestsWaived += waived;
    if (l.qty - waived > 0) lines.push({ ...l, qty: l.qty - waived });
  }
  if (providerTicket) {
    const first = types.find((t) => !t.hidden);
    if (first === undefined) throw new DomainError('invalid_argument', 'entry');
    const i = lines.findIndex((l) => l.ticketTypeId === first.id);
    if (i >= 0) lines[i] = { ...(lines[i] as EntryLine), qty: (lines[i] as EntryLine).qty + 1 };
    else lines.push({ ticketTypeId: first.id, name: first.name, price: first.price, qty: 1 });
  }
  return {
    items: lines,
    providerTicket,
    waived: { provider: waiver.provider, guests: guestsWaived > 0 },
    amount: lines.reduce((s, l) => s + l.price * l.qty, 0),
  };
}

/**
 * The entry event and day a booking's tickets need (Decision 15): `invalid_argument` (field `entry`)
 * unless the event is a published entry event (`open`/`full`) at the booking's spot (when the booking is
 * at a spot) and `visitDay` is the booking's day; `day_closed` when the day is not sold (closed weekday
 * or day, outside the range, past, after closing time, or closed by the organizer); `sold_out_day` when
 * `qty` more would pass the daily capacity.
 */
export function assertEntryBookable(p: {
  readonly event: EventRecord | null;
  readonly visitDay: string;
  readonly bookingDay: string;
  readonly spotId: string | null;
  readonly day: EntryDay | null;
  readonly qty: number;
  readonly now: Date;
}): EventRecord {
  const ev = p.event;
  if (ev === null || ev.type !== 'entry' || (ev.status !== 'open' && ev.status !== 'full')) {
    throw new DomainError('invalid_argument', 'entry');
  }
  const fields = entryFieldsOf(ev);
  if (p.visitDay !== p.bookingDay || (p.spotId !== null && p.spotId !== fields.spotId)) {
    throw new DomainError('invalid_argument', 'entry');
  }
  if (p.visitDay < formatVnDate(p.now) || !isOpenDay(fields, p.visitDay)
    || p.now.getTime() >= parseVnDateTime(p.visitDay, fields.openHours.end).getTime()) {
    throw new DomainError('day_closed');
  }
  assertDailyCapacity(p.day, fields.dailyCapacity, p.qty);
  return ev;
}
