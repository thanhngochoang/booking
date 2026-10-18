/**
 * Firestore implementations of the safety ports (blocks and reports).
 */

import { FieldValue, Timestamp, type DocumentData, type Firestore } from 'firebase-admin/firestore';
import {
  blockDocId,
  EMPTY_BLOCK_INDEX,
  type BlockGate,
  type BlockIndex,
  type BlockRecord,
  type BlockStore,
  type BlockTx,
  type PublicProfiles,
  type Report,
  type ReportStatus,
  type ReportStore,
  type ReportTargetType,
  type ReportTargetView,
  type ReportTx,
} from '@photobooking/domain';
import { db } from './admin.js';

export const BLOCKS_COLLECTION = 'blocks';
export const REPORTS_COLLECTION = 'reports';

const str = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);

function toIsoString(v: unknown): string {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  if (typeof v === 'string') return v;
  if (v instanceof Date) return v.toISOString();
  return new Date().toISOString();
}

export function blockRecordToFirestore(b: BlockRecord): DocumentData {
  const at = b.createdAt ? new Date(b.createdAt) : new Date();
  return {
    blockerId: b.blockerId,
    blockedId: b.blockedId,
    blockedName: b.blockedName,
    blockedAvatarUrl: b.blockedAvatarUrl,
    source: b.source,
    createdAt: Timestamp.fromDate(Number.isNaN(at.getTime()) ? new Date() : at),
  };
}

export function blockRecordFromFirestore(d: DocumentData): BlockRecord {
  return {
    blockerId: String(d.blockerId ?? ''),
    blockedId: String(d.blockedId ?? ''),
    blockedName: String(d.blockedName ?? ''),
    blockedAvatarUrl: str(d.blockedAvatarUrl),
    source: d.source === 'report' ? 'report' : 'menu',
    createdAt: toIsoString(d.createdAt),
  };
}

export function blockIndexToFirestore(idx: BlockIndex, at: string): DocumentData {
  return {
    blockedIds: [...idx.blockedIds],
    blockedByIds: [...idx.blockedByIds],
    updatedAt: Timestamp.fromDate(new Date(at)),
  };
}

export function blockIndexFromFirestore(d: DocumentData): BlockIndex {
  return {
    blockedIds: Array.isArray(d.blockedIds) ? d.blockedIds.map(String) : [],
    blockedByIds: Array.isArray(d.blockedByIds) ? d.blockedByIds.map(String) : [],
  };
}

export function reportToFirestore(r: Report): DocumentData {
  return {
    id: r.id,
    reporterId: r.reporterId,
    targetType: r.targetType,
    targetId: r.targetId,
    chatId: r.chatId,
    targetOwnerId: r.targetOwnerId,
    reason: r.reason,
    text: r.text,
    blocked: r.blocked,
    snapshot: {
      name: r.snapshot.name,
      excerpt: r.snapshot.excerpt,
      imageUrl: r.snapshot.imageUrl,
    },
    status: r.status,
    staffNote: r.staffNote,
    decidedBy: r.decidedBy,
    decidedAt: r.decidedAt ? Timestamp.fromDate(new Date(r.decidedAt)) : null,
    createdAt: Timestamp.fromDate(new Date(r.createdAt)),
  };
}

export function reportFromFirestore(d: DocumentData): Report {
  const snap = d.snapshot as Record<string, unknown> | undefined;
  return {
    id: String(d.id ?? ''),
    reporterId: String(d.reporterId ?? ''),
    targetType: (d.targetType as ReportTargetType) || 'user',
    targetId: String(d.targetId ?? ''),
    chatId: str(d.chatId),
    targetOwnerId: str(d.targetOwnerId),
    reason: (d.reason as Report['reason']) || 'other',
    text: str(d.text),
    blocked: Boolean(d.blocked),
    snapshot: {
      name: str(snap?.name),
      excerpt: str(snap?.excerpt),
      imageUrl: str(snap?.imageUrl),
    },
    status: (d.status as ReportStatus) || 'open',
    staffNote: str(d.staffNote),
    decidedBy: str(d.decidedBy),
    decidedAt: d.decidedAt ? toIsoString(d.decidedAt) : null,
    createdAt: toIsoString(d.createdAt),
  };
}

/**
 * True when either direction's block document exists. One `getAll` of both paths and no cache:
 * a block has to apply to the very next order.
 */
export class FirestoreBlockGate implements BlockGate {
  constructor(private readonly firestore: Firestore = db()) {}

