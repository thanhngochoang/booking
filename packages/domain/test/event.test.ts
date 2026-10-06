import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError } from '../src/errors.js';
import {
  encodeGeohash, isEventManager, seatsLeft, statusAfterSeats, validateEventFields,
} from '../src/event.js';
import { START, T0, admin, cu1, eventRecord, ph1, ph2, rawEvent, sales1, sales2 } from './support/event_world.js';

const publish = (over: Record<string, unknown> = {}, now = T0) =>
  validateEventFields(rawEvent('ev1_aaaaaaaaaaaaaaaaaaaa', 'ph1', over), 'publish', now, null);
const draft = (raw: Record<string, unknown>) => validateEventFields(raw, 'draft', T0, null);
const invalid = (fn: () => unknown) =>
  assert.throws(fn, (e) => e instanceof DomainError && e.code === 'invalid_argument');

test('title is trimmed and 1–80 characters', () => {
  assert.equal(publish({ title: '  Đi dạo   ' }).title, 'Đi dạo');
  invalid(() => publish({ title: '   ' }));
  invalid(() => publish({ title: 'a'.repeat(81) }));
  assert.equal(publish({ title: 'a'.repeat(80) }).title.length, 80);
  invalid(() => publish({ title: 5 }));
});

test('description over 1000 is invalid', () => {
  assert.equal(publish({ description: 'a'.repeat(1000) }).description.length, 1000);
  invalid(() => publish({ description: 'a'.repeat(1001) }));
});

test('a draft accepts missing schedule fields', () => {
  const f = draft({ title: 'Nháp', type: 'workshop' });
  assert.equal(f.startAt, null);
  assert.equal(f.location, null);
  assert.equal(f.capacity, null);
  assert.equal(f.registrationDeadline, null);
  invalid(() => draft({ type: 'workshop' })); // title is needed to create
});

test('publish needs cover, schedule, place, capacity and price', () => {
  for (const key of ['coverUrl', 'startAt', 'endAt', 'location', 'capacity', 'price']) {
    invalid(() => publish({ [key]: null }));
  }
  invalid(() => publish({ coverPath: null })); // url without path
});

test('start must be at least 2 hours ahead at publish', () => {
  const now = new Date('2026-10-01T12:00:00.000Z');
  const at = (mins: number) => new Date(now.getTime() + mins * 60_000).toISOString();
  invalid(() => publish({ startAt: at(119), endAt: at(150) }, now));
  assert.ok(publish({ startAt: at(120), endAt: at(150) }, now).startAt);
});

test('start and end must be on the same VN day', () => {
  // 16:59 UTC is 23:59 in Vietnam, 17:00 UTC is already the next day
  invalid(() => publish({ startAt: '2026-10-04T16:00:00.000Z', endAt: '2026-10-04T17:00:00.000Z' }));
  assert.ok(publish({ startAt: '2026-10-04T16:00:00.000Z', endAt: '2026-10-04T16:59:00.000Z' }));
});

test('end must be after start', () => {
  invalid(() => publish({ endAt: START }));
  invalid(() => publish({ endAt: '2026-10-04T01:00:00.000Z' }));
});

test('capacity outside 1–500 is invalid', () => {
  invalid(() => publish({ capacity: 0 }));
  invalid(() => publish({ capacity: 501 }));
  invalid(() => publish({ capacity: 2.5 }));
  assert.equal(publish({ capacity: 1 }).capacity, 1);
  assert.equal(publish({ capacity: 500 }).capacity, 500);
});

test('price must be a whole multiple of 1000 and at most 100 000 000', () => {
  invalid(() => publish({ price: 1500 }));
  invalid(() => publish({ price: -1000 }));
  invalid(() => publish({ price: 100_001_000 }));
  assert.equal(publish({ price: 100_000_000 }).price, 100_000_000);
  assert.equal(publish({ price: 250_000 }).price, 250_000);
});

test('price 0 is a free event', () => {
  assert.equal(publish({ price: 0 }).price, 0);
});

