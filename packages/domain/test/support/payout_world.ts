import { createHash } from 'node:crypto';
import { MemoryEarningsStore } from '../../src/memory_earnings_store.js';
import { MemoryPayoutStore } from '../../src/memory_payout_store.js';
import { FakePayoutGateway } from '../../src/fake_payout_gateway.js';
import { FakeAccountNameLookup, type OtpCrypto } from '../../src/account_lookup.js';
import { FakeOtpSender } from '../../src/fake_otp_sender.js';
import type { EarningsDeps } from '../../src/earnings_ports.js';
import type { PayoutAccountDeps, PayoutDeps, PayoutNotices } from '../../src/payout_ports.js';
import type { NameStatus, PayoutAccount } from '../../src/payout_account.js';
import { requestPayoutOtp } from '../../src/payout_account_use_cases.js';
import { OTP_RESEND_SECONDS } from '../../src/payout_otp.js';
import { savePayoutAccount } from '../../src/save_payout_account.js';
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

/**
 * Deterministic OTP crypto for tests: real SHA-256 (node:crypto, test support only — never in
 * `src/`) and a counter-seeded byte stream instead of a CSPRNG.
 */
export class TestOtpCrypto implements OtpCrypto {
  private counter = 0;

  async sha256Hex(input: string): Promise<string> {
    return createHash('sha256').update(input, 'utf8').digest('hex');
  }

  random(n: number): Uint8Array {
    const out = new Uint8Array(n);
    let filled = 0;
    while (filled < n) {
      this.counter += 1;
      const block = createHash('sha256').update(`otp-test-${this.counter}`).digest();
      const take = Math.min(block.length, n - filled);
      out.set(block.subarray(0, take), filled);
      filled += take;
    }
    return out;
  }
}

export interface PayoutWorld extends BookingWorld {
  readonly payoutStore: MemoryPayoutStore;
  readonly earningsStore: MemoryEarningsStore;
  /** Staff/daily payout deps and p1's account deps in one object. */
  readonly payoutDeps: PayoutDeps & PayoutAccountDeps;
  /** p1's account deps (the fake lookup echoes p1's verified name). */
  readonly accountDeps: PayoutAccountDeps;
  readonly earningsDeps: EarningsDeps;
  readonly payGateway: FakePayoutGateway;
  readonly notices: RecordingPayoutNotices;
  /** uid → verified legal name (`users/{uid}/private/identity.legalName`). */
  readonly names: Map<string, string>;
  /** uid → phone (`photographers/{uid}/private/contact.phone`). */
  readonly phones: Map<string, string>;
  readonly otpSender: FakeOtpSender;
  readonly otpCrypto: TestOtpCrypto;
}

/** p1 is a photographer named Nguyễn Văn An with phone 0912345678 (test values). */
export function createPayoutWorld(start = new Date('2026-10-10T10:00:00.000Z')): PayoutWorld {
  const base = createBookingWorld(start);
  const payoutStore = new MemoryPayoutStore(base.store);
  payoutStore.seedRole('p1', 'photographer');
  const earningsStore = new MemoryEarningsStore(base.store, payoutStore, new Map([['c1', 'Khách Hàng Một']]));
  const payGateway = new FakePayoutGateway();
  const notices = new RecordingPayoutNotices();
  const names = new Map([['p1', 'Nguyễn Văn An']]);
  const phones = new Map([['p1', '0912345678']]);
  const otpSender = new FakeOtpSender();
  const otpCrypto = new TestOtpCrypto();
  const payoutDeps: PayoutDeps & PayoutAccountDeps = {
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
    lookup: echoLookup(names, 'p1'),
    names: { legalName: async (uid) => names.get(uid) ?? null },
    otp: { sender: otpSender, phones: { phoneOf: async (uid) => phones.get(uid) ?? null }, crypto: otpCrypto },
  };
  return {
    ...base,
    payoutStore,
    earningsStore,
    payoutDeps,
    accountDeps: payoutDeps,
    earningsDeps: { store: earningsStore, clock: base.clock, policy: DEFAULT_PAYOUT_POLICY },
    payGateway,
    notices,
    names,
    phones,
    otpSender,
    otpCrypto,
  };
}

