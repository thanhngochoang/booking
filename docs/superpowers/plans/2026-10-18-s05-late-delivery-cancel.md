# S05 · Huỷ phần bàn giao khi trễ hạn (late delivery cancel) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Rules emulator tests and Functions integration tests (standing rule):** write them, do not run them; CI runs them. Record the skip in the ledger. No battery/performance, device build or iOS steps.

> **Detail level ("ở giữa", owner):** exact interfaces, tests listed by name with expected behaviour, sample code only for the hard parts.

**Goal:** When the provider has not submitted any delivery round `deliveryDays` days after the shoot, the customer can end the booking with "Huỷ phần bàn giao": milestone 2 (delivery) is refunded 100% to the customer, milestone 1 (shoot) stays with the provider, and the booking goes `shot → completed`. The same unit settles the two delivery rulings the owner gave on 2026-10-18 (auto-approve keeps running while an extra round is pending; no dispute after `completed` on a milestone booking) and exposes the "Giao trễ hạn" predicate the staff dashboard will show.

**Architecture:** Pure rules in `packages/domain`: `delivery_deadline.ts` (`DEFAULT_DELIVERY_DAYS`, `deliveryDueAt`, `isDeliveryLate`), `refundMilestone` next to `releaseMilestone` in `milestones.ts`, and the use case `cancelLateDelivery` in `delivery_use_cases.ts` over the existing `BookingTx` (one transaction: booking, payment, refund, ledger, booking event; the gateway call runs after commit like `commitTransition` does). `deliveryDays` becomes part of the booking snapshot at draft time (`buildBookingDraft`), read from the package's `deliverables.deliveryDays`. Functions stay thin: one callable `cancelLateDelivery`, two adapter fields, one notification type. Flutter: `Booking.deliveryDays`/`deliveryCancel`, `BookingRepository.cancelLateDelivery`, the S05.02 late card, the S05.08 confirmation sheet, and the provider-side notice.

**Tech Stack:** TypeScript (`packages/domain`, Functions v2 `onCall`, `node --test`), Firestore; Flutter, Riverpod 3, go_router, freezed (`build_runner`), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-05-provider-types-portfolio-jobs-design.md` §4.1.5 ("Trễ hạn") and §4 state machine; `docs/superpowers/specs/2026-10-06-delivery-preview-unlock-design.md` §4 (`shot ──(quá deliveryDays, khách huỷ phần giao)──▶ completed (mốc 2 hoàn 100%)`) and its "Quyết định của chủ dự án 2026-10-18" block (added with this plan); `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` (two milestones, refunds from escrow); `docs/superpowers/specs/screens/booking.md` (S05.02 `shot` row, new S05.08); `docs/superpowers/specs/screens/staff-disputes-support.md` §2.3 (the staff flag); mock `docs/design/ui-mock.html` frames `#S05.02-late` and `#S05.08` (drawn with this plan, together with the §2 row of the main spec and `ScreenCodes.cancelLateDelivery`; treat them as done); cost unit prices `docs/superpowers/specs/2026-10-07-google-cloud-costs.md`.

**Issue:** #207 (S05 · Huỷ phần bàn giao khi trễ hạn). Related: #142 (S18 disputes, which this plan leaves alone), #165 (staff dashboard shows the flag), #134 (payouts).

**Branch:** `plan/207-late-delivery-cancel` from `origin/develop`; PR into `develop` titled `feat(delivery): cancel the delivery part when the provider is late [#207]`.

**Execution order:** not blocked: #152 (two-layer delivery) merged on 2026-10-18 (PR #239). Soft: #142 (S18) may later move "Báo vấn đề" into its dispute screen; this plan does not touch disputes beyond the explicit `completed` refusal.

**Owns (others consume):** `Booking.deliveryDays`, `Booking.deliveryCancel`, `DEFAULT_DELIVERY_DAYS`, `deliveryDueAt`, `isDeliveryLate`, `refundMilestone`, `cancelLateDelivery`, callable `cancelLateDelivery`, notification type `delivery_cancelled_late` + hook `notifyDeliveryCancelledLate`, `DetailAction.cancelLateDelivery`, `showLateCancelSheet`, `ScreenCodes.cancelLateDelivery` (`S05.08`). **Reuses without redefining:** `splitMilestones`/`withMilestones`/`aggregateEscrow`/`releaseMilestone` (`milestones.ts`), `applyRefundToPayment`'s refund-row conventions (`escrow.ts`: `fromEscrow`, `refundMethodOf`, `destination` from `payment.payer`, `awaiting_account`), `dispatchRefund` (`refunds.ts`), `roleOf` (`booking_machine.ts`), `BookingTx` (`booking_ports.ts`), `handleCallableError` + `CallableInput` (Functions), `showConfirmSheet`/`ConfirmSheet`, `StatusTimeline`, `BookingCard`, `BookingRules`, `detailActions`, l10n via `app_vi.arb`.

## Contract with existing code

