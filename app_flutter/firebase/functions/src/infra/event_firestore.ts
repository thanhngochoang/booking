import {
  Timestamp,
  type DocumentData,
  type DocumentReference,
  type Firestore,
  type Query,
  type Transaction,
} from 'firebase-admin/firestore';
import {
  MAX_TX_ATTEMPTS,
  REFUND_STATUSES,
  RetryableConflict,
  entryDayId,
  type AvailabilityRecord,
  type BookingLineDue,
  type EntryDay,
  type EntryLine,
  type EventHost,
  type TicketType,
  type EventFaq,
  type EventGroupChatSeed,
  type EventPeople,
  type EventRecord,
  type EventStore,
  type EventTx,
  type Payment,
  type RefundStatus,
  type RegistrationContact,
  type RegistrationDoc,
  type RegistrationReader,
  type TransferRecord,
  type Venue,
} from '@photobooking/domain';
import { PASSES_COLLECTION, passFromFirestore, passToFirestore, privatePassRef } from './pass_firestore.js';
import {
  LEDGER_COLLECTION,
  PAYMENTS_COLLECTION,
  PAYMENT_NOTIFICATIONS_COLLECTION,
  REFUNDS_COLLECTION,
  ledgerEntryToFirestore,
  paymentFromFirestore,
  paymentToFirestore,
  refundFromFirestore,
  refundToFirestore,
  transferRecordFromFirestore,
  transferRecordToFirestore,
  PAYMENT_GROUPS_COLLECTION,
  paymentGroupToFirestore,
} from './booking_firestore.js';
import { SPOTS_COLLECTION, spotFromFirestore } from './spot_firestore.js';
import { ORGANIZERS_COLLECTION, RESIDENTS_SUBCOLLECTION, organizerFromFirestore, residentFromFirestore } from './organizer_firestore.js';

export const EVENTS_COLLECTION = 'events';
export const EVENT_HASHTAGS = 'event_hashtags';
export const TICKET_CODES = 'ticket_codes';
/** S30: `entry_days/{eventId}_{day}`. */
export const ENTRY_DAYS = 'entry_days';

function toDate(v: unknown): Date | null {
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  return null;
}

const ts = (d: Date | null): Timestamp | null => (d === null ? null : Timestamp.fromDate(d));
const str = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);
const num = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) ? v : null);
const int = (v: unknown): number => (typeof v === 'number' && Number.isInteger(v) ? v : 0);

type Obj = Record<string, unknown>;
const asObj = (v: unknown): Obj => (typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Obj) : {});

// ---- events/{id} ---------------------------------------------------------------------------

/** `host.type` as stored; anything unknown reads as the platform (older documents). */
const hostTypeOf = (v: unknown): EventHost['type'] =>
  v === 'photographer' || v === 'organizer' ? v : 'platform';

/**
 * S30 Decision 16: the venue block and its consent. `venueConsent` is always written (default
 * `not_required`) so the 72 h expiry query (`venueConsent == pending`) matches it.
 */
function venueFieldsToFirestore(e: EventRecord): DocumentData {
  const v = e.venue ?? null;
  return {
    venue: v === null
      ? null
      : {
        kind: v.kind,
        spotId: v.spotId,
        entryFee: { included: v.entryFee.included, amountVnd: v.entryFee.amountVnd },
        commitmentAt: v.commitmentAt,
        termsVersion: v.termsVersion,
      },
    venueConsent: e.venueConsent ?? 'not_required',
    venueConsentExpiresAt: ts(e.venueConsentExpiresAt ?? null),
    venueFeePerGuest: e.venueFeePerGuest ?? 0,
    venueManagerId: e.venueManagerId ?? null,
  };
}

const VENUE_KIND_VALUES: readonly string[] = ['managed_spot', 'paid_place', 'public'];
const CONSENT_VALUES: readonly string[] = ['not_required', 'pending', 'accepted', 'declined', 'expired'];

function venueFromFirestore(v: unknown): Venue | null {
  if (typeof v !== 'object' || v === null || Array.isArray(v)) return null;
  const o = asObj(v);
  const kind = str(o.kind);
  if (kind === null || !VENUE_KIND_VALUES.includes(kind)) return null;
  const fee = asObj(o.entryFee);
  return {
    kind: kind as Venue['kind'],
    spotId: str(o.spotId),
    entryFee: { included: fee.included !== false, amountVnd: num(fee.amountVnd) },
    commitmentAt: str(o.commitmentAt),
    termsVersion: String(o.termsVersion ?? ''),
  };
}

