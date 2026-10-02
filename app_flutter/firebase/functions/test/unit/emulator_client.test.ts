import { afterEach, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { callCallable, emulatorProject } from '../../seed/emulator_client.js';

// `firebase emulators:exec` sets the Firestore and Auth hosts but never FUNCTIONS_EMULATOR_HOST:
// only the callable client may require it (final review item 1).
const KEYS = ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FUNCTIONS_EMULATOR_HOST', 'GCLOUD_PROJECT'] as const;
let saved: Record<string, string | undefined> = {};

beforeEach(() => {
  saved = Object.fromEntries(KEYS.map((k) => [k, process.env[k]]));
  process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
  process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
  process.env.GCLOUD_PROJECT = 'demo-nag';
  delete process.env.FUNCTIONS_EMULATOR_HOST;
});

afterEach(() => {
  for (const k of KEYS) {
    const v = saved[k];
    if (v === undefined) Reflect.deleteProperty(process.env, k);
    else process.env[k] = v;
  }
});

describe('emulator client guard split', () => {
  test('emulatorProject (used by resetEmulators and the Admin SDK) needs only Firestore and Auth', () => {
    assert.equal(emulatorProject(), 'demo-nag');
  });

  test('callCallable refuses without FUNCTIONS_EMULATOR_HOST, before any request', async () => {
    await assert.rejects(callCallable('getContactLink', {}), /FUNCTIONS_EMULATOR_HOST/);
  });

  test('callCallable accepts a non-demo project only when asked (try_contact_link); hosts still checked', async () => {
    process.env.GCLOUD_PROJECT = 'booking-c1922';
    await assert.rejects(callCallable('getContactLink', {}, undefined, { allowAnyProject: true }), /FUNCTIONS_EMULATOR_HOST/);
    process.env.FUNCTIONS_EMULATOR_HOST = 'example.com:5001';
    await assert.rejects(callCallable('getContactLink', {}, undefined, { allowAnyProject: true }), /FUNCTIONS_EMULATOR_HOST/);
    process.env.FUNCTIONS_EMULATOR_HOST = '127.0.0.1:5001';
    await assert.rejects(callCallable('getContactLink', {}), /demo-/);
  });
});
