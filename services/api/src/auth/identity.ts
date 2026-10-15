import {
  createRemoteJWKSet,
  decodeJwt,
  decodeProtectedHeader,
  jwtVerify,
  type JWTPayload,
  type JWTVerifyGetKey,
} from 'jose';

import type { AuthProvider } from '../db/database.js';
import type { Clock } from '../deps.js';
import { ApiError } from '../errors.js';
import { isValidId } from '../ids.js';

/** Public keys of Firebase ID tokens (the IdentityProvider port, data-model README §3). */
export const FIREBASE_JWKS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

export interface Principal {
  /** = users.id (the Firebase uid today). */
  uid: string;
  /** Firebase `sign_in_provider`, e.g. google.com, facebook.com, password. */
  signInProvider: string;
  /** The subject at that provider, kept in auth_identities for the IdP switch (README §6 step 5). */
  providerSubject: string;
  email: string | null;
}

export interface IdentityVerifier {
  /** Throws ApiError('unauthenticated'). */
  verify(token: string): Promise<Principal>;
}

const issuerFor = (projectId: string): string => `https://securetoken.google.com/${projectId}`;

export function claimsToPrincipal(p: JWTPayload): Principal {
  const uid = p.sub;
  if (!isValidId(uid)) throw new ApiError('unauthenticated', 'token subject is not a valid id');
  const firebase = (typeof p.firebase === 'object' && p.firebase !== null ? p.firebase : {}) as {
    sign_in_provider?: unknown;
    identities?: Record<string, unknown>;
  };
  const signInProvider = typeof firebase.sign_in_provider === 'string' ? firebase.sign_in_provider : 'custom';
  const ids = firebase.identities?.[signInProvider];
  const first = Array.isArray(ids) && typeof ids[0] === 'string' ? ids[0] : null;
  return {
    uid,
    signInProvider,
    providerSubject: signInProvider === 'password' || first === null ? uid : first,
    email: typeof p.email === 'string' ? p.email : null,
  };
}

export function authProviderCode(signInProvider: string): AuthProvider {
  switch (signInProvider) {
    case 'password':
      return 'password';
    case 'google.com':
      return 'google';
    case 'facebook.com':
      return 'facebook';
    case 'apple.com':
      return 'apple';
    default:
      return 'oidc';
  }
}

/** Verifies RS256 tokens of one Firebase project against a JWKS (remote in production). */
export class JwksVerifier implements IdentityVerifier {
  constructor(private readonly opts: { jwks: JWTVerifyGetKey; projectId: string; clock?: Clock }) {}

  async verify(token: string): Promise<Principal> {
    let payload: JWTPayload;
    try {
      ({ payload } = await jwtVerify(token, this.opts.jwks, {
        issuer: issuerFor(this.opts.projectId),
        audience: this.opts.projectId,
        algorithms: ['RS256'],
        currentDate: this.opts.clock?.now(),
      }));
    } catch {
      throw new ApiError('unauthenticated', 'invalid or expired token');
    }
    return claimsToPrincipal(payload);
  }
}

export function firebaseVerifier(projectId: string): JwksVerifier {
  // createRemoteJWKSet caches keys and refetches only on an unknown kid.
  return new JwksVerifier({ jwks: createRemoteJWKSet(new URL(FIREBASE_JWKS_URL)), projectId });
}

/**
 * Accepts the Firebase Auth emulator's unsigned tokens (alg "none") for one project.
 * loadConfig refuses this mode when NODE_ENV=production.
 */
export class EmulatorVerifier implements IdentityVerifier {
  constructor(private readonly opts: { projectId: string; clock?: Clock }) {}

  async verify(token: string): Promise<Principal> {
    let alg: unknown;
    let payload: JWTPayload;
    try {
      alg = decodeProtectedHeader(token).alg;
      payload = decodeJwt(token);
    } catch {
      throw new ApiError('unauthenticated', 'invalid token');
    }
    const now = Math.floor((this.opts.clock?.now() ?? new Date()).getTime() / 1000);
    if (
      alg !== 'none' ||
      payload.iss !== issuerFor(this.opts.projectId) ||
      payload.aud !== this.opts.projectId ||
      typeof payload.exp !== 'number' ||
      payload.exp <= now
    ) {
      throw new ApiError('unauthenticated', 'invalid or expired emulator token');
    }
    return claimsToPrincipal(payload);
  }
}
