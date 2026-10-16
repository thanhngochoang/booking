// Staff CLI for provider verification (S21, plan Decision 11) until the S23.04 screen (#83):
//   npm run verifications -- list
//   npm run verifications -- show <uid>
//   npm run verifications -- approve <uid> --actor <uid>
//   npm run verifications -- reject <uid> <reason> ["note"] --actor <uid>
//   npm run verifications -- revoke <uid> "note" --actor <uid>
//   npm run verifications -- business-approve <uid> --actor <uid>
//   npm run verifications -- business-reject <uid> <reason> ["note"] --actor <uid>
// Same environment as tools/awards.ts (scripts/verifications-local.sh sets it for the emulators).
// Decisions go through the same reviewVerification use case as the callable, then the same
// notification hooks; `--actor` must be a user with the admin claim.

import { fileURLToPath } from 'node:url';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  BUSINESS_REJECT_REASONS,
  REJECT_REASONS,
  REVIEW_SLA_HOURS,
  reviewVerification,
  type VerificationChange,
  type VerificationDeps,
  type VerificationRecord,
} from '@photobooking/domain';
import { bucketNameFromEnv, formatWaiting, guardEnv, proofFileLines, proofModeFromEnv, type BucketLike } from './awards.js';

const USAGE =
  'usage: verifications list | show <uid> | approve <uid> | reject <uid> <reason> ["note"] | revoke <uid> "note" | ' +
  'business-approve <uid> | business-reject <uid> <reason> ["note"]  (decisions need --actor <uid>)';

export const HELP = `${USAGE}

Identity reject reasons: ${REJECT_REASONS.join(', ')} ("other" needs a note of 5-500 characters)
Business reject reasons: ${BUSINESS_REJECT_REASONS.join(', ')} ("other" needs a note)
revoke always needs a note (5-500 characters). list marks with ! what waited more than ${REVIEW_SLA_HOURS} h.

Environment: the same as \`npm run awards -- --help\` (GOOGLE_APPLICATION_CREDENTIALS and GCLOUD_PROJECT for a
real project, or the three emulator hosts); \`show\` signs (project) or downloads (emulator) the business photo.
--actor must be a user with the custom claim staffRole = admin.

scripts/verifications-local.sh sets all of this for the local emulators.`;

export type Command = 'list' | 'show' | 'approve' | 'reject' | 'revoke' | 'business-approve' | 'business-reject';

export interface ParsedArgs {
  readonly command: Command;
  readonly uid: string | null;
  readonly reason: string | null;
  readonly note: string | null;
  readonly actor: string | null;
}

const DECISIONS: Readonly<Record<string, { target: 'identity' | 'business'; action: 'approve' | 'reject' | 'revoke' }>> = {
  approve: { target: 'identity', action: 'approve' },
  reject: { target: 'identity', action: 'reject' },
  revoke: { target: 'identity', action: 'revoke' },
  'business-approve': { target: 'business', action: 'approve' },
  'business-reject': { target: 'business', action: 'reject' },
};

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
  if (command === 'list') return { command, uid: null, reason: null, note: null, actor };
  if (command !== undefined && (command === 'show' || Object.hasOwn(DECISIONS, command))) {
    const uid = rest[1];
    if (uid === undefined) throw new Error(`missing uid. ${USAGE}`);
    if (command === 'reject' || command === 'business-reject') {
      const reason = rest[2];
      if (reason === undefined) throw new Error(`${command} needs a reason. ${USAGE}`);
      return { command, uid, reason, note: rest[3] ?? null, actor };
    }
    if (command === 'revoke') {
      const note = rest[2];
      if (note === undefined) throw new Error(`revoke needs a note (5-500 characters). ${USAGE}`);
      return { command, uid, reason: null, note, actor };
    }
    return { command: command as Command, uid, reason: null, note: null, actor };
  }
  throw new Error(USAGE);
}

/** True when a record has waited longer than the review SLA (Decision 19). */
export function overdue(since: Date, now: Date): boolean {
  return now.getTime() - since.getTime() > REVIEW_SLA_HOURS * 3_600_000;
}

/** One `list` row: `!` (overdue) or a space, uid, target, kind, submitted time, waiting time. */
export function queueLine(r: VerificationRecord, target: 'identity' | 'business', now: Date): string {
  const at = target === 'business' ? r.business?.submittedAt : r.submittedAt;
  const since = new Date(at ?? r.updatedAt);
  const kind = target === 'business' ? (r.business?.kind ?? '?') : r.kind;
  return `${overdue(since, now) ? '!' : ' '} ${r.uid}  ${target}  ${kind}  ${since.toISOString()}  ${formatWaiting(since, now)}`;
}

export interface IdentitySummary {
  readonly legalName: string;
  readonly dob: string;
  readonly method: string;
  readonly provider: string;
}

