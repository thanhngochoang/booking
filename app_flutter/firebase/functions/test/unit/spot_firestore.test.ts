import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { GeoPoint, Timestamp } from 'firebase-admin/firestore';
import type { Spot, SpotSchedule, SlotOffer, SpotDay } from '@photobooking/domain';
import {
  spotToFirestore,
  spotFromFirestore,
  scheduleToFirestore,
  scheduleFromFirestore,
  offerToFirestore,
  offerFromFirestore,
  spotDayToFirestore,
  spotDayFromFirestore,
  FirestoreSpotScheduleStore,
} from '../../src/infra/spot_firestore.js';

describe('spot_firestore mappers', () => {
  const sampleSpot: Spot = {
    id: 'spot_01',
    name: 'Hồ Gươm',
    city: 'Hà Nội',
    areaCode: 'hn-hoan-kiem',
    point: { lat: 21.0285, lng: 105.8542 },
    geohash: 'w7er8u0xx',
    radiusM: 800,
    cover: {
      url: 'https://example.com/cover.jpg',
      cardUrl: 'https://example.com/card.jpg',
      path: 'spots/spot_01/cover.jpg',
    },
    description: 'Trái tim của thủ đô',
    tips: ['Chụp sáng sớm từ 05:30', 'Tránh trưa nắng'],
    seasonMonths: [10, 11, 12, 1],
    pinned: true,
    hidden: false,
    status: 'active',
    hotScore: 42,
    stats: {
      posts14d: 15,
      events: 2,
      bookings14d: 8,
      openSchedules: 3,
      providersWeek: 4,
      providersWeekend: 6,
    },
    createdAt: '2026-10-01T00:00:00.000Z',
    updatedAt: '2026-10-02T12:00:00.000Z',
    rankedAt: '2026-10-02T12:00:00.000Z',
    updatedBy: 'admin_1',
  };

  it('spot round-trips with cover set, GeoPoint, Timestamps, and stats', () => {
    const docData = spotToFirestore(sampleSpot);
    assert.ok(docData.point instanceof GeoPoint);
    assert.equal(docData.point.latitude, sampleSpot.point.lat);
    assert.equal(docData.point.longitude, sampleSpot.point.lng);
    assert.ok(docData.createdAt instanceof Timestamp);
    assert.ok(docData.updatedAt instanceof Timestamp);
    assert.ok(docData.rankedAt instanceof Timestamp);
    assert.deepEqual(docData.cover, sampleSpot.cover);
    assert.deepEqual(docData.stats, sampleSpot.stats);

    const restored = spotFromFirestore('spot_01', docData);
    assert.ok(restored);
    assert.deepEqual(restored, sampleSpot);
  });

  it('spot round-trips with cover null', () => {
    const spotNoCover: Spot = { ...sampleSpot, cover: null };
    const docData = spotToFirestore(spotNoCover);
    assert.equal(docData.cover, null);

    const restored = spotFromFirestore('spot_01', docData);
    assert.ok(restored);
    assert.equal(restored.cover, null);
  });

  it('schedule round-trips (assigneeId null and set, priceFrom null)', () => {
    const scheduleWithAssignee: SpotSchedule = {
      id: 'sched_01',
      providerId: 'studio_01',
      assigneeId: 'photog_member',
      spotId: 'spot_01',
      days: ['2026-10-18', '2026-10-25'],
      window: { start: '06:00', end: '11:00' },
      serviceIds: ['svc_portrait', 'svc_couple'],
      priceFrom: 500_000,
      status: 'open',
      createdAt: '2026-10-01T00:00:00.000Z',
      updatedAt: '2026-10-01T00:00:00.000Z',
    };
    const d1 = scheduleToFirestore(scheduleWithAssignee);
    assert.equal(d1.assigneeId, 'photog_member');
    assert.ok(d1.createdAt instanceof Timestamp);
    const r1 = scheduleFromFirestore('sched_01', d1);
    assert.ok(r1);
    assert.deepEqual(r1, scheduleWithAssignee);

    const scheduleWithoutAssignee: SpotSchedule = {
      ...scheduleWithAssignee,
      assigneeId: null,
      priceFrom: null,
      status: 'cancelled',
    };
    const d2 = scheduleToFirestore(scheduleWithoutAssignee);
    assert.equal(d2.assigneeId, null);
    assert.equal(d2.priceFrom, null);
    const r2 = scheduleFromFirestore('sched_01', d2);
    assert.ok(r2);
    assert.deepEqual(r2, scheduleWithoutAssignee);
  });

  it('offer round-trips', () => {
    const offer: SlotOffer = {
      id: 'off_01',
      providerId: 'photog_01',
      scheduleId: 'sched_01',
      spotId: 'spot_01',
      name: 'Bình minh Hồ Tây 30 phút',
      price: 490_000,
      slotMinutes: 30,
      gapMinutes: 10,
      photoCount: 30,
      editedCount: 5,
      deliveryDays: 3,
      status: 'open',
      createdAt: '2026-10-01T00:00:00.000Z',
      updatedAt: '2026-10-01T00:00:00.000Z',
    };
    const docData = offerToFirestore(offer);
    assert.ok(docData.createdAt instanceof Timestamp);
    assert.equal(docData.price, 490_000);
    const restored = offerFromFirestore('off_01', docData);
    assert.ok(restored);
    assert.deepEqual(restored, offer);
  });

  it('spotDayToFirestore writes only scheduleId, spotId, providerId, day, taken, updatedAt', () => {
    const spotDay: SpotDay = {
      scheduleId: 'sched_01',
      spotId: 'spot_01',
      providerId: 'photog_01',
      day: '2026-10-18',
      taken: [
        { start: '06:00', end: '06:30', offerId: 'off_01' },
        { start: '06:40', end: '07:10', offerId: 'off_01' },
        { start: '08:00', end: '10:00' },
      ],
      updatedAt: '2026-10-01T00:00:00.000Z',
    };
    const docData = spotDayToFirestore(spotDay);
    const keys = Object.keys(docData).sort();
    assert.deepEqual(keys, ['day', 'providerId', 'scheduleId', 'spotId', 'taken', 'updatedAt'].sort());

    for (const item of docData.taken) {
      assert.ok(!('bookingId' in item));
      assert.ok(!('customerId' in item));
    }

    const restored = spotDayFromFirestore(docData);
    assert.ok(restored);
    assert.deepEqual(restored, spotDay);
  });

  it('a document with an unknown status maps to null', () => {
    assert.equal(
      spotFromFirestore('s1', {
        status: 'unknown_status',
        point: new GeoPoint(21, 105),
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      }),
      null,
    );

    assert.equal(
      scheduleFromFirestore('sc1', {
        status: 'draft',
        window: { start: '06:00', end: '11:00' },
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      }),
      null,
    );

    assert.equal(
      offerFromFirestore('o1', {
        status: 'archived',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      }),
      null,
    );
  });

  it('FirestoreSpotScheduleStore reads private/spot_schedules before any write in transactions', async () => {
    const ops: string[] = [];
    const fTx = {
      get: async (ref: { path: string }) => {
        ops.push(`get:${ref.path}`);
        return {
          exists: true,
          data: () => ({ updatedAt: Timestamp.now() }),
        };
      },
      set: (ref: { path: string }) => {
        ops.push(`set:${ref.path}`);
      },
      delete: (ref: { path: string }) => {
        ops.push(`delete:${ref.path}`);
      },
    };
    const firestore = {
      runTransaction: async (fn: (tx: unknown) => Promise<unknown>) => fn(fTx),
      doc: (path: string) => ({ path }),
      collection: (name: string) => ({
        doc: (id: string) => ({ path: `${name}/${id}` }),
        where: () => ({
          where: () => ({
            get: async () => ({ docs: [] }),
          }),
          get: async () => ({ docs: [] }),
        }),
      }),
    };

    const store = new FirestoreSpotScheduleStore(firestore as never);
    await store.runTransaction(async (tx) => {
      await tx.lockProvider('ph1');
      tx.touchLock('ph1', '2026-10-01T00:00:00.000Z');
    });

    assert.deepEqual(ops, [
      'get:photographers/ph1/private/spot_schedules',
      'set:photographers/ph1/private/spot_schedules',
    ]);
  });
});
