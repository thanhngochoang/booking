/**
 * S18 disputes (#142): the dispute record, its input rules, the dispute window of a booking or ticket
 * and the money split of an outcome. Plan 2026-10-07-s18-disputes-help, Decisions 1–7.
 */

import { DISPUTE_WINDOW_HOURS } from './booking_policy.js';
import { graphemeCount } from './booking_requests.js';
import type { DisputeSubjectView } from './dispute_ports.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';
import type { MilestoneKind } from './milestones.js';

export const DISPUTE_SUBJECT_TYPES = ['booking', 'ticket'] as const;
export type DisputeSubjectType = (typeof DISPUTE_SUBJECT_TYPES)[number];

export const DISPUTE_REASONS = [
  'no_show',
  'not_as_agreed',
  'photos_missing',
  'not_as_sample',
  'link_broken',
  'event_not_held',
  'not_as_described',
  'other',
] as const;
export type DisputeReason = (typeof DISPUTE_REASONS)[number];

/** Decision 5: the reasons each subject offers. */
export const REASONS_BY_SUBJECT: Readonly<Record<DisputeSubjectType, readonly DisputeReason[]>> = Object.freeze({
  booking: ['no_show', 'not_as_agreed', 'photos_missing', 'not_as_sample', 'link_broken', 'other'],
  ticket: ['event_not_held', 'not_as_described', 'other'],
});

export const DISPUTE_STATUSES = ['open', 'resolved'] as const;
export type DisputeStatus = (typeof DISPUTE_STATUSES)[number];

export const DISPUTE_OUTCOMES = ['release', 'refund', 'split'] as const;
export type DisputeOutcomeKind = (typeof DISPUTE_OUTCOMES)[number];

export const MAX_DISPUTE_EVIDENCE = 5;
export const DISPUTE_DESCRIPTION_MIN = 10;
export const DISPUTE_DESCRIPTION_MAX = 1000;
export const DISPUTE_NOTE_MIN = 5;
export const DISPUTE_NOTE_MAX = 500;

export interface DisputeSnapshot {
  readonly title: string;
  readonly subtitle: string;
  readonly providerName: string | null;
  readonly thumbUrl: string | null;
}

export interface DisputeOutcome {
  readonly kind: DisputeOutcomeKind;
  readonly refundPercent: number;
  readonly refundAmount: number;
  readonly releaseAmount: number;
  readonly note: string;
  readonly decidedBy: string;
  readonly decidedAt: string;
  readonly refundId: string | null;
}

export interface Dispute {
  readonly id: string;
  readonly subjectType: DisputeSubjectType;
  /** bookingId | registrationId. */
  readonly subjectId: string;
  readonly eventId: string | null;
  readonly paymentId: string;
  readonly customerId: string;
  /** Photographer uid, event host, or `'platform'` for a platform-hosted event. */
  readonly providerId: string;
  /** customerId, plus providerId unless `'platform'`. */
  readonly parties: readonly string[];
  readonly openedBy: 'customer';
  readonly reason: DisputeReason;
  readonly description: string;
  readonly evidencePaths: readonly string[];
  readonly snapshot: DisputeSnapshot;
  /** Integer VND frozen at open: the window's milestone, or what a payment without milestones still held. */
  readonly amountHeld: number;
  readonly status: DisputeStatus;
  readonly outcome: DisputeOutcome | null;
  readonly threadId: string;
  readonly createdAt: string;
  readonly updatedAt: string;
  readonly resolvedAt: string | null;
  readonly version: number;
}

export interface OpenDisputeInput {
  readonly disputeId: string;
  readonly subjectType: DisputeSubjectType;
  readonly subjectId: string;
  readonly eventId: string | null;
  readonly reason: DisputeReason;
  readonly description: string;
  readonly evidencePaths: readonly string[];
}

export interface ResolveDisputeInput {
  readonly disputeId: string;
  readonly kind: DisputeOutcomeKind;
  readonly refundPercent: number | undefined;
  readonly note: string;
}

