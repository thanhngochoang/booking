import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import type { Booking } from '../src/booking.js';
import { bookingNotices, notifyBookingChange } from '../src/booking_notifications.js';
import { notifyStudioBookingChange, studioBookingNotices, vnHourDay } from '../src/studio_notifications.js';
import { makeTestBooking } from './support/booking_fixtures.js';
import { createNotifyWorld, type NotifyWorld } from './support/notify_world.js';

const unassigned: Booking = makeTestBooking({
  id: 'b1',
  customerId: 'c1',
  photographerId: 's1',
  status: 'accepted',
  day: '2026-10-12',
  start: '15:30',
  isStudio: true,
  assigneeId: null,
  assigneeKind: null,
  assignStatus: 'unassigned',
  assignDeadline: '2026-10-11T08:30:00.000Z',
  assignOverdue: false,
  assignedAt: null,
  assignments: [],
  changeRequest: null,
  studioFault: null,
  assignmentReturned: null,
});
const withA1: Booking = { ...unassigned, assigneeId: 'a1', assigneeKind: 'member', assignStatus: 'assigned', assignedAt: '2026-10-10T10:00:00.000Z' };
const withA2: Booking = { ...withA1, assigneeId: 'a2', assignedAt: '2026-10-10T12:00:00.000Z' };
const pending: Booking = {
  ...withA1,
  changeRequest: {
    at: '2026-10-10T11:00:00.000Z',
    note: null,
    respondBy: '2026-10-10T17:00:00.000Z',
    status: 'pending',
    declineReason: null,
    answeredAt: null,
  },
};
const answered = (status: 'declined' | 'expired' | 'reassigned'): Booking => ({
  ...pending,
  changeRequest: pending.changeRequest ? { ...pending.changeRequest, status, answeredAt: '2026-10-10T12:00:00.000Z' } : null,
});

function world(): NotifyWorld {
  const n = createNotifyWorld();
  n.users.users.set('s1', { name: 'Studio Mây', avatarUrl: null });
  n.users.users.set('c1', { name: 'An', avatarUrl: null });
  n.users.users.set('a1', { name: 'Minh Trí', avatarUrl: null });
  n.users.users.set('a2', { name: 'Lan Chi', avatarUrl: null });
  return n;
}

/** uid → row ids, for every user that got a row. */
function rowsByUser(n: NotifyWorld): Record<string, string[]> {
  const out: Record<string, string[]> = {};
  for (const r of n.store.rows.values()) (out[r.userId] ??= []).push(r.id);
  for (const list of Object.values(out)) list.sort();
  return out;
}

describe('studioBookingNotices', () => {
  it('maps each studio change to one notice; creation, deletion and individual bookings send nothing', () => {
    assert.deepEqual(studioBookingNotices(unassigned, withA1), ['assigned']);
    assert.deepEqual(studioBookingNotices(withA1, withA2), ['reassigned']);
    assert.deepEqual(studioBookingNotices(withA1, pending), ['change_requested']);
    assert.deepEqual(studioBookingNotices(pending, answered('declined')), ['change_answered']);
    assert.deepEqual(studioBookingNotices(pending, answered('expired')), ['change_answered']);
    assert.deepEqual(studioBookingNotices(pending, { ...answered('reassigned'), assigneeId: 'a2' }), ['reassigned']);
    assert.deepEqual(
      studioBookingNotices(withA1, { ...withA1, assignmentReturned: { at: 'x', reason: null } }),
      ['assignment_returned'],
    );
    assert.deepEqual(studioBookingNotices(null, unassigned), []);
    assert.deepEqual(studioBookingNotices(withA1, null), []);
    assert.deepEqual(studioBookingNotices(withA1, { ...withA1, version: 9 }), []);
    const plain = makeTestBooking({ status: 'accepted' });
    assert.deepEqual(studioBookingNotices(plain, { ...plain, assigneeId: 'a1' }), []);
  });

  it('vnHourDay prints Vietnam time', () => {
    assert.equal(vnHourDay('2026-10-10T17:00:00.000Z'), '00:00 11/10');
  });
});

