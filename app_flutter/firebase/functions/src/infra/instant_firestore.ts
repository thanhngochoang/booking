/**
 * Firestore adapters of the Chụp ngay ports (plan #140 Task 4): the request, offer and presence
 * mappers, the transaction adapter behind `InstantStore` and the presence directory.
 *
 * Layout (Contract "Firestore data"):
 * - `instant_requests/{id}`: the request without `excludedIds` (the assigned photographer can read it);
 * - `instant_requests/{id}/private/dispatch`: `{excludedIds}` (server only, Task 3 privacy ruling: who
 *   was skipped, declined or let an offer expire never reaches the photographer who got the job);
 * - `instant_requests/{id}/private/contact`: the customer's contact for the assigned photographer (#202);
 * - `instant_customers/{uid}`: `{activeRequestId}`, the lock that makes "one active request per customer"
 *   (Decision 18) hold under concurrency: a query does not lock documents that do not exist yet, a
 *   document read and written in the same transaction does;
 * - `instant_offers/{uid}/offers/{offerId}`, `instant_presence/{uid}`, `instant_tracks/{requestId}`.
 */
import {
  Timestamp,
  type DocumentData,
  type DocumentReference,
  type DocumentSnapshot,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import {
  INSTANT_STATUSES,
  OFFER_OUTCOMES,
  PAYMENT_PROVIDERS,
  REFUND_STATUSES,
  isInstantActive,
  isInstantGenre,
  isPaymentMethod,
  providerTypeOf,
  type BookingContactSnapshot,
  type InstantCancelRule,
  type InstantCandidate,
  type InstantOffer,
  type InstantOfferRow,
  type InstantParty,
  type InstantPresence,
  type InstantRequest,
  type InstantStatus,
  type InstantStore,
  type InstantTrackDoc,
  type InstantTx,
  type LedgerEntry,
  type OfferOutcome,
  type OfferRowOutcome,
  type Payment,
  type PaymentProvider,
  type PresenceDirectory,
  type Refund,
  type RefundStatus,
} from '@photobooking/domain';
import {
  LEDGER_COLLECTION,
  PAYMENTS_COLLECTION,
  REFUNDS_COLLECTION,
  ledgerEntryToFirestore,
  paymentFromFirestore,
  paymentToFirestore,
  refundFromFirestore,
  refundToFirestore,
} from './booking_firestore.js';

export const INSTANT_REQUESTS = 'instant_requests';
export const INSTANT_OFFERS = 'instant_offers';
export const INSTANT_PRESENCE = 'instant_presence';
export const INSTANT_TRACKS = 'instant_tracks';
export const INSTANT_CUSTOMERS = 'instant_customers';

export const instantRequestPath = (id: string): string => `${INSTANT_REQUESTS}/${id}`;
export const instantDispatchPath = (id: string): string => `${INSTANT_REQUESTS}/${id}/private/dispatch`;
export const instantContactPath = (id: string): string => `${INSTANT_REQUESTS}/${id}/private/contact`;
export const instantOfferPath = (uid: string, offerId: string): string => `${INSTANT_OFFERS}/${uid}/offers/${offerId}`;
export const instantPresencePath = (uid: string): string => `${INSTANT_PRESENCE}/${uid}`;
export const instantTrackPath = (requestId: string): string => `${INSTANT_TRACKS}/${requestId}`;
export const instantCustomerLockPath = (uid: string): string => `${INSTANT_CUSTOMERS}/${uid}`;

// ---------------------------------------------------------------- field readers

const ts = (d: Date | null): Timestamp | null => (d === null ? null : Timestamp.fromDate(d));
const dateOrNull = (v: unknown): Date | null =>
  v instanceof Timestamp ? v.toDate() : v instanceof Date ? new Date(v.getTime()) : null;
const dateOr = (v: unknown, fallback: Date): Date => dateOrNull(v) ?? fallback;
const EPOCH = new Date(0);
const str = (v: unknown, fallback = ''): string => (typeof v === 'string' ? v : fallback);
const strOrNull = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);
const num = (v: unknown, fallback = 0): number => (typeof v === 'number' && Number.isFinite(v) ? v : fallback);
const numOrNull = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) ? v : null);
const bool = (v: unknown): boolean => v === true;
const record = (v: unknown): Record<string, unknown> =>
  typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Record<string, unknown>) : {};
