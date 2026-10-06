import { Timestamp, type DocumentData, type Firestore, type Transaction } from 'firebase-admin/firestore';
import type {
  NotificationActor,
  NotificationCategory,
  NotificationRow,
  NotificationStore,
  NotificationTab,
  NotificationTx,
  NotificationType,
} from '@photobooking/domain';

/** `users/{uid}/notifications/{id}`; `userId` comes from the path, not the document. */
export function notificationRowToFirestore(r: NotificationRow): DocumentData {
  return {
    type: r.type,
    tab: r.tab,
    category: r.category,
    title: r.title,
    body: r.body,
    target: r.target,
    groupKey: r.groupKey,
    actors: r.actors.map((a) => ({ id: a.id, name: a.name, avatarUrl: a.avatarUrl })),
    count: r.count,
    thumbUrl: r.thumbUrl,
    lastEventId: r.lastEventId,
    createdAt: Timestamp.fromDate(r.createdAt),
    readAt: r.readAt === null ? null : Timestamp.fromDate(r.readAt),
  };
}

const asDate = (v: unknown): Date | null => (v instanceof Timestamp ? v.toDate() : v instanceof Date ? v : null);
const asString = (v: unknown, fallback = ''): string => (typeof v === 'string' ? v : fallback);

export function notificationRowFromFirestore(uid: string, id: string, d: DocumentData | undefined): NotificationRow | null {
  if (!d) return null;
  const createdAt = asDate(d.createdAt);
  if (createdAt === null) return null;
  const actors: NotificationActor[] = Array.isArray(d.actors)
    ? d.actors
        .filter((a): a is Record<string, unknown> => typeof a === 'object' && a !== null)
        .map((a) => ({ id: asString(a.id), name: asString(a.name), avatarUrl: typeof a.avatarUrl === 'string' ? a.avatarUrl : null }))
    : [];
  return {
    id,
    userId: uid,
    type: asString(d.type) as NotificationType,
    tab: asString(d.tab) as NotificationTab,
    category: asString(d.category) as NotificationCategory,
    title: asString(d.title),
    body: asString(d.body),
    target: asString(d.target),
    groupKey: typeof d.groupKey === 'string' ? d.groupKey : null,
    actors,
    count: typeof d.count === 'number' ? d.count : 1,
    thumbUrl: typeof d.thumbUrl === 'string' ? d.thumbUrl : null,
    lastEventId: typeof d.lastEventId === 'string' ? d.lastEventId : null,
    createdAt,
    readAt: asDate(d.readAt),
  };
}

const rowRef = (db: Firestore, uid: string, id: string) =>
  db.collection('users').doc(uid).collection('notifications').doc(id);

/** The private doc that holds the unread count (ruling R1: never the public user doc). */
const inboxRef = (db: Firestore, uid: string) => db.collection('users').doc(uid).collection('private').doc('inbox');

export class FirestoreNotificationStore implements NotificationStore {
  constructor(private readonly db: Firestore) {}

  async runTransaction<T>(fn: (tx: NotificationTx) => Promise<T>): Promise<T> {
    return this.db.runTransaction(async (fTx: Transaction) => {
      const tx: NotificationTx = {
        getRow: async (uid, id) => {
          const snap = await fTx.get(rowRef(this.db, uid, id));
          return notificationRowFromFirestore(uid, id, snap.data());
        },
        putRow: (r) => {
          fTx.set(rowRef(this.db, r.userId, r.id), notificationRowToFirestore(r));
        },
      };
      return fn(tx);
    });
  }

  async getPrefs(uid: string): Promise<unknown> {
    const snap = await this.db.collection('users').doc(uid).collection('private').doc('notification_prefs').get();
    return snap.exists ? snap.data() : null;
  }

  async listUnreadIds(uid: string, limit: number): Promise<string[]> {
    const snap = await this.db
      .collection('users').doc(uid).collection('notifications')
      .where('readAt', '==', null)
      .limit(limit)
      .get();
    return snap.docs.map((d) => d.id);
  }

  async markRead(uid: string, ids: readonly string[], at: Date): Promise<void> {
    if (ids.length === 0) return;
    const batch = this.db.batch();
    for (const id of ids) batch.update(rowRef(this.db, uid, id), { readAt: Timestamp.fromDate(at) });
    await batch.commit();
  }

  async countUnread(uid: string): Promise<number> {
    const snap = await this.db
      .collection('users').doc(uid).collection('notifications')
      .where('readAt', '==', null)
      .count()
      .get();
    return snap.data().count;
  }

  /** Compare-and-write in one transaction; only a strictly older `at` is refused. */
  async setUnreadCount(uid: string, count: number, at: Date): Promise<boolean> {
    const ref = inboxRef(this.db, uid);
    return this.db.runTransaction(async (fTx) => {
      const stored = asDate((await fTx.get(ref)).data()?.unreadCountAt);
      if (stored !== null && stored.getTime() > at.getTime()) return false;
      fTx.set(ref, { unreadCount: count, unreadCountAt: Timestamp.fromDate(at) }, { merge: true });
      return true;
    });
  }

  /**
   * Read rows whose `readAt` is before the cutoff (a row is read after it is created, so its
   * `createdAt` is older still). The range query on `readAt` matches only timestamps, so unread
   * rows (`null`) are never returned. Needs the collection-group index on `notifications.readAt`.
   */
  async deleteReadBefore(cutoff: Date, limit: number): Promise<number> {
    const snap = await this.db
      .collectionGroup('notifications')
      .where('readAt', '<', Timestamp.fromDate(cutoff))
      .limit(limit)
      .get();
    const own = snap.docs.filter((d) => d.ref.parent.parent?.parent.id === 'users');
    if (own.length === 0) return 0;
    const batch = this.db.batch();
    for (const d of own) batch.delete(d.ref);
    await batch.commit();
    return own.length;
  }
}
