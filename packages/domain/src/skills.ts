// Photographer skills (spec 3e.2–3e.3): the reading rules of the app's skillsFromMap
// (app_flutter/lib/data/skills/photographer_skills.dart), the evidence check and the
// "Độ khớp hồ sơ" score. Pure: the Function onPhotographerWrite wires it to Firestore.
import { isId } from './ids.js';

export const SKILLS_SCHEMA_VERSION = 1;

/** Fields of `photographers/{uid}.skills` written only by the server (Admin SDK). */
export const SERVER_SKILL_FIELDS = ['completeness', 'completenessNext', 'completenessNextAfter', 'updatedAt', 'evidenceRemovedAt'] as const;

/** 1 Cơ bản, 2 Thành thạo, 3 Chuyên sâu. */
export type SkillLevel = 1 | 2 | 3;

export interface SpecialtySkill {
  readonly id: string;
  readonly level: SkillLevel;
  readonly years: number | null;
  readonly evidencePostIds: readonly string[];
}

/** The client-owned part of `photographers/{uid}.skills`. */
export interface Skills {
  readonly specialties: readonly SpecialtySkill[];
  readonly styles: readonly string[];
  readonly extras: readonly string[];
  readonly languages: readonly string[];
  readonly audiences: readonly string[];
  readonly yearsExperience: number | null;
}

const isRecord = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);

const integer = (v: unknown): number | null => (typeof v === 'number' && Number.isInteger(v) ? v : null);

/** Strings only, each once, in their first order (Dart `_strings`). */
function strings(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return [...new Set(v.filter((x): x is string => typeof x === 'string'))];
}

/**
 * The stored skills map → Skills, or null when it is not a schema-1 map (malformed: the
 * Function logs it and writes nothing). Inside a schema-1 map it is as tolerant as the app:
 * malformed genres are dropped, a duplicate genre id counts once (first wins), a level outside
 * 1..3 reads as 2, non-integer years read as null.
 */
export function parseSkills(raw: unknown): Skills | null {
  if (!isRecord(raw) || raw.schemaVersion !== SKILLS_SCHEMA_VERSION) return null;
  const specialties: SpecialtySkill[] = [];
  const seen = new Set<string>();
  const list: unknown = raw.specialties;
  if (Array.isArray(list)) {
    for (const e of list) {
      if (!isRecord(e)) continue;
      const id = e.id;
      if (typeof id !== 'string' || seen.has(id)) continue;
      seen.add(id);
      const lv = e.level;
      specialties.push({
        id,
        level: lv === 1 || lv === 3 ? lv : 2,
        years: integer(e.years),
        evidencePostIds: strings(e.evidencePostIds),
      });
    }
  }
  return {
    specialties,
    styles: strings(raw.styles),
    extras: strings(raw.extras),
    languages: strings(raw.languages),
    audiences: strings(raw.audiences),
    yearsExperience: integer(raw.yearsExperience),
  };
}

/** 6 genres × 3 posts: the most one run reads (spec 3e.2). */
export const MAX_EVIDENCE_READS = 18;

/**
 * Post ids to look up, each once, at most 18. Ids that are not opaque ids are left out: they
 * cannot be a post (and `doc('a/b')` would throw), so cleanEvidence removes them.
 */
export function evidenceIds(skills: Skills): string[] {
  const ids = new Set(skills.specialties.flatMap((s) => s.evidencePostIds).filter(isId));
  return [...ids].slice(0, MAX_EVIDENCE_READS);
}

/** The fields of a `posts/{id}` document the evidence check reads. */
export interface EvidencePostRecord {
  readonly authorId?: unknown;
  readonly photographerId?: unknown;
  readonly deletedAt?: unknown;
}

/**
 * Evidence must be the photographer's own live post: the document exists, has no `deletedAt`,
 * and its owner (`authorId`, else `photographerId`, like the app's postFromFirestore) is `uid`.
 * A customer's real-shoot post about the photographer (`authorId` = the customer) does not count.
 */
export function isOwnEvidencePost(uid: string, post: EvidencePostRecord | undefined): boolean {
  if (post === undefined || (post.deletedAt !== undefined && post.deletedAt !== null)) return false;
  const owner = typeof post.authorId === 'string' ? post.authorId : post.photographerId;
  return owner === uid;
}

/** Keeps only owned evidence; a level-3 genre left with none becomes level 2. */
export function cleanEvidence(skills: Skills, ownedIds: ReadonlySet<string>): { skills: Skills; removed: boolean } {
  let removed = false;
  const specialties = skills.specialties.map((sp): SpecialtySkill => {
    const kept = sp.evidencePostIds.filter((id) => ownedIds.has(id));
    if (kept.length === sp.evidencePostIds.length) return sp;
    removed = true;
    return { ...sp, level: sp.level === 3 && kept.length === 0 ? 2 : sp.level, evidencePostIds: kept };
  });
  return removed ? { skills: { ...skills, specialties }, removed } : { skills, removed };
}

