import {
  Timestamp,
  type DocumentData,
  type Firestore,
} from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import {
  JOB_STATUSES,
  QUOTE_STATUSES,
  type JobRecord,
  type QuoteRecord,
  type JobInviteRecord,
  type JobMatchRecord,
  type JobStatus,
  type QuoteStatus,
  type AllowedProviders,
  type ScheduleKind,
  type JobStore,
  type JobTx,
  type JobPeople,
  type JobMedia,
  type JobProviderProfile,
  type ProviderType,
} from '@photobooking/domain';
import { storageUrlPrefixes } from '../config.js';

function toDate(v: unknown): Date | null {
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  if (typeof v === 'string' || typeof v === 'number') {
    const d = new Date(v);
    if (!isNaN(d.getTime())) return d;
  }
  return null;
}

function toTimestamp(d: Date | null | undefined): Timestamp | null {
  if (!d) return null;
  return Timestamp.fromDate(d);
}

export function jobToFirestore(job: JobRecord): DocumentData {
  return {
    customerId: job.customerId,
    customer: {
      name: job.customer.name,
      avatarUrl: job.customer.avatarUrl ?? null,
      hireCount: job.customer.hireCount,
      phoneVerified: job.customer.phoneVerified,
    },
    specialtyId: job.specialtyId,
    title: job.title,
    description: job.description,
    references: job.references.map((r) => ({ url: r.url, path: r.path })),
    schedule: {
      kind: job.schedule.kind,
      day: job.schedule.day ?? null,
      start: job.schedule.start ?? null,
      end: job.schedule.end ?? null,
      from: job.schedule.from ?? null,
      to: job.schedule.to ?? null,
      durationMinutes: job.schedule.durationMinutes,
    },
    dayFrom: job.dayFrom,
    dayTo: job.dayTo,
    area: {
      areaId: job.area.areaId,
      name: job.area.name,
      city: job.area.city,
      cityKey: job.area.cityKey,
      lat: job.area.lat,
      lng: job.area.lng,
      geohash5: job.area.geohash5,
    },
    budget: job.budget ? { min: job.budget.min, max: job.budget.max } : null,
    wants: {
      editedCount: job.wants.editedCount ?? null,
      deliveryDays: job.wants.deliveryDays ?? null,
    },
    allowedProviders: job.allowedProviders,
    quoteDeadline: toTimestamp(job.quoteDeadline),
    extended: job.extended,
    status: job.status,
    quoteCount: job.quoteCount,
    newQuoteCount: job.newQuoteCount,
    viewCount: job.viewCount,
    inviteCount: job.inviteCount,
    matchCount: job.matchCount,
    recentQuoters: job.recentQuoters.map((q) => ({
      photographerId: q.photographerId,
      avatarUrl: q.avatarUrl ?? null,
    })),
    awardedQuoteId: job.awardedQuoteId ?? null,
    bookingId: job.bookingId ?? null,
    awardedTo: job.awardedTo
      ? {
          photographerId: job.awardedTo.photographerId,
          name: job.awardedTo.name,
          price: job.awardedTo.price,
        }
      : null,
    checkout: job.checkout
      ? {
          quoteId: job.checkout.quoteId,
          bookingId: job.checkout.bookingId,
          expiresAt: toTimestamp(job.checkout.expiresAt),
        }
      : null,
    expiringNotifiedAt: toTimestamp(job.expiringNotifiedAt),
    closedAt: toTimestamp(job.closedAt),
    referencesPurgeAfter: toTimestamp(job.referencesPurgeAfter),
    quotesSeenAt: toTimestamp(job.quotesSeenAt),
    version: job.version,
    createdAt: toTimestamp(job.createdAt),
    updatedAt: toTimestamp(job.updatedAt),
  };
}