const list = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);
const strings = (v: unknown): string[] => list(v).filter((x): x is string => typeof x === 'string');
const oneOf = <T extends string>(values: readonly T[], v: unknown): T | null =>
  typeof v === 'string' && (values as readonly string[]).includes(v) ? (v as T) : null;

const CANCEL_RULES: readonly InstantCancelRule[] = [
  'unpaid', 'full_refund', 'free_window', 'photographer_late', 'en_route', 'arrived', 'photographer_cancel', 'no_show',
];
const ROW_OUTCOMES: readonly OfferRowOutcome[] = [...OFFER_OUTCOMES, 'unavailable'];

// ---------------------------------------------------------------- request

function candidateToFirestore(c: InstantCandidate): DocumentData {
  return {
    photographerId: c.photographerId, name: c.name, avatarUrl: c.avatarUrl, verified: c.verified,
    providerType: c.providerType, tomatoPct: c.tomatoPct, reviewCount: c.reviewCount, completedCount: c.completedCount,
    distanceKm: c.distanceKm, etaMinutes: c.etaMinutes, photos: [...c.photos],
    reasons: c.reasons.map((r) => ({ code: r.code, text: r.text })), tier: c.tier, score: c.score,
  };
}

function candidateFromFirestore(v: unknown): InstantCandidate {
  const d = record(v);
  return {
    photographerId: str(d.photographerId), name: str(d.name), avatarUrl: strOrNull(d.avatarUrl), verified: bool(d.verified),
    providerType: providerTypeOf(d.providerType), tomatoPct: num(d.tomatoPct), reviewCount: num(d.reviewCount),
    completedCount: num(d.completedCount), distanceKm: num(d.distanceKm), etaMinutes: num(d.etaMinutes, 1),
    photos: strings(d.photos),
    reasons: list(d.reasons).flatMap((x) => {
      const r = record(x);
      const code = oneOf(['genre', 'distance'] as const, r.code);
      return code === null ? [] : [{ code, text: str(r.text) }];
    }),
    tier: d.tier === 'expanded' ? 'expanded' : 'priority',
    score: num(d.score),
  };
}

function offerRowToFirestore(o: InstantOfferRow): DocumentData {
  return {
    offerId: o.offerId, photographerId: o.photographerId, name: o.name, avatarUrl: o.avatarUrl, tomatoPct: o.tomatoPct,
    reviewCount: o.reviewCount, etaMinutes: o.etaMinutes, outcome: o.outcome, expiresAt: ts(o.expiresAt),
  };
}

function offerRowFromFirestore(v: unknown): InstantOfferRow {
  const d = record(v);
  return {
    offerId: strOrNull(d.offerId), photographerId: str(d.photographerId), name: str(d.name), avatarUrl: strOrNull(d.avatarUrl),
    tomatoPct: num(d.tomatoPct), reviewCount: num(d.reviewCount), etaMinutes: num(d.etaMinutes, 1),
    // Defensive, like the app: an unknown outcome reads as expired (the row is over).
    outcome: oneOf(ROW_OUTCOMES, d.outcome) ?? 'expired',
    expiresAt: dateOrNull(d.expiresAt),
  };
}

function partyToFirestore(p: InstantParty): DocumentData {
  return {
    id: p.id, name: p.name, avatarUrl: p.avatarUrl, verified: p.verified, tomatoPct: p.tomatoPct,
    reviewCount: p.reviewCount, completedCount: p.completedCount,
  };
}

function partyFromFirestore(v: unknown): InstantParty | null {
  if (v === null || v === undefined) return null;
  const d = record(v);
  return {
    id: str(d.id), name: str(d.name), avatarUrl: strOrNull(d.avatarUrl), verified: bool(d.verified),
    tomatoPct: num(d.tomatoPct), reviewCount: num(d.reviewCount), completedCount: num(d.completedCount),
  };
}

/**
 * The public request document. Every field is written (nulls included, never `undefined`); instants
 * are Timestamps. `excludedIds` is left out: it lives in `private/dispatch` (instantDispatchToFirestore).
 */
