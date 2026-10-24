import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { DomainError } from '../src/errors.js';
import { encodeGeohash } from '../src/event.js';
import {
  INSTANT,
  INSTANT_EVENTS,
  INSTANT_STATUSES,
  areaLabelAt,
  cityAt,
  estimateEtaMinutes,
  instantEarningLabel,
  instantSearchCells,
  isInstantActive,
  livePendingOffers,
  nextInstantStatus,
  parseInstantConfig,
  photographerEarning,
  presenceFresh,
  quoteInstantPrice,
  type InstantEvent,
  type InstantStatus,
} from '../src/instant.js';
import { MIN, SEC, T0, TAO_DAN, aConfig, aPresence, at, north } from './support/instant_fixtures.js';

const isCode = (code: string) => (e: unknown): boolean => e instanceof DomainError && e.code === code;

/** JSON round trip: what a Firestore adapter hands the parser (plain objects, no class instances). */
const raw = (o: unknown): Record<string, unknown> => JSON.parse(JSON.stringify(o)) as Record<string, unknown>;

const without = (o: Record<string, unknown>, key: string): Record<string, unknown> =>
  Object.fromEntries(Object.entries(o).filter(([k]) => k !== key));

describe('instant config', () => {
  it('parseInstantConfig accepts the seed config', () => {
    assert.deepEqual(parseInstantConfig(raw(aConfig())), aConfig());
  });

  it('refuses platformFeeBp outside 0–10000 and instantArrivedCancelPhotographerPercent outside 0–100 with not_eligible', () => {
    for (const platformFeeBp of [-1, 10_001, 0.5, '0', null]) {
      assert.throws(() => parseInstantConfig({ ...raw(aConfig()), platformFeeBp }), isCode('not_eligible'), String(platformFeeBp));
    }
    for (const pct of [-1, 101, 50.5, '50', null]) {
      assert.throws(
        () => parseInstantConfig({ ...raw(aConfig()), instantArrivedCancelPhotographerPercent: pct }),
        isCode('not_eligible'),
        String(pct),
      );
    }
    assert.equal(parseInstantConfig({ ...raw(aConfig()), platformFeeBp: 10_000 }).platformFeeBp, 10_000);
    assert.equal(parseInstantConfig({ ...raw(aConfig()), instantArrivedCancelPhotographerPercent: 0 }).instantArrivedCancelPhotographerPercent, 0);
  });

  it('a missing split reads the default 50 only through the seed, never in code paths of the request (the request snapshots it)', () => {
    assert.throws(() => parseInstantConfig(without(raw(aConfig()), 'instantArrivedCancelPhotographerPercent')), isCode('not_eligible'));
    assert.throws(() => parseInstantConfig(without(raw(aConfig()), 'platformFeeBp')), isCode('not_eligible'));
    // The value 50 lives in the seed only: a config with another split keeps it.
    assert.equal(parseInstantConfig(raw(aConfig({ instantArrivedCancelPhotographerPercent: 30 }))).instantArrivedCancelPhotographerPercent, 30);
  });

  it('refuses a package with a non-integer price', () => {
    const cfg = raw(aConfig());
    const packages = [{ code: 'p60', durationMin: 60, photos: 30, priceVnd: 690_000.5 }];
    assert.throws(() => parseInstantConfig({ ...cfg, packages }), isCode('not_eligible'));
    assert.throws(() => parseInstantConfig({ ...cfg, packages: [{ code: 'p60', durationMin: 60, photos: 30, priceVnd: '690000' }] }), isCode('not_eligible'));
    assert.throws(() => parseInstantConfig({ ...cfg, packages: [] }), isCode('not_eligible'));
    assert.throws(() => parseInstantConfig(null), isCode('not_eligible'));
  });

  it('refuses a city box turned inside out and a duplicate package code', () => {
    const cfg = raw(aConfig());
    const city = { id: 'hcm', name: 'TP.HCM', south: 11.17, west: 106.36, north: 10.35, east: 107.03, surgeBp: 10_000 };
    assert.throws(() => parseInstantConfig({ ...cfg, cities: [city] }), isCode('not_eligible'));
    const p = { code: 'p60', durationMin: 60, photos: 30, priceVnd: 690_000 };
    assert.throws(() => parseInstantConfig({ ...cfg, packages: [p, p] }), isCode('not_eligible'));
  });

  it('cityAt finds HCM inside its box and null in the sea', () => {
    const cfg = aConfig();
    assert.equal(cityAt(cfg, TAO_DAN.lat, TAO_DAN.lng)?.id, 'hcm');
    assert.equal(cityAt(cfg, 21.0285, 105.8542)?.id, 'hn');
    assert.equal(cityAt(cfg, 9.5, 108.5), null);
  });

  it('areaLabelAt picks the nearest area within 8 km, else the city name', () => {
    const cfg = aConfig();
    const hcm = cityAt(cfg, TAO_DAN.lat, TAO_DAN.lng);
    assert.ok(hcm);
    // Tao Đàn: Quận 1 centre ≈ 0,96 km, Quận 3 centre ≈ 1,38 km.
    assert.equal(areaLabelAt(cfg, hcm, TAO_DAN.lat, TAO_DAN.lng), 'Quận 1, TP.HCM');
    assert.equal(areaLabelAt(cfg, hcm, 10.786, 106.682), 'Quận 3, TP.HCM');
    // Củ Chi: inside the HCM box, > 8 km from every area.
    assert.equal(areaLabelAt(cfg, hcm, 11.0, 106.5), 'TP.HCM');
  });

  it('quoteInstantPrice rounds 690000 × 1.15 to 794000', () => {
    const [p30, p60] = aConfig().packages;
    assert.ok(p30 && p60);
    const [hcm] = aConfig().cities;
    assert.ok(hcm);
    const city = (surgeBp: number) => ({ ...hcm, surgeBp });
    assert.equal(quoteInstantPrice(p60, city(11_500)), 794_000);
    assert.equal(quoteInstantPrice(p60, city(10_000)), 690_000);
    assert.equal(quoteInstantPrice(p30, city(12_500)), 488_000);
  });

  it('photographerEarning is the amount with platformFeeBp 0 and amount − 10% with 1000', () => {
    assert.equal(photographerEarning(690_000, { platformFeeBp: 0 }), 690_000);
    assert.equal(photographerEarning(690_000, { platformFeeBp: 1000 }), 621_000);
    assert.equal(photographerEarning(794_000, { platformFeeBp: 1000 }), 714_600);
  });
});

