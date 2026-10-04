import type { FastifyInstance } from 'fastify';
import { sql, type Kysely } from 'kysely';

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

/** Empties every slice table (FK order handled by CASCADE). */
export async function resetDb(db: Kysely<Database>): Promise<void> {
  await sql`truncate table contact_access_log, booking_events, bookings, services,
    photographer_contact_numbers, photographer_contact_channels, photographers, taxonomy_items,
    auth_identities, user_contacts, users, files restart identity cascade`.execute(db);
}
