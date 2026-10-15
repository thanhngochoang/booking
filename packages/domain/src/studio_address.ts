import { DomainError } from './errors.js';
import type { ProviderDeps, StudioAddress } from './provider_ports.js';

const LAT_RANGE = [8, 24] as const;
const LNG_RANGE = [102, 110] as const;

function text(v: unknown, min: number, max: number): string {
  if (typeof v !== 'string') throw new DomainError('invalid_argument');
  const s = v.trim();
  if (s.length < min || s.length > max) throw new DomainError('invalid_argument');
  return s;
}

function coord(v: unknown, range: readonly [number, number]): number | null {
  if (v === undefined || v === null) return null;
  if (typeof v !== 'number' || !Number.isFinite(v) || v < range[0] || v > range[1]) {
    throw new DomainError('invalid_argument');
  }
  return v;
}

/** Trims strings; empty ward → null; lat/lng both or neither, inside Vietnam. */
export function validateStudioAddress(raw: unknown): StudioAddress {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;

  const line = text(r.line, 5, 120);
  const district = text(r.district, 2, 60);
  const city = text(r.city, 2, 60);

  let ward: string | null = null;
  if (r.ward !== undefined && r.ward !== null) {
    ward = text(r.ward, 0, 60);
    if (ward === '') ward = null;
  }

  const lat = coord(r.lat, LAT_RANGE);
  const lng = coord(r.lng, LNG_RANGE);
  if ((lat === null) !== (lng === null)) throw new DomainError('invalid_argument');

  return { line, ward, district, city, lat, lng };
}

/** Only a studio keeps an address; the district and city also go public. */
export async function setStudioAddress(
  deps: ProviderDeps,
  callerId: string,
  raw: unknown,
): Promise<StudioAddress> {
  const address = validateStudioAddress(raw);

  await deps.providers.runTransaction(async (tx) => {
    const p = await tx.getProfile(callerId);
    if (p === null) throw new DomainError('not_found');
    if (p.providerType !== 'studio') throw new DomainError('not_eligible');
    tx.setStudioAddress(callerId, address, deps.clock.now());
  });

  return address;
}
