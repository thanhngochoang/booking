import { DomainError } from './errors.js';
import { isId } from './ids.js';
import { graphemeCount } from './booking_requests.js';
import type { Booking } from './booking.js';
import { clampRevisions, DEFAULT_REVISIONS } from './booking_policy.js';

export const DELIVERY_SAMPLES_MIN = 3;
export const DELIVERY_SAMPLES_MAX = 20;

export const AUTO_APPROVE_HOURS = 72;
export const DELIVERY_CHECK_HOURS = 48;
export const SHOOT_RELEASE_HOURS = 24;
export const SAMPLE_RETENTION_DAYS = 90;

export const DELIVERY_LINK_MAX = 2000;
export const DELIVERY_NOTE_MAX = 500;
export const PHOTO_NOTE_MAX = 120;
export const PHOTO_COUNT_MAX = 10000;

export interface DeliverySampleRef {
  readonly fileId: string;
  readonly path: string;
  readonly thumbPath: string;
  readonly width: number;
  readonly height: number;
}

export interface PhotoNote {
  readonly sampleIndex: number;
  readonly note: string;
}

export interface DeliveryDecision {
  readonly kind: 'approve' | 'request_revision';
  readonly note: string | null;
  readonly photoNotes: readonly PhotoNote[];
  readonly at: string;
  readonly auto: boolean;
  readonly extra: boolean;
}

export interface DeliveryRound {
  readonly bookingId: string;
  readonly round: number;
  readonly samples: readonly DeliverySampleRef[];
  readonly photoCount: number;
  readonly linkHost: string;
  readonly note: string | null;
  readonly submittedAt: string;
  readonly submittedBy: string;
  readonly decision: DeliveryDecision | null;
}

export interface PrivateDelivery {
  readonly link: string;
  readonly round: number;
  readonly unlockedAt: string | null;
  readonly updatedAt: string;
}

export interface DeliverySample {
  readonly fileId: string;
  readonly uploaderId: string;
  readonly status: 'ready' | 'failed';
  readonly path: string;
  readonly thumbPath: string;
  readonly width: number;
  readonly height: number;
  readonly bytes: number;
  readonly failure: string | null;
  readonly createdAt?: string;
}

export interface ExtraRound {
  readonly status: 'pending' | 'granted' | 'declined';
  readonly at: string;
  readonly note: string | null;
  readonly photoNotes: readonly PhotoNote[];
}

export function canDeliver(b: Booking, uid: string): boolean {
  return uid === b.photographerId;
}

export function revisionAllowance(b: Booking): { used: number; total: number; left: number } {
  const base = clampRevisions(b.revisionsIncluded ?? DEFAULT_REVISIONS);
  const granted = b.revisionsGranted ?? 0;
  const total = base + granted;
  const used = b.revisionsUsed ?? 0;
  const left = Math.max(0, total - used);
  return { used, total, left };
}

const ULID_REGEX = /^[0-9A-HJKMNP-TV-Z]{26}$/i;

export function parseDeliveryUploadPath(path: string): { bookingId: string; uploaderId: string; fileId: string } | null {
  const parts = path.split('/');
  if (parts.length !== 4) return null;
  if (parts[0] !== 'deliveryUploads') return null;
  const bookingId = parts[1];
  const uploaderId = parts[2];
  const filename = parts[3];
  if (!bookingId || !uploaderId || !filename || !filename.endsWith('.jpg')) return null;
  const fileId = filename.slice(0, -4);
  if (!ULID_REGEX.test(fileId)) return null;
  return { bookingId, uploaderId, fileId };
}

export function watermarkLabel(name: string | null | undefined): string {
  const trimmed = name?.trim();
  return `${trimmed || 'Nhiếp ảnh gia'} · Bản xem trước`;
}

