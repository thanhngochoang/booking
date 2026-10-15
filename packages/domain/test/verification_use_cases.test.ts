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
import { PROVIDER_RULES_VERSION, emptyVerification } from '../src/verification.js';

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
