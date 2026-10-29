import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { handleCreateBooking, handleTransitionBooking } from '../../src/callables/booking.js';
import { handleConfirmFakePayment, handleCreatePayment } from '../../src/callables/payment.js';
import { WEBHOOK_ENV } from './support/payment_world.js';

const bew = await import('../../../../../packages/domain/test/support/booking_entry_world.js');

const c1 = (data: unknown) => ({ auth: { uid: 'c1' }, data });

/** S30 (Decision 6, 15): a booking with entry tickets through the existing booking and payment callables. */
async function groupBooking() {
  const w = await bew.createBookingEntryWorld();
  const booking = await handleCreateBooking(c1({
    photographerId: 'p3', serviceId: 'srv_p3', day: bew.VISIT, start: '09:00', place: { name: 'Bãi đá sông Hồng' },
    entry: { eventId: bew.ENTRY_ID, visitDay: bew.VISIT, items: [{ ticketTypeId: 'adult', qty: 1 }] },
  }), w.bookingDeps);
  const pay = await handleCreatePayment(c1({ bookingId: booking.id, method: 'bank_qr' }), w.bookingDeps, WEBHOOK_ENV);
  return { w, booking, pay };
}

describe('bookings with entry tickets through the callables', () => {
  it('createBooking passes entry; createPayment returns the group payment with groupId and lines', async () => {
    const { booking, pay } = await groupBooking();
    assert.equal(booking.entry?.eventId, bew.ENTRY_ID);
    assert.equal(booking.customerId, 'c1');
    assert.equal(pay.groupId, pay.paymentId);
    assert.deepEqual(pay.lines?.map((l) => l.kind).sort(), ['booking', 'entry_ticket']);
  });

  it('confirmFakePayment on a line of the group confirms the group payment', async () => {
    const { w, pay } = await groupBooking();
    const line = pay.lines?.find((l) => l.kind === 'entry_ticket');
    assert.ok(line);
    const out = await handleConfirmFakePayment(c1({ paymentId: line.paymentId }), w.settlement, WEBHOOK_ENV);
    assert.equal(out.outcome, 'paid');
    assert.equal(bew.paymentOf(w, pay.paymentId)?.status, 'paid');
    for (const l of pay.lines ?? []) assert.equal(bew.paymentOf(w, l.paymentId)?.status, 'paid');
  });

  it('transitionBooking passes keepTickets: a customer cancel keeps the tickets paid', async () => {
    const { w, booking, pay } = await groupBooking();
    await handleConfirmFakePayment(c1({ paymentId: pay.paymentId }), w.settlement, WEBHOOK_ENV);
    const line = pay.lines?.find((l) => l.kind === 'entry_ticket');
    assert.ok(line);
    const cancelled = await handleTransitionBooking(c1({ bookingId: booking.id, action: 'cancel', keepTickets: true }), w.bookingDeps);
    assert.equal(cancelled.status, 'cancelled');
    assert.equal(w.entry.store.registrations.get(`${bew.ENTRY_ID}/${line.subjectId}`)?.status, 'paid');
  });

  it('transitionBooking refuses action scan from clients', async () => {
    const { w, booking } = await groupBooking();
    await assert.rejects(handleTransitionBooking(c1({ bookingId: booking.id, action: 'scan' }), w.bookingDeps), { code: 'invalid-argument' });
  });
});