export function instantRequestToFirestore(r: InstantRequest): DocumentData {
  return {
    customerId: r.customerId, customerName: r.customerName, customerAvatarUrl: r.customerAvatarUrl,
    status: r.status, active: isInstantActive(r.status),
    packageCode: r.packageCode, durationMin: r.durationMin, photos: r.photos, genre: r.genre, note: r.note,
    cityId: r.cityId, meetPoint: { lat: r.meetPoint.lat, lng: r.meetPoint.lng, name: r.meetPoint.name }, areaLabel: r.areaLabel,
    amountVnd: r.amountVnd, earningVnd: r.earningVnd,
    priceListVersion: r.priceListVersion, platformFeeBp: r.platformFeeBp, arrivedCancelPhotographerPercent: r.arrivedCancelPhotographerPercent,
    committedAt: ts(r.committedAt),
    payMethod: r.payMethod, provider: r.provider, paymentId: r.paymentId, paidAt: ts(r.paidAt),
    paymentDeadlineAt: ts(r.paymentDeadlineAt), refundId: r.refundId, refundStatus: r.refundStatus,
    round: r.round, invitedTotal: r.invitedTotal, roundsWithInvites: r.roundsWithInvites,
    candidates: r.candidates.map(candidateToFirestore), offers: r.offers.map(offerRowToFirestore),
    pendingInviteIds: [...r.pendingInviteIds], roundEnded: r.roundEnded,
    photographerId: r.photographerId, photographer: r.photographer === null ? null : partyToFirestore(r.photographer),
    chatId: r.chatId, etaMinutes: r.etaMinutes,
    assignedAt: ts(r.assignedAt), freeCancelUntil: ts(r.freeCancelUntil), lateDeadlineAt: ts(r.lateDeadlineAt),
    startedRouteAt: ts(r.startedRouteAt), arrivedAt: ts(r.arrivedAt), forcedArrivalAccuracyM: r.forcedArrivalAccuracyM,
    startedAt: ts(r.startedAt), shootEndsAt: ts(r.shootEndsAt), finishedAt: ts(r.finishedAt), completedAt: ts(r.completedAt),
    cancelledAt: ts(r.cancelledAt), cancelledBy: r.cancelledBy, cancelRule: r.cancelRule, refundPercent: r.refundPercent,
    feeVnd: r.feeVnd, searchDeadlineAt: ts(r.searchDeadlineAt), lastActivityAt: Timestamp.fromDate(r.lastActivityAt),
    nextDeadlineAt: ts(r.nextDeadlineAt), createdAt: Timestamp.fromDate(r.createdAt), updatedAt: Timestamp.fromDate(r.updatedAt),
    version: r.version,
  };
}

/** `instant_requests/{id}/private/dispatch` (server only). */
export function instantDispatchToFirestore(r: Pick<InstantRequest, 'excludedIds' | 'updatedAt'>): DocumentData {
  return { excludedIds: [...r.excludedIds], updatedAt: Timestamp.fromDate(r.updatedAt) };
}

/**
 * The request of a stored document and its dispatch subdocument (absent → no exclusions). A document
 * whose status or genre is unknown reads as not found (defensive: never act on a request we cannot read).
 */
