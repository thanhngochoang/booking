import { describe, expect, it } from 'vitest';

import { loadConfig } from '../src/config.js';

const base = { DATABASE_URL: 'postgres://x@localhost/x', FIREBASE_PROJECT_ID: 'demo-nag' };

describe('loadConfig', () => {
  it('has safe defaults: firebase auth, pool of 10, port 8787', () => {
    const c = loadConfig({ ...base });
    expect(c).toMatchObject({ authMode: 'firebase', dbPoolMax: 10, port: 8787, nodeEnv: 'production' });
  });

  it('refuses emulator tokens in production', () => {
    expect(() => loadConfig({ ...base, AUTH_MODE: 'firebase-emulator', NODE_ENV: 'production' })).toThrow(/refused/);
    expect(loadConfig({ ...base, AUTH_MODE: 'firebase-emulator', NODE_ENV: 'development' }).authMode).toBe('firebase-emulator');
  });

  it('rejects missing and out-of-range values', () => {
    expect(() => loadConfig({ FIREBASE_PROJECT_ID: 'p' })).toThrow(/DATABASE_URL/);
    expect(() => loadConfig({ ...base, DB_POOL_MAX: '0' })).toThrow(/DB_POOL_MAX/);
    expect(() => loadConfig({ ...base, AUTH_MODE: 'jwt' })).toThrow(/AUTH_MODE/);
  });
});
