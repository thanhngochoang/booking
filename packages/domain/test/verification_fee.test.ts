import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createVerificationWorld, type VerificationWorld } from './support/verification_world.js';
import { createBookingWorld } from './support/booking_world.js';
import {
  checkVerificationFee,
  startVerificationFee,
  verificationFeePayments,
  verificationFeeRefundHandler,
} from '../src/verification_fee.js';
import { confirmPhoneVerified } from '../src/verification_use_cases.js';
import { fakeTransferFor } from '../src/fake_payment_gateway.js';
import { settleTransfer } from '../src/payment_settlement.js';
import { applyRefundEvent, resendPendingRefunds } from '../src/refund_subjects.js';
import { verifyPaymentLedgerInvariant, type Payment, type Refund } from '../src/escrow.js';
import { PLATFORM_PAYEE } from '../src/payout.js';

function must<T>(v: T | null | undefined): T {
  if (v === null || v === undefined) throw new Error('expected a value');
  return v;
}

/** A provider with the phone step done and an open bank-QR fee payment. */
async function openFee(world: VerificationWorld, method: 'bank_qr' | 'momo' | 'zalopay' = 'bank_qr', uid = 'p1') {
  await confirmPhoneVerified(world.deps, uid).catch(() => undefined);
  return startVerificationFee(world.deps, uid, { method });
}

const paymentOf = (world: VerificationWorld, id: string): Payment => must(world.store.payments.get(id));
const refundsOf = (world: VerificationWorld, paymentId: string): Refund[] =>
  [...world.store.refunds.values()].filter((r) => r.paymentId === paymentId);
const ledgerOf = (world: VerificationWorld, paymentId: string) =>
  world.store.ledger.filter((e) => e.paymentId === paymentId);

