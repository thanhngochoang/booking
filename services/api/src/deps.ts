import type { Kysely } from 'kysely';

import type { Contract } from './contract/openapi.js';
import type { Database } from './db/database.js';

export interface Clock {
  now(): Date;
}

export const systemClock: Clock = { now: () => new Date() };

/** What every route module receives. */
export interface RouteDeps {
  db: Kysely<Database>;
  contract: Contract;
  clock: Clock;
}