test('deadline after start is invalid', () => {
  invalid(() => publish({ registrationDeadline: '2026-10-04T02:00:01.000Z' }));
  assert.ok(publish({ registrationDeadline: START }).registrationDeadline);
});

test('deadline defaults to 12 hours before start', () => {
  const d = publish().registrationDeadline;
  assert.equal(d?.toISOString(), '2026-10-03T14:00:00.000Z');
});

test('a near start defaults the deadline to the start', () => {
  const start = new Date(T0.getTime() + 5 * 3_600_000);
  const f = publish({ startAt: start.toISOString(), endAt: new Date(start.getTime() + 3_600_000).toISOString() });
  assert.equal(f.registrationDeadline?.getTime(), start.getTime());
});

test('moving the start re-derives the deadline; the same start keeps it', () => {
  const ev = eventRecord({ status: 'open', registrationDeadline: new Date('2026-10-03T10:00:00.000Z') });
  const same = validateEventFields({ startAt: START }, 'publish', T0, ev);
  assert.equal(same.registrationDeadline?.toISOString(), '2026-10-03T10:00:00.000Z');
  const moved = validateEventFields(
    { startAt: '2026-10-05T02:00:00.000Z', endAt: '2026-10-05T04:00:00.000Z' }, 'publish', T0, ev);
  assert.equal(moved.registrationDeadline?.toISOString(), '2026-10-04T14:00:00.000Z');
});

test('location is validated and gets a geohash', () => {
  const f = publish();
  assert.equal(f.location?.geohash.length, 9);
  assert.equal(encodeGeohash(57.64911, 10.40744, 11), 'u4pruydqqvj');
  invalid(() => publish({ location: { name: 'x', lat: 91, lng: 0 } }));
  invalid(() => publish({ location: { name: '', lat: 1, lng: 1 } }));
});

test('faq is bounded', () => {
  const qa = { question: 'Có gửi xe không?', answer: 'Có.' };
  assert.equal(publish({ faq: [qa] }).faq.length, 1);
  invalid(() => publish({ faq: Array.from({ length: 11 }, () => qa) }));
  invalid(() => publish({ faq: [{ question: 'a'.repeat(121), answer: 'x' }] }));
  invalid(() => publish({ faq: [{ question: 'q', answer: 'a'.repeat(501) }] }));
  invalid(() => publish({ faq: [{ question: 'q', answer: '' }] }));
});

test('managers: host, admin, sales creator — not another sales', () => {
  const own = eventRecord();
  assert.equal(isEventManager(own, ph1), true);
  assert.equal(isEventManager(own, ph2), false);
  assert.equal(isEventManager(own, admin), true);
  const platform = eventRecord({
    host: { type: 'platform', id: null, name: null, avatarUrl: null, verified: true },
    createdBy: 'sales1', createdByRole: 'sales',
  });
  assert.equal(isEventManager(platform, sales1), true);
  assert.equal(isEventManager(platform, sales2), false);
  assert.equal(isEventManager(platform, cu1), false);
  assert.equal(isEventManager(platform, admin), true);
});

test('seatsLeft never goes below 0', () => {
  assert.equal(seatsLeft({ capacity: 10, registeredCount: 4, heldCount: 2 }), 4);
  assert.equal(seatsLeft({ capacity: 10, registeredCount: 9, heldCount: 5 }), 0);
  assert.equal(seatsLeft({ capacity: null, registeredCount: 0, heldCount: 0 }), 0);
});

test('full when registered plus held equals capacity', () => {
  const e = eventRecord({ registeredCount: 6, heldCount: 4 });
  assert.equal(statusAfterSeats(e, T0), 'full');
  assert.equal(statusAfterSeats({ ...e, status: 'full', heldCount: 3 }, T0), 'open');
  // past the deadline a freed seat does not reopen registration
  assert.equal(statusAfterSeats({ ...e, status: 'full', heldCount: 3 }, new Date('2026-10-03T15:00:00.000Z')), 'closed');
  for (const status of ['draft', 'closed', 'cancelled', 'completed'] as const) {
    assert.equal(statusAfterSeats({ ...e, status }, T0), status);
  }
});
