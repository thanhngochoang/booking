import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { isId, newUlid } from '../src/index.js';

describe('ids', () => {
  test('isId accepts opaque 1-64 char ids and refuses paths', () => {
    for (const ok of ['a', 'seed-booking-accepted', 'AbC_123-x', '01ARYZ6S41TSV4RRFFQ69G5FAV', 'x'.repeat(64)]) {
      assert.equal(isId(ok), true, ok);
    }
    for (const bad of ['', 'x'.repeat(65), 'a/b', '../x', 'a b', 'ä', 5, null]) {
      assert.equal(isId(bad), false, String(bad));
    }
  });

  test('newUlid encodes the time like the ULID spec', () => {
    const zeros = (n: number) => new Uint8Array(n);
    assert.equal(newUlid(1469918176385, zeros), `01ARYZ6S41${'0'.repeat(16)}`);
    assert.equal(newUlid(0, zeros), '0'.repeat(26));
  });

  test('newUlid is 26 Crockford characters, a valid id, and sorts by time', () => {
    const a = newUlid(1_700_000_000_000);
    const b = newUlid(1_700_000_000_001);
    assert.match(a, /^[0-9A-HJKMNP-TV-Z]{26}$/);
    assert.equal(isId(a), true);
    assert.ok(a < b);
  });

  test('newUlid gives different ids in the same millisecond', () => {
    const ids = new Set(Array.from({ length: 1000 }, () => newUlid(1_700_000_000_000)));
    assert.equal(ids.size, 1000);
  });

  test('newUlid refuses times outside 48 bits', () => {
    assert.throws(() => newUlid(-1), RangeError);
    assert.throws(() => newUlid(2 ** 48), RangeError);
    assert.throws(() => newUlid(1.5), RangeError);
  });
});
