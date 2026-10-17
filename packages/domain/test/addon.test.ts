import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { validateAddonInput } from '../src/addon.js';
import { DomainError } from '../src/errors.js';

const OK = {
  kind: 'retouch',
  name: 'Chỉnh thêm ảnh',
  price: 100_000,
  unit: 'per_item',
  maxQty: 5,
  serviceIds: [] as unknown[],
  active: true,
};

function refused(over: Record<string, unknown>, code: string, field: string): void {
  assert.throws(
    () => validateAddonInput({ ...OK, ...over }),
    (e: unknown) => e instanceof DomainError && e.code === code && e.field === field,
  );
}

describe('validateAddonInput', () => {
  it('trims name and accepts 2 and 60 graphemes', () => {
    assert.equal(validateAddonInput({ ...OK, name: '  Ab  ' }).name, 'Ab');
    assert.equal(validateAddonInput({ ...OK, name: 'a'.repeat(60) }).name.length, 60);
  });

  it('refuses 1 and 61 graphemes with field name', () => {
    refused({ name: 'a' }, 'invalid_argument', 'name');
    refused({ name: 'a'.repeat(61) }, 'invalid_argument', 'name');
  });

  it('refuses a 201-grapheme description with field description; an empty description becomes absent', () => {
    refused({ description: 'a'.repeat(201) }, 'invalid_argument', 'description');
    assert.equal(validateAddonInput({ ...OK, description: 'a'.repeat(200) }).description?.length, 200);
    assert.equal('description' in validateAddonInput({ ...OK, description: '   ' }), false);
  });

  it('refuses price 9_999, 50_000_001 and 10_000.5 with field price; accepts 10_000 and 50_000_000', () => {
    for (const price of [9_999, 50_000_001, 10_000.5]) refused({ price }, 'invalid_argument', 'price');
    assert.equal(validateAddonInput({ ...OK, price: 10_000 }).price, 10_000);
    assert.equal(validateAddonInput({ ...OK, price: 50_000_000 }).price, 50_000_000);
  });

  it('refuses maxQty 0, 11 and 2.5 with field maxQty for per_person and per_item', () => {
    for (const unit of ['per_person', 'per_item']) {
      for (const maxQty of [0, 11, 2.5]) refused({ unit, maxQty }, 'invalid_argument', 'maxQty');
    }
  });

  it('per_booking stores maxQty 1 whatever was sent', () => {
    assert.equal(validateAddonInput({ ...OK, unit: 'per_booking', maxQty: 7 }).maxQty, 1);
    assert.equal(validateAddonInput({ ...OK, unit: 'per_booking', maxQty: undefined }).maxQty, 1);
  });

  it('refuses an unknown kind (field kind) and unit (field unit)', () => {
    refused({ kind: 'spa' }, 'invalid_argument', 'kind');
    refused({ unit: 'per_hour' }, 'invalid_argument', 'unit');
  });

  it('refuses serviceIds that are not ids, duplicated, or more than 20 (field serviceIds)', () => {
    refused({ serviceIds: ['a/b'] }, 'invalid_argument', 'serviceIds');
    refused({ serviceIds: ['a', 'a'] }, 'invalid_argument', 'serviceIds');
    refused({ serviceIds: Array.from({ length: 21 }, (_, i) => `s${i}`) }, 'invalid_argument', 'serviceIds');
    refused({ serviceIds: 'a' }, 'invalid_argument', 'serviceIds');
    const twenty = Array.from({ length: 20 }, (_, i) => `s${i}`);
    assert.equal(validateAddonInput({ ...OK, serviceIds: twenty }).serviceIds.length, 20);
  });

  it('refuses "Gọi 0903 123 456" in the name with contact_leak field name', () => {
    refused({ name: 'Gọi 0903 123 456' }, 'contact_leak', 'name');
  });

  it('refuses "zalo.me/0912345678" in the description with contact_leak field description', () => {
    refused({ description: 'zalo.me/0912345678' }, 'contact_leak', 'description');
  });

  it('accepts "Chỉnh thêm 10 ảnh, giao trong 3 ngày"', () => {
    assert.equal(
      validateAddonInput({ ...OK, description: 'Chỉnh thêm 10 ảnh, giao trong 3 ngày' }).description,
      'Chỉnh thêm 10 ảnh, giao trong 3 ngày',
    );
  });

  it('active must be a boolean', () => {
    refused({ active: 'true' }, 'invalid_argument', 'active');
    refused({ active: undefined }, 'invalid_argument', 'active');
  });

  it('addonId when present must be an id', () => {
    refused({ addonId: 'a/b' }, 'invalid_argument', 'addonId');
    assert.equal(validateAddonInput({ ...OK, addonId: 'A1' }).addonId, 'A1');
  });

  it('refuses a non-object', () => {
    assert.throws(() => validateAddonInput(null), (e: unknown) => e instanceof DomainError);
  });
});
