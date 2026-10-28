/**
 * Production and emulator wiring of the S27 recruit ports (#151). `blocks` is #198's live BlockGate, set here
 * explicitly (apply, invite and invite answers check studio ↔ photographer blocks).
 */

import { newUlid, type CollabChatDeps, type RecruitDeps, type RecruitSweepDeps } from '@photobooking/domain';
import { db } from './admin.js';
import { FirestoreBookingStore } from './booking_firestore.js';
import { FirestoreProviderOrderGate } from './booking_readers.js';
import { liveChatDeps } from './live_chat.js';
import { liveNotifyDeps } from './live_notification.js';
import { liveBlockGate } from './live_safety.js';
import { liveStudioBookingDeps } from './live_studio.js';
import {
  FirestoreCollabBookingSync,
  FirestoreOwnedPosts,
  FirestoreRecruitPeople,
  FirestoreRecruitStore,
  FirestoreShootMilestones,
} from './recruit_firestore.js';

export function liveRecruitDeps(): RecruitDeps {
  const firestore = db();
  return {
    store: new FirestoreRecruitStore(firestore),
    people: new FirestoreRecruitPeople(firestore),
    orders: new FirestoreProviderOrderGate(firestore),
    blocks: liveBlockGate(),
    posts: new FirestoreOwnedPosts(firestore),
    milestones: new FirestoreShootMilestones(new FirestoreBookingStore(firestore)),
    notify: liveNotifyDeps(),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
  };
}

/** The recruit steps of bookingClock: recruit deps plus S26's booking deps for expiring collaborator offers. */
export function liveRecruitSweepDeps(): RecruitSweepDeps {
  return { ...liveRecruitDeps(), assign: liveStudioBookingDeps() };
}

/** `openCollabChat`: the chat deps plus the recruit store that holds the collaboration. */
export function liveCollabChatDeps(): CollabChatDeps {
  return { ...liveChatDeps(), recruit: new FirestoreRecruitStore(db()) };
}

export function liveCollabBookingSync(): FirestoreCollabBookingSync {
  return new FirestoreCollabBookingSync(db());
}
