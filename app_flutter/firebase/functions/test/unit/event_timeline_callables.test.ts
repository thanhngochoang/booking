import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { MemoryEventTimelineStore, type EventRecord, type TimelineDeps, type TimelineRow } from '@photobooking/domain';
import { handleModerateEventTimeline, handleShareEventPost } from '../../src/callables/event_timeline.js';
import {
  ownPostImage,
  sharedPostToFirestore,
  timelinePostFromFirestore,
  timelineRowFromFirestore,
  timelineRowToFirestore,
} from '../../src/infra/event_timeline_firestore.js';
import { handleLinkEventPosts, mayLinkEventPosts } from '../../src/triggers/post_created.js';

const EV = 'ev1';
const T = new Date('2026-10-06T03:00:00.000Z');

const event = (over: Partial<EventRecord> = {}): EventRecord => ({
  id: EV, host: { type: 'photographer', id: 'ph1', name: 'A', avatarUrl: null, verified: false },
  createdBy: 'ph1', createdByRole: 'photographer', hostConsent: 'not_required', hostConsentExpiresAt: null,
  title: 'T', description: '', type: 'photo_walk', coverUrl: 'u', coverPath: 'p',
  startAt: new Date('2026-10-12T02:00:00.000Z'), endAt: new Date('2026-10-12T05:00:00.000Z'), dayKey: '2026-10-12',
  location: { name: 'L', meetingPoint: null, lat: 21, lng: 105, geohash: 'w7er8u0', areaId: null },
  capacity: 10, price: 0, registrationDeadline: new Date('2026-10-11T14:00:00.000Z'), faq: [],
  hashtag: 'PhotoWalk1012', hashtagKey: 'photowalk1012', hashtagLocked: false, status: 'open',
  registeredCount: 0, heldCount: 0, chatId: `event_${EV}`, postCount: 0, version: 1,
  publishedAt: T, completedAt: null, cancelledAt: null, createdAt: T, updatedAt: T, ...over,
});

const images = (uid: string, postId: string) => [
  { url: `https://s.test/posts/${uid}/${postId}/a.jpg`, path: `posts/${uid}/${postId}/a.jpg`, w: 10, h: 20 },
];

