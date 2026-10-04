import { Kysely, PostgresDialect } from 'kysely';
import pg from 'pg';

// int8 (bigint money, count(*)) → number; refuse values a JS number cannot hold exactly.
pg.types.setTypeParser(20, (v: string) => {
  const n = Number(v);
  if (!Number.isSafeInteger(n)) throw new RangeError(`int8 value ${v} exceeds Number.MAX_SAFE_INTEGER`);
  return n;
});
// date stays 'yyyy-MM-dd': a calendar day in Asia/Ho_Chi_Minh, not an instant.
pg.types.setTypeParser(1082, (v: string) => v);

// Tables arrive with the migrations (Task 2).
// eslint-disable-next-line @typescript-eslint/no-empty-interface
export interface Database {}

export function createDb(databaseUrl: string, max: number): Kysely<Database> {
  return new Kysely<Database>({
    dialect: new PostgresDialect({
      pool: new pg.Pool({
        connectionString: databaseUrl,
        max,
        idleTimeoutMillis: 30_000,
        connectionTimeoutMillis: 2_000,
      }),
    }),
  });
}
