import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createBookingWorld, newDraft, transferOf, type BookingWorld } from './support/booking_world.js';
import { createPayment } from '../src/create_payment.js';
import { assertPaymentPayer, checkPayment, handleTransferNotification } from '../src/handle_transfer.js';
import { runPaymentSweeps } from '../src/payment_sweeps.js';
import { DomainError, type ErrorCode } from '../src/errors.js';
import { verifyPaymentLedgerInvariant, type Payment } from '../src/escrow.js';

const PRICE = 1_000_000;

const refusedWith = (code: ErrorCode) => (e: unknown) => e instanceof DomainError && e.code === code;

/** A draft for c1 with an open bank QR payment. */
async function openCheckout(world: BookingWorld) {
  const draft = await newDraft(world);
  const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
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

async function received(world: BookingWorld, id: string) {
  return (await world.store.getLedgerEntriesForPayment(id)).filter((e) => e.type === 'payment_received');
}

const eventsOf = (world: BookingWorld, bookingId: string) => world.store.events.filter((e) => e.bookingId === bookingId);

describe('handleTransferNotification', () => {
  it('exact transfer pays and moves the draft to requested', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);
    world.clock.advanceMinutes(3);

    const n = transferOf(world, { content: code, amount: PRICE });
    const res = await handleTransferNotification(world.deps, n);

    assert.deepEqual(res, { outcome: 'paid', paymentId });
    const p = await payment(world, paymentId);
    assert.equal(p.status, 'paid');
    assert.equal(p.escrowStatus, 'held');
    assert.equal(p.receivedAmount, PRICE);
    assert.equal(p.paidAt, '2026-10-10T10:03:00.000Z');

    const booking = await world.store.getBooking(draft.id);
    assert.equal(booking?.status, 'requested');
    assert.equal(booking?.escrowStatus, 'held');
    assert.equal(booking?.depositPaidAt, '2026-10-10T10:03:00.000Z');
    assert.ok(booking?.acceptDeadline, 'accept deadline set');
    assert.equal(eventsOf(world, draft.id).length, 1);
    assert.equal(eventsOf(world, draft.id)[0]?.status, 'requested');

    const entries = await received(world, paymentId);
    assert.equal(entries.length, 1);
    assert.equal(entries[0]?.amount, PRICE);
    assert.equal(world.store.refunds.size, 0);
    assert.equal(await balanced(world, paymentId), true);

    const record = await world.store.getTransferRecord(`fake_${n.txnId}`);
    assert.equal(record?.outcome, 'paid');
    assert.equal(record?.paymentId, paymentId);
    assert.equal(record?.txnId, n.txnId);
    assert.equal(record?.raw, n.raw);
  });

  it('over-transfer pays and refunds only the excess', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);

    const n = transferOf(world, { content: code, amount: PRICE + 50_000 });
    const res = await handleTransferNotification(world.deps, n);

    assert.equal(res.outcome, 'paid_with_refund');
    const p = await payment(world, paymentId);
    assert.equal(p.status, 'paid');
    assert.equal(p.receivedAmount, PRICE);
    assert.equal((await world.store.getBooking(draft.id))?.status, 'requested');
    const refunds = await world.store.getRefundsForPayment(paymentId);
    assert.equal(refunds.length, 1);
    assert.equal(refunds[0]?.amount, 50_000);
    assert.equal(refunds[0]?.reason, 'overpaid_excess');
    assert.equal(refunds[0]?.status, 'done');
    assert.equal(refunds[0]?.providerRef?.startsWith('fake_refund_'), true);
    assert.deepEqual([...world.gateway.issuedRefunds.values()], [50_000]);
    assert.equal(await balanced(world, paymentId), true);
  });

  it('under-transfer keeps created, then a top-up pays', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);

    const first = await handleTransferNotification(world.deps, transferOf(world, { content: code, amount: 400_000 }));
    assert.deepEqual(first, { outcome: 'partial', paymentId });
    let p = await payment(world, paymentId);
    assert.equal(p.status, 'created');
    assert.equal(p.receivedAmount, 400_000);
    assert.equal((await world.store.getBooking(draft.id))?.status, 'draft');
    assert.equal(eventsOf(world, draft.id).length, 0);
    assert.equal(await balanced(world, paymentId), true);

    world.clock.advanceMinutes(5);
    const second = await handleTransferNotification(world.deps, transferOf(world, { content: code, amount: 600_000 }));

    assert.deepEqual(second, { outcome: 'paid', paymentId });
    p = await payment(world, paymentId);
    assert.equal(p.status, 'paid');
    assert.equal(p.receivedAmount, PRICE);
    assert.equal((await world.store.getBooking(draft.id))?.status, 'requested');
    assert.equal(eventsOf(world, draft.id).length, 1);
    assert.equal((await received(world, paymentId)).length, 2);
    assert.equal(world.store.refunds.size, 0, 'nothing refunded');
    assert.equal(await balanced(world, paymentId), true);
  });

  it('a top-up past the amount pays and refunds only the excess', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);

    await handleTransferNotification(world.deps, transferOf(world, { content: code, amount: 400_000 }));
    const res = await handleTransferNotification(world.deps, transferOf(world, { content: code, amount: 700_000 }));

    assert.equal(res.outcome, 'paid_with_refund');
    assert.equal((await payment(world, paymentId)).status, 'paid');
    assert.equal(eventsOf(world, draft.id).length, 1);
    const refunds = await world.store.getRefundsForPayment(paymentId);
    assert.deepEqual(
      refunds.map((r) => [r.amount, r.reason]),
      [[100_000, 'overpaid_excess']],
    );
    assert.equal(await balanced(world, paymentId), true);
  });

  it('content variations still match', async () => {
    const variants = (code: string) => {
      const bare = code.replace(' ', '');
      return [
        `${bare.toLowerCase()} chuyen tien`,
        `CK ${bare.slice(0, 2)}-${bare.slice(2)}`,
        `${code} den Minh Tri`,
        `MBVCB.12345678.${bare}.CT tu 0123456789`,
        `  ${code.toLowerCase()}  `,
      ];
    };
    for (let i = 0; i < 5; i++) {
      const world = createBookingWorld();
      const { draft, paymentId, code } = await openCheckout(world);
      const content = variants(code)[i] ?? '';

      const res = await handleTransferNotification(world.deps, transferOf(world, { content, amount: PRICE }));

      assert.deepEqual(res, { outcome: 'paid', paymentId }, content);
      assert.equal((await world.store.getBooking(draft.id))?.status, 'requested', content);
    }
  });

  it('unmatched content is stored as needs_review and changes nothing else', async () => {
    for (const content of ['CHUYEN TIEN', '', 'PB 222222 tien chup anh', 'PBXYZ', '🙂 pb']) {
      const world = createBookingWorld();
      const { draft, paymentId } = await openCheckout(world);

      const n = transferOf(world, { content, amount: PRICE });
      const res = await handleTransferNotification(world.deps, n);

      assert.deepEqual(res, { outcome: 'needs_review' }, content);
      const record = await world.store.getTransferRecord(`fake_${n.txnId}`);
      assert.equal(record?.outcome, 'needs_review');
      assert.equal(record?.paymentId, undefined);
      assert.equal(record?.raw, n.raw);
      assert.equal(record?.receivedAt, n.receivedAt);
      const p = await payment(world, paymentId);
      assert.equal(p.status, 'created');
      assert.equal(p.receivedAmount, 0);
      assert.equal(world.store.ledgerEntries.size, 0);
      assert.equal(world.store.refunds.size, 0);
      assert.equal((await world.store.getBooking(draft.id))?.status, 'draft');
    }
  });

  it('the same txnId twice is a duplicate', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);

    // A part payment arrives by webhook twice, then the reconciliation job finds it again.
    const part = transferOf(world, { content: code, amount: 400_000 });
    assert.equal((await handleTransferNotification(world.deps, part)).outcome, 'partial');
    assert.deepEqual(await handleTransferNotification(world.deps, part), { outcome: 'duplicate', paymentId });
    world.gateway.pushTransfer(paymentId, part);
    world.clock.advanceMinutes(4);
    const sweep = await runPaymentSweeps(world.deps);
    assert.equal(sweep.reconciled, 0);
    assert.equal((await payment(world, paymentId)).receivedAmount, 400_000);
    assert.equal((await received(world, paymentId)).length, 1);

    // The over-paying top-up arrives twice too.
    const topUp = transferOf(world, { content: code, amount: 620_000 });
    assert.equal((await handleTransferNotification(world.deps, topUp)).outcome, 'paid_with_refund');
    assert.deepEqual(await handleTransferNotification(world.deps, topUp), { outcome: 'duplicate', paymentId });

    assert.equal((await received(world, paymentId)).length, 2);
    assert.equal(eventsOf(world, draft.id).length, 1);
    assert.equal(world.store.refunds.size, 1, 'one refund at most');
    assert.equal(world.gateway.refundCalls.length, 1);
    assert.equal(await balanced(world, paymentId), true);
  });

  it('a transfer after expiresAt is refunded while status is still created', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);
    world.clock.advanceMinutes(15); // exactly expiresAt, no sweep yet

    const res = await handleTransferNotification(world.deps, transferOf(world, { content: code, amount: PRICE }));

    assert.deepEqual(res, { outcome: 'refunded', paymentId });
    const p = await payment(world, paymentId);
    assert.equal(p.status, 'created');
    assert.equal(p.receivedAmount, 0);
    assert.equal((await world.store.getBooking(draft.id))?.status, 'draft');
    const refunds = await world.store.getRefundsForPayment(paymentId);
    assert.deepEqual(
      refunds.map((r) => [r.amount, r.reason, r.status]),
      [[PRICE, 'late_transfer', 'done']],
    );
    assert.equal(await balanced(world, paymentId), true);
  });

  it('paying the old QR after a new one is refunded and the booking is paid once', async () => {
    const world = createBookingWorld();
    const { draft, paymentId: oldId, code: oldCode } = await openCheckout(world);
    const fresh = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    // The old QR is paid first: refunded, the new QR stays valid.
    const late = await handleTransferNotification(world.deps, transferOf(world, { content: oldCode, amount: PRICE }));
    assert.deepEqual(late, { outcome: 'refunded', paymentId: oldId });
    assert.equal((await world.store.getBooking(draft.id))?.status, 'draft');
    assert.equal((await payment(world, fresh.paymentId)).status, 'created');

    const paid = await handleTransferNotification(
      world.deps,
      transferOf(world, { content: fresh.checkout.transferCode, amount: PRICE }),
    );
    assert.deepEqual(paid, { outcome: 'paid', paymentId: fresh.paymentId });

    // The old QR is paid again after the booking is paid.
    const again = await handleTransferNotification(world.deps, transferOf(world, { content: oldCode, amount: PRICE }));
    assert.deepEqual(again, { outcome: 'refunded', paymentId: oldId });

    assert.equal((await world.store.getBooking(draft.id))?.status, 'requested');
    assert.equal(eventsOf(world, draft.id).length, 1);
    const old = await payment(world, oldId);
    assert.equal(old.status, 'expired');
    assert.deepEqual(
      (await world.store.getRefundsForPayment(oldId)).map((r) => [r.amount, r.reason]),
      [
        [PRICE, 'late_transfer'],
        [PRICE, 'late_transfer'],
      ],
    );
    assert.equal(world.store.refunds.size, 2);
    assert.equal(await balanced(world, oldId), true);
    assert.equal(await balanced(world, fresh.paymentId), true);
  });

  it('a second transfer to a paid payment is refunded as extra_transfer', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);
    await handleTransferNotification(world.deps, transferOf(world, { content: code, amount: PRICE }));

    const res = await handleTransferNotification(world.deps, transferOf(world, { content: code, amount: PRICE }));

    assert.deepEqual(res, { outcome: 'refunded', paymentId });
    assert.equal((await payment(world, paymentId)).status, 'paid');
    assert.deepEqual(
      (await world.store.getRefundsForPayment(paymentId)).map((r) => [r.amount, r.reason]),
      [[PRICE, 'extra_transfer']],
    );
    assert.equal(eventsOf(world, draft.id).length, 1);
    assert.equal(await balanced(world, paymentId), true);
  });

  it('a paid transfer for a deleted draft is refunded in full', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);
    await world.store.deleteBooking(draft.id);

    const res = await handleTransferNotification(world.deps, transferOf(world, { content: code, amount: PRICE }));

    assert.deepEqual(res, { outcome: 'refunded', paymentId });
    const p = await payment(world, paymentId);
    assert.equal(p.status, 'refunded');
    assert.equal(p.escrowStatus, 'refunded');
    const refunds = await world.store.getRefundsForPayment(paymentId);
    assert.deepEqual(
      refunds.map((r) => [r.amount, r.percent, r.reason, r.status]),
      [[PRICE, 100, 'late_payment_draft_expired', 'done']],
    );
    assert.equal(world.store.events.length, 0);
    assert.equal(await balanced(world, paymentId), true);
  });

  it('an over-transfer for a deleted draft refunds everything received', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);
    await world.store.deleteBooking(draft.id);

    const res = await handleTransferNotification(world.deps, transferOf(world, { content: code, amount: PRICE + 30_000 }));

    assert.equal(res.outcome, 'refunded');
    const refunds = await world.store.getRefundsForPayment(paymentId);
    assert.equal(
      refunds.reduce((s, r) => s + r.amount, 0),
      PRICE + 30_000,
    );
    assert.equal((await payment(world, paymentId)).status, 'refunded');
    assert.equal(await balanced(world, paymentId), true);
  });

  it('a transfer received before a payment was created never matches it', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);

    const n = transferOf(world, { content: code, amount: PRICE, receivedAt: '2026-10-10T09:59:59.000Z' });
    const res = await handleTransferNotification(world.deps, n);

    assert.deepEqual(res, { outcome: 'needs_review' });
    assert.equal((await payment(world, paymentId)).receivedAmount, 0);
    assert.equal((await world.store.getBooking(draft.id))?.status, 'draft');
    assert.equal(world.store.ledgerEntries.size, 0);
  });

  it('a refund that throws stays pending with attempts 1 and the next refund still goes out', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);
    await world.store.deleteBooking(draft.id);
    world.gateway.refundThrowCount = 1;

    // Two refunds: the excess, then the late-path full refund.
    const res = await handleTransferNotification(world.deps, transferOf(world, { content: code, amount: PRICE + 30_000 }));

    assert.deepEqual(res, { outcome: 'refunded', paymentId });
    const refunds = await world.store.getRefundsForPayment(paymentId);
    assert.deepEqual(
      refunds.map((r) => [r.amount, r.reason, r.status, r.manual, r.attempts]),
      [
        [30_000, 'overpaid_excess', 'pending', false, 1],
        [PRICE, 'late_payment_draft_expired', 'done', false, 1],
      ],
    );
    assert.equal(world.gateway.refundCalls.length, 2);
    assert.equal(await balanced(world, paymentId), true);
  });
});

