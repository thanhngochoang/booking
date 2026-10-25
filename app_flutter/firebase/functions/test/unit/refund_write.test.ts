import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  EMPTY_PAYER_SUBJECT,
  MemoryNotificationStore,
  MemoryPayerHistoryStore,
  MemoryPushSender,
  MemoryUserDirectory,
  type Payment,
  type Refund,
} from '@photobooking/domain';
import { refundToFirestore } from '../../src/infra/booking_firestore.js';
import { handleRefundWrite } from '../../src/triggers/refund_write.js';

const T = '2026-10-10T08:00:00.000Z';
const NOW = new Date('2026-10-20T10:00:00.000Z');

const payment: Payment = {
  id: 'pay1', subjectType: 'booking', subjectId: 'b1', payerId: 'c1', payeeId: 'p1', provider: 'fake',
  amount: 1_000_000, status: 'refunded', escrowStatus: 'refunded', idempotencyKey: 'k1', method: 'momo',
  receivedAmount: 1_000_000, refundedAmount: 1_000_000, paidAt: T, createdAt: T, updatedAt: T,
};
const refund = (status: Refund['status']): Refund => ({
  id: 'r1', paymentId: 'pay1', subjectType: 'booking', amount: 1_000_000, percent: 100, status, manual: false,
  fromEscrow: true, method: 'gateway', destination: null, attempts: 1, createdAt: T, updatedAt: T,
});

describe('onRefundWritten', () => {
  it('a refund write refreshes the payer row of its payment', async () => {
    const store = new MemoryPayerHistoryStore();
    store.payments.set('pay1', payment);
    store.subjects.set('pay1', { ...EMPTY_PAYER_SUBJECT, photographerName: 'Lan Anh', serviceName: 'Chân dung 2 giờ', day: '2026-08-12', cancelled: true });
    const deps = { store, clock: { now: () => NOW } };

    store.refunds.set('r1', refund('pending'));
    assert.equal(await handleRefundWrite('r1', undefined, { paymentId: 'pay1', status: 'pending' }, deps), 'written');
    assert.equal(store.rows.get('c1/pay1')?.status, 'refunding');
    assert.deepEqual(store.totals.get('c1'), { held: 0, refunding: 1_000_000, updatedAt: NOW.toISOString() });

    store.refunds.set('r1', refund('done'));
    assert.equal(await handleRefundWrite('r1', { paymentId: 'pay1', status: 'pending' }, { paymentId: 'pay1', status: 'done' }, deps), 'written');
    assert.equal(store.rows.get('c1/pay1')?.status, 'refunded');
    assert.deepEqual(store.totals.get('c1'), { held: 0, refunding: 0, updatedAt: NOW.toISOString() });

    // A delete uses the payment of the old document; a document without a payment is skipped.
    assert.equal(await handleRefundWrite('r1', { paymentId: 'pay1' }, undefined, deps), 'written');
    assert.equal(await handleRefundWrite('r1', undefined, { status: 'done' }, deps), null);
  });

  it('a refund entering awaiting_account tells its payer once (S22.04); other writes do not', async () => {
    const store = new MemoryPayerHistoryStore();
    store.payments.set('pay1', { ...payment, method: 'bank_qr', status: 'refunded' });
    const deps = { store, clock: { now: () => NOW } };
    const notifications = new MemoryNotificationStore();
    const notice = {
      notify: { store: notifications, push: new MemoryPushSender(), users: new MemoryUserDirectory(), clock: { now: () => NOW } },
      payments: { getPayment: async (id: string) => store.payments.get(id) ?? null },
    };
    const waiting: Refund = { ...refund('awaiting_account'), method: 'bank_transfer', confirmBy: '2026-10-21T10:00:00.000Z' };
    store.refunds.set('r1', waiting);
    const doc = refundToFirestore(waiting);

    await handleRefundWrite('r1', undefined, doc, deps, notice);
    // A retried trigger: #138's dedupe by refund id keeps one row.
    await handleRefundWrite('r1', undefined, doc, deps, notice);
    // The candidate written by lookupRefundAccount, then the choice: not a new wait.
    await handleRefundWrite('r1', doc, { ...doc, updatedAt: doc.updatedAt }, deps, notice);
    await handleRefundWrite('r1', doc, refundToFirestore({ ...waiting, status: 'pending' }), deps, notice);
    const rows = notifications.rowsOf('c1');
    assert.deepEqual(rows.map((r) => [r.type, r.target]), [['refund_account_needed', '/me/payments']]);
    // The row refresh still ran (the store's refund still waits).
    assert.equal(store.rows.get('c1/pay1')?.status, 'refund_account_needed');

    // Without notice deps (older wiring) only the row refreshes.
    assert.equal(await handleRefundWrite('r1', undefined, doc, deps), 'written');
  });
});
