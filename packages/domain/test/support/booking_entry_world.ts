import type { Booking } from '../../src/booking.js';
import type { BookingDeps, TransferNotification } from '../../src/booking_ports.js';
import { createBookingDraft } from '../../src/create_booking.js';
import { createPayment, type CreatePaymentResult } from '../../src/create_payment.js';
import type { Payment } from '../../src/escrow.js';
import type { EventPaymentDeps } from '../../src/event_ports.js';
import { bookingTicketLines, TicketPaymentSettler } from '../../src/event_payments.js';
import { groupSettler } from '../../src/group_settlement.js';
import { BookingPaymentSettler } from '../../src/handle_transfer.js';
import { MemoryGroupStore } from '../../src/memory_group_store.js';
import { MemoryPaymentLookup } from '../../src/memory_payment_lookup.js';
import type { Resident } from '../../src/organizer.js';
import { settleTransfer, type SettlementDeps } from '../../src/payment_settlement.js';
import { createBookingWorld, transferOf, type BookingWorld } from './booking_world.js';
import { ENTRY_ID, ENTRY_NOW, VISIT, createEntryWorld, publishedEntry, type EntryWorld } from './entry_world.js';

export { ENTRY_ID, ENTRY_NOW, VISIT };

/**
 * A booking world and the entry world sharing one clock (the booking world's) and one group store:
 * org1 sells entry tickets for spot s1 (adult 70 000, child 40 000, 10 a day; Mondays and 2026-10-25
 * closed); p1 is a resident of s1 who `waivesProvider`, p3 is not a resident. Customer c1 has a phone.
 */
export interface BookingEntryWorld {
  readonly booking: BookingWorld;
  readonly entry: EntryWorld;
  readonly bookingDeps: BookingDeps;
  readonly eventDeps: EventPaymentDeps;
  readonly groups: MemoryGroupStore;
  readonly settlement: SettlementDeps;
}

export function residentOf(providerId: string, over: Partial<Resident> = {}): Resident {
  return {
    providerId, waivesProvider: false, waivesGuests: false, maxGuests: null, validUntil: null,
    addedAt: '2026-10-01T00:00:00.000Z', addedBy: 'org1', ...over,
  };
}

export async function createBookingEntryWorld(): Promise<BookingEntryWorld> {
  const booking = createBookingWorld(ENTRY_NOW);
  const ew = createEntryWorld();
  const eventDeps: EventPaymentDeps = {
    ...ew.deps,
    clock: booking.clock,
    payments: new MemoryPaymentLookup([ew.store, booking.store]),
  };
  const entry: EntryWorld = { ...ew, deps: eventDeps };
  await publishedEntry(entry);
  entry.store.residents.set('s1/p1', residentOf('p1', { waivesProvider: true }));

  booking.providers.set('p3', { verified: true, onboardingComplete: true });
  booking.services.set('srv_p3', {
    id: 'srv_p3', photographerId: 'p3', name: 'Gói Bãi đá', price: 1_000_000, durationMinutes: 120, active: true,
  });

  const groups = new MemoryGroupStore(booking.store, entry.store);
  const bookingDeps: BookingDeps = { ...booking.deps, tickets: bookingTicketLines(eventDeps) };
  const settlement: SettlementDeps = {
    payments: new MemoryPaymentLookup([booking.store, entry.store]),
    gateway: booking.gateway,
    clock: booking.clock,
    subjects: {
      booking: new BookingPaymentSettler(bookingDeps),
      event_registration: new TicketPaymentSettler(eventDeps),
      payment_group: groupSettler(bookingDeps, groups),
    },
  };
  return { booking, entry, bookingDeps, eventDeps, groups, settlement };
}

/** c1 books p3 (`srv_p3`, 1 000 000) on the visit day at 09:00 with one adult ticket (+ p3's). */
export function entryDraft(w: BookingEntryWorld, over: Record<string, unknown> = {}, entry: Record<string, unknown> = {}): Promise<Booking> {
  return createBookingDraft(w.bookingDeps, {
    customerId: 'c1',
    photographerId: 'p3',
    serviceId: 'srv_p3',
    day: VISIT,
    start: '09:00',
    place: { name: 'Bãi đá sông Hồng' },
    entry: { eventId: ENTRY_ID, visitDay: VISIT, items: [{ ticketTypeId: 'adult', qty: 1 }], ...entry },
    ...over,
  });
}

export const payEntry = (w: BookingEntryWorld, bookingId: string): Promise<CreatePaymentResult> =>
  createPayment(w.bookingDeps, { bookingId, customerId: 'c1', method: 'bank_qr' });

export const transfer = (w: BookingEntryWorld, code: string, amount: number, txnId?: string): TransferNotification =>
  transferOf(w.booking, { content: code, amount, ...(txnId === undefined ? {} : { txnId }) });

export const send = (w: BookingEntryWorld, n: TransferNotification) => settleTransfer(w.settlement, n);

/** Every payment of either store. */
export function paymentOf(w: BookingEntryWorld, id: string): Payment | undefined {
  return w.booking.store.payments.get(id) ?? w.entry.store.payments.get(id);
}

export function childrenOf(w: BookingEntryWorld, groupId: string): Payment[] {
  return [...w.booking.store.payments.values(), ...w.entry.store.payments.values()].filter((p) => p.groupId === groupId);
}
