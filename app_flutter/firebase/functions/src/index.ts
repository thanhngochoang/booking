import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { Timestamp } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { handleGetContactLink } from './callables/get_contact_link.js';
import {
  handleCreateBooking,
  handleCreateDeposit,
  handleConfirmFakePayment,
  handleCheckDeposit,
  handleTransitionBooking,
  handleOpenDispute,
} from './callables/booking.js';
import {
  handleOpenInquiry,
  handleSendMessage,
  handleProposeReschedule,
  handleAnswerReschedule,
} from './callables/chat.js';
import { CALLABLE_OPTIONS, SCHEDULE_OPTIONS, TRIGGER_OPTIONS } from './config.js';
import { liveContactDeps } from './infra/live.js';
import { liveSkillsDeps } from './infra/live_skills.js';
import { liveBookingDeps } from './infra/live_booking.js';
import { liveChatDeps } from './infra/live_chat.js';
import { handleBookingClock } from './scheduled/booking_clock.js';
import { handlePhotographerEvent } from './triggers/photographer_write.js';
import { handleBookingWrite } from './triggers/booking_write.js';
import { handleSubmitReview } from './callables/review.js';
import { handleReviewWrite } from './triggers/review_write.js';
import { liveReviewDeps, liveStatsStore } from './infra/live_review.js';
import { handleSetProviderType, handleSetStudioAddress } from './callables/provider.js';
import { liveProviderDeps } from './infra/live_provider.js';
import {
  handleCreateAlbum,
  handleDeleteAlbum,
  handleMovePostsToAlbum,
  handleReorderAlbumPosts,
  handleReorderAlbums,
  handleUpdateAlbum,
} from './callables/album.js';
import { handlePostCreated } from './triggers/post_created.js';
import { liveAlbumDeps } from './infra/live_album.js';
import {
  handleCreateAward,
  handleDeleteAward,
  handleReviewAward,
  handleUpdateAward,
} from './callables/award.js';
import { handleAwardWrite } from './triggers/award_write.js';
import { handleAwardPurge } from './scheduled/award_purge.js';
import { liveAwardDeps } from './infra/live_award.js';
import { evaluateUserBadges } from '@photobooking/domain';
import { handleMarkAllNotificationsRead } from './callables/notification.js';
import { FirestoreDeviceDirectory } from './infra/fcm_push.js';
import { liveBadgeDeps } from './infra/live_badge.js';
import { liveNotifyDeps } from './infra/live_notification.js';
import { db } from './infra/admin.js';
import { handleChatMemberWrite } from './triggers/chat_member_write.js';
import { handleChatMessageCreated } from './triggers/chat_message_created.js';
import { handleDeviceWrite } from './triggers/device_write.js';
import { handleNotificationWrite } from './triggers/notification_write.js';
import { handleServiceWrite } from './triggers/service_write.js';
import { handleUserCreated } from './triggers/user_created.js';
import { evaluatePostAuthor } from './triggers/post_created.js';
import { handleReconcileBadges } from './scheduled/reconcile_badges.js';
import { handlePruneNotifications } from './scheduled/prune_notifications.js';
import { liveReminderDeps } from './scheduled/booking_clock.js';

// Entry point of the Cloud Functions codebase. Each export is one deployed function.

/** `{bookingId | registrationId, channel}` → `{url}`; contract in plan 2b "Out of scope". */
export const getContactLink = onCall(CALLABLE_OPTIONS, (request) => handleGetContactLink(request, liveContactDeps()));

/** Booking creation draft */
export const createBooking = onCall(CALLABLE_OPTIONS, (request) => handleCreateBooking(request, liveBookingDeps()));

/** Deposit payment intent creation */
export const createDeposit = onCall(CALLABLE_OPTIONS, (request) => handleCreateDeposit(request, liveBookingDeps()));

/** Fake payment confirmation (dev/test) */
export const confirmFakePayment = onCall(CALLABLE_OPTIONS, (request) => handleConfirmFakePayment(request, liveBookingDeps()));

/** Check deposit payment status */
export const checkDeposit = onCall(CALLABLE_OPTIONS, (request) => handleCheckDeposit(request, liveBookingDeps()));

