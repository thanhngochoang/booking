import { graphemeCount } from './booking_requests.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';

export const AWARD_RESULTS = ['gold', 'silver', 'bronze', 'honorable', 'finalist', 'exhibited'] as const;
export const AWARD_STATUSES = ['pending', 'needs_info', 'approved', 'rejected', 'revoked'] as const;
export const ARTIST_THRESHOLD = 3;
export const AWARDS_PER_PHOTOGRAPHER = 50;
export const PROOF_FILES_MAX = 3;
export const PROOF_LINKS_MAX = 2;
export const PROOF_PURGE_DAYS = 30;
export const COMPETITION_MIN = 2;
export const COMPETITION_MAX = 120;
export const CATEGORY_MAX = 60;
export const LINK_MAX = 300;
export const NOTE_MIN = 5;
export const NOTE_MAX = 500;
export const FIRST_AWARD_YEAR = 1950;

export type AwardResult = (typeof AWARD_RESULTS)[number];
export type AwardStatus = (typeof AWARD_STATUSES)[number];
export type ReviewAction = 'approve' | 'needs_info' | 'reject' | 'revoke';

export interface AwardInput {
  readonly awardId: string;
  readonly competition: string;
  readonly year: number;
  readonly category: string | null;
  readonly result: AwardResult;
  readonly workPostId: string | null;
  /** Storage paths. */
  readonly proofFiles: readonly string[];
  readonly proofLinks: readonly string[];
}

export interface Award {
  readonly id: string;
  readonly photographerId: string;
  readonly competition: string;
  readonly year: number;
  readonly category: string | null;
  readonly result: AwardResult;
  readonly workPostId: string | null;
  readonly status: AwardStatus;
  readonly reviewNote: string | null;
  readonly reviewedBy: string | null;
  readonly reviewedAt: Date | null;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface AwardProof {
  readonly awardId: string;
  readonly photographerId: string;
  readonly files: readonly string[];
  readonly links: readonly string[];
  readonly purgeAfter: Date | null;
}

const clean = (s: string): string => s.normalize('NFC').trim().replace(/\s+/g, ' ');

function text(v: unknown, min: number, max: number): string {
  if (typeof v !== 'string') throw new DomainError('invalid_argument');
  const t = clean(v);
  const n = graphemeCount(t);
  if (n < min || n > max) throw new DomainError('invalid_argument');
  return t;
}

/** Proof files live under `awardProofs/{callerId}/{awardId}/`, one plain file name each. */
export function proofFolder(callerId: string, awardId: string): string {
  return `awardProofs/${callerId}/${awardId}/`;
}

function proofPath(v: unknown, folder: string): string {
  if (typeof v !== 'string' || !v.startsWith(folder)) throw new DomainError('invalid_argument');
  if (!/^[A-Za-z0-9_.-]{1,100}$/.test(v.slice(folder.length)) || v.slice(folder.length).startsWith('..')) {
    throw new DomainError('invalid_argument');
  }
  return v;
}

function proofLink(v: unknown): string {
  if (typeof v !== 'string') throw new DomainError('invalid_argument');
  const t = v.trim();
  if (t.length > LINK_MAX || !/^https:\/\/[^\s/]/.test(t) || /\s/.test(t)) {
    throw new DomainError('invalid_argument');
  }
  return t;
}

function list(v: unknown, max: number): unknown[] {
  if (v === undefined) return [];
  if (!Array.isArray(v) || v.length > max) throw new DomainError('invalid_argument');
  return v;
}

/** invalid_argument unless Decision 1/3 and Global Constraints hold; `now` gives the current year. */
export function validateAwardInput(raw: unknown, callerId: string, now: Date): AwardInput {
  if (typeof raw !== 'object' || raw === null) throw new DomainError('invalid_argument');
  const r = raw as Record<string, unknown>;
  if (!isId(r.awardId)) throw new DomainError('invalid_argument');
  const awardId = r.awardId;
  const competition = text(r.competition, COMPETITION_MIN, COMPETITION_MAX);
  const year = r.year;
  if (
    typeof year !== 'number' ||
    !Number.isInteger(year) ||
    year < FIRST_AWARD_YEAR ||
    year > now.getUTCFullYear()
  ) {
    throw new DomainError('invalid_argument');
  }
  let category: string | null = null;
  if (r.category !== undefined && r.category !== null) {
    const c = clean(typeof r.category === 'string' ? r.category : '\u0000');
    if (c.includes('\u0000') || graphemeCount(c) > CATEGORY_MAX) throw new DomainError('invalid_argument');
    category = c === '' ? null : c;
  }
  if (!(AWARD_RESULTS as readonly unknown[]).includes(r.result)) throw new DomainError('invalid_argument');
  let workPostId: string | null = null;
  if (r.workPostId !== undefined && r.workPostId !== null) {
    if (!isId(r.workPostId)) throw new DomainError('invalid_argument');
    workPostId = r.workPostId;
  }
  const folder = proofFolder(callerId, awardId);
  const proofFiles = list(r.proofFiles, PROOF_FILES_MAX).map((p) => proofPath(p, folder));
  const proofLinks = list(r.proofLinks, PROOF_LINKS_MAX).map(proofLink);
  if (new Set(proofFiles).size !== proofFiles.length) throw new DomainError('invalid_argument');
  if (proofFiles.length + proofLinks.length < 1) throw new DomainError('invalid_argument');
  return {
    awardId,
    competition,
    year,
    category,
    result: r.result as AwardResult,
    workPostId,
    proofFiles,
    proofLinks,
  };
}

/** Staff and owner moves; throws conflict on an illegal one. */
export function nextStatus(current: AwardStatus, action: ReviewAction): AwardStatus {
  switch (action) {
    case 'approve':
      if (current === 'pending') return 'approved';
      break;
    case 'needs_info':
      if (current === 'pending') return 'needs_info';
      break;
    case 'reject':
      if (current === 'pending') return 'rejected';
      break;
    case 'revoke':
      if (current === 'approved') return 'revoked';
      break;
  }
  throw new DomainError('conflict');
}

/** Statuses after which proofs are deleted 30 days later. */
export const FINAL_STATUSES: readonly AwardStatus[] = ['approved', 'rejected', 'revoked'];

export function validateReviewNote(raw: unknown): string {
  return text(raw, NOTE_MIN, NOTE_MAX);
}
