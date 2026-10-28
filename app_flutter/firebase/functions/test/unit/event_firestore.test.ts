import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { readFileSync } from 'node:fs';
import { Timestamp, type DocumentData } from 'firebase-admin/firestore';
import type { EventRecord, Refund, RegistrationDoc } from '@photobooking/domain';
import { paymentFromFirestore, paymentToFirestore, refundFromFirestore, refundToFirestore } from '../../src/infra/booking_firestore.js';
import {
  FirestoreEventStore,
  entryDayFromFirestore,
  entryDayToFirestore,
  eventFromFirestore,
  eventToFirestore,
  firestoreRegistrationReader,
  registrationFromFirestore,
  registrationToFirestore,
} from '../../src/infra/event_firestore.js';

const D = (s: string): Date => new Date(s);

const event = (over: Partial<EventRecord> = {}): EventRecord => ({
  id: 'ev1',
  host: { type: 'photographer', id: 'ph1', name: 'Lan', avatarUrl: null, verified: true },
  createdBy: 'ad1',
  createdByRole: 'admin',
  hostConsent: 'pending',
  hostConsentExpiresAt: D('2026-10-07T03:00:00.000Z'),
  title: 'Photo walk',
  description: 'Mô tả',
  type: 'photo_walk',
  coverUrl: 'https://s.test/c.jpg',
  coverPath: 'eventCovers/ad1/ev1/c.jpg',
  startAt: D('2026-10-12T02:00:00.000Z'),
  endAt: D('2026-10-12T05:00:00.000Z'),
  dayKey: '2026-10-12',
  location: { name: 'Hồ Gươm', meetingPoint: null, lat: 21.0285, lng: 105.8542, geohash: 'w7er8u0xx', areaId: null },
  capacity: 10,
  price: 0,
  registrationDeadline: D('2026-10-11T14:00:00.000Z'),
  faq: [{ question: 'Mang gì?', answer: 'Máy ảnh' }],
  hashtag: 'PhotoWalk1012',
  hashtagKey: 'photowalk1012',
  hashtagLocked: false,
  spotId: 'spot-ho-guom',
  spotDecided: true,
  status: 'draft',
  registeredCount: 0,
  heldCount: 0,
  chatId: null,
  postCount: 0,
  version: 1,
  publishedAt: null,
  completedAt: null,
  cancelledAt: null,
  soonNoticeAt: null,
  soonNotifiedRegIds: [],
  venue: null,
  venueConsent: 'not_required',
  venueConsentExpiresAt: null,
  venueFeePerGuest: 0,
  venueManagerId: null,
  createdAt: D('2026-10-06T03:00:00.000Z'),
  updatedAt: D('2026-10-06T03:00:00.000Z'),
  ...over,
});

const registration = (over: Partial<RegistrationDoc> = {}): RegistrationDoc => ({
  id: 'r1',
  eventId: 'ev1',
  userId: 'cu1',
  userName: 'Khách',
  userAvatarUrl: null,
  quantity: 2,
  amount: 0,
  status: 'paid',
  holdExpiresAt: null,
  ticketCode: 'VE-ABCD-1012',
  paymentId: null,
  contactEligible: false,
  checkedInAt: null,
  cancelledAt: null,
  refundPercent: null,
  event: {
    title: 'Photo walk', type: 'photo_walk', startAt: D('2026-10-12T02:00:00.000Z'),
    endAt: D('2026-10-12T05:00:00.000Z'), locationName: 'Hồ Gươm', lat: 21.0285, lng: 105.8542, coverUrl: null,
  },
  version: 1,
  createdAt: D('2026-10-06T03:00:00.000Z'),
  updatedAt: D('2026-10-06T03:00:00.000Z'),
  ...over,
});

