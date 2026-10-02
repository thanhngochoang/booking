// Same rules as app_flutter/lib/core/phone.dart (plan 2a), so client and server agree.
const VN = /^(?:\+84|0)([35789]\d{8})$/;
const VN_E164 = /^\+84[35789]\d{8}$/;
const INTERNATIONAL = /^\+\d{8,15}$/;

const compact = (s: string): string => s.replace(/[\s.\-()]/g, '');

/**
 * E.164 for a valid number, else null. Spaces, dots, dashes and brackets are ignored.
 * `international` also accepts other countries (`+` and 8–15 digits), for WhatsApp.
 */
export function normalizePhone(input: string, options: { international?: boolean } = {}): string | null {
  const s = compact(input);
  const national = VN.exec(s)?.[1];
  if (national !== undefined) return `+84${national}`;
  // A malformed +84 number must not slip through as "international".
  if (options.international === true && !s.startsWith('+84') && INTERNATIONAL.test(s)) return s;
  return null;
}

/** The stored form of a Vietnamese number: `+84` and 9 digits starting with 3, 5, 7, 8 or 9. */
export const isVnE164 = (v: unknown): v is string => typeof v === 'string' && VN_E164.test(v);

/** Any stored international number: `+` and 8–15 digits (WhatsApp's own number). */
export const isInternationalE164 = (v: unknown): v is string => typeof v === 'string' && INTERNATIONAL.test(v);
