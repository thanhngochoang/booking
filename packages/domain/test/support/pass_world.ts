import type { Booking, BookingEntry } from '../../src/booking.js';
import { parseVnDateTime } from '../../src/booking_policy.js';
import type { EventRecord, RegistrationDoc } from '../../src/event.js';
import type { GateStaff } from '../../src/organizer.js';
import { MemoryOrganizerStore } from '../../src/memory_organizer_store.js';
import { MemoryScanStore } from '../../src/memory_scan_store.js';
import type { PassRecord } from '../../src/pass.js';
import { scanPass, type ScanDeps, type ScanResult } from '../../src/pass_scan.js';
import { makeTestBooking } from './booking_fixtures.js';
import { ENTRY_ID, createBookingEntryWorld, type BookingEntryWorld } from './booking_entry_world.js';
import { eventRecord, must, registrationDoc } from './event_world.js';
import { ORGANIZER_TERMS_VERSION } from '../../src/organizer.js';

export { ENTRY_ID };

/** Sunday 2026-10-18 (the entry event of org1 at s1 is open; Mondays are closed). */
export const TODAY = '2026-10-18';
export const TOMORROW_OPEN = '2026-10-20';
export const at = (hhmm: string, day = TODAY): Date => parseVnDateTime(day, hhmm);

/** b1 (p1, upcoming today 15:30–17:30). */
export const P1 = 'BKNG2345';
/** r1 (an entry ticket of today, 2 people). */
export const P2 = 'TKTS2345';
/** b2 (p1) + r2 (its 2 entry tickets). */
export const P3 = 'CMBN2345';
/** b3 (studio st1, assignee m1). */
export const P4 = 'STDA2345';
/** b4 (p1, a resident: the provider's ticket is waived, nothing bought). */
export const P5 = 'WAVD2345';
/** r5 (an entry ticket of 2026-10-20). */
export const P7 = 'TMRW2345';
/** r6 (a refunded entry ticket of today). */
export const P8 = 'RFND2345';
/** e1 (a photo walk of h1 today 16:00–18:00): r4's legacy ticket code. */
export const E1_TICKET = 'VE-ABCD-1018';
/** e2 (h2's event at s1, `venue.spotId = s1`): r3's legacy ticket code. */
export const E2_TICKET = 'VE-EFGH-1018';

export const NAMES: Readonly<Record<string, string>> = { c1: 'Khách Một', c2: 'Khách Hai', c3: 'Khách Ba', c4: 'Khách Bốn' };

export interface PassWorld {
  readonly be: BookingEntryWorld;
  readonly organizers: MemoryOrganizerStore;
  readonly deps: ScanDeps;
  readonly setNow: (d: Date) => void;
  readonly scan: (uid: string, code: string) => Promise<ScanResult>;
  readonly booking: (id: string) => Booking;
  readonly reg: (eventId: string, id: string) => RegistrationDoc;
}

const booking = (over: Partial<Booking>): Booking => makeTestBooking({
  photographerId: 'p1', day: TODAY, start: '15:30', end: '17:30', status: 'upcoming', ...over,
});

function entryOf(over: Partial<BookingEntry>): BookingEntry {
  return {
    eventId: ENTRY_ID, visitDay: TODAY, items: [], providerTicket: false, waived: { provider: false, guests: false },
    amount: 0, registrationId: null, ...over,
  };
}

function entryReg(over: Partial<RegistrationDoc>): RegistrationDoc {
  return registrationDoc({
    eventId: ENTRY_ID, quantity: 2, amount: 140_000, status: 'paid', ticketCode: '', contactEligible: true,
    visitDay: TODAY, items: [{ ticketTypeId: 'adult', name: 'Người lớn', price: 70_000, qty: 2 }], bookingId: null,
    gateCheckedInAt: null,
    event: {
      title: 'Vé vào cửa Bãi đá', type: 'entry', startAt: at('08:00'), endAt: at('17:00'), locationName: 'Bãi đá sông Hồng',
      lat: 21, lng: 105, coverUrl: null,
    },
    ...over,
  });
}

function normalEvent(id: string, host: string, over: Partial<EventRecord> = {}): EventRecord {
  return eventRecord({
    id, title: `Sự kiện ${id}`, host: { type: 'photographer', id: host, name: host, avatarUrl: null, verified: true },
    createdBy: host, startAt: at('16:00'), endAt: at('18:00'), dayKey: TODAY, hashtagKey: '', ...over,
  });
}

const pass = (code8: string, customerId: string, bookingId: string | null, registrationIds: string[], day = TODAY): PassRecord =>
  ({
    code8, customerId, day, bookingId, eventId: registrationIds.length > 0 ? ENTRY_ID : null, registrationIds,
    createdAt: '2026-10-17T00:00:00.000Z',
  });

