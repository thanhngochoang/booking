/**
 * What a write of `instant_requests/{id}` tells people (plan #140 Decision 20, 21): the pure decider
 * of #138's seven instant hooks (recipients, copy, targets and dedupe keys are the hooks'), the offer
 * push (push only, no inbox row), the pair chat and the track clean-up. `onInstantRequestWrite`
 * (Functions, Task 5) is the only caller.
 */
import { BOOKING_CHAT_READONLY_DAYS, chatIdFor, type Chat } from './chat.js';
import type { ChatDeps } from './chat_ports.js';
import type { InstantGenre, InstantOffer, InstantRequest } from './instant.js';
import type { PushMessage } from './notification_ports.js';
import { formatVnd } from './notification_render.js';

export type InstantNotice =
  | { hook: 'assigned' }
  | { hook: 'round_ended'; round: number }
  | { hook: 'no_match'; round: number }
  | { hook: 'arrived' }
  | { hook: 'finished' }
  | { hook: 'cancelled'; by: 'customer' | 'photographer'; photographerId: string; feeVnd: number }
  | { hook: 'missed'; photographerId: string; offerId: string };

const ASSIGNED_STATUSES: readonly InstantRequest['status'][] = ['assigned', 'en_route', 'arrived'];

const entered = (before: InstantRequest | null, after: InstantRequest, status: InstantRequest['status']): boolean =>
  after.status === status && before?.status !== status;

/**
 * Every chosen person was unavailable when the offers went out: the round ended inside the
 * customer's own invite call, which answers it on screen, so no inbox row.
 */
const allUnavailable = (r: InstantRequest): boolean => r.offers.length > 0 && r.offers.every((o) => o.outcome === 'unavailable');

/** The notices of one write, in a stable order. A write that changes nothing visible gives none. */
export function instantNotices(before: InstantRequest | null, after: InstantRequest | null): InstantNotice[] {
  if (after === null) return [];
  const out: InstantNotice[] = [];
  if (before !== null) {
    for (const row of before.offers) {
      if (row.outcome !== 'pending' || row.offerId === null) continue;
      const now = after.offers.find((o) => o.offerId === row.offerId);
      // Expired in this write, or expired and dropped by a round reset in the same write.
      const missed = now === undefined
        ? row.expiresAt !== null && row.expiresAt.getTime() <= after.updatedAt.getTime()
        : now.outcome === 'expired';
      if (missed) out.push({ hook: 'missed', photographerId: row.photographerId, offerId: row.offerId });
    }
  }
  if (entered(before, after, 'assigned') && after.photographerId !== null) out.push({ hook: 'assigned' });
  const photographerCancelled = before !== null && before.photographerId !== null && ASSIGNED_STATUSES.includes(before.status)
    && after.status === 'choosing' && after.cancelledBy === 'photographer';
  if (photographerCancelled) {
    out.push({ hook: 'cancelled', by: 'photographer', photographerId: before.photographerId as string, feeVnd: 0 });
  } else if (after.roundEnded && before?.roundEnded !== true && !allUnavailable(after)) {
    out.push({ hook: 'round_ended', round: after.round });
  }
  if (entered(before, after, 'no_match')) out.push({ hook: 'no_match', round: after.round });
  if (entered(before, after, 'arrived')) out.push({ hook: 'arrived' });
  if (entered(before, after, 'finished')) out.push({ hook: 'finished' });
  if (entered(before, after, 'cancelled_by_customer') && after.photographerId !== null) {
    out.push({ hook: 'cancelled', by: 'customer', photographerId: after.photographerId, feeVnd: after.feeVnd ?? 0 });
  }
  return out;
}

const GENRE_LABEL: Readonly<Record<InstantGenre, string>> = {
  portrait: 'Chân dung',
  couple: 'Cặp đôi',
  family: 'Gia đình',
  event: 'Sự kiện nhỏ',
  product: 'Sản phẩm',
};

