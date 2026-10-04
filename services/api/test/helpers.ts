import type { FastifyInstance } from 'fastify';
import type { Kysely } from 'kysely';

import { buildApp, type AppDeps } from '../src/app.js';
import { createDb, type Database } from '../src/db/database.js';

export function testDatabaseUrl(): string {
  const url = process.env.TEST_DATABASE_URL;
  if (!url) throw new Error('TEST_DATABASE_URL is set by test/global-setup.ts');
  return url;
}

export function testDb(): Kysely<Database> {
  return createDb(testDatabaseUrl(), 4);
}

export function testApp(deps: AppDeps): Promise<FastifyInstance> {
  return buildApp(deps);
}
