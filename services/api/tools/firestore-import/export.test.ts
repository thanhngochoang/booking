// services/api/tools/firestore-import/export.test.ts
import { mkdtemp, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import { exportSlice } from './export.js';
import { FIXTURE, memorySource } from './memory-source.js';
import { sha256 } from './ndjson.js';

describe('exportSlice', () => {
  it('writes one NDJSON file per table plus a manifest with counts and SHA-256', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'nag-export-'));
    const m = await exportSlice(memorySource(FIXTURE), dir, new Date('2026-10-01T00:00:00Z'));
    expect(Object.fromEntries(Object.entries(m.tables).map(([t, v]) => [t, v.rows]))).toEqual({
      files: 1, users: 2, user_contacts: 1, photographers: 1, photographer_contact_channels: 1, photographer_contact_numbers: 1,
    });
    expect(m).toMatchObject({ schemaVersion: 1, source: 'firestore', exportedAt: '2026-10-01T00:00:00.000Z', rejected: 3 });
    for (const [table, meta] of Object.entries(m.tables)) {
      expect(sha256(await readFile(join(dir, `${table}.ndjson`), 'utf8')), table).toBe(meta.sha256);
    }
    const manifest = JSON.parse(await readFile(join(dir, 'manifest.json'), 'utf8'));
    expect(manifest).toEqual(m);
  });

  it('lists what it skipped and why, without any value', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'nag-export-'));
    await exportSlice(memorySource(FIXTURE), dir);
    const text = await readFile(join(dir, 'rejected.ndjson'), 'utf8');
    expect(text.trim().split('\n').map((l) => JSON.parse(l))).toEqual([
      { source: 'users/p_minh/private/contact', reason: 'phone is not E.164' },
      { source: 'users/bad$id', reason: 'id is not [A-Za-z0-9_-]{1,64}' },
      { source: 'photographers/p_ghost', reason: 'no users document' },
    ]);
    expect(text).not.toContain('0903123456');
  });
});
