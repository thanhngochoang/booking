import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { roleOf, decideTransition, type TransitionAction, type TransitionActor } from '../src/booking_machine.js';
import type { Booking } from '../src/booking.js';
import { DomainError } from '../src/errors.js';

describe('Task 2: Booking state machine & transitions', () => {
  const baseBooking: Booking = {
    id: 'b_01',
    customerId: 'cust_01',
    photographerId: 'photog_01',
    serviceId: 'srv_01',
    serviceSnapshot: { name: 'Chân dung', price: 1_000_000, durationMinutes: 120 },
    day: '2026-10-15',
    start: '14:00',
    end: '16:00',
    place: { name: 'Hồ Gươm' },
    status: 'requested',
    deposit: 300_000,
    remaining: 700_000,
    acceptDeadline: '2026-10-11T10:00:00.000Z',
    version: 1,
    createdAt: '2026-10-10T10:00:00.000Z',
    updatedAt: '2026-10-10T10:00:00.000Z',
  };

  it('roleOf correctly identifies role', () => {
    assert.equal(roleOf('cust_01', baseBooking), 'customer');
    assert.equal(roleOf('photog_01', baseBooking), 'photographer');
    assert.equal(roleOf('other_user', baseBooking), null);
    assert.equal(roleOf(undefined, baseBooking), null);
  });

  describe('accept', () => {
    it('photographer can accept requested booking before deadline', () => {
      const now = new Date('2026-10-10T15:00:00.000Z');
      const res = decideTransition(baseBooking, 'accept', { id: 'photog_01', role: 'photographer' }, now);
      assert.equal(res.nextStatus, 'accepted');
      assert.equal(res.refundPercent, 0);
    });

    it('accepting within 24h of start moves directly to upcoming', () => {
      // starts at 2026-10-15 14:00 VN = 07:00 UTC
      // now is 2026-10-14 10:00 UTC (21 hours before start)
      const now = new Date('2026-10-14T10:00:00.000Z');
      const bookingSoon = {
        ...baseBooking,
        acceptDeadline: '2026-10-14T12:00:00.000Z',
      };
      const res = decideTransition(bookingSoon, 'accept', { id: 'photog_01', role: 'photographer' }, now);
      assert.equal(res.nextStatus, 'upcoming');
    });

    it('refuses accept by customer or stranger (permission_denied)', () => {
      const now = new Date('2026-10-10T15:00:00.000Z');
      assert.throws(
        () => decideTransition(baseBooking, 'accept', { id: 'cust_01', role: 'customer' }, now),
        (err: unknown) => err instanceof DomainError && err.code === 'permission_denied',
      );
    });

    it('refuses accept if deadline passed', () => {
      const now = new Date('2026-10-11T10:00:01.000Z');
      assert.throws(
        () => decideTransition(baseBooking, 'accept', { id: 'photog_01', role: 'photographer' }, now),
        (err: unknown) => err instanceof DomainError && err.code === 'deadline_passed',
      );
    });
  });

  describe('decline', () => {
    it('photographer can decline requested booking with 100% refund', () => {
      const now = new Date('2026-10-10T15:00:00.000Z');
      const res = decideTransition(
        baseBooking,
        'decline',
        { id: 'photog_01', role: 'photographer' },
        now,
        'Bận việc gia đình',
      );
      assert.equal(res.nextStatus, 'declined');
      assert.equal(res.refundPercent, 100);
      assert.deepEqual(res.cancelRecord, {
        by: 'photographer',
        reason: 'Bận việc gia đình',
        at: now.toISOString(),
        refundPercent: 100,
      });
    });

    it('refuses decline by customer', () => {
      const now = new Date('2026-10-10T15:00:00.000Z');
      assert.throws(
        () => decideTransition(baseBooking, 'decline', { id: 'cust_01', role: 'customer' }, now),
        (err: unknown) => err instanceof DomainError && err.code === 'permission_denied',
      );
    });
  });

  describe('expire', () => {
    it('system can expire requested booking past deadline with 100% refund', () => {
      const now = new Date('2026-10-11T10:00:00.000Z');
      const res = decideTransition(baseBooking, 'expire', { role: 'system' }, now);
      assert.equal(res.nextStatus, 'expired');
      assert.equal(res.refundPercent, 100);
    });

    it('refuses expire before deadline', () => {
      const now = new Date('2026-10-11T09:59:59.000Z');
      assert.throws(
        () => decideTransition(baseBooking, 'expire', { role: 'system' }, now),
        (err: unknown) => err instanceof DomainError && err.code === 'conflict',
      );
    });
  });

  describe('cancel', () => {
    it('customer cancel follows policy: >=48h gives 100%', () => {
      // start: 2026-10-15 14:00 VN (07:00 UTC)
      // now: 2026-10-13 06:00 UTC (49 hours before start)
      const now = new Date('2026-10-13T06:00:00.000Z');
      const booking = { ...baseBooking, status: 'accepted' as const };
      const res = decideTransition(booking, 'cancel', { id: 'cust_01', role: 'customer' }, now, 'Đổi kế hoạch');
      assert.equal(res.nextStatus, 'cancelled');
      assert.equal(res.refundPercent, 100);
    });

    it('customer cancel follows policy: 24-48h gives 50%', () => {
      // now: 2026-10-14 00:00 UTC (31 hours before start)
      const now = new Date('2026-10-14T00:00:00.000Z');
      const booking = { ...baseBooking, status: 'accepted' as const };
      const res = decideTransition(booking, 'cancel', { id: 'cust_01', role: 'customer' }, now, 'Bận đột xuất');
      assert.equal(res.nextStatus, 'cancelled');
      assert.equal(res.refundPercent, 50);
    });

    it('customer cancel follows policy: <24h gives 0%', () => {
      // now: 2026-10-15 00:00 UTC (7 hours before start)
      const now = new Date('2026-10-15T00:00:00.000Z');
      const booking = { ...baseBooking, status: 'upcoming' as const };
      const res = decideTransition(booking, 'cancel', { id: 'cust_01', role: 'customer' }, now, 'Đau chân');
      assert.equal(res.nextStatus, 'cancelled');
      assert.equal(res.refundPercent, 0);
    });

    it('photographer cancel always gives 100% refund', () => {
      // now: 2026-10-15 00:00 UTC (7 hours before start)
      const now = new Date('2026-10-15T00:00:00.000Z');
      const booking = { ...baseBooking, status: 'upcoming' as const };
      const res = decideTransition(booking, 'cancel', { id: 'photog_01', role: 'photographer' }, now, 'Hỏng máy');
      assert.equal(res.nextStatus, 'cancelled');
      assert.equal(res.refundPercent, 100);
    });

    it('cannot cancel at or after start time (not_eligible)', () => {
      // start: 2026-10-15 07:00 UTC
      const now = new Date('2026-10-15T07:00:00.000Z');
      const booking = { ...baseBooking, status: 'upcoming' as const };
      assert.throws(
        () => decideTransition(booking, 'cancel', { id: 'cust_01', role: 'customer' }, now),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
      );
    });
  });

  describe('complete and review', () => {
    it('photographer can complete after end time', () => {
      // end: 2026-10-15 16:00 VN (09:00 UTC)
      const now = new Date('2026-10-15T09:00:00.000Z');
      const booking = { ...baseBooking, status: 'upcoming' as const };
      const res = decideTransition(booking, 'mark_shot', { id: 'photog_01', role: 'photographer' }, now);
      assert.equal(res.nextStatus, 'shot');
    });

    it('photographer mark_shot after the end moves upcoming to shot', () => {
      const now = new Date('2026-10-15T09:00:00.000Z');
      const booking = { ...baseBooking, status: 'upcoming' as const };
      const res = decideTransition(booking, 'mark_shot', { id: 'photog_01', role: 'photographer' }, now);
      assert.equal(res.nextStatus, 'shot');
    });

    it('mark_shot before the end is not_eligible', () => {
      const now = new Date('2026-10-15T08:59:59.000Z');
      const booking = { ...baseBooking, status: 'upcoming' as const };
      assert.throws(
        () => decideTransition(booking, 'mark_shot', { id: 'photog_01', role: 'photographer' }, now),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
      );
    });

    it('complete is an alias of mark_shot', () => {
      const now = new Date('2026-10-15T09:00:00.000Z');
      const booking = { ...baseBooking, status: 'upcoming' as const };
      const res = decideTransition(booking, 'complete', { id: 'photog_01', role: 'photographer' }, now);
      assert.equal(res.nextStatus, 'shot');
    });

    it('system mark_shot of a shooting booking needs end + 24 h (S30)', () => {
      // end + 24h: 2026-10-16 09:00 UTC
      const nowBefore = new Date('2026-10-16T08:59:00.000Z');
      const booking = { ...baseBooking, status: 'shooting' as const, checkedInAt: '2026-10-15T07:00:00.000Z' };
      assert.throws(
        () => decideTransition(booking, 'mark_shot', { role: 'system' }, nowBefore),
        (err: unknown) => err instanceof DomainError && err.code === 'conflict',
      );

      const now = new Date('2026-10-16T09:00:00.000Z');
      const res = decideTransition(booking, 'mark_shot', { role: 'system' }, now);
      assert.equal(res.nextStatus, 'shot');
      assert.equal(res.shotAt, undefined);
    });

    it('system mark_shot of an upcoming booking only after the shoot question, dated at its end (S30)', () => {
      const now = new Date('2026-10-19T09:00:00.000Z');
      const upcoming = { ...baseBooking, status: 'upcoming' as const };
      assert.throws(
        () => decideTransition(upcoming, 'mark_shot', { role: 'system' }, now),
        (err: unknown) => err instanceof DomainError && err.code === 'conflict',
      );
      const asked = { ...upcoming, shootQuestionAt: '2026-10-16T09:00:00.000Z', shootQuestionUntil: '2026-10-18T09:00:00.000Z' };
      assert.deepEqual(decideTransition(asked, 'mark_shot', { role: 'system' }, now), {
        nextStatus: 'shot', refundPercent: 0, shotAt: '2026-10-15T09:00:00.000Z',
      });
      assert.throws(
        () => decideTransition({ ...asked, shootDeniedAt: '2026-10-16T10:00:00.000Z' }, 'mark_shot', { role: 'system' }, now),
        (err: unknown) => err instanceof DomainError && err.code === 'conflict',
      );
    });

    it('scan: the photographer moves upcoming to shooting inside the window (S30)', () => {
      const booking = { ...baseBooking, status: 'upcoming' as const };
      const p = { id: baseBooking.photographerId, role: 'photographer' as const };
      // start 2026-10-15 14:00 VN: opens 12:00 VN (05:00Z), closes end 16:00 + 2 h (11:00Z)
      assert.deepEqual(decideTransition(booking, 'scan', p, new Date('2026-10-15T05:00:00.000Z')), { nextStatus: 'shooting', refundPercent: 0 });
      assert.deepEqual(decideTransition(booking, 'scan', p, new Date('2026-10-15T11:00:00.000Z')), { nextStatus: 'shooting', refundPercent: 0 });
      assert.throws(() => decideTransition(booking, 'scan', p, new Date('2026-10-15T04:59:00.000Z')),
        (err: unknown) => err instanceof DomainError && err.code === 'too_early');
      assert.throws(() => decideTransition(booking, 'scan', p, new Date('2026-10-15T11:01:00.000Z')),
        (err: unknown) => err instanceof DomainError && err.code === 'wrong_day');
      assert.throws(() => decideTransition(booking, 'scan', { id: 'cust_01', role: 'customer' }, new Date('2026-10-15T06:00:00.000Z')),
        (err: unknown) => err instanceof DomainError && (err.code === 'permission_denied'));
      assert.throws(() => decideTransition({ ...booking, status: 'accepted' }, 'scan', p, new Date('2026-10-15T06:00:00.000Z')),
        (err: unknown) => err instanceof DomainError && err.code === 'conflict');
    });

    it('finish moves approved to completed after checkUntil', () => {
      const checkUntil = '2026-10-18T10:00:00.000Z';
      const now = new Date('2026-10-18T10:00:01.000Z');
      const booking = { ...baseBooking, status: 'approved' as const, checkUntil };
      const res = decideTransition(booking, 'finish', { role: 'system' }, now);
      assert.equal(res.nextStatus, 'completed');
    });

    it('finish before checkUntil is conflict', () => {
      const checkUntil = '2026-10-18T10:00:00.000Z';
      const now = new Date('2026-10-18T09:59:59.000Z');
      const booking = { ...baseBooking, status: 'approved' as const, checkUntil };
      assert.throws(
        () => decideTransition(booking, 'finish', { role: 'system' }, now),
        (err: unknown) => err instanceof DomainError && err.code === 'conflict',
      );
    });

    it('finish on a disputed escrow is not_eligible', () => {
      const checkUntil = '2026-10-18T10:00:00.000Z';
      const now = new Date('2026-10-18T10:01:00.000Z');
      const booking = { ...baseBooking, status: 'approved' as const, checkUntil, escrowStatus: 'disputed' as const };
      assert.throws(
        () => decideTransition(booking, 'finish', { role: 'system' }, now),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
      );
    });

    it('customer cannot finish', () => {
      const checkUntil = '2026-10-18T10:00:00.000Z';
      const now = new Date('2026-10-18T10:01:00.000Z');
      const booking = { ...baseBooking, status: 'approved' as const, checkUntil };
      assert.throws(
        () => decideTransition(booking, 'finish', { id: 'cust_01', role: 'customer' }, now),
        (err: unknown) => err instanceof DomainError && err.code === 'permission_denied',
      );
    });

    it('the retired review action is refused (reviews go through submitReview)', () => {
      const now = new Date('2026-10-16T10:00:00.000Z');
      const booking = { ...baseBooking, status: 'completed' as const };
      assert.throws(
        () =>
          decideTransition(
            booking,
            'review' as unknown as TransitionAction,
            { id: 'cust_01', role: 'customer' },
            now,
          ),
        (err: unknown) => err instanceof DomainError && err.code === 'invalid_argument',
      );
    });
  });

  describe('studio bookings (#136)', () => {
    const studio: Booking = {
      ...baseBooking,
      isStudio: true,
      assigneeId: null,
      assigneeKind: null,
      assignStatus: 'unassigned',
      assignDeadline: '2026-10-14T07:00:00.000Z',
      assignOverdue: false,
      assignments: [],
      changeRequest: null,
      studioFault: null,
    };
    const inside24h = new Date('2026-10-14T08:00:00.000Z');
    const customer = { id: 'cust_01', role: 'customer' as const };

    it('upcoming refuses a studio booking without assignee', () => {
      assert.throws(
        () => decideTransition({ ...studio, status: 'accepted' }, 'upcoming', { role: 'system' }, inside24h),
        (err: unknown) => err instanceof DomainError && err.code === 'conflict',
      );
      const assigned = { ...studio, status: 'accepted' as const, assigneeId: 'm1', assignStatus: 'assigned' as const };
      assert.equal(decideTransition(assigned, 'upcoming', { role: 'system' }, inside24h).nextStatus, 'upcoming');
    });

    it('accept inside 24 h keeps an unassigned studio booking accepted', () => {
      const requested = { ...studio, acceptDeadline: '2026-10-15T00:00:00.000Z' };
      const actor = { id: 'photog_01', role: 'photographer' as const };
      assert.equal(decideTransition(requested, 'accept', actor, inside24h).nextStatus, 'accepted');
      const assigned = { ...requested, assigneeId: 'm1', assignStatus: 'assigned' as const };
      assert.equal(decideTransition(assigned, 'accept', actor, inside24h).nextStatus, 'upcoming');
    });

    it('cancel_studio_fault: customer only, 100% with the fault kind as reason', () => {
      const overdue = { ...studio, status: 'accepted' as const };
      const d = decideTransition(overdue, 'cancel_studio_fault', customer, new Date('2026-10-14T07:00:00.000Z'));
      assert.deepEqual(d, {
        nextStatus: 'cancelled',
        refundPercent: 100,
        cancelRecord: { by: 'studio_fault', reason: 'assign_overdue', at: '2026-10-14T07:00:00.000Z', refundPercent: 100 },
      });
      assert.throws(
        () => decideTransition(overdue, 'cancel_studio_fault', { id: 'photog_01', role: 'photographer' }, inside24h),
        (err: unknown) => err instanceof DomainError && err.code === 'permission_denied',
      );
      assert.throws(
        () => decideTransition(overdue, 'cancel_studio_fault', customer, new Date('2026-10-13T07:00:00.000Z')),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
      );
      assert.throws(
        () => decideTransition({ ...overdue, status: 'cancelled' }, 'cancel_studio_fault', customer, inside24h),
        (err: unknown) => err instanceof DomainError && err.code === 'conflict',
      );
      assert.throws(
        () => decideTransition({ ...baseBooking, status: 'accepted' }, 'cancel_studio_fault', customer, inside24h),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
      );
    });

    it('mark_shot and complete refuse a studio booking without assignee, for every role', () => {
      // start 2026-10-15 14:00 VN, end 16:00 VN = 09:00Z; the clock may mark shot from 2026-10-16T09:00Z
      const afterAuto = new Date('2026-10-16T10:00:00.000Z');
      const unassigned = { ...studio, status: 'accepted' as const, assignOverdue: true };
      for (const action of ['mark_shot', 'complete'] as const) {
        for (const actor of [{ id: 'photog_01', role: 'photographer' as const }, { role: 'system' as const }]) {
          assert.throws(
            () => decideTransition(unassigned, action, actor, afterAuto),
            (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
          );
        }
      }
      const assigned = { ...unassigned, assigneeId: 'm1', assignStatus: 'assigned' as const };
      assert.equal(decideTransition({ ...assigned, status: 'shooting' }, 'mark_shot', { role: 'system' }, afterAuto).nextStatus, 'shot');
      assert.equal(
        decideTransition({ ...assigned, status: 'upcoming' }, 'complete', { id: 'photog_01', role: 'photographer' }, afterAuto)
          .nextStatus,
        'shot',
      );
    });

    it('cancel_unassigned_at_start: system only, at or after the start, unassigned only, 100%', () => {
      const start = new Date('2026-10-15T07:00:00.000Z'); // 14:00 VN
      const unassigned = { ...studio, status: 'accepted' as const };
      assert.deepEqual(decideTransition(unassigned, 'cancel_unassigned_at_start', { role: 'system' }, start), {
        nextStatus: 'cancelled',
        refundPercent: 100,
        cancelRecord: { by: 'studio_fault', reason: 'assign_overdue', at: start.toISOString(), refundPercent: 100 },
      });
      assert.equal(
        decideTransition({ ...studio }, 'cancel_unassigned_at_start', { role: 'system' }, start).nextStatus,
        'cancelled',
      );
      const refused: [Booking, TransitionActor, Date, string][] = [
        [unassigned, { role: 'system' }, new Date(start.getTime() - 1), 'not_eligible'],
        [{ ...unassigned, assigneeId: 'm1', assignStatus: 'assigned' }, { role: 'system' }, start, 'not_eligible'],
        [{ ...baseBooking, status: 'accepted' }, { role: 'system' }, start, 'not_eligible'],
        [{ ...unassigned, status: 'cancelled' }, { role: 'system' }, start, 'conflict'],
        [unassigned, customer, start, 'permission_denied'],
        [unassigned, { id: 'photog_01', role: 'photographer' }, start, 'permission_denied'],
      ];
      for (const [b, actor, at, code] of refused) {
        assert.throws(
          () => decideTransition(b, 'cancel_unassigned_at_start', actor, at),
          (err: unknown) => err instanceof DomainError && err.code === code,
          code,
        );
      }
    });
  });
});
