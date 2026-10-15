/**
 * Pure pricing of a booking's add-ons and the booking total (Decisions 2, 4, 5, 7).
 * The server prices from the provider's catalogue; the app sends only `addonId` + `qty`.
 */

import { ADDON_KINDS, MAX_BOOKING_ADDON_LINES, type ServiceAddon } from './addon.js';
import type { AddonLine, BookingPickup } from './booking.js';
import type { BookingDraftInput } from './create_booking.js';
import { DomainError } from './errors.js';

export interface AddonPick {
  readonly addonId: string;
  readonly qty: number;
}

/**
 * Turns picks into snapshot lines, sorted by kind order then pick order.
 * invalid_argument: too many picks, duplicate id, qty not an integer ≥ 1, per_booking qty ≠ 1.
 * addon_changed: unknown or inactive add-on, qty above the current maxQty.
 * addon_not_applicable: the add-on does not apply to this package.
 */
export function priceAddonLines(
  addons: readonly ServiceAddon[],
  picks: readonly AddonPick[],
  serviceId: string,
): AddonLine[] {
  if (picks.length > MAX_BOOKING_ADDON_LINES) throw new DomainError('invalid_argument');
  const seen = new Set<string>();
  const lines = picks.map((p, i) => {
    if (seen.has(p.addonId) || !Number.isInteger(p.qty) || p.qty < 1) {
      throw new DomainError('invalid_argument');
    }
    seen.add(p.addonId);
    const a = addons.find((x) => x.id === p.addonId);
    if (!a || !a.active) throw new DomainError('addon_changed');
    if (a.serviceIds.length > 0 && !a.serviceIds.includes(serviceId)) {
      throw new DomainError('addon_not_applicable');
    }
    if (a.unit === 'per_booking' && p.qty !== 1) throw new DomainError('invalid_argument');
    if (p.qty > a.maxQty) throw new DomainError('addon_changed'); // Decision 4
    const line: AddonLine = {
      addonId: a.id,
      kind: a.kind,
      name: a.name,
      unit: a.unit,
      unitPrice: a.price,
      qty: p.qty,
      amount: a.price * p.qty,
    };
    return { order: i, line };
  });
  return lines
    .sort((x, y) => ADDON_KINDS.indexOf(x.line.kind) - ADDON_KINDS.indexOf(y.line.kind) || x.order - y.order)
    .map((x) => x.line);
}

/** The amount the customer pays: package price + Σ add-on amounts. */
export const bookingTotal = (s: { readonly price: number }, addons: readonly AddonLine[]): number =>
  addons.reduce((sum, l) => sum + l.amount, s.price);

/** The pickup is kept only with a transport line (Decision 7); a transport line without one is refused. */
export function requirePickup(
  lines: readonly AddonLine[],
  pickup: BookingPickup | undefined,
): BookingPickup | undefined {
  if (!lines.some((l) => l.kind === 'transport')) return undefined;
  if (!pickup) throw new DomainError('pickup_required');
  return pickup;
}

/** The slot fields of the draft: `addons` only when non-empty, `pickup` only when present (Decision 6). */
export function addonDraftFields(
  i: Pick<BookingDraftInput, 'addons' | 'pickup'>,
): { addons?: readonly AddonLine[]; pickup?: BookingPickup } {
  return {
    ...(i.addons && i.addons.length > 0 ? { addons: i.addons } : {}),
    ...(i.pickup ? { pickup: i.pickup } : {}),
  };
}
