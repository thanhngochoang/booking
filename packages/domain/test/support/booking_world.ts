import type { ServiceAddon } from '../../src/addon.js';
import { MemoryAddonStore } from '../../src/memory_addon_store.js';
import { MemoryBookingStore } from '../../src/memory_booking_store.js';
import { FakePaymentGateway } from '../../src/fake_payment_gateway.js';
import { FakeBlockGate } from '../../src/fake_block_gate.js';
import type { BookingDeps, CustomerContactReader, ServiceCatalog, ServiceRecord } from '../../src/booking_ports.js';
import { acceptsOrders, type OrderEligibilityFields } from '../../src/provider_orders.js';
import type { Clock, IdGenerator } from '../../src/ports.js';
import type { ProviderType } from '../../src/provider_type.js';
import type { StudioBookingDeps } from '../../src/studio_assignment.js';
import type { Booking } from '../../src/booking.js';
import type { TransferNotification } from '../../src/booking_ports.js';
import { createBookingDraft } from '../../src/create_booking.js';
import { createPayment } from '../../src/create_payment.js';
import { handleTransferNotification } from '../../src/handle_transfer.js';
import { transitionBooking } from '../../src/transition_booking.js';
import { TEST_CIPHER } from './test_cipher.js';
export { TEST_CIPHER };

export const TEST_PAYER: NonNullable<TransferNotification['payer']> = {
  bankCode: 'VCB',
  accountNumber: '0071000123456',
  name: 'NGUYEN THANH HA',
  accountMasked: '•••• 3456',
} as const;

import type { SettlementDeps } from '../../src/payment_settlement.js';
import { BookingPaymentSettler } from '../../src/handle_transfer.js';
import { MemoryPaymentLookup } from '../../src/memory_payment_lookup.js';
import type { Spot } from '../../src/spot.js';
import type { SpotSchedule } from '../../src/spot_schedule.js';
import type { SlotOffer } from '../../src/spot_slots.js';

export class ControllableClock implements Clock {
  constructor(private currentTime: Date = new Date('2026-10-10T10:00:00.000Z')) {}

  now(): Date {
    return new Date(this.currentTime.getTime());
  }

  advanceMinutes(mins: number): void {
    this.currentTime = new Date(this.currentTime.getTime() + mins * 60 * 1000);
  }

  advanceHours(hours: number): void {
    this.currentTime = new Date(this.currentTime.getTime() + hours * 60 * 60 * 1000);
  }

  setTime(time: Date): void {
    this.currentTime = new Date(time.getTime());
  }
}

export class SequentialIdGen implements IdGenerator {
  private counter = 0;

  constructor(private prefix = 'id') {}

  newId(): string {
    this.counter += 1;
    return `${this.prefix}_${String(this.counter).padStart(3, '0')}`;
  }
}

export interface BookingWorld {
  readonly deps: BookingDeps;
  readonly settlement: SettlementDeps;
  readonly store: MemoryBookingStore;
  readonly gateway: FakePaymentGateway;
  readonly blocks: FakeBlockGate;
  readonly addons: MemoryAddonStore;
  readonly clock: ControllableClock;
  readonly ids: SequentialIdGen;
  readonly services: Map<string, ServiceRecord>;
  readonly providers: Map<string, OrderEligibilityFields>;
  readonly contacts: Map<string, { phone: string; allowZalo?: boolean; allowWhatsApp?: boolean; name?: string }>;
  /** Provider types (missing = individual); a studio's bookings get the studio fields. */
  readonly providerTypes: Map<string, ProviderType>;
  /** Active memberships: member uid → studio uid (the roster and orderProfile.studioId read it). */
  readonly memberships: Map<string, string>;
  /** Names for the roster's `person`. */
  readonly people: Map<string, { name: string; avatarUrl: string | null }>;
  /** `deps` plus the studio roster (#136). */
  readonly studioDeps: StudioBookingDeps;
}

