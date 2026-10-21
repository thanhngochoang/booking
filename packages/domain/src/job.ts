import { DomainError } from './errors.js';
import { findContactLeak } from './contact_filter.js';
import { foldVietnamese } from './event_hashtag.js';
import { formatVnDate, isDateString, isTimeString, parseVnDateTime } from './booking_policy.js';

export const JOB_STATUSES = ['draft', 'open', 'awarded', 'expired', 'closed'] as const;
export const QUOTE_STATUSES = ['submitted', 'withdrawn', 'accepted', 'not_selected', 'declined'] as const;
export const ALLOWED_PROVIDERS = ['all', 'artist', 'studio'] as const;
export const SCHEDULE_KINDS = ['fixed', 'flexible'] as const;
export const JOB_SPECIALTY_OTHER = 'other';

export const JOB_TITLE_MIN = 10;
export const JOB_TITLE_MAX = 60;
export const JOB_DESC_MAX = 1000;
export const JOB_REFERENCES_MAX = 5;
export const JOB_DEADLINE_DAYS_MIN = 1;
export const JOB_DEADLINE_DAYS_MAX = 7;
export const JOB_DEADLINE_DAYS_DEFAULT = 3;
export const JOB_EXTEND_DAYS = 7;
export const JOB_FLEX_RANGE_MAX_DAYS = 30;
export const JOB_DURATIONS = [60, 120, 180, 240, 360, 480] as const;

export const OPEN_JOBS_PER_CUSTOMER = 3;
export const OPEN_QUOTES_PER_PHOTOGRAPHER = 20;
export const INVITES_PER_JOB = 5;
export const MATCHES_PER_JOB = 30;
export const MATCH_SCAN_LIMIT = 200;
export const MATCH_AVAILABILITY_READS = 40;

export const QUOTE_MESSAGE_MIN = 20;
export const QUOTE_MESSAGE_MAX = 500;
export const QUOTE_PRICE_MAX = 1_000_000_000;
export const QUOTE_REVISIONS_MAX = 5;
export const QUOTE_DELIVERY_DAYS_MIN = 1;
export const QUOTE_DELIVERY_DAYS_MAX = 60;
export const QUOTE_COUNT_MAX = 2000;

export const JOB_EXPIRING_NOTICE_HOURS = 24;
export const JOB_REFERENCES_RETENTION_DAYS = 30;

export type JobStatus = (typeof JOB_STATUSES)[number];
export type QuoteStatus = (typeof QUOTE_STATUSES)[number];
export type AllowedProviders = (typeof ALLOWED_PROVIDERS)[number];
export type ScheduleKind = (typeof SCHEDULE_KINDS)[number];

export interface JobSchedule {
  readonly kind: ScheduleKind;
  readonly day: string | null;
  readonly start: string | null;
  readonly end: string | null;
  readonly from: string | null;
  readonly to: string | null;
  readonly durationMinutes: number;
}

export interface JobArea {
  readonly areaId: string;
  readonly name: string;
  readonly city: string;
  readonly cityKey: string;
  readonly lat: number;
  readonly lng: number;
  readonly geohash5: string;
}

export interface JobReference {
  readonly url: string;
  readonly path: string;
}

export interface JobCustomer {
  readonly name: string;
  readonly avatarUrl: string | null;
  readonly hireCount: number;
  readonly phoneVerified: boolean;
}

export interface JobBudget {
  readonly min: number;
  readonly max: number;
}

export interface JobWants {
  readonly editedCount: number | null;
  readonly deliveryDays: number | null;
}

export interface JobCheckout {
  readonly quoteId: string;
  readonly bookingId: string;
  readonly expiresAt: Date;
}

