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
import type { LedgerEntry, Payment, Refund } from '../src/escrow.js';
import {
  LEDGER_ENTRY_TYPES,
  PAYMENT_METHODS,
  PAYMENT_STATUSES,
  REFUND_METHODS,
  REFUND_STATUSES,
  RESERVED_PAYMENT_METHODS,
  refundMethodOf,
} from '../src/escrow.js';

describe('Task 3: Escrow & ledger maths', () => {
  const now = new Date('2026-10-10T10:00:00.000Z');

  it('REFUND_STATUSES lists awaiting_account, pending, done, failed', () => {
    assert.deepEqual(REFUND_STATUSES, ['awaiting_account', 'pending', 'done', 'failed']);
    assert.deepEqual(REFUND_METHODS, ['gateway', 'bank_transfer']);
  });

  it('refundMethodOf: bank_qr → bank_transfer; momo, zalopay, undefined → gateway', () => {
    assert.equal(refundMethodOf('bank_qr'), 'bank_transfer');
    assert.equal(refundMethodOf('momo'), 'gateway');
    assert.equal(refundMethodOf('zalopay'), 'gateway');
    assert.equal(refundMethodOf(undefined), 'gateway');
  });

  it('createDepositPayment: creates paid payment and payment_received ledger entry', () => {
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
    assert.equal(ledgerEntry.type, 'payment_received');
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
      assert.equal(res.refund.method, 'gateway');
      assert.equal(res.refund.attempts, 0);
      assert.equal(res.refund.lastAttemptAt, refundNow.toISOString());

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

    it('an explicit amount is refunded as given, within what escrow still holds; full once escrow refunds reach the amount', () => {
      const { payment } = createDepositPayment({
        paymentId: 'pay_01', bookingId: 'b_01', customerId: 'cust_01', photographerId: 'photog_01', provider: 'fake',
        amount: 1_000_000, idempotencyKey: 'idem_01', ledgerEntryId: 'led_01', now,
      });
      // 200 000 already left escrow earlier, plus 50 000 of an over-transfer that never entered it.
      const partly: Payment = { ...payment, status: 'partially_refunded', escrowStatus: 'partially_refunded', refundedAmount: 250_000 };
      const base = { refundId: 'ref_02', ledgerEntryId: 'led_02', reason: 'dispute:d1', now } as const;

      const split = applyRefundToPayment({ ...base, payment: partly, percent: 40, amount: 320_000, escrowRefunded: 200_000 });
      assert.equal(split.refund.amount, 320_000);
      assert.equal(split.refund.percent, 40);
      assert.equal(split.refund.fromEscrow, true);
      assert.equal(split.ledgerEntry.amount, -320_000);
      assert.equal(split.payment.status, 'partially_refunded');
      assert.equal(split.payment.refundedAmount, 570_000);

      const rest = applyRefundToPayment({ ...base, payment: partly, percent: 100, amount: 800_000, escrowRefunded: 200_000 });
      assert.equal(rest.payment.status, 'refunded');
      assert.equal(rest.payment.escrowStatus, 'refunded');

      // `escrowRefunded` is required with `amount` (no silent 0); a caller that skips it does not compile.
      assert.throws(
        // @ts-expect-error amount without escrowRefunded
        () => applyRefundToPayment({ ...base, payment: partly, percent: 100, amount: 1 }),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );

      for (const amount of [0, -1, 1.5, 800_001]) {
        assert.throws(
          () => applyRefundToPayment({ ...base, payment: partly, percent: 100, amount, escrowRefunded: 200_000 }),
          (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
          String(amount),
        );
      }
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

    const { payment: updatedPayment, refund, ledgerEntry: e2 } = applyRefundToPayment({
      payment,
      refundId: 'ref_01',
      percent: 50,
      ledgerEntryId: 'led_02',
      now,
    });

    const isBalanced = verifyPaymentLedgerInvariant(updatedPayment, [refund], [e1, e2]);
    assert.equal(isBalanced, true);
  });
  describe('payment statuses, methods and the QR ledger', () => {
    const at = now.toISOString();
    const qrPayment = (over: Partial<Payment> = {}): Payment => ({
      id: 'pay_qr',
      subjectType: 'booking',
      subjectId: 'b_01',
      payerId: 'cust_01',
      payeeId: 'photog_01',
      provider: 'fake',
      amount: 1_500_000,
      status: 'paid',
      escrowStatus: 'held',
      idempotencyKey: 'idem_qr',
      method: 'bank_qr',
      transferCode: 'PB 7F3K2Q',
      expiresAt: '2026-10-10T10:15:00.000Z',
      receivedAmount: 1_600_000,
      createdAt: at,
      updatedAt: at,
      ...over,
    });
    const received = (id: string, amount: number, type: LedgerEntry['type'] = 'payment_received'): LedgerEntry => ({
      id,
      type,
      paymentId: 'pay_qr',
      accountOwnerId: 'platform_escrow',
      amount,
      at,
    });
    const refundOf = (id: string, amount: number, reason: string): { refund: Refund; entry: LedgerEntry } => ({
      refund: {
        id,
        paymentId: 'pay_qr',
        amount,
        percent: 100,
        status: 'done',
        manual: false,
        fromEscrow: false,
        method: 'bank_transfer',
        attempts: 1,
        reason,
        createdAt: at,
        updatedAt: at,
      },
      entry: { id: `led_${id}`, type: 'refund_issued', paymentId: 'pay_qr', refundId: id, accountOwnerId: 'cust_01', amount: -amount, note: reason, at },
    });

    it('lists the statuses and methods of the payments spec, without failed', () => {
      // `awaiting_group`: a group payment's line (S30 Decision 6).
      assert.deepEqual([...PAYMENT_STATUSES], ['created', 'paid', 'expired', 'needs_review', 'refunded', 'partially_refunded', 'awaiting_group']);
      assert.deepEqual([...PAYMENT_METHODS], ['bank_qr', 'momo', 'zalopay']);
      assert.deepEqual([...RESERVED_PAYMENT_METHODS], ['domestic_card', 'intl_card']);
      assert.ok(LEDGER_ENTRY_TYPES.includes('payment_received'));
      assert.ok(!(LEDGER_ENTRY_TYPES as readonly string[]).includes('deposit_received'));
    });

    it('a paid QR payment with an over-transfer keeps the ledger invariant', () => {
      const { refund, entry } = refundOf('r1', 100_000, 'overpaid_excess');
      assert.equal(verifyPaymentLedgerInvariant(qrPayment(), [refund], [received('l1', 1_600_000), entry]), true);
    });

    it('a paid QR payment with an unrefunded over-transfer is out of balance', () => {
      assert.equal(verifyPaymentLedgerInvariant(qrPayment(), [], [received('l1', 1_600_000)]), false);
    });

    it('a top-up in two transfers keeps the invariant', () => {
      const p = qrPayment({ receivedAmount: 1_500_000 });
      assert.equal(verifyPaymentLedgerInvariant(p, [], [received('l1', 500_000), received('l2', 1_000_000)]), true);
    });

    it('an expired payment that received 500 000 and refunded it balances to 0', () => {
      const p = qrPayment({ status: 'expired', escrowStatus: 'refunded', receivedAmount: 500_000 });
      const { refund, entry } = refundOf('r1', 500_000, 'underpaid_expired');
      assert.equal(verifyPaymentLedgerInvariant(p, [refund], [received('l1', 500_000), entry]), true);
      assert.equal(verifyPaymentLedgerInvariant(p, [], [received('l1', 500_000)]), false);
    });

    it('an expired payment that never received anything balances to 0', () => {
      assert.equal(verifyPaymentLedgerInvariant(qrPayment({ status: 'expired', escrowStatus: 'refunded' }), [], []), true);
    });

    it('a cancelled over-transferred payment keeps the invariant', () => {
      const excess = refundOf('r1', 100_000, 'overpaid_excess');
      const cancel = refundOf('r2', 1_500_000, 'customer_cancelled');
      const p = qrPayment({ status: 'refunded', escrowStatus: 'refunded' });
      assert.equal(
        verifyPaymentLedgerInvariant(p, [excess.refund, cancel.refund], [received('l1', 1_600_000), excess.entry, cancel.entry]),
        true,
      );
    });

    it('a cancellation refund whose reason text says overpaid_excess does not hide an unbalanced paid ledger', () => {
      // Paid 1 500 000, then a 750 000 cancellation refund typed with a reason that mimics an excess refund.
      const cancel = refundOf('r1', 750_000, 'overpaid_excess');
      // Status still paid: the ledger says 1 500 000 - 750 000 != amount.
      assert.equal(verifyPaymentLedgerInvariant(qrPayment({ receivedAmount: 1_500_000 }), [cancel.refund], [received('l1', 1_500_000), cancel.entry]), false);
      // Properly recorded as partially_refunded it is fine, whatever the reason text.
      const p = qrPayment({ status: 'partially_refunded', escrowStatus: 'partially_refunded', receivedAmount: 1_500_000 });
      assert.equal(verifyPaymentLedgerInvariant(p, [cancel.refund], [received('l1', 1_500_000), cancel.entry]), true);
    });

    it('refunds beyond what was received never balance', () => {
      const cancel = refundOf('r1', 1_700_000, 'customer_cancelled');
      const p = qrPayment({ status: 'refunded', escrowStatus: 'refunded' });
      assert.equal(verifyPaymentLedgerInvariant(p, [cancel.refund], [received('l1', 1_500_000), cancel.entry]), false);
    });

    it('a refunded payment that was never received in full is out of balance', () => {
      const cancel = refundOf('r1', 500_000, 'customer_cancelled');
      const p = qrPayment({ status: 'refunded', escrowStatus: 'refunded' });
      assert.equal(verifyPaymentLedgerInvariant(p, [cancel.refund], [received('l1', 500_000), cancel.entry]), false);
    });

    it('old deposit_received entries still count', () => {
      const p = qrPayment({ amount: 300_000, receivedAmount: undefined });
      assert.equal(verifyPaymentLedgerInvariant(p, [], [received('l1', 300_000, 'deposit_received' as LedgerEntry['type'])]), true);
    });

    it('verifyPaymentLedgerInvariant fails when refundedAmount is present and differs from the sum of refunds', () => {
      const cancel = refundOf('r1', 500_000, 'customer_cancelled');
      const p = qrPayment({ status: 'refunded', escrowStatus: 'refunded', refundedAmount: 400_000 });
      assert.equal(verifyPaymentLedgerInvariant(p, [cancel.refund], [received('l1', 1_500_000), cancel.entry]), false);
    });

    it('verifyPaymentLedgerInvariant passes when refundedAmount is absent or matches', () => {
      const cancel = refundOf('r1', 500_000, 'customer_cancelled');
      const pWithout = qrPayment({ status: 'refunded', escrowStatus: 'refunded', refundedAmount: undefined });
      assert.equal(verifyPaymentLedgerInvariant(pWithout, [cancel.refund], [received('l1', 1_500_000), cancel.entry]), true);
      const pWith = qrPayment({ status: 'refunded', escrowStatus: 'refunded', refundedAmount: 500_000 });
      assert.equal(verifyPaymentLedgerInvariant(pWith, [cancel.refund], [received('l1', 1_500_000), cancel.entry]), true);
    });
  });
});
