# S13 Chụp ngay: customer app (S13.01–S13.08) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Blocked by** `docs/superpowers/plans/2026-10-07-s13-s14-dispatch-provider.md` (same issue #140): its domain, callables, rules, `InstantRepository`, `MapPreview` and `MatchOverlay` must be merged first. Task 1 Step 1 checks they exist; if one is missing, stop and report.

> **No battery/performance, device build or iOS steps** (standing rules in `RUN-ORDER.md`). This plan changes no rules or indexes; no emulator test is skipped beyond the companion plan's.

> **Detail level (owner, "ở giữa"):** exact interfaces, tests listed by name with expected behaviour, sample code only for the parts easy to get wrong.

**Goal:** A customer taps "Chụp ngay" on Home or Tìm thợ ảnh, picks a package, a kind of shoot and a named meet point at their current position (S13.01), swipes through the 5 best-matched photographers and picks one or more (S13.02), pays 100% once on the fake rails and sends the invites, watches each invitee's answer for 60 seconds (S13.03), sees the "Đã match" moment (S13.04), follows the photographer on the map with an ETA and unlocked contact (S13.05), confirms the end of the shoot (S13.06), keeps the money held and chooses again when nobody accepts (S13.07), and can cancel at any step after seeing the exact refund from the server (S13.08) — every screen on the real Functions/Firestore backend against the local emulators.

**Architecture:** UI only, on top of the companion plan's `InstantRepository` (`lib/data/instant/`): callables for every change, Firestore listeners for the request document (`instantRequestProvider`) and the photographer's track (`instantTrackProvider`, only while S13.05 is open). One route `/instant` (S13.01) and one route `/instant/:id` whose `InstantFlowScreen` switches on the request status (S13.02, S13.03, S13.05, S13.06, S13.07, closed states), each view in its own `ScreenCode`; S13.04 is the `MatchOverlay` shown on the `searching → assigned` transition; S13.08 is a sheet. A keep-alive `InstantDraft` holds the S13.01 form across the S04.05 phone detour. Local choices on S13.02 (liked/skipped) stay on the device until "Gửi lời mời". Timers shown on screen call `tickInstantRequest` when they reach zero, so the server settles at once instead of waiting for the 15-minute clock. The map is the schematic `MapPreview`; the ETA is the straight-line estimate of the domain (`estimateEtaMinutes`).

**Tech Stack:** Flutter, Riverpod 3, go_router, existing core widgets (`MapPreview`, `MatchOverlay`, `CountdownRing`, `CountdownText`, `StatusTimeline`, `PolicyTable`, `EscrowNotice`, `PayMethodPicker`, `SignatureLoader` vibration wave, `EmptyState`, `AsyncView`), `geolocator` through `LocationRepository`, `url_launcher` through `ExternalLauncher`; `flutter_test`. No new package.

**Spec:** `docs/superpowers/specs/2026-10-01-instant-booking-design.md` (§1, §2.1 customer flow, §3.1, §4 money and the cancel table, §8 screens, strings and UI conventions, §9 privacy, §10 edge cases, §11 app tests); `docs/superpowers/specs/2026-10-06-payments-payouts-design.md` (M2, §3.1 methods, §5); `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2, §3b.1 (phone before booking, contact unlock), §3h (customer notification targets), S17.03 primer caption; `docs/superpowers/specs/components/shared-components.md` (`SwipeDeck`, `MatchOverlay`, `MapPreview`); `docs/superpowers/specs/2026-10-07-google-cloud-costs.md` §9, §14; mock `docs/design/ui-mock.html` `#S13.01`–`#S13.08`, `#S02.01`, `#S02.06`, `#S11.03` (`PayMethodPicker` look).

**Issue:** #140 (item "I5 app khách (S13)"; the customer half of S13.04 and S13.08).

**Branch:** `plan/140-instant-customer` (claimed with `project.py claim 140` after the companion PR is merged), PR into `develop` titled `feat(instant): Chụp ngay customer app S13.01–S13.08 [#140]`.

