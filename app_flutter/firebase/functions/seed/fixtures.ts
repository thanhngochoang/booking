// Deterministic local test data for the Firebase emulators. Test values only: these accounts
// and numbers exist nowhere but in the local emulators. Listed in seed/README.md.

export const SEED_PASSWORD = 'seed-password-1';
export const SEED_CREATED_AT = new Date('2026-09-01T00:00:00Z');

const DAY_MS = 86_400_000;
const HOUR_MS = 3_600_000;

export const LAN = 'seed-customer-lan';
export const MINH = 'seed-customer-minh';
export const AN = 'seed-photographer-an';
export const BINH = 'seed-photographer-binh';

export interface SeedUser {
  readonly uid: string;
  readonly email: string;
  readonly displayName: string;
  readonly role: 'customer' | 'photographer';
}

export const SEED_USERS: readonly SeedUser[] = [
  { uid: LAN, email: 'lan.customer@seed.test', displayName: 'Lan (seed)', role: 'customer' },
  { uid: MINH, email: 'minh.nophone@seed.test', displayName: 'Minh (seed, no phone)', role: 'customer' },
  { uid: AN, email: 'an.verified@seed.test', displayName: 'An Studio (seed)', role: 'photographer' },
  { uid: BINH, email: 'binh.unverified@seed.test', displayName: 'Bình (seed)', role: 'photographer' },
];

/** Private customer numbers (`users/{uid}/private/contact`). Minh has none, for `phone_required`. */
export const SEED_CUSTOMER_PHONES: Readonly<Record<string, string>> = { [LAN]: '+84903000001' };

export interface SeedPhotographer {
  readonly uid: string;
  readonly verified: boolean;
  readonly bio: string;
  readonly city: string;
  readonly radiusKm: number;
  readonly specialties: readonly string[];
  readonly channels: { readonly call: boolean; readonly zalo: boolean; readonly whatsapp: boolean; readonly acceptInquiries: boolean };
  readonly numbers: { readonly phone: string; readonly zaloPhone?: string; readonly whatsappPhone?: string };
}

export const SEED_PHOTOGRAPHERS: readonly SeedPhotographer[] = [
  {
    uid: AN,
    verified: true,
    bio: 'Chân dung và cưới, ánh sáng tự nhiên.',
    city: 'Hà Nội',
    radiusKm: 20,
    specialties: ['portrait', 'wedding'],
    channels: { call: true, zalo: true, whatsapp: true, acceptInquiries: true },
    numbers: { phone: '+84912000001', zaloPhone: '+84912000002', whatsappPhone: '+14155550101' },
  },
  {
    uid: BINH,
    verified: false,
    bio: 'Ảnh gia đình cuối tuần.',
    city: 'Đà Nẵng',
    radiusKm: 15,
    specialties: ['family'],
    channels: { call: true, zalo: false, whatsapp: false, acceptInquiries: true },
    numbers: { phone: '+84987000001' },
  },
];

export interface SeedService {
  readonly id: string;
  readonly photographerId: string;
  readonly name: string;
  /** Integer VND. */
  readonly price: number;
  readonly durationMinutes: number;
}

export const SEED_SERVICES: readonly SeedService[] = [
  { id: 'seed-service-portrait', photographerId: AN, name: 'Chân dung 2 giờ', price: 1_500_000, durationMinutes: 120 },
  { id: 'seed-service-family', photographerId: BINH, name: 'Gia đình 90 phút', price: 1_200_000, durationMinutes: 90 },
];

export interface SeedBooking {
  readonly id: string;
  readonly customerId: string;
  readonly photographerId: string;
  readonly serviceId: string;
  readonly status: string;
  readonly date: string;
  readonly start: string;
  readonly end: string;
  readonly place: string;
  /** Days between completion and seeding; null when not completed. */
  readonly completedDaysAgo: number | null;
}

