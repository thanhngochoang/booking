/**
 * S27 recruit posts and applications (spec 2026-10-07-studio-recruiting-design.md §3; plan #151).
 * Pure rules: input validation, filter/match keys, counters and the daily quotas. One place to change the numbers.
 */

import { findContactLeak } from './contact_filter.js';
import { DomainError } from './errors.js';
import { RECRUIT_AREAS } from './recruit_areas.js';
import { vnDayKey } from './verification.js';

export { recruitMatchKeys } from './recruit_areas.js';

export const RECRUIT_KINDS = ['collaborator', 'member'] as const;
export const RECRUIT_FREQUENCIES = ['occasional', 'weekly', 'seasonal'] as const;
export const RECRUIT_POST_STATUSES = ['open', 'closed', 'expired'] as const;
export const APPLICATION_STATUSES = ['applied', 'accepted', 'declined', 'withdrawn', 'expired'] as const;

export type RecruitKind = (typeof RECRUIT_KINDS)[number];
export type RecruitFrequency = (typeof RECRUIT_FREQUENCIES)[number];
export type RecruitPostStatus = (typeof RECRUIT_POST_STATUSES)[number];
export type ApplicationStatus = (typeof APPLICATION_STATUSES)[number];

export const RECRUIT_TITLE_MIN = 8,
  RECRUIT_TITLE_MAX = 80,
  RECRUIT_REQUIREMENTS_MAX = 600,
  RECRUIT_SPECIALTIES_MAX = 4,
  RECRUIT_AREAS_MAX = 5,
  RECRUIT_POST_DAYS = 30,
  MAX_OPEN_POSTS = 3,
  STUDIO_POST_DAILY_ACTIONS = 5,
  APPLICATION_MESSAGE_MAX = 400,
  APPLICATION_SAMPLES_MAX = 3,
  APPLICATION_TTL_DAYS = 7,
  MAX_OPEN_APPLICATIONS = 10,
  APPLY_DAILY = 3,
  RECRUIT_NOTICES_DAILY = 3,
  RECRUIT_FANOUT_MAX = 200,
  FEE_MIN = 1_000,
  FEE_MAX = 100_000_000,
  FEE_STEP = 1_000;

/**
 * Studio collaboration actions per VN day (Decision 5): invite, cancel invite, accept or decline an
 * application, end. Declared here because declining an application (this module's use case) counts;
 * `studio_collaboration.ts` (Task 3) uses this one.
 */
export const STUDIO_COLLAB_DAILY_ACTIONS = 10;

/**
 * Specialty ids a post may name: the ids of `kSpecialties` (app_flutter/lib/data/taxonomy/builtin_taxonomy.dart),
 * in order. Change both together.
 */
export const RECRUIT_SPECIALTIES = [
  'portrait', 'wedding', 'couple', 'family', 'graduation', 'event', 'product',
  'travel', 'fashion', 'food', 'real_estate', 'newborn', 'street', 'commercial',
] as const;

const DAY_MS = 24 * 60 * 60 * 1000;

/** `at` plus whole days. */
export const recruitDaysAfter = (at: Date, days: number): Date => new Date(at.getTime() + days * DAY_MS);

export type FeeHint = { readonly type: 'per_shoot'; readonly amount: number } | { readonly type: 'negotiable' };

/** An integer VND amount 1.000–100.000.000 in steps of 1.000 (fee hints, agreed fees, default fees). */
export function isValidFee(v: unknown): v is number {
  return typeof v === 'number' && Number.isInteger(v) && v >= FEE_MIN && v <= FEE_MAX && v % FEE_STEP === 0;
}

/** Denormalised at create, update and renew (Decision 22). */
export interface RecruitStudioSnapshot {
  readonly name: string;
  readonly avatarUrl: string | null;
  readonly businessVerified: boolean;
}

