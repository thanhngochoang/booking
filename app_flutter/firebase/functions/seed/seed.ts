import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { applySeed } from './apply.js';
import { assertLocalEmulators } from './local_guard.js';
import { SEED_BOOKINGS, SEED_USERS } from './fixtures.js';

// CLI: `npm run seed` (scripts/backend-local.sh runs it). Refuses anything but local emulators.
// The dev project id need not be `demo-*`; the emulator hosts are still checked.
const guard = { allowAnyProject: true } as const;
let project: string;
try {
  project = assertLocalEmulators(guard);
} catch (e) {
  console.error((e as Error).message);
  process.exit(1);
}

initializeApp({ projectId: project });
await applySeed(getFirestore(), getAuth(), new Date(), guard);
console.log(`Seeded ${SEED_USERS.length} users and ${SEED_BOOKINGS.length} bookings into ${project} (emulators).`);
console.log('Accounts: app_flutter/firebase/functions/seed/README.md');
