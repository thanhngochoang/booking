/** Marks one chat row read for a user; false when there was no unread row. */
export type MarkChatRowRead = (uid: string, chatId: string, at: Date) => Promise<boolean>;

/** Decision 11: when the member's chat unread count is 0, the grouped inbox row of that chat is read too. */
export async function handleChatMemberWrite(
  input: { chatId: string; uid: string; after: { unreadCount?: unknown } | undefined },
  markRead: MarkChatRowRead,
  now: Date = new Date(),
): Promise<boolean> {
  if (input.after === undefined || input.after.unreadCount !== 0) return false;
  return markRead(input.uid, input.chatId, now);
}
