import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { handleRankSpots } from '../../src/scheduled/rank_spots.js';
import { MemorySpotRankStore, MemorySpotCounter } from '@photobooking/domain';

describe('rank_spots scheduled job', () => {
  it('the job runs runSpotRanking with the live deps once and logs the counts', async () => {
    const store = new MemorySpotRankStore();
    const counter = new MemorySpotCounter();
    const clock = { now: () => new Date('2026-10-08T03:00:00.000Z') };

    store.seedSpot({
      id: 'spot-1',
      name: 'Hồ Tây',
      city: 'Hà Nội',
      areaCode: 'hn',
      point: { lat: 21.05, lng: 105.82 },
      geohash: 'w7e5q8',
      radiusM: 1000,
      cover: null,
      description: 'Hồ Tây',
      tips: [],
      seasonMonths: [],
      pinned: false,
      hidden: false,
      status: 'active',
      hotScore: 0,
      stats: {
        posts14d: 0,
        events: 0,
        bookings14d: 0,
        openSchedules: 0,
        providersWeek: 0,
        providersWeekend: 0,
      },
      createdAt: '2026-10-01T00:00:00.000Z',
      updatedAt: '2026-10-01T00:00:00.000Z',
      rankedAt: null,
      managedBy: null,
      access: null,
      openHours: null,
      updatedBy: 'admin',
    });

    counter.setCounts('spot-1', {
      posts: 5,
      events: 2,
      paidBookings: 3,
      schedulesNext30: 1,
      schedulesNext7: 1,
      schedulesWeekend: 1,
    });

    const res = await handleRankSpots({
      store: store as never,
      counter: counter as never,
      clock,
    });

    assert.equal(res.spots, 1);
    assert.equal(res.changed, 1);
    assert.deepEqual(res.keys.sort(), ['all', 'hn']);

    const updated = await store.getSpot('spot-1');
    assert.equal(updated?.stats.posts14d, 5);
    // 5*1 + 2*3 + 3*2 + 1*2 = 5 + 6 + 6 + 2 = 19
    assert.equal(updated?.hotScore, 19);
  });
});
