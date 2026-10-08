import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  MemoryEventStore,
  MemoryNotificationStore,
  MemoryPushSender,
  MemoryUserDirectory,
  type EventDeps,
  type EventRecord,
  type NotifyDeps,
  type RegistrationDoc,
} from '@photobooking/domain';
import { handleEventClock } from '../../src/scheduled/event_clock.js';

// The event_soon step is the last named step of eventClock, in its own try/catch (S17 clock rule).

const NOW = new Date('2026-10-10T13:00:00.000Z'); // 20:00 in Vietnam
const START = new Date(NOW.getTime() + 36 * 3_600_000);

const event = (over: Partial<EventRecord> = {}): EventRecord => ({
  id: 'ev1', host: { type: 'photographer', id: 'ph1', name: 'An', avatarUrl: null, verified: true },
  createdBy: 'ph1', createdByRole: 'photographer', hostConsent: 'not_required', hostConsentExpiresAt: null,
  title: 'Chụp phố đêm', description: '', type: 'photo_walk', coverUrl: null, coverPath: null,
  startAt: START, endAt: new Date(START.getTime() + 3 * 3_600_000), dayKey: '2026-10-12',
  location: { name: 'Quận 1', meetingPoint: 'Nhà hát Thành phố', lat: 10.77, lng: 106.7, geohash: 'w3gv2', areaId: null },
  capacity: 10, price: 0, registrationDeadline: new Date(START.getTime() - 12 * 3_600_000), faq: [],
  hashtag: 'PhoDem', hashtagKey: 'phodem', hashtagLocked: false, status: 'open',
  registeredCount: 1, heldCount: 0, chatId: null, postCount: 0, version: 1,
  publishedAt: NOW, completedAt: null, cancelledAt: null, soonNoticeAt: null, createdAt: NOW, updatedAt: NOW,
  ...over,
});

const registration: RegistrationDoc = {
  id: 'rg1', eventId: 'ev1', userId: 'cu1', userName: 'Lan', userAvatarUrl: null, quantity: 1, amount: 0,
  status: 'paid', holdExpiresAt: null, ticketCode: 'VE-ABCD-1012', paymentId: null, contactEligible: false,
  checkedInAt: null, cancelledAt: null, refundPercent: null,
  event: { title: 'Chụp phố đêm', type: 'photo_walk', startAt: START, endAt: START, locationName: 'Quận 1', lat: 10.77, lng: 106.7, coverUrl: null },
  version: 1, createdAt: NOW, updatedAt: NOW,
};

function setup() {
  const events = new MemoryEventStore();
  events.seedEvent(event());
  events.seedRegistration(registration);
  const deps: EventDeps = {
    events,
    people: { photographer: async () => null, user: async () => null },
    contacts: { get: async () => null },
    media: { isOwnUpload: () => false },
    clock: { now: () => NOW },
    ids: { newId: () => 'x' },
    random: (n) => new Uint8Array(n),
  };
  const store = new MemoryNotificationStore();
  const notify: NotifyDeps = { store, push: new MemoryPushSender(), users: new MemoryUserDirectory(), clock: { now: () => NOW } };
  return { events, deps, store, notify };
}

describe('handleEventClock', () => {
  it('keeps the sweep counts and adds soonEvents and soonSent', async () => {
    const w = setup();
    assert.deepEqual(await handleEventClock(w.deps, { notify: w.notify }), {
      closed: 0, completed: 0, consentExpired: 0, refunded: 0, refundsResent: 0, soonEvents: 1, soonSent: 1,
    });
    assert.equal(w.store.rowsOf('cu1')[0]?.type, 'event_soon');
    assert.deepEqual(await handleEventClock(w.deps, { notify: w.notify }), {
      closed: 0, completed: 0, consentExpired: 0, refunded: 0, refundsResent: 0, soonEvents: 0, soonSent: 0,
    });
  });

  it('a failing reminder step does not fail the clock', async () => {
    const w = setup();
    w.events.dueForSoonNotice = async () => {
      throw new Error('missing index');
    };
    const r = await handleEventClock(w.deps, { notify: w.notify });
    assert.deepEqual([r.soonEvents, r.soonSent], [0, 0]);
    assert.equal(w.store.rowsOf('cu1').length, 0);
  });
});