/** S18.02 `disputePlatformName`: who receives the money of a platform-hosted event. */
export const DISPUTE_PLATFORM_NAME = 'ứng dụng';

/** The payee's name as disputes show it: the snapshot's provider, or the platform's name. */
export const disputeProviderName = (d: Pick<Dispute, 'providerId' | 'snapshot'>): string =>
  d.providerId === 'platform' ? DISPUTE_PLATFORM_NAME : (d.snapshot.providerName ?? DISPUTE_PLATFORM_NAME);

export const disputeThreadId = (disputeId: string): string => `dispute_${disputeId}`;
export const helpThreadId = (uid: string): string => `help_${uid}`;

const isOneOf = <T extends string>(list: readonly T[], v: unknown): v is T =>
  typeof v === 'string' && (list as readonly string[]).includes(v);

const EVIDENCE_FILE = /^[A-Za-z0-9_-]{1,64}\.jpg$/;

function trimmedText(v: unknown, min: number, max: number): string {
  const text = typeof v === 'string' ? v.trim() : '';
  const n = graphemeCount(text);
  if (n < min || n > max) throw new DomainError('invalid_argument');
  return text;
}

/**
 * Throws invalid_argument. Evidence paths must be `disputeEvidence/{uid}/{disputeId}/{fileId}` with
 * fileId `[A-Za-z0-9_-]{1,64}\.jpg` (JPEG only, #147), at most 5, no repeats.
 */
export function parseOpenDisputeInput(raw: unknown, uid: string): OpenDisputeInput {
  if (typeof raw !== 'object' || raw === null) throw new DomainError('invalid_argument');
  const r = raw as Record<string, unknown>;
  if (!isId(r.disputeId) || !isId(r.subjectId) || !isOneOf(DISPUTE_SUBJECT_TYPES, r.subjectType)) {
    throw new DomainError('invalid_argument');
  }
  const subjectType = r.subjectType;
  let eventId: string | null = null;
  if (subjectType === 'ticket') {
    if (!isId(r.eventId)) throw new DomainError('invalid_argument');
    eventId = r.eventId;
  }
  if (!isOneOf(REASONS_BY_SUBJECT[subjectType], r.reason)) throw new DomainError('invalid_argument');
  const description = trimmedText(r.description, DISPUTE_DESCRIPTION_MIN, DISPUTE_DESCRIPTION_MAX);

  const rawPaths = r.evidencePaths ?? [];
  if (!Array.isArray(rawPaths) || rawPaths.length > MAX_DISPUTE_EVIDENCE) throw new DomainError('invalid_argument');
  const prefix = `disputeEvidence/${uid}/${r.disputeId}/`;
  const evidencePaths = rawPaths.map((p: unknown) => {
    if (typeof p !== 'string' || !p.startsWith(prefix) || !EVIDENCE_FILE.test(p.slice(prefix.length))) {
      throw new DomainError('invalid_argument');
    }
    return p;
  });
  if (new Set(evidencePaths).size !== evidencePaths.length) throw new DomainError('invalid_argument');

  return { disputeId: r.disputeId, subjectType, subjectId: r.subjectId, eventId, reason: r.reason, description, evidencePaths };
}

/** `{disputeId, outcome, refundPercent?, note}` (staff). The percent itself is checked by `outcomeAmounts`. */
export function parseResolveDisputeInput(raw: unknown): ResolveDisputeInput {
  if (typeof raw !== 'object' || raw === null) throw new DomainError('invalid_argument');
  const r = raw as Record<string, unknown>;
  if (!isId(r.disputeId) || !isOneOf(DISPUTE_OUTCOMES, r.outcome)) throw new DomainError('invalid_argument');
  const pct = r.refundPercent;
  if (pct !== undefined && pct !== null && typeof pct !== 'number') throw new DomainError('invalid_argument');
  const note = trimmedText(r.note, DISPUTE_NOTE_MIN, DISPUTE_NOTE_MAX);
  return { disputeId: r.disputeId, kind: r.outcome, refundPercent: typeof pct === 'number' ? pct : undefined, note };
}

