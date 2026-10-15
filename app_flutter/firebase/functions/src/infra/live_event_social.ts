import { newUlid, type EventChatDeps, type TimelineDeps } from '@photobooking/domain';
import { storageUrlPrefixes } from '../config.js';
import { db } from './admin.js';
import { FirestoreEventChatStore } from './event_chat_firestore.js';
import { firestoreEventPeople } from './event_firestore.js';
import { FirestoreEventTimelineStore, firestoreTimelinePeople, ownPostImage } from './event_timeline_firestore.js';

export function liveTimelineDeps(): TimelineDeps {
  const firestore = db();
  return {
    timeline: new FirestoreEventTimelineStore(firestore),
    people: firestoreTimelinePeople(firestore),
    media: { isOwnPostImage: ownPostImage(storageUrlPrefixes()) },
    clock: { now: () => new Date() },
  };
}

export function liveEventChatDeps(): EventChatDeps {
  const firestore = db();
  return {
    chats: new FirestoreEventChatStore(firestore),
    people: { user: (uid) => firestoreEventPeople(firestore).user(uid) },
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}
