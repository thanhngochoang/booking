import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { roleOf, decideTransition } from '../src/booking_machine.js';
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
      const res = decideTransition(booking, 'complete', { id: 'photog_01', role: 'photographer' }, now);
      assert.equal(res.nextStatus, 'completed');
    });

    it('photographer cannot complete before end time (not_eligible)', () => {
      const now = new Date('2026-10-15T08:59:59.000Z');
      const booking = { ...baseBooking, status: 'upcoming' as const };
      assert.throws(
        () => decideTransition(booking, 'complete', { id: 'photog_01', role: 'photographer' }, now),
        (err: unknown) => err instanceof DomainError && err.code === 'not_eligible',
      );
    });

    it('system can auto-complete 24h after end time', () => {
      // end + 24h: 2026-10-16 09:00 UTC
      const now = new Date('2026-10-16T09:00:00.000Z');
      const booking = { ...baseBooking, status: 'upcoming' as const };
      const res = decideTransition(booking, 'complete', { role: 'system' }, now);
      assert.equal(res.nextStatus, 'completed');
    });

    it('customer can review a completed booking', () => {
      const now = new Date('2026-10-16T10:00:00.000Z');
      const booking = { ...baseBooking, status: 'completed' as const };
      const res = decideTransition(booking, 'review', { id: 'cust_01', role: 'customer' }, now);
      assert.equal(res.nextStatus, 'reviewed');
    });
  });
});
