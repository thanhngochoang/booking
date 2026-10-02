import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { handleGetContactLink } from './callables/get_contact_link.js';
import { CALLABLE_OPTIONS, TRIGGER_OPTIONS } from './config.js';
import { liveContactDeps } from './infra/live.js';
import { liveSkillsDeps } from './infra/live_skills.js';
import { handlePhotographerWrite } from './triggers/photographer_write.js';

// Entry point of the Cloud Functions codebase. Each export is one deployed function.

/** `{bookingId | registrationId, channel}` → `{url}`; contract in plan 2b "Out of scope". */
export const getContactLink = onCall(CALLABLE_OPTIONS, (request) => handleGetContactLink(request, liveContactDeps()));

/**
 * Scores `photographers/{uid}.skills` ("Độ khớp hồ sơ") and removes evidence that is not the
 * photographer's own post (spec 2026-10-02-photographer-write-function-design.md).
 */
export const onPhotographerWrite = onDocumentWritten({ ...TRIGGER_OPTIONS, document: 'photographers/{uid}' }, async (event) => {
  const uid = event.params.uid;
  const after = event.data?.after;
  const live = after?.exists === true ? after : undefined;
  await handlePhotographerWrite(
    { uid, before: event.data?.before.data(), after: live?.data() },
    liveSkillsDeps(uid, live?.updateTime),
  );
});
