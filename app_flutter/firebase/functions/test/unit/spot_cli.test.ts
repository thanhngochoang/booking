import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { beforeEach, describe, it } from 'node:test';
import {
  parseArgs,
  guardEnv,
  runCli,
  type SpotCliIo,
  type SpotCliDeps,
} from '../../tools/spots.js';
import { MemorySpotRankStore, MemorySpotCounter, type Spot } from '@photobooking/domain';

const makeSpot = (id: string, over: Partial<Spot> = {}): Spot => ({
  id,
  name: `Spot ${id}`,
  city: 'Hà Nội',
  areaCode: 'hn',
  point: { lat: 21.0285, lng: 105.8542 },
  geohash: 'w7e5q8',
  radiusM: 1000,
  cover: null,
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

describe('spot_cli', () => {
  let store: MemorySpotRankStore;
  let counter: MemorySpotCounter;
  let out: string[];
  let admin = true;

  const io: SpotCliIo = {
    print: (s: string) => void out.push(s),
    now: () => new Date('2026-10-08T03:00:00.000Z'),
    isAdmin: async () => admin,
    uploadCover: async (spotId: string) => ({
      url: 'https://test/cover.jpg',
      cardUrl: 'https://test/card.jpg',
      path: `spots/${spotId}/cover.jpg`,
    }),
  };

  const deps = (): SpotCliDeps => ({
    spots: store,
    counter,
    clock: { now: () => new Date('2026-10-08T03:00:00.000Z') },
    ids: { newId: () => 'new-spot-1' },
    staff: { isAdmin: async () => admin },
  });

  beforeEach(() => {
    store = new MemorySpotRankStore();
    counter = new MemorySpotCounter();
    out = [];
    admin = true;
  });

  it('parseArgs parses commands and flags', () => {
    const listArgs = parseArgs(['list', '--area', 'hn']);
    assert.equal(listArgs.command, 'list');
    assert.equal(listArgs.area, 'hn');

    const addArgs = parseArgs([
      'add',
      '--name', 'Hồ Tây',
      '--city', 'Hà Nội',
      '--area', 'hn',
      '--lat', '21.05',
      '--lng', '105.82',
      '--radius', '1500',
      '--season', '10,11,12',
      '--description', 'Hồ đẹp',
      '--tip', 'Mẹo 1',
      '--tip', 'Mẹo 2',
      '--actor', 'admin-uid',
    ]);
    assert.equal(addArgs.command, 'add');
    assert.equal(addArgs.name, 'Hồ Tây');
    assert.equal(addArgs.city, 'Hà Nội');
    assert.equal(addArgs.area, 'hn');
    assert.equal(addArgs.lat, 21.05);
    assert.equal(addArgs.lng, 105.82);
    assert.equal(addArgs.radiusM, 1500);
    assert.deepEqual(addArgs.seasonMonths, [10, 11, 12]);
    assert.equal(addArgs.description, 'Hồ đẹp');
    assert.deepEqual(addArgs.tips, ['Mẹo 1', 'Mẹo 2']);
    assert.equal(addArgs.actor, 'admin-uid');
  });

  it('a half-set emulator environment is refused', () => {
    assert.throws(
      () => guardEnv({ FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080' }),
      /FIREBASE_AUTH_EMULATOR_HOST/i,
    );
  });

  it('add without --actor is refused', async () => {
    await assert.rejects(
      () =>
        runCli(
          [
            'add',
            '--name', 'Hồ Tây',
            '--city', 'Hà Nội',
            '--area', 'hn',
            '--lat', '21.05',
            '--lng', '105.82',
            '--radius', '1500',
          ],
          deps(),
          io,
        ),
      /--actor/i,
    );
  });

  it('add stores spot, uploads cover if given, and rewrites rankings and directory', async () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'spot-cli-test-'));
    const coverPath = path.join(tmpDir, 'cover.jpg');
    const cardPath = path.join(tmpDir, 'card.jpg');
    const fakeJpeg = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
    fs.writeFileSync(coverPath, fakeJpeg);
    fs.writeFileSync(cardPath, fakeJpeg);

    try {
      await runCli(
        [
          'add',
          '--name', 'Hồ Tây',
          '--city', 'Hà Nội',
          '--area', 'hn',
          '--lat', '21.05',
          '--lng', '105.82',
          '--radius', '1500',
          '--season', '10,11,12',
          '--cover', coverPath,
          '--card', cardPath,
          '--actor', 'admin1',
        ],
        deps(),
        io,
      );

      const spot = await store.getSpot('new-spot-1');
      assert.ok(spot);
      assert.equal(spot.name, 'Hồ Tây');
      assert.equal(spot.cover?.url, 'https://test/cover.jpg');

      // Rankings and directory are updated
      const rankings = store.getRankings();
      assert.ok(rankings.some((r) => r.key === 'all'));
      assert.ok(rankings.some((r) => r.key === 'hn'));
      const dir = store.getDirectory();
      assert.equal(dir.length, 1);
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  it('pin rewrites spot_rankings and spot_directory from stored scores without counting', async () => {
    store.seedSpot(makeSpot('spot-1', { hotScore: 50, pinned: false }));

    await runCli(['pin', 'spot-1', '--actor', 'admin1'], deps(), io);

    const spot = await store.getSpot('spot-1');
    assert.equal(spot?.pinned, true);

    const rankings = store.getRankings();
    const all = rankings.find((r) => r.key === 'all');
    assert.ok(all?.entries.some((e) => e.spotId === 'spot-1' && e.pinned));
  });

  it('rank runs runSpotRanking', async () => {
    store.seedSpot(makeSpot('spot-1', { hotScore: 0 }));
    counter.setCounts('spot-1', { posts: 4, events: 1, paidBookings: 2, schedulesNext30: 1, schedulesNext7: 1, schedulesWeekend: 1 });

    await runCli(['rank'], deps(), io);

    const spot = await store.getSpot('spot-1');
    // 4*1 + 1*3 + 2*2 + 1*2 = 13
    assert.equal(spot?.hotScore, 13);
    assert.ok(out.some((l) => l.includes('rankSpots completed') || l.includes('spots: 1')));
  });

  it('list prints id, name, area, status, flags, hotScore', async () => {
    store.seedSpot(makeSpot('s1', { name: 'Đồi chè Cầu Đất', areaCode: 'da-lat', hotScore: 25, pinned: true }));
    store.seedSpot(makeSpot('s2', { name: 'Hồ Tây', areaCode: 'hn', hotScore: 10, hidden: true }));

    await runCli(['list'], deps(), io);

    assert.equal(out.length, 2);
    assert.ok(out[0]?.includes('s1') && out[0]?.includes('Đồi chè Cầu Đất') && out[0]?.includes('pinned'));
    assert.ok(out[1]?.includes('s2') && out[1]?.includes('Hồ Tây') && out[1]?.includes('hidden'));
  });
});
