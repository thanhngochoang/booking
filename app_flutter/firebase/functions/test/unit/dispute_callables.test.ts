import assert from 'node:assert/strict';
import { beforeEach, describe, test, type TestContext } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import {
  DomainError,
  FakePaymentGateway,
  MemoryDisputeStore,
  type DisputeDeps,
  type DisputeStore,
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

    // The same admin retrying the same decision (lost response) gets the same answer; nothing is sent again.
    const retried = await handleResolveDispute(
      { auth: { uid: 'staff1', token: { staffRole: 'admin' } }, data: { disputeId: DISPUTE_ID, outcome: 'split', refundPercent: 40, note: 'Thiếu một phần ảnh.' } },
      deps(),
    );
    assert.deepEqual(retried, res);
    assert.deepEqual(gateway.refundCalls, [refundId]);
    await assert.rejects(
      handleResolveDispute(
        { auth: { uid: 'staff2', token: { staffRole: 'admin' } }, data: { disputeId: DISPUTE_ID, outcome: 'split', refundPercent: 40, note: 'Thiếu một phần ảnh.' } },
        deps(),
      ),
      httpsError('aborted', 'conflict'),
    );

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
  /** The Functions logger writes warnings and errors as JSON lines to stderr (info to stdout). */
  function captureLogs(t: TestContext): string[] {
    const lines: string[] = [];
    for (const stream of [process.stdout, process.stderr]) {
      t.mock.method(stream, 'write', (chunk: unknown) => {
        lines.push(String(chunk));
        return true;
      });
    }
    return lines;
  }

  /** The store, except that every transaction after the decision is committed runs `after` instead. */
  function afterResolve(after: (fn: Parameters<DisputeStore['runTransaction']>[0]) => Promise<unknown>): DisputeStore {
    return {
      runTransaction: (fn) =>
        (store.disputes.get(DISPUTE_ID)?.status === 'resolved' ? after(fn) : store.runTransaction(fn)) as never,
      getRefundsForPayment: (id) => store.getRefundsForPayment(id),
      listByStatus: (status, limit) => store.listByStatus(status, limit),
    };
  }

  const admin = { uid: 'staff1', token: { staffRole: 'admin' } };
  const refundAll = { disputeId: DISPUTE_ID, outcome: 'refund', note: 'Thiếu ảnh thật.' };

  test('a refund send that throws logs the domain code with ids only; the decision stands', async (t) => {
    await handleOpenDispute({ auth: { uid: 'c1' }, data: openInput() }, deps());
    const failing = { ...deps(), store: afterResolve(async () => { throw new DomainError('not_found'); }) };
    const logs = captureLogs(t);
    const res = await handleResolveDispute({ auth: admin, data: refundAll }, failing);
    t.mock.restoreAll();
    assert.deepEqual(res, { disputeId: DISPUTE_ID, refundAmount: 1_000_000, releaseAmount: 0 });
    const line = logs.find((l) => l.includes('dispute_refund_send_failed'));
    assert.ok(line, logs.join(''));
    assert.match(line, /"code":"not_found"/);
    assert.match(line, new RegExp(`"refundId":"${store.disputes.get(DISPUTE_ID)?.outcome?.refundId}"`));
    assert.doesNotMatch(line, /Thiếu|1000000|An|Minh/);
    assert.deepEqual(gateway.refundCalls, []);
    assert.equal(store.refunds.get(store.disputes.get(DISPUTE_ID)?.outcome?.refundId ?? '')?.status, 'pending');
  });

  test('a refund whose payment cannot be read again is skipped with a log line, not sent', async (t) => {
    await handleOpenDispute({ auth: { uid: 'c1' }, data: openInput() }, deps());
    const missing = { ...deps(), store: afterResolve((fn) => store.runTransaction((tx) => fn({ ...tx, getPayment: async () => null }))) };
    const logs = captureLogs(t);
    const res = await handleResolveDispute({ auth: admin, data: refundAll }, missing);
    t.mock.restoreAll();
    assert.equal(res.refundAmount, 1_000_000);
    const line = logs.find((l) => l.includes('dispute_refund_send_skipped'));
    assert.ok(line, logs.join(''));
    assert.match(line, /"reason":"payment_not_found"/);
    assert.equal(logs.some((l) => l.includes('dispute_refund_send_failed')), false);
    assert.deepEqual(gateway.refundCalls, []);
  });
});
