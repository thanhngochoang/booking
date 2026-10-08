// Staff CLI for payouts (plan 10b Decision 10), same pattern as the awards CLI:
//   npm run payouts -- due
//   npm run payouts -- show <payoutId>
//   npm run payouts -- create <payeeId> --actor <uid>
//   npm run payouts -- approve <payoutId> --actor <uid>
//   npm run payouts -- execute <payoutId> --actor <uid>
//   npm run payouts -- hold <payoutId> "<reason>" --actor <uid>
//   npm run payouts -- resume <payoutId> --actor <uid>
//   npm run payouts -- run-daily --actor <uid>
// Uses the Admin SDK and the same domain use cases as any future staff screen and the daily
// `createPayouts` job. There is no real bank adapter: `execute` and `run-daily` work only against
// the fake gateway (emulators, or PAYOUTS_MODE=fake in the dev project of .firebaserc only).

import { fileURLToPath } from 'node:url';
import {
  approvePayout,
  createPayout,
  executePayout,
  holdPayout,
  isDomainError,
  resumePayout,
  runDailyPayouts,
  type DailyPayoutReport,
  type Payout,
  type PayoutDeps,
  type PayoutStatus,
  type StaffActor,
} from '@photobooking/domain';

const USAGE =
  'usage: payouts due | show <payoutId> | create <payeeId> --actor <uid> | approve <payoutId> --actor <uid> | execute <payoutId> --actor <uid> | hold <payoutId> "<reason>" --actor <uid> | resume <payoutId> --actor <uid> | run-daily --actor <uid>';

export const HELP = `${USAGE}

Environment:
  GOOGLE_APPLICATION_CREDENTIALS  path to a service account key (real project)
  GCLOUD_PROJECT                  project id
  PAYOUT_ACCOUNT_KEY              base64 key of the account cipher (32 bytes); with FIRESTORE_EMULATOR_HOST
                                  the emulator key from .secret.local is used when it is unset
  PAYOUTS_MODE=fake               allow \`execute\` and \`run-daily\` against the fake gateway, only when GCLOUD_PROJECT is the dev
                                  project of .firebaserc (emulators allow it by default; any other project: refused)
  FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST
                                  use these instead of credentials to work against the emulators
--actor must be a user with the custom claim staffRole = admin. \`show\` prints the account masked (•••• 6789).
\`approve\` sends a payout waiting for staff (needs_approval: the first to an account, or a holder name
to compare) to pending. \`run-daily\` does what the daily createPayouts job does (create a payout per
due payee, send every pending one) and prints its report; a failed item is printed by id and code.`;

export type Command = 'due' | 'show' | 'create' | 'approve' | 'execute' | 'hold' | 'resume' | 'run-daily';

/** Payouts `due` lists as `open:` (waiting for staff or the bank), oldest first. */
export const OPEN_PAYOUT_STATUSES = ['needs_approval', 'pending', 'on_hold', 'processing'] as const satisfies readonly PayoutStatus[];

export interface ParsedArgs {
  readonly command: Command;
  readonly target: string | null;
  readonly reason: string | null;
  readonly actor: string | null;
}

export function parseArgs(argv: readonly string[]): ParsedArgs {
  const rest: string[] = [];
  let actor: string | null = null;
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i] as string;
    if (a === '--actor') {
      actor = argv[i + 1] ?? null;
      i += 1;
      if (actor === null) throw new Error(`--actor needs a uid. ${USAGE}`);
    } else {
      rest.push(a);
    }
  }
  const command = rest[0];
  if (command === 'due' || command === 'run-daily') return { command, target: null, reason: null, actor };
  if (
    command === 'show' ||
    command === 'create' ||
    command === 'approve' ||
    command === 'execute' ||
    command === 'hold' ||
    command === 'resume'
  ) {
    const target = rest[1];
    if (target === undefined) throw new Error(`missing ${command === 'create' ? 'payee' : 'payout'} id. ${USAGE}`);
    let reason: string | null = null;
    if (command === 'hold') {
      reason = rest[2] ?? null;
      if (reason === null) throw new Error(`hold needs a reason (5-200 characters). ${USAGE}`);
    }
    return { command, target, reason, actor };
  }
  throw new Error(USAGE);
}