export function instantRequestFromFirestore(
  id: string,
  d: DocumentData | undefined,
  dispatch?: DocumentData | undefined,
): InstantRequest | null {
  if (d === undefined) return null;
  const status = oneOf<InstantStatus>(INSTANT_STATUSES, d.status);
  if (status === null || !isInstantGenre(d.genre)) return null;
  const meet = record(d.meetPoint);
  const createdAt = dateOr(d.createdAt, EPOCH);
  const cancelledBy = d.cancelledBy === 'customer' || d.cancelledBy === 'photographer' ? d.cancelledBy : null;
  return {
    id,
    customerId: str(d.customerId), customerName: str(d.customerName), customerAvatarUrl: strOrNull(d.customerAvatarUrl),
    status, active: isInstantActive(status),
    packageCode: str(d.packageCode), durationMin: num(d.durationMin), photos: num(d.photos), genre: d.genre, note: str(d.note),
    cityId: str(d.cityId), meetPoint: { lat: num(meet.lat), lng: num(meet.lng), name: str(meet.name) }, areaLabel: str(d.areaLabel),
    amountVnd: num(d.amountVnd), earningVnd: num(d.earningVnd),
    priceListVersion: num(d.priceListVersion), platformFeeBp: num(d.platformFeeBp),
    arrivedCancelPhotographerPercent: num(d.arrivedCancelPhotographerPercent),
    committedAt: dateOrNull(d.committedAt),
    payMethod: isPaymentMethod(d.payMethod) ? d.payMethod : null,
    provider: oneOf<PaymentProvider>(PAYMENT_PROVIDERS, d.provider),
    paymentId: strOrNull(d.paymentId), paidAt: dateOrNull(d.paidAt), paymentDeadlineAt: dateOrNull(d.paymentDeadlineAt),
    refundId: strOrNull(d.refundId), refundStatus: oneOf<RefundStatus>(REFUND_STATUSES, d.refundStatus),
    round: num(d.round, 1), invitedTotal: num(d.invitedTotal), roundsWithInvites: num(d.roundsWithInvites),
    candidates: list(d.candidates).map(candidateFromFirestore), offers: list(d.offers).map(offerRowFromFirestore),
    excludedIds: strings(dispatch?.excludedIds), pendingInviteIds: strings(d.pendingInviteIds), roundEnded: bool(d.roundEnded),
    photographerId: strOrNull(d.photographerId), photographer: partyFromFirestore(d.photographer),
    chatId: strOrNull(d.chatId), etaMinutes: numOrNull(d.etaMinutes),
    assignedAt: dateOrNull(d.assignedAt), freeCancelUntil: dateOrNull(d.freeCancelUntil), lateDeadlineAt: dateOrNull(d.lateDeadlineAt),
    startedRouteAt: dateOrNull(d.startedRouteAt), arrivedAt: dateOrNull(d.arrivedAt),
    forcedArrivalAccuracyM: numOrNull(d.forcedArrivalAccuracyM),
    startedAt: dateOrNull(d.startedAt), shootEndsAt: dateOrNull(d.shootEndsAt), finishedAt: dateOrNull(d.finishedAt),
    completedAt: dateOrNull(d.completedAt),
    cancelledAt: dateOrNull(d.cancelledAt), cancelledBy, cancelRule: oneOf(CANCEL_RULES, d.cancelRule),
    refundPercent: numOrNull(d.refundPercent), feeVnd: numOrNull(d.feeVnd),
    searchDeadlineAt: dateOrNull(d.searchDeadlineAt), lastActivityAt: dateOr(d.lastActivityAt, createdAt),
    nextDeadlineAt: dateOrNull(d.nextDeadlineAt), createdAt, updatedAt: dateOr(d.updatedAt, createdAt), version: num(d.version, 1),
  };
}

// ---------------------------------------------------------------- offer

export function instantOfferToFirestore(o: InstantOffer): DocumentData {
  return {
    requestId: o.requestId, photographerId: o.photographerId, round: o.round,
    offeredAt: Timestamp.fromDate(o.offeredAt), expiresAt: Timestamp.fromDate(o.expiresAt),
    outcome: o.outcome, decidedAt: ts(o.decidedAt),
    packageCode: o.packageCode, durationMin: o.durationMin, photos: o.photos, genre: o.genre, areaLabel: o.areaLabel,
    distanceKm: o.distanceKm, etaMinutes: o.etaMinutes, earningVnd: o.earningVnd, note: o.note, invitedCount: o.invitedCount,
  };
}

/** Unknown outcome or genre → null (not found). */
export function instantOfferFromFirestore(id: string, d: DocumentData | undefined): InstantOffer | null {
  if (d === undefined) return null;
  const outcome = oneOf<OfferOutcome>(OFFER_OUTCOMES, d.outcome);
  const offeredAt = dateOrNull(d.offeredAt);
  const expiresAt = dateOrNull(d.expiresAt);
  if (outcome === null || !isInstantGenre(d.genre) || offeredAt === null || expiresAt === null) return null;
  return {
    id, requestId: str(d.requestId), photographerId: str(d.photographerId), round: num(d.round, 1),
    offeredAt, expiresAt, outcome, decidedAt: dateOrNull(d.decidedAt),
    packageCode: str(d.packageCode), durationMin: num(d.durationMin), photos: num(d.photos), genre: d.genre,
    areaLabel: str(d.areaLabel), distanceKm: num(d.distanceKm), etaMinutes: num(d.etaMinutes, 1), earningVnd: num(d.earningVnd),
    note: str(d.note), invitedCount: num(d.invitedCount, 1),
  };
}

