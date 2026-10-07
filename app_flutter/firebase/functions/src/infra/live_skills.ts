import type { Firestore, Timestamp } from 'firebase-admin/firestore';
import type { ScoreSkillsDeps } from '@photobooking/domain';
import { db } from './admin.js';
import type { AcceptingOrdersWriter } from '../triggers/photographer_write.js';
import { firestoreOwnedPostsReader, firestoreSkillsScoreWriter } from './skills_firestore.js';

/** Production wiring of onPhotographerWrite for one event (the writer carries its precondition). */
export function liveSkillsDeps(uid: string, lastUpdateTime: Timestamp | undefined): ScoreSkillsDeps {
  const firestore = db();
  return {
    posts: firestoreOwnedPostsReader(firestore),
    writer: firestoreSkillsScoreWriter(firestore, uid, lastUpdateTime),
  };
}

/** Production writer of the derived `acceptingOrders` flag (Admin SDK bypasses the rules). */
export function liveAcceptingOrdersWriter(firestore: Firestore = db()): AcceptingOrdersWriter {
  return {
    async set(uid, acceptingOrders) {
      try {
        await firestore.collection('photographers').doc(uid).update({ acceptingOrders });
      } catch (e) {
        // gRPC NOT_FOUND (5): the doc was deleted between the event and this write. No-op, not a
        // retry; `update` (not `set` merge) so a deleted photographer is never recreated.
        if ((e as { code?: unknown }).code === 5) return;
        throw e;
      }
    },
  };
}
