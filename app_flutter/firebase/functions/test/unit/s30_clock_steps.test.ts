import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  MemoryNotificationStore,
  MemoryOrganizerStore,
  MemoryPushSender,
  MemorySpotCounter,
  MemorySpotRankStore,
  MemoryUserDirectory,
  ORGANIZER_TERMS_VERSION,
  publishEvent,
  saveEventDraft,
  type NotifyDeps,
  type OrganizerDeps,
} from '@photobooking/domain';
import { handleBookingClock } from '../../src/scheduled/booking_clock.js';
import { handleEventClock } from '../../src/scheduled/event_clock.js';
import { handleRankSpots } from '../../src/scheduled/rank_spots.js';
import { paymentWorld } from './support/payment_world.js';

const { makeTestBooking } = await import('../../../../../packages/domain/test/support/booking_fixtures.js');
const ew = await import('../../../../../packages/domain/test/support/entry_world.js');
const evw = await import('../../../../../packages/domain/test/support/event_world.js');
const ow = await import('../../../../../packages/domain/test/support/organizer_world.js');

const HOUR = 3_600_000;

function notifyAt(now: () => Date): { deps: NotifyDeps; store: MemoryNotificationStore } {
  const store = new MemoryNotificationStore();
  return { store, deps: { store, push: new MemoryPushSender(), users: new MemoryUserDirectory(), clock: { now } } };
}

// Decision 13: no new Scheduler job; the S30 periodic steps join the three existing clocks.
describe('S30 steps of the existing clocks', () => {
  it('bookingClock runs askShootHappened and expireShootQuestions', async () => {
    // 2026-10-20 10:00 in Vietnam.
    const w = paymentWorld(new Date('2026-10-20T03:00:00.000Z'));
    const now = () => w.deps.clock.now();
    // b_ask ended 2026-10-18 17:30 (more than 24 h ago), never scanned → the customer is asked.
    w.store.bookings.set('b_ask', makeTestBooking({
      id: 'b_ask', status: 'upcoming', day: '2026-10-18', start: '15:30', end: '17:30', remaining: 0,
    }));
    // b_open's question ran out an hour ago → shot by the system.
    w.store.bookings.set('b_open', makeTestBooking({
      id: 'b_open', customerId: 'c2', status: 'upcoming', day: '2026-10-16', start: '09:00', end: '11:00',
      shootQuestionAt: new Date(now().getTime() - 49 * HOUR).toISOString(),
      shootQuestionUntil: new Date(now().getTime() - HOUR).toISOString(),
    }));
    const n = notifyAt(now);
    const results = await handleBookingClock(w.deps, { notify: n.deps, upcoming: async () => ({ bookings: [], next: null }) });
    assert.equal(results.shootQuestionsExpired, 1);
    assert.equal(w.store.bookings.get('b_open')?.status, 'shot');
    const asked = w.store.bookings.get('b_ask');
    assert.equal(asked?.status, 'upcoming');
    assert.ok(asked?.shootQuestionAt);
    assert.deepEqual(n.store.rowsOf('c1').map((r) => r.type), ['shoot_question']);
  });

  it('eventClock runs expireVenueConsent and refundClosedDays', async () => {
    const w = ew.createEntryWorld();
    await ew.publishedEntry(w);
    const regId = await ew.bought(w, evw.cu1);
    // closeEntryDay left this ticket of the closed day to the clock (more than 20 that day).
    const key = `${ew.ENTRY_ID}_${ew.VISIT}`;
    const day = w.store.entryDays.get(key);
    assert.ok(day);
    w.store.entryDays.set(key, { ...day, closed: true });
    const reg = w.store.registrations.get(`${ew.ENTRY_ID}/${regId}`);
    assert.ok(reg);
    w.store.registrations.set(`${ew.ENTRY_ID}/${regId}`, { ...reg, refundDue: true });

    // ph1's photo walk at s1 waits for org1's consent; 73 h later nobody answered.
    const at = new Date('2026-10-20T03:00:00.000Z');
    w.clock.set(at);
    const id = 'ev1_aaaaaaaaaaaaaaaaaaaa';
    await saveEventDraft(w.deps, evw.ph1, evw.rawEvent(id, 'ph1', {
      startAt: '2026-10-30T02:00:00.000Z', endAt: '2026-10-30T05:00:00.000Z',
      venue: { kind: 'managed_spot', spotId: 's1', termsVersion: ORGANIZER_TERMS_VERSION },
    }));
    await publishEvent({ ...w.deps, notify: w.notify.deps }, evw.ph1, { eventId: id });
    assert.equal(w.store.events.get(id)?.venueConsent, 'pending');
    w.clock.set(new Date(at.getTime() + 73 * HOUR));

    const n = notifyAt(() => w.clock.now());
    const r = await handleEventClock(w.deps, { notify: n.deps });
    assert.equal(r.consentExpired, 1);
    assert.equal(w.store.events.get(id)?.venueConsent, 'expired');
    assert.equal(r.refunded, 1);
    const after = w.store.registrations.get(`${ew.ENTRY_ID}/${regId}`);
    assert.deepEqual([after?.status, after?.refundPercent], ['refunded', 100]);
  });

  it('rankSpots runs expireResidents', async () => {
    const store = new MemorySpotRankStore();
    const counter = new MemorySpotCounter();
    const organizers = new MemoryOrganizerStore();
    organizers.seedResident('s1', { providerId: 'p1', waivesProvider: true, waivesGuests: false, maxGuests: null, validUntil: '2026-10-07', addedAt: '2026-10-01T00:00:00.000Z', addedBy: 'org1' });
    organizers.seedResident('s1', { providerId: 'p2', waivesProvider: true, waivesGuests: false, maxGuests: null, validUntil: '2026-10-08', addedAt: '2026-10-01T00:00:00.000Z', addedBy: 'org1' });
    organizers.seedResident('s1', { providerId: 'p3', waivesProvider: true, waivesGuests: false, maxGuests: null, validUntil: null, addedAt: '2026-10-01T00:00:00.000Z', addedBy: 'org1' });
    const w = ow.createOrganizerWorld();
    const deps: OrganizerDeps = { ...w.deps, organizers };
    // 2026-10-08 10:00 in Vietnam: p1's residency ended yesterday.
    const res = await handleRankSpots({
      store: store as never, counter: counter as never, clock: { now: () => new Date('2026-10-08T03:00:00.000Z') }, residents: deps,
    });
    assert.equal(res.residentsExpired, 1);
    assert.deepEqual(organizers.residentsOfSync('s1').map((r) => r.providerId).sort(), ['p2', 'p3']);
  });

  it('a failing expireResidents never fails the ranking', async () => {
    const organizers = new MemoryOrganizerStore();
    organizers.expiredResidents = async () => {
      throw new Error('missing index');
    };
    const w = ow.createOrganizerWorld();
    const res = await handleRankSpots({
      store: new MemorySpotRankStore() as never, counter: new MemorySpotCounter() as never,
      clock: { now: () => new Date('2026-10-08T03:00:00.000Z') }, residents: { ...w.deps, organizers },
    });
    assert.equal(res.residentsExpired, 0);
    assert.equal(res.spots, 0);
  });
});
