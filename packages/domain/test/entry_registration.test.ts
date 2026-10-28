import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError, type ErrorCode } from '../src/errors.js';
import { entryReleaseAt, type EntryDay } from '../src/entry_tickets.js';
import { parseVnDateTime } from '../src/booking_policy.js';
import { cancelRegistration } from '../src/event_registration.js';
import { cancelEventWithRefunds, closeEntryDay, releaseEventHolds, TicketPaymentSettler } from '../src/event_payments.js';
import { publishEvent, saveEventDraft, updateEvent } from '../src/event_use_cases.js';
import { FakeBlockGate } from '../src/fake_block_gate.js';
import { cu1, cu2, cu3, cuNoPhone, must, ph1, rawEvent } from './support/event_world.js';
import {
  ENTRY_ID, ENTRY_NOW, ENTRY_TODAY, HOUR, SPOT_COVER, VISIT, bought, buy, createEntryWorld, entryRaw, org1, org2, org3,
  publishedEntry, type EntryWorld,
} from './support/entry_world.js';

const code = (c: ErrorCode, field?: string) => (e: unknown) =>
  e instanceof DomainError && e.code === c && (field === undefined || e.field === field);
const ev = (w: EntryWorld) => must(w.store.events.get(ENTRY_ID));
const reg = (w: EntryWorld, id: string) => must(w.store.registrations.get(`${ENTRY_ID}/${id}`));
const day = (w: EntryWorld, d = VISIT) => w.store.entryDays.get(`${ENTRY_ID}_${d}`) ?? null;
const seedDay = (w: EntryWorld, over: Partial<EntryDay>, d = VISIT) => w.store.entryDays.set(`${ENTRY_ID}_${d}`, {
  eventId: ENTRY_ID, day: d, sold: 0, held: 0, checkedIn: 0, closed: false, updatedAt: ENTRY_NOW.toISOString(), ...over,
});
/** 00:00 of the visit day in Vietnam. */
const MIDNIGHT = parseVnDateTime(VISIT, '00:00').getTime();

