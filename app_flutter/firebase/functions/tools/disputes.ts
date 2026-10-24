// Staff CLI for disputes (S18, #142 Decision 10), until the S23.01 dashboard exists:
//   npm run disputes -- list [open|resolved]
//   npm run disputes -- show <disputeId>
//   npm run disputes -- resolve <disputeId> release|refund "<note>" --actor <uid>
//   npm run disputes -- resolve <disputeId> split <percent> "<note>" --actor <uid>
// `resolve` runs the same `resolveDispute` use case as the callable, then sends the refund with
// `dispatchDisputeRefund` (the fake rails: money moves only on FakePaymentGateway), so the outcome,
// ledger, thread message and the `onDisputeWrite` notices are the callable's. `--actor` must be a user
// with the claim staffRole = admin. Local emulators only: refuses unless FIRESTORE_EMULATOR_HOST and
// FIREBASE_AUTH_EMULATOR_HOST point at a local host, before anything is opened.

import { fileURLToPath } from 'node:url';
import {
  DISPUTE_STATUSES,
  dispatchDisputeRefund,
  formatVnd,
  isDomainError,
  resolveDispute,
  type DisputeDeps,
  type DisputeOutcomeKind,
  type DisputeStatus,
  type DisputeStore,
  type SupportStore,
} from '@photobooking/domain';
import { assertLocalEmulators } from '../seed/local_guard.js';

export const USAGE =
  'usage: disputes list [open|resolved] | show <id> | resolve <id> release|refund "<note>" --actor <uid> | resolve <id> split <percent> "<note>" --actor <uid>';

export const HELP = `${USAGE}
(local emulators only)

  list [open|resolved]   disputes with that status (default open), oldest first: id, opened at, subject, amount held, status
  show <id>              the dispute, its evidence paths (private Storage files) and the last 30 thread messages
  resolve <id> ...       release (0% back), refund (100% back) or split <1-99>% back to the customer, of the
                         amount the dispute holds; the note (5-500 characters) goes to both parties

Environment:
  FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST
                         must point at local emulators (scripts/backend-local.sh); anything else is refused
  GCLOUD_PROJECT         project id of the emulators
  PAYOUT_ACCOUNT_KEY     optional; the emulator key from .secret.local is used when it is unset
--actor must be a user with the custom claim staffRole = admin (seed: seed-staff-admin).`;

/** The CLI's deps: the dispute use cases' plus the thread messages of `show`. */
export type DisputesCliDeps = DisputeDeps & { readonly store: DisputeStore & Pick<SupportStore, 'listMessages'> };

export type ParsedArgs =
  | { readonly command: 'list'; readonly status: DisputeStatus }
  | { readonly command: 'show'; readonly disputeId: string }
  | {
      readonly command: 'resolve';
      readonly disputeId: string;
      readonly outcome: DisputeOutcomeKind;
      readonly refundPercent: number | null;
      readonly note: string;
      readonly actor: string | null;
    };

const SHOW_MESSAGES = 30;
const LIST_LIMIT = 50;

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
  const [command, ...args] = rest;
  if (command === 'list') {
    const status = args[0] ?? 'open';
    if (args.length > 1 || !(DISPUTE_STATUSES as readonly string[]).includes(status)) throw new Error(USAGE);
    return { command, status: status as DisputeStatus };
  }
  if (command === 'show') {
    const disputeId = args[0];
    if (disputeId === undefined) throw new Error(`missing dispute id. ${USAGE}`);
    if (args.length > 1) throw new Error(USAGE);
    return { command, disputeId };
  }
  if (command === 'resolve') {
    const [disputeId, outcome, ...tail] = args;
    if (disputeId === undefined) throw new Error(`missing dispute id. ${USAGE}`);
    if (outcome !== 'release' && outcome !== 'refund' && outcome !== 'split') {
      throw new Error(`resolve needs release, refund or split. ${USAGE}`);
    }
    let refundPercent: number | null = null;
    if (outcome === 'split') {
      const raw = tail.shift();
      if (raw === undefined || !/^\d+$/.test(raw) || Number(raw) < 1 || Number(raw) > 99) {
        throw new Error(`split needs a percent 1-99 (refunded to the customer). ${USAGE}`);
      }
      refundPercent = Number(raw);
    }
    if (tail.length > 1) throw new Error(`${outcome} takes no percent, only a note. ${USAGE}`);
    const note = tail[0];
    if (note === undefined) throw new Error(`resolve needs a note (5-500 characters). ${USAGE}`);
    return { command, disputeId, outcome, refundPercent, note, actor };
  }
  throw new Error(USAGE);
}

export interface DisputesCliIo {
  print(line: string): void;
  /** Opened only after the guard and the actor check passed (the live wiring starts the Admin SDK). */
  deps(): Promise<DisputesCliDeps>;
  /** The real CLI reads the Auth user's custom claims. */
  isAdmin(uid: string): Promise<boolean>;
}

