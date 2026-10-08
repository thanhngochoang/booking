import { MemoryEarningsStore } from '../../src/memory_earnings_store.js';
import { MemoryPayoutStore } from '../../src/memory_payout_store.js';
import { FakePayoutGateway } from '../../src/fake_payout_gateway.js';
import type { EarningsDeps } from '../../src/earnings_ports.js';
import type { PayoutDeps, PayoutNotices } from '../../src/payout_ports.js';
import { accountLast4, type NameStatus, type PayoutAccount } from '../../src/payout_account.js';
import type { Payout } from '../../src/payout.js';
import { DEFAULT_PAYOUT_POLICY } from '../../src/payout_policy.js';
import { createBookingDraft } from '../../src/create_booking.js';
import { transitionBooking } from '../../src/transition_booking.js';
import { createBookingWorld, payDraft, type BookingWorld } from './booking_world.js';

export const ADMIN = { uid: 'admin1', isAdmin: true } as const;

/** Records every notice the payout use cases send. */
export class RecordingPayoutNotices implements PayoutNotices {
  readonly needed: { payeeId: string; amount: number }[] = [];
  readonly changed: { uid: string; accountId: string; bankCode: string; accountLast4: string; activeFrom: string }[] = [];

  async accountNeeded(payeeId: string, amount: number): Promise<void> {
    this.needed.push({ payeeId, amount });
  }

  async accountChanged(
    uid: string,
    v: { accountId: string; bankCode: string; accountLast4: string; activeFrom: string },
  ): Promise<void> {
    this.changed.push({ uid, ...v });
  }
}

export interface PayoutWorld extends BookingWorld {
  readonly payoutStore: MemoryPayoutStore;
  readonly earningsStore: MemoryEarningsStore;
  readonly payoutDeps: PayoutDeps;
  readonly earningsDeps: EarningsDeps;
  readonly payGateway: FakePayoutGateway;
  readonly notices: RecordingPayoutNotices;
}

export function createPayoutWorld(start = new Date('2026-10-10T10:00:00.000Z')): PayoutWorld {
  const base = createBookingWorld(start);
  const payoutStore = new MemoryPayoutStore(base.store);
  payoutStore.seedRole('p1', 'photographer');
  const earningsStore = new MemoryEarningsStore(base.store, payoutStore, new Map([['c1', 'Khách Hàng Một']]));
  const payGateway = new FakePayoutGateway();
  const notices = new RecordingPayoutNotices();
  const payoutDeps: PayoutDeps = {
    store: payoutStore,
    cipher: {
      encrypt: async (p) => `enc:${[...p].reverse().join('')}`,
      decrypt: async (e) => [...e.slice(4)].reverse().join(''),
    },
    clock: base.clock,
    ids: base.ids,
    gateway: payGateway,
    policy: DEFAULT_PAYOUT_POLICY,
    notices,
  };
  return {
    ...base,
    payoutStore,
    earningsStore,
    payoutDeps,
    earningsDeps: { store: earningsStore, clock: base.clock, policy: DEFAULT_PAYOUT_POLICY },
    payGateway,
    notices,
  };
}

/**
 * Writes an active account (and its owner view) straight into the memory store, replacing the
 * user's current one. Until Task 3's savePayoutAccount v2: `nameStatus` 'matched', active from now.
 */
export async function addAccount(
  w: PayoutWorld,
  accountNumber = '0123456789',
  opts: { uid?: string; nameStatus?: NameStatus; activeFrom?: string } = {},
): Promise<PayoutAccount> {
  const uid = opts.uid ?? 'p1';
  const at = w.clock.now().toISOString();
  for (const [key, a] of w.payoutStore.accounts) {
    if (a.userId === uid && a.active) w.payoutStore.accounts.set(key, { ...a, active: false, deactivatedAt: at });
  }
  const account: PayoutAccount = {
    id: w.ids.newId(),
    userId: uid,
    bankCode: 'VCB',
    accountNumberEnc: await w.payoutDeps.cipher.encrypt(accountNumber),
    accountLast4: accountLast4(accountNumber),
    holderName: 'NGUYEN VAN AN',
    active: true,
    createdAt: at,
    nameStatus: opts.nameStatus ?? 'matched',
    activeFrom: opts.activeFrom ?? at,
  };
  w.payoutStore.accounts.set(`${uid}/${account.id}`, account);
  w.payoutStore.accountViews.set(uid, {
    accountId: account.id,
    bankCode: account.bankCode,
    accountLast4: account.accountLast4,
    holderName: account.holderName,
    updatedAt: at,
    nameStatus: account.nameStatus,
    activeFrom: account.activeFrom,
  });
  return account;
}

/** Seeds an earlier payout to the account (default `paid`), so the next one is not the first. */
export function payoutHistory(w: PayoutWorld, account: PayoutAccount, status: Payout['status'] = 'paid'): Payout {
  w.clock.advanceMinutes(1);
  const at = w.clock.now().toISOString();
  const p: Payout = {
    id: w.ids.newId(),
    payeeId: account.userId,
    accountId: account.id,
    amount: 100_000,
    status,
    items: [{ paymentId: `old_${at}`, amount: 100_000, fee: 0, tax: 7_000, net: 93_000 }],
    platformFee: 0,
    taxWithheld: 7_000,
    amountNet: 93_000,
    feeRateBp: 0,
    taxRateBp: 700,
    firstPayout: false,
    createdBy: ADMIN.uid,
    createdAt: at,
    updatedAt: at,
    ...(status === 'paid' ? { paidAt: at } : {}),
    ...(status === 'failed' ? { failureReason: 'account_rejected' } : {}),
  };
  w.payoutStore.seedPayout(p);
  return p;
}

/** An accepted booking of p1 with a paid deposit; returns ids. */
export async function paidBooking(w: PayoutWorld, day: string, start = '14:00'): Promise<{ bookingId: string; paymentId: string }> {
  const draft = await createBookingDraft(w.deps, {
    customerId: 'c1', photographerId: 'p1', serviceId: 'srv_01', day, start, place: { name: 'Nhà thờ Lớn' },
  });
  const dep = await payDraft(w, draft.id);
  await transitionBooking(w.deps, { bookingId: draft.id, action: 'accept', actorId: 'p1' });
  return { bookingId: draft.id, paymentId: dep.paymentId };
}

/** Marks a payment released without running the clock (fixture shortcut). */
export function release(w: PayoutWorld, paymentId: string): void {
  const p = w.store.payments.get(paymentId);
  if (!p) throw new Error('no payment');
  w.store.payments.set(paymentId, { ...p, escrowStatus: 'released', releasedAt: w.clock.now().toISOString() });
}

/** A released payment of `amount` owed to `payeeId` (a p1 booking payment re-pointed; fixture shortcut). */
export async function releasedFor(w: PayoutWorld, day: string, payeeId = 'p1', amount?: number): Promise<string> {
  const b = await paidBooking(w, day);
  release(w, b.paymentId);
  const p = w.store.payments.get(b.paymentId);
  if (!p) throw new Error('no payment');
  w.store.payments.set(b.paymentId, { ...p, payeeId, ...(amount === undefined ? {} : { amount }) });
  return b.paymentId;
}