export function jobFromFirestore(id: string, d: DocumentData | undefined): JobRecord | null {
  if (!d) return null;
  if (!JOB_STATUSES.includes(d.status as JobStatus)) return null;
  if (
    typeof d.customerId !== 'string' ||
    typeof d.specialtyId !== 'string' ||
    typeof d.title !== 'string' ||
    typeof d.description !== 'string' ||
    !d.schedule ||
    typeof d.dayFrom !== 'string' ||
    typeof d.dayTo !== 'string' ||
    !d.area
  ) {
    return null;
  }

  const quoteDeadline = toDate(d.quoteDeadline);
  const createdAt = toDate(d.createdAt);
  const updatedAt = toDate(d.updatedAt);
  if (!quoteDeadline || !createdAt || !updatedAt) return null;

  const checkout =
    d.checkout && typeof d.checkout === 'object' && d.checkout.quoteId && d.checkout.bookingId && d.checkout.expiresAt
      ? {
          quoteId: String(d.checkout.quoteId),
          bookingId: String(d.checkout.bookingId),
          expiresAt: toDate(d.checkout.expiresAt) ?? new Date(0),
        }
      : null;

  return {
    id,
    customerId: d.customerId,
    customer: {
      name: String(d.customer?.name ?? ''),
      avatarUrl: typeof d.customer?.avatarUrl === 'string' ? d.customer.avatarUrl : null,
      hireCount: Number(d.customer?.hireCount ?? 0),
      phoneVerified: Boolean(d.customer?.phoneVerified),
    },
    specialtyId: d.specialtyId,
    title: d.title,
    description: d.description,
    references: Array.isArray(d.references)
      ? d.references.map((r: Record<string, unknown>) => ({ url: String(r?.url ?? ''), path: String(r?.path ?? '') }))
      : [],
    schedule: {
      kind: (d.schedule.kind as ScheduleKind) || 'fixed',
      day: typeof d.schedule.day === 'string' ? d.schedule.day : null,
      start: typeof d.schedule.start === 'string' ? d.schedule.start : null,
      end: typeof d.schedule.end === 'string' ? d.schedule.end : null,
      from: typeof d.schedule.from === 'string' ? d.schedule.from : null,
      to: typeof d.schedule.to === 'string' ? d.schedule.to : null,
      durationMinutes: Number(d.schedule.durationMinutes ?? 120),
    },
    dayFrom: d.dayFrom,
    dayTo: d.dayTo,
    area: {
      areaId: String(d.area.areaId ?? ''),
      name: String(d.area.name ?? ''),
      city: String(d.area.city ?? ''),
      cityKey: String(d.area.cityKey ?? ''),
      lat: Number(d.area.lat ?? 0),
      lng: Number(d.area.lng ?? 0),
      geohash5: String(d.area.geohash5 ?? ''),
    },
    budget:
      d.budget && typeof d.budget.min === 'number' && typeof d.budget.max === 'number'
        ? { min: d.budget.min, max: d.budget.max }
        : null,
    wants: {
      editedCount: typeof d.wants?.editedCount === 'number' ? d.wants.editedCount : null,
      deliveryDays: typeof d.wants?.deliveryDays === 'number' ? d.wants.deliveryDays : null,
    },
    allowedProviders: (d.allowedProviders as AllowedProviders) || 'all',
    quoteDeadline,
    extended: Boolean(d.extended),
    status: d.status as JobStatus,
    quoteCount: Number(d.quoteCount ?? 0),
    newQuoteCount: Number(d.newQuoteCount ?? 0),
    viewCount: Number(d.viewCount ?? 0),
    inviteCount: Number(d.inviteCount ?? 0),
    matchCount: Number(d.matchCount ?? 0),
    recentQuoters: Array.isArray(d.recentQuoters)
      ? d.recentQuoters.map((q: Record<string, unknown>) => ({
          photographerId: String(q?.photographerId ?? ''),
          avatarUrl: typeof q?.avatarUrl === 'string' ? q.avatarUrl : null,
        }))
      : [],
    awardedQuoteId: typeof d.awardedQuoteId === 'string' ? d.awardedQuoteId : null,
    bookingId: typeof d.bookingId === 'string' ? d.bookingId : null,
    awardedTo:
      d.awardedTo && typeof d.awardedTo.photographerId === 'string'
        ? {
            photographerId: d.awardedTo.photographerId,
            name: String(d.awardedTo.name ?? ''),
            price: Number(d.awardedTo.price ?? 0),
          }
        : null,
    checkout,
    expiringNotifiedAt: toDate(d.expiringNotifiedAt),
    closedAt: toDate(d.closedAt),
    referencesPurgeAfter: toDate(d.referencesPurgeAfter),
    quotesSeenAt: toDate(d.quotesSeenAt),
    version: Number(d.version ?? 1),
    createdAt,
    updatedAt,
  };
}

