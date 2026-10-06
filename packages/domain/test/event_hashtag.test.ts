import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  foldVietnamese, hashtagBase, hashtagKeyOf, hashtagWithSuffix, isValidHashtag,
} from '../src/event_hashtag.js';

const oct20 = new Date('2026-10-20T03:00:00.000Z');

test('folds Vietnamese marks and đ', () => {
  assert.equal(foldVietnamese('Phố cổ Đà Nẵng đẹp'), 'Pho co Da Nang dep');
});

test('PascalCases words and appends MMDD', () => {
  assert.equal(hashtagBase('Photo walk phố cổ', oct20), 'PhotoWalkPhoCo1020');
});

test('MMDD is the Vietnam day', () => {
  // 23:30 UTC on 20 Oct is already 21 Oct in Vietnam
  assert.equal(hashtagBase('Walk', new Date('2026-10-20T23:30:00.000Z')), 'Walk1021');
});

test('drops symbols and keeps digits', () => {
  assert.equal(hashtagBase('Cosplay #2026 -- (vui!) 3x', oct20), 'Cosplay2026Vui3x1020');
});

test('never exceeds 40 characters', () => {
  const tag = hashtagBase('a'.repeat(200), oct20);
  assert.equal(tag.length, 40);
  assert.ok(isValidHashtag(tag));
  assert.ok(hashtagWithSuffix(tag, 12).length <= 40);
  assert.ok(hashtagWithSuffix(tag, 12).endsWith('12'));
});

test('a title of symbols still gives a valid tag', () => {
  assert.ok(isValidHashtag(hashtagBase('!!!', oct20)));
});

test('key is lower case', () => {
  assert.equal(hashtagKeyOf('PhotoWalk1020'), 'photowalk1020');
});

test('3–40 letters and digits only', () => {
  assert.equal(isValidHashtag('abc'), true);
  assert.equal(isValidHashtag('ab'), false);
  assert.equal(isValidHashtag('a'.repeat(40)), true);
  assert.equal(isValidHashtag('a'.repeat(41)), false);
  assert.equal(isValidHashtag('co dau'), false);
  assert.equal(isValidHashtag('phố'), false);
  assert.equal(isValidHashtag('a_b'), false);
});
