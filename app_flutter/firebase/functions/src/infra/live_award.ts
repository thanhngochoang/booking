import { getStorage } from 'firebase-admin/storage';
import * as logger from 'firebase-functions/logger';
import type { AwardCallableDeps } from '../callables/award.js';
import { db as adminDb } from './admin.js';
import { FirestoreAwardStore, FirestoreTierStore } from './award_firestore.js';

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
    // Push notifications arrive with plan S17; until then these are logged no-ops.
    notify: {
      tierChanged: async (uid, to) => {
        logger.info('notifyTierChange', { uid, to });
      },
      awardReviewed: async (uid, awardId, status) => {
        logger.info('notifyAwardReviewed', { uid, awardId, status });
      },
    },
    clock: { now: () => new Date() },
  };
}

export function liveAwardStore(): FirestoreAwardStore {
  return new FirestoreAwardStore(adminDb());
}
