import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { HttpsError } from 'firebase-functions/v2/https';
import type { BookingRecord, ContactAccessLogEntry, GetContactLinkDeps } from '@photobooking/domain';
import { handleGetContactLink } from '../../src/callables/get_contact_link.js';

const accepted: BookingRecord = { id: 'b1', customerId: 'c1', photographerId: 'p1', status: 'accepted', completedAt: null };

function fakes(bookings: BookingRecord[]): { deps: GetContactLinkDeps; logs: ContactAccessLogEntry[] } {
  const logs: ContactAccessLogEntry[] = [];
  const deps: GetContactLinkDeps = {
    bookings: { get: async (id) => bookings.find((b) => b.id === id) ?? null },
    photographers: {
      read: async () => ({ channels: { call: true, zalo: true, whatsapp: false }, numbers: { phone: '+84912000001' } }),
    },
    log: { append: async (e) => { logs.push(e); } },
    clock: { now: () => new Date('2026-10-01T12:00:00Z') },
    ids: { newId: () => 'log-1' },
  };
  return { deps, logs };
}

const httpsError = (code: string, detailsCode?: string) => (e: unknown) =>
  e instanceof HttpsError
  && e.code === code
  && (detailsCode === undefined || (e.details as { code?: string }).code === detailsCode);

describe('handleGetContactLink', () => {
  test('a signed-in customer gets { url } and nothing else', async () => {
    const { deps } = fakes([accepted]);
    const result = await handleGetContactLink({ auth: { uid: 'c1' }, data: { bookingId: 'b1', channel: 'call' } }, deps);
    assert.deepEqual(result, { url: 'tel:+84912000001' });
    assert.deepEqual(Object.keys(result), ['url']);
  });

  test('no auth is unauthenticated with details.code permission_denied, and nothing is logged', async () => {
    const { deps, logs } = fakes([accepted]);
    await assert.rejects(
      handleGetContactLink({ data: { bookingId: 'b1', channel: 'call' } }, deps),
      httpsError('unauthenticated', 'permission_denied'),
    );
    assert.equal(logs.length, 0);
  });

  test('contact_locked reaches the client exactly as the contract says', async () => {
    const { deps } = fakes([{ ...accepted, status: 'cancelled' }]);
    await assert.rejects(
      handleGetContactLink({ auth: { uid: 'c1' }, data: { bookingId: 'b1', channel: 'call' } }, deps),
      (e: unknown) => httpsError('failed-precondition', 'contact_locked')(e) && (e as HttpsError).message === 'contact_locked',
    );
  });

  test('a switched-off channel is not-found', async () => {
    const { deps } = fakes([accepted]);
    await assert.rejects(
      handleGetContactLink({ auth: { uid: 'c1' }, data: { bookingId: 'b1', channel: 'whatsapp' } }, deps),
      httpsError('not-found', 'not_found'),
    );
  });
});
