import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { groupSettler, type BookingDeps, type PaymentGroupView } from '@photobooking/domain';
import {
  FirestoreBookingStore,
  bookingToFirestore,
  paymentGroupFromFirestore,
  paymentGroupToFirestore,
  paymentToFirestore,
} from '../../src/infra/booking_firestore.js';
import { entryDayToFirestore, eventToFirestore, registrationToFirestore } from '../../src/infra/event_firestore.js';
import { MemoryFirestore } from './support/memory_firestore.js';

const bew = await import('../../../../../packages/domain/test/support/booking_entry_world.js');

/** c1's booking of p3 with one adult ticket (+ p3's), its group payment opened in memory, then copied to a fake Firestore. */
async function groupFirestore() {
  const w = await bew.createBookingEntryWorld();
  const draft = await bew.entryDraft(w);
  const pay = await bew.payEntry(w, draft.id);
  assert.ok(pay.groupId !== undefined && pay.lines !== undefined && pay.lines.length >= 2);
  const db = new MemoryFirestore();
  for (const [id, b] of w.booking.store.bookings) db.seed(`bookings/${id}`, bookingToFirestore(b));
  for (const p of [...w.booking.store.payments.values(), ...w.entry.store.payments.values()]) db.seed(`payments/${p.id}`, paymentToFirestore(p));
  for (const [id, e] of w.entry.store.events) db.seed(`events/${id}`, eventToFirestore(e));
  for (const r of w.entry.store.registrations.values()) db.seed(`events/${r.eventId}/registrations/${r.id}`, registrationToFirestore(r));
  for (const [key, d] of w.entry.store.entryDays) db.seed(`entry_days/${key}`, entryDayToFirestore(d));
  const deps: BookingDeps = { ...w.bookingDeps, store: new FirestoreBookingStore(db.asFirestore()) };
  const group = w.booking.store.payments.get(pay.groupId) ?? w.entry.store.payments.get(pay.groupId);
  assert.ok(group?.transferCode !== undefined);
  return { w, db, deps, groupId: pay.groupId, lines: pay.lines, total: group.amount, code: group.transferCode, bookingId: draft.id };
}

describe('payment groups on Firestore', () => {
  it('payment_groups round-trip', () => {
    const g: PaymentGroupView = {
      id: 'g1', payerId: 'c1',
      lines: [
        { paymentId: 'p1', kind: 'booking', subjectType: 'booking', subjectId: 'b1', payeeId: 'ph1', amount: 1_000_000 },
        { paymentId: 'p2', kind: 'entry_ticket', subjectType: 'event_registration', subjectId: 'r1', payeeId: 'org1', amount: 140_000 },
      ],
      total: 1_140_000, status: 'created',
      expiresAt: '2026-10-18T03:15:00.000Z', createdAt: '2026-10-18T03:00:00.000Z', updatedAt: '2026-10-18T03:00:00.000Z',
    };
    assert.deepEqual(paymentGroupFromFirestore(g.id, paymentGroupToFirestore(g)), g);
    assert.equal(paymentGroupFromFirestore('x', undefined), null);
  });

  it('the group settler\'s Firestore transaction reads the group, its children and their subjects before any write, and a transfer below the total leaves the children awaiting_group', async () => {
    const { w, db, deps, groupId, lines, total, code } = await groupFirestore();
    const n = bew.transfer(w, code, total - 10_000, 'txn_short');
    // MemoryTransaction refuses a read after a write, so a settled transfer proves every read came first.
    const outcome = await groupSettler(deps).settle(groupId, n);
    assert.equal(outcome, 'partial');
    const tx = db.txLog.at(-1);
    assert.ok(tx?.reads.includes(`payments/${groupId}`));
    for (const l of lines) {
      assert.ok(tx?.reads.includes(`payments/${l.paymentId}`), `child ${l.kind} read`);
      assert.equal(db.data(`payments/${l.paymentId}`)?.status, 'awaiting_group', `${l.kind} stays awaiting_group`);
    }
    const booking = lines.find((l) => l.kind === 'booking');
    assert.ok(booking && tx?.reads.includes(`bookings/${booking.subjectId}`));
    assert.equal([...db.docs.keys()].some((p) => p.startsWith('passes/')), false);
  });

  it('the exact total pays every child, writes one pass and the group view', async () => {
    const { w, db, deps, groupId, lines, total, code, bookingId } = await groupFirestore();
    const outcome = await groupSettler(deps).settle(groupId, bew.transfer(w, code, total, 'txn_exact'));
    assert.equal(outcome, 'paid');
    for (const l of lines) assert.equal(db.data(`payments/${l.paymentId}`)?.status, 'paid');
    assert.equal(db.data(`payments/${groupId}`)?.status, 'paid');
    assert.equal(db.data(`payment_groups/${groupId}`)?.status, 'paid');
    const passes = [...db.docs.keys()].filter((p) => p.startsWith('passes/'));
    assert.equal(passes.length, 1);
    assert.ok(db.data(`bookings/${bookingId}/private/pass`)?.code);
  });
});
