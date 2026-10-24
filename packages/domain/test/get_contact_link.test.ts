// packages/domain/test/get_contact_link.test.ts
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import {
  DomainError,
  getContactLink,
  type BookingRecord,
  type ContactAccessLogEntry,
  type ContactChannels,
  type ContactNumbers,
  type GetContactLinkDeps,
  type InstantContactRecord,
  type RegistrationRecord,
} from '../src/index.js';

const NOW = new Date('2026-10-01T12:00:00Z');
const DAY = 86_400_000;
const allOn: ContactChannels = { call: true, zalo: true, whatsapp: true };
const own: ContactNumbers = { phone: '+84912000001', zaloPhone: '+84912000002', whatsappPhone: '+14155550101' };
const booking = (over: Partial<BookingRecord> = {}): BookingRecord => ({
  id: 'b1', customerId: 'c1', photographerId: 'p1', status: 'accepted', completedAt: null, ...over,
});

interface Setup {
  bookings?: BookingRecord[];
  registrations?: RegistrationRecord[];
  instantRequests?: (InstantContactRecord & { id: string })[];
  channels?: ContactChannels | null;
  numbers?: ContactNumbers | null;
  failLog?: boolean;
}

/** Fakes that count what a Firestore (or SQL) adapter would read. */
function harness(s: Setup = {}) {
  const reads = { documents: 0, roundTrips: 0 };
  const logs: ContactAccessLogEntry[] = [];
  let next = 0;
  const registrations = s.registrations;
  const instantRequests = s.instantRequests;
  const deps: GetContactLinkDeps = {
    bookings: {
      async get(id) {
        reads.documents += 1;
        reads.roundTrips += 1;
        return (s.bookings ?? [booking()]).find((b) => b.id === id) ?? null;
      },
    },
    ...(registrations === undefined ? {} : {
      registrations: {
        async get(id: string) {
          reads.documents += 1;
          reads.roundTrips += 1;
          return registrations.find((r) => r.id === id) ?? null;
        },
      },
    }),
    ...(instantRequests === undefined ? {} : {
      instantRequests: {
        async get(id: string) {
          reads.documents += 1;
          reads.roundTrips += 1;
          return instantRequests.find((r) => r.id === id) ?? null;
        },
      },
    }),
    photographers: {
      async read() {
        reads.documents += 2;
        reads.roundTrips += 1;
        return {
          channels: s.channels === undefined ? allOn : s.channels,
          numbers: s.numbers === undefined ? own : s.numbers,
        };
      },
    },
    log: {
      async append(entry) {
        if (s.failLog === true) throw new Error('log unavailable');
        logs.push(entry);
      },
    },
    clock: { now: () => NOW },
    ids: { newId: () => `log-${++next}` },
  };
  return { deps, reads, logs };
}

const isCode = (code: string) => (e: unknown) => e instanceof DomainError && e.code === code;