const staff = (staffUid: string, status: GateStaff['status']): GateStaff =>
  ({ staffUid, status, invitedAt: '2026-10-10T00:00:00.000Z', respondedAt: '2026-10-10T01:00:00.000Z' });

/**
 * The scanners of Task 4: photographer p1 (b1, b2, b4), assignee m1 of studio st1's b3, organizer org1
 * (entry event `ENTRY_ID` at s1), its active gate staff g1 and removed g3, g2 (gate staff of org2), h1
 * (host of photo walk e1) and h2 (host of e2, whose venue is s1).
 */
export async function createPassWorld(): Promise<PassWorld> {
  const be = await createBookingEntryWorld();
  const bookings = be.booking.store;
  const events = be.entry.store;

  bookings.bookings.set('b1', booking({ id: 'b1', customerId: 'c1', passCode4: P1.slice(4) }));
  bookings.bookings.set('b2', booking({
    id: 'b2', customerId: 'c2', passCode4: P3.slice(4), groupId: 'g2',
    entry: entryOf({ items: [{ ticketTypeId: 'adult', name: 'Người lớn', price: 70_000, qty: 2 }], providerTicket: true, amount: 140_000, registrationId: 'r2' }),
  }));
  bookings.bookings.set('b3', booking({
    id: 'b3', customerId: 'c3', photographerId: 'st1', isStudio: true, assigneeId: 'm1', assigneeKind: 'member',
    assignStatus: 'assigned', passCode4: P4.slice(4),
  }));
  bookings.bookings.set('b4', booking({
    id: 'b4', customerId: 'c4', passCode4: P5.slice(4),
    entry: entryOf({ waived: { provider: true, guests: false }, waivedGuests: 0 }),
  }));

  const regs: RegistrationDoc[] = [
    entryReg({ id: 'r1', userId: 'c1', userName: 'Nguyễn An', ticketCodeLast4: P2.slice(4) }),
    entryReg({ id: 'r2', userId: 'c2', userName: 'Trần Hai', bookingId: 'b2', ticketCodeLast4: P3.slice(4) }),
    entryReg({ id: 'r5', userId: 'c1', userName: 'Nguyễn An', visitDay: TOMORROW_OPEN, ticketCodeLast4: P7.slice(4) }),
    entryReg({ id: 'r6', userId: 'c1', userName: 'Nguyễn An', status: 'refunded', refundPercent: 100, ticketCodeLast4: P8.slice(4) }),
  ];
  for (const r of regs) events.registrations.set(`${r.eventId}/${r.id}`, r);

  events.seedEvent(normalEvent('e1', 'h1'));
  events.seedEvent({ ...normalEvent('e2', 'h2'), venue: {
    kind: 'managed_spot', spotId: 's1', entryFee: { included: true, amountVnd: null }, commitmentAt: null, termsVersion: ORGANIZER_TERMS_VERSION,
  } });
  events.seedRegistration(registrationDoc({ id: 'r4', eventId: 'e1', userId: 'c1', userName: 'Nguyễn An', quantity: 1, ticketCode: E1_TICKET }));
  events.seedRegistration(registrationDoc({ id: 'r3', eventId: 'e2', userId: 'c2', userName: 'Trần Hai', quantity: 3, ticketCode: E2_TICKET }));

  for (const p of [
    pass(P1, 'c1', 'b1', []), pass(P2, 'c1', null, ['r1']), pass(P3, 'c2', 'b2', ['r2']), pass(P4, 'c3', 'b3', []),
    pass(P5, 'c4', 'b4', []), pass(P7, 'c1', null, ['r5'], TOMORROW_OPEN), pass(P8, 'c1', null, ['r6']),
  ]) events.passes.set(p.code8, p);
  events.entryDays.set(`${ENTRY_ID}_${TODAY}`, {
    eventId: ENTRY_ID, day: TODAY, sold: 6, held: 0, checkedIn: 0, closed: false, updatedAt: '2026-10-17T00:00:00.000Z',
  });

  const organizers = new MemoryOrganizerStore(events.events);
  organizers.seedGateStaff('org1', staff('g1', 'active'));
  organizers.seedGateStaff('org1', staff('g3', 'removed'));
  organizers.seedGateStaff('org2', staff('g2', 'active'));

  const deps: ScanDeps = {
    scans: new MemoryScanStore(bookings, events, organizers),
    names: { displayName: async (uid) => NAMES[uid] ?? '' },
    clock: be.booking.clock,
    ids: be.booking.ids,
  };
  return {
    be,
    organizers,
    deps,
    setNow: (d) => be.booking.clock.setTime(d),
    scan: (uid, code) => scanPass(deps, uid, { code }),
    booking: (id) => must(bookings.bookings.get(id)),
    reg: (eventId, id) => must(events.registrations.get(`${eventId}/${id}`)),
  };
}
