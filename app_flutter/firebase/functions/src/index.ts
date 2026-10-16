import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onCall, onRequest } from 'firebase-functions/v2/https';
import { Timestamp } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { handleGetContactLink } from './callables/get_contact_link.js';
import {
  handleCreateBooking,
  handleTransitionBooking,
  handleOpenDispute,
} from './callables/booking.js';
import { handleCheckPayment, handleConfirmFakePayment, handleCreatePayment, handleGetPaymentInstructions } from './callables/payment.js';
import { servePaymentWebhook } from './http/payment_webhook.js';
import { handlePaymentClock } from './scheduled/payment_clock.js';
import { liveSettlementDeps } from './infra/live_payments.js';
import { handleCreatePayouts } from './scheduled/create_payouts.js';
import {
  handleOpenInquiry,
  handleSendMessage,
  handleProposeReschedule,
  handleAnswerReschedule,
} from './callables/chat.js';
import {
  CALLABLE_OPTIONS,
  CREATE_PAYOUTS_OPTIONS,
  PAYMENT_CALLABLE_OPTIONS,
  PAYMENT_CLOCK_OPTIONS,
  PAYOUT_ACCOUNT_KEY,
  SCHEDULE_OPTIONS,
  TRIGGER_OPTIONS,
  WEBHOOK_OPTIONS,
} from './config.js';
import {
  handleLookupPayoutAccountName,
  handleRequestPayoutOtp,
  handleSavePayoutAccount,
} from './callables/payout_account.js';
import { handlePaymentWrite } from './triggers/payment_write.js';
import { handlePayoutWrite } from './triggers/payout_write.js';
import { liveEarningsDeps, livePayoutAccountDeps } from './infra/live_payout.js';
import { liveContactDeps } from './infra/live.js';
import { liveAcceptingOrdersWriter, liveSkillsDeps } from './infra/live_skills.js';
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
import { handleLinkEventPosts, handlePostCreated, mayLinkEventPosts } from './triggers/post_created.js';
import { liveAlbumDeps } from './infra/live_album.js';
import { FirestoreFollowerCounter } from './infra/follower_counter.js';
import { handleFollowWrite } from './triggers/engagement_counters.js';
import { liveDiscoveryDeps } from './infra/live_discovery.js';
import { handleAvailabilityWrite } from './triggers/availability_write.js';
import { handleEngagementWrite } from './triggers/engagement_write.js';
import { handleRollNextFree } from './scheduled/roll_next_free.js';
import { handleServiceDiscovery } from './triggers/service_write.js';
import {
  handleCreateAward,
  handleDeleteAward,
  handleReviewAward,
  handleUpdateAward,
} from './callables/award.js';
import { handleAwardWrite } from './triggers/award_write.js';
import { handleAwardPurge } from './scheduled/award_purge.js';
import { liveAwardDeps } from './infra/live_award.js';
import {
  handleAcceptVerificationRules,
  handleCompleteIdentityVerification,
  handleConfirmPhoneVerified,
  handleLookupTaxCode,
  handleResubmitVerification,
  handleReviewVerification,
  handleStartIdentityVerification,
  handleSubmitBusinessVerification,
  handleSubmitVerification,
} from './callables/verification.js';
import { liveVerificationCallableDeps, liveVerificationDeps } from './infra/live_verification.js';
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
import {
  handleCancelEvent,
  handleCancelRegistration,
  handleCheckInRegistration,
  handleCheckTicketPayment,
  handlePublishEvent,
  handleRegisterEvent,
  handleRespondToHostConsent,
  handleSaveEventDraft,
  handleUpdateEvent,
} from './callables/event.js';
import { handleEventClock, handleReleaseEventHolds } from './scheduled/event_clock.js';
import { liveEventCallableDeps, liveEventDeps, liveEventPaymentDeps } from './infra/live_event.js';
import { handleModerateEventTimeline, handleShareEventPost } from './callables/event_timeline.js';
import {
  handleModerateEventChat,
  handlePostEventAnnouncement,
  handleSendEventMessage,
} from './callables/event_chat.js';
import { handleRegistrationWrite } from './triggers/registration_write.js';
import { liveEventChatDeps, liveTimelineDeps } from './infra/live_event_social.js';
import { handleSendSupportMessage } from './callables/support.js';
import { liveSupportDeps } from './infra/live_support.js';
import { handleSupportMessageCreated } from './triggers/support_message_created.js';

