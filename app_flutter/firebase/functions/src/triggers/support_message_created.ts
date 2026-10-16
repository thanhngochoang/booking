import type { NotifyDeps, SupportMessage, SupportStore } from '@photobooking/domain';
import { notifySupportMessage, supportMessageFromFirestore, supportThreadFromFirestore } from './support_firestore_deps.js';

export interface SupportMessageCreatedInput {
  readonly threadId: string;
  readonly messageId: string;
  readonly messageData: Record<string, unknown> | undefined;
}

export interface SupportTriggerDeps {
  readonly notify: NotifyDeps;
  readonly store?: SupportStore;
  readonly getThreadData?: (threadId: string) => Promise<Record<string, unknown> | null>;
}

export async function handleSupportMessageCreated(
  event: SupportMessageCreatedInput,
  deps: SupportTriggerDeps,
): Promise<'sent' | 'skipped'> {
  if (!event.messageData) return 'skipped';

  const message = supportMessageFromFirestore({
    id: event.messageId,
    threadId: event.threadId,
    ...event.messageData,
  });

  if (!message || message.senderRole !== 'staff') {
    return 'skipped';
  }

  let thread = null;
  if (deps.store) {
    thread = await deps.store.runTransaction((tx) => tx.getThread(event.threadId));
  } else if (deps.getThreadData) {
    const rawThread = await deps.getThreadData(event.threadId);
    thread = supportThreadFromFirestore(rawThread);
  }

  if (!thread) return 'skipped';

  await notifySupportMessage(deps.notify, thread, message);
  return 'sent';
}
