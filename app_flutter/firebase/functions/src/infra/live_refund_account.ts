/**
 * Production and emulator wiring of RefundAccountDeps (S22.04, #141): the booking, ticket and
 * dispute deps (one `refunds` collection behind all three), the bank's holder-name lookup, a clock.
 */

import {
  normalizeHolderName,
  type AccountNameLookup,
  type BookingDeps,
  type RefundAccountDeps,
} from '@photobooking/domain';
import type { Firestore } from 'firebase-admin/firestore';
import { db } from './admin.js';
import { liveBookingDeps } from './live_booking.js';
import { liveDisputeDeps } from './live_dispute.js';
import { liveEventPaymentDeps } from './live_event.js';
import { accountNameLookup, lookupMode } from './payout_lookup.js';

/**
 * The caller's `users/{uid}.displayName` normalised like a bank holder name (uppercase ASCII), or
 * null. Customers have no verified name (Decision 7); the fake lookup echoes this one so a tester
 * sees their own name for their own account.
 */
export async function echoNameOf(firestore: Firestore, uid: string): Promise<string | null> {
  const snap = await firestore.collection('users').doc(uid).get();
  return normalizeHolderName(snap.data()?.displayName);
}

/**
 * `lookup` for `uid`: the domain's one fake where fake payouts run (`lookupMode()`), echoing the
 * caller's normalised display name (read once, only when a lookup runs); `off` everywhere else
 * (every lookup is `unsupported`, so the customer uses the paying account). Never logs the number.
 */
export function refundAccountLookup(uid: string | null, mode: 'fake' | 'off' = lookupMode()): AccountNameLookup {
  let echo: Promise<string | null> | undefined;
  return {
    lookup: async (r) => {
      if (mode === 'fake' && uid !== null) echo ??= echoNameOf(db(), uid);
      return accountNameLookup(mode, mode === 'fake' && echo !== undefined ? await echo : null).lookup(r);
    },
  };
}

/**
 * Callables pass the caller's uid (`lookupRefundAccount` echoes their name); the payment clock passes
 * its own booking deps and no uid (its step never looks a name up).
 */
export function liveRefundAccountDeps(o: { readonly uid?: string; readonly bookings?: BookingDeps } = {}): RefundAccountDeps {
  return {
    bookings: o.bookings ?? liveBookingDeps(),
    events: liveEventPaymentDeps(),
    disputes: liveDisputeDeps(),
    lookup: refundAccountLookup(o.uid ?? null),
    clock: { now: () => new Date() },
  };
}
