import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { ServiceAddon } from '../src/addon.js';
import { addonDraftFields, bookingTotal, priceAddonLines, requirePickup } from '../src/addon_pricing.js';
import { computeDeposit } from '../src/booking_policy.js';
import { buildBookingDraft } from '../src/create_booking.js';
import { DomainError } from '../src/errors.js';
import type { AddonLine } from '../src/booking.js';

const T = '2026-10-01T00:00:00.000Z';
const addon = (id: string, over: Partial<ServiceAddon>): ServiceAddon => ({
  id,
  providerId: 'p1',
  kind: 'other',
  name: id,
  price: 100_000,
  unit: 'per_booking',
  maxQty: 1,
  serviceIds: [],
  active: true,
  createdAt: T,
  updatedAt: T,
  ...over,
});

const CATALOGUE: ServiceAddon[] = [
  addon('makeup', { kind: 'makeup', unit: 'per_person', price: 800_000, maxQty: 4 }),
  addon('retouch', { kind: 'retouch', unit: 'per_item', price: 20_000, maxQty: 10 }),
  addon('transport', { kind: 'transport', unit: 'per_booking', price: 300_000, serviceIds: ['svc-portrait'] }),
  addon('outfit', { kind: 'outfit', unit: 'per_item', price: 150_000, maxQty: 3, active: false }),
];

const code = (e: unknown, c: string): boolean => e instanceof DomainError && e.code === c;
const refuses = (fn: () => unknown, c: string): void => assert.throws(fn, (e) => code(e, c));
const price = (picks: { addonId: string; qty: number }[], serviceId = 'svc-portrait'): AddonLine[] =>
  priceAddonLines(CATALOGUE, picks, serviceId);

describe('priceAddonLines', () => {
  it('per_booking line: qty 1, amount = price', () => {
    const [l] = price([{ addonId: 'transport', qty: 1 }]);
    assert.equal(l?.qty, 1);
    assert.equal(l?.amount, 300_000);
    assert.deepEqual(l, {
      addonId: 'transport', kind: 'transport', name: 'transport', unit: 'per_booking',
      unitPrice: 300_000, qty: 1, amount: 300_000,
    });
  });

  it('per_person 2 → 1.600.000; per_item 10 → 200.000', () => {
    assert.equal(price([{ addonId: 'makeup', qty: 2 }])[0]?.amount, 1_600_000);
    assert.equal(price([{ addonId: 'retouch', qty: 10 }])[0]?.amount, 200_000);
  });

  it('lines are sorted by kind order then pick order', () => {
    const lines = price([{ addonId: 'transport', qty: 1 }, { addonId: 'makeup', qty: 1 }]);
    assert.deepEqual(lines.map((l) => l.addonId), ['makeup', 'transport']);
  });

  it('an unknown addonId is addon_changed', () => {
    refuses(() => price([{ addonId: 'nope', qty: 1 }]), 'addon_changed');
  });
  it('an inactive add-on is addon_changed', () => {
    refuses(() => price([{ addonId: 'outfit', qty: 1 }]), 'addon_changed');
  });
  it('qty above the current maxQty is addon_changed', () => {
    refuses(() => price([{ addonId: 'makeup', qty: 5 }]), 'addon_changed');
  });

  it('transport on svc-family is addon_not_applicable; serviceIds [] applies to every package', () => {
    refuses(() => price([{ addonId: 'transport', qty: 1 }], 'svc-family'), 'addon_not_applicable');
    assert.equal(price([{ addonId: 'makeup', qty: 1 }], 'svc-family').length, 1);
  });

  it('qty 0, -1, 1.5 is invalid_argument', () => {
    for (const qty of [0, -1, 1.5]) refuses(() => price([{ addonId: 'makeup', qty }]), 'invalid_argument');
  });
  it('per_booking with qty 2 is invalid_argument', () => {
    refuses(() => price([{ addonId: 'transport', qty: 2 }]), 'invalid_argument');
  });
  it('a duplicated addonId is invalid_argument', () => {
    refuses(() => price([{ addonId: 'makeup', qty: 1 }, { addonId: 'makeup', qty: 1 }]), 'invalid_argument');
  });
  it('11 picks are invalid_argument; [] picks give []', () => {
    const many = Array.from({ length: 11 }, (_, i) => ({ addonId: `x${i}`, qty: 1 }));
    refuses(() => price(many), 'invalid_argument');
    assert.deepEqual(price([]), []);
  });
});

describe('bookingTotal', () => {
  it('= price + Σ amount, and = price without lines', () => {
    const lines = price([{ addonId: 'makeup', qty: 2 }, { addonId: 'retouch', qty: 10 }]);
    assert.equal(bookingTotal({ price: 1_500_000 }, lines), 1_500_000 + 1_600_000 + 200_000);
    assert.equal(bookingTotal({ price: 1_500_000 }, []), 1_500_000);
  });

  it('total invariant holds for 200 random baskets', () => {
    let seed = 20261008;
    const rnd = (): number => {
      seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
      return seed / 2 ** 32;
    };
    const int = (lo: number, hi: number): number => lo + Math.floor(rnd() * (hi - lo + 1));
    for (let n = 0; n < 200; n++) {
      const servicePrice = int(100_000, 50_000_000);
      const picks = CATALOGUE.filter((a) => a.active && rnd() < 0.7).map((a) => ({
        addonId: a.id,
        qty: a.unit === 'per_booking' ? 1 : int(1, a.maxQty),
      }));
      const lines = price(picks);
      const total = bookingTotal({ price: servicePrice }, lines);
      assert.equal(total, servicePrice + lines.reduce((s, l) => s + l.amount, 0));
      const { deposit, remaining } = computeDeposit(total);
      assert.equal(deposit + remaining, total);
      const draft = buildBookingDraft({
        id: 'b1', customerId: 'c1', photographerId: 'p1',
        service: { id: 'svc-portrait', photographerId: 'p1', name: 'Gói', price: servicePrice, durationMinutes: 60, active: true },
        day: '2026-10-15', start: '14:00', place: { name: 'Nhà thờ Lớn' }, now: new Date('2026-10-10T10:00:00.000Z'),
        addons: lines,
      });
      assert.equal(draft.deposit + draft.remaining, total);
      assert.equal(draft.deposit, total);
    }
  });
});

describe('requirePickup', () => {
  const transportLine = price([{ addonId: 'transport', qty: 1 }]);
  const makeupLine = price([{ addonId: 'makeup', qty: 1 }]);
  const pickup = { name: '12 Lê Lợi, Quận 1' };

  it('transport without pickup is pickup_required', () => {
    refuses(() => requirePickup(transportLine, undefined), 'pickup_required');
  });
  it('transport with pickup returns it', () => {
    assert.deepEqual(requirePickup(transportLine, pickup), pickup);
  });
  it('pickup is dropped when no transport line exists', () => {
    assert.equal(requirePickup(makeupLine, pickup), undefined);
    assert.equal(requirePickup([], pickup), undefined);
  });
});

describe('addonDraftFields', () => {
  it('returns {} without add-ons and pickup', () => {
    assert.deepEqual(addonDraftFields({}), {});
    assert.deepEqual(addonDraftFields({ addons: [] }), {});
  });
});
