import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createBookingWorld, newDraft, payDraft, transferOf } from './support/booking_world.js';
import { applyRefundEvent, bookingRefundHandler, resendPendingRefunds, type RefundEvent } from '../src/refund_subjects.js';
import { transitionBooking } from '../src/transition_booking.js';
import type { Refund } from '../src/escrow.js';
import { confirmRefundToPayer, refundAccountDepsOf } from './support/refund_account_world.js';

/** #141 (S22.04): c1 confirms the paying account for the booking's waiting cancel refund, which sends it. */
async function confirmPayer(world: ReturnType<typeof createBookingWorld>, paymentId: string): Promise<void> {
  const [waiting] = await world.store.getRefundsForPayment(paymentId);
  assert.equal(waiting?.status, 'awaiting_account');
  await confirmRefundToPayer(refundAccountDepsOf({ bookings: world.deps }), waiting?.id ?? '');
}

const must = <T>(v: T | null | undefined): T => {
  assert.ok(v);
  return v;
};

describe('refund_subjects: applyRefundEvent', () => {
  it('a refund event done moves a pending refund to done and sets depositRefundedAt once', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId } = await payDraft(world, draft.id);

    // Cancel to trigger refund
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c1', reason: 'Bận' });
    const [refund] = await world.store.getRefundsForPayment(paymentId);
    assert.ok(refund);

    // Set refund back to pending manually and clear booking depositRefundedAt to simulate pending gateway state
    await world.store.runTransaction(async (tx) => {
      await tx.addRefund({ ...refund, status: 'pending', manual: false, attempts: 1 });
      const b = await tx.getBooking(draft.id);
      assert.ok(b);
      await tx.setBooking({ ...b, depositRefundedAt: undefined });
    });

    const event: RefundEvent = {
      refundId: refund.id,
      provider: 'fake',
      status: 'done',
      providerRef: 'gw_ref_123',
    };

    const outcome = await applyRefundEvent(world.deps, event);
    assert.equal(outcome, 'refund_applied');

    const updated = await world.store.getRefund(refund.id);
    assert.equal(updated?.status, 'done');
    assert.equal(updated?.providerRef, 'gw_ref_123');

    const booking = await world.store.getBooking(draft.id);
    assert.ok(booking?.depositRefundedAt);
  });

  it('a failed refund becomes done on a later done event', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId } = await payDraft(world, draft.id);
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c1', reason: 'Bận' });
    const [refund] = await world.store.getRefundsForPayment(paymentId);
    assert.ok(refund);

    // Seed failed state in the store
    await world.store.runTransaction(async (tx) => {
      await tx.addRefund({ ...refund, status: 'failed', manual: true, attempts: 6 });
    });
    assert.equal((await world.store.getRefund(refund.id))?.status, 'failed');

    // Later done event
    const outcome = await applyRefundEvent(world.deps, {
      refundId: refund.id,
      provider: 'fake',
      status: 'done',
    });
    assert.equal(outcome, 'refund_applied');
    assert.equal((await world.store.getRefund(refund.id))?.status, 'done');
    assert.equal((await world.store.getRefund(refund.id))?.manual, false);
  });

  it('a done refund never changes on a failed event', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId } = await payDraft(world, draft.id);
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c1', reason: 'Bận' });
    await confirmPayer(world, paymentId);
    const [refund] = await world.store.getRefundsForPayment(paymentId);
    assert.ok(refund);
    assert.equal(refund.status, 'done');

    // Event reporting failed
    const outcome = await applyRefundEvent(world.deps, {
      refundId: refund.id,
      provider: 'fake',
      status: 'failed',
    });
    assert.equal(outcome, 'refund_unchanged');
    const after = await world.store.getRefund(refund.id);
    assert.equal(after?.status, 'done');
    assert.equal(after?.manual, false);
  });

  it('an unknown refund id is refund_unknown', async () => {
    const world = createBookingWorld();
    const outcome = await applyRefundEvent(world.deps, {
      refundId: 'rf_unknown',
      provider: 'fake',
      status: 'done',
    });
    assert.equal(outcome, 'refund_unknown');
  });

  it("a provider that differs from the payment's is refund_unknown", async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId } = await payDraft(world, draft.id);
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c1', reason: 'Bận' });
    const [refund] = await world.store.getRefundsForPayment(paymentId);
    assert.ok(refund);

    const outcome = await applyRefundEvent(world.deps, {
      refundId: refund.id,
      provider: 'momo', // payment is 'fake'
      status: 'done',
    });
    assert.equal(outcome, 'refund_unknown');
  });

  it('a ticket refund event is recorded by subjects.event_registration', async () => {
    const world = createBookingWorld();
    const now = world.clock.now().toISOString();

    // Seed ticket payment and refund in world.store
    world.store.payments.set('pay_tkt', {
      id: 'pay_tkt',
      subjectType: 'event_registration',
      subjectId: 'reg1',
      payerId: 'c1',
      payeeId: 'p1',
      provider: 'fake',
      amount: 100_000,
      status: 'refunded',
      escrowStatus: 'refunded',
      idempotencyKey: 'tkt_reg1_fake',
      createdAt: now,
      updatedAt: now,
    });
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
      createdAt: now,
      updatedAt: now,
    });

    let recordedNext: Refund | null = null;
    const subjects = {
      event_registration: {
        async resend(r: Refund) {
          return r;
        },
        async record(next: Refund) {
          recordedNext = next;
          return next;
        },
      },
    };

    const outcome = await applyRefundEvent(
      world.deps,
      {
        refundId: 'rf_tkt',
        provider: 'fake',
        status: 'done',
      },
      subjects,
    );

    assert.equal(outcome, 'refund_applied');
    assert.ok(recordedNext);
    assert.equal((recordedNext as Refund).status, 'done');
  });

  it('an awaiting_account refund ignores an event', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId } = await world.deps.store.getCustomerDraftForDay('c1', 'p1', '2026-10-15')
      .then(async () => {
        const { createPayment } = await import('../src/create_payment.js');
        const { handleTransferNotification } = await import('../src/handle_transfer.js');
        const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
        await handleTransferNotification(world.deps, transferOf(world, { content: res.checkout.transferCode, amount: res.checkout.amount, payer: null }));
        return res;
      });

    await transitionBooking(world.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c1', reason: 'Bận' });
    const [refund] = await world.store.getRefundsForPayment(paymentId);
    assert.ok(refund);
    assert.equal(refund.status, 'awaiting_account');

    // mergeRefundOutcome rules: awaiting_account ignores done/failed events
    const outcome = await applyRefundEvent(world.deps, {
      refundId: refund.id,
      provider: 'fake',
      status: 'done',
    });
    assert.equal(outcome, 'refund_unchanged');
    assert.equal((await world.store.getRefund(refund.id))?.status, 'awaiting_account');
  });
});

