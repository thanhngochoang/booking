import assert from 'node:assert/strict';
import { computeDeposit, computeRefund } from '../src/booking_policy.js';
import { describe, it } from 'node:test';
import {
  HOLD_REASON_DISPUTE,
  HOLD_REASON_PAYOUT_ON_HOLD,
  earningItemOf,
  earningStateOf,
  summarizeEarnings,
} from '../src/earnings.js';
import type { Payment } from '../src/escrow.js';
import type { Payout } from '../src/payout.js';
import { runBookingSweeps } from '../src/booking_sweeps.js';
import { transitionBooking } from '../src/transition_booking.js';
import { approvePayout, createPayout, executePayout } from '../src/payout_use_cases.js';
import { DEFAULT_PAYOUT_POLICY } from '../src/payout_policy.js';
import type { ProviderType } from '../src/provider_type.js';
import { refreshEarnings } from '../src/refresh_earnings.js';
import { ADMIN, addAccount, createPayoutWorld, paidBooking } from './support/payout_world.js';
import { freezeBookingPayment } from './support/dispute_world.js';

const NOW = new Date('2026-10-20T10:00:00.000Z');
const subject = { counterpartName: 'Khách Hàng Một', label: 'Gói Chân dung', day: '2026-10-15', milestones: null };

const payment = (over: Partial<Payment> = {}): Payment => ({
  id: 'pay1',
  subjectType: 'booking',
  subjectId: 'b1',
  payerId: 'c1',
  payeeId: 'p1',
  provider: 'fake',
  amount: 300_000,
  status: 'paid',
  escrowStatus: 'held',
  idempotencyKey: 'k',
  createdAt: NOW.toISOString(),
  updatedAt: NOW.toISOString(),
  ...over,
});
const payout = (over: Partial<Payout> = {}): Payout => ({
  id: 'po1',
  payeeId: 'p1',
  accountId: 'a1',
  amount: 300_000,
  status: 'pending',
  items: [{ paymentId: 'pay1', amount: 300_000, fee: 0, tax: 21_000, net: 279_000 }],
  platformFee: 0,
  taxWithheld: 21_000,
  amountNet: 279_000,
  feeRateBp: 0,
  taxRateBp: 700,
  firstPayout: true,
  createdBy: 'admin1',
  createdAt: NOW.toISOString(),
  updatedAt: NOW.toISOString(),
  ...over,
});
const item = (p: Payment, refunded = 0, po: Payout | null = null, payeeType: ProviderType = 'individual') =>
  earningItemOf({ payment: p, refunded, subject, payout: po, payeeType, policy: DEFAULT_PAYOUT_POLICY, now: NOW });

/** The customer pays the whole price up front. */
const PAID = computeDeposit(1_000_000).deposit;

