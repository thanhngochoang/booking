// Deterministic local test data for the Firebase emulators. Test values only: these accounts
// and numbers exist nowhere but in the local emulators. Listed in seed/README.md.

import {
  BADGE_CATALOG,
  acceptsOrders,
  addVerdict,
  intensityOf,
  mentionsPunctual,
  reviewDocId,
  NOTIFICATION_TYPES,
  accountLast4,
  computeDeposit,
  encodeGeohash,
  formatVnDate,
  hashtagBase,
  hashtagKeyOf,
  earningItemOf,
  providerTypeOf,
  payoutLineOf,
  DEFAULT_PAYOUT_POLICY,
  renderNotification,
  summarizeEarnings,
  titleKeyOf,
  transferCodeFor,
  PAYMENT_EXPIRY_MINUTES,
  afterMessage,
  chatIdFor,
  chatPreview,
  type Chat,
  type EarningItem,
  type Message,
  type EventRecord,
  type RegistrationDoc,
  type NotificationContent,
  type NotificationType,
  type Payment,
  type Payout,
  type PayoutAccount,
  type PhotographerStatsPatch,
  type ReviewReason,
  type Verdict,
} from '@photobooking/domain';
import { encryptSyncForSeed } from '../src/infra/account_cipher.js';
import { toFirestoreChat, toFirestoreMessage } from '../src/infra/chat_firestore.js';
import { eventToFirestore, groupChatToFirestore, registrationToFirestore } from '../src/infra/event_firestore.js';
import { earningItemToFirestore } from '../src/infra/earnings_firestore.js';
import { accountToFirestore, accountViewToFirestore, payoutToFirestore } from '../src/infra/payout_firestore.js';
import { emulatorPayoutKey } from './emulator_key.js';

export const SEED_PASSWORD = 'seed-password-1';
export const SEED_CREATED_AT = new Date('2026-09-01T00:00:00Z');

const DAY_MS = 86_400_000;
const HOUR_MS = 3_600_000;

export const LAN = 'seed-customer-lan';
export const MINH = 'seed-customer-minh';
export const AN = 'seed-photographer-an';
export const BINH = 'seed-photographer-binh';
export const CUC = 'seed-photographer-cuc';
export const DUNG = 'seed-photographer-dung';
/** Staff account with the custom claim `staffRole: 'admin'` (reviews awards; see `applySeed`). */
export const ADMIN = 'seed-staff-admin';

export interface SeedUser {
  readonly uid: string;
  readonly email: string;
  readonly displayName: string;
  readonly role: 'customer' | 'photographer';
  /** Custom auth claim `staffRole`, set by `applySeed`. */
  readonly staffRole?: 'admin';
}

