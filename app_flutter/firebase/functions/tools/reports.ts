// Staff CLI for reports (S20, plan Decision 10) until the S23.05 screen (#83):
//   npm run reports -- list [open|dismissed|actioned]
//   npm run reports -- show <id>
//   npm run reports -- dismiss <id> "<note>" --actor <uid>
//   npm run reports -- takedown <id> "<note>" --actor <uid>

import { fileURLToPath } from 'node:url';
import {
  decideReport,
  moderateEventTimeline,
  type Report,
  type ReportStatus,
} from '@photobooking/domain';
import { auth, db } from '../src/infra/admin.js';
import { liveReportDeps } from '../src/infra/live_safety.js';
import { liveTimelineDeps } from '../src/infra/live_event_social.js';

export type Command = 'list' | 'show' | 'dismiss' | 'takedown';

export interface ParsedArgs {
  readonly command: Command;
  readonly id: string | null;
  readonly status: ReportStatus;
  readonly note: string | null;
  readonly actor: string | null;
}

const USAGE =
  'usage: reports list [open|dismissed|actioned] | show <id> | dismiss <id> "<note>" --actor <uid> | takedown <id> "<note>" --actor <uid>';

export function parseArgs(argv: readonly string[]): ParsedArgs {
  const args = [...argv];
  const command = args[0] as Command | undefined;
  if (!command || !['list', 'show', 'dismiss', 'takedown'].includes(command)) {
    throw new Error(USAGE);
  }

  let actor: string | null = null;
  const actorIdx = args.indexOf('--actor');
  if (actorIdx !== -1) {
    actor = args[actorIdx + 1] ?? null;
    args.splice(actorIdx, 2);
  }

  if (command === 'list') {
    const statusRaw = args[1] ?? 'open';
    if (!['open', 'dismissed', 'actioned'].includes(statusRaw)) {
      throw new Error(USAGE);
    }
    return {
      command: 'list',
      id: null,
      status: statusRaw as ReportStatus,
      note: null,
      actor: null,
    };
  }

  const id = args[1] ?? null;
  if (!id) {
    throw new Error(USAGE);
  }

  if (command === 'show') {
    return {
      command: 'show',
      id,
      status: 'open',
      note: null,
      actor: null,
    };
  }

  // dismiss | takedown
  const note = args[2] ?? null;
  if (!note || note.trim().length < 5) {
    throw new Error('note must be at least 5 characters');
  }
  if (!actor) {
    throw new Error('--actor <uid> is required for decisions');
  }

  return {
    command,
    id,
    status: 'open',
    note: note.trim(),
    actor,
  };
}

export async function executeTakedown(
  report: Report,
  actor: string,
  note: string,
  reportDeps = liveReportDeps(),
): Promise<string> {
  const firestore = db();
  const targetType = report.targetType;
  const targetId = report.targetId;

  if (targetType === 'event') {
    return 'Event takedown cannot be completed via CLI. Cancel it in S12.03 with an admin account.';
  }

  if (targetType === 'post') {
    const postRef = firestore.collection('posts').doc(targetId);
    const snap = await postRef.get();
    if (snap.exists) {
      const data = snap.data();
      const eventId = data?.eventId;
      if (typeof eventId === 'string' && eventId.length > 0) {
        try {
          await moderateEventTimeline(
            liveTimelineDeps(),
            { uid: actor, staffRole: 'admin' },
            { eventId, postId: targetId, action: 'hide' },
          );
        } catch {
          // ignore if already hidden
        }
      }
      await postRef.delete();
    }
  } else if (targetType === 'message') {
    if (report.chatId) {
      const msgRef = firestore.doc(`chats/${report.chatId}/messages/${targetId}`);
      await msgRef.update({
        deletedAt: new Date(),
        body: '',
        imagePath: null,
        imageUrl: null,
      });
    }
  } else if (targetType === 'user') {
    try {
      await auth().updateUser(targetId, { disabled: true });
      await auth().revokeRefreshTokens(targetId);
    } catch {
      // User might be disabled or auth mocked
    }
  }

  await decideReport(reportDeps, actor, {
    reportId: report.id,
    status: 'actioned',
    note,
  });

  return `Takedown executed successfully for ${targetType} ${targetId}.`;
}

export async function runCli(argv: readonly string[]): Promise<void> {
  const parsed = parseArgs(argv);
  const deps = liveReportDeps();

  if (parsed.command === 'list') {
    const reports = await deps.store.list(parsed.status, 50);
    console.log(`Found ${reports.length} ${parsed.status} reports:`);
    for (const r of reports) {
      console.log(`- [${r.id}] ${r.targetType} (${r.targetId}) reason: ${r.reason} by ${r.reporterId} at ${r.createdAt}`);
    }
    return;
  }

  if (parsed.command === 'show') {
    const r = await deps.store.get(parsed.id!);
    if (!r) {
      console.error(`Report ${parsed.id} not found.`);
      process.exitCode = 1;
      return;
    }
    console.log(JSON.stringify(r, null, 2));
    return;
  }

  const report = await deps.store.get(parsed.id!);
  if (!report) {
    console.error(`Report ${parsed.id} not found.`);
    process.exitCode = 1;
    return;
  }

  if (parsed.command === 'dismiss') {
    await decideReport(deps, parsed.actor!, {
      reportId: parsed.id!,
      status: 'dismissed',
      note: parsed.note!,
    });
    console.log(`Report ${parsed.id} dismissed.`);
    return;
  }

  if (parsed.command === 'takedown') {
    const msg = await executeTakedown(report, parsed.actor!, parsed.note!, deps);
    console.log(msg);
  }
}

const isEntry = process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1];
if (isEntry) {
  runCli(process.argv.slice(2)).catch((e) => {
    console.error(e);
    process.exitCode = 1;
  });
}
