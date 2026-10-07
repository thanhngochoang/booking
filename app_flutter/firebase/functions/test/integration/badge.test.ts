import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { BADGE_CATALOG, MemoryPushSender, evaluateUserBadges, reconcileBadges } from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { emulatorProject, resetEmulators } from '../../seed/emulator_client.js';
import { AN } from '../../seed/fixtures.js';
import { FirestoreBadgeMetricsReader, FirestoreBadgeStore } from '../../src/infra/badge_firestore.js';
import { FirestoreNotificationStore } from '../../src/infra/notification_firestore.js';
import { FirestoreUserDirectory } from '../../src/infra/user_directory.js';

// Badge evaluator over the Firestore adapters (metrics aggregation queries, catalogue sync,
// collection-group holder query). Needs the emulators and the indexes; CI runs it.

let app: App;
let db: Firestore;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'badge-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
});
after(async () => {
  await deleteApp(app);
});

const deps = (now: Date) => ({
  badges: new FirestoreBadgeStore(db),
  metrics: new FirestoreBadgeMetricsReader(db, () => now),
  notify: { store: new FirestoreNotificationStore(db), push: new MemoryPushSender(), users: new FirestoreUserDirectory(db), clock: { now: () => now } },
  clock: { now: () => now },
});

describe('badges on the emulators', () => {
  test('the catalogue is synced once and a second sync writes nothing', async () => {
    const store = new FirestoreBadgeStore(db);
    await store.syncCatalog(BADGE_CATALOG);
    assert.equal(await store.syncCatalog(BADGE_CATALOG), 0);
    assert.equal((await db.collection('badges').get()).size, BADGE_CATALOG.length);
  });

  test('evaluation awards from real counts and is idempotent', async () => {
    const now = new Date();
    const first = await evaluateUserBadges(deps(now), AN);
    assert.ok(Array.isArray(first.awarded));
    const second = await evaluateUserBadges(deps(now), AN);
    assert.deepEqual(second.awarded, []);
    const progress = (await db.doc(`users/${AN}/private/badgeProgress`).get()).data();
    assert.ok(progress?.entries);
  });

  test('new_member holders past 30 days are re-evaluated and lose the badge', async () => {
    await db.doc('users/old-member').set({ displayName: 'Cũ', role: 'customer', createdAt: new Date(Date.now() - 40 * 86_400_000) });
    await db.doc('users/old-member/badges/new_member').set({
      badgeId: 'new_member',
      uid: 'old-member',
      awardedAt: new Date(Date.now() - 40 * 86_400_000),
      snapshot: { text: 'x' },
    });
    const result = await reconcileBadges(deps(new Date()));
    assert.ok(result.reevaluated >= 1);
    assert.equal((await db.doc('users/old-member/badges/new_member').get()).exists, false);
  });
});
