import assert from 'node:assert/strict';
import test, { describe } from 'node:test';
import { createPayment } from '../src/create_payment.js';
import { verifyPaymentLedgerInvariant } from '../src/escrow.js';
import { dispatchRefund } from '../src/refunds.js';
import { bookingRefundHandler } from '../src/refund_subjects.js';
import { handleTransferNotification } from '../src/handle_transfer.js';
import { transitionBooking } from '../src/transition_booking.js';
import { createBookingWorld, newDraft, payDraft, transferOf, TEST_PAYER } from './support/booking_world.js';
import { TEST_CIPHER } from './support/test_cipher.js';

const PRICE = 1_000_000;

describe('Task 2: payer capture, refund destination and booking dispatch', () => {
  test('the first counted transfer stores the payer encrypted with bank name, last 4 and holder', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId } = await payDraft(world, draft.id);

    const payment = await world.store.getPayment(paymentId);
    assert.ok(payment);
    assert.ok(payment.payer);
    assert.equal(payment.payer.bankCode, 'VCB');
    assert.equal(payment.payer.bankName, 'Vietcombank');
    assert.equal(payment.payer.accountLast4, '3456');
    assert.equal(payment.payer.holderName, 'NGUYEN THANH HA');
    assert.equal(await TEST_CIPHER.decrypt(payment.payer.accountNumberEnc), '0071000123456');
  });

  test('a later payer does not replace the first (under then top-up from another account)', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId, checkout } = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    // Transfer 1: partial payment from VCB account
    await handleTransferNotification(
      world.deps,
      transferOf(world, {
        content: checkout.transferCode,
        amount: 400_000,
        payer: TEST_PAYER,
      }),
    );

    let payment = await world.store.getPayment(paymentId);
    assert.ok(payment?.payer);
    assert.equal(payment.payer.bankCode, 'VCB');

    // Transfer 2: top-up from TCB account
    const payer2 = {
      bankCode: 'TCB',
      accountNumber: '1903000099998888',
      name: 'TRAN VAN B',
      accountMasked: '•••• 8888',
    };
    await handleTransferNotification(
      world.deps,
      transferOf(world, {
        content: checkout.transferCode,
        amount: 600_000,
        payer: payer2,
      }),
    );

    payment = await world.store.getPayment(paymentId);
    assert.ok(payment?.payer);
    assert.equal(payment.payer.bankCode, 'VCB');
    assert.equal(payment.payer.accountLast4, '3456');
    assert.equal(await TEST_CIPHER.decrypt(payment.payer.accountNumberEnc), '0071000123456');
  });

  test('a transfer without a complete payer stores no payer', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId, checkout } = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    await handleTransferNotification(
      world.deps,
      transferOf(world, {
        content: checkout.transferCode,
        amount: PRICE,
        payer: null,
      }),
    );

    const payment = await world.store.getPayment(paymentId);
    assert.ok(payment);
    assert.ok(!payment.payer);
  });

  test("an over-transfer refunds the excess to that transfer's sender: bank_transfer, source payer, pending, done after dispatch", async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId, checkout } = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    const payer = {
      bankCode: 'TCB',
      accountNumber: '1903000099998888',
      name: 'TRAN VAN B',
    };
    await handleTransferNotification(
      world.deps,
      transferOf(world, {
        content: checkout.transferCode,
        amount: PRICE + 50_000,
        payer,
      }),
    );

    const refunds = await world.store.getRefundsForPayment(paymentId);
    assert.equal(refunds.length, 1);
    const excessRefund = refunds[0];
    assert.ok(excessRefund);
    assert.equal(excessRefund.amount, 50_000);
    assert.equal(excessRefund.method, 'bank_transfer');
    assert.equal(excessRefund.status, 'done');
    assert.ok(excessRefund.destination);
    assert.equal(excessRefund.destination.bankCode, 'TCB');
    assert.equal(excessRefund.destination.accountLast4, '8888');
    assert.equal(excessRefund.destination.source, 'payer');
    assert.equal(await TEST_CIPHER.decrypt(excessRefund.destination.accountNumberEnc), '1903000099998888');
  });

  test('a late transfer from another account is refunded to it and payment.payer is unchanged', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId } = await payDraft(world, draft.id);

    const paymentBefore = await world.store.getPayment(paymentId);
    assert.ok(paymentBefore?.payer);
    assert.equal(paymentBefore.payer.bankCode, 'VCB');

    const paymentDoc = await world.store.getPayment(paymentId);
    assert.ok(paymentDoc?.transferCode);
    const latePayer = {
      bankCode: 'TCB',
      accountNumber: '1903000099998888',
      name: 'TRAN VAN B',
    };
    await handleTransferNotification(
      world.deps,
      transferOf(world, {
        content: paymentDoc.transferCode,
        amount: 200_000,
        payer: latePayer,
      }),
    );

    const paymentAfter = await world.store.getPayment(paymentId);
    assert.equal(paymentAfter?.payer?.bankCode, 'VCB');
    assert.equal(paymentAfter?.payer?.accountLast4, '3456');

    const refunds = await world.store.getRefundsForPayment(paymentId);
    assert.equal(refunds.length, 1);
    const lateRefund = refunds[0];
    assert.ok(lateRefund);
    assert.equal(lateRefund.amount, 200_000);
    assert.equal(lateRefund.method, 'bank_transfer');
    assert.equal(lateRefund.status, 'done');
    assert.ok(lateRefund.destination);
    assert.equal(lateRefund.destination.bankCode, 'TCB');
    assert.equal(lateRefund.destination.accountLast4, '8888');
    assert.equal(await TEST_CIPHER.decrypt(lateRefund.destination.accountNumberEnc), '1903000099998888');
  });

  test('an expired under-paid payment refunds what it received to the payer', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId, checkout } = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    await handleTransferNotification(
      world.deps,
      transferOf(world, {
        content: checkout.transferCode,
        amount: 300_000,
        payer: TEST_PAYER,
      }),
    );

    // Advance 16 minutes to expire QR
    world.clock.advanceMinutes(16);
    // Requesting a new payment expires the old one
    await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    const expiredPayment = await world.store.getPayment(paymentId);
    assert.equal(expiredPayment?.status, 'expired');
    assert.equal(expiredPayment?.refundedAmount, 300_000);

    const refunds = await world.store.getRefundsForPayment(paymentId);
    assert.equal(refunds.length, 1);
    const r = refunds[0];
    assert.ok(r);
    assert.equal(r.amount, 300_000);
    assert.equal(r.reason, 'underpaid_expired');
    assert.equal(r.method, 'bank_transfer');
    assert.equal(r.status, 'done');
    assert.ok(r.destination);
    assert.equal(r.destination.bankCode, 'VCB');
    assert.equal(r.destination.accountLast4, '3456');
    assert.equal(await TEST_CIPHER.decrypt(r.destination.accountNumberEnc), '0071000123456');
  });

  test('a customer cancel of a bank_qr booking refunds to payment.payer and the gateway gets the plain account', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId } = await payDraft(world, draft.id);

    // Transition cancel (at least 48h before)
    await transitionBooking(world.deps, {
      bookingId: draft.id,
      action: 'cancel',
      actorId: 'c1',
      reason: 'Bận việc',
    });

    const payment = await world.store.getPayment(paymentId);
    assert.equal(payment?.status, 'refunded');
    assert.equal(payment?.refundedAmount, PRICE);

    const refunds = await world.store.getRefundsForPayment(paymentId);
    assert.equal(refunds.length, 1);
    const r = refunds[0];
    assert.ok(r);
    assert.equal(r.status, 'done');
    assert.equal(r.method, 'bank_transfer');
    assert.equal(r.destination?.bankCode, 'VCB');
    assert.equal(r.destination?.accountLast4, '3456');

    const req = world.gateway.refundRequests.get(r.id);
    assert.ok(req);
    assert.equal(req.method, 'bank_transfer');
    assert.deepEqual(req.destination, {
      bankCode: 'VCB',
      accountNumber: '0071000123456',
      holderName: 'NGUYEN THANH HA',
    });
  });

  test("a wallet payment's cancel refund is gateway with no destination", async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId } = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'momo' });
    world.gateway.markPaid(paymentId);
    const payment = await world.store.getPayment(paymentId);
    assert.ok(payment);
    await world.store.runTransaction(async (tx) => {
      await tx.setPayment({
        ...payment,
        status: 'paid',
        escrowStatus: 'held',
        receivedAmount: PRICE,
        updatedAt: world.clock.now().toISOString(),
      });
      await tx.setBooking({
        ...draft,
        status: 'requested',
        escrowStatus: 'held',
        depositProvider: 'fake',
        depositPaidAt: world.clock.now().toISOString(),
        updatedAt: world.clock.now().toISOString(),
      });
    });

    await transitionBooking(world.deps, {
      bookingId: draft.id,
      action: 'cancel',
      actorId: 'c1',
      reason: 'Đổi ý',
    });

    const refunds = await world.store.getRefundsForPayment(paymentId);
    assert.equal(refunds.length, 1);
    const r = refunds[0];
    assert.ok(r);
    assert.equal(r.status, 'done');
    assert.equal(r.method, 'gateway');
    assert.equal(r.destination, null);

    const req = world.gateway.refundRequests.get(r.id);
    assert.ok(req);
    assert.equal(req.method, 'gateway');
    assert.equal(req.destination, undefined);
  });

  test('no payer: the cancel refund is awaiting_account, not sent, depositRefundedAt unset', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId, checkout } = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
    await handleTransferNotification(
      world.deps,
      transferOf(world, { content: checkout.transferCode, amount: checkout.amount, payer: null }),
    );

    await transitionBooking(world.deps, {
      bookingId: draft.id,
      action: 'cancel',
      actorId: 'c1',
      reason: 'Bận',
    });

    const booking = await world.store.getBooking(draft.id);
    assert.equal(booking?.depositRefundedAt, undefined);

    const refunds = await world.store.getRefundsForPayment(paymentId);
    assert.equal(refunds.length, 1);
    const r = refunds[0];
    assert.ok(r);
    assert.equal(r.status, 'awaiting_account');
    assert.equal(r.method, 'bank_transfer');
    assert.equal(r.destination, null);
    assert.equal(r.lastAttemptAt, undefined);

    // Gateway was never called
    assert.ok(!world.gateway.refundRequests.has(r.id));
  });

  test('refundedAmount equals the sum of refunds after paid_with_refund, refunded, expiry, late-draft and cancel', async () => {
    // 1. paid_with_refund
    const w1 = createBookingWorld();
    const d1 = await newDraft(w1);
    const p1 = await createPayment(w1.deps, { bookingId: d1.id, customerId: 'c1', method: 'bank_qr' });
    await handleTransferNotification(w1.deps, transferOf(w1, { content: p1.checkout.transferCode, amount: PRICE + 70_000 }));
    const pay1 = await w1.store.getPayment(p1.paymentId);
    assert.ok(pay1);
    const refs1 = await w1.store.getRefundsForPayment(p1.paymentId);
    const entries1 = await w1.store.getLedgerEntriesForPayment(p1.paymentId);
    assert.equal(pay1.refundedAmount, 70_000);
    assert.equal(verifyPaymentLedgerInvariant(pay1, refs1, entries1), true);

    // 2. refunded (pure excess/unmatched/late transfer)
    const w2 = createBookingWorld();
    const d2 = await newDraft(w2);
    const { paymentId: p2Id } = await payDraft(w2, d2.id);
    const p2Doc = await w2.store.getPayment(p2Id);
    assert.ok(p2Doc?.transferCode);
    await handleTransferNotification(w2.deps, transferOf(w2, { content: p2Doc.transferCode, amount: 150_000 }));
    const pay2 = await w2.store.getPayment(p2Id);
    assert.ok(pay2);
    const refs2 = await w2.store.getRefundsForPayment(p2Id);
    const entries2 = await w2.store.getLedgerEntriesForPayment(p2Id);
    assert.equal(pay2.refundedAmount, 150_000);
    assert.equal(verifyPaymentLedgerInvariant(pay2, refs2, entries2), true);

    // 3. expiry
    const w3 = createBookingWorld();
    const d3 = await newDraft(w3);
    const p3 = await createPayment(w3.deps, { bookingId: d3.id, customerId: 'c1', method: 'bank_qr' });
    await handleTransferNotification(w3.deps, transferOf(w3, { content: p3.checkout.transferCode, amount: 250_000 }));
    w3.clock.advanceMinutes(16);
    await createPayment(w3.deps, { bookingId: d3.id, customerId: 'c1', method: 'bank_qr' });
    const pay3 = await w3.store.getPayment(p3.paymentId);
    assert.ok(pay3);
    const refs3 = await w3.store.getRefundsForPayment(p3.paymentId);
    const entries3 = await w3.store.getLedgerEntriesForPayment(p3.paymentId);
    assert.equal(pay3.refundedAmount, 250_000);
    assert.equal(verifyPaymentLedgerInvariant(pay3, refs3, entries3), true);

    // 4. late-draft (draft deleted before payment arrives)
    const w4 = createBookingWorld();
    const d4 = await newDraft(w4);
    const p4 = await createPayment(w4.deps, { bookingId: d4.id, customerId: 'c1', method: 'bank_qr' });
    await w4.store.deleteBooking(d4.id);
    await handleTransferNotification(w4.deps, transferOf(w4, { content: p4.checkout.transferCode, amount: PRICE }));
    const pay4 = await w4.store.getPayment(p4.paymentId);
    assert.ok(pay4);
    const refs4 = await w4.store.getRefundsForPayment(p4.paymentId);
    const entries4 = await w4.store.getLedgerEntriesForPayment(p4.paymentId);
    assert.equal(pay4.refundedAmount, PRICE);
    assert.equal(verifyPaymentLedgerInvariant(pay4, refs4, entries4), true);

    // 5. cancel
    const w5 = createBookingWorld();
    const d5 = await newDraft(w5);
    const { paymentId: p5Id } = await payDraft(w5, d5.id);
    await transitionBooking(w5.deps, { bookingId: d5.id, action: 'cancel', actorId: 'c1', reason: 'Bận' });
    const pay5 = await w5.store.getPayment(p5Id);
    assert.ok(pay5);
    const refs5 = await w5.store.getRefundsForPayment(p5Id);
    const entries5 = await w5.store.getLedgerEntriesForPayment(p5Id);
    assert.equal(pay5.refundedAmount, PRICE);
    assert.equal(verifyPaymentLedgerInvariant(pay5, refs5, entries5), true);
  });

  test('the plain number is nowhere in the store after capture, refund and dispatch', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    await payDraft(world, draft.id);
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c1', reason: 'Bận' });

    // Review Focus 2: JSON.stringify of every map in MemoryBookingStore does not contain '0071000123456'
    const plainNumber = '0071000123456';
    const storeDumps = [
      JSON.stringify([...world.store.payments.entries()]),
      JSON.stringify([...world.store.refunds.entries()]),
      JSON.stringify([...world.store.bookings.entries()]),
      JSON.stringify([...world.store.ledgerEntries.entries()]),
      JSON.stringify([...world.store.transferRecords.entries()]),
    ];
    for (const dump of storeDumps) {
      assert.ok(!dump.includes(plainNumber), `Found plain account number in store dump: ${dump}`);
    }
  });

  test('a refund event done before the dispatch answer is stored stays done', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId } = await payDraft(world, draft.id);
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c1', reason: 'Bận' });

    const [refund] = await world.store.getRefundsForPayment(paymentId);
    assert.ok(refund);

    // Simulate an event arriving and marking it done first
    await bookingRefundHandler(world.deps).record({ ...refund, status: 'done' });
    const storedDone = await world.store.getRefund(refund.id);
    assert.equal(storedDone?.status, 'done');

    // Now record a pending answer: stored must stay done
    await bookingRefundHandler(world.deps).record({ ...refund, status: 'pending', attempts: 1 });
    const storedAfter = await world.store.getRefund(refund.id);
    assert.equal(storedAfter?.status, 'done');
  });

  test('dispatchRefund on a refund already done makes no gateway call', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const { paymentId } = await payDraft(world, draft.id);
    await transitionBooking(world.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c1', reason: 'Bận' });

    const [refund] = await world.store.getRefundsForPayment(paymentId);
    assert.ok(refund);
    assert.equal(refund.status, 'done');

    const callsBefore = world.gateway.refundCalls.length;
    await dispatchRefund(world.deps, refund, 'fake');
    assert.equal(world.gateway.refundCalls.length, callsBefore);
  });
});
