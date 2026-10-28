import { DomainError } from './errors.js';
import { requireCustomerPhone } from './require_phone.js';
import { orderBlocker } from './order_gate.js';
import {
  checkoutActive,
  deadlinePassed,
  INVITES_PER_JOB,
  JOB_EXTEND_DAYS,
  MATCH_AVAILABILITY_READS,
  MATCH_SCAN_LIMIT,
  MATCHES_PER_JOB,
  OPEN_JOBS_PER_CUSTOMER,
  validateJobInput,
} from './job.js';
import type { JobMatchRecord, JobRecord } from './job.js';
import type { JobDeps } from './job_ports.js';
import { jobFit, jobInServiceArea, providerTypeAllowed } from './job_eligibility.js';
import { acceptsOrders } from './provider_orders.js';
import { formatVnDate } from './booking_policy.js';

export async function createJob(
  deps: JobDeps,
  uid: string,
  raw: unknown,
): Promise<{ jobId: string; matched: number }> {
  // 1. Check customer role
  const customer = await deps.people.customer(uid);
  if (!customer || customer.role !== 'customer') {
    throw new DomainError('permission_denied');
  }

  // 2. Require customer phone
  await requireCustomerPhone(deps.contacts, uid);

  // 3. Validate input
  const now = deps.clock.now();
  const fields = validateJobInput(raw, now);

  // Verify caller owns references
  for (const ref of fields.references) {
    if (!deps.media.isOwnReference(ref.url, ref.path, uid)) {
      throw new DomainError('invalid_argument', 'references');
    }
  }

  // 4. Open jobs limit
  const openCount = await deps.jobs.countOpenJobs(uid);
  if (openCount >= OPEN_JOBS_PER_CUSTOMER) {
    throw new DomainError('limit_exceeded');
  }

  // 5. Matching candidates
  let topMatches: JobMatchRecord[] = [];
  const jobId = deps.ids.newId();

  if (fields.specialtyId !== 'other') {
    const candidates = await deps.people.candidates(fields.specialtyId, MATCH_SCAN_LIMIT);
    const eligible: { p: (typeof candidates)[0]; fit: number }[] = [];

    for (const p of candidates) {
      if (p.uid === uid) continue;
      if (!acceptsOrders(p.acceptingOrdersFields)) continue;
      if (deps.blocks && (await deps.blocks.isBlockedEitherWay(uid, p.uid))) continue;
      if (!jobInServiceArea(fields.area, p.serviceArea)) continue;
      if (!providerTypeAllowed(fields.allowedProviders, p.providerType)) continue;

      // Provisional fit assuming free
      const provisionalJobRecord: JobRecord = {
        id: jobId,
        customerId: uid,
        customer: {
          name: customer.name,
          avatarUrl: customer.avatarUrl,
          hireCount: customer.hireCount,
          phoneVerified: customer.phoneVerified,
        },
        ...fields,
        extended: false,
        status: 'open',
        quoteCount: 0,
        newQuoteCount: 0,
        viewCount: 0,
        inviteCount: 0,
        matchCount: 0,
        recentQuoters: [],
        awardedQuoteId: null,
        bookingId: null,
        awardedTo: null,
        checkout: null,
        expiringNotifiedAt: null,
        closedAt: null,
        referencesPurgeAfter: null,
        quotesSeenAt: null,
        version: 1,
        createdAt: now,
        updatedAt: now,
      };

      const fit = jobFit(provisionalJobRecord, p, 'free');
      eligible.push({ p, fit });
    }

    // Top 40 by provisional fit
    eligible.sort((a, b) => b.fit - a.fit);
    const top40 = eligible.slice(0, MATCH_AVAILABILITY_READS);

    // Final fit with day state
    const firstDay = fields.dayFrom;
    const scored: { p: (typeof candidates)[0]; fit: number }[] = [];

    for (const item of top40) {
      const state = await deps.people.dayState(item.p.uid, firstDay);
      const dayArg: 'free' | 'pending' | 'busy' =
        state === 'booked' || state === 'off' ? 'busy' : state;
      const provisionalJobRecord: JobRecord = {
        id: jobId,
        customerId: uid,
        customer: {
          name: customer.name,
          avatarUrl: customer.avatarUrl,
          hireCount: customer.hireCount,
          phoneVerified: customer.phoneVerified,
        },
        ...fields,
        extended: false,
        status: 'open',
        quoteCount: 0,
        newQuoteCount: 0,
        viewCount: 0,
        inviteCount: 0,
        matchCount: 0,
        recentQuoters: [],
        awardedQuoteId: null,
        bookingId: null,
        awardedTo: null,
        checkout: null,
        expiringNotifiedAt: null,
        closedAt: null,
        referencesPurgeAfter: null,
        quotesSeenAt: null,
        version: 1,
        createdAt: now,
        updatedAt: now,
      };
      const finalFit = jobFit(provisionalJobRecord, item.p, dayArg);
      scored.push({ p: item.p, fit: finalFit });
    }

    scored.sort((a, b) => b.fit - a.fit);
    const top30 = scored.slice(0, MATCHES_PER_JOB);

    topMatches = top30.map((s) => ({
      id: s.p.uid,
      jobId,
      photographerId: s.p.uid,
      fit: s.fit,
      jobStatus: 'open',
      createdAt: now,
    }));
  }

  // 6. Transaction to save job & matches
  const jobRecord: JobRecord = {
    id: jobId,
    customerId: uid,
    customer: {
      name: customer.name,
      avatarUrl: customer.avatarUrl,
      hireCount: customer.hireCount,
      phoneVerified: customer.phoneVerified,
    },
    ...fields,
    extended: false,
    status: 'open',
    quoteCount: 0,
    newQuoteCount: 0,
    viewCount: 0,
    inviteCount: 0,
    matchCount: topMatches.length,
    recentQuoters: [],
    awardedQuoteId: null,
    bookingId: null,
    awardedTo: null,
    checkout: null,
    expiringNotifiedAt: null,
    closedAt: null,
    referencesPurgeAfter: null,
    quotesSeenAt: null,
    version: 1,
    createdAt: now,
    updatedAt: now,
  };

  await deps.jobs.runTransaction(async (tx) => {
    tx.putJob(jobRecord);
    for (const m of topMatches) {
      tx.putMatch(m);
    }
  });

  return { jobId, matched: topMatches.length };
}

