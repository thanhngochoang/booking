import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import type { NotifyRequest } from '../src/notification_ports.js';
import {
  markAllRead,
  notify,
  pruneReadNotifications,
  reconcileUnread,
} from '../src/notification_use_cases.js';
import { createNotifyWorld, type NotifyWorld } from './support/notify_world.js';

const review = (over: Partial<NotifyRequest> = {}): NotifyRequest => ({
  userId: 'u1',
  content: { type: 'review_new', customer: 'An', rating: 5, text: 'Rất tốt' },
  target: '/u/u1?tab=reviews',
  dedupeKey: 'review_new_b1',
  ...over,
});

const chat = (n: number, actorId: string, eventId: string): NotifyRequest => ({
  userId: 'u1',
  content: { type: 'chat_message', sender: actorId, preview: `tin ${n}`, count: 1 },
  target: '/chat/c1',
  dedupeKey: 'ignored',
  groupKey: 'chat:c1',
  eventId,
  actor: { id: actorId, name: actorId, avatarUrl: null },
});

describe('notify', () => {
  let w: NotifyWorld;
  beforeEach(() => {
    w = createNotifyWorld();
  });

  it('creates a row with readAt null and pushes with its id', async () => {
    assert.equal(await notify(w.deps, review()), 'created');
    const [row] = w.store.rowsOf('u1');
    assert.equal(row?.id, 'n_review_new_b1');
    assert.equal(row?.readAt, null);
    assert.equal(row?.tab, 'system');
    assert.equal(row?.category, 'badges');
    assert.equal(row?.title, 'An đã đánh giá 5 sao');
    assert.equal(w.push.sent.length, 1);
    assert.deepEqual(w.push.sent[0]?.msg.data, {
      type: 'review_new',
      target: '/u/u1?tab=reviews',
      notificationId: 'n_review_new_b1',
    });
    assert.equal(w.push.sent[0]?.msg.channel, 'default');
  });

  it('a duplicate dedupe key writes nothing and does not push', async () => {
    await notify(w.deps, review());
    const writes = w.store.writes;
    assert.equal(await notify(w.deps, review()), 'duplicate');
    assert.equal(w.store.writes, writes);
    assert.equal(w.push.sent.length, 1);
  });

  it('in-app off still pushes without a notification id', async () => {
    w.store.prefs.set('u1', { channels: { badges: { push: true, inApp: false } } });
    assert.equal(await notify(w.deps, review()), 'created');
    assert.equal(w.store.rowsOf('u1').length, 0);
    assert.equal(w.push.sent.length, 1);
    assert.equal('notificationId' in (w.push.sent[0]?.msg.data ?? {}), false);
  });

  it('everything off is suppressed', async () => {
    w.store.prefs.set('u1', { channels: { badges: { push: false, inApp: false } } });
    assert.equal(await notify(w.deps, review()), 'suppressed');
    assert.equal(w.store.rowsOf('u1').length, 0);
    assert.equal(w.push.sent.length, 0);
  });

  it('push off keeps the row but sends nothing', async () => {
    w.store.prefs.set('u1', { channels: { badges: { push: false, inApp: true } } });
    await notify(w.deps, review());
    assert.equal(w.store.rowsOf('u1').length, 1);
    assert.equal(w.push.sent.length, 0);
  });

  it('quiet hours push on the quiet channel', async () => {
    w.clock.setTime(new Date('2026-10-10T16:00:00.000Z')); // 23:00 VN
    await notify(w.deps, review());
    assert.equal(w.push.sent[0]?.msg.channel, 'quiet');
  });

  it('grouped events bump count, move to the top and become unread', async () => {
    await notify(w.deps, chat(1, 'a', 'm1'));
    const id = 'g_chat_c1';
    await w.store.markRead('u1', [id], new Date());
    w.clock.advanceMinutes(5);
    assert.equal(await notify(w.deps, chat(2, 'b', 'm2')), 'grouped');
    const row = w.store.rowsOf('u1')[0];
    assert.equal(row?.count, 2);
    assert.equal(row?.readAt, null);
    assert.equal(row?.createdAt.getTime(), w.clock.now().getTime());
    assert.equal(row?.body, '2 tin nhắn mới');
    assert.equal(w.store.rowsOf('u1').length, 1);
    assert.equal(w.push.sent.length, 2);
    assert.equal(w.push.sent[1]?.msg.data.notificationId, id);
  });

  it('the same event id twice is a duplicate', async () => {
    await notify(w.deps, chat(1, 'a', 'm1'));
    assert.equal(await notify(w.deps, chat(1, 'a', 'm1')), 'duplicate');
    assert.equal(w.store.rowsOf('u1')[0]?.count, 1);
    assert.equal(w.push.sent.length, 1);
  });

  it('group keeps at most 3 unique actors, newest first', async () => {
    for (const [i, a] of ['a', 'b', 'c', 'd', 'b'].entries()) await notify(w.deps, chat(i, a, `m${i}`));
    const row = w.store.rowsOf('u1')[0];
    assert.deepEqual(row?.actors.map((x) => x.id), ['b', 'd', 'c']);
    assert.equal(row?.count, 5);
  });

  it('a grouped request without an actor is invalid', async () => {
    const { actor: _a, ...rest } = chat(1, 'a', 'm1');
    void _a;
    await assert.rejects(notify(w.deps, rest as NotifyRequest), { code: 'invalid_argument' });
  });

  it('a push failure does not undo the row', async () => {
    w.push.failWith = new Error('fcm down');
    assert.equal(await notify(w.deps, review()), 'created');
    assert.equal(w.store.rowsOf('u1').length, 1);
    assert.equal(w.pushErrors.length, 1);
  });
});

