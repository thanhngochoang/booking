import type { DocumentOptions } from 'firebase-functions/v2/firestore';
import type { CallableOptions } from 'firebase-functions/v2/https';
import type { ScheduleOptions } from 'firebase-functions/v2/scheduler';

/**
 * Every function runs in Singapore, the closest Cloud Functions region to Vietnam.
 * The Flutter app uses the same value (lib/data/backend/backend_config.dart, `functionsRegion`).
 */
export const REGION = 'asia-southeast1';

/**
 * Options shared by every callable. Passed explicitly to each `onCall` (not through
 * setGlobalOptions) so the value cannot depend on module evaluation order.
 * App Check is not enforced in phase 1: the emulators do not verify App Check tokens; the cloud
 * deploy plan turns `enforceAppCheck` on together with the client's App Check provider.
 */
export const CALLABLE_OPTIONS = {
  region: REGION,
  memory: '256MiB',
  timeoutSeconds: 10,
  maxInstances: 10,
  minInstances: 0,
  enforceAppCheck: false,
} as const satisfies CallableOptions;

/**
 * Options of every Firestore trigger (onPhotographerWrite, spec 2026-10-02 §2). `retry: true`:
 * a failed read or write is retried; the use case is idempotent (precondition + loop guard).
 */
export const TRIGGER_OPTIONS = {
  region: REGION,
  memory: '256MiB',
  timeoutSeconds: 30,
  maxInstances: 10,
  minInstances: 0,
  retry: true,
} as const satisfies Omit<DocumentOptions, 'document'>;

/**
 * Options for the scheduled sweep clock (runs every 15 minutes, Asia/Ho_Chi_Minh).
 */
export const SCHEDULE_OPTIONS = {
  schedule: 'every 15 minutes',
  timeZone: 'Asia/Ho_Chi_Minh',
  region: REGION,
  memory: '256MiB',
  timeoutSeconds: 60,
  maxInstances: 1,
  minInstances: 0,
  retryCount: 0,
} as const satisfies ScheduleOptions;

/**
 * Storage URL prefixes allowed for photo uploads in reviews.
 */
export function storageUrlPrefixes(): string[] {
  let projectId = process.env.GCLOUD_PROJECT;
  if (!projectId && process.env.FIREBASE_CONFIG) {
    try {
      const cfg = JSON.parse(process.env.FIREBASE_CONFIG) as { projectId?: string };
      projectId = cfg.projectId;
    } catch {
      // Ignore JSON parse error
    }
  }

  const bucket =
    process.env.STORAGE_BUCKET ||
    (projectId ? `${projectId}.firebasestorage.app` : 'demo-photobooking.appspot.com');

  const prefixes = [
    `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/`,
  ];
  if (projectId) {
    prefixes.push(`https://firebasestorage.googleapis.com/v0/b/${projectId}.appspot.com/o/`);
  }

  if (process.env.FUNCTIONS_EMULATOR === 'true' || process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
    const host = process.env.FIREBASE_STORAGE_EMULATOR_HOST || '127.0.0.1:9199';
    prefixes.push(`http://${host}/v0/b/${bucket}/o/`);
    if (projectId) {
      prefixes.push(`http://${host}/v0/b/${projectId}.appspot.com/o/`);
    }
  }

  return prefixes;
}