const HOUR_MS = 3_600_000;
const plusHours = (d: Date, h: number): Date => new Date(d.getTime() + h * HOUR_MS);

/**
 * The window of a subject (Decision 2): booking `shooting` (S30: scanned, not marked done) → any time while
 * it lasts, and an `upcoming` booking whose customer denied the shoot (`shootDeniedAt`, the preset reason
 * "Buổi chụp không diễn ra") → any time: milestones are split only at `shot`, so both freeze the whole
 * held payment (`closesAt` rolls with now); booking `shot` → shotAt + 24 h (milestone `shoot`);
 * `approved` → checkUntil (milestone `delivery`); `completed|reviewed` whose payment has no milestones
 * (before #152) → completedAt (`windowStart`) + 24 h; paid ticket → from endAt (`windowStart`) to + 24 h.
 * `hasMilestones`: the subject's payment carries #152's milestones (only the use case knows it).
 * Throws not_eligible (state, nothing held, before the window) or deadline_passed (now >= closesAt).
 */
export function disputeWindow(
  subject: DisputeSubjectView,
  now: Date,
  hasMilestones: boolean,
): { readonly closesAt: Date; readonly milestone: MilestoneKind | null } {
  let closesAt: Date;
  let milestone: MilestoneKind | null = null;
  if (subject.type === 'ticket') {
    if (subject.state !== 'paid' || subject.amount <= 0 || subject.windowStart === null) {
      throw new DomainError('not_eligible');
    }
    if (now.getTime() < subject.windowStart.getTime()) throw new DomainError('not_eligible');
    closesAt = plusHours(subject.windowStart, DISPUTE_WINDOW_HOURS);
  } else if (subject.state === 'shooting' || (subject.state === 'upcoming' && (subject.shootDeniedAt ?? null) !== null)) {
    closesAt = plusHours(now, DISPUTE_WINDOW_HOURS);
  } else if (subject.state === 'shot' && subject.shotAt !== null) {
    closesAt = plusHours(subject.shotAt, DISPUTE_WINDOW_HOURS);
    milestone = 'shoot';
  } else if (subject.state === 'approved' && subject.checkUntil !== null) {
    closesAt = subject.checkUntil;
    milestone = 'delivery';
  } else if ((subject.state === 'completed' || subject.state === 'reviewed') && !hasMilestones && subject.windowStart !== null) {
    closesAt = plusHours(subject.windowStart, DISPUTE_WINDOW_HOURS);
  } else {
    // Includes `completed` with milestones: the delivery milestone was released on completion.
    throw new DomainError('not_eligible');
  }
  if (now.getTime() >= closesAt.getTime()) throw new DomainError('deadline_passed');
  return { closesAt, milestone };
}

/**
 * Decision 7: `release` refunds 0 %, `refund` 100 %, `split` an integer 1–99 % of `heldAmount`;
 * refundAmount = ⌊held × pct / 100⌋, releaseAmount = held − refundAmount.
 * Throws invalid_argument (split outside 1–99 or not an integer, a percent given for release/refund).
 */
export function outcomeAmounts(
  heldAmount: number,
  kind: DisputeOutcomeKind,
  refundPercent?: number,
): { readonly refundPercent: number; readonly refundAmount: number; readonly releaseAmount: number } {
  if (!Number.isSafeInteger(heldAmount) || heldAmount < 0) throw new DomainError('invalid_argument');
  let pct: number;
  if (kind === 'split') {
    if (refundPercent === undefined || !Number.isInteger(refundPercent) || refundPercent < 1 || refundPercent > 99) {
      throw new DomainError('invalid_argument');
    }
    pct = refundPercent;
  } else {
    if (refundPercent !== undefined) throw new DomainError('invalid_argument');
    pct = kind === 'refund' ? 100 : 0;
  }
  const refundAmount = Math.floor((heldAmount * pct) / 100);
  return { refundPercent: pct, refundAmount, releaseAmount: heldAmount - refundAmount };
}
