import { SEED_PASSWORD } from './fixtures.js';
import { callCallable, signIn } from './emulator_client.js';

// Manual check: npm run try:contact -- <seed email> <bookingId> <call|zalo|whatsapp>
// Needs the three emulator hosts exported (seed/README.md). The dev project id that
// scripts/backend-local.sh uses need not be `demo-*`; the hosts are still checked.
const [email, bookingId, channel] = process.argv.slice(2);
if (email === undefined || bookingId === undefined || channel === undefined) {
  console.error('Usage: npm run try:contact -- <seed email> <bookingId> <call|zalo|whatsapp>');
  process.exit(2);
}
const token = await signIn(email, SEED_PASSWORD);
const res = await callCallable('getContactLink', { bookingId, channel }, token, { allowAnyProject: true });
console.log(res.status, res.text);
