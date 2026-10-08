import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import type { EventRecord, RegistrationDoc } from '../src/event.js';
import { EVENT_SOON_HOURS, eventSoonContent, sendEventSoonNotices } from '../src/event_notices.js';
import type { NotifyDeps } from '../src/notification_ports.js';
import { renderNotification } from '../src/notification_render.js';
import { createEventWorld, eventRecord, registrationDoc, type EventWorld } from './support/event_world.js';
import { createNotifyWorld, type NotifyWorld } from './support/notify_world.js';

const HOUR_MS = 3_600_000;
// 2026-10-10 13:00 UTC = 20:00 in Vietnam (outside quiet hours).
const NOW = new Date('2026-10-10T13:00:00.000Z');
const inHours = (h: number, from = NOW): Date => new Date(from.getTime() + h * HOUR_MS);

interface World {
  readonly ev: EventWorld;
  readonly nw: NotifyWorld;
  readonly notify: NotifyDeps;
  readonly errors: string[];
}

/** Both worlds on one clock, so `notify` stamps rows with the event clock's time. */
function world(now = NOW): World {
  const ev = createEventWorld();
  ev.clock.set(now);
  const nw = createNotifyWorld(now);
  return { ev, nw, notify: { ...nw.deps, clock: ev.clock }, errors: [] };
}

function seedEvent(w: World, over: Partial<EventRecord> = {}): EventRecord {
  const e = eventRecord({
    id: 'evS', hashtagKey: 'evs', title: 'Chụp phố đêm', coverUrl: 'https://s.test/cover.jpg',
    startAt: inHours(36), endAt: inHours(39), status: 'open',
    location: { name: 'Quận 1', meetingPoint: 'Nhà hát Thành phố', lat: 10.77, lng: 106.7, geohash: 'w3gv2', areaId: null },
    ...over,
  });
  w.ev.store.seedEvent(e);
  return e;
}

function seedReg(w: World, id: string, userId: string, status: RegistrationDoc['status'], eventId = 'evS'): void {
  w.ev.store.seedRegistration(registrationDoc({ id, eventId, userId, status, ticketCode: `VE-${id.toUpperCase().padEnd(4, 'X').slice(0, 4)}-1012` }));
}

const run = (w: World) => sendEventSoonNotices(w.ev.deps, w.notify, (id) => w.errors.push(id));
const rowsOf = (w: World, uid: string) => w.nw.store.rowsOf(uid).filter((r) => r.type === 'event_soon');

