import { chatPreview, notify, type NotifyDeps } from '@photobooking/domain';

export interface ChatMessageEvent {
  readonly chatId: string;
  readonly messageId: string;
  readonly message: Record<string, unknown> | undefined;
  /** The chat's members (customer and photographer). */
  readonly members: readonly string[];
}

/** Notifies the other member, grouped per chat; system messages and malformed ones are skipped. */
export async function handleChatMessageCreated(event: ChatMessageEvent, deps: NotifyDeps): Promise<'sent' | 'skipped'> {
  const m = event.message;
  const senderId = typeof m?.senderId === 'string' ? m.senderId : null;
  const kind = m?.type;
  if (senderId === null || (kind !== 'text' && kind !== 'image' && kind !== 'location')) return 'skipped';
  const recipient = event.members.find((u) => u !== senderId);
  if (recipient === undefined || !event.members.includes(senderId)) return 'skipped';

  const sender = await deps.users.get(senderId);
  const name = sender?.name ?? 'Tin nhắn mới';
  await notify(deps, {
    userId: recipient,
    content: {
      type: 'chat_message',
      sender: name,
      preview: chatPreview(kind, typeof m?.body === 'string' ? m.body : ''),
      count: 1,
    },
    target: `/chat/${event.chatId}`,
    dedupeKey: `chat_message_${event.messageId}`,
    groupKey: `chat:${event.chatId}`,
    eventId: event.messageId,
    actor: { id: senderId, name, avatarUrl: sender?.avatarUrl ?? null },
    thumbUrl: sender?.avatarUrl ?? null,
  });
  return 'sent';
}
