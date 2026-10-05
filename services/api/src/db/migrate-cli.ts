import { migrate } from './migrate.js';

const [direction, countArg] = process.argv.slice(2);
if (direction !== 'up' && direction !== 'down') {
  console.error('usage: migrate-cli up|down [n|all]');
  process.exit(2);
}
const url = process.env.DATABASE_URL;
if (!url) {
  console.error('DATABASE_URL is required');
  process.exit(2);
}
const count = countArg === 'all' ? Infinity : countArg ? Number(countArg) : undefined;
await migrate(url, direction, { count, log: (m) => console.log(m) });
console.log(`migrations ${direction}: done`);
