import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  createDepositPayment,
  applyRefundToPayment,
  releaseEscrowPayment,
  disputeEscrowPayment,
  verifyPaymentLedgerInvariant,
} from '../src/escrow.js';
import { DomainError } from '../src/errors.js';

describe('Task 3: Escrow & ledger maths', () => {
  const now = new Date('2026-10-10T10:00:00.000Z');

  it('createDepositPayment: creates paid payment and deposit_received ledger entry', () => {
    const { payment, ledgerEntry } = createDepositPayment({
      paymentId: 'pay_01',
      bookingId: 'b_01',
      customerId: 'cust_01',
      photographerId: 'photog_01',
      provider: 'fake',
      amount: 300_000,
      idempotencyKey: 'idem_01',
      providerRef: 'fake_ref_01',
      ledgerEntryId: 'led_01',
      now,
    });

    assert.equal(payment.id, 'pay_01');
    assert.equal(payment.subjectType, 'booking');
    assert.equal(payment.subjectId, 'b_01');
    assert.equal(payment.amount, 300_000);
    assert.equal(payment.status, 'paid');
    assert.equal(payment.escrowStatus, 'held');
    assert.equal(payment.paidAt, now.toISOString());

    assert.equal(ledgerEntry.id, 'led_01');
    assert.equal(ledgerEntry.type, 'deposit_received');
    assert.equal(ledgerEntry.paymentId, 'pay_01');
    assert.equal(ledgerEntry.subjectId, 'b_01');
    assert.equal(ledgerEntry.amount, 300_000);
    assert.equal(ledgerEntry.at, now.toISOString());
  });

  describe('applyRefundToPayment (Invariant 11 and 12)', () => {
    it('100% refund sets status refunded and creates refund_issued entry', () => {
      const { payment } = createDepositPayment({
        paymentId: 'pay_01',
        bookingId: 'b_01',
        customerId: 'cust_01',
        photographerId: 'photog_01',
        provider: 'fake',
        amount: 300_000,
        idempotencyKey: 'idem_01',
        providerRef: 'fake_ref_01',
        ledgerEntryId: 'led_01',
        now,
      });

      const refundNow = new Date('2026-10-10T12:00:00.000Z');
      const res = applyRefundToPayment({
        payment,
        refundId: 'ref_01',
        percent: 100,
        ledgerEntryId: 'led_02',
        reason: 'customer_cancel',
        now: refundNow,
      });

      assert.equal(res.refund.id, 'ref_01');
      assert.equal(res.refund.amount, 300_000);
      assert.equal(res.refund.percent, 100);
      assert.equal(res.refund.status, 'pending');

      assert.equal(res.payment.status, 'refunded');
      assert.equal(res.payment.escrowStatus, 'refunded');

      assert.equal(res.ledgerEntry.type, 'refund_issued');
      assert.equal(res.ledgerEntry.amount, -300_000);
      assert.equal(res.ledgerEntry.paymentId, 'pay_01');
    });

    it('50% refund sets partially_refunded', () => {
      const { payment } = createDepositPayment({
        paymentId: 'pay_01',
        bookingId: 'b_01',
        customerId: 'cust_01',
        photographerId: 'photog_01',
        provider: 'fake',
        amount: 300_000,
        idempotencyKey: 'idem_01',
        providerRef: 'fake_ref_01',
        ledgerEntryId: 'led_01',
        now,
      });

      const refundNow = new Date('2026-10-10T12:00:00.000Z');
      const res = applyRefundToPayment({
        payment,
        refundId: 'ref_01',
        percent: 50,
        ledgerEntryId: 'led_02',
        reason: 'customer_late_cancel',
        now: refundNow,
      });

      assert.equal(res.refund.amount, 150_000);
      assert.equal(res.payment.status, 'partially_refunded');
      assert.equal(res.payment.escrowStatus, 'partially_refunded');
      assert.equal(res.ledgerEntry.amount, -150_000);
    });

    it('Invariant 12: refuses refund when escrowStatus is released or already refunded', () => {
      const { payment } = createDepositPayment({
        paymentId: 'pay_01',
        bookingId: 'b_01',
        customerId: 'cust_01',
        photographerId: 'photog_01',
        provider: 'fake',
        amount: 300_000,
        idempotencyKey: 'idem_01',
        providerRef: 'fake_ref_01',
        ledgerEntryId: 'led_01',
        now,
      });

      const releasedPayment = {
        ...payment,
        escrowStatus: 'released' as const,
      };

      assert.throws(
        () =>
          applyRefundToPayment({
            payment: releasedPayment,
            refundId: 'ref_01',
            percent: 50,
            ledgerEntryId: 'led_02',
            now,
          }),
        (err: unknown) => err instanceof DomainError && err.code === 'conflict',
      );
    });
  });

  describe('releaseEscrowPayment', () => {
    it('releases held escrow and logs escrow_released entry', () => {
      const { payment } = createDepositPayment({
        paymentId: 'pay_01',
        bookingId: 'b_01',
        customerId: 'cust_01',
        photographerId: 'photog_01',
        provider: 'fake',
        amount: 300_000,
        idempotencyKey: 'idem_01',
        providerRef: 'fake_ref_01',
        ledgerEntryId: 'led_01',
        now,
      });

      const releaseNow = new Date('2026-10-17T10:00:00.000Z');
      const res = releaseEscrowPayment({
        payment,
        ledgerEntryId: 'led_rel_01',
        now: releaseNow,
      });

      assert.equal(res.payment.escrowStatus, 'released');
      assert.equal(res.payment.releasedAt, releaseNow.toISOString());
      assert.equal(res.ledgerEntry.type, 'escrow_released');
      assert.equal(res.ledgerEntry.amount, 300_000);
      assert.equal(res.ledgerEntry.accountOwnerId, 'photog_01');
    });

    it('releases remaining amount of partially_refunded payment', () => {
      const { payment } = createDepositPayment({
        paymentId: 'pay_01',
        bookingId: 'b_01',
        customerId: 'cust_01',
        photographerId: 'photog_01',
        provider: 'fake',
        amount: 300_000,
        idempotencyKey: 'idem_01',
        providerRef: 'fake_ref_01',
        ledgerEntryId: 'led_01',
        now,
      });

      const refundRes = applyRefundToPayment({
        payment,
        refundId: 'ref_01',
        percent: 50,
        ledgerEntryId: 'led_02',
        now,
      });

      const releaseRes = releaseEscrowPayment({
        payment: refundRes.payment,
        refundAmount: 150_000,
        ledgerEntryId: 'led_rel_01',
        now,
      });

      assert.equal(releaseRes.payment.escrowStatus, 'released');
      assert.equal(releaseRes.ledgerEntry.amount, 150_000);
      assert.equal(releaseRes.ledgerEntry.accountOwnerId, 'photog_01');
    });
  });

  describe('disputeEscrowPayment', () => {
    it('marks held payment as disputed', () => {
      const { payment } = createDepositPayment({
        paymentId: 'pay_01',
        bookingId: 'b_01',
        customerId: 'cust_01',
        photographerId: 'photog_01',
        provider: 'fake',
        amount: 300_000,
        idempotencyKey: 'idem_01',
        providerRef: 'fake_ref_01',
        ledgerEntryId: 'led_01',
        now,
      });

      const disputed = disputeEscrowPayment(payment, now);
      assert.equal(disputed.escrowStatus, 'disputed');
    });

    it('refuses dispute if payment already released', () => {
      const { payment } = createDepositPayment({
        paymentId: 'pay_01',
        bookingId: 'b_01',
        customerId: 'cust_01',
        photographerId: 'photog_01',
        provider: 'fake',
        amount: 300_000,
        idempotencyKey: 'idem_01',
        providerRef: 'fake_ref_01',
        ledgerEntryId: 'led_01',
        now,
      });

      const released = { ...payment, escrowStatus: 'released' as const };
      assert.throws(
        () => disputeEscrowPayment(released, now),
        (err: unknown) => err instanceof DomainError && err.code === 'conflict',
      );
    });
  });

  it('verifyPaymentLedgerInvariant verifies balanced ledger entries (Invariant 11)', () => {
    const { payment, ledgerEntry: e1 } = createDepositPayment({
      paymentId: 'pay_01',
      bookingId: 'b_01',
      customerId: 'cust_01',
      photographerId: 'photog_01',
      provider: 'fake',
      amount: 300_000,
      idempotencyKey: 'idem_01',
      providerRef: 'fake_ref_01',
      ledgerEntryId: 'led_01',
      now,
    });

    const { refund, ledgerEntry: e2 } = applyRefundToPayment({
      payment,
      refundId: 'ref_01',
      percent: 50,
      ledgerEntryId: 'led_02',
      now,
    });

    const isBalanced = verifyPaymentLedgerInvariant(payment, [refund], [e1, e2]);
    assert.equal(isBalanced, true);
  });
});