describe('verification_fee: VerificationFeeSettler through V1 settlement', () => {
  it('an exact transfer records the fee step, escrow released, payment_received plus fee_charged, in_progress', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    const inst = await openFee(world);

    const res = await world.payFee(inst.paymentId);
    assert.equal(res.outcome, 'paid');

    const p = paymentOf(world, inst.paymentId);
    assert.equal(p.status, 'paid');
    assert.equal(p.escrowStatus, 'released');
    assert.equal(p.releasedAt, world.clock.now().toISOString());
    assert.equal(p.payeeId, PLATFORM_PAYEE);
    assert.equal(p.payer?.accountLast4, '3456');

    const rec = must(world.store.verifications.get('p1'));
    assert.deepEqual(rec.steps.fee, { paymentId: inst.paymentId, amount: 99_000, paidAt: world.clock.now().toISOString() });
    assert.equal(rec.status, 'in_progress');
    assert.equal(rec.kind, 'individual');

    const ledger = ledgerOf(world, inst.paymentId);
    assert.deepEqual(
      ledger.map((e) => [e.type, e.accountOwnerId, e.amount]),
      [['payment_received', 'platform_escrow', 99_000], ['fee_charged', 'platform_revenue', 99_000]],
    );
    assert.equal(verifyPaymentLedgerInvariant(p, refundsOf(world, p.id), ledger), true);
  });

  it('a second paid fee for the same attempt is refunded 100% as duplicate_verification_fee', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    const qr = await openFee(world, 'bank_qr');
    const momo = await startVerificationFee(world.deps, 'p1', { method: 'momo' });
    assert.notEqual(qr.paymentId, momo.paymentId);

    assert.equal((await world.payFee(qr.paymentId)).outcome, 'paid');
    const second = await world.payFee(momo.paymentId);
    assert.equal(second.outcome, 'refunded');
    assert.equal(second.paymentStatus, 'refunded');

    const p = paymentOf(world, momo.paymentId);
    assert.equal(p.escrowStatus, 'refunded');
    const [refund, ...more] = refundsOf(world, momo.paymentId);
    assert.equal(more.length, 0);
    assert.equal(refund?.reason, 'duplicate_verification_fee');
    assert.equal(refund?.amount, 99_000);
    assert.equal(refund?.percent, 100);
    assert.equal(refund?.fromEscrow, true);
    assert.equal(refund?.subjectType, 'verification_fee');
    assert.equal(refund?.status, 'done');
    assert.equal(world.gateway.issuedRefunds.get(must(refund).id), 99_000);
    // Only the first payment is the fee; no fee_charged for the duplicate.
    assert.equal(must(world.store.verifications.get('p1')).steps.fee?.paymentId, qr.paymentId);
    assert.deepEqual(ledgerOf(world, momo.paymentId).map((e) => e.type), ['payment_received', 'refund_issued']);
    assert.equal(verifyPaymentLedgerInvariant(p, refundsOf(world, p.id), ledgerOf(world, p.id)), true);
  });

  it('the same transaction id applies once', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    const inst = await openFee(world);
    const n = fakeTransferFor(paymentOf(world, inst.paymentId) as Payment & { transferCode: string }, 'exact', world.clock.now());

    assert.equal((await settleTransfer(world.settlement, n)).outcome, 'paid');
    assert.equal((await settleTransfer(world.settlement, n)).outcome, 'duplicate');
    assert.equal(ledgerOf(world, inst.paymentId).filter((e) => e.type === 'payment_received').length, 1);
    assert.equal(world.store.transferRecords.get(`fake_${n.txnId}`)?.outcome, 'paid');
  });

  it('an over transfer refunds the excess (overpaid)', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    const inst = await openFee(world);

    const res = await world.payFee(inst.paymentId, 'over');
    assert.equal(res.outcome, 'paid_with_refund');

    const p = paymentOf(world, inst.paymentId);
    assert.equal(p.status, 'paid');
    assert.equal(p.escrowStatus, 'released');
    const [refund] = refundsOf(world, inst.paymentId);
    assert.equal(refund?.reason, 'overpaid_excess');
    assert.equal(refund?.amount, 50_000);
    assert.equal(refund?.fromEscrow, false);
    assert.equal(refund?.method, 'bank_transfer');
    assert.equal(refund?.destination?.accountLast4, '3456');
    assert.equal(refund?.status, 'done');
    assert.equal(must(world.store.verifications.get('p1')).steps.fee?.amount, 99_000);
    assert.equal(verifyPaymentLedgerInvariant(p, refundsOf(world, p.id), ledgerOf(world, p.id)), true);
  });

  it('expire refunds what an unpaid fee received', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    const inst = await openFee(world);
    assert.equal((await world.payFee(inst.paymentId, 'under')).outcome, 'partial');

    const settler = must(world.settlement.subjects.verification_fee);
    assert.equal(await settler.expire(inst.paymentId, world.clock.now()), 'unchanged');
    world.clock.advanceMinutes(16);
    assert.equal(await settler.expire(inst.paymentId, world.clock.now()), 'expired');

    const p = paymentOf(world, inst.paymentId);
    assert.equal(p.status, 'expired');
    const [refund] = refundsOf(world, inst.paymentId);
    assert.equal(refund?.reason, 'underpaid_expired');
    assert.equal(refund?.amount, 49_500);
    assert.equal(refund?.status, 'done');
    assert.equal(must(world.store.verifications.get('p1')).steps.fee, null);
    assert.equal(verifyPaymentLedgerInvariant(p, refundsOf(world, p.id), ledgerOf(world, p.id)), true);
  });

  it("a throwing refund stays pending for V2's re-send", async () => {
    const world = createVerificationWorld({ feeRequired: true });
    const qr = await openFee(world, 'bank_qr');
    const momo = await startVerificationFee(world.deps, 'p1', { method: 'momo' });
    await world.payFee(qr.paymentId);

    world.gateway.refundThrowCount = 1;
    assert.equal((await world.payFee(momo.paymentId)).outcome, 'refunded');
    const [pending] = refundsOf(world, momo.paymentId);
    assert.equal(pending?.status, 'pending');
    assert.equal(pending?.attempts, 1);

    world.clock.advanceMinutes(10);
    const out = await verificationFeeRefundHandler(world.deps).resend(must(pending));
    assert.equal(out.status, 'done');
    assert.equal(world.store.refunds.get(must(pending).id)?.status, 'done');
    // The same refund id both times: the gateway never pays it twice.
    assert.deepEqual(world.gateway.refundCalls, [must(pending).id, must(pending).id]);
  });

  it('the payment clock re-send and refund events reach subjects.verification_fee', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    const qr = await openFee(world, 'bank_qr');
    const momo = await startVerificationFee(world.deps, 'p1', { method: 'momo' });
    await world.payFee(qr.paymentId);
    world.gateway.refundThrowCount = 1;
    await world.payFee(momo.paymentId);
    const pending = must(refundsOf(world, momo.paymentId)[0]);

    // In Firestore every subject's refunds share one collection; the booking store stands in for it.
    const clockWorld = createBookingWorld();
    clockWorld.store.payments.set(momo.paymentId, paymentOf(world, momo.paymentId));
    clockWorld.store.refunds.set(pending.id, pending);
    clockWorld.clock.advanceMinutes(10);
    const subjects = { verification_fee: verificationFeeRefundHandler(world.deps) };

    assert.deepEqual(await resendPendingRefunds(clockWorld.deps, subjects), { resent: 1, failed: 0, skipped: 0 });
    assert.equal(world.store.refunds.get(pending.id)?.status, 'done');

    // A later failed event never undoes a done refund; an event for a pending one is applied.
    assert.equal(
      await applyRefundEvent(clockWorld.deps, { refundId: pending.id, provider: 'fake', status: 'failed' }, subjects),
      'refund_unchanged',
    );
    world.store.refunds.set(pending.id, { ...pending, status: 'pending' });
    assert.equal(
      await applyRefundEvent(clockWorld.deps, { refundId: pending.id, provider: 'fake', status: 'done', providerRef: 'gw_1' }, subjects),
      'refund_applied',
    );
    assert.equal(world.store.refunds.get(pending.id)?.providerRef, 'gw_1');
  });

  it("V1's confirmFakePayment pays a fee and returns the verification status", async () => {
    const world = createVerificationWorld({ feeRequired: true });
    const inst = await openFee(world);

    const res = await world.payFee(inst.paymentId);
    assert.deepEqual(res, {
      outcome: 'paid',
      subjectType: 'verification_fee',
      paymentStatus: 'paid',
      subjectStatus: 'in_progress',
    });
  });

  it('checkVerificationFee settles a transfer found by queryPayment', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    const inst = await openFee(world);

    assert.deepEqual((await verificationFeePayments(world.deps, 'p1')).map((p) => p.id), [inst.paymentId]);
    const before = await checkVerificationFee(world.deps, 'p1');
    assert.equal(before.paid, false);
    assert.equal(before.instructions?.paymentId, inst.paymentId);

    const p = paymentOf(world, inst.paymentId) as Payment & { transferCode: string };
    world.gateway.pushTransfer(p.id, fakeTransferFor(p, 'exact', world.clock.now()));
    const after = await checkVerificationFee(world.deps, 'p1');
    assert.deepEqual(after, { paid: true, instructions: null });
    assert.equal(must(world.store.verifications.get('p1')).steps.fee?.paymentId, inst.paymentId);
    assert.deepEqual(await verificationFeePayments(world.deps, 'p1'), []);
  });
});
