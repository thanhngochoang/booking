import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { computeDeposit } from '../src/booking_policy.js';
import { DomainError } from '../src/errors.js';
import { verifyPaymentLedgerInvariant, type Payment } from '../src/escrow.js';
import { entryReleaseAt } from '../src/entry_tickets.js';
import {
  assertLinesSum,
  newChildPayment,
  newGroupPayment,
  refundPlan,
  type GroupLine,
} from '../src/group_settlement.js';
import { transferCodeFor } from '../src/payment_code.js';
import { EMPTY_PAYER_SUBJECT, confirmFakePayment, payerRowOf, runPaymentSweeps } from '../src/index.js';
import { createPayout, createPayouts } from '../src/payout_use_cases.js';
import { DEFAULT_PAYOUT_POLICY, payoutLineOf, taxRateBpOf } from '../src/payout_policy.js';
import {
  ENTRY_ID, VISIT, childrenOf, createBookingEntryWorld, entryDraft, payEntry, paymentOf, send, transfer,
  type BookingEntryWorld,
} from './support/booking_entry_world.js';
import { ADMIN, addAccount, createPayoutWorld, paidBooking, release } from './support/payout_world.js';

const NOW = new Date('2026-10-18T03:00:00.000Z');
const LATER = new Date(NOW.getTime() + 15 * 60_000);
const DEPOSIT = computeDeposit(1_000_000).deposit;
/** One adult for the customer and one for p3 (not a resident). */
const TICKETS = 2 * 70_000;
const TOTAL = DEPOSIT + TICKETS;

const lines = (over: Partial<Record<'booking' | 'entry', Partial<GroupLine>>> = {}): GroupLine[] => [
  { paymentId: 'pb', kind: 'booking', subjectType: 'booking', subjectId: 'b1', payeeId: 'p3', amount: DEPOSIT, ...over.booking },
  { paymentId: 'pt', kind: 'entry_ticket', subjectType: 'event_registration', subjectId: 'r1', payeeId: 'org1', amount: TICKETS, ...over.entry },
];

/** A booking with tickets whose group payment is open; returns the ids. */
async function openGroup(w: BookingEntryWorld) {
  const draft = await entryDraft(w);
  const res = await payEntry(w, draft.id);
  const groupId = res.paymentId;
  const kids = childrenOf(w, groupId);
  const bookingChild = kids.find((p) => p.lineKind === 'booking') as Payment;
  const ticketChild = kids.find((p) => p.lineKind === 'entry_ticket') as Payment;
  return { draft, res, groupId, bookingChild, ticketChild, code: res.checkout.transferCode };
}

const reg = (w: BookingEntryWorld, id: string) => w.entry.store.registrations.get(`${ENTRY_ID}/${id}`);
const day = (w: BookingEntryWorld) => w.entry.store.entryDays.get(`${ENTRY_ID}_${VISIT}`);

function ledgerHolds(w: BookingEntryWorld, p: Payment): boolean {
  const refunds = [...w.booking.store.refunds.values(), ...w.entry.store.refunds.values()].filter((r) => r.paymentId === p.id);
  const entries = [...w.booking.store.ledgerEntries.values(), ...w.entry.store.ledger].filter((e) => e.paymentId === p.id);
  return verifyPaymentLedgerInvariant(p, refunds, entries);
}

