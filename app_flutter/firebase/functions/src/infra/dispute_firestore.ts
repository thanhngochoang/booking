/**
 * Firestore adapter of the S18 dispute store (#142): `disputes/{id}`, the frozen payment, the refund and
 * ledger rows, the subject mirrors (`bookings/{id}`, `events/{e}/registrations/{r}`) and, through #204's
 * support adapter, the dispute thread. Every read of a transaction comes before its first write
 * (Firestore refuses a read after a write); the subject mirrors are written once, at the end.
 */

import {
  FieldValue,
  Timestamp,
  type DocumentData,
  type DocumentReference,
} from 'firebase-admin/firestore';
import {
  formatDayShortVi,
  formatVnDate,
  formatVnTime,
  isEscrowRefund,
  pickSubjectPayment,
  venueLinesAmong,
  ticketPayeeOf,
  type Booking,
  type Dispute,
  type DisputeStatus,
  type DisputeStore,
  type DisputeSubjectType,
  type DisputeSubjectView,
  type DisputeTx,
  type EscrowStatus,
  type EventRecord,
  type LedgerEntry,
  type Payment,
  type Refund,
  type RefundStatus,
  type RegistrationDoc,
  type SupportTx,
} from '@photobooking/domain';
import {
  BOOKINGS_COLLECTION,
  LEDGER_COLLECTION,
  PAYMENTS_COLLECTION,
  REFUNDS_COLLECTION,
  bookingFromFirestore,
  ledgerEntryToFirestore,
  paymentFromFirestore,
  paymentToFirestore,
  refundFromFirestore,
  refundToFirestore,
} from './booking_firestore.js';
import { DISPUTES_COLLECTION, disputeFromFirestore, disputeToFirestore } from './dispute_mapping.js';
import { EVENTS_COLLECTION, eventFromFirestore, registrationFromFirestore } from './event_firestore.js';
import { FirestoreSupportStore, FirestoreSupportTx } from './support_firestore.js';

export { DISPUTES_COLLECTION, disputeFromFirestore, disputeToFirestore };

const REGISTRATIONS = 'registrations';
const str = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);
const dateOf = (iso: string | undefined | null): Date | null => (iso ? new Date(iso) : null);

/**
 * The dispute view of a booking: the paying customer, the photographer (studio account for a studio
 * booking), the #152 window fields and the display copy kept on the dispute
 * (`"{photographer} · {service}"`, `"T7 12/10 · 15:30–17:30"`). Pure; the seed uses it too.
 */
export function bookingDisputeView(
  b: Booking,
  provider: { readonly name: string; readonly avatarUrl: string | null },
): DisputeSubjectView {
  const name = provider.name.trim();
  return {
    type: 'booking',
    id: b.id,
    eventId: null,
    customerId: b.customerId,
    providerId: b.photographerId,
    state: b.status,
    windowStart: dateOf(b.completedAt),
    shotAt: dateOf(b.shotAt),
    checkUntil: dateOf(b.checkUntil),
    // S30: "Không diễn ra" makes an upcoming booking disputable (dispute.ts).
    shootDeniedAt: dateOf(b.shootDeniedAt),
    amount: b.deposit,
    paymentId: null,
    disputeId: b.disputeId ?? null,
    snapshot: {
      title: name !== '' ? `${name} · ${b.serviceSnapshot.name}` : b.serviceSnapshot.name,
      subtitle: `${formatDayShortVi(b.day)} · ${b.start}–${b.end}`,
      providerName: name !== '' ? name : null,
      thumbUrl: provider.avatarUrl,
    },
  };
}

/**
 * The dispute view of a ticket: the registration's buyer, the event's payee (host photographer or
 * `'platform'`), the window from the event's end, and the event title and Vietnam-time slot.
 */
export function ticketDisputeView(reg: RegistrationDoc, ev: EventRecord): DisputeSubjectView {
  const start = ev.startAt ?? reg.event.startAt;
  const end = ev.endAt ?? reg.event.endAt;
  return {
    type: 'ticket',
    id: reg.id,
    eventId: ev.id,
    customerId: reg.userId,
    providerId: ticketPayeeOf(ev),
    state: reg.status,
    windowStart: end,
    shotAt: null,
    checkUntil: null,
    amount: reg.amount,
    paymentId: reg.paymentId,
    disputeId: reg.disputeId ?? null,
    snapshot: {
      title: ev.title || reg.event.title,
      subtitle: `${formatDayShortVi(formatVnDate(start))} · ${formatVnTime(start)}–${formatVnTime(end)}`,
      // S30: an organizer host is the payee too; its name is the organizer's (`host.name`).
      providerName: ev.host.type === 'photographer' || ev.host.type === 'organizer' ? ev.host.name : null,
      thumbUrl: ev.coverUrl ?? reg.event.coverUrl,
    },
  };
}

