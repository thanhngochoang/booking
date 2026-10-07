import { DomainError } from './errors.js';
import type { EventCaller, RegistrationDoc } from './event.js';
import type { EventChatDeps, EventChatTx, PaidRegistration } from './event_chat_ports.js';
import { isId } from './ids.js';
import { previewOf, validateMessageInput } from './chat.js';

export const GROUP_RATE_PER_MINUTE = 20;
export const GROUP_READONLY_DAYS = 7;
export const ANNOUNCEMENT_MAX = 500;
export const MUTE_DEFAULT_MINUTES = 24 * 60;
export const MUTE_MAX_MINUTES = 7 * 24 * 60;
const MINUTE_MS = 60_000;

export interface GroupChat {
  readonly id: string;
  readonly eventId: string;
  readonly title: string;
  readonly members: readonly string[];
  readonly moderators: readonly string[];
  readonly memberCount: number;
  readonly moderatorsOnly: boolean;
  readonly lastMessageAt: Date | null;
  readonly lastMessagePreview: string | null;
  readonly lastSenderId: string | null;
  readonly readOnlyAt: Date | null;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

/** `chats/{id}/members/{uid}`; names and avatars only, never a phone. */
export interface GroupMember {
  readonly uid: string;
  readonly role: 'member' | 'moderator';
  readonly name: string;
  readonly avatarUrl: string | null;
  readonly mutedUntil: Date | null;
  readonly joinedAt: Date;
  /** A removed member keeps the doc (history) but leaves `members`. */
  readonly removedAt: Date | null;
  /** The moderator who removed the member; null when the member left by cancelling the ticket. */
  readonly removedBy: string | null;
  readonly sentWindowStart: Date | null;
  readonly sentInWindow: number;
}

export interface GroupMessage {
  readonly id: string;
  readonly chatId: string;
  readonly senderId: string | null;
  /** Denormalised display name; never a phone or an email. */
  readonly senderName: string | null;
  readonly type: 'text' | 'image' | 'location' | 'system';
  readonly body: string | null;
  readonly imagePath: string | null;
  readonly point: { readonly lat: number; readonly lng: number } | null;
  readonly system: { readonly kind: 'member_joined'; readonly userId: string; readonly name: string } | null;
  readonly createdAt: Date;
  /** A deleted message keeps its place as a tombstone. */
  readonly deletedAt: Date | null;
}

/** `chats/{id}/pins/{messageId}`; the newest pin shows at the top of the chat. */
export interface GroupPin {
  readonly messageId: string;
  readonly body: string;
  readonly senderName: string;
  readonly pinnedBy: string;
  readonly pinnedAt: Date;
}

export const eventChatId = (eventId: string): string => `event_${eventId}`;

export const isModerator = (chat: Pick<GroupChat, 'moderators'>, caller: EventCaller): boolean =>
  chat.moderators.includes(caller.uid) || caller.staffRole === 'admin';

/**
 * Sending rules, in this order: not a member or removed → permission_denied; the chat is past
 * `readOnlyAt` → not_eligible; muted → not_eligible; moderators-only and not a moderator →
 * permission_denied; 20 messages in the last minute → limit_exceeded.
 */
export function assertCanSendToGroup(chat: GroupChat, member: GroupMember | null, now: Date): void {
  if (member === null || member.removedAt !== null || !chat.members.includes(member.uid)) {
    throw new DomainError('permission_denied');
  }
  if (chat.readOnlyAt !== null && now.getTime() >= chat.readOnlyAt.getTime()) throw new DomainError('not_eligible');
  if (member.mutedUntil !== null && now.getTime() < member.mutedUntil.getTime()) throw new DomainError('not_eligible');
  if (chat.moderatorsOnly && member.role !== 'moderator') throw new DomainError('permission_denied');
  if (member.sentWindowStart !== null
    && now.getTime() - member.sentWindowStart.getTime() < MINUTE_MS
    && member.sentInWindow >= GROUP_RATE_PER_MINUTE) {
    throw new DomainError('limit_exceeded');
  }
}

function obj(raw: unknown): Record<string, unknown> {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) throw new DomainError('invalid_argument');
  return raw as Record<string, unknown>;
}

function idOf(v: unknown): string {
  if (!isId(v)) throw new DomainError('invalid_argument');
  return v;
}

