import assert from 'node:assert/strict';
import { describe, it, beforeEach } from 'node:test';
import {
  addSpot,
  editSpot,
  setSpotFlag,
  validateSpotInput,
  type SpotAdminDeps,
} from '../src/spot_admin.js';
import { DomainError } from '../src/errors.js';
import { MemorySpotRankStore } from '../src/memory_spot_rank_store.js';

describe('spot_admin', () => {
  let store: MemorySpotRankStore;
  let admin = true;
  let nextId = 'spot-id-1';

  const deps: SpotAdminDeps = {
    spots: {
      getSpot: (id) => store.getSpot(id),
      putSpot: (s) => store.saveSpot(s),
    },
    staff: {
      isAdmin: async () => admin,
    },
    clock: {
      now: () => new Date('2026-10-08T10:00:00.000Z'),
    },
    ids: {
      newId: () => nextId,
    },
  };

  beforeEach(() => {
    store = new MemorySpotRankStore();
    admin = true;
    nextId = 'spot-id-1';
  });

  describe('validateSpotInput', () => {
    const valid = {
      name: 'Đồi chè Cầu Đất',
      city: 'Đà Lạt',
      areaCode: 'da-lat',
      lat: 11.9012,
      lng: 108.5123,
      radiusM: 1500,
      description: 'Đồi chè xanh mướt ngút ngàn.',
      tips: ['Đi sáng sớm săn mây', 'Mang áo khoác mỏng'],
      seasonMonths: [10, 11, 12],
    };

    it('accepts valid input', () => {
      const input = validateSpotInput(valid);
      assert.equal(input.name, 'Đồi chè Cầu Đất');
      assert.equal(input.areaCode, 'da-lat');
      assert.equal(input.radiusM, 1500);
      assert.deepEqual(input.seasonMonths, [10, 11, 12]);
    });

    it('validates name 3–60 chars', () => {
      assert.throws(() => validateSpotInput({ ...valid, name: 'Ab' }), (e: DomainError) => e.code === 'invalid_argument' && e.field === 'name');
      assert.throws(() => validateSpotInput({ ...valid, name: 'A'.repeat(61) }), (e: DomainError) => e.code === 'invalid_argument' && e.field === 'name');
    });

    it('validates area code from SPOT_AREAS', () => {
      assert.throws(() => validateSpotInput({ ...valid, areaCode: 'unknown-area' }), (e: DomainError) => e.code === 'invalid_argument' && e.field === 'areaCode');
    });

    it('validates radius 100–3000 m', () => {
      assert.throws(() => validateSpotInput({ ...valid, radiusM: 99 }), (e: DomainError) => e.code === 'invalid_argument' && e.field === 'radiusM');
      assert.throws(() => validateSpotInput({ ...valid, radiusM: 3001 }), (e: DomainError) => e.code === 'invalid_argument' && e.field === 'radiusM');
    });

    it('validates season months 1–12', () => {
      assert.throws(() => validateSpotInput({ ...valid, seasonMonths: [0, 1] }), (e: DomainError) => e.code === 'invalid_argument' && e.field === 'seasonMonths');
      assert.throws(() => validateSpotInput({ ...valid, seasonMonths: [12, 13] }), (e: DomainError) => e.code === 'invalid_argument' && e.field === 'seasonMonths');
    });

    it('validates ≤ 5 tips of ≤ 120 chars', () => {
      assert.throws(() => validateSpotInput({ ...valid, tips: ['1', '2', '3', '4', '5', '6'] }), (e: DomainError) => e.code === 'invalid_argument' && e.field === 'tips');
      assert.throws(() => validateSpotInput({ ...valid, tips: ['T'.repeat(121)] }), (e: DomainError) => e.code === 'invalid_argument' && e.field === 'tips');
    });

    it('validates description ≤ 600 chars', () => {
      assert.throws(() => validateSpotInput({ ...valid, description: 'D'.repeat(601) }), (e: DomainError) => e.code === 'invalid_argument' && e.field === 'description');
    });
  });

  describe('addSpot and permission check', () => {
    const raw = {
      name: 'Hồ Tây',
      city: 'Hà Nội',
      areaCode: 'hn',
      lat: 21.055,
      lng: 105.823,
      radiusM: 2000,
      description: 'Hồ nước tự nhiên lớn nhất Hà Nội',
      tips: ['Đi vào lúc hoàng hôn', 'Đạp vịt ngắm cảnh'],
      seasonMonths: [],
    };

    it('a non-admin actor is permission_denied', async () => {
      admin = false;
      await assert.rejects(
        () => addSpot(deps, 'user1', raw),
        (e: DomainError) => e.code === 'permission_denied',
      );
    });

    it('adds spot with empty stats and hotScore 0', async () => {
      const spot = await addSpot(deps, 'admin1', raw);
      assert.equal(spot.id, 'spot-id-1');
      assert.equal(spot.name, 'Hồ Tây');
      assert.equal(spot.status, 'active');
      assert.equal(spot.pinned, false);
      assert.equal(spot.hidden, false);
      assert.equal(spot.hotScore, 0);
      assert.equal(spot.updatedBy, 'admin1');
      assert.equal(spot.stats.posts14d, 0);

      const saved = await store.getSpot('spot-id-1');
      assert.deepEqual(saved, spot);
    });
  });

  describe('editSpot', () => {
    it('editSpot keeps stats and hotScore', async () => {
      const spot = await addSpot(deps, 'admin1', {
        name: 'Hồ Tây',
        city: 'Hà Nội',
        areaCode: 'hn',
        lat: 21.055,
        lng: 105.823,
        radiusM: 2000,
        description: 'Hồ nước tự nhiên lớn nhất Hà Nội',
        tips: [],
        seasonMonths: [],
      });

      // Update spot stats directly in store (as if ranking job ran)
      await store.saveSpot({
        ...spot,
        hotScore: 42,
        stats: {
          posts14d: 10,
          events: 5,
          bookings14d: 8,
          openSchedules: 4,
          providersWeek: 3,
          providersWeekend: 2,
        },
      });

      const updated = await editSpot(deps, 'admin2', spot.id, {
        name: 'Hồ Tây Mùa Sen',
        city: 'Hà Nội',
        areaCode: 'hn',
        lat: 21.055,
        lng: 105.823,
        radiusM: 2500,
        description: 'Mùa sen nở rộ vào mùa hạ',
        tips: ['Chụp sen sáng sớm'],
        seasonMonths: [5, 6, 7],
      });

      assert.equal(updated.name, 'Hồ Tây Mùa Sen');
      assert.equal(updated.radiusM, 2500);
      assert.equal(updated.hotScore, 42); // kept
      assert.equal(updated.stats.posts14d, 10); // kept
      assert.equal(updated.updatedBy, 'admin2');
    });

    it('editing unknown spot throws not_found', async () => {
      await assert.rejects(
        () => editSpot(deps, 'admin1', 'nonexistent', {
          name: 'Hồ Tây',
          city: 'Hà Nội',
          areaCode: 'hn',
          lat: 21.055,
          lng: 105.823,
          radiusM: 2000,
          description: 'Desc',
          tips: [],
          seasonMonths: [],
        }),
        (e: DomainError) => e.code === 'not_found',
      );
    });
  });

  describe('setSpotFlag', () => {
    it('pin/unpin/hide/unhide/archive set the flags and updatedBy', async () => {
      const spot = await addSpot(deps, 'admin1', {
        name: 'Hồ Tây',
        city: 'Hà Nội',
        areaCode: 'hn',
        lat: 21.055,
        lng: 105.823,
        radiusM: 2000,
        description: 'Desc',
        tips: [],
        seasonMonths: [],
      });

      let curr = await setSpotFlag(deps, 'admin2', spot.id, 'pin');
      assert.equal(curr.pinned, true);
      assert.equal(curr.updatedBy, 'admin2');

      curr = await setSpotFlag(deps, 'admin3', spot.id, 'unpin');
      assert.equal(curr.pinned, false);

      curr = await setSpotFlag(deps, 'admin4', spot.id, 'hide');
      assert.equal(curr.hidden, true);

      curr = await setSpotFlag(deps, 'admin5', spot.id, 'ununhide' as unknown as 'pin').catch(() => null) ?? curr;
      curr = await setSpotFlag(deps, 'admin5', spot.id, 'unhide');
      assert.equal(curr.hidden, false);

      curr = await setSpotFlag(deps, 'admin6', spot.id, 'archive');
      assert.equal(curr.status, 'archived');
      assert.equal(curr.updatedBy, 'admin6');
    });

    it('archive is final for the CLI (unarchive is not a command / refused)', async () => {
      const spot = await addSpot(deps, 'admin1', {
        name: 'Hồ Tây',
        city: 'Hà Nội',
        areaCode: 'hn',
        lat: 21.055,
        lng: 105.823,
        radiusM: 2000,
        description: 'Desc',
        tips: [],
        seasonMonths: [],
      });

      await setSpotFlag(deps, 'admin2', spot.id, 'archive');

      // Attempting to unarchive (or modifying archived spot flag) throws invalid_argument
      await assert.rejects(
        () => setSpotFlag(deps, 'admin3', spot.id, 'unarchive' as unknown as 'pin'),
        (e: DomainError) => e.code === 'invalid_argument',
      );
    });
  });

  describe('field-scoped writes (final fix B-I1)', () => {
    it('editSpot and setSpotFlag name only their own fields; addSpot writes the whole spot', async () => {
      const calls: (readonly string[] | undefined)[] = [];
      const spied: SpotAdminDeps = {
        ...deps,
        spots: {
          getSpot: (id) => store.getSpot(id),
          putSpot: async (s, fields) => {
            calls.push(fields);
            await store.putSpot(s, fields);
          },
        },
      };
      const input = {
        name: 'Hồ Tây', city: 'Hà Nội', areaCode: 'hn', lat: 21.055, lng: 105.823, radiusM: 2000, description: 'D', tips: [], seasonMonths: [],
      };
      const spot = await addSpot(spied, 'admin1', input);
      // Meanwhile the spot is claimed and its manager sets access (another writer).
      const claimed = { ...spot, managedBy: 'org1', access: { type: 'ticket' as const, fees: [], note: '', updatedAt: spot.updatedAt, source: 'organizer' as const } };
      await store.putSpot(claimed);
      await editSpot(spied, 'admin2', spot.id, { ...input, name: 'Hồ Tây Mùa Sen' });
      await setSpotFlag(spied, 'admin3', spot.id, 'pin');
      assert.equal(calls[0], undefined);
      assert.ok(calls[1]?.includes('name') && !calls[1].includes('managedBy') && !calls[1].includes('access') && !calls[1].includes('stats'));
      assert.deepEqual(calls[2], ['pinned', 'hidden', 'status', 'updatedAt', 'updatedBy']);
      const after = await store.getSpot(spot.id);
      assert.equal(after?.managedBy, 'org1');
      assert.equal(after?.access?.type, 'ticket');
      assert.equal(after?.name, 'Hồ Tây Mùa Sen');
      assert.equal(after?.pinned, true);
    });
  });
});
