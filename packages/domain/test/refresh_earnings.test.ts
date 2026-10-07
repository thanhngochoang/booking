import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { refreshEarnings } from '../src/refresh_earnings.js';
import { createPayoutWorld, paidBooking, release } from './support/payout_world.js';

describe('refreshEarnings', () => {
  it('refresh writes the named rows and the summary', async () => {
    const w = createPayoutWorld();
    const a = await paidBooking(w, '2026-10-15');
    const b = await paidBooking(w, '2026-10-16');
    release(w, b.paymentId);
    const s = await refreshEarnings(w.earningsDeps, { payeeId: 'p1', paymentIds: [a.paymentId, b.paymentId] });
    assert.deepEqual([s.heldAmount, s.soonAmount, s.receivedAmount], [300_000, 300_000, 0]);
    assert.equal(w.earningsStore.items.size, 2);
    assert.equal(w.earningsStore.summaries.get('p1')?.soonAmount, 300_000);
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
});
