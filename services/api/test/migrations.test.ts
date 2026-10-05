import pg from 'pg';
import { sql } from 'kysely';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import type { BookingStatus } from '../src/db/database.js';
import { migrate } from '../src/db/migrate.js';
import { resetDb, testDatabaseUrl, testDb } from './helpers.js';

/** relational-schema.md §2, slice tables, columns in DDL order. */
const EXPECTED: Record<string, string[]> = {
  auth_identities: ['id', 'user_id', 'provider', 'subject', 'email', 'created_at'],
  booking_events: ['id', 'booking_id', 'status', 'actor_id', 'at'],
  bookings: [
    'id', 'customer_id', 'photographer_id', 'service_id', 'service_name', 'service_price',
    'service_duration_minutes', 'day', 'start_time', 'end_time', 'place_name', 'place_lat', 'place_lng',
    'note', 'status', 'deposit_amount', 'remaining_amount', 'currency', 'deposit_provider',
    'deposit_paid_at', 'deposit_refunded_at', 'accept_deadline', 'cancelled_by', 'cancel_reason',
    'cancelled_at', 'cancel_refund_percent', 'chat_id', 'version', 'created_at', 'updated_at',
  ],
  contact_access_log: ['id', 'requester_id', 'subject_type', 'subject_id', 'channel', 'granted', 'at'],
  files: [
    'id', 'owner_user_id', 'storage_provider', 'storage_key', 'mime_type', 'size_bytes', 'width', 'height',
    'blurhash', 'created_at',
  ],
  photographer_contact_channels: ['photographer_id', 'call_enabled', 'zalo_enabled', 'whatsapp_enabled'],
  photographer_contact_numbers: ['photographer_id', 'phone_e164', 'zalo_phone_e164', 'whatsapp_phone_e164'],
  photographers: [
    'user_id', 'bio', 'years_experience', 'service_city', 'service_lat', 'service_lng', 'service_radius_km',
    'cover_file_id', 'verified', 'verified_at', 'onboarding_complete', 'accepts_inquiries', 'rating_avg',
    'review_count', 'completed_count', 'response_minutes_median', 'starting_price', 'next_free_date',
    'skills_completeness', 'created_at', 'updated_at', 'provider_type', 'artist_since', 'studio_district',
    'studio_city', 'approved_award_count',
  ],
  services: [
    'id', 'photographer_id', 'name', 'specialty_id', 'duration_minutes', 'price', 'currency', 'photo_count',
    'edited_count', 'delivery_days', 'cover_file_id', 'active', 'created_at', 'updated_at',
  ],
  studio_addresses: ['photographer_id', 'line', 'ward', 'district', 'city', 'lat', 'lng', 'updated_at'],
  taxonomy_items: ['id', 'grp', 'label_vi', 'parent_id', 'sort_order', 'active'],
  user_contacts: ['user_id', 'phone_e164', 'phone_verified', 'allow_zalo', 'allow_whatsapp', 'updated_at'],
  users: [
    'id', 'display_name', 'avatar_file_id', 'role', 'staff_role', 'city', 'locale', 'created_at', 'updated_at',
    'deleted_at',
  ],
};

async function withClient<T>(url: string, f: (c: pg.Client) => Promise<T>): Promise<T> {
  const c = new pg.Client({ connectionString: url });
  await c.connect();
  try {
    return await f(c);
  } finally {
    await c.end();
  }
}

async function columns(url: string): Promise<Record<string, string[]>> {
  return withClient(url, async (c) => {
    const r = await c.query<{ table_name: string; column_name: string }>(
      `select table_name, column_name from information_schema.columns
        where table_schema = 'public' and table_name <> 'pgmigrations'
        order by table_name, ordinal_position`,
    );
    const out: Record<string, string[]> = {};
    for (const row of r.rows) (out[row.table_name] ??= []).push(row.column_name);
    return out;
  });
}

describe('migrations', () => {
  const name = `mig_${Date.now()}_test`;
  const scratch = (() => {
    const u = new URL(testDatabaseUrl());
    u.pathname = `/${name}`;
    return u.toString();
  })();

  beforeAll(() => withClient(testDatabaseUrl(), (c) => c.query(`create database ${name}`)));
  afterAll(() => withClient(testDatabaseUrl(), (c) => c.query(`drop database if exists ${name} with (force)`)));

  it('apply all: the slice tables match relational-schema.md column for column', async () => {
    await migrate(scratch, 'up');
    expect(await columns(scratch)).toEqual(EXPECTED);
  });

  it('indexes of relational-schema.md exist', async () => {
    const names = await withClient(scratch, async (c) =>
      (await c.query<{ indexname: string }>(`select indexname from pg_indexes where schemaname = 'public'`)).rows.map(
        (r) => r.indexname,
      ),
    );
    expect(names).toEqual(
      expect.arrayContaining([
        'ix_taxonomy_items_grp',
        'ix_services_photographer',
        'ix_bookings_customer',
        'ix_bookings_photographer',
        'ux_bookings_active_day',
        'ix_booking_events_booking',
      ]),
    );
  });

  it('rolls back completely, then applies again', async () => {
    await migrate(scratch, 'down', { count: Infinity });
    expect(await columns(scratch)).toEqual({});
    const fn = await withClient(scratch, (c) =>
      c.query<{ n: number }>(`select count(*)::int as n from pg_proc where proname = 'set_updated_at'`),
    );
    expect(fn.rows[0]?.n).toBe(0);
    await migrate(scratch, 'up');
    expect(Object.keys(await columns(scratch)).sort()).toEqual(Object.keys(EXPECTED).sort());
  });
});

