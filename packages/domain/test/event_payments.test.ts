import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError, type ErrorCode } from '../src/errors.js';
import type { EventCaller } from '../src/event.js';
import type { EventPaymentDeps } from '../src/event_ports.js';
import {
  cancelEventWithRefunds, checkTicketPayment, confirmFakeTicketPayment, handleTicketPayment, refundTicket,
  releaseEventHolds, resendTicketRefund, ticketRefundPercent,
} from '../src/event_payments.js';
import { cancelRegistration, registerEvent } from '../src/event_registration.js';
import { runEventSweeps } from '../src/event_sweeps.js';
import { verifyPaymentLedgerInvariant } from '../src/escrow.js';
import { FakePaymentGateway } from '../src/fake_payment_gateway.js';
import { getContactLink } from '../src/get_contact_link.js';
import { MemoryEventStore } from '../src/memory_event_store.js';
import type { RegistrationRecord } from '../src/ports.js';
import { END, START, admin, createEventWorld, cu1, cu2, cu3, must, ph1, publishedEvent, type EventWorld } from './support/event_world.js';

const EV = 'ev1_aaaaaaaaaaaaaaaaaaaa';
const PRICE = 150_000;
const HOUR = 3_600_000;
const code = (c: ErrorCode) => (e: unknown) => e instanceof DomainError && e.code === c;

type PaidWorld = EventWorld & { gateway: FakePaymentGateway; pay: EventPaymentDeps };

async function paidWorld(over: Record<string, unknown> = {}, host: EventCaller = ph1): Promise<PaidWorld> {
  const w = createEventWorld();
  const gateway = new FakePaymentGateway();
  await publishedEvent(w, { price: PRICE, ...over }, host);
  return { ...w, gateway, pay: { ...w.deps, gateway } };
}

const buy = (w: PaidWorld, who: EventCaller, quantity = 1, provider = 'momo') =>
  registerEvent(w.pay, who, { eventId: EV, quantity, name: 'Nguyễn An', provider });

const ev = (w: EventWorld) => must(w.store.events.get(EV));
const reg = (w: EventWorld, id: string) => must(w.store.registrations.get(`${EV}/${id}`));
const pay = (w: EventWorld, id: string | null) => must(w.store.payments.get(must(id)));

/** Registers and confirms through the fake gateway; returns the registration id. */
async function bought(w: PaidWorld, who: EventCaller, quantity = 1): Promise<string> {
  const r = await buy(w, who, quantity);
  await confirmFakeTicketPayment(w.pay, who, { paymentId: r.paymentId });
  return r.registrationId;
}

