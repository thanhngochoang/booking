import { after, before, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { ORGANIZER_TERMS_VERSION, formatVnDate, formatVnTime, newUlid, passDisplay } from '@photobooking/domain';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import {
  AN,
  BINH,
  DUNG,
  LAN,
  SEED_BOOKING_LAN_AN_PASS,
  SEED_EVENT_ENTRY_BAI_DA,
  SEED_ORGANIZER_BAI_DA,
  SEED_PASSWORD,
  SEED_PASS_BOOKING_LAN_AN,
  SEED_PASS_ENTRY_LAN,
  SEED_SPOT_BAI_DA,
  SEED_USERS,
} from '../../seed/fixtures.js';
import { bucketUrl } from './event_social_support.js';

// S30 scanPass on the emulators (#223, plan Task 6, Review Focus 2): written here, run by CI. The server decides what
// a scan changes from the scanner's roles, in one Firestore transaction; the venue gate reads the event's real venue.

let app: App;
let db: Firestore;
const tokens = new Map<string, string>();
const HOUR = 3_600_000;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'scan-pass-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  for (const u of SEED_USERS) tokens.set(u.uid, await signIn(u.email, SEED_PASSWORD));
});
after(async () => {
  await deleteApp(app);
});

const call = (name: string, uid: string, payload: unknown) => callCallable(name, payload, tokens.get(uid));
const data = async (path: string) => (await db.doc(path).get()).data() ?? {};
const codeOf = (res: { error?: { details?: unknown } }) => (res.error?.details as { code?: string } | undefined)?.code;

/** Moves the seeded Lan ↔ An booking around "now" (Vietnam), so the shooter's window is open whenever CI runs. */
async function bookingAroundNow(): Promise<void> {
  const now = new Date();
  const start = formatVnTime(new Date(Math.max(now.getTime() - HOUR, new Date(`${formatVnDate(now)}T00:00:00+07:00`).getTime())));
  const endAt = new Date(Math.min(now.getTime() + HOUR, new Date(`${formatVnDate(now)}T23:59:00+07:00`).getTime()));
  await db.doc(`bookings/${SEED_BOOKING_LAN_AN_PASS}`).update({ day: formatVnDate(now), date: formatVnDate(now), start, end: formatVnTime(endAt) });
  await db.doc(`passes/${SEED_PASS_BOOKING_LAN_AN}`).update({ day: formatVnDate(now) });
}

