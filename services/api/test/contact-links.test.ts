import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { contractWorld, seedContractWorld, type WorldBooking } from '../src/tools/contract-world.js';
import { decideContactLink, type ContactLinkRow } from '../src/use-cases/get-contact-link.js';
import { ApiError } from '../src/errors.js';
import { bearer, resetDb, testApp, testDb } from './helpers.js';

const NOW = new Date('2026-10-01T12:00:00Z');
const db = testDb();
let app: FastifyInstance;

beforeAll(async () => {
  app = await testApp({ db, clock: { now: () => NOW } });
  await resetDb(db);
  await seedContractWorld(db, NOW);
});
afterAll(async () => {
  await app.close();
  await db.destroy();
});

const CHANNELS = ['call', 'zalo', 'whatsapp'] as const;
type Channel = (typeof CHANNELS)[number];

const link = async (uid: string, payload: object) =>
  app.inject({ method: 'POST', url: '/v1/contact-links', headers: await bearer(uid), payload });

/** Independent oracle of plan 2b's URL shapes and domain-model.md §5. */
function expected(b: WorldBooking, channel: Channel): { status: number; code?: string; url?: string } {
  const p = contractWorld.photographers[b.photographerId]!;
  if (!b.unlocked) return { status: 403, code: 'contact_locked' };
  if (!p.channels[channel]) return { status: 404, code: 'not_found' };
  const n =
    channel === 'call' ? p.numbers.phone : channel === 'zalo' ? (p.numbers.zaloPhone ?? p.numbers.phone) : (p.numbers.whatsappPhone ?? p.numbers.phone);
  const url = channel === 'call' ? `tel:${n}` : channel === 'zalo' ? `https://zalo.me/${n.slice(1)}` : `https://wa.me/${n.slice(1)}`;
  return { status: 200, url };
}

describe('get_contact_link over the contract world', () => {
  for (const b of contractWorld.bookings) {
    for (const channel of CHANNELS) {
      const want = expected(b, channel);
      it(`${b.id} ${channel} → ${want.url ?? want.code}`, async () => {
        const res = await link(contractWorld.customer, { bookingId: b.id, channel });
        expect(res.statusCode).toBe(want.status);
        if (want.url) expect(res.json()).toEqual({ url: want.url });
        else expect(res.json().code).toBe(want.code);
      });
    }
  }
});

describe('who may ask, and what is refused', () => {
  it('another customer is refused', async () => {
    const res = await link(contractWorld.otherCustomer, { bookingId: 'ctr_b_accepted', channel: 'call' });
    expect(res.statusCode).toBe(403);
    expect(res.json().code).toBe('permission_denied');
  });

  it('the photographer cannot use the customer endpoint for its own booking', async () => {
    expect((await link('ctr_photographer', { bookingId: 'ctr_b_accepted', channel: 'call' })).json().code).toBe('permission_denied');
  });

  it('an unknown booking is not_found', async () => {
    expect((await link(contractWorld.customer, { bookingId: 'nope', channel: 'call' })).statusCode).toBe(404);
  });

  it('a registration is not served yet (events plan)', async () => {
    expect((await link(contractWorld.customer, { registrationId: 'r1', channel: 'call' })).json().code).toBe('not_found');
  });

  it('exactly one of bookingId and registrationId', async () => {
    expect((await link(contractWorld.customer, { bookingId: 'ctr_b_accepted', registrationId: 'r1', channel: 'call' })).statusCode).toBe(400);
    expect((await link(contractWorld.customer, { channel: 'call' })).statusCode).toBe(400);
  });

  it('the in-app channel has no link', async () => {
    expect((await link(contractWorld.customer, { bookingId: 'ctr_b_accepted', channel: 'in_app' })).statusCode).toBe(400);
  });

  it('needs a token', async () => {
    const res = await app.inject({ method: 'POST', url: '/v1/contact-links', payload: { bookingId: 'ctr_b_accepted', channel: 'call' } });
    expect(res.statusCode).toBe(401);
  });

  it('answers are not cacheable and a refusal never carries the number', async () => {
    const ok = await link(contractWorld.customer, { bookingId: 'ctr_b_accepted', channel: 'zalo' });
    expect(ok.headers['cache-control']).toBe('no-store');
    const locked = await link(contractWorld.customer, { bookingId: 'ctr_b_declined', channel: 'call' });
    expect(locked.body).not.toMatch(/\d{9}/);
  });
});

