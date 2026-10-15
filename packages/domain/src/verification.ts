import type { ProviderType } from './provider_type.js';

export const VERIFICATION_STATUSES = ['not_started', 'in_progress', 'submitted', 'approved', 'rejected', 'revoked'] as const;
export type VerificationStatus = (typeof VERIFICATION_STATUSES)[number];

export type VerificationKind = 'individual' | 'studio';
export type VerificationStep = 'phone' | 'fee' | 'identity' | 'rules';
export type IdentityMethod = 'vneid' | 'nfc';

export const VERIFICATION_FEE_VND: Readonly<Record<VerificationKind, number>> = {
  individual: 99_000,
  studio: 299_000,
};

export const FREE_RESUBMITS = 1;
export const IDENTITY_ATTEMPTS_PER_DAY = 3;
export const MIN_PROVIDER_AGE_YEARS = 18;
export const REVIEW_SLA_HOURS = 24;
export const VERIFICATION_NUDGE_AFTER_HOURS = 24;
export const BUSINESS_DOC_RETENTION_DAYS = 30;

export const PROVIDER_RULES_VERSION = '2026-10-06';

export const REJECT_REASONS = [
  'fake_avatar',
  'stolen_portfolio',
  'identity_mismatch',
  'duplicate_account',
  'underage',
  'other',
] as const;
export type RejectReason = (typeof REJECT_REASONS)[number];

export const RESUBMITTABLE_REASONS = [
  'fake_avatar',
  'stolen_portfolio',
  'identity_mismatch',
  'other',
] as const;

export const BUSINESS_REJECT_REASONS = [
  'inactive',
  'representative_mismatch',
  'doc_unreadable',
  'other',
] as const;
export type BusinessRejectReason = (typeof BUSINESS_REJECT_REASONS)[number];

export interface PhoneStepRecord {
  readonly doneAt: string;
}

export interface FeeStepRecord {
  readonly paymentId: string;
  readonly amount: number;
  readonly paidAt: string;
}

export interface IdentityStepRecord {
  readonly method: IdentityMethod;
  readonly checkedAt: string;
  readonly result: 'passed' | 'failed';
  readonly failure: 'underage' | 'identity_in_use' | 'provider_failed' | null;
  readonly maskedName: string | null;
}

export interface RulesStepRecord {
  readonly acceptedAt: string;
  readonly version: string;
}

export interface IdentitySessionRecord {
  readonly id: string;
  readonly method: IdentityMethod;
  readonly startedAt: string;
}

export interface IdentityAttemptsRecord {
  readonly dayKey: string;
  readonly count: number;
}

export interface RejectReasonRecord {
  readonly code: RejectReason;
  readonly text: string | null;
}

export interface BusinessRejectReasonRecord {
  readonly code: BusinessRejectReason;
  readonly text: string | null;
}

export interface BusinessVerificationRecord {
  readonly status: 'submitted' | 'approved' | 'rejected';
  readonly kind: 'company' | 'household';
  readonly taxCode: string;
  readonly name: string;
  readonly address: string;
  readonly registryStatus: 'active' | 'inactive';
  readonly docPath: string | null;
  readonly representativeMatched: boolean;
  readonly submittedAt: string;
  readonly decidedAt: string | null;
  readonly decidedBy: string | null;
  readonly rejectReason: BusinessRejectReasonRecord | null;
  readonly purgeAfter: string | null;
}

export interface VerificationSteps {
  readonly phone: PhoneStepRecord | null;
  readonly fee: FeeStepRecord | null;
  readonly identity: IdentityStepRecord | null;
  readonly rules: RulesStepRecord | null;
}