describe('sendEventSoonNotices', () => {
  test('an open event starting in 36 h notifies each paid ticket once and sets soonNoticeAt', async () => {
    const w = world();
    seedEvent(w);
    seedReg(w, 'rga', 'cu1', 'paid');
    seedReg(w, 'rgb', 'cu2', 'paid');
    assert.deepEqual(await run(w), { events: 1, sent: 2 });
    for (const uid of ['cu1', 'cu2']) {
      const rows = rowsOf(w, uid);
      assert.equal(rows.length, 1, uid);
      assert.equal(rows[0]?.target, '/e/evS');
      assert.equal(rows[0]?.thumbUrl, 'https://s.test/cover.jpg');
    }
    assert.equal(rowsOf(w, 'cu1')[0]?.id, 'n_event_soon_evS_rga');
    assert.equal(w.ev.store.events.get('evS')?.soonNoticeAt?.getTime(), NOW.getTime());
    // A server marker, not an edit: the version stays.
    assert.equal(w.ev.store.events.get('evS')?.version, 1);
    assert.deepEqual(w.errors, []);
  });

  test('a second clock run sends nothing', async () => {
    const w = world();
    seedEvent(w);
    seedReg(w, 'rga', 'cu1', 'paid');
    await run(w);
    const writes = w.nw.store.writes;
    const pushes = w.nw.push.sent.length;
    w.ev.clock.advance(5 * 60_000);
    assert.deepEqual(await run(w), { events: 0, sent: 0 });
    assert.equal(w.nw.store.writes, writes);
    assert.equal(w.nw.push.sent.length, pushes);
    assert.equal(rowsOf(w, 'cu1').length, 1);
  });

  test('held, cancelled and refunded registrations get nothing', async () => {
    const w = world();
    seedEvent(w);
    seedReg(w, 'rga', 'cu1', 'paid');
    seedReg(w, 'rgh', 'cu3', 'held');
    seedReg(w, 'rgc', 'cu4', 'cancelled');
    seedReg(w, 'rgr', 'cu5', 'refunded');
    assert.deepEqual(await run(w), { events: 1, sent: 1 });
    for (const uid of ['cu3', 'cu4', 'cu5']) assert.equal(w.nw.store.rowsOf(uid).length, 0, uid);
  });

  test('a cancelled or completed event is not due', async () => {
    for (const status of ['cancelled', 'completed', 'draft'] as const) {
      const w = world();
      seedEvent(w, { status });
      seedReg(w, 'rga', 'cu1', 'paid');
      assert.deepEqual(await run(w), { events: 0, sent: 0 }, status);
      assert.equal(w.nw.store.rowsOf('cu1').length, 0, status);
    }
    // full and closed (registration over) still remind.
    for (const status of ['full', 'closed'] as const) {
      const w = world();
      seedEvent(w, { status });
      seedReg(w, 'rga', 'cu1', 'paid');
      assert.deepEqual(await run(w), { events: 1, sent: 1 }, status);
    }
  });

  test('an event 49 h ahead is not due; one already started is not due', async () => {
    const far = world();
    seedEvent(far, { startAt: inHours(EVENT_SOON_HOURS + 1), endAt: inHours(EVENT_SOON_HOURS + 4) });
    seedReg(far, 'rga', 'cu1', 'paid');
    assert.deepEqual(await run(far), { events: 0, sent: 0 });
    // Exactly 48 h ahead is due.
    far.ev.clock.set(inHours(1));
    assert.deepEqual(await run(far), { events: 1, sent: 1 });

    const started = world();
    seedEvent(started, { startAt: inHours(-1), endAt: inHours(2) });
    seedReg(started, 'rga', 'cu1', 'paid');
    assert.deepEqual(await run(started), { events: 0, sent: 0 });
    const exact = world();
    seedEvent(exact, { startAt: NOW, endAt: inHours(2) });
    seedReg(exact, 'rga', 'cu1', 'paid');
    assert.deepEqual(await run(exact), { events: 0, sent: 0 });
  });

  test('a failed send leaves soonNoticeAt null and the next run completes without doubles', async () => {
    const w = world();
    seedEvent(w);
    seedReg(w, 'rga', 'cu1', 'paid');
    seedReg(w, 'rgb', 'cu2', 'paid');
    const real = w.nw.store.getPrefs.bind(w.nw.store);
    let failures = 1;
    w.nw.store.getPrefs = async (uid: string) => {
      if (uid === 'cu2' && failures > 0) {
        failures -= 1;
        throw new Error('firestore unavailable');
      }
      return real(uid);
    };
    assert.deepEqual(await run(w), { events: 0, sent: 1 });
    assert.deepEqual(w.errors, ['evS']);
    assert.equal(w.ev.store.events.get('evS')?.soonNoticeAt ?? null, null);
    assert.equal(rowsOf(w, 'cu1').length, 1);
    assert.equal(rowsOf(w, 'cu2').length, 0);

    w.ev.clock.advance(5 * 60_000);
    assert.deepEqual(await run(w), { events: 1, sent: 1 });
    assert.equal(rowsOf(w, 'cu1').length, 1);
    assert.equal(rowsOf(w, 'cu2').length, 1);
    assert.equal(w.nw.push.sent.filter((p) => p.uid === 'cu1').length, 1);
    assert.notEqual(w.ev.store.events.get('evS')?.soonNoticeAt ?? null, null);
    assert.deepEqual(w.errors, ['evS']);
  });

  test('a push-only recipient gets exactly one push across retries while a failing one is retried', async () => {
    const w = world();
    seedEvent(w);
    seedReg(w, 'rga', 'cu1', 'paid');
    seedReg(w, 'rgb', 'cu2', 'paid');
    // cu1: "Sự kiện" inbox off, push on → no dedupe row, so only the event's list stops a re-push.
    w.nw.store.prefs.set('cu1', { channels: { events: { push: true, inApp: false } } });
    const real = w.nw.store.getPrefs.bind(w.nw.store);
    let failures = 2;
    w.nw.store.getPrefs = async (uid: string) => {
      if (uid === 'cu2' && failures > 0) {
        failures -= 1;
        throw new Error('firestore unavailable');
      }
      return real(uid);
    };
    const pushesTo = (uid: string) => w.nw.push.sent.filter((p) => p.uid === uid).length;

    // notify reports a push-only send as 'created'.
    assert.deepEqual(await run(w), { events: 0, sent: 1 });
    assert.equal(pushesTo('cu1'), 1);
    assert.equal(rowsOf(w, 'cu1').length, 0);
    assert.deepEqual(w.ev.store.events.get('evS')?.soonNotifiedRegIds, ['rga']);
    assert.equal(w.ev.store.events.get('evS')?.soonNoticeAt ?? null, null);

    w.ev.clock.advance(5 * 60_000);
    assert.deepEqual(await run(w), { events: 0, sent: 0 });
    assert.equal(pushesTo('cu1'), 1);
    assert.equal(rowsOf(w, 'cu2').length, 0);
    assert.equal(w.ev.store.events.get('evS')?.soonNoticeAt ?? null, null);

    w.ev.clock.advance(5 * 60_000);
    assert.deepEqual(await run(w), { events: 1, sent: 1 });
    assert.equal(pushesTo('cu1'), 1);
    assert.equal(pushesTo('cu2'), 1);
    assert.equal(rowsOf(w, 'cu2').length, 1);
    const ev = w.ev.store.events.get('evS');
    assert.notEqual(ev?.soonNoticeAt ?? null, null);
    // The list is only needed until the marker is set.
    assert.deepEqual(ev?.soonNotifiedRegIds, []);
    assert.equal(ev?.version, 1);
    assert.deepEqual(w.errors, ['evS', 'evS']);

    // Marker set: a later run sends nothing to anyone.
    w.ev.clock.advance(5 * 60_000);
    assert.deepEqual(await run(w), { events: 0, sent: 0 });
    assert.equal(w.nw.push.sent.length, 2);
  });

  test('a ticket paid between the send and the marker is reminded on the next run', async () => {
    const w = world();
    seedEvent(w);
    seedReg(w, 'rga', 'cu1', 'paid');
    const realPrefs = w.nw.store.getPrefs.bind(w.nw.store);
    let added = false;
    w.nw.store.getPrefs = async (uid: string) => {
      if (!added) {
        added = true;
        seedReg(w, 'rgb', 'cu2', 'paid');
      }
      return realPrefs(uid);
    };
    assert.deepEqual(await run(w), { events: 0, sent: 1 });
    assert.deepEqual(w.ev.store.events.get('evS')?.soonNotifiedRegIds, ['rga']);
    w.ev.clock.advance(5 * 60_000);
    assert.deepEqual(await run(w), { events: 1, sent: 1 });
    assert.equal(rowsOf(w, 'cu1').length, 1);
    assert.equal(rowsOf(w, 'cu2').length, 1);
    assert.deepEqual(w.errors, []);
  });

  test('one failing event does not block the others', async () => {
    const w = world();
    seedEvent(w, { id: 'evA', hashtagKey: 'eva' });
    seedEvent(w, { id: 'evB', hashtagKey: 'evb' });
    seedReg(w, 'rga', 'cu1', 'paid', 'evA');
    seedReg(w, 'rgb', 'cu2', 'paid', 'evB');
    w.ev.store.failNext = { error: new Error('boom'), times: 1 };
    assert.deepEqual(await run(w), { events: 1, sent: 1 });
    assert.equal(w.errors.length, 1);
  });

  test('an event cancelled after the query is skipped', async () => {
    const w = world();
    const e = seedEvent(w);
    seedReg(w, 'rga', 'cu1', 'paid');
    const realDue = w.ev.store.dueForSoonNotice.bind(w.ev.store);
    w.ev.store.dueForSoonNotice = async (now, horizon, limit) => {
      const due = await realDue(now, horizon, limit);
      w.ev.store.events.set(e.id, { ...e, status: 'cancelled' });
      return due;
    };
    assert.deepEqual(await run(w), { events: 0, sent: 0 });
    assert.equal(w.nw.store.rowsOf('cu1').length, 0);
  });

  test('the row reads like the mock: title, meeting point and time', async () => {
    const w = world();
    // 19:00 on 12 Oct in Vietnam; now is 20:00 on 10 Oct.
    seedEvent(w, { startAt: new Date('2026-10-12T12:00:00.000Z'), endAt: new Date('2026-10-12T15:00:00.000Z') });
    seedReg(w, 'rga', 'cu1', 'paid');
    await run(w);
    const row = rowsOf(w, 'cu1')[0];
    assert.equal(row?.title, 'Chụp phố đêm bắt đầu sau 2 ngày');
    assert.equal(row?.body, 'Tập trung 19:00 tại Nhà hát Thành phố. Mang vé trong mục Vé.');
    assert.equal(row?.tab, 'events');
  });

  test('turning off the "Sự kiện" channel suppresses it and still marks the event', async () => {
    const w = world();
    seedEvent(w);
    seedReg(w, 'rga', 'cu1', 'paid');
    w.nw.store.prefs.set('cu1', { channels: { events: { push: false, inApp: false } } });
    assert.deepEqual(await run(w), { events: 1, sent: 0 });
    assert.equal(w.nw.store.rowsOf('cu1').length, 0);
    assert.notEqual(w.ev.store.events.get('evS')?.soonNoticeAt ?? null, null);
  });
});

