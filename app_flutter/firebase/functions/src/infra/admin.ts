import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';

/**
 * The Admin SDK's Firestore, initialised on first use (not at import) to keep cold starts short.
 * In the emulator, FIRESTORE_EMULATOR_HOST routes it to the local Firestore.
 */
export function db(): Firestore {
  if (getApps().length === 0) initializeApp();
  return getFirestore();
}
