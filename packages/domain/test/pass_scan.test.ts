import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { runBookingSweeps } from '../src/booking_sweeps.js';
import { bookingContactUnlocked } from '../src/contact.js';
import { openDispute } from '../src/dispute_use_cases.js';
import { DomainError, type ErrorCode } from '../src/errors.js';
import { checkInRegistration } from '../src/event_registration.js';
import { SCAN_REFUSALS_PER_HOUR, afterRefusal, resolveScan, scanBudgetSpent, scanPass, type ScanAttempts } from '../src/pass_scan.js';
import { bookingView, createDisputeWorld, openInput, paidPayment } from './support/dispute_world.js';
import {
  E1_TICKET, E2_TICKET, ENTRY_ID, P1, P2, P3, P4, P5, P7, P8, TODAY, at, createPassWorld, type PassWorld,
} from './support/pass_world.js';

const HOUR = 3_600_000;
const code = (c: ErrorCode) => (e: unknown) => e instanceof DomainError && e.code === c;
const day = (w: PassWorld) => w.be.entry.store.entryDays.get(`${ENTRY_ID}_${TODAY}`);
const staffRow = (w: PassWorld, org: string, uid: string) => w.organizers.gateStaff.get(org)?.get(uid);
/** Every registration of the world, as a comparable snapshot. */
const regsSnapshot = (w: PassWorld) => JSON.stringify([...w.be.entry.store.registrations.entries()]);

async function world(now = at('14:00')): Promise<PassWorld> {
  const w = await createPassWorld();
  w.setNow(now);
  return w;
}

describe('scanPass by the shooter (Decision 9, Review Focus 2)', () => {
  test("the shooter's scan at 14:00 moves b1 to shooting with checkedInAt and leaves registrations untouched", async () => {
    const w = await world();
    const before = regsSnapshot(w);
    const r = await w.scan('p1', P1);
    assert.deepEqual(r.booking, { id: 'b1', customerName: 'Khách Một' });
    assert.deepEqual(r.registrations, []);
    const b = w.booking('b1');
    assert.equal(b.status, 'shooting');
    assert.equal(b.checkedInAt, at('14:00').toISOString());
    assert.equal(b.version, 2);
    assert.equal(regsSnapshot(w), before);
    const ev = w.be.booking.store.events.filter((e) => e.bookingId === 'b1');
    assert.deepEqual(ev.map((e) => [e.status, e.actorId]), [['shooting', 'p1']]);
  });

  test('at 13:29 it is too_early (opens 13:30)', async () => {
    const w = await world(at('13:29'));
    await assert.rejects(w.scan('p1', P1), (e: unknown) =>
      code('too_early')(e) && (e as DomainError).details?.opensAt === at('13:30').toISOString());
    w.setNow(at('13:30'));
    assert.equal((await w.scan('p1', P1)).booking?.id, 'b1');
  });

  test('the day after it is wrong_day', async () => {
    const w = await world(at('09:00', '2026-10-19'));
    await assert.rejects(w.scan('p1', P1), (e: unknown) => code('wrong_day')(e) && (e as DomainError).details?.day === TODAY);
    assert.equal(w.booking('b1').status, 'upcoming');
  });

  test('a second scan is already_checked_in', async () => {
    const w = await world();
    await w.scan('p1', P1);
    w.setNow(at('14:05'));
    await assert.rejects(w.scan('p1', 've-bkng-2345'), (e: unknown) =>
      code('already_checked_in')(e) && (e as DomainError).details?.at === at('14:00').toISOString());
  });

  test('the customer scanning their own pass is not_your_pass', async () => {
    const w = await world();
    await assert.rejects(w.scan('c1', P1), code('not_your_pass'));
    assert.equal(w.booking('b1').status, 'upcoming');
  });

  test('the studio assignee may scan b3; the studio owner may not when an assignee exists', async () => {
    const w = await world();
    await assert.rejects(w.scan('st1', P4), code('not_your_pass'));
    assert.equal((await w.scan('m1', P4)).booking?.id, 'b3');
    assert.equal(w.booking('b3').status, 'shooting');
  });

  test('an unknown code is not_found; garbage is invalid_argument', async () => {
    const w = await world();
    await assert.rejects(w.scan('p1', 'ZZZZ2345'), code('not_found'));
    await assert.rejects(w.scan('p1', 'VE-ZZZZ-1018'), code('not_found'));
    await assert.rejects(w.scan('p1', 'hello'), code('not_found'));
    const { scanPass } = await import('../src/pass_scan.js');
    await assert.rejects(scanPass(w.deps, 'p1', { code: 5 }), code('invalid_argument'));
  });
});

