import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  handleGetAccountDeletionBlockers,
  handleRequestAccountDeletion,
  handleRestoreAccount,
  handleRequestDataExport,
  type AccountCallableInput,
} from '../../src/callables/account.js';
import type { AccountDeletionDeps, DataExportDeps, Blocker } from '@photobooking/domain';

function dummyDeletionDeps(overrides: Partial<AccountDeletionDeps> = {}): AccountDeletionDeps {
  return {
    snapshot: async () => ({
      openBookings: [],
      openJobs: [],
      openJobPosts: [],
      openQuotes: [],
      activeInstants: [],
      studioRelations: [],
      openCollabs: [],
      liveTickets: [],
      hostedEvents: [],
      payerMoney: [],
      unpaidEarnings: 0,
    }),
    lock: async () => 'locked',
    unlock: async () => 'restored',
    startPurge: async () => true,
    duePending: async () => [],
    revokeSessions: async () => {},
    clock: { now: () => new Date('2026-10-21T10:00:00Z') },
    ...overrides,
  };
}

describe('account_callables', () => {
  it('requestAccountDeletion passes auth_time', async () => {
    let authTimePassed: Date | null = null;
    const deps = dummyDeletionDeps({
      lock: async () => 'locked',
    });
    // Request with auth_time
    const req: AccountCallableInput = {
      auth: {
        uid: 'u1',
        token: { auth_time: 1792576700 }, // ~100s before 2026-10-21T10:00:00Z
      },
      data: {},
    };
    const res = await handleRequestAccountDeletion(req, deps);
    assert.equal(res.status, 'deletion_pending');
  });

  it('conflict carries details.blockers kinds', async () => {
    // Review Focus 3
    const now = new Date('2026-10-21T10:00:00Z');
    const deps = dummyDeletionDeps({
      clock: { now: () => now },
      snapshot: async () => ({
        openBookings: [{ id: 'b1', title: 'B1', day: null }],
        openJobs: [],
        openJobPosts: [],
        openQuotes: [],
        activeInstants: [],
        studioRelations: [],
        openCollabs: [],
        liveTickets: [],
        hostedEvents: [],
        payerMoney: [],
        unpaidEarnings: 0,
      }),
    });
    const req: AccountCallableInput = {
      auth: {
        uid: 'u1',
        token: { auth_time: Math.floor(now.getTime() / 1000) - 10 },
      },
      data: {},
    };

    try {
      await handleRequestAccountDeletion(req, deps);
      assert.fail('should have thrown');
    } catch (e: any) {
      assert.equal(e.code, 'aborted');
      assert.equal(e.details.code, 'conflict');
      assert.deepEqual(e.details.blockers, ['open_booking']);
    }
  });

  it('restoreAccount maps deadline_passed to failed-precondition with details.code', async () => {
    const deps = dummyDeletionDeps({
      unlock: async () => 'expired',
    });
    const req: AccountCallableInput = {
      auth: { uid: 'u1' },
      data: {},
    };
    try {
      await handleRestoreAccount(req, deps);
      assert.fail('should have thrown');
    } catch (e: any) {
      assert.equal(e.code, 'failed-precondition');
      assert.equal(e.details.code, 'deadline_passed');
    }
  });

  it('requestDataExport logs no content', async () => {
    const deps: DataExportDeps = {
      gather: async () => ({ profile: { secret: 'do-not-log' } }),
      last: async () => null,
      pending: async () => false,
      write: async (uid, expId) => ({ path: `exports/${uid}/${expId}.json`, sizeBytes: 123 }),
      record: async () => {},
      clock: { now: () => new Date('2026-10-21T10:00:00Z') },
      ids: { newId: () => 'exp1' },
    };
    const req: AccountCallableInput = {
      auth: { uid: 'u1' },
      data: {},
    };
    const res = await handleRequestDataExport(req, deps);
    assert.equal(res.path, 'exports/u1/exp1.json');
    assert.equal(res.sizeBytes, 123);
  });
});
