import { Timestamp, type DocumentData, type Firestore, type Transaction } from 'firebase-admin/firestore';
import {
  EMPTY_PAYER_SUBJECT,
  PAYER_ROW_STATUSES,
  REFUND_METHODS,
  REFUND_STATUSES,
  formatVnDate,
  isPaymentMethod,
  isPaymentSubject,
  type Payment,
  type PaymentSubject,
  type PayerHistoryStore,
  type PayerHistoryTx,
  type PayerPaymentRow,
  type PayerRefundView,
  type PayerRowStatus,
  type PayerSubjectView,
  type RefundMethod,
  type RefundStatus,
} from '@photobooking/domain';
import {
  BOOKINGS_COLLECTION,
  PAYMENTS_COLLECTION,
  REFUNDS_COLLECTION,
  paymentFromFirestore,
  refundFromFirestore,
} from './booking_firestore.js';
import { INSTANT_REQUESTS } from './instant_firestore.js';

/** `users/{uid}/payments/{paymentId}`: the payer's S22.01 rows (owner read, server write). */
export const PAYER_PAYMENTS = 'payments';
/** `users/{uid}/private/paymentTotals`: `{held, refunding, updatedAt}`. */
export const PAYMENT_TOTALS_DOC = 'paymentTotals';

const ts = (iso: string): Timestamp => Timestamp.fromDate(new Date(iso));
const tsOrNull = (iso: string | null): Timestamp | null => (iso === null ? null : ts(iso));
const isoOf = (v: unknown): string | null => (v instanceof Timestamp ? v.toDate().toISOString() : null);
const str = (v: unknown, fallback = ''): string => (typeof v === 'string' ? v : fallback);
const strOrNull = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);
const int = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? v : 0);
const oneOf = <T extends string>(list: readonly T[], v: unknown, fallback: T): T =>
  (list as readonly unknown[]).includes(v) ? (v as T) : fallback;

/** The fields are listed one by one: nothing else of a payment or refund reaches the customer. */
export function payerRowToFirestore(r: PayerPaymentRow): DocumentData {
  return {
    payerId: r.payerId,
    subjectType: r.subjectType,
    subjectId: r.subjectId,
    eventId: r.eventId,
    photographerName: r.photographerName,
    serviceName: r.serviceName,
    eventTitle: r.eventTitle,
    quantity: r.quantity,
    areaLabel: r.areaLabel,
    day: r.day,
    method: r.method,
    amount: r.amount,
    status: r.status,
    open: r.open,
    toPlatform: r.toPlatform,
    heldAmount: r.heldAmount,
    refundingAmount: r.refundingAmount,
    refundedAmount: r.refundedAmount,
    searching: r.searching,
    cancelled: r.cancelled,
    refunds: r.refunds.map((x) => ({
      refundId: x.refundId,
      amount: x.amount,
      status: x.status,
      method: x.method,
      kind: x.kind,
      destinationLabel: x.destinationLabel,
      createdAt: ts(x.createdAt),
      doneAt: tsOrNull(x.doneAt),
    })),
    createdAt: ts(r.createdAt),
    paidAt: tsOrNull(r.paidAt),
    updatedAt: ts(r.updatedAt),
  };
}

function refundViewFrom(d: DocumentData): PayerRefundView {
  return {
    refundId: str(d.refundId),
    amount: int(d.amount),
    status: oneOf<RefundStatus>(REFUND_STATUSES, d.status, 'pending'),
    method: oneOf<RefundMethod>(REFUND_METHODS, d.method, 'gateway'),
    kind: d.kind === 'excess' ? 'excess' : 'policy',
    destinationLabel: strOrNull(d.destinationLabel),
    createdAt: isoOf(d.createdAt) ?? new Date(0).toISOString(),
    doneAt: isoOf(d.doneAt),
  };
}

