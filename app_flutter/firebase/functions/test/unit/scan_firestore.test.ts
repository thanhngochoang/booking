import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { scanPass, type ScanDeps } from '@photobooking/domain';
import { bookingToFirestore } from '../../src/infra/booking_firestore.js';
import { entryDayToFirestore, eventToFirestore, registrationToFirestore } from '../../src/infra/event_firestore.js';
import { gateStaffToFirestore } from '../../src/infra/organizer_firestore.js';
import { passToFirestore } from '../../src/infra/pass_firestore.js';
import { FirestoreScanStore } from '../../src/infra/scan_firestore.js';
import { spotToFirestore } from '../../src/infra/spot_firestore.js';
import { MemoryFirestore } from './support/memory_firestore.js';

const pw = await import('../../../../../packages/domain/test/support/pass_world.js');

/** Task 4's pass world (bookings, entry tickets, legacy tickets, gate staff) copied into a fake Firestore. */
async function scanFirestore(): Promise<{ db: MemoryFirestore; deps: ScanDeps }> {
  const w = await pw.createPassWorld();
  const db = new MemoryFirestore();
  for (const [id, b] of w.be.booking.store.bookings) db.seed(`bookings/${id}`, bookingToFirestore(b));
  const events = w.be.entry.store;
  for (const [id, e] of events.events) db.seed(`events/${id}`, eventToFirestore(e));
  for (const r of events.registrations.values()) db.seed(`events/${r.eventId}/registrations/${r.id}`, registrationToFirestore(r));
  for (const [code, t] of events.ticketCodes) db.seed(`ticket_codes/${code}`, { ...t });
  for (const p of events.passes.values()) db.seed(`passes/${p.code8}`, passToFirestore(p));
  for (const [key, d] of events.entryDays) db.seed(`entry_days/${key}`, entryDayToFirestore(d));
  for (const [id, s] of events.spots) db.seed(`spots/${id}`, spotToFirestore(s));
  for (const [org, rows] of w.organizers.gateStaff) {
    for (const g of rows.values()) db.seed(`organizers/${org}/gate_staff/${g.staffUid}`, gateStaffToFirestore(g));
  }
  w.setNow(pw.at('16:00'));
  return { db, deps: { ...w.deps, scans: new FirestoreScanStore(db.asFirestore()) } };
}

const gateRows = (paths: readonly string[]) => paths.filter((p) => p.includes('/gate_staff/'));

describe('FirestoreScanStore', () => {
  it('the shooter\'s scan is one transaction: the booking moves to shooting, its event row is added', async () => {
    const { db, deps } = await scanFirestore();
    const before = db.transactions;
    const out = await scanPass(deps, 'p1', { code: pw.P1 });
    assert.equal(db.transactions - before, 1);
    assert.deepEqual(out.booking, { id: 'b1', customerName: 'Khách Một' });
    assert.equal(db.data('bookings/b1')?.status, 'shooting');
    assert.ok(db.data('bookings/b1')?.checkedInAt);
    const tx = db.txLog.at(-1);
    assert.ok(tx?.writes.some((p) => p.startsWith('bookings/b1/events/')));
  });

  it('scan_firestore collects only the roles the pass\'s parts need', async () => {
    const { db, deps } = await scanFirestore();
    // A booking-only pass: no gate staff row, no spot is read.
    await scanPass(deps, 'p1', { code: pw.P1 });
    let reads = db.txLog.at(-1)?.reads ?? [];
    assert.deepEqual(gateRows(reads), []);
    assert.equal(reads.some((p) => p.startsWith('spots/')), false);

    // An entry ticket scanned by org1's gate staff g1: only g1's row of org1 (never org2's) is read.
    const out = await scanPass(deps, 'g1', { code: pw.P2 });
    reads = db.txLog.at(-1)?.reads ?? [];
    assert.deepEqual(gateRows(reads), ['organizers/org1/gate_staff/g1']);
    assert.equal(out.registrations[0]?.kind, 'entry');
    assert.equal(out.todayCount, 2);
    assert.equal(db.data(`entry_days/${pw.ENTRY_ID}_${pw.TODAY}`)?.checkedIn, 2);
    assert.deepEqual(db.data('organizers/org1/gate_staff/g1')?.scansToday, { day: pw.TODAY, count: 1 });
    assert.ok(db.data(`events/${pw.ENTRY_ID}/registrations/r1`)?.checkedInAt);
  });

  it('gate staff of another organizer is not_your_pass and nothing is written', async () => {
    const { db, deps } = await scanFirestore();
    const writes = db.log.length;
    await assert.rejects(scanPass(deps, 'g2', { code: pw.P2 }), { code: 'not_your_pass' });
    assert.equal(db.log.length, writes);
  });

  it('a legacy VE-XXXX-MMDD ticket resolves through ticket_codes for its host', async () => {
    const { db, deps } = await scanFirestore();
    const out = await scanPass(deps, 'h1', { code: pw.E1_TICKET });
    assert.equal(out.registrations[0]?.kind, 'event');
    assert.ok(db.data('events/e1/registrations/r4')?.checkedInAt);
  });
});
