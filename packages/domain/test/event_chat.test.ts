import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError } from '../src/errors.js';
import {
  GROUP_RATE_PER_MINUTE, assertCanSendToGroup, moderateEventChat, postEventAnnouncement, sendEventMessage,
  syncEventChatMembership,
} from '../src/event_chat.js';
import type { EventCaller } from '../src/event.js';
import {
  CHAT, EV, T0, chatSeed, createChatWorld, memberSeed, mod, registrationDoc, text,
} from './support/event_social_world.js';

const refused = (code: string) => (e: unknown) => e instanceof DomainError && e.code === code;
const customer = (uid: string): EventCaller => ({ uid, staffRole: null });
const paid = (uid: string, id = `rg_${uid}`) => registrationDoc({ id, userId: uid, userName: `Tên ${uid}`, eventId: EV, status: 'paid' });

describe('syncEventChatMembership', () => {
  test('a paid registration joins once and posts the join line', async () => {
    const w = createChatWorld();
    assert.equal(await syncEventChatMembership(w.deps, { before: null, after: paid('cu3') }), 'joined');
    const chat = w.store.chats.get(CHAT);
    assert.deepEqual(chat?.members, ['ph1', 'cu1', 'cu2', 'cu3']);
    assert.equal(chat?.memberCount, 4);
    const member = w.store.members.get(`${CHAT}/cu3`);
    assert.equal(member?.role, 'member');
    assert.equal(member?.name, 'Tên cu3');
    const [line] = w.store.messagesOf(CHAT);
    assert.equal(line?.type, 'system');
    assert.deepEqual(line?.system, { kind: 'member_joined', userId: 'cu3', name: 'Tên cu3' });
    assert.equal(line?.senderId, null);
  });

  test('a held registration that becomes paid joins; a repeated write does not rejoin', async () => {
    const w = createChatWorld();
    const held = registrationDoc({ userId: 'cu3', eventId: EV, status: 'held' });
    assert.equal(await syncEventChatMembership(w.deps, { before: null, after: held }), 'none');
    assert.equal(await syncEventChatMembership(w.deps, { before: held, after: { ...held, status: 'paid' } }), 'joined');
    const writes = w.store.writes;
    assert.equal(await syncEventChatMembership(w.deps, { before: null, after: paid('cu3') }), 'none');
    assert.equal(w.store.writes, writes);
    assert.equal(w.store.messagesOf(CHAT).length, 1);
  });

  test('a second paid registration of the same user does not join twice', async () => {
    const w = createChatWorld();
    await syncEventChatMembership(w.deps, { before: null, after: paid('cu3', 'rgA') });
    assert.equal(await syncEventChatMembership(w.deps, { before: null, after: paid('cu3', 'rgB') }), 'none');
    assert.equal(w.store.chats.get(CHAT)?.members.filter((u) => u === 'cu3').length, 1);
    assert.equal(w.store.messagesOf(CHAT).length, 1);
  });

  test('refund or cancel removes the member and keeps the member doc', async () => {
    for (const status of ['cancelled', 'refunded'] as const) {
      const w = createChatWorld();
      const reg = paid('cu1');
      assert.equal(await syncEventChatMembership(w.deps, { before: reg, after: { ...reg, status } }), 'left');
      assert.deepEqual(w.store.chats.get(CHAT)?.members, ['ph1', 'cu2']);
      assert.equal(w.store.chats.get(CHAT)?.memberCount, 2);
      const doc = w.store.members.get(`${CHAT}/cu1`);
      assert.equal(doc?.removedAt?.getTime(), T0.getTime());
      assert.equal(doc?.removedBy, null);
    }
  });

  test('a user with another paid ticket stays; the host never leaves', async () => {
    const w = createChatWorld();
    w.store.seedPaid(EV, 'cu1', 'other');
    const reg = paid('cu1');
    assert.equal(await syncEventChatMembership(w.deps, { before: reg, after: { ...reg, status: 'cancelled' } }), 'none');
    const host = registrationDoc({ userId: 'ph1', eventId: EV, status: 'paid' });
    assert.equal(await syncEventChatMembership(w.deps, { before: host, after: { ...host, status: 'cancelled' } }), 'none');
    assert.ok(w.store.chats.get(CHAT)?.members.includes('ph1'));
  });

  test('someone a moderator removed does not rejoin; one who left by cancelling does', async () => {
    const w = createChatWorld();
    await moderateEventChat(w.deps, mod, { eventId: EV, action: 'remove', userId: 'cu1' });
    assert.equal(await syncEventChatMembership(w.deps, { before: null, after: paid('cu1', 'again') }), 'none');
    const reg = paid('cu2');
    await syncEventChatMembership(w.deps, { before: reg, after: { ...reg, status: 'cancelled' } });
    assert.equal(await syncEventChatMembership(w.deps, { before: null, after: paid('cu2', 'again') }), 'joined');
    assert.ok(w.store.chats.get(CHAT)?.members.includes('cu2'));
    assert.equal(w.store.members.get(`${CHAT}/cu2`)?.removedAt, null);
  });

  test('an event without a chat is ignored', async () => {
    const w = createChatWorld();
    assert.equal(await syncEventChatMembership(w.deps, { before: null, after: registrationDoc({ eventId: 'nochat', status: 'paid' }) }), 'none');
  });
});