// ---------------------------------------------------------------- presence

export function instantPresenceToFirestore(p: InstantPresence): DocumentData {
  const pr = p.profile;
  const rel = p.reliability;
  return {
    online: p.online, helpReady: p.helpReady, priceListVersion: p.priceListVersion, cityId: p.cityId,
    lat: p.lat, lng: p.lng, accuracyM: p.accuracyM, geohash5: p.geohash5, geohash4: p.geohash4,
    heartbeatAt: ts(p.heartbeatAt), activeRequestId: p.activeRequestId,
    pendingOffers: p.pendingOffers.map((o) => ({ offerId: o.offerId, requestId: o.requestId, expiresAt: Timestamp.fromDate(o.expiresAt) })),
    profile: {
      name: pr.name, avatarUrl: pr.avatarUrl, verified: pr.verified, providerType: pr.providerType, tomatoPct: pr.tomatoPct,
      score: pr.score, reviewCount: pr.reviewCount, completedCount: pr.completedCount,
      specialties: [...pr.specialties], photos: [...pr.photos],
    },
    reliability: {
      offers: rel.offers, accepted: rel.accepted, declined: rel.declined, expired: rel.expired,
      cancelled: rel.cancelled, late: rel.late, noShow: rel.noShow,
    },
    updatedAt: Timestamp.fromDate(p.updatedAt),
  };
}

export function instantPresenceFromFirestore(uid: string, d: DocumentData | undefined): InstantPresence | null {
  if (d === undefined) return null;
  const pr = record(d.profile);
  const rel = record(d.reliability);
  return {
    uid,
    online: bool(d.online), helpReady: bool(d.helpReady), priceListVersion: numOrNull(d.priceListVersion),
    cityId: strOrNull(d.cityId), lat: numOrNull(d.lat), lng: numOrNull(d.lng), accuracyM: numOrNull(d.accuracyM),
    geohash5: strOrNull(d.geohash5), geohash4: strOrNull(d.geohash4), heartbeatAt: dateOrNull(d.heartbeatAt),
    activeRequestId: strOrNull(d.activeRequestId),
    pendingOffers: list(d.pendingOffers).flatMap((x) => {
      const o = record(x);
      const expiresAt = dateOrNull(o.expiresAt);
      return expiresAt === null ? [] : [{ offerId: str(o.offerId), requestId: str(o.requestId), expiresAt }];
    }),
    profile: {
      name: str(pr.name), avatarUrl: strOrNull(pr.avatarUrl), verified: bool(pr.verified), providerType: providerTypeOf(pr.providerType),
      tomatoPct: num(pr.tomatoPct), score: num(pr.score), reviewCount: num(pr.reviewCount), completedCount: num(pr.completedCount),
      specialties: strings(pr.specialties), photos: strings(pr.photos),
    },
    reliability: {
      offers: num(rel.offers), accepted: num(rel.accepted), declined: num(rel.declined), expired: num(rel.expired),
      cancelled: num(rel.cancelled), late: num(rel.late), noShow: num(rel.noShow),
    },
    updatedAt: dateOr(d.updatedAt, EPOCH),
  };
}

// ---------------------------------------------------------------- track and contact

export function instantTrackToFirestore(t: InstantTrackDoc): DocumentData {
  return {
    customerId: t.customerId, photographerId: t.photographerId, active: t.active, lat: t.lat, lng: t.lng,
    accuracyM: t.accuracyM, heading: t.heading, at: Timestamp.fromDate(t.at),
  };
}

/** The `BookingContactSnapshot` shape, like `bookings/{id}/private/contact`. */
export function instantContactToFirestore(c: BookingContactSnapshot): DocumentData {
  return { name: c.name, phone: c.phone, allowZalo: c.allowZalo, allowWhatsApp: c.allowWhatsApp };
}

// ---------------------------------------------------------------- transaction adapter

type Write = { readonly kind: 'set'; readonly data: DocumentData } | { readonly kind: 'delete' };

const sameIds = (a: readonly string[], b: readonly string[]): boolean => a.length === b.length && a.every((x, i) => x === b[i]);

