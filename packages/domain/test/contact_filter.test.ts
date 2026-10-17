import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { findContactLeak } from '../src/contact_filter.js';
import { DomainError } from '../src/errors.js';

const TABLE: ReadonlyArray<readonly [string, ReturnType<typeof findContactLeak>]> = [
  ['0903 123 456', 'phone'],
  ['+84 903.123.456', 'phone'],
  ['84912345678', 'phone'],
  ['0 9 0 3 1 2 3 4 5 6', 'phone'],
  ['liên hệ a@b.vn', 'email'],
  ['xem www.abc.com', 'link'],
  ['fb.com/abc', 'link'],
  ['studio.vn', 'link'],
  ['zalo.me/0912345678', 'link'],
  ['nhắn Zalo nhé', 'zalo'],
  ['42 bạn, 12A1, 2025', null],
  ['giá 3.000.000đ', null],
  ['ngân sách 1.000.000.000₫', null],
  ['từ 7:00 đến 11:00', null],
  ['70-200mm f2.8', null],
  ['Kỷ yếu lớp 12A1, 42 bạn', null],
];

describe('findContactLeak', () => {
  for (const [text, want] of TABLE) {
    it(`${JSON.stringify(text)} -> ${want}`, () => assert.equal(findContactLeak(text), want));
  }
});

describe('DomainError field', () => {
  it('carries an optional field', () => {
    assert.equal(new DomainError('invalid_argument', 'name').field, 'name');
    assert.equal(new DomainError('not_found').field, undefined);
  });
});