describe('earning rows', () => {
  it('held and partially refunded payments are Đang giữ with the kept amount', () => {
    assert.equal(earningStateOf(payment()), 'held');
    const row = item(payment({ escrowStatus: 'partially_refunded' }), 150_000);
    assert.equal(row?.state, 'held');
    assert.equal(row?.amount, 150_000);
    assert.equal(row?.counterpartName, 'Khách Hàng Một');
    assert.equal(row?.subjectLabel, 'Gói Chân dung');
    assert.equal(row?.day, '2026-10-15');
  });

  it('a disputed payment carries its reason', () => {
    const row = item(payment({ escrowStatus: 'disputed', dispute: { reason: 'free text', openedAt: 'x' } }));
    assert.equal(row?.state, 'disputed');
    assert.equal(row?.holdReason, HOLD_REASON_DISPUTE);
    assert.equal(JSON.stringify(row).includes('free text'), false);
  });

  it('a fully refunded payment has no row', () => {
    assert.equal(item(payment({ escrowStatus: 'refunded' }), 300_000), null);
    assert.equal(item(payment({ escrowStatus: 'held' }), 300_000), null);
    assert.equal(item(payment({ escrowStatus: 'created' as never })), null);
  });

  it('a released payment in an on_hold payout shows the hold reason', () => {
    const row = item(payment({ escrowStatus: 'released', payoutId: 'po1' }), 0, payout({ status: 'on_hold', holdReason: 'secret staff note' }));
    assert.equal(row?.state, 'released');
    assert.equal(row?.holdReason, HOLD_REASON_PAYOUT_ON_HOLD);
    assert.equal(item(payment({ escrowStatus: 'released' }))?.holdReason, null);
  });

  it('paid_out rows carry the payout date', () => {
    const row = item(
      payment({ escrowStatus: 'paid_out', payoutId: 'po1' }),
      0,
      payout({ status: 'paid', paidAt: '2026-10-18T03:00:00.000Z' }),
    );
    assert.equal(row?.state, 'paid_out');
    assert.equal(row?.paidOutAt, '2026-10-18T03:00:00.000Z');
    assert.equal(item(payment())?.paidOutAt, null);
  });

  it("a paid-out row carries the payout item's fee, tax and net (estimated false)", () => {
    // The snapshot wins over today's policy: a studio payee still shows what was withheld then.
    const po = payout({
      status: 'paid',
      paidAt: '2026-10-18T03:00:00.000Z',
      items: [{ paymentId: 'pay1', amount: 300_000, fee: 3_000, tax: 21_000, net: 276_000 }],
      feeRateBp: 100,
    });
    const row = item(payment({ escrowStatus: 'paid_out', payoutId: 'po1' }), 0, po, 'studio');
    assert.equal(row?.amount, 300_000);
    assert.equal(row?.platformFee, 3_000);
    assert.equal(row?.taxWithheld, 21_000);
    assert.equal(row?.netAmount, 276_000);
    assert.equal(row?.feeRateBp, 100);
    assert.equal(row?.taxRateBp, 700);
    assert.equal(row?.estimated, false);
  });

  it('a held row carries the policy estimate (estimated true); a studio row has tax 0', () => {
    const held = item(payment({ amount: 1_500_000 }));
    assert.equal(held?.amount, 1_500_000);
    assert.equal(held?.platformFee, 0);
    assert.equal(held?.taxWithheld, 105_000);
    assert.equal(held?.netAmount, 1_395_000);
    assert.equal(held?.taxRateBp, 700);
    assert.equal(held?.feeRateBp, 0);
    assert.equal(held?.estimated, true);
    // A released row in a payout that is not paid yet is still an estimate.
    assert.equal(item(payment({ escrowStatus: 'released', payoutId: 'po1' }), 0, payout())?.estimated, true);
    const studio = item(payment({ amount: 1_500_000 }), 0, null, 'studio');
    assert.equal(studio?.taxWithheld, 0);
    assert.equal(studio?.taxRateBp, 0);
    assert.equal(studio?.netAmount, 1_500_000);
    assert.equal(studio?.estimated, true);
  });

  it('the estimate is on the amount kept after refunds', () => {
    const row = item(payment({ escrowStatus: 'partially_refunded', amount: 1_000_000 }), 500_000);
    assert.equal(row?.amount, 500_000);
    assert.equal(row?.taxWithheld, 35_000);
    assert.equal(row?.netAmount, 465_000);
  });

  it('milestones from the subject reach the row; null when absent; refunded milestone excluded from total', () => {
    const withMilestones = earningItemOf({
      payment: payment(),
      refunded: 0,
      subject: { ...subject, milestones: { done: 1, total: 2 } },
      payout: null,
      payeeType: 'individual',
      policy: DEFAULT_PAYOUT_POLICY,
      now: NOW,
    });
    assert.equal(withMilestones?.milestonesDone, 1);
    assert.equal(withMilestones?.milestonesTotal, 2);
    assert.equal(withMilestones?.milestonesRefunded, undefined);

    const withRefunded = earningItemOf({
      payment: payment({
        amount: 1_000_000,
        status: 'partially_refunded',
        escrowStatus: 'released',
        milestones: [
          { kind: 'shoot', amount: 500_000, status: 'released', releaseAfter: null, releasedAt: NOW.toISOString(), payoutId: null },
          { kind: 'delivery', amount: 500_000, status: 'refunded', releaseAfter: null, releasedAt: null, payoutId: null },
        ],
      }),
      refunded: 500_000,
      subject,
      payout: null,
      payeeType: 'individual',
      policy: DEFAULT_PAYOUT_POLICY,
      now: NOW,
    });
    assert.equal(withRefunded?.milestonesDone, 1);
    assert.equal(withRefunded?.milestonesTotal, 1);
    assert.deepEqual(withRefunded?.milestonesRefunded, ['delivery']);

    const none = item(payment());
    assert.equal(none?.milestonesDone, null);
    assert.equal(none?.milestonesTotal, null);
  });
});

