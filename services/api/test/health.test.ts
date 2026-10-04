import { afterAll, describe, expect, it } from 'vitest';

import { createDb } from '../src/db/database.js';
import { testApp, testDb } from './helpers.js';

const db = testDb();
afterAll(() => db.destroy());

describe('GET /v1/health', () => {
  it('is public and reports the database', async () => {
    const app = await testApp({ db });
    const res = await app.inject({ method: 'GET', url: '/v1/health' });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ status: 'ok', db: 'ok' });
    await app.close();
  });

  it('answers 503 when the database is unreachable', async () => {
    const down = createDb('postgres://nag:x@127.0.0.1:1/none_test', 1);
    const app = await testApp({ db: down });
    const res = await app.inject({ method: 'GET', url: '/v1/health' });
    expect(res.statusCode).toBe(503);
    expect(res.json()).toEqual({ status: 'degraded', db: 'down' });
    await app.close();
    await down.destroy();
  });
});
