import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { GeoPoint, Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  MemoryEventChatStore,
  type EventChatDeps,
  type GroupChat,
  type GroupMember,
  type GroupMessage,
} from '@photobooking/domain';
import {
  handleModerateEventChat,
  handlePostEventAnnouncement,
  handleSendEventMessage,
} from '../../src/callables/event_chat.js';
import {
  groupChatDoc,
  groupChatFrom,
  groupMemberDoc,
  groupMemberFrom,
  groupMessageDoc,
  groupMessageFrom,
} from '../../src/infra/event_chat_firestore.js';
import { registrationToFirestore } from '../../src/infra/event_firestore.js';
import { handleRegistrationWrite } from '../../src/triggers/registration_write.js';

const EV = 'ev1';
const CHAT = `event_${EV}`;
const T = new Date('2026-10-06T03:00:00.000Z');

const chat = (over: Partial<GroupChat> = {}): GroupChat => ({
  id: CHAT, eventId: EV, title: 'Photo walk', members: ['ph1', 'cu1'], moderators: ['ph1'], memberCount: 2,
  moderatorsOnly: false, lastMessageAt: null, lastMessagePreview: null, lastSenderId: null, readOnlyAt: null,
  createdAt: T, updatedAt: T, ...over,
});

const member = (uid: string, over: Partial<GroupMember> = {}): GroupMember => ({
  uid, role: uid === 'ph1' ? 'moderator' : 'member', name: `Tên ${uid}`, avatarUrl: null, mutedUntil: null, joinedAt: T,
  removedAt: null, removedBy: null, sentWindowStart: null, sentInWindow: 0, ...over,
});

