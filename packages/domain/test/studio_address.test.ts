import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { DomainError } from '../src/errors.js';
import { MemoryProviderStore } from '../src/memory_provider_store.js';
import type { ProviderDeps, ProviderProfile } from '../src/provider_ports.js';
import { setStudioAddress, validateStudioAddress } from '../src/studio_address.js';

const NOW = new Date('2026-10-05T10:00:00.000Z');

function profile(over: Partial<ProviderProfile> = {}): ProviderProfile {
  return {
    uid: 'p1',
    providerType: 'studio',
    onboardingComplete: false,
    artistSince: null,
    studioDistrict: null,
    studioCity: null,
    memberCount: 0,
    ...over,
  };
}

const valid = { line: '  12 Nguyễn Huệ ', district: ' Quận 1 ', city: ' TP.HCM ' };

function invalid(raw: unknown): void {
  assert.throws(
    () => validateStudioAddress(raw),
    (e: unknown) => e instanceof DomainError && e.code === 'invalid_argument',
  );
}

describe('setStudioAddress', () => {
  let store: MemoryProviderStore;
  let deps: ProviderDeps;

  beforeEach(() => {
    store = new MemoryProviderStore();
    deps = {
      providers: store,
      clock: { now: () => NOW },
      recomputeArtistTier: async () => {},
    };
  });

  it('a studio saves a trimmed address and the public district', async () => {
    store.seedProfile(profile());
    const a = await setStudioAddress(deps, 'p1', { ...valid, lat: 10.77, lng: 106.7 });
    assert.deepEqual(a, {
      line: '12 Nguyễn Huệ',
      ward: null,
      district: 'Quận 1',
      city: 'TP.HCM',
      lat: 10.77,
      lng: 106.7,
    });
    assert.deepEqual(store.studioAddresses.get('p1'), a);
    assert.equal(store.profiles.get('p1')?.studioDistrict, 'Quận 1');
    assert.equal(store.profiles.get('p1')?.studioCity, 'TP.HCM');
  });

  it('an individual is not eligible', async () => {
    store.seedProfile(profile({ providerType: 'individual' }));
    await assert.rejects(
      setStudioAddress(deps, 'p1', valid),
      (e: unknown) => e instanceof DomainError && e.code === 'not_eligible',
    );
    assert.equal(store.writes, 0);
  });

  it('unknown caller is not_found', async () => {
    await assert.rejects(
      setStudioAddress(deps, 'ghost', valid),
      (e: unknown) => e instanceof DomainError && e.code === 'not_found',
    );
  });

  it('line shorter than 5 is invalid', () => {
    invalid({ ...valid, line: ' 123 ' });
    invalid({ ...valid, line: 'x'.repeat(121) });
    invalid({ ...valid, district: 'Q' });
    invalid({ ...valid, city: 'x'.repeat(61) });
    invalid({ ...valid, ward: 'x'.repeat(61) });
    invalid(null);
    invalid({ ...valid, line: 12345 });
  });

  it('lat without lng is invalid', () => {
    invalid({ ...valid, lat: 10.7 });
    invalid({ ...valid, lng: 106.7 });
    invalid({ ...valid, lat: 'a', lng: 106 });
    invalid({ ...valid, lat: Number.NaN, lng: 106 });
  });

  it('a point outside Vietnam is invalid', () => {
    invalid({ ...valid, lat: 51.5, lng: -0.12 });
    invalid({ ...valid, lat: 7.9, lng: 106 });
    invalid({ ...valid, lat: 10, lng: 110.1 });
    assert.doesNotThrow(() => validateStudioAddress({ ...valid, lat: 8, lng: 102 }));
    assert.doesNotThrow(() => validateStudioAddress({ ...valid, lat: 24, lng: 110 }));
  });

  it('ward is optional', () => {
    assert.equal(validateStudioAddress(valid).ward, null);
    assert.equal(validateStudioAddress({ ...valid, ward: '   ' }).ward, null);
    assert.equal(validateStudioAddress({ ...valid, ward: ' Bến Nghé ' }).ward, 'Bến Nghé');
    assert.equal(validateStudioAddress(valid).lat, null);
  });
});
