/**
 * S27 collab jobs (spec 2026-10-07-studio-recruiting-design.md §5–§6; plan #151 Decisions 3, 13–15, 18):
 * a studio booking offered to a collaborator. The agreed fee, the offer state and the off-app pay record live
 * only in `collab_jobs/{bookingId}_{collaboratorId}` (studio and that collaborator read it), never on the
 * booking the customer reads. The pay record only records "Đã trả / Đã nhận": no money moves (R5).
 * The offer use cases are S26's (`studio_assignment.ts`); the pay use cases are here.
 */

import type { Booking } from './booking.js';
import { bookingContactUnlocked } from './contact.js';
import type { Payment } from './escrow.js';
import { notifyCollabPayDisputed, notifyCollabPayReported } from './notification_hooks.js';
import type { RecruitCounters } from './recruit.js';
import type { RecruitDeps } from './recruit_ports.js';
import { fail, idOf, objectOf, safely } from './recruit_shared.js';
import { vnDayKey } from './verification.js';

export const OFFER_HOURS = 6,
  OFFER_MIN_MINUTES = 15,
  PAY_OVERDUE_DAYS = 7,
  UNPAID_FLAGS_TO_BLOCK = 3,
  UNPAID_WINDOW_DAYS = 90,
  RECRUIT_BLOCK_DAYS = 30,
  CONTACT_CLOSE_DAYS = 7,
  POACH_WINDOW_DAYS = 183,
  POACH_THRESHOLD = 2;

export const OFFER_STATUSES = ['pending', 'accepted', 'declined', 'expired', 'replaced', 'returned', 'cancelled'] as const;
export type OfferStatus = (typeof OFFER_STATUSES)[number];
export const COLLAB_PAY_STATUSES = ['none', 'due', 'paid_reported', 'received', 'disputed'] as const;
export type CollabPayStatus = (typeof COLLAB_PAY_STATUSES)[number];
export const COLLAB_PAY_METHODS = ['bank', 'cash', 'other'] as const;
export type CollabPayMethod = (typeof COLLAB_PAY_METHODS)[number];

/** The shoot as the collaborator sees it in S27.07: no customer contact. */
export interface CollabJobShoot {
  readonly day: string;
  readonly start: string;
  readonly end: string;
  readonly serviceName: string;
  readonly placeName: string;
}

export interface CollabPay {
  /** Integer VND, = agreedFee. */
  readonly amount: number;
  /** When the booking's shoot milestone was released to the studio (`due` from then on). */
  readonly dueAt: Date | null;
  /** Studio "Đã trả": the day it says it paid (`yyyy-MM-dd`, Vietnam) and how. */
  readonly paidOn: string | null;
  readonly method: CollabPayMethod | null;
  readonly reportedAt: Date | null;
  readonly receivedAt: Date | null;
  readonly disputedAt: Date | null;
  /** Each reason adds one unpaid flag to the studio, once per job (Decision 15). */
  readonly overdueFlaggedAt: Date | null;
  readonly disputeFlaggedAt: Date | null;
}

