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

const OWNER = 'u_owner';
const OTHER = 'u_other';
const CONTACT = { phone: '+84903123456', allowZalo: true, allowWhatsApp: false };

type Actor = 'anon' | 'owner' | 'other';
const headersFor = async (a: Actor): Promise<Record<string, string>> =>
  a === 'anon' ? {} : bearer(a === 'owner' ? OWNER : OTHER);

async function call(actor: Actor, method: Method, url: string, payload?: object) {
  return app.inject({ method, url, headers: await headersFor(actor), ...(payload ? { payload } : {}) });
}

beforeEach(async () => {
  await resetDb(db);
  for (const uid of [OWNER, OTHER]) {
    await app.inject({ method: 'POST', url: '/v1/me', headers: await bearer(uid), payload: { displayName: uid } });
  }
  await call('owner', 'PUT', `/v1/users/${OWNER}/contact`, CONTACT);
});

const MATRIX: Array<{ op: string; method: Method; url: string; payload?: object; expect: Record<Actor, number> }> = [
  { op: 'getUser', method: 'GET', url: `/v1/users/${OWNER}`, expect: { anon: 401, owner: 200, other: 200 } },
  { op: 'updateUser', method: 'PATCH', url: `/v1/users/${OWNER}`, payload: { displayName: 'Minh' }, expect: { anon: 401, owner: 200, other: 403 } },
  { op: 'setRole', method: 'PUT', url: `/v1/users/${OWNER}/role`, payload: { role: 'customer' }, expect: { anon: 401, owner: 200, other: 403 } },
  { op: 'getUserContact', method: 'GET', url: `/v1/users/${OWNER}/contact`, expect: { anon: 401, owner: 200, other: 403 } },
  { op: 'saveUserContact', method: 'PUT', url: `/v1/users/${OWNER}/contact`, payload: CONTACT, expect: { anon: 401, owner: 200, other: 403 } },
];

describe('authorization matrix (data-model README §4: users U read / S write, user_contacts S / S)', () => {
  for (const row of MATRIX) {
    for (const actor of ['anon', 'owner', 'other'] as const) {
      it(`${row.op} as ${actor} → ${row.expect[actor]}`, async () => {
        const res = await call(actor, row.method, row.url, row.payload);
        expect(res.statusCode).toBe(row.expect[actor]);
      });
    }
  }
});

describe('profile and contact behaviour', () => {
  it('the public profile never carries a phone number', async () => {
    const res = await call('other', 'GET', `/v1/users/${OWNER}`);
    expect(res.json()).toEqual({ id: OWNER, displayName: OWNER, role: null, avatarUrl: null });
    expect(res.body).not.toMatch(/phone|\+?84\d{9}/i);
  });

  it('a changed number becomes unverified; a toggle keeps verification', async () => {
    await db.updateTable('user_contacts').set({ phone_verified: true }).where('user_id', '=', OWNER).execute();
    const toggle = await call('owner', 'PUT', `/v1/users/${OWNER}/contact`, { ...CONTACT, allowWhatsApp: true });
    expect(toggle.json()).toMatchObject({ phone: '+84903123456', phoneVerified: true, allowWhatsApp: true });
    const changed = await call('owner', 'PUT', `/v1/users/${OWNER}/contact`, { ...CONTACT, phone: '+84912345678' });
    expect(changed.json()).toMatchObject({ phone: '+84912345678', phoneVerified: false });
    expect(Date.parse(changed.json().updatedAt)).not.toBeNaN();
  });

  it('only Vietnamese E.164 numbers are accepted', async () => {
    for (const phone of ['0903123456', '+8490312345', '+84123456789', '+14155552671']) {
      const res = await call('owner', 'PUT', `/v1/users/${OWNER}/contact`, { ...CONTACT, phone });
      expect(res.statusCode, phone).toBe(400);
    }
  });

  it('a client cannot set phoneVerified or staffRole', async () => {
    expect((await call('owner', 'PUT', `/v1/users/${OWNER}/contact`, { ...CONTACT, phoneVerified: true })).statusCode).toBe(400);
    expect((await call('owner', 'PATCH', `/v1/users/${OWNER}`, { displayName: 'Minh', staffRole: 'admin' })).statusCode).toBe(400);
  });

  it('a user without a profile row gets not_found for its contact', async () => {
    const res = await app.inject({ method: 'PUT', url: '/v1/users/u_new/contact', headers: await bearer('u_new'), payload: CONTACT });
    expect(res.statusCode).toBe(404);
    expect(res.json().code).toBe('not_found');
    const get = await app.inject({ method: 'GET', url: '/v1/users/u_new/contact', headers: await bearer('u_new') });
    expect(get.statusCode).toBe(404);
  });

  it('setRole(photographer) creates the photographer row once and keeps its progress', async () => {
    const res = await call('owner', 'PUT', `/v1/users/${OWNER}/role`, { role: 'photographer' });
    expect(res.json().role).toBe('photographer');
    await db.updateTable('photographers').set({ onboarding_complete: true }).where('user_id', '=', OWNER).execute();
    await call('owner', 'PUT', `/v1/users/${OWNER}/role`, { role: 'customer' });
    await call('owner', 'PUT', `/v1/users/${OWNER}/role`, { role: 'photographer' });
    const row = await db.selectFrom('photographers').select('onboarding_complete').where('user_id', '=', OWNER).executeTakeFirstOrThrow();
    expect(row.onboarding_complete).toBe(true);
  });

  it('private contact responses are not cacheable', async () => {
    const res = await call('owner', 'GET', `/v1/users/${OWNER}/contact`);
    expect(res.headers['cache-control']).toBe('no-store');
  });

  it('an unknown user is not_found', async () => {
    const res = await call('owner', 'GET', '/v1/users/nobody');
    expect(res.statusCode).toBe(404);
  });
});
