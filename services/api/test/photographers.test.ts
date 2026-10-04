import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { bearer, resetDb, testApp, testDb } from './helpers.js';

type Method = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

const db = testDb();
let app: FastifyInstance;
beforeAll(async () => {
  app = await testApp({ db });
});
afterAll(async () => {
  await app.close();
  await db.destroy();
});

const OWNER = 'p_owner';
const OTHER = 'u_other';
const SETUP = {
  area: { city: 'Hà Nội', radiusKm: 20 },
  channels: { call: true, zalo: true, whatsapp: false, acceptInquiries: true },
  numbers: { phone: '+84903123456', zaloPhone: '+84912345678' },
};

type Actor = 'anon' | 'owner' | 'other';
const headersFor = async (a: Actor): Promise<Record<string, string>> =>
  a === 'anon' ? {} : bearer(a === 'owner' ? OWNER : OTHER);
async function call(actor: Actor, method: Method, url: string, payload?: object) {
  return app.inject({ method, url, headers: await headersFor(actor), ...(payload ? { payload } : {}) });
}
const base = `/v1/photographers/${OWNER}`;

async function photographer(uid: string): Promise<void> {
  await app.inject({ method: 'POST', url: '/v1/me', headers: await bearer(uid), payload: { displayName: uid } });
  await app.inject({ method: 'PUT', url: `/v1/users/${uid}/role`, headers: await bearer(uid), payload: { role: 'photographer' } });
}

beforeEach(async () => {
  await resetDb(db);
  await photographer(OWNER);
  await app.inject({ method: 'POST', url: '/v1/me', headers: await bearer(OTHER), payload: { displayName: OTHER } });
  await call('owner', 'PUT', `${base}/contact-setup`, SETUP);
});

const MATRIX: Array<{ op: string; method: Method; url: string; payload?: object; expect: Record<Actor, number> }> = [
  { op: 'getContactChannels', method: 'GET', url: `${base}/contact-channels`, expect: { anon: 401, owner: 200, other: 200 } },
  { op: 'getContactNumbers', method: 'GET', url: `${base}/contact-numbers`, expect: { anon: 401, owner: 200, other: 403 } },
  { op: 'getServiceArea', method: 'GET', url: `${base}/service-area`, expect: { anon: 401, owner: 200, other: 200 } },
  { op: 'completeContactSetup', method: 'PUT', url: `${base}/contact-setup`, payload: SETUP, expect: { anon: 401, owner: 204, other: 403 } },
];

describe('authorization matrix (README §4: channels U / S, numbers S / S, photographers U if onboarded)', () => {
  for (const row of MATRIX) {
    for (const actor of ['anon', 'owner', 'other'] as const) {
      it(`${row.op} as ${actor} → ${row.expect[actor]}`, async () => {
        expect((await call(actor, row.method, row.url, row.payload)).statusCode).toBe(row.expect[actor]);
      });
    }
  }
});

describe('contact setup (S34)', () => {
  it('stores area, flags and numbers and completes onboarding', async () => {
    expect((await call('other', 'GET', `${base}/contact-channels`)).json()).toEqual(SETUP.channels);
    expect((await call('owner', 'GET', `${base}/contact-numbers`)).json()).toEqual({ phone: '+84903123456', zaloPhone: '+84912345678', whatsappPhone: null });
    expect((await call('other', 'GET', `${base}/service-area`)).json()).toEqual(SETUP.area);
    const row = await db.selectFrom('photographers').select(['onboarding_complete', 'accepts_inquiries']).where('user_id', '=', OWNER).executeTakeFirstOrThrow();
    expect(row).toEqual({ onboarding_complete: true, accepts_inquiries: true });
  });

  it('public flags carry no number', async () => {
    const res = await call('other', 'GET', `${base}/contact-channels`);
    expect(res.body).not.toMatch(/phone|\+?84\d{9}/i);
  });

  it('saving again without an own Zalo number clears it', async () => {
    await call('owner', 'PUT', `${base}/contact-setup`, { ...SETUP, numbers: { phone: '+84903123456' } });
    expect((await call('owner', 'GET', `${base}/contact-numbers`)).json().zaloPhone).toBeNull();
  });

  it('only photographers can set contact channels', async () => {
    const res = await call('other', 'PUT', `/v1/photographers/${OTHER}/contact-setup`, SETUP);
    expect(res.statusCode).toBe(403);
    expect(res.json().code).toBe('permission_denied');
    const none = await app.inject({ method: 'PUT', url: '/v1/photographers/p_new/contact-setup', headers: await bearer('p_new'), payload: SETUP });
    expect(none.statusCode).toBe(404);
  });

  it('the contract rejects a foreign Zalo number, a malformed WhatsApp number, a bad radius or city', async () => {
    const bad = [
      { ...SETUP, numbers: { phone: '+84903123456', zaloPhone: '+14155552671' } },
      { ...SETUP, numbers: { phone: '+84903123456', whatsappPhone: '14155552671' } },
      { ...SETUP, area: { city: 'Hà Nội', radiusKm: 0 } },
      { ...SETUP, area: { city: 'H', radiusKm: 20 } },
      { ...SETUP, channels: { ...SETUP.channels, sms: true } },
    ];
    for (const payload of bad) expect((await call('owner', 'PUT', `${base}/contact-setup`, payload)).statusCode).toBe(400);
  });

  it('before setup everything is not_found', async () => {
    await photographer('p_fresh');
    const h = await bearer('p_fresh');
    for (const path of ['contact-channels', 'contact-numbers', 'service-area']) {
      const res = await app.inject({ method: 'GET', url: `/v1/photographers/p_fresh/${path}`, headers: h });
      expect(res.statusCode, path).toBe(404);
    }
  });

  it('an unfinished profile hides its area from others but not from its owner', async () => {
    await db.updateTable('photographers').set({ onboarding_complete: false }).where('user_id', '=', OWNER).execute();
    expect((await call('owner', 'GET', `${base}/service-area`)).statusCode).toBe(200);
    expect((await call('other', 'GET', `${base}/service-area`)).statusCode).toBe(404);
  });

  it('numbers are not cacheable', async () => {
    expect((await call('owner', 'GET', `${base}/contact-numbers`)).headers['cache-control']).toBe('no-store');
  });
});
