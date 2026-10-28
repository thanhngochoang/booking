import type { EventCaller } from '../../src/event.js';
import { FakeBlockGate } from '../../src/fake_block_gate.js';
import { MemoryOrganizerStore } from '../../src/memory_organizer_store.js';
import type { Organizer } from '../../src/organizer.js';
import type { OrganizerPeople, SuspendOrganizerDeps } from '../../src/organizer_ports.js';
import type { OrderProfile, ProviderOrderGate } from '../../src/booking_ports.js';
import { EMPTY_SPOT_STATS, type Spot } from '../../src/spot.js';
import { createTicketPaymentWorld, type TicketPaymentWorld } from './event_world.js';
import { FakeIdGenerator } from './chat_world.js';
import { createNotifyWorld, type NotifyWorld } from './notify_world.js';

/** 2026-10-18 10:00 in Vietnam. */
export const ORG_NOW = new Date('2026-10-18T03:00:00.000Z');
export const TODAY = '2026-10-18';
export const HOUR = 3_600_000;

export const ADMIN = 'admin';
export const adminCaller: EventCaller = { uid: ADMIN, staffRole: 'admin' };

/** Users with a verified phone. `cust` is a customer (no provider profile). */
const VERIFIED = new Set(['org1', 'org2', 'p1', 'p2', 'cust']);

/** Gate staff candidates g1…g12: phone `09120000NN` (any spacing) or `@gacNN`. */
const gate = (n: number): { uid: string; name: string } => ({ uid: `g${n}`, name: `Gác ${n}` });

class FakeOrganizerPeople implements OrganizerPeople {
  readonly business = new Set<string>();
  readonly payout = new Set<string>();
  readonly lookups: string[] = [];

  async phoneVerified(uid: string): Promise<boolean> {
    return VERIFIED.has(uid);
  }

  async businessVerified(uid: string): Promise<boolean> {
    return this.business.has(uid);
  }

  async payoutAccountOk(uid: string): Promise<boolean> {
    return this.payout.has(uid);
  }

  async lookup(target: string): Promise<{ uid: string; name: string } | null> {
    this.lookups.push(target);
    const phone = /^09120000(\d\d)$/.exec(target.replace(/\s/g, ''));
    if (phone?.[1]) return gate(Number(phone[1]));
    const handle = /^@gac(\d+)$/.exec(target);
    if (handle?.[1]) return gate(Number(handle[1]));
    return null;
  }

  async isStaff(uid: string): Promise<boolean> {
    return uid === ADMIN;
  }
}

/** p1 accepts orders, p2 has a profile but does not, everyone else has no provider profile. */
class FakeProviders implements ProviderOrderGate {
  async acceptsOrders(uid: string): Promise<boolean> {
    return uid === 'p1';
  }

  async orderProfile(uid: string): Promise<OrderProfile | null> {
    if (uid === 'p1') return { acceptsOrders: true, providerType: 'individual' };
    if (uid === 'p2') return { acceptsOrders: false, providerType: 'individual' };
    if (/^q\d+$/.test(uid)) return { acceptsOrders: true, providerType: 'individual' };
    return null;
  }
}

export function spotOf(id: string, over: Partial<Spot> = {}): Spot {
  return {
    id, name: `Điểm ${id}`, city: 'Hà Nội', areaCode: 'hn', point: { lat: 21.0285, lng: 105.8542 }, geohash: 'w7er8',
    radiusM: 500, cover: null, description: '', tips: [], seasonMonths: [], pinned: false, hidden: false,
    status: 'active', hotScore: 0, stats: EMPTY_SPOT_STATS, createdAt: '2026-10-01T00:00:00.000Z',
    updatedAt: '2026-10-01T00:00:00.000Z', rankedAt: null, updatedBy: 'staff',
    managedBy: null, access: null, openHours: null, ...over,
  };
}

export function organizerOf(id: string, over: Partial<Organizer> = {}): Organizer {
  return {
    id, name: `Tổ chức ${id}`, bio: '', avatarUrl: null, status: 'active', phoneVerified: true,
    businessVerified: false, payoutAccountOk: false, managedSpotIds: [],
    createdAt: '2026-10-01T00:00:00.000Z', updatedAt: '2026-10-01T00:00:00.000Z', ...over,
  };
}

export interface OrganizerWorld {
  readonly deps: SuspendOrganizerDeps;
  readonly store: MemoryOrganizerStore;
  readonly people: FakeOrganizerPeople;
  readonly blocks: FakeBlockGate;
  readonly notify: NotifyWorld;
  /** The event side (suspendOrganizer cancels through it); shares the clock. */
  readonly events: TicketPaymentWorld;
  readonly setNow: (at: Date) => void;
}

/**
 * Users org1, org2 (verified phones), providers p1 (accepting orders) and p2 (not), customer `cust`,
 * staff `admin`; spots s1 (free), s2 (managed by org2), s3 (archived, managed by org1 once seeded);
 * org2 is an active organizer managing s2. Clock 2026-10-18 10:00 Vietnam.
 */
export function createOrganizerWorld(): OrganizerWorld {
  const events = createTicketPaymentWorld();
  events.clock.set(ORG_NOW);
  const store = new MemoryOrganizerStore(events.store.events);
  store.seedSpot(spotOf('s1'));
  store.seedSpot(spotOf('s2', { managedBy: 'org2' }));
  store.seedSpot(spotOf('s3', { status: 'archived', managedBy: 'org1' }));
  store.seedOrganizer(organizerOf('org2', { managedSpotIds: ['s2'] }));
  const notify = createNotifyWorld(ORG_NOW);
  for (const [id, name] of [['org1', 'Lan'], ['org2', 'Bình'], ['p1', 'Minh Trí'], ['g1', 'Gác 1']] as const) {
    notify.users.users.set(id, { name, avatarUrl: null });
  }
  const people = new FakeOrganizerPeople();
  const blocks = new FakeBlockGate();
  const deps: SuspendOrganizerDeps = {
    organizers: store,
    people,
    providers: new FakeProviders(),
    blocks,
    notify: notify.deps,
    clock: events.clock,
    ids: new FakeIdGenerator(),
    eventPayments: events.deps,
  };
  const setNow = (at: Date) => {
    events.clock.set(at);
    notify.clock.setTime(at);
  };
  return { deps, store, people, blocks, notify, events, setNow };
}

/** org1 as an active organizer managing s1 (as if a claim had been approved). */
export function withManager(w: OrganizerWorld, spotId = 's1', uid = 'org1'): void {
  w.store.seedOrganizer(organizerOf(uid, { managedSpotIds: [spotId] }));
  w.store.seedSpot({ ...(w.store.spots.get(spotId) ?? spotOf(spotId)), managedBy: uid });
}