/** Returns the exit code. Refuses (throws) before opening anything when the hosts are not local. */
export async function runCli(
  argv: readonly string[],
  env: Readonly<Record<string, string | undefined>>,
  io: DisputesCliIo,
): Promise<number> {
  if (argv.includes('--help') || argv.includes('-h')) {
    io.print(HELP);
    return 0;
  }
  const args = parseArgs(argv);
  assertLocalEmulators({ allowAnyProject: true }, env as NodeJS.ProcessEnv);
  if (args.command === 'resolve') {
    if (args.actor === null) throw new Error(`resolve needs --actor <uid> of an admin. ${USAGE}`);
    if (!(await io.isAdmin(args.actor))) throw new Error(`${args.actor} does not have the admin claim`);
  }
  const deps = await io.deps();
  try {
    if (args.command === 'list') return await list(deps, args.status, io);
    if (args.command === 'show') return await show(deps, args.disputeId, io);
    return await resolve(deps, args, io);
  } catch (e) {
    if (!isDomainError(e)) throw e;
    io.print(`refused: ${e.code}`);
    return 1;
  }
}

async function list(deps: DisputesCliDeps, status: DisputeStatus, io: DisputesCliIo): Promise<number> {
  const disputes = await deps.store.listByStatus(status, LIST_LIMIT);
  if (disputes.length === 0) io.print(`no ${status} disputes`);
  for (const d of disputes) {
    io.print(`${d.id}  ${d.createdAt}  ${d.subjectType}  ${d.snapshot.title}  held ${formatVnd(d.amountHeld)}  ${d.status}`);
  }
  return 0;
}

async function show(deps: DisputesCliDeps, disputeId: string, io: DisputesCliIo): Promise<number> {
  const d = await deps.store.runTransaction((tx) => tx.getDispute(disputeId));
  if (d === null) {
    io.print(`no dispute ${disputeId}`);
    return 1;
  }
  io.print(JSON.stringify(d, null, 2));
  for (const path of d.evidencePaths) io.print(`evidence: ${path}`);
  // listMessages answers newest first; print the conversation in reading order.
  const messages = [...(await deps.store.listMessages(d.threadId, SHOW_MESSAGES))].reverse();
  io.print(`thread ${d.threadId} (last ${messages.length} messages):`);
  for (const m of messages) io.print(`[${m.createdAt}] ${m.senderRole} (${m.senderName}): ${m.body}`);
  return 0;
}

async function resolve(
  deps: DisputesCliDeps,
  args: Extract<ParsedArgs, { command: 'resolve' }>,
  io: DisputesCliIo,
): Promise<number> {
  const { dispute, refund } = await resolveDispute(deps, args.actor as string, {
    disputeId: args.disputeId,
    outcome: args.outcome,
    ...(args.refundPercent !== null ? { refundPercent: args.refundPercent } : {}),
    note: args.note,
  });
  const o = dispute.outcome;
  io.print(
    `${dispute.id} -> resolved ${args.outcome}: refund ${formatVnd(o?.refundAmount ?? 0)}, release ${formatVnd(o?.releaseAmount ?? 0)}`,
  );
  if (refund === null) return 0;
  // The decision is committed; the send follows the callable's rule (a throw stays pending for V2's re-send).
  const payment = await deps.store.runTransaction((tx) => tx.getPayment(dispute.paymentId));
  if (payment === null) {
    io.print(`refund ${refund.id}: payment ${dispute.paymentId} not found, not sent`);
    return 1;
  }
  const sent = await dispatchDisputeRefund(deps, payment, refund);
  io.print(`refund ${sent.id}: ${sent.status}`);
  return 0;
}

async function main(): Promise<void> {
  const io: DisputesCliIo = {
    print: (l) => console.log(l),
    deps: async () => {
      const { liveDisputeDeps } = await import('../src/infra/live_dispute.js');
      const { lazyAccountCipher } = await import('../src/infra/account_cipher.js');
      const { emulatorPayoutKey } = await import('../seed/emulator_key.js');
      const key = process.env.PAYOUT_ACCOUNT_KEY;
      // Emulators only (guarded above): the committed emulator key unless one is given; read on first use.
      return { ...liveDisputeDeps(), cipher: lazyAccountCipher(() => (key !== undefined && key !== '' ? key : emulatorPayoutKey())) };
    },
    isAdmin: async (uid) => {
      const { auth } = await import('../src/infra/admin.js');
      return (await auth().getUser(uid)).customClaims?.staffRole === 'admin';
    },
  };
  process.exitCode = await runCli(process.argv.slice(2), process.env, io);
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e: unknown) => {
    console.error(e instanceof Error ? e.message : String(e));
    process.exit(1);
  });
}
