import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { distanceKm } from '../src/geo.js';
import { BEN_THANH, TAO_DAN } from './support/instant_fixtures.js';

describe('geo', () => {
  // The plan's name said "≈ 1,1 km"; the real straight-line distance between Công viên Tao Đàn
  // and Chợ Bến Thành is ≈ 0,65 km (see the task-2 report).
  it('distanceKm Tao Đàn → Bến Thành ≈ 0,65 km', () => {
    const km = distanceKm(TAO_DAN, BEN_THANH);
    assert.ok(Math.abs(km - 0.655) < 0.01, `got ${km}`);
    assert.equal(distanceKm(BEN_THANH, TAO_DAN), km);
  });

  it('one degree of latitude is 111,195 km (R = 6371.0088)', () => {
    const km = distanceKm({ lat: 10, lng: 106 }, { lat: 11, lng: 106 });
    assert.ok(Math.abs(km - (6371.0088 * Math.PI) / 180) < 1e-9, `got ${km}`);
  });

  it('0 for the same point', () => {
    assert.equal(distanceKm(TAO_DAN, TAO_DAN), 0);
  });
});
