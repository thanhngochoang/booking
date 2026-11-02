import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  ORGANIZER_TERMS_VERSION,
  TicketPaymentSettler,
  groupSettler,
  publishEvent,
  registerEvent,
  respondVenueConsent,
  runPaymentSweeps,
  saveEventDraft,
  type BookingDeps,
  type EventPaymentDeps,
  type SettlementDeps,
} from '@photobooking/domain';
import { FirestoreBookingStore } from '../../src/infra/booking_firestore.js';
import { FirestoreEventStore, eventToFirestore } from '../../src/infra/event_firestore.js';
import { organizerToFirestore } from '../../src/infra/organizer_firestore.js';
import { FirestorePaymentLookup } from '../../src/infra/payment_firestore.js';
import { spotToFirestore } from '../../src/infra/spot_firestore.js';
import { MemoryFirestore } from './support/memory_firestore.js';

const bew = await import('../../../../../packages/domain/test/support/booking_entry_world.js');
const evw = await import('../../../../../packages/domain/test/support/event_world.js');
const ew = await import('../../../../../packages/domain/test/support/entry_world.js');

const ID = 'ev1_aaaaaaaaaaaaaaaaaaaa';
const PRICE = 150_000;
const FEE = 20_000;

/**
 * S30 Decisions 6, 16 on Firestore: a group opened by the EVENT store (ph1's event priced 150 000 at org1's spot s1 with
 * a venue fee of 20 000 per guest), then settled by the `payment_group` settler over the BOOKING store, and expired by
 * the payment sweeps, all on one fake Firestore.
 */
async function feeEventFirestore() {
  const w = await bew.createBookingEntryWorld();
  const d = w.eventDeps;
  await saveEventDraft(d, evw.ph1, evw.rawEvent(ID, 'ph1', {
    startAt: '2026-10-24T02:00:00.000Z', endAt: '2026-10-24T05:00:00.000Z', price: PRICE,
    venue: { kind: 'managed_spot', spotId: 's1', termsVersion: ORGANIZER_TERMS_VERSION },
  }));
  await publishEvent(d, evw.ph1, { eventId: ID });
  await respondVenueConsent(d, ew.org1, { eventId: ID, accept: true, venueFeePerGuest: FEE });
  await publishEvent(d, evw.ph1, { eventId: ID });
  const db = new MemoryFirestore();
  for (const [id, e] of w.entry.store.events) db.seed(`events/${id}`, eventToFirestore(e));
  for (const [id, s] of w.entry.store.spots) db.seed(`spots/${id}`, spotToFirestore(s));
  for (const [id, o] of w.entry.store.organizers) db.seed(`organizers/${id}`, organizerToFirestore(o));
  const fs = db.asFirestore();
  const payments = new FirestorePaymentLookup(fs);
  const eventDeps: EventPaymentDeps = { ...d, events: new FirestoreEventStore(fs), payments };
  const bookingDeps: BookingDeps = { ...w.bookingDeps, store: new FirestoreBookingStore(fs) };
  const settlement: SettlementDeps = {
    payments, gateway: w.booking.gateway, clock: w.booking.clock,
    subjects: { payment_group: groupSettler(bookingDeps), event_registration: new TicketPaymentSettler(eventDeps) },
  };
  const register = async (caller: typeof evw.cu1) => {
    const r = await registerEvent(eventDeps, caller, { eventId: ID, quantity: 1, name: 'An', method: 'bank_qr' });
    const gid = r.paymentId as string;
    const group = db.data(`payments/${gid}`);
    assert.equal(group?.subjectType, 'payment_group');
    const lines = [...db.docs.entries()].filter(([p, x]) => p.startsWith('payments/') && x.groupId === gid).map(([p]) => p);
    return { r, gid, code: String(group?.transferCode), lines };
  };
  return { w, db, bookingDeps, settlement, register };
}

describe('event-store groups (venue fee) on Firestore', () => {
  it('registerEvent opens a group; a short transfer leaves the lines awaiting_group; reaching the total pays both lines', async () => {
    const { w, db, bookingDeps, register } = await feeEventFirestore();
    const { r, gid, code, lines } = await register(evw.cu1);
    assert.equal(db.data(`payments/${gid}`)?.amount, PRICE);
    assert.deepEqual(lines.map((p) => db.data(p)?.lineKind).sort(), ['event_ticket', 'venue_fee']);
    assert.equal(db.data(`payment_groups/${gid}`)?.total, PRICE);
    const settler = groupSettler(bookingDeps);

    assert.equal(await settler.settle(gid, bew.transfer(w, code, PRICE - 10_000, 'txn_short')), 'partial');
    for (const p of lines) assert.equal(db.data(p)?.status, 'awaiting_group', p);
    assert.equal(db.data(`events/${ID}/registrations/${r.registrationId}`)?.status, 'held');

    // The rest of the total (received amounts add up) pays the group: both lines at once.
    assert.equal(await settler.settle(gid, bew.transfer(w, code, 10_000, 'txn_rest')), 'paid');
    for (const p of lines) assert.deepEqual([db.data(p)?.status, db.data(p)?.escrowStatus], ['paid', 'held'], p);
    assert.deepEqual(
      lines.map((p) => [db.data(p)?.lineKind, db.data(p)?.amount]).sort(),
      [['event_ticket', PRICE - FEE], ['venue_fee', FEE]],
    );
    const reg = db.data(`events/${ID}/registrations/${r.registrationId}`);
    assert.equal(reg?.status, 'paid');
    assert.equal(db.data(`events/${ID}`)?.registeredCount, 1);
    assert.equal(db.data(`payment_groups/${gid}`)?.status, 'paid');
  });

  it('the payment sweeps expire an unpaid group with its lines and give the seat back', async () => {
    const { w, db, settlement, register } = await feeEventFirestore();
    const { r, gid, lines } = await register(evw.cu2);
    assert.equal(db.data(`events/${ID}`)?.heldCount, 1);
    w.booking.clock.advanceMinutes(16);
    await runPaymentSweeps(settlement);
    assert.equal(db.data(`payments/${gid}`)?.status, 'expired');
    for (const p of lines) assert.equal(db.data(p)?.status, 'expired', p);
    assert.equal(db.data(`events/${ID}/registrations/${r.registrationId}`)?.status, 'cancelled');
    assert.equal(db.data(`events/${ID}`)?.heldCount, 0);
    assert.equal(db.data(`payment_groups/${gid}`)?.status, 'expired');
  });
});
