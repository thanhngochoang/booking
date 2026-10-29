import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError, type ErrorCode } from '../src/errors.js';
import {
  ENTRY_REFUND_CUTOFF_HOURS,
  assertDailyCapacity,
  entryRefundPercent,
  entryReleaseAt,
  isOpenDay,
  openDays,
  priceItems,
  validateEntryEvent,
  type EntryDay,
  type TicketType,
} from '../src/entry_tickets.js';

const TODAY = '2026-10-18'; // a Sunday
const HOUR = 3_600_000;

const fails = (c: ErrorCode, field?: string) => (e: unknown) =>
  e instanceof DomainError && e.code === c && (field === undefined || e.field === field);

const raw = (over: Record<string, unknown> = {}): Record<string, unknown> => ({
  spotId: 's1',
  startAt: TODAY,
  endAt: '2026-11-30',
  closedWeekdays: [1],
  closedDays: ['2026-10-25'],
  openHours: { start: '08:00', end: '17:00' },
  ticketTypes: [
    { id: 'adult', name: 'Người lớn', price: 70_000 },
    { id: 'child', name: 'Trẻ em', price: 40_000 },
  ],
  dailyCapacity: 10,
  ...over,
});

const type = (over: Partial<TicketType> = {}) => ({ id: 'adult', name: 'Người lớn', price: 70_000, ...over });

