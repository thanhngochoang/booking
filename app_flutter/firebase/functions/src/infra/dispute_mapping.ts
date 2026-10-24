/**
 * `disputes/{id}` (S18, #142) ↔ the domain `Dispute`: Timestamps in Firestore, ISO strings in the domain.
 * Its own module so that both the support adapter (dispute threads) and the dispute store can read it
 * without an import cycle.
 */

import { Timestamp, type DocumentData } from 'firebase-admin/firestore';
import {
  DISPUTE_OUTCOMES,
  DISPUTE_REASONS,
  DISPUTE_STATUSES,
  DISPUTE_SUBJECT_TYPES,
  type Dispute,
  type DisputeOutcome,
} from '@photobooking/domain';

export const DISPUTES_COLLECTION = 'disputes';

function toIso(v: unknown): string | null {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  if (typeof v === 'string' && v !== '') return v;
  return null;
}

function toTimestamp(iso: string | null): Timestamp | null {
  return iso ? Timestamp.fromDate(new Date(iso)) : null;
}

const oneOf = <T extends string>(list: readonly T[], v: unknown, fallback: T): T =>
  typeof v === 'string' && (list as readonly string[]).includes(v) ? (v as T) : fallback;

const strOrNull = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);
const strings = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []);
const int = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? v : 0);

export function disputeToFirestore(d: Dispute): DocumentData {
  return {
    id: d.id,
    subjectType: d.subjectType,
    subjectId: d.subjectId,
    eventId: d.eventId,
    paymentId: d.paymentId,
    customerId: d.customerId,
    providerId: d.providerId,
    parties: [...d.parties],
    openedBy: d.openedBy,
    reason: d.reason,
    description: d.description,
    evidencePaths: [...d.evidencePaths],
    snapshot: {
      title: d.snapshot.title,
      subtitle: d.snapshot.subtitle,
      providerName: d.snapshot.providerName,
      thumbUrl: d.snapshot.thumbUrl,
    },
    amountHeld: d.amountHeld,
    status: d.status,
    outcome: d.outcome
      ? {
          kind: d.outcome.kind,
          refundPercent: d.outcome.refundPercent,
          refundAmount: d.outcome.refundAmount,
          releaseAmount: d.outcome.releaseAmount,
          note: d.outcome.note,
          decidedBy: d.outcome.decidedBy,
          decidedAt: toTimestamp(d.outcome.decidedAt),
          refundId: d.outcome.refundId,
        }
      : null,
    threadId: d.threadId,
    createdAt: toTimestamp(d.createdAt),
    updatedAt: toTimestamp(d.updatedAt),
    resolvedAt: toTimestamp(d.resolvedAt),
    version: d.version,
  };
}

function outcomeFromFirestore(v: unknown): DisputeOutcome | null {
  if (typeof v !== 'object' || v === null) return null;
  const o = v as Record<string, unknown>;
  return {
    kind: oneOf(DISPUTE_OUTCOMES, o.kind, 'release'),
    refundPercent: int(o.refundPercent),
    refundAmount: int(o.refundAmount),
    releaseAmount: int(o.releaseAmount),
    note: String(o.note ?? ''),
    decidedBy: String(o.decidedBy ?? ''),
    decidedAt: toIso(o.decidedAt) ?? '',
    refundId: strOrNull(o.refundId),
  };
}

export function disputeFromFirestore(d: DocumentData | null | undefined): Dispute | null {
  if (!d || typeof d.id !== 'string') return null;
  const snap = (typeof d.snapshot === 'object' && d.snapshot !== null ? d.snapshot : {}) as Record<string, unknown>;
  return {
    id: d.id,
    subjectType: oneOf(DISPUTE_SUBJECT_TYPES, d.subjectType, 'booking'),
    subjectId: String(d.subjectId ?? ''),
    eventId: strOrNull(d.eventId),
    paymentId: String(d.paymentId ?? ''),
    customerId: String(d.customerId ?? ''),
    providerId: String(d.providerId ?? ''),
    parties: strings(d.parties),
    openedBy: 'customer',
    reason: oneOf(DISPUTE_REASONS, d.reason, 'other'),
    description: String(d.description ?? ''),
    evidencePaths: strings(d.evidencePaths),
    snapshot: {
      title: String(snap.title ?? ''),
      subtitle: String(snap.subtitle ?? ''),
      providerName: strOrNull(snap.providerName),
      thumbUrl: strOrNull(snap.thumbUrl),
    },
    amountHeld: int(d.amountHeld),
    status: oneOf(DISPUTE_STATUSES, d.status, 'open'),
    outcome: outcomeFromFirestore(d.outcome),
    threadId: String(d.threadId ?? ''),
    createdAt: toIso(d.createdAt) ?? '',
    updatedAt: toIso(d.updatedAt) ?? '',
    resolvedAt: toIso(d.resolvedAt),
    version: int(d.version),
  };
}
