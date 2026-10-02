import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';

/**
 * The Admin SDK's Firestore, initialised on first use (not at import) to keep cold starts short.
 * In the emulator, FIRESTORE_EMULATOR_HOST routes it to the local Firestore.
 * Checks for the default app by name: firebase-functions creates its own named app
 * ("__FIREBASE_FUNCTIONS_SDK__") when it decodes a Firestore trigger event, so getApps() is not
 * empty inside a trigger even though the default app was never initialised.
 */
export function db(): Firestore {
  if (!getApps().some((app) => app.name === '[DEFAULT]')) initializeApp();
  return getFirestore();
}
