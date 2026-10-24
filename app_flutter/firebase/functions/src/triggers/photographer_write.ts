import type { DocumentData } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import {
  acceptingOrdersPatch,
  foldNameKey,
  providerTypeOf,
  recruitMatchKeysOf,
  scorePhotographerSkills,
  refreshNextFreeDate,
  type ScoreSkillsDeps,
  type ScoreSkillsOutcome,
  type DiscoveryDeps,
} from '@photobooking/domain';
import { isAssignableMember } from '../infra/booking_firestore.js';
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

/** `users/{uid}.role` and the server-only `photographers/{uid}.recruitMatchKeys` (S27 Decision 7). */
export interface RecruitMatchKeyWriter {
  role(uid: string): Promise<string | null>;
  set(uid: string, keys: string[]): Promise<void>;
}

function storedKeys(d: DocumentData): string[] {
  return Array.isArray(d.recruitMatchKeys) ? d.recruitMatchKeys.filter((k): k is string => typeof k === 'string') : [];
}

/** A key-order independent JSON form, to compare a field of two snapshots. */
function stableJson(v: unknown): string {
  if (Array.isArray(v)) return `[${v.map(stableJson).join(',')}]`;
  if (v !== null && typeof v === 'object') {
    const o = v as Record<string, unknown>;
    return `{${Object.keys(o).sort().map((k) => `${JSON.stringify(k)}:${stableJson(o[k])}`).join(',')}}`;
  }
  return JSON.stringify(v) ?? 'undefined';
}

/** The inputs of the keys did not change and the keys were written before: nothing to recompute. */
function matchInputsUnchanged(before: DocumentData | undefined, after: DocumentData): boolean {
  if (before === undefined || !Array.isArray(after.recruitMatchKeys)) return false;
  return (['providerType', 'serviceArea', 'specialties'] as const).every((f) => stableJson(before[f]) === stableJson(after[f]));
}

/**
 * Keeps `recruitMatchKeys` = every `a=<area>|s=<specialty>` of the provider (empty for a studio and for an account in
 * customer mode), so `onRecruitPostCreated` finds matching providers with one query. Reads the role once (not for a
 * studio), and not at all when `providerType`, `serviceArea` and `specialties` are unchanged and the keys exist (a
 * role switch is re-synced by `refreshRecruitMatchKeys`); writes only when the sorted list differs, so the re-fire
 * of its own write changes nothing. A missing field counts as an empty list.
 */
export async function syncRecruitMatchKeys(
  input: PhotographerWriteInput,
  writer: RecruitMatchKeyWriter,
): Promise<'written' | 'unchanged' | 'deleted'> {
  const after = input.after;
  if (after === undefined) return 'deleted';
  if (matchInputsUnchanged(input.before, after)) return 'unchanged';
  const isStudio = providerTypeOf(after.providerType) === 'studio';
  const role = isStudio ? null : await writer.role(input.uid);
  const specialties = Array.isArray(after.specialties) ? after.specialties.filter((x): x is string => typeof x === 'string') : [];
  const keys = [...new Set(recruitMatchKeysOf({ role, providerType: after.providerType, serviceArea: after.serviceArea, specialties }))].sort();
  const stored = [...storedKeys(after)].sort();
  if (keys.length === stored.length && keys.every((k, i) => k === stored[i])) return 'unchanged';
  await writer.set(input.uid, keys);
  return 'written';
}

/** The photographer document a role switch re-syncs (`FirestoreRecruitMatchKeys`). */
export interface RecruitMatchKeyStore extends RecruitMatchKeyWriter {
  photographer(uid: string): Promise<DocumentData | undefined>;
}

/**
 * `users/{uid}.role` switched (S09.02 "Chế độ"): the photographer document is not written, so its match keys are
 * re-synced here (customer mode receives no recruit notices). Other user writes read nothing.
 */
export async function refreshRecruitMatchKeys(
  input: { readonly uid: string; readonly before: DocumentData | undefined; readonly after: DocumentData | undefined },
  store: RecruitMatchKeyStore,
): Promise<'written' | 'unchanged' | 'deleted'> {
  if (input.after === undefined || input.before?.role === input.after.role) return 'unchanged';
  const doc = await store.photographer(input.uid);
  if (doc === undefined) return 'deleted';
  // `before: undefined`: the role changed, so the unchanged-inputs shortcut must not apply.
  return syncRecruitMatchKeys({ uid: input.uid, before: undefined, after: doc }, store);
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

const assignable = (d: DocumentData | undefined): boolean => isAssignableMember(d);

/**
 * Studios whose derived `full` days and `assignableMembers` a photographer write can change (#136 Decision 26):
 * both studios of a member who joined, left or was removed (`studioId` is written in the membership commit), the
 * studio of a member who became assignable or stopped being so, a provider that became a studio (its count
 * starts at 0) and one that stopped being a studio (its marks are cleared).
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
  const wasStudio = input.before !== undefined && providerTypeOf(input.before.providerType) === 'studio';
  const isStudioNow = input.after !== undefined && providerTypeOf(input.after.providerType) === 'studio';
  if (wasStudio !== isStudioNow) out.add(input.uid);
  return [...out];
}