  async isBlockedEitherWay(a: string, b: string): Promise<boolean> {
    const snaps = await this.firestore.getAll(
      this.firestore.doc(`blocks/${blockDocId(a, b)}`),
      this.firestore.doc(`blocks/${blockDocId(b, a)}`),
    );
    return snaps.some((s) => s.exists);
  }
}

export class FirestorePublicProfiles implements PublicProfiles {
  constructor(private readonly firestore: Firestore = db()) {}

  async get(uid: string): Promise<{ name: string; avatarUrl: string | null } | null> {
    const snap = await this.firestore.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    const data = snap.data();
    return {
      name: str(data?.displayName) ?? 'Người dùng',
      avatarUrl: str(data?.avatarUrl),
    };
  }
}

export class FirestoreBlockStore implements BlockStore {
  constructor(private readonly firestore: Firestore = db()) {}

  async runTransaction<T>(fn: (tx: BlockTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx) => {
      const tx: BlockTx = {
        getBlock: async (blockerId: string, blockedId: string): Promise<BlockRecord | null> => {
          const ref = this.firestore.collection(BLOCKS_COLLECTION).doc(blockDocId(blockerId, blockedId));
          const snap = await fTx.get(ref);
          const data = snap.data();
          if (!snap.exists || !data) return null;
          return blockRecordFromFirestore(data);
        },
        getIndex: async (uid: string): Promise<BlockIndex> => {
          const ref = this.firestore.doc(`users/${uid}/private/blocks`);
          const snap = await fTx.get(ref);
          const data = snap.data();
          if (!snap.exists || !data) return EMPTY_BLOCK_INDEX;
          return blockIndexFromFirestore(data);
        },
        chatExists: async (chatId: string): Promise<boolean> => {
          const ref = this.firestore.collection('chats').doc(chatId);
          const snap = await fTx.get(ref);
          return snap.exists;
        },
        putBlock: (b: BlockRecord): void => {
          const ref = this.firestore.collection(BLOCKS_COLLECTION).doc(blockDocId(b.blockerId, b.blockedId));
          fTx.set(ref, blockRecordToFirestore(b));
        },
        deleteBlock: (blockerId: string, blockedId: string): void => {
          const ref = this.firestore.collection(BLOCKS_COLLECTION).doc(blockDocId(blockerId, blockedId));
          fTx.delete(ref);
        },
        putIndex: (uid: string, index: BlockIndex, at: string): void => {
          const ref = this.firestore.doc(`users/${uid}/private/blocks`);
          fTx.set(ref, blockIndexToFirestore(index, at));
        },
        setChatBlockedAt: (chatId: string, at: string | null): void => {
          const ref = this.firestore.collection('chats').doc(chatId);
          fTx.update(ref, {
            blockedAt: at ? Timestamp.fromDate(new Date(at)) : null,
            updatedAt: FieldValue.serverTimestamp(),
          });
        },
        deleteFollowMarkers: (a: string, b: string): void => {
          fTx.delete(this.firestore.doc(`follows/${a}_${b}`));
          fTx.delete(this.firestore.doc(`follows/${b}_${a}`));
          fTx.delete(this.firestore.doc(`savedPhotographers/${a}_${b}`));
          fTx.delete(this.firestore.doc(`savedPhotographers/${b}_${a}`));
        },
      };

      return fn(tx);
    });
  }
}

export class FirestoreReportStore implements ReportStore {
  constructor(private readonly firestore: Firestore = db()) {}

