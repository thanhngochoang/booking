import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createBookingWorld, newDraft, payDraft, transferOf } from './support/booking_world.js';
import { applyRefundEvent, type RefundEvent } from '../src/refund_subjects.js';
import { transitionBooking } from '../src/transition_booking.js';
import type { Refund } from '../src/escrow.js';

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
    const [refund] = await world.store.getRefundsForPayment(paymentId);
    assert.ok(refund);
    assert.equal(refund.status, 'done');

    // Event reporting failed
    const outcome = await applyRefundEvent(world.deps, {
      refundId: refund.id,
      provider: 'fake',
      status: 'failed',
    });
    assert.equal(outcome, 'refund_applied');
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
    assert.equal(outcome, 'refund_applied');
    assert.equal((await world.store.getRefund(refund.id))?.status, 'awaiting_account');
  });
});
