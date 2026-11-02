import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DomainError, type ErrorCode } from '../src/errors.js';
import { isEventManager, type EventCaller } from '../src/event.js';
import {
  VENUE_CONSENT_HOURS,
  VENUE_REQUIRED_FROM,
  respondVenueConsent,
  validateVenue,
  venueConsentNeeded,
} from '../src/event_venue.js';
import { cancelEvent, publishEvent, saveEventDraft, updateEvent } from '../src/event_use_cases.js';
import { cancelRegistration, registerEvent } from '../src/event_registration.js';
import { checkTicketPayment } from '../src/event_payments.js';
import { runEventSweeps } from '../src/event_sweeps.js';
import { ORGANIZER_TERMS_VERSION } from '../src/organizer.js';
import { createEntryWorld, org1, org2, org3, type EntryWorld } from './support/entry_world.js';
import { cu1, must, ph1, rawEvent } from './support/event_world.js';
import { organizerOf, spotOf } from './support/organizer_world.js';
import { childrenOf, createBookingEntryWorld, paymentOf, send, transfer, type BookingEntryWorld } from './support/booking_entry_world.js';

const rejects = (code: ErrorCode, field?: string) => (e: unknown) =>
  e instanceof DomainError && e.code === code && (field === undefined || e.field === field);

const HOUR = 3_600_000;
const ID = 'ev1_aaaaaaaaaaaaaaaaaaaa';
/** After VENUE_REQUIRED_FROM: 2026-10-20 10:00 in Vietnam. */
const V_NOW = new Date('2026-10-20T03:00:00.000Z');
const START = '2026-10-24T02:00:00.000Z';
const END = '2026-10-24T05:00:00.000Z';
const TERMS = ORGANIZER_TERMS_VERSION;

const managed = (spotId = 's1'): Record<string, unknown> => ({ kind: 'managed_spot', spotId, termsVersion: TERMS });
const paidPlace = (entryFee: unknown = { included: false, amountVnd: 50_000 }, over: Record<string, unknown> = {}) =>
  ({ kind: 'paid_place', entryFee, termsVersion: TERMS, ...over });
const publicPlace = (over: Record<string, unknown> = {}) =>
  ({ kind: 'public', commitmentAt: '2026-10-18T02:00:00.000Z', termsVersion: TERMS, ...over });

const raw = (creator: string, over: Record<string, unknown> = {}) => rawEvent(ID, creator, { startAt: START, endAt: END, ...over });

/** The entry world (org1 manages s1 and can sell; org3 manages s2 without a business; org2 manages nothing). */
function world(at: Date | null = null): EntryWorld {
  const w = createEntryWorld();
  if (at !== null) {
    w.clock.set(at);
    w.notify.clock.setTime(at);
  }
  w.notify.users.users.set('ph1', { name: 'Minh', avatarUrl: null });
  return w;
}

const withNotify = (w: EntryWorld) => ({ ...w.deps, notify: w.notify.deps });
const ev = (w: EntryWorld) => must(w.store.events.get(ID));

/** ph1's draft at s1 (managed by org1), published once: the venue consent request is open. */
async function requested(w: EntryWorld, over: Record<string, unknown> = {}): Promise<void> {
  await saveEventDraft(w.deps, ph1, raw('ph1', { venue: managed('s1'), ...over }));
  await publishEvent(withNotify(w), ph1, { eventId: ID });
}