export interface CliIo {
  print(line: string): void;
  /** The actor of a change must pass it (the real CLI checks the admin claim). */
  isAdmin(uid: string): Promise<boolean>;
  /** Payouts in these statuses (`OPEN_PAYOUT_STATUSES`), oldest first. */
  listOpenPayouts(statuses: readonly PayoutStatus[]): Promise<Payout[]>;
}

/**
 * `fake` only when the fake gateway may run: against the emulators, or when `PAYOUTS_MODE=fake`
 * AND the project id (GCLOUD_PROJECT) equals the dev project from `.firebaserc` (alias `dev`,
 * passed in as `devProjectId`). Never against any other project, whatever the variable says.
 */
export function cliPayoutsMode(
  env: Readonly<Record<string, string | undefined>>,
  devProjectId: string | null = null,
): 'fake' | 'off' {
  const emulator = (env.FIRESTORE_EMULATOR_HOST ?? '') !== '' || env.FUNCTIONS_EMULATOR === 'true';
  if (emulator) return 'fake';
  const project = env.GCLOUD_PROJECT ?? '';
  return env.PAYOUTS_MODE === 'fake' && devProjectId !== null && devProjectId !== '' && project === devProjectId
    ? 'fake'
    : 'off';
}

/** The dev project id from `.firebaserc` (alias `dev`), or null when it cannot be read. */
export function devProjectFromFirebaserc(json: string): string | null {
  try {
    const dev = (JSON.parse(json) as { projects?: Record<string, unknown> }).projects?.dev;
    return typeof dev === 'string' && dev !== '' ? dev : null;
  } catch {
    return null;
  }
}

const money = (n: number): string => `${n.toLocaleString('en-US')} VND`;

function line(p: Payout): string {
  return `${p.id}  ${p.status}  ${p.createdAt}  ${p.payeeId}  ${money(p.amount)}  ${p.items.length} payment(s)`;
}

const reportLine = (r: DailyPayoutReport): string =>
  (Object.keys(r) as (keyof DailyPayoutReport)[]).map((k) => `${k}=${r[k]}`).join(' ');

/** The domain code or the error's class name: never its message (it could carry account data). */
const codeOf = (e: unknown): string => (isDomainError(e) ? e.code : e instanceof Error ? e.name : 'unknown');

