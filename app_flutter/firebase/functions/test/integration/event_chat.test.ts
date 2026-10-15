import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { AN, LAN, SEED_PASSWORD, SEED_USERS } from '../../seed/fixtures.js';
import { callAs, makeCustomer, publishFreeEvent, waitFor, type SocialEnv } from './event_social_support.js';

// Event group chat on the emulators: onRegistrationWrite joins and removes members, the callables
// send, moderate and announce. Needs the emulators; CI runs it.

let env: SocialEnv;

before(async () => {
  await resetEmulators();
  const app = initializeApp({ projectId: emulatorProject() }, 'event-chat-test');
  const db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  const tokens = new Map<string, string>();
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
  env = { app, db, tokens };
});
after(async () => {
  await deleteApp(env.app);
});

const chatOf = async (eventId: string) => (await env.db.doc(`chats/event_${eventId}`).get()).data();

describe('event group chat on the emulators', () => {
  test('a paid registration joins the chat and a refund removes it', async () => {
    const { eventId } = await publishFreeEvent(env, AN);
    const reg = await callAs(env, 'registerEvent', LAN, { eventId, quantity: 1, name: 'Lan' });
    assert.equal(reg.status, 200, reg.text);
    const regId = (reg.result as { registrationId: string }).registrationId;
    const joined = await waitFor('the member to join', async () => {
      const c = await chatOf(eventId);
      return (c?.members as string[]).includes(LAN) ? c : null;
    });
    assert.equal(joined.memberCount, 2);
    const member = (await env.db.doc(`chats/event_${eventId}/members/${LAN}`).get()).data();
    assert.equal(member?.role, 'member');
    assert.equal(member?.name, 'Lan (seed)', 'the profile display name, not the registration name (M7)');
    assert.equal('phone' in (member ?? {}), false);
    const lines = await env.db.collection(`chats/event_${eventId}/messages`).where('type', '==', 'system').get();
    assert.equal(lines.size, 1);

    const sent = await callAs(env, 'sendEventMessage', LAN, { eventId, message: { clientId: 'm1', type: 'text', body: 'Xin chào cả nhóm' } });
    assert.equal(sent.status, 200, sent.text);
    assert.equal((await env.db.doc(`chats/event_${eventId}/messages/m1`).get()).data()?.senderName, 'Lan (seed)');

    const cancel = await callAs(env, 'cancelRegistration', LAN, { eventId, registrationId: regId });
    assert.equal(cancel.status, 200, cancel.text);
    await waitFor('the member to leave', async () => (!((await chatOf(eventId))?.members as string[]).includes(LAN)) || null);
    assert.equal((await chatOf(eventId))?.memberCount, 1);
    assert.ok((await env.db.doc(`chats/event_${eventId}/members/${LAN}`).get()).data()?.removedAt);
    const after = await callAs(env, 'sendEventMessage', LAN, { eventId, message: { clientId: 'm2', type: 'text', body: 'còn đó không' } });
    assert.equal(after.status, 403);
  });

  test('an announcement is pinned; only moderators may post one', async () => {
    const { eventId } = await publishFreeEvent(env, AN);
    const stranger = await makeCustomer(env, 'chat');
    const denied = await callAs(env, 'postEventAnnouncement', stranger, { eventId, text: 'Hack' });
    assert.equal(denied.status, 403);
    const ok = await callAs(env, 'postEventAnnouncement', AN, { eventId, text: 'Tập trung 7h45' });
    assert.equal(ok.status, 200, ok.text);
    const messageId = (ok.result as { messageId: string }).messageId;
    const pin = (await env.db.doc(`chats/event_${eventId}/pins/${messageId}`).get()).data();
    assert.equal(pin?.body, 'Tập trung 7h45');
    assert.equal(pin?.pinnedBy, AN);
    const msg = (await env.db.doc(`chats/event_${eventId}/messages/${messageId}`).get()).data();
    assert.equal(msg?.senderName, 'An Studio (seed)');
  });

  test('moderators mute, remove and switch moderators-only; the 1-1 inbox is not notified', async () => {
    const { eventId } = await publishFreeEvent(env, AN);
    const guest = await makeCustomer(env, 'guest');
    await callAs(env, 'registerEvent', guest, { eventId, quantity: 1, name: 'Khách' });
    await waitFor('the guest to join', async () => ((await chatOf(eventId))?.members as string[]).includes(guest) || null);
    assert.equal((await callAs(env, 'moderateEventChat', guest, { eventId, action: 'moderatorsOnly', on: true })).status, 403);
    assert.equal((await callAs(env, 'moderateEventChat', AN, { eventId, action: 'moderatorsOnly', on: true })).status, 200);
    assert.equal((await callAs(env, 'sendEventMessage', guest, { eventId, message: { clientId: 'g1', type: 'text', body: 'hi' } })).status, 403);
    await callAs(env, 'moderateEventChat', AN, { eventId, action: 'moderatorsOnly', on: false });
    assert.equal((await callAs(env, 'moderateEventChat', AN, { eventId, action: 'mute', userId: guest })).status, 200);
    assert.equal((await callAs(env, 'sendEventMessage', guest, { eventId, message: { clientId: 'g2', type: 'text', body: 'hi' } })).status, 400);
    assert.equal((await callAs(env, 'moderateEventChat', AN, { eventId, action: 'remove', userId: guest })).status, 200);
    assert.equal(((await chatOf(eventId))?.members as string[]).includes(guest), false);
    await new Promise((r) => setTimeout(r, 1500));
    // Only chat rows count: a new account also gets the `new_member` badge notice.
    const inbox = await env.db.collection(`users/${guest}/notifications`).where('type', '==', 'chat_message').get();
    assert.equal(inbox.size, 0, 'group messages never create chat notifications');

    // O1/M8: a moderator restores the removed guest, who still holds the paid ticket.
    assert.equal((await callAs(env, 'moderateEventChat', guest, { eventId, action: 'restore', userId: guest })).status, 403);
    assert.equal((await callAs(env, 'moderateEventChat', AN, { eventId, action: 'restore', userId: guest })).status, 200);
    assert.ok(((await chatOf(eventId))?.members as string[]).includes(guest));
    const restored = (await env.db.doc(`chats/event_${eventId}/members/${guest}`).get()).data();
    assert.equal(restored?.removedBy, null);
    assert.equal(restored?.removedAt, null);
  });
});
