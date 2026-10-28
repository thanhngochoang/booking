# Handover Ledger: S05 · Huỷ phần bàn giao khi trễ hạn (late delivery cancel)

Issue: [#207](https://github.com/thanhngochoang/booking/issues/207) · Plan: `docs/superpowers/plans/2026-10-18-s05-late-delivery-cancel.md` · Branch: `plan/207-s05-huy-phan-ban-giao-khi-tre-han` · Date: 2026-10-28

## 1. What shipped

When the provider has not submitted any delivery round `deliveryDays` days after the shoot, the customer ends the booking from S05.02 with "Huỷ phần bàn giao" (S05.08): milestone 2 is refunded 100% to the payer, milestone 1 stays with the provider, and the booking goes `shot → completed` with a `deliveryCancel` block.

| Task | Commit | Content |
|---|---|---|
| 1 | `1039e989` | `delivery_deadline.ts` (`DEFAULT_DELIVERY_DAYS = 7`, `clampDeliveryDays`, `deliveryDueAt`, `isDeliveryLate`); `deliveryDays` snapshot in `buildBookingDraft` |
| 2 | `634376ba` | `refundMilestone` (`milestones.ts:249`), `cancelLateDelivery` (`delivery_use_cases.ts:336`), `notifyDeliveryCancelledLate` (`notification_hooks.ts:366`), owner ruling (a) pinned by a test |
| 3 | `e346c25c` | callable `cancelLateDelivery` (`index.ts:351`, handler `callables/delivery.ts:58`), adapter fields, trigger hook, seed `SEED_BOOKING_SHOT_LATE` |
| 4 | `538ef94a` | app `Booking.deliveryDays`/`deliveryCancel`, `BookingRepository.cancelLateDelivery`, `BookingRules.deliveryDueAt`/`isDeliveryLate`, `BookingMilestones` read model, dispute entry closed for two-layer `completed` |
| 5 | `c4799476` | S05.02 late card (`LateDeliveryCard`), S05.08 sheet (`showLateCancelSheet`), provider notice, timeline subtitles, earnings label, notification visual |

## 2. Step 1 findings (Tasks 1–5)

- **Deadline snapshot.** `buildBookingDraft` sets `deliveryDays = clampDeliveryDays(service.deliveryDays)` (`create_booking.ts:89`); the slot offer path passes `offer.deliveryDays` (`create_booking.ts:150`).
- **Trigger site of the provider notice.** `triggers/booking_write.ts:120–125` calls `notifyDeliveryCancelledLate` on `shot → completed` with `deliveryCancel`; the badge check and `refreshCompletedCount` skip a booking with `deliveryCancel` (`booking_write.ts:130`, `:147`, Decision 17).
- **`refund_account_needed`.** No new code: `triggers/refund_write.ts:39` (`announceRefundAccountNeeded`) already fires for a booking refund entering `awaiting_account`, including `reason: 'late_delivery'`.
- **Milestone read model.** Written by `triggers/payment_write.ts` on every payment write with milestones; `refunded` reaches `bookings/{id}/milestones/delivery` with no Functions change. The app reads it through `bookingMilestonesProvider` (`data/booking/booking_providers.dart:133`).
- **Earnings label.** `milestonesOfDocs` (`infra/earnings_firestore.ts`) and `earningItemOf` (`packages/domain/src/earnings.ts`) exclude refunded milestones from `total` and report `milestonesRefunded`; `_meta` (`features/earnings/earnings_screen.dart`) appends `earningsMilestoneRefundedSuffix`, so the provider reads "mốc 1/1 · mốc 2 đã hoàn cho khách".
- **App dispute entry (Decision 16).** `bookingDisputeClosesAt` returns null for a `completed`/`reviewed` booking with `approvedAt` or `deliveryCancel` (`features/disputes/dispute_entry.dart:145`).
- **Mock.** `#S05.02-late` and `#S05.08` copy and order match the l10n keys verbatim; the card sits above the payment block and the timeline; the primary button stays "Nhắn tin".

## 3. Decisions 1–19 as taken

Decisions 1–18 are implemented as the plan states. Notes:

- **Decision 4.** Refund is milestone-exact; the payment becomes `partially_refunded`; the refund row's `percent` is display only.
- **Decision 14.** The sheet returns `LateCancelOutcome {cancelled, kept, alreadyDelivered, notLate, disputed, failed}`; `alreadyDelivered`/`notLate`/`disputed` close the sheet and S05.02 toasts and refreshes; any other error keeps it open with the generic `detailErrorNetwork` SnackBar ("Không gửi được. Thử lại nhé.").
- **Decision 15.** The earnings change needed `packages/domain/src/earnings.ts` as well as the Functions mapper (the item is built from the payment in the domain).
- **Decision 19 (analytics) not done.** The app has no `booking_action` event to reuse (no analytics call in `booking_detail_screen.dart`); adding a new analytics surface is out of scope. Follow-up when booking analytics exists.

## 4. Copy that differs from the mock

None. The toast amount comes from the milestone read model (falls back to 50/50 of `deposit − depositRefunded` for a legacy booking), matching the sheet.

## 5. Skipped suites

- Rules emulator tests: no rule changed.
- Functions integration test `test/integration/delivery_late_cancel.test.ts`: CI runs it only after merge (`firebase-deploy.yml` on `develop`). Run once locally on the emulators on 2026-10-28 and passing; its trigger-written reads wait up to 60 s because the seed's own triggers queue ahead of them (about 20 s locally).

Verified locally on 2026-10-28: `packages/domain` test, lint and typecheck; Functions lint, typecheck and unit tests; `flutter analyze`; `flutter test` for `test/features/booking` (344), `earnings`, `notifications`, `disputes`, `test/data/booking`; `dart run tool/affected_test.dart origin/develop --run` (5169 passed, 42 skipped).

## 6. Deploy order

1. Firestore indexes first: `bookings (photographerId, deliveryCancel)` and `bookings (customerId, deliveryCancel)`, used by the late-cancel subtraction in the completed count and the shoot badges.
2. Functions (callable `cancelLateDelivery`, trigger, adapter and count changes).
3. The app.

No rules or Scheduler entries.

## 7. QA

Run the emulators with the seed; as Lan, open `/b/seed-booking-shot-late` (shot 240 h ago, `deliveryDays` 5, delivery milestone held): S05.02 shows "Bàn giao ảnh · Quá hạn", the red card and "Huỷ phần bàn giao"; confirming in S05.08 completes the booking, toasts "Đã huỷ phần bàn giao · hoàn {amount}", and An gets `delivery_cancelled_late`.

## 8. Rulings during execution

- Tasks 1–4 ran before a ledger existed; resumed from Task 5 on 2026-10-28 with an uncommitted Task 5 draft in the working tree.
- The draft's tests targeted APIs that do not exist (a `screenHost` helper, `DeliveryCancel.byUid/refundId`, `BookingMilestones` without statuses, invented copy); they were rewritten to the real APIs and the plan's copy.
- A clock fudge the draft added to `FakeBookingRepository.cancelLateDelivery` was reverted; the fake's real clock already makes the fixtures late.
- Deletions of `services/{README.md,dispatch/*,recommender/*}` found in the working tree are unrelated to #207 and were left out of every commit.
- Spec status cells point at #207 until the PR exists.

## 9. Final review fixes

A fresh whole-branch review found:

- **Fixed: completed count and shoot badges dropped older bookings.** The draft filtered `deliveryCancel == null`, which in Firestore matches only documents that have the field, so every booking written before this branch fell out of `completedCount`, `completedShoots` and `customerShoots`; the three-field query also had no composite index. The counts now keep the old query and subtract `deliveryCancel != null` (`discovery_firestore.ts` `completedBookings`, `badge_firestore.ts`), with the two indexes above. Tests: `completedBookings subtracts late-cancelled bookings…`, `shoot counts subtract late-cancelled bookings…`, `the late-cancel counts have their composite indexes`.
- **Fixed: the integration test asserted the wrong statuses and notification id** and read trigger-written documents without waiting. It now expects payment `partially_refunded` / escrow `released`, the id `n_delivery_cancelled_late_{bookingId}`, and polls with `waitFor` (60 s budget, `waitFor` gained an optional timeout). Verified on the local emulators.
- **Fixed: S05.08 stayed open on a `not_eligible` refusal** (the first call committed but its response was lost, or a legacy payment without milestones): the sheet now closes with `LateCancelOutcome.notEligible` and S05.02 toasts `detailErrorNotEligible` and refreshes.

Needs the owner (not changed):

- **In-flight bookings without a `deliveryDays` snapshot read 7 days** (Decision 3), even when their package promises more, so a 30-day package booked before deploy can show "Quá hạn" after 7 days. Options: a one-off backfill copying `deliverables.deliveryDays` into non-terminal bookings at deploy, or keep 7.
- **The milestone refund goes straight to the paying account** (V2, Decision 5), while other customer-initiated refunds of bank-QR payments wait 24 h for an S22.04 account choice (#141). Options: apply the account-choice wait here too, or confirm V2 for late cancels.

Deferred minors: the dispute guard reads only the booking mirror, not the transactional payment's milestones; a fully refunded payment stays `partially_refunded` after a shoot refund plus a late cancel; the provider-name fallback reuses `earningsCustomerFallback` ("Khách"); the late card still shows on a disputed booking (tapping toasts the dispute); a dead `ref.read` of the auto-dispose milestones provider in S05.02 and a dead response fallback in `firestore_booking_repository.dart`; no test with `delivery` before `shoot` in the milestones array; the memory discovery store and `hireCount` do not exclude late-cancelled bookings.