export async function updateJob(
  deps: JobDeps,
  uid: string,
  raw: unknown,
): Promise<{ jobId: string }> {
  if (typeof raw !== 'object' || raw === null) {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;
  if (typeof r.jobId !== 'string') {
    throw new DomainError('invalid_argument', 'jobId');
  }
  const jobId = r.jobId;

  const now = deps.clock.now();

  await deps.jobs.runTransaction(async (tx) => {
    const existing = await tx.getJob(jobId);
    if (!existing) throw new DomainError('not_found');
    if (existing.customerId !== uid) throw new DomainError('permission_denied');
    if (existing.status !== 'open') throw new DomainError('conflict');
    if (existing.quoteCount > 0) throw new DomainError('conflict');
    if (checkoutActive(existing, now)) throw new DomainError('conflict');

    const fields = validateJobInput(raw, now);
    for (const ref of fields.references) {
      if (!deps.media.isOwnReference(ref.url, ref.path, uid)) {
        throw new DomainError('invalid_argument', 'references');
      }
    }

    const updated: JobRecord = {
      ...existing,
      ...fields,
      quoteDeadline: existing.quoteDeadline, // deadline stays as originally set
      version: existing.version + 1,
      updatedAt: now,
    };
    tx.putJob(updated);
  });

  return { jobId };
}

export async function extendJob(
  deps: JobDeps,
  uid: string,
  raw: unknown,
): Promise<{ quoteDeadline: Date }> {
  if (typeof raw !== 'object' || raw === null) throw new DomainError('invalid_argument');
  const jobId = (raw as Record<string, unknown>).jobId;
  if (typeof jobId !== 'string') throw new DomainError('invalid_argument', 'jobId');

  const now = deps.clock.now();

  return await deps.jobs.runTransaction(async (tx) => {
    const job = await tx.getJob(jobId);
    if (!job) throw new DomainError('not_found');
    if (job.customerId !== uid) throw new DomainError('permission_denied');
    if (job.status !== 'open') throw new DomainError('conflict');
    if (job.extended) throw new DomainError('not_eligible');

    const newDeadline = new Date(job.quoteDeadline.getTime() + JOB_EXTEND_DAYS * 24 * 60 * 60 * 1000);
    const newDeadlineVnDate = formatVnDate(newDeadline);

    // Shoot day must be after the VN date of quote deadline
    if (job.dayFrom <= newDeadlineVnDate) {
      throw new DomainError('not_eligible');
    }

    const updated: JobRecord = {
      ...job,
      quoteDeadline: newDeadline,
      extended: true,
      expiringNotifiedAt: null, // resets expiringNotifiedAt so a new 24h notice can fire
      version: job.version + 1,
      updatedAt: now,
    };
    tx.putJob(updated);

    return { quoteDeadline: newDeadline };
  });
}

export async function closeJob(
  deps: JobDeps,
  uid: string,
  raw: unknown,
): Promise<void> {
  if (typeof raw !== 'object' || raw === null) throw new DomainError('invalid_argument');
  const jobId = (raw as Record<string, unknown>).jobId;
  if (typeof jobId !== 'string') throw new DomainError('invalid_argument', 'jobId');

  const now = deps.clock.now();

  await deps.jobs.runTransaction(async (tx) => {
    const job = await tx.getJob(jobId);
    if (!job) throw new DomainError('not_found');
    if (job.customerId !== uid) throw new DomainError('permission_denied');
    if (job.status !== 'open') throw new DomainError('conflict');
    if (checkoutActive(job, now)) throw new DomainError('conflict');

    const quotes = await tx.listQuotes(jobId);
    const invites = await tx.listInvites(jobId);
    const matches = await tx.listMatches(jobId);

    for (const q of quotes) {
      if (q.status === 'submitted') {
        tx.putQuote({
          ...q,
          status: 'not_selected',
          notSelectedReason: 'closed',
          version: q.version + 1,
          updatedAt: now,
        });
      }
    }

    for (const inv of invites) {
      if (inv.jobStatus === 'open') {
        tx.putInvite({ ...inv, jobStatus: 'closed' });
      }
    }

    for (const m of matches) {
      if (m.jobStatus === 'open') {
        tx.putMatch({ ...m, jobStatus: 'closed' });
      }
    }

    const updated: JobRecord = {
      ...job,
      status: 'closed',
      closedAt: now,
      referencesPurgeAfter: new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000),
      version: job.version + 1,
      updatedAt: now,
    };
    tx.putJob(updated);
  });
}

