import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { emulatorProject, resetEmulators } from '../../seed/emulator_client.js';

// CI only (rule 2026-10-02); written, not run locally.
// Integration tests verifying discovery triggers:
// 1. a booked availability day moves nextFreeDate
// 2. like, unlike, like ends at likeCount 1
// 3. a new active package updates catalog/explore and startingPrice

const P = 'disc-p1';
const POST_ID = 'disc-post1';
let app: App;
let db: Firestore;

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'discovery-test');
  db = getFirestore(app);
});

after(async () => {
  await deleteApp(app);
});

async function waitFor<T>(fn: () => Promise<T | null | undefined>, timeoutMs = 20_000): Promise<T> {
  const end = Date.now() + timeoutMs;
  for (;;) {
    const val = await fn();
    if (val !== null && val !== undefined) return val;
    if (Date.now() > end) throw new Error('Condition timed out');
    await sleep(250);
  }
}

describe('discovery triggers on emulators', () => {
  test('a booked availability day moves nextFreeDate', async () => {
    const today = '2026-10-10';
    await db.doc(`photographers/${P}`).set({
      onboardingComplete: true,
      verified: true,
      acceptingOrders: true,
      stats: { nextFreeDate: today, score: 0 },
      updatedAt: Timestamp.now(),
    });

    // Book today
    await db.doc(`availability/${P}/days/${today}`).set({
      state: 'booked',
      updatedAt: Timestamp.now(),
    });

    // The trigger moves nextFreeDate past today
    const moved = await waitFor(async () => {
      const snap = await db.doc(`photographers/${P}`).get();
      const nfd = snap.data()?.stats?.nextFreeDate;
      if (nfd && nfd > today) return nfd;
      return null;
    });

    assert.ok(moved > today);
  });

  test('like, unlike, like ends at likeCount 1', async () => {
    await db.doc(`posts/${POST_ID}`).set({
      likeCount: 0,
      saveCount: 0,
      createdAt: Timestamp.now(),
    });

    // Like
    await db.doc(`likes/u1_${POST_ID}`).set({ userId: 'u1', postId: POST_ID, createdAt: Timestamp.now() });
    await waitFor(async () => {
      const snap = await db.doc(`posts/${POST_ID}`).get();
      return snap.data()?.likeCount === 1 ? true : null;
    });

    // Unlike
    await db.doc(`likes/u1_${POST_ID}`).delete();
    await waitFor(async () => {
      const snap = await db.doc(`posts/${POST_ID}`).get();
      return snap.data()?.likeCount === 0 ? true : null;
    });

    // Like again
    await db.doc(`likes/u1_${POST_ID}`).set({ userId: 'u1', postId: POST_ID, createdAt: Timestamp.now() });
    const finalCount = await waitFor(async () => {
      const snap = await db.doc(`posts/${POST_ID}`).get();
      return snap.data()?.likeCount === 1 ? 1 : null;
    });

    assert.equal(finalCount, 1);
  });

  test('a new active package updates catalog/explore and startingPrice', async () => {
    const sId = 'srv-new';
    await db.doc(`photographers/${P}/services/${sId}`).set({
      name: 'Gói mới',
      price: 800_000,
      active: true,
      specialty: 'portrait',
      coverUrl: 'https://example.test/cover.jpg',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });

    // startingPrice updated on photographer
    await waitFor(async () => {
      const snap = await db.doc(`photographers/${P}`).get();
      return snap.data()?.startingPrice === 800_000 ? true : null;
    });

    // catalog/explore updated with portrait
    await waitFor(async () => {
      const snap = await db.doc('catalog/explore').get();
      const cat = snap.data()?.specialties?.portrait;
      if (cat && cat.serviceCount >= 1 && cat.coverUrl === 'https://example.test/cover.jpg') return true;
      return null;
    });
  });
});