describe('assertCanSendToGroup', () => {
  const chat = chatSeed({ members: ['cu1', 'ph1'] });
  const now = T0;

  test('a removed member or a stranger cannot send', () => {
    assert.throws(() => assertCanSendToGroup(chat, null, now), refused('permission_denied'));
    assert.throws(() => assertCanSendToGroup(chat, memberSeed('cu9'), now), refused('permission_denied'));
    assert.throws(() => assertCanSendToGroup(chat, memberSeed('cu1', { removedAt: T0 }), now), refused('permission_denied'));
    assert.doesNotThrow(() => assertCanSendToGroup(chat, memberSeed('cu1'), now));
  });

  test('moderators-only blocks members, not moderators', () => {
    const c = chatSeed({ members: ['cu1', 'ph1'], moderatorsOnly: true });
    assert.throws(() => assertCanSendToGroup(c, memberSeed('cu1'), now), refused('permission_denied'));
    assert.doesNotThrow(() => assertCanSendToGroup(c, memberSeed('ph1', { role: 'moderator' }), now));
  });

  test('muted members cannot send until the time passes', () => {
    const m = memberSeed('cu1', { mutedUntil: new Date(now.getTime() + 1000) });
    assert.throws(() => assertCanSendToGroup(chat, m, now), refused('not_eligible'));
    assert.doesNotThrow(() => assertCanSendToGroup(chat, m, new Date(now.getTime() + 1000)));
  });

  test('after readOnlyAt nobody sends', () => {
    const c = chatSeed({ members: ['ph1'], readOnlyAt: now });
    assert.throws(() => assertCanSendToGroup(c, memberSeed('ph1', { role: 'moderator' }), now), refused('not_eligible'));
    assert.doesNotThrow(() => assertCanSendToGroup(c, memberSeed('ph1', { role: 'moderator' }), new Date(now.getTime() - 1)));
  });

  test('the check order: removed, read-only, muted, moderators-only, rate', () => {
    const everything = chatSeed({ members: ['cu1'], moderatorsOnly: true, readOnlyAt: now });
    const m = memberSeed('cu1', { mutedUntil: new Date(now.getTime() + 5000), sentWindowStart: now, sentInWindow: 99 });
    assert.throws(() => assertCanSendToGroup(everything, m, now), refused('not_eligible')); // read-only first
    assert.throws(() => assertCanSendToGroup({ ...everything, readOnlyAt: null }, m, now), refused('not_eligible')); // muted
    assert.throws(() => assertCanSendToGroup({ ...everything, readOnlyAt: null }, { ...m, mutedUntil: null }, now), refused('permission_denied'));
    assert.throws(() => assertCanSendToGroup({ ...everything, readOnlyAt: null, moderatorsOnly: false }, { ...m, mutedUntil: null }, now), refused('limit_exceeded'));
  });
});

