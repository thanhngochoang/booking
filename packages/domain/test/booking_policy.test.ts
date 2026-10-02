import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  computeDeposit,
  refundPercent,
  computeRefund,
  computeAcceptDeadline,
  computeDaySlots,
  addMinutesToTime,
  parseVnDateTime,
  formatVnDate,
  formatVnTime,
  DEPOSIT_PERCENT,
  DISPUTE_WINDOW_HOURS,
  ACCEPT_DEADLINE_HOURS,
  DRAFT_EXPIRY_MINUTES,
  AUTO_COMPLETE_DELAY_HOURS,
  ESCROW_RELEASE_DELAY_HOURS,
  BOOKING_CONTACT_RETENTION_DAYS,
  isDateString,
  isTimeString,
} from '../src/booking_policy.js';
import { ERROR_CODES } from '../src/errors.js';

describe('Task 1: Booking policy and math', () => {
  it('error codes include price_changed and not_eligible', () => {
    assert.ok(ERROR_CODES.includes('price_changed'));
    assert.ok(ERROR_CODES.includes('not_eligible'));
  });

  it('constants match specs', () => {
    assert.equal(DEPOSIT_PERCENT, 30);
    assert.equal(DISPUTE_WINDOW_HOURS, 24);
    assert.equal(ACCEPT_DEADLINE_HOURS, 24);
    assert.equal(DRAFT_EXPIRY_MINUTES, 30);
    assert.equal(AUTO_COMPLETE_DELAY_HOURS, 24);
    assert.equal(ESCROW_RELEASE_DELAY_HOURS, 24);
    assert.equal(BOOKING_CONTACT_RETENTION_DAYS, 30);
  });

  it('computeDeposit: deposit is floor(30%), remaining = price - deposit', () => {
    const testCases = [
      { price: 1_000_000, expectedDeposit: 300_000, expectedRemaining: 700_000 },
      { price: 1_250_000, expectedDeposit: 375_000, expectedRemaining: 875_000 },
      { price: 999_999, expectedDeposit: 299_999, expectedRemaining: 700_000 },
      { price: 1, expectedDeposit: 0, expectedRemaining: 1 },
      { price: 3, expectedDeposit: 0, expectedRemaining: 3 },
      { price: 4, expectedDeposit: 1, expectedRemaining: 3 },
    ];

    for (const tc of testCases) {
      const res = computeDeposit(tc.price);
      assert.equal(res.deposit, tc.expectedDeposit);
      assert.equal(res.remaining, tc.expectedRemaining);
      assert.equal(res.deposit + res.remaining, tc.price);
    }
  });

  it('refundPercent: follows policy table based on hours before start', () => {
    assert.equal(refundPercent(72), 100);
    assert.equal(refundPercent(48), 100);
    assert.equal(refundPercent(47.9), 50);
    assert.equal(refundPercent(24), 50);
    assert.equal(refundPercent(23.9), 0);
    assert.equal(refundPercent(0), 0);
    assert.equal(refundPercent(-1), 0);
  });

  it('computeRefund: floor(deposit * percent / 100)', () => {
    assert.equal(computeRefund(300_000, 100), 300_000);
    assert.equal(computeRefund(300_000, 50), 150_000);
    assert.equal(computeRefund(300_000, 0), 0);
    assert.equal(computeRefund(375_001, 50), 187_500);
  });

  it('computeAcceptDeadline: min(paidAt + 24h, startsAt)', () => {
    const paidAt = new Date('2026-10-10T10:00:00Z');
    const startFar = new Date('2026-10-15T10:00:00Z');
    const startSoon = new Date('2026-10-10T20:00:00Z');

    const deadlineFar = computeAcceptDeadline(paidAt, startFar);
    assert.equal(deadlineFar.toISOString(), new Date('2026-10-11T10:00:00Z').toISOString());

    const deadlineSoon = computeAcceptDeadline(paidAt, startSoon);
    assert.equal(deadlineSoon.toISOString(), startSoon.toISOString());
  });

  it('computeDaySlots: 30-min steps from 06:00 to 20:00 minus duration', () => {
    const slots120 = computeDaySlots(120);
    assert.equal(slots120[0], '06:00');
    assert.equal(slots120[1], '06:30');
    assert.equal(slots120[slots120.length - 1], '18:00');

    const slots60 = computeDaySlots(60);
    assert.equal(slots60[0], '06:00');
    assert.equal(slots60[slots60.length - 1], '19:00');

    const slots30 = computeDaySlots(30);
    assert.equal(slots30[0], '06:00');
    assert.equal(slots30[slots30.length - 1], '19:30');
  });

  it('addMinutesToTime: correctly calculates end time', () => {
    assert.equal(addMinutesToTime('06:00', 90), '07:30');
    assert.equal(addMinutesToTime('15:30', 120), '17:30');
    assert.equal(addMinutesToTime('18:00', 120), '20:00');
  });

  it('parseVnDateTime and format in UTC+7 (Asia/Ho_Chi_Minh)', () => {
    const d = parseVnDateTime('2026-10-12', '15:30');
    // UTC+7 -> 15:30 is 08:30 UTC
    assert.equal(d.toISOString(), '2026-10-12T08:30:00.000Z');

    assert.equal(formatVnDate(d), '2026-10-12');
    assert.equal(formatVnTime(d), '15:30');

    const dMidnight = parseVnDateTime('2026-01-01', '00:00');
    // UTC+7 -> 00:00 is 17:00 UTC previous day (2025-12-31)
    assert.equal(dMidnight.toISOString(), '2025-12-31T17:00:00.000Z');
    assert.equal(formatVnDate(dMidnight), '2026-01-01');
    assert.equal(formatVnTime(dMidnight), '00:00');
  });

  it('isDateString and isTimeString validators', () => {
    assert.equal(isDateString('2026-10-12'), true);
    assert.equal(isDateString('2026-1-1'), false);
    assert.equal(isDateString('invalid'), false);

    assert.equal(isTimeString('08:30'), true);
    assert.equal(isTimeString('8:30'), false);
    assert.equal(isTimeString('25:00'), false);
    assert.equal(isTimeString('12:60'), false);
  });
});