/** What a refund read in this transaction mirrors on its subject when its status changes. */
type RefundMirror =
  | { readonly kind: 'booking'; readonly ref: DocumentReference; stamped: boolean }
  | { readonly kind: 'ticket'; readonly ref: DocumentReference; readonly refundId: string | null; refundStatus: RefundStatus | null };

export class FirestoreDisputeTx extends FirestoreSupportTx implements DisputeTx {
  private readonly links: { readonly subject: DisputeSubjectView; readonly patch: { readonly disputeId: string; readonly escrowStatus: EscrowStatus } }[] = [];
  /** Refunds created in this transaction (the dispute's refund at resolution). */
  private readonly created: Refund[] = [];
  private readonly mirrors = new Map<string, RefundMirror>();

  private bookingRef(id: string): DocumentReference {
    return this.firestore.collection(BOOKINGS_COLLECTION).doc(id);
  }

  private registrationRef(eventId: string, id: string): DocumentReference {
    return this.firestore.collection(EVENTS_COLLECTION).doc(eventId).collection(REGISTRATIONS).doc(id);
  }

  async getSubject(type: DisputeSubjectType, id: string, eventId: string | null): Promise<DisputeSubjectView | null> {
    if (type === 'booking') {
      const snap = await this.tx.get(this.bookingRef(id));
      const b = snap.exists ? bookingFromFirestore(id, snap.data()) : null;
      if (!b) return null;
      const user = (await this.tx.get(this.firestore.collection('users').doc(b.photographerId))).data() ?? {};
      return bookingDisputeView(b, { name: str(user.displayName) ?? '', avatarUrl: str(user.avatarUrl) });
    }
    if (eventId === null) return null;
    const reg = await this.tx.get(this.registrationRef(eventId, id));
    const ev = await this.tx.get(this.firestore.collection(EVENTS_COLLECTION).doc(eventId));
    const regData = reg.data();
    const evData = ev.data();
    if (!reg.exists || !ev.exists || !regData || !evData) return null;
    return ticketDisputeView(registrationFromFirestore(id, regData), eventFromFirestore(eventId, evData));
  }

  async getPayment(id: string): Promise<Payment | null> {
    const snap = await this.tx.get(this.firestore.collection(PAYMENTS_COLLECTION).doc(id));
    return snap.exists ? paymentFromFirestore(id, snap.data()) : null;
  }

  /**
   * Also reads what the refund mirrors (its payment, then the booking or registration), so that a status
   * written back in this transaction (`dispatchDisputeRefund`) reaches the subject like V2's handlers do.
   */
  async getRefund(id: string): Promise<Refund | null> {
    const snap = await this.tx.get(this.firestore.collection(REFUNDS_COLLECTION).doc(id));
    const refund = snap.exists ? refundFromFirestore(id, snap.data()) : null;
    if (!refund || (refund.subjectType !== 'booking' && refund.subjectType !== 'event_registration')) return refund;
    const payment = await this.getPayment(refund.paymentId);
    if (!payment) return refund;
    if (payment.subjectType === 'booking') {
      const ref = this.bookingRef(payment.subjectId);
      const booking = await this.tx.get(ref);
      if (booking.exists) this.mirrors.set(id, { kind: 'booking', ref, stamped: booking.data()?.depositRefundedAt != null });
    } else if (payment.subjectType === 'event_registration' && payment.eventId !== undefined) {
      const ref = this.registrationRef(payment.eventId, payment.subjectId);
      const reg = await this.tx.get(ref);
      const d = reg.data();
      if (reg.exists && d) {
        this.mirrors.set(id, { kind: 'ticket', ref, refundId: str(d.refundId), refundStatus: (str(d.refundStatus) as RefundStatus | null) });
      }
    }
    return refund;
  }

  async findSubjectPayment(subject: DisputeSubjectView): Promise<Payment | null> {
    if (subject.type === 'ticket') return subject.paymentId === null ? null : this.getPayment(subject.paymentId);
    const q = this.firestore
      .collection(PAYMENTS_COLLECTION)
      .where('subjectType', '==', 'booking')
      .where('subjectId', '==', subject.id);
    const snap = await this.tx.get(q);
    return pickSubjectPayment(snap.docs.map((d) => paymentFromFirestore(d.id, d.data())).filter((p): p is Payment => p !== null));
  }