function venueFieldsFromFirestore(d: DocumentData): Partial<EventRecord> {
  const consent = str(d.venueConsent);
  return {
    venue: venueFromFirestore(d.venue),
    venueConsent: (consent !== null && CONSENT_VALUES.includes(consent) ? consent : 'not_required') as EventRecord['hostConsent'],
    venueConsentExpiresAt: toDate(d.venueConsentExpiresAt),
    venueFeePerGuest: int(d.venueFeePerGuest),
    venueManagerId: str(d.venueManagerId),
  };
}

/** S30 entry events only (Decision 11): the per-day rules; absent on every other event. */
function entryFieldsToFirestore(e: EventRecord): DocumentData {
  if (e.type !== 'entry') return {};
  return {
    closedWeekdays: [...(e.closedWeekdays ?? [])],
    closedDays: [...(e.closedDays ?? [])],
    openHours: e.openHours === undefined ? null : { start: e.openHours.start, end: e.openHours.end },
    ticketTypes: (e.ticketTypes ?? []).map((t) => ({ id: t.id, name: t.name, price: t.price, hidden: t.hidden })),
    dailyCapacity: e.dailyCapacity ?? null,
    refundCutoffHours: e.refundCutoffHours ?? null,
  };
}

function entryFieldsFromFirestore(d: DocumentData): Partial<EventRecord> {
  if (d.type !== 'entry') return {};
  const hours = asObj(d.openHours);
  const ints = (v: unknown): number[] => (Array.isArray(v) ? v.filter((x): x is number => Number.isInteger(x)) : []);
  const strs = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []);
  const types: TicketType[] = Array.isArray(d.ticketTypes)
    ? d.ticketTypes.map((x: unknown) => asObj(x)).map((t) => ({
      id: String(t.id ?? ''), name: String(t.name ?? ''), price: int(t.price), hidden: t.hidden === true,
    }))
    : [];
  return {
    closedWeekdays: ints(d.closedWeekdays),
    closedDays: strs(d.closedDays),
    ...(str(hours.start) !== null && str(hours.end) !== null
      ? { openHours: { start: str(hours.start) as string, end: str(hours.end) as string } }
      : {}),
    ticketTypes: types,
    dailyCapacity: num(d.dailyCapacity),
    ...(num(d.refundCutoffHours) !== null ? { refundCutoffHours: num(d.refundCutoffHours) as number } : {}),
  };
}

export function eventToFirestore(e: EventRecord): DocumentData {
  return {
    host: {
      type: e.host.type,
      id: e.host.id,
      name: e.host.name,
      avatarUrl: e.host.avatarUrl,
      verified: e.host.verified,
    },
    hostId: e.host.id,
    createdBy: e.createdBy,
    createdByRole: e.createdByRole,
    hostConsent: e.hostConsent,
    hostConsentExpiresAt: ts(e.hostConsentExpiresAt),
    title: e.title,
    description: e.description,
    type: e.type,
    coverUrl: e.coverUrl,
    coverPath: e.coverPath,
    startAt: ts(e.startAt),
    endAt: ts(e.endAt),
    dayKey: e.dayKey,
    location: e.location === null
      ? null
      : {
        name: e.location.name,
        meetingPoint: e.location.meetingPoint,
        lat: e.location.lat,
        lng: e.location.lng,
        geohash: e.location.geohash,
        areaId: e.location.areaId,
      },
    capacity: e.capacity,
    price: e.price,
    registrationDeadline: ts(e.registrationDeadline),
    faq: e.faq.map((f) => ({ question: f.question, answer: f.answer })),
    hashtag: e.hashtag,
    hashtagKey: e.hashtagKey,
    hashtagLocked: e.hashtagLocked,
    spotId: e.spotId ?? null,
    spotDecided: e.spotDecided === true || (e.spotId ?? null) !== null,
    status: e.status,
    registeredCount: e.registeredCount,
    heldCount: e.heldCount,
    chatId: e.chatId,
    postCount: e.postCount,
    version: e.version,
    publishedAt: ts(e.publishedAt),
    completedAt: ts(e.completedAt),
    cancelledAt: ts(e.cancelledAt),
    // Always written (null when unset) so the reminder query `soonNoticeAt == null` matches it.
    soonNoticeAt: ts(e.soonNoticeAt ?? null),
    // S17 Ruling 7: server-only list of registrations already reminded while the marker is unset.
    soonNotifiedRegIds: [...(e.soonNotifiedRegIds ?? [])],
    ...venueFieldsToFirestore(e),
    ...entryFieldsToFirestore(e),
    createdAt: Timestamp.fromDate(e.createdAt),
    updatedAt: Timestamp.fromDate(e.updatedAt),
  };
}

