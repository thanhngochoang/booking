/**
 * Firestore adapters of the S27 recruit ports (#151): the `RecruitStore` transaction over posts, applications,
 * collaborations (+ history), collab jobs, the server-only counters and S26's member writes; the sweep queries;
 * the fan-out query on `photographers.recruitMatchKeys`; and the people, owned-posts and shoot-milestone readers.
 * Every transaction reads before it writes (Admin SDK rule; the domain orders its calls that way).
 */

import { FieldValue, Timestamp, type DocumentData, type Firestore, type Transaction } from 'firebase-admin/firestore';
import {
  POACH_WINDOW_DAYS,
  acceptsOrders,
  collabJobId,
  collaborationId,
  isOpenCollabJob,
  providerTypeOf,
  recruitApplicationId,
  shootMilestoneState,
  syncCollabJobOnBooking,
  type Booking,
  type CollabJob,
  type Collaboration,
  type DailyQuota,
  type Payment,
  type ProviderFacts,
  type RecruitApplication,
  type RecruitCounters,
  type RecruitMemberState,
  type RecruitPost,
  type RecruitStore,
  type RecruitTx,
  type ShootMilestoneState,
} from '@photobooking/domain';
import {
  COLLAB_JOBS_COLLECTION,
  RECRUIT_APPLICATIONS_COLLECTION,
  RECRUIT_COUNTERS_DOC,
  RECRUIT_POSTS_COLLECTION,
  STAFF_FLAGS_COLLECTION,
  STUDIO_COLLABORATIONS_COLLECTION,
  applicationFromDoc,
  applicationToDoc,
  collabJobFromDoc,
  collabJobToDoc,
  collaborationFromDoc,
  collaborationToDoc,
  countersFromDoc,
  countersToDoc,
  dateOf,
  recruitPostFromDoc,
  recruitPostToDoc,
} from './recruit_mapping.js';
import { BOOKINGS_COLLECTION, bookingFromFirestore } from './booking_firestore.js';
import {
  STUDIO_MEMBERS_COLLECTION,
  STUDIO_QUOTA_COLLECTION,
  relationToFirestore,
} from './studio_firestore.js';

const PHOTOGRAPHERS = 'photographers';
const USERS = 'users';
const POSTS = 'posts';
/** Firestore's cap on `array-contains-any` values. */
const ARRAY_CONTAINS_ANY_MAX = 30;
/** A pair has few jobs; enough to count the open ones without an unbounded read. */
const PAIR_JOBS_MAX = 200;

function present<T>(xs: readonly (T | null)[]): T[] {
  return xs.filter((x): x is T => x !== null);
}

export class FirestoreRecruitStore implements RecruitStore {
  constructor(
    private readonly firestore: Firestore,
    /** Time for the S26 open-invite count (a stale invite frees its seat before the sweep, as S26 does). */
    private readonly now: () => Date = () => new Date(),
  ) {}

  private col(name: string) {
    return this.firestore.collection(name);
  }

  private countersRef(uid: string) {
    return this.col(PHOTOGRAPHERS).doc(uid).collection('private').doc(RECRUIT_COUNTERS_DOC);
  }

