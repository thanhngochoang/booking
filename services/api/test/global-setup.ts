import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql';

import { migrate } from '../src/db/migrate.js';

let container: StartedPostgreSqlContainer | undefined;

export async function setup(): Promise<void> {
  const given = process.env.TEST_DATABASE_URL;
  if (given) {
    if (!new URL(given).pathname.endsWith('_test')) {
      throw new Error('TEST_DATABASE_URL must name a database ending in _test (tests truncate tables)');
    }
    await migrate(given, 'up');
    return;
  }
  container = await new PostgreSqlContainer('postgres:16.4-alpine')
    .withDatabase('nag_test')
    .withUsername('nag')
    .withPassword('nag_test_only')
    .start();
  process.env.TEST_DATABASE_URL = container.getConnectionUri();
  await migrate(process.env.TEST_DATABASE_URL, 'up');
}

export async function teardown(): Promise<void> {
  await container?.stop();
}