describe('getContactLink', () => {
  test('an unlocked booking gets the URL of each channel', async () => {
    const { deps } = harness();
    assert.deepEqual(await getContactLink('c1', { bookingId: 'b1', channel: 'call' }, deps), { url: 'tel:+84912000001' });
    assert.deepEqual(await getContactLink('c1', { bookingId: 'b1', channel: 'zalo' }, deps), { url: 'https://zalo.me/84912000002' });
    assert.deepEqual(await getContactLink('c1', { bookingId: 'b1', channel: 'whatsapp' }, deps), { url: 'https://wa.me/14155550101' });
  });

  test('reads 3 documents in 2 round trips and writes 1 log row', async () => {
    const { deps, reads, logs } = harness();
    await getContactLink('c1', { bookingId: 'b1', channel: 'zalo' }, deps);
    assert.deepEqual(reads, { documents: 3, roundTrips: 2 });
    assert.equal(logs.length, 1);
  });

  test('the log row has the spec fields and no number', async () => {
    const { deps, logs } = harness();
    await getContactLink('c1', { bookingId: 'b1', channel: 'whatsapp' }, deps);
    assert.deepEqual(logs, [{
      id: 'log-1', requesterId: 'c1', subjectType: 'booking', subjectId: 'b1', channel: 'whatsapp', granted: true, at: NOW,
    }]);
    const text = JSON.stringify(logs);
    for (const digits of ['912000001', '912000002', '4155550101']) assert.ok(!text.includes(digits), digits);
  });

  test('locked bookings are contact_locked and the photographer is never read', async () => {
    for (const status of ['draft', 'declined', 'expired', 'cancelled']) {
      const { deps, reads, logs } = harness({ bookings: [booking({ status })] });
      await assert.rejects(getContactLink('c1', { bookingId: 'b1', channel: 'call' }, deps), isCode('contact_locked'), status);
      assert.deepEqual(reads, { documents: 1, roundTrips: 1 }, status);
      assert.equal(logs[0]?.granted, false, status);
    }
  });

  test('completed bookings follow the 30-day window', async () => {
    const recent = harness({ bookings: [booking({ status: 'completed', completedAt: new Date(NOW.getTime() - 3 * DAY) })] });
    assert.deepEqual(await getContactLink('c1', { bookingId: 'b1', channel: 'call' }, recent.deps), { url: 'tel:+84912000001' });
    const old = harness({ bookings: [booking({ status: 'reviewed', completedAt: new Date(NOW.getTime() - 31 * DAY) })] });
    await assert.rejects(getContactLink('c1', { bookingId: 'b1', channel: 'call' }, old.deps), isCode('contact_locked'));
  });

  test("someone else's booking is permission_denied and logged", async () => {
    const { deps, reads, logs } = harness();
    await assert.rejects(getContactLink('p1', { bookingId: 'b1', channel: 'call' }, deps), isCode('permission_denied'));
    assert.deepEqual(reads, { documents: 1, roundTrips: 1 });
    assert.deepEqual(logs.map((l) => [l.requesterId, l.granted]), [['p1', false]]);
  });

  test('an unknown booking is not_found and logged', async () => {
    const { deps, logs } = harness({ bookings: [] });
    await assert.rejects(getContactLink('c1', { bookingId: 'nope', channel: 'call' }, deps), isCode('not_found'));
    assert.equal(logs.length, 1);
    assert.equal(logs[0]?.subjectId, 'nope');
  });

  test('a switched-off channel, missing data or a malformed number are not_found', async () => {
    const cases: Setup[] = [
      { channels: { call: true, zalo: false, whatsapp: true } },
      { channels: null },
      { numbers: null },
      { numbers: { phone: '+84912000001', zaloPhone: '0912000002' } },
    ];
    for (const setup of cases) {
      const { deps, logs } = harness(setup);
      await assert.rejects(
        getContactLink('c1', { bookingId: 'b1', channel: 'zalo' }, deps),
        isCode('not_found'),
        JSON.stringify(setup),
      );
      assert.equal(logs[0]?.granted, false);
    }
  });

  test('malformed requests are invalid_argument: nothing read, nothing logged', async () => {
    const { deps, reads, logs } = harness();
    for (const data of [null, {}, { bookingId: 'b1', channel: 'in_app' }, { bookingId: 'b1/x', channel: 'call' }]) {
      await assert.rejects(getContactLink('c1', data, deps), isCode('invalid_argument'));
    }
    assert.deepEqual(reads, { documents: 0, roundTrips: 0 });
    assert.equal(logs.length, 0);
  });

  test('registrations are not_found until the events plan wires a reader', async () => {
    const { deps, logs } = harness();
    await assert.rejects(getContactLink('c1', { registrationId: 'r1', channel: 'call' }, deps), isCode('not_found'));
    assert.deepEqual(logs.map((l) => [l.subjectType, l.subjectId, l.granted]), [['event_registration', 'r1', false]]);
  });

  test('registrations with a reader follow the ticket rule', async () => {
    const reg = (over: Partial<RegistrationRecord>): RegistrationRecord => ({
      id: 'r1', userId: 'c1', photographerId: 'p1', status: 'paid', eventEndsAt: new Date(NOW.getTime() - DAY), contactEligible: true, ...over,
    });
    const ask = (uid: string, r: RegistrationRecord) =>
      getContactLink(uid, { registrationId: 'r1', channel: 'call' }, harness({ registrations: [r] }).deps);
    assert.deepEqual(await ask('c1', reg({})), { url: 'tel:+84912000001' });
    await assert.rejects(ask('c1', reg({ eventEndsAt: new Date(NOW.getTime() - 8 * DAY) })), isCode('contact_locked'));
    await assert.rejects(ask('c2', reg({})), isCode('permission_denied'));
    await assert.rejects(ask('c1', reg({ photographerId: null })), isCode('not_found'));
    await assert.rejects(ask('c1', reg({ contactEligible: false })), isCode('contact_locked'));
  });

  test('a failing log write fails the call: no URL without an audit row', async () => {
    const { deps } = harness({ failLog: true });
    await assert.rejects(getContactLink('c1', { bookingId: 'b1', channel: 'call' }, deps), /log unavailable/);
  });

  test('getContactLink → blocked and logs not granted', async () => {
    const { deps, logs } = harness();
    const depsWithBlock: GetContactLinkDeps = {
      ...deps,
      blocks: {
        async isBlockedEitherWay(a: string, b: string) {
          return (a === 'c1' && b === 'p1') || (a === 'p1' && b === 'c1');
        },
      },
    };

    await assert.rejects(
      getContactLink('c1', { bookingId: 'b1', channel: 'call' }, depsWithBlock),
      isCode('blocked'),
    );
    assert.deepEqual(logs.map((l) => [l.requesterId, l.granted]), [['c1', false]]);
  });
});

