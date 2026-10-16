import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  applyTransfer,
  expireUnpaid,
  transferRecordOf,
  transferRecordId,
  fakeTransferFor,
  FAKE_TRANSFER_KINDS,
  FAKE_OVERPAY_VND,
  FAKE_WRONG_CONTENT,
  type Payment,
  type TransferNotification,
} from '../src/index.js';

describe('payment_settlement pure helpers', () => {
  const basePayment: Payment = {
    id: 'pay_001',
    subjectType: 'booking',
    subjectId: 'b_001',
    payerId: 'c_001',
    payeeId: 'p_001',
    provider: 'fake',
    amount: 1_500_000,
    status: 'created',
    escrowStatus: 'held',
    idempotencyKey: 'key_001',
    transferCode: 'PB 123456',
    expiresAt: '2026-10-10T12:00:00.000Z',
    createdAt: '2026-10-10T11:45:00.000Z',
    updatedAt: '2026-10-10T11:45:00.000Z',
  };

  const transfer = (overrides: Partial<TransferNotification> = {}): TransferNotification => ({
    provider: 'fake',
    txnId: 'txn_001',
    amount: 1_500_000,
    content: 'PB 123456',
    receivedAt: '2026-10-10T11:50:00.000Z',
    ...overrides,
  });

  describe('applyTransfer', () => {
    it('exact → paid, receivedAmount = amount, one payment_received entry of the transfer amount', () => {
      const now = new Date('2026-10-10T11:50:05.000Z');
      const res = applyTransfer({
        payment: basePayment,
        transfer: transfer({ amount: 1_500_000 }),
        ledgerEntryId: 'led_001',
        now,
      });

      assert.equal(res.decision.kind, 'paid');
      assert.equal(res.excess, 0);
      assert.equal(res.payment.status, 'paid');
      assert.equal(res.payment.escrowStatus, 'held');
      assert.equal(res.payment.receivedAmount, 1_500_000);
      assert.equal(res.payment.paidAt, now.toISOString());
      assert.equal(res.ledgerEntry.type, 'payment_received');
      assert.equal(res.ledgerEntry.amount, 1_500_000);
      assert.equal(res.ledgerEntry.subjectType, 'booking');
      assert.equal(res.ledgerEntry.subjectId, 'b_001');
    });

    it('under then top-up → partial with the running total, then paid with excess 0', () => {
      const now1 = new Date('2026-10-10T11:50:00.000Z');
      const step1 = applyTransfer({
        payment: basePayment,
        transfer: transfer({ amount: 1_000_000, receivedAt: '2026-10-10T11:49:00.000Z' }),
        ledgerEntryId: 'led_001',
        now: now1,
      });

      assert.equal(step1.decision.kind, 'partial');
      assert.equal(step1.excess, 0);
      assert.equal(step1.payment.status, 'created');
      assert.equal(step1.payment.receivedAmount, 1_000_000);
      assert.equal(step1.ledgerEntry.amount, 1_000_000);

      const now2 = new Date('2026-10-10T11:55:00.000Z');
      const step2 = applyTransfer({
        payment: step1.payment,
        transfer: transfer({ txnId: 'txn_002', amount: 500_000, receivedAt: '2026-10-10T11:54:00.000Z' }),
        ledgerEntryId: 'led_002',
        now: now2,
      });

      assert.equal(step2.decision.kind, 'paid');
      assert.equal(step2.excess, 0);
      assert.equal(step2.payment.status, 'paid');
      assert.equal(step2.payment.receivedAmount, 1_500_000);
      assert.equal(step2.ledgerEntry.amount, 500_000);
    });

    it('over → paid with excess = the part above the amount', () => {
      const now = new Date('2026-10-10T11:50:00.000Z');
      const res = applyTransfer({
        payment: basePayment,
        transfer: transfer({ amount: 1_600_000 }),
        ledgerEntryId: 'led_001',
        now,
      });

      assert.equal(res.decision.kind, 'paid');
      assert.equal(res.excess, 100_000);
      assert.equal(res.payment.status, 'paid');
      assert.equal(res.payment.receivedAmount, 1_500_000);
      assert.equal(res.ledgerEntry.amount, 1_600_000);
    });

    it('a late transfer or one to a paid payment → refund decision, payment unchanged, ledger still records it', () => {
      const now = new Date('2026-10-10T12:05:00.000Z');
      // Late transfer
      const resLate = applyTransfer({
        payment: basePayment,
        transfer: transfer({ receivedAt: '2026-10-10T12:01:00.000Z' }),
        ledgerEntryId: 'led_001',
        now,
      });

      assert.equal(resLate.decision.kind, 'refund');
      assert.equal(resLate.decision.reason, 'late_transfer');
      assert.equal(resLate.excess, 0);
      assert.equal(resLate.payment.status, 'created');
      assert.equal(resLate.payment.receivedAmount, undefined);
      assert.equal(resLate.ledgerEntry.amount, 1_500_000);

      // Transfer to already paid payment
      const paidPayment: Payment = {
        ...basePayment,
        status: 'paid',
        receivedAmount: 1_500_000,
        paidAt: '2026-10-10T11:50:00.000Z',
      };
      const resPaid = applyTransfer({
        payment: paidPayment,
        transfer: transfer({ txnId: 'txn_extra' }),
        ledgerEntryId: 'led_002',
        now,
      });

      assert.equal(resPaid.decision.kind, 'refund');
      assert.equal(resPaid.decision.reason, 'extra_transfer');
      assert.equal(resPaid.payment, paidPayment);
      assert.equal(resPaid.ledgerEntry.amount, 1_500_000);
    });

    it('a ticket payment records ticket_received', () => {
      const ticketPayment: Payment = {
        ...basePayment,
        subjectType: 'event_registration',
        subjectId: 'reg_001',
        eventId: 'evt_001',
      };
      const now = new Date('2026-10-10T11:50:00.000Z');
      const res = applyTransfer({
        payment: ticketPayment,
        transfer: transfer(),
        ledgerEntryId: 'led_tkt',
        now,
      });

      assert.equal(res.ledgerEntry.type, 'ticket_received');
      assert.equal(res.ledgerEntry.subjectType, 'event_registration');
      assert.equal(res.ledgerEntry.subjectId, 'reg_001');
      assert.equal(res.ledgerEntry.note, 'Payment for event_registration reg_001');
    });
  });

  describe('expireUnpaid', () => {
    it('nothing received → expired, escrow refunded, no refund', () => {
      const now = new Date('2026-10-10T12:05:00.000Z');
      const res = expireUnpaid({
        payment: basePayment,
        refundId: 'ref_001',
        ledgerEntryId: 'led_001',
        now,
      });

      assert.equal(res.payment.status, 'expired');
      assert.equal(res.payment.escrowStatus, 'refunded');
      assert.equal(res.refund, null);
      assert.equal(res.ledgerEntry, null);
    });

    it('400 000 received → one underpaid_expired refund of 400 000 with fromEscrow false and its refund_issued entry', () => {
      const now = new Date('2026-10-10T12:05:00.000Z');
      const underpaid: Payment = {
        ...basePayment,
        receivedAmount: 400_000,
      };
      const res = expireUnpaid({
        payment: underpaid,
        refundId: 'ref_001',
        ledgerEntryId: 'led_001',
        now,
      });

      assert.equal(res.payment.status, 'expired');
      assert.equal(res.payment.escrowStatus, 'refunded');
      assert.ok(res.refund);
      assert.equal(res.refund.id, 'ref_001');
      assert.equal(res.refund.amount, 400_000);
      assert.equal(res.refund.reason, 'underpaid_expired');
      assert.equal(res.refund.fromEscrow, false);
      assert.ok(res.ledgerEntry);
      assert.equal(res.ledgerEntry.id, 'led_001');
      assert.equal(res.ledgerEntry.type, 'refund_issued');
      assert.equal(res.ledgerEntry.amount, -400_000);
    });

    it('refuses a payment that is not created', () => {
      const paidPayment: Payment = {
        ...basePayment,
        status: 'paid',
      };
      assert.throws(
        () =>
          expireUnpaid({
            payment: paidPayment,
            refundId: 'ref_001',
            ledgerEntryId: 'led_001',
            now: new Date(),
          }),
        (err: unknown) => (err as { code?: string }).code === 'conflict',
      );
    });
  });

  describe('transferRecordOf', () => {
    it('transferRecordOf builds id provider_txnId and keeps raw and receivedAt', () => {
      const n: TransferNotification = {
        provider: 'fake',
        txnId: 'tx_999',
        amount: 500_000,
        content: 'PB 123456',
        receivedAt: '2026-10-10T11:50:00.000Z',
        raw: '{"test":true}',
      };
      const rec = transferRecordOf(n, 'paid', 'pay_001');
      assert.equal(rec.id, transferRecordId(n));
      assert.equal(rec.id, 'fake_tx_999');
      assert.equal(rec.provider, 'fake');
      assert.equal(rec.txnId, 'tx_999');
      assert.equal(rec.raw, '{"test":true}');
      assert.equal(rec.receivedAt, '2026-10-10T11:50:00.000Z');
      assert.equal(rec.outcome, 'paid');
      assert.equal(rec.paymentId, 'pay_001');
    });
  });

  describe('fakeTransferFor', () => {
    it('fakeTransferFor gives the amounts and contents of the four kinds', () => {
      const p = {
        ...basePayment,
        transferCode: 'PB 999999',
        amount: 1_000_000,
      };
      const now = new Date('2026-10-10T12:00:00.000Z');

      assert.deepEqual(FAKE_TRANSFER_KINDS, ['exact', 'under', 'over', 'wrong_content']);

      const exact = fakeTransferFor(p, 'exact', now);
      assert.equal(exact.amount, 1_000_000);
      assert.equal(exact.content, 'PB 999999');
      assert.equal(exact.provider, 'fake');

      const under = fakeTransferFor(p, 'under', now);
      assert.equal(under.amount, 500_000);
      assert.equal(under.content, 'PB 999999');

      const over = fakeTransferFor(p, 'over', now);
      assert.equal(over.amount, 1_000_000 + FAKE_OVERPAY_VND);
      assert.equal(over.content, 'PB 999999');

      const wrong = fakeTransferFor(p, 'wrong_content', now);
      assert.equal(wrong.amount, 1_000_000);
      assert.equal(wrong.content, FAKE_WRONG_CONTENT);
    });
  });
});
