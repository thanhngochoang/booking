import { MemoryBookingStore } from '../../src/memory_booking_store.js';
import { FakePaymentGateway } from '../../src/fake_payment_gateway.js';
import { FakeBlockGate } from '../../src/fake_block_gate.js';
import type { BookingDeps, CustomerContactReader, ServiceCatalog, ServiceRecord } from '../../src/booking_ports.js';
import { acceptsOrders, type OrderEligibilityFields } from '../../src/provider_orders.js';
import type { Clock, IdGenerator } from '../../src/ports.js';
import type { Booking } from '../../src/booking.js';
import type { TransferNotification } from '../../src/booking_ports.js';
import { createBookingDraft } from '../../src/create_booking.js';
import { createPayment } from '../../src/create_payment.js';
import { handleTransferNotification } from '../../src/handle_transfer.js';
import { TEST_CIPHER } from './test_cipher.js';

export const TEST_PAYER: NonNullable<TransferNotification['payer']> = {
  bankCode: 'VCB',
  accountNumber: '0071000123456',
  name: 'NGUYEN THANH HA',
  accountMasked: '•••• 3456',
} as const;

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
  readonly store: MemoryBookingStore;
  readonly gateway: FakePaymentGateway;
  readonly blocks: FakeBlockGate;
  readonly clock: ControllableClock;
  readonly ids: SequentialIdGen;
  readonly services: Map<string, ServiceRecord>;
  readonly providers: Map<string, OrderEligibilityFields>;
  readonly contacts: Map<string, { phone: string; allowZalo?: boolean; allowWhatsApp?: boolean; name?: string }>;
}

export function createBookingWorld(initialDate = new Date('2026-10-10T10:00:00.000Z')): BookingWorld {
  const store = new MemoryBookingStore();
  const gateway = new FakePaymentGateway();
  const blocks = new FakeBlockGate();
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

  const deps: BookingDeps = {
    store,
    services: serviceCatalog,
    providers: { acceptsOrders: async (id) => acceptsOrders(providers.get(id)) },
    blocks,
    contacts: contactReader,
    gateway,
    cipher: TEST_CIPHER,
    clock,
    ids,
  };

  return { deps, store, gateway, blocks, clock, ids, services, providers, contacts };
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
