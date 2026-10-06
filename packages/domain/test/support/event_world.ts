import type { EventCaller, EventRecord, RegistrationDoc } from '../../src/event.js';
import type { EventDeps, EventPeople } from '../../src/event_ports.js';
import { MemoryEventStore } from '../../src/memory_event_store.js';
import type { UserContactReader, UserContactRecord } from '../../src/ports.js';
import { publishEvent, saveEventDraft } from '../../src/event_use_cases.js';
import { registerEvent } from '../../src/event_registration.js';
import { FakeClock, FakeIdGenerator } from './chat_world.js';

/** Unwraps a value a test knows is there. */
export function must<T>(v: T | null | undefined): T {
  if (v === null || v === undefined) throw new Error('expected a value');
  return v;
}

export const T0 = new Date('2026-10-01T12:00:00.000Z'); // 19:00 in Vietnam
export const START = '2026-10-04T02:00:00.000Z'; // 09:00 on 4 Oct in Vietnam
export const END = '2026-10-04T05:00:00.000Z';

export const ph1: EventCaller = { uid: 'ph1', staffRole: null };
export const ph2: EventCaller = { uid: 'ph2', staffRole: null };
export const phNew: EventCaller = { uid: 'ph_new', staffRole: null };
export const cu1: EventCaller = { uid: 'cu1', staffRole: null };
export const cu2: EventCaller = { uid: 'cu2', staffRole: null };
export const cu3: EventCaller = { uid: 'cu3', staffRole: null };
export const cuNoPhone: EventCaller = { uid: 'cu_nophone', staffRole: null };
export const admin: EventCaller = { uid: 'ad1', staffRole: 'admin' };
export const sales1: EventCaller = { uid: 'sales1', staffRole: 'sales' };
export const sales2: EventCaller = { uid: 'sales2', staffRole: 'sales' };

/** Deterministic LCG; `makeRandom(seed)` twice gives the same stream. */
export function makeRandom(seed = 7): (n: number) => Uint8Array {
  let s = seed >>> 0;
  return (n) => {
    const out = new Uint8Array(n);
    for (let i = 0; i < n; i++) {
      s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
      out[i] = (s >>> 24) & 0xff;
    }
    return out;
  };
}

class FakePeople implements EventPeople {
  async photographer(uid: string) {
    if (uid === 'ph1' || uid === 'ph2') {
      return { onboardingComplete: true, name: `Nhiếp ảnh ${uid}`, avatarUrl: null, verified: uid === 'ph1' };
    }
    if (uid === 'ph_new') return { onboardingComplete: false, name: 'Mới', avatarUrl: null, verified: false };
    return null;
  }

  async user(uid: string) {
    return { name: `User ${uid}`, avatarUrl: null };
  }
}

class FakeContacts implements UserContactReader {
  private readonly phones = new Map<string, string>([
    ['cu1', '+84912000001'], ['cu2', '+84912000002'], ['cu3', '+84912000003'], ['cu4', '+84912000004'], ['cu5', '+84912000005'],
  ]);

  async get(uid: string): Promise<UserContactRecord | null> {
    const phone = this.phones.get(uid);
    return phone === undefined ? null : { phone };
  }
}

export interface EventWorld {
  readonly deps: EventDeps;
  readonly store: MemoryEventStore;
  readonly clock: FakeClock;
}

export function createEventWorld(seed = 7): EventWorld {
  const store = new MemoryEventStore();
  const clock = new FakeClock(T0);
  const deps: EventDeps = {
    events: store,
    people: new FakePeople(),
    contacts: new FakeContacts(),
    media: {
      isOwnUpload: (url, path, uid, eventId) => path.startsWith(`eventCovers/${uid}/${eventId}/`) && url.endsWith(path),
    },
    clock,
    ids: new FakeIdGenerator(),
    random: makeRandom(seed),
  };
  return { deps, store, clock };
}

/** A complete, valid save/publish request for `creator`'s event `eventId`. */
export function rawEvent(eventId: string, creator = 'ph1', over: Record<string, unknown> = {}): Record<string, unknown> {
  const path = `eventCovers/${creator}/${eventId}/cover.jpg`;
  return {
    eventId,
    title: 'Photo walk phố cổ',
    type: 'photo_walk',
    description: 'Đi bộ chụp ảnh phố cổ buổi sáng.',
    coverUrl: `https://storage.test/${path}`,
    coverPath: path,
    startAt: START,
    endAt: END,
    location: { name: 'Hồ Gươm', meetingPoint: 'Cổng đền Ngọc Sơn', lat: 21.0285, lng: 105.8542, areaId: null },
    capacity: 10,
    price: 0,
    ...over,
  };
}

/** Saves and publishes an event; returns its id. */
export async function publishedEvent(
  w: EventWorld,
  over: Record<string, unknown> = {},
  caller: EventCaller = ph1,
  id = 'ev1_aaaaaaaaaaaaaaaaaaaa',
): Promise<string> {
  const { eventId } = await saveEventDraft(w.deps, caller, rawEvent(id, caller.uid, over));
  await publishEvent(w.deps, caller, { eventId });
  return eventId;
}

export const register = (w: EventWorld, caller: EventCaller, eventId: string, quantity = 1) =>
  registerEvent(w.deps, caller, { eventId, quantity, name: 'Nguyễn An' });

export function eventRecord(over: Partial<EventRecord> = {}): EventRecord {
  return {
    id: 'evX', host: { type: 'photographer', id: 'ph1', name: 'A', avatarUrl: null, verified: false },
    createdBy: 'ph1', createdByRole: 'photographer', hostConsent: 'not_required', hostConsentExpiresAt: null,
    title: 'T', description: '', type: 'photo_walk', coverUrl: 'u', coverPath: 'p',
    startAt: new Date(START), endAt: new Date(END), dayKey: '2026-10-04',
    location: { name: 'L', meetingPoint: null, lat: 21, lng: 105, geohash: 'w7er8u0', areaId: null },
    capacity: 10, price: 0, registrationDeadline: new Date('2026-10-03T14:00:00.000Z'), faq: [],
    hashtag: 'Tag1004', hashtagKey: 'tag1004', hashtagLocked: false, status: 'open',
    registeredCount: 0, heldCount: 0, chatId: 'event_evX', postCount: 0, version: 1,
    publishedAt: T0, completedAt: null, cancelledAt: null, createdAt: T0, updatedAt: T0,
    ...over,
  };
}

export function registrationDoc(over: Partial<RegistrationDoc> = {}): RegistrationDoc {
  return {
    id: 'rg1', eventId: 'evX', userId: 'cu9', userName: 'Khách', userAvatarUrl: null, quantity: 1, amount: 0,
    status: 'paid', holdExpiresAt: null, ticketCode: 'VE-ABCD-1004', paymentId: null, contactEligible: false,
    checkedInAt: null, cancelledAt: null, refundPercent: null,
    event: { title: 'T', type: 'photo_walk', startAt: new Date(START), endAt: new Date(END), locationName: 'L', lat: 21, lng: 105, coverUrl: null },
    version: 1, createdAt: T0, updatedAt: T0,
    ...over,
  };
}
