import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError, type ErrorCode } from '../src/errors.js';
import { RetryableConflict } from '../src/event_ports.js';
import {
  cancelRegistration, cancellationRefundPercent, checkInRegistration, registerEvent,
} from '../src/event_registration.js';
import { registrationContactOf } from '../src/event.js';
import { cancelEvent } from '../src/event_use_cases.js';
import { ticketCodeCandidates } from '../src/ticket_code.js';
import {
  START, admin, sales1, cu1, cu2, cu3, cuNoPhone, createEventWorld, makeRandom, ph1, publishedEvent, register,
  registrationDoc, must, type EventWorld,
} from './support/event_world.js';

const code = (c: ErrorCode) => (e: unknown) => e instanceof DomainError && e.code === c;
const ev = (w: EventWorld) => must(w.store.events.get('ev1_aaaaaaaaaaaaaaaaaaaa'));
const setEvent = (w: EventWorld, over: Record<string, unknown>) => w.store.seedEvent({ ...ev(w), ...over });
const regId = (w: EventWorld, uid: string) => must(w.store.registrationsOf('ev1_aaaaaaaaaaaaaaaaaaaa').find((r) => r.userId === uid)).id;

describe('registerEvent', () => {
  test('phone_required without a valid phone, also for free events', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await assert.rejects(register(w, cuNoPhone, 'ev1_aaaaaaaaaaaaaaaaaaaa'), code('phone_required'));
    assert.equal(w.store.registrationsOf('ev1_aaaaaaaaaaaaaaaaaaaa').length, 0);
  });

  test('free registration is paid at once and counts seats', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    const r = await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa', 3);
    assert.equal(r.status, 'paid');
    assert.deepEqual([r.paymentId, r.payUrl, r.holdExpiresAt], [null, null, null]);
    const doc = w.store.registrations.get(`ev1_aaaaaaaaaaaaaaaaaaaa/${r.registrationId}`);
    assert.deepEqual([doc?.amount, doc?.quantity, doc?.userId, doc?.checkedInAt], [0, 3, 'cu1', null]);
    assert.match(doc?.ticketCode ?? '', /^VE-[A-HJ-NP-Z2-9]{4}-1004$/);
    assert.equal(doc?.event.title, 'Photo walk phố cổ');
    assert.equal(ev(w).registeredCount, 3);
    assert.equal(ev(w).heldCount, 0);
    assert.equal(ev(w).hashtagLocked, true);
    assert.deepEqual(w.store.ticketCodes.get(must(doc).ticketCode), { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', registrationId: r.registrationId });
  });

  test('a free registration does not unlock contact and stores no phone (O3)', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    const r = await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa');
    assert.equal(w.store.registrations.get(`ev1_aaaaaaaaaaaaaaaaaaaa/${r.registrationId}`)?.contactEligible, false);
    assert.equal(w.store.contacts.size, 0);
  });

  test('the contact snapshot of a paid ticket holds name, phone and channel flags', () => {
    assert.deepEqual(registrationContactOf('An', '+84912000001', { phone: '+84912000001', allowZalo: true } as never),
      { name: 'An', phone: '+84912000001', allowZalo: true, allowWhatsApp: false });
    assert.deepEqual(registrationContactOf('An', '+84912000001', null),
      { name: 'An', phone: '+84912000001', allowZalo: false, allowWhatsApp: false });
  });

  test('quantity 5 is limit_exceeded, 0 is invalid_argument', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await assert.rejects(register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa', 5), code('limit_exceeded'));
    await assert.rejects(register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa', 0), code('invalid_argument'));
    await assert.rejects(register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa', 1.5), code('invalid_argument'));
    await assert.rejects(registerEvent(w.deps, cu1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', quantity: 1, name: '' }), code('invalid_argument'));
    await assert.rejects(registerEvent(w.deps, cu1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', quantity: 1, name: 'a'.repeat(61) }), code('invalid_argument'));
  });

  test('more tickets than seats is sold_out', async () => {
    const w = createEventWorld();
    await publishedEvent(w, { capacity: 3 });
    await assert.rejects(register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa', 4), code('sold_out'));
    assert.equal(ev(w).registeredCount, 0);
  });

  test('the last seat makes the event full', async () => {
    const w = createEventWorld();
    await publishedEvent(w, { capacity: 3 });
    await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa', 2);
    assert.equal(ev(w).status, 'open');
    await register(w, cu2, 'ev1_aaaaaaaaaaaaaaaaaaaa', 1);
    assert.equal(ev(w).status, 'full');
    await assert.rejects(register(w, cu3, 'ev1_aaaaaaaaaaaaaaaaaaaa', 1), code('sold_out'));
  });

  test('a second tap returns the same registration', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    const a = await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa', 2);
    const writes = w.store.writes;
    const b = await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa', 2);
    assert.equal(b.registrationId, a.registrationId);
    assert.equal(w.store.writes, writes);
    assert.equal(ev(w).registeredCount, 2);
  });

  test('managers cannot register', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await assert.rejects(register(w, ph1, 'ev1_aaaaaaaaaaaaaaaaaaaa'), code('permission_denied'));
    await assert.rejects(register(w, admin, 'ev1_aaaaaaaaaaaaaaaaaaaa'), code('permission_denied'));
  });

  test('after the deadline is deadline_passed', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    w.clock.set(must(ev(w).registrationDeadline));
    await assert.rejects(register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa'), code('deadline_passed'));
    w.clock.set(new Date(must(ev(w).registrationDeadline).getTime() - 1));
    await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa');
  });

  test('draft or missing event is not_found', async () => {
    const w = createEventWorld();
    await assert.rejects(register(w, cu1, 'nope'), code('not_found'));
    w.store.seedEvent({ ...(await (async () => { await publishedEvent(w); return ev(w); })()), status: 'draft' });
    await assert.rejects(register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa'), code('not_found'));
  });

  test('paid events are not_eligible without a payment gateway (Decision 27)', async () => {
    const w = createEventWorld();
    await publishedEvent(w, { price: 150_000 });
    await assert.rejects(register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa'), code('not_eligible'));
    assert.equal(w.store.registrationsOf('ev1_aaaaaaaaaaaaaaaaaaaa').length, 0);
  });

  test('stale holds are released inside register', async () => {
    const w = createEventWorld();
    await publishedEvent(w, { capacity: 2, price: 100_000 });
    setEvent(w, { price: 0, heldCount: 2, status: 'full' });
    w.store.seedRegistration(registrationDoc({
      id: 'stale', eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', userId: 'cu9', quantity: 2, amount: 200_000, status: 'held',
      holdExpiresAt: new Date(w.clock.now().getTime() - 1000), ticketCode: 'VE-STAL-1004',
    }));
    const r = await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa', 2);
    assert.equal(r.status, 'paid');
    assert.equal(w.store.registrations.get('ev1_aaaaaaaaaaaaaaaaaaaa/stale')?.status, 'cancelled');
    assert.deepEqual([ev(w).heldCount, ev(w).registeredCount, ev(w).status], [0, 2, 'full']);
  });

  test('a live hold still blocks seats', async () => {
    const w = createEventWorld();
    await publishedEvent(w, { capacity: 2 });
    setEvent(w, { heldCount: 2, status: 'full' });
    w.store.seedRegistration(registrationDoc({
      id: 'live', eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', userId: 'cu9', quantity: 2, amount: 200_000, status: 'held',
      holdExpiresAt: new Date(w.clock.now().getTime() + 60_000), ticketCode: 'VE-LIVE-1004',
    }));
    await assert.rejects(register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa', 1), code('sold_out'));
    assert.equal(w.store.registrations.get('ev1_aaaaaaaaaaaaaaaaaaaa/live')?.status, 'held');
  });

  test('sold_out still releases stale holds', async () => {
    const w = createEventWorld();
    await publishedEvent(w, { capacity: 2 });
    setEvent(w, { registeredCount: 1, heldCount: 1, status: 'full' });
    w.store.seedRegistration(registrationDoc({ id: 'sold', eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', userId: 'cu8', ticketCode: 'VE-SOLD-1004' }));
    w.store.seedRegistration(registrationDoc({
      id: 'stale', eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', userId: 'cu9', amount: 100_000, status: 'held',
      holdExpiresAt: new Date(w.clock.now().getTime() - 1), ticketCode: 'VE-STAL-1004',
    }));
    await assert.rejects(register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa', 2), code('sold_out'));
    assert.equal(w.store.registrations.get('ev1_aaaaaaaaaaaaaaaaaaaa/stale')?.status, 'cancelled');
    assert.deepEqual([ev(w).heldCount, ev(w).registeredCount, ev(w).status], [0, 1, 'open']);
  });

  test('ticket code collisions pick another candidate', async () => {
    const w = createEventWorld(11);
    await publishedEvent(w);
    const peek = ticketCodeCandidates(new Date(START), makeRandom(11), 5);
    w.store.ticketCodes.set(must(peek[0]), { eventId: 'other', registrationId: 'x' });
    const r = await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa');
    assert.equal(w.store.registrations.get(`ev1_aaaaaaaaaaaaaaaaaaaa/${r.registrationId}`)?.ticketCode, peek[1]);
  });

  test('when every candidate is taken the transaction is retried with new ones', async () => {
    const w = createEventWorld(11);
    await publishedEvent(w);
    for (const c of ticketCodeCandidates(new Date(START), makeRandom(11), 5)) {
      w.store.ticketCodes.set(c, { eventId: 'other', registrationId: 'x' });
    }
    await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa');
    assert.equal(w.store.retries, 1);
    assert.equal(ev(w).registeredCount, 1);
  });

  test('retries stop after 5 attempts', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await assert.rejects(
      w.store.runTransaction(async () => { throw new RetryableConflict(); }),
      (e) => e instanceof RetryableConflict,
    );
    assert.equal(w.store.retries, 4);
  });

  test('concurrent registrations never oversell: 5 people, 2 seats, conflicts are retried', async () => {
    const w = createEventWorld();
    await publishedEvent(w, { capacity: 2 });
    const callers = ['cu1', 'cu2', 'cu3', 'cu4', 'cu5'].map((uid) => ({ uid, staffRole: null }));
    const results = await Promise.allSettled(callers.map((c) => register(w, c, 'ev1_aaaaaaaaaaaaaaaaaaaa', 1)));
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 2);
    const rejected = results.filter((r): r is PromiseRejectedResult => r.status === 'rejected');
    assert.equal(rejected.length, 3);
    assert.ok(rejected.every((f) => f.reason instanceof DomainError && f.reason.code === 'sold_out'));
    assert.equal(ev(w).registeredCount, 2);
    assert.ok(w.store.retries > 0);
  });

  test('the memory store refuses a read after a write', async () => {
    const w = createEventWorld();
    await assert.rejects(
      w.store.runTransaction(async (tx) => {
        tx.deleteHashtag('x');
        await tx.getEvent('ev1_aaaaaaaaaaaaaaaaaaaa');
      }),
      /read after write/,
    );
  });
});

describe('cancelRegistration', () => {
  test('cancel a free ticket frees seats and reopens a full event', async () => {
    const w = createEventWorld();
    await publishedEvent(w, { capacity: 2 });
    await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa', 2);
    assert.equal(ev(w).status, 'full');
    const r = await cancelRegistration(w.deps, cu1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', registrationId: regId(w, 'cu1') });
    assert.deepEqual(r, { status: 'cancelled', refundPercent: null });
    assert.deepEqual([ev(w).registeredCount, ev(w).status], [0, 'open']);
    assert.ok(w.store.registrations.get(`ev1_aaaaaaaaaaaaaaaaaaaa/${regId(w, 'cu1')}`)?.cancelledAt);
    // a cancelled attendee may register again
    await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa', 1);
    assert.equal(ev(w).registeredCount, 1);
  });

  test('cancelling again is idempotent', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa');
    const id = regId(w, 'cu1');
    await cancelRegistration(w.deps, cu1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', registrationId: id });
    const writes = w.store.writes;
    assert.equal((await cancelRegistration(w.deps, cu1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', registrationId: id })).status, 'cancelled');
    assert.equal(w.store.writes, writes);
  });

  test('cannot cancel after the start', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa');
    w.clock.set(new Date(START));
    await assert.rejects(
      cancelRegistration(w.deps, cu1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', registrationId: regId(w, 'cu1') }),
      code('not_eligible'),
    );
    assert.equal(ev(w).registeredCount, 1);
  });

  test('cannot cancel a checked-in ticket', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa');
    w.clock.set(new Date('2026-10-03T17:00:00.000Z')); // 00:00 on the event day in Vietnam
    const ticketCode = must(w.store.registrations.get(`ev1_aaaaaaaaaaaaaaaaaaaa/${regId(w, 'cu1')}`)).ticketCode;
    await checkInRegistration(w.deps, ph1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', ticketCode });
    await assert.rejects(
      cancelRegistration(w.deps, cu1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', registrationId: regId(w, 'cu1') }),
      code('conflict'),
    );
  });

  test('someone else\'s registration is permission_denied', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa');
    const id = regId(w, 'cu1');
    await assert.rejects(cancelRegistration(w.deps, cu2, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', registrationId: id }), code('permission_denied'));
    await assert.rejects(cancelRegistration(w.deps, ph1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', registrationId: id }), code('permission_denied'));
    await assert.rejects(cancelRegistration(w.deps, cu1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', registrationId: 'nope' }), code('not_found'));
  });

  test('a held ticket gives its held seats back', async () => {
    const w = createEventWorld();
    await publishedEvent(w, { capacity: 4 });
    setEvent(w, { heldCount: 2 });
    w.store.seedRegistration(registrationDoc({
      id: 'h1', eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', userId: 'cu1', quantity: 2, amount: 0, status: 'held',
      holdExpiresAt: new Date(w.clock.now().getTime() + 60_000), ticketCode: 'VE-HELD-1004',
    }));
    await cancelRegistration(w.deps, cu1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', registrationId: 'h1' });
    assert.deepEqual([ev(w).heldCount, ev(w).registeredCount], [0, 0]);
  });

  test('a paid ticket waits for the payment task', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    w.store.seedRegistration(registrationDoc({ id: 'pd', eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', userId: 'cu1', amount: 100_000, paymentId: 'pay1', contactEligible: true }));
    await assert.rejects(cancelRegistration(w.deps, cu1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', registrationId: 'pd' }), code('not_eligible'));
  });

  test('refund policy: 100% at 48 hours or more before the start, none after (O4)', () => {
    const start = new Date(START);
    const before = (h: number, extraMs = 0) => new Date(start.getTime() - h * 3_600_000 - extraMs);
    assert.equal(cancellationRefundPercent(start, before(48)), 100);
    assert.equal(cancellationRefundPercent(start, before(48, -1)), 0);
    assert.equal(cancellationRefundPercent(start, before(1)), 0);
    assert.equal(cancellationRefundPercent(start, before(120)), 100);
  });

  test('a cancelled event refuses a late attendee cancel', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa');
    const id = regId(w, 'cu1');
    await cancelEvent(w.deps, ph1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa' });
    assert.equal((await cancelRegistration(w.deps, cu1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', registrationId: id })).status, 'cancelled');
  });
});

describe('checkInRegistration', () => {
  const dayStart = new Date('2026-10-03T17:00:00.000Z');
  const ticketOf = (w: EventWorld, uid: string) => must(w.store.registrations.get(`ev1_aaaaaaaaaaaaaaaaaaaa/${regId(w, uid)}`)).ticketCode;

  test('check-in sets checkedInAt and returns name and quantity', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa', 2);
    w.clock.set(dayStart);
    const r = await checkInRegistration(w.deps, ph1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', ticketCode: ticketOf(w, 'cu1').toLowerCase() });
    assert.deepEqual(r, { name: 'Nguyễn An', quantity: 2 });
    assert.equal(w.store.registrations.get(`ev1_aaaaaaaaaaaaaaaaaaaa/${regId(w, 'cu1')}`)?.checkedInAt?.getTime(), dayStart.getTime());
    assert.equal(ev(w).registeredCount, 2); // counts never change
  });

  test('a second check-in is conflict', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa');
    w.clock.set(dayStart);
    const ticketCode = ticketOf(w, 'cu1');
    await checkInRegistration(w.deps, admin, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', ticketCode });
    await assert.rejects(checkInRegistration(w.deps, ph1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', ticketCode }), code('conflict'));
  });

  test('a code of another event is not_found', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await publishedEvent(w, {}, sales1, 'ev2_aaaaaaaaaaaaaaaaaaaa');
    await register(w, cu1, 'ev2_aaaaaaaaaaaaaaaaaaaa');
    const other = must(w.store.registrationsOf('ev2_aaaaaaaaaaaaaaaaaaaa')[0]).ticketCode;
    w.clock.set(dayStart);
    await assert.rejects(checkInRegistration(w.deps, ph1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', ticketCode: other }), code('not_found'));
    await assert.rejects(checkInRegistration(w.deps, ph1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', ticketCode: 'VE-ZZZZ-1004' }), code('not_found'));
    await assert.rejects(checkInRegistration(w.deps, ph1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', ticketCode: 'garbage' }), code('not_found'));
    await assert.rejects(checkInRegistration(w.deps, ph1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', ticketCode: 5 }), code('invalid_argument'));
  });

  test('a held ticket cannot check in', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    w.store.seedRegistration(registrationDoc({
      id: 'h1', eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', userId: 'cu1', amount: 100_000, status: 'held',
      holdExpiresAt: new Date(w.clock.now().getTime() + 60_000), ticketCode: 'VE-HELD-1004',
    }));
    w.clock.set(dayStart);
    await assert.rejects(checkInRegistration(w.deps, ph1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', ticketCode: 'VE-HELD-1004' }), code('not_found'));
  });

  test('check-in outside the window is not_eligible', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa');
    const ticketCode = ticketOf(w, 'cu1');
    w.clock.set(new Date(dayStart.getTime() - 1));
    await assert.rejects(checkInRegistration(w.deps, ph1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', ticketCode }), code('not_eligible'));
    // endAt + 2 h is the last moment
    w.clock.set(new Date(new Date('2026-10-04T05:00:00.000Z').getTime() + 2 * 3_600_000 + 1));
    await assert.rejects(checkInRegistration(w.deps, ph1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', ticketCode }), code('not_eligible'));
    w.clock.set(new Date(new Date('2026-10-04T05:00:00.000Z').getTime() + 2 * 3_600_000));
    await checkInRegistration(w.deps, ph1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', ticketCode });
  });

  test('a cancelled event cannot check in', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa');
    const ticketCode = ticketOf(w, 'cu1');
    await cancelEvent(w.deps, ph1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa' });
    w.clock.set(dayStart);
    await assert.rejects(checkInRegistration(w.deps, ph1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', ticketCode }), code('not_eligible'));
  });

  test('only managers check in', async () => {
    const w = createEventWorld();
    await publishedEvent(w);
    await register(w, cu1, 'ev1_aaaaaaaaaaaaaaaaaaaa');
    w.clock.set(dayStart);
    await assert.rejects(checkInRegistration(w.deps, cu1, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', ticketCode: ticketOf(w, 'cu1') }), code('permission_denied'));
    await assert.rejects(checkInRegistration(w.deps, cu2, { eventId: 'ev1_aaaaaaaaaaaaaaaaaaaa', ticketCode: ticketOf(w, 'cu1') }), code('permission_denied'));
  });
});
