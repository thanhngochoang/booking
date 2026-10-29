import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import type { Spot } from '@photobooking/domain';
import {
  FirestoreSpotAdminStore,
  FirestoreSpotCounter,
  FirestoreSpotRankStore,
} from '../../src/infra/spot_rank_firestore.js';
import { spotFromFirestore, spotToFirestore } from '../../src/infra/spot_firestore.js';
import { MemoryFirestore } from './support/memory_firestore.js';

/** A managed spot as stored now (claimed by org_1, manager fields set). */
const managed: Spot = {
  id: 'spot_01', name: 'Bãi đá sông Hồng', city: 'Hà Nội', areaCode: 'hn', point: { lat: 21.05, lng: 105.86 },
  geohash: 'w7er8u0xx', radiusM: 800,
  cover: { url: 'https://example.com/m.jpg', cardUrl: 'https://example.com/mc.jpg', path: 'spots/spot_01/cover.jpg' },
  description: 'Mô tả của chủ điểm', tips: ['Đến sớm'], seasonMonths: [10, 11], pinned: false, hidden: false,
  status: 'active', hotScore: 10,
  stats: { posts14d: 1, events: 0, bookings14d: 0, openSchedules: 0, providersWeek: 0, providersWeekend: 0 },
  createdAt: '2026-10-01T00:00:00.000Z', updatedAt: '2026-10-17T00:00:00.000Z', rankedAt: null, updatedBy: 'org_1',
  managedBy: 'org_1',
  access: { type: 'ticket', fees: [{ label: 'Người lớn', amountVnd: 70_000 }], note: '', updatedAt: '2026-10-17T00:00:00.000Z', source: 'organizer' },
  openHours: { start: '07:00', end: '18:00' },
};
/** The same spot as the ranking job read it earlier (before the claim and the manager's edits). */
const stale: Spot = {
  ...managed, cover: null, description: 'Cũ', tips: [], managedBy: null, access: null, openHours: null,
  updatedAt: '2026-10-01T00:00:00.000Z', updatedBy: 'admin_1',
};

