import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { USAGE, runClock, type ClockIo } from '../../tools/clock.js';

// `npm run clock -- events|bookings` (S17 Decision 11): runs one scheduled clock on the emulators,
// which never fire schedules. Refuses anything but local emulator hosts.

const LOCAL = { FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080', FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099', GCLOUD_PROJECT: 'booking-c1922' };

function io() {
  const out: string[] = [];
  const calls: string[] = [];
  const clockIo: ClockIo = {
    print: (l) => void out.push(l),
    events: async () => {
      calls.push('events');
      return { closed: 0, completed: 1, consentExpired: 0, refunded: 0, refundsResent: 0, soonEvents: 1, soonSent: 2 };
    },
    bookings: async () => {
      calls.push('bookings');
      return { cleanedDrafts: 0, expiredRequests: 0, upcomingTransitions: 1, autoCompletions: 0, releasedEscrows: 0 };
    },
  };
  return { out, calls, clockIo };
}

describe('clock CLI', () => {
  it('refuses a non-local Firestore host', async () => {
    const t = io();
    await assert.rejects(
      runClock(['events'], { ...LOCAL, FIRESTORE_EMULATOR_HOST: 'firestore.googleapis.com:443' }, t.clockIo),
      /Refusing to run: FIRESTORE_EMULATOR_HOST/,
    );
    await assert.rejects(runClock(['bookings'], { GCLOUD_PROJECT: 'booking-c1922' }, t.clockIo), /Refusing to run/);
    assert.deepEqual(t.calls, []);
  });

  it('events runs handleEventClock once and prints the counts', async () => {
    const t = io();
    assert.equal(await runClock(['events'], LOCAL, t.clockIo), 0);
    assert.deepEqual(t.calls, ['events']);
    assert.deepEqual(t.out, ['eventClock: closed=0 completed=1 consentExpired=0 refunded=0 refundsResent=0 soonEvents=1 soonSent=2']);
  });

  it('bookings runs handleBookingClock once', async () => {
    const t = io();
    assert.equal(await runClock(['bookings'], LOCAL, t.clockIo), 0);
    assert.deepEqual(t.calls, ['bookings']);
    assert.match(t.out[0] ?? '', /^bookingClock: .*upcomingTransitions=1/);
  });

  it('unknown command prints usage', async () => {
    for (const argv of [[], ['payments'], ['--help']]) {
      const t = io();
      assert.equal(await runClock(argv, LOCAL, t.clockIo), argv[0] === '--help' ? 0 : 2);
      assert.deepEqual(t.out, [USAGE]);
      assert.deepEqual(t.calls, []);
    }
  });
});
