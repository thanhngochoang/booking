import { Timestamp, type DocumentData, type Firestore } from 'firebase-admin/firestore';
import {
  EARNING_STATES,
  formatVnDate,
  isSettledPayment,
  providerTypeOf,
  type EarningItem,
  type EarningState,
  type EarningSubject,
  type EarningsStore,
  type EarningsSummary,
  type EarningsTx,
  type PaymentSubject,
  type Payout,
} from '@photobooking/domain';
import {
  BOOKINGS_COLLECTION,
  PAYMENTS_COLLECTION,
  REFUNDS_COLLECTION,
  escrowRefundedOfDocs,
  paymentFromFirestore,
} from './booking_firestore.js';
import { PAYOUTS_COLLECTION, payoutFromFirestore } from './payout_firestore.js';
import { PHOTOGRAPHERS_COLLECTION } from './review_firestore.js';

export const EARNINGS_COLLECTION = 'earnings';

const ts = (iso: string): Timestamp => Timestamp.fromDate(new Date(iso));
const iso = (v: unknown): string | null => (v instanceof Timestamp ? v.toDate().toISOString() : null);

export function earningItemToFirestore(i: EarningItem): DocumentData {
  return {
    payeeId: i.payeeId,
    subjectType: i.subjectType,
    subjectId: i.subjectId,
    counterpartName: i.counterpartName,
    subjectLabel: i.subjectLabel,
    day: i.day,
    amount: i.amount,
    platformFee: i.platformFee,
    taxWithheld: i.taxWithheld,
    netAmount: i.netAmount,
    feeRateBp: i.feeRateBp,
    taxRateBp: i.taxRateBp,
    estimated: i.estimated,
    milestonesDone: i.milestonesDone,
    milestonesTotal: i.milestonesTotal,
    state: i.state,
    holdReason: i.holdReason,
    paidOutAt: i.paidOutAt === null ? null : ts(i.paidOutAt),
    updatedAt: ts(i.updatedAt),
  };
}

const num = (v: unknown, fallback: number): number => (typeof v === 'number' && Number.isFinite(v) ? v : fallback);
const numOrNull = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) ? v : null);

/** A row written before the breakdown existed reads fee 0, tax 0, net = amount, estimated. */
export function earningItemFromFirestore(id: string, d: DocumentData): EarningItem {
  const amount = typeof d.amount === 'number' ? d.amount : 0;
  return {
    id,
    payeeId: String(d.payeeId ?? ''),
    subjectType: (d.subjectType === 'event_registration' ? 'event_registration' : 'booking') satisfies PaymentSubject,
    subjectId: String(d.subjectId ?? ''),
    counterpartName: String(d.counterpartName ?? ''),
    subjectLabel: String(d.subjectLabel ?? ''),
    day: String(d.day ?? ''),
    amount,
    platformFee: num(d.platformFee, 0),
    taxWithheld: num(d.taxWithheld, 0),
    netAmount: num(d.netAmount, amount),
    feeRateBp: num(d.feeRateBp, 0),
    taxRateBp: num(d.taxRateBp, 0),
    estimated: d.estimated !== false,
    milestonesDone: numOrNull(d.milestonesDone),
    milestonesTotal: numOrNull(d.milestonesTotal),
    state: ((EARNING_STATES as readonly unknown[]).includes(d.state) ? d.state : 'held') as EarningState,
    holdReason: typeof d.holdReason === 'string' ? d.holdReason : null,
    paidOutAt: iso(d.paidOutAt),
    updatedAt: iso(d.updatedAt) ?? new Date(0).toISOString(),
  };
}

export function earningsSummaryToFirestore(s: EarningsSummary): DocumentData {
  return {
    heldAmount: s.heldAmount,
    soonAmount: s.soonAmount,
    receivedAmount: s.receivedAmount,
    lastPayout: s.lastPayout === null ? null : { id: s.lastPayout.id, status: s.lastPayout.status, at: ts(s.lastPayout.at) },
    updatedAt: ts(s.updatedAt),
  };
}

/** Earnings projection in Firestore; writes are buffered until all reads are done. */
export class FirestoreEarningsStore implements EarningsStore {
  constructor(private readonly db: Firestore) {}

