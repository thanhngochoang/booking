import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  rankSpots,
  spotDirectory,
  nextDays,
  weekendDays,
  runSpotRanking,
} from '../src/spot_ranking.js';
import type { Spot } from '../src/spot.js';
import { MemorySpotRankStore, MemorySpotCounter } from '../src/memory_spot_rank_store.js';

const makeSpot = (id: string, over: Partial<Spot> = {}): Spot => ({
  id,
  name: `Spot ${id}`,
  city: 'Hà Nội',
  areaCode: 'hn',
  point: { lat: 21.0285, lng: 105.8542 },
  geohash: 'w7e5q8',
  radiusM: 1000,
  cover: { url: `https://test/${id}/cover.jpg`, cardUrl: `https://test/${id}/card.jpg`, path: `spots/${id}/cover.jpg` },
  description: 'Mô tả',
  tips: ['Mẹo 1'],
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
  updatedBy: 'admin',
  ...over,
});

describe('spot_ranking', () => {
  describe('nextDays and weekendDays', () => {
    it('nextDays(today, 30) has 30 VN days starting today', () => {
      const days = nextDays('2026-10-08', 30);
      assert.equal(days.length, 30);
      assert.equal(days[0], '2026-10-08');
      assert.equal(days[1], '2026-10-09');
      assert.equal(days[29], '2026-11-06');
    });

    it('weekendDays on Wednesday → Sat, Sun; on Saturday → today, tomorrow; on Sunday → today', () => {
      // 2026-10-07 is Wednesday (3)
      const wed = weekendDays('2026-10-07');
      assert.deepEqual(wed, ['2026-10-10', '2026-10-11']);

      // 2026-10-10 is Saturday (6)
      const sat = weekendDays('2026-10-10');
      assert.deepEqual(sat, ['2026-10-10', '2026-10-11']);

      // 2026-10-11 is Sunday (0)
      const sun = weekendDays('2026-10-11');
      assert.deepEqual(sun, ['2026-10-11']);
    });
  });

  describe('rankSpots and spotDirectory', () => {
    it('region list: pinned first, then by score, at most 10 hot', () => {
      const spots: Spot[] = [
        makeSpot('s1', { areaCode: 'hn', hotScore: 10 }),
        makeSpot('s2', { areaCode: 'hn', hotScore: 20 }),
        makeSpot('s3', { areaCode: 'hn', pinned: true, hotScore: 5 }),
      ];

      const rankings = rankSpots(spots, 10, '2026-10-08T03:00:00.000Z');
      const hn = rankings.find((r) => r.key === 'hn');
      assert.ok(hn);
      assert.equal(hn.entries.length, 3);
      assert.equal(hn.entries[0]?.spotId, 's3'); // pinned first
      assert.equal(hn.entries[1]?.spotId, 's2'); // hotScore 20
      assert.equal(hn.entries[2]?.spotId, 's1'); // hotScore 10
    });

    it('hidden spots are in no list but in the directory with hidden true', () => {
      const spots: Spot[] = [
        makeSpot('s1', { areaCode: 'hn', hotScore: 10 }),
        makeSpot('s_hidden', { areaCode: 'hn', hotScore: 30, hidden: true }),
      ];

      const rankings = rankSpots(spots, 10, '2026-10-08T03:00:00.000Z');
      const all = rankings.find((r) => r.key === 'all');
      const hn = rankings.find((r) => r.key === 'hn');
      assert.ok(!all?.entries.some((e) => e.spotId === 's_hidden'));
      assert.ok(!hn?.entries.some((e) => e.spotId === 's_hidden'));

      const dir = spotDirectory(spots, 10);
      const hiddenEntry = dir.find((e) => e.spotId === 's_hidden');
      assert.ok(hiddenEntry);
      assert.equal(hiddenEntry.hidden, true);
    });

    it('archived spots are in nothing', () => {
      const spots: Spot[] = [
        makeSpot('s1', { areaCode: 'hn', hotScore: 10 }),
        makeSpot('s_archived', { areaCode: 'hn', hotScore: 30, status: 'archived' }),
      ];

      const rankings = rankSpots(spots, 10, '2026-10-08T03:00:00.000Z');
      const all = rankings.find((r) => r.key === 'all');
      assert.ok(!all?.entries.some((e) => e.spotId === 's_archived'));

      const dir = spotDirectory(spots, 10);
      assert.ok(!dir.some((e) => e.spotId === 's_archived'));
    });

    it('an out-of-season spot with score > 0 is not hot unless pinned', () => {
      const spots: Spot[] = [
        makeSpot('s_in', { areaCode: 'hn', hotScore: 10, seasonMonths: [10, 11] }),
        makeSpot('s_out', { areaCode: 'hn', hotScore: 25, seasonMonths: [5, 6] }),
        makeSpot('s_out_pinned', { areaCode: 'hn', hotScore: 20, seasonMonths: [5, 6], pinned: true }),
      ];

      const rankings = rankSpots(spots, 10, '2026-10-08T03:00:00.000Z');
      const hn = rankings.find((r) => r.key === 'hn');
      assert.ok(hn);
      // s_out is out of season in month 10, not pinned -> not hot, excluded
      assert.ok(!hn.entries.some((e) => e.spotId === 's_out'));
      // s_out_pinned is pinned -> included first
      assert.equal(hn.entries[0]?.spotId, 's_out_pinned');
      // s_in is in season -> included
      assert.equal(hn.entries[1]?.spotId, 's_in');
    });

    it('a region with 3 hot spots is filled from the national list up to 10, without duplicates', () => {
      const spots: Spot[] = [
        // 3 in da-lat
        makeSpot('dl1', { areaCode: 'da-lat', hotScore: 5 }),
        makeSpot('dl2', { areaCode: 'da-lat', hotScore: 6 }),
        makeSpot('dl3', { areaCode: 'da-lat', hotScore: 7 }),
        // 8 in hn
        ...Array.from({ length: 8 }, (_, i) =>
          makeSpot(`hn${i + 1}`, { areaCode: 'hn', hotScore: 20 + i }),
        ),
      ];

      const rankings = rankSpots(spots, 10, '2026-10-08T03:00:00.000Z');
      const dl = rankings.find((r) => r.key === 'da-lat');
      assert.ok(dl);
      assert.equal(dl.entries.length, 10); // 3 own + 7 filled from national
      const dlEntries = dl.entries.map((e) => e.spotId);
      // Own 3 first (sorted by hotScore desc: dl3, dl2, dl1)
      assert.deepEqual(dlEntries.slice(0, 3), ['dl3', 'dl2', 'dl1']);
      // Next 7 are filled from national (which are hn spots with highest scores)
      assert.equal(dlEntries.slice(3).length, 7);
      // No duplicate ids
      assert.equal(new Set(dlEntries).size, 10);
    });

    it('all = every pinned spot then the national top 10, ≤ 20', () => {
      const spots: Spot[] = [
        ...Array.from({ length: 15 }, (_, i) =>
          makeSpot(`hot${i + 1}`, { areaCode: 'hn', hotScore: i + 1 }),
        ),
        makeSpot('pinned1', { areaCode: 'hcm', pinned: true }),
        makeSpot('pinned2', { areaCode: 'dn', pinned: true }),
      ];

      const rankings = rankSpots(spots, 10, '2026-10-08T03:00:00.000Z');
      const all = rankings.find((r) => r.key === 'all');
      assert.ok(all);
      // 2 pinned + top 10 hot = 12 entries
      assert.equal(all.entries.length, 12);
      assert.equal(all.entries[0]?.spotId, 'pinned1');
      assert.equal(all.entries[1]?.spotId, 'pinned2');
      // Top hot spots: hot15 down to hot6
      assert.equal(all.entries[2]?.spotId, 'hot15');
      assert.equal(all.entries[11]?.spotId, 'hot6');
    });

    it('entries carry name, city, cardUrl, lat, lng, inSeason, providersWeek, pinned', () => {
      const spot = makeSpot('s1', {
        name: 'Hồ Tây',
        city: 'Hà Nội',
        areaCode: 'hn',
        point: { lat: 21.05, lng: 105.82 },
        cover: { url: 'https://test/u.jpg', cardUrl: 'https://test/card.jpg', path: 'spots/s1/cover.jpg' },
        seasonMonths: [10, 11],
        pinned: true,
        stats: {
          posts14d: 0,
          events: 0,
          bookings14d: 0,
          openSchedules: 0,
          providersWeek: 4,
          providersWeekend: 2,
        },
      });

      const rankings = rankSpots([spot], 10, '2026-10-08T03:00:00.000Z');
      const all = rankings[0];
      assert.ok(all);
      const entry = all.entries[0];
      assert.ok(entry);
      assert.equal(entry.spotId, 's1');
      assert.equal(entry.name, 'Hồ Tây');
      assert.equal(entry.city, 'Hà Nội');
      assert.equal(entry.areaCode, 'hn');
      assert.equal(entry.cardUrl, 'https://test/card.jpg');
      assert.equal(entry.lat, 21.05);
      assert.equal(entry.lng, 105.82);
      assert.deepEqual(entry.seasonMonths, [10, 11]);
      assert.equal(entry.inSeason, true);
      assert.equal(entry.providersWeek, 4);
      assert.equal(entry.pinned, true);
    });
  });

  describe('runSpotRanking', () => {
    it('counts posts 14 d, events 30 d, paid bookings 14 d, schedules 30 d/7 d/weekend for each active spot and saves only changed spots', async () => {
      const store = new MemorySpotRankStore();
      const counter = new MemorySpotCounter();

      const s1 = makeSpot('s1', { areaCode: 'hn', hotScore: 0 });
      const s2 = makeSpot('s2', { areaCode: 'hcm', hotScore: 11, stats: {
        posts14d: 2, events: 1, bookings14d: 1, openSchedules: 2, providersWeek: 1, providersWeekend: 1,
      } });
      const s3Archived = makeSpot('s3', { status: 'archived' });

      store.seedSpot(s1);
      store.seedSpot(s2);
      store.seedSpot(s3Archived);

      // Setup counts for s1: posts=2, events=1, bookings=1, openSchedules=2 -> score 11
      counter.setCounts('s1', {
        posts: 2,
        events: 1,
        paidBookings: 1,
        schedulesNext30: 2,
        schedulesNext7: 1,
        schedulesWeekend: 1,
      });
      // Setup counts for s2: same as its existing stats -> no change
      counter.setCounts('s2', {
        posts: 2,
        events: 1,
        paidBookings: 1,
        schedulesNext30: 2,
        schedulesNext7: 1,
        schedulesWeekend: 1,
      });

      const clock = { now: () => new Date('2026-10-08T03:00:00.000Z') };
      const res = await runSpotRanking({ store, counter, clock });

      assert.equal(res.spots, 2); // 2 active spots
      assert.equal(res.changed, 1); // s1 changed, s2 did not
      const updatedS1 = await store.getSpot('s1');
      assert.equal(updatedS1?.hotScore, 11);
      assert.equal(updatedS1?.stats.posts14d, 2);
    });

    it('runSpotRanking writes rankings and the directory and lists stale region keys to delete', async () => {
      const store = new MemorySpotRankStore();
      const counter = new MemorySpotCounter();

      // Seed an old ranking key that is now stale (e.g. 'hue')
      store.seedRankingKey('hue');
      store.seedRankingKey('hn');

      const s1 = makeSpot('s1', { areaCode: 'hn', hotScore: 10 });
      store.seedSpot(s1);

      const clock = { now: () => new Date('2026-10-08T03:00:00.000Z') };
      const res = await runSpotRanking({ store, counter, clock });

      assert.ok(res.keys.includes('all'));
      assert.ok(res.keys.includes('hn'));
      assert.ok(!res.keys.includes('hue'));

      // Check stored rankings
      const rankings = store.getRankings();
      assert.ok(rankings.some((r) => r.key === 'all'));
      assert.ok(rankings.some((r) => r.key === 'hn'));
      // Stale key 'hue' was deleted
      assert.ok(!rankings.some((r) => r.key === 'hue'));

      // Check stored directory
      const directory = store.getDirectory();
      assert.equal(directory.length, 1);
      assert.equal(directory[0]?.spotId, 's1');
    });
  });
});
