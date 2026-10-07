import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError } from '../src/errors.js';
import {
  extractHashtags, linkEventPosts, moderateEventTimeline, shareEventPost, timelineOpen, timelineStatusFor,
} from '../src/event_timeline.js';
import type { EventCaller } from '../src/event.js';
import { EV, createTimelineWorld, eventRecord, post, shareImages } from './support/event_social_world.js';

const refused = (code: string) => (e: unknown) => e instanceof DomainError && e.code === code;
const manager: EventCaller = { uid: 'ph1', staffRole: null };
const customer = (uid: string): EventCaller => ({ uid, staffRole: null });
const DAY = 86_400_000;

describe('timelineStatusFor', () => {
  test('photographers, managers and paid attendees post visible, others pending', () => {
    const base = { isPhotographer: false, hasPaidTicket: false, isManager: false };
    assert.equal(timelineStatusFor({ ...base, isPhotographer: true }), 'visible');
    assert.equal(timelineStatusFor({ ...base, isManager: true }), 'visible');
    assert.equal(timelineStatusFor({ ...base, hasPaidTicket: true }), 'visible');
    assert.equal(timelineStatusFor(base), 'pending');
  });
});

describe('timelineOpen', () => {
  test('a draft or a cancelled event is closed; a completed event closes 30 days after', () => {
    const done = new Date('2026-10-04T05:00:00.000Z');
    const now = new Date(done.getTime() + 30 * DAY);
    assert.equal(timelineOpen(eventRecord({ status: 'draft' }), now), false);
    assert.equal(timelineOpen(eventRecord({ status: 'cancelled', cancelledAt: done }), done), false);
    assert.equal(timelineOpen(eventRecord({ status: 'completed', completedAt: done }), now), true);
    assert.equal(timelineOpen(eventRecord({ status: 'completed', completedAt: done }), new Date(now.getTime() + 1)), false);
    assert.equal(timelineOpen(eventRecord({ status: 'open' }), now), true);
  });
});

describe('extractHashtags', () => {
  test('lower case, unique, ignores glued hashes', () => {
    assert.deepEqual(extractHashtags('Đẹp #PhotoWalk1004 và #photowalk1004 #a http://x/#frag a#b'), ['photowalk1004']);
  });
});

describe('linkEventPosts', () => {
  test('a post with the hashtag in another case links, visible for a photographer', async () => {
    const w = createTimelineWorld();
    w.store.seedPost(post('p1', 'ph2', ['photowalk1004']));
    assert.deepEqual(await linkEventPosts(w.deps, 'p1'), { linked: [EV] });
    const row = w.store.rows.get(`${EV}/p1`);
    assert.equal(row?.status, 'visible');
    assert.equal(row?.source, 'hashtag');
    assert.equal(row?.authorName, 'Tên ph2');
    assert.equal(row?.imageCount, 2);
    assert.equal(row?.imageUrl, 'https://s.test/posts/ph2/p1/a.jpg');
    assert.equal(w.store.events.get(EV)?.postCount, 1);
  });

  test('a hashtag stored in upper case still finds the event', async () => {
    const w = createTimelineWorld();
    w.store.seedPost(post('p1', 'ph2', ['PhotoWalk1004']));
    assert.deepEqual((await linkEventPosts(w.deps, 'p1')).linked, [EV]);
  });

  test('the host posts visible and is marked as host', async () => {
    const w = createTimelineWorld();
    w.store.seedPost(post('p1', 'ph1', ['photowalk1004']));
    await linkEventPosts(w.deps, 'p1');
    assert.equal(w.store.rows.get(`${EV}/p1`)?.isHost, true);
    assert.equal(w.store.rows.get(`${EV}/p1`)?.status, 'visible');
  });

  test('a paid attendee is visible, anyone else pending (and uncounted)', async () => {
    const w = createTimelineWorld();
    w.store.seedPaid(EV, 'cu1');
    w.store.seedPost(post('p1', 'cu1', ['photowalk1004']));
    w.store.seedPost(post('p2', 'cu2', ['photowalk1004']));
    await linkEventPosts(w.deps, 'p1');
    await linkEventPosts(w.deps, 'p2');
    assert.equal(w.store.rows.get(`${EV}/p1`)?.status, 'visible');
    assert.equal(w.store.rows.get(`${EV}/p2`)?.status, 'pending');
    assert.equal(w.store.events.get(EV)?.postCount, 1);
  });

  test('a draft event never links', async () => {
    const w = createTimelineWorld();
    w.store.seedEvent(eventRecord({ id: 'd1', status: 'draft', hashtag: 'Draft1', hashtagKey: 'draft1' }));
    w.store.seedPost(post('p1', 'ph2', ['draft1']));
    assert.deepEqual(await linkEventPosts(w.deps, 'p1'), { linked: [] });
    assert.equal(w.store.rowsOf('d1').length, 0);
  });

  test('an event closed 30 days after completion does not link', async () => {
    const w = createTimelineWorld();
    w.store.seedEvent(eventRecord({
      id: 'old', status: 'completed', hashtag: 'Old1', hashtagKey: 'old1',
      completedAt: new Date(w.clock.now().getTime() - 31 * DAY),
    }));
    w.store.seedPost(post('p1', 'ph2', ['old1']));
    assert.deepEqual((await linkEventPosts(w.deps, 'p1')).linked, []);
  });

  test('linking twice writes once', async () => {
    const w = createTimelineWorld();
    w.store.seedPost(post('p1', 'ph2', ['photowalk1004']));
    await linkEventPosts(w.deps, 'p1');
    const writes = w.store.writes;
    assert.deepEqual(await linkEventPosts(w.deps, 'p1'), { linked: [] });
    assert.equal(w.store.writes, writes);
    assert.equal(w.store.events.get(EV)?.postCount, 1);
  });

  test('an unknown post or hashtag links nothing', async () => {
    const w = createTimelineWorld();
    assert.deepEqual(await linkEventPosts(w.deps, 'nope'), { linked: [] });
    w.store.seedPost(post('p1', 'ph2', ['other']));
    assert.deepEqual(await linkEventPosts(w.deps, 'p1'), { linked: [] });
  });
});

