import type { NotifyDeps } from './notification_ports.js';
import { notifySupportReply } from './notification_hooks.js';
import type { SupportMessage, SupportThread } from './support_thread.js';

export async function notifySupportMessage(
  deps: NotifyDeps,
  thread: SupportThread,
  message: SupportMessage,
): Promise<void> {
  // Only staff messages notify
  if (message.senderRole !== 'staff') {
    return;
  }

  // System or user messages notify nobody
  if (thread.kind === 'help') {
    const recipientIds = thread.ownerId ? [thread.ownerId] : thread.participants;
    await notifySupportReply(deps, {
      threadId: thread.id,
      disputeId: thread.disputeId,
      messageId: message.id,
      recipientIds,
      preview: message.body,
    });
  }
}
