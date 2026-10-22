import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { InstantGenre, InstantPresence } from '../src/instant.js';
import {
  candidateReasons,
  dayBlocksInstant,
  isPriorityTier,
  rankCandidates,
  type InstantDayState,
} from '../src/instant_match.js';
import { MIN, SEC, T0, TAO_DAN, aPresence, at, north, type PresenceOverrides } from './support/instant_fixtures.js';

/** A photographer `km` north of the meet point. */
const near = (uid: string, km: number, overrides: PresenceOverrides = {}): InstantPresence =>
  aPresence(uid, { ...north(TAO_DAN, km), ...overrides });

function rank(
  presences: readonly InstantPresence[],
  o: { genre?: InstantGenre; excluded?: readonly string[]; dayStates?: ReadonlyMap<string, InstantDayState> } = {},
) {
  return rankCandidates({
    presences,
    meetPoint: TAO_DAN,
    genre: o.genre ?? 'portrait',
    excluded: new Set(o.excluded ?? []),
    customerId: 'c-lan',
    priceListVersion: 1,
    now: T0,
    dayStates: o.dayStates ?? new Map(),
  });
}

const ids = (cs: readonly { photographerId: string }[]): string[] => cs.map((c) => c.photographerId);
const close = (a: number, b: number): boolean => Math.abs(a - b) < 1e-9;

