import type { EventCaller } from '../../src/event.js';
import type { GroupChat, GroupMember } from '../../src/event_chat.js';
import type { EventChatDeps } from '../../src/event_chat_ports.js';
import type { TimelineDeps } from '../../src/event_timeline_ports.js';
import { MemoryEventChatStore } from '../../src/memory_event_chat_store.js';
import { MemoryEventTimelineStore } from '../../src/memory_event_timeline_store.js';
import { FakeClock, FakeIdGenerator } from './chat_world.js';
import { T0, eventRecord, registrationDoc } from './event_world.js';

export { T0, eventRecord, registrationDoc };

export const EV = 'evX';
export const CHAT = 'event_evX';

export interface TimelineWorld {
  readonly deps: TimelineDeps;
  readonly store: MemoryEventTimelineStore;
  readonly clock: FakeClock;
}

const photographers = new Set(['ph1', 'ph2', 'ph9']);

export function createTimelineWorld(): TimelineWorld {
  const store = new MemoryEventTimelineStore();
  const clock = new FakeClock(T0);
  const deps: TimelineDeps = {
    timeline: store,
    people: {
      author: async (uid) => ({ name: `Tên ${uid}`, isPhotographer: photographers.has(uid) }),
    },
    media: { isOwnPostImage: (url, path, uid, postId) => path.startsWith(`posts/${uid}/${postId}/`) && url.endsWith(path) },
    clock,
  };
  store.seedEvent(eventRecord({ id: EV, hashtag: 'PhotoWalk1004', hashtagKey: 'photowalk1004' }));
  return { deps, store, clock };
}

export const post = (id: string, authorId: string, hashtags: string[], over: Record<string, unknown> = {}) => ({
  id, authorId, kind: 'work', hashtags, eventId: null,
  imageUrls: [`https://s.test/posts/${authorId}/${id}/a.jpg`, `https://s.test/posts/${authorId}/${id}/b.jpg`],
  imageW: 800, imageH: 1200, ...over,
});

export const shareImages = (uid: string, postId: string, n = 2) =>
  Array.from({ length: n }, (_, i) => ({
    url: `https://s.test/posts/${uid}/${postId}/${i}.jpg`,
    path: `posts/${uid}/${postId}/${i}.jpg`,
    w: 800, h: 600,
  }));

export interface ChatWorld {
  readonly deps: EventChatDeps;
  readonly store: MemoryEventChatStore;
  readonly clock: FakeClock;
}

export const chatSeed = (over: Partial<GroupChat> = {}): GroupChat => ({
  id: CHAT, eventId: EV, title: 'Photo walk', members: ['ph1'], moderators: ['ph1'], memberCount: 1,
  moderatorsOnly: false, lastMessageAt: null, lastMessagePreview: null, lastSenderId: null, readOnlyAt: null,
  createdAt: T0, updatedAt: T0, ...over,
});

export const memberSeed = (uid: string, over: Partial<GroupMember> = {}): GroupMember => ({
  uid, role: 'member', name: `Tên ${uid}`, avatarUrl: null, mutedUntil: null, joinedAt: T0, removedAt: null,
  removedBy: null, sentWindowStart: null, sentInWindow: 0, ...over,
});

export const mod: EventCaller = { uid: 'ph1', staffRole: null };

export function createChatWorld(): ChatWorld {
  const store = new MemoryEventChatStore();
  const clock = new FakeClock(T0);
  const deps: EventChatDeps = {
    chats: store,
    people: { user: async (uid) => ({ name: `Tên ${uid}`, avatarUrl: null }) },
    clock,
    ids: new FakeIdGenerator(),
  };
  store.seedChat(chatSeed({ members: ['ph1', 'cu1', 'cu2'], memberCount: 3 }));
  store.seedMember(CHAT, memberSeed('ph1', { role: 'moderator' }));
  store.seedMember(CHAT, memberSeed('cu1'));
  store.seedMember(CHAT, memberSeed('cu2'));
  // cu1 and cu2 hold a paid ticket (membership is derived from them).
  store.seedPaid(EV, 'cu1', 'rg_cu1', { createdAt: new Date(T0.getTime() - 86_400_000) });
  store.seedPaid(EV, 'cu2', 'rg_cu2', { createdAt: new Date(T0.getTime() - 86_400_000) });
  return { deps, store, clock };
}

export const text = (clientId: string, body = 'xin chào') => ({ eventId: EV, message: { clientId, type: 'text', body } });
