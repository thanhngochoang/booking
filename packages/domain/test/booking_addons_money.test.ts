/** Refunds, milestones and payout lines of a booking with add-ons all run on the total (Decision 2). */
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { ServiceAddon } from '../src/addon.js';
import { milestoneAmounts } from '../src/milestones.js';
import { DEFAULT_PAYOUT_POLICY, payoutLineOf } from '../src/payout_policy.js';
import { createPayment } from '../src/create_payment.js';
import { handleTransferNotification } from '../src/handle_transfer.js';
import { transitionBooking } from '../src/transition_booking.js';
import { createBookingWorld, newDraft, transferOf, withAddons, type BookingWorld } from './support/booking_world.js';

const T = '2026-10-01T00:00:00.000Z';
const mk = (id: string, over: Partial<ServiceAddon>): ServiceAddon => ({
  id, providerId: 'p1', kind: 'makeup', name: id, price: 800_000, unit: 'per_person', maxQty: 4,
  serviceIds: [], active: true, createdAt: T, updatedAt: T, ...over,
});

const TOTAL = 3_400_000; // portrait 1.500.000 + makeup ×2 1.600.000 + transport 300.000

function basketWorld(): BookingWorld {
  const world = withAddons(createBookingWorld(), 'p1', [
    mk('makeup', {}),
    mk('transport', { kind: 'transport', unit: 'per_booking', price: 300_000, maxQty: 1 }),
  ]);
  const srv = world.services.get('srv_01');
  assert.ok(srv);
  world.services.set('srv_01', { ...srv, price: 1_500_000 });
  return world;
}

const basket = (world: BookingWorld) =>
  newDraft(world, { addons: [{ addonId: 'makeup', qty: 2 }, { addonId: 'transport', qty: 1 }], pickup: { name: '12 Lê Lợi' } });

async function paid(world: BookingWorld) {
  const draft = await basket(world);
  const { paymentId, checkout } = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
  await handleTransferNotification(world.deps, transferOf(world, { content: checkout.transferCode, amount: checkout.amount }));
  await transitionBooking(world.deps, { bookingId: draft.id, action: 'accept', actorId: 'p1' });
  return { draft, paymentId, checkout };
}

describe('booking with add-ons: money follows the total', () => {
  it('createPayment charges the total', async () => {
    const world = basketWorld();
    const draft = await basket(world);
    assert.equal(draft.deposit, TOTAL);
    const { paymentId, checkout } = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
    assert.equal(checkout.amount, TOTAL);
    assert.equal((await world.store.getPayment(paymentId))?.amount, TOTAL);
  });

  it('cancel ≥ 48 h before refunds 100% of the total', async () => {
    const world = basketWorld();
    const { draft, paymentId } = await paid(world);
    world.clock.setTime(new Date('2026-10-12T10:00:00.000Z')); // 3 days before
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c1' });
    const refunds = [...world.store.refunds.values()].filter((r) => r.paymentId === paymentId && r.fromEscrow);
    assert.deepEqual(refunds.map((r) => r.amount), [TOTAL]);
  });

  it('refund at 24–48 h is 50% of the total', async () => {
    const world = basketWorld();
    const { draft, paymentId } = await paid(world);
    world.clock.setTime(new Date('2026-10-13T10:00:00.000Z')); // 45 h before the shoot (2026-10-15 14:00 VN)
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c1' });
    const refunds = [...world.store.refunds.values()].filter((r) => r.paymentId === paymentId && r.fromEscrow);
    assert.deepEqual(refunds.map((r) => r.amount), [1_700_000]);
  });

  it('milestone amounts of a booking with add-ons sum to the total', async () => {
    const world = basketWorld();
    const { paymentId } = await paid(world);
    const payment = await world.store.getPayment(paymentId);
    assert.ok(payment);
    const m = milestoneAmounts(payment.amount);
    assert.deepEqual(m, { shoot: 1_700_000, delivery: 1_700_000 });
    assert.equal(m.shoot + m.delivery, TOTAL);
  });

  it('payout line gross for the shoot milestone is half the total', () => {
    assert.equal(payoutLineOf(milestoneAmounts(TOTAL).shoot, 'individual', DEFAULT_PAYOUT_POLICY).gross, 1_700_000);
  });
});
