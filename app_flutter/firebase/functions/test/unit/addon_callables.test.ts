import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import { MemoryAddonStore, type AddonDeps, type ServiceAddon } from '@photobooking/domain';
import { handleDeleteAddon, handleSaveAddon } from '../../src/callables/addon.js';

const ID = (n: number): string => `01ARZ3NDEKTSV4RRFFQ69G5F${String(n).padStart(2, '0')}`;

const body = (o: Record<string, unknown> = {}): Record<string, unknown> => ({
  kind: 'makeup',
  name: 'Trang điểm',
  price: 800_000,
  unit: 'per_person',
  maxQty: 4,
  serviceIds: [],
  active: true,
  ...o,
});

const details = (e: unknown): { code?: string; field?: string } =>
  (e as HttpsError).details as { code?: string; field?: string };

describe('addon callables', () => {
  let store: MemoryAddonStore;
  let next: number;

  function deps(): AddonDeps {
    return {
      addons: store,
      services: { getService: async () => null },
      clock: { now: () => new Date('2026-10-10T12:00:00.000Z') },
      ids: { newId: () => ID(next++) },
    };
  }

  beforeEach(() => {
    store = new MemoryAddonStore();
    store.providers.add('p1');
    next = 10;
  });

  it('saveAddon without auth is unauthenticated with code permission_denied', async () => {
    for (const h of [handleSaveAddon, handleDeleteAddon]) {
      await assert.rejects(
        () => h({ auth: undefined, data: {} }, deps()),
        (e: unknown) => e instanceof HttpsError && e.code === 'unauthenticated' && details(e).code === 'permission_denied',
      );
    }
  });

  it('saveAddon returns {addonId} and passes the caller uid', async () => {
    const res = await handleSaveAddon({ auth: { uid: 'p1' }, data: body() }, deps());
    assert.deepEqual(res, { addonId: ID(10) });
    assert.equal(store.addons.get(`p1/${ID(10)}`)?.providerId, 'p1');
    assert.equal(store.locks.get('p1')?.activeCount, 1);
  });

  it('contact_leak maps to invalid-argument with details.code contact_leak and details.field name', async () => {
    await assert.rejects(
      () => handleSaveAddon({ auth: { uid: 'p1' }, data: body({ name: 'Gọi 0903123456' }) }, deps()),
      (e: unknown) =>
        e instanceof HttpsError &&
        e.code === 'invalid-argument' &&
        details(e).code === 'contact_leak' &&
        details(e).field === 'name',
    );
  });

  it('addon_limit maps to resource-exhausted', async () => {
    for (let i = 0; i < 10; i++) {
      const a: ServiceAddon = {
        id: ID(50 + i),
        providerId: 'p1',
        kind: 'other',
        name: `Dịch vụ ${i}`,
        price: 100_000,
        unit: 'per_booking',
        maxQty: 1,
        serviceIds: [],
        active: true,
        createdAt: '2026-10-01T00:00:00.000Z',
        updatedAt: '2026-10-01T00:00:00.000Z',
      };
      store.seedAddon(a);
    }
    await assert.rejects(
      () => handleSaveAddon({ auth: { uid: 'p1' }, data: body() }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'resource-exhausted' && details(e).code === 'addon_limit',
    );
  });

  it('deleteAddon of an unknown id is not-found', async () => {
    await assert.rejects(
      () => handleDeleteAddon({ auth: { uid: 'p1' }, data: { addonId: ID(1) } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'not-found',
    );
  });

  it('a customer calling saveAddon is permission-denied', async () => {
    await assert.rejects(
      () => handleSaveAddon({ auth: { uid: 'customer1' }, data: body() }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'permission-denied',
    );
  });
});
