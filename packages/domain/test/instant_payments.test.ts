import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { fakeTransferFor } from '../src/fake_payment_gateway.js';
import type { Payment } from '../src/escrow.js';
import { InstantPaymentSettler, sendInstantRefunds } from '../src/instant_payments.js';
import type { InstantDeps } from '../src/instant_ports.js';
import { cancelInstantRequest, inviteInstant } from '../src/instant_requests.js';
import { transferCodeFor } from '../src/payment_code.js';
import { transferRecordId } from '../src/payment_settlement.js';
import { MIN, T0, at } from './support/instant_fixtures.js';
import { LAN, createInstantWorld, lanRequests, type InstantWorld } from './support/instant_world.js';

/** Lan's request with one open bank-QR payment (first invite, nothing paid yet). */
async function openPayment(w: InstantWorld, ids: readonly string[] = ['p1']): Promise<{ requestId: string; payment: Payment }> {
  const requestId = await lanRequests(w);
  const res = await inviteInstant(w.deps, LAN, {
    requestId, photographerIds: ids, skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr',
  });
  assert.equal(res.kind, 'payment');
  const payment = w.store.payments.get(res.kind === 'payment' ? res.instructions.paymentId : '');
  assert.ok(payment);
  return { requestId, payment };
}

const exact = (p: Payment, now: Date) => fakeTransferFor(p as Payment & { transferCode: string }, 'exact', now);

