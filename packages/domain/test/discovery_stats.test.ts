import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  addDays,
  computeNextFreeDate,
  computeStartingPrice,
  statsPatch,
  isCatalogSpecialty,
  NEXT_FREE_HORIZON_DAYS,
} from '../src/discovery_stats.js';

describe('discovery_stats', () => {
  it('addDays crosses month and year ends', () => {
    assert.equal(addDays('2026-12-31', 1), '2027-01-01');
    assert.equal(addDays('2026-03-01', -1), '2026-02-28');
    assert.equal(addDays('2026-10-07', 0), '2026-10-07');
    assert.equal(addDays('2026-10-07', 5), '2026-10-12');
  });

  it('computeNextFreeDate returns today when today is not blocked', () => {
    const today = '2026-10-07';
    const blocked = new Set<string>();
    assert.equal(computeNextFreeDate(today, blocked), '2026-10-07');
  });

  it('a pending day is not free', () => {
    const today = '2026-10-07';
    const blocked = new Set<string>([today]);
    assert.equal(computeNextFreeDate(today, blocked), '2026-10-08');
  });

  it('no free day in the horizon is null', () => {
    const today = '2026-10-07';
    const blocked60 = new Set<string>();
    for (let i = 0; i < NEXT_FREE_HORIZON_DAYS; i++) {
      blocked60.add(addDays(today, i));
    }
    assert.equal(computeNextFreeDate(today, blocked60), null);

    const blocked3 = new Set<string>([
      today,
      addDays(today, 1),
      addDays(today, 2),
    ]);
    assert.equal(computeNextFreeDate(today, blocked3, 3), null);
    assert.equal(computeNextFreeDate(today, blocked3, 4), addDays(today, 3));
  });

  it('computeStartingPrice takes the smallest positive integer', () => {
    assert.equal(
      computeStartingPrice([1500000, 900000, 0, -1, 1.5, '2']),
      900000,
    );
    assert.equal(computeStartingPrice([]), null);
    assert.equal(computeStartingPrice([0, -500, null, undefined, 'abc']), null);
  });

  it('statsPatch returns only changed fields', () => {
    const current = {
      nextFreeDate: '2026-10-07',
      score: 0.5,
      completedCount: 10,
      startingPrice: 500000,
    };
    const patch = statsPatch(current, {
      nextFreeDate: '2026-10-08',
      startingPrice: 500000,
    });
    assert.deepEqual(patch, { nextFreeDate: '2026-10-08' });
  });

  it('statsPatch is null when nothing changes', () => {
    const current = {
      nextFreeDate: '2026-10-07',
      score: 0.5,
      completedCount: 10,
      startingPrice: 500000,
    };
    const patch = statsPatch(current, {
      nextFreeDate: '2026-10-07',
      completedCount: 10,
      startingPrice: 500000,
    });
    assert.equal(patch, null);
  });

  it('the first nextFreeDate write also ensures score', () => {
    const currentNoScore = {
      nextFreeDate: null,
      completedCount: 0,
      startingPrice: null,
    };
    const patch1 = statsPatch(currentNoScore, { nextFreeDate: '2026-10-08' });
    assert.deepEqual(patch1, {
      nextFreeDate: '2026-10-08',
      ensureScore: true,
    });

    const currentWithScore = {
      nextFreeDate: null,
      score: 0.4,
      completedCount: 0,
      startingPrice: null,
    };
    const patch2 = statsPatch(currentWithScore, { nextFreeDate: '2026-10-08' });
    assert.deepEqual(patch2, { nextFreeDate: '2026-10-08' });
  });

  it('isCatalogSpecialty accepts code-shaped strings only', () => {
    assert.equal(isCatalogSpecialty('portrait'), true);
    assert.equal(isCatalogSpecialty('family_kids'), true);
    assert.equal(isCatalogSpecialty('weddings_123'), true);
    assert.equal(isCatalogSpecialty('../x'), false);
    assert.equal(isCatalogSpecialty(''), false);
    assert.equal(isCatalogSpecialty('Portrait'), false);
    assert.equal(isCatalogSpecialty(42), false);
    assert.equal(isCatalogSpecialty(null), false);
    assert.equal(isCatalogSpecialty('a'), false); // min length 2 per regex ^[a-z][a-z0-9_]{1,39}$
  });
});
