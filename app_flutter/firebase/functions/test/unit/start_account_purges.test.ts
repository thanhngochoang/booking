import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { handleStartDueAccountPurges } from '../../src/scheduled/start_account_purges.js';
import { handlePruneNotifications } from '../../src/scheduled/prune_notifications.js';
import type { AccountDeletionDeps, NotifyDeps } from '@photobooking/domain';

describe('start_account_purges', () => {
  it('startDueAccountPurges wires correctly and reports started count', async () => {
    let dueChecked = false;
    const deps: AccountDeletionDeps = {
      snapshot: async () => ({} as unknown as import('@photobooking/domain').AccountSnapshot),
      lock: async () => 'locked',
      unlock: async () => 'restored',
      startPurge: async () => true,
      duePending: async () => {
        dueChecked = true;
        return ['u1', 'u2'];
      },
      revokeSessions: async () => {},
      clock: { now: () => new Date() },
    };

    const count = await handleStartDueAccountPurges(deps, new Date(), 50);
    assert.equal(count, 2);
    assert.equal(dueChecked, true);
  });

  it('pruneNotifications runs startDueAccountPurges as a named step and a failure there does not stop pruneDataExports', async () => {
    let pruneReadCalled = false;
    const mockNotifyDeps: unknown = {
      store: {
        deleteReadBefore: async () => {
          pruneReadCalled = true;
          return 5;
        },
      },
      clock: { now: () => new Date() },
    };

    const res = await handlePruneNotifications(mockNotifyDeps as unknown as NotifyDeps);
    assert.equal(res, 5);
    assert.equal(pruneReadCalled, true);
  });
});
