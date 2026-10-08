import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { describe, it } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import {
  DEFAULT_PAYOUT_POLICY,
  MemoryBookingStore,
  MemoryEarningsStore,
  MemoryPayoutStore,
  type EarningItem,
  type Payment,
  type Payout,
  type PayoutAccount,
} from '@photobooking/domain';
import { paymentFromFirestore, paymentToFirestore } from '../../src/infra/booking_firestore.js';
import {
  earningItemFromFirestore,
  earningItemToFirestore,
  earningsSummaryToFirestore,
  milestonesOfDocs,
} from '../../src/infra/earnings_firestore.js';
import {
  accountFromFirestore,
  accountToFirestore,
  accountViewToFirestore,
  payoutFromFirestore,
  payoutToFirestore,
} from '../../src/infra/payout_firestore.js';
import { handlePaymentWrite } from '../../src/triggers/payment_write.js';
import { handlePayoutWrite } from '../../src/triggers/payout_write.js';

const T = '2026-10-10T08:00:00.000Z';
const EARLY = '2026-09-01T00:00:00.000Z';
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

  it('item round-trips fee, tax, net, rates, estimated and milestones', () => {
    const item: EarningItem = {
      id: 'pay1',
      payeeId: 'p1',
      subjectType: 'booking',
      subjectId: 'b1',
      counterpartName: 'Lan',
      subjectLabel: 'Chân dung 2 giờ',
      day: '2026-10-09',
      amount: 450_000,
      platformFee: 0,
      taxWithheld: 31_500,
      netAmount: 418_500,
      feeRateBp: 0,
      taxRateBp: 700,
      estimated: false,
      milestonesDone: 1,
      milestonesTotal: 2,
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

  it('old items without the fields read net = amount, estimated true', () => {
    const old = {
      payeeId: 'p1', subjectType: 'booking', subjectId: 'b1', counterpartName: 'Lan', subjectLabel: 'Chân dung 2 giờ',
      day: '2026-10-09', amount: 450_000, state: 'released', holdReason: null, paidOutAt: null, updatedAt: Timestamp.fromDate(new Date(T)),
    };
    const i = earningItemFromFirestore('pay1', old);
    assert.equal(i.platformFee, 0);
    assert.equal(i.taxWithheld, 0);
    assert.equal(i.netAmount, 450_000);
    assert.equal(i.feeRateBp, 0);
    assert.equal(i.taxRateBp, 0);
    assert.equal(i.estimated, true);
    assert.equal(i.milestonesDone, null);
    assert.equal(i.milestonesTotal, null);
  });

  it('milestones count the released documents; no documents is null', () => {
    assert.equal(milestonesOfDocs([]), null);
    assert.deepEqual(milestonesOfDocs([{ status: 'released' }, { status: 'held' }]), { done: 1, total: 2 });
    assert.deepEqual(milestonesOfDocs([{ status: 'released' }, { status: 'released' }]), { done: 2, total: 2 });
    assert.deepEqual(milestonesOfDocs([{}]), { done: 0, total: 1 });
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
      items: [{ paymentId: 'pay1', amount: 300_000, fee: 0, tax: 21_000, net: 279_000 }], reference: 'FAKE-po1', createdBy: 'admin1',
      platformFee: 0, taxWithheld: 21_000, amountNet: 279_000, feeRateBp: 0, taxRateBp: 700, firstPayout: true,
      approvedBy: 's1', approvedAt: T,
      createdAt: T, updatedAt: T, processingAt: T, paidAt: T,
    };
    assert.deepEqual(payoutFromFirestore('po1', payoutToFirestore(p)), p);
    const a: PayoutAccount = {
      id: 'a1', userId: 'p1', bankCode: 'VCB', accountNumberEnc: 'v1:a:b:c', accountLast4: '6789', holderName: 'AN', active: true, createdAt: T,
      nameStatus: 'matched', activeFrom: T,
    };
    assert.deepEqual(accountFromFirestore('a1', accountToFirestore(a)), a);
    assert.deepEqual(Object.keys(accountToFirestore(a)).filter((k) => /number/i.test(k)), ['accountNumberEnc']);
  });
});