  async runTransaction<T>(fn: (tx: EarningsTx) => Promise<T>): Promise<T> {
    return this.db.runTransaction(async (fTx) => {
      const writes: Array<() => void> = [];
      const items = (uid: string) => this.db.collection(EARNINGS_COLLECTION).doc(uid).collection('items');
      const tx: EarningsTx = {
        getPayeeType: async (uid) =>
          providerTypeOf((await fTx.get(this.db.collection(PHOTOGRAPHERS_COLLECTION).doc(uid))).data()?.providerType),
        getPayment: async (id) => {
          const snap = await fTx.get(this.db.collection(PAYMENTS_COLLECTION).doc(id));
          return snap.exists ? paymentFromFirestore(snap.id, snap.data()) : null;
        },
        refundedTotal: async (paymentId) => {
          const snap = await fTx.get(this.db.collection(REFUNDS_COLLECTION).where('paymentId', '==', paymentId));
          return escrowRefundedOfDocs(snap.docs.map((d) => d.data()));
        },
        getSubject: async (p): Promise<EarningSubject | null> => {
          if (p.subjectType === 'event_registration') {
            // A ticket: the attendee, the event title and its day (snapshot on the registration).
            // An unpaid intent (escrow `held` from creation, like a deposit intent) is not money yet.
            if (p.eventId === undefined || p.status !== 'paid') return null;
            const r = (await fTx.get(
              this.db.collection('events').doc(p.eventId).collection('registrations').doc(p.subjectId),
            )).data();
            if (r === undefined) return null;
            const ev = (r.event ?? {}) as { title?: unknown; startAt?: unknown };
            const start = ev.startAt instanceof Timestamp ? ev.startAt.toDate() : null;
            return {
              counterpartName: typeof r.userName === 'string' ? r.userName : '',
              label: typeof ev.title === 'string' ? ev.title : '',
              day: start === null ? '' : formatVnDate(start),
              milestones: null,
            };
          }
          if (p.subjectType !== 'booking') return null;
          // An unpaid QR payment (escrow `held` from creation) is not money yet (earningItemOf
          // drops it too; this saves the reads).
          if (!isSettledPayment(p) && p.status !== 'refunded') return null;
          const b = await fTx.get(this.db.collection(BOOKINGS_COLLECTION).doc(p.subjectId));
          const d = b.data();
          if (d === undefined) return null;
          const customerId: unknown = d.customerId;
          let counterpartName = '';
          if (typeof customerId === 'string' && customerId !== '') {
            const name: unknown = (await fTx.get(this.db.collection('users').doc(customerId))).data()?.displayName;
            if (typeof name === 'string') counterpartName = name;
          }
          const label: unknown = d.serviceSnapshot?.name;
          // Milestones (bookings/{id}/milestones) are not read yet: null.
          return { counterpartName, label: typeof label === 'string' ? label : '', day: String(d.day ?? ''), milestones: null };
        },
        getPayout: async (id): Promise<Payout | null> => {
          const snap = await fTx.get(this.db.collection(PAYOUTS_COLLECTION).doc(id));
          return snap.exists ? payoutFromFirestore(snap.id, snap.data()) : null;
        },
        latestPayout: async (payeeId) => {
          const snap = await fTx.get(
            this.db.collection(PAYOUTS_COLLECTION).where('payeeId', '==', payeeId).orderBy('createdAt', 'desc').limit(1),
          );
          const d = snap.docs[0];
          return d === undefined ? null : payoutFromFirestore(d.id, d.data());
        },
        listItems: async (payeeId) => {
          const snap = await fTx.get(items(payeeId));
          return snap.docs.map((d) => earningItemFromFirestore(d.id, d.data()));
        },
        putItem: (i) => writes.push(() => fTx.set(items(i.payeeId).doc(i.id), earningItemToFirestore(i))),
        deleteItem: (payeeId, id) => writes.push(() => fTx.delete(items(payeeId).doc(id))),
        putSummary: (s) =>
          writes.push(() => fTx.set(this.db.collection(EARNINGS_COLLECTION).doc(s.payeeId), earningsSummaryToFirestore(s))),
      };
      const result = await fn(tx);
      for (const w of writes) w();
      return result;
    });
  }
}
