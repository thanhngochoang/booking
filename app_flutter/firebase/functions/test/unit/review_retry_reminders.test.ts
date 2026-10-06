import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  MemoryBadgeStore,
  MemoryNotificationStore,
  MemoryPushSender,
  MemoryUserDirectory,
  type BadgeDeps,
  type Booking,
  type StatsStore,
  type StatsTx,
} from '@photobooking/domain';
import { handleReviewWrite } from '../../src/triggers/review_write.js';
import { sweepReminders, type ReminderDeps } from '../../src/scheduled/booking_clock.js';

describe('review notice retries', () => {
  it('a retry after a failed notice finds the review already counted and still notifies and evaluates', async () => {
    let counted = false;
    const store: StatsStore = {
      runTransaction: async <T,>(fn: (tx: StatsTx) => Promise<T>) =>
        fn({
          getReview: async (id) => ({
            bookingId: id, customerId: 'c1', photographerId: 'p1', serviceId: 's', rating: 5, text: 'Tốt',
            photoPostId: null, createdAt: new Date(), countedAt: counted ? new Date() : null,
          }),
          getPhotographerStats: async () => null,
          setPhotographerStats: () => {},
          markCounted: () => { counted = true; },
        }),
    };
    const notifyStore = new MemoryNotificationStore();
    const users = new MemoryUserDirectory();
    users.users.set('c1', { name: 'Lan', avatarUrl: null });
    const push = new MemoryPushSender();
    let evaluations = 0;
    let failOnce = true;
    const clock = { now: () => new Date('2026-10-10T10:00:00.000Z') };
    const badges: BadgeDeps = {
      badges: new MemoryBadgeStore(),
      metrics: {
        isPhotographer: async () => {
          evaluations += 1;
          return false;
        },
        read: async () => ({}),
      },
      notify: {
        store: {
          ...Object.create(notifyStore),
          runTransaction: (fn: never) => {
            if (failOnce) {
              failOnce = false;
              throw new Error('boom');
            }
            return notifyStore.runTransaction(fn);
          },
          getPrefs: (u: string) => notifyStore.getPrefs(u),
        },
        push,
        users,
        clock,
      },
      clock,
    };
    const input = { bookingId: 'b1', before: undefined, after: { photographerId: 'p1', customerId: 'c1', rating: 5, text: 'Tốt' } };

    await assert.rejects(handleReviewWrite(input, store, new Date(), badges));
    assert.equal(notifyStore.rowsOf('p1').length, 0);
    assert.equal(await handleReviewWrite(input, store, new Date(), badges), 'already');
    assert.equal(notifyStore.rowsOf('p1').length, 1);
    assert.ok(evaluations >= 2);
    assert.equal(await handleReviewWrite(input, store, new Date(), badges), 'already');
    assert.equal(notifyStore.rowsOf('p1').length, 1, 'a second retry adds nothing');
  });
});

describe('reminder sweep paging', () => {
  const booking = (i: number): Booking => ({
    id: `b${i}`, customerId: 'c', photographerId: 'p', serviceId: 's',
    serviceSnapshot: { name: 'x', price: 1, durationMinutes: 60 },
    day: '2026-10-10', start: '09:00', end: '10:00', place: { name: 'x' }, status: 'upcoming',
    deposit: 0, remaining: 0, version: 1, createdAt: '', updatedAt: '',
  });

  it('walks every page (200 per page, batches of 20)', async () => {
    const all = Array.from({ length: 450 }, (_, i) => booking(i));
    const pages: number[] = [];
    const store = new MemoryNotificationStore();
    const users = new MemoryUserDirectory();
    const deps: ReminderDeps = {
      notify: { store, push: new MemoryPushSender(), users, clock: { now: () => new Date('2026-10-10T01:00:00.000Z') } },
      upcoming: async (limit, after) => {
        const from = typeof after === 'number' ? after : 0;
        pages.push(from);
        const bookings = all.slice(from, from + limit);
        return { bookings, next: bookings.length < limit ? null : from + limit };
      },
    };
    // 09:00 Vietnam = 02:00Z; at 01:00Z the start is in 1 h, so h2 is due: 2 rows per booking.
    const sent = await sweepReminders(deps);
    assert.deepEqual(pages, [0, 200, 400]);
    assert.equal(sent, 900);
    assert.equal(store.rows.size, 900);
  });
});
