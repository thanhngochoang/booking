import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  MemorySupportStore,
  type SupportDeps,
} from '@photobooking/domain';
import { handleSendSupportMessage } from '../../src/callables/support.js';

describe('support callables', () => {
  let store: MemorySupportStore;
  let nowTime: Date;
  let counter = 1;

  function deps(): SupportDeps {
    return {
      store,
      names: {
        displayName: async (uid) => (uid === 'u1' ? 'User One' : 'User Other'),
      },
      clock: { now: () => nowTime },
      ids: { newId: () => `id_${counter++}` },
    };
  }

  beforeEach(() => {
    store = new MemorySupportStore();
    nowTime = new Date('2026-10-10T12:00:00.000Z');
    counter = 1;
  });

  it('sendSupportMessage without auth → unauthenticated', async () => {
    await assert.rejects(
      async () => {
        await handleSendSupportMessage(
          { auth: undefined, data: { text: 'Hello', clientId: 'c1' } },
          deps(),
        );
      },
      (e: unknown) => e instanceof HttpsError && e.code === 'unauthenticated',
    );
  });

  it('without threadId writes to help_{uid}', async () => {
    const res = await handleSendSupportMessage(
      {
        auth: { uid: 'u1' },
        data: { text: 'Need assistance', clientId: 'c1' },
      },
      deps(),
    );

    assert.equal(res.threadId, 'help_u1');
    assert.ok(res.messageId);

    const thread = await store.runTransaction((tx) => tx.getThread('help_u1'));
    assert.ok(thread);
    assert.equal(thread.kind, 'help');
    assert.equal(thread.ownerId, 'u1');
    assert.equal(thread.awaitingStaff, true);
    assert.equal(thread.lastMessagePreview, 'Need assistance');
  });

  it('limit_exceeded → resource-exhausted', async () => {
    const d = deps();
    for (let i = 0; i < 10; i++) {
      await handleSendSupportMessage(
        {
          auth: { uid: 'u1' },
          data: { text: `Message ${i}`, clientId: `c_${i}` },
        },
        d,
      );
    }

    await assert.rejects(
      async () => {
        await handleSendSupportMessage(
          {
            auth: { uid: 'u1' },
            data: { text: 'Message 11', clientId: 'c_11' },
          },
          d,
        );
      },
      (e: unknown) => e instanceof HttpsError && e.code === 'resource-exhausted',
    );
  });
});
