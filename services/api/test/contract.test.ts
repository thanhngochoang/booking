import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { loadContract, operations, toFastifyUrl } from '../src/contract/openapi.js';
import { testApp, testDb } from './helpers.js';

/** Operations whose routes arrive in later tasks. Task 7 empties this set. */
const PENDING = new Set<string>([
  'getContactChannels', 'getContactNumbers', 'getServiceArea', 'completeContactSetup', 'getContactLink',
]);

const contract = loadContract();
const db = testDb();
let app: FastifyInstance;

beforeAll(async () => {
  app = await testApp({ db });
  await app.ready();
});
afterAll(async () => {
  await app.close();
  await db.destroy();
});

describe('API contract', () => {
  it('every contract operation is routed (or still pending)', () => {
    for (const op of operations(contract)) {
      const routed = app.hasRoute({ method: op.method, url: op.url });
      if (PENDING.has(op.operationId)) {
        expect(routed, `${op.operationId} is routed now: remove it from PENDING`).toBe(false);
      } else {
        expect(routed, `${op.operationId} ${op.method} ${op.path}`).toBe(true);
      }
    }
  });

  it('every /v1 route is in the contract', () => {
    const known = new Set(operations(contract).map((o) => `${o.method} ${o.url}`));
    for (const r of app.routeTable.filter((r) => r.url.startsWith('/v1/'))) {
      expect(known.has(`${r.method} ${r.url}`), `${r.method} ${r.url}`).toBe(true);
    }
  });

  it('property names are camelCase and phone fields live only in private schemas', () => {
    const PRIVATE = new Set(['UserContact', 'SaveUserContactRequest', 'ContactNumbers']);
    for (const [name, schema] of Object.entries(contract.components.schemas)) {
      const props = (schema as { properties?: Record<string, unknown> }).properties ?? {};
      for (const key of Object.keys(props)) {
        expect(key, `${name}.${key}`).toMatch(/^[a-z][A-Za-z0-9]*$/);
        if (/phone/i.test(key) && !/^allow/.test(key)) expect(PRIVATE.has(name), `${name}.${key}`).toBe(true);
      }
    }
  });

  it('path templates map to Fastify URLs', () => {
    expect(toFastifyUrl('/v1/users/{userId}/contact')).toBe('/v1/users/:userId/contact');
  });
});
