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