/** 30 → "30 phút", 60 → "1 giờ", 90 → "1 giờ 30 phút". */
export function instantDurationText(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m} phút`;
  return m === 0 ? `${h} giờ` : `${h} giờ ${m} phút`;
}

/**
 * The offer push (S14.02): high priority (`default`) even in quiet hours, opens the offer. Never the
 * meet point, only the area (spec §9).
 */
export function offerPushMessage(offer: InstantOffer): PushMessage {
  return {
    title: 'Lời mời chụp ngay',
    body: `${GENRE_LABEL[offer.genre]} ${instantDurationText(offer.durationMin)} · ${offer.areaLabel} · bạn nhận ${formatVnd(offer.earningVnd)}. Còn 60 giây.`,
    channel: 'default',
    data: { type: 'instant_offer', target: `/work/instant/offer/${offer.id}` },
  };
}

/** The track goes when the request leaves `en_route` (arrival, cancel, any end; Decision 11). */
export function instantTrackShouldGo(before: InstantRequest | null, after: InstantRequest | null): boolean {
  return before?.status === 'en_route' && after?.status !== 'en_route';
}

const DAY_MS = 86_400_000;

/**
 * The pair chat of an instant job (Decision 21). On assignment: created as a booking-kind chat, or an
 * inquiry (or read-only) chat upgraded so the inquiry limits do not block the job. When the job of the
 * pair ends (the request ends, or the photographer cancels) a chat not attached to a booking becomes
 * read-only 7 days later.
 */
export async function syncInstantChat(
  deps: ChatDeps,
  before: InstantRequest | null,
  after: InstantRequest | null,
): Promise<'created' | 'upgraded' | 'closed' | 'none'> {
  if (after === null) return 'none';
  const was = before?.photographerId ?? null;
  const now = deps.clock.now();
  if (was === null && after.photographerId !== null && after.active) {
    const photographerId = after.photographerId;
    const chatId = chatIdFor(after.customerId, photographerId);
    return deps.chats.runTransaction(async (tx) => {
      const chat = await tx.getChat(chatId);
      if (chat === null) {
        const created: Chat = {
          id: chatId, kind: 'booking', customerId: after.customerId, photographerId, assigneeId: null,
          bookingId: null, bookingStatus: null, photographerRepliedAt: null, customerMessagesBeforeReply: 0,
          lastMessageAt: null, lastMessagePreview: null, lastSenderId: null, readOnlyAt: null, blockedAt: null,
          rescheduleUsed: false, createdAt: now, updatedAt: now,
        };
        tx.setChat(created);
        tx.incrementUnread(chatId, after.customerId, 0);
        tx.incrementUnread(chatId, photographerId, 0);
        return 'created';
      }
      if (chat.kind === 'booking' && chat.readOnlyAt === null) return 'none'; // an open booking chat serves the job too
      // An inquiry, or a booking chat that is read-only or closing: it becomes this job's chat, detached
      // from any earlier booking (as openInquiry does) so the end of the job can close it again.
      tx.setChat({ ...chat, kind: 'booking', bookingId: null, bookingStatus: null, assigneeId: null, readOnlyAt: null, updatedAt: now });
      return 'upgraded';
    });
  }
  const ended = before !== null && before.active && !after.active && after.photographerId !== null;
  const dropped = was !== null && after.photographerId === null;
  if (!ended && !dropped) return 'none';
  const photographerId = ended ? (after.photographerId as string) : was;
  if (photographerId === null) return 'none';
  const chatId = chatIdFor(after.customerId, photographerId);
  return deps.chats.runTransaction(async (tx) => {
    const chat = await tx.getChat(chatId);
    if (chat === null || chat.bookingId !== null || chat.readOnlyAt !== null) return 'none';
    tx.setChat({ ...chat, readOnlyAt: new Date(now.getTime() + BOOKING_CHAT_READONLY_DAYS * DAY_MS), updatedAt: now });
    return 'closed';
  });
}
