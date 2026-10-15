import assert from 'node:assert/strict';
import test, { describe } from 'node:test';
import type { Payment, Refund } from '../src/escrow.js';
import { FakePaymentGateway } from '../src/fake_payment_gateway.js';
import { mergeRefundOutcome, sendRefundOnce } from '../src/refunds.js';
import { TEST_CIPHER } from './support/test_cipher.js';

const NOW = new Date('2026-10-15T10:00:00.000Z');
const clock = { now: () => NOW };

const testPayment: Pick<Payment, 'id' | 'provider'> = {
  id: 'pay_1',
  provider: 'fake',
};

function makeRefund(overrides: Partial<Refund> = {}): Refund {
  return {
    id: 'rf_1',
    paymentId: 'pay_1',
    subjectType: 'booking',
    amount: 100_000,
    percent: 100,
    status: 'pending',
    manual: false,
    fromEscrow: true,
    method: 'gateway',
    attempts: 0,
    createdAt: NOW.toISOString(),
    updatedAt: NOW.toISOString(),
    ...overrides,
  };
}

describe('sendRefundOnce', () => {
  test('a pending gateway refund is done with the provider ref, attempts 1, lastAttemptAt now', async () => {
    const gateway = new FakePaymentGateway();
    const refund = makeRefund({ method: 'gateway' });
    const res = await sendRefundOnce({ gateway, cipher: TEST_CIPHER, clock }, refund, testPayment);
    assert.equal(res.status, 'done');
    assert.equal(res.manual, false);
    assert.equal(res.attempts, 1);
    assert.equal(res.lastAttemptAt, NOW.toISOString());
    assert.ok(res.providerRef);
  });

  test('a bank_transfer refund sends method and the decrypted destination', async () => {
    const gateway = new FakePaymentGateway();
    const enc = await TEST_CIPHER.encrypt('0071000123456');
    const refund = makeRefund({
      method: 'bank_transfer',
      destination: {
        bankCode: 'VCB',
        bankName: 'Vietcombank',
        accountNumberEnc: enc,
        accountLast4: '3456',
        holderName: 'NGUYEN THANH HA',
        source: 'payer',
      },
    });
    const res = await sendRefundOnce({ gateway, cipher: TEST_CIPHER, clock }, refund, testPayment);
    assert.equal(res.status, 'done');
    const recorded = gateway.refundRequests.get(refund.id);
    assert.deepEqual(recorded, {
      method: 'bank_transfer',
      destination: {
        bankCode: 'VCB',
        accountNumber: '0071000123456',
        holderName: 'NGUYEN THANH HA',
      },
    });
  });

  test('an answer pending keeps the refund pending with providerRef and attempts + 1', async () => {
    const gateway = new FakePaymentGateway();
    gateway.refundPendingIds.add('rf_1');
    const refund = makeRefund();
    const res = await sendRefundOnce({ gateway, cipher: TEST_CIPHER, clock }, refund, testPayment);
    assert.equal(res.status, 'pending');
    assert.equal(res.attempts, 1);
    assert.equal(res.lastAttemptAt, NOW.toISOString());
    assert.ok(res.providerRef);
  });

  test('success false is failed, manual, failureReason from the gateway error', async () => {
    const gateway = new FakePaymentGateway();
    gateway.refundFailureId = 'rf_1';
    const refund = makeRefund();
    const res = await sendRefundOnce({ gateway, cipher: TEST_CIPHER, clock }, refund, testPayment);
    assert.equal(res.status, 'failed');
    assert.equal(res.manual, true);
    assert.equal(res.failureReason, 'fake_refund_failed');
  });

  test('a throw keeps it pending with attempts + 1 and lastAttemptAt now, and does not throw', async () => {
    const gateway = new FakePaymentGateway();
    gateway.refundThrowCount = 1;
    const refund = makeRefund();
    const res = await sendRefundOnce({ gateway, cipher: TEST_CIPHER, clock }, refund, testPayment);
    assert.equal(res.status, 'pending');
    assert.equal(res.attempts, 1);
    assert.equal(res.lastAttemptAt, NOW.toISOString());
  });

  test('a decrypt failure is handled like a throw', async () => {
    const gateway = new FakePaymentGateway();
    const refund = makeRefund({
      method: 'bank_transfer',
      destination: {
        bankCode: 'VCB',
        bankName: 'Vietcombank',
        accountNumberEnc: 'invalid_not_enc_prefix',
        accountLast4: '3456',
        holderName: 'NGUYEN THANH HA',
        source: 'payer',
      },
    });
    const res = await sendRefundOnce({ gateway, cipher: TEST_CIPHER, clock }, refund, testPayment);
    assert.equal(res.status, 'pending');
    assert.equal(res.attempts, 1);
    assert.equal(res.lastAttemptAt, NOW.toISOString());
  });

  test('the 6th throw is failed, manual, gateway_unavailable', async () => {
    const gateway = new FakePaymentGateway();
    gateway.refundThrowCount = 1;
    const refund = makeRefund({ attempts: 5 });
    const res = await sendRefundOnce({ gateway, cipher: TEST_CIPHER, clock }, refund, testPayment);
    assert.equal(res.status, 'failed');
    assert.equal(res.manual, true);
    assert.equal(res.failureReason, 'gateway_unavailable');
    assert.equal(res.attempts, 6);
  });

  test('awaiting_account, done and failed refunds are returned unchanged without a gateway call', async () => {
    const gateway = new FakePaymentGateway();
    for (const status of ['awaiting_account', 'done', 'failed'] as const) {
      const refund = makeRefund({ status });
      const res = await sendRefundOnce({ gateway, cipher: TEST_CIPHER, clock }, refund, testPayment);
      assert.deepEqual(res, refund);
    }
    assert.equal(gateway.refundCalls.length, 0);
  });

  test('a pending bank_transfer refund without destination is failed, manual, no_destination, without a call', async () => {
    const gateway = new FakePaymentGateway();
    const refund = makeRefund({ method: 'bank_transfer', destination: null, attempts: 2 });
    const res = await sendRefundOnce({ gateway, cipher: TEST_CIPHER, clock }, refund, testPayment);
    assert.equal(res.status, 'failed');
    assert.equal(res.manual, true);
    assert.equal(res.failureReason, 'no_destination');
    assert.equal(res.attempts, 2); // attempts not bumped when no call was made
    assert.equal(gateway.refundCalls.length, 0);
  });

  test('sending the same refund twice reaches the gateway under one id', async () => {
    const gateway = new FakePaymentGateway();
    const refund = makeRefund();
    await sendRefundOnce({ gateway, cipher: TEST_CIPHER, clock }, refund, testPayment);
    assert.equal(gateway.issuedRefunds.size, 1);
  });
});

