import { DomainError } from './errors.js';

export interface StoredCounter {
  value: number | null;
  at: string | null;
}

export interface CounterPatch {
  value: number;
  at: string;
}

/**
 * Computes the patch to update an event-driven counter.
 * Returns null if the incoming event is stale (stored.at >= eventAt)
 * or if the value is unchanged at the exact same timestamp.
 */
export function counterPatch(
  stored: StoredCounter,
  recount: number,
  eventAt: string,
): CounterPatch | null {
  if (!Number.isInteger(recount) || recount < 0) {
    throw new DomainError('invalid_argument');
  }

  if (stored.at !== null) {
    const storedTime = new Date(stored.at).getTime();
    const eventTime = new Date(eventAt).getTime();

    if (storedTime > eventTime) {
      return null;
    }
    if (storedTime === eventTime && stored.value === recount) {
      return null;
    }
  }

  return {
    value: recount,
    at: eventAt,
  };
}