describe('scanPass attempt budget (final fix D-I3: 20 refusals per scanner per hour)', () => {
  const MIN = 60_000;

  test('the 21st refusal is limit_exceeded, and so is a real code until the window resets', async () => {
    const w = await world();
    for (let i = 0; i < SCAN_REFUSALS_PER_HOUR; i += 1) {
      // Unknown codes and someone else's pass both count.
      await assert.rejects(w.scan('p1', i % 2 === 0 ? 'ZZZZ2345' : P2), code(i % 2 === 0 ? 'not_found' : 'not_your_pass'));
    }
    await assert.rejects(w.scan('p1', 'ZZZZ2345'), code('limit_exceeded'));
    await assert.rejects(w.scan('p1', P1), code('limit_exceeded'));
    assert.equal(w.booking('b1').status, 'upcoming');
    // Another scanner keeps its own budget.
    await assert.rejects(w.scan('h1', 'ZZZZ2345'), code('not_found'));

    w.setNow(new Date(at('14:00').getTime() + 60 * MIN));
    assert.equal((await w.scan('p1', P1)).booking?.id, 'b1');
    assert.equal(w.booking('b1').status, 'shooting');
  });

  test('a successful or window-refused scan does not count; the window starts at the first refusal', async () => {
    const w = await world(at('13:00'));
    await assert.rejects(w.scan('p1', P1), code('too_early'));
    const store = w.deps.scans as unknown as { attempts: Map<string, ScanAttempts> };
    assert.equal(store.attempts.get('p1'), undefined);
    await assert.rejects(w.scan('p1', 'ZZZZ2345'), code('not_found'));
    assert.deepEqual(store.attempts.get('p1'), { uid: 'p1', windowStart: at('13:00').toISOString(), count: 1 });
    w.setNow(new Date(at('13:00').getTime() + 30 * MIN));
    await assert.rejects(w.scan('p1', 'ZZZZ2346'), code('not_found'));
    assert.equal(store.attempts.get('p1')?.count, 2);
    w.setNow(new Date(at('13:00').getTime() + 61 * MIN));
    await assert.rejects(w.scan('p1', 'ZZZZ2347'), code('not_found'));
    assert.deepEqual(store.attempts.get('p1'), { uid: 'p1', windowStart: new Date(at('13:00').getTime() + 61 * MIN).toISOString(), count: 1 });
  });

  test('a refusal is counted in the scan transaction itself, so parallel guesses cannot pass the check together', async () => {
    const w = await world();
    const scans = w.deps.scans;
    let txs = 0;
    const counted = { ...w.deps, scans: { runTransaction: <T>(fn: Parameters<typeof scans.runTransaction<T>>[0]) => { txs += 1; return scans.runTransaction(fn); } } };
    await assert.rejects(scanPass(counted, 'p1', { code: 'ZZZZ2345' }), code('not_found'));
    await assert.rejects(scanPass(counted, 'p1', { code: 'not a code' }), code('not_found'));
    assert.equal(txs, 2);
    const store = scans as unknown as { attempts: Map<string, ScanAttempts> };
    assert.equal(store.attempts.get('p1')?.count, 2);
    // A malformed code is refused with limit_exceeded too once the budget is spent.
    store.attempts.set('p1', { uid: 'p1', windowStart: at('14:00').toISOString(), count: SCAN_REFUSALS_PER_HOUR });
    await assert.rejects(scanPass(counted, 'p1', { code: 'not a code' }), code('limit_exceeded'));
  });

  test('scanBudgetSpent and afterRefusal', () => {
    const t0 = at('10:00');
    assert.equal(scanBudgetSpent(null, t0), false);
    const full: ScanAttempts = { uid: 'u', windowStart: t0.toISOString(), count: SCAN_REFUSALS_PER_HOUR };
    assert.equal(scanBudgetSpent({ ...full, count: SCAN_REFUSALS_PER_HOUR - 1 }, t0), false);
    assert.equal(scanBudgetSpent(full, new Date(t0.getTime() + 60 * MIN - 1)), true);
    assert.equal(scanBudgetSpent(full, new Date(t0.getTime() + 60 * MIN)), false);
    assert.deepEqual(afterRefusal(null, 'u', t0), { uid: 'u', windowStart: t0.toISOString(), count: 1 });
    assert.equal(afterRefusal({ ...full, count: 3 }, 'u', t0).count, 4);
  });
});

