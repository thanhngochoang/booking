import { DomainError } from './errors.js';

export const CHAT_KINDS = ['inquiry', 'booking'] as const;
export type ChatKind = (typeof CHAT_KINDS)[number];

export const MESSAGE_TYPES = ['text', 'image', 'location', 'system'] as const;
export type MessageType = (typeof MESSAGE_TYPES)[number];

export const INQUIRY_MAX_UNANSWERED = 3;
export const INQUIRY_CLOSE_DAYS = 14;
export const BOOKING_CHAT_READONLY_DAYS = 7;
export const MESSAGE_MAX_LENGTH = 2000;
export const PREVIEW_MAX_LENGTH = 80;

export interface Chat {
  readonly id: string;
  readonly kind: ChatKind;
  readonly customerId: string;
  readonly photographerId: string;
  readonly bookingId: string | null;
  readonly photographerRepliedAt: Date | null;
  readonly customerMessagesBeforeReply: number;
  readonly lastMessageAt: Date | null;
  readonly lastMessagePreview: string | null;
  readonly lastSenderId: string | null;
  readonly readOnlyAt: Date | null;
  readonly rescheduleUsed: boolean;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface RescheduleProposal {
  readonly day: string;
  readonly start: string;
  readonly end: string;
  readonly byRole: 'customer' | 'photographer';
}

export interface SystemPayload {
  readonly kind: 'booking_status' | 'reschedule_proposal';
  readonly status?: string; // BookingStatus code for booking_status
  readonly proposal?: RescheduleProposal;
  readonly answer?: 'accepted' | 'declined' | 'expired';
  readonly answeredBy?: string;
  readonly answeredAt?: Date;
}

export interface Message {
  readonly id: string;
  readonly chatId: string;
  readonly senderId: string | null;
  readonly type: MessageType;
  readonly body: string | null;
  readonly imagePath: string | null;
  readonly point: { lat: number; lng: number } | null;
  readonly system: SystemPayload | null;
  readonly createdAt: Date;
}

export const chatIdFor = (customerId: string, photographerId: string): string =>
  `${customerId}_${photographerId}`;

export function roleInChat(chat: Chat, uid: string): 'customer' | 'photographer' | null {
  if (uid === chat.customerId) return 'customer';
  if (uid === chat.photographerId) return 'photographer';
  return null;
}

export function previewOf(
  m: Pick<Message, 'type' | 'body'> & { system?: SystemPayload | null },
): string {
  if (m.type === 'image') return 'Ảnh';
  if (m.type === 'location') return 'Vị trí';
  if (m.type === 'system') {
    if (m.system?.kind === 'reschedule_proposal') {
      return 'Đề nghị đổi lịch';
    }
    return '';
  }
  if (m.type === 'text') {
    const trimmed = (m.body ?? '').trim();
    if (!trimmed) return '';
    const segments = [...new Intl.Segmenter().segment(trimmed)].map((s) => s.segment);
    if (segments.length <= PREVIEW_MAX_LENGTH) {
      return trimmed;
    }
    return segments.slice(0, PREVIEW_MAX_LENGTH).join('');
  }
  return '';
}

export function isInquiryClosed(chat: Chat, now: Date): boolean {
  if (chat.kind !== 'inquiry' || chat.lastMessageAt === null) {
    return false;
  }
  const closeTime = chat.lastMessageAt.getTime() + INQUIRY_CLOSE_DAYS * 24 * 60 * 60 * 1000;
  return now.getTime() >= closeTime;
}

export function assertCanSend(chat: Chat, senderId: string, now: Date): void {
  const role = roleInChat(chat, senderId);
  if (role === null) throw new DomainError('permission_denied');
  if (chat.readOnlyAt !== null && now.getTime() >= chat.readOnlyAt.getTime()) {
    throw new DomainError('not_eligible');
  }
  if (
    chat.kind === 'inquiry' &&
    role === 'customer' &&
    chat.photographerRepliedAt === null &&
    chat.customerMessagesBeforeReply >= INQUIRY_MAX_UNANSWERED
  ) {
    throw new DomainError('limit_exceeded');
  }
}

export function afterMessage(chat: Chat, m: Message, now: Date): Chat {
  let customerMessagesBeforeReply = chat.customerMessagesBeforeReply;
  let photographerRepliedAt = chat.photographerRepliedAt;

  if (chat.kind === 'inquiry') {
    if (m.senderId === chat.photographerId) {
      if (photographerRepliedAt === null) {
        photographerRepliedAt = now;
      }
    } else if (m.senderId === chat.customerId) {
      if (photographerRepliedAt === null) {
        customerMessagesBeforeReply += 1;
      }
    }
  }

  return {
    ...chat,
    photographerRepliedAt,
    customerMessagesBeforeReply,
    lastMessageAt: m.createdAt,
    lastMessagePreview: previewOf(m),
    lastSenderId: m.senderId,
    updatedAt: now,
  };
}

export function validateMessageInput(
  raw: unknown,
  senderId?: string,
): {
  type: 'text' | 'image' | 'location';
  body: string | null;
  imagePath: string | null;
  point: { lat: number; lng: number } | null;
  clientId: string;
} {
  if (!raw || typeof raw !== 'object') {
    throw new DomainError('invalid_argument');
  }
  const r = raw as Record<string, unknown>;
  const clientId = r.clientId;
  if (typeof clientId !== 'string' || !/^[A-Za-z0-9_-]{1,64}$/.test(clientId)) {
    throw new DomainError('invalid_argument');
  }

  const type = r.type;
  if (type === 'text') {
    const body = r.body;
    if (typeof body !== 'string') {
      throw new DomainError('invalid_argument');
    }
    const trimmed = body.trim();
    if (trimmed.length === 0 || trimmed.length > MESSAGE_MAX_LENGTH) {
      throw new DomainError('invalid_argument');
    }
    return {
      type: 'text',
      body: trimmed,
      imagePath: null,
      point: null,
      clientId,
    };
  }

  if (type === 'image') {
    const imagePath = r.imagePath;
    if (typeof imagePath !== 'string' || !imagePath.startsWith('chats/')) {
      throw new DomainError('invalid_argument');
    }
    const parts = imagePath.split('/');
    if (parts.length < 4) {
      throw new DomainError('invalid_argument');
    }
    if (senderId !== undefined && parts[2] !== senderId) {
      throw new DomainError('invalid_argument');
    }
    return {
      type: 'image',
      body: null,
      imagePath,
      point: null,
      clientId,
    };
  }

  if (type === 'location') {
    const point = r.point;
    if (!point || typeof point !== 'object') {
      throw new DomainError('invalid_argument');
    }
    const p = point as { lat?: unknown; lng?: unknown };
    if (typeof p.lat !== 'number' || typeof p.lng !== 'number') {
      throw new DomainError('invalid_argument');
    }
    if (
      Number.isNaN(p.lat) ||
      Number.isNaN(p.lng) ||
      !Number.isFinite(p.lat) ||
      !Number.isFinite(p.lng)
    ) {
      throw new DomainError('invalid_argument');
    }
    if (p.lat < -90 || p.lat > 90 || p.lng < -180 || p.lng > 180) {
      throw new DomainError('invalid_argument');
    }
    return {
      type: 'location',
      body: null,
      imagePath: null,
      point: { lat: p.lat, lng: p.lng },
      clientId,
    };
  }

  throw new DomainError('invalid_argument');
}