describe('paid registration', () => {
  test('a paid registration holds seats and returns payUrl and hold expiry', async () => {
    const w = await paidWorld();
    const r = await buy(w, cu1, 2);
    assert.equal(r.status, 'held');
    assert.match(r.payUrl ?? '', /^https:\/\/fake-pay\.local\/checkout\?paymentId=/);
    assert.equal(r.holdExpiresAt?.getTime(), w.clock.now().getTime() + 10 * 60_000);
    const doc = reg(w, r.registrationId);
    assert.deepEqual([doc.status, doc.amount, doc.quantity, doc.contactEligible], ['held', 300_000, 2, false]);
    assert.deepEqual([ev(w).heldCount, ev(w).registeredCount], [2, 0]);
    const p = pay(w, r.paymentId);
    assert.deepEqual(
      [p.subjectType, p.subjectId, p.eventId, p.payerId, p.payeeId, p.amount, p.status, p.escrowStatus, p.idempotencyKey],
      ['event_registration', r.registrationId, EV, 'cu1', 'ph1', 300_000, 'created', 'held', `tkt_${r.registrationId}_momo`],
    );
    assert.equal(p.providerRef, `fake_ref_${p.id}`);
    assert.equal(w.store.contacts.size, 0);
  });

  test('a paid event needs a known provider', async () => {
    const w = await paidWorld();
    await assert.rejects(registerEvent(w.pay, cu1, { eventId: EV, quantity: 1, name: 'An' }), code('invalid_argument'));
    await assert.rejects(buy(w, cu1, 1, 'paypal'), code('invalid_argument'));
    assert.equal(w.store.registrationsOf(EV).length, 0);
  });

  test('without a payment gateway a paid event stays not_eligible (Decision 27)', async () => {
    const w = await paidWorld();
    await assert.rejects(registerEvent(w.deps, cu1, { eventId: EV, quantity: 1, name: 'An', provider: 'momo' }), code('not_eligible'));
  });

  test('the same provider twice reuses the payment', async () => {
    const w = await paidWorld();
    const a = await buy(w, cu1);
    const b = await buy(w, cu1);
    assert.equal(b.registrationId, a.registrationId);
    assert.equal(b.paymentId, a.paymentId);
    assert.equal(w.store.payments.size, 1);
    assert.equal(ev(w).heldCount, 1);
  });

  test('another provider opens a second intent for the same hold', async () => {
    const w = await paidWorld();
    const a = await buy(w, cu1, 1, 'momo');
    const b = await buy(w, cu1, 1, 'vnpay');
    assert.equal(b.registrationId, a.registrationId);
    assert.notEqual(b.paymentId, a.paymentId);
    assert.equal(reg(w, a.registrationId).paymentId, b.paymentId);
    assert.equal(pay(w, b.paymentId).idempotencyKey, `tkt_${a.registrationId}_vnpay`);
    assert.equal(ev(w).heldCount, 1);
  });

  test('Thanh toán tiếp without a provider keeps the provider of the hold\'s payment', async () => {
    const w = await paidWorld();
    const a = await buy(w, cu1, 1, 'vnpay');
    const b = await buy(w, cu1, 1, 'momo'); // the customer switched to MoMo
    const again = await registerEvent(w.pay, cu1, { eventId: EV, quantity: 1, name: 'Nguyễn An' });
    assert.equal(again.registrationId, a.registrationId);
    assert.equal(again.paymentId, b.paymentId);
    assert.equal(pay(w, again.paymentId).provider, 'momo');
    assert.match(again.payUrl ?? '', new RegExp(`paymentId=${must(b.paymentId)}`));
    assert.equal(w.store.payments.size, 2);
    assert.equal(reg(w, a.registrationId).paymentId, b.paymentId);
  });

  test('a lapsed hold tapped again starts a new hold', async () => {
    const w = await paidWorld();
    const a = await buy(w, cu1);
    w.clock.advance(10 * 60_000);
    const b = await buy(w, cu1);
    assert.notEqual(b.registrationId, a.registrationId);
    assert.equal(reg(w, a.registrationId).status, 'cancelled');
    assert.equal(ev(w).heldCount, 1);
  });
});

