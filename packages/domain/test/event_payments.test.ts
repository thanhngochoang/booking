import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError, type ErrorCode } from '../src/errors.js';
import type { EventCaller } from '../src/event.js';
import type { EventPaymentDeps } from '../src/event_ports.js';
import {
  cancelEventWithRefunds, refundTicket,
  ticketRefundHandler, ticketRefundPercent,
} from '../src/event_payments.js';
import { cancelRegistration, registerEvent } from '../src/event_registration.js';
import { runEventSweeps } from '../src/event_sweeps.js';
import { FAKE_PAYER, FakePaymentGateway } from '../src/fake_payment_gateway.js';
import { getContactLink } from '../src/get_contact_link.js';
import { MemoryEventStore } from '../src/memory_event_store.js';
import type { RegistrationRecord } from '../src/ports.js';
import {
  END,
  START,
  admin,
  createEventWorld,
  createTicketPaymentWorld,
  cu1,
  cu2,
  cu3,
  must,
  ph1,
  publishedEvent,
  type EventWorld,
  type TicketPaymentWorld,
} from './support/event_world.js';
import { settleTransfer } from '../src/payment_settlement.js';

const EV = 'ev1_aaaaaaaaaaaaaaaaaaaa';
const PRICE = 150_000;
const HOUR = 3_600_000;
const code = (c: ErrorCode) => (e: unknown) => e instanceof DomainError && e.code === c;

type PaidWorld = TicketPaymentWorld & { pay: EventPaymentDeps };

async function paidWorld(over: Record<string, unknown> = {}, host: EventCaller = ph1): Promise<PaidWorld> {
  const w = createTicketPaymentWorld();
  await publishedEvent(w, { price: PRICE, ...over }, host);
  return { ...w, pay: w.deps };
}

const buy = (w: PaidWorld, who: EventCaller, quantity = 1, method = 'bank_qr') =>
  registerEvent(w.pay, who, { eventId: EV, quantity, name: 'Nguyễn An', method });

const ev = (w: EventWorld) => must(w.store.events.get(EV));
const reg = (w: EventWorld, id: string) => must(w.store.registrations.get(`${EV}/${id}`));
const pay = (w: EventWorld, id: string | null) => must(w.store.payments.get(must(id)));

/** Registers and confirms through payTicket; returns the registration id. */
async function bought(w: PaidWorld, who: EventCaller, quantity = 1): Promise<string> {
  const r = await buy(w, who, quantity);
  await w.payTicket(must(r.paymentId), 'exact', who);
  return r.registrationId;
}

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
    const p = pay(w, r.paymentId);
    const notification = {
      provider: 'fake' as const,
      txnId: `fake_${p.id}_exact`,
      amount: p.amount,
      content: p.transferCode ?? '',
      receivedAt: w.clock.now().toISOString(),
    };
    const res = await settleTransfer(w.settlement, notification);
    assert.equal(res.outcome, 'refunded');
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
    await w.payTicket(must(r.paymentId), 'exact', cu1);
    assert.deepEqual(await ask(), { url: 'tel:+84912999999' });
    await cancelRegistration(w.pay, cu1, { eventId: EV, registrationId: r.registrationId });
    await assert.rejects(ask(), code('contact_locked'));
  });
});

