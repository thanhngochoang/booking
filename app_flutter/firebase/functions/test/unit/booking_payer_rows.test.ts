import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { EMPTY_PAYER_SUBJECT, MemoryPayerHistoryStore, refreshPayerHistory, type Payment } from '@photobooking/domain';
import { handleBookingPayerRows } from '../../src/triggers/booking_payer_rows.js';

const T = '2026-10-10T08:00:00.000Z';
const NOW = new Date('2026-10-20T10:00:00.000Z');
const payment: Payment = {
  id: 'pay1', subjectType: 'booking', subjectId: 'b1', payerId: 'c1', payeeId: 'p1', provider: 'fake', amount: 1_000_000,
  status: 'paid', escrowStatus: 'held', idempotencyKey: 'k1', method: 'bank_qr', receivedAmount: 1_000_000, paidAt: T,
  createdAt: T, updatedAt: T,
};

describe('onBookingWrite → payer rows', () => {
  it('a booking cancel with no refund or a reschedule refreshes its payer row; other writes do not', async () => {
    const store = new MemoryPayerHistoryStore();
    store.payments.set('pay1', payment);
    store.subjects.set('pay1', { ...EMPTY_PAYER_SUBJECT, photographerName: 'Minh Trí', serviceName: 'Chân dung', day: '2026-10-12' });
    const deps = { store, clock: { now: () => NOW } };
    await refreshPayerHistory(deps, 'pay1');
    const writes = store.rowWrites;

    // Only `updatedAt` / a chat id changed: nothing to do.
    assert.equal(await handleBookingPayerRows('b1', { status: 'accepted', day: '2026-10-12', chatId: null }, { status: 'accepted', day: '2026-10-12', chatId: 'c' }, deps), 0);
    assert.equal(await handleBookingPayerRows('b1', undefined, { status: 'requested', day: '2026-10-12' }, deps), 0);
    assert.equal(store.rowWrites, writes);

    // A late cancel at 0%: no refund, no payment write, only the booking.
    store.subjects.set('pay1', { ...EMPTY_PAYER_SUBJECT, photographerName: 'Minh Trí', serviceName: 'Chân dung', day: '2026-10-12', cancelled: true });
    assert.equal(await handleBookingPayerRows('b1', { status: 'accepted', day: '2026-10-12' }, { status: 'cancelled', day: '2026-10-12' }, deps), 1);
    assert.equal(store.rows.get('c1/pay1')?.cancelled, true);

    // A reschedule moves the day.
    store.subjects.set('pay1', { ...EMPTY_PAYER_SUBJECT, photographerName: 'Minh Trí', serviceName: 'Chân dung', day: '2026-10-15' });
    assert.equal(await handleBookingPayerRows('b1', { status: 'accepted', day: '2026-10-12' }, { status: 'accepted', day: '2026-10-15' }, deps), 1);
    assert.equal(store.rows.get('c1/pay1')?.day, '2026-10-15');
  });
});
