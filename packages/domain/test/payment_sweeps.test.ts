import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createBookingWorld, newDraft, transferOf, type BookingWorld } from './support/booking_world.js';
import { createPayment } from '../src/create_payment.js';
import { handleTransferNotification } from '../src/handle_transfer.js';
import { runPaymentSweeps } from '../src/payment_sweeps.js';
import { verifyPaymentLedgerInvariant, type Payment, type Refund } from '../src/escrow.js';
import type { StudioBookingTx } from '../src/booking_ports.js';

const PRICE = 1_000_000;

async function openCheckout(world: BookingWorld, overrides: Record<string, unknown> = {}) {
  const draft = await newDraft(world, overrides);
  const customerId = (overrides.customerId as string | undefined) ?? 'c1';
  const res = await createPayment(world.deps, { bookingId: draft.id, customerId, method: 'bank_qr' });
  return { draft, paymentId: res.paymentId, code: res.checkout.transferCode };
}

async function payment(world: BookingWorld, id: string): Promise<Payment> {
  const p = await world.store.getPayment(id);
  assert.ok(p, `payment ${id}`);
  return p;
}

async function balanced(world: BookingWorld, id: string): Promise<boolean> {
  return verifyPaymentLedgerInvariant(
    await payment(world, id),
    await world.store.getRefundsForPayment(id),
    await world.store.getLedgerEntriesForPayment(id),
  );
}

