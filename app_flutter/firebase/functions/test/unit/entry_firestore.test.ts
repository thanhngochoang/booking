import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { registerEntry, type EventPaymentDeps } from '@photobooking/domain';
import {
  FirestoreEventStore,
  eventFromFirestore,
  eventToFirestore,
  registrationFromFirestore,
  registrationToFirestore,
} from '../../src/infra/event_firestore.js';
import { FirestorePaymentLookup } from '../../src/infra/payment_firestore.js';
import { organizerToFirestore } from '../../src/infra/organizer_firestore.js';
import { spotToFirestore } from '../../src/infra/spot_firestore.js';
import { MemoryFirestore } from './support/memory_firestore.js';

const { createEntryWorld, publishedEntry, ENTRY_ID, VISIT } = await import('../../../../../packages/domain/test/support/entry_world.js');
const { eventRecord, registrationDoc, cu1, cu2 } = await import('../../../../../packages/domain/test/support/event_world.js');

/** org1's published entry event on s1 (capacity 10 a day) copied into a fake Firestore. */
async function entryFirestore(): Promise<{ db: MemoryFirestore; deps: EventPaymentDeps }> {
  const w = createEntryWorld();
  await publishedEntry(w);
  const db = new MemoryFirestore();
  const ev = w.store.events.get(ENTRY_ID);
  if (ev === undefined) throw new Error('no entry event');
  db.seed(`events/${ENTRY_ID}`, eventToFirestore(ev));
  for (const [id, s] of w.store.spots) db.seed(`spots/${id}`, spotToFirestore(s));
  for (const [id, o] of w.store.organizers) db.seed(`organizers/${id}`, organizerToFirestore(o));
  const firestore = db.asFirestore();
  return {
    db,
    deps: { ...w.deps, events: new FirestoreEventStore(firestore), payments: new FirestorePaymentLookup(firestore) },
  };
}

const buy = (deps: EventPaymentDeps, caller: typeof cu1, qty: number) =>
  registerEntry(deps, caller, { eventId: ENTRY_ID, visitDay: VISIT, items: [{ ticketTypeId: 'adult', qty }], name: 'Nguyễn An', method: 'bank_qr' });

