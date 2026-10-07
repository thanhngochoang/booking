# S05/S06 · Bàn giao hai lớp (S06.07, S05.06, S05.07) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Rules emulator tests (2026-10-02, user):** this plan changes `firestore.rules`, `storage.rules`, `firestore.indexes.json` and adds Functions (one Storage trigger). Write the rules tests and the Functions integration tests; do not run them, CI runs them. Record the skips in the ledger.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`).

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

> **Runs after** `docs/superpowers/plans/2026-10-07-s05-tomato-brick-reviews.md` (same issue #130): it needs `isReviewable`, `BookingRules.canReview/isReviewed` and `booking.reviewedAt` without the `reviewed` status. Best after #129 (`2026-10-07-s04-booking-payment.md`, 100 % payment); works before it. Tasks 4 (Storage rule) and 7 (upload) are blocked by #147 (`2026-10-07-s10-post-upload.md`, shared image API; Decision 16). Coordinates with #134 and #142 as Decision 15 says.

**Goal:** After the shoot, the provider (the photographer, or the studio account for a studio booking) submits a delivery round: 3–20 sample photos that the **server** watermarks, plus a hidden link to the full set. The customer reviews the watermarked samples (S05.06), asks for revisions within the package's free rounds or one extra round the provider may grant (S05.07), and approves; the link then opens, a 48‑hour check starts, and when it passes without a reported problem the booking completes and the second payout milestone is released on the fake payout path. The first milestone is released 24 h after the shoot. Review opens at approval.

**Architecture:** Rules in `packages/domain`: the booking machine gains `shot`, `delivered`, `revision_requested`, `approved` (new `delivery.ts`, `delivery_use_cases.ts`, `milestones.ts`; `booking_machine.ts`, `booking_sweeps.ts`, `commit_transition.ts`, `escrow.ts`, `payout_use_cases.ts`, `earnings.ts` extended). Functions: four callables (`submitDelivery`, `approveDelivery`, `requestRevision`, `answerExtraRound`), `transitionBooking` action `mark_shot`, the existing 15‑minute `bookingClock` runs the new sweeps (auto-approve, finish the check, release milestones, purge old samples), and a Storage trigger `onDeliveryUpload` watermarks each clean sample with `sharp` (resize to 1600 px, JPEG q75, metadata stripped, diagonal text drawn from a bundled font through `opentype.js`), writes the watermarked file and a 400 px thumbnail to `deliveries/{bookingId}/`, records `bookings/{id}/deliverySamples/{fileId}`, and deletes the clean upload at once. The original link lives in `bookings/{id}/private/delivery`, readable by the customer only from `approved`. Flutter: `lib/data/delivery/` (Firestore + fake), S06.07 sheet, provider actions on S05.02 and a "Chờ bàn giao" section on S06.01, S05.06 screen, S05.07 sheet, report sheet; no watermarking ever runs on a device.

**Tech Stack:** TypeScript (domain, Functions v2 `onCall`, `onSchedule`, `onObjectFinalized`, `sharp` ^0.34, `opentype.js` ^1.3, `node --test`), Firestore + Storage rules and indexes; Flutter, Riverpod 3, go_router, freezed/build_runner (`Booking`), `image_picker` (existing), `cached_network_image` (existing), `url_launcher` via `ExternalLauncher` (existing).

**Spec:** `docs/superpowers/specs/2026-10-06-delivery-preview-unlock-design.md` (all; Task 1 rewrites parts per the owner decisions below); `2026-10-05-provider-types-portfolio-jobs-design.md` §4.1–4.3 (milestones, revisions, machine); `2026-10-06-payments-payouts-design.md` §4 (milestones), §5 (refund by method — deferred), §6 (payouts); `2026-10-06-studio-members-design.md` §5.6 (studio delivers); `2026-10-06-tomato-brick-reviews-design.md` §5 (review opens at `approved`); main spec `2026-10-01-remaining-screens.md` §2 (rows S05.02, S05.03, S05.06, S05.07, S06.01, S06.05, S06.07), §3g (escrow); `data-model/domain-model.md` §2.4, §4, §5, §6 invariant 18; `relational-schema.md` (proposed `booking_milestones`, `booking_deliveries`); `docs/superpowers/specs/2026-10-07-google-cloud-costs.md` §10 (watermark); mock `docs/design/ui-mock.html` `#S05.06`, `#S05.06-approved`, `#S05.07`, `#S06.07`, `#S05.02`, `#S05.02-studio` (step "Bàn giao & duyệt ảnh"), `#S05.03`, `#S06.05` ("mốc 1/2").

**Issue:** #130 (S05 · Theo dõi buổi chụp, bàn giao & đánh giá), items "Bàn giao hai lớp …" and "S05.03 gắn `ScreenCode`"; also #134's item "S06.07 Nộp bàn giao" (the same screens; close that checkbox from this PR). "Hoàn tiền theo phương thức" is deferred to #141 (see Deferred).

**Branch:** `plan/130-delivery-two-layer` from `origin/develop` after the reviews plan is merged; PR into `develop` titled `feat(delivery): two-layer delivery with server watermark and milestone release (S05.06, S05.07, S06.07) [#130]`.

## Contract with existing code

Checked 2026-10-07 on `develop` 812afd6. Each task's Step 1 re-checks its part; adapt and ledger any difference. If a member named here does not exist, stop and report instead of guessing.

- Domain (`packages/domain/src`): `booking.ts` (`BOOKING_STATUSES` draft…reviewed; `Booking` fields incl. `completedAt`, `reviewedAt`, `escrowStatus`, `deposit`, `remaining`, `serviceSnapshot {name, price, durationMinutes}`); `booking_machine.ts` (`TransitionAction` accept/decline/cancel/upcoming/complete/review/expire, `decideTransition`, `roleOf`); `commit_transition.ts` (`completed` sets `payment.releaseAfter = now + 24 h`); `booking_ports.ts` (`BookingTx`, `BookingStore` incl. `getPaymentsForBooking`, `findAutoCompletions`, `findReleasableEscrows`; `ServiceRecord {id, photographerId, name, price, durationMinutes, active}`; `BookingDeps {store, services, providers, contacts, gateway, clock, ids}`); `booking_sweeps.ts` (`runBookingSweeps`: drafts, expire, upcoming, auto-complete, release); `booking_policy.ts` (`AUTO_COMPLETE_DELAY_HOURS = 24`, `DISPUTE_WINDOW_HOURS = 24`, `parseVnDateTime`); `create_booking.ts` (`createBookingDraft`); `escrow.ts` (`Payment` with `escrowStatus`, `releaseAfter`, `payoutId`, `dispute`; `releaseEscrowPayment`, `disputeEscrowPayment`, `LEDGER_ENTRY_TYPES`); `open_dispute.ts` (allows `upcoming`/`completed` within 24 h of `completedAt`); `payout.ts` (`isPayoutPayable`, `PayoutItem {paymentId, amount}`); `payout_use_cases.ts` (`createPayout`, `executePayout`); `payout_ports.ts` (`PayoutTx.listPayablePayments`); `earnings.ts` (`earningItemOf`, `EarningItem`, `summarizeEarnings`), `refresh_earnings.ts`; `contact.ts` (`bookingContactUnlocked`); `booking_chat_sync.ts`; `errors.ts` (`ERROR_CODES`); `memory_booking_store.ts`; `review.ts` after the reviews plan (`isReviewable`); `ids.ts` (`isId`, `newUlid`); `booking_requests.ts` (`graphemeCount`).
- Functions (`app_flutter/firebase/functions/src`): `config.ts` (`REGION`, `CALLABLE_OPTIONS`, `SCHEDULE_OPTIONS`, `TRIGGER_OPTIONS`, `payoutsMode`), `callables/booking.ts` (`handleTransitionBooking`, `handleOpenDispute`), `callables/errors.ts` (`toHttpsError`, code→status table), `infra/booking_firestore.ts` (`bookingToFirestore` writes the **whole** document with `set`, `bookingFromFirestore`, `paymentToFirestore`, `FirestoreBookingStore` + `find*` queries), `infra/booking_readers.ts` (`FirestoreServiceCatalog`), `infra/live_booking.ts`, `infra/payout_firestore.ts` (`listPayablePayments`, `listDuePayees` query `escrowStatus == 'released'`), `infra/earnings_firestore.ts`, `scheduled/booking_clock.ts` (`handleBookingClock`), `index.ts:125` (`bookingClock`, `timeoutSeconds: 300`), `triggers/booking_write.ts`, `tools/payouts.ts` (staff CLI, fake gateway), `seed/fixtures.ts` (`SEED_BOOKINGS`, `bookingData`, payments, earnings), `build.mjs` (esbuild bundle; externals `firebase-admin`, `firebase-functions`), `package.json` (`test:integration` runs `--only auth,firestore,functions`). No Storage trigger exists yet.
- Rules: `firestore.rules:458-483` (`bookings` read by parties; `private/{docId}` only `contact`; `events` subcollection), `isBookingContactUnlocked(b)` (~line 450); `storage.rules` (no `deliveryUploads`, no `deliveries`; catch-all deny). Indexes: `bookings` composites for `status` + `acceptDeadline`/`createdAt`; `payments (escrowStatus, releaseAfter)`.
- App data: `lib/data/booking/booking.dart` (freezed `Booking`, `fromFirestore`: unknown status → `draft`), `booking_status.dart` (`BookingStatus`, `.color`, `.label`), `booking_repository.dart` (`BookingAction {accept, decline, cancel, complete}`, `BookingRepository.transitionBooking`, `openDispute`, `BookingErrorCode`, `bookingErrorOf`), `firestore_booking_repository.dart`, `booking_rules.dart` (`tabForBooking`, `canReview`/`isReviewed` from the reviews plan), `contact_access.dart` (`contactAccessForBooking`); `lib/data/media/` (`ImagePickerPort.pickImages({max})` 2048/q85, `PluginImagePicker`, `MediaUploader.upload`, `MediaUrlResolver.downloadUrl`, `mediaUrlResolverProvider`, `FirebaseMediaUploader`); `lib/data/earnings/earnings.dart` (`EarningItem`), `firestore_earnings_repository.dart`; `lib/data/contact/` (`externalLauncherProvider`).
- App features/core: `lib/features/booking/booking_detail_screen.dart` (`bookingDetailRoutes()` with `/b/:id`, `/cancel`, `/decline`, `/review`; `DetailAction`; `_onAction`; `_actions`), `booking_view_rules.dart` (`detailActions`, `timelineSteps`, `bucket`, `workDashboard`, `WorkDashboard`, `roleIn`), `cancel_sheet.dart` (no `ScreenCode`), `my_bookings_screen.dart`; `lib/features/work/work_screen.dart`, `work_dashboard.dart`; `lib/features/earnings/earnings_screen.dart` (row meta from `formatDay`); core `ScreenCode`, `ScreenCodes.deliveryReview` (S05.06), `.requestRevision` (S05.07), `.submitDelivery` (S06.07), `.cancelBooking` (S05.03), `showAppSheet`, `showConfirmSheet(…danger, confirmEnabled)`, `ReasonPicker`, `AppChip`, `AppButton`, `BookingCard`, `StatusTimeline`/`TimelineStep`, `CountdownText`, `NetworkPhoto`, `EscrowNotice`, `SectionHeader`, `StatusBadge`, `EmptyState`, `AsyncView`, `DotRingLoader`, `AppIcons` (`lock`, `link`, `check`, `info`, `close`, `add`, `more`).

## Global Constraints

- Delivery spec B1 (as amended): "Một lần bàn giao gồm **ảnh mẫu (3–20)** có watermark do server đóng và **link bộ ảnh gốc** bị che." B2: "Khách đồng ý trên ảnh mẫu thì link mở." B3: "Số vòng sửa miễn phí theo gói/báo giá (`terms.revisions`, 0–5). Hết lượt: khách đồng ý, xin thêm vòng (người bàn giao cho hoặc không), hoặc mở khiếu nại." B4: "Link mở ngay khi khách đồng ý (hoặc tự đồng ý sau 3 ngày im lặng). Khách có **48 giờ kiểm tra** bộ ảnh gốc; không báo vấn đề thì mốc 2 chuyển." B5: "Người bàn giao: thợ (booking cá nhân), **studio** (booking studio)." B6: "Màn đánh giá mở ngay khi link mở (`approved`)."
- Owner decisions after the spec (Task 1 writes them in): watermark is done **by the server**: the provider uploads clean samples to a temporary Storage path only the provider can write; a Function watermarks them into the delivery path and **deletes the clean copy at once**; **never** watermark on the customer's device (and the clean copy never reaches it); samples are compressed to **1600 px long side, JPEG q75, EXIF stripped**; Storage rules carry **size limits**.
- §4 machine: `shot ──(nộp bàn giao)──▶ delivered`; `delivered ──(yêu cầu sửa, còn lượt)──▶ revision_requested ──(nộp vòng mới)──▶ delivered`; `delivered ──(đồng ý | im lặng 3 ngày)──▶ approved` (link opens, `checkUntil = +48 giờ`); `approved ──(48 giờ không báo vấn đề)──▶ completed` (mốc 2); `approved ──(Báo vấn đề với ảnh gốc)──▶` dispute, mốc 2 held; "Đồng hồ tự đồng ý 3 ngày đặt lại mỗi khi có vòng ảnh mẫu mới."
- Money (CLAUDE.md, payments spec §4): two milestones, mốc 1 `shoot` = `shot` + 24 h without dispute, mốc 2 `delivery` = `approved` + 48 h without "Báo vấn đề"; money only on the fake rails (`FakePaymentGateway`, `FakePayoutGateway`, staff CLI `npm run payouts`); no real intermediary.
- Rules (spec §3, §7): the customer never reads `private/delivery` before `approved`; nobody but the provider writes `deliveryUploads/…`; no client reads clean uploads; booking, deliveries, milestones are server-only writes.
- Mock is the authority for layout and copy (Task 1 adds the missing frames first); one `AppButton.primary` per screen/sheet; cancel/decline/report are red buttons in a confirmation sheet.
- CLAUDE.md: rules in `packages/domain` (no Firebase/Node imports, `purity.test.ts`); Functions thin, region `asia-southeast1`; Firebase only in `lib/data/**` adapters, `firebase_options.dart`, `main.dart`; strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons`; imports `package:photobooking/...`, features import `core/core.dart`; every screen/sheet in `ScreenCode`; `AsyncView` for every `AsyncValue`.
- Data conventions (`data-model/README.md`): ULID ids (sample `fileId` is a ULID made on the device), UTC instants, integer VND, string enum codes (`shot`, `delivered`, `revision_requested`, `approved`, `shoot`, `delivery`, `held`, `released`, `paid_out`, `refunded`, `disputed`, `approve`, `request_revision`, `pending`, `granted`, `declined`).
- Commits: Conventional Commits, subject ends with `[#130]`, footer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.
- Tests: Flutter one folder or file at a time: `flutter test --no-pub --timeout 60s <file or folder>` (bounded pumps; `CountdownText` and progress rings driven by a fake clock, no endless animation); domain `cd packages/domain && npm test && npm run lint`; functions `cd app_flutter/firebase/functions && npm test && npm run build`; rules-test and Functions integration suites written, not run. After editing `Booking` run `dart run build_runner build --delete-conflicting-outputs`.
- New npm packages (`sharp`, `opentype.js`, `@types/opentype.js`) need `registry.npmjs.org`; if the sandbox refuses the install, stop and ask the owner to run `cd app_flutter/firebase/functions && npm install sharp@^0.34 opentype.js@^1.3 && npm install -D @types/opentype.js`, then continue.
- Env for Flutter commands (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.

## Decisions

1. **Server watermark, clean copy gone at once (owner).** Upload path `deliveryUploads/{bookingId}/{uploaderId}/{fileId}.jpg`; the trigger writes `deliveries/{bookingId}/{fileId}.jpg` (1600 px, q75) and `deliveries/{bookingId}/{fileId}_t.jpg` (400 px, q70, the grid thumbnail) and deletes the upload in a `finally`, success or not. The spec's `sampleOriginals` (clean copy kept for disputes) is dropped: the original set behind the link is the dispute evidence. The device compresses before upload too, through the shared image API of #147 (`2026-10-07-s10-post-upload.md`): `MediaUploader.upload(image, storagePath: …, purpose: ImagePurpose.deliverySample)` resizes to 1600 px, JPEG q75, strips EXIF and caps the file at 2 MiB inside the uploader (the delivery code never calls a compressor), which keeps uploads small; the server does not trust it and re-encodes.
2. **Text without system fonts.** Cloud Functions images have no guaranteed font with Vietnamese glyphs, so the label "{tên người bàn giao} · Bản xem trước" is turned into SVG path data with `opentype.js` from `functions/assets/fonts/BeVietnamPro-SemiBold.ttf` (copied from `app_flutter/assets/fonts/`, OFL, `OFL.txt` copied alongside) and composited by `sharp`; white fill at 35% opacity with a faint dark stroke, tiled diagonally (−32°, like the mock `.wm`). JPEG only (`image/jpeg`): the picker re-encodes to JPEG, and `sharp`'s prebuilt libvips cannot decode HEIC.
3. **Who delivers = the booking's provider account** (`booking.photographerId`: the photographer, or the studio account for a studio booking). An assignee (#136) is never the deliverer: rules and `canDeliver` compare with `photographerId` only, so #136 only has to hide the S06.07 entry from assignees.
4. **Free rounds per package.** `createBookingDraft` snapshots `revisionsIncluded = clamp(service.deliverables.revisions ?? 1, 0, 5)` (10-05 spec: `Service.revisions = 1` default); existing bookings without it read as 1. Editing the number in the package editor (S08.01) is #146's.
5. **Extra round.** With no free round left the customer sends the same S05.07 sheet in "Xin thêm 1 vòng" mode → `booking.extraRound = {status: 'pending', …}` (status stays `delivered`); the provider answers "Cho thêm 1 vòng" (→ `revisionsGranted + 1`, `revisionsUsed + 1`, `revision_requested` with the pending notes) or "Không thêm" (→ `declined`). The auto-approve clock keeps running (the spec resets it only on a new round); one pending request at a time; a declined customer can still approve, or report later through S18 (#142).
6. **Machine actions.** `mark_shot` replaces `complete` for `accepted|upcoming → shot` (photographer after the end, system at end + 24 h); `complete` stays accepted as an alias of `mark_shot` for one release (older dev builds). `finish` (system) moves `approved → completed` when `checkUntil` has passed and the escrow is not disputed. Delivery transitions (`submit`, `approve`, `request_revision`, extra round) live in `delivery_use_cases.ts` because they write delivery records in the same transaction.
7. **Milestones on the payment (fake rails).** Source of truth: `payment.milestones`, split at `shot`: `shoot` = ⌊net × 50 %⌋, `delivery` = the rest (invariant 18), `net = amount − refunded` (with #129 landed, `amount` is the full price). `shoot.releaseAfter = shotAt + 24 h` (the existing step‑5 sweep releases it through `payment.releaseAfter`); `delivery` is released inside the `finish` transaction. Each release writes its own `escrow_released` ledger entry. Payment fields: `milestones`, `payableAmount` (Σ released and not batched) and an aggregate `escrowStatus` (disputed > held > released > paid_out; all refunded → refunded). Read model: `bookings/{id}/milestones/{kind}` (`{kind, amount, status, releaseAfter, releasedAt}`, the path of spec 10‑05 §5 that #134's earnings `getSubject` reads), kept equal to the payment's array by the existing `onPaymentWritten` trigger. Payouts batch per milestone (`PayoutItem.milestone`). Earnings keep **one row per payment** (mock `#S06.05` "T5 10/10 · mốc 1/2"): row `state` = disputed > released (payable part) > held > paid_out, the row's money split into `heldAmount`/`soonAmount`/`receivedAmount` so the three totals stay exact, and `milestonesDone`/`milestonesTotal` (the field names #134's plan uses). Payments without milestones (tickets, old bookings) keep today's path unchanged. The 50/50 split is the 10‑05 default until `BookingTerms.milestones` exist (#139).
8. **Disputes.** `openDispute` accepts `shot` within 24 h of `shotAt` (disputes the `shoot` milestone) and `approved` before `checkUntil` (disputes `delivery`; this is "Báo vấn đề với ảnh gốc"). The booking status does not change (S18 #142 adds `disputed` handling and staff resolution); `finish` skips a disputed booking, so mốc 2 stays held. The report sheet sends the chosen reason as the dispute text.
9. **The link.** `bookings/{id}/private/delivery {link, round, unlockedAt}`; the round doc carries only `linkHost` (e.g. `drive.google.com`) so S05.06 can draw `drive.google.com/••••••••` before approval without the customer reading the link. Link rule: `http(s)` URL, ≤ 2,000 characters, a host with a dot, no spaces.
10. **Samples lifecycle.** Each processed sample gets `bookings/{id}/deliverySamples/{fileId}` (`ready` or `failed`, provider-readable); `submitDelivery` consumes the `ready` ones (copies `path`, `thumbPath`, size into the round and deletes the sample docs). Unused samples and their files are deleted by the provider ("×" on a tile) or, if left, by the purge. Watermarked files are purged 90 days after `completed` unless the booking is disputed (`samplesPurgeAfter`), by a step of the existing `bookingClock` (no new Scheduler job); S05.06 then shows "Ảnh mẫu đã xoá sau 90 ngày".
11. **Notifications.** None emitted here; the booking status, `deliveryRound`, `autoApproveAt`, `extraRound` and the round docs are the data #138 needs for `delivery_submitted`, `delivery_revision_requested`, `delivery_approved`, `delivery_auto_approve_soon`, `delivery_extra_round` (delivery spec §6). Until then the lists and S05.02 show the state.
12. **Booking list tabs.** `shot`, `delivered`, `revision_requested` → "Đang chờ"; `approved`, `completed`, `reviewed` → "Đã xong" (the review button lives there, mock `#S05.01` caption). Status labels: `shot` "Chờ bàn giao", `delivered` "Chờ duyệt ảnh", `revision_requested` "Cần chỉnh sửa", `approved` "Đã đồng ý ảnh".
13. **Contact stays unlocked** through `shot`, `delivered`, `revision_requested`, `approved` (domain `bookingContactUnlocked`, rules `isBookingContactUnlocked`, app `contactAccessForBooking`); the 30‑day window still starts at `completedAt`.
14. **Refund by payment method** (payments spec §5) needs the payment method and sender account from #129's `createPayment`/webhook and the S22.04 sheet (#141); nothing here refunds after a split. Deferred to #141.
15. **Sibling plans written the same day** (`2026-10-07-s04-booking-payment.md` #129, `2026-10-07-s06-work-earnings.md` #134, `2026-10-07-s18-disputes-help.md` #142). Each task's Step 1 checks which of them is merged and adapts: (a) #129 merged → the payment is the 100 % `createPayment` payment and its single release at `completed` + 24 h is replaced by the milestone path here (its Decision 18 hands this over); not merged → the same code splits the deposit payment. (b) #134 merged → reuse its `EarningItem` fields (`milestonesDone`, `milestonesTotal`, breakdown) and l10n keys `earningsMilestones` "mốc {done}/{total}" / `earningsMilestonesAll` "đủ {total} mốc" instead of adding them; `PayoutItem` keeps its `fee/tax/net` and gains `milestone`. Not merged → add exactly those names here so #134 finds them. (c) #142 merged → "Báo vấn đề với ảnh gốc" opens its S18.01 sheet (mock `#S18.01-delivery`) and Task 2 extends its `disputeWindow` (`shot` → `shotAt` + 24 h, `approved` → `checkUntil`) and `findSubjectPayment` (freeze only the milestone of the window) instead of `openDispute`; the `#S05.06-report` frame and `report_delivery_sheet.dart` are then not created. Not merged → the minimal report sheet + `openDispute` of Decision 8, which #142 later replaces. Ledger which branch was taken.

16. **Shared image API from #147 (dependency of the upload piece).** The S06.07 clean upload uses the S10 plan's API (`2026-10-07-s10-post-upload.md`, issue #147): `MediaUploader.upload(image, storagePath: 'deliveryUploads/{bookingId}/{uid}/{fileId}.jpg', purpose: ImagePurpose.deliverySample)` (1600 px, q75, EXIF stripped, ≤ 2 MiB, `Cache-Control` of the purpose; compression happens inside the uploader), and the `deliveryUploads/` Storage rule uses its helper `jpegUpTo(2 * 1024 * 1024)`. No size limit or compressor of its own here. Tasks 4 (Storage rule) and 7 (upload) need #147 merged; Tasks 1–3, 5, 6 and 8 do not. The server still re-encodes and watermarks (the client copy is never trusted).

## Needs the owner

1. Watermarked samples are deleted 90 days after the booking completes (not disputed). Default 90 days; say if they must live longer as evidence.
2. A pending "Xin thêm 1 vòng" has no answer deadline and the 3‑day auto-approve keeps running. Default as written (Decision 5); alternative: pause auto-approve while pending.
3. 50/50 milestone split for every booking until per-package milestones exist. Default 50/50 (10‑05 spec §4.1).
4. "Huỷ phần bàn giao" when the provider is past `deliveryDays` (10‑05 §4.1.5) has no mock. Default: deferred to S18 (#142) with disputes.

## Contract

### Data (Firestore, all server-written)

`bookings/{id}` adds: `shotAt`, `deliveredAt`, `approvedAt`, `checkUntil`, `autoApproveAt` (Timestamps or null); `deliveryRound` (int, 0 before the first round); `revisionsIncluded` (int 0–5, default 1), `revisionsUsed` (int), `revisionsGranted` (int); `extraRound` (`{status: 'pending'|'granted'|'declined', at, note|null, photoNotes: [{sampleIndex, note}]}` or null); `samplesPurgeAfter` (Timestamp or null), `samplesPurged` (bool). `status` adds `shot`, `delivered`, `revision_requested`, `approved`.

`bookings/{id}/deliveries/{round}` (doc id = round as a string): `round`, `samples: [{fileId, path, thumbPath, width, height}]` (3–20), `photoCount`, `linkHost`, `note|null`, `submittedAt`, `submittedBy`, `decision: null | {kind: 'approve'|'request_revision', note|null, photoNotes: [{sampleIndex, note}], at, auto: bool, extra: bool}`.

`bookings/{id}/private/delivery`: `link`, `round`, `unlockedAt|null`, `updatedAt`.

`bookings/{id}/deliverySamples/{fileId}`: `uploaderId`, `status: 'ready'|'failed'`, `path`, `thumbPath`, `width`, `height`, `bytes`, `failure: null|'not_allowed'|'too_large'|'unsupported'|'error'`, `createdAt`.

`payments/{id}` adds (bookings only): `milestones: [{kind: 'shoot'|'delivery', amount, status: 'held'|'released'|'paid_out'|'refunded'|'disputed', releaseAfter|null, releasedAt|null, payoutId|null}]`, `payableAmount` (int). `bookings/{id}/milestones/{kind}` (read model, written only by `onPaymentWritten`): `kind`, `amount`, `status`, `releaseAfter|null`, `releasedAt|null`. `payouts/{id}.items[]` adds `milestone: 'shoot'|'delivery'|null`. `earnings/{uid}/items/{paymentId}` (one row per payment, as today) adds `heldAmount`, `soonAmount`, `receivedAmount` (ints; sum = row amount) and `milestonesDone`, `milestonesTotal` (int or null).

### Storage

- `deliveryUploads/{bookingId}/{uid}/{fileId}.jpg`: create only by `uid` when `uid == booking.photographerId` and `booking.status in ['shot','revision_requested']`, `jpegUpTo(2 * 1024 * 1024)` (the #147 helper: JPEG only, ≤ 2 MiB = `ImagePurpose.deliverySample.maxBytes`), `resource == null`; delete by `uid`; read and update: nobody.
- `deliveries/{bookingId}/{file}`: read by `booking.customerId` or `booking.photographerId`; write: nobody (Admin SDK). Objects carry `cacheControl: 'private, max-age=31536000, immutable'`.

### Domain (`packages/domain/src`)

```ts
// booking.ts
BOOKING_STATUSES adds 'shot', 'delivered', 'revision_requested', 'approved'
interface Booking adds: shotAt?, deliveredAt?, approvedAt?, checkUntil?, autoApproveAt?: string; deliveryRound?: number;
  revisionsIncluded?: number; revisionsUsed?: number; revisionsGranted?: number;
  extraRound?: ExtraRound | null; samplesPurgeAfter?: string | null; samplesPurged?: boolean;
// booking_ports.ts
interface ServiceRecord adds: readonly revisions?: number;
interface BookingTx adds:
  getDelivery(bookingId: string, round: number): Promise<DeliveryRound | null>;
  setDelivery(d: DeliveryRound): Promise<void>;
  getDeliverySamples(bookingId: string, fileIds: readonly string[]): Promise<(DeliverySample | null)[]>;
  deleteDeliverySamples(bookingId: string, fileIds: readonly string[]): Promise<void>;
  setPrivateDelivery(bookingId: string, p: PrivateDelivery): Promise<void>;
  getPrivateDelivery(bookingId: string): Promise<PrivateDelivery | null>;
interface BookingStore adds:
  findDueAutoApprovals(now: Date, limit?: number): Promise<readonly Booking[]>;  // status delivered, autoApproveAt <= now
  findDueChecks(now: Date, limit?: number): Promise<readonly Booking[]>;         // status approved, checkUntil <= now
// booking_machine.ts
TransitionAction adds 'mark_shot' | 'finish' ('complete' = alias of 'mark_shot')
// delivery.ts
export const DELIVERY_SAMPLES_MIN = 3, DELIVERY_SAMPLES_MAX = 20, REVISIONS_MAX = 5, DEFAULT_REVISIONS = 1;
export const AUTO_APPROVE_HOURS = 72, DELIVERY_CHECK_HOURS = 48, SHOOT_RELEASE_HOURS = 24, SAMPLE_RETENTION_DAYS = 90;
export const DELIVERY_LINK_MAX = 2000, DELIVERY_NOTE_MAX = 500, PHOTO_NOTE_MAX = 120, PHOTO_COUNT_MAX = 10000;
export interface DeliverySampleRef { fileId; path; thumbPath; width; height }
export interface DeliveryDecision { kind: 'approve' | 'request_revision'; note: string | null; photoNotes: readonly PhotoNote[]; at: string; auto: boolean; extra: boolean }
export interface DeliveryRound { bookingId; round; samples: readonly DeliverySampleRef[]; photoCount; linkHost; note: string | null; submittedAt; submittedBy; decision: DeliveryDecision | null }
export interface PrivateDelivery { link; round; unlockedAt: string | null; updatedAt }
export interface DeliverySample { fileId; uploaderId; status: 'ready' | 'failed'; path; thumbPath; width; height; bytes; failure: string | null }
export interface PhotoNote { sampleIndex: number; note: string }
export interface ExtraRound { status: 'pending' | 'granted' | 'declined'; at; note: string | null; photoNotes: readonly PhotoNote[] }
export function clampRevisions(v: unknown): number;
export function canDeliver(b: Booking, uid: string): boolean;                  // uid === b.photographerId
export function revisionAllowance(b: Booking): { used: number; total: number; left: number };
export function parseDeliveryUploadPath(path: string): { bookingId: string; uploaderId: string; fileId: string } | null;
export function watermarkLabel(name: string | null | undefined): string;   // `${name || 'Nhiếp ảnh gia'} · Bản xem trước`
export function validateSubmitDelivery(raw: unknown): { bookingId; sampleIds: string[]; link: string; linkHost: string; photoCount: number; note: string | null };
export function validateRevisionRequest(raw: unknown): { bookingId; note: string | null; photoNotes: PhotoNote[]; extra: boolean };
// delivery_use_cases.ts (all take BookingDeps)
export function submitDelivery(deps, callerId, raw): Promise<{ round: number }>;
export function approveDelivery(deps, input: { bookingId: string; actorId?: string /* undefined = system auto-approve */ }): Promise<Booking>;
export function requestRevision(deps, callerId, raw): Promise<Booking>;
export function answerExtraRound(deps, callerId, raw: { bookingId: string; grant: boolean }): Promise<Booking>;
// milestones.ts
export const MILESTONE_KINDS = ['shoot', 'delivery'] as const; export type MilestoneKind = …;
export const MILESTONE_STATUSES = ['held', 'released', 'paid_out', 'refunded', 'disputed'] as const;
export const DEFAULT_MILESTONE_PERCENTS: Readonly<Record<MilestoneKind, number>> = { shoot: 50, delivery: 50 };
export interface PaymentMilestone { kind; amount; status; releaseAfter: string | null; releasedAt: string | null; payoutId: string | null }
export function splitMilestones(net: number, shotAt: Date): PaymentMilestone[];
export function releaseMilestone(p: Payment, kind: MilestoneKind, ledgerEntryId: string, now: Date): { payment: Payment; ledgerEntry: LedgerEntry };
export function releaseDueMilestones(p: Payment, now: Date, newId: () => string): { payment: Payment; ledgerEntries: LedgerEntry[] };
export function disputeMilestone(p: Payment, kind: MilestoneKind, now: Date): Payment;
export function payableAmountOf(p: Payment): number;
export function aggregateEscrow(ms: readonly PaymentMilestone[]): EscrowStatus;
// escrow.ts: Payment adds milestones?: readonly PaymentMilestone[]; payableAmount?: number
// payout.ts: PayoutItem adds milestone?: MilestoneKind | null; isPayoutPayable handles milestones
// earnings.ts: EarningItem adds heldAmount, soonAmount, receivedAmount: number; milestonesDone, milestonesTotal: number | null
//   (earningItemOf keeps one row per payment; summarizeEarnings sums the three parts when present, else uses state + amount as today)
// errors.ts: ERROR_CODES adds 'not_ready'
// booking_sweeps.ts: BookingSweepResults { cleanedDrafts, expiredRequests, upcomingTransitions, autoShots, autoApprovals, finishedChecks, releasedEscrows }
```

### Callables (region `asia-southeast1`, `CALLABLE_OPTIONS`; errors in `details.code`)

| Name | Input | Output | Errors |
|---|---|---|---|
| `submitDelivery` | `{bookingId, sampleIds: string[], link, photoCount, note?}` | `{round}` | `invalid_argument`, `permission_denied` (not the provider, or a sample of someone else), `not_found`, `not_eligible` (status not `shot`/`revision_requested`), `not_ready` (a sample missing, failed or not processed yet), `conflict` |
| `approveDelivery` | `{bookingId}` | `{status: 'approved'}` | `permission_denied` (not the customer), `not_found`, `not_eligible` (not `delivered`), `conflict` |
| `requestRevision` | `{bookingId, note?, photoNotes?: [{sampleIndex, note}], extra?: bool}` | `{status}` | `invalid_argument` (empty request, bad index, long note), `permission_denied`, `not_found`, `not_eligible` (not `delivered`; no round left without `extra`; `extra` while rounds are left), `conflict` (extra already pending) |
| `answerExtraRound` | `{bookingId, grant: bool}` | `{status}` | `permission_denied` (not the provider), `not_found`, `not_eligible` (nothing pending), `conflict` |
| `transitionBooking` (exists) | `{bookingId, action: 'mark_shot', …}` | booking | as today |
| `openDispute` (exists) | `{bookingId, reason}` | booking | as today, with the new allowed states (Decision 8) |

Error table (`callables/errors.ts`): `not_ready → 'failed-precondition'`.

### Triggers and jobs

- `onDeliveryUpload`: `onObjectFinalized({ region: REGION, memory: '1GiB', cpu: 1, concurrency: 1, timeoutSeconds: 60, maxInstances: 10, retry: false })`; ignores any path not matching `parseDeliveryUploadPath`.
- `bookingClock` (exists, every 15 min): `runBookingSweeps` (drafts, expire, upcoming, auto mark-shot, **auto-approve**, **finish checks**, release due milestones/escrows) then **purge samples** (Functions-only step, ≤ 50 bookings per run).

### Indexes (`firestore.indexes.json`)

`bookings (status ASC, autoApproveAt ASC)`, `bookings (status ASC, checkUntil ASC)`, `payments (payeeId ASC, payableAmount ASC)`; `samplesPurgeAfter` and `payableAmount` single-field ranges use automatic indexes.

### Rules (`firestore.rules`)

```
match /bookings/{bookingId} {
  function bk() { return get(/databases/$(database)/documents/bookings/$(bookingId)).data; }
  function isParty() { return signedIn() && (bk().customerId == request.auth.uid || bk().photographerId == request.auth.uid); }
  match /private/{docId} {
    allow read: if signedIn() && (
      (docId == 'contact'
        && (bk().customerId == request.auth.uid
            || (bk().photographerId == request.auth.uid && isBookingContactUnlocked(bk()))))
      || (docId == 'delivery'
        && (bk().photographerId == request.auth.uid
            || (bk().customerId == request.auth.uid && bk().status in ['approved', 'completed']))));
    allow write: if false;
  }
  match /deliveries/{round} { allow read: if isParty(); allow write: if false; }
  match /deliverySamples/{fileId} { allow read: if signedIn() && bk().photographerId == request.auth.uid; allow write: if false; }
  match /milestones/{kind} { allow read: if isParty(); allow write: if false; }
}
```
`isBookingContactUnlocked(b)` adds `'shot', 'delivered', 'revision_requested', 'approved'` to the always-unlocked list.

### App (`lib/data`, `lib/features`)

```dart
// lib/data/booking/booking_status.dart: BookingStatus adds shot, delivered, revisionRequested ('revision_requested'), approved
//   (fromFirestore maps 'revision_requested' → revisionRequested; keep the draft fallback for unknown codes)
// lib/data/booking/booking.dart: Booking adds DateTime? shotAt, deliveredAt, approvedAt, checkUntil, autoApproveAt;
//   @Default(0) int deliveryRound; @Default(1) int revisionsIncluded; @Default(0) int revisionsUsed; @Default(0) int revisionsGranted;
//   ExtraRound? extraRound; @Default(false) bool samplesPurged;
// lib/data/booking/booking_repository.dart: BookingAction adds markShot (code 'mark_shot'); complete removed
// lib/data/delivery/delivery.dart
class DeliverySampleRef { fileId, path, thumbPath, width, height }
class DeliveryDecision { kind ('approve'|'request_revision'), note, photoNotes, at, auto, extra }
class DeliveryRound { bookingId, round, samples, photoCount, linkHost, note, submittedAt, submittedBy, decision }
class DeliveryLink { link, round, unlockedAt }
enum SampleStatus { ready, failed }
class StagedSample { fileId, status, path?, thumbPath?, failure? }
class PhotoNote { sampleIndex, note }
class ExtraRound { status ('pending'|'granted'|'declined'), at, note, photoNotes }
// lib/data/delivery/delivery_repository.dart
abstract class DeliveryRepository {
  Stream<List<DeliveryRound>> watchRounds(String bookingId);              // deliveries ordered by round desc, limit 5 (listener)
  Stream<DeliveryLink?> watchLink(String bookingId);                      // only subscribe when allowed (provider, or customer at approved/completed)
  Stream<List<StagedSample>> watchStagedSamples(String bookingId);       // provider only
  Stream<UploadEvent> uploadSample({required String bookingId, required String uploaderId, required String fileId, required PickedImage image});
  Future<void> discardSample({required String bookingId, required String uploaderId, required String fileId}); // deletes the upload if still there; staged files go with the purge
  Future<int> submit({required String bookingId, required List<String> sampleIds, required String link, required int photoCount, String? note});
  Future<void> approve(String bookingId);
  Future<void> requestRevision({required String bookingId, String? note, List<PhotoNote> photoNotes = const [], bool extra = false});
  Future<void> answerExtraRound({required String bookingId, required bool grant});
  Future<String> imageUrl(String storagePath);                            // MediaUrlResolver
}
final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) => FirestoreDeliveryRepository());
final deliveryRoundsProvider = StreamProvider.autoDispose.family<List<DeliveryRound>, String>(…);
final deliveryLinkProvider = StreamProvider.autoDispose.family<DeliveryLink?, String>(…);
final stagedSamplesProvider = StreamProvider.autoDispose.family<List<StagedSample>, String>(…);
// lib/data/media (from #147, not changed here): MediaUploader.upload(PickedImage image, {required String storagePath, required ImagePurpose purpose});
//   uploadSample calls it with ImagePurpose.deliverySample; UploadedMedia carries width, height, sizeBytes
// lib/data/earnings/earnings.dart: EarningItem adds int? milestonesDone, int? milestonesTotal (skip if #134 already added them)
```

`DeliveryErrorCode { notReady, notEligible, conflict, permissionDenied, notFound, invalidArgument, network, unknown }` + `deliveryErrorOf(Object e)` (same mapping style as `bookingErrorOf`).

Routes (in `bookingDetailRoutes()`): `/b/:id/delivery` → `DeliveryReviewScreen(bookingId)` (S05.06). Sheets (no route): `showSubmitDeliverySheet(context, booking)` (S06.07), `showRevisionSheet(context, booking, round, {extra})` (S05.07), `showReportDeliverySheet(context, booking)` (report), `showApproveDeliverySheet(context)` (confirm).

### l10n (`lib/l10n/app_vi.arb`, exact Vietnamese)

Statuses: `statusShot` "Chờ bàn giao"; `statusDelivered` "Chờ duyệt ảnh"; `statusRevisionRequested` "Cần chỉnh sửa"; `statusApproved` "Đã đồng ý ảnh".
Timeline: `timelineDelivery` "Bàn giao & duyệt ảnh"; `timelineDeliveryWaitCustomer` "Chờ {name} gửi ảnh mẫu"; `timelineDeliveryWaitProvider` "Chờ bạn nộp ảnh mẫu và link ảnh gốc"; `timelineDeliveryReviewCustomer` "Vòng {round} · chờ bạn duyệt"; `timelineDeliveryReviewProvider` "Vòng {round} · chờ khách duyệt"; `timelineDeliveryRevisingCustomer` "{name} đang chỉnh sửa vòng {round}"; `timelineDeliveryRevisingProvider` "Khách muốn chỉnh sửa vòng {round}"; `timelineDeliveryApproved` "Đã đồng ý ảnh · {when}"; `timelineCheck` "Kiểm tra bộ ảnh gốc trong 48 giờ".
S05.02: `detailMarkShot` "Đã chụp xong"; `detailDeliver` "Nộp bàn giao"; `detailDeliverRound` "Nộp vòng {round}"; `detailViewDelivery` "Xem bàn giao"; `detailRevisionCard` "Khách muốn chỉnh sửa vòng {round}"; `detailWaitingApproval` "Đã gửi vòng {round} · chờ khách duyệt"; `detailApprovedProvider` "Khách đã đồng ý ảnh; tiền chuyển sau 48 giờ kiểm tra"; `detailExtraRoundTitle` "{name} xin thêm 1 vòng sửa"; `detailExtraRoundUsed` "Đã dùng hết {total} lượt sửa miễn phí của gói."; `detailExtraGrant` "Cho thêm 1 vòng"; `detailExtraDecline` "Không thêm"; `detailExtraDeclineTitle` "Không thêm vòng sửa?"; `detailExtraDeclineBody` "{name} vẫn đồng ý ảnh được, hoặc mở khiếu nại."; `detailExtraGranted` "Đã cho thêm 1 vòng sửa"; `detailExtraDeclined` "Đã báo khách là không thêm vòng".
S06.01: `workToDeliver` "Chờ bàn giao"; `workToDeliverShot` "{day} · đã chụp"; `workToDeliverRevision` "Vòng {round} · khách muốn chỉnh sửa"; `workToDeliverExtra` "Khách xin thêm 1 vòng".
S06.07: `deliverySubmitTitle` "Nộp bàn giao · vòng {round}"; `deliverySamplesHint` "3–20 ảnh mẫu · tự đóng watermark khi tải lên"; `deliveryAddSample` "Thêm ảnh mẫu"; `deliverySampleProcessing` "Đang đóng watermark"; `deliverySampleFailed` "Lỗi · thử lại"; `deliverySampleRemove` "Bỏ ảnh này"; `deliveryLinkLabel` "Link bộ ảnh gốc"; `deliveryLinkInvalid` "Dán link http(s) hợp lệ"; `deliveryCountLabel` "Số ảnh gốc"; `deliveryCountInvalid` "Nhập số ảnh gốc"; `deliveryNoteLabel` "Ghi chú · tuỳ chọn"; `deliveryLockNote` "Khách chỉ thấy link sau khi đồng ý ảnh mẫu"; `deliverySubmit` "Nộp bàn giao"; `deliveryNeedSamples` "Cần ít nhất 3 ảnh mẫu"; `deliveryTooManySamples` "Tối đa 20 ảnh mẫu"; `deliveryWaitProcessing` "Đợi ảnh mẫu đóng watermark xong"; `deliveryCustomerNotes` "Khách muốn chỉnh sửa"; `deliverySubmitted` "Đã nộp vòng {round}"; `deliveryNotReady` "Ảnh mẫu đang xử lý, đợi một chút rồi nộp lại.".
S05.06: `deliveryTitleRound` "Bàn giao · vòng {round}"; `deliveryTitleApproved` "Bàn giao · đã đồng ý"; `deliverySentBy` "{name} gửi {count} ảnh mẫu · {date}"; `deliveryAwaitingYou` "Chờ bạn duyệt"; `deliveryOriginals` "Bộ ảnh gốc · {count} ảnh"; `deliveryLinkLocked` "Mở khi bạn đồng ý ảnh"; `deliveryLinkMasked` "{host}/••••••••"; `deliveryLinkLockedSemantics` "Link bộ ảnh gốc đang bị che"; `deliveryRoundsLeft` "Còn {left}/{total} lượt sửa miễn phí"; `deliveryNoRoundsLeft` "Hết lượt sửa miễn phí ({total}/{total})"; `deliveryAutoApproveIn` "Tự đồng ý sau {time} nếu bạn không phản hồi"; `deliveryRequestRevision` "Yêu cầu chỉnh sửa"; `deliveryAskExtra` "Xin thêm 1 vòng"; `deliveryExtraPending` "Đã xin thêm 1 vòng · chờ {name} trả lời"; `deliveryExtraDeclined` "{name} không thêm vòng sửa"; `deliveryApprove` "Đồng ý ảnh"; `deliveryApproveTitle` "Đồng ý ảnh?"; `deliveryApproveBody` "Đồng ý thì link ảnh gốc mở ra; bạn có 48 giờ để kiểm tra."; `deliveryApproveKeep` "Xem lại"; `deliveryApprovedToast` "Bạn đã đồng ý ảnh lúc {time}. Link bộ ảnh gốc đã mở."; `deliverySentOn` "{name} gửi {date}"; `deliveryOpenOriginals` "Mở bộ ảnh gốc"; `deliveryCheckTitle` "Kiểm tra bộ ảnh gốc trong 48 giờ:"; `deliveryCheckHours` "còn {hours} giờ"; `deliveryCheckMinutes` "còn {minutes} phút"; `deliveryCheckHint` "Thiếu ảnh, link hỏng hay ảnh khác bản mẫu? Báo trong thời gian này, đợt thanh toán thứ hai vẫn được giữ."; `deliveryCheckOver` "Đã hết thời gian kiểm tra"; `deliveryReport` "Báo vấn đề với ảnh gốc"; `deliveryReviewShoot` "Đánh giá buổi chụp"; `deliverySamplesPurged` "Ảnh mẫu đã xoá sau 90 ngày"; `deliverySampleSemantics` "Ảnh mẫu {index}"; `deliveryWaiting` "Chưa có ảnh mẫu"; `durationDaysHours` "{days} ngày {hours} giờ".
Report sheet: `reportTitle` "Báo vấn đề với ảnh gốc?"; `reportMissing` "Thiếu ảnh so với gói"; `reportDifferent` "Ảnh khác bản mẫu"; `reportBrokenLink` "Link hỏng hoặc không mở được"; `reportOther` "Lý do khác"; `reportHold` "Đợt thanh toán thứ hai được giữ tới khi hỗ trợ xử lý xong."; `reportSend` "Báo vấn đề"; `reportBack` "Quay lại"; `reportDone` "Đã báo vấn đề. Hỗ trợ sẽ liên hệ bạn.".
S05.07: `revisionTitle` "Yêu cầu chỉnh sửa"; `revisionCount` "{count} ảnh"; `revisionTapHint` "Chạm ảnh để sửa ghi chú riêng của ảnh đó."; `revisionGeneralNote` "Ghi chú chung"; `revisionRoundOf` "Vòng sửa {round}/{total} (miễn phí)"; `revisionSend` "Gửi yêu cầu"; `revisionExtraTitle` "Xin thêm 1 vòng"; `revisionExtraHint` "Hết lượt sửa miễn phí. {name} có thể cho thêm hoặc không."; `revisionExtraSend` "Gửi đề nghị"; `revisionNeedSomething` "Chọn ảnh hoặc ghi chú điều cần sửa"; `revisionChipSkin` "Da sáng hơn"; `revisionChipWarm` "Bớt vàng"; `revisionChipRemove` "Xoá vật thể"; `revisionChipLevel` "Cân lại nghiêng"; `revisionPhotoNote` "Ghi chú cho ảnh {index}"; `revisionSent` "Đã gửi yêu cầu chỉnh sửa"; `revisionExtraSent` "Đã gửi đề nghị thêm 1 vòng".
S06.05 (same keys as #134's plan; add only if absent): `earningsMilestones` "mốc {done}/{total}"; `earningsMilestonesAll` "đủ {total} mốc".

## Review Focus

1. **The customer reads the original link before approving** (a stale listener, a deep link to `/b/:id/delivery`, or a rules gap) — the link must exist only in `private/delivery`, never in the round doc, and the rule must check `status in ['approved','completed']`. Pinned: Task 4 rules tests and `the round doc has linkHost and no link`; Task 8 `the customer never subscribes to the link before approved`.
2. **A clean sample escaping** — the upload must be deleted on success, on failure and on a refused path (wrong uploader, wrong status, too large), and no client may read `deliveryUploads/**`. Pinned: Task 5 `deletes the clean upload in every outcome`; Task 4 storage rules tests.
3. **Fields wiped by the whole-document booking write** — `bookingToFirestore` uses `set`, so any new field it does not map (`deliveryRound`, `revisionsUsed`, `checkUntil`, `extraRound`, `samplesPurgeAfter`…) is erased by the next unrelated transition (chat id, review, dispute). Pinned: Task 4 `booking mapping round-trips every delivery field`.
4. **Money released twice, or released while disputed** — a retried sweep, a `finish` racing a "Báo vấn đề", or a payout batch built while a milestone is disputed. Pinned: Task 3 `releaseDueMilestones is idempotent`, `finish skips a disputed booking`, `a disputed milestone is not payable`; Task 4 `the clock run twice releases once`.
5. **Submitting with samples still processing or from an old round** — `submitDelivery` must refuse a missing/failed/foreign sample with `not_ready`/`permission_denied` and consume the used samples so a later round cannot reuse them. Pinned: Task 2 `refuses an unprocessed sample with not_ready`, `samples are consumed by the round`; Task 7 `the submit button waits for every tile`.

## Chi phí Google

Unit prices from `docs/superpowers/specs/2026-10-07-google-cloud-costs.md` (Firestore nam5 upper bound, Singapore "chưa xác nhận"; Functions Tier 2 $0.0000336/vCPU‑s, $0.0000035/GiB‑s; Storage $0.020/GB‑month; egress $0.12/GB "giả định, chưa xác nhận"). Volumes: 300 bookings/month at (b) 1,000 MAU, 3,000 at (c) 10,000 MAU (§12); assume 10 samples per round, 1.3 rounds per booking → 13 samples/booking.

- **Per user action (Firestore).** Provider uploads 13 samples: 13 sample-doc writes by the trigger + 13 reads (booking get in the trigger) + a listener on `deliverySamples` while the sheet is open (~13 reads, closed with the sheet). Submit: callable transaction reads booking + 13 sample docs (`getAll`) + private (≈ 15 reads), writes booking, round, private, event (4) + 13 deletes. Customer opens S05.06: booking listener (exists) + rounds listener (limit 5, ≈ 1–2 reads) + link `get`/listener after approval (1). Approve / revise / extra / answer: 2–3 reads, 3–4 writes each. Clock: three extra queries per run (auto-approve, finish, purge) ≈ 3 reads minimum × 2,880 runs = 8,640 reads/month. Milestones: 4 payment writes per booking (split, shoot release, delivery release, payout) each followed by the existing `onPaymentWritten` (+2 milestone read-model writes) — included in the per-booking writes below. Per booking ≈ 70 reads, 40 writes, 15 deletes → (b) 21k reads, 12k writes, 4.5k deletes ≈ $0.04; (c) 210k reads ($0.13), 120k writes ($0.22), 45k deletes ($0.01) ≈ $0.36.
- **New functions.** 4 callables (+ `mark_shot` through the existing `transitionBooking`): ≈ 3 calls/booking → 900/month (b), 9,000/month (c), 256 MiB, 10 s. Storage trigger `onDeliveryUpload`: 1 per sample → 3,900 (b), 39,000 (c); 1 GiB, 1 vCPU, 60 s timeout, ≈ 1.2 s each → 4,680 vCPU‑s + 4,680 GiB‑s (b) ≈ $0.17 (inside the free tier if the rest of the app leaves room), 46,800 vCPU‑s + 46,800 GiB‑s (c) ≈ $1.57 + $0.16 = $1.73. Invocations far under 2 M free.
- **Scheduled jobs.** None new: the steps run inside `bookingClock` (every 15 min, 2,880 runs/month, unchanged schedule); no extra Cloud Scheduler job.
- **Storage.** `deliveryUploads/` (clean, ≈ 250 KB after the phone-side `deliverySample` compression, ≤ 2 MiB, deleted within seconds; ingress free). `deliveries/` per sample: 250 KB (1600 px q75) + 30 KB thumbnail = 280 KB → 3.6 MB/booking → +1.1 GB/month (b), +11 GB/month (c); purged 90 days after completion → steady ≈ 3.5 GB (b) $0.07, ≈ 35 GB (c) $0.70. Egress: grids load thumbnails (13 × 30 KB × ~4 opens × 1.3 rounds ≈ 2 MB), full screen ≈ 13 × 250 KB × 1.3 ≈ 4.2 MB, provider staging ≈ 0.4 MB; with `cached_network_image` and `immutable` cache headers ≈ 5 MB/booking → 1.5 GB (b) $0.18, 15 GB (c) $1.80.
- **Paid APIs.** None (no Vision, no Maps, no SMS). `sharp` adds ≈ 35 MB to the functions build; with one image per function and no cleanup policy Artifact Registry grows (≈ $0.10/GB‑month, "chưa xác nhận"): apply `firebase functions:artifacts:setpolicy` (cost spec §3).
- **Conclusion:** ≈ **+$0.46/month at (b)** (≈ +$0.30 if the watermark CPU stays in the free tier) and ≈ **+$4.6/month at (c)** (storage $0.70, egress $1.80, watermark CPU $1.73, Firestore $0.36). Under $5 at (c) thanks to the mitigations already in the design: 400 px thumbnails in every grid, 90‑day purge, immutable cache headers + `cached_network_image`, 20‑sample cap, one-pass `sharp` pipeline at 1 vCPU with `concurrency: 1`.

## Tasks

### Task 1: Spec and mock first (owner decisions, missing frames)

**Files:**
- Modify: `docs/superpowers/specs/2026-10-06-delivery-preview-unlock-design.md`, `docs/design/ui-mock.html`, `docs/superpowers/specs/2026-10-01-remaining-screens.md` (§2 rows S05.02, S05.06, S05.07, S06.01, S06.07: "plan `2026-10-07-s05-delivery-two-layer.md`"), `docs/superpowers/specs/screens/booking.md` (S05.02 provider/customer delivery actions, S05.06, S05.07), `docs/superpowers/specs/screens/photographer.md` (S06.01 section, S06.07)

- [ ] **Step 1: Spec.** In the delivery spec: status "đang làm (#130)"; add to §2 rows B7 "Watermark do **server** đóng: thợ tải bản sạch lên vùng tạm chỉ thợ ghi được (`deliveryUploads/{bookingId}/{uid}/{fileId}.jpg`), Function đóng watermark vào `deliveries/{bookingId}/` rồi **xoá bản sạch ngay**", B8 "**Không bao giờ** đóng watermark trên máy khách; bản sạch không tới máy khách", B9 "Ảnh mẫu nén cạnh dài 1600 px, JPEG q75, bỏ EXIF; thêm ảnh thu nhỏ 400 px cho lưới", B10 "Storage rules: chỉ JPEG, ≤ 2 MiB mỗi ảnh tải lên (`jpegUpTo(2 * 1024 * 1024)`, mục đích ảnh `deliverySample` của #147); chỉ hai bên booking đọc `deliveries/`"; in §3 remove `sampleOriginals`, add `linkHost`, `deliverySamples`, thumbnails, the 90‑day purge, the extra-round record and the milestone fields (Decisions 7, 9, 10); §4 add Decisions 5, 6, 8; §5 S06.07 "server tự đóng watermark sau khi tải lên", per-tile states; §7 "bản sạch không giữ lại"; §9 add rules for `deliveryUploads` and a test that the clean copy is deleted. Keep Vietnamese prose.
- [ ] **Step 2: Mock frames** (follow existing `.step` + `.phone` + `.cap` frames, Material Symbols `<span class="ms">`, existing classes; ids exactly):
  - `S05.02-delivered` (customer): bar "Buổi chụp #A1F3"; card "Minh Trí · Chân dung 2 giờ" / "T7 12/10 · 15:30–17:30" / badge `b-pen` "Chờ duyệt ảnh"; timeline done "Đã gửi & thanh toán", "Đã xác nhận", "Sắp tới · T7 12/10", "Buổi chụp"; now "Bàn giao & duyệt ảnh" / "Vòng 1 · chờ bạn duyệt"; upcoming "Hoàn thành", "Đánh giá & chia sẻ ảnh"; row "Nhắn tin" + Liên hệ dial; foot `btn pri` "Xem bàn giao". Caption: "Đã chụp: dòng 'Chờ Minh Trí gửi ảnh mẫu', không có nút chính. Cần chỉnh sửa: 'Minh Trí đang chỉnh sửa vòng 1', nút viền 'Xem bàn giao'. Đã đồng ý ảnh: nút chính 'Đánh giá', nút viền 'Xem bàn giao'."
  - `S05.02-shot` (provider): bar "Buổi chụp #A1F3"; card "Lan Anh · Chân dung 2 giờ" / "T7 12/10 · đã chụp" / badge `b-warn` "Chờ bàn giao"; now step "Bàn giao & duyệt ảnh" / "Chờ bạn nộp ảnh mẫu và link ảnh gốc"; foot `btn pri` "Nộp bàn giao". Caption: "Sau giờ kết thúc mà chưa bấm: nút chính 'Đã chụp xong' (tự chuyển sau 24 giờ). Khách yêu cầu sửa: thẻ 'Khách muốn chỉnh sửa vòng 1' với ghi chú, nút chính 'Nộp vòng 2'. Đã nộp: dòng 'Đã gửi vòng 1 · chờ khách duyệt'. Đã đồng ý: 'Khách đã đồng ý ảnh; tiền chuyển sau 48 giờ kiểm tra'. Booking studio: chỉ tài khoản studio thấy nút này."
  - `S05.02-extra-round` (provider): card (`warnc` style, `info` icon) "Lan Anh xin thêm 1 vòng sửa" + meta "3 ảnh · Tông màu ấm hơn một chút"; meta x "Đã dùng hết 2 lượt sửa miễn phí của gói."; foot `btn out` "Không thêm" + `btn pri` "Cho thêm 1 vòng". Caption: "'Không thêm' mở sheet xác nhận 'Không thêm vòng sửa?' / 'Lan Anh vẫn đồng ý ảnh được, hoặc mở khiếu nại.'"
  - `S05.06-no-rounds` (customer): as `S05.06` but row "Hết lượt sửa miễn phí (2/2)" + "Gói Cưới 4 giờ"; foot `btn out` "Xin thêm 1 vòng" + `btn pri` "Đồng ý ảnh". Caption: "Đã xin: dòng 'Đã xin thêm 1 vòng · chờ Minh Trí trả lời', nút viền ẩn. Bị từ chối: 'Minh Trí không thêm vòng sửa'. 'Xin thêm 1 vòng' mở S05.07 ở chế độ 'Xin thêm 1 vòng', nút 'Gửi đề nghị'."
  - `S05.06-report` (sheet over `S05.06-approved`; skip it when the mock already has `#S18.01-delivery` from #142, Decision 15c): `h3` "Báo vấn đề với ảnh gốc?"; four `.opt` radios "Thiếu ảnh so với gói" (on), "Ảnh khác bản mẫu", "Link hỏng hoặc không mở được", "Lý do khác"; meta x "Đợt thanh toán thứ hai được giữ tới khi hỗ trợ xử lý xong."; row `btn out` "Quay lại" + `btn dng` "Báo vấn đề".
  - `S06.01-deliver`: S06.01 top as the existing frame, then `sec` "Chờ bàn giao" with count "2"; cards "Lan Anh · Chân dung 2 giờ" / "T7 12/10 · đã chụp" / `b-warn` "Chờ bàn giao" and "Quang Huy · Cặp đôi 3 giờ" / "Vòng 2 · khách muốn chỉnh sửa" / `b-warn` "Cần chỉnh sửa".
  - Captions of `#S06.07` ("app tự đóng watermark" → "server tự đóng watermark sau khi tải lên; ô ảnh có bốn trạng thái: đang tải, đang đóng watermark, xong, lỗi · thử lại") and `#S05.06` (add "Sau 90 ngày kể từ khi hoàn thành, ảnh mẫu được xoá: 'Ảnh mẫu đã xoá sau 90 ngày'").
- [ ] **Step 3:** Check the mock still parses (open the file in the Browser pane if available, or `python3 -c "import html.parser,sys; html.parser.HTMLParser().feed(open('docs/design/ui-mock.html').read())"`), every new id is unique, every new `data-code` is an existing code (variants only; `lib/core/screen_codes.dart` unchanged). If a test compares mock ids with `ScreenCodes` (`grep -rn "ui-mock" app_flutter/test`), run it.
- [ ] **Step 4: Commit** `docs(design): delivery owner decisions and missing S05.02/S05.06/S06.01 frames [#130]`.

### Task 2: Domain — delivery machine and use cases

**Files:**
- Create: `packages/domain/src/delivery.ts`, `delivery_use_cases.ts`; tests `packages/domain/test/delivery.test.ts`, `delivery_use_cases.test.ts`
- Modify: `booking.ts`, `booking_ports.ts`, `booking_machine.ts`, `commit_transition.ts` (`shot`, `completed` via `finish`), `booking_sweeps.ts` (auto mark-shot, auto-approve, finish), `create_booking.ts` (`revisionsIncluded`), `memory_booking_store.ts` (new tx methods and queries), `open_dispute.ts`, `contact.ts`, `review.ts` (`isReviewable` adds `approved`), `errors.ts` (`not_ready`), `index.ts` (exports), `test/support/booking_world.ts`; tests `booking_machine.test.ts`, `booking_sweeps.test.ts`, `create_booking.test.ts`, `contact.test.ts`, `submit_review.test.ts`, `transition_booking.test.ts` (the open-dispute tests live where they are today; grep `openDispute`)

**Interfaces:**
- Consumes: `Booking`, `BookingDeps`, `decideTransition`, `commitTransition`, `DomainError`, `isId`, `graphemeCount`, `parseVnDateTime`.
- Produces: Contract → Domain except `milestones.ts` (Task 3). In this task `commitTransition` sets `shotAt` on `shot` and `completedAt` + `samplesPurgeAfter = now + 90 d` on `completed`, and leaves payments untouched for `shot`/`finish` (Task 3 adds the split and the release).

- [ ] **Step 1:** Contract check of the domain names; ledger differences.
- [ ] **Step 2: Failing tests.**
  - machine: `photographer mark_shot after the end moves upcoming to shot`; `mark_shot before the end is not_eligible`; `complete is an alias of mark_shot`; `system mark_shot needs end + 24 h`; `finish moves approved to completed after checkUntil`; `finish before checkUntil is conflict`; `finish on a disputed escrow is not_eligible`; `customer cannot finish`.
  - delivery: `validateSubmitDelivery accepts 3 and 20 samples, refuses 2 and 21`; `refuses duplicate sample ids`; `refuses ftp://, a link without a host dot, a link with spaces and a 2,001-char link`; `linkHost is the URL host`; `photoCount must be 1..10000 integer`; `note over 500 graphemes is invalid`; `validateRevisionRequest refuses an empty request`; `refuses a photo note over 120 graphemes and a duplicate index`; `parseDeliveryUploadPath accepts deliveryUploads/b1/u1/{ULID}.jpg and refuses other prefixes, extra segments and non-ULID names`; `watermarkLabel falls back to "Nhiếp ảnh gia · Bản xem trước"`; `clampRevisions: undefined → 1, 7 → 5, -1 → 0, 2.5 → 2`; `revisionAllowance adds granted rounds`.
  - use cases: `submitDelivery round 1 from shot` (round doc with samples, photoCount, linkHost, **no link field**; private link written; booking `delivered`, `deliveryRound 1`, `deliveredAt`, `autoApproveAt = now + 72 h`); `submitDelivery from revision_requested opens round 2 and resets autoApproveAt`; `refuses a caller who is not booking.photographerId with permission_denied`; `refuses status upcoming with not_eligible`; `refuses an unprocessed sample with not_ready` (missing doc and `failed` doc); `refuses a sample uploaded by someone else with permission_denied`; `samples are consumed by the round` (sample docs deleted in the same transaction); `approveDelivery by the customer` (status `approved`, `approvedAt`, `checkUntil = +48 h`, `autoApproveAt` null, decision `{kind approve, auto false}`, private `unlockedAt` set, a pending `extraRound` cleared to null); `system approve records auto true`; `approve from revision_requested is not_eligible`; `requestRevision with rounds left` (`revision_requested`, `revisionsUsed + 1`, decision `request_revision` with notes, `autoApproveAt` null); `requestRevision without rounds left is not_eligible`; `extra request with rounds left is not_eligible`; `extra request stores a pending extraRound and keeps delivered`; `a second extra request while pending is conflict`; `answerExtraRound grant` (`revisionsGranted + 1`, `revisionsUsed + 1`, `revision_requested`, decision `extra true`, `extraRound.status granted`); `answerExtraRound decline` (`extraRound.status declined`, status `delivered`); `answer by the customer is permission_denied`; `answer with nothing pending is not_eligible`.
  - sweeps: `auto mark-shot after end + 24 h` (counter `autoShots`); `auto-approve a delivered booking past autoApproveAt` (`autoApprovals`); `finish an approved booking past checkUntil` (`finishedChecks`, `samplesPurgeAfter = +90 d`); `a failing item does not stop the batch`.
  - others: `createBookingDraft snapshots revisionsIncluded from the service, default 1`; `contact stays unlocked in shot, delivered, revision_requested and approved`; `openDispute accepts shot within 24 h of shotAt and approved before checkUntil, refuses approved after checkUntil`; `isReviewable is true for approved and completed` (and `submitReview` on an approved booking succeeds, status stays `approved`).
- [ ] **Step 3:** `cd packages/domain && npm test` — new tests fail.
- [ ] **Step 4: Implement.** Use-case shape (all reads before writes, like `MemoryBookingStore` enforces):
  ```ts
  export async function submitDelivery(deps: BookingDeps, callerId: string, raw: unknown): Promise<{ round: number }> {
    const input = validateSubmitDelivery(raw);
    const now = deps.clock.now(); const at = now.toISOString();
    return deps.store.runTransaction(async (tx) => {
      const b = await tx.getBooking(input.bookingId);
      if (!b) throw new DomainError('not_found');
      if (!canDeliver(b, callerId)) throw new DomainError('permission_denied');
      if (b.status !== 'shot' && b.status !== 'revision_requested') throw new DomainError('not_eligible');
      const samples = await tx.getDeliverySamples(b.id, input.sampleIds);
      if (samples.some((s) => s !== null && s.uploaderId !== callerId)) throw new DomainError('permission_denied');
      if (samples.some((s) => s === null || s.status !== 'ready')) throw new DomainError('not_ready');
      const round = (b.deliveryRound ?? 0) + 1;
      await tx.setDelivery({ bookingId: b.id, round, samples: samples.map(toRef), photoCount: input.photoCount,
        linkHost: input.linkHost, note: input.note, submittedAt: at, submittedBy: callerId, decision: null });
      await tx.setPrivateDelivery(b.id, { link: input.link, round, unlockedAt: null, updatedAt: at });
      await tx.deleteDeliverySamples(b.id, input.sampleIds);
      await tx.setBooking({ ...b, status: 'delivered', deliveryRound: round, deliveredAt: at,
        autoApproveAt: new Date(now.getTime() + AUTO_APPROVE_HOURS * 3_600_000).toISOString(),
        version: b.version + 1, updatedAt: at });
      await tx.addBookingEvent({ id: deps.ids.newId(), bookingId: b.id, status: 'delivered', at, actorId: callerId });
      return { round };
    });
  }
  ```
  `approveDelivery` reads the current round with `tx.getDelivery(b.id, b.deliveryRound)` and the private doc before writing. `finish` goes through `decideTransition` + `commitTransition`.
- [ ] **Step 5:** `npm test && npm run lint` green (incl. `purity.test.ts`).
- [ ] **Step 6: Commit** `feat(domain): two-layer delivery machine, rounds, extra round and auto-approve [#130]`.

### Task 3: Domain — two milestones on the fake rails (release, payouts, earnings)

**Files:**
- Create: `packages/domain/src/milestones.ts`, `packages/domain/test/milestones.test.ts`
- Modify: `escrow.ts` (`Payment.milestones`, `payableAmount`), `commit_transition.ts` (split at `shot`, release `delivery` at `completed`), `booking_sweeps.ts` (step 5 milestone-aware), `open_dispute.ts` (milestone dispute), `payout.ts`, `payout_use_cases.ts`, `payout_ports.ts` (doc comment of `listPayablePayments`), `earnings.ts`, `refresh_earnings.ts`, `memory_payout_store.ts`, `memory_earnings_store.ts`, `index.ts`; tests `escrow.test.ts`, `booking_sweeps.test.ts`, `payout_use_cases.test.ts`, `earnings.test.ts`, `refresh_earnings.test.ts`

**Interfaces:**
- Consumes: Task 2 (`shot`, `finish`, `shotAt`, `checkUntil`).
- Produces: Contract → Domain `milestones.ts`, `PayoutItem.milestone`, `EarningItem.heldAmount/soonAmount/receivedAmount/milestonesDone/milestonesTotal`.

- [ ] **Step 1:** Contract check (payments, payouts, earnings); ledger differences.
- [ ] **Step 2: Failing tests.**
  - `splitMilestones(1_500_001, shotAt)` → shoot 750,000 (`releaseAfter = shotAt + 24 h`), delivery 750,001 (`releaseAfter` null); amounts sum to net.
  - `mark_shot splits the held payment` (net = amount − refunds; `payment.releaseAfter = shoot.releaseAfter`; `escrowStatus` stays `held`).
  - `the step-5 sweep releases the shoot milestone after 24 h` (one `escrow_released` ledger entry of 750,000; `payableAmount 750,000`; aggregate `held` because delivery is held; booking mirror `escrowStatus held`).
  - `releaseDueMilestones is idempotent` (second run: no entry).
  - `finish releases the delivery milestone in the same transaction` (second `escrow_released`; aggregate `released`; `payableAmount` = unbatched released total).
  - `finish skips a disputed booking` (no release, status stays `approved`).
  - `openDispute on approved disputes only the delivery milestone`; `a disputed milestone is not payable`; `aggregateEscrow precedence: disputed > held > released > paid_out; all refunded → refunded`.
  - payouts: `createPayout batches released milestones as separate items with milestone kind`; `the shoot milestone is paid while delivery is still held`; `executePayout marks only the batched milestones paid_out and writes one payout_paid per item`; `a failed payout clears the milestones' payoutId`; `legacy payments without milestones keep the old path` (existing tests stay green).
  - earnings: `a milestone payment keeps one row whose parts are held 750,001 / soon 750,000 / received 0 after the shoot release`; `the row state is released while a part is payable, disputed when a milestone is disputed, paid_out when all parts are paid`; `milestonesDone/Total read 1/2 then 2/2`; `summary sums the parts across rows (Đang giữ = held, Sắp nhận = soon, Đã nhận = received)`; `a legacy payment keeps today's row with parts derived from its state and milestones null`.
- [ ] **Step 3:** `npm test` — fail.
- [ ] **Step 4: Implement.** Hard part (aggregate and payable must be recomputed on every milestone change):
  ```ts
  export function aggregateEscrow(ms: readonly PaymentMilestone[]): EscrowStatus {
    if (ms.some((m) => m.status === 'disputed')) return 'disputed';
    if (ms.some((m) => m.status === 'held')) return 'held';
    if (ms.some((m) => m.status === 'released')) return 'released';
    if (ms.every((m) => m.status === 'refunded')) return 'refunded';
    return 'paid_out';
  }
  const withMilestones = (p: Payment, ms: PaymentMilestone[], at: string): Payment => ({
    ...p, milestones: ms, escrowStatus: aggregateEscrow(ms),
    payableAmount: ms.filter((m) => m.status === 'released' && !m.payoutId).reduce((s, m) => s + m.amount, 0),
    releaseAfter: ms.filter((m) => m.status === 'held' && m.releaseAfter).map((m) => m.releaseAfter!).sort()[0] ?? undefined,
    updatedAt: at,
  });
  ```
  `isPayoutPayable(p)`: milestones → `payableAmountOf(p) > 0 && payee ok`; else today's rule. `createPayout`: for a milestone payment add one item per released, unbatched milestone and set its `payoutId`; `executePayout` validates per item (`milestone` set → that milestone must be `released` with `payoutId == payout.id`). Earnings: `earningItemOf` keeps its signature and one row per payment; for a milestone payment `heldAmount` = Σ held + disputed, `soonAmount` = Σ released, `receivedAmount` = Σ paid_out (refunded parts excluded), `state` by the precedence of Decision 7, `holdReason` dispute when a milestone is disputed; `summarizeEarnings` adds the parts.
- [ ] **Step 5:** `npm test && npm run lint` green.
- [ ] **Step 6: Commit** `feat(domain): shoot and delivery milestones with per-milestone payouts and earnings [#130]`.

### Task 4: Functions — callables, adapters, clock, rules, indexes, seed

**Files:**
- Create: `app_flutter/firebase/functions/src/callables/delivery.ts`, `src/infra/delivery_firestore.ts` (round/private/sample mappers used by `FirestoreBookingStore`), `src/scheduled/purge_delivery_samples.ts`; tests `test/unit/delivery_callables.test.ts`, `test/unit/delivery_firestore.test.ts`, `test/unit/purge_delivery_samples.test.ts`, `test/integration/delivery.test.ts`
- Modify: `src/index.ts` (four callables; `bookingClock` calls the purge after the sweeps), `src/callables/errors.ts` (`not_ready`), `src/callables/booking.ts` (action list accepts `mark_shot`), `src/infra/booking_firestore.ts` (booking mapping of every new field; payment `milestones`, `payableAmount`; new tx methods; `findDueAutoApprovals`, `findDueChecks`), `src/infra/booking_readers.ts` (`revisions` from `deliverables.revisions`), `src/infra/payout_firestore.ts` (union of the legacy `escrowStatus == 'released'` query and `payableAmount > 0`), `src/infra/earnings_firestore.ts` (row parts and milestone counts), `src/triggers/payment_write.ts` (also syncs `bookings/{subjectId}/milestones/{kind}` from `payment.milestones`; deletes nothing for payments without milestones), `src/scheduled/booking_clock.ts`, `seed/fixtures.ts`, `seed/README.md`, `test/unit/booking_firestore.test.ts`, `booking_clock_ticket_release.test.ts`, `booking_callables.test.ts`, `earnings_firestore.test.ts`, `payout_cli.test.ts`, `seed_fixtures.test.ts`, `errors.test.ts`; `app_flutter/firebase/firestore.rules`, `storage.rules`, `firestore.indexes.json`, `rules-test/rules.test.mjs`; `functions/package.json` (`test:integration` `--only auth,firestore,functions,storage`)

**Interfaces:**
- Consumes: Tasks 2–3.
- Produces: callables of Contract → Callables; `handleSubmitDelivery(request, deps)`, `handleApproveDelivery`, `handleRequestRevision`, `handleAnswerExtraRound` (pattern of `callables/booking.ts`: unauthenticated → `HttpsError('unauthenticated', 'permission_denied', {code})`, domain errors through `toHttpsError`); `purgeDeliverySamples(deps: { db: Firestore; bucket: Bucket; now: Date; limit?: number }): Promise<number>`.

- [ ] **Step 1:** Contract check (Functions, rules, indexes); confirm `jpegUpTo` exists in `storage.rules` (#147); if not, stop and report (Decision 16); ledger differences.
- [ ] **Step 2: Failing tests.**
  - `booking_firestore.test.ts`: `booking mapping round-trips every delivery field` (`shotAt`, `deliveredAt`, `approvedAt`, `checkUntil`, `autoApproveAt`, `deliveryRound`, `revisionsIncluded`, `revisionsUsed`, `revisionsGranted`, `extraRound`, `samplesPurgeAfter`, `samplesPurged`); `a booking without the fields reads revisionsIncluded 1 and deliveryRound 0`; `payment milestones and payableAmount round-trip`.
  - `delivery_firestore.test.ts`: `the round doc has linkHost and no link`; `private delivery holds the link`.
  - `delivery_callables.test.ts`: one success and one refusal per callable with the `details.code` mapping (`not_ready` → `failed-precondition`); `unauthenticated is refused`.
  - clock (`booking_clock_ticket_release.test.ts` or a new `booking_clock_delivery.test.ts`): `the clock auto-approves, finishes and releases`; `the clock run twice releases once`; `purge runs after the sweeps and a purge failure is logged, not thrown`.
  - `purge_delivery_samples.test.ts`: `deletes sample and thumbnail objects of every round, sets samplesPurged and clears samplesPurgeAfter`; `skips a disputed booking`; `missing objects are not an error`; `stops at the limit`.
  - payouts/earnings adapters: `listPayablePayments returns legacy released payments and milestone payments with payableAmount > 0, once each`; `an earnings row of a milestone payment carries heldAmount, soonAmount, receivedAmount, milestonesDone, milestonesTotal`; `payment_write syncs bookings/{id}/milestones/shoot and /delivery with the payment's array and is idempotent` (in `test/unit/payment_write.test.ts`, create if absent).
  - `seed_fixtures.test.ts`: `seed has bookings in shot, delivered (round 1, 3 ready samples), revision_requested, approved (link unlocked, checkUntil in 47 h) with milestone payments`.
  - rules (written, not run): `customer reads deliveries/1`; `stranger cannot read deliveries/1`; `customer cannot read private/delivery while delivered`; `customer reads private/delivery when approved`; `provider reads private/delivery any time`; `customer cannot read deliverySamples`; `nobody writes deliveries, private/delivery, deliverySamples or milestones`; `both parties read milestones/shoot, a stranger cannot`; storage: `provider uploads a 1 MB JPEG to deliveryUploads/{b}/{uid}/x.jpg while shot`; `refused while upcoming`; `refused for a PNG`; `refused over 2 MiB`; `refused for another uid's folder`; `refused for the customer`; `nobody reads deliveryUploads`; `customer and provider read deliveries/{b}/x.jpg`; `stranger cannot`; `nobody writes deliveries/`; contact: `a booking in shot keeps contact unlocked`.
  - integration (written, not run): submit → approve on the emulator; the customer client cannot read `private/delivery` before approval and can after.
- [ ] **Step 3:** `npm test` — fail.
- [ ] **Step 4: Implement.** Rules per Contract → Rules (keep the existing `contact` branch verbatim) and Storage per Contract → Storage:
  ```
  match /deliveryUploads/{bookingId}/{uid}/{file} {
    allow create: if isOwner(uid)
      && firestore.get(/databases/(default)/documents/bookings/$(bookingId)).data.photographerId == uid
      && firestore.get(/databases/(default)/documents/bookings/$(bookingId)).data.status in ['shot', 'revision_requested']
      && resource == null
      && jpegUpTo(2 * 1024 * 1024);   // #147 helper, ImagePurpose.deliverySample
    allow delete: if isOwner(uid);
    allow read, update: if false;
  }
  match /deliveries/{bookingId}/{file} {
    allow read: if signedIn() && request.auth.uid in [
      firestore.get(/databases/(default)/documents/bookings/$(bookingId)).data.customerId,
      firestore.get(/databases/(default)/documents/bookings/$(bookingId)).data.photographerId];
    allow write: if false;
  }
  ```
  Indexes of Contract → Indexes. Seed: bookings `seed-booking-shot` (Lan ↔ An), `seed-booking-delivered` (round 1, three samples written to the Storage emulator by running Task 5's `watermarkSample` on generated 2000×1500 JPEGs — if Task 5 is not merged yet, add these seed files in Task 5 Step 4 instead and ledger it), `seed-booking-revision` (round 1 decided `request_revision`), `seed-booking-approved` (link `https://drive.google.com/drive/folders/seed-an-approved`, `checkUntil = seed time + 47 h`); their payments carry milestones (approved: shoot released, delivery held). `seed/README.md`: a "Delivery (two-layer)" table and "the seed needs the Storage emulator (`FIREBASE_STORAGE_EMULATOR_HOST`)".
- [ ] **Step 5:** `npm test && npm run build` (functions), domain `npm test` green. Ledger: rules tests and integration test written, not run; deploy order (rules + indexes before the Functions; Storage rules by the manual Storage deploy).
- [ ] **Step 6: Commit** `feat(functions): delivery callables, clock sweeps, rules and milestone payouts [#130]`.

### Task 5: Functions — server watermark (`onDeliveryUpload`)

**Files:**
- Create: `app_flutter/firebase/functions/src/infra/watermark.ts`, `src/triggers/delivery_upload.ts`, `functions/assets/fonts/BeVietnamPro-SemiBold.ttf` (copy of `app_flutter/assets/fonts/BeVietnamPro-SemiBold.ttf`), `functions/assets/fonts/OFL.txt` (copy); tests `test/unit/watermark.test.ts`, `test/unit/delivery_upload.test.ts`, `test/integration/delivery_upload.test.ts`
- Modify: `functions/package.json` (dependencies `sharp`, `opentype.js`; devDependency `@types/opentype.js`), `package-lock.json`, `build.mjs` (`external: ['firebase-admin', 'firebase-functions', 'sharp']`), `src/index.ts` (`onDeliveryUpload`), `src/config.ts` (`WATERMARK_OPTIONS`), `seed/fixtures.ts` (sample files, if not done in Task 4)

**Interfaces:**
- Consumes: `parseDeliveryUploadPath`, `watermarkLabel` (Task 2); `bookingFromFirestore`; `db()`; `getStorage().bucket()`.
- Produces:
  ```ts
  // config.ts
  export const WATERMARK_OPTIONS = { region: REGION, memory: '1GiB', cpu: 1, concurrency: 1, timeoutSeconds: 60, maxInstances: 10, minInstances: 0, retry: false } as const;
  // infra/watermark.ts (pure apart from sharp/opentype; no Firebase)
  export const SAMPLE_LONG_SIDE = 1600, SAMPLE_QUALITY = 75, THUMB_LONG_SIDE = 400, THUMB_QUALITY = 70, WATERMARK_OPACITY = 0.35, MAX_UPLOAD_BYTES = 2 * 1024 * 1024;
  export function loadWatermarkFont(): opentype.Font;            // cached; reads assets/fonts/BeVietnamPro-SemiBold.ttf next to lib/
  export function watermarkSvg(width: number, height: number, label: string, font: opentype.Font): string;
  export function watermarkSample(input: Buffer, label: string, font: opentype.Font): Promise<{ sample: Buffer; thumb: Buffer; width: number; height: number }>;
  // triggers/delivery_upload.ts
  export interface DeliveryUploadDeps {
    readBooking(id: string): Promise<Booking | null>;
    providerName(uid: string): Promise<string | null>;
    download(path: string): Promise<Buffer>;
    upload(path: string, data: Buffer): Promise<void>;          // contentType image/jpeg, cacheControl private, max-age=31536000, immutable
    remove(path: string): Promise<void>;                        // missing object = ok
    sampleDoc(bookingId: string, fileId: string): Promise<{ status: string } | null>;
    writeSample(bookingId: string, fileId: string, data: Record<string, unknown>): Promise<void>;
    font(): opentype.Font;
    now(): Date;
  }
  export function handleDeliveryUpload(object: { name: string; contentType?: string; size?: number | string }, deps: DeliveryUploadDeps): Promise<'ignored' | 'ready' | 'failed' | 'already'>;
  ```

- [ ] **Step 1:** Contract check; install the packages (Global Constraints note); ledger the installed versions.
- [ ] **Step 2: Failing tests** (generate inputs with `sharp({create: {width: 3000, height: 2000, channels: 3, background: '#7aa'}})` and `.withMetadata({ exif: { IFD0: { Copyright: 'x', Artist: 'secret' } } })`):
  - `watermarkSample shrinks the long side to 1600 and keeps the aspect`; `a 1200 px image is not enlarged`; `the output has no EXIF` (`(await sharp(out).metadata()).exif === undefined`); `the output is JPEG`; `the thumbnail long side is 400`; `the watermark changes the pixels` (mean absolute difference vs. the plain resize > 1 in the centre region); `portrait input honours the EXIF orientation before stripping it`; `watermarkSvg tiles the label across the whole image` (count of `<use` ≥ 6 for 1600×1067); `Vietnamese diacritics are drawn` (path data for "Trí · Bản xem trước" is longer than for "Tri . Ban xem truoc").
  - `handleDeliveryUpload ignores other paths` (no read, no delete); `writes the sample, the thumbnail and a ready doc for the provider of a shot booking`; `refuses an uploader who is not booking.photographerId: failed doc 'not_allowed'`; `refuses a booking that is not shot or revision_requested`; `marks an oversized upload 'too_large' without downloading it`; `marks a non-JPEG 'unsupported'`; `deletes the clean upload in every outcome` (ready, each failure, and when processing throws); `a retry of an already ready sample returns 'already' and only deletes the clean upload`; `the label uses the provider's display name`.
  - integration (written, not run): upload to the Storage emulator as the provider → within 10 s `deliverySamples/{fileId}` is `ready`, `deliveries/{b}/{fileId}.jpg` exists, the upload is gone.
- [ ] **Step 3:** `npm test` — fail.
- [ ] **Step 4: Implement.**
  ```ts
  export async function watermarkSample(input: Buffer, label: string, font: opentype.Font) {
    const resized = await sharp(input, { failOn: 'error', limitInputPixels: 50_000_000 })
      .rotate()                                   // apply EXIF orientation; metadata is not copied to the output
      .resize({ width: SAMPLE_LONG_SIDE, height: SAMPLE_LONG_SIDE, fit: 'inside', withoutEnlargement: true })
      .toColourspace('srgb')
      .toBuffer({ resolveWithObject: true });
    const { width, height } = resized.info;
    const sample = await sharp(resized.data)
      .composite([{ input: Buffer.from(watermarkSvg(width, height, label, font)), top: 0, left: 0 }])
      .jpeg({ quality: SAMPLE_QUALITY, mozjpeg: true })
      .toBuffer();
    const thumb = await sharp(sample).resize({ width: THUMB_LONG_SIDE, height: THUMB_LONG_SIDE, fit: 'inside' })
      .jpeg({ quality: THUMB_QUALITY }).toBuffer();
    return { sample, thumb, width, height };
  }
  export function watermarkSvg(w: number, h: number, label: string, font: opentype.Font): string {
    const size = Math.max(14, Math.round(Math.max(w, h) / 28));
    const d = font.getPath(label, 0, 0, size).toPathData(1);
    const stepX = font.getAdvanceWidth(label, size) + size * 3, stepY = size * 4;
    const r = Math.ceil(Math.hypot(w, h) / 2);
    let uses = '';
    for (let y = -r, row = 0; y <= r; y += stepY, row++)
      for (let x = -r + (row % 2) * (stepX / 2); x <= r; x += stepX)
        uses += `<use xlink:href="#t" x="${Math.round(x)}" y="${Math.round(y)}"/>`;
    return `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${w}" height="${h}">`
      + `<defs><path id="t" d="${d}"/></defs>`
      + `<g transform="translate(${w / 2} ${h / 2}) rotate(-32)" fill="#fff" fill-opacity="${WATERMARK_OPACITY}"`
      + ` stroke="#000" stroke-opacity="0.18" stroke-width="${(size / 24).toFixed(2)}">${uses}</g></svg>`;
  }
  ```
  Handler order: parse path (else `'ignored'`) → existing `ready` doc → remove upload, `'already'` → size check → booking + `canDeliver` + status → download → `watermarkSample` (label from `watermarkLabel(providerName)`) → upload `deliveries/{b}/{fileId}.jpg` and `{fileId}_t.jpg` → write `ready` doc → `finally` remove the upload. Failures write `{status: 'failed', failure}` and log `{bookingId, fileId, failure}` only (no names, no URLs). Wire `export const onDeliveryUpload = onObjectFinalized(WATERMARK_OPTIONS, (e) => handleDeliveryUpload(e.data, liveDeliveryUploadDeps()))`. Keep `sharp` external in `build.mjs` (native module; installed from `package.json` at deploy).
- [ ] **Step 5:** `npm test && npm run build` green; `node -e "import('./lib/index.js')"` loads (sharp resolved). Ledger: integration test written, not run; the font file and licence copied.
- [ ] **Step 6: Commit** `feat(functions): server-side watermark for delivery samples, clean copy deleted at once [#130]`.

### Task 6: App data — statuses, booking fields, delivery repository, rules mirrors

**Files:**
- Create: `app_flutter/lib/data/delivery/delivery.dart`, `delivery_repository.dart`, `firestore_delivery_repository.dart`, `delivery_providers.dart`; `test/support/fake_delivery_repository.dart`; tests `test/data/delivery/delivery_mapping_test.dart`, `test/data/delivery/fake_delivery_repository_test.dart`
- Modify: `lib/data/booking/booking_status.dart`, `booking.dart` (+ regenerated `booking.freezed.dart`, `booking.g.dart`), `booking_repository.dart` (`BookingAction.markShot`), `firestore_booking_repository.dart`, `booking_rules.dart` (`tabForBooking`, `canReview` adds `approved`), `contact_access.dart`, `lib/data/media/image_picker_port.dart`, `plugin_image_picker.dart`, `lib/data/earnings/earnings.dart`, `firestore_earnings_repository.dart`, `lib/features/booking/booking_view_rules.dart` (`detailActions`, `timelineSteps`, `workDashboard.toDeliver`), `lib/l10n/app_vi.arb` (status and timeline keys), `test/support/booking_world.dart`, `test/support/fake_booking_repository.dart`, `test/support/booking_fixtures.dart`, `test/support/earnings_world.dart`; tests `test/data/booking/` (mapping), `test/features/booking/booking_view_rules_test.dart`, `test/data/media/` (picker), `test/data/earnings/`

**Interfaces:**
- Consumes: Contract → Data, Callables.
- Produces: Contract → App; `DetailAction` adds `markShot`, `deliver`, `answerExtraRound`, `viewDelivery` (`complete` removed); `WorkDashboard.toDeliver` (`List<Booking>`: `shot`, `revision_requested`, and `delivered` with a pending extra round; soonest day first).

- [ ] **Step 1:** Contract check (booking model, view rules, picker, earnings); ledger differences.
- [ ] **Step 2: Failing tests.**
  - mapping: `Booking.fromFirestore reads shot, delivered, revision_requested, approved`; `reads every delivery field and the extra round`; `a booking without them reads revisionsIncluded 1`; `DeliveryRound.fromFirestore reads samples, linkHost, decision`; `StagedSample reads ready and failed`; `FirestoreDeliveryRepository.submit calls submitDelivery with the exact map` (fake functions); `approve`, `requestRevision`, `answerExtraRound` likewise; `deliveryErrorOf maps not_ready, not_eligible, conflict and network`; `uploadSample writes to deliveryUploads/{bookingId}/{uid}/{fileId}.jpg`.
  - upload: `uploadSample calls MediaUploader.upload with ImagePurpose.deliverySample and the deliveryUploads path` (fake uploader records the purpose).
  - rules: `tabForBooking puts shot, delivered, revision_requested in pending and approved in history`; `canReview is true for approved and completed without reviewedAt`; `contact stays unlocked in the four new statuses`.
  - view rules: `provider gets markShot after the end of an upcoming booking`; `provider gets deliver in shot and revision_requested, answerExtraRound when delivered with a pending extra round`; `customer gets viewDelivery when delivered (primary), revision_requested and approved (outline) and review when approved`; `timeline inserts "Bàn giao & duyệt ảnh" after "Buổi chụp"` with subtitles per status and role (Contract l10n keys); `approved shows the delivery step done and "Hoàn thành" current with "Kiểm tra bộ ảnh gốc trong 48 giờ"`; `workDashboard.toDeliver lists shot and revision_requested, soonest first`; `status labels and colours for the four new statuses`.
  - earnings: `EarningItem reads milestonesDone and milestonesTotal; null when absent`.
- [ ] **Step 3:** Run them; they fail.
- [ ] **Step 4: Implement.** `build_runner` after editing `Booking`. `FirestoreDeliveryRepository.watchLink` maps a permission error to `null` (defensive; the screen does not subscribe before approval anyway). `imageUrl` goes through `mediaUrlResolverProvider` (download URL, cached by `cached_network_image`).
- [ ] **Step 5:** `flutter analyze` clean; `test/data`, `test/features/booking` one at a time; affected tests green.
- [ ] **Step 6: Commit** `feat(data): delivery statuses, booking fields and the delivery repository [#130]`.

### Task 7: App — provider side: S06.07 sheet, S05.02 actions, S06.01 section

**Files:**
- Create: `app_flutter/lib/features/delivery/submit_delivery_sheet.dart`, `submit_delivery_controller.dart`, `widgets/sample_tile.dart`; tests `test/features/delivery/submit_delivery_sheet_test.dart`, `submit_delivery_controller_test.dart`
- Modify: `lib/features/booking/booking_detail_screen.dart` (provider actions: "Đã chụp xong", "Nộp bàn giao"/"Nộp vòng {n}", revision card, extra-round card with grant/decline), `lib/features/work/work_screen.dart` (section "Chờ bàn giao"), `lib/l10n/app_vi.arb`; tests `test/features/booking/booking_detail_screen_test.dart`, `test/features/work/work_screen_test.dart`

**Interfaces:**
- Consumes: `DeliveryRepository`, `stagedSamplesProvider`, `deliveryRoundsProvider`, `imagePickerProvider` (default pick), `MediaUploader` through `DeliveryRepository.uploadSample` (`ImagePurpose.deliverySample`, #147), `newUlid`, `DetailAction`s, `WorkDashboard.toDeliver` (Task 6).
- Produces:
  ```dart
  Future<int?> showSubmitDeliverySheet(BuildContext context, {required Booking booking}); // returns the round on success
  class SubmitDeliveryState { List<SampleTileState> tiles; String link; String count; String note; bool submitting; Object? error;
    String? get linkError; String? get countError; SubmitBlock? get blocked; }
  enum SampleTilePhase { uploading, processing, ready, failed }
  class SampleTileState { String fileId; PickedImage local; SampleTilePhase phase; double progress; String? thumbPath; }
  ```

**Backend wiring:** uploads with `DeliveryRepository.uploadSample` (Firebase Storage `deliveryUploads/…`, Storage rules of Task 4); tile phase from `stagedSamplesProvider` (listener on `bookings/{id}/deliverySamples`, provider-only rule); submit → callable `submitDelivery`; "Đã chụp xong" → `transitionBooking` action `mark_shot`; grant/decline → callable `answerExtraRound`; S06.01 list from the existing bookings listener (`watchPhotographerBookings`).

**Mock parity:** `#S06.07`: sheet title "Nộp bàn giao · vòng {n}" + close; 3‑column grid of samples (watermarked thumbnails once ready) + add tile; meta "3–20 ảnh mẫu · tự đóng watermark khi tải lên"; field "Link bộ ảnh gốc"; row "Số ảnh gốc" (96 dp) + "Ghi chú · tuỳ chọn"; `lockn` "Khách chỉ thấy link sau khi đồng ý ảnh mẫu"; primary "Nộp bàn giao"; round ≥ 2: "Khách muốn chỉnh sửa" block first (general note + per-photo notes). `#S05.02-shot`, `#S05.02-extra-round`, `#S06.01-deliver` (Task 1).

- [ ] **Step 1:** Contract check (detail screen, work screen, sheet helpers); confirm #147 is merged (`ImagePurpose.deliverySample`, `MediaUploader.upload(…, purpose:)`); if not, stop and report (Decision 16); ledger differences.
- [ ] **Step 2: Failing tests.**
  - controller: `picking 5 photos starts 5 uploads with ULID file ids`; `a tile moves uploading → processing → ready from the staged-sample stream`; `a failed staged sample marks the tile failed and retry uploads a new file id`; `removing a tile discards its upload`; `blocked: fewer than 3 ready → "Cần ít nhất 3 ảnh mẫu"; any processing → "Đợi ảnh mẫu đóng watermark xong"; more than 20 → "Tối đa 20 ảnh mẫu"`; `link error "Dán link http(s) hợp lệ"`; `count error "Nhập số ảnh gốc"`; `submit sends only ready ids in tile order`; `not_ready from the server shows "Ảnh mẫu đang xử lý, đợi một chút rồi nộp lại." and keeps everything`; `the picker is asked for 1600 px / q75`.
  - sheet: `title reads "Nộp bàn giao · vòng 2" for a revision_requested booking and the customer's notes come first`; `submit button is disabled until blocked is null`; `success closes the sheet and shows "Đã nộp vòng 1"`; `fits 320 dp at 1.3× text`; `ScreenCode S06.07`.
  - detail (provider): `upcoming after the end shows "Đã chụp xong" and calls mark_shot`; `shot shows "Nộp bàn giao"`; `revision_requested shows "Khách muốn chỉnh sửa vòng 1" and "Nộp vòng 2"`; `delivered shows "Đã gửi vòng 1 · chờ khách duyệt" and no primary`; `a pending extra round shows the card; "Cho thêm 1 vòng" calls answerExtraRound(grant: true) and toasts "Đã cho thêm 1 vòng sửa"`; `"Không thêm" opens the confirm sheet and declines`; `approved shows "Khách đã đồng ý ảnh; tiền chuyển sau 48 giờ kiểm tra"`; `only one primary button in every state`.
  - work: `"Chờ bàn giao" lists shot and revision_requested bookings with their badges and opens /b/:id`; `the section is hidden when empty`; `the empty state of S06.02 is not shown while something waits for delivery`.
- [ ] **Step 3:** Run them; they fail.
- [ ] **Step 4: Implement.** No watermark or image processing in the delivery code: compression to 1600 px/q75 happens inside `MediaUploader.upload` (purpose `deliverySample`, #147); tiles show the local file while uploading and the server thumbnail (`thumbPath` → `imageUrl`) once ready; the progress ring is driven by upload events (no idle animation).
- [ ] **Step 5:** `flutter analyze` clean; `test/features/delivery`, `test/features/booking`, `test/features/work` one at a time; affected tests green.
- [ ] **Step 6: Commit** `feat(delivery): S06.07 submit sheet and provider delivery actions on S05.02 and S06.01 [#130]`.

### Task 8: App — customer side: S05.06, S05.07, report sheet, S05.02 entry, S05.03 code, S06.05 milestone

**Files:**
- Create: `app_flutter/lib/features/delivery/delivery_review_screen.dart`, `revision_sheet.dart`, `report_delivery_sheet.dart` (only when #142 is not merged; else the button opens its S18.01 sheet with `subjectType: 'booking'` and the delivery reasons, Decision 15c), `widgets/sample_grid.dart`, `widgets/originals_card.dart`, `widgets/check_window_card.dart`; tests `test/features/delivery/delivery_review_screen_test.dart`, `revision_sheet_test.dart`, `report_delivery_sheet_test.dart`, goldens `test/features/delivery/goldens/`
- Modify: `lib/features/booking/booking_detail_screen.dart` (route `/b/:id/delivery`; customer `viewDelivery`/`review` buttons), `lib/features/booking/cancel_sheet.dart` (wrap in `ScreenCode(ScreenCodes.cancelBooking, …)`), `lib/features/earnings/earnings_screen.dart` (row meta "· mốc 1/2"), `lib/l10n/app_vi.arb`; tests `test/features/booking/booking_detail_screen_test.dart`, `cancel_sheet_test.dart`, `test/features/earnings/earnings_screen_test.dart`

**Interfaces:**
- Consumes: Task 6 repository/providers, `BookingRepository.openDispute`, `bookingProvider`, `photographerProfileProvider` (provider name), `externalLauncherProvider`, `nowTickerProvider`, `BookingRules.canReview/isReviewed`.
- Produces: `class DeliveryReviewScreen extends ConsumerStatefulWidget { const DeliveryReviewScreen({super.key, required this.bookingId}); }`; `Future<bool?> showRevisionSheet(BuildContext, {required Booking booking, required DeliveryRound round, required String providerName, bool extra = false})`; `Future<bool?> showReportDeliverySheet(BuildContext, {required Booking booking})`.

**Backend wiring:** rounds via `deliveryRoundsProvider` (listener `bookings/{id}/deliveries`, parties rule); link via `deliveryLinkProvider` **only when** `booking.status` is `approved` or `completed` (rule `private/delivery`); images via Storage download URLs of `deliveries/{bookingId}/…` (parties rule), thumbnails in the grid, full size in the viewer; actions through callables `approveDelivery`, `requestRevision`, and `openDispute` (report); "Mở bộ ảnh gốc" through `ExternalLauncher.open(Uri.parse(link))`.

**Mock parity:**
- `#S05.06`: bar "Bàn giao · vòng {n}" + "…" menu; row avatar + "{tên} gửi {k} ảnh mẫu · {ngày}" + badge "Chờ bạn duyệt"; 3‑column grid of watermarked thumbnails, the 6th tile "+{n}" when more (tap any → full-screen pager of the 1600 px watermarked files, never the link); card with lock icon "Bộ ảnh gốc · {count} ảnh", masked link chip "{host}/••••••••" (link icon), "Mở khi bạn đồng ý ảnh"; row "Còn {x}/{y} lượt sửa miễn phí" + package name; meta "Tự đồng ý sau {time} nếu bạn không phản hồi" (`CountdownText`, "2 ngày 14 giờ"); footer outline "Yêu cầu chỉnh sửa" (46%) + primary "Đồng ý ảnh" → confirm sheet "Đồng ý ảnh?" / "Đồng ý thì link ảnh gốc mở ra; bạn có 48 giờ để kiểm tra." / primary "Đồng ý ảnh" / "Xem lại" (not red).
- `#S05.06-no-rounds` (Task 1): "Hết lượt sửa miễn phí ({total}/{total})", outline "Xin thêm 1 vòng"; pending / declined lines.
- `#S05.06-approved`: bar "Bàn giao · đã đồng ý"; toast "Bạn đã đồng ý ảnh lúc {time}. Link bộ ảnh gốc đã mở."; card link icon (accent) "Bộ ảnh gốc · {count} ảnh" / "{tên} gửi {ngày}", open link chip, outline small "Mở bộ ảnh gốc"; card "Kiểm tra bộ ảnh gốc trong 48 giờ: còn {h} giờ" (the "còn …" part in accent) + progress bar (`role progressbar`, 0–48) + hint; red text button "Báo vấn đề với ảnh gốc" → `#S05.06-report`; footer primary "Đánh giá buổi chụp" (→ `/b/:id/review`; when already reviewed: outline "Xem đánh giá", no primary). After `checkUntil`: "Đã hết thời gian kiểm tra", no report button.
- `#S05.07`: sheet title "Yêu cầu chỉnh sửa" + accent count "{n} ảnh"; selectable grid with numbered checks and per-photo note captions; hint "Chạm ảnh để sửa ghi chú riêng của ảnh đó."; field "Ghi chú chung"; "Vòng sửa {round}/{total} (miễn phí)"; primary "Gửi yêu cầu". Per-photo note editor: chips "Da sáng hơn", "Bớt vàng", "Xoá vật thể", "Cân lại nghiêng" + text field "Ghi chú cho ảnh {index}" (≤ 120). Extra mode: title "Xin thêm 1 vòng", hint "Hết lượt sửa miễn phí. {name} có thể cho thêm hoặc không.", primary "Gửi đề nghị".
- `#S05.02-delivered` (Task 1) for the customer detail; `#S05.03` gets its `ScreenCode` (no visual change); `#S06.05` row meta "T5 10/10 · mốc 1/2".

- [ ] **Step 1:** Contract check (detail screen, cancel sheet, earnings screen, viewer options); ledger differences.
- [ ] **Step 2: Failing tests.**
  - S05.06: `delivered: title "Bàn giao · vòng 1", "Minh Trí gửi 12 ảnh mẫu · 14/10", 6 tiles with "+6", masked "drive.google.com/••••••••", "Còn 1/2 lượt sửa miễn phí", "Tự đồng ý sau 2 ngày 14 giờ nếu bạn không phản hồi"`; `the customer never subscribes to the link before approved` (fake repository records no `watchLink` call); `"Đồng ý ảnh" opens the confirm sheet and approve is called only after confirming`; `after approve the screen shows the approved layout with the toast`; `no rounds left shows "Hết lượt sửa miễn phí (2/2)" and "Xin thêm 1 vòng"`; `a pending extra round shows "Đã xin thêm 1 vòng · chờ Minh Trí trả lời" and hides the outline`; `approved: "Mở bộ ảnh gốc" launches the link`; `the check card reads "còn 47 giờ" and the bar is at 47/48`; `"Báo vấn đề với ảnh gốc" opens the report sheet`; `"Đánh giá buổi chụp" goes to /b/:id/review`; `reviewed shows "Xem đánh giá" and no primary`; `after checkUntil shows "Đã hết thời gian kiểm tra" and no report button`; `purged samples show "Ảnh mẫu đã xoá sau 90 ngày"`; `a stranger or the provider opening the customer route sees the not-found state`; `ScreenCode S05.06`; `fits 320 dp at 1.3× text`; golden `S05.06 delivered` and `approved`, light and dark (`tags: ['golden']`).
  - S05.07: `selecting tiles numbers them in order and the count reads "3 ảnh"`; `a chip fills the photo note`; `send is disabled with "Chọn ảnh hoặc ghi chú điều cần sửa" when empty`; `send calls requestRevision with sampleIndex values and the general note`; `extra mode calls requestRevision(extra: true) with "Gửi đề nghị"`; `"Vòng sửa 2/2 (miễn phí)"`; `ScreenCode S05.07`.
  - report: `"Báo vấn đề" is red and disabled until a reason is picked`; `"Lý do khác" needs text`; `sends openDispute with the reason label (plus the text for "Lý do khác") and toasts "Đã báo vấn đề. Hỗ trợ sẽ liên hệ bạn."`.
  - detail (customer): `delivered shows the primary "Xem bàn giao" opening /b/:id/delivery`; `approved shows primary "Đánh giá" and outline "Xem bàn giao"`; `shot shows "Chờ Minh Trí gửi ảnh mẫu" in the timeline and no primary`.
  - cancel sheet: `carries ScreenCode S05.03`.
  - earnings: `a milestone row reads "T5 10/10 · mốc 1/2"` and `"đủ 2 mốc"` when both are released (skip if #134 already pinned these).
- [ ] **Step 3:** Run them; they fail.
- [ ] **Step 4: Implement.** The countdowns use `CountdownText` with the injected clock; the check progress is `LinearProgressIndicator(value: left / 48 h)` (static between ticks). The full-screen viewer reuses the existing image pager if one exists (grep `PageView` in `lib/features/photo`), else a minimal `PageView` of `NetworkPhoto`s inside `InteractiveViewer` in `widgets/sample_grid.dart`.
- [ ] **Step 5:** `flutter analyze` clean; `test/features/delivery`, `test/features/booking`, `test/features/earnings` one at a time; goldens locally; affected tests green.
- [ ] **Step 6: Commit** `feat(delivery): S05.06 review and approve, S05.07 revisions, report sheet and S05.03 code [#130]`.

### Task 9: Data model docs, spec status and handover ledger

**Files:**
- Modify: `docs/superpowers/specs/2026-10-06-delivery-preview-unlock-design.md` (Trạng thái "đã làm (#130)"), `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (S05.02 "… · bàn giao: ✅ (#130)", S05.03 "✅ đã làm (4c) · ScreenCode ✅ (#130)", S05.06 "✅ đã làm (#130)", S05.07 "✅ đã làm (#130)", S06.01 "… · Chờ bàn giao ✅ (#130)", S06.05 "… · theo mốc ✅ (#130)", S06.07 "✅ đã làm (#130)"), §3g (milestones on the payment, Decision 7), `docs/superpowers/specs/data-model/domain-model.md` (`BookingStatus` +4, `Booking` new fields, `DeliveryRound`, `PaymentMilestone`, `ExtraRound`, invariant 18 now enforced by `splitMilestones`, the machine in §5), `relational-schema.md` (`booking_deliveries` without `link`, `booking_delivery_links` (private), `booking_milestones` columns incl. `payout_id`; status check list), `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` §4 (one paragraph: milestones live on the payment; `releaseMilestones` is a step of `bookingClock`), `docs/superpowers/specs/2026-10-06-studio-members-design.md` §5.6 (`canDeliver` = provider account; hide S06.07 from assignees)
- Create: `docs/superpowers/handover/ledger-s05-delivery-two-layer.md`

- [ ] **Step 1:** Edit the docs (Vietnamese specs, English code names); check every string in `screens/booking.md`/`photographer.md` against `app_vi.arb` and the mock.
- [ ] **Step 2:** Ledger: Decisions 1–16 as rulings (and which branch of Decision 15 was taken); skipped suites (rules-test, Functions integration incl. Storage); deploy order (Firestore rules + indexes → Storage rules (manual run of `npm run deploy:storage:dev`) → Functions (needs Blaze; `sharp` native build on Cloud Build) → app); the dev project is on Spark, so everything runs on the emulators; set an Artifact Registry cleanup policy before the first cloud deploy; the data #138 needs (Decision 11); the open items of Deferred.
- [ ] **Step 3: Commit** `docs(spec): two-layer delivery done, milestones in the data model, ledger [#130]`.

## Deferred

- **Refund by payment method** (wallet API refund vs bank transfer to the sender account, S22.04) → #141; needs #129's `createPayment`/webhook (method and sender account). No refund happens after a milestone split in this plan.
- Delivery notifications `delivery_submitted`, `delivery_revision_requested`, `delivery_approved`, `delivery_auto_approve_soon`, `delivery_extra_round` → #138 (data listed in Decision 11).
- Disputes as a booking state, staff resolution, "Huỷ phần bàn giao" when late, disputes when no round is left → S18 (#142); this plan only holds the milestone through `openDispute`.
- Studio: assignee view without the S06.07 entry, studio two-block review, "Giao bởi {Studio}" → #136.
- Per-package `revisions` editor in S08.01 → #146; per-booking milestone percentages from `BookingTerms` → #139 (quotes).
- Automatic daily `createPayouts`, first-payout staff approval, tax withholding → #134 (payments spec §6–7); payouts stay on the staff CLI and the fake gateway here.
- Real payment intermediary, real payouts → payments spec §10–11 (after the legal work).
- Staff screens for disputes and payouts (S23) → Phase 1.5 dashboard (#83); Go backend endpoints → Phase 2 (#90).
