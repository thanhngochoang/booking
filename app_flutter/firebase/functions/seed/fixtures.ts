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
  computeNextFreeDate,
  computeStartingPrice,
  encodeGeohash,
  formatVnDate,
  formatVnTime,
  assignDeadlineFor,
  foldNameKey,
  inviteExpiresAt,
  parseVnDateTime,
  relationId,
  studioDayMark,
  hashtagBase,
  hashtagKeyOf,
  earningItemOf,
  emptyVerification,
  fakeIdNumberOf,
  feeFor,
  newSubjectPayment,
  verificationFeeKey,
  PLATFORM_PAYEE,
  PLATFORM_REVENUE_ACCOUNT,
  maskLegalName,
  providerTypeOf,
  PROVIDER_RULES_VERSION,
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
  EMPTY_COUNTERS,
  recruitFilterKeys,
  recruitMatchKeys,
  recruitMatchKeysOf,
  type Chat,
  type RecruitCounters,
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
  type VerificationRecord,
  EMPTY_SPOT_STATS,
  type Spot,
  type SpotSchedule,
  type SlotOffer,
  DISPUTE_OPENED_TEXT,
  DISPUTE_WINDOW_HOURS,
  disputeEscrowPayment,
  disputeThreadId,
  disputeWindow,
  parseOpenDisputeInput,
  ticketIdempotencyKey,
  ticketPayeeOf,
  truncateGraphemes,
  type Dispute,
  type DisputeReason,
  type SupportMessage,
  type SupportThread,
} from '@photobooking/domain';
import { encryptSyncForSeed } from '../src/infra/account_cipher.js';
import { toFirestoreChat, toFirestoreMessage } from '../src/infra/chat_firestore.js';
import { eventToFirestore, groupChatToFirestore, registrationToFirestore } from '../src/infra/event_firestore.js';
import { earningItemToFirestore } from '../src/infra/earnings_firestore.js';
import { accountToFirestore, accountViewToFirestore, payoutToFirestore } from '../src/infra/payout_firestore.js';
import { devEncryptIdForSeed, devHashIdSync } from '../src/infra/identity_vault.js';
import { identityToFirestore, verificationToFirestore } from '../src/infra/verification_firestore.js';
import { bookingFromFirestore, ledgerEntryToFirestore, paymentToFirestore } from '../src/infra/booking_firestore.js';
import { bookingDisputeView, disputeToFirestore } from '../src/infra/dispute_firestore.js';
import { supportMessageToFirestore, supportThreadToFirestore } from '../src/infra/support_firestore.js';
import { relationToFirestore } from '../src/infra/studio_firestore.js';
import {
  applicationToDoc,
  collaborationToDoc,
  countersToDoc,
  recruitPostToDoc,
} from '../src/infra/recruit_mapping.js';
import {
  spotToFirestore,
  scheduleToFirestore,
  offerToFirestore,
  spotDayToFirestore,
} from '../src/infra/spot_firestore.js';
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
/** Unverified photographer whose S21 verification waits for staff (`npm run verifications -- approve`). */
export const GIANG = 'seed-photographer-giang';
/** Verified individual in TP.HCM, in no studio: the S27 applicant Cúc can accept (#151). */
export const HOA = 'seed-photographer-hoa';
/** Staff account with the custom claim `staffRole: 'admin'` (reviews awards; see `applySeed`). */
export const ADMIN = 'seed-staff-admin';

export interface SeedUser {
  readonly uid: string;
  readonly email: string;
  readonly displayName: string;
  readonly role: 'customer' | 'photographer';
  /** Custom auth claim `staffRole`, set by `applySeed`. */
  readonly staffRole?: 'admin';
  /** Auth phone (E.164) as if linked by the S21.01 OTP, set by `applySeed`. */
  readonly phoneNumber?: string;
}