export interface CliIo {
  print(line: string): void;
  now(): Date;
  /** The record, the identity summary (never the id number) and the `file` lines of the business photo. */
  show(uid: string): Promise<{ verification: VerificationRecord; identity: IdentitySummary | null; fileLines: string[] } | null>;
  /** The actor of a decision must pass it (the real CLI checks the admin claim). */
  isAdmin(uid: string): Promise<boolean>;
  /** The #138 hooks after the decision committed (the callable does the same). */
  notify(change: VerificationChange): Promise<void>;
}

const QUEUE_LIMIT = 50;

export async function runCli(argv: readonly string[], deps: VerificationDeps, io: CliIo): Promise<void> {
  const args = parseArgs(argv);
  if (args.command === 'list') {
    const now = io.now();
    for (const target of ['identity', 'business'] as const) {
      for (const r of await deps.store.queue(target, QUEUE_LIMIT)) io.print(queueLine(r, target, now));
    }
    return;
  }
  const uid = args.uid as string;
  if (args.command === 'show') {
    const found = await io.show(uid);
    if (found === null) throw new Error(`verification ${uid} not found`);
    io.print(JSON.stringify(found.verification, null, 2));
    if (found.identity !== null) {
      const i = found.identity;
      io.print(`identity: ${i.legalName}  dob ${i.dob}  ${i.method}/${i.provider}`);
    }
    for (const l of found.fileLines) io.print(l);
    return;
  }
  if (args.actor === null) throw new Error(`${args.command} needs --actor <uid> of an admin. ${USAGE}`);
  if (!(await io.isAdmin(args.actor))) throw new Error(`${args.actor} does not have the admin claim`);
  const decision = Object.hasOwn(DECISIONS, args.command) ? DECISIONS[args.command] : undefined;
  if (decision === undefined) throw new Error(USAGE);
  const change = await reviewVerification(
    deps,
    { uid: args.actor, isAdmin: true },
    {
      uid,
      target: decision.target,
      action: decision.action,
      ...(args.reason !== null ? { reason: args.reason } : {}),
      ...(args.note !== null ? { note: args.note } : {}),
    },
  );
  try {
    await io.notify(change);
  } catch (e) {
    io.print(`notification failed (decision saved): ${e instanceof Error ? e.message : String(e)}`);
  }
  const status = decision.target === 'business' ? change.after.business?.status : change.after.status;
  io.print(`${uid} ${decision.target} -> ${status ?? '?'}`);
}

async function main(): Promise<void> {
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    console.log(HELP);
    return;
  }
  guardEnv(process.env);
  const mode = proofModeFromEnv(process.env);
  // Emulator mode: livePushSender() then logs instead of sending FCM pushes (set before the live deps load).
  if (mode === 'emulator') process.env.FUNCTIONS_EMULATOR = 'true';
  const { getAuth } = await import('firebase-admin/auth');
  const { getStorage } = await import('firebase-admin/storage');
  const { notifyVerificationChange } = await import('@photobooking/domain');
  const { db } = await import('../src/infra/admin.js');
  const { liveVerificationDeps } = await import('../src/infra/live_verification.js');
  const { liveNotifyDeps } = await import('../src/infra/live_notification.js');
  const { VERIFICATIONS_COLLECTION, verificationFromFirestore, identityFromFirestore } = await import(
    '../src/infra/verification_firestore.js'
  );
  const firestore = db();
  const deps = liveVerificationDeps();
  const io: CliIo = {
    print: (l) => console.log(l),
    now: () => new Date(),
    show: async (uid) => {
      const [v, i] = await firestore.getAll(
        firestore.collection(VERIFICATIONS_COLLECTION).doc(uid),
        firestore.collection('users').doc(uid).collection('private').doc('identity'),
      );
      const verification = verificationFromFirestore(v?.data());
      if (verification === null) return null;
      const identity = identityFromFirestore(i?.data());
      const docPath = verification.business?.docPath ?? null;
      let bucket: BucketLike | undefined;
      const fileLines = await proofFileLines(mode, docPath === null ? [] : [docPath], {
        getBucket: () => (bucket ??= getStorage().bucket(bucketNameFromEnv(process.env)) as unknown as BucketLike),
        downloadDir: path.join(os.tmpdir(), 'verifications', path.basename(uid)),
        now: () => Date.now(),
      });
      return {
        verification,
        identity:
          identity === null
            ? null
            : { legalName: identity.legalName, dob: identity.dob, method: identity.method, provider: identity.provider },
        fileLines,
      };
    },
    isAdmin: async (uid) => (await getAuth().getUser(uid)).customClaims?.staffRole === 'admin',
    notify: (change) => notifyVerificationChange(liveNotifyDeps(), change),
  };
  await runCli(process.argv.slice(2), deps, io);
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e: unknown) => {
    console.error(e instanceof Error ? e.message : String(e));
    process.exit(1);
  });
}
