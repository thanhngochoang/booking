import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { HttpsError } from 'firebase-functions/v2/https';
import { DomainError, ERROR_CODES, type ErrorCode } from '@photobooking/domain';
import { toHttpsError } from '../../src/callables/errors.js';

describe('toHttpsError', () => {
  test('domain codes travel as message and details.code (what the client reads)', () => {
    const e = toHttpsError(new DomainError('contact_locked'));
    assert.equal(e.code, 'failed-precondition');
    assert.equal(e.message, 'contact_locked');
    assert.deepEqual(e.details, { code: 'contact_locked' });
  });

  test('each domain code has a fitting transport code', () => {
    const expected: Record<ErrorCode, string> = {
      invalid_argument: 'invalid-argument',
      permission_denied: 'permission-denied',
      not_found: 'not-found',
      contact_locked: 'failed-precondition',
      phone_required: 'failed-precondition',
      day_taken: 'already-exists',
      sold_out: 'resource-exhausted',
      deadline_passed: 'failed-precondition',
      limit_exceeded: 'resource-exhausted',
      conflict: 'aborted',
      price_changed: 'failed-precondition',
      not_eligible: 'failed-precondition',
      reauth_required: 'failed-precondition',
      not_accepting_orders: 'failed-precondition',
      blocked: 'failed-precondition',
      payment_attempts_exceeded: 'failed-precondition',
      name_mismatch: 'failed-precondition',
      otp_required: 'failed-precondition',
      otp_invalid: 'failed-precondition',
      otp_expired: 'failed-precondition',
      identity_in_use: 'already-exists',
      underage: 'failed-precondition',
      rate_limited: 'resource-exhausted',
      addon_changed: 'failed-precondition',
      addon_not_applicable: 'failed-precondition',
      pickup_required: 'failed-precondition',
      addon_limit: 'resource-exhausted',
      contact_leak: 'invalid-argument',
      not_ready: 'failed-precondition',
    };
    for (const code of ERROR_CODES) assert.equal(toHttpsError(new DomainError(code)).code, expected[code], code);
  });

  test('reauth_required maps to failed-precondition with details.code', () => {
    const e = toHttpsError(new DomainError('reauth_required'));
    assert.equal(e.code, 'failed-precondition');
    assert.deepEqual(e.details, { code: 'reauth_required' });
  });

  test('not_accepting_orders maps to failed-precondition', () => {
    const e = toHttpsError(new DomainError('not_accepting_orders'));
    assert.equal(e.code, 'failed-precondition');
    assert.deepEqual(e.details, { code: 'not_accepting_orders' });
  });

  test('blocked maps to failed-precondition with details.code blocked', () => {
    const e = toHttpsError(new DomainError('blocked'));
    assert.equal(e.code, 'failed-precondition');
    assert.equal(e.message, 'blocked');
    assert.deepEqual(e.details, { code: 'blocked' });
  });

  test('the four new codes map to failed-precondition', () => {
    for (const code of ['name_mismatch', 'otp_required', 'otp_invalid', 'otp_expired'] as const) {
      const e = toHttpsError(new DomainError(code));
      assert.equal(e.code, 'failed-precondition', code);
      assert.equal(e.message, code);
      assert.deepEqual(e.details, { code });
    }
  });

  test('a domain error with a field carries details.field; without one the details stay {code}', () => {
    const e = toHttpsError(new DomainError('contact_leak', 'name'));
    assert.equal(e.code, 'invalid-argument');
    assert.deepEqual(e.details, { code: 'contact_leak', field: 'name' });
    assert.deepEqual(toHttpsError(new DomainError('addon_limit')).details, { code: 'addon_limit' });
  });

  test('unexpected errors become internal and leak nothing', () => {
    const e = toHttpsError(new Error('Firestore said +84912000001'));
    assert.equal(e.code, 'internal');
    assert.equal(e.message, 'internal');
    assert.deepEqual(e.details, { code: 'internal' });
  });

  test('an HttpsError passes through unchanged', () => {
    const original = new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
    assert.equal(toHttpsError(original), original);
  });
});
