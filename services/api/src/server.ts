import { buildApp } from './app.js';
import { EmulatorVerifier, firebaseVerifier } from './auth/identity.js';
import { loadConfig } from './config.js';
import { createDb } from './db/database.js';

const config = loadConfig();
const db = createDb(config.databaseUrl, config.dbPoolMax);
const verifier =
  config.authMode === 'firebase'
    ? firebaseVerifier(config.firebaseProjectId)
    : new EmulatorVerifier({ projectId: config.firebaseProjectId });
const app = await buildApp({ db, verifier, logLevel: config.logLevel });

async function shutdown(): Promise<void> {
  await app.close();
  await db.destroy();
}
for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.once(signal, () => {
    void shutdown().then(() => process.exit(0));
  });
}

await app.listen({ port: config.port, host: config.host });