describe('Firestore mapping for events', () => {
  it('event maps to and from Firestore with UTC timestamps', () => {
    const e = event();
    const doc = eventToFirestore(e);
    assert.ok(doc.startAt instanceof Timestamp);
    assert.ok(doc.hostConsentExpiresAt instanceof Timestamp);
    assert.equal(doc.startAt.toDate().toISOString(), '2026-10-12T02:00:00.000Z');
    assert.equal(doc.hostId, 'ph1');
    assert.equal(doc.publishedAt, null);
    assert.deepEqual(eventFromFirestore('ev1', doc), e);
  });

  it('the venue block, its consent and fee round-trip (S30 Decision 16); an old event reads no venue', () => {
    const e = event({
      venue: { kind: 'managed_spot', spotId: 's1', entryFee: { included: true, amountVnd: null }, commitmentAt: null, termsVersion: '2026-10-18' },
      venueConsent: 'pending', venueConsentExpiresAt: D('2026-10-09T03:00:00.000Z'), venueFeePerGuest: 20_000, venueManagerId: 'org1',
    });
    const doc = eventToFirestore(e);
    assert.ok(doc.venueConsentExpiresAt instanceof Timestamp);
    assert.equal(doc.venue.spotId, 's1');
    assert.deepEqual(eventFromFirestore('ev1', doc), e);
    const pub = event({ venue: { kind: 'public', spotId: null, entryFee: { included: true, amountVnd: null }, commitmentAt: '2026-10-06T02:00:00.000Z', termsVersion: '2026-10-18' } });
    assert.deepEqual(eventFromFirestore('ev1', eventToFirestore(pub)), pub);
    const venueKeys = new Set(['venue', 'venueConsent', 'venueConsentExpiresAt', 'venueFeePerGuest', 'venueManagerId']);
    const old = Object.fromEntries(Object.entries(eventToFirestore(event())).filter(([k]) => !venueKeys.has(k)));
    const back = eventFromFirestore('ev1', old);
    assert.deepEqual([back.venue, back.venueConsent, back.venueFeePerGuest], [null, 'not_required', 0]);
  });

  it('the venue consent expiry query has its composite index', () => {
    const json = JSON.parse(readFileSync(new URL('../../../firestore.indexes.json', import.meta.url), 'utf8')) as {
      indexes: { collectionGroup: string; fields: { fieldPath: string }[] }[];
    };
    const has = json.indexes.some((i) => i.collectionGroup === 'events'
      && i.fields.map((f) => f.fieldPath).join(',') === 'status,venueConsent,venueConsentExpiresAt');
    assert.equal(has, true);
  });

  it('a platform event has a null hostId', () => {
    const e = event({ host: { type: 'platform', id: null, name: null, avatarUrl: null, verified: true }, hostConsent: 'not_required', hostConsentExpiresAt: null });
    const doc = eventToFirestore(e);
    assert.equal(doc.hostId, null);
    assert.deepEqual(eventFromFirestore('ev1', doc), e);
  });

  it('a draft without schedule or place round-trips', () => {
    const e = event({ startAt: null, endAt: null, dayKey: null, location: null, capacity: null, price: null,
      registrationDeadline: null, coverUrl: null, coverPath: null });
    assert.deepEqual(eventFromFirestore('ev1', eventToFirestore(e)), e);
  });

  it('an event without spotId reads null', () => {
    const doc = eventToFirestore(event());
    delete doc.spotId;
    delete doc.spotDecided;
    const back = eventFromFirestore('ev1', doc);
    assert.equal(back.spotId, null);
    assert.equal(back.spotDecided, false);
  });

  it('a decided "none" round-trips as decided with spotId null', () => {
    const e = event({ spotId: null, spotDecided: true });
    const back = eventFromFirestore('ev1', eventToFirestore(e));
    assert.equal(back.spotId, null);
    assert.equal(back.spotDecided, true);
  });

  it('soonNoticeAt round-trips; absent reads null', () => {
    const e = event({ status: 'open', soonNoticeAt: D('2026-10-10T13:00:00.000Z') });
    const doc = eventToFirestore(e);
    assert.ok(doc.soonNoticeAt instanceof Timestamp);
    assert.deepEqual(eventFromFirestore('ev1', doc), e);
    // Written as null when the record has none, so the reminder query (== null) matches it.
    assert.equal(eventToFirestore({ ...event(), soonNoticeAt: undefined }).soonNoticeAt, null);
    // An older document without the field reads null.
    const old = { ...eventToFirestore(event()) };
    delete old.soonNoticeAt;
    assert.equal(eventFromFirestore('ev1', old).soonNoticeAt, null);
  });

  it('soonNotifiedRegIds round-trips; absent or malformed reads []', () => {
    const e = event({ status: 'open', soonNotifiedRegIds: ['rg1', 'rg2'] });
    const doc = eventToFirestore(e);
    assert.deepEqual(doc.soonNotifiedRegIds, ['rg1', 'rg2']);
    assert.deepEqual(eventFromFirestore('ev1', doc), e);
    // Written as [] when the record has none.
    assert.deepEqual(eventToFirestore({ ...event(), soonNotifiedRegIds: undefined }).soonNotifiedRegIds, []);
    const old = { ...eventToFirestore(event()) };
    delete old.soonNotifiedRegIds;
    assert.deepEqual(eventFromFirestore('ev1', old).soonNotifiedRegIds, []);
    assert.deepEqual(eventFromFirestore('ev1', { ...old, soonNotifiedRegIds: ['rg1', 7, null] }).soonNotifiedRegIds, ['rg1']);
  });

  it('dueForSoonNotice builds the status/soonNoticeAt/startAt query with the limit', async () => {
    const asked: unknown[] = [];
    const evDoc = eventToFirestore(event({ status: 'open' }));
    const q = {
      where: (...args: unknown[]) => { asked.push(['where', ...args]); return q; },
      limit: (n: number) => { asked.push(['limit', n]); return q; },
      get: async () => ({ docs: [{ id: 'ev1', data: () => evDoc }] }),
    };
    const firestore = { collection: (name: string) => { asked.push(['collection', name]); return q; } };
    const now = D('2026-10-10T13:00:00.000Z');
    const horizon = D('2026-10-12T13:00:00.000Z');
    const got = await new FirestoreEventStore(firestore as never).dueForSoonNotice(now, horizon, 200);
    assert.deepEqual(got.map((e) => e.id), ['ev1']);
    assert.deepEqual(asked, [
      ['collection', 'events'],
      ['where', 'status', 'in', ['open', 'full', 'closed']],
      ['where', 'soonNoticeAt', '==', null],
      ['where', 'startAt', '>', Timestamp.fromDate(now)],
      ['where', 'startAt', '<=', Timestamp.fromDate(horizon)],
      ['limit', 200],
    ]);
  });

  it('a registration snapshot round-trips and carries no phone', () => {
    const r = registration({ contactEligible: true, amount: 120000, checkedInAt: D('2026-10-12T02:10:00.000Z') });
    const doc = registrationToFirestore(r);
    assert.ok(doc.event.startAt instanceof Timestamp);
    assert.equal('phone' in doc, false);
    assert.deepEqual(registrationFromFirestore('r1', doc), r);
  });

  it('a refunded ticket keeps its refund id and state; a refund keeps its subject', () => {
    const r = registration({ status: 'refunded', amount: 250000, refundPercent: 100, refundId: 'rf1', refundStatus: 'pending' });
    const doc = registrationToFirestore(r);
    assert.deepEqual([doc.refundId, doc.refundStatus], ['rf1', 'pending']);
    assert.deepEqual(registrationFromFirestore('r1', doc), r);
    assert.equal(registrationFromFirestore('r1', { ...doc, refundStatus: 'bogus' }).refundStatus, undefined);
    const plain = registrationToFirestore(registration());
    assert.deepEqual([plain.refundId, plain.refundStatus], [null, null]);
    const refund: Refund = {
      id: 'rf1', paymentId: 'p1', subjectType: 'event_registration', amount: 250000, percent: 100, status: 'pending',
      method: 'gateway', attempts: 0,
      manual: false, fromEscrow: true, reason: 'customer_cancel', createdAt: '2026-10-06T03:00:00.000Z', updatedAt: '2026-10-06T03:00:00.000Z',
    };
    assert.deepEqual(refundFromFirestore('rf1', refundToFirestore(refund)), refund);
    const old = refundToFirestore({ ...refund, subjectType: undefined });
    assert.equal(old.subjectType, null);
    assert.equal('subjectType' in (refundFromFirestore('rf1', old) ?? {}), false);
  });


  it('registration mapping round-trips disputeId', () => {
    const r = registration({ status: 'paid', amount: 250000, disputeId: 'dsp_01' });
    const doc = registrationToFirestore(r);
    assert.equal(doc.disputeId, 'dsp_01');
    assert.deepEqual(registrationFromFirestore('r1', doc), r);
    // A registration without a dispute writes null and reads the field absent (so the next write keeps null).
    const plain = registrationToFirestore(registration());
    assert.equal(plain.disputeId, null);
    assert.equal('disputeId' in registrationFromFirestore('r1', plain), false);
  });

  it('registration reader returns the host and end time', async () => {
    const reg = registrationToFirestore(registration({ contactEligible: true }));
    const evDoc = eventToFirestore(event({ status: 'open' }));
    const eventRef = { parent: { id: 'events' }, get: async () => ({ data: () => evDoc }) };
    const regDoc = { id: 'r1', data: () => reg, ref: { parent: { parent: eventRef } } };
    let asked: unknown[] = [];
    const firestore = {
      collectionGroup: (name: string) => ({
        where: (...args: unknown[]) => {
          asked = [name, ...args];
          return { limit: () => ({ get: async () => ({ docs: [regDoc] }) }) };
        },
      }),
    };
    const got = await firestoreRegistrationReader(firestore as never).get('r1');
    assert.deepEqual(asked, ['registrations', 'id', '==', 'r1']);
    assert.deepEqual(got, {
      id: 'r1',
      userId: 'cu1',
      photographerId: 'ph1',
      status: 'paid',
      eventEndsAt: D('2026-10-12T05:00:00.000Z'),
      contactEligible: true,
    });
  });

  it('registration reader answers null for an unknown id', async () => {
    const firestore = {
      collectionGroup: () => ({ where: () => ({ limit: () => ({ get: async () => ({ docs: [] }) }) }) }),
    };
    assert.equal(await firestoreRegistrationReader(firestore as never).get('nope'), null);
  });

  it('event adapter maps state spot to spot, not off', async () => {
    const firestore = {
      runTransaction: async (fn: (fTx: unknown) => Promise<unknown>) => {
        const fTx = {
          get: async () => ({ data: () => ({ state: 'spot' }) }),
        };
        return fn(fTx);
      },
      doc: () => ({}),
      collection: () => ({}),
    };
    const store = new FirestoreEventStore(firestore as never);
    const rec = await store.runTransaction(async (tx) => {
      return (await tx.availability('ph1', '2026-10-18')) as { state: string };
    });
    assert.equal(rec.state, 'spot');
  });
});

