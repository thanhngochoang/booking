import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { DomainError } from '../src/errors.js';
import { MemoryProviderStore } from '../src/memory_provider_store.js';
import type { ProviderDeps } from '../src/provider_ports.js';
import type { ProviderProfile } from '../src/provider_ports.js';
import { setProviderType } from '../src/set_provider_type.js';

const NOW = new Date('2026-10-05T10:00:00.000Z');

function profile(over: Partial<ProviderProfile> = {}): ProviderProfile {
  return {
    uid: 'p1',
    providerType: 'individual',
    onboardingComplete: true,
    artistSince: null,
    studioDistrict: null,
    studioCity: null,
    ...over,
  };
}

async function refused(p: Promise<unknown>, code: string): Promise<void> {
  await assert.rejects(p, (e: unknown) => e instanceof DomainError && e.code === code);
}

describe('setProviderType', () => {
  let store: MemoryProviderStore;
  let recomputed: string[];
  let deps: ProviderDeps;

  beforeEach(() => {
    store = new MemoryProviderStore();
    recomputed = [];
    deps = {
      providers: store,
      clock: { now: () => NOW },
      recomputeArtistTier: async (uid) => {
        recomputed.push(uid);
        store.log.push('recompute');
      },
    };
  });

  it('a new profile with no open work switches', async () => {
    store.seedProfile(profile({ onboardingComplete: false }));
    const r = await setProviderType(deps, 'p1', { type: 'studio' });
    assert.deepEqual(r, { providerType: 'studio' });
    assert.equal(store.profiles.get('p1')?.providerType, 'studio');
  });

  it('un-finishing setup does not bypass the check', async () => {
    store.seedProfile(profile({ onboardingComplete: false }));
    store.activeBookings.set('p1', 1);
    await refused(setProviderType(deps, 'p1', { type: 'studio' }), 'not_eligible');
    assert.equal(store.profiles.get('p1')?.providerType, 'individual');
    assert.equal(store.writes, 0);
  });

  it('the same choice is a no-op and writes nothing', async () => {
    store.seedProfile(profile({ providerType: 'studio' }));
    const r = await setProviderType(deps, 'p1', { type: 'studio' });
    assert.deepEqual(r, { providerType: 'studio' });
    assert.equal(store.writes, 0);
    assert.deepEqual(recomputed, []);
  });

  it('artist asking for individual is a no-op', async () => {
    store.seedProfile(profile({ providerType: 'artist', artistSince: NOW }));
    const r = await setProviderType(deps, 'p1', { type: 'individual' });
    assert.deepEqual(r, { providerType: 'artist' });
    assert.equal(store.writes, 0);
    assert.equal(store.profiles.get('p1')?.providerType, 'artist');
  });

  it('artist is refused as a choice', async () => {
    store.seedProfile(profile());
    await refused(setProviderType(deps, 'p1', { type: 'artist' }), 'invalid_argument');
    await refused(setProviderType(deps, 'p1', null), 'invalid_argument');
    await refused(setProviderType(deps, 'p1', {}), 'invalid_argument');
  });

  it('an accepted booking blocks the switch', async () => {
    store.seedProfile(profile());
    store.activeBookings.set('p1', 1);
    await refused(setProviderType(deps, 'p1', { type: 'studio' }), 'not_eligible');
    assert.equal(store.profiles.get('p1')?.providerType, 'individual');
  });

  it('a requested booking blocks the switch', async () => {
    store.seedProfile(profile({ providerType: 'studio' }));
    store.activeBookings.set('p1', 1);
    await refused(setProviderType(deps, 'p1', { type: 'individual' }), 'not_eligible');
    assert.equal(store.profiles.get('p1')?.providerType, 'studio');
    assert.deepEqual(recomputed, []);
  });

  it('held money blocks the switch', async () => {
    store.seedProfile(profile());
    store.heldPayments.set('p1', 1);
    await refused(setProviderType(deps, 'p1', { type: 'studio' }), 'not_eligible');
    assert.equal(store.profiles.get('p1')?.providerType, 'individual');
  });

  it('no active booking and no held money lets a finished profile switch', async () => {
    // Which statuses count is the adapter's job (completed bookings are not
    // counted; see the functions integration test). Here: zero counts switch.
    store.seedProfile(profile());
    store.activeBookings.set('p1', 0);
    store.heldPayments.set('p1', 0);
    const r = await setProviderType(deps, 'p1', { type: 'studio' });
    assert.deepEqual(r, { providerType: 'studio' });
    assert.equal(store.profiles.get('p1')?.providerType, 'studio');
  });

  it('switching to studio clears artistSince', async () => {
    store.seedProfile(profile({ providerType: 'artist', artistSince: NOW }));
    await setProviderType(deps, 'p1', { type: 'studio' });
    const p = store.profiles.get('p1');
    assert.equal(p?.providerType, 'studio');
    assert.equal(p?.artistSince, null);
  });

  it('studio back to individual calls recomputeArtistTier once, after the write', async () => {
    store.seedProfile(profile({ providerType: 'studio' }));
    const r = await setProviderType(deps, 'p1', { type: 'individual' });
    assert.deepEqual(r, { providerType: 'individual' });
    assert.deepEqual(recomputed, ['p1']);
    assert.deepEqual(store.log, ['setProviderType', 'recompute']);
  });

  it('unknown caller is not_found', async () => {
    await refused(setProviderType(deps, 'ghost', { type: 'studio' }), 'not_found');
  });
});
