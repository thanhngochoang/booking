import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { spotHotScore } from '../src/spot_score.js';
import { inSeason, type SpotStats } from '../src/spot.js';

describe('spot_score', () => {
  const stats: SpotStats = {
    posts14d: 2,
    events: 1,
    bookings14d: 1,
    openSchedules: 2,
    providersWeek: 1,
    providersWeekend: 1,
  };

  it('score = 1·posts + 3·events + 2·bookings + 2·schedules', () => {
    // 2*1 + 1*3 + 1*2 + 2*2 = 2 + 3 + 2 + 4 = 11
    const raw = spotHotScore(stats, [], 10);
    assert.equal(raw, 11);
  });

  it('in season ×1.5 rounded', () => {
    // 11 * 1.5 = 16.5 -> round to 17
    const scored = spotHotScore(stats, [10, 11, 12], 11);
    assert.equal(scored, 17);
  });

  it('season-less spots get no multiplier', () => {
    const scored = spotHotScore(stats, [], 5);
    assert.equal(scored, 11);
  });

  it('December in [12, 1] is in season; February is not', () => {
    const months = [12, 1];
    assert.equal(inSeason(months, 12), true);
    assert.equal(inSeason(months, 2), false);

    assert.equal(spotHotScore(stats, months, 12), 17);
    assert.equal(spotHotScore(stats, months, 2), 11);
  });
});
