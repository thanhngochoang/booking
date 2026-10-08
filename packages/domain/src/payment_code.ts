/**
 * Transfer codes: the "Nội dung" a customer types into the bank app so an incoming
 * transfer can be matched to a payment (#129, Decision 5).
 * Pure: a 32-bit FNV-1a hash of the payment id, no crypto, works with any id format.
 */

/** No 0, O, 1, I, L or U: 30 characters that survive being read off a screen. */
export const TRANSFER_CODE_ALPHABET = '23456789ABCDEFGHJKMNPQRSTVWXYZ';

const CODE_LENGTH = 6;
const PREFIX = 'PB';

function fnv1a32(input: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < input.length; i++) {
    h ^= input.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

/**
 * `"PB " + 6 characters`, the lowest 6 base-30 digits of the id's hash (30^6 < 2^32),
 * most significant digit first. Not unique: the caller regenerates the id on a clash.
 */
export function transferCodeFor(paymentId: string): string {
  let h = fnv1a32(paymentId);
  const base = TRANSFER_CODE_ALPHABET.length;
  const digits: string[] = [];
  for (let i = 0; i < CODE_LENGTH; i++) {
    digits.push(TRANSFER_CODE_ALPHABET.charAt(h % base));
    h = Math.floor(h / base);
  }
  return `${PREFIX} ${digits.reverse().join('')}`;
}

/**
 * Every transfer code that can be read out of a bank memo, in order and without repeats.
 * Upper-cases the text and drops everything but A-Z and 0-9 first, so "pb7f3k2q chuyen tien"
 * and "CK PB-7F3K2Q den Minh Tri" both give `['PB 7F3K2Q']`. Candidates may overlap; the
 * caller takes the first one that names an existing payment.
 */
export function transferCodesIn(content: string): readonly string[] {
  const text = content.toUpperCase().replace(/[^A-Z0-9]/g, '');
  const found: string[] = [];
  for (let i = 0; i + PREFIX.length + CODE_LENGTH <= text.length; i++) {
    if (!text.startsWith(PREFIX, i)) continue;
    const body = text.slice(i + PREFIX.length, i + PREFIX.length + CODE_LENGTH);
    if ([...body].every((ch) => TRANSFER_CODE_ALPHABET.includes(ch))) {
      const code = `${PREFIX} ${body}`;
      if (!found.includes(code)) found.push(code);
    }
  }
  return found;
}