  async runTransaction<T>(fn: (tx: RecruitTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx: Transaction) => {
      const tx: RecruitTx = {
        getPost: async (id) => {
          const snap = await fTx.get(this.col(RECRUIT_POSTS_COLLECTION).doc(id));
          return snap.exists ? recruitPostFromDoc(snap.id, snap.data()) : null;
        },
        getApplication: async (postId, uid) => {
          const snap = await fTx.get(this.col(RECRUIT_APPLICATIONS_COLLECTION).doc(recruitApplicationId(postId, uid)));
          return snap.exists ? applicationFromDoc(snap.id, snap.data()) : null;
        },
        getCollaboration: async (studioId, uid) => {
          const snap = await fTx.get(this.col(STUDIO_COLLABORATIONS_COLLECTION).doc(collaborationId(studioId, uid)));
          return snap.exists ? collaborationFromDoc(snap.id, snap.data()) : null;
        },
        getCounters: async (uid) => {
          const snap = await fTx.get(this.countersRef(uid));
          return countersFromDoc(snap.exists ? snap.data() : undefined);
        },
        activeMembershipStudioOf: async (uid) => {
          // S26's lock: read in the transaction, so a racing S26 join retries one side.
          const snap = await fTx.get(this.col(PHOTOGRAPHERS).doc(uid));
          const studioId = snap.data()?.studioId;
          return typeof studioId === 'string' && studioId !== '' ? studioId : null;
        },
        getMemberState: (studioId, uid) => this.memberState(fTx, studioId, uid),
        getCollabJob: async (bookingId, uid) => {
          const snap = await fTx.get(this.col(COLLAB_JOBS_COLLECTION).doc(collabJobId(bookingId, uid)));
          return snap.exists ? collabJobFromDoc(snap.id, snap.data()) : null;
        },
        putPost: (p) => {
          fTx.set(this.col(RECRUIT_POSTS_COLLECTION).doc(p.id), recruitPostToDoc(p));
        },
        putApplication: (a) => {
          fTx.set(this.col(RECRUIT_APPLICATIONS_COLLECTION).doc(a.id), applicationToDoc(a));
        },
        putCollaboration: (c) => {
          fTx.set(this.col(STUDIO_COLLABORATIONS_COLLECTION).doc(c.id), collaborationToDoc(c));
        },
        archiveCollaboration: (previous, historyId) => {
          fTx.set(
            this.col(STUDIO_COLLABORATIONS_COLLECTION).doc(previous.id).collection('history').doc(historyId),
            collaborationToDoc(previous),
          );
        },
        putCounters: (uid, c) => {
          fTx.set(this.countersRef(uid), countersToDoc(c));
        },
        putMember: (m) => {
          // S26's join, exactly as FirestoreStudioStore writes it (relation, lock, count, quota).
          const r = m.relation;
          fTx.set(this.col(STUDIO_MEMBERS_COLLECTION).doc(r.id), { ...relationToFirestore(r), applicationId: m.applicationId });
          fTx.set(
            this.col(PHOTOGRAPHERS).doc(r.memberId),
            { studioId: r.studioId, studioJoinedAt: r.joinedAt === null ? null : Timestamp.fromDate(new Date(r.joinedAt)) },
            { merge: true },
          );
          fTx.set(this.col(PHOTOGRAPHERS).doc(r.studioId), { memberCount: FieldValue.increment(1) }, { merge: true });
          fTx.set(this.col(STUDIO_QUOTA_COLLECTION).doc(r.studioId), quotaToDoc(m.quota));
        },
        putCollabJob: (j) => {
          fTx.set(this.col(COLLAB_JOBS_COLLECTION).doc(j.id), collabJobToDoc(j));
        },
      };
      return fn(tx);
    });
  }

  /** Decision 21: S26's activation inputs, read in the caller's transaction. */
  private async memberState(fTx: Transaction, studioId: string, uid: string): Promise<RecruitMemberState> {
    const [member, studio, quota, collab] = await fTx.getAll(
      this.col(PHOTOGRAPHERS).doc(uid),
      this.col(PHOTOGRAPHERS).doc(studioId),
      this.col(STUDIO_QUOTA_COLLECTION).doc(studioId),
      this.col(STUDIO_COLLABORATIONS_COLLECTION).doc(collaborationId(studioId, uid)),
    );
    const invites = await fTx.get(
      this.col(STUDIO_MEMBERS_COLLECTION).where('studioId', '==', studioId).where('status', '==', 'invited'),
    );
    const pair = await fTx.get(
      this.col(STUDIO_MEMBERS_COLLECTION)
        .where('studioId', '==', studioId)
        .where('memberId', '==', uid)
        .where('status', 'in', ['invited', 'requested'])
        .limit(1),
    );
    const m = member?.data() ?? {};
    const s = studio?.data() ?? {};
    const q = quota?.data();
    const now = this.now().getTime();
    const cooldown = dateOf(m.studioCooldownUntil);
    return {
      member: {
        studioId: typeof m.studioId === 'string' && m.studioId !== '' ? m.studioId : null,
        studioCooldownUntil: cooldown === null ? null : cooldown.toISOString(),
      },
      studio: { memberCount: typeof s.memberCount === 'number' ? s.memberCount : 0, businessVerified: s.businessVerified === true },
      // Same count as S26's countOpenInvites: invites past expiresAt no longer hold a seat.
      openInvites: invites.docs.filter((d) => (dateOf(d.data().expiresAt)?.getTime() ?? 0) > now).length,
      quota:
        q && typeof q.dayKey === 'string'
          ? {
              dayKey: q.dayKey,
              studioActions: typeof q.studioActions === 'number' ? q.studioActions : 0,
              memberActions: typeof q.memberActions === 'number' ? q.memberActions : 0,
            }
          : null,
      activeCollabWithStudio: collab?.exists === true && collab.data()?.status === 'active',
      pairOpen: !pair.empty,
    };
  }

  // ── queries (outside transactions; the use case re-reads each item in its own) ──

  async appliedOf(postId: string, limit: number): Promise<RecruitApplication[]> {
    const snap = await this.col(RECRUIT_APPLICATIONS_COLLECTION)
      .where('postId', '==', postId)
      .where('status', '==', 'applied')
      .orderBy('createdAt')
      .limit(limit)
      .get();
    return present(snap.docs.map((d) => applicationFromDoc(d.id, d.data())));
  }

  async duePosts(now: Date, limit: number): Promise<RecruitPost[]> {
    const snap = await this.col(RECRUIT_POSTS_COLLECTION)
      .where('status', '==', 'open')
      .where('expiresAt', '<=', Timestamp.fromDate(now))
      .orderBy('expiresAt')
      .limit(limit)
      .get();
    return present(snap.docs.map((d) => recruitPostFromDoc(d.id, d.data())));
  }

  async dueApplications(now: Date, limit: number): Promise<RecruitApplication[]> {
    const snap = await this.col(RECRUIT_APPLICATIONS_COLLECTION)
      .where('status', '==', 'applied')
      .where('expiresAt', '<=', Timestamp.fromDate(now))
      .orderBy('expiresAt')
      .limit(limit)
      .get();
    return present(snap.docs.map((d) => applicationFromDoc(d.id, d.data())));
  }

  async dueInvites(now: Date, limit: number): Promise<Collaboration[]> {
    const snap = await this.col(STUDIO_COLLABORATIONS_COLLECTION)
      .where('status', '==', 'invited')
      .where('expiresAt', '<=', Timestamp.fromDate(now))
      .orderBy('expiresAt')
      .limit(limit)
      .get();
    return present(snap.docs.map((d) => collaborationFromDoc(d.id, d.data())));
  }

  async openJobCount(studioId: string, uid: string): Promise<number> {
    const snap = await this.col(COLLAB_JOBS_COLLECTION)
      .where('studioId', '==', studioId)
      .where('collaboratorId', '==', uid)
      .limit(PAIR_JOBS_MAX)
      .get();
    return present(snap.docs.map((d) => collabJobFromDoc(d.id, d.data()))).filter(isOpenCollabJob).length;
  }

  async dueOffers(now: Date, limit: number): Promise<CollabJob[]> {
    const snap = await this.col(COLLAB_JOBS_COLLECTION)
      .where('offerStatus', '==', 'pending')
      .where('offerExpiresAt', '<=', Timestamp.fromDate(now))
      .orderBy('offerExpiresAt')
      .limit(limit)
      .get();
    return present(snap.docs.map((d) => collabJobFromDoc(d.id, d.data())));
  }

  async payPending(now: Date, limit: number): Promise<CollabJob[]> {
    const snap = await this.col(COLLAB_JOBS_COLLECTION)
      .where('offerStatus', '==', 'accepted')
      .where('payStatus', '==', 'none')
      .where('pay.checkAfter', '<=', Timestamp.fromDate(now))
      .orderBy('pay.checkAfter')
      .limit(limit)
      .get();
    return present(snap.docs.map((d) => collabJobFromDoc(d.id, d.data())));
  }

  async overduePay(cutoff: Date, limit: number): Promise<CollabJob[]> {
    const snap = await this.col(COLLAB_JOBS_COLLECTION)
      .where('payStatus', '==', 'due')
      .where('pay.overdueFlaggedAt', '==', null)
      .where('pay.dueAt', '<=', Timestamp.fromDate(cutoff))
      .orderBy('pay.dueAt')
      .limit(limit)
      .get();
    return present(snap.docs.map((d) => collabJobFromDoc(d.id, d.data())));
  }

  async unflaggedDisputes(limit: number): Promise<CollabJob[]> {
    const snap = await this.col(COLLAB_JOBS_COLLECTION)
      .where('payStatus', '==', 'disputed')
      .where('pay.disputeFlaggedAt', '==', null)
      .limit(limit)
      .get();
    return present(snap.docs.map((d) => collabJobFromDoc(d.id, d.data())));
  }

  /** Decision 8: one `array-contains-any` on the server-only `recruitMatchKeys` (single-field index), ids only. */
  async matchingProviders(matchKeys: readonly string[], limit: number): Promise<string[]> {
    const keys = [...new Set(matchKeys)].slice(0, ARRAY_CONTAINS_ANY_MAX);
    if (keys.length === 0) return [];
    const snap = await this.col(PHOTOGRAPHERS).where('recruitMatchKeys', 'array-contains-any', keys).select().limit(limit).get();
    return snap.docs.map((d) => d.id);
  }
}

