import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import {
  HELP,
  parseArgs,
  runCli,
  type CliIo,
} from '../../tools/support.js';
import {
  MemorySupportStore,
  type SupportDeps,
  type SupportMessage,
  type SupportThread,
} from '@photobooking/domain';

describe('support CLI', () => {
  let store: MemorySupportStore;
  let counter = 1;
  let lines: string[];

  function deps(): SupportDeps {
    return {
      store,
      names: { displayName: async () => 'Test User' },
      clock: { now: () => new Date('2026-10-10T12:00:00.000Z') },
      ids: { newId: () => `id_${counter++}` },
    };
  }

  function mockIo(threads: SupportThread[] = [], messages: SupportMessage[] = []): CliIo {
    return {
      print: (l) => void lines.push(l),
      listAwaitingStaff: async () => threads.filter((t) => t.awaitingStaff),
      showMessages: async () => messages,
      getThread: async (id) => threads.find((t) => t.id === id) ?? null,
      isStaff: async (uid) => uid === 'staff_admin' || uid === 'staff_sales',
    };
  }

  beforeEach(() => {
    store = new MemorySupportStore();
    counter = 1;
    lines = [];
  });

  it('parseArgs list/show/reply', () => {
    const listArgs = parseArgs(['list']);
    assert.deepEqual(listArgs, { command: 'list', threadId: null, text: null, actor: null });

    const showArgs = parseArgs(['show', 'help_u1']);
    assert.deepEqual(showArgs, { command: 'show', threadId: 'help_u1', text: null, actor: null });

    const replyArgs = parseArgs(['reply', 'help_u1', 'Xin chao ban', '--actor', 'staff_1']);
    assert.deepEqual(replyArgs, {
      command: 'reply',
      threadId: 'help_u1',
      text: 'Xin chao ban',
      actor: 'staff_1',
    });
  });

  it('reply needs text and --actor', async () => {
    assert.throws(
      () => parseArgs(['reply', 'help_u1']),
      /reply needs text/,
    );

    const parsed = parseArgs(['reply', 'help_u1', 'Text']);
    assert.equal(parsed.actor, null);

    const io = mockIo([]);
    await assert.rejects(
      async () => {
        await runCli(['reply', 'help_u1', 'Text'], deps(), io);
      },
      /reply needs --actor <uid>/,
    );
  });

  it('--help prints HELP', () => {
    assert.ok(HELP.includes('usage: support list | show <threadId> | reply <threadId> "<text>" --actor <uid>'));
    assert.ok(HELP.includes('admin or sales'));
  });

  it('runCli list prints awaitingStaff threads', async () => {
    const t1: SupportThread = {
      id: 'help_u1',
      kind: 'help',
      ownerId: 'u1',
      disputeId: null,
      participants: ['u1'],
      status: 'open',
      awaitingStaff: true,
      lastMessageAt: '2026-10-10T12:00:00.000Z',
      lastMessagePreview: 'Need help',
      lastSenderRole: 'user',
      rate: {},
      createdAt: '2026-10-10T11:00:00.000Z',
      updatedAt: '2026-10-10T12:00:00.000Z',
    };

    const io = mockIo([t1]);
    await runCli(['list'], deps(), io);
    assert.equal(lines.length, 1);
    assert.ok(lines[0]?.includes('help_u1'));
    assert.ok(lines[0]?.includes('awaitingStaff:true'));
  });

  it('runCli reply calls staffReply when actor is staff', async () => {
    const t1: SupportThread = {
      id: 'help_u1',
      kind: 'help',
      ownerId: 'u1',
      disputeId: null,
      participants: ['u1'],
      status: 'open',
      awaitingStaff: true,
      lastMessageAt: '2026-10-10T12:00:00.000Z',
      lastMessagePreview: 'Need help',
      lastSenderRole: 'user',
      rate: {},
      createdAt: '2026-10-10T11:00:00.000Z',
      updatedAt: '2026-10-10T12:00:00.000Z',
    };
    await store.runTransaction(async (tx) => {
      tx.putThread(t1);
    });

    const io = mockIo([t1]);
    await runCli(['reply', 'help_u1', 'Da xu ly xong', '--actor', 'staff_admin'], deps(), io);

    assert.equal(lines.length, 1);
    assert.ok(lines[0]?.includes('replied with message'));

    const updated = await store.runTransaction((tx) => tx.getThread('help_u1'));
    assert.equal(updated?.awaitingStaff, false);
    assert.equal(updated?.lastMessagePreview, 'Da xu ly xong');
    assert.equal(updated?.lastSenderRole, 'staff');
  });

  it('runCli reply refuses non-staff actor', async () => {
    const io = mockIo([]);
    await assert.rejects(
      async () => {
        await runCli(['reply', 'help_u1', 'Xin chao', '--actor', 'normal_user'], deps(), io);
      },
      /does not have staffRole claim/,
    );
  });
});
