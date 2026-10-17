import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  ageOn,
  emptyVerification,
  feeFor,
  identityAttemptsLeft,
  maskLegalName,
  nextStep,
  requiredSteps,
  stepDone,
  stepsLeft,
  verificationKindOf,
} from '../src/verification.js';

describe('verification domain state', () => {
  it('kind is studio only for providerType studio', () => {
    assert.equal(verificationKindOf('studio'), 'studio');
    assert.equal(verificationKindOf('individual'), 'individual');
    assert.equal(verificationKindOf('artist'), 'individual');
  });

  it('fees are 99 000 and 299 000', () => {
    assert.equal(feeFor('individual'), 99_000);
    assert.equal(feeFor('studio'), 299_000);
  });

  it('requiredSteps without the fee is phone, identity, rules', () => {
    assert.deepEqual(requiredSteps(false), ['phone', 'identity', 'rules']);
    assert.deepEqual(requiredSteps(true), ['phone', 'fee', 'identity', 'rules']);
  });

  it('nextStep follows the required steps and skips fee when feeRequired is false', () => {
    const now = new Date('2026-10-10T10:00:00.000Z');
    const rec = emptyVerification('p1', 'individual', now);

    // Initial: phone is undone
    assert.equal(nextStep(rec, false, false), 'phone');

    // Phone done: next is identity
    assert.equal(nextStep(rec, true, false), 'identity');

    // Fee step exists but feeRequired is false: still moves phone -> identity -> rules
    const withIdentity = {
      ...rec,
      steps: {
        ...rec.steps,
        identity: {
          method: 'vneid' as const,
          checkedAt: now.toISOString(),
          result: 'passed' as const,
          failure: null,
          maskedName: 'NGUYỄN M** T**',
        },
      },
    };
    assert.equal(nextStep(withIdentity, true, false), 'rules');

    const allDone = {
      ...withIdentity,
      steps: {
        ...withIdentity.steps,
        rules: { acceptedAt: now.toISOString(), version: '2026-10-06' },
      },
    };
    assert.equal(nextStep(allDone, true, false), null);
  });

  it('nextStep follows phone, fee, identity, rules when feeRequired', () => {
    const now = new Date('2026-10-10T10:00:00.000Z');
    const rec = emptyVerification('p1', 'individual', now);
    assert.equal(nextStep(rec, false, true), 'phone');
    assert.equal(nextStep(rec, true, true), 'fee');
    assert.equal(stepsLeft(rec, true, true), 3);

    const paid = { ...rec, steps: { ...rec.steps, fee: { paymentId: 'pay1', amount: 99_000, paidAt: now.toISOString() } } };
    assert.equal(nextStep(paid, true, true), 'identity');
    const withIdentity = {
      ...paid,
      steps: {
        ...paid.steps,
        identity: { method: 'vneid' as const, checkedAt: now.toISOString(), result: 'passed' as const, failure: null, maskedName: 'A' },
      },
    };
    assert.equal(nextStep(withIdentity, true, true), 'rules');
    const allDone = { ...withIdentity, steps: { ...withIdentity.steps, rules: { acceptedAt: now.toISOString(), version: '2026-10-06' } } };
    assert.equal(nextStep(allDone, true, true), null);
    // The fee alone is not enough without the identity step, and identity alone is not enough without the fee.
    const identityNoFee = { ...withIdentity, steps: { ...withIdentity.steps, fee: null } };
    assert.equal(nextStep(identityNoFee, true, true), 'fee');
  });

  it('phoneVerified on the contact counts as the phone step', () => {
    const now = new Date('2026-10-10T10:00:00.000Z');
    const rec = emptyVerification('p1', 'individual', now);
    assert.equal(stepDone(rec, 'phone', false), false);
    assert.equal(stepDone(rec, 'phone', true), true);
  });

  it('a recorded steps.phone without contact.phoneVerified does not count', () => {
    const now = new Date('2026-10-10T10:00:00.000Z');
    const empty = emptyVerification('p1', 'individual', now);
    const rec = { ...empty, steps: { ...empty.steps, phone: { doneAt: now.toISOString() } } };
    assert.equal(stepDone(rec, 'phone', false), false);
    assert.equal(nextStep(rec, false, false), 'phone');
    assert.equal(stepsLeft(rec, false, false), 3);
    assert.equal(stepDone(rec, 'phone', true), true);
  });

  it('stepsLeft counts undone steps', () => {
    const now = new Date('2026-10-10T10:00:00.000Z');
    const rec = emptyVerification('p1', 'individual', now);
    assert.equal(stepsLeft(rec, false, false), 3);
    assert.equal(stepsLeft(rec, true, false), 2);
    assert.equal(stepsLeft(rec, false, true), 4);
  });

  it('ageOn turns 18 on the VN birthday (17:00Z the day before)', () => {
    // Born 2008-10-10.
    // In UTC, 2026-10-09T16:59:00Z is 2026-10-09T23:59:00 in VN -> 17 years old.
    assert.equal(ageOn('2008-10-10', new Date('2026-10-09T16:59:00.000Z')), 17);
    // In UTC, 2026-10-09T17:00:00Z is 2026-10-10T00:00:00 in VN -> 18 years old.
    assert.equal(ageOn('2008-10-10', new Date('2026-10-09T17:00:00.000Z')), 18);
  });

  it('maskLegalName keeps the first word and masks the rest', () => {
    assert.equal(maskLegalName('NGUYỄN MINH TRÍ'), 'NGUYỄN M** T**');
    assert.equal(maskLegalName('AN'), 'AN');
    assert.equal(maskLegalName('HOÀNG THÀNH'), 'HOÀNG T**');
  });

  it('identity attempts reset on a new VN day', () => {
    const now = new Date('2026-10-10T10:00:00.000Z');
    const rec = {
      ...emptyVerification('p1', 'individual', now),
      identityAttempts: { dayKey: '2026-10-10', count: 3 },
    };

    assert.equal(identityAttemptsLeft(rec, now), 0);

    // Next VN day: advance 24h
    const nextDay = new Date('2026-10-11T10:00:00.000Z');
    assert.equal(identityAttemptsLeft(rec, nextDay), 3);
  });
});