describe('instant geometry', () => {
  it('estimateEtaMinutes: 0 km → 1, 1.2 km → 6, 2.1 km → 9, 10 km → 42', () => {
    assert.equal(estimateEtaMinutes(0), 1);
    assert.equal(estimateEtaMinutes(1.2), 6);
    assert.equal(estimateEtaMinutes(2.1), 9);
    assert.equal(estimateEtaMinutes(10), 42);
    assert.equal(estimateEtaMinutes(5), 21);
  });

  it('instantSearchCells near uses geohash5 3×3, wide uses geohash4 3×3, centre cell first', () => {
    const near = instantSearchCells(TAO_DAN.lat, TAO_DAN.lng, 'near');
    assert.equal(near.field, 'geohash5');
    assert.equal(near.cells.length, 9);
    assert.equal(new Set(near.cells).size, 9);
    assert.equal(near.cells[0], encodeGeohash(TAO_DAN.lat, TAO_DAN.lng, 5));
    assert.ok(near.cells.every((c) => c.length === 5));
    const wide = instantSearchCells(TAO_DAN.lat, TAO_DAN.lng, 'wide');
    assert.equal(wide.field, 'geohash4');
    assert.equal(wide.cells.length, 9);
    assert.equal(new Set(wide.cells).size, 9);
    assert.equal(wide.cells[0], encodeGeohash(TAO_DAN.lat, TAO_DAN.lng, 4));
    // Everyone within the rings is found: 3 km by the near cells, 10 km by the wide ones, in every direction.
    for (const [dLat, dLng] of [[1, 0], [-1, 0], [0, 1], [0, -1], [0.7, 0.7], [-0.7, -0.7], [0.7, -0.7], [-0.7, 0.7]] as const) {
      const p3 = { lat: TAO_DAN.lat + (dLat * 3) / 111.2, lng: TAO_DAN.lng + (dLng * 3) / 109.2 };
      assert.ok(near.cells.includes(encodeGeohash(p3.lat, p3.lng, 5)));
      const p10 = { lat: TAO_DAN.lat + (dLat * 10) / 111.2, lng: TAO_DAN.lng + (dLng * 10) / 109.2 };
      assert.ok(wide.cells.includes(encodeGeohash(p10.lat, p10.lng, 4)));
    }
    assert.ok(near.cells.includes(encodeGeohash(north(TAO_DAN, 2.9).lat, TAO_DAN.lng, 5)));
  });
});

