// Deterministic local test data for the Firebase emulators. Test values only: these accounts
// and numbers exist nowhere but in the local emulators. Listed in seed/README.md.

import { BADGE_CATALOG, NOTIFICATION_TYPES, renderNotification, titleKeyOf, type NotificationContent, type NotificationType } from '@photobooking/domain';

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
}

export const SEED_BOOKINGS: readonly SeedBooking[] = [
  { id: 'seed-booking-accepted', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'accepted', date: '2026-10-20', start: '08:00', end: '10:00', place: 'Hồ Hoàn Kiếm, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-upcoming', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'upcoming', date: '2026-10-10', start: '08:00', end: '10:00', place: 'Công viên Thống Nhất, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-requested-binh', customerId: LAN, photographerId: BINH, serviceId: 'seed-service-family', status: 'requested', date: '2026-10-25', start: '16:00', end: '17:30', place: 'Biển Mỹ Khê, Đà Nẵng', completedDaysAgo: null },
  { id: 'seed-booking-cancelled', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'cancelled', date: '2026-10-22', start: '08:00', end: '10:00', place: 'Văn Miếu, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-completed-recent', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'completed', date: '2026-09-27', start: '08:00', end: '10:00', place: 'Hồ Tây, Hà Nội', completedDaysAgo: 3 },
  { id: 'seed-booking-completed-old', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'completed', date: '2026-08-20', start: '08:00', end: '10:00', place: 'Phố cổ, Hà Nội', completedDaysAgo: 40 },
];

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
  const completedAt = b.status === 'completed' ? last : null;
  const escrowStatus = b.status === 'completed'
    ? 'released'
    : b.status === 'cancelled'
      ? 'refunded'
      : 'held';

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
    remaining: service.price - deposit,
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
        ...(p.providerType !== undefined ? { providerType: p.providerType } : {}),
        ...(p.providerType === 'artist' ? { artistSince: at } : {}),
        // An's stats keep the revocable `top_rated` badge: the evaluator runs on every seed write.
        ...(p.uid === AN ? { stats: { rating: 4.9, reviewCount: 58, ratingSum: 284, punctualMentions: 3 } } : {}),
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
    const deposit = Math.floor(service.price * 0.3);
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
    const escrowStatus = b.status === 'completed' ? 'released' : b.status === 'cancelled' ? 'refunded' : 'held';
    docs.push({
      path: `payments/${paymentId}`,
      data: {
        subjectType: 'booking',
        subjectId: b.id,
        payerId: b.customerId,
        payeeId: b.photographerId,
        provider: 'fake',
        amount: deposit,
        status: b.status === 'cancelled' ? 'refunded' : 'paid',
        escrowStatus,
        idempotencyKey: `dep_${b.id}_fake`,
        createdAt,
        updatedAt,
      },
    });

    // Ledger entry for deposit
    docs.push({
      path: `ledger_entries/seed-ledger-${b.id}-dep`,
      data: {
        type: 'deposit_received',
        paymentId,
        subjectType: 'booking',
        subjectId: b.id,
        accountOwnerId: 'platform_escrow',
        amount: deposit,
        note: `Seed deposit for ${b.id}`,
        at: createdAt,
      },
    });

    if (b.status === 'completed') {
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
  docs.push(...notificationAndBadgeDocuments(now));
  return docs;
}

interface SeedRow {
  readonly uid: string;
  readonly id: string;
  readonly content: NotificationContent;
  readonly target: string;
  readonly ageHours: number;
  readonly read: boolean;
  readonly group?: { readonly key: string; readonly count: number; readonly lastEventId: string };
}

const SEED_CHAT = `${LAN}_${AN}`;
const ACTOR_AN = { id: AN, name: 'An Studio (seed)', avatarUrl: null };
const ACTOR_LAN = { id: LAN, name: 'Lan (seed)', avatarUrl: null };