describe('publishing entry events', () => {
  test('publishEvent type entry by the spot manager with canSell: status open, no availability write, entry fields stored', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    const e = ev(w);
    assert.equal(e.status, 'open');
    assert.equal(e.type, 'entry');
    assert.deepEqual(e.host, { type: 'organizer', id: 'org1', name: 'Bãi đá sông Hồng', avatarUrl: null, verified: true });
    assert.equal(w.store.availabilityDays.size, 0);
    assert.equal(e.spotId, 's1');
    assert.deepEqual(e.ticketTypes, [
      { id: 'adult', name: 'Người lớn', price: 70_000, hidden: false },
      { id: 'child', name: 'Trẻ em', price: 40_000, hidden: false },
    ]);
    assert.deepEqual([e.dailyCapacity, e.closedWeekdays, e.closedDays, e.openHours, e.refundCutoffHours],
      [10, [1], ['2026-10-25'], { start: '08:00', end: '17:00' }, 48]);
    // The sale range runs from 00:00 of the first day to the end of the last day (Vietnam).
    assert.equal(e.startAt?.toISOString(), parseVnDateTime(ENTRY_TODAY, '00:00').toISOString());
    assert.equal(e.endAt?.toISOString(), parseVnDateTime('2027-01-01', '00:00').toISOString());
    assert.equal(e.location?.name, 'Bãi đá sông Hồng');
    assert.deepEqual([e.location?.lat, e.location?.lng], [21.0285, 105.8542]);
    assert.deepEqual([e.coverUrl, e.coverPath], [SPOT_COVER.url, SPOT_COVER.path]);
    assert.deepEqual([e.dayKey, e.capacity, e.price, e.registrationDeadline, e.hashtag, e.hashtagLocked], [null, null, null, null, '', true]);
    assert.equal(w.store.hashtags.size, 0);
  });

  test('by an organizer who does not manage the spot → not_spot_manager', async () => {
    const w = createEntryWorld();
    await assert.rejects(saveEventDraft(w.deps, org2, entryRaw()), code('not_spot_manager'));
    // A draft whose spot changed hands before publishing.
    await saveEventDraft(w.deps, org1, entryRaw());
    w.store.spots.set('s1', { ...must(w.store.spots.get('s1')), managedBy: 'org2' });
    await assert.rejects(publishEvent(w.deps, org1, { eventId: ENTRY_ID }), code('not_spot_manager'));
    assert.equal(ev(w).status, 'draft');
  });

  test('without business → business_required', async () => {
    const w = createEntryWorld();
    await saveEventDraft(w.deps, org3, entryRaw({ spotId: 's2' }));
    await assert.rejects(publishEvent(w.deps, org3, { eventId: ENTRY_ID }), code('business_required'));
    assert.equal(ev(w).status, 'draft');
  });

  test('a photographer host with type entry → invalid_argument type', async () => {
    const w = createEntryWorld();
    await assert.rejects(saveEventDraft(w.deps, ph1, entryRaw()), code('invalid_argument', 'type'));
    // An existing photographer draft cannot become an entry event either.
    const { eventId } = await saveEventDraft(w.deps, ph1, rawEvent('ev1_aaaaaaaaaaaaaaaaaaaa'));
    await assert.rejects(saveEventDraft(w.deps, ph1, { eventId, type: 'entry' }), code('invalid_argument', 'type'));
  });

  test('publishEvent type entry creates no group chat', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    assert.equal(w.store.chats.size, 0);
    assert.equal(ev(w).chatId, null);
  });

  test('an invalid entry field is refused with its field', async () => {
    const w = createEntryWorld();
    await assert.rejects(saveEventDraft(w.deps, org1, entryRaw({ openHours: { start: '17:00', end: '08:00' } })), code('invalid_argument', 'openHours'));
    await assert.rejects(saveEventDraft(w.deps, org1, entryRaw({ spotId: 'nope_spot' })), code('not_found', 'spotId'));
  });
});

describe('updating entry events', () => {
  test('updateEvent cannot remove a ticket type that sold (invalid_argument ticketTypes); hiding it is fine; lowering dailyCapacity under a day\'s sold count → invalid_argument dailyCapacity with details.days', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    await bought(w, cu1, [{ ticketTypeId: 'adult', qty: 3 }]);
    await assert.rejects(updateEvent(w.deps, org1, { eventId: ENTRY_ID, ticketTypes: [{ id: 'child', name: 'Trẻ em', price: 40_000 }] }),
      code('invalid_argument', 'ticketTypes'));
    await updateEvent(w.deps, org1, {
      eventId: ENTRY_ID,
      ticketTypes: [{ id: 'adult', name: 'Người lớn', price: 80_000, hidden: true }, { id: 'child', name: 'Trẻ em', price: 40_000 }],
    });
    assert.deepEqual(ev(w).ticketTypes?.[0], { id: 'adult', name: 'Người lớn', price: 80_000, hidden: true });
    // A sold registration keeps the price it paid.
    const r = must([...w.store.registrations.values()].find((x) => x.userId === 'cu1'));
    assert.deepEqual(r.items, [{ ticketTypeId: 'adult', name: 'Người lớn', price: 70_000, qty: 3 }]);
    await assert.rejects(updateEvent(w.deps, org1, { eventId: ENTRY_ID, dailyCapacity: 2 }), (e: unknown) =>
      e instanceof DomainError && e.code === 'invalid_argument' && e.field === 'dailyCapacity'
      && JSON.stringify(e.details) === JSON.stringify({ days: [{ day: VISIT, sold: 3 }] }));
    await updateEvent(w.deps, org1, { eventId: ENTRY_ID, dailyCapacity: 3 });
    assert.equal(ev(w).dailyCapacity, 3);
  });

  test('closing a day that has tickets through an edit is refused (closeEntryDay refunds them)', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    await bought(w, cu1);
    await assert.rejects(updateEvent(w.deps, org1, { eventId: ENTRY_ID, closedDays: [VISIT] }), code('invalid_argument', 'closedDays'));
    await assert.rejects(updateEvent(w.deps, org1, { eventId: ENTRY_ID, spotId: 's2' }), code('invalid_argument', 'spotId'));
  });
});

