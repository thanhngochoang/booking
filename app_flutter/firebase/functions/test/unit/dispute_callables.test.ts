import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  FakePaymentGateway,
  MemoryDisputeStore,
  type DisputeDeps,
  type DisputeSubjectView,
  type Payment,
} from '@photobooking/domain';
import { handleOpenDispute, handleResolveDispute } from '../../src/callables/dispute.js';

const NOW = new Date('2026-10-20T10:00:00.000Z');
const HOUR = 3_600_000;
const DISPUTE_ID = '01JDISPUTE0000000000000001';

const httpsError = (code: string, detailsCode?: string) => (e: unknown) =>
  e instanceof HttpsError
  && e.code === code
  && (detailsCode === undefined || (e.details as { code?: string }).code === detailsCode);

function bookingView(over: Partial<DisputeSubjectView> = {}): DisputeSubjectView {
  return {
    type: 'booking',
    id: 'b1',
    eventId: null,
    customerId: 'c1',
    providerId: 'p1',
    state: 'completed',
    windowStart: new Date(NOW.getTime() - 2 * HOUR),
    shotAt: null,
    checkUntil: null,
    amount: 1_000_000,
    paymentId: null,
    disputeId: null,
    snapshot: { title: 'Minh Trí · Chân dung', subtitle: 'T2 19/10 · 15:30–17:30', providerName: 'Minh Trí', thumbUrl: null },
    ...over,
  };
}

function heldPayment(): Payment {
  const at = new Date(NOW.getTime() - 48 * HOUR).toISOString();
  return {
    id: 'pay_b1', subjectType: 'booking', subjectId: 'b1', payerId: 'c1', payeeId: 'p1', provider: 'fake',
    amount: 1_000_000, status: 'paid', escrowStatus: 'held', idempotencyKey: 'key_b1', paidAt: at, createdAt: at, updatedAt: at,
  };
}

const openInput = (over: Record<string, unknown> = {}) => ({
  disputeId: DISPUTE_ID,
  subjectType: 'booking',
  subjectId: 'b1',
  reason: 'photos_missing',
  description: 'Thiếu 20 ảnh so với gói đã đặt.',
  evidencePaths: [],
  ...over,
});

describe('dispute callables', () => {
  let store: MemoryDisputeStore;
  let gateway: FakePaymentGateway;
  let n = 0;
  const deps = (): DisputeDeps => ({
    store,
    gateway,
    cipher: { encrypt: async (s) => s, decrypt: async (s) => s },
    names: { displayName: async (uid) => (uid === 'c1' ? 'An' : 'Minh Trí') },
    clock: { now: () => NOW },
    ids: { newId: () => `id_${String(++n).padStart(4, '0')}` },
  });

  beforeEach(() => {
    store = new MemoryDisputeStore();
    gateway = new FakePaymentGateway();
    n = 0;
    store.putSubject(bookingView());
    store.payments.set('pay_b1', heldPayment());
  });

  test('openDispute without auth → unauthenticated', async () => {
    await assert.rejects(handleOpenDispute({ data: openInput() }, deps()), httpsError('unauthenticated', 'permission_denied'));
  });

  test('maps not_eligible, deadline_passed and conflict to failed-precondition/failed-precondition/aborted with details.code', async () => {
    store.putSubject(bookingView({ state: 'upcoming' }));
    await assert.rejects(
      handleOpenDispute({ auth: { uid: 'c1' }, data: openInput() }, deps()),
      httpsError('failed-precondition', 'not_eligible'),
    );

    store.putSubject(bookingView({ windowStart: new Date(NOW.getTime() - 30 * HOUR) }));
    await assert.rejects(
      handleOpenDispute({ auth: { uid: 'c1' }, data: openInput() }, deps()),
      httpsError('failed-precondition', 'deadline_passed'),
    );

    store.putSubject(bookingView());
    await handleOpenDispute({ auth: { uid: 'c1' }, data: openInput() }, deps());
    await assert.rejects(
      handleOpenDispute({ auth: { uid: 'c1' }, data: openInput({ disputeId: '01JDISPUTE0000000000000002' }) }, deps()),
      httpsError('aborted', 'conflict'),
    );
  });

  test('returns {disputeId}', async () => {
    const res = await handleOpenDispute({ auth: { uid: 'c1' }, data: openInput() }, deps());
    assert.deepEqual(res, { disputeId: DISPUTE_ID });
    assert.equal(store.disputes.get(DISPUTE_ID)?.status, 'open');
    assert.equal(store.payments.get('pay_b1')?.escrowStatus, 'disputed');
  });

  test('resolveDispute by a user without the admin claim → permission-denied', async () => {
    await handleOpenDispute({ auth: { uid: 'c1' }, data: openInput() }, deps());
    const data = { disputeId: DISPUTE_ID, outcome: 'refund', note: 'Thiếu ảnh thật.' };
    await assert.rejects(handleResolveDispute({ data }, deps()), httpsError('unauthenticated', 'permission_denied'));
    await assert.rejects(handleResolveDispute({ auth: { uid: 'c1' }, data }, deps()), httpsError('permission-denied', 'permission_denied'));
    await assert.rejects(
      handleResolveDispute({ auth: { uid: 's1', token: { staffRole: 'sales' } }, data }, deps()),
      httpsError('permission-denied', 'permission_denied'),
    );
    assert.equal(store.disputes.get(DISPUTE_ID)?.status, 'open');
  });

  test('resolveDispute by admin returns the amounts and dispatches the refund once', async () => {
    await handleOpenDispute({ auth: { uid: 'c1' }, data: openInput() }, deps());
    const res = await handleResolveDispute(
      { auth: { uid: 'staff1', token: { staffRole: 'admin' } }, data: { disputeId: DISPUTE_ID, outcome: 'split', refundPercent: 40, note: 'Thiếu một phần ảnh.' } },
      deps(),
    );
    assert.deepEqual(res, { disputeId: DISPUTE_ID, refundAmount: 400_000, releaseAmount: 600_000 });
    const refundId = store.disputes.get(DISPUTE_ID)?.outcome?.refundId;
    assert.ok(refundId);
    assert.deepEqual(gateway.refundCalls, [refundId]);
    assert.equal(store.refunds.get(refundId)?.status, 'done');
    assert.equal(store.disputes.get(DISPUTE_ID)?.outcome?.decidedBy, 'staff1');

    // A release has no refund to send.
    const other = '01JDISPUTE0000000000000003';
    store.putSubject(bookingView({ id: 'b2', disputeId: null }));
    store.payments.set('pay_b2', { ...heldPayment(), id: 'pay_b2', subjectId: 'b2', idempotencyKey: 'key_b2' });
    await handleOpenDispute({ auth: { uid: 'c1' }, data: openInput({ disputeId: other, subjectId: 'b2' }) }, deps());
    const released = await handleResolveDispute(
      { auth: { uid: 'staff1', token: { staffRole: 'admin' } }, data: { disputeId: other, outcome: 'release', note: 'Đủ ảnh theo gói.' } },
      deps(),
    );
    assert.deepEqual(released, { disputeId: other, refundAmount: 0, releaseAmount: 1_000_000 });
    assert.equal(gateway.refundCalls.length, 1);
  });
});