export function quoteToFirestore(quote: QuoteRecord): DocumentData {
  return {
    jobId: quote.jobId,
    photographerId: quote.photographerId,
    customerId: quote.customerId,
    jobTitle: quote.jobTitle,
    photographer: {
      name: quote.photographer.name,
      avatarUrl: quote.photographer.avatarUrl ?? null,
      providerType: quote.photographer.providerType,
      verified: quote.photographer.verified,
      tomatoPct: quote.photographer.tomatoPct,
      score: quote.photographer.score,
      reviewCount: quote.photographer.reviewCount,
      completedCount: quote.photographer.completedCount,
      approvedAwardCount: quote.photographer.approvedAwardCount,
      studioDistrict: quote.photographer.studioDistrict ?? null,
    },
    basedOnServiceId: quote.basedOnServiceId ?? null,
    terms: {
      price: quote.terms.price,
      durationMinutes: quote.terms.durationMinutes,
      photoCount: quote.terms.photoCount ?? null,
      editedCount: quote.terms.editedCount,
      deliveryDays: quote.terms.deliveryDays,
      revisions: quote.terms.revisions,
      milestones: quote.terms.milestones.map((m) => ({ kind: m.kind, percent: m.percent })),
    },
    milestoneAmounts: {
      shoot: quote.milestoneAmounts.shoot,
      delivery: quote.milestoneAmounts.delivery,
    },
    proposal: {
      day: quote.proposal.day,
      start: quote.proposal.start,
      end: quote.proposal.end,
    },
    message: quote.message,
    albumId: quote.albumId ?? null,
    album: quote.album
      ? {
          title: quote.album.title,
          coverUrl: quote.album.coverUrl ?? null,
          postCount: quote.album.postCount,
        }
      : null,
    invited: quote.invited,
    fit: quote.fit,
    status: quote.status,
    notSelectedReason: quote.notSelectedReason ?? null,
    autoWithdrawn: quote.autoWithdrawn,
    declineReason: quote.declineReason ?? null,
    bookingId: quote.bookingId ?? null,
    withdrawnAt: toTimestamp(quote.withdrawnAt),
    version: quote.version,
    createdAt: toTimestamp(quote.createdAt),
    updatedAt: toTimestamp(quote.updatedAt),
  };
}