const SEED_ROWS: readonly SeedRow[] = [
  { uid: LAN, id: 'n_booking_accepted_seed-booking-accepted', ageHours: 1, read: false, target: '/b/seed-booking-accepted',
    content: { type: 'booking_accepted', photographer: 'An Studio (seed)', day: 'T3 20/10', start: '08:00', place: 'Hồ Hoàn Kiếm, Hà Nội' } },
  { uid: LAN, id: 'n_shoot_reminder_seed-booking-upcoming_h24', ageHours: 5, read: true, target: '/b/seed-booking-upcoming',
    content: { type: 'shoot_reminder', hours: 24, service: 'Chân dung 2 giờ', counterpart: 'An Studio (seed)', day: 'T7 10/10', start: '08:00' } },
  { uid: LAN, id: 'n_refund_done_seed-booking-cancelled', ageHours: 30, read: true, target: '/b/seed-booking-cancelled',
    content: { type: 'refund_done', amount: 450_000, bookingId: 'seed-booking-cancelled' } },
  { uid: LAN, id: 'n_booking_declined_seed-booking-declined', ageHours: 12 * 24, read: true, target: '/b/seed-booking-declined',
    content: { type: 'booking_declined', reason: 'declined', photographer: 'Bình (seed)', percent: 100 } },
  { uid: LAN, id: `g_chat_${SEED_CHAT}`, ageHours: 2, read: false, target: `/chat/${SEED_CHAT}`,
    content: { type: 'chat_message', sender: 'An Studio (seed)', preview: 'Chào bạn', count: 2 },
    group: { key: `chat:${SEED_CHAT}`, count: 2, lastEventId: 'seed-message-2' } },
  { uid: AN, id: 'n_booking_request_seed-booking-requested-an', ageHours: 3, read: false, target: '/bookings',
    content: { type: 'booking_request', customer: 'Lan (seed)', service: 'Chân dung 2 giờ', day: 'T7 25/10', start: '16:00' } },
  { uid: AN, id: 'n_review_new_seed-booking-completed-recent', ageHours: 48, read: true, target: `/u/${AN}?tab=reviews`,
    content: { type: 'review_new', customer: 'Lan (seed)', rating: 5, text: 'Rất hài lòng, đúng giờ.' } },
];

/** Inbox rows, unread counts and badges (plan 10a). Defaults apply to everyone: no prefs doc. */
function notificationAndBadgeDocuments(now: Date): SeedDocument[] {
  const docs: SeedDocument[] = [];
  const unread = new Map<string, number>();
  for (const r of SEED_ROWS) {
    const meta = NOTIFICATION_TYPES[r.content.type as NotificationType];
    const at = new Date(now.getTime() - r.ageHours * HOUR_MS);
    if (!r.read) unread.set(r.uid, (unread.get(r.uid) ?? 0) + 1);
    docs.push({
      path: `users/${r.uid}/notifications/${r.id}`,
      data: {
        type: r.content.type,
        tab: meta.tab,
        category: meta.category,
        ...renderNotification(r.content),
        target: r.target,
        groupKey: r.group?.key ?? null,
        actors: [r.uid === LAN ? ACTOR_AN : ACTOR_LAN],
        count: r.group?.count ?? 1,
        thumbUrl: null,
        lastEventId: r.group?.lastEventId ?? null,
        createdAt: at,
        readAt: r.read ? new Date(at.getTime() + HOUR_MS / 2) : null,
      },
    });
  }
  for (const uid of [LAN, AN]) {
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
  earned(AN, 'top_rated', '4,9 sao từ 58 đánh giá', 20);
  earned(AN, 'shoots_10', 'Hoàn thành 12 buổi', 10);
  earned(AN, 'complete_profile', 'Đủ ảnh và gói', 25);
  earned(LAN, 'loyal_customer', 'Hoàn thành 3 buổi chụp', 5);
  const progress = (uid: string, entries: Record<string, { current: number; target: number }>) =>
    docs.push({ path: `users/${uid}/private/badgeProgress`, data: { entries, updatedAt: now } });
  // Equal to what the evaluator computes from the seeded data, so a trigger run changes nothing.
  const anShoots = SEED_BOOKINGS.filter((b) => b.photographerId === AN && b.status === 'completed').length;
  progress(AN, { punctual: { current: 3, target: 5 }, shoots_50: { current: Math.min(anShoots, 50), target: 50 } });
  progress(LAN, { sharer: { current: 0, target: 5 }, detailed_reviewer: { current: 0, target: 5 } });
  return docs;
}
