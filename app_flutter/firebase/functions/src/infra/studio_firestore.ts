/**
 * Firestore adapters of the studio membership ports (#136): `studio_members`, `studio_quota`, the member
 * fields of `photographers/{uid}`, the roster, the per-day reads behind S26.04 and the invite search (S26.02).
 */

import {
  FieldValue,
  Timestamp,
  type DocumentData,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import {
  CLOSED_BOOKING_STATUSES,
  DomainError,
  MAX_MEMBERS_VERIFIED,
  OPEN_RELATION_STATUSES,
  RELATION_STATUSES,
  foldNameKey,
  inviteCandidateState,
  isStudio,
  providerTypeOf,
  scheduleReachesDay,
  type AssigneeKind,
  type DailyQuota,
  type InviteCandidateState,
  type MemberDayReader,
  type ProviderType,
  type RelationStatus,
  type StudioProfile,
  type StudioRelation,
  type StudioRoster,
  type StudioStore,
  type StudioTx,
} from '@photobooking/domain';
import type { NameKeyStore } from '../triggers/user_write.js';
import { AVAILABILITY_COLLECTION, BOOKINGS_COLLECTION } from './booking_firestore.js';
import { SPOT_SCHEDULES_COLLECTION, scheduleFromFirestore } from './spot_firestore.js';
import { STUDIO_COLLABORATIONS_COLLECTION } from './recruit_mapping.js';

export const STUDIO_MEMBERS_COLLECTION = 'studio_members';
export const STUDIO_QUOTA_COLLECTION = 'studio_quota';
const PHOTOGRAPHERS = 'photographers';
const USERS = 'users';

const DUE_WINDOW_MS = 24 * 60 * 60 * 1000;

function iso(v: unknown): string | null {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  if (typeof v === 'string' && v !== '') return v;
  return null;
}

function ts(v: string | null): Timestamp | null {
  return v === null ? null : Timestamp.fromDate(new Date(v));
}

function str(v: unknown): string | null {
  return typeof v === 'string' && v !== '' ? v : null;
}

// ── relation mapping ──

/** Every field written, `expiringNotifiedAt` as an explicit null: the sweep's `== null` matches only stored nulls. */
export function relationToFirestore(r: StudioRelation): DocumentData {
  return {
    studioId: r.studioId,
    memberId: r.memberId,
    status: r.status,
    initiatedBy: r.initiatedBy,
    createdAt: ts(r.createdAt),
    expiresAt: ts(r.expiresAt),
    respondedAt: ts(r.respondedAt),
    joinedAt: ts(r.joinedAt),
    endedAt: ts(r.endedAt),
    endedBy: r.endedBy,
    expiringNotifiedAt: ts(r.expiringNotifiedAt),
    studioName: r.studioName,
    studioAvatarUrl: r.studioAvatarUrl,
    memberName: r.memberName,
    memberAvatarUrl: r.memberAvatarUrl,
    version: r.version,
  };
}

export function relationFromFirestore(id: string, d: DocumentData | undefined): StudioRelation | null {
  if (!d) return null;
  const status = RELATION_STATUSES.find((s) => s === d.status);
  if (status === undefined || typeof d.studioId !== 'string' || typeof d.memberId !== 'string') return null;
  const endedBy = d.endedBy === 'member' || d.endedBy === 'studio' || d.endedBy === 'system' ? d.endedBy : null;
  return {
    id,
    studioId: d.studioId,
    memberId: d.memberId,
    status,
    initiatedBy: d.initiatedBy === 'member' ? 'member' : 'studio',
    createdAt: iso(d.createdAt) ?? '',
    expiresAt: iso(d.expiresAt) ?? '',
    respondedAt: iso(d.respondedAt),
    joinedAt: iso(d.joinedAt),
    endedAt: iso(d.endedAt),
    endedBy,
    expiringNotifiedAt: iso(d.expiringNotifiedAt),
    studioName: typeof d.studioName === 'string' ? d.studioName : '',
    studioAvatarUrl: str(d.studioAvatarUrl),
    memberName: typeof d.memberName === 'string' ? d.memberName : '',
    memberAvatarUrl: str(d.memberAvatarUrl),
    version: typeof d.version === 'number' ? d.version : 1,
  };
}

/** `photographers/{uid}` + `users/{uid}` → StudioProfile; null without a photographer document. */
export function studioProfileOf(
  uid: string,
  photographer: DocumentData | undefined,
  user: DocumentData | undefined,
): StudioProfile | null {
  if (!photographer) return null;
  return {
    uid,
    providerType: providerTypeOf(photographer.providerType),
    onboardingComplete: photographer.onboardingComplete === true,
    businessVerified: photographer.businessVerified === true,
    memberCount: typeof photographer.memberCount === 'number' ? photographer.memberCount : 0,
    studioId: str(photographer.studioId),
    studioCooldownUntil: iso(photographer.studioCooldownUntil),
    name: typeof user?.displayName === 'string' ? user.displayName : '',
    avatarUrl: str(user?.avatarUrl),
  };
}

function quotaFromFirestore(d: DocumentData | undefined): DailyQuota | null {
  if (!d || typeof d.dayKey !== 'string') return null;
  return {
    dayKey: d.dayKey,
    studioActions: typeof d.studioActions === 'number' ? d.studioActions : 0,
    memberActions: typeof d.memberActions === 'number' ? d.memberActions : 0,
  };
}

// ── StudioStore ──

export class FirestoreStudioStore implements StudioStore {
  constructor(private readonly firestore: Firestore) {}

  private relations() {
    return this.firestore.collection(STUDIO_MEMBERS_COLLECTION);
  }

  async runTransaction<T>(fn: (tx: StudioTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx: Transaction) => {
      const photographer = (uid: string) => this.firestore.collection(PHOTOGRAPHERS).doc(uid);
      const tx: StudioTx = {
        getProfile: async (uid) => {
          // The member's photographer document is the membership lock (Decision 1): read in the transaction.
          const [p, u] = await fTx.getAll(photographer(uid), this.firestore.collection(USERS).doc(uid));
          return studioProfileOf(uid, p?.exists ? p.data() : undefined, u?.exists ? u.data() : undefined);
        },
        getRelation: async (id) => {
          const snap = await fTx.get(this.relations().doc(id));
          return snap.exists ? relationFromFirestore(snap.id, snap.data()) : null;
        },
        openRelationOf: async (studioId, memberId) => {
          const snap = await fTx.get(
            this.relations()
              .where('studioId', '==', studioId)
              .where('memberId', '==', memberId)
              .where('status', 'in', [...OPEN_RELATION_STATUSES])
              .limit(1),
          );
          const doc = snap.docs[0];
          return doc ? relationFromFirestore(doc.id, doc.data()) : null;
        },
        countOpenInvites: async (studioId, now) => {
          // At most a handful (5 open + a few unswept stale ones): filter expiresAt here, no extra index.
          const snap = await fTx.get(
            this.relations().where('studioId', '==', studioId).where('status', '==', 'invited'),
          );
          return snap.docs.filter((d) => {
            const at = iso(d.data().expiresAt);
            return at !== null && Date.parse(at) > now.getTime();
          }).length;
        },
        countOpenAssignments: async (studioId, memberId) => {
          const snap = await fTx.get(
            this.firestore
              .collection(BOOKINGS_COLLECTION)
              .where('photographerId', '==', studioId)
              .where('assigneeId', '==', memberId)
              .where('status', 'not-in', [...CLOSED_BOOKING_STATUSES])
              .limit(50),
          );
          return snap.size;
        },
        countOpenSpotSchedules: async (studioId, memberId, today) => {
          // Open schedules naming the member that still reach today (#194):
          // a range on lastDay, no limit, so old schedules never crowd out a
          // current one. Index (providerId, assigneeId, status, lastDay).
          const snap = await fTx.get(
            this.firestore
              .collection(SPOT_SCHEDULES_COLLECTION)
              .where('providerId', '==', studioId)
              .where('assigneeId', '==', memberId)
              .where('status', '==', 'open')
              .where('lastDay', '>=', today),
          );
          return snap.docs.filter((d) => {
            const s = scheduleFromFirestore(d.id, d.data());
            return s !== null && scheduleReachesDay(s, today);
          }).length;
        },
        getQuota: async (uid) => {
          const snap = await fTx.get(this.firestore.collection(STUDIO_QUOTA_COLLECTION).doc(uid));
          return snap.exists ? quotaFromFirestore(snap.data()) : null;
        },
        activeCollaborationOf: async (studioId, uid) => {
          // Read in the transaction: an activation of the collaboration racing this join retries one side.
          const snap = await fTx.get(this.firestore.collection(STUDIO_COLLABORATIONS_COLLECTION).doc(`${studioId}_${uid}`));
          return snap.exists && snap.data()?.status === 'active';
        },
        putRelation: (r) => {
          fTx.set(this.relations().doc(r.id), relationToFirestore(r));
        },
        setMemberStudio: (memberId, patch) => {
          fTx.set(
            photographer(memberId),
            {
              studioId: patch.studioId,
              studioJoinedAt: ts(patch.studioJoinedAt),
              ...(patch.studioCooldownUntil !== undefined ? { studioCooldownUntil: ts(patch.studioCooldownUntil) } : {}),
            },
            { merge: true },
          );
        },
        addMemberCount: (studioId, delta) => {
          fTx.set(photographer(studioId), { memberCount: FieldValue.increment(delta) }, { merge: true });
        },
        putQuota: (uid, q) => {
          fTx.set(this.firestore.collection(STUDIO_QUOTA_COLLECTION).doc(uid), {
            dayKey: q.dayKey,
            studioActions: q.studioActions,
            memberActions: q.memberActions,
          });
        },
      };
      return fn(tx);
    });
  }

  /**
   * Two queries merged, soonest `expiresAt` first: invited | requested past `expiresAt` (index
   * `status, expiresAt`), and invites expiring within 24 h without a notice yet (index
   * `status, expiringNotifiedAt, expiresAt`).
   */
  async dueRelations(now: Date, limit: number): Promise<StudioRelation[]> {
    const [expire, announce] = await Promise.all([
      this.relations()
        .where('status', 'in', ['invited', 'requested'])
        .where('expiresAt', '<=', Timestamp.fromDate(now))
        .orderBy('expiresAt')
        .limit(limit)
        .get(),
      this.relations()
        .where('status', '==', 'invited')
        .where('expiringNotifiedAt', '==', null)
        .where('expiresAt', '<=', Timestamp.fromDate(new Date(now.getTime() + DUE_WINDOW_MS)))
        .orderBy('expiresAt')
        .limit(limit)
        .get(),
    ]);
    const byId = new Map<string, StudioRelation>();
    for (const d of [...expire.docs, ...announce.docs]) {
      const r = relationFromFirestore(d.id, d.data());
      if (r) byId.set(r.id, r);
    }
    return [...byId.values()]
      .sort((a, b) => Date.parse(a.expiresAt) - Date.parse(b.expiresAt))
      .slice(0, limit);
  }
}

