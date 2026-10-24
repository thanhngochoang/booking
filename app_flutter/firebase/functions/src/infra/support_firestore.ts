import {
  Timestamp,
  type DocumentData,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import type {
  DisplayNames,
  Dispute,
  SupportMessage,
  SupportSenderRole,
  SupportStore,
  SupportThread,
  SupportThreadKind,
  SupportTx,
} from '@photobooking/domain';
import { DISPUTES_COLLECTION, disputeFromFirestore } from './dispute_mapping.js';

export const SUPPORT_THREADS_COLLECTION = 'support_threads';
export const MESSAGES_SUBCOLLECTION = 'messages';

function toIsoString(v: unknown): string | null {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  if (typeof v === 'string') return v;
  return null;
}

function toTimestamp(iso: string | null | undefined): Timestamp | null {
  if (!iso) return null;
  return Timestamp.fromDate(new Date(iso));
}

export function supportThreadToFirestore(t: SupportThread): DocumentData {
  const rateData: Record<string, { windowStart: Timestamp | null; count: number }> = {};
  for (const [uid, r] of Object.entries(t.rate)) {
    rateData[uid] = {
      windowStart: toTimestamp(r.windowStart),
      count: r.count,
    };
  }

  return {
    id: t.id,
    kind: t.kind,
    ownerId: t.ownerId ?? null,
    disputeId: t.disputeId ?? null,
    participants: [...t.participants],
    status: t.status,
    awaitingStaff: t.awaitingStaff,
    lastMessageAt: toTimestamp(t.lastMessageAt),
    lastMessagePreview: t.lastMessagePreview ?? null,
    lastSenderRole: t.lastSenderRole ?? null,
    rate: rateData,
    createdAt: toTimestamp(t.createdAt),
    updatedAt: toTimestamp(t.updatedAt),
  };
}

export function supportThreadFromFirestore(d: DocumentData | null | undefined): SupportThread | null {
  if (!d) return null;

  const rate: Record<string, { windowStart: string; count: number }> = {};
  const rawRate = d.rate ?? {};
  for (const [uid, r] of Object.entries(rawRate as Record<string, { windowStart?: unknown; count?: unknown }>)) {
    rate[uid] = {
      windowStart: toIsoString(r.windowStart) ?? '',
      count: Number(r.count ?? 0),
    };
  }

  return {
    id: String(d.id),
    kind: d.kind as SupportThreadKind,
    ownerId: d.ownerId ?? null,
    disputeId: d.disputeId ?? null,
    participants: Array.isArray(d.participants) ? d.participants.map(String) : [],
    status: (d.status as 'open' | 'closed') ?? 'open',
    awaitingStaff: Boolean(d.awaitingStaff),
    lastMessageAt: toIsoString(d.lastMessageAt),
    lastMessagePreview: d.lastMessagePreview ?? null,
    lastSenderRole: (d.lastSenderRole as SupportSenderRole) ?? null,
    rate,
    createdAt: toIsoString(d.createdAt) ?? '',
    updatedAt: toIsoString(d.updatedAt) ?? '',
  };
}

export function supportMessageToFirestore(m: SupportMessage): DocumentData {
  return {
    id: m.id,
    threadId: m.threadId,
    senderId: m.senderId ?? null,
    senderRole: m.senderRole,
    senderName: m.senderName,
    body: m.body,
    createdAt: toTimestamp(m.createdAt),
  };
}

export function supportMessageFromFirestore(d: DocumentData | null | undefined): SupportMessage | null {
  if (!d) return null;
  return {
    id: String(d.id),
    threadId: String(d.threadId),
    senderId: d.senderId ?? null,
    senderRole: d.senderRole as SupportSenderRole,
    senderName: String(d.senderName ?? ''),
    body: String(d.body ?? ''),
    createdAt: toIsoString(d.createdAt) ?? '',
  };
}

export class FirestoreSupportTx implements SupportTx {
  constructor(
    protected readonly firestore: Firestore,
    protected readonly tx: Transaction,
  ) {}

  async getThread(id: string): Promise<SupportThread | null> {
    const ref = this.firestore.collection(SUPPORT_THREADS_COLLECTION).doc(id);
    const snap = await this.tx.get(ref);
    if (!snap.exists) return null;
    return supportThreadFromFirestore(snap.data());
  }

  async getMessage(threadId: string, id: string): Promise<SupportMessage | null> {
    const ref = this.firestore
      .collection(SUPPORT_THREADS_COLLECTION)
      .doc(threadId)
      .collection(MESSAGES_SUBCOLLECTION)
      .doc(id);
    const snap = await this.tx.get(ref);
    if (!snap.exists) return null;
    return supportMessageFromFirestore(snap.data());
  }

  /** `disputes/{id}` (#142): a dispute thread's party check and its open/resolved state. */
  async getDispute(id: string): Promise<Dispute | null> {
    const snap = await this.tx.get(this.firestore.collection(DISPUTES_COLLECTION).doc(id));
    return snap.exists ? disputeFromFirestore(snap.data()) : null;
  }

  putThread(t: SupportThread): void {
    const ref = this.firestore.collection(SUPPORT_THREADS_COLLECTION).doc(t.id);
    this.tx.set(ref, supportThreadToFirestore(t), { merge: true });
  }

  addMessage(m: SupportMessage): void {
    const ref = this.firestore
      .collection(SUPPORT_THREADS_COLLECTION)
      .doc(m.threadId)
      .collection(MESSAGES_SUBCOLLECTION)
      .doc(m.id);
    this.tx.set(ref, supportMessageToFirestore(m));
  }
}

export class FirestoreSupportStore implements SupportStore {
  constructor(protected readonly firestore: Firestore) {}

  async runTransaction<T>(fn: (tx: SupportTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx) => {
      const tx = new FirestoreSupportTx(this.firestore, fTx);
      return fn(tx);
    });
  }

  async listAwaitingStaff(limit: number): Promise<readonly SupportThread[]> {
    const snap = await this.firestore
      .collection(SUPPORT_THREADS_COLLECTION)
      .where('awaitingStaff', '==', true)
      .orderBy('lastMessageAt', 'asc')
      .limit(limit)
      .get();

    return snap.docs
      .map((d) => supportThreadFromFirestore(d.data()))
      .filter((t): t is SupportThread => t !== null);
  }

  async listMessages(threadId: string, limit: number): Promise<readonly SupportMessage[]> {
    const snap = await this.firestore
      .collection(SUPPORT_THREADS_COLLECTION)
      .doc(threadId)
      .collection(MESSAGES_SUBCOLLECTION)
      .orderBy('createdAt', 'desc')
      .limit(limit)
      .get();

    return snap.docs
      .map((d) => supportMessageFromFirestore(d.data()))
      .filter((m): m is SupportMessage => m !== null);
  }
}

export class FirestoreDisplayNames implements DisplayNames {
  constructor(private readonly firestore: Firestore) {}

  async displayName(uid: string): Promise<string> {
    const snap = await this.firestore.collection('users').doc(uid).get();
    if (!snap.exists) return '';
    return (snap.data()?.displayName as string) ?? '';
  }
}
