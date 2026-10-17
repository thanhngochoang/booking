import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import { PROVIDER_RULES_VERSION, fakeIdNumberOf, type NotifyDeps, type SettlementDeps } from '@photobooking/domain';
import { handleConfirmFakePayment } from '../../src/callables/payment.js';
import { settlementSubjectsOf } from '../../src/infra/live_payments.js';
import {
  handleAcceptVerificationRules,
  handleCheckVerificationFee,
  handleStartVerificationFee,
  handleCompleteIdentityVerification,
  handleConfirmPhoneVerified,
  handleLookupTaxCode,
  handleResubmitVerification,
  handleReviewVerification,
  handleStartIdentityVerification,
  handleSubmitBusinessVerification,
  handleSubmitVerification,
  type VerificationCallableDeps,
  type VerificationCallableInput,
  type VerificationFeeCallableDeps,
} from '../../src/callables/verification.js';
import { liveVerificationDeps } from '../../src/infra/live_verification.js';
import { WEBHOOK_ENV } from './support/payment_world.js';
import { EMULATOR_ENV, PROD_ENV, readyRecord, verificationWorld } from './verification_support.js';

type Handler = (r: VerificationCallableInput, d: VerificationCallableDeps) => Promise<unknown>;

const HANDLERS: Record<string, Handler> = {
  confirmPhoneVerified: handleConfirmPhoneVerified,
  startIdentityVerification: handleStartIdentityVerification,
  completeIdentityVerification: handleCompleteIdentityVerification,
  acceptVerificationRules: handleAcceptVerificationRules,
  submitVerification: handleSubmitVerification,
  resubmitVerification: handleResubmitVerification,
  lookupTaxCode: handleLookupTaxCode,
  submitBusinessVerification: handleSubmitBusinessVerification,
  reviewVerification: handleReviewVerification,
};

const refused = (httpCode: string, code: string) => (e: unknown) =>
  e instanceof HttpsError && e.code === httpCode && (e.details as { code?: string } | undefined)?.code === code;

const as = (uid: string, data: unknown = {}, token: Record<string, unknown> = {}): VerificationCallableInput => ({
  auth: { uid, token },
  data,
});
const ADMIN = { staffRole: 'admin' };

function setup(options: { fakes?: boolean; feeRequired?: boolean } = {}) {
  const w = verificationWorld(options);
  const deps: VerificationCallableDeps = { verification: w.deps, notify: w.notify };
  // V1's settlement as liveSettlementDeps() builds it, with the fee settler over this world.
  const settlement: SettlementDeps = {
    payments: w.deps.payments,
    gateway: w.gateway,
    clock: w.deps.clock,
    subjects: settlementSubjectsOf({ verification: w.deps }),
  };
  const feeDeps: VerificationFeeCallableDeps = { ...deps, settlement };
  return { ...w, callDeps: deps, feeDeps, settlement };
}

/** Phone, identity (fake) and rules done through the callables, then submitted. */
async function walkToSubmitted(d: VerificationCallableDeps, uid: string): Promise<void> {
  await handleConfirmPhoneVerified(as(uid), d);
  const { sessionId } = await handleStartIdentityVerification(as(uid, { method: 'vneid' }), d);
  await handleCompleteIdentityVerification(as(uid, { sessionId }), d);
  await handleAcceptVerificationRules(as(uid, { version: PROVIDER_RULES_VERSION }), d);
  assert.deepEqual(await handleSubmitVerification(as(uid), d), { status: 'submitted' });
}

