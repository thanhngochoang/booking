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
    addons: [
      { addonId: 'a_01', kind: 'makeup', name: 'Trang điểm', unit: 'per_person', unitPrice: 800_000, qty: 2, amount: 1_600_000 },
      { addonId: 'a_02', kind: 'transport', name: 'Xe đón', unit: 'per_booking', unitPrice: 300_000, qty: 1, amount: 300_000 },
    ],
    pickup: { name: '12 Lê Lợi, Quận 1', point: { lat: 10.7769, lng: 106.7009 } },
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
    shotAt: '2026-10-15T16:00:00.000Z',
    deliveredAt: '2026-10-16T16:00:00.000Z',
    approvedAt: '2026-10-17T10:00:00.000Z',
    checkUntil: '2026-10-19T10:00:00.000Z',
    autoApproveAt: '2026-10-19T16:00:00.000Z',
    autoApproveNoticeAt: '2026-10-18T16:00:00.000Z',
    deliveryRound: 2,
    source: 'spot_slot',
    spotId: 'spot_01',
    spotScheduleId: 'sched_01',
    slotOfferId: 'offer_01',
    revisionsIncluded: 2,
    revisionsUsed: 1,
    revisionsGranted: 1,
    extraRound: {
      status: 'pending',
      at: '2026-10-17T09:00:00.000Z',
      note: 'Thêm 1 lượt chỉnh sáng',
      photoNotes: [{ sampleIndex: 0, note: 'Tăng sáng góc trái' }],
    },
    samplesPurgeAfter: '2027-01-15T09:00:00.000Z',
    samplesPurged: false,
    disputeId: 'dsp_01',
    version: 2,
    createdAt: '2026-10-10T09:00:00.000Z',
    updatedAt: '2026-10-10T10:00:00.000Z',
  };

  it('round-trips Booking through Firestore conversion', () => {
    const docData = bookingToFirestore(sampleBooking);
    assert.ok(docData.place.point instanceof GeoPoint);
    assert.ok(docData.createdAt instanceof Timestamp);
    assert.ok(docData.acceptDeadline instanceof Timestamp);
    assert.ok(docData.shotAt instanceof Timestamp);
    assert.ok(docData.deliveredAt instanceof Timestamp);
    assert.ok(docData.approvedAt instanceof Timestamp);
    assert.ok(docData.checkUntil instanceof Timestamp);
    assert.ok(docData.autoApproveAt instanceof Timestamp);
    assert.ok(docData.autoApproveNoticeAt instanceof Timestamp);
    assert.ok(docData.samplesPurgeAfter instanceof Timestamp);
    assert.equal(docData.deliveryRound, 2);
    assert.equal(docData.revisionsIncluded, 2);
    assert.equal(docData.revisionsUsed, 1);
    assert.equal(docData.revisionsGranted, 1);
    assert.equal(docData.samplesPurged, false);
    assert.equal(docData.source, 'spot_slot');
    assert.equal(docData.spotId, 'spot_01');
    assert.equal(docData.spotScheduleId, 'sched_01');
    assert.equal(docData.slotOfferId, 'offer_01');

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
    assert.equal(restored.shotAt, sampleBooking.shotAt);
    assert.equal(restored.deliveredAt, sampleBooking.deliveredAt);
    assert.equal(restored.approvedAt, sampleBooking.approvedAt);
    assert.equal(restored.checkUntil, sampleBooking.checkUntil);
    assert.equal(restored.autoApproveAt, sampleBooking.autoApproveAt);
    assert.equal(restored.autoApproveNoticeAt, sampleBooking.autoApproveNoticeAt);
    assert.equal(restored.deliveryRound, 2);
    assert.equal(restored.source, 'spot_slot');
    assert.equal(restored.spotId, 'spot_01');
    assert.equal(restored.spotScheduleId, 'sched_01');
    assert.equal(restored.slotOfferId, 'offer_01');
    assert.equal(restored.revisionsIncluded, 2);
    assert.equal(restored.revisionsUsed, 1);
    assert.equal(restored.revisionsGranted, 1);
    assert.deepEqual(restored.extraRound, sampleBooking.extraRound);
    assert.equal(restored.samplesPurgeAfter, sampleBooking.samplesPurgeAfter);
    assert.equal(restored.samplesPurged, false);
    // S18: the dispute mirror survives every booking write (Review Focus 5).
    assert.equal(docData.disputeId, 'dsp_01');
    assert.equal(restored.disputeId, 'dsp_01');
    assert.equal(bookingToFirestore({ ...sampleBooking, disputeId: undefined }).disputeId, null);
    assert.equal(restored.version, sampleBooking.version);
    assert.deepEqual(restored.addons, sampleBooking.addons);
    assert.deepEqual(restored.pickup, sampleBooking.pickup);
    assert.ok(docData.pickup.point instanceof GeoPoint);

    // An individual booking writes no studio field (#136)
    assert.equal('isStudio' in docData, false);
    assert.equal('assigneeId' in docData, false);
    assert.equal(restored.isStudio, undefined);

    // Studio fields (#136 Decision 16)
    const studio: Booking = {
      ...sampleBooking,
      cancel: { by: 'studio_fault', reason: 'change_declined', at: '2026-10-12T10:00:00.000Z', refundPercent: 100 },
      isStudio: true,
      assigneeId: 'm_01',
      assigneeKind: 'member',
      assignStatus: 'assigned',
      assignDeadline: '2026-10-14T07:00:00.000Z',
      assignOverdue: true,
      assignedAt: '2026-10-14T08:00:00.000Z',
      assignments: [
        { assigneeId: 'm_00', assigneeKind: 'member', at: '2026-10-11T08:00:00.000Z', by: 'photog_01', reason: null, late: false },
        { assigneeId: 'm_01', assigneeKind: 'member', at: '2026-10-14T08:00:00.000Z', by: 'photog_01', reason: 'Đổi lịch', late: true },
      ],
      assignRemindersSent: ['h48', 'h26'],
      changeRequest: {
        at: '2026-10-13T08:00:00.000Z',
        note: 'Muốn thợ nữ',
        respondBy: '2026-10-13T14:00:00.000Z',
        status: 'declined',
        declineReason: 'Kín lịch',
        answeredAt: '2026-10-13T09:00:00.000Z',
      },
      studioFault: { kind: 'late_reassign', at: '2026-10-14T08:00:00.000Z' },
      assignmentReturned: { at: '2026-10-14T07:30:00.000Z', reason: null },
    };
    const studioDoc = bookingToFirestore(studio);
    assert.ok(studioDoc.assignDeadline instanceof Timestamp);
    assert.ok(studioDoc.changeRequest.respondBy instanceof Timestamp);
    assert.ok(studioDoc.assignments[1].at instanceof Timestamp);
    const back = bookingFromFirestore('b_01', studioDoc);
    assert.ok(back);
    for (const key of [
      'cancel', 'isStudio', 'assigneeId', 'assigneeKind', 'assignStatus', 'assignDeadline', 'assignOverdue', 'assignedAt',
      'assignments', 'assignRemindersSent', 'changeRequest', 'studioFault', 'assignmentReturned',
    ] as const) {
      assert.deepEqual(back[key], studio[key], key);
    }
    const unassigned = bookingFromFirestore('b_01', bookingToFirestore({
      ...studio, assigneeId: null, assigneeKind: null, assignStatus: 'unassigned', assignedAt: null,
      assignments: [], assignRemindersSent: [], changeRequest: null, studioFault: null, assignmentReturned: null,
    }));
    assert.equal(unassigned?.assigneeId, null);
    assert.equal(unassigned?.changeRequest, null);
    assert.deepEqual(unassigned?.assignments, []);

    // S27 (#151, cross-plan review finding 41): a collaborator offer keeps its kind and acceptance, and each
    // assignment entry its offer fields; a lost kind would make a pending collaborator look confirmed.
    const collab: Booking = {
      ...studio,
      assigneeId: 'c_01',
      assigneeKind: 'collaborator',
      assigneeAccepted: false,
      assignStatus: 'unassigned',
      assignedAt: null,
      assignments: [
        { assigneeId: 'm_00', assigneeKind: 'member', at: '2026-10-11T08:00:00.000Z', by: 'photog_01', reason: null, late: false },
        {
          assigneeId: 'c_00', assigneeKind: 'collaborator', at: '2026-10-12T08:00:00.000Z', by: 'photog_01', reason: null,
          late: false, offerExpiresAt: '2026-10-12T14:00:00.000Z', declinedAt: '2026-10-12T09:00:00.000Z',
        },
        {
          assigneeId: 'c_01', assigneeKind: 'collaborator', at: '2026-10-12T10:00:00.000Z', by: 'photog_01', reason: null,
          late: false, offerExpiresAt: '2026-10-12T16:00:00.000Z',
        },
      ],
    };
    const collabDoc = bookingToFirestore(collab);
    assert.equal(collabDoc.assigneeKind, 'collaborator');
    assert.equal(collabDoc.assigneeAccepted, false);
    assert.ok(collabDoc.assignments[1].offerExpiresAt instanceof Timestamp);
    assert.equal('agreedFee' in collabDoc.assignments[2], false);
    const collabBack = bookingFromFirestore('b_01', collabDoc);
    assert.ok(collabBack);
    for (const key of ['assigneeId', 'assigneeKind', 'assigneeAccepted', 'assignStatus', 'assignments'] as const) {
      assert.deepEqual(collabBack[key], collab[key], key);
    }
    const [first, declined, offer] = collab.assignments ?? [];
    assert.ok(first && declined && offer);
    const accepted: Booking = {
      ...collab,
      assigneeAccepted: true,
      assignStatus: 'assigned',
      assignedAt: '2026-10-12T11:00:00.000Z',
      assignments: [first, declined, { ...offer, acceptedAt: '2026-10-12T11:00:00.000Z' }],
    };
    const acceptedBack = bookingFromFirestore('b_01', bookingToFirestore(accepted));
    assert.equal(acceptedBack?.assigneeAccepted, true);
    assert.deepEqual(acceptedBack?.assignments, accepted.assignments);
    // A member booking written before S27 has no assigneeAccepted: it stays absent.
    assert.equal('assigneeAccepted' in (bookingFromFirestore('b_01', studioDoc) ?? {}), false);
  });

  it('a booking without add-ons writes neither addons nor pickup', () => {
    const { addons, pickup, ...plain } = sampleBooking;
    assert.ok(addons);
    assert.ok(pickup);
    const docData = bookingToFirestore(plain);
    assert.equal('addons' in docData, false);
    assert.equal('pickup' in docData, false);
    const restored = bookingFromFirestore('b_01', docData);
    assert.ok(restored);
    assert.equal(restored.addons, undefined);
    assert.equal(restored.pickup, undefined);
  });

  it('getAvailabilityDay returns scheduleId and spotId for a spot day', async () => {
    const firestore = {
      collection: () => ({
        doc: () => ({
          collection: () => ({
            doc: () => ({
              get: async () => ({
                exists: true,
                data: () => ({
                  state: 'spot',
                  scheduleId: 'sched_01',
                  spotId: 'spot_01',
                }),
              }),
            }),
          }),
        }),
      }),
    };
    const store = new FirestoreBookingStore(firestore as never);
    const rec = await store.getAvailabilityDay('ph1', '2026-10-18');
    assert.deepEqual(rec, {
      state: 'spot',
      bookingId: undefined,
      scheduleId: 'sched_01',
      spotId: 'spot_01',
    });
  });

  it('FirestoreBookingStore reads availability/{holder}/days/{day} and spot_days in the spot transaction', async () => {
    const reads: string[] = [];
    const writes: string[] = [];
    const fTx = {
      get: async (ref: { path: string }) => {
        reads.push(ref.path);
        return {
          exists: true,
          data: () => ({
            scheduleId: 'sched_01',
            spotId: 'spot_01',
            providerId: 'ph1',
            day: '2026-10-18',
            taken: [],
            updatedAt: Timestamp.now(),
          }),
        };
      },
      set: (ref: { path: string }) => {
        writes.push(ref.path);
      },
    };
    const firestore = {
      runTransaction: async (fn: (tx: unknown) => Promise<unknown>) => fn(fTx),
      collection: (col: string) => ({
        doc: (id: string) => ({
          path: `${col}/${id}`,
          collection: (sub: string) => ({
            doc: (day: string) => ({ path: `${col}/${id}/${sub}/${day}` }),
          }),
        }),
      }),
    };
    const store = new FirestoreBookingStore(firestore as never);
    await store.runTransaction(async (tx) => {
      await tx.getAvailabilityDay('ph1', '2026-10-18');
      await tx.getSpotDay('sched_01', '2026-10-18');
      await tx.setSpotDay({
        scheduleId: 'sched_01',
        spotId: 'spot_01',
        providerId: 'ph1',
        day: '2026-10-18',
        taken: [{ start: '06:00', end: '08:00' }],
        updatedAt: '2026-10-15T00:00:00.000Z',
      });
    });
    assert.deepEqual(reads, [
      'availability/ph1/days/2026-10-18',
      'spot_days/sched_01_2026-10-18',
    ]);
    assert.deepEqual(writes, ['spot_days/sched_01_2026-10-18']);
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

    // a payment round-trips milestones and payableAmount
    const paymentWithMilestones: Payment = {
      ...paymentWithPayer,
      payableAmount: 150_000,
      milestones: [
        {
          kind: 'shoot',
          amount: 150_000,
          status: 'released',
          releaseAfter: '2026-10-16T09:00:00.000Z',
          releasedAt: '2026-10-16T09:00:00.000Z',
          payoutId: null,
        },
        {
          kind: 'delivery',
          amount: 150_000,
          status: 'held',
          releaseAfter: null,
          releasedAt: null,
          payoutId: null,
        },
      ],
    };
    const milestoneDoc = paymentToFirestore(paymentWithMilestones);
    assert.deepEqual(paymentFromFirestore('pay_01', milestoneDoc), paymentWithMilestones);
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

  it('round-trips Payment with instructions for each subject', () => {
    for (const subjectType of ['booking', 'event_registration'] as const) {
      const p: Payment = {
        id: `pay_${subjectType}`,
        subjectType,
        subjectId: 'sub_01',
        ...(subjectType === 'event_registration' ? { eventId: 'ev_01' } : {}),
        payerId: 'cust_01',
        payeeId: 'photog_01',
        provider: 'fake',
        amount: 500_000,
        status: 'created',
        escrowStatus: 'held',
        idempotencyKey: `idem_${subjectType}`,
        method: 'bank_qr',
        transferCode: 'PB 7F3K2Q',
        expiresAt: '2026-10-10T09:15:00.000Z',
        instructions: {
          providerRef: 'fake_ref_1',
          qrPayload: '000201...',
          bankName: 'BIDV',
          accountMasked: '9624 •••• 3812',
          bankAppsUrl: 'https://fake-pay.local/bank-apps',
        },
        createdAt: '2026-10-10T09:00:00.000Z',
        updatedAt: '2026-10-10T09:00:00.000Z',
      };
      const docData = paymentToFirestore(p);
      const restored = paymentFromFirestore(p.id, docData);
      assert.ok(restored);
      assert.equal(restored.subjectType, subjectType);
      assert.deepEqual(restored.instructions, p.instructions);
      if (subjectType === 'event_registration') {
        assert.equal(restored.eventId, 'ev_01');
      }
    }
  });

  it('a refund with subjectType event_registration keeps it', () => {
    const r: Refund = {
      id: 'ref_tkt_1',
      paymentId: 'pay_tkt_1',
      subjectType: 'event_registration',
      amount: 200_000,
      percent: 100,
      status: 'pending',
      manual: false,
      fromEscrow: true,
      method: 'gateway',
      attempts: 0,
      reason: 'event_cancelled',
      createdAt: '2026-10-10T09:00:00.000Z',
      updatedAt: '2026-10-10T09:00:00.000Z',
    };
    const docData = refundToFirestore(r);
    const restored = refundFromFirestore(r.id, docData);
    assert.ok(restored);
    assert.equal(restored.subjectType, 'event_registration');
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

  it('findReleasableEscrows also returns disputed milestone payments (another milestone may be due), never a disputed payment without milestones', async () => {
    const base: Payment = {
      id: 'pay_h', subjectType: 'booking', subjectId: 'b_h', payerId: 'c1', payeeId: 'p1', provider: 'fake', amount: 1_000_000,
      status: 'paid', escrowStatus: 'held', idempotencyKey: 'k', releaseAfter: '2026-10-10T08:00:00.000Z',
      createdAt: '2026-10-01T00:00:00.000Z', updatedAt: '2026-10-01T00:00:00.000Z',
    };
    const milestone = (kind: 'shoot' | 'delivery', status: 'held' | 'disputed', releaseAfter: string | null) =>
      ({ kind, amount: 500_000, status, releaseAfter, releasedAt: null, payoutId: null });
    const byStatus: Record<string, Payment[]> = {
      'held,partially_refunded': [base],
      disputed: [
        { ...base, id: 'pay_legacy', escrowStatus: 'disputed' },
        {
          ...base, id: 'pay_ms', escrowStatus: 'disputed',
          milestones: [milestone('shoot', 'held', '2026-10-10T08:00:00.000Z'), milestone('delivery', 'disputed', null)],
        },
      ],
    };
    const wheres: unknown[][] = [];
    let statuses = '';
    const query = {
      where: (field: string, op: string, value: unknown) => {
        wheres.push([field, op, value instanceof Timestamp ? value.toDate().toISOString() : value]);
        if (field === 'escrowStatus') statuses = String(value);
        return query;
      },
      limit: () => query,
      get: async () => {
        const docs = (byStatus[statuses] ?? []).map((p) => ({ id: p.id, data: () => paymentToFirestore(p) }));
        return { empty: docs.length === 0, size: docs.length, docs };
      },
    };
    const firestore = { collection: () => query } as unknown as Firestore;
    const found = await new FirestoreBookingStore(firestore).findReleasableEscrows(CUTOFF);
    assert.deepEqual(found.map((p) => p.id), ['pay_h', 'pay_ms']);
    assert.deepEqual(wheres, [
      ['escrowStatus', 'in', ['held', 'partially_refunded']],
      ['releaseAfter', '<=', CUTOFF.toISOString()],
      ['escrowStatus', 'in', ['disputed']],
      ['releaseAfter', '<=', CUTOFF.toISOString()],
    ]);
  });

  it('payment dispute keeps disputeId, milestone and prevStatus', () => {
    const base: Payment = {
      id: 'pay_d', subjectType: 'booking', subjectId: 'b_d', payerId: 'c1', payeeId: 'p1', provider: 'fake', amount: 1_000_000,
      status: 'paid', escrowStatus: 'disputed', idempotencyKey: 'k', payoutId: null,
      createdAt: '2026-10-01T00:00:00.000Z', updatedAt: '2026-10-01T00:00:00.000Z',
    };
    const legacy: Payment = {
      ...base,
      dispute: { reason: 'photos_missing', openedAt: '2026-10-02T00:00:00.000Z', disputeId: 'dsp_1', milestone: null, prevEscrowStatus: 'partially_refunded' },
    };
    const legacyDoc = paymentToFirestore(legacy);
    assert.ok(legacyDoc.dispute.openedAt instanceof Timestamp);
    assert.deepEqual(paymentFromFirestore('pay_d', legacyDoc)?.dispute, legacy.dispute);

    const milestone: Payment = {
      ...base,
      dispute: { reason: 'no_show', openedAt: '2026-10-02T00:00:00.000Z', disputeId: 'dsp_2', milestone: 'shoot' },
    };
    assert.deepEqual(paymentFromFirestore('pay_d', paymentToFirestore(milestone))?.dispute, milestone.dispute);

    // A dispute stored before S18 has only the reason and the time; nothing is invented on read.
    const old: Payment = { ...base, dispute: { reason: 'Ảnh giao thiếu', openedAt: '2026-10-02T00:00:00.000Z' } };
    const oldDoc = paymentToFirestore(old);
    assert.deepEqual(Object.keys(oldDoc.dispute).sort(), ['openedAt', 'reason']);
    assert.deepEqual(paymentFromFirestore('pay_d', oldDoc)?.dispute, old.dispute);
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
