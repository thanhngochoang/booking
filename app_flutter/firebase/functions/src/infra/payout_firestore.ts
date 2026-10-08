import { Timestamp, type DocumentData, type Firestore, type Transaction } from 'firebase-admin/firestore';
import {
  NAME_STATUSES,
  PAYOUT_STATUSES,
  isPayoutPayable,
  providerTypeOf,
  type LedgerEntry,
  type NameStatus,
  type Payment,
  type Payout,
  type PayoutItem,
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
  escrowRefundedOfDocs,
  ledgerEntryToFirestore,
  paymentFromFirestore,
  paymentToFirestore,
} from './booking_firestore.js';

import { PHOTOGRAPHERS_COLLECTION } from './review_firestore.js';

export const PAYOUTS_COLLECTION = 'payouts';
export const PAYOUT_ACCOUNTS_COLLECTION = 'payoutAccounts';

const ts = (iso: string): Timestamp => Timestamp.fromDate(new Date(iso));
const iso = (v: unknown): string | undefined => (v instanceof Timestamp ? v.toDate().toISOString() : undefined);

/** The payout gateway in use: only the fake reference adapter exists (owner ruling 2). */
export const PAYOUT_PROVIDER = 'fake';

export function payoutToFirestore(p: Payout): DocumentData {
  return {
    // The key the gateway must send to the bank so a retry never pays twice (PayoutGateway.transfer).
    idempotencyKey: p.id,
    provider: PAYOUT_PROVIDER,
    payeeId: p.payeeId,
    accountId: p.accountId,
    amount: p.amount,
    status: p.status,
    items: p.items.map((i) => ({ paymentId: i.paymentId, amount: i.amount, fee: i.fee, tax: i.tax, net: i.net })),
    platformFee: p.platformFee,
    taxWithheld: p.taxWithheld,
    amountNet: p.amountNet,
    feeRateBp: p.feeRateBp,
    taxRateBp: p.taxRateBp,
    firstPayout: p.firstPayout,
    approvedBy: p.approvedBy ?? null,
    approvedAt: p.approvedAt ? ts(p.approvedAt) : null,
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
const int = (v: unknown, fallback: number): number => (typeof v === 'number' && Number.isFinite(v) ? v : fallback);

/** A payout written before tax existed reads fee 0, tax 0, net = amount, firstPayout false. */
export function payoutFromFirestore(id: string, d: DocumentData | undefined): Payout | null {
  if (d === undefined || typeof d.payeeId !== 'string') return null;
  const status = (PAYOUT_STATUSES as readonly unknown[]).includes(d.status) ? (d.status as PayoutStatus) : 'pending';
  const items: PayoutItem[] = [];
  if (Array.isArray(d.items)) {
    for (const i of d.items as { paymentId?: unknown; amount?: unknown; fee?: unknown; tax?: unknown; net?: unknown }[]) {
      if (typeof i?.paymentId === 'string' && typeof i.amount === 'number') {
        items.push({ paymentId: i.paymentId, amount: i.amount, fee: int(i.fee, 0), tax: int(i.tax, 0), net: int(i.net, i.amount) });
      }
    }
  }
  const amount = typeof d.amount === 'number' ? d.amount : 0;
  const processingAt = iso(d.processingAt);
  const paidAt = iso(d.paidAt);
  const approvedAt = iso(d.approvedAt);
  return {
    id,
    payeeId: d.payeeId,
    accountId: String(d.accountId ?? ''),
    amount,
    status,
    items,
    platformFee: int(d.platformFee, 0),
    taxWithheld: int(d.taxWithheld, 0),
    amountNet: int(d.amountNet, amount),
    feeRateBp: int(d.feeRateBp, 0),
    taxRateBp: int(d.taxRateBp, 0),
    firstPayout: d.firstPayout === true,
    ...(str(d.approvedBy) !== undefined ? { approvedBy: str(d.approvedBy) as string } : {}),
    ...(approvedAt !== undefined ? { approvedAt } : {}),
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
    nameStatus: a.nameStatus,
    activeFrom: ts(a.activeFrom),
  };
}

const nameStatusOf = (v: unknown): NameStatus =>
  (NAME_STATUSES as readonly unknown[]).includes(v) ? (v as NameStatus) : 'matched';

export function accountFromFirestore(id: string, d: DocumentData | undefined): PayoutAccount | null {
  if (d === undefined || typeof d.userId !== 'string' || typeof d.accountNumberEnc !== 'string') return null;
  const deactivatedAt = iso(d.deactivatedAt);
  const createdAt = iso(d.createdAt) ?? new Date(0).toISOString();
  return {
    id,
    userId: d.userId,
    bankCode: String(d.bankCode ?? ''),
    accountNumberEnc: d.accountNumberEnc,
    accountLast4: String(d.accountLast4 ?? ''),
    holderName: String(d.holderName ?? ''),
    active: d.active === true,
    createdAt,
    ...(deactivatedAt !== undefined ? { deactivatedAt } : {}),
    // An account written before the 72-hour rule: matched and active from its creation.
    nameStatus: nameStatusOf(d.nameStatus),
    activeFrom: iso(d.activeFrom) ?? createdAt,
  };
}

export function accountViewToFirestore(v: PayoutAccountView): DocumentData {
  return {
    accountId: v.accountId,
    bankCode: v.bankCode,
    accountLast4: v.accountLast4,
    holderName: v.holderName,
    updatedAt: ts(v.updatedAt),
    nameStatus: v.nameStatus,
    activeFrom: ts(v.activeFrom),
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
      escrowRefundedOfDocs(snap.docs.map((d) => d.data())),
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

  async listPayoutIdsByStatus(statuses: readonly PayoutStatus[], limit: number): Promise<string[]> {
    if (statuses.length === 0 || limit <= 0) return [];
    // Sorted here, not by the query, so no composite index is needed (open payouts are few).
    const snap = await this.db.collection(PAYOUTS_COLLECTION).where('status', 'in', [...statuses]).get();
    return snap.docs
      .map((d) => ({ id: d.id, createdAt: iso(d.data().createdAt) ?? '' }))
      .sort((a, b) => (a.createdAt === b.createdAt ? a.id.localeCompare(b.id) : a.createdAt.localeCompare(b.createdAt)))
      .slice(0, limit)
      .map((p) => p.id);
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
        getPayeeType: async (uid) =>
          providerTypeOf((await fTx.get(this.db.collection(PHOTOGRAPHERS_COLLECTION).doc(uid))).data()?.providerType),
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
        hasApprovedOrPaidPayout: async (accountId) => {
          const byAccount = this.db.collection(PAYOUTS_COLLECTION).where('accountId', '==', accountId);
          const paid = await fTx.get(byAccount.where('status', '==', 'paid').limit(1));
          if (!paid.empty) return true;
          const approved = await fTx.get(
            byAccount.where('status', 'in', ['pending', 'processing']).where('approvedBy', '!=', null).limit(1),
          );
          return !approved.empty;
        },
        lastFinishedPayouts: async (accountId, limit) => {
          if (limit <= 0) return [];
          const snap = await fTx.get(
            this.db
              .collection(PAYOUTS_COLLECTION)
              .where('accountId', '==', accountId)
              .where('status', 'in', ['paid', 'failed'])
              .orderBy('createdAt', 'desc')
              .limit(limit),
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
        // otp_challenges / payout_lookups adapters come with the account callables (#134 Task 5).
        // Until then they fail closed: nothing reads or writes those collections.
        getOtpChallenge: async () => {
          throw new Error('otp_challenges adapter not wired');
        },
        putOtpChallenge: () => {
          throw new Error('otp_challenges adapter not wired');
        },
        getLookupQuota: async () => {
          throw new Error('payout_lookups adapter not wired');
        },
        putLookupQuota: () => {
          throw new Error('payout_lookups adapter not wired');
        },
      };
      const result = await fn(tx);
      for (const w of writes) w(fTx);
      return result;
    });
  }
}
