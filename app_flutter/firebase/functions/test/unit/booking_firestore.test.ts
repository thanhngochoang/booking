import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  bookingToFirestore,
  bookingFromFirestore,
  paymentToFirestore,
  paymentFromFirestore,
  refundToFirestore,
  refundFromFirestore,
  escrowRefundedOfDocs,
  ledgerEntryToFirestore,
  ledgerEntryFromFirestore,
  transferRecordToFirestore,
  transferRecordFromFirestore,
  FirestoreBookingStore,
  PAYMENT_NOTIFICATIONS_COLLECTION,
} from '../../src/infra/booking_firestore.js';
import { PAYMENT_METHODS, type Booking, type Payment, type Refund, type LedgerEntry, type TransferRecord } from '@photobooking/domain';
import { GeoPoint, Timestamp, type DocumentData, type Firestore } from 'firebase-admin/firestore';

describe('Firestore <-> Domain booking mappers', () => {
  const sampleBooking: Booking = {
    id: 'b_01',
    customerId: 'cust_01',
    photographerId: 'photog_01',
    serviceId: 'srv_01',
    serviceSnapshot: { name: 'Chân dung', price: 1_000_000, durationMinutes: 120 },
    day: '2026-10-15',
    start: '14:00',
    end: '16:00',
    place: { name: 'Nhà thờ Lớn', point: { lat: 21.0285, lng: 105.8542 } },
    note: 'Chụp ảnh ngoại cảnh',
    status: 'requested',
    deposit: 1_000_000,
    remaining: 0,
    escrowStatus: 'held',
    depositPaidAt: '2026-10-10T10:00:00.000Z',
    acceptDeadline: '2026-10-11T10:00:00.000Z',
    cancel: {
      by: 'customer',
      reason: 'Đổi kế hoạch',
      at: '2026-10-12T10:00:00.000Z',
      refundPercent: 100,
    },
    completedAt: '2026-10-15T09:00:00.000Z',
    reviewedAt: '2026-10-16T10:00:00.000Z',
    chatId: 'chat_01',
    revisionsIncluded: 2,
    version: 2,
    createdAt: '2026-10-10T09:00:00.000Z',
    updatedAt: '2026-10-10T10:00:00.000Z',
  };

  it('round-trips Booking through Firestore conversion', () => {
    const docData = bookingToFirestore(sampleBooking);
    assert.ok(docData.place.point instanceof GeoPoint);
    assert.ok(docData.createdAt instanceof Timestamp);
    assert.ok(docData.acceptDeadline instanceof Timestamp);
    assert.equal(docData.revisionsIncluded, 2);

    const restored = bookingFromFirestore('b_01', docData);
    assert.ok(restored);
    assert.equal(restored.id, sampleBooking.id);
    assert.equal(restored.customerId, sampleBooking.customerId);
    assert.equal(restored.photographerId, sampleBooking.photographerId);
    assert.deepEqual(restored.serviceSnapshot, sampleBooking.serviceSnapshot);
    assert.equal(restored.place.name, sampleBooking.place.name);
    assert.equal(restored.place.point?.lat, sampleBooking.place.point?.lat);
    assert.equal(restored.place.point?.lng, sampleBooking.place.point?.lng);
    assert.equal(restored.depositPaidAt, sampleBooking.depositPaidAt);
    assert.equal(restored.acceptDeadline, sampleBooking.acceptDeadline);
    assert.deepEqual(restored.cancel, sampleBooking.cancel);
    assert.equal(restored.revisionsIncluded, 2);
    assert.equal(restored.version, sampleBooking.version);
  });

  it('a booking without revisionsIncluded reads it as undefined', () => {
    const bookingWithoutRev: Booking = {
      ...sampleBooking,
      revisionsIncluded: undefined,
    };
    const docData = bookingToFirestore(bookingWithoutRev);
    assert.equal(docData.revisionsIncluded, null);

    const restoredFromNull = bookingFromFirestore('b_01', docData);
    assert.ok(restoredFromNull);
    assert.equal(restoredFromNull.revisionsIncluded, undefined);

    delete docData.revisionsIncluded;
    const restoredFromMissing = bookingFromFirestore('b_01', docData);
    assert.ok(restoredFromMissing);
    assert.equal(restoredFromMissing.revisionsIncluded, undefined);
  });

  it('round-trips Payment through Firestore conversion', () => {
    const samplePayment: Payment = {
      id: 'pay_01',
      subjectType: 'booking',
      subjectId: 'b_01',
      payerId: 'cust_01',
      payeeId: 'photog_01',
      provider: 'fake',
      amount: 300_000,
      status: 'paid',
      escrowStatus: 'held',
      idempotencyKey: 'idem_01',
      providerRef: 'ref_01',
      paidAt: '2026-10-10T10:00:00.000Z',
      releaseAfter: '2026-10-16T09:00:00.000Z',
      createdAt: '2026-10-10T10:00:00.000Z',
      updatedAt: '2026-10-10T10:00:00.000Z',
    };

    const docData = paymentToFirestore(samplePayment);
    assert.ok(docData.paidAt instanceof Timestamp);
    assert.ok(docData.releaseAfter instanceof Timestamp);

    const restored = paymentFromFirestore('pay_01', docData);
    assert.ok(restored);
    assert.equal(restored.id, samplePayment.id);
    assert.equal(restored.amount, samplePayment.amount);
    assert.equal(restored.status, samplePayment.status);
    assert.equal(restored.escrowStatus, samplePayment.escrowStatus);
    assert.equal(restored.releaseAfter, samplePayment.releaseAfter);

    // a payment round-trips payer and refundedAmount, and stores no plain number
    const paymentWithPayer: Payment = {
      ...samplePayment,
      releasedAt: undefined,
      dispute: null,
      payoutId: null,
      payer: {
        bankCode: 'VCB',
        bankName: 'Vietcombank',
        accountNumberEnc: 'v1:fake-enc-val',
        accountLast4: '3456',
        holderName: 'NGUYEN THANH HA',
      },
      refundedAmount: 150_000,
    };
    const payerDoc = paymentToFirestore(paymentWithPayer);
    assert.doesNotMatch(JSON.stringify(payerDoc), /0071000123456/);
    assert.deepEqual(paymentFromFirestore('pay_01', payerDoc), paymentWithPayer);
  });

  it('round-trips Refund and LedgerEntry', () => {
    const sampleRefund: Refund = {
      id: 'ref_01',
      paymentId: 'pay_01',
      amount: 150_000,
      percent: 50,
      status: 'pending',
      method: 'gateway',
      attempts: 0,
      manual: false,
      fromEscrow: true,
      reason: 'customer_late_cancel',
      providerRef: 'fake_ref',
      createdAt: '2026-10-12T10:00:00.000Z',
      updatedAt: '2026-10-12T10:00:00.000Z',
    };

    const refundDoc = refundToFirestore(sampleRefund);
    const restoredRefund = refundFromFirestore('ref_01', refundDoc);
    assert.deepEqual(restoredRefund, sampleRefund);
    assert.equal(refundDoc.fromEscrow, true);
    const passThrough = { ...sampleRefund, fromEscrow: false, reason: 'overpaid_excess' };
    assert.equal(refundToFirestore(passThrough).fromEscrow, false);
    assert.deepEqual(refundFromFirestore('ref_01', refundToFirestore(passThrough)), passThrough);
    // A refund stored before the marker existed came out of escrow.
    const legacyDoc = { ...refundDoc };
    delete legacyDoc.fromEscrow;
    assert.equal(refundFromFirestore('ref_01', legacyDoc)?.fromEscrow, true);

    // a refund round-trips method, destination, confirmBy, attempts, lastAttemptAt, failureReason and status awaiting_account
    const complexRefund: Refund = {
      id: 'ref_02',
      paymentId: 'pay_01',
      amount: 100_000,
      percent: 100,
      status: 'awaiting_account',
      method: 'bank_transfer',
      destination: {
        bankCode: 'TCB',
        bankName: 'Techcombank',
        accountNumberEnc: 'v1:enc-destination',
        accountLast4: '8888',
        holderName: 'TRAN VAN B',
        source: 'payer',
      },
      confirmBy: '2026-10-13T10:00:00.000Z',
      attempts: 2,
      lastAttemptAt: '2026-10-12T11:00:00.000Z',
      failureReason: 'gateway_unavailable',
      manual: false,
      fromEscrow: true,
      createdAt: '2026-10-12T10:00:00.000Z',
      updatedAt: '2026-10-12T11:00:00.000Z',
    };
    const cDoc = refundToFirestore(complexRefund);
    assert.ok(cDoc.confirmBy instanceof Timestamp);
    assert.ok(cDoc.lastAttemptAt instanceof Timestamp);
    assert.deepEqual(refundFromFirestore('ref_02', cDoc), complexRefund);

    // a refund without method or attempts reads as gateway and 0
    const minimalDoc = {
      paymentId: 'pay_01',
      amount: 50_000,
      percent: 100,
      status: 'pending',
    };
    const minRestored = refundFromFirestore('ref_min', minimalDoc);
    assert.equal(minRestored?.method, 'gateway');
    assert.equal(minRestored?.attempts, 0);

    const sampleEntry: LedgerEntry = {
      id: 'led_01',
      type: 'refund_issued',
      paymentId: 'pay_01',
      refundId: 'ref_01',
      subjectType: 'booking',
      subjectId: 'b_01',
      accountOwnerId: 'cust_01',
      amount: -150_000,
      note: 'customer_late_cancel',
      at: '2026-10-12T10:00:00.000Z',
    };

    const entryDoc = ledgerEntryToFirestore(sampleEntry);
    const restoredEntry = ledgerEntryFromFirestore('led_01', entryDoc);
    assert.deepEqual(restoredEntry, sampleEntry);
  });

  const checkoutBooking: Booking = {
    ...sampleBooking,
    status: 'draft',
    checkout: {
      paymentId: 'pay_02',
      method: 'bank_qr',
      amount: 1_000_000,
      expiresAt: '2026-10-10T09:15:00.000Z',
      transferCode: 'PB 7F3K2Q',
      attempt: 2,
      qrPayload: '000201010212',
      bankName: 'BIDV',
      accountMasked: '9624 •••• 3812',
      bankAppsUrl: 'https://fake-pay.local/bank-apps',
    },
    payableUntil: '2026-10-10T09:20:00.000Z',
  };

  it('round-trips the booking checkout mirror and payableUntil as Timestamps', () => {
    const docData = bookingToFirestore(checkoutBooking);
    assert.ok(docData.checkout.expiresAt instanceof Timestamp);
    assert.ok(docData.payableUntil instanceof Timestamp);
    assert.equal('payUrl' in docData.checkout, false, 'absent optional fields are not written');
    const restored = bookingFromFirestore('b_01', docData);
    assert.deepEqual(restored?.checkout, checkoutBooking.checkout);
    assert.equal(restored?.payableUntil, checkoutBooking.payableUntil);

    const wallet = bookingFromFirestore('b_01', bookingToFirestore({
      ...checkoutBooking,
      checkout: { paymentId: 'pay_03', method: 'momo', amount: 1_000_000, expiresAt: '2026-10-10T09:15:00.000Z', transferCode: 'PB 7F3K2R', attempt: 3, payUrl: 'https://fake-pay.local/momo?paymentId=pay_03' },
    }));
    assert.equal(wallet?.checkout?.payUrl, 'https://fake-pay.local/momo?paymentId=pay_03');
    assert.equal(wallet?.checkout?.qrPayload, undefined);
  });

  it('a booking without checkout writes nulls and reads them back as absent', () => {
    const docData = bookingToFirestore(sampleBooking);
    assert.equal(docData.checkout, null);
    assert.equal(docData.payableUntil, null);
    const restored = bookingFromFirestore('b_01', docData);
    assert.equal(restored?.checkout, undefined);
    assert.equal(restored?.payableUntil, undefined);
    assert.equal('checkout' in (restored ?? {}), false);
    // A malformed mirror is dropped rather than half-read.
    assert.equal(bookingFromFirestore('b_01', { ...docData, checkout: { paymentId: 'x' } })?.checkout, undefined);
  });

  it('round-trips the checkout fields of a Payment; a legacy payment has none', () => {
    const p: Payment = {
      id: 'pay_02',
      subjectType: 'booking',
      subjectId: 'b_01',
      payerId: 'cust_01',
      payeeId: 'photog_01',
      provider: 'fake',
      amount: 1_000_000,
      status: 'created',
      escrowStatus: 'held',
      idempotencyKey: 'pay_b_01_1',
      providerRef: 'fake_ref_pay_02',
      method: 'bank_qr',
      transferCode: 'PB 7F3K2Q',
      expiresAt: '2026-10-10T09:15:00.000Z',
      receivedAmount: 400_000,
      createdAt: '2026-10-10T09:00:00.000Z',
      updatedAt: '2026-10-10T09:00:00.000Z',
    };
    const docData = paymentToFirestore(p);
    assert.ok(docData.expiresAt instanceof Timestamp);
    assert.equal(docData.transferCode, 'PB 7F3K2Q');
    const restored = paymentFromFirestore('pay_02', docData);
    assert.equal(restored?.method, 'bank_qr');
    assert.equal(restored?.transferCode, 'PB 7F3K2Q');
    assert.equal(restored?.expiresAt, p.expiresAt);
    assert.equal(restored?.receivedAmount, 400_000);

    const { method: _m, transferCode: _t, expiresAt: _e, receivedAmount: _r, ...legacy } = p;
    void [_m, _t, _e, _r];
    const old = paymentFromFirestore('pay_02', paymentToFirestore(legacy));
    assert.equal(old?.method, undefined);
    assert.equal(old?.transferCode, undefined);
    assert.equal(old?.expiresAt, undefined);
    assert.equal(old?.receivedAmount, undefined);
  });

  it('round-trips a transfer record (payment_notifications)', () => {
    assert.equal(PAYMENT_NOTIFICATIONS_COLLECTION, 'payment_notifications');
    const r: TransferRecord = {
      id: 'fake_txn_1',
      provider: 'fake',
      txnId: 'txn_1',
      raw: '{"txnId":"txn_1"}',
      receivedAt: '2026-10-10T09:05:00.000Z',
      outcome: 'paid',
      paymentId: 'pay_02',
    };
    const docData = transferRecordToFirestore(r);
    assert.ok(docData.receivedAt instanceof Timestamp);
    assert.deepEqual(transferRecordFromFirestore('fake_txn_1', docData), r);
    const review: TransferRecord = { id: 'fake_txn_2', provider: 'fake', txnId: 'txn_2', receivedAt: r.receivedAt, outcome: 'needs_review' };
    assert.deepEqual(transferRecordFromFirestore('fake_txn_2', transferRecordToFirestore(review)), review);
    assert.equal(transferRecordFromFirestore('x', undefined), null);
  });
});