describe('scanPass at the gate', () => {
  test("the gate's scan (org1 or g1) checks r1 in and never touches a booking", async () => {
    const w = await world(at('09:00'));
    const r = await w.scan('g1', P2);
    assert.equal(r.booking, null);
    assert.deepEqual(r.registrations, [{ id: 'r1', eventTitle: 'Vé vào cửa Bãi đá', quantity: 2, kind: 'entry' }]);
    assert.equal(w.reg(ENTRY_ID, 'r1').checkedInAt?.getTime(), at('09:00').getTime());
    assert.equal(w.reg(ENTRY_ID, 'r1').gateCheckedInAt ?? null, null);

    const b2 = JSON.stringify(w.booking('b2'));
    const viaOrg = await w.scan('org1', P3);
    assert.equal(viaOrg.booking, null);
    assert.deepEqual(viaOrg.registrations.map((x) => x.id), ['r2']);
    assert.equal(JSON.stringify(w.booking('b2')), b2);
    assert.equal(w.be.booking.store.events.length, 0);
  });

  test('g2 is not_your_pass', async () => {
    const w = await world(at('09:00'));
    await assert.rejects(w.scan('g2', P2), code('not_your_pass'));
    assert.equal(w.reg(ENTRY_ID, 'r1').checkedInAt, null);
  });

  test('a removed gate staff is not_your_pass', async () => {
    const w = await world(at('09:00'));
    await assert.rejects(w.scan('g3', P2), code('not_your_pass'));
  });

  test('a refunded ticket is refunded', async () => {
    const w = await world(at('09:00'));
    await assert.rejects(w.scan('g1', P8), code('refunded'));
  });

  test('a ticket for tomorrow is wrong_day', async () => {
    const w = await world(at('09:00'));
    await assert.rejects(w.scan('g1', P7), (e: unknown) => code('wrong_day')(e) && (e as DomainError).details?.day === '2026-10-20');
  });

  test('a second gate scan of the same ticket is already_checked_in', async () => {
    const w = await world(at('09:00'));
    await w.scan('g1', P2);
    await assert.rejects(w.scan('org1', P2), code('already_checked_in'));
  });

  test("an entry-gate check-in increments entry_days.checkedIn and the gate staff's scansToday", async () => {
    const w = await world(at('09:00'));
    const first = await w.scan('g1', P2);
    assert.equal(day(w)?.checkedIn, 2);
    assert.equal(first.todayCount, 2);
    assert.deepEqual(staffRow(w, 'org1', 'g1')?.scansToday, { day: TODAY, count: 1 });
    await w.scan('g1', P3);
    assert.equal(day(w)?.checkedIn, 4);
    assert.deepEqual(staffRow(w, 'org1', 'g1')?.scansToday, { day: TODAY, count: 2 });
    // The organizer's own scans count on the day, not on a staff row.
    const g1 = staffRow(w, 'org1', 'g1');
    if (g1 === undefined) throw new Error('g1');
    w.organizers.seedGateStaff('org1', { ...g1, scansToday: { day: '2026-10-17', count: 9 } });
    await w.scan('org1', P5);
    assert.deepEqual(staffRow(w, 'org1', 'g1')?.scansToday, { day: '2026-10-17', count: 9 });
  });

  test('a booking pass whose provider ticket is waived is a gate success with the waived head count; the booking is untouched', async () => {
    const w = await world(at('09:00'));
    const before = JSON.stringify(w.booking('b4'));
    const r = await w.scan('g1', P5);
    assert.equal(r.booking, null);
    assert.deepEqual(r.registrations, []);
    assert.deepEqual(r.waived, { bookingId: 'b4', count: 1 });
    assert.equal(JSON.stringify(w.booking('b4')), before);
    assert.equal(day(w)?.checkedIn, 1);
    assert.deepEqual(staffRow(w, 'org1', 'g1')?.scansToday, { day: TODAY, count: 1 });
  });

  test('the waived part scans once: a rescan is already_checked_in and counts nobody again (fix 3)', async () => {
    const w = await world(at('09:00'));
    await w.scan('g1', P5);
    assert.equal(w.be.entry.store.passes.get(P5)?.waivedCheckedInAt, at('09:00').toISOString());
    w.setNow(at('09:30'));
    await assert.rejects(w.scan('org1', P5), (e: unknown) =>
      code('already_checked_in')(e) && (e as DomainError).details?.at === at('09:00').toISOString());
    assert.equal(day(w)?.checkedIn, 1);
    assert.deepEqual(staffRow(w, 'org1', 'g1')?.scansToday, { day: TODAY, count: 1 });
  });

  test('a waiver of the provider and two guests lets three people in', async () => {
    const w = await world(at('09:00'));
    const b4 = w.booking('b4');
    w.be.booking.store.bookings.set('b4', {
      ...b4, entry: { ...(b4.entry as NonNullable<typeof b4.entry>), waived: { provider: true, guests: true }, waivedGuests: 2 },
    });
    assert.deepEqual((await w.scan('g1', P5)).waived, { bookingId: 'b4', count: 3 });
    assert.equal(day(w)?.checkedIn, 3);
  });

  test('a pass with a waived provider and the customer\'s tickets lets both in at once', async () => {
    const w = await world(at('09:00'));
    const b2 = w.booking('b2');
    w.be.booking.store.bookings.set('b2', {
      ...b2, entry: { ...(b2.entry as NonNullable<typeof b2.entry>), waived: { provider: true, guests: false }, waivedGuests: 0 },
    });
    const r = await w.scan('g1', P3);
    assert.deepEqual(r.registrations.map((x) => x.id), ['r2']);
    assert.deepEqual(r.waived, { bookingId: 'b2', count: 1 });
    assert.equal(day(w)?.checkedIn, 3);
    assert.equal(r.todayCount, 3);
    assert.deepEqual(staffRow(w, 'org1', 'g1')?.scansToday, { day: TODAY, count: 1 });
    await assert.rejects(w.scan('g1', P3), code('already_checked_in'));
    assert.equal(day(w)?.checkedIn, 3);
  });

  test('a booking cancelled with keepTickets: the gate checks the tickets in, the waived part is ignored', async () => {
    const w = await world(at('09:00'));
    const b2 = w.booking('b2');
    w.be.booking.store.bookings.set('b2', {
      ...b2,
      status: 'cancelled',
      entry: { ...(b2.entry as NonNullable<typeof b2.entry>), waived: { provider: true, guests: false }, waivedGuests: 0 },
    });
    const r = await w.scan('g1', P3);
    assert.deepEqual(r.registrations.map((x) => x.id), ['r2']);
    assert.equal(r.waived, null);
    assert.equal(day(w)?.checkedIn, 2);
    assert.equal(w.reg(ENTRY_ID, 'r2').checkedInAt?.getTime(), at('09:00').getTime());
    assert.equal(w.be.entry.store.passes.get(P3)?.waivedCheckedInAt ?? null, null);
  });

  test('an entry ticket of a closed day, waiting for its refund, or of a cancelled entry event is refunded at the gate (fix 4)', async () => {
    const w = await world(at('09:00'));
    const row = day(w);
    if (row === undefined) throw new Error('day');
    w.be.entry.store.entryDays.set(`${ENTRY_ID}_${TODAY}`, { ...row, closed: true });
    await assert.rejects(w.scan('g1', P2), code('refunded'));
    w.be.entry.store.entryDays.set(`${ENTRY_ID}_${TODAY}`, row);

    w.be.entry.store.registrations.set(`${ENTRY_ID}/r1`, { ...w.reg(ENTRY_ID, 'r1'), refundDue: true });
    await assert.rejects(w.scan('g1', P2), code('refunded'));
    w.be.entry.store.registrations.set(`${ENTRY_ID}/r1`, { ...w.reg(ENTRY_ID, 'r1'), refundDue: false });

    const ev = w.be.entry.store.events.get(ENTRY_ID);
    if (ev === undefined) throw new Error('event');
    w.be.entry.store.events.set(ENTRY_ID, { ...ev, status: 'cancelled' });
    await assert.rejects(w.scan('g1', P2), code('refunded'));
    assert.equal(w.reg(ENTRY_ID, 'r1').checkedInAt, null);
    assert.equal(day(w)?.checkedIn, 0);
  });

  test('a booking pass without waivers or tickets is not_your_pass at the gate', async () => {
    const w = await world(at('09:00'));
    await assert.rejects(w.scan('g1', P1), code('not_your_pass'));
    await assert.rejects(w.scan('org1', P1), code('not_your_pass'));
    assert.equal(day(w)?.checkedIn, 0);
  });
});