describe('payout and account mapping (S06 tax, approval, 72 hours)', () => {
  const taxed: Payout = {
    id: 'po2', payeeId: 'p1', accountId: 'a2', amount: 750_000, status: 'needs_approval',
    items: [
      { paymentId: 'pay1', amount: 450_000, fee: 0, tax: 31_500, net: 418_500 },
      { paymentId: 'pay2', amount: 300_000, fee: 0, tax: 21_000, net: 279_000 },
    ],
    platformFee: 0, taxWithheld: 52_500, amountNet: 697_500, feeRateBp: 0, taxRateBp: 700, firstPayout: true,
    createdBy: 'system:createPayouts', createdAt: T, updatedAt: T,
  };

  it('payout round-trips money fields and needs_approval', () => {
    const doc = payoutToFirestore(taxed);
    assert.equal(doc.status, 'needs_approval');
    assert.equal(doc.approvedBy, null);
    assert.equal(doc.approvedAt, null);
    // The gateway idempotency key is the payout id; only the fake gateway exists (owner ruling 2).
    assert.equal(doc.idempotencyKey, 'po2');
    assert.equal(doc.provider, 'fake');
    assert.deepEqual(payoutFromFirestore('po2', doc), taxed);
    const approved: Payout = { ...taxed, status: 'pending', approvedBy: 's1', approvedAt: T };
    assert.ok(payoutToFirestore(approved).approvedAt instanceof Timestamp);
    assert.deepEqual(payoutFromFirestore('po2', payoutToFirestore(approved)), approved);
    const held: Payout = { ...taxed, status: 'on_hold', holdReason: 'repeated_failure' };
    assert.deepEqual(payoutFromFirestore('po2', payoutToFirestore(held)), held);
  });

  it('an old payout reads fee 0, tax 0, net = amount, firstPayout false', () => {
    const ts = Timestamp.fromDate(new Date(T));
    const old = {
      payeeId: 'p1', accountId: 'a1', amount: 450_000, status: 'paid', items: [{ paymentId: 'pay1', amount: 450_000 }],
      reference: 'FAKE-po1', failureReason: null, holdReason: null, createdBy: 'admin1',
      createdAt: ts, updatedAt: ts, processingAt: ts, paidAt: ts,
    };
    const p = payoutFromFirestore('po1', old);
    assert.deepEqual(p?.items, [{ paymentId: 'pay1', amount: 450_000, fee: 0, tax: 0, net: 450_000 }]);
    assert.equal(p?.platformFee, 0);
    assert.equal(p?.taxWithheld, 0);
    assert.equal(p?.amountNet, 450_000);
    assert.equal(p?.feeRateBp, 0);
    assert.equal(p?.taxRateBp, 0);
    assert.equal(p?.firstPayout, false);
    assert.equal(p?.approvedBy, undefined);
    assert.equal(p?.approvedAt, undefined);
  });

  it('an old account reads nameStatus matched and activeFrom = createdAt', () => {
    const old = {
      userId: 'p1', bankCode: 'VCB', accountNumberEnc: 'v1:a:b:c', accountLast4: '6789', holderName: 'NGUYEN VAN AN',
      active: true, createdAt: Timestamp.fromDate(new Date(EARLY)),
    };
    const a = accountFromFirestore('a1', old);
    assert.equal(a?.nameStatus, 'matched');
    assert.equal(a?.activeFrom, EARLY);
    assert.equal(accountFromFirestore('a1', { ...old, nameStatus: 'bogus' })?.nameStatus, 'matched');
    const review = accountFromFirestore('a1', accountToFirestore({ ...(a as PayoutAccount), nameStatus: 'pending_review', activeFrom: T }));
    assert.equal(review?.nameStatus, 'pending_review');
    assert.equal(review?.activeFrom, T);
  });

  it('the owner view carries nameStatus and activeFrom, never the number', () => {
    const doc = accountViewToFirestore({
      accountId: 'a2', bankCode: 'VCB', accountLast4: '6789', holderName: 'NGUYEN VAN AN', updatedAt: T,
      nameStatus: 'staff_confirmed', activeFrom: T,
    });
    assert.equal(doc.nameStatus, 'staff_confirmed');
    assert.ok(doc.activeFrom instanceof Timestamp);
    assert.deepEqual(Object.keys(doc).filter((k) => /number/i.test(k)), []);
  });

  it('the payout history queries have their composite indexes', () => {
    const json = JSON.parse(readFileSync(new URL('../../../firestore.indexes.json', import.meta.url), 'utf8')) as {
      indexes: { collectionGroup: string; queryScope: string; fields: { fieldPath: string; order: string }[] }[];
    };
    const shapes = json.indexes
      .filter((i) => i.collectionGroup === 'payouts' && i.queryScope === 'COLLECTION')
      .map((i) => i.fields.map((f) => `${f.fieldPath} ${f.order}`).join(', '));
    // lastFinishedPayouts: accountId ==, status in [paid, failed], orderBy createdAt desc.
    assert.ok(shapes.includes('accountId ASCENDING, status ASCENDING, createdAt DESCENDING'), shapes.join(' | '));
    // hasApprovedOrPaidPayout: accountId ==, status in [pending, processing], approvedBy != null.
    assert.ok(shapes.includes('accountId ASCENDING, status ASCENDING, approvedBy ASCENDING'), shapes.join(' | '));
    // The CLI's open payouts (status in, orderBy createdAt) and the earnings' latest payout.
    assert.ok(shapes.includes('status ASCENDING, createdAt ASCENDING'), shapes.join(' | '));
    assert.ok(shapes.includes('payeeId ASCENDING, createdAt DESCENDING'), shapes.join(' | '));
  });
});

describe('earnings triggers', () => {
  function world() {
    const booking = new MemoryBookingStore();
    const payouts = new MemoryPayoutStore(booking);
    const earnings = new MemoryEarningsStore(booking, payouts, new Map([['c1', 'Lan']]));
    const deps = { store: earnings, clock: { now: () => new Date('2026-10-11T00:00:00.000Z') }, policy: DEFAULT_PAYOUT_POLICY };
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
      items: [{ paymentId: 'pay1', amount: 300_000, fee: 0, tax: 21_000, net: 279_000 }], createdBy: 'admin1',
      platformFee: 0, taxWithheld: 21_000, amountNet: 279_000, feeRateBp: 0, taxRateBp: 700, firstPayout: true,
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
