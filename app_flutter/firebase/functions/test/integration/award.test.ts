import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { newUlid } from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { ADMIN, AN, BINH, DUNG, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';

// The real award callables, the onAwardWrite trigger and the A1 hook on the Functions emulator,
// through FirestoreAwardStore / FirestoreTierStore. Needs the emulators; CI runs it
// (npm run test:integration). AN builds a tier from scratch; DUNG starts as an artist with three
// approved seed awards; each test owns its data, but the tests run in order on shared accounts.

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'award-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const call = (name: string, uid: string, data: unknown) => callCallable(name, data, tokens.get(uid));
const data = async (path: string) => (await db.doc(path).get()).data() ?? {};

async function newAward(uid: string): Promise<string> {
  const awardId = newUlid(Date.now());
  const res = await call('createAward', uid, {
    awardId,
    competition: 'Sony World Photography Awards',
    year: 2025,
    result: 'gold',
    proofLinks: ['https://example.com/winners'],
  });
  assert.deepEqual(res.result, { awardId }, res.text);
  return awardId;
}

async function approve(awardId: string): Promise<void> {
  const res = await call('reviewAward', ADMIN, { awardId, action: 'approve' });
  assert.deepEqual(res.result, { status: 'approved' }, res.text);
}

async function waitFor(check: () => Promise<boolean>, what: string): Promise<void> {
  const end = Date.now() + 20_000;
  while (Date.now() < end) {
    if (await check()) return;
    await new Promise((r) => setTimeout(r, 200));
  }
  assert.fail(`timed out waiting for ${what}`);
}

describe('award callables on the emulators', () => {
  test('a customer cannot create an award; a photographer can', async () => {
    const refused = await callCallable('createAward', {}, tokens.get(SEED_USERS[0]?.uid ?? ''));
    assert.equal(refused.error?.status, 'PERMISSION_DENIED', refused.text);
    const id = await newAward(AN);
    const award = await data(`awards/${id}`);
    assert.equal(award.status, 'pending');
    assert.equal(award.photographerId, AN);
    assert.deepEqual((await data(`awardProofs/${id}`)).links, ['https://example.com/winners']);
  });

  test('only the admin claim may review', async () => {
    const id = await newAward(AN);
    const res = await call('reviewAward', AN, { awardId: id, action: 'approve' });
    assert.equal(res.error?.status, 'PERMISSION_DENIED', res.text);
    assert.equal((await data(`awards/${id}`)).status, 'pending');
    await approve(id);
    const award = await data(`awards/${id}`);
    assert.equal(award.status, 'approved');
    assert.equal(award.reviewedBy, ADMIN);
    assert.ok((await data(`awardProofs/${id}`)).purgeAfter instanceof Timestamp);
    const audit = await db.collection('awardAudit').where('awardId', '==', id).get();
    assert.equal(audit.size, 1);
  });

  test('a third approval turns the photographer gold', async () => {
    // AN already has one approved award from the previous test; two more make three.
    const second = await newAward(AN);
    const third = await newAward(AN);
    await approve(second);
    assert.notEqual((await data(`photographers/${AN}`)).providerType, 'artist');
    await approve(third);
    await waitFor(async () => (await data(`photographers/${AN}`)).providerType === 'artist', 'artist tier');
    const doc = await data(`photographers/${AN}`);
    assert.equal(doc.approvedAwardCount, 3);
    assert.ok(doc.artistSince instanceof Timestamp);
  });

  test('recompute without a change writes nothing', async () => {
    const before = await data(`photographers/${AN}`);
    const pending = await newAward(AN); // fires onAwardWrite; pending does not count
    await new Promise((r) => setTimeout(r, 2_000));
    assert.ok(pending);
    const after = await data(`photographers/${AN}`);
    assert.equal((after.updatedAt as Timestamp).toMillis(), (before.updatedAt as Timestamp).toMillis());
    assert.equal((after.artistSince as Timestamp).toMillis(), (before.artistSince as Timestamp).toMillis());
  });

  test('deleting an approved award recounts', async () => {
    const approved = await db.collection('awards').where('photographerId', '==', AN).where('status', '==', 'approved').get();
    const victim = approved.docs[0]?.id;
    assert.ok(victim);
    const res = await call('deleteAward', AN, { awardId: victim });
    assert.deepEqual(res.result, {}, res.text);
    await waitFor(async () => (await data(`photographers/${AN}`)).approvedAwardCount === 2, 'recount');
    const doc = await data(`photographers/${AN}`);
    assert.equal(doc.providerType, 'individual');
    assert.equal('artistSince' in doc, false);
    assert.equal((await db.doc(`awards/${victim}`).get()).exists, false);
    assert.equal((await db.doc(`awardProofs/${victim}`).get()).exists, false);
  });

  test('editing an approved award sends it back to pending and drops the count', async () => {
    const approved = await db.collection('awards').where('photographerId', '==', AN).where('status', '==', 'approved').get();
    const first = approved.docs[0];
    assert.ok(first);
    const res = await call('updateAward', AN, {
      awardId: first.id,
      competition: 'Sony World Photography Awards 2025',
      year: 2025,
      result: 'gold',
      proofLinks: ['https://example.com/winners'],
    });
    assert.deepEqual(res.result, {}, res.text);
    assert.equal((await data(`awards/${first.id}`)).status, 'pending');
    await waitFor(async () => (await data(`photographers/${AN}`)).approvedAwardCount === 1, 'recount after edit');
  });

  test('the A1 hook recomputes after studio -> individual', async () => {
    // DUNG is an artist with three approved seed awards. Studio keeps its type, so the switch
    // clears artistSince; going back to individual must bring the artist tier back.
    const toStudio = await call('setProviderType', DUNG, { type: 'studio' });
    assert.deepEqual(toStudio.result, { providerType: 'studio' }, toStudio.text);
    assert.equal((await data(`photographers/${DUNG}`)).providerType, 'studio');
    const back = await call('setProviderType', DUNG, { type: 'individual' });
    assert.equal(back.status, 200, back.text);
    await waitFor(async () => (await data(`photographers/${DUNG}`)).providerType === 'artist', 'artist again');
    assert.equal((await data(`photographers/${DUNG}`)).approvedAwardCount, 3);
  });

  test('a client write to awards is refused by the rules', async () => {
    // Rules apply: Firestore REST with the photographer's ID token.
    const id = newUlid(Date.now());
    const host = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
    const project = emulatorProject();
    const res = await fetch(`http://${host}/v1/projects/${project}/databases/(default)/documents:commit`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tokens.get(BINH)}` },
      body: JSON.stringify({
        writes: [
          {
            update: {
              name: `projects/${project}/databases/(default)/documents/awards/${id}`,
              fields: {
                photographerId: { stringValue: BINH },
                status: { stringValue: 'approved' },
              },
            },
            currentDocument: { exists: false },
          },
        ],
      }),
    });
    assert.equal(res.status, 403, await res.text());
    assert.equal((await db.doc(`awards/${id}`).get()).exists, false);
  });
});
