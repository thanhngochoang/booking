import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import {
  FirestoreSpotCounter,
  FirestoreSpotRankStore,
} from '../../src/infra/spot_rank_firestore.js';

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

  it('events uses spotId, status in [open, full], startAt range', async () => {
    const calls: { field: string; op: string; val: unknown }[] = [];
    const fakeQuery = {
      where: (field: string, op: string, val: unknown) => {
        calls.push({ field, op, val });
        return fakeQuery;
      },
      count: () => ({
        get: async () => ({ data: () => ({ count: 2 }) }),
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
    assert.equal(count, 2);
    assert.equal(calls.length, 4);
    assert.deepEqual(calls[0], { field: 'spotId', op: '==', val: 'spot-1' });
    assert.deepEqual(calls[1], { field: 'status', op: 'in', val: ['open', 'full'] });
    assert.equal(calls[2]?.field, 'startAt');
    assert.equal(calls[2]?.op, '>=');
    assert.equal(calls[3]?.field, 'startAt');
    assert.equal(calls[3]?.op, '<=');
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
