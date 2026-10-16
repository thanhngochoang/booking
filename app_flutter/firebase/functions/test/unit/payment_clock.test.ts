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

  it('the clock expires a ticket payment through liveSettlementDeps-shaped deps', async () => {
    const { createTicketPaymentWorld } = await import('../../../../../packages/domain/test/support/event_world.js');
    const { saveEventDraft, publishEvent, registerEvent, BookingPaymentSettler } = await import('@photobooking/domain');
    const tw = createTicketPaymentWorld();
    const bw = paymentWorld();
    const host = { uid: 'ph1', staffRole: null } as const;
    const eventId = '01ARZ3NDEKTSV4RRFFQ69G5F77';
    const path = `eventCovers/ph1/${eventId}/c.jpg`;
    await saveEventDraft(tw.deps, host, {
      eventId, title: 'Walk', type: 'photo_walk', coverUrl: `https://s.test/${path}`, coverPath: path,
      startAt: '2026-10-15T02:00:00.000Z', endAt: '2026-10-15T05:00:00.000Z',
      location: { name: 'Lake', lat: 21.0, lng: 105.8 }, capacity: 5, price: 200_000,
    });
    await publishEvent(tw.deps, host, { eventId });
    const cu1 = { uid: 'cu1', staffRole: null } as const;
    const r = await registerEvent(tw.deps, cu1, {
      eventId, quantity: 1, name: 'An', phone: '0901234567', method: 'bank_qr',
    });
    assert.ok(r.paymentId);
    const p = tw.store.payments.get(r.paymentId);
    assert.ok(p);
    const expiresAt = p.expiresAt;
    assert.ok(expiresAt);
    const eventSettler = tw.settlement.subjects.event_registration;
    assert.ok(eventSettler);

    const settlementDeps = {
      payments: tw.deps.payments,
      gateway: tw.deps.gateway,
      clock: tw.deps.clock,
      subjects: {
        booking: new BookingPaymentSettler(bw.deps),
        event_registration: eventSettler,
      },
    };

    // Advance clock past 10-minute hold expiry
    tw.clock.now = () => new Date(Date.parse(expiresAt) + 1000);

    const res = await handlePaymentClock(settlementDeps);
    assert.equal(res.expired, 1);
    assert.equal(tw.store.payments.get(p.id)?.status, 'expired');
  });
});
