import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createBookingWorld } from './support/booking_world.js';
import { createBookingDraft } from '../src/create_booking.js';
import { createDeposit } from '../src/create_deposit.js';
import { confirmFakePayment, handlePaymentNotification, checkDeposit } from '../src/handle_payment.js';
import { verifyPaymentLedgerInvariant } from '../src/escrow.js';

describe('Task 4: createDeposit and payment handling', () => {
  it('creates deposit payment intent and transitions on fake confirm', async () => {
    const world = createBookingWorld();
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
    });

    const depositResult = await createDeposit(world.deps, {
      bookingId: draft.id,
      customerId: 'c1',
      provider: 'fake',
    });

    assert.ok(depositResult.payUrl);
    assert.equal(depositResult.provider, 'fake');

    // Confirm fake payment
    const confirmResult = await confirmFakePayment(world.deps, {
      paymentId: depositResult.paymentId,
      customerId: 'c1',
    });

    assert.equal(confirmResult.refunded, false);
    assert.equal(confirmResult.booking?.status, 'requested');
    assert.equal(confirmResult.booking?.depositPaidAt, world.clock.now().toISOString());
    assert.equal(confirmResult.payment.status, 'paid');
    assert.equal(confirmResult.payment.escrowStatus, 'held');

    // Ledger invariant
    const refunds = await world.store.getRefundsForPayment(depositResult.paymentId);
    const entries = await world.store.getLedgerEntriesForPayment(depositResult.paymentId);
    assert.equal(verifyPaymentLedgerInvariant(confirmResult.payment, refunds, entries), true);
  });

  it('Review Focus 3a: duplicate payment confirmation captures nothing twice', async () => {
    const world = createBookingWorld();
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
    });

    const depositResult = await createDeposit(world.deps, {
      bookingId: draft.id,
      customerId: 'c1',
      provider: 'fake',
    });

    const res1 = await confirmFakePayment(world.deps, {
      paymentId: depositResult.paymentId,
      customerId: 'c1',
    });
    assert.equal(res1.booking?.status, 'requested');

    // Second duplicate notification arrives
    const res2 = await handlePaymentNotification(world.deps, {
      paymentId: depositResult.paymentId,
    });
    assert.equal(res2.booking?.status, 'requested');

    const entries = await world.store.getLedgerEntriesForPayment(depositResult.paymentId);
    // Exactly 1 deposit_received entry, never 2
    assert.equal(entries.length, 1);
  });

  it('Review Focus 3b: late payment after draft was cleaned up is refunded in full', async () => {
    const world = createBookingWorld();
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
    });

    const depositResult = await createDeposit(world.deps, {
      bookingId: draft.id,
      customerId: 'c1',
      provider: 'fake',
    });

    // Simulate 30-minute draft cleanup: draft deleted
    await world.store.deleteBooking(draft.id);

    // Payment arrives late from gateway
    const res = await handlePaymentNotification(world.deps, {
      paymentId: depositResult.paymentId,
    });

    assert.equal(res.refunded, true);
    assert.equal(res.booking, null);
    assert.equal(res.payment.status, 'refunded');
    assert.equal(res.payment.escrowStatus, 'refunded');
    assert.equal(res.refund?.amount, 300_000);
    assert.equal(res.refund?.percent, 100);

    // Balanced ledger entries
    const refunds = await world.store.getRefundsForPayment(depositResult.paymentId);
    const entries = await world.store.getLedgerEntriesForPayment(depositResult.paymentId);
    assert.equal(verifyPaymentLedgerInvariant(res.payment, refunds, entries), true);
  });

  it('checkDeposit verifies gateway status if redirect returns early', async () => {
    const world = createBookingWorld();
    const draft = await createBookingDraft(world.deps, {
      customerId: 'c1',
      photographerId: 'p1',
      serviceId: 'srv_01',
      day: '2026-10-15',
      start: '14:00',
      place: { name: 'Nhà thờ Lớn' },
    });

    const depositResult = await createDeposit(world.deps, {
      bookingId: draft.id,
      customerId: 'c1',
      provider: 'fake',
    });

    // Gateway not yet marked paid
    const check1 = await checkDeposit(world.deps, {
      bookingId: draft.id,
      customerId: 'c1',
    });
    assert.equal(check1.paid, false);

    // Gateway marks paid
    world.gateway.markPaid(depositResult.paymentId);

    const check2 = await checkDeposit(world.deps, {
      bookingId: draft.id,
      customerId: 'c1',
    });
    assert.equal(check2.paid, true);
    assert.equal(check2.booking?.status, 'requested');
  });
});