export function quoteFromFirestore(id: string, d: DocumentData | undefined): QuoteRecord | null {
  if (!d) return null;
  if (!QUOTE_STATUSES.includes(d.status as QuoteStatus)) return null;
  if (
    typeof d.jobId !== 'string' ||
    typeof d.photographerId !== 'string' ||
    typeof d.customerId !== 'string' ||
    typeof d.jobTitle !== 'string' ||
    !d.photographer ||
    !d.terms ||
    !d.milestoneAmounts ||
    !d.proposal ||
    typeof d.message !== 'string'
  ) {
    return null;
  }

  const createdAt = toDate(d.createdAt);
  const updatedAt = toDate(d.updatedAt);
  if (!createdAt || !updatedAt) return null;

  const milestones: { kind: 'shoot' | 'delivery'; percent: number }[] = [];
  if (Array.isArray(d.terms.milestones)) {
    for (const m of d.terms.milestones) {
      if (m && (m.kind === 'shoot' || m.kind === 'delivery') && typeof m.percent === 'number') {
        milestones.push({ kind: m.kind, percent: m.percent });
      }
    }
  }

  return {
    id,
    jobId: d.jobId,
    photographerId: d.photographerId,
    customerId: d.customerId,
    jobTitle: d.jobTitle,
    photographer: {
      name: String(d.photographer.name ?? ''),
      avatarUrl: typeof d.photographer.avatarUrl === 'string' ? d.photographer.avatarUrl : null,
      providerType: String(d.photographer.providerType ?? 'individual'),
      verified: Boolean(d.photographer.verified),
      tomatoPct: Number(d.photographer.tomatoPct ?? 0),
      score: Number(d.photographer.score ?? 0),
      reviewCount: Number(d.photographer.reviewCount ?? 0),
      completedCount: Number(d.photographer.completedCount ?? 0),
      approvedAwardCount: Number(d.photographer.approvedAwardCount ?? 0),
      studioDistrict: typeof d.photographer.studioDistrict === 'string' ? d.photographer.studioDistrict : null,
    },
    basedOnServiceId: typeof d.basedOnServiceId === 'string' ? d.basedOnServiceId : null,
    terms: {
      price: Number(d.terms.price ?? 0),
      durationMinutes: Number(d.terms.durationMinutes ?? 120),
      photoCount: typeof d.terms.photoCount === 'number' ? d.terms.photoCount : null,
      editedCount: Number(d.terms.editedCount ?? 0),
      deliveryDays: Number(d.terms.deliveryDays ?? 7),
      revisions: Number(d.terms.revisions ?? 1),
      milestones,
    },
    milestoneAmounts: {
      shoot: Number(d.milestoneAmounts.shoot ?? 0),
      delivery: Number(d.milestoneAmounts.delivery ?? 0),
    },
    proposal: {
      day: String(d.proposal.day ?? ''),
      start: String(d.proposal.start ?? ''),
      end: String(d.proposal.end ?? ''),
    },
    message: d.message,
    albumId: typeof d.albumId === 'string' ? d.albumId : null,
    album:
      d.album && typeof d.album.title === 'string'
        ? {
            title: d.album.title,
            coverUrl: typeof d.album.coverUrl === 'string' ? d.album.coverUrl : null,
            postCount: Number(d.album.postCount ?? 0),
          }
        : null,
    invited: Boolean(d.invited),
    fit: Number(d.fit ?? 0),
    status: d.status as QuoteStatus,
    notSelectedReason:
      d.notSelectedReason === 'expired' ||
      d.notSelectedReason === 'closed' ||
      d.notSelectedReason === 'awarded'
        ? d.notSelectedReason
        : null,
    autoWithdrawn: Boolean(d.autoWithdrawn),
    declineReason: typeof d.declineReason === 'string' ? d.declineReason : null,
    bookingId: typeof d.bookingId === 'string' ? d.bookingId : null,
    withdrawnAt: toDate(d.withdrawnAt),
    version: Number(d.version ?? 1),
    createdAt,
    updatedAt,
  };
}

export function inviteToFirestore(invite: JobInviteRecord): DocumentData {
  return {
    jobId: invite.jobId,
    photographerId: invite.photographerId,
    customerId: invite.customerId,
    fit: invite.fit,
    jobStatus: invite.jobStatus,
    createdAt: toTimestamp(invite.createdAt),
    seenAt: toTimestamp(invite.seenAt),
  };
}

export function inviteFromFirestore(id: string, d: DocumentData | undefined): JobInviteRecord | null {
  if (!d) return null;
  if (typeof d.jobId !== 'string' || typeof d.photographerId !== 'string' || typeof d.customerId !== 'string') {
    return null;
  }
  const createdAt = toDate(d.createdAt);
  if (!createdAt) return null;

  return {
    id,
    jobId: d.jobId,
    photographerId: d.photographerId,
    customerId: d.customerId,
    fit: Number(d.fit ?? 0),
    jobStatus: d.jobStatus === 'closed' ? 'closed' : 'open',
    createdAt,
    seenAt: toDate(d.seenAt),
  };
}

export function matchToFirestore(match: JobMatchRecord): DocumentData {
  return {
    jobId: match.jobId,
    photographerId: match.photographerId,
    fit: match.fit,
    jobStatus: match.jobStatus,
    createdAt: toTimestamp(match.createdAt),
  };
}

export function matchFromFirestore(id: string, d: DocumentData | undefined): JobMatchRecord | null {
  if (!d) return null;
  if (typeof d.jobId !== 'string' || typeof d.photographerId !== 'string') {
    return null;
  }
  const createdAt = toDate(d.createdAt);
  if (!createdAt) return null;

  return {
    id,
    jobId: d.jobId,
    photographerId: d.photographerId,
    fit: Number(d.fit ?? 0),
    jobStatus: d.jobStatus === 'closed' ? 'closed' : 'open',
    createdAt,
  };
}

