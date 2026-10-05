// services/api/tools/firestore-import/cli.ts
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

import { createDb } from '../../src/db/database.js';
import { exportSlice } from './export.js';
import { firestoreSource } from './firestore-source.js';
import { loadSlice } from './load.js';

const USAGE = `usage:
  import:firestore export --out <dir>         env FIREBASE_PROJECT_ID, and FIRESTORE_EMULATOR_HOST or GOOGLE_APPLICATION_CREDENTIALS
  import:firestore load --in <dir> [--dry-run] env DATABASE_URL`;

const [command, ...args] = process.argv.slice(2);
const flag = (name: string): string | undefined => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};

if (command === 'export') {
  const out = flag('--out');
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!out || !projectId) {
    console.error(USAGE);
    process.exit(2);
  }
  initializeApp({ projectId });
  const manifest = await exportSlice(firestoreSource(getFirestore()), out);
  console.table(Object.fromEntries(Object.entries(manifest.tables).map(([t, m]) => [t, { rows: m.rows }])));
  console.log(`rejected: ${manifest.rejected} (reasons in ${out}/rejected.ndjson)`);
} else if (command === 'load') {
  const dir = flag('--in');
  const url = process.env.DATABASE_URL;
  if (!dir || !url) {
    console.error(USAGE);
    process.exit(2);
  }
  const db = createDb(url, 2);
  try {
    const report = await loadSlice(db, dir, { dryRun: args.includes('--dry-run') });
    console.table(report.tables);
    console.log(report.dryRun ? 'dry run: checked and rolled back, nothing written' : 'loaded: counts match');
  } catch (e) {
    console.error(e instanceof Error ? e.message : String(e));
    process.exitCode = 1;
  } finally {
    await db.destroy();
  }
} else {
  console.error(USAGE);
  process.exit(2);
}