describe('a pass with a booking and tickets (P3)', () => {
  test('P3 scanned by p1 changes b2 only; scanned by g1 changes r2 only; scanned by a stranger is not_your_pass', async () => {
    const w = await world();
    await assert.rejects(w.scan('x9', P3), code('not_your_pass'));
    const r2 = JSON.stringify(w.reg(ENTRY_ID, 'r2'));
    const byShooter = await w.scan('p1', P3);
    assert.deepEqual(byShooter.booking, { id: 'b2', customerName: 'Khách Hai' });
    assert.deepEqual(byShooter.registrations, []);
    assert.equal(w.booking('b2').status, 'shooting');
    assert.equal(JSON.stringify(w.reg(ENTRY_ID, 'r2')), r2);

    const b2 = JSON.stringify(w.booking('b2'));
    const byGate = await w.scan('g1', P3);
    assert.equal(byGate.booking, null);
    assert.deepEqual(byGate.registrations.map((x) => [x.id, x.kind]), [['r2', 'entry']]);
    assert.ok(w.reg(ENTRY_ID, 'r2').checkedInAt !== null);
    assert.equal(JSON.stringify(w.booking('b2')), b2);
  });
});

describe('event tickets (legacy codes through ticket_codes)', () => {
  test("h1 scanning e1's ticket between startAt − 2 h and endAt checks it in; before is too_early", async () => {
    const w = await world(at('13:59'));
    await assert.rejects(w.scan('h1', E1_TICKET), (e: unknown) =>
      code('too_early')(e) && (e as DomainError).details?.opensAt === at('14:00').toISOString());
    w.setNow(at('14:00'));
    const r = await w.scan('h1', E1_TICKET);
    assert.deepEqual(r.registrations, [{ id: 'r4', eventTitle: 'Sự kiện e1', quantity: 1, kind: 'event' }]);
    assert.equal(w.reg('e1', 'r4').checkedInAt?.getTime(), at('14:00').getTime());
    w.setNow(at('18:00'));
    await assert.rejects(w.scan('h1', E1_TICKET), code('already_checked_in'));
  });

  test("org1/g1 scanning e2's ticket sets gateCheckedInAt and not checkedInAt", async () => {
    const w = await world();
    const r = await w.scan('g1', E2_TICKET);
    assert.deepEqual(r.registrations, [{ id: 'r3', eventTitle: 'Sự kiện e2', quantity: 3, kind: 'venue_gate' }]);
    assert.equal(w.reg('e2', 'r3').gateCheckedInAt?.getTime(), at('14:00').getTime());
    assert.equal(w.reg('e2', 'r3').checkedInAt, null);
    await assert.rejects(w.scan('org1', E2_TICKET), code('already_checked_in'));
    // The event's own host still checks it in (another part).
    assert.equal((await w.scan('h2', E2_TICKET)).registrations[0]?.kind, 'event');
  });

  test('h1 scanning an entry ticket is not_your_pass', async () => {
    const w = await world(at('09:00'));
    await assert.rejects(w.scan('h1', P2), code('not_your_pass'));
  });

  test("an event manager of e2 scanning e1's ticket is not_your_pass", async () => {
    const w = await world();
    await assert.rejects(w.scan('h2', E1_TICKET), code('not_your_pass'));
  });

  test('scanPass with a legacy VE-XXXX-MMDD code resolves through ticket_codes', async () => {
    const w = await world();
    assert.equal((await w.scan('h1', ' ve-abcd-1018 ')).registrations[0]?.id, 'r4');
  });

  test('checkInRegistration({eventId, ticketCode}) still works for a legacy registration with a public ticketCode', async () => {
    const w = await world();
    const deps = w.be.entry.deps;
    const h1 = { uid: 'h1', staffRole: null };
    await assert.rejects(checkInRegistration(deps, h1, { eventId: 'e2', ticketCode: E1_TICKET }), code('permission_denied'));
    await assert.rejects(checkInRegistration(deps, { uid: 'h2', staffRole: null }, { eventId: 'e2', ticketCode: E1_TICKET }), code('not_found'));
    assert.deepEqual(await checkInRegistration(deps, h1, { eventId: 'e1', ticketCode: E1_TICKET.toLowerCase() }), { name: 'Nguyễn An', quantity: 1 });
    assert.equal(w.reg('e1', 'r4').checkedInAt?.getTime(), at('14:00').getTime());
    await assert.rejects(checkInRegistration(deps, h1, { eventId: 'e1', ticketCode: E1_TICKET }), code('conflict'));
  });

  test('checkInRegistration takes legacy ticket codes only: a pass code is not_found (no budget-free guessing)', async () => {
    const w = await world();
    const org1 = { uid: 'org1', staffRole: null };
    // Before: a real pass code answered permission_denied, an unknown one not_found (an oracle).
    await assert.rejects(checkInRegistration(w.be.entry.deps, org1, { eventId: ENTRY_ID, ticketCode: P2 }), code('not_found'));
    assert.equal(w.reg(ENTRY_ID, 'r1').checkedInAt ?? null, null);
  });
});

