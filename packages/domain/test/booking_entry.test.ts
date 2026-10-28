import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { bookingEntryDefaults } from '../src/booking_entry.js';
import { computeDeposit } from '../src/booking_policy.js';
import { bookingContactUnlocked } from '../src/contact.js';
import { DomainError, type ErrorCode } from '../src/errors.js';
import type { Payment } from '../src/escrow.js';
import { closeEntryDay } from '../src/event_payments.js';
import { runPaymentSweeps } from '../src/payment_sweeps.js';
import { runBookingSweeps } from '../src/booking_sweeps.js';
import { runEventSweeps } from '../src/event_sweeps.js';
import { transitionBooking } from '../src/transition_booking.js';
import { must } from './support/event_world.js';
import { org1 } from './support/entry_world.js';
import {
  ENTRY_ID, VISIT, childrenOf, createBookingEntryWorld, entryDraft, payEntry, paymentOf, residentOf, send, transfer,
  type BookingEntryWorld,
} from './support/booking_entry_world.js';

const code = (c: ErrorCode, field?: string) => (e: unknown) =>
  e instanceof DomainError && e.code === c && (field === undefined || e.field === field);
const DEPOSIT = computeDeposit(1_000_000).deposit;
const ADULT = 70_000;

const ev = (w: BookingEntryWorld) => must(w.entry.store.events.get(ENTRY_ID));
const reg = (w: BookingEntryWorld, id: string) => must(w.entry.store.registrations.get(`${ENTRY_ID}/${id}`));
const day = (w: BookingEntryWorld) => w.entry.store.entryDays.get(`${ENTRY_ID}_${VISIT}`);
const bookingOf = (w: BookingEntryWorld, id: string) => must(w.booking.store.bookings.get(id));

/** A booking with tickets paid in full; returns the ids. */
async function paidEntryBooking(w: BookingEntryWorld) {
  const draft = await entryDraft(w);
  const res = await payEntry(w, draft.id);
  const kids = childrenOf(w, res.paymentId);
  const bookingChild = kids.find((p) => p.lineKind === 'booking') as Payment;
  const ticketChild = kids.find((p) => p.lineKind === 'entry_ticket') as Payment;
  const total = DEPOSIT + 2 * ADULT;
  const out = await send(w, transfer(w, res.checkout.transferCode, total));
  assert.equal(out.outcome, 'paid');
  return { draft, res, groupId: res.paymentId, bookingChild, ticketChild, regId: ticketChild.subjectId, total };
}

describe('bookingEntryDefaults', () => {
  test('p3 → items = customer tickets + providerTicket true; p1 → providerTicket false and waived.provider true; waivesGuests with maxGuests 2 and 2 customer tickets → customer tickets waived; 3 customer tickets → only 2 waived', async () => {
    const w = await createBookingEntryWorld();
    const event = ev(w);
    const two = [{ ticketTypeId: 'adult', qty: 1 }, { ticketTypeId: 'child', qty: 1 }];

    const p3 = bookingEntryDefaults({ event, resident: null, customerItems: two, visitDay: VISIT });
    assert.deepEqual(p3.items.map((l) => [l.ticketTypeId, l.qty, l.price]), [['adult', 2, ADULT], ['child', 1, 40_000]]);
    assert.deepEqual([p3.providerTicket, p3.waived, p3.amount], [true, { provider: false, guests: false }, 2 * ADULT + 40_000]);

    const p1 = bookingEntryDefaults({
      event, resident: residentOf('p1', { waivesProvider: true }), customerItems: two, visitDay: VISIT,
    });
    assert.deepEqual(p1.items.map((l) => [l.ticketTypeId, l.qty]), [['adult', 1], ['child', 1]]);
    assert.deepEqual([p1.providerTicket, p1.waived], [false, { provider: true, guests: false }]);

    const guests = residentOf('p1', { waivesProvider: true, waivesGuests: true, maxGuests: 2 });
    const allWaived = bookingEntryDefaults({ event, resident: guests, customerItems: two, visitDay: VISIT });
    assert.deepEqual([allWaived.items, allWaived.amount, allWaived.waived], [[], 0, { provider: true, guests: true }]);

    const three = bookingEntryDefaults({
      event, resident: guests, customerItems: [{ ticketTypeId: 'adult', qty: 3 }], visitDay: VISIT,
    });
    assert.deepEqual(three.items.map((l) => [l.ticketTypeId, l.qty]), [['adult', 1]]);
    assert.equal(three.amount, ADULT);

    // A residency that ends before the visit day waives nothing, even while it is still valid today.
    const endsBefore = bookingEntryDefaults({
      event, resident: residentOf('p1', { waivesProvider: true, validUntil: '2026-10-20' }), customerItems: two, visitDay: VISIT,
    });
    assert.deepEqual([endsBefore.providerTicket, endsBefore.waived.provider], [true, false]);
    // One valid through the visit day does.
    const endsThatDay = bookingEntryDefaults({
      event, resident: residentOf('p1', { waivesProvider: true, validUntil: VISIT }), customerItems: two, visitDay: VISIT,
    });
    assert.deepEqual([endsThatDay.providerTicket, endsThatDay.waived.provider], [false, true]);
  });
});

