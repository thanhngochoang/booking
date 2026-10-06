import { MemoryEarningsStore } from '../../src/memory_earnings_store.js';
import { MemoryPayoutStore } from '../../src/memory_payout_store.js';
import { FakePayoutGateway } from '../../src/fake_payout_gateway.js';
import type { EarningsDeps } from '../../src/earnings_ports.js';
import type { PayoutDeps } from '../../src/payout_ports.js';
import { savePayoutAccount } from '../../src/save_payout_account.js';
import { createBookingDraft } from '../../src/create_booking.js';
import { createDeposit } from '../../src/create_deposit.js';
import { confirmFakePayment } from '../../src/handle_payment.js';
import { transitionBooking } from '../../src/transition_booking.js';
import { createBookingWorld, type BookingWorld } from './booking_world.js';

export const ADMIN = { uid: 'admin1', isAdmin: true } as const;

export interface PayoutWorld extends BookingWorld {
  readonly payoutStore: MemoryPayoutStore;
  readonly earningsStore: MemoryEarningsStore;
  readonly payoutDeps: PayoutDeps;
  readonly earningsDeps: EarningsDeps;
  readonly payGateway: FakePayoutGateway;
}

export function createPayoutWorld(start = new Date('2026-10-10T10:00:00.000Z')): PayoutWorld {
  const base = createBookingWorld(start);
  const payoutStore = new MemoryPayoutStore(base.store);
  payoutStore.seedRole('p1', 'photographer');
  const earningsStore = new MemoryEarningsStore(base.store, payoutStore, new Map([['c1', 'Khách Hàng Một']]));
  const payGateway = new FakePayoutGateway();
  const payoutDeps: PayoutDeps = {
    store: payoutStore,
    cipher: {
      encrypt: async (p) => `enc:${[...p].reverse().join('')}`,
      decrypt: async (e) => [...e.slice(4)].reverse().join(''),
    },
    clock: base.clock,
    ids: base.ids,
    gateway: payGateway,
  };
  return { ...base, payoutStore, earningsStore, payoutDeps, earningsDeps: { store: earningsStore, clock: base.clock }, payGateway };
}

export async function addAccount(w: PayoutWorld, accountNumber = '0123456789'): Promise<void> {
  await savePayoutAccount(w.payoutDeps, { uid: 'p1', authTime: w.clock.now() }, {
    bankCode: 'VCB',
    accountNumber,
    holderName: 'Nguyen Van An',
  });
}

/** An accepted booking of p1 with a paid deposit; returns ids. */
export async function paidBooking(w: PayoutWorld, day: string, start = '14:00'): Promise<{ bookingId: string; paymentId: string }> {
  const draft = await createBookingDraft(w.deps, {
    customerId: 'c1', photographerId: 'p1', serviceId: 'srv_01', day, start, place: { name: 'Nhà thờ Lớn' },
  });
  const dep = await createDeposit(w.deps, { bookingId: draft.id, customerId: 'c1', provider: 'fake' });
  await confirmFakePayment(w.deps, { paymentId: dep.paymentId, customerId: 'c1' });
  await transitionBooking(w.deps, { bookingId: draft.id, action: 'accept', actorId: 'p1' });
  return { bookingId: draft.id, paymentId: dep.paymentId };
}

/** Marks a payment released without running the clock (fixture shortcut). */
export function release(w: PayoutWorld, paymentId: string): void {
  const p = w.store.payments.get(paymentId);
  if (!p) throw new Error('no payment');
  w.store.payments.set(paymentId, { ...p, escrowStatus: 'released', releasedAt: w.clock.now().toISOString() });
}