describe('Firestore mapping for entry events (S30, #223)', () => {
  const entry = (over: Partial<EventRecord> = {}): EventRecord => event({
    type: 'entry', status: 'open', hostConsent: 'not_required', hostConsentExpiresAt: null,
    host: { type: 'organizer', id: 'org1', name: 'Bãi đá sông Hồng', avatarUrl: null, verified: true },
    createdBy: 'org1', createdByRole: 'photographer', dayKey: null, capacity: null, price: null,
    registrationDeadline: null, faq: [], hashtag: '', hashtagKey: '', hashtagLocked: true, spotId: 's1',
    startAt: D('2026-10-17T17:00:00.000Z'), endAt: D('2026-12-31T17:00:00.000Z'),
    closedWeekdays: [1], closedDays: ['2026-10-25'], openHours: { start: '08:00', end: '17:00' },
    ticketTypes: [{ id: 'adult', name: 'Người lớn', price: 70_000, hidden: false }, { id: 'old', name: 'Vé cũ', price: 50_000, hidden: true }],
    dailyCapacity: 10, refundCutoffHours: 48,
    ...over,
  });

  it('an organizer-hosted event keeps host.type organizer on read (not platform)', () => {
    const doc = eventToFirestore(entry());
    assert.deepEqual([doc.host.type, doc.hostId], ['organizer', 'org1']);
    assert.deepEqual(eventFromFirestore('ev1', doc).host, { type: 'organizer', id: 'org1', name: 'Bãi đá sông Hồng', avatarUrl: null, verified: true });
    // An unknown stored type still reads as the platform.
    assert.equal(eventFromFirestore('ev1', { ...doc, host: { ...doc.host, type: 'robot' } }).host.type, 'platform');
  });

  it('an entry event round-trips its day rules; other events carry none', () => {
    const e = entry();
    const doc = eventToFirestore(e);
    assert.deepEqual(doc.ticketTypes[1], { id: 'old', name: 'Vé cũ', price: 50_000, hidden: true });
    assert.deepEqual(eventFromFirestore('ev1', doc), e);
    assert.deepEqual(eventFromFirestore('ev1', eventToFirestore(entry({ dailyCapacity: null }))).dailyCapacity, null);
    const plain = eventToFirestore(event());
    for (const k of ['closedWeekdays', 'closedDays', 'openHours', 'ticketTypes', 'dailyCapacity', 'refundCutoffHours']) {
      assert.equal(k in plain, false, k);
    }
  });

  it('an entry ticket round-trips visitDay, items, bookingId, gateCheckedInAt and ticketCodeLast4', () => {
    const r = registration({
      status: 'held', amount: 180_000, quantity: 3, holdExpiresAt: D('2026-10-18T03:15:00.000Z'), paymentId: 'p1',
      ticketCode: 'VE-ABCD-1022', ticketCodeLast4: 'ABCD', visitDay: '2026-10-22', bookingId: null,
      gateCheckedInAt: null,
      items: [{ ticketTypeId: 'adult', name: 'Người lớn', price: 70_000, qty: 2 }, { ticketTypeId: 'child', name: 'Trẻ em', price: 40_000, qty: 1 }],
    });
    const doc = registrationToFirestore(r);
    assert.deepEqual([doc.visitDay, doc.ticketCodeLast4, doc.bookingId, doc.gateCheckedInAt], ['2026-10-22', 'ABCD', null, null]);
    assert.deepEqual(registrationFromFirestore('r1', doc), r);
    const checked = registration({ visitDay: '2026-10-22', items: [], bookingId: 'bk1', ticketCodeLast4: 'WXYZ', gateCheckedInAt: D('2026-10-22T02:00:00.000Z') });
    assert.deepEqual(registrationFromFirestore('r1', registrationToFirestore(checked)), checked);
    assert.equal('visitDay' in registrationToFirestore(registration()), false);
  });

  it('an entry day round-trips', () => {
    const d = { eventId: 'ev1', day: '2026-10-22', sold: 8, held: 2, checkedIn: 1, closed: false, updatedAt: '2026-10-18T03:00:00.000Z' };
    const doc = entryDayToFirestore(d);
    assert.ok(doc.updatedAt instanceof Timestamp);
    assert.deepEqual(entryDayFromFirestore(doc), d);
    assert.equal(entryDayFromFirestore(undefined), null);
  });

  it('a ticket payment keeps lineKind and payeeKind', () => {
    const p = paymentFromFirestore('p1', paymentToFirestore({
      id: 'p1', subjectType: 'event_registration', subjectId: 'r1', eventId: 'ev1', payerId: 'cu1', payeeId: 'org1',
      provider: 'fake', amount: 70_000, status: 'created', escrowStatus: 'held', idempotencyKey: 'tkt_r1_bank_qr',
      method: 'bank_qr', lineKind: 'entry_ticket', payeeKind: 'organizer', releaseAfter: '2026-10-22T17:00:00.000Z',
      createdAt: '2026-10-18T03:00:00.000Z', updatedAt: '2026-10-18T03:00:00.000Z',
    }));
    assert.deepEqual([p?.lineKind, p?.payeeKind, p?.payeeId, p?.releaseAfter], ['entry_ticket', 'organizer', 'org1', '2026-10-22T17:00:00.000Z']);
  });

  it('entry_days, organizers and residents are read inside the event transaction', async () => {
    const gets: string[] = [];
    const sets: string[] = [];
    const docs: Record<string, DocumentData> = {
      'entry_days/ev1_2026-10-22': { eventId: 'ev1', day: '2026-10-22', sold: 8, held: 0, checkedIn: 0, closed: false, updatedAt: Timestamp.fromDate(D('2026-10-18T03:00:00.000Z')) },
      'organizers/org1': { name: 'Bãi đá', bio: '', status: 'active', phoneVerified: true, businessVerified: true, payoutAccountOk: true, managedSpotIds: ['s1'] },
      'spots/s1/residents/p1': { waivesProvider: true, waivesGuests: false, maxGuests: null, validUntil: null, addedAt: '2026-10-01T00:00:00.000Z', addedBy: 'org1' },
    };
    const ref = (path: string): unknown => ({
      path,
      collection: (c: string) => ({ doc: (id: string) => ref(`${path}/${c}/${id}`) }),
    });
    const firestore = {
      collection: (c: string) => ({ doc: (id: string) => ref(`${c}/${id}`) }),
      runTransaction: async (fn: (fTx: unknown) => Promise<unknown>) => fn({
        get: async (r: { path: string }) => { gets.push(r.path); return { data: () => docs[r.path] }; },
        set: (r: { path: string }) => { sets.push(r.path); },
      }),
    };
    const store = new FirestoreEventStore(firestore as never);
    const out = await store.runTransaction(async (tx) => {
      const day = await tx.getEntryDay('ev1', '2026-10-22');
      const org = await tx.getOrganizer('org1');
      const res = await tx.residentOf('s1', 'p1');
      tx.putEntryDay({ ...(day as NonNullable<typeof day>), held: 2 });
      return { day, org, res };
    });
    assert.deepEqual(gets, ['entry_days/ev1_2026-10-22', 'organizers/org1', 'spots/s1/residents/p1']);
    assert.deepEqual(sets, ['entry_days/ev1_2026-10-22']);
    assert.equal(out.day?.sold, 8);
    assert.equal(out.org?.businessVerified, true);
    assert.equal(out.res?.waivesProvider, true);
  });
});