describe('group payments (pure)', () => {
  test('newGroupPayment has subjectType payment_group, its own transfer code and amount = Σ lines', () => {
    const g = newGroupPayment({
      id: 'g1', payerId: 'c1', total: TOTAL, method: 'bank_qr', provider: 'fake', idempotencyKey: 'pay_b1_1', now: NOW, expiresAt: LATER,
    });
    assert.deepEqual(
      [g.subjectType, g.subjectId, g.payerId, g.payeeId, g.amount, g.status, g.transferCode, g.expiresAt],
      ['payment_group', 'g1', 'c1', 'c1', TOTAL, 'created', transferCodeFor('g1'), LATER.toISOString()],
    );
    assert.equal(g.amount, lines().reduce((s, l) => s + l.amount, 0));
  });

  test('children are awaiting_group with no transfer code', () => {
    const [b, t] = lines();
    const kids = [b, t].map((l) => newChildPayment({
      id: (l as GroupLine).paymentId, groupId: 'g1', line: l as GroupLine, payerId: 'c1', method: 'bank_qr', provider: 'fake',
      ...((l as GroupLine).kind === 'entry_ticket' ? { payeeKind: 'organizer' as const, eventId: ENTRY_ID } : {}),
      now: NOW, expiresAt: LATER,
    }));
    for (const k of kids) {
      assert.equal(k.status, 'awaiting_group');
      assert.equal(k.transferCode, undefined);
      assert.equal(k.groupId, 'g1');
    }
    assert.deepEqual([kids[0]?.lineKind, kids[0]?.subjectType, kids[0]?.payeeId], ['booking', 'booking', 'p3']);
    assert.deepEqual([kids[1]?.lineKind, kids[1]?.payeeKind, kids[1]?.eventId], ['entry_ticket', 'organizer', ENTRY_ID]);
  });

  test('assertLinesSum throws on a mismatch', () => {
    const g = newGroupPayment({
      id: 'g1', payerId: 'c1', total: TOTAL, method: 'bank_qr', provider: 'fake', idempotencyKey: 'k', now: NOW, expiresAt: LATER,
    });
    const kids = lines().map((l) => newChildPayment({
      id: l.paymentId, groupId: 'g1', line: l, payerId: 'c1', method: 'bank_qr', provider: 'fake', now: NOW, expiresAt: LATER,
    }));
    assert.doesNotThrow(() => assertLinesSum(g, kids));
    assert.throws(() => assertLinesSum({ ...g, amount: TOTAL + 1 }, kids), (e: unknown) => e instanceof DomainError);
    assert.throws(() => assertLinesSum(g, kids.slice(0, 1)), (e: unknown) => e instanceof DomainError);
    assert.throws(() => assertLinesSum(g, [kids[0] as Payment, { ...(kids[1] as Payment), groupId: 'g2' }]), (e: unknown) => e instanceof DomainError);
  });

  test('payoutLineOf/taxRateBpOf for payeeKind organizer is 0 fee and 0 tax', () => {
    assert.equal(taxRateBpOf('organizer', DEFAULT_PAYOUT_POLICY), 0);
    const line = payoutLineOf(140_000, 'organizer', DEFAULT_PAYOUT_POLICY);
    assert.deepEqual([line.fee, line.tax, line.net, line.feeRateBp, line.taxRateBp], [0, 0, 140_000, 0, 0]);
    // Even under a policy with a commission for providers.
    const policy = { ...DEFAULT_PAYOUT_POLICY, feeBp: { individual: 1000, artist: 1000, studio: 1000 } };
    assert.equal(payoutLineOf(140_000, 'organizer', policy).fee, 0);
  });

  test('refundPlan provider decline → both 100% (booking: decline, entry_ticket: provider_cancelled)', () => {
    assert.deepEqual(refundPlan(lines(), 'provider', false, 100, 0, 'decline'), [
      { paymentId: 'pb', percent: 100, reason: 'decline' },
      { paymentId: 'pt', percent: 100, reason: 'provider_cancelled' },
    ]);
    // keepTickets means nothing when the provider cancels: the reason to go is gone.
    assert.deepEqual(refundPlan(lines(), 'provider', true, 100, 0, 'decline').map((x) => x.percent), [100, 100]);
  });

  test('customer cancel keepTickets false → booking percent from the table, entry_ticket by entryRefundPercent', () => {
    assert.deepEqual(refundPlan(lines(), 'customer', false, 50, 0), [
      { paymentId: 'pb', percent: 50, reason: 'customer_cancel' },
      { paymentId: 'pt', percent: 0, reason: 'customer_cancel' },
    ]);
    assert.deepEqual(refundPlan(lines(), 'customer', false, 100, 100).map((x) => x.percent), [100, 100]);
  });

  test('keepTickets true → booking only', () => {
    assert.deepEqual(refundPlan(lines(), 'customer', true, 100, 100), [{ paymentId: 'pb', percent: 100, reason: 'customer_cancel' }]);
  });

  test('venue_day_closed → entry 100% only', () => {
    assert.deepEqual(refundPlan(lines(), 'venue_day_closed', false, 0, 0), [{ paymentId: 'pt', percent: 100, reason: 'day_closed' }]);
  });
});