describe('spot_rank_firestore', () => {
  it('schedulesWithDay builds spotId == X, status == open, days array-contains-any [...] with count()', async () => {
    const calls: { field: string; op: string; val: unknown }[] = [];
    const fakeQuery = {
      where: (field: string, op: string, val: unknown) => {
        calls.push({ field, op, val });
        return fakeQuery;
      },
      count: () => ({
        get: async () => ({ data: () => ({ count: 3 }) }),
      }),
    };
    const fakeFirestore = {
      collection: (name: string) => {
        assert.equal(name, 'spot_schedules');
        return fakeQuery;
      },
    };

    const counter = new FirestoreSpotCounter(fakeFirestore as never);
    const count = await counter.schedulesWithDay('spot-1', ['2026-10-10', '2026-10-11']);
    assert.equal(count, 3);
    assert.deepEqual(calls, [
      { field: 'spotId', op: '==', val: 'spot-1' },
      { field: 'status', op: '==', val: 'open' },
      { field: 'days', op: 'array-contains-any', val: ['2026-10-10', '2026-10-11'] },
    ]);
  });

  it('paidBookings uses depositPaidAt >= since', async () => {
    const calls: { field: string; op: string; val: unknown }[] = [];
    const fakeQuery = {
      where: (field: string, op: string, val: unknown) => {
        calls.push({ field, op, val });
        return fakeQuery;
      },
      count: () => ({
        get: async () => ({ data: () => ({ count: 5 }) }),
      }),
    };
    const fakeFirestore = {
      collection: (name: string) => {
        assert.equal(name, 'bookings');
        return fakeQuery;
      },
    };

    const counter = new FirestoreSpotCounter(fakeFirestore as never);
    const sinceIso = '2026-09-24T00:00:00.000Z';
    const count = await counter.paidBookings('spot-1', sinceIso);
    assert.equal(count, 5);
    assert.equal(calls.length, 2);
    assert.deepEqual(calls[0], { field: 'spotId', op: '==', val: 'spot-1' });
    assert.equal(calls[1]?.field, 'depositPaidAt');
    assert.equal(calls[1]?.op, '>=');
    assert.ok(calls[1]?.val instanceof Timestamp);
  });

  it('events uses spotId, status in [open, full], startAt range, and leaves out entry events (type != entry)', async () => {
    const calls: { field: string; op: string; val: unknown }[] = [];
    const fakeQuery = {
      where: (field: string, op: string, val: unknown) => {
        calls.push({ field, op, val });
        return fakeQuery;
      },
      count: () => ({
        get: async () => ({ data: () => ({ count: 2 }) }),
      }),
      // S30: the spot's entry events (one open, in the window) are not counted.
      get: async () => ({
        docs: [
          { data: () => ({ status: 'open', startAt: Timestamp.fromDate(new Date('2026-10-10T00:00:00.000Z')) }) },
          { data: () => ({ status: 'cancelled', startAt: Timestamp.fromDate(new Date('2026-10-10T00:00:00.000Z')) }) },
        ],
      }),
    };
    const fakeFirestore = {
      collection: (name: string) => {
        assert.equal(name, 'events');
        return fakeQuery;
      },
    };

    const counter = new FirestoreSpotCounter(fakeFirestore as never);
    const fromIso = '2026-10-08T00:00:00.000Z';
    const toIso = '2026-11-07T00:00:00.000Z';
    const count = await counter.events('spot-1', fromIso, toIso);
    assert.equal(count, 1);
    assert.equal(calls.length, 6);
    assert.deepEqual(calls.slice(4), [{ field: 'spotId', op: '==', val: 'spot-1' }, { field: 'type', op: '==', val: 'entry' }]);
    assert.deepEqual(calls[0], { field: 'spotId', op: '==', val: 'spot-1' });
    assert.deepEqual(calls[1], { field: 'status', op: 'in', val: ['open', 'full'] });
    assert.equal(calls[2]?.field, 'startAt');
    assert.equal(calls[2]?.op, '>=');
    assert.equal(calls[3]?.field, 'startAt');
    assert.equal(calls[3]?.op, '<=');
  });

  it('saveSpot writes only what the ranking computes: managedBy and the manager fields stay (final fix B-I1)', async () => {
    const db = new MemoryFirestore();
    db.seed('spots/spot_01', spotToFirestore(managed));
    const ranked: Spot = {
      ...stale, stats: { ...stale.stats, posts14d: 9 }, hotScore: 55, rankedAt: '2026-10-18T20:00:00.000Z', updatedAt: '2026-10-18T20:00:00.000Z',
    };
    await new FirestoreSpotRankStore(db.asFirestore()).saveSpot(ranked);
    assert.deepEqual(db.log, [{ path: 'spots/spot_01', kind: 'update' }]);
    const after = spotFromFirestore('spot_01', db.data('spots/spot_01'));
    assert.equal(after?.managedBy, 'org_1');
    assert.deepEqual(after?.access, managed.access);
    assert.deepEqual(after?.openHours, managed.openHours);
    assert.deepEqual(after?.cover, managed.cover);
    assert.equal(after?.description, managed.description);
    assert.deepEqual(after?.tips, managed.tips);
    assert.equal(after?.updatedBy, 'org_1');
    assert.equal(after?.stats.posts14d, 9);
    assert.equal(after?.hotScore, 55);
    assert.equal(after?.rankedAt, '2026-10-18T20:00:00.000Z');
    assert.equal(after?.updatedAt, '2026-10-18T20:00:00.000Z');
  });

  it("the spots CLI's putSpot with fields updates only those; without fields (spots add) it writes the whole spot", async () => {
    const db = new MemoryFirestore();
    db.seed('spots/spot_01', spotToFirestore(managed));
    const admin = new FirestoreSpotAdminStore(db.asFirestore());
    await admin.putSpot({ ...stale, pinned: true, updatedAt: '2026-10-18T09:00:00.000Z', updatedBy: 'admin_2' }, ['pinned', 'updatedAt', 'updatedBy']);
    const after = spotFromFirestore('spot_01', db.data('spots/spot_01'));
    assert.equal(after?.pinned, true);
    assert.equal(after?.updatedBy, 'admin_2');
    assert.equal(after?.managedBy, 'org_1');
    assert.deepEqual(after?.access, managed.access);
    assert.deepEqual(after?.cover, managed.cover);

    await admin.putSpot({ ...managed, id: 'spot_02', managedBy: null, access: null });
    assert.deepEqual(spotFromFirestore('spot_02', db.data('spots/spot_02')), { ...managed, id: 'spot_02', managedBy: null, access: null });
  });

  it('saveRankings deletes the stale keys in the same batch', async () => {
    const setOps: { path: string; data: unknown }[] = [];
    const delOps: string[] = [];
    let committed = false;

    const fakeBatch = {
      set: (ref: { path: string }, data: unknown) => {
        setOps.push({ path: ref.path, data });
      },
      delete: (ref: { path: string }) => {
        delOps.push(ref.path);
      },
      commit: async () => {
        committed = true;
      },
    };

    const fakeFirestore = {
      collection: (name: string) => ({
        doc: (id: string) => ({ path: `${name}/${id}` }),
      }),
      batch: () => fakeBatch,
    };

    const store = new FirestoreSpotRankStore(fakeFirestore as never);
    await store.saveRankings(
      [
        { key: 'all', rankedAt: '2026-10-08T03:00:00.000Z', entries: [] },
        { key: 'hn', rankedAt: '2026-10-08T03:00:00.000Z', entries: [] },
      ],
      ['stale-hue', 'stale-dn'],
    );

    assert.equal(committed, true);
    assert.equal(setOps.length, 2);
    assert.equal(setOps[0]?.path, 'spot_rankings/all');
    assert.equal(setOps[1]?.path, 'spot_rankings/hn');
    assert.deepEqual(delOps, ['spot_rankings/stale-hue', 'spot_rankings/stale-dn']);
  });
});
