import { Timestamp, type DocumentData, type Firestore, type Transaction } from 'firebase-admin/firestore';
import {
  PAYER_ROW_STATUSES,
  REFUND_METHODS,
  REFUND_STATUSES,
  formatVnDate,
  isPaymentMethod,
  isPaymentSubject,
  type Payment,
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
    title: r.title,
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
    title: str(d.title),
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
const INSTANT_SEARCHING = ['pending_payment', 'searching'];
const INSTANT_CANCELLED = ['no_match', 'abandoned', 'cancelled_by_customer', 'no_show_customer'];
const NO_SUBJECT: PayerSubjectView = { title: '', day: null, eventId: null, searching: false, cancelled: false };
const dateOf = (v: unknown): Date | null => (v instanceof Timestamp ? v.toDate() : v instanceof Date ? v : null);

/** A booking: "Minh Trí · Chân dung 2 giờ" (photographer · service), the shoot day. */
export function bookingSubjectOf(b: DocumentData, photographerName: string): PayerSubjectView {
  return {
    title: [photographerName, str(b.serviceSnapshot?.name)].filter((s) => s !== '').join(' · '),
    day: strOrNull(b.day),
    eventId: null,
    searching: false,
    cancelled: BOOKING_CANCELLED.includes(str(b.status)),
  };
}

/** A ticket (`events/{eventId}/registrations/{id}`): "Photo walk phố cổ · 2 vé", the Vietnam day the event starts. */
export function ticketSubjectOf(r: DocumentData, eventId: string): PayerSubjectView {
  const ev = (r.event ?? {}) as { title?: unknown; startAt?: unknown };
  const title = str(ev.title);
  const quantity = int(r.quantity);
  const start = dateOf(ev.startAt);
  return {
    title: quantity > 0 ? `${title} · ${quantity} vé` : title,
    day: start === null ? null : formatVnDate(start),
    eventId,
    searching: false,
    cancelled: TICKET_CANCELLED.includes(str(r.status)),
  };
}

/** A Chụp ngay request: "Chụp ngay · Quận 1", "đang tìm thợ" until someone accepts (#140/#202). */
export function instantSubjectOf(r: DocumentData): PayerSubjectView {
  const area = str(r.areaLabel);
  const status = str(r.status);
  return {
    title: area === '' ? 'Chụp ngay' : `Chụp ngay · ${area}`,
    day: null,
    eventId: null,
    searching: INSTANT_SEARCHING.includes(status),
    cancelled: INSTANT_CANCELLED.includes(status),
  };
}

/** The S21 verification fee (the app's own label is `verifyFeeTitle`). */
export const VERIFICATION_FEE_SUBJECT: PayerSubjectView = { ...NO_SUBJECT, title: 'Phí xác minh' };

/** The row as stored, for a subject whose document is gone: its title and day are kept. */
export function storedSubjectOf(id: string, d: DocumentData | undefined): PayerSubjectView | null {
  const row = payerRowFromFirestore(id, d);
  return row === null ? null : { title: row.title, day: row.day, eventId: row.eventId, searching: false, cancelled: row.cancelled };
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
        if (b === undefined) return stored(NO_SUBJECT);
        const photographerId = str(b.photographerId);
        const name = photographerId === '' ? '' : str((await read(`users/${photographerId}`))?.displayName);
        return bookingSubjectOf(b, name);
      }
      case 'event_registration': {
        const eventId = p.eventId ?? '';
        const r = eventId === '' ? undefined : await read(`events/${eventId}/registrations/${p.subjectId}`);
        return r === undefined ? stored({ ...NO_SUBJECT, eventId: strOrNull(eventId) }) : ticketSubjectOf(r, eventId);
      }
      case 'instant_request': {
        const r = await read(`${INSTANT_REQUESTS}/${p.subjectId}`);
        return r === undefined ? stored({ ...NO_SUBJECT, title: 'Chụp ngay' }) : instantSubjectOf(r);
      }
      case 'verification_fee':
        return VERIFICATION_FEE_SUBJECT;
    }
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
