import type { TestContext } from 'node:test';
import {
  createBookingDraft,
  createPayment,
  FakePaymentGateway,
  MemoryBookingStore,
  type BookingDeps,
  type CustomerContactRecord,
  type ServiceRecord,
} from '@photobooking/domain';

/** Fake payments and the fake webhook run on the emulator (or the dev project) only. Test secret. */
export const WEBHOOK_ENV = {
  FUNCTIONS_EMULATOR: 'true',
  GCLOUD_PROJECT: 'demo-nag',
  FAKE_PAYMENT_WEBHOOK_SECRET: 'unit-test-webhook-secret',
} as const;
export const PROD_ENV = { GCLOUD_PROJECT: 'booking-prod-1', FAKE_PAYMENT_WEBHOOK_SECRET: 'unit-test-webhook-secret' } as const;
export const SECRET = WEBHOOK_ENV.FAKE_PAYMENT_WEBHOOK_SECRET;

export interface PaymentWorld {
  readonly deps: BookingDeps;
  readonly store: MemoryBookingStore;
  readonly gateway: FakePaymentGateway;
  /** Moves the clock forward. */
  advanceMinutes(minutes: number): void;
}

/** p1 sells `svc1` (1 000 000 VND); c1 and c2 have phones. */
export function paymentWorld(start = new Date('2026-10-01T10:00:00.000Z')): PaymentWorld {
  const store = new MemoryBookingStore();
  const gateway = new FakePaymentGateway();
  let now = start.getTime();
  let n = 0;
  const services = new Map<string, ServiceRecord>([
    ['svc1', { id: 'svc1', photographerId: 'p1', name: 'Gói chụp chân dung', price: 1_000_000, durationMinutes: 120, active: true }],
  ]);
  const contacts = new Map<string, CustomerContactRecord>([
    ['c1', { name: 'Nguyễn Văn A', phone: '+84903123456', allowZalo: true, allowWhatsApp: false }],
    ['c2', { name: 'Trần Thị B', phone: '+84903654321', allowZalo: false, allowWhatsApp: false }],
  ]);
  const deps: BookingDeps = {
    store,
    services: { getService: async (photographerId, id) => {
      const s = services.get(id);
      return s === undefined ? null : { ...s, photographerId };
    } },
    contacts: { get: async (uid) => contacts.get(uid) ?? null },
    providers: { acceptsOrders: async () => true },
    gateway,
    clock: { now: () => new Date(now) },
    ids: { newId: () => `id_${String(++n).padStart(4, '0')}` },
  };
  return { deps, store, gateway, advanceMinutes: (m) => { now += m * 60_000; } };
}

/** A draft of c1 (or `customerId`) on `day` and its first bank-QR payment. */
export async function openPayment(
  w: PaymentWorld,
  day = '2026-10-15',
  customerId = 'c1',
): Promise<{ bookingId: string; paymentId: string; transferCode: string; amount: number }> {
  const draft = await createBookingDraft(w.deps, {
    customerId,
    photographerId: 'p1',
    serviceId: 'svc1',
    day,
    start: '09:00',
    place: { name: 'Thảo Cầm Viên' },
  });
  const { paymentId, checkout } = await createPayment(w.deps, { bookingId: draft.id, customerId, method: 'bank_qr' });
  return { bookingId: draft.id, paymentId, transferCode: checkout.transferCode, amount: checkout.amount };
}

/** Every line the Functions logger writes while `fn` runs. */
export async function captureLogs(t: TestContext, fn: () => Promise<unknown>): Promise<string[]> {
  const lines: string[] = [];
  const capture = (chunk: unknown): boolean => {
    lines.push(String(chunk));
    return true;
  };
  t.mock.method(process.stdout, 'write', capture);
  t.mock.method(process.stderr, 'write', capture);
  try {
    await fn();
  } finally {
    t.mock.restoreAll();
  }
  return lines;
}
