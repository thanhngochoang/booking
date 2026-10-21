import { MemoryStudioStore } from '../../src/memory_studio_store.js';
import type { StudioProfile } from '../../src/studio_membership.js';
import type { StudioDeps } from '../../src/studio_ports.js';
import { ControllableClock, SequentialIdGen } from './booking_world.js';

/** 2026-10-10T10:00Z is 17:00 in Vietnam; the VN day ends 7 hours later (17:00Z). */
export const STUDIO_WORLD_START = new Date('2026-10-10T10:00:00.000Z');

export interface StudioWorld {
  readonly deps: StudioDeps;
  readonly store: MemoryStudioStore;
  readonly clock: ControllableClock;
}

export function studioProfile(uid: string, over: Partial<StudioProfile> = {}): StudioProfile {
  return {
    uid,
    providerType: 'individual',
    onboardingComplete: true,
    businessVerified: false,
    memberCount: 0,
    studioId: null,
    studioCooldownUntil: null,
    name: uid,
    avatarUrl: null,
    ...over,
  };
}

/**
 * Studios `s1` ("Studio Mây", onboarded, not business-verified) and `s2` ("Studio Nắng"); photographers
 * `m1`–`m5` (individual, onboarded), artist `a1`, unfinished `u1`. Open studio bookings per
 * (studio, member) are set with `store.setOpenAssignments`.
 */
export function createStudioWorld(): StudioWorld {
  const store = new MemoryStudioStore();
  const clock = new ControllableClock(new Date(STUDIO_WORLD_START.getTime()));
  store.seedProfile(studioProfile('s1', { providerType: 'studio', name: 'Studio Mây', avatarUrl: 'https://img/s1.jpg' }));
  store.seedProfile(studioProfile('s2', { providerType: 'studio', name: 'Studio Nắng' }));
  const names = ['Minh Trí', 'Lan Chi', 'Hồng Nhung', 'Quốc Bảo', 'Thu Hà'];
  names.forEach((name, i) => store.seedProfile(studioProfile(`m${i + 1}`, { name })));
  store.seedProfile(studioProfile('a1', { providerType: 'artist', name: 'Anh Tú' }));
  store.seedProfile(studioProfile('u1', { onboardingComplete: false, name: 'Chưa Xong' }));
  const deps: StudioDeps = { studios: store, clock, ids: new SequentialIdGen('studio') };
  return { deps, store, clock };
}
