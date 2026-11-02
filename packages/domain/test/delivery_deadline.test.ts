import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  DEFAULT_DELIVERY_DAYS,
  DELIVERY_DAYS_MAX,
  DELIVERY_DAYS_MIN,
  clampDeliveryDays,
  deliveryDueAt,
  isDeliveryLate,
} from '../src/delivery_deadline.js';
import type { BookingStatus } from '../src/booking.js';

describe('delivery_deadline', () => {
  it('clampDeliveryDays(undefined | null | 0 | -3 | 1.5 | "x") is 7', () => {
    assert.equal(DEFAULT_DELIVERY_DAYS, 7);
    assert.equal(DELIVERY_DAYS_MIN, 1);
    assert.equal(DELIVERY_DAYS_MAX, 90);
    for (const v of [undefined, null, 0, -3, 1.5, 'x', NaN, Infinity]) {
      assert.equal(clampDeliveryDays(v), 7, `expected 7 for ${String(v)}`);
    }
  });

  it('clampDeliveryDays(1) is 1, (90) is 90, (91) is 90', () => {
    assert.equal(clampDeliveryDays(1), 1);
    assert.equal(clampDeliveryDays(5), 5);
    assert.equal(clampDeliveryDays(90), 90);
    assert.equal(clampDeliveryDays(91), 90);
    assert.equal(clampDeliveryDays(120), 90);
  });

  it('deliveryDueAt without shotAt is null', () => {
    assert.equal(deliveryDueAt({}), null);
    assert.equal(deliveryDueAt({ deliveryDays: 5 }), null);
  });

  it('deliveryDueAt with shotAt 2026-10-10T10:00Z and 5 days is 2026-10-15T10:00Z', () => {
    const due = deliveryDueAt({ shotAt: '2026-10-10T10:00:00.000Z', deliveryDays: 5 });
    assert.equal(due?.toISOString(), '2026-10-15T10:00:00.000Z');
  });

  it('isDeliveryLate is false one second before dueAt and true one second after', () => {
    const b = {
      status: 'shot' as const,
      shotAt: '2026-10-10T10:00:00.000Z',
      deliveryDays: 5,
    };
    const dueMs = new Date('2026-10-15T10:00:00.000Z').getTime();
    assert.equal(isDeliveryLate(b, new Date(dueMs - 1000)), false);
    assert.equal(isDeliveryLate(b, new Date(dueMs)), false);
    assert.equal(isDeliveryLate(b, new Date(dueMs + 1000)), true);
  });

  it('isDeliveryLate is false on delivered, revision_requested, approved, completed even past dueAt', () => {
    const pastDue = new Date('2026-10-20T10:00:00.000Z');
    const statuses: BookingStatus[] = [
      'delivered',
      'revision_requested',
      'approved',
      'completed',
      'upcoming',
      'accepted',
      'cancelled',
    ];
    for (const status of statuses) {
      assert.equal(
        isDeliveryLate({ status, shotAt: '2026-10-10T10:00:00.000Z', deliveryDays: 5 }, pastDue),
        false,
        status,
      );
    }
  });

  it('isDeliveryLate without deliveryDays uses 7 days', () => {
    const b = {
      status: 'shot' as const,
      shotAt: '2026-10-10T10:00:00.000Z',
    };
    assert.equal(isDeliveryLate(b, new Date('2026-10-17T10:00:00.000Z')), false);
    assert.equal(isDeliveryLate(b, new Date('2026-10-17T10:00:01.000Z')), true);
  });
});
