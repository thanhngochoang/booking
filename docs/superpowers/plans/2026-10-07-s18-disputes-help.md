# S18 · Khiếu nại & hỗ trợ (S18.01–S18.03) Implementation Plan

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules`, `storage.rules` and `firestore.indexes.json` and adds Functions. Write the rules tests and the Functions integration test; do not run them, CI runs them. Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Split (owner, 2026-10-08):** this plan holds two issues. **#204 (S18 · Trợ giúp & chat hỗ trợ, Tasks 1–6)**: the static FAQ, the help inbox chat with support and the support-thread base (domain, callable, rules, trigger, staff CLI, `SupportThreadView`). **#142 (S18 · Khiếu nại, Tasks 7–13)**: disputes on top of that base. Contract items are tagged where only one issue builds them.

**Goal:** A customer whose booking or paid event ticket went wrong opens a dispute inside the dispute window (reason, description, up to 5 evidence photos); the money of that booking or ticket stops moving towards the provider at once; customer, provider and support talk in one thread on the dispute screen; staff decide (release / refund / split) through a callable or the staff CLI and the money follows on the fake rails; everyone can read a static FAQ and chat with a support inbox.

**Architecture:** Business rules live in `packages/domain` (new `dispute*.ts` and `support*.ts` modules with ports and an in-memory store, like albums and awards). A dispute is `disputes/{id}` plus one support thread `support_threads/dispute_{id}` (+ `messages/`); the help chat is `support_threads/help_{uid}`. Clients only read; every write goes through the callables `openDispute` (re-pointed to the new use case), `resolveDispute` (staff `admin`), `sendSupportMessage`, or the staff CLIs `npm run disputes` / `npm run support` (Admin SDK, same use cases). Opening freezes the subject's escrow payment (`escrowStatus: disputed`), which the existing `bookingClock` step 5 and the payout CLI already skip; resolving restores it and applies a refund (fake gateway) and/or the existing release. Two triggers (`onDisputeWrite`, `onSupportMessageCreated`) send notifications through the existing `notify` use case. The app gets `lib/data/disputes/` and `lib/data/support/` (Firestore adapters, fakes in `test/support/`), feature folders `features/disputes/` (S18.01 sheet, S18.02) and `features/help/` (S18.03, support chat), and entry points on S05.02, S11.04, S09.02 and notifications. Evidence photos live in Storage `disputeEvidence/{uid}/{disputeId}/{file}`, readable by the parties only.

**Tech Stack:** TypeScript (domain, Functions v2 callables + `onDocumentWritten`/`onDocumentCreated`, `node --test`), Firestore/Storage rules and indexes; Flutter, Riverpod 3, go_router, existing core widgets (`ChatBubble`, `ChatComposer`, `ReasonPicker`, `StatusTimeline`, `EscrowNotice`, `AsyncView`, `EmptyState`, `showAppSheet`, `showConfirmSheet`).

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (S18 rows), §3g (escrow), §3i.1 (S18), §3i.6 (S23 audit rule), §8 questions 3, 16, 18, 22; `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` §4 (milestones, "Khiếu nại → mốc liên quan `disputed`, chi trả `on_hold`"), §5 (refunds); `docs/superpowers/specs/2026-10-06-delivery-preview-unlock-design.md` §4–§5 ("Báo vấn đề với ảnh gốc" → S18.01 with preset reasons); `docs/legal/terms-and-help-notes.md` (FAQ source); `docs/superpowers/specs/data-model/README.md` (`open_dispute`, `resolve_dispute`), `domain-model.md` §5 escrow state machine; mock `docs/design/ui-mock.html` `#S05.06-approved` (entry), frames added by Task 1.

**Issues and dependencies** (execution wave 4, cross-plan review 2026-10-07; split 2026-10-08). Merged inputs used by both: #147 (S10, in #159: `ImagePurpose.document`, `jpegUpTo`), #129 (S04, in #154: refund dispatch rule, `escrowRefundedTotal` (the old S04 plan's `policyRefundTotal`); see `2026-10-08-s04-reconciliation.md`), #138 (S17, in #155: the four dispute/support hooks and their visuals), #148 (S09, in #188: `settingsGroupOrder` with the `support` slot).
- **#204** (S18 · Trợ giúp & chat hỗ trợ): Tasks 1–6. **Blocked by: nothing.** `lib/core/app_config.dart` is create-if-absent (absent on develop 4e25834; #135 creates the same file, whichever lands first). Branch `plan/204-s18-help`, PR into `develop` titled `feat(help): S18.03 help, FAQ and support chat [#204]`.
- **#142** (S18 · Khiếu nại): Tasks 7–13. **Blocked by: #152, #204** (#204: the support-thread base below, owner 2026-10-08; #152: delivery plan, split from #130: milestones, `disputeMilestone`, `releaseMilestone`, the `shot`/`approved` windows; hard). #135 is no longer a blocker (`app_config.dart` comes from #204 or #135, create-if-absent). **Also runs on #204's support-thread base** (`support_thread.ts`, `sendSupportMessage`, the `support_threads` rules, `SupportThreadView`, the S18.03 slot): #204 is unblocked and lands first in practice; if it has not merged when #142 is claimed, stop and report rather than duplicating it (flagged 2026-10-08: the board should carry #204 as a "Blocked by" of #142). Branch `plan/142-s18-disputes`, PR into `develop` titled `feat(disputes): S18 disputes and dispute detail [#142]`.

## Contract with existing code

