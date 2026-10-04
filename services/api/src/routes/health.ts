import type { FastifyInstance } from 'fastify';
import { sql, type Kysely } from 'kysely';

import type { Database } from '../db/database.js';

export function registerHealthRoutes(app: FastifyInstance, deps: { db: Kysely<Database> }): void {
  app.get('/v1/health', { config: { public: true } }, async (_req, reply) => {
    try {
      await sql`select 1`.execute(deps.db);
      return { status: 'ok', db: 'ok' };
    } catch {
      return reply.status(503).send({ status: 'degraded', db: 'down' });
    }
  });
}
