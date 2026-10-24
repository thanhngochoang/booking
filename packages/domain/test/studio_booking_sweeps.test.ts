import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { assignBooking, requestAssigneeChange, studioFaultOf } from '../src/studio_assignment.js';
import { assignSweepActionOf, runStudioBookingSweeps, runUnassignedStartSweep } from '../src/studio_booking_sweeps.js';
import { runBookingSweeps } from '../src/booking_sweeps.js';
import { bookingNotices } from '../src/booking_notifications.js';
import type { NotifyDeps } from '../src/notification_ports.js';
import type { StudioBookingTx } from '../src/booking_ports.js';
import { studioBookingNotices } from '../src/studio_notifications.js';
import { acceptedStudioBooking, createBookingWorld, withStudio, type BookingWorld } from './support/booking_world.js';
import { createNotifyWorld, type NotifyWorld } from './support/notify_world.js';

// 2026-10-15 14:00 VN = 07:00Z; the assign deadline is 2026-10-14T07:00Z.
const DEADLINE_MS = Date.parse('2026-10-14T07:00:00.000Z');
const HOUR = 60 * 60 * 1000;
const START_MS = Date.parse('2026-10-15T07:00:00.000Z');

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
    assert.deepEqual(first, { overdue: 1, reminders: 0, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0 });
    const after = await w.store.getBooking(b.id);
    assert.equal(after?.assignOverdue, true);
    assert.deepEqual(after?.studioFault, { kind: 'assign_overdue', at: '2026-10-14T07:00:00.000Z' });
    assert.equal(w.store.counterOf('s1', 'lateAssignCount'), 1);
    assert.deepEqual(ids(n, 'c1'), [`n_assign_overdue_${b.id}_customer`]);
    assert.deepEqual(ids(n, 's1'), [`n_assign_overdue_${b.id}_studio`]);
    assert.ok(after);
    assert.equal(studioFaultOf(after, w.clock.now()), 'assign_overdue');

    const second = await sweepAt(w, n, DEADLINE_MS + HOUR);
    assert.deepEqual(second, { overdue: 0, reminders: 0, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0 });
    assert.equal(w.store.counterOf('s1', 'lateAssignCount'), 1);
    assert.equal((await w.store.getBooking(b.id))?.version, after?.version);
  });

  it('reminders at 48 h and 26 h fire once each', async () => {
    const { w, n } = worlds();
    const b = await acceptedStudioBooking(w);
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - 24 * HOUR - 1), { overdue: 0, reminders: 0, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0 });
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - 24 * HOUR), { overdue: 0, reminders: 1, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0 });
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - 20 * HOUR), { overdue: 0, reminders: 0, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0 });
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - 2 * HOUR), { overdue: 0, reminders: 1, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0 });
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - HOUR), { overdue: 0, reminders: 0, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0 });
    assert.deepEqual((await w.store.getBooking(b.id))?.assignRemindersSent, ['h48', 'h26']);
    assert.deepEqual(ids(n, 's1'), [`n_assign_reminder_${b.id}_26`, `n_assign_reminder_${b.id}_48`]);
    assert.deepEqual(ids(n, 'c1'), []);
  });

  it('a booking first seen at the 26 h mark gets only that reminder', async () => {
    const { w, n } = worlds();
    const b = await acceptedStudioBooking(w);
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - HOUR), { overdue: 0, reminders: 1, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0 });
    assert.deepEqual(ids(n, 's1'), [`n_assign_reminder_${b.id}_26`]);
    assert.deepEqual((await w.store.getBooking(b.id))?.assignRemindersSent, ['h48', 'h26']);
  });

  it('an assigned booking gets no reminder and is never overdue', async () => {
    const { w, n } = worlds();
    const b = await acceptedStudioBooking(w);
    await assignBooking(w.studioDeps, 's1', { bookingId: b.id, assigneeId: 'm1' });
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - HOUR), { overdue: 0, reminders: 0, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0 });
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS + HOUR), { overdue: 0, reminders: 0, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0 });
    assert.deepEqual(ids(n, 's1'), []);
  });

  it('pending change past respondBy expires with change_expired', async () => {
    const { w, n } = worlds();
    const b = await acceptedStudioBooking(w);
    await assignBooking(w.studioDeps, 's1', { bookingId: b.id, assigneeId: 'm1' });
    const asked = await requestAssigneeChange(w.studioDeps, 'c1', { bookingId: b.id });
    const respondBy = Date.parse(asked.changeRequest?.respondBy ?? '');
    assert.deepEqual(await sweepAt(w, n, respondBy - 1), { overdue: 0, reminders: 0, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0 });
    assert.deepEqual(await sweepAt(w, n, respondBy), { overdue: 0, reminders: 0, changesExpired: 1, cancelledAtStart: 0, notifyFailed: 0 });
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
    assert.deepEqual(await sweepAt(w, n, at), { overdue: 1, reminders: 0, changesExpired: 1, cancelledAtStart: 0, notifyFailed: 0 });
    const snapshot = [await w.store.getBooking(overdue.id), await w.store.getBooking(changed.id)];
    const rows = n.store.rows.size;
    assert.deepEqual(await sweepAt(w, n, at), { overdue: 0, reminders: 0, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0 });
    assert.deepEqual([await w.store.getBooking(overdue.id), await w.store.getBooking(changed.id)], snapshot);
    assert.equal(n.store.rows.size, rows);
    assert.equal(w.store.counterOf('s1', 'lateAssignCount'), 1);
    assert.equal(w.store.counterOf('s1', 'changeDeclinedCount'), 1);
  });

  it('without notify deps the sweep still marks', async () => {
    const { w } = worlds();
    const b = await acceptedStudioBooking(w);
    w.clock.setTime(new Date(DEADLINE_MS));
    assert.deepEqual(await runStudioBookingSweeps(w.studioDeps), { overdue: 1, reminders: 0, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0 });
    assert.equal((await w.store.getBooking(b.id))?.assignOverdue, true);
  });

  it('a notice that fails is sent on the next run, exactly once overall', async () => {
    const { w, n } = worlds();
    const b = await acceptedStudioBooking(w);
    let failures = 1;
    const flaky: NotifyDeps = {
      ...n.deps,
      users: {
        get: async (uid) => {
          if (failures > 0) {
            failures -= 1;
            throw new Error('directory down');
          }
          return n.users.get(uid);
        },
      },
    };
    w.clock.setTime(new Date(DEADLINE_MS));
    n.clock.setTime(new Date(DEADLINE_MS));
    assert.deepEqual(await runStudioBookingSweeps(w.studioDeps, flaky), {
      overdue: 0, reminders: 0, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 1,
    });
    assert.equal((await w.store.getBooking(b.id))?.assignOverdue, false);
    assert.equal(w.store.counterOf('s1', 'lateAssignCount'), 0);
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS + 15 * 60 * 1000), {
      overdue: 1, reminders: 0, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0,
    });
    await sweepAt(w, n, DEADLINE_MS + 30 * 60 * 1000);
    assert.deepEqual(ids(n, 'c1'), [`n_assign_overdue_${b.id}_customer`]);
    assert.deepEqual(ids(n, 's1'), [`n_assign_overdue_${b.id}_studio`]);
    assert.equal(w.store.counterOf('s1', 'lateAssignCount'), 1);
  });

  it('a failed mark after a sent notice resends as a duplicate, not a second notice', async () => {
    const { w, n } = worlds();
    const b = await acceptedStudioBooking(w);
    const original = w.store.runTransaction.bind(w.store);
    let fail = true;
    w.store.runTransaction = async <T>(fn: (tx: StudioBookingTx) => Promise<T>): Promise<T> => {
      if (fail) {
        fail = false;
        throw new Error('store down');
      }
      return original(fn);
    };
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - HOUR), { overdue: 0, reminders: 0, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0 });
    assert.deepEqual(await sweepAt(w, n, DEADLINE_MS - HOUR), { overdue: 0, reminders: 1, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0 });
    assert.deepEqual(ids(n, 's1'), [`n_assign_reminder_${b.id}_26`]);
    assert.equal(n.store.rowsOf('s1')[0]?.count, 1);
  });

  it('assignSweepActionOf: nothing for assigned, overdue-marked or individual bookings', async () => {
    const { w } = worlds();
    const b = await acceptedStudioBooking(w);
    const at = new Date(DEADLINE_MS);
    assert.deepEqual(assignSweepActionOf(b, at), { kind: 'overdue', notify: true });
    assert.equal(assignSweepActionOf({ ...b, assignOverdue: true }, at), null);
    assert.equal(assignSweepActionOf({ ...b, assignStatus: 'assigned' }, at), null);
    assert.equal(assignSweepActionOf({ ...b, isStudio: undefined }, at), null);
    assert.deepEqual(assignSweepActionOf(b, new Date(Date.parse('2026-10-15T07:00:00.000Z'))), { kind: 'overdue', notify: false });
  });
});

