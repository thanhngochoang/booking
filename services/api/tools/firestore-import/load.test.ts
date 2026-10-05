// services/api/tools/firestore-import/load.test.ts
import { appendFile, mkdtemp } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { findProfile } from '../../src/repos/users.js';
import { resetDb, testDb } from '../../test/helpers.js';
import { exportSlice } from './export.js';
import { ImportCheckError, loadSlice } from './load.js';
import { FIXTURE, memorySource } from './memory-source.js';

const db = testDb();
afterAll(() => db.destroy());
beforeEach(() => resetDb(db));

async function exported(): Promise<string> {
  const dir = await mkdtemp(join(tmpdir(), 'nag-load-'));
  await exportSlice(memorySource(FIXTURE), dir);
  return dir;
}

const EXPECTED = {
  files: { file: 1, inDb: 1 },
  users: { file: 2, inDb: 2 },
  user_contacts: { file: 1, inDb: 1 },
  photographers: { file: 1, inDb: 1 },
  photographer_contact_channels: { file: 1, inDb: 1 },
  photographer_contact_numbers: { file: 1, inDb: 1 },
};

describe('loadSlice', () => {
  it('--dry-run checks everything and writes nothing', async () => {
    const report = await loadSlice(db, await exported(), { dryRun: true });
    expect(report).toEqual({ dryRun: true, tables: EXPECTED });
    expect(await db.selectFrom('users').selectAll().execute()).toEqual([]);
  });

  it('loads with ids kept, counts matching, and a second run changes nothing', async () => {
    const dir = await exported();
    expect(await loadSlice(db, dir, { dryRun: false })).toEqual({ dryRun: false, tables: EXPECTED });
    const before = await db.selectFrom('users').select(['id', 'updated_at']).orderBy('id').execute();
    expect(before.map((r) => r.id)).toEqual(['p_minh', 'u_lan']);
    expect(before[1]?.updated_at.toISOString()).toBe('2026-09-02T00:00:00.000Z');

    expect(await loadSlice(db, dir, { dryRun: false })).toEqual({ dryRun: false, tables: EXPECTED });
    const after = await db.selectFrom('users').select(['id', 'updated_at']).orderBy('id').execute();
    expect(after).toEqual(before);

    expect((await findProfile(db, 'u_lan'))?.avatarUrl).toBe('https://lh3.googleusercontent.com/a/lan.jpg');
    const numbers = await db.selectFrom('photographer_contact_numbers').selectAll().executeTakeFirstOrThrow();
    expect(numbers).toEqual({ photographer_id: 'p_minh', phone_e164: '+84912345678', zalo_phone_e164: '+84987654321', whatsapp_phone_e164: null });
  });

  it('a file that does not match its manifest stops the import before any write', async () => {
    const dir = await exported();
    await appendFile(join(dir, 'users.ndjson'), '{"id":"intruder","display_name":"x","role":null,"avatar_file_id":null,"created_at":null,"updated_at":null}\n');
    await expect(loadSlice(db, dir, { dryRun: false })).rejects.toBeInstanceOf(ImportCheckError);
    expect(await db.selectFrom('users').selectAll().execute()).toEqual([]);
  });
});
