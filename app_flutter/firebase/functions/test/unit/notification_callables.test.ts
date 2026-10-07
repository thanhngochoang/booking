import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import { MemoryNotificationStore, notify, pruneReadNotifications, type NotifyDeps } from '@photobooking/domain';
import { MemoryPushSender, MemoryUserDirectory } from '@photobooking/domain';
import { handleMarkAllNotificationsRead } from '../../src/callables/notification.js';
import { handleNotificationWrite } from '../../src/triggers/notification_write.js';
import { handleChatMessageCreated } from '../../src/triggers/chat_message_created.js';
import { handleChatMemberWrite } from '../../src/triggers/chat_member_write.js';
import { handleDeviceWrite } from '../../src/triggers/device_write.js';

function world() {
  const store = new MemoryNotificationStore();
  const users = new MemoryUserDirectory();
  users.users.set('a', { name: 'An', avatarUrl: null });
  let now = new Date('2026-10-10T10:00:00.000Z');
  const deps: NotifyDeps = { store, push: new MemoryPushSender(), users, clock: { now: () => now } };
  return { store, deps, advance: (ms: number) => { now = new Date(now.getTime() + ms); } };
}

const accepted = (key: string) => ({
  userId: 'u1',
  content: { type: 'booking_accepted' as const, photographer: 'An', day: 'T7 10/10', start: '09:00', place: 'Hồ Tây' },
  target: '/b/x',
  dedupeKey: key,
});

describe('notification callables and triggers', () => {
  it('unauthenticated markAll is refused', async () => {
    const w = world();
    await assert.rejects(
      handleMarkAllNotificationsRead({ data: {} }, w.deps),
      (e: unknown) => e instanceof HttpsError && e.code === 'unauthenticated',
    );
  });

  it('markAll returns the marked count and zeroes the unread count', async () => {
    const w = world();
    await notify(w.deps, accepted('a'));
    await notify(w.deps, accepted('b'));
    const res = await handleMarkAllNotificationsRead({ auth: { uid: 'u1' }, data: {} }, w.deps);
    assert.deepEqual(res, { marked: 2 });
    assert.equal(w.store.unread.get('u1')?.count, 0);
    assert.deepEqual(await handleMarkAllNotificationsRead({ auth: { uid: 'u1' }, data: {} }, w.deps), { marked: 0 });
  });

  it('the row trigger recounts only when the unread state changes', async () => {
    const w = world();
    await notify(w.deps, accepted('a'));
    assert.equal(await handleNotificationWrite('u1', undefined, { readAt: null }, w.deps), 1);
    assert.equal(await handleNotificationWrite('u1', { readAt: null }, { readAt: null }, w.deps), null);
    assert.equal(await handleNotificationWrite('u1', { readAt: new Date() }, undefined, w.deps), null);
  });

  it('a chat message notifies the other member, grouped; system and foreign senders are skipped', async () => {
    const w = world();
    const ev = (id: string, message: Record<string, unknown>) => ({ chatId: 'c1', messageId: id, message, members: ['a', 'u1'] });
    assert.equal(await handleChatMessageCreated(ev('m1', { senderId: 'a', type: 'text', body: 'Chào bạn' }), w.deps), 'sent');
    assert.equal(await handleChatMessageCreated(ev('m2', { senderId: 'a', type: 'image' }), w.deps), 'sent');
    assert.equal(await handleChatMessageCreated(ev('m3', { senderId: null, type: 'system' }), w.deps), 'skipped');
    assert.equal(await handleChatMessageCreated(ev('m4', { senderId: 'zz', type: 'text', body: 'x' }), w.deps), 'skipped');
    const rows = w.store.rowsOf('u1');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.id, 'g_chat_c1');
    assert.equal(rows[0]?.count, 2);
    assert.equal(rows[0]?.target, '/chat/c1');
  });

  it('reading the chat marks its row read once', async () => {
    const calls: string[] = [];
    const mark = async (uid: string, chatId: string) => { calls.push(`${uid}/${chatId}`); return true; };
    assert.equal(await handleChatMemberWrite({ chatId: 'c1', uid: 'u1', after: { unreadCount: 2 } }, mark), false);
    assert.equal(await handleChatMemberWrite({ chatId: 'c1', uid: 'u1', after: undefined }, mark), false);
    assert.equal(await handleChatMemberWrite({ chatId: 'c1', uid: 'u1', after: { unreadCount: 0 } }, mark), true);
    assert.deepEqual(calls, ['u1/c1']);
    // M9: event group chats have no inbox row; their member writes are skipped.
    assert.equal(await handleChatMemberWrite({ chatId: 'event_ev1', uid: 'u1', after: { unreadCount: 0 } }, mark), false);
    assert.deepEqual(calls, ['u1/c1']);
  });

  it('a device token moves to its newest owner', async () => {
    const removed: string[][] = [];
    const deps = {
      otherDevicesWithToken: async () => ['old_1'],
      remove: async (ids: readonly string[]) => { removed.push([...ids]); },
    };
    assert.equal(await handleDeviceWrite('new_1', undefined, { token: 't' }, deps), 1);
    assert.equal(await handleDeviceWrite('new_1', { token: 't' }, { token: 't' }, deps), 0);
    assert.equal(await handleDeviceWrite('new_1', { token: 't' }, undefined, deps), 0);
    assert.deepEqual(removed, [['old_1']]);
  });

  it('the nightly prune deletes read rows older than 90 days and keeps unread ones', async () => {
    const w = world();
    await notify(w.deps, accepted('old-read'));
    await notify(w.deps, accepted('old-unread'));
    await w.store.markRead('u1', ['n_old-read'], new Date('2026-10-10T11:00:00.000Z'));
    w.advance(91 * 86_400_000);
    assert.equal(await pruneReadNotifications(w.deps), 1);
    assert.deepEqual(w.store.rowsOf('u1').map((r) => r.id), ['n_old-unread']);
  });
});