describe('registerEntry', () => {
  test('registerEntry holds 3 tickets: registration held with visitDay, items, quantity 3, amount = Σ; entry_days held + 3; payment created with lineKind entry_ticket, payeeId org1, releaseAfter = entryReleaseAt(visitDay); ticketCodeLast4 set, private pass to be written on payment (Task 4)', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    const r = await buy(w, cu1, [{ ticketTypeId: 'adult', qty: 2 }, { ticketTypeId: 'child', qty: 1 }]);
    assert.equal(r.status, 'held');
    assert.notEqual(r.instructions, null);
    assert.equal(r.holdExpiresAt?.toISOString(), new Date(ENTRY_NOW.getTime() + 15 * 60_000).toISOString());
    const doc = reg(w, r.registrationId);
    assert.deepEqual([doc.visitDay, doc.quantity, doc.amount, doc.status, doc.bookingId, doc.gateCheckedInAt],
      [VISIT, 3, 180_000, 'held', null, null]);
    assert.deepEqual(doc.items, [
      { ticketTypeId: 'adult', name: 'Người lớn', price: 70_000, qty: 2 },
      { ticketTypeId: 'child', name: 'Trẻ em', price: 40_000, qty: 1 },
    ]);
    assert.match(doc.ticketCodeLast4 ?? '', /^[A-HJ-NP-Z2-9]{4}$/);
    assert.equal(doc.ticketCode.slice(3, 7), doc.ticketCodeLast4);
    assert.deepEqual([day(w)?.held, day(w)?.sold, day(w)?.closed], [3, 0, false]);
    const p = must(w.store.payments.get(must(r.paymentId)));
    assert.deepEqual([p.lineKind, p.payeeId, p.payeeKind, p.amount, p.subjectId, p.eventId],
      ['entry_ticket', 'org1', 'organizer', 180_000, r.registrationId, ENTRY_ID]);
    assert.equal(p.releaseAfter, entryReleaseAt(VISIT).toISOString());
    assert.deepEqual([ev(w).heldCount, ev(w).registeredCount, ev(w).status], [3, 0, 'open']);
  });

  test('paying moves entry_days held → sold', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    const id = await bought(w, cu1, [{ ticketTypeId: 'adult', qty: 2 }]);
    assert.equal(reg(w, id).status, 'paid');
    assert.deepEqual([day(w)?.held, day(w)?.sold], [0, 2]);
  });

  test('two concurrent registerEntry for the last seats: exactly one succeeds, the other is sold_out_day', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    seedDay(w, { sold: 8 });
    const out = await Promise.allSettled([
      buy(w, cu1, [{ ticketTypeId: 'adult', qty: 2 }]),
      buy(w, cu2, [{ ticketTypeId: 'adult', qty: 2 }]),
    ]);
    assert.equal(out.filter((x) => x.status === 'fulfilled').length, 1);
    const failed = out.find((x) => x.status === 'rejected');
    assert.ok(failed !== undefined && code('sold_out_day')(failed.reason));
    assert.deepEqual([day(w)?.sold, day(w)?.held], [8, 2]);
    assert.equal(w.store.registrationsOf(ENTRY_ID).length, 1);
    // The loser re-ran its transaction and saw the winner's entry_days row.
    assert.ok(w.store.retries >= 1);
  });

  test('a closed day is day_closed', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    seedDay(w, { closed: true });
    await assert.rejects(buy(w, cu1), code('day_closed'));
    assert.equal(w.store.registrationsOf(ENTRY_ID).length, 0);
  });

  test('a day outside the range or a closed weekday is day_closed', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    await assert.rejects(buy(w, cu1, undefined, '2026-10-19'), code('day_closed')); // Monday
    await assert.rejects(buy(w, cu1, undefined, '2026-10-25'), code('day_closed')); // closed day
    await assert.rejects(buy(w, cu1, undefined, '2027-01-01'), code('day_closed')); // after the range
    await assert.rejects(buy(w, cu1, undefined, '2026-10-17'), code('day_closed')); // yesterday
    w.clock.set(parseVnDateTime(ENTRY_TODAY, '17:00'));
    await assert.rejects(buy(w, cu1, undefined, ENTRY_TODAY), code('day_closed')); // today, after closing time
  });

  test('11 tickets limit_exceeded', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    await assert.rejects(buy(w, cu1, [{ ticketTypeId: 'adult', qty: 6 }, { ticketTypeId: 'child', qty: 5 }]), code('limit_exceeded'));
    await assert.rejects(buy(w, cu1, [{ ticketTypeId: 'adult', qty: 0 }]), code('invalid_argument'));
  });

  test('a hidden ticket type cannot be bought', async () => {
    const w = createEntryWorld();
    await publishedEntry(w, { ticketTypes: [{ id: 'adult', name: 'Người lớn', price: 70_000, hidden: true }, { id: 'child', name: 'Trẻ em', price: 40_000 }] });
    await assert.rejects(buy(w, cu1), code('invalid_argument', 'items'));
  });

  test('blocked customer ↔ organizer is blocked', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    (w.deps.blocks as FakeBlockGate).block('org1', 'cu1');
    await assert.rejects(buy(w, cu1), code('blocked'));
  });

  test('without a phone is phone_required', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    await assert.rejects(buy(w, cuNoPhone), code('phone_required'));
  });

  test('the organizer cannot buy its own tickets', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    await assert.rejects(buy(w, org1), code('permission_denied'));
  });

  test('a customer may hold tickets for two different visit days of one entry event; a second order for the same day while one is held is conflict', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    await buy(w, cu1, undefined, VISIT);
    await buy(w, cu1, undefined, '2026-10-23');
    assert.equal(w.store.registrationsOf(ENTRY_ID).filter((r) => r.userId === 'cu1').length, 2);
    await assert.rejects(buy(w, cu1, undefined, VISIT), code('conflict'));
  });

  test("a registration's event block carries the visit day's open/close hours and the spot's location", async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    const r = await buy(w, cu1);
    assert.deepEqual(reg(w, r.registrationId).event, {
      title: 'Vé vào cửa Bãi đá', type: 'entry',
      startAt: parseVnDateTime(VISIT, '08:00'), endAt: parseVnDateTime(VISIT, '17:00'),
      locationName: 'Bãi đá sông Hồng', lat: 21.0285, lng: 105.8542, coverUrl: SPOT_COVER.url,
    });
  });
});