**Execution wave:** 5 (cross-plan review 2026-10-07). **Blocked by:** the dispatch plan `2026-10-07-s13-s14-dispatch-provider.md` (#140, wave 4, hard); #129 (S04, wave 1: S04.04 `PaymentScreen`, `openPayment`, `PaySubject`, `PayMethodPicker`, `PaymentsRepository.confirmFake`); #130's reviews plan (wave 2: `MetaLine`, `formatTomatoPct`); #138 (S17, wave 1: instant notification rows and the `/instant/:id` target).

**Replaces** `2026-10-01-instant-i5-customer-app.md` (Goong `PlaceSearch`, `ApiClient` to `DISPATCH_URL`, automatic refund on no-match, `maplibre_gl`) — kept from it: `InstantDraft` across the phone detour, the status switch on one route, the two-party integration test; Task 7 adds a "Superseded by …" line to it.

## Global Constraints

- Spec §4: "khách xem và vuốt chọn miễn phí; trả đủ khi bấm 'Thanh toán {giá} và gửi lời mời' ở lượt đầu … Các lượt chọn lại sau đó dùng khoản đang giữ, không thu thêm."
- Spec §2.1.9 and §3.1: "`no_match` **không phải trạng thái kết thúc**: tiền vẫn `held` … Hệ thống không bao giờ tự hoàn khi chưa tìm được người."
- Spec §8 UI: "nút Huỷ là chữ đỏ mở S13.08, xác nhận huỷ là nút đỏ trong sheet; số tiền hoàn luôn hiện bằng chữ trước khi xác nhận"; "S13.02: thẻ vuốt luôn có nút ♥ / ✕ / Hoàn tác (≥ 48dp, có nhãn đọc màn hình) … khi giảm chuyển động bật, thẻ đổi tức thì thay vì bay đi"; "bản đồ có nút 'Về vị trí của tôi' và nhãn chữ cho mọi ghim".
- Spec §9 privacy: the photographer's position is shown only while `en_route`; the customer's own position is never shared live (only the meet point).
- Main spec §3b.1: a customer without a phone number goes to S04.05 first and comes back (`returnTo`); external channels (call/Zalo/WhatsApp) open only after payment and assignment.
- CLAUDE.md money rules: 100% up front, held, released to the provider after the job; never weaken.
- Payments are #129's: the customer pays on S04.04 through `openPayment(context, ref, subject: InstantPay(requestId), instructions)`; no instant-specific payment sheet or pay URL handling here.
- Companion plan decisions that bind here: 5 (pay before dispatch, on #129's model), 6 (commission 100%, fee 0% configurable — owner 2026-10-07), 9 (cancel table; the arrived split is a config value — owner 2026-10-07), 23 (tomato, not stars), 12 (straight-line ETA, no Maps API), 15 (round fields emptied at assignment), 16 (round end shows "Chưa ai nhận …" and the customer asks for 5 more), 19 (GPS fix + typed meet point name), 30 (schematic `MapPreview`), 31 (five genres).
- App: `package:photobooking/...` imports; features import `core/core.dart`; Firebase only in `lib/data/**`; `AppColors`/`AppSpace`/`AppRadius`/`AppIcons`; strings in `lib/l10n/app_vi.arb` + `flutter gen-l10n`; `ScreenCode` on every view and sheet; `AsyncView` for every `AsyncValue`; one `AppButton.primary` per view.
- Env (from `app_flutter/`): `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.
- Tests: `flutter test --no-pub --timeout 60s <file or folder>`, one folder at a time; bounded `pump(Duration)` on any screen with a countdown, the match overlay or the swipe animation; inject `clockProvider`; `MediaQuery(disableAnimations: true)` where animation is not under test. `flutter analyze` clean before each commit.
- Commits: Conventional Commits, subject ends with `[#140]`, footer `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.

## Decisions

1. **Payment happens at the first "Thanh toán {giá} và gửi lời mời", before any invite** (spec §4, companion Decision 5). Not at match: the photographer would accept and then wait on a payment that might fail, blocking their presence; contact unlock and escrow need paid money; spec §10 says the invite waits for confirmed payment. `invite` returns #129's `PaymentInstructions`; the app opens #129's S04.04 with `openPayment(context, ref, subject: InstantPay(requestId), instructions: …)` (cross-plan review finding 13): VietQR with the countdown for Chuyển khoản QR, `FakeWalletSheet` → `confirmFakePayment` for wallets in fake mode, the wallet `payUrl` in real mode, and `checkInstantPayment` on resume through the `InstantPay` case of `PaymentController`. When the request leaves `pending_payment` S04.04 returns to `/instant/:id`. Later rounds call `invite` without paying again.
2. **Payment method** on the S13.02 summary with #129's `PayMethodPicker` (`lib/core/widgets/pay_method_picker.dart`; Chuyển khoản QR preselected, MoMo, ZaloPay; payments spec §3.1); the mock gets the picker in `#S13.02-summary` (Task 1). The method also names the refund destination on S13.07/S13.08 ("hoàn đủ về MoMo").
3. **Meet point = current GPS fix + a typed name** (≤ 80 characters, required). `MapPreview` shows one pin "Điểm hẹn · {name}" ("Vị trí của bạn" while the name is empty); its "Về vị trí của tôi" button takes a new fix. No drag, no address search (companion Decision 19, cost). Location denied or off → the `#S13.01-noloc` view ("Bật vị trí để Chụp ngay", "Cho phép vị trí", "Đặt lịch thường"); Chụp ngay needs a position.
4. **One route, status switch.** `/instant/:id` maps `choosing` → S13.02 (deck; `roundEnded` with no candidates → "Chưa ai nhận …" banner and "Xem 5 người khác"; unpaid with no candidates → `#S13.02-empty`), `pending_payment` → S13.02 summary in "Thanh toán tiếp" mode, `searching` → S13.03, `assigned`/`en_route`/`arrived` → S13.05, `in_progress`/`finished` → S13.06, `no_match` → S13.07, `completed` → `#S13.06-done`, `cancelled_by_customer`/`abandoned`/`no_show_customer` → `#S13.08-done`. The S13.08 sheet has no route of its own (like S05.03); spec §8's `/instant/:id/cancel` is not added.
5. **S13.04** shows when the flow screen sees `searching → assigned` while open, or opens on an `assigned` request whose `assignedAt` is less than 60 s old (push tap). Otherwise S13.05 directly.
6. **Ticks.** S13.03 calls `tick` once per deadline: 1 s after the latest pending offer's `expiresAt`, and at `searchDeadlineAt`; paid S13.02 at `searchDeadlineAt`; S13.06 at `shootEndsAt`; every view once on app resume. A tick failing is silent (the listener shows the truth).
7. **ETA and stale position.** S13.05 recomputes the ETA from each track point (`haversineKm` to the meet point → `estimateEtaMinutes`); "đến trong khoảng {n} phút" (no "ước tính" label: "khoảng" already says it, mock copy kept). No point for 3 minutes → "Đang chờ cập nhật vị trí" (spec §10). Past `lateDeadlineAt` and not arrived → the late line and "Huỷ (hoàn 100%)".
8. **Cancel amounts come only from the server** (`cancel(dryRun: true)`); the sheet never computes money. The sheet highlights the mock row of the rule (`full_refund`/`free_window`/`photographer_late` → row 1, `en_route` → row 2, `arrived` → row 3), shows "(bây giờ)" on it, and the summary line from the quote. **Owner 2026-10-07:** the arrived split is a server config value (`instantArrivedCancelPhotographerPercent`, default 50, snapshotted on the request as `arrivedCancelPhotographerPercent`); row 3 reads "Hoàn {100 − arrivedCancelPhotographerPercent}%" from the request and the active row's percent and amounts come from the dry run; no percentage is baked into copy (`cancelOutcome` "Hoàn {percent}%" everywhere). Commission (owner 2026-10-07): 100% to the photographer, fee 0% configurable (`platformFeeBp`); the customer never sees the fee, the photographer's earning comes from the server (`earningVnd`).
9. **Home and Tìm thợ entry points** (spec §2.1.1; no mock today → Task 1 frames): S02.01 card under the header, S02.06 outline button above the result count; both only when `instantEnabledProvider` and the user is a customer. Home does one `myActiveRequestId()` read per open: when a request is active, the card reads "Yêu cầu chụp ngay đang mở" and opens `/instant/:id`; `createInstantRequest`'s `conflict` also opens it.
10. **Primer:** `maybeAskForNotifications(context, ref, const CustomerInstantPrimer())` after the first successful payment confirmation (mock S17.03 caption).
11. **Contact on S13.05:** "Nhắn tin" opens `/chat/{request.chatId}`; "Liên hệ" is `PhotographerContactAction(access: ContactAccess.unlocked, subject: ContactSubject.instantRequest(id), style: ContactDialStyle.labeled)`; both only while a photographer is assigned.
12. **After completion** the done view says the photos come within 48 hours; no review entry (reviews are booking-bound until #130) and no dispute link (S18, #142) — the note text "có vấn đề thì báo trong 24 giờ" stays as information (mock).
13. **"Đặt lịch thường"** (S13.02 empty, S13.07, no-location view) goes to `/action` (S02.06); an open request stays open (spec §2.1.9).
14. **Feature flag:** Task 7 sets `kInstantEnabled = true` (both sides ship together) and updates the S17.02 test that pinned it to false.

## Needs the owner

1. Real map tiles and address search for the meet point (shared with the companion plan's question 2): default schematic map + typed name.
2. Customers who refuse location: default no Chụp ngay (offer "Đặt lịch thường"); alternative: pick an area centre (imprecise ETA and a photographer guided only by the name).
3. A review after an instant shoot before tomato/brick (#130): default none.

## Contract

### Consumed (from the companion plan; checked in Task 1 Step 1)

`InstantRepository` (customer methods `config`, `createRequest`, `nextCandidates`, `invite`, `checkPayment`, `confirmComplete`, `myActiveRequestId`, `watchTrack`, `watchRequest`, `cancel`, `tick`), models `InstantConfig`, `InstantPackage`, `InstantGenre`, `InstantStatus`, `InstantRequest` (incl. `chatId`, `candidates`, `offers`, `roundEnded`, `invitedTotal`, `roundsWithInvites`, `payMethod`, `freeCancelUntil`, `lateDeadlineAt`, `searchDeadlineAt`, `shootEndsAt`, `finishedAt`), `InstantCandidate`, `InstantOfferRow`, `OfferOutcome`, `InstantTrack`, `InstantCancelQuote`, `InstantInviteResult` (`InstantPaymentNeeded {instructions, amountVnd}`, `InstantInvited`, `InstantPriceChanged`), `InstantError`/`instantErrorCodeOf`, `estimateEtaMinutes`; `InstantRequest.arrivedCancelPhotographerPercent`, `refundPercent`; `InstantCandidate`/`InstantOfferRow`/`InstantParty` `tomatoPct` + `reviewCount`; providers `instantRepositoryProvider`, `instantEnabledProvider`, `instantConfigProvider`, `instantRequestProvider`, `instantTrackProvider`; `ContactSubject.instantRequest`; core `MapPreview`/`MapPin`, `MatchOverlay`; l10n `instantTitle`, `instantGenre*`, `instantDuration*`, `instantPackageLabel`, `instantStatus*`, `instantError*`, `matchTitle`, `matchBodyCustomer`, `matchContinue`, `jobStepAccepted`, `jobStepArrived`, `jobShootLeft`, `mapRecenter`, `liveShutterOpenSettings`; `test/support/fake_instant_repository.dart`.
Existing app code: `currentContactProvider` and the `startBooking` pattern (`features/discovery/book_entry.dart`), `/profile/phone?returnTo=`, `LocationRepository` + `locationRepositoryProvider` + `FakeLocationRepository`, #129's `PayMethod` (`lib/core/payments.dart`), `PayMethodPicker` (`lib/core/widgets/pay_method_picker.dart`), `PaySubject`/`openPayment`/`PaymentScreen`/`PaymentController` (`lib/features/payment/`), `PaymentsRepository.confirmFake`, `realPaymentsProvider`, `externalLauncherProvider`, `PhotographerContactAction`/`ContactAccess`/`ContactDialStyle`, `maybeAskForNotifications`/`CustomerInstantPrimer`, `safeTarget`, `HomeScreen` (`features/home/home_screen.dart`), `FindScreen` results header (`features/find/find_screen.dart`, the `findCount` line), `ActionTab`, `appRouter`, `clockProvider`, `formatMoney(short:)`, `photographerSessions`, #130's `MetaLine`/`MetaPart.tomato` and `formatTomatoPct` (not `formatRating`, which #130 removed), reusable l10n `fakePayTitle`, `fakePayBody`, `fakePayConfirm`, `ticketPayFailed`, `ticketPayFakeDisabled`, `ticketPayContinue`, `payMethodBankQr`, `payMethodMomo`, `payMethodZaloPay`, `payMethodLabel`.

### Produced

```dart
// lib/core/widgets/swipe_deck.dart (export from core.dart) — shared-components "SwipeDeck"
class SwipeDeck<T> extends StatefulWidget {
  const SwipeDeck({super.key, required this.items, required this.cardBuilder, required this.onLike, required this.onSkip,
    this.onUndo, this.onEmpty, required this.likeStampLabel, required this.likeLabel, required this.skipLabel, required this.undoLabel});
  final List<T> items; final Widget Function(BuildContext, T) cardBuilder;
  final ValueChanged<T> onLike; final ValueChanged<T> onSkip; final VoidCallback? onUndo; final VoidCallback? onEmpty;
  final String likeStampLabel, likeLabel, skipLabel, undoLabel;
}
// Up to 3 cards visible (2nd: translateY 12, scale .94, opacity .55; 3rd: 24, .88, .3); drag right past 30% width
// or ♥ = like, left or ✕ = skip; "CHỌN" stamp fades in with the drag; Hoàn tác restores the last card;
// reduced motion: no fly-out, the next card appears at once. Buttons 56dp (Hoàn tác 44dp + 4dp padding ≥ 48dp), Semantics labels.

// lib/features/instant/
class InstantDraft { final String packageCode; final InstantGenre genre; final String meetPointName; final String note; }
final instantDraftProvider = NotifierProvider<InstantDraftNotifier, InstantDraft>(...); // keep-alive, reset after create
class InstantRequestController extends AutoDisposeAsyncNotifier<InstantRequestView> {   // S13.01
  Future<void> refreshLocation();
  Future<String?> submit(); // phone gate → createRequest → request id (null when sent to S04.05)
}
class ChooseController extends AutoDisposeFamilyNotifier<ChooseState, String> {         // S13.02
  void like(InstantCandidate c); void skip(InstantCandidate c); void undo(); void done(); void unpick(String photographerId);
  void setMethod(PayMethod m);
  Future<void> more();                     // nextCandidates(skipped)
  Future<InstantInviteResult?> send();     // invite; null while in flight (double tap guard)
}
// lib/features/payment/pay_subject.dart (#129's file, its Decision 22): final class InstantPay extends PaySubject { const InstantPay(this.requestId); final String requestId; }
//   payPathOf → '/instant/{requestId}/pay'; PaymentController case: paid when the request leaves pending_payment → go('/instant/{id}'); "Tạo QR mới" = invite again with the same ids (the server reuses or renews the payment)
class InstantFlowScreen extends ConsumerStatefulWidget { const InstantFlowScreen({super.key, required this.requestId}); } // /instant/:id
Future<void> showCustomerCancelSheet(BuildContext context, WidgetRef ref, {required InstantRequest request});
class InstantEntryCard extends ConsumerWidget {}     // S02.01
class InstantFindButton extends ConsumerWidget {}    // S02.06
Duration? nextTickDelay(InstantRequest r, DateTime now); // Decision 6, pure, tested
```

Routes: `/instant` → `InstantRequestScreen`; `/instant/:id` → `InstantFlowScreen`; `/instant/:id/pay` → #129's `PaymentScreen(subject: InstantPay(id), initial: extra)`. The push target `/instant/:id` is allowlisted by #138.

### Strings (`lib/l10n/app_vi.arb`, exact Vietnamese; mock and spec §8 wording)

| Key | Text |
|---|---|
| `instantSubtitle` | Nhiếp ảnh gia tới trong 30–90 phút |
| `instantCardBody` | Nhiếp ảnh gia tới chỗ bạn trong khoảng 30–90 phút |
| `instantCardResumeTitle` | Yêu cầu chụp ngay đang mở |
| `instantCardResumeBody` | Chạm để xem tiếp |
| `instantFindButton` | Chụp ngay · tới trong 30–90 phút |
| `instantMeetPointPin` | Điểm hẹn · {name} |
| `instantMeetPointSelf` | Vị trí của bạn |
| `instantMeetPointLabel` | Tên điểm hẹn |
| `instantMeetPointHint` | Ví dụ: Cổng Trương Định, Công viên Tao Đàn |
| `instantMeetPointRequired` | Nhập tên điểm hẹn để nhiếp ảnh gia dễ tìm. |
| `instantPhotosCount` | {n} ảnh |
| `instantNoteLabel` | Ghi chú cho nhiếp ảnh gia |
| `instantNoteHint` | Mình mặc áo dài trắng, chụp ở hồ… |
| `instantEscrowNote` | Xem 5 người phù hợp miễn phí. Chỉ trả khi gửi lời mời; tiền được giữ an toàn và hoàn 100% nếu bạn huỷ khi chưa có người nhận. |
| `instantSeeMatches` | Xem nhiếp ảnh gia phù hợp |
| `instantLocationTitle` | Bật vị trí để Chụp ngay |
| `instantLocationBody` | Nhiếp ảnh gia cần biết bạn đang ở đâu để tới đúng chỗ. |
| `instantLocationAllow` | Cho phép vị trí |
| `instantBookNormally` | Đặt lịch thường |
| `instantOutsideArea` | Chụp ngay chưa có ở khu vực này. Bạn có thể đặt lịch thường. |
| `instantDisabled` | Chụp ngay đang tạm dừng. |
| `instantHasActive` | Bạn đang có một yêu cầu chụp ngay. |
| `chooseTitle` | Chọn người bạn thích |
| `chooseSubtitle` | {genre} · {duration} · {amount} |
| `chooseCounter` | {index} / {total} |
| `chooseStamp` | CHỌN |
| `chooseEta` | đến khoảng {minutes} phút |
| `chooseLike` | Chọn |
| `chooseSkip` | Bỏ qua |
| `chooseUndo` | Hoàn tác |
| `choosePicked` | Đã chọn {n} người |
| `chooseDone` | Xong |
| `chooseSummaryTitle` | Những người bạn đã chọn |
| `chooseUnpick` | Bỏ chọn |
| `choosePayAndInvite` | Thanh toán {amount} và gửi lời mời |
| `chooseInvite` | Gửi lời mời |
| `chooseMore` | Xem 5 người khác |
| `chooseEscrow` | Tiền được giữ an toàn và hoàn 100% nếu không có người nhận. |
| `chooseRoundEnded` | Chưa ai nhận. Chọn thêm người nhé. |
| `chooseEmptyTitle` | Hiện chưa có nhiếp ảnh gia sẵn sàng gần bạn |
| `chooseEmptyBody` | Bạn chưa phải trả gì. Thử lại sau ít phút hoặc đặt lịch thường. |
| `chooseEmptyRetry` | Thử lại |
| `choosePriceChanged` | Giá vừa đổi thành {amount}. Kiểm tra lại trước khi thanh toán. |
| `chooseUnavailable` | {name} vừa nhận việc khác |
| `waitingTitle` | Đang chờ trả lời |
| `waitingSent` | Đã gửi lời mời cho {n} người |
| `waitingBody` | Ai nhận trước sẽ tới chỗ bạn. Mỗi lời mời còn {time}. |
| `waitingRowMeta` | {pct}% · khoảng {minutes} phút (built with `MetaLine`: tomato icon + `formatTomatoPct`; only with ≥ 5 reviews, cross-plan review finding 27) |
| `waitingRowMetaNoRating` | khoảng {minutes} phút |
| `waitingViewing` | Đang xem |
| `waitingDeclined` | Đã từ chối |
| `waitingExpired` | Hết hạn |
| `waitingNotCounted` | Không tính |
| `waitingRowSemantics` | {name} đang xem lời mời |
| `waitingNote` | Chưa ai nhận thì bạn chọn tiếp trong 5 người khác, không trả thêm. Tiền vẫn được giữ cho tới khi có người nhận hoặc bạn huỷ. |
| `waitingCancel` | Huỷ yêu cầu |
| `trackingSelf` | Bạn |
| `trackingPin` | {name} · {minutes} phút |
| `trackingEta` | đến trong khoảng {minutes} phút |
| `trackingNote` | Đối chiếu ảnh đại diện khi gặp. Vị trí của {name} chỉ hiện trong lúc đang đến. |
| `trackingMessage` | Nhắn tin |
| `trackingCancelFree` | Huỷ (miễn phí thêm {time}) |
| `trackingCancel` | Huỷ |
| `trackingCancelLate` | Huỷ (hoàn 100%) |
| `trackingStale` | Đang chờ cập nhật vị trí |
| `trackingLate` | {name} đến trễ. Bạn có thể huỷ và được hoàn 100%. |
| `trackingArrived` | Đã đến điểm hẹn |
| `trackingArrivedBody` | {name} đang chờ bạn ở {place}. |
| `shootingTitle` | Đang chụp |
| `shootingCard` | {name} · {genre} {duration} |
| `shootingMeta` | Bắt đầu {time} · {place} |
| `shootingStepDeliver` | Hoàn thành và giao {photos} ảnh trong 48 giờ |
| `shootingNote` | Khi {name} bấm Hoàn thành, bạn xác nhận ở đây. Không xác nhận thì tự hoàn thành sau 2 giờ; có vấn đề thì báo trong 24 giờ. |
| `shootingConfirm` | Xác nhận hoàn thành |
| `shootingFinishedTitle` | Chờ bạn xác nhận |
| `shootingFinishedBody` | {name} đã hoàn thành buổi chụp. Tự hoàn thành sau {time} nếu bạn không xác nhận. |
| `doneTitle` | Buổi chụp đã hoàn thành |
| `doneBody` | {name} sẽ giao {photos} ảnh trong 48 giờ. |
| `doneHome` | Về trang chủ |
| `noMatchTitle` | Chưa tìm được nhiếp ảnh gia |
| `noMatchBody` | Bạn đã mời {invited} người trong {rounds} lượt; gần bạn lúc này ít người đang sẵn sàng. |
| `noMatchHeld` | {amount} vẫn được giữ an toàn cho yêu cầu này. Huỷ yêu cầu thì hoàn đủ về {method}. |
| `refundToBankQr` / `refundToMomo` / `refundToZaloPay` | tài khoản đã chuyển / MoMo / ZaloPay |
| `noMatchBookNormally` | Đặt lịch thường với người bạn chọn |
| `noMatchCancel` | Huỷ yêu cầu và hoàn {amount} |
| `noMatchMore` | Chọn thêm người |
| `cancelInstantTitle` | Huỷ chụp ngay? |
| `cancelRowFree` | Đang chọn, đang chờ trả lời, chưa tìm được, hoặc 2 phút đầu sau khi có người nhận |
| `cancelRowEnRoute` | Nhiếp ảnh gia đang đến |
| `cancelRowArrived` | Đã đến, bạn không có mặt sau 15 phút |
| `cancelRowNow` | {row} (bây giờ) |
| `cancelOutcome` | Hoàn {percent}% |
| `cancelInstantRefundFee` | Bạn sẽ được hoàn {refund}; {fee} là phí đi lại trả cho {name}. |
| `cancelInstantRefundAll` | Bạn sẽ được hoàn {refund}. |
| `cancelInstantLate` | {name} đến trễ hơn 15 phút nên bạn được hoàn đủ. |
| `cancelInstantUnpaid` | Bạn chưa thanh toán nên không có khoản tiền nào. |
| `cancelInstantConfirm` | Huỷ và hoàn {refund} |
| `cancelInstantConfirmUnpaid` | Huỷ yêu cầu |
| `cancelInstantKeep` | Giữ yêu cầu |
| `cancelledTitle` | Đã huỷ yêu cầu |
| `cancelledRefund` | Hoàn {amount} về {method}. Tiền thường về trong vài phút. |
| `cancelledNoMoney` | Không có khoản tiền nào. |
| `abandonedTitle` | Yêu cầu đã hết hạn |
| `abandonedBody` | Bạn chưa gửi lời mời trong 30 phút nên yêu cầu đã đóng. |
| `noShowTitle` | Nhiếp ảnh gia báo bạn không có mặt |
| `noShowBody` | Bạn được hoàn {amount} ({percent}%). (percent = the request's `refundPercent`, from the server) |
| `closedNewRequest` | Tạo yêu cầu mới |

## Review Focus

1. **Paying twice.** A double tap on "Thanh toán … và gửi lời mời", or leaving and tapping again, must create one payment and send one set of invites. Pinned by Task 3 "double tap sends one invite" and "pending_payment resumes with Thanh toán tiếp and reuses the payment".
2. **Coming back mid-flow.** App killed during payment, push tap, or Home resume must land on the right view for the status (`pending_payment`, `searching`, `assigned` within 60 s → overlay, `no_match`). Pinned by Task 3 "status switch shows the view of each status" and Task 5 "overlay only on transition or fresh assignment".
3. **Money on screen comes from the server.** S13.08 shows exactly the dry-run quote; S13.07 shows `amountVnd` and the method; the free-cancel countdown ends at `freeCancelUntil`. Pinned by Task 4 "sheet shows the dry-run amounts, not a client computation" and Task 6 "free-cancel countdown switches the label at 2:00".
4. **Countdowns and ticks.** S13.03 rows read "Hết hạn" from server data; one tick per deadline, none after dispose. Pinned by Task 5 "tick once 1 s after the last expiry" and "no timer after dispose".
5. **Privacy and contact.** Photographer pin only while `en_route`; contact actions only when a photographer is assigned; nothing of the customer's live position leaves the device. Pinned by Task 6 "arrived hides the photographer pin", "no contact before assignment".

## Chi phí Google

Backend costs (callables, trigger, clock step, presence, track writes) are counted in the companion plan. This plan adds client reads and no paid API. Assumptions as the companion plan: (b) 1.000 MAU, 150 requests/month; (c) 10.000 MAU, 1.500 requests/month; Home opened 20 times per MAU per month; Firestore nam5 upper bound ($0.06/100K reads, **Singapore chưa xác nhận**). **Functions (one rule for every plan, cost spec §12):** at (b) new invocations and CPU fit the free tier (2M invocations, 180,000 vCPU-s, 360,000 GiB-s per month) → $0; at (c) the app already uses the free tier up (§12 (c): 2.5M invocations, ~500K vCPU-s), so this plan's Functions work is charged at Tier 2: $0.40/M invocations, $0.0000336/vCPU-s, $0.0000035/GiB-s. This plan adds no Functions work.

| Action | Reads | Writes | Notes |
|---|---|---|---|
| Home open (customer, flag on) | 1 (`myActiveRequestId`: `get`, `limit(1)`; an empty query counts 1) | 0 | `get`, not a listener: the card does not need live updates |
| S13.01 open | 1 (`instant_config/current`, `get`, cached for the session) | 0 | |
| `/instant/:id` while open | ~15 per request (one per server write of the request doc) | 0 | single-document listener, closed when the screen is |
| S13.05 track listener | ≤ 60 per trip (writes capped at 4/min by the companion rules) | 0 | only while S13.05 is visible; detached at `arrived` |
| S13.08 dry run | 0 (callable; its reads are in the companion plan) | 0 | |

Totals: (b) Home 20K + requests 150 × 76 ≈ 11K → ~31K reads ≈ $0.02; (c) Home 200K + 1.500 × 76 ≈ 114K → ~314K reads ≈ **$0.19**. No new callables, triggers, scheduled jobs or Storage paths. Maps: `MapPreview` is drawn on the device ($0); a real map with live ETA would cost ≈ $25/month at (c) (companion plan's comparison), which is why it is not the default. Conclusion: **+$0.02/month at (b), +$0.19/month at (c)**, under the $5 threshold. Mitigation already applied: Home uses one `get` instead of a listener, the track listener lives only on S13.05.

---

## Tasks

### Task 1: Mock frames for the customer side and the entry points

**Files:**
- Modify: `docs/design/ui-mock.html` (rails `#S02`, `#S13`; existing classes `.card.hi`, `.btn`, `.field`, `.chips`, `.pkg`, `.map`, `.swipe`, `.picked`, `.irow2`, `.empty`, `.esc`, `.cd`, `.tl`, `.sheet`, `.opt`, the `PayMethodPicker` markup of `#S11.03`), `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (S02.01 and S02.06 "Trạng thái" cells: "+ lối vào Chụp ngay (mock 2026-10-07, #140)").

- [ ] **Step 1: Contract check** — the companion plan's exports listed under "Consumed" exist on `develop` (repository, providers, `MapPreview`, `MatchOverlay`, l10n keys, `FakeInstantRepository`); stop and report if not.
- [ ] **Step 2: Add frames** (caption `<span class="n new">Mới</span>` or `Đổi`, copy verbatim from the Strings table):
  - `id="S02.01-instant"`: Home with a `card hi` under the greeting: `bolt` icon, "Chụp ngay", "Nhiếp ảnh gia tới chỗ bạn trong khoảng 30–90 phút", chevron. Caption: resume variant "Yêu cầu chụp ngay đang mở · Chạm để xem tiếp" when the customer has an active request.
  - `id="S02.06-instant"`: S02.06 with an outline button (`bolt`) "Chụp ngay · tới trong 30–90 phút" above "12 nhiếp ảnh gia rảnh thứ 7".
  - `#S13.01` (Đổi): a `field` "Tên điểm hẹn" with value "Cổng Trương Định, Công viên Tao Đàn" above "Ghi chú cho nhiếp ảnh gia"; map pin "Điểm hẹn · Cổng Trương Định, Công viên Tao Đàn"; caption adds "Điểm hẹn = vị trí hiện tại + tên do khách gõ; nút tròn lấy lại vị trí."
  - `id="S13.01-noloc"`: map replaced by an `empty` block: "Bật vị trí để Chụp ngay", "Nhiếp ảnh gia cần biết bạn đang ở đâu để tới đúng chỗ.", primary "Cho phép vị trí", text "Đặt lịch thường".
  - `id="S13.02-summary"`: bar as S13.02; "Những người bạn đã chọn" with two `irow2` rows (avatar, name, tomato icon + "97% · đến khoảng 9 phút" (the `.tm` markup of `#S02.06`), text "Bỏ chọn"); "Phương thức thanh toán" + the S11.03 picker (Chuyển khoản QR selected, MoMo, ZaloPay); `esc` "Tiền được giữ an toàn và hoàn 100% nếu không có người nhận."; footer primary "Thanh toán 690.000₫ và gửi lời mời"; text "Xem 5 người khác". Caption: later rounds show "Gửi lời mời" and no picker; `pending_payment` shows "Thanh toán tiếp".
  - `id="S13.02-round"`: banner "Chưa ai nhận. Chọn thêm người nhé." over an empty deck, primary "Xem 5 người khác".
  - `id="S13.02-empty"`: `empty` "Hiện chưa có nhiếp ảnh gia sẵn sàng gần bạn", "Bạn chưa phải trả gì. Thử lại sau ít phút hoặc đặt lịch thường.", primary "Thử lại", outline "Đặt lịch thường".
  - `#S13.02` (Đổi): card meta tomato icon + "97% · 112 buổi · đến khoảng 9 phút" (#130 has merged: no stars).
  - `#S13.08` (Đổi): row 3 outcome and the summary amounts are marked as coming from the server (caption: "Tỉ lệ khi đã đến là cấu hình máy chủ (mặc định 50%); số tiền lấy từ máy chủ").
  - `id="S13.05-arrived"`: badge "Đã đến", line "Đã đến điểm hẹn", body "Minh Trí đang chờ bạn ở Cổng Trương Định, Công viên Tao Đàn."; map with only the "Bạn" pin; contact row; no cancel countdown.
  - `id="S13.05-stale"`: same as S13.05 with the meta "Đang chờ cập nhật vị trí".
  - `id="S13.06-confirm"`: title "Chờ bạn xác nhận", body "Minh Trí đã hoàn thành buổi chụp. Tự hoàn thành sau 1:52:10 nếu bạn không xác nhận.", timeline, primary "Xác nhận hoàn thành".
  - `id="S13.06-done"`: `empty` "Buổi chụp đã hoàn thành", "Minh Trí sẽ giao 30 ảnh trong 48 giờ.", outline "Về trang chủ".
  - `id="S13.08-done"`: `empty` "Đã huỷ yêu cầu", "Hoàn 690.000₫ về MoMo. Tiền thường về trong vài phút.", primary "Tạo yêu cầu mới", outline "Về trang chủ". Caption lists the other closed texts (`abandonedTitle/Body`, `noShowTitle/Body`, `cancelledNoMoney`).
  - `#S13.07` caption: "'về {phương thức}' theo phương thức đã trả."
- [ ] **Step 3:** Open `#S13.02-summary`, `#S13.01-noloc` in a browser; Debug overlay shows the codes; nothing overflows the 320px phone.
- [ ] **Step 4: Commit** `docs(mock): Chụp ngay customer frames and entry points (S02.01, S02.06, S13.x variants) [#140]`.

### Task 2: S13.01 request form, `/instant`, entry points and phone gate

**Files:**
- Create: `app_flutter/lib/features/instant/instant_draft.dart`, `instant_request_controller.dart`, `instant_request_screen.dart`, `instant_entry_card.dart`, `instant_find_button.dart`; tests `test/features/instant/instant_request_screen_test.dart`, `instant_request_controller_test.dart`, `instant_entry_test.dart`; `test/support/instant_customer_world.dart` (`instantCustomerApp({repo, location, contact, now, flag = true})` with a router holding `/instant`, `/instant/:id` (stub), `/profile/phone`, `/action`, `/home`).
- Modify: `lib/app/router.dart` (`/instant`), `lib/features/home/home_screen.dart` (card under the header sliver), `lib/features/find/find_screen.dart` (button above the count line), `lib/l10n/app_vi.arb`, `test/features/home/home_screen_test.dart` and `test/features/find/find_screen_test.dart` (flag off: nothing new).

**Interfaces:**
- Consumes: `instantConfigProvider`, `instantRepositoryProvider` (`createRequest`, `myActiveRequestId`), `locationRepositoryProvider`, `currentContactProvider`.
- Produces: `InstantDraft`, `instantDraftProvider`, `InstantRequestController` (`InstantRequestView {config, position, permission, busy, error}`), `InstantRequestScreen`, `InstantEntryCard`, `InstantFindButton`.
- `submit()` order: name required (`instantMeetPointRequired` under the field) → phone: `currentContactProvider` null → push `/profile/phone?returnTo=/instant` and return null (the draft keeps everything) → `createRequest(packageCode, genre, lat, lng, meetPointName, note)` → reset the draft → `context.go('/instant/$id')`. Errors: `outside_service_area` → `instantOutsideArea` with "Đặt lịch thường"; `conflict` → `instantHasActive` snackbar and `go('/instant/$activeId')` from `myActiveRequestId()`; `not_eligible` → `instantDisabled`; `phone_required` (server) → same phone detour; `network` → `instantErrorNetwork`.
- **Backend wiring:** `instant_config/current` (`get`), callable `createInstantRequest`, `instant_requests` query `customerId == uid && active == true limit 1` (`myActiveRequestId`, index from the companion plan).
- **Mock parity:** `#S13.01` (bar back + "Chụp ngay" + "Nhiếp ảnh gia tới trong 30–90 phút"; `MapPreview` height 170 with the meet point pin and the recenter button; three package tiles "30 phút / 15 ảnh / 390K" with the selected one accented (`.pkg .on`); five genre chips; "Tên điểm hẹn" field; note field with counter ≤ 140; `EscrowNotice` with `instantEscrowNote`; primary "Xem nhiếp ảnh gia phù hợp"), `#S13.01-noloc`, `#S02.01-instant`, `#S02.06-instant`.

- [ ] **Step 1: Contract check** of the consumed app names; ledger differences.
- [ ] **Step 2: Failing tests:**
  - screen: `shows the three packages with short prices and the 1 giờ package selected by default`; `five genre chips, Chân dung selected`; `map pin reads "Vị trí của bạn" until a name is typed, then "Điểm hẹn · {name}"`; `recenter takes a new fix`; `empty name shows "Nhập tên điểm hẹn để nhiếp ảnh gia dễ tìm." and does not call createRequest`; `note longer than 140 is cut by the field`; `submit calls createRequest with the exact payload and goes to /instant/{id}`; `no phone goes to /profile/phone?returnTo=/instant and the draft survives the round trip`; `outside_service_area shows the message and "Đặt lịch thường" opens /action`; `conflict opens the active request`; `location denied shows S13.01-noloc; "Cho phép vị trí" asks; deniedForever opens settings`; `the primary button shows a loader while creating and ignores a second tap`; `fits 320dp at 1.3× text, light and dark`.
  - controller: `draft is reset after a successful create`; `config error shows AsyncView error with retry`.
  - entry: `Home card shows "Chụp ngay" and opens /instant`; `Home card resumes "Yêu cầu chụp ngay đang mở" → /instant/{id}`; `Find button opens /instant`; `nothing when the flag is off or the user is a photographer`; `Home reads myActiveRequestId once per build of the card (not a stream)`.
- [ ] **Step 3:** Run `flutter test --no-pub --timeout 60s test/features/instant` → fail.
- [ ] **Step 4: Implement**; arb + `flutter gen-l10n`; `ScreenCode(ScreenCodes.instantRequest, label: 'noloc' when no position)`.
- [ ] **Step 5:** `flutter analyze` clean; `test/features/instant`, `test/features/home`, `test/features/find` green one at a time.
- [ ] **Step 6: Commit** `feat(instant): S13.01 request form, Home and Tìm thợ entry points [#140]`.

### Task 3: `SwipeDeck`, S13.02 choose and pay, `/instant/:id` status switch

**Files:**
- Create: `app_flutter/lib/core/widgets/swipe_deck.dart` (export from `core.dart`), `lib/features/instant/instant_flow_screen.dart`, `choose_view.dart`, `choose_controller.dart`, `instant_payment.dart`, `instant_ticks.dart` (`nextTickDelay`); tests `test/core/widgets/swipe_deck_test.dart`, `test/features/instant/choose_view_test.dart`, `choose_controller_test.dart`, `instant_flow_screen_test.dart`, `instant_ticks_test.dart`.
- Modify: `lib/app/router.dart` (`/instant/:id`), `lib/l10n/app_vi.arb`, `test/support/instant_customer_world.dart` (real `/instant/:id`).

**Interfaces:**
- Consumes: `instantRequestProvider(id)`, repository `nextCandidates`, `invite`, `checkPayment`, `tick`; #129's `PayMethodPicker`, `openPayment(BuildContext context, WidgetRef ref, {required PaySubject subject, required PaymentInstructions instructions, bool replace = false})`, `PaymentScreen`, `PaymentController` (adds the `InstantPay` case), `PaymentsRepository.confirmFake`.
- Produces: `SwipeDeck<T>`, `ChooseController`/`ChooseState {liked, skipped, index, summary, method, sending, error}`, `InstantPay` + route `/instant/:id/pay` (#129's S04.04), `InstantFlowScreen` (status switch per Decision 4; views of later tasks start as `SignatureLoader(wave: LoaderWave.vibration)` placeholders that Tasks 4–6 replace — no placeholder survives Task 6, and Task 7's two-party test fails on any), `nextTickDelay`.
- `SwipeDeck` drag (the part easy to get wrong):
  ```dart
  // In onPanUpdate: _dx += d.delta.dx; stamp opacity = (_dx / (0.3 * width)).clamp(0, 1); rotation = _dx / width * 0.12.
  // onPanEnd: if (_dx > 0.3 * width || velocity > 800) _fly(+1) else if (_dx < -0.3 * width || velocity < -800) _fly(-1) else _snapBack();
  // _fly(dir): reduced motion (MediaQuery.disableAnimationsOf) → commit at once; else animate 220 ms off-screen then commit.
  // commit: _history.add(_index); dir > 0 ? onLike(items[_index]) : onSkip(items[_index]); _index++; if (_index == items.length) onEmpty?.call();
  // undo: if (_history.isEmpty) return; _index = _history.removeLast(); onUndo?.call(); (no animation under reduced motion)
  ```
- `ChooseController.send()` (one in flight; a second call returns null): `invite(requestId, photographerIds: liked, skipped: skipped, expectedAmountVnd: request.amountVnd, payMethod: method.code)` → `InstantPaymentNeeded` → #129's `openPayment(context, ref, subject: InstantPay(requestId), instructions: result.instructions)` (S04.04: VietQR, or `FakeWalletSheet` → `confirmFake` for wallets in fake mode, the `payUrl` in real mode; `checkInstantPayment` on resume) → primer (Decision 10) once the request leaves `pending_payment`; `InstantInvited` → nothing (the listener moves to S13.03); `InstantPriceChanged` → `choosePriceChanged` snackbar and stay on the summary with the new amount. `PayMethod.code` = `bank_qr`/`momo`/`zalopay` (#129's enum has it).
- **Backend wiring:** listener `instant_requests/{id}`; callables `nextInstantCandidates`, `inviteInstant` (returns `PaymentInstructions`), #129's `confirmFakePayment` (emulator/dev only, through S04.04), `checkInstantPayment`, `tickInstantRequest`.
- **Mock parity:** `#S13.02` (bar back + "Chọn người bạn thích" + "Chân dung · 1 giờ · 690.000₫" + counter "3 / 5"; deck with three stacked cards, photo pager of 3 photos with top dashes, "CHỌN" stamp, name + verified mark, meta `MetaLine` tomato "97% · 112 buổi · đến khoảng 9 phút" ("Mới · {n} đánh giá" under 5 reviews), two reason chips; picked row "Đã chọn 2 người" with avatars + secondary "Xong"; three round buttons Hoàn tác (small) / ✕ (red) / ♥ (gradient)), `#S13.02-summary`, `#S13.02-round`, `#S13.02-empty`.

- [ ] **Step 1: Contract check** (#129's `PayMethod`, `PayMethodPicker`, `openPayment`, `PaySubject`, `PaymentController`; #130's `MetaLine`); ledger differences.
- [ ] **Step 2: Failing tests:**
  - `swipe_deck_test.dart`: `drag right past 30% likes, left skips, short drag snaps back`; `♥ and ✕ buttons give the same results as the gestures`; `Hoàn tác restores the last card and calls onUndo`; `stamp "CHỌN" appears while dragging right`; `reduced motion: no fly-out, next card at once`; `buttons are ≥ 48dp and labelled Chọn / Bỏ qua / Hoàn tác`; `onEmpty after the last card`; `no ticker left after dispose`.
  - `choose_view_test.dart`: `shows up to 5 cards with name, meta and reasons`; `"Xong" opens the summary with the liked people`; `deck end with nobody liked offers "Xem 5 người khác" and sends the skipped ids`; `summary "Bỏ chọn" removes a person; none left disables the primary`; `first round: method picker (Chuyển khoản QR selected) and "Thanh toán 690.000₫ và gửi lời mời"`; `cards show the tomato meta, never a star`; `later round (paid): no picker, "Gửi lời mời"`; `pending_payment: "Thanh toán tiếp" calls invite with the pending ids`; `round ended: banner "Chưa ai nhận. Chọn thêm người nhé." and "Xem 5 người khác"`; `unpaid with no candidates: empty view, "Thử lại" calls nextCandidates, "Đặt lịch thường" opens /action`; `price changed: snackbar with the new amount, summary stays`; `fits 320dp at 1.3× text`.
  - `choose_controller_test.dart`: `double tap sends one invite`; `a payment result opens /instant/{id}/pay (S04.04) with the instructions`; `S04.04 for InstantPay returns to /instant/{id} when the request leaves pending_payment and asks the primer once`; `a wallet in fake mode confirms through PaymentsRepository.confirmFake`.
  - `instant_flow_screen_test.dart`: `status switch shows the view of each status` (one case per `InstantStatus`, each `ScreenCode` code checked); `null request (not mine / gone) shows EmptyState with "Về trang chủ"`; `pending_payment resumes with Thanh toán tiếp and reuses the payment` (fake repo returns the same payment id).
  - `instant_ticks_test.dart`: `searching: 1 s after the latest pending expiry`; `paid choosing: at searchDeadlineAt`; `in_progress: at shootEndsAt`; `no deadline → null`; `past deadline → Duration.zero`.
- [ ] **Step 3:** Run `test/core/widgets/swipe_deck_test.dart`, then `test/features/instant` → fail.
- [ ] **Step 4: Implement**; arb + `flutter gen-l10n`; `ScreenCode(ScreenCodes.instantChoose, label: 'summary' | 'round' | 'empty' | null)`, payment sheet `ScreenCode(ScreenCodes.instantChoose, label: 'pay')`.
- [ ] **Step 5:** `flutter analyze` clean; same folders green.
- [ ] **Step 6: Commit** `feat(instant): S13.02 swipe deck, pay-and-invite on the fake rails, request status switch [#140]`.

### Task 4: S13.08 customer cancel sheet, closed states, push target

**Files:**
- Create: `app_flutter/lib/features/instant/customer_cancel_sheet.dart`, `closed_view.dart`; tests `test/features/instant/customer_cancel_sheet_test.dart`, `closed_view_test.dart`.
- Modify: `instant_flow_screen.dart` (closed states), `choose_view.dart` (bar action "Huỷ" while the request is paid or `pending_payment` opens `showCustomerCancelSheet`; Tasks 5–6 wire their own cancel buttons to it); `lib/l10n/app_vi.arb`. (`/instant/:id` is allowlisted by #138; only a routing test here.)

**Interfaces:**
- Produces: `showCustomerCancelSheet(context, ref, {required InstantRequest request})`: shows `AsyncView` while `cancel(dryRun: true)` loads; then `PolicyTable(rows: [free, enRoute, arrived], activeIndex: rowOf(quote.rule))` with "(bây giờ)" on the active row; summary line by rule (`photographer_late` → `cancelInstantLate` + `cancelInstantRefundAll`; fee > 0 → `cancelInstantRefundFee`; `unpaid` → `cancelInstantUnpaid`; else `cancelInstantRefundAll`); red confirm "Huỷ và hoàn {refund}" (`cancelInstantConfirmUnpaid` when unpaid) calling `cancel(dryRun: false)`; text "Giữ yêu cầu". A server `conflict` (state moved, e.g. shooting started) closes the sheet with `instantErrorGeneric`. `ClosedView` for `cancelled_by_customer` (refund line with `amountVnd − feeVnd`, both written by the server, and the payment method; `cancelledNoMoney` when the request was never paid), `abandoned`, `no_show_customer` (`noShowBody` with `amountVnd − feeVnd`); primary "Tạo yêu cầu mới" → `/instant`, outline "Về trang chủ" → `/home`.
- **Backend wiring:** callable `cancelInstantRequest` (dry run, then real); push rows `instant_assigned`, `instant_round_ended`, `instant_no_match`, `instant_arrived`, `instant_finished`, `instant_cancelled` (#138's rows) open `/instant/{id}`.
- **Mock parity:** `#S13.08` (sheet over the dimmed map: "Huỷ chụp ngay?", three option rows with "Hoàn 100% / 80% / {100 − arrivedCancelPhotographerPercent}%" (row 3 from the request's config snapshot, owner 2026-10-07), active row selected, "Bạn sẽ được hoàn **552.000₫**; **138.000₫** là phí đi lại trả cho Minh Trí.", red "Huỷ và hoàn 552.000₫", text "Giữ yêu cầu"), `#S13.08-done`.

- [ ] **Step 1: Contract check** (`PolicyTable`, `showAppSheet`, `safeTarget`); ledger differences.
- [ ] **Step 2: Failing tests:**
  - `customer_cancel_sheet_test.dart`: `sheet shows the dry-run amounts, not a client computation` (fake quote with odd numbers 552.001/137.999 is shown verbatim); `active row follows the rule (free_window → row 1 "(bây giờ)", en_route → row 2, arrived → row 3)`; `row 3 reads the request's split (arrivedCancelPhotographerPercent 30 → "Hoàn 70%") and the amounts come from the dry run`; `unpaid shows "Bạn chưa thanh toán nên không có khoản tiền nào." and "Huỷ yêu cầu"`; `photographer_late shows the late line`; `confirm is a red button, never the gradient`; `confirm calls cancel(dryRun: false) once and closes`; `"Giữ yêu cầu" closes without a call`; `conflict closes with the generic error`; `fits 320dp at 1.3× text`.
  - `closed_view_test.dart`: `cancelled paid: "Hoàn 690.000₫ về MoMo. Tiền thường về trong vài phút."`; `cancelled unpaid: "Không có khoản tiền nào."`; `abandoned and no-show texts`; `"Tạo yêu cầu mới" opens /instant`.
  - routing: `an instant_cancelled row opens /instant/{id}` (#138's allowlist).
- [ ] **Step 3:** Run `test/features/instant` → fail.
- [ ] **Step 4: Implement**; arb + `flutter gen-l10n`; `ScreenCode(ScreenCodes.instantCancel)`, closed view `ScreenCode(ScreenCodes.instantCancel, label: 'done')` (completed uses `instantInProgress`/`done`, Task 6).
- [ ] **Step 5:** `flutter analyze` clean; both folders green one at a time.
- [ ] **Step 6: Commit** `feat(instant): S13.08 cancel sheet from the server quote, closed states, push target [#140]`.

### Task 5: S13.03 waiting, S13.04 match moment, S13.07 no match

**Files:**
- Create: `app_flutter/lib/features/instant/waiting_view.dart`, `no_match_view.dart`, `instant_tick_scheduler.dart`; tests `test/features/instant/waiting_view_test.dart`, `no_match_view_test.dart`, `match_overlay_flow_test.dart`, `instant_tick_scheduler_test.dart`.
- Modify: `lib/features/instant/instant_flow_screen.dart` (wire the views and the overlay), `lib/l10n/app_vi.arb`.

**Interfaces:**
- Produces:
  ```dart
  /// Calls repo.tick(requestId) once when [nextTickDelay] elapses, and once on app resume; one timer at a time,
  /// cancelled on dispose or when the request changes (rescheduled from the new data).
  class InstantTickScheduler { InstantTickScheduler({required Future<void> Function() tick, required DateTime Function() now}); void update(InstantRequest r); void onResume(); void dispose(); }
  ```
- S13.04 rule (Decision 5): `InstantFlowScreen` remembers the previous status; `searching → assigned` while mounted, or first build with `assigned` and `now − assignedAt < 60 s` → push `MatchOverlay(name: photographer.name, body: matchBodyCustomer(name, meetPoint.name, etaMinutes), myAvatarUrl, theirAvatarUrl, onContinue: pop)` over S13.05 (`ScreenCode(ScreenCodes.instantMatched)`).
- **Backend wiring:** request listener rows `offers`, `invitedTotal`, `roundsWithInvites`, `amountVnd`, `payMethod`; callables `tickInstantRequest`, `nextInstantCandidates` (S13.07 "Chọn thêm người"); the red cancel texts open `showCustomerCancelSheet` (Task 4).
- **Mock parity:** `#S13.03` (bar "Đang chờ trả lời"; `SignatureLoader(wave: vibration)` only while waiting, still under reduced motion; "Đã gửi lời mời cho 3 người"; "Ai nhận trước sẽ tới chỗ bạn. Mỗi lời mời còn 0:42." with `CountdownText` to the latest pending expiry; one row per invitee: avatar, name, meta `MetaLine` tomato "97% · khoảng 9 phút", status chip "Đang xem" (live tone) / "Đã từ chối" / "Hết hạn" / for `unavailable` the meta line "{name} vừa nhận việc khác" and chip "Không tính"; note; text button red "Huỷ yêu cầu"), `#S13.04`, `#S13.07` (illustration, "Chưa tìm được nhiếp ảnh gia", "Bạn đã mời 7 người trong 3 lượt; …", `EscrowNotice` "690.000₫ vẫn được giữ an toàn … hoàn đủ về MoMo.", outline "Đặt lịch thường với người bạn chọn", text "Huỷ yêu cầu và hoàn 690.000₫", primary "Chọn thêm người").

- [ ] **Step 1: Contract check** (`MatchOverlay` signature, `SignatureLoader`, `CountdownText`); ledger differences.
- [ ] **Step 2: Failing tests:**
  - `waiting_view_test.dart`: `rows show Đang xem / Đã từ chối / Hết hạn / Không tính from the offers data`; `unavailable row reads "Quốc Bảo vừa nhận việc khác"`; `the countdown reads the time to the latest pending expiry`; `rows have semantics "{name} đang xem lời mời" while pending`; `loader is static under reduced motion`; `"Huỷ yêu cầu" opens the cancel sheet`; `fits 320dp at 1.3× text`.
  - `instant_tick_scheduler_test.dart`: `tick once 1 s after the last expiry`; `reschedules when the request changes, never two timers`; `tick on resume`; `no timer after dispose`.
  - `match_overlay_flow_test.dart`: `overlay only on transition or fresh assignment` (searching → assigned shows it; opening an assignment 2 minutes old does not); `"Tiếp tục" reveals S13.05`; `auto-continue after 3 s`.
  - `no_match_view_test.dart`: `copy uses invitedTotal, roundsWithInvites, amountVnd and the method ("MoMo", "tài khoản đã chuyển")`; `"Chọn thêm người" calls nextCandidates`; `"Đặt lịch thường với người bạn chọn" opens /action`; `"Huỷ yêu cầu và hoàn 690.000₫" opens the cancel sheet`; `no_match never shows a refund as done`.
- [ ] **Step 3:** Run `test/features/instant` → fail.
- [ ] **Step 4: Implement**; arb + `flutter gen-l10n`; `ScreenCode(ScreenCodes.instantSearching)`, `ScreenCode(ScreenCodes.instantNoMatch)`.
- [ ] **Step 5:** `flutter analyze` clean; `test/features/instant` green.
- [ ] **Step 6: Commit** `feat(instant): S13.03 waiting rows, S13.04 match moment, S13.07 money-held no match [#140]`.

### Task 6: S13.05 on the way and S13.06 shooting / confirm / done

**Files:**
- Create: `app_flutter/lib/features/instant/tracking_view.dart`, `shooting_view.dart`, `done_view.dart`; tests `test/features/instant/tracking_view_test.dart`, `shooting_view_test.dart`.
- Modify: `instant_flow_screen.dart`, `lib/l10n/app_vi.arb`.

**Interfaces:**
- Consumes: `instantTrackProvider(id)` (watched only by `TrackingView` while `en_route`), `estimateEtaMinutes`, `haversineKm`, `PhotographerContactAction`, repository `confirmComplete`, `tick`.
- **Backend wiring:** listeners on `instant_requests/{id}` and `instant_tracks/{id}` (rules: both parties; the companion plan deletes the track at arrival); `getContactLink` with `instantRequestId`; callable `confirmInstantComplete`; chat route `/chat/{chatId}`.
- Tracking states: `assigned` (no track yet) → photographer pin absent, ETA from `request.etaMinutes`; `en_route` → pins "Bạn" (meet point, self) + "{name} · {n} phút" (track), dotted route, ETA from the track; track older than 3 min → `trackingStale`; `now > lateDeadlineAt` and not arrived → `trackingLate` + cancel label `trackingCancelLate`; `arrived` → `#S13.05-arrived` (no photographer pin, track listener detached). Cancel label: before `freeCancelUntil` `trackingCancelFree(mm:ss)` via `CountdownText`, then `trackingCancel`; `arrived` keeps "Huỷ" (the sheet shows the server's split); every cancel text opens `showCustomerCancelSheet` (Task 4).
- S13.06: `in_progress` → `CountdownRing` to `shootEndsAt` ("còn lại"), card `shootingCard`, meta `shootingMeta`, badge "Đang chụp", `StatusTimeline` (accepted done, arrived done, deliver upcoming), note, primary "Xác nhận hoàn thành" (enabled, companion Decision 9); `finished` → `#S13.06-confirm` with `CountdownText` to `finishedAt + 2 h`; `completed` → `DoneView` (`#S13.06-done`). Confirm → `confirmComplete`; `conflict` (already completed by the clock) → refresh silently.
- **Mock parity:** `#S13.05` (full-bleed map 250dp with labelled pins and "Về vị trí của tôi"; row avatar, name + verified, meta `MetaLine` tomato "97% · 112 buổi · đến trong khoảng **9 phút**", badge "Đang đến"; note `trackingNote`; outline "Nhắn tin" + `ContactDial` "Liên hệ"; red text "Huỷ (miễn phí thêm 1:40)"), `#S13.05-arrived`, `#S13.05-stale`, `#S13.06`, `#S13.06-confirm`, `#S13.06-done`.

- [ ] **Step 1: Contract check** (`PhotographerContactAction`, `MapPreview` recenter, `CountdownRing`); ledger differences.
- [ ] **Step 2: Failing tests:**
  - `tracking_view_test.dart`: `en_route: two labelled pins, ETA from the track ("đến trong khoảng 6 phút" at 1,2 km)`; `a new track point updates the ETA and the pin`; `no point for 3 minutes shows "Đang chờ cập nhật vị trí"`; `free-cancel countdown switches the label at 2:00`; `after lateDeadlineAt shows the late line and "Huỷ (hoàn 100%)"`; `arrived hides the photographer pin` and `stops listening to the track`; `"Nhắn tin" opens /chat/{chatId}`; `"Liên hệ" requests a link with the instant subject`; `no contact before assignment` (status `searching` never renders this view; and `photographer == null` renders no contact); `recenter centres the map on the meet point`; `fits 320dp at 1.3× text, light and dark`.
  - `shooting_view_test.dart`: `ring counts down to shootEndsAt and ticks at 0`; `"Xác nhận hoàn thành" calls confirmComplete in in_progress and in finished`; `finished shows "Chờ bạn xác nhận" and the 2-hour countdown`; `completed shows "Buổi chụp đã hoàn thành" and "{name} sẽ giao 30 ảnh trong 48 giờ."`; `conflict on confirm refreshes without an error`; `timeline shows Đã nhận · 15:21 and Đã đến · 15:38 in Vietnam time`.
- [ ] **Step 3:** Run `test/features/instant` → fail.
- [ ] **Step 4: Implement**; arb + `flutter gen-l10n`; `ScreenCode(ScreenCodes.instantTracking, label: 'arrived' | 'stale' | null)`, `ScreenCode(ScreenCodes.instantInProgress, label: 'confirm' | 'done' | null)`.
- [ ] **Step 5:** `flutter analyze` clean; `test/features/instant` green.
- [ ] **Step 6: Commit** `feat(instant): S13.05 tracking with schematic map and ETA, S13.06 shooting and completion [#140]`.

### Task 7: Two-party flow test, flag on, docs and ledger

**Files:**
- Create: `app_flutter/test/features/instant/instant_two_party_test.dart`, `test/support/instant_simulator.dart` (one in-memory backend with two `InstantRepository` facades: customer and photographer; implements the companion plan's rules at the level the screens see: rounds, 60 s offers, first accept wins, cancel table from a fixed quote map, statuses; drives time through an injected clock); `docs/superpowers/handover/ledger-instant-customer.md`.
- Modify: `lib/core/feature_flags.dart` (`kInstantEnabled = true`), `test/features/notifications/notification_settings_screen_test.dart` (the "Chụp ngay" row is shown), `docs/superpowers/specs/screens/instant.md` (S13 sections as built), `docs/superpowers/specs/2026-10-01-remaining-screens.md` §2 (S13.01–S13.08 "✅ đã làm (#140)", S13.04 and S13.08 "✅ cả hai bên"; S02.01/S02.06 entries), `docs/superpowers/specs/2026-10-01-instant-booking-design.md` §8 (one line: `/instant/:id/cancel` is a sheet without a route; meet point is a typed name), `docs/superpowers/plans/2026-10-01-instant-i5-customer-app.md` (Superseded line).

- [ ] **Step 1: Failing tests** in `instant_two_party_test.dart` (two `ProviderScope`s on one simulator, bounded pumps):
  - `customer picks three, the second photographer accepts: customer sees the match then S13.05, photographer sees S14.03`;
  - `nobody accepts in round 1 (all expire): customer sees "Chưa ai nhận …", picks again without paying, round 2 matches`;
  - `photographer cancels after accepting: customer is back on S13.02 with the round banner and money held`;
  - `customer cancels at each milestone: choosing unpaid (no money), searching (100%), en route after 2 minutes (80/20 shown to both), arrived (the configured split; 50/50 with the seed, 70/30 with a 30% config)`;
  - `ten minutes without a match: S13.07 with the held amount; "Chọn thêm người" opens a new round`;
  - `completion: photographer finishes, customer confirms, both see the done states`.
- [ ] **Step 2:** Run `flutter test --no-pub --timeout 60s test/features/instant/instant_two_party_test.dart` → fail until the simulator exists; implement the simulator; run → pass.
- [ ] **Step 3:** Flip `kInstantEnabled`; update the S17.02 test; run `test/features/notifications`, `test/features/home`, `test/features/find`, `test/features/work` one at a time → green; `flutter analyze` clean.
- [ ] **Step 4: Docs and ledger** (Built; Decisions 1–14; rulings; skipped by standing rules: no device build so the swipe feel and the map look are not checked on a phone; Deferred below; release note: Chụp ngay shows on Home and Tìm thợ for every customer once deployed — `instant_config/current.enabled` is the server switch).
- [ ] **Step 5: Commit** `feat(instant): two-party Chụp ngay flow test, feature on, docs and ledger [#140]`.

## Deferred

- Real map tiles, address search and reverse geocoding for the meet point; live ETA from a routing API (Needs the owner 1; companion cost comparison ≈ $25/month at (c)).
- Choosing an area when location is refused (Needs the owner 2).
- Review and delivery approval after an instant shoot (#130), dispute within 24 hours (S18, #142).
- Real payment intermediary (#129 Deferred) and the refund destination sheet S22.04 (#141); S04.04 with VietQR is already reused for instant here.
- "Thường có người nhận trong khoảng {n} phút" on S13.01 (needs match-time data).
- Instant requests in S05.01 Đặt lịch and S22.01 payment history (no list today; the Home card resumes the active one).
- A "Xem hồ sơ đầy đủ" from a swipe card (spec question 7).
