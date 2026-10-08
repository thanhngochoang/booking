import * as logger from 'firebase-functions/logger';
import {
  DEFAULT_PAYOUT_POLICY,
  FakePayoutGateway,
  DomainError,
  isDomainError,
  newUlid,
  notifyPayoutAccountChanged,
  notifyPayoutAccountNeeded,
  type AccountCipher,
  type EarningsDeps,
  type PayoutAccountDeps,
  type PayoutDeps,
  type PayoutGateway,
  type PayoutNotices,
} from '@photobooking/domain';
import { PAYOUT_ACCOUNT_KEY, payoutsMode } from '../config.js';
import { aesGcmCipher } from './account_cipher.js';
import { db } from './admin.js';
import { FirestoreEarningsStore } from './earnings_firestore.js';
import { liveNotifyDeps } from './live_notification.js';
import { FirestorePayoutStore } from './payout_firestore.js';

/** The payout notices through #138's hooks; a failure is logged by code only and never thrown. */
export function livePayoutNotices(): PayoutNotices {
  const logged = async (what: string, run: () => Promise<unknown>): Promise<void> => {
    try {
      await run();
    } catch (e) {
      logger.error('payout notice failed', { what, code: isDomainError(e) ? e.code : e instanceof Error ? e.name : 'unknown' });
    }
  };
  return {
    accountNeeded: (payeeId, amount) =>
      logged('payout_account_needed', () => notifyPayoutAccountNeeded(liveNotifyDeps(), { payeeId, amount })),
    accountChanged: (uid, v) =>
      logged('payout_account_changed', () => notifyPayoutAccountChanged(liveNotifyDeps(), { uid, ...v })),
  };
}

/** The payout gateway: the reference adapter in fake mode; otherwise one that refuses (no real bank adapter exists). */
export function payoutGateway(mode: 'fake' | 'off' = payoutsMode()): PayoutGateway {
  if (mode === 'fake') return sharedFake();
  return {
    transfer: async () => {
      throw new DomainError('not_eligible');
    },
  };
}

let fake: FakePayoutGateway | undefined;
function sharedFake(): FakePayoutGateway {
  fake ??= new FakePayoutGateway();
  return fake;
}

/** Callable wiring; the key is read lazily, so only a function that binds the secret can call it. */
export function livePayoutAccountDeps(): PayoutAccountDeps {
  let cipher: AccountCipher | undefined;
  const lazy: AccountCipher = {
    encrypt: (plain) => (cipher ??= aesGcmCipher(PAYOUT_ACCOUNT_KEY.value())).encrypt(plain),
    decrypt: (enc) => (cipher ??= aesGcmCipher(PAYOUT_ACCOUNT_KEY.value())).decrypt(enc),
  };
  const notWired = async (): Promise<never> => {
    throw new DomainError('not_eligible');
  };
  return {
    store: new FirestorePayoutStore(db()),
    cipher: lazy,
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
    // Fail closed until #134 Task 5 wires the fake lookup, the identity reader, the OTP adapters
    // and the payout_lookups quota: a save stops at the quota stub (internal), and even past it no
    // verified name + an unsupported lookup would be refused (not_eligible).
    lookup: { lookup: async () => ({ status: 'unsupported' }) },
    names: { legalName: async () => null },
    otp: {
      sender: { send: notWired },
      phones: { phoneOf: async () => null },
      crypto: { sha256Hex: notWired, random: () => { throw new DomainError('not_eligible'); } },
    },
    notices: livePayoutNotices(),
  };
}

/** Staff CLI wiring: the key comes from the caller (environment or `.secret.local`). */
export function livePayoutDeps(keyB64: string, gateway: PayoutGateway = payoutGateway()): PayoutDeps {
  return {
    store: new FirestorePayoutStore(db()),
    cipher: aesGcmCipher(keyB64),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
    gateway,
    policy: DEFAULT_PAYOUT_POLICY,
    notices: livePayoutNotices(),
  };
}

export function liveEarningsDeps(): EarningsDeps {
  return { store: new FirestoreEarningsStore(db()), clock: { now: () => new Date() }, policy: DEFAULT_PAYOUT_POLICY };
}