describe('event chat callables', () => {
  let store: MemoryEventChatStore;
  let n: number;
  const deps = (): EventChatDeps => ({
    chats: store,
    people: { user: async (uid) => ({ name: `Tên ${uid}`, avatarUrl: null }) },
    clock: { now: () => T },
    ids: { newId: () => `id${n++}` },
  });

  beforeEach(() => {
    store = new MemoryEventChatStore();
    n = 1;
    store.seedChat(chat());
    store.seedMember(CHAT, member('ph1'));
    store.seedMember(CHAT, member('cu1'));
  });

  it('unauthenticated is refused', async () => {
    for (const h of [handleSendEventMessage, handleModerateEventChat, handlePostEventAnnouncement]) {
      await assert.rejects(
        () => h({ auth: undefined, data: {} }, deps()),
        (e: unknown) => e instanceof HttpsError && e.code === 'unauthenticated'
          && (e.details as { code?: string } | undefined)?.code === 'permission_denied',
      );
    }
  });

  it('domain errors map to HttpsError with the code', async () => {
    await assert.rejects(
      () => handleSendEventMessage({ auth: { uid: 'stranger' }, data: { eventId: EV, message: { clientId: 'a', type: 'text', body: 'hi' } } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'permission-denied',
    );
    await assert.rejects(
      () => handleSendEventMessage({ auth: { uid: 'cu1' }, data: { eventId: EV } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'invalid-argument',
    );
    await assert.rejects(
      () => handleModerateEventChat({ auth: { uid: 'cu1' }, data: { eventId: EV, action: 'moderatorsOnly', on: true } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'permission-denied',
    );
    await assert.rejects(
      () => handlePostEventAnnouncement({ auth: { uid: 'ph1' }, data: { eventId: 'ghost', text: 'x' } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'not-found',
    );
  });

  it('the 21st message maps to resource-exhausted', async () => {
    for (let i = 0; i < 20; i++) {
      await handleSendEventMessage({ auth: { uid: 'cu1' }, data: { eventId: EV, message: { clientId: `m${i}`, type: 'text', body: 'x' } } }, deps());
    }
    await assert.rejects(
      () => handleSendEventMessage({ auth: { uid: 'cu1' }, data: { eventId: EV, message: { clientId: 'm20', type: 'text', body: 'x' } } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'resource-exhausted',
    );
  });

  it('send, announce and moderate end to end', async () => {
    assert.deepEqual(
      await handleSendEventMessage({ auth: { uid: 'cu1' }, data: { eventId: EV, message: { clientId: 'a', type: 'text', body: 'hi' } } }, deps()),
      { id: 'a' },
    );
    const { messageId } = await handlePostEventAnnouncement({ auth: { uid: 'ph1' }, data: { eventId: EV, text: 'Họp 8h' } }, deps());
    assert.equal(store.pinsOf(CHAT)[0]?.messageId, messageId);
    await handleModerateEventChat({ auth: { uid: 'ph1' }, data: { eventId: EV, action: 'unpin', messageId } }, deps());
    assert.equal(store.pinsOf(CHAT).length, 0);
    await handleModerateEventChat({ auth: { uid: 'ph1', token: { staffRole: 'admin' } }, data: { eventId: EV, action: 'delete', messageId: 'a' } }, deps());
    assert.equal(store.messagesOf(CHAT).find((m) => m.id === 'a')?.body, null);
  });
});

describe('registration trigger', () => {
  it('maps the Firestore documents and joins a paid registration', async () => {
    const store = new MemoryEventChatStore();
    store.seedChat(chat({ members: ['ph1'], memberCount: 1 }));
    const deps: EventChatDeps = {
      chats: store, people: { user: async () => null }, clock: { now: () => T }, ids: { newId: () => 'sys1' },
    };
    const reg = {
      id: 'r1', eventId: EV, userId: 'cu1', userName: 'Lan', userAvatarUrl: null, quantity: 1, amount: 0, status: 'paid' as const,
      holdExpiresAt: null, ticketCode: 'VE-AAAA-1012', paymentId: null, contactEligible: false, checkedInAt: null,
      cancelledAt: null, refundPercent: null,
      event: { title: 'T', type: 'photo_walk' as const, startAt: T, endAt: T, locationName: 'L', lat: 1, lng: 2, coverUrl: null },
      version: 1, createdAt: T, updatedAt: T,
    };
    const paid = registrationToFirestore(reg);
    assert.equal(await handleRegistrationWrite({ eventId: EV, regId: 'r1', before: undefined, after: paid }, deps), 'joined');
    assert.deepEqual(store.chats.get(CHAT)?.members, ['ph1', 'cu1']);
    assert.equal(await handleRegistrationWrite({ eventId: EV, regId: 'r1', before: undefined, after: paid }, deps), 'none');
    const cancelled = registrationToFirestore({ ...reg, status: 'cancelled' });
    assert.equal(await handleRegistrationWrite({ eventId: EV, regId: 'r1', before: paid, after: cancelled }, deps), 'left');
    assert.deepEqual(store.chats.get(CHAT)?.members, ['ph1']);
  });
});

describe('event chat Firestore mapping', () => {
  it('a chat, member and message survive the round trip', () => {
    const c = chat({ lastMessageAt: T, lastMessagePreview: 'hi', lastSenderId: 'cu1', readOnlyAt: T });
    const cd = groupChatDoc(c);
    assert.equal(cd.kind, 'event_group');
    assert.ok(cd.readOnlyAt instanceof Timestamp);
    assert.deepEqual(groupChatFrom(CHAT, cd), c);
    assert.equal(groupChatFrom(CHAT, { ...cd, kind: 'inquiry' }), null);

    const m = member('cu1', { mutedUntil: T, removedAt: T, removedBy: 'ph1', sentWindowStart: T, sentInWindow: 3 });
    const md = groupMemberDoc(m);
    assert.deepEqual(groupMemberFrom('cu1', md), m);
    assert.ok(!('unreadCount' in md) && !('lastReadAt' in md), 'client-owned fields are never written by the server');

    const msg: GroupMessage = {
      id: 'm1', chatId: CHAT, senderId: 'cu1', senderName: 'Lan', type: 'location', body: null, imagePath: null,
      point: { lat: 21, lng: 105 }, system: null, createdAt: T, deletedAt: null,
    };
    const msgDoc = groupMessageDoc(msg);
    assert.ok(msgDoc.point instanceof GeoPoint);
    assert.deepEqual(groupMessageFrom(CHAT, 'm1', msgDoc), msg);

    const sys: GroupMessage = {
      ...msg, id: 's1', senderId: null, senderName: null, type: 'system', point: null,
      system: { kind: 'member_joined', userId: 'cu1', name: 'Lan' },
    };
    assert.deepEqual(groupMessageFrom(CHAT, 's1', groupMessageDoc(sys)), sys);
  });
});