export function eventFromFirestore(id: string, d: DocumentData): EventRecord {
  const host = asObj(d.host);
  const loc = d.location === null || d.location === undefined ? null : asObj(d.location);
  const faq: EventFaq[] = Array.isArray(d.faq)
    ? d.faq.map((x): EventFaq => ({ question: String(asObj(x).question ?? ''), answer: String(asObj(x).answer ?? '') }))
    : [];
  return {
    id,
    host: {
      type: hostTypeOf(host.type),
      id: str(host.id),
      name: str(host.name),
      avatarUrl: str(host.avatarUrl),
      verified: host.verified === true,
    },
    createdBy: String(d.createdBy ?? ''),
    createdByRole: d.createdByRole === 'admin' || d.createdByRole === 'sales' ? d.createdByRole : 'photographer',
    hostConsent: (str(d.hostConsent) ?? 'not_required') as EventRecord['hostConsent'],
    hostConsentExpiresAt: toDate(d.hostConsentExpiresAt),
    title: String(d.title ?? ''),
    description: String(d.description ?? ''),
    type: (str(d.type) ?? 'other') as EventRecord['type'],
    coverUrl: str(d.coverUrl),
    coverPath: str(d.coverPath),
    startAt: toDate(d.startAt),
    endAt: toDate(d.endAt),
    dayKey: str(d.dayKey),
    location: loc === null
      ? null
      : {
        name: String(loc.name ?? ''),
        meetingPoint: str(loc.meetingPoint),
        lat: num(loc.lat) ?? 0,
        lng: num(loc.lng) ?? 0,
        geohash: String(loc.geohash ?? ''),
        areaId: str(loc.areaId),
      },
    capacity: num(d.capacity),
    price: num(d.price),
    registrationDeadline: toDate(d.registrationDeadline),
    faq,
    hashtag: String(d.hashtag ?? ''),
    hashtagKey: String(d.hashtagKey ?? ''),
    hashtagLocked: d.hashtagLocked === true,
    spotId: str(d.spotId),
    spotDecided: d.spotDecided === true || str(d.spotId) !== null,
    status: (str(d.status) ?? 'draft') as EventRecord['status'],
    registeredCount: int(d.registeredCount),
    heldCount: int(d.heldCount),
    chatId: str(d.chatId),
    postCount: int(d.postCount),
    version: int(d.version),
    publishedAt: toDate(d.publishedAt),
    completedAt: toDate(d.completedAt),
    cancelledAt: toDate(d.cancelledAt),
    soonNoticeAt: toDate(d.soonNoticeAt),
    soonNotifiedRegIds: Array.isArray(d.soonNotifiedRegIds)
      ? d.soonNotifiedRegIds.filter((x: unknown): x is string => typeof x === 'string')
      : [],
    ...venueFieldsFromFirestore(d),
    ...entryFieldsFromFirestore(d),
    createdAt: toDate(d.createdAt) ?? new Date(0),
    updatedAt: toDate(d.updatedAt) ?? new Date(0),
  };
}

// ---- events/{id}/registrations/{regId} -----------------------------------------------------

/** S30 entry tickets only (a string `visitDay`); event tickets carry none of these fields. */
function entryTicketToFirestore(r: RegistrationDoc): DocumentData {
  if (typeof r.visitDay !== 'string') return {};
  return {
    visitDay: r.visitDay,
    items: (r.items ?? []).map((i) => ({ ticketTypeId: i.ticketTypeId, name: i.name, price: i.price, qty: i.qty })),
    bookingId: r.bookingId ?? null,
    gateCheckedInAt: ts(r.gateCheckedInAt ?? null),
    ticketCodeLast4: r.ticketCodeLast4 ?? '',
  };
}

function entryTicketFromFirestore(d: DocumentData): Partial<RegistrationDoc> {
  const visitDay = str(d.visitDay);
  if (visitDay === null) return {};
  const items: EntryLine[] = Array.isArray(d.items)
    ? d.items.map((x: unknown) => asObj(x)).map((i) => ({
      ticketTypeId: String(i.ticketTypeId ?? ''), name: String(i.name ?? ''), price: int(i.price), qty: int(i.qty),
    }))
    : [];
  return {
    visitDay,
    items,
    bookingId: str(d.bookingId),
    gateCheckedInAt: toDate(d.gateCheckedInAt),
    ticketCodeLast4: String(d.ticketCodeLast4 ?? ''),
  };
}