describe('sendEventMessage', () => {
  test('messages carry the sender name, never a phone', async () => {
    const w = createChatWorld();
    const m = await sendEventMessage(w.deps, 'cu1', text('m1'));
    assert.equal(m.senderName, 'Tên cu1');
    assert.equal(m.body, 'xin chào');
    assert.deepEqual(Object.keys(m).sort(), [
      'body', 'chatId', 'createdAt', 'deletedAt', 'id', 'imagePath', 'point', 'senderId', 'senderName', 'system', 'type',
    ]);
    const chat = w.store.chats.get(CHAT);
    assert.equal(chat?.lastMessagePreview, 'xin chào');
    assert.equal(chat?.lastSenderId, 'cu1');
  });

  test('a retried send with the same clientId returns the first message', async () => {
    const w = createChatWorld();
    const a = await sendEventMessage(w.deps, 'cu1', text('m1'));
    w.clock.advance(5000);
    const b = await sendEventMessage(w.deps, 'cu1', text('m1', 'khác'));
    assert.deepEqual(b, a);
    assert.equal(w.store.messagesOf(CHAT).length, 1);
    assert.equal(w.store.members.get(`${CHAT}/cu1`)?.sentInWindow, 1);
    await assert.rejects(sendEventMessage(w.deps, 'cu2', text('m1')), refused('conflict'));
  });

  test('the 21st message in a minute is limit_exceeded; the next minute is fine', async () => {
    const w = createChatWorld();
    for (let i = 0; i < GROUP_RATE_PER_MINUTE; i++) await sendEventMessage(w.deps, 'cu1', text(`m${i}`));
    await assert.rejects(sendEventMessage(w.deps, 'cu1', text('m21')), refused('limit_exceeded'));
    w.clock.advance(60_000);
    await sendEventMessage(w.deps, 'cu1', text('m22'));
    assert.equal(w.store.members.get(`${CHAT}/cu1`)?.sentInWindow, 1);
  });

  test('a removed member cannot send', async () => {
    const w = createChatWorld();
    await moderateEventChat(w.deps, mod, { eventId: EV, action: 'remove', userId: 'cu1' });
    await assert.rejects(sendEventMessage(w.deps, 'cu1', text('m1')), refused('permission_denied'));
    await assert.rejects(sendEventMessage(w.deps, 'stranger', text('m2')), refused('permission_denied'));
  });

  test('a moderator without a member doc sends under their own name', async () => {
    const w = createChatWorld();
    w.store.members.delete(`${CHAT}/ph1`);
    const m = await sendEventMessage(w.deps, 'ph1', text('m1'));
    assert.equal(m.senderName, 'Tên ph1');
    assert.equal(w.store.members.get(`${CHAT}/ph1`)?.role, 'moderator');
  });

  test('image paths must be under this chat and the sender', async () => {
    const w = createChatWorld();
    const img = (imagePath: string) => ({ eventId: EV, message: { clientId: 'i1', type: 'image', imagePath } });
    await assert.rejects(sendEventMessage(w.deps, 'cu1', img(`chats/event_other/cu1/a.jpg`)), refused('invalid_argument'));
    await assert.rejects(sendEventMessage(w.deps, 'cu1', img(`chats/${CHAT}/cu2/a.jpg`)), refused('invalid_argument'));
    const ok = await sendEventMessage(w.deps, 'cu1', img(`chats/${CHAT}/cu1/a.jpg`));
    assert.equal(ok.type, 'image');
    assert.equal(w.store.chats.get(CHAT)?.lastMessagePreview, 'Ảnh');
  });

  test('bad input is invalid_argument; an unknown chat is not_found', async () => {
    const w = createChatWorld();
    await assert.rejects(sendEventMessage(w.deps, 'cu1', null), refused('invalid_argument'));
    await assert.rejects(sendEventMessage(w.deps, 'cu1', { eventId: EV, message: { clientId: 'x', type: 'text', body: '  ' } }), refused('invalid_argument'));
    await assert.rejects(sendEventMessage(w.deps, 'cu1', { ...text('m1'), eventId: 'ghost' }), refused('not_found'));
  });
});