/**
 * One Firestore transaction behind `InstantTx`. Reads go through `fTx` (every request read also reads
 * its `private/dispatch`); writes are buffered by path (the last one wins) and applied by `commit()`
 * after the use case returns; a read after the first write throws `read after write`.
 *
 * The customer lock (`instant_customers/{uid}.activeRequestId`): `findActiveRequestOfCustomer` reads it,
 * a new active request writes it, and a request read active and written ended clears it (unless the lock
 * now points elsewhere). Two concurrent creates both read and write the lock, so Firestore retries one,
 * which then finds the other's request.
 */
export class FirestoreInstantTx implements InstantTx {
  private readonly writes = new Map<string, Write>();
  private readonly requestsRead = new Map<string, { request: InstantRequest | null; excludedIds: readonly string[] | null }>();
  private readonly locksRead = new Map<string, string | null>();
  /** The lock value this transaction will write, per customer. */
  private readonly lockWrites = new Map<string, string | null>();
  private written = false;

  constructor(private readonly firestore: Firestore, private readonly fTx: Transaction) {}

  private ref(path: string): DocumentReference {
    return this.firestore.doc(path);
  }

  private beforeRead(): void {
    if (this.written) throw new Error('read after write');
  }

  private async read(path: string): Promise<DocumentSnapshot> {
    this.beforeRead();
    const [snap] = await this.fTx.getAll(this.ref(path));
    if (snap === undefined) throw new Error(`no snapshot for ${path}`);
    return snap;
  }

  private write(path: string, w: Write): void {
    this.written = true;
    this.writes.set(path, w);
  }

  async getRequest(id: string): Promise<InstantRequest | null> {
    this.beforeRead();
    const seen = this.requestsRead.get(id);
    if (seen !== undefined) return seen.request;
    const [pub, dispatch] = await this.fTx.getAll(this.ref(instantRequestPath(id)), this.ref(instantDispatchPath(id)));
    const request = pub?.exists === true ? instantRequestFromFirestore(id, pub.data(), dispatch?.data()) : null;
    this.requestsRead.set(id, { request, excludedIds: dispatch?.exists === true ? request?.excludedIds ?? null : null });
    return request;
  }

  async getOffer(photographerId: string, offerId: string): Promise<InstantOffer | null> {
    const snap = await this.read(instantOfferPath(photographerId, offerId));
    return snap.exists ? instantOfferFromFirestore(offerId, snap.data()) : null;
  }

  async getPresence(uid: string): Promise<InstantPresence | null> {
    const snap = await this.read(instantPresencePath(uid));
    return snap.exists ? instantPresenceFromFirestore(uid, snap.data()) : null;
  }

  async getPayment(id: string): Promise<Payment | null> {
    const snap = await this.read(`${PAYMENTS_COLLECTION}/${id}`);
    return snap.exists ? paymentFromFirestore(id, snap.data()) : null;
  }

  async getRefund(id: string): Promise<Refund | null> {
    const snap = await this.read(`${REFUNDS_COLLECTION}/${id}`);
    return snap.exists ? refundFromFirestore(id, snap.data()) : null;
  }

  async findActiveRequestOfCustomer(customerId: string): Promise<InstantRequest | null> {
    const snap = await this.read(instantCustomerLockPath(customerId));
    const activeId = snap.exists ? strOrNull(snap.data()?.activeRequestId) : null;
    this.locksRead.set(customerId, activeId);
    if (activeId === null) return null;
    const r = await this.getRequest(activeId);
    // A lock left on an ended or foreign request is stale: the next active request overwrites it.
    return r !== null && r.active && r.customerId === customerId ? r : null;
  }

  putRequest(r: InstantRequest): void {
    const seen = this.requestsRead.get(r.id);
    this.write(instantRequestPath(r.id), { kind: 'set', data: instantRequestToFirestore(r) });
    if (seen === undefined || seen.excludedIds === null || !sameIds(seen.excludedIds, r.excludedIds)) {
      this.write(instantDispatchPath(r.id), { kind: 'set', data: instantDispatchToFirestore(r) });
    }
    const wasActive = seen?.request?.active === true;
    const isActive = isInstantActive(r.status);
    if (isActive && !wasActive) {
      this.setLock(r.customerId, r.id);
    } else if (!isActive && wasActive) {
      const planned = this.lockWrites.has(r.customerId) ? this.lockWrites.get(r.customerId) : this.locksRead.get(r.customerId);
      if (planned === undefined || planned === null || planned === r.id) this.setLock(r.customerId, null);
    }
  }

