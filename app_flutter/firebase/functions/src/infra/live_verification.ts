import type { DocumentData, Firestore } from 'firebase-admin/firestore';
import {
  FakeIdentityVerifier,
  FakeTaxCodeLookup,
  newUlid,
  type IdentityResult,
  type VerificationDeps,
} from '@photobooking/domain';
import type { VerificationCallableDeps } from '../callables/verification.js';
import type { BusinessDocPurgeDeps } from '../scheduled/award_purge.js';
import { db } from './admin.js';
import { deleteStorageFiles } from './live_award.js';
import { fakePaymentsAllowed } from './fake_payments.js';
import { devIdentityVault } from './identity_vault.js';
import { liveNotifyDeps } from './live_notification.js';
import {
  FAKE_IDENTITIES_COLLECTION,
  FirestoreVerificationStore,
  adminAuthPhoneReader,
} from './verification_firestore.js';

type Env = Readonly<Record<string, string | undefined>>;
type FakeIdentitySource = Partial<IdentityResult> & { displayName?: string };

/** The typed fields of a `fake_identities/{uid}` override (written by the seed or the Emulator UI). */
export function fakeIdentityOverrideOf(d: DocumentData | undefined): Partial<IdentityResult> {
  if (d === undefined) return {};
  const out: { -readonly [K in keyof IdentityResult]?: IdentityResult[K] } = {};
  if (typeof d.legalName === 'string' && d.legalName.trim() !== '') out.legalName = d.legalName.trim();
  if (typeof d.dob === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(d.dob)) out.dob = d.dob;
  if (d.gender === 'male' || d.gender === 'female' || d.gender === null) out.gender = d.gender;
  if (typeof d.idNumber === 'string' && /^\d{12}$/.test(d.idNumber)) out.idNumber = d.idNumber;
  if (typeof d.passed === 'boolean') out.passed = d.passed;
  return out;
}

/** Override fields plus the display name the fake derives a legal name from (Decision 6). */
export async function readFakeIdentity(firestore: Firestore, uid: string): Promise<FakeIdentitySource> {
  const [override, user] = await firestore.getAll(
    firestore.collection(FAKE_IDENTITIES_COLLECTION).doc(uid),
    firestore.collection('users').doc(uid),
  );
  const displayName: unknown = user?.data()?.displayName;
  return {
    ...(typeof displayName === 'string' && displayName.trim() !== '' ? { displayName } : {}),
    ...fakeIdentityOverrideOf(override?.data()),
  };
}

/**
 * Identity, vault and tax-code lookup exist only where fake payments are allowed (the emulator on
 * `demo-*`, the dev project); elsewhere they are null and the use cases answer `not_eligible`.
 * `feeRequired` stays false until #203 (Decision 24).
 */
export function liveVerificationDeps(env: Env = process.env): VerificationDeps {
  const firestore = db();
  const ids = { newId: () => newUlid(Date.now()) };
  const fake = fakePaymentsAllowed(env);
  return {
    store: new FirestoreVerificationStore(firestore),
    authPhones: adminAuthPhoneReader(),
    identity: fake ? new FakeIdentityVerifier((uid) => readFakeIdentity(firestore, uid), ids) : null,
    vault: fake ? devIdentityVault(env) : null,
    taxCodes: fake ? new FakeTaxCodeLookup() : null,
    feeRequired: false,
    clock: { now: () => new Date() },
    ids,
  };
}

export function liveVerificationCallableDeps(): VerificationCallableDeps {
  return { verification: liveVerificationDeps(), notify: liveNotifyDeps() };
}

export function liveBusinessDocPurgeDeps(): BusinessDocPurgeDeps {
  const store = new FirestoreVerificationStore(db());
  return {
    due: (now, limit) => store.findDueBusinessPurges(now, limit),
    deleteFiles: deleteStorageFiles,
    clear: (uid, docPath, now) => store.clearBusinessDoc(uid, docPath, now),
    clock: { now: () => new Date() },
  };
}