describe('constraints from relational-schema.md', () => {
  const db = testDb();
  afterAll(() => db.destroy());
  beforeEach(() => resetDb(db));

  async function graph(): Promise<void> {
    await db.insertInto('users').values([
      { id: 'c1', display_name: 'Khách', role: 'customer' },
      { id: 'p1', display_name: 'Thợ', role: 'photographer' },
    ]).execute();
    await db.insertInto('photographers').values({ user_id: 'p1' }).execute();
    await db.insertInto('services').values({ id: 's1', photographer_id: 'p1', name: 'Gói', duration_minutes: 60, price: 1_000_000 }).execute();
  }

  const booking = (id: string, over: { status?: BookingStatus; remaining_amount?: number } = {}) => ({
    id, customer_id: 'c1', photographer_id: 'p1', service_id: 's1', service_name: 'Gói', service_price: 1_000_000,
    service_duration_minutes: 60, day: '2026-11-02', start_time: '09:00', end_time: '10:00', status: 'accepted' as const,
    deposit_amount: 300_000, remaining_amount: 700_000, ...over,
  });

  it('user_contacts refuses a number that is not E.164', async () => {
    await graph();
    await expect(db.insertInto('user_contacts').values({ user_id: 'c1', phone_e164: '0903123456' }).execute()).rejects.toThrow(/check constraint/);
    await db.insertInto('user_contacts').values({ user_id: 'c1', phone_e164: '+84903123456' }).execute();
  });

  it('bookings: deposit + remaining must equal the snapshot price', async () => {
    await graph();
    await expect(db.insertInto('bookings').values(booking('b1', { remaining_amount: 600_000 })).execute()).rejects.toThrow(/check constraint/);
  });

  it('bookings: one active booking per photographer and day', async () => {
    await graph();
    await db.insertInto('bookings').values(booking('b1')).execute();
    await expect(db.insertInto('bookings').values(booking('b2', { status: 'requested' })).execute()).rejects.toThrow(/ux_bookings_active_day/);
    await db.insertInto('bookings').values(booking('b3', { status: 'declined' })).execute();
  });

  it('contact_access_log: channel must be a ContactChannel code', async () => {
    await graph();
    await expect(
      db.insertInto('contact_access_log').values({ id: 'l1', requester_id: 'c1', subject_type: 'booking', subject_id: 'b1', channel: 'sms' as never, granted: false }).execute(),
    ).rejects.toThrow(/check constraint/);
  });

  it('updated_at is bumped by the trigger on update', async () => {
    await graph();
    const before = await db.selectFrom('users').select('updated_at').where('id', '=', 'c1').executeTakeFirstOrThrow();
    await sql`select pg_sleep(0.01)`.execute(db);
    await db.updateTable('users').set({ display_name: 'Lan' }).where('id', '=', 'c1').execute();
    const after = await db.selectFrom('users').select('updated_at').where('id', '=', 'c1').executeTakeFirstOrThrow();
    expect(after.updated_at.getTime()).toBeGreaterThan(before.updated_at.getTime());
  });

  it('studio_addresses.updated_at is bumped by the trigger on update', async () => {
    await graph();
    await db.insertInto('studio_addresses').values({ photographer_id: 'p1', line: '12 Lê Lợi', district: 'Quận 1', city: 'TP.HCM' }).execute();
    const before = await db.selectFrom('studio_addresses').select('updated_at').where('photographer_id', '=', 'p1').executeTakeFirstOrThrow();
    await sql`select pg_sleep(0.01)`.execute(db);
    await db.updateTable('studio_addresses').set({ district: 'Quận 3' }).where('photographer_id', '=', 'p1').execute();
    const after = await db.selectFrom('studio_addresses').select('updated_at').where('photographer_id', '=', 'p1').executeTakeFirstOrThrow();
    expect(after.updated_at.getTime()).toBeGreaterThan(before.updated_at.getTime());
  });

  it('money comes back as a JS integer and a day as yyyy-MM-dd', async () => {
    await graph();
    await db.insertInto('bookings').values(booking('b1')).execute();
    const row = await db.selectFrom('bookings').select(['service_price', 'day']).where('id', '=', 'b1').executeTakeFirstOrThrow();
    expect(row).toEqual({ service_price: 1_000_000, day: '2026-11-02' });
  });
});