describe('mergeRefundOutcome', () => {
  test('null when the stored refund is done', () => {
    const stored = makeRefund({ status: 'done' });
    const next = makeRefund({ status: 'failed', failureReason: 'err' });
    assert.equal(mergeRefundOutcome(stored, next), null);
  });

  test('null when the stored refund is awaiting_account', () => {
    const stored = makeRefund({ status: 'awaiting_account' });
    const next = makeRefund({ status: 'done' });
    assert.equal(mergeRefundOutcome(stored, next), null);
  });

  test('a failed refund accepts done and nothing else', () => {
    const stored = makeRefund({ status: 'failed', manual: true });
    assert.equal(mergeRefundOutcome(stored, makeRefund({ status: 'pending' })), null);
    assert.equal(mergeRefundOutcome(stored, makeRefund({ status: 'failed' })), null);
    const done = mergeRefundOutcome(stored, makeRefund({ status: 'done', providerRef: 'ref_1' }));
    assert.ok(done);
    assert.equal(done.status, 'done');
    assert.equal(done.manual, false);
    assert.equal(done.providerRef, 'ref_1');
  });

  test('pending accepts pending, done and failed', () => {
    const stored = makeRefund({ status: 'pending', attempts: 1 });
    const nextDone = makeRefund({ status: 'done', attempts: 2 });
    const resDone = mergeRefundOutcome(stored, nextDone);
    assert.ok(resDone);
    assert.equal(resDone.status, 'done');

    const nextFailed = makeRefund({ status: 'failed', manual: true, failureReason: 'err', attempts: 2 });
    const resFailed = mergeRefundOutcome(stored, nextFailed);
    assert.ok(resFailed);
    assert.equal(resFailed.status, 'failed');
    assert.equal(resFailed.failureReason, 'err');

    const nextPending = makeRefund({ status: 'pending', attempts: 2, providerRef: 'p_1' });
    const resPending = mergeRefundOutcome(stored, nextPending);
    assert.ok(resPending);
    assert.equal(resPending.status, 'pending');
    assert.equal(resPending.providerRef, 'p_1');
  });

  test('only outcome fields are copied', () => {
    const stored = makeRefund({
      status: 'pending',
      amount: 100_000,
      confirmBy: '2026-10-16T10:00:00.000Z',
      destination: {
        bankCode: 'VCB',
        bankName: 'Vietcombank',
        accountNumberEnc: 'enc_1',
        accountLast4: '1234',
        holderName: 'TEST',
        source: 'payer',
      },
    });
    const next = makeRefund({
      status: 'done',
      amount: 999_999, // should be ignored
      confirmBy: null, // should be ignored
      destination: null, // should be ignored
      providerRef: 'ref_x',
      attempts: 3,
    });
    const merged = mergeRefundOutcome(stored, next);
    assert.ok(merged);
    assert.equal(merged.status, 'done');
    assert.equal(merged.amount, 100_000);
    assert.equal(merged.confirmBy, '2026-10-16T10:00:00.000Z');
    assert.ok(merged.destination);
    assert.equal(merged.providerRef, 'ref_x');
  });

  test('attempts is the larger of the two', () => {
    const stored = makeRefund({ attempts: 4 });
    const next = makeRefund({ attempts: 2, status: 'pending' });
    const merged = mergeRefundOutcome(stored, next);
    assert.ok(merged);
    assert.equal(merged.attempts, 4);
  });
});