describe('checkPayment', () => {
  it('checkPayment asks the gateway and pays when it reports a transfer', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);

    const before = await checkPayment(world.deps, { bookingId: draft.id, customerId: 'c1' });
    assert.equal(before.paid, false);
    assert.equal(before.booking?.status, 'draft');

    world.gateway.pushTransfer(paymentId, transferOf(world, { content: code, amount: PRICE }));
    const after = await checkPayment(world.deps, { bookingId: draft.id, customerId: 'c1' });

    assert.equal(after.paid, true);
    assert.equal(after.booking?.status, 'requested');
    assert.equal((await payment(world, paymentId)).status, 'paid');

    // Asking again changes nothing.
    const again = await checkPayment(world.deps, { bookingId: draft.id, customerId: 'c1' });
    assert.equal(again.paid, true);
    assert.equal(eventsOf(world, draft.id).length, 1);
  });

  it('a draft without a checkout is not paid', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);

    const res = await checkPayment(world.deps, { bookingId: draft.id, customerId: 'c1' });

    assert.equal(res.paid, false);
  });

  it('checkPayment of another customer\'s booking is permission_denied', async () => {
    const world = createBookingWorld();
    const { draft } = await openCheckout(world);

    await assert.rejects(
      checkPayment(world.deps, { bookingId: draft.id, customerId: 'c2' }),
      refusedWith('permission_denied'),
    );
    await assert.rejects(
      checkPayment(world.deps, { bookingId: 'b_missing', customerId: 'c1' }),
      refusedWith('not_found'),
    );
  });

  it('after a revoke a transfer for the draft is refunded provider_not_accepting and the draft stays', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);
    world.clock.advanceMinutes(3);

    // Photographer stops accepting orders (e.g. revoked or turned off)
    world.providers.set('p1', { verified: false, onboardingComplete: true });

    const n = transferOf(world, { content: code, amount: PRICE });
    const res = await handleTransferNotification(world.deps, n);

    assert.deepEqual(res, { outcome: 'refunded', paymentId });

    // Payment is refunded 100%
    const p = await payment(world, paymentId);
    assert.equal(p.status, 'refunded');

    const refunds = await world.store.getRefundsForPayment(paymentId);
    assert.equal(refunds.length, 1);
    assert.equal(refunds[0]?.amount, PRICE);
    assert.equal(refunds[0]?.reason, 'provider_not_accepting');

    // Booking remains a draft
    const booking = await world.store.getBooking(draft.id);
    assert.equal(booking?.status, 'draft');
  });

  it('a transfer for a draft of an accepting provider still moves it to requested', async () => {
    const world = createBookingWorld();
    const { draft, paymentId, code } = await openCheckout(world);
    world.clock.advanceMinutes(3);

    const n = transferOf(world, { content: code, amount: PRICE });
    const res = await handleTransferNotification(world.deps, n);

    assert.deepEqual(res, { outcome: 'paid', paymentId });
    const booking = await world.store.getBooking(draft.id);
    assert.equal(booking?.status, 'requested');
  });
});

describe('assertPaymentPayer', () => {
  it('returns the payer\'s payment and refuses anyone else', async () => {
    const world = createBookingWorld();
    const { paymentId } = await openCheckout(world);

    assert.equal((await assertPaymentPayer(world.deps, paymentId, 'c1')).id, paymentId);
    await assert.rejects(assertPaymentPayer(world.deps, paymentId, 'c2'), refusedWith('permission_denied'));
    await assert.rejects(assertPaymentPayer(world.deps, 'p_missing', 'c1'), refusedWith('not_found'));
  });
});
