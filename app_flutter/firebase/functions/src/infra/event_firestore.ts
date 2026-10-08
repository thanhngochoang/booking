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
  type AvailabilityRecord,
  type EventFaq,
  type EventGroupChatSeed,
  type EventPeople,
  type EventRecord,
  type EventStore,
  type EventTx,
  type Payment,
  type Refund,
  type RefundStatus,
  type RegistrationContact,
  type RegistrationDoc,
  type RegistrationReader,
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

export const EVENTS_COLLECTION = 'events';
export const EVENT_HASHTAGS = 'event_hashtags';
export const TICKET_CODES = 'ticket_codes';

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
      type: host.type === 'photographer' ? 'photographer' : 'platform',
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
    createdAt: toDate(d.createdAt) ?? new Date(0),
    updatedAt: toDate(d.updatedAt) ?? new Date(0),
  };
}

// ---- events/{id}/registrations/{regId} -----------------------------------------------------

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
    refundId: r.refundId ?? null,
    refundStatus: r.refundStatus ?? null,
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
    ...(str(d.refundId) !== null ? { refundId: str(d.refundId) as string } : {}),
    ...((REFUND_STATUSES as readonly unknown[]).includes(d.refundStatus) ? { refundStatus: d.refundStatus as RefundStatus } : {}),
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
        activeRegistrationOf: async (eventId, userId) => {
          const rows = await queryRegs(
            regsOf(eventId).where('userId', '==', userId).where('status', 'in', ['held', 'paid']).limit(1),
          );
          return rows[0] ?? null;
        },
        activeRegistrations: (eventId) => queryRegs(regsOf(eventId).where('status', 'in', ['held', 'paid'])),
        expiredHolds: (eventId, now) =>
          queryRegs(regsOf(eventId).where('status', '==', 'held').where('holdExpiresAt', '<=', Timestamp.fromDate(now))),
        availability: async (uid, dayKey) => {
          const d = (await fTx.get(dayRef(uid, dayKey))).data();
          if (d === undefined) return null;
          const state = d.state === 'booked' || d.state === 'pending' ? d.state : 'off';
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
        putEvent: (e) => {
          writes.push(() => fTx.set(eventRef(e.id), eventToFirestore(e)));
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

  /** `refunds` where `subjectType == event_registration`, `status == pending`, `createdAt <= before` (composite index). */
  async pendingTicketRefunds(before: Date, limit: number): Promise<Refund[]> {
    const snap = await this.firestore.collection(REFUNDS_COLLECTION)
      .where('subjectType', '==', 'event_registration')
      .where('status', '==', 'pending')
      .where('createdAt', '<=', Timestamp.fromDate(before))
      .orderBy('createdAt')
      .limit(limit)
      .get();
    return snap.docs.flatMap((d) => refundFromFirestore(d.id, d.data()) ?? []);
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