describe('moderateEventChat', () => {
  test('pin and unpin need a moderator', async () => {
    const w = createChatWorld();
    await sendEventMessage(w.deps, 'cu1', text('m1', 'Họp lúc 8h'));
    await assert.rejects(moderateEventChat(w.deps, customer('cu1'), { eventId: EV, action: 'pin', messageId: 'm1' }), refused('permission_denied'));
    await moderateEventChat(w.deps, mod, { eventId: EV, action: 'pin', messageId: 'm1' });
    const [pin] = w.store.pinsOf(CHAT);
    assert.equal(pin?.body, 'Họp lúc 8h');
    assert.equal(pin?.senderName, 'Tên cu1');
    assert.equal(pin?.pinnedBy, 'ph1');
    await assert.rejects(moderateEventChat(w.deps, customer('cu2'), { eventId: EV, action: 'unpin', messageId: 'm1' }), refused('permission_denied'));
    await moderateEventChat(w.deps, mod, { eventId: EV, action: 'unpin', messageId: 'm1' });
    assert.equal(w.store.pinsOf(CHAT).length, 0);
    await assert.rejects(moderateEventChat(w.deps, mod, { eventId: EV, action: 'pin', messageId: 'ghost' }), refused('not_found'));
  });

  test('delete clears the body and keeps a tombstone, and drops the pin', async () => {
    const w = createChatWorld();
    await sendEventMessage(w.deps, 'cu1', text('m1', 'bí mật'));
    await moderateEventChat(w.deps, mod, { eventId: EV, action: 'pin', messageId: 'm1' });
    await moderateEventChat(w.deps, mod, { eventId: EV, action: 'delete', messageId: 'm1' });
    const [m] = w.store.messagesOf(CHAT);
    assert.equal(m?.body, null);
    assert.equal(m?.deletedAt?.getTime(), T0.getTime());
    assert.equal(m?.senderId, 'cu1');
    assert.equal(w.store.pinsOf(CHAT).length, 0);
    await assert.rejects(moderateEventChat(w.deps, mod, { eventId: EV, action: 'pin', messageId: 'm1' }), refused('invalid_argument'));
    await assert.rejects(moderateEventChat(w.deps, customer('cu1'), { eventId: EV, action: 'delete', messageId: 'm1' }), refused('permission_denied'));
  });

  test('mute lasts 24 hours by default and unmute lifts it; moderators cannot be muted', async () => {
    const w = createChatWorld();
    await moderateEventChat(w.deps, mod, { eventId: EV, action: 'mute', userId: 'cu1' });
    assert.equal(w.store.members.get(`${CHAT}/cu1`)?.mutedUntil?.getTime(), T0.getTime() + 24 * 3_600_000);
    await assert.rejects(sendEventMessage(w.deps, 'cu1', text('m1')), refused('not_eligible'));
    await moderateEventChat(w.deps, mod, { eventId: EV, action: 'unmute', userId: 'cu1' });
    await sendEventMessage(w.deps, 'cu1', text('m1'));
    await assert.rejects(moderateEventChat(w.deps, mod, { eventId: EV, action: 'mute', userId: 'ph1' }), refused('permission_denied'));
    await assert.rejects(moderateEventChat(w.deps, mod, { eventId: EV, action: 'mute', userId: 'cu1', minutes: 0 }), refused('invalid_argument'));
    await assert.rejects(moderateEventChat(w.deps, mod, { eventId: EV, action: 'mute', userId: 'ghost' }), refused('not_found'));
  });

  test('remove takes the member out of the chat; admin staff can moderate', async () => {
    const w = createChatWorld();
    await moderateEventChat(w.deps, { uid: 'ad1', staffRole: 'admin' }, { eventId: EV, action: 'remove', userId: 'cu2' });
    assert.deepEqual(w.store.chats.get(CHAT)?.members, ['ph1', 'cu1']);
    assert.equal(w.store.chats.get(CHAT)?.memberCount, 2);
    assert.equal(w.store.members.get(`${CHAT}/cu2`)?.removedBy, 'ad1');
    await assert.rejects(moderateEventChat(w.deps, mod, { eventId: EV, action: 'remove', userId: 'ph1' }), refused('permission_denied'));
  });

  test('moderators-only switches on and off', async () => {
    const w = createChatWorld();
    await moderateEventChat(w.deps, mod, { eventId: EV, action: 'moderatorsOnly', on: true });
    assert.equal(w.store.chats.get(CHAT)?.moderatorsOnly, true);
    await assert.rejects(sendEventMessage(w.deps, 'cu1', text('m1')), refused('permission_denied'));
    await moderateEventChat(w.deps, mod, { eventId: EV, action: 'moderatorsOnly', on: false });
    await sendEventMessage(w.deps, 'cu1', text('m1'));
    await assert.rejects(moderateEventChat(w.deps, mod, { eventId: EV, action: 'moderatorsOnly' }), refused('invalid_argument'));
    await assert.rejects(moderateEventChat(w.deps, mod, { eventId: EV, action: 'burn' }), refused('invalid_argument'));
  });
});