/** `collab_jobs/{bookingId}_{collaboratorId}`. */
export interface CollabJob {
  readonly id: string;
  readonly bookingId: string;
  readonly studioId: string;
  readonly collaboratorId: string;
  readonly customerId: string;
  readonly studioName: string;
  readonly collaboratorName: string;
  readonly shoot: CollabJobShoot;
  readonly shootEndsAt: Date;
  readonly agreedFee: number;
  readonly offerStatus: OfferStatus;
  readonly offerAt: Date;
  readonly offerExpiresAt: Date;
  readonly acceptedAt: Date | null;
  readonly declinedAt: Date | null;
  /** When the booking was completed or cancelled. */
  readonly closedAt: Date | null;
  readonly payStatus: CollabPayStatus;
  readonly pay: CollabPay;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export const collabJobId = (bookingId: string, collaboratorId: string): string => `${bookingId}_${collaboratorId}`;

const MINUTE_MS = 60 * 1000;
const HOUR_MS = 60 * MINUTE_MS;
const DAY_MS = 24 * HOUR_MS;

/**
 * Who holds a studio booking: its assignee, except a collaborator whose offer is still waiting (S27: no
 * calendar block, chat membership, customer notice or actions until accepted). Null = nobody yet.
 */
export function confirmedAssigneeId(
  b: Pick<Booking, 'assigneeId'> & Partial<Pick<Booking, 'assigneeKind' | 'assigneeAccepted'>>,
): string | null {
  const id = b.assigneeId ?? null;
  if (id === null) return null;
  return b.assigneeKind === 'collaborator' && b.assigneeAccepted !== true ? null : id;
}

/** A job still waiting for an answer or accepted: what replacing, returning or a booking close acts on. */
export const isLiveOffer = (j: Pick<CollabJob, 'offerStatus'>): boolean =>
  j.offerStatus === 'pending' || j.offerStatus === 'accepted';

/**
 * A job that keeps the collaboration from ending (spec §4 "còn booking được giao chưa xong, hoặc đang khiếu
 * nại"): a live offer of a booking not yet completed or cancelled, or a pay record the collaborator disputes.
 */
export const isOpenCollabJob = (j: Pick<CollabJob, 'offerStatus' | 'closedAt' | 'payStatus'>): boolean =>
  (isLiveOffer(j) && j.closedAt === null) || j.payStatus === 'disputed';

/**
 * When an offer made now lapses (Decision 13): 6 hours, never after `assignDeadline` (or, once the deadline
 * passed, never after the start). Null when that leaves less than 15 minutes: assign a member instead.
 */
export function offerExpiry(now: Date, assignDeadline: Date, startAt: Date): Date | null {
  const cap = now.getTime() < assignDeadline.getTime() ? assignDeadline : startAt;
  const at = Math.min(now.getTime() + OFFER_HOURS * HOUR_MS, cap.getTime());
  return at - now.getTime() < OFFER_MIN_MINUTES * MINUTE_MS ? null : new Date(at);
}

/** The pending job of an offer (Decision 13). */
export function newCollabJob(input: {
  readonly booking: Pick<Booking, 'id' | 'photographerId' | 'customerId' | 'day' | 'start' | 'end' | 'serviceSnapshot' | 'place'>;
  readonly collaboratorId: string;
  readonly studioName: string;
  readonly collaboratorName: string;
  readonly shootEndsAt: Date;
  readonly agreedFee: number;
  readonly offerExpiresAt: Date;
  readonly now: Date;
}): CollabJob {
  const { booking: b, now } = input;
  return {
    id: collabJobId(b.id, input.collaboratorId),
    bookingId: b.id,
    studioId: b.photographerId,
    collaboratorId: input.collaboratorId,
    customerId: b.customerId,
    studioName: input.studioName,
    collaboratorName: input.collaboratorName,
    shoot: { day: b.day, start: b.start, end: b.end, serviceName: b.serviceSnapshot.name, placeName: b.place.name },
    shootEndsAt: input.shootEndsAt,
    agreedFee: input.agreedFee,
    offerStatus: 'pending',
    offerAt: now,
    offerExpiresAt: input.offerExpiresAt,
    acceptedAt: null,
    declinedAt: null,
    closedAt: null,
    payStatus: 'none',
    pay: {
      amount: input.agreedFee,
      dueAt: null,
      paidOn: null,
      method: null,
      reportedAt: null,
      receivedAt: null,
      disputedAt: null,
      overdueFlaggedAt: null,
      disputeFlaggedAt: null,
    },
    createdAt: now,
    updatedAt: now,
  };
}

const OPEN_FOR_COLLABORATOR: readonly string[] = ['requested', 'accepted', 'upcoming', 'shot', 'delivered', 'revision_requested', 'approved'];

/**
 * R8 (Review Focus 3): whether the assignee may read the customer's contact. A member follows S26
 * (`bookingContactUnlocked`, the photographer's rule). A collaborator only once the offer is accepted (the
 * booking is paid by then) while the booking runs, and until 7 days after it was completed or cancelled
 * (exclusive). A replaced collaborator is no longer the booking's assignee, so this is never asked for them.
 */
export function collaboratorContactOpen(
  b: {
    readonly assigneeKind?: string | null;
    readonly assigneeAccepted?: boolean;
    readonly status: string;
    readonly completedAt: Date | null;
    readonly cancelledAt: Date | null;
  },
  now: Date,
): boolean {
  if (b.assigneeKind !== 'collaborator') return bookingContactUnlocked(b, now);
  if (b.assigneeAccepted !== true) return false;
  if (OPEN_FOR_COLLABORATOR.includes(b.status)) return true;
  const within = (at: Date | null): boolean => at !== null && now.getTime() - at.getTime() < CONTACT_CLOSE_DAYS * DAY_MS;
  if (b.status === 'completed' || b.status === 'reviewed') return within(b.completedAt);
  if (b.status === 'cancelled') return within(b.cancelledAt);
  return false;
}

/**
 * One more unpaid flag on the studio's counters (Decision 15): flags older than 90 days are dropped; the third
 * within 90 days blocks recruiting for 30 days (never shortening a running block). Flags never clear otherwise.
 */
export function addUnpaidFlag(c: RecruitCounters, now: Date): RecruitCounters {
  const unpaidFlags = [...c.unpaidFlags.filter((f) => now.getTime() - f.getTime() < UNPAID_WINDOW_DAYS * DAY_MS), now];
  let recruitBlockedUntil = c.recruitBlockedUntil;
  if (unpaidFlags.length >= UNPAID_FLAGS_TO_BLOCK) {
    const until = new Date(now.getTime() + RECRUIT_BLOCK_DAYS * DAY_MS);
    if (recruitBlockedUntil === null || recruitBlockedUntil.getTime() < until.getTime()) recruitBlockedUntil = until;
  }
  return { ...c, unpaidFlags, recruitBlockedUntil };
}

/**
 * The job after a booking write (pure; the booking trigger calls it): a cancelled booking cancels a pending or
 * accepted job (no pay record), a completed or reviewed one closes it. Null when nothing changes.
 */
export function syncCollabJobOnBooking(
  job: CollabJob,
  booking: Pick<Booking, 'status' | 'cancel' | 'completedAt' | 'updatedAt'>,
): CollabJob | null {
  if (!isLiveOffer(job) || job.closedAt !== null) return null;
  if (booking.status === 'cancelled') {
    const at = new Date(booking.cancel?.at ?? booking.updatedAt);
    return { ...job, offerStatus: 'cancelled', closedAt: at, updatedAt: at };
  }
  if (booking.status === 'completed' || booking.status === 'reviewed') {
    const at = new Date(booking.completedAt ?? booking.updatedAt);
    return { ...job, closedAt: at, updatedAt: at };
  }
  return null;
}

/**
 * Whether the booking's first milestone went to the studio (Decision 15, payments V1 #200): a payment whose
 * `shoot` milestone is `released` or `paid_out`. What the `milestones.shotReleased` adapter reads.
 */
export function isShootMilestoneReleased(payments: readonly Pick<Payment, 'milestones'>[]): boolean {
  return payments.some((p) =>
    (p.milestones ?? []).some((m) => m.kind === 'shoot' && (m.status === 'released' || m.status === 'paid_out')));
}

/**
 * Decision 18, record only: the photographer's accepted jobs with this customer from the last 183 days, when
 * the photographer has at least 2 personal bookings with the customer since the earliest of them; else null.
 */
export function poachingSignal(input: {
  readonly jobs: readonly CollabJob[];
  readonly personalBookingsSince: (since: Date) => number;
  readonly now: Date;
}): CollabJob[] | null {
  const recent = input.jobs.filter(
    (j): j is CollabJob & { acceptedAt: Date } =>
      j.offerStatus === 'accepted' &&
      j.acceptedAt !== null &&
      input.now.getTime() - j.acceptedAt.getTime() <= POACH_WINDOW_DAYS * DAY_MS,
  );
  if (recent.length === 0) return null;
  const since = new Date(Math.min(...recent.map((j) => j.acceptedAt.getTime())));
  return input.personalBookingsSince(since) >= POACH_THRESHOLD ? recent : null;
}

// ── off-app pay record (spec §5.1) ──

const PAID_ON = /^(\d{4})-(\d{2})-(\d{2})$/;

/** A real calendar day `yyyy-MM-dd` not after today in Vietnam. */
function paidOnOf(v: unknown, now: Date): string {
  if (typeof v !== 'string') return fail('invalid_argument', 'paidOn');
  const m = PAID_ON.exec(v);
  if (!m) return fail('invalid_argument', 'paidOn');
  const d = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])));
  if (d.toISOString().slice(0, 10) !== v || v > vnDayKey(now)) fail('invalid_argument', 'paidOn');
  return v;
}

