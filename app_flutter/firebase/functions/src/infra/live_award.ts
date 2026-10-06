import { getStorage } from 'firebase-admin/storage';
import { formatVnDate, notify } from '@photobooking/domain';
import type { AwardCallableDeps } from '../callables/award.js';
import { db as adminDb } from './admin.js';
import { FirestoreAwardStore, FirestoreTierStore } from './award_firestore.js';
import { liveNotifyDeps } from './live_notification.js';

/** Deletes proof files through the Admin SDK (storage rules close them to staff and clients alike). */
export async function deleteStorageFiles(paths: readonly string[]): Promise<void> {
  adminDb(); // makes sure the default app exists
  const bucket = getStorage().bucket();
  await Promise.all(paths.map((p) => bucket.file(p).delete({ ignoreNotFound: true })));
}

export function liveAwardDeps(): AwardCallableDeps {
  const db = adminDb();
  return {
    userRole: async (uid) => {
      const role: unknown = (await db.collection('users').doc(uid).get()).data()?.role;
      return typeof role === 'string' ? role : null;
    },
    awards: new FirestoreAwardStore(db),
    tiers: new FirestoreTierStore(db),
    files: { delete: deleteStorageFiles },
    notify: {
      tierChanged: async (uid, to) => {
        await notify(liveNotifyDeps(), {
          userId: uid,
          content: { type: to === 'artist' ? 'artist_granted' : 'artist_revoked' },
          target: '/me/awards',
          dedupeKey: `artist_${to}_${formatVnDate(new Date()).replace(/-/g, '')}`,
        });
      },
      awardReviewed: async (uid, awardId, status) => {
        if (status === 'pending') return;
        await notify(liveNotifyDeps(), {
          userId: uid,
          content: { type: 'award_reviewed', status },
          target: '/me/awards',
          dedupeKey: `award_reviewed_${awardId}_${status}`,
        });
      },
    },
    clock: { now: () => new Date() },
  };
}

export function liveAwardStore(): FirestoreAwardStore {
  return new FirestoreAwardStore(adminDb());
}