// Entry point of the Cloud Functions codebase. Each export is one deployed function.


/** `{bookingId | registrationId, channel}` → `{url}`; contract in plan 2b "Out of scope". */
export const getContactLink = onCall(CALLABLE_OPTIONS, (request) => handleGetContactLink(request, liveContactDeps()));

/** Booking creation draft */
export const createBooking = onCall(CALLABLE_OPTIONS, (request) => handleCreateBooking(request, liveBookingDeps()));

/**
 * `{bookingId, method}` → `{paymentId, checkout}`: opens a payment of the full price (S04.03
 * "Thanh toán", S04.04 "Tạo QR mới"); replaces `createDeposit`.
 */
export const createPayment = onCall(PAYMENT_CALLABLE_OPTIONS, (request) => handleCreatePayment(request, liveBookingDeps()));

/** `{bookingId}` → `{paid, booking}`: "Kiểm tra lại" asks the provider; replaces `checkDeposit`. */
export const checkPayment = onCall(PAYMENT_CALLABLE_OPTIONS, (request) => handleCheckPayment(request, liveBookingDeps()));

/**
 * `{paymentId, kind?}` → `{outcome}`: a simulated bank transfer (`exact` | `under` | `over` |
 * `wrong_content`) signed and run through the webhook handler. Emulator and dev project only
 * (`fake_payments_disabled` elsewhere).
 */
export const confirmFakePayment = onCall(PAYMENT_CALLABLE_OPTIONS, (request) =>
  handleConfirmFakePayment(request, liveSettlementDeps()),
);

/**
 * `{paymentId}` → `{instructions: PaymentInstructions | null}`:
 * payer only; instructions of a `created` payment, else null.
 */
export const getPaymentInstructions = onCall(PAYMENT_CALLABLE_OPTIONS, (request) =>
  handleGetPaymentInstructions(request, liveSettlementDeps()),
);

/**
 * `POST /paymentWebhook?provider=fake`: the provider reports a transfer; authenticated by its
 * signature over the raw body (the fake provider exists only where fake payments are allowed).
 */
export const paymentWebhook = onRequest(WEBHOOK_OPTIONS, (req, res) => servePaymentWebhook(req, res, liveSettlementDeps()));

/** Every 5 minutes: reconcile open payments with the provider and expire unpaid QRs. */
export const paymentClock = onSchedule(PAYMENT_CLOCK_OPTIONS, async () => {
  await handlePaymentClock(liveSettlementDeps());
});

/** Booking lifecycle transition */
export const transitionBooking = onCall(CALLABLE_OPTIONS, (request) => handleTransitionBooking(request, liveBookingDeps()));

/** Open dispute on completed/upcoming booking */
export const openDispute = onCall(CALLABLE_OPTIONS, (request) => handleOpenDispute(request, liveBookingDeps()));

/** 15-minute booking lifecycle and escrow sweep clock */
export const bookingClock = onSchedule({ ...SCHEDULE_OPTIONS, timeoutSeconds: 300 }, async () => {
  await handleBookingClock(undefined, liveReminderDeps(), {
    verification: { deps: liveVerificationDeps(), notify: liveNotifyDeps() },
  });
});

/**
 * Scores `photographers/{uid}.skills` ("Độ khớp hồ sơ"), removes evidence that is not the
 * photographer's own post (spec 2026-10-02-photographer-write-function-design.md) and keeps the
 * derived `acceptingOrders` flag in sync (verified and onboarded). Events older than
 * 1 hour and permanent Firestore errors end without a retry (handlePhotographerEvent).
 */
