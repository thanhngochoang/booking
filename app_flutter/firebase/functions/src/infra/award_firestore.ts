import {
  FieldValue,
  Timestamp,
  type DocumentData,
  type DocumentReference,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import {
  AWARDS_PER_PHOTOGRAPHER,
  AWARD_RESULTS,
  AWARD_STATUSES,
  providerTypeOf,
  type Award,
  type AwardProof,
  type AwardResult,
  type AwardStatus,
  type AwardStore,
  type AwardTx,
  type TierStore,
  type TierTx,
} from '@photobooking/domain';
import { PHOTOGRAPHERS_COLLECTION } from './review_firestore.js';

export const AWARDS_COLLECTION = 'awards';
export const AWARD_PROOFS_COLLECTION = 'awardProofs';
export const AWARD_AUDIT_COLLECTION = 'awardAudit';
const POSTS = 'posts';

function toDate(v: unknown): Date | null {
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  return null;
}

const strOrNull = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);

export function awardFromDoc(id: string, d: DocumentData): Award {
  return {
    id,
    photographerId: String(d.photographerId ?? ''),
    competition: String(d.competition ?? ''),
    year: typeof d.year === 'number' ? d.year : 0,
    category: strOrNull(d.category),
    result: (AWARD_RESULTS as readonly unknown[]).includes(d.result) ? (d.result as AwardResult) : 'finalist',
    workPostId: strOrNull(d.workPostId),
    status: (AWARD_STATUSES as readonly unknown[]).includes(d.status) ? (d.status as AwardStatus) : 'pending',
    reviewNote: strOrNull(d.reviewNote),
    reviewedBy: strOrNull(d.reviewedBy),
    reviewedAt: toDate(d.reviewedAt),
    createdAt: toDate(d.createdAt) ?? new Date(0),
    updatedAt: toDate(d.updatedAt) ?? new Date(0),
  };
}

export function proofFromDoc(awardId: string, d: DocumentData): AwardProof {
  const files: string[] = [];
  if (Array.isArray(d.files)) {
    for (const f of d.files as unknown[]) {
      const p = (f as { storagePath?: unknown } | null)?.storagePath;
      if (typeof p === 'string') files.push(p);
    }
  }
  return {
    awardId,
    photographerId: String(d.photographerId ?? ''),
    files,
    links: Array.isArray(d.links) ? (d.links as unknown[]).filter((l): l is string => typeof l === 'string') : [],
    purgeAfter: toDate(d.purgeAfter),
  };
}

/**
 * Awards, their proofs and the audit log in Firestore. Writes are buffered until the callback has
 * finished all its reads (Firestore requires reads before writes), then applied together.
 */
export class FirestoreAwardStore implements AwardStore {
  constructor(private readonly firestore: Firestore) {}

