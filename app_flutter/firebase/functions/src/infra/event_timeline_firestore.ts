import {
  Timestamp,
  type DocumentData,
  type DocumentReference,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import type {
  EventRecord,
  SharedPost,
  TimelinePeople,
  TimelinePost,
  TimelineRow,
  TimelineStore,
  TimelineTx,
} from '@photobooking/domain';
import { EVENT_HASHTAGS, EVENTS_COLLECTION, eventFromFirestore } from './event_firestore.js';

export const TIMELINE = 'timeline';
const POSTS = 'posts';

const str = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);
const dim = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) ? v : null);

function toDate(v: unknown): Date {
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  return new Date(0);
}

/** `events/{id}/timeline/{postId}`. */
export function timelineRowToFirestore(r: TimelineRow): DocumentData {
  return {
    postId: r.postId,
    source: r.source,
    status: r.status,
    authorId: r.authorId,
    authorName: r.authorName,
    isHost: r.isHost,
    imageUrl: r.imageUrl,
    imageW: r.imageW,
    imageH: r.imageH,
    imageCount: r.imageCount,
    addedAt: Timestamp.fromDate(r.addedAt),
    moderatedBy: r.moderatedBy,
  };
}

export function timelineRowFromFirestore(id: string, d: DocumentData): TimelineRow {
  return {
    postId: id,
    source: d.source === 'explicit' ? 'explicit' : 'hashtag',
    status: d.status === 'visible' || d.status === 'hidden' ? d.status : 'pending',
    authorId: String(d.authorId ?? ''),
    authorName: String(d.authorName ?? ''),
    isHost: d.isHost === true,
    imageUrl: String(d.imageUrl ?? ''),
    imageW: dim(d.imageW),
    imageH: dim(d.imageH),
    imageCount: typeof d.imageCount === 'number' ? d.imageCount : 1,
    addedAt: toDate(d.addedAt),
    moderatedBy: str(d.moderatedBy),
  };
}

/** The slice of `posts/{id}` the timeline reads; a soft-deleted post is null. */
export function timelinePostFromFirestore(id: string, d: DocumentData | undefined): TimelinePost | null {
  if (d === undefined || d.deletedAt != null) return null;
  const urls: string[] = Array.isArray(d.imageUrls) ? d.imageUrls.filter((u: unknown): u is string => typeof u === 'string') : [];
  const meta: unknown = Array.isArray(d.imageMeta) ? d.imageMeta[0] : null;
  const m = typeof meta === 'object' && meta !== null ? (meta as Record<string, unknown>) : {};
  return {
    id,
    authorId: str(d.authorId) ?? str(d.photographerId) ?? '',
    kind: String(d.kind ?? ''),
    hashtags: Array.isArray(d.hashtags) ? d.hashtags.filter((t: unknown): t is string => typeof t === 'string') : [],
    eventId: str(d.eventId),
    imageUrls: urls,
    imageW: dim(m.w),
    imageH: dim(m.h),
  };
}

/** An `event_share` post: no service, the host as `photographerId`, counters at 0 (Decision 17). */
export function sharedPostToFirestore(p: SharedPost): DocumentData {
  return {
    kind: 'event_share',
    authorId: p.authorId,
    photographerId: p.photographerId,
    serviceId: '',
    eventId: p.eventId,
    imageUrls: [...p.imageUrls],
    imageMeta: p.imageMeta.map((m) => ({ blurHash: m.blurHash, w: m.w, h: m.h })),
    caption: p.caption,
    hashtags: [...p.hashtags],
    inPortfolio: false,
    likeCount: 0,
    saveCount: 0,
    createdAt: Timestamp.fromDate(p.createdAt),
  };
}

/**
 * Timeline rows in Firestore. Reads go straight to the transaction; every write is buffered until
 * the callback has finished all its reads, then applied together.
 */
export class FirestoreEventTimelineStore implements TimelineStore {
  constructor(private readonly firestore: Firestore) {}

  async getPost(postId: string): Promise<TimelinePost | null> {
    const s = await this.firestore.collection(POSTS).doc(postId).get();
    return s.exists ? timelinePostFromFirestore(postId, s.data()) : null;
  }

  runTransaction<T>(fn: (tx: TimelineTx) => Promise<T>): Promise<T> {
    const fs = this.firestore;
    return fs.runTransaction(async (fTx: Transaction) => {
      const eventRef = (id: string): DocumentReference => fs.collection(EVENTS_COLLECTION).doc(id);
      const rowRef = (eventId: string, postId: string): DocumentReference =>
        eventRef(eventId).collection(TIMELINE).doc(postId);
      const writes: Array<() => void> = [];

      const tx: TimelineTx = {
        getEvent: async (id): Promise<EventRecord | null> => {
          const s = await fTx.get(eventRef(id));
          const d = s.data();
          return s.exists && d ? eventFromFirestore(id, d) : null;
        },
        hashtagOwner: async (key) => {
          const s = await fTx.get(fs.collection(EVENT_HASHTAGS).doc(key));
          return s.exists ? str(s.data()?.eventId) : null;
        },
        getRow: async (eventId, postId) => {
          const s = await fTx.get(rowRef(eventId, postId));
          const d = s.data();
          return s.exists && d ? timelineRowFromFirestore(postId, d) : null;
        },
        hasPaidTicket: async (eventId, uid) => {
          const q = eventRef(eventId).collection('registrations')
            .where('userId', '==', uid).where('status', '==', 'paid').limit(1);
          return !(await fTx.get(q)).empty;
        },
        getPost: async (postId) => {
          const s = await fTx.get(fs.collection(POSTS).doc(postId));
          return s.exists ? timelinePostFromFirestore(postId, s.data()) : null;
        },
        putRow: (eventId, row) => {
          writes.push(() => fTx.set(rowRef(eventId, row.postId), timelineRowToFirestore(row)));
        },
        setPostCount: (eventId, count) => {
          writes.push(() => fTx.update(eventRef(eventId), { postCount: count, updatedAt: Timestamp.now() }));
        },
        createPost: (post) => {
          writes.push(() => fTx.create(fs.collection(POSTS).doc(post.id), sharedPostToFirestore(post)));
        },
      };

      const result = await fn(tx);
      for (const w of writes) w();
      return result;
    });
  }
}

/** Display name and whether the author is a photographer; read from `users/{uid}` (never from the client). */
export function firestoreTimelinePeople(firestore: Firestore): TimelinePeople {
  return {
    async author(uid) {
      const s = await firestore.collection('users').doc(uid).get();
      const d = s.data();
      if (!s.exists || d === undefined) return null;
      return { name: str(d.displayName) ?? 'Người dùng', isPhotographer: d.role === 'photographer' };
    },
  };
}

/**
 * A post image is the caller's own upload: `path` is `posts/{uid}/{postId}/{file}` and `url` is a
 * download URL of exactly that object in this project's bucket.
 */
export function ownPostImage(prefixes: readonly string[]) {
  return (url: string, path: string, uid: string, postId: string): boolean => {
    if (!/^posts\/[A-Za-z0-9_-]+\/[A-Za-z0-9_-]+\/[^/]+$/.test(path)) return false;
    if (!path.startsWith(`posts/${uid}/${postId}/`)) return false;
    const prefix = prefixes.find((p) => url.startsWith(p));
    if (prefix === undefined) return false;
    const object = url.slice(prefix.length).split('?')[0] ?? '';
    try {
      return decodeURIComponent(object) === path;
    } catch {
      return false;
    }
  };
}
