import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import {
  MemoryBookingStore,
  MemoryEarningsStore,
  MemoryPayoutStore,
  type EarningItem,
  type Payment,
  type Payout,
} from '@photobooking/domain';
import { paymentFromFirestore, paymentToFirestore } from '../../src/infra/booking_firestore.js';
import {
  earningItemFromFirestore,
  earningItemToFirestore,
  earningsSummaryToFirestore,
} from '../../src/infra/earnings_firestore.js';
import { accountFromFirestore, accountToFirestore, payoutFromFirestore, payoutToFirestore } from '../../src/infra/payout_firestore.js';
import { handlePaymentWrite } from '../../src/triggers/payment_write.js';
import { handlePayoutWrite } from '../../src/triggers/payout_write.js';

const T = '2026-10-10T08:00:00.000Z';
const payment = (over: Partial<Payment> = {}): Payment => ({
  id: 'pay1',
  subjectType: 'booking',
  subjectId: 'b1',
  payerId: 'c1',
  payeeId: 'p1',
  provider: 'fake',
  amount: 300_000,
  status: 'paid',
  escrowStatus: 'released',
  idempotencyKey: 'k1',
  createdAt: T,
  updatedAt: T,
  ...over,
});

describe('Firestore mapping for payments, payouts and earnings', () => {
  it('payment mapping keeps dispute and payoutId', () => {
    const p = payment({ escrowStatus: 'disputed', dispute: { reason: 'Ảnh giao thiếu', openedAt: T }, payoutId: 'po1' });
    const doc = paymentToFirestore(p);
    assert.ok(doc.dispute.openedAt instanceof Timestamp);
    assert.equal(doc.payoutId, 'po1');
    assert.deepEqual(paymentFromFirestore('pay1', doc)?.dispute, { reason: 'Ảnh giao thiếu', openedAt: T });
    assert.equal(paymentFromFirestore('pay1', doc)?.payoutId, 'po1');
  });

  it('absent dispute and payoutId map to null both ways', () => {
    const doc = paymentToFirestore(payment());
    assert.equal(doc.dispute, null);
    assert.equal(doc.payoutId, null);
    const back = paymentFromFirestore('pay1', { ...doc, dispute: undefined, payoutId: undefined });
    assert.equal(back?.dispute, null);
    assert.equal(back?.payoutId, null);
  });

  it('earnings mapping round-trips an item', () => {
    const item: EarningItem = {
      id: 'pay1',
      payeeId: 'p1',
      subjectType: 'booking',
      subjectId: 'b1',
      counterpartName: 'Lan',
      subjectLabel: 'Chân dung 2 giờ',
      day: '2026-10-09',
      amount: 450_000,
      state: 'paid_out',
      holdReason: null,
      paidOutAt: T,
      updatedAt: T,
    };
    const doc = earningItemToFirestore(item);
    assert.ok(doc.paidOutAt instanceof Timestamp);
    assert.deepEqual(earningItemFromFirestore('pay1', doc), item);
    const held = { ...item, state: 'disputed' as const, holdReason: 'dispute', paidOutAt: null };
    assert.deepEqual(earningItemFromFirestore('pay1', earningItemToFirestore(held)), held);
  });

  it('the summary document carries Timestamps and the last payout', () => {
    const doc = earningsSummaryToFirestore({
      payeeId: 'p1', heldAmount: 1, soonAmount: 2, receivedAmount: 3,
      lastPayout: { id: 'po1', status: 'paid', at: T }, updatedAt: T,
    });
    assert.ok(doc.lastPayout.at instanceof Timestamp);
    assert.equal('payeeId' in doc, false);
  });

  it('payout and account documents round-trip and the account holds only ciphertext', () => {
    const p: Payout = {
      id: 'po1', payeeId: 'p1', accountId: 'a1', amount: 300_000, status: 'paid',
      items: [{ paymentId: 'pay1', amount: 300_000 }], reference: 'FAKE-po1', createdBy: 'admin1',
      createdAt: T, updatedAt: T, processingAt: T, paidAt: T,
    };
    assert.deepEqual(payoutFromFirestore('po1', payoutToFirestore(p)), p);
    const a = { id: 'a1', userId: 'p1', bankCode: 'VCB', accountNumberEnc: 'v1:a:b:c', accountLast4: '6789', holderName: 'AN', active: true, createdAt: T };
    assert.deepEqual(accountFromFirestore('a1', accountToFirestore(a)), a);
    assert.deepEqual(Object.keys(accountToFirestore(a)).filter((k) => /number/i.test(k)), ['accountNumberEnc']);
  });
});

