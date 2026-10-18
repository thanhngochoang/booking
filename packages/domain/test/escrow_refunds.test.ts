/**
 * Final review of #129: money sent straight back on arrival (over-transfer excess, a second
 * transfer, a late transfer) never entered escrow, so release, payouts and earnings must not
 * subtract it; and an unpaid (`created`) booking payment is never money for the payee.
 */
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { bookingNotices } from '../src/booking_notifications.js';
import { computeRefund } from '../src/booking_policy.js';
import { createBookingDraft } from '../src/create_booking.js';
import { createPayment } from '../src/create_payment.js';
import { escrowRefundedTotal, isEscrowRefund, type Payment, type Refund } from '../src/escrow.js';
import { handleTransferNotification } from '../src/handle_transfer.js';
import { runBookingSweeps } from '../src/booking_sweeps.js';
import { openDispute } from '../src/open_dispute.js';
import { createPayout } from '../src/payout_use_cases.js';
import { refreshEarnings } from '../src/refresh_earnings.js';
import { dispatchRefund, dispatchRefunds } from '../src/refunds.js';
import { transitionBooking } from '../src/transition_booking.js';
import { transferOf } from './support/booking_world.js';
import { ADMIN, addAccount, createPayoutWorld, type PayoutWorld } from './support/payout_world.js';

const PRICE = 1_000_000;

