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
 * Writes the server fields only if the document is still the one last seen (the trigger's snapshot,
 * then the last `reread`); `stale` when it changed or was deleted. Other failures throw.
 */
export interface SkillsScoreWriter {
  write(update: SkillsScoreUpdate): Promise<'written' | 'stale'>;
  /**
   * After a stale write: reads the document again (the raw `skills`, or null when it was deleted);
   * the next `write` is conditioned on this read.
   */
  reread(): Promise<{ readonly skills: unknown } | null>;
}

export interface ScoreSkillsDeps {
  readonly posts: OwnedPostsReader;
  readonly writer: SkillsScoreWriter;
}

export type ScoreSkillsOutcome = 'deleted' | 'no_skills' | 'unchanged' | 'malformed' | 'up_to_date' | 'written' | 'stale';

export type SkillsScorePlan =
  | { readonly kind: 'skip'; readonly reason: 'deleted' | 'no_skills' | 'unchanged' | 'malformed' }
  | { readonly kind: 'score'; readonly skills: Skills };

const storedField = (raw: unknown, key: string): unknown =>
  typeof raw === 'object' && raw !== null && !Array.isArray(raw) ? (raw as Record<string, unknown>)[key] : undefined;

/** The stored server fields equal the score of `skills`. */
function storedScoreIs(raw: unknown, c: { percent: number; next: CompletenessStep | null; nextAfter: number | null }): boolean {
  return (
    storedField(raw, 'completeness') === c.percent &&
    storedField(raw, 'completenessNext') === c.next &&
    storedField(raw, 'completenessNextAfter') === c.nextAfter
  );
}

/**
 * What a write needs, decided without any read. `unchanged` is the re-entry guard: the client part
 * of `skills` did not change AND the stored score is the score of the stored skills (every
 * Function write keeps that true, so its own write stops here). A profile left unscored or with an
 * out-of-date score (a run that went stale, or an event dropped as too old) is scored by the next
 * write of the document, whatever field it changes.
 */
export function planSkillsScore(e: SkillsWriteEvent): SkillsScorePlan {
  if (e.deleted) return { kind: 'skip', reason: 'deleted' };
  if (e.after === undefined) return { kind: 'skip', reason: 'no_skills' };
  const skills = parseSkills(e.after);
  if (sameClientSkills(e.before, e.after) && (skills === null || storedScoreIs(e.after, skillsCompleteness(skills)))) {
    return { kind: 'skip', reason: 'unchanged' };
  }
  return skills === null ? { kind: 'skip', reason: 'malformed' } : { kind: 'score', skills };
}

/**
 * Scores `photographers/{uid}.skills` and removes evidence that is not the photographer's own.
 * Idempotent: a re-run finds the score current (`up_to_date`) and writes nothing. A stale write
 * (a save during the run) re-reads the document once and scores what is stored now; a second
 * stale write gives up (that newer save is unscored, so its own trigger scores it). Read and write
 * failures propagate so Cloud Functions retries the event.
 */
export async function scorePhotographerSkills(e: SkillsWriteEvent, deps: ScoreSkillsDeps): Promise<ScoreSkillsOutcome> {
  const plan = planSkillsScore(e);
  if (plan.kind === 'skip') return plan.reason;
  const first = await scoreAndWrite(e.uid, e.after, plan.skills, deps);
  if (first !== 'stale') return first;
  const current = await deps.writer.reread();
  if (current === null) return 'stale';
  const again = planSkillsScore({ uid: e.uid, before: undefined, after: current.skills, deleted: false });
  if (again.kind === 'skip') return again.reason;
  return scoreAndWrite(e.uid, current.skills, again.skills, deps);
}

async function scoreAndWrite(uid: string, raw: unknown, parsed: Skills, deps: ScoreSkillsDeps): Promise<ScoreSkillsOutcome> {
  const ids = evidenceIds(parsed);
  const owned = ids.length === 0 ? new Set<string>() : await deps.posts.owned(uid, ids);
  const { skills, removed } = cleanEvidence(parsed, owned);
  const { percent, next, nextAfter } = skillsCompleteness(skills);
  if (!removed && storedScoreIs(raw, { percent, next, nextAfter })) return 'up_to_date';
  return deps.writer.write({
    completeness: percent,
    completenessNext: next,
    completenessNextAfter: nextAfter,
    specialties: removed ? toStoredSpecialties(skills.specialties) : null,
  });
}
