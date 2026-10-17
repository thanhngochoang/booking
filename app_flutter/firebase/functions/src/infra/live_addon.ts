import { newUlid, type AddonDeps } from '@photobooking/domain';
import { db as adminDb } from './admin.js';
import { FirestoreAddonStore } from './addon_firestore.js';
import { FirestoreServiceCatalog } from './booking_readers.js';

export function liveAddonDeps(): AddonDeps {
  const firestore = adminDb();
  return {
    addons: new FirestoreAddonStore(firestore),
    services: new FirestoreServiceCatalog(firestore),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}
