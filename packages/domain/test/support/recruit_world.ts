import type { OrderProfile, ProviderOrderGate } from '../../src/booking_ports.js';
import { FakeBlockGate } from '../../src/fake_block_gate.js';
import { MemoryRecruitStore } from '../../src/memory_recruit_store.js';
import type { NotificationRow } from '../../src/notification_ports.js';
import type { ProviderFacts, RecruitDeps } from '../../src/recruit_ports.js';
import { createRecruitPost } from '../../src/recruit_use_cases.js';
import { collaborationId, type Collaboration } from '../../src/studio_collaboration.js';
import { SequentialIdGen, type ControllableClock } from './booking_world.js';
import { createNotifyWorld, type NotifyWorld } from './notify_world.js';

/** 2026-10-10T10:00Z is 17:00 in Vietnam; the VN day ends 7 hours later (17:00Z). */
export const RECRUIT_WORLD_START = new Date('2026-10-10T10:00:00.000Z');

/** A valid create input (collaborator kind, HCM Q1 + Q3, wedding + family). */
export const VALID_POST = {
  kind: 'collaborator',
  title: 'Tuyển CTV chụp cưới cuối tuần',
  specialties: ['wedding', 'family'],
  areas: ['hcm-q1', 'hcm-q3'],
  frequency: 'weekly',
  feeHint: { type: 'per_shoot', amount: 800_000 },
  requirements: 'Có máy full-frame, đã chụp cưới ít nhất một năm.',
} as const;

export class FakeOrderGate implements ProviderOrderGate {
  constructor(private readonly people: Map<string, ProviderFacts>) {}

  async acceptsOrders(uid: string): Promise<boolean> {
    return this.people.get(uid)?.acceptsOrders === true;
  }

  async orderProfile(uid: string): Promise<OrderProfile | null> {
    const p = this.people.get(uid);
    return p ? { acceptsOrders: p.acceptsOrders, providerType: p.providerType } : null;
  }
}

export interface RecruitWorld {
  readonly deps: RecruitDeps;
  readonly store: MemoryRecruitStore;
  readonly people: Map<string, ProviderFacts>;
  readonly blocks: FakeBlockGate;
  /** `${uid}/${postId}`: a portfolio post of that photographer. */
  readonly ownedPosts: Set<string>;
  readonly notify: NotifyWorld;
  readonly clock: ControllableClock;
  /** Inbox rows of `uid` (rendered by #138's hooks), oldest first. */
  rowsOf(uid: string): NotificationRow[];
}

function facts(uid: string, over: Partial<ProviderFacts>): ProviderFacts {
  return {
    uid,
    role: 'photographer',
    providerType: 'individual',
    acceptsOrders: true,
    businessVerified: false,
    name: uid,
    avatarUrl: null,
    ...over,
  };
}

/**
 * Studios `s1` ("Studio Mây") and `s2` ("Studio Nắng"), verified; `s3` an unverified studio.
 * Verified individuals `p1`–`p4`, artist `a1`; unverified individual `u1`; customer `c1`.
 */
export function createRecruitWorld(): RecruitWorld {
  const notifyWorld = createNotifyWorld(new Date(RECRUIT_WORLD_START.getTime()));
  const clock = notifyWorld.clock;
  const store = new MemoryRecruitStore();
  const people = new Map<string, ProviderFacts>();
  const add = (p: ProviderFacts): void => {
    people.set(p.uid, p);
    notifyWorld.users.users.set(p.uid, { name: p.name, avatarUrl: p.avatarUrl });
  };
  add(facts('s1', { providerType: 'studio', name: 'Studio Mây', avatarUrl: 'https://img/s1.jpg', businessVerified: true }));
  add(facts('s2', { providerType: 'studio', name: 'Studio Nắng' }));
  add(facts('s3', { providerType: 'studio', name: 'Studio Mới', acceptsOrders: false }));
  ['Minh Trí', 'Lan Chi', 'Hồng Nhung', 'Quốc Bảo'].forEach((name, i) => add(facts(`p${i + 1}`, { name })));
  add(facts('a1', { providerType: 'artist', name: 'Anh Tú' }));
  add(facts('u1', { name: 'Chưa Xác Minh', acceptsOrders: false }));
  add(facts('c1', { role: 'customer', name: 'Khách Lan', acceptsOrders: false }));

  const blocks = new FakeBlockGate();
  const ownedPosts = new Set<string>();
  const deps: RecruitDeps = {
    store,
    people: { provider: async (uid) => people.get(uid) ?? null },
    orders: new FakeOrderGate(people),
    blocks,
    posts: { ownedBy: async (uid, ids) => ids.every((id) => ownedPosts.has(`${uid}/${id}`)) },
    notify: notifyWorld.deps,
    clock,
    ids: new SequentialIdGen('rp'),
  };
  return {
    deps,
    store,
    people,
    blocks,
    ownedPosts,
    notify: notifyWorld,
    clock,
    rowsOf: (uid) => notifyWorld.store.rowsOf(uid),
  };
}

/** Creates an open post by `studioId` and returns its id. */
export async function openPost(w: RecruitWorld, studioId: string, over: Record<string, unknown> = {}): Promise<string> {
  const { postId } = await createRecruitPost(w.deps, studioId, { ...VALID_POST, ...over });
  return postId;
}

/** Seeds the main collaboration document of the pair (active by default, created and activated now). */
export function seedCollaboration(
  w: RecruitWorld,
  studioId: string,
  collaboratorId: string,
  over: Partial<Collaboration> = {},
): Collaboration {
  const now = w.clock.now();
  const party = (uid: string) => ({ name: w.people.get(uid)?.name ?? uid, avatarUrl: w.people.get(uid)?.avatarUrl ?? null });
  const c: Collaboration = {
    id: collaborationId(studioId, collaboratorId),
    studioId,
    collaboratorId,
    studio: party(studioId),
    collaborator: party(collaboratorId),
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
  w.store.seedCollaboration(c);
  return c;
}
