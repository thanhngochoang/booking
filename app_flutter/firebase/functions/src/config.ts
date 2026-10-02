import type { CallableOptions } from 'firebase-functions/v2/https';

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