export function payerRowFromFirestore(id: string, d: DocumentData | undefined): PayerPaymentRow | null {
  if (d === undefined) return null;
  return {
    paymentId: id,
    payerId: str(d.payerId),
    subjectType: isPaymentSubject(d.subjectType) ? d.subjectType : 'booking',
    subjectId: str(d.subjectId),
    eventId: strOrNull(d.eventId),
    photographerName: strOrNull(d.photographerName),
    serviceName: strOrNull(d.serviceName),
    eventTitle: strOrNull(d.eventTitle),
    quantity: typeof d.quantity === 'number' && Number.isFinite(d.quantity) ? d.quantity : null,
    areaLabel: strOrNull(d.areaLabel),
    day: strOrNull(d.day),
    method: isPaymentMethod(d.method) ? d.method : null,
    amount: int(d.amount),
    status: oneOf<PayerRowStatus>(PAYER_ROW_STATUSES, d.status, 'held'),
    open: d.open === true,
    toPlatform: d.toPlatform === true,
    heldAmount: int(d.heldAmount),
    refundingAmount: int(d.refundingAmount),
    refundedAmount: int(d.refundedAmount),
    searching: d.searching === true,
    cancelled: d.cancelled === true,
    refunds: Array.isArray(d.refunds) ? d.refunds.filter((x): x is DocumentData => typeof x === 'object' && x !== null).map(refundViewFrom) : [],
    createdAt: isoOf(d.createdAt) ?? new Date(0).toISOString(),
    paidAt: isoOf(d.paidAt),
    updatedAt: isoOf(d.updatedAt) ?? new Date(0).toISOString(),
  };
}

const BOOKING_CANCELLED = ['cancelled', 'declined', 'expired'];
const TICKET_CANCELLED = ['cancelled', 'refunded'];
// `choosing`: paid, nobody assigned yet (the first round, or again after a photographer cancelled).
const INSTANT_SEARCHING = ['choosing', 'pending_payment', 'searching'];
// Terminal ends (`no_match` is not one: the customer may still reopen or cancel).
const INSTANT_CANCELLED = ['abandoned', 'cancelled_by_customer', 'no_show_customer'];
const dateOf = (v: unknown): Date | null => (v instanceof Timestamp ? v.toDate() : v instanceof Date ? v : null);

/** A booking: the photographer and the service (the app writes "Minh Trí · Chân dung 2 giờ"), the shoot day. */
export function bookingSubjectOf(b: DocumentData, photographerName: string | null): PayerSubjectView {
  return {
    ...EMPTY_PAYER_SUBJECT,
    photographerName: photographerName === '' ? null : photographerName,
    serviceName: strOrNull(b.serviceSnapshot?.name),
    day: strOrNull(b.day),
    cancelled: BOOKING_CANCELLED.includes(str(b.status)),
  };
}

/** A ticket (`events/{eventId}/registrations/{id}`): the event title and number of tickets, the Vietnam day it starts. */
export function ticketSubjectOf(r: DocumentData, eventId: string): PayerSubjectView {
  const ev = (r.event ?? {}) as { title?: unknown; startAt?: unknown };
  const start = dateOf(ev.startAt);
  return {
    ...EMPTY_PAYER_SUBJECT,
    eventTitle: strOrNull(ev.title),
    quantity: typeof r.quantity === 'number' && r.quantity > 0 ? r.quantity : null,
    day: start === null ? null : formatVnDate(start),
    eventId,
    cancelled: TICKET_CANCELLED.includes(str(r.status)),
  };
}

/** A Chụp ngay request: its area label; searching until a photographer accepts (#140/#202). */
export function instantSubjectOf(r: DocumentData): PayerSubjectView {
  const status = str(r.status);
  return {
    ...EMPTY_PAYER_SUBJECT,
    areaLabel: strOrNull(r.areaLabel),
    searching: INSTANT_SEARCHING.includes(status),
    cancelled: INSTANT_CANCELLED.includes(status),
  };
}

/** The row as stored, for a subject whose document is gone: its parts and day are kept. */
export function storedSubjectOf(id: string, d: DocumentData | undefined): PayerSubjectView | null {
  const row = payerRowFromFirestore(id, d);
  return row === null
    ? null
    : {
        photographerName: row.photographerName,
        serviceName: row.serviceName,
        eventTitle: row.eventTitle,
        quantity: row.quantity,
        areaLabel: row.areaLabel,
        day: row.day,
        eventId: row.eventId,
        searching: false,
        cancelled: row.cancelled,
      };
}