/** `recruitPosts/{id}`. */
export interface RecruitPost {
  readonly id: string;
  readonly studioId: string;
  readonly studio: RecruitStudioSnapshot;
  readonly kind: RecruitKind;
  readonly title: string;
  readonly specialties: readonly string[];
  readonly areas: readonly string[];
  readonly frequency: RecruitFrequency;
  readonly feeHint: FeeHint;
  readonly requirements: string;
  readonly status: RecruitPostStatus;
  readonly renewed: boolean;
  readonly applicationCount: number;
  readonly matchKeys: readonly string[];
  readonly filterKeys: readonly string[];
  readonly createdAt: Date;
  readonly updatedAt: Date;
  readonly expiresAt: Date;
  readonly closedAt: Date | null;
}

/** `recruitApplications/{postId}_{applicantId}`. */
export interface RecruitApplication {
  readonly id: string;
  readonly postId: string;
  readonly studioId: string;
  readonly applicantId: string;
  readonly kind: RecruitKind;
  readonly postTitle: string;
  readonly applicant: { readonly name: string; readonly avatarUrl: string | null };
  readonly status: ApplicationStatus;
  readonly message: string;
  readonly samplePostIds: readonly string[];
  /** Collaborator kind: when the applicant accepted the collaboration terms; member kind: null. */
  readonly termsAcceptedAt: Date | null;
  readonly createdAt: Date;
  readonly expiresAt: Date;
  /** When the studio accepted or declined (also a decline by closing the post); null otherwise. */
  readonly respondedAt: Date | null;
}

export const recruitApplicationId = (postId: string, applicantId: string): string => `${postId}_${applicantId}`;

/** Actions counted on the Vietnam day `day` (`vnDayKey`). */
export interface Daily {
  readonly day: string;
  readonly count: number;
}

/** `recruit_post_new` received on `day`; `postIds` makes a replayed fan-out count once. */
export interface NoticeDaily extends Daily {
  readonly postIds: readonly string[];
}

/** `photographers/{uid}/private/recruit` (Decision 5), server-only. */
export interface RecruitCounters {
  readonly openPostCount: number;
  readonly postActions: Daily | null;
  readonly activeCollabCount: number;
  readonly pendingInviteCount: number;
  readonly collabActions: Daily | null;
  readonly openApplicationCount: number;
  readonly applyActions: Daily | null;
  readonly notices: NoticeDaily | null;
  readonly unpaidFlags: readonly Date[];
  readonly recruitBlockedUntil: Date | null;
}

export const EMPTY_COUNTERS: RecruitCounters = {
  openPostCount: 0,
  postActions: null,
  activeCollabCount: 0,
  pendingInviteCount: 0,
  collabActions: null,
  openApplicationCount: 0,
  applyActions: null,
  notices: null,
  unpaidFlags: [],
  recruitBlockedUntil: null,
};

/** One more action today (VN day); throws `rate_limited` when `max` were already taken today. */
export function takeDaily(d: Daily | null, at: Date, max: number): Daily {
  const day = vnDayKey(at);
  if (d === null || d.day !== day) return { day, count: 1 };
  if (d.count >= max) throw new DomainError('rate_limited');
  return { day, count: d.count + 1 };
}

/** The studio may not post, invite or assign collaborators until `recruitBlockedUntil` (Decision 15). */
export function isRecruitBlocked(c: RecruitCounters, now: Date): boolean {
  return c.recruitBlockedUntil !== null && now.getTime() < c.recruitBlockedUntil.getTime();
}

/** `k=…|a=…|s=…` with the given parts, in that order; '' for no filter. */
export function recruitFilterKey(f: { kind?: string; area?: string; specialty?: string }): string {
  const parts: string[] = [];
  if (f.kind !== undefined) parts.push(`k=${f.kind}`);
  if (f.area !== undefined) parts.push(`a=${f.area}`);
  if (f.specialty !== undefined) parts.push(`s=${f.specialty}`);
  return parts.join('|');
}

/** Every non-empty combination of kind, one area and one specialty (≤ 59 for 5 areas × 4 specialties). */
export function recruitFilterKeys(p: { kind: string; areas: readonly string[]; specialties: readonly string[] }): string[] {
  const kinds = [undefined, p.kind];
  const areas = [undefined, ...new Set(p.areas)];
  const specialties = [undefined, ...new Set(p.specialties)];
  const keys: string[] = [];
  for (const kind of kinds) {
    for (const area of areas) {
      for (const specialty of specialties) {
        const key = recruitFilterKey({ kind, area, specialty });
        if (key !== '') keys.push(key);
      }
    }
  }
  return keys;
}