describe('createBooking with entry', () => {
  test('stores Booking.entry from the defaults', async () => {
    const w = await createBookingEntryWorld();
    const p3 = await entryDraft(w);
    assert.deepEqual(
      [p3.entry?.eventId, p3.entry?.visitDay, p3.entry?.providerTicket, p3.entry?.amount, p3.entry?.registrationId],
      [ENTRY_ID, VISIT, true, 2 * ADULT, null],
    );
    const p1 = await entryDraft(w, { photographerId: 'p1', serviceId: 'srv_01', customerId: 'c2' });
    assert.deepEqual([p1.entry?.providerTicket, p1.entry?.waived.provider, p1.entry?.amount], [false, true, ADULT]);
  });

  test('a residency ending before the visit day gives no waiver on the draft', async () => {
    const w = await createBookingEntryWorld();
    w.entry.store.residents.set('s1/p1', residentOf('p1', { waivesProvider: true, validUntil: '2026-10-20' }));
    const draft = await entryDraft(w, { photographerId: 'p1', serviceId: 'srv_01' });
    assert.deepEqual([draft.entry?.providerTicket, draft.entry?.waived.provider, draft.entry?.amount], [true, false, 2 * ADULT]);
  });

  test('createBooking with entry on a spot without an entry event → invalid_argument entry; on a closed day → day_closed; qty over 10 → limit_exceeded', async () => {
    const w = await createBookingEntryWorld();
    await assert.rejects(entryDraft(w, {}, { eventId: 'nope_aaaaaaaaaaaaaaaaaaaa' }), code('invalid_argument', 'entry'));
    // The visit day must be the booking's day.
    await assert.rejects(entryDraft(w, {}, { visitDay: '2026-10-23' }), code('invalid_argument', 'entry'));
    // 2026-10-25 is a closed day; a Monday is a closed weekday; a day the organizer closed.
    await assert.rejects(entryDraft(w, { day: '2026-10-25' }, { visitDay: '2026-10-25' }), code('day_closed'));
    await assert.rejects(entryDraft(w, { day: '2026-10-26' }, { visitDay: '2026-10-26' }), code('day_closed'));
    w.entry.store.entryDays.set(`${ENTRY_ID}_${VISIT}`, {
      eventId: ENTRY_ID, day: VISIT, sold: 0, held: 0, checkedIn: 0, closed: true, updatedAt: '2026-10-18T03:00:00.000Z',
    });
    await assert.rejects(entryDraft(w), code('day_closed'));
    w.entry.store.entryDays.delete(`${ENTRY_ID}_${VISIT}`);
    await assert.rejects(entryDraft(w, {}, { items: [{ ticketTypeId: 'adult', qty: 10 }] }), code('limit_exceeded'));
    assert.equal(w.booking.store.bookings.size, 0);
  });
});