// ---- entry_days/{eventId}_{day} ------------------------------------------------------------

export function entryDayToFirestore(d: EntryDay): DocumentData {
  return {
    eventId: d.eventId,
    day: d.day,
    sold: d.sold,
    held: d.held,
    checkedIn: d.checkedIn,
    closed: d.closed,
    updatedAt: Timestamp.fromDate(new Date(d.updatedAt)),
  };
}

export function entryDayFromFirestore(d: DocumentData | undefined): EntryDay | null {
  if (d === undefined) return null;
  const at = toDate(d.updatedAt);
  return {
    eventId: String(d.eventId ?? ''),
    day: String(d.day ?? ''),
    sold: int(d.sold),
    held: int(d.held),
    checkedIn: int(d.checkedIn),
    closed: d.closed === true,
    updatedAt: (at ?? new Date(0)).toISOString(),
  };
}

/** S30: `bookingLineDue` of a registration bought with a booking (`{percent: 0 | 100, reason}`), or null. */
function bookingLineDueOf(v: unknown): BookingLineDue | null {
  const o = asObj(v);
  const percent = o.percent === 0 || o.percent === 100 ? o.percent : null;
  const reason = o.reason === 'provider_cancelled' || o.reason === 'customer_cancel' ? o.reason : null;
  return percent === null || reason === null ? null : { percent, reason };
}

export function registrationToFirestore(r: RegistrationDoc): DocumentData {
  return {
    id: r.id,
    eventId: r.eventId,
    userId: r.userId,
    userName: r.userName,
    userAvatarUrl: r.userAvatarUrl,
    quantity: r.quantity,
    amount: r.amount,
    status: r.status,
    holdExpiresAt: ts(r.holdExpiresAt),
    ticketCode: r.ticketCode,
    paymentId: r.paymentId,
    contactEligible: r.contactEligible,
    checkedInAt: ts(r.checkedInAt),
    cancelledAt: ts(r.cancelledAt),
    refundPercent: r.refundPercent,
    refundDue: r.refundDue === true,
    bookingLineDue: r.bookingLineDue ? { percent: r.bookingLineDue.percent, reason: r.bookingLineDue.reason } : null,
    refundId: r.refundId ?? null,
    refundStatus: r.refundStatus ?? null,
    // S18: the dispute mirror (written by the dispute transaction) survives every registration write.
    disputeId: r.disputeId ?? null,
    ...entryTicketToFirestore(r),
    event: {
      title: r.event.title,
      type: r.event.type,
      startAt: Timestamp.fromDate(r.event.startAt),
      endAt: Timestamp.fromDate(r.event.endAt),
      locationName: r.event.locationName,
      lat: r.event.lat,
      lng: r.event.lng,
      coverUrl: r.event.coverUrl,
    },
    version: r.version,
    createdAt: Timestamp.fromDate(r.createdAt),
    updatedAt: Timestamp.fromDate(r.updatedAt),
  };
}

export function registrationFromFirestore(id: string, d: DocumentData): RegistrationDoc {
  const ev = asObj(d.event);
  return {
    id,
    eventId: String(d.eventId ?? ''),
    userId: String(d.userId ?? ''),
    userName: String(d.userName ?? ''),
    userAvatarUrl: str(d.userAvatarUrl),
    quantity: int(d.quantity),
    amount: int(d.amount),
    status: (str(d.status) ?? 'cancelled') as RegistrationDoc['status'],
    holdExpiresAt: toDate(d.holdExpiresAt),
    ticketCode: String(d.ticketCode ?? ''),
    paymentId: str(d.paymentId),
    contactEligible: d.contactEligible === true,
    checkedInAt: toDate(d.checkedInAt),
    cancelledAt: toDate(d.cancelledAt),
    refundPercent: num(d.refundPercent),
    ...(d.refundDue === true ? { refundDue: true } : {}),
    ...(bookingLineDueOf(d.bookingLineDue) !== null ? { bookingLineDue: bookingLineDueOf(d.bookingLineDue) } : {}),
    ...(str(d.refundId) !== null ? { refundId: str(d.refundId) as string } : {}),
    ...((REFUND_STATUSES as readonly unknown[]).includes(d.refundStatus) ? { refundStatus: d.refundStatus as RefundStatus } : {}),
    ...(str(d.disputeId) !== null ? { disputeId: str(d.disputeId) as string } : {}),
    ...entryTicketFromFirestore(d),
    event: {
      title: String(ev.title ?? ''),
      type: (str(ev.type) ?? 'other') as RegistrationDoc['event']['type'],
      startAt: toDate(ev.startAt) ?? new Date(0),
      endAt: toDate(ev.endAt) ?? new Date(0),
      locationName: String(ev.locationName ?? ''),
      lat: num(ev.lat) ?? 0,
      lng: num(ev.lng) ?? 0,
      coverUrl: str(ev.coverUrl),
    },
    version: int(d.version),
    createdAt: toDate(d.createdAt) ?? new Date(0),
    updatedAt: toDate(d.updatedAt) ?? new Date(0),
  };
}