describe('ticket payment', () => {
  test('payment confirmation makes the ticket paid and moves held to registered', async () => {
    const w = await paidWorld();
    const r = await buy(w, cu1, 2);
    const holdAt = reg(w, r.registrationId).createdAt;
    w.clock.advance(60_000);
    const out = await confirmFakeTicketPayment(w.pay, cu1, { paymentId: r.paymentId });
    assert.deepEqual(out, { status: 'paid' });
    const doc = reg(w, r.registrationId);
    assert.deepEqual([doc.status, doc.contactEligible, doc.paymentId], ['paid', true, r.paymentId]);
    // The hold time stays: the group chat compares it with a moderator removal (N4).
    assert.equal(doc.createdAt.getTime(), holdAt.getTime());
    assert.deepEqual([ev(w).heldCount, ev(w).registeredCount], [0, 2]);
    const p = pay(w, r.paymentId);
    assert.deepEqual([p.status, p.escrowStatus, p.providerRef], ['paid', 'held', `fake_confirmed_${p.id}`]);
    assert.deepEqual(w.store.ledgerOf(p.id).map((e) => [e.type, e.accountOwnerId, e.amount]),
      [['ticket_received', 'platform_escrow', 300_000]]);
    assert.deepEqual(w.store.contacts.get(`${EV}/${r.registrationId}`),
      { name: 'Nguyễn An', phone: '+84912000001', allowZalo: false, allowWhatsApp: false });
  });

  test('a duplicate confirmation changes nothing', async () => {
    const w = await paidWorld();
    const r = await buy(w, cu1);
    await confirmFakeTicketPayment(w.pay, cu1, { paymentId: r.paymentId });
    const writes = w.store.writes;
    const again = await handleTicketPayment(w.pay, { paymentId: must(r.paymentId) });
    assert.equal(again.refunded, false);
    assert.equal(again.registration?.status, 'paid');
    assert.equal(w.store.writes, writes);
    assert.equal(ev(w).registeredCount, 1);
    assert.equal(w.store.ledger.length, 1);
  });

  test('payment after the hold expired refunds 100%', async () => {
    const w = await paidWorld();
    const r = await buy(w, cu1);
    w.clock.advance(11 * 60_000);
    const out = await handleTicketPayment(w.pay, { paymentId: must(r.paymentId) });
    assert.equal(out.refunded, true);
    const p = pay(w, r.paymentId);
    assert.deepEqual([p.status, p.escrowStatus], ['refunded', 'refunded']);
    const [refund] = w.store.refundsOf(p.id);
    assert.deepEqual([refund?.amount, refund?.percent, refund?.reason, refund?.status], [PRICE, 100, 'late_payment_hold_expired', 'done']);
    // The lapsed hold gives its seat back at once.
    assert.equal(reg(w, r.registrationId).status, 'cancelled');
    assert.deepEqual([ev(w).heldCount, ev(w).registeredCount], [0, 0]);
  });

  test('a second intent paid after the first one is refunded', async () => {
    const w = await paidWorld();
    const a = await buy(w, cu1, 1, 'momo');
    const b = await buy(w, cu1, 1, 'vnpay');
    await handleTicketPayment(w.pay, { paymentId: must(b.paymentId) });
    const late = await handleTicketPayment(w.pay, { paymentId: must(a.paymentId) });
    assert.equal(late.refunded, true);
    assert.equal(pay(w, a.paymentId).status, 'refunded');
    assert.equal(pay(w, b.paymentId).status, 'paid');
    assert.equal(reg(w, a.registrationId).status, 'paid');
    assert.equal(ev(w).registeredCount, 1);
  });

  test('only the payer confirms a fake payment', async () => {
    const w = await paidWorld();
    const r = await buy(w, cu1);
    await assert.rejects(confirmFakeTicketPayment(w.pay, cu2, { paymentId: r.paymentId }), code('permission_denied'));
    await assert.rejects(confirmFakeTicketPayment(w.pay, cu1, { paymentId: 'nope' }), code('not_found'));
    await assert.rejects(confirmFakeTicketPayment(w.pay, cu1, {}), code('invalid_argument'));
    assert.equal(reg(w, r.registrationId).status, 'held');
  });

  test('checkTicketPayment applies a payment the gateway reports', async () => {
    const w = await paidWorld();
    const r = await buy(w, cu1);
    const ask = { eventId: EV, registrationId: r.registrationId };
    assert.deepEqual(await checkTicketPayment(w.pay, cu1, ask), { paid: false, status: 'held' });
    await assert.rejects(checkTicketPayment(w.pay, cu2, ask), code('permission_denied'));
    w.gateway.markPaid(must(r.paymentId));
    assert.deepEqual(await checkTicketPayment(w.pay, cu1, ask), { paid: true, status: 'paid' });
    assert.deepEqual(await checkTicketPayment(w.pay, cu1, ask), { paid: true, status: 'paid' });
    assert.equal(ev(w).registeredCount, 1);
  });

  test('an expired hold frees its seats', async () => {
    const w = await paidWorld({ capacity: 2 });
    await buy(w, cu1, 2);
    assert.equal(ev(w).status, 'full');
    w.clock.advance(9 * 60_000);
    assert.equal(await releaseEventHolds(w.deps), 0);
    w.clock.advance(60_000);
    assert.equal(await releaseEventHolds(w.deps), 1);
    assert.deepEqual([ev(w).heldCount, ev(w).status], [0, 'open']);
    assert.equal(await releaseEventHolds(w.deps), 0);
    const next = await buy(w, cu2, 2);
    assert.equal(next.status, 'held');
  });

  test('ledger: ticket_received then refund_issued sum to the refund (invariant 11)', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1, 2);
    await cancelRegistration(w.pay, cu1, { eventId: EV, registrationId: id });
    const p = pay(w, reg(w, id).paymentId);
    const entries = w.store.ledgerOf(p.id);
    assert.deepEqual(entries.map((e) => [e.type, e.amount]), [['ticket_received', 300_000], ['refund_issued', -300_000]]);
    assert.equal(entries.reduce((s, e) => s + e.amount, 0), 0);
    assert.ok(verifyPaymentLedgerInvariant(p, w.store.refundsOf(p.id), entries));
  });
});

