import {
  FakePayoutGateway,
  DomainError,
  newUlid,
  type AccountCipher,
  type EarningsDeps,
  type PayoutAccountDeps,
  type PayoutDeps,
  type PayoutGateway,
} from '@photobooking/domain';
import { PAYOUT_ACCOUNT_KEY, payoutsMode } from '../config.js';
import { aesGcmCipher } from './account_cipher.js';
import { db } from './admin.js';
import { FirestoreEarningsStore } from './earnings_firestore.js';
import { FirestorePayoutStore } from './payout_firestore.js';

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
  return {
    store: new FirestorePayoutStore(db()),
    cipher: lazy,
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
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
  };
}

export function liveEarningsDeps(): EarningsDeps {
  return { store: new FirestoreEarningsStore(db()), clock: { now: () => new Date() } };
}
