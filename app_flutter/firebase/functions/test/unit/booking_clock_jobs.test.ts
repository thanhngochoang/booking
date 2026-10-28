import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { handleBookingClock } from '../../src/scheduled/booking_clock.js';
import { MemoryBookingStore, type BookingDeps, type JobDeps } from '@photobooking/domain';

describe('bookingClock job sweeps step', () => {
  it('the clock runs job sweeps after booking sweeps and a job sweep failure is logged, not thrown over the booking results', async () => {
    let bookingSweepsRan = false;
    let jobSweepsRan = false;

    const store = new MemoryBookingStore();
    const originalFindExpired = store.findExpiredDrafts.bind(store);
    store.findExpiredDrafts = async (now, limit) => {
      bookingSweepsRan = true;
      return originalFindExpired(now, limit);
    };

    const mockBookingDeps = {
      store,
      services: {},
      providers: {},
      contacts: {},
      gateway: {},
      clock: { now: () => new Date('2026-10-21T10:00:00.000Z') },
      ids: { newId: () => 'b_1' },
    } as unknown as BookingDeps;

    const failingJobDeps = {
      jobs: {
        runTransaction: async () => {
          throw new Error('Firestore job sweeps down');
        },
        countOpenJobs: async () => 0,
        countSubmittedQuotes: async () => 0,
        submittedQuotesOnDay: async () => [],
        dueForExpiry: async () => {
          jobSweepsRan = true;
          throw new Error('Firestore job sweeps down');
        },
        dueForExpiringNotice: async () => [],
        dueForReferencePurge: async () => [],
      },
      people: {},
      contacts: {},
      media: {},
      providers: {},
      clock: { now: () => new Date('2026-10-21T10:00:00.000Z') },
      ids: { newId: () => 'id_1' },
    } as unknown as JobDeps;

    // The call should NOT throw even though failingJobDeps throws!
    const results = await handleBookingClock(mockBookingDeps, undefined, {
      jobs: failingJobDeps,
    });

    assert.ok(bookingSweepsRan);
    assert.ok(jobSweepsRan);
    assert.ok(results);
    assert.equal(typeof results.cleanedDrafts, 'number');
  });
});