/** The editable fields of a post. `kind` is null only in update mode when the input leaves it out. */
export interface RecruitPostFields {
  readonly kind: RecruitKind | null;
  readonly title: string;
  readonly specialties: readonly string[];
  readonly areas: readonly string[];
  readonly frequency: RecruitFrequency;
  readonly feeHint: FeeHint;
  readonly requirements: string;
}

const AREA_IDS: ReadonlySet<string> = new Set(RECRUIT_AREAS.map((a) => a.id));
const SPECIALTY_IDS: ReadonlySet<string> = new Set(RECRUIT_SPECIALTIES);

const invalid = (field: string): DomainError => new DomainError('invalid_argument', field);

/** Characters as the user sees them (code points, after NFC). */
const lengthOf = (s: string): number => [...s.normalize('NFC')].length;

function codeOf<T extends string>(raw: unknown, codes: readonly T[], field: string): T {
  if (typeof raw !== 'string' || !(codes as readonly string[]).includes(raw)) throw invalid(field);
  return raw as T;
}

function idList(raw: unknown, known: ReadonlySet<string>, max: number, field: string): string[] {
  if (!Array.isArray(raw) || raw.length < 1 || raw.length > max) throw invalid(field);
  const ids = raw as unknown[];
  if (!ids.every((v): v is string => typeof v === 'string' && known.has(v)) || new Set(ids).size !== ids.length) {
    throw invalid(field);
  }
  return ids;
}

function feeHintOf(raw: unknown): FeeHint {
  if (raw === null || typeof raw !== 'object') throw invalid('feeHint');
  const { type, amount } = raw as { type?: unknown; amount?: unknown };
  if (type === 'negotiable') return { type: 'negotiable' };
  if (type === 'per_shoot' && isValidFee(amount)) return { type: 'per_shoot', amount };
  throw invalid('feeHint');
}

/** Refuses free text that carries contact info (#139's filter; 'zalo' included) with field `<field>.contact`. */
export function assertNoContact(text: string, field: string): void {
  if (findContactLeak(text) !== null) throw invalid(`${field}.contact`);
}

/**
 * Post input of S27.04. `invalid_argument` with the offending field; contact info in the title or the
 * requirements is `title.contact` / `requirements.contact` (Decision 11). Create needs `kind`; update may
 * leave it out (the use case refuses a change).
 */
export function validateRecruitPostInput(raw: unknown, mode: 'create' | 'update'): RecruitPostFields {
  if (raw === null || typeof raw !== 'object') throw new DomainError('invalid_argument');
  const r = raw as Record<string, unknown>;
  const kind = mode === 'update' && r.kind === undefined ? null : codeOf(r.kind, RECRUIT_KINDS, 'kind');

  if (typeof r.title !== 'string') throw invalid('title');
  const title = r.title.trim();
  if (lengthOf(title) < RECRUIT_TITLE_MIN || lengthOf(title) > RECRUIT_TITLE_MAX) throw invalid('title');
  assertNoContact(title, 'title');

  const specialties = idList(r.specialties, SPECIALTY_IDS, RECRUIT_SPECIALTIES_MAX, 'specialties');
  const areas = idList(r.areas, AREA_IDS, RECRUIT_AREAS_MAX, 'areas');
  const frequency = codeOf(r.frequency, RECRUIT_FREQUENCIES, 'frequency');
  const feeHint = feeHintOf(r.feeHint);

  if (r.requirements !== undefined && r.requirements !== null && typeof r.requirements !== 'string') throw invalid('requirements');
  const requirements = typeof r.requirements === 'string' ? r.requirements.trim() : '';
  if (lengthOf(requirements) > RECRUIT_REQUIREMENTS_MAX) throw invalid('requirements');
  assertNoContact(requirements, 'requirements');

  return { kind, title, specialties, areas, frequency, feeHint, requirements };
}