/** Spec §3.1 plus `finished` (Decision 8); `invite` = offers sent (#140 at once, #202 after payment, later rounds on held money). */
const ARROWS: readonly (readonly [InstantStatus, InstantEvent, InstantStatus])[] = [
  ['choosing', 'invite_unpaid', 'pending_payment'],
  ['choosing', 'invite', 'searching'],
  ['pending_payment', 'paid', 'searching'],
  ['pending_payment', 'payment_expired', 'choosing'],
  ['searching', 'round_ended', 'choosing'],
  ['searching', 'accept', 'assigned'],
  ['choosing', 'no_match', 'no_match'],
  ['searching', 'no_match', 'no_match'],
  ['no_match', 'reopen', 'choosing'],
  ['assigned', 'start_route', 'en_route'],
  ['en_route', 'arrive', 'arrived'],
  ['arrived', 'start', 'in_progress'],
  ['in_progress', 'finish', 'finished'],
  ['in_progress', 'complete', 'completed'],
  ['finished', 'complete', 'completed'],
  ['assigned', 'photographer_cancel', 'choosing'],
  ['en_route', 'photographer_cancel', 'choosing'],
  ['arrived', 'photographer_cancel', 'choosing'],
  ['choosing', 'abandon', 'abandoned'],
  ['pending_payment', 'abandon', 'abandoned'],
  ['choosing', 'customer_cancel', 'cancelled_by_customer'],
  ['pending_payment', 'customer_cancel', 'cancelled_by_customer'],
  ['searching', 'customer_cancel', 'cancelled_by_customer'],
  ['no_match', 'customer_cancel', 'cancelled_by_customer'],
  ['assigned', 'customer_cancel', 'cancelled_by_customer'],
  ['en_route', 'customer_cancel', 'cancelled_by_customer'],
  ['arrived', 'customer_cancel', 'cancelled_by_customer'],
  ['arrived', 'no_show', 'no_show_customer'],
];

describe('instant state machine', () => {
  it('nextInstantStatus allows every arrow of spec §3.1 plus finished', () => {
    for (const [from, event, to] of ARROWS) assert.equal(nextInstantStatus(from, event), to, `${from} --${event}-->`);
  });

  it('refuses every other pair with conflict', () => {
    const allowed = new Set(ARROWS.map(([from, event]) => `${from}:${event}`));
    let refused = 0;
    for (const from of INSTANT_STATUSES) {
      for (const event of INSTANT_EVENTS) {
        if (allowed.has(`${from}:${event}`)) continue;
        assert.throws(() => nextInstantStatus(from, event), isCode('conflict'), `${from} --${event}-->`);
        refused++;
      }
    }
    assert.equal(refused, INSTANT_STATUSES.length * INSTANT_EVENTS.length - ARROWS.length);
  });

  it('isInstantActive is false only for the four terminal statuses', () => {
    const inactive = INSTANT_STATUSES.filter((s) => !isInstantActive(s));
    assert.deepEqual(inactive, ['completed', 'abandoned', 'cancelled_by_customer', 'no_show_customer']);
  });
});

describe('instant presence', () => {
  it('livePendingOffers drops expired entries', () => {
    const p = aPresence('p1', {
      pendingOffers: [
        { offerId: 'o1', requestId: 'r1', expiresAt: at(-1) },
        { offerId: 'o2', requestId: 'r2', expiresAt: T0 },
        { offerId: 'o3', requestId: 'r3', expiresAt: at(30 * SEC) },
      ],
    });
    assert.deepEqual(livePendingOffers(p, T0).map((o) => o.offerId), ['o3']);
  });

  it('presenceFresh is false 30 minutes after the heartbeat or when offline', () => {
    const p = aPresence('p1', { heartbeatAt: T0 });
    assert.equal(presenceFresh(p, at(29 * MIN + 59 * SEC)), true);
    assert.equal(presenceFresh(p, at(INSTANT.PRESENCE_FRESH_MIN * MIN)), false);
    assert.equal(presenceFresh(aPresence('p2', { online: false }), T0), false);
    assert.equal(presenceFresh(aPresence('p3', { heartbeatAt: null }), T0), false);
  });
});

describe('instantEarningLabel (#202)', () => {
  it('reads the package duration', () => {
    assert.equal(instantEarningLabel(60), 'Chụp ngay · 1 giờ');
    assert.equal(instantEarningLabel(30), 'Chụp ngay · 30 phút');
    assert.equal(instantEarningLabel(120), 'Chụp ngay · 2 giờ');
    assert.equal(instantEarningLabel(90), 'Chụp ngay · 1 giờ 30 phút');
  });
});
