import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { isInternationalE164, isVnE164, normalizePhone } from '../src/index.js';

// Same vectors as app_flutter/test/core/phone_test.dart (plan 2a, Task 1).
describe('normalizePhone', () => {
  const valid: Record<string, string> = {
    '0903123456': '+84903123456',
    '+84 903 123 456': '+84903123456',
    '0903.123.456': '+84903123456',
    '(090) 312-3456': '+84903123456',
    '+84903123456': '+84903123456',
    '0321234567': '+84321234567',
  };
  for (const [input, e164] of Object.entries(valid)) {
    test(`accepts ${input}`, () => assert.equal(normalizePhone(input), e164));
  }

  const invalid = [
    '', '090312345', '0123456789', '09031234567', '0203123456',
    '+84 023 123 456', '+14155552671', 'abc', '0903 123 45a',
  ];
  for (const input of invalid) {
    test(`rejects "${input}"`, () => assert.equal(normalizePhone(input), null));
  }

  test('international accepts other countries, still rejects malformed +84', () => {
    assert.equal(normalizePhone('+1 415 555 2671', { international: true }), '+14155552671');
    assert.equal(normalizePhone('+84012345678', { international: true }), null);
    assert.equal(normalizePhone('+123', { international: true }), null);
  });
});

describe('stored-number checks', () => {
  test('isVnE164 only accepts the stored Vietnamese form', () => {
    assert.equal(isVnE164('+84903123456'), true);
    for (const v of ['0903123456', '+8490312345', '+84123456789', '+14155552671', 84903123456, null, undefined]) {
      assert.equal(isVnE164(v), false, String(v));
    }
  });

  test('isInternationalE164 accepts + and 8-15 digits', () => {
    assert.equal(isInternationalE164('+14155552671'), true);
    assert.equal(isInternationalE164('+84903123456'), true);
    for (const v of ['14155552671', '+123', '+1234567890123456', '+1 415', 5]) {
      assert.equal(isInternationalE164(v), false, String(v));
    }
  });
});
