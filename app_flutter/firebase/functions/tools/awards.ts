// Staff CLI for award review (plan B1 Decision 7):
//   npm run awards -- list
//   npm run awards -- show <awardId>
//   npm run awards -- approve <awardId> --actor <uid>
//   npm run awards -- needs-info|reject|revoke <awardId> "<note>" --actor <uid>
// Uses the Admin SDK. Environment (see HELP below): GOOGLE_APPLICATION_CREDENTIALS (a service
// account key; `show` needs it to sign URLs), STORAGE_BUCKET for `show`, or the emulators through
// FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST.
// Decisions go through the same reviewAward use case as the callable; `--actor` must be a user
// with the admin claim.

import { fileURLToPath } from 'node:url';
import * as os from 'node:os';
import * as path from 'node:path';
import { mkdir } from 'node:fs/promises';
import { reviewAward, type Award, type AwardDeps, type AwardProof, type ReviewAction } from '@photobooking/domain';
import { assertLocalEmulators, LOCAL_HOST } from '../seed/local_guard.js';

export const HELP = `${'usage: awards list | show <id> | approve <id> --actor <uid> | needs-info|reject|revoke <id> "<note>" --actor <uid>'}

Environment:
  GOOGLE_APPLICATION_CREDENTIALS  path to a service account key (real project; \`show\` needs it to sign URLs)
  GCLOUD_PROJECT                  project id
  STORAGE_BUCKET                  bucket of the proof files (or FIREBASE_STORAGE_BUCKET); required by \`show\`
  FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST
                                  use these instead of credentials to work against the emulators
  FIREBASE_STORAGE_EMULATOR_HOST  with the emulators: show downloads proof files to $TMPDIR/awards/<id>/ (no key needed)
--actor must be a user with the custom claim staffRole = admin.

scripts/awards-local.sh sets all of this for the local emulators.`;

const EMULATOR_HOST_VARS = ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST', 'FIREBASE_STORAGE_EMULATOR_HOST'] as const;

/** Refuses a mixed environment: once any emulator host is set, all of them must be local. */
export function guardEnv(env: Readonly<Record<string, string | undefined>>): void {
  if (!EMULATOR_HOST_VARS.some((k) => env[k] !== undefined && env[k] !== '')) return;
  assertLocalEmulators({ allowAnyProject: true }, env as NodeJS.ProcessEnv);
  const storage = env.FIREBASE_STORAGE_EMULATOR_HOST;
  if (storage !== undefined && storage !== '' && !LOCAL_HOST.test(storage)) {
    throw new Error(`Refusing to run: FIREBASE_STORAGE_EMULATOR_HOST must point at a local emulator (got ${storage}).`);
  }
}

/** 'emulator' when FIREBASE_STORAGE_EMULATOR_HOST is set, else 'project'. */
export type ProofMode = 'emulator' | 'project';

export function proofModeFromEnv(env: Readonly<Record<string, string | undefined>>): ProofMode {
  const host = env.FIREBASE_STORAGE_EMULATOR_HOST;
  return host !== undefined && host !== '' ? 'emulator' : 'project';
}

/** "waiting 3d 4h" / "waiting 5h" / "waiting 12m", from createdAt to now (never negative). */
export function formatWaiting(createdAt: Date, now: Date): string {
  const minutes = Math.max(0, Math.floor((now.getTime() - createdAt.getTime()) / 60_000));
  const days = Math.floor(minutes / 1440);
  const hours = Math.floor((minutes % 1440) / 60);
  if (days > 0) return `waiting ${days}d ${hours}h`;
  if (hours > 0) return `waiting ${hours}h`;
  return `waiting ${minutes}m`;
}

/** The `file` lines of `show`: signed URLs against a project, local downloads on the emulators. */
export async function proofFileLines(
  mode: ProofMode,
  files: readonly string[],
  deps: { sign(path: string): Promise<string>; download(path: string): Promise<string> },
): Promise<string[]> {
  const lines: string[] = [];
  for (const f of files) {
    lines.push(mode === 'emulator' ? `file: ${await deps.download(f)}` : `file (15 min): ${await deps.sign(f)}`);
  }
  return lines;
}

/** Bucket that holds the proof files; `show` cannot guess it outside Cloud Functions. */
export function bucketNameFromEnv(env: Readonly<Record<string, string | undefined>>): string {
  const name = env.STORAGE_BUCKET ?? env.FIREBASE_STORAGE_BUCKET;
  if (name === undefined || name === '') {
    throw new Error('show needs the proof bucket: set STORAGE_BUCKET (or FIREBASE_STORAGE_BUCKET), e.g. my-project.firebasestorage.app');
  }
  return name;
}

export type Command = 'list' | 'show' | 'approve' | 'needs-info' | 'reject' | 'revoke';

export interface ParsedArgs {
  readonly command: Command;
  readonly awardId: string | null;
  readonly note: string | null;
  readonly actor: string | null;
}

const USAGE =
  'usage: awards list | show <id> | approve <id> --actor <uid> | needs-info|reject|revoke <id> "<note>" --actor <uid>';

