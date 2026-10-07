import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  FakePaymentGateway,
  FakePayoutGateway,
  MemoryBookingStore,
  MemoryEventStore,
  MemoryPayoutStore,
  createPayout,
  listDuePayees,
  savePayoutAccount,
  type PayoutDeps,
  confirmFakeTicketPayment,
  publishEvent,
  registerEvent,
  runEventSweeps,
  saveEventDraft,
  type BookingDeps,
  type EventCaller,
  type EventPaymentDeps,
  type Payment,
} from '@photobooking/domain';
import { handleBookingClock } from '../../src/scheduled/booking_clock.js';

// Ticket money goes through the booking escrow release (bookingClock step 5) unchanged: the event
// clock only stamps `releaseAfter` at completion. Both stores stand for the same `payments`
// collection in Firestore, so the payment the event flow produced is handed to the booking store.

const ID = (n: number): string => `01ARZ3NDEKTSV4RRFFQ69G5F${String(n).padStart(2, '0')}`;
const EVENT_ID = ID(1);
const START = new Date('2026-10-12T02:00:00.000Z');
const END = new Date('2026-10-12T05:00:00.000Z');
const HOUR = 3_600_000;

async function completedTicket(host: EventCaller): Promise<Payment> {
  const store = new MemoryEventStore();
  let now = new Date('2026-10-06T03:00:00.000Z');
  let next = 10;
  const deps: EventPaymentDeps = {
    events: store,
    people: {
      photographer: async (uid) => (uid === 'ph1' ? { onboardingComplete: true, name: 'Lan', avatarUrl: null, verified: true } : null),
      user: async (uid) => ({ name: uid, avatarUrl: null }),
    },
    contacts: { get: async () => ({ phone: '+84912000001' }) },
    media: { isOwnUpload: (url, path, uid, eventId) => path.startsWith(`eventCovers/${uid}/${eventId}/`) && url.endsWith(path) },
    clock: { now: () => now },
    ids: { newId: () => ID(next++) },
    random: (n) => Uint8Array.from({ length: n }, (_, i) => (i * 37 + 11) % 256),
    gateway: new FakePaymentGateway(),
  };
  const path = `eventCovers/${host.uid}/${EVENT_ID}/c.jpg`;
  await saveEventDraft(deps, host, {
    eventId: EVENT_ID, title: 'Photo walk', type: 'photo_walk', coverUrl: `https://s.test/${path}`, coverPath: path,
    startAt: START.toISOString(), endAt: END.toISOString(),
    location: { name: 'Hồ Gươm', lat: 21.0285, lng: 105.8542 }, capacity: 5, price: 200_000,
  });
  await publishEvent(deps, host, { eventId: EVENT_ID });
  const cu1: EventCaller = { uid: 'cu1', staffRole: null };
  const r = await registerEvent(deps, cu1, { eventId: EVENT_ID, quantity: 1, name: 'An', provider: 'momo' });
  await confirmFakeTicketPayment(deps, cu1, { paymentId: r.paymentId });
  now = new Date(END.getTime() + 60_000);
  await runEventSweeps(deps);
  const p = store.payments.get(r.paymentId as string);
  assert.ok(p);
  return p;
}

function bookingDeps(store: MemoryBookingStore, now: Date): BookingDeps {
  let next = 1;
  return {
    store,
    services: { getService: async () => null },
    contacts: { get: async () => null },
    providers: { acceptsOrders: async () => true },
    gateway: new FakePaymentGateway(),
    clock: { now: () => now },
    ids: { newId: () => `led_${next++}` },
  };
}

const ADMIN = { uid: 'admin1', isAdmin: true } as const;

function payoutDeps(store: MemoryBookingStore, now: Date): PayoutDeps {
  const payoutStore = new MemoryPayoutStore(store);
  payoutStore.seedRole('ph1', 'photographer');
  let next = 1;
  return {
    store: payoutStore,
    cipher: { encrypt: async (p) => `enc:${p}`, decrypt: async (e) => e.slice(4) },
    clock: { now: () => now },
    ids: { newId: () => `po_${next++}` },
    gateway: new FakePayoutGateway(),
  };
}