describe('refund state on the ticket', () => {

  test('the ticket mirrors its refund: pending until the gateway says done', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1);
    w.clock.set(new Date(new Date(START).getTime() - 72 * HOUR));
    await cancelRegistration(w.pay, cu1, { eventId: EV, registrationId: id });
    const [refund] = w.store.refundsOf(must(reg(w, id).paymentId));
    assert.equal(refund?.subjectType, 'event_registration');
    assert.deepEqual([reg(w, id).status, reg(w, id).refundId, reg(w, id).refundStatus], ['refunded', refund?.id, 'done']);
  });

  test('a throwing ticket refund stays pending and the registration still says pending', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1);
    w.gateway.refundThrowCount = 1;
    await cancelEventWithRefunds(w.pay, ph1, { eventId: EV });
    const [refund] = w.store.refundsOf(must(reg(w, id).paymentId));
    assert.deepEqual([refund?.status, refund?.manual, refund?.attempts, reg(w, id).refundStatus], ['pending', false, 1, 'pending']);
  });

  test('a bank-QR ticket keeps its payer and its refund goes back to that account', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1);
    const p = pay(w, reg(w, id).paymentId);
    assert.deepEqual([p.payer?.bankCode, p.payer?.accountLast4], ['VCB', '3456']);
    await cancelEventWithRefunds(w.pay, ph1, { eventId: EV });
    const [refund] = w.store.refundsOf(p.id);
    assert.deepEqual(
      [refund?.status, refund?.method, refund?.destination?.accountLast4, reg(w, id).refundStatus],
      ['done', 'bank_transfer', '3456', 'done'],
    );
    assert.deepEqual(w.gateway.refundRequests.get(must(refund).id)?.destination, {
      bankCode: 'VCB', accountNumber: FAKE_PAYER.accountNumber, holderName: FAKE_PAYER.name,
    });
    assert.equal(pay(w, p.id).refundedAmount, PRICE);
  });

  test('a bank-QR transfer without a sender leaves the late refund awaiting an account', async () => {
    const w = await paidWorld();
    const r = await buy(w, cu1);
    await cancelRegistration(w.pay, cu1, { eventId: EV, registrationId: r.registrationId });
    const p = pay(w, r.paymentId);
    await settleTransfer(w.settlement, {
      provider: 'fake', txnId: `fake_${p.id}_nopayer`, amount: p.amount,
      content: p.transferCode ?? '', receivedAt: w.clock.now().toISOString(),
    });
    const [refund] = w.store.refundsOf(p.id);
    assert.deepEqual([refund?.status, reg(w, r.registrationId).refundStatus], ['awaiting_account', 'awaiting_account']);
    assert.deepEqual(w.gateway.refundCalls, []);
  });

  test('ticketRefundHandler.record mirrors done on the registration', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1);
    w.gateway.refundThrowCount = 1;
    await cancelEventWithRefunds(w.pay, ph1, { eventId: EV });
    const [refund] = w.store.refundsOf(must(reg(w, id).paymentId));
    assert.ok(refund);

    const handler = ticketRefundHandler(w.pay);
    await handler.record({ ...refund, status: 'done', attempts: 2 });
    assert.equal(w.store.refunds.get(refund.id)?.status, 'done');
    assert.equal(reg(w, id).refundStatus, 'done');
  });

  test('a pending dispute refund re-sent by ticketRefundHandler only mirrors refundStatus, the ticket stays paid', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1);
    const paid = reg(w, id);
    const payment = pay(w, paid.paymentId);
    const at = w.clock.now().toISOString();
    // S18: resolveDispute refunded out of escrow; the first send threw, so the refund waits for the clock.
    w.store.refunds.set('rf_dispute', {
      id: 'rf_dispute', paymentId: payment.id, subjectType: 'event_registration', amount: PRICE, percent: 100,
      status: 'pending', manual: false, fromEscrow: true, method: 'gateway', attempts: 1, reason: 'dispute:d1',
      createdAt: at, updatedAt: at,
    });
    w.store.registrations.set(`${EV}/${id}`, { ...paid, disputeId: 'd1', refundId: 'rf_dispute', refundStatus: 'pending' });

    const out = await ticketRefundHandler(w.pay).resend(must(w.store.refunds.get('rf_dispute')));
    assert.equal(out.status, 'done');
    const after = reg(w, id);
    assert.equal(after.refundStatus, 'done');
    assert.equal(after.status, 'paid');
    assert.equal(after.cancelledAt, null);
    assert.equal(after.disputeId, 'd1');
    assert.equal(after.refundPercent, paid.refundPercent);
  });

  test('ticketRefundHandler.resend sends under the same id', async () => {
    const w = await paidWorld();
    const id = await bought(w, cu1);
    w.gateway.refundThrowCount = 1;
    await cancelEventWithRefunds(w.pay, ph1, { eventId: EV });
    const [refund] = w.store.refundsOf(must(reg(w, id).paymentId));
    assert.ok(refund);

    const handler = ticketRefundHandler(w.pay);
    const resent = await handler.resend(refund);
    assert.equal(resent.status, 'done');
    assert.deepEqual(w.gateway.refundCalls, [refund.id, refund.id]);
    assert.equal(w.gateway.issuedRefunds.size, 1);
    assert.equal(reg(w, id).refundStatus, 'done');
  });

  test('a ticket resend re-checks pending: a done or failed refund is never sent again', async () => {
    for (const settled of ['done', 'failed'] as const) {
      const w = await paidWorld();
      const id = await bought(w, cu1);
      w.gateway.refundThrowCount = 1;
      await cancelEventWithRefunds(w.pay, ph1, { eventId: EV });
      const [queried] = w.store.refundsOf(must(reg(w, id).paymentId));
      assert.equal(queried?.status, 'pending');
      const calls = w.gateway.refundCalls.length;
      w.store.refunds.set(must(queried).id, { ...must(queried), status: settled, manual: settled === 'failed' });
      const out = await ticketRefundHandler(w.pay).resend(must(queried));
      assert.equal(out.status, settled);
      assert.equal(w.gateway.refundCalls.length, calls, `${settled}: no gateway call`);
      assert.equal(w.store.refunds.get(must(queried).id)?.status, settled);
    }
  });

  test('a payment after the hold shows its refund on the cancelled ticket', async () => {
    const w = await paidWorld();
    const r = await buy(w, cu1);
    w.clock.advance(11 * 60_000);
    const p = pay(w, r.paymentId);
    await settleTransfer(w.settlement, {
      provider: 'fake',
      txnId: `fake_${p.id}_exact`,
      amount: p.amount,
      content: p.transferCode ?? '',
      receivedAt: w.clock.now().toISOString(),
      payer: { ...FAKE_PAYER },
    });
    const [refund] = w.store.refundsOf(must(r.paymentId));
    const doc = reg(w, r.registrationId);
    assert.deepEqual([doc.status, doc.refundId, doc.refundStatus], ['cancelled', refund?.id, 'done']);
  });

  test('a payment after a cancelled hold shows its refund too', async () => {
    const w = await paidWorld();
    const r = await buy(w, cu1);
    await cancelRegistration(w.pay, cu1, { eventId: EV, registrationId: r.registrationId });
    const p = pay(w, r.paymentId);
    await settleTransfer(w.settlement, {
      provider: 'fake',
      txnId: `fake_${p.id}_exact`,
      amount: p.amount,
      content: p.transferCode ?? '',
      receivedAt: w.clock.now().toISOString(),
      payer: { ...FAKE_PAYER },
    });
    assert.deepEqual([reg(w, r.registrationId).status, reg(w, r.registrationId).refundStatus], ['cancelled', 'done']);
  });

  test('a late second intent is refunded without touching the paid ticket', async () => {
    const w = await paidWorld();
    const a = await buy(w, cu1, 1, 'momo');
    const b = await buy(w, cu1, 1, 'bank_qr');
    const payA = pay(w, a.paymentId);
    const payB = pay(w, b.paymentId);
    await settleTransfer(w.settlement, {
      provider: 'fake',
      txnId: `fake_${payB.id}_exact`,
      amount: payB.amount,
      content: payB.transferCode ?? '',
      receivedAt: w.clock.now().toISOString(),
    });
    await settleTransfer(w.settlement, {
      provider: 'fake',
      txnId: `fake_${payA.id}_exact`,
      amount: payA.amount,
      content: payA.transferCode ?? '',
      receivedAt: w.clock.now().toISOString(),
    });
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
    const r = await registerEvent({ ...w.deps, gateway }, cu1, { eventId: EV, quantity: 1, name: 'An', method: 'bank_qr' });
    assert.equal(w.store.payments.get(must(r.paymentId))?.payeeId, 'platform');
  });
});