describe('paying a booking with tickets', () => {
  test('createPayment on a booking with entry creates the registration held, a group payment and two children (booking; entry_ticket with payee org1 and payeeKind organizer), the payment_groups view with 2 lines and total = Σ, and returns the group\'s instructions', async () => {
    const w = await createBookingEntryWorld();
    const draft = await entryDraft(w);
    const res = await payEntry(w, draft.id);
    const group = must(paymentOf(w, res.paymentId));
    assert.deepEqual([group.subjectType, group.amount, group.status], ['payment_group', DEPOSIT + 2 * ADULT, 'created']);
    assert.deepEqual([res.checkout.paymentId, res.checkout.amount, res.checkout.transferCode], [group.id, group.amount, group.transferCode]);
    assert.equal(res.groupId, group.id);
    assert.equal(res.lines?.length, 2);

    const kids = childrenOf(w, group.id);
    const b = must(kids.find((p) => p.lineKind === 'booking'));
    const t = must(kids.find((p) => p.lineKind === 'entry_ticket'));
    assert.deepEqual([b.subjectType, b.subjectId, b.payeeId, b.amount, b.status], ['booking', draft.id, 'p3', DEPOSIT, 'awaiting_group']);
    assert.deepEqual(
      [t.subjectType, t.eventId, t.payeeId, t.payeeKind, t.amount, t.status],
      ['event_registration', ENTRY_ID, 'org1', 'organizer', 2 * ADULT, 'awaiting_group'],
    );

    const r = reg(w, t.subjectId);
    assert.deepEqual([r.status, r.bookingId, r.visitDay, r.quantity, r.amount, r.paymentId], ['held', draft.id, VISIT, 2, 2 * ADULT, t.id]);
    assert.equal(r.holdExpiresAt?.toISOString(), group.expiresAt);
    assert.deepEqual([day(w)?.held, ev(w).heldCount], [2, 2]);

    const view = must(w.booking.store.paymentGroups.get(group.id));
    assert.deepEqual([view.payerId, view.lines.length, view.total, view.status], ['c1', 2, b.amount + t.amount, 'created']);
    assert.deepEqual(view.lines.map((l) => [l.paymentId, l.kind, l.payeeId]).sort(), [[b.id, 'booking', 'p3'], [t.id, 'entry_ticket', 'org1']].sort());

    const booking = bookingOf(w, draft.id);
    assert.deepEqual([booking.groupId, booking.entry?.registrationId], [group.id, r.id]);
  });

  test('a booking whose tickets are all waived pays one direct payment, no group', async () => {
    const w = await createBookingEntryWorld();
    w.entry.store.residents.set('s1/p1', residentOf('p1', { waivesProvider: true, waivesGuests: true, maxGuests: 2 }));
    const draft = await entryDraft(w, { photographerId: 'p1', serviceId: 'srv_01' });
    const res = await payEntry(w, draft.id);
    assert.equal(must(paymentOf(w, res.paymentId)).subjectType, 'booking');
    assert.equal(res.groupId, undefined);
    assert.equal(w.entry.store.registrations.size, 0);
  });

  test('a transfer of exactly the total pays both lines, marks the group paid, registration paid, booking depositPaidAt set and contact unlocked; milestones split later at shot on the booking child only', async () => {
    const w = await createBookingEntryWorld();
    const { draft, groupId, bookingChild, ticketChild, regId } = await paidEntryBooking(w);
    assert.equal(must(paymentOf(w, groupId)).status, 'paid');
    assert.equal(must(paymentOf(w, bookingChild.id)).status, 'paid');
    assert.equal(must(paymentOf(w, ticketChild.id)).status, 'paid');
    const r = reg(w, regId);
    assert.deepEqual([r.status, r.contactEligible], ['paid', true]);
    assert.deepEqual([day(w)?.held, day(w)?.sold, ev(w).heldCount, ev(w).registeredCount], [0, 2, 0, 2]);
    const b = bookingOf(w, draft.id);
    assert.equal(b.status, 'requested');
    assert.ok(b.depositPaidAt);
    assert.ok(bookingContactUnlocked({ status: b.status, completedAt: null }, w.booking.clock.now()));
    assert.ok(w.booking.store.contacts.get(draft.id));

    await transitionBooking(w.bookingDeps, { bookingId: draft.id, action: 'accept', actorId: 'p3' });
    w.booking.clock.setTime(new Date('2026-10-22T05:00:00.000Z')); // 12:00 in Vietnam, after the 11:00 end
    const shot = await transitionBooking(w.bookingDeps, { bookingId: draft.id, action: 'mark_shot', actorId: 'p3' });
    assert.equal(shot.status, 'shot');
    assert.equal(must(paymentOf(w, bookingChild.id)).milestones?.length, 2);
    assert.equal(must(paymentOf(w, ticketChild.id)).milestones, undefined);
  });

  test('a transfer below the total is partial and nothing is paid', async () => {
    const w = await createBookingEntryWorld();
    const draft = await entryDraft(w);
    const res = await payEntry(w, draft.id);
    const out = await send(w, transfer(w, res.checkout.transferCode, DEPOSIT + 2 * ADULT - 10_000));
    assert.equal(out.outcome, 'partial');
    for (const k of childrenOf(w, res.paymentId)) assert.equal(k.status, 'awaiting_group');
    assert.equal(bookingOf(w, draft.id).status, 'draft');
    const t = must(childrenOf(w, res.paymentId).find((p) => p.lineKind === 'entry_ticket'));
    assert.equal(reg(w, t.subjectId).status, 'held');
    assert.equal(day(w)?.sold, 0);
  });

  test('an expired group expires both children and releases the held registration and entry_days.held', async () => {
    const w = await createBookingEntryWorld();
    const draft = await entryDraft(w);
    const res = await payEntry(w, draft.id);
    w.booking.clock.advanceMinutes(16);
    await runPaymentSweeps(w.settlement);
    const kids = childrenOf(w, res.paymentId);
    assert.deepEqual(kids.map((k) => k.status), ['expired', 'expired']);
    const t = must(kids.find((p) => p.lineKind === 'entry_ticket'));
    assert.equal(reg(w, t.subjectId).status, 'cancelled');
    assert.deepEqual([day(w)?.held, ev(w).heldCount], [0, 0]);
    // The draft keeps its day: a new QR builds a new group and holds the tickets again.
    const again = await payEntry(w, draft.id);
    assert.notEqual(again.paymentId, res.paymentId);
    assert.equal(day(w)?.held, 2);
  });

  test('a second QR replaces the open group: the old children expire and the old hold is released', async () => {
    const w = await createBookingEntryWorld();
    const draft = await entryDraft(w);
    const first = await payEntry(w, draft.id);
    const second = await payEntry(w, draft.id);
    assert.equal(must(paymentOf(w, first.paymentId)).status, 'expired');
    for (const k of childrenOf(w, first.paymentId)) assert.equal(k.status, 'expired');
    assert.deepEqual([day(w)?.held, ev(w).heldCount], [2, 2]);
    const held = [...w.entry.store.registrations.values()].filter((r) => r.status === 'held');
    assert.equal(held.length, 1);
    assert.equal(bookingOf(w, draft.id).groupId, second.paymentId);
  });
});