export function createBookingWorld(initialDate = new Date('2026-10-10T10:00:00.000Z')): BookingWorld {
  const store = new MemoryBookingStore();
  const gateway = new FakePaymentGateway();
  const blocks = new FakeBlockGate();
  const addons = new MemoryAddonStore();
  const clock = new ControllableClock(initialDate);
  const ids = new SequentialIdGen();

  const services = new Map<string, ServiceRecord>();
  const contacts = new Map<string, { phone: string; allowZalo?: boolean; allowWhatsApp?: boolean; name?: string }>();

  // Default photographer is open for orders
  const providers = new Map<string, OrderEligibilityFields>([
    ['p1', { verified: true, onboardingComplete: true }],
  ]);

  // Default seed service
  services.set('srv_01', {
    id: 'srv_01',
    photographerId: 'p1',
    name: 'Gói Chân dung',
    price: 1_000_000,
    durationMinutes: 120,
    active: true,
  });

  // Default seed contacts
  contacts.set('c1', {
    phone: '+84903123456',
    allowZalo: true,
    allowWhatsApp: true,
    name: 'Khách Hàng Một',
  });
  contacts.set('c2', {
    phone: '+84903654321',
    allowZalo: true,
    allowWhatsApp: false,
    name: 'Khách Hàng Hai',
  });

  const serviceCatalog: ServiceCatalog = {
    getService: async (_photographerId, id) => services.get(id) ?? null,
  };

  const contactReader: CustomerContactReader = {
    get: async (id) => contacts.get(id) ?? null,
  };

  const providerTypes = new Map<string, ProviderType>();
  const memberships = new Map<string, string>();
  const people = new Map<string, { name: string; avatarUrl: string | null }>();
  store.memberVerified = (uid) => acceptsOrders(providers.get(uid));

  const deps: BookingDeps = {
    store,
    services: serviceCatalog,
    addons,
    providers: {
      acceptsOrders: async (id) => acceptsOrders(providers.get(id)),
      orderProfile: async (id) =>
        providers.has(id)
          ? {
              acceptsOrders: acceptsOrders(providers.get(id)),
              providerType: providerTypes.get(id) ?? 'individual',
              studioId: memberships.get(id) ?? null,
            }
          : null,
    },
    blocks,
    contacts: contactReader,
    gateway,
    cipher: TEST_CIPHER,
    clock,
    ids,
  };

  const settlement: SettlementDeps = {
    payments: new MemoryPaymentLookup([store]),
    gateway,
    clock,
    subjects: {
      booking: new BookingPaymentSettler(deps),
    },
  };

  const studioDeps: StudioBookingDeps = {
    ...deps,
    store,
    roster: {
      relationOf: async (studioId, uid) => (memberships.get(uid) === studioId ? 'member' : null),
      person: async (uid) => people.get(uid) ?? null,
    },
  };

  return {
    deps,
    settlement,
    store,
    gateway,
    blocks,
    addons,
    clock,
    ids,
    services,
    providers,
    contacts,
    providerTypes,
    memberships,
    people,
    studioDeps,
  };
}

/**
 * Studio `studioId` (verified, onboarded, package `srv_<studioId>` 1 000 000 VND / 120 min) with active
 * `members` (verified unless listed in `unverified`), each with their own package `srv_<member>`.
 */
export function withStudio(
  world: BookingWorld,
  studioId = 's1',
  members: readonly string[] = ['m1', 'm2', 'm3'],
  o: { readonly unverified?: readonly string[] } = {},
): BookingWorld {
  world.providers.set(studioId, { verified: true, onboardingComplete: true });
  world.providerTypes.set(studioId, 'studio');
  world.people.set(studioId, { name: 'Studio Mây', avatarUrl: null });
  world.services.set(`srv_${studioId}`, {
    id: `srv_${studioId}`,
    photographerId: studioId,
    name: 'Gói Studio',
    price: 1_000_000,
    durationMinutes: 120,
    active: true,
  });
  for (const m of members) {
    const verified = !(o.unverified ?? []).includes(m);
    world.providers.set(m, { verified, onboardingComplete: true });
    world.memberships.set(m, studioId);
    world.people.set(m, { name: `Thợ ${m}`, avatarUrl: null });
    world.services.set(`srv_${m}`, {
      id: `srv_${m}`,
      photographerId: m,
      name: 'Gói cá nhân',
      price: 500_000,
      durationMinutes: 60,
      active: true,
    });
  }
  world.store.studioMembers.set(studioId, [...members]);
  return world;
}