/** Booking lifecycle transition */
export const transitionBooking = onCall(CALLABLE_OPTIONS, (request) => handleTransitionBooking(request, liveBookingDeps()));

/** Open dispute on completed/upcoming booking */
export const openDispute = onCall(CALLABLE_OPTIONS, (request) => handleOpenDispute(request, liveBookingDeps()));

/** 15-minute booking lifecycle and escrow sweep clock */
export const bookingClock = onSchedule({ ...SCHEDULE_OPTIONS, timeoutSeconds: 300 }, async () => {
  await handleBookingClock(undefined, liveReminderDeps());
});

/**
 * Scores `photographers/{uid}.skills` ("Độ khớp hồ sơ") and removes evidence that is not the
 * photographer's own post (spec 2026-10-02-photographer-write-function-design.md). Events older than
 * 1 hour and permanent Firestore errors end without a retry (handlePhotographerEvent).
 */
export const onPhotographerWrite = onDocumentWritten({ ...TRIGGER_OPTIONS, document: 'photographers/{uid}' }, async (event) => {
  const uid = event.params.uid;
  const after = event.data?.after;
  const live = after?.exists === true ? after : undefined;
  await handlePhotographerEvent({ uid, time: event.time, before: event.data?.before.data(), after: live?.data() }, () =>
    liveSkillsDeps(uid, live?.updateTime),
  );
  // `fast_reply` follows stats.responseMinutes (written by the server only).
  if (live !== undefined && live.get('stats.responseMinutes') !== event.data?.before.get('stats.responseMinutes')) {
    await evaluateUserBadges(liveBadgeDeps(), uid);
  }
});

/** Open chat inquiry between customer and photographer */
export const openInquiry = onCall(CALLABLE_OPTIONS, (request) =>
  handleOpenInquiry(request, liveChatDeps()),
);

/** Send chat message (text, image, location) */
export const sendMessage = onCall(CALLABLE_OPTIONS, (request) =>
  handleSendMessage(request, liveChatDeps()),
);

/** Propose reschedule for an accepted or upcoming booking */
export const proposeReschedule = onCall(CALLABLE_OPTIONS, (request) =>
  handleProposeReschedule(request, liveChatDeps()),
);

/** Answer reschedule proposal (accept or decline) */
export const answerReschedule = onCall(CALLABLE_OPTIONS, (request) =>
  handleAnswerReschedule(request, liveChatDeps()),
);

/** Sync chat status and read-only windows with booking writes */
export const onBookingWrite = onDocumentWritten(
  { ...TRIGGER_OPTIONS, document: 'bookings/{bookingId}' },
  async (event) => {
    const bookingId = event.params.bookingId;
    const before = event.data?.before.exists ? (event.data.before.data() as Record<string, unknown>) : undefined;
    const after = event.data?.after.exists ? (event.data.after.data() as Record<string, unknown>) : undefined;
    await handleBookingWrite({ id: bookingId, before, after }, liveChatDeps(), undefined, {
      notify: liveNotifyDeps(),
      badges: liveBadgeDeps(),
    });
  },
);

/** Submit review and optionally share real shoot photos */
export const submitReview = onCall(CALLABLE_OPTIONS, (request) =>
  handleSubmitReview(request, liveReviewDeps()),
);

/** Fold review rating into photographer stats */
export const onReviewWrite = onDocumentWritten(
  { ...TRIGGER_OPTIONS, document: 'reviews/{bookingId}' },
  async (event) => {
    const bookingId = event.params.bookingId;
    const before = event.data?.before.exists ? (event.data.before.data() as Record<string, unknown>) : undefined;
    const after = event.data?.after.exists ? (event.data.after.data() as Record<string, unknown>) : undefined;
    await handleReviewWrite(
      { bookingId, before, after },
      liveStatsStore(),
      new Date(),
      liveBadgeDeps(),
    );
  },
);


/** Provider picks individual or studio (`{type}` → `{providerType}`); refused with open work or held money. */
export const setProviderType = onCall(CALLABLE_OPTIONS, (request) =>
  handleSetProviderType(request, liveProviderDeps()),
);