describe('validateVenue (S30 Decision 16)', () => {
  const now = new Date('2026-10-18T03:00:00.000Z');
  const field = (v: unknown, f: string) => assert.throws(() => validateVenue(v, now), rejects('invalid_argument', f));

  test('managed_spot without spotId → spotId', () => field({ kind: 'managed_spot', termsVersion: TERMS }, 'spotId'));
  test('paid_place without entryFee.included → entryFee', () => field(paidPlace({ amountVnd: 50_000 }), 'entryFee'));
  test('paid_place not included without amountVnd → entryFee', () => field(paidPlace({ included: false }), 'entryFee'));
  test('public without commitmentAt → commitmentAt', () => field({ kind: 'public', termsVersion: TERMS }, 'commitmentAt'));
  test('termsVersion ≠ current → termsVersion', () => field(publicPlace({ termsVersion: '2026-01-01' }), 'termsVersion'));

  test('valid blocks come back normalized', () => {
    assert.deepEqual(validateVenue(managed('s1'), now), {
      kind: 'managed_spot', spotId: 's1', entryFee: { included: true, amountVnd: null }, commitmentAt: null, termsVersion: TERMS,
    });
    assert.deepEqual(validateVenue(paidPlace(), now).entryFee, { included: false, amountVnd: 50_000 });
    assert.equal(validateVenue(publicPlace(), now).commitmentAt, '2026-10-18T02:00:00.000Z');
  });

  test('venueConsentNeeded only for a managed spot whose manager is not the host', () => {
    const v = validateVenue(managed('s1'), now);
    assert.equal(venueConsentNeeded(v, 'ph1', 'org1'), true);
    assert.equal(venueConsentNeeded(v, 'org1', 'org1'), false);
    assert.equal(venueConsentNeeded(validateVenue(publicPlace(), now), 'ph1', 'org1'), false);
  });
});

describe('event venue on save and publish', () => {
  test('paid_place on an S29 spot with access prefills amountVnd when the input omits it', async () => {
    const w = world();
    w.store.spots.set('s9', spotOf('s9', {
      access: { type: 'ticket', fees: [{ label: 'Người lớn', amountVnd: 70_000 }], note: '', updatedAt: '2026-10-01T00:00:00.000Z', source: 'staff' },
    }));
    await saveEventDraft(w.deps, ph1, raw('ph1', { venue: paidPlace({ included: false }, { spotId: 's9' }) }));
    assert.deepEqual(ev(w).venue?.entryFee, { included: false, amountVnd: 70_000 });
  });

  test('publishEvent without venue for an event created at or after VENUE_REQUIRED_FROM → invalid_argument venue; one created before it still publishes', async () => {
    assert.ok(V_NOW.getTime() >= Date.parse(VENUE_REQUIRED_FROM));
    const late = world(V_NOW);
    await saveEventDraft(late.deps, ph1, raw('ph1'));
    await assert.rejects(publishEvent(late.deps, ph1, { eventId: ID }), rejects('invalid_argument', 'venue'));
    await saveEventDraft(late.deps, ph1, { eventId: ID, venue: publicPlace() });
    await publishEvent(late.deps, ph1, { eventId: ID });
    assert.equal(ev(late).status, 'open');

    const early = world(); // 2026-10-18, before the cut-over
    await saveEventDraft(early.deps, ph1, raw('ph1'));
    await publishEvent(early.deps, ph1, { eventId: ID });
    assert.deepEqual([ev(early).status, ev(early).venue ?? null], ['open', null]);
  });

  test('managed_spot by the manager publishes with venueConsent not_required', async () => {
    const w = world(V_NOW);
    await saveEventDraft(w.deps, org1, raw('org1', { venue: managed('s1') }));
    await publishEvent(withNotify(w), org1, { eventId: ID });
    assert.deepEqual([ev(w).status, ev(w).venueConsent, ev(w).host.type], ['open', 'not_required', 'organizer']);
    assert.equal(w.notify.store.rowsOf('org1').length, 0);
  });

  test('by another host → status draft, venueConsent pending, expires in 72 h, notification event_venue_requested to org1', async () => {
    const w = world(V_NOW);
    await requested(w);
    assert.deepEqual([ev(w).status, ev(w).venueConsent], ['draft', 'pending']);
    assert.equal(ev(w).venueConsentExpiresAt?.getTime(), V_NOW.getTime() + VENUE_CONSENT_HOURS * HOUR);
    assert.equal(VENUE_CONSENT_HOURS, 72);
    const rows = w.notify.store.rowsOf('org1');
    assert.deepEqual(rows.map((r) => [r.type, r.target]), [['event_venue_requested', `/e/${ID}`]]);
  });

  test('publish while pending → venue_consent_required', async () => {
    const w = world(V_NOW);
    await requested(w);
    await assert.rejects(publishEvent(w.deps, ph1, { eventId: ID }), rejects('venue_consent_required'));
    assert.equal(ev(w).status, 'draft');
  });

  test('a paid_place or public venue on a managed spot is refused (the manager must consent)', async () => {
    const w = world();
    await assert.rejects(saveEventDraft(w.deps, ph1, raw('ph1', { venue: paidPlace(undefined, { spotId: 's1' }) })), rejects('invalid_argument', 'kind'));
  });

  test('a managed_spot venue on a spot nobody manages is invalid_argument spotId', async () => {
    const w = world();
    w.store.spots.set('s9', spotOf('s9'));
    await assert.rejects(saveEventDraft(w.deps, ph1, raw('ph1', { venue: managed('s9') })), rejects('invalid_argument', 'spotId'));
  });
});

