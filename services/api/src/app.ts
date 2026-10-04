import Fastify, { type FastifyInstance } from 'fastify';
import type { Kysely } from 'kysely';

import type { Database } from './db/database.js';
import { registerHealthRoutes } from './routes/health.js';

export interface AppDeps {
  db: Kysely<Database>;
  /** Pino level; omit to disable logging (tests). */
  logLevel?: string;
}

export async function buildApp(deps: AppDeps): Promise<FastifyInstance> {
  const app = Fastify({
    logger: deps.logLevel ? { level: deps.logLevel, redact: ['req.headers.authorization'] } : false,
    keepAliveTimeout: 65_000,
    bodyLimit: 16 * 1024,
    ajv: { customOptions: { removeAdditional: false, coerceTypes: false } },
  });
  registerHealthRoutes(app, deps);
  return app;
}