describe('ticket refunds', () => {
  test('refund policy: 100% at 48 hours or more before the start', () => {
    const start = new Date(START);
    assert.equal(ticketRefundPercent(start, new Date(start.getTime() - 48 * HOUR)), 100);
    assert.equal(ticketRefundPercent(start, new Date(start.getTime() - 48 * HOUR + 1)), 0);
  });

  test('cancel 48 hours before refunds 100%', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1, 2);
    w.clock.set(new Date(new Date(START).getTime() - 48 * HOUR));
    assert.deepEqual(await cancelRegistration(w.pay, cu1, { eventId: EV, registrationId: id }), { status: 'refunded', refundPercent: 100 });
    const doc = reg(w, id);
    assert.deepEqual([doc.status, doc.refundPercent], ['refunded', 100]);
    assert.equal(ev(w).registeredCount, 0);
    const p = pay(w, doc.paymentId);
    assert.deepEqual([p.status, p.escrowStatus], ['refunded', 'refunded']);
    assert.deepEqual(w.store.refundsOf(p.id).map((r) => [r.amount, r.reason, r.status]), [[300_000, 'customer_cancel', 'done']]);
    assert.equal(w.store.contacts.has(`${EV}/${id}`), false);
    // Idempotent.
    assert.deepEqual(await cancelRegistration(w.pay, cu1, { eventId: EV, registrationId: id }), { status: 'refunded', refundPercent: 100 });
    assert.equal(w.store.refunds.size, 1);
  });

  test('cancel later keeps the money held and frees the seat', async () => {
    const w = await paidWorld({ capacity: 1 });
    const id = await bought(w, cu1);
    assert.equal(ev(w).status, 'full');
    w.clock.set(new Date(new Date(START).getTime() - 47 * HOUR));
    assert.deepEqual(await cancelRegistration(w.pay, cu1, { eventId: EV, registrationId: id }), { status: 'cancelled', refundPercent: 0 });
    const p = pay(w, reg(w, id).paymentId);
    assert.deepEqual([p.status, p.escrowStatus], ['paid', 'held']);
    assert.equal(w.store.refunds.size, 0);
    assert.deepEqual([ev(w).registeredCount, ev(w).status], [0, 'open']);
    assert.equal(w.store.contacts.has(`${EV}/${id}`), false);
  });

  test('cancelling a hold frees it; a payment arriving later is refunded', async () => {
    const w = await paidWorld();
    const r = await buy(w, cu1);
    assert.deepEqual(await cancelRegistration(w.pay, cu1, { eventId: EV, registrationId: r.registrationId }), { status: 'cancelled', refundPercent: null });
    assert.equal(ev(w).heldCount, 0);
    assert.equal((await handleTicketPayment(w.pay, { paymentId: must(r.paymentId) })).refunded, true);
  });

  test('a refund only comes from held money', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1);
    const p = pay(w, reg(w, id).paymentId);
    w.store.seedPayment({ ...p, escrowStatus: 'released' });
    assert.equal(await refundTicket(w.pay, EV, id, 100, 'customer_cancel'), 'skipped');
    assert.equal(w.store.refunds.size, 0);
    assert.equal(reg(w, id).status, 'paid');
    // An unpaid hold has no money to refund either.
    const hold = await buy(w, cu2);
    assert.equal(await refundTicket(w.pay, EV, hold.registrationId, 100, 'event_cancelled'), 'skipped');
  });

  test('a gateway failure leaves the refund to staff and never doubles', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1);
    w.gateway.issueRefund = async () => ({ success: false, error: 'down' });
    assert.equal(await refundTicket(w.pay, EV, id, 100, 'customer_cancel'), 'refunded');
    const [refund] = w.store.refundsOf(must(reg(w, id).paymentId));
    assert.deepEqual([refund?.status, refund?.manual], ['failed', true]);
    assert.equal(await refundTicket(w.pay, EV, id, 100, 'customer_cancel'), 'skipped');
    assert.equal(w.store.refunds.size, 1);
  });

  test('cancelling the event refunds every paid ticket', async () => {
    const w = await paidWorld();
    const a = await bought(w, cu1, 2);
    const b = await bought(w, cu2);
    const hold = await buy(w, cu3);
    // cu2 cancels late (no refund, money held for the host), then the host cancels the event.
    w.clock.set(new Date(new Date(START).getTime() - 24 * HOUR));
    await cancelRegistration(w.pay, cu2, { eventId: EV, registrationId: b });
    const out = await cancelEventWithRefunds(w.pay, ph1, { eventId: EV });
    assert.deepEqual([out.refunded, out.failed, [...out.paidRegistrationIds].sort()], [2, 0, [a, b].sort()]);
    assert.deepEqual([reg(w, a).status, reg(w, a).refundPercent, reg(w, a).refundDue], ['refunded', 100, false]);
    assert.deepEqual([reg(w, b).status, reg(w, b).refundPercent], ['refunded', 100]);
    assert.equal(reg(w, hold.registrationId).status, 'cancelled');
    for (const id of [a, b]) {
      const p = pay(w, reg(w, id).paymentId);
      assert.equal(p.escrowStatus, 'refunded');
      assert.deepEqual(w.store.refundsOf(p.id).map((r) => r.reason), ['event_cancelled']);
    }
    assert.deepEqual([ev(w).status, ev(w).registeredCount, ev(w).heldCount], ['cancelled', 0, 0]);
  });

  test('a refund failure is retried by the clock and never doubles', async () => {
    const w = await paidWorld();
    const a = await bought(w, cu1);
    const b = await bought(w, cu2);
    // The 4th transaction (b's refund) dies: cancel, a's refund, a's gateway result, then b.
    let calls = 0;
    const flakyStore = Object.assign(Object.create(w.store) as MemoryEventStore, {
      runTransaction: <T>(fn: Parameters<MemoryEventStore['runTransaction']>[0]) => {
        calls += 1;
        if (calls === 4) return Promise.reject(new Error('outage'));
        return w.store.runTransaction(fn as never) as Promise<T>;
      },
    });
    const out = await cancelEventWithRefunds({ ...w.pay, events: flakyStore }, ph1, { eventId: EV });
    assert.deepEqual([out.refunded, out.failed], [1, 1]);
    assert.deepEqual([reg(w, b).status, reg(w, b).refundDue], ['paid', true]);
    assert.equal((await runEventSweeps(w.pay)).refunded, 1);
    assert.equal((await runEventSweeps(w.pay)).refunded, 0);
    assert.deepEqual([reg(w, a).status, reg(w, b).status], ['refunded', 'refunded']);
    assert.equal(w.store.refunds.size, 2);
    for (const id of [a, b]) assert.equal(w.store.refundsOf(must(reg(w, id).paymentId)).length, 1);
  });

  test('getContactLink unlocks with a paid ticket and locks after refund', async () => {
    const w = await paidWorld();
    const r = await buy(w, cu1);
    const deps = {
      bookings: { get: async () => null },
      registrations: {
        get: async (id: string): Promise<RegistrationRecord | null> => {
          const x = w.store.registrations.get(`${EV}/${id}`);
          if (x === undefined) return null;
          return { id, userId: x.userId, photographerId: 'ph1', status: x.status, eventEndsAt: new Date(END), contactEligible: x.contactEligible };
        },
      },
      photographers: {
        read: async () => ({ channels: { call: true, zalo: true, whatsapp: true }, numbers: { phone: '+84912999999', zaloPhone: null, whatsappPhone: null } }),
      },
      log: { append: async () => undefined },
      clock: w.clock,
      ids: w.deps.ids,
    };
    const ask = () => getContactLink('cu1', { registrationId: r.registrationId, channel: 'call' }, deps);
    await assert.rejects(ask(), code('contact_locked')); // held, not paid
    await confirmFakeTicketPayment(w.pay, cu1, { paymentId: r.paymentId });
    assert.deepEqual(await ask(), { url: 'tel:+84912999999' });
    await cancelRegistration(w.pay, cu1, { eventId: EV, registrationId: r.registrationId });
    await assert.rejects(ask(), code('contact_locked'));
  });
});

