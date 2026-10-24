import type { Booking } from '../../src/booking.js';
import { MemoryRecruitStore } from '../../src/memory_recruit_store.js';
import type { NotificationRow, NotifyDeps } from '../../src/notification_ports.js';
import type { ProviderFacts, RecruitDeps } from '../../src/recruit_ports.js';
import { respondCollabOffer } from '../../src/collab_offers.js';
import { assignBooking, type StudioBookingDeps } from '../../src/studio_assignment.js';
import { collaborationId, type Collaboration } from '../../src/studio_collaboration.js';
import { acceptedStudioBooking, createBookingWorld, SequentialIdGen, withStudio, type BookingWorld } from './booking_world.js';
import { createNotifyWorld, type NotifyWorld } from './notify_world.js';

/** 2026-10-15 14:00 VN = 07:00Z (acceptedStudioBooking's default); the assign deadline is 24 h before. */
export const COLLAB_DAY = '2026-10-15';
export const COLLAB_START = new Date('2026-10-15T07:00:00.000Z');
export const COLLAB_DEADLINE = new Date('2026-10-14T07:00:00.000Z');

/**
 * Studio bookings and S27 collaborations on one clock: the booking world's studio `s1` ("Studio Mây",
 * members `m1`, `m2`), verified individuals `p1` ("Minh Trí"), `p2` ("Lan Chi"), `p3` (not a collaborator),
 * unverified `u1`; customer `c1`. The recruit store is linked to the booking store, so the assignment
 * transaction reads and writes collaborations, collab jobs and recruit counters.
 */
export interface CollabWorld {
  readonly bw: BookingWorld;
  readonly recruit: MemoryRecruitStore;
  readonly deps: RecruitDeps;
  readonly assignDeps: StudioBookingDeps;
  readonly notify: NotifyWorld;
  readonly people: Map<string, ProviderFacts>;
  /** Bookings whose shoot milestone was released, or refunded without release (`milestones.shootMilestone`). */
  readonly released: Set<string>;
  readonly refunded: Set<string>;
  rowsOf(uid: string): NotificationRow[];
}

const NAMES: Record<string, string> = {
  s1: 'Studio Mây',
  m1: 'Thợ m1',
  m2: 'Thợ m2',
  p1: 'Minh Trí',
  p2: 'Lan Chi',
  p3: 'Hồng Nhung',
  u1: 'Chưa Xác Minh',
  c1: 'Khách Lan',
};

export function createCollabWorld(): CollabWorld {
  const bw = withStudio(createBookingWorld(), 's1', ['m1', 'm2']);
  const recruit = new MemoryRecruitStore();
  bw.store.recruit = recruit;
  const notifyWorld = createNotifyWorld();
  const notify: NotifyDeps = { ...notifyWorld.deps, clock: bw.clock };
  const people = new Map<string, ProviderFacts>();
  for (const [uid, name] of Object.entries(NAMES)) {
    notifyWorld.users.users.set(uid, { name, avatarUrl: null });
    bw.people.set(uid, { name, avatarUrl: null });
  }
  for (const uid of ['p1', 'p2', 'p3', 'u1']) {
    bw.providers.set(uid, { verified: uid !== 'u1', onboardingComplete: true });
  }
  for (const uid of ['s1', 'p1', 'p2', 'p3', 'u1']) {
    people.set(uid, {
      uid,
      role: 'photographer',
      providerType: uid === 's1' ? 'studio' : 'individual',
      acceptsOrders: uid !== 'u1',
      businessVerified: false,
      name: NAMES[uid] ?? uid,
      avatarUrl: null,
    });
  }
  const released = new Set<string>();
  const refunded = new Set<string>();
  const deps: RecruitDeps = {
    store: recruit,
    people: { provider: async (uid) => people.get(uid) ?? null },
    orders: bw.deps.providers,
    blocks: bw.blocks,
    posts: { ownedBy: async () => true },
    milestones: {
      shootMilestone: async (bookingId) => (released.has(bookingId) ? 'released' : refunded.has(bookingId) ? 'refunded' : 'waiting'),
    },
    notify,
    clock: bw.clock,
    ids: new SequentialIdGen('rc'),
  };
  const assignDeps: StudioBookingDeps = { ...bw.studioDeps, notify };
  return {
    bw,
    recruit,
    deps,
    assignDeps,
    notify: notifyWorld,
    people,
    released,
    refunded,
    rowsOf: (uid) => notifyWorld.store.rowsOf(uid),
  };
}

/** The main collaboration document of `s1` and `uid`, active since now unless `over` says otherwise. */
export function seedCollab(w: CollabWorld, uid: string, over: Partial<Collaboration> = {}, studioId = 's1'): Collaboration {
  const now = w.bw.clock.now();
  const c: Collaboration = {
    id: collaborationId(studioId, uid),
    studioId,
    collaboratorId: uid,
    studio: { name: NAMES[studioId] ?? studioId, avatarUrl: null },
    collaborator: { name: NAMES[uid] ?? uid, avatarUrl: null },
    status: 'active',
    initiatedBy: 'studio',
    applicationId: null,
    defaultFee: null,
    termsAcceptedAt: now,
    createdAt: now,
    expiresAt: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000),
    activeAt: now,
    endedAt: null,
    endedBy: null,
    updatedAt: now,
    ...over,
  };
  w.recruit.seedCollaboration(c);
  return c;
}

/** c1's paid, accepted booking with `s1` on 2026-10-15 14:00 (deadline 2026-10-14T07:00Z). */
export const studioBooking = (w: CollabWorld, o: { customerId?: string; day?: string; start?: string } = {}): Promise<Booking> =>
  acceptedStudioBooking(w.bw, o);

/** `s1` offers the booking to collaborator `uid` for `fee`. */
export const offer = (w: CollabWorld, bookingId: string, uid: string, fee: unknown = 800_000, caller = 's1'): Promise<Booking> =>
  assignBooking(w.assignDeps, caller, { bookingId, assigneeId: uid, assigneeKind: 'collaborator', agreedFee: fee });

/** `uid` answers the offer on the booking. */
export const answer = (w: CollabWorld, uid: string, bookingId: string, accept: boolean) =>
  respondCollabOffer(w.assignDeps, uid, { bookingId, accept });
