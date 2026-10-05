import type { FastifyInstance } from 'fastify';

import { principalOf, requireSelf } from '../auth/plugin.js';
import { operation } from '../contract/openapi.js';
import type { RouteDeps } from '../deps.js';
import { ApiError } from '../errors.js';
import type { components } from '../generated/api.js';
import { findContact, findProfile, saveContact, setRole, updateDisplayName } from '../repos/users.js';

type S = components['schemas'];
interface UserParams {
  userId: string;
}

const missingProfile = () => new ApiError('not_found', 'create the profile first (POST /v1/me)');

export function registerUserRoutes(app: FastifyInstance, deps: RouteDeps): void {
  app.route<{ Params: UserParams }>({
    ...operation(deps.contract, 'getUser'),
    handler: async (req) => {
      principalOf(req);
      const profile = await findProfile(deps.db, req.params.userId);
      if (!profile) throw new ApiError('not_found', 'no such user');
      return profile;
    },
  });

  app.route<{ Params: UserParams; Body: S['UpdateUserRequest'] }>({
    ...operation(deps.contract, 'updateUser'),
    handler: async (req) => {
      requireSelf(req, req.params.userId);
      const profile = await updateDisplayName(deps.db, req.params.userId, req.body.displayName);
      if (!profile) throw missingProfile();
      return profile;
    },
  });

  app.route<{ Params: UserParams; Body: S['SetRoleRequest'] }>({
    ...operation(deps.contract, 'setRole'),
    handler: async (req) => {
      requireSelf(req, req.params.userId);
      const profile = await setRole(deps.db, req.params.userId, req.body.role);
      if (!profile) throw missingProfile();
      return profile;
    },
  });

  app.route<{ Params: UserParams }>({
    ...operation(deps.contract, 'getUserContact'),
    handler: async (req, reply) => {
      requireSelf(req, req.params.userId);
      reply.header('cache-control', 'no-store');
      const contact = await findContact(deps.db, req.params.userId);
      if (!contact) throw new ApiError('not_found', 'no contact saved yet');
      return contact;
    },
  });

  app.route<{ Params: UserParams; Body: S['SaveUserContactRequest'] }>({
    ...operation(deps.contract, 'saveUserContact'),
    handler: async (req, reply) => {
      requireSelf(req, req.params.userId);
      reply.header('cache-control', 'no-store');
      return saveContact(deps.db, req.params.userId, req.body);
    },
  });
}
