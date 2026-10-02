import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { assertLocalEmulators } from '../../seed/local_guard.js';

const ok = { FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080', FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099', GCLOUD_PROJECT: 'demo-nag' };

describe('assertLocalEmulators', () => {
  test('accepts local hosts and a demo project', () => {
    assert.equal(assertLocalEmulators({}, ok), 'demo-nag');
  });
  test('unset hosts throw', () => {
    assert.throws(() => assertLocalEmulators({}, { GCLOUD_PROJECT: 'demo-nag' }), /FIRESTORE_EMULATOR_HOST/);
    assert.throws(() => assertLocalEmulators({}, { ...ok, FIREBASE_AUTH_EMULATOR_HOST: undefined }), /FIREBASE_AUTH_EMULATOR_HOST/);
  });
  test('a look-alike host throws', () => {
    assert.throws(() => assertLocalEmulators({}, { ...ok, FIRESTORE_EMULATOR_HOST: 'localhost.evil.com:80' }), /FIRESTORE_EMULATOR_HOST/);
  });
  test('a real project throws', () => {
    assert.throws(() => assertLocalEmulators({}, { ...ok, GCLOUD_PROJECT: 'booking-c1922' }), /demo-/);
  });
  test('functions host is required only on request', () => {
    assert.doesNotThrow(() => assertLocalEmulators({}, ok));
    assert.throws(() => assertLocalEmulators({ functions: true }, ok), /FUNCTIONS_EMULATOR_HOST/);
    assert.doesNotThrow(() => assertLocalEmulators({ functions: true }, { ...ok, FUNCTIONS_EMULATOR_HOST: '127.0.0.1:5001' }));
  });
  test('allowAnyProject skips only the project rule', () => {
    const env = { ...ok, GCLOUD_PROJECT: 'booking-c1922' };
    assert.doesNotThrow(() => assertLocalEmulators({ allowAnyProject: true }, env));
    assert.throws(() => assertLocalEmulators({ allowAnyProject: true }, { ...env, FIRESTORE_EMULATOR_HOST: 'x:1' }));
  });
});
