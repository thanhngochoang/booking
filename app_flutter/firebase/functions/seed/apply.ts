import type { Auth } from 'firebase-admin/auth';
import type { Firestore } from 'firebase-admin/firestore';
import { SEED_PASSWORD, SEED_USERS, seedDocuments } from './fixtures.js';

/** Writes the seed into the emulators. Idempotent: fixed ids, documents replaced, users updated. */
export async function applySeed(db: Firestore, auth: Auth, now: Date): Promise<void> {
  for (const u of SEED_USERS) {
    const props = { email: u.email, password: SEED_PASSWORD, displayName: u.displayName, emailVerified: true };
    try {
      await auth.updateUser(u.uid, props);
    } catch (e) {
      if ((e as { code?: string }).code !== 'auth/user-not-found') throw e;
      await auth.createUser({ uid: u.uid, ...props });
    }
  }
  const batch = db.batch();
  for (const d of seedDocuments(now)) batch.set(db.doc(d.path), d.data);
  await batch.commit();
}
