import type { BookingDraftInput } from './create_booking.js';
import type { Booking } from './booking.js';
import type { BookingTerms, QuoteRecord } from './job.js';
import type { JobDeps } from './job_ports.js';
import type { BookingDeps } from './booking_ports.js';
import { DomainError } from './errors.js';
import { findContactLeak } from './contact_filter.js';
import {
  checkoutActive,
  deadlinePassed,
} from './job.js';
import { milestoneAmounts } from './milestones.js';
import { addMinutesToTime, isDateString, isTimeString, parseVnDateTime } from './booking_policy.js';
import { jobFit, jobInServiceArea, providerTypeAllowed } from './job_eligibility.js';
import { assertOrderAllowed, orderBlocker } from './order_gate.js';
import { requireCustomerPhone } from './require_phone.js';
import { buildBookingDraft } from './create_booking.js';
import { createPayment } from './create_payment.js';
import { DRAFT_EXPIRY_MINUTES } from './booking_policy.js';
import { isPaymentMethod } from './escrow.js';

export function quoteDraftFields(i: BookingDraftInput): Partial<Booking> {
  if (!i.quote) return {};
  return {
    source: 'quote',
    jobId: i.quote.jobId,
    quoteId: i.quote.quoteId,
    terms: i.quote.terms,
  };
}

export interface SubmitQuoteInput {
  readonly jobId: string;
  readonly price: number;
  readonly editedCount: number;
  readonly deliveryDays: number;
  readonly revisions: number;
  readonly message: string;
  readonly albumId?: string | null;
  readonly basedOnServiceId?: string | null;
  readonly proposal?: {
    readonly day: string;
    readonly start: string;
  };
}