async function loadChat(tx: EventChatTx, chatId: string): Promise<GroupChat> {
  const chat = await tx.getChat(chatId);
  if (chat === null) throw new DomainError('not_found');
  return chat;
}

/** The member doc, or for a moderator who has none yet the one they would get. */
async function memberOrImplicit(
  deps: EventChatDeps,
  tx: EventChatTx,
  chat: GroupChat,
  uid: string,
): Promise<GroupMember | null> {
  const stored = await tx.getMember(chat.id, uid);
  if (stored !== null) return stored;
  if (!chat.moderators.includes(uid) || !chat.members.includes(uid)) return null;
  const profile = await deps.people.user(uid);
  return {
    uid, role: 'moderator', name: profile?.name ?? 'Ban tổ chức', avatarUrl: profile?.avatarUrl ?? null,
    mutedUntil: null, joinedAt: chat.createdAt, removedAt: null, removedBy: null,
    sentWindowStart: null, sentInWindow: 0,
  };
}

/** Counts one more message in the member's rolling minute. */
function countSend(member: GroupMember, now: Date): GroupMember {
  const fresh = member.sentWindowStart === null || now.getTime() - member.sentWindowStart.getTime() >= MINUTE_MS;
  return fresh
    ? { ...member, sentWindowStart: now, sentInWindow: 1 }
    : { ...member, sentInWindow: member.sentInWindow + 1 };
}

function after(chat: GroupChat, m: GroupMessage, now: Date): GroupChat {
  return {
    ...chat, lastMessageAt: m.createdAt, lastMessagePreview: previewOf({ type: m.type, body: m.body }), lastSenderId: m.senderId, updatedAt: now,
  };
}

/** `{eventId, message: {clientId, type, …}}`; idempotent by `clientId`; the message carries the sender's name. */
export async function sendEventMessage(deps: EventChatDeps, senderId: string, raw: unknown): Promise<GroupMessage> {
  const r = obj(raw);
  const chatId = eventChatId(idOf(r.eventId));
  const v = validateMessageInput(r.message, senderId);
  if (v.type === 'image' && (v.imagePath as string).split('/')[1] !== chatId) throw new DomainError('invalid_argument');

  return deps.chats.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const chat = await loadChat(tx, chatId);
    const existing = await tx.getMessage(chatId, v.clientId);
    if (existing !== null) {
      if (existing.senderId !== senderId) throw new DomainError('conflict');
      return existing;
    }
    const member = await memberOrImplicit(deps, tx, chat, senderId);
    assertCanSendToGroup(chat, member, now);
    const m = member as GroupMember;
    const message: GroupMessage = {
      id: v.clientId, chatId, senderId, senderName: m.name, type: v.type, body: v.body,
      imagePath: v.imagePath, point: v.point, system: null, createdAt: now, deletedAt: null,
    };
    tx.addMessage(message);
    tx.putMember(chatId, countSend(m, now));
    tx.putChat(after(chat, message, now));
    return message;
  });
}

const MODERATION = ['pin', 'unpin', 'delete', 'mute', 'unmute', 'remove', 'restore', 'moderatorsOnly'] as const;

