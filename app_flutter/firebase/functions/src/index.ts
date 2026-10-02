import { onDocumentWritten } from 'firebase-functions/v2/firestore';
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
import { CALLABLE_OPTIONS, SCHEDULE_OPTIONS, TRIGGER_OPTIONS } from './config.js';
import { liveContactDeps } from './infra/live.js';
import { liveSkillsDeps } from './infra/live_skills.js';
import { liveBookingDeps } from './infra/live_booking.js';
import { handleBookingClock } from './scheduled/booking_clock.js';
import { handlePhotographerEvent } from './triggers/photographer_write.js';

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
