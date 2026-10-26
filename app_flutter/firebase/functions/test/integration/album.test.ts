import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { appendNewPost, newUlid } from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, BINH, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';
import { FirestoreAlbumStore } from '../../src/infra/album_firestore.js';

// The real album callables and the onPostCreated trigger on the Functions emulator, through
// FirestoreAlbumStore. Needs the emulators; CI runs it (npm run test:integration).
// Every test builds its own albums and posts, so the tests do not depend on each other's state.

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'album-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const call = (name: string, uid: string, data: unknown) => callCallable(name, data, tokens.get(uid));
const data = async (path: string) => (await db.doc(path).get()).data() ?? {};

async function newAlbum(uid: string, title: string): Promise<string> {
  const res = await call('createAlbum', uid, { title });
  const albumId = (res.result as { albumId?: string } | undefined)?.albumId;
  assert.ok(albumId, res.text);
  return albumId;
}

async function addPost(uid: string, images: number, extra: Record<string, unknown> = {}): Promise<string> {
  const id = newUlid(Date.now());
  await db.doc(`posts/${id}`).set({
    kind: 'work',
    authorId: uid,
    photographerId: uid,
    serviceId: 'seed-service-portrait',
    imageUrls: Array.from({ length: images }, (_, i) => `https://seed.test/${id}/${i}.jpg`),
    caption: 'test',
    likeCount: 0,
    saveCount: 0,
    createdAt: Timestamp.now(),
    ...extra,
  });
  return id;
}

// 60 s: the first test runs right after applySeed, whose documents queue many triggers on the Functions
// emulator; on a CI runner onPostCreated can wait behind them for more than 20 s.
async function waitFor(check: () => Promise<boolean>, what: string): Promise<void> {
  const end = Date.now() + 60_000;
  while (Date.now() < end) {
    if (await check()) return;
    await new Promise((r) => setTimeout(r, 200));
  }
  assert.fail(`timed out waiting for ${what}`);
}