export const SEED_USERS: readonly SeedUser[] = [
  { uid: LAN, email: 'lan.customer@seed.test', displayName: 'Lan (seed)', role: 'customer' },
  { uid: MINH, email: 'minh.nophone@seed.test', displayName: 'Minh (seed, no phone)', role: 'customer' },
  { uid: AN, email: 'an.verified@seed.test', displayName: 'An Studio (seed)', role: 'photographer' },
  { uid: BINH, email: 'binh.unverified@seed.test', displayName: 'Bình (seed)', role: 'photographer' },
  { uid: CUC, email: 'cuc.studio@seed.test', displayName: 'Cúc Studio (seed)', role: 'photographer' },
  { uid: DUNG, email: 'dung.artist@seed.test', displayName: 'Dũng (seed, nghệ sĩ)', role: 'photographer' },
  { uid: GIANG, email: 'giang.pending@seed.test', displayName: 'Giang (seed, chờ duyệt)', role: 'photographer', phoneNumber: '+84976000001' },
  { uid: HOA, email: 'hoa.ctv@seed.test', displayName: 'Hòa (seed, CTV)', role: 'photographer' },
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
  {
    uid: GIANG,
    verified: false,
    bio: 'Chân dung ngoài trời, mới tham gia.',
    city: 'Cần Thơ',
    radiusKm: 15,
    specialties: ['portrait'],
    channels: { call: true, zalo: false, whatsapp: false, acceptInquiries: true },
    numbers: { phone: '+84976000001' },
  },
  {
    uid: HOA,
    verified: true,
    bio: 'Chụp cưới và gia đình, nhận làm cộng tác viên.',
    city: 'TP.HCM',
    radiusKm: 20,
    specialties: ['wedding', 'family'],
    channels: { call: true, zalo: false, whatsapp: false, acceptInquiries: true },
    numbers: { phone: '+84909000001' },
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
  // Cúc's package: the studio bookings (S26) and the "one booking per free member" day (Decision 26).
  { id: 'seed-service-studio-family', photographerId: CUC, name: 'Gia đình tại studio 2 giờ', price: 2_500_000, durationMinutes: 120 },
];

export interface SeedAddon {
  readonly id: string;
  readonly providerId: string;
  readonly kind: 'makeup' | 'retouch' | 'transport' | 'outfit' | 'other';
  readonly name: string;
  readonly description?: string;
  /** Integer VND. */
  readonly price: number;
  readonly unit: 'per_booking' | 'per_person' | 'per_item';
  readonly maxQty: number;
  /** `[]` = every package. */
  readonly serviceIds: readonly string[];
}

/** Service add-ons (S04.01, S08.06): An three, Cúc one studio add-on. All active. */
export const SEED_ADDONS: readonly SeedAddon[] = [
  {
    id: 'seed-addon-makeup', providerId: AN, kind: 'makeup', name: 'Trang điểm',
    description: 'Trang điểm tự nhiên, làm tóc cơ bản', price: 800_000, unit: 'per_person', maxQty: 4, serviceIds: [],
  },
  {
    id: 'seed-addon-retouch', providerId: AN, kind: 'retouch', name: 'Chỉnh thêm ảnh',
    description: 'Hậu kỳ thêm ngoài số ảnh của gói', price: 20_000, unit: 'per_item', maxQty: 10, serviceIds: [],
  },
  {
    id: 'seed-addon-car', providerId: AN, kind: 'transport', name: 'Xe đón trong nội thành',
    description: 'Đón đi và đưa về, xe 4 chỗ', price: 300_000, unit: 'per_booking', maxQty: 1,
    serviceIds: ['seed-service-portrait'],
  },
  {
    id: 'seed-addon-outfit', providerId: CUC, kind: 'outfit', name: 'Thuê áo dài',
    price: 250_000, unit: 'per_item', maxQty: 4, serviceIds: [],
  },
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
  /** Lan's open S18 dispute on it (`seedDispute`): the reason code and what she wrote. */
  readonly dispute?: { readonly reason: DisputeReason; readonly description: string };
  /** Completed inside the 24-hour dispute window: the money is still held (S18.01 to try). */
  readonly heldInWindow?: true;
  /** A studio booking (#136): its member, or null while unassigned. */
  readonly studio?: { readonly assigneeId: string | null };
}

export const SEED_BOOKINGS: readonly SeedBooking[] = [
  { id: 'seed-booking-accepted', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'accepted', date: '2026-10-20', start: '08:00', end: '10:00', place: 'Hồ Hoàn Kiếm, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-upcoming', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'upcoming', date: '2026-10-10', start: '08:00', end: '10:00', place: 'Công viên Thống Nhất, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-requested-binh', customerId: LAN, photographerId: BINH, serviceId: 'seed-service-family', status: 'requested', date: '2026-10-25', start: '16:00', end: '17:30', place: 'Biển Mỹ Khê, Đà Nẵng', completedDaysAgo: null },
  { id: 'seed-booking-cancelled', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'cancelled', date: '2026-10-22', start: '08:00', end: '10:00', place: 'Văn Miếu, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-completed-recent', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'completed', date: '2026-09-27', start: '08:00', end: '10:00', place: 'Hồ Tây, Hà Nội', completedDaysAgo: 3 },
  { id: 'seed-booking-completed-old', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'completed', date: '2026-08-20', start: '08:00', end: '10:00', place: 'Phố cổ, Hà Nội', completedDaysAgo: 40 },
  // Completed 10 hours before seeding, then disputed by Lan an hour later (`seed-dispute-lan-an`): the money stays on hold (S06.05 row with a reason).
  { id: 'seed-booking-disputed', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'completed', date: '2026-09-29', start: '08:00', end: '10:00', place: 'Hồ Gươm, Hà Nội', completedDaysAgo: 10 / 24, dispute: { reason: 'photos_missing', description: 'Ảnh giao thiếu so với gói: gói 2 giờ có 40 ảnh chỉnh, mới nhận 20 ảnh.' } },
  // S18.01 to try: completed 2 hours before seeding, money still held, 22 hours left to report a problem.
  { id: 'seed-booking-completed-window', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'completed', date: '2026-09-30', start: '14:00', end: '16:00', place: 'Nhà hát Lớn, Hà Nội', completedDaysAgo: 2 / 24, heldInWindow: true },
  // Two-layer delivery seed bookings (S05/S06):
  { id: 'seed-booking-shot', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'shot', date: '2026-10-14', start: '14:00', end: '16:00', place: 'Hồ Gươm, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-delivered', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'delivered', date: '2026-10-13', start: '14:00', end: '16:00', place: 'Hồ Tây, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-revision', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'revision_requested', date: '2026-10-12', start: '14:00', end: '16:00', place: 'Bảo tàng Dân tộc học, Hà Nội', completedDaysAgo: null },
  { id: 'seed-booking-approved', customerId: LAN, photographerId: AN, serviceId: 'seed-service-portrait', status: 'approved', date: '2026-10-11', start: '14:00', end: '16:00', place: 'Cầu Long Biên, Hà Nội', completedDaysAgo: null },
];

// ---- Studio (S26, #136) ----

export const SEED_STUDIO_ASSIGNED = 'seed-booking-studio-assigned';
export const SEED_STUDIO_UNASSIGNED = 'seed-booking-studio-unassigned';
/** An joined Cúc this long before seeding. */
export const SEED_STUDIO_JOINED_DAYS_AGO = 30;

/** The start of an hour-aligned 2-hour slot near `at` in Vietnam time, kept within one day (09:00–21:00). */
function vnSlot(at: Date): { date: string; start: string; end: string } {
  const hourStart = new Date(Math.floor(at.getTime() / HOUR_MS) * HOUR_MS);
  const date = formatVnDate(hourStart);
  const hour = Number(formatVnTime(hourStart).slice(0, 2));
  const h = Math.min(21, hour);
  const pad = (n: number) => String(n).padStart(2, '0');
  return { date, start: `${pad(h)}:00`, end: `${pad(h + 2)}:00` };
}

/** Days An's own calendar holds (seed bookings and the three seed events), before any studio job. */
function anOwnDays(now: Date): Set<string> {
  const days = new Set<string>();
  for (const b of SEED_BOOKINGS) if (b.photographerId === AN && b.status !== 'cancelled') days.add(b.date);
  for (const h of [8 * 24 + 2, 15 * 24 + 2, 36]) days.add(formatVnDate(new Date(now.getTime() + h * HOUR_MS)));
  return days;
}

/**
 * Lan ↔ Cúc, both accepted: one assigned to An three days ahead (or the next day An is free), one unassigned
 * starting about 20 hours after seeding (its assign deadline has passed, so the first bookingClock marks it overdue).
 */
export function studioSeedBookings(now: Date): SeedBooking[] {
  const base = { customerId: LAN, photographerId: CUC, serviceId: 'seed-service-studio-family', status: 'accepted', completedDaysAgo: null };
  const anDays = anOwnDays(now);
  let ahead = 3;
  while (anDays.has(formatVnDate(new Date(now.getTime() + ahead * DAY_MS)))) ahead += 1;
  const assigned = { date: formatVnDate(new Date(now.getTime() + ahead * DAY_MS)), start: '09:00', end: '11:00' };
  const unassigned = vnSlot(new Date(now.getTime() + 20 * HOUR_MS));
  return [
    { ...base, id: SEED_STUDIO_ASSIGNED, ...assigned, place: 'Studio Cúc, Quận 1', studio: { assigneeId: AN } },
    { ...base, id: SEED_STUDIO_UNASSIGNED, ...unassigned, place: 'Công viên Tao Đàn, TP.HCM', studio: { assigneeId: null } },
  ];
}

/** Days An is not free for Cúc: An's own calendar and the studio job. */
function anBusyDays(now: Date): Set<string> {
  const days = anOwnDays(now);
  for (const b of studioSeedBookings(now)) if (b.studio?.assigneeId === AN) days.add(b.date);
  return days;
}

/** `studio_day_load` of Cúc per day, and the days its one member leaves full (Decision 26). */
function studioLoads(now: Date): { day: string; unassignedIds: string[]; assignedIds: string[]; full: boolean }[] {
  const byDay = new Map<string, { unassignedIds: string[]; assignedIds: string[] }>();
  for (const b of studioSeedBookings(now)) {
    const l = byDay.get(b.date) ?? { unassignedIds: [], assignedIds: [] };
    (b.studio?.assigneeId ? l.assignedIds : l.unassignedIds).push(b.id);
    byDay.set(b.date, l);
  }
  const busy = anBusyDays(now);
  return [...byDay.entries()].map(([day, l]) => ({
    day,
    ...l,
    full:
      studioDayMark(null, { studioOff: false, memberDays: [{ uid: AN, verified: true, free: !busy.has(day) }], ...l }) ===
      'set_full',
  }));
}

/** Cúc's relations: An active, Bình invited (expires in 5 days), Dũng's open join request. */
function studioMemberDocuments(now: Date): SeedDocument[] {
  const joinedAt = new Date(now.getTime() - SEED_STUDIO_JOINED_DAYS_AGO * DAY_MS);
  const names: Record<string, string> = Object.fromEntries(SEED_USERS.map((u) => [u.uid, u.displayName]));
  const rel = (memberId: string, createdAt: Date, over: Record<string, unknown>) => {
    const id = relationId(CUC, memberId, createdAt);
    return {
      path: `studio_members/${id}`,
      data: relationToFirestore({
        id, studioId: CUC, memberId, status: 'invited', initiatedBy: 'studio',
        createdAt: createdAt.toISOString(), expiresAt: inviteExpiresAt(createdAt),
        respondedAt: null, joinedAt: null, endedAt: null, endedBy: null, expiringNotifiedAt: null,
        studioName: names[CUC] ?? '', studioAvatarUrl: null, memberName: names[memberId] ?? '', memberAvatarUrl: null,
        version: 1,
        ...over,
      }),
    };
  };
  const anInvited = new Date(joinedAt.getTime() - DAY_MS);
  return [
    rel(AN, anInvited, { status: 'active', respondedAt: joinedAt.toISOString(), joinedAt: joinedAt.toISOString(), version: 2 }),
    rel(BINH, new Date(now.getTime() - 2 * DAY_MS), {}),
    rel(DUNG, new Date(now.getTime() - DAY_MS), { status: 'requested', initiatedBy: 'member' }),
  ];
}

// ---- S27 studio recruiting (#151) ----

export const SEED_RECRUIT_POST_CUC = 'seed-recruit-cuc-ctv';
export const SEED_COLLAB_DEFAULT_FEE = 600_000;

/**
 * Cúc's open collaborator post (TP.HCM Q1/Q3, cưới and gia đình; keys computed by the domain), two applied
 * applications to it: Hòa's (a verified individual in no studio: Cúc can accept it, the S27.05 accept path) and
 * An's (An is also Cúc's S26 member, so Cúc can only decline it: accepting is membership_conflict), the active
 * collaboration Cúc–Dũng (default fee 600.000₫) and the counters these imply.
 */
function recruitDocuments(now: Date): SeedDocument[] {
  const createdAt = new Date(now.getTime() - 2 * DAY_MS);
  const cuc = SEED_USERS.find((u) => u.uid === CUC)?.displayName ?? '';
  const dung = SEED_USERS.find((u) => u.uid === DUNG)?.displayName ?? '';
  const an = SEED_USERS.find((u) => u.uid === AN)?.displayName ?? '';
  const hoa = SEED_USERS.find((u) => u.uid === HOA)?.displayName ?? '';
  const areas = ['hcm-q1', 'hcm-q3'];
  const specialties = ['wedding', 'family'];
  const title = 'Tuyển CTV chụp cưới cuối tuần';
  const appliedAt = new Date(now.getTime() - DAY_MS);
  const hoaAppliedAt = new Date(now.getTime() - 3 * HOUR_MS);
  const activeAt = new Date(now.getTime() - 10 * DAY_MS);
  const counters = (patch: Partial<RecruitCounters>): Record<string, unknown> => countersToDoc({ ...EMPTY_COUNTERS, ...patch });
  return [
    {
      path: `recruitPosts/${SEED_RECRUIT_POST_CUC}`,
      data: recruitPostToDoc({
        id: SEED_RECRUIT_POST_CUC,
        studioId: CUC,
        studio: { name: cuc, avatarUrl: null, businessVerified: false },
        kind: 'collaborator',
        title,
        specialties,
        areas,
        frequency: 'weekly',
        feeHint: { type: 'per_shoot', amount: 800_000 },
        requirements: 'Có máy full-frame, đã chụp cưới ít nhất một năm.',
        status: 'open',
        renewed: false,
        applicationCount: 2,
        matchKeys: recruitMatchKeys(areas, specialties),
        filterKeys: recruitFilterKeys({ kind: 'collaborator', areas, specialties }),
        createdAt,
        updatedAt: hoaAppliedAt,
        expiresAt: new Date(createdAt.getTime() + 30 * DAY_MS),
        closedAt: null,
      }),
    },
    {
      path: `recruitApplications/${SEED_RECRUIT_POST_CUC}_${AN}`,
      data: applicationToDoc({
        id: `${SEED_RECRUIT_POST_CUC}_${AN}`,
        postId: SEED_RECRUIT_POST_CUC,
        studioId: CUC,
        applicantId: AN,
        kind: 'collaborator',
        postTitle: title,
        applicant: { name: an, avatarUrl: null },
        status: 'applied',
        message: 'Em chụp cưới 3 năm, rảnh cuối tuần.',
        samplePostIds: [],
        termsAcceptedAt: appliedAt,
        createdAt: appliedAt,
        expiresAt: new Date(appliedAt.getTime() + 7 * DAY_MS),
        respondedAt: null,
      }),
    },
    {
      path: `recruitApplications/${SEED_RECRUIT_POST_CUC}_${HOA}`,
      data: applicationToDoc({
        id: `${SEED_RECRUIT_POST_CUC}_${HOA}`,
        postId: SEED_RECRUIT_POST_CUC,
        studioId: CUC,
        applicantId: HOA,
        kind: 'collaborator',
        postTitle: title,
        applicant: { name: hoa, avatarUrl: null },
        status: 'applied',
        message: 'Em ở Quận 3, chụp cưới 2 năm, nhận được các buổi cuối tuần.',
        samplePostIds: [],
        termsAcceptedAt: hoaAppliedAt,
        createdAt: hoaAppliedAt,
        expiresAt: new Date(hoaAppliedAt.getTime() + 7 * DAY_MS),
        respondedAt: null,
      }),
    },
    {
      path: `studio_collaborations/${CUC}_${DUNG}`,
      data: collaborationToDoc({
        id: `${CUC}_${DUNG}`,
        studioId: CUC,
        collaboratorId: DUNG,
        studio: { name: cuc, avatarUrl: null },
        collaborator: { name: dung, avatarUrl: null },
        status: 'active',
        initiatedBy: 'studio',
        applicationId: null,
        defaultFee: SEED_COLLAB_DEFAULT_FEE,
        termsAcceptedAt: activeAt,
        createdAt: new Date(activeAt.getTime() - DAY_MS),
        expiresAt: new Date(activeAt.getTime() + 6 * DAY_MS),
        activeAt,
        endedAt: null,
        endedBy: null,
        updatedAt: activeAt,
      }),
    },
    { path: `photographers/${CUC}/private/recruit`, data: counters({ openPostCount: 1, activeCollabCount: 1 }) },
    { path: `photographers/${DUNG}/private/recruit`, data: counters({ activeCollabCount: 1 }) },
    { path: `photographers/${AN}/private/recruit`, data: counters({ openApplicationCount: 1 }) },
    { path: `photographers/${HOA}/private/recruit`, data: counters({ openApplicationCount: 1 }) },
  ];
}

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
  readonly spotId?: string;
}

