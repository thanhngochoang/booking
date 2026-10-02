import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  bookingToFirestore,
  bookingFromFirestore,
  paymentToFirestore,
  paymentFromFirestore,
  refundToFirestore,
  refundFromFirestore,
  ledgerEntryToFirestore,
  ledgerEntryFromFirestore,
} from '../../src/infra/booking_firestore.js';
import type { Booking, Payment, Refund, LedgerEntry } from '@photobooking/domain';
import { GeoPoint, Timestamp } from 'firebase-admin/firestore';

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
    deposit: 300_000,
    remaining: 700_000,
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
    version: 2,
    createdAt: '2026-10-10T09:00:00.000Z',
    updatedAt: '2026-10-10T10:00:00.000Z',
  };

  it('round-trips Booking through Firestore conversion', () => {
    const docData = bookingToFirestore(sampleBooking);
    assert.ok(docData.place.point instanceof GeoPoint);
    assert.ok(docData.createdAt instanceof Timestamp);
    assert.ok(docData.acceptDeadline instanceof Timestamp);

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
    assert.equal(restored.version, sampleBooking.version);
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
  });

  it('round-trips Refund and LedgerEntry', () => {
    const sampleRefund: Refund = {
      id: 'ref_01',
      paymentId: 'pay_01',
      amount: 150_000,
      percent: 50,
      status: 'pending',
      manual: false,
      reason: 'customer_late_cancel',
      providerRef: 'fake_ref',
      createdAt: '2026-10-12T10:00:00.000Z',
      updatedAt: '2026-10-12T10:00:00.000Z',
    };

    const refundDoc = refundToFirestore(sampleRefund);
    const restoredRefund = refundFromFirestore('ref_01', refundDoc);
    assert.deepEqual(restoredRefund, sampleRefund);

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
});