describe('unread count', () => {
  let w: NotifyWorld;
  beforeEach(() => {
    w = createNotifyWorld();
  });

  it('markAllRead marks every unread row and sets the count to 0', async () => {
    for (const k of ['a', 'b', 'c']) await notify(w.deps, review({ dedupeKey: `review_${k}` }));
    await reconcileUnread(w.deps, 'u1');
    assert.equal(w.store.unread.get('u1')?.count, 3);
    w.clock.advanceMinutes(1);
    assert.equal(await markAllRead(w.deps, 'u1'), 3);
    assert.equal(w.store.unread.get('u1')?.count, 0);
    assert.equal(await w.store.countUnread('u1'), 0);
    assert.equal(await markAllRead(w.deps, 'u1'), 0);
  });

  it('reconcileUnread writes the counted value', async () => {
    await notify(w.deps, review());
    assert.equal(await reconcileUnread(w.deps, 'u1'), 1);
    assert.equal(w.store.unread.get('u1')?.count, 1);
  });

  it('an older count never overwrites a newer one', async () => {
    assert.equal(await w.store.setUnreadCount('u1', 5, new Date('2026-10-10T10:00:02.000Z')), true);
    assert.equal(await w.store.setUnreadCount('u1', 3, new Date('2026-10-10T10:00:01.000Z')), false);
    assert.equal(w.store.unread.get('u1')?.count, 5);
  });
});

describe('pruneReadNotifications', () => {
  it('deletes read rows older than 90 days and keeps unread and recent ones', async () => {
    const w = createNotifyWorld(new Date('2026-06-01T10:00:00.000Z'));
    await notify(w.deps, review({ dedupeKey: 'old_read' }));
    await notify(w.deps, review({ dedupeKey: 'old_unread' }));
    await w.store.markRead('u1', ['n_old_read'], w.clock.now());
    w.clock.setTime(new Date('2026-09-01T10:00:00.000Z'));
    await notify(w.deps, review({ dedupeKey: 'new_read' }));
    await w.store.markRead('u1', ['n_new_read'], w.clock.now());
    w.clock.setTime(new Date('2026-10-10T10:00:00.000Z'));
    assert.equal(await pruneReadNotifications(w.deps), 1);
    assert.deepEqual(w.store.rowsOf('u1').map((r) => r.id).sort(), ['n_new_read', 'n_old_unread']);
    assert.equal(await pruneReadNotifications(w.deps), 0);
  });
});
