import { encodeGeohash } from '../../src/event.js';
import type {
  InstantConfig,
  InstantPresence,
  InstantProfile,
  InstantReliability,
  InstantRequest,
} from '../../src/instant.js';

/** Fixed clock of every instant test: 2026-10-22 15:00 in Vietnam. */
export const T0 = new Date('2026-10-22T08:00:00.000Z');
export const SEC = 1000;
export const MIN = 60 * SEC;
export const HOUR = 60 * MIN;
export const at = (ms: number): Date => new Date(T0.getTime() + ms);

/** Công viên Tao Đàn, Quận 1 (the mock's meet point). */
export const TAO_DAN = { lat: 10.7746, lng: 106.6924 } as const;
/** Chợ Bến Thành. */
export const BEN_THANH = { lat: 10.7725, lng: 106.698 } as const;

/** A point `km` north of `from` (1° of latitude = 111.195 km with R = 6371.0088). */
export const north = (from: { lat: number; lng: number }, km: number): { lat: number; lng: number } => ({
  lat: from.lat + km / 111.19508,
  lng: from.lng,
});

/** The emulator seed of `instant_config/current` (plan Task 4). */
export function aConfig(overrides: Partial<InstantConfig> = {}): InstantConfig {
  return {
    enabled: true,
    priceListVersion: 1,
    platformFeeBp: 0,
    instantArrivedCancelPhotographerPercent: 50,
    packages: [
      { code: 'p30', durationMin: 30, photos: 15, priceVnd: 390_000 },
      { code: 'p60', durationMin: 60, photos: 30, priceVnd: 690_000 },
      { code: 'p120', durationMin: 120, photos: 60, priceVnd: 1_190_000 },
    ],
    cities: [
      { id: 'hcm', name: 'TP.HCM', south: 10.35, west: 106.36, north: 11.17, east: 107.03, surgeBp: 10_000 },
      { id: 'hn', name: 'Hà Nội', south: 20.56, west: 105.28, north: 21.39, east: 106.02, surgeBp: 10_000 },
      { id: 'dn', name: 'Đà Nẵng', south: 15.92, west: 107.82, north: 16.2, east: 108.33, surgeBp: 10_000 },
    ],
    areas: [
      { name: 'Quận 1, TP.HCM', lat: 10.7769, lng: 106.7009 },
      { name: 'Quận 3, TP.HCM', lat: 10.784, lng: 106.6842 },
      { name: 'Quận 7, TP.HCM', lat: 10.734, lng: 106.7219 },
      { name: 'Bình Thạnh, TP.HCM', lat: 10.8106, lng: 106.7091 },
      { name: 'Thủ Đức, TP.HCM', lat: 10.8494, lng: 106.7537 },
      { name: 'Hoàn Kiếm, Hà Nội', lat: 21.0285, lng: 105.8542 },
      { name: 'Ba Đình, Hà Nội', lat: 21.034, lng: 105.819 },
      { name: 'Cầu Giấy, Hà Nội', lat: 21.0333, lng: 105.794 },
      { name: 'Hải Châu, Đà Nẵng', lat: 16.0471, lng: 108.2208 },
      { name: 'Huế', lat: 16.4637, lng: 107.5909 },
      { name: 'Đà Lạt', lat: 11.9404, lng: 108.4583 },
      { name: 'Nha Trang', lat: 12.2388, lng: 109.1967 },
    ],
    ...overrides,
  };
}

/** A fresh request of Lan at Tao Đàn: `choosing`, round 1, nothing sent, unpaid. */
export function aRequest(overrides: Partial<InstantRequest> = {}): InstantRequest {
  return {
    id: 'ir_01',
    customerId: 'c-lan',
    customerName: 'Lan Anh',
    customerAvatarUrl: null,
    status: 'choosing',
    active: true,
    packageCode: 'p60',
    durationMin: 60,
    photos: 30,
    genre: 'portrait',
    note: '',
    cityId: 'hcm',
    meetPoint: { ...TAO_DAN, name: 'Cổng Trương Định, Công viên Tao Đàn' },
    areaLabel: 'Quận 1, TP.HCM',
    amountVnd: 690_000,
    earningVnd: 690_000,
    priceListVersion: 1,
    platformFeeBp: 0,
    arrivedCancelPhotographerPercent: 50,
    committedAt: null,
    payMethod: null,
    provider: null,
    paymentId: null,
    paidAt: null,
    paymentDeadlineAt: null,
    refundId: null,
    refundStatus: null,
    round: 1,
    invitedTotal: 0,
    roundsWithInvites: 0,
    candidates: [],
    offers: [],
    excludedIds: [],
    pendingInviteIds: [],
    roundEnded: false,
    photographerId: null,
    photographer: null,
    chatId: null,
    etaMinutes: null,
    assignedAt: null,
    freeCancelUntil: null,
    lateDeadlineAt: null,
    startedRouteAt: null,
    arrivedAt: null,
    forcedArrivalAccuracyM: null,
    startedAt: null,
    shootEndsAt: null,
    finishedAt: null,
    completedAt: null,
    cancelledAt: null,
    cancelledBy: null,
    cancelRule: null,
    refundPercent: null,
    feeVnd: null,
    searchDeadlineAt: null,
    lastActivityAt: T0,
    nextDeadlineAt: null,
    createdAt: T0,
    updatedAt: T0,
    version: 1,
    ...overrides,
  };
}

export type PresenceOverrides = Partial<Omit<InstantPresence, 'uid' | 'profile' | 'reliability'>> & {
  readonly profile?: Partial<InstantProfile>;
  readonly reliability?: Partial<InstantReliability>;
};

/** An online, fresh, verified photographer at Tao Đàn who accepted price list 1 and has no history. */
export function aPresence(uid: string, overrides: PresenceOverrides = {}): InstantPresence {
  const { profile, reliability, ...rest } = overrides;
  const lat = rest.lat === undefined ? TAO_DAN.lat : rest.lat;
  const lng = rest.lng === undefined ? TAO_DAN.lng : rest.lng;
  return {
    uid,
    online: true,
    helpReady: false,
    priceListVersion: 1,
    cityId: 'hcm',
    lat,
    lng,
    accuracyM: 20,
    geohash5: lat === null || lng === null ? null : encodeGeohash(lat, lng, 5),
    geohash4: lat === null || lng === null ? null : encodeGeohash(lat, lng, 4),
    heartbeatAt: T0,
    activeRequestId: null,
    pendingOffers: [],
    updatedAt: T0,
    ...rest,
    profile: {
      name: `Nhiếp ảnh gia ${uid}`,
      avatarUrl: null,
      verified: true,
      providerType: 'individual',
      tomatoPct: 0,
      score: 0,
      reviewCount: 0,
      completedCount: 0,
      specialties: [],
      photos: [],
      ...profile,
    },
    reliability: { offers: 0, accepted: 0, declined: 0, expired: 0, cancelled: 0, late: 0, noShow: 0, ...reliability },
  };
}