export function validateSubmitQuoteInput(raw: unknown): SubmitQuoteInput {
  if (!raw || typeof raw !== 'object') {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;

  if (typeof r.jobId !== 'string' || !r.jobId.trim()) {
    throw new DomainError('invalid_argument', 'jobId');
  }

  if (
    typeof r.price !== 'number' ||
    !Number.isInteger(r.price) ||
    r.price <= 0 ||
    r.price > 1_000_000_000
  ) {
    throw new DomainError('invalid_argument', 'price');
  }

  if (
    typeof r.editedCount !== 'number' ||
    !Number.isInteger(r.editedCount) ||
    r.editedCount < 1 ||
    r.editedCount > 2000
  ) {
    throw new DomainError('invalid_argument', 'editedCount');
  }

  if (
    typeof r.deliveryDays !== 'number' ||
    !Number.isInteger(r.deliveryDays) ||
    r.deliveryDays < 1 ||
    r.deliveryDays > 60
  ) {
    throw new DomainError('invalid_argument', 'deliveryDays');
  }

  if (
    typeof r.revisions !== 'number' ||
    !Number.isInteger(r.revisions) ||
    r.revisions < 0 ||
    r.revisions > 10
  ) {
    throw new DomainError('invalid_argument', 'revisions');
  }

  if (typeof r.message !== 'string') {
    throw new DomainError('invalid_argument', 'message');
  }
  const message = r.message.trim();
  if (message.length < 20 || message.length > 500) {
    throw new DomainError('invalid_argument', 'message');
  }
  if (findContactLeak(message) !== null) {
    throw new DomainError('invalid_argument', 'message.contact');
  }

  let albumId: string | null = null;
  if (r.albumId !== undefined && r.albumId !== null) {
    if (typeof r.albumId !== 'string' || !r.albumId.trim()) {
      throw new DomainError('invalid_argument', 'albumId');
    }
    albumId = r.albumId.trim();
  }

  let basedOnServiceId: string | null = null;
  if (r.basedOnServiceId !== undefined && r.basedOnServiceId !== null) {
    if (typeof r.basedOnServiceId !== 'string' || !r.basedOnServiceId.trim()) {
      throw new DomainError('invalid_argument', 'basedOnServiceId');
    }
    basedOnServiceId = r.basedOnServiceId.trim();
  }

  let proposal: { day: string; start: string } | undefined = undefined;
  if (r.proposal !== undefined && r.proposal !== null) {
    const p = r.proposal as Record<string, unknown>;
    if (
      typeof p !== 'object' ||
      typeof p.day !== 'string' ||
      !isDateString(p.day) ||
      typeof p.start !== 'string' ||
      !isTimeString(p.start)
    ) {
      throw new DomainError('invalid_argument', 'proposal');
    }
    proposal = { day: p.day, start: p.start };
  }

  return {
    jobId: r.jobId.trim(),
    price: r.price,
    editedCount: r.editedCount,
    deliveryDays: r.deliveryDays,
    revisions: r.revisions,
    message,
    albumId,
    basedOnServiceId,
    proposal,
  };
}

export async function submitQuote(
  deps: JobDeps,
  uid: string,
  raw: unknown,
): Promise<{ status: 'submitted'; fit: number }> {
  const provider = await deps.people.provider(uid);
  if (!provider || provider.role !== 'photographer') {
    throw new DomainError('not_eligible');
  }

  const input = validateSubmitQuoteInput(raw);
  const now = deps.clock.now();

  let photoCount: number | null = null;
  if (input.basedOnServiceId) {
    const svc = await deps.people.service(uid, input.basedOnServiceId);
    if (!svc || !svc.active) {
      throw new DomainError('invalid_argument', 'basedOnServiceId');
    }
    photoCount = svc.photoCount;
  }

  let albumData: { title: string; coverUrl: string | null; postCount: number } | null = null;
  if (input.albumId) {
    const alb = await deps.people.album(input.albumId);
    if (!alb || alb.photographerId !== uid || alb.postCount <= 0) {
      throw new DomainError('invalid_argument', 'albumId');
    }
    albumData = {
      title: alb.title,
      coverUrl: alb.coverUrl,
      postCount: alb.postCount,
    };
  }

  // Check 20 submitted quotes limit outside the transaction
  const submittedCount = await deps.jobs.countSubmittedQuotes(uid);

  return deps.jobs.runTransaction(async (tx) => {
    const job = await tx.getJob(input.jobId);
    if (!job) {
      throw new DomainError('not_found');
    }

    if (job.customerId === uid) {
      throw new DomainError('not_eligible');
    }

    const blocker = await orderBlocker(deps, {
      customerId: job.customerId,
      providerId: uid,
    });
    if (blocker) {
      throw new DomainError(blocker);
    }

    if (job.status !== 'open') {
      throw new DomainError('conflict');
    }

    if (deadlinePassed(job, now)) {
      throw new DomainError('deadline_passed');
    }

    if (!jobInServiceArea(job.area, provider.serviceArea)) {
      throw new DomainError('not_eligible');
    }

    if (!providerTypeAllowed(job.allowedProviders, provider.providerType)) {
      throw new DomainError('not_eligible');
    }

    const existingQuote = await tx.getQuote(job.id, uid);
    if (existingQuote) {
      if (
        existingQuote.status === 'accepted' ||
        existingQuote.status === 'not_selected' ||
        existingQuote.status === 'declined'
      ) {
        throw new DomainError('conflict');
      }
      if (job.checkout?.quoteId === existingQuote.id && checkoutActive(job, now)) {
        throw new DomainError('conflict');
      }
    }

    const isNewOrResubmitted = !existingQuote || existingQuote.status === 'withdrawn';
    if (isNewOrResubmitted && submittedCount >= 20) {
      throw new DomainError('limit_exceeded');
    }

    let quoteProposal: { day: string; start: string; end: string };
    if (job.schedule.kind === 'fixed') {
      const fixedDay = job.schedule.day ?? '';
      const fixedStart = job.schedule.start ?? '';
      const fixedEnd = job.schedule.end ?? '';
      quoteProposal = {
        day: fixedDay,
        start: fixedStart,
        end: fixedEnd,
      };
    } else {
      if (!input.proposal) {
        throw new DomainError('invalid_argument', 'proposal');
      }
      const propDay = input.proposal.day;
      const schedFrom = job.schedule.from ?? '';
      const schedTo = job.schedule.to ?? '';
      if (propDay < schedFrom || propDay > schedTo) {
        throw new DomainError('invalid_argument', 'proposal');
      }
      const dur = job.schedule.durationMinutes ?? 0;
      quoteProposal = {
        day: propDay,
        start: input.proposal.start,
        end: addMinutesToTime(input.proposal.start, dur),
      };
    }

    const dayState = await deps.people.dayState(uid, quoteProposal.day);
    if (dayState === 'booked' || dayState === 'off') {
      throw new DomainError('day_taken');
    }

    const fit = jobFit(job, provider, dayState);
    const existingInvite = await tx.getInvite(job.id, uid);
    const invited = !!existingInvite;

    const terms: BookingTerms = {
      price: input.price,
      durationMinutes: job.schedule.durationMinutes ?? 0,
      photoCount,
      editedCount: input.editedCount,
      deliveryDays: input.deliveryDays,
      revisions: input.revisions,
      milestones: [
        { kind: 'shoot', percent: 50 },
        { kind: 'delivery', percent: 50 },
      ],
    };

    const amounts = milestoneAmounts(input.price, { shoot: 50, delivery: 50 });

    const quoteRecord: QuoteRecord = {
      id: uid,
      jobId: job.id,
      photographerId: uid,
      customerId: job.customerId,
      jobTitle: job.title,
      photographer: {
        name: provider.name,
        avatarUrl: provider.avatarUrl,
        providerType: provider.providerType,
        verified: provider.verified,
        tomatoPct: provider.tomatoPct,
        score: provider.score,
        reviewCount: provider.reviewCount,
        completedCount: provider.completedCount,
        approvedAwardCount: provider.approvedAwardCount,
        studioDistrict: provider.studioDistrict,
      },
      basedOnServiceId: input.basedOnServiceId ?? null,
      terms,
      milestoneAmounts: amounts,
      proposal: quoteProposal,
      message: input.message,
      albumId: input.albumId ?? null,
      album: albumData,
      invited,
      fit,
      status: 'submitted',
      notSelectedReason: null,
      autoWithdrawn: false,
      declineReason: null,
      bookingId: null,
      withdrawnAt: null,
      version: existingQuote ? existingQuote.version + 1 : 1,
      createdAt: existingQuote?.createdAt ?? now,
      updatedAt: now,
    };

    let nextRecentQuoters = job.recentQuoters;
    if (provider.avatarUrl) {
      nextRecentQuoters = [
        { photographerId: provider.uid, avatarUrl: provider.avatarUrl },
        ...job.recentQuoters.filter((u) => u.photographerId !== provider.uid),
      ].slice(0, 3);
    }

    const quoteCountDelta = isNewOrResubmitted ? 1 : 0;
    const nextJob = {
      ...job,
      quoteCount: job.quoteCount + quoteCountDelta,
      newQuoteCount: job.newQuoteCount + quoteCountDelta,
      recentQuoters: nextRecentQuoters,
      version: job.version + 1,
      updatedAt: now,
    };

    tx.putQuote(quoteRecord);
    tx.putJob(nextJob);

    return { status: 'submitted', fit };
  });
}

export async function withdrawQuote(
  deps: JobDeps,
  uid: string,
  raw: unknown,
): Promise<Record<string, never>> {
  if (!raw || typeof raw !== 'object' || typeof (raw as Record<string, unknown>).jobId !== 'string') {
    throw new DomainError('invalid_argument', 'jobId');
  }
  const jobId = ((raw as Record<string, unknown>).jobId as string).trim();
  const now = deps.clock.now();

  return deps.jobs.runTransaction(async (tx) => {
    const job = await tx.getJob(jobId);
    if (!job) {
      throw new DomainError('not_found');
    }

    const quote = await tx.getQuote(jobId, uid);
    if (!quote || quote.status !== 'submitted') {
      throw new DomainError('conflict');
    }

    if (job.checkout?.quoteId === quote.id && checkoutActive(job, now)) {
      throw new DomainError('conflict');
    }

    const updatedQuote: QuoteRecord = {
      ...quote,
      status: 'withdrawn',
      autoWithdrawn: false,
      withdrawnAt: now,
      version: quote.version + 1,
      updatedAt: now,
    };

    const nextRecentQuoters = quote.photographer.avatarUrl
      ? job.recentQuoters.filter((u) => u.photographerId !== quote.photographerId)
      : job.recentQuoters;

    const nextJob = {
      ...job,
      quoteCount: Math.max(0, job.quoteCount - 1),
      recentQuoters: nextRecentQuoters,
      version: job.version + 1,
      updatedAt: now,
    };

    tx.putQuote(updatedQuote);
    tx.putJob(nextJob);

    return {};
  });
}

export async function declineQuote(
  deps: JobDeps,
  uid: string,
  raw: unknown,
): Promise<Record<string, never>> {
  if (
    !raw ||
    typeof raw !== 'object' ||
    typeof (raw as Record<string, unknown>).jobId !== 'string' ||
    typeof (raw as Record<string, unknown>).photographerId !== 'string'
  ) {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;
  const jobId = (r.jobId as string).trim();
  const photographerId = (r.photographerId as string).trim();
  let reason: string | null = null;
  if (r.reason !== undefined && r.reason !== null) {
    if (typeof r.reason !== 'string' || r.reason.length > 200) {
      throw new DomainError('invalid_argument', 'reason');
    }
    reason = r.reason.trim();
  }

  const now = deps.clock.now();

  return deps.jobs.runTransaction(async (tx) => {
    const job = await tx.getJob(jobId);
    if (!job) {
      throw new DomainError('not_found');
    }

    if (job.customerId !== uid) {
      throw new DomainError('permission_denied');
    }

    const quote = await tx.getQuote(jobId, photographerId);
    if (!quote || quote.status !== 'submitted') {
      throw new DomainError('conflict');
    }

    const updatedQuote: QuoteRecord = {
      ...quote,
      status: 'declined',
      declineReason: reason,
      version: quote.version + 1,
      updatedAt: now,
    };

    tx.putQuote(updatedQuote);

    return {};
  });
}

export interface AcceptQuoteInput {
  jobId: string;
  photographerId: string;
  place: { name: string };
  note?: string;
  method: string;
}

export function validateAcceptQuoteInput(raw: unknown): AcceptQuoteInput {
  if (!raw || typeof raw !== 'object') {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;

  if (typeof r.jobId !== 'string' || !r.jobId.trim()) {
    throw new DomainError('invalid_argument', 'jobId');
  }
  if (typeof r.photographerId !== 'string' || !r.photographerId.trim()) {
    throw new DomainError('invalid_argument', 'photographerId');
  }

  if (!r.place || typeof r.place !== 'object') {
    throw new DomainError('invalid_argument', 'place');
  }
  const placeObj = r.place as Record<string, unknown>;
  if (
    typeof placeObj.name !== 'string' ||
    placeObj.name.trim().length < 3 ||
    placeObj.name.trim().length > 120
  ) {
    throw new DomainError('invalid_argument', 'place');
  }

  let note: string | undefined = undefined;
  if (r.note !== undefined && r.note !== null) {
    if (typeof r.note !== 'string' || r.note.length > 300) {
      throw new DomainError('invalid_argument', 'note');
    }
    note = r.note;
  }

  if (typeof r.method !== 'string' || !isPaymentMethod(r.method)) {
    throw new DomainError('invalid_argument', 'method');
  }

  return {
    jobId: r.jobId.trim(),
    photographerId: r.photographerId.trim(),
    place: { name: placeObj.name.trim() },
    note,
    method: r.method,
  };
}

export async function createQuoteBookingDraft(
  bookingDeps: BookingDeps,
  p: {
    bookingId: string;
    job: import('./job.js').JobRecord;
    quote: QuoteRecord;
    customerId: string;
    place: { name: string; point?: { lat: number; lng: number } };
    note?: string;
    replaceDraftId: string | null;
  },
): Promise<Booking> {
  const now = bookingDeps.clock.now();
  const { quote, job } = p;
  const { terms, proposal } = quote;

  return bookingDeps.store.runTransaction(async (tx) => {
    const dayState = await bookingDeps.store.getAvailabilityDay(
      quote.photographerId,
      proposal.day,
    );

    if (dayState?.state === 'off' || dayState?.state === 'booked') {
      throw new DomainError('day_taken');
    }
    if (dayState?.state === 'pending') {
      if (!p.replaceDraftId || dayState.bookingId !== p.replaceDraftId) {
        throw new DomainError('day_taken');
      }
    }

    if (p.replaceDraftId) {
      const oldDraft = await tx.getBooking(p.replaceDraftId);
      if (oldDraft && oldDraft.status === 'draft') {
        // clear old draft
        await tx.setBooking({
          ...oldDraft,
          status: 'expired',
          version: oldDraft.version + 1,
          updatedAt: now.toISOString(),
        });
      }
    }

    const draft = buildBookingDraft({
      id: p.bookingId,
      customerId: p.customerId,
      photographerId: quote.photographerId,
      service: {
        id: quote.basedOnServiceId ?? '',
        photographerId: quote.photographerId,
        name: job.title,
        price: terms.price,
        durationMinutes: terms.durationMinutes,
        active: true,
        revisions: terms.revisions,
      },
      day: proposal.day,
      start: proposal.start,
      place: p.place,
      note: p.note,
      now,
      quote: {
        jobId: job.id,
        quoteId: quote.id,
        terms,
      },
    });

    const bookingContact = await bookingDeps.contacts.get(p.customerId);
    if (bookingContact) {
      await tx.setContactSnapshot(draft.id, {
        name: bookingContact.name ?? bookingContact.phone,
        phone: bookingContact.phone,
        allowZalo: bookingContact.allowZalo ?? true,
        allowWhatsApp: bookingContact.allowWhatsApp ?? false,
      });
    }

    await tx.setBooking(draft);
    await tx.setAvailabilityDay(quote.photographerId, proposal.day, {
      state: 'pending',
      bookingId: draft.id,
    });
    await tx.addBookingEvent({
      id: bookingDeps.ids.newId(),
      bookingId: draft.id,
      status: 'draft',
      at: now.toISOString(),
    });

    return draft;
  });
}

export async function releaseCheckout(
  deps: JobDeps,
  jobId: string,
  bookingId: string,
): Promise<void> {
  await deps.jobs.runTransaction(async (tx) => {
    const job = await tx.getJob(jobId);
    if (!job || job.checkout?.bookingId !== bookingId) {
      return;
    }
    tx.putJob({
      ...job,
      checkout: null,
      version: job.version + 1,
      updatedAt: deps.clock.now(),
    });
  });
}

export async function acceptQuote(
  deps: JobDeps,
  booking: BookingDeps,
  uid: string,
  raw: unknown,
) {
  const input = validateAcceptQuoteInput(raw);
  const now = deps.clock.now();

  await requireCustomerPhone(deps.contacts, uid);
  await assertOrderAllowed(deps, {
    customerId: uid,
    providerId: input.photographerId,
  });

  const bookingId = booking.ids.newId();

  // 1. Reserve the quote on the job (replaces any earlier lock)
  const { job, quote, previous } = await deps.jobs.runTransaction(async (tx) => {
    const job = await tx.getJob(input.jobId);
    if (!job) throw new DomainError('not_found');
    if (job.customerId !== uid) throw new DomainError('permission_denied');
    if (job.status !== 'open') throw new DomainError('conflict');
    if (deadlinePassed(job, now) && !checkoutActive(job, now)) {
      throw new DomainError('deadline_passed');
    }
    const quote = await tx.getQuote(job.id, input.photographerId);
    if (!quote || quote.status !== 'submitted') throw new DomainError('conflict');

    const previous = checkoutActive(job, now) ? job.checkout : null;
    const expiresAt = new Date(now.getTime() + DRAFT_EXPIRY_MINUTES * 60 * 1000);

    tx.putJob({
      ...job,
      checkout: {
        quoteId: quote.id,
        bookingId,
        expiresAt,
      },
      version: job.version + 1,
      updatedAt: now,
    });
    return { job, quote, previous };
  });

  try {
    // 2. Booking draft through buildBookingDraft
    await createQuoteBookingDraft(booking, {
      bookingId,
      job,
      quote,
      customerId: uid,
      place: input.place,
      note: input.note,
      replaceDraftId: previous?.bookingId ?? null,
    });

    // 3. Payment: createPayment
    const { paymentId, checkout } = await createPayment(booking, {
      bookingId,
      customerId: uid,
      method: input.method as import('./escrow.js').PaymentMethod,
    });

    return { bookingId, paymentId, checkout };
  } catch (e) {
    await releaseCheckout(deps, job.id, bookingId);
    throw e;
  }
}

export async function awardJobFromBooking(
  deps: JobDeps,
  b: Booking,
): Promise<'awarded' | 'already' | 'skipped'> {
  if (b.source !== 'quote' || b.status !== 'accepted' || !b.jobId || !b.quoteId) {
    return 'skipped';
  }
  const jId = b.jobId;

  return deps.jobs.runTransaction(async (tx) => {
    const job = await tx.getJob(jId);
    if (!job) {
      return 'skipped';
    }

    if (job.awardedQuoteId === b.quoteId) {
      return 'already';
    }

    if (job.status === 'awarded') {
      return 'skipped';
    }

    if (job.status === 'closed') {
      return 'skipped';
    }

    // Must read all queries upfront before writes
    const quotes = await tx.listQuotes(job.id);
    const invites = await tx.listInvites(job.id);
    const matches = await tx.listMatches(job.id);

    const now = deps.clock.now();
    const chosenQuote = quotes.find((q) => q.id === b.quoteId);
    if (!chosenQuote) {
      return 'skipped';
    }

    // Shoot day + 30 days for referencesPurgeAfter
    const shootDayDt = parseVnDateTime(b.day, b.start);
    const purgeDate = new Date(shootDayDt.getTime() + 30 * 24 * 60 * 60 * 1000);

    const updatedJob: import('./job.js').JobRecord = {
      ...job,
      status: 'awarded',
      awardedQuoteId: chosenQuote.id,
      bookingId: b.id,
      awardedTo: {
        photographerId: chosenQuote.photographerId,
        name: chosenQuote.photographer.name,
        price: chosenQuote.terms.price,
      },
      checkout: null,
      closedAt: now,
      referencesPurgeAfter: purgeDate,
      version: job.version + 1,
      updatedAt: now,
    };

    tx.putJob(updatedJob);

    for (const q of quotes) {
      if (q.id === chosenQuote.id) {
        tx.putQuote({
          ...q,
          status: 'accepted',
          bookingId: b.id,
          version: q.version + 1,
          updatedAt: now,
        });
      } else if (q.status === 'submitted') {
        tx.putQuote({
          ...q,
          status: 'not_selected',
          notSelectedReason: 'awarded',
          version: q.version + 1,
          updatedAt: now,
        });
      }
    }

    for (const inv of invites) {
      if (inv.jobStatus === 'open') {
        tx.putInvite({
          ...inv,
          jobStatus: 'closed',
        });
      }
    }

    for (const m of matches) {
      if (m.jobStatus === 'open') {
        tx.putMatch({
          ...m,
          jobStatus: 'closed',
        });
      }
    }

    return 'awarded';
  });
}

export async function withdrawQuotesForDay(
  deps: JobDeps,
  pid: string,
  day: string,
  exceptJobId?: string,
): Promise<number> {
  const submittedQuotes = await deps.jobs.submittedQuotesOnDay(pid, day);
  let count = 0;

  for (const sq of submittedQuotes) {
    if (exceptJobId && sq.jobId === exceptJobId) {
      continue;
    }

    await deps.jobs.runTransaction(async (tx) => {
      const currentQuote = await tx.getQuote(sq.jobId, pid);
      if (!currentQuote || currentQuote.status !== 'submitted') {
        return;
      }
      const job = await tx.getJob(sq.jobId);
      if (!job) return;

      const now = deps.clock.now();
      const updatedQuote: QuoteRecord = {
        ...currentQuote,
        status: 'withdrawn',
        autoWithdrawn: true,
        withdrawnAt: now,
        version: currentQuote.version + 1,
        updatedAt: now,
      };

      const nextRecent = currentQuote.photographer.avatarUrl
        ? job.recentQuoters.filter((u) => u.photographerId !== currentQuote.photographerId)
        : job.recentQuoters;

      const updatedJob = {
        ...job,
        quoteCount: Math.max(0, job.quoteCount - 1),
        recentQuoters: nextRecent,
        version: job.version + 1,
        updatedAt: now,
      };

      tx.putQuote(updatedQuote);
      tx.putJob(updatedJob);
      count++;
    });
  }

  return count;
}
