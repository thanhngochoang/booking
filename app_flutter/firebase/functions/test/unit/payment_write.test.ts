import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  DEFAULT_PAYOUT_POLICY,
  EMPTY_PAYER_SUBJECT,
  MemoryBookingStore,
  MemoryEarningsStore,
  MemoryPayerHistoryStore,
  MemoryPayoutStore,
  type Payment,
} from '@photobooking/domain';
import { paymentToFirestore } from '../../src/infra/booking_firestore.js';
import { FirestorePayerHistoryStore } from '../../src/infra/payer_history_firestore.js';
import { handlePaymentWrite } from '../../src/triggers/payment_write.js';
import { strictFirestore } from './strict_firestore_support.js';

const T = '2026-10-10T08:00:00.000Z';
const NOW = new Date('2026-10-20T10:00:00.000Z');

const payment = (over: Partial<Payment> = {}): Payment => ({
  id: 'pay1', subjectType: 'booking', subjectId: 'b1', payerId: 'c1', payeeId: 'p1', provider: 'fake',
  amount: 1_000_000, status: 'paid', escrowStatus: 'held', idempotencyKey: 'k1', method: 'bank_qr',
  receivedAmount: 1_000_000, paidAt: T, createdAt: T, updatedAt: T, ...over,
});

function world(p: Payment) {
  const booking = new MemoryBookingStore();
  const payouts = new MemoryPayoutStore(booking);
  const earnings = new MemoryEarningsStore(booking, payouts, new Map([['c1', 'Lan']]));
  booking.payments.set(p.id, p);
  booking.bookings.set('b1', {
    id: 'b1', customerId: 'c1', photographerId: 'p1', serviceId: 's1',
    serviceSnapshot: { name: 'Chân dung', price: 1_000_000, durationMinutes: 120 },
    day: '2026-10-12', start: '08:00', end: '10:00', place: { name: 'Hồ Tây' }, status: 'accepted',
    deposit: 1_000_000, remaining: 0, version: 1, createdAt: T, updatedAt: T,
  } as never);
  const history = new MemoryPayerHistoryStore();
  history.payments.set(p.id, p);
  history.subjects.set(p.id, { ...EMPTY_PAYER_SUBJECT, photographerName: 'Minh Trí', serviceName: 'Chân dung', day: '2026-10-12' });
  return {
    booking,
    earnings,
    history,
    deps: { store: earnings, clock: { now: () => NOW }, policy: DEFAULT_PAYOUT_POLICY },
    historyDeps: { store: history, clock: { now: () => NOW } },
  };
}

/** The fields of a stored payment document the trigger looks at (Timestamps left out). */
const doc = (p: Payment, updatedAt = 'a') => ({
  payeeId: p.payeeId, payerId: p.payerId, subjectType: p.subjectType, subjectId: p.subjectId, status: p.status,
  escrowStatus: p.escrowStatus, receivedAmount: p.receivedAmount ?? 0, refundedAmount: p.refundedAmount ?? 0, updatedAt,
});