function quotaToDoc(q: DailyQuota): Record<string, unknown> {
  return { dayKey: q.dayKey, studioActions: q.studioActions, memberActions: q.memberActions };
}

/** `users/{uid}` + `photographers/{uid}` → ProviderFacts; null without a photographer document. */
export class FirestoreRecruitPeople {
  constructor(private readonly firestore: Firestore) {}

  async provider(uid: string): Promise<ProviderFacts | null> {
    const [user, photographer] = await this.firestore.getAll(
      this.firestore.collection(USERS).doc(uid),
      this.firestore.collection(PHOTOGRAPHERS).doc(uid),
    );
    const p = photographer?.exists ? photographer.data() : undefined;
    if (!p) return null;
    const u = user?.exists ? (user.data() ?? {}) : {};
    return {
      uid,
      role: typeof u.role === 'string' ? u.role : null,
      providerType: providerTypeOf(p.providerType),
      // Same rule as the live order gate (verified and onboarded, not being deleted).
      acceptsOrders: p.deletionPending !== true && acceptsOrders(p),
      businessVerified: p.businessVerified === true,
      name: typeof u.displayName === 'string' ? u.displayName : '',
      avatarUrl: typeof u.avatarUrl === 'string' && u.avatarUrl !== '' ? u.avatarUrl : null,
    };
  }
}

