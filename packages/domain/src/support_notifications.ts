import type { NotifyDeps } from './notification_ports.js';
import { notifyDisputeMessage, notifySupportReply } from './notification_hooks.js';
import type { SupportMessage, SupportThread } from './support_thread.js';

/**
 * Decides who hears about a new support message (the `onSupportMessageCreated` trigger), through #138's hooks:
 * - staff in a help thread → `notifySupportReply` to the owner; in a dispute thread → to every participant;
 * - a dispute party (customer or provider) → `notifyDisputeMessage` to the other participants;
 * - a help-thread user message or a system message → nobody.
 */
export async function notifySupportMessage(
  deps: NotifyDeps,
  thread: SupportThread,
  message: SupportMessage,
): Promise<void> {
  if (message.senderRole === 'staff') {
    const recipientIds = thread.kind === 'help' && thread.ownerId ? [thread.ownerId] : thread.participants;
    await notifySupportReply(deps, {
      threadId: thread.id,
      disputeId: thread.disputeId,
      messageId: message.id,
      recipientIds,
      preview: message.body,
    });
    return;
  }

  const partyMessage = message.senderRole === 'customer' || message.senderRole === 'provider';
  if (thread.kind === 'dispute' && thread.disputeId && partyMessage && message.senderId) {
    const recipientIds = thread.participants.filter((uid) => uid !== message.senderId);
    if (recipientIds.length === 0) return;
    await notifyDisputeMessage(deps, {
      disputeId: thread.disputeId,
      recipientIds,
      senderId: message.senderId,
      preview: message.body,
      messageId: message.id,
    });
  }
}