describe('refund state on the ticket', () => {
  /** Transaction `n` (1-based) of `w.store` throws: the process stopped there. */
  function crashAt(w: PaidWorld, n: number): EventPaymentDeps {
    let calls = 0;
    const store = Object.assign(Object.create(w.store) as MemoryEventStore, {
      runTransaction: <T>(fn: Parameters<MemoryEventStore['runTransaction']>[0]) => {
        calls += 1;
        if (calls === n) return Promise.reject(new Error('crash'));
        return w.store.runTransaction(fn as never) as Promise<T>;
      },
    });
    return { ...w.pay, events: store };
  }

  test('the ticket mirrors its refund: pending until the gateway says done', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1);
    w.clock.set(new Date(new Date(START).getTime() - 72 * HOUR));
    await cancelRegistration(w.pay, cu1, { eventId: EV, registrationId: id });
    const [refund] = w.store.refundsOf(must(reg(w, id).paymentId));
    assert.equal(refund?.subjectType, 'event_registration');
    assert.deepEqual([reg(w, id).status, reg(w, id).refundId, reg(w, id).refundStatus], ['refunded', refund?.id, 'done']);
  });

  test('a gateway failure shows on the ticket as failed and stays with staff', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1);
    w.gateway.refundFailureId = undefined;
    const fail = w.gateway.issueRefund.bind(w.gateway);
    w.gateway.issueRefund = async (p) => {
      w.gateway.refundFailureId = p.refundId;
      return fail(p);
    };
    await cancelEventWithRefunds(w.pay, ph1, { eventId: EV });
    const [refund] = w.store.refundsOf(must(reg(w, id).paymentId));
    assert.deepEqual([refund?.status, refund?.manual, reg(w, id).refundStatus], ['failed', true, 'failed']);
    // The clock never sends a failed refund again.
    w.clock.advance(2 * HOUR);
    assert.equal((await runEventSweeps(w.pay)).refundsResent, 0);
    assert.deepEqual(w.gateway.refundCalls, [refund?.id]);
    assert.equal(reg(w, id).refundStatus, 'failed');
  });

  test('a refund left pending by a crash is sent again by the clock, once', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1);
    w.clock.set(new Date(new Date(START).getTime() - 72 * HOUR));
    // Transactions: 1 decide, 2 refund, (gateway), 3 record the outcome → the process stops at 3.
    await assert.rejects(cancelRegistration(crashAt(w, 3), cu1, { eventId: EV, registrationId: id }), /crash/);
    const paymentId = must(reg(w, id).paymentId);
    const [refund] = w.store.refundsOf(paymentId);
    assert.deepEqual([refund?.status, reg(w, id).status, reg(w, id).refundStatus], ['pending', 'refunded', 'pending']);
    // Not before TICKET_REFUND_RESEND_AFTER_MINUTES: a send may still be on its way.
    w.clock.advance(5 * 60_000);
    assert.equal((await runEventSweeps(w.pay)).refundsResent, 0);
    w.clock.advance(5 * 60_000);
    assert.equal((await runEventSweeps(w.pay)).refundsResent, 1);
    assert.deepEqual([w.store.refunds.get(must(refund).id)?.status, reg(w, id).refundStatus], ['done', 'done']);
    // Sent under the same id: the gateway paid back once.
    assert.deepEqual(w.gateway.refundCalls, [refund?.id, refund?.id]);
    assert.equal(w.gateway.issuedRefunds.size, 1);
    assert.equal((await runEventSweeps(w.pay)).refundsResent, 0);
    assert.equal(w.store.refunds.size, 1);
    assert.deepEqual(w.store.ledgerOf(paymentId).map((e) => e.type), ['ticket_received', 'refund_issued']);
  });

  /** A cancel whose outcome transaction crashed: the refund is left `pending`. */
  async function pendingRefund(w: PaidWorld): Promise<{ id: string; refundId: string }> {
    const id = await bought(w, cu1);
    w.clock.set(new Date(new Date(START).getTime() - 72 * HOUR));
    await assert.rejects(cancelRegistration(crashAt(w, 3), cu1, { eventId: EV, registrationId: id }), /crash/);
    const [refund] = w.store.refundsOf(must(reg(w, id).paymentId));
    assert.equal(refund?.status, 'pending');
    return { id, refundId: must(refund).id };
  }

  test('two resends in parallel: a late failure never overwrites the done refund', async () => {
    const w = await paidWorld();
    const { id, refundId } = await pendingRefund(w);
    // Both sends pass the pending check before either outcome is written; the
    // first succeeds, the second (same id) comes back failed after it.
    const gates: Array<() => void> = [];
    const real = w.gateway.issueRefund.bind(w.gateway);
    let calls = 0;
    w.gateway.issueRefund = async (p) => {
      const n = ++calls;
      await new Promise<void>((resolve) => gates.push(resolve));
      return n === 1 ? real(p) : { success: false };
    };
    const a = resendTicketRefund(w.pay, refundId);
    const b = resendTicketRefund(w.pay, refundId);
    while (gates.length < 2) await new Promise((r) => setImmediate(r));
    must(gates[0])();
    assert.equal(await a, true);
    assert.equal(w.store.refunds.get(refundId)?.status, 'done');
    must(gates[1])();
    assert.equal(await b, true);
    // The outcome is written only while the refund is pending: done stays done.
    assert.deepEqual(
      [w.store.refunds.get(refundId)?.status, w.store.refunds.get(refundId)?.manual, reg(w, id).refundStatus],
      ['done', false, 'done'],
    );
    assert.equal(w.gateway.issuedRefunds.size, 1);
  });

  test('a resend re-checks pending: a done or failed refund is never sent again', async () => {
    const w = await paidWorld();
    const { refundId } = await pendingRefund(w);
    assert.equal(await resendTicketRefund(w.pay, refundId), true);
    assert.equal(w.store.refunds.get(refundId)?.status, 'done');
    const sent = w.gateway.refundCalls.length;
    // The clock picked it up while still pending, but it is done by now.
    assert.equal(await resendTicketRefund(w.pay, refundId), false);
    assert.equal(w.gateway.refundCalls.length, sent);
    // A failed one stays with staff too.
    w.store.refunds.set(refundId, { ...must(w.store.refunds.get(refundId)), status: 'failed', manual: true });
    assert.equal(await resendTicketRefund(w.pay, refundId), false);
    assert.equal(w.gateway.refundCalls.length, sent);
    assert.equal(w.store.refunds.get(refundId)?.status, 'failed');
  });

  test('a refund that never reached the gateway is sent by the clock', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1);
    w.clock.set(new Date(new Date(START).getTime() - 72 * HOUR));
    const real = w.gateway.issueRefund.bind(w.gateway);
    w.gateway.issueRefund = async () => {
      throw new Error('process stopped');
    };
    // The outcome cannot be recorded either (the process is gone).
    await assert.rejects(cancelRegistration(crashAt(w, 3), cu1, { eventId: EV, registrationId: id }), /crash/);
    w.gateway.issueRefund = real;
    assert.equal(w.gateway.issuedRefunds.size, 0);
    w.clock.advance(10 * 60_000);
    assert.equal((await runEventSweeps(w.pay)).refundsResent, 1);
    assert.equal(w.gateway.issuedRefunds.size, 1);
    assert.equal(reg(w, id).refundStatus, 'done');
  });

  test('a booking refund left pending is not the event clock\'s', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1);
    const p = pay(w, reg(w, id).paymentId);
    w.store.seedPayment({ ...p, subjectType: 'booking' });
    w.store.refunds.set('rf_booking', {
      id: 'rf_booking', paymentId: p.id, subjectType: 'booking', amount: 1, percent: 100, status: 'pending', manual: false, fromEscrow: true,
      method: 'gateway', attempts: 0,
      createdAt: new Date(w.clock.now().getTime() - HOUR).toISOString(), updatedAt: w.clock.now().toISOString(),
    });
    assert.equal((await runEventSweeps(w.pay)).refundsResent, 0);
    assert.deepEqual(w.gateway.refundCalls, []);
  });

  test('a payment after the hold shows its refund on the cancelled ticket', async () => {
    const w = await paidWorld();
    const r = await buy(w, cu1);
    w.clock.advance(11 * 60_000);
    await handleTicketPayment(w.pay, { paymentId: must(r.paymentId) });
    const [refund] = w.store.refundsOf(must(r.paymentId));
    const doc = reg(w, r.registrationId);
    assert.deepEqual([doc.status, doc.refundId, doc.refundStatus], ['cancelled', refund?.id, 'done']);
  });

  test('a payment after a cancelled hold shows its refund too', async () => {
    const w = await paidWorld();
    const r = await buy(w, cu1);
    await cancelRegistration(w.pay, cu1, { eventId: EV, registrationId: r.registrationId });
    await handleTicketPayment(w.pay, { paymentId: must(r.paymentId) });
    assert.deepEqual([reg(w, r.registrationId).status, reg(w, r.registrationId).refundStatus], ['cancelled', 'done']);
  });

  test('a late second intent is refunded without touching the paid ticket', async () => {
    const w = await paidWorld();
    const a = await buy(w, cu1, 1, 'momo');
    const b = await buy(w, cu1, 1, 'vnpay');
    await handleTicketPayment(w.pay, { paymentId: must(b.paymentId) });
    await handleTicketPayment(w.pay, { paymentId: must(a.paymentId) });
    const doc = reg(w, a.registrationId);
    assert.deepEqual([doc.status, doc.refundId ?? null, doc.refundStatus ?? null], ['paid', null, null]);
  });

  test('cancel at 48 hours racing a host cancel returns refunded, not conflict', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1);
    w.clock.set(new Date(new Date(START).getTime() - 72 * HOUR));
    // The host cancels right after the customer's cancel decided to refund.
    let calls = 0;
    const racing = Object.assign(Object.create(w.store) as MemoryEventStore, {
      runTransaction: async <T>(fn: Parameters<MemoryEventStore['runTransaction']>[0]) => {
        calls += 1;
        const out = (await w.store.runTransaction(fn as never)) as T;
        if (calls === 1) await cancelEventWithRefunds(w.pay, ph1, { eventId: EV });
        return out;
      },
    });
    const out = await cancelRegistration({ ...w.pay, events: racing }, cu1, { eventId: EV, registrationId: id });
    assert.deepEqual(out, { status: 'refunded', refundPercent: 100 });
    assert.equal(w.store.refundsOf(must(reg(w, id).paymentId)).length, 1);
    assert.equal(w.store.refundsOf(must(reg(w, id).paymentId))[0]?.reason, 'event_cancelled');
  });
});

