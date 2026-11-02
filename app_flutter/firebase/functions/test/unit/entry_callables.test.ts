import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { HttpsError } from 'firebase-functions/v2/https';
import { ORGANIZER_TERMS_VERSION, publishEvent, saveEventDraft } from '@photobooking/domain';
import { handleCloseEntryDay, handleRegisterEntry, handleRespondVenueConsent } from '../../src/callables/entry.js';

const ew = await import('../../../../../packages/domain/test/support/entry_world.js');
const evw = await import('../../../../../packages/domain/test/support/event_world.js');

const as = (uid: string, data: unknown) => ({ auth: { uid }, data });
const buyRaw = (qty: number, visitDay: string = ew.VISIT) =>
  ({ eventId: ew.ENTRY_ID, visitDay, items: [{ ticketTypeId: 'adult', qty }], name: 'Nguyễn An', method: 'bank_qr' });

async function refused(p: Promise<unknown>, transport: string, code: string): Promise<void> {
  await assert.rejects(p, (e: unknown) => {
    assert.ok(e instanceof HttpsError, String(e));
    assert.equal(e.code, transport);
    assert.equal((e.details as { code?: string }).code, code);
    return true;
  });
}

async function entry() {
  const w = ew.createEntryWorld();
  await ew.publishedEntry(w);
  return { w, deps: { ...w.deps, notify: w.notify.deps } };
}

describe('entry callables', () => {
  it('every handler is unauthenticated without auth', async () => {
    const { deps } = await entry();
    for (const handle of [handleRegisterEntry, handleCloseEntryDay, handleRespondVenueConsent] as const) {
      await assert.rejects(handle({ data: {} }, deps), (e: unknown) => e instanceof HttpsError && e.code === 'unauthenticated');
    }
  });

  it('registerEntry holds the caller\'s tickets and answers like registerEvent', async () => {
    const { w, deps } = await entry();
    const out = await handleRegisterEntry(as('cu1', buyRaw(2)), deps);
    assert.equal(out.status, 'held');
    assert.equal(typeof out.holdExpiresAt, 'string');
    assert.ok(out.paymentId);
    assert.ok(out.instructions);
    assert.equal(w.store.registrations.get(`${ew.ENTRY_ID}/${out.registrationId}`)?.userId, 'cu1');
  });

  it('registerEntry maps sold_out_day, day_closed and limit_exceeded', async () => {
    const { deps } = await entry();
    await handleRegisterEntry(as('cu1', buyRaw(9)), deps);
    await refused(handleRegisterEntry(as('cu2', buyRaw(2)), deps), 'resource-exhausted', 'sold_out_day');
    await refused(handleRegisterEntry(as('cu2', buyRaw(1, '2026-10-25')), deps), 'failed-precondition', 'day_closed');
    await refused(handleRegisterEntry(as('cu3', buyRaw(11)), deps), 'resource-exhausted', 'limit_exceeded');
  });

  it('closeEntryDay by the organizer refunds the day; anyone else is refused', async () => {
    const { w, deps } = await entry();
    await ew.bought(w, evw.cu1);
    await refused(handleCloseEntryDay(as('org2', { eventId: ew.ENTRY_ID, day: ew.VISIT }), deps), 'permission-denied', 'permission_denied');
    const out = await handleCloseEntryDay(as('org1', { eventId: ew.ENTRY_ID, day: ew.VISIT }), deps);
    assert.deepEqual(out, { refunded: 1, left: 0 });
    assert.equal(w.store.entryDays.get(`${ew.ENTRY_ID}_${ew.VISIT}`)?.closed, true);
  });

  it('respondVenueConsent: the spot manager accepts; not_spot_manager for anyone else', async () => {
    const { w, deps } = await entry();
    const at = new Date('2026-10-20T03:00:00.000Z');
    w.clock.set(at);
    w.notify.clock.setTime(at);
    const id = 'ev1_aaaaaaaaaaaaaaaaaaaa';
    await saveEventDraft(w.deps, evw.ph1, evw.rawEvent(id, 'ph1', {
      startAt: '2026-10-24T02:00:00.000Z', endAt: '2026-10-24T05:00:00.000Z',
      venue: { kind: 'managed_spot', spotId: 's1', termsVersion: ORGANIZER_TERMS_VERSION },
    }));
    await publishEvent(deps, evw.ph1, { eventId: id });
    assert.equal(w.store.events.get(id)?.venueConsent, 'pending');
    await refused(handleRespondVenueConsent(as('org2', { eventId: id, accept: true }), deps), 'failed-precondition', 'not_spot_manager');
    assert.deepEqual(await handleRespondVenueConsent(as('org1', { eventId: id, accept: true, venueFeePerGuest: 0 }), deps), {});
    assert.equal(w.store.events.get(id)?.venueConsent, 'accepted');
    await refused(handleRespondVenueConsent(as('org1', { eventId: id, accept: false }), deps), 'aborted', 'conflict');
  });
});