export const onPhotographerWrite = onDocumentWritten({ ...TRIGGER_OPTIONS, document: 'photographers/{uid}' }, async (event) => {
  const uid = event.params.uid;
  const after = event.data?.after;
  const live = after?.exists === true ? after : undefined;
  await handlePhotographerEvent(
    { uid, time: event.time, before: event.data?.before.data(), after: live?.data() },
    () => liveSkillsDeps(uid, live?.updateTime),
    liveAcceptingOrdersWriter(),
    new Date(),
    liveDiscoveryDeps(),
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
    await handleBookingWrite(
      { id: bookingId, before, after },
      liveChatDeps(),
      undefined,
      {
        notify: liveNotifyDeps(),
        badges: liveBadgeDeps(),
      },
      liveDiscoveryDeps(),
    );
  },
);

/** Submit review and optionally share real shoot photos */
export const submitReview = onCall(CALLABLE_OPTIONS, (request) =>
  handleSubmitReview(request, liveReviewDeps()),
);

/** Count a tomato/brick review into its subject's stats, then the verdict notice and badges */
export const onReviewWrite = onDocumentWritten(
  { ...TRIGGER_OPTIONS, document: 'reviews/{reviewId}' },
  async (event) => {
    const reviewId = event.params.reviewId;
    const before = event.data?.before.exists ? (event.data.before.data() as Record<string, unknown>) : undefined;
    const after = event.data?.after.exists ? (event.data.after.data() as Record<string, unknown>) : undefined;
    await handleReviewWrite(
      { reviewId, before, after },
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

/**
 * A new post that names an album lands last in it, or is detached when the album is not usable; a post
 * with hashtags (or an event) is put on the timeline of every open event it names (plan 10c).
 */
export const onPostCreated = onDocumentCreated({ ...TRIGGER_OPTIONS, document: 'posts/{postId}' }, async (event) => {
  if (typeof event.data?.get('albumId') === 'string') await handlePostCreated(event.params.postId, liveAlbumDeps());
  if (mayLinkEventPosts(event.data?.get('hashtags'), event.data?.get('eventId'))) {
    await handleLinkEventPosts(event.params.postId, liveTimelineDeps());
  }
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

/** Daily 03:00 Asia/Ho_Chi_Minh: deletes award proofs and S21.04 business photos 30 days after a final decision. */
export const purgeAwardProofs = onSchedule(
  { ...SCHEDULE_OPTIONS, schedule: 'every day 03:00', timeoutSeconds: 300 },
  async () => {
    await handleAwardPurge();
  },
);

// ---- provider verification (S21, #135; the fee callables are #203's) ----

/** `{}` → `{phoneVerified: true}`: marks the contact phone verified once the Auth phone (OTP) matches it. */
export const confirmPhoneVerified = onCall(CALLABLE_OPTIONS, (request) =>
  handleConfirmPhoneVerified(request, liveVerificationCallableDeps()),
);

/** `{method: 'vneid' | 'nfc'}` → `{sessionId, redirectUrl}`; fake verifier on the emulator/dev, `not_eligible` elsewhere. */
export const startIdentityVerification = onCall(CALLABLE_OPTIONS, (request) =>
  handleStartIdentityVerification(request, liveVerificationCallableDeps()),
);

/** `{sessionId}` → `{result: 'passed', maskedName}`; `underage`, `identity_in_use`, `rate_limited`, `not_found`. */
export const completeIdentityVerification = onCall(CALLABLE_OPTIONS, (request) =>
  handleCompleteIdentityVerification(request, liveVerificationCallableDeps()),
);

/** `{version}` → `{}`: the provider rules of PROVIDER_RULES_VERSION. */
export const acceptVerificationRules = onCall(CALLABLE_OPTIONS, (request) =>
  handleAcceptVerificationRules(request, liveVerificationCallableDeps()),
);

/** `{}` → `{status: 'submitted'}` once every required step is done. */
export const submitVerification = onCall(CALLABLE_OPTIONS, (request) =>
  handleSubmitVerification(request, liveVerificationCallableDeps()),
);

/** `{}` → `{status}` after a resubmittable rejection. */
export const resubmitVerification = onCall(CALLABLE_OPTIONS, (request) =>
  handleResubmitVerification(request, liveVerificationCallableDeps()),
);

/** `{taxCode}` → `{name, address, status, kind}` (verified studios; fake lookup on the emulator/dev). */
export const lookupTaxCode = onCall(CALLABLE_OPTIONS, (request) => handleLookupTaxCode(request, liveVerificationCallableDeps()));

/** `{taxCode, docPath?}` → `{status}`: household matched at once, company to staff. */
export const submitBusinessVerification = onCall(CALLABLE_OPTIONS, (request) =>
  handleSubmitBusinessVerification(request, liveVerificationCallableDeps()),
);

/** Staff only (claim `staffRole: 'admin'`): `{uid, target?, action, reason?, note?}` → `{status}`. */
export const reviewVerification = onCall(CALLABLE_OPTIONS, (request) =>
  handleReviewVerification(request, liveVerificationCallableDeps()),
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
    // Event group chats (up to 500 members) never notify per message: there is no "other member".
    if (chat.data()?.kind === 'event_group') return;
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

/** Package changes can complete `complete_profile` and refresh discovery starting price and catalog. */
export const onServiceWrite = onDocumentWritten(
  { ...TRIGGER_OPTIONS, document: 'photographers/{uid}/services/{serviceId}' },
  async (event) => {
    const before = event.data?.before.exists ? event.data.before.data() : undefined;
    const after = event.data?.after.exists ? event.data.after.data() : undefined;
    await handleServiceWrite(
      event.params.uid,
      before,
      after,
      liveBadgeDeps(),
    );
    await handleServiceDiscovery(
      event.params.uid,
      before,
      after,
      liveDiscoveryDeps(),
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

// ---- earnings and payout account (plan 10b) ----

/**
 * S06.06 `{bankCode, accountNumber}` → `{decision, holderName, verifiedName}`: the bank's holder
 * name compared with the verified name. Photographers only, 20 lookups per Vietnam day
 * (`limit_exceeded`), shared with the save. Fake lookup on the emulator/dev only, else unsupported.
 */
export const lookupPayoutAccountName = onCall(CALLABLE_OPTIONS, (request) =>
  handleLookupPayoutAccountName(request, livePayoutAccountDeps(request.auth?.uid ?? '')),
);

/**
 * S06.06 `{bankCode, accountNumber}` → `{phoneLast4, expiresInSeconds, resendInSeconds}`: the OTP a
 * change of account needs (`not_eligible` outside the emulator/dev: no SMS vendor yet). Binds the
 * account key only to tell the account already active (`conflict`) by decrypting it.
 */
export const requestPayoutOtp = onCall({ ...CALLABLE_OPTIONS, secrets: [PAYOUT_ACCOUNT_KEY] }, (request) =>
  handleRequestPayoutOtp(request, livePayoutAccountDeps(request.auth?.uid ?? '')),
);

/**
 * S06.06 v2 `{bankCode, accountNumber, otpCode?}` → `{accountId, accountLast4, activeFrom,
 * nameStatus}`. Photographers only; the holder name comes from the bank and must match the
 * verified name (`name_mismatch`, `not_found`, `not_eligible`); a change needs the OTP
 * (`otp_required`, `otp_invalid`, `otp_expired`, `limit_exceeded`) and is active 72 hours later;
 * the account already active is `conflict`. The number is stored AES-256-GCM encrypted with the
 * secret PAYOUT_ACCOUNT_KEY.
 */
export const savePayoutAccount = onCall({ ...CALLABLE_OPTIONS, secrets: [PAYOUT_ACCOUNT_KEY] }, (request) =>
  handleSavePayoutAccount(request, livePayoutAccountDeps(request.auth?.uid ?? '')),
);

/** A payment write refreshes the payee's earnings rows and totals. */
export const onPaymentWritten = onDocumentWritten({ ...TRIGGER_OPTIONS, document: 'payments/{paymentId}' }, async (event) => {
  await handlePaymentWrite(
    event.params.paymentId,
    event.data?.before.exists ? event.data.before.data() : undefined,
    event.data?.after.exists ? event.data.after.data() : undefined,
    liveEarningsDeps(),
  );
});

/**
 * A payout write refreshes the rows of every payment in the batch and the last-payout card; when
 * the payout becomes `paid` the payee gets `payout_released` (S17).
 */
export const onPayoutWritten = onDocumentWritten({ ...TRIGGER_OPTIONS, document: 'payouts/{payoutId}' }, async (event) => {
  await handlePayoutWrite(
    event.params.payoutId,
    event.data?.before.exists ? event.data.before.data() : undefined,
    event.data?.after.exists ? event.data.after.data() : undefined,
    liveEarningsDeps(),
    liveNotifyDeps(),
  );
});

/** Daily 10:00 Asia/Ho_Chi_Minh: batch released money per payee and send it (fake gateway only; off elsewhere). */
export const createPayouts = onSchedule(CREATE_PAYOUTS_OPTIONS, async () => {
  await handleCreatePayouts();
});

// ---- photo events (plan 10c) ----

/** `{eventId?, …fields, hostPhotographerId?}` → `{eventId, hashtag}`; creates or edits a draft. */
export const saveEventDraft = onCall(CALLABLE_OPTIONS, (request) =>
  handleSaveEventDraft(request, liveEventCallableDeps()),
);

/** `{eventId}`: draft → open (needs the host's consent when staff created it for a photographer). */
export const publishEvent = onCall(CALLABLE_OPTIONS, (request) => handlePublishEvent(request, liveEventDeps()));

/** `{eventId, …fields}`: edits a published event. */
export const updateEvent = onCall(CALLABLE_OPTIONS, (request) => handleUpdateEvent(request, liveEventDeps()));

/** `{eventId}` → `{paidRegistrationIds, refunded, failed}`: cancels and refunds every paid ticket 100%. */
export const cancelEvent = onCall({ ...CALLABLE_OPTIONS, timeoutSeconds: 60 }, (request) =>
  handleCancelEvent(request, liveEventPaymentDeps()),
);

/** `{eventId, accept}`: the photographer answers a staff-created draft (24 h). */
export const respondToHostConsent = onCall(CALLABLE_OPTIONS, (request) =>
  handleRespondToHostConsent(request, liveEventDeps()),
);

/**
 * `{eventId, quantity, name, provider?}` → registration (free events: paid at once; paid events: a
 * 10-minute hold with `paymentId`, `payUrl`, `holdExpiresAt`). 30 s: contended transactions.
 */
export const registerEvent = onCall(PAYMENT_CALLABLE_OPTIONS, (request) =>
  handleRegisterEvent(request, liveEventPaymentDeps()),
);

/** `{eventId, registrationId}` → `{status, refundPercent}` (paid ≥ 48 h before: refunded 100%). */
export const cancelRegistration = onCall(PAYMENT_CALLABLE_OPTIONS, (request) =>
  handleCancelRegistration(request, liveEventPaymentDeps()),
);

/** `{eventId, registrationId}` → `{paid, status}`: back from the gateway, or "Thanh toán tiếp". */
export const checkTicketPayment = onCall(PAYMENT_CALLABLE_OPTIONS, (request) =>
  handleCheckTicketPayment(request, { ...liveEventPaymentDeps(), settlement: liveSettlementDeps() }),
);

/** `{eventId, ticketCode}` → `{name, quantity}` */
export const checkInRegistration = onCall(CALLABLE_OPTIONS, (request) =>
  handleCheckInRegistration(request, liveEventDeps()),
);

/**
 * Every 5 minutes: closes registration, completes events (ticket money then waits 24 h for the
 * bookingClock release), expires unanswered host invitations, retries refunds of cancelled events,
 * then reminds paid ticket holders 48 h before the start (S17 `event_soon`).
 */
export const eventClock = onSchedule({ ...SCHEDULE_OPTIONS, schedule: 'every 5 minutes', timeoutSeconds: 120 }, async () => {
  await handleEventClock();
});

/** Every minute: expired 10-minute ticket holds give their seats back. */
export const releaseEventHolds = onSchedule({ ...SCHEDULE_OPTIONS, schedule: 'every 1 minutes' }, async () => {
  await handleReleaseEventHolds();
});

// ---- event timeline and group chat (plan 10c) ----

/** `{eventId, postId, images, caption?}` → `{postId}`: a paid attendee or a manager shares photos to the timeline. */
export const shareEventPost = onCall(CALLABLE_OPTIONS, (request) => handleShareEventPost(request, liveTimelineDeps()));

/** `{eventId, postId, action: hide | show | approve}`: managers moderate the timeline. */
export const moderateEventTimeline = onCall(CALLABLE_OPTIONS, (request) =>
  handleModerateEventTimeline(request, liveTimelineDeps()),
);

/** `{eventId, message}` → `{id}`: a member posts to the event group chat (20 messages a minute). */
export const sendEventMessage = onCall(CALLABLE_OPTIONS, (request) =>
  handleSendEventMessage(request, liveEventChatDeps()),
);

/** `{eventId, action, …}`: moderators pin, unpin, delete, mute, unmute, remove, or switch moderators-only. */
export const moderateEventChat = onCall(CALLABLE_OPTIONS, (request) =>
  handleModerateEventChat(request, liveEventChatDeps()),
);

/** `{eventId, text}` → `{messageId}`: S12.03 "Nhắn nhóm", a pinned moderator message. */
export const postEventAnnouncement = onCall(CALLABLE_OPTIONS, (request) =>
  handlePostEventAnnouncement(request, liveEventChatDeps()),
);

/** A registration that becomes paid joins the event group chat; cancelled or refunded leaves it. */
export const onRegistrationWrite = onDocumentWritten(
  { ...TRIGGER_OPTIONS, document: 'events/{eventId}/registrations/{regId}' },
  async (event) => {
    await handleRegistrationWrite(
      {
        eventId: event.params.eventId,
        regId: event.params.regId,
        before: event.data?.before.exists ? event.data.before.data() : undefined,
        after: event.data?.after.exists ? event.data.after.data() : undefined,
      },
      liveEventChatDeps(),
    );
  },
);

/** A follow marker created or deleted recounts photographer followers. */
export const onFollowWrite = onDocumentWritten(
  { ...TRIGGER_OPTIONS, document: 'follows/{docId}' },
  async (event) => {
    const counter = new FirestoreFollowerCounter(db());
    await handleFollowWrite(
      {
        time: event.time,
        before: event.data?.before.exists ? (event.data.before.data() as { userId?: string; photographerId?: string }) : null,
        after: event.data?.after.exists ? (event.data.after.data() as { userId?: string; photographerId?: string }) : null,
      },
      counter,
    );
  },
);

/** An availability day write updates nextFreeDate when inside the horizon. */
export const onAvailabilityWrite = onDocumentWritten(
  { ...TRIGGER_OPTIONS, document: 'availability/{uid}/days/{dayKey}' },
  async (event) => {
    await handleAvailabilityWrite(event.params.uid, event.params.dayKey, liveDiscoveryDeps());
  },
);

/** Like marker created or deleted recounts post likes. */
export const onLikeWrite = onDocumentWritten(
  { ...TRIGGER_OPTIONS, document: 'likes/{docId}' },
  async (event) => {
    await handleEngagementWrite(
      'like',
      event.data?.before.exists ? event.data.before.data() : undefined,
      event.data?.after.exists ? event.data.after.data() : undefined,
      liveDiscoveryDeps(),
    );
  },
);

/** Save marker created or deleted recounts post saves. */
export const onSaveWrite = onDocumentWritten(
  { ...TRIGGER_OPTIONS, document: 'saves/{docId}' },
  async (event) => {
    await handleEngagementWrite(
      'save',
      event.data?.before.exists ? event.data.before.data() : undefined,
      event.data?.after.exists ? event.data.after.data() : undefined,
      liveDiscoveryDeps(),
    );
  },
);

/** Daily 00:10 Asia/Ho_Chi_Minh: rolls nextFreeDate for photographers whose date has passed. */
export const rollNextFreeDates = onSchedule(
  { ...SCHEDULE_OPTIONS, schedule: '10 0 * * *', timeZone: 'Asia/Ho_Chi_Minh', maxInstances: 1, timeoutSeconds: 300 },
  async () => {
    await handleRollNextFree(liveDiscoveryDeps());
  },
);

/** Send support message (help chat or dispute thread) */
export const sendSupportMessage = onCall(CALLABLE_OPTIONS, (request) =>
  handleSendSupportMessage(request, liveSupportDeps()),
);

/** Notify recipient when a new support message is created */
export const onSupportMessageCreated = onDocumentCreated(
  { ...TRIGGER_OPTIONS, document: 'support_threads/{threadId}/messages/{messageId}' },
  async (event) => {
    const message = event.data?.data();
    if (!message) return;
    await handleSupportMessageCreated(
      {
        threadId: event.params.threadId,
        messageId: event.params.messageId,
        messageData: message as Record<string, unknown>,
      },
      {
        notify: liveNotifyDeps(),
        getThreadData: async (threadId) => {
          const snap = await db().collection('support_threads').doc(threadId).get();
          return snap.exists ? (snap.data() as Record<string, unknown>) : null;
        },
      },
    );
  },
);