export interface VerificationRecord {
  readonly uid: string;
  readonly kind: VerificationKind;
  readonly status: VerificationStatus;
  readonly steps: VerificationSteps;
  readonly identitySession: IdentitySessionRecord | null;
  readonly identityAttempts: IdentityAttemptsRecord;
  readonly feeAttempt: number;
  readonly submittedAt: string | null;
  readonly decidedAt: string | null;
  readonly decidedBy: string | null;
  readonly rejectReason: RejectReasonRecord | null;
  readonly freeResubmitsLeft: number;
  readonly nudgedAt: string | null;
  readonly business: BusinessVerificationRecord | null;
  readonly version: number;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export interface IdentityRecord {
  readonly legalName: string;
  readonly dob: string;
  readonly gender: 'male' | 'female' | null;
  readonly idNumberEnc: string;
  readonly idHash: string;
  readonly method: IdentityMethod;
  readonly provider: string;
  readonly providerRef: string;
  readonly verifiedAt: string;
}

export function verificationKindOf(t: ProviderType): VerificationKind {
  return t === 'studio' ? 'studio' : 'individual';
}

export function feeFor(kind: VerificationKind): number {
  return VERIFICATION_FEE_VND[kind];
}

export function vnDayKey(now: Date): string {
  // VN timezone is UTC+7
  const vnTime = new Date(now.getTime() + 7 * 60 * 60 * 1000);
  const year = vnTime.getUTCFullYear();
  const month = String(vnTime.getUTCMonth() + 1).padStart(2, '0');
  const day = String(vnTime.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function emptyVerification(uid: string, kind: VerificationKind, now: Date): VerificationRecord {
  const at = now.toISOString();
  return {
    uid,
    kind,
    status: 'not_started',
    steps: {
      phone: null,
      fee: null,
      identity: null,
      rules: null,
    },
    identitySession: null,
    identityAttempts: {
      dayKey: vnDayKey(now),
      count: 0,
    },
    feeAttempt: 1,
    submittedAt: null,
    decidedAt: null,
    decidedBy: null,
    rejectReason: null,
    freeResubmitsLeft: FREE_RESUBMITS,
    nudgedAt: null,
    business: null,
    version: 1,
    createdAt: at,
    updatedAt: at,
  };
}

export function requiredSteps(feeRequired: boolean): readonly VerificationStep[] {
  return feeRequired ? ['phone', 'fee', 'identity', 'rules'] : ['phone', 'identity', 'rules'];
}

export function stepDone(r: VerificationRecord, s: VerificationStep, phoneVerified: boolean): boolean {
  switch (s) {
    case 'phone':
      // Decision 3: the contact flag is the step; steps.phone only mirrors it,
      // and a number change resets the flag, so the step shows undone again.
      return phoneVerified;
    case 'fee':
      return r.steps.fee !== null;
    case 'identity':
      return r.steps.identity !== null && r.steps.identity.result === 'passed';
    case 'rules':
      return r.steps.rules !== null;
  }
}

export function nextStep(r: VerificationRecord, phoneVerified: boolean, feeRequired: boolean): VerificationStep | null {
  const req = requiredSteps(feeRequired);
  for (const s of req) {
    if (!stepDone(r, s, phoneVerified)) {
      return s;
    }
  }
  return null;
}

export function stepsLeft(r: VerificationRecord, phoneVerified: boolean, feeRequired: boolean): number {
  const req = requiredSteps(feeRequired);
  let count = 0;
  for (const s of req) {
    if (!stepDone(r, s, phoneVerified)) {
      count++;
    }
  }
  return count;
}

/**
 * Whole years on the VN calendar day (UTC+7).
 * dob is 'yyyy-MM-dd'.
 */
export function ageOn(dob: string, now: Date): number {
  const parts = dob.split('-').map(Number);
  const bYear = parts[0] ?? 0;
  const bMonth = parts[1] ?? 1;
  const bDay = parts[2] ?? 1;
  const vnTime = new Date(now.getTime() + 7 * 60 * 60 * 1000);
  const cYear = vnTime.getUTCFullYear();
  const cMonth = vnTime.getUTCMonth() + 1;
  const cDay = vnTime.getUTCDate();

  let age = cYear - bYear;
  if (cMonth < bMonth || (cMonth === bMonth && cDay < bDay)) {
    age--;
  }
  return age;
}

/**
 * 'NGUYỄN MINH TRÍ' → 'NGUYỄN M** T**'
 * First word whole, each later word first letter + '**'
 */
export function maskLegalName(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length <= 1) return name.trim();
  const [first, ...rest] = parts;
  const maskedRest = rest.map((w) => `${w[0]}**`);
  return [first, ...maskedRest].join(' ');
}

export function identityAttemptsLeft(r: VerificationRecord, now: Date): number {
  const currentKey = vnDayKey(now);
  if (r.identityAttempts.dayKey !== currentKey) {
    return IDENTITY_ATTEMPTS_PER_DAY;
  }
  return Math.max(0, IDENTITY_ATTEMPTS_PER_DAY - r.identityAttempts.count);
}