describe('S30 scanPass on the emulators', () => {
  test('the gate refuses Lan\'s entry ticket of tomorrow (wrong_day); no other part changes', async () => {
    const res = await call('scanPass', DUNG, { code: passDisplay(SEED_PASS_ENTRY_LAN) });
    assert.equal(codeOf(res), 'wrong_day', res.text);
    assert.equal(codeOf(await call('scanPass', SEED_ORGANIZER_BAI_DA, { code: SEED_PASS_ENTRY_LAN.toLowerCase() })), 'wrong_day');
    // A photographer is not the gate of this ticket.
    assert.equal(codeOf(await call('scanPass', BINH, { code: SEED_PASS_ENTRY_LAN })), 'not_your_pass');
  });

  test('the shooter\'s scan moves the booking to shooting; another scanner is not_your_pass; a rescan is already_checked_in', async () => {
    await bookingAroundNow();
    assert.equal(codeOf(await call('scanPass', DUNG, { code: SEED_PASS_BOOKING_LAN_AN })), 'not_your_pass');
    const res = await call('scanPass', AN, { code: passDisplay(SEED_PASS_BOOKING_LAN_AN) });
    assert.equal(res.status, 200, res.text);
    const out = res.result as { booking: { id: string; customerName: string } | null; registrations: unknown[] };
    assert.deepEqual(out.booking, { id: SEED_BOOKING_LAN_AN_PASS, customerName: 'Lan (seed)' });
    assert.equal(res.text.includes('+84'), false);
    const b = await data(`bookings/${SEED_BOOKING_LAN_AN_PASS}`);
    assert.equal(b.status, 'shooting');
    assert.ok(b.checkedInAt instanceof Timestamp);
    assert.equal(codeOf(await call('scanPass', AN, { code: SEED_PASS_BOOKING_LAN_AN })), 'already_checked_in');
    // Another photographer is not this booking's shooter.
    assert.equal(codeOf(await call('scanPass', BINH, { code: SEED_PASS_BOOKING_LAN_AN })), 'not_your_pass');
  });

  test('gate staff check a ticket of today in: checkedInAt, entry_days.checkedIn and their scansToday', async () => {
    const today = formatVnDate(new Date());
    const buyer = LAN;
    const r = await call('registerEntry', buyer, {
      eventId: SEED_EVENT_ENTRY_BAI_DA, visitDay: today, items: [{ ticketTypeId: 'adult', qty: 2 }], name: 'Lan', method: 'bank_qr',
    });
    // After the spot closes (18:00 in Vietnam) today's tickets are no longer sold; the test then has nothing to scan.
    if (r.status !== 200) {
      assert.equal(codeOf(r), 'day_closed', r.text);
      return;
    }
    const { registrationId, paymentId } = r.result as { registrationId: string; paymentId: string };
    assert.equal((await call('confirmFakePayment', buyer, { paymentId })).status, 200);
    const regPath = `events/${SEED_EVENT_ENTRY_BAI_DA}/registrations/${registrationId}`;
    const code = String((await data(`${regPath}/private/pass`)).code);
    const res = await call('scanPass', DUNG, { code });
    assert.equal(res.status, 200, res.text);
    const out = res.result as { registrations: { id: string; kind: string; quantity: number }[]; todayCount: number | null };
    assert.deepEqual(out.registrations.map((x) => [x.id, x.kind, x.quantity]), [[registrationId, 'entry', 2]]);
    assert.ok((await data(regPath)).checkedInAt instanceof Timestamp);
    const day = await data(`entry_days/${SEED_EVENT_ENTRY_BAI_DA}_${today}`);
    assert.equal(out.todayCount, day.checkedIn);
    assert.ok(Number(day.checkedIn) >= 2);
    assert.equal((await data(`organizers/${SEED_ORGANIZER_BAI_DA}/gate_staff/${DUNG}`)).scansToday?.day, today);
    // The organizer's scan of the same ticket: already in.
    assert.equal(codeOf(await call('scanPass', SEED_ORGANIZER_BAI_DA, { code })), 'already_checked_in');
  });

  test('the venue gate reads the event\'s real venue: the spot manager checks a ticket of An\'s event at the spot in', async () => {
    const eventId = newUlid(Date.now());
    const path = `eventCovers/${AN}/${eventId}/cover.jpg`;
    const start = new Date(Date.now() + HOUR);
    const saved = await call('saveEventDraft', AN, {
      eventId, title: `Photo walk ${eventId.slice(-6)}`, type: 'photo_walk', coverUrl: bucketUrl(path), coverPath: path,
      startAt: start.toISOString(), endAt: new Date(start.getTime() + 2 * HOUR).toISOString(),
      location: { name: 'Bãi đá sông Hồng', lat: 21.0493, lng: 105.8612 }, capacity: 10, price: 0,
      venue: { kind: 'managed_spot', spotId: SEED_SPOT_BAI_DA, termsVersion: ORGANIZER_TERMS_VERSION },
    });
    assert.equal(saved.status, 200, saved.text);
    // The first publish sends the venue request; the manager accepts (no fee); the second publish opens it.
    await call('publishEvent', AN, { eventId });
    assert.equal((await data(`events/${eventId}`)).venueConsent, 'pending');
    const accepted = await call('respondVenueConsent', SEED_ORGANIZER_BAI_DA, { eventId, accept: true, venueFeePerGuest: 0 });
    assert.equal(accepted.status, 200, accepted.text);
    assert.equal((await call('publishEvent', AN, { eventId })).status, 200);
    const reg = await call('registerEvent', LAN, { eventId, quantity: 1, name: 'Lan' });
    assert.equal(reg.status, 200, reg.text);
    const regId = (reg.result as { registrationId: string }).registrationId;
    const ticketCode = String((await data(`events/${eventId}/registrations/${regId}`)).ticketCode);

    // Gate staff of the spot's manager and the manager itself act as the venue gate (gateCheckedInAt only).
    const res = await call('scanPass', DUNG, { code: ticketCode });
    assert.equal(res.status, 200, res.text);
    assert.deepEqual((res.result as { registrations: { kind: string }[] }).registrations.map((x) => x.kind), ['venue_gate']);
    const after = await data(`events/${eventId}/registrations/${regId}`);
    assert.ok(after.gateCheckedInAt instanceof Timestamp);
    assert.equal(after.checkedInAt ?? null, null);
    // The host still checks the attendee in for the event itself (the old callable delegates to scanPass).
    const host = await call('checkInRegistration', AN, { eventId, ticketCode });
    assert.equal(host.status, 200, host.text);
    assert.ok((await data(`events/${eventId}/registrations/${regId}`)).checkedInAt instanceof Timestamp);
  });
});
