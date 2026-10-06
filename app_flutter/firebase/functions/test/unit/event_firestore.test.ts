import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import type { EventRecord, RegistrationDoc } from '@photobooking/domain';
import {
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
  status: 'draft',
  registeredCount: 0,
  heldCount: 0,
  chatId: null,
  postCount: 0,
  version: 1,
  publishedAt: null,
  completedAt: null,
  cancelledAt: null,
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

  it('a registration snapshot round-trips and carries no phone', () => {
    const r = registration({ contactEligible: true, amount: 120000, checkedInAt: D('2026-10-12T02:10:00.000Z') });
    const doc = registrationToFirestore(r);
    assert.ok(doc.event.startAt instanceof Timestamp);
    assert.equal('phone' in doc, false);
    assert.deepEqual(registrationFromFirestore('r1', doc), r);
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
});