export class FirestoreJobStore implements JobStore {
  constructor(private readonly firestore: Firestore) {}

  async runTransaction<T>(fn: (tx: JobTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (adminTx) => {
      const tx: JobTx = {
        getJob: async (id: string) => {
          const snap = await adminTx.get(this.firestore.collection('jobs').doc(id));
          return jobFromFirestore(snap.id, snap.data());
        },
        getQuote: async (jobId: string, photographerId: string) => {
          const snap = await adminTx.get(
            this.firestore.collection('jobs').doc(jobId).collection('quotes').doc(photographerId),
          );
          return quoteFromFirestore(snap.id, snap.data());
        },
        getInvite: async (jobId: string, photographerId: string) => {
          const snap = await adminTx.get(
            this.firestore.collection('jobs').doc(jobId).collection('invites').doc(photographerId),
          );
          return inviteFromFirestore(snap.id, snap.data());
        },
        listQuotes: async (jobId: string) => {
          const snap = await adminTx.get(
            this.firestore.collection('jobs').doc(jobId).collection('quotes').limit(100),
          );
          return snap.docs.map((d) => quoteFromFirestore(d.id, d.data())).filter((q): q is QuoteRecord => q !== null);
        },
        listInvites: async (jobId: string) => {
          const snap = await adminTx.get(this.firestore.collection('jobs').doc(jobId).collection('invites'));
          return snap.docs.map((d) => inviteFromFirestore(d.id, d.data())).filter((i): i is JobInviteRecord => i !== null);
        },
        listMatches: async (jobId: string) => {
          const snap = await adminTx.get(this.firestore.collection('jobs').doc(jobId).collection('matches'));
          return snap.docs.map((d) => matchFromFirestore(d.id, d.data())).filter((m): m is JobMatchRecord => m !== null);
        },
        putJob: (j: JobRecord) => {
          adminTx.set(this.firestore.collection('jobs').doc(j.id), jobToFirestore(j));
        },
        putQuote: (q: QuoteRecord) => {
          adminTx.set(
            this.firestore.collection('jobs').doc(q.jobId).collection('quotes').doc(q.photographerId),
            quoteToFirestore(q),
          );
        },
        putInvite: (i: JobInviteRecord) => {
          adminTx.set(
            this.firestore.collection('jobs').doc(i.jobId).collection('invites').doc(i.photographerId),
            inviteToFirestore(i),
          );
        },
        putMatch: (m: JobMatchRecord) => {
          adminTx.set(
            this.firestore.collection('jobs').doc(m.jobId).collection('matches').doc(m.photographerId),
            matchToFirestore(m),
          );
        },
      };
      return await fn(tx);
    });
  }

  async countOpenJobs(customerId: string): Promise<number> {
    const snap = await this.firestore
      .collection('jobs')
      .where('customerId', '==', customerId)
      .where('status', '==', 'open')
      .count()
      .get();
    return snap.data().count;
  }

  async countSubmittedQuotes(photographerId: string): Promise<number> {
    const snap = await this.firestore
      .collectionGroup('quotes')
      .where('photographerId', '==', photographerId)
      .where('status', '==', 'submitted')
      .count()
      .get();
    return snap.data().count;
  }

  async submittedQuotesOnDay(photographerId: string, day: string): Promise<QuoteRecord[]> {
    const snap = await this.firestore
      .collectionGroup('quotes')
      .where('photographerId', '==', photographerId)
      .where('status', '==', 'submitted')
      .where('proposal.day', '==', day)
      .get();
    return snap.docs.map((d) => quoteFromFirestore(d.id, d.data())).filter((q): q is QuoteRecord => q !== null);
  }

  async dueForExpiry(now: Date, limit: number): Promise<JobRecord[]> {
    const snap = await this.firestore
      .collection('jobs')
      .where('status', '==', 'open')
      .where('quoteDeadline', '<=', Timestamp.fromDate(now))
      .limit(limit)
      .get();
    return snap.docs.map((d) => jobFromFirestore(d.id, d.data())).filter((j): j is JobRecord => j !== null);
  }