describe('shareEventPost', () => {
  const req = (uid: string, over: Record<string, unknown> = {}) => ({
    eventId: EV, postId: 'sp1', images: shareImages(uid, 'sp1'), caption: 'Buổi sáng đẹp', ...over,
  });

  test('share needs a paid ticket or a manager', async () => {
    const w = createTimelineWorld();
    await assert.rejects(shareEventPost(w.deps, customer('cu1'), req('cu1')), refused('permission_denied'));
    w.store.seedPaid(EV, 'cu1');
    assert.deepEqual(await shareEventPost(w.deps, customer('cu1'), req('cu1')), { postId: 'sp1' });
    assert.equal(w.store.rows.get(`${EV}/sp1`)?.status, 'visible');
    const m = await shareEventPost(w.deps, manager, req('ph1', { postId: 'sp2', images: shareImages('ph1', 'sp2') }));
    assert.equal(m.postId, 'sp2');
    assert.equal(w.store.rows.get(`${EV}/sp2`)?.isHost, true);
    assert.equal(w.store.events.get(EV)?.postCount, 2);
  });

  test('share writes an event_share post with the event and no service or photographer', async () => {
    const w = createTimelineWorld();
    w.store.seedPaid(EV, 'cu1');
    await shareEventPost(w.deps, customer('cu1'), req('cu1'));
    const p = w.store.sharedPosts.get('sp1');
    assert.equal(p?.eventId, EV);
    assert.equal(p?.authorId, 'cu1');
    assert.equal(p !== undefined && 'photographerId' in p, false);
    assert.equal(p?.imageUrls.length, 2);
  });

  test('share adds the hashtag when the caption lacks it, and keeps it when present', async () => {
    const w = createTimelineWorld();
    w.store.seedPaid(EV, 'cu1');
    await shareEventPost(w.deps, customer('cu1'), req('cu1'));
    assert.equal(w.store.sharedPosts.get('sp1')?.caption, 'Buổi sáng đẹp #Tag1004'.replace('Tag1004', 'PhotoWalk1004'));
    assert.deepEqual(w.store.sharedPosts.get('sp1')?.hashtags, ['photowalk1004']);
    await shareEventPost(w.deps, customer('cu1'), req('cu1', { postId: 'sp3', images: shareImages('cu1', 'sp3'), caption: '#photowalk1004 hay' }));
    assert.equal(w.store.sharedPosts.get('sp3')?.caption, '#photowalk1004 hay');
    await shareEventPost(w.deps, customer('cu1'), req('cu1', { postId: 'sp4', images: shareImages('cu1', 'sp4'), caption: '' }));
    assert.equal(w.store.sharedPosts.get('sp4')?.caption, '#PhotoWalk1004');
  });

  test('share refuses more than 10 images or foreign storage URLs', async () => {
    const w = createTimelineWorld();
    w.store.seedPaid(EV, 'cu1');
    await assert.rejects(
      shareEventPost(w.deps, customer('cu1'), req('cu1', { images: shareImages('cu1', 'sp1', 11) })),
      refused('invalid_argument'),
    );
    await assert.rejects(
      shareEventPost(w.deps, customer('cu1'), req('cu1', { images: [] })),
      refused('invalid_argument'),
    );
    await assert.rejects(
      shareEventPost(w.deps, customer('cu1'), req('cu1', { images: shareImages('cu2', 'sp1') })),
      refused('invalid_argument'),
    );
    await assert.rejects(
      shareEventPost(w.deps, customer('cu1'), req('cu1', { images: [{ url: 'https://evil.test/x.jpg', path: 'posts/cu1/sp1/x.jpg' }] })),
      refused('invalid_argument'),
    );
    assert.equal(w.store.sharedPosts.size, 0);
  });

  test('share after 30 days past completion is not_eligible', async () => {
    const w = createTimelineWorld();
    w.store.seedEvent(eventRecord({
      id: EV, hashtag: 'PhotoWalk1004', hashtagKey: 'photowalk1004', status: 'completed',
      completedAt: new Date(w.clock.now().getTime() - 31 * DAY),
    }));
    w.store.seedPaid(EV, 'cu1');
    await assert.rejects(shareEventPost(w.deps, customer('cu1'), req('cu1')), refused('not_eligible'));
  });

  test('a retried share returns the first post and writes nothing more', async () => {
    const w = createTimelineWorld();
    w.store.seedPaid(EV, 'cu1');
    await shareEventPost(w.deps, customer('cu1'), req('cu1'));
    const writes = w.store.writes;
    assert.deepEqual(await shareEventPost(w.deps, customer('cu1'), req('cu1')), { postId: 'sp1' });
    assert.equal(w.store.writes, writes);
    assert.equal(w.store.events.get(EV)?.postCount, 1);
  });

  test('a draft or unknown event is not_found', async () => {
    const w = createTimelineWorld();
    w.store.seedEvent(eventRecord({ id: 'd1', status: 'draft', hashtag: 'D1', hashtagKey: 'd1' }));
    await assert.rejects(shareEventPost(w.deps, manager, req('ph1', { eventId: 'd1' })), refused('not_found'));
    await assert.rejects(shareEventPost(w.deps, manager, req('ph1', { eventId: 'zz' })), refused('not_found'));
  });
});

