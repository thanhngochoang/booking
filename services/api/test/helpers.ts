import type { FastifyInstance } from 'fastify';
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type JWK, type KeyLike } from 'jose';
import { sql, type Kysely } from 'kysely';

import { buildApp, type AppDeps } from '../src/app.js';
import { JwksVerifier } from '../src/auth/identity.js';
import { createDb, type Database } from '../src/db/database.js';

export const PROJECT_ID = 'demo-nag-test';

export function testDatabaseUrl(): string {
  const url = process.env.TEST_DATABASE_URL;
  if (!url) throw new Error('TEST_DATABASE_URL is set by test/global-setup.ts');
  return url;
}

export function testDb(): Kysely<Database> {
  return createDb(testDatabaseUrl(), 4);
}

/** Empties every slice table (FK order handled by CASCADE). */
export async function resetDb(db: Kysely<Database>): Promise<void> {
  await sql`truncate table contact_access_log, booking_events, bookings, services,
    photographer_contact_numbers, photographer_contact_channels, photographers, taxonomy_items,
    auth_identities, user_contacts, users, files restart identity cascade`.execute(db);
}

// A local RS256 key stands in for Google's securetoken key: the same JwksVerifier
// class runs in production with the remote JWKS.
const keys = await generateKeyPair('RS256', { extractable: true });
const publicJwk: JWK = { ...(await exportJWK(keys.publicKey)), kid: 'test-key', alg: 'RS256', use: 'sig' };
export const testVerifier = new JwksVerifier({ jwks: createLocalJWKSet({ keys: [publicJwk] }), projectId: PROJECT_ID });

export interface TokenOptions {
  provider?: string;
  identities?: Record<string, string[]>;
  email?: string;
  audience?: string;
  issuer?: string;
  /** Expiry as epoch seconds; default one hour from now. */
  exp?: number;
  key?: KeyLike;
}

export function tokenFor(uid: string, o: TokenOptions = {}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  return new SignJWT({
    user_id: uid,
    auth_time: now,
    ...(o.email ? { email: o.email } : {}),
    firebase: { sign_in_provider: o.provider ?? 'password', identities: o.identities ?? {} },
  })
    .setProtectedHeader({ alg: 'RS256', kid: 'test-key' })
    .setIssuer(o.issuer ?? `https://securetoken.google.com/${PROJECT_ID}`)
    .setAudience(o.audience ?? PROJECT_ID)
    .setSubject(uid)
    .setIssuedAt(now)
    .setExpirationTime(o.exp ?? now + 3600)
    .sign(o.key ?? keys.privateKey);
}

export async function bearer(uid: string, o?: TokenOptions): Promise<{ authorization: string }> {
  return { authorization: `Bearer ${await tokenFor(uid, o)}` };
}

/** What the Firebase Auth emulator issues: an unsigned JWT (alg "none"). */
export function emulatorToken(uid: string, o: { projectId?: string; exp?: number } = {}): string {
  const projectId = o.projectId ?? PROJECT_ID;
  const now = Math.floor(Date.now() / 1000);
  const enc = (v: object) => Buffer.from(JSON.stringify(v)).toString('base64url');
  return `${enc({ alg: 'none', typ: 'JWT' })}.${enc({
    iss: `https://securetoken.google.com/${projectId}`,
    aud: projectId,
    sub: uid,
    user_id: uid,
    iat: now,
    auth_time: now,
    exp: o.exp ?? now + 3600,
    firebase: { sign_in_provider: 'password', identities: {} },
  })}.`;
}

export function testApp(deps: Omit<AppDeps, 'verifier'> & Partial<Pick<AppDeps, 'verifier'>>): Promise<FastifyInstance> {
  return buildApp({ verifier: testVerifier, ...deps });
}
