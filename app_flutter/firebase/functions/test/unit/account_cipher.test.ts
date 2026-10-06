import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { aesGcmCipher, encryptSyncForSeed } from '../../src/infra/account_cipher.js';

const KEY = Buffer.alloc(32, 7).toString('base64');

describe('account cipher (AES-256-GCM)', () => {
  it('encrypt then decrypt returns the number', async () => {
    const c = aesGcmCipher(KEY);
    const enc = await c.encrypt('0123456789');
    assert.match(enc, /^v1:[^:]+:[^:]+:[^:]+$/);
    assert.ok(!enc.includes('0123456789'));
    assert.equal(await c.decrypt(enc), '0123456789');
  });

  it('two encryptions of one number differ', async () => {
    const c = aesGcmCipher(KEY);
    assert.notEqual(await c.encrypt('0123456789'), await c.encrypt('0123456789'));
  });

  it('a tampered ciphertext fails', async () => {
    const c = aesGcmCipher(KEY);
    const [v, iv, tag, data] = (await c.encrypt('0123456789')).split(':') as [string, string, string, string];
    const flipped = Buffer.from(data, 'base64');
    flipped[0] = (flipped[0] ?? 0) ^ 1;
    await assert.rejects(c.decrypt([v, iv, tag, flipped.toString('base64')].join(':')));
    const badTag = Buffer.from(tag, 'base64');
    badTag[0] = (badTag[0] ?? 0) ^ 1;
    await assert.rejects(c.decrypt([v, iv, badTag.toString('base64'), data].join(':')));
  });

  it('a truncated tag or a wrong IV length is refused', async () => {
    const c = aesGcmCipher(KEY);
    const [v, iv, tag, data] = (await c.encrypt('0123456789')).split(':') as [string, string, string, string];
    const shortTag = Buffer.from(tag, 'base64').subarray(0, 4).toString('base64');
    await assert.rejects(c.decrypt([v, iv, shortTag, data].join(':')), /bad tag length/);
    const longIv = Buffer.alloc(16, 1).toString('base64');
    await assert.rejects(c.decrypt([v, longIv, tag, data].join(':')), /bad IV length/);
  });

  it('another key cannot decrypt, and an unknown version is refused', async () => {
    const enc = await aesGcmCipher(KEY).encrypt('0123456789');
    await assert.rejects(aesGcmCipher(Buffer.alloc(32, 9).toString('base64')).decrypt(enc));
    await assert.rejects(aesGcmCipher(KEY).decrypt(enc.replace(/^v1/, 'v2')), /unknown ciphertext version/);
  });

  it('a key that is not 32 bytes is refused', () => {
    assert.throws(() => aesGcmCipher(Buffer.alloc(16).toString('base64')), /32 bytes/);
    assert.throws(() => encryptSyncForSeed('', 'x'), /32 bytes/);
  });

  it('the seed helper writes the same format', async () => {
    assert.equal(await aesGcmCipher(KEY).decrypt(encryptSyncForSeed(KEY, '0123456789')), '0123456789');
  });
});
