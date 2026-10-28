import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { DomainError } from '../src/errors.js';
import { collabChatId, openCollabChat } from '../src/open_collab_chat.js';
import { sendMessage } from '../src/send_message.js';
import { createChatWorld } from './support/chat_world.js';
import { createRecruitWorld, seedCollaboration } from './support/recruit_world.js';

const DAY_MS = 24 * 60 * 60 * 1000;

function world() {
  const w = createRecruitWorld();
  const cw = createChatWorld();
  cw.clock.set(w.clock.now());
  return { w, cw, deps: { ...cw.deps, recruit: w.store } };
}

async function code(p: Promise<unknown>): Promise<string> {
  try {
    await p;
  } catch (e) {
    assert.ok(e instanceof DomainError, String(e));
    return e.code;
  }
  assert.fail('expected a DomainError');
}

const text = (body: string, clientId: string) => ({ type: 'text', body, clientId });

describe('openCollabChat', () => {
  it('creates collab_{studio}_{uid} with the studio in customerId and the collaborator in photographerId', async () => {
    const { w, cw, deps } = world();
    seedCollaboration(w, 's1', 'p1');
    assert.equal(collabChatId('s1', 'p1'), 'collab_s1_p1');
    assert.deepEqual(await openCollabChat(deps, 's1', { collaboratorId: 'p1' }), { chatId: 'collab_s1_p1' });
    const chat = cw.chats.chats.get('collab_s1_p1');
    assert.ok(chat);
    assert.equal(chat.kind, 'collab');
    assert.equal(chat.customerId, 's1');
    assert.equal(chat.photographerId, 'p1');
    assert.equal(chat.assigneeId, null);
    assert.equal(chat.bookingId, null);
    assert.equal(chat.readOnlyAt, null);
    assert.deepEqual(chat.createdAt, cw.clock.now());
    assert.equal(cw.chats.unread.get('collab_s1_p1')?.get('s1'), 0);
    assert.equal(cw.chats.unread.get('collab_s1_p1')?.get('p1'), 0);
  });

  it('returns the existing chat', async () => {
    const { w, cw, deps } = world();
    seedCollaboration(w, 's1', 'p1');
    await openCollabChat(deps, 's1', { collaboratorId: 'p1' });
    await sendMessage(cw.deps, { senderId: 's1', chatId: 'collab_s1_p1', message: text('Chào em', 'm1') });
    assert.deepEqual(await openCollabChat(deps, 'p1', { studioId: 's1' }), { chatId: 'collab_s1_p1' });
    assert.equal(cw.chats.chats.size, 1);
    assert.equal(cw.chats.chats.get('collab_s1_p1')?.lastMessagePreview, 'Chào em');
    assert.equal(cw.chats.messages.get('collab_s1_p1')?.length, 1);
  });

  it('refused (not_eligible) without an active collaboration', async () => {
    const { w, cw, deps } = world();
    assert.equal(await code(openCollabChat(deps, 's1', { collaboratorId: 'p1' })), 'not_eligible');
    seedCollaboration(w, 's1', 'p1', { status: 'invited', activeAt: null });
    assert.equal(await code(openCollabChat(deps, 's1', { collaboratorId: 'p1' })), 'not_eligible');
    seedCollaboration(w, 's1', 'p2', { status: 'ended', endedAt: new Date(cw.clock.now().getTime() - 30 * DAY_MS), endedBy: 'studio' });
    assert.equal(await code(openCollabChat(deps, 'p2', { studioId: 's1' })), 'not_eligible');
    seedCollaboration(w, 's1', 'p3');
    assert.equal(await code(openCollabChat(deps, 'p3', { collaboratorId: 's1' })), 'not_eligible', 'only the studio names a collaborator');
    assert.equal(await code(openCollabChat(deps, 's1', {})), 'invalid_argument');
    assert.equal(cw.chats.chats.size, 0);
  });

  it('an ended collaboration less than 30 days old returns the chat read-only', async () => {
    const { w, cw, deps } = world();
    seedCollaboration(w, 's1', 'p1');
    await openCollabChat(deps, 's1', { collaboratorId: 'p1' });
    const endedAt = cw.clock.now();
    seedCollaboration(w, 's1', 'p1', { status: 'ended', endedAt, endedBy: 'collaborator' });
    cw.clock.advance(29 * DAY_MS);
    assert.deepEqual(await openCollabChat(deps, 'p1', { studioId: 's1' }), { chatId: 'collab_s1_p1' });
    assert.deepEqual(cw.chats.chats.get('collab_s1_p1')?.readOnlyAt, endedAt);
    assert.equal(await code(sendMessage(cw.deps, { senderId: 's1', chatId: 'collab_s1_p1', message: text('Còn đó không?', 'm1') })),
      'not_eligible');

    // Never chatted: the read-only chat is created on demand.
    seedCollaboration(w, 's1', 'p2', { status: 'ended', endedAt: cw.clock.now(), endedBy: 'studio' });
    await openCollabChat(deps, 's1', { collaboratorId: 'p2' });
    assert.deepEqual(cw.chats.chats.get('collab_s1_p2')?.readOnlyAt, cw.clock.now());
  });

  it('a new activation clears readOnlyAt', async () => {
    const { w, cw, deps } = world();
    seedCollaboration(w, 's1', 'p1', { status: 'ended', endedAt: cw.clock.now(), endedBy: 'studio' });
    await openCollabChat(deps, 's1', { collaboratorId: 'p1' });
    assert.notEqual(cw.chats.chats.get('collab_s1_p1')?.readOnlyAt, null);
    seedCollaboration(w, 's1', 'p1', { activeAt: cw.clock.now() });
    await openCollabChat(deps, 'p1', { studioId: 's1' });
    assert.equal(cw.chats.chats.get('collab_s1_p1')?.readOnlyAt, null);
    await sendMessage(cw.deps, { senderId: 'p1', chatId: 'collab_s1_p1', message: text('Em quay lại rồi', 'm1') });
  });

  it('a new chat between parties who blocked each other is refused (blocked)', async () => {
    const { w, cw, deps } = world();
    seedCollaboration(w, 's1', 'p1');
    cw.blocks.block('p1', 's1');
    assert.equal(await code(openCollabChat(deps, 's1', { collaboratorId: 'p1' })), 'blocked');
    assert.equal(cw.chats.chats.size, 0);
  });
});