describe('earnings summary', () => {
  const rows = (...specs: Array<[Partial<Payment>, number]>) =>
    specs.flatMap(([over, amount], i) => item(payment({ id: `p${i}`, amount, ...over })) ?? []);

  it('summary adds disputed money to held', () => {
    const s = summarizeEarnings(
      'p1',
      rows([{ escrowStatus: 'held' }, 100], [{ escrowStatus: 'disputed' }, 50], [{ escrowStatus: 'released' }, 7], [{ escrowStatus: 'paid_out' }, 3]),
      null,
      NOW,
    );
    assert.deepEqual([s.heldAmount, s.soonAmount, s.receivedAmount], [150, 7, 3]);
    assert.equal(s.lastPayout, null);
  });

  it('summary counts released money in pending, processing and failed payouts as soon', () => {
    for (const status of ['pending', 'processing', 'failed'] as const) {
      const row = item(payment({ escrowStatus: 'released', payoutId: status === 'failed' ? null : 'po1' }), 0, payout({ status }));
      const s = summarizeEarnings('p1', row ? [row] : [], payout({ status }), NOW);
      assert.equal(s.soonAmount, 300_000, status);
      assert.equal(s.receivedAmount, 0);
      assert.deepEqual(s.lastPayout, { id: 'po1', status, at: NOW.toISOString() });
    }
  });

  it('summary equals the ledger sums', async () => {
    const w = createPayoutWorld(new Date('2026-10-10T10:00:00.000Z'));
    w.payoutStore.seedRole('p1', 'photographer');
    await addAccount(w);
    const a = await paidBooking(w, '2026-10-15');
    const b = await paidBooking(w, '2026-10-16');
    const c = await paidBooking(w, '2026-10-17');
    const d = await paidBooking(w, '2026-10-18');

    // A: customer cancels 30 h before the shoot, 50 % back, the kept half is released after start + 24 h.
    w.clock.setTime(new Date('2026-10-14T01:00:00.000Z'));
    await transitionBooking(w.deps, { bookingId: a.bookingId, action: 'cancel', actorId: 'c1', reason: 'Bận' });
    w.clock.setTime(new Date('2026-10-16T08:00:00.000Z'));
    assert.equal((await runBookingSweeps(w.deps)).releasedEscrows, 1);
    const batch = await createPayout(w.payoutDeps, ADMIN, 'p1');
    assert.equal(batch.amount, PAID - computeRefund(PAID, 50));
    await approvePayout(w.payoutDeps, ADMIN, batch.id);
    await executePayout(w.payoutDeps, ADMIN, batch.id);

    // B and C complete; C is disputed; B is released after the window.
    w.clock.setTime(new Date('2026-10-17T09:30:00.000Z'));
    await transitionBooking(w.deps, { bookingId: b.bookingId, action: 'complete', actorId: 'p1' });
    await transitionBooking(w.deps, { bookingId: c.bookingId, action: 'complete', actorId: 'p1' });
    w.clock.setTime(new Date('2026-10-17T10:00:00.000Z'));
    freezeBookingPayment(w.store, c.bookingId, w.clock.now());
    w.clock.setTime(new Date('2026-10-18T10:00:00.000Z'));
    await runBookingSweeps(w.deps);

    const ids = [a, b, c, d].map((x) => x.paymentId);
    const summary = await refreshEarnings(w.earningsDeps, { payeeId: 'p1', paymentIds: ids });

    const entries = [...w.store.ledgerEntries.values()];
    const sum = (f: (e: (typeof entries)[number]) => boolean): number => entries.filter(f).reduce((s, e) => s + e.amount, 0);
    const status = (id: string) => w.store.payments.get(id)?.escrowStatus;
    const heldIds = ids.filter((id) => ['held', 'partially_refunded', 'disputed'].includes(status(id) ?? ''));
    const held =
      sum((e) => heldIds.includes(e.paymentId ?? '') && (e.type === 'payment_received' || (e.type as string) === 'deposit_received')) +
      sum((e) => heldIds.includes(e.paymentId ?? '') && e.type === 'refund_issued') -
      sum((e) => heldIds.includes(e.paymentId ?? '') && e.type === 'escrow_released');
    // Soon in ledger is all escrow_released minus what was paid out
    const outgoing = ['payout_paid', 'tax_withheld', 'platform_fee'];
    const soon =
      sum((e) => e.type === 'escrow_released') +
      sum((e) => outgoing.includes(e.type));
    const received = -sum((e) => outgoing.includes(e.type));

    assert.deepEqual(
      [summary.heldAmount, summary.soonAmount, summary.receivedAmount],
      [2_500_000, 500_000, PAID - computeRefund(PAID, 50)],
    );
    assert.deepEqual([summary.heldAmount, summary.soonAmount, summary.receivedAmount], [held, soon, received]);
    assert.equal(w.earningsStore.items.get(`p1/${c.paymentId}`)?.holdReason, HOLD_REASON_DISPUTE);
  });
});

