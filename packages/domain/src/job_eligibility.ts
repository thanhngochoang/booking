import { distanceKm } from './geo.js';
import { cityKeyOf } from './job.js';
import type { JobArea, JobRecord } from './job.js';
import type { ProviderType } from './provider_type.js';
import type { OrderEligibilityFields } from './provider_orders.js';
import { TOMATO_PCT_MIN_REVIEWS } from './review.js';

export interface JobProviderProfile {
  readonly uid: string;
  readonly role: string | null;
  readonly onboardingComplete: boolean;
  readonly acceptingOrdersFields: OrderEligibilityFields;
  readonly providerType: ProviderType;
  readonly specialties: readonly string[];
  readonly serviceArea: { city: string; radiusKm: number; center: { lat: number; lng: number } | null } | null;
  readonly startingPrice: number | null;
  readonly tomatoPct: number;
  readonly score: number;
  readonly reviewCount: number;
  readonly completedCount: number;
  readonly approvedAwardCount: number;
  readonly verified: boolean;
  readonly name: string;
  readonly avatarUrl: string | null;
  readonly studioDistrict: string | null;
}

export function jobInServiceArea(area: JobArea, serviceArea: JobProviderProfile['serviceArea']): boolean {
  if (!serviceArea) return false;
  if (serviceArea.center) {
    return distanceKm(area, serviceArea.center) <= serviceArea.radiusKm;
  }
  return cityKeyOf(serviceArea.city) === area.cityKey;
}

export function providerTypeAllowed(allowed: 'all' | 'artist' | 'studio', type: ProviderType): boolean {
  if (allowed === 'all') return true;
  if (allowed === 'artist') return type === 'artist';
  if (allowed === 'studio') return type === 'studio';
  return false;
}

function clamp01(x: number): number {
  return Math.max(0, Math.min(1, x));
}

export function jobFit(job: JobRecord, p: JobProviderProfile, day: 'free' | 'pending' | 'busy'): number {
  const spec = p.specialties[0] === job.specialtyId ? 1 : p.specialties.includes(job.specialtyId) ? 0.8 : 0;
  const area = p.serviceArea?.center
    ? Math.max(0, 1 - distanceKm(job.area, p.serviceArea.center) / Math.max(1, p.serviceArea.radiusKm))
    : p.serviceArea && cityKeyOf(p.serviceArea.city) === job.area.cityKey
      ? 0.6
      : 0;
  const budget =
    !job.budget || p.startingPrice === null
      ? 0.7
      : p.startingPrice <= job.budget.max
        ? 1
        : Math.max(0, 1 - (p.startingPrice - job.budget.max) / job.budget.max);
  const free = day === 'free' ? 1 : day === 'pending' ? 0.5 : 0;
  const rating = p.reviewCount >= TOMATO_PCT_MIN_REVIEWS ? clamp01((p.score + 1) / 2) : 0.5;
  const quality = 0.5 * clamp01(p.completedCount / 20) + 0.5 * rating;
  return Math.round(100 * (0.35 * spec + 0.2 * area + 0.2 * free + 0.15 * budget + 0.1 * quality));
}
