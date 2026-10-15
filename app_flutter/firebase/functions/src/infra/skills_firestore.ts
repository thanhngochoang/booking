import { FieldValue, type DocumentData, type Firestore, type Timestamp } from 'firebase-admin/firestore';
import { isOwnEvidencePost, type OwnedPostsReader, type SkillsScoreUpdate, type SkillsScoreWriter } from '@photobooking/domain';

// Firestore adapters of the onPhotographerWrite ports. Reads go through one `db.getAll`.

export const POSTS = 'posts';

export function firestoreOwnedPostsReader(db: Firestore): OwnedPostsReader {
  return {
    async owned(uid, postIds) {
      if (postIds.length === 0) return new Set<string>();
      const snaps = await db.getAll(...postIds.map((id) => db.collection(POSTS).doc(id)));
      return new Set(snaps.filter((s) => isOwnEvidencePost(uid, s.exists ? s.data() : undefined)).map((s) => s.id));
    },
  };
}

/** Field paths of the single update (dotted, so the client-owned part of `skills` stays as is). */
export function skillsUpdateFields(update: SkillsScoreUpdate): DocumentData {
  return {
    'skills.completeness': update.completeness,
    'skills.completenessNext': update.completenessNext,
    'skills.completenessNextAfter': update.completenessNextAfter,
    'skills.updatedAt': FieldValue.serverTimestamp(),
    ...(update.specialties === null
      ? {}
      : { 'skills.specialties': update.specialties, 'skills.evidenceRemovedAt': FieldValue.serverTimestamp() }),
  };
}

/** gRPC FAILED_PRECONDITION (9: changed since the trigger's snapshot) or NOT_FOUND (5: deleted). */
export function isStaleWriteError(e: unknown): boolean {
  if (typeof e !== 'object' || e === null || !('code' in e)) return false;
  return e.code === 9 || e.code === 5;
}

/**
 * Writes only if `photographers/{uid}` still has the update time last seen (the trigger's snapshot,
 * then the last `reread`). A newer save fails the precondition: `stale`; the use case then calls
 * `reread` once and scores what is stored now (bounded: one reread per event).
 */
export function firestoreSkillsScoreWriter(db: Firestore, uid: string, lastUpdateTime: Timestamp | undefined): SkillsScoreWriter {
  const ref = () => db.collection('photographers').doc(uid);
  let seen = lastUpdateTime;
  return {
    async write(update) {
      if (seen === undefined) return 'stale';
      try {
        await ref().update(skillsUpdateFields(update), { lastUpdateTime: seen });
        return 'written';
      } catch (e) {
        if (isStaleWriteError(e)) return 'stale';
        throw e;
      }
    },
    async reread() {
      const snap = await ref().get();
      seen = snap.exists ? snap.updateTime : undefined;
      return snap.exists ? { skills: snap.get('skills') as unknown } : null;
    },
  };
}