describe('InstantPaymentSettler', () => {
  test('settle is idempotent per transfer', async () => {
    const w = createInstantWorld();
    const { requestId, payment } = await openPayment(w);
    const settler = new InstantPaymentSettler(w.deps);
    const t = exact(payment, T0);
    assert.equal(await settler.settle(payment.id, t), 'paid');
    assert.equal(await settler.settle(payment.id, t), 'duplicate');
    assert.equal([...w.store.ledger.values()].filter((e) => e.type === 'payment_received').length, 1);
    assert.equal(w.store.offersOf('p1').length, 1);
    assert.equal(w.pushes.get('p1')?.length, 1);
    assert.equal(w.store.payments.get(payment.id)?.status, 'paid');
    assert.equal(w.store.requests.get(requestId)?.status, 'searching');
    assert.equal(w.store.transferRecords.get(transferRecordId(t))?.outcome, 'paid');
  });

  test('settle returns duplicate for a replayed transfer record', async () => {
    const w = createInstantWorld();
    const { requestId, payment } = await openPayment(w);
    const t = exact(payment, T0);
    w.store.transferRecords.set(transferRecordId(t), {
      id: transferRecordId(t), provider: t.provider, txnId: t.txnId, receivedAt: t.receivedAt, outcome: 'paid', paymentId: payment.id,
    });
    const commits = w.store.commits;
    assert.equal(await new InstantPaymentSettler(w.deps).settle(payment.id, t), 'duplicate');
    assert.equal(w.store.commits, commits);
    assert.equal(w.store.payments.get(payment.id)?.status, 'created');
    assert.equal(w.store.requests.get(requestId)?.status, 'pending_payment');
    assert.equal(w.store.ledger.size, 0);
  });

  test('expire uses expireUnpaid', async () => {
    const w = createInstantWorld();
    const { payment } = await openPayment(w);
    const settler = new InstantPaymentSettler(w.deps);
    const half = fakeTransferFor(payment as Payment & { transferCode: string }, 'under', T0);
    assert.equal(await settler.settle(payment.id, half), 'partial');
    assert.equal(await settler.expire(payment.id, at(14 * MIN)), 'unchanged');
    assert.equal(await settler.expire(payment.id, at(15 * MIN)), 'expired');
    const p = w.store.payments.get(payment.id);
    assert.deepEqual([p?.status, p?.escrowStatus], ['expired', 'refunded']);
    const refunds = [...w.store.refunds.values()];
    assert.deepEqual(refunds.map((r) => [r.reason, r.amount, r.fromEscrow]), [['underpaid_expired', 345_000, false]]);
    // Sent at once with V2's sendRefundOnce (the fake transfer carries a payer account).
    assert.deepEqual(w.gateway.refundCalls, [refunds[0]?.id]);
    assert.equal(w.store.refunds.get(refunds[0]?.id ?? '')?.status, 'done');
    assert.equal(await settler.expire(payment.id, at(16 * MIN)), 'unchanged');
  });

  test('a refund whose outcome cannot be stored stays pending and is logged as a count', async () => {
    const w = createInstantWorld();
    const { payment } = await openPayment(w);
    const settler = new InstantPaymentSettler(w.deps);
    assert.equal(await settler.settle(payment.id, fakeTransferFor(payment as Payment & { transferCode: string }, 'under', T0)), 'partial');
    // The expiry commits; the transaction that stores the gateway's answer fails.
    const logged: number[] = [];
    let transactions = 0;
    const deps: InstantDeps = {
      ...w.deps,
      store: {
        findDue: (now, limit) => w.store.findDue(now, limit),
        runTransaction: (fn) => (++transactions > 1 ? Promise.reject(new Error('store down')) : w.store.runTransaction(fn)),
      },
      log: { refundSendsFailed: (n) => logged.push(n) },
    };
    assert.equal(await new InstantPaymentSettler(deps).expire(payment.id, at(15 * MIN)), 'expired');
    const refund = [...w.store.refunds.values()][0];
    assert.equal(refund?.status, 'pending');
    assert.deepEqual(w.gateway.refundCalls, [refund?.id]);
    assert.deepEqual(logged, [1]);
  });

  test('sendInstantRefunds logs nothing when every send is stored', async () => {
    const w = createInstantWorld();
    const logged: number[] = [];
    assert.deepEqual(await sendInstantRefunds({ ...w.deps, log: { refundSendsFailed: (n) => logged.push(n) } }, []), { failed: 0 });
    assert.deepEqual(logged, []);
  });

  test("statusOf(payment) returns the status of payment.subjectId's request, gone when missing", async () => {
    const w = createInstantWorld();
    const { requestId, payment } = await openPayment(w);
    const settler = new InstantPaymentSettler(w.deps);
    assert.equal(await settler.statusOf(payment), 'pending_payment');
    await cancelInstantRequest(w.deps, LAN, { requestId, dryRun: false });
    assert.equal(await settler.statusOf(payment), 'cancelled_by_customer');
    w.store.requests.delete(requestId);
    assert.equal(await settler.statusOf(payment), 'gone');
  });

  test('the payment id comes from freshPaymentId (code unique across subjects)', async () => {
    const w = createInstantWorld();
    const requestId = await lanRequests(w);
    // The next id the generator draws already names a transfer code of another subject's payment.
    const probe = w.deps.ids.newId();
    const taken = `id_${String(Number(probe.slice(3)) + 1).padStart(3, '0')}`;
    w.store.payments.set('vf_1', {
      id: 'vf_1', subjectType: 'verification_fee', subjectId: 'p9', payerId: 'p9', payeeId: 'platform', provider: 'fake',
      amount: 99_000, status: 'expired', escrowStatus: 'refunded', idempotencyKey: 'vfee_p9_1_bank_qr',
      transferCode: transferCodeFor(taken), createdAt: T0.toISOString(), updatedAt: T0.toISOString(),
    });
    const res = await inviteInstant(w.deps, LAN, {
      requestId, photographerIds: ['p1'], skipped: [], expectedAmountVnd: 690_000, payMethod: 'bank_qr',
    });
    assert.equal(res.kind, 'payment');
    const paymentId = res.kind === 'payment' ? res.instructions.paymentId : '';
    assert.notEqual(paymentId, taken);
    assert.notEqual(res.kind === 'payment' ? res.instructions.transferCode : '', transferCodeFor(taken));
    assert.equal(w.store.payments.get(paymentId)?.transferCode, transferCodeFor(paymentId));
  });
});