export interface JobRecord {
  readonly id: string;
  readonly customerId: string;
  readonly customer: JobCustomer;
  readonly specialtyId: string;
  readonly title: string;
  readonly description: string;
  readonly references: readonly JobReference[];
  readonly schedule: JobSchedule;
  readonly dayFrom: string;
  readonly dayTo: string;
  readonly area: JobArea;
  readonly budget: JobBudget | null;
  readonly wants: JobWants;
  readonly allowedProviders: AllowedProviders;
  readonly quoteDeadline: Date;
  readonly extended: boolean;
  readonly status: JobStatus;
  readonly quoteCount: number;
  readonly newQuoteCount: number;
  readonly viewCount: number;
  readonly inviteCount: number;
  readonly matchCount: number;
  readonly recentQuoters: readonly { readonly photographerId: string; readonly avatarUrl: string | null }[];
  readonly awardedQuoteId: string | null;
  readonly bookingId: string | null;
  readonly awardedTo: { readonly photographerId: string; readonly name: string; readonly price: number } | null;
  readonly checkout: JobCheckout | null;
  readonly expiringNotifiedAt: Date | null;
  readonly closedAt: Date | null;
  readonly referencesPurgeAfter: Date | null;
  readonly quotesSeenAt: Date | null;
  readonly version: number;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface BookingTerms {
  readonly price: number;
  readonly durationMinutes: number;
  readonly photoCount: number | null;
  readonly editedCount: number;
  readonly deliveryDays: number;
  readonly revisions: number;
  readonly milestones: readonly { readonly kind: 'shoot' | 'delivery'; readonly percent: number }[];
}

export interface QuoteRecord {
  readonly id: string; // photographerId
  readonly jobId: string;
  readonly photographerId: string;
  readonly customerId: string;
  readonly jobTitle: string;
  readonly photographer: {
    readonly name: string;
    readonly avatarUrl: string | null;
    readonly providerType: string;
    readonly verified: boolean;
    readonly tomatoPct: number;
    readonly score: number;
    readonly reviewCount: number;
    readonly completedCount: number;
    readonly approvedAwardCount: number;
    readonly studioDistrict: string | null;
  };
  readonly basedOnServiceId: string | null;
  readonly terms: BookingTerms;
  readonly milestoneAmounts: { readonly shoot: number; readonly delivery: number };
  readonly proposal: { readonly day: string; readonly start: string; readonly end: string };
  readonly message: string;
  readonly albumId: string | null;
  readonly album: { readonly title: string; readonly coverUrl: string | null; readonly postCount: number } | null;
  readonly invited: boolean;
  readonly fit: number;
  readonly status: QuoteStatus;
  readonly notSelectedReason: 'awarded' | 'expired' | 'closed' | null;
  readonly autoWithdrawn: boolean;
  readonly declineReason: string | null;
  readonly bookingId: string | null;
  readonly withdrawnAt: Date | null;
  readonly version: number;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface JobInviteRecord {
  readonly id: string; // photographerId
  readonly jobId: string;
  readonly photographerId: string;
  readonly customerId: string;
  readonly fit: number;
  readonly jobStatus: 'open' | 'closed';
  readonly createdAt: Date;
  readonly seenAt: Date | null;
}

export interface JobMatchRecord {
  readonly id: string; // photographerId
  readonly jobId: string;
  readonly photographerId: string;
  readonly fit: number;
  readonly jobStatus: 'open' | 'closed';
  readonly createdAt: Date;
}

export function cityOf(areaName: string): string {
  const parts = areaName.split(', ');
  return parts.length > 1 ? parts[parts.length - 1].trim() : areaName.trim();
}

export function cityKeyOf(s: string): string {
  const folded = foldVietnamese(s).toLowerCase();
  return folded.replace(/[^a-z0-9]/g, '');
}

export function deadlinePassed(job: Pick<JobRecord, 'quoteDeadline'>, now: Date): boolean {
  return now.getTime() >= job.quoteDeadline.getTime();
}

export function checkoutActive(job: Pick<JobRecord, 'checkout'>, now: Date): boolean {
  return job.checkout !== null && now.getTime() < job.checkout.expiresAt.getTime();
}

export interface JobFields {
  readonly specialtyId: string;
  readonly title: string;
  readonly description: string;
  readonly references: readonly JobReference[];
  readonly schedule: JobSchedule;
  readonly dayFrom: string;
  readonly dayTo: string;
  readonly area: JobArea;
  readonly budget: JobBudget | null;
  readonly wants: JobWants;
  readonly allowedProviders: AllowedProviders;
  readonly deadlineDays: number;
  readonly quoteDeadline: Date;
}

// Built-in taxonomy specialties for validation parity
const SPECIALTIES = [
  'portrait',
  'graduation',
  'wedding',
  'event',
  'family',
  'couple',
  'product',
  'food',
  'fashion',
  'interior',
  'other',
] as const;

export function validateJobInput(raw: unknown, now: Date): JobFields {
  if (typeof raw !== 'object' || raw === null) {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;

  // Title
  if (typeof r.title !== 'string') throw new DomainError('invalid_argument', 'title');
  const title = r.title.trim();
  if (title.length < JOB_TITLE_MIN || title.length > JOB_TITLE_MAX) {
    throw new DomainError('invalid_argument', 'title');
  }
  const titleLeak = findContactLeak(title);
  if (titleLeak) throw new DomainError('invalid_argument', 'title.contact');

  // Description
  const description = typeof r.description === 'string' ? r.description.trim() : '';
  if (description.length > JOB_DESC_MAX) {
    throw new DomainError('invalid_argument', 'description');
  }
  const descLeak = findContactLeak(description);
  if (descLeak) throw new DomainError('invalid_argument', 'description.contact');

  // Specialty
  if (typeof r.specialtyId !== 'string' || (!SPECIALTIES.includes(r.specialtyId as (typeof SPECIALTIES)[number]) && r.specialtyId !== 'other')) {
    throw new DomainError('invalid_argument', 'specialtyId');
  }
  const specialtyId = r.specialtyId;

  // References
  const references: JobReference[] = [];
  if (Array.isArray(r.references)) {
    if (r.references.length > JOB_REFERENCES_MAX) {
      throw new DomainError('invalid_argument', 'references');
    }
    for (const ref of r.references) {
      if (typeof ref?.url !== 'string' || typeof ref?.path !== 'string') {
        throw new DomainError('invalid_argument', 'references');
      }
      references.push({ url: ref.url, path: ref.path });
    }
  }

  // Deadline days
  const deadlineDays = typeof r.deadlineDays === 'number' ? r.deadlineDays : JOB_DEADLINE_DAYS_DEFAULT;
  if (!Number.isInteger(deadlineDays) || deadlineDays < JOB_DEADLINE_DAYS_MIN || deadlineDays > JOB_DEADLINE_DAYS_MAX) {
    throw new DomainError('invalid_argument', 'deadlineDays');
  }
  const quoteDeadline = new Date(now.getTime() + deadlineDays * 24 * 60 * 60 * 1000);
  const deadlineVnDate = formatVnDate(quoteDeadline);

  // Schedule
  const s = r.schedule as Record<string, unknown> | null | undefined;
  if (typeof s !== 'object' || s === null) throw new DomainError('invalid_argument', 'schedule');
  let schedule: JobSchedule;
  let dayFrom: string;
  let dayTo: string;

  if (s.kind === 'fixed') {
    if (!isDateString(s.day) || !isTimeString(s.start) || !isTimeString(s.end)) {
      throw new DomainError('invalid_argument', 'schedule');
    }
    const [startH, startM] = s.start.split(':').map(Number);
    const [endH, endM] = s.end.split(':').map(Number);
    const startMins = startH * 60 + startM;
    const endMins = endH * 60 + endM;
    if (endMins <= startMins) {
      throw new DomainError('invalid_argument', 'schedule');
    }
    const durationMinutes = endMins - startMins;
    dayFrom = s.day;
    dayTo = s.day;
    schedule = {
      kind: 'fixed',
      day: s.day,
      start: s.start,
      end: s.end,
      from: null,
      to: null,
      durationMinutes,
    };
  } else if (s.kind === 'flexible') {
    if (!isDateString(s.from) || !isDateString(s.to) || typeof s.durationMinutes !== 'number' || !JOB_DURATIONS.includes(s.durationMinutes as (typeof JOB_DURATIONS)[number])) {
      throw new DomainError('invalid_argument', 'schedule');
    }
    const fromTime = parseVnDateTime(s.from, '00:00').getTime();
    const toTime = parseVnDateTime(s.to, '00:00').getTime();
    if (toTime < fromTime) {
      throw new DomainError('invalid_argument', 'schedule');
    }
    const diffDays = Math.round((toTime - fromTime) / (24 * 60 * 60 * 1000));
    if (diffDays > JOB_FLEX_RANGE_MAX_DAYS) {
      throw new DomainError('invalid_argument', 'schedule');
    }
    dayFrom = s.from;
    dayTo = s.to;
    schedule = {
      kind: 'flexible',
      day: null,
      start: null,
      end: null,
      from: s.from,
      to: s.to,
      durationMinutes: s.durationMinutes,
    };
  } else {
    throw new DomainError('invalid_argument', 'schedule');
  }

  // Shoot day after quote deadline date & at most 365 days ahead
  if (dayFrom <= deadlineVnDate) {
    throw new DomainError('invalid_argument', 'schedule');
  }
  const maxShootDate = formatVnDate(new Date(now.getTime() + 365 * 24 * 60 * 60 * 1000));
  if (dayFrom > maxShootDate) {
    throw new DomainError('invalid_argument', 'schedule');
  }

  // Area
  const a = r.area as Record<string, unknown> | null | undefined;
  if (typeof a !== 'object' || a === null || typeof a.name !== 'string' || typeof a.lat !== 'number' || typeof a.lng !== 'number') {
    throw new DomainError('invalid_argument', 'area');
  }
  if (a.lat < 8 || a.lat > 24 || a.lng < 102 || a.lng > 110) {
    throw new DomainError('invalid_argument', 'area');
  }
  const areaName = a.name.trim();
  const city = typeof a.city === 'string' ? a.city : cityOf(areaName);
  const cityKey = typeof a.cityKey === 'string' ? a.cityKey : cityKeyOf(city);
  const area: JobArea = {
    areaId: typeof a.areaId === 'string' ? a.areaId : 'area',
    name: areaName,
    city,
    cityKey,
    lat: a.lat,
    lng: a.lng,
    geohash5: typeof a.geohash5 === 'string' ? a.geohash5 : '',
  };

  // Budget
  let budget: JobBudget | null = null;
  if (r.budget !== null && r.budget !== undefined) {
    const b = r.budget as Record<string, unknown>;
    if (
      typeof b !== 'object' ||
      typeof b.min !== 'number' ||
      typeof b.max !== 'number' ||
      !Number.isInteger(b.min) ||
      !Number.isInteger(b.max) ||
      b.min <= 0 ||
      b.min > b.max ||
      b.max > 1_000_000_000
    ) {
      throw new DomainError('invalid_argument', 'budget');
    }
    budget = { min: b.min, max: b.max };
  }

  // Wants
  const w = (r.wants ?? {}) as Record<string, unknown>;
  const wants: JobWants = {
    editedCount: typeof w.editedCount === 'number' && Number.isInteger(w.editedCount) && w.editedCount >= 1 && w.editedCount <= 2000 ? w.editedCount : null,
    deliveryDays: typeof w.deliveryDays === 'number' && Number.isInteger(w.deliveryDays) && w.deliveryDays >= 1 && w.deliveryDays <= 60 ? w.deliveryDays : null,
  };

  // Allowed providers
  const allowed = r.allowedProviders as AllowedProviders;
  if (!ALLOWED_PROVIDERS.includes(allowed)) {
    throw new DomainError('invalid_argument', 'allowedProviders');
  }

  return {
    specialtyId,
    title,
    description,
    references,
    schedule,
    dayFrom,
    dayTo,
    area,
    budget,
    wants,
    allowedProviders: allowed,
    deadlineDays,
    quoteDeadline,
  };
}