/** Studio saves its private address; the district and city go public. */
export const setStudioAddress = onCall(CALLABLE_OPTIONS, (request) =>
  handleSetStudioAddress(request, liveProviderDeps()),
);

// ---- portfolio albums (plan C) ----

/** `{title, description?}` → `{albumId}`; limit_exceeded at 30 albums, conflict on a duplicate title. */
export const createAlbum = onCall(CALLABLE_OPTIONS, (request) => handleCreateAlbum(request, liveAlbumDeps()));

/** `{albumId, title?, description?, cover?}` */
export const updateAlbum = onCall(CALLABLE_OPTIONS, (request) => handleUpdateAlbum(request, liveAlbumDeps()));

/** `{albumId}`: its posts go back to the timeline only. */
export const deleteAlbum = onCall(CALLABLE_OPTIONS, (request) => handleDeleteAlbum(request, liveAlbumDeps()));

/** `{albumIds}`: exactly the caller's albums, in the new order. */
export const reorderAlbums = onCall(CALLABLE_OPTIONS, (request) => handleReorderAlbums(request, liveAlbumDeps()));

/** `{albumId | null, postIds}`: moves 1–50 of the caller's work posts. */
export const movePostsToAlbum = onCall(CALLABLE_OPTIONS, (request) =>
  handleMovePostsToAlbum(request, liveAlbumDeps()),
);

/** `{albumId, postIds}`: exactly the album's posts, in the new order. */
export const reorderAlbumPosts = onCall(CALLABLE_OPTIONS, (request) =>
  handleReorderAlbumPosts(request, liveAlbumDeps()),
);

/** A new post that names an album lands last in it, or is detached when the album is not usable. */
export const onPostCreated = onDocumentCreated({ ...TRIGGER_OPTIONS, document: 'posts/{postId}' }, async (event) => {
  if (typeof event.data?.get('albumId') === 'string') await handlePostCreated(event.params.postId, liveAlbumDeps());
  await evaluatePostAuthor(event.data?.get('authorId'), liveBadgeDeps());
});

// ---- awards and the NAG tier (plan B1) ----

/** `{awardId, competition, year, category?, result, workPostId?, proofFiles?, proofLinks?}` → `{awardId}`; limit_exceeded at 50. */
export const createAward = onCall(CALLABLE_OPTIONS, (request) => handleCreateAward(request, liveAwardDeps()));

/** Owner edit; a content change sends a reviewed award back to `pending`. */
export const updateAward = onCall(CALLABLE_OPTIONS, (request) => handleUpdateAward(request, liveAwardDeps()));

/** `{awardId}`: deletes the award, its proof doc and files. */
export const deleteAward = onCall(CALLABLE_OPTIONS, (request) => handleDeleteAward(request, liveAwardDeps()));

/** Staff only (claim `staffRole: 'admin'`): `{awardId, action, note?}` → `{status}`. */
export const reviewAward = onCall(CALLABLE_OPTIONS, (request) => handleReviewAward(request, liveAwardDeps()));

/** Recomputes the artist tier for the before and after owner of every award write. */
export const onAwardWrite = onDocumentWritten({ ...TRIGGER_OPTIONS, document: 'awards/{awardId}' }, async (event) => {
  const before = event.data?.before.exists ? event.data.before.data() : undefined;
  const after = event.data?.after.exists ? event.data.after.data() : undefined;
  await handleAwardWrite(before, after, liveAwardDeps());
});

/** Daily 03:00 Asia/Ho_Chi_Minh: deletes proofs 30 days after a final decision. */
export const purgeAwardProofs = onSchedule(
  { ...SCHEDULE_OPTIONS, schedule: 'every day 03:00', timeoutSeconds: 300 },
  async () => {
    await handleAwardPurge();
  },
);

// ---- notifications and badges (plan 10a) ----

/** `{}` → `{marked}`: marks every unread inbox row read and zeroes the unread count. */
export const markAllNotificationsRead = onCall(CALLABLE_OPTIONS, (request) =>
  handleMarkAllNotificationsRead(request, liveNotifyDeps()),
);