describe('getContactLink: instant_request (#140 Decision 22)', () => {
  const instant = (over: Partial<InstantContactRecord & { id: string }> = {}): InstantContactRecord & { id: string } => ({
    id: 'ir1', customerId: 'c1', photographerId: 'p1', status: 'en_route', paidAt: new Date(NOW.getTime() - DAY), completedAt: null, ...over,
  });
  const ask = (uid: string, r: InstantContactRecord & { id: string }, data: Record<string, unknown> = {}) => {
    const h = harness({ instantRequests: [r] });
    return { h, call: getContactLink(uid, { instantRequestId: 'ir1', channel: 'call', ...data }, h.deps) };
  };

  test('instant_request: unlocked for the customer while a photographer is assigned and the request is paid', async () => {
    for (const status of ['assigned', 'en_route', 'arrived', 'in_progress', 'finished']) {
      const { h, call } = ask('c1', instant({ status }));
      assert.deepEqual(await call, { url: 'tel:+84912000001' }, status);
      assert.deepEqual(h.logs.map((l) => [l.subjectType, l.subjectId, l.granted]), [['instant_request', 'ir1', true]]);
    }
  });

  test('locked while unpaid even when assigned (contact_locked; every #140 request)', async () => {
    const { h, call } = ask('c1', instant({ paidAt: null }));
    await assert.rejects(call, isCode('contact_locked'));
    assert.deepEqual(h.reads, { documents: 1, roundTrips: 1 });
  });

  test('locked before assignment (contact_locked)', async () => {
    for (const status of ['choosing', 'searching', 'no_match']) {
      await assert.rejects(ask('c1', instant({ status, photographerId: null })).call, isCode('contact_locked'), status);
    }
    await assert.rejects(ask('c1', instant({ status: 'cancelled_by_customer' })).call, isCode('contact_locked'));
  });

  test('unlocked 7 days after completion, locked on day 8', async () => {
    const done = (days: number) => instant({ status: 'completed', completedAt: new Date(NOW.getTime() - days * DAY) });
    assert.deepEqual(await ask('c1', done(7)).call, { url: 'tel:+84912000001' });
    await assert.rejects(ask('c1', done(8)).call, isCode('contact_locked'));
    await assert.rejects(ask('c1', instant({ status: 'completed', completedAt: null })).call, isCode('contact_locked'));
  });

  test('another user is permission_denied', async () => {
    await assert.rejects(ask('p1', instant()).call, isCode('permission_denied'));
    await assert.rejects(ask('c2', instant()).call, isCode('permission_denied'));
  });

  test('not_found without a reader or for an unknown request', async () => {
    await assert.rejects(getContactLink('c1', { instantRequestId: 'ir1', channel: 'call' }, harness().deps), isCode('not_found'));
    await assert.rejects(getContactLink('c1', { instantRequestId: 'ir9', channel: 'call' }, harness({ instantRequests: [] }).deps), isCode('not_found'));
  });

  test('parse refuses two subject keys', async () => {
    const { deps, reads, logs } = harness({ instantRequests: [instant()] });
    for (const data of [
      { instantRequestId: 'ir1', bookingId: 'b1', channel: 'call' },
      { instantRequestId: 'ir1', registrationId: 'r1', channel: 'call' },
      { instantRequestId: 'ir/1', channel: 'call' },
    ]) {
      await assert.rejects(getContactLink('c1', data, deps), isCode('invalid_argument'));
    }
    assert.deepEqual(reads, { documents: 0, roundTrips: 0 });
    assert.equal(logs.length, 0);
  });
});