describe('verification callables', () => {
  it('unauthenticated calls are refused', async () => {
    const { callDeps, store } = setup();
    for (const [name, h] of Object.entries(HANDLERS)) {
      await assert.rejects(() => h({ auth: undefined, data: {} }, callDeps), refused('unauthenticated', 'permission_denied'), name);
    }
    assert.equal(store.verifications.size, 0);
  });

  it('a caller without a photographers doc is permission-denied', async () => {
    const { callDeps } = setup();
    await assert.rejects(() => handleConfirmPhoneVerified(as('c1'), callDeps), refused('permission-denied', 'permission_denied'));
    await assert.rejects(
      () => handleAcceptVerificationRules(as('c1', { version: PROVIDER_RULES_VERSION }), callDeps),
      refused('permission-denied', 'permission_denied'),
    );
  });

  it('the full path: phone, fake identity, rules, submit, then approve opens orders and notifies', async () => {
    const { callDeps, store, notifyStore } = setup();
    assert.deepEqual(await handleConfirmPhoneVerified(as('p1'), callDeps), { phoneVerified: true });
    assert.equal(store.contacts.get('p1')?.phoneVerified, true);
    const start = await handleStartIdentityVerification(as('p1', { method: 'vneid' }), callDeps);
    assert.equal(start.redirectUrl, null);
    const done = await handleCompleteIdentityVerification(as('p1', { sessionId: start.sessionId }), callDeps);
    assert.deepEqual(done, { result: 'passed', maskedName: 'THO P**' });
    assert.deepEqual(await handleAcceptVerificationRules(as('p1', { version: PROVIDER_RULES_VERSION }), callDeps), {});
    assert.deepEqual(await handleSubmitVerification(as('p1'), callDeps), { status: 'submitted' });
    assert.equal(notifyStore.rowsOf('p1').length, 0);

    const res = await handleReviewVerification(as('staff1', { uid: 'p1', action: 'approve' }, ADMIN), callDeps);
    assert.deepEqual(res, { status: 'approved' });
    assert.equal(store.providerFlags.get('p1')?.verified, true);
    assert.equal(store.providerFlags.get('p1')?.acceptingOrders, true);
    assert.deepEqual(
      notifyStore.rowsOf('p1').map((r) => r.type),
      ['verification_approved'],
    );
    // The stored identity keeps the encrypted number and its dev hash, never the number itself.
    const identity = store.identities.get('p1');
    assert.ok(identity !== undefined);
    assert.ok(!JSON.stringify(identity).includes(fakeIdNumberOf('p1')));
    assert.equal(store.identityHashes.get(identity.idHash), 'p1');
  });

  it('reviewVerification needs the admin claim', async () => {
    const { callDeps, store } = setup();
    store.verifications.set('p1', readyRecord('p1'));
    for (const token of [{}, { staffRole: 'support' }, { staffRole: true }]) {
      await assert.rejects(
        () => handleReviewVerification(as('p1', { uid: 'p1', action: 'approve' }, token), callDeps),
        refused('permission-denied', 'permission_denied'),
      );
    }
    assert.equal(store.verifications.get('p1')?.status, 'submitted');
    assert.equal(store.audits.length, 0);
  });

  it('staff decisions answer with the status of their target and audit the actor', async () => {
    const { callDeps, store, notifyStore } = setup();
    store.verifications.set('p1', readyRecord('p1'));
    // A ready record's phone step is the contact flag (Decision 3), which resubmit re-checks.
    store.contacts.set('p1', { phone: store.contacts.get('p1')?.phone ?? null, phoneVerified: true });
    assert.deepEqual(
      await handleReviewVerification(as('staff1', { uid: 'p1', action: 'reject', reason: 'fake_avatar' }, ADMIN), callDeps),
      { status: 'rejected' },
    );
    assert.equal(store.audits.at(-1)?.actorId, 'staff1');
    assert.deepEqual(notifyStore.rowsOf('p1').map((r) => r.type), ['verification_rejected']);
    assert.deepEqual(await handleResubmitVerification(as('p1'), callDeps), { status: 'submitted' });
    await assert.rejects(
      () => handleReviewVerification(as('staff1', { uid: 'p1', action: 'revoke', note: 'x' }, ADMIN), callDeps),
      refused('aborted', 'conflict'),
    );
  });

  it('domain codes map: identity_in_use → already-exists, underage → failed-precondition, rate_limited → resource-exhausted', async () => {
    const { callDeps, overrides } = setup();
    // p1 owns the identity first.
    await handleConfirmPhoneVerified(as('p1'), callDeps);
    const s1 = await handleStartIdentityVerification(as('p1', { method: 'nfc' }), callDeps);
    await handleCompleteIdentityVerification(as('p1', { sessionId: s1.sessionId }), callDeps);

    // p2 presents p1's id number.
    overrides.set('p2', { idNumber: fakeIdNumberOf('p1') });
    const s2 = await handleStartIdentityVerification(as('p2', { method: 'vneid' }), callDeps);
    await assert.rejects(
      () => handleCompleteIdentityVerification(as('p2', { sessionId: s2.sessionId }), callDeps),
      refused('already-exists', 'identity_in_use'),
    );

    // s1 is 16 on the fake card.
    overrides.set('s1', { dob: '2010-05-01' });
    const s3 = await handleStartIdentityVerification(as('s1', { method: 'vneid' }), callDeps);
    await assert.rejects(
      () => handleCompleteIdentityVerification(as('s1', { sessionId: s3.sessionId }), callDeps),
      refused('failed-precondition', 'underage'),
    );

    // p2 already used one attempt today; two more, then rate_limited.
    await handleStartIdentityVerification(as('p2', { method: 'vneid' }), callDeps);
    await handleStartIdentityVerification(as('p2', { method: 'vneid' }), callDeps);
    await assert.rejects(
      () => handleStartIdentityVerification(as('p2', { method: 'vneid' }), callDeps),
      refused('resource-exhausted', 'rate_limited'),
    );
  });

  it('identity callables answer not_eligible when the fake is not allowed', async () => {
    const { callDeps } = setup({ fakes: false });
    await assert.rejects(
      () => handleStartIdentityVerification(as('p1', { method: 'vneid' }), callDeps),
      refused('failed-precondition', 'not_eligible'),
    );
    await assert.rejects(
      () => handleCompleteIdentityVerification(as('p1', { sessionId: 'x' }), callDeps),
      refused('failed-precondition', 'not_eligible'),
    );
    await assert.rejects(
      () => handleLookupTaxCode(as('s1', { taxCode: '0312345678' }), callDeps),
      refused('failed-precondition', 'not_eligible'),
    );
  });

  it('liveVerificationDeps wires the fakes only on the emulator or the dev project, and requires the fee (#203)', () => {
    const prod = liveVerificationDeps(PROD_ENV);
    assert.equal(prod.identity, null);
    assert.equal(prod.vault, null);
    assert.equal(prod.taxCodes, null);
    assert.equal(prod.feeRequired, true);
    const emulator = liveVerificationDeps(EMULATOR_ENV);
    assert.ok(emulator.identity !== null && emulator.vault !== null && emulator.taxCodes !== null);
    assert.equal(emulator.feeRequired, true);
    // #129's gateway, V1's cross-subject lookup and V2's cipher (read lazily, so no secret here).
    assert.equal(emulator.gateway.provider, 'fake');
    assert.equal(typeof emulator.payments.findPaymentsByTransferCode, 'function');
    assert.equal(typeof emulator.cipher.encrypt, 'function');
    const dev = liveVerificationDeps({ GCLOUD_PROJECT: 'booking-c1922' });
    assert.ok(dev.identity !== null);
    // FUNCTIONS_EMULATOR alone on a real project id is not enough.
    assert.equal(liveVerificationDeps({ FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'photobooking-prod' }).identity, null);
  });

  it('a failing notification after the commit is logged, not thrown', async () => {
    const { callDeps, store } = setup();
    store.verifications.set('p1', readyRecord('p1'));
    const broken: NotifyDeps = {
      ...callDeps.notify,
      store: { runTransaction: async () => Promise.reject(new Error('firestore down')) } as unknown as NotifyDeps['store'],
    };
    const res = await handleReviewVerification(as('staff1', { uid: 'p1', action: 'approve' }, ADMIN), {
      ...callDeps,
      notify: broken,
    });
    assert.deepEqual(res, { status: 'approved' });
    assert.equal(store.verifications.get('p1')?.status, 'approved');
  });

  it('studio business: lookup, household matched at once, then the approved record cannot be replaced', async () => {
    const { callDeps, store, notifyStore } = setup();
    await walkToSubmitted(callDeps, 's1');
    await handleReviewVerification(as('staff1', { uid: 's1', action: 'approve' }, ADMIN), callDeps);

    assert.deepEqual(await handleLookupTaxCode(as('s1', { taxCode: '0312345678' }), callDeps), {
      name: 'CÔNG TY TNHH STUDIO THỬ 5678',
      address: '12 Nguyễn Huệ, Phường Sài Gòn, TP. Hồ Chí Minh',
      status: 'active',
      kind: 'company',
    });
    await assert.rejects(
      () => handleLookupTaxCode(as('s1', { taxCode: '123' }), callDeps),
      refused('invalid-argument', 'invalid_argument'),
    );
    // A household code is the owner's own id number: approved at once.
    assert.deepEqual(
      await handleSubmitBusinessVerification(as('s1', { taxCode: fakeIdNumberOf('s1') }), callDeps),
      { status: 'approved' },
    );
    assert.equal(store.providerFlags.get('s1')?.businessVerified, true);
    assert.ok(notifyStore.rowsOf('s1').some((r) => r.type === 'business_verified'));

    // The verified business is not replaced by another submission (businessVerified and the record agree).
    await assert.rejects(
      () => handleSubmitBusinessVerification(as('s1', { taxCode: '0312345678', docPath: 'businessDocs/s1/01J.jpg' }), callDeps),
      refused('aborted', 'conflict'),
    );
    assert.equal(store.verifications.get('s1')?.business?.kind, 'household');
    assert.equal(store.verifications.get('s1')?.business?.status, 'approved');
  });

  it('studio business: a company goes to staff, cannot be resent while pending, is resent after a rejection', async () => {
    const { callDeps, store } = setup();
    await walkToSubmitted(callDeps, 's1');
    await handleReviewVerification(as('staff1', { uid: 's1', action: 'approve' }, ADMIN), callDeps);

    assert.deepEqual(
      await handleSubmitBusinessVerification(as('s1', { taxCode: '0312345678', docPath: 'businessDocs/s1/a.jpg' }), callDeps),
      { status: 'submitted' },
    );
    await assert.rejects(
      () => handleSubmitBusinessVerification(as('s1', { taxCode: '0312345678', docPath: 'businessDocs/s1/b.jpg' }), callDeps),
      refused('aborted', 'conflict'),
    );
    assert.equal(store.verifications.get('s1')?.business?.docPath, 'businessDocs/s1/a.jpg');

    assert.deepEqual(
      await handleReviewVerification(
        as('staff1', { uid: 's1', target: 'business', action: 'reject', reason: 'doc_unreadable' }, ADMIN),
        callDeps,
      ),
      { status: 'rejected' },
    );
    assert.deepEqual(
      await handleSubmitBusinessVerification(as('s1', { taxCode: '0312345678', docPath: 'businessDocs/s1/c.jpg' }), callDeps),
      { status: 'submitted' },
    );
    assert.deepEqual(
      await handleReviewVerification(as('staff1', { uid: 's1', target: 'business', action: 'approve' }, ADMIN), callDeps),
      { status: 'approved' },
    );
    assert.equal(store.providerFlags.get('s1')?.businessVerified, true);
  });

  it('a non-verified provider cannot start the business step', async () => {
    const { callDeps } = setup();
    await assert.rejects(
      () => handleSubmitBusinessVerification(as('s1', { taxCode: '0312345678', docPath: 'businessDocs/s1/a.jpg' }), callDeps),
      refused('failed-precondition', 'not_eligible'),
    );
  });
});