describe('respondVenueConsent', () => {
  test('accept with fee 20000 by org1 (canSell) → accepted, venueFeePerGuest 20000; the host is told and can publish', async () => {
    const w = world(V_NOW);
    await requested(w, { price: 150_000 });
    await respondVenueConsent(withNotify(w), org1, { eventId: ID, accept: true, venueFeePerGuest: 20_000 });
    assert.deepEqual([ev(w).venueConsent, ev(w).venueFeePerGuest, ev(w).venueManagerId], ['accepted', 20_000, 'org1']);
    assert.deepEqual(w.notify.store.rowsOf('ph1').map((r) => [r.type, r.target]), [['event_venue_answered', `/events/${ID}/manage`]]);
    await publishEvent(w.deps, ph1, { eventId: ID });
    assert.equal(ev(w).status, 'open');
  });

  test('fee > 0 without business → business_required', async () => {
    const w = world(V_NOW);
    await requested(w, { price: 150_000, venue: managed('s2') });
    await assert.rejects(respondVenueConsent(w.deps, org3, { eventId: ID, accept: true, venueFeePerGuest: 20_000 }), rejects('business_required'));
    assert.equal(ev(w).venueConsent, 'pending');
  });

  test('accept with fee 0 always fine', async () => {
    const w = world(V_NOW);
    await requested(w, { price: 150_000, venue: managed('s2') });
    await respondVenueConsent(w.deps, org3, { eventId: ID, accept: true, venueFeePerGuest: 0 });
    assert.deepEqual([ev(w).venueConsent, ev(w).venueFeePerGuest], ['accepted', 0]);
  });

  test('decline → cancelled', async () => {
    const w = world(V_NOW);
    await requested(w);
    await respondVenueConsent(withNotify(w), org1, { eventId: ID, accept: false });
    assert.deepEqual([ev(w).venueConsent, ev(w).status], ['declined', 'cancelled']);
    assert.equal(w.store.hashtags.has(ev(w).hashtagKey), false);
    assert.deepEqual(w.notify.store.rowsOf('ph1').map((r) => r.type), ['event_venue_answered']);
  });

  test('by a stranger → not_spot_manager', async () => {
    const w = world(V_NOW);
    await requested(w);
    await assert.rejects(respondVenueConsent(w.deps, org2, { eventId: ID, accept: true }), rejects('not_spot_manager'));
    await assert.rejects(respondVenueConsent(w.deps, ph1, { eventId: ID, accept: true }), rejects('not_spot_manager'));
  });

  test('respondVenueConsent with a fee above the event price is invalid_argument venueFeePerGuest', async () => {
    const w = world(V_NOW);
    await requested(w, { price: 150_000 });
    await assert.rejects(respondVenueConsent(w.deps, org1, { eventId: ID, accept: true, venueFeePerGuest: 150_001 }),
      rejects('invalid_argument', 'venueFeePerGuest'));
  });

  test('a fee equal to the price is invalid_argument venueFeePerGuest (the fee stays strictly below it)', async () => {
    const w = world(V_NOW);
    await requested(w, { price: 150_000 });
    await assert.rejects(respondVenueConsent(w.deps, org1, { eventId: ID, accept: true, venueFeePerGuest: 150_000 }),
      rejects('invalid_argument', 'venueFeePerGuest'));
    await respondVenueConsent(w.deps, org1, { eventId: ID, accept: true, venueFeePerGuest: 149_000 });
    assert.equal(ev(w).venueFeePerGuest, 149_000);
  });

  test('a free event at a managed spot can only be accepted with fee 0', async () => {
    const w = world(V_NOW);
    await requested(w, { price: 0 });
    await assert.rejects(respondVenueConsent(w.deps, org1, { eventId: ID, accept: true, venueFeePerGuest: 1000 }),
      rejects('invalid_argument', 'venueFeePerGuest'));
    await respondVenueConsent(w.deps, org1, { eventId: ID, accept: true });
    assert.deepEqual([ev(w).venueConsent, ev(w).venueFeePerGuest], ['accepted', 0]);
  });

  test('a second answer is conflict', async () => {
    const w = world(V_NOW);
    await requested(w);
    await respondVenueConsent(w.deps, org1, { eventId: ID, accept: true });
    await assert.rejects(respondVenueConsent(w.deps, org1, { eventId: ID, accept: false }), rejects('conflict'));
  });

  test('editing dates after acceptance → pending again (a new 72 h window and a new request)', async () => {
    const w = world(V_NOW);
    await requested(w, { price: 150_000 });
    await respondVenueConsent(w.deps, org1, { eventId: ID, accept: true, venueFeePerGuest: 20_000 });
    w.clock.set(new Date(V_NOW.getTime() + HOUR));
    await saveEventDraft(withNotify(w), ph1, { eventId: ID, startAt: '2026-10-25T02:00:00.000Z', endAt: '2026-10-25T05:00:00.000Z' });
    assert.deepEqual([ev(w).venueConsent, ev(w).status], ['pending', 'draft']);
    assert.equal(ev(w).venueConsentExpiresAt?.getTime(), V_NOW.getTime() + HOUR + VENUE_CONSENT_HOURS * HOUR);
    assert.equal(w.notify.store.rowsOf('org1').filter((r) => r.type === 'event_venue_requested').length, 2);
    await assert.rejects(publishEvent(w.deps, ph1, { eventId: ID }), rejects('venue_consent_required'));
  });

  /** ph1's event priced 150 000 at s1, accepted by org1 with a 20 000 fee, published. */
  async function publishedAtVenue(w: EntryWorld): Promise<void> {
    await requested(w, { price: 150_000 });
    await respondVenueConsent(w.deps, org1, { eventId: ID, accept: true, venueFeePerGuest: 20_000 });
    await publishEvent(w.deps, ph1, { eventId: ID });
    assert.equal(ev(w).status, 'open');
  }

  test('a published event at an accepted venue may raise its capacity without a new consent', async () => {
    const w = world(V_NOW);
    await publishedAtVenue(w);
    await updateEvent(withNotify(w), ph1, { eventId: ID, capacity: 20, title: 'Tên mới' });
    assert.deepEqual([ev(w).status, ev(w).capacity, ev(w).venueConsent, ev(w).venueFeePerGuest, ev(w).title], ['open', 20, 'accepted', 20_000, 'Tên mới']);
    assert.equal(w.notify.store.rowsOf('org1').filter((r) => r.type === 'event_venue_requested').length, 1);
  });

  test('without tickets, another material edit of a published event returns it to draft and asks the manager again', async () => {
    const w = world(V_NOW);
    await publishedAtVenue(w);
    w.clock.set(new Date(V_NOW.getTime() + HOUR));
    await updateEvent(withNotify(w), ph1, { eventId: ID, startAt: '2026-10-25T02:00:00.000Z', endAt: '2026-10-25T05:00:00.000Z' });
    assert.deepEqual([ev(w).status, ev(w).venueConsent, ev(w).dayKey], ['draft', 'pending', '2026-10-25']);
    assert.equal(ev(w).venueConsentExpiresAt?.getTime(), V_NOW.getTime() + HOUR + VENUE_CONSENT_HOURS * HOUR);
    assert.equal(w.notify.store.rowsOf('org1').filter((r) => r.type === 'event_venue_requested').length, 2);
    // A photographer host's old day is free again; the new one is booked only when it is published.
    assert.equal(w.store.availabilityDays.has('ph1/2026-10-24'), false);
    assert.equal(w.store.availabilityDays.has('ph1/2026-10-25'), false);
    await respondVenueConsent(w.deps, org1, { eventId: ID, accept: true, venueFeePerGuest: 20_000 });
    await publishEvent(w.deps, ph1, { eventId: ID });
    assert.deepEqual([ev(w).status, w.store.availabilityDays.get('ph1/2026-10-25')?.state], ['open', 'booked']);
  });

  test('a capacity cut or a price change without tickets also asks again', async () => {
    const w = world(V_NOW);
    await publishedAtVenue(w);
    await updateEvent(w.deps, ph1, { eventId: ID, capacity: 5 });
    assert.deepEqual([ev(w).status, ev(w).venueConsent], ['draft', 'pending']);
  });

  test('with tickets sold or held the material edit is refused venue_consent_required (field = the change)', async () => {
    const w = world(V_NOW);
    await publishedAtVenue(w);
    await registerEvent(w.deps, cu1, { eventId: ID, quantity: 1, name: 'An', method: 'bank_qr' });
    await assert.rejects(updateEvent(w.deps, ph1, { eventId: ID, capacity: 5 }), rejects('venue_consent_required', 'capacity'));
    await updateEvent(w.deps, ph1, { eventId: ID, capacity: 20 });
    assert.deepEqual([ev(w).status, ev(w).capacity], ['open', 20]);
  });

  test('while accepted, replacing the managed_spot venue is venue_consent_required venue', async () => {
    const w = world(V_NOW);
    await publishedAtVenue(w);
    await assert.rejects(updateEvent(w.deps, ph1, { eventId: ID, venue: publicPlace() }), rejects('venue_consent_required', 'venue'));
    await assert.rejects(updateEvent(w.deps, ph1, { eventId: ID, venue: managed('s2') }), rejects('venue_consent_required', 'venue'));
    assert.deepEqual([ev(w).venue?.spotId, ev(w).venueConsent], ['s1', 'accepted']);
  });

  test('expireVenueConsent after 72 h → expired, cancelled', async () => {
    const w = world(V_NOW);
    await requested(w);
    w.clock.set(new Date(V_NOW.getTime() + VENUE_CONSENT_HOURS * HOUR - 1));
    assert.equal((await runEventSweeps(w.deps)).consentExpired, 0);
    w.clock.set(new Date(V_NOW.getTime() + VENUE_CONSENT_HOURS * HOUR));
    assert.equal((await runEventSweeps(w.deps)).consentExpired, 1);
    assert.deepEqual([ev(w).venueConsent, ev(w).status], ['expired', 'cancelled']);
    await assert.rejects(respondVenueConsent(w.deps, org1, { eventId: ID, accept: true }), rejects('conflict'));
  });
});

