/** Marks one chat row read for a user; false when there was no unread row. */
export type MarkChatRowRead = (uid: string, chatId: string, at: Date) => Promise<boolean>;

/** Decision 11: when the member's chat unread count is 0, the grouped inbox row of that chat is read too. */
export async function handleChatMemberWrite(
  input: { chatId: string; uid: string; after: { unreadCount?: unknown } | undefined },
  markRead: MarkChatRowRead,
  now: Date = new Date(),
): Promise<boolean> {
  // M9: an event group (`event_{eventId}`) has no inbox row, and every send rewrites the sender's
  // member doc (rate window), so the group chats stop here.
  if (input.chatId.startsWith('event_')) return false;
  if (input.after === undefined || input.after.unreadCount !== 0) return false;
  return markRead(input.uid, input.chatId, now);
}
