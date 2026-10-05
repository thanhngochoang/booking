// services/api/tools/firestore-import/load.ts
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';

import { sql, type Kysely, type Transaction } from 'kysely';

import type { Database } from '../../src/db/database.js';
import { SLICE_TABLES, type Manifest, type SliceTable } from './export.js';
import type { ChannelsRow, FileRow, NumbersRow, PhotographerRow, UserContactRow, UserRow } from './map.js';
import { readNdjson } from './ndjson.js';

export class ImportCheckError extends Error {}

export interface LoadReport {
  dryRun: boolean;
  tables: Record<SliceTable, { file: number; inDb: number }>;
}

class DryRunRollback extends Error {
  constructor(readonly report: LoadReport) {
    super('dry run');
  }
}

const PK: Record<SliceTable, string> = {
  files: 'id',
  users: 'id',
  user_contacts: 'user_id',
  photographers: 'user_id',
  photographer_contact_channels: 'photographer_id',
  photographer_contact_numbers: 'photographer_id',
};

const chunks = <T>(rows: T[], size = 500): T[][] =>
  Array.from({ length: Math.ceil(rows.length / size) }, (_, i) => rows.slice(i * size, (i + 1) * size));

const stamps = (r: { created_at?: string | null; updated_at: string | null }) => ({
  ...(r.created_at ? { created_at: r.created_at } : {}),
  ...(r.updated_at ? { updated_at: r.updated_at } : {}),
});

type Trx = Transaction<Database>;

// Every upsert skips rows whose values are unchanged, so no trigger fires and a re-run is a no-op.
async function upsertFiles(trx: Trx, rows: FileRow[]): Promise<void> {
  for (const c of chunks(rows)) {
    await trx
      .insertInto('files')
      .values(c.map((r) => ({ ...r, owner_user_id: null })))
      .onConflict((oc) =>
        oc
          .column('id')
          .doUpdateSet((eb) => ({ storage_key: eb.ref('excluded.storage_key') }))
          .where(sql<boolean>`files.storage_key is distinct from excluded.storage_key`),
      )
      .execute();
  }
}

async function upsertUsers(trx: Trx, rows: UserRow[]): Promise<void> {
  for (const c of chunks(rows)) {
    await trx
      .insertInto('users')
      .values(c.map((r) => ({ id: r.id, display_name: r.display_name, role: r.role, avatar_file_id: r.avatar_file_id, ...stamps(r) })))
      .onConflict((oc) =>
        oc
          .column('id')
          .doUpdateSet((eb) => ({
            display_name: eb.ref('excluded.display_name'),
            role: eb.ref('excluded.role'),
            avatar_file_id: eb.ref('excluded.avatar_file_id'),
          }))
          .where(sql<boolean>`(users.display_name, users.role, users.avatar_file_id)
            is distinct from (excluded.display_name, excluded.role, excluded.avatar_file_id)`),
      )
      .execute();
  }
}

async function setFileOwners(trx: Trx, rows: FileRow[]): Promise<void> {
  if (rows.length === 0) return;
  await sql`update files set owner_user_id = data.owner
    from unnest(${rows.map((r) => r.id)}::text[], ${rows.map((r) => r.owner_user_id)}::text[]) as data(id, owner)
    where files.id = data.id and files.owner_user_id is distinct from data.owner`.execute(trx);
}

async function upsertUserContacts(trx: Trx, rows: UserContactRow[]): Promise<void> {
  for (const c of chunks(rows)) {
    await trx
      .insertInto('user_contacts')
      .values(c.map((r) => ({
        user_id: r.user_id, phone_e164: r.phone_e164, phone_verified: r.phone_verified,
        allow_zalo: r.allow_zalo, allow_whatsapp: r.allow_whatsapp, ...stamps(r),
      })))
      .onConflict((oc) =>
        oc
          .column('user_id')
          .doUpdateSet((eb) => ({
            phone_e164: eb.ref('excluded.phone_e164'),
            phone_verified: eb.ref('excluded.phone_verified'),
            allow_zalo: eb.ref('excluded.allow_zalo'),
            allow_whatsapp: eb.ref('excluded.allow_whatsapp'),
          }))
          .where(sql<boolean>`(user_contacts.phone_e164, user_contacts.phone_verified, user_contacts.allow_zalo, user_contacts.allow_whatsapp)
            is distinct from (excluded.phone_e164, excluded.phone_verified, excluded.allow_zalo, excluded.allow_whatsapp)`),
      )
      .execute();
  }
}

async function upsertPhotographers(trx: Trx, rows: PhotographerRow[]): Promise<void> {
  for (const c of chunks(rows)) {
    await trx
      .insertInto('photographers')
      .values(c.map((r) => ({
        user_id: r.user_id, bio: r.bio, years_experience: r.years_experience, service_city: r.service_city,
        service_lat: r.service_lat, service_lng: r.service_lng, service_radius_km: r.service_radius_km,
        verified: r.verified, onboarding_complete: r.onboarding_complete, accepts_inquiries: r.accepts_inquiries,
        ...stamps(r),
      })))
      .onConflict((oc) =>
        oc
          .column('user_id')
          .doUpdateSet((eb) => ({
            bio: eb.ref('excluded.bio'),
            years_experience: eb.ref('excluded.years_experience'),
            service_city: eb.ref('excluded.service_city'),
            service_lat: eb.ref('excluded.service_lat'),
            service_lng: eb.ref('excluded.service_lng'),
            service_radius_km: eb.ref('excluded.service_radius_km'),
            verified: eb.ref('excluded.verified'),
            onboarding_complete: eb.ref('excluded.onboarding_complete'),
            accepts_inquiries: eb.ref('excluded.accepts_inquiries'),
          }))
          .where(sql<boolean>`(photographers.bio, photographers.years_experience, photographers.service_city,
              photographers.service_lat, photographers.service_lng, photographers.service_radius_km,
              photographers.verified, photographers.onboarding_complete, photographers.accepts_inquiries)
            is distinct from (excluded.bio, excluded.years_experience, excluded.service_city,
              excluded.service_lat, excluded.service_lng, excluded.service_radius_km,
              excluded.verified, excluded.onboarding_complete, excluded.accepts_inquiries)`),
      )
      .execute();
  }
}

