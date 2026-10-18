import { Timestamp, type DocumentData } from 'firebase-admin/firestore';
import type {
  DeliveryRound,
  DeliverySampleRef,
  DeliveryDecision,
  PhotoNote,
  PrivateDelivery,
  DeliverySample,
} from '@photobooking/domain';

function toIso(v: unknown): string | null {
  if (v instanceof Timestamp) return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  if (typeof v === 'string') return v;
  return null;
}

function toTs(iso: string | null | undefined): Timestamp | null {
  if (!iso) return null;
  return Timestamp.fromDate(new Date(iso));
}

export function deliveryRoundToFirestore(r: DeliveryRound): DocumentData {
  return {
    bookingId: r.bookingId,
    round: r.round,
    samples: r.samples.map((s) => ({
      fileId: s.fileId,
      path: s.path,
      thumbPath: s.thumbPath,
      width: s.width,
      height: s.height,
    })),
    photoCount: r.photoCount,
    linkHost: r.linkHost,
    note: r.note ?? null,
    submittedAt: toTs(r.submittedAt),
    submittedBy: r.submittedBy,
    decision: r.decision
      ? {
          kind: r.decision.kind,
          note: r.decision.note ?? null,
          photoNotes: r.decision.photoNotes.map((pn) => ({
            sampleIndex: pn.sampleIndex,
            note: pn.note,
          })),
          at: toTs(r.decision.at),
          auto: r.decision.auto,
          extra: r.decision.extra,
        }
      : null,
  };
}

export function deliveryRoundFromFirestore(roundNumber: number, d: DocumentData | undefined): DeliveryRound | null {
  if (!d) return null;
  const bookingId = typeof d.bookingId === 'string' ? d.bookingId : '';
  const round = typeof d.round === 'number' ? d.round : roundNumber;
  const photoCount = typeof d.photoCount === 'number' ? d.photoCount : 0;
  const linkHost = typeof d.linkHost === 'string' ? d.linkHost : '';
  const note = typeof d.note === 'string' ? d.note : null;
  const submittedAt = toIso(d.submittedAt) ?? new Date(0).toISOString();
  const submittedBy = typeof d.submittedBy === 'string' ? d.submittedBy : '';

  const samples: DeliverySampleRef[] = [];
  if (Array.isArray(d.samples)) {
    for (const s of d.samples) {
      if (s && typeof s === 'object') {
        samples.push({
          fileId: String(s.fileId ?? ''),
          path: String(s.path ?? ''),
          thumbPath: String(s.thumbPath ?? ''),
          width: Number(s.width ?? 0),
          height: Number(s.height ?? 0),
        });
      }
    }
  }

  let decision: DeliveryDecision | null = null;
  if (d.decision && typeof d.decision === 'object') {
    const dec = d.decision as Record<string, unknown>;
    const kind = dec.kind === 'approve' ? 'approve' : 'request_revision';
    const decNote = typeof dec.note === 'string' ? dec.note : null;
    const photoNotes: PhotoNote[] = [];
    if (Array.isArray(dec.photoNotes)) {
      for (const pn of dec.photoNotes) {
        if (pn && typeof pn === 'object') {
          photoNotes.push({
            sampleIndex: Number(pn.sampleIndex ?? 0),
            note: String(pn.note ?? ''),
          });
        }
      }
    }
    decision = {
      kind,
      note: decNote,
      photoNotes,
      at: toIso(dec.at) ?? new Date(0).toISOString(),
      auto: Boolean(dec.auto),
      extra: Boolean(dec.extra),
    };
  }

  return {
    bookingId,
    round,
    samples,
    photoCount,
    linkHost,
    note,
    submittedAt,
    submittedBy,
    decision,
  };
}

export function privateDeliveryToFirestore(p: PrivateDelivery): DocumentData {
  return {
    link: p.link,
    round: p.round,
    unlockedAt: toTs(p.unlockedAt),
    updatedAt: toTs(p.updatedAt),
  };
}

export function privateDeliveryFromFirestore(d: DocumentData | undefined): PrivateDelivery | null {
  if (!d || typeof d.link !== 'string') return null;
  return {
    link: d.link,
    round: Number(d.round ?? 1),
    unlockedAt: toIso(d.unlockedAt),
    updatedAt: toIso(d.updatedAt) ?? new Date(0).toISOString(),
  };
}

export function deliverySampleToFirestore(s: DeliverySample): DocumentData {
  return {
    fileId: s.fileId,
    uploaderId: s.uploaderId,
    status: s.status,
    path: s.path,
    thumbPath: s.thumbPath,
    width: s.width,
    height: s.height,
    bytes: s.bytes,
    failure: s.failure ?? null,
    ...(s.createdAt ? { createdAt: toTs(s.createdAt) } : {}),
  };
}

export function deliverySampleFromFirestore(fileId: string, d: DocumentData | undefined): DeliverySample | null {
  if (!d) return null;
  const createdAt = toIso(d.createdAt);
  return {
    fileId,
    uploaderId: String(d.uploaderId ?? ''),
    status: d.status === 'ready' ? 'ready' : 'failed',
    path: String(d.path ?? ''),
    thumbPath: String(d.thumbPath ?? ''),
    width: Number(d.width ?? 0),
    height: Number(d.height ?? 0),
    bytes: Number(d.bytes ?? 0),
    failure: typeof d.failure === 'string' ? d.failure : null,
    ...(createdAt ? { createdAt } : {}),
  };
}
