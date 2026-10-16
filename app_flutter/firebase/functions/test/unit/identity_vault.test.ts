import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  devEncryptIdForSeed,
  devHashIdSync,
  devIdentityVault,
  devIdentityVaultDecrypt,
} from '../../src/infra/identity_vault.js';
import { EMULATOR_ENV, PROD_ENV } from './verification_support.js';

const ID = '079095001234';

describe('devIdentityVault', () => {
  it('devIdentityVault hashes deterministically and refuses outside emulator/dev', async () => {
    const vault = devIdentityVault(EMULATOR_ENV);
    const h = await vault.hashId(ID);
    assert.match(h, /^[0-9a-f]{64}$/);
    assert.equal(await vault.hashId(ID), h);
    assert.equal(await vault.hashId(` ${ID} `), h, 'trimmed');
    assert.equal(await devIdentityVault({ GCLOUD_PROJECT: 'booking-c1922' }).hashId(ID), h, 'same key on the dev project');
    assert.equal(devHashIdSync(ID), h, 'the seed hashes the same way');
    assert.notEqual(await vault.hashId('079095001235'), h);
    assert.ok(!h.includes(ID));

    assert.throws(() => devIdentityVault(PROD_ENV), /disabled/);
    assert.throws(() => devIdentityVault({ FUNCTIONS_EMULATOR: 'true', GCLOUD_PROJECT: 'photobooking-prod' }), /disabled/);
    assert.throws(() => devIdentityVault({}), /disabled/);
  });

  it('encrypts with a fresh IV each time and decrypts back; tampering fails', async () => {
    const vault = devIdentityVault(EMULATOR_ENV);
    const a = await vault.encryptId(ID);
    const b = await vault.encryptId(ID);
    assert.notEqual(a, b);
    assert.match(a, /^v1:[^:]+:[^:]+:[^:]+$/);
    assert.ok(!a.includes(ID));
    assert.equal(devIdentityVaultDecrypt(a), ID);
    assert.equal(devIdentityVaultDecrypt(b), ID);
    const [v, iv, tag, data] = a.split(':') as [string, string, string, string];
    const flipped = Buffer.from(data, 'base64');
    flipped[0] = (flipped[0] ?? 0) ^ 1;
    assert.throws(() => devIdentityVaultDecrypt([v, iv, tag, flipped.toString('base64')].join(':')));
    assert.throws(() => devIdentityVaultDecrypt('v2:a:b:c'), /version/);
  });

  it('the seed ciphertext is deterministic and decrypts with the same key', () => {
    assert.equal(devEncryptIdForSeed(ID), devEncryptIdForSeed(ID));
    assert.equal(devIdentityVaultDecrypt(devEncryptIdForSeed(ID)), ID);
  });
});
