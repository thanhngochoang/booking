// services/api/tools/firestore-import/export.ts
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';

import { mapPhotographer, mapPhotographerNumbers, mapStudioAddress, mapUser, mapUserContact } from './map.js';
import { writeNdjson } from './ndjson.js';

/** relational-schema.md §5 order, restricted to the slice. */
export const SLICE_TABLES = [
  'files',
  'users',
  'user_contacts',
  'photographers',
  'photographer_contact_channels',
  'photographer_contact_numbers',
  'studio_addresses',
] as const;
export type SliceTable = (typeof SLICE_TABLES)[number];

export interface Manifest {
  schemaVersion: 1;
  source: 'firestore';
  exportedAt: string;
  tables: Record<SliceTable, { rows: number; sha256: string }>;
  rejected: number;
}

export interface SourceDoc {
  id: string;
  data: Record<string, unknown>;
}

export interface DocSource {
  list(collection: string): AsyncIterable<SourceDoc>;
  get(path: string): Promise<Record<string, unknown> | null>;
}

interface Rejected {
  source: string;
  reason: string;
}

export async function exportSlice(src: DocSource, outDir: string, now: Date = new Date()): Promise<Manifest> {
  const rows: Record<SliceTable, object[]> = {
    files: [], users: [], user_contacts: [], photographers: [], photographer_contact_channels: [], photographer_contact_numbers: [], studio_addresses: [],
  };
  const rejected: Rejected[] = [];
  const userIds = new Set<string>();

  for await (const doc of src.list('users')) {
    const m = mapUser(doc.id, doc.data);
    if (!m.ok) {
      rejected.push({ source: `users/${doc.id}`, reason: m.reason });
      continue;
    }
    userIds.add(doc.id);
    rows.users.push(m.value.user);
    if (m.value.file) rows.files.push(m.value.file);
    const contact = await src.get(`users/${doc.id}/private/contact`);
    if (contact) {
      const c = mapUserContact(doc.id, contact);
      if (c.ok) rows.user_contacts.push(c.value);
      else rejected.push({ source: `users/${doc.id}/private/contact`, reason: c.reason });
    }
  }

  for await (const doc of src.list('photographers')) {
    if (!userIds.has(doc.id)) {
      rejected.push({ source: `photographers/${doc.id}`, reason: 'no users document' });
      continue;
    }
    const m = mapPhotographer(doc.id, doc.data);
    if (!m.ok) {
      rejected.push({ source: `photographers/${doc.id}`, reason: m.reason });
      continue;
    }
    rows.photographers.push(m.value.photographer);
    if (m.value.channels) rows.photographer_contact_channels.push(m.value.channels);
    const numbers = await src.get(`photographers/${doc.id}/private/contact`);
    if (numbers) {
      const n = mapPhotographerNumbers(doc.id, numbers);
      if (n.ok) rows.photographer_contact_numbers.push(n.value);
      else rejected.push({ source: `photographers/${doc.id}/private/contact`, reason: n.reason });
    }
    const studio = await src.get(`photographers/${doc.id}/private/studioAddress`);
    if (studio) {
      const a = mapStudioAddress(doc.id, studio);
      if (a.ok) rows.studio_addresses.push(a.value);
      else rejected.push({ source: `photographers/${doc.id}/private/studioAddress`, reason: a.reason });
    }
  }

  await mkdir(outDir, { recursive: true });
  const tables = {} as Manifest['tables'];
  for (const t of SLICE_TABLES) tables[t] = await writeNdjson(join(outDir, `${t}.ndjson`), rows[t]);
  await writeNdjson(join(outDir, 'rejected.ndjson'), rejected);
  const manifest: Manifest = { schemaVersion: 1, source: 'firestore', exportedAt: now.toISOString(), tables, rejected: rejected.length };
  await writeFile(join(outDir, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
  return manifest;
}
