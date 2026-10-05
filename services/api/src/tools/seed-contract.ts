import { createDb } from '../db/database.js';
import { seedContractWorld } from './contract-world.js';

const url = process.env.DATABASE_URL;
if (!url) {
  console.error('DATABASE_URL is required');
  process.exit(2);
}
if (process.env.NODE_ENV === 'production') {
  console.error('refusing to seed contract fixtures with NODE_ENV=production');
  process.exit(2);
}
const db = createDb(url, 1);
await seedContractWorld(db, new Date());
await db.destroy();
console.log('contract world seeded');