Checked 2026-10-18 on `origin/develop` ca851ed (after #152, #144, #203, #201). Task 2 Step 1 re-checks these names; adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- **Domain.** `BOOKING_STATUSES` includes `shot`, `delivered`, `revision_requested`, `approved`, `completed` (`booking.ts`); `Booking` has `shotAt?`, `deliveredAt?`, `approvedAt?`, `checkUntil?`, `autoApproveAt?`, `deliveryRound?`, `revisionsIncluded?`, `extraRound?`, `escrowStatus?`, `depositRefunded?`, `completedAt?`, `samplesPurgeAfter?`, `version`; `BookingServiceSnapshot {name, price, durationMinutes}` (no `deliveryDays`, no `terms`); `ServiceRecord {id, photographerId, name, price, durationMinutes, active, revisions?}` (`booking_ports.ts`); `buildBookingDraft` sets `revisionsIncluded = clampRevisions(service.revisions)` (`create_booking.ts:65`); `PaymentMilestone {kind: 'shoot' | 'delivery', amount, status: 'held' | 'released' | 'paid_out' | 'refunded' | 'disputed', releaseAfter, releasedAt, payoutId}`, `releaseMilestone(p, kind, ledgerEntryId, now)`, `disputeMilestone(p, kind, now)`, `withMilestones(p, ms, at)` (recomputes `escrowStatus` with `aggregateEscrow` and `payableAmount`), `splitMilestones(net, now)` (`milestones.ts`); `commitTransition` splits milestones at `shot` from `payment.amount − escrow refunds` and releases `delivery` at `completed` only when `held` (`commit_transition.ts:92–120`); `applyRefundToPayment({payment, refundId, percent, ledgerEntryId, reason, now})` builds the `Refund` row (`fromEscrow: true`, `method: refundMethodOf(payment.method)`, `destination` from `payment.payer`, `status: awaiting_account | pending`) and the `refund_issued` ledger entry with `amount: -refundAmount` and `accountOwnerId: payment.payerId` (`escrow.ts:237–312`); `dispatchRefund(deps, refund, provider)` sends it and records the outcome through `bookingRefundHandler` (`refunds.ts:173`); `openDispute` accepts `upcoming | shot | approved | completed` and for a milestone payment reaches `disputeEscrowPayment`, which throws `conflict` on a released payment (`open_dispute.ts`); `approveDelivery(deps, {bookingId, actorId?})` (system when `actorId` is undefined) clears `extraRound` (`delivery_use_cases.ts:96–160`); `DISPUTE_WINDOW_HOURS = 24`, `DEFAULT_REVISIONS = 1`, `REVISIONS_MAX = 5` (`booking_policy.ts`); `DELIVERY_CHECK_HOURS`, `AUTO_APPROVE_HOURS`, `SHOOT_RELEASE_HOURS` (`delivery.ts`); `NOTIFICATION_TYPES` entries are `meta(category, channel, critical?)` (`notification.ts:25`); copy per type in the `NotificationContent` union + `renderNotification` (`notification_render.ts`; `notification_render.test.ts:240` requires copy for every type); hook pattern `notifyDeliverySubmitted` (`notification_hooks.ts:288`); `notifyRefundAccountNeeded` (`notification_hooks.ts:732`, no caller yet); the milestone read model `bookings/{id}/milestones/{kind}` is written by the `onPaymentWritten` trigger (`triggers/payment_write.ts:18–33`); `BookingEventRecord {id, bookingId, status, at, actorId?}`; `DomainError(code, field?)` (no `details` on `develop`, `errors.ts:56`), `ERROR_CODES` has `not_eligible`, `conflict`, `permission_denied`, `not_found`, `invalid_argument`.
- **Functions.** `handleApproveDelivery`/`handleSubmitDelivery` pattern (`callables/delivery.ts`: `request.auth?.uid` guard, `handleCallableError`); `BOOKING_REFUND_CALLABLE_OPTIONS` (used by `transitionBooking`, which may refund) and `CALLABLE_OPTIONS` (`config.ts`); `bookingToFirestore`/`bookingFromFirestore` map every delivery field explicitly (`infra/booking_firestore.ts:172–190, 308–326`); `booking_readers.ts:17` reads `d.deliverables?.revisions` into `ServiceRecord.revisions`; `triggers/booking_write.ts` calls `notifyBookingChange(before, after)` and, on `completed`, the badge check and `refreshCompletedCount` (`:96–108`; its tests live in `test/unit/discovery_triggers.test.ts`, there is no `booking_write.test.ts`); seed `seed/fixtures.ts` (`SEED_SERVICES`, `SEED_BOOKINGS`; `SeedBooking` has no `deliveryDays` and `shotAt` is always now − 2 h, `fixtures.ts:464`; Lan the customer, An the photographer); unit tests `test/unit/delivery_callables.test.ts`, `booking_firestore.test.ts`, `booking_readers.test.ts`.
- **Rules.** `bookings/{id}` is read by its parties and never written by clients; services validate `deliverables.deliveryDays` as an int 0–90 (`firestore.rules:211–222`). No rule change in this plan.
- **App.** `Booking` (freezed, `data/booking/booking.dart`, mapped from Firestore by `bookingFromFirestore`, `booking.dart:187`; `shotAt`, `deliveredAt`, `approvedAt`, `checkUntil`, `autoApproveAt`, `deliveryRound`, `revisionsIncluded`, `escrowStatus`, `depositRefunded`, `completedAt`, `cancel`); `ServiceSummary.deliveryDays` (`data/content/service_summary.dart`, read from `deliverables['deliveryDays']`); `BookingRepository.transitionBooking/openDispute` (interface `data/booking/booking_repository.dart`, implementation `data/booking/firestore_booking_repository.dart`), `BookingErrorCode` + `bookingErrorOf`; `BookingRules.canCustomerDispute(b, now)` (`:153`, allows `completed` with escrow `held`), `canReview`, `computeRefundPercent` (`data/booking/booking_rules.dart`); `showConfirmSheet` keeps the sheet open with a SnackBar when `onConfirm` throws (`core/widgets/confirm_sheet.dart:18–44`); the red token is `AppColors.error`; `DetailAction` enum and `detailActions(b, role, now, features)` (`features/booking/booking_view_rules.dart`), `timelineSteps`; `BookingDetailScreen._onAction` switch, `_StatusNoticeCard`, `_ExtraRoundCard` (`features/booking/booking_detail_screen.dart`); `showCancelSheet` over `showConfirmSheet` (`features/booking/cancel_sheet.dart`); earnings items with "mốc {done}/{total}" and no per-milestone row (`milestonesOfDocs` `infra/earnings_firestore.ts:102`, `earningItemOf` `data/earnings/earnings.dart:137–139`, `_meta` `features/earnings/earnings_screen.dart:434`); `notification_visuals.dart` (app, one case per type); tests `test/features/booking/booking_view_rules_test.dart`, `booking_detail_screen_test.dart`, `cancel_sheet_test.dart`, `test/features/delivery/*`.
- **Not anywhere yet:** `deliveryDays` on the domain `ServiceRecord`/`Booking`, any `deliveryCancel`, `cancelLateDelivery`, `refundMilestone`, `S05.08`.

## Global Constraints

- Money rules (CLAUDE.md, payments spec): 100% paid up front and held; two milestones; the only money movement here is **milestone 2 refunded 100% to the payer** and nothing to the provider beyond milestone 1 as already split; fake rails only (`PAYMENTS_MODE`); no change to release timing of milestone 1.
- Spec 10-05 §4.1.5: the customer may cancel the delivery part only when `now > shotAt + deliveryDays × 24 h` and the booking is still `shot` (no round submitted). After it, the booking is `completed` and the provider cannot submit (`canDeliver` is false on `completed`).
- Owner rulings 2026-10-18 (delivery spec "Quyết định của chủ dự án 2026-10-18"): (a) the 72-hour auto-approve clock **keeps running** while an extra-round request is pending; (b) a milestone booking cannot be disputed once `completed` (the 48-hour check window is the customer's last remedy); (c) `deliveryDays` defaults to **7** when the package has none, clamped to 1–90.
- Phase 1 has no staff UI: the flag "Giao trễ hạn" is a pure predicate for #165; the customer acts in the app.
- CLAUDE.md: business rules only in `packages/domain` (no Firebase/Node imports, `purity.test.ts`); Functions thin, region `asia-southeast1`; `cloud_firestore`/`cloud_functions` only in `lib/data/**`, `firebase_options.dart`, `main.dart`; imports `package:photobooking/...`, features import `core/core.dart`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons` only; one primary action per screen (S05.02's primary stays "Nhắn tin"/"Nộp bàn giao" as today; the late cancel is a red text button and a red button inside `ConfirmSheet`); strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`.
- Data model (`data-model/README.md`): ULID ids (`deps.ids.newId()`), UTC ISO instants in the domain, Firestore `Timestamp` only in adapters, integer VND.
- Env for Flutter commands (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Tests: `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time; bounded pumps, no `pumpAndSettle` on screens with `DotRingLoader`.
- Domain: `(cd packages/domain && npm test && npm run lint && npm run typecheck)`. Functions: `(cd app_flutter/firebase/functions && npm run lint && npm run typecheck && npm test)`. Lockfiles, if touched, are written with `npx -y npm@10 install` (CI runs npm 10).
- Commits: Conventional Commits, subject ends with `[#207]`, body ends with `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>` (owner's rule; never the Claude line).

## Decisions

1. **Eligible status is `shot` only.** `delivered` and `revision_requested` mean a round exists; the customer's remedies there are revisions, the extra round and the dispute window, not this cancel. `upcoming`/`accepted` are not late (nothing was shot).
2. **The deadline is a snapshot.** `Booking.deliveryDays` is copied at draft time from `ServiceRecord.deliveryDays` (new optional field, read from the package document's `deliverables.deliveryDays`); absent, `0`, negative or non-integer → `DEFAULT_DELIVERY_DAYS = 7` (deliberately not truncated like `clampRevisions`); above 90 → 90 (the rules already cap the package field at 90). Changing the package later does not move the deadline of an existing booking. Quotes (#139) and slot offers (#194) build a synthetic `ServiceRecord` for `buildBookingDraft`; they put their own `deliveryDays` on that record (today the only caller is `create_booking.ts:174`).
3. **`deliveryDueAt(b) = shotAt + deliveryDays × 24 h`** (UTC arithmetic; the day boundary is not VN-midnight aligned, matching the 72 h / 48 h clocks of the delivery spec). `isDeliveryLate(b, now)` = `status === 'shot' && shotAt set && now > dueAt`. Bookings written before this plan have no `deliveryDays`: the reader treats absence as the default 7, so the predicate works on old bookings too.
4. **Refund is milestone-exact, not percent-of-payment.** `refundMilestone(p, 'delivery', refundId, ledgerEntryId, now, reason)` refunds exactly `milestone.amount`, marks that milestone `refunded`, recomputes the payment through `withMilestones`, adds `refundedAmount` and sets **`status: 'partially_refunded'`** (as `applyRefundToPayment` does for a partial refund, `escrow.ts:259–273`; `verifyPaymentLedgerInvariant` requires it, `escrow.ts:402`; `isSettledPayment` still accepts it, `escrow.ts:142`). The `Refund` row carries `percent = round(amount / payment.amount × 100)` for display only and `fromEscrow: true`. `applyRefundToPayment` itself is not used (it refunds a percent of the whole payment and requires `escrowStatus` `held`, which a split payment with a released shoot milestone is not).
5. **Refund destination follows V2.** The refund row is built like `applyRefundToPayment` builds it: `method = refundMethodOf(payment.method)`, `destination = payment.payer ? {...payer, source: 'payer'} : null`, `status = awaiting_account` when a bank transfer has no payer, else `pending`. `notifyRefundAccountNeeded` (`notification_hooks.ts:732`) exists but has **no caller** on `develop`, and the S22.04 screen does not exist yet (#141). So: when the refund is `awaiting_account`, the trigger of Task 3 calls `notifyRefundAccountNeeded` (this plan is its first caller; its target stays whatever the hook sets), and the app shows the existing "Đang hoàn" state on the booking. Opening S22.04 from the sheet waits for #141 (Deferred).
6. **Disputed money is untouchable.** `escrowStatus === 'disputed'` (a dispute opened at `shot`) → `conflict`. A legacy payment without `milestones` → `not_eligible` (no second milestone to refund; such bookings predate #152 and will not be `shot` with a late provider in practice).
7. **The booking ends `completed`** with `completedAt = now` and a new `deliveryCancel: {at, dueAt, refundedAmount}` block (so the timeline, the provider notice and the staff dashboard know *why* it completed without a delivery). `depositRefunded += amount`; `escrowStatus` = the payment's recomputed status; `samplesPurgeAfter` is not set (no samples exist in `shot`). The booking event is `{status: 'completed', actorId: customerId}`.
8. **Milestone 1 is not touched.** Whether `held` (inside the 24 h window) or `released`, the shoot milestone keeps its state; the existing `releaseDueMilestones` sweep releases a `held` one at its `releaseAfter` as today.
9. **One notification.** `delivery_cancelled_late` (`meta('booking', 'activity', true)`) to the provider, target `/b/{id}`. Copy lives where every type's copy lives: the `NotificationContent` union and `renderNotification` in `packages/domain/src/notification_render.ts` (title "Khách đã huỷ phần bàn giao", body "{customer} huỷ vì quá hạn bàn giao · hoàn {amount} (mốc 2) cho khách"; `notification_render.test.ts:240` fails for a type without copy), plus a case in the app's `notification_visuals.dart` (icon `AppIcons.info`, error tone). The customer gets the existing `refund_done` when the refund lands. No reminder before the deadline (Deferred).
10. **Owner ruling (a) is pinned by a test, not by code.** `approveDelivery` as system with `extraRound.status = 'pending'` already approves and clears the request; Task 2 adds the test `auto-approve proceeds while an extra round is pending and clears it` so nobody "fixes" it later.
11. **Owner ruling (b) is explicit code.** `openDispute` refuses `completed` for a payment with `milestones` *before* loading the payment (`conflict`), keeping the legacy 24-hour-after-completion window only for single-escrow payments.
12. **Staff flag.** `isDeliveryLate` and `deliveryDueAt` are exported from `@photobooking/domain`; Task 6 comments on #165 with the names and the `bookings(status == 'shot', shotAt)` query shape. No Phase 1 staff screen or CLI.
13. **Customer UI.** In `shot`, for both roles, the S05.02 timeline step "Bàn giao & duyệt ảnh" gets the subtitle "Hạn bàn giao {date}" (it replaces the customer's `timelineDeliveryWaitCustomer` subtitle; after the deadline: "Hạn bàn giao {date} · đã quá {n} ngày"). After the deadline the customer sees, above the timeline, the section header "Bàn giao ảnh" with the red trailing label "Quá hạn" and the card `LateDeliveryCard` (the mock's `warnc` block, like `#S05.02-studio-late`) with the red text button "Huỷ phần bàn giao" (`DetailAction.cancelLateDelivery`). The primary button is unchanged. The sheet S05.08 (`showLateCancelSheet`) shows two amount rows (milestone 2 refunded, milestone 1 kept), one line of consequence, "Chờ thêm" (outline) and "Huỷ phần bàn giao" (red). Amounts come from the booking's milestone read model (`bookings/{id}/milestones/{kind}`, written by the `onPaymentWritten` trigger on every payment write with milestones, `triggers/payment_write.ts:18–33`, so `refunded` reaches the app with no Functions change) through a small `bookingMilestonesProvider(id)`; when the read model is missing (legacy), the sheet shows 50/50 of `deposit − depositRefunded` and the server stays the authority.
14. **Sheet outcomes.** `showConfirmSheet` keeps the sheet open and shows a SnackBar when `onConfirm` throws (`core/widgets/confirm_sheet.dart:18–44`). S05.08 needs to close on the "nothing to do any more" errors, so it builds its own `AppBottomSheet` content (same look as `ConfirmSheet`) and returns `LateCancelOutcome {cancelled, kept, alreadyDelivered, notLate, disputed, failed}`; S05.02 shows the toast for each (`failed` keeps the sheet open with the generic error, like `ConfirmSheet`). The server tells the cases apart with the `field` of `DomainError(code, field?)`: `not_eligible` with field `delivered` (status is `delivered`/`revision_requested`/`approved`), `not_late` (still `shot` before the deadline), `status` (anything else); `conflict` = disputed. The app maps `failed-precondition` + `details.field` through `bookingErrorOf`.
15. **Provider UI.** `_StatusNoticeCard` on S05.02 for a `completed` booking with `deliveryCancel`: "Khách đã huỷ phần bàn giao vì quá hạn (hạn {date}). Bạn giữ mốc 1, mốc 2 đã hoàn cho khách." The S06.01 "Chờ bàn giao" section drops the booking (it is `completed`). S06.05 has no per-milestone row today: an earning item shows "mốc {done}/{total}" (`milestonesOfDocs`, `infra/earnings_firestore.ts:102`; `earningItemOf`, `data/earnings/earnings.dart:137–139`; `_meta`, `features/earnings/earnings_screen.dart:434`). A `refunded` milestone is excluded from `total` and the item gets the suffix " · mốc 2 đã hoàn cho khách", so the provider sees "mốc 1/1 · mốc 2 đã hoàn cho khách" instead of "mốc 1/2" forever.
16. **App dispute rule follows ruling (b).** `BookingRules.canCustomerDispute` (`data/booking/booking_rules.dart:153`) allows `completed` with escrow `held` today, which a late-cancelled booking with a held shoot milestone would hit. It returns false for `completed` when the booking is two-layer (`approvedAt != null` or `deliveryCancel != null`); legacy single-escrow bookings keep the 24-hour rule.
17. **Late cancels are not "completed jobs".** `shot → completed` runs the badge check and `refreshCompletedCount` in the booking-write trigger (`triggers/booking_write.ts:96–108`). A booking that completed through `deliveryCancel` is skipped by both (the count query and the badge rule ignore bookings with `deliveryCancel`), so a late provider's public count does not grow. Needs the owner 4.
18. **Review after a late cancel** stays allowed (`completed` is reviewable today); the review form is unchanged.
19. **Analytics**: `booking_action{action: 'cancel_late_delivery'}` on confirm (existing event name).

## Needs the owner

1. Default `deliveryDays` for packages that never set one: 7 (Decision 2). Say if the default should be longer for wedding packages.
2. After the late cancel the customer may still review the provider (Decision 15). Default: yes.
3. No "Sắp trễ hạn" reminder to the provider before the deadline (Deferred). Default: none in this unit; S17 can add `delivery_due_soon` later.
4. A booking ended by a late cancel does not count toward the provider's public "completed" count and badges (Decision 17). Default: it does not count.
5. Until #141 ships S22.04, a bank-transfer refund without a known sender account waits as `awaiting_account` with the `refund_account_needed` notification (Decision 5). Default: acceptable for Phase 1.

## Contract

### Firestore

| Path | Fields | Writer / readers |
|---|---|---|
| `photographers/{uid}/services/{id}` | `deliverables.deliveryDays` (exists, int 0–90) | provider (client) / signed-in (unchanged) |
| `bookings/{id}` | adds `deliveryDays: int` (snapshot, 1–90), `deliveryCancel: {at: Timestamp, dueAt: Timestamp, refundedAmount: int} \| null` | server / parties (unchanged rule) |
| `payments/{id}` | `milestones[kind == 'delivery'].status` becomes `refunded`; `refundedAmount` grows | server |
| `refunds/{id}` | one row `{paymentId, amount, percent, fromEscrow: true, reason: 'late_delivery', …}` | server |
| `bookings/{id}/milestones/delivery` (read model of #152) | `status: 'refunded'` | server / parties |
| `notifications/…` | type `delivery_cancelled_late` | server |

No new collection, rule or index.

### Domain (`packages/domain/src`)

```ts
// delivery_deadline.ts (new)
export const DEFAULT_DELIVERY_DAYS = 7, DELIVERY_DAYS_MIN = 1, DELIVERY_DAYS_MAX = 90;
export function clampDeliveryDays(v: unknown): number;          // not an integer or < 1 → DEFAULT; > 90 → 90
export function deliveryDueAt(b: Pick<Booking, 'shotAt' | 'deliveryDays'>): Date | null;   // null without shotAt
export function isDeliveryLate(b: Pick<Booking, 'status' | 'shotAt' | 'deliveryDays'>, now: Date): boolean;

// booking.ts: Booking adds
//   readonly deliveryDays?: number;
//   readonly deliveryCancel?: { readonly at: string; readonly dueAt: string; readonly refundedAmount: number } | null;
// booking_ports.ts: ServiceRecord adds readonly deliveryDays?: number;   (from deliverables.deliveryDays)
// create_booking.ts: BookingDraftInput/buildBookingDraft copy deliveryDays = clampDeliveryDays(service.deliveryDays)

// milestones.ts adds
export function refundMilestone(
  p: Payment, kind: MilestoneKind, refundId: string, ledgerEntryId: string, now: Date, reason: string,
): { payment: Payment; refund: Refund; ledgerEntry: LedgerEntry };
// conflict unless p.milestones and the milestone is `held`; payment: milestone → refunded, withMilestones(...), refundedAmount += amount, status: 'partially_refunded' (Decision 4);
// refund: {id, paymentId, subjectType, amount, percent: Math.round(amount / p.amount * 100), status: awaiting_account | pending (Decision 5),
//   manual: false, fromEscrow: true, method: refundMethodOf(p.method), destination, attempts: 0, lastAttemptAt (when pending), reason, createdAt, updatedAt};
// ledgerEntry: {id, type: 'refund_issued', paymentId, refundId, subjectType, subjectId, accountOwnerId: p.payerId, amount: -amount, note: reason, at}

// delivery_use_cases.ts adds
export interface CancelLateDeliveryInput { readonly bookingId: string; readonly customerId: string }
export async function cancelLateDelivery(deps: BookingDeps, input: CancelLateDeliveryInput): Promise<Booking>;
// invalid_argument (ids) · not_found · permission_denied (not the customer) · not_eligible with field 'delivered' (delivered | revision_requested | approved),
// 'not_late' (shot, now ≤ dueAt), 'status' (anything else, incl. completed and no milestones) (Decision 14)
// · conflict (escrowStatus disputed). Finds the settled milestone payment with deps.store.getPaymentsForBooking (outside, like commitTransition),
// then inside the transaction re-reads it with tx.getPayment(id) so a concurrent payout (payoutId) or release is never overwritten; writes payment, refund,
// ledger, booking {status: completed, completedAt, deliveryCancel, depositRefunded, escrowStatus, version + 1}, booking event; after commit:
// dispatchRefund(deps, refund, payment.provider) (like commitTransition).

// open_dispute.ts: before the payment lookup —
//   if (booking.status === 'completed' && (await hasMilestones(...))) throw new DomainError('conflict');
// implemented as: load payments once, pick the settled one; if booking.status === 'completed' && payment.milestones → conflict (Decision 11).

// notification.ts: NOTIFICATION_TYPES adds delivery_cancelled_late: meta('booking', 'activity', true)
// notification_render.ts: NotificationContent adds {type: 'delivery_cancelled_late', customer: string, amount: number}; renderNotification title/body (Decision 9)
// notification_hooks.ts adds
export async function notifyDeliveryCancelledLate(
  deps: NotifyDeps, e: { bookingId: string; customerId: string; providerId: string; amount: number },
): Promise<NotifyResult>;   // userId: providerId; content {type, customer: name, amount}; target `/b/${bookingId}`; dedupeKey `delivery_cancelled_late_${bookingId}`

// index.ts exports the new names.
```

### Callables (`asia-southeast1`)

| Callable | Options | Input | Output | Errors (`details.code`) |
|---|---|---|---|---|
| `cancelLateDelivery` | `BOOKING_REFUND_CALLABLE_OPTIONS` (it refunds) | `{bookingId}` | `{status: 'completed', refundedAmount}` | `unauthenticated`, `invalid_argument`, `not_found`, `permission_denied`, `not_eligible`, `conflict` |

Transport codes are the existing map (`not_eligible` → `failed-precondition`, `conflict` → `aborted`). Trigger: `onBookingWrite` detects `before.status === 'shot' && after.status === 'completed' && after.deliveryCancel` and calls `notifyDeliveryCancelledLate` (inside the existing `notifyBookingChange` or next to it; Task 3 Step 1 decides by reading `booking_write.ts`).

### App (`app_flutter/lib`)

```dart
// data/booking/booking.dart: Booking adds  int deliveryDays (default 7),  DeliveryCancel? deliveryCancel
@freezed class DeliveryCancel { DateTime at; DateTime dueAt; int refundedAmount; }
// data/booking/booking_rules.dart: BookingRules adds
static DateTime? deliveryDueAt(Booking b);                 // shotAt + deliveryDays days
static bool isDeliveryLate(Booking b, DateTime now);       // status shot && dueAt != null && now.isAfter(dueAt)
// data/booking/booking_repository.dart
Future<Booking> cancelLateDelivery({required String bookingId});   // callable cancelLateDelivery, maps errors with bookingErrorOf
// data/booking/booking_providers.dart
final bookingMilestonesProvider = StreamProvider.family<BookingMilestones?, String>(…);   // bookings/{id}/milestones/{shoot,delivery}
@immutable class BookingMilestones { final int shootAmount, deliveryAmount; final String shootStatus, deliveryStatus; }
// features/booking/booking_view_rules.dart: DetailAction adds cancelLateDelivery (customer, status shot, isDeliveryLate)
// features/booking/late_cancel_sheet.dart (S05.08)
Future<bool?> showLateCancelSheet(BuildContext context, {required Booking booking, required String providerName, BookingMilestones? milestones});
// features/booking/widgets/late_delivery_card.dart: LateDeliveryCard({required Booking booking, required String providerName, required VoidCallback onCancel})
// core/screen_codes.dart: cancelLateDelivery = 'S05.08' (already added with the mock)
```

### l10n keys (`lib/l10n/app_vi.arb`, exact text)

- S05.02 (both roles, `shot`): `detailDeliveryDue` "Hạn bàn giao {date}"; `detailDeliveryOverdue` "Hạn bàn giao {date} · đã quá {n} ngày"; customer only: `lateDeliverySection` "Bàn giao ảnh"; `lateDeliveryOverdueLabel` "Quá hạn"; `lateDeliveryTitle` "{name} chưa bàn giao đúng hạn (trước {date})"; `lateDeliveryBody` "Bạn có thể chờ thêm hoặc huỷ phần bàn giao và nhận lại mốc 2."; `lateDeliveryCancel` "Huỷ phần bàn giao".
- S05.08 (sheet): `lateCancelTitle` "Huỷ phần bàn giao?"; `lateCancelRefundRow` "Hoàn mốc 2 cho bạn"; `lateCancelKeepRow` "{name} giữ mốc 1 (buổi chụp)"; `lateCancelNote` "Buổi chụp được tính là hoàn thành, bạn sẽ không nhận ảnh. Nếu {name} bàn giao sau khi huỷ thì không còn qua app."; `lateCancelWait` "Chờ thêm"; `lateCancelConfirm` "Huỷ phần bàn giao"; `lateCancelDoneToast` "Đã huỷ phần bàn giao · hoàn {amount}"; `lateCancelNotLate` "Chưa quá hạn bàn giao."; `lateCancelDisputed` "Booking đang khiếu nại, không huỷ được."; `lateCancelAlreadyDelivered` "{name} vừa nộp bàn giao. Xem bàn giao trước khi quyết định.".
- S05.02 (provider, `completed` + `deliveryCancel`): `detailLateCancelledProvider` "Khách đã huỷ phần bàn giao vì quá hạn (hạn {date}). Bạn giữ mốc 1, mốc 2 đã hoàn cho khách."; timeline: `timelineLateCancelled` "Đã huỷ phần bàn giao · hoàn {amount}".
- S06.05: `earningsMilestoneRefundedSuffix` " · mốc {n} đã hoàn cho khách" (Decision 15).
- Notification (server copy in `notification_render.ts`, Decision 9): title "Khách đã huỷ phần bàn giao", body "{customer} huỷ vì quá hạn bàn giao · hoàn {amount} (mốc 2) cho khách".

## Review Focus

1. **The provider submits in the same minute the customer cancels.** Both transactions read `status: shot`; one wins. Pinned: Task 2 `cancelLateDelivery after a concurrent submitDelivery is not_eligible` (memory store serializes: submit first → status `delivered` → cancel refused) and `submitDelivery after cancelLateDelivery is not_eligible` (status `completed`, `canDeliver` false); Task 5 `S05.08 shows lateCancelAlreadyDelivered on not_eligible and closes`.
2. **A disputed shoot milestone.** Dispute at `shot` sets `escrowStatus: disputed` and the shoot milestone `disputed`; a late cancel must not refund around it. Pinned: Task 2 `cancelLateDelivery on a disputed booking is conflict and writes nothing`.
3. **Old bookings without `deliveryDays`.** Absent field must read as 7, never as 0 (which would make every `shot` booking late at once). Pinned: Task 2 `clampDeliveryDays(undefined | 0 | 1.5 | -3) is 7` and `isDeliveryLate on a booking without deliveryDays uses 7 days`; Task 3 `bookingFromFirestore without deliveryDays yields undefined and the app default is 7`; Task 4 `bookingFromFirestore without deliveryDays reads 7`.
4. **Refund money twice.** A second call after success, or a retry after the gateway call failed. Pinned: Task 2 `a second cancelLateDelivery is not_eligible (status completed)`, `refundMilestone on a refunded milestone is conflict`; Task 3 `callable returns the refundedAmount of the first call only` (unit, fake deps).
5. **Milestone 1 silently refunded.** The refund must be the delivery milestone only, whatever its order in the array. Pinned: Task 2 `refundMilestone leaves the shoot milestone untouched (held and released cases) and the ledger entry equals -delivery.amount`, `the payment's refundedAmount grows by the delivery amount only`.

## Chi phí Google

Unit prices from `2026-10-07-google-cloud-costs.md`. One late cancel ≈ 4 reads (booking, payments, refunds, milestones read model) + 5 writes (payment, refund, ledger, booking, booking event) + 1 notification write, plus the existing refund gateway call (fake rails). Expected frequency: well under 1% of bookings. (b) 1,000 MAU ≈ 10 late cancels/month → < $0.001; (c) 10,000 MAU ≈ 100/month → < $0.01. The S05.02 screen adds one listener on `bookings/{id}/milestones` only while the sheet is open (2 reads). No new job, trigger, index or Scheduler entry. Total **+$0.0x/month** at both scales.

## Tasks

### Task 1: Spec check, deadline snapshot and the pure predicate

**Files:**
- Create: `packages/domain/src/delivery_deadline.ts`; test `packages/domain/test/delivery_deadline.test.ts`.
- Modify: `packages/domain/src/booking.ts` (`deliveryDays?`, `deliveryCancel?`), `booking_ports.ts` (`ServiceRecord.deliveryDays?`), `create_booking.ts` (`BookingDraftInput`/`buildBookingDraft` copy `deliveryDays`), `index.ts`; `docs/superpowers/specs/data-model/domain-model.md` (§2 `Booking.deliveryDays`, `deliveryCancel`; §6 invariant "huỷ phần bàn giao chỉ khi `shot` và quá hạn"), `relational-schema.md` (`bookings.delivery_days`, `bookings.delivery_cancelled_at`, `delivery_due_at` derived).

**Interfaces:**
- Consumes: `Booking`, `ServiceRecord`, `buildBookingDraft` (`create_booking.ts`), `clampRevisions` (pattern).
- Produces: `DEFAULT_DELIVERY_DAYS`, `DELIVERY_DAYS_MIN/MAX`, `clampDeliveryDays`, `deliveryDueAt`, `isDeliveryLate`, `Booking.deliveryDays`, `Booking.deliveryCancel`, `ServiceRecord.deliveryDays`.

- [ ] **Step 1: Contract check.** On the branch confirm the names in "Contract with existing code" (`buildBookingDraft` and its `revisionsIncluded` line, `BookingServiceSnapshot`, `ServiceRecord.revisions`); confirm `#S05.02-late`, `#S05.08`, `ScreenCodes.cancelLateDelivery` and the §2 row exist (drawn with this plan). Ledger the exact line numbers. Stop if `buildBookingDraft` is missing.
- [ ] **Step 2: Failing tests** (`delivery_deadline.test.ts`): `clampDeliveryDays(undefined | null | 0 | -3 | 1.5 | 'x') is 7`; `clampDeliveryDays(1) is 1, (90) is 90, (91) is 90`; `deliveryDueAt without shotAt is null`; `deliveryDueAt with shotAt 2026-10-10T10:00Z and 5 days is 2026-10-15T10:00Z`; `isDeliveryLate is false one second before dueAt and true one second after`; `isDeliveryLate is false on delivered, revision_requested, approved, completed even past dueAt`; `isDeliveryLate without deliveryDays uses 7 days`. In `create_booking.test.ts` (existing file): `buildBookingDraft copies deliveryDays from the service (5 → 5; absent → 7; 120 → 90)`.
- [ ] **Step 3:** `cd packages/domain && npm test` → the new tests fail.
- [ ] **Step 4: Implement** `delivery_deadline.ts` (pure, no imports beyond `booking.ts` types); extend the three interfaces and `buildBookingDraft` (one line next to `revisionsIncluded`); export from `index.ts`; update the two data-model docs (Vietnamese prose like the rest).
- [ ] **Step 5:** `npm test && npm run lint && npm run typecheck` → pass; `purity.test.ts` still passes.
- [ ] **Step 6: Commit** `feat(domain): delivery deadline snapshot and late predicate [#207]`.

### Task 2: Domain — `refundMilestone`, `cancelLateDelivery`, the two owner rulings

**Files:**
- Modify: `packages/domain/src/milestones.ts` (`refundMilestone`), `delivery_use_cases.ts` (`cancelLateDelivery`), `open_dispute.ts` (Decision 11), `notification.ts` (type), `notification_render.ts` (content + copy), `notification_hooks.ts` (hook), `index.ts`; tests `packages/domain/test/milestones.test.ts`, `delivery_use_cases.test.ts`, `open_dispute.test.ts` (or the existing dispute test file), `notification_hooks.test.ts` (or the existing hooks test).

**Interfaces:**
- Consumes: Task 1; `withMilestones`, `releaseMilestone` (pattern), `refundMethodOf`, `Refund`, `LedgerEntry`, `isSettledPayment`, `dispatchRefund`, `BookingTx`, `roleOf`, `test/support/booking_world.ts` (memory store, fake clock and ids).
- Produces: Contract → Domain (`refundMilestone`, `cancelLateDelivery`, `notifyDeliveryCancelledLate`, type `delivery_cancelled_late`).

- [ ] **Step 1: Contract check.** Confirm `applyRefundToPayment`'s refund-row fields (Decision 5), `dispatchRefund(deps, refund, provider)`, `disputeEscrowPayment`'s `conflict` on released payments, where `refund_account_needed` is sent for `awaiting_account` refunds (grep `notifyRefundAccountNeeded`; ledger the trigger site), and that `approveDelivery` as system clears a pending `extraRound`. Ledger.
- [ ] **Step 2: Failing tests.**
  - `milestones.test.ts`: `refundMilestone on a held delivery milestone: milestone refunded, shoot untouched (held case), payment.status partially_refunded, payment.refundedAmount += amount, escrowStatus recomputed, verifyPaymentLedgerInvariant holds, refund {amount, percent 50, fromEscrow true, status pending} and ledger {type refund_issued, amount -delivery.amount, accountOwnerId payerId}`; `refundMilestone with the shoot milestone already released leaves it released`; `refundMilestone on a released or refunded delivery milestone is conflict`; `refundMilestone on a payment without milestones is conflict`; `a bank-transfer payment without payer yields status awaiting_account and destination null`; `a payment with payer yields destination {…payer, source: 'payer'}`.
  - `delivery_use_cases.test.ts` (booking world: customer `c1`, provider `p1`, booking `shot` with `shotAt = now − 8 days`, `deliveryDays 5`, payment paid with milestones 500k/500k, shoot released):
    - `cancelLateDelivery by the customer past the deadline: booking completed with completedAt, deliveryCancel {at, dueAt, refundedAmount 500000}, depositRefunded 500000, escrowStatus from the payment, version + 1; one refund row; one ledger row; booking event completed with actorId c1`.
    - `the provider calling it is permission_denied`; `a stranger is permission_denied`; `an unknown booking is not_found`; `a bad id is invalid_argument`.
    - `before the deadline it is not_eligible field not_late and nothing is written`; `exactly at dueAt it is not_eligible field not_late`.
    - `on delivered, revision_requested, approved it is not_eligible field delivered; on completed, upcoming it is not_eligible field status`.
    - `a payout stamping payoutId on the shoot milestone between the lookup and the transaction is kept` (the use case re-reads with tx.getPayment).
    - `cancelLateDelivery on a disputed booking is conflict and writes nothing` (Review Focus 2).
    - `a legacy payment without milestones is not_eligible`.
    - `a second cancelLateDelivery is not_eligible` (Review Focus 4).
    - `cancelLateDelivery after a concurrent submitDelivery is not_eligible` and `submitDelivery after cancelLateDelivery is not_eligible` (Review Focus 1).
    - `the gateway is called once after commit with the refund` (fake gateway records calls) and `a gateway failure leaves the refund pending for the clock` (status stays `pending`, booking stays `completed`).
    - `auto-approve proceeds while an extra round is pending and clears it` (Decision 10; may already exist under another name — then only rename/keep).
  - dispute test file: `openDispute on a completed milestone booking is conflict before any payment write`; `openDispute on a completed legacy (no milestones) booking inside 24 h still works`.
  - hooks test: `notifyDeliveryCancelledLate notifies the provider with type delivery_cancelled_late, target /b/{id}, dedupe key delivery_cancelled_late_{id}`; `notification_render.test.ts` passes (copy exists for the new type) and `renderNotification` returns the title and body of Decision 9.
- [ ] **Step 3:** `npm test` → the new tests fail.
- [ ] **Step 4: Implement.** Hard part, the transaction body (reads before writes, Firestore refuses reads after writes):
  ```ts
  export async function cancelLateDelivery(deps: BookingDeps, input: CancelLateDeliveryInput): Promise<Booking> {
    if (!isId(input.bookingId) || !isId(input.customerId)) throw new DomainError('invalid_argument');
    const now = deps.clock.now(); const at = now.toISOString();
    let pending: { refund: Refund; provider: Payment['provider'] } | undefined;
    const updated = await deps.store.runTransaction(async (tx) => {
      const b = await tx.getBooking(input.bookingId);
      if (!b) throw new DomainError('not_found');
      if (b.customerId !== input.customerId) throw new DomainError('permission_denied');
      if (['delivered', 'revision_requested', 'approved'].includes(b.status)) throw new DomainError('not_eligible', 'delivered');
      if (b.status !== 'shot') throw new DomainError('not_eligible', 'status');
      if (b.escrowStatus === 'disputed') throw new DomainError('conflict');
      if (!isDeliveryLate(b, now)) throw new DomainError('not_eligible', 'not_late');
      const found = (await deps.store.getPaymentsForBooking(b.id)).find((p) => isSettledPayment(p) && p.milestones);
      const payment = found ? await tx.getPayment(found.id) : null;            // re-read inside the transaction (Decision 14 note)
      if (!payment || !payment.milestones) throw new DomainError('not_eligible', 'status');
      const r = refundMilestone(payment, 'delivery', deps.ids.newId(), deps.ids.newId(), now, 'late_delivery');
      await tx.setPayment(r.payment); await tx.addRefund(r.refund); await tx.addLedgerEntry(r.ledgerEntry);
      const dueAt = deliveryDueAt(b)!.toISOString();
      const next: Booking = { ...b, status: 'completed', completedAt: at, escrowStatus: r.payment.escrowStatus,
        depositRefunded: (b.depositRefunded ?? 0) + r.refund.amount,
        deliveryCancel: { at, dueAt, refundedAmount: r.refund.amount }, version: b.version + 1, updatedAt: at };
      await tx.setBooking(next);
      await tx.addBookingEvent({ id: deps.ids.newId(), bookingId: b.id, status: 'completed', at, actorId: input.customerId });
      pending = { refund: r.refund, provider: payment.provider };
      return next;
    });
    if (pending && pending.refund.status === 'pending') await dispatchRefund(deps, pending.refund, pending.provider);
    return updated;
  }
  ```
  `refundMilestone` mirrors `releaseMilestone` + the row construction of `applyRefundToPayment`. `openDispute`: after the status/window checks and the payments read, `if (booking.status === 'completed' && payment.milestones) throw new DomainError('conflict')`.
- [ ] **Step 5:** `npm test && npm run lint && npm run typecheck` → pass.
- [ ] **Step 6: Commit** `feat(domain): cancel the delivery part when late, milestone refund, dispute ruling [#207]`.

### Task 3: Functions — callable, adapters, notification trigger, seed

**Files:**
- Modify: `app_flutter/firebase/functions/src/callables/delivery.ts` (`handleCancelLateDelivery`), `src/index.ts` (`export const cancelLateDelivery = onCall(BOOKING_REFUND_CALLABLE_OPTIONS, …)`), `src/infra/booking_readers.ts` (`deliveryDays` from `deliverables.deliveryDays`), `src/infra/booking_firestore.ts` (`deliveryDays`, `deliveryCancel` both ways; milestone read model already written by #152's `setPayment` path — verify), `src/triggers/booking_write.ts` (hook call; `notifyRefundAccountNeeded` when the new refund is `awaiting_account`; skip `refreshCompletedCount` and the badge check when `after.deliveryCancel` is set, Decision 17), `src/infra/discovery_firestore.ts` or wherever `refreshCompletedCount` queries (exclude `deliveryCancel`), `seed/fixtures.ts` (add optional `deliveryDays` and `shotHoursAgo` to `SeedBooking`; one `shot` booking 240 h old, `deliveryDays: 5`, paid with milestones, shoot released: Lan ↔ An) + `seed/apply.ts` + `seed/README.md`; tests `test/unit/delivery_callables.test.ts`, `booking_readers.test.ts`, `booking_firestore.test.ts`, `discovery_triggers.test.ts` (the trigger's tests), `seed_fixtures.test.ts`.

**Interfaces:**
- Consumes: Task 2; `CallableInput`, `handleCallableError`, `BOOKING_REFUND_CALLABLE_OPTIONS`, `liveBookingDeps`, `notifyBookingChange` pattern.
- Produces: callable `cancelLateDelivery` `{bookingId} → {status, refundedAmount}`; Firestore fields `deliveryDays`, `deliveryCancel`.

- [ ] **Step 1: Contract check.** Read `booking_write.ts` and decide whether the hook goes inside `notifyBookingChange` (domain) or next to it in the trigger; find the query behind `refreshCompletedCount` and the badge rule; ledger. The milestone read model is already written by `onPaymentWritten` (`triggers/payment_write.ts:18–33`) on every payment write with milestones; no change there.
- [ ] **Step 2: Failing tests.** `handleCancelLateDelivery: unauthenticated without auth; passes {bookingId, customerId: uid}; returns {status: 'completed', refundedAmount}; maps not_eligible → failed-precondition and conflict → aborted`; `callable returns the refundedAmount of the first call only` (fake deps: second call throws not_eligible); `bookingReaders: deliverables.deliveryDays 5 → ServiceRecord.deliveryDays 5; absent → undefined`; `bookingToFirestore writes deliveryDays and deliveryCancel {at, dueAt, refundedAmount} as Timestamps/ints and null when absent`; `bookingFromFirestore reads them back; without deliveryDays yields undefined` (Review Focus 3); trigger (in `discovery_triggers.test.ts`): `shot → completed with deliveryCancel sends delivery_cancelled_late to the provider once and does not refresh the completed count or badges; completed without deliveryCancel behaves as today; an awaiting_account refund sends refund_account_needed once`; seed: `the late seed booking is shot 240 h ago, deliveryDays 5, with a delivery milestone held`.
- [ ] **Step 3:** `npm test` → fail.
- [ ] **Step 4: Implement.** Handler is a copy of `handleApproveDelivery` with `cancelLateDelivery(deps, {bookingId, customerId: uid})` and `{status: b.status, refundedAmount: b.deliveryCancel?.refundedAmount ?? 0}`.
- [ ] **Step 5:** `npm run lint && npm run typecheck && npm test && npm run build` → pass. Integration test (written, not run): `test/integration/delivery_late_cancel.test.ts` — seed the late booking, call the callable as Lan, assert booking `completed`, payment milestone `refunded`, one refund row, An's notification.
- [ ] **Step 6: Commit** `feat(functions): cancelLateDelivery callable, booking fields and seed [#207]`.

### Task 4: App data — booking fields, repository, rules helpers, milestones read model

**Files:**
- Modify: `app_flutter/lib/data/booking/booking.dart` (+ `build_runner`; `bookingFromFirestore`), `booking_rules.dart` (`deliveryDueAt`, `isDeliveryLate`, `canCustomerDispute` per Decision 16), `booking_repository.dart` (interface) + `firestore_booking_repository.dart` (`cancelLateDelivery`; `bookingErrorOf` reads `details.field`), `booking_providers.dart` (`bookingMilestonesProvider`), `data/booking/booking_milestones.dart` (new, `BookingMilestones` + `fromDocs`); `test/support/fake_booking_repository.dart`; tests `test/data/booking/booking_mapping_test.dart` (or the existing mapping test), `booking_rules_test.dart`, `booking_repository_test.dart`.

**Interfaces:**
- Consumes: Task 3's fields; `cloud_functions` callable pattern of `transitionBooking`; `bookingErrorOf`.
- Produces: Contract → App data.

- [ ] **Step 1: Failing tests.** `bookingFromFirestore without deliveryDays reads 7; with 5 reads 5` (Review Focus 3); `canCustomerDispute is false on a completed two-layer booking (approvedAt or deliveryCancel set) even with escrow held, true on a legacy completed booking inside 24 h`; `bookingErrorOf maps failed-precondition with details.field delivered/not_late to alreadyDelivered/notLate`; `DeliveryCancel maps at/dueAt/refundedAmount from Timestamps`; `BookingRules.deliveryDueAt = shotAt + deliveryDays days; null without shotAt`; `BookingRules.isDeliveryLate is true only for shot past dueAt`; `cancelLateDelivery calls the callable with {bookingId} and maps failed-precondition → notEligible, aborted → conflict`; `BookingMilestones.fromDocs reads shoot/delivery amounts and statuses; missing docs → null`.
- [ ] **Step 2:** `flutter test --no-pub --timeout 60s test/data/booking` → fail.
- [ ] **Step 3: Implement**; `dart run build_runner build --delete-conflicting-outputs` for the freezed changes.
- [ ] **Step 4:** tests pass; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(data): delivery deadline, late cancel call and milestone read model [#207]`.

### Task 5: App UI — S05.02 late card, S05.08 sheet, provider notice, earnings label

**Files:**
- Create: `app_flutter/lib/features/booking/late_cancel_sheet.dart` (S05.08), `features/booking/widgets/late_delivery_card.dart`; tests `test/features/booking/late_cancel_sheet_test.dart`, `late_delivery_card_test.dart`.
- Modify: `features/booking/booking_view_rules.dart` (`DetailAction.cancelLateDelivery`; timeline subtitle "Hạn bàn giao {date}" in `shot`; a `completed` step "Đã huỷ phần bàn giao · hoàn {amount}" when `deliveryCancel`), `booking_detail_screen.dart` (`_onAction` case → sheet → toast; `_StatusNoticeCard` provider text; card placement above the timeline), `data/earnings/earnings.dart` + `app_flutter/firebase/functions/src/infra/earnings_firestore.ts` (`milestonesOfDocs` excludes `refunded` from `total` and reports refunded kinds) + `features/earnings/earnings_screen.dart` (`_meta` suffix, Decision 15), `features/notifications/notification_visuals.dart` (case `delivery_cancelled_late`), `lib/l10n/app_vi.arb` (+ `flutter gen-l10n`); tests `booking_view_rules_test.dart`, `booking_detail_screen_test.dart`, `test/features/earnings/*` (if touched).

**Interfaces:**
- Consumes: Task 4; `showConfirmSheet`, `ConfirmSheet`, `StatusTimeline`, `AppButton.text` (red), `formatMoney`, `formatDayMonth`, `bookingMilestonesProvider`, mock frames `#S05.02-late`, `#S05.08`.
- Produces: `DetailAction.cancelLateDelivery`, `showLateCancelSheet`, `LateDeliveryCard`.

- [ ] **Step 1: Contract check.** Read `#S05.02-late` and `#S05.08` in the mock for copy and order; read the earnings mapper for the milestone statuses it labels; ledger.
- [ ] **Step 2: Failing tests.**
  - `booking_view_rules_test.dart`: `customer on shot past dueAt gets cancelLateDelivery; before dueAt not; provider never`; `timeline in shot shows "Hạn bàn giao {date}"`; `timeline of a completed booking with deliveryCancel shows "Đã huỷ phần bàn giao · hoàn 500.000₫" and no delivery step`.
  - `late_delivery_card_test.dart`: `shows lateDeliveryTitle with the provider name and the due date, lateDeliveryBody, and the red text button`; `fits 320 dp at 1.3× text`.
  - `late_cancel_sheet_test.dart`: `rows show milestone 2 amount and milestone 1 amount from BookingMilestones; without milestones shows 50/50 of deposit − depositRefunded`; `"Chờ thêm" returns LateCancelOutcome.kept; "Huỷ phần bàn giao" (AppColors.error) calls cancelLateDelivery once and returns cancelled`; `alreadyDelivered closes the sheet and S05.02 toasts lateCancelAlreadyDelivered` (Review Focus 1); `notLate closes and toasts lateCancelNotLate`; `disputed closes and toasts lateCancelDisputed`; `a network failure keeps the sheet open with the generic error`; `the confirm button is disabled while the call runs`.
  - earnings: `an item whose delivery milestone is refunded reads "mốc 1/1 · mốc 2 đã hoàn cho khách"` (Functions `earnings_firestore.test.ts` for `milestonesOfDocs`, app `earnings_screen_test.dart` for the line).
  - notifications: `notification_visuals has a case for delivery_cancelled_late`.
  - `booking_detail_screen_test.dart`: `customer sees LateDeliveryCard only when late; tapping opens the sheet; after success the toast "Đã huỷ phần bàn giao · hoàn 500.000₫" shows and the primary button stays "Nhắn tin"`; `provider sees detailLateCancelledProvider on a completed booking with deliveryCancel and no "Nộp bàn giao"`; `golden-free layout at 320 dp, 1.3×, dark and light`.
- [ ] **Step 3:** `flutter test --no-pub --timeout 60s test/features/booking` → fail.
- [ ] **Step 4: Implement.** The sheet is an `AppBottomSheet` with the `ConfirmSheet` look (Decision 14), not `showConfirmSheet`. The card follows the mock's `warnc` block: `AppIcons.info`, bold title, body, then `AppButton.text` in `AppColors.error`; above it a `SectionHeader` "Bàn giao ảnh" with the trailing "Quá hạn" in `AppColors.error`.
- [ ] **Step 5:** tests pass; `flutter analyze` clean; `dart run tool/affected_test.dart origin/develop --run` green.
- [ ] **Step 6: Commit** `feat(booking): S05.02 late delivery card and S05.08 cancel sheet [#207]`.

### Task 6: Ledger, spec status, cross-issue notes

**Files:**
- Create: `docs/superpowers/handover/ledger-s05-late-delivery-cancel.md`.
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (S05.08 "Làm bởi" cell → the PR; S05.02 cell adds "huỷ phần bàn giao: PR"), `docs/superpowers/specs/2026-10-06-delivery-preview-unlock-design.md` ("Quyết định của chủ dự án 2026-10-18" block: status "đã làm (#207)"), `docs/superpowers/specs/screens/booking.md` (S05.02 `shot` row and S05.08 section: "Chưa có" → PR link).

- [ ] **Step 1: Ledger** (English prose, Vietnamese copy verbatim): Step 1 findings of Tasks 1–5 (real line numbers, the `refund_account_needed` trigger site, the milestone read-model writer, the earnings label), Decisions 1–19 as taken, copy that differs from the mock, skipped suites (rules tests: none changed; Functions integration test written, not run), deploy order (Functions callable before the app; no rules or indexes), the seed booking for QA (`Lan` opens `/b/{seedLateBookingId}` on the emulator and sees the card).
- [ ] **Step 2: Cross-issue notes.** Comment on #165 (`gh issue comment 165 -R thanhngochoang/booking`): "S23.01 flag 'Giao trễ hạn': `isDeliveryLate(booking, now)` / `deliveryDueAt(booking)` in `@photobooking/domain` (`delivery_deadline.ts`); query `bookings` where `status == 'shot'` and `shotAt <= now − deliveryDays` is not expressible in one Firestore query, so read `status == 'shot'` ordered by `shotAt` and filter with the predicate." Comment on #142 (S18): "Dispute after `completed` is refused for milestone bookings (owner 2026-10-18, #207); S18 screens should not offer it there."
- [ ] **Step 3: Spec status.** Fill the cells; `git diff --stat` shows only docs in this task.
- [ ] **Step 4: Commit** `docs(delivery): ledger and screen status for the late delivery cancel [#207]`.

## Deferred

- A "Sắp trễ hạn" reminder to the provider before `dueAt` and a "Đã trễ hạn" nudge after it (S17, `delivery_due_soon`; Needs the owner 3).
- Partial deliveries ("đã giao một phần"): the spec has only all-or-nothing rounds.
- Per-booking `deliveryDays` negotiated in chat or in a quote beyond the package value (#139 passes the quote's value through the same snapshot field).
- Staff override of the deadline or a manual late cancel from S23 (Phase 1.5, #165); a staff CLI for it.
- Opening S22.04 (tài khoản nhận hoàn) from S05.08 when the refund is `awaiting_account`: waits for #141's screen (Decision 5).
- Self-hosted parity: `services/api` route and PostgreSQL migration for `delivery_days`, `delivery_cancelled_at` (data-model docs updated in Task 1; code is Phase 2, #90).
- Real payment intermediary and real refunds (fake rails only, owner ruling 2026-10-07).
