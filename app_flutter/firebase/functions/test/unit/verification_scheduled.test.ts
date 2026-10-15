import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  FakeBlockGate,
  FakePaymentGateway,
  MemoryAwardStore,
  MemoryBookingStore,
  type AwardDeps,
  type BookingDeps,
  type VerificationStore,
} from '@photobooking/domain';
import { handleBookingClock } from '../../src/scheduled/booking_clock.js';
import { BUSINESS_PURGE_PAGE, handleAwardPurge, purgeBusinessDocs, type BusinessDocPurgeDeps } from '../../src/scheduled/award_purge.js';
import { NOW, readyRecord, verificationWorld } from './verification_support.js';

const HOUR = 3_600_000;

function bookingDeps(now: Date): BookingDeps {
  return {
    store: new MemoryBookingStore(),
    services: { getService: async () => null },
    contacts: { get: async () => null },
    providers: { acceptsOrders: async () => true },
    blocks: new FakeBlockGate(),
    gateway: new FakePaymentGateway(),
    clock: { now: () => now },
    ids: { newId: () => '01ARZ3NDEKTSV4RRFFQ69G5F01' },
  };
}

describe('bookingClock verification step', () => {
  it('bookingClock runs the nudge step and survives its failure', async () => {
    const w = verificationWorld();
    const old = new Date(NOW.getTime() - 25 * HOUR).toISOString();
    w.store.verifications.set('p1', readyRecord('p1', { status: 'in_progress', submittedAt: null, updatedAt: old }));
    w.store.verifications.set('p2', readyRecord('p2', { status: 'in_progress', submittedAt: null, updatedAt: NOW.toISOString() }));

    const results = await handleBookingClock(bookingDeps(NOW), undefined, { verification: { deps: w.deps, notify: w.notify } });
    assert.equal(results.expiredRequests, 0);
    assert.deepEqual(w.notifyStore.rowsOf('p1').map((r) => r.type), ['verification_reminder']);
    assert.equal(w.notifyStore.rowsOf('p2').length, 0);
    assert.equal(w.store.verifications.get('p1')?.nudgedAt, NOW.toISOString());

    // Once only.
    await handleBookingClock(bookingDeps(NOW), undefined, { verification: { deps: w.deps, notify: w.notify } });
    assert.equal(w.notifyStore.rowsOf('p1').length, 1);

    // A failing step is logged; the booking sweep result still comes back.
    const broken: VerificationStore = {
      runTransaction: () => Promise.reject(new Error('down')),
      dueForNudge: () => Promise.reject(new Error('down')),
      queue: () => Promise.reject(new Error('down')),
    };
    const res = await handleBookingClock(bookingDeps(NOW), undefined, {
      verification: { deps: { ...w.deps, store: broken }, notify: w.notify },
    });
    assert.equal(res.releasedEscrows, 0);
  });

  it('without extras the clock is what it was', async () => {
    const res = await handleBookingClock(bookingDeps(NOW));
    assert.deepEqual(res, { cleanedDrafts: 0, expiredRequests: 0, upcomingTransitions: 0, autoCompletions: 0, releasedEscrows: 0 });
  });
});

describe('purgeAwardProofs business-doc step', () => {
  function businessDeps(items: { uid: string; docPath: string | null }[], failOn: string | null = null) {
    const log: string[] = [];
    let asked: { now: Date; limit: number } | null = null;
    const deps: BusinessDocPurgeDeps = {
      due: async (now, limit) => ((asked = { now, limit }), items),
      deleteFiles: async (paths) => {
        if (paths.includes(failOn ?? '')) throw new Error('storage down');
        log.push(`delete ${paths.join(',')}`);
      },
      clear: async (uid, docPath) => void log.push(`clear ${uid} ${docPath}`),
      clock: { now: () => NOW },
    };
    return { deps, log, asked: () => asked };
  }

  it('the purge step deletes business photos past purgeAfter', async () => {
    const b = businessDeps([
      { uid: 's1', docPath: 'businessDocs/s1/a.jpg' },
      { uid: 's2', docPath: 'businessDocs/s2/b.jpg' },
      { uid: 's3', docPath: null },
    ], 'businessDocs/s2/b.jpg');
    const purged = await purgeBusinessDocs(b.deps);
    assert.equal(purged, 1);
    assert.deepEqual(b.log, ['delete businessDocs/s1/a.jpg', 'clear s1 businessDocs/s1/a.jpg', 'clear s3 null']);
    assert.deepEqual(b.asked(), { now: NOW, limit: BUSINESS_PURGE_PAGE });
  });

  it('runs after the award proofs in the same daily job, each with its own failure', async () => {
    const store = new MemoryAwardStore();
    const awardDeps = {
      awards: store,
      tiers: store.tiers,
      files: { delete: async () => {} },
      notify: { tierChanged: async () => {}, awardReviewed: async () => {} },
      clock: { now: () => NOW },
    } satisfies AwardDeps;
    const b = businessDeps([{ uid: 's1', docPath: 'businessDocs/s1/a.jpg' }]);
    assert.equal(await handleAwardPurge({ ...awardDeps, proofsDue: async () => [] }, b.deps), 0);
    assert.deepEqual(b.log, ['delete businessDocs/s1/a.jpg', 'clear s1 businessDocs/s1/a.jpg']);

    // The award step fails: the business step still runs, then the award error is reported.
    const c = businessDeps([{ uid: 's1', docPath: 'businessDocs/s1/a.jpg' }]);
    await assert.rejects(
      () => handleAwardPurge({ ...awardDeps, proofsDue: () => Promise.reject(new Error('award down')) }, c.deps),
      /award down/,
    );
    assert.equal(c.log.length, 2);

    // The business step fails: the award result stands.
    const failing: BusinessDocPurgeDeps = { ...b.deps, due: () => Promise.reject(new Error('query down')) };
    assert.equal(await handleAwardPurge({ ...awardDeps, proofsDue: async () => [] }, failing), 0);
  });
});
