import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  assignBooking,
  requestAssigneeChange,
  runStudioBookingSweeps,
  studioFaultOf,
} from '../src/studio_assignment.js';
import { studioBookingNotices } from '../src/studio_notifications.js';
import { acceptedStudioBooking, createBookingWorld, withStudio, type BookingWorld } from './support/booking_world.js';
import { createNotifyWorld, type NotifyWorld } from './support/notify_world.js';

// 2026-10-15 14:00 VN = 07:00Z; the assign deadline is 2026-10-14T07:00Z.
const DEADLINE_MS = Date.parse('2026-10-14T07:00:00.000Z');
const HOUR = 60 * 60 * 1000;

function worlds(): { w: BookingWorld; n: NotifyWorld } {
  const w = withStudio(createBookingWorld());
  const n = createNotifyWorld();
  n.users.users.set('s1', { name: 'Studio Mây', avatarUrl: null });
  n.users.users.set('c1', { name: 'An', avatarUrl: null });
  return { w, n };
}

/** Both clocks to the same instant, then one sweep. */
async function sweepAt(w: BookingWorld, n: NotifyWorld, at: number) {
  w.clock.setTime(new Date(at));
  n.clock.setTime(new Date(at));
  return runStudioBookingSweeps(w.studioDeps, n.deps);
}

const ids = (n: NotifyWorld, uid: string) => n.store.rowsOf(uid).map((r) => r.id).sort();

describe('runStudioBookingSweeps', () => {
  it('overdue marks once, counts lateAssignCount once, notifies customer and studio', async () => {
    const { w, n } = worlds();
    const b = await acceptedStudioBooking(w);
    const first = await sweepAt(w, n, DEADLINE_MS);
    assert.deepEqual(first, { overdue: 1, reminders: 0, changesExpired: 0 });
    const after = await w.store.getBooking(b.id);
    assert.equal(after?.assignOverdue, true);
    assert.deepEqual(after?.studioFault, { kind: 'assign_overdue', at: '2026-10-14T07:00:00.000Z' });
    assert.equal(w.store.counterOf('s1', 'lateAssignCount'), 1);
    assert.deepEqual(ids(n, 'c1'), [`n_assign_overdue_${b.id}_customer`]);
    assert.deepEqual(ids(n, 's1'), [`n_assign_overdue_${b.id}_studio`]);
    assert.ok(after);
    assert.equal(studioFaultOf(after, w.clock.now()), 'assign_overdue');

    const second = await sweepAt(w, n, DEADLINE_MS + HOUR);
    assert.deepEqual(second, { overdue: 0, reminders: 0, changesExpired: 0 });
    assert.equal(w.store.counterOf('s1', 'lateAssignCount'), 1);
    assert.equal((await w.store.getBooking(b.id))?.version, after?.version);
  });

  it('reminders at 48 h and 26 h fire once each', async () => {
    const { w, n } = worlds();
    const b = await acceptedStudioBooking(w);
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - 24 * HOUR - 1), { overdue: 0, reminders: 0, changesExpired: 0 });
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - 24 * HOUR), { overdue: 0, reminders: 1, changesExpired: 0 });
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - 20 * HOUR), { overdue: 0, reminders: 0, changesExpired: 0 });
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - 2 * HOUR), { overdue: 0, reminders: 1, changesExpired: 0 });
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - HOUR), { overdue: 0, reminders: 0, changesExpired: 0 });
    assert.deepEqual((await w.store.getBooking(b.id))?.assignRemindersSent, ['h48', 'h26']);
    assert.deepEqual(ids(n, 's1'), [`n_assign_reminder_${b.id}_26`, `n_assign_reminder_${b.id}_48`]);
    assert.deepEqual(ids(n, 'c1'), []);
  });

  it('a booking first seen at the 26 h mark gets only that reminder', async () => {
    const { w, n } = worlds();
    const b = await acceptedStudioBooking(w);
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - HOUR), { overdue: 0, reminders: 1, changesExpired: 0 });
    assert.deepEqual(ids(n, 's1'), [`n_assign_reminder_${b.id}_26`]);
    assert.deepEqual((await w.store.getBooking(b.id))?.assignRemindersSent, ['h48', 'h26']);
  });

  it('an assigned booking gets no reminder and is never overdue', async () => {
    const { w, n } = worlds();
    const b = await acceptedStudioBooking(w);
    await assignBooking(w.studioDeps, 's1', { bookingId: b.id, assigneeId: 'm1' });
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - HOUR), { overdue: 0, reminders: 0, changesExpired: 0 });
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS + HOUR), { overdue: 0, reminders: 0, changesExpired: 0 });
    assert.deepEqual(ids(n, 's1'), []);
  });

  it('pending change past respondBy expires with change_expired', async () => {
    const { w, n } = worlds();
    const b = await acceptedStudioBooking(w);
    await assignBooking(w.studioDeps, 's1', { bookingId: b.id, assigneeId: 'm1' });
    const asked = await requestAssigneeChange(w.studioDeps, 'c1', { bookingId: b.id });
    const respondBy = Date.parse(asked.changeRequest?.respondBy ?? '');
    assert.deepEqual(await sweepAt(w, n, respondBy - 1), { overdue: 0, reminders: 0, changesExpired: 0 });
    assert.deepEqual(await sweepAt(w, n, respondBy), { overdue: 0, reminders: 0, changesExpired: 1 });
    const after = await w.store.getBooking(b.id);
    assert.ok(after);
    assert.equal(after.changeRequest?.status, 'expired');
    assert.equal(after.changeRequest?.answeredAt, new Date(respondBy).toISOString());
    assert.deepEqual(after.studioFault, { kind: 'change_expired', at: new Date(respondBy).toISOString() });
    assert.equal(w.store.counterOf('s1', 'changeDeclinedCount'), 1);
    assert.equal(after.assigneeId, 'm1');
    // the customer hears it through the booking write
    assert.deepEqual(studioBookingNotices(asked, after), ['change_answered']);
  });

  it('a sweep run twice changes nothing more', async () => {
    const { w, n } = worlds();
    const overdue = await acceptedStudioBooking(w);
    const changed = await acceptedStudioBooking(w, { customerId: 'c2' });
    await assignBooking(w.studioDeps, 's1', { bookingId: changed.id, assigneeId: 'm1' });
    await requestAssigneeChange(w.studioDeps, 'c2', { bookingId: changed.id });
    const at = DEADLINE_MS + HOUR;
    assert.deepEqual(await sweepAt(w, n, at), { overdue: 1, reminders: 0, changesExpired: 1 });
    const snapshot = [await w.store.getBooking(overdue.id), await w.store.getBooking(changed.id)];
    const rows = n.store.rows.size;
    assert.deepEqual(await sweepAt(w, n, at), { overdue: 0, reminders: 0, changesExpired: 0 });
    assert.deepEqual([await w.store.getBooking(overdue.id), await w.store.getBooking(changed.id)], snapshot);
    assert.equal(n.store.rows.size, rows);
    assert.equal(w.store.counterOf('s1', 'lateAssignCount'), 1);
    assert.equal(w.store.counterOf('s1', 'changeDeclinedCount'), 1);
  });

  it('without notify deps the sweep still marks', async () => {
    const { w } = worlds();
    const b = await acceptedStudioBooking(w);
    w.clock.setTime(new Date(DEADLINE_MS));
    assert.deepEqual(await runStudioBookingSweeps(w.studioDeps), { overdue: 1, reminders: 0, changesExpired: 0 });
    assert.equal((await w.store.getBooking(b.id))?.assignOverdue, true);
  });
});