describe('validateEntryEvent', () => {
  test('a complete request gives the entry fields', () => {
    const f = validateEntryEvent(raw(), TODAY);
    assert.equal(f.spotId, 's1');
    assert.deepEqual([f.startAt, f.endAt], [TODAY, '2026-11-30']);
    assert.deepEqual(f.openHours, { start: '08:00', end: '17:00' });
    assert.deepEqual(f.ticketTypes, [
      { id: 'adult', name: 'Người lớn', price: 70_000, hidden: false },
      { id: 'child', name: 'Trẻ em', price: 40_000, hidden: false },
    ]);
    assert.deepEqual([f.closedWeekdays, f.closedDays, f.dailyCapacity], [[1], ['2026-10-25'], 10]);
  });

  test('range of 181 days → field endAt (180 is fine; an end before the start too)', () => {
    assert.throws(() => validateEntryEvent(raw({ endAt: '2027-04-16' }), TODAY), fails('invalid_argument', 'endAt'));
    assert.equal(validateEntryEvent(raw({ endAt: '2027-04-15' }), TODAY).endAt, '2027-04-15');
    assert.throws(() => validateEntryEvent(raw({ endAt: '2026-10-17' }), TODAY), fails('invalid_argument', 'endAt'));
  });

  test('start yesterday → startAt (an unchanged past start of a published event is kept)', () => {
    assert.throws(() => validateEntryEvent(raw({ startAt: '2026-10-17' }), TODAY), fails('invalid_argument', 'startAt'));
    assert.equal(validateEntryEvent(raw({ startAt: '2026-10-17' }), TODAY, { existingStartAt: '2026-10-17' }).startAt, '2026-10-17');
    assert.throws(() => validateEntryEvent(raw({ startAt: '18/10/2026' }), TODAY), fails('invalid_argument', 'startAt'));
  });

  test('close ≤ open → openHours', () => {
    assert.throws(() => validateEntryEvent(raw({ openHours: { start: '17:00', end: '17:00' } }), TODAY), fails('invalid_argument', 'openHours'));
    assert.throws(() => validateEntryEvent(raw({ openHours: { start: '17:00', end: '08:00' } }), TODAY), fails('invalid_argument', 'openHours'));
    assert.throws(() => validateEntryEvent(raw({ openHours: { start: '8:00', end: '17:00' } }), TODAY), fails('invalid_argument', 'openHours'));
  });

  test('0 or 7 ticket types → ticketTypes', () => {
    assert.throws(() => validateEntryEvent(raw({ ticketTypes: [] }), TODAY), fails('invalid_argument', 'ticketTypes'));
    const seven = Array.from({ length: 7 }, (_, i) => type({ id: `t${i}`, name: `Loại ${i}` }));
    assert.throws(() => validateEntryEvent(raw({ ticketTypes: seven }), TODAY), fails('invalid_argument', 'ticketTypes'));
    assert.equal(validateEntryEvent(raw({ ticketTypes: seven.slice(0, 6) }), TODAY).ticketTypes.length, 6);
  });

  test('type name of 2/41 → ticketTypes', () => {
    assert.throws(() => validateEntryEvent(raw({ ticketTypes: [type({ name: 'Vé' })] }), TODAY), fails('invalid_argument', 'ticketTypes'));
    assert.throws(() => validateEntryEvent(raw({ ticketTypes: [type({ name: 'a'.repeat(41) })] }), TODAY), fails('invalid_argument', 'ticketTypes'));
    assert.equal(validateEntryEvent(raw({ ticketTypes: [type({ name: 'a'.repeat(40) })] }), TODAY).ticketTypes[0]?.name, 'a'.repeat(40));
  });

  test('price 0 or 1.5 → ticketTypes', () => {
    assert.throws(() => validateEntryEvent(raw({ ticketTypes: [type({ price: 0 })] }), TODAY), fails('invalid_argument', 'ticketTypes'));
    assert.throws(() => validateEntryEvent(raw({ ticketTypes: [type({ price: 1.5 })] }), TODAY), fails('invalid_argument', 'ticketTypes'));
  });

  test('duplicate ticket type ids → ticketTypes; a missing id gets a new one', () => {
    assert.throws(() => validateEntryEvent(raw({ ticketTypes: [type(), type({ name: 'Khác' })] }), TODAY), fails('invalid_argument', 'ticketTypes'));
    let n = 0;
    const f = validateEntryEvent(raw({ ticketTypes: [{ name: 'Người lớn', price: 70_000 }] }), TODAY, { newId: () => `new${++n}` });
    assert.equal(f.ticketTypes[0]?.id, 'new1');
  });

  test('31 closedDays → closedDays (30 is fine, deduplicated and sorted)', () => {
    const days = Array.from({ length: 31 }, (_, i) => `2026-11-${String(i % 30 + 1).padStart(2, '0')}`);
    days[30] = '2026-12-01';
    assert.throws(() => validateEntryEvent(raw({ closedDays: days }), TODAY), fails('invalid_argument', 'closedDays'));
    assert.deepEqual(validateEntryEvent(raw({ closedDays: ['2026-11-02', '2026-11-01', '2026-11-02'] }), TODAY).closedDays,
      ['2026-11-01', '2026-11-02']);
    assert.throws(() => validateEntryEvent(raw({ closedDays: ['tomorrow'] }), TODAY), fails('invalid_argument', 'closedDays'));
  });

  test('closedWeekdays are 0 (Sunday) … 6; anything else → closedWeekdays', () => {
    assert.throws(() => validateEntryEvent(raw({ closedWeekdays: [7] }), TODAY), fails('invalid_argument', 'closedWeekdays'));
    assert.throws(() => validateEntryEvent(raw({ closedWeekdays: [0, 1, 2, 3, 4, 5, 6] }), TODAY), fails('invalid_argument', 'closedWeekdays'));
    assert.deepEqual(validateEntryEvent(raw({ closedWeekdays: [6, 0, 6] }), TODAY).closedWeekdays, [0, 6]);
  });

  test('dailyCapacity is null (no limit) or an integer ≥ 1', () => {
    assert.equal(validateEntryEvent(raw({ dailyCapacity: null }), TODAY).dailyCapacity, null);
    assert.throws(() => validateEntryEvent(raw({ dailyCapacity: 0 }), TODAY), fails('invalid_argument', 'dailyCapacity'));
    assert.throws(() => validateEntryEvent(raw({ dailyCapacity: 2.5 }), TODAY), fails('invalid_argument', 'dailyCapacity'));
  });

  test('refundCutoffHours default 48', () => {
    assert.equal(validateEntryEvent(raw(), TODAY).refundCutoffHours, ENTRY_REFUND_CUTOFF_HOURS);
    assert.equal(ENTRY_REFUND_CUTOFF_HOURS, 48);
    assert.equal(validateEntryEvent(raw({ refundCutoffHours: 24 }), TODAY).refundCutoffHours, 24);
    assert.throws(() => validateEntryEvent(raw({ refundCutoffHours: -1 }), TODAY), fails('invalid_argument', 'refundCutoffHours'));
  });

  test('a missing spot id → spotId', () => {
    assert.throws(() => validateEntryEvent(raw({ spotId: undefined }), TODAY), fails('invalid_argument', 'spotId'));
  });
});

describe('open days', () => {
  const f = validateEntryEvent(raw({ endAt: '2026-10-28' }), TODAY);

  test('openDays skips closedWeekdays and closedDays and stops at endAt (14 from today)', () => {
    // Mondays 19 and 26 are closed weekdays, the 25th a closed day; the range ends on the 28th.
    assert.deepEqual(openDays(f, TODAY, 14),
      ['2026-10-18', '2026-10-20', '2026-10-21', '2026-10-22', '2026-10-23', '2026-10-24', '2026-10-27', '2026-10-28']);
    assert.deepEqual(openDays(f, TODAY, 3), ['2026-10-18', '2026-10-20', '2026-10-21']);
    assert.deepEqual(openDays(f, '2026-10-01', 2), ['2026-10-18', '2026-10-20']);
  });

  test('isOpenDay', () => {
    assert.equal(isOpenDay(f, '2026-10-20'), true);
    assert.equal(isOpenDay(f, '2026-10-19'), false); // Monday
    assert.equal(isOpenDay(f, '2026-10-25'), false); // closed day
    assert.equal(isOpenDay(f, '2026-10-17'), false); // before the range
    assert.equal(isOpenDay(f, '2026-10-29'), false); // after the range
    assert.equal(isOpenDay(f, 'nope'), false);
  });
});