async function upsertChannels(trx: Trx, rows: ChannelsRow[]): Promise<void> {
  for (const c of chunks(rows)) {
    await trx
      .insertInto('photographer_contact_channels')
      .values(c)
      .onConflict((oc) =>
        oc
          .column('photographer_id')
          .doUpdateSet((eb) => ({
            call_enabled: eb.ref('excluded.call_enabled'),
            zalo_enabled: eb.ref('excluded.zalo_enabled'),
            whatsapp_enabled: eb.ref('excluded.whatsapp_enabled'),
          }))
          .where(sql<boolean>`(photographer_contact_channels.call_enabled, photographer_contact_channels.zalo_enabled,
              photographer_contact_channels.whatsapp_enabled)
            is distinct from (excluded.call_enabled, excluded.zalo_enabled, excluded.whatsapp_enabled)`),
      )
      .execute();
  }
}

async function upsertNumbers(trx: Trx, rows: NumbersRow[]): Promise<void> {
  for (const c of chunks(rows)) {
    await trx
      .insertInto('photographer_contact_numbers')
      .values(c)
      .onConflict((oc) =>
        oc
          .column('photographer_id')
          .doUpdateSet((eb) => ({
            phone_e164: eb.ref('excluded.phone_e164'),
            zalo_phone_e164: eb.ref('excluded.zalo_phone_e164'),
            whatsapp_phone_e164: eb.ref('excluded.whatsapp_phone_e164'),
          }))
          .where(sql<boolean>`(photographer_contact_numbers.phone_e164, photographer_contact_numbers.zalo_phone_e164,
              photographer_contact_numbers.whatsapp_phone_e164)
            is distinct from (excluded.phone_e164, excluded.zalo_phone_e164, excluded.whatsapp_phone_e164)`),
      )
      .execute();
  }
}

/**
 * Loads an export into PostgreSQL in one transaction (data-model README §6 step 2):
 * checksums and counts first, then upserts in FK order, then every exported id
 * must be present. Any mismatch, or dryRun, rolls everything back.
 */
export async function loadSlice(db: Kysely<Database>, dir: string, opts: { dryRun: boolean }): Promise<LoadReport> {
  const manifest = JSON.parse(await readFile(join(dir, 'manifest.json'), 'utf8')) as Manifest;
  if (manifest.schemaVersion !== 1) throw new ImportCheckError(`unsupported schemaVersion ${String(manifest.schemaVersion)}`);
  const data = {} as Record<SliceTable, Record<string, unknown>[]>;
  for (const t of SLICE_TABLES) {
    const { rows, sha256 } = await readNdjson<Record<string, unknown>>(join(dir, `${t}.ndjson`));
    const meta = manifest.tables[t];
    if (sha256 !== meta.sha256) throw new ImportCheckError(`${t}.ndjson checksum does not match manifest.json`);
    if (rows.length !== meta.rows) throw new ImportCheckError(`${t}.ndjson has ${rows.length} rows, manifest says ${meta.rows}`);
    data[t] = rows;
  }

  try {
    return await db.transaction().execute(async (trx) => {
      await upsertFiles(trx, data.files as unknown as FileRow[]);
      await upsertUsers(trx, data.users as unknown as UserRow[]);
      await setFileOwners(trx, data.files as unknown as FileRow[]);
      await upsertUserContacts(trx, data.user_contacts as unknown as UserContactRow[]);
      await upsertPhotographers(trx, data.photographers as unknown as PhotographerRow[]);
      await upsertChannels(trx, data.photographer_contact_channels as unknown as ChannelsRow[]);
      await upsertNumbers(trx, data.photographer_contact_numbers as unknown as NumbersRow[]);

      const tables = {} as LoadReport['tables'];
      for (const t of SLICE_TABLES) {
        const ids = data[t].map((r) => String(r[PK[t]]));
        const r = await sql<{ n: number }>`select count(*)::int as n from ${sql.table(t)}
          where ${sql.ref(PK[t])} = any(${ids}::text[])`.execute(trx);
        const inDb = r.rows[0]?.n ?? 0;
        if (inDb !== ids.length) throw new ImportCheckError(`${t}: ${ids.length} exported, ${inDb} present after load`);
        tables[t] = { file: ids.length, inDb };
      }
      const report: LoadReport = { dryRun: opts.dryRun, tables };
      if (opts.dryRun) throw new DryRunRollback(report);
      return report;
    });
  } catch (e) {
    if (e instanceof DryRunRollback) return e.report;
    throw e;
  }
}