describe('entry events on Firestore', () => {
  it('eventToFirestore writes entry fields and venue; eventFromFirestore reads old events with venue null and type photo_walk', () => {
    const entry = eventRecord({
      id: 'en1', type: 'entry', host: { type: 'organizer', id: 'org1', name: 'Bãi đá', avatarUrl: null, verified: true },
      spotId: 's1', closedWeekdays: [1], closedDays: ['2026-10-25'], openHours: { start: '08:00', end: '17:00' },
      ticketTypes: [{ id: 'adult', name: 'Người lớn', price: 70_000, hidden: false }], dailyCapacity: 10, refundCutoffHours: 48,
      venue: null, venueConsent: 'not_required', venueConsentExpiresAt: null, venueFeePerGuest: 0, venueManagerId: null,
    });
    const d = eventToFirestore(entry);
    assert.equal(d.type, 'entry');
    assert.deepEqual(d.host, { type: 'organizer', id: 'org1', name: 'Bãi đá', avatarUrl: null, verified: true });
    assert.deepEqual(d.ticketTypes, [{ id: 'adult', name: 'Người lớn', price: 70_000, hidden: false }]);
    assert.deepEqual(d.openHours, { start: '08:00', end: '17:00' });
    assert.equal(d.dailyCapacity, 10);
    assert.equal(d.venueConsent, 'not_required');
    const back = eventFromFirestore('en1', d);
    assert.equal(back.type, 'entry');
    assert.equal(back.host.type, 'organizer');
    assert.deepEqual(back.closedDays, ['2026-10-25']);

    const venue = { kind: 'managed_spot' as const, spotId: 's1', entryFee: { included: true, amountVnd: null }, commitmentAt: null, termsVersion: '2026-10-18' };
    const walk = eventToFirestore(eventRecord({ id: 'w1', venue, venueConsent: 'pending', venueFeePerGuest: 10_000 }));
    assert.deepEqual(walk.venue, venue);
    assert.equal(walk.closedWeekdays, undefined);
    assert.deepEqual(eventFromFirestore('w1', walk).venue, venue);

    // A document written before S30: no venue, no venueConsent, type photo_walk.
    const old = { ...eventToFirestore(eventRecord({ id: 'old1' })) } as Record<string, unknown>;
    delete old.venue;
    delete old.venueConsent;
    delete old.venueFeePerGuest;
    const read = eventFromFirestore('old1', old);
    assert.equal(read.type, 'photo_walk');
    assert.equal(read.venue, null);
    assert.equal(read.venueConsent, 'not_required');
    assert.equal(read.venueFeePerGuest, 0);
  });

  it('registrationToFirestore writes ticketCodeLast4 and no ticketCode for a new registration; legacy rows keep ticketCode', () => {
    const fresh = registrationDoc({ id: 'r1', eventId: 'en1', ticketCode: '', ticketCodeLast4: '4M9P', visitDay: VISIT, items: [], bookingId: null });
    const d = registrationToFirestore(fresh);
    assert.equal('ticketCode' in d, false);
    assert.equal(d.ticketCodeLast4, '4M9P');
    assert.equal(registrationFromFirestore('r1', d).ticketCode, '');

    const legacy = registrationDoc({ id: 'r2', ticketCode: 'VE-ABCD-1004' });
    assert.equal(registrationToFirestore(legacy).ticketCode, 'VE-ABCD-1004');
    assert.equal(registrationFromFirestore('r2', registrationToFirestore(legacy)).ticketCode, 'VE-ABCD-1004');

    // A normal event's ticket paid with a pass (venue-fee group) keeps its last 4 too.
    const withPass = registrationDoc({ id: 'r3', ticketCode: 'VE-ABCD-1004', ticketCodeLast4: 'K2QM' });
    assert.equal(registrationToFirestore(withPass).ticketCodeLast4, 'K2QM');
    assert.equal(registrationFromFirestore('r3', registrationToFirestore(withPass)).ticketCodeLast4, 'K2QM');
  });

  it('FirestoreEventStore reads and writes entry_days inside the registration transaction', async () => {
    const { db, deps } = await entryFirestore();
    const dayPath = `entry_days/${ENTRY_ID}_${VISIT}`;
    const r = await buy(deps, cu1, 2);
    assert.equal(r.status, 'held');
    const tx = db.txLog.find((t) => t.writes.some((p) => p.endsWith(`/registrations/${r.registrationId}`)));
    assert.ok(tx, 'the registration is written by a transaction');
    assert.ok(tx.reads.includes(dayPath), 'entry_days read in that transaction');
    assert.ok(tx.writes.includes(dayPath), 'entry_days written in that transaction');
    assert.equal(db.data(dayPath)?.held, 2);
    // No public ticket code and no empty ticket_codes row for an entry ticket.
    assert.equal('ticketCode' in (db.data(`events/${ENTRY_ID}/registrations/${r.registrationId}`) ?? {}), false);
    assert.equal([...db.docs.keys()].some((p) => p.startsWith('ticket_codes/')), false);
  });

  it('the last seats of a day: a buyer past dailyCapacity is sold_out_day and nothing is written', async () => {
    const { db, deps } = await entryFirestore();
    const dayPath = `entry_days/${ENTRY_ID}_${VISIT}`;
    db.seed(dayPath, { eventId: ENTRY_ID, day: VISIT, sold: 8, held: 0, checkedIn: 0, closed: false });
    await buy(deps, cu1, 2);
    const writes = db.log.length;
    await assert.rejects(buy(deps, cu2, 2), { code: 'sold_out_day' });
    assert.equal(db.log.length, writes);
    assert.equal(db.data(dayPath)?.held, 2);
  });

  it('putTicketCode never writes an empty code', async () => {
    const db = new MemoryFirestore();
    const store = new FirestoreEventStore(db.asFirestore());
    await store.runTransaction(async (tx) => {
      tx.putTicketCode('', 'e1', 'r1');
      tx.putTicketCode('VE-ABCD-1004', 'e1', 'r2');
    });
    assert.deepEqual([...db.docs.keys()].filter((p) => p.startsWith('ticket_codes/')), ['ticket_codes/VE-ABCD-1004']);
  });
});
