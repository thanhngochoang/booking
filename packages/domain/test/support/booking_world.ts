import { MemoryBookingStore } from '../../src/memory_booking_store.js';
import { FakePaymentGateway } from '../../src/fake_payment_gateway.js';
import type { BookingDeps, CustomerContactReader, ServiceCatalog, ServiceRecord } from '../../src/booking_ports.js';
import type { Clock, IdGenerator } from '../../src/ports.js';

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
  readonly clock: ControllableClock;
  readonly ids: SequentialIdGen;
  readonly services: Map<string, ServiceRecord>;
  readonly contacts: Map<string, { phone: string; allowZalo?: boolean; allowWhatsApp?: boolean; name?: string }>;
}

export function createBookingWorld(initialDate = new Date('2026-10-10T10:00:00.000Z')): BookingWorld {
  const store = new MemoryBookingStore();
  const gateway = new FakePaymentGateway();
  const clock = new ControllableClock(initialDate);
  const ids = new SequentialIdGen();

  const services = new Map<string, ServiceRecord>();
  const contacts = new Map<string, { phone: string; allowZalo?: boolean; allowWhatsApp?: boolean; name?: string }>();

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
    contacts: contactReader,
    gateway,
    clock,
    ids,
  };

  return { deps, store, gateway, clock, ids, services, contacts };
}
