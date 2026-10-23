import type { Clock, IdGenerator, UserContactReader } from './ports.js';
import type { OrderGateDeps } from './order_gate.js';
import type {
  JobRecord,
  QuoteRecord,
  JobInviteRecord,
  JobMatchRecord,
} from './job.js';
import type { JobProviderProfile } from './job_eligibility.js';

export interface JobTx {
  getJob(id: string): Promise<JobRecord | null>;
  getQuote(jobId: string, photographerId: string): Promise<QuoteRecord | null>;
  getInvite(jobId: string, photographerId: string): Promise<JobInviteRecord | null>;
  listQuotes(jobId: string): Promise<QuoteRecord[]>; // all statuses, ≤ 100
  listInvites(jobId: string): Promise<JobInviteRecord[]>;
  listMatches(jobId: string): Promise<JobMatchRecord[]>;
  putJob(j: JobRecord): void;
  putQuote(q: QuoteRecord): void;
  putInvite(i: JobInviteRecord): void;
  putMatch(m: JobMatchRecord): void;
}

export interface JobStore {
  runTransaction<T>(fn: (tx: JobTx) => Promise<T>): Promise<T>;
  countOpenJobs(customerId: string): Promise<number>;
  countSubmittedQuotes(photographerId: string): Promise<number>;
  submittedQuotesOnDay(photographerId: string, day: string): Promise<QuoteRecord[]>; // collection group
  dueForExpiry(now: Date, limit: number): Promise<JobRecord[]>; // open, quoteDeadline <= now
  dueForExpiringNotice(now: Date, limit: number): Promise<JobRecord[]>; // open, expiringNotifiedAt null, quoteDeadline <= now + 24 h
  dueForReferencePurge(now: Date, limit: number): Promise<JobRecord[]>; // referencesPurgeAfter <= now
}

export interface JobPeople {
  customer(
    uid: string,
  ): Promise<{
    role: string | null;
    name: string;
    avatarUrl: string | null;
    phoneVerified: boolean;
    hireCount: number;
  } | null>;
  provider(uid: string): Promise<JobProviderProfile | null>;
  candidates(specialtyId: string, limit: number): Promise<JobProviderProfile[]>;
  dayState(photographerId: string, day: string): Promise<'free' | 'pending' | 'booked' | 'off'>;
  dayBookingId(photographerId: string, day: string): Promise<string | null>;
  service(
    photographerId: string,
    serviceId: string,
  ): Promise<{
    active: boolean;
    photoCount: number | null;
    editedCount: number | null;
    deliveryDays: number | null;
    price: number;
  } | null>;
  album(
    albumId: string,
  ): Promise<{
    photographerId: string;
    title: string;
    coverUrl: string | null;
    postCount: number;
  } | null>;
}

export interface JobMedia {
  isOwnReference(url: string, path: string, uid: string): boolean;
  deleteReference(path: string): Promise<void>;
}

export interface JobDeps extends OrderGateDeps {
  readonly jobs: JobStore;
  readonly people: JobPeople;
  readonly contacts: UserContactReader;
  readonly media: JobMedia;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}
