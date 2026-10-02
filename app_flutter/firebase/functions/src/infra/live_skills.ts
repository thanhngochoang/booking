import type { Timestamp } from 'firebase-admin/firestore';
import type { ScoreSkillsDeps } from '@photobooking/domain';
import { db } from './admin.js';
import { firestoreOwnedPostsReader, firestoreSkillsScoreWriter } from './skills_firestore.js';

/** Production wiring of onPhotographerWrite for one event (the writer carries its precondition). */
export function liveSkillsDeps(uid: string, lastUpdateTime: Timestamp | undefined): ScoreSkillsDeps {
  const firestore = db();
  return {
    posts: firestoreOwnedPostsReader(firestore),
    writer: firestoreSkillsScoreWriter(firestore, uid, lastUpdateTime),
  };
}
