/**
 * S27 (#151) adapter tests: RecruitDeps over the in-memory Firestore (store, people, owned posts, order gate,
 * block gate), a memory notification store, and a controllable clock. People: studio Cúc (`studio_cuc`,
 * verified), individuals An and Dũng (verified), Bình (unverified), customer Lan (`cust_lan`).
 */

import {
  MemoryNotificationStore,
  MemoryPushSender,
  MemoryUserDirectory,
  type NotifyDeps,
  type RecruitDeps,
  type ShootMilestoneState,
} from '@photobooking/domain';
import { FirestoreProviderOrderGate } from '../../../src/infra/booking_readers.js';
import { FirestoreOwnedPosts, FirestoreRecruitPeople, FirestoreRecruitStore } from '../../../src/infra/recruit_firestore.js';
import { FirestoreBlockGate } from '../../../src/infra/safety_firestore.js';
import type { MemoryFirestore } from './memory_firestore.js';
import { CUSTOMER, NOW, STUDIO } from './studio_fixtures.js';

export const AN = 'an_indiv';
export const DUNG = 'dung_artist';
export const BINH = 'binh_unverified';

/** `users/{uid}` (role, name) and, for a provider, `photographers/{uid}`. */
export function seedProvider(
  db: MemoryFirestore,
  uid: string,
  name: string,
  photographer: Record<string, unknown> | null,
  role: 'photographer' | 'customer' = 'photographer',
): void {
  db.seed(`users/${uid}`, { displayName: name, avatarUrl: `https://img.test/${uid}.jpg`, role });
  if (photographer !== null) {
    db.seed(`photographers/${uid}`, { onboardingComplete: true, verified: true, providerType: 'individual', ...photographer });
  }
}

export function seedRecruitPeople(db: MemoryFirestore): void {
  seedProvider(db, STUDIO, 'Cúc Studio', { providerType: 'studio', businessVerified: true });
  seedProvider(db, AN, 'An', {});
  seedProvider(db, DUNG, 'Dũng', { providerType: 'artist' });
  seedProvider(db, BINH, 'Bình', { verified: false });
  seedProvider(db, CUSTOMER, 'Lan', null, 'customer');
}

export interface RecruitTestWorld {
  readonly deps: RecruitDeps;
  readonly store: FirestoreRecruitStore;
  readonly notifications: MemoryNotificationStore;
  readonly notify: NotifyDeps;
  /** The milestone answer per booking id (default `waiting`). */
  readonly milestones: Map<string, ShootMilestoneState>;
  now: Date;
  advanceHours(h: number): void;
}

export function memoryNotify(now: () => Date): { deps: NotifyDeps; store: MemoryNotificationStore } {
  const store = new MemoryNotificationStore();
  return { store, deps: { store, push: new MemoryPushSender(), users: new MemoryUserDirectory(), clock: { now } } };
}

export function recruitWorld(db: MemoryFirestore, start: Date = NOW): RecruitTestWorld {
  const firestore = db.asFirestore();
  let n = 0;
  const milestones = new Map<string, ShootMilestoneState>();
  const w = {
    now: start,
    advanceHours(h: number) {
      w.now = new Date(w.now.getTime() + h * 3_600_000);
    },
  } as RecruitTestWorld;
  const clock = { now: () => w.now };
  const notify = memoryNotify(clock.now);
  const store = new FirestoreRecruitStore(firestore, clock.now);
  const deps: RecruitDeps = {
    store,
    people: new FirestoreRecruitPeople(firestore),
    orders: new FirestoreProviderOrderGate(firestore),
    blocks: new FirestoreBlockGate(firestore),
    posts: new FirestoreOwnedPosts(firestore),
    milestones: { shootMilestone: async (bookingId) => milestones.get(bookingId) ?? 'waiting' },
    notify: notify.deps,
    clock,
    ids: { newId: () => `01JRECRUIT${String(++n).padStart(16, '0')}` },
  };
  return Object.assign(w, { deps, store, notifications: notify.store, notify: notify.deps, milestones });
}
