import {
  FieldPath,
  Timestamp,
  type DocumentData,
  type Firestore,
  type Query,
  type Transaction,
} from 'firebase-admin/firestore';
import {
  ANY_ORGANIZER,
  GATE_STAFF_STATUSES,
  ORGANIZER_STATUSES,
  SPOT_CLAIM_STATUSES,
  holderNameKey,
  normalizePhone,
  type EventRecord,
  type ExpiredResidentRef,
  type GateStaff,
  type GateStaffStatus,
  type Organizer,
  type OrganizerPeople,
  type OrganizerStatus,
  type OrganizerStore,
  type OrganizerTx,
  type Resident,
  type SpotClaim,
  type SpotClaimStatus,
} from '@photobooking/domain';
import { eventFromFirestore } from './event_firestore.js';
import { SPOTS_COLLECTION, spotFromFirestore, spotToFirestore } from './spot_firestore.js';

/**
 * S30 organizer documents (#223 Decisions 2–5) on Firestore: `organizers/{uid}`, `organizers/{uid}/gate_staff/{staffUid}`,
 * `spot_claims/{id}`, `spots/{id}/residents/{providerId}`; the store the organizer use cases run on, and the people
 * port (phone, business, payout flags, the S30.06 account lookup, staff).
 */
export const ORGANIZERS_COLLECTION = 'organizers';
export const GATE_STAFF_SUBCOLLECTION = 'gate_staff';
export const RESIDENTS_SUBCOLLECTION = 'residents';
export const SPOT_CLAIMS_COLLECTION = 'spot_claims';
const EVENTS = 'events';

/** Statuses `openEventsOf` lists: every event that is not cancelled or completed. */
const OPEN_EVENT_STATUSES = ['draft', 'open', 'full', 'closed'] as const;
/** Pages of 50 the phone lookup reads at most (a phone also sits in booking contact copies). */
const LOOKUP_PAGE = 50;
const LOOKUP_PAGES = 10;

const iso = (v: unknown): string | null => {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  return typeof v === 'string' && v !== '' ? v : null;
};
const str = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);
const ts = (v: string | null): Timestamp | null => (v === null ? null : Timestamp.fromDate(new Date(v)));
const strings = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x: unknown): x is string => typeof x === 'string') : []);
const EPOCH = new Date(0).toISOString();

// ---- organizers/{uid} ----------------------------------------------------------------------

export function organizerToFirestore(o: Organizer): DocumentData {
  return {
    name: o.name,
    bio: o.bio,
    avatarUrl: o.avatarUrl,
    status: o.status,
    phoneVerified: o.phoneVerified,
    businessVerified: o.businessVerified,
    payoutAccountOk: o.payoutAccountOk,
    managedSpotIds: [...o.managedSpotIds],
    createdAt: Timestamp.fromDate(new Date(o.createdAt)),
    updatedAt: Timestamp.fromDate(new Date(o.updatedAt)),
  };
}

/** `organizers/{uid}`; null when the document is missing. An unknown status reads as suspended. */
export function organizerFromFirestore(id: string, d: DocumentData | undefined): Organizer | null {
  if (d === undefined) return null;
  const status: OrganizerStatus = (ORGANIZER_STATUSES as readonly unknown[]).includes(d.status) ? d.status as OrganizerStatus : 'suspended';
  return {
    id,
    name: String(d.name ?? ''),
    bio: String(d.bio ?? ''),
    avatarUrl: str(d.avatarUrl),
    status,
    phoneVerified: d.phoneVerified === true,
    businessVerified: d.businessVerified === true,
    payoutAccountOk: d.payoutAccountOk === true,
    managedSpotIds: strings(d.managedSpotIds),
    createdAt: iso(d.createdAt) ?? EPOCH,
    updatedAt: iso(d.updatedAt) ?? EPOCH,
  };
}

// ---- spots/{spotId}/residents/{providerId} ------------------------------------------------

/** `validUntil` stays a Vietnam day string (`yyyy-MM-dd`), so `expiredResidents` compares it as text. */
export function residentToFirestore(r: Resident): DocumentData {
  return {
    waivesProvider: r.waivesProvider,
    waivesGuests: r.waivesGuests,
    maxGuests: r.maxGuests,
    validUntil: r.validUntil,
    addedAt: Timestamp.fromDate(new Date(r.addedAt)),
    addedBy: r.addedBy,
  };
}