const ACTIONS: Readonly<Record<string, ReviewAction>> = {
  approve: 'approve',
  'needs-info': 'needs_info',
  reject: 'reject',
  revoke: 'revoke',
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
  if (command === 'list') return { command, awardId: null, note: null, actor };
  if (command === 'show' || command === 'approve' || command === 'needs-info' || command === 'reject' || command === 'revoke') {
    const awardId = rest[1];
    if (awardId === undefined) throw new Error(`missing award id. ${USAGE}`);
    let note: string | null = null;
    if (command === 'needs-info' || command === 'reject' || command === 'revoke') {
      note = rest[2] ?? null;
      if (note === null) throw new Error(`${command} needs a note (5-500 characters). ${USAGE}`);
    }
    return { command, awardId, note, actor };
  }
  throw new Error(USAGE);
}

export interface CliIo {
  print(line: string): void;
  listPending(): Promise<Award[]>;
  /** Project mode fills `urls` (signed, 15 min); emulator mode fills `files` (local paths). */
  show(awardId: string): Promise<{ award: Award; proof: AwardProof | null; urls: string[]; files: string[] } | null>;
  now(): Date;
  /** The actor of a decision must pass it (the real CLI checks the admin claim). */
  isAdmin(uid: string): Promise<boolean>;
}

export async function runCli(argv: readonly string[], deps: AwardDeps, io: CliIo): Promise<void> {
  const args = parseArgs(argv);
  if (args.command === 'list') {
    const pending = (await io.listPending()).sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
    const now = io.now();
    for (const a of pending) {
      io.print(
        `${a.id}  ${a.createdAt.toISOString()}  ${formatWaiting(a.createdAt, now)}  ${a.photographerId}  ${a.result}  ${a.year}  ${a.competition}`,
      );
    }
    return;
  }
  const awardId = args.awardId as string;
  if (args.command === 'show') {
    const found = await io.show(awardId);
    if (found === null) throw new Error(`award ${awardId} not found`);
    io.print(JSON.stringify(found.award, null, 2));
    for (const l of found.proof?.links ?? []) io.print(`link: ${l}`);
    for (const u of found.urls) io.print(`file (15 min): ${u}`);
    for (const f of found.files) io.print(`file: ${f}`);
    return;
  }
  if (args.actor === null) throw new Error(`${args.command} needs --actor <uid> of an admin. ${USAGE}`);
  if (!(await io.isAdmin(args.actor))) {
    throw new Error(`${args.actor} does not have the admin claim`);
  }
  const action = ACTIONS[args.command] as ReviewAction;
  const { status } = await reviewAward(deps, args.actor, true, {
    awardId,
    action,
    ...(args.note !== null ? { note: args.note } : {}),
  });
  io.print(`${awardId} -> ${status}`);
}

async function main(): Promise<void> {
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    console.log(HELP);
    return;
  }
  guardEnv(process.env);
  const mode = proofModeFromEnv(process.env);
  const { getAuth } = await import('firebase-admin/auth');
  const { getStorage } = await import('firebase-admin/storage');
  const { db } = await import('../src/infra/admin.js');
  const { liveAwardDeps } = await import('../src/infra/live_award.js');
  const { awardFromDoc, proofFromDoc, AWARDS_COLLECTION, AWARD_PROOFS_COLLECTION } = await import(
    '../src/infra/award_firestore.js'
  );
  const firestore = db();
  const deps = liveAwardDeps();
  const io: CliIo = {
    print: (l) => console.log(l),
    listPending: async () => {
      const snap = await firestore.collection(AWARDS_COLLECTION).where('status', '==', 'pending').orderBy('createdAt').get();
      return snap.docs.map((s) => awardFromDoc(s.id, s.data()));
    },
    show: async (id) => {
      const [a, p] = await firestore.getAll(
        firestore.collection(AWARDS_COLLECTION).doc(id),
        firestore.collection(AWARD_PROOFS_COLLECTION).doc(id),
      );
      const ad = a?.data();
      if (ad === undefined) return null;
      const proof = p?.data() === undefined ? null : proofFromDoc(id, p.data() ?? {});
      const proofFiles = proof?.files ?? [];
      // Only resolve the bucket when there is something to fetch (the seed's proof has links only).
      const bucket = proofFiles.length > 0 ? getStorage().bucket(bucketNameFromEnv(process.env)) : null;
      const urls: string[] = [];
      const files: string[] = [];
      await proofFileLines(mode, proofFiles, {
        sign: async (f) => {
          const [url] = await (bucket as NonNullable<typeof bucket>)
            .file(f)
            .getSignedUrl({ action: 'read', expires: Date.now() + 15 * 60 * 1000 });
          urls.push(url);
          return url;
        },
        download: async (f) => {
          const dir = path.join(os.tmpdir(), 'awards', id);
          await mkdir(dir, { recursive: true });
          const destination = path.join(dir, path.basename(f));
          await (bucket as NonNullable<typeof bucket>).file(f).download({ destination });
          files.push(destination);
          return destination;
        },
      });
      return { award: awardFromDoc(id, ad), proof, urls, files };
    },
    now: () => new Date(),
    isAdmin: async (uid) => (await getAuth().getUser(uid)).customClaims?.staffRole === 'admin',
  };
  await runCli(process.argv.slice(2), deps, io);
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e: unknown) => {
    console.error(e instanceof Error ? e.message : String(e));
    process.exit(1);
  });
}
