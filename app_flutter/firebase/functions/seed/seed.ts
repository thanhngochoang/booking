import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { applySeed } from './apply.js';
import { SEED_BOOKINGS, SEED_USERS } from './fixtures.js';

// CLI: `npm run seed` (scripts/backend-local.sh runs it). Refuses anything but local emulators.
const LOCAL = /^(127\.0\.0\.1|localhost|0\.0\.0\.0|\[::1\]):\d+$/;
for (const key of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST']) {
  const value = process.env[key];
  if (value === undefined || !LOCAL.test(value)) {
    console.error(`Refusing to seed: ${key} must point at a local emulator (got ${value ?? 'nothing'}).`);
    process.exit(1);
  }
}
const project = process.env.GCLOUD_PROJECT;
if (project === undefined || project === '') {
  console.error('Refusing to seed: GCLOUD_PROJECT is not set.');
  process.exit(1);
}

initializeApp({ projectId: project });
await applySeed(getFirestore(), getAuth(), new Date());
console.log(`Seeded ${SEED_USERS.length} users and ${SEED_BOOKINGS.length} bookings into ${project} (emulators).`);
console.log('Accounts: app_flutter/firebase/functions/seed/README.md');
