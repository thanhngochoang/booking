import {
  moderateEventChat,
  postEventAnnouncement,
  sendEventMessage,
  type EventChatDeps,
} from '@photobooking/domain';
import { eventCallerOf, runEventCallable, type EventCallableInput } from './event.js';

const dataOf = (request: EventCallableInput): unknown => request.data ?? {};

/** `{eventId, message: {clientId, type, body | imagePath | point}}` → `{id}` */
export async function handleSendEventMessage(
  request: EventCallableInput,
  deps: EventChatDeps,
): Promise<{ id: string }> {
  const { uid } = eventCallerOf(request);
  const m = await runEventCallable('sendEventMessage', () => sendEventMessage(deps, uid, dataOf(request)));
  return { id: m.id };
}

/** `{eventId, action: pin | unpin | delete | mute | unmute | remove | moderatorsOnly, messageId?, userId?, minutes?, on?}` → `{}` */
export async function handleModerateEventChat(
  request: EventCallableInput,
  deps: EventChatDeps,
): Promise<Record<string, never>> {
  const caller = eventCallerOf(request);
  await runEventCallable('moderateEventChat', () => moderateEventChat(deps, caller, dataOf(request)));
  return {};
}

/** `{eventId, text, clientId?}` → `{messageId}` (S12.03 "Nhắn nhóm": a moderator message, pinned) */
export async function handlePostEventAnnouncement(
  request: EventCallableInput,
  deps: EventChatDeps,
): Promise<{ messageId: string }> {
  const caller = eventCallerOf(request);
  return runEventCallable('postEventAnnouncement', () => postEventAnnouncement(deps, caller, dataOf(request)));
}
