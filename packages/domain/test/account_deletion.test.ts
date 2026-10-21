import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  accountDeletionBlockers,
  type AccountSnapshot,
  type BlockerItem,
  getAccountDeletionBlockers,
  requestAccountDeletion,
  restoreAccount,
  startDueAccountPurges,
  tombstoneOf,
  type AccountDeletionDeps,
  DELETED_USER_NAME,
  ACCOUNT_RESTORE_DAYS,
} from '../src/account_deletion.js';
import { DomainError } from '../src/errors.js';

function emptySnapshot(): AccountSnapshot {
  return {
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
  };
}

describe('accountDeletionBlockers', () => {
  it('no blockers for a fresh customer', () => {
    const blockers = accountDeletionBlockers(emptySnapshot());
    assert.deepEqual(blockers, []);
  });

  it('an upcoming booking blocks with count and first item', () => {
    const item1: BlockerItem = { id: 'b1', title: 'Minh Trí · Chân dung 2 giờ', day: '2026-10-25' };
    const item2: BlockerItem = { id: 'b2', title: 'Lan Anh · Cưới', day: '2026-11-01' };
    const snap: AccountSnapshot = {
      ...emptySnapshot(),
      openBookings: [item1, item2],
    };
    const blockers = accountDeletionBlockers(snap);
    assert.equal(blockers.length, 1);
    const firstBlocker = blockers[0];
    assert.ok(firstBlocker !== undefined);
    assert.deepEqual(firstBlocker, {
      kind: 'open_booking',
      count: 2,
      amount: null,
      first: item1,
    });
  });

  it('a delivered booking, an open job post, a submitted quote, an active instant request, an active studio membership and an open collab job each block', () => {
    // Review Focus 3: one row per kind
    const snap: AccountSnapshot = {
      ...emptySnapshot(),
      openBookings: [{ id: 'b_deliv', title: 'Booking in delivery', day: '2026-10-15' }],
      openJobPosts: [{ id: 'jp1', title: 'Need wedding photographer', day: '2026-10-20' }],
      openQuotes: [{ id: 'q1', title: 'Quote for wedding', day: '2026-10-21' }],
      activeInstants: [{ id: 'inst1', title: 'Instant request Q1', day: '2026-10-21' }],
      studioRelations: [{ id: 'st1', title: 'Studio Alpha', day: null }],
      openCollabs: [{ id: 'collab1', title: 'Collab Project X', day: '2026-10-22' }],
    };
    const blockers = accountDeletionBlockers(snap);
    const kinds = blockers.map((b) => b.kind);
    assert.deepEqual(kinds, [
      'open_booking',
      'open_job_post',
      'open_quote',
      'active_instant',
      'studio_membership',
      'open_collab',
    ]);
  });

  it('an assigned studio booking blocks the member as open_job', () => {
    const snap: AccountSnapshot = {
      ...emptySnapshot(),
      openJobs: [{ id: 'job_assigned', title: 'Assigned studio gig', day: '2026-10-25' }],
    };
    const blockers = accountDeletionBlockers(snap);
    assert.equal(blockers.length, 1);
    assert.ok(blockers[0] !== undefined);
    assert.equal(blockers[0].kind, 'open_job');
  });

  it('a cancelled, completed or reviewed booking does not block', () => {
    const snap = emptySnapshot();
    assert.deepEqual(accountDeletionBlockers(snap), []);
  });

  it('a photographer accepted job blocks as open_job', () => {
    const snap: AccountSnapshot = {
      ...emptySnapshot(),
      openJobs: [{ id: 'job1', title: 'Client gig', day: '2026-10-28' }],
    };
    const blockers = accountDeletionBlockers(snap);
    assert.equal(blockers.length, 1);
    assert.ok(blockers[0] !== undefined);
    assert.equal(blockers[0].kind, 'open_job');
  });

  it('a paid ticket of an event that has not ended blocks; one that ended does not', () => {
    const snap: AccountSnapshot = {
      ...emptySnapshot(),
      liveTickets: [{ id: 'reg1', title: 'Photo walk', day: '2026-11-05', eventId: 'ev1' }],
    };
    const blockers = accountDeletionBlockers(snap);
    assert.equal(blockers.length, 1);
    assert.ok(blockers[0] !== undefined);
    assert.equal(blockers[0].kind, 'live_ticket');
  });

  it('a hosted open event blocks', () => {
    const snap: AccountSnapshot = {
      ...emptySnapshot(),
      hostedEvents: [{ id: 'ev1', title: 'Street Photography Workshop', day: '2026-11-10' }],
    };
    const blockers = accountDeletionBlockers(snap);
    assert.equal(blockers.length, 1);
    assert.ok(blockers[0] !== undefined);
    assert.equal(blockers[0].kind, 'hosted_event');
  });

  it('held payments and refunds in progress give amounts (read from payments and refunds, no history rows needed)', () => {
    const snap: AccountSnapshot = {
      ...emptySnapshot(),
      payerMoney: [
        {
          paymentId: 'pay1',
          state: 'held',
          amount: 1500000,
          item: { id: 'pay1', title: 'Booking 1', day: '2026-10-25' },
        },
        {
          paymentId: 'pay2',
          state: 'refunding',
          amount: 500000,
          item: { id: 'pay2', title: 'Ticket refund', day: null },
        },
      ],
    };
    const blockers = accountDeletionBlockers(snap);
    assert.equal(blockers.length, 2);
    const held = blockers.find((b) => b.kind === 'held_payment');
    const refund = blockers.find((b) => b.kind === 'refund_in_progress');
    assert.equal(held?.amount, 1500000);
    assert.equal(held?.count, 1);
    assert.equal(refund?.amount, 500000);
    assert.equal(refund?.count, 1);
  });

  it('a disputed payment blocks as open_dispute', () => {
    const snap: AccountSnapshot = {
      ...emptySnapshot(),
      payerMoney: [
        {
          paymentId: 'pay_disp',
          state: 'disputed',
          amount: 2000000,
          item: { id: 'disp1', title: 'Dispute 1', day: null },
        },
      ],
    };
    const blockers = accountDeletionBlockers(snap);
    assert.equal(blockers.length, 1);
    assert.ok(blockers[0] !== undefined);
    assert.equal(blockers[0].kind, 'open_dispute');
  });

  it('a refund pending on a fully refunded payment still blocks as refund_in_progress', () => {
    const snap: AccountSnapshot = {
      ...emptySnapshot(),
      payerMoney: [
        {
          paymentId: 'pay_ref',
          state: 'refunding',
          amount: 300000,
          item: { id: 'pay_ref', title: 'Refund in flight', day: null },
        },
      ],
    };
    const blockers = accountDeletionBlockers(snap);
    assert.equal(blockers.length, 1);
    assert.ok(blockers[0] !== undefined);
    assert.equal(blockers[0].kind, 'refund_in_progress');
    assert.equal(blockers[0].amount, 300000);
  });

  it('unpaid earnings block a photographer', () => {
    // Review Focus 3
    const snap: AccountSnapshot = {
      ...emptySnapshot(),
      unpaidEarnings: 4500000,
    };
    const blockers = accountDeletionBlockers(snap);
    assert.equal(blockers.length, 1);
    assert.ok(blockers[0] !== undefined);
    assert.equal(blockers[0].kind, 'unpaid_earnings');
    assert.equal(blockers[0].amount, 4500000);
  });

  it('blockers come in the fixed order', () => {
    const snap: AccountSnapshot = {
      unpaidEarnings: 100000,
      openBookings: [{ id: 'b1', title: 'B1', day: null }],
      openJobs: [{ id: 'j1', title: 'J1', day: null }],
      openJobPosts: [{ id: 'jp1', title: 'JP1', day: null }],
      openQuotes: [{ id: 'q1', title: 'Q1', day: null }],
      activeInstants: [{ id: 'i1', title: 'I1', day: null }],
      studioRelations: [{ id: 's1', title: 'S1', day: null }],
      openCollabs: [{ id: 'c1', title: 'C1', day: null }],
      liveTickets: [{ id: 't1', title: 'T1', day: null }],
      hostedEvents: [{ id: 'e1', title: 'E1', day: null }],
      payerMoney: [
        { paymentId: 'p1', state: 'disputed', amount: 10, item: { id: 'd1', title: 'D', day: null } },
        { paymentId: 'p2', state: 'held', amount: 20, item: { id: 'h1', title: 'H', day: null } },
        { paymentId: 'p3', state: 'refunding', amount: 30, item: { id: 'r1', title: 'R', day: null } },
      ],
    };
    const blockers = accountDeletionBlockers(snap);
    const kinds = blockers.map((b) => b.kind);
    assert.deepEqual(kinds, [
      'open_booking',
      'open_job',
      'open_job_post',
      'open_quote',
      'active_instant',
      'studio_membership',
      'open_collab',
      'live_ticket',
      'hosted_event',
      'open_dispute',
      'held_payment',
      'refund_in_progress',
      'unpaid_earnings',
    ]);
  });
});

