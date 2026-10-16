import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  DomainError,
  TicketPaymentSettler,
  checkTicketPayment,
  cancelRegistration,
  registerEvent,
  settleTransfer,
  confirmFakePayment,
  runPaymentSweeps,
  verifyPaymentLedgerInvariant,
  type Payment,
  type PaymentMethod,
  type TransferNotification,
} from '../src/index.js';
import {
  cu1,
  cu2,
  must,
  ph1,
  publishedEvent,
  createTicketPaymentWorld,
  type TicketPaymentWorld,
} from './support/event_world.js';
import { fakeTransferFor } from '../src/fake_payment_gateway.js';

const EV = 'ev1_aaaaaaaaaaaaaaaaaaaa';
const PRICE = 150_000;

async function setupWorld(seed = 7, over: Record<string, unknown> = {}): Promise<TicketPaymentWorld> {
  const w = createTicketPaymentWorld(seed);
  await publishedEvent(w, { price: PRICE, ...over }, ph1, EV);
  return w;
}

const buyTicket = (w: TicketPaymentWorld, who = cu1, quantity = 1, method: PaymentMethod | string = 'bank_qr') =>
  registerEvent(w.deps, who, { eventId: EV, quantity, name: 'Nguyễn An', method });

describe('Ticket Settlement (Task 3)', () => {
  it('a paid registration holds seats and returns VietQR instructions for bank_qr', async () => {
    const w = await setupWorld();
    const r = await buyTicket(w, cu1, 2, 'bank_qr');

    assert.equal(r.status, 'held');
    assert.ok(r.instructions);
    assert.equal(r.instructions.subjectType, 'event_registration');
    assert.equal(r.instructions.subjectId, r.registrationId);
    assert.equal(r.instructions.amount, 300_000);
    assert.match(r.instructions.transferCode, /^PB /);
    assert.ok(r.instructions.qrPayload);
    assert.ok(
      r.instructions.qrPayload.includes(r.instructions.transferCode) ||
      r.instructions.qrPayload.includes(r.instructions.transferCode.replace(/\s+/g, ''))
    );
    assert.equal(r.instructions.expiresAt, r.holdExpiresAt?.toISOString());

    const doc = must(w.store.registrations.get(`${EV}/${r.registrationId}`));
    assert.deepEqual([doc.status, doc.amount, doc.quantity, doc.contactEligible], ['held', 300_000, 2, false]);
    const ev = must(w.store.events.get(EV));
    assert.deepEqual([ev.heldCount, ev.registeredCount], [2, 0]);

    const p = must(w.store.payments.get(must(r.paymentId)));
    assert.deepEqual(
      [p.subjectType, p.subjectId, p.eventId, p.payerId, p.payeeId, p.amount, p.status, p.escrowStatus, p.idempotencyKey],
      ['event_registration', r.registrationId, EV, 'cu1', 'ph1', 300_000, 'created', 'held', `tkt_${r.registrationId}_bank_qr`],
    );
    assert.equal(p.transferCode, r.instructions.transferCode);
  });

  it('a paid event needs a known method', async () => {
    const w = await setupWorld();
    await assert.rejects(
      registerEvent(w.deps, cu1, { eventId: EV, quantity: 1, name: 'An' }),
      (e: unknown) => e instanceof DomainError && e.code === 'invalid_argument',
    );
    await assert.rejects(
      registerEvent(w.deps, cu1, { eventId: EV, quantity: 1, name: 'An', method: 'vnpay' }),
      (e: unknown) => e instanceof DomainError && e.code === 'invalid_argument',
    );
    assert.equal(w.store.registrationsOf(EV).length, 0);
  });

  it('the same method twice reuses the payment and its instructions (one gateway call)', async () => {
    const w = await setupWorld();
    let gatewayCalls = 0;
    const originalCreatePayment = w.gateway.createPayment.bind(w.gateway);
    w.gateway.createPayment = async (args) => {
      gatewayCalls += 1;
      return originalCreatePayment(args);
    };

    const a = await buyTicket(w, cu1, 1, 'bank_qr');
    const b = await buyTicket(w, cu1, 1, 'bank_qr');

    assert.equal(b.registrationId, a.registrationId);
    assert.equal(b.paymentId, a.paymentId);
    assert.deepEqual(b.instructions, a.instructions);
    assert.equal(gatewayCalls, 1);
    assert.equal(w.store.payments.size, 1);
  });

  it('another method opens a second payment for the same hold', async () => {
    const w = await setupWorld();
    const a = await buyTicket(w, cu1, 1, 'bank_qr');
    const b = await buyTicket(w, cu1, 1, 'momo');

    assert.equal(b.registrationId, a.registrationId);
    assert.notEqual(b.paymentId, a.paymentId);
    assert.equal(w.store.payments.size, 2);
    const regDoc = must(w.store.registrations.get(`${EV}/${a.registrationId}`));
    assert.equal(regDoc.paymentId, b.paymentId);
    const payA = must(w.store.payments.get(must(a.paymentId)));
    const payB = must(w.store.payments.get(must(b.paymentId)));
    assert.equal(payA.method, 'bank_qr');
    assert.equal(payB.method, 'momo');
  });

  it('Thanh toán tiếp without a method keeps the hold\'s payment', async () => {
    const w = await setupWorld();
    const a = await buyTicket(w, cu1, 1, 'bank_qr');
    const b = await buyTicket(w, cu1, 1, 'momo');
    const again = await registerEvent(w.deps, cu1, { eventId: EV, quantity: 1, name: 'Nguyễn An' });

    assert.equal(again.registrationId, a.registrationId);
    assert.equal(again.paymentId, b.paymentId);
    assert.equal(w.store.payments.size, 2);
    assert.equal(must(again.instructions).method, 'momo');
  });

  it('a ticket payment\'s code is fresh across subjects', async () => {
    const w = await setupWorld();
    // Seed an existing booking payment with transferCode of first ticket payment id
    const candidateId = w.deps.ids.newId();
    // Pre-insert a booking payment with candidateId
    w.store.seedPayment({
      id: candidateId,
      subjectType: 'booking',
      subjectId: 'bk_123',
      payerId: 'cu99',
      payeeId: 'ph99',
      provider: 'fake',
      amount: 100_000,
      status: 'created',
      escrowStatus: 'held',
      idempotencyKey: 'bk_123_key',
      transferCode: `PB ${candidateId.slice(0, 6).toUpperCase()}`,
      createdAt: w.clock.now().toISOString(),
      updatedAt: w.clock.now().toISOString(),
    });

    const r = await buyTicket(w, cu1, 1, 'bank_qr');
    const p = must(w.store.payments.get(must(r.paymentId)));
    assert.notEqual(p.id, candidateId);
    assert.notEqual(p.transferCode, `PB ${candidateId.slice(0, 6).toUpperCase()}`);
  });

  it('an exact transfer makes the ticket paid and moves held to registered', async () => {
    const w = await setupWorld();
    const r = await buyTicket(w, cu1, 2, 'bank_qr');
    const p = must(w.store.payments.get(must(r.paymentId)));

    w.clock.advance(60_000);
    const notification = fakeTransferFor(p as Payment & { transferCode: string }, 'exact', w.clock.now());
    const res = await settleTransfer(w.settlement, notification);

    assert.deepEqual(res, { outcome: 'paid', paymentId: p.id });
    const regDoc = must(w.store.registrations.get(`${EV}/${r.registrationId}`));
    assert.deepEqual([regDoc.status, regDoc.contactEligible, regDoc.paymentId], ['paid', true, p.id]);

    const ev = must(w.store.events.get(EV));
    assert.deepEqual([ev.heldCount, ev.registeredCount], [0, 2]);

    const updatedP = must(w.store.payments.get(p.id));
    assert.equal(updatedP.status, 'paid');
    assert.equal(updatedP.escrowStatus, 'held');

    const ledger = w.store.ledgerOf(p.id);
    assert.equal(ledger.length, 1);
    assert.deepEqual([must(ledger[0]).type, must(ledger[0]).amount], ['ticket_received', 300_000]);

    assert.deepEqual(w.store.contacts.get(`${EV}/${r.registrationId}`), {
      name: 'Nguyễn An',
      phone: '+84912000001',
      allowZalo: false,
      allowWhatsApp: false,
    });
  });

  it('a webhook-style transfer reaches TicketPaymentSettler, then a repeat is duplicate', async () => {
    const w = await setupWorld();
    const r = await buyTicket(w, cu1, 1, 'bank_qr');
    const p = must(w.store.payments.get(must(r.paymentId)));

    const notification = fakeTransferFor(p as Payment & { transferCode: string }, 'exact', w.clock.now());
    const first = await settleTransfer(w.settlement, notification);
    assert.equal(first.outcome, 'paid');

    const second = await settleTransfer(w.settlement, notification);
    assert.equal(second.outcome, 'duplicate');
    assert.equal(w.store.ledgerOf(p.id).length, 1);
  });

  it('under then top-up pays the ticket; over refunds only the excess', async () => {
    const w = await setupWorld();
    const r = await buyTicket(w, cu1, 1, 'bank_qr'); // amount 150_000
    const p = must(w.store.payments.get(must(r.paymentId)));

    // 1. Underpayment
    const under = fakeTransferFor(p as Payment & { transferCode: string }, 'under', w.clock.now()); // 75_000
    const resUnder = await settleTransfer(w.settlement, under);
    assert.equal(resUnder.outcome, 'partial');
    assert.equal(must(w.store.payments.get(p.id)).receivedAmount, 75_000);
    assert.equal(must(w.store.registrations.get(`${EV}/${r.registrationId}`)).status, 'held');

    // 2. Top-up to exact
    const topUp: TransferNotification = {
      provider: 'fake',
      txnId: `fake_topup_${p.id}`,
      amount: 75_000,
      content: p.transferCode ?? '',
      receivedAt: w.clock.now().toISOString(),
    };
    const resTopUp = await settleTransfer(w.settlement, topUp);
    assert.equal(resTopUp.outcome, 'paid');
    assert.equal(must(w.store.payments.get(p.id)).status, 'paid');
    assert.equal(must(w.store.registrations.get(`${EV}/${r.registrationId}`)).status, 'paid');

    // Overpayment test on another ticket
    const r2 = await buyTicket(w, cu2, 1, 'bank_qr'); // 150_000
    const p2 = must(w.store.payments.get(must(r2.paymentId)));
    const over = fakeTransferFor(p2 as Payment & { transferCode: string }, 'over', w.clock.now()); // 200_000 (+50k)
    const resOver = await settleTransfer(w.settlement, over);
    assert.equal(resOver.outcome, 'paid_with_refund');
    assert.equal(must(w.store.payments.get(p2.id)).status, 'paid');

    const refunds = w.store.refundsOf(p2.id);
    assert.equal(refunds.length, 1);
    assert.equal(must(refunds[0]).amount, 50_000);
    assert.equal(must(refunds[0]).reason, 'overpaid_excess');
  });

  it('a transfer after the hold expired is refunded (late_transfer) and marks the ticket refund pending', async () => {
    const w = await setupWorld();
    const r = await buyTicket(w, cu1, 1, 'bank_qr');
    const p = must(w.store.payments.get(must(r.paymentId)));

    w.clock.advance(11 * 60_000);
    const notification = fakeTransferFor(p as Payment & { transferCode: string }, 'exact', w.clock.now());
    const res = await settleTransfer(w.settlement, notification);

    assert.equal(res.outcome, 'refunded');
    const updatedP = must(w.store.payments.get(p.id));
    assert.equal(updatedP.status, 'created');

    const refunds = w.store.refundsOf(p.id);
    assert.equal(refunds.length, 1);
    assert.equal(must(refunds[0]).reason, 'late_transfer');

    const doc = must(w.store.registrations.get(`${EV}/${r.registrationId}`));
    assert.equal(doc.status, 'cancelled');
    assert.equal(doc.refundStatus, 'done');
  });

  it('a second payment paid after the first is refunded and the paid ticket is untouched', async () => {
    const w = await setupWorld();
    const a = await buyTicket(w, cu1, 1, 'bank_qr');
    const b = await buyTicket(w, cu1, 1, 'momo');
    const payA = must(w.store.payments.get(must(a.paymentId)));
    const payB = must(w.store.payments.get(must(b.paymentId)));

    // Settle B first -> ticket paid
    const notifB = fakeTransferFor(payB as Payment & { transferCode: string }, 'exact', w.clock.now());
    await settleTransfer(w.settlement, notifB);
    assert.equal(must(w.store.registrations.get(`${EV}/${a.registrationId}`)).status, 'paid');

    // Late transfer for A arrives -> refunded, does not touch ticket
    const notifA = fakeTransferFor(payA as Payment & { transferCode: string }, 'exact', w.clock.now());
    const resA = await settleTransfer(w.settlement, notifA);
    assert.equal(resA.outcome, 'refunded');
    assert.equal(must(w.store.payments.get(payA.id)).status, 'refunded');
    assert.equal(must(w.store.payments.get(payB.id)).status, 'paid');

    const doc = must(w.store.registrations.get(`${EV}/${a.registrationId}`));
    assert.equal(doc.status, 'paid');
    assert.equal(doc.paymentId, payB.id);
  });

  it('confirmFakePayment on a ticket: payer only; returns the registration status', async () => {
    const w = await setupWorld();
    const r = await buyTicket(w, cu1, 1, 'bank_qr');

    await assert.rejects(
      confirmFakePayment(w.settlement, cu2, { paymentId: r.paymentId, kind: 'exact' }),
      (e: unknown) => e instanceof DomainError && e.code === 'permission_denied',
    );

    const res = await confirmFakePayment(w.settlement, cu1, { paymentId: r.paymentId, kind: 'exact' });
    assert.equal(res.outcome, 'paid');
    assert.equal(res.subjectStatus, 'paid');
    assert.equal(res.paymentStatus, 'paid');
  });

  it('checkTicketPayment settles a transfer the gateway reports', async () => {
    const w = await setupWorld();
    const r = await buyTicket(w, cu1, 1, 'bank_qr');
    const ask = { eventId: EV, registrationId: r.registrationId };

    const check1 = await checkTicketPayment(w.deps, cu1, ask);
    assert.deepEqual(check1, { paid: false, status: 'held' });

    // Seed a transfer on gateway
    const p = must(w.store.payments.get(must(r.paymentId)));
    w.gateway.pushTransfer(p.id, fakeTransferFor(p as Payment & { transferCode: string }, 'exact', w.clock.now()));

    const check2 = await checkTicketPayment(w.deps, cu1, ask);
    assert.deepEqual(check2, { paid: true, status: 'paid' });
  });

  it('runPaymentSweeps expires an unpaid ticket payment and refunds what it received', async () => {
    const w = await setupWorld();
    const r = await buyTicket(w, cu1, 1, 'bank_qr');
    const p = must(w.store.payments.get(must(r.paymentId)));

    // Partially pay 75_000
    const under = fakeTransferFor(p as Payment & { transferCode: string }, 'under', w.clock.now());
    await settleTransfer(w.settlement, under);

    // Advance beyond hold expiry
    w.clock.advance(15 * 60_000);
    const sweepRes = await runPaymentSweeps(w.settlement);

    assert.equal(sweepRes.expired, 1);
    assert.equal(sweepRes.refunded, 1);

    const updatedP = must(w.store.payments.get(p.id));
    assert.equal(updatedP.status, 'expired');
    assert.equal(updatedP.escrowStatus, 'refunded');

    const refunds = w.store.refundsOf(p.id);
    assert.equal(refunds.length, 1);
    assert.equal(must(refunds[0]).amount, 75_000);
    assert.equal(must(refunds[0]).reason, 'underpaid_expired');
  });

  it('statusOf gives the registration status', async () => {
    const w = await setupWorld();
    const r = await buyTicket(w, cu1, 1, 'bank_qr');
    const p = must(w.store.payments.get(must(r.paymentId)));
    const settler = new TicketPaymentSettler(w.deps);

    assert.equal(await settler.statusOf(p), 'held');

    await w.payTicket(p.id, 'exact', cu1);
    assert.equal(await settler.statusOf(p), 'paid');

    const fakeP = { ...p, eventId: 'non_existent_event' };
    assert.equal(await settler.statusOf(fakeP), 'gone');
  });

  it('ledger: ticket_received then refund_issued keep invariant 11', async () => {
    const w = await setupWorld();
    const r = await buyTicket(w, cu1, 2, 'bank_qr');
    const pId = must(r.paymentId);
    await w.payTicket(pId, 'exact', cu1);

    await cancelRegistration(w.deps, cu1, { eventId: EV, registrationId: r.registrationId });

    const p = must(w.store.payments.get(pId));
    const entries = w.store.ledgerOf(p.id);
    assert.deepEqual(
      entries.map((e) => [e.type, e.amount]),
      [['ticket_received', 300_000], ['refund_issued', -300_000]],
    );
    assert.equal(entries.reduce((s, e) => s + e.amount, 0), 0);
    assert.ok(verifyPaymentLedgerInvariant(p, w.store.refundsOf(p.id), entries));
  });
});
