import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import { createBookingDraft, type BookingDeps } from '@photobooking/domain';
import { handleCheckPayment, handleConfirmFakePayment, handleCreatePayment } from '../../src/callables/payment.js';
import { PROD_ENV, WEBHOOK_ENV, openPayment, paymentWorld } from './support/payment_world.js';

const httpsError = (code: string, detailsCode?: string) => (e: unknown) =>
  e instanceof HttpsError
  && e.code === code
  && (detailsCode === undefined || (e.details as { code?: string }).code === detailsCode);

async function newDraft(deps: BookingDeps, day = '2026-10-15', customerId = 'c1') {
  return createBookingDraft(deps, {
    customerId,
    photographerId: 'p1',
    serviceId: 'svc1',
    day,
    start: '09:00',
    place: { name: 'Thảo Cầm Viên' },
  });
}

describe('payment callables', () => {
  it('createPayment returns the checkout and rejects unauthenticated callers', async () => {
    const w = paymentWorld();
    const draft = await newDraft(w.deps);
    await assert.rejects(handleCreatePayment({ data: { bookingId: draft.id, method: 'bank_qr' } }, w.deps, WEBHOOK_ENV), httpsError('unauthenticated', 'permission_denied'));
    await assert.rejects(handleCheckPayment({ data: { bookingId: draft.id } }, w.deps), httpsError('unauthenticated', 'permission_denied'));
    await assert.rejects(handleConfirmFakePayment({ data: { paymentId: 'x' } }, w.deps, WEBHOOK_ENV), httpsError('unauthenticated', 'permission_denied'));

    const res = await handleCreatePayment({ auth: { uid: 'c1' }, data: { bookingId: draft.id, method: 'bank_qr' } }, w.deps, WEBHOOK_ENV);
    assert.ok(res.paymentId);
    assert.equal(res.checkout.paymentId, res.paymentId);
    assert.equal(res.checkout.method, 'bank_qr');
    assert.equal(res.checkout.amount, 1_000_000);
    assert.equal(res.checkout.attempt, 1);
    assert.match(res.checkout.transferCode, /^PB [2-9A-HJKMNP-TV-Z]{6}$/);
    assert.equal(res.checkout.bankName, 'BIDV');
    assert.equal(res.checkout.expiresAt, '2026-10-01T10:15:00.000Z');
    assert.ok(res.checkout.qrPayload?.startsWith('000201'));
    assert.equal((await w.store.getBooking(draft.id))?.checkout?.paymentId, res.paymentId);

    // A method outside PAYMENT_METHODS (a reserved card method) is invalid_argument.
    await assert.rejects(
      handleCreatePayment({ auth: { uid: 'c1' }, data: { bookingId: draft.id, method: 'intl_card' } }, w.deps, WEBHOOK_ENV),
      httpsError('invalid-argument', 'invalid_argument'),
    );
    // Another customer's booking is refused.
    await assert.rejects(
      handleCreatePayment({ auth: { uid: 'c2' }, data: { bookingId: draft.id, method: 'bank_qr' } }, w.deps, WEBHOOK_ENV),
      httpsError('permission-denied', 'permission_denied'),
    );
  });

  it('createPayment fails closed (not_eligible) where no real gateway is wired and fakes are not allowed', async () => {
    const w = paymentWorld();
    const draft = await newDraft(w.deps);
    const before = await w.store.getBooking(draft.id);
    for (const env of [PROD_ENV, {}, { FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'booking-prod-1' }]) {
      await assert.rejects(
        handleCreatePayment({ auth: { uid: 'c1' }, data: { bookingId: draft.id, method: 'bank_qr' } }, w.deps, env),
        httpsError('failed-precondition', 'not_eligible'),
      );
    }
    // Nothing was written and the fake gateway never produced a QR.
    assert.equal(w.store.payments.size, 0);
    assert.equal(w.gateway.createPaymentCalls.length, 0);
    assert.deepEqual(await w.store.getBooking(draft.id), before);

    // The emulator (demo-*) and the dev project open payments as before.
    const emu = await handleCreatePayment({ auth: { uid: 'c1' }, data: { bookingId: draft.id, method: 'bank_qr' } }, w.deps, WEBHOOK_ENV);
    assert.equal(emu.checkout.bankName, 'BIDV');
    const devDraft = await newDraft(w.deps, '2026-10-20');
    const dev = await handleCreatePayment(
      { auth: { uid: 'c1' }, data: { bookingId: devDraft.id, method: 'bank_qr' } },
      w.deps,
      { GCLOUD_PROJECT: 'booking-c1922' },
    );
    assert.ok(dev.paymentId);
  });

  it('payment_attempts_exceeded maps to failed-precondition with details.code', async () => {
    const w = paymentWorld();
    const draft = await newDraft(w.deps);
    for (let i = 0; i < 3; i++) {
      await handleCreatePayment({ auth: { uid: 'c1' }, data: { bookingId: draft.id, method: i === 1 ? 'momo' : 'bank_qr' } }, w.deps, WEBHOOK_ENV);
    }
    await assert.rejects(
      handleCreatePayment({ auth: { uid: 'c1' }, data: { bookingId: draft.id, method: 'bank_qr' } }, w.deps, WEBHOOK_ENV),
      httpsError('failed-precondition', 'payment_attempts_exceeded'),
    );
  });

  it('confirmFakePayment exact/under/over/wrong_content give paid/partial/paid_with_refund/needs_review', async () => {
    const w = paymentWorld();
    const cases = [
      { kind: 'exact', day: '2026-10-15', outcome: 'paid', status: 'paid', booking: 'requested' },
      { kind: 'under', day: '2026-10-16', outcome: 'partial', status: 'created', booking: 'draft' },
      { kind: 'over', day: '2026-10-17', outcome: 'paid_with_refund', status: 'paid', booking: 'requested' },
      { kind: 'wrong_content', day: '2026-10-18', outcome: 'needs_review', status: 'created', booking: 'draft' },
    ] as const;
    for (const c of cases) {
      const p = await openPayment(w, c.day);
      const res = await handleConfirmFakePayment({ auth: { uid: 'c1' }, data: { paymentId: p.paymentId, kind: c.kind } }, w.deps, WEBHOOK_ENV);
      assert.deepEqual(res, { outcome: c.outcome }, c.kind);
      assert.equal((await w.store.getPayment(p.paymentId))?.status, c.status, c.kind);
      assert.equal((await w.store.getBooking(p.bookingId))?.status, c.booking, c.kind);
      if (c.kind === 'under') assert.equal((await w.store.getPayment(p.paymentId))?.receivedAmount, 500_000);
      if (c.kind === 'over') {
        const refunds = await w.store.getRefundsForPayment(p.paymentId);
        assert.deepEqual(refunds.map((r) => [r.amount, r.reason]), [[50_000, 'overpaid_excess']]);
      }
    }
    // Each kind went through the signed webhook pipeline and is stored by its txnId.
    const ids = [...w.store.transferRecords.keys()];
    assert.equal(ids.length, 4);
    for (const id of ids) assert.match(id, /^fake_fake_id_\d{4}_(exact|under|over|wrong_content)_\d+$/);
  });

  it('confirmFakePayment defaults to exact and refuses an unknown kind', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    await assert.rejects(
      handleConfirmFakePayment({ auth: { uid: 'c1' }, data: { paymentId: p.paymentId, kind: 'double' } }, w.deps, WEBHOOK_ENV),
      httpsError('invalid-argument', 'invalid_argument'),
    );
    assert.deepEqual(await handleConfirmFakePayment({ auth: { uid: 'c1' }, data: { paymentId: p.paymentId } }, w.deps, WEBHOOK_ENV), { outcome: 'paid' });
  });

  it('confirmFakePayment on a production project is refused before any read', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    let reads = 0;
    const counting = new Proxy(w.store, {
      get(target, prop, receiver) {
        const v = Reflect.get(target, prop, receiver) as unknown;
        if (typeof v !== 'function') return v;
        return (...args: unknown[]) => {
          reads += 1;
          return (v as (...a: unknown[]) => unknown).apply(target, args);
        };
      },
    });
    await assert.rejects(
      handleConfirmFakePayment({ auth: { uid: 'c1' }, data: { paymentId: p.paymentId, kind: 'exact' } }, { ...w.deps, store: counting }, PROD_ENV),
      httpsError('failed-precondition', 'fake_payments_disabled'),
    );
    assert.equal(reads, 0);
    assert.equal((await w.store.getPayment(p.paymentId))?.status, 'created');
  });

  it('confirmFakePayment by another customer is permission_denied', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    await assert.rejects(
      handleConfirmFakePayment({ auth: { uid: 'c2' }, data: { paymentId: p.paymentId } }, w.deps, WEBHOOK_ENV),
      httpsError('permission-denied', 'permission_denied'),
    );
    await assert.rejects(
      handleConfirmFakePayment({ auth: { uid: 'c1' }, data: { paymentId: 'id_9999' } }, w.deps, WEBHOOK_ENV),
      httpsError('not-found', 'not_found'),
    );
    assert.equal(w.store.transferRecords.size, 0);
  });

  it('confirmFakePayment without the webhook secret fails as internal and writes nothing', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    const { FAKE_PAYMENT_WEBHOOK_SECRET: _unused, ...noSecret } = WEBHOOK_ENV;
    void _unused;
    await assert.rejects(
      handleConfirmFakePayment({ auth: { uid: 'c1' }, data: { paymentId: p.paymentId } }, w.deps, noSecret),
      httpsError('internal'),
    );
    assert.equal(w.store.transferRecords.size, 0);
  });

  it('checkPayment returns paid after a transfer', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    const before = await handleCheckPayment({ auth: { uid: 'c1' }, data: { bookingId: p.bookingId } }, w.deps);
    assert.equal(before.paid, false);
    await handleConfirmFakePayment({ auth: { uid: 'c1' }, data: { paymentId: p.paymentId, kind: 'exact' } }, w.deps, WEBHOOK_ENV);
    const after = await handleCheckPayment({ auth: { uid: 'c1' }, data: { bookingId: p.bookingId } }, w.deps);
    assert.equal(after.paid, true);
    assert.equal(after.booking?.status, 'requested');
    await assert.rejects(
      handleCheckPayment({ auth: { uid: 'c2' }, data: { bookingId: p.bookingId } }, w.deps),
      httpsError('permission-denied', 'permission_denied'),
    );
  });

  it('confirmFakePayment sends FAKE_PAYER, so a cancel refund is sent by bank transfer', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    const paid = await handleConfirmFakePayment(
      { auth: { uid: 'c1' }, data: { paymentId: p.paymentId, kind: 'exact' } },
      w.deps,
      WEBHOOK_ENV,
    );
    assert.deepEqual(paid, { outcome: 'paid' });

    // Customer cancels the requested booking
    const { transitionBooking } = await import('@photobooking/domain');
    const cancelled = await transitionBooking(w.deps, {
      bookingId: p.bookingId,
      action: 'cancel',
      actorId: 'c1',
    });
    assert.equal(cancelled.status, 'cancelled');

    const refunds = await w.store.getRefundsForPayment(p.paymentId);
    assert.equal(refunds.length, 1);
    const refund = refunds[0];
    assert.ok(refund);
    assert.equal(refund.method, 'bank_transfer');
    assert.equal(refund.status, 'done');
    assert.equal(refund.destination?.holderName, 'KHACH THU NGHIEM');
    assert.equal(refund.destination?.source, 'payer');
  });
});

