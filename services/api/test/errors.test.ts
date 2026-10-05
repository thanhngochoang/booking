import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { API_ERROR_CODES, ApiError, HTTP_STATUS } from '../src/errors.js';
import { ID_PATTERN, isValidId, newId } from '../src/ids.js';
import { iso } from '../src/wire.js';
import { testApp, testDb } from './helpers.js';

const db = testDb();
let app: FastifyInstance;

beforeAll(async () => {
  app = await testApp({ db });
  app.get('/test/locked', { config: { public: true } }, async () => {
    throw new ApiError('contact_locked', 'contact opens once the booking is paid');
  });
  app.get('/test/crash', { config: { public: true } }, async () => {
    throw new Error('db said: +84903123456 secret');
  });
  app.post('/test/contact', { config: { public: true }, schema: { body: { $ref: 'SaveUserContactRequest#' } } }, async () => ({ ok: true }));
  await app.ready();
});
afterAll(async () => {
  await app.close();
  await db.destroy();
});

describe('error envelope', () => {
  it('every code has an HTTP status', () => {
    for (const code of API_ERROR_CODES) expect(HTTP_STATUS[code], code).toBeGreaterThanOrEqual(400);
    expect(HTTP_STATUS.contact_locked).toBe(403);
    expect(HTTP_STATUS.unauthenticated).toBe(401);
  });

  it('an ApiError becomes {code, message, requestId}', async () => {
    const res = await app.inject({ method: 'GET', url: '/test/locked' });
    expect(res.statusCode).toBe(403);
    expect(res.json()).toEqual({ code: 'contact_locked', message: 'contact opens once the booking is paid', requestId: expect.any(String) });
  });

  it('a body that breaks the contract is invalid_argument, extra fields included', async () => {
    const bad = await app.inject({ method: 'POST', url: '/test/contact', payload: { phone: '0903123456', allowZalo: true, allowWhatsApp: false } });
    expect(bad.statusCode).toBe(400);
    expect(bad.json().code).toBe('invalid_argument');
    const extra = await app.inject({ method: 'POST', url: '/test/contact', payload: { phone: '+84903123456', allowZalo: true, allowWhatsApp: false, phoneVerified: true } });
    expect(extra.statusCode).toBe(400);
    const ok = await app.inject({ method: 'POST', url: '/test/contact', payload: { phone: '+84903123456', allowZalo: true, allowWhatsApp: false } });
    expect(ok.statusCode).toBe(200);
  });

  it('an unknown route is not_found', async () => {
    const res = await app.inject({ method: 'GET', url: '/v1/nope' });
    expect(res.statusCode).toBe(404);
    expect(res.json().code).toBe('not_found');
  });

  it('an unexpected error is internal and leaks nothing', async () => {
    const res = await app.inject({ method: 'GET', url: '/test/crash' });
    expect(res.statusCode).toBe(500);
    expect(res.json()).toEqual({ code: 'internal', message: 'internal error', requestId: expect.any(String) });
    expect(res.body).not.toContain('84903123456');
  });
});

describe('ids and instants', () => {
  it('new ids are 26-character ULIDs, time ordered, valid ids', () => {
    const a = newId(1_000);
    const b = newId(2_000);
    expect(a).toHaveLength(26);
    expect(a < b).toBe(true);
    expect(ID_PATTERN.test(a)).toBe(true);
    expect(isValidId('Xg7sD9kPq2NfwT4LmR8vYc1BzA03')).toBe(true); // a Firebase uid
    expect(isValidId('a/b')).toBe(false);
    expect(isValidId('x'.repeat(65))).toBe(false);
  });

  it('instants go on the wire as ISO-8601 UTC', () => {
    expect(iso(new Date(Date.UTC(2026, 9, 12, 8, 30)))).toBe('2026-10-12T08:30:00.000Z');
  });
});
