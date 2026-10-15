import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import type { ServiceAddon } from '../src/addon.js';
import type { AddonDeps } from '../src/addon_ports.js';
import { deleteAddon, saveAddon } from '../src/addon_use_cases.js';
import type { ServiceRecord } from '../src/booking_ports.js';
import { DomainError } from '../src/errors.js';
import { MemoryAddonStore } from '../src/memory_addon_store.js';

const NOW = new Date('2026-10-08T10:00:00.000Z');
const OLD = '2026-10-01T00:00:00.000Z';

async function refused(p: Promise<unknown>, code: string, field?: string): Promise<void> {
  await assert.rejects(
    p,
    (e: unknown) => e instanceof DomainError && e.code === code && (field === undefined || e.field === field),
  );
}

describe('addon use cases', () => {
  let store: MemoryAddonStore;
  let services: Map<string, ServiceRecord>;
  let deps: AddonDeps;
  let n: number;

  const body = (over: Record<string, unknown> = {}): Record<string, unknown> => ({
    kind: 'makeup',
    name: 'Trang điểm',
    price: 300_000,
    unit: 'per_person',
    maxQty: 4,
    serviceIds: [],
    active: true,
    ...over,
  });
  const addon = (id: string, over: Partial<ServiceAddon> = {}): ServiceAddon => ({
    id,
    providerId: 'p1',
    kind: 'makeup',
    name: id,
    price: 100_000,
    unit: 'per_booking',
    maxQty: 1,
    serviceIds: [],
    active: true,
    createdAt: OLD,
    updatedAt: OLD,
    ...over,
  });
  const seedActive = (count: number): void => {
    for (let i = 0; i < count; i++) store.seedAddon(addon(`a${String(i).padStart(2, '0')}`));
  };

  beforeEach(() => {
    store = new MemoryAddonStore();
    store.providers.add('p1');
    services = new Map([
      ['s1', { id: 's1', photographerId: 'p1', name: 'Gói 1', price: 1_000_000, durationMinutes: 60, active: true }],
      ['s2', { id: 's2', photographerId: 'p1', name: 'Gói ẩn', price: 2_000_000, durationMinutes: 60, active: false }],
    ]);
    n = 0;
    deps = {
      addons: store,
      services: {
        getService: async (pid, sid) => {
          const s = services.get(sid);
          return s !== undefined && s.photographerId === pid ? s : null;
        },
      },
      clock: { now: () => NOW },
      ids: { newId: () => `NEW${++n}` },
    };
  });

  it('saveAddon creates an add-on with a new id, providerId = caller, createdAt = updatedAt = now', async () => {
    const res = await saveAddon(deps, 'p1', body());
    assert.deepEqual(res, { addonId: 'NEW1' });
    const a = store.addons.get('p1/NEW1');
    assert.equal(a?.providerId, 'p1');
    assert.equal(a?.createdAt, NOW.toISOString());
    assert.equal(a?.updatedAt, NOW.toISOString());
    assert.equal(a?.name, 'Trang điểm');
    assert.equal(store.locks.get('p1')?.activeCount, 1);
  });

  it("saveAddon updates the caller's add-on and keeps createdAt", async () => {
    store.seedAddon(addon('a1', { active: false }));
    const res = await saveAddon(deps, 'p1', body({ addonId: 'a1', name: 'Tên mới' }));
    assert.deepEqual(res, { addonId: 'a1' });
    const a = store.addons.get('p1/a1');
    assert.equal(a?.name, 'Tên mới');
    assert.equal(a?.createdAt, OLD);
    assert.equal(a?.updatedAt, NOW.toISOString());
    assert.equal(store.addons.size, 1);
  });

  it('an unknown addonId is not_found and writes nothing', async () => {
    await refused(saveAddon(deps, 'p1', body({ addonId: 'nope' })), 'not_found');
    assert.equal(store.writes, 0);
  });

  it("another provider's addonId is not_found (paths are per provider)", async () => {
    store.providers.add('p2');
    store.seedAddon(addon('a1', { providerId: 'p2' }));
    await refused(saveAddon(deps, 'p1', body({ addonId: 'a1' })), 'not_found');
    assert.equal(store.addons.get('p2/a1')?.name, 'a1');
  });

  it('a caller without a provider profile is permission_denied', async () => {
    await refused(saveAddon(deps, 'c1', body()), 'permission_denied');
    assert.equal(store.writes, 0);
  });

  it('serviceIds naming a package the caller does not have is invalid_argument field serviceIds', async () => {
    await refused(saveAddon(deps, 'p1', body({ serviceIds: ['zzz'] })), 'invalid_argument', 'serviceIds');
    assert.equal(store.writes, 0);
  });

  it('a hidden package is accepted in serviceIds', async () => {
    await saveAddon(deps, 'p1', body({ serviceIds: ['s1', 's2'] }));
    assert.deepEqual(store.addons.get('p1/NEW1')?.serviceIds, ['s1', 's2']);
  });

  it('creating the 11th active add-on is addon_limit', async () => {
    seedActive(10);
    await refused(saveAddon(deps, 'p1', body()), 'addon_limit');
    assert.equal(store.writes, 0);
  });

  it('creating an 11th inactive add-on succeeds', async () => {
    seedActive(10);
    await saveAddon(deps, 'p1', body({ active: false }));
    assert.equal(store.locks.get('p1')?.activeCount, 10);
  });

  it('turning on an inactive add-on while 10 are active is addon_limit', async () => {
    seedActive(10);
    store.seedAddon(addon('zz', { active: false }));
    await refused(saveAddon(deps, 'p1', body({ addonId: 'zz' })), 'addon_limit');
  });

  it('editing an already active add-on while 10 are active succeeds', async () => {
    seedActive(10);
    await saveAddon(deps, 'p1', body({ addonId: 'a00', name: 'Đổi tên' }));
    assert.equal(store.addons.get('p1/a00')?.name, 'Đổi tên');
    assert.equal(store.locks.get('p1')?.activeCount, 10);
  });

  it('turning off then on again counts correctly (activeCount written each time)', async () => {
    seedActive(10);
    await saveAddon(deps, 'p1', body({ addonId: 'a00', active: false }));
    assert.equal(store.locks.get('p1')?.activeCount, 9);
    await saveAddon(deps, 'p1', body({ addonId: 'a00', active: true }));
    assert.equal(store.locks.get('p1')?.activeCount, 10);
  });

  it('two concurrent turn-on transactions cannot both pass', async () => {
    seedActive(9);
    const results = await Promise.allSettled([
      saveAddon(deps, 'p1', body({ name: 'Một' })),
      saveAddon(deps, 'p1', body({ name: 'Hai' })),
    ]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    const rejected = results.find((r) => r.status === 'rejected');
    assert.ok(rejected?.status === 'rejected');
    assert.ok(rejected.reason instanceof DomainError && rejected.reason.code === 'addon_limit');
    assert.equal(store.locks.get('p1')?.activeCount, 10);
  });

  it('the memory store requires lockProvider before writes', async () => {
    await assert.rejects(
      store.runTransaction(async (tx) => {
        tx.setActiveCount('p1', 1, OLD);
      }),
      /lockProvider/,
    );
  });

  it('deleteAddon removes the add-on and updates activeCount', async () => {
    store.seedAddon(addon('a1'));
    store.seedAddon(addon('a2'));
    store.seedAddon(addon('a3', { active: false }));
    assert.deepEqual(await deleteAddon(deps, 'p1', { addonId: 'a1' }), {});
    assert.equal(store.addons.has('p1/a1'), false);
    assert.equal(store.locks.get('p1')?.activeCount, 1);
  });

  it('deleteAddon of an unknown id is not_found', async () => {
    await refused(deleteAddon(deps, 'p1', { addonId: 'nope' }), 'not_found');
    await refused(deleteAddon(deps, 'p1', { addonId: 'a/b' }), 'invalid_argument', 'addonId');
  });

  it('deleteAddon by a non-provider is permission_denied', async () => {
    store.seedAddon(addon('a1'));
    await refused(deleteAddon(deps, 'c1', { addonId: 'a1' }), 'permission_denied');
    assert.equal(store.addons.has('p1/a1'), true);
  });
});