/** `spots/{spotId}/residents/{providerId}`; null when the document is missing. */
export function residentFromFirestore(providerId: string, d: DocumentData | undefined): Resident | null {
  if (d === undefined) return null;
  return {
    providerId,
    waivesProvider: d.waivesProvider === true,
    waivesGuests: d.waivesGuests === true,
    maxGuests: typeof d.maxGuests === 'number' && Number.isInteger(d.maxGuests) ? d.maxGuests : null,
    validUntil: str(d.validUntil),
    addedAt: iso(d.addedAt) ?? EPOCH,
    addedBy: String(d.addedBy ?? ''),
  };
}

// ---- organizers/{uid}/gate_staff/{staffUid} -----------------------------------------------

/** `staffUid` and `organizerId` are stored too: the invitee's list is a collection-group query on `staffUid`. */
export function gateStaffToFirestore(g: GateStaff, organizerId?: string): DocumentData {
  return {
    staffUid: g.staffUid,
    ...(organizerId !== undefined ? { organizerId } : {}),
    status: g.status,
    invitedAt: Timestamp.fromDate(new Date(g.invitedAt)),
    respondedAt: ts(g.respondedAt),
    scansToday: g.scansToday === undefined ? null : { day: g.scansToday.day, count: g.scansToday.count },
  };
}

export function gateStaffFromFirestore(staffUid: string, d: DocumentData | undefined): GateStaff | null {
  if (d === undefined) return null;
  const status: GateStaffStatus = (GATE_STAFF_STATUSES as readonly unknown[]).includes(d.status) ? d.status as GateStaffStatus : 'removed';
  const scans = typeof d.scansToday === 'object' && d.scansToday !== null ? (d.scansToday as Record<string, unknown>) : null;
  return {
    staffUid,
    status,
    invitedAt: iso(d.invitedAt) ?? EPOCH,
    respondedAt: iso(d.respondedAt),
    ...(scans !== null && typeof scans.day === 'string' && typeof scans.count === 'number'
      ? { scansToday: { day: scans.day, count: scans.count } }
      : {}),
  };
}

// ---- spot_claims/{id} ---------------------------------------------------------------------

export function claimToFirestore(c: SpotClaim): DocumentData {
  return {
    spotId: c.spotId,
    proposal: c.proposal === null ? null : { name: c.proposal.name, address: c.proposal.address },
    organizerId: c.organizerId,
    status: c.status,
    proofPaths: [...c.proofPaths],
    note: c.note,
    reason: c.reason,
    createdAt: Timestamp.fromDate(new Date(c.createdAt)),
    reviewedAt: ts(c.reviewedAt),
    reviewedBy: c.reviewedBy,
  };
}

export function claimFromFirestore(id: string, d: DocumentData | undefined): SpotClaim | null {
  if (d === undefined) return null;
  const status: SpotClaimStatus = (SPOT_CLAIM_STATUSES as readonly unknown[]).includes(d.status) ? d.status as SpotClaimStatus : 'rejected';
  const p = typeof d.proposal === 'object' && d.proposal !== null ? (d.proposal as Record<string, unknown>) : null;
  return {
    id,
    spotId: str(d.spotId),
    proposal: p === null ? null : { name: String(p.name ?? ''), address: String(p.address ?? '') },
    organizerId: String(d.organizerId ?? ''),
    status,
    proofPaths: strings(d.proofPaths),
    note: String(d.note ?? ''),
    reason: str(d.reason),
    createdAt: iso(d.createdAt) ?? EPOCH,
    reviewedAt: iso(d.reviewedAt),
    reviewedBy: str(d.reviewedBy),
  };
}

// ---- the store ----------------------------------------------------------------------------

/**
 * `OrganizerStore` over one Firestore transaction per call. Writes are buffered and applied after the
 * use case returns, so every read comes first (Firestore's rule; the use cases read first anyway).
 */
export class FirestoreOrganizerStore implements OrganizerStore {
  constructor(private readonly firestore: Firestore) {}

  private organizerRef(uid: string) {
    return this.firestore.collection(ORGANIZERS_COLLECTION).doc(uid);
  }

  private residentRef(spotId: string, providerId: string) {
    return this.firestore.collection(SPOTS_COLLECTION).doc(spotId).collection(RESIDENTS_SUBCOLLECTION).doc(providerId);
  }

  async getOrganizer(uid: string): Promise<Organizer | null> {
    const snap = await this.organizerRef(uid).get();
    return organizerFromFirestore(uid, snap.data());
  }

