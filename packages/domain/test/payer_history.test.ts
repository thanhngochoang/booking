import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { Payment, Refund } from '../src/escrow.js';
import { MemoryPayerHistoryStore } from '../src/memory_payer_history_store.js';
import type { PaymentMilestone } from '../src/milestones.js';
import {
  EMPTY_PAYER_SUBJECT,
  destinationLabel,
  payerRowOf,
  payerTotals,
  refreshPayerHistory,
  refreshPayerHistoryOfSubject,
  type PayerPaymentRow,
  type PayerSubjectView,
} from '../src/payer_history.js';

const T0 = '2026-10-10T08:00:00.000Z';
const NOW = new Date('2026-10-20T10:00:00.000Z');
const AMOUNT = 1_500_000;

const payment = (over: Partial<Payment> = {}): Payment => ({
  id: 'pay1',
  subjectType: 'booking',
  subjectId: 'b1',
  payerId: 'c1',
  payeeId: 'p1',
  provider: 'fake',
  amount: AMOUNT,
  status: 'paid',
  escrowStatus: 'held',
  idempotencyKey: 'k1',
  method: 'bank_qr',
  receivedAmount: AMOUNT,
  paidAt: T0,
  createdAt: T0,
  updatedAt: T0,
  ...over,
});

/** A QR payment nobody finished paying. */
const unpaid = (over: Partial<Payment> = {}): Payment =>
  payment({ status: 'created', receivedAmount: 0, paidAt: undefined, ...over });

const VCB = { bankCode: 'VCB', bankName: 'Vietcombank', accountNumberEnc: 'enc:secret', accountLast4: '6789', holderName: 'NGUYEN THANH HA' };

const refund = (over: Partial<Refund> = {}): Refund => ({
  id: 'r1',
  paymentId: 'pay1',
  subjectType: 'booking',
  amount: AMOUNT,
  percent: 100,
  status: 'done',
  manual: false,
  fromEscrow: true,
  method: 'bank_transfer',
  destination: { ...VCB, source: 'payer' },
  attempts: 1,
  providerRef: 'prov_ref_1',
  createdAt: '2026-10-12T08:00:00.000Z',
  updatedAt: '2026-10-12T09:00:00.000Z',
  ...over,
});

const subject = (over: Partial<PayerSubjectView> = {}): PayerSubjectView => ({
  ...EMPTY_PAYER_SUBJECT,
  photographerName: 'Minh Trí',
  serviceName: 'Chân dung 2 giờ',
  day: '2026-10-12',
  ...over,
});
const NO_BOOKING = { photographerName: null, serviceName: null };

const rowOf = (p: Payment, refunds: readonly Refund[] = [], s: PayerSubjectView = subject()) => payerRowOf(p, refunds, s, NOW);
const must = (r: PayerPaymentRow | null): PayerPaymentRow => {
  assert.ok(r, 'expected a row');
  return r;
};

