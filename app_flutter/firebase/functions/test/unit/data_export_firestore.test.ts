import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { EMPTY_PAYER_SUBJECT, payerRowOf, type Payment, type PayerPaymentRow } from '@photobooking/domain';
import { paymentHistoryForExport } from '../../src/infra/data_export_firestore.js';
import { payerRowToFirestore } from '../../src/infra/payer_history_firestore.js';
import { paymentToFirestore } from '../../src/infra/booking_firestore.js';
import { strictFirestore } from './strict_firestore_support.js';

const T = '2026-10-10T08:00:00.000Z';
const NOW = new Date('2026-10-20T10:00:00.000Z');
const payment: Payment = {
  id: 'pay1', subjectType: 'booking', subjectId: 'b1', payerId: 'c1', payeeId: 'p1', provider: 'fake', amount: 1_000_000,
  status: 'paid', escrowStatus: 'released', idempotencyKey: 'k_secret', method: 'bank_qr', receivedAmount: 1_000_000,
  payoutId: 'po1', payableAmount: 1_000_000, feeBp: 500, providerRef: 'prov_1', paidAt: T, createdAt: T, updatedAt: T,
};

describe('data export: payment history', () => {
  it('exports the customer\'s S22.01 rows, never the raw payments', async () => {
    const row = payerRowOf(payment, [], { ...EMPTY_PAYER_SUBJECT, photographerName: 'Minh Trí', serviceName: 'Chân dung' }, NOW) as PayerPaymentRow;
    const { firestore } = strictFirestore({
      'payments/pay1': paymentToFirestore(payment),
      'users/c1/payments/pay1': payerRowToFirestore(row),
      'users/c2/payments/pay9': payerRowToFirestore({ ...row, paymentId: 'pay9', payerId: 'c2' }),
    });
    const out = await paymentHistoryForExport(firestore, 'c1', 1000);
    assert.deepEqual(out, [row]);
    const json = JSON.stringify(out);
    for (const secret of ['k_secret', 'payoutId', 'payableAmount', 'feeBp', 'prov_1', 'idempotencyKey', 'payeeId']) {
      assert.equal(json.includes(secret), false, secret);
    }
  });
});
