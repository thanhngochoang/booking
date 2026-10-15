import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';
import { newUlid } from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, LAN, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';
import { bucketUrl, callAs, makeCustomer, publishFreeEvent, waitFor, type SocialEnv } from './event_social_support.js';

// Hashtag timeline on the emulators: onPostCreated links posts, shareEventPost writes event_share
// posts, moderateEventTimeline keeps postCount. Needs the emulators; CI runs it.

let env: SocialEnv;

before(async () => {
  await resetEmulators();
  const app = initializeApp({ projectId: emulatorProject() }, 'timeline-test');
  const db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  const tokens = new Map<string, string>();
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
  env = { app, db, tokens };
});
after(async () => {
  await deleteApp(env.app);
});

const rowOf = async (eventId: string, postId: string) =>
  (await env.db.doc(`events/${eventId}/timeline/${postId}`).get()).data();

describe('event timeline on the emulators', () => {
  test('a new post with the hashtag appears on the timeline', async () => {
    const { eventId, hashtag } = await publishFreeEvent(env, AN);
    const postId = newUlid(Date.now());
    await env.db.doc(`posts/${postId}`).set({
      kind: 'work', authorId: AN, photographerId: AN, serviceId: 'seed-service-portrait',
      imageUrls: ['https://seed.test/a.jpg'], imageMeta: [{ w: 800, h: 600 }], caption: `Đẹp #${hashtag}`,
      hashtags: [hashtag.toLowerCase()], likeCount: 0, saveCount: 0, createdAt: Timestamp.now(),
    });
    const row = await waitFor('the timeline row', () => rowOf(eventId, postId));
    assert.equal(row.status, 'visible');
    assert.equal(row.isHost, true);
    assert.equal(row.source, 'hashtag');
    assert.equal((await env.db.doc(`events/${eventId}`).get()).data()?.postCount, 1);
  });

  test('a stranger\'s post waits as pending until a manager approves it', async () => {
    const { eventId, hashtag } = await publishFreeEvent(env, AN);
    const stranger = await makeCustomer(env, 'stranger');
    const postId = newUlid(Date.now());
    await env.db.doc(`posts/${postId}`).set({
      kind: 'real_shoot', authorId: stranger, photographerId: AN, serviceId: 'seed-service-portrait',
      imageUrls: ['https://seed.test/b.jpg'], caption: `#${hashtag}`, hashtags: [hashtag.toLowerCase()],
      likeCount: 0, saveCount: 0, createdAt: Timestamp.now(),
    });
    const row = await waitFor('the pending row', () => rowOf(eventId, postId));
    assert.equal(row.status, 'pending');
    assert.equal((await env.db.doc(`events/${eventId}`).get()).data()?.postCount, 0);
    const denied = await callAs(env, 'moderateEventTimeline', LAN, { eventId, postId, action: 'approve' });
    assert.equal(denied.status, 403);
    const ok = await callAs(env, 'moderateEventTimeline', AN, { eventId, postId, action: 'approve' });
    assert.equal(ok.status, 200, ok.text);
    assert.equal((await rowOf(eventId, postId))?.status, 'visible');
    assert.equal((await env.db.doc(`events/${eventId}`).get()).data()?.postCount, 1);
    await callAs(env, 'moderateEventTimeline', AN, { eventId, postId, action: 'hide' });
    assert.equal((await env.db.doc(`events/${eventId}`).get()).data()?.postCount, 0);
  });

  test('a paid attendee shares photos: the event_share post and the row land together', async () => {
    const { eventId, hashtag } = await publishFreeEvent(env, AN);
    const reg = await callAs(env, 'registerEvent', LAN, { eventId, quantity: 1, name: 'Lan' });
    assert.equal(reg.status, 200, reg.text);
    const postId = newUlid(Date.now());
    const path = `posts/${LAN}/${postId}/1.jpg`;
    const shared = await callAs(env, 'shareEventPost', LAN, {
      eventId, postId, images: [{ url: bucketUrl(path), path, w: 800, h: 600 }], caption: 'Buổi sáng',
    });
    assert.equal(shared.status, 200, shared.text);
    const post = (await env.db.doc(`posts/${postId}`).get()).data();
    assert.equal(post?.kind, 'event_share');
    assert.equal(post?.eventId, eventId);
    assert.equal(post?.serviceId, '');
    assert.equal(post?.photographerId, '', 'never in the host portfolio (byPhotographer)');
    assert.match(post?.caption as string, new RegExp(`#${hashtag}$`));
    assert.equal((await rowOf(eventId, postId))?.status, 'visible');
    // onPostCreated runs for the new post and must not write a second row
    await new Promise((r) => setTimeout(r, 1500));
    assert.equal((await env.db.collection(`events/${eventId}/timeline`).get()).size, 1);
    assert.equal((await env.db.doc(`events/${eventId}`).get()).data()?.postCount, 1);
  });

  test('sharing without a ticket is refused', async () => {
    const { eventId } = await publishFreeEvent(env, AN);
    const stranger = await makeCustomer(env, 'noticket');
    const postId = newUlid(Date.now());
    const path = `posts/${stranger}/${postId}/1.jpg`;
    const res = await callAs(env, 'shareEventPost', stranger, { eventId, postId, images: [{ url: bucketUrl(path), path }] });
    assert.equal(res.status, 403);
  });
});
