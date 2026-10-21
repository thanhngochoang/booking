import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  dayConflicts,
  priceFromOf,
  scheduleEditBlocks,
  validateScheduleInput,
} from '../src/spot_schedule.js';
import { isDomainError } from '../src/errors.js';
import type { AvailabilityDayRecord, ServiceRecord } from '../src/booking_ports.js';
import type { SpotDay } from '../src/spot_booking.js';

describe('spot_schedule', () => {
  const today = '2026-10-15';
  const valid = {
    spotId: '01HR0000000000000000000001',
    days: ['2026-10-17', '2026-10-18'],
    window: { start: '06:00', end: '11:00' },
    serviceIds: [],
  };

  describe('validateScheduleInput', () => {
    it('validateScheduleInput sorts and dedupes days', () => {
      const res = validateScheduleInput(
        { ...valid, days: ['2026-10-18', '2026-10-17', '2026-10-18'] },
        today,
      );
      assert.deepEqual(res.days, ['2026-10-17', '2026-10-18']);
    });

    it('a day before today or after today + 60 → field days', () => {
      assert.throws(
        () => validateScheduleInput({ ...valid, days: ['2026-10-14'] }, today),
        (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'days',
      );
      // today + 61 days: 2026-12-16
      assert.throws(
        () => validateScheduleInput({ ...valid, days: ['2026-12-16'] }, today),
        (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'days',
      );
    });

    it('41 days → field days', () => {
      const days = Array.from({ length: 41 }, (_, i) => {
        const d = new Date('2026-10-16T00:00:00Z');
        d.setUTCDate(d.getUTCDate() + i);
        return d.toISOString().slice(0, 10);
      });
      assert.throws(
        () => validateScheduleInput({ ...valid, days }, today),
        (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'days',
      );
    });

    it('no day → field days', () => {
      assert.throws(
        () => validateScheduleInput({ ...valid, days: [] }, today),
        (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'days',
      );
    });

    it('window 04:45–09:00 or 17:00–21:15 → field window', () => {
      assert.throws(
        () => validateScheduleInput({ ...valid, window: { start: '04:45', end: '09:00' } }, today),
        (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'window',
      );
      assert.throws(
        () => validateScheduleInput({ ...valid, window: { start: '17:00', end: '21:15' } }, today),
        (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'window',
      );
    });

    it('window of 45 minutes or 12 h 15 → field window', () => {
      assert.throws(
        () => validateScheduleInput({ ...valid, window: { start: '06:00', end: '06:45' } }, today),
        (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'window',
      );
      assert.throws(
        () => validateScheduleInput({ ...valid, window: { start: '06:00', end: '18:15' } }, today),
        (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'window',
      );
    });

    it('window off the 15-minute grid (06:10) → field window', () => {
      assert.throws(
        () => validateScheduleInput({ ...valid, window: { start: '06:10', end: '09:00' } }, today),
        (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'window',
      );
    });

    it('assigneeId when present must be an id', () => {
      assert.throws(
        () => validateScheduleInput({ ...valid, assigneeId: 'invalid-id-!!' }, today),
        (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'assigneeId',
      );
      const res = validateScheduleInput({ ...valid, assigneeId: '01HR0000000000000000000002' }, today);
      assert.equal(res.assigneeId, '01HR0000000000000000000002');
    });
  });

  describe('dayConflicts', () => {
    it('dayConflicts: booked/pending/off/full/spot of another schedule are conflicts with their reason; no record and spot of the same schedule are free', () => {
      const records = new Map<string, AvailabilityDayRecord | null>([
        ['2026-10-16', null],
        ['2026-10-17', { state: 'booked', bookingId: 'b1' }],
        ['2026-10-18', { state: 'pending', bookingId: 'b2' }],
        ['2026-10-19', { state: 'off' }],
        ['2026-10-20', { state: 'spot', scheduleId: 'sched-1', spotId: 's1' }],
        ['2026-10-21', { state: 'spot', scheduleId: 'other-sched', spotId: 's1' }],
        ['2026-10-22', { state: 'full' }],
      ]);

      const days = [
        '2026-10-16',
        '2026-10-17',
        '2026-10-18',
        '2026-10-19',
        '2026-10-20',
        '2026-10-21',
        '2026-10-22',
      ];
      const conflicts = dayConflicts(days, records, 'sched-1');

      assert.deepEqual(conflicts, [
        { day: '2026-10-17', reason: 'booked' },
        { day: '2026-10-18', reason: 'pending' },
        { day: '2026-10-19', reason: 'off' },
        { day: '2026-10-21', reason: 'spot' },
        { day: '2026-10-22', reason: 'full' },
      ]);
    });
  });

  describe('priceFromOf', () => {
    const services: ServiceRecord[] = [
      { id: 'srv-1', photographerId: 'p1', name: 'Gói 1', price: 1_000_000, durationMinutes: 60, active: true },
      { id: 'srv-2', photographerId: 'p1', name: 'Gói 2', price: 500_000, durationMinutes: 60, active: true },
      { id: 'srv-inactive', photographerId: 'p1', name: 'Gói cũ', price: 300_000, durationMinutes: 60, active: false },
    ];

    it('[] → min of all active', () => {
      assert.equal(priceFromOf(services, []), 500_000);
    });

    it('listed ids → min of those', () => {
      assert.equal(priceFromOf(services, ['srv-1']), 1_000_000);
    });

    it('an unknown id → invalid_argument serviceIds', () => {
      assert.throws(
        () => priceFromOf(services, ['unknown']),
        (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'serviceIds',
      );
    });

    it('no active package → invalid_argument serviceIds', () => {
      assert.throws(
        () => priceFromOf([], []),
        (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'serviceIds',
      );
    });
  });

  describe('scheduleEditBlocks', () => {
    it('a removed day with 2 intervals → {day, count: 2}; an interval outside the new window → blocked; inside → []', () => {
      const spotDays = new Map<string, SpotDay | null>([
        [
          '2026-10-17',
          {
            scheduleId: 's1',
            spotId: 'sp1',
            providerId: 'p1',
            day: '2026-10-17',
            taken: [
              { start: '07:00', end: '08:00' },
              { start: '08:30', end: '09:30' },
            ],
            updatedAt: '2026-10-15T00:00:00Z',
          },
        ],
        [
          '2026-10-18',
          {
            scheduleId: 's1',
            spotId: 'sp1',
            providerId: 'p1',
            day: '2026-10-18',
            taken: [{ start: '06:00', end: '07:00' }],
            updatedAt: '2026-10-15T00:00:00Z',
          },
        ],
      ]);

      // Removed day 2026-10-17 with 2 intervals
      const removedBlocks = scheduleEditBlocks(['2026-10-17'], { start: '06:00', end: '11:00' }, spotDays);
      assert.deepEqual(removedBlocks, [{ day: '2026-10-17', count: 2 }]);

      // Window narrowed to 07:00-11:00, 2026-10-18 has 06:00-07:00 which falls outside!
      const narrowedBlocks = scheduleEditBlocks([], { start: '07:00', end: '11:00' }, spotDays);
      assert.deepEqual(narrowedBlocks, [{ day: '2026-10-18', count: 1 }]);

      // Window 05:00-11:00 covers 2026-10-18 completely
      const d18 = spotDays.get('2026-10-18') ?? null;
      const insideBlocks = scheduleEditBlocks([], { start: '05:00', end: '11:00' }, new Map([['2026-10-18', d18]]));
      assert.deepEqual(insideBlocks, []);
    });
  });
});
