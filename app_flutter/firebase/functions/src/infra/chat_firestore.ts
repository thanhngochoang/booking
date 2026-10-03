import { FieldValue, GeoPoint, Timestamp, type Firestore } from 'firebase-admin/firestore';
import {
  type Chat,
  type ChatStore,
  type ChatTx,
  type Message,
  type MessageType,
  type PhotographerInquiryReader,
  type RescheduleProposal,
  type SystemPayload,
} from '@photobooking/domain';

export function toFirestoreChat(chat: Chat): Record<string, unknown> {
  return {
    kind: chat.kind,
    customerId: chat.customerId,
    photographerId: chat.photographerId,
    members: [chat.customerId, chat.photographerId],
    bookingId: chat.bookingId ?? null,
    photographerRepliedAt: chat.photographerRepliedAt
      ? Timestamp.fromDate(chat.photographerRepliedAt)
      : null,
    customerMessagesBeforeReply: chat.customerMessagesBeforeReply,
    lastMessageAt: chat.lastMessageAt ? Timestamp.fromDate(chat.lastMessageAt) : null,
    lastMessagePreview: chat.lastMessagePreview ?? null,
    lastSenderId: chat.lastSenderId ?? null,
    readOnlyAt: chat.readOnlyAt ? Timestamp.fromDate(chat.readOnlyAt) : null,
    rescheduleUsed: chat.rescheduleUsed,
    createdAt: Timestamp.fromDate(chat.createdAt),
    updatedAt: Timestamp.fromDate(chat.updatedAt),
  };
}

export function fromFirestoreChat(id: string, data: Record<string, unknown>): Chat {
  const toDate = (v: unknown): Date | null => {
    if (v instanceof Timestamp) return v.toDate();
    if (typeof v === 'string' || typeof v === 'number') return new Date(v);
    return null;
  };

  return {
    id,
    kind: (data.kind as 'inquiry' | 'booking') || 'inquiry',
    customerId: String(data.customerId ?? ''),
    photographerId: String(data.photographerId ?? ''),
    bookingId: data.bookingId ? String(data.bookingId) : null,
    photographerRepliedAt: toDate(data.photographerRepliedAt),
    customerMessagesBeforeReply: Number(data.customerMessagesBeforeReply ?? 0),
    lastMessageAt: toDate(data.lastMessageAt),
    lastMessagePreview: data.lastMessagePreview ? String(data.lastMessagePreview) : null,
    lastSenderId: data.lastSenderId ? String(data.lastSenderId) : null,
    readOnlyAt: toDate(data.readOnlyAt),
    rescheduleUsed: Boolean(data.rescheduleUsed),
    createdAt: toDate(data.createdAt) ?? new Date(),
    updatedAt: toDate(data.updatedAt) ?? new Date(),
  };
}

export function toFirestoreSystem(system: SystemPayload | null): Record<string, unknown> | null {
  if (!system) return null;
  return {
    kind: system.kind,
    ...(system.status !== undefined ? { status: system.status } : {}),
    ...(system.proposal !== undefined ? { proposal: system.proposal } : {}),
    ...(system.answer !== undefined ? { answer: system.answer } : {}),
    ...(system.answeredBy !== undefined ? { answeredBy: system.answeredBy } : {}),
    ...(system.answeredAt ? { answeredAt: Timestamp.fromDate(system.answeredAt) } : {}),
  };
}

export function fromFirestoreSystem(
  data: Record<string, unknown> | null | undefined,
): SystemPayload | null {
  if (!data || typeof data !== 'object') return null;
  const toDate = (v: unknown): Date | undefined => {
    if (v instanceof Timestamp) return v.toDate();
    if (typeof v === 'string' || typeof v === 'number') return new Date(v);
    return undefined;
  };

  return {
    kind: (data.kind as 'booking_status' | 'reschedule_proposal') || 'booking_status',
    ...(data.status ? { status: String(data.status) } : {}),
    ...(data.proposal ? { proposal: data.proposal as RescheduleProposal } : {}),
    ...(data.answer ? { answer: data.answer as 'accepted' | 'declined' | 'expired' } : {}),
    ...(data.answeredBy ? { answeredBy: String(data.answeredBy) } : {}),
    ...(data.answeredAt ? { answeredAt: toDate(data.answeredAt) } : {}),
  };
}