  async runTransaction<T>(fn: (tx: AwardTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx: Transaction) => {
      const awardRef = (id: string): DocumentReference => this.firestore.collection(AWARDS_COLLECTION).doc(id);
      const proofRef = (id: string): DocumentReference => this.firestore.collection(AWARD_PROOFS_COLLECTION).doc(id);
      const writes: Array<() => void> = [];

      const tx: AwardTx = {
        getAward: async (id) => {
          const s = await fTx.get(awardRef(id));
          const d = s.data();
          return s.exists && d ? awardFromDoc(id, d) : null;
        },
        getProof: async (awardId) => {
          const s = await fTx.get(proofRef(awardId));
          const d = s.data();
          return s.exists && d ? proofFromDoc(awardId, d) : null;
        },
        countAwards: async (photographerId) => {
          const snap = await fTx.get(
            this.firestore
              .collection(AWARDS_COLLECTION)
              .where('photographerId', '==', photographerId)
              .select()
              .limit(AWARDS_PER_PHOTOGRAPHER),
          );
          return snap.size;
        },
        isOwnWorkPost: async (postId, photographerId) => {
          const s = await fTx.get(this.firestore.collection(POSTS).doc(postId));
          const d = s.data();
          return s.exists && d !== undefined && d.kind === 'work' && d.authorId === photographerId;
        },
        putAward: (a) => {
          writes.push(() => {
            fTx.set(awardRef(a.id), {
              photographerId: a.photographerId,
              competition: a.competition,
              year: a.year,
              ...(a.category !== null ? { category: a.category } : {}),
              result: a.result,
              ...(a.workPostId !== null ? { workPostId: a.workPostId } : {}),
              status: a.status,
              ...(a.reviewNote !== null ? { reviewNote: a.reviewNote } : {}),
              ...(a.reviewedBy !== null ? { reviewedBy: a.reviewedBy } : {}),
              ...(a.reviewedAt !== null ? { reviewedAt: Timestamp.fromDate(a.reviewedAt) } : {}),
              createdAt: Timestamp.fromDate(a.createdAt),
              updatedAt: Timestamp.fromDate(a.updatedAt),
            });
          });
        },
        putProof: (p) => {
          writes.push(() => {
            fTx.set(proofRef(p.awardId), {
              photographerId: p.photographerId,
              files: p.files.map((storagePath) => ({ storagePath })),
              links: [...p.links],
              ...(p.purgeAfter !== null ? { purgeAfter: Timestamp.fromDate(p.purgeAfter) } : {}),
            });
          });
        },
        deleteAward: (id) => {
          writes.push(() => void fTx.delete(awardRef(id)));
        },
        deleteProof: (awardId) => {
          writes.push(() => void fTx.delete(proofRef(awardId)));
        },
        addAudit: (row) => {
          writes.push(() => {
            fTx.create(this.firestore.collection(AWARD_AUDIT_COLLECTION).doc(), {
              awardId: row.awardId,
              actorId: row.actorId,
              action: row.action,
              note: row.note ?? '',
              at: Timestamp.fromDate(row.at),
            });
          });
        },
      };

      const result = await fn(tx);
      for (const w of writes) w();
      return result;
    });
  }

  /** Proof docs whose `purgeAfter` has passed (the purge job). */
  async proofsDue(now: Date): Promise<AwardProof[]> {
    const snap = await this.firestore
      .collection(AWARD_PROOFS_COLLECTION)
      .where('purgeAfter', '<=', Timestamp.fromDate(now))
      .limit(500)
      .get();
    return snap.docs.map((s) => proofFromDoc(s.id, s.data()));
  }
}

/** `photographers/{uid}` tier fields; never writes when the profile is missing. */
export class FirestoreTierStore implements TierStore {
  constructor(private readonly firestore: Firestore) {}

  async runTransaction<T>(fn: (tx: TierTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx: Transaction) => {
      const photographer = (uid: string): DocumentReference =>
        this.firestore.collection(PHOTOGRAPHERS_COLLECTION).doc(uid);
      const writes: Array<() => void> = [];
      const tx: TierTx = {
        getTierState: async (uid) => {
          const s = await fTx.get(photographer(uid));
          const d = s.data();
          if (!s.exists || d === undefined) return null;
          return {
            providerType: providerTypeOf(d.providerType),
            artistSince: toDate(d.artistSince),
            approvedAwardCount: typeof d.approvedAwardCount === 'number' ? d.approvedAwardCount : 0,
          };
        },
        countApproved: async (uid) => {
          const snap = await fTx.get(
            this.firestore
              .collection(AWARDS_COLLECTION)
              .where('photographerId', '==', uid)
              .where('status', '==', 'approved')
              .select(),
          );
          return snap.size;
        },
        setTierState: (uid, s) => {
          writes.push(() => {
            fTx.set(
              photographer(uid),
              {
                providerType: s.providerType,
                approvedAwardCount: s.approvedAwardCount,
                artistSince: s.artistSince === null ? FieldValue.delete() : Timestamp.fromDate(s.artistSince),
                updatedAt: Timestamp.now(),
              },
              { merge: true },
            );
          });
        },
      };
      const result = await fn(tx);
      for (const w of writes) w();
      return result;
    });
  }
}
