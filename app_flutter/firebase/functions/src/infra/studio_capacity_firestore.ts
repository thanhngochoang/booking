/**
 * The derived `availability/{studioId}/days/{day}` `{state: 'full'}` record (#136 Decision 26): written when the
 * studio's open bookings of the day reach its capacity, deleted when a place frees up. Recomputed after every
 * studio booking change (onBookingWrite), member day write (onAvailabilityWrite) and membership or verification
 * change of a member (onPhotographerWrite).
 */

import { FieldPath, Timestamp, type DocumentData, type Firestore } from 'firebase-admin/firestore';
import {
  MAX_MEMBERS_VERIFIED,
  formatVnDate,
  providerTypeOf,
  studioDayMark,
  type StudioDayFacts,
} from '@photobooking/domain';
import {
  AVAILABILITY_COLLECTION,
  STUDIO_DAY_LOAD_COLLECTION,
  isAssignableMember,
  readStudioMemberDays,
} from './booking_firestore.js';

export type StudioDayOutcome = 'set_full' | 'clear_full' | null;

/** Days recomputed per studio after a membership change (one upcoming page). */
export const STUDIO_DAYS_PAGE = 100;

const ids = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []);

/** Recomputes one day of one studio in a transaction. A provider that is not a studio only loses a stale mark. */
export async function recomputeStudioDay(firestore: Firestore, studioId: string, day: string): Promise<StudioDayOutcome> {
  const dayRef = firestore.collection(AVAILABILITY_COLLECTION).doc(studioId).collection('days').doc(day);
  return firestore.runTransaction(async (tx) => {
    const [studioSnap, daySnap, loadSnap] = await tx.getAll(
      firestore.collection('photographers').doc(studioId),
      dayRef,
      firestore.collection(STUDIO_DAY_LOAD_COLLECTION).doc(`${studioId}_${day}`),
    );
    const current = daySnap?.exists ? (daySnap.data() as { state: string }) : null;
    if (providerTypeOf(studioSnap?.data()?.providerType) !== 'studio') {
      if (current?.state !== 'full') return null;
      tx.delete(dayRef);
      return 'clear_full';
    }
    const load: DocumentData = loadSnap?.exists ? (loadSnap.data() ?? {}) : {};
    const facts: StudioDayFacts = {
      studioOff: current?.state === 'off',
      memberDays: await readStudioMemberDays(firestore, tx, studioId, day),
      unassignedIds: ids(load.unassignedIds),
      assignedIds: ids(load.assignedIds),
    };
    const mark = studioDayMark(current, facts);
    if (mark === 'set_full') tx.set(dayRef, { state: 'full', updatedAt: Timestamp.now() });
    if (mark === 'clear_full') tx.delete(dayRef);
    return mark;
  });
}

/** Upcoming day keys (id >= `today`) of one availability calendar, one page. */
async function upcomingDayKeys(firestore: Firestore, uid: string, today: string): Promise<string[]> {
  const snap = await firestore
    .collection(AVAILABILITY_COLLECTION)
    .doc(uid)
    .collection('days')
    .where(FieldPath.documentId(), '>=', today)
    .orderBy(FieldPath.documentId())
    .limit(STUDIO_DAYS_PAGE)
    .get();
  return snap.docs.map((d) => d.id);
}

/**
 * After a membership or gate change, every upcoming day whose answer can change is recomputed (one page of each
 * source from today, Vietnam day): the studio's load days, its own day records (full marks, off days), and each
 * member's own day records, of the remaining members and of `formerMembers` (who just left or were removed). A
 * day none of them has a record for has every member free, so its answer follows `assignableMembers`.
 */
export async function recomputeStudioDays(
  firestore: Firestore,
  studioId: string,
  now: Date,
  formerMembers: readonly string[] = [],
): Promise<number> {
  const today = formatVnDate(now);
  const [loads, members] = await Promise.all([
    firestore
      .collection(STUDIO_DAY_LOAD_COLLECTION)
      .where('studioId', '==', studioId)
      .where('day', '>=', today)
      .orderBy('day')
      .limit(STUDIO_DAYS_PAGE)
      .get(),
    firestore.collection('photographers').where('studioId', '==', studioId).limit(MAX_MEMBERS_VERIFIED).get(),
  ]);
  const calendars = new Set([studioId, ...members.docs.map((m) => m.id), ...formerMembers]);
  const toDo = new Set<string>();
  for (const d of loads.docs) {
    const day = d.data().day;
    if (typeof day === 'string') toDo.add(day);
  }
  for (const keys of await Promise.all([...calendars].map((uid) => upcomingDayKeys(firestore, uid, today)))) {
    for (const day of keys) toDo.add(day);
  }
  for (const day of [...toDo].sort()) await recomputeStudioDay(firestore, studioId, day);
  return toDo.size;
}

/**
 * `photographers/{studioId}.assignableMembers` (public, server-written): how many members the studio can assign
 * (`isAssignableMember`, the same rule as the capacity check). 0 means every day without a member record is full
 * for the app; createBooking refuses such a day with day_taken. Written only when it changes; a provider that is
 * not a studio is left alone. Returns the stored count, or null.
 */
export async function refreshAssignableMembers(firestore: Firestore, studioId: string): Promise<number | null> {
  const ref = firestore.collection('photographers').doc(studioId);
  return firestore.runTransaction(async (tx) => {
    const studio = await tx.get(ref);
    if (!studio.exists || providerTypeOf(studio.data()?.providerType) !== 'studio') return null;
    const members = await tx.get(
      firestore.collection('photographers').where('studioId', '==', studioId).limit(MAX_MEMBERS_VERIFIED),
    );
    const count = members.docs.filter((m) => isAssignableMember(m.data())).length;
    if (studio.data()?.assignableMembers !== count) tx.set(ref, { assignableMembers: count }, { merge: true });
    return count;
  });
}
