import { getFirestore } from 'firebase-admin/firestore';
import {
  newUlid,
  type ReviewDeps,
  type StatsStore,
} from '@photobooking/domain';
import { storageUrlPrefixes } from '../config.js';
import {
  FirestoreReviewStore,
  FirestoreStatsStore,
} from './review_firestore.js';

export function liveReviewDeps(): ReviewDeps {
  const db = getFirestore();
  return {
    reviews: new FirestoreReviewStore(db),
    clock: { now: () => new Date() },
    ids: { newId: () => newUlid(Date.now()) },
    storageUrlPrefixes: storageUrlPrefixes(),
  };
}

export function liveStatsStore(): StatsStore {
  const db = getFirestore();
  return new FirestoreStatsStore(db);
}