describe('unassigned studio bookings at their start (#136 ruling)', () => {
  it('the sweep cancels with 100% back at the start, frees the load, counts lateAssignCount once', async () => {
    const { w, n } = worlds();
    const b = await acceptedStudioBooking(w);
    const paid = b.deposit;
    await sweepAt(w, n, DEADLINE_MS); // overdue marked before the start
    assert.equal(w.store.counterOf('s1', 'lateAssignCount'), 1);
    assert.deepEqual(await sweepAt(w, n, START_MS - 1), {
      overdue: 0, reminders: 0, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0,
    });
    const before = await w.store.getBooking(b.id);
    assert.deepEqual(await sweepAt(w, n, START_MS), {
      overdue: 0, reminders: 0, changesExpired: 0, cancelledAtStart: 1, notifyFailed: 0,
    });
    const after = await w.store.getBooking(b.id);
    assert.ok(before && after);
    assert.equal(after.status, 'cancelled');
    assert.deepEqual(after.cancel, {
      by: 'studio_fault', reason: 'assign_overdue', at: new Date(START_MS).toISOString(), refundPercent: 100,
    });
    assert.equal(after.depositRefunded, paid);
    assert.equal(w.store.counterOf('s1', 'lateAssignCount'), 1);
    assert.deepEqual(w.store.getStudioDayLoad('s1', after.day)?.unassignedIds ?? [], []);
    // both are told by the booking write (a system cancel); the bank-QR refund waits for the
    // customer's account (#141 S22.04: refundAccountNeeded), so refund_done comes once it is sent.
    assert.deepEqual(bookingNotices(before, after), [
      { to: 'customer', kind: 'cancelled' },
      { to: 'photographer', kind: 'cancelled' },
    ]);
    assert.equal(after.refundAccountNeeded, true);

    assert.deepEqual(await sweepAt(w, n, START_MS + HOUR), {
      overdue: 0, reminders: 0, changesExpired: 0, cancelledAtStart: 0, notifyFailed: 0,
    });
    assert.equal((await w.store.getBooking(b.id))?.version, after.version);
  });

  it('a booking the overdue sweep never marked gets the mark and the counter once, then the cancel', async () => {
    const { w } = worlds();
    const b = await acceptedStudioBooking(w);
    w.clock.setTime(new Date(START_MS + HOUR));
    assert.deepEqual(await runUnassignedStartSweep(w.studioDeps), { cancelled: 1, failed: 0 });
    const after = await w.store.getBooking(b.id);
    assert.equal(after?.status, 'cancelled');
    assert.equal(after?.assignOverdue, true);
    assert.equal(w.store.counterOf('s1', 'lateAssignCount'), 1);
    assert.deepEqual(await runUnassignedStartSweep(w.studioDeps), { cancelled: 0, failed: 0 });
    assert.equal(w.store.counterOf('s1', 'lateAssignCount'), 1);
  });

  it('a failed cancel is retried on the next run without counting the studio twice', async () => {
    const { w } = worlds();
    const b = await acceptedStudioBooking(w);
    const original = w.store.runTransaction.bind(w.store);
    let calls = 0;
    w.store.runTransaction = async <T>(fn: (tx: StudioBookingTx) => Promise<T>): Promise<T> => {
      calls += 1;
      if (calls === 2) throw new Error('store down'); // the cancel, after the mark
      return original(fn);
    };
    w.clock.setTime(new Date(START_MS));
    assert.deepEqual(await runUnassignedStartSweep(w.studioDeps), { cancelled: 0, failed: 1 });
    assert.equal((await w.store.getBooking(b.id))?.status, 'accepted');
    assert.equal(w.store.counterOf('s1', 'lateAssignCount'), 1);
    assert.deepEqual(await runUnassignedStartSweep(w.studioDeps), { cancelled: 1, failed: 0 });
    assert.equal(w.store.counterOf('s1', 'lateAssignCount'), 1);
    assert.equal((await w.store.getBooking(b.id))?.status, 'cancelled');
  });

  it('an assigned booking at its start is left alone and is marked shot later; an unassigned one never is', async () => {
    const { w, n } = worlds();
    const assigned = await acceptedStudioBooking(w);
    await assignBooking(w.studioDeps, 's1', { bookingId: assigned.id, assigneeId: 'm1' });
    const unassigned = await acceptedStudioBooking(w, { customerId: 'c2' });
    // Without the start sweep, the auto mark-shot (end + 24 h) must still skip the unassigned booking.
    w.clock.setTime(new Date(START_MS + 2 * HOUR + 24 * HOUR));
    const r = await runBookingSweeps(w.deps);
    assert.equal(r.autoShots, 1);
    assert.equal((await w.store.getBooking(assigned.id))?.status, 'shot');
    assert.equal((await w.store.getBooking(unassigned.id))?.status, 'accepted');
    assert.deepEqual(
      (await w.store.findAutoCompletions(new Date(START_MS + 2 * HOUR))).map((x) => x.id),
      [],
    );
    const swept = await sweepAt(w, n, START_MS + 26 * HOUR);
    assert.equal(swept.cancelledAtStart, 1);
    assert.equal((await w.store.getBooking(assigned.id))?.status, 'shot');
    assert.equal((await w.store.getBooking(unassigned.id))?.status, 'cancelled');
  });
});
