import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import { FakePaymentGateway, MemoryEventStore, type EventDeps, type EventPaymentDeps } from '@photobooking/domain';
import {
  eventCallerOf,
  handleCancelEvent,
  handleCancelRegistration,
  handleCheckInRegistration,
  handlePublishEvent,
  handleRegisterEvent,
  handleRespondToHostConsent,
  handleSaveEventDraft,
  handleUpdateEvent,
  type EventCallableDeps,
} from '../../src/callables/event.js';
import { handleEventClock } from '../../src/scheduled/event_clock.js';
import { ownCoverUpload } from '../../src/infra/event_firestore.js';

const ID = (n: number): string => `01ARZ3NDEKTSV4RRFFQ69G5F${String(n).padStart(2, '0')}`;
const EVENT_ID = ID(1);

describe('event callables', () => {
  let store: MemoryEventStore;
  let next: number;
  let now: Date;
  let invited: Array<{ hostId: string; eventId: string; title: string; expiresAt: string }>;

  const deps = (): EventCallableDeps & EventPaymentDeps => ({
    gateway: new FakePaymentGateway(),
    events: store,
    people: {
      photographer: async (uid) =>
        uid === 'ph1' ? { onboardingComplete: true, name: 'Lan', avatarUrl: null, verified: true } : null,
      user: async (uid) => ({ name: uid, avatarUrl: null }),
    },
    contacts: { get: async (uid) => (uid === 'cu1' ? { phone: '+84912000001' } : null) },
    media: { isOwnUpload: (url, path, uid, eventId) => path.startsWith(`eventCovers/${uid}/${eventId}/`) && url.endsWith(path) },
    clock: { now: () => now },
    ids: { newId: () => ID(next++) },
    random: (n) => Uint8Array.from({ length: n }, (_, i) => (i * 37 + 11) % 256),
    notifyHostInvited: async (hostId, eventId, title, expiresAt) => {
      invited.push({ hostId, eventId, title, expiresAt: expiresAt.toISOString() });
    },
  });

  const draft = (over: Record<string, unknown> = {}): Record<string, unknown> => {
    const path = `eventCovers/ph1/${EVENT_ID}/c.jpg`;
    return {
      eventId: EVENT_ID,
      title: 'Photo walk',
      type: 'photo_walk',
      coverUrl: `https://s.test/${path}`,
      coverPath: path,
      startAt: '2026-10-12T02:00:00.000Z',
      endAt: '2026-10-12T05:00:00.000Z',
      location: { name: 'Hồ Gươm', lat: 21.0285, lng: 105.8542 },
      capacity: 5,
      price: 0,
      ...over,
    };
  };
  const ph1 = { auth: { uid: 'ph1' } };

  beforeEach(() => {
    store = new MemoryEventStore();
    next = 10;
    now = new Date('2026-10-06T03:00:00.000Z');
    invited = [];
  });

  it('unauthenticated is refused', async () => {
    const handlers = [
      handleSaveEventDraft, handlePublishEvent, handleUpdateEvent, handleCancelEvent,
      handleRespondToHostConsent, handleRegisterEvent, handleCancelRegistration, handleCheckInRegistration,
    ];
    for (const h of handlers) {
      await assert.rejects(
        () => h({ auth: undefined, data: {} }, deps()),
        (e: unknown) =>
          e instanceof HttpsError && e.code === 'unauthenticated'
          && (e.details as { code?: string } | undefined)?.code === 'permission_denied',
      );
    }
  });

  it('staffRole claim reaches the caller, other claims are ignored', () => {
    assert.deepEqual(eventCallerOf({ auth: { uid: 'a', token: { staffRole: 'admin' } }, data: {} }), { uid: 'a', staffRole: 'admin' });
    assert.deepEqual(eventCallerOf({ auth: { uid: 'a', token: { staffRole: 'sales' } }, data: {} }), { uid: 'a', staffRole: 'sales' });
    for (const bad of ['superuser', 1, true, null, undefined, ['admin']]) {
      assert.deepEqual(eventCallerOf({ auth: { uid: 'a', token: { staffRole: bad } }, data: {} }), { uid: 'a', staffRole: null });
    }
    assert.deepEqual(eventCallerOf({ auth: { uid: 'a' }, data: {} }), { uid: 'a', staffRole: null });
  });

  it('domain errors map to HttpsError with the code', async () => {
    await assert.rejects(
      () => handleSaveEventDraft({ auth: { uid: 'cu1' }, data: draft() }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'permission-denied'
        && (e.details as { code?: string }).code === 'permission_denied',
    );
    await assert.rejects(
      () => handleSaveEventDraft({ ...ph1, data: draft({ capacity: 0 }) }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'invalid-argument',
    );
    await assert.rejects(
      () => handlePublishEvent({ ...ph1, data: { eventId: ID(77) } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'not-found',
    );
  });

  it('draft, publish and register a free event end to end', async () => {
    const saved = await handleSaveEventDraft({ ...ph1, data: draft() }, deps());
    assert.equal(saved.eventId, EVENT_ID);
    await handlePublishEvent({ ...ph1, data: { eventId: EVENT_ID } }, deps());
    assert.equal(store.events.get(EVENT_ID)?.status, 'open');
    const reg = await handleRegisterEvent({ auth: { uid: 'cu1' }, data: { eventId: EVENT_ID, quantity: 2, name: 'Khách' } }, deps());
    assert.equal(reg.status, 'paid');
    assert.equal(reg.holdExpiresAt, null);
    assert.equal(store.events.get(EVENT_ID)?.registeredCount, 2);
    assert.equal(store.contacts.size, 0); // O3: no phone snapshot for the host
  });

  it('staff naming a photographer notifies the photographer once; the photographer accepts', async () => {
    const staff = { auth: { uid: 'ad1', token: { staffRole: 'admin' } } };
    const path = `eventCovers/ad1/${EVENT_ID}/c.jpg`;
    await handleSaveEventDraft(
      { ...staff, data: draft({ hostPhotographerId: 'ph1', coverPath: path, coverUrl: `https://s.test/${path}` }) },
      deps(),
    );
    assert.deepEqual(invited, [
      { hostId: 'ph1', eventId: EVENT_ID, title: 'Photo walk', expiresAt: '2026-10-07T03:00:00.000Z' },
    ]);
    await assert.rejects(
      () => handlePublishEvent({ ...staff, data: { eventId: EVENT_ID } }, deps()),
      (e: unknown) => e instanceof HttpsError && e.code === 'failed-precondition',
    );
    await handleRespondToHostConsent({ ...ph1, data: { eventId: EVENT_ID, accept: true } }, deps());
    await handlePublishEvent({ ...staff, data: { eventId: EVENT_ID } }, deps());
    assert.equal(store.events.get(EVENT_ID)?.status, 'open');
  });

  it('staff changing an accepted draft re-notifies the photographer with a new window', async () => {
    const staff = { auth: { uid: 'ad1', token: { staffRole: 'admin' } } };
    const path = `eventCovers/ad1/${EVENT_ID}/c.jpg`;
    const base = { hostPhotographerId: 'ph1', coverPath: path, coverUrl: `https://s.test/${path}` };
    await handleSaveEventDraft({ ...staff, data: draft(base) }, deps());
    await handleRespondToHostConsent({ ...ph1, data: { eventId: EVENT_ID, accept: true } }, deps());
    now = new Date('2026-10-06T05:00:00.000Z');
    await handleSaveEventDraft({ ...staff, data: draft({ ...base, title: 'Đổi tên' }) }, deps());
    assert.equal(invited.length, 2);
    assert.equal(invited[1]?.expiresAt, '2026-10-07T05:00:00.000Z');
    assert.equal(store.events.get(EVENT_ID)?.hostConsent, 'pending');
  });

  it('a photographer saving their own draft sends no invitation', async () => {
    await handleSaveEventDraft({ ...ph1, data: draft() }, deps());
    assert.deepEqual(invited, []);
  });

  it('a failing invitation notice does not fail the save', async () => {
    const d = deps();
    d.notifyHostInvited = async () => {
      throw new Error('push down');
    };
    const staff = { auth: { uid: 'ad1', token: { staffRole: 'admin' } } };
    const path = `eventCovers/ad1/${EVENT_ID}/c.jpg`;
    const res = await handleSaveEventDraft(
      { ...staff, data: draft({ hostPhotographerId: 'ph1', coverPath: path, coverUrl: `https://s.test/${path}` }) },
      d,
    );
    assert.equal(res.eventId, EVENT_ID);
  });

  it('eventClock closes, completes and expires consent', async () => {
    await handleSaveEventDraft({ ...ph1, data: draft() }, deps());
    await handlePublishEvent({ ...ph1, data: { eventId: EVENT_ID } }, deps());
    now = new Date('2026-10-12T00:00:00.000Z'); // after the deadline (start - 12 h)
    assert.deepEqual(await handleEventClock(deps() as EventDeps), { closed: 1, completed: 0, consentExpired: 0, refunded: 0 });
    now = new Date('2026-10-12T06:00:00.000Z');
    assert.deepEqual(await handleEventClock(deps() as EventDeps), { closed: 0, completed: 1, consentExpired: 0, refunded: 0 });
    assert.equal(store.events.get(EVENT_ID)?.status, 'completed');
  });
});

describe('ownCoverUpload', () => {
  const prefix = 'https://firebasestorage.googleapis.com/v0/b/demo.firebasestorage.app/o/';
  const check = ownCoverUpload([prefix]);
  const path = 'eventCovers/u1/e1/cover.jpg';
  const url = `${prefix}${encodeURIComponent(path)}?alt=media&token=abc`;

  it('accepts the caller\'s own object in this bucket', () => {
    assert.equal(check(url, path, 'u1', 'e1'), true);
  });

  it('refuses another user, another event, another bucket and a mismatched object', () => {
    assert.equal(check(url, path, 'u2', 'e1'), false);
    assert.equal(check(url, path, 'u1', 'e2'), false);
    assert.equal(check(url.replace('demo', 'evil'), path, 'u1', 'e1'), false);
    assert.equal(check(`${prefix}${encodeURIComponent('eventCovers/u1/e1/other.jpg')}?alt=media`, path, 'u1', 'e1'), false);
    assert.equal(check(url, 'eventCovers/u1/e1/../x.jpg', 'u1', 'e1'), false);
  });
});