function methodOf(v: unknown): CollabPayMethod {
  return typeof v === 'string' && (COLLAB_PAY_METHODS as readonly string[]).includes(v)
    ? (v as CollabPayMethod)
    : fail('invalid_argument', 'method');
}

/**
 * Studio "Đã trả" (`{bookingId, collaboratorId, paidOn, method}`): a `due` job, or one the collaborator
 * disputed, becomes `paid_reported`; the collaborator is asked to confirm.
 */
export async function reportCollabPaid(deps: RecruitDeps, studioId: string, raw: unknown): Promise<void> {
  const r = objectOf(raw);
  const bookingId = idOf(r, 'bookingId');
  const collaboratorId = idOf(r, 'collaboratorId');
  const now = deps.clock.now();
  const paidOn = paidOnOf(r.paidOn, now);
  const method = methodOf(r.method);
  const job = await deps.store.runTransaction(async (tx) => {
    const j = await tx.getCollabJob(bookingId, collaboratorId);
    if (j === null) return fail('not_found');
    if (j.studioId !== studioId) fail('permission_denied');
    if (j.payStatus !== 'due' && j.payStatus !== 'disputed') fail('conflict');
    const next: CollabJob = {
      ...j,
      payStatus: 'paid_reported',
      pay: { ...j.pay, paidOn, method, reportedAt: now },
      updatedAt: now,
    };
    tx.putCollabJob(next);
    return next;
  });
  await safely(deps, job.collaboratorId, () => notifyCollabPayReported(deps.notify, {
    collaboratorId: job.collaboratorId,
    studioId: job.studioId,
    bookingId: job.bookingId,
    amount: job.pay.amount,
    method,
  }));
}