describe('eventSoonContent', () => {
  // 23:30 on 10 Oct in Vietnam (16:30 UTC): the Vietnam day changes in 30 minutes.
  const LATE = new Date('2026-10-10T16:30:00.000Z');
  const ev = (startAt: Date, over: Partial<EventRecord> = {}) => eventRecord({ title: 'Chụp phố đêm', startAt, ...over });
  const title = (startAt: Date, now: Date) => renderNotification(eventSoonContent(ev(startAt), now)).title;

  test('title says "bắt đầu sau 2 ngày" 30 h before a next-next-day start; "ngày mai"; "hôm nay"', () => {
    // 30 h later = 05:30 on 12 Oct in Vietnam.
    assert.equal(title(inHours(30, LATE), LATE), 'Chụp phố đêm bắt đầu sau 2 ngày');
    // 09:00 on 11 Oct in Vietnam: 9.5 hours away, but tomorrow.
    assert.equal(title(new Date('2026-10-11T02:00:00.000Z'), LATE), 'Chụp phố đêm bắt đầu ngày mai');
    // 00:30 on 11 Oct in Vietnam; the event is at 19:00 the same day.
    const afterMidnight = new Date('2026-10-10T17:30:00.000Z');
    assert.equal(title(new Date('2026-10-11T12:00:00.000Z'), afterMidnight), 'Chụp phố đêm bắt đầu hôm nay');
    assert.equal(eventSoonContent(ev(new Date('2026-10-11T12:00:00.000Z')), afterMidnight).start, '19:00');
  });

  test('place is the meeting point, else the location name', () => {
    const loc = { name: 'Hồ Gươm', meetingPoint: 'Cổng đền Ngọc Sơn', lat: 21, lng: 105, geohash: 'w7er8u0', areaId: null };
    const start = inHours(30);
    assert.equal(eventSoonContent(ev(start, { location: loc }), NOW).place, 'Cổng đền Ngọc Sơn');
    assert.equal(eventSoonContent(ev(start, { location: { ...loc, meetingPoint: null } }), NOW).place, 'Hồ Gươm');
  });

  test('thumbUrl is the cover; target is /e/{eventId}', async () => {
    const w = world();
    seedEvent(w, { coverUrl: null });
    seedReg(w, 'rga', 'cu1', 'paid');
    await run(w);
    const row = rowsOf(w, 'cu1')[0];
    assert.equal(row?.thumbUrl, null);
    assert.equal(row?.target, '/e/evS');
  });
});