describe('payerRowOf', () => {
  it('no row before money arrives', () => {
    assert.equal(rowOf(unpaid()), null);
  });

  it('no row for an expired empty QR', () => {
    assert.equal(rowOf(unpaid({ status: 'expired', escrowStatus: 'refunded' })), null);
  });

  it('paid booking, escrow held → held, heldAmount = amount, open', () => {
    const r = must(rowOf(payment()));
    assert.equal(r.status, 'held');
    assert.equal(r.heldAmount, AMOUNT);
    assert.equal(r.amount, AMOUNT);
    assert.equal(r.open, true);
    assert.deepEqual([r.refundingAmount, r.refundedAmount], [0, 0]);
    assert.deepEqual(
      [r.paymentId, r.payerId, r.subjectType, r.subjectId, r.photographerName, r.serviceName, r.eventTitle, r.quantity, r.areaLabel, r.day, r.method, r.createdAt, r.paidAt, r.updatedAt],
      ['pay1', 'c1', 'booking', 'b1', 'Minh Trí', 'Chân dung 2 giờ', null, null, null, '2026-10-12', 'bank_qr', T0, T0, NOW.toISOString()],
    );
  });

  it('a wallet payment with no receivedAmount (gateway paid) still has a row', () => {
    const r = must(rowOf(payment({ method: 'momo', receivedAmount: undefined })));
    assert.equal(r.status, 'held');
    assert.equal(r.method, 'momo');
  });

  it('after the shoot milestone is released only the delivery milestone is held', () => {
    const ms: PaymentMilestone[] = [
      { kind: 'shoot', amount: 750_000, status: 'released', releaseAfter: null, releasedAt: T0, payoutId: null },
      { kind: 'delivery', amount: 750_000, status: 'held', releaseAfter: null, releasedAt: null, payoutId: null },
    ];
    const r = must(rowOf(payment({ milestones: ms })));
    assert.equal(r.status, 'held');
    assert.equal(r.heldAmount, 750_000);
  });

  it('disputed → disputed, open', () => {
    const r = must(rowOf(payment({ escrowStatus: 'disputed' })));
    assert.equal(r.status, 'disputed');
    assert.equal(r.open, true);
    assert.equal(r.heldAmount, AMOUNT);
  });

  it('released → released, heldAmount 0, not open', () => {
    for (const escrowStatus of ['released', 'paid_out'] as const) {
      const r = must(rowOf(payment({ escrowStatus })));
      assert.equal(r.status, 'released');
      assert.equal(r.heldAmount, 0);
      assert.equal(r.open, false);
    }
  });

  it('50% cancel then release → partially_refunded, refundedAmount = half', () => {
    const half = refund({ amount: AMOUNT / 2, percent: 50 });
    const cancelled = payment({ status: 'partially_refunded', escrowStatus: 'partially_refunded', refundedAmount: AMOUNT / 2 });
    // Before the release: half is still held for the photographer.
    const before = must(rowOf(cancelled, [half], subject({ cancelled: true })));
    assert.equal(before.status, 'held');
    assert.equal(before.heldAmount, AMOUNT / 2);
    assert.equal(before.cancelled, true);
    // After the release: "Đã hoàn một phần", nothing held.
    const r = must(rowOf({ ...cancelled, escrowStatus: 'released' }, [half], subject({ cancelled: true })));
    assert.equal(r.status, 'partially_refunded');
    assert.equal(r.refundedAmount, AMOUNT / 2);
    assert.equal(r.heldAmount, 0);
    assert.equal(r.open, false);
  });

  it('full refund done → refunded', () => {
    const r = must(rowOf(payment({ status: 'refunded', escrowStatus: 'refunded', refundedAmount: AMOUNT }), [refund()]));
    assert.equal(r.status, 'refunded');
    assert.deepEqual([r.heldAmount, r.refundingAmount, r.refundedAmount, r.open], [0, 0, AMOUNT, false]);
  });

  it('refund pending → refunding, refundingAmount', () => {
    const r = must(rowOf(payment({ status: 'refunded', escrowStatus: 'refunded' }), [refund({ status: 'pending' })]));
    assert.equal(r.status, 'refunding');
    assert.equal(r.refundingAmount, AMOUNT);
    assert.equal(r.refundedAmount, 0);
    assert.equal(r.open, true);
  });

  it('refund failed → refunding', () => {
    const r = must(rowOf(payment({ status: 'refunded', escrowStatus: 'refunded' }), [refund({ status: 'failed', manual: true })]));
    assert.equal(r.status, 'refunding');
    assert.equal(r.refundingAmount, AMOUNT);
  });

  it('refund awaiting_account → refund_account_needed, open', () => {
    const waiting = refund({ status: 'awaiting_account', destination: null, attempts: 0 });
    const r = must(rowOf(payment({ status: 'refunded', escrowStatus: 'refunded' }), [waiting, refund({ id: 'r0', status: 'pending', amount: 1 })]));
    assert.equal(r.status, 'refund_account_needed');
    assert.equal(r.open, true);
    assert.equal(r.refunds.find((x) => x.refundId === 'r1')?.destinationLabel, null);
  });

  it('a 50% cancel waiting for its refund still counts the held half', () => {
    const r = must(rowOf(
      payment({ status: 'partially_refunded', escrowStatus: 'partially_refunded' }),
      [refund({ amount: AMOUNT / 2, percent: 50, status: 'pending' })],
    ));
    assert.equal(r.status, 'refunding');
    assert.deepEqual([r.heldAmount, r.refundingAmount], [AMOUNT / 2, AMOUNT / 2]);
  });

  it('overpaid: paid row with an excess refund line, status held', () => {
    const excess = refund({ id: 'rx', amount: 200_000, fromEscrow: false, reason: 'overpaid_excess' });
    const r = must(rowOf(payment({ refundedAmount: 200_000 }), [excess]));
    assert.equal(r.status, 'held');
    assert.equal(r.amount, AMOUNT + 200_000);
    assert.equal(r.heldAmount, AMOUNT);
    assert.equal(r.refundedAmount, 200_000);
    assert.deepEqual(r.refunds.map((x) => [x.refundId, x.kind, x.status, x.amount]), [['rx', 'excess', 'done', 200_000]]);
  });

  it('late transfer to an expired QR, refunded → refunded', () => {
    const late = refund({ id: 'rl', amount: 400_000, fromEscrow: false, reason: 'late_transfer' });
    const p = unpaid({ status: 'expired', escrowStatus: 'refunded', refundedAmount: 400_000 });
    const r = must(rowOf(p, [late]));
    assert.equal(r.status, 'refunded');
    assert.equal(r.amount, 400_000);
    assert.deepEqual([r.heldAmount, r.refundedAmount, r.open, r.paidAt], [0, 400_000, false, null]);
    // A late transfer before the sweep marked the QR expired reads the same.
    assert.equal(must(rowOf(unpaid({ refundedAmount: 400_000 }), [late])).status, 'refunded');
  });

  it('an under-paid QR: held while open, refunded once it expired', () => {
    const open = must(rowOf(unpaid({ receivedAmount: 500_000 })));
    assert.deepEqual([open.status, open.amount, open.heldAmount, open.open], ['held', 500_000, 500_000, true]);
    const back = refund({ id: 'ru', amount: 500_000, fromEscrow: false, reason: 'underpaid_expired' });
    const expired = must(rowOf(unpaid({ status: 'expired', escrowStatus: 'refunded', receivedAmount: 500_000 }), [back]));
    assert.deepEqual([expired.status, expired.amount, expired.heldAmount, expired.refundedAmount], ['refunded', 500_000, 0, 500_000]);
  });

  it('bank refund destination label is "Vietcombank •••• 6789"; wallet refund label is null', () => {
    assert.equal(destinationLabel(VCB), 'Vietcombank •••• 6789');
    assert.equal(destinationLabel(null), null);
    assert.equal(destinationLabel(undefined), null);
    const bank = must(rowOf(payment({ status: 'refunded', escrowStatus: 'refunded' }), [refund()]));
    assert.equal(bank.refunds[0]?.destinationLabel, 'Vietcombank •••• 6789');
    assert.equal(bank.refunds[0]?.kind, 'policy');
    assert.equal(bank.refunds[0]?.doneAt, '2026-10-12T09:00:00.000Z');
    const wallet = must(rowOf(
      payment({ method: 'zalopay', status: 'refunded', escrowStatus: 'refunded' }),
      [refund({ method: 'gateway', destination: null, status: 'pending' })],
    ));
    assert.equal(wallet.refunds[0]?.destinationLabel, null);
    assert.equal(wallet.refunds[0]?.method, 'gateway');
    assert.equal(wallet.refunds[0]?.doneAt, null);
  });

  it('the row never copies payer, candidate, instructions or provider refs', () => {
    const p = payment({
      payer: VCB,
      providerRef: 'prov_pay',
      instructions: { kind: 'bank_qr', qrPayload: 'x' } as unknown as Payment['instructions'],
    });
    const r = must(rowOf(p, [refund({ status: 'pending' })]));
    const json = JSON.stringify(r);
    for (const secret of ['enc:secret', 'prov_pay', 'prov_ref_1', 'qrPayload', 'payer"', 'candidate', 'accountNumberEnc', 'holderName']) {
      assert.equal(json.includes(secret), false, secret);
    }
  });

  it('instant_request subject renders title and searching', () => {
    const r = must(rowOf(
      payment({ subjectType: 'instant_request', subjectId: 'ir1', payeeId: '', method: 'momo' }),
      [],
      subject({ ...NO_BOOKING, areaLabel: 'Quận 1, TP.HCM', day: null, searching: true }),
    ));
    assert.deepEqual(
      [r.subjectType, r.areaLabel, r.photographerName, r.searching, r.status, r.heldAmount, r.toPlatform],
      ['instant_request', 'Quận 1, TP.HCM', null, true, 'held', AMOUNT, false],
    );
  });

  it('a ticket keeps its event id; platform money reads as paid to the platform', () => {
    const ticket = must(rowOf(
      payment({ subjectType: 'event_registration', subjectId: 'reg1', eventId: 'ev1', payeeId: 'platform', escrowStatus: 'released' }),
      [],
      subject({ ...NO_BOOKING, eventTitle: 'Photo walk phố cổ', quantity: 2, eventId: 'ev1' }),
    ));
    assert.deepEqual([ticket.eventId, ticket.eventTitle, ticket.quantity, ticket.toPlatform, ticket.status], ['ev1', 'Photo walk phố cổ', 2, true, 'released']);
    const fee = must(rowOf(payment({ subjectType: 'verification_fee', subjectId: 'p9', payerId: 'p9', payeeId: 'platform', escrowStatus: 'released' }), [], EMPTY_PAYER_SUBJECT));
    assert.deepEqual([fee.status, fee.open, fee.toPlatform, fee.photographerName, fee.eventTitle, fee.areaLabel], ['released', false, true, null, null, null]);
  });
});