// ── roster and S26.04 reads ──

async function personOf(firestore: Firestore, uid: string): Promise<{ name: string; avatarUrl: string | null } | null> {
  const snap = await firestore.collection(USERS).doc(uid).get();
  if (!snap.exists) return null;
  const d = snap.data();
  return { name: typeof d?.displayName === 'string' ? d.displayName : '', avatarUrl: str(d?.avatarUrl) };
}

/** Who may be assigned for a studio: its active members (`photographers/{uid}.studioId`, Decision 2). */
export class FirestoreStudioRoster implements StudioRoster {
  constructor(private readonly firestore: Firestore) {}

  async relationOf(studioId: string, uid: string): Promise<AssigneeKind | null> {
    const snap = await this.firestore.collection(PHOTOGRAPHERS).doc(uid).get();
    return snap.exists && snap.data()?.studioId === studioId ? 'member' : null;
  }

  person(uid: string): Promise<{ name: string; avatarUrl: string | null } | null> {
    return personOf(this.firestore, uid);
  }
}

/** Active members, each member's own day (with the occupying booking's times, Decision 18) and review stats. */
export class FirestoreMemberDayReader implements MemberDayReader {
  constructor(private readonly firestore: Firestore) {}

  async members(studioId: string): Promise<string[]> {
    const snap = await this.firestore
      .collection(PHOTOGRAPHERS)
      .where('studioId', '==', studioId)
      .orderBy('studioJoinedAt')
      .limit(MAX_MEMBERS_VERIFIED)
      .get();
    return snap.docs.map((d) => d.id);
  }

