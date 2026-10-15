import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CALLABLE_OPTIONS, REGION } from '../../src/config.js';

test('callables run in asia-southeast1 with small, bounded instances', () => {
  assert.equal(REGION, 'asia-southeast1');
  assert.equal(CALLABLE_OPTIONS.region, REGION);
  assert.equal(CALLABLE_OPTIONS.memory, '256MiB');
  assert.equal(CALLABLE_OPTIONS.timeoutSeconds, 10);
  assert.equal(CALLABLE_OPTIONS.maxInstances, 10);
  assert.equal(CALLABLE_OPTIONS.minInstances, 0);
});

test('App Check is not enforced in phase 1 (the emulators do not verify it)', () => {
  assert.equal(CALLABLE_OPTIONS.enforceAppCheck, false);
});