/** Records the query a FirestoreBookingStore sweep builds and answers it with `docs`. */
function recordingFirestore(docs: { id: string; data: DocumentData }[] = []) {
  const calls: unknown[][] = [];
  const query = {
    where: (...a: unknown[]) => {
      calls.push(['where', ...a]);
      return query;
    },
    limit: (n: number) => {
      calls.push(['limit', n]);
      return query;
    },
    get: async () => ({ empty: docs.length === 0, size: docs.length, docs: docs.map((d) => ({ id: d.id, data: () => d.data })) }),
  };
  const firestore = {
    collection: (name: string) => {
      calls.push(['collection', name]);
      return query;
    },
  };
  return { firestore: firestore as unknown as Firestore, calls };
}

const whereOf = (calls: unknown[][]) =>
  calls.filter((c) => c[0] === 'where').map((c) => [c[1], c[2], c[3] instanceof Timestamp ? (c[3] as Timestamp).toDate().toISOString() : c[3]]);

describe('FirestoreBookingStore sweep queries', () => {
  const CUTOFF = new Date('2026-10-10T09:00:00.000Z');

  it('findPaymentsToReconcile asks only for open checkout payments of bookings (not tickets, not old deposits)', async () => {
    const { firestore, calls } = recordingFirestore();
    await new FirestoreBookingStore(firestore).findPaymentsToReconcile(CUTOFF, 50);
    assert.deepEqual(calls[0], ['collection', 'payments']);
    assert.deepEqual(whereOf(calls), [
      ['status', '==', 'created'],
      ['subjectType', '==', 'booking'],
      ['method', 'in', [...PAYMENT_METHODS]],
      ['createdAt', '<=', CUTOFF.toISOString()],
    ]);
    assert.deepEqual(calls.at(-1), ['limit', 50]);
  });

  it('findOverduePayments asks the same set by expiresAt', async () => {
    const { firestore, calls } = recordingFirestore();
    await new FirestoreBookingStore(firestore).findOverduePayments(CUTOFF);
    assert.deepEqual(whereOf(calls), [
      ['status', '==', 'created'],
      ['subjectType', '==', 'booking'],
      ['method', 'in', [...PAYMENT_METHODS]],
      ['expiresAt', '<=', CUTOFF.toISOString()],
    ]);
    assert.deepEqual(calls.at(-1), ['limit', 100]);
  });

  it('findExpiredDrafts asks for drafts by payableUntil and maps them', async () => {
    const draft = bookingToFirestore({ ...(await sampleDraft()), payableUntil: '2026-10-10T08:30:00.000Z' });
    const { firestore, calls } = recordingFirestore([{ id: 'b_9', data: draft }]);
    const found = await new FirestoreBookingStore(firestore).findExpiredDrafts(CUTOFF);
    assert.deepEqual(calls[0], ['collection', 'bookings']);
    assert.deepEqual(whereOf(calls), [
      ['status', '==', 'draft'],
      ['payableUntil', '<=', CUTOFF.toISOString()],
    ]);
    assert.deepEqual(found.map((b) => [b.id, b.payableUntil]), [['b_9', '2026-10-10T08:30:00.000Z']]);
  });

  it('findPaymentsByTransferCode filters by the code only (any status)', async () => {
    const { firestore, calls } = recordingFirestore();
    await new FirestoreBookingStore(firestore).findPaymentsByTransferCode('PB 7F3K2Q');
    assert.deepEqual(calls[0], ['collection', 'payments']);
    assert.deepEqual(whereOf(calls), [['transferCode', '==', 'PB 7F3K2Q']]);
  });
});

