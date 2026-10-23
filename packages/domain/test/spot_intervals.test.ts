import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  clashes,
  freeSlots,
  freeStartTimes,
  requiredGap,
  withInterval,
  withoutInterval,
  type SpotInterval,
} from '../src/spot_booking.js';

describe('spot_intervals', () => {
  it('requiredGap is 0 for two slots of the same offer and 15 otherwise', () => {
    assert.equal(requiredGap({ start: '06:00', end: '06:30', offerId: 'o1' }, { start: '06:30', end: '07:00', offerId: 'o1' }), 0);
    assert.equal(requiredGap({ start: '06:00', end: '06:30', offerId: 'o1' }, { start: '06:30', end: '07:00', offerId: 'o2' }), 15);
    assert.equal(requiredGap({ start: '06:00', end: '06:30' }, { start: '06:30', end: '07:00' }), 15);
    assert.equal(requiredGap({ start: '06:00', end: '06:30', offerId: 'o1' }, { start: '06:30', end: '07:00' }), 15);
  });

  it('clashes: 07:00–08:00 vs 08:10–09:00 clash (gap 10 < 15); vs 08:15–09:00 do not', () => {
    const taken: SpotInterval[] = [{ start: '07:00', end: '08:00' }];
    assert.equal(clashes({ start: '08:10', end: '09:00' }, taken), true);
    assert.equal(clashes({ start: '08:15', end: '09:00' }, taken), false);
    // Overlapping
    assert.equal(clashes({ start: '07:30', end: '08:30' }, taken), true);
    // Before with gap < 15
    assert.equal(clashes({ start: '06:00', end: '06:50' }, taken), true);
    // Before with gap >= 15
    assert.equal(clashes({ start: '06:00', end: '06:45' }, taken), false);
  });

  it('two same-offer slots back to back do not clash', () => {
    const taken: SpotInterval[] = [{ start: '06:00', end: '06:30', offerId: 'o1' }];
    assert.equal(clashes({ start: '06:30', end: '07:00', offerId: 'o1' }, taken), false);
  });

  it('freeStartTimes 06:00–11:00, 60 min, step 30, taken 07:00–08:00 → exactly ["08:30", "09:00", "09:30", "10:00"]', () => {
    const times = freeStartTimes(
      { start: '06:00', end: '11:00' },
      60,
      [{ start: '07:00', end: '08:00' }],
      30,
    );
    assert.deepEqual(times, ['08:30', '09:00', '09:30', '10:00']);
  });

  it('freeSlots marks a slot overlapping a package booking taken and a same-offer neighbour free', () => {
    const offer = { id: 'offer-1', slotMinutes: 30, gapMinutes: 0 };
    const slots = freeSlots(
      { start: '06:00', end: '09:00' },
      offer,
      [
        { start: '06:30', end: '07:30' }, // package booking
        { start: '08:00', end: '08:30', offerId: 'offer-1' }, // same-offer slot
      ],
    );
    // 06:00-06:30 ends 06:30, touches package at 06:30 (gap 0 < 15) -> free: false
    // 06:30-07:00 overlaps -> false
    // 07:00-07:30 overlaps -> false
    // 07:30-08:00 starts 07:30 (gap 0 < 15 from package) -> false
    // 08:00-08:30 taken -> false
    // 08:30-09:00 touches 08:30 end of slot with same offer -> free: true!
    const s0830 = slots.find((s) => s.start === '08:30');
    assert.equal(s0830?.free, true);
    const s0630 = slots.find((s) => s.start === '06:30');
    assert.equal(s0630?.free, false);
  });

  it('withInterval appends and keeps taken sorted by start', () => {
    const base = { scheduleId: 's1', spotId: 'sp1', providerId: 'p1', day: '2026-10-18' };
    const day1 = withInterval(null, base, { start: '09:00', end: '10:00' }, '2026-10-15T00:00:00Z');
    assert.deepEqual(day1.taken, [{ start: '09:00', end: '10:00' }]);

    const day2 = withInterval(day1, base, { start: '07:00', end: '08:00' }, '2026-10-15T01:00:00Z');
    assert.deepEqual(day2.taken, [
      { start: '07:00', end: '08:00' },
      { start: '09:00', end: '10:00' },
    ]);
  });

  it('withoutInterval removes only the exact {start, end}; an unknown interval leaves the day unchanged', () => {
    const day = {
      scheduleId: 's1',
      spotId: 'sp1',
      providerId: 'p1',
      day: '2026-10-18',
      taken: [
        { start: '07:00', end: '08:00' },
        { start: '09:00', end: '10:00' },
      ],
      updatedAt: '2026-10-15T00:00:00Z',
    };
    const unchanged = withoutInterval(day, { start: '10:00', end: '11:00' }, '2026-10-15T01:00:00Z');
    assert.deepEqual(unchanged.taken, day.taken);

    const changed = withoutInterval(day, { start: '07:00', end: '08:00' }, '2026-10-15T02:00:00Z');
    assert.deepEqual(changed.taken, [{ start: '09:00', end: '10:00' }]);
  });

  it('SpotInterval carries no booking or customer field', () => {
    const iv: SpotInterval = {
      start: '07:00',
      end: '08:00',
      offerId: 'o1',
    };
    assert.deepEqual(Object.keys(iv).sort(), ['end', 'offerId', 'start']);
  });
});
