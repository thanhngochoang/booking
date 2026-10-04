import type { FastifyInstance } from 'fastify';
import { sql } from 'kysely';

import { operation } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';

export function registerHealthRoutes(app: FastifyInstance, deps: RouteDeps): void {
  app.route({
    ...operation(deps.contract, 'health'),
    config: { public: true },
    handler: async (_req, reply) => {
      try {
        await sql`select 1`.execute(deps.db);
        return { status: 'ok', db: 'ok' };
      } catch {
        return reply.status(503).send({ status: 'degraded', db: 'down' });
      }
    },
  });
}