/** The fake lookup for `uid`, echoing their verified name as it is when the lookup runs. */
function echoLookup(names: Map<string, string>, uid: string): PayoutAccountDeps['lookup'] {
  return { lookup: (r) => new FakeAccountNameLookup(names.get(uid) ?? null).lookup(r) };
}

/** Account deps for another photographer (the live adapter is also built per caller). */
export function accountDepsFor(w: PayoutWorld, uid: string): PayoutAccountDeps {
  return { ...w.accountDeps, lookup: echoLookup(w.names, uid) };
}

/** Requests an OTP for this target and returns the code the fake sender got. */
export async function otpFor(
  w: PayoutWorld,
  target: { bankCode: string; accountNumber: string },
  uid = 'p1',
): Promise<string> {
  await requestPayoutOtp(accountDepsFor(w, uid), { uid }, target);
  const last = w.otpSender.sent.at(-1);
  if (last === undefined) throw new Error('no otp sent');
  return last.code;
}

/**
 * Fixtures must not hit the OTP and lookup limits for fixture reasons: wait out the 60 s resend
 * (moves the clock), and forget today's sends and lookups (store shortcut).
 */
function clearFixtureLimits(w: PayoutWorld, uid: string): void {
  const challenge = w.payoutStore.otpChallenges.get(uid);
  if (challenge !== undefined) {
    const wait = Date.parse(challenge.sentAt) + OTP_RESEND_SECONDS * 1000 - w.clock.now().getTime();
    if (wait > 0) w.clock.setTime(new Date(w.clock.now().getTime() + wait));
    w.payoutStore.otpChallenges.set(uid, { ...challenge, sendsToday: 0 });
  }
  w.payoutStore.lookupQuotas.delete(uid);
}

/**
 * Adds (or changes to) a VCB account through `savePayoutAccount` v2, with an OTP when the user
 * already has one (after `clearFixtureLimits`). The user is made a photographer with a verified
 * name and a phone if needed.
 * `nameStatus` / `activeFrom` are fixture overrides written on the saved account and its view
 * afterwards (e.g. a `pending_review` account, or one still inside the 72 hours).
 */
export async function addAccount(
  w: PayoutWorld,
  accountNumber = '0123456789',
  opts: { uid?: string; nameStatus?: NameStatus; activeFrom?: string } = {},
): Promise<PayoutAccount> {
  const uid = opts.uid ?? 'p1';
  if (!w.payoutStore.roles.has(uid)) w.payoutStore.seedRole(uid, 'photographer');
  if (!w.names.has(uid)) w.names.set(uid, 'Nguyễn Văn An');
  if (!w.phones.has(uid)) w.phones.set(uid, '0912345678');
  const target = { bankCode: 'VCB', accountNumber };
  const hasCurrent = [...w.payoutStore.accounts.values()].some((a) => a.userId === uid && a.active);
  clearFixtureLimits(w, uid);
  const input = hasCurrent ? { ...target, otpCode: await otpFor(w, target, uid) } : target;
  const saved = await savePayoutAccount(accountDepsFor(w, uid), { uid }, input);
  const key = `${uid}/${saved.accountId}`;
  const stored = w.payoutStore.accounts.get(key);
  if (stored === undefined) throw new Error('account not saved');
  const account: PayoutAccount = {
    ...stored,
    ...(opts.nameStatus === undefined ? {} : { nameStatus: opts.nameStatus }),
    ...(opts.activeFrom === undefined ? {} : { activeFrom: opts.activeFrom }),
  };
  w.payoutStore.accounts.set(key, account);
  const view = w.payoutStore.accountViews.get(uid);
  if (view !== undefined) {
    w.payoutStore.accountViews.set(uid, { ...view, nameStatus: account.nameStatus, activeFrom: account.activeFrom });
  }
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
