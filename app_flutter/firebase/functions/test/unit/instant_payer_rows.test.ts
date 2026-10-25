import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { EMPTY_PAYER_SUBJECT, MemoryPayerHistoryStore, refreshPayerHistory, type Payment } from '@photobooking/domain';
import { handleInstantPayerRows } from '../../src/triggers/instant_payer_rows.js';

const T = '2026-10-10T08:00:00.000Z';
const NOW = new Date('2026-10-20T10:00:00.000Z');
const payment: Payment = {
  id: 'pay1', subjectType: 'instant_request', subjectId: 'ir1', payerId: 'c1', payeeId: '', provider: 'fake', amount: 500_000,
  status: 'paid', escrowStatus: 'held', idempotencyKey: 'k1', method: 'momo', receivedAmount: 500_000, paidAt: T,
  createdAt: T, updatedAt: T,
};

describe('onInstantRequestWrite → payer rows', () => {
  it('a status change with no payment write refreshes the Chụp ngay row; other writes do not', async () => {
    const store = new MemoryPayerHistoryStore();
    store.payments.set('pay1', payment);
    store.subjects.set('pay1', { ...EMPTY_PAYER_SUBJECT, areaLabel: 'Quận 1', searching: true });
    const deps = { store, clock: { now: () => NOW } };
    await refreshPayerHistory(deps, 'pay1');
    assert.equal(store.rows.get('c1/pay1')?.searching, true);
    const writes = store.rowWrites;

    // Created, deleted or same status: nothing to do.
    assert.equal(await handleInstantPayerRows('ir1', null, { status: 'searching' }, deps), 0);
    assert.equal(await handleInstantPayerRows('ir1', { status: 'searching' }, null, deps), 0);
    assert.equal(await handleInstantPayerRows('ir1', { status: 'searching' }, { status: 'searching' }, deps), 0);
    assert.equal(store.rowWrites, writes);

    // searching → no_match: the row stops saying "đang tìm thợ".
    store.subjects.set('pay1', { ...EMPTY_PAYER_SUBJECT, areaLabel: 'Quận 1', searching: false });
    assert.equal(await handleInstantPayerRows('ir1', { status: 'searching' }, { status: 'no_match' }, deps), 1);
    assert.equal(store.rows.get('c1/pay1')?.searching, false);

    // no_match → choosing: it says it again.
    store.subjects.set('pay1', { ...EMPTY_PAYER_SUBJECT, areaLabel: 'Quận 1', searching: true });
    assert.equal(await handleInstantPayerRows('ir1', { status: 'no_match' }, { status: 'choosing' }, deps), 1);
    assert.equal(store.rows.get('c1/pay1')?.searching, true);
  });
});
