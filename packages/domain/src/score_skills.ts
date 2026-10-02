// Use case behind the Firestore trigger onPhotographerWrite (spec 2026-10-02 §2): skip what needs
// no work, check the evidence with one read, score, write once. Firestore lives in the adapters.
import {
  cleanEvidence,
  evidenceIds,
  parseSkills,
  sameClientSkills,
  skillsCompleteness,
  toStoredSpecialties,
  type CompletenessStep,
  type Skills,
  type StoredSpecialty,
} from './skills.js';

/** One write of `photographers/{uid}`: the raw `skills` values before and after. */
export interface SkillsWriteEvent {
  readonly uid: string;
  readonly before: unknown;
  readonly after: unknown;
  /** The document itself was deleted. */
  readonly deleted: boolean;
}

/** Which of `postIds` are the photographer's own live posts (one batched read). */
export interface OwnedPostsReader {
  owned(uid: string, postIds: readonly string[]): Promise<ReadonlySet<string>>;
}

export interface SkillsScoreUpdate {
  readonly completeness: number;
  readonly completenessNext: CompletenessStep | null;
  /** The score once `completenessNext` is done; null when it is null. */
  readonly completenessNextAfter: number | null;
  /** The cleaned genres when evidence was removed (then `evidenceRemovedAt` is set too); else null. */
  readonly specialties: readonly StoredSpecialty[] | null;
}

/**
 * Writes the server fields only if the document is still the one the trigger saw; `stale` when
 * it changed (a newer save, whose own trigger scores it) or was deleted. Other failures throw.
 */
export interface SkillsScoreWriter {
  write(update: SkillsScoreUpdate): Promise<'written' | 'stale'>;
}

export interface ScoreSkillsDeps {
  readonly posts: OwnedPostsReader;
  readonly writer: SkillsScoreWriter;
}

export type ScoreSkillsOutcome = 'deleted' | 'no_skills' | 'unchanged' | 'malformed' | 'up_to_date' | 'written' | 'stale';

export type SkillsScorePlan =
  | { readonly kind: 'skip'; readonly reason: 'deleted' | 'no_skills' | 'unchanged' | 'malformed' }
  | { readonly kind: 'score'; readonly skills: Skills };

/** What a write needs, decided without any read. `unchanged` is the re-entry guard. */
export function planSkillsScore(e: SkillsWriteEvent): SkillsScorePlan {
  if (e.deleted) return { kind: 'skip', reason: 'deleted' };
  if (e.after === undefined) return { kind: 'skip', reason: 'no_skills' };
  if (sameClientSkills(e.before, e.after)) return { kind: 'skip', reason: 'unchanged' };
  const skills = parseSkills(e.after);
  return skills === null ? { kind: 'skip', reason: 'malformed' } : { kind: 'score', skills };
}

const storedField = (raw: unknown, key: string): unknown =>
  typeof raw === 'object' && raw !== null && !Array.isArray(raw) ? (raw as Record<string, unknown>)[key] : undefined;

/**
 * Scores `photographers/{uid}.skills` and removes evidence that is not the photographer's own.
 * Idempotent: a re-run finds the score current (`up_to_date`) and writes nothing. Read and write
 * failures propagate so Cloud Functions retries the event.
 */
export async function scorePhotographerSkills(e: SkillsWriteEvent, deps: ScoreSkillsDeps): Promise<ScoreSkillsOutcome> {
  const plan = planSkillsScore(e);
  if (plan.kind === 'skip') return plan.reason;
  const ids = evidenceIds(plan.skills);
  const owned = ids.length === 0 ? new Set<string>() : await deps.posts.owned(e.uid, ids);
  const { skills, removed } = cleanEvidence(plan.skills, owned);
  const { percent, next, nextAfter } = skillsCompleteness(skills);
  if (
    !removed &&
    storedField(e.after, 'completeness') === percent &&
    storedField(e.after, 'completenessNext') === next &&
    storedField(e.after, 'completenessNextAfter') === nextAfter
  ) {
    return 'up_to_date';
  }
  return deps.writer.write({
    completeness: percent,
    completenessNext: next,
    completenessNextAfter: nextAfter,
    specialties: removed ? toStoredSpecialties(skills.specialties) : null,
  });
}
