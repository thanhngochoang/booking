import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import type { AccountCipher } from '@photobooking/domain';

// AES-256-GCM for the payout account number (docs: plan 10b Decision 6). The key is 32 bytes,
// base64, from the secret PAYOUT_ACCOUNT_KEY. Format `v1:<iv>:<tag>:<data>` (base64 parts); `v1`
// is the key version for a later rotation. Every value gets a fresh 12-byte IV and the tag is
// checked on decrypt, so a tampered value fails instead of decoding to garbage.

function keyOf(keyB64: string): Buffer {
  const key = Buffer.from(keyB64, 'base64');
  if (key.length !== 32) throw new Error('PAYOUT_ACCOUNT_KEY must be 32 bytes, base64');
  return key;
}

function seal(key: Buffer, plain: string, iv: Buffer = randomBytes(12)): string {
  const c = createCipheriv('aes-256-gcm', key, iv);
  const data = Buffer.concat([c.update(plain, 'utf8'), c.final()]);
  return ['v1', iv.toString('base64'), c.getAuthTag().toString('base64'), data.toString('base64')].join(':');
}

export function aesGcmCipher(keyB64: string): AccountCipher {
  const key = keyOf(keyB64);
  return {
    encrypt: async (plain) => seal(key, plain),
    decrypt: async (enc) => {
      const [v, iv, tag, data] = enc.split(':');
      if (v !== 'v1' || !iv || !tag || !data) throw new Error('unknown ciphertext version');
      const ivBytes = Buffer.from(iv, 'base64');
      const tagBytes = Buffer.from(tag, 'base64');
      if (ivBytes.length !== 12) throw new Error('invalid ciphertext: bad IV length');
      if (tagBytes.length !== 16) throw new Error('invalid ciphertext: bad tag length');
      const d = createDecipheriv('aes-256-gcm', key, ivBytes, { authTagLength: 16 });
      d.setAuthTag(tagBytes);
      return Buffer.concat([d.update(Buffer.from(data, 'base64')), d.final()]).toString('utf8');
    },
  };
}

/**
 * Same format, synchronous: for `seedDocuments(now)` (the emulator key only). The IV is fixed so
 * the seed stays deterministic; real values always get a fresh IV from `aesGcmCipher`.
 */
export function encryptSyncForSeed(keyB64: string, plain: string): string {
  return seal(keyOf(keyB64), plain, Buffer.alloc(12, 1));
}