describe('organizer-hosted ordinary events (Decisions 3, 12)', () => {
  test('an active organizer hosts a normal event: host organizer with the organizer document name and avatar', async () => {
    const w = world();
    w.store.organizers.set('org2', organizerOf('org2', { name: 'Hội Ảnh', avatarUrl: 'https://a.test/o2.jpg', businessVerified: true, payoutAccountOk: true }));
    await saveEventDraft(w.deps, org2, raw('org2'));
    assert.deepEqual(ev(w).host, { type: 'organizer', id: 'org2', name: 'Hội Ảnh', avatarUrl: 'https://a.test/o2.jpg', verified: true });
    assert.equal(isEventManager(ev(w), org2), true);
    await publishEvent(w.deps, org2, { eventId: ID });
    await updateEvent(w.deps, org2, { eventId: ID, title: 'Đổi tên' });
    await cancelEvent(w.deps, org2, { eventId: ID });
    assert.equal(ev(w).status, 'cancelled');
  });

  test('a priced event by an organizer without canSell is business_required; a free one needs only active', async () => {
    const w = world();
    await saveEventDraft(w.deps, org3, raw('org3', { price: 100_000 }));
    await assert.rejects(publishEvent(w.deps, org3, { eventId: ID }), rejects('business_required'));
    await saveEventDraft(w.deps, org3, { eventId: ID, price: 0 });
    await publishEvent(w.deps, org3, { eventId: ID });
    assert.equal(ev(w).status, 'open');
    await assert.rejects(updateEvent(w.deps, org3, { eventId: ID, price: 50_000 }), rejects('business_required'));
  });

  test('a suspended organizer (and a user who is neither) cannot host', async () => {
    const w = world();
    w.store.organizers.set('org2', organizerOf('org2', { status: 'suspended' }));
    await assert.rejects(saveEventDraft(w.deps, org2, raw('org2')), rejects('permission_denied'));
    const nobody: EventCaller = { uid: 'nobody', staffRole: null };
    await assert.rejects(saveEventDraft(w.deps, nobody, raw('nobody')), rejects('permission_denied'));
  });

  test('its ticket payments carry lineKind event_ticket, payee the organizer, payeeKind organizer', async () => {
    const w = world();
    await saveEventDraft(w.deps, org1, raw('org1', { price: 100_000 }));
    await publishEvent(w.deps, org1, { eventId: ID });
    const r = await registerEvent(w.deps, cu1, { eventId: ID, quantity: 1, name: 'An', method: 'bank_qr' });
    const p = must(w.store.payments.get(must(r.paymentId)));
    assert.deepEqual([p.lineKind, p.payeeId, p.payeeKind, p.amount], ['event_ticket', 'org1', 'organizer', 100_000]);
  });
});