/**
 * Collaborator "Đã nhận" / "Chưa nhận" (`{bookingId, received}`) on a reported payment: `received`, or
 * `disputed` (the studio is told; the sweep adds the unpaid flag once).
 */
export async function confirmCollabPay(
  deps: RecruitDeps,
  collaboratorId: string,
  raw: unknown,
): Promise<{ payStatus: 'received' | 'disputed' }> {
  const r = objectOf(raw);
  const bookingId = idOf(r, 'bookingId');
  if (typeof r.received !== 'boolean') fail('invalid_argument', 'received');
  const received = r.received;
  const now = deps.clock.now();
  const job = await deps.store.runTransaction(async (tx) => {
    const j = await tx.getCollabJob(bookingId, collaboratorId);
    if (j === null) return fail('not_found');
    if (j.payStatus !== 'paid_reported') fail('conflict');
    const next: CollabJob = received
      ? { ...j, payStatus: 'received', pay: { ...j.pay, receivedAt: now }, updatedAt: now }
      : { ...j, payStatus: 'disputed', pay: { ...j.pay, disputedAt: now }, updatedAt: now };
    tx.putCollabJob(next);
    return next;
  });
  if (!received) {
    await safely(deps, job.studioId, () => notifyCollabPayDisputed(deps.notify, {
      studioId: job.studioId,
      collaboratorId: job.collaboratorId,
      bookingId: job.bookingId,
      amount: job.pay.amount,
      service: job.shoot.serviceName,
      day: job.shoot.day,
    }));
  }
  return { payStatus: received ? 'received' : 'disputed' };
}
