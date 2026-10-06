// Staff CLI for award review (plan B1 Decision 7):
//   npm run awards -- list
//   npm run awards -- show <awardId>
//   npm run awards -- approve <awardId> --actor <uid>
//   npm run awards -- needs-info|reject|revoke <awardId> "<note>" --actor <uid>
// Uses the Admin SDK (GOOGLE_APPLICATION_CREDENTIALS, or the emulators through *_EMULATOR_HOST).
// Decisions go through the same reviewAward use case as the callable; `--actor` must be a user
// with the admin claim.

import { fileURLToPath } from 'node:url';
import { reviewAward, type Award, type AwardDeps, type AwardProof, type ReviewAction } from '@photobooking/domain';

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
  show(awardId: string): Promise<{ award: Award; proof: AwardProof | null; urls: string[] } | null>;
  /** When set, the actor must pass it (the real CLI checks the admin claim). */
  isAdmin?(uid: string): Promise<boolean>;
}

export async function runCli(argv: readonly string[], deps: AwardDeps, io: CliIo): Promise<void> {
  const args = parseArgs(argv);
  if (args.command === 'list') {
    const pending = (await io.listPending()).sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
    for (const a of pending) {
      io.print(
        `${a.id}  ${a.createdAt.toISOString()}  ${a.photographerId}  ${a.result}  ${a.year}  ${a.competition}`,
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
    return;
  }
  if (args.actor === null) throw new Error(`${args.command} needs --actor <uid> of an admin. ${USAGE}`);
  if (io.isAdmin !== undefined && !(await io.isAdmin(args.actor))) {
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
      const bucket = getStorage().bucket();
      const urls: string[] = [];
      for (const f of proof?.files ?? []) {
        const [url] = await bucket.file(f).getSignedUrl({ action: 'read', expires: Date.now() + 15 * 60 * 1000 });
        urls.push(url);
      }
      return { award: awardFromDoc(id, ad), proof, urls };
    },
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
