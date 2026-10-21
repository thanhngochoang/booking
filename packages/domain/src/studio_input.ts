/** Input parsing shared by the studio use cases (membership and studio bookings). */

import { DomainError } from './errors.js';
import { isId } from './ids.js';

/** Change-request note, decline reason and return reason. */
export const STUDIO_NOTE_MAX_LENGTH = 300;

/** The callable payload as a plain object, or invalid_argument. */
export function fields(raw: unknown): Record<string, unknown> {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) throw new DomainError('invalid_argument');
  return raw as Record<string, unknown>;
}

/** An opaque id field (uid, booking id), or invalid_argument naming the field. */
export function idField(raw: unknown, key: string): string {
  const v = fields(raw)[key];
  if (!isId(v)) throw new DomainError('invalid_argument', key);
  return v;
}

/** Optional text: absent, null or blank → null; longer than STUDIO_NOTE_MAX_LENGTH → invalid_argument. */
export function optionalText(v: unknown): string | null {
  if (v === undefined || v === null) return null;
  if (typeof v !== 'string') throw new DomainError('invalid_argument');
  const t = v.trim();
  if (t.length > STUDIO_NOTE_MAX_LENGTH) throw new DomainError('invalid_argument');
  return t.length === 0 ? null : t;
}

/** Required text of 1–STUDIO_NOTE_MAX_LENGTH characters after trimming. */
export function requiredText(v: unknown): string {
  const t = optionalText(v);
  if (t === null) throw new DomainError('invalid_argument');
  return t;
}
