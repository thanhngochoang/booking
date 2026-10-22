import { formatVnDate } from '../../src/booking_policy.js';
import type { CustomerContactRecord } from '../../src/booking_ports.js';
import { FakeBlockGate } from '../../src/fake_block_gate.js';
import type { InstantConfig, InstantProfile } from '../../src/instant.js';
import type { InstantDayState } from '../../src/instant_match.js';
import type { InstantDeps } from '../../src/instant_ports.js';
import { createInstantRequest, inviteInstant } from '../../src/instant_requests.js';
import { MemoryInstantStore, MemoryPresenceDirectory } from '../../src/memory_instant_store.js';
import type { PushMessage } from '../../src/notification_ports.js';
import { acceptsOrders, type OrderEligibilityFields } from '../../src/provider_orders.js';
import { T0, TAO_DAN, aConfig, aPresence, north, type PresenceOverrides } from './instant_fixtures.js';

export interface InstantWorldClock {
  now(): Date;
  set(d: Date): void;
  advance(ms: number): void;
}

export interface InstantWorld {
  readonly deps: InstantDeps;
  readonly store: MemoryInstantStore;
  readonly presenceDirectory: MemoryPresenceDirectory;
  /** Every push, by recipient uid. */
  readonly pushes: Map<string, PushMessage[]>;
  /** `photographers/{uid}` order eligibility (#198's ProviderOrderGate reads it). */
  readonly gate: Map<string, OrderEligibilityFields>;
  /** Also `deps.blocks`. */
  readonly blocks: FakeBlockGate;
  /** Photographers with a VN phone on file. */
  readonly phones: Set<string>;
  /** Customer contacts (`users/{uid}/private/contact`). */
  readonly contacts: Map<string, CustomerContactRecord>;
  readonly users: Map<string, { name: string; avatarUrl: string | null }>;
  readonly profiles: Map<string, InstantProfile>;
  /** Key `${uid}/${yyyy-MM-dd}` (Vietnam date). */
  readonly days: Map<string, InstantDayState>;
  readonly clock: InstantWorldClock;
  config: InstantConfig;
  /** Puts an online, fresh presence (heartbeat now) at a point; `overrides` win. */
  online(uid: string, at: { lat: number; lng: number }, overrides?: PresenceOverrides): void;
  /** A customer with a name and, unless `phone: null`, a VN phone. */
  customer(uid: string, opts?: { phone?: string | null; name?: string }): void;
  /** Today's (Vietnam date of the clock) availability state of a provider. */
  day(uid: string, state: InstantDayState): void;
}

/** Photographers p1–p5 around Tao Đàn (0,5–2,5 km north) and p6 at 8 km. */
export const NEARBY_KM: Readonly<Record<string, number>> = { p1: 0.5, p2: 1, p3: 1.5, p4: 2, p5: 2.5, p6: 8 };

/** A fresh world at T0 (2026-10-22 15:00 in Vietnam): seed config, Lan with a phone, p1–p6 online and eligible. */
export function createInstantWorld(opts: { now?: Date } = {}): InstantWorld {
  let current = new Date((opts.now ?? T0).getTime());
  const clock: InstantWorldClock = {
    now: () => new Date(current.getTime()),
    set: (d) => { current = new Date(d.getTime()); },
    advance: (ms) => { current = new Date(current.getTime() + ms); },
  };
  const store = new MemoryInstantStore();
  const presenceDirectory = new MemoryPresenceDirectory(store);
  const pushes = new Map<string, PushMessage[]>();
  const gate = new Map<string, OrderEligibilityFields>();
  const blocks = new FakeBlockGate();
  const phones = new Set<string>();
  const contacts = new Map<string, CustomerContactRecord>();
  const users = new Map<string, { name: string; avatarUrl: string | null }>();
  const profiles = new Map<string, InstantProfile>();
  const days = new Map<string, InstantDayState>();
  let counter = 0;

  const world: InstantWorld = {
    store,
    presenceDirectory,
    pushes,
    gate,
    blocks,
    phones,
    contacts,
    users,
    profiles,
    days,
    clock,
    config: aConfig(),
    deps: undefined as unknown as InstantDeps,
    online(uid, at, overrides = {}) {
      const base = aPresence(uid, { lat: at.lat, lng: at.lng, heartbeatAt: clock.now(), updatedAt: clock.now(), ...overrides });
      store.presences.set(uid, base);
      if (!profiles.has(uid)) profiles.set(uid, base.profile);
    },
    customer(uid, o = {}) {
      users.set(uid, { name: o.name ?? uid, avatarUrl: null });
      if (o.phone === null) contacts.delete(uid);
      else contacts.set(uid, { phone: o.phone ?? '+84901234567' });
    },
    day(uid, state) {
      days.set(`${uid}/${formatVnDate(clock.now())}`, state);
    },
  };

  (world as { deps: InstantDeps }).deps = {
    store,
    presences: presenceDirectory,
    config: { get: async () => world.config },
    providers: {
      acceptsOrders: async (uid) => acceptsOrders(gate.get(uid)),
      orderProfile: async (uid) =>
        gate.has(uid) ? { acceptsOrders: acceptsOrders(gate.get(uid)), providerType: 'individual', studioId: null } : null,
    },
    blocks,
    contacts: { get: async (uid) => contacts.get(uid) ?? null },
    phones: { hasPhone: async (uid) => phones.has(uid) },
    profiles: { snapshot: async (uid) => profiles.get(uid) ?? null },
    days: { stateOf: async (uid, day) => days.get(`${uid}/${day}`) ?? null },
    users: { get: async (uid) => users.get(uid) ?? null },
    push: {
      send: async (uid, msg) => {
        pushes.set(uid, [...(pushes.get(uid) ?? []), msg]);
      },
    },
    clock,
    ids: { newId: () => `id_${String(++counter).padStart(3, '0')}` },
  };

  world.customer('c-lan', { name: 'Lan Anh', phone: '+84901234567' });
  for (const [uid, km] of Object.entries(NEARBY_KM)) {
    world.online(uid, north(TAO_DAN, km));
    gate.set(uid, { verified: true, onboardingComplete: true });
    phones.add(uid);
    users.set(uid, { name: `Nhiếp ảnh gia ${uid}`, avatarUrl: null });
  }
  return world;
}

export const LAN = { uid: 'c-lan' } as const;
export const MEET = { ...TAO_DAN, name: 'Cổng Trương Định, Công viên Tao Đàn' } as const;

/** Lan's request at Tao Đàn (p60 portrait); returns its id. */
export async function lanRequests(w: InstantWorld, input: Record<string, unknown> = {}): Promise<string> {
  const res = await createInstantRequest(w.deps, LAN, { packageCode: 'p60', genre: 'portrait', meetPoint: MEET, ...input });
  return res.requestId;
}

/** Lan's request with offers sent to `ids` (first invite, #140: no payment). */
export async function lanInvites(w: InstantWorld, ids: readonly string[], requestId?: string): Promise<string> {
  const id = requestId ?? (await lanRequests(w));
  const r = w.store.requests.get(id);
  const res = await inviteInstant(w.deps, LAN, { requestId: id, photographerIds: ids, skipped: [], expectedAmountVnd: r?.amountVnd ?? 0 });
  if (res.kind !== 'invited') throw new Error(`invite answered ${res.kind}`);
  return id;
}

/** The pending offer of `uid` on a request. */
export function offerOf(w: InstantWorld, uid: string, requestId: string): string {
  const o = w.store.offersOf(uid).find((x) => x.requestId === requestId);
  if (o === undefined) throw new Error(`no offer of ${uid} on ${requestId}`);
  return o.id;
}
