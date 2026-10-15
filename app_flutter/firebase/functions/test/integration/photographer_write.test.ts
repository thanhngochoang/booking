import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { emulatorProject, resetEmulators } from '../../seed/emulator_client.js';

// The real trigger on the Functions emulator: Admin writes to photographers/{uid} fire it.
// CI only (rule 2026-10-02); not run while executing the plan.

const P = 'skills-p1';
const OTHER = 'skills-p2';
let app: App;
let db: Firestore;

const post = (author: string) => ({
  authorId: author,
  photographerId: author,
  serviceId: 'seed-service-portrait',
  imageUrls: ['https://example.test/1.jpg'],
  createdAt: Timestamp.now(),
});

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'skills-test');
  db = getFirestore(app);
  await db.doc('posts/ev-own').set(post(P));
  await db.doc('posts/ev-theirs').set(post(OTHER));
});
after(async () => {
  await deleteApp(app);
});

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
const skillsOf = async (uid: string) =>
  (await db.doc(`photographers/${uid}`).get()).data()?.skills as Record<string, unknown> | undefined;

async function scored(uid: string, timeoutMs = 20_000): Promise<Record<string, unknown>> {
  const end = Date.now() + timeoutMs;
  for (;;) {
    const s = await skillsOf(uid);
    if (s?.completeness !== undefined) return s;
    if (Date.now() > end) throw new Error('onPhotographerWrite did not score the profile in time');
    await sleep(250);
  }
}

const clientSkills = {
  schemaVersion: 1,
  specialties: [
    { id: 'portrait', level: 3, evidencePostIds: ['ev-theirs'] },
    { id: 'couple', level: 2, evidencePostIds: ['ev-own', 'ev-gone'] },
  ],
  styles: ['film'],
  extras: [],
  languages: ['vi'],
  audiences: [],
  yearsExperience: null,
};

describe('onPhotographerWrite on the emulators', () => {
  test('foreign and missing evidence is removed, the level drops and the score is written', async () => {
    await db.doc(`photographers/${P}`).set({ onboardingComplete: false, verified: false, skills: clientSkills, updatedAt: Timestamp.now() });
    const s = await scored(P);
    assert.deepEqual(s.specialties, [
      { id: 'portrait', level: 2, evidencePostIds: [] },
      { id: 'couple', level: 2, evidencePostIds: ['ev-own'] },
    ]);
    assert.equal(s.completeness, 85);
    assert.equal(s.completenessNext, 'audiences');
    assert.equal(s.completenessNextAfter, 95);
    assert.ok(s.updatedAt instanceof Timestamp);
    assert.ok(s.evidenceRemovedAt instanceof Timestamp);
  });

  test('saving the same skills again writes nothing more', async () => {
    const first = await scored(P);
    // What the app sends next time: the cleaned client part plus a new top-level updatedAt.
    await db.doc(`photographers/${P}`).set({ skills: { ...clientSkills, specialties: first.specialties }, updatedAt: Timestamp.now() }, { merge: true });
    await sleep(5_000);
    const again = await skillsOf(P);
    assert.ok(again !== undefined);
    assert.equal((again.updatedAt as Timestamp).toMillis(), (first.updatedAt as Timestamp).toMillis());
    assert.equal(again.completeness, 85);
    assert.equal(again.completenessNextAfter, 95);
  });

  test('a profile without skills is left alone', async () => {
    await db.doc(`photographers/${OTHER}`).set({ onboardingComplete: false, verified: false, bio: 'Chưa có kỹ năng' });
    await sleep(3_000);
    assert.equal(await skillsOf(OTHER), undefined);
  });
});
