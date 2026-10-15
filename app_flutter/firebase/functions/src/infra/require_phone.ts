import type { Firestore } from 'firebase-admin/firestore';
import { requireCustomerPhone } from '@photobooking/domain';
import { firestoreUserContactReader } from './firestore.js';

/**
 * Server-side `phone_required` guard for transitionBooking(requested) and registerEvent (later plans):
 *   const requirePhone = makeRequirePhone(db());
 *   const phone = await requirePhone(uid); // E.164, or throws DomainError('phone_required')
 * One document read (`users/{uid}/private/contact`).
 */
export function makeRequirePhone(firestore: Firestore): (uid: string) => Promise<string> {
  const contacts = firestoreUserContactReader(firestore);
  return (uid) => requireCustomerPhone(contacts, uid);
}
