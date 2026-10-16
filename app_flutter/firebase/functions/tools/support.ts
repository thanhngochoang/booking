import { fileURLToPath } from 'node:url';
import {
  staffReply,
  type SupportDeps,
  type SupportMessage,
  type SupportThread,
} from '@photobooking/domain';

export const HELP = `usage: support list | show <threadId> | reply <threadId> "<text>" --actor <uid>

Environment:
  GOOGLE_APPLICATION_CREDENTIALS  path to a service account key
  GCLOUD_PROJECT                  project id
  FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST
                                  use these instead of credentials to work against emulators

--actor must be a user with the custom claim staffRole = admin or sales.`;

export type Command = 'list' | 'show' | 'reply';

export interface ParsedArgs {
  readonly command: Command;
  readonly threadId: string | null;
  readonly text: string | null;
  readonly actor: string | null;
}

const USAGE = 'usage: support list | show <threadId> | reply <threadId> "<text>" --actor <uid>';

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
  if (command === 'list') {
    return { command, threadId: null, text: null, actor };
  }
  if (command === 'show') {
    const threadId = rest[1];
    if (!threadId) throw new Error(`missing thread id. ${USAGE}`);
    return { command, threadId, text: null, actor };
  }
  if (command === 'reply') {
    const threadId = rest[1];
    if (!threadId) throw new Error(`missing thread id. ${USAGE}`);
    const text = rest[2] ?? null;
    if (text === null) throw new Error(`reply needs text (1-1000 characters). ${USAGE}`);
    return { command, threadId, text, actor };
  }
  throw new Error(USAGE);
}

export interface CliIo {
  print(line: string): void;
  listAwaitingStaff(limit: number): Promise<readonly SupportThread[]>;
  showMessages(threadId: string, limit: number): Promise<readonly SupportMessage[]>;
  getThread(threadId: string): Promise<SupportThread | null>;
  isStaff(uid: string): Promise<boolean>;
}

export async function runCli(argv: readonly string[], deps: SupportDeps, io: CliIo): Promise<void> {
  const args = parseArgs(argv);

  if (args.command === 'list') {
    const threads = await io.listAwaitingStaff(50);
    for (const t of threads) {
      io.print(`${t.id}  ${t.kind}  ${t.status}  awaitingStaff:${t.awaitingStaff}  lastMsg:${t.lastMessageAt ?? '-'}  preview:${t.lastMessagePreview ?? '-'}`);
    }
    return;
  }

  const threadId = args.threadId as string;

  if (args.command === 'show') {
    const thread = await io.getThread(threadId);
    if (!thread) throw new Error(`thread ${threadId} not found`);
    io.print(JSON.stringify(thread, null, 2));
    const messages = await io.showMessages(threadId, 30);
    for (const m of messages) {
      io.print(`[${m.createdAt}] ${m.senderRole} (${m.senderName}): ${m.body}`);
    }
    return;
  }

  if (args.command === 'reply') {
    if (!args.actor) throw new Error(`reply needs --actor <uid> of staff (admin or sales). ${USAGE}`);
    if (!(await io.isStaff(args.actor))) {
      throw new Error(`${args.actor} does not have staffRole claim (admin or sales)`);
    }
    const text = args.text as string;
    const clientId = deps.ids.newId();
    const result = await staffReply(deps, args.actor, {
      threadId,
      clientId,
      text,
    });
    io.print(`${threadId} -> replied with message ${result.messageId}`);
  }
}

async function main(): Promise<void> {
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    console.log(HELP);
    return;
  }

  const { getAuth } = await import('firebase-admin/auth');
  const { db } = await import('../src/infra/admin.js');
  const { liveSupportDeps } = await import('../src/infra/live_support.js');
  const firestore = db();
  const deps = liveSupportDeps();

  const io: CliIo = {
    print: (l) => console.log(l),
    listAwaitingStaff: (limit) => deps.store.listAwaitingStaff(limit),
    showMessages: (threadId, limit) => deps.store.listMessages(threadId, limit),
    getThread: async (threadId) => {
      return deps.store.runTransaction((tx) => tx.getThread(threadId));
    },
    isStaff: async (uid) => {
      const user = await getAuth().getUser(uid);
      const role = user.customClaims?.staffRole;
      return role === 'admin' || role === 'sales';
    },
  };

  await runCli(process.argv.slice(2), deps, io);
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e: unknown) => {
    console.error(e instanceof Error ? e.message : String(e));
    process.exit(1);
  });
}
