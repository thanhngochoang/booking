/**
 * Firestore mapping and BookingStore implementation for Firebase Cloud Functions.
 */

import {
  Timestamp,
  GeoPoint,
  type DocumentData,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import type {
  Booking,
  BookingContactSnapshot,
  BookingStatus,
  EscrowStatus,
  PaymentProvider,
  AvailabilityDayRecord,
  BookingStore,
  BookingTx,
  Payment,
  PaymentStatus,
  Refund,
  RefundStatus,
  LedgerEntry,
  LedgerEntryType,
} from '@photobooking/domain';

export const BOOKINGS_COLLECTION = 'bookings';
export const AVAILABILITY_COLLECTION = 'availability';
export const PAYMENTS_COLLECTION = 'payments';
export const REFUNDS_COLLECTION = 'refunds';
export const LEDGER_COLLECTION = 'ledger_entries';

function toIsoString(v: unknown): string | undefined {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  if (typeof v === 'string') return v;
  return undefined;
}

function toTimestamp(iso: string | undefined): Timestamp | null {
  if (!iso) return null;
  return Timestamp.fromDate(new Date(iso));
}

export function bookingToFirestore(b: Booking): DocumentData {
  return {
    customerId: b.customerId,
    photographerId: b.photographerId,
    serviceId: b.serviceId,
    serviceSnapshot: {
      name: b.serviceSnapshot.name,
      price: b.serviceSnapshot.price,
      durationMinutes: b.serviceSnapshot.durationMinutes,
    },
    day: b.day,
    start: b.start,
    end: b.end,
    place: {
      name: b.place.name,
      point: b.place.point ? new GeoPoint(b.place.point.lat, b.place.point.lng) : null,
    },
    note: b.note ?? null,
    status: b.status,
    deposit: b.deposit,
    remaining: b.remaining,
    escrowStatus: b.escrowStatus ?? null,
    depositRefunded: b.depositRefunded ?? 0,
    depositProvider: b.depositProvider ?? null,
    depositPaidAt: toTimestamp(b.depositPaidAt),
    depositRefundedAt: toTimestamp(b.depositRefundedAt),
    acceptDeadline: toTimestamp(b.acceptDeadline),
    cancel: b.cancel
      ? {
          by: b.cancel.by,
          reason: b.cancel.reason ?? null,
          at: toTimestamp(b.cancel.at),
          refundPercent: b.cancel.refundPercent,
        }
      : null,
    completedAt: toTimestamp(b.completedAt),
    reviewedAt: toTimestamp(b.reviewedAt),
    chatId: b.chatId ?? null,
    version: b.version,
    createdAt: toTimestamp(b.createdAt),
    updatedAt: toTimestamp(b.updatedAt),
  };
}

export function bookingFromFirestore(id: string, d: DocumentData | undefined): Booking | null {
  if (!d) return null;
  const { customerId, photographerId, serviceId, serviceSnapshot, day, start, end, place, status } = d;
  if (
    typeof customerId !== 'string' ||
    typeof photographerId !== 'string' ||
    typeof serviceId !== 'string' ||
    !serviceSnapshot ||
    typeof day !== 'string' ||
    typeof start !== 'string' ||
    typeof end !== 'string' ||
    !place ||
    typeof status !== 'string'
  ) {
    return null;
  }

  const pointGeo = place.point instanceof GeoPoint ? { lat: place.point.latitude, lng: place.point.longitude } : undefined;

  let cancelObj: Booking['cancel'] | undefined;
  if (d.cancel && typeof d.cancel === 'object') {
    cancelObj = {
      by: d.cancel.by,
      reason: d.cancel.reason ?? undefined,
      at: toIsoString(d.cancel.at) ?? new Date().toISOString(),
      refundPercent: d.cancel.refundPercent ?? 0,
    };
  }

  return {
    id,
    customerId,
    photographerId,
    serviceId,
    serviceSnapshot: {
      name: serviceSnapshot.name,
      price: serviceSnapshot.price,
      durationMinutes: serviceSnapshot.durationMinutes,
    },
    day,
    start,
    end,
    place: {
      name: place.name,
      point: pointGeo,
    },
    note: d.note ?? undefined,
    status: status as BookingStatus,
    deposit: d.deposit,
    remaining: d.remaining,
    escrowStatus: (d.escrowStatus as EscrowStatus) ?? undefined,
    depositRefunded: d.depositRefunded ?? undefined,
    depositProvider: (d.depositProvider as PaymentProvider) ?? undefined,
    depositPaidAt: toIsoString(d.depositPaidAt),
    depositRefundedAt: toIsoString(d.depositRefundedAt),
    acceptDeadline: toIsoString(d.acceptDeadline),
    cancel: cancelObj,
    completedAt: toIsoString(d.completedAt),
    reviewedAt: toIsoString(d.reviewedAt),
    chatId: d.chatId ?? undefined,
    version: d.version ?? 1,
    createdAt: toIsoString(d.createdAt) ?? new Date().toISOString(),
    updatedAt: toIsoString(d.updatedAt) ?? new Date().toISOString(),
  };
}

export function paymentToFirestore(p: Payment): DocumentData {
  return {
    subjectType: p.subjectType,
    subjectId: p.subjectId,
    payerId: p.payerId,
    payeeId: p.payeeId,
    provider: p.provider,
    amount: p.amount,
    status: p.status,
    escrowStatus: p.escrowStatus,
    idempotencyKey: p.idempotencyKey,
    providerRef: p.providerRef ?? null,
    paidAt: toTimestamp(p.paidAt),
    releasedAt: toTimestamp(p.releasedAt),
    releaseAfter: toTimestamp(p.releaseAfter),
    createdAt: toTimestamp(p.createdAt),
    updatedAt: toTimestamp(p.updatedAt),
  };
}

export function paymentFromFirestore(id: string, d: DocumentData | undefined): Payment | null {
  if (!d) return null;
  return {
    id,
    subjectType: d.subjectType,
    subjectId: d.subjectId,
    payerId: d.payerId,
    payeeId: d.payeeId,
    provider: d.provider as PaymentProvider,
    amount: d.amount,
    status: d.status as PaymentStatus,
    escrowStatus: d.escrowStatus as EscrowStatus,
    idempotencyKey: d.idempotencyKey,
    providerRef: d.providerRef ?? undefined,
    paidAt: toIsoString(d.paidAt),
    releasedAt: toIsoString(d.releasedAt),
    releaseAfter: toIsoString(d.releaseAfter),
    createdAt: toIsoString(d.createdAt) ?? new Date().toISOString(),
    updatedAt: toIsoString(d.updatedAt) ?? new Date().toISOString(),
  };
}

export function refundToFirestore(r: Refund): DocumentData {
  return {
    paymentId: r.paymentId,
    amount: r.amount,
    percent: r.percent,
    status: r.status,
    manual: r.manual,
    reason: r.reason ?? null,
    providerRef: r.providerRef ?? null,
    createdAt: toTimestamp(r.createdAt),
    updatedAt: toTimestamp(r.updatedAt),
  };
}

export function refundFromFirestore(id: string, d: DocumentData | undefined): Refund | null {
  if (!d) return null;
  return {
    id,
    paymentId: d.paymentId,
    amount: d.amount,
    percent: d.percent,
    status: d.status as RefundStatus,
    manual: d.manual ?? false,
    ...(d.reason ? { reason: d.reason } : {}),
    ...(d.providerRef ? { providerRef: d.providerRef } : {}),
    createdAt: toIsoString(d.createdAt) ?? new Date().toISOString(),
    updatedAt: toIsoString(d.updatedAt) ?? new Date().toISOString(),
  };
}

export function ledgerEntryToFirestore(e: LedgerEntry): DocumentData {
  return {
    type: e.type,
    paymentId: e.paymentId ?? null,
    refundId: e.refundId ?? null,
    payoutId: e.payoutId ?? null,
    subjectType: e.subjectType ?? null,
    subjectId: e.subjectId ?? null,
    accountOwnerId: e.accountOwnerId,
    amount: e.amount,
    note: e.note ?? null,
    at: toTimestamp(e.at),
  };
}

export function ledgerEntryFromFirestore(id: string, d: DocumentData | undefined): LedgerEntry | null {
  if (!d) return null;
  return {
    id,
    type: d.type as LedgerEntryType,
    ...(d.paymentId ? { paymentId: d.paymentId } : {}),
    ...(d.refundId ? { refundId: d.refundId } : {}),
    ...(d.payoutId ? { payoutId: d.payoutId } : {}),
    ...(d.subjectType ? { subjectType: d.subjectType } : {}),
    ...(d.subjectId ? { subjectId: d.subjectId } : {}),
    accountOwnerId: d.accountOwnerId,
    amount: d.amount,
    ...(d.note ? { note: d.note } : {}),
    at: toIsoString(d.at) ?? new Date().toISOString(),
  };
}

export class FirestoreBookingStore implements BookingStore {
  constructor(private readonly firestore: Firestore) {}

  async runTransaction<T>(fn: (tx: BookingTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx: Transaction) => {
      const tx: BookingTx = {
        getBooking: async (id) => {
          const snap = await fTx.get(this.firestore.collection(BOOKINGS_COLLECTION).doc(id));
          return bookingFromFirestore(snap.id, snap.data());
        },
        getAvailabilityDay: async (photographerId, day) => {
          const snap = await fTx.get(
            this.firestore.collection(AVAILABILITY_COLLECTION).doc(photographerId).collection('days').doc(day),
          );
          if (!snap.exists) return null;
          const d = snap.data();
          return d ? { state: d.state, bookingId: d.bookingId } : null;
        },
        getCustomerDraftForDay: async (customerId, photographerId, day) => {
          const q = this.firestore
            .collection(BOOKINGS_COLLECTION)
            .where('customerId', '==', customerId)
            .where('photographerId', '==', photographerId)
            .where('day', '==', day)
            .where('status', '==', 'draft')
            .limit(1);
          const snap = await fTx.get(q);
          if (snap.empty || !snap.docs[0]) return null;
          return bookingFromFirestore(snap.docs[0].id, snap.docs[0].data());
        },
        setBooking: async (b) => {
          fTx.set(this.firestore.collection(BOOKINGS_COLLECTION).doc(b.id), bookingToFirestore(b));
        },
        deleteBooking: async (id) => {
          fTx.delete(this.firestore.collection(BOOKINGS_COLLECTION).doc(id));
        },
        setAvailabilityDay: async (photographerId, day, record) => {
          const ref = this.firestore.collection(AVAILABILITY_COLLECTION).doc(photographerId).collection('days').doc(day);
          fTx.set(ref, record);
        },
        deleteAvailabilityDay: async (photographerId, day) => {
          const ref = this.firestore.collection(AVAILABILITY_COLLECTION).doc(photographerId).collection('days').doc(day);
          fTx.delete(ref);
        },
        setContactSnapshot: async (bookingId, contact) => {
          const ref = this.firestore.collection(BOOKINGS_COLLECTION).doc(bookingId).collection('private').doc('contact');
          fTx.set(ref, {
            name: contact.name,
            phone: contact.phone,
            allowZalo: contact.allowZalo,
            allowWhatsApp: contact.allowWhatsApp,
            redactedAt: toTimestamp(contact.redactedAt ?? undefined),
          });
        },
        getContactSnapshot: async (bookingId) => {
          const ref = this.firestore.collection(BOOKINGS_COLLECTION).doc(bookingId).collection('private').doc('contact');
          const snap = await fTx.get(ref);
          if (!snap.exists) return null;
          const d = snap.data();
          if (!d) return null;
          return {
            name: d.name ?? '',
            phone: d.phone,
            allowZalo: d.allowZalo ?? false,
            allowWhatsApp: d.allowWhatsApp ?? false,
            redactedAt: toIsoString(d.redactedAt),
          };
        },
        deleteContactSnapshot: async (bookingId) => {
          const ref = this.firestore.collection(BOOKINGS_COLLECTION).doc(bookingId).collection('private').doc('contact');
          fTx.delete(ref);
        },
        getPayment: async (id) => {
          const snap = await fTx.get(this.firestore.collection(PAYMENTS_COLLECTION).doc(id));
          return paymentFromFirestore(snap.id, snap.data());
        },
        getPaymentByIdempotencyKey: async (key) => {
          const q = this.firestore.collection(PAYMENTS_COLLECTION).where('idempotencyKey', '==', key).limit(1);
          const snap = await fTx.get(q);
          if (snap.empty || !snap.docs[0]) return null;
          return paymentFromFirestore(snap.docs[0].id, snap.docs[0].data());
        },
        setPayment: async (payment) => {
          fTx.set(this.firestore.collection(PAYMENTS_COLLECTION).doc(payment.id), paymentToFirestore(payment));
        },
        addRefund: async (refund) => {
          fTx.set(this.firestore.collection(REFUNDS_COLLECTION).doc(refund.id), refundToFirestore(refund));
        },
        addLedgerEntry: async (entry) => {
          fTx.set(this.firestore.collection(LEDGER_COLLECTION).doc(entry.id), ledgerEntryToFirestore(entry));
        },
        addBookingEvent: async (event) => {
          const ref = this.firestore.collection(BOOKINGS_COLLECTION).doc(event.bookingId).collection('events').doc(event.id);
          fTx.set(ref, {
            status: event.status,
            at: toTimestamp(event.at),
            actorId: event.actorId ?? null,
          });
        },
      };

      return fn(tx);
    });
  }

  async getBooking(id: string): Promise<Booking | null> {
    const snap = await this.firestore.collection(BOOKINGS_COLLECTION).doc(id).get();
    return bookingFromFirestore(snap.id, snap.data());
  }

  async getAvailabilityDay(photographerId: string, day: string): Promise<AvailabilityDayRecord | null> {
    const snap = await this.firestore.collection(AVAILABILITY_COLLECTION).doc(photographerId).collection('days').doc(day).get();
    if (!snap.exists) return null;
    const d = snap.data();
    return d ? { state: d.state, bookingId: d.bookingId } : null;
  }

  async getCustomerDraftForDay(customerId: string, photographerId: string, day: string): Promise<Booking | null> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('customerId', '==', customerId)
      .where('photographerId', '==', photographerId)
      .where('day', '==', day)
      .where('status', '==', 'draft')
      .limit(1)
      .get();
    if (snap.empty || !snap.docs[0]) return null;
    return bookingFromFirestore(snap.docs[0].id, snap.docs[0].data());
  }

  async getPayment(id: string): Promise<Payment | null> {
    const snap = await this.firestore.collection(PAYMENTS_COLLECTION).doc(id).get();
    return paymentFromFirestore(snap.id, snap.data());
  }

  async getPaymentByIdempotencyKey(key: string): Promise<Payment | null> {
    const snap = await this.firestore.collection(PAYMENTS_COLLECTION).where('idempotencyKey', '==', key).limit(1).get();
    if (snap.empty || !snap.docs[0]) return null;
    return paymentFromFirestore(snap.docs[0].id, snap.docs[0].data());
  }

  async getPaymentsForBooking(bookingId: string): Promise<readonly Payment[]> {
    const snap = await this.firestore
      .collection(PAYMENTS_COLLECTION)
      .where('subjectType', '==', 'booking')
      .where('subjectId', '==', bookingId)
      .get();
    const res: Payment[] = [];
    for (const doc of snap.docs) {
      const p = paymentFromFirestore(doc.id, doc.data());
      if (p) res.push(p);
    }
    return res;
  }

  async getRefundsForPayment(paymentId: string): Promise<readonly Refund[]> {
    const snap = await this.firestore.collection(REFUNDS_COLLECTION).where('paymentId', '==', paymentId).get();
    const res: Refund[] = [];
    for (const doc of snap.docs) {
      const r = refundFromFirestore(doc.id, doc.data());
      if (r) res.push(r);
    }
    return res;
  }

  async getLedgerEntriesForPayment(paymentId: string): Promise<readonly LedgerEntry[]> {
    const snap = await this.firestore.collection(LEDGER_COLLECTION).where('paymentId', '==', paymentId).get();
    const res: LedgerEntry[] = [];
    for (const doc of snap.docs) {
      const e = ledgerEntryFromFirestore(doc.id, doc.data());
      if (e) res.push(e);
    }
    return res;
  }

  async getContactSnapshot(bookingId: string): Promise<BookingContactSnapshot | null> {
    const snap = await this.firestore.collection(BOOKINGS_COLLECTION).doc(bookingId).collection('private').doc('contact').get();
    if (!snap.exists) return null;
    const d = snap.data();
    if (!d) return null;
    return {
      name: d.name ?? '',
      phone: d.phone,
      allowZalo: d.allowZalo ?? false,
      allowWhatsApp: d.allowWhatsApp ?? false,
      redactedAt: toIsoString(d.redactedAt),
    };
  }

  async findUnpaidDraftsOlderThan(cutoff: Date, limit = 100): Promise<readonly Booking[]> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('status', '==', 'draft')
      .where('createdAt', '<=', Timestamp.fromDate(cutoff))
      .limit(limit)
      .get();
    const res: Booking[] = [];
    for (const doc of snap.docs) {
      const b = bookingFromFirestore(doc.id, doc.data());
      if (b) res.push(b);
    }
    return res;
  }

  async findExpiredRequests(now: Date, limit = 100): Promise<readonly Booking[]> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('status', '==', 'requested')
      .where('acceptDeadline', '<=', Timestamp.fromDate(now))
      .limit(limit)
      .get();
    const res: Booking[] = [];
    for (const doc of snap.docs) {
      const b = bookingFromFirestore(doc.id, doc.data());
      if (b) res.push(b);
    }
    return res;
  }

  async findUpcomingTransitions(now: Date, limit = 100): Promise<readonly Booking[]> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('status', '==', 'accepted')
      .limit(limit)
      .get();
    const res: Booking[] = [];
    for (const doc of snap.docs) {
      const b = bookingFromFirestore(doc.id, doc.data());
      if (b) res.push(b);
    }
    return res;
  }

  async findAutoCompletions(cutoff: Date, limit = 100): Promise<readonly Booking[]> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('status', 'in', ['upcoming', 'accepted'])
      .limit(limit)
      .get();
    const res: Booking[] = [];
    for (const doc of snap.docs) {
      const b = bookingFromFirestore(doc.id, doc.data());
      if (b) res.push(b);
    }
    return res;
  }

  async findReleasableEscrows(cutoff: Date, limit = 100): Promise<readonly Payment[]> {
    const snap = await this.firestore
      .collection(PAYMENTS_COLLECTION)
      .where('escrowStatus', 'in', ['held', 'partially_refunded'])
      .where('releaseAfter', '<=', Timestamp.fromDate(cutoff))
      .limit(limit)
      .get();
    const res: Payment[] = [];
    for (const doc of snap.docs) {
      const p = paymentFromFirestore(doc.id, doc.data());
      if (p) res.push(p);
    }
    return res;
  }
}
