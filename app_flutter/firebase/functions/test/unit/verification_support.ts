import {
  FakeIdentityVerifier,
  FakePaymentGateway,
  FakeTaxCodeLookup,
  MemoryNotificationStore,
  MemoryPaymentLookup,
  MemoryPushSender,
  MemoryUserDirectory,
  MemoryVerificationStore,
  emptyVerification,
  type IdentityResult,
  type NotifyDeps,
  type PaymentSource,
  type VerificationDeps,
  type VerificationRecord,
} from '@photobooking/domain';
import { devIdentityVault } from '../../src/infra/identity_vault.js';
import { TEST_CIPHER } from './support/payment_world.js';

/** Where the dev vault and the fake verifier may run (the emulator on a demo-* project). */
export const EMULATOR_ENV = { FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'demo-nag' } as const;
export const PROD_ENV = { GCLOUD_PROJECT: 'photobooking-prod' } as const;

export const NOW = new Date('2026-10-10T10:00:00.000Z');

/**
 * Memory world of the verification use cases with the shipped fakes (fake verifier, dev vault,
 * fake tax codes): p1 individual and s1 studio, both onboarded, unverified, with a contact phone
 * equal to their Auth phone. `feeRequired` (default false, #135's three steps) turns on the #203
 * fee step; the fee runs on #129's fake gateway and a payment lookup over this store.
 */
export function verificationWorld(options: { fakes?: boolean; feeRequired?: boolean } = {}) {
  const fakes = options.fakes ?? true;
  const store = new MemoryVerificationStore();
  const phones = new Map<string, string>();
  const overrides = new Map<string, Partial<IdentityResult>>();
  let now = NOW;
  let n = 0;
  const ids = { newId: () => `01JA${String((n += 1)).padStart(22, '0')}` };
  const clock = { now: () => now };
  for (const [uid, providerType, phone] of [
    ['p1', 'individual', '+84903123456'],
    ['p2', 'individual', '+84903123457'],
    ['s1', 'studio', '+84903999999'],
  ] as const) {
    store.providers.set(uid, { providerType, onboardingComplete: true, verified: false, businessVerified: false });
    store.contacts.set(uid, { phone, phoneVerified: false });
    phones.set(uid, phone);
  }
  store.contacts.set('c1', { phone: '+84901111111', phoneVerified: true });

  const gateway = new FakePaymentGateway();
  const deps: VerificationDeps = {
    store,
    authPhones: { verifiedPhoneOf: async (uid) => phones.get(uid) ?? null },
    identity: fakes
      ? new FakeIdentityVerifier(async (uid) => ({ displayName: `Thợ ${uid}`, ...(overrides.get(uid) ?? {}) }), ids)
      : null,
    vault: fakes ? devIdentityVault(EMULATOR_ENV) : null,
    taxCodes: fakes ? new FakeTaxCodeLookup() : null,
    feeRequired: options.feeRequired ?? false,
    gateway,
    payments: new MemoryPaymentLookup([store]),
    cipher: TEST_CIPHER,
    clock,
    ids,
  };

  const notifyStore = new MemoryNotificationStore();
  const users = new MemoryUserDirectory();
  for (const uid of ['p1', 'p2', 's1']) users.users.set(uid, { name: uid, avatarUrl: null });
  const notify: NotifyDeps = {
    store: notifyStore,
    push: new MemoryPushSender(),
    users,
    clock,
    onPushError: () => {},
  };

  return {
    deps,
    store,
    gateway,
    phones,
    overrides,
    notify,
    notifyStore,
    setNow: (d: Date) => {
      now = d;
    },
  };
}

/** The #203 payment deps of a hand-built VerificationDeps: fake gateway, lookup over `sources`, test cipher. */
export function feeDepsOf(...sources: PaymentSource[]): Pick<VerificationDeps, 'gateway' | 'payments' | 'cipher'> {
  return { gateway: new FakePaymentGateway(), payments: new MemoryPaymentLookup(sources), cipher: TEST_CIPHER };
}

/** A record with every #135 step done, in `status` (default submitted). */
export function readyRecord(uid: string, over: Partial<VerificationRecord> = {}): VerificationRecord {
  const at = NOW.toISOString();
  const base = emptyVerification(uid, uid.startsWith('s') ? 'studio' : 'individual', NOW);
  return {
    ...base,
    status: 'submitted',
    steps: {
      phone: { doneAt: at },
      fee: null,
      identity: { method: 'vneid', checkedAt: at, result: 'passed', failure: null, maskedName: 'THO P**' },
      rules: { acceptedAt: at, version: '2026-10-06' },
    },
    submittedAt: at,
    ...over,
  };
}