export function groupChatToFirestore(c: EventGroupChatSeed): DocumentData {
  return {
    kind: c.kind,
    eventId: c.eventId,
    title: c.title,
    members: [...c.members],
    moderators: [...c.moderators],
    memberCount: c.memberCount,
    moderatorsOnly: c.moderatorsOnly,
    lastMessageAt: ts(c.lastMessageAt),
    lastMessagePreview: c.lastMessagePreview,
    lastSenderId: c.lastSenderId,
    readOnlyAt: ts(c.readOnlyAt),
    createdAt: Timestamp.fromDate(c.createdAt),
    updatedAt: Timestamp.fromDate(c.updatedAt),
  };
}

// ---- the store -----------------------------------------------------------------------------

/**
 * Events in Firestore. Reads go straight to the transaction; every write is buffered until the
 * callback has finished all its reads (Firestore needs reads before writes), then applied together,
 * so a refusal never leaves a partial write. A `RetryableConflict` (all ticket-code candidates
 * taken) runs the transaction again, like the memory store.
 */
export class FirestoreEventStore implements EventStore {
  constructor(private readonly firestore: Firestore) {}

  async runTransaction<T>(fn: (tx: EventTx) => Promise<T>): Promise<T> {
    for (let attempt = 1; ; attempt++) {
      try {
        return await this.attempt(fn);
      } catch (e) {
        if (!(e instanceof RetryableConflict) || attempt >= MAX_TX_ATTEMPTS) throw e;
      }
    }
  }