describe('earnings triggers', () => {
  function world() {
    const booking = new MemoryBookingStore();
    const payouts = new MemoryPayoutStore(booking);
    const earnings = new MemoryEarningsStore(booking, payouts, new Map([['c1', 'Lan']]));
    const deps = { store: earnings, clock: { now: () => new Date('2026-10-11T00:00:00.000Z') } };
    return { booking, payouts, earnings, deps };
  }
  const withBooking = (w: ReturnType<typeof world>, p: Payment) => {
    w.booking.payments.set(p.id, p);
    w.booking.bookings.set('b1', {
      id: 'b1', customerId: 'c1', photographerId: 'p1', serviceId: 's1',
      serviceSnapshot: { name: 'Chân dung', price: 1_000_000, durationMinutes: 120 },
      day: '2026-10-09', start: '08:00', end: '10:00', place: { name: 'Hồ Tây' }, status: 'completed',
      deposit: 300_000, remaining: 700_000, version: 1, createdAt: T, updatedAt: T,
    } as never);
  };

  it('a released payment appears in Sắp nhận', async () => {
    const w = world();
    withBooking(w, payment());
    assert.equal(await handlePaymentWrite('pay1', undefined, { payeeId: 'p1' }, w.deps), 'p1');
    assert.equal(w.earnings.summaries.get('p1')?.soonAmount, 300_000);
  });

  it('a write without a payee is skipped; a delete uses the before payee', async () => {
    const w = world();
    assert.equal(await handlePaymentWrite('pay1', undefined, {}, w.deps), null);
    withBooking(w, payment());
    await handlePaymentWrite('pay1', undefined, { payeeId: 'p1' }, w.deps);
    w.booking.payments.delete('pay1');
    assert.equal(await handlePaymentWrite('pay1', { payeeId: 'p1' }, undefined, w.deps), 'p1');
    assert.equal(w.earnings.summaries.get('p1')?.soonAmount, 0);
  });

  it('platform ticket money has no earnings page (payee platform is skipped)', async () => {
    const w = world();
    assert.equal(await handlePaymentWrite('pay1', undefined, { payeeId: 'platform' }, w.deps), null);
    assert.equal(w.earnings.summaries.has('platform'), false);
  });

  it('a payout write refreshes every payment in it and takes paidOutAt from the payout', async () => {
    const w = world();
    withBooking(w, payment({ escrowStatus: 'paid_out', payoutId: 'po1', updatedAt: '2026-10-10T09:00:00.000Z' }));
    const po: Payout = {
      id: 'po1', payeeId: 'p1', accountId: 'a1', amount: 300_000, status: 'paid',
      items: [{ paymentId: 'pay1', amount: 300_000 }], createdBy: 'admin1',
      createdAt: T, updatedAt: '2026-10-10T10:00:00.000Z', paidAt: '2026-10-10T10:00:00.000Z',
    };
    w.payouts.seedPayout(po);
    assert.equal(await handlePayoutWrite('po1', undefined, { payeeId: 'p1', items: po.items }, w.deps), 'p1');
    assert.equal(w.earnings.items.get('p1/pay1')?.paidOutAt, '2026-10-10T10:00:00.000Z');
    assert.equal(w.earnings.summaries.get('p1')?.receivedAmount, 300_000);
    assert.equal(w.earnings.summaries.get('p1')?.lastPayout?.status, 'paid');
    // A failed payout: the payment left the batch (in `before` only) and is released again.
    w.booking.payments.set('pay1', payment({ payoutId: null }));
    w.payouts.seedPayout({ ...po, status: 'failed', updatedAt: '2026-10-10T11:00:00.000Z' });
    await handlePayoutWrite('po1', { payeeId: 'p1', items: po.items }, { payeeId: 'p1', items: [] }, w.deps);
    assert.equal(w.earnings.summaries.get('p1')?.soonAmount, 300_000);
    assert.equal(w.earnings.summaries.get('p1')?.receivedAmount, 0);
    assert.equal(await handlePayoutWrite('po1', undefined, {}, w.deps), null);
  });
});
