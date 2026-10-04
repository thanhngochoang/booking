import type { FastifyInstance } from 'fastify';

import { principalOf } from '../auth/plugin.js';
import { operation } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import type { components } from '../generated/api.js';
import { ensureProfile } from '../repos/users.js';

type S = components['schemas'];

export function registerMeRoutes(app: FastifyInstance, deps: RouteDeps): void {
  app.route<{ Body: S['EnsureProfileRequest'] }>({
    ...operation(deps.contract, 'ensureProfile'),
    handler: async (req, reply) => {
      const { profile, created } = await ensureProfile(deps.db, principalOf(req), req.body);
      return reply.status(created ? 201 : 200).send(profile);
    },
  });
}
