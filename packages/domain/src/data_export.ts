import type { Clock, IdGenerator } from './ports.js';
import { DomainError } from './errors.js';

export const EXPORT_SCHEMA_VERSION = 1;
export const EXPORT_COOLDOWN_HOURS = 24;
export const EXPORT_TTL_DAYS = 7;

export const EXPORT_LIMITS = {
  bookings: 1000,
  registrations: 1000,
  payments: 1000,
  posts: 1000,
  reviews: 1000,
  messages: 2000,
  notifications: 200,
  markers: 1000,
} as const;

export const EXPORT_REDACTED_KEYS: readonly string[] = [
  'accountNumberEnc',
  'candidate',
  'payer',
  'providerRef',
  'raw',
  'token',
  'idHash',
  'instructions',
];

export interface ExportParts {
  readonly [section: string]: unknown;
}

function redactValue(val: unknown): unknown {
  if (val === null || val === undefined) return val;
  if (Array.isArray(val)) {
    return val.map((item) => redactValue(item));
  }
  if (typeof val === 'object') {
    const res: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(val as Record<string, unknown>)) {
      if (!EXPORT_REDACTED_KEYS.includes(k)) {
        res[k] = redactValue(v);
      }
    }
    return res;
  }
  return val;
}

/** Pure: schemaVersion, generatedAt, the sections with redacted keys removed at any depth. */
export function buildExportDocument(parts: ExportParts, now: Date): Record<string, unknown> {
  const result: Record<string, unknown> = {
    schemaVersion: EXPORT_SCHEMA_VERSION,
    generatedAt: now.toISOString(),
  };

  for (const [section, data] of Object.entries(parts)) {
    result[section] = redactValue(data);
  }

  return result;
}

export function exportAllowed(last: Date | null, now: Date): boolean {
  if (!last) return true;
  const cooldownMs = EXPORT_COOLDOWN_HOURS * 60 * 60 * 1000;
  return now.getTime() - last.getTime() >= cooldownMs;
}

export interface DataExportDeps {
  gather(uid: string, limits: typeof EXPORT_LIMITS): Promise<ExportParts>;
  last(uid: string): Promise<Date | null>;
  pending(uid: string): Promise<boolean>;
  write(uid: string, exportId: string, json: string): Promise<{ path: string; sizeBytes: number }>;
  record(
    uid: string,
    rec: { path: string; sizeBytes: number; createdAt: Date; expiresAt: Date },
  ): Promise<void>;
  readonly clock: Clock;
  readonly ids: IdGenerator;
}

export async function requestDataExport(
  deps: DataExportDeps,
  caller: { uid: string },
  raw: unknown,
): Promise<{ path: string; sizeBytes: number; expiresAt: string }> {
  if (raw !== null && typeof raw === 'object' && Object.keys(raw).length > 0) {
    throw new DomainError('invalid_argument');
  }

  const isPending = await deps.pending(caller.uid);
  if (isPending) {
    throw new DomainError('not_eligible');
  }

  const now = deps.clock.now();
  const lastExport = await deps.last(caller.uid);
  if (!exportAllowed(lastExport, now)) {
    throw new DomainError('limit_exceeded');
  }

  const parts = await deps.gather(caller.uid, EXPORT_LIMITS);
  const doc = buildExportDocument(parts, now);
  const jsonStr = JSON.stringify(doc);

  const exportId = deps.ids.newId();
  const writeRes = await deps.write(caller.uid, exportId, jsonStr);

  const expiresAt = new Date(now.getTime() + EXPORT_TTL_DAYS * 24 * 60 * 60 * 1000);
  await deps.record(caller.uid, {
    path: writeRes.path,
    sizeBytes: writeRes.sizeBytes,
    createdAt: now,
    expiresAt,
  });

  return {
    path: writeRes.path,
    sizeBytes: writeRes.sizeBytes,
    expiresAt: expiresAt.toISOString(),
  };
}