export async function inviteToJob(
  deps: JobDeps,
  uid: string,
  raw: unknown,
): Promise<{ invited: string[] }> {
  if (typeof raw !== 'object' || raw === null) throw new DomainError('invalid_argument');
  const r = raw as Record<string, unknown>;
  const jobId = r.jobId;
  const photographerIds = r.photographerIds;
  if (typeof jobId !== 'string') throw new DomainError('invalid_argument', 'jobId');
  if (!Array.isArray(photographerIds) || photographerIds.length === 0 || photographerIds.length > 5) {
    throw new DomainError('invalid_argument', 'photographerIds');
  }

  const now = deps.clock.now();

  // Read job
  const job = await deps.jobs.runTransaction(async (tx) => tx.getJob(jobId));
  if (!job) throw new DomainError('not_found');
  if (job.customerId !== uid) throw new DomainError('permission_denied');
  if (job.status !== 'open') throw new DomainError('conflict');
  if (deadlinePassed(job, now)) throw new DomainError('deadline_passed');

  // Verify total invites limit
  if (job.inviteCount + photographerIds.length > INVITES_PER_JOB) {
    throw new DomainError('limit_exceeded');
  }

  // Order gate checks for each id
  for (const pid of photographerIds) {
    const blockedReason = await orderBlocker(deps, { customerId: uid, providerId: pid });
    if (blockedReason === 'not_accepting_orders') {
      throw new DomainError('not_accepting_orders');
    }
    if (blockedReason === 'blocked') {
      throw new DomainError('blocked');
    }
  }

  const newInvited: string[] = [];

  for (const pid of photographerIds) {
    const provider = await deps.people.provider(pid);
    if (!provider || provider.role !== 'photographer') {
      throw new DomainError('not_eligible');
    }
    if (!jobInServiceArea(job.area, provider.serviceArea)) {
      throw new DomainError('not_eligible');
    }
    if (!providerTypeAllowed(job.allowedProviders, provider.providerType)) {
      throw new DomainError('not_eligible');
    }
  }

  await deps.jobs.runTransaction(async (tx) => {
    const currentJob = await tx.getJob(jobId);
    if (!currentJob) throw new DomainError('not_found');

    const existingInvites = await tx.listInvites(jobId);
    const existingQuotes = await tx.listQuotes(jobId);

    const invitedSet = new Set(existingInvites.map((i) => i.photographerId));
    const quotedSet = new Set(existingQuotes.map((q) => q.photographerId));

    for (const pid of photographerIds) {
      if (invitedSet.has(pid) || quotedSet.has(pid)) {
        continue; // skip
      }

      newInvited.push(pid);
    }

    if (currentJob.inviteCount + newInvited.length > INVITES_PER_JOB) {
      throw new DomainError('limit_exceeded');
    }

    for (const pid of newInvited) {
      const p = await deps.people.provider(pid);
      if (!p) throw new DomainError('not_eligible');
      const state = await deps.people.dayState(pid, currentJob.dayFrom);
      const dayArg: 'free' | 'pending' | 'busy' =
        state === 'booked' || state === 'off' ? 'busy' : state;
      const fit = jobFit(currentJob, p, dayArg);

      tx.putInvite({
        id: pid,
        jobId,
        photographerId: pid,
        customerId: uid,
        fit,
        jobStatus: 'open',
        createdAt: now,
        seenAt: null,
      });
    }

    tx.putJob({
      ...currentJob,
      inviteCount: currentJob.inviteCount + newInvited.length,
      version: currentJob.version + 1,
      updatedAt: now,
    });
  });

  return { invited: newInvited };
}