  private attempt<T>(fn: (tx: EventTx) => Promise<T>): Promise<T> {
    const fs = this.firestore;
    return fs.runTransaction(async (fTx: Transaction) => {
      const eventRef = (id: string): DocumentReference => fs.collection(EVENTS_COLLECTION).doc(id);
      const regsOf = (eventId: string) => eventRef(eventId).collection('registrations');
      const regRef = (eventId: string, regId: string): DocumentReference => regsOf(eventId).doc(regId);
      const dayRef = (uid: string, dayKey: string): DocumentReference =>
        fs.doc(`availability/${uid}/days/${dayKey}`);
      const writes: Array<() => void> = [];
      const queryRegs = async (q: Query): Promise<RegistrationDoc[]> =>
        (await fTx.get(q)).docs.map((s) => registrationFromFirestore(s.id, s.data()));

      const tx: EventTx = {
        getEvent: async (id) => {
          const s = await fTx.get(eventRef(id));
          const d = s.data();
          return s.exists && d ? eventFromFirestore(id, d) : null;
        },
        getSpot: async (id) => {
          const snap = await fTx.get(fs.collection(SPOTS_COLLECTION).doc(id));
          return spotFromFirestore(snap.id, snap.data());
        },
        hashtagOwner: async (key) => {
          const s = await fTx.get(fs.collection(EVENT_HASHTAGS).doc(key));
          return s.exists ? str(s.data()?.eventId) : null;
        },
        ticketCodeTaken: async (code) => (await fTx.get(fs.collection(TICKET_CODES).doc(code))).exists,
        findTicket: async (code) => {
          const d = (await fTx.get(fs.collection(TICKET_CODES).doc(code))).data();
          const eventId = str(d?.eventId);
          const registrationId = str(d?.registrationId);
          return eventId !== null && registrationId !== null ? { eventId, registrationId } : null;
        },
        getRegistration: async (eventId, regId) => {
          const s = await fTx.get(regRef(eventId, regId));
          const d = s.data();
          return s.exists && d ? registrationFromFirestore(regId, d) : null;
        },
        activeRegistrationOf: async (eventId, userId, visitDay) => {
          const mine = regsOf(eventId).where('userId', '==', userId).where('status', 'in', ['held', 'paid']);
          if (visitDay === undefined) return (await queryRegs(mine.limit(1)))[0] ?? null;
          // Entry tickets (S30): the lone ticket of that visit day; a customer holds a few at most.
          const rows = await queryRegs(mine);
          return rows.find((r) => r.visitDay === visitDay && (r.bookingId ?? null) === null) ?? null;
        },
        registrationsOfDay: (eventId, day) =>
          queryRegs(regsOf(eventId).where('visitDay', '==', day).where('status', '==', 'paid')),
        getEntryDay: async (eventId, day) =>
          entryDayFromFirestore((await fTx.get(fs.collection(ENTRY_DAYS).doc(entryDayId(eventId, day)))).data()),
        getOrganizer: async (uid) =>
          organizerFromFirestore(uid, (await fTx.get(fs.collection(ORGANIZERS_COLLECTION).doc(uid))).data()),
        residentOf: async (spotId, providerId) =>
          residentFromFirestore(providerId, (await fTx.get(
            fs.collection(SPOTS_COLLECTION).doc(spotId).collection(RESIDENTS_SUBCOLLECTION).doc(providerId),
          )).data()),
        activeRegistrations: (eventId) => queryRegs(regsOf(eventId).where('status', 'in', ['held', 'paid'])),
        expiredHolds: (eventId, now) =>
          queryRegs(regsOf(eventId).where('status', '==', 'held').where('holdExpiresAt', '<=', Timestamp.fromDate(now))),
        availability: async (uid, dayKey) => {
          const d = (await fTx.get(dayRef(uid, dayKey))).data();
          if (d === undefined) return null;
          const state = d.state === 'booked' || d.state === 'pending' || d.state === 'spot' ? d.state : 'off';
          const rec: AvailabilityRecord = {
            state,
            ...(str(d.eventId) !== null ? { eventId: str(d.eventId) as string } : {}),
            ...(str(d.bookingId) !== null ? { bookingId: str(d.bookingId) as string } : {}),
          };
          return rec;
        },
        getPayment: async (id) => {
          const s = await fTx.get(fs.collection(PAYMENTS_COLLECTION).doc(id));
          return s.exists ? paymentFromFirestore(s.id, s.data()) : null;
        },
        paymentByIdempotencyKey: async (key) => {
          const snap = await fTx.get(fs.collection(PAYMENTS_COLLECTION).where('idempotencyKey', '==', key).limit(1));
          const doc = snap.docs[0];
          return doc === undefined ? null : paymentFromFirestore(doc.id, doc.data());
        },
        heldTicketPayments: async (eventId) => {
          const snap = await fTx.get(
            fs.collection(PAYMENTS_COLLECTION)
              .where('eventId', '==', eventId)
              .where('status', '==', 'paid')
              .where('escrowStatus', 'in', ['held', 'partially_refunded']),
          );
          return snap.docs
            .map((d) => paymentFromFirestore(d.id, d.data()))
            .filter((p): p is Payment => p !== null && p.subjectType === 'event_registration');
        },
        getRefund: async (id) => {
          const s = await fTx.get(fs.collection(REFUNDS_COLLECTION).doc(id));
          return s.exists ? refundFromFirestore(s.id, s.data()) : null;
        },
        getTransferRecord: async (id) => {
          const s = await fTx.get(fs.collection(PAYMENT_NOTIFICATIONS_COLLECTION).doc(id));
          return s.exists ? transferRecordFromFirestore(s.id, s.data()) : null;
        },
        // S30 passes (Decision 7; the scan adapter is Task 6's).
        getPass: async (code8) => passFromFirestore(code8, (await fTx.get(fs.collection(PASSES_COLLECTION).doc(code8))).data()),
        passTaken: async (code8) => (await fTx.get(fs.collection(PASSES_COLLECTION).doc(code8))).exists,
        putPass: (p) => {
          writes.push(() => fTx.set(fs.collection(PASSES_COLLECTION).doc(p.code8), passToFirestore(p)));
        },
        putPrivatePass: (ref, code8) => {
          writes.push(() => fTx.set(privatePassRef(fs, ref), { code: code8 }));
        },
        putTransferRecord: (r: TransferRecord) => {
          writes.push(() => fTx.set(fs.collection(PAYMENT_NOTIFICATIONS_COLLECTION).doc(r.id), transferRecordToFirestore(r)));
        },
        putEvent: (e) => {
          writes.push(() => fTx.set(eventRef(e.id), eventToFirestore(e)));
        },
        putEntryDay: (d) => {
          writes.push(() => fTx.set(fs.collection(ENTRY_DAYS).doc(entryDayId(d.eventId, d.day)), entryDayToFirestore(d)));
        },
        putHashtag: (key, eventId) => {
          writes.push(() => fTx.set(fs.collection(EVENT_HASHTAGS).doc(key), { eventId }));
        },
        deleteHashtag: (key) => {
          writes.push(() => fTx.delete(fs.collection(EVENT_HASHTAGS).doc(key)));
        },
        putTicketCode: (code, eventId, registrationId) => {
          writes.push(() => fTx.set(fs.collection(TICKET_CODES).doc(code), { eventId, registrationId }));
        },
        putRegistration: (r) => {
          writes.push(() => fTx.set(regRef(r.eventId, r.id), registrationToFirestore(r)));
        },
        putRegistrationContact: (eventId, regId, c: RegistrationContact) => {
          writes.push(() =>
            fTx.set(regRef(eventId, regId).collection('private').doc('contact'), {
              name: c.name,
              phone: c.phone,
              allowZalo: c.allowZalo,
              allowWhatsApp: c.allowWhatsApp,
            }),
          );
        },
        deleteRegistrationContact: (eventId, regId) => {
          writes.push(() => fTx.delete(regRef(eventId, regId).collection('private').doc('contact')));
        },
        putPayment: (p) => {
          writes.push(() => fTx.set(fs.collection(PAYMENTS_COLLECTION).doc(p.id), paymentToFirestore(p)));
        },
        putGroupView: (g) => {
          writes.push(() => fTx.set(fs.collection(PAYMENT_GROUPS_COLLECTION).doc(g.id), paymentGroupToFirestore(g)));
        },
        putRefund: (r) => {
          writes.push(() => fTx.set(fs.collection(REFUNDS_COLLECTION).doc(r.id), refundToFirestore(r)));
        },
        putLedgerEntry: (e) => {
          writes.push(() => fTx.set(fs.collection(LEDGER_COLLECTION).doc(e.id), ledgerEntryToFirestore(e)));
        },
        setAvailabilityBooked: (uid, dayKey, eventId) => {
          writes.push(() => fTx.set(dayRef(uid, dayKey), { state: 'booked', eventId, updatedAt: Timestamp.now() }));
        },
        deleteAvailability: (uid, dayKey) => {
          writes.push(() => fTx.delete(dayRef(uid, dayKey)));
        },
        putGroupChat: (chat) => {
          writes.push(() => fTx.set(fs.collection('chats').doc(chat.id), groupChatToFirestore(chat)));
          // The moderators are members from the start; their member docs carry the names the list shows.
          for (const p of chat.memberProfiles) {
            writes.push(() =>
              fTx.set(fs.collection('chats').doc(chat.id).collection('members').doc(p.uid), {
                role: 'moderator',
                name: p.name,
                avatarUrl: p.avatarUrl,
                mutedUntil: null,
                joinedAt: Timestamp.fromDate(chat.createdAt),
                removedAt: null,
                removedBy: null,
                sentWindowStart: null,
                sentInWindow: 0,
              }),
            );
          }
        },
        setChatReadOnlyAt: (chatId, at) => {
          writes.push(() =>
            fTx.set(
              fs.collection('chats').doc(chatId),
              { readOnlyAt: Timestamp.fromDate(at), updatedAt: Timestamp.now() },
              { merge: true },
            ),
          );
        },
      };

      const result = await fn(tx);
      for (const w of writes) w();
      return result;
    });
  }

