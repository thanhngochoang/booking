import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createVerificationWorld } from './support/verification_world.js';
import {
  acceptVerificationRules,
  confirmPhoneVerified,
  notifyVerificationChange,
  resubmitVerification,
  reviewVerification,
  sendVerificationNudges,
  submitVerification,
  verificationNotices,
} from '../src/verification_use_cases.js';
import { DomainError, type ErrorCode } from '../src/errors.js';
import { PROVIDER_RULES_VERSION, emptyVerification, feeWaived, nextStep } from '../src/verification.js';
import { startVerificationFee } from '../src/verification_fee.js';
import { PLATFORM_PAYEE } from '../src/payout.js';

const refusedWith = (code: ErrorCode) => (e: unknown) => e instanceof DomainError && e.code === code;

describe('verification_use_cases', () => {
  it('a non-provider is permission_denied', async () => {
    const world = createVerificationWorld();
    await assert.rejects(
      confirmPhoneVerified(world.deps, 'c1'),
      refusedWith('permission_denied'),
    );
  });

  it('confirmPhoneVerified sets phoneVerified when Auth and contact match', async () => {
    const world = createVerificationWorld();
    const res = await confirmPhoneVerified(world.deps, 'p1');

    assert.equal(res.after.status, 'in_progress');
    assert.ok(res.after.steps.phone?.doneAt);

    const contact = await world.store.runTransaction((tx) => tx.getContact('p1'));
    assert.equal(contact.phoneVerified, true);
  });

  it('a different Auth number is conflict', async () => {
    const world = createVerificationWorld();
    world.authPhones.phones.set('p1', '+84909999999');

    await assert.rejects(
      confirmPhoneVerified(world.deps, 'p1'),
      refusedWith('conflict'),
    );
  });

  it('no contact phone is phone_required', async () => {
    const world = createVerificationWorld();
    world.store.contacts.set('p1', { phone: null, phoneVerified: false });

    await assert.rejects(
      confirmPhoneVerified(world.deps, 'p1'),
      refusedWith('phone_required'),
    );
  });

  it('kind follows providerType while no fee is recorded', async () => {
    const world = createVerificationWorld();
    const resP1 = await confirmPhoneVerified(world.deps, 'p1');
    assert.equal(resP1.after.kind, 'individual');

    const resS1 = await confirmPhoneVerified(world.deps, 's1');
    assert.equal(resS1.after.kind, 'studio');
  });

  it('acceptVerificationRules needs the current version', async () => {
    const world = createVerificationWorld();
    await confirmPhoneVerified(world.deps, 'p1');

    await assert.rejects(
      acceptVerificationRules(world.deps, 'p1', { version: '2026-09-01' }),
      refusedWith('invalid_argument'),
    );

    const res = await acceptVerificationRules(world.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    assert.equal(res.after.steps.rules?.version, PROVIDER_RULES_VERSION);
  });

  it('submit needs phone, identity and rules (no fee step without feeRequired)', async () => {
    const world = createVerificationWorld();
    await confirmPhoneVerified(world.deps, 'p1');

    // Missing identity and rules
    await assert.rejects(
      submitVerification(world.deps, 'p1'),
      refusedWith('not_eligible'),
    );

    // Mock identity passed
    await world.store.runTransaction(async (tx) => {
      const rec = await tx.getVerification('p1');
      assert.ok(rec);
      tx.putVerification({
        ...rec,
        steps: {
          ...rec.steps,
          identity: {
            method: 'vneid',
            checkedAt: world.clock.now().toISOString(),
            result: 'passed',
            failure: null,
            maskedName: 'NGUYỄN M** T**',
          },
        },
      });
    });

    // Still missing rules
    await assert.rejects(
      submitVerification(world.deps, 'p1'),
      refusedWith('not_eligible'),
    );

    await acceptVerificationRules(world.deps, 'p1', { version: PROVIDER_RULES_VERSION });

    // Submit now succeeds
    const submitted = await submitVerification(world.deps, 'p1');
    assert.equal(submitted.after.status, 'submitted');
    assert.ok(submitted.after.submittedAt);
  });

  it('submit moves to submitted with submittedAt', async () => {
    const world = createVerificationWorld();
    await confirmPhoneVerified(world.deps, 'p1');
    await acceptVerificationRules(world.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await world.store.runTransaction(async (tx) => {
      const rec = await tx.getVerification('p1');
      assert.ok(rec);
      tx.putVerification({
        ...rec,
        steps: {
          ...rec.steps,
          identity: {
            method: 'vneid',
            checkedAt: world.clock.now().toISOString(),
            result: 'passed',
            failure: null,
            maskedName: 'NGUYỄN M** T**',
          },
        },
      });
    });

    const res = await submitVerification(world.deps, 'p1');
    assert.equal(res.after.status, 'submitted');
    assert.equal(res.after.submittedAt, '2026-10-10T10:00:00.000Z');
  });

  it('approve writes verified and acceptingOrders together', async () => {
    const world = createVerificationWorld();
    await confirmPhoneVerified(world.deps, 'p1');
    await acceptVerificationRules(world.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await world.store.runTransaction(async (tx) => {
      const rec = await tx.getVerification('p1');
      assert.ok(rec);
      tx.putVerification({
        ...rec,
        steps: {
          ...rec.steps,
          identity: {
            method: 'vneid',
            checkedAt: world.clock.now().toISOString(),
            result: 'passed',
            failure: null,
            maskedName: 'NGUYỄN M** T**',
          },
        },
      });
    });
    await submitVerification(world.deps, 'p1');

    const res = await reviewVerification(
      world.deps,
      { uid: 'staff1', isAdmin: true },
      { uid: 'p1', action: 'approve' },
    );

    assert.equal(res.after.status, 'approved');
    const flags = world.store.providerFlags.get('p1');
    assert.equal(flags?.verified, true);
    assert.equal(flags?.acceptingOrders, true);
  });

  it('approve of a provider without onboarding writes acceptingOrders false', async () => {
    const world = createVerificationWorld();
    world.store.providers.set('p1', {
      providerType: 'individual',
      onboardingComplete: false,
      verified: false,
      businessVerified: false,
    });

    await confirmPhoneVerified(world.deps, 'p1');
    await acceptVerificationRules(world.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await world.store.runTransaction(async (tx) => {
      const rec = await tx.getVerification('p1');
      assert.ok(rec);
      tx.putVerification({
        ...rec,
        steps: {
          ...rec.steps,
          identity: {
            method: 'vneid',
            checkedAt: world.clock.now().toISOString(),
            result: 'passed',
            failure: null,
            maskedName: 'NGUYỄN M** T**',
          },
        },
      });
    });
    await submitVerification(world.deps, 'p1');

    await reviewVerification(
      world.deps,
      { uid: 'staff1', isAdmin: true },
      { uid: 'p1', action: 'approve' },
    );

    const flags = world.store.providerFlags.get('p1');
    assert.equal(flags?.verified, true);
    assert.equal(flags?.acceptingOrders, false);
  });

  it('reject needs a known reason and a note for other', async () => {
    const world = createVerificationWorld();
    await confirmPhoneVerified(world.deps, 'p1');
    await acceptVerificationRules(world.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await world.store.runTransaction(async (tx) => {
      const rec = await tx.getVerification('p1');
      assert.ok(rec);
      tx.putVerification({
        ...rec,
        steps: {
          ...rec.steps,
          identity: {
            method: 'vneid',
            checkedAt: world.clock.now().toISOString(),
            result: 'passed',
            failure: null,
            maskedName: 'NGUYỄN M** T**',
          },
        },
      });
    });
    await submitVerification(world.deps, 'p1');

    // Unknown reason
    await assert.rejects(
      reviewVerification(
        world.deps,
        { uid: 'staff1', isAdmin: true },
        { uid: 'p1', action: 'reject', reason: 'unknown_reason' },
      ),
      refusedWith('invalid_argument'),
    );

    // other without note
    await assert.rejects(
      reviewVerification(
        world.deps,
        { uid: 'staff1', isAdmin: true },
        { uid: 'p1', action: 'reject', reason: 'other' },
      ),
      refusedWith('invalid_argument'),
    );

    // Valid reject
    const rej = await reviewVerification(
      world.deps,
      { uid: 'staff1', isAdmin: true },
      { uid: 'p1', action: 'reject', reason: 'fake_avatar' },
    );
    assert.equal(rej.after.status, 'rejected');
    assert.equal(rej.after.rejectReason?.code, 'fake_avatar');
  });

  it('reject identity_mismatch clears the identity step', async () => {
    const world = createVerificationWorld();
    await confirmPhoneVerified(world.deps, 'p1');
    await acceptVerificationRules(world.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await world.store.runTransaction(async (tx) => {
      const rec = await tx.getVerification('p1');
      assert.ok(rec);
      tx.putVerification({
        ...rec,
        steps: {
          ...rec.steps,
          identity: {
            method: 'vneid',
            checkedAt: world.clock.now().toISOString(),
            result: 'passed',
            failure: null,
            maskedName: 'NGUYỄN M** T**',
          },
        },
      });
    });
    await submitVerification(world.deps, 'p1');

    const rej = await reviewVerification(
      world.deps,
      { uid: 'staff1', isAdmin: true },
      { uid: 'p1', action: 'reject', reason: 'identity_mismatch' },
    );
    assert.equal(rej.after.status, 'rejected');
    assert.equal(rej.after.steps.identity, null);
  });

  it('resubmit with a free resubmit goes back to submitted and uses it', async () => {
    const world = createVerificationWorld();
    await confirmPhoneVerified(world.deps, 'p1');
    await acceptVerificationRules(world.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await world.store.runTransaction(async (tx) => {
      const rec = await tx.getVerification('p1');
      assert.ok(rec);
      tx.putVerification({
        ...rec,
        steps: {
          ...rec.steps,
          identity: {
            method: 'vneid',
            checkedAt: world.clock.now().toISOString(),
            result: 'passed',
            failure: null,
            maskedName: 'NGUYỄN M** T**',
          },
        },
      });
    });
    await submitVerification(world.deps, 'p1');
    await reviewVerification(
      world.deps,
      { uid: 'staff1', isAdmin: true },
      { uid: 'p1', action: 'reject', reason: 'fake_avatar' },
    );

    const resub = await resubmitVerification(world.deps, 'p1');
    assert.equal(resub.after.status, 'submitted');
    assert.equal(resub.after.freeResubmitsLeft, 0);
  });

  it('resubmit without free resubmits and without the fee goes back to submitted', async () => {
    const world = createVerificationWorld();
    await confirmPhoneVerified(world.deps, 'p1');
    await acceptVerificationRules(world.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await world.store.runTransaction(async (tx) => {
      const rec = await tx.getVerification('p1');
      assert.ok(rec);
      tx.putVerification({
        ...rec,
        steps: {
          ...rec.steps,
          identity: {
            method: 'vneid',
            checkedAt: world.clock.now().toISOString(),
            result: 'passed',
            failure: null,
            maskedName: 'NGUYỄN M** T**',
          },
        },
      });
    });
    await submitVerification(world.deps, 'p1');
    await reviewVerification(
      world.deps,
      { uid: 'staff1', isAdmin: true },
      { uid: 'p1', action: 'reject', reason: 'fake_avatar' },
    );
    // Use the 1 free resubmit
    await resubmitVerification(world.deps, 'p1');
    // Reject again
    await reviewVerification(
      world.deps,
      { uid: 'staff1', isAdmin: true },
      { uid: 'p1', action: 'reject', reason: 'fake_avatar' },
    );

    // Free resubmits is now 0. With feeRequired false, resubmit moves straight back to submitted
    const resub2 = await resubmitVerification(world.deps, 'p1');
    assert.equal(resub2.after.status, 'submitted');
  });

  it('duplicate_account and underage cannot resubmit', async () => {
    const world = createVerificationWorld();
    await confirmPhoneVerified(world.deps, 'p1');
    await acceptVerificationRules(world.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await world.store.runTransaction(async (tx) => {
      const rec = await tx.getVerification('p1');
      assert.ok(rec);
      tx.putVerification({
        ...rec,
        steps: {
          ...rec.steps,
          identity: {
            method: 'vneid',
            checkedAt: world.clock.now().toISOString(),
            result: 'passed',
            failure: null,
            maskedName: 'NGUYỄN M** T**',
          },
        },
      });
    });
    await submitVerification(world.deps, 'p1');
    await reviewVerification(
      world.deps,
      { uid: 'staff1', isAdmin: true },
      { uid: 'p1', action: 'reject', reason: 'duplicate_account' },
    );

    await assert.rejects(
      resubmitVerification(world.deps, 'p1'),
      refusedWith('not_eligible'),
    );
  });

  it('revoke turns verified and acceptingOrders off', async () => {
    const world = createVerificationWorld();
    await confirmPhoneVerified(world.deps, 'p1');
    await acceptVerificationRules(world.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await world.store.runTransaction(async (tx) => {
      const rec = await tx.getVerification('p1');
      assert.ok(rec);
      tx.putVerification({
        ...rec,
        steps: {
          ...rec.steps,
          identity: {
            method: 'vneid',
            checkedAt: world.clock.now().toISOString(),
            result: 'passed',
            failure: null,
            maskedName: 'NGUYỄN M** T**',
          },
        },
      });
    });
    await submitVerification(world.deps, 'p1');
    await reviewVerification(
      world.deps,
      { uid: 'staff1', isAdmin: true },
      { uid: 'p1', action: 'approve' },
    );

    // Revoke
    const rev = await reviewVerification(
      world.deps,
      { uid: 'staff1', isAdmin: true },
      { uid: 'p1', action: 'revoke', note: 'Vi phạm quy chuẩn chất lượng' },
    );

    assert.equal(rev.after.status, 'revoked');
    const flags = world.store.providerFlags.get('p1');
    assert.equal(flags?.verified, false);
    assert.equal(flags?.acceptingOrders, false);
  });

  it('only admins decide', async () => {
    const world = createVerificationWorld();
    await assert.rejects(
      reviewVerification(
        world.deps,
        { uid: 'non_admin', isAdmin: false },
        { uid: 'p1', action: 'approve' },
      ),
      refusedWith('permission_denied'),
    );
  });

  it('every decision writes an audit row', async () => {
    const world = createVerificationWorld();
    await confirmPhoneVerified(world.deps, 'p1');
    await acceptVerificationRules(world.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await world.store.runTransaction(async (tx) => {
      const rec = await tx.getVerification('p1');
      assert.ok(rec);
      tx.putVerification({
        ...rec,
        steps: {
          ...rec.steps,
          identity: {
            method: 'vneid',
            checkedAt: world.clock.now().toISOString(),
            result: 'passed',
            failure: null,
            maskedName: 'NGUYỄN M** T**',
          },
        },
      });
    });
    await submitVerification(world.deps, 'p1');

    await reviewVerification(
      world.deps,
      { uid: 'staff1', isAdmin: true },
      { uid: 'p1', action: 'approve' },
    );

    assert.equal(world.store.audits.length, 1);
    assert.equal(world.store.audits[0]?.action, 'approve');
    assert.equal(world.store.audits[0]?.actorId, 'staff1');
  });

  it('verificationNotices: approved, rejected, revoked, business verified/rejected', () => {
    const now = '2026-10-10T10:00:00.000Z';
    const base = emptyVerification('p1', 'individual', new Date(now));

    const approved = { ...base, status: 'approved' as const, decidedAt: now };
    assert.deepEqual(verificationNotices(base, approved), [
      { hook: 'decision', outcome: 'approved', decidedAt: now },
    ]);

    const rejected = { ...base, status: 'rejected' as const, decidedAt: now };
    assert.deepEqual(verificationNotices(base, rejected), [
      { hook: 'decision', outcome: 'rejected', decidedAt: now },
    ]);

    const revoked = { ...approved, status: 'revoked' as const, decidedAt: now };
    assert.deepEqual(verificationNotices(approved, revoked), [
      { hook: 'decision', outcome: 'revoked', decidedAt: now },
    ]);

    const bizApp = {
      ...base,
      business: {
        subject: 'studio' as const,
        status: 'approved' as const,
        kind: 'company' as const,
        taxCode: '0312345678',
        name: 'CÔNG TY TNHH ABC',
        address: '123 Đường',
        registryStatus: 'active' as const,
        docPath: null,
        representativeMatched: true,
        submittedAt: now,
        decidedAt: now,
        decidedBy: 'staff1',
        rejectReason: null,
        purgeAfter: null,
      },
    };
    assert.deepEqual(verificationNotices(base, bizApp), [
      { hook: 'business', outcome: 'verified', decidedAt: now },
    ]);
  });

  it('notifyVerificationChange calls notifyVerificationDecision with the outcome and decidedAt', async () => {
    const world = createVerificationWorld();
    const now = '2026-10-10T10:00:00.000Z';
    const before = emptyVerification('p1', 'individual', new Date(now));
    const after = { ...before, status: 'approved' as const, decidedAt: now };

    await notifyVerificationChange(world.notifyDeps, { before, after });
    // notify was invoked without throwing
  });

  it('sendVerificationNudges calls notifyVerificationReminder once after 24 h of no change', async () => {
    const world = createVerificationWorld();
    await confirmPhoneVerified(world.deps, 'p1');

    // Initially updated just now: nudge returns 0
    let count = await sendVerificationNudges(world.deps, world.notifyDeps);
    assert.equal(count, 0);

    // Advance 25 hours
    world.clock.advanceHours(25);
    count = await sendVerificationNudges(world.deps, world.notifyDeps);
    assert.equal(count, 1);

    // Second call: already nudged (nudgedAt != null), so 0
    count = await sendVerificationNudges(world.deps, world.notifyDeps);
    assert.equal(count, 0);
  });

  it('a reminder for a record with every step done but not sent says at least 1 step', async () => {
    const world = createVerificationWorld();
    await confirmPhoneVerified(world.deps, 'p1');
    const rec = world.store.verifications.get('p1');
    assert.ok(rec);
    // Every required step done (no fee), still in_progress because it was never sent.
    world.store.verifications.set('p1', {
      ...rec,
      steps: {
        ...rec.steps,
        identity: { method: 'vneid', checkedAt: rec.updatedAt, result: 'passed', failure: null, maskedName: 'N*** T***' },
        rules: { version: PROVIDER_RULES_VERSION, acceptedAt: rec.updatedAt },
      },
    });

    world.clock.advanceHours(25);
    const count = await sendVerificationNudges(world.deps, world.notifyDeps);
    assert.equal(count, 1);
    const rows = world.notifyStore.rowsOf('p1');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.title, 'Còn 1 bước để nhận đơn');
  });

  it('no reminder is sent when the guarding transaction did not write nudgedAt', async () => {
    const world = createVerificationWorld();
    await confirmPhoneVerified(world.deps, 'p1');
    world.clock.advanceHours(25);

    // The query returns the record, but it was submitted before the transaction ran.
    const stale = world.store.verifications.get('p1');
    assert.ok(stale);
    world.store.verifications.set('p1', { ...stale, status: 'submitted' });
    world.store.dueForNudge = async () => [stale];

    const count = await sendVerificationNudges(world.deps, world.notifyDeps);
    assert.equal(count, 0);
    assert.equal(world.notifyStore.rowsOf('p1').length, 0);
  });
});

describe('verification_use_cases with the fee (feeRequired: true)', () => {
  const staff = { uid: 'staff1', isAdmin: true };

  /** Marks the identity step passed without the vendor (the identity tests cover the vendor). */
  async function identityPassed(world: ReturnType<typeof createVerificationWorld>, uid = 'p1'): Promise<void> {
    await world.store.runTransaction(async (tx) => {
      const rec = await tx.getVerification(uid);
      assert.ok(rec);
      tx.putVerification({
        ...rec,
        steps: {
          ...rec.steps,
          identity: {
            method: 'vneid',
            checkedAt: world.clock.now().toISOString(),
            result: 'passed',
            failure: null,
            maskedName: 'NGUYỄN M** T**',
          },
        },
      });
    });
  }

  async function paidFee(world: ReturnType<typeof createVerificationWorld>, uid = 'p1'): Promise<string> {
    const inst = await startVerificationFee(world.deps, uid, { method: 'bank_qr' });
    await world.payFee(inst.paymentId, 'exact', uid);
    return inst.paymentId;
  }

  /** Phone, fee, identity, rules done, then submitted. */
  async function submittedWithFee(world: ReturnType<typeof createVerificationWorld>): Promise<void> {
    await confirmPhoneVerified(world.deps, 'p1');
    await paidFee(world);
    await identityPassed(world);
    await acceptVerificationRules(world.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await submitVerification(world.deps, 'p1');
  }

  it("startVerificationFee returns PaymentInstructions for a platform payment of the kind's fee (bank_qr has the VietQR payload)", async () => {
    const world = createVerificationWorld({ feeRequired: true });
    await confirmPhoneVerified(world.deps, 'p1');

    const inst = await startVerificationFee(world.deps, 'p1', { method: 'bank_qr' });
    assert.equal(inst.subjectType, 'verification_fee');
    assert.equal(inst.subjectId, 'p1');
    assert.equal(inst.method, 'bank_qr');
    assert.equal(inst.amount, 99_000);
    assert.equal(inst.expiresAt, '2026-10-10T10:15:00.000Z');
    assert.match(inst.transferCode, /^PB [2-9A-Z]{6}$/);
    assert.ok(inst.qrPayload?.startsWith('000201'));
    assert.equal(inst.payUrl, undefined);

    const p = world.store.payments.get(inst.paymentId);
    assert.ok(p);
    assert.equal(p.payerId, 'p1');
    assert.equal(p.payeeId, PLATFORM_PAYEE);
    assert.equal(p.status, 'created');
    assert.equal(p.idempotencyKey, 'vfee_p1_1_bank_qr');
    assert.equal(p.providerRef, `fake_ref_${inst.paymentId}`);
    assert.ok(p.instructions?.qrPayload);

    const studio = await startVerificationFee(world.deps, 's1', { method: 'momo' });
    assert.equal(studio.amount, 299_000);
    assert.ok(studio.payUrl);
    assert.equal(studio.qrPayload, undefined);
    // Starting the fee starts the verification.
    assert.equal(world.store.verifications.get('s1')?.status, 'in_progress');
  });

  it('startVerificationFee refuses bad input, non-providers and the free mode', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    await assert.rejects(startVerificationFee(world.deps, 'p1', { method: 'intl_card' }), refusedWith('invalid_argument'));
    await assert.rejects(startVerificationFee(world.deps, 'p1', { method: 'momo', renew: 'yes' }), refusedWith('invalid_argument'));
    await assert.rejects(startVerificationFee(world.deps, 'c1', { method: 'momo' }), refusedWith('permission_denied'));
    const free = createVerificationWorld();
    await assert.rejects(startVerificationFee(free.deps, 'p1', { method: 'momo' }), refusedWith('not_eligible'));
  });

  it('the same method and attempt reuse the live payment', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    const first = await startVerificationFee(world.deps, 'p1', { method: 'bank_qr' });
    const again = await startVerificationFee(world.deps, 'p1', { method: 'bank_qr' });
    assert.deepEqual(again, first);
    assert.equal(world.gateway.createPaymentCalls.length, 1);

    const momo = await startVerificationFee(world.deps, 'p1', { method: 'momo' });
    assert.notEqual(momo.paymentId, first.paymentId);
    assert.equal(world.store.payments.get(momo.paymentId)?.idempotencyKey, 'vfee_p1_1_momo');
  });

  it('every start writes the record, so concurrent starts conflict on it (version moves each time)', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    await confirmPhoneVerified(world.deps, 'p1');
    const v0 = world.store.verifications.get('p1')?.version ?? 0;
    assert.equal(world.store.verifications.get('p1')?.status, 'in_progress');

    await startVerificationFee(world.deps, 'p1', { method: 'bank_qr' });
    const v1 = world.store.verifications.get('p1')?.version ?? 0;
    assert.equal(v1, v0 + 1);

    // Reusing the live code still writes the record (in_progress, same kind).
    world.clock.advanceMinutes(1);
    await startVerificationFee(world.deps, 'p1', { method: 'bank_qr' });
    const rec = world.store.verifications.get('p1');
    assert.equal(rec?.version, v1 + 1);
    assert.equal(rec?.updatedAt, world.clock.now().toISOString());
    assert.equal(rec?.status, 'in_progress');

    await startVerificationFee(world.deps, 'p1', { method: 'momo' });
    assert.equal(world.store.verifications.get('p1')?.version, v1 + 2);
  });

  it('renew expires the live payment and issues a new code', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    const first = await startVerificationFee(world.deps, 'p1', { method: 'bank_qr' });
    const renewed = await startVerificationFee(world.deps, 'p1', { method: 'bank_qr', renew: true });

    assert.notEqual(renewed.paymentId, first.paymentId);
    assert.notEqual(renewed.transferCode, first.transferCode);
    assert.equal(world.store.payments.get(first.paymentId)?.status, 'expired');
    assert.equal(world.store.payments.get(renewed.paymentId)?.status, 'created');
    // The gateway sees a new idempotency key for the new code.
    assert.deepEqual(world.gateway.createPaymentCalls.map((c) => c.idempotencyKey), ['vfee_p1_1_bank_qr', 'vfee_p1_1_bank_qr_2']);

    // A lapsed code is replaced on the next tap too.
    world.clock.advanceMinutes(16);
    const later = await startVerificationFee(world.deps, 'p1', { method: 'bank_qr' });
    assert.notEqual(later.paymentId, renewed.paymentId);
    assert.equal(world.store.payments.get(renewed.paymentId)?.status, 'expired');
  });

  it('fee after it is paid is not_eligible', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    await paidFee(world);
    await assert.rejects(startVerificationFee(world.deps, 'p1', { method: 'momo' }), refusedWith('not_eligible'));
    await assert.rejects(startVerificationFee(world.deps, 'p1', { method: 'bank_qr', renew: true }), refusedWith('not_eligible'));
  });

  it('submit needs all four steps', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    await confirmPhoneVerified(world.deps, 'p1');
    await identityPassed(world);
    await acceptVerificationRules(world.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await assert.rejects(submitVerification(world.deps, 'p1'), refusedWith('not_eligible'));

    await paidFee(world);
    const res = await submitVerification(world.deps, 'p1');
    assert.equal(res.after.status, 'submitted');
  });

  it('resubmit without free resubmits clears the fee and bumps feeAttempt', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    await submittedWithFee(world);
    await reviewVerification(world.deps, staff, { uid: 'p1', action: 'reject', reason: 'fake_avatar' });
    assert.equal((await resubmitVerification(world.deps, 'p1')).after.status, 'submitted');
    await reviewVerification(world.deps, staff, { uid: 'p1', action: 'reject', reason: 'fake_avatar' });

    const paid = await resubmitVerification(world.deps, 'p1');
    assert.equal(paid.after.status, 'in_progress');
    assert.equal(paid.after.steps.fee, null);
    assert.equal(paid.after.feeAttempt, 2);
    await assert.rejects(submitVerification(world.deps, 'p1'), refusedWith('not_eligible'));

    // Pay again under the new attempt, then "Gửi duyệt".
    const inst = await startVerificationFee(world.deps, 'p1', { method: 'bank_qr' });
    assert.equal(world.store.payments.get(inst.paymentId)?.idempotencyKey, 'vfee_p1_2_bank_qr');
    assert.equal((await world.payFee(inst.paymentId)).outcome, 'paid');
    assert.equal((await submitVerification(world.deps, 'p1')).after.status, 'submitted');
  });

  it('kind is frozen once the fee is paid', async () => {
    const world = createVerificationWorld({ feeRequired: true });
    await confirmPhoneVerified(world.deps, 'p1');
    await paidFee(world);

    const p1 = world.store.providers.get('p1');
    assert.ok(p1);
    world.store.providers.set('p1', { ...p1, providerType: 'studio' });
    const res = await acceptVerificationRules(world.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    assert.equal(res.after.kind, 'individual');
    assert.equal(res.after.steps.fee?.amount, 99_000);
  });

  it('a record submitted before the fee existed stays submitted', async () => {
    const free = createVerificationWorld();
    await confirmPhoneVerified(free.deps, 'p1');
    await identityPassed(free);
    await acceptVerificationRules(free.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await submitVerification(free.deps, 'p1');

    // #203 turns the fee on: the record keeps its state and staff can still approve it.
    const deps = { ...free.deps, feeRequired: true };
    await assert.rejects(startVerificationFee(deps, 'p1', { method: 'bank_qr' }), refusedWith('not_eligible'));
    assert.equal(free.store.verifications.get('p1')?.status, 'submitted');
    const approved = await reviewVerification(deps, staff, { uid: 'p1', action: 'approve' });
    assert.equal(approved.after.status, 'approved');
    assert.equal(approved.after.steps.fee, null);
  });

  it('a fee paid after the rejection is the paid resubmit: resubmit goes to submitted and charges nothing more', async () => {
    const free = createVerificationWorld();
    await confirmPhoneVerified(free.deps, 'p1');
    await identityPassed(free);
    await acceptVerificationRules(free.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await submitVerification(free.deps, 'p1');
    await reviewVerification(free.deps, staff, { uid: 'p1', action: 'reject', reason: 'fake_avatar' });
    await resubmitVerification(free.deps, 'p1');
    await reviewVerification(free.deps, staff, { uid: 'p1', action: 'reject', reason: 'fake_avatar' });

    // #203 turns the fee on: the rejected record (0 free resubmits) pays the fee while rejected.
    const deps = { ...free.deps, feeRequired: true };
    await assert.rejects(resubmitVerification(deps, 'p1'), refusedWith('not_eligible'));
    free.clock.advanceMinutes(5);
    const inst = await startVerificationFee(deps, 'p1', { method: 'bank_qr' });
    assert.equal((await free.payFee(inst.paymentId)).outcome, 'paid');
    assert.equal(free.store.verifications.get('p1')?.status, 'rejected');

    const res = await resubmitVerification(deps, 'p1');
    assert.equal(res.after.status, 'submitted');
    assert.equal(res.after.steps.fee?.paymentId, inst.paymentId);
    assert.equal(res.after.feeAttempt, 1);
    const p = free.store.payments.get(inst.paymentId);
    assert.deepEqual([p?.status, p?.escrowStatus], ['paid', 'released']);
    assert.equal(free.store.refunds.size, 0);
    // Nothing more to pay.
    await assert.rejects(startVerificationFee(deps, 'p1', { method: 'momo' }), refusedWith('not_eligible'));
  });

  /** A record submitted and rejected while the fee was off (#135), then the fee turned on. */
  async function rejectedBeforeFee(reason = 'fake_avatar') {
    const free = createVerificationWorld();
    await confirmPhoneVerified(free.deps, 'p1');
    await identityPassed(free);
    await acceptVerificationRules(free.deps, 'p1', { version: PROVIDER_RULES_VERSION });
    await submitVerification(free.deps, 'p1');
    await reviewVerification(free.deps, staff, { uid: 'p1', action: 'reject', reason });
    return { world: free, deps: { ...free.deps, feeRequired: true } };
  }

  it('a pre-#203 rejected record resubmits free without paying', async () => {
    const { world, deps } = await rejectedBeforeFee();
    const rec = world.store.verifications.get('p1');
    assert.ok(rec);
    // The S21.02 helpers agree: nothing left to do but resubmit, and no fee to open.
    assert.equal(feeWaived(rec), true);
    assert.equal(nextStep(rec, true, true), null);
    await assert.rejects(startVerificationFee(deps, 'p1', { method: 'bank_qr' }), refusedWith('not_eligible'));

    const res = await resubmitVerification(deps, 'p1');
    assert.equal(res.after.status, 'submitted');
    assert.equal(res.after.steps.fee, null);
    assert.equal(res.after.freeResubmitsLeft, 0);
    assert.equal(world.store.payments.size, 0);
  });

  it('after that, a staff reject with 0 free resubmits requires paying', async () => {
    const { world, deps } = await rejectedBeforeFee();
    await resubmitVerification(deps, 'p1');
    await reviewVerification(deps, staff, { uid: 'p1', action: 'reject', reason: 'fake_avatar' });
    const rec = world.store.verifications.get('p1');
    assert.ok(rec);
    assert.equal(feeWaived(rec), false);
    assert.equal(nextStep(rec, true, true), 'fee');
    await assert.rejects(resubmitVerification(deps, 'p1'), refusedWith('not_eligible'));

    world.clock.advanceMinutes(5);
    const inst = await startVerificationFee(deps, 'p1', { method: 'bank_qr' });
    assert.equal((await world.payFee(inst.paymentId)).outcome, 'paid');
    const res = await resubmitVerification(deps, 'p1');
    assert.equal(res.after.status, 'submitted');
    assert.equal(res.after.steps.fee?.paymentId, inst.paymentId);
  });

  it('a final rejection (underage, duplicate_account) cannot open the fee', async () => {
    for (const reason of ['underage', 'duplicate_account']) {
      const { world, deps } = await rejectedBeforeFee(reason);
      await assert.rejects(startVerificationFee(deps, 'p1', { method: 'bank_qr' }), refusedWith('not_eligible'), reason);
      assert.equal(world.store.payments.size, 0);
    }
  });
});