export function toFirestoreMessage(m: Message): Record<string, unknown> {
  return {
    senderId: m.senderId ?? null,
    type: m.type,
    body: m.body ?? null,
    imagePath: m.imagePath ?? null,
    point: m.point ? new GeoPoint(m.point.lat, m.point.lng) : null,
    system: toFirestoreSystem(m.system),
    clientId: m.id,
    createdAt: Timestamp.fromDate(m.createdAt),
  };
}

export function fromFirestoreMessage(
  chatId: string,
  id: string,
  data: Record<string, unknown>,
): Message {
  const toDate = (v: unknown): Date => {
    if (v instanceof Timestamp) return v.toDate();
    if (typeof v === 'string' || typeof v === 'number') return new Date(v);
    return new Date();
  };

  let point: { lat: number; lng: number } | null = null;
  if (data.point instanceof GeoPoint) {
    point = { lat: data.point.latitude, lng: data.point.longitude };
  } else if (data.point && typeof data.point === 'object') {
    const p = data.point as { lat?: number; lng?: number; latitude?: number; longitude?: number };
    const lat = p.lat ?? p.latitude;
    const lng = p.lng ?? p.longitude;
    if (typeof lat === 'number' && typeof lng === 'number') {
      point = { lat, lng };
    }
  }

  return {
    id,
    chatId,
    senderId: data.senderId ? String(data.senderId) : null,
    type: (data.type as MessageType) || 'text',
    body: data.body ? String(data.body) : null,
    imagePath: data.imagePath ? String(data.imagePath) : null,
    point,
    system: fromFirestoreSystem(data.system as Record<string, unknown> | null | undefined),
    createdAt: toDate(data.createdAt),
  };
}

export class FirestorePhotographerInquiryReader implements PhotographerInquiryReader {
  constructor(private readonly db: Firestore) {}

  async acceptsInquiries(photographerId: string): Promise<boolean> {
    const snap = await this.db.collection('photographers').doc(photographerId).get();
    if (!snap.exists) return true;
    const data = snap.data();
    return data?.contactChannels?.acceptInquiries !== false;
  }
}

export class FirestoreChatStore implements ChatStore {
  constructor(private readonly db: Firestore) {}

  async runTransaction<T>(fn: (tx: ChatTx) => Promise<T>): Promise<T> {
    return this.db.runTransaction(async (fTx) => {
      const tx: ChatTx = {
        getChat: async (id: string): Promise<Chat | null> => {
          const snap = await fTx.get(this.db.collection('chats').doc(id));
          if (!snap.exists) return null;
          return fromFirestoreChat(snap.id, snap.data() as Record<string, unknown>);
        },
        getMessage: async (chatId: string, id: string): Promise<Message | null> => {
          const snap = await fTx.get(
            this.db.collection('chats').doc(chatId).collection('messages').doc(id),
          );
          if (!snap.exists) return null;
          return fromFirestoreMessage(chatId, snap.id, snap.data() as Record<string, unknown>);
        },
        setChat: (chat: Chat): void => {
          fTx.set(this.db.collection('chats').doc(chat.id), toFirestoreChat(chat), { merge: true });
        },
        addMessage: (m: Message): void => {
          fTx.set(
            this.db.collection('chats').doc(m.chatId).collection('messages').doc(m.id),
            toFirestoreMessage(m),
          );
        },
        updateMessageSystem: (chatId: string, id: string, system: SystemPayload): void => {
          fTx.update(
            this.db.collection('chats').doc(chatId).collection('messages').doc(id),
            { system: toFirestoreSystem(system) },
          );
        },
        incrementUnread: (chatId: string, uid: string, by: number): void => {
          fTx.set(
            this.db.collection('chats').doc(chatId).collection('members').doc(uid),
            { unreadCount: FieldValue.increment(by) },
            { merge: true },
          );
        },
      };

      return fn(tx);
    });
  }

  async pendingProposal(chatId: string): Promise<Message | null> {
    const snap = await this.db
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .where('type', '==', 'system')
      .where('system.kind', '==', 'reschedule_proposal')
      .orderBy('createdAt', 'desc')
      .limit(5)
      .get();

    for (const doc of snap.docs) {
      const msg = fromFirestoreMessage(chatId, doc.id, doc.data() as Record<string, unknown>);
      if (msg.system && !msg.system.answer) {
        return msg;
      }
    }
    return null;
  }
}
