import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  FakeBlockGate,
  MemoryRecruitStore,
  MemoryStudioStore,
  type RecruitPost,
  type RecruitSweepDeps,
  type StudioBookingDeps,
  type StudioDeps,
} from '@photobooking/domain';
import { handleBookingClock } from '../../src/scheduled/booking_clock.js';
import { captureLogs, paymentWorld } from './support/payment_world.js';
import { memoryNotify } from './support/recruit_fixtures.js';
import { NOW, STUDIO } from './support/studio_fixtures.js';

const DAY_MS = 86_400_000;

function world() {
  const w = paymentWorld(NOW);
  const bookings: StudioBookingDeps = { ...w.deps, store: w.store, roster: { relationOf: async () => null, person: async () => null } };
  const members: StudioDeps = { studios: new MemoryStudioStore(), clock: { now: () => NOW }, ids: { newId: () => 'x' } };
  const notify = memoryNotify(() => NOW);
  const store = new MemoryRecruitStore();
  const recruit: RecruitSweepDeps = {
    store,
    people: { provider: async () => null },
    orders: { acceptsOrders: async () => true, orderProfile: async () => null },
    blocks: new FakeBlockGate(),
    posts: { ownedBy: async () => true },
    milestones: { shootMilestone: async () => 'waiting' },
    notify: notify.deps,
    clock: { now: () => NOW },
    ids: { newId: () => 'id' },
    assign: bookings,
  };
  return { w, bookings, members, recruit, store, notify: notify.deps };
}

const expiredPost: RecruitPost = {
  id: 'post_old',
  studioId: STUDIO,
  studio: { name: 'Cúc Studio', avatarUrl: null, businessVerified: false },
  kind: 'collaborator',
  title: 'Tuyển CTV chụp cưới cuối tuần',
  specialties: ['wedding'],
  areas: ['hcm-q1'],
  frequency: 'weekly',
  feeHint: { type: 'negotiable' },
  requirements: '',
  status: 'open',
  renewed: false,
  applicationCount: 0,
  matchKeys: [],
  filterKeys: [],
  createdAt: new Date(NOW.getTime() - 31 * DAY_MS),
  updatedAt: new Date(NOW.getTime() - 31 * DAY_MS),
  expiresAt: new Date(NOW.getTime() - DAY_MS),
  closedAt: null,
};

describe('bookingClock recruitSweeps step (S27, no new schedule)', () => {
  it('runs the recruit sweeps before the studio steps, so an expired offer is unassigned before S26\'s overdue mark', async (t) => {
    const { w, bookings, members, recruit, store, notify } = world();
    store.posts.set(expiredPost.id, expiredPost);
    const lines = await captureLogs(t, () =>
      handleBookingClock(w.deps, undefined, { studio: { bookings, members, notify }, recruit }),
    );
    const recruitAt = lines.findIndex((l) => l.includes('bookingClock recruitSweeps completed'));
    const studioAt = lines.findIndex((l) => l.includes('bookingClock studioAssignSweeps completed'));
    assert.ok(recruitAt >= 0 && studioAt > recruitAt, `recruit ${recruitAt}, studio ${studioAt}`);
    assert.ok(lines[recruitAt]?.includes('"postsExpired":1'));
    assert.equal(store.posts.get('post_old')?.status, 'expired');
  });

  it('a failing recruit step is logged and the studio steps still run; without `recruit` the step is skipped', async (t) => {
    const { w, bookings, members, recruit, notify } = world();
    const broken: RecruitSweepDeps = {
      ...recruit,
      store: Object.assign(Object.create(recruit.store) as MemoryRecruitStore, {
        duePosts: async () => {
          throw new Error('index missing');
        },
      }),
    };
    const lines = await captureLogs(t, () =>
      handleBookingClock(w.deps, undefined, { studio: { bookings, members, notify }, recruit: broken }),
    );
    assert.ok(lines.some((l) => l.includes('bookingClock recruitSweeps failed')));
    assert.ok(lines.some((l) => l.includes('bookingClock studioAssignSweeps completed')));
    const quiet = await captureLogs(t, () => handleBookingClock(w.deps, undefined, { studio: { bookings, members, notify } }));
    assert.equal(quiet.some((l) => l.includes('recruitSweeps')), false);
  });
});