  private async due(q: Query, limit: number): Promise<EventRecord[]> {
    const snap = await q.limit(limit).get();
    return snap.docs.map((s) => eventFromFirestore(s.id, s.data()));
  }

  dueForClose(now: Date, limit: number): Promise<EventRecord[]> {
    return this.due(
      this.firestore.collection(EVENTS_COLLECTION)
        .where('status', 'in', ['open', 'full'])
        .where('registrationDeadline', '<=', Timestamp.fromDate(now)),
      limit,
    );
  }

  dueForCompletion(now: Date, limit: number): Promise<EventRecord[]> {
    return this.due(
      this.firestore.collection(EVENTS_COLLECTION)
        .where('status', 'in', ['open', 'full', 'closed'])
        .where('endAt', '<=', Timestamp.fromDate(now)),
      limit,
    );
  }

  /** Collection group `registrations` (status, holdExpiresAt): index in firestore.indexes.json. */
  async expiredHoldsAll(now: Date, limit: number): Promise<RegistrationDoc[]> {
    const snap = await this.firestore.collectionGroup('registrations')
      .where('status', '==', 'held')
      .where('holdExpiresAt', '<=', Timestamp.fromDate(now))
      .limit(limit)
      .get();
    return snap.docs
      .filter((d) => d.ref.parent.parent?.parent.id === EVENTS_COLLECTION)
      .map((d) => registrationFromFirestore(d.id, d.data()));
  }