describe('escrow at completion', () => {
  test('completion sets releaseAfter to end plus 24 hours', async () => {
    const w = await paidWorld();
    const a = await bought(w, cu1);
    const b = await bought(w, cu2);
    const unpaid = await buy(w, cu3);
    w.clock.set(new Date(new Date(START).getTime() - 24 * HOUR));
    await cancelRegistration(w.pay, cu2, { eventId: EV, registrationId: b }); // late: money stays held (O4)
    w.clock.set(new Date(new Date(END).getTime() + 60_000));
    assert.equal((await runEventSweeps(w.pay)).completed, 1);
    const releaseAfter = new Date(new Date(END).getTime() + 24 * HOUR).toISOString();
    assert.equal(pay(w, reg(w, a).paymentId).releaseAfter, releaseAfter);
    assert.equal(pay(w, reg(w, b).paymentId).releaseAfter, releaseAfter);
    assert.equal(pay(w, unpaid.paymentId).releaseAfter, undefined);
  });

  test('a platform event pays the platform', async () => {
    const w = createEventWorld();
    const gateway = new FakePaymentGateway();
    await publishedEvent(w, { price: PRICE }, admin);
    const r = await registerEvent({ ...w.deps, gateway }, cu1, { eventId: EV, quantity: 1, name: 'An', provider: 'vnpay' });
    assert.equal(w.store.payments.get(must(r.paymentId))?.payeeId, 'platform');
  });
});
