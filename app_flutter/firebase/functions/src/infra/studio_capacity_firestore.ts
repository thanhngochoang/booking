/**
 * The derived `availability/{studioId}/days/{day}` `{state: 'full'}` record (#136 Decision 26): written when the
 * studio's open bookings of the day reach its capacity, deleted when a place frees up. Recomputed after every
 * studio booking change (onBookingWrite), member day write (onAvailabilityWrite) and membership or verification
 * change of a member (onPhotographerWrite).
 */

import { Timestamp, type DocumentData, type Firestore } from 'firebase-admin/firestore';
import {
  MAX_MEMBERS_VERIFIED,
  acceptsOrders,
  formatVnDate,
  providerTypeOf,
  studioDayMark,
  type StudioDayFacts,
} from '@photobooking/domain';
import { AVAILABILITY_COLLECTION, STUDIO_DAY_LOAD_COLLECTION } from './booking_firestore.js';

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
    const members = await tx.get(
      firestore.collection('photographers').where('studioId', '==', studioId).limit(MAX_MEMBERS_VERIFIED),
    );
    const memberDays = members.empty
      ? []
      : await tx.getAll(
          ...members.docs.map((m) => firestore.collection(AVAILABILITY_COLLECTION).doc(m.id).collection('days').doc(day)),
        );
    const load: DocumentData = loadSnap?.exists ? (loadSnap.data() ?? {}) : {};
    const facts: StudioDayFacts = {
      studioOff: current?.state === 'off',
      memberDays: members.docs.map((m, i) => {
        const p = m.data();
        return { uid: m.id, verified: p.deletionPending !== true && acceptsOrders(p), free: memberDays[i]?.exists !== true };
      }),
      unassignedIds: ids(load.unassignedIds),
      assignedIds: ids(load.assignedIds),
    };
    const mark = studioDayMark(current, facts);
    if (mark === 'set_full') tx.set(dayRef, { state: 'full', updatedAt: Timestamp.now() });
    if (mark === 'clear_full') tx.delete(dayRef);
    return mark;
  });
}

/**
 * After a membership change every upcoming day the studio already holds bookings on (its `studio_day_load`
 * docs) or already shows as full is recomputed, one page of each from today (Vietnam day).
 */
export async function recomputeStudioDays(firestore: Firestore, studioId: string, now: Date): Promise<number> {
  const today = formatVnDate(now);
  const [loads, days] = await Promise.all([
    firestore
      .collection(STUDIO_DAY_LOAD_COLLECTION)
      .where('studioId', '==', studioId)
      .where('day', '>=', today)
      .orderBy('day')
      .limit(STUDIO_DAYS_PAGE)
      .get(),
    firestore
      .collection(AVAILABILITY_COLLECTION)
      .doc(studioId)
      .collection('days')
      .where('state', '==', 'full')
      .limit(STUDIO_DAYS_PAGE)
      .get(),
  ]);
  const toDo = new Set<string>();
  for (const d of loads.docs) {
    const day = d.data().day;
    if (typeof day === 'string') toDo.add(day);
  }
  for (const d of days.docs) if (d.id >= today) toDo.add(d.id);
  for (const day of [...toDo].sort()) await recomputeStudioDay(firestore, studioId, day);
  return toDo.size;
}