describe('postEventAnnouncement', () => {
  test('an announcement is a pinned moderator message', async () => {
    const w = createChatWorld();
    const { messageId } = await postEventAnnouncement(w.deps, mod, { eventId: EV, text: '  Tập trung 7h45  ' });
    const [m] = w.store.messagesOf(CHAT);
    assert.equal(m?.id, messageId);
    assert.equal(m?.body, 'Tập trung 7h45');
    assert.equal(m?.senderId, 'ph1');
    assert.equal(m?.senderName, 'Tên ph1');
    const [pin] = w.store.pinsOf(CHAT);
    assert.equal(pin?.messageId, messageId);
    assert.equal(pin?.body, 'Tập trung 7h45');
    assert.equal(w.store.chats.get(CHAT)?.lastMessagePreview, 'Tập trung 7h45');
  });

  test('only moderators; 1 to 500 characters; not after the chat closes', async () => {
    const w = createChatWorld();
    await assert.rejects(postEventAnnouncement(w.deps, customer('cu1'), { eventId: EV, text: 'hi' }), refused('permission_denied'));
    await assert.rejects(postEventAnnouncement(w.deps, mod, { eventId: EV, text: '   ' }), refused('invalid_argument'));
    await assert.rejects(postEventAnnouncement(w.deps, mod, { eventId: EV, text: 'x'.repeat(501) }), refused('invalid_argument'));
    await postEventAnnouncement(w.deps, mod, { eventId: EV, text: 'x'.repeat(500) });
    w.store.seedChat({ ...(w.store.chats.get(CHAT) as ReturnType<typeof chatSeed>), readOnlyAt: T0 });
    await assert.rejects(postEventAnnouncement(w.deps, mod, { eventId: EV, text: 'late' }), refused('not_eligible'));
  });

  test('a retried announcement with the same clientId posts once', async () => {
    const w = createChatWorld();
    await postEventAnnouncement(w.deps, mod, { eventId: EV, text: 'một', clientId: 'a1' });
    await postEventAnnouncement(w.deps, mod, { eventId: EV, text: 'một', clientId: 'a1' });
    assert.equal(w.store.messagesOf(CHAT).length, 1);
  });
});
