import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  VerificationFeeSettler,
  bookingSettlement,
  confirmFakePayment,
  startVerificationFee,
  type EarningsDeps,
  type Payment,
  type SettlementDeps,
} from '@photobooking/domain';
import { handlePaymentWebhook } from '../../src/http/payment_webhook.js';
import { FAKE_SIGNATURE_HEADER, signFakeWebhook } from '../../src/infra/fake_webhook.js';
import { paymentToFirestore } from '../../src/infra/booking_firestore.js';
import { liveSettlementDeps, settlementSubjectsOf } from '../../src/infra/live_payments.js';
import { liveRefundSubjects, refundSubjectsOf } from '../../src/infra/live_refunds.js';
import { handlePaymentClock } from '../../src/scheduled/payment_clock.js';
import { handlePaymentWrite } from '../../src/triggers/payment_write.js';
import { SECRET, WEBHOOK_ENV, paymentWorld } from './support/payment_world.js';
import { NOW, verificationWorld } from './verification_support.js';

// The S21 fee (#203) on V1's settlement and V2's refund re-send, through the same subject maps
// liveSettlementDeps() and liveRefundSubjects() are built from.

function must<T>(v: T | null | undefined): T {
  assert.ok(v !== null && v !== undefined);
  return v;
}

function feeWorld() {
  const w = verificationWorld({ feeRequired: true });
  const settlement: SettlementDeps = {
    payments: w.deps.payments,
    gateway: w.gateway,
    clock: w.deps.clock,
    subjects: settlementSubjectsOf({ verification: w.deps }),
  };
  const openFee = async (method: 'bank_qr' | 'momo' = 'bank_qr') => {
    const inst = await startVerificationFee(w.deps, 'p1', { method });
    return must(w.store.payments.get(inst.paymentId)) as Payment & { transferCode: string };
  };
  return { ...w, settlement, openFee };
}

function signed(rawBody: string) {
  return { provider: 'fake', rawBody, headers: { [FAKE_SIGNATURE_HEADER]: signFakeWebhook(rawBody, SECRET) } };
}

describe('verification fee settlement wiring', () => {
  it('liveSettlementDeps registers the fee settler and liveRefundSubjects its refund handler', () => {
    assert.ok(liveSettlementDeps().subjects.verification_fee instanceof VerificationFeeSettler);
    const handler = liveRefundSubjects().verification_fee;
    assert.equal(typeof handler?.resend, 'function');
    assert.equal(typeof handler?.record, 'function');
  });

  it('a webhook transfer for a verification fee is settled, not unmatched', async () => {
    const w = feeWorld();
    const p = await w.openFee();
    const raw = JSON.stringify({
      txnId: 'txn_fee_1',
      amount: p.amount,
      content: `CK ${p.transferCode} phi xac minh`,
      receivedAt: NOW.toISOString(),
    });

    const res = await handlePaymentWebhook(signed(raw), w.settlement, WEBHOOK_ENV);

    assert.deepEqual(res, { status: 200, body: { ok: true, outcome: 'paid' } });
    const paid = must(w.store.payments.get(p.id));
    assert.equal(paid.status, 'paid');
    assert.equal(paid.escrowStatus, 'released');
    assert.equal(must(w.store.verifications.get('p1')).steps.fee?.paymentId, p.id);
    assert.equal(w.store.transferRecords.get('fake_txn_fee_1')?.outcome, 'paid');
    const types = w.store.ledger.filter((e) => e.paymentId === p.id).map((e) => e.type).sort();
    assert.deepEqual(types, ['fee_charged', 'payment_received']);
  });

  it('a pending fee refund is re-sent by the payment clock', async () => {
    const w = feeWorld();
    const qr = await w.openFee('bank_qr');
    const momo = await w.openFee('momo');
    await confirmFakePayment(w.settlement, { uid: 'p1' }, { paymentId: qr.id });
    // The duplicate fee's refund fails once at the gateway and stays pending.
    w.gateway.refundThrowCount = 1;
    await confirmFakePayment(w.settlement, { uid: 'p1' }, { paymentId: momo.id });
    const pending = must([...w.store.refunds.values()].find((r) => r.paymentId === momo.id));
    assert.equal(pending.status, 'pending');
    assert.equal(pending.subjectType, 'verification_fee');

    // In Firestore every subject's refunds share one collection, read by the booking store; the
    // booking world's store stands in for it, ten minutes later.
    const bw = paymentWorld(new Date(NOW.getTime() + 10 * 60_000));
    bw.store.payments.set(momo.id, must(w.store.payments.get(momo.id)));
    bw.store.refunds.set(pending.id, pending);
    const deps: SettlementDeps = {
      ...bookingSettlement(bw.deps),
      subjects: settlementSubjectsOf({ booking: bw.deps, verification: w.deps }),
    };

    const res = await handlePaymentClock(deps, { refundSubjects: refundSubjectsOf({ verification: w.deps }) });

    assert.equal(res.refundsResent, 1);
    assert.equal(res.skippedRefunds ?? 0, 0);
    assert.equal(w.store.refunds.get(pending.id)?.status, 'done');
  });

  it('a verification fee payment does not refresh earnings', async () => {
    const w = feeWorld();
    const p = await w.openFee();
    assert.equal(p.payeeId, 'platform');
    const unused = new Proxy({}, { get: () => assert.fail('earnings deps touched') }) as EarningsDeps;
    assert.equal(await handlePaymentWrite(p.id, undefined, paymentToFirestore(p), unused), null);
  });
});