  /** Collection group `residents` where `validUntil < today` (single-field collection-group index). */
  async expiredResidents(today: string, limit: number): Promise<ExpiredResidentRef[]> {
    const snap = await this.firestore.collectionGroup(RESIDENTS_SUBCOLLECTION).where('validUntil', '<', today).limit(limit).get();
    const out: ExpiredResidentRef[] = [];
    for (const d of snap.docs) {
      const parts = d.ref.path.split('/');
      // spots/{spotId}/residents/{providerId} only.
      if (parts.length === 4 && parts[0] === SPOTS_COLLECTION && parts[1] !== undefined) out.push({ spotId: parts[1], providerId: d.id });
    }
    return out;
  }

  /** Staff CLI (`claims list`): claims of `status`, oldest first (index `spot_claims(status, createdAt)`). */
  async listClaims(status: SpotClaimStatus, limit = 100): Promise<SpotClaim[]> {
    const snap = await this.firestore.collection(SPOT_CLAIMS_COLLECTION).where('status', '==', status).orderBy('createdAt').limit(limit).get();
    return snap.docs.map((d) => claimFromFirestore(d.id, d.data())).filter((c): c is SpotClaim => c !== null);
  }

  /** Staff CLI (`claims approve --spot`): a pending proposal gets the spot staff added for it. */
  async setClaimSpot(claimId: string, spotId: string): Promise<SpotClaim | null> {
    return this.firestore.runTransaction(async (fTx) => {
      const ref = this.firestore.collection(SPOT_CLAIMS_COLLECTION).doc(claimId);
      const claim = claimFromFirestore(claimId, (await fTx.get(ref)).data());
      if (claim === null || claim.status !== 'pending' || claim.spotId !== null) return null;
      const next: SpotClaim = { ...claim, spotId };
      fTx.set(ref, claimToFirestore(next));
      return next;
    });
  }

  runTransaction<T>(fn: (tx: OrganizerTx) => Promise<T>): Promise<T> {
    const fs = this.firestore;
    return fs.runTransaction(async (fTx: Transaction) => {
      const writes: Array<() => void> = [];
      const queryDocs = async (q: Query) => (await fTx.get(q)).docs;
      const claims = fs.collection(SPOT_CLAIMS_COLLECTION);
      const tx: OrganizerTx = {
        getOrganizer: async (uid) => organizerFromFirestore(uid, (await fTx.get(this.organizerRef(uid))).data()),
        putOrganizer: (o) => {
          writes.push(() => fTx.set(this.organizerRef(o.id), organizerToFirestore(o)));
        },
        getSpot: async (id) => {
          const snap = await fTx.get(fs.collection(SPOTS_COLLECTION).doc(id));
          return spotFromFirestore(snap.id, snap.data());
        },
        putSpot: (s) => {
          writes.push(() => fTx.set(fs.collection(SPOTS_COLLECTION).doc(s.id), spotToFirestore(s)));
        },
        getClaim: async (id) => claimFromFirestore(id, (await fTx.get(claims.doc(id))).data()),
        pendingClaimsOf: async (spotId, organizerId) => {
          let q: Query = claims.where('status', '==', 'pending').where('spotId', '==', spotId);
          if (organizerId !== ANY_ORGANIZER) q = q.where('organizerId', '==', organizerId);
          return (await queryDocs(q)).map((d) => claimFromFirestore(d.id, d.data())).filter((c): c is SpotClaim => c !== null);
        },
        putClaim: (c) => {
          writes.push(() => fTx.set(claims.doc(c.id), claimToFirestore(c)));
        },
        residentsOf: async (spotId) =>
          (await queryDocs(fs.collection(SPOTS_COLLECTION).doc(spotId).collection(RESIDENTS_SUBCOLLECTION)))
            .map((d) => residentFromFirestore(d.id, d.data()))
            .filter((r): r is Resident => r !== null),
        getResident: async (spotId, providerId) =>
          residentFromFirestore(providerId, (await fTx.get(this.residentRef(spotId, providerId))).data()),
        putResident: (spotId, r) => {
          writes.push(() => fTx.set(this.residentRef(spotId, r.providerId), residentToFirestore(r)));
        },
        deleteResident: (spotId, providerId) => {
          writes.push(() => fTx.delete(this.residentRef(spotId, providerId)));
        },
        gateStaffOf: async (organizerId) =>
          (await queryDocs(this.organizerRef(organizerId).collection(GATE_STAFF_SUBCOLLECTION)))
            .map((d) => gateStaffFromFirestore(d.id, d.data()))
            .filter((g): g is GateStaff => g !== null),
        putGateStaff: (organizerId, g) => {
          writes.push(() =>
            fTx.set(this.organizerRef(organizerId).collection(GATE_STAFF_SUBCOLLECTION).doc(g.staffUid), gateStaffToFirestore(g, organizerId)));
        },
        openEventsOf: async (organizerId) =>
          (await queryDocs(fs.collection(EVENTS).where('hostId', '==', organizerId).where('status', 'in', [...OPEN_EVENT_STATUSES])))
            .map((d) => eventFromFirestore(d.id, d.data()))
            .filter((e: EventRecord) => e.host.type === 'organizer' && e.host.id === organizerId),
      };
      const result = await fn(tx);
      for (const w of writes) w();
      return result;
    });
  }
}

