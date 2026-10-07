import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createBookingWorld, newDraft, transferOf, type BookingWorld } from './support/booking_world.js';
import { createPayment } from '../src/create_payment.js';
import { handleTransferNotification } from '../src/handle_transfer.js';
import { runPaymentSweeps } from '../src/payment_sweeps.js';
import { verifyPaymentLedgerInvariant, type Payment } from '../src/escrow.js';

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

    assert.deepEqual(res, { reconciled: 1, expired: 0, refunded: 0 });
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

    assert.deepEqual(res, { reconciled: 0, expired: 0, refunded: 0 });
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
    assert.deepEqual(early, { reconciled: 0, expired: 0, refunded: 0 });

    world.clock.advanceMinutes(1); // 15 minutes: expiresAt reached
    const res = await runPaymentSweeps(world.deps);

    assert.deepEqual(res, { reconciled: 0, expired: 2, refunded: 1 });
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

    assert.deepEqual(first, { reconciled: 0, expired: 1, refunded: 1 });
    assert.deepEqual(second, { reconciled: 0, expired: 0, refunded: 0 });
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

    assert.deepEqual(res, { reconciled: 1, expired: 1, refunded: 0 });
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

    assert.deepEqual(res, { reconciled: 0, expired: 0, refunded: 0 });
    assert.equal(world.gateway.queryTransfersCalls.length, 0);
    assert.equal((await payment(world, 'legacy')).status, 'created');
  });
});