describe('contact_access_log', () => {
  beforeEach(async () => {
    await resetDb(db);
    await seedContractWorld(db, NOW);
  });

  it('logs every decision once, granted or not, without any number', async () => {
    await link(contractWorld.customer, { bookingId: 'ctr_b_accepted', channel: 'call' });
    await link(contractWorld.customer, { bookingId: 'ctr_b_declined', channel: 'zalo' });
    await link(contractWorld.customer, { bookingId: 'nope', channel: 'whatsapp' });
    const rows = await db
      .selectFrom('contact_access_log')
      .select(['requester_id', 'subject_type', 'subject_id', 'channel', 'granted', 'at'])
      .orderBy('id')
      .execute();
    expect(rows).toEqual([
      { requester_id: 'ctr_customer', subject_type: 'booking', subject_id: 'ctr_b_accepted', channel: 'call', granted: true, at: NOW },
      { requester_id: 'ctr_customer', subject_type: 'booking', subject_id: 'ctr_b_declined', channel: 'zalo', granted: false, at: NOW },
      { requester_id: 'ctr_customer', subject_type: 'booking', subject_id: 'nope', channel: 'whatsapp', granted: false, at: NOW },
    ]);
  });

  it('a caller without a profile is answered but not logged', async () => {
    expect((await link('ghost', { bookingId: 'ctr_b_accepted', channel: 'call' })).statusCode).toBe(403);
    expect(await db.selectFrom('contact_access_log').selectAll().execute()).toEqual([]);
  });

  it('seeding twice changes nothing', async () => {
    await seedContractWorld(db, NOW);
    const bookings = await db.selectFrom('bookings').select((eb) => eb.fn.countAll<number>().as('n')).executeTakeFirstOrThrow();
    const events = await db.selectFrom('booking_events').select((eb) => eb.fn.countAll<number>().as('n')).executeTakeFirstOrThrow();
    expect([bookings.n, events.n]).toEqual([9, 2]);
  });
});

describe('decideContactLink', () => {
  const row = (over: Partial<ContactLinkRow> = {}): ContactLinkRow => ({
    customer_id: 'c1', status: 'completed', completed_at: new Date(NOW.getTime() - 30 * 86_400_000),
    call_enabled: true, zalo_enabled: false, whatsapp_enabled: false,
    phone_e164: '+84903123456', zalo_phone_e164: null, whatsapp_phone_e164: null, ...over,
  });
  const code = (f: () => unknown) => {
    try {
      f();
    } catch (e) {
      return (e as ApiError).code;
    }
    return 'ok';
  };

  it('30 days after completion is still open, one second later is locked; off or missing number is not_found', () => {
    expect(decideContactLink(row(), 'c1', 'call', NOW)).toBe('tel:+84903123456');
    expect(code(() => decideContactLink(row({ completed_at: new Date(NOW.getTime() - 30 * 86_400_000 - 1000) }), 'c1', 'call', NOW))).toBe('contact_locked');
    expect(code(() => decideContactLink(row(), 'c1', 'zalo', NOW))).toBe('not_found');
    expect(code(() => decideContactLink(row({ phone_e164: null }), 'c1', 'call', NOW))).toBe('not_found');
    expect(code(() => decideContactLink(undefined, 'c1', 'call', NOW))).toBe('not_found');
    expect(code(() => decideContactLink(row(), 'c2', 'call', NOW))).toBe('permission_denied');
  });
});