describe('priceItems', () => {
  const types: TicketType[] = [
    { id: 'adult', name: 'Người lớn', price: 70_000, hidden: false },
    { id: 'child', name: 'Trẻ em', price: 40_000, hidden: false },
    { id: 'old', name: 'Vé cũ', price: 50_000, hidden: true },
  ];

  test('two types × qty → lines, quantity, total', () => {
    assert.deepEqual(priceItems(types, [{ ticketTypeId: 'adult', qty: 2 }, { ticketTypeId: 'child', qty: 1 }]), {
      lines: [
        { ticketTypeId: 'adult', name: 'Người lớn', price: 70_000, qty: 2 },
        { ticketTypeId: 'child', name: 'Trẻ em', price: 40_000, qty: 1 },
      ],
      quantity: 3,
      total: 180_000,
    });
  });

  test('hidden type → invalid_argument', () => {
    assert.throws(() => priceItems(types, [{ ticketTypeId: 'old', qty: 1 }]), fails('invalid_argument', 'items'));
    assert.throws(() => priceItems(types, [{ ticketTypeId: 'ghost', qty: 1 }]), fails('invalid_argument', 'items'));
  });

  test('qty 0 → invalid_argument (an empty order or a repeated type too)', () => {
    assert.throws(() => priceItems(types, [{ ticketTypeId: 'adult', qty: 0 }]), fails('invalid_argument', 'items'));
    assert.throws(() => priceItems(types, []), fails('invalid_argument', 'items'));
    assert.throws(() => priceItems(types, [{ ticketTypeId: 'adult', qty: 1 }, { ticketTypeId: 'adult', qty: 1 }]),
      fails('invalid_argument', 'items'));
  });

  test('11 tickets → limit_exceeded', () => {
    assert.throws(() => priceItems(types, [{ ticketTypeId: 'adult', qty: 6 }, { ticketTypeId: 'child', qty: 5 }]), fails('limit_exceeded'));
    assert.equal(priceItems(types, [{ ticketTypeId: 'adult', qty: 10 }]).quantity, 10);
  });
});

describe('assertDailyCapacity', () => {
  const day = (over: Partial<EntryDay> = {}): EntryDay => ({
    eventId: 'ev', day: TODAY, sold: 0, held: 0, checkedIn: 0, closed: false, updatedAt: '2026-10-18T00:00:00.000Z', ...over,
  });

  test('closed → day_closed', () => {
    assert.throws(() => assertDailyCapacity(day({ closed: true }), 10, 1), fails('day_closed'));
    assert.throws(() => assertDailyCapacity(day({ closed: true }), null, 1), fails('day_closed'));
  });

  test('sold + held + qty > capacity → sold_out_day', () => {
    assert.throws(() => assertDailyCapacity(day({ sold: 6, held: 2 }), 10, 3), fails('sold_out_day'));
    assertDailyCapacity(day({ sold: 6, held: 2 }), 10, 2);
    assertDailyCapacity(null, 10, 10);
    assert.throws(() => assertDailyCapacity(null, 10, 11), fails('sold_out_day'));
  });

  test('capacity null never sells out', () => {
    assertDailyCapacity(day({ sold: 1_000_000 }), null, 10);
  });
});

describe('entry refunds and release', () => {
  const midnight = Date.parse('2026-10-19T17:00:00.000Z'); // 2026-10-20 00:00 in Vietnam

  test('entryRefundPercent: 49 h before 00:00 VN of the day → 100; 47 h → 0', () => {
    assert.equal(entryRefundPercent('2026-10-20', new Date(midnight - 49 * HOUR), 48), 100);
    assert.equal(entryRefundPercent('2026-10-20', new Date(midnight - 48 * HOUR), 48), 100);
    assert.equal(entryRefundPercent('2026-10-20', new Date(midnight - 47 * HOUR), 48), 0);
    assert.equal(entryRefundPercent('2026-10-20', new Date(midnight - 25 * HOUR), 24), 100);
  });

  test("entryReleaseAt('2026-10-20') = 2026-10-21T00:00 VN + 48 h", () => {
    assert.equal(entryReleaseAt('2026-10-20').toISOString(), new Date(Date.parse('2026-10-20T17:00:00.000Z') + 48 * HOUR).toISOString());
    assert.equal(entryReleaseAt('2026-10-20').toISOString(), '2026-10-22T17:00:00.000Z');
  });
});