export const SEED_BOOKINGS: readonly SeedBooking[] = [
  { id: 'seed-booking-accepted', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'accepted', date: '2026-10-20', start: '08:00', end: '10:00', place: 'Hồ Hoàn Kiếm, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-requested-binh', customerId: LAN, photographerId: BINH, serviceId: 'seed-service-family', status: 'requested', date: '2026-10-25', start: '16:00', end: '17:30', place: 'Biển Mỹ Khê, Đà Nẵng', completedDaysAgo: null },
  { id: 'seed-booking-cancelled', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'cancelled', date: '2026-10-22', start: '08:00', end: '10:00', place: 'Văn Miếu, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-completed-recent', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'completed', date: '2026-09-27', start: '08:00', end: '10:00', place: 'Hồ Tây, Hà Nội', completedDaysAgo: 3 },
  { id: 'seed-booking-completed-old', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'completed', date: '2026-08-20', start: '08:00', end: '10:00', place: 'Phố cổ, Hà Nội', completedDaysAgo: 40 },
];

export interface SeedDocument {
  readonly path: string;
  readonly data: Record<string, unknown>;
}

const TIMELINE: Readonly<Record<string, readonly string[]>> = {
  requested: ['requested'],
  accepted: ['requested', 'accepted'],
  cancelled: ['requested', 'accepted', 'cancelled'],
  completed: ['requested', 'accepted', 'upcoming', 'completed'],
};

function bookingData(b: SeedBooking, now: Date): Record<string, unknown> {
  const service = SEED_SERVICES.find((s) => s.id === b.serviceId);
  if (service === undefined) throw new Error(`unknown seed service ${b.serviceId}`);
  const deposit = Math.floor(service.price * 0.3);
  const steps = TIMELINE[b.status] ?? [b.status];
  const last = b.completedDaysAgo === null
    ? new Date(SEED_CREATED_AT.getTime() + (steps.length - 1) * HOUR_MS)
    : new Date(now.getTime() - b.completedDaysAgo * DAY_MS);
  const timeline = steps.map((status, i) => ({ status, at: new Date(last.getTime() - (steps.length - 1 - i) * HOUR_MS) }));
  const createdAt = timeline[0]?.at ?? last;
  return {
    customerId: b.customerId,
    photographerId: b.photographerId,
    serviceId: b.serviceId,
    service: { name: service.name, price: service.price, durationMinutes: service.durationMinutes },
    date: b.date,
    start: b.start,
    end: b.end,
    location: { name: b.place },
    note: 'Seed booking',
    status: b.status,
    deposit: { amount: deposit, provider: 'momo', paymentId: b.id.replace('seed-booking-', 'seed-payment-'), paidAt: createdAt },
    remaining: service.price - deposit,
    timeline,
    createdAt,
    updatedAt: last,
  };
}

/** Every Firestore document of the seed, in write order. Pure: same `now`, same documents. */
export function seedDocuments(now: Date): SeedDocument[] {
  const at = SEED_CREATED_AT;
  const docs: SeedDocument[] = [];
  for (const u of SEED_USERS) {
    docs.push({ path: `users/${u.uid}`, data: { displayName: u.displayName, role: u.role, createdAt: at, updatedAt: at } });
  }
  for (const [uid, phone] of Object.entries(SEED_CUSTOMER_PHONES)) {
    docs.push({
      path: `users/${uid}/private/contact`,
      data: { phone, phoneVerified: false, allowZalo: true, allowWhatsApp: false, updatedAt: at },
    });
  }
  for (const p of SEED_PHOTOGRAPHERS) {
    docs.push({
      path: `photographers/${p.uid}`,
      data: {
        bio: p.bio,
        specialties: [...p.specialties],
        serviceArea: { city: p.city, radiusKm: p.radiusKm },
        contactChannels: { ...p.channels },
        onboardingComplete: true,
        verified: p.verified,
        ...(p.verified ? { verifiedAt: at } : {}),
        createdAt: at,
        updatedAt: at,
      },
    });
    docs.push({ path: `photographers/${p.uid}/private/contact`, data: { ...p.numbers, updatedAt: at } });
  }
  for (const s of SEED_SERVICES) {
    docs.push({
      path: `photographers/${s.photographerId}/services/${s.id}`,
      data: { name: s.name, price: s.price, currency: 'VND', durationMinutes: s.durationMinutes, active: true, createdAt: at },
    });
  }
  for (const b of SEED_BOOKINGS) docs.push({ path: `bookings/${b.id}`, data: bookingData(b, now) });
  return docs;
}