describe('instant payments (#202)', () => {
  it("an instant_request row is estimated with the payment's own fee rate", () => {
    const item = earningItemOf({
      payment: payment({ subjectType: 'instant_request', subjectId: 'ir1', amount: 690_000, feeBp: 1_000 }),
      refunded: 0,
      subject: { counterpartName: 'Lan Anh', label: 'Chụp ngay · 1 giờ', day: '2026-10-22', milestones: null },
      payout: null,
      payeeType: 'studio',
      policy: DEFAULT_PAYOUT_POLICY,
      now: NOW,
    });
    assert.deepEqual(
      [item?.subjectType, item?.amount, item?.platformFee, item?.netAmount, item?.feeRateBp],
      ['instant_request', 690_000, 69_000, 621_000, 1_000],
    );
  });

  it("a paid-out instant row reads its item's fee and the rate of that fee, not the payout's", () => {
    const po = payout({
      amount: 690_000,
      items: [{ paymentId: 'pay1', amount: 690_000, fee: 69_000, tax: 0, net: 621_000 }],
      platformFee: 69_000, taxWithheld: 0, amountNet: 621_000, feeRateBp: 0, taxRateBp: 0, status: 'paid',
    });
    const row = item(payment({ subjectType: 'instant_request', amount: 690_000, feeBp: 1_000, escrowStatus: 'paid_out', payoutId: 'po1' }), 0, po, 'studio');
    assert.deepEqual([row?.state, row?.platformFee, row?.feeRateBp, row?.estimated], ['paid_out', 69_000, 1_000, false]);
    // A booking keeps the payout's rate.
    const booking = item(payment({ escrowStatus: 'paid_out', payoutId: 'po1', amount: 690_000 }), 0, { ...po, feeRateBp: 500 }, 'studio');
    assert.equal(booking?.feeRateBp, 500);
  });
});