describe('scan privacy and the shooting status', () => {
  test('scan responses carry no phone (Review Focus 3)', async () => {
    const w = await world();
    w.be.booking.store.contacts.set('b1', { name: 'Khách Một', phone: '+84903123456', allowZalo: true, allowWhatsApp: false });
    const out = JSON.stringify([await w.scan('p1', P1), await w.scan('g1', E2_TICKET)]);
    assert.doesNotMatch(out, /\+84|phone/i);
  });

  test('resolveScan evaluates only the parts the scanner owns', () => {
    const b = { ...bookingFixture(), status: 'upcoming' as const };
    const scanner = { uid: 'p1', shooterOf: ['b1'], managerOf: [], gateOf: [], managesSpots: [] };
    const out = resolveScan([{ kind: 'booking', booking: b }], scanner, at('14:00'));
    assert.deepEqual(out.updates, [{ kind: 'booking_shooting', bookingId: 'b1' }]);
    assert.throws(() => resolveScan([{ kind: 'booking', booking: b }], { ...scanner, shooterOf: [] }, at('14:00')), code('not_your_pass'));
  });

  test('contact is unlocked while shooting', () => {
    assert.equal(bookingContactUnlocked({ status: 'shooting', completedAt: null }, at('14:00')), true);
  });

  test('openDispute is allowed while shooting', async () => {
    const d = createDisputeWorld();
    d.store.putSubject(bookingView({ state: 'shooting' }));
    d.store.payments.set('pay_b1', paidPayment());
    const dispute = await openDispute(d.deps, 'c1', openInput());
    assert.equal(dispute.amountHeld, 1_000_000);
    assert.equal(d.store.payments.get('pay_b1')?.escrowStatus, 'disputed');
  });

  test('a shooting booking at end + 24 h becomes shot by the sweep', async () => {
    const w = await world();
    await w.scan('p1', P1);
    w.setNow(new Date(at('17:30').getTime() + 24 * HOUR - 1));
    assert.equal((await runBookingSweeps(w.be.bookingDeps)).shootingShots, 0);
    w.setNow(new Date(at('17:30').getTime() + 24 * HOUR));
    assert.equal((await runBookingSweeps(w.be.bookingDeps)).shootingShots, 1);
    assert.equal(w.booking('b1').status, 'shot');
  });
});

function bookingFixture() {
  return {
    id: 'b1', customerId: 'c1', photographerId: 'p1', serviceId: 's', serviceSnapshot: { name: 'G', price: 1, durationMinutes: 60 },
    day: TODAY, start: '15:30', end: '17:30', place: { name: 'P' }, deposit: 1, remaining: 0, version: 1,
    createdAt: '2026-10-01T00:00:00.000Z', updatedAt: '2026-10-01T00:00:00.000Z', passCode4: '2345',
  };
}
