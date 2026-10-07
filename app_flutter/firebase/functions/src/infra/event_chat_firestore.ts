import {
  GeoPoint,
  Timestamp,
  type DocumentData,
  type DocumentReference,
  type Firestore,
  type Transaction,
} from 'firebase-admin/firestore';
import type {
  PaidRegistration,
  EventChatStore,
  EventChatTx,
  GroupChat,
  GroupMember,
  GroupMessage,
  GroupPin,
} from '@photobooking/domain';
import { EVENTS_COLLECTION } from './event_firestore.js';

const CHATS = 'chats';

const ts = (d: Date | null): Timestamp | null => (d === null ? null : Timestamp.fromDate(d));
const str = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);

function date(v: unknown): Date | null {
  if (v instanceof Timestamp) return v.toDate();
  if (v instanceof Date) return v;
  return null;
}

const strings = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []);

/** The slice of a `paid` registration membership reads (I1, O1). */
export function paidRegistrationFrom(id: string, d: DocumentData): PaidRegistration {
  return {
    id,
    createdAt: date(d.createdAt) ?? new Date(0),
    userName: String(d.userName ?? ''),
    userAvatarUrl: str(d.userAvatarUrl),
  };
}

export function groupChatDoc(c: GroupChat): DocumentData {
  return {
    kind: 'event_group',
    eventId: c.eventId,
    title: c.title,
    members: [...c.members],
    moderators: [...c.moderators],
    memberCount: c.memberCount,
    moderatorsOnly: c.moderatorsOnly,
    lastMessageAt: ts(c.lastMessageAt),
    lastMessagePreview: c.lastMessagePreview,
    lastSenderId: c.lastSenderId,
    readOnlyAt: ts(c.readOnlyAt),
    createdAt: Timestamp.fromDate(c.createdAt),
    updatedAt: Timestamp.fromDate(c.updatedAt),
  };
}

export function groupChatFrom(id: string, d: DocumentData): GroupChat | null {
  if (d.kind !== 'event_group') return null;
  const members = strings(d.members);
  return {
    id,
    eventId: String(d.eventId ?? ''),
    title: String(d.title ?? ''),
    members,
    moderators: strings(d.moderators),
    memberCount: typeof d.memberCount === 'number' ? d.memberCount : members.length,
    moderatorsOnly: d.moderatorsOnly === true,
    lastMessageAt: date(d.lastMessageAt),
    lastMessagePreview: str(d.lastMessagePreview),
    lastSenderId: str(d.lastSenderId),
    readOnlyAt: date(d.readOnlyAt),
    createdAt: date(d.createdAt) ?? new Date(0),
    updatedAt: date(d.updatedAt) ?? new Date(0),
  };
}

/** Server-owned fields only: the client owns `unreadCount` and `lastReadAt` on the same document. */
export function groupMemberDoc(m: GroupMember): DocumentData {
  return {
    role: m.role,
    name: m.name,
    avatarUrl: m.avatarUrl,
    mutedUntil: ts(m.mutedUntil),
    joinedAt: Timestamp.fromDate(m.joinedAt),
    removedAt: ts(m.removedAt),
    removedBy: m.removedBy,
    sentWindowStart: ts(m.sentWindowStart),
    sentInWindow: m.sentInWindow,
  };
}

export function groupMemberFrom(uid: string, d: DocumentData): GroupMember {
  return {
    uid,
    role: d.role === 'moderator' ? 'moderator' : 'member',
    name: String(d.name ?? ''),
    avatarUrl: str(d.avatarUrl),
    mutedUntil: date(d.mutedUntil),
    joinedAt: date(d.joinedAt) ?? new Date(0),
    removedAt: date(d.removedAt),
    removedBy: str(d.removedBy),
    sentWindowStart: date(d.sentWindowStart),
    sentInWindow: typeof d.sentInWindow === 'number' ? d.sentInWindow : 0,
  };
}

export function groupMessageDoc(m: GroupMessage): DocumentData {
  return {
    senderId: m.senderId,
    senderName: m.senderName,
    type: m.type,
    body: m.body,
    imagePath: m.imagePath,
    point: m.point === null ? null : new GeoPoint(m.point.lat, m.point.lng),
    system: m.system === null ? null : { kind: m.system.kind, userId: m.system.userId, name: m.system.name },
    clientId: m.id,
    createdAt: Timestamp.fromDate(m.createdAt),
    deletedAt: ts(m.deletedAt),
  };
}