  async dueForExpiringNotice(now: Date, limit: number): Promise<JobRecord[]> {
    const deadlineThreshold = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const snap = await this.firestore
      .collection('jobs')
      .where('status', '==', 'open')
      .where('expiringNotifiedAt', '==', null)
      .where('quoteDeadline', '<=', Timestamp.fromDate(deadlineThreshold))
      .limit(limit)
      .get();
    return snap.docs.map((d) => jobFromFirestore(d.id, d.data())).filter((j): j is JobRecord => j !== null);
  }

  async dueForReferencePurge(now: Date, limit: number): Promise<JobRecord[]> {
    const snap = await this.firestore
      .collection('jobs')
      .where('referencesPurgeAfter', '<=', Timestamp.fromDate(now))
      .limit(limit)
      .get();
    return snap.docs.map((d) => jobFromFirestore(d.id, d.data())).filter((j): j is JobRecord => j !== null);
  }
}

function mapToJobProviderProfile(
  uid: string,
  p: DocumentData,
  u?: DocumentData,
): JobProviderProfile {
  const stats = (p.stats ?? {}) as Record<string, unknown>;
  const serviceArea = p.serviceArea
    ? {
        city: String(p.serviceArea.city ?? ''),
        radiusKm: Number(p.serviceArea.radiusKm ?? 0),
        center: p.serviceArea.center
          ? {
              lat: Number(p.serviceArea.center.latitude ?? p.serviceArea.center.lat ?? 0),
              lng: Number(p.serviceArea.center.longitude ?? p.serviceArea.center.lng ?? 0),
            }
          : null,
      }
    : null;

  return {
    uid,
    role: u?.role ? String(u.role) : 'photographer',
    onboardingComplete: Boolean(p.onboardingComplete),
    acceptingOrdersFields: {
      verified: p.verified,
      onboardingComplete: p.onboardingComplete,
    },
    providerType: (p.providerType as ProviderType) ?? 'individual',
    specialties: Array.isArray(p.specialties)
      ? p.specialties.filter((s: unknown): s is string => typeof s === 'string')
      : [],
    serviceArea,
    startingPrice: typeof p.startingPrice === 'number' ? p.startingPrice : null,
    tomatoPct: Number(stats.tomatoPct ?? 0),
    score: Number(stats.score ?? 0),
    reviewCount: Number(stats.reviewCount ?? 0),
    completedCount: Number(stats.completedCount ?? 0),
    approvedAwardCount: Number(p.approvedAwardCount ?? stats.approvedAwardCount ?? 0),
    verified: Boolean(p.verified),
    name: String(u?.displayName ?? p.displayName ?? ''),
    avatarUrl: (u?.avatarUrl as string) ?? (p.avatarUrl as string) ?? null,
    studioDistrict: typeof p.studioDistrict === 'string' ? p.studioDistrict : null,
  };
}

