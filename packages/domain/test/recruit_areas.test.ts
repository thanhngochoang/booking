import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { RECRUIT_AREAS, recruitAreasOf, recruitCityOf, recruitMatchKeysOf } from '../src/recruit_areas.js';

/** The ids of `builtInAreas` (app_flutter/lib/data/location/area.dart), in order. */
const BUILT_IN_AREA_IDS = [
  'hcm-q1', 'hcm-q3', 'hcm-q7', 'hcm-binh-thanh', 'hcm-thu-duc',
  'hn-hoan-kiem', 'hn-ba-dinh', 'hn-cau-giay', 'dn-hai-chau', 'hue', 'da-lat', 'nha-trang',
];

const Q1 = { lat: 10.7769, lng: 106.7009 };

describe('recruit areas', () => {
  it('RECRUIT_AREAS has the 12 builtInAreas ids in order', () => {
    assert.deepEqual(RECRUIT_AREAS.map((a) => a.id), BUILT_IN_AREA_IDS);
    assert.deepEqual(RECRUIT_AREAS[0], { id: 'hcm-q1', cityKey: 'hcm', lat: 10.7769, lng: 106.7009 });
  });

  it('recruitCityOf folds accents and aliases', () => {
    for (const city of ['TP.HCM', 'Hồ Chí Minh', 'Sài Gòn', 'tp. hồ chí minh', 'HCM']) assert.equal(recruitCityOf(city), 'hcm', city);
    assert.equal(recruitCityOf('Hà Nội'), 'hn');
    assert.equal(recruitCityOf('Đà Nẵng'), 'dn');
    assert.equal(recruitCityOf('Huế'), 'hue');
    assert.equal(recruitCityOf('Đà Lạt'), 'da-lat');
    assert.equal(recruitCityOf('Nha Trang'), 'nha-trang');
    assert.equal(recruitCityOf('Paris'), null);
    assert.equal(recruitCityOf(''), null);
  });

  it('areas by centre and radius', () => {
    assert.deepEqual(recruitAreasOf({ city: 'TP.HCM', radiusKm: 5, center: Q1 }), ['hcm-q1', 'hcm-q3', 'hcm-binh-thanh']);
    assert.deepEqual(recruitAreasOf({ city: 'TP.HCM', radiusKm: 1, center: Q1 }), ['hcm-q1']);
  });

  it('areas by city when no centre', () => {
    assert.deepEqual(recruitAreasOf({ city: 'Hà Nội', radiusKm: 10 }), ['hn-hoan-kiem', 'hn-ba-dinh', 'hn-cau-giay']);
    assert.deepEqual(recruitAreasOf({ city: 'Sài Gòn', radiusKm: 10, center: null }),
      ['hcm-q1', 'hcm-q3', 'hcm-q7', 'hcm-binh-thanh', 'hcm-thu-duc']);
    assert.deepEqual(recruitAreasOf({ city: 'Paris', radiusKm: 10 }), []);
    assert.deepEqual(recruitAreasOf(null), []);
  });

  it('recruitMatchKeysOf: every area × specialty of a provider', () => {
    assert.deepEqual(
      recruitMatchKeysOf({ role: 'photographer', providerType: 'individual', serviceArea: { city: 'Huế', radiusKm: 10 },
        specialties: ['portrait', 'wedding', 'portrait'] }),
      ['a=hue|s=portrait', 'a=hue|s=wedding'],
    );
    assert.equal(
      recruitMatchKeysOf({ role: 'photographer', providerType: 'artist', serviceArea: { city: 'TP.HCM', radiusKm: 10 },
        specialties: ['wedding'] }).length,
      5,
    );
  });

  it('recruitMatchKeysOf is empty for studios and for customers', () => {
    const area = { city: 'TP.HCM', radiusKm: 10 };
    assert.deepEqual(recruitMatchKeysOf({ role: 'photographer', providerType: 'studio', serviceArea: area, specialties: ['wedding'] }), []);
    assert.deepEqual(recruitMatchKeysOf({ role: 'customer', providerType: 'individual', serviceArea: area, specialties: ['wedding'] }), []);
    assert.deepEqual(recruitMatchKeysOf({ role: null, providerType: 'individual', serviceArea: area, specialties: ['wedding'] }), []);
  });
});
