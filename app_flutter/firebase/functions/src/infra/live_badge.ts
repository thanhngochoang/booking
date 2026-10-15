import type { BadgeDeps } from '@photobooking/domain';
import { db as adminDb } from './admin.js';
import { FirestoreBadgeMetricsReader, FirestoreBadgeStore } from './badge_firestore.js';
import { liveNotifyDeps } from './live_notification.js';

export function liveBadgeDeps(): BadgeDeps {
  const db = adminDb();
  return {
    badges: new FirestoreBadgeStore(db),
    metrics: new FirestoreBadgeMetricsReader(db),
    notify: liveNotifyDeps(),
    clock: { now: () => new Date() },
  };
}
