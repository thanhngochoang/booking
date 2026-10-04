import compress from '@fastify/compress';
import Fastify, { type FastifyInstance } from 'fastify';
import type { Kysely } from 'kysely';

import type { IdentityVerifier } from './auth/identity.js';
import { installAuth } from './auth/plugin.js';
import { loadContract, registerContractSchemas, type Contract } from './contract/openapi.js';
import type { Database } from './db/database.js';
import { systemClock, type Clock, type RouteDeps } from './deps.js';
import { installErrorHandling } from './errors.js';
import { registerHealthRoutes } from './routes/health.js';
import { registerMeRoutes } from './routes/me.js';

export interface AppDeps {
  db: Kysely<Database>;
  verifier: IdentityVerifier;
  /** Defaults to api/openapi.yaml (CONTRACT_PATH in the image). */
  contract?: Contract;
  clock?: Clock;
  /** Pino level; omit to disable logging (tests). */
  logLevel?: string;
}

export async function buildApp(deps: AppDeps): Promise<FastifyInstance> {
  const app = Fastify({
    logger: deps.logLevel ? { level: deps.logLevel, redact: ['req.headers.authorization'] } : false,
    keepAliveTimeout: 65_000,
    bodyLimit: 16 * 1024,
    // Extra properties are an error, not silently dropped (clients never write server fields).
    ajv: { customOptions: { removeAdditional: false, coerceTypes: false } },
  });

  const routeTable: Array<{ method: string; url: string }> = [];
  app.decorate('routeTable', routeTable);
  app.addHook('onRoute', (r) => {
    for (const method of [r.method].flat()) if (method !== 'HEAD') routeTable.push({ method, url: r.url });
  });

  const contract = deps.contract ?? loadContract();
  registerContractSchemas(app, contract);
  installErrorHandling(app);
  installAuth(app, deps.verifier);
  // Slice payloads are < 1 KiB and stay uncompressed; anything larger is gzipped.
  await app.register(compress, { global: true, threshold: 1024, encodings: ['gzip'] });

  const routeDeps: RouteDeps = { db: deps.db, contract, clock: deps.clock ?? systemClock };
  registerHealthRoutes(app, routeDeps);
  registerMeRoutes(app, routeDeps);
  return app;
}
