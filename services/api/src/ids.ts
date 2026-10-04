import { monotonicFactory } from 'ulidx';

const nextUlid = monotonicFactory();

/** data-model README §2.1: opaque, immutable, ≤ 64 chars of [A-Za-z0-9_-]. */
export const ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

/** New ids are ULIDs (26 chars, time ordered). Firebase uids are kept as they are. */
export function newId(now: number = Date.now()): string {
  return nextUlid(now);
}

export function isValidId(v: unknown): v is string {
  return typeof v === 'string' && ID_PATTERN.test(v);
}
