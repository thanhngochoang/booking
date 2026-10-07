import { Timestamp, type DocumentData, type Firestore, type Transaction } from 'firebase-admin/firestore';
import {
  PAYOUT_STATUSES,
  isPayoutPayable,
  type LedgerEntry,
  type Payment,
  type Payout,
  type PayoutAccount,
  type PayoutAccountView,
  type PayoutStatus,
  type PayoutStore,
  type PayoutTx,
} from '@photobooking/domain';
import {
  LEDGER_COLLECTION,
  PAYMENTS_COLLECTION,
  REFUNDS_COLLECTION,
  ledgerEntryToFirestore,
  paymentFromFirestore,
  paymentToFirestore,
} from './booking_firestore.js';

export const PAYOUTS_COLLECTION = 'payouts';
export const PAYOUT_ACCOUNTS_COLLECTION = 'payoutAccounts';

const ts = (iso: string): Timestamp => Timestamp.fromDate(new Date(iso));
const iso = (v: unknown): string | undefined => (v instanceof Timestamp ? v.toDate().toISOString() : undefined);

export function payoutToFirestore(p: Payout): DocumentData {
  return {
    payeeId: p.payeeId,
    accountId: p.accountId,
    amount: p.amount,
    status: p.status,
    items: p.items.map((i) => ({ paymentId: i.paymentId, amount: i.amount })),
    reference: p.reference ?? null,
    failureReason: p.failureReason ?? null,
    holdReason: p.holdReason ?? null,
    createdBy: p.createdBy,
    createdAt: ts(p.createdAt),
    updatedAt: ts(p.updatedAt),
    processingAt: p.processingAt ? ts(p.processingAt) : null,
    paidAt: p.paidAt ? ts(p.paidAt) : null,
  };
}

const str = (v: unknown): string | undefined => (typeof v === 'string' && v !== '' ? v : undefined);

export function payoutFromFirestore(id: string, d: DocumentData | undefined): Payout | null {
  if (d === undefined || typeof d.payeeId !== 'string') return null;
  const status = (PAYOUT_STATUSES as readonly unknown[]).includes(d.status) ? (d.status as PayoutStatus) : 'pending';
  const items: { paymentId: string; amount: number }[] = [];
  if (Array.isArray(d.items)) {
    for (const i of d.items as { paymentId?: unknown; amount?: unknown }[]) {
      if (typeof i?.paymentId === 'string' && typeof i.amount === 'number') items.push({ paymentId: i.paymentId, amount: i.amount });
    }
  }
  const processingAt = iso(d.processingAt);
  const paidAt = iso(d.paidAt);
  return {
    id,
    payeeId: d.payeeId,
    accountId: String(d.accountId ?? ''),
    amount: typeof d.amount === 'number' ? d.amount : 0,
    status,
    items,
    ...(str(d.reference) !== undefined ? { reference: str(d.reference) as string } : {}),
    ...(str(d.failureReason) !== undefined ? { failureReason: str(d.failureReason) as string } : {}),
    ...(str(d.holdReason) !== undefined ? { holdReason: str(d.holdReason) as string } : {}),
    createdBy: String(d.createdBy ?? ''),
    createdAt: iso(d.createdAt) ?? new Date(0).toISOString(),
    updatedAt: iso(d.updatedAt) ?? new Date(0).toISOString(),
    ...(processingAt !== undefined ? { processingAt } : {}),
    ...(paidAt !== undefined ? { paidAt } : {}),
  };
}

export function accountToFirestore(a: PayoutAccount): DocumentData {
  return {
    userId: a.userId,
    bankCode: a.bankCode,
    accountNumberEnc: a.accountNumberEnc,
    accountLast4: a.accountLast4,
    holderName: a.holderName,
    active: a.active,
    createdAt: ts(a.createdAt),
    ...(a.deactivatedAt ? { deactivatedAt: ts(a.deactivatedAt) } : {}),
  };
}

export function accountFromFirestore(id: string, d: DocumentData | undefined): PayoutAccount | null {
  if (d === undefined || typeof d.userId !== 'string' || typeof d.accountNumberEnc !== 'string') return null;
  const deactivatedAt = iso(d.deactivatedAt);
  return {
    id,
    userId: d.userId,
    bankCode: String(d.bankCode ?? ''),
    accountNumberEnc: d.accountNumberEnc,
    accountLast4: String(d.accountLast4 ?? ''),
    holderName: String(d.holderName ?? ''),
    active: d.active === true,
    createdAt: iso(d.createdAt) ?? new Date(0).toISOString(),
    ...(deactivatedAt !== undefined ? { deactivatedAt } : {}),
  };
}

export function accountViewToFirestore(v: PayoutAccountView): DocumentData {
  return {
    accountId: v.accountId,
    bankCode: v.bankCode,
    accountLast4: v.accountLast4,
    holderName: v.holderName,
    updatedAt: ts(v.updatedAt),
  };
}

/**
 * Payout accounts, payouts, payments and ledger entries in Firestore. Writes are buffered until
 * the callback has finished all its reads (Firestore needs reads before writes), then applied.
 */
