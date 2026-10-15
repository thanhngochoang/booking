import { createCipheriv, createDecipheriv, createHash, createHmac, randomBytes } from 'node:crypto';
import type { IdentityVault } from '@photobooking/domain';
import { fakePaymentsAllowed } from './fake_payments.js';

// DEV ONLY (Decision 7). Fixed, labelled keys so the emulator, the dev project and the seed agree
// on the same hash for the same id number. They protect nothing: this vault refuses to run unless
// fake payments are allowed (the dev project, or the emulator on `demo-*`). The KMS-backed vault
// for production is Deferred; until it exists the identity callables answer `not_eligible` there.
const DEV_HMAC_KEY = createHash('sha256').update('photobooking/dev-only/identity-hmac/v1').digest();
const DEV_AES_KEY = createHash('sha256').update('photobooking/dev-only/identity-aes/v1').digest();

type Env = Readonly<Record<string, string | undefined>>;

/** HMAC-SHA256 (hex) of the trimmed id number under the dev key: the `identity_hashes/{idHash}` id. */
export function devHashIdSync(idNumber: string): string {
  return createHmac('sha256', DEV_HMAC_KEY).update(idNumber.trim()).digest('hex');
}

/** AES-256-GCM under the dev key, `v1:<iv>:<tag>:<data>` (base64 parts). `iv` is for the seed only. */
export function devEncryptIdSync(idNumber: string, iv: Buffer = randomBytes(12)): string {
  const cipher = createCipheriv('aes-256-gcm', DEV_AES_KEY, iv);
  const data = Buffer.concat([cipher.update(idNumber.trim(), 'utf8'), cipher.final()]);
  return ['v1', iv.toString('base64'), cipher.getAuthTag().toString('base64'), data.toString('base64')].join(':');
}

/** The seed's ciphertext: fixed IV so `seedDocuments(now)` stays deterministic. */
export function devEncryptIdForSeed(idNumber: string): string {
  return devEncryptIdSync(idNumber, Buffer.alloc(12, 2));
}

export function devIdentityVaultDecrypt(enc: string): string {
  const [v, iv, tag, data] = enc.split(':');
  if (v !== 'v1' || !iv || !tag || !data) throw new Error('unknown ciphertext version');
  const decipher = createDecipheriv('aes-256-gcm', DEV_AES_KEY, Buffer.from(iv, 'base64'), { authTagLength: 16 });
  decipher.setAuthTag(Buffer.from(tag, 'base64'));
  return Buffer.concat([decipher.update(Buffer.from(data, 'base64')), decipher.final()]).toString('utf8');
}

/** The dev vault; throws outside the emulator on `demo-*` and the dev project. */
export function devIdentityVault(env: Env = process.env): IdentityVault {
  if (!fakePaymentsAllowed(env)) {
    throw new Error('devIdentityVault is disabled outside the emulator and the dev project');
  }
  return {
    hashId: async (idNumber) => devHashIdSync(idNumber),
    encryptId: async (idNumber) => devEncryptIdSync(idNumber),
  };
}
