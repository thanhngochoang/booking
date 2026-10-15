import { graphemeCount } from './booking_requests.js';
import { findContactLeak } from './contact_filter.js';
import { DomainError } from './errors.js';
import { isId } from './ids.js';

export const ADDON_KINDS = ['makeup', 'retouch', 'transport', 'outfit', 'other'] as const;
export type AddonKind = (typeof ADDON_KINDS)[number];
export const ADDON_UNITS = ['per_booking', 'per_person', 'per_item'] as const;
export type AddonUnit = (typeof ADDON_UNITS)[number];
export const MAX_ACTIVE_ADDONS = 10;
export const ADDON_PRICE_MIN = 10_000;
export const ADDON_PRICE_MAX = 50_000_000;
export const ADDON_MAX_QTY = 10;
export const ADDON_NAME_MIN = 2;
export const ADDON_NAME_MAX = 60;
export const ADDON_DESCRIPTION_MAX = 200;
export const MAX_ADDON_SERVICE_IDS = 20;
export const MAX_BOOKING_ADDON_LINES = 10;

export interface ServiceAddon {
  readonly id: string;
  readonly providerId: string;
  readonly kind: AddonKind;
  readonly name: string;
  readonly description?: string;
  readonly price: number;
  readonly unit: AddonUnit;
  readonly maxQty: number;
  /** Packages the add-on applies to; `[]` = every package. */
  readonly serviceIds: readonly string[];
  readonly active: boolean;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export interface AddonInput {
  readonly addonId?: string;
  readonly kind: AddonKind;
  readonly name: string;
  readonly description?: string;
  readonly price: number;
  readonly unit: AddonUnit;
  readonly maxQty: number;
  readonly serviceIds: readonly string[];
  readonly active: boolean;
}

export const isAddonKind = (v: unknown): v is AddonKind =>
  typeof v === 'string' && (ADDON_KINDS as readonly string[]).includes(v);

export const isAddonUnit = (v: unknown): v is AddonUnit =>
  typeof v === 'string' && (ADDON_UNITS as readonly string[]).includes(v);

const bad = (field: string): DomainError => new DomainError('invalid_argument', field);

function cleanText(v: unknown, field: 'name' | 'description'): string {
  if (typeof v !== 'string') throw bad(field);
  return v.normalize('NFC').trim().replace(/\s+/g, ' ');
}

/**
 * Trims, checks every limit, runs findContactLeak on name and description; `per_booking` stores
 * maxQty 1. Throws DomainError('invalid_argument', field) or DomainError('contact_leak', field).
 */
export function validateAddonInput(raw: unknown): AddonInput {
  if (typeof raw !== 'object' || raw === null) throw new DomainError('invalid_argument');
  const r = raw as Record<string, unknown>;

  if (r.addonId !== undefined && !isId(r.addonId)) throw bad('addonId');
  if (!isAddonKind(r.kind)) throw bad('kind');
  if (!isAddonUnit(r.unit)) throw bad('unit');

  const name = cleanText(r.name, 'name');
  const nameLen = graphemeCount(name);
  if (nameLen < ADDON_NAME_MIN || nameLen > ADDON_NAME_MAX) throw bad('name');

  let description: string | undefined;
  if (r.description !== undefined && r.description !== null) {
    const d = cleanText(r.description, 'description');
    if (graphemeCount(d) > ADDON_DESCRIPTION_MAX) throw bad('description');
    if (d !== '') description = d;
  }

  if (findContactLeak(name) !== null) throw new DomainError('contact_leak', 'name');
  if (description !== undefined && findContactLeak(description) !== null) {
    throw new DomainError('contact_leak', 'description');
  }

  const { price, maxQty } = r;
  if (
    typeof price !== 'number' ||
    !Number.isInteger(price) ||
    price < ADDON_PRICE_MIN ||
    price > ADDON_PRICE_MAX
  ) {
    throw bad('price');
  }
  let qty = 1;
  if (r.unit !== 'per_booking') {
    if (
      typeof maxQty !== 'number' ||
      !Number.isInteger(maxQty) ||
      maxQty < 1 ||
      maxQty > ADDON_MAX_QTY
    ) {
      throw bad('maxQty');
    }
    qty = maxQty;
  }

  const sids = r.serviceIds;
  if (!Array.isArray(sids) || sids.length > MAX_ADDON_SERVICE_IDS) throw bad('serviceIds');
  if (!sids.every(isId) || new Set(sids).size !== sids.length) throw bad('serviceIds');

  if (typeof r.active !== 'boolean') throw bad('active');

  return {
    ...(r.addonId === undefined ? {} : { addonId: r.addonId }),
    kind: r.kind,
    name,
    ...(description === undefined ? {} : { description }),
    price,
    unit: r.unit,
    maxQty: qty,
    serviceIds: sids as string[],
    active: r.active,
  };
}
