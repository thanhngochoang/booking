/** Shared documents of the S26 adapter tests (#136): a studio Cúc, members, a studio booking. */

import type { Booking } from '@photobooking/domain';
import { Timestamp } from 'firebase-admin/firestore';
import { bookingToFirestore } from '../../../src/infra/booking_firestore.js';
import type { MemoryFirestore } from './memory_firestore.js';

export const NOW = new Date('2026-10-10T03:00:00.000Z'); // 10:00 in Vietnam
export const STUDIO = 'studio_cuc';
export const CUSTOMER = 'cust_lan';

export function seedPerson(
  db: MemoryFirestore,
  uid: string,
  name: string,
  photographer: Record<string, unknown> | null = {},
): void {
  db.seed(`users/${uid}`, { displayName: name, avatarUrl: `https://img.test/${uid}.jpg` });
  if (photographer !== null) {
    db.seed(`photographers/${uid}`, { onboardingComplete: true, verified: true, ...photographer });
  }
}

/** Cúc (studio, verified) with `members` active since 30 days. */
export function seedStudio(db: MemoryFirestore, members: readonly string[] = []): void {
  seedPerson(db, STUDIO, 'Cúc Studio', { providerType: 'studio', memberCount: members.length });
  const joined = Timestamp.fromDate(new Date(NOW.getTime() - 30 * 86_400_000));
  members.forEach((uid, i) =>
    seedPerson(db, uid, `Thợ ${i + 1}`, { studioId: STUDIO, studioJoinedAt: joined, stats: { tomatoPct: 90 - i, reviewCount: 10 + i } }),
  );
}

export function studioBooking(over: Partial<Booking> = {}): Booking {
  return {
    id: 'bk_studio_1',
    customerId: CUSTOMER,
    photographerId: STUDIO,
    serviceId: 'svc_1',
    serviceSnapshot: { name: 'Cưới 4 giờ', price: 4_000_000, durationMinutes: 240 },
    day: '2026-10-14',
    start: '09:00',
    end: '13:00',
    place: { name: 'Nhà thờ Đức Bà' },
    status: 'accepted',
    deposit: 4_000_000,
    remaining: 0,
    escrowStatus: 'held',
    isStudio: true,
    assigneeId: null,
    assigneeKind: null,
    assignStatus: 'unassigned',
    assignDeadline: '2026-10-13T02:00:00.000Z',
    assignOverdue: false,
    assignedAt: null,
    assignments: [],
    assignRemindersSent: [],
    changeRequest: null,
    studioFault: null,
    assignmentReturned: null,
    version: 1,
    createdAt: '2026-10-09T03:00:00.000Z',
    updatedAt: '2026-10-09T03:00:00.000Z',
    ...over,
  };
}

export function seedBooking(db: MemoryFirestore, b: Booking): void {
  db.seed(`bookings/${b.id}`, bookingToFirestore(b));
}