  private setLock(customerId: string, activeRequestId: string | null): void {
    this.lockWrites.set(customerId, activeRequestId);
    this.write(instantCustomerLockPath(customerId), { kind: 'set', data: { activeRequestId, updatedAt: Timestamp.now() } });
  }

  putOffer(o: InstantOffer): void {
    this.write(instantOfferPath(o.photographerId, o.id), { kind: 'set', data: instantOfferToFirestore(o) });
  }

  putPresence(p: InstantPresence): void {
    this.write(instantPresencePath(p.uid), { kind: 'set', data: instantPresenceToFirestore(p) });
  }

  putPayment(p: Payment): void {
    this.write(`${PAYMENTS_COLLECTION}/${p.id}`, { kind: 'set', data: paymentToFirestore(p) });
  }

  putRefund(r: Refund): void {
    this.write(`${REFUNDS_COLLECTION}/${r.id}`, { kind: 'set', data: refundToFirestore(r) });
  }

  putLedgerEntry(e: LedgerEntry): void {
    this.write(`${LEDGER_COLLECTION}/${e.id}`, { kind: 'set', data: ledgerEntryToFirestore(e) });
  }

  putContact(requestId: string, c: BookingContactSnapshot): void {
    this.write(instantContactPath(requestId), { kind: 'set', data: instantContactToFirestore(c) });
  }

  deleteContact(requestId: string): void {
    this.write(instantContactPath(requestId), { kind: 'delete' });
  }

  putTrack(requestId: string, t: InstantTrackDoc): void {
    this.write(instantTrackPath(requestId), { kind: 'set', data: instantTrackToFirestore(t) });
  }

  deleteTrack(requestId: string): void {
    this.write(instantTrackPath(requestId), { kind: 'delete' });
  }

  /** Applies the buffered writes to the Firestore transaction (one per path). */
  commit(): void {
    for (const [path, w] of this.writes) {
      if (w.kind === 'set') this.fTx.set(this.ref(path), w.data);
      else this.fTx.delete(this.ref(path));
    }
  }
}

export class FirestoreInstantStore implements InstantStore {
  constructor(private readonly firestore: Firestore) {}

  runTransaction<T>(fn: (tx: InstantTx) => Promise<T>): Promise<T> {
    return this.firestore.runTransaction(async (fTx) => {
      const tx = new FirestoreInstantTx(this.firestore, fTx);
      const out = await fn(tx);
      tx.commit();
      return out;
    });
  }

  /** The clock step's query (Decision 3; index `instant_requests (active, nextDeadlineAt)`). */
  async findDue(now: Date, limit: number): Promise<readonly InstantRequest[]> {
    const snap = await this.firestore
      .collection(INSTANT_REQUESTS)
      .where('active', '==', true)
      .where('nextDeadlineAt', '<=', Timestamp.fromDate(now))
      .orderBy('nextDeadlineAt')
      .limit(limit)
      .get();
    if (snap.empty) return [];
    const dispatch = await this.firestore.getAll(...snap.docs.map((d) => this.firestore.doc(instantDispatchPath(d.id))));
    return snap.docs.flatMap((d, i) => {
      const r = instantRequestFromFirestore(d.id, d.data(), dispatch[i]?.data());
      return r === null ? [] : [r];
    });
  }
}

export class FirestorePresenceDirectory implements PresenceDirectory {
  constructor(private readonly firestore: Firestore) {}

  /** Decision 12; indexes `instant_presence (online, geohash5)` and `(online, geohash4)`. */
  async nearby(q: { field: 'geohash5' | 'geohash4'; cells: readonly string[]; limit: number }): Promise<readonly InstantPresence[]> {
    if (q.cells.length === 0) return [];
    const snap = await this.firestore
      .collection(INSTANT_PRESENCE)
      .where('online', '==', true)
      .where(q.field, 'in', [...q.cells])
      .limit(q.limit)
      .get();
    return snap.docs.flatMap((d) => {
      const p = instantPresenceFromFirestore(d.id, d.data());
      return p === null ? [] : [p];
    });
  }
}
