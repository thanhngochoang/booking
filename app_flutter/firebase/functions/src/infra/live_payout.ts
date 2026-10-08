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
  type NotifyDeps,
  type PayoutAccountDeps,
  type PayoutDeps,
  type PayoutGateway,
  type PayoutNotices,
  type VerifiedNameReader,
} from '@photobooking/domain';
import { PAYOUT_ACCOUNT_KEY } from '../config.js';
import { aesGcmCipher } from './account_cipher.js';
import { db } from './admin.js';
import { FirestoreEarningsStore } from './earnings_firestore.js';
import { fakePayoutsMode } from './fake_payments.js';
import { liveNotifyDeps } from './live_notification.js';
import { FirestorePhotographerPhoneReader, nodeOtpCrypto, otpSender } from './otp.js';
import { FirestoreVerifiedNameReader, accountNameLookup, lookupMode } from './payout_lookup.js';
import { FirestorePayoutStore } from './payout_firestore.js';

/** A log-safe code for an error: the domain code, else the error's class name; never its message. */
export function errorCodeOf(e: unknown): string {
  return isDomainError(e) ? e.code : e instanceof Error ? e.name : 'unknown';
}

/** #138's hooks for the two payout notices (S17 owns their copy, dedupe and target). */
export interface PayoutNoticeHooks {
  readonly needed: typeof notifyPayoutAccountNeeded;
  readonly changed: typeof notifyPayoutAccountChanged;
}

/**
 * The payout notices through #138's hooks (this plan is their only emitter). A failure is logged
 * by its code only and never thrown: a notice never fails a payout run or an account save.
 */
export function livePayoutNotices(
  hooks: PayoutNoticeHooks = { needed: notifyPayoutAccountNeeded, changed: notifyPayoutAccountChanged },
  notifyDeps: () => NotifyDeps = liveNotifyDeps,
): PayoutNotices {
  const logged = async (what: string, run: () => Promise<unknown>): Promise<void> => {
    try {
      await run();
    } catch (e) {
      logger.error('payout notice failed', { what, code: errorCodeOf(e) });
    }
  };
  return {
    accountNeeded: (payeeId, amount) =>
      logged('payout_account_needed', () => hooks.needed(notifyDeps(), { payeeId, amount })),
    accountChanged: (uid, v) =>
      logged('payout_account_changed', () =>
        hooks.changed(notifyDeps(), {
          uid,
          accountId: v.accountId,
          bankCode: v.bankCode,
          accountLast4: v.accountLast4,
          activeFrom: v.activeFrom,
        }),
      ),
  };
}

/** The payout gateway: the reference adapter in fake mode; otherwise one that refuses (no real bank adapter exists). */
export function payoutGateway(mode: 'fake' | 'off' = fakePayoutsMode()): PayoutGateway {
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

/**
 * Callable wiring for the caller `uid` (`lookupPayoutAccountName`, `requestPayoutOtp`,
 * `savePayoutAccount`). The key is read lazily, so only a function that binds the secret can
 * decrypt or encrypt. The caller's verified name is read at most once per call, and only when the
 * use case asks for it (after its role and quota transaction, Ruling 5): the fake lookup echoes it.
 */
export function livePayoutAccountDeps(uid: string, mode: 'fake' | 'off' = lookupMode()): PayoutAccountDeps {
  let cipher: AccountCipher | undefined;
  const lazy: AccountCipher = {
    encrypt: (plain) => (cipher ??= aesGcmCipher(PAYOUT_ACCOUNT_KEY.value())).encrypt(plain),
    decrypt: (enc) => (cipher ??= aesGcmCipher(PAYOUT_ACCOUNT_KEY.value())).decrypt(enc),
  };
  const firestore = db();
  const reader = new FirestoreVerifiedNameReader(firestore);
  const read = new Map<string, Promise<string | null>>();
  const names: VerifiedNameReader = {
    legalName: (who) => {
      let name = read.get(who);
      if (name === undefined) {
        name = reader.legalName(who);
        read.set(who, name);
      }
      return name;
    },
  };
  return {
    store: new FirestorePayoutStore(firestore),
    cipher: lazy,
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
    lookup: {
      lookup: async (r) => accountNameLookup(mode, mode === 'fake' ? await names.legalName(uid) : null).lookup(r),
    },
    names,
    otp: {
      sender: otpSender(process.env, uid),
      phones: new FirestorePhotographerPhoneReader(firestore),
      crypto: nodeOtpCrypto,
    },
    notices: livePayoutNotices(),
  };
}

/**
 * Staff CLI and `createPayouts` wiring: the key comes from the caller (the CLI: environment or
 * `.secret.local`; the job: the bound `PAYOUT_ACCOUNT_KEY` secret).
 */
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
