import type { FastifyInstance, FastifyRequest } from 'fastify';

import { ApiError } from '../errors.js';
import type { IdentityVerifier, Principal } from './identity.js';

declare module 'fastify' {
  interface FastifyRequest {
    principal: Principal | null;
  }
}

/** Every route needs a bearer token unless its config says `public: true`. */
export function installAuth(app: FastifyInstance, verifier: IdentityVerifier): void {
  app.decorateRequest('principal', null);
  app.addHook('onRequest', async (req) => {
    if (req.is404 || req.routeOptions.config.public === true) return;
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) throw new ApiError('unauthenticated', 'missing bearer token');
    req.principal = await verifier.verify(header.slice('Bearer '.length).trim());
  });
}

export function principalOf(req: FastifyRequest): Principal {
  if (!req.principal) throw new ApiError('unauthenticated', 'missing bearer token');
  return req.principal;
}

/** Authorization matrix "S": only the subject itself. */
export function requireSelf(req: FastifyRequest, subjectId: string): Principal {
  const p = principalOf(req);
  if (p.uid !== subjectId) throw new ApiError('permission_denied', 'only the owner can do this');
  return p;
}
