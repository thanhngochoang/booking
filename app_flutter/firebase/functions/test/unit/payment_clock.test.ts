import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { handlePaymentClock } from '../../src/scheduled/payment_clock.js';
import { PAYMENT_CLOCK_OPTIONS, REGION, WEBHOOK_OPTIONS } from '../../src/config.js';
import { captureLogs, openPayment, paymentWorld } from './support/payment_world.js';
import { transitionBooking, type RefundAccountDeps } from '@photobooking/domain';

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
    assert.deepEqual(results, {
      reconciled: 1,
      expired: 1,
      refunded: 1,
      refundsResent: 0,
      reconcileFailed: 0,
      expireFailed: 0,
      resendFailed: 0,
      skippedRefunds: 0,
      refundAccountsConfirmed: 0,
      confirmFailed: 0,
    });
    assert.equal((await w.store.getPayment(p.paymentId))?.status, 'expired');

    const logged = lines.filter((l) => l.includes('paymentClock'));
    assert.equal(logged.length, 1, lines.join(''));
    const entry = JSON.parse(logged[0] ?? '{}') as Record<string, unknown>;
    const { severity: _s, message: _m, ...fields } = entry;
    void _s;
    void _m;
    assert.deepEqual(fields, {
      reconciled: 1,
      expired: 1,
      refunded: 1,
      refundsResent: 0,
      reconcileFailed: 0,
      expireFailed: 0,
      resendFailed: 0,
      skippedRefunds: 0,
      refundAccountsConfirmed: 0,
      confirmFailed: 0,
    });
    for (const l of lines) {
      assert.doesNotMatch(l, /PAYER|5555/, l);
      assert.doesNotMatch(l, new RegExp(p.paymentId), l);
    }
  });

  it('the clock re-sends a pending refund through the default subjects', async () => {
    const w = paymentWorld();
    const p = await openPayment(w);
    const at = new Date('2026-10-01T10:00:00.000Z');
    await w.store.runTransaction(async (tx) => {
      tx.setPayment({
        id: p.paymentId,
        subjectType: 'booking',
        subjectId: p.bookingId,
        payerId: 'c1',
        payeeId: 'p1',
        provider: 'fake',
        amount: 1_000_000,
        status: 'paid',
        escrowStatus: 'held',
        idempotencyKey: 'idem_1',
        createdAt: at.toISOString(),
        updatedAt: at.toISOString(),
      });
      tx.addRefund({
        id: 'ref_pending_1',
        paymentId: p.paymentId,
        subjectType: 'booking',
        amount: 1_000_000,
        percent: 100,
        status: 'pending',
        method: 'gateway',
        attempts: 1,
        lastAttemptAt: new Date(at.getTime() - 15 * 60_000).toISOString(),
        manual: false,
        fromEscrow: true,
        createdAt: at.toISOString(),
        updatedAt: at.toISOString(),
      });
    });

    const res = await handlePaymentClock(w.deps, { refundSubjects: {} });
    assert.equal(res.refundsResent, 1);
    const ref = await w.store.getRefund('ref_pending_1');
    assert.equal(ref?.status, 'done');
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

  it('confirmDueRefundAccounts runs as the last named step and a failure in it does not stop the other steps', async (t) => {
    const { createBookingWorld, newDraft, payDraft } = await import('../../../../../packages/domain/test/support/booking_world.js');
    const { refundAccountDepsOf } = await import('../../../../../packages/domain/test/support/refund_account_world.js');
    // c1's cancelled bank-QR booking: the refund waits for the account, 24 hours by default.
    const w = createBookingWorld();
    const draft = await newDraft(w);
    const { paymentId } = await payDraft(w, draft.id);
    await transitionBooking(w.deps, { bookingId: draft.id, action: 'cancel', actorId: 'c1', reason: 'Bận' });
    const [refund] = await w.store.getRefundsForPayment(paymentId);
    assert.equal(refund?.status, 'awaiting_account');
    const refundAccounts = refundAccountDepsOf({ bookings: w.deps });

    // Before confirmBy nothing moves; at confirmBy the step sends it to the payer.
    w.clock.advanceHours(23);
    assert.equal((await handlePaymentClock(w.deps, { refundSubjects: {}, refundAccounts })).refundAccountsConfirmed, 0);
    w.clock.advanceHours(1);
    let results: Awaited<ReturnType<typeof handlePaymentClock>> | undefined;
    const lines = await captureLogs(t, async () => {
      results = await handlePaymentClock(w.deps, { refundSubjects: {}, refundAccounts });
    });
    assert.deepEqual([results?.refundAccountsConfirmed, results?.confirmFailed], [1, 0]);
    assert.equal((await w.store.getRefund(refund?.id ?? ''))?.status, 'done');
    assert.deepEqual(w.gateway.refundCalls, [refund?.id]);
    const logged = lines.filter((l) => l.includes('paymentClock completed'));
    assert.match(logged[0] ?? '', /"refundAccountsConfirmed":1/);
    for (const l of lines) assert.doesNotMatch(l, /3456|NGUYEN/, l);

    // A failing step (its query throws) is counted; the steps before it still ran.
    const p = paymentWorld();
    const open = await openPayment(p);
    p.gateway.pushTransfer(open.paymentId, {
      provider: 'fake', txnId: 'txn_late_webhook', amount: open.amount, content: open.transferCode,
      receivedAt: '2026-10-01T10:01:00.000Z',
    });
    p.advanceMinutes(4);
    const broken: RefundAccountDeps = {
      ...refundAccountDepsOf({ bookings: p.deps }),
      bookings: { ...p.deps, store: Object.assign(Object.create(p.store) as typeof p.store, {
        awaitingRefundsDue: async () => { throw new Error('index missing'); },
      }) },
    };
    const res = await handlePaymentClock(p.deps, { refundSubjects: {}, refundAccounts: broken });
    assert.deepEqual([res.reconciled, res.refundAccountsConfirmed, res.confirmFailed], [1, 0, 1]);
    assert.equal((await p.store.getPayment(open.paymentId))?.status, 'paid');
  });
});
