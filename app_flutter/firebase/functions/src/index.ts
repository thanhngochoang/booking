import { onCall } from 'firebase-functions/v2/https';
import { handleGetContactLink } from './callables/get_contact_link.js';
import { CALLABLE_OPTIONS } from './config.js';
import { liveContactDeps } from './infra/live.js';

// Entry point of the Cloud Functions codebase. Each export is one deployed function.

/** `{bookingId | registrationId, channel}` → `{url}`; contract in plan 2b "Out of scope". */
export const getContactLink = onCall(CALLABLE_OPTIONS, (request) => handleGetContactLink(request, liveContactDeps()));