describe('cancelling a booking with tickets', () => {
  test('provider decline refunds both lines 100%', async () => {
    const w = await createBookingEntryWorld();
    const { draft, bookingChild, ticketChild, regId } = await paidEntryBooking(w);
    await transitionBooking(w.bookingDeps, { bookingId: draft.id, action: 'decline', actorId: 'p3', reason: 'Bận' });
    assert.equal(bookingOf(w, draft.id).status, 'declined');
    assert.equal(must(paymentOf(w, bookingChild.id)).status, 'refunded');
    assert.equal(must(paymentOf(w, ticketChild.id)).status, 'refunded');
    const r = reg(w, regId);
    assert.deepEqual([r.status, r.refundPercent], ['refunded', 100]);
    assert.equal(must(w.entry.store.refunds.get(must(r.refundId))).reason, 'provider_cancelled');
    assert.deepEqual([day(w)?.sold, ev(w).registeredCount], [0, 0]);
  });

  test('customer cancel with keepTickets keeps the registration paid', async () => {
    const w = await createBookingEntryWorld();
    const { draft, bookingChild, ticketChild, regId } = await paidEntryBooking(w);
    await transitionBooking(w.bookingDeps, { bookingId: draft.id, action: 'cancel', actorId: 'c1', keepTickets: true });
    assert.equal(bookingOf(w, draft.id).status, 'cancelled');
    assert.equal(must(paymentOf(w, bookingChild.id)).status, 'refunded');
    assert.deepEqual([must(paymentOf(w, ticketChild.id)).status, must(paymentOf(w, ticketChild.id)).escrowStatus], ['paid', 'held']);
    assert.equal(reg(w, regId).status, 'paid');
    assert.equal(day(w)?.sold, 2);
  });

  test('customer cancel without keepTickets: the tickets follow the entry rule (100% before the cutoff)', async () => {
    const w = await createBookingEntryWorld();
    const { draft, ticketChild, regId } = await paidEntryBooking(w);
    await transitionBooking(w.bookingDeps, { bookingId: draft.id, action: 'cancel', actorId: 'c1' });
    assert.equal(must(paymentOf(w, ticketChild.id)).status, 'refunded');
    assert.deepEqual([reg(w, regId).status, reg(w, regId).refundPercent], ['refunded', 100]);
    assert.equal(day(w)?.sold, 0);
  });

  test('customer cancel after the entry cutoff: the ticket is cancelled, its money stays held, sold goes back', async () => {
    const w = await createBookingEntryWorld();
    const { draft, bookingChild, ticketChild, regId } = await paidEntryBooking(w);
    w.booking.clock.setTime(new Date('2026-10-20T03:00:00.000Z')); // past the cutoff (00:00 on the 20th), 47 h before the start
    await transitionBooking(w.bookingDeps, { bookingId: draft.id, action: 'cancel', actorId: 'c1' });
    assert.equal(bookingOf(w, draft.id).status, 'cancelled');
    assert.equal(must(paymentOf(w, bookingChild.id)).status, 'partially_refunded'); // 50% of the booking
    const r = reg(w, regId);
    assert.deepEqual([r.status, r.refundPercent, r.refundDue, r.bookingLineDue], ['cancelled', 0, false, null]);
    const t = must(paymentOf(w, ticketChild.id));
    assert.deepEqual([t.status, t.escrowStatus, t.refundedAmount ?? 0], ['paid', 'held', 0]);
    assert.equal(w.entry.store.refundsOf(t.id).length, 0);
    assert.deepEqual([day(w)?.sold, ev(w).registeredCount], [0, 0]);
  });

  test('a ticket refund that fails after a decline stays stamped on the registration and the event clock refunds it', async () => {
    const w = await createBookingEntryWorld();
    const { draft, bookingChild, ticketChild, regId } = await paidEntryBooking(w);
    w.entry.store.failNext = { error: new Error('outage'), times: 1 };
    await transitionBooking(w.bookingDeps, { bookingId: draft.id, action: 'decline', actorId: 'p3', reason: 'Bận' });
    assert.equal(bookingOf(w, draft.id).status, 'declined');
    assert.equal(must(paymentOf(w, bookingChild.id)).status, 'refunded');
    const stamped = reg(w, regId);
    assert.deepEqual([stamped.status, stamped.refundDue, stamped.bookingLineDue], ['paid', true, { percent: 100, reason: 'provider_cancelled' }]);
    assert.equal(must(paymentOf(w, ticketChild.id)).status, 'paid');

    const swept = await runEventSweeps(w.eventDeps);
    assert.equal(swept.refunded, 1);
    const r = reg(w, regId);
    assert.deepEqual([r.status, r.refundPercent, r.refundDue, r.bookingLineDue], ['refunded', 100, false, null]);
    assert.equal(must(paymentOf(w, ticketChild.id)).status, 'refunded');
    assert.deepEqual(w.entry.store.refundsOf(ticketChild.id).map((x) => x.reason), ['provider_cancelled']);
    assert.deepEqual([day(w)?.sold, ev(w).registeredCount], [0, 0]);
    // A second run changes nothing.
    assert.equal((await runEventSweeps(w.eventDeps)).refunded, 0);
  });

  test('a request that expires in the booking sweep without the ticket port is stamped, and the event clock refunds the ticket', async () => {
    const w = await createBookingEntryWorld();
    const { draft, ticketChild, regId } = await paidEntryBooking(w);
    const { tickets: _ignored, ...withoutPort } = w.bookingDeps;
    void _ignored;
    w.booking.clock.advanceHours(25); // past the 24 h accept deadline
    const swept = await runBookingSweeps(withoutPort);
    assert.equal(swept.expiredRequests, 1);
    assert.equal(bookingOf(w, draft.id).status, 'expired');
    assert.deepEqual(reg(w, regId).bookingLineDue, { percent: 100, reason: 'provider_cancelled' });
    assert.equal((await runEventSweeps(w.eventDeps)).refunded, 1);
    assert.equal(reg(w, regId).status, 'refunded');
    assert.equal(must(paymentOf(w, ticketChild.id)).status, 'refunded');
  });

  test('closeEntryDay on the booking\'s day refunds the ticket line and leaves the booking upcoming', async () => {
    const w = await createBookingEntryWorld();
    const { draft, bookingChild, ticketChild, regId } = await paidEntryBooking(w);
    await transitionBooking(w.bookingDeps, { bookingId: draft.id, action: 'accept', actorId: 'p3' });
    w.booking.clock.setTime(new Date('2026-10-21T03:00:00.000Z')); // 23 h before the 09:00 start
    await transitionBooking(w.bookingDeps, { bookingId: draft.id, action: 'upcoming' });
    assert.equal(bookingOf(w, draft.id).status, 'upcoming');

    const out = await closeEntryDay(w.eventDeps, org1, { eventId: ENTRY_ID, day: VISIT });
    assert.deepEqual(out, { refunded: 1, left: 0 });
    assert.deepEqual([reg(w, regId).status, reg(w, regId).refundPercent], ['refunded', 100]);
    assert.equal(must(paymentOf(w, ticketChild.id)).status, 'refunded');
    assert.equal(bookingOf(w, draft.id).status, 'upcoming');
    assert.deepEqual([must(paymentOf(w, bookingChild.id)).status, must(paymentOf(w, bookingChild.id)).escrowStatus], ['paid', 'held']);
  });
});
