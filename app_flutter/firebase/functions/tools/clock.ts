// Runs one scheduled clock against the local emulators, which never fire schedules (S17 Decision 11):
//   npm run clock -- events     # handleEventClock once (closes, completes, refunds, event_soon reminders)
//   npm run clock -- bookings   # handleBookingClock once (booking sweeps, shoot reminders, verification nudges, studio sweeps, Chụp ngay timers)
// Emulators only: refuses unless FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST are local
// (any project id, like the dev seed). Push is only logged, never sent through FCM.

import { fileURLToPath } from 'node:url';
import { assertLocalEmulators } from '../seed/local_guard.js';

export const USAGE = 'usage: npm run clock -- events | bookings | payments   (local emulators only)';

export interface ClockIo {
  print(line: string): void;
  events(): Promise<object>;
  bookings(): Promise<object>;
  payments(): Promise<object>;
}

const counts = (r: object): string => Object.entries(r).map(([k, v]) => `${k}=${String(v)}`).join(' ');

/** Returns the exit code. Refuses (throws) before running anything when the hosts are not local. */
export async function runClock(
  argv: readonly string[],
  env: NodeJS.ProcessEnv,
  io: ClockIo,
): Promise<number> {
  const command = argv[0];
  if (command !== 'events' && command !== 'bookings' && command !== 'payments') {
    io.print(USAGE);
    return command === '--help' || command === '-h' ? 0 : 2;
  }
  assertLocalEmulators({ allowAnyProject: true }, env);
  if (command === 'events') io.print(`eventClock: ${counts(await io.events())}`);
  else if (command === 'bookings') io.print(`bookingClock: ${counts(await io.bookings())}`);
  else io.print(`paymentClock: ${counts(await io.payments())}`);
  return 0;
}

async function main(): Promise<void> {
  // The live wiring is imported only after the guard passed (it opens the Admin SDK).
  const io: ClockIo = {
    print: (l) => console.log(l),
    events: async () => {
      const { handleEventClock } = await import('../src/scheduled/event_clock.js');
      return handleEventClock(undefined, { notify: await emulatorNotifyDeps() });
    },
    bookings: async () => {
      const { handleBookingClock, liveReminderDeps } = await import('../src/scheduled/booking_clock.js');
      const { liveVerificationDeps } = await import('../src/infra/live_verification.js');
      const { liveStudioBookingDeps, liveStudioDeps } = await import('../src/infra/live_studio.js');
      const { liveInstantDeps } = await import('../src/infra/live_instant.js');
      const notify = await emulatorNotifyDeps();
      return handleBookingClock(undefined, { ...liveReminderDeps(), notify }, {
        verification: { deps: liveVerificationDeps(), notify },
        studio: { bookings: liveStudioBookingDeps(), members: liveStudioDeps(), notify },
        instant: { ...liveInstantDeps(), push: notify.push },
      });
    },
    payments: async () => {
      const { handlePaymentClock } = await import('../src/scheduled/payment_clock.js');
      return handlePaymentClock();
    },
  };
  process.exitCode = await runClock(process.argv.slice(2), process.env, io);
}

/** The live notification wiring with push logged instead of sent (this tool runs outside the Functions emulator). */
async function emulatorNotifyDeps() {
  const { liveNotifyDeps } = await import('../src/infra/live_notification.js');
  const { LoggingPushSender } = await import('../src/infra/fcm_push.js');
  return { ...liveNotifyDeps(), push: new LoggingPushSender() };
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e: unknown) => {
    console.error(e instanceof Error ? e.message : String(e));
    process.exit(1);
  });
}