  async runTransaction<T>(fn: (tx: ReportTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx) => {
      const tx: ReportTx = {
        getReport: async (id: string): Promise<Report | null> => {
          const ref = this.firestore.collection(REPORTS_COLLECTION).doc(id);
          const snap = await fTx.get(ref);
          const data = snap.data();
          if (!snap.exists || !data) return null;
          return reportFromFirestore(data);
        },
        getTarget: async (type: ReportTargetType, id: string, chatId: string | null): Promise<ReportTargetView | null> => {
          if (type === 'user') {
            const snap = await fTx.get(this.firestore.collection('users').doc(id));
            if (!snap.exists) return null;
            const data = snap.data();
            return {
              type: 'user',
              id,
              chatId: null,
              ownerId: id,
              snapshot: {
                name: str(data?.displayName) ?? 'Người dùng',
                excerpt: null,
                imageUrl: str(data?.avatarUrl),
              },
            };
          }
          if (type === 'post') {
            const snap = await fTx.get(this.firestore.collection('posts').doc(id));
            const data = snap.data();
            if (!snap.exists || !data) return null;
            const images = Array.isArray(data.images) ? data.images : [];
            const firstImg = images[0] ? (typeof images[0] === 'string' ? images[0] : images[0].url) : null;
            const caption = str(data.caption) ?? '';
            const segments = [...new Intl.Segmenter().segment(caption)].map((s) => s.segment);
            const excerpt = segments.slice(0, 300).join('');
            return {
              type: 'post',
              id,
              chatId: null,
              ownerId: str(data.authorId),
              snapshot: {
                name: null,
                excerpt: excerpt.length > 0 ? excerpt : null,
                imageUrl: str(firstImg),
              },
            };
          }
          if (type === 'message') {
            if (!chatId) return null;
            const msgRef = this.firestore.doc(`chats/${chatId}/messages/${id}`);
            const snap = await fTx.get(msgRef);
            const data = snap.data();
            if (!snap.exists || !data) return null;
            const senderId = str(data.senderId);
            if (senderId === null || data.type === 'system') {
              return null;
            }
            const body = str(data.body) ?? '';
            const segments = [...new Intl.Segmenter().segment(body)].map((s) => s.segment);
            const excerpt = segments.slice(0, 300).join('');
            return {
              type: 'message',
              id,
              chatId,
              ownerId: senderId,
              snapshot: {
                name: null,
                excerpt: excerpt.length > 0 ? excerpt : null,
                imageUrl: str(data.imageUrl),
              },
            };
          }
          if (type === 'event') {
            const snap = await fTx.get(this.firestore.collection('events').doc(id));
            const data = snap.data();
            if (!snap.exists || !data) return null;
            if (data.status === 'draft') return null;
            const host = data.host as Record<string, unknown> | undefined;
            const hostType = host?.type ?? 'photographer';
            const ownerId = hostType === 'platform' ? null : str(host?.id ?? data.hostId);
            return {
              type: 'event',
              id,
              chatId: null,
              ownerId,
              snapshot: {
                name: str(data.title) ?? 'Sự kiện',
                excerpt: null,
                imageUrl: str(data.coverUrl),
              },
            };
          }
          return null;
        },
        isChatMember: async (chatId: string, uid: string): Promise<boolean> => {
          const snap = await fTx.get(this.firestore.collection('chats').doc(chatId));
          if (!snap.exists) return false;
          const data = snap.data();
          const members = Array.isArray(data?.members) ? data.members : [];
          return members.includes(uid);
        },
        getQuota: async (uid: string): Promise<{ day: string; count: number } | null> => {
          const snap = await fTx.get(this.firestore.doc(`users/${uid}/private/report_quota`));
          const data = snap.data();
          if (!snap.exists || !data) return null;
          return {
            day: String(data.day ?? ''),
            count: Number(data.count ?? 0),
          };
        },
        putReport: (r: Report): void => {
          const ref = this.firestore.collection(REPORTS_COLLECTION).doc(r.id);
          fTx.set(ref, reportToFirestore(r));
        },
        putQuota: (uid: string, q: { day: string; count: number }): void => {
          const ref = this.firestore.doc(`users/${uid}/private/report_quota`);
          fTx.set(ref, q);
        },
      };

      return fn(tx);
    });
  }

  async list(status: ReportStatus, limit: number): Promise<readonly Report[]> {
    const snap = await this.firestore
      .collection(REPORTS_COLLECTION)
      .where('status', '==', status)
      .orderBy('createdAt', 'asc')
      .limit(limit)
      .get();
    return snap.docs.map((doc) => reportFromFirestore(doc.data()));
  }

  async get(id: string): Promise<Report | null> {
    const snap = await this.firestore.collection(REPORTS_COLLECTION).doc(id).get();
    const data = snap.data();
    if (!snap.exists || !data) return null;
    return reportFromFirestore(data);
  }

  async decide(
    id: string,
    patch: Pick<Report, 'status' | 'staffNote' | 'decidedBy' | 'decidedAt'>,
  ): Promise<void> {
    const ref = this.firestore.collection(REPORTS_COLLECTION).doc(id);
    await ref.update({
      status: patch.status,
      staffNote: patch.staffNote,
      decidedBy: patch.decidedBy,
      decidedAt: patch.decidedAt ? Timestamp.fromDate(new Date(patch.decidedAt)) : null,
    });
  }
}