  /** Collection group `registrations` where `refundDue == true` (single-field override). */
  async paidUnrefundedOfCancelled(limit: number): Promise<RegistrationDoc[]> {
    const snap = await this.firestore.collectionGroup('registrations').where('refundDue', '==', true).limit(limit).get();
    return snap.docs
      .filter((d) => d.ref.parent.parent?.parent.id === EVENTS_COLLECTION)
      .map((d) => registrationFromFirestore(d.id, d.data()));
  }


  /** S17 reminder: composite index events (status, soonNoticeAt, startAt) in firestore.indexes.json. */
  dueForSoonNotice(now: Date, horizon: Date, limit: number): Promise<EventRecord[]> {
    return this.due(
      this.firestore.collection(EVENTS_COLLECTION)
        .where('status', 'in', ['open', 'full', 'closed'])
        .where('soonNoticeAt', '==', null)
        .where('startAt', '>', Timestamp.fromDate(now))
        .where('startAt', '<=', Timestamp.fromDate(horizon)),
      limit,
    );
  }

  /** S30 Decision 16. Needs the composite index `events(status, venueConsent, venueConsentExpiresAt)` (Task 6). */
  dueForVenueConsentExpiry(now: Date, limit: number): Promise<EventRecord[]> {
    return this.due(
      this.firestore.collection(EVENTS_COLLECTION)
        .where('status', '==', 'draft')
        .where('venueConsent', '==', 'pending')
        .where('venueConsentExpiresAt', '<=', Timestamp.fromDate(now)),
      limit,
    );
  }

  dueForConsentExpiry(now: Date, limit: number): Promise<EventRecord[]> {
    return this.due(
      this.firestore.collection(EVENTS_COLLECTION)
        .where('status', '==', 'draft')
        .where('hostConsent', '==', 'pending')
        .where('hostConsentExpiresAt', '<=', Timestamp.fromDate(now)),
      limit,
    );
  }
}

// ---- people, media, contact-link reader ---------------------------------------------------

/** Names and onboarding flags the event use cases look up (never trusted from the client). */
export function firestoreEventPeople(firestore: Firestore): EventPeople {
  const user = async (uid: string) => {
    const [u] = await firestore.getAll(firestore.collection('users').doc(uid));
    const d = u?.data();
    if (u === undefined || !u.exists || d === undefined) return null;
    return { name: str(d.displayName) ?? 'Người dùng', avatarUrl: str(d.avatarUrl) };
  };
  return {
    user,
    async photographer(uid) {
      const [p, u] = await firestore.getAll(
        firestore.collection('photographers').doc(uid),
        firestore.collection('users').doc(uid),
      );
      const pd = p?.data();
      if (p === undefined || !p.exists || pd === undefined) return null;
      const ud = u?.data();
      return {
        onboardingComplete: pd.onboardingComplete === true,
        name: str(ud?.displayName) ?? 'Nhiếp ảnh gia',
        avatarUrl: str(ud?.avatarUrl),
        verified: pd.verified === true,
      };
    },
  };
}

/**
 * A cover is the caller's own upload: `coverPath` is `eventCovers/{uid}/{eventId}/{file}` and
 * `coverUrl` is a download URL of exactly that object in this project's bucket.
 */
export function ownCoverUpload(prefixes: readonly string[]) {
  return (url: string, path: string, uid: string, eventId: string): boolean => {
    if (!/^eventCovers\/[A-Za-z0-9_-]+\/[A-Za-z0-9_-]+\/[^/]+$/.test(path)) return false;
    if (!path.startsWith(`eventCovers/${uid}/${eventId}/`)) return false;
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

/** `getContactLink` for a ticket: collection-group `registrations where id == regId`, plus the parent event. */
export function firestoreRegistrationReader(firestore: Firestore): RegistrationReader {
  return {
    async get(id) {
      const snap = await firestore.collectionGroup('registrations').where('id', '==', id).limit(1).get();
      const doc = snap.docs[0];
      if (doc === undefined) return null;
      const reg = doc.data();
      const eventRef = doc.ref.parent.parent;
      if (eventRef === null || eventRef.parent.id !== EVENTS_COLLECTION) return null;
      const ev = (await eventRef.get()).data();
      if (ev === undefined) return null;
      return {
        id: doc.id,
        userId: String(reg.userId ?? ''),
        photographerId: str(ev.hostId),
        status: String(reg.status ?? ''),
        eventEndsAt: toDate(ev.endAt),
        contactEligible: reg.contactEligible === true,
      };
    },
  };
}
