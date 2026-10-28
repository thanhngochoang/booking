/**
 * S30 passes (#223 Decision 7) on Firestore: `passes/{code8}` (server only) and the customer's copies
 * `bookings/{id}/private/pass` and `events/{e}/registrations/{r}/private/pass` (`{code}`). The scan adapter
 * and the rules come with Task 6; these mappers are what the payment transactions write today.
 */

import { Timestamp, type DocumentData, type DocumentReference, type Firestore } from 'firebase-admin/firestore';
import type { PassRecord, PrivatePassRef } from '@photobooking/domain';

export const PASSES_COLLECTION = 'passes';

export function passToFirestore(p: PassRecord): DocumentData {
  return {
    customerId: p.customerId,
    day: p.day,
    bookingId: p.bookingId,
    eventId: p.eventId,
    registrationIds: [...p.registrationIds],
    createdAt: Timestamp.fromDate(new Date(p.createdAt)),
    waivedCheckedInAt: p.waivedCheckedInAt ? Timestamp.fromDate(new Date(p.waivedCheckedInAt)) : null,
  };
}

export function passFromFirestore(code8: string, d: DocumentData | undefined): PassRecord | null {
  if (d === undefined || typeof d.customerId !== 'string' || typeof d.day !== 'string') return null;
  const createdAt = d.createdAt instanceof Timestamp ? d.createdAt.toDate().toISOString() : String(d.createdAt ?? '');
  return {
    code8,
    customerId: d.customerId,
    day: d.day,
    bookingId: typeof d.bookingId === 'string' ? d.bookingId : null,
    eventId: typeof d.eventId === 'string' ? d.eventId : null,
    registrationIds: Array.isArray(d.registrationIds) ? d.registrationIds.filter((x: unknown): x is string => typeof x === 'string') : [],
    createdAt,
    waivedCheckedInAt: d.waivedCheckedInAt instanceof Timestamp ? d.waivedCheckedInAt.toDate().toISOString() : null,
  };
}

/** The customer's copy of a pass. */
export function privatePassRef(firestore: Firestore, ref: PrivatePassRef): DocumentReference {
  const parent = 'bookingId' in ref
    ? firestore.collection('bookings').doc(ref.bookingId)
    : firestore.collection('events').doc(ref.eventId).collection('registrations').doc(ref.regId);
  return parent.collection('private').doc('pass');
}