/** Score parts of spec 3e.2, highest weight first; `next` is the first one missing. */
export const COMPLETENESS_STEPS = ['specialties', 'levels', 'evidence', 'styles', 'languages', 'audiences', 'extras'] as const;

export type CompletenessStep = (typeof COMPLETENESS_STEPS)[number];

export const COMPLETENESS_POINTS: Readonly<Record<CompletenessStep, number>> = {
  specialties: 25,
  levels: 20,
  evidence: 20,
  styles: 10,
  languages: 10,
  audiences: 10,
  extras: 5,
};

export interface Completeness {
  /** 0..100; shown only to the photographer. */
  readonly percent: number;
  /** First missing step, or null at 100. */
  readonly next: CompletenessStep | null;
  /** The score once `next` is done (null when `next` is null): the S38 hint "để lên N%". */
  readonly nextAfter: number | null;
}

function done(s: Skills, step: CompletenessStep): boolean {
  const any = s.specialties.length > 0;
  switch (step) {
    case 'specialties':
      return any;
    case 'levels':
      return any && s.specialties.every((x) => x.level >= 1 && x.level <= 3);
    case 'evidence':
      return any && s.specialties.every((x) => x.level !== 3 || x.evidencePostIds.length > 0);
    case 'styles':
      return s.styles.length > 0;
    case 'languages':
      return s.languages.length > 0;
    case 'audiences':
      return s.audiences.length > 0;
    case 'extras':
      return s.extras.length > 0;
  }
}

function percentOf(s: Skills): number {
  return COMPLETENESS_STEPS.reduce((sum, step) => sum + (done(s, step) ? COMPLETENESS_POINTS[step] : 0), 0);
}

/** The minimal change that completes `step` (same as the app's CompletenessHint.percentAfter). */
function withStepDone(s: Skills, step: CompletenessStep): Skills {
  switch (step) {
    case 'specialties':
      return { ...s, specialties: [{ id: '_', level: 2, years: null, evidencePostIds: [] }] };
    case 'levels':
      return s;
    case 'evidence': {
      const i = s.specialties.findIndex((x) => x.level === 3 && x.evidencePostIds.length === 0);
      return { ...s, specialties: s.specialties.map((x, j) => (j === i ? { ...x, evidencePostIds: ['_'] } : x)) };
    }
    case 'styles':
      return { ...s, styles: ['_'] };
    case 'languages':
      return { ...s, languages: ['_'] };
    case 'audiences':
      return { ...s, audiences: ['_'] };
    case 'extras':
      return { ...s, extras: ['_'] };
  }
}

/** "Độ khớp hồ sơ" (spec 3e.2), the first missing step and the score once it is done. */
export function skillsCompleteness(s: Skills): Completeness {
  const percent = percentOf(s);
  const next = COMPLETENESS_STEPS.find((step) => !done(s, step)) ?? null;
  return { percent, next, nextAfter: next === null ? null : percentOf(withStepDone(s, next)) };
}

const SERVER_FIELDS = new Set<string>(SERVER_SKILL_FIELDS);

function clientPart(v: unknown): unknown {
  if (!isRecord(v)) return v;
  return Object.fromEntries(Object.entries(v).filter(([k]) => !SERVER_FIELDS.has(k)));
}

function deepEqual(a: unknown, b: unknown): boolean {
  if (Object.is(a, b)) return true;
  if (Array.isArray(a) || Array.isArray(b)) {
    return Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((x, i) => deepEqual(x, b[i]));
  }
  if (!isRecord(a) || !isRecord(b)) return false;
  const keys = Object.keys(a);
  return keys.length === Object.keys(b).length && keys.every((k) => Object.hasOwn(b, k) && deepEqual(a[k], b[k]));
}

/**
 * The loop guard: true when the two raw skills values differ only in server fields, so the
 * write that fired the trigger was the Function's own (or an identical save) and needs no work.
 */
export function sameClientSkills(before: unknown, after: unknown): boolean {
  return deepEqual(clientPart(before), clientPart(after));
}

/** A genre as the app stores it (`skillsToMap`): `years` only when known. */
export interface StoredSpecialty {
  readonly id: string;
  readonly level: SkillLevel;
  readonly years?: number;
  readonly evidencePostIds: readonly string[];
}

export function toStoredSpecialties(specialties: readonly SpecialtySkill[]): StoredSpecialty[] {
  return specialties.map((s) => ({
    id: s.id,
    level: s.level,
    ...(s.years === null ? {} : { years: s.years }),
    evidencePostIds: [...s.evidencePostIds],
  }));
}