describe('notifyStudioBookingChange', () => {
  it('assigned → customer and assignee', async () => {
    const n = world();
    await notifyStudioBookingChange(n.deps, unassigned, withA1);
    assert.deepEqual(rowsByUser(n), {
      c1: ['n_booking_assigned_b1_a1_customer'],
      a1: ['n_booking_assigned_b1_a1_assignee'],
    });
  });

  it('a studio spot booking created already assigned tells the member when it leaves the draft, once (#194)', async () => {
    const draft: Booking = { ...withA1, status: 'draft', spotScheduleId: 'sched_1', spotId: 'spot_1', source: 'spot' };
    const requested: Booking = { ...draft, status: 'requested' };
    assert.deepEqual(studioBookingNotices(null, draft), []);
    assert.deepEqual(studioBookingNotices(draft, { ...draft, version: 2 }), []);
    assert.deepEqual(studioBookingNotices(draft, { ...draft, status: 'expired' }), []);
    assert.deepEqual(studioBookingNotices(requested, { ...requested, status: 'accepted' }), []);
    assert.deepEqual(studioBookingNotices({ ...draft, assigneeId: null }, { ...requested, assigneeId: null }), []);

    const n = world();
    await notifyStudioBookingChange(n.deps, draft, requested);
    // A retry of the same write is the same dedupe key: still one row each.
    await notifyStudioBookingChange(n.deps, draft, requested);
    assert.deepEqual(rowsByUser(n), {
      c1: ['n_booking_assigned_b1_a1_customer'],
      a1: ['n_booking_assigned_b1_a1_assignee'],
    });
  });

  it('reassigned → customer, old and new', async () => {
    const n = world();
    await notifyStudioBookingChange(n.deps, withA1, withA2);
    const at = '2026-10-10T12:00:00.000Z';
    assert.deepEqual(rowsByUser(n), {
      c1: [`n_booking_reassigned_b1_a1_a2_${at}_customer`.replace(/:/g, '_')],
      a1: [`n_booking_reassigned_b1_a1_a2_${at}_old`.replace(/:/g, '_')],
      a2: [`n_booking_reassigned_b1_a1_a2_${at}_new`.replace(/:/g, '_')],
    });
  });

  it('change requested → studio, with respondBy in Vietnam time', async () => {
    const n = world();
    await notifyStudioBookingChange(n.deps, withA1, pending);
    assert.deepEqual(rowsByUser(n), { s1: ['n_change_requested_b1'] });
    const row = n.store.rowsOf('s1')[0];
    assert.equal(row?.body, 'Buổi T2 12/10. Trả lời trước 00:00 11/10.');
  });

  it('declined/expired → customer', async () => {
    for (const status of ['declined', 'expired'] as const) {
      const n = world();
      await notifyStudioBookingChange(n.deps, pending, answered(status));
      assert.deepEqual(rowsByUser(n), { c1: [`n_change_answered_b1_${status}`] });
    }
  });

  it('a reassign that answers a change request sends only booking_reassigned', async () => {
    const n = world();
    await notifyStudioBookingChange(n.deps, pending, { ...answered('reassigned'), assigneeId: 'a2' });
    const at = '2026-10-10T10:00:00.000Z'.replace(/:/g, '_');
    assert.deepEqual(rowsByUser(n), {
      c1: [`n_booking_reassigned_b1_a1_a2_${at}_customer`],
      a1: [`n_booking_reassigned_b1_a1_a2_${at}_old`],
      a2: [`n_booking_reassigned_b1_a1_a2_${at}_new`],
    });
  });

  it('returned → studio', async () => {
    const n = world();
    await notifyStudioBookingChange(n.deps, withA1, { ...withA1, assignmentReturned: { at: 'x', reason: 'Ốm' } });
    assert.deepEqual(rowsByUser(n), { s1: ['n_assignment_returned_b1_a1'] });
  });

  it('cancel by studio_fault notifies only the studio (plus the refund notice)', async () => {
    const cancelled: Booking = {
      ...withA1,
      status: 'cancelled',
      cancel: { by: 'studio_fault', reason: 'change_declined', at: '2026-10-10T12:00:00.000Z', refundPercent: 100 },
    };
    assert.deepEqual(bookingNotices(withA1, cancelled), [{ to: 'photographer', kind: 'cancelled' }]);
    assert.deepEqual(studioBookingNotices(withA1, cancelled), []);
    const refunded = { ...cancelled, depositRefundedAt: '2026-10-10T12:00:00.000Z', depositRefunded: 1_000_000 };
    assert.deepEqual(bookingNotices(withA1, refunded), [
      { to: 'photographer', kind: 'cancelled' },
      { to: 'customer', kind: 'refund' },
    ]);
    const n = world();
    await notifyBookingChange(n.deps, withA1, cancelled);
    assert.deepEqual(Object.keys(rowsByUser(n)), ['s1']);
  });
});