/** `{eventId, action, messageId?, userId?, minutes?, on?}`; moderators (and admin staff) only. */
export async function moderateEventChat(deps: EventChatDeps, caller: EventCaller, raw: unknown): Promise<void> {
  const r = obj(raw);
  const chatId = eventChatId(idOf(r.eventId));
  const action = MODERATION.find((a) => a === r.action);
  if (action === undefined) throw new DomainError('invalid_argument');
  const messageId = action === 'pin' || action === 'unpin' || action === 'delete' ? idOf(r.messageId) : null;
  const userId = action === 'mute' || action === 'unmute' || action === 'remove' || action === 'restore'
    ? idOf(r.userId) : null;
  let minutes = MUTE_DEFAULT_MINUTES;
  if (action === 'mute' && r.minutes !== undefined) {
    if (typeof r.minutes !== 'number' || !Number.isInteger(r.minutes) || r.minutes < 1 || r.minutes > MUTE_MAX_MINUTES) {
      throw new DomainError('invalid_argument');
    }
    minutes = r.minutes;
  }
  if (action === 'moderatorsOnly' && typeof r.on !== 'boolean') throw new DomainError('invalid_argument');

  await deps.chats.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const chat = await loadChat(tx, chatId);
    if (!isModerator(chat, caller)) throw new DomainError('permission_denied');
    const message = messageId === null ? null : await tx.getMessage(chatId, messageId);
    if (messageId !== null && message === null) throw new DomainError('not_found');
    const target = userId === null ? null : await tx.getMember(chatId, userId);
    if (userId !== null) {
      if (target === null) throw new DomainError('not_found');
      if (target.role === 'moderator' || chat.moderators.includes(userId)) throw new DomainError('permission_denied');
    }
    const paid = action === 'restore' && userId !== null ? await tx.paidRegistrations(chat.eventId, userId) : [];
    const profile = action === 'restore' && paid.length > 0 && userId !== null ? await deps.people.user(userId) : null;

    switch (action) {
      case 'moderatorsOnly':
        tx.putChat({ ...chat, moderatorsOnly: r.on === true, updatedAt: now });
        return;
      case 'pin': {
        const m = message as GroupMessage;
        if (m.deletedAt !== null || m.type === 'system') throw new DomainError('invalid_argument');
        tx.putPin(chatId, {
          messageId: m.id, body: m.body ?? previewOf({ type: m.type, body: m.body }), senderName: m.senderName ?? '',
          pinnedBy: caller.uid, pinnedAt: now,
        });
        return;
      }
      case 'unpin':
        tx.deletePin(chatId, (message as GroupMessage).id);
        return;
      case 'delete': {
        const m = message as GroupMessage;
        if (m.type === 'system') throw new DomainError('invalid_argument');
        if (m.deletedAt === null) tx.updateMessage({ ...m, body: null, imagePath: null, point: null, deletedAt: now });
        tx.deletePin(chatId, m.id);
        return;
      }
      case 'mute':
        tx.putMember(chatId, { ...(target as GroupMember), mutedUntil: new Date(now.getTime() + minutes * MINUTE_MS) });
        return;
      case 'unmute':
        tx.putMember(chatId, { ...(target as GroupMember), mutedUntil: null });
        return;
      case 'remove': {
        const t = target as GroupMember;
        if (t.removedAt !== null) return;
        const members = chat.members.filter((u) => u !== t.uid);
        tx.putMember(chatId, { ...t, removedAt: now, removedBy: caller.uid });
        tx.putChat({ ...chat, members, memberCount: members.length, updatedAt: now });
        return;
      }
      case 'restore': {
        // O1/M8: lifts a moderator removal. With a paid ticket now the user is back at once;
        // otherwise only the flag goes, so their next ticket lets them in.
        const t = target as GroupMember;
        if (t.removedBy === null) return;
        if (paid.length > 0) {
          writeJoin(tx, deps, chat, t, t.uid, { name: profile?.name ?? t.name, avatarUrl: profile?.avatarUrl ?? t.avatarUrl }, now);
        } else {
          tx.putMember(chatId, { ...t, removedBy: null });
        }
      }
    }
  });
}

/** S12.03 "Nhắn nhóm": a moderator message that is pinned at once. */
export async function postEventAnnouncement(
  deps: EventChatDeps,
  caller: EventCaller,
  raw: unknown,
): Promise<{ messageId: string }> {
  const r = obj(raw);
  const chatId = eventChatId(idOf(r.eventId));
  if (typeof r.text !== 'string') throw new DomainError('invalid_argument');
  const text = r.text.normalize('NFC').trim();
  if (text.length < 1 || text.length > ANNOUNCEMENT_MAX) throw new DomainError('invalid_argument');
  const messageId = r.clientId === undefined ? deps.ids.newId() : idOf(r.clientId);

  return deps.chats.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const chat = await loadChat(tx, chatId);
    if (!isModerator(chat, caller)) throw new DomainError('permission_denied');
    const existing = await tx.getMessage(chatId, messageId);
    if (existing !== null) return { messageId };
    if (chat.readOnlyAt !== null && now.getTime() >= chat.readOnlyAt.getTime()) throw new DomainError('not_eligible');
    const stored = await tx.getMember(chatId, caller.uid);
    const profile = stored === null ? await deps.people.user(caller.uid) : null;
    const senderName = stored?.name ?? profile?.name ?? 'Ban tổ chức';
    const message: GroupMessage = {
      id: messageId, chatId, senderId: caller.uid, senderName, type: 'text', body: text,
      imagePath: null, point: null, system: null, createdAt: now, deletedAt: null,
    };
    tx.addMessage(message);
    tx.putChat(after(chat, message, now));
    tx.putPin(chatId, { messageId, body: text, senderName, pinnedBy: caller.uid, pinnedAt: now });
    return { messageId };
  });
}