describe('entry refunds, closing a day and holds', () => {
  test('cancelRegistration on an entry ticket 49 h before the day refunds 100%; 47 h before it is cancelled with refundPercent 0', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    const a = await bought(w, cu1, [{ ticketTypeId: 'adult', qty: 2 }]);
    const b = await bought(w, cu2);
    w.clock.set(new Date(MIDNIGHT - 49 * HOUR));
    assert.deepEqual(await cancelRegistration(w.deps, cu1, { eventId: ENTRY_ID, registrationId: a }), { status: 'refunded', refundPercent: 100 });
    assert.equal(reg(w, a).status, 'refunded');
    w.clock.set(new Date(MIDNIGHT - 47 * HOUR));
    assert.deepEqual(await cancelRegistration(w.deps, cu2, { eventId: ENTRY_ID, registrationId: b }), { status: 'cancelled', refundPercent: 0 });
    assert.equal(w.store.refundsOf(must(reg(w, b).paymentId)).length, 0);
    assert.deepEqual([day(w)?.sold, day(w)?.held], [0, 0]);
  });

  test('closeEntryDay refunds 100% every paid registration of that day, marks entry_days closed, notifies entry_day_closed, returns {refunded, left}', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    const a = await bought(w, cu1, [{ ticketTypeId: 'adult', qty: 2 }]);
    const b = await bought(w, cu2);
    const other = await bought(w, cu3, undefined, '2026-10-23');
    const out = await closeEntryDay({ ...w.deps, notify: w.notify.deps }, org1, { eventId: ENTRY_ID, day: VISIT });
    assert.deepEqual(out, { refunded: 2, left: 0 });
    for (const id of [a, b]) assert.deepEqual([reg(w, id).status, reg(w, id).refundPercent], ['refunded', 100]);
    assert.equal(reg(w, other).status, 'paid');
    assert.deepEqual([day(w)?.closed, day(w)?.sold], [true, 0]);
    assert.equal(day(w, '2026-10-23')?.closed, false);
    for (const uid of ['cu1', 'cu2']) {
      assert.deepEqual(w.notify.store.rowsOf(uid).map((r) => [r.type, r.target]), [['entry_day_closed', `/e/${ENTRY_ID}`]]);
    }
    assert.equal(w.notify.store.rowsOf('cu3').length, 0);
    await assert.rejects(buy(w, cu3), code('day_closed'));
    // A second close changes nothing.
    assert.deepEqual(await closeEntryDay(w.deps, org1, { eventId: ENTRY_ID, day: VISIT }), { refunded: 0, left: 0 });
  });

  test('closeEntryDay also refunds 100% a late-cancelled ticket of that day whose money is still held', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    const late = await bought(w, cu1);
    const other = await bought(w, cu2, undefined, '2026-10-23');
    // Past the 48 h cutoff (00:00 on the 20th): cancelled without a refund, the money stays held.
    w.clock.set(new Date(MIDNIGHT - 30 * HOUR));
    assert.deepEqual(await cancelRegistration(w.deps, cu1, { eventId: ENTRY_ID, registrationId: late }), { status: 'cancelled', refundPercent: 0 });
    const paymentId = must(reg(w, late).paymentId);
    assert.equal(must(w.store.payments.get(paymentId)).escrowStatus, 'held');

    const out = await closeEntryDay(w.deps, org1, { eventId: ENTRY_ID, day: VISIT });
    assert.deepEqual(out, { refunded: 1, left: 0 });
    assert.deepEqual([reg(w, late).status, reg(w, late).refundPercent], ['refunded', 100]);
    assert.equal(must(w.store.payments.get(paymentId)).status, 'refunded');
    assert.deepEqual(w.store.refundsOf(paymentId).map((r) => [r.amount, r.reason]), [[70_000, 'day_closed']]);
    // Another day's ticket keeps its money; the day's counters never go below zero.
    assert.equal(reg(w, other).status, 'paid');
    assert.deepEqual([day(w)?.sold, day(w)?.closed], [0, true]);
  });

  test('closeEntryDay refunds the first 20 at once and leaves the rest to the event clock', async () => {
    const w = createEntryWorld();
    await publishedEntry(w, { dailyCapacity: null });
    const first = await bought(w, cu1);
    const template = reg(w, first);
    const pay = must(w.store.payments.get(must(template.paymentId)));
    for (let i = 0; i < 21; i++) {
      const id = `rg_extra_${String(i).padStart(2, '0')}`;
      w.store.payments.set(`pay_${id}`, { ...pay, id: `pay_${id}`, subjectId: id, idempotencyKey: `k_${id}` });
      w.store.seedRegistration({ ...template, id, userId: `cx${i}`, paymentId: `pay_${id}`, ticketCode: `VE-X${String(i).padStart(3, '0')}-1022` });
    }
    const out = await closeEntryDay(w.deps, org1, { eventId: ENTRY_ID, day: VISIT });
    assert.deepEqual(out, { refunded: 20, left: 2 });
    const { runEventSweeps } = await import('../src/event_sweeps.js');
    const swept = await runEventSweeps(w.deps);
    assert.equal(swept.refunded, 2);
    assert.equal(w.store.registrationsOf(ENTRY_ID).filter((r) => r.status === 'paid').length, 0);
    assert.ok([...w.store.refunds.values()].every((r) => r.reason === 'day_closed'));
  });

  test('closeEntryDay by a stranger is permission_denied', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    await assert.rejects(closeEntryDay(w.deps, cu3, { eventId: ENTRY_ID, day: VISIT }), code('permission_denied'));
    await assert.rejects(closeEntryDay(w.deps, org2, { eventId: ENTRY_ID, day: VISIT }), code('permission_denied'));
    assert.equal(day(w), null);
  });

  test('a held registration whose payment expires releases entry_days.held', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    const r = await buy(w, cu1, [{ ticketTypeId: 'adult', qty: 3 }]);
    assert.equal(day(w)?.held, 3);
    w.clock.set(new Date(ENTRY_NOW.getTime() + 16 * 60_000));
    assert.equal(await new TicketPaymentSettler(w.deps).expire(must(r.paymentId), w.clock.now()), 'expired');
    assert.equal(await releaseEventHolds(w.deps), 1);
    assert.equal(reg(w, r.registrationId).status, 'cancelled');
    assert.deepEqual([day(w)?.held, day(w)?.sold, ev(w).heldCount], [0, 0, 0]);
  });

  test('a payment that lands after the day was closed is refunded, not sold', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    const r = await buy(w, cu1);
    await closeEntryDay(w.deps, org1, { eventId: ENTRY_ID, day: VISIT });
    assert.equal(((await w.payTicket(must(r.paymentId))) as { outcome: string }).outcome, 'refunded');
    assert.equal(reg(w, r.registrationId).status, 'cancelled');
    assert.deepEqual([day(w)?.held, day(w)?.sold], [0, 0]);
  });

  test('statusAfterSeats leaves an entry event open after paid, cancel, hold release and refund', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    const a = await bought(w, cu1);
    assert.equal(ev(w).status, 'open');
    await buy(w, cu2);
    w.clock.set(new Date(ENTRY_NOW.getTime() + 16 * 60_000));
    await releaseEventHolds(w.deps);
    assert.equal(ev(w).status, 'open');
    const b = await bought(w, cu3);
    await cancelRegistration(w.deps, cu1, { eventId: ENTRY_ID, registrationId: a }); // refund
    assert.equal(ev(w).status, 'open');
    w.clock.set(new Date(MIDNIGHT - 47 * HOUR));
    await cancelRegistration(w.deps, cu3, { eventId: ENTRY_ID, registrationId: b }); // no refund
    assert.deepEqual([ev(w).status, ev(w).registeredCount, ev(w).heldCount], ['open', 0, 0]);
  });

  test('cancelEvent on an entry event refunds only tickets with visitDay ≥ today and no checkedInAt', async () => {
    const w = createEntryWorld();
    await publishedEntry(w);
    const past = await bought(w, cu1, undefined, '2026-10-20');
    const future = await bought(w, cu2, undefined, VISIT);
    const used = await bought(w, cu3, undefined, VISIT);
    const held = await buy(w, cu1, undefined, VISIT);
    w.store.seedRegistration({ ...reg(w, used), checkedInAt: new Date(MIDNIGHT + 9 * HOUR) });
    w.clock.set(parseVnDateTime('2026-10-21', '10:00'));
    const out = await cancelEventWithRefunds(w.deps, org1, { eventId: ENTRY_ID });
    assert.deepEqual([out.paidRegistrationIds, out.refunded], [[future], 1]);
    assert.equal(reg(w, past).status, 'paid');
    assert.equal(reg(w, future).status, 'refunded');
    assert.equal(reg(w, used).status, 'paid');
    assert.equal(reg(w, held.registrationId).status, 'cancelled');
    assert.equal(ev(w).status, 'cancelled');
    assert.deepEqual([day(w)?.held, day(w)?.sold], [0, 1]);
  });
});
