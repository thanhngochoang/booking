import type { FastifyInstance } from 'fastify';

import { principalOf, requireSelf } from '../auth/plugin.js';
import { operation } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import { ApiError } from '../errors.js';
import type { components } from '../generated/api.js';
import { completeContactSetup, findChannels, findNumbers, findServiceArea } from '../repos/photographers.js';

type S = components['schemas'];
interface PhotographerParams {
  photographerId: string;
}

export function registerPhotographerRoutes(app: FastifyInstance, deps: RouteDeps): void {
  app.route<{ Params: PhotographerParams }>({
    ...operation(deps.contract, 'getContactChannels'),
    handler: async (req) => {
      principalOf(req);
      const channels = await findChannels(deps.db, req.params.photographerId);
      if (!channels) throw new ApiError('not_found', 'contact channels are not set up');
      return channels;
    },
  });

  app.route<{ Params: PhotographerParams }>({
    ...operation(deps.contract, 'getContactNumbers'),
    handler: async (req, reply) => {
      requireSelf(req, req.params.photographerId);
      reply.header('cache-control', 'no-store');
      const numbers = await findNumbers(deps.db, req.params.photographerId);
      if (!numbers) throw new ApiError('not_found', 'contact numbers are not set up');
      return numbers;
    },
  });

  app.route<{ Params: PhotographerParams }>({
    ...operation(deps.contract, 'getServiceArea'),
    handler: async (req) => {
      const p = principalOf(req);
      const found = await findServiceArea(deps.db, req.params.photographerId);
      // Others see a photographer only once onboarding is complete (README §4).
      if (!found || (!found.onboardingComplete && p.uid !== req.params.photographerId)) {
        throw new ApiError('not_found', 'service area is not set up');
      }
      return found.area;
    },
  });

  app.route<{ Params: PhotographerParams; Body: S['ContactSetupRequest'] }>({
    ...operation(deps.contract, 'completeContactSetup'),
    handler: async (req, reply) => {
      requireSelf(req, req.params.photographerId);
      await completeContactSetup(deps.db, req.params.photographerId, req.body);
      return reply.status(204).send();
    },
  });
}