  async day(
    uid: string,
    day: string,
  ): Promise<{ state: 'off' | 'booked' | 'pending' | 'spot'; start: string | null; end: string | null } | null> {
    const snap = await this.firestore.collection(AVAILABILITY_COLLECTION).doc(uid).collection('days').doc(day).get();
    if (!snap.exists) return null;
    const d = snap.data() ?? {};
    if (d.state === 'off') return { state: 'off', start: null, end: null };
    // A spot day (#194 Decision 6) is busy with the schedule's window.
    if (d.state === 'spot') {
      const scheduleId = str(d.scheduleId);
      const schedule = scheduleId
        ? scheduleFromFirestore(
            scheduleId,
            (await this.firestore.collection(SPOT_SCHEDULES_COLLECTION).doc(scheduleId).get()).data(),
          )
        : null;
      return { state: 'spot', start: schedule?.window.start ?? null, end: schedule?.window.end ?? null };
    }
    const state = d.state === 'pending' ? 'pending' : 'booked';
    const bookingId = str(d.bookingId);
    if (bookingId === null) return { state, start: null, end: null };
    const booking = (await this.firestore.collection(BOOKINGS_COLLECTION).doc(bookingId).get()).data();
    return { state, start: str(booking?.start), end: str(booking?.end) };
  }

