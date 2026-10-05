import type { FastifyInstance } from 'fastify';
import { generateKeyPair } from 'jose';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { authProviderCode, claimsToPrincipal, EmulatorVerifier } from '../src/auth/identity.js';
import { ApiError } from '../src/errors.js';
import { bearer, emulatorToken, PROJECT_ID, testApp, testDb, tokenFor } from './helpers.js';

const db = testDb();
let app: FastifyInstance;
beforeAll(async () => {
  app = await testApp({ db });
});
afterAll(async () => {
  await app.close();
  await db.destroy();
});

const me = (headers: Record<string, string>) =>
  app.inject({ method: 'POST', url: '/v1/me', headers, payload: { displayName: 'Lan' } });

describe('bearer tokens on /v1/*', () => {
  it('no token → 401 with the error envelope', async () => {
    const res = await me({});
    expect(res.statusCode).toBe(401);
    expect(res.json()).toMatchObject({ code: 'unauthenticated', requestId: expect.any(String) });
  });

  it('a token signed by another key → 401', async () => {
    const other = await generateKeyPair('RS256');
    expect((await me(await bearer('u1', { key: other.privateKey }))).statusCode).toBe(401);
  });

  it('wrong audience, wrong issuer or expired → 401', async () => {
    expect((await me(await bearer('u1', { audience: 'other-project' }))).statusCode).toBe(401);
    expect((await me(await bearer('u1', { issuer: 'https://evil.example' }))).statusCode).toBe(401);
    expect((await me(await bearer('u1', { exp: Math.floor(Date.now() / 1000) - 60 }))).statusCode).toBe(401);
  });

  it('a subject that is not a valid id → 401', async () => {
    expect((await me(await bearer('bad/uid'))).statusCode).toBe(401);
  });

  it('health stays public', async () => {
    expect((await app.inject({ method: 'GET', url: '/v1/health' })).statusCode).toBe(200);
  });
});

describe('EmulatorVerifier', () => {
  const v = new EmulatorVerifier({ projectId: PROJECT_ID });

  it('accepts the emulator\'s unsigned token for its project', async () => {
    expect((await v.verify(emulatorToken('u1'))).uid).toBe('u1');
  });

  it('refuses signed tokens, other projects and expired tokens', async () => {
    await expect(v.verify(await tokenFor('u1'))).rejects.toBeInstanceOf(ApiError);
    await expect(v.verify(emulatorToken('u1', { projectId: 'other' }))).rejects.toBeInstanceOf(ApiError);
    await expect(v.verify(emulatorToken('u1', { exp: Math.floor(Date.now() / 1000) - 1 }))).rejects.toBeInstanceOf(ApiError);
    await expect(v.verify('not-a-jwt')).rejects.toBeInstanceOf(ApiError);
  });
});

describe('claims', () => {
  it('a social sign-in keeps the provider\'s own subject; password keeps the uid', () => {
    const google = claimsToPrincipal({
      sub: 'u1', email: 'lan@example.com',
      firebase: { sign_in_provider: 'google.com', identities: { 'google.com': ['1098765'] } },
    });
    expect(google).toEqual({ uid: 'u1', signInProvider: 'google.com', providerSubject: '1098765', email: 'lan@example.com' });
    const pw = claimsToPrincipal({ sub: 'u2', firebase: { sign_in_provider: 'password', identities: { email: ['a@b.vn'] } } });
    expect(pw.providerSubject).toBe('u2');
  });

  it('maps Firebase provider ids to AuthProvider codes', () => {
    expect(authProviderCode('google.com')).toBe('google');
    expect(authProviderCode('facebook.com')).toBe('facebook');
    expect(authProviderCode('apple.com')).toBe('apple');
    expect(authProviderCode('password')).toBe('password');
    expect(authProviderCode('oidc.keycloak')).toBe('oidc');
  });
});
