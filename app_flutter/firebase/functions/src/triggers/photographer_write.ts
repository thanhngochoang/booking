import type { DocumentData } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import {
  acceptsOrders,
  acceptingOrdersPatch,
  foldNameKey,
  providerTypeOf,
  scorePhotographerSkills,
  refreshNextFreeDate,
  type ScoreSkillsDeps,
  type ScoreSkillsOutcome,
  type DiscoveryDeps,
} from '@photobooking/domain';
import type { NameKeyStore } from './user_write.js';

/** The two snapshots of one `photographers/{uid}` write; `after` undefined when it was deleted. */
export interface PhotographerWriteInput {
  readonly uid: string;
  readonly before: DocumentData | undefined;
  readonly after: DocumentData | undefined;
}

export async function handlePhotographerWrite(input: PhotographerWriteInput, deps: ScoreSkillsDeps): Promise<ScoreSkillsOutcome> {
  const outcome = await scorePhotographerSkills(
    { uid: input.uid, before: input.before?.skills, after: input.after?.skills, deleted: input.after === undefined },
    deps,
  );
  if (outcome === 'malformed') {
    // The rules refuse such writes; reaching here means an Admin write or a rules gap.
    logger.warn('onPhotographerWrite: skills do not match the schema; nothing written', { uid: input.uid });
  } else if (outcome === 'written' || outcome === 'stale') {
    logger.info('onPhotographerWrite', { uid: input.uid, outcome });
  }
  return outcome;
}

/** Writes the derived `photographers/{uid}.acceptingOrders` flag (Admin SDK; clients cannot). */
export interface AcceptingOrdersWriter {
  set(uid: string, acceptingOrders: boolean): Promise<void>;
}

/**
 * Keeps `acceptingOrders` equal to `verified && onboardingComplete`. The trigger fires again on
 * its own write; that second event finds the flag equal and writes nothing, so it cannot loop.
 */
export async function syncAcceptingOrders(
  input: PhotographerWriteInput,
  writer: AcceptingOrdersWriter,
): Promise<'written' | 'unchanged' | 'deleted'> {
  if (input.after === undefined) return 'deleted';
  const patch = acceptingOrdersPatch(input.after);
  if (patch === null) return 'unchanged';
  await writer.set(input.uid, patch.acceptingOrders);
  return 'written';
}

/** Events older than this are dropped instead of retried (deployed with `retry: true`). */
export const MAX_EVENT_AGE_MS = 60 * 60 * 1000;

/** gRPC INVALID_ARGUMENT (3) or PERMISSION_DENIED (7): retrying the same event cannot succeed. */
export function isPermanentFirestoreError(e: unknown): boolean {
  if (typeof e !== 'object' || e === null || !('code' in e)) return false;
  return e.code === 3 || e.code === 7;
}

export interface PhotographerEventInput extends PhotographerWriteInput {
  /** `event.time` (RFC 3339). */
  readonly time: string;
}

/**
 * Retry policy around handlePhotographerWrite: an event older than 1 hour is dropped and a
 * permanent Firestore error ends the event (both logged as errors with the uid only, never data
 * or messages); other failures are rethrown so Functions retries. A dropped event leaves the
 * profile unscored or with an out-of-date score; the next write of the document scores it
 * (the `unchanged` guard holds only when the stored score matches the stored skills).
 * `deps` is called only for an event that is handled.
 */
export async function handlePhotographerEvent(
  input: PhotographerEventInput,
  deps: () => ScoreSkillsDeps,
  acceptingOrders: AcceptingOrdersWriter,
  now: Date = new Date(),
  discovery?: DiscoveryDeps,
): Promise<ScoreSkillsOutcome | 'expired' | 'failed'> {
  const age = now.getTime() - Date.parse(input.time);
  if (age > MAX_EVENT_AGE_MS) {
    logger.error('onPhotographerWrite: event older than 1 hour dropped; the next save scores the profile', { uid: input.uid });
    return 'expired';
  }
  try {
    const outcome = await handlePhotographerWrite(input, deps());
    const sync = await syncAcceptingOrders(input, acceptingOrders);
    if (sync === 'written') logger.info('onPhotographerWrite: acceptingOrders synced', { uid: input.uid });

    // Discovery: onPhotographerWrite gains refreshNextFreeDate(uid) when acceptingOrders or
    // onboardingComplete turned true, or stats.nextFreeDate is missing on a bookable profile.
    if (discovery && input.after !== undefined) {
      const beforeAcc = input.before?.acceptingOrders === true;
      const afterAcc = input.after.acceptingOrders === true;
      const beforeOnb = input.before?.onboardingComplete === true;
      const afterOnb = input.after.onboardingComplete === true;
      const missingNextFree = input.after.stats?.nextFreeDate == null;

      const becameBookable = (!beforeAcc && afterAcc) || (!beforeOnb && afterOnb);
      const isBookable = afterAcc || afterOnb;

      if (becameBookable || (isBookable && missingNextFree)) {
        await refreshNextFreeDate(discovery, input.uid);
      }
    }

    return outcome;
  } catch (e) {
    if (!isPermanentFirestoreError(e)) throw e;
    logger.error('onPhotographerWrite: permanent Firestore error; not retried', { uid: input.uid, code: (e as { code: number }).code });
    return 'failed';
  }
}

/**
 * Heals a missing `nameKey` (S26.02 search, Decision 19) from `users/{uid}.displayName`, once: the write that
 * follows finds the key present. A name change is `onUserWrite`'s.
 */
export async function healNameKey(input: PhotographerWriteInput, store: NameKeyStore): Promise<'written' | 'present' | 'deleted'> {
  if (input.after === undefined) return 'deleted';
  if (typeof input.after.nameKey === 'string') return 'present';
  await store.setNameKey(input.uid, foldNameKey((await store.displayName(input.uid)) ?? ''));
  return 'written';
}

function studioIdOf(d: DocumentData | undefined): string | null {
  return typeof d?.studioId === 'string' && d.studioId !== '' ? d.studioId : null;
}

function assignable(d: DocumentData | undefined): boolean {
  return d !== undefined && d.deletionPending !== true && acceptsOrders(d);
}

/**
 * Studios whose derived `full` days a photographer write can change (#136 Decision 26): both studios of a member
 * who joined, left or was removed (`studioId` is written in the membership commit), the studio of a member who
 * became assignable or stopped being so, and a provider that stopped being a studio (its marks are cleared).
 */
export function studiosToRecompute(input: PhotographerWriteInput): string[] {
  const out = new Set<string>();
  const was = studioIdOf(input.before);
  const now = studioIdOf(input.after);
  if (was !== now) {
    if (was !== null) out.add(was);
    if (now !== null) out.add(now);
  } else if (now !== null && assignable(input.before) !== assignable(input.after)) {
    out.add(now);
  }
  if (providerTypeOf(input.before?.providerType) === 'studio' && providerTypeOf(input.after?.providerType) !== 'studio') {
    out.add(input.uid);
  }
  return [...out];
}
