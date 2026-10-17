import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  handleBlockUser,
  handleUnblockUser,
  handleSubmitReport,
} from '../../src/callables/safety.js';
import type { CallableInput } from '../../src/callables/get_contact_link.js';
import {
  createSafetyWorld,
  type SafetyWorld,
} from '../../../../../packages/domain/test/support/safety_world.js';
import { MAX_BLOCKS } from '@photobooking/domain';

describe('safety callables', () => {
  it('blockUser without auth → unauthenticated', async () => {
    const { blockDeps } = createSafetyWorld();
    const req: CallableInput = {
      auth: undefined,
      data: { userId: 'u2' },
    };
    await assert.rejects(
      () => handleBlockUser(req, blockDeps),
      (err: unknown) => err instanceof HttpsError && err.code === 'unauthenticated',
    );
  });

  it('blockUser returns {blockedId}', async () => {
    const { blockDeps, profiles } = createSafetyWorld();
    profiles.setProfile('u2', 'User Two');
    const req: CallableInput = {
      auth: { uid: 'u1' } as any,
      data: { userId: 'u2' },
    };
    const res = await handleBlockUser(req, blockDeps);
    assert.deepEqual(res, { blockedId: 'u2' });
  });

  it('limit_exceeded → resource-exhausted', async () => {
    const { blockDeps, blockStore, profiles } = createSafetyWorld();
    const blockedList: string[] = [];
    for (let i = 0; i < MAX_BLOCKS; i++) {
      blockedList.push(`user_${i}`);
    }
    blockStore.indexes.set('u1', { blockedIds: blockedList, blockedByIds: [] });
    profiles.setProfile('u_new', 'New');

    const req: CallableInput = {
      auth: { uid: 'u1' } as any,
      data: { userId: 'u_new' },
    };
    await assert.rejects(
      () => handleBlockUser(req, blockDeps),
      (err: unknown) => err instanceof HttpsError && err.code === 'resource-exhausted',
    );
  });

  it('unblockUser returns {}', async () => {
    const { blockDeps } = createSafetyWorld();
    const req: CallableInput = {
      auth: { uid: 'u1' } as any,
      data: { userId: 'u2' },
    };
    const res = await handleUnblockUser(req, blockDeps);
    assert.deepEqual(res, {});
  });

  it('submitReport maps permission_denied for a non-member', async () => {
    const { reportDeps, reportStore } = createSafetyWorld();
    reportStore.setTarget({
      type: 'message',
      id: 'm1',
      chatId: 'chat_1',
      ownerId: 'u2',
      snapshot: { name: null, excerpt: 'msg', imageUrl: null },
    });

    const req: CallableInput = {
      auth: { uid: 'u_outsider' } as any,
      data: {
        targetType: 'message',
        targetId: 'm1',
        chatId: 'chat_1',
        reason: 'spam',
      },
    };
    await assert.rejects(
      () => handleSubmitReport(req, reportDeps),
      (err: unknown) => err instanceof HttpsError && err.code === 'permission-denied',
    );
  });

  it('submitReport returns duplicate true on the second call', async () => {
    const { reportDeps, reportStore } = createSafetyWorld();
    reportStore.setTarget({
      type: 'user',
      id: 'u2',
      chatId: null,
      ownerId: 'u2',
      snapshot: { name: 'U2', excerpt: null, imageUrl: null },
    });

    const req: CallableInput = {
      auth: { uid: 'u1' } as any,
      data: {
        targetType: 'user',
        targetId: 'u2',
        reason: 'spam',
      },
    };

    const res1 = await handleSubmitReport(req, reportDeps);
    assert.equal(res1.duplicate, false);

    const res2 = await handleSubmitReport(req, reportDeps);
    assert.equal(res2.duplicate, true);
    assert.equal(res2.reportId, res1.reportId);
  });
});
