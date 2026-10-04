import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { bearer, resetDb, testApp, testDb } from './helpers.js';

const db = testDb();
let app: FastifyInstance;
beforeAll(async () => {
  app = await testApp({ db });
});
afterAll(async () => {
  await app.close();
  await db.destroy();
});
beforeEach(() => resetDb(db));

const post = async (uid: string, payload: object, o?: Parameters<typeof bearer>[1]) =>
  app.inject({ method: 'POST', url: '/v1/me', headers: await bearer(uid, o), payload });

describe('POST /v1/me (ensureProfile)', () => {
  it('creates the profile once (201) and never overwrites it (200)', async () => {
    const first = await post('u1', { displayName: 'Lan' });
    expect(first.statusCode).toBe(201);
    expect(first.json()).toEqual({ id: 'u1', displayName: 'Lan', role: null, avatarUrl: null });
    const again = await post('u1', { displayName: 'Someone else' });
    expect(again.statusCode).toBe(200);
    expect(again.json().displayName).toBe('Lan');
  });

  it('records the sign-in identity once; the email stays private', async () => {
    const o = { provider: 'google.com', identities: { 'google.com': ['1098765'] }, email: 'lan@example.com' };
    const res = await post('u1', { displayName: 'Lan' }, o);
    await post('u1', { displayName: 'Lan' }, o);
    expect(res.body).not.toContain('lan@example.com');
    const rows = await db.selectFrom('auth_identities').select(['user_id', 'provider', 'subject', 'email']).execute();
    expect(rows).toEqual([{ user_id: 'u1', provider: 'google', subject: '1098765', email: 'lan@example.com' }]);
  });

  it('keeps a social avatar as an external file and returns its URL', async () => {
    const url = 'https://lh3.googleusercontent.com/a/photo.jpg';
    const res = await post('u1', { displayName: 'Lan', avatarUrl: url });
    expect(res.json().avatarUrl).toBe(url);
    const file = await db.selectFrom('files').select(['storage_provider', 'storage_key', 'owner_user_id']).executeTakeFirstOrThrow();
    expect(file).toEqual({ storage_provider: 'external', storage_key: url, owner_user_id: 'u1' });
  });

  it('validates the body against the contract', async () => {
    expect((await post('u1', { displayName: '' })).statusCode).toBe(400);
    expect((await post('u1', { displayName: 'Lan', role: 'photographer' })).json().code).toBe('invalid_argument');
  });

  it('a deleted account cannot recreate itself', async () => {
    await post('u1', { displayName: 'Lan' });
    await db.updateTable('users').set({ deleted_at: new Date() }).where('id', '=', 'u1').execute();
    const res = await post('u1', { displayName: 'Lan' });
    expect(res.statusCode).toBe(403);
    expect(res.json().code).toBe('permission_denied');
  });
});