Checked 2026-10-07 on `develop` 812afd6; refund names re-checked 2026-10-08 on develop 87d8187 (after #129): `Refund.fromEscrow`, `escrowRefundedTotal`, `dispatchRefunds` (gateway throw or `success: false` → `failed` + `manual`, #129 Ruling 7), private `dispatchTicketRefund` (same rule), no `pending` re-send for bookings, no `awaiting_account`, no `Refund.method`/`destination`. The first step of every task re-checks the names it uses; adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- Domain (`packages/domain/src`): `openDispute(deps: BookingDeps, {bookingId, customerId, reason})` in `open_dispute.ts` (allows `upcoming`, 24 h after `completedAt`, freezes the first `held|partially_refunded` payment) — **replaced** by this plan; `MIN/MAX_DISPUTE_REASON_LENGTH` (`booking_policy.ts`, only used there); `DISPUTE_WINDOW_HOURS = 24`; `Payment.dispute?: {reason, openedAt}`; `disputeEscrowPayment`, `applyRefundToPayment({payment, refundId, percent, ledgerEntryId, reason, now})` (percent of `payment.amount`), `releaseEscrowPayment({payment, refundAmount, ledgerEntryId, now})`, `verifyPaymentLedgerInvariant` (`escrow.ts`); `dispatchRefund(deps: BookingDeps, refund, provider)` (`refunds.ts`); `runBookingSweeps` step 5 releases only `held|partially_refunded` with `releaseAfter <= now` (`booking_sweeps.ts`); `PaymentGateway.issueRefund` (`refundId` is the idempotency key), `FakePaymentGateway`; `notify(deps: NotifyDeps, req: NotifyRequest)`, `NOTIFICATION_TYPES`, `renderNotification`, `NotificationContent` (`notification*.ts`); `graphemeCount` (`booking_requests.ts`); `isId`, `DomainError`, `ERROR_CODES` (no new code is added); `PLATFORM_PAYEE`; `Booking` (`booking.ts`, has `completedAt`, `escrowStatus`, no `disputeId`); registrations: `RegistrationRecord` (`event_ports.ts`), `endAt` on the event, ticket payment `subjectType 'event_registration'`, `eventId` on the payment, `releaseAfter = endAt + 24 h` set at completion (`event_payments.ts:416`). Memory stores refuse a read after a write inside a transaction (`memory_album_store.ts` pattern).
- Functions (`app_flutter/firebase/functions/src`): `handleOpenDispute` in `callables/booking.ts:120` and the `openDispute` export in `index.ts:122` (no app code calls it: `BookingRepository.openDispute` is unused); `CALLABLE_OPTIONS`, `PAYMENT_CALLABLE_OPTIONS`, `TRIGGER_OPTIONS` (`config.ts`); `toHttpsError` (`callables/errors.ts`); staff claim read as `request.auth?.token?.staffRole` (`callables/award.ts`); `liveNotifyDeps()` (`infra/live_notification.ts`); `bookingFromFirestore` / the booking writer and the payment mapping with `dispute` (`infra/booking_firestore.ts:175,200`); registration mapping in `infra/event_firestore.ts`; `getSharedFakeGateway()` (`infra/live_booking.ts`); staff CLI pattern `tools/awards.ts` (`parseArgs`, `HELP`, `--actor` with `staffRole == 'admin'`) and its test `test/unit/award_cli.test.ts`; seed `seed/fixtures.ts` (`seed-booking-disputed`: payment `disputed`, no dispute document), `seed/README.md`.
- Rules: no `disputes`, no `support_threads`; catch-all deny. Storage: no `disputeEvidence`; `awardProofs` is the private-upload precedent (create-only, `resource == null`, raster types). Indexes: none on these collections.
- App data: `Booking` (`lib/data/booking/booking.dart`: `completedAt`, `escrowStatus`, `deposit`, no `disputeId`), `BookingRepository.openDispute` + `FirestoreBookingRepository.openDispute` (unused; removed), `BookingRules.canCustomerDispute` + `disputeWindowHours` (`booking_rules.dart:9,137`; allows `upcoming`; replaced), `EventRegistration` (`lib/data/events/event_registration.dart`: `amount`, `status`, `paymentId`, `event.endsAt`), `firestore_event_mapping.dart`; media: `MediaUploader.upload(image, storagePath:)`, `MediaUrlResolver.downloadUrl(path)`, `mediaUploaderProvider`, `mediaUrlResolverProvider`, `imagePickerProvider`, `PickedImage`; `newUlid()` (`lib/core/ulid.dart`); `authStateProvider`, `currentProfileProvider`, `staffRoleProvider`.
- App features: `BookingDetailScreen` + `bookingDetailRoutes()` + `DetailSheet {cancel, decline}` + `_maybeOpenSheet` (`features/booking/booking_detail_screen.dart`), `detailActions` + `DetailAction` (`booking_view_rules.dart`), the red text-button style of the cancel action (`AppColors.destructive` / `AppColorsDark.destructive`), `bookingCode(id)`; S11.04 `TicketCard` (`lib/core/widgets/ticket_card.dart`; `compact`, `onCancel`, `cancelLabel`) built in `features/events/tickets_tab.dart:297`; `SettingsScreen` sections (`features/settings/settings_screen.dart`); `notificationVisualOf` (`features/notifications/notification_visuals.dart`); `eventSupportEmail` / `eventSupportUri` (`features/events/event_links.dart`, used by `event_info_tab.dart:118`, tested in `test/features/events/event_links_test.dart`); `lib/app/router.dart`.
- Core: `ScreenCodes.openDispute` (S18.01), `disputeDetail` (S18.02), `help` (S18.03) already exist (`lib/core/screen_codes.dart:102-104`); `AppIcons.flag`, `AppIcons.lock`, `AppIcons.info`, `AppIcons.schedule`, `AppIcons.addPhoto`, `AppIcons.chat`, `AppIcons.supportAgent` exist; `help` does not (checked 2026-10-08 on develop 4e25834); `lib/core/app_config.dart` does not exist yet; `settingsGroupOrder` (`features/settings/settings_screen.dart`, #148) has the slot `support`.

## Global Constraints

- Spec §3i.1, verbatim: "S05.02 / S11.04 hiện "Báo vấn đề" khi booking `completed` hoặc vé đã dùng và còn trong `dispute_window_hours` → S18.01 → `openDispute` (khoản tiền `held → disputed`, khoản chi trả `on_hold`) → S18.02 theo dõi; nhiếp ảnh gia nhận thông báo, xem S18.02 và gửi giải trình; staff xử lý ở S23.01 (`resolveDispute`: thả / hoàn / chia), hai bên nhận thông báo và tiền đi theo kết quả." "một khiếu nại mở cho mỗi booking hoặc vé; quá cửa sổ thì nút ẩn và S18.03 giải thích; ảnh bằng chứng lưu riêng tư (chỉ hai bên và staff đọc); không có kênh liên hệ ngoài app mới nào được mở vì khiếu nại."
- Spec §3i.6: "mọi quyết định của staff ghi nhật ký kiểm toán (ai, lúc nào, lý do); tiền chỉ di chuyển qua callable phía server, không sửa tay dữ liệu."
- Money (CLAUDE.md, owner ruling 2): money moves only on the fake rails (`FakePaymentGateway`, payout CLI); no real intermediary. Refunds come only from money still held (Invariant 12).
- Delivery spec §5: "nút chữ đỏ "Báo vấn đề với ảnh gốc" (→ S18.01 với lý do điền sẵn: thiếu ảnh, khác ảnh mẫu, link hỏng)".
- Support email: build config `SUPPORT_EMAIL` only (`--dart-define=SUPPORT_EMAIL=…`); unset hides every email line. Never write an invented address.
- CLAUDE.md: business rules in `packages/domain` (no Firebase/Node imports, `purity.test.ts`); Functions thin, region `asia-southeast1`; Firebase only in `lib/data/**` adapters, `firebase_options.dart`, `main.dart`; strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons` only; `package:photobooking/...` imports, features import `core/core.dart`; one `AppButton.primary` per screen; every screen/sheet wrapped in `ScreenCode`; `AsyncView` for every `AsyncValue`.
- Ids/time/money (`data-model/README.md`): ULID/opaque ids (the client mints the dispute id with `newUlid()`), UTC instants (`Timestamp` in Firestore, ISO strings in the domain), integer VND, string enum codes.
- Commits: Conventional Commits, subject ends with `[#204]` (Tasks 1–6) or `[#142]` (Tasks 7–13), footer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>` (never the Claude line).
- Env for Flutter commands (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.
- Tests: `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time (never the whole suite in one command); bounded pumps (`pump(Duration)`, no `pumpAndSettle` on screens with loaders/countdowns); domain `cd packages/domain && npm test && npm run lint`; functions `cd app_flutter/firebase/functions && npm test && npm run build`; rules-test and Functions integration suites are written, not run (CI runs them).

## Decisions (where the spec is silent)

1. **What a dispute freezes: the milestone of its window (cross-plan review finding 19).** #152 (delivery plan, split from #130) (merged before this one) splits booking payments into the `shoot` and `delivery` milestones and owns `disputeMilestone(p, kind, now)`, `releaseMilestone`, `payableAmountOf`. A booking dispute freezes only the milestone of its window (Decision 2) with #130's `disputeMilestone`, stores `dispute: {reason, openedAt, disputeId, milestone, prevStatus}` and leaves the other milestone alone (a shoot milestone already released or paid out is not touched). A payment without `milestones` (tickets, bookings from before #130) keeps the whole-payment freeze: `escrowStatus: disputed` with `prevEscrowStatus`. `bookingClock`'s release step and #134's daily payouts already skip a disputed milestone / payment; the earnings trigger shows "Đang khiếu nại".
2. **Who opens, when.** The paying customer only (`openedBy: 'customer'`; provider-opened disputes from delivery "hết lượt sửa" are #130's, through the same use case with `openedBy: 'provider'`). Booking (#130's windows are the primary rule): status `shot` and `now < shotAt + 24 h` → the `shoot` milestone; status `approved` and `now < checkUntil` → the `delivery` milestone (this is "Báo vấn đề với ảnh gốc"); a booking whose payment has no `milestones` (before #130): `completed|reviewed` and `now < completedAt + DISPUTE_WINDOW_HOURS`. `completed` with milestones has nothing held (milestone 2 was released when it became `completed`) → `not_eligible`. The old `upcoming` allowance is dropped: before the shoot the customer cancels (S05.03). Ticket: registration `paid`, `amount > 0`, `endAt <= now < endAt + 24 h`; check-in is **not** required (spec says "vé đã dùng", but "the event did not happen" is the main ticket complaint and leaves the ticket unused). Free tickets hold no money: no dispute; S18.03 says so.
3. **Errors.** Wrong state, free ticket, no held payment → `not_eligible`; window over → `deadline_passed`; a dispute already open on the subject → `conflict`; caller not the payer → `permission_denied`; malformed → `invalid_argument`. No new error code.
4. **Idempotent open.** The client mints the dispute id (`newUlid()`) before uploading evidence (the Storage path needs it) and sends it; a second `openDispute` with the same id by the same customer returns the existing dispute unchanged.
5. **Reasons** (string codes, fixed): booking `no_show`, `not_as_agreed`, `photos_missing`, `not_as_sample`, `link_broken`, `other`; ticket `event_not_held`, `not_as_described`, `other`. Origin `delivery_check` (S05.06, #130) offers `photos_missing`, `not_as_sample`, `link_broken`, `other`. Description is required, 10–1000 graphemes after trim (staff need facts; replaces the old 1–500 reason text). Evidence: 0–5 images.
6. **Evidence storage.** `disputeEvidence/{uid}/{disputeId}/{fileId}.jpg`, fileId a fresh ULID per upload (Storage refuses overwrites, award-proof precedent). Firestore stores paths only, never download URLs (a token URL bypasses rules); viewers resolve URLs with `MediaUrlResolver.downloadUrl`, which the Storage rule checks against `disputes/{id}.parties`. The owner may delete an upload only while no dispute document with that id exists (the sheet cleans up after itself). Kept after resolution; purge with account deletion (S22.02) or a later job (Deferred). **Uploads use the shared image API of #147** (`docs/superpowers/plans/2026-10-07-s10-post-upload.md`): `MediaUploader.upload(image, storagePath:, purpose: ImagePurpose.document)` (2048 px, q85, EXIF removed, JPEG only) and the Storage rule helper `jpegUpTo(3 * 1024 * 1024)`; no PNG/WebP/HEIC on this path. #147 is merged (#159); Task 8 uses its rule helper and Task 11 its uploader `purpose:`.
7. **Outcome money on #129's refund rule and #130's milestones (cross-plan review findings 18, 19).** `release` (refund 0%), `refund` (100%), `split` (integer 1–99%). The percent applies to the amount **held by the dispute**: the frozen milestone's `amount` (Decision 1), or for a payment without milestones `payment.amount − escrowRefundedTotal(refunds)` (#129: refunds with `fromEscrow: false` never count). `refundAmount = floor(held × pct / 100)`, `releaseAmount = held − refundAmount`. In one transaction: the milestone (or payment) back to its previous status, then #129's `applyRefundToPayment` with an explicit `amount` (refund `fromEscrow: true`; `method`/`destination` come with V2 (#201, `2026-10-08-v2-refund-destination.md`)), then #130's `releaseMilestone` (or `releaseEscrowPayment` for a payment without milestones) for `releaseAmount > 0` (payee: provider, or `platform` which keeps it). After the commit the refund goes through `dispatchDisputeRefund`, which follows #129's rule as built (`dispatchRefunds` in `refunds.ts`, `dispatchTicketRefund` in `event_payments.ts`): one `gateway.issueRefund({paymentId, refundId, amount, provider, providerRef})` keyed by the refund id; `success` → `done`; `success: false` or a throw → `failed` + `manual` (S23.03, #129 Ruling 7); the outcome is written only while the stored refund is still `pending`. When V2 (#201, `2026-10-08-v2-refund-destination.md`; soft for #142) lands, `dispatchDisputeRefund` switches to `sendRefundOnce` + `mergeRefundOutcome` (a throw then stays `pending` and V2 re-sends it under the same id) and skips an `awaiting_account` refund (#141) until the customer chooses. No own resend. (Checked 2026-10-08: the index `refunds (subjectType, status, createdAt)` still exists; it serves the ticket refund re-send.)
8. **Thread (#142, on #204's thread base).** One thread per dispute, three-party: customer, provider (absent for platform-hosted events) and support. The provider's messages are the "giải trình" of §3i.1. Parties read everything in it; messages are server-written (`sendSupportMessage`); sending closes when the dispute is resolved (`not_eligible`). Opening writes a system message and the customer's description as the first message.
9. **Help chat (#204).** `support_threads/help_{uid}`, created by the first `sendSupportMessage` without a thread id. Staff answer with `npm run support -- reply` until the S23.06 dashboard (phase 1.5, #83). Text only; 1–1000 graphemes; at most 10 messages per sender per thread per rolling 10 minutes (`limit_exceeded`).
10. **Staff side, phase 1.** Callable `resolveDispute` (ID token `staffRole == 'admin'`) and CLI `npm run disputes -- list | show <id> | resolve <id> release|refund|split [percent] "<note>" --actor <uid>`; both call `resolveDispute` in the domain. Audit trail = `outcome.decidedBy/decidedAt/note` on the dispute, the ledger entries (`refund_issued`, `escrow_released`) and the thread system message. No "reviewing" sub-state (staff just reply in the thread).
11. **Notifications through #138's hooks.** #138 owns the four types (`dispute_opened` → provider, critical; `dispute_resolved` → parties, critical; `support_reply` → participants when staff write, critical; `dispute_message` → the other party, grouped per dispute, not critical; category `booking`, tab `activity`), their copy (this plan's text, moved to #138's catalogue by the cross-plan review), dedupe keys and targets (`/disputes/{id}`, `/help/chat`, allowlisted by #138 unconditionally; cross-plan review finding 29). This plan is their only emitter: `notifyDisputeChange` and `notifySupportMessage` become deciders that call #138's `notifyDisputeOpened`, `notifyDisputeResolved`, `notifyDisputeMessage`, `notifySupportReply` (signatures in Contract).
12. **Mirrors.** `bookings/{id}.disputeId` (+ the existing `escrowStatus` mirror) and `events/{e}/registrations/{r}.disputeId`, written by the dispute transaction. Both Firestore mappings must round-trip `disputeId`, or the next booking transition would erase it (Review Focus 5): the booking field goes into the shared `round-trips Booking through Firestore conversion` test (cross-plan review finding 41).
13. **Entry points.** S05.02 customer, window open: red text button "Báo vấn đề · còn {h} giờ" under the actions (mock `S05.02-problem`); S05.02 any party, `disputeId` set: a banner "Đang khiếu nại" / "Khiếu nại đã có kết quả" → S18.02 (mock `S05.02-disputed`); S11.04 compact past ticket in its window: text button "Báo vấn đề"; S18.03 "Khiếu nại của bạn" (#142, in #204's slot); notification deep links; S09.02 group "Hỗ trợ" → "Trợ giúp" (#204) (group 7 of #148's canonical order, Decision 12 there: after "Thanh toán và dữ liệu", before Debug and "Đăng xuất"). Routes: `/b/:id/dispute` (sheet over S05.02; `?from=delivery` presets the delivery reasons for #130), `/disputes/:id`, `/help`, `/help/chat`. The ticket sheet has no route (opened from S11.04). §2 route cells are updated.
14. **Support email** is `lib/core/app_config.dart` (`supportEmail`, `supportEmailUri()`; cross-plan review finding 3), create-if-absent: #204 (Task 4) or #135 (S21 Task 5), whichever lands first, creates it with exactly this shape and moves `event_links.dart`'s pair; the other consumes it unchanged. S18.03 shows "Email hỗ trợ: {email}" under the button only when set.
15. **FAQ** (#204) is static, in `app_vi.arb`, written from `docs/legal/terms-and-help-notes.md` (P1–P10, P12, C1, R1, V1–V2, spec §3i.1) in 7 topics (Task 5 has every string). It states the product rules (100%, two milestones, delivery check) that #129/#130 implement; if this ships first, the ledger notes the temporary mismatch with the app's "cọc" copy. "Chụp ngay" FAQ waits for S13.
16. **Display code.** `#K7Q2` = last 4 characters of the dispute id upper-cased (`disputeCode(id)`, like `bookingCode`).
17. **Seed.** A `disputes/seed-dispute-lan-an` document for the existing `seed-booking-disputed` (open, thread with a staff and a provider message), a completed booking `seed-booking-completed-window` (completed 2 hours before seeding, payment held) to try S18.01, and a past paid ticket for Lan inside its window (`seed-event-an-past-workshop`, ended 3 hours before seeding, `seed-registration-lan-past-paid`, payment held).

## Needs the owner

1. **Three-party thread** (Decision 8): the customer reads the provider's explanation and vice versa. Default: yes. The alternative (two private threads with support) doubles the screens.
2. **Withdrawing a dispute** ("Rút khiếu nại", money back to `held`): default not in this unit (Deferred); staff can resolve with `release`.
3. **Evidence retention**: default kept until account deletion (S22.02); a purge job (e.g. 90 days after resolution, like `purgeAwardProofs`) comes later.

## Contract

### Data (Firestore)

- `disputes/{id}` (server-written only): `id`, `subjectType: 'booking'|'ticket'`, `subjectId` (bookingId | registrationId), `eventId: string|null`, `paymentId`, `customerId`, `providerId` (photographer uid or `'platform'`), `parties: string[]` (customerId, + providerId unless `'platform'`), `openedBy: 'customer'`, `reason` (code), `description`, `evidencePaths: string[]` (≤ 5), `snapshot: {title, subtitle, providerName|null, thumbUrl|null}` (display copy taken at open: booking → `"{photographer} · {service}"`, `"T7 12/10 · 15:30–17:30"`; ticket → event title, `"CN 20/10 · 06:00–09:00"`), `amountHeld` (int VND at open), `status: 'open'|'resolved'`, `outcome: null | {kind: 'release'|'refund'|'split', refundPercent, refundAmount, releaseAmount, note, decidedBy, decidedAt, refundId|null}`, `threadId` (`dispute_{id}`), `createdAt`, `updatedAt`, `resolvedAt|null`, `version`.
- `payments/{id}.dispute`: `{reason, openedAt, disputeId, milestone: 'shoot'|'delivery'|null, prevStatus}` (`prevStatus` = the milestone's previous status, or the payment's `prevEscrowStatus` without milestones; server-only as today). The frozen milestone itself is #130's `status: 'disputed'`.
- `bookings/{id}.disputeId: string|null`; `events/{e}/registrations/{r}.disputeId: string|null` (server-only).
- `support_threads/{threadId}` (server-written only): `id`, `kind: 'help'|'dispute'`, `ownerId: string|null` (help: the user), `disputeId: string|null`, `participants: string[]`, `status: 'open'|'closed'`, `awaitingStaff: bool`, `lastMessageAt`, `lastMessagePreview` (≤ 80 graphemes), `lastSenderRole: 'customer'|'provider'|'user'|'staff'|'system'`, `rate: {[uid]: {windowStart, count}}`, `createdAt`, `updatedAt`.
- `support_threads/{threadId}/messages/{messageId}` (id = client ULID; system messages server ULID): `id`, `threadId`, `senderId: string|null` (null for system), `senderRole`, `senderName` ("Hỗ trợ" for staff), `body`, `createdAt`.
- Storage `disputeEvidence/{uid}/{disputeId}/{fileId}`.

### Domain (`packages/domain/src`)

```ts
// dispute.ts
export const DISPUTE_SUBJECT_TYPES = ['booking', 'ticket'] as const;
export type DisputeSubjectType = (typeof DISPUTE_SUBJECT_TYPES)[number];
export const DISPUTE_REASONS = ['no_show', 'not_as_agreed', 'photos_missing', 'not_as_sample', 'link_broken',
  'event_not_held', 'not_as_described', 'other'] as const;
export type DisputeReason = (typeof DISPUTE_REASONS)[number];
export const REASONS_BY_SUBJECT: Readonly<Record<DisputeSubjectType, readonly DisputeReason[]>>;
export const DISPUTE_STATUSES = ['open', 'resolved'] as const;
export type DisputeStatus = (typeof DISPUTE_STATUSES)[number];
export const DISPUTE_OUTCOMES = ['release', 'refund', 'split'] as const;
export type DisputeOutcomeKind = (typeof DISPUTE_OUTCOMES)[number];
export const MAX_DISPUTE_EVIDENCE = 5;
export const DISPUTE_DESCRIPTION_MIN = 10;
export const DISPUTE_DESCRIPTION_MAX = 1000;
export const DISPUTE_NOTE_MIN = 5;
export const DISPUTE_NOTE_MAX = 500;
export interface DisputeSnapshot { readonly title: string; readonly subtitle: string; readonly providerName: string | null; readonly thumbUrl: string | null }
export interface DisputeOutcome { readonly kind: DisputeOutcomeKind; readonly refundPercent: number; readonly refundAmount: number;
  readonly releaseAmount: number; readonly note: string; readonly decidedBy: string; readonly decidedAt: string; readonly refundId: string | null }
export interface Dispute { readonly id: string; readonly subjectType: DisputeSubjectType; readonly subjectId: string;
  readonly eventId: string | null; readonly paymentId: string; readonly customerId: string; readonly providerId: string;
  readonly parties: readonly string[]; readonly openedBy: 'customer'; readonly reason: DisputeReason; readonly description: string;
  readonly evidencePaths: readonly string[]; readonly snapshot: DisputeSnapshot; readonly amountHeld: number;
  readonly status: DisputeStatus; readonly outcome: DisputeOutcome | null; readonly threadId: string;
  readonly createdAt: string; readonly updatedAt: string; readonly resolvedAt: string | null; readonly version: number }
export interface OpenDisputeInput { readonly disputeId: string; readonly subjectType: DisputeSubjectType; readonly subjectId: string;
  readonly eventId: string | null; readonly reason: DisputeReason; readonly description: string; readonly evidencePaths: readonly string[] }
/** Throws invalid_argument. Evidence paths must be `disputeEvidence/{uid}/{disputeId}/{fileId}` with fileId `[A-Za-z0-9_-]{1,64}\.jpg` (JPEG only, #147). */
export function parseOpenDisputeInput(raw: unknown, uid: string): OpenDisputeInput;
/** The window of a subject (Decision 2): shot → shotAt + 24 h (shoot), approved → checkUntil (delivery), no milestones → completedAt + 24 h, ticket → endAt + 24 h.
 *  Throws not_eligible (state / nothing held) or deadline_passed (closed). */
export function disputeWindow(subject: DisputeSubjectView, now: Date): { readonly closesAt: Date; readonly milestone: 'shoot' | 'delivery' | null };
/** Throws invalid_argument (split outside 1–99, percent given for release/refund). */
export function outcomeAmounts(heldAmount: number, kind: DisputeOutcomeKind, refundPercent?: number):
  { readonly refundPercent: number; readonly refundAmount: number; readonly releaseAmount: number };
export const disputeThreadId = (disputeId: string): string => `dispute_${disputeId}`;
export const helpThreadId = (uid: string): string => `help_${uid}`;

// dispute_ports.ts
export interface DisputeSubjectView {
  readonly type: DisputeSubjectType; readonly id: string; readonly eventId: string | null;
  readonly customerId: string; readonly providerId: string;   // 'platform' for platform-hosted events
  readonly state: string;                                      // booking status | registration status
  readonly windowStart: Date | null;                           // legacy booking completedAt | event endAt
  readonly shotAt: Date | null; readonly checkUntil: Date | null; // #130 fields (bookings)
  readonly amount: number;                                     // 0 for a free ticket
  readonly paymentId: string | null;                           // registration.paymentId; null for bookings (looked up)
  readonly disputeId: string | null;
  readonly snapshot: DisputeSnapshot;
}
export interface DisputeTx {
  getSubject(type: DisputeSubjectType, id: string, eventId: string | null): Promise<DisputeSubjectView | null>;
  getDispute(id: string): Promise<Dispute | null>;
  /** Booking: the payment with subjectId = booking id (its milestone of the window must be `held`, or for a legacy payment the payment `held|partially_refunded`); ticket: `paymentId`. */
  findSubjectPayment(subject: DisputeSubjectView): Promise<Payment | null>;
  setDispute(d: Dispute): void;
  setPayment(p: Payment): void;
  /** Booking: `disputeId` + `escrowStatus` mirror; registration: `disputeId` only. */
  linkSubject(subject: DisputeSubjectView, patch: { readonly disputeId: string; readonly escrowStatus: EscrowStatus }): void;
  addRefund(r: Refund): void;
  addLedgerEntry(e: LedgerEntry): void;
  putThread(t: SupportThread): void;
  addMessage(m: SupportMessage): void;
}
export interface DisputeStore {
  runTransaction<T>(fn: (tx: DisputeTx) => Promise<T>): Promise<T>;
  getRefundsForPayment(paymentId: string): Promise<readonly Refund[]>;
  saveRefund(r: Refund): Promise<void>;
  listByStatus(status: DisputeStatus, limit: number): Promise<readonly Dispute[]>;
}
// DisplayNames { displayName(uid: string): Promise<string> } ('' when unknown) lives in support_use_cases.ts (#204) and is imported here
export interface DisputeDeps { readonly store: DisputeStore; readonly gateway: PaymentGateway /* #129's port */; readonly cipher: AccountCipher; readonly names: DisplayNames;
  readonly clock: Clock; readonly ids: IdGenerator }

// dispute_use_cases.ts
export async function openDispute(deps: DisputeDeps, callerId: string, raw: unknown): Promise<Dispute>;
/** Input `{disputeId, outcome, refundPercent?, note}`; the adapter has already checked the staff role. */
export async function resolveDispute(deps: DisputeDeps, staffId: string, raw: unknown): Promise<{ dispute: Dispute; refund: Refund | null }>;
/** After commit, #129's rule as built: one gateway.issueRefund keyed by refund.id, then a store transaction that writes
 *  done, or failed + manual on success: false or a throw, only while the stored refund is pending (Decision 7).
 *  With V2: sendRefundOnce + mergeRefundOutcome (throw → pending, re-sent by V2; awaiting_account → not sent). */
export async function dispatchDisputeRefund(deps: DisputeDeps, payment: Payment, refund: Refund): Promise<Refund>;
// consumed from #129 (on develop 87d8187): escrowRefundedTotal(refunds): number; applyRefundToPayment(...); PaymentGateway.issueRefund(...)
// from V2 (#201, 2026-10-08-v2-refund-destination.md; soft) once it lands: sendRefundOnce(d: {gateway, cipher, clock}, refund, payment: Pick<Payment, 'id' | 'provider'>): Promise<Refund>;
//   mergeRefundOutcome(stored: Refund, next: Refund): Refund | null
// consumed from #130: disputeMilestone(p: Payment, kind: MilestoneKind, now: Date): Payment; releaseMilestone(p, kind, ledgerEntryId, now): {payment, ledgerEntry}

// escrow.ts (modified)
// Payment.dispute?: { reason; openedAt; disputeId?: string; prevEscrowStatus?: 'held' | 'partially_refunded' } | null
// applyRefundToPayment gains `amount?: number` (when given: used instead of percent math; must be 1..held; full when Σ refunds == payment.amount)

// support_thread.ts (#204)
export type SupportThreadKind = 'help' | 'dispute';
export type SupportSenderRole = 'customer' | 'provider' | 'user' | 'staff' | 'system';
export interface SupportThread { readonly id: string; readonly kind: SupportThreadKind; readonly ownerId: string | null;
  readonly disputeId: string | null; readonly participants: readonly string[]; readonly status: 'open' | 'closed';
  readonly awaitingStaff: boolean; readonly lastMessageAt: string | null; readonly lastMessagePreview: string | null;
  readonly lastSenderRole: SupportSenderRole | null; readonly rate: Readonly<Record<string, { windowStart: string; count: number }>>;
  readonly createdAt: string; readonly updatedAt: string }
export interface SupportMessage { readonly id: string; readonly threadId: string; readonly senderId: string | null;
  readonly senderRole: SupportSenderRole; readonly senderName: string; readonly body: string; readonly createdAt: string }
export const SUPPORT_TEXT_MAX = 1000;
export const SUPPORT_RATE_LIMIT = 10;          // messages
export const SUPPORT_RATE_WINDOW_MINUTES = 10;

// support_use_cases.ts (#204; #142 adds getDispute and the kind 'dispute' branch)
export interface SupportTx { getThread(id: string): Promise<SupportThread | null>; getMessage(threadId: string, id: string): Promise<SupportMessage | null>;
  getDispute(id: string): Promise<Dispute | null> /* #142 */; putThread(t: SupportThread): void; addMessage(m: SupportMessage): void }
export interface SupportStore { runTransaction<T>(fn: (tx: SupportTx) => Promise<T>): Promise<T>;
  listAwaitingStaff(limit: number): Promise<readonly SupportThread[]>; listMessages(threadId: string, limit: number): Promise<readonly SupportMessage[]> }
export interface SupportDeps { readonly store: SupportStore; readonly names: DisplayNames; readonly clock: Clock; readonly ids: IdGenerator }
/** `{threadId?: string|null, clientId, text}`; null/absent → the caller's help thread (created on first message). */
export async function sendSupportMessage(deps: SupportDeps, senderId: string, raw: unknown): Promise<{ threadId: string; messageId: string }>;
export async function staffReply(deps: SupportDeps, staffId: string, raw: unknown): Promise<{ threadId: string; messageId: string }>;

// dispute_notifications.ts (#142) — deciders that call #138's hooks (no copy here; Decision 11)
export async function notifyDisputeChange(deps: NotifyDeps, before: Dispute | null, after: Dispute | null): Promise<void>;
// support_notifications.ts (#204: help threads → notifySupportReply; #142 adds dispute threads → notifyDisputeMessage / notifySupportReply)
export async function notifySupportMessage(deps: NotifyDeps, thread: SupportThread, message: SupportMessage): Promise<void>;
// consumed from #138 (packages/domain/src/notification_hooks.ts, merged in #155; types, copy, targets, dedupe are #138's):
export function notifyDisputeOpened(deps: NotifyDeps, e: { disputeId: string; providerId: string; customerId: string; subject: string; ticket: boolean }): Promise<NotifyResult | null>; // null for 'platform'
export function notifyDisputeResolved(deps: NotifyDeps, e: { disputeId: string; recipientIds: readonly string[]; subject: string; kind: 'release' | 'refund' | 'split'; providerName: string; refund: number; release: number }): Promise<NotifyResult[]>;
export function notifyDisputeMessage(deps: NotifyDeps, e: { disputeId: string; recipientIds: readonly string[]; senderId: string; preview: string }): Promise<NotifyResult[]>;
export function notifySupportReply(deps: NotifyDeps, e: { threadId: string; disputeId: string | null; messageId: string; recipientIds: readonly string[]; preview: string }): Promise<NotifyResult[]>;
// memory_support_store.ts (#204): MemorySupportStore implements SupportStore
// memory_dispute_store.ts (#142): MemoryDisputeStore extends MemorySupportStore implements DisputeStore (one world; seeded subjects, payments, refunds)
```

Notification copy (moved to #138's catalogue by the cross-plan review, unchanged; listed so this plan's tests can assert it): `dispute_opened` title `"{customer} báo vấn đề với buổi chụp"` (ticket: `"{customer} báo vấn đề với vé sự kiện"`), body `"{subject}. Tiền được giữ tới khi có kết quả. Gửi giải trình trong mục Khiếu nại."`; `dispute_resolved` title `"Khiếu nại đã có kết quả"`, body release `"{subject}: tiền được chuyển cho {provider}."`, refund `"{subject}: hoàn {refund} cho khách."`, split `"{subject}: hoàn {refund} cho khách, chuyển {release} cho {provider}."` (amounts with `formatVnd`; platform events: `{provider}` = "ứng dụng"); `dispute_message` title `"{sender} nhắn trong khiếu nại"`, body preview or `"{count} tin nhắn mới"`; `support_reply` title `"Hỗ trợ đã trả lời"`, body preview. Dedupe keys `dispute_opened:{id}`, `dispute_resolved:{id}`, `support_reply:{messageId}`; `dispute_message` grouped with `groupKey: dispute:{id}`, actor = sender.

### Callables and triggers (`asia-southeast1`)

| Name | Input | Output | Errors |
|---|---|---|---|
| `openDispute` (#142, `PAYMENT_CALLABLE_OPTIONS`) | `{disputeId, subjectType, subjectId, eventId?, reason, description, evidencePaths}` | `{disputeId}` | `invalid_argument`, `permission_denied`, `not_found`, `not_eligible`, `deadline_passed`, `conflict` |
| `resolveDispute` (#142, `PAYMENT_CALLABLE_OPTIONS`) | `{disputeId, outcome: 'release'\|'refund'\|'split', refundPercent?, note}` | `{disputeId, refundAmount, releaseAmount}` | `permission_denied` (token `staffRole != 'admin'`), `invalid_argument`, `not_found`, `conflict` (not open / payment not disputed) |
| `sendSupportMessage` (#204, `CALLABLE_OPTIONS`) | `{threadId?: string\|null, clientId, text}` | `{threadId, messageId}` | `invalid_argument`, `permission_denied`, `not_found`, `not_eligible` (dispute resolved), `limit_exceeded` |
| `onDisputeWrite` (#142, `disputes/{id}`, `TRIGGER_OPTIONS`) | before/after | — | `notifyDisputeChange` |
| `onSupportMessageCreated` (#204, `support_threads/{threadId}/messages/{messageId}`) | created message | — | `notifySupportMessage` (reads the thread) |

CLIs (`app_flutter/firebase/functions/tools/`): (#142) `npm run disputes -- list [open|resolved] | show <id> | resolve <id> release|refund "<note>" --actor <uid> | resolve <id> split <percent> "<note>" --actor <uid>`; (#204) `npm run support -- list | show <threadId> | reply <threadId> "<text>" --actor <uid>`. `--actor` must have the claim `staffRole: 'admin'` (disputes) or `admin|sales` (support), same environment rules as `npm run awards`.

### Rules, Storage, indexes

```
// firestore.rules
match /disputes/{id} {
  allow get, list: if signedIn() && request.auth.uid in resource.data.parties;
  allow write: if false;
}
match /support_threads/{threadId} {
  // A missing help thread must read as "none", not as a denial.
  allow get: if signedIn() && (threadId == 'help_' + request.auth.uid
                               || request.auth.uid in resource.data.participants);
  allow list: if signedIn() && request.auth.uid in resource.data.participants;
  allow write: if false;
  match /messages/{messageId} {
    allow read: if signedIn() && request.auth.uid in
      get(/databases/$(database)/documents/support_threads/$(threadId)).data.participants;
    allow write: if false;
  }
}
// storage.rules
match /disputeEvidence/{uid}/{disputeId}/{file} {
  // purpose: document (#147); JPEG only
  allow create: if isOwner(uid) && resource == null && jpegUpTo(3 * 1024 * 1024);
  allow read: if isOwner(uid) || (signedIn() && request.auth.uid in
    firestore.get(/databases/(default)/documents/disputes/$(disputeId)).data.parties);
  allow delete: if isOwner(uid)
    && !firestore.exists(/databases/(default)/documents/disputes/$(disputeId));
  allow update: if false;
}
```
Rules: the `disputes` block and Storage `disputeEvidence` are #142's; the `support_threads` block is #204's. Indexes: `disputes (parties CONTAINS, createdAt DESC)` (S18.03, #142), `disputes (status ASC, createdAt ASC)` (CLI, #142), `support_threads (awaitingStaff ASC, lastMessageAt ASC)` (CLI, #204).

### App (Dart)

```dart
// lib/core/app_config.dart (exported from core.dart; create-if-absent, #204 or #135)
const String? supportEmail;                       // from String.fromEnvironment('SUPPORT_EMAIL'); '' → null
Uri? supportEmailUri([String? email = supportEmail]);

// lib/data/disputes/dispute.dart (#142)
enum DisputeSubjectType { booking, ticket }
enum DisputeOrigin { booking, deliveryCheck, ticket }
enum DisputeReason {
  noShow('no_show'), notAsAgreed('not_as_agreed'), photosMissing('photos_missing'), notAsSample('not_as_sample'),
  linkBroken('link_broken'), eventNotHeld('event_not_held'), notAsDescribed('not_as_described'), other('other');
  const DisputeReason(this.code); final String code;
  static DisputeReason fromCode(String? c);                              // unknown → other
  static List<DisputeReason> offeredFor(DisputeOrigin origin);           // Decision 5
}
enum DisputeStatus { open, resolved }
enum DisputeOutcomeKind { release, refund, split }
class DisputeOutcome { kind, refundPercent, refundAmount, releaseAmount, note, decidedAt }
class Dispute { id, subjectType, subjectId, eventId, customerId, providerId, reason, description, evidencePaths,
  title, subtitle, providerName, thumbUrl, amountHeld, status, outcome, threadId, createdAt, resolvedAt;
  bool isCustomer(String uid); }
String disputeCode(String id);                                           // last 4, upper case
class DisputeDraft { disputeId, subjectType, subjectId, eventId, reason, description, evidencePaths }
class DisputeError implements Exception { const DisputeError(this.code); final String code; }  // domain code | 'network'

// lib/data/disputes/dispute_repository.dart
abstract class DisputeRepository {
  String evidencePath(String disputeId, String fileId);                 // disputeEvidence/{uid}/{disputeId}/{fileId}.jpg
  Stream<UploadEvent> uploadEvidence(PickedImage image, String storagePath);   // MediaUploader.upload(…, purpose: ImagePurpose.document) (#147)
  Future<void> deleteEvidence(String storagePath);                     // missing object is fine
  Future<String> open(DisputeDraft draft);                             // → disputeId; throws DisputeError
  Stream<Dispute?> watch(String disputeId);
  Future<List<Dispute>> mine({int limit = 10});                        // get, newest first
  Future<String> evidenceUrl(String storagePath);
}
// firestore_dispute_repository.dart: FirestoreDisputeRepository({required String? uid, required MediaUploader uploader,
//   required MediaUrlResolver urls, FirebaseFirestore? db, FirebaseFunctions? functions})
// dispute_providers.dart
final disputeRepositoryProvider = Provider<DisputeRepository>(...);    // rebuilt on uid change (event_providers pattern)
final disputeProvider = StreamProvider.autoDispose.family<Dispute?, String>(...);
final myDisputesProvider = FutureProvider.autoDispose<List<Dispute>>(...);
final evidenceUrlProvider = FutureProvider.autoDispose.family<String, String>(...);

// lib/data/support/support_thread.dart (#204)
enum SupportSenderRole { customer, provider, user, staff, system }
class SupportThread { id, kind, disputeId, participants, status, lastMessageAt }
class SupportMessage { id, threadId, senderId, senderRole, senderName, body, createdAt, sendState }  // MessageSendState reused
// support_repository.dart
abstract class SupportRepository {
  String helpThreadIdFor(String uid);                                   // 'help_$uid'
  Stream<SupportThread?> watchThread(String threadId);
  Stream<List<SupportMessage>> watchMessages(String threadId, {int limit = 30});
  Future<String> send({String? threadId, required String text, required String clientId});   // → threadId; throws SupportError
}
class SupportError implements Exception { const SupportError(this.code); final String code; }
// support_providers.dart: supportRepositoryProvider, supportThreadProvider(threadId), supportMessagesProvider(threadId)

// lib/features/disputes/dispute_entry.dart  (#142; entry API, also for #130)
sealed class DisputeSubject {
  const factory DisputeSubject.booking(String bookingId) = BookingDisputeSubject;
  const factory DisputeSubject.ticket({required String eventId, required String registrationId}) = TicketDisputeSubject;
}
class DisputeSubjectSummary { const DisputeSubjectSummary({required this.title, required this.subtitle, this.thumbUrl, this.badge}); }
/// Opens S18.01. Resolves to the new dispute id after a successful submit, null when closed.
Future<String?> showOpenDisputeSheet(BuildContext context, {required DisputeSubject subject,
  required DisputeSubjectSummary summary, required DateTime closesAt, DisputeOrigin origin = DisputeOrigin.booking});
/// Hours left (ceil), null when closed. Pure, used by S05.02/S11.04 to show the entry.
int? disputeHoursLeft(DateTime closesAt, DateTime now);
DateTime? bookingDisputeClosesAt(Booking b);          // status completed|reviewed, escrow held|partiallyRefunded, completedAt + 24 h
DateTime? ticketDisputeClosesAt(EventRegistration r); // paid, amount > 0, disputeId null, endsAt + 24 h
```

Routes: `/b/:id/dispute` (`BookingDetailScreen(openSheet: DetailSheet.dispute)`, `?from=delivery` → `DisputeOrigin.deliveryCheck`), `/disputes/:id` (`DisputeDetailScreen`, `ScreenCodes.disputeDetail`), `/help` (`HelpScreen`, `ScreenCodes.help`, #204), `/help/chat` (`SupportChatScreen`, `ScreenCode(ScreenCodes.help, label: 'chat')`, #204). New icon: `AppIcons.help = Symbols.help_rounded` (#204; `supportAgent` exists).

### Strings (`app_vi.arb`, exact)

S18.01 (#142): `disputeSheetTitle` "Báo vấn đề"; `disputeSheetTitleDelivery` "Báo vấn đề với ảnh gốc"; `disputeWindowLeft` "Còn {hours} giờ để báo vấn đề. Tiền của buổi chụp được giữ tới khi có kết quả."; `disputeWindowLeftTicket` "Còn {hours} giờ để báo vấn đề. Tiền vé được giữ tới khi có kết quả."; `disputeWindowLeftDelivery` "Còn {hours} giờ để kiểm tra bộ ảnh gốc. Đợt thanh toán thứ hai được giữ tới khi có kết quả."; `disputeReasonTitle` "Vấn đề là gì?"; `disputeReasonNoShow` "Thợ không đến"; `disputeReasonNotAsAgreed` "Không đúng thoả thuận"; `disputeReasonPhotosMissing` "Thiếu ảnh"; `disputeReasonNotAsSample` "Khác ảnh mẫu"; `disputeReasonLinkBroken` "Link hỏng"; `disputeReasonEventNotHeld` "Sự kiện không diễn ra"; `disputeReasonNotAsDescribed` "Khác mô tả"; `disputeReasonOther` "Lý do khác"; `disputeDescriptionLabel` "Mô tả"; `disputeDescriptionHint` "Chuyện gì đã xảy ra? Càng cụ thể, hỗ trợ xử lý càng nhanh."; `disputeDescriptionTooShort` "Viết ít nhất 10 ký tự"; `disputeEvidenceTitle` "Ảnh bằng chứng · {count}/5"; `disputeEvidenceAdd` "Thêm ảnh"; `disputeEvidenceRemove` "Bỏ ảnh"; `disputeEvidenceNote` "Ảnh chỉ bạn, người bị khiếu nại và đội hỗ trợ xem được."; `disputeEvidenceFailed` "Một ảnh chưa tải lên được. Chạm để thử lại."; `disputeSubmit` "Gửi khiếu nại"; `disputeSent` "Đã gửi khiếu nại. Tiền được giữ tới khi có kết quả."; `disputeDiscardTitle` "Bỏ nội dung đang viết?"; `disputeDiscardConfirm` "Bỏ"; `disputeDiscardKeep` "Viết tiếp"; `disputeErrNotEligible` "Khoản này không còn mở khiếu nại được."; `disputeErrDeadline` "Đã quá thời hạn báo vấn đề."; `disputeErrConflict` "Đã có một khiếu nại đang mở cho khoản này."; `disputeErrGeneric` "Chưa gửi được. Kiểm tra kết nối rồi thử lại."
Entries (#142): `disputeReportProblem` "Báo vấn đề · còn {hours} giờ"; `ticketReportProblem` "Báo vấn đề"; `disputeBannerOpen` "Đang khiếu nại"; `disputeBannerOpenBody` "Tiền được giữ tới khi có kết quả."; `disputeBannerResolved` "Khiếu nại đã có kết quả"; `disputeBannerView` "Xem khiếu nại".
S18.02 (#142): `disputeTitle` "Khiếu nại #{code}"; `disputeStatusOpen` "Đang xem xét"; `disputeStatusResolved` "Đã xử lý"; `disputeHeld` "Tiền đang giữ"; `disputeHeldNote` "Tạm dừng chuyển cho tới khi có kết quả"; `disputeOpenedAt` "Gửi lúc"; `disputeStepSent` "Đã gửi khiếu nại"; `disputeStepSentBody` "Mô tả và {count} ảnh bằng chứng"; `disputeStepReview` "Hỗ trợ đang xem xét"; `disputeStepReviewBody` "Hai bên trao đổi và gửi thêm bằng chứng ở mục Trao đổi"; `disputeStepOutcome` "Kết quả"; `disputeStepOutcomeBody` "Chuyển cho người nhận, hoàn cho bạn, hoặc chia"; `disputeDetailsTitle` "Mô tả & ảnh"; `disputeThreadTitle` "Trao đổi"; `disputeThreadHint` "Nhắn cho hỗ trợ…"; `disputeThreadClosed` "Khiếu nại đã đóng. Cần thêm hỗ trợ? Liên hệ ở mục Trợ giúp."; `disputeSenderSupport` "Hỗ trợ"; `disputeSenderProvider` "{name} · nhiếp ảnh gia"; `disputeSenderHost` "{name} · chủ sự kiện"; `disputeSenderCustomer` "{name} · khách"; `disputeResolvedToast` "Đã có kết quả · {when}"; `disputeOutcome` "Kết quả"; `disputeOutcomeRelease` "Chuyển tiền cho {name}"; `disputeOutcomeRefund` "Hoàn 100%"; `disputeOutcomeSplit` "Chia: hoàn {percent}%"; `disputeRefundToYou` "Hoàn cho bạn"; `disputeRefundToCustomer` "Hoàn cho khách"; `disputeReleaseTo` "Chuyển cho {name}"; `disputeReleaseToYou` "Chuyển cho bạn"; `disputeRefundWhere` "Về tài khoản hoặc ví đã thanh toán"; `disputeStaffNote` "Ghi chú của hỗ trợ: {note}"; `disputePlatformName` "ứng dụng"; `disputeNotFound` "Không tìm thấy khiếu nại"; `disputeNotFoundBody` "Khiếu nại này không tồn tại hoặc bạn không có quyền xem."; `supportSendFailed` "Chưa gửi được tin nhắn. Thử lại."; `supportRateLimited` "Bạn gửi hơi nhanh. Đợi vài phút rồi gửi tiếp."
S18.03 and chat (#204): Task 5 lists them (FAQ). Settings (#204): `settingsSupportSection` "Hỗ trợ"; `settingsHelp` "Trợ giúp"; `settingsHelpBody` "Câu hỏi thường gặp, liên hệ hỗ trợ".

## Review Focus

1. **Money released while disputed.** A disputed payment must survive `bookingClock` step 5 and the event completion (`releaseAfter` set) and never enter a payout. Pinned by Task 7 test `a disputed payment is not released by runBookingSweeps even after releaseAfter`.
2. **Split math on a partly refunded payment.** The percent applies to what is still held; the ledger invariant holds after every outcome; a 100% outcome on a partially refunded payment never refunds more than was paid. Pinned by Task 7 tests `split 40% of a partially refunded payment refunds 40% of the held rest` and `verifyPaymentLedgerInvariant holds after release, refund and split`.
3. **Privacy of evidence and threads.** A third user reads neither the dispute, nor the thread, nor an evidence file; a party can; a missing help thread reads as absent (not a permission error, or S18.03 crashes into its error state). Pinned by the rules tests of Task 3 (#204, threads) and Task 8 (#142, disputes, evidence) and Task 4 test `watchThread of a missing help thread emits null`.
4. **Double tap and abandoned sheets.** Re-sending the same `disputeId` returns the same dispute; a second dispute on the subject is `conflict`; photos uploaded in a sheet the user closes are deleted. Pinned by Task 7 `openDispute is idempotent for the same id` and Task 11 `closing the sheet after uploads deletes them`.
5. **Mirrors survive other writes.** After a dispute, a booking transition (review, reschedule system write) must keep `disputeId`, and the S05.02 banner must stay. Pinned by Task 8 (extends the shared `round-trips Booking through Firestore conversion` test with `disputeId`) and `registration mapping round-trips disputeId`.

## Chi phí Google

Unit prices from `docs/superpowers/specs/2026-10-07-google-cloud-costs.md`: Firestore $0.06/100K reads, $0.18/100K writes (nam5 upper bound, **chưa xác nhận** for Singapore). **Functions (one rule for every plan, cost spec §12):** at (b) new invocations and CPU fit the free tier (2M invocations, 180,000 vCPU-s, 360,000 GiB-s per month) → $0; at (c) the app already uses the free tier up (§12 (c): 2.5M invocations, ~500K vCPU-s), so this plan's Functions work is charged at Tier 2: $0.40/M invocations, $0.0000336/vCPU-s, $0.0000035/GiB-s. Other prices: Storage $0.020/GB-month; egress $0.12/GB (**giả định**). Volumes assumed: disputes 3% of bookings + 1 ticket dispute → 10/month at (b) 1,000 MAU (300 bookings), 100/month at (c) 10,000 MAU; 8 thread messages per dispute; help chats started by 3% of MAU with 5 messages each.

| Action | Reads | Writes | Notes |
|---|---|---|---|
| Show "Báo vấn đề" on S05.02 / S11.04 | 0 | 0 | from the booking / registration already loaded |
| Submit S18.01 (`openDispute`) | ~6 (dispute, subject, payment query, refunds, user name) | 6 (dispute, payment, subject mirror, thread, 2 messages) | + ≤ 5 Storage uploads |
| `onDisputeWrite` notify | ~3 per recipient | ~2 per recipient | prefs, user, inbox row |
| Open S18.02 | 1 + 1 + ≤ 30 | 0 | listeners (live thread while open), messages `limit(30)` |
| Send a thread message | 3 | 2 | + trigger notify ~3 reads / 2 writes per other party |
| Open S18.03 | ≤ 10 (`mine`, `get`, `limit(10)`, min 1) | 0 | FAQ is in the app |
| Open support chat | 1 + ≤ 30 | 0 | listener while open |
| `resolveDispute` | ~5 | ~6 (+ refund save) | |

New functions: 3 callables + 2 triggers. Calls/month: (b) `openDispute` 10, `resolveDispute` 10, `sendSupportMessage` 80 + 150, triggers ≈ 260 → ~510; (c) ~5,100; CPU ~0.2 vCPU-s each → < 1,100 vCPU-s: $0 at (b), ≈ $0.04 at (c) under the Functions rule. No scheduled job (no new Cloud Scheduler cost). Storage path `disputeEvidence/`: ~3 photos × 0.45 MB per dispute (`ImagePurpose.document`: 2048 px q85, ≤ 3 MiB by rule, no thumbnail: viewed rarely, at most 5 per dispute) → 13.5 MB/month at (b), 135 MB/month at (c), kept (Needs the owner 3) → 1.6 GB after a year at (c) = $0.03/month; egress ~5 views each → 70 MB (b), 675 MB (c) → $0.01 / $0.08. No paid API (no Maps, SMS, Vision).

Reads/month: (b) ≈ 7,000 ($0.004), (c) ≈ 70,000 ($0.04); writes (b) ≈ 1,000, (c) ≈ 10,000 ($0.02).

**Conclusion:** adds about **$0.02/month at (b)** and **$0.19/month at (c)** (incl. ≈ $0.04 Functions under the one rule); well under $5, no mitigation needed. Limits that keep it there: `limit(30)` thread pages, `get` for S18.03, rate limit on support messages, no thumbnails for rarely viewed evidence.

## Tasks

**Split (owner, 2026-10-08).** **#204 = Tasks 1–6** (help & support chat: FAQ, help inbox, the support-thread base that disputes reuse; Blocked by nothing). **#142 = Tasks 7–13** (disputes; Blocked by #152 and #204, because it runs on #204's support-thread base). Old task numbers (cross-plan review, ledgers before 2026-10-08) are given in each heading. #204 builds the generic thread (`support_threads`, `sendSupportMessage`, `SupportThreadView`) for `kind: 'help'`; #142 adds `kind: 'dispute'` threads on top without changing #204's code paths for help threads.

### Task 1 (#204): Mock check, screen codes and screen spec (was Task 1)

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 S18 rows, §3i.1 one paragraph), `docs/superpowers/specs/screens/README.md` (index row)
- Create: `docs/superpowers/specs/screens/disputes-help.md`
- Check only: `docs/design/ui-mock.html` (the S18 section exists since #187: `#S05.02-problem`, `#S18.01`, `#S18.01-delivery`, `#S18.02`, `#S18.02-thread`, `#S18.02-resolved`, `#S05.02-disputed`, `#S18.03`, `#S18.03-chat`; the code table already says "Có" for S18.01–S18.03 and the progress table has the "Khiếu nại & hỗ trợ" row; the S09.02 caption already names the Hỗ trợ group), `app_flutter/lib/core/screen_codes.dart` (S18.01–S18.03 exist; no change unless a name differs)

**Interfaces:** Uses the existing frame ids above; later tasks (of both issues) cite them.

- [ ] **Step 1: Contract check.** Every frame id above exists once; their copy matches this plan's Contract strings and Task 5's strings (S18.03) and Task 12's (S18.02). Where the committed mock differs from this plan, the mock wins (CLAUDE.md) and the difference is ledgered; do not re-insert frames.
- [ ] **Step 2:** Spec §2: S18.01 route `/b/:id/dispute` (sheet trên S05.02; `?from=delivery` từ S05.06) · sheet trên S11.04 (vé); S18.03 route `/help`, `/help/chat`; status cells: S18.03 "⬜ có mock, có plan (#204)", S18.01–S18.02 "⬜ có mock, có plan (#142)". §3i.1: add one paragraph "Đã chốt khi viết plan #142/#204 (2026-10-07, tách 2026-10-08)" summarising Decisions 2, 7, 8, 9 in Vietnamese. Create `screens/disputes-help.md` with the README template for S18.01, S18.02, S18.03 (+ chat), copying the strings of this plan's Contract, Task 5 and Task 12, and add its index row to `screens/README.md`.
- [ ] **Step 3: Commit** `docs(spec): S18 screen spec for help and disputes [#204]`.

### Task 2 (#204): Domain — support threads (support half of the old Task 2)

**Files:**
- Create: `packages/domain/src/support_thread.ts`, `support_use_cases.ts`, `support_notifications.ts` (`notifySupportMessage`), `memory_support_store.ts` (`MemorySupportStore implements SupportStore`); tests `packages/domain/test/support_use_cases.test.ts`, `support_notifications.test.ts`, `test/support/support_world.ts`
- Modify: `src/index.ts`

**Interfaces:** Produces `support_thread.ts`, `support_use_cases.ts` (`SupportTx` without `getDispute`, `SupportStore`, `SupportDeps`, `sendSupportMessage`, `staffReply`), `DisplayNames` (moved here from `dispute_ports.ts`; #142 imports it), `notifySupportMessage` and `MemorySupportStore` (refuses reads after writes inside one transaction, `memory_album_store.ts` pattern; #142's `MemoryDisputeStore` extends it so one world holds threads and disputes). Consumes `graphemeCount`, `truncateGraphemes`, `isId`, #138's `notifySupportReply` (merged in #155). In #204 `sendSupportMessage` serves `help_{uid}` threads only: a thread of kind `dispute` answers `not_found` until #142 (Task 7) adds that branch.

- [ ] **Step 1:** Contract check (domain bullets, #138's `notifySupportReply` signature); ledger differences.
- [ ] **Step 2: Failing tests.** `support_use_cases.test.ts`: `first help message creates help_{uid} with the sender as participant and awaitingStaff true`; `same clientId twice writes one message`; `another user's help thread → permission_denied`; `11th message in 10 minutes → limit_exceeded, the window restarts after 10 minutes`; `staffReply writes senderName Hỗ trợ, role staff, awaitingStaff false`; `text over 1000 graphemes or blank → invalid_argument`; `a dispute thread id → not_found (no dispute support yet)`. `support_notifications.test.ts` (through #138's hook): `a staff message in a help thread calls notifySupportReply for the owner`; `a user message notifies nobody`; `system messages notify nobody`.
- [ ] **Step 3:** Run `cd packages/domain && npm test` — new tests fail.
- [ ] **Step 4: Implement.** Rate window per sender in `thread.rate`; `lastMessagePreview` truncated to 80 graphemes; export the new modules from `index.ts`.
- [ ] **Step 5:** `npm test && npm run lint` green (including `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): support threads for the help inbox [#204]`.

### Task 3 (#204): Functions — support adapter, callable, trigger, staff CLI, rules (support halves of the old Tasks 3 and 4)

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/support_firestore.ts` (`FirestoreSupportStore implements SupportStore`, `FirestoreDisplayNames`), `src/infra/live_support.ts` (`liveSupportDeps()`), `src/callables/support.ts` (`handleSendSupportMessage`), `src/triggers/support_message_created.ts` (`handleSupportMessageCreated(threadId, messageData, deps)`), `tools/support.ts`; tests `test/unit/support_callables.test.ts`, `support_firestore.test.ts`, `support_triggers.test.ts`, `support_cli.test.ts`
- Modify: `src/index.ts` (`sendSupportMessage`, `onSupportMessageCreated`), `package.json` (`"support": "tsx tools/support.ts"`), `seed/README.md` (CLI section "Staff CLI for support"); `app_flutter/firebase/firestore.rules` (the `support_threads` block of the Contract), `firestore.indexes.json` (`support_threads (awaitingStaff ASC, lastMessageAt ASC)`), `rules-test/rules.test.mjs`

**Interfaces:** Consumes Task 2. `liveSupportDeps()` = `{store: new FirestoreSupportStore(db()), names: new FirestoreDisplayNames(db()), clock, ids: {newId: newUlid}}`. CLI shape copies `tools/awards.ts`: exported `parseArgs(argv)`, `HELP`, a `main()` guarded by `fileURLToPath(import.meta.url) === process.argv[1]`; `--actor` verified with Admin Auth `getUser(actor).customClaims.staffRole` (`admin|sales`).

- [ ] **Step 1:** Contract check (Functions, rules bullets; `tools/awards.ts`, `award_cli.test.ts`, trigger exports in `index.ts`); ledger differences.
- [ ] **Step 2: Failing tests.** `support_callables.test.ts`: `sendSupportMessage without auth → unauthenticated`; `without threadId writes to help_{uid}`; `limit_exceeded → resource-exhausted`. `support_firestore.test.ts`: `support message mapping keeps senderRole and senderName`; `thread round-trips (Timestamps ↔ ISO)`. `support_triggers.test.ts`: `support_reply for a staff message, nothing for a user or system message`; `a retry of the same event writes no second row (dedupe)`. `support_cli.test.ts`: `parseArgs list/show/reply`; `reply needs text and --actor`; `--help prints HELP`. Rules tests (written, not run): `a user gets their missing help thread (no error)`; `a user cannot get another user's help thread`; `nobody writes support threads or messages from the client`; `a participant reads the thread's messages, a third user cannot`.
- [ ] **Step 3:** `cd app_flutter/firebase/functions && npm test` — the new unit tests fail.
- [ ] **Step 4: Implement** the adapter (transaction: all reads first), callable, trigger, CLI (`support list` prints threads awaiting staff (`listAwaitingStaff(50)`); `show` prints the last 30 messages; `reply` runs `staffReply` with a fresh ULID clientId), rules and index.
- [ ] **Step 5:** `npm test && npm run build` (functions) and `cd packages/domain && npm test` green. Ledger: rules tests written, not run.
- [ ] **Step 6: Commit** `feat(functions): support messages, notifications and the support CLI [#204]`.

### Task 4 (#204): App data — support email and support threads (support half of the old Task 5)

**Files:**
- Create: `lib/data/support/support_thread.dart`, `support_repository.dart`, `firestore_support_repository.dart`, `support_providers.dart`; `test/support/fake_support_repository.dart`; tests `test/data/support/support_mapping_test.dart`
- Create if absent: `lib/core/app_config.dart` (`const String? supportEmail`, `Uri? supportEmailUri([String? email = supportEmail])`; absent on develop 4e25834). #135 (S21 Task 5) creates the same file with the same shape; whichever lands first creates it, exports it from `core.dart`, moves `event_links.dart`'s pair (`eventSupportEmail` / `eventSupportUri`, used by `event_info_tab.dart`) and its tests (`test/features/events/event_links_test.dart` → `test/core/app_config_test.dart`); the other reuses it unchanged.
- Modify: `lib/core/theme/app_icons.dart` (`help` only; `supportAgent` exists)

**Interfaces:** Produces the support part of the Dart contract (`lib/data/support/*`) and `app_config.dart`. `support_reply` visuals and the `/help/chat` target are #138's (merged). Callable errors map like `callEventFunction`: `details.code` → `SupportError(code)`, `unavailable|deadline-exceeded` → `'network'`.

- [ ] **Step 1:** Contract check (app data bullets, `app_config.dart` presence); ledger differences.
- [ ] **Step 2: Failing tests:** `watchThread of a missing help thread emits null` (fake Firestore or the adapter's null branch); `SupportMessage maps senderRole staff with name Hỗ trợ`; `send without threadId calls sendSupportMessage with threadId null and returns help_{uid}`; `supportEmail is null when SUPPORT_EMAIL is empty; supportEmailUri builds mailto` (only if this task creates `app_config.dart`).
- [ ] **Step 3:** Run the new test folders; they fail.
- [ ] **Step 4: Implement.** Messages stream `orderBy createdAt desc limit 30`, reversed for display.
- [ ] **Step 5:** `flutter analyze` clean; `flutter test --no-pub --timeout 60s test/core`, `test/data/support`, `test/features/events` green (one folder per command).
- [ ] **Step 6: Commit** `feat(data): support threads and the shared support email [#204]`.

### Task 5 (#204): Shared support thread view, S18.03 help, support chat and the settings entry (thread-view half of the old Task 7 + the old Task 8)

**Files:**
- Create: `app_flutter/lib/features/help/support_thread_view.dart` (`SupportThreadView({required String threadId, required bool enabled, String? disabledReason, required String hint, required String Function(SupportMessage) senderLabel})`, used by the help chat now and by S18.02 in #142), `lib/features/help/support_thread_controller.dart` (optimistic send with `clientId = newUlid()`, retry on failure), `help_screen.dart`, `help_faq.dart` (`List<FaqTopic> faqTopics(AppLocalizations l)`; `FaqTopic {id, label, items: List<(question, answer)>}`), `support_chat_screen.dart`; tests `test/features/help/support_thread_view_test.dart`, `help_screen_test.dart`, `support_chat_screen_test.dart`
- Modify: `lib/app/router.dart` (`/help`, `/help/chat`), `lib/features/settings/settings_screen.dart` (add group "Hỗ trợ" (`settings-group-support`, label `settingsSupportSection`) with row "Trợ giúp" `Key('settings-help')`, `AppIcons.help`, in #148's merged `settingsGroupOrder` slot `support` (after `paymentsData` when present, else after "Thông báo"; before Debug and "Đăng xuất"); the order test of #148 covers it), its test, `lib/l10n/app_vi.arb`

**Interfaces:** Consumes `supportMessagesProvider`, `SupportRepository.send`, `authStateProvider`, `supportEmail`, `supportEmailUri()`, `externalLauncherProvider`. Produces `SupportThreadView` and `HelpScreen` with an empty slot above the FAQ for "Khiếu nại của bạn", which #142 (Task 12) fills from `myDisputesProvider`; in #204 nothing renders there.

**Backend wiring:** help chat listener on `support_threads/help_{uid}` (+ messages, `limit(30)`) and `sendSupportMessage` without thread id.

**Mock parity:** `#S18.03` (sections in order: "Khiếu nại của bạn" only when there is one (#142), "Câu hỏi thường gặp" with topic chips and expandable rows, one `AppButton.primary` "Liên hệ hỗ trợ" with `AppIcons.supportAgent` in the footer, email line only when set), `#S18.03-chat` (title "Hỗ trợ", lock note, bubbles, composer "Nhắn cho hỗ trợ…", empty text).

Strings (exact): `helpTitle` "Trợ giúp"; `helpMyDisputes` "Khiếu nại của bạn"; `helpDisputeRow` "Khiếu nại #{code} · {name}"; `helpDisputeRowMeta` "{status} · {date}"; `helpFaqTitle` "Câu hỏi thường gặp"; `helpContactSupport` "Liên hệ hỗ trợ"; `helpEmailLine` "Email hỗ trợ: {email}"; `supportChatTitle` "Hỗ trợ"; `supportChatNote` "Chỉ bạn và đội hỗ trợ xem được cuộc trò chuyện này. Đừng gửi mật khẩu hay mã OTP."; `supportChatHint` "Nhắn cho hỗ trợ…"; `supportChatEmpty` "Bạn cần giúp gì? Nhắn cho đội hỗ trợ, chúng tôi trả lời tại đây và báo cho bạn khi có tin mới."
Topics: `helpTopicPayments` "Thanh toán"; `helpTopicCancel` "Huỷ & hoàn tiền"; `helpTopicDelivery` "Bàn giao ảnh"; `helpTopicDisputes` "Khiếu nại"; `helpTopicContact` "Liên hệ"; `helpTopicReviews` "Đánh giá"; `helpTopicProviders` "Dành cho thợ ảnh".
FAQ (question / answer, exact):
- `helpPayFullQ` "Vì sao phải trả trước 100%?" / `helpPayFullA` "Tiền không đến tay thợ ngay. Ứng dụng giữ tiền và chỉ chuyển cho thợ theo 2 đợt: sau buổi chụp, và sau khi bạn đồng ý ảnh rồi kiểm tra bộ ảnh gốc trong 48 giờ. Có lỗi thì bạn được hoàn qua ứng dụng."
- `helpPayHeldQ` "Tiền của tôi được giữ ở đâu?" / `helpPayHeldA` "Tiền do một tổ chức trung gian thanh toán được cấp phép giữ, không nằm trong tài khoản của ứng dụng, và chưa chuyển cho thợ cho tới khi đủ điều kiện."
- `helpPayQrQ` "Chuyển khoản QR sai số tiền thì sao?" / `helpPayQrA` "Hãy chuyển đúng số tiền và nội dung trong 15 phút. Chuyển thiếu, thừa hoặc sau khi QR hết hạn sẽ được hoàn tự động về tài khoản đã chuyển."
- `helpCancelRefundQ` "Huỷ buổi chụp được hoàn bao nhiêu?" / `helpCancelRefundA` "Huỷ trước giờ chụp từ 48 giờ trở lên: hoàn 100%. Từ 24 đến 48 giờ: hoàn 50%. Dưới 24 giờ: không hoàn. Tính trên toàn bộ số đã trả. Thợ huỷ thì bạn được hoàn 100%."
- `helpCancelWhereQ` "Tiền hoàn về đâu?" / `helpCancelWhereA` "Trả bằng ví MoMo hoặc ZaloPay thì hoàn về ví. Chuyển khoản thì hoàn về tài khoản đã chuyển, hoặc tài khoản khác bạn khai."
- `helpCancelLateQ` "Thợ giao ảnh trễ thì sao?" / `helpCancelLateA` "Quá số ngày đã hẹn, bạn được huỷ phần bàn giao và hoàn 100% đợt thanh toán thứ hai; thợ giữ đợt đầu."
- `helpDeliverySampleQ` "Ảnh mẫu có watermark là gì?" / `helpDeliverySampleA` "Thợ gửi ảnh mẫu có watermark trước. Link bộ ảnh gốc bị che và chỉ mở khi bạn bấm \"Đồng ý ảnh\". Không phản hồi trong 3 ngày thì hệ thống tự đồng ý."
- `helpDeliveryEditQ` "Muốn sửa ảnh thì làm sao?" / `helpDeliveryEditA` "Trao đổi màu sắc, chỉnh sửa ngay trên ảnh mẫu. Số vòng sửa miễn phí theo gói. Hết lượt thì bạn đồng ý, xin thêm một vòng, hoặc mở khiếu nại."
- `helpDisputeWhenQ` "Khi nào tôi mở khiếu nại được?" / `helpDisputeWhenA` "Trong 24 giờ sau khi buổi chụp hoàn thành, hoặc trong 24 giờ sau khi sự kiện có vé trả tiền kết thúc. Với bộ ảnh gốc, bạn có 48 giờ kể từ khi đồng ý ảnh. Quá thời hạn thì nút \"Báo vấn đề\" không còn. Vé không thu phí không có khiếu nại vì không có tiền được giữ."
- `helpDisputeMoneyQ` "Trong lúc khiếu nại, tiền ở đâu?" / `helpDisputeMoneyA` "Tiền tiếp tục được giữ, không chuyển cho thợ. Đội hỗ trợ xem bằng chứng của hai bên rồi quyết định: chuyển cho thợ, hoàn cho bạn, hoặc chia."
- `helpDisputeEvidenceQ` "Ai xem được ảnh bằng chứng?" / `helpDisputeEvidenceA` "Chỉ bạn, người bị khiếu nại và đội hỗ trợ."
- `helpContactQ` "Khi nào tôi gọi được cho thợ?" / `helpContactA` "Gọi, Zalo, WhatsApp chỉ mở sau khi bạn đã thanh toán. Trước đó bạn nhắn tin hỏi trong ứng dụng. Số điện thoại không hiện công khai."
- `helpReviewQ` "Cà chua và gạch là gì?" / `helpReviewA` "Cà chua là hài lòng, gạch là chưa hài lòng; bấm 1 đến 10 lần để nói mức độ. Hồ sơ thợ hiện tỉ lệ cà chua. Mỗi buổi chụp đánh giá một lần, gửi rồi không sửa."
- `helpProviderStartQ` "Làm sao để bắt đầu nhận đơn?" / `helpProviderStartA` "Xác minh số điện thoại, đóng phí xác minh (thợ ảnh 99.000₫, studio 299.000₫, không hoàn), xác minh danh tính bằng VNeID hoặc chip CCCD và đồng ý quy định nhận việc. Nhân viên duyệt trong 24 giờ."
- `helpProviderPaidQ` "Khi nào tôi nhận được tiền?" / `helpProviderPaidA` "Tiền về theo 2 đợt: sau buổi chụp, và sau khi khách đồng ý ảnh và hết 48 giờ kiểm tra. Chi tự động mỗi ngày vào tài khoản đã xác minh; lần chi đầu do nhân viên duyệt."
Topic membership: payments (PayFull, PayHeld, PayQr), cancel (CancelRefund, CancelWhere, CancelLate), delivery (DeliverySample, DeliveryEdit), disputes (DisputeWhen, DisputeMoney, DisputeEvidence), contact (Contact), reviews (Review), providers (ProviderStart, ProviderPaid).

- [ ] **Step 1:** Contract check (settings sections, router, `ChatBubble`, `ChatComposer`).
- [ ] **Step 2: Failing tests:** `SupportThreadView labels staff messages Hỗ trợ and leaves mine unlabelled`; `sending shows the bubble at once and keeps it with a retry when the call fails`; `limit_exceeded shows "Bạn gửi hơi nhanh…"`; `disabled shows disabledReason and no composer`; `help without disputes shows no "Khiếu nại của bạn" section`; `topic chips switch the questions; the first topic is Thanh toán`; `a question expands to its exact answer and collapses again (semantics expanded state)`; `every FAQ key has a non-empty question and answer` (iterate `faqTopics`); `"Liên hệ hỗ trợ" pushes /help/chat`; `the email line is hidden when supportEmail is null and opens mailto when set` (inject through a provider override of a `supportEmailProvider` that defaults to `supportEmail`); `support chat empty state shows the empty text and the lock note`; `sending creates the help thread through send(threadId: null)`; `settings shows the "Hỗ trợ" group after "Thông báo" and before "Đăng xuất"; "Trợ giúp" opens /help`; `help fits 320dp at 1.3x text`.
- [ ] **Step 3:** Run; they fail.
- [ ] **Step 4: Implement.** Expandable rows: `ExpansionTile`-free custom row (glass card rows like the mock, `AppIcons.expandMore` rotated), `Semantics(expanded:)`. The composer sits in the bottom bar (`AppFooterBar`). Strings + `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; `test/features/help`, `test/features/settings` green; `dart run tool/affected_test.dart origin/develop --run` green.
- [ ] **Step 6: Commit** `feat(help): S18.03 help with FAQ and support chat [#204]`.

### Task 6 (#204): Docs, data model, ledger (support half of the old Task 9)

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 S18.03 status cell → "✅ đã làm (#204)"), `docs/superpowers/specs/data-model/domain-model.md` (`SupportThread`, `SupportMessage` rows), `relational-schema.md` (`support_threads`, `support_messages` DDL + Firestore mapping rows), `data-model/README.md` (`send_support_message`), `docs/superpowers/specs/screens/disputes-help.md` (S18.03 Trạng thái "Đã có"), `docs/legal/terms-and-help-notes.md` (one line under P8: the FAQ keys that quote it), `docs/FIREBASE-SETUP.md` (only if it lists callables/indexes; add `sendSupportMessage` and the index)
- Create: `docs/superpowers/handover/ledger-s18-help.md`

- [ ] **Step 1:** Edit the docs (Vietnamese specs, English code names). Check every S18.03 string in `screens/disputes-help.md` against `app_vi.arb` and the mock.
- [ ] **Step 2:** Ledger: rulings, rules tests written not run, the temporary FAQ/app copy mismatch if #129/#152 have not landed (Decision 15), the extension points left for #142 (`kind: 'dispute'` branch of `sendSupportMessage`, the S18.03 disputes slot, `SupportThreadView`).
- [ ] **Step 3: Commit** `docs(spec): S18 help inbox in the data model, ledger [#204]`.

### Task 7 (#142): Domain — disputes, outcomes, dispute threads, notifications (dispute half of the old Task 2)

**Files:**
- Create: `packages/domain/src/dispute.ts`, `dispute_ports.ts`, `dispute_use_cases.ts`, `dispute_notifications.ts`, `memory_dispute_store.ts` (`MemoryDisputeStore extends MemorySupportStore implements DisputeStore`); tests `packages/domain/test/dispute.test.ts`, `dispute_use_cases.test.ts`, `dispute_notifications.test.ts`, `test/support/dispute_world.ts`
- Modify: `support_use_cases.ts` (the `kind: 'dispute'` branch of `sendSupportMessage`; `SupportTx.getDispute`), `support_notifications.ts` (dispute threads: `notifyDisputeMessage` for a party message, `notifySupportReply` for all participants), `test/support_use_cases.test.ts`, `escrow.ts` (`Payment.dispute` shape, `applyRefundToPayment` `amount?`), `booking.ts` (`Booking.disputeId?: string | null`), `booking_policy.ts` (remove `MIN/MAX_DISPUTE_REASON_LENGTH`), `index.ts`, `test/escrow.test.ts`, `test/booking_sweeps.test.ts` (no notification module: #138's)
- Delete: `open_dispute.ts`, `test/open_dispute_reason.test.ts`

**Interfaces:** Produces everything under "Domain" in the Contract except #204's support modules (Task 2), which it extends. Consumes #204's `support_thread.ts`, `support_use_cases.ts`, `MemorySupportStore`, `DisplayNames`; `applyRefundToPayment`, `releaseEscrowPayment`, `disputeEscrowPayment`, `verifyPaymentLedgerInvariant`, `graphemeCount`, `truncateGraphemes`, `formatVnd`, `formatDayShortVi`, `isId`; #129's `escrowRefundedTotal` and `PaymentGateway.issueRefund` (V2's `sendRefundOnce`, `mergeRefundOutcome` once they exist); #130's `disputeMilestone`, `releaseMilestone`, `PaymentMilestone`; #138's four hooks (Contract signatures).

- [ ] **Step 1:** Contract check (domain bullets above; #204's support modules merged); ledger differences.
- [ ] **Step 2: Failing tests.** `dispute.test.ts`: `parseOpenDisputeInput accepts a booking dispute with 0–5 evidence paths`; `refuses a reason that does not belong to the subject` (ticket + `no_show` → invalid_argument); `refuses a description under 10 or over 1000 graphemes after trim`; `refuses 6 evidence paths and a path under another uid or another dispute id`; `disputeWindow: shot booking closes 24 h after shotAt with milestone shoot`; `approved booking closes at checkUntil with milestone delivery`; `completed booking with milestones → not_eligible (nothing held)`; `legacy completed booking (no milestones) closes 24 h after completedAt`; `upcoming booking is not_eligible`; `at the closing instant exactly → deadline_passed`; `paid ticket opens at endAt and closes 24 h later; before endAt → not_eligible`; `free ticket → not_eligible`; `outcomeAmounts: release 0/held, refund held/0, split 40% of 1 500 000 → 600 000 / 900 000, split 33% of 1 000 001 floors the refund`; `split 0 or 100 or 12.5 → invalid_argument`.
  `dispute_use_cases.test.ts` (`createDisputeWorld()`): `openDispute on an approved booking freezes only the delivery milestone (shoot stays released) and opens the thread`; `openDispute on a shot booking freezes the shoot milestone`; `a legacy payment without milestones is frozen whole and stores prevEscrowStatus partially_refunded`; `openDispute is idempotent for the same id` (same result, one thread, no second message); `a second dispute on the same booking → conflict`; `another customer → permission_denied`; `a booking whose payment was already released → not_eligible`; `ticket dispute freezes the ticket payment and sets registration.disputeId; platform event → parties is the customer only`; `resolveDispute release on a milestone dispute releases that milestone only (releaseMilestone), outcome stored with decidedBy, thread closed`; `refund on a delivery-milestone dispute refunds the delivery amount (`fromEscrow: true`), never the released shoot milestone`; `split 40% of a frozen milestone refunds 40% of that milestone`; `split on a legacy payment uses amount − escrowRefundedTotal (a refund with fromEscrow false is not subtracted)`; `verifyPaymentLedgerInvariant holds after release, refund and split`; `resolving twice → conflict`; `note under 5 characters → invalid_argument`; `dispatchDisputeRefund marks the refund done, failed+manual when the gateway fails or throws (#129 Ruling 7), and never overwrites a refund that is no longer pending` (with V2: a throw keeps it pending and an awaiting_account refund is not sent).
  `booking_sweeps.test.ts`: `a disputed payment is not released by runBookingSweeps even after releaseAfter`.
  `support_use_cases.test.ts` (added): `a dispute party can write while open, its role is customer or provider`; `a non-party → permission_denied`; `after resolution → not_eligible`.
  `dispute_notifications.test.ts` (through #138's hooks): `open calls notifyDisputeOpened for the provider only, not a platform payee`; `resolve calls notifyDisputeResolved for every party`; `staff message in a dispute thread calls notifySupportReply for all participants`; `a provider message calls notifyDisputeMessage for the customer`; `system messages notify nobody`. (Copy pinned by #138.)
- [ ] **Step 3:** Run `cd packages/domain && npm test` — new tests fail.
- [ ] **Step 4: Implement.** The resolve transaction is the part to get right:
  ```ts
  export async function resolveDispute(deps: DisputeDeps, staffId: string, raw: unknown) {
    const input = parseResolveInput(raw);                     // disputeId, kind, refundPercent?, note (5–500)
    const now = deps.clock.now();
    const pre = await deps.store.runTransaction((tx) => tx.getDispute(input.disputeId));
    if (!pre) throw new DomainError('not_found');
    const refundsSoFar = escrowRefundedTotal(await deps.store.getRefundsForPayment(pre.paymentId)); // #129: fromEscrow false excluded
    return deps.store.runTransaction(async (tx) => {
      const d = await tx.getDispute(input.disputeId);
      const p = d && (await tx.getPayment(d.paymentId));
      const subject = d && (await tx.getSubject(d.subjectType, d.subjectId, d.eventId));
      if (!d || !p || !subject) throw new DomainError('not_found');
      const ms = p.dispute?.milestone ? p.milestones?.find((m) => m.kind === p.dispute!.milestone) ?? null : null;
      if (d.status !== 'open' || (ms ? ms.status !== 'disputed' : p.escrowStatus !== 'disputed')) throw new DomainError('conflict');
      const held = ms ? ms.amount : p.amount - refundsSoFar;   // Decision 7: the frozen milestone, else the legacy rest
      const a = outcomeAmounts(held, input.kind, input.refundPercent);
      let pay: Payment = { ...p, escrowStatus: p.dispute?.prevEscrowStatus ?? 'held', updatedAt: now.toISOString() };
      let refund: Refund | null = null;
      if (a.refundAmount > 0) {
        const r = applyRefundToPayment({ payment: pay, refundId: deps.ids.newId(), percent: a.refundPercent,
          amount: a.refundAmount, ledgerEntryId: deps.ids.newId(), reason: `dispute:${d.id}`, now });
        pay = r.payment; refund = r.refund; tx.addRefund(r.refund); tx.addLedgerEntry(r.ledgerEntry);
      }
      if (a.releaseAmount > 0) {
        const r = ms   // #130: release only that milestone (its amount minus this refund); legacy: whole payment
          ? releaseMilestone(pay, ms.kind, deps.ids.newId(), now)
          : releaseEscrowPayment({ payment: pay, refundAmount: refundsSoFar + a.refundAmount, ledgerEntryId: deps.ids.newId(), now });
        pay = r.payment; tx.addLedgerEntry(r.ledgerEntry);
      }
      tx.setPayment(pay);
      tx.linkSubject(subject, { disputeId: d.id, escrowStatus: pay.escrowStatus });
      // … dispute resolved + outcome (decidedBy = staffId), thread closed, system message; read everything before the first write.
    });
  }
  ```
  `openDispute`: parse → read dispute by id (idempotent return) → subject → `permission_denied` unless `customerId === caller` → `disputeWindow` → an open `subject.disputeId` dispute → `conflict` → `findSubjectPayment`: the window's milestone must be `held` (frozen with #130's `disputeMilestone`), or for a legacy payment the payment `held|partially_refunded` (else `not_eligible`) → `amountHeld` = the milestone amount, or `amount − escrowRefundedTotal(refunds)` (refunds read before the transaction) → writes. `MemoryDisputeStore` (extending #204's `MemorySupportStore`) refuses reads after writes inside one transaction. Delete `open_dispute.ts` and its test; export the new modules from `index.ts`.
- [ ] **Step 5:** `npm test && npm run lint` green (including `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): disputes with escrow freeze and outcomes [#142]`.

### Task 8 (#142): Functions — dispute adapters, callables, rules, Storage, indexes, seed (dispute half of the old Task 3)

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/dispute_firestore.ts` (`FirestoreDisputeStore extends FirestoreSupportStore implements DisputeStore`; `FirestoreDisplayNames` is #204's), `src/infra/live_dispute.ts` (`liveDisputeDeps()`), `src/callables/dispute.ts` (`handleOpenDispute`, `handleResolveDispute`); tests `test/unit/dispute_callables.test.ts`, `dispute_firestore.test.ts`; integration `test/integration/dispute.test.ts` (written, not run)
- Modify: `src/index.ts` (re-point `openDispute`; export `resolveDispute`), `src/callables/booking.ts` (drop `handleOpenDispute` and its import), `src/infra/booking_firestore.ts` (`disputeId` both ways; payment `dispute.disputeId/prevEscrowStatus`), `src/infra/event_firestore.ts` (registration `disputeId` both ways), `seed/fixtures.ts`, `seed/README.md`, `test/unit/booking_callables.test.ts` (remove openDispute cases), `test/unit/booking_firestore.test.ts`, `test/unit/event_firestore.test.ts`, `test/unit/seed_fixtures.test.ts`; `app_flutter/firebase/firestore.rules` (the `disputes` block; the `support_threads` block is #204's and already lets dispute parties read through `participants`), `storage.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs`

**Interfaces:** Consumes the domain use cases (Task 7) and #204's `FirestoreSupportStore`, `FirestoreDisplayNames`. Produces the callables of the Contract. `liveDisputeDeps()` = `{store: new FirestoreDisputeStore(db()), gateway: getSharedFakeGateway() /* #129's live gateway, infra/live_booking.ts */, cipher: aesGcmCipher(PAYOUT_ACCOUNT_KEY.value()) /* created lazily, as livePayoutAccountDeps does */, names: new FirestoreDisplayNames(db()), clock, ids: {newId: newUlid}}`. Staff check in `handleResolveDispute`: `request.auth?.token?.staffRole === 'admin'` else `permission_denied` (award pattern). After the resolve transaction the handler calls `dispatchDisputeRefund` when a refund was created and logs `dispute_resolved` with the dispute id only.

- [ ] **Step 1:** Contract check (Functions, rules bullets); ledger differences.
- [ ] **Step 2: Failing tests.** `dispute_callables.test.ts`: `openDispute without auth → unauthenticated`; `maps not_eligible, deadline_passed and conflict to failed-precondition/failed-precondition/aborted with details.code`; `returns {disputeId}`; `resolveDispute by a user without the admin claim → permission-denied`; `resolveDispute by admin returns the amounts and dispatches the refund once`. `dispute_firestore.test.ts`: `dispute document round-trips (Timestamps ↔ ISO, outcome null and set)`; `findSubjectPayment for a booking picks the held payment`. `booking_firestore.test.ts`: extend the shared `round-trips Booking through Firestore conversion` test with `disputeId`; `payment dispute keeps disputeId, milestone and prevStatus`. `event_firestore.test.ts`: `registration mapping round-trips disputeId`. `seed_fixtures.test.ts`: `seed-dispute-lan-an is open on seed-booking-disputed with a thread`; `seed-booking-completed-window is completed 2 hours before seeding with a held payment`; `the past paid ticket ended 3 hours before seeding with a held payment`.
  Rules tests (written, not run): `a party reads its dispute`; `a third user cannot get or list a dispute`; `nobody writes disputes from the client`; `a party reads dispute thread messages, a third user cannot`. Storage rules tests: `owner uploads a JPEG under their uid, not another's`; `PNG or a JPEG over 3 MiB is refused` (`jpegUpTo`); `overwrite refused`; `a party reads evidence, a third user cannot`; `owner deletes evidence only while no dispute document exists`.
  Integration (written, not run): `openDispute then bookingClock leaves the payment disputed; resolveDispute split releases and refunds on the fake gateway`.
- [ ] **Step 3:** `cd app_flutter/firebase/functions && npm test` — the new unit tests fail.
- [ ] **Step 4: Implement** adapters (transaction: all reads first; `findSubjectPayment` for bookings = `payments where subjectId == bookingId` read inside the transaction with `tx.get(query)`), callables, rules, Storage rule and the two `disputes` indexes (Contract). Seed per Decision 17 (compute the seed dispute with the same domain helpers, not by hand), README rows for the three new seed items and a "Staff CLI for disputes" note pointing to Task 9.
- [ ] **Step 5:** `npm test && npm run build` (functions) and `cd packages/domain && npm test` green. Ledger: rules/storage/integration tests written, not run.
- [ ] **Step 6: Commit** `feat(functions): openDispute and resolveDispute with rules and seed [#142]`.

### Task 9 (#142): Functions — dispute trigger and the disputes CLI (dispute half of the old Task 4)

**Files:**
- Create: `src/triggers/dispute_write.ts` (`handleDisputeWrite(before, after, deps: NotifyDeps)`), `tools/disputes.ts`; tests `test/unit/dispute_triggers.test.ts`, `disputes_cli.test.ts`
- Modify: `src/index.ts` (`onDisputeWrite`), `src/triggers/support_message_created.ts` (dispute threads go through the extended `notifySupportMessage`; no code change expected), `test/unit/support_triggers.test.ts`, `package.json` (`"disputes": "tsx tools/disputes.ts"`), `seed/README.md` (CLI section)

**Interfaces:** Consumes `notifyDisputeChange`, `notifySupportMessage`, `resolveDispute`, `dispatchDisputeRefund`, `liveNotifyDeps()`, `liveDisputeDeps()`. CLI shape copies `tools/awards.ts` (as #204's `tools/support.ts`); `--actor` must hold `staffRole: 'admin'`.

- [ ] **Step 1:** Contract check (`tools/awards.ts`, `tools/support.ts`, trigger exports in `index.ts`).
- [ ] **Step 2: Failing tests.** `dispute_triggers.test.ts`: `created open dispute → one dispute_opened to the provider`; `open → resolved → dispute_resolved to both parties`; `a retry of the same event writes no second row (dedupe)`; `a deleted document notifies nobody`. `support_triggers.test.ts` (added): `dispute_message for a party message in a dispute thread`. `disputes_cli.test.ts`: `parseArgs list/show/resolve release|refund|split`; `split needs 1–99`; `resolve needs a note and --actor`; `--help prints HELP`.
- [ ] **Step 3:** Run; they fail.
- [ ] **Step 4: Implement.** `list` prints id, created date, subject title, amount held, status (`listByStatus`); `show` prints the dispute, evidence paths and the last 30 thread messages; `resolve` runs `resolveDispute` then `dispatchDisputeRefund`.
- [ ] **Step 5:** `npm test && npm run build` green.
- [ ] **Step 6: Commit** `feat(functions): dispute notifications and the disputes CLI [#142]`.

### Task 10 (#142): App data — disputes (dispute half of the old Task 5)

**Files:**
- Create: `lib/data/disputes/dispute.dart`, `dispute_repository.dart`, `firestore_dispute_repository.dart`, `dispute_providers.dart`; `test/support/fake_dispute_repository.dart`, `dispute_world.dart`; tests `test/data/disputes/dispute_mapping_test.dart`
- Modify: `lib/data/booking/booking.dart` (+ `disputeId`), `firestore_booking_repository.dart` (map `disputeId`; remove `openDispute`), `booking_repository.dart` (remove `openDispute`), `booking_rules.dart` (remove `canCustomerDispute` and `disputeWindowHours`; their tests go), `test/support/fake_booking_repository.dart`, `lib/data/events/event_registration.dart` (+ `disputeId`), `firestore_event_mapping.dart`

**Interfaces:** Produces the disputes part of the Dart contract (`lib/data/disputes/*`). Notification visuals and targets of the dispute types are #138's (merged: `dispute_opened` → (`AppIcons.flag`, action); `dispute_resolved` → (`AppIcons.payment`, success); `dispute_message` → (`AppIcons.chat`, neutral); `/disputes/:id` allowlisted). Callable errors map like `callEventFunction`: `details.code` → `DisputeError(code)`, `unavailable|deadline-exceeded` → `'network'`.

- [ ] **Step 1:** Contract check (app data bullets); ledger differences.
- [ ] **Step 2: Failing tests:** `Dispute.fromFirestore maps status, outcome and Timestamps; unknown reason → other`; `disputeCode takes the last 4 characters upper-cased`; `DisputeReason.offeredFor(deliveryCheck) is photos_missing, not_as_sample, link_broken, other`; `open() sends the draft fields and returns disputeId`; `open() maps details.code conflict to DisputeError('conflict')`; `Booking maps disputeId`; `EventRegistration maps disputeId`.
- [ ] **Step 3:** Run the new test folders; they fail.
- [ ] **Step 4: Implement.** Evidence paths: `disputeEvidence/$uid/$disputeId/${newUlid()}.jpg`. `FirestoreDisputeRepository.mine()` = `disputes where parties array-contains uid orderBy createdAt desc limit 10` (`get`).
- [ ] **Step 5:** `flutter analyze` clean; `flutter test --no-pub --timeout 60s test/data/disputes`, `test/data/booking`, `test/data/events`, `test/features/notifications` green (one folder per command).
- [ ] **Step 6: Commit** `feat(data): dispute repository and booking/registration dispute ids [#142]`.

### Task 11 (#142): S18.01 open-dispute sheet and its entries (S05.02, S11.04) (was Task 6)

**Files:**
- Create: `app_flutter/lib/features/disputes/dispute_entry.dart`, `open_dispute_sheet.dart`, `open_dispute_controller.dart`; tests `test/features/disputes/open_dispute_sheet_test.dart`, `dispute_entry_test.dart`
- Modify: `lib/features/booking/booking_detail_screen.dart` (`DetailSheet.dispute`, `/b/:id/dispute` in `bookingDetailRoutes()`, the red text button, the banner), `lib/features/booking/booking_view_rules.dart` (`DetailAction.reportProblem` for the customer when `bookingDisputeClosesAt` is in the future and `disputeId == null`), `lib/core/widgets/ticket_card.dart` (`onReportProblem`, `reportProblemLabel` on the compact row), `lib/features/events/tickets_tab.dart`, `lib/l10n/app_vi.arb` (S18.01 + entry strings); tests `test/features/booking/booking_detail_screen_test.dart`, `test/features/booking/booking_view_rules_test.dart`, `test/core/widgets/ticket_card_test.dart`, `test/features/events/tickets_tab_test.dart`

**Interfaces:** Consumes `DisputeRepository`, `imagePickerProvider`, `clockProvider`. Produces the entry API of the Contract (`showOpenDisputeSheet`, `disputeHoursLeft`, `bookingDisputeClosesAt`, `ticketDisputeClosesAt`, `DisputeSubject`, `DisputeSubjectSummary`, `DisputeOrigin`). `OpenDisputeController` (AutoDispose `Notifier<OpenDisputeState>`, keyed by the dispute id it mints on first build): `reason`, `description`, `photos: List<EvidenceSlot {picked, path?, progress, failed}>`, `submitting`, `error`; `pick()` (max 5 − count), `retry(slot)`, `remove(slot)` (deletes the uploaded object), `submit()` → disputeId, `discard()` (deletes every uploaded object).

**Backend wiring:** `openDispute` callable through `FirestoreDisputeRepository.open`; uploads to `disputeEvidence/{uid}/{disputeId}/…` (Storage rule of Task 8); no Firestore read.

**Mock parity:** `#S18.01` (title, window line with `AppIcons.schedule`, chip reasons in this order, description field + counter, "Ảnh bằng chứng · n/5" grid with add tile, lock note, one `AppButton.primary` "Gửi khiếu nại"), `#S18.01-delivery` (title, delivery window line, four chips), `#S05.02-problem` (red text "Báo vấn đề · còn {h} giờ" under the actions), `#S05.02-disputed` (banner with `AppIcons.flag`, "Xem khiếu nại").

- [ ] **Step 1:** Contract check (booking detail, view rules, ticket card, tickets tab); ledger differences.
- [ ] **Step 2: Failing tests:** `the sheet shows the booking reasons in mock order and the window "Còn 18 giờ…"`; `delivery origin shows the delivery title, window copy and four reasons`; `ticket subject shows the ticket reasons and "Tiền vé…"`; `submit is disabled until a reason is picked and the description has 10 characters`; `the counter shows n/1000`; `picking 6 photos keeps 5`; `evidence uploads pass purpose ImagePurpose.document to the uploader` (`FakeMediaUploader.purposes`, #147); `a failed upload shows the retry text and blocks submit until retried or removed`; `submit sends reason code, trimmed description and the uploaded paths, then pops the dispute id`; `conflict shows "Đã có một khiếu nại đang mở cho khoản này."` (and deadline/not-eligible copies); `dragging down after typing asks "Bỏ nội dung đang viết?"`; `closing the sheet after uploads deletes them`. `booking_view_rules_test`: `reportProblem only for the customer of a completed booking inside 24 h with held escrow and no dispute`; `not for upcoming, not after 24 h, not when disputeId is set`. `booking_detail_screen_test`: `the red "Báo vấn đề · còn 18 giờ" opens S18.01 and a success pushes /disputes/:id`; `/b/:id/dispute opens the sheet over S05.02`; `?from=delivery opens the delivery variant`; `a booking with disputeId shows "Đang khiếu nại" for both roles and opens /disputes/:id`; `the resolved banner reads "Khiếu nại đã có kết quả"`. `ticket_card_test`: `compact row shows "Báo vấn đề" only with onReportProblem`. `tickets_tab_test`: `a paid past ticket inside its window shows "Báo vấn đề"; a free one does not`. `dispute_entry_test`: `disputeHoursLeft rounds up and is null at closesAt`.
- [ ] **Step 3:** Run the four test folders; new tests fail.
- [ ] **Step 4: Implement.** Sheet in `showAppSheet` with `canDismiss` asking the discard confirm when anything was entered; `ScreenCode(ScreenCodes.openDispute, …)`; reasons with `ReasonPicker(style: ReasonPickerStyle.chips)`; photo tiles reuse `NetworkPhoto`/file thumbnails at 1:1 in a 3-column grid with a dashed add tile (`AppIcons.addPhoto`); uploads at most 2 at a time. The S05.02 banner is an `EscrowNotice`-styled tappable row (field background, `AppIcons.flag`) shown above the `BookingCard`; the red text button reuses the cancel button's style. Strings into `app_vi.arb`, `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; run `test/features/disputes`, `test/features/booking`, `test/core/widgets`, `test/features/events` (one per command) green.
- [ ] **Step 6: Commit** `feat(disputes): S18.01 open-dispute sheet from S05.02 and S11.04 [#142]`.


### Task 12 (#142): S18.02 dispute detail and the disputes section of S18.03 (dispute half of the old Task 7 + the S18.03 disputes rows of the old Task 8)

**Files:**
- Create: `app_flutter/lib/features/disputes/dispute_detail_screen.dart`, `lib/features/disputes/widgets/dispute_outcome_card.dart`; tests `test/features/disputes/dispute_detail_screen_test.dart`
- Modify: `lib/app/router.dart` (`/disputes/:id`), `lib/features/help/help_screen.dart` (fill #204's slot with "Khiếu nại của bạn" from `myDisputesProvider`), `test/features/help/help_screen_test.dart`, `lib/l10n/app_vi.arb` (S18.02 strings; `helpMyDisputes`, `helpDisputeRow`, `helpDisputeRowMeta` if #204 did not add them)

**Interfaces:** Consumes `disputeProvider`, `evidenceUrlProvider`, `myDisputesProvider`, #204's `SupportThreadView` (with `enabled: dispute.status == open`), `authStateProvider`. Sender labels: staff → `disputeSenderSupport`; provider → `disputeSenderProvider(name)` (`disputeSenderHost` for tickets); customer → `disputeSenderCustomer(name)`; own messages unlabeled (`ChatBubble(mine: true)`); system messages as `SystemContent`.

**Backend wiring:** listeners on `disputes/{id}`, `support_threads/dispute_{id}` and its `messages` (`limit(30)`, rules of Tasks 3 and 8); sending through `sendSupportMessage`; evidence URLs through `MediaUrlResolver.downloadUrl` (Storage rule checks parties); S18.03 rows: `get` of `disputes where parties array-contains uid orderBy createdAt desc limit 10` (index of Task 8).

**Mock parity:** `#S18.02` (title "Khiếu nại #K7Q2", subject card + status badge, key-value block "Tiền đang giữ" with the note and "Gửi lúc", three-step `StatusTimeline`, "Mô tả & ảnh" with a 3-column grid, "Trao đổi" with labelled bubbles (`#S18.02-thread`), composer "Nhắn cho hỗ trợ…"), `#S18.02-resolved` (toast "Đã có kết quả · {when}", badge "Đã xử lý", outcome rows by role, staff note line, closed text, outline "Liên hệ hỗ trợ" in the footer, no composer); `#S18.03` "Khiếu nại của bạn" rows.

- [ ] **Step 1:** Contract check (router, `StatusTimeline`, #204's `SupportThreadView` and help slot).
- [ ] **Step 2: Failing tests:** `customer view of an open dispute: "Khiếu nại #K7Q2", "Đang xem xét", "Tiền đang giữ 1.500.000₫", three steps with "Hỗ trợ đang xem xét" current`; `provider view of a split outcome reads "Hoàn cho khách 600.000₫" and "Chuyển cho bạn 900.000₫"`; `customer view of split reads "Hoàn cho bạn" and "Chuyển cho Minh Trí"`; `release outcome reads "Chuyển tiền cho {name}"; refund reads "Hoàn 100%"`; `platform event release names "ứng dụng"`; `the staff note shows "Ghi chú của hỗ trợ: …"`; `messages are labelled Hỗ trợ / "{name} · nhiếp ảnh gia" / mine unlabelled`; `resolved: no composer, the closed text and "Liên hệ hỗ trợ" pushes /help/chat`; `an unknown or forbidden id shows "Không tìm thấy khiếu nại"`; `tapping an evidence photo opens it full screen`; `fits 320dp at 1.3x text`. Help: `help shows "Khiếu nại của bạn" with "Khiếu nại #K7Q2 · Minh Trí" / "Đang xem xét · 14/10" only when the user has disputes`; `tapping a dispute row pushes /disputes/:id`.
- [ ] **Step 3:** Run; they fail.
- [ ] **Step 4: Implement** with `AsyncView`; the composer sits in the bottom bar (`AppFooterBar`), the rest scrolls; no `AppButton.primary` on this screen (send is the composer's own button). Route `/disputes/:id` outside the tab shell. Strings + `flutter gen-l10n`.
- [ ] **Step 5:** `flutter analyze` clean; `test/features/disputes`, `test/features/help` green.
- [ ] **Step 6: Commit** `feat(disputes): S18.02 dispute detail and my disputes on S18.03 [#142]`.

### Task 13 (#142): Docs, data model, ledger and status (dispute half of the old Task 9)

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 S18.01–S18.02 status cells → "✅ đã làm (#142)"), `docs/superpowers/specs/data-model/domain-model.md` (`Dispute` row; `Payment.dispute` shape; `DisputeStatus`, `DisputeOutcomeKind`, `DisputeReason` enums; escrow state machine note "disputed → prevEscrowStatus → released|refunded|partially_refunded"), `relational-schema.md` (`disputes` DDL + Firestore mapping rows), `data-model/README.md` (`resolve_dispute` row: callable `resolveDispute` + CLI), `docs/superpowers/specs/screens/disputes-help.md` (S18.01–S18.02 Trạng thái "Đã có"), `docs/FIREBASE-SETUP.md` (only if it lists callables/indexes; add the dispute ones)
- Create: `docs/superpowers/handover/ledger-s18-disputes.md`

- [ ] **Step 1:** Edit the docs (Vietnamese specs, English code names). Check every S18.01–S18.02 string in `screens/disputes-help.md` against `app_vi.arb` and the mock.
- [ ] **Step 2:** Ledger: rulings taken while implementing, rules/Storage/integration tests written not run, deploy order (indexes before the app release that queries `disputes`; Functions `openDispute` re-point and the app ship together since no client used the old shape), extension points handed to #129/#152 (`findSubjectPayment`, `disputeWindow`, `DisputeOrigin.deliveryCheck` + `/b/:id/dispute?from=delivery`).
- [ ] **Step 3: Commit** `docs(spec): S18 disputes in the data model, ledger [#142]`.

## Deferred

- Real payment intermediary, real refunds and payouts (#129 and the payments spec §10–11); disputes run on the fake gateway.
- Staff dashboard screens S23.01 (dispute queue) and S23.06 (support inbox) — phase 1.5 (#83); phase 1 uses `resolveDispute` + CLIs.
- Provider-opened disputes after "hết lượt sửa" (#130). (Milestone-level freezing and the `shot`/`approved` windows are no longer deferred: Decisions 1, 2, 7.)
- Withdrawing a dispute (Needs the owner 2); evidence purge job (Needs the owner 3); images in support chat; staff "reviewing" sub-state.
- "Chụp ngay" FAQ (S13 plans); self-hosted parity (`services/api` has no disputes; Go backend phase 2 #90).
- Analytics events (no analytics layer, as in earlier plans).
