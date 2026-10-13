import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createBookingWorld, newDraft, transferOf, type BookingWorld } from './support/booking_world.js';
import {
  createPayment,
  freshPaymentId,
  instructionsOf,
  issuePaymentInstructions,
  newSubjectPayment,
} from '../src/create_payment.js';
import { handleTransferNotification } from '../src/handle_transfer.js';
import { TRANSFER_CODE_ALPHABET, transferCodeFor } from '../src/payment_code.js';
import { DomainError, type ErrorCode } from '../src/errors.js';
import { verifyPaymentLedgerInvariant, type Payment } from '../src/escrow.js';

const PRICE = 1_000_000;
const CODE_RE = new RegExp(`^PB [${TRANSFER_CODE_ALPHABET}]{6}$`);

const refusedWith = (code: ErrorCode) => (e: unknown) => e instanceof DomainError && e.code === code;

async function payment(world: BookingWorld, id: string): Promise<Payment> {
  const p = await world.store.getPayment(id);
  assert.ok(p, `payment ${id}`);
  return p;
}

async function balanced(world: BookingWorld, p: Payment): Promise<boolean> {
  return verifyPaymentLedgerInvariant(
    p,
    await world.store.getRefundsForPayment(p.id),
    await world.store.getLedgerEntriesForPayment(p.id),
  );
}