  async stats(uid: string): Promise<{ tomatoPct: number | null; reviewCount: number }> {
    const raw: unknown = (await this.firestore.collection(PHOTOGRAPHERS).doc(uid).get()).data()?.stats;
    const s = typeof raw === 'object' && raw !== null ? (raw as Record<string, unknown>) : {};
    return {
      tomatoPct: typeof s.tomatoPct === 'number' ? s.tomatoPct : null,
      reviewCount: typeof s.reviewCount === 'number' ? s.reviewCount : 0,
    };
  }
}

// ── invite search (S26.02, Decision 19) ──

export const INVITE_SEARCH_MIN_CHARS = 2;
export const INVITE_SEARCH_LIMIT = 20;
/** Fetched before studios, unfinished profiles and the caller are filtered out, then cut to INVITE_SEARCH_LIMIT. */
export const INVITE_SEARCH_FETCH = 40;
/** `in` takes at most 30 values. */
const IN_CHUNK = 30;

export interface InviteCandidateRow {
  readonly uid: string;
  readonly name: string;
  readonly avatarUrl: string | null;
  readonly verified: boolean;
  readonly tomatoPct: number | null;
  readonly areaLabel: string | null;
  readonly state: InviteCandidateState;
  /** in_studio: the other studio's name. */
  readonly studioName?: string;
  /** cooldown: when an invite works again (ISO). */
  readonly availableFrom?: string;
}

/**
 * Prefix search on `photographers.nameKey` (automatic single-field index), limit 20; studios, unfinished
 * profiles and the caller are left out. Each row carries its state for the calling studio.
 */