describe('verification fee callables (#203)', () => {
  it('unauthenticated fee calls are refused', async () => {
    const { feeDeps, store } = setup({ feeRequired: true });
    await assert.rejects(
      () => handleStartVerificationFee({ auth: undefined, data: { method: 'bank_qr' } }, feeDeps, EMULATOR_ENV),
      refused('unauthenticated', 'permission_denied'),
    );
    await assert.rejects(() => handleCheckVerificationFee({ auth: undefined, data: {} }, feeDeps), refused('unauthenticated', 'permission_denied'));
    assert.equal(store.payments.size, 0);
  });

  it('startVerificationFee in payments-off mode is not_eligible', async () => {
    const { feeDeps, store } = setup({ feeRequired: true });
    await assert.rejects(
      () => handleStartVerificationFee(as('p1', { method: 'bank_qr' }), feeDeps, PROD_ENV),
      refused('failed-precondition', 'not_eligible'),
    );
    assert.equal(store.payments.size, 0);
    assert.equal(store.verifications.size, 0);
  });

  it('startVerificationFee refuses bad input and customers; checkVerificationFee without a record is not_found', async () => {
    const { feeDeps } = setup({ feeRequired: true });
    await assert.rejects(
      () => handleStartVerificationFee(as('p1', { method: 'cash' }), feeDeps, EMULATOR_ENV),
      refused('invalid-argument', 'invalid_argument'),
    );
    await assert.rejects(
      () => handleStartVerificationFee(as('c1', { method: 'bank_qr' }), feeDeps, EMULATOR_ENV),
      refused('permission-denied', 'permission_denied'),
    );
    await assert.rejects(() => handleCheckVerificationFee(as('p1'), feeDeps), refused('not-found', 'not_found'));
  });

  it('the full path with the fee: phone, fee (fake), identity (fake), rules, submit, approve', async () => {
    const { callDeps, feeDeps, settlement, store, gateway } = setup({ feeRequired: true });
    assert.deepEqual(await handleConfirmPhoneVerified(as('p1'), callDeps), { phoneVerified: true });
    // Identity needs the fee paid.
    await assert.rejects(
      () => handleStartIdentityVerification(as('p1', { method: 'vneid' }), callDeps),
      refused('failed-precondition', 'not_eligible'),
    );

    const inst = await handleStartVerificationFee(as('p1', { method: 'bank_qr' }), feeDeps, EMULATOR_ENV);
    assert.equal(inst.amount, 99_000);
    assert.equal(inst.method, 'bank_qr');
    const payment = store.payments.get(inst.paymentId);
    assert.equal(payment?.subjectType, 'verification_fee');
    assert.equal(payment?.payeeId, 'platform');
    // A second tap reuses the live code (no new payment, no gateway call).
    const calls = gateway.createPaymentCalls.length;
    assert.equal((await handleStartVerificationFee(as('p1', { method: 'bank_qr' }), feeDeps, EMULATOR_ENV)).paymentId, inst.paymentId);
    assert.equal(gateway.createPaymentCalls.length, calls);
    assert.deepEqual(await handleCheckVerificationFee(as('p1'), feeDeps), { paid: false, instructions: inst });

    // V1's unified fake confirmation, through the webhook handler and the registered fee settler.
    assert.deepEqual(
      await handleConfirmFakePayment(as('p1', { paymentId: inst.paymentId }), settlement, WEBHOOK_ENV),
      { outcome: 'paid' },
    );
    assert.deepEqual(await handleCheckVerificationFee(as('p1'), feeDeps), { paid: true, instructions: null });
    assert.equal(store.verifications.get('p1')?.steps.fee?.amount, 99_000);
    await assert.rejects(
      () => handleStartVerificationFee(as('p1', { method: 'momo' }), feeDeps, EMULATOR_ENV),
      refused('failed-precondition', 'not_eligible'),
    );

    const start = await handleStartIdentityVerification(as('p1', { method: 'vneid' }), callDeps);
    await handleCompleteIdentityVerification(as('p1', { sessionId: start.sessionId }), callDeps);
    await handleAcceptVerificationRules(as('p1', { version: PROVIDER_RULES_VERSION }), callDeps);
    assert.deepEqual(await handleSubmitVerification(as('p1'), callDeps), { status: 'submitted' });
    assert.deepEqual(
      await handleReviewVerification(as('staff1', { uid: 'p1', action: 'approve' }, ADMIN), callDeps),
      { status: 'approved' },
    );
    assert.equal(store.providerFlags.get('p1')?.acceptingOrders, true);
  });
});