describe('event timeline callables', () => {
  let store: MemoryEventTimelineStore;
  const deps = (): TimelineDeps => ({
    timeline: store,
    people: { author: async (uid) => ({ name: uid, isPhotographer: uid === 'ph1' }) },
    media: { isOwnPostImage: (url, path, uid, postId) => path.startsWith(`posts/${uid}/${postId}/`) && url.endsWith(path) },
    clock: { now: () => T },
  });

  beforeEach(() => {
    store = new MemoryEventTimelineStore();
    store.seedEvent(event());
  });

  it('unauthenticated is refused', async () => {
    for (const h of [handleShareEventPost, handleModerateEventTimeline]) {
      await assert.rejects(
        () => h({ auth: undefined, data: {} }, deps()),
        (e: unknown) => e instanceof HttpsError && e.code === 'unauthenticated',
      );
    }
  });

  it('domain errors map to HttpsError with the code', async () => {
    await assert.rejects(
      () => handleShareEventPost({ auth: { uid: 'cu1' }, data: { eventId: EV, postId: 'p1', images: images('cu1', 'p1') } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'permission-denied'
        && (e.details as { code?: string }).code === 'permission_denied',
    );
    await assert.rejects(
      () => handleShareEventPost({ auth: { uid: 'cu1' }, data: { eventId: EV } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'invalid-argument',
    );
    await assert.rejects(
      () => handleModerateEventTimeline({ auth: { uid: 'ph1' }, data: { eventId: 'nope', postId: 'p1', action: 'hide' } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'not-found',
    );
  });

  it('share then moderate end to end', async () => {
    store.seedPaid(EV, 'cu1');
    const shared = await handleShareEventPost({ auth: { uid: 'cu1' }, data: { eventId: EV, postId: 'p1', images: images('cu1', 'p1'), caption: 'đẹp' } }, deps());
    assert.deepEqual(shared, { postId: 'p1' });
    assert.equal(store.events.get(EV)?.postCount, 1);
    await assert.rejects(
      () => handleModerateEventTimeline({ auth: { uid: 'cu1' }, data: { eventId: EV, postId: 'p1', action: 'hide' } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'permission-denied',
    );
    assert.deepEqual(await handleModerateEventTimeline({ auth: { uid: 'ph1' }, data: { eventId: EV, postId: 'p1', action: 'hide' } }, deps()), {});
    assert.equal(store.rows.get(`${EV}/p1`)?.status, 'hidden');
    assert.equal(store.events.get(EV)?.postCount, 0);
  });

  it('an attendee share never appears in byPhotographer of the host (C1)', async () => {
    store.seedPaid(EV, 'cu1');
    await handleShareEventPost({ auth: { uid: 'cu1' }, data: { eventId: EV, postId: 'p1', images: images('cu1', 'p1') } }, deps());
    await handleShareEventPost({ auth: { uid: 'ph1' }, data: { eventId: EV, postId: 'p2', images: images('ph1', 'p2') } }, deps());
    // byPhotographer is `posts where photographerId == host`: the written documents never match it.
    const written = [...store.sharedPosts.values()].map(sharedPostToFirestore);
    assert.equal(written.length, 2);
    assert.deepEqual(written.filter((d) => d.photographerId === 'ph1'), []);
  });

  it('the post trigger links a hashtag post and skips plain ones', async () => {
    store.seedPost({
      id: 'w1', authorId: 'ph1', kind: 'work', hashtags: ['photowalk1012'], eventId: null,
      imageUrls: ['https://s.test/a.jpg'], imageW: null, imageH: null,
    });
    assert.equal(mayLinkEventPosts([], undefined), false);
    assert.equal(mayLinkEventPosts(undefined, ''), false);
    assert.equal(mayLinkEventPosts(['a'], undefined), true);
    assert.equal(mayLinkEventPosts(undefined, EV), true);
    assert.deepEqual(await handleLinkEventPosts('w1', deps()), [EV]);
    assert.deepEqual(await handleLinkEventPosts('w1', deps()), []);
  });
});

describe('event timeline Firestore mapping', () => {
  it('a row survives the round trip', () => {
    const row: TimelineRow = {
      postId: 'p1', source: 'explicit', status: 'pending', authorId: 'cu1', authorName: 'Lan', isHost: false,
      imageUrl: 'https://s.test/a.jpg', imageW: 10, imageH: 20, imageCount: 3, addedAt: T, moderatedBy: null,
    };
    const doc = timelineRowToFirestore(row);
    assert.ok(doc.addedAt instanceof Timestamp);
    assert.deepEqual(timelineRowFromFirestore('p1', doc), row);
  });

  it('a post maps to the slice the timeline needs; a deleted post is null', () => {
    const p = timelinePostFromFirestore('p1', {
      kind: 'work', authorId: 'ph1', photographerId: 'ph1', hashtags: ['a', 3, 'b'], imageUrls: ['u1', 'u2'],
      imageMeta: [{ w: 100, h: 200 }],
    });
    assert.deepEqual(p, { id: 'p1', authorId: 'ph1', kind: 'work', hashtags: ['a', 'b'], eventId: null, imageUrls: ['u1', 'u2'], imageW: 100, imageH: 200 });
    assert.equal(timelinePostFromFirestore('p1', { deletedAt: Timestamp.now() }), null);
    assert.equal(timelinePostFromFirestore('p1', undefined), null);
  });

  it('a shared post has no service, no photographer and zero counters', () => {
    const doc = sharedPostToFirestore({
      id: 'p1', authorId: 'cu1', eventId: EV, imageUrls: ['u'], imageMeta: [{ w: 1, h: 2, blurHash: null }],
      caption: '#x', hashtags: ['x'], createdAt: T,
    });
    assert.equal(doc.kind, 'event_share');
    assert.equal(doc.serviceId, '');
    assert.equal(doc.photographerId, '');
    assert.equal(doc.eventId, EV);
    assert.equal(doc.likeCount, 0);
    assert.equal(doc.saveCount, 0);
  });

  it('ownPostImage accepts only the caller\'s own object in this bucket', () => {
    const own = ownPostImage(['https://firebasestorage.googleapis.com/v0/b/b/o/']);
    const path = 'posts/cu1/p1/a b.jpg';
    const url = `https://firebasestorage.googleapis.com/v0/b/b/o/${encodeURIComponent(path)}?alt=media&token=t`;
    assert.equal(own(url, path, 'cu1', 'p1'), true);
    assert.equal(own(url, path, 'cu2', 'p1'), false);
    assert.equal(own(url, path, 'cu1', 'p2'), false);
    assert.equal(own('https://evil.test/x', path, 'cu1', 'p1'), false);
    assert.equal(own(url, 'posts/cu1/p1/../x.jpg', 'cu1', 'p1'), false);
    assert.equal(own(url, 'chats/a/cu1/x.jpg', 'cu1', 'p1'), false);
  });
});