export function firestoreJobPeople(firestore: Firestore): JobPeople {
  return {
    customer: async (uid: string) => {
      const [userSnap, contactSnap, bookingCountSnap] = await Promise.all([
        firestore.collection('users').doc(uid).get(),
        firestore.collection('users').doc(uid).collection('private').doc('contact').get(),
        firestore
          .collection('bookings')
          .where('customerId', '==', uid)
          .where('status', 'in', ['completed', 'reviewed'])
          .count()
          .get(),
      ]);
      if (!userSnap.exists) return null;
      const uData = userSnap.data();
      if (!uData) return null;
      return {
        role: uData.role ? String(uData.role) : null,
        name: String(uData.displayName ?? ''),
        avatarUrl: uData.avatarUrl ? String(uData.avatarUrl) : null,
        phoneVerified: Boolean(contactSnap.data()?.phoneVerified),
        hireCount: bookingCountSnap.data().count,
      };
    },

    provider: async (uid: string) => {
      const snaps = await firestore.getAll(
        firestore.collection('photographers').doc(uid),
        firestore.collection('users').doc(uid),
      );
      const photoSnap = snaps[0];
      const userSnap = snaps[1];
      if (!photoSnap || !photoSnap.exists) return null;
      const photoData = photoSnap.data();
      if (!photoData) return null;
      return mapToJobProviderProfile(uid, photoData, userSnap?.exists ? userSnap.data() : undefined);
    },

    candidates: async (specialtyId: string, limit: number) => {
      const snap = await firestore
        .collection('photographers')
        .where('acceptingOrders', '==', true)
        .where('specialties', 'array-contains', specialtyId)
        .limit(limit)
        .get();
      if (snap.empty) return [];

      const userRefs = snap.docs.map((d) => firestore.collection('users').doc(d.id));
      const userSnaps = await firestore.getAll(...userRefs);
      const userMap = new Map<string, DocumentData>();
      for (const u of userSnaps) {
        const uData = u.data();
        if (u.exists && uData) userMap.set(u.id, uData);
      }

      return snap.docs.map((d) => {
        const pData = d.data();
        const uData = userMap.get(d.id);
        return mapToJobProviderProfile(d.id, pData, uData);
      });
    },

    dayState: async (photographerId: string, day: string) => {
      const snap = await firestore
        .collection('availability')
        .doc(photographerId)
        .collection('days')
        .doc(day)
        .get();
      if (!snap.exists) return 'free';
      const state = snap.data()?.state;
      if (state === 'pending' || state === 'booked' || state === 'off') return state;
      return 'free';
    },

    dayBookingId: async (photographerId: string, day: string) => {
      const snap = await firestore
        .collection('availability')
        .doc(photographerId)
        .collection('days')
        .doc(day)
        .get();
      if (!snap.exists) return null;
      const d = snap.data();
      return typeof d?.bookingId === 'string' ? d.bookingId : null;
    },

    service: async (photographerId: string, serviceId: string) => {
      const snap = await firestore
        .collection('photographers')
        .doc(photographerId)
        .collection('services')
        .doc(serviceId)
        .get();
      if (!snap.exists) return null;
      const d = snap.data();
      if (!d) return null;
      return {
        active: d.active !== false,
        photoCount:
          typeof d.deliverables?.photoCount === 'number'
            ? d.deliverables.photoCount
            : typeof d.photoCount === 'number'
              ? d.photoCount
              : null,
        editedCount:
          typeof d.deliverables?.editedCount === 'number'
            ? d.deliverables.editedCount
            : typeof d.editedCount === 'number'
              ? d.editedCount
              : null,
        deliveryDays:
          typeof d.deliverables?.deliveryDays === 'number'
            ? d.deliverables.deliveryDays
            : typeof d.deliveryDays === 'number'
              ? d.deliveryDays
              : null,
        price: typeof d.price === 'number' ? d.price : 0,
      };
    },

    album: async (albumId: string) => {
      const snap = await firestore.collection('albums').doc(albumId).get();
      if (!snap.exists) return null;
      const d = snap.data();
      if (!d) return null;
      return {
        photographerId: String(d.photographerId ?? ''),
        title: String(d.title ?? ''),
        coverUrl: typeof d.coverUrl === 'string' ? d.coverUrl : null,
        postCount: typeof d.postCount === 'number' ? d.postCount : 0,
      };
    },
  };
}

export function ownReferenceUpload(prefixes: readonly string[]) {
  return (url: string, path: string, uid: string): boolean => {
    if (!path.startsWith(`jobRefs/${uid}/`)) return false;
    const prefix = prefixes.find((p) => url.startsWith(p));
    if (prefix === undefined) return false;
    const object = url.slice(prefix.length).split('?')[0] ?? '';
    try {
      return decodeURIComponent(object) === path;
    } catch {
      return false;
    }
  };
}

export function firestoreJobMedia(): JobMedia {
  const prefixes = storageUrlPrefixes();
  const checker = ownReferenceUpload(prefixes);
  return {
    isOwnReference: (url: string, path: string, uid: string) => checker(url, path, uid),
    deleteReference: async (path: string) => {
      try {
        const bucket = getStorage().bucket();
        await bucket.file(path).delete({ ignoreNotFound: true });
      } catch (err: unknown) {
        if ((err as { code?: number })?.code === 404) return;
      }
    },
  };
}
