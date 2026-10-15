/**
 * The only file in services/api that knows where phase 1's pure domain module
 * lives (created by docs/superpowers/plans/2026-10-01-backend-phase1-firebase-local.md).
 * Rules are imported, never copied: Cloud Functions and this API run the same
 * code. If phase 1 uses other names, alias them here (`export { x as y }`).
 */
// Phase 1 names (packages/domain): bookingContactUnlocked, contactUrlFor.
// If their parameters differ from the signatures under "Consumes", wrap them
// here instead of aliasing; nothing else in services/api changes.
export {
  ERROR_CODES,
  bookingContactUnlocked as contactUnlocked,
  contactUrlFor as contactUrl,
} from '../../../../packages/domain/src/index.js';
export type {
  ContactNumbers,
  ErrorCode,
  ExternalChannel,
} from '../../../../packages/domain/src/index.js';