export class FirestorePayoutStore implements PayoutStore {
  constructor(private readonly db: Firestore) {}

  private refundedOf(paymentId: string, read: (q: FirebaseFirestore.Query) => Promise<FirebaseFirestore.QuerySnapshot>): Promise<number> {
    return read(this.db.collection(REFUNDS_COLLECTION).where('paymentId', '==', paymentId)).then((snap) =>
      snap.docs.reduce((sum, d) => sum + (typeof d.data().amount === 'number' ? (d.data().amount as number) : 0), 0),
    );
  }

  async listDuePayees(): Promise<{ payeeId: string; amount: number; hasAccount: boolean }[]> {
    const snap = await this.db.collection(PAYMENTS_COLLECTION).where('escrowStatus', '==', 'released').get();
    const totals = new Map<string, number>();
    for (const d of snap.docs) {
      const p = paymentFromFirestore(d.id, d.data());
      if (p === null || !isPayoutPayable(p)) continue;
      const net = p.amount - (await this.refundedOf(p.id, (q) => q.get()));
      if (net > 0) totals.set(p.payeeId, (totals.get(p.payeeId) ?? 0) + net);
    }
    const out: { payeeId: string; amount: number; hasAccount: boolean }[] = [];
    for (const [payeeId, amount] of totals) {
      const account = await this.db.collection(PAYOUT_ACCOUNTS_COLLECTION).doc(payeeId).get();
      out.push({ payeeId, amount, hasAccount: account.exists });
    }
    return out.sort((a, b) => a.payeeId.localeCompare(b.payeeId));
  }

  async runTransaction<T>(fn: (tx: PayoutTx) => Promise<T>): Promise<T> {
    return this.db.runTransaction(async (fTx: Transaction) => {
      const writes: Array<(t: Transaction) => void> = [];
      const accounts = (uid: string) => this.db.collection(PAYOUT_ACCOUNTS_COLLECTION).doc(uid).collection('accounts');
      const tx: PayoutTx = {
        getUserRole: async (uid) => {
          const role: unknown = (await fTx.get(this.db.collection('users').doc(uid))).data()?.role;
          return typeof role === 'string' ? role : null;
        },
        getActiveAccount: async (userId) => {
          const snap = await fTx.get(accounts(userId).where('active', '==', true).limit(1));
          const d = snap.docs[0];
          return d === undefined ? null : accountFromFirestore(d.id, d.data());
        },
        getAccount: async (userId, accountId) => {
          const snap = await fTx.get(accounts(userId).doc(accountId));
          return accountFromFirestore(snap.id, snap.data());
        },
        listPayouts: async (payeeId, statuses) => {
          if (statuses.length === 0) return [];
          const snap = await fTx.get(
            this.db.collection(PAYOUTS_COLLECTION).where('payeeId', '==', payeeId).where('status', 'in', [...statuses]),
          );
          return snap.docs.flatMap((d) => payoutFromFirestore(d.id, d.data()) ?? []);
        },
        putAccount: (a) => writes.push((t) => t.set(accounts(a.userId).doc(a.id), accountToFirestore(a))),
        putAccountView: (userId, v) =>
          writes.push((t) => t.set(this.db.collection(PAYOUT_ACCOUNTS_COLLECTION).doc(userId), accountViewToFirestore(v))),
        putPayout: (p) => writes.push((t) => t.set(this.db.collection(PAYOUTS_COLLECTION).doc(p.id), payoutToFirestore(p))),
        listPayablePayments: async (payeeId) => {
          const snap = await fTx.get(
            this.db.collection(PAYMENTS_COLLECTION).where('payeeId', '==', payeeId).where('escrowStatus', '==', 'released'),
          );
          return snap.docs.flatMap((d) => {
            const p = paymentFromFirestore(d.id, d.data());
            // Bookings and event tickets (payee = host); the platform payee never matches a provider.
            return p === null || !isPayoutPayable(p) ? [] : [p];
          });
        },
        getPayments: async (ids) => {
          if (ids.length === 0) return [];
          const snaps = await fTx.getAll(...ids.map((id) => this.db.collection(PAYMENTS_COLLECTION).doc(id)));
          return snaps.map((s) => (s.exists ? paymentFromFirestore(s.id, s.data()) : null));
        },
        refundedTotal: (paymentId) => this.refundedOf(paymentId, (q) => fTx.get(q)),
        getPayout: async (id) => {
          const snap = await fTx.get(this.db.collection(PAYOUTS_COLLECTION).doc(id));
          return payoutFromFirestore(snap.id, snap.data());
        },
        setPayment: (p: Payment) =>
          writes.push((t) => t.set(this.db.collection(PAYMENTS_COLLECTION).doc(p.id), paymentToFirestore(p))),
        addLedgerEntry: (e: LedgerEntry) =>
          writes.push((t) => t.set(this.db.collection(LEDGER_COLLECTION).doc(e.id), ledgerEntryToFirestore(e))),
      };
      const result = await fn(tx);
      for (const w of writes) w(fTx);
      return result;
    });
  }
}