/** Seeds the provider's add-ons (each `providerId` is set to `providerId`). */
export function withAddons(world: BookingWorld, providerId: string, addons: readonly ServiceAddon[]): BookingWorld {
  for (const a of addons) world.addons.seedAddon({ ...a, providerId });
  return world;
}

/** The default draft request: c1 books p1's `srv_01` (1 000 000 VND) on 2026-10-15 at 14:00. */
export const DRAFT_INPUT = {
  customerId: 'c1',
  photographerId: 'p1',
  serviceId: 'srv_01',
  day: '2026-10-15',
  start: '14:00',
  place: { name: 'Nhà thờ Lớn' },
} as const;

export function newDraft(world: BookingWorld, overrides: Record<string, unknown> = {}): Promise<Booking> {
  return createBookingDraft(world.deps, { ...DRAFT_INPUT, ...overrides });
}

let txnCounter = 0;

/**
 * A fake-provider bank transfer of `amount` with `content` as the memo (default: the transfer
 * code alone), received now unless `receivedAt` says otherwise. Each call gets a new txnId.
 */
export function transferOf(
  world: BookingWorld,
  p: {
    readonly content: string;
    readonly amount: number;
    readonly txnId?: string;
    readonly receivedAt?: string;
    readonly payer?: TransferNotification['payer'] | null;
  },
): TransferNotification {
  txnCounter += 1;
  const payer = p.payer === null ? undefined : (p.payer ?? TEST_PAYER);
  return {
    provider: 'fake',
    txnId: p.txnId ?? `txn_${txnCounter}`,
    amount: p.amount,
    content: p.content,
    receivedAt: p.receivedAt ?? world.clock.now().toISOString(),
    raw: JSON.stringify({ amount: p.amount, content: p.content }),
    ...(payer ? { payer } : {}),
  };
}

/**
 * Pays a draft in full the way a customer does: a bank-QR payment (createPayment), then one
 * transfer of the exact amount with its code. Returns the payment id.
 */
export async function payDraft(world: BookingWorld, bookingId: string, customerId = 'c1'): Promise<{ readonly paymentId: string }> {
  const { paymentId, checkout } = await createPayment(world.deps, { bookingId, customerId, method: 'bank_qr' });
  await handleTransferNotification(world.deps, transferOf(world, { content: checkout.transferCode, amount: checkout.amount }));
  return { paymentId };
}

/**
 * A studio booking of `withStudio`'s studio paid and accepted by the studio (default: c1, 2026-10-15 14:00,
 * so the assign deadline is 2026-10-14T07:00Z with the clock at 2026-10-10T10:00Z).
 */
export async function acceptedStudioBooking(
  world: BookingWorld,
  o: { readonly customerId?: string; readonly day?: string; readonly start?: string; readonly studioId?: string } = {},
): Promise<Booking> {
  const studioId = o.studioId ?? 's1';
  const customerId = o.customerId ?? 'c1';
  const draft = await newDraft(world, {
    customerId,
    photographerId: studioId,
    serviceId: `srv_${studioId}`,
    ...(o.day ? { day: o.day } : {}),
    ...(o.start ? { start: o.start } : {}),
  });
  await payDraft(world, draft.id, customerId);
  return transitionBooking(world.deps, { bookingId: draft.id, action: 'accept', actorId: studioId });
}
export function withSpot(world: BookingWorld, spot: Spot): BookingWorld {
  world.store.spots.set(spot.id, { ...spot });
  return world;
}

export function withSchedule(world: BookingWorld, schedule: SpotSchedule): BookingWorld {
  world.store.schedules.set(schedule.id, { ...schedule });
  return world;
}

export function withOffer(world: BookingWorld, offer: SlotOffer): BookingWorld {
  world.store.offers.set(offer.id, { ...offer });
  return world;
}

