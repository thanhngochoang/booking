import { strict as assert } from 'node:assert';
import test from 'node:test';
import { counterPatch } from '../src/counters.js';

test('counters.test.ts: counterPatch', async (t) => {
  await t.test('writes the recount when nothing is stored', () => {
    const patch = counterPatch(
      { value: null, at: null },
      5,
      '2026-10-07T10:00:00.000Z',
    );
    assert.deepEqual(patch, {
      value: 5,
      at: '2026-10-07T10:00:00.000Z',
    });
  });

  await t.test('writes when the event is newer', () => {
    const patch = counterPatch(
      { value: 3, at: '2026-10-07T09:00:00.000Z' },
      4,
      '2026-10-07T10:00:00.000Z',
    );
    assert.deepEqual(patch, {
      value: 4,
      at: '2026-10-07T10:00:00.000Z',
    });
  });

  await t.test('a stale event does not overwrite a newer recount', () => {
    const patch = counterPatch(
      { value: 5, at: '2026-10-07T11:00:00.000Z' },
      4,
      '2026-10-07T10:00:00.000Z',
    );
    assert.equal(patch, null);
  });

  await t.test('same value and same time -> null', () => {
    const patch = counterPatch(
      { value: 5, at: '2026-10-07T10:00:00.000Z' },
      5,
      '2026-10-07T10:00:00.000Z',
    );
    assert.equal(patch, null);
  });

  await t.test('same value, newer time -> writes (freshness)', () => {
    const patch = counterPatch(
      { value: 5, at: '2026-10-07T09:00:00.000Z' },
      5,
      '2026-10-07T10:00:00.000Z',
    );
    assert.deepEqual(patch, {
      value: 5,
      at: '2026-10-07T10:00:00.000Z',
    });
  });

  await t.test('negative or fractional recount -> invalid_argument', () => {
    assert.throws(
      () => counterPatch({ value: null, at: null }, -1, '2026-10-07T10:00:00.000Z'),
      { name: 'DomainError', code: 'invalid_argument' },
    );
    assert.throws(
      () => counterPatch({ value: null, at: null }, 2.5, '2026-10-07T10:00:00.000Z'),
      { name: 'DomainError', code: 'invalid_argument' },
    );
  });
});