describe('the venue fee line (Decisions 6, 16)', () => {
  /** ph1's event priced 150 000 at s1 (org1), consented with `fee` per guest, published. */
  async function feeEvent(fee: number): Promise<BookingEntryWorld> {
    const w = await createBookingEntryWorld();
    const d = w.eventDeps;
    await saveEventDraft(d, ph1, raw('ph1', { price: 150_000, venue: managed('s1') }));
    await publishEvent(d, ph1, { eventId: ID });
    await respondVenueConsent(d, org1, { eventId: ID, accept: true, venueFeePerGuest: fee });
    await publishEvent(d, ph1, { eventId: ID });
    return w;
  }
  const evOf = (w: BookingEntryWorld) => must(w.entry.store.events.get(ID));

  test('a paid registration of an event priced 150000 with venueFeePerGuest 20000 and quantity 3 creates a group of 450000: event_ticket line 390000 to the host and venue_fee line 60000 to org1 (payeeKind organizer), both released at event completed', async () => {
    const w = await feeEvent(20_000);
    const r = await registerEvent(w.eventDeps, cu1, { eventId: ID, quantity: 3, name: 'An', method: 'bank_qr' });
    const group = must(paymentOf(w, must(r.paymentId)));
    assert.deepEqual([group.subjectType, group.amount, group.status], ['payment_group', 450_000, 'created']);
    assert.ok(r.instructions !== null);
    const lines = childrenOf(w, group.id).map((c) => [c.lineKind, c.amount, c.payeeId, c.payeeKind ?? null, c.status]);
    assert.deepEqual(lines.sort(), [
      ['event_ticket', 390_000, 'ph1', null, 'awaiting_group'],
      ['venue_fee', 60_000, 'org1', 'organizer', 'awaiting_group'],
    ]);
    const reg = must(w.entry.store.registrations.get(`${ID}/${r.registrationId}`));
    const ticketLine = childrenOf(w, group.id).find((c) => c.lineKind === 'event_ticket');
    assert.equal(reg.paymentId, ticketLine?.id);
    assert.deepEqual(must(w.booking.store.paymentGroups.get(group.id) ?? w.entry.store.paymentGroups.get(group.id)).total, 450_000);

    assert.equal((await send(w, transfer(w, must(group.transferCode), 450_000))).outcome, 'paid');
    const paid = must(w.entry.store.registrations.get(`${ID}/${r.registrationId}`));
    assert.equal(paid.status, 'paid');
    assert.match(paid.ticketCode, /^VE-/);
    assert.deepEqual(childrenOf(w, group.id).map((c) => [c.status, c.escrowStatus]), [['paid', 'held'], ['paid', 'held']]);
    // Decision 7: a normal-event ticket keeps its public code; the group gets no pass.
    assert.equal(w.entry.store.passes.size + w.booking.store.passes.size, 0);
    assert.equal(evOf(w).registeredCount, 3);

    w.booking.clock.setTime(new Date(Date.parse(END) + 1000));
    assert.equal((await runEventSweeps(w.eventDeps)).completed, 1);
    const release = new Date(Date.parse(END) + 24 * HOUR).toISOString();
    assert.deepEqual(childrenOf(w, group.id).map((c) => c.releaseAfter), [release, release]);
  });

  test('a fee-event ticket refunded by the customer refunds both lines', async () => {
    const w = await feeEvent(20_000);
    const r = await registerEvent(w.eventDeps, cu1, { eventId: ID, quantity: 1, name: 'An', method: 'bank_qr' });
    const group = must(paymentOf(w, must(r.paymentId)));
    await send(w, transfer(w, must(group.transferCode), 150_000));
    const out = await cancelRegistration(w.eventDeps, cu1, { eventId: ID, registrationId: r.registrationId });
    assert.equal(out.status, 'refunded');
    const refunded = childrenOf(w, group.id).map((c) => [c.lineKind, c.escrowStatus, c.refundedAmount ?? 0]).sort();
    assert.deepEqual(refunded, [['event_ticket', 'refunded', 130_000], ['venue_fee', 'refunded', 20_000]]);
  });

  test('checkTicketPayment of a fee ticket polls its group and settles a transfer the gateway reports', async () => {
    const w = await feeEvent(20_000);
    const r = await registerEvent(w.eventDeps, cu1, { eventId: ID, quantity: 1, name: 'An', method: 'bank_qr' });
    const group = must(paymentOf(w, must(r.paymentId)));
    const deps = { ...w.eventDeps, settlement: w.settlement };
    const ask = { eventId: ID, registrationId: r.registrationId };
    assert.deepEqual(await checkTicketPayment(deps, cu1, ask), { paid: false, status: 'held' });
    w.booking.gateway.pushTransfer(group.id, transfer(w, must(group.transferCode), 150_000));
    assert.deepEqual(await checkTicketPayment(deps, cu1, ask), { paid: true, status: 'paid' });
    assert.deepEqual(childrenOf(w, group.id).map((c) => c.status), ['paid', 'paid']);
  });

  test('an event with fee 0 creates no group', async () => {
    const w = await feeEvent(0);
    const r = await registerEvent(w.eventDeps, cu1, { eventId: ID, quantity: 2, name: 'An', method: 'bank_qr' });
    const p = must(paymentOf(w, must(r.paymentId)));
    assert.deepEqual([p.subjectType, p.amount, p.payeeId, p.groupId ?? null], ['event_registration', 300_000, 'ph1', null]);
    assert.equal(childrenOf(w, p.id).length, 0);
  });
});
