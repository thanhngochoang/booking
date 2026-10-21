import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import { MemoryProviderStore, type ProviderDeps } from '@photobooking/domain';
import { handleSetProviderType, handleSetStudioAddress } from '../../src/callables/provider.js';

describe('provider callables', () => {
  let store: MemoryProviderStore;
  let recomputed: string[];

  function deps(): ProviderDeps {
    return {
      providers: store,
      clock: { now: () => new Date('2026-10-10T12:00:00.000Z') },
      recomputeArtistTier: async (uid) => {
        recomputed.push(uid);
      },
    };
  }

  beforeEach(() => {
    store = new MemoryProviderStore();
    recomputed = [];
    store.seedProfile({
      uid: 'p1',
      providerType: 'individual',
      onboardingComplete: false,
      artistSince: null,
      studioDistrict: null,
      studioCity: null,
      memberCount: 0,
    });
  });

  it('unauthenticated is refused', async () => {
    await assert.rejects(
      () => handleSetProviderType({ auth: undefined, data: { type: 'studio' } }, deps()),
      (e: unknown) =>
        e instanceof HttpsError &&
        e.code === 'unauthenticated' &&
        (e.details as { code?: string } | undefined)?.code === 'permission_denied',
    );
    await assert.rejects(
      () => handleSetStudioAddress({ auth: undefined, data: {} }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'unauthenticated',
    );
  });

  it('domain errors map to HttpsError codes', async () => {
    await assert.rejects(
      () => handleSetProviderType({ auth: { uid: 'p1' }, data: { type: 'artist' } }, deps()),
      (e: unknown) =>
        e instanceof HttpsError &&
        e.code === 'invalid-argument' &&
        (e.details as { code?: string } | undefined)?.code === 'invalid_argument',
    );
    await assert.rejects(
      () => handleSetProviderType({ auth: { uid: 'nobody' }, data: { type: 'studio' } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'not-found',
    );
    store.seedProfile({
      uid: 'p2',
      providerType: 'individual',
      onboardingComplete: true,
      artistSince: null,
      studioDistrict: null,
      studioCity: null,
      memberCount: 0,
    });
    store.activeBookings.set('p2', 1);
    await assert.rejects(
      () => handleSetProviderType({ auth: { uid: 'p2' }, data: { type: 'studio' } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'failed-precondition',
    );
  });

  it('setProviderType returns the new type', async () => {
    const res = await handleSetProviderType({ auth: { uid: 'p1' }, data: { type: 'studio' } }, deps());
    assert.deepEqual(res, { providerType: 'studio' });
  });

  it('setStudioAddress returns the saved address for a studio', async () => {
    await handleSetProviderType({ auth: { uid: 'p1' }, data: { type: 'studio' } }, deps());
    const res = await handleSetStudioAddress(
      { auth: { uid: 'p1' }, data: { line: '12 Lê Lợi', district: 'Quận 1', city: 'TP.HCM' } },
      deps(),
    );
    assert.equal(res.district, 'Quận 1');
    assert.equal(res.ward, null);
  });
});
