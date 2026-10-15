import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  distanceMeters,
  inSeason,
  regionOfArea,
  seasonOk,
  seasonRunEnd,
  spotCovers,
} from '../src/spot.js';

describe('spot domain helpers', () => {
  it('regionOfArea maps hcm-q1 → hcm, hn-ba-dinh → hn, dn-hai-chau → dn, da-lat → da-lat, null → all', () => {
    assert.equal(regionOfArea('hcm-q1'), 'hcm');
    assert.equal(regionOfArea('hn-ba-dinh'), 'hn');
    assert.equal(regionOfArea('dn-hai-chau'), 'dn');
    assert.equal(regionOfArea('da-lat'), 'da-lat');
    assert.equal(regionOfArea(null), 'all');
  });

  it('inSeason([10,11,12], 11) is true, ([], 5) is false', () => {
    assert.equal(inSeason([10, 11, 12], 11), true);
    assert.equal(inSeason([], 5), false);
    assert.equal(inSeason([10, 11, 12], 5), false);
  });

  it('seasonOk([], 5) is true', () => {
    assert.equal(seasonOk({ seasonMonths: [] }, 5), true);
    assert.equal(seasonOk({ seasonMonths: [10, 11] }, 10), true);
    assert.equal(seasonOk({ seasonMonths: [10, 11] }, 5), false);
  });

  it('seasonRunEnd([11,12,1], 12) is 1 (wraps the year), ([10,11], 11) is 11, ([3,9], 3) is 3', () => {
    assert.equal(seasonRunEnd([11, 12, 1], 12), 1);
    assert.equal(seasonRunEnd([10, 11], 11), 11);
    assert.equal(seasonRunEnd([3, 9], 3), 3);
    assert.equal(seasonRunEnd([3, 9], 5), null);
  });

  it('distanceMeters Hồ Gươm → Hồ Tây ≈ 3,000 m (±5%)', () => {
    // Hồ Gươm (21.0285, 105.8542) to Hồ Tây (Trần Quốc / Thanh Niên 21.0478, 105.8325)
    const hoGuom = { lat: 21.0285, lng: 105.8542 };
    const hoTay = { lat: 21.0478, lng: 105.8325 };
    const d = distanceMeters(hoGuom, hoTay);
    assert.ok(d >= 2850 && d <= 3150, `Expected ~3000m, got ${d}`);
  });

  it('spotCovers is true inside the radius, false 1 m outside, true with slack', () => {
    const spot = { point: { lat: 21.0285, lng: 105.8542 }, radiusM: 500 };
    // Exact center
    assert.equal(spotCovers(spot, { lat: 21.0285, lng: 105.8542 }), true);
    // Find a point exactly at ~500m
    // 1 deg latitude ≈ 111,139 m. 500m ≈ 0.0044988 deg
    const pInside = { lat: 21.0285 + 400 / 111139, lng: 105.8542 };
    assert.equal(spotCovers(spot, pInside), true);

    const d500 = distanceMeters(spot.point, { lat: 21.0285 + 500 / 111139, lng: 105.8542 });
    // Point 1m outside:
    const deltaDeg1mOutside = ((500 + 1) / d500) * (500 / 111139);
    const pOutside = { lat: 21.0285 + deltaDeg1mOutside, lng: 105.8542 };
    assert.equal(spotCovers(spot, pOutside), false);
    // With slack 500m, it should cover
    assert.equal(spotCovers(spot, pOutside, 500), true);
  });
});