describe('moderateEventTimeline', () => {
  async function pendingWorld() {
    const w = createTimelineWorld();
    w.store.seedPost(post('p1', 'cu2', ['photowalk1004']));
    w.store.seedPost(post('p2', 'ph2', ['photowalk1004']));
    await linkEventPosts(w.deps, 'p1'); // pending
    await linkEventPosts(w.deps, 'p2'); // visible
    return w;
  }

  test('postCount counts only visible rows and follows moderation', async () => {
    const w = await pendingWorld();
    const count = () => w.store.events.get(EV)?.postCount;
    assert.equal(count(), 1);
    await moderateEventTimeline(w.deps, manager, { eventId: EV, postId: 'p1', action: 'approve' });
    assert.equal(count(), 2);
    await moderateEventTimeline(w.deps, manager, { eventId: EV, postId: 'p2', action: 'hide' });
    assert.equal(count(), 1);
    assert.equal(w.store.rows.get(`${EV}/p2`)?.status, 'hidden');
    assert.equal(w.store.rows.get(`${EV}/p2`)?.moderatedBy, 'ph1');
    await moderateEventTimeline(w.deps, manager, { eventId: EV, postId: 'p2', action: 'show' });
    assert.equal(count(), 2);
  });

  test('repeating an action changes nothing', async () => {
    const w = await pendingWorld();
    await moderateEventTimeline(w.deps, manager, { eventId: EV, postId: 'p2', action: 'hide' });
    const writes = w.store.writes;
    await moderateEventTimeline(w.deps, manager, { eventId: EV, postId: 'p2', action: 'hide' });
    assert.equal(w.store.writes, writes);
    assert.equal(w.store.events.get(EV)?.postCount, 0);
  });

  test('a pending post is approved, not shown; a hidden one is shown, not approved', async () => {
    const w = await pendingWorld();
    await assert.rejects(moderateEventTimeline(w.deps, manager, { eventId: EV, postId: 'p1', action: 'show' }), refused('conflict'));
    await moderateEventTimeline(w.deps, manager, { eventId: EV, postId: 'p2', action: 'hide' });
    await assert.rejects(moderateEventTimeline(w.deps, manager, { eventId: EV, postId: 'p2', action: 'approve' }), refused('conflict'));
  });

  test('only managers hide, show or approve', async () => {
    const w = await pendingWorld();
    for (const caller of [customer('cu1'), customer('ph2'), { uid: 'sales9', staffRole: 'sales' } as EventCaller]) {
      await assert.rejects(
        moderateEventTimeline(w.deps, caller, { eventId: EV, postId: 'p1', action: 'approve' }),
        refused('permission_denied'),
      );
    }
    await moderateEventTimeline(w.deps, { uid: 'ad1', staffRole: 'admin' }, { eventId: EV, postId: 'p1', action: 'approve' });
    assert.equal(w.store.rows.get(`${EV}/p1`)?.status, 'visible');
  });

  test('bad input and unknown rows are refused', async () => {
    const w = await pendingWorld();
    await assert.rejects(moderateEventTimeline(w.deps, manager, { eventId: EV, postId: 'p1', action: 'nuke' }), refused('invalid_argument'));
    await assert.rejects(moderateEventTimeline(w.deps, manager, { eventId: EV, postId: 'zz', action: 'hide' }), refused('not_found'));
    await assert.rejects(moderateEventTimeline(w.deps, manager, null), refused('invalid_argument'));
  });
});
