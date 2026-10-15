import assert from 'node:assert/strict';
import { computeDeposit } from '../src/booking_policy.js';
import { describe, it } from 'node:test';
import { refreshEarnings } from '../src/refresh_earnings.js';
import { approvePayout, createPayout, executePayout } from '../src/payout_use_cases.js';
import { ADMIN, addAccount, createPayoutWorld, paidBooking, release } from './support/payout_world.js';

/** The customer pays the whole price up front. */
const PAID = computeDeposit(1_000_000).deposit;

describe('refreshEarnings', () => {
  it('refresh writes the named rows and the summary', async () => {
    const w = createPayoutWorld();
    const a = await paidBooking(w, '2026-10-15');
    const b = await paidBooking(w, '2026-10-16');
    release(w, b.paymentId);
    const s = await refreshEarnings(w.earningsDeps, { payeeId: 'p1', paymentIds: [a.paymentId, b.paymentId] });
    assert.deepEqual([s.heldAmount, s.soonAmount, s.receivedAmount], [PAID, PAID, 0]);
    assert.equal(w.earningsStore.items.size, 2);
    assert.equal(w.earningsStore.summaries.get('p1')?.soonAmount, PAID);
    const row = w.earningsStore.items.get(`p1/${a.paymentId}`);
    assert.equal(row?.counterpartName, 'Khách Hàng Một');
    assert.equal(row?.subjectLabel, 'Gói Chân dung');
    assert.equal(row?.day, '2026-10-15');
  });

  it('a payment of another payee is ignored', async () => {
    const w = createPayoutWorld();
    const a = await paidBooking(w, '2026-10-15');
    const s = await refreshEarnings(w.earningsDeps, { payeeId: 'p2', paymentIds: [a.paymentId] });
    assert.equal(s.heldAmount, 0);
    assert.equal(w.earningsStore.items.size, 0);
    assert.equal(w.earningsStore.itemWrites, 0);
  });

  it('refresh is idempotent', async () => {
    const w = createPayoutWorld();
    const a = await paidBooking(w, '2026-10-15');
    await refreshEarnings(w.earningsDeps, { payeeId: 'p1', paymentIds: [a.paymentId] });
    assert.equal(w.earningsStore.itemWrites, 1);
    const summaries = w.earningsStore.summaryWrites;
    w.clock.advanceMinutes(5);
    await refreshEarnings(w.earningsDeps, { payeeId: 'p1', paymentIds: [a.paymentId, a.paymentId] });
    assert.equal(w.earningsStore.itemWrites, 1);
    assert.equal(w.earningsStore.itemDeletes, 0);
    assert.equal(w.earningsStore.summaryWrites, summaries + 1);
  });

  it('a deleted booking removes its row', async () => {
    const w = createPayoutWorld();
    const a = await paidBooking(w, '2026-10-15');
    await refreshEarnings(w.earningsDeps, { payeeId: 'p1', paymentIds: [a.paymentId] });
    w.store.bookings.delete(a.bookingId);
    const s = await refreshEarnings(w.earningsDeps, { payeeId: 'p1', paymentIds: [a.paymentId] });
    assert.equal(w.earningsStore.items.size, 0);
    assert.equal(s.heldAmount, 0);
  });

  it("a paid-out row carries the payout item's fee, tax and net", async () => {
    const w = createPayoutWorld();
    await addAccount(w);
    const a = await paidBooking(w, '2026-10-15');
    release(w, a.paymentId);
    const po = await createPayout(w.payoutDeps, ADMIN, 'p1');
    await approvePayout(w.payoutDeps, ADMIN, po.id);
    await executePayout(w.payoutDeps, ADMIN, po.id);
    const s = await refreshEarnings(w.earningsDeps, { payeeId: 'p1', paymentIds: [a.paymentId] });
    const row = w.earningsStore.items.get(`p1/${a.paymentId}`);
    const it = po.items[0];
    assert.ok(it);
    assert.equal(row?.state, 'paid_out');
    assert.equal(row?.estimated, false);
    assert.deepEqual([row?.amount, row?.platformFee, row?.taxWithheld, row?.netAmount], [it.amount, it.fee, it.tax, it.net]);
    assert.equal(s.receivedAmount, PAID, 'Đã nhận stays gross');
  });

  it("a studio's held row has no tax estimate", async () => {
    const w = createPayoutWorld();
    w.payoutStore.seedPayeeType('p1', 'studio');
    const a = await paidBooking(w, '2026-10-15');
    await refreshEarnings(w.earningsDeps, { payeeId: 'p1', paymentIds: [a.paymentId] });
    const row = w.earningsStore.items.get(`p1/${a.paymentId}`);
    assert.equal(row?.estimated, true);
    assert.equal(row?.taxWithheld, 0);
    assert.equal(row?.netAmount, PAID);
  });

  it('milestones from the subject reach the row; null when absent', async () => {
    const w = createPayoutWorld();
    const a = await paidBooking(w, '2026-10-15');
    const b = await paidBooking(w, '2026-10-16');
    w.earningsStore.milestones.set(a.bookingId, { done: 2, total: 2 });
    await refreshEarnings(w.earningsDeps, { payeeId: 'p1', paymentIds: [a.paymentId, b.paymentId] });
    const rowA = w.earningsStore.items.get(`p1/${a.paymentId}`);
    const rowB = w.earningsStore.items.get(`p1/${b.paymentId}`);
    assert.deepEqual([rowA?.milestonesDone, rowA?.milestonesTotal], [2, 2]);
    assert.deepEqual([rowB?.milestonesDone, rowB?.milestonesTotal], [null, null]);
  });
});
