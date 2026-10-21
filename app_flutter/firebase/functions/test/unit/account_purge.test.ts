import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import type { Firestore } from 'firebase-admin/firestore';
import type { Bucket } from '@google-cloud/storage';
import { purgeAccount, type PurgeDeps } from '../../src/infra/account_purge.js';
import { handleAccountDeletionUpdated } from '../../src/triggers/account_deletion.js';

interface MockStoreDoc {
  exists: boolean;
  data: () => Record<string, unknown> | undefined;
}

function createMockFirestore(accountDeletionDoc: Record<string, unknown> = {}) {
  const store = new Map<string, Record<string, unknown>>();
  store.set('account_deletions/u1', { ...accountDeletionDoc });
  store.set('users/u1', { displayName: 'Original User', role: 'customer' });

  return {
    collection: (col: string) => ({
      doc: (id: string) => {
        const path = `${col}/${id}`;
        return {
          id,
          get: async (): Promise<MockStoreDoc> => ({
            exists: store.has(path),
            data: () => store.get(path),
          }),
          set: async (val: Record<string, unknown>, opts?: { merge?: boolean }) => {
            const cur = store.get(path) ?? {};
            store.set(path, opts?.merge ? { ...cur, ...val } : val);
          },
          update: async (val: Record<string, unknown>) => {
            const cur = store.get(path) ?? {};
            if (val.done && typeof val.done === 'object' && ('elements' in val.done || '_elements' in val.done)) {
              const elements = ((val.done as { elements?: string[]; _elements?: string[] }).elements ||
                (val.done as { elements?: string[]; _elements?: string[] })._elements) ?? [];
              const existingDone = (cur.done as string[]) ?? [];
              cur.done = [...new Set([...existingDone, ...elements])];
              delete val.done;
            }
            store.set(path, { ...cur, ...val });
          },
          delete: async () => {
            store.delete(path);
          },
          collection: () => ({
            get: async () => ({ docs: [] }),
            doc: () => ({ delete: async () => {} }),
          }),
        };
      },
      where: () => ({
        get: async () => ({ docs: [] }),
      }),
    }),
    collectionGroup: () => ({
      where: () => ({
        get: async () => ({ docs: [] }),
      }),
    }),
    recursiveDelete: async () => {},
    bulkWriter: () => ({
      delete: () => {},
      update: () => {},
      close: async () => {},
    }),
    _store: store,
  };
}

describe('account_purge', () => {
  it('purge removes contacts and payout accounts and is idempotent', async () => {
    // Review Focus 4: run twice, the second run has nothing to do, Auth delete called once
    let authDeletedCount = 0;
    const mockDb = createMockFirestore({
      status: 'purging',
      done: [],
    });

    const deps: PurgeDeps = {
      firestore: mockDb as unknown as Firestore,
      bucket: {
        deleteFiles: async () => {},
      } as unknown as Bucket,
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
      deleteAuthUser: async () => {
        authDeletedCount++;
      },
      logBlocked: async () => {},
    };

    // First run
    const res1 = await purgeAccount('u1', deps);
    assert.equal(res1, 'done');
    assert.equal(authDeletedCount, 1);

    // Second run
    const res2 = await purgeAccount('u1', deps);
    assert.equal(res2, 'done');
    assert.equal(authDeletedCount, 1); // Not called again because step delete_auth is already done
  });

  it('purge tombstones users/{uid} and anonymizes registrations and hosted events', async () => {
    const mockDb = createMockFirestore({
      status: 'purging',
      done: [],
    });

    const deps: PurgeDeps = {
      firestore: mockDb as unknown as Firestore,
      bucket: {
        deleteFiles: async () => {},
      } as unknown as Bucket,
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
      deleteAuthUser: async () => {},
      logBlocked: async () => {},
    };

    await purgeAccount('u1', deps);
    const userDoc = mockDb._store.get('users/u1');
    assert.equal(userDoc?.displayName, 'Người dùng đã xoá');
    assert.equal(userDoc?.deleted, true);
    assert.equal(userDoc?.role, 'customer');
  });

  it('purge records each step in done[]', async () => {
    const mockDb = createMockFirestore({
      status: 'purging',
      done: [],
    });
    const deps: PurgeDeps = {
      firestore: mockDb as unknown as Firestore,
      bucket: { deleteFiles: async () => {} } as unknown as Bucket,
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
      deleteAuthUser: async () => {},
      logBlocked: async () => {},
    };

    await purgeAccount('u1', deps);
    const delDoc = mockDb._store.get('account_deletions/u1');
    assert.equal(delDoc?.status, 'done');
    assert.ok(Array.isArray(delDoc?.done));
    assert.ok(delDoc?.done && (delDoc.done as string[]).includes('delete_auth'));
    assert.ok(delDoc?.done && (delDoc.done as string[]).includes('tombstone_user'));
  });

  it('a blocker found at purge time stops the purge with status blocked', async () => {
    let loggedBlocked = false;
    const mockDb = createMockFirestore({
      status: 'purging',
      done: [],
    });
    const deps: PurgeDeps = {
      firestore: mockDb as unknown as Firestore,
      bucket: { deleteFiles: async () => {} } as unknown as Bucket,
      snapshot: async () => ({
        openBookings: [{ id: 'b1', title: 'Late booking', day: null }],
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
      deleteAuthUser: async () => {
        assert.fail('should not delete auth user');
      },
      logBlocked: async () => {
        loggedBlocked = true;
      },
    };

    const res = await purgeAccount('u1', deps);
    assert.equal(res, 'blocked');
    assert.equal(loggedBlocked, true);
    const delDoc = mockDb._store.get('account_deletions/u1');
    assert.equal(delDoc?.status, 'blocked');
    assert.deepEqual(delDoc?.blockedReasons, ['open_booking']);
  });

  it('the trigger ignores updates that do not move status to purging', async () => {
    let called = false;
    const deps: PurgeDeps = {
      firestore: {} as unknown as Firestore,
      bucket: {} as unknown as Bucket,
      snapshot: async () => {
        called = true;
        return {} as unknown as import('@photobooking/domain').AccountSnapshot;
      },
      deleteAuthUser: async () => {},
      logBlocked: async () => {},
    };

    // Before and after both pending
    const change = {
      before: { data: () => ({ status: 'pending' }) },
      after: { id: 'u1', data: () => ({ status: 'pending' }) },
    };

    await handleAccountDeletionUpdated(change as unknown as Parameters<typeof handleAccountDeletionUpdated>[0], deps);
    assert.equal(called, false);
  });
});