export async function searchInviteCandidates(
  firestore: Firestore,
  studioId: string,
  rawQuery: unknown,
  now: Date,
): Promise<InviteCandidateRow[]> {
  const q = typeof rawQuery === 'string' ? foldNameKey(rawQuery) : '';
  if (q.length < INVITE_SEARCH_MIN_CHARS || q.length > 80) throw new DomainError('invalid_argument', 'query');

  const [studioSnap, studioUser] = await Promise.all([
    firestore.collection(PHOTOGRAPHERS).doc(studioId).get(),
    firestore.collection(USERS).doc(studioId).get(),
  ]);
  const studio = studioProfileOf(studioId, studioSnap.exists ? studioSnap.data() : undefined, studioUser.data());
  if (studio === null) throw new DomainError('not_found');
  if (!isStudio(studio)) throw new DomainError('permission_denied');

  const found = await firestore
    .collection(PHOTOGRAPHERS)
    .where('nameKey', '>=', q)
    .where('nameKey', '<', `${q}\uf8ff`)
    .orderBy('nameKey')
    .limit(INVITE_SEARCH_FETCH)
    .get();
  const people = found.docs
    .filter((d) => {
      const p = d.data();
      return d.id !== studioId && p.onboardingComplete === true && providerTypeOf(p.providerType) !== 'studio';
    })
    .slice(0, INVITE_SEARCH_LIMIT);
  if (people.length === 0) return [];

  // The pair's open invite or request, for the rows found only (history is filtered here).
  const uids = people.map((d) => d.id);
  const chunks: string[][] = [];
  for (let i = 0; i < uids.length; i += IN_CHUNK) chunks.push(uids.slice(i, i + IN_CHUNK));
  const pending = await Promise.all(
    chunks.map((chunk) =>
      firestore.collection(STUDIO_MEMBERS_COLLECTION).where('studioId', '==', studioId).where('memberId', 'in', chunk).get(),
    ),
  );
  const openOf = new Map<string, { status: RelationStatus; expiresAt: string }>();
  for (const d of pending.flatMap((p) => p.docs)) {
    const r = relationFromFirestore(d.id, d.data());
    if (r && (r.status === 'invited' || r.status === 'requested')) {
      openOf.set(r.memberId, { status: r.status, expiresAt: r.expiresAt });
    }
  }

  const otherStudios = [
    ...new Set(people.map((d) => str(d.data().studioId)).filter((s): s is string => s !== null && s !== studioId)),
  ];
  const userDocs = await firestore.getAll(
    ...[...people.map((d) => d.id), ...otherStudios].map((uid) => firestore.collection(USERS).doc(uid)),
  );
  const userOf = new Map(userDocs.map((u) => [u.id, u.exists ? u.data() : undefined]));

  return people.map((d): InviteCandidateRow => {
    const p = d.data();
    const profile = studioProfileOf(d.id, p, userOf.get(d.id));
    const memberSide = {
      studioId: profile?.studioId ?? null,
      studioCooldownUntil: profile?.studioCooldownUntil ?? null,
    };
    const state = inviteCandidateState(studioId, memberSide, openOf.get(d.id) ?? null, now);
    const stats = typeof p.stats === 'object' && p.stats !== null ? (p.stats as Record<string, unknown>) : {};
    const otherName = memberSide.studioId === null ? undefined : userOf.get(memberSide.studioId)?.displayName;
    return {
      uid: d.id,
      name: profile?.name ?? '',
      avatarUrl: profile?.avatarUrl ?? null,
      verified: p.verified === true,
      tomatoPct: typeof stats.tomatoPct === 'number' ? stats.tomatoPct : null,
      areaLabel: str(p.serviceArea?.city),
      state,
      ...(state === 'in_studio' ? { studioName: typeof otherName === 'string' ? otherName : '' } : {}),
      ...(state === 'cooldown' && memberSide.studioCooldownUntil !== null
        ? { availableFrom: memberSide.studioCooldownUntil }
        : {}),
    };
  });
}

// ── nameKey and the availability trigger's studio lookup ──

/** `photographers/{uid}.nameKey` (server field) and `users/{uid}.displayName`. */
export class FirestoreNameKeys implements NameKeyStore {
  constructor(private readonly firestore: Firestore) {}

  async photographerExists(uid: string): Promise<boolean> {
    return (await this.firestore.collection(PHOTOGRAPHERS).doc(uid).get()).exists;
  }

  async displayName(uid: string): Promise<string | null> {
    const name: unknown = (await this.firestore.collection(USERS).doc(uid).get()).data()?.displayName;
    return typeof name === 'string' ? name : null;
  }

  /** `update`, so a photographer document deleted meanwhile is not recreated (NOT_FOUND is ignored). */
  async setNameKey(uid: string, nameKey: string): Promise<void> {
    try {
      await this.firestore.collection(PHOTOGRAPHERS).doc(uid).update({ nameKey });
    } catch (e) {
      if ((e as { code?: unknown } | null)?.code !== 5) throw e;
    }
  }
}

/** The studio a photographer is an active member of, and their provider type; null without a document. */
export async function studioSideOf(
  firestore: Firestore,
  uid: string,
): Promise<{ studioId: string | null; providerType: ProviderType } | null> {
  const snap = await firestore.collection(PHOTOGRAPHERS).doc(uid).get();
  if (!snap.exists) return null;
  const d = snap.data();
  return { studioId: str(d?.studioId), providerType: providerTypeOf(d?.providerType) };
}