// ---- people -------------------------------------------------------------------------------

/**
 * `@username` lookups: no account field holds a username (checked 2026-10-28: no `username` or
 * `usernameLower` in `users/*`, the app or the rules), so S30.06 resolves phone numbers only.
 */
export const USERNAME_LOOKUP = false;

/** The organizer use cases' view of a person (never trusted from the client). */
export function firestoreOrganizerPeople(firestore: Firestore, isAdmin: (uid: string) => Promise<boolean>): OrganizerPeople {
  const contactOf = async (uid: string) => (await firestore.doc(`users/${uid}/private/contact`).get()).data();
  const businessOf = async (uid: string): Promise<Record<string, unknown> | null> => {
    const b: unknown = (await firestore.collection('verifications').doc(uid).get()).data()?.business;
    return typeof b === 'object' && b !== null ? (b as Record<string, unknown>) : null;
  };
  return {
    async phoneVerified(uid) {
      const d = await contactOf(uid);
      return d?.phoneVerified === true && typeof d.phone === 'string' && d.phone !== '';
    },
    async businessVerified(uid) {
      if ((await businessOf(uid))?.status === 'approved') return true;
      return (await firestore.collection(ORGANIZERS_COLLECTION).doc(uid).get()).data()?.businessVerified === true;
    },
    /**
     * The flag S06.06 wrote on the organizer, or an active payout account whose holder is the approved business's
     * legal name (a provider who becomes an organizer after saving their account).
     */
    async payoutAccountOk(uid) {
      if ((await firestore.collection(ORGANIZERS_COLLECTION).doc(uid).get()).data()?.payoutAccountOk === true) return true;
      const business = await businessOf(uid);
      if (business?.status !== 'approved' || typeof business.name !== 'string') return false;
      const holder: unknown = (await firestore.collection('payoutAccounts').doc(uid).get()).data()?.holderName;
      const key = holderNameKey(business.name);
      return typeof holder === 'string' && key !== '' && holderNameKey(holder) === key;
    },
    /**
     * A phone in any form (`0903 123 456`, `+84903123456`) → E.164 → collection group `private` where `phone ==`, kept
     * only for `users/{uid}/private/contact` (booking and provider contact copies hold phones too). `@username` → null.
     */
    async lookup(raw) {
      const target = raw.trim();
      if (target.startsWith('@')) return null;
      const phone = normalizePhone(target);
      if (phone === null) return null;
      let after: unknown = null;
      for (let page = 0; page < LOOKUP_PAGES; page++) {
        let q = firestore.collectionGroup('private').where('phone', '==', phone).orderBy(FieldPath.documentId()).limit(LOOKUP_PAGE);
        if (after !== null) q = q.startAfter(after as never);
        const snap = await q.get();
        for (const d of snap.docs) {
          const parts = d.ref.path.split('/');
          const uid = parts[1];
          if (parts.length === 4 && parts[0] === 'users' && parts[2] === 'private' && parts[3] === 'contact' && uid !== undefined) {
            const user = (await firestore.collection('users').doc(uid).get()).data();
            if (user === undefined) continue;
            const name = typeof user.displayName === 'string' && user.displayName !== '' ? user.displayName : 'Người dùng';
            return { uid, name };
          }
        }
        if (snap.size < LOOKUP_PAGE) return null;
        after = snap.docs[snap.size - 1] ?? null;
      }
      return null;
    },
    isStaff: isAdmin,
  };
}
