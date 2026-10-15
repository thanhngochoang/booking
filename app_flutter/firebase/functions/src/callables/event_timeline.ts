import { moderateEventTimeline, shareEventPost, type TimelineDeps } from '@photobooking/domain';
import { eventCallerOf, runEventCallable, type EventCallableInput } from './event.js';

const dataOf = (request: EventCallableInput): unknown => request.data ?? {};

/** `{eventId, postId, images: [{url, path, w?, h?, blurHash?}], caption?}` → `{postId}` */
export async function handleShareEventPost(
  request: EventCallableInput,
  deps: TimelineDeps,
): Promise<{ postId: string }> {
  const caller = eventCallerOf(request);
  return runEventCallable('shareEventPost', () => shareEventPost(deps, caller, dataOf(request)));
}

/** `{eventId, postId, action: hide | show | approve}` → `{}` */
export async function handleModerateEventTimeline(
  request: EventCallableInput,
  deps: TimelineDeps,
): Promise<Record<string, never>> {
  const caller = eventCallerOf(request);
  await runEventCallable('moderateEventTimeline', () => moderateEventTimeline(deps, caller, dataOf(request)));
  return {};
}