  /** S30 Decision 16: the group's lines (single-field `groupId`), filtered to the ticket's venue-fee lines. */
  async venueLinesOf(payment: Payment): Promise<Payment[]> {
    if (payment.groupId === undefined || payment.subjectType !== 'event_registration') return [];
    const snap = await this.tx.get(this.firestore.collection(PAYMENTS_COLLECTION).where('groupId', '==', payment.groupId));
    const all = snap.docs.map((d) => paymentFromFirestore(d.id, d.data())).filter((p): p is Payment => p !== null);
    return venueLinesAmong(payment, all);
  }

  setDispute(d: Dispute): void {
    this.tx.set(this.firestore.collection(DISPUTES_COLLECTION).doc(d.id), disputeToFirestore(d));
  }

  setPayment(p: Payment): void {
    this.tx.set(this.firestore.collection(PAYMENTS_COLLECTION).doc(p.id), paymentToFirestore(p));
  }

  linkSubject(subject: DisputeSubjectView, patch: { readonly disputeId: string; readonly escrowStatus: EscrowStatus }): void {
    this.links.push({ subject, patch });
  }

  addRefund(r: Refund): void {
    this.tx.set(this.firestore.collection(REFUNDS_COLLECTION).doc(r.id), refundToFirestore(r));
    const mirror = this.mirrors.get(r.id);
    if (mirror === undefined) {
      this.created.push(r);
      return;
    }
    // V2's rules: a booking's `depositRefundedAt` once an escrow refund is done (the refund notice);
    // a ticket's `refundStatus` when the registration carries this refund.
    if (mirror.kind === 'booking') {
      if (!mirror.stamped && r.status === 'done' && isEscrowRefund(r)) {
        this.tx.update(mirror.ref, { depositRefundedAt: Timestamp.fromDate(new Date(r.updatedAt)) });
        mirror.stamped = true;
      }
    } else if (mirror.refundId === r.id && mirror.refundStatus !== r.status) {
      this.tx.update(mirror.ref, { refundStatus: r.status });
      mirror.refundStatus = r.status;
    }
  }

  addLedgerEntry(e: LedgerEntry): void {
    this.tx.set(this.firestore.collection(LEDGER_COLLECTION).doc(e.id), ledgerEntryToFirestore(e));
  }

  /**
   * Writes the subject mirrors, one update per subject (called after the use case, before commit):
   * booking `disputeId` + `escrowStatus` (+ `depositRefunded` grows by a refund created here);
   * registration `disputeId` (+ `refundId`/`refundStatus` of a refund created here).
   */
  commitMirrors(): void {
    for (const { subject, patch } of this.links) {
      if (subject.type === 'booking') {
        const refunded = this.created.filter((r) => r.subjectType === 'booking').reduce((sum, r) => sum + r.amount, 0);
        const data: DocumentData = { disputeId: patch.disputeId, escrowStatus: patch.escrowStatus };
        if (refunded > 0) data.depositRefunded = FieldValue.increment(refunded);
        this.tx.update(this.bookingRef(subject.id), data);
      } else if (subject.eventId !== null) {
        const refund = this.created.filter((r) => r.subjectType === 'event_registration').at(-1);
        const data: DocumentData = { disputeId: patch.disputeId };
        if (refund) Object.assign(data, { refundId: refund.id, refundStatus: refund.status });
        this.tx.update(this.registrationRef(subject.eventId, subject.id), data);
      }
    }
    this.links.length = 0;
  }
}

export class FirestoreDisputeStore extends FirestoreSupportStore implements DisputeStore {
  override async runTransaction<T>(fn: (tx: DisputeTx & SupportTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx) => {
      const tx = new FirestoreDisputeTx(this.firestore, fTx);
      const result = await fn(tx);
      tx.commitMirrors();
      return result;
    });
  }

  async getRefundsForPayment(paymentId: string): Promise<readonly Refund[]> {
    const snap = await this.firestore.collection(REFUNDS_COLLECTION).where('paymentId', '==', paymentId).get();
    return snap.docs.map((d) => refundFromFirestore(d.id, d.data())).filter((r): r is Refund => r !== null);
  }

  /** Index `disputes (status ASC, createdAt ASC)`. */
  async listByStatus(status: DisputeStatus, limit: number): Promise<readonly Dispute[]> {
    const snap = await this.firestore
      .collection(DISPUTES_COLLECTION)
      .where('status', '==', status)
      .orderBy('createdAt', 'asc')
      .limit(limit)
      .get();
    return snap.docs.map((d) => disputeFromFirestore(d.data())).filter((d): d is Dispute => d !== null);
  }
}
