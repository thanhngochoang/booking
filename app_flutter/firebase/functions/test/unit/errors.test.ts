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
      membership_conflict: 'failed-precondition',
      cooldown: 'failed-precondition',
      member_busy: 'failed-precondition',
      studio_full: 'resource-exhausted',
      outside_schedule: 'failed-precondition',
      slot_taken: 'failed-precondition',
      day_conflict: 'failed-precondition',
      schedule_limit: 'resource-exhausted',
      spot_archived: 'failed-precondition',
      schedule_has_bookings: 'failed-precondition',
      no_match: 'failed-precondition',
      offer_expired: 'failed-precondition',
      already_assigned: 'failed-precondition',
      outside_service_area: 'failed-precondition',
      collab_full: 'resource-exhausted',
      recruit_blocked: 'failed-precondition',
      spot_managed: 'failed-precondition',
      not_spot_manager: 'failed-precondition',
      day_closed: 'failed-precondition',
      venue_consent_required: 'failed-precondition',
      business_required: 'failed-precondition',
      wrong_day: 'failed-precondition',
      too_early: 'failed-precondition',
      refunded: 'failed-precondition',
      sold_out_day: 'resource-exhausted',
      not_your_pass: 'permission-denied',
      already_checked_in: 'already-exists',
    };
    for (const code of ERROR_CODES) assert.equal(toHttpsError(new DomainError(code)).code, expected[code], code);
  });

  test('no_match, offer_expired, already_assigned, outside_service_area map to failed-precondition', () => {
    for (const code of ['no_match', 'offer_expired', 'already_assigned', 'outside_service_area'] as const) {
      const e = toHttpsError(new DomainError(code));
      assert.equal(e.code, 'failed-precondition', code);
      assert.equal(e.message, code);
      assert.deepEqual(e.details, { code });
    }
  });

  // S27 (#151) Decision 10
  test('collab_full → resource-exhausted', () => {
    const e = toHttpsError(new DomainError('collab_full'));
    assert.equal(e.code, 'resource-exhausted');
    assert.deepEqual(e.details, { code: 'collab_full' });
  });

  test('recruit_blocked → failed-precondition', () => {
    const e = toHttpsError(new DomainError('recruit_blocked'));
    assert.equal(e.code, 'failed-precondition');
    assert.deepEqual(e.details, { code: 'recruit_blocked' });
  });

  test('a field error carries details.field (S27 contact in a post title)', () => {
    const e = toHttpsError(new DomainError('invalid_argument', 'title.contact'));
    assert.equal(e.code, 'invalid-argument');
    assert.deepEqual(e.details, { code: 'invalid_argument', field: 'title.contact' });
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

  test('spot error codes preserve field and copy details', () => {
    const e1 = toHttpsError(new DomainError('day_conflict', 'days', { days: [{ day: '2026-10-18', reason: 'booked' }] }));
    assert.equal(e1.code, 'failed-precondition');
    assert.equal(e1.message, 'day_conflict');
    assert.deepEqual(e1.details, {
      code: 'day_conflict',
      field: 'days',
      days: [{ day: '2026-10-18', reason: 'booked' }],
    });

    const e2 = toHttpsError(new DomainError('schedule_has_bookings', 'days', { days: [{ day: '2026-10-18', count: 2 }] }));
    assert.equal(e2.code, 'failed-precondition');
    assert.deepEqual(e2.details, {
      code: 'schedule_has_bookings',
      field: 'days',
      days: [{ day: '2026-10-18', count: 2 }],
    });

    // cancelSpotSchedule: no field, the blocked days still travel.
    const cancel = toHttpsError(
      new DomainError('schedule_has_bookings', undefined, { days: [{ day: '2026-10-18', count: 2 }] }),
    );
    assert.deepEqual(cancel.details, {
      code: 'schedule_has_bookings',
      days: [{ day: '2026-10-18', count: 2 }],
    });

    const e3 = toHttpsError(new DomainError('contact_leak', 'name'));
    assert.equal(e3.code, 'invalid-argument');
    assert.deepEqual(e3.details, { code: 'contact_leak', field: 'name' });
  });

  test('an HttpsError passes through unchanged', () => {
    const original = new HttpsError('unauthenticated', 'permission_denied', { code: 'permission_denied' });
    assert.equal(toHttpsError(original), original);
  });
});