/**
 * Whether the user should be in the group now: a moderator always; otherwise a `paid` registration,
 * and after a moderator removed them only one created after that removal (O1/M8: a new ticket
 * re-admits).
 */
export function shouldBeGroupMember(
  chat: Pick<GroupChat, 'moderators'>,
  member: Pick<GroupMember, 'removedAt' | 'removedBy'> | null,
  uid: string,
  paid: readonly PaidRegistration[],
): boolean {
  if (chat.moderators.includes(uid)) return true;
  const removedAt = member?.removedBy != null ? member.removedAt : null;
  if (removedAt === null) return paid.length > 0;
  return paid.some((p) => p.createdAt.getTime() > removedAt.getTime());
}

/** Writes the join (member doc, `members`, system line) inside a transaction, after all reads. */
function writeJoin(
  tx: EventChatTx,
  deps: EventChatDeps,
  chat: GroupChat,
  member: GroupMember | null,
  uid: string,
  who: { name: string; avatarUrl: string | null },
  now: Date,
): void {
  const members = chat.members.includes(uid) ? chat.members : [...chat.members, uid];
  tx.putMember(chat.id, {
    uid, role: chat.moderators.includes(uid) ? 'moderator' : 'member', name: who.name, avatarUrl: who.avatarUrl,
    mutedUntil: member?.mutedUntil ?? null, joinedAt: now, removedAt: null, removedBy: null,
    sentWindowStart: member?.sentWindowStart ?? null, sentInWindow: member?.sentInWindow ?? 0,
  });
  tx.putChat({ ...chat, members, memberCount: members.length, updatedAt: now });
  tx.addMessage({
    id: deps.ids.newId(), chatId: chat.id, senderId: null, senderName: null, type: 'system', body: null,
    imagePath: null, point: null, system: { kind: 'member_joined', userId: uid, name: who.name },
    createdAt: now, deletedAt: null,
  });
}

/**
 * Keeps the user's group membership in step with their registrations. The trigger's change is only
 * a wake-up (deliveries are at-least-once and unordered): the target state is derived inside the
 * transaction from the user's `paid` registrations now and the moderator removal (I1). Joining posts
 * a system line once; leaving keeps the member doc. The member's name is the profile display name,
 * falling back to the name typed on the registration (M7). Idempotent.
 */
export async function syncEventChatMembership(
  deps: EventChatDeps,
  change: { before: RegistrationDoc | null; after: RegistrationDoc | null },
): Promise<'joined' | 'left' | 'none'> {
  const { before, after: next } = change;
  const reg = next ?? before;
  // Only a change in "paid" can change membership; anything else is not even a wake-up.
  if (reg === null || (before?.status === 'paid') === (next?.status === 'paid')) return 'none';
  const chatId = eventChatId(reg.eventId);
  const uid = reg.userId;
  const profile = await deps.people.user(uid);

  return deps.chats.runTransaction(async (tx) => {
    const now = deps.clock.now();
    const chat = await tx.getChat(chatId);
    if (chat === null) return 'none';
    const member = await tx.getMember(chatId, uid);
    const paid = await tx.paidRegistrations(reg.eventId, uid);
    const inChat = chat.members.includes(uid);
    const should = shouldBeGroupMember(chat, member, uid, paid);

    if (should) {
      // In the chat with a live member doc (or a moderator still on the implicit one): nothing to do.
      if (inChat && (member === null ? chat.moderators.includes(uid) : member.removedAt === null)) return 'none';
      const latest = [...paid].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())[0];
      const name = profile?.name ?? latest?.userName ?? reg.userName;
      writeJoin(tx, deps, chat, member, uid, { name, avatarUrl: profile?.avatarUrl ?? latest?.userAvatarUrl ?? null }, now);
      return 'joined';
    }

    if (!inChat) return 'none';
    const members = chat.members.filter((u) => u !== uid);
    if (member !== null) tx.putMember(chatId, { ...member, removedAt: now, removedBy: member.removedBy });
    tx.putChat({ ...chat, members, memberCount: members.length, updatedAt: now });
    return 'left';
  });
}
