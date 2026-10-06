import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onCall } from 'firebase-functions/v2/https';
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
export const bookingClock = onSchedule(SCHEDULE_OPTIONS, async () => {
  await handleBookingClock();
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
    );
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
  // Most posts name no album: skip before building the live deps.
  if (typeof event.data?.get('albumId') !== 'string') return;
  await handlePostCreated(event.params.postId, liveAlbumDeps());
});