/**
 * S27 R8 on getContactLink. #136 built no assignee branch here (S26 spec §5.7: the customer opens the
 * studio's channels; the assignee's own channels are "chưa làm", the mock has no button). So a collaborator,
 * pending, accepted or replaced, is never the subject of a booking's contact link; the collaborator → customer
 * direction (reading `bookings/{id}/private/contact`) is the rules' job, with `collaboratorContactOpen`.
 */
describe('getContactLink: studio bookings with a collaborator (S27 R8)', () => {
  const studioBooking = (over: Record<string, unknown>): BookingRecord =>
    ({ ...booking({ photographerId: 's1' }), isStudio: true, assigneeId: 'p1', assigneeKind: 'collaborator', ...over }) as BookingRecord;

  function readsOf(record: BookingRecord) {
    const { deps } = harness({ bookings: [record] });
    const read: string[] = [];
    const photographers = deps.photographers;
    return {
      read,
      deps: { ...deps, photographers: { read: (id: string) => { read.push(id); return photographers.read(id); } } },
    };
  }

  test("the customer cannot open a pending collaborator's channels: the booking's link opens the studio", async () => {
    const { deps, read } = readsOf(studioBooking({ assigneeAccepted: false }));
    assert.deepEqual(await getContactLink('c1', { bookingId: 'b1', channel: 'call' }, deps), { url: 'tel:+84912000001' });
    assert.deepEqual(read, ['s1']);
  });

  test("after acceptance the link still opens the studio, never the collaborator's own channels (S26 §5.7)", async () => {
    const { deps, read } = readsOf(studioBooking({ assigneeAccepted: true }));
    await getContactLink('c1', { bookingId: 'b1', channel: 'zalo' }, deps);
    assert.deepEqual(read, ['s1']);
  });

  test('a pending, accepted or replaced collaborator is not the subject and cannot ask for the link (permission_denied)', async () => {
    for (const over of [{ assigneeAccepted: false }, { assigneeAccepted: true }, { assigneeId: 'p2', assigneeAccepted: true }]) {
      const { deps, read } = readsOf(studioBooking(over));
      await assert.rejects(getContactLink('p1', { bookingId: 'b1', channel: 'call' }, deps), isCode('permission_denied'));
      assert.deepEqual(read, []);
    }
  });
});