/** p1's accepted booking on 2026-10-15 14:00, paid by the given transfers (amounts) of its QR code. */
async function bookingPaidWith(w: PayoutWorld, transfers: readonly number[]): Promise<{ bookingId: string; paymentId: string }> {
  const draft = await createBookingDraft(w.deps, {
    customerId: 'c1', photographerId: 'p1', serviceId: 'srv_01', day: '2026-10-15', start: '14:00', place: { name: 'Nhà thờ Lớn' },
  });
  const { paymentId, checkout } = await createPayment(w.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
  for (const amount of transfers) {
    await handleTransferNotification(w.deps, transferOf(w, { content: checkout.transferCode, amount }));
  }
  await transitionBooking(w.deps, { bookingId: draft.id, action: 'accept', actorId: 'p1' });
  return { bookingId: draft.id, paymentId };
}

/** Completes the booking after the shoot and runs the clock past the dispute window. */
async function completeAndRelease(w: PayoutWorld, bookingId: string): Promise<void> {
  w.clock.setTime(new Date('2026-10-16T09:30:00.000Z'));
  await transitionBooking(w.deps, { bookingId, action: 'complete', actorId: 'p1' });
  w.clock.setTime(new Date('2026-10-17T10:00:00.000Z'));
  assert.equal((await runBookingSweeps(w.deps)).releasedEscrows, 1);
}

const released = (w: PayoutWorld, paymentId: string): number[] =>
  [...w.store.ledgerEntries.values()].filter((e) => e.type === 'escrow_released' && e.paymentId === paymentId).map((e) => e.amount);

/** Release, payout and earnings amounts for one payment of p1. */
async function payeeAmounts(w: PayoutWorld, paymentId: string): Promise<{ release: number[]; earning: number | undefined; payout: number }> {
  const release = released(w, paymentId);
  const summary = await refreshEarnings(w.earningsDeps, { payeeId: 'p1', paymentIds: [paymentId] });
  const item = w.earningsStore.items.get(`p1/${paymentId}`);
  const earning = item?.soonAmount ?? item?.amount;
  assert.equal(summary.soonAmount, earning);
  await addAccount(w);
  const payout = (await createPayout(w.payoutDeps, ADMIN, 'p1')).amount;
  return { release, earning, payout };
}

describe('escrow refunds vs pass-through refunds', () => {
  it('refunds from the payment paths are marked: transfer refunds are not escrow, cancellations are', async () => {
    const w = createPayoutWorld();
    const { bookingId, paymentId } = await bookingPaidWith(w, [1_200_000]);
    const excess = [...w.store.refunds.values()].filter((r) => r.paymentId === paymentId);
    assert.deepEqual(excess.map((r) => [r.reason, r.amount, r.fromEscrow]), [['overpaid_excess', 200_000, false]]);

    w.clock.setTime(new Date('2026-10-14T01:00:00.000Z'));
    await transitionBooking(w.deps, { bookingId, action: 'cancel', actorId: 'c1', reason: 'overpaid_excess' });
    const cancel = [...w.store.refunds.values()].filter((r) => r.paymentId === paymentId && r.fromEscrow);
    // The customer's free-text reason never decides it, even when it copies a transfer reason.
    assert.deepEqual(cancel.map((r) => r.amount), [computeRefund(PRICE, 50)]);
  });

  it('over-transfer of 1 200 000 on a 1 000 000 booking: release, payout and earnings are the price', async () => {
    const w = createPayoutWorld();
    const { bookingId, paymentId } = await bookingPaidWith(w, [1_200_000]);
    await completeAndRelease(w, bookingId);
    assert.deepEqual(await payeeAmounts(w, paymentId), { release: [500_000], earning: 500_000, payout: 500_000 });
  });

  it('paying the QR twice: the second transfer goes back and the payee still gets the price', async () => {
    const w = createPayoutWorld();
    const { bookingId, paymentId } = await bookingPaidWith(w, [PRICE, PRICE]);
    const refunds = [...w.store.refunds.values()].filter((r) => r.paymentId === paymentId);
    assert.deepEqual(refunds.map((r) => [r.reason, r.fromEscrow]), [['extra_transfer', false]]);
    await completeAndRelease(w, bookingId);
    assert.deepEqual(await payeeAmounts(w, paymentId), { release: [500_000], earning: 500_000, payout: 500_000 });
  });

  it('a 50% cancellation after an over-transfer releases half of the price', async () => {
    const w = createPayoutWorld();
    const { bookingId, paymentId } = await bookingPaidWith(w, [1_200_000]);
    // 30 h before the shoot: 50% back; the kept half is released after start + 24 h.
    w.clock.setTime(new Date('2026-10-14T01:00:00.000Z'));
    await transitionBooking(w.deps, { bookingId, action: 'cancel', actorId: 'c1', reason: 'Bận' });
    w.clock.setTime(new Date('2026-10-16T08:00:00.000Z'));
    assert.equal((await runBookingSweeps(w.deps)).releasedEscrows, 1);
    const kept = PRICE - computeRefund(PRICE, 50);
    assert.deepEqual(await payeeAmounts(w, paymentId), { release: [kept], earning: kept, payout: kept });
  });

  it('a refund stored before the marker existed still counts as an escrow refund', async () => {
    const w = createPayoutWorld();
    const { bookingId, paymentId } = await bookingPaidWith(w, [PRICE]);
    const legacy = {
      id: 'legacy_r1', paymentId, subjectType: 'booking', amount: 100_000, percent: 10, status: 'done', manual: false,
      createdAt: '2026-10-10T10:00:00.000Z', updatedAt: '2026-10-10T10:00:00.000Z',
    } as unknown as Refund;
    assert.equal(isEscrowRefund(legacy), true);
    w.store.refunds.set(legacy.id, legacy);
    await completeAndRelease(w, bookingId);
    assert.deepEqual(await payeeAmounts(w, paymentId), { release: [450_000], earning: 450_000, payout: 450_000 });
  });

  it('escrowRefundedTotal sums only escrow refunds', () => {
    const r = (amount: number, fromEscrow?: boolean) => ({ amount, ...(fromEscrow === undefined ? {} : { fromEscrow }) }) as Refund;
    assert.equal(escrowRefundedTotal([r(100, true), r(200, false), r(400)]), 500);
  });
});

describe('unpaid booking payments', () => {
  it('a created QR payment is not Đang giữ in earnings', async () => {
    const w = createPayoutWorld();
    const draft = await createBookingDraft(w.deps, {
      customerId: 'c1', photographerId: 'p1', serviceId: 'srv_01', day: '2026-10-15', start: '14:00', place: { name: 'Nhà thờ Lớn' },
    });
    const { paymentId } = await createPayment(w.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
    assert.equal(w.store.payments.get(paymentId)?.status, 'created');
    const summary = await refreshEarnings(w.earningsDeps, { payeeId: 'p1', paymentIds: [paymentId] });
    assert.equal(summary.heldAmount, 0);
    assert.equal(w.earningsStore.items.has(`p1/${paymentId}`), false);
  });

  /** A paid, accepted booking whose payment list starts with a stray `created` row (escrow `held`). */
  async function withStrayFirst(w: PayoutWorld): Promise<{ bookingId: string; paymentId: string; stray: Payment }> {
    const paid = await bookingPaidWith(w, [PRICE]);
    const real = w.store.payments.get(paid.paymentId);
    assert.ok(real);
    const stray: Payment = {
      ...real, id: 'stray_created', status: 'created', escrowStatus: 'held', transferCode: undefined, receivedAmount: 0,
      paidAt: undefined, idempotencyKey: 'stray',
    };
    const rest = [...w.store.payments.entries()];
    w.store.payments.clear();
    w.store.payments.set(stray.id, stray);
    for (const [k, v] of rest) w.store.payments.set(k, v);
    return { ...paid, stray };
  }

  it('completion schedules the release of the paid payment, never a stray created one', async () => {
    const w = createPayoutWorld();
    const { bookingId, paymentId, stray } = await withStrayFirst(w);
    await completeAndRelease(w, bookingId);
    assert.deepEqual(released(w, paymentId), [500_000]);
    assert.deepEqual(released(w, stray.id), []);
    assert.equal(w.store.payments.get(stray.id)?.releaseAfter, undefined);
  });

  it('a dispute holds the paid payment, never a stray created one', async () => {
    const w = createPayoutWorld();
    const { bookingId, paymentId, stray } = await withStrayFirst(w);
    w.clock.setTime(new Date('2026-10-16T09:30:00.000Z'));
    await transitionBooking(w.deps, { bookingId, action: 'complete', actorId: 'p1' });
    await openDispute(w.deps, { bookingId, customerId: 'c1', reason: 'Thiếu ảnh' });
    assert.equal(w.store.payments.get(paymentId)?.escrowStatus, 'disputed');
    assert.equal(w.store.payments.get(stray.id)?.escrowStatus, 'held');
  });
});

describe('booking refund_done marker (depositRefundedAt)', () => {
  const manualRefund = (paymentId: string, id: string, fromEscrow = true): Refund => ({
    id, paymentId, subjectType: 'booking', amount: 100_000, percent: 10, status: 'pending', manual: false, fromEscrow,
    method: 'gateway', attempts: 0,
    reason: 'test', createdAt: '2026-10-14T01:00:00.000Z', updatedAt: '2026-10-14T01:00:00.000Z',
  });

  it('a booking escrow refund that becomes done sets depositRefundedAt once', async () => {
    const w = createPayoutWorld();
    const { bookingId, paymentId } = await bookingPaidWith(w, [PRICE]);
    w.clock.setTime(new Date('2026-10-14T01:00:00.000Z'));
    await transitionBooking(w.deps, { bookingId, action: 'cancel', actorId: 'c1', reason: 'Bận' });
    const after = w.store.bookings.get(bookingId);
    assert.ok(after);
    assert.equal(after.depositRefundedAt, '2026-10-14T01:00:00.000Z');
    assert.equal(after.updatedAt, '2026-10-14T01:00:00.000Z');
    assert.equal(after.depositRefunded, computeRefund(PRICE, 50));
    // The booking trigger now sees the marker appear and sends refund_done.
    assert.deepEqual(bookingNotices({ ...after, depositRefundedAt: undefined }, after), [{ to: 'customer', kind: 'refund' }]);

    // A later escrow refund of the same payment leaves the first instant.
    w.clock.setTime(new Date('2026-10-14T05:00:00.000Z'));
    const extra = await dispatchRefund(w.deps, manualRefund(paymentId, 'r_extra'), 'fake');
    assert.equal(extra.status, 'done');
    assert.equal(w.store.bookings.get(bookingId)?.depositRefundedAt, '2026-10-14T01:00:00.000Z');
    assert.equal(w.store.bookings.get(bookingId)?.version, after.version);
  });

  it('a refund with fromEscrow false does not set it', async () => {
    const w = createPayoutWorld();
    const { bookingId, paymentId } = await bookingPaidWith(w, [1_200_000]);
    const excess = [...w.store.refunds.values()].filter((r) => r.paymentId === paymentId);
    assert.deepEqual(excess.map((r) => [r.status, r.fromEscrow]), [['done', false]]);
    assert.equal(w.store.bookings.get(bookingId)?.depositRefundedAt, undefined);
    await dispatchRefund(w.deps, manualRefund(paymentId, 'r_pass', false), 'fake');
    assert.equal(w.store.bookings.get(bookingId)?.depositRefundedAt, undefined);
  });

  it('a failed refund does not set it', async () => {
    const w = createPayoutWorld();
    const { bookingId, paymentId } = await bookingPaidWith(w, [PRICE]);
    w.gateway.refundFailureId = 'r_fail';
    assert.equal((await dispatchRefund(w.deps, manualRefund(paymentId, 'r_fail'), 'fake')).status, 'failed');
    w.gateway.refundThrowCount = 1;
    const [thrown] = await dispatchRefunds(w.deps, [{ refund: manualRefund(paymentId, 'r_throw'), provider: 'fake' }]);
    assert.equal(thrown?.status, 'pending');
    assert.equal(thrown?.attempts, 1);
    assert.equal(w.store.bookings.get(bookingId)?.depositRefundedAt, undefined);
  });

  it('a done refund whose booking is gone writes only the refund', async () => {
    const w = createPayoutWorld();
    const { bookingId, paymentId } = await bookingPaidWith(w, [PRICE]);
    w.store.bookings.delete(bookingId);
    assert.equal((await dispatchRefund(w.deps, manualRefund(paymentId, 'r_gone'), 'fake')).status, 'done');
    assert.equal(w.store.bookings.has(bookingId), false);
    assert.equal(w.store.refunds.get('r_gone')?.status, 'done');
  });
});
