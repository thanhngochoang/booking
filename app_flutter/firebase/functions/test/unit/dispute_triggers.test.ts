import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import {
  MemoryNotificationStore,
  MemoryPushSender,
  MemoryUserDirectory,
  type Dispute,
  type NotifyDeps,
} from '@photobooking/domain';
import { disputeToFirestore } from '../../src/infra/dispute_mapping.js';
import { handleDisputeWrite } from '../../src/triggers/dispute_write.js';

// `onDisputeWrite` (S18, #142 Decision 11): the trigger maps `disputes/{id}` and lets the domain's
// `notifyDisputeChange` decide; #138's hooks own the copy, targets and dedupe keys.

const OPENED_AT = '2026-10-20T10:00:00.000Z';
const RESOLVED_AT = '2026-10-21T09:00:00.000Z';

const openDispute: Dispute = {
  id: 'd1',
  subjectType: 'booking',
  subjectId: 'b1',
  eventId: null,
  paymentId: 'pay_b1',
  customerId: 'c1',
  providerId: 'p1',
  parties: ['c1', 'p1'],
  openedBy: 'customer',
  reason: 'photos_missing',
  description: 'Thiếu ảnh so với gói đã đặt',
  evidencePaths: ['disputeEvidence/c1/d1/f1.jpg'],
  snapshot: { title: 'Minh Trí · Chân dung', subtitle: 'T2 19/10 · 15:30–17:30', providerName: 'Minh Trí', thumbUrl: null },
  amountHeld: 500_000,
  status: 'open',
  outcome: null,
  threadId: 'dispute_d1',
  createdAt: OPENED_AT,
  updatedAt: OPENED_AT,
  resolvedAt: null,
  version: 1,
};

const resolvedDispute: Dispute = {
  ...openDispute,
  status: 'resolved',
  outcome: {
    kind: 'split',
    refundPercent: 40,
    refundAmount: 200_000,
    releaseAmount: 300_000,
    note: 'Thiếu một phần ảnh',
    decidedBy: 'staff1',
    decidedAt: RESOLVED_AT,
    refundId: 'rf_1',
  },
  resolvedAt: RESOLVED_AT,
  updatedAt: RESOLVED_AT,
  version: 2,
};

describe('dispute triggers', () => {
  let store: MemoryNotificationStore;
  let users: MemoryUserDirectory;

  const deps = (): NotifyDeps => ({
    store,
    push: new MemoryPushSender(),
    users,
    clock: { now: () => new Date(RESOLVED_AT) },
  });

  beforeEach(() => {
    store = new MemoryNotificationStore();
    users = new MemoryUserDirectory();
    users.users.set('c1', { name: 'An', avatarUrl: null });
    users.users.set('p1', { name: 'Minh Trí', avatarUrl: null });
  });

  it('created open dispute → one dispute_opened to the provider', async () => {
    await handleDisputeWrite(undefined, disputeToFirestore(openDispute), deps());
    const rows = store.rowsOf('p1');
    assert.equal(rows.length, 1);
    assert.equal(rows[0]?.type, 'dispute_opened');
    assert.equal(rows[0]?.target, '/disputes/d1');
    assert.equal(rows[0]?.title, 'An báo vấn đề với buổi chụp');
    assert.equal(store.rowsOf('c1').length, 0);
  });

  it('open → resolved → dispute_resolved to both parties', async () => {
    await handleDisputeWrite(disputeToFirestore(openDispute), disputeToFirestore(resolvedDispute), deps());
    for (const uid of ['c1', 'p1']) {
      const rows = store.rowsOf(uid);
      assert.equal(rows.length, 1, uid);
      assert.equal(rows[0]?.type, 'dispute_resolved');
      assert.equal(rows[0]?.target, '/disputes/d1');
      assert.equal(rows[0]?.title, 'Khiếu nại đã có kết quả');
    }
    // A later write that changes nothing about the status (a mirror, a retry) notifies nobody again.
    await handleDisputeWrite(disputeToFirestore(resolvedDispute), disputeToFirestore(resolvedDispute), deps());
    await handleDisputeWrite(disputeToFirestore(openDispute), disputeToFirestore(openDispute), deps());
    assert.equal(store.rowsOf('c1').length, 1);
    assert.equal(store.rowsOf('p1').length, 1);
  });

  it('a retry of the same event writes no second row (dedupe)', async () => {
    const created = [undefined, disputeToFirestore(openDispute)] as const;
    await handleDisputeWrite(...created, deps());
    await handleDisputeWrite(...created, deps());
    assert.equal(store.rowsOf('p1').length, 1);

    const resolved = [disputeToFirestore(openDispute), disputeToFirestore(resolvedDispute)] as const;
    await handleDisputeWrite(...resolved, deps());
    await handleDisputeWrite(...resolved, deps());
    assert.equal(store.rowsOf('c1').length, 1);
    assert.deepEqual(
      store.rowsOf('p1').map((r) => r.type).sort(),
      ['dispute_opened', 'dispute_resolved'],
    );
  });

  it('a deleted document notifies nobody', async () => {
    await handleDisputeWrite(disputeToFirestore(openDispute), undefined, deps());
    await handleDisputeWrite(disputeToFirestore(resolvedDispute), undefined, deps());
    await handleDisputeWrite(undefined, undefined, deps());
    assert.equal(store.rows.size, 0);
  });
});