export function validateSubmitDelivery(raw: unknown): {
  bookingId: string;
  sampleIds: string[];
  link: string;
  linkHost: string;
  photoCount: number;
  note: string | null;
} {
  if (typeof raw !== 'object' || raw === null) {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;

  if (!isId(r.bookingId)) throw new DomainError('invalid_argument');

  if (!Array.isArray(r.sampleIds)) throw new DomainError('invalid_argument');
  const sampleIds = r.sampleIds as string[];
  if (sampleIds.length < DELIVERY_SAMPLES_MIN || sampleIds.length > DELIVERY_SAMPLES_MAX) {
    throw new DomainError('invalid_argument');
  }
  const uniqueSamples = new Set(sampleIds);
  if (uniqueSamples.size !== sampleIds.length) {
    throw new DomainError('invalid_argument');
  }
  for (const id of sampleIds) {
    if (typeof id !== 'string' || !id) throw new DomainError('invalid_argument');
  }

  if (typeof r.link !== 'string') throw new DomainError('invalid_argument');
  const link = r.link.trim();
  if (link.length === 0 || link.length > DELIVERY_LINK_MAX) throw new DomainError('invalid_argument');
  if (/\s/.test(link)) throw new DomainError('invalid_argument');

  let parsedUrl: URL;
  try {
    parsedUrl = new URL(link);
  } catch {
    throw new DomainError('invalid_argument');
  }
  if (parsedUrl.protocol !== 'http:' && parsedUrl.protocol !== 'https:') {
    throw new DomainError('invalid_argument');
  }
  const linkHost = parsedUrl.hostname;
  if (!linkHost || !linkHost.includes('.')) {
    throw new DomainError('invalid_argument');
  }

  if (typeof r.photoCount !== 'number' || !Number.isInteger(r.photoCount) || r.photoCount < 1 || r.photoCount > PHOTO_COUNT_MAX) {
    throw new DomainError('invalid_argument');
  }

  let note: string | null = null;
  if (r.note !== undefined && r.note !== null) {
    if (typeof r.note !== 'string') throw new DomainError('invalid_argument');
    const trimmedNote = r.note.trim();
    if (graphemeCount(trimmedNote) > DELIVERY_NOTE_MAX) {
      throw new DomainError('invalid_argument');
    }
    note = trimmedNote.length > 0 ? trimmedNote : null;
  }

  return {
    bookingId: r.bookingId,
    sampleIds,
    link,
    linkHost,
    photoCount: r.photoCount,
    note,
  };
}

export function validateRevisionRequest(raw: unknown): {
  bookingId: string;
  note: string | null;
  photoNotes: PhotoNote[];
  extra: boolean;
} {
  if (typeof raw !== 'object' || raw === null) {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;

  if (!isId(r.bookingId)) throw new DomainError('invalid_argument');

  const extra = r.extra === true;

  let note: string | null = null;
  if (r.note !== undefined && r.note !== null) {
    if (typeof r.note !== 'string') throw new DomainError('invalid_argument');
    const trimmed = r.note.trim();
    if (graphemeCount(trimmed) > DELIVERY_NOTE_MAX) {
      throw new DomainError('invalid_argument');
    }
    note = trimmed.length > 0 ? trimmed : null;
  }

  const photoNotes: PhotoNote[] = [];
  if (r.photoNotes !== undefined && r.photoNotes !== null) {
    if (!Array.isArray(r.photoNotes)) throw new DomainError('invalid_argument');
    const seenIndices = new Set<number>();
    for (const pn of r.photoNotes) {
      if (typeof pn !== 'object' || pn === null) throw new DomainError('invalid_argument');
      const item = pn as Record<string, unknown>;
      if (typeof item.sampleIndex !== 'number' || !Number.isInteger(item.sampleIndex) || item.sampleIndex < 0) {
        throw new DomainError('invalid_argument');
      }
      if (seenIndices.has(item.sampleIndex)) {
        throw new DomainError('invalid_argument');
      }
      seenIndices.add(item.sampleIndex);

      if (typeof item.note !== 'string') throw new DomainError('invalid_argument');
      const trimmedNote = item.note.trim();
      const count = graphemeCount(trimmedNote);
      if (count === 0 || count > PHOTO_NOTE_MAX) {
        throw new DomainError('invalid_argument');
      }
      photoNotes.push({ sampleIndex: item.sampleIndex, note: trimmedNote });
    }
  }

  if (note === null && photoNotes.length === 0) {
    throw new DomainError('invalid_argument');
  }

  return {
    bookingId: r.bookingId,
    note,
    photoNotes,
    extra,
  };
}

export type DeliveryNotice =
  | { kind: 'submitted'; round: number }
  | { kind: 'revision_requested'; round: number }
  | { kind: 'approved' }
  | { kind: 'extra_round'; round: number; granted: boolean };

export function deliveryNotices(before: Booking | null, after: Booking | null): DeliveryNotice[] {
  if (!after) return [];
  const prevStatus = before?.status;
  const nextStatus = after.status;

  // Status transitions
  if (prevStatus !== nextStatus) {
    if (nextStatus === 'delivered') {
      return [{ kind: 'submitted', round: after.deliveryRound ?? 1 }];
    }
    if (nextStatus === 'revision_requested') {
      // Check if this was a granted extra round
      const beforeExtra = before?.extraRound?.status;
      const afterExtra = after.extraRound?.status;
      if (beforeExtra === 'pending' && afterExtra === 'granted') {
        return [{ kind: 'extra_round', round: after.deliveryRound ?? 1, granted: true }];
      }
      return [{ kind: 'revision_requested', round: after.deliveryRound ?? 1 }];
    }
    if (nextStatus === 'approved') {
      return [{ kind: 'approved' }];
    }
  }

  // Extra round declined while remaining in delivered status
  if (prevStatus === 'delivered' && nextStatus === 'delivered') {
    const beforeExtra = before?.extraRound?.status;
    const afterExtra = after.extraRound?.status;
    if (beforeExtra === 'pending' && afterExtra === 'declined') {
      return [{ kind: 'extra_round', round: after.deliveryRound ?? 1, granted: false }];
    }
  }

  return [];
}