describe('payerTotals', () => {
  it('payerTotals sums held and refunding of open rows', () => {
    const rows = [
      must(rowOf(payment({ id: 'a' }))),
      must(rowOf(payment({ id: 'b', status: 'refunded', escrowStatus: 'refunded' }), [refund({ paymentId: 'b', status: 'pending', amount: 700_000 })])),
      must(rowOf(payment({ id: 'c', escrowStatus: 'released' }))),
      must(rowOf(payment({ id: 'd', status: 'refunded', escrowStatus: 'refunded' }), [refund({ paymentId: 'd' })])),
    ];
    assert.deepEqual(payerTotals(rows), { held: AMOUNT, refunding: 700_000 });
    assert.deepEqual(payerTotals([]), { held: 0, refunding: 0 });
  });
});

describe('refreshPayerHistory', () => {
  const world = () => {
    const store = new MemoryPayerHistoryStore();
    return { store, deps: { store, clock: { now: () => NOW } } };
  };

  it('refreshPayerHistory writes the row and totals; deletes a row that has no money; missing payment → missing', async () => {
    const { store, deps } = world();
    store.payments.set('pay1', payment());
    store.payments.set('pay2', payment({ id: 'pay2', subjectId: 'b2', amount: 800_000, receivedAmount: 800_000 }));
    store.subjects.set('pay1', subject());
    store.subjects.set('pay2', subject({ photographerName: 'Quốc Bảo', serviceName: 'Gia đình 1 giờ' }));

    assert.equal(await refreshPayerHistory(deps, 'pay1'), 'written');
    assert.equal(await refreshPayerHistory(deps, 'pay2'), 'written');
    assert.equal(store.rows.get('c1/pay1')?.status, 'held');
    assert.deepEqual(store.totals.get('c1'), { held: AMOUNT + 800_000, refunding: 0, updatedAt: NOW.toISOString() });

    // pay2 is refunded and its refund is still on its way.
    store.payments.set('pay2', payment({ id: 'pay2', subjectId: 'b2', amount: 800_000, status: 'refunded', escrowStatus: 'refunded' }));
    store.refunds.set('r2', refund({ id: 'r2', paymentId: 'pay2', amount: 800_000, status: 'pending' }));
    assert.equal(await refreshPayerHistory(deps, 'pay2'), 'written');
    assert.deepEqual(store.totals.get('c1'), { held: AMOUNT, refunding: 800_000, updatedAt: NOW.toISOString() });
    // Replaying the same write changes nothing.
    assert.equal(await refreshPayerHistory(deps, 'pay2'), 'written');
    assert.deepEqual(store.totals.get('c1'), { held: AMOUNT, refunding: 800_000, updatedAt: NOW.toISOString() });

    // A payment that never had money loses its row (never happens with real data, Decision 2).
    store.payments.set('pay1', unpaid());
    assert.equal(await refreshPayerHistory(deps, 'pay1'), 'deleted');
    assert.equal(store.rows.has('c1/pay1'), false);
    assert.deepEqual(store.totals.get('c1'), { held: 0, refunding: 800_000, updatedAt: NOW.toISOString() });

    assert.equal(await refreshPayerHistory(deps, 'nope'), 'missing');
  });

  it('a deleted payment loses its row when its payer is known', async () => {
    const { store, deps } = world();
    store.payments.set('pay1', payment());
    await refreshPayerHistory(deps, 'pay1');
    store.payments.delete('pay1');
    assert.equal(await refreshPayerHistory(deps, 'pay1'), 'missing');
    assert.equal(store.rows.has('c1/pay1'), true);
    assert.equal(await refreshPayerHistory(deps, 'pay1', { payerId: 'c1' }), 'deleted');
    assert.equal(store.rows.has('c1/pay1'), false);
    assert.deepEqual(store.totals.get('c1'), { held: 0, refunding: 0, updatedAt: NOW.toISOString() });
  });

  it('refreshPayerHistoryOfSubject refreshes every payment of a booking whose status changed', async () => {
    const { store, deps } = world();
    store.payments.set('pay1', payment());
    store.payments.set('pay0', unpaid({ id: 'pay0', status: 'expired', escrowStatus: 'refunded' }));
    store.payments.set('payX', payment({ id: 'payX', subjectId: 'b9' }));
    store.subjects.set('pay1', subject());
    await refreshPayerHistory(deps, 'pay1');
    // A 0% late cancel: no refund, no payment write; only the booking changed.
    store.subjects.set('pay1', subject({ cancelled: true }));
    assert.equal(await refreshPayerHistoryOfSubject(deps, 'booking', 'b1'), 2);
    assert.equal(store.rows.get('c1/pay1')?.cancelled, true);
    assert.equal(store.rows.has('c1/pay0'), false);
    assert.equal(store.rows.has('c1/payX'), false);
  });

  it('the memory store refuses a read after a write, like Firestore', async () => {
    const { store } = world();
    await assert.rejects(
      store.runTransaction(async (tx) => {
        tx.deleteRow('c1', 'pay1');
        await tx.payment('pay1');
      }),
      /read after write/,
    );
  });
});