/** Whether every id is a portfolio post (`posts/{id}`) of `uid`; at most 3 ids (APPLICATION_SAMPLES_MAX). */
export class FirestoreOwnedPosts {
  constructor(private readonly firestore: Firestore) {}

  async ownedBy(uid: string, postIds: readonly string[]): Promise<boolean> {
    if (postIds.length === 0) return true;
    const snaps = await this.firestore.getAll(...postIds.map((id) => this.firestore.collection(POSTS).doc(id)));
    return snaps.every((s) => s.exists && s.data()?.authorId === uid);
  }
}

/** Decision 15: the booking's shoot milestone, from its payments (payments V1). */
export class FirestoreShootMilestones {
  constructor(private readonly payments: { getPaymentsForBooking(bookingId: string): Promise<readonly Payment[]> }) {}

  async shootMilestone(bookingId: string): Promise<ShootMilestoneState> {
    return shootMilestoneState(await this.payments.getPaymentsForBooking(bookingId));
  }
}

/** The counters document of `uid`, read outside a transaction (tests and tools). */
export async function readRecruitCounters(firestore: Firestore, uid: string): Promise<RecruitCounters> {
  const snap = await firestore.collection(PHOTOGRAPHERS).doc(uid).collection('private').doc(RECRUIT_COUNTERS_DOC).get();
  return countersFromDoc(snap.exists ? snap.data() : undefined);
}

/** Jobs of one booking: a booking has a handful (one per offer). */
const BOOKING_JOBS_MAX = 20;
/** Personal bookings of one photographer with one customer read for the poaching signal. */
const PAIR_BOOKINGS_MAX = 50;
const DAY_MS = 24 * 60 * 60 * 1000;

/** The poaching flag: one per photographer and customer, ever (Decision 18 "once"). */
export const poachFlagId = (photographerId: string, customerId: string): string => `poach_${photographerId}_${customerId}`;

/** The reads and writes `onBookingWrite` needs for S27 (collab job sync, poaching signal). */
export class FirestoreCollabBookingSync {
  constructor(private readonly firestore: Firestore) {}

