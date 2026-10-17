import { DomainError } from './errors.js';
import { isId } from './ids.js';

export const REPORT_TARGETS = ['user', 'post', 'message', 'event'] as const;
export type ReportTargetType = (typeof REPORT_TARGETS)[number];

export const REPORT_REASONS = [
  'spam',
  'scam',
  'harassment',
  'inappropriate',
  'stolen_photos',
  'impersonation',
  'other',
] as const;
export type ReportReason = (typeof REPORT_REASONS)[number];

export const REPORT_TEXT_MAX = 500;
export const REPORT_OTHER_MIN = 10;
export const REPORTS_PER_DAY = 20;
export const REPORT_STATUSES = ['open', 'dismissed', 'actioned'] as const;
export type ReportStatus = (typeof REPORT_STATUSES)[number];

export interface ReportSnapshot {
  readonly name: string | null;
  readonly excerpt: string | null;
  readonly imageUrl: string | null;
}

export interface ReportTargetView {
  readonly type: ReportTargetType;
  readonly id: string;
  readonly chatId: string | null;
  readonly ownerId: string | null;
  readonly snapshot: ReportSnapshot;
}

export interface Report {
  readonly id: string;
  readonly reporterId: string;
  readonly targetType: ReportTargetType;
  readonly targetId: string;
  readonly chatId: string | null;
  readonly targetOwnerId: string | null;
  readonly reason: ReportReason;
  readonly text: string | null;
  readonly blocked: boolean;
  readonly snapshot: ReportSnapshot;
  readonly status: ReportStatus;
  readonly staffNote: string | null;
  readonly decidedBy: string | null;
  readonly decidedAt: string | null;
  readonly createdAt: string;
}

export function reportDocId(
  reporterId: string,
  type: ReportTargetType,
  targetId: string,
  chatId: string | null,
): string {
  const targetKey = type === 'message' ? `${chatId}~${targetId}` : targetId;
  return `${reporterId}_${type}_${targetKey}`;
}

export function parseReportInput(raw: unknown): {
  type: ReportTargetType;
  targetId: string;
  chatId: string | null;
  reason: ReportReason;
  text: string | null;
  block: boolean;
} {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;
  const type = r.targetType;
  if (typeof type !== 'string' || !(REPORT_TARGETS as readonly string[]).includes(type)) {
    throw new DomainError('invalid_argument');
  }
  const targetType = type as ReportTargetType;

  const targetId = r.targetId;
  if (!isId(targetId)) {
    throw new DomainError('invalid_argument');
  }

  let chatId: string | null = null;
  if (targetType === 'message') {
    if (typeof r.chatId !== 'string' || !r.chatId) {
      throw new DomainError('invalid_argument');
    }
    chatId = r.chatId;
  }

  const reason = r.reason;
  if (typeof reason !== 'string' || !(REPORT_REASONS as readonly string[]).includes(reason)) {
    throw new DomainError('invalid_argument');
  }
  const reportReason = reason as ReportReason;

  let text: string | null = null;
  if (r.text !== undefined && r.text !== null) {
    if (typeof r.text !== 'string') {
      throw new DomainError('invalid_argument');
    }
    const trimmed = r.text.trim();
    if (trimmed.length > REPORT_TEXT_MAX) {
      throw new DomainError('invalid_argument');
    }
    text = trimmed.length > 0 ? trimmed : null;
  }

  if (reportReason === 'other') {
    if (!text || text.length < REPORT_OTHER_MIN) {
      throw new DomainError('invalid_argument');
    }
  }

  const block = Boolean(r.block);

  return {
    type: targetType,
    targetId,
    chatId,
    reason: reportReason,
    text,
    block,
  };
}
