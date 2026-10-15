import { fileURLToPath } from 'node:url';

import { runner } from 'node-pg-migrate';

/** services/api/migrations when run from source; the image sets MIGRATIONS_DIR. */
export const DEFAULT_MIGRATIONS_DIR = fileURLToPath(new URL('../../migrations', import.meta.url));

export function migrate(
  databaseUrl: string,
  direction: 'up' | 'down',
  opts: { count?: number; dir?: string; log?: (msg: string) => void } = {},
): Promise<unknown> {
  return runner({
    databaseUrl,
    dir: opts.dir ?? process.env.MIGRATIONS_DIR ?? DEFAULT_MIGRATIONS_DIR,
    direction,
    count: opts.count ?? (direction === 'up' ? Infinity : 1),
    migrationsTable: 'pgmigrations',
    checkOrder: true,
    singleTransaction: true,
    log: opts.log ?? (() => {}),
  });
}