describe('album trigger on the emulators', () => {
  test('a post created with albumId lands last in the album', async () => {
    const albumId = await newAlbum(AN, 'Trigger một');
    const first = await addPost(AN, 2, { albumId });
    await waitFor(async () => (await data(`posts/${first}`)).albumPosition === 1, 'first post placed');
    const second = await addPost(AN, 3, { albumId });
    await waitFor(async () => (await data(`posts/${second}`)).albumPosition === 2, 'second post placed');
    const album = await data(`albums/${albumId}`);
    assert.equal(album.postCount, 2);
    assert.equal(album.mediaCount, 5);
    assert.equal(album.visible, true);
  });

  test('concurrent creates get consecutive positions', async () => {
    const albumId = await newAlbum(AN, 'Trigger song song');
    const ids = await Promise.all([1, 2, 3, 4].map(() => addPost(AN, 1, { albumId })));
    await waitFor(async () => (await data(`albums/${albumId}`)).postCount === 4, 'four posts counted');
    const positions = (await Promise.all(ids.map(async (id) => (await data(`posts/${id}`)).albumPosition as number))).sort((a, b) => a - b);
    assert.deepEqual(positions, [1, 2, 3, 4]);
  });

  test('a retried trigger does not count twice', async () => {
    const albumId = await newAlbum(AN, 'Trigger thử lại');
    const id = await addPost(AN, 2, { albumId });
    await waitFor(async () => (await data(`posts/${id}`)).albumPosition === 1, 'post placed');
    // The same event delivered again runs the use case a second time on the real store.
    const store = new FirestoreAlbumStore(db);
    const outcome = await appendNewPost({ albums: store, clock: { now: () => new Date() }, ids: { newId: () => newUlid(Date.now()) } }, id);
    assert.equal(outcome, 'skipped');
    const album = await data(`albums/${albumId}`);
    assert.equal(album.postCount, 1);
    assert.equal(album.mediaCount, 2);
  });

  test('a post published by the client SDK path naming a deleted album succeeds and stays unsorted', async () => {
    // Rules apply: Firestore REST with the photographer's ID token and a server-time createdAt,
    // the same shape the app publishes.
    const gone = await newAlbum(AN, 'Sắp xóa');
    assert.equal((await call('deleteAlbum', AN, { albumId: gone })).status, 200);
    const id = newUlid(Date.now());
    const host = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
    const name = `projects/${emulatorProject()}/databases/(default)/documents/posts/${id}`;
    const res = await fetch(`http://${host}/v1/projects/${emulatorProject()}/databases/(default)/documents:commit`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tokens.get(AN)}` },
      body: JSON.stringify({
        writes: [
          {
            update: {
              name,
              fields: {
                kind: { stringValue: 'work' },
                authorId: { stringValue: AN },
                photographerId: { stringValue: AN },
                serviceId: { stringValue: 'seed-service-portrait' },
                imageUrls: { arrayValue: { values: [{ stringValue: 'https://seed.test/x.jpg' }] } },
                caption: { stringValue: 'client' },
                albumId: { stringValue: gone },
                likeCount: { integerValue: '0' },
                saveCount: { integerValue: '0' },
              },
            },
            updateTransforms: [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }],
            currentDocument: { exists: false },
          },
        ],
      }),
    });
    assert.equal(res.status, 200, await res.text());
    await waitFor(async () => !('albumId' in (await data(`posts/${id}`))), 'albumId removed');
    assert.equal('albumPosition' in (await data(`posts/${id}`)), false);
  });

  test('a post written by the Admin SDK naming a missing album stays unsorted', async () => {
    const id = await addPost(AN, 1, { albumId: 'seed-album-missing' });
    await waitFor(async () => !('albumId' in (await data(`posts/${id}`))), 'albumId removed');
    assert.equal('albumPosition' in (await data(`posts/${id}`)), false);
  });
});

describe('album callables on the emulators', () => {
  test('movePostsToAlbum moves and compacts', async () => {
    const from = await newAlbum(AN, 'Nguồn');
    const to = await newAlbum(AN, 'Đích');
    const a = await addPost(AN, 1, { albumId: from });
    await waitFor(async () => (await data(`posts/${a}`)).albumPosition === 1, 'a placed');
    const b = await addPost(AN, 2, { albumId: from });
    await waitFor(async () => (await data(`posts/${b}`)).albumPosition === 2, 'b placed');
    const c = await addPost(AN, 3, { albumId: from });
    await waitFor(async () => (await data(`posts/${c}`)).albumPosition === 3, 'c placed');

    const res = await call('movePostsToAlbum', AN, { albumId: to, postIds: [a] });
    assert.equal(res.status, 200, res.text);

    const target = await data(`albums/${to}`);
    assert.equal(target.postCount, 1);
    assert.equal(target.mediaCount, 1);
    assert.equal(target.visible, true);
    assert.equal((await data(`posts/${a}`)).albumId, to);
    assert.equal((await data(`posts/${a}`)).albumPosition, 1);
    const source = await data(`albums/${from}`);
    assert.equal(source.postCount, 2);
    assert.equal(source.mediaCount, 5);
    assert.equal((await data(`posts/${b}`)).albumPosition, 1);
    assert.equal((await data(`posts/${c}`)).albumPosition, 2);
  });

  test("someone else's album or post is permission_denied", async () => {
    const mine = await newAlbum(AN, 'Của An');
    const theirs = await addPost(BINH, 1);
    const res = await call('movePostsToAlbum', AN, { albumId: mine, postIds: [theirs] });
    assert.equal(res.error?.status, 'PERMISSION_DENIED', res.text);
    const res2 = await call('deleteAlbum', BINH, { albumId: mine });
    assert.equal(res2.error?.status, 'PERMISSION_DENIED', res2.text);
  });

  test('passing 200 posts is limit_exceeded and writes nothing', async () => {
    const full = await newAlbum(AN, 'Đầy');
    const source = await newAlbum(AN, 'Nguồn nhỏ');
    // 200 posts already in the full album (positions 1..200), written directly with the Admin SDK.
    const batch = db.batch();
    for (let i = 1; i <= 200; i++) {
      batch.set(db.doc(`posts/limit-${full}-${i}`), {
        kind: 'work', authorId: AN, photographerId: AN, serviceId: 'seed-service-portrait',
        imageUrls: ['https://seed.test/x.jpg'], caption: 'full', likeCount: 0, saveCount: 0,
        createdAt: Timestamp.now(), albumId: full, albumPosition: i,
      });
    }
    batch.update(db.doc(`albums/${full}`), { postCount: 200, mediaCount: 200, visible: true });
    await batch.commit();
    const moving = await addPost(AN, 1, { albumId: source });
    await waitFor(async () => (await data(`posts/${moving}`)).albumPosition === 1, 'moving post placed');

    const res = await call('movePostsToAlbum', AN, { albumId: full, postIds: [moving] });
    assert.equal(res.error?.status, 'RESOURCE_EXHAUSTED', res.text);
    assert.equal(res.error?.message, 'limit_exceeded');

    // Nothing was written: the post is still in its source album, both albums keep their counts.
    const post = await data(`posts/${moving}`);
    assert.equal(post.albumId, source);
    assert.equal(post.albumPosition, 1);
    assert.equal((await data(`albums/${full}`)).postCount, 200);
    const src = await data(`albums/${source}`);
    assert.equal(src.postCount, 1);
    assert.equal(src.mediaCount, 1);
    assert.equal((await data(`posts/limit-${full}-200`)).albumPosition, 200);
  });

  test('more than 50 posts in one move is invalid_argument', async () => {
    const album = await newAlbum(AN, 'Quá nhiều');
    const ids = Array.from({ length: 51 }, () => newUlid(Date.now()));
    const res = await call('movePostsToAlbum', AN, { albumId: album, postIds: ids });
    assert.equal(res.error?.status, 'INVALID_ARGUMENT', res.text);
  });

  test('deleteAlbum clears its posts and renumbers the other albums', async () => {
    const first = await newAlbum(AN, 'Xóa một');
    const second = await newAlbum(AN, 'Xóa hai');
    const p = await addPost(AN, 1, { albumId: first });
    await waitFor(async () => (await data(`posts/${p}`)).albumPosition === 1, 'post placed');
    const before = (await data(`albums/${second}`)).position as number;
    const res = await call('deleteAlbum', AN, { albumId: first });
    assert.equal(res.status, 200, res.text);
    assert.equal((await db.doc(`albums/${first}`).get()).exists, false);
    assert.equal('albumId' in (await data(`posts/${p}`)), false);
    assert.equal((await data(`albums/${second}`)).position, before - 1);
  });
});
