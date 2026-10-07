import type { Booking } from '../../src/booking.js';

export function makeTestBooking(overrides: Partial<Booking> = {}): Booking {
  return {
    id: 'b_test_01',
    customerId: 'c1',
    photographerId: 'p1',
    serviceId: 'srv_01',
    serviceSnapshot: {
      name: 'Gói Chân dung',
      price: 1_000_000,
      durationMinutes: 120,
    },
    day: '2026-10-15',
    start: '14:00',
    end: '16:00',
    place: { name: 'Phố đi bộ' },
    status: 'draft',
    deposit: 1_000_000,
    remaining: 0,
    version: 1,
    createdAt: '2026-10-10T10:00:00.000Z',
    updatedAt: '2026-10-10T10:00:00.000Z',
    ...overrides,
  };
}
