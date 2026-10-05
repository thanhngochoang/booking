export type AuthMode = 'firebase' | 'firebase-emulator';

export interface Config {
  port: number;
  host: string;
  databaseUrl: string;
  dbPoolMax: number;
  authMode: AuthMode;
  firebaseProjectId: string;
  logLevel: string;
  nodeEnv: string;
}

function required(env: NodeJS.ProcessEnv, key: string): string {
  const v = env[key];
  if (v === undefined || v.trim() === '') throw new Error(`${key} is required`);
  return v.trim();
}

function int(env: NodeJS.ProcessEnv, key: string, fallback: number, min: number, max: number): number {
  const raw = env[key];
  const n = raw === undefined || raw === '' ? fallback : Number(raw);
  if (!Number.isInteger(n) || n < min || n > max) {
    throw new Error(`${key} must be an integer between ${min} and ${max}`);
  }
  return n;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const nodeEnv = env.NODE_ENV ?? 'production';
  const authMode = env.AUTH_MODE ?? 'firebase';
  if (authMode !== 'firebase' && authMode !== 'firebase-emulator') {
    throw new Error('AUTH_MODE must be firebase or firebase-emulator');
  }
  if (authMode === 'firebase-emulator' && nodeEnv === 'production') {
    throw new Error('AUTH_MODE=firebase-emulator accepts unsigned tokens and is refused when NODE_ENV=production');
  }
  return {
    port: int(env, 'PORT', 8787, 1, 65_535),
    host: env.HOST ?? '0.0.0.0',
    databaseUrl: required(env, 'DATABASE_URL'),
    dbPoolMax: int(env, 'DB_POOL_MAX', 10, 1, 50),
    authMode,
    firebaseProjectId: required(env, 'FIREBASE_PROJECT_ID'),
    logLevel: env.LOG_LEVEL ?? 'info',
    nodeEnv,
  };
}
