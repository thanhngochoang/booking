import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import {
  MemoryVerificationStore,
  fakeIdNumberOf,
  nextStep,
  reviewVerification,
  submitBusinessVerification,
  FakeTaxCodeLookup,
} from '@photobooking/domain';
import { devHashIdSync, devIdentityVaultDecrypt } from '../../src/infra/identity_vault.js';
import { identityFromFirestore, verificationFromFirestore } from '../../src/infra/verification_firestore.js';
import {
  AN,
  BINH,
  CUC,
  DUNG,
  GIANG,
  MINH,
  SEED_GIANG_FEE_PAYMENT,
  SEED_MINH_FAKE_DOB,
  SEED_PHOTOGRAPHERS,
  SEED_USERS,
  seedDocuments,
} from '../../seed/fixtures.js';
import { paymentFromFirestore } from '../../src/infra/booking_firestore.js';
import { feeDepsOf } from './verification_support.js';

const NOW = new Date('2026-10-01T12:00:00Z');
const docs = seedDocuments(NOW);
const get = (path: string) => docs.find((d) => d.path === path)?.data;

describe('seed verification (S21)', () => {
  test('Giang is unverified with a submitted record: phone, fee, fake identity and rules done', () => {
    const giang = SEED_PHOTOGRAPHERS.find((p) => p.uid === GIANG);
    assert.equal(giang?.verified, false);
    assert.equal(get(`photographers/${GIANG}`)?.acceptingOrders, false);
    assert.equal(SEED_USERS.find((u) => u.uid === GIANG)?.email, 'giang.pending@seed.test');

    const v = verificationFromFirestore(get(`verifications/${GIANG}`));
    assert.equal(v?.status, 'submitted');
    assert.equal(v?.kind, 'individual');
    assert.deepEqual(v?.steps.fee && [v.steps.fee.paymentId, v.steps.fee.amount], [SEED_GIANG_FEE_PAYMENT, 99_000]);
    assert.ok(v !== null && v.steps.phone !== null && v.steps.rules !== null);
    assert.equal(v.steps.identity?.result, 'passed');
    // Every step of the #203 flow is done (the fee is required since #203).
    assert.equal(nextStep(v, true, true), null);
    assert.ok(Date.parse(v.steps.fee?.paidAt ?? '') < Date.parse(v.submittedAt ?? ''));
    // 26 h waiting: the staff CLI marks it overdue.
    assert.equal(NOW.getTime() - Date.parse(v.submittedAt ?? ''), 26 * 3_600_000);

    // The Auth phone (applySeed) equals the verified contact phone.
    const contact = get(`users/${GIANG}/private/contact`);
    assert.equal(contact?.phoneVerified, true);
    assert.equal(contact?.phone, SEED_USERS.find((u) => u.uid === GIANG)?.phoneNumber);
  });

  test("Giang's fee is a released platform payment with its received and charged ledger entries", () => {
    const p = paymentFromFirestore(SEED_GIANG_FEE_PAYMENT, get(`payments/${SEED_GIANG_FEE_PAYMENT}`));
    assert.ok(p !== null);
    assert.equal(p.subjectType, 'verification_fee');
    assert.equal(p.subjectId, GIANG);
    assert.equal(p.payerId, GIANG);
    assert.equal(p.payeeId, 'platform');
    assert.equal(p.amount, 99_000);
    assert.equal(p.status, 'paid');
    assert.equal(p.escrowStatus, 'released');
    assert.equal(p.idempotencyKey, `vfee_${GIANG}_1_bank_qr`);
    assert.ok(p.transferCode !== undefined);
    const ledger = docs.filter((d) => d.path.startsWith('ledger_entries/') && d.data.paymentId === SEED_GIANG_FEE_PAYMENT);
    assert.deepEqual(
      ledger.map((d) => [d.data.type, d.data.accountOwnerId, d.data.amount]).sort(),
      [['fee_charged', 'platform_revenue', 99_000], ['payment_received', 'platform_escrow', 99_000]],
    );
    // Approved records from before #203 keep no fee (Decision 24).
    for (const uid of [AN, CUC, DUNG]) assert.equal(verificationFromFirestore(get(`verifications/${uid}`))?.steps.fee, null, uid);
  });

  test('identity docs hold the dev-vault hash and ciphertext of the fake id, guarded by identity_hashes', () => {
    for (const uid of [GIANG, CUC]) {
      const identity = identityFromFirestore(get(`users/${uid}/private/identity`));
      const idNumber = fakeIdNumberOf(uid);
      assert.equal(identity?.idHash, devHashIdSync(idNumber), uid);
      assert.equal(devIdentityVaultDecrypt(identity?.idNumberEnc ?? ''), idNumber, uid);
      assert.ok(!JSON.stringify(get(`users/${uid}/private/identity`)).includes(idNumber), uid);
      assert.equal(get(`identity_hashes/${identity?.idHash}`)?.uid, uid);
    }
  });

  test('verified seed photographers have approved records; Bình has none and no fake identity', () => {
    for (const uid of [AN, CUC, DUNG]) assert.equal(verificationFromFirestore(get(`verifications/${uid}`))?.status, 'approved', uid);
    assert.equal(verificationFromFirestore(get(`verifications/${CUC}`))?.kind, 'studio');
    assert.equal(get(`verifications/${BINH}`), undefined);
    assert.equal(get(`fake_identities/${BINH}`), undefined);
    assert.deepEqual(get(`fake_identities/${MINH}`), { dob: SEED_MINH_FAKE_DOB });
  });

  test('npm run verifications -- approve on Giang opens orders (same use case, seeded state)', async () => {
    const store = new MemoryVerificationStore();
    const v = verificationFromFirestore(get(`verifications/${GIANG}`));
    assert.ok(v !== null);
    store.verifications.set(GIANG, v);
    store.providers.set(GIANG, { providerType: 'individual', onboardingComplete: true, verified: false, businessVerified: false });
    const change = await reviewVerification(
      { store, authPhones: { verifiedPhoneOf: async () => null }, identity: null, vault: null, taxCodes: null, feeRequired: false, ...feeDepsOf(), clock: { now: () => NOW }, ids: { newId: () => 'a1' } },
      { uid: 'seed-staff-admin', isAdmin: true },
      { uid: GIANG, action: 'approve' },
    );
    assert.equal(change.after.status, 'approved');
    assert.equal(store.providerFlags.get(GIANG)?.acceptingOrders, true);
  });

  test("Cúc's household tax code (her fake id number) matches her identity in S21.04", async () => {
    const store = new MemoryVerificationStore();
    const v = verificationFromFirestore(get(`verifications/${CUC}`));
    const identity = identityFromFirestore(get(`users/${CUC}/private/identity`));
    assert.ok(v !== null && identity !== null);
    store.verifications.set(CUC, v);
    store.identities.set(CUC, identity);
    store.providers.set(CUC, { providerType: 'studio', onboardingComplete: true, verified: true, businessVerified: false });
    const change = await submitBusinessVerification(
      {
        store, authPhones: { verifiedPhoneOf: async () => null }, identity: null,
        vault: { hashId: async (s) => devHashIdSync(s), encryptId: async (s) => s },
        taxCodes: new FakeTaxCodeLookup(), feeRequired: false, ...feeDepsOf(), clock: { now: () => NOW }, ids: { newId: () => 'a1' },
      },
      CUC,
      { taxCode: fakeIdNumberOf(CUC) },
    );
    assert.equal(change.after.business?.status, 'approved');
  });
});

test("the README's household tax code for Cúc is her fake id number", () => {
  assert.equal(fakeIdNumberOf(CUC), '001461723292');
});
