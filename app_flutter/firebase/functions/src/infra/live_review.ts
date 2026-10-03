import {
  newUlid,
  type ReviewDeps,
  type StatsStore,
} from '@photobooking/domain';
import { storageUrlPrefixes } from '../config.js';
import { db as adminDb } from './admin.js';
import {
  FirestoreReviewStore,
  FirestoreStatsStore,
} from './review_firestore.js';

export function liveReviewDeps(): ReviewDeps {
  const db = adminDb();
  return {
    reviews: new FirestoreReviewStore(db),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
    storageUrlPrefixes: storageUrlPrefixes(),
  };
}

export function liveStatsStore(): StatsStore {
  const db = adminDb();
  return new FirestoreStatsStore(db);
}
