import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { handlePaymentClock } from '../../src/scheduled/payment_clock.js';
import { PAYMENT_CLOCK_OPTIONS, REGION, WEBHOOK_OPTIONS } from '../../src/config.js';
import { captureLogs, openPayment, paymentWorld } from './support/payment_world.js';

describe('payment clock', () => {
  it('the clock runs runPaymentSweeps and logs counts only', async (t) => {
    const w = paymentWorld();
    // An under-paid payment found by reconciliation (a missed webhook), then expired and refunded.
    const p = await openPayment(w);
    w.gateway.pushTransfer(p.paymentId, {
      provider: 'fake',
      txnId: 'txn_missed',
      amount: 400_000,
      content: `${p.transferCode} NGUYEN VAN PAYER`,
      receivedAt: '2026-10-01T10:02:00.000Z',
      raw: '{"payer":{"name":"NGUYEN VAN PAYER"}}',
      payer: { name: 'NGUYEN VAN PAYER', accountMasked: '•••• 5555' },
    });
    w.advanceMinutes(16);

    let results: Awaited<ReturnType<typeof handlePaymentClock>> | undefined;
    const lines = await captureLogs(t, async () => {
      results = await handlePaymentClock(w.deps);
    });
    assert.deepEqual(results, { reconciled: 1, expired: 1, refunded: 1, reconcileFailed: 0, expireFailed: 0 });
    assert.equal((await w.store.getPayment(p.paymentId))?.status, 'expired');

    const logged = lines.filter((l) => l.includes('paymentClock'));
    assert.equal(logged.length, 1, lines.join(''));
    const entry = JSON.parse(logged[0] ?? '{}') as Record<string, unknown>;
    const { severity: _s, message: _m, ...fields } = entry;
    void _s;
    void _m;
    assert.deepEqual(fields, { reconciled: 1, expired: 1, refunded: 1, reconcileFailed: 0, expireFailed: 0 });
    for (const l of lines) {
      assert.doesNotMatch(l, /PAYER|5555/, l);
      assert.doesNotMatch(l, new RegExp(p.paymentId), l);
    }
  });

  it('a sweep that throws is logged without details and rethrown', async (t) => {
    const w = paymentWorld();
    const failing = { ...w.deps, store: Object.assign(Object.create(w.store) as typeof w.store, {
      findPaymentsToReconcile: async () => { throw new Error('index missing for payer NGUYEN'); },
    }) };
    const lines = await captureLogs(t, () => assert.rejects(handlePaymentClock(failing)));
    const logged = lines.filter((l) => l.includes('paymentClock'));
    assert.equal(logged.length, 1, lines.join(''));
    assert.doesNotMatch(logged[0] ?? '', /NGUYEN/);
  });

  it('runs every 5 minutes, one instance, finishing before the next run; the webhook is public in the region', () => {
    assert.equal(PAYMENT_CLOCK_OPTIONS.schedule, 'every 5 minutes');
    assert.equal(PAYMENT_CLOCK_OPTIONS.region, REGION);
    assert.equal(PAYMENT_CLOCK_OPTIONS.maxInstances, 1);
    assert.ok(PAYMENT_CLOCK_OPTIONS.timeoutSeconds < 300);
    assert.equal(WEBHOOK_OPTIONS.region, REGION);
    assert.equal(WEBHOOK_OPTIONS.invoker, 'public');
  });
});
