import { blockUser } from './block_use_cases.js';
import { formatVnDate } from './booking_policy.js';
import { DomainError } from './errors.js';
import {
  parseReportInput,
  reportDocId,
  REPORTS_PER_DAY,
  type Report,
} from './report.js';
import type { ReportDeps } from './report_ports.js';

export async function submitReport(
  deps: ReportDeps,
  reporterId: string,
  raw: unknown,
): Promise<{ reportId: string; duplicate: boolean; blocked: boolean }> {
  const input = parseReportInput(raw);
  const docId = reportDocId(reporterId, input.type, input.targetId, input.chatId);
  const now = deps.clock.now();
  const dayKey = formatVnDate(now);
  const at = now.toISOString();

  const report = await deps.store.runTransaction(async (tx) => {
    // 1. ALL READS
    const existing = await tx.getReport(docId);
    if (existing) {
      return { report: existing, duplicate: true };
    }

    const quota = await tx.getQuota(reporterId);
    const countToday = quota && quota.day === dayKey ? quota.count : 0;
    if (countToday >= REPORTS_PER_DAY) {
      throw new DomainError('limit_exceeded');
    }

    if (input.type === 'message') {
      if (!input.chatId) throw new DomainError('invalid_argument');
      const isMember = await tx.isChatMember(input.chatId, reporterId);
      if (!isMember) {
        throw new DomainError('permission_denied');
      }
    }

    const target = await tx.getTarget(input.type, input.targetId, input.chatId);
    if (!target) {
      throw new DomainError('not_found');
    }

    // Reporting your own content -> invalid_argument
    if (target.ownerId === reporterId) {
      throw new DomainError('invalid_argument');
    }

    // 2. ALL WRITES
    const newReport: Report = {
      id: docId,
      reporterId,
      targetType: input.type,
      targetId: input.targetId,
      chatId: input.chatId,
      targetOwnerId: target.ownerId,
      reason: input.reason,
      text: input.text,
      blocked: input.block && target.ownerId !== null && target.ownerId !== reporterId,
      snapshot: target.snapshot,
      status: 'open',
      staffNote: null,
      decidedBy: null,
      decidedAt: null,
      createdAt: at,
    };

    tx.putReport(newReport);
    tx.putQuota(reporterId, { day: dayKey, count: countToday + 1 });

    return { report: newReport, duplicate: false };
  });

  if (report.duplicate) {
    return { reportId: docId, duplicate: true, blocked: false };
  }

  let blocked = false;
  if (
    input.block &&
    report.report.targetOwnerId !== null &&
    report.report.targetOwnerId !== reporterId
  ) {
    try {
      await blockUser(deps.blocks, reporterId, {
        userId: report.report.targetOwnerId,
        source: 'report',
      });
      blocked = true;
    } catch {
      // If block fails (e.g. limit_exceeded), the report was already filed
      blocked = false;
    }
  }

  return {
    reportId: docId,
    duplicate: false,
    blocked,
  };
}

/** `{reportId, status: 'dismissed'|'actioned', note (5–500)}`; staff role checked by the adapter. */
export async function decideReport(
  deps: ReportDeps,
  staffId: string,
  raw: unknown,
): Promise<Report> {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;
  const reportId = r.reportId;
  if (typeof reportId !== 'string' || !reportId) {
    throw new DomainError('invalid_argument');
  }

  const status = r.status;
  if (status !== 'dismissed' && status !== 'actioned') {
    throw new DomainError('invalid_argument');
  }

  const note = r.note;
  if (typeof note !== 'string') {
    throw new DomainError('invalid_argument');
  }
  const trimmedNote = note.trim();
  if (trimmedNote.length < 5 || trimmedNote.length > 500) {
    throw new DomainError('invalid_argument');
  }

  const report = await deps.store.get(reportId);
  if (!report) {
    throw new DomainError('not_found');
  }

  const at = deps.clock.now().toISOString();
  const patch: Pick<Report, 'status' | 'staffNote' | 'decidedBy' | 'decidedAt'> = {
    status,
    staffNote: trimmedNote,
    decidedBy: staffId,
    decidedAt: at,
  };

  await deps.store.decide(reportId, patch);

  return {
    ...report,
    ...patch,
  };
}