export async function runCli(
  argv: readonly string[],
  deps: PayoutDeps,
  io: CliIo,
  mode: 'fake' | 'off',
): Promise<void> {
  const args = parseArgs(argv);

  if (args.command === 'due') {
    const due = await deps.store.listDuePayees();
    if (due.length === 0) io.print('no payee has released money without a payout');
    for (const d of due) {
      io.print(`${d.payeeId}  ${money(d.amount)}  ${d.hasAccount ? 'account' : 'NO ACCOUNT (cannot create a payout)'}`);
    }
    for (const p of await io.listOpenPayouts(OPEN_PAYOUT_STATUSES)) io.print(`open: ${line(p)}`);
    return;
  }

  const target = args.target as string;
  if (args.command === 'show') {
    const found = await deps.store.runTransaction(async (tx) => {
      const payout = await tx.getPayout(target);
      if (payout === null) return null;
      return { payout, account: await tx.getAccount(payout.payeeId, payout.accountId) };
    });
    if (found === null) throw new Error(`payout ${target} not found`);
    io.print(JSON.stringify(found.payout, null, 2));
    // The masked view only: never the stored number, not even decrypted.
    io.print(
      found.account === null
        ? 'account: (missing)'
        : `account: ${found.account.bankCode} •••• ${found.account.accountLast4} ${found.account.holderName}`,
    );
    return;
  }

  if (args.actor === null) throw new Error(`${args.command} needs --actor <uid> of an admin. ${USAGE}`);
  if (!(await io.isAdmin(args.actor))) throw new Error(`${args.actor} does not have the admin claim`);
  const actor: StaffActor = { uid: args.actor, isAdmin: true };

  switch (args.command) {
    case 'run-daily': {
      if (mode !== 'fake') {
        throw new Error('run-daily is refused: no real bank adapter exists. Use the emulators, or PAYOUTS_MODE=fake with GCLOUD_PROJECT set to the dev project.');
      }
      const report = await runDailyPayouts(deps, (id, step, e) => io.print(`error: ${id} ${step} ${codeOf(e)}`));
      io.print(reportLine(report));
      return;
    }
    case 'approve': {
      const p = await approvePayout(deps, actor, target);
      io.print(`${p.id} -> ${p.status} (approved by ${actor.uid})`);
      return;
    }
    case 'create': {
      const p = await createPayout(deps, actor, target);
      io.print(`${p.id} created: ${money(p.amount)} for ${p.payeeId}, ${p.items.length} payment(s)`);
      return;
    }
    case 'execute': {
      if (mode !== 'fake') {
        throw new Error('execute is refused: no real bank adapter exists. Use the emulators, or PAYOUTS_MODE=fake with GCLOUD_PROJECT set to the dev project.');
      }
      const p = await executePayout(deps, actor, target);
      io.print(`${p.id} -> ${p.status}${p.reference ? ` (${p.reference})` : ''}${p.failureReason ? ` (${p.failureReason})` : ''}`);
      return;
    }
    case 'hold': {
      const p = await holdPayout(deps, actor, target, args.reason as string);
      io.print(`${p.id} -> ${p.status}`);
      return;
    }
    case 'resume': {
      const p = await resumePayout(deps, actor, target);
      io.print(`${p.id} -> ${p.status}`);
      return;
    }
  }
}

async function main(): Promise<void> {
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    console.log(HELP);
    return;
  }
  const { getAuth } = await import('firebase-admin/auth');
  const { db } = await import('../src/infra/admin.js');
  const { livePayoutDeps, payoutGateway } = await import('../src/infra/live_payout.js');
  const { payoutFromFirestore, PAYOUTS_COLLECTION } = await import('../src/infra/payout_firestore.js');
  const { readFileSync } = await import('node:fs');
  let devProject: string | null = null;
  try {
    devProject = devProjectFromFirebaserc(
      readFileSync(fileURLToPath(new URL('../../.firebaserc', import.meta.url)), 'utf8'),
    );
  } catch {
    devProject = null;
  }
  const mode = cliPayoutsMode(process.env, devProject);
  let key = process.env.PAYOUT_ACCOUNT_KEY;
  if ((key === undefined || key === '') && (process.env.FIRESTORE_EMULATOR_HOST ?? '') !== '') {
    key = (await import('../seed/emulator_key.js')).emulatorPayoutKey();
  }
  if (key === undefined || key === '') throw new Error('set PAYOUT_ACCOUNT_KEY (base64, 32 bytes)');
  const deps = livePayoutDeps(key, payoutGateway(mode));
  const firestore = db();
  const io: CliIo = {
    print: (l) => console.log(l),
    isAdmin: async (uid) => (await getAuth().getUser(uid)).customClaims?.staffRole === 'admin',
    listOpenPayouts: async (statuses) => {
      const snap = await firestore
        .collection(PAYOUTS_COLLECTION)
        .where('status', 'in', [...statuses])
        .orderBy('createdAt')
        .get();
      return snap.docs.flatMap((d) => payoutFromFirestore(d.id, d.data()) ?? []);
    },
  };
  await runCli(process.argv.slice(2), deps, io, mode);
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e: unknown) => {
    console.error(e instanceof Error ? e.message : String(e));
    process.exit(1);
  });
}