describe('group settlement', () => {
  test('matchPayment never returns an awaiting_group child', async () => {
    const w = await createBookingEntryWorld();
    const { bookingChild } = await openGroup(w);
    // Even a child that somehow carries a code is never matched (it is not payable on its own).
    const code = transferCodeFor(bookingChild.id);
    w.booking.store.payments.set(bookingChild.id, { ...bookingChild, transferCode: code });
    const res = await send(w, transfer(w, code, DEPOSIT));
    assert.equal(res.outcome, 'needs_review');
    assert.equal(paymentOf(w, bookingChild.id)?.status, 'awaiting_group');
  });

  test('settle: exact total → group paid with escrow released, every child paid and held with its releaseAfter', async () => {
    const w = await createBookingEntryWorld();
    const { draft, groupId, bookingChild, ticketChild, code } = await openGroup(w);
    const res = await send(w, transfer(w, code, TOTAL));
    assert.deepEqual(res, { outcome: 'paid', paymentId: groupId });
    const g = paymentOf(w, groupId) as Payment;
    assert.deepEqual([g.status, g.escrowStatus, g.payableAmount], ['paid', 'released', 0]);
    const b = paymentOf(w, bookingChild.id) as Payment;
    const t = paymentOf(w, ticketChild.id) as Payment;
    assert.deepEqual([b.status, b.escrowStatus, b.releaseAfter], ['paid', 'held', undefined]);
    assert.deepEqual([t.status, t.escrowStatus, t.releaseAfter], ['paid', 'held', entryReleaseAt(VISIT).toISOString()]);
    assert.equal(w.booking.store.bookings.get(draft.id)?.status, 'requested');
    assert.equal(reg(w, t.subjectId)?.status, 'paid');
    assert.deepEqual([day(w)?.held, day(w)?.sold], [0, 2]);
    assert.equal(w.booking.store.paymentGroups.get(groupId)?.status, 'paid');
  });

  test('below total → partial on the group only, children untouched', async () => {
    const w = await createBookingEntryWorld();
    const { draft, groupId, bookingChild, ticketChild, code } = await openGroup(w);
    const res = await send(w, transfer(w, code, TOTAL - 10_000));
    assert.equal(res.outcome, 'partial');
    assert.deepEqual([paymentOf(w, groupId)?.status, paymentOf(w, groupId)?.receivedAmount], ['created', TOTAL - 10_000]);
    assert.equal(paymentOf(w, bookingChild.id)?.status, 'awaiting_group');
    assert.equal(paymentOf(w, ticketChild.id)?.status, 'awaiting_group');
    assert.equal(w.booking.store.bookings.get(draft.id)?.status, 'draft');
    assert.equal(reg(w, ticketChild.subjectId)?.status, 'held');
    assert.deepEqual([day(w)?.held, day(w)?.sold], [2, 0]);
  });

  test('above total → over: children paid, the excess refunded from the group payment', async () => {
    const w = await createBookingEntryWorld();
    const { groupId, bookingChild, ticketChild, code } = await openGroup(w);
    const res = await send(w, transfer(w, code, TOTAL + 30_000));
    assert.equal(res.outcome, 'paid_with_refund');
    const refunds = [...w.booking.store.refunds.values()].filter((r) => r.paymentId === groupId);
    assert.deepEqual(refunds.map((r) => [r.amount, r.reason, r.fromEscrow]), [[30_000, 'overpaid_excess', false]]);
    assert.equal(paymentOf(w, bookingChild.id)?.status, 'paid');
    assert.equal(paymentOf(w, ticketChild.id)?.status, 'paid');
    assert.equal(paymentOf(w, groupId)?.refundedAmount, 30_000);
  });

  test('a duplicate notification → duplicate', async () => {
    const w = await createBookingEntryWorld();
    const { code } = await openGroup(w);
    const n = transfer(w, code, TOTAL, 'txn_group_dup');
    assert.equal((await send(w, n)).outcome, 'paid');
    assert.equal((await send(w, n)).outcome, 'duplicate');
    assert.equal(day(w)?.sold, 2);
  });

  test('expire → group and children expired, held registration released, entry_days.held decremented', async () => {
    const w = await createBookingEntryWorld();
    const { groupId, bookingChild, ticketChild } = await openGroup(w);
    assert.equal(day(w)?.held, 2);
    w.booking.clock.advanceMinutes(16);
    const swept = await runPaymentSweeps(w.settlement);
    assert.equal(swept.expired, 1);
    assert.equal(paymentOf(w, groupId)?.status, 'expired');
    assert.equal(paymentOf(w, bookingChild.id)?.status, 'expired');
    assert.equal(paymentOf(w, ticketChild.id)?.status, 'expired');
    assert.equal(reg(w, ticketChild.subjectId)?.status, 'cancelled');
    assert.equal(day(w)?.held, 0);
    assert.equal(w.entry.store.events.get(ENTRY_ID)?.heldCount, 0);
    assert.equal(w.booking.store.paymentGroups.get(groupId)?.status, 'expired');
  });

  test('confirmFakePayment on a child confirms the group', async () => {
    const w = await createBookingEntryWorld();
    const { draft, groupId, bookingChild } = await openGroup(w);
    const out = await confirmFakePayment(w.settlement, { uid: 'c1' }, { paymentId: bookingChild.id });
    assert.deepEqual([out.outcome, out.subjectType, out.paymentStatus], ['paid', 'payment_group', 'paid']);
    assert.equal(paymentOf(w, groupId)?.status, 'paid');
    assert.equal(w.booking.store.bookings.get(draft.id)?.status, 'requested');
  });

  test('the payer history shows a paid group by its lines (no row for the split group)', async () => {
    const w = await createBookingEntryWorld();
    const { groupId, bookingChild, ticketChild, code } = await openGroup(w);
    const now = w.booking.clock.now();
    await send(w, transfer(w, code, TOTAL - 10_000));
    assert.ok(payerRowOf(paymentOf(w, groupId) as Payment, [], EMPTY_PAYER_SUBJECT, now), 'a part-paid group has its row');
    await send(w, transfer(w, code, 10_000));
    assert.equal(payerRowOf(paymentOf(w, groupId) as Payment, [], EMPTY_PAYER_SUBJECT, now), null);
    for (const id of [bookingChild.id, ticketChild.id]) {
      assert.equal(payerRowOf(paymentOf(w, id) as Payment, [], EMPTY_PAYER_SUBJECT, now)?.status, 'held');
    }
  });

  test('verifyPaymentLedgerInvariant holds for the group and every child', async () => {
    const w = await createBookingEntryWorld();
    const { groupId, bookingChild, ticketChild, code } = await openGroup(w);
    for (const id of [groupId, bookingChild.id, ticketChild.id]) assert.ok(ledgerHolds(w, paymentOf(w, id) as Payment), `open ${id}`);
    await send(w, transfer(w, code, TOTAL + 50_000));
    for (const id of [groupId, bookingChild.id, ticketChild.id]) assert.ok(ledgerHolds(w, paymentOf(w, id) as Payment), `paid ${id}`);

    // An expired group and its children too.
    const w2 = await createBookingEntryWorld();
    const o2 = await openGroup(w2);
    await send(w2, transfer(w2, o2.code, 100_000));
    w2.booking.clock.advanceMinutes(16);
    await runPaymentSweeps(w2.settlement);
    for (const id of [o2.groupId, o2.bookingChild.id, o2.ticketChild.id]) {
      assert.ok(ledgerHolds(w2, paymentOf(w2, id) as Payment), `expired ${id}`);
    }
  });
});

