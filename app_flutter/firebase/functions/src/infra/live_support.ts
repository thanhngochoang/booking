/**
 * Production wiring for SupportDeps.
 */

import { newUlid, type SupportDeps } from '@photobooking/domain';
import { db } from './admin.js';
import { FirestoreDisplayNames, FirestoreSupportStore } from './support_firestore.js';

export function liveSupportDeps(): SupportDeps {
  const firestore = db();
  return {
    store: new FirestoreSupportStore(firestore),
    names: new FirestoreDisplayNames(firestore),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}
