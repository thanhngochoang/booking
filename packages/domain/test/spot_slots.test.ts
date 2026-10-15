import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { slotsFor, validateSlotOfferInput } from '../src/spot_slots.js';
import { isDomainError } from '../src/errors.js';

describe('spot_slots', () => {
  describe('slotsFor', () => {
    it('slotsFor 06:00–11:00, 30/10 → 06:00, 06:40, 07:20, 08:00, 08:40, 09:20, 10:00 (7 slots)', () => {
      const slots = slotsFor({ start: '06:00', end: '11:00' }, 30, 10);
      assert.deepEqual(slots, [
        { start: '06:00', end: '06:30' },
        { start: '06:40', end: '07:10' },
        { start: '07:20', end: '07:50' },
        { start: '08:00', end: '08:30' },
        { start: '08:40', end: '09:10' },
        { start: '09:20', end: '09:50' },
        { start: '10:00', end: '10:30' },
      ]);
    });

    it('gap 0: 06:00–08:00, 30 → 4 slots ending 08:00', () => {
      const slots = slotsFor({ start: '06:00', end: '08:00' }, 30, 0);
      assert.deepEqual(slots, [
        { start: '06:00', end: '06:30' },
        { start: '06:30', end: '07:00' },
        { start: '07:00', end: '07:30' },
        { start: '07:30', end: '08:00' },
      ]);
    });

    it('window shorter than a slot → []', () => {
      const slots = slotsFor({ start: '06:00', end: '06:20' }, 30, 0);
      assert.deepEqual(slots, []);
    });

    it('a window that does not divide evenly drops the tail', () => {
      const slots = slotsFor({ start: '06:00', end: '07:20' }, 45, 15);
      // 06:00-06:45, next is 07:00-07:45 which exceeds 07:20
      assert.deepEqual(slots, [{ start: '06:00', end: '06:45' }]);
    });
  });

  describe('validateSlotOfferInput', () => {
    const valid = {
      scheduleId: '01HR0000000000000000000001',
      name: 'Gói chụp hoàng hôn',
      price: 500_000,
      slotMinutes: 45,
      gapMinutes: 15,
      photoCount: 50,
      editedCount: 10,
      deliveryDays: 3,
    };

    it('accepts valid input', () => {
      const res = validateSlotOfferInput(valid);
      assert.equal(res.name, 'Gói chụp hoàng hôn');
      assert.equal(res.price, 500_000);
    });

    it('price 9_999 / 100_000_001 / 10_000.5 → field price', () => {
      for (const price of [9_999, 100_000_001, 10_000.5]) {
        assert.throws(
          () => validateSlotOfferInput({ ...valid, price }),
          (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'price',
        );
      }
    });

    it('slotMinutes 14 and 91 → field slotMinutes', () => {
      for (const slotMinutes of [14, 91]) {
        assert.throws(
          () => validateSlotOfferInput({ ...valid, slotMinutes }),
          (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'slotMinutes',
        );
      }
    });

    it('gapMinutes 31 → field gapMinutes', () => {
      assert.throws(
        () => validateSlotOfferInput({ ...valid, gapMinutes: 31 }),
        (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'gapMinutes',
      );
    });

    it('editedCount above photoCount → field editedCount', () => {
      assert.throws(
        () => validateSlotOfferInput({ ...valid, photoCount: 50, editedCount: 51 }),
        (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'editedCount',
      );
    });

    it('deliveryDays 0 and 31 → field deliveryDays', () => {
      for (const deliveryDays of [0, 31]) {
        assert.throws(
          () => validateSlotOfferInput({ ...valid, deliveryDays }),
          (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'deliveryDays',
        );
      }
    });

    it('name "Gọi 0903 123 456" → contact_leak field name', () => {
      assert.throws(
        () => validateSlotOfferInput({ ...valid, name: 'Gọi 0903 123 456' }),
        (err: unknown) => isDomainError(err) && err.code === 'contact_leak' && err.field === 'name',
      );
    });

    it('name of 2 or 61 graphemes → field name', () => {
      for (const name of ['Ab', 'a'.repeat(61)]) {
        assert.throws(
          () => validateSlotOfferInput({ ...valid, name }),
          (err: unknown) => isDomainError(err) && err.code === 'invalid_argument' && err.field === 'name',
        );
      }
    });
  });
});
