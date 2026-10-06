import * as logger from 'firebase-functions/logger';
import type { NotifyDeps, PushSender } from '@photobooking/domain';
import { db as adminDb } from './admin.js';
import { FcmPushSender, FirestoreDeviceDirectory, LoggingPushSender } from './fcm_push.js';
import { FirestoreNotificationStore } from './notification_firestore.js';
import { FirestoreUserDirectory } from './user_directory.js';

export function livePushSender(): PushSender {
  if (process.env.FUNCTIONS_EMULATOR === 'true') return new LoggingPushSender();
  return new FcmPushSender(new FirestoreDeviceDirectory(adminDb()));
}

export function liveNotifyDeps(): NotifyDeps {
  const db = adminDb();
  return {
    store: new FirestoreNotificationStore(db),
    push: livePushSender(),
    users: new FirestoreUserDirectory(db),
    clock: { now: () => new Date() },
    onPushError: (uid, e) => {
      logger.warn('push failed', { uid, error: e instanceof Error ? e.name : 'unknown' });
    },
  };
}