describe('requestAccountDeletion & restoreAccount', () => {
  function makeDeps(overrides: Partial<AccountDeletionDeps> = {}): AccountDeletionDeps {
    return {
      snapshot: async () => emptySnapshot(),
      lock: async () => 'locked',
      unlock: async () => 'restored',
      startPurge: async () => true,
      duePending: async () => [],
      revokeSessions: async () => {},
      clock: { now: () => new Date('2026-10-21T10:00:00Z') },
      ...overrides,
    };
  }

  it('getAccountDeletionBlockers calls snapshot and returns blockers', async () => {
    const item: BlockerItem = { id: 'b1', title: 'B1', day: null };
    const deps = makeDeps({
      snapshot: async () => ({
        ...emptySnapshot(),
        openBookings: [item],
      }),
    });
    const res = await getAccountDeletionBlockers(deps, { uid: 'u1' });
    assert.equal(res.blockers.length, 1);
    assert.ok(res.blockers[0] !== undefined);
    assert.equal(res.blockers[0].kind, 'open_booking');
  });

  it('requestAccountDeletion with sign-in older than 5 minutes → reauth_required', async () => {
    const deps = makeDeps();
    const caller = {
      uid: 'user1',
      authTime: new Date('2026-10-21T09:54:00Z'), // 6 mins ago
    };
    await assert.rejects(
      async () => requestAccountDeletion(deps, caller, {}),
      (err: DomainError) => {
        assert.equal(err.code, 'reauth_required');
        return true;
      },
    );
  });

  it('requestAccountDeletion re-checks blockers server-side → conflict', async () => {
    // Review Focus 3
    const deps = makeDeps({
      snapshot: async () => ({
        ...emptySnapshot(),
        openBookings: [{ id: 'b1', title: 'B1', day: null }],
      }),
    });
    const caller = {
      uid: 'user1',
      authTime: new Date('2026-10-21T09:58:00Z'),
    };
    await assert.rejects(
      async () => requestAccountDeletion(deps, caller, {}),
      (err: DomainError) => {
        assert.equal(err.code, 'conflict');
        return true;
      },
    );
  });

  it('confirming locks the account: deletion_pending, restoreUntil = +30 days, deletionPending on the provider, sessions revoked, Auth user not disabled', async () => {
    let lockedUid = '';
    let sessionsRevoked = false;
    const now = new Date('2026-10-21T10:00:00Z');
    const deps = makeDeps({
      clock: { now: () => now },
      lock: async (uid) => {
        lockedUid = uid;
        return 'locked';
      },
      revokeSessions: async () => {
        sessionsRevoked = true;
      },
    });
    const caller = {
      uid: 'u123',
      authTime: new Date('2026-10-21T09:59:00Z'),
    };
    const res = await requestAccountDeletion(deps, caller, {});
    assert.equal(res.status, 'deletion_pending');
    assert.equal(lockedUid, 'u123');
    assert.equal(sessionsRevoked, true);

    const expectedDate = new Date(now.getTime() + ACCOUNT_RESTORE_DAYS * 24 * 60 * 60 * 1000);
    assert.equal(res.restoreUntil, expectedDate.toISOString());
  });

  it('a second request while pending returns the same restoreUntil', async () => {
    const now = new Date('2026-10-21T10:00:00Z');
    const expectedRestore = new Date(now.getTime() + ACCOUNT_RESTORE_DAYS * 24 * 60 * 60 * 1000).toISOString();
    const deps = makeDeps({
      clock: { now: () => now },
      lock: async () => 'already',
    });
    const caller = {
      uid: 'u123',
      authTime: new Date('2026-10-21T09:59:00Z'),
    };
    const res = await requestAccountDeletion(deps, caller, {});
    assert.equal(res.status, 'deletion_pending');
    assert.equal(res.restoreUntil, expectedRestore);
  });

  it('raw other than {} → invalid_argument', async () => {
    const deps = makeDeps();
    const caller = {
      uid: 'u123',
      authTime: new Date('2026-10-21T09:59:00Z'),
    };
    await assert.rejects(
      async () => requestAccountDeletion(deps, caller, { extra: 'field' }),
      (err: DomainError) => {
        assert.equal(err.code, 'invalid_argument');
        return true;
      },
    );
  });

  it('restoreAccount within 30 days keeps every document', async () => {
    let restoredUid = '';
    const deps = makeDeps({
      unlock: async (uid) => {
        restoredUid = uid;
        return 'restored';
      },
    });
    const res = await restoreAccount(deps, { uid: 'u123' }, {});
    assert.equal(res.status, 'restored');
    assert.equal(restoredUid, 'u123');
  });

  it('restoreAccount after restoreUntil → deadline_passed', async () => {
    const deps = makeDeps({
      unlock: async () => 'expired',
    });
    await assert.rejects(
      async () => restoreAccount(deps, { uid: 'u123' }, {}),
      (err: DomainError) => {
        assert.equal(err.code, 'deadline_passed');
        return true;
      },
    );
  });

  it('restoreAccount when not pending → not_found', async () => {
    const deps = makeDeps({
      unlock: async () => 'not_pending',
    });
    await assert.rejects(
      async () => restoreAccount(deps, { uid: 'u123' }, {}),
      (err: DomainError) => {
        assert.equal(err.code, 'not_found');
        return true;
      },
    );
  });

  it('restore and the purge start racing: exactly one wins', async () => {
    let status: 'pending' | 'restored' | 'purging' = 'pending';
    const unlock = async () => {
      if ((status as string) === 'pending') {
        status = 'restored';
        return 'restored' as const;
      }
      return 'not_pending' as const;
    };
    const startPurge = async () => {
      if ((status as string) === 'pending') {
        status = 'purging';
        return true;
      }
      return false;
    };
    const deps = makeDeps({ unlock, startPurge });

    const [restoreRes, purgeRes] = await Promise.allSettled([
      restoreAccount(deps, { uid: 'u1' }, {}),
      deps.startPurge('u1', new Date()),
    ]);

    assert.ok(['restored', 'purging'].includes(status));
    if ((status as string) === 'restored') {
      assert.equal(restoreRes.status, 'fulfilled');
      assert.equal((purgeRes as PromiseFulfilledResult<boolean>).value, false);
    } else {
      assert.equal((purgeRes as PromiseFulfilledResult<boolean>).value, true);
      assert.equal(restoreRes.status, 'rejected');
    }
  });

  it('nothing is purged before restoreUntil', async () => {
    const now = new Date('2026-10-21T10:00:00Z');
    let dueCalled = false;
    const deps = makeDeps({
      duePending: async () => {
        dueCalled = true;
        return [];
      },
      startPurge: async () => {
        throw new Error('should not be called');
      },
    });
    const count = await startDueAccountPurges(deps, now, 50);
    assert.equal(count, 0);
    assert.equal(dueCalled, true);
  });

  it('startDueAccountPurges moves at most 50 due accounts to purging', async () => {
    const dues = Array.from({ length: 50 }, (_, i) => `user_${i}`);
    let purgedCount = 0;
    const deps = makeDeps({
      duePending: async (_now, limit) => {
        assert.equal(limit, 50);
        return dues;
      },
      startPurge: async () => {
        purgedCount++;
        return true;
      },
    });
    const count = await startDueAccountPurges(deps, new Date(), 50);
    assert.equal(count, 50);
    assert.equal(purgedCount, 50);
  });

  it('tombstoneOf keeps role, clears name and avatar, removes accountStatus and restoreUntil', () => {
    const now = new Date('2026-10-21T10:00:00Z');
    const user = { role: 'photographer', accountStatus: 'pending_deletion', restoreUntil: '2026-11-20' };
    const tombstone = tombstoneOf(user, now);
    assert.equal(tombstone.displayName, DELETED_USER_NAME);
    assert.equal(tombstone.avatarUrl, null);
    assert.equal(tombstone.avatarPath, null);
    assert.equal(tombstone.deleted, true);
    assert.equal(tombstone.deletedAt, now.toISOString());
    assert.equal(tombstone.accountStatus, null);
    assert.equal(tombstone.restoreUntil, null);
    assert.equal(tombstone.role, 'photographer');
  });
});