async function sampleDraft(): Promise<Booking> {
  return {
    id: 'b_9',
    customerId: 'cust_01',
    photographerId: 'photog_01',
    serviceId: 'srv_01',
    serviceSnapshot: { name: 'Chân dung', price: 1_000_000, durationMinutes: 120 },
    day: '2026-10-15',
    start: '14:00',
    end: '16:00',
    place: { name: 'Nhà thờ Lớn' },
    status: 'draft',
    deposit: 1_000_000,
    remaining: 0,
    version: 1,
    createdAt: '2026-10-10T08:00:00.000Z',
    updatedAt: '2026-10-10T08:00:00.000Z',
  };
}

describe('escrowRefundedOfDocs (release, payouts and earnings read refunds through it)', () => {
  it('sums escrow refunds only; a document without the marker counts as escrow', () => {
    const docs: DocumentData[] = [
      { paymentId: 'p', amount: 500_000, fromEscrow: true, reason: 'Bận' },
      { paymentId: 'p', amount: 200_000, fromEscrow: false, reason: 'overpaid_excess' },
      { paymentId: 'p', amount: 1_000_000, fromEscrow: false, reason: 'extra_transfer' },
      { paymentId: 'p', amount: 100_000, reason: 'customer_late_cancel' },
      { paymentId: 'p', amount: 'bad' },
    ];
    assert.equal(escrowRefundedOfDocs(docs), 600_000);
    assert.equal(escrowRefundedOfDocs([]), 0);
  });

  it('never reads the free-text reason', () => {
    assert.equal(escrowRefundedOfDocs([{ amount: 300_000, reason: 'overpaid_excess' }]), 300_000);
  });
});
