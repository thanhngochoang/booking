/**
 * Small helpers shared by the S27 use cases (recruit posts, collaborations, collab jobs). Internal: not
 * re-exported from `index.ts` (the names are generic).
 */

import { DomainError, type ErrorCode } from './errors.js';
import { isId } from './ids.js';
import type { NotifyDeps } from './notification_ports.js';

export function fail(code: ErrorCode, field?: string): never {
  throw new DomainError(code, field);
}

/** A counter one lower, never below 0. */
export const decrement = (n: number): number => Math.max(0, n - 1);

/** The request object of a callable; `invalid_argument` for anything else. */
export function objectOf(raw: unknown): Record<string, unknown> {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) fail('invalid_argument');
  return raw as Record<string, unknown>;
}

/** The id at `r[field]`; `invalid_argument` with that field otherwise. */
export function idOf(r: Record<string, unknown>, field: string): string {
  const v = r[field];
  return isId(v) ? v : fail('invalid_argument', field);
}

/** Runs a post-commit notification; a failure is reported, never thrown (the write already happened). */
export async function safely(deps: { readonly notify: NotifyDeps }, uid: string, send: () => Promise<unknown>): Promise<void> {
  try {
    await send();
  } catch (e) {
    deps.notify.onPushError?.(uid, e);
  }
}