export function groupMessageFrom(chatId: string, id: string, d: DocumentData): GroupMessage {
  const p: unknown = d.point;
  let point: GroupMessage['point'] = null;
  if (p instanceof GeoPoint) point = { lat: p.latitude, lng: p.longitude };
  const sys = typeof d.system === 'object' && d.system !== null ? (d.system as Record<string, unknown>) : null;
  const type = d.type === 'image' || d.type === 'location' || d.type === 'system' ? d.type : 'text';
  return {
    id,
    chatId,
    senderId: str(d.senderId),
    senderName: str(d.senderName),
    type,
    body: str(d.body),
    imagePath: str(d.imagePath),
    point,
    system: sys !== null && sys.kind === 'member_joined'
      ? { kind: 'member_joined', userId: String(sys.userId ?? ''), name: String(sys.name ?? '') }
      : null,
    createdAt: date(d.createdAt) ?? new Date(0),
    deletedAt: date(d.deletedAt),
  };
}

export function groupPinDoc(p: GroupPin): DocumentData {
  return { body: p.body, senderName: p.senderName, pinnedBy: p.pinnedBy, pinnedAt: Timestamp.fromDate(p.pinnedAt) };
}

/**
 * The event group chat in Firestore (`chats/event_{eventId}` + members, messages, pins). Reads go
 * straight to the transaction; every write is buffered until the callback has finished all its
 * reads, then applied together.
 */
export class FirestoreEventChatStore implements EventChatStore {
  constructor(private readonly firestore: Firestore) {}

  runTransaction<T>(fn: (tx: EventChatTx) => Promise<T>): Promise<T> {
    const fs = this.firestore;
    return fs.runTransaction(async (fTx: Transaction) => {
      const chatRef = (id: string): DocumentReference => fs.collection(CHATS).doc(id);
      const writes: Array<() => void> = [];

      const tx: EventChatTx = {
        getChat: async (id) => {
          const s = await fTx.get(chatRef(id));
          const d = s.data();
          return s.exists && d ? groupChatFrom(id, d) : null;
        },
        getMember: async (chatId, uid) => {
          const s = await fTx.get(chatRef(chatId).collection('members').doc(uid));
          const d = s.data();
          // A doc with only the client's read marker (no role) is not a member record.
          return s.exists && d && d.role !== undefined ? groupMemberFrom(uid, d) : null;
        },
        getMessage: async (chatId, id) => {
          const s = await fTx.get(chatRef(chatId).collection('messages').doc(id));
          const d = s.data();
          return s.exists && d ? groupMessageFrom(chatId, id, d) : null;
        },
        paidRegistrations: async (eventId, uid) => {
          const q = fs.collection(EVENTS_COLLECTION).doc(eventId).collection('registrations')
            .where('userId', '==', uid).where('status', '==', 'paid');
          return (await fTx.get(q)).docs.map((d) => paidRegistrationFrom(d.id, d.data()));
        },
        putChat: (c) => {
          writes.push(() => fTx.set(chatRef(c.id), groupChatDoc(c), { merge: true }));
        },
        putMember: (chatId, m) => {
          writes.push(() => fTx.set(chatRef(chatId).collection('members').doc(m.uid), groupMemberDoc(m), { merge: true }));
        },
        addMessage: (m) => {
          writes.push(() => fTx.set(chatRef(m.chatId).collection('messages').doc(m.id), groupMessageDoc(m)));
        },
        updateMessage: (m) => {
          writes.push(() => fTx.set(chatRef(m.chatId).collection('messages').doc(m.id), groupMessageDoc(m)));
        },
        putPin: (chatId, p) => {
          writes.push(() => fTx.set(chatRef(chatId).collection('pins').doc(p.messageId), groupPinDoc(p)));
        },
        deletePin: (chatId, messageId) => {
          writes.push(() => fTx.delete(chatRef(chatId).collection('pins').doc(messageId)));
        },
      };

      const result = await fn(tx);
      for (const w of writes) w();
      return result;
    });
  }
}
