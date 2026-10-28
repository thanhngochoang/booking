import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import { handleAnswerShootHappened, handleScanPass } from '../../src/callables/scan.js';
import { handleCheckInRegistration } from '../../src/callables/event.js';

const pw = await import('../../../../../packages/domain/test/support/pass_world.js');

const as = (uid: string, data: unknown) => ({ auth: { uid }, data });

async function refused(p: Promise<unknown>, transport: string, code: string): Promise<void> {
  await assert.rejects(p, (e: unknown) => {
    assert.ok(e instanceof HttpsError, String(e));
    assert.equal(e.code, transport);
    assert.equal((e.details as { code?: string }).code, code);
    return true;
  });
}

/** The pass world at 16:00 with b1's pass also under `7K2Q4M9P` and r4's ticket also under `VE-7K2Q-1020`. */
async function world() {
  const w = await pw.createPassWorld();
  const events = w.be.entry.store;
  const b1 = events.passes.get(pw.P1);
  assert.ok(b1);
  events.passes.set('7K2Q4M9P', { ...b1, code8: '7K2Q4M9P' });
  events.ticketCodes.set('VE-7K2Q-1020', { eventId: 'e1', registrationId: 'r4' });
  w.setNow(pw.at('16:00'));
  return w;
}

describe('scan callables', () => {
  it('every handler is unauthenticated without auth', async () => {
    const w = await world();
    await assert.rejects(handleScanPass({ data: { code: pw.P1 } }, w.deps), (e: unknown) => e instanceof HttpsError && e.code === 'unauthenticated');
    await assert.rejects(handleAnswerShootHappened({ data: {} }, w.be.bookingDeps), (e: unknown) => e instanceof HttpsError && e.code === 'unauthenticated');
    await assert.rejects(handleCheckInRegistration({ data: {} }, w.be.eventDeps), (e: unknown) => e instanceof HttpsError && e.code === 'unauthenticated');
  });

  it('scanPass accepts \'VE-7K2Q-4M9P\', \'7k2q4m9p\' and a legacy \'VE-7K2Q-1020\' ticket code', async () => {
    for (const code of ['VE-7K2Q-4M9P', '7k2q4m9p']) {
      const w = await world();
      const out = await handleScanPass(as('p1', { code }), w.deps);
      assert.deepEqual(out.booking, { id: 'b1', customerName: 'Khách Một' }, code);
      assert.equal(w.booking('b1').status, 'shooting', code);
    }
    const w = await world();
    const legacy = await handleScanPass(as('h1', { code: 'VE-7K2Q-1020' }), w.deps);
    assert.deepEqual(legacy.registrations.map((r) => [r.id, r.kind]), [['r4', 'event']]);
    assert.ok(w.reg('e1', 'r4').checkedInAt);
  });

  it('scanPass passes the caller as the scanner and maps the scan codes', async () => {
    const w = await world();
    // The photographer's pass scanned by the event host: not theirs.
    await refused(handleScanPass(as('h1', { code: pw.P1 }), w.deps), 'permission-denied', 'not_your_pass');
    await handleScanPass(as('p1', { code: pw.P1 }), w.deps);
    await refused(handleScanPass(as('p1', { code: pw.P1 }), w.deps), 'already-exists', 'already_checked_in');
    await refused(handleScanPass(as('g1', { code: pw.P7 }), w.deps), 'failed-precondition', 'wrong_day');
    await refused(handleScanPass(as('g1', { code: pw.P8 }), w.deps), 'failed-precondition', 'refunded');
    await refused(handleScanPass(as('p1', { code: 'ZZZZ2345' }), w.deps), 'not-found', 'not_found');
    await refused(handleScanPass(as('p1', { code: 42 }), w.deps), 'invalid-argument', 'invalid_argument');
    // The response names the customer and counts heads, never a phone.
    const gate = await handleScanPass(as('g1', { code: pw.P2 }), w.deps);
    assert.equal(JSON.stringify(gate).includes('+84'), false);
    assert.equal(gate.todayCount, 2);
  });

  it('checkInRegistration delegates to scanPass with the manager role', async () => {
    const w = await world();
    assert.deepEqual(await handleCheckInRegistration(as('h1', { eventId: 'e1', ticketCode: pw.E1_TICKET }), w.be.eventDeps), { name: 'Nguyễn An', quantity: 1 });
    assert.ok(w.reg('e1', 'r4').checkedInAt);
    // Old clients keep the old codes: a second scan is conflict, not already_checked_in.
    await refused(handleCheckInRegistration(as('h1', { eventId: 'e1', ticketCode: pw.E1_TICKET }), w.be.eventDeps), 'aborted', 'conflict');
    // The venue's gate may scan e2's ticket through scanPass, but the old manager-only callable refuses it.
    await refused(handleCheckInRegistration(as('org1', { eventId: 'e2', ticketCode: pw.E2_TICKET }), w.be.eventDeps), 'permission-denied', 'permission_denied');
  });

  it('answerShootHappened: the customer answers an open question; anyone else is refused', async () => {
    const w = await world();
    const store = w.be.booking.store;
    const b = w.booking('b1');
    w.setNow(new Date(pw.at('17:30').getTime() + 25 * 3_600_000));
    const asked = new Date(pw.at('17:30').getTime() + 24 * 3_600_000);
    store.bookings.set('b1', {
      ...b, shootQuestionAt: asked.toISOString(), shootQuestionUntil: new Date(asked.getTime() + 48 * 3_600_000).toISOString(),
    });
    await refused(handleAnswerShootHappened(as('p1', { bookingId: 'b1', happened: true }), w.be.bookingDeps), 'permission-denied', 'permission_denied');
    await refused(handleAnswerShootHappened(as('c1', { bookingId: 'b1', happened: 'yes' }), w.be.bookingDeps), 'invalid-argument', 'invalid_argument');
    assert.deepEqual(await handleAnswerShootHappened(as('c1', { bookingId: 'b1', happened: true }), w.be.bookingDeps), { status: 'shot' });
    await refused(handleAnswerShootHappened(as('c1', { bookingId: 'b1', happened: false }), w.be.bookingDeps), 'failed-precondition', 'not_eligible');
  });
});
