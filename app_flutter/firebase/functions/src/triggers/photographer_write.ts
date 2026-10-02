import type { DocumentData } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { scorePhotographerSkills, type ScoreSkillsDeps, type ScoreSkillsOutcome } from '@photobooking/domain';

/** The two snapshots of one `photographers/{uid}` write; `after` undefined when it was deleted. */
export interface PhotographerWriteInput {
  readonly uid: string;
  readonly before: DocumentData | undefined;
  readonly after: DocumentData | undefined;
}

export async function handlePhotographerWrite(input: PhotographerWriteInput, deps: ScoreSkillsDeps): Promise<ScoreSkillsOutcome> {
  const outcome = await scorePhotographerSkills(
    { uid: input.uid, before: input.before?.skills, after: input.after?.skills, deleted: input.after === undefined },
    deps,
  );
  if (outcome === 'malformed') {
    // The rules refuse such writes; reaching here means an Admin write or a rules gap.
    logger.warn('onPhotographerWrite: skills do not match the schema; nothing written', { uid: input.uid });
  } else if (outcome === 'written' || outcome === 'stale') {
    logger.info('onPhotographerWrite', { uid: input.uid, outcome });
  }
  return outcome;
}

/** Events older than this are dropped instead of retried (deployed with `retry: true`). */
export const MAX_EVENT_AGE_MS = 60 * 60 * 1000;

/** gRPC INVALID_ARGUMENT (3) or PERMISSION_DENIED (7): retrying the same event cannot succeed. */
export function isPermanentFirestoreError(e: unknown): boolean {
  if (typeof e !== 'object' || e === null || !('code' in e)) return false;
  return e.code === 3 || e.code === 7;
}

export interface PhotographerEventInput extends PhotographerWriteInput {
  /** `event.time` (RFC 3339). */
  readonly time: string;
}

/**
 * Retry policy around handlePhotographerWrite: an event older than 1 hour is dropped and a
 * permanent Firestore error ends the event (both logged as errors with the uid only, never data
 * or messages); other failures are rethrown so Functions retries. A dropped event leaves the
 * profile unscored or with an out-of-date score; the next write of the document scores it
 * (the `unchanged` guard holds only when the stored score matches the stored skills).
 * `deps` is called only for an event that is handled.
 */
export async function handlePhotographerEvent(
  input: PhotographerEventInput,
  deps: () => ScoreSkillsDeps,
  now: Date = new Date(),
): Promise<ScoreSkillsOutcome | 'expired' | 'failed'> {
  const age = now.getTime() - Date.parse(input.time);
  if (age > MAX_EVENT_AGE_MS) {
    logger.error('onPhotographerWrite: event older than 1 hour dropped; the next save scores the profile', { uid: input.uid });
    return 'expired';
  }
  try {
    return await handlePhotographerWrite(input, deps());
  } catch (e) {
    if (!isPermanentFirestoreError(e)) throw e;
    logger.error('onPhotographerWrite: permanent Firestore error; not retried', { uid: input.uid, code: (e as { code: number }).code });
    return 'failed';
  }
}