describe('bookingClock and ticket money', () => {
  it('bookingClock releases a ticket payment after the window to the host', async () => {
    const ticket = await completedTicket({ uid: 'ph1', staffRole: null });
    assert.equal(ticket.releaseAfter, new Date(END.getTime() + 24 * HOUR).toISOString());
    const store = new MemoryBookingStore();
    store.payments.set(ticket.id, ticket);

    // Not before end + 24 h.
    await handleBookingClock(bookingDeps(store, new Date(END.getTime() + 23 * HOUR)));
    assert.equal(store.payments.get(ticket.id)?.escrowStatus, 'held');

    const results = await handleBookingClock(bookingDeps(store, new Date(END.getTime() + 24 * HOUR)));
    assert.equal(results.releasedEscrows, 1);
    const released = store.payments.get(ticket.id);
    assert.equal(released?.escrowStatus, 'released');
    const entries = [...store.ledgerEntries.values()].filter((e) => e.paymentId === ticket.id);
    assert.deepEqual(entries.map((e) => [e.type, e.accountOwnerId, e.amount, e.subjectType]),
      [['escrow_released', 'ph1', 200_000, 'event_registration']]);
    // No booking is touched (the subject is a registration).
    assert.equal(store.bookings.size, 0);
    // Released once.
    assert.equal((await handleBookingClock(bookingDeps(store, new Date(END.getTime() + 48 * HOUR)))).releasedEscrows, 0);
  });

  it('a platform event\'s ticket money is released to platform', async () => {
    const ticket = await completedTicket({ uid: 'ad1', staffRole: 'admin' });
    assert.equal(ticket.payeeId, 'platform');
    const store = new MemoryBookingStore();
    store.payments.set(ticket.id, ticket);
    await handleBookingClock(bookingDeps(store, new Date(END.getTime() + 25 * HOUR)));
    const [entry] = [...store.ledgerEntries.values()];
    assert.deepEqual([entry?.type, entry?.accountOwnerId], ['escrow_released', 'platform']);
  });

  it('a released ticket payment is paid out to the host exactly once', async () => {
    const ticket = await completedTicket({ uid: 'ph1', staffRole: null });
    const store = new MemoryBookingStore();
    store.payments.set(ticket.id, ticket);
    const at = new Date(END.getTime() + 25 * HOUR);
    await handleBookingClock(bookingDeps(store, at));
    const deps = payoutDeps(store, at);
    await savePayoutAccount(deps, { uid: 'ph1', authTime: at }, { bankCode: 'VCB', accountNumber: '0123456789', holderName: 'Lan' });
    assert.deepEqual(await listDuePayees(deps, ADMIN), [{ payeeId: 'ph1', amount: 200_000, hasAccount: true }]);
    const po = await createPayout(deps, ADMIN, 'ph1');
    assert.deepEqual(po.items, [{ paymentId: ticket.id, amount: 200_000 }]);
    assert.equal(store.payments.get(ticket.id)?.payoutId, po.id);
    assert.deepEqual(await listDuePayees(deps, ADMIN), []);
    await assert.rejects(createPayout(deps, ADMIN, 'ph1'), /not_eligible/);
  });

  it('a platform event\'s released ticket money never enters a provider payout', async () => {
    const ticket = await completedTicket({ uid: 'ad1', staffRole: 'admin' });
    const store = new MemoryBookingStore();
    store.payments.set(ticket.id, ticket);
    const at = new Date(END.getTime() + 25 * HOUR);
    await handleBookingClock(bookingDeps(store, at));
    assert.equal(store.payments.get(ticket.id)?.escrowStatus, 'released');
    const deps = payoutDeps(store, at);
    assert.deepEqual(await listDuePayees(deps, ADMIN), []);
    await assert.rejects(createPayout(deps, ADMIN, 'platform'), /not_eligible/);
  });
});