/** Keeps `users/{uid}/private/inbox.unreadCount` equal to the number of unread rows. */
export const onNotificationWrite = onDocumentWritten(
  { ...TRIGGER_OPTIONS, document: 'users/{uid}/notifications/{id}' },
  async (event) => {
    await handleNotificationWrite(
      event.params.uid,
      event.data?.before.exists ? event.data.before.data() : undefined,
      event.data?.after.exists ? event.data.after.data() : undefined,
      liveNotifyDeps(),
    );
  },
);

/** A chat message notifies the other member (grouped per chat); system messages never do. */
export const onChatMessageCreated = onDocumentCreated(
  { ...TRIGGER_OPTIONS, document: 'chats/{chatId}/messages/{messageId}' },
  async (event) => {
    const message = event.data?.data();
    if (message === undefined || message.type === 'system') return;
    const chat = await db().collection('chats').doc(event.params.chatId).get();
    const members: unknown = chat.data()?.members;
    await handleChatMessageCreated(
      {
        chatId: event.params.chatId,
        messageId: event.params.messageId,
        message,
        members: Array.isArray(members) ? members.filter((m): m is string => typeof m === 'string') : [],
      },
      liveNotifyDeps(),
    );
  },
);

/** Reading a chat (member unreadCount → 0) marks its grouped inbox row read. */
export const onChatMemberWrite = onDocumentWritten(
  { ...TRIGGER_OPTIONS, document: 'chats/{chatId}/members/{uid}' },
  async (event) => {
    const after = event.data?.after.exists ? event.data.after.data() : undefined;
    await handleChatMemberWrite({ chatId: event.params.chatId, uid: event.params.uid, after }, async (uid, chatId, at) => {
      const ref = db().collection('users').doc(uid).collection('notifications').doc(`g_chat_${chatId}`);
      return db().runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists || snap.data()?.readAt != null) return false;
        tx.update(ref, { readAt: Timestamp.fromDate(at) });
        return true;
      });
    });
  },
);

/** One account per push token: other device docs with the same token are removed. */
export const onDeviceWrite = onDocumentWritten({ ...TRIGGER_OPTIONS, document: 'devices/{deviceId}' }, async (event) => {
  const directory = new FirestoreDeviceDirectory(db());
  await handleDeviceWrite(
    event.params.deviceId,
    event.data?.before.exists ? event.data.before.data() : undefined,
    event.data?.after.exists ? event.data.after.data() : undefined,
    {
      otherDevicesWithToken: async (token, exceptId) => {
        const snap = await db().collection('devices').where('token', '==', token).get();
        return snap.docs.filter((d) => d.id !== exceptId).map((d) => d.id);
      },
      remove: (ids) => directory.remove(ids),
    },
  );
});

/** A new account earns `new_member`. */
export const onUserCreated = onDocumentCreated({ ...TRIGGER_OPTIONS, document: 'users/{uid}' }, async (event) => {
  await handleUserCreated(event.params.uid, liveBadgeDeps());
});

/** Package changes can complete `complete_profile`. */
export const onServiceWrite = onDocumentWritten(
  { ...TRIGGER_OPTIONS, document: 'photographers/{uid}/services/{serviceId}' },
  async (event) => {
    await handleServiceWrite(
      event.params.uid,
      event.data?.before.exists ? event.data.before.data() : undefined,
      event.data?.after.exists ? event.data.after.data() : undefined,
      liveBadgeDeps(),
    );
  },
);

/** Nightly 03:30 Asia/Ho_Chi_Minh: syncs the badge catalogue and re-evaluates `new_member` holders. */
export const reconcileBadges = onSchedule(
  { ...SCHEDULE_OPTIONS, schedule: '30 3 * * *', timeZone: 'Asia/Ho_Chi_Minh', maxInstances: 1, timeoutSeconds: 300 },
  async () => {
    await handleReconcileBadges();
  },
);

/** Nightly 03:45: deletes read inbox rows older than 90 days. */
export const pruneNotifications = onSchedule(
  { ...SCHEDULE_OPTIONS, schedule: '45 3 * * *', timeZone: 'Asia/Ho_Chi_Minh', maxInstances: 1, timeoutSeconds: 300 },
  async () => {
    await handlePruneNotifications();
  },
);
