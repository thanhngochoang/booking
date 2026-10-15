const ID = /^[A-Za-z0-9_-]{1,64}$/;

/** Opaque id (data-model README §2.1): 1–64 chars of `[A-Za-z0-9_-]`, so never a path. */
export const isId = (v: unknown): v is string => typeof v === 'string' && ID.test(v);

const CROCKFORD = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const MAX_TIME = 2 ** 48 - 1;

export type RandomBytes = (length: number) => Uint8Array;

const systemRandom: RandomBytes = (length) => globalThis.crypto.getRandomValues(new Uint8Array(length));

/** ULID: 10 chars of millisecond time + 16 random chars, Crockford base32, sorts by time. */
export function newUlid(nowMs: number, random: RandomBytes = systemRandom): string {
  if (!Number.isInteger(nowMs) || nowMs < 0 || nowMs > MAX_TIME) {
    throw new RangeError('ULID time must be an integer between 0 and 2^48 - 1');
  }
  let time = '';
  let t = nowMs;
  for (let i = 0; i < 10; i++) {
    time = CROCKFORD.charAt(t % 32) + time;
    t = Math.floor(t / 32);
  }
  const bytes = random(16);
  let rest = '';
  for (let i = 0; i < 16; i++) rest += CROCKFORD.charAt((bytes[i] ?? 0) % 32);
  return time + rest;
}