describe('createPayment', () => {
  it('creates a created QR payment with a 15-minute expiry and mirrors checkout on the booking', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    world.clock.advanceMinutes(20); // 10:20Z: the QR outlives the draft's first 30 minutes

    const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    const p = await payment(world, res.paymentId);
    assert.equal(p.status, 'created');
    assert.equal(p.escrowStatus, 'held');
    assert.equal(p.provider, 'fake');
    assert.equal(p.method, 'bank_qr');
    assert.equal(p.amount, PRICE);
    assert.equal(p.receivedAmount, 0);
    assert.equal(p.subjectId, draft.id);
    assert.equal(p.transferCode, transferCodeFor(p.id));
    assert.match(p.transferCode ?? '', CODE_RE);
    assert.equal(p.expiresAt, '2026-10-10T10:35:00.000Z');
    assert.equal(p.idempotencyKey, `pay_${draft.id}_1`);
    assert.equal(world.gateway.createPaymentCalls.length, 1);
    assert.equal(world.gateway.createPaymentCalls[0]?.idempotencyKey, `pay_${draft.id}_1`);

    const c = res.checkout;
    assert.equal(c.paymentId, p.id);
    assert.equal(c.method, 'bank_qr');
    assert.equal(c.amount, PRICE);
    assert.equal(c.expiresAt, p.expiresAt);
    assert.equal(c.transferCode, p.transferCode);
    assert.equal(c.attempt, 1);
    assert.ok(c.qrPayload?.includes(p.transferCode ?? '?'), 'the QR carries the transfer code');
    assert.ok(c.qrPayload?.includes(String(PRICE)), 'the QR carries the amount');
    assert.equal(c.bankName, 'BIDV');
    assert.equal(c.accountMasked, '9624 •••• 3812');
    assert.equal(c.bankAppsUrl, 'https://fake-pay.local/bank-apps');
    assert.equal(c.payUrl, undefined);

    const booking = await world.store.getBooking(draft.id);
    assert.deepEqual(booking?.checkout, c);
    // max(createdAt + 30 min, expiresAt + 5 min) = max(10:30, 10:40)
    assert.equal(booking?.payableUntil, '2026-10-10T10:40:00.000Z');
    assert.equal(booking?.status, 'draft');
  });

  it('keeps the 30-minute draft lifetime when the QR expires earlier', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    assert.equal(draft.payableUntil, '2026-10-10T10:30:00.000Z');

    await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    // max(10:30, 10:15 + 5 min)
    assert.equal((await world.store.getBooking(draft.id))?.payableUntil, '2026-10-10T10:30:00.000Z');
  });

  it('wallet methods mirror payUrl and no QR', async () => {
    for (const method of ['momo', 'zalopay'] as const) {
      const world = createBookingWorld();
      const draft = await newDraft(world);

      const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method });

      assert.equal(res.checkout.method, method);
      assert.equal(res.checkout.payUrl, `https://fake-pay.local/${method}?paymentId=${res.paymentId}`);
      assert.equal(res.checkout.qrPayload, undefined);
      assert.equal(res.checkout.bankName, undefined);
      assert.equal(res.checkout.bankAppsUrl, undefined);
      assert.match(res.checkout.transferCode, CODE_RE);
      assert.equal((await payment(world, res.paymentId)).method, method);
    }
  });

  it('rejects a reserved or unknown method with invalid_argument', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);

    for (const method of ['domestic_card', 'intl_card', 'cash', '', undefined, 42, null]) {
      await assert.rejects(
        createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method }),
        refusedWith('invalid_argument'),
        String(method),
      );
    }
    assert.equal(world.store.payments.size, 0);
    assert.equal(world.gateway.createPaymentCalls.length, 0);
  });

  it('a new QR expires the previous open payment', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const first = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
    world.clock.advanceMinutes(2);

    const second = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    assert.notEqual(second.paymentId, first.paymentId);
    assert.notEqual(second.checkout.transferCode, first.checkout.transferCode);
    const old = await payment(world, first.paymentId);
    assert.equal(old.status, 'expired');
    assert.equal(old.escrowStatus, 'refunded');
    assert.equal((await world.store.getRefundsForPayment(old.id)).length, 0, 'nothing received, nothing refunded');
    assert.equal(await balanced(world, old), true);

    const fresh = await payment(world, second.paymentId);
    assert.equal(fresh.status, 'created');
    assert.equal(fresh.idempotencyKey, `pay_${draft.id}_2`);
    assert.equal(second.checkout.attempt, 2);
    assert.equal((await world.store.getBooking(draft.id))?.checkout?.paymentId, second.paymentId);
  });

  it('a new QR refunds what the previous payment had received', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const first = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
    const partial = await handleTransferNotification(
      world.deps,
      transferOf(world, { content: first.checkout.transferCode, amount: 400_000 }),
    );
    assert.equal(partial.outcome, 'partial');

    await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    const old = await payment(world, first.paymentId);
    assert.equal(old.status, 'expired');
    const refunds = await world.store.getRefundsForPayment(old.id);
    assert.equal(refunds.length, 1);
    assert.equal(refunds[0]?.amount, 400_000);
    assert.equal(refunds[0]?.reason, 'underpaid_expired');
    assert.equal(refunds[0]?.status, 'done');
    assert.equal(world.gateway.issuedRefunds.get(refunds[0]?.id ?? ''), 400_000);
    assert.equal(await balanced(world, old), true);
  });

  it('the fourth attempt is refused with payment_attempts_exceeded', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    for (let i = 1; i <= 3; i++) {
      const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
      assert.equal(res.checkout.attempt, i);
    }

    await assert.rejects(
      createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' }),
      refusedWith('payment_attempts_exceeded'),
    );
    assert.equal((await world.store.getPaymentsForBooking(draft.id)).length, 3);
    assert.equal(world.gateway.createPaymentCalls.length, 3);
  });

  it('refuses a non-draft booking, another customer, a missing phone, a released day', async () => {
    // Another customer
    {
      const world = createBookingWorld();
      const draft = await newDraft(world);
      await assert.rejects(
        createPayment(world.deps, { bookingId: draft.id, customerId: 'c2', method: 'bank_qr' }),
        refusedWith('permission_denied'),
      );
    }
    // Unknown booking
    {
      const world = createBookingWorld();
      await assert.rejects(
        createPayment(world.deps, { bookingId: 'b_missing', customerId: 'c1', method: 'bank_qr' }),
        refusedWith('not_found'),
      );
    }
    // Missing phone
    {
      const world = createBookingWorld();
      const draft = await newDraft(world);
      world.contacts.delete('c1');
      await assert.rejects(
        createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' }),
        refusedWith('phone_required'),
      );
    }
    // Released day
    {
      const world = createBookingWorld();
      const draft = await newDraft(world);
      world.store.availability.clear();
      await assert.rejects(
        createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' }),
        refusedWith('day_taken'),
      );
    }
    // Not a draft any more (paid)
    {
      const world = createBookingWorld();
      const draft = await newDraft(world);
      const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
      await handleTransferNotification(world.deps, transferOf(world, { content: res.checkout.transferCode, amount: PRICE }));
      await assert.rejects(
        createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' }),
        refusedWith('conflict'),
      );
      assert.equal(world.gateway.createPaymentCalls.length, 1);
    }
  });

  it('retries the id when the transfer code is taken by an open payment', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    assert.equal(draft.id, 'id_001');
    // The next id createPayment draws is id_002: an open payment of someone else already uses its code.
    const takenCode = transferCodeFor('id_002');
    const at = world.clock.now().toISOString();
    world.store.payments.set('other_open', {
      id: 'other_open',
      subjectType: 'booking',
      subjectId: 'b_other',
      payerId: 'c2',
      payeeId: 'p1',
      provider: 'fake',
      amount: PRICE,
      status: 'created',
      escrowStatus: 'held',
      idempotencyKey: 'pay_b_other_1',
      transferCode: takenCode,
      expiresAt: '2026-10-10T10:15:00.000Z',
      receivedAmount: 0,
      createdAt: at,
      updatedAt: at,
    });

    const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    assert.notEqual(res.paymentId, 'id_002');
    assert.notEqual(res.checkout.transferCode, takenCode);
    assert.equal(res.checkout.transferCode, transferCodeFor(res.paymentId));
  });

  it('never reuses a code held by a closed payment', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    assert.equal(draft.id, 'id_001');
    const takenCode = transferCodeFor('id_002');
    const at = world.clock.now().toISOString();
    world.store.payments.set('other_expired', {
      id: 'other_expired',
      subjectType: 'booking',
      subjectId: 'b_other',
      payerId: 'c2',
      payeeId: 'p1',
      provider: 'fake',
      amount: PRICE,
      status: 'expired',
      escrowStatus: 'refunded',
      idempotencyKey: 'pay_b_other_1',
      transferCode: takenCode,
      createdAt: at,
      updatedAt: at,
    });

    const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    assert.notEqual(res.paymentId, 'id_002');
    assert.notEqual(res.checkout.transferCode, takenCode);
  });

  it('a new QR is returned even when refunding the previous payment throws', async () => {
    const world = createBookingWorld();
    const draft = await newDraft(world);
    const first = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });
    await handleTransferNotification(world.deps, transferOf(world, { content: first.checkout.transferCode, amount: 400_000 }));
    world.gateway.refundThrowCount = 1;

    const second = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

    assert.equal(second.checkout.attempt, 2);
    assert.equal((await world.store.getBooking(draft.id))?.checkout?.paymentId, second.paymentId);
    const refunds = await world.store.getRefundsForPayment(first.paymentId);
    assert.deepEqual(
      refunds.map((r) => [r.amount, r.reason, r.status, r.manual]),
      [[400_000, 'underpaid_expired', 'failed', true]],
    );
    assert.equal(world.gateway.issuedRefunds.size, 0);
  });

  describe('order gate', () => {
    it('refuses a provider who stopped accepting orders with not_accepting_orders', async () => {
      const world = createBookingWorld();
      const draft = await newDraft(world);
      world.providers.set('p1', { verified: false, onboardingComplete: true });
      await assert.rejects(
        createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' }),
        refusedWith('not_accepting_orders'),
      );
      assert.equal((await world.store.getPaymentsForBooking(draft.id)).length, 0);
      assert.equal(world.gateway.createPaymentCalls.length, 0);
    });

    it('refuses a blocked pair with blocked', async () => {
      const world = createBookingWorld();
      const draft = await newDraft(world);
      world.blocks.block('c1', 'p1');
      await assert.rejects(
        createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' }),
        refusedWith('blocked'),
      );
      assert.equal((await world.store.getPaymentsForBooking(draft.id)).length, 0);
      assert.equal(world.gateway.createPaymentCalls.length, 0);
    });

    it('createPayment by another customer answers permission_denied even for a blocked pair', async () => {
      const world = createBookingWorld();
      const draft = await newDraft(world);
      world.blocks.block('p1', 'c1');
      await assert.rejects(
        createPayment(world.deps, { bookingId: draft.id, customerId: 'c2', method: 'bank_qr' }),
        refusedWith('permission_denied'),
      );
    });
  });

  describe('Task 1 generic payment helpers', () => {
    it('newSubjectPayment sets created, held, the PB code of its id, zero received and an ISO expiresAt', () => {
      const now = new Date('2026-10-10T10:00:00.000Z');
      const expiresAt = new Date('2026-10-10T10:15:00.000Z');
      const p = newSubjectPayment({
        id: 'id_xyz',
        subjectType: 'booking',
        subjectId: 'b_123',
        payerId: 'u_payer',
        payeeId: 'u_payee',
        amount: 500_000,
        method: 'bank_qr',
        provider: 'fake',
        idempotencyKey: 'key_123',
        now,
        expiresAt,
      });

      assert.equal(p.id, 'id_xyz');
      assert.equal(p.status, 'created');
      assert.equal(p.escrowStatus, 'held');
      assert.equal(p.transferCode, transferCodeFor('id_xyz'));
      assert.equal(p.receivedAmount, 0);
      assert.equal(p.expiresAt, '2026-10-10T10:15:00.000Z');
      assert.equal(p.createdAt, '2026-10-10T10:00:00.000Z');
    });

    it('instructionsOf rebuilds the instructions from the stored payment and is null without them', () => {
      const base: Payment = {
        id: 'p_1',
        subjectType: 'booking',
        subjectId: 'b_1',
        payerId: 'c1',
        payeeId: 'p1',
        provider: 'fake',
        amount: 200_000,
        status: 'created',
        escrowStatus: 'held',
        idempotencyKey: 'k_1',
        method: 'bank_qr',
        transferCode: 'PB 111111',
        expiresAt: '2026-10-10T10:15:00.000Z',
        createdAt: '2026-10-10T10:00:00.000Z',
        updatedAt: '2026-10-10T10:00:00.000Z',
      };

      assert.equal(instructionsOf(base), null);

      const withInst: Payment = {
        ...base,
        instructions: {
          qrPayload: 'qr_test',
          bankName: 'BIDV',
        },
      };

      const inst = instructionsOf(withInst);
      assert.ok(inst);
      assert.equal(inst.paymentId, 'p_1');
      assert.equal(inst.subjectType, 'booking');
      assert.equal(inst.subjectId, 'b_1');
      assert.equal(inst.method, 'bank_qr');
      assert.equal(inst.amount, 200_000);
      assert.equal(inst.qrPayload, 'qr_test');
      assert.equal(inst.bankName, 'BIDV');
    });

    it('issuePaymentInstructions calls the gateway once with subjectType and subjectId and saves providerRef and instructions', async () => {
      const world = createBookingWorld();
      const p: Payment = {
        id: 'p_issue',
        subjectType: 'booking',
        subjectId: 'b_issue',
        payerId: 'c1',
        payeeId: 'p1',
        provider: 'fake',
        amount: 750_000,
        status: 'created',
        escrowStatus: 'held',
        idempotencyKey: 'k_issue',
        method: 'bank_qr',
        transferCode: 'PB 222222',
        expiresAt: '2026-10-10T10:15:00.000Z',
        createdAt: '2026-10-10T10:00:00.000Z',
        updatedAt: '2026-10-10T10:00:00.000Z',
      };

      let savedRef: string | undefined;
      let savedInst: unknown;
      const res = await issuePaymentInstructions(world.gateway, p, async (ref, inst) => {
        savedRef = ref;
        savedInst = inst;
      });

      assert.equal(world.gateway.createPaymentCalls.length, 1);
      assert.equal(world.gateway.createPaymentCalls[0]?.subjectType, 'booking');
      assert.equal(world.gateway.createPaymentCalls[0]?.subjectId, 'b_issue');
      assert.equal(savedRef, 'fake_ref_p_issue');
      assert.ok(savedInst);
      assert.equal(res.paymentId, 'p_issue');
      assert.equal(res.transferCode, 'PB 222222');
      assert.ok(res.qrPayload);
    });

    it('issuePaymentInstructions refuses a payment without method, code or expiry (conflict)', async () => {
      const world = createBookingWorld();
      const pMissing: Payment = {
        id: 'p_bad',
        subjectType: 'booking',
        subjectId: 'b_bad',
        payerId: 'c1',
        payeeId: 'p1',
        provider: 'fake',
        amount: 100_000,
        status: 'created',
        escrowStatus: 'held',
        idempotencyKey: 'k_bad',
        createdAt: '2026-10-10T10:00:00.000Z',
        updatedAt: '2026-10-10T10:00:00.000Z',
      };

      await assert.rejects(
        issuePaymentInstructions(world.gateway, pMissing, async () => {}),
        refusedWith('conflict'),
      );
    });

    it('freshPaymentId skips an id whose code any payment of any subject uses', async () => {
      const world = createBookingWorld();
      // Suppose id_001 is drawn first, its code is taken by an event_registration payment
      const takenCode = transferCodeFor('id_001');
      world.store.payments.set('p_evt', {
        id: 'p_evt',
        subjectType: 'event_registration',
        subjectId: 'reg_1',
        payerId: 'c2',
        payeeId: 'host_1',
        provider: 'fake',
        amount: 100_000,
        status: 'created',
        escrowStatus: 'held',
        idempotencyKey: 'k_evt',
        transferCode: takenCode,
        createdAt: '2026-10-10T10:00:00.000Z',
        updatedAt: '2026-10-10T10:00:00.000Z',
      });

      const nextId = await freshPaymentId(world.store, world.ids);
      assert.notEqual(nextId, 'id_001');
      assert.notEqual(transferCodeFor(nextId), takenCode);
    });

    it('createPayment stores the gateway instructions on the booking payment', async () => {
      const world = createBookingWorld();
      const draft = await newDraft(world);
      const res = await createPayment(world.deps, { bookingId: draft.id, customerId: 'c1', method: 'bank_qr' });

      const p = await world.store.getPayment(res.paymentId);
      assert.ok(p?.instructions);
      assert.equal(p.instructions.bankName, 'BIDV');
      assert.ok(p.instructions.qrPayload);
    });
  });
});