export const SEED_ALBUM_FAMILY = 'seed-album-an-family';
export const SEED_ALBUM_STREET = 'seed-album-an-street';

export const SEED_SPOT_CAU_DAT = 'seed-spot-cau-dat';
export const SEED_SPOT_HOI_AN = 'seed-spot-hoi-an';
export const SEED_SPOT_HO_TAY = 'seed-spot-ho-tay';
export const SEED_SPOT_CAU_VANG = 'seed-spot-cau-vang';
export const SEED_SPOT_MU_CANG_CHAI = 'seed-spot-mu-cang-chai';

export const SEED_SCHEDULE_AN_HO_TAY = 'seed-schedule-an-ho-tay';
export const SEED_OFFER_AN_BINH_MINH = 'seed-offer-an-binh-minh';

/** An's `work` posts: two in "Gia đình", one in "Đường phố", two only on the timeline. */
export const SEED_POSTS: readonly SeedPost[] = [
  { id: 'seed-post-an-1', photographerId: AN, images: 3, caption: 'Buổi chiều ở Hồ Tây', album: { id: SEED_ALBUM_FAMILY, position: 1 }, spotId: SEED_SPOT_HO_TAY },
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

export interface SeedFollow {
  readonly userId: string;
  readonly photographerId: string;
}

export const SEED_FOLLOWS: readonly SeedFollow[] = [
  { userId: LAN, photographerId: AN },
  { userId: MINH, photographerId: AN },
  { userId: LAN, photographerId: DUNG },
];

export interface SeedLike {
  readonly userId: string;
  readonly postId: string;
}

export const SEED_LIKES: readonly SeedLike[] = [
  { userId: LAN, postId: 'seed-post-an-1' },
  { userId: MINH, postId: 'seed-post-an-1' },
];

export interface SeedSave {
  readonly userId: string;
  readonly postId: string;
}

export const SEED_SAVES: readonly SeedSave[] = [
  { userId: LAN, postId: 'seed-post-an-1' },
  { userId: LAN, postId: 'seed-post-an-2' },
];

export interface SeedSavedPhotographer {
  readonly userId: string;
  readonly photographerId: string;
}

export const SEED_SAVED_PHOTOGRAPHERS: readonly SeedSavedPhotographer[] = [
  { userId: LAN, photographerId: CUC },
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

/**
 * `instant_config/current` (#140 Decisions 6, 9, 19, 27; test values): three packages, three cities by
 * bounding box with surge ×1.0, and the twelve built-in areas of `lib/data/location/area.dart`
 * (names and centres copied) for the offer's area label.
 */
export const SEED_INSTANT_CONFIG = {
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
} as const;

export interface SeedDocument {
  readonly path: string;
  readonly data: Record<string, unknown>;
}

const TIMELINE: Readonly<Record<string, readonly string[]>> = {
  requested: ['requested'],
  accepted: ['requested', 'accepted'],
  upcoming: ['requested', 'accepted', 'upcoming'],
  shot: ['requested', 'accepted', 'upcoming', 'shot'],
  delivered: ['requested', 'accepted', 'upcoming', 'shot', 'delivered'],
  revision_requested: ['requested', 'accepted', 'upcoming', 'shot', 'delivered', 'revision_requested'],
  approved: ['requested', 'accepted', 'upcoming', 'shot', 'delivered', 'approved'],
  cancelled: ['requested', 'accepted', 'cancelled'],
  completed: ['requested', 'accepted', 'upcoming', 'completed'],
};

function escrowOf(b: SeedBooking): string {
  if (b.dispute !== undefined) return 'disputed';
  if (b.heldInWindow === true) return 'held';
  if (b.id === SEED_PAID_OUT_BOOKING) return 'released';
  return b.status === 'completed' || b.status === 'approved' ? 'released' : b.status === 'cancelled' ? 'refunded' : 'held';
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
  const shotAt = ['shot', 'delivered', 'revision_requested', 'approved', 'completed'].includes(b.status)
    ? new Date(last.getTime() - 2 * HOUR_MS)
    : null;
  const deliveredAt = ['delivered', 'revision_requested', 'approved'].includes(b.status)
    ? new Date(last.getTime() - HOUR_MS)
    : null;
  const approvedAt = b.status === 'approved' ? last : null;
  const checkUntil = b.status === 'approved'
    ? new Date(now.getTime() + 47 * HOUR_MS)
    : null;
  const autoApproveAt = b.status === 'delivered'
    ? new Date(now.getTime() + 71 * HOUR_MS)
    : null;
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
    shotAt,
    deliveredAt,
    approvedAt,
    checkUntil,
    autoApproveAt,
    deliveryRound: ['delivered', 'revision_requested', 'approved'].includes(b.status) ? 1 : 0,
    revisionsIncluded: 1,
    revisionsUsed: b.status === 'revision_requested' ? 1 : 0,
    timeline,
    createdAt,
    updatedAt: last,
    version: steps.length,
    ...(b.studio !== undefined ? studioFieldsOf(b, createdAt, last) : {}),
  };
}

/** The studio fields of a seeded studio booking, as `studioDraftFields` and `assignBooking` write them. */
function studioFieldsOf(b: SeedBooking, createdAt: Date, assignedAt: Date): Record<string, unknown> {
  const assigneeId = b.studio?.assigneeId ?? null;
  return {
    isStudio: true,
    assigneeId,
    assigneeKind: assigneeId === null ? null : 'member',
    assignStatus: assigneeId === null ? 'unassigned' : 'assigned',
    assignDeadline: assignDeadlineFor(parseVnDateTime(b.date, b.start), createdAt),
    assignOverdue: false,
    assignedAt: assigneeId === null ? null : assignedAt,
    assignments:
      assigneeId === null ? [] : [{ assigneeId, assigneeKind: 'member', at: assignedAt, by: b.photographerId, reason: null, late: false }],
    assignRemindersSent: [],
    changeRequest: null,
    studioFault: null,
    assignmentReturned: null,
  };
}

export const SEED_DISPUTE_LAN_AN = 'seed-dispute-lan-an';
export const SEED_BOOKING_COMPLETED_WINDOW = 'seed-booking-completed-window';

/**
 * S18 (#142, Decision 17): Lan's open dispute on a seeded booking, opened an hour after completion and
 * built with the domain's own rules (input parser, dispute window, whole-payment freeze of a payment
 * without milestones, thread id), as `openDispute` would: the dispute, the payment's `dispute` record,
 * and its thread with the system line, Lan's description, a staff question and An's answer (so the
 * thread waits for staff).
 */
function seedDispute(
  b: SeedBooking,
  bData: Record<string, unknown>,
  paymentData: Record<string, unknown>,
  paymentId: string,
): { dispute: Dispute; paymentDispute: unknown; docs: SeedDocument[] } {
  if (b.dispute === undefined) throw new Error(`seed: ${b.id} has no dispute`);
  const booking = bookingFromFirestore(b.id, bData);
  if (booking === null) throw new Error(`seed: ${b.id} does not map to a booking`);
  const nameOf = (uid: string) => SEED_USERS.find((u) => u.uid === uid)?.displayName ?? '';
  const view = bookingDisputeView({ ...booking, disputeId: null }, { name: nameOf(b.photographerId), avatarUrl: null });
  const completedAt = bData.completedAt as Date;
  const openedAt = new Date(completedAt.getTime() + HOUR_MS);
  const at = openedAt.toISOString();
  disputeWindow(view, openedAt, false);
  const input = parseOpenDisputeInput(
    { disputeId: SEED_DISPUTE_LAN_AN, subjectType: 'booking', subjectId: b.id, reason: b.dispute.reason, description: b.dispute.description, evidencePaths: [] },
    b.customerId,
  );
  const createdAt = (paymentData.createdAt as Date).toISOString();
  const held: Payment = {
    id: paymentId, subjectType: 'booking', subjectId: b.id, payerId: b.customerId, payeeId: b.photographerId, provider: 'fake',
    amount: paymentData.amount as number, status: 'paid', escrowStatus: 'held', idempotencyKey: paymentData.idempotencyKey as string,
    createdAt, updatedAt: createdAt,
  };
  const frozen: Payment = {
    ...disputeEscrowPayment(held, openedAt),
    dispute: { reason: input.reason, openedAt: at, disputeId: input.disputeId, milestone: null, prevEscrowStatus: 'held' },
  };
  if (frozen.escrowStatus !== paymentData.escrowStatus) throw new Error('seed: the disputed payment is not frozen');
  const dispute: Dispute = {
    id: input.disputeId,
    subjectType: 'booking',
    subjectId: b.id,
    eventId: null,
    paymentId,
    customerId: b.customerId,
    providerId: b.photographerId,
    parties: [b.customerId, b.photographerId],
    openedBy: 'customer',
    reason: input.reason,
    description: input.description,
    evidencePaths: input.evidencePaths,
    snapshot: view.snapshot,
    amountHeld: held.amount,
    status: 'open',
    outcome: null,
    threadId: disputeThreadId(input.disputeId),
    createdAt: at,
    updatedAt: at,
    resolvedAt: null,
    version: 1,
  };
  const msgAt = (ms: number) => new Date(openedAt.getTime() + ms).toISOString();
  const message = (i: number, m: Omit<SupportMessage, 'id' | 'threadId'>): SupportMessage =>
    ({ id: `seed-msg-${input.disputeId}-${i}`, threadId: dispute.threadId, ...m });
  const messages: SupportMessage[] = [
    message(1, { senderId: null, senderRole: 'system', senderName: 'Hệ thống', body: DISPUTE_OPENED_TEXT, createdAt: at }),
    message(2, { senderId: b.customerId, senderRole: 'customer', senderName: nameOf(b.customerId), body: input.description, createdAt: msgAt(1) }),
    message(3, {
      senderId: ADMIN, senderRole: 'staff', senderName: 'Hỗ trợ',
      body: 'Chào chị Lan, hỗ trợ đã nhận khiếu nại. Anh An gửi giúp danh sách ảnh đã giao nhé.', createdAt: msgAt(2 * HOUR_MS),
    }),
    message(4, {
      senderId: b.photographerId, senderRole: 'provider', senderName: nameOf(b.photographerId),
      body: 'Em đã giao 20 ảnh chỉnh, 20 ảnh còn lại em gửi trong hôm nay ạ.', createdAt: msgAt(3 * HOUR_MS),
    }),
  ];
  const last = messages[messages.length - 1] as SupportMessage;
  const thread: SupportThread = {
    id: dispute.threadId,
    kind: 'dispute',
    ownerId: null,
    disputeId: dispute.id,
    participants: dispute.parties,
    status: 'open',
    awaitingStaff: true,
    lastMessageAt: last.createdAt,
    lastMessagePreview: truncateGraphemes(last.body, 80),
    lastSenderRole: last.senderRole,
    rate: {},
    createdAt: at,
    updatedAt: last.createdAt,
  };
  return {
    dispute,
    paymentDispute: paymentToFirestore(frozen).dispute,
    docs: [
      { path: `disputes/${dispute.id}`, data: disputeToFirestore(dispute) },
      { path: `support_threads/${thread.id}`, data: supportThreadToFirestore(thread) },
      ...messages.map((m) => ({ path: `support_threads/${thread.id}/messages/${m.id}`, data: supportMessageToFirestore(m) })),
    ],
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
    const baseStats = seedStatsOf(p.uid);
    const servicesOfP = SEED_SERVICES.filter((s) => s.photographerId === p.uid);
    const startingPrice = computeStartingPrice(servicesOfP.map((s) => s.price));
    const completedCount = SEED_BOOKINGS.filter((b) => b.photographerId === p.uid && b.status === 'completed').length;
    // Calculate blocked days for p.uid from bookings and events
    const today = formatVnDate(at);
    const blockedDaysList: string[] = [];
    for (const b of SEED_BOOKINGS) {
      if (b.photographerId === p.uid && (b.status === 'accepted' || b.status === 'upcoming' || b.status === 'completed')) {
        blockedDaysList.push(b.date);
      }
    }
    // Cúc's full days (its one member is busy) and An's studio job.
    if (p.uid === CUC) blockedDaysList.push(...studioLoads(now).filter((l) => l.full).map((l) => l.day));
    if (p.uid === AN) {
      for (const b of studioSeedBookings(now)) if (b.studio?.assigneeId === AN) blockedDaysList.push(b.date);
    }
    // Event days for An
    if (p.uid === AN) {
      // 8 days, 15 days, 36 hours from now
      const freeStart = new Date(now.getTime() + (8 * 24 + 2) * HOUR_MS);
      const paidStart = new Date(now.getTime() + (15 * 24 + 2) * HOUR_MS);
      const soonStart = new Date(now.getTime() + 36 * HOUR_MS);
      blockedDaysList.push(formatVnDate(freeStart), formatVnDate(paidStart), formatVnDate(soonStart));
    }
    const nextFreeDate = computeNextFreeDate(today, new Set(blockedDaysList));

    const stats = {
      reviewCount: 0,
      score: 0,
      ...(baseStats !== null ? baseStats : {}),
      nextFreeDate,
      completedCount,
    };

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
        startingPrice,
        stats,
        approvedAwardCount: SEED_AWARDS.filter((a) => a.photographerId === p.uid && a.status === 'approved').length,
        followerCount: SEED_FOLLOWS.filter((f) => f.photographerId === p.uid).length,
        ...(SEED_FOLLOWS.some((f) => f.photographerId === p.uid) ? { followerCountAt: at } : {}),
        ...(p.studioAddress !== undefined ? { studioDistrict: p.studioAddress.district, studioCity: p.studioAddress.city } : {}),
        // S26: the invite-search key, Cúc's member counts (An is verified) and An's membership (#136).
        nameKey: foldNameKey(SEED_USERS.find((u) => u.uid === p.uid)?.displayName ?? ''),
        ...(p.uid === CUC ? { memberCount: 1, assignableMembers: 1 } : {}),
        // S27 (#151 Decision 7): what onPhotographerWrite keeps (Cúc, a studio, matches nothing).
        recruitMatchKeys: [...recruitMatchKeysOf({
          role: SEED_USERS.find((u) => u.uid === p.uid)?.role,
          providerType: p.providerType,
          serviceArea: { city: p.city, radiusKm: p.radiusKm },
          specialties: p.specialties,
        })].sort(),
        ...(p.uid === AN
          ? { studioId: CUC, studioJoinedAt: new Date(now.getTime() - SEED_STUDIO_JOINED_DAYS_AGO * DAY_MS) }
          : {}),
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
  for (const a of SEED_ADDONS) {
    docs.push({
      path: `photographers/${a.providerId}/addons/${a.id}`,
      data: {
        kind: a.kind,
        name: a.name,
        ...(a.description !== undefined ? { description: a.description } : {}),
        price: a.price,
        unit: a.unit,
        maxQty: a.maxQty,
        serviceIds: [...a.serviceIds],
        active: true,
        createdAt: at,
        updatedAt: at,
      },
    });
  }
  for (const providerId of new Set(SEED_ADDONS.map((a) => a.providerId))) {
    // The lock document of saveAddon/deleteAddon (Decision 8): its count matches the active add-ons.
    docs.push({
      path: `photographers/${providerId}/private/addons`,
      data: { activeCount: SEED_ADDONS.filter((a) => a.providerId === providerId).length, updatedAt: at },
    });
  }
  for (const p of SEED_POSTS) {
    const likeCount = SEED_LIKES.filter((l) => l.postId === p.id).length;
    const saveCount = SEED_SAVES.filter((s) => s.postId === p.id).length;
    docs.push({
      path: `posts/${p.id}`,
      data: {
        kind: 'work',
        authorId: p.photographerId,
        photographerId: p.photographerId,
        serviceId: 'seed-service-portrait',
        imageUrls: Array.from({ length: p.images }, (_, i) => `https://seed.test/${p.id}/${i + 1}.jpg`),
        caption: p.caption,
        likeCount,
        saveCount,
        ...(p.album !== null ? { albumId: p.album.id, albumPosition: p.album.position } : {}),
        ...(p.spotId !== undefined ? { spotId: p.spotId } : {}),
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
  for (const f of SEED_FOLLOWS) {
    docs.push({
      path: `follows/${f.userId}_${f.photographerId}`,
      data: { userId: f.userId, photographerId: f.photographerId, createdAt: at },
    });
  }
  for (const l of SEED_LIKES) {
    docs.push({
      path: `likes/${l.userId}_${l.postId}`,
      data: { userId: l.userId, postId: l.postId, createdAt: at },
    });
  }
  for (const s of SEED_SAVES) {
    docs.push({
      path: `saves/${s.userId}_${s.postId}`,
      data: { userId: s.userId, postId: s.postId, createdAt: at },
    });
  }
  for (const sp of SEED_SAVED_PHOTOGRAPHERS) {
    docs.push({
      path: `savedPhotographers/${sp.userId}_${sp.photographerId}`,
      data: { userId: sp.userId, photographerId: sp.photographerId, createdAt: at },
    });
  }
  const disputeDocs: SeedDocument[] = [];
  for (const b of [...SEED_BOOKINGS, ...studioSeedBookings(now)]) {
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
    const seedPayer = {
      bankCode: 'VCB',
      bankName: 'Vietcombank',
      accountNumberEnc: encryptSyncForSeed(emulatorPayoutKey(), '0071000123456'),
      accountLast4: '3456',
      holderName: 'KHACH THU NGHIEM',
    };
    const refundedAmount = b.status === 'cancelled' ? deposit : 0;
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
      payer: seedPayer,
      refundedAmount,
      ...(paidOut ? { payoutId: SEED_PAYOUT_AN } : {}),
      // Legacy completion: released by the booking clock once the dispute window is over.
      ...(b.heldInWindow === true ? { releaseAfter: new Date(updatedAt.getTime() + DISPUTE_WINDOW_HOURS * HOUR_MS) } : {}),
      createdAt,
      updatedAt,
    };
    if (b.dispute !== undefined) {
      const opened = seedDispute(b, bData, paymentData, paymentId);
      paymentData.dispute = opened.paymentDispute;
      bData.disputeId = opened.dispute.id;
      disputeDocs.push(...opened.docs);
    }
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

    if (b.status === 'completed' && b.dispute === undefined && b.heldInWindow !== true) {
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
          status: 'done',
          method: 'bank_transfer',
          destination: {
            ...seedPayer,
            source: 'payer',
          },
          attempts: 1,
          lastAttemptAt: updatedAt,
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

    // Payment milestones (for delivery-aware bookings: shot, delivered, revision_requested, approved)
    const isDeliveryBooking = ['shot', 'delivered', 'revision_requested', 'approved'].includes(b.status);
    if (isDeliveryBooking) {
      const shootAmount = Math.floor(deposit / 2);
      const deliveryAmount = deposit - shootAmount;
      const shootReleased = ['delivered', 'revision_requested', 'approved'].includes(b.status);
      const deliveryReleased = b.status === 'approved';
      const ms = [
        {
          kind: 'shoot',
          amount: shootAmount,
          status: shootReleased ? 'released' : 'held',
          releaseAfter: new Date(createdAt.getTime() + 24 * HOUR_MS).toISOString(),
          releasedAt: shootReleased ? new Date(createdAt.getTime() + 24 * HOUR_MS).toISOString() : null,
          payoutId: null,
        },
        {
          kind: 'delivery',
          amount: deliveryAmount,
          status: deliveryReleased ? 'released' : 'held',
          releaseAfter: null,
          releasedAt: deliveryReleased ? updatedAt.toISOString() : null,
          payoutId: null,
        },
      ];
      paymentData.milestones = ms;
      paymentData.payableAmount = (shootReleased ? shootAmount : 0) + (deliveryReleased ? deliveryAmount : 0);

      // Mirror subcollection bookings/{id}/milestones/{kind}
      for (const m of ms) {
        docs.push({
          path: `bookings/${b.id}/milestones/${m.kind}`,
          data: m,
        });
      }

      // Add delivery docs
      if (['delivered', 'revision_requested', 'approved'].includes(b.status)) {
        docs.push({
          path: `bookings/${b.id}/deliveries/1`,
          data: {
            bookingId: b.id,
            round: 1,
            samples: [
              { fileId: 's1', path: `deliveries/${b.id}/s1.jpg`, thumbPath: `deliveries/${b.id}/s1_thumb.jpg`, width: 1600, height: 1200 },
              { fileId: 's2', path: `deliveries/${b.id}/s2.jpg`, thumbPath: `deliveries/${b.id}/s2_thumb.jpg`, width: 1600, height: 1200 },
              { fileId: 's3', path: `deliveries/${b.id}/s3.jpg`, thumbPath: `deliveries/${b.id}/s3_thumb.jpg`, width: 1600, height: 1200 },
            ],
            photoCount: 40,
            linkHost: 'drive.google.com',
            note: 'Ảnh đã hoàn thiện',
            submittedAt: updatedAt,
            submittedBy: b.photographerId,
            decision: b.status === 'revision_requested'
              ? {
                  kind: 'request_revision',
                  note: 'Chỉnh thêm màu ấm',
                  photoNotes: [{ sampleIndex: 0, note: 'Tăng sáng' }],
                  at: updatedAt,
                  auto: false,
                  extra: false,
                }
              : b.status === 'approved'
                ? {
                    kind: 'approve',
                    note: null,
                    photoNotes: [],
                    at: updatedAt,
                    auto: false,
                    extra: false,
                  }
                : null,
          },
        });

        docs.push({
          path: `bookings/${b.id}/private/delivery`,
          data: {
            link: 'https://drive.google.com/drive/folders/seed-an-approved',
            round: 1,
            unlockedAt: b.status === 'approved' ? updatedAt : null,
            updatedAt,
          },
        });
      }
    }

    // Availability day. A studio booking holds the studio's day load instead; its member's day is booked.
    if (b.studio !== undefined) {
      if (b.studio.assigneeId !== null) {
        docs.push({
          path: `availability/${b.studio.assigneeId}/days/${b.date}`,
          data: { state: 'booked', bookingId: b.id, updatedAt },
        });
      }
    } else if (b.status === 'requested') {
      docs.push({
        path: `availability/${b.photographerId}/days/${b.date}`,
        data: { state: 'pending', bookingId: b.id, updatedAt },
      });
    } else if (['accepted', 'upcoming', 'shot', 'delivered', 'revision_requested', 'approved', 'completed'].includes(b.status)) {
      docs.push({
        path: `availability/${b.photographerId}/days/${b.date}`,
        data: { state: 'booked', bookingId: b.id, updatedAt },
      });
    }
  }
  docs.push(...disputeDocs);
  docs.push(...reviewDocuments(now));
  docs.push(...notificationAndBadgeDocuments(now));
  docs.push(...payoutAndEarningsDocuments(now, docs));
  docs.push(...eventDocuments(now, docs));
  docs.push(...directChatDocuments(now, docs));
  docs.push(...verificationDocuments(now));
  docs.push(...studioMemberDocuments(now));
  docs.push(...recruitDocuments(now));
  for (const l of studioLoads(now)) {
    docs.push({
      path: `studio_day_load/${CUC}_${l.day}`,
      data: { studioId: CUC, day: l.day, unassignedIds: l.unassignedIds, assignedIds: l.assignedIds, updatedAt: now },
    });
    if (l.full) docs.push({ path: `availability/${CUC}/days/${l.day}`, data: { state: 'full', updatedAt: now } });
  }

  // Chụp ngay server config (#140, plan Task 4): price list v1, fee 0, arrived-cancel split 50.
  docs.push({ path: 'instant_config/current', data: { ...SEED_INSTANT_CONFIG, updatedAt: at } });

  // Explore catalog document (S02)
  docs.push({
    path: 'catalog/explore',
    data: {
      specialties: {
        portrait: { serviceCount: 1, coverUrl: null, updatedAt: at },
        family: { serviceCount: 1, coverUrl: null, updatedAt: at },
      },
      updatedAt: at,
    },
  });

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

/** Giang's legal name on the fake card (test value), and Cúc's (owner of the studio, for S21.04). */
export const SEED_GIANG_LEGAL_NAME = 'NGUYỄN THỊ GIANG';
export const SEED_CUC_LEGAL_NAME = 'TRẦN THỊ CÚC';
/** Minh's fake card says 16: the underage example if Minh switches to a photographer role. */
export const SEED_MINH_FAKE_DOB = '2010-05-01';

/** Giang's verification fee payment (#203; bank QR, paid before she submitted). */
export const SEED_GIANG_FEE_PAYMENT = 'seed-payment-vfee-giang';

/**
 * S21 verification: the verified seed photographers have an approved record from before the fee
 * (#203 grandfathers them: `steps.fee` stays null); Giang has a submitted one (phone, the 99.000₫
 * fee paid by bank QR, fake identity and rules done) for the staff CLI; Bình has none and walks
 * the whole flow, fee included; Cúc's identity (fake id number of her uid)
 * lets her household tax code (that same number) match in S21.04. Identity docs hold the dev-vault
 * hash and ciphertext of `fakeIdNumberOf(uid)`, so a second account presenting it gets
 * `identity_in_use`.
 */
function verificationDocuments(now: Date): SeedDocument[] {
  const at = SEED_CREATED_AT;
  const docs: SeedDocument[] = [];
  const done = (uid: string, legalName: string, doneAt: Date, status: VerificationRecord['status']): VerificationRecord => {
    const iso = doneAt.toISOString();
    const p = SEED_PHOTOGRAPHERS.find((x) => x.uid === uid);
    const base = emptyVerification(uid, p?.providerType === 'studio' ? 'studio' : 'individual', doneAt);
    return {
      ...base,
      status,
      steps: {
        phone: { doneAt: iso },
        fee: null,
        identity: { method: 'vneid', checkedAt: iso, result: 'passed', failure: null, maskedName: maskLegalName(legalName) },
        rules: { acceptedAt: iso, version: PROVIDER_RULES_VERSION },
      },
      identityAttempts: { dayKey: formatVnDate(doneAt), count: 1 },
      submittedAt: iso,
      ...(status === 'approved' ? { decidedAt: iso, decidedBy: ADMIN } : {}),
      version: 5,
    };
  };
  const identity = (uid: string, legalName: string, dob: string, gender: 'male' | 'female', verifiedAt: Date) => {
    const idNumber = fakeIdNumberOf(uid);
    const idHash = devHashIdSync(idNumber);
    docs.push({
      path: `users/${uid}/private/identity`,
      data: identityToFirestore({
        legalName, dob, gender, idNumberEnc: devEncryptIdForSeed(idNumber), idHash, method: 'vneid', provider: 'fake',
        providerRef: `fake_ref_${uid}`, verifiedAt: verifiedAt.toISOString(),
      }),
    });
    docs.push({ path: `identity_hashes/${idHash}`, data: { uid, createdAt: verifiedAt } });
  };

  // Approved: mirrors `verified: true` on photographers/{uid}. An's identity doc is the payout seed's.
  for (const [uid, name] of [[AN, SEED_AN_LEGAL_NAME.toUpperCase()], [CUC, SEED_CUC_LEGAL_NAME], [DUNG, 'LÊ VĂN DŨNG'], [HOA, 'PHẠM THỊ HÒA']] as const) {
    docs.push({ path: `verifications/${uid}`, data: verificationToFirestore(done(uid, name, at, 'approved')) });
  }
  identity(CUC, SEED_CUC_LEGAL_NAME, '1988-03-08', 'female', at);

  // Giang: submitted 26 hours before seeding, so `npm run verifications -- list` marks it overdue (!).
  // Her fee was paid 30 minutes earlier: a released platform payment (never earnings, never
  // payouts) with the ledger entries the fee settler writes.
  const submitted = new Date(now.getTime() - 26 * HOUR_MS);
  const feePaidAt = new Date(submitted.getTime() - 30 * 60_000);
  const feeOpened = new Date(feePaidAt.getTime() - 5 * 60_000);
  const fee = feeFor('individual');
  const opened = newSubjectPayment({
    id: SEED_GIANG_FEE_PAYMENT,
    subjectType: 'verification_fee',
    subjectId: GIANG,
    payerId: GIANG,
    payeeId: PLATFORM_PAYEE,
    amount: fee,
    method: 'bank_qr',
    provider: 'fake',
    idempotencyKey: verificationFeeKey(GIANG, 1, 'bank_qr'),
    now: feeOpened,
    expiresAt: new Date(feeOpened.getTime() + PAYMENT_EXPIRY_MINUTES * 60_000),
  });
  const paidIso = feePaidAt.toISOString();
  docs.push({
    path: `payments/${SEED_GIANG_FEE_PAYMENT}`,
    data: paymentToFirestore({
      ...opened,
      status: 'paid',
      escrowStatus: 'released',
      receivedAmount: fee,
      paidAt: paidIso,
      releasedAt: paidIso,
      updatedAt: paidIso,
    }),
  });
  for (const [suffix, type, owner] of [
    ['received', 'payment_received', 'platform_escrow'],
    ['charged', 'fee_charged', PLATFORM_REVENUE_ACCOUNT],
  ] as const) {
    docs.push({
      path: `ledger_entries/seed-ledger-vfee-giang-${suffix}`,
      data: ledgerEntryToFirestore({
        id: `seed-ledger-vfee-giang-${suffix}`,
        type,
        paymentId: SEED_GIANG_FEE_PAYMENT,
        subjectType: 'verification_fee',
        subjectId: GIANG,
        accountOwnerId: owner,
        amount: fee,
        note: `Seed verification fee for ${GIANG}`,
        at: paidIso,
      }),
    });
  }
  const giangRecord = done(GIANG, SEED_GIANG_LEGAL_NAME, submitted, 'submitted');
  docs.push({
    path: `verifications/${GIANG}`,
    data: verificationToFirestore({
      ...giangRecord,
      steps: { ...giangRecord.steps, fee: { paymentId: SEED_GIANG_FEE_PAYMENT, amount: fee, paidAt: paidIso } },
    }),
  });
  identity(GIANG, SEED_GIANG_LEGAL_NAME, '1996-04-12', 'female', submitted);
  const giang = SEED_PHOTOGRAPHERS.find((p) => p.uid === GIANG);
  docs.push({
    path: `users/${GIANG}/private/contact`,
    data: { phone: giang?.numbers.phone, phoneVerified: true, allowZalo: false, allowWhatsApp: false, updatedAt: submitted },
  });

  // Fake identity override (server-only, emulator/dev): Minh is under 18 on the fake card.
  docs.push({ path: `fake_identities/${MINH}`, data: { dob: SEED_MINH_FAKE_DOB } });
  return docs;
}

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
      id, kind: c.kind, customerId: c.customerId, photographerId: c.photographerId, assigneeId: null,
      bookingId: c.bookingId, bookingStatus,
      photographerRepliedAt: null, customerMessagesBeforeReply: 0,
      lastMessageAt: null, lastMessagePreview: null, lastSenderId: null,
      readOnlyAt: null, rescheduleUsed: false, blockedAt: null, createdAt: at0, updatedAt: at0,
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
  // An is an individual: 7% withheld (DEFAULT_PAYOUT_POLICY), so 1,500,000 → tax 105,000, net 1,395,000 (Ruling 8).
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
      payableAmount: typeof x.payableAmount === 'number' ? x.payableAmount : undefined,
      milestones: Array.isArray(x.milestones) ? x.milestones : undefined,
      createdAt: iso(x.createdAt) ?? at.toISOString(),
      updatedAt: iso(x.updatedAt) ?? at.toISOString(),
    };
    const refunded = x.status === 'refunded' ? payment.amount : 0;
    const item = earningItemOf({
      payment,
      refunded,
      subject: {
        counterpartName: 'Lan (seed)',
        label: service.name,
        day: booking.date,
        milestones: payment.milestones
          ? {
              done: payment.milestones.filter((m) => m.status === 'released' || m.status === 'paid_out').length,
              total: payment.milestones.length,
            }
          : null,
      },
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
/** S18.01 (#142) to try on a ticket: a paid workshop that ended 3 hours before seeding, Lan's money still held. */
export const SEED_EVENT_PAST = 'seed-event-an-past-workshop';
export const SEED_REGISTRATION_LAN_PAST = 'seed-registration-lan-past-paid';
export const SEED_TICKET_CODE_LAN_PAST = 'VE-LANC-0000';
export const SEED_PAYMENT_TICKET_LAN_PAST = 'seed-payment-ticket-lan-past';

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
  // S18: started 5 hours and ended 3 hours before seeding; completed, so the event clock leaves it alone.
  const pastBase = make(SEED_EVENT_PAST, 'Workshop chân dung ngoài trời', 'workshop', -5, 250_000, 12);
  const pastOpenedAt = new Date((pastBase.startAt as Date).getTime() - 7 * DAY_MS);
  const past: EventRecord = {
    ...pastBase,
    status: 'completed',
    completedAt: pastBase.endAt,
    registrationDeadline: new Date((pastBase.startAt as Date).getTime() - 12 * HOUR_MS),
    publishedAt: pastOpenedAt,
    createdAt: pastOpenedAt,
    updatedAt: pastBase.endAt as Date,
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
  // Lan's paid ticket of the past workshop, paid two days before it started (contact unlocked, O3).
  const pastPaidAt = new Date((past.startAt as Date).getTime() - 2 * DAY_MS);
  const pastTicket: RegistrationDoc = {
    ...ticketOf(SEED_REGISTRATION_LAN_PAST, past, SEED_TICKET_CODE_LAN_PAST),
    amount: past.price ?? 0,
    paymentId: SEED_PAYMENT_TICKET_LAN_PAST,
    contactEligible: true,
    createdAt: pastPaidAt,
    updatedAt: pastPaidAt,
  };
  const pastIso = pastPaidAt.toISOString();
  const pastPayment: Payment = {
    id: SEED_PAYMENT_TICKET_LAN_PAST,
    subjectType: 'event_registration',
    subjectId: pastTicket.id,
    eventId: past.id,
    payerId: LAN,
    payeeId: ticketPayeeOf(past),
    provider: 'fake',
    method: 'bank_qr',
    amount: pastTicket.amount,
    status: 'paid',
    escrowStatus: 'held',
    idempotencyKey: ticketIdempotencyKey(pastTicket.id, 'bank_qr'),
    transferCode: transferCodeFor(SEED_PAYMENT_TICKET_LAN_PAST),
    receivedAmount: pastTicket.amount,
    paidAt: pastIso,
    // Stamped by the event clock at completion: the end plus the dispute window.
    releaseAfter: new Date((past.endAt as Date).getTime() + DISPUTE_WINDOW_HOURS * HOUR_MS).toISOString(),
    createdAt: pastIso,
    updatedAt: pastIso,
  };
  const withLan = new Set([free.id, soon.id, past.id]);
  const taken = new Set(existing.map((d) => d.path));
  const docs: SeedDocument[] = [];
  for (const e of [{ ...free, registeredCount: 1, postCount: 1 }, paid, { ...soon, registeredCount: 1 }, { ...past, registeredCount: 1 }]) {
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
  docs.push({ path: `chats/${past.chatId as string}/members/${AN}`, data: memberDoc('moderator', 'An Studio (seed)') });
  docs.push({ path: `chats/${past.chatId as string}/members/${LAN}`, data: memberDoc('member', 'Lan (seed)') });
  docs.push({ path: `events/${past.id}/registrations/${pastTicket.id}`, data: registrationToFirestore(pastTicket) as Record<string, unknown> });
  docs.push({
    path: `events/${past.id}/registrations/${pastTicket.id}/private/contact`,
    data: { name: 'Lan (seed)', phone: SEED_CUSTOMER_PHONES[LAN] ?? '+84903000001', allowZalo: true, allowWhatsApp: false },
  });
  docs.push({ path: `ticket_codes/${pastTicket.ticketCode}`, data: { eventId: past.id, registrationId: pastTicket.id } });
  docs.push({ path: `payments/${pastPayment.id}`, data: paymentToFirestore(pastPayment) as Record<string, unknown> });
  docs.push({
    path: `ledger_entries/seed-ledger-${pastPayment.id}-recv`,
    data: ledgerEntryToFirestore({
      id: `seed-ledger-${pastPayment.id}-recv`, type: 'ticket_received', paymentId: pastPayment.id, subjectType: 'event_registration',
      subjectId: pastTicket.id, accountOwnerId: 'platform_escrow', amount: pastPayment.amount, at: pastIso,
    }) as Record<string, unknown>,
  });

  // S20 Safety seed: Minh blocks Bình
  docs.push({
    path: `blocks/${MINH}_${BINH}`,
    data: {
      blockerId: MINH,
      blockedId: BINH,
      blockedName: 'Bình (seed)',
      blockedAvatarUrl: null,
      source: 'menu',
      createdAt: SEED_CREATED_AT,
    },
  });
  docs.push({
    path: `users/${MINH}/private/blocks`,
    data: {
      blockedIds: [BINH],
      blockedByIds: [],
      updatedAt: SEED_CREATED_AT,
    },
  });
  docs.push({
    path: `users/${BINH}/private/blocks`,
    data: {
      blockedIds: [],
      blockedByIds: [MINH],
      updatedAt: SEED_CREATED_AT,
    },
  });

  // S20 Safety seed: Open report on seed-post-an-5 by Lan
  docs.push({
    path: `reports/${LAN}_post_seed-post-an-5`,
    data: {
      id: `${LAN}_post_seed-post-an-5`,
      reporterId: LAN,
      targetType: 'post',
      targetId: 'seed-post-an-5',
      chatId: null,
      targetOwnerId: AN,
      reason: 'inappropriate',
      text: 'Ảnh có nội dung chưa phù hợp',
      blocked: false,
      snapshot: {
        name: null,
        excerpt: 'Cưới ngoại cảnh',
        imageUrl: 'https://seed.test/seed-post-an-5/1.jpg',
      },
      status: 'open',
      staffNote: null,
      decidedBy: null,
      decidedAt: null,
      createdAt: SEED_CREATED_AT,
    },
  });

  const atIso = now.toISOString();
  const today = formatVnDate(now);
  const spots = seedSpots(now);
  for (const s of spots) {
    docs.push({ path: `spots/${s.id}`, data: spotToFirestore(s) as Record<string, unknown> });
  }

  const anBlockedDays = new Set<string>();
  for (const d of existing) {
    const m = new RegExp(`^availability/${AN}/days/(\\d{4}-\\d{2}-\\d{2})$`).exec(d.path);
    const day = m?.[1];
    if (day) anBlockedDays.add(day);
  }
  for (const e of [free, paid, soon]) {
    if (e.dayKey) anBlockedDays.add(e.dayKey);
  }
  const anWeekendDays = seedWeekendDays(today, anBlockedDays);
  const anSchedule: SpotSchedule = {
    id: SEED_SCHEDULE_AN_HO_TAY,
    providerId: AN,
    assigneeId: null,
    spotId: SEED_SPOT_HO_TAY,
    days: anWeekendDays,
    window: { start: '06:00', end: '11:00' },
    serviceIds: ['seed-service-portrait'],
    priceFrom: 1500000,
    status: 'open',
    createdAt: atIso,
    updatedAt: atIso,
  };
  docs.push({ path: `spot_schedules/${SEED_SCHEDULE_AN_HO_TAY}`, data: scheduleToFirestore(anSchedule) as Record<string, unknown> });

  const anOffer: SlotOffer = {
    id: SEED_OFFER_AN_BINH_MINH,
    providerId: AN,
    scheduleId: SEED_SCHEDULE_AN_HO_TAY,
    spotId: SEED_SPOT_HO_TAY,
    name: 'Bình minh Hồ Tây 30 phút',
    price: 490000,
    slotMinutes: 30,
    gapMinutes: 10,
    photoCount: 30,
    editedCount: 10,
    deliveryDays: 3,
    status: 'open',
    createdAt: atIso,
    updatedAt: atIso,
  };
  docs.push({ path: `spot_slot_offers/${SEED_OFFER_AN_BINH_MINH}`, data: offerToFirestore(anOffer) as Record<string, unknown> });

  for (const day of anWeekendDays) {
    docs.push({
      path: `availability/${AN}/days/${day}`,
      data: {
        photographerId: AN,
        day,
        state: 'spot',
        scheduleId: SEED_SCHEDULE_AN_HO_TAY,
        spotId: SEED_SPOT_HO_TAY,
        updatedAt: now,
      },
    });
    docs.push({
      path: `spot_days/${SEED_SCHEDULE_AN_HO_TAY}_${day}`,
      data: spotDayToFirestore({
        scheduleId: SEED_SCHEDULE_AN_HO_TAY,
        spotId: SEED_SPOT_HO_TAY,
        providerId: AN,
        day,
        taken: [],
        updatedAt: atIso,
      }) as Record<string, unknown>,
    });
  }

  const binhP = SEED_PHOTOGRAPHERS.find((p) => p.uid === BINH);
  const binhAccepts = binhP ? acceptsOrders({ verified: binhP.verified, onboardingComplete: true }) : false;
  if (binhAccepts) {
    const nextSat = anWeekendDays[0] ?? today;
    docs.push({
      path: `spot_schedules/seed-schedule-binh-cau-vang`,
      data: scheduleToFirestore({
        id: 'seed-schedule-binh-cau-vang',
        providerId: BINH,
        assigneeId: null,
        spotId: SEED_SPOT_CAU_VANG,
        days: [nextSat],
        window: { start: '15:00', end: '18:00' },
        serviceIds: [],
        priceFrom: null,
        status: 'open',
        createdAt: atIso,
        updatedAt: atIso,
      }) as Record<string, unknown>,
    });
  }

  return docs;
}

export function seedWeekendDays(today: string, excludedDays: ReadonlySet<string> = new Set()): string[] {
  const parts = today.split('-').map(Number);
  const y = parts[0] ?? 2026;
  const m = parts[1] ?? 1;
  const d = parts[2] ?? 1;
  const out: string[] = [];
  let offset = 0;
  while (out.length < 4 && offset < 60) {
    const dt = new Date(Date.UTC(y, m - 1, d + offset));
    const dow = dt.getUTCDay();
    if (dow === 6) {
      const satStr = formatVnDate(dt);
      const sun = new Date(Date.UTC(y, m - 1, d + offset + 1));
      const sunStr = formatVnDate(sun);
      if (!excludedDays.has(satStr) && !excludedDays.has(sunStr)) {
        out.push(satStr, sunStr);
      }
      offset += 6;
    }
    offset += 1;
  }
  return out;
}

export function seedSpots(now: Date): Spot[] {
  const at = now.toISOString();
  return [
    {
      id: SEED_SPOT_CAU_DAT,
      name: 'Đồi chè Cầu Đất',
      city: 'Đà Lạt',
      areaCode: 'da-lat',
      point: { lat: 11.9012, lng: 108.5123 },
      geohash: encodeGeohash(11.9012, 108.5123),
      radiusM: 1500,
      cover: {
        url: `https://seed.test/spots/${SEED_SPOT_CAU_DAT}/cover.jpg`,
        cardUrl: `https://seed.test/spots/${SEED_SPOT_CAU_DAT}/card.jpg`,
        path: `spots/${SEED_SPOT_CAU_DAT}/cover.jpg`,
      },
      description: 'Đồi chè bạt ngàn trong sương sớm, điểm săn mây và chụp ảnh lãng mạn tại Đà Lạt.',
      tips: ['Đi sáng sớm săn mây từ 5:30 đến 7:00', 'Mang áo khoác ấm vì sáng sớm khá lạnh'],
      seasonMonths: [10, 11, 12],
      pinned: false,
      hidden: false,
      status: 'active',
      hotScore: 0,
      stats: EMPTY_SPOT_STATS,
      createdAt: at,
      updatedAt: at,
      rankedAt: null,
      updatedBy: 'seed',
    },
    {
      id: SEED_SPOT_HOI_AN,
      name: 'Phố cổ Hội An',
      city: 'Hội An',
      areaCode: 'hoi-an',
      point: { lat: 15.877, lng: 108.326 },
      geohash: encodeGeohash(15.877, 108.326),
      radiusM: 1000,
      cover: {
        url: `https://seed.test/spots/${SEED_SPOT_HOI_AN}/cover.jpg`,
        cardUrl: `https://seed.test/spots/${SEED_SPOT_HOI_AN}/card.jpg`,
        path: `spots/${SEED_SPOT_HOI_AN}/cover.jpg`,
      },
      description: 'Khu phố cổ rực rỡ lồng đèn bên dòng sông Hoài, nét đẹp hoài niệm vượt thời gian.',
      tips: ['Chụp áo dài rất đẹp vào sáng sớm hoặc hoàng hôn', 'Thả hoa đăng buổi tối trên sông Hoài'],
      seasonMonths: [],
      pinned: false,
      hidden: false,
      status: 'active',
      hotScore: 0,
      stats: EMPTY_SPOT_STATS,
      createdAt: at,
      updatedAt: at,
      rankedAt: null,
      updatedBy: 'seed',
    },
    {
      id: SEED_SPOT_HO_TAY,
      name: 'Hồ Tây',
      city: 'Hà Nội',
      areaCode: 'hn',
      point: { lat: 21.055, lng: 105.823 },
      geohash: encodeGeohash(21.055, 105.823),
      radiusM: 2000,
      cover: {
        url: `https://seed.test/spots/${SEED_SPOT_HO_TAY}/cover.jpg`,
        cardUrl: `https://seed.test/spots/${SEED_SPOT_HO_TAY}/card.jpg`,
        path: `spots/${SEED_SPOT_HO_TAY}/cover.jpg`,
      },
      description: 'Hồ nước ngọt tự nhiên lớn nhất thủ đô, góc ngắm hoàng hôn và chụp ảnh phong cảnh đa dạng.',
      tips: ['Bến Hàn Quốc và đường Thanh Niên ngắm hoàng hôn đẹp nhất', 'Mùa hè có đầm sen nở rộ'],
      seasonMonths: [],
      pinned: true,
      hidden: false,
      status: 'active',
      hotScore: 0,
      stats: EMPTY_SPOT_STATS,
      createdAt: at,
      updatedAt: at,
      rankedAt: null,
      updatedBy: 'seed',
    },
    {
      id: SEED_SPOT_CAU_VANG,
      name: 'Cầu Vàng',
      city: 'Đà Nẵng',
      areaCode: 'dn',
      point: { lat: 15.995, lng: 107.9967 },
      geohash: encodeGeohash(15.995, 107.9967),
      radiusM: 800,
      cover: {
        url: `https://seed.test/spots/${SEED_SPOT_CAU_VANG}/cover.jpg`,
        cardUrl: `https://seed.test/spots/${SEED_SPOT_CAU_VANG}/card.jpg`,
        path: `spots/${SEED_SPOT_CAU_VANG}/cover.jpg`,
      },
      description: 'Đôi bàn tay khổng lồ nâng đỡ cây cầu vàng uốn lượn giữa mây trời Bà Nà Hills.',
      tips: ['Lên chuyến cáp treo đầu tiên để tránh đông đúc', 'Chụp góc nghiêng bắt trọn đôi bàn tay đá'],
      seasonMonths: [],
      pinned: false,
      hidden: false,
      status: 'active',
      hotScore: 0,
      stats: EMPTY_SPOT_STATS,
      createdAt: at,
      updatedAt: at,
      rankedAt: null,
      updatedBy: 'seed',
    },
    {
      id: SEED_SPOT_MU_CANG_CHAI,
      name: 'Mù Cang Chải',
      city: 'Yên Bái',
      areaCode: 'yen-bai',
      point: { lat: 21.854, lng: 104.088 },
      geohash: encodeGeohash(21.854, 104.088),
      radiusM: 2000,
      cover: {
        url: `https://seed.test/spots/${SEED_SPOT_MU_CANG_CHAI}/cover.jpg`,
        cardUrl: `https://seed.test/spots/${SEED_SPOT_MU_CANG_CHAI}/card.jpg`,
        path: `spots/${SEED_SPOT_MU_CANG_CHAI}/cover.jpg`,
      },
      description: 'Những nấc thang vàng óng ánh trên ruộng bậc thang La Pán Tẩn mùa lúa chín vàng.',
      tips: ['Thời điểm lúa chín đẹp nhất từ giữa tháng 9 đến đầu tháng 10', 'Đồi mâm xôi và đồi móng ngựa chụp góc toàn cảnh'],
      seasonMonths: [9, 10],
      pinned: false,
      hidden: false,
      status: 'active',
      hotScore: 0,
      stats: EMPTY_SPOT_STATS,
      createdAt: at,
      updatedAt: at,
      rankedAt: null,
      updatedBy: 'seed',
    },
  ];
}