describe('refund_subjects: re-send', () => {
  /** A cancelled booking whose refund was left pending by one gateway throw. */
  async function pendingCancelRefund(world: ReturnType<typeof createBookingWorld>): Promise<Refund> {
    const draft = await newDraft(world);
    const { paymentId } = await payDraft(world, draft.id);
    world.gateway.refundThrowCount = 1;
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c1', reason: 'Bận' });
    await confirmPayer(world, paymentId);
    const [refund] = await world.store.getRefundsForPayment(paymentId);
    assert.ok(refund);
    assert.equal(refund.status, 'pending');
    return refund;
  }

  it('a pending dispute refund re-sent by bookingRefundHandler only stamps depositRefundedAt, the booking keeps its status', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId } = await payDraft(world, draft.id);
    const at = world.clock.now().toISOString();
    // S18: a completed booking whose dispute was resolved with a refund; the first send threw.
    await world.store.runTransaction(async (tx) => {
      const b = await tx.getBooking(draft.id);
      assert.ok(b);
      await tx.setBooking({ ...b, status: 'completed', completedAt: at, disputeId: 'd1', escrowStatus: 'partially_refunded' });
      await tx.addRefund({
        id: 'rf_dispute', paymentId, subjectType: 'booking', amount: 400_000, percent: 40, status: 'pending', manual: false,
        fromEscrow: true, method: 'gateway', attempts: 1, reason: 'dispute:d1', createdAt: at, updatedAt: at,
      });
    });
    const before = await world.store.getBooking(draft.id);

    const out = await bookingRefundHandler(world.deps).resend(must(await world.store.getRefund('rf_dispute')));
    assert.equal(out.status, 'done');
    const after = await world.store.getBooking(draft.id);
    assert.ok(after?.depositRefundedAt);
    assert.deepEqual({ ...after, depositRefundedAt: undefined, updatedAt: before?.updatedAt }, { ...before, depositRefundedAt: undefined });
  });

  it('a resend re-checks pending: a done or failed refund is never sent again', async () => {
    for (const settled of ['done', 'failed'] as const) {
      const world = createBookingWorld();
      const queried = await pendingCancelRefund(world);
      const calls = world.gateway.refundCalls.length;
      // Settled after the clock's query (a refund event, or staff paid it by hand).
      await world.store.runTransaction(async (tx) => {
        await tx.addRefund({ ...queried, status: settled, manual: settled === 'failed' });
      });
      const out = await bookingRefundHandler(world.deps).resend(queried);
      assert.equal(out.status, settled);
      assert.equal(world.gateway.refundCalls.length, calls, `${settled}: no gateway call`);
      assert.equal((await world.store.getRefund(queried.id))?.status, settled);
    }
  });

  it('a pending refund whose payment is gone goes to staff and leaves the queue', async () => {
    const world = createBookingWorld();
    const at = world.clock.now().toISOString();
    const orphan: Refund = {
      id: 'rf_orphan', paymentId: 'pay_missing', subjectType: 'booking', amount: 1_000, percent: 100,
      status: 'pending', manual: false, fromEscrow: false, method: 'gateway', attempts: 1,
      lastAttemptAt: at, createdAt: at, updatedAt: at,
    };
    await world.store.runTransaction(async (tx) => tx.addRefund(orphan));
    world.clock.advanceMinutes(10);
    const res = await resendPendingRefunds(world.deps);
    assert.deepEqual(res, { resent: 1, failed: 0, skipped: 0 });
    const after = await world.store.getRefund('rf_orphan');
    assert.deepEqual([after?.status, after?.manual, after?.failureReason, after?.attempts], ['failed', true, 'payment_missing', 2]);
    assert.deepEqual(world.gateway.refundCalls, []);
  });

  it('a refund skipped for an unknown subject no longer heads the queue', async () => {
    const world = createBookingWorld();
    const booking = await pendingCancelRefund(world);
    const old = new Date(world.clock.now().getTime() - 60 * 60_000).toISOString();
    const unknown: Refund = {
      id: 'rf_unknown_subject', paymentId: 'pay_x', subjectType: 'instant_request' as Refund['subjectType'],
      amount: 1_000, percent: 100, status: 'pending', manual: false, fromEscrow: false, method: 'gateway',
      attempts: 0, lastAttemptAt: old, createdAt: old, updatedAt: old,
    };
    await world.store.runTransaction(async (tx) => tx.addRefund(unknown));
    world.clock.advanceMinutes(10);

    // Limit 1: the older unknown row is first; it is skipped and stamped.
    assert.deepEqual(await resendPendingRefunds(world.deps, {}, 1), { resent: 0, failed: 0, skipped: 1 });
    const stamped = await world.store.getRefund(unknown.id);
    assert.deepEqual([stamped?.status, stamped?.attempts, stamped?.lastAttemptAt], ['pending', 1, world.clock.now().toISOString()]);

    // Next run: the booking refund is now first and is sent.
    assert.deepEqual(await resendPendingRefunds(world.deps, {}, 1), { resent: 1, failed: 0, skipped: 0 });
    assert.equal((await world.store.getRefund(booking.id))?.status, 'done');
  });
});