describe('runPaymentSweeps', () => {
  it('reconciles created payments older than 3 minutes through queryTransfers', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);
    world.clock.advanceMinutes(1);
    world.gateway.pushTransfer(paymentId, transferOf(world, { content: code, amount: PRICE }));
    world.clock.advanceMinutes(3);

    const res = await runPaymentSweeps(world.deps);

    assert.deepEqual(res, {
      reconciled: 1, expired: 0, refunded: 0, refundsResent: 0,
      reconcileFailed: 0, expireFailed: 0, resendFailed: 0, skippedRefunds: 0,
    });
    assert.equal((await payment(world, paymentId)).status, 'paid');
    assert.equal((await world.store.getBooking(draft.id))?.status, 'requested');
    assert.equal(await balanced(world, paymentId), true);
  });

  it('skips payments younger than 3 minutes', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);
    world.gateway.pushTransfer(paymentId, transferOf(world, { content: code, amount: PRICE }));
    world.clock.advanceMinutes(2);

    const res = await runPaymentSweeps(world.deps);

    assert.deepEqual(res, {
      reconciled: 0, expired: 0, refunded: 0, refundsResent: 0,
      reconcileFailed: 0, expireFailed: 0, resendFailed: 0, skippedRefunds: 0,
    });
    assert.equal((await payment(world, paymentId)).status, 'created');
    assert.equal((await world.store.getBooking(draft.id))?.status, 'draft');
  });

  it('expires overdue payments and refunds what they received', async () => {
    const world = createBookingWorld();
    const under = await openCheckout(world);
    const nothing = await openCheckout(world, { customerId: 'c2', day: '2026-10-16' });
    await handleTransferNotification(world.deps, transferOf(world, { content: under.code, amount: 300_000 }));
    world.clock.advanceMinutes(14);

    const early = await runPaymentSweeps(world.deps);
    assert.deepEqual(early, {
      reconciled: 0, expired: 0, refunded: 0, refundsResent: 0,
      reconcileFailed: 0, expireFailed: 0, resendFailed: 0, skippedRefunds: 0,
    });

    world.clock.advanceMinutes(1); // 15 minutes: expiresAt reached
    const res = await runPaymentSweeps(world.deps);

    assert.deepEqual(res, {
      reconciled: 0, expired: 2, refunded: 1, refundsResent: 0,
      reconcileFailed: 0, expireFailed: 0, resendFailed: 0, skippedRefunds: 0,
    });
    const p = await payment(world, under.paymentId);
    assert.equal(p.status, 'expired');
    assert.equal(p.escrowStatus, 'refunded');
    const refunds = await world.store.getRefundsForPayment(under.paymentId);
    assert.deepEqual(
      refunds.map((r) => [r.amount, r.reason, r.status]),
      [[300_000, 'underpaid_expired', 'done']],
    );
    assert.equal(world.gateway.issuedRefunds.get(refunds[0]?.id ?? ''), 300_000);
    assert.equal(await balanced(world, under.paymentId), true);

    const q = await payment(world, nothing.paymentId);
    assert.equal(q.status, 'expired');
    assert.equal(q.escrowStatus, 'refunded');
    assert.equal((await world.store.getRefundsForPayment(nothing.paymentId)).length, 0);
    assert.equal(await balanced(world, nothing.paymentId), true);
    // The draft stays until its own payableUntil; the booking sweep removes it.
    assert.equal((await world.store.getBooking(under.draft.id))?.status, 'draft');
  });

  it('a second run changes nothing', async () => {
    const world = createBookingWorld();
    const { paymentId, code } = await openCheckout(world);
    const part = transferOf(world, { content: code, amount: 300_000 });
    await handleTransferNotification(world.deps, part);
    world.gateway.pushTransfer(paymentId, part);
    world.clock.advanceMinutes(16);

    const first = await runPaymentSweeps(world.deps);
    const second = await runPaymentSweeps(world.deps);

    assert.deepEqual(first, {
      reconciled: 0, expired: 1, refunded: 1, refundsResent: 0,
      reconcileFailed: 0, expireFailed: 0, resendFailed: 0, skippedRefunds: 0,
    });
    assert.deepEqual(second, {
      reconciled: 0, expired: 0, refunded: 0, refundsResent: 0,
      reconcileFailed: 0, expireFailed: 0, resendFailed: 0, skippedRefunds: 0,
    });
    assert.equal(world.store.refunds.size, 1);
    assert.equal(world.gateway.refundCalls.length, 1);
    assert.equal(await balanced(world, paymentId), true);
  });

  it('a transfer the gateway reports after expiry is refunded as late', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);
    world.clock.advanceMinutes(16);
    world.gateway.pushTransfer(paymentId, transferOf(world, { content: code, amount: PRICE }));

    const res = await runPaymentSweeps(world.deps);

    assert.deepEqual(res, {
      reconciled: 1, expired: 1, refunded: 0, refundsResent: 0,
      reconcileFailed: 0, expireFailed: 0, resendFailed: 0, skippedRefunds: 0,
    });
    assert.equal((await payment(world, paymentId)).status, 'expired');
    assert.deepEqual(
      (await world.store.getRefundsForPayment(paymentId)).map((r) => [r.amount, r.reason]),
      [[PRICE, 'late_transfer']],
    );
    assert.equal((await world.store.getBooking(draft.id))?.status, 'draft');
    assert.equal(await balanced(world, paymentId), true);
  });

  it('leaves payments without a transfer code alone', async () => {
    const world = createBookingWorld();
    const at = world.clock.now().toISOString();
    world.store.payments.set('legacy', {
      id: 'legacy',
      subjectType: 'booking',
      subjectId: 'b_legacy',
      payerId: 'c1',
      payeeId: 'p1',
      provider: 'momo',
      amount: PRICE,
      status: 'created',
      escrowStatus: 'held',
      idempotencyKey: 'dep_b_legacy_momo',
      createdAt: at,
      updatedAt: at,
    });
    world.clock.advanceHours(2);

    const res = await runPaymentSweeps(world.deps);

    assert.deepEqual(res, {
      reconciled: 0, expired: 0, refunded: 0, refundsResent: 0,
      reconcileFailed: 0, expireFailed: 0, resendFailed: 0, skippedRefunds: 0,
    });
    assert.equal(world.gateway.queryTransfersCalls.length, 0);
    assert.equal((await payment(world, 'legacy')).status, 'created');
  });

  it('a query that throws for one payment still reconciles the next and counts the failure', async () => {
    const world = createBookingWorld();
    const broken = await openCheckout(world);
    const fine = await openCheckout(world, { customerId: 'c2', day: '2026-10-16' });
    world.gateway.pushTransfer(broken.paymentId, transferOf(world, { content: broken.code, amount: PRICE }));
    world.gateway.pushTransfer(fine.paymentId, transferOf(world, { content: fine.code, amount: PRICE }));
    world.gateway.queryThrowIds.add(broken.paymentId);
    world.clock.advanceMinutes(4);

    const res = await runPaymentSweeps(world.deps);

    assert.deepEqual(res, {
      reconciled: 1, expired: 0, refunded: 0, refundsResent: 0,
      reconcileFailed: 1, expireFailed: 0, resendFailed: 0, skippedRefunds: 0,
    });
    assert.equal((await payment(world, broken.paymentId)).status, 'created');
    assert.equal((await payment(world, fine.paymentId)).status, 'paid');
  });

  it('an expiry whose refund dispatch throws still expires the next payment', async () => {
    const world = createBookingWorld();
    const a = await openCheckout(world);
    const b = await openCheckout(world, { customerId: 'c2', day: '2026-10-16' });
    await handleTransferNotification(world.deps, transferOf(world, { content: a.code, amount: 300_000 }));
    await handleTransferNotification(world.deps, transferOf(world, { content: b.code, amount: 200_000 }));
    world.gateway.refundThrowCount = 1;
    world.clock.advanceMinutes(16);

    const res = await runPaymentSweeps(world.deps);

    assert.deepEqual(res, {
      reconciled: 0, expired: 2, refunded: 2, refundsResent: 0,
      reconcileFailed: 0, expireFailed: 0, resendFailed: 0, skippedRefunds: 0,
    });
    assert.equal((await payment(world, a.paymentId)).status, 'expired');
    assert.equal((await payment(world, b.paymentId)).status, 'expired');
    assert.deepEqual(
      [...world.store.refunds.values()].map((r) => [r.amount, r.status, r.manual, r.attempts]),
      [
        [300_000, 'pending', false, 1],
        [200_000, 'done', false, 1],
      ],
    );
  });

  it('an expiry whose transaction throws is counted and the next payment still expires', async () => {
    const world = createBookingWorld();
    const a = await openCheckout(world);
    const b = await openCheckout(world, { customerId: 'c2', day: '2026-10-16' });
    world.clock.advanceMinutes(16);
    const store = world.store;
    const original = store.runTransaction.bind(store);
    let calls = 0;
    store.runTransaction = async <T>(fn: (tx: StudioBookingTx) => Promise<T>): Promise<T> => {
      calls += 1;
      if (calls === 1) throw new Error('simulated store outage');
      return original(fn);
    };

    const res = await runPaymentSweeps(world.deps);

    assert.deepEqual(res, {
      reconciled: 0, expired: 1, refunded: 0, refundsResent: 0,
      reconcileFailed: 0, expireFailed: 1, resendFailed: 0, skippedRefunds: 0,
    });
    assert.equal((await payment(world, a.paymentId)).status, 'created');
    assert.equal((await payment(world, b.paymentId)).status, 'expired');
  });

  it('the payment clock re-sends a pending refund after 10 minutes under the same id and marks it done', async () => {
    const world = createBookingWorld();
    const a = await openCheckout(world);
    await handleTransferNotification(world.deps, transferOf(world, { content: a.code, amount: 300_000 }));
    world.gateway.refundThrowCount = 1;
    world.clock.advanceMinutes(16);

    // Initial expiry runs, gateway throws once, left pending
    await runPaymentSweeps(world.deps);
    const [r0] = await world.store.getRefundsForPayment(a.paymentId);
    assert.ok(r0);
    assert.equal(r0.status, 'pending');
    assert.equal(r0.attempts, 1);

    // +9 min -> not re-sent yet
    world.clock.advanceMinutes(9);
    const res9 = await runPaymentSweeps(world.deps);
    assert.equal(res9.refundsResent, 0);
    assert.equal(world.gateway.refundCalls.length, 1);

    // +1 min (total 10 min) -> re-sent
    world.clock.advanceMinutes(1);
    const res10 = await runPaymentSweeps(world.deps);
    assert.equal(res10.refundsResent, 1);
    assert.deepEqual(world.gateway.refundCalls, [r0.id, r0.id]);
    assert.equal(world.gateway.issuedRefunds.size, 1);
    const [rDone] = await world.store.getRefundsForPayment(a.paymentId);
    assert.equal(rDone?.status, 'done');
    assert.equal(rDone?.attempts, 2);
  });

  it('given SettlementDeps, the clock re-sends through the booking settler\'s deps', async () => {
    const world = createBookingWorld();
    const a = await openCheckout(world);
    await handleTransferNotification(world.deps, transferOf(world, { content: a.code, amount: 300_000 }));
    world.gateway.refundThrowCount = 1;
    world.clock.advanceMinutes(16);
    await runPaymentSweeps(world.settlement);
    const [r0] = await world.store.getRefundsForPayment(a.paymentId);
    assert.equal(r0?.status, 'pending');

    world.clock.advanceMinutes(10);
    const res = await runPaymentSweeps(world.settlement);
    assert.equal(res.refundsResent, 1);
    const [r1] = await world.store.getRefundsForPayment(a.paymentId);
    assert.equal(r1?.status, 'done');
    assert.deepEqual(world.gateway.refundCalls, [r0?.id, r0?.id]);
  });

  it('given SettlementDeps without a booking settler, the re-send step is skipped', async () => {
    const world = createBookingWorld();
    const res = await runPaymentSweeps({ ...world.settlement, subjects: {} });
    assert.deepEqual([res.refundsResent, res.resendFailed, res.skippedRefunds], [0, 0, 0]);
  });

  it('awaiting_account and failed refunds are never re-sent', async () => {
    const world = createBookingWorld();
    const a = await openCheckout(world);
    await handleTransferNotification(world.deps, transferOf(world, { content: a.code, amount: 300_000, payer: null }));
    world.clock.advanceMinutes(16);
    await runPaymentSweeps(world.deps);

    // Wait 20 minutes
    world.clock.advanceMinutes(20);
    const callsBefore = world.gateway.refundCalls.length;
    const res = await runPaymentSweeps(world.deps);
    assert.equal(res.refundsResent, 0);
    assert.equal(world.gateway.refundCalls.length, callsBefore);
  });

  it('a refund that keeps throwing is re-sent until it goes to staff', async () => {
    const world = createBookingWorld();
    const a = await openCheckout(world);
    await handleTransferNotification(world.deps, transferOf(world, { content: a.code, amount: 300_000 }));
    world.gateway.refundThrowCount = 99; // keeps throwing
    world.clock.advanceMinutes(16);

    // Call 1 at expiry (attempts = 1)
    await runPaymentSweeps(world.deps);

    // Runs 2..5 (attempts reach 2, 3, 4, 5)
    for (let i = 2; i <= 5; i++) {
      world.clock.advanceMinutes(10);
      const sweep = await runPaymentSweeps(world.deps);
      assert.equal(sweep.refundsResent, 1);
      const [cur] = await world.store.getRefundsForPayment(a.paymentId);
      assert.equal(cur?.status, 'pending');
      assert.equal(cur?.attempts, i);
      assert.equal(cur?.manual, false);
    }

    // Call 6 (attempts reaches 6 -> failed, manual: true, failureReason: gateway_unavailable)
    world.clock.advanceMinutes(10);
    const sweep6 = await runPaymentSweeps(world.deps);
    assert.equal(sweep6.refundsResent, 1);
    const [rfFinal] = await world.store.getRefundsForPayment(a.paymentId);
    assert.equal(rfFinal?.status, 'failed');
    assert.equal(rfFinal?.manual, true);
    assert.equal(rfFinal?.attempts, 6);
    assert.equal(rfFinal?.failureReason, 'gateway_unavailable');

    // No more calls
    world.clock.advanceMinutes(10);
    const sweep7 = await runPaymentSweeps(world.deps);
    assert.equal(sweep7.refundsResent, 0);
  });

  it('the re-send racing an inline dispatch pays once and ends done', async () => {
    const world = createBookingWorld();
    const a = await openCheckout(world);
    await handleTransferNotification(world.deps, transferOf(world, { content: a.code, amount: 300_000 }));
    world.gateway.refundThrowCount = 1;
    world.clock.advanceMinutes(16);
    await runPaymentSweeps(world.deps);

    const [pending] = await world.store.getRefundsForPayment(a.paymentId);
    assert.ok(pending);
    assert.equal(pending.status, 'pending');

    world.clock.advanceMinutes(10);
    // Race dispatchRefunds and runPaymentSweeps
    await Promise.all([
      runPaymentSweeps(world.deps),
      runPaymentSweeps(world.deps),
    ]);

    assert.equal(world.gateway.issuedRefunds.size, 1);
    const [after] = await world.store.getRefundsForPayment(a.paymentId);
    assert.equal(after?.status, 'done');
  });

  it('a ticket refund goes to refundSubjects.event_registration', async () => {
    const world = createBookingWorld();
    let handledTicketRefundId: string | null = null;
    const subjects = {
      event_registration: {
        async resend(r: Refund) {
          handledTicketRefundId = r.id;
          return { ...r, status: 'done' as const };
        },
        async record(r: Refund) {
          return r;
        },
      },
    };

    const now = world.clock.now();
    const tMinus15 = new Date(now.getTime() - 15 * 60_000).toISOString();
    world.store.refunds.set('rf_tkt', {
      id: 'rf_tkt',
      paymentId: 'pay_tkt',
      subjectType: 'event_registration',
      amount: 100_000,
      percent: 100,
      status: 'pending',
      manual: false,
      fromEscrow: true,
      method: 'gateway',
      attempts: 1,
      lastAttemptAt: tMinus15,
      createdAt: tMinus15,
      updatedAt: tMinus15,
    });

    const res = await runPaymentSweeps(world.deps, { refundSubjects: subjects });
    assert.equal(res.refundsResent, 1);
    assert.equal(handledTicketRefundId, 'rf_tkt');
  });

  it('a refund of a subject without a handler is skipped and counted', async () => {
    const world = createBookingWorld();
    const now = world.clock.now();
    const tMinus15 = new Date(now.getTime() - 15 * 60_000).toISOString();
    world.store.refunds.set('rf_orphan', {
      id: 'rf_orphan',
      paymentId: 'pay_orphan',
      subjectType: 'event_registration',
      amount: 100_000,
      percent: 100,
      status: 'pending',
      manual: false,
      fromEscrow: true,
      method: 'gateway',
      attempts: 1,
      lastAttemptAt: tMinus15,
      createdAt: tMinus15,
      updatedAt: tMinus15,
    });

    const res = await runPaymentSweeps(world.deps); // no refundSubjects provided
    assert.equal(res.refundsResent, 0);
    assert.equal(res.skippedRefunds, 1);
  });

  it('one failing handler does not stop the batch', async () => {
    const world = createBookingWorld();
    const now = world.clock.now();
    const tMinus15 = new Date(now.getTime() - 15 * 60_000).toISOString();

    world.store.refunds.set('rf_fail', {
      id: 'rf_fail',
      paymentId: 'pay_fail',
      subjectType: 'event_registration',
      amount: 50_000,
      percent: 100,
      status: 'pending',
      manual: false,
      fromEscrow: true,
      method: 'gateway',
      attempts: 1,
      lastAttemptAt: tMinus15,
      createdAt: tMinus15,
      updatedAt: tMinus15,
    });

    const a = await openCheckout(world);
    await handleTransferNotification(world.deps, transferOf(world, { content: a.code, amount: 300_000 }));
    world.gateway.refundThrowCount = 1;
    world.clock.advanceMinutes(16);
    await runPaymentSweeps(world.deps); // creates pending booking refund

    world.clock.advanceMinutes(10);
    const subjects = {
      event_registration: {
        async resend() {
          throw new Error('ticket resend crashed');
        },
        async record(r: Refund) {
          return r;
        },
      },
    };

    const res = await runPaymentSweeps(world.deps, { refundSubjects: subjects });
    assert.equal(res.resendFailed, 1);
    assert.equal(res.refundsResent, 1); // the booking refund was still re-sent
  });
});
