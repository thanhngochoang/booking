import { defineSecret } from 'firebase-functions/params';
import type { DocumentOptions } from 'firebase-functions/v2/firestore';
import type { CallableOptions, HttpsOptions } from 'firebase-functions/v2/https';
import type { ScheduleOptions } from 'firebase-functions/v2/scheduler';

/**
 * Every function runs in Singapore, the closest Cloud Functions region to Vietnam.
 * The Flutter app uses the same value (lib/data/backend/backend_config.dart, `functionsRegion`).
 */
export const REGION = 'asia-southeast1';

/**
 * Key of the payout account cipher: 32 random bytes, base64 (Secret Manager; see
 * docs/FIREBASE-SETUP.md "Payout account key"). Bound to the callable that encrypts
 * (`savePayoutAccount`), the callable that decrypts the active account to refuse a code for it
 * (`requestPayoutOtp`) and the job that decrypts to send (`createPayouts`), nothing else; the
 * emulator reads it from `.secret.local`.
 */
export const PAYOUT_ACCOUNT_KEY = defineSecret('PAYOUT_ACCOUNT_KEY');

export const PAYMENT_SECRETS = [PAYOUT_ACCOUNT_KEY];

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
 * Callables that run contended transactions or payments (registerEvent, the ticket payment
 * callables, cancelEvent's refunds): under 20 concurrent registrations the emulator needed more than
 * the 10 s default (ledger, PR #32).
 */
export const PAYMENT_CALLABLE_OPTIONS = {
  ...CALLABLE_OPTIONS,
  timeoutSeconds: 30,
  secrets: PAYMENT_SECRETS,
} as const satisfies CallableOptions;

export const BOOKING_REFUND_CALLABLE_OPTIONS = {
  ...CALLABLE_OPTIONS,
  secrets: PAYMENT_SECRETS,
} as const satisfies CallableOptions;

/** `cancelEvent`: refunds every paid ticket, by bank transfer to the payer for bank-QR tickets. */
export const EVENT_REFUND_CALLABLE_OPTIONS = {
  ...CALLABLE_OPTIONS,
  timeoutSeconds: 60,
  secrets: PAYMENT_SECRETS,
} as const satisfies CallableOptions;

/**
 * The payment provider's webhook (`paymentWebhook`, onRequest). Public: the provider calls it without
 * a Firebase identity, so every request is authenticated by its signature (infra/fake_webhook.ts for
 * the fake provider) before anything is read. 30 s like the payment callables (one transfer runs a
 * contended transaction and may dispatch refunds).
 */
export const WEBHOOK_OPTIONS = {
  region: REGION,
  memory: '256MiB',
  timeoutSeconds: 30,
  maxInstances: 10,
  minInstances: 0,
  invoker: 'public',
  secrets: PAYMENT_SECRETS,
} as const satisfies HttpsOptions;

/**
 * The development Firebase project (`.firebaserc` alias `dev`). Fake payments are allowed there and
 * on the emulator only (infra/fake_payments.ts); this is the single place the id is written.
 */
export const DEV_PROJECT_ID = 'booking-c1922';

/** The project the functions run in: `GCLOUD_PROJECT`, else `FIREBASE_CONFIG.projectId`. */
export function currentProjectId(env: Readonly<Record<string, string | undefined>> = process.env): string | undefined {
  if (env.GCLOUD_PROJECT) return env.GCLOUD_PROJECT;
  if (!env.FIREBASE_CONFIG) return undefined;
  try {
    return (JSON.parse(env.FIREBASE_CONFIG) as { projectId?: string }).projectId;
  } catch {
    return undefined;
  }
}

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

export const BOOKING_CLOCK_OPTIONS = {
  ...SCHEDULE_OPTIONS,
  timeoutSeconds: 300,
  secrets: PAYMENT_SECRETS,
} as const satisfies ScheduleOptions;

/**
 * The event clock (every 5 minutes): its refund step pays back tickets of cancelled events, which go
 * to the payer's bank account when they were paid by bank QR (V1 + V2), so it binds the account key.
 */
export const EVENT_CLOCK_OPTIONS = {
  ...SCHEDULE_OPTIONS,
  schedule: 'every 5 minutes',
  timeoutSeconds: 120,
  secrets: PAYMENT_SECRETS,
} as const satisfies ScheduleOptions;

/**
 * The payment clock (payments spec §3.3): reconciliation of open payments and QR expiry every
 * 5 minutes. One instance, and a run ends before the next one starts.
 */
export const PAYMENT_CLOCK_OPTIONS = {
  ...SCHEDULE_OPTIONS,
  schedule: 'every 5 minutes',
  timeoutSeconds: 240,
  secrets: PAYMENT_SECRETS,
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



/**
 * `createPayouts` (payments spec M5, §6.1 "đề xuất 10:00"): daily at 10:00 Vietnam time, one
 * instance, no retry (a second run the same day creates nothing new anyway), up to 540 s, with the
 * account key to decrypt the number it sends to.
 */
export const CREATE_PAYOUTS_OPTIONS: ScheduleOptions = {
  ...SCHEDULE_OPTIONS,
  schedule: '0 10 * * *',
  timeZone: 'Asia/Ho_Chi_Minh',
  timeoutSeconds: 540,
  secrets: [PAYOUT_ACCOUNT_KEY],
};

/**
 * `fake` runs the reference payout gateway (emulator, or `PAYOUTS_MODE=fake` in the dev project);
 * anything else is `off`: no real bank adapter exists, so executing a payout is refused.
 */
export function payoutsMode(env: Readonly<Record<string, string | undefined>> = process.env): 'fake' | 'off' {
  return env.FUNCTIONS_EMULATOR === 'true' || env.PAYOUTS_MODE === 'fake' ? 'fake' : 'off';
}