describe('rankCandidates', () => {
  it('returns at most 5, nearest rings first (3 then 6 then 10 km)', () => {
    const ps = [near('k9', 9), near('k1', 1), near('k12', 12), near('k5', 5), near('k7', 7), near('k2', 2), near('k4', 4), near('k8', 8)];
    const out = rank(ps);
    assert.deepEqual(ids(out), ['k1', 'k2', 'k4', 'k5', 'k7']);
    // Only two within 3 km and four within 6 km: the round widens to 10 km, never beyond.
    assert.deepEqual(ids(rank([near('k1', 1), near('k5', 5), near('k12', 12)])), ['k1', 'k5']);
  });

  it('stops widening once 5 are found within 3 km', () => {
    const unverified = { profile: { verified: false } };
    const ps = [0.5, 1, 1.5, 2, 2.5].map((km, i) => near(`n${i}`, km, unverified));
    const star = near('star', 4, { helpReady: true });
    const out = rank([star, ...ps]);
    assert.deepEqual(ids(out), ['n0', 'n1', 'n2', 'n3', 'n4']);
    assert.ok(out.every((c) => c.tier === 'expanded'));
  });

  it('skips offline, stale, busy, excluded, self, other price list, and 3 live pending offers', () => {
    const live = (n: number) => Array.from({ length: n }, (_, i) => ({ offerId: `o${i}`, requestId: `r${i}`, expiresAt: at(30 * SEC) }));
    const ps = [
      near('ok', 1),
      near('offline', 1, { online: false }),
      near('stale', 1, { heartbeatAt: at(-30 * MIN) }),
      near('busy', 1, { activeRequestId: 'ir_other' }),
      near('declined-before', 1),
      aPresence('c-lan', north(TAO_DAN, 1)),
      near('old-prices', 1, { priceListVersion: 0 }),
      near('no-prices', 1, { priceListVersion: null }),
      near('three-offers', 1, { pendingOffers: live(3) }),
      aPresence('no-position', { lat: null, lng: null }),
      near('far', 10.5),
    ];
    assert.deepEqual(ids(rank(ps, { excluded: ['declined-before'] })), ['ok']);
  });

  it('counts only unexpired pending offers', () => {
    const pendingOffers = [
      { offerId: 'o1', requestId: 'r1', expiresAt: at(-1) },
      { offerId: 'o2', requestId: 'r2', expiresAt: T0 },
      { offerId: 'o3', requestId: 'r3', expiresAt: at(30 * SEC) },
    ];
    assert.deepEqual(ids(rank([near('p1', 1, { pendingOffers })])), ['p1']);
  });

  it('a provider holding today for an open spot schedule, a full studio day or a booking is not a candidate', () => {
    const ps = [near('free', 1), near('spot', 1), near('full', 1), near('booked', 1), near('off', 1), near('pending', 1)];
    const dayStates = new Map<string, InstantDayState>([['spot', 'spot'], ['full', 'full'], ['booked', 'booked'], ['off', 'off'], ['pending', 'pending']]);
    assert.deepEqual(ids(rank(ps, { dayStates })).sort(), ['free', 'off', 'pending']);
    for (const s of ['spot', 'full', 'booked'] as const) assert.equal(dayBlocksInstant(s), true);
    for (const s of ['off', 'pending', null] as const) assert.equal(dayBlocksInstant(s), false);
  });

  it('priority tier fills first, expanded only fills the rest', () => {
    const expanded = [0.2, 0.4, 0.6, 0.8].map((km, i) => near(`e${i}`, km, { profile: { verified: false } }));
    const priority = [2.5, 2.6, 2.7].map((km, i) => near(`p${i}`, km));
    const out = rank([...expanded, ...priority]);
    assert.deepEqual(ids(out), ['p0', 'p1', 'p2', 'e0', 'e1']);
    assert.deepEqual(out.map((c) => c.tier), ['priority', 'priority', 'priority', 'expanded', 'expanded']);
  });

  it('helpReady joins the priority tier and gets +0.05', () => {
    assert.equal(isPriorityTier(aPresence('u', { helpReady: true, profile: { verified: false } })), true);
    assert.equal(isPriorityTier(aPresence('u', { profile: { verified: false } })), false);
    const out = rank([near('plain', 1), near('helper', 1, { helpReady: true })]);
    assert.deepEqual(ids(out), ['helper', 'plain']);
    const [helper, plain] = out;
    assert.ok(helper && plain);
    assert.ok(close(helper.score - plain.score, 0.05));
  });

  it('a photographer with ≥ 5 reviews and tomatoPct below 90 is expanded', () => {
    assert.equal(isPriorityTier(aPresence('u', { profile: { reviewCount: 5, tomatoPct: 89 } })), false);
    assert.equal(isPriorityTier(aPresence('u', { profile: { reviewCount: 5, tomatoPct: 90 } })), true);
    assert.equal(isPriorityTier(aPresence('u', { profile: { reviewCount: 4, tomatoPct: 10 } })), true);
  });

  it('the score component is (score + 1) / 2 with ≥ 5 reviews, else 0.5', () => {
    // At the meet point: ETA 1 min, no genre match, reliability 0.5 (fewer than 10 offers).
    const base = 0.45 * (1 - 1 / 60) + 0.15 * 0.5;
    const [rated] = rank([aPresence('rated', { profile: { reviewCount: 6, tomatoPct: 95, score: 0.6 } })]);
    assert.ok(rated && close(rated.score, base + 0.15 * 0.8), String(rated?.score));
    const [fresh] = rank([aPresence('fresh', { profile: { reviewCount: 4, tomatoPct: 100, score: 1 } })]);
    assert.ok(fresh && close(fresh.score, base + 0.15 * 0.5), String(fresh?.score));
  });

  it('a photographer with ≥ 10 offers and cancelled / accepted > 10% is expanded', () => {
    assert.equal(isPriorityTier(aPresence('u', { reliability: { offers: 20, accepted: 10, cancelled: 2 } })), false);
    assert.equal(isPriorityTier(aPresence('u', { reliability: { offers: 20, accepted: 10, cancelled: 1 } })), true);
    // 1 of 5 accepted jobs cancelled is 20%, though only 5% of the offers.
    assert.equal(isPriorityTier(aPresence('u', { reliability: { offers: 20, accepted: 5, cancelled: 1 } })), false);
    assert.equal(isPriorityTier(aPresence('u', { reliability: { offers: 9, accepted: 5, cancelled: 5 } })), true);
  });

  it('reliability is accepted/offers − cancelled/accepted with ≥ 10 offers (clamped), else 0.5', () => {
    const base = 0.45 * (1 - 1 / 60) + 0.15 * 0.5;
    const score = (reliability: PresenceOverrides['reliability']): number => rank([aPresence('u', { reliability })])[0]?.score ?? NaN;
    assert.ok(close(score({ offers: 10, accepted: 8, cancelled: 1 }), base + 0.15 * (0.8 - 1 / 8)));
    assert.ok(close(score({ offers: 10, accepted: 1, cancelled: 3 }), base));
    assert.ok(close(score({ offers: 9, accepted: 0, cancelled: 0 }), base + 0.15 * 0.5));
  });

  it('score orders by ETA when everything else is equal', () => {
    assert.deepEqual(ids(rank([near('far', 2), near('close', 0.5), near('mid', 1.2)])), ['close', 'mid', 'far']);
  });

  it('genre match beats 1 km of distance at equal rating', () => {
    const out = rank([near('nearer', 0.5), near('portraitist', 1.5, { profile: { specialties: ['portrait'] } })]);
    assert.deepEqual(ids(out), ['portraitist', 'nearer']);
    assert.deepEqual(ids(rank([near('nearer', 0.5), near('family', 1.5, { profile: { specialties: ['family'] } })])), ['nearer', 'family']);
  });

  it('ties break by distance then uid (stable)', () => {
    // 1.00 km and 1.05 km both round up to a 5-minute ETA: equal scores.
    const out = rank([near('b', 1.05), near('z', 1), near('a', 1.05)]);
    assert.deepEqual(ids(out), ['z', 'a', 'b']);
    assert.ok(out.every((c) => c.score === out[0]?.score));
  });

  it('reasons: "Chuyên chân dung" first when the genre matches, then "Cách 1,2 km" ("Cách 800 m" below 1 km)', () => {
    const portraitist = aPresence('u', { profile: { specialties: ['couple', 'portrait'] } });
    assert.deepEqual(candidateReasons(portraitist, 'portrait', 1.2), [
      { code: 'genre', text: 'Chuyên chân dung' },
      { code: 'distance', text: 'Cách 1,2 km' },
    ]);
    assert.deepEqual(candidateReasons(portraitist, 'family', 0.8), [{ code: 'distance', text: 'Cách 800 m' }]);
    assert.deepEqual(candidateReasons(portraitist, 'couple', 3), [
      { code: 'genre', text: 'Chuyên cặp đôi' },
      { code: 'distance', text: 'Cách 3 km' },
    ]);
    const words: Record<InstantGenre, string> = {
      portrait: 'Chuyên chân dung', couple: 'Chuyên cặp đôi', family: 'Chuyên gia đình', event: 'Chuyên sự kiện nhỏ', product: 'Chuyên sản phẩm',
    };
    for (const [genre, text] of Object.entries(words) as [InstantGenre, string][]) {
      assert.equal(candidateReasons(aPresence('u', { profile: { specialties: [genre] } }), genre, 1)[0]?.text, text);
    }
    assert.equal(candidateReasons(portraitist, 'family', 0.02)[0]?.text, 'Cách 100 m');
    assert.equal(candidateReasons(portraitist, 'family', 0.96)[0]?.text, 'Cách 1 km');
    const [c] = rank([near('u', 1.2, { profile: { specialties: ['portrait'] } })]);
    assert.deepEqual(c?.reasons.map((r) => r.text), ['Chuyên chân dung', 'Cách 1,2 km']);
  });

  it('candidate photos are at most 3', () => {
    const photos = ['a.jpg', 'b.jpg', 'c.jpg', 'd.jpg'];
    const [c] = rank([near('u', 1, { profile: { photos, name: 'Minh', tomatoPct: 96, reviewCount: 12, completedCount: 30, providerType: 'artist' } })]);
    assert.ok(c);
    assert.deepEqual(c.photos, ['a.jpg', 'b.jpg', 'c.jpg']);
    assert.equal(c.name, 'Minh');
    assert.equal(c.providerType, 'artist');
    assert.equal(c.tomatoPct, 96);
    assert.equal(c.reviewCount, 12);
    assert.equal(c.completedCount, 30);
    assert.equal(c.verified, true);
    assert.equal(c.distanceKm, 1);
    assert.equal(c.etaMinutes, 5);
  });

  it('lists a photographer found by both cell queries once', () => {
    const p = near('twice', 1);
    assert.deepEqual(ids(rank([p, p])), ['twice']);
  });
});
