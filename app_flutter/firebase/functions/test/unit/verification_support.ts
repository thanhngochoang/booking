import {
  FakeIdentityVerifier,
  FakeTaxCodeLookup,
  MemoryNotificationStore,
  MemoryPushSender,
  MemoryUserDirectory,
  MemoryVerificationStore,
  emptyVerification,
  type IdentityResult,
  type NotifyDeps,
  type VerificationDeps,
  type VerificationRecord,
} from '@photobooking/domain';
import { devIdentityVault } from '../../src/infra/identity_vault.js';

/** Where the dev vault and the fake verifier may run (the emulator on a demo-* project). */
export const EMULATOR_ENV = { FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'demo-nag' } as const;
export const PROD_ENV = { GCLOUD_PROJECT: 'photobooking-prod' } as const;

export const NOW = new Date('2026-10-10T10:00:00.000Z');

/**
 * Memory world of the verification use cases with the shipped fakes (fake verifier, dev vault,
 * fake tax codes): p1 individual and s1 studio, both onboarded, unverified, with a contact phone
 * equal to their Auth phone.
 */
export function verificationWorld(options: { fakes?: boolean } = {}) {
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

  const deps: VerificationDeps = {
    store,
    authPhones: { verifiedPhoneOf: async (uid) => phones.get(uid) ?? null },
    identity: fakes
      ? new FakeIdentityVerifier(async (uid) => ({ displayName: `Thợ ${uid}`, ...(overrides.get(uid) ?? {}) }), ids)
      : null,
    vault: fakes ? devIdentityVault(EMULATOR_ENV) : null,
    taxCodes: fakes ? new FakeTaxCodeLookup() : null,
    feeRequired: false,
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
    phones,
    overrides,
    notify,
    notifyStore,
    setNow: (d: Date) => {
      now = d;
    },
  };
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