describe('payouts by payee kind', () => {
  test('createPayout splits one payee into two batches by payeeKind', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    const b = await paidBooking(w, '2026-10-15');
    release(w, b.paymentId);
    const t = await paidBooking(w, '2026-10-16');
    release(w, t.paymentId);
    const tp = w.store.payments.get(t.paymentId) as Payment;
    w.store.payments.set(t.paymentId, {
      ...tp, subjectType: 'event_registration', subjectId: 'reg_x', eventId: 'en1', amount: 140_000,
      idempotencyKey: 'tkt_reg_x_bank_qr', lineKind: 'entry_ticket', payeeKind: 'organizer',
    });

    const batches = await createPayouts(w.payoutDeps, ADMIN, 'p1');
    assert.equal(batches.length, 2);
    const provider = batches.find((p) => p.items.some((i) => i.paymentId === b.paymentId));
    const organizer = batches.find((p) => p.items.some((i) => i.paymentId === t.paymentId));
    assert.ok(provider && organizer && provider.id !== organizer.id);
    assert.deepEqual(provider.items.map((i) => i.paymentId), [b.paymentId]);
    assert.equal(provider.taxRateBp, 700);
    assert.ok(provider.taxWithheld > 0);
    assert.deepEqual(organizer.items.map((i) => [i.paymentId, i.fee, i.tax, i.net]), [[t.paymentId, 0, 0, 140_000]]);
    assert.deepEqual([organizer.feeRateBp, organizer.taxRateBp, organizer.taxWithheld, organizer.amountNet], [0, 0, 0, 140_000]);
    assert.equal(w.store.payments.get(t.paymentId)?.payoutId, organizer.id);
    assert.equal(w.store.payments.get(b.paymentId)?.payoutId, provider.id);
  });

  test('createPayout still answers one payout (the first batch) and leaves nothing to batch again', async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    const b = await paidBooking(w, '2026-10-15');
    release(w, b.paymentId);
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.deepEqual(po.items.map((i) => i.paymentId), [b.paymentId]);
    await assert.rejects(createPayout(w.payoutDeps, ADMIN, 'p1'), (e: unknown) => e instanceof DomainError && e.code === 'not_eligible');
  });

  test('a released group payment is never paid out (its money is the lines\')', async () => {
    const w = createPayoutWorld();
    await addAccount(w, '0123456789', { uid: 'c1' });
    const b = await paidBooking(w, '2026-10-15');
    const p = w.store.payments.get(b.paymentId) as Payment;
    w.store.payments.set(b.paymentId, {
      ...p, subjectType: 'payment_group', subjectId: p.id, payeeId: 'c1', escrowStatus: 'released', payableAmount: 0,
    });
    await assert.rejects(createPayout(w.payoutDeps, ADMIN, 'c1'), (e: unknown) => e instanceof DomainError && e.code === 'not_eligible');
  });
});