export const SEED_USERS: readonly SeedUser[] = [
  { uid: LAN, email: 'lan.customer@seed.test', displayName: 'Lan (seed)', role: 'customer' },
  { uid: MINH, email: 'minh.nophone@seed.test', displayName: 'Minh (seed, no phone)', role: 'customer' },
  { uid: AN, email: 'an.verified@seed.test', displayName: 'An Studio (seed)', role: 'photographer' },
  { uid: BINH, email: 'binh.unverified@seed.test', displayName: 'Bình (seed)', role: 'photographer' },
  { uid: CUC, email: 'cuc.studio@seed.test', displayName: 'Cúc Studio (seed)', role: 'photographer' },
  { uid: DUNG, email: 'dung.artist@seed.test', displayName: 'Dũng (seed, nghệ sĩ)', role: 'photographer' },
  { uid: ADMIN, email: 'admin.staff@seed.test', displayName: 'Admin (seed, nhân viên)', role: 'customer', staffRole: 'admin' },
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
  /** Missing = individual. */
  readonly providerType?: 'studio' | 'artist';
  /** Studio only: private `studioAddress` doc; district and city also go on the public doc. */
  readonly studioAddress?: { readonly line: string; readonly ward: string; readonly district: string; readonly city: string; readonly lat: number; readonly lng: number };
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
  {
    uid: CUC,
    verified: true,
    bio: 'Studio ảnh cưới và gia đình, có phòng chụp.',
    city: 'TP.HCM',
    radiusKm: 30,
    specialties: ['wedding', 'family'],
    channels: { call: true, zalo: false, whatsapp: false, acceptInquiries: true },
    numbers: { phone: '+84938000001' },
    providerType: 'studio',
    studioAddress: { line: '12 Lê Lợi', ward: 'Bến Nghé', district: 'Quận 1', city: 'TP.HCM', lat: 10.7769, lng: 106.7009 },
  },
  {
    uid: DUNG,
    verified: true,
    bio: 'Nhiếp ảnh nghệ thuật, nhiều giải thưởng.',
    city: 'Huế',
    radiusKm: 25,
    specialties: ['portrait'],
    channels: { call: true, zalo: false, whatsapp: false, acceptInquiries: true },
    numbers: { phone: '+84905000001' },
    providerType: 'artist',
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
  /** The deposit is held back by a dispute; the text is what the customer wrote. */
  readonly dispute?: { readonly reason: string };
}

export const SEED_BOOKINGS: readonly SeedBooking[] = [
  { id: 'seed-booking-accepted', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'accepted', date: '2026-10-20', start: '08:00', end: '10:00', place: 'Hồ Hoàn Kiếm, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-upcoming', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'upcoming', date: '2026-10-10', start: '08:00', end: '10:00', place: 'Công viên Thống Nhất, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-requested-binh', customerId: LAN, photographerId: BINH, serviceId: 'seed-service-family', status: 'requested', date: '2026-10-25', start: '16:00', end: '17:30', place: 'Biển Mỹ Khê, Đà Nẵng', completedDaysAgo: null },
  { id: 'seed-booking-cancelled', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'cancelled', date: '2026-10-22', start: '08:00', end: '10:00', place: 'Văn Miếu, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-completed-recent', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'completed', date: '2026-09-27', start: '08:00', end: '10:00', place: 'Hồ Tây, Hà Nội', completedDaysAgo: 3 },
  { id: 'seed-booking-completed-old', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'completed', date: '2026-08-20', start: '08:00', end: '10:00', place: 'Phố cổ, Hà Nội', completedDaysAgo: 40 },
  // Completed 10 hours before seeding, then disputed by Lan: the money stays on hold (S06.05 row with a reason).
  { id: 'seed-booking-disputed', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'completed', date: '2026-09-29', start: '08:00', end: '10:00', place: 'Hồ Gươm, Hà Nội', completedDaysAgo: 10 / 24, dispute: { reason: 'Ảnh giao thiếu so với gói' } },
];

/** An's payout account (VCB). Test value; the number is stored encrypted with the emulator key. */
export const SEED_AN_ACCOUNT = { id: 'seed-account-an-1', bankCode: 'VCB', number: '0123456789', holderName: 'NGUYEN VAN AN' } as const;
export const SEED_PAYOUT_AN = 'seed-payout-an-1';
/** An's verified legal name (`users/{uid}/private/identity.legalName`; test value). */
export const SEED_AN_LEGAL_NAME = 'Nguyễn Văn An';
/** The booking whose payment the seeded payout paid out. */
export const SEED_PAID_OUT_BOOKING = 'seed-booking-completed-old';

export interface SeedPost {
  readonly id: string;
  readonly photographerId: string;
  readonly images: number;
  readonly caption: string;
  /** Album the post sits in and its 1-based place there; null = timeline only. */
  readonly album: { readonly id: string; readonly position: number } | null;
}

export const SEED_ALBUM_FAMILY = 'seed-album-an-family';
export const SEED_ALBUM_STREET = 'seed-album-an-street';

/** An's `work` posts: two in "Gia đình", one in "Đường phố", two only on the timeline. */
export const SEED_POSTS: readonly SeedPost[] = [
  { id: 'seed-post-an-1', photographerId: AN, images: 3, caption: 'Buổi chiều ở Hồ Tây', album: { id: SEED_ALBUM_FAMILY, position: 1 } },
  { id: 'seed-post-an-2', photographerId: AN, images: 2, caption: 'Gia đình nhỏ', album: { id: SEED_ALBUM_FAMILY, position: 2 } },
  { id: 'seed-post-an-3', photographerId: AN, images: 1, caption: 'Phố cổ sớm mai', album: { id: SEED_ALBUM_STREET, position: 1 } },
  { id: 'seed-post-an-4', photographerId: AN, images: 4, caption: 'Chân dung ánh sáng tự nhiên', album: null },
  { id: 'seed-post-an-5', photographerId: AN, images: 2, caption: 'Cưới ngoại cảnh', album: null },
];

export interface SeedAward {
  readonly id: string;
  readonly photographerId: string;
  readonly competition: string;
  readonly year: number;
  readonly result: 'gold' | 'silver' | 'bronze' | 'honorable' | 'finalist' | 'exhibited';
  readonly status: 'pending' | 'approved';
}

/** Dũng has three approved awards (artist tier); Bình has one pending in the review queue. */
export const SEED_AWARDS: readonly SeedAward[] = [
  { id: 'seed-award-dung-1', photographerId: DUNG, competition: 'Sony World Photography Awards', year: 2024, result: 'gold', status: 'approved' },
  { id: 'seed-award-dung-2', photographerId: DUNG, competition: 'Siena International Photo Awards', year: 2023, result: 'silver', status: 'approved' },
  { id: 'seed-award-dung-3', photographerId: DUNG, competition: 'Hội Nghệ sĩ Nhiếp ảnh Việt Nam', year: 2022, result: 'bronze', status: 'approved' },
  { id: 'seed-award-binh-1', photographerId: BINH, competition: 'Vietnam Photo Contest', year: 2025, result: 'finalist', status: 'pending' },
];

export interface SeedReview {
  /** Synthetic booking id (no booking doc): the review doc id is `reviewDocId(bookingId, 'photographer')`. */
  readonly bookingId: string;
  readonly subjectId: string;
  readonly customerId: string;
  readonly serviceId: string;
  readonly serviceName: string;
  readonly bookingDay: string;
  readonly verdict: Verdict;
  readonly hits: number;
  readonly reasons: readonly ReviewReason[];
  readonly text: string;
  /** Days between the review and seeding. */
  readonly daysAgo: number;
}

/**
 * Tomato/brick reviews (S05). An's three are the newest of his 58 (texts of mock S03.01-reviews);
 * Cúc's and Dũng's are all they have. Every review is born counted, so the trigger neither recounts
 * nor notifies. `seed-booking-completed-recent` stays unreviewed: Lan can review it.
 */
export const SEED_REVIEWS: readonly SeedReview[] = [
  { bookingId: 'seed-review-an-1', subjectId: AN, customerId: LAN, serviceId: 'seed-service-portrait', serviceName: 'Chân dung 2 giờ', bookingDay: '2026-09-24', verdict: 'tomato', hits: 10, reasons: [], text: 'Đúng giờ, kiên nhẫn với bé, ảnh giao sau 3 ngày. Rất ưng.', daysAgo: 4 },
  { bookingId: 'seed-review-an-2', subjectId: AN, customerId: MINH, serviceId: 'seed-service-portrait', serviceName: 'Chân dung 2 giờ', bookingDay: '2026-09-14', verdict: 'brick', hits: 3, reasons: ['late', 'slow_delivery'], text: 'Đến trễ 30 phút, ảnh giao sau 10 ngày. Ảnh thì đẹp.', daysAgo: 6 },
  { bookingId: 'seed-review-an-3', subjectId: AN, customerId: LAN, serviceId: 'seed-service-portrait', serviceName: 'Chân dung 2 giờ', bookingDay: '2026-09-07', verdict: 'tomato', hits: 6, reasons: [], text: 'Cả lớp ai cũng có ảnh đẹp, anh hướng dẫn tạo dáng rất vui.', daysAgo: 12 },
  { bookingId: 'seed-review-cuc-1', subjectId: CUC, customerId: LAN, serviceId: 'seed-service-cuc-wedding', serviceName: 'Ảnh cưới trong studio', bookingDay: '2026-09-20', verdict: 'tomato', hits: 8, reasons: [], text: 'Phòng chụp đẹp, ekip chu đáo, ảnh cưới rất ưng ý.', daysAgo: 5 },
  { bookingId: 'seed-review-cuc-2', subjectId: CUC, customerId: MINH, serviceId: 'seed-service-cuc-wedding', serviceName: 'Ảnh cưới trong studio', bookingDay: '2026-09-13', verdict: 'tomato', hits: 4, reasons: [], text: 'Trang điểm khéo, chụp nhanh gọn, giá hợp lý.', daysAgo: 9 },
  { bookingId: 'seed-review-cuc-3', subjectId: CUC, customerId: LAN, serviceId: 'seed-service-cuc-family', serviceName: 'Gia đình 90 phút', bookingDay: '2026-09-06', verdict: 'tomato', hits: 2, reasons: [], text: 'Ổn, bé nhà mình hợp tác tốt nhờ anh chị kiên nhẫn.', daysAgo: 15 },
  { bookingId: 'seed-review-dung-1', subjectId: DUNG, customerId: LAN, serviceId: 'seed-service-dung-art', serviceName: 'Chân dung nghệ thuật', bookingDay: '2026-09-25', verdict: 'tomato', hits: 9, reasons: [], text: 'Ảnh như tranh, anh chỉnh ánh sáng rất có gu.', daysAgo: 3 },
  { bookingId: 'seed-review-dung-2', subjectId: DUNG, customerId: MINH, serviceId: 'seed-service-dung-art', serviceName: 'Chân dung nghệ thuật', bookingDay: '2026-09-22', verdict: 'brick', hits: 2, reasons: ['late'], text: 'Đến trễ gần một tiếng, phải dời cả buổi.', daysAgo: 4 },
  { bookingId: 'seed-review-dung-3', subjectId: DUNG, customerId: LAN, serviceId: 'seed-service-dung-art', serviceName: 'Chân dung nghệ thuật', bookingDay: '2026-09-18', verdict: 'tomato', hits: 5, reasons: [], text: 'Concept lạ, ảnh có hồn, đáng tiền.', daysAgo: 8 },
  { bookingId: 'seed-review-dung-4', subjectId: DUNG, customerId: MINH, serviceId: 'seed-service-dung-art', serviceName: 'Chân dung nghệ thuật', bookingDay: '2026-09-15', verdict: 'brick', hits: 5, reasons: ['not_as_portfolio', 'price_changed'], text: 'Ảnh không giống portfolio, lại đòi thêm tiền hậu kỳ.', daysAgo: 10 },
  { bookingId: 'seed-review-dung-5', subjectId: DUNG, customerId: LAN, serviceId: 'seed-service-dung-art', serviceName: 'Chân dung nghệ thuật', bookingDay: '2026-09-10', verdict: 'tomato', hits: 3, reasons: [], text: 'Ảnh đẹp, nhưng chờ hơi lâu mới bắt đầu chụp.', daysAgo: 14 },
  { bookingId: 'seed-review-dung-6', subjectId: DUNG, customerId: MINH, serviceId: 'seed-service-dung-art', serviceName: 'Chân dung nghệ thuật', bookingDay: '2026-09-04', verdict: 'brick', hits: 1, reasons: ['attitude'], text: 'Hơi khó tính khi mình góp ý về dáng chụp.', daysAgo: 20 },
];

/** An's stats stand for all 58 of his reviews (only three are seeded); they keep `top_rated` (≥ 95% from ≥ 20). */
const AN_STATS: PhotographerStatsPatch = {
  reviewCount: 58,
  tomatoCount: 56,
  brickCount: 2,
  signedSum: 54.62,
  tomatoPct: 97,
  score: 0.942,
  punctualMentions: 3,
};

/** `photographers/{uid}.stats`: An's fixed numbers; anyone else's folded from their seeded reviews. */
function seedStatsOf(uid: string): PhotographerStatsPatch | null {
  if (uid === AN) return AN_STATS;
  let stats: PhotographerStatsPatch | null = null;
  for (const r of SEED_REVIEWS.filter((x) => x.subjectId === uid)) {
    stats = addVerdict(stats === null ? {} : { ...stats }, r.verdict, intensityOf(r.hits), mentionsPunctual(r.text));
  }
  return stats;
}

function reviewDocuments(now: Date): SeedDocument[] {
  return SEED_REVIEWS.map((r) => {
    const at = new Date(now.getTime() - r.daysAgo * DAY_MS);
    return {
      path: `reviews/${reviewDocId(r.bookingId, 'photographer')}`,
      data: {
        bookingId: r.bookingId,
        subjectType: 'photographer',
        subjectId: r.subjectId,
        photographerId: r.subjectId,
        customerId: r.customerId,
        serviceId: r.serviceId,
        serviceName: r.serviceName,
        bookingDay: r.bookingDay,
        verdict: r.verdict,
        hits: r.hits,
        intensity: intensityOf(r.hits),
        reasons: [...r.reasons],
        text: r.text,
        photoPostId: null,
        createdAt: at,
        countedAt: at,
      },
    };
  });
}

export interface SeedDocument {
  readonly path: string;
  readonly data: Record<string, unknown>;
}

const TIMELINE: Readonly<Record<string, readonly string[]>> = {
  requested: ['requested'],
  accepted: ['requested', 'accepted'],
  upcoming: ['requested', 'accepted', 'upcoming'],
  cancelled: ['requested', 'accepted', 'cancelled'],
  completed: ['requested', 'accepted', 'upcoming', 'completed'],
};

function escrowOf(b: SeedBooking): string {
  if (b.dispute !== undefined) return 'disputed';
  if (b.id === SEED_PAID_OUT_BOOKING) return 'released';
  return b.status === 'completed' ? 'released' : b.status === 'cancelled' ? 'refunded' : 'held';
}

function bookingData(b: SeedBooking, now: Date): Record<string, unknown> {
  const service = SEED_SERVICES.find((s) => s.id === b.serviceId);
  if (service === undefined) throw new Error(`unknown seed service ${b.serviceId}`);
  const { deposit, remaining } = computeDeposit(service.price);
  const steps = TIMELINE[b.status] ?? [b.status];
  const last = b.completedDaysAgo === null
    ? new Date(SEED_CREATED_AT.getTime() + (steps.length - 1) * HOUR_MS)
    : new Date(now.getTime() - b.completedDaysAgo * DAY_MS);
  const timeline = steps.map((status, i) => ({ status, at: new Date(last.getTime() - (steps.length - 1 - i) * HOUR_MS) }));
  const createdAt = timeline[0]?.at ?? last;
  const completedAt = b.status === 'completed' ? last : null;
  const escrowStatus = escrowOf(b);

  return {
    customerId: b.customerId,
    photographerId: b.photographerId,
    serviceId: b.serviceId,
    service: { name: service.name, price: service.price, durationMinutes: service.durationMinutes },
    serviceSnapshot: { name: service.name, price: service.price, durationMinutes: service.durationMinutes },
    date: b.date,
    day: b.date,
    start: b.start,
    end: b.end,
    location: { name: b.place },
    place: { name: b.place },
    note: 'Seed booking',
    status: b.status,
    deposit: { amount: deposit, provider: 'fake', paymentId: b.id.replace('seed-booking-', 'seed-payment-'), paidAt: createdAt },
    remaining,
    depositProvider: 'fake',
    depositPaidAt: createdAt,
    escrowStatus,
    completedAt,
    timeline,
    createdAt,
    updatedAt: last,
    version: steps.length,
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
    const onboardingComplete = true;
    const stats = seedStatsOf(p.uid);
    docs.push({
      path: `photographers/${p.uid}`,
      data: {
        bio: p.bio,
        specialties: [...p.specialties],
        serviceArea: { city: p.city, radiusKm: p.radiusKm },
        contactChannels: { ...p.channels },
        onboardingComplete,
        verified: p.verified,
        // Derived like the onPhotographerWrite trigger does: Bình shows "Chưa nhận đơn".
        acceptingOrders: acceptsOrders({ verified: p.verified, onboardingComplete }),
        ...(p.verified ? { verifiedAt: at } : {}),
        ...(p.providerType !== undefined ? { providerType: p.providerType } : {}),
        ...(p.providerType === 'artist' ? { artistSince: at } : {}),
        // An's stats keep the revocable `top_rated` badge: the evaluator runs on every seed write.
        ...(stats !== null ? { stats: { ...stats } } : {}),
        approvedAwardCount: SEED_AWARDS.filter((a) => a.photographerId === p.uid && a.status === 'approved').length,
        ...(p.studioAddress !== undefined ? { studioDistrict: p.studioAddress.district, studioCity: p.studioAddress.city } : {}),
        createdAt: at,
        updatedAt: at,
      },
    });
    docs.push({ path: `photographers/${p.uid}/private/contact`, data: { ...p.numbers, updatedAt: at } });
    if (p.studioAddress !== undefined) {
      docs.push({ path: `photographers/${p.uid}/private/studioAddress`, data: { ...p.studioAddress, updatedAt: at } });
    }
  }
  for (const s of SEED_SERVICES) {
    docs.push({
      path: `photographers/${s.photographerId}/services/${s.id}`,
      data: { name: s.name, price: s.price, currency: 'VND', durationMinutes: s.durationMinutes, active: true, createdAt: at },
    });
  }
  for (const p of SEED_POSTS) {
    docs.push({
      path: `posts/${p.id}`,
      data: {
        kind: 'work',
        authorId: p.photographerId,
        photographerId: p.photographerId,
        serviceId: 'seed-service-portrait',
        imageUrls: Array.from({ length: p.images }, (_, i) => `https://seed.test/${p.id}/${i + 1}.jpg`),
        caption: p.caption,
        likeCount: 0,
        saveCount: 0,
        ...(p.album !== null ? { albumId: p.album.id, albumPosition: p.album.position } : {}),
        createdAt: at,
      },
    });
  }
  const albumSeeds = [
    { id: SEED_ALBUM_FAMILY, title: 'Gia đình', position: 1 },
    { id: SEED_ALBUM_STREET, title: 'Đường phố', position: 2 },
  ];
  for (const a of albumSeeds) {
    const inAlbum = SEED_POSTS.filter((p) => p.album?.id === a.id);
    docs.push({
      path: `albums/${a.id}`,
      data: {
        photographerId: AN,
        title: a.title,
        titleKey: titleKeyOf(a.title),
        description: '',
        cover: null,
        position: a.position,
        postCount: inAlbum.length,
        mediaCount: inAlbum.reduce((n, p) => n + p.images, 0),
        visible: inAlbum.length > 0,
        createdAt: at,
        updatedAt: at,
      },
    });
  }
  for (const a of SEED_AWARDS) {
    docs.push({
      path: `awards/${a.id}`,
      data: {
        photographerId: a.photographerId,
        competition: a.competition,
        year: a.year,
        result: a.result,
        status: a.status,
        ...(a.status === 'approved' ? { reviewedBy: ADMIN, reviewedAt: at } : {}),
        createdAt: at,
        updatedAt: at,
      },
    });
    docs.push({
      path: `awardProofs/${a.id}`,
      data: {
        photographerId: a.photographerId,
        files: [],
        links: [`https://seed.test/awards/${a.id}`],
        ...(a.status === 'approved' ? { purgeAfter: new Date(at.getTime() + 30 * DAY_MS) } : {}),
      },
    });
  }
  for (const b of SEED_BOOKINGS) {
    const service = SEED_SERVICES.find((s) => s.id === b.serviceId);
    if (!service) continue;
    const bData = bookingData(b, now);
    const { deposit } = computeDeposit(service.price);
    const createdAt = bData.createdAt as Date;
    const updatedAt = bData.updatedAt as Date;

    // Booking document
    docs.push({ path: `bookings/${b.id}`, data: bData });

    // Contact snapshot subdocument (except for cancelled bookings)
    if (b.status !== 'cancelled') {
      const isRedacted = b.status === 'completed' && b.completedDaysAgo !== null && b.completedDaysAgo > 30;
      docs.push({
        path: `bookings/${b.id}/private/contact`,
        data: {
          name: 'Lan (seed)',
          phone: isRedacted ? null : (SEED_CUSTOMER_PHONES[b.customerId] ?? '+84903000001'),
          allowZalo: true,
          allowWhatsApp: false,
          ...(isRedacted ? { redactedAt: updatedAt } : {}),
        },
      });
    }

    // Payment document
    const paymentId = `seed-payment-${b.id}`;
    const paidOut = b.id === SEED_PAID_OUT_BOOKING;
    const escrowStatus = paidOut ? 'paid_out' : escrowOf(b);
    const paymentData: Record<string, unknown> = {
      subjectType: 'booking',
      subjectId: b.id,
      payerId: b.customerId,
      payeeId: b.photographerId,
      provider: 'fake',
      amount: deposit,
      status: b.status === 'cancelled' ? 'refunded' : 'paid',
      escrowStatus,
      idempotencyKey: `dep_${b.id}_fake`,
      // Paid by bank QR, the way createPayment opens a payment.
      method: 'bank_qr',
      transferCode: transferCodeFor(paymentId),
      expiresAt: new Date(createdAt.getTime() + PAYMENT_EXPIRY_MINUTES * 60_000),
      receivedAmount: deposit,
      ...(paidOut ? { payoutId: SEED_PAYOUT_AN } : {}),
      ...(b.dispute !== undefined ? { dispute: { reason: b.dispute.reason, openedAt: new Date(updatedAt.getTime() + HOUR_MS) } } : {}),
      createdAt,
      updatedAt,
    };
    docs.push({ path: `payments/${paymentId}`, data: paymentData });

    // Ledger entry for deposit
    docs.push({
      path: `ledger_entries/seed-ledger-${b.id}-dep`,
      data: {
        type: 'payment_received',
        paymentId,
        subjectType: 'booking',
        subjectId: b.id,
        accountOwnerId: 'platform_escrow',
        amount: deposit,
        note: `Seed deposit for ${b.id}`,
        at: createdAt,
      },
    });

    if (b.status === 'completed' && b.dispute === undefined) {
      docs.push({
        path: `ledger_entries/seed-ledger-${b.id}-rel`,
        data: {
          type: 'escrow_released',
          paymentId,
          subjectType: 'booking',
          subjectId: b.id,
          accountOwnerId: b.photographerId,
          amount: deposit,
          note: `Seed release for ${b.id}`,
          at: updatedAt,
        },
      });
    } else if (b.status === 'cancelled') {
      const refundId = `seed-refund-${b.id}`;
      docs.push({
        path: `refunds/${refundId}`,
        data: {
          paymentId,
          amount: deposit,
          percent: 100,
          status: 'completed',
          manual: false,
          fromEscrow: true,
          createdAt: updatedAt,
          updatedAt,
        },
      });
      docs.push({
        path: `ledger_entries/seed-ledger-${b.id}-ref`,
        data: {
          type: 'refund_issued',
          paymentId,
          subjectType: 'booking',
          subjectId: b.id,
          accountOwnerId: b.customerId,
          amount: -deposit,
          note: `Seed refund for ${b.id}`,
          at: updatedAt,
        },
      });
    }

    // Availability day
    if (b.status === 'requested') {
      docs.push({
        path: `availability/${b.photographerId}/days/${b.date}`,
        data: { state: 'pending', bookingId: b.id, updatedAt },
      });
    } else if (b.status === 'accepted' || b.status === 'upcoming' || b.status === 'completed') {
      docs.push({
        path: `availability/${b.photographerId}/days/${b.date}`,
        data: { state: 'booked', bookingId: b.id, updatedAt },
      });
    }
  }
  docs.push(...reviewDocuments(now));
  docs.push(...notificationAndBadgeDocuments(now));
  docs.push(...payoutAndEarningsDocuments(now, docs));
  docs.push(...eventDocuments(now, docs));
  docs.push(...directChatDocuments(now, docs));
  return docs;
}

interface SeedChatText {
  readonly from: string;
  readonly body: string;
  /** Milliseconds before seed time. */
  readonly agoMs: number;
}

interface SeedDirectChat {
  readonly kind: 'booking' | 'inquiry';
  readonly customerId: string;
  readonly photographerId: string;
  /** The seeded booking it mirrors (`bookingStatus` is read from it), or null for an inquiry. */
  readonly bookingId: string | null;
  readonly texts: readonly SeedChatText[];
  /** Unread messages per member; a member left out has 0. */
  readonly unread: Readonly<Record<string, number>>;
}

/**
 * The three 1-1 conversations of S07 (`chats/{customer}_{photographer}`): a booking chat that
 * mirrors its booking, an inquiry closed for 20 days, and an open inquiry with one unread message.
 */
const SEED_DIRECT_CHATS: readonly SeedDirectChat[] = [
  {
    kind: 'booking', customerId: LAN, photographerId: AN, bookingId: 'seed-booking-upcoming',
    texts: [
      { from: LAN, body: 'Chào anh An, em muốn hỏi thêm về buổi chụp chân dung.', agoMs: 5 * HOUR_MS },
      { from: AN, body: 'Chào Lan, anh nhận được lịch rồi nhé.', agoMs: 4 * HOUR_MS },
      { from: AN, body: 'Hẹn bạn sáng thứ Bảy ở Công viên Thống Nhất.', agoMs: 3 * HOUR_MS },
    ],
    unread: { [LAN]: 2 },
  },
  {
    kind: 'inquiry', customerId: LAN, photographerId: CUC, bookingId: null,
    texts: [
      { from: LAN, body: 'Studio còn nhận chụp ảnh gia đình không ạ?', agoMs: 20 * DAY_MS + HOUR_MS },
      { from: CUC, body: 'Dạ còn ạ, bạn cho studio biết ngày dự kiến nhé.', agoMs: 20 * DAY_MS },
    ],
    unread: {},
  },
  {
    kind: 'inquiry', customerId: MINH, photographerId: DUNG, bookingId: null,
    texts: [{ from: MINH, body: 'Anh Dũng ơi, anh có nhận chụp ảnh cưới ở Huế không?', agoMs: 3 * HOUR_MS }],
    unread: { [DUNG]: 1 },
  },
];

const seedMessageId = (chatId: string, i: number): string => `seed-msg-${chatId}-${i + 1}`;

/**
 * Chat fields are folded from the messages with the domain's `afterMessage`, and `bookingStatus`
 * is read from the seeded booking, so nothing here is a hand-written status.
 */
function directChatDocuments(now: Date, existing: readonly SeedDocument[]): SeedDocument[] {
  const docs: SeedDocument[] = [];
  for (const c of SEED_DIRECT_CHATS) {
    const first = c.texts[0];
    if (first === undefined) throw new Error('a seed chat needs a message');
    let bookingStatus: string | null = null;
    if (c.bookingId !== null) {
      const booking = existing.find((d) => d.path === `bookings/${c.bookingId}`);
      if (booking === undefined) throw new Error(`seed booking ${c.bookingId} is missing`);
      bookingStatus = String(booking.data.status);
    }
    const id = chatIdFor(c.customerId, c.photographerId);
    const at0 = new Date(now.getTime() - first.agoMs);
    let chat: Chat = {
      id, kind: c.kind, customerId: c.customerId, photographerId: c.photographerId,
      bookingId: c.bookingId, bookingStatus,
      photographerRepliedAt: null, customerMessagesBeforeReply: 0,
      lastMessageAt: null, lastMessagePreview: null, lastSenderId: null,
      readOnlyAt: null, rescheduleUsed: false, createdAt: at0, updatedAt: at0,
    };
    const messages: SeedDocument[] = [];
    c.texts.forEach((t, i) => {
      const at = new Date(now.getTime() - t.agoMs);
      const m: Message = {
        id: seedMessageId(id, i), chatId: id, senderId: t.from, type: 'text', body: t.body,
        imagePath: null, point: null, system: null, createdAt: at,
      };
      chat = afterMessage(chat, m, at);
      messages.push({ path: `chats/${id}/messages/${m.id}`, data: toFirestoreMessage(m) });
    });
    // The chat document comes before its messages and members, like the callables write them.
    docs.push({ path: `chats/${id}`, data: toFirestoreChat(chat) }, ...messages);
    for (const uid of [c.customerId, c.photographerId]) {
      docs.push({ path: `chats/${id}/members/${uid}`, data: { unreadCount: c.unread[uid] ?? 0, lastReadAt: null } });
    }
  }
  return docs;
}

/**
 * The grouped `g_chat_{chatId}` inbox row each member already has for the messages they received,
 * exactly as onChatMessageCreated would have left it. applySeed writes the messages with the Admin
 * SDK, so that trigger runs for every one of them after seeding; with these rows in place each run is
 * a duplicate (same last or recent event id) and writes nothing, instead of adding a fresh unread row
 * for a 20-day-old message. Unread rows hold the member's unread messages; read rows only dedupe
 * their last event, so a member who has read everything may have received one message at most.
 */
function seedChatInboxRows(): SeedRow[] {
  const rows: SeedRow[] = [];
  for (const c of SEED_DIRECT_CHATS) {
    const id = chatIdFor(c.customerId, c.photographerId);
    for (const uid of [c.customerId, c.photographerId]) {
      const received = c.texts.map((t, i) => ({ ...t, id: seedMessageId(id, i) })).filter((t) => t.from !== uid);
      const last = received[received.length - 1];
      if (last === undefined) continue;
      const unread = c.unread[uid] ?? 0;
      if (unread > received.length) throw new Error(`${id}: ${uid} has more unread than received messages`);
      if (unread === 0 && received.length > 1) throw new Error(`${id}: a read chat row only dedupes its last message`);
      const sender = SEED_USERS.find((u) => u.uid === last.from);
      if (sender === undefined) throw new Error(`unknown seed sender ${last.from}`);
      const count = Math.max(unread, 1);
      rows.push({
        uid, id: `g_chat_${id}`, ageHours: last.agoMs / HOUR_MS, read: unread === 0, target: `/chat/${id}`,
        content: { type: 'chat_message', sender: sender.displayName, preview: chatPreview('text', last.body), count },
        actor: { id: sender.uid, name: sender.displayName, avatarUrl: null },
        group: {
          key: `chat:${id}`, count, lastEventId: last.id,
          recentEventIds: unread === 0 ? [last.id] : received.slice(-unread).map((t) => t.id).reverse(),
        },
      });
    }
  }
  return rows;
}

interface SeedRow {
  readonly uid: string;
  readonly id: string;
  readonly content: NotificationContent;
  readonly target: string;
  readonly ageHours: number;
  readonly read: boolean;
  /** Defaults to An for Lan's rows and Lan for everyone else's. */
  readonly actor?: { readonly id: string; readonly name: string; readonly avatarUrl: string | null };
  readonly group?: {
    readonly key: string;
    readonly count: number;
    readonly lastEventId: string;
    /** Newest first; defaults to `[lastEventId]`. */
    readonly recentEventIds?: readonly string[];
  };
}

const ACTOR_AN = { id: AN, name: 'An Studio (seed)', avatarUrl: null };
const ACTOR_LAN = { id: LAN, name: 'Lan (seed)', avatarUrl: null };

const SEED_ROWS: readonly SeedRow[] = [
  { uid: LAN, id: 'n_booking_accepted_seed-booking-accepted', ageHours: 1, read: false, target: '/b/seed-booking-accepted',
    content: { type: 'booking_accepted', photographer: 'An Studio (seed)', day: 'T3 20/10', start: '08:00', place: 'Hồ Hoàn Kiếm, Hà Nội' } },
  { uid: LAN, id: 'n_shoot_reminder_seed-booking-upcoming_h24', ageHours: 5, read: true, target: '/b/seed-booking-upcoming',
    content: { type: 'shoot_reminder', hours: 24, service: 'Chân dung 2 giờ', counterpart: 'An Studio (seed)', day: 'T7 10/10', start: '08:00' } },
  { uid: LAN, id: 'n_refund_done_seed-booking-cancelled', ageHours: 30, read: true, target: '/b/seed-booking-cancelled',
    content: { type: 'refund_done', amount: computeDeposit(1_500_000).deposit, bookingId: 'seed-booking-cancelled' } },
  { uid: LAN, id: 'n_booking_declined_seed-booking-declined', ageHours: 12 * 24, read: true, target: '/b/seed-booking-declined',
    content: { type: 'booking_declined', reason: 'declined', photographer: 'Bình (seed)', percent: 100 } },
  { uid: AN, id: 'n_booking_request_seed-booking-requested-an', ageHours: 3, read: false, target: '/bookings',
    content: { type: 'booking_request', customer: 'Lan (seed)', service: 'Chân dung 2 giờ', day: 'T7 25/10', start: '16:00' } },
  // A sample verdict notice (S17 `review_tomato`); its id is no real dedupe key, so Lan's review of
  // seed-booking-completed-recent still notifies An.
  { uid: AN, id: 'n_review_tomato_seed-sample', ageHours: 48, read: true, target: `/u/${AN}?tab=reviews`,
    content: { type: 'review_tomato', hits: 7, day: '2026-09-27', text: 'Rất hài lòng, đúng giờ.' } },
];

/** Inbox rows, unread counts and badges (plan 10a). Defaults apply to everyone: no prefs doc. */
function notificationAndBadgeDocuments(now: Date): SeedDocument[] {
  const docs: SeedDocument[] = [];
  const unread = new Map<string, number>();
  for (const r of [...SEED_ROWS, ...seedChatInboxRows()]) {
    const meta = NOTIFICATION_TYPES[r.content.type as NotificationType];
    const at = new Date(now.getTime() - r.ageHours * HOUR_MS);
    unread.set(r.uid, (unread.get(r.uid) ?? 0) + (r.read ? 0 : 1));
    docs.push({
      path: `users/${r.uid}/notifications/${r.id}`,
      data: {
        type: r.content.type,
        tab: meta.tab,
        category: meta.category,
        ...renderNotification(r.content),
        target: r.target,
        groupKey: r.group?.key ?? null,
        actors: [r.actor ?? (r.uid === LAN ? ACTOR_AN : ACTOR_LAN)],
        count: r.group?.count ?? 1,
        thumbUrl: null,
        lastEventId: r.group?.lastEventId ?? null,
        recentEventIds: r.group ? [...(r.group.recentEventIds ?? [r.group.lastEventId])] : [],
        createdAt: at,
        readAt: r.read ? new Date(at.getTime() + HOUR_MS / 2) : null,
      },
    });
  }
  for (const uid of unread.keys()) {
    docs.push({ path: `users/${uid}/private/inbox`, data: { unreadCount: unread.get(uid) ?? 0, unreadCountAt: now } });
  }

  for (const b of BADGE_CATALOG) {
    docs.push({
      path: `badges/${b.id}`,
      data: {
        name: b.name,
        shortName: b.shortName,
        description: b.description,
        icon: b.icon,
        source: b.source,
        audience: b.audience,
        order: b.order,
        hiddenWhenLocked: b.hiddenWhenLocked,
        progress: b.progress,
      },
    });
  }
  const earned = (uid: string, badgeId: string, text: string, daysAgo: number) =>
    docs.push({
      path: `users/${uid}/badges/${badgeId}`,
      data: { badgeId, uid, awardedAt: new Date(now.getTime() - daysAgo * DAY_MS), snapshot: { text } },
    });
  earned(AN, 'top_rated', '97% cà chua từ 58 đánh giá', 20);
  earned(AN, 'shoots_10', 'Hoàn thành 12 buổi', 10);
  earned(AN, 'complete_profile', 'Đủ ảnh và gói', 25);
  earned(LAN, 'loyal_customer', 'Hoàn thành 3 buổi chụp', 5);
  const progress = (uid: string, entries: Record<string, { current: number; target: number }>) =>
    docs.push({ path: `users/${uid}/private/badgeProgress`, data: { entries, updatedAt: now } });
  // Equal to what the evaluator computes from the seeded data, so a trigger run changes nothing.
  const anShoots = SEED_BOOKINGS.filter((b) => b.photographerId === AN && b.status === 'completed').length;
  progress(AN, { punctual: { current: 3, target: 5 }, shoots_50: { current: Math.min(anShoots, 50), target: 50 } });
  // Lan has no real-shoot post; 3 of her seeded reviews have ≥ 50 graphemes (detailedReviews).
  progress(LAN, { sharer: { current: 0, target: 5 }, detailed_reviewer: { current: 3, target: 5 } });
  return docs;
}


/**
 * An's payout account (matched, with her verified name), one paid payout with its tax line (#134),
 * and the `earnings` projection of every
 * photographer with payments, computed by the same pure functions the triggers use so the seed
 * does not depend on trigger timing. Bình has no account.
 */
function payoutAndEarningsDocuments(now: Date, existing: readonly SeedDocument[]): SeedDocument[] {
  const docs: SeedDocument[] = [];
  const at = SEED_CREATED_AT;
  const a = SEED_AN_ACCOUNT;
  // An's account: matched against the verified name below, active since the seed start.
  const account: PayoutAccount = {
    id: a.id,
    userId: AN,
    bankCode: a.bankCode,
    accountNumberEnc: encryptSyncForSeed(emulatorPayoutKey(), a.number),
    accountLast4: accountLast4(a.number),
    holderName: a.holderName,
    active: true,
    createdAt: at.toISOString(),
    nameStatus: 'matched',
    activeFrom: at.toISOString(),
  };
  docs.push({
    path: `payoutAccounts/${AN}`,
    data: accountViewToFirestore({
      accountId: account.id,
      bankCode: account.bankCode,
      accountLast4: account.accountLast4,
      holderName: account.holderName,
      updatedAt: account.createdAt,
      nameStatus: account.nameStatus,
      activeFrom: account.activeFrom,
    }),
  });
  docs.push({ path: `payoutAccounts/${AN}/accounts/${a.id}`, data: accountToFirestore(account) });
  // The verified name the account was matched against (test value; #135 owns this doc's full shape).
  docs.push({
    path: `users/${AN}/private/identity`,
    data: { legalName: SEED_AN_LEGAL_NAME, method: 'fake', provider: 'fake', verifiedAt: at },
  });

  const paymentDoc = (id: string) => existing.find((d) => d.path === `payments/${id}`);
  const paidId = `seed-payment-${SEED_PAID_OUT_BOOKING}`;
  const paid = paymentDoc(paidId);
  if (paid === undefined) throw new Error('seed: the paid-out payment is missing');
  const amount = paid.data.amount as number;
  const paidAt = new Date(now.getTime() - 35 * DAY_MS);
  const createdAt = new Date(paidAt.getTime() - HOUR_MS);
  // An is an individual: 7% withheld (DEFAULT_PAYOUT_POLICY), so 450,000 → tax 31,500, net 418,500.
  const line = payoutLineOf(amount, providerTypeOf(SEED_PHOTOGRAPHERS.find((sp) => sp.uid === AN)?.providerType), DEFAULT_PAYOUT_POLICY);
  // The first payout to the account, approved by staff before it was sent.
  const payout: Payout = {
    id: SEED_PAYOUT_AN,
    payeeId: AN,
    accountId: a.id,
    amount,
    status: 'paid',
    items: [{ paymentId: paidId, amount, fee: line.fee, tax: line.tax, net: line.net }],
    platformFee: line.fee,
    taxWithheld: line.tax,
    amountNet: line.net,
    feeRateBp: line.feeRateBp,
    taxRateBp: line.taxRateBp,
    firstPayout: true,
    approvedBy: ADMIN,
    approvedAt: new Date(createdAt.getTime() + HOUR_MS / 4).toISOString(),
    reference: `FAKE-${SEED_PAYOUT_AN}`,
    createdBy: ADMIN,
    createdAt: createdAt.toISOString(),
    updatedAt: paidAt.toISOString(),
    processingAt: new Date(paidAt.getTime() - HOUR_MS / 2).toISOString(),
    paidAt: paidAt.toISOString(),
  };
  docs.push({ path: `payouts/${SEED_PAYOUT_AN}`, data: payoutToFirestore(payout) });
  // Per payment the payout entries net to −amount: payout_paid −net, tax_withheld −tax.
  const ledgerLines: [string, string, number][] = [
    ['pay', 'payout_paid', line.net],
    ['tax', 'tax_withheld', line.tax],
    ['fee', 'platform_fee', line.fee],
  ];
  for (const [suffix, type, value] of ledgerLines) {
    if (value <= 0) continue;
    docs.push({
      path: `ledger_entries/seed-ledger-${SEED_PAYOUT_AN}-${suffix}`,
      data: {
        type,
        paymentId: paidId,
        payoutId: SEED_PAYOUT_AN,
        subjectType: 'booking',
        subjectId: SEED_PAID_OUT_BOOKING,
        accountOwnerId: AN,
        amount: -value,
        note: `Payout ${SEED_PAYOUT_AN}`,
        at: paidAt,
      },
    });
  }

  // The projection: rows and totals per payee, from the seeded payments.
  const iso = (v: unknown): string | undefined => (v instanceof Date ? v.toISOString() : undefined);
  const byPayee = new Map<string, EarningItem[]>();
  for (const d of existing) {
    if (!/^payments\/[^/]+$/.test(d.path)) continue;
    const id = d.path.slice('payments/'.length);
    const x = d.data;
    const booking = SEED_BOOKINGS.find((b) => b.id === x.subjectId);
    const service = SEED_SERVICES.find((s) => s.id === booking?.serviceId);
    if (booking === undefined || service === undefined) continue;
    const payment: Payment = {
      id,
      subjectType: 'booking',
      subjectId: booking.id,
      payerId: x.payerId as string,
      payeeId: x.payeeId as string,
      provider: 'fake',
      amount: x.amount as number,
      status: x.status as Payment['status'],
      escrowStatus: x.escrowStatus as Payment['escrowStatus'],
      idempotencyKey: x.idempotencyKey as string,
      payoutId: (x.payoutId as string | undefined) ?? null,
      createdAt: iso(x.createdAt) ?? at.toISOString(),
      updatedAt: iso(x.updatedAt) ?? at.toISOString(),
    };
    const refunded = x.status === 'refunded' ? payment.amount : 0;
    const item = earningItemOf({
      payment,
      refunded,
      subject: { counterpartName: 'Lan (seed)', label: service.name, day: booking.date, milestones: null },
      payout: payment.payoutId === SEED_PAYOUT_AN ? payout : null,
      payeeType: providerTypeOf(SEED_PHOTOGRAPHERS.find((sp) => sp.uid === payment.payeeId)?.providerType),
      policy: DEFAULT_PAYOUT_POLICY,
      now,
    });
    if (item === null) continue;
    byPayee.set(item.payeeId, [...(byPayee.get(item.payeeId) ?? []), item]);
  }
  for (const [payeeId, items] of byPayee) {
    const summary = summarizeEarnings(payeeId, items, payeeId === AN ? payout : null, now);
    docs.push({
      path: `earnings/${payeeId}`,
      data: {
        heldAmount: summary.heldAmount,
        soonAmount: summary.soonAmount,
        receivedAmount: summary.receivedAmount,
        lastPayout: summary.lastPayout === null ? null : { id: summary.lastPayout.id, status: summary.lastPayout.status, at: new Date(summary.lastPayout.at) },
        updatedAt: now,
      },
    });
    for (const i of items) {
      docs.push({ path: `earnings/${payeeId}/items/${i.id}`, data: earningItemToFirestore({ ...i, updatedAt: now.toISOString() }) });
    }
  }
  return docs;
}

export const SEED_EVENT_FREE = 'seed-event-an-free-photowalk';
export const SEED_EVENT_PAID = 'seed-event-an-paid-workshop';
export const SEED_REGISTRATION_LAN = 'seed-registration-lan-free-walk';
export const SEED_TICKET_CODE_LAN = 'VE-LANA-0000';
/** S17: starts 36 hours after seeding, so `npm run clock -- events` sends Lan's `event_soon` reminder. */
export const SEED_EVENT_SOON = 'seed-event-an-night-walk';
export const SEED_REGISTRATION_LAN_SOON = 'seed-registration-lan-night-walk';
export const SEED_TICKET_CODE_LAN_SOON = 'VE-LANB-0000';

/**
 * Three open events of An (a free photo walk, a paid workshop and, for the S17 reminder, a free
 * night walk 36 hours after seeding) and Lan's free registrations to both walks. Written through the
 * same mapping the Functions use (plan 10c). Free tickets are `paid` with `contactEligible: false`
 * and have no `private/contact` snapshot (O3). An availability day a seed booking already holds is
 * left to the booking (`existing`: the documents written before).
 */
function eventDocuments(now: Date, existing: readonly SeedDocument[]): SeedDocument[] {
  const make = (id: string, title: string, type: EventRecord['type'], hoursAhead: number, price: number, capacity: number): EventRecord => {
    const startAt = new Date(now.getTime() + hoursAhead * HOUR_MS);
    const endAt = new Date(startAt.getTime() + 2 * HOUR_MS);
    const hashtag = hashtagBase(title, startAt);
    return {
      id,
      host: { type: 'photographer', id: AN, name: 'An Studio (seed)', avatarUrl: null, verified: true },
      createdBy: AN,
      createdByRole: 'photographer',
      hostConsent: 'not_required',
      hostConsentExpiresAt: null,
      title,
      description: 'Sự kiện mẫu cho môi trường thử nghiệm.',
      type,
      coverUrl: null,
      coverPath: null,
      startAt,
      endAt,
      dayKey: formatVnDate(startAt),
      location: {
        name: 'Hồ Gươm', meetingPoint: 'Cổng đền Ngọc Sơn', lat: 21.0285, lng: 105.8542,
        geohash: encodeGeohash(21.0285, 105.8542), areaId: null,
      },
      capacity,
      price,
      registrationDeadline: new Date(startAt.getTime() - 12 * HOUR_MS),
      faq: [],
      hashtag,
      hashtagKey: hashtagKeyOf(hashtag),
      hashtagLocked: false,
      status: 'open',
      registeredCount: 0,
      heldCount: 0,
      chatId: `event_${id}`,
      postCount: 0,
      version: 1,
      publishedAt: now,
      completedAt: null,
      cancelledAt: null,
      soonNoticeAt: null,
      createdAt: now,
      updatedAt: now,
    };
  };
  const free = make(SEED_EVENT_FREE, 'Photo walk phố cổ', 'photo_walk', 8 * 24 + 2, 0, 20);
  const paid = make(SEED_EVENT_PAID, 'Workshop ánh sáng tự nhiên', 'workshop', 15 * 24 + 2, 250_000, 12);
  const soonBase = make(SEED_EVENT_SOON, 'Chụp phố đêm', 'photo_walk', 36, 0, 15);
  const soon: EventRecord = {
    ...soonBase,
    location: {
      name: 'Phố đi bộ Nguyễn Huệ', meetingPoint: 'Nhà hát Thành phố', lat: 10.7769, lng: 106.7032,
      geohash: encodeGeohash(10.7769, 106.7032), areaId: null,
    },
  };
  const ticketOf = (id: string, ev: EventRecord, code: string): RegistrationDoc => ({
    id,
    eventId: ev.id,
    userId: LAN,
    userName: 'Lan (seed)',
    userAvatarUrl: null,
    quantity: 1,
    amount: 0,
    status: 'paid',
    holdExpiresAt: null,
    ticketCode: code,
    paymentId: null,
    contactEligible: false,
    checkedInAt: null,
    cancelledAt: null,
    refundPercent: null,
    event: {
      title: ev.title, type: ev.type, startAt: ev.startAt as Date, endAt: ev.endAt as Date,
      locationName: ev.location?.name ?? '', lat: ev.location?.lat ?? 0, lng: ev.location?.lng ?? 0, coverUrl: null,
    },
    version: 1,
    createdAt: now,
    updatedAt: now,
  });
  const registration = ticketOf(SEED_REGISTRATION_LAN, free, SEED_TICKET_CODE_LAN);
  const soonTicket = ticketOf(SEED_REGISTRATION_LAN_SOON, soon, SEED_TICKET_CODE_LAN_SOON);
  const withLan = new Set([free.id, soon.id]);
  const taken = new Set(existing.map((d) => d.path));
  const docs: SeedDocument[] = [];
  for (const e of [{ ...free, registeredCount: 1, postCount: 1 }, paid, { ...soon, registeredCount: 1 }]) {
    docs.push({ path: `events/${e.id}`, data: eventToFirestore(e) as Record<string, unknown> });
    docs.push({ path: `event_hashtags/${e.hashtagKey}`, data: { eventId: e.id } });
    const dayPath = `availability/${AN}/days/${e.dayKey}`;
    if (!taken.has(dayPath)) {
      taken.add(dayPath);
      docs.push({ path: dayPath, data: { state: 'booked', eventId: e.id, updatedAt: now } });
    }
    docs.push({
      path: `chats/${e.chatId}`,
      data: groupChatToFirestore({
        id: e.chatId as string, kind: 'event_group', eventId: e.id, title: e.title,
        members: withLan.has(e.id) ? [AN, LAN] : [AN], moderators: [AN],
        memberProfiles: [{ uid: AN, name: 'An Studio (seed)', avatarUrl: null }],
        memberCount: withLan.has(e.id) ? 2 : 1, moderatorsOnly: false,
        lastMessageAt: null, lastMessagePreview: null, lastSenderId: null, readOnlyAt: null,
        createdAt: now, updatedAt: now,
      }) as Record<string, unknown>,
    });
  }
  // Group chat of the free walk: both members, a join line and An's pinned announcement.
  const chatPath = `chats/${free.chatId as string}`;
  const memberDoc = (role: 'moderator' | 'member', name: string) => ({
    role, name, avatarUrl: null, mutedUntil: null, joinedAt: now, removedAt: null, removedBy: null,
    sentWindowStart: null, sentInWindow: 0,
  });
  docs.push({ path: `${chatPath}/members/${AN}`, data: memberDoc('moderator', 'An Studio (seed)') });
  docs.push({ path: `chats/${paid.chatId as string}/members/${AN}`, data: memberDoc('moderator', 'An Studio (seed)') });
  docs.push({ path: `${chatPath}/members/${LAN}`, data: memberDoc('member', 'Lan (seed)') });
  docs.push({ path: `chats/${soon.chatId as string}/members/${AN}`, data: memberDoc('moderator', 'An Studio (seed)') });
  docs.push({ path: `chats/${soon.chatId as string}/members/${LAN}`, data: memberDoc('member', 'Lan (seed)') });
  docs.push({
    path: `${chatPath}/messages/seed-msg-join-lan`,
    data: {
      senderId: null, senderName: null, type: 'system', body: null, imagePath: null, point: null,
      system: { kind: 'member_joined', userId: LAN, name: 'Lan (seed)' }, clientId: 'seed-msg-join-lan',
      createdAt: now, deletedAt: null,
    },
  });
  docs.push({
    path: `${chatPath}/messages/seed-msg-announcement`,
    data: {
      senderId: AN, senderName: 'An Studio (seed)', type: 'text', body: 'Tập trung đúng giờ, mang theo máy ảnh nhé!',
      imagePath: null, point: null, system: null, clientId: 'seed-msg-announcement', createdAt: now, deletedAt: null,
    },
  });
  docs.push({
    path: `${chatPath}/pins/seed-msg-announcement`,
    data: { body: 'Tập trung đúng giờ, mang theo máy ảnh nhé!', senderName: 'An Studio (seed)', pinnedBy: AN, pinnedAt: now },
  });
  // Timeline of the free walk: Lan's shared post (visible) and a stranger's (pending, for the review tab).
  const share = (id: string, authorId: string, name: string) => ({
    path: `posts/${id}`,
    data: {
      kind: 'event_share', authorId, photographerId: '', serviceId: '', eventId: free.id,
      imageUrls: [`https://seed.test/${id}/1.jpg`, `https://seed.test/${id}/2.jpg`],
      imageMeta: [{ blurHash: null, w: 800, h: 1000 }, { blurHash: null, w: 800, h: 1000 }],
      caption: `Ảnh của ${name} #${free.hashtag}`, hashtags: [free.hashtagKey], inPortfolio: false,
      likeCount: 0, saveCount: 0, createdAt: now,
    },
  });
  const row = (postId: string, authorId: string, name: string, status: 'visible' | 'pending') => ({
    path: `events/${free.id}/timeline/${postId}`,
    data: {
      postId, source: 'explicit', status, authorId, authorName: name, isHost: false,
      imageUrl: `https://seed.test/${postId}/1.jpg`, imageW: 800, imageH: 1000, imageCount: 2, addedAt: now, moderatedBy: null,
    },
  });
  docs.push(share('seed-post-lan-share', LAN, 'Lan'), row('seed-post-lan-share', LAN, 'Lan (seed)', 'visible'));
  docs.push(share('seed-post-minh-share', MINH, 'Minh'), row('seed-post-minh-share', MINH, 'Minh', 'pending'));
  docs.push({ path: `events/${free.id}/registrations/${registration.id}`, data: registrationToFirestore(registration) as Record<string, unknown> });
  docs.push({ path: `ticket_codes/${registration.ticketCode}`, data: { eventId: free.id, registrationId: registration.id } });
  docs.push({ path: `events/${soon.id}/registrations/${soonTicket.id}`, data: registrationToFirestore(soonTicket) as Record<string, unknown> });
  docs.push({ path: `ticket_codes/${soonTicket.ticketCode}`, data: { eventId: soon.id, registrationId: soonTicket.id } });
  return docs;
}