/**
 * S22.01 rows in Firestore. One transaction per refresh; every read (payment, refunds, subject,
 * the stored row, the open rows) comes before the first write, as the Admin SDK requires.
 */
export class FirestorePayerHistoryStore implements PayerHistoryStore {
  constructor(private readonly db: Firestore) {}

  private rows(uid: string) {
    return this.db.collection('users').doc(uid).collection(PAYER_PAYMENTS);
  }

  private async subjectOf(fTx: Transaction, p: Payment): Promise<PayerSubjectView> {
    const read = async (path: string) => (await fTx.get(this.db.doc(path))).data();
    const stored = async (fallback: PayerSubjectView) =>
      storedSubjectOf(p.id, await read(`users/${p.payerId}/${PAYER_PAYMENTS}/${p.id}`)) ?? fallback;
    switch (p.subjectType) {
      case 'booking': {
        const b = await read(`${BOOKINGS_COLLECTION}/${p.subjectId}`);
        if (b === undefined) return stored(EMPTY_PAYER_SUBJECT);
        const photographerId = str(b.photographerId);
        const name = photographerId === '' ? null : strOrNull((await read(`users/${photographerId}`))?.displayName);
        return bookingSubjectOf(b, name);
      }
      case 'event_registration': {
        const eventId = p.eventId ?? '';
        const r = eventId === '' ? undefined : await read(`events/${eventId}/registrations/${p.subjectId}`);
        return r === undefined ? stored({ ...EMPTY_PAYER_SUBJECT, eventId: strOrNull(eventId) }) : ticketSubjectOf(r, eventId);
      }
      case 'instant_request': {
        const r = await read(`${INSTANT_REQUESTS}/${p.subjectId}`);
        return r === undefined ? stored(EMPTY_PAYER_SUBJECT) : instantSubjectOf(r);
      }
      case 'verification_fee':
        // The app's own title (`verifyFeeTitle`); nothing to read.
        return EMPTY_PAYER_SUBJECT;
    }
  }

  async paymentIdsOf(subjectType: PaymentSubject, subjectId: string): Promise<readonly string[]> {
    // One equality filter (single-field index); a booking has a few QR attempts at most.
    const snap = await this.db.collection(PAYMENTS_COLLECTION).where('subjectId', '==', subjectId).get();
    return snap.docs.filter((d) => d.data().subjectType === subjectType).map((d) => d.id);
  }

  async runTransaction<T>(fn: (tx: PayerHistoryTx) => Promise<T>): Promise<T> {
    return this.db.runTransaction(async (fTx) => {
      const tx: PayerHistoryTx = {
        payment: async (id) => {
          const s = await fTx.get(this.db.collection(PAYMENTS_COLLECTION).doc(id));
          return s.exists ? paymentFromFirestore(s.id, s.data()) : null;
        },
        refundsOf: async (paymentId) => {
          const snap = await fTx.get(this.db.collection(REFUNDS_COLLECTION).where('paymentId', '==', paymentId));
          return snap.docs.flatMap((d) => refundFromFirestore(d.id, d.data()) ?? []);
        },
        subjectOf: (p) => this.subjectOf(fTx, p),
        openRows: async (payerId) => {
          // The totals document `putTotals` overwrites: reading it makes two concurrent refreshes of
          // one payer contend on it (the loser retries and sees the other's open row), so totals cannot drift.
          await fTx.get(this.db.collection('users').doc(payerId).collection('private').doc(PAYMENT_TOTALS_DOC));
          const snap = await fTx.get(this.rows(payerId).where('open', '==', true));
          return snap.docs.flatMap((d) => payerRowFromFirestore(d.id, d.data()) ?? []);
        },
        putRow: (row) => {
          fTx.set(this.rows(row.payerId).doc(row.paymentId), payerRowToFirestore(row));
        },
        deleteRow: (payerId, paymentId) => {
          fTx.delete(this.rows(payerId).doc(paymentId));
        },
        putTotals: (payerId, totals, at) => {
          fTx.set(this.db.collection('users').doc(payerId).collection('private').doc(PAYMENT_TOTALS_DOC), {
            held: totals.held,
            refunding: totals.refunding,
            updatedAt: Timestamp.fromDate(at),
          });
        },
      };
      return fn(tx);
    });
  }
}