  /**
   * Applies `syncCollabJobOnBooking` to every job of the booking, each in a transaction that re-reads it, so a
   * re-fired event writes nothing. Returns how many jobs changed.
   */
  async syncJobs(booking: Booking): Promise<number> {
    const snap = await this.firestore
      .collection(COLLAB_JOBS_COLLECTION)
      .where('bookingId', '==', booking.id)
      .limit(BOOKING_JOBS_MAX)
      .get();
    let changed = 0;
    for (const doc of snap.docs) {
      const wrote = await this.firestore.runTransaction(async (fTx) => {
        const fresh = await fTx.get(doc.ref);
        const j = fresh.exists ? collabJobFromDoc(fresh.id, fresh.data()) : null;
        const next = j === null ? null : syncCollabJobOnBooking(j, booking);
        if (next === null) return false;
        fTx.set(doc.ref, collabJobToDoc(next));
        return true;
      });
      if (wrote) changed += 1;
    }
    return changed;
  }

  /** The photographer's collab jobs with this customer accepted within the poaching window (index collaboratorId, customerId, acceptedAt). */
  async acceptedJobsWith(photographerId: string, customerId: string, now: Date): Promise<CollabJob[]> {
    const since = new Date(now.getTime() - POACH_WINDOW_DAYS * DAY_MS);
    const snap = await this.firestore
      .collection(COLLAB_JOBS_COLLECTION)
      .where('collaboratorId', '==', photographerId)
      .where('customerId', '==', customerId)
      .where('acceptedAt', '>=', Timestamp.fromDate(since))
      .orderBy('acceptedAt', 'desc')
      .limit(PAIR_JOBS_MAX)
      .get();
    return present(snap.docs.map((d) => collabJobFromDoc(d.id, d.data())));
  }

  /** The photographer's own (non-studio) bookings with the customer, as `createdAt` instants. */
  async personalBookingTimes(photographerId: string, customerId: string): Promise<Date[]> {
    const snap = await this.firestore
      .collection(BOOKINGS_COLLECTION)
      .where('customerId', '==', customerId)
      .where('photographerId', '==', photographerId)
      .limit(PAIR_BOOKINGS_MAX)
      .get();
    return present(
      snap.docs.map((d) => {
        const b = bookingFromFirestore(d.id, d.data());
        return b === null || b.isStudio === true ? null : new Date(b.createdAt);
      }),
    );
  }

  /** Creates `staff_flags/poach_{p}_{c}` unless it exists; false when it already did. */
  async createPoachFlag(flag: {
    readonly photographerId: string;
    readonly customerId: string;
    readonly studioId: string;
    readonly jobIds: readonly string[];
    readonly createdAt: Date;
  }): Promise<boolean> {
    const ref = this.firestore.collection(STAFF_FLAGS_COLLECTION).doc(poachFlagId(flag.photographerId, flag.customerId));
    return this.firestore.runTransaction(async (fTx) => {
      if ((await fTx.get(ref)).exists) return false;
      fTx.set(ref, {
        kind: 'collab_poaching',
        photographerId: flag.photographerId,
        customerId: flag.customerId,
        studioId: flag.studioId,
        jobIds: [...flag.jobIds],
        createdAt: Timestamp.fromDate(flag.createdAt),
      });
      return true;
    });
  }
}

/** `users/{uid}.role` and `photographers/{uid}.recruitMatchKeys` for the match-key sync (Admin SDK; clients cannot). */
export class FirestoreRecruitMatchKeys {
  constructor(private readonly firestore: Firestore) {}

  async role(uid: string): Promise<string | null> {
    const role = (await this.firestore.collection(USERS).doc(uid).get()).data()?.role;
    return typeof role === 'string' ? role : null;
  }

  async photographer(uid: string): Promise<DocumentData | undefined> {
    const snap = await this.firestore.collection(PHOTOGRAPHERS).doc(uid).get();
    return snap.exists ? snap.data() : undefined;
  }

  async set(uid: string, keys: string[]): Promise<void> {
    try {
      await this.firestore.collection(PHOTOGRAPHERS).doc(uid).update({ recruitMatchKeys: keys });
    } catch (e) {
      // NOT_FOUND (5): deleted between the event and this write; `update` never recreates it.
      if ((e as { code?: unknown }).code === 5) return;
      throw e;
    }
  }
}