describe('onPaymentWritten → payer history', () => {
  it('a write that changes only updatedAt does not refresh the payer row', async () => {
    const p = payment();
    const w = world(p);
    await handlePaymentWrite('pay1', doc(p, 'a'), doc(p, 'b'), w.deps, w.historyDeps);
    assert.equal(w.history.rows.size, 0);
    assert.equal(w.history.totals.size, 0);
    // An unpaid QR being created or expiring has no money: no row, no write.
    const q = payment({ status: 'created', receivedAmount: 0, paidAt: undefined });
    const w2 = world(q);
    await handlePaymentWrite('pay1', undefined, doc(q), w2.deps, w2.historyDeps);
    await handlePaymentWrite('pay1', doc(q), doc({ ...q, status: 'expired', escrowStatus: 'refunded' }), w2.deps, w2.historyDeps);
    assert.equal(w2.history.totals.size, 0);
  });

  it('payer row and earnings both refresh on a status change', async () => {
    const before = payment({ status: 'created', receivedAmount: 0, paidAt: undefined });
    const p = payment();
    const w = world(p);
    assert.equal(await handlePaymentWrite('pay1', doc(before), doc(p), w.deps, w.historyDeps), 'p1');
    assert.equal(w.history.rows.get('c1/pay1')?.status, 'held');
    assert.deepEqual(w.history.totals.get('c1'), { held: 1_000_000, refunding: 0, updatedAt: NOW.toISOString() });
    assert.equal(w.earnings.items.has('p1/pay1'), true);

    // The shoot milestone released: escrow stays `held`, the held amount drops (milestones watched too).
    const ms = [
      { kind: 'shoot' as const, amount: 500_000, status: 'released' as const, releaseAfter: null, releasedAt: T, payoutId: null },
      { kind: 'delivery' as const, amount: 500_000, status: 'held' as const, releaseAfter: null, releasedAt: null, payoutId: null },
    ];
    const split = { ...p, milestones: ms.map((m) => ({ ...m, status: 'held' as const })) };
    const released = { ...p, milestones: ms };
    w.history.payments.set('pay1', released);
    const plain = (x: Payment) => ({ ...doc(x), milestones: x.milestones?.map((m) => ({ kind: m.kind, amount: m.amount, status: m.status })) });
    // No subjectType 'booking' milestone sync here: the test documents leave the subject out.
    await handlePaymentWrite('pay1', { ...plain(split), subjectType: undefined }, { ...plain(released), subjectType: undefined }, w.deps, w.historyDeps);
    assert.equal(w.history.rows.get('c1/pay1')?.heldAmount, 500_000);
  });

  it('without history deps only earnings refresh (callers that predate S22.01)', async () => {
    const p = payment();
    const w = world(p);
    assert.equal(await handlePaymentWrite('pay1', undefined, doc(p), w.deps), 'p1');
    assert.equal(w.history.rows.size, 0);
  });

  it('accepting a Chụp ngay request clears searching; a photographer cancel sets it again', async () => {
    const searching = payment({ subjectType: 'instant_request', subjectId: 'ir1', payeeId: '', method: 'momo' });
    const docs: Record<string, Record<string, unknown>> = {
      'payments/pay1': paymentToFirestore(searching),
      'instant_requests/ir1': { status: 'searching', areaLabel: 'Quận 1, TP.HCM' },
    };
    const fake = strictFirestore(docs);
    const history = { store: new FirestorePayerHistoryStore(fake.firestore), clock: { now: () => NOW } };
    const w = world(searching);
    const raw = (p: Payment) => ({ ...doc(p), subjectType: 'instant_request' });
    await handlePaymentWrite('pay1', undefined, raw(searching), w.deps, history);
    assert.equal(docs['users/c1/payments/pay1']?.searching, true);

    // A photographer accepts: only the payee changes on the payment (escrow stays held).
    const accepted = { ...searching, payeeId: 'p1' };
    docs['payments/pay1'] = paymentToFirestore(accepted);
    docs['instant_requests/ir1'] = { status: 'assigned', areaLabel: 'Quận 1, TP.HCM' };
    await handlePaymentWrite('pay1', raw(searching), raw(accepted), w.deps, history);
    assert.equal(docs['users/c1/payments/pay1']?.searching, false);

    // The photographer cancels: the payee goes back to '' and the request to `choosing`.
    docs['payments/pay1'] = paymentToFirestore(searching);
    docs['instant_requests/ir1'] = { status: 'choosing', areaLabel: 'Quận 1, TP.HCM' };
    await handlePaymentWrite('pay1', raw(accepted), raw(searching), w.deps, history);
    assert.equal(docs['users/c1/payments/pay1']?.searching, true);
  });

  it('a deleted payment loses its payer row and leaves the totals', async () => {
    const p = payment();
    const w = world(p);
    await handlePaymentWrite('pay1', undefined, doc(p), w.deps, w.historyDeps);
    assert.equal(w.history.rows.has('c1/pay1'), true);
    w.history.payments.delete('pay1');
    await handlePaymentWrite('pay1', doc(p), undefined, w.deps, w.historyDeps);
    assert.equal(w.history.rows.has('c1/pay1'), false);
    assert.deepEqual(w.history.totals.get('c1'), { held: 0, refunding: 0, updatedAt: NOW.toISOString() });
  });

  it('the payee\'s earnings refresh before the payer row, so a failing payer refresh never holds them back', async () => {
    const p = payment({ escrowStatus: 'released' });
    const w = world(p);
    const failing = { store: { runTransaction: () => Promise.reject(new Error('boom')), paymentIdsOf: async () => [] }, clock: w.historyDeps.clock };
    await assert.rejects(handlePaymentWrite('pay1', undefined, doc(p), w.deps, failing), /boom/);
    assert.equal(w.earnings.items.has('p1/pay1'), true);
  });
});
