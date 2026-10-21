import { Firestore, FieldValue } from 'firebase-admin/firestore';
import type { Bucket } from '@google-cloud/storage';
import { db, adminAuth, bucket as getBucket } from './admin.js';
import {
  accountDeletionBlockers,
  tombstoneOf,
  type AccountSnapshot,
} from '@photobooking/domain';

export interface PurgeDeps {
  readonly firestore: Firestore;
  readonly bucket: Bucket;
  snapshot(uid: string, now: Date): Promise<AccountSnapshot>;
  deleteAuthUser(uid: string): Promise<void>;
  logBlocked(uid: string, kinds: readonly string[]): Promise<void>;
}

export const PURGE_STEPS = [
  'check_blockers',
  'tombstone_user',
  'delete_user_private',
  'delete_notifications',
  'delete_badges',
  'delete_payments_projection',
  'delete_photographer',
  'delete_availability',
  'delete_payout_account',
  'delete_earnings',
  'delete_devices',
  'delete_social',
  'delete_posts',
  'delete_albums_awards',
  'delete_booking_contacts',
  'anonymize_registrations',
  'anonymize_events',
  'anonymize_jobs',
  'delete_storage',
  'delete_identity',
  'delete_auth',
] as const;

export async function purgeAccount(
  uid: string,
  deps: PurgeDeps,
  now: Date = new Date(),
): Promise<'done' | 'blocked'> {
  const delRef = deps.firestore.collection('account_deletions').doc(uid);
  const delSnap = await delRef.get();
  if (!delSnap.exists) return 'done';

  const data = delSnap.data();
  const done: string[] = Array.isArray(data?.done) ? [...data.done] : [];

  const recordDone = async (step: string) => {
    done.push(step);
    await delRef.update({
      done: FieldValue.arrayUnion(step),
    });
  };

  // 1. check_blockers
  if (!done.includes('check_blockers')) {
    const snap = await deps.snapshot(uid, now);
    const blockers = accountDeletionBlockers(snap);
    if (blockers.length > 0) {
      const kinds = blockers.map((b) => b.kind);
      await delRef.update({
        status: 'blocked',
        blockedReasons: kinds,
      });
      await deps.logBlocked(uid, kinds);
      return 'blocked';
    }
    await recordDone('check_blockers');
  }

  // 2. tombstone_user
  if (!done.includes('tombstone_user')) {
    const userRef = deps.firestore.collection('users').doc(uid);
    const uSnap = await userRef.get();
    if (uSnap.exists) {
      const tombstone = tombstoneOf(uSnap.data() ?? {}, now);
      await userRef.set(tombstone, { merge: true });
    }
    await recordDone('tombstone_user');
  }

  // 3. delete_user_private
  if (!done.includes('delete_user_private')) {
    const privateRef = deps.firestore.collection('users').doc(uid).collection('private');
    await deps.firestore.recursiveDelete(privateRef);
    await recordDone('delete_user_private');
  }

  // 4. delete_notifications
  if (!done.includes('delete_notifications')) {
    const notifs = await deps.firestore.collection('notifications').where('userId', '==', uid).get();
    const bw = deps.firestore.bulkWriter();
    for (const d of notifs.docs) bw.delete(d.ref);
    await bw.close();
    await recordDone('delete_notifications');
  }

  // 5. delete_badges
  if (!done.includes('delete_badges')) {
    const badgesRef = deps.firestore.collection('badges').doc(uid);
    await deps.firestore.recursiveDelete(badgesRef);
    await recordDone('delete_badges');
  }

  // 6. delete_payments_projection
  if (!done.includes('delete_payments_projection')) {
    const pSnap = await deps.firestore.collection('users').doc(uid).collection('payments').get();
    const bw = deps.firestore.bulkWriter();
    for (const d of pSnap.docs) bw.delete(d.ref);
    await bw.close();
    await recordDone('delete_payments_projection');
  }

  // 7. delete_photographer
  if (!done.includes('delete_photographer')) {
    const pRef = deps.firestore.collection('photographers').doc(uid);
    await deps.firestore.recursiveDelete(pRef);
    await recordDone('delete_photographer');
  }

  // 8. delete_availability
  if (!done.includes('delete_availability')) {
    const aRef = deps.firestore.collection('availability').doc(uid);
    await deps.firestore.recursiveDelete(aRef);
    await recordDone('delete_availability');
  }

  // 9. delete_payout_account
  if (!done.includes('delete_payout_account')) {
    const poRef = deps.firestore.collection('payoutAccounts').doc(uid);
    await deps.firestore.recursiveDelete(poRef);
    await recordDone('delete_payout_account');
  }

  // 10. delete_earnings
  if (!done.includes('delete_earnings')) {
    const eRef = deps.firestore.collection('earnings').doc(uid);
    await deps.firestore.recursiveDelete(eRef);
    await recordDone('delete_earnings');
  }

  // 11. delete_devices
  if (!done.includes('delete_devices')) {
    const devSnap = await deps.firestore.collection('devices').where('userId', '==', uid).get();
    const bw = deps.firestore.bulkWriter();
    for (const d of devSnap.docs) bw.delete(d.ref);
    await bw.close();
    await recordDone('delete_devices');
  }

  // 12. delete_social
  if (!done.includes('delete_social')) {
    const bw = deps.firestore.bulkWriter();
    const likes = await deps.firestore.collection('likes').where('userId', '==', uid).get();
    for (const d of likes.docs) bw.delete(d.ref);
    const saves = await deps.firestore.collection('saves').where('userId', '==', uid).get();
    for (const d of saves.docs) bw.delete(d.ref);
    const follows1 = await deps.firestore.collection('follows').where('userId', '==', uid).get();
    for (const d of follows1.docs) bw.delete(d.ref);
    const follows2 = await deps.firestore.collection('follows').where('photographerId', '==', uid).get();
    for (const d of follows2.docs) bw.delete(d.ref);
    await bw.close();
    await recordDone('delete_social');
  }

  // 13. delete_posts
  if (!done.includes('delete_posts')) {
    const posts = await deps.firestore.collection('posts').where('authorId', '==', uid).get();
    const bw = deps.firestore.bulkWriter();
    for (const d of posts.docs) bw.delete(d.ref);
    await bw.close();
    await recordDone('delete_posts');
  }

  // 14. delete_albums_awards
  if (!done.includes('delete_albums_awards')) {
    const albums = await deps.firestore.collection('albums').where('photographerId', '==', uid).get();
    const awards = await deps.firestore.collection('awards').where('photographerId', '==', uid).get();
    const bw = deps.firestore.bulkWriter();
    for (const d of albums.docs) bw.delete(d.ref);
    for (const d of awards.docs) bw.delete(d.ref);
    await bw.close();
    await recordDone('delete_albums_awards');
  }

  // 15. delete_booking_contacts
  if (!done.includes('delete_booking_contacts')) {
    const bSnap = await deps.firestore.collection('bookings').where('customerId', '==', uid).get();
    for (const d of bSnap.docs) {
      const contactRef = d.ref.collection('private').doc('contact');
      await contactRef.delete();
    }
    await recordDone('delete_booking_contacts');
  }

  // 16. anonymize_registrations
  if (!done.includes('anonymize_registrations')) {
    const regs = await deps.firestore.collectionGroup('registrations').where('userId', '==', uid).get();
    for (const d of regs.docs) {
      await d.ref.update({
        userName: 'Người dùng đã xoá',
        userAvatarUrl: null,
      });
      const cRef = d.ref.collection('private').doc('contact');
      await cRef.delete();
    }
    await recordDone('anonymize_registrations');
  }

  // 17. anonymize_events
  if (!done.includes('anonymize_events')) {
    const evs = await deps.firestore.collection('events').where('hostId', '==', uid).get();
    const bw = deps.firestore.bulkWriter();
    for (const d of evs.docs) {
      bw.update(d.ref, {
        'host.name': 'Người dùng đã xoá',
        'host.avatarUrl': null,
      });
    }
    await bw.close();
    await recordDone('anonymize_events');
  }

  // 18. anonymize_jobs
  if (!done.includes('anonymize_jobs')) {
    const jobs = await deps.firestore.collection('jobs').where('customerId', '==', uid).get();
    const bw = deps.firestore.bulkWriter();
    for (const d of jobs.docs) {
      bw.update(d.ref, { customerName: 'Người dùng đã xoá' });
    }
    await bw.close();
    await recordDone('anonymize_jobs');
  }

  // 19. delete_storage
  if (!done.includes('delete_storage')) {
    const prefixes = [
      `avatars/${uid}/`,
      `posts/${uid}/`,
      `users/${uid}/`,
      `awardProofs/${uid}/`,
      `eventCovers/${uid}/`,
      `exports/${uid}/`,
    ];
    for (const prefix of prefixes) {
      try {
        await deps.bucket.deleteFiles({ prefix });
      } catch {
        // ignore
      }
    }
    await recordDone('delete_storage');
  }

  // 20. delete_identity
  if (!done.includes('delete_identity')) {
    const idRef = deps.firestore.collection('identities').doc(uid);
    await idRef.delete();
    await recordDone('delete_identity');
  }

  // 21. delete_auth
  if (!done.includes('delete_auth')) {
    await deps.deleteAuthUser(uid);
    await recordDone('delete_auth');
  }

  await delRef.update({
    status: 'done',
    purgedAt: now.toISOString(),
  });

  return 'done';
}

export function livePurgeDeps(firestore: Firestore = db(), bucket: Bucket = getBucket()): PurgeDeps {
  const { FirestoreAccountDeletionDeps } = require('./account_firestore.js');
  const accountDeps = new FirestoreAccountDeletionDeps(firestore);

  return {
    firestore,
    bucket,
    snapshot: (uid, now) => accountDeps.snapshot(uid, now),
    deleteAuthUser: async (uid) => {
      try {
        await adminAuth().deleteUser(uid);
      } catch (e: any) {
        if (e?.code !== 'auth/user-not-found') throw e;
      }
    },
    logBlocked: async (uid, kinds) => {
      console.warn(`[deletion_blocked] uid=${uid} blockers=${kinds.join(',')}`);
    },
  };
}
