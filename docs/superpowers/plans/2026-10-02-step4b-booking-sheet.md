# Step 4b: Booking sheet S04.01–S04.03 and payment wait S04.04 Implementation Plan

> **Battery/performance (2026-10-02, user):** no battery, idle, blur-budget or performance steps in this plan; they run once in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Keep the functional tests.

> **Rules emulator tests (2026-10-02, user):** this plan changes no rules. If a step ever needs the emulators (rules tests, Functions integration tests), write the test and skip running it; CI runs it.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** interfaces are exact; each task lists its tests by name with the expected behaviour; sample code is given only for the parts that are easy to get wrong. Write the remaining code in the style of the surrounding files.

**Goal:** A customer opens `/u/:uid/book` from S02.02, S03.01 or S02.06, picks a package (S04.01), a free day and a start time (S04.02), a place, reviews everything with the money and policy (S04.03), pays the 30 % deposit (fake gateway in this phase) and lands on S04.04, which waits for the server to confirm the payment and never trusts the redirect.

**Architecture:** One `BookingFlowController` (Riverpod `Notifier`, auto-disposed, keyed by photographer) holds every choice, so going back never loses anything and nothing is written to the server before the customer taps "Đặt cọc" on S04.03. The route `/u/:uid/book` is a non-opaque page that draws the app's glass sheet over the previous screen; the four steps are one widget switching on `state.step`. Submitting calls plan 4a's `BookingRepository` (`createBooking` → `createDeposit` → fake confirm or external payment page) and then replaces the sheet with S04.04 (`/b/:id/pay`), which listens to `bookings/{id}` and only moves on when the server status leaves `draft`. Money, slots and the refund text come from plan 4a's client mirror (`booking_rules.dart`, with the Task 1 additions), never from local arithmetic in widgets.

**Tech Stack:** Flutter, Riverpod 3, go_router 18, url_launcher (already a dependency), existing core widgets.

**Spec:** `docs/superpowers/specs/screens/booking.md` (§ S04.01–S04.03 "Quy tắc chung", S04.01, S04.02, Bước 3, S04.03, S04.04); `docs/superpowers/specs/2026-09-30-photography-marketplace-design.md` §7 (slots), §8 (deposit, never trust the redirect), §10 (`day_taken`, network); `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3b.1 (phone gate before booking), §3g.6 (`EscrowNotice` text); `docs/superpowers/specs/components/shared-components.md` (`BookingCard`, `StepProgress`, `AvailabilityCalendar`, `PhoneField`, `SignatureLoader`, `AsyncView`, `AppSkeleton`, `MoneyBreakdown`, `EscrowNotice`, `ProviderPicker`, `ConfirmSheet`); mock `docs/design/ui-mock.html` `data-code="S04.01"`, `"S04.02"`, `"S04.03"`, `"S04.04"` (layout authority).

**Prerequisite:** plan 4a (`docs/superpowers/plans/2026-10-02-step4a-booking-backend.md`) merged into `flutter-rewrite`, plan `2026-10-02-shared-components-a.md` done (RUN-ORDER row 8a2: `SignatureLoader`, `AsyncView`, component skeletons, `BookingCard`, `EscrowNotice`, `MoneyBreakdown`, `ProviderPicker` + `PaymentProviderCode`, `showConfirmSheet`), plus every plan marked done in `RUN-ORDER.md`.

## Contract with plan 4a (merged code, 2026-10-02)

Plan 4a is merged (`9211592`, `5f218d0`). Its real Flutter API, which this plan uses:

```dart
// lib/data/booking/booking.dart (freezed)
Booking({required String id, customerId, photographerId, serviceId,
  required BookingServiceSnapshot serviceSnapshot,   // name, int price, int durationMinutes
  required String day, start, end,                    // 'yyyy-MM-dd', 'HH:mm'
  required BookingPlace place,                        // name, double? lat, double? lng
  String? note, required BookingStatus status,
  required int deposit, required int remaining,
  EscrowStatus? escrowStatus, int? depositRefunded, String? depositProvider,
  DateTime? depositPaidAt, depositRefundedAt, acceptDeadline,
  BookingCancel? cancel, DateTime? completedAt, reviewedAt, String? chatId,
  required DateTime createdAt, updatedAt, /* version */});

// lib/data/booking/booking_repository.dart
abstract class BookingRepository {
  Stream<Booking?> watchBooking(String id);
  Future<Booking?> getBooking(String id);
  Stream<List<Booking>> watchCustomerBookings(String customerId);
  Stream<List<Booking>> watchPhotographerBookings(String photographerId);
  Stream<BookingContactSnapshot?> watchBookingContact(String bookingId);
  Future<Booking> createBooking({required String photographerId, required String serviceId,
      required String day, required String start, required BookingPlace place, String? note});
  Future<CreateDepositResponse> createDeposit({required String bookingId, required String provider, String? returnUrl});
  Future<ConfirmPaymentResponse> confirmFakePayment({required String paymentId});
  Future<CheckDepositResponse> checkDeposit({required String bookingId});   // {bool paid, Booking? booking}
  Future<Booking> transitionBooking({required String bookingId, required String action, String? reason});
  Future<Booking> openDispute({required String bookingId, required String reason});
}
class CreateDepositResponse { String paymentId; String payUrl; String provider; }
// errors: BookingException(String code) in lib/data/booking/firestore_booking_repository.dart

// lib/data/booking/booking_rules.dart
class BookingRules {
  static const depositPercent = 30, draftExpiryMinutes = 30, maxBookingDaysAhead = 365;
  static ({int deposit, int remaining}) computeDeposit(int price);
  static DateTime parseBookingDateTime(String day, String time);          // Vietnam wall time → UTC instant
  static int computeRefundPercent({required DateTime startsAt, required DateTime cancelledAt, required String actorRole});
  static BookingTab? tabForBooking(Booking b); static Map<BookingTab, List<Booking>> groupBookingsByTab(List<Booking> l);
  static bool canCustomerCancel(Booking b); canPhotographerAccept(b); canPhotographerDecline(b);
  static bool canPhotographerComplete(Booking b, DateTime now); canCustomerDispute(Booking b, DateTime now);
}

// lib/data/booking/booking_providers.dart
bookingRepositoryProvider; bookingStreamProvider (family, not auto-disposed);
customerBookingsStreamProvider; photographerBookingsStreamProvider; bookingContactStreamProvider;
groupedCustomerBookingsProvider.

// test/support/fake_booking_repository.dart
FakeBookingRepository({String customerId = 'c1'}) — bookings / contacts maps, seedBooking, seedContact;
createBooking ids 'booking_<n>'; createDeposit paymentId 'pay_<bookingId>'; confirmFakePayment moves draft → requested.
```

**Additions this plan makes in Task 1** (the rest of the plan uses these names; add them to 4a's files, with tests):

```dart
// booking_rules.dart (top-level functions next to BookingRules)
List<String> daySlots(int durationMinutes);            // mirror of the server's computeDaySlots: 06:00 … 20:00 − duration, step 30
String endTimeFor(String start, int durationMinutes);  // mirror of addMinutesToTime
const kNoteMaxLength = 300; const kPlaceMinLength = 3; const kPlaceMaxLength = 120;
({int deposit, int remaining}) depositFor(int price) => BookingRules.computeDeposit(price);

// booking_repository.dart
// PaymentProviderCode is NOT defined here: it comes from core (`lib/core/payments.dart`, exported by
// `core/core.dart`, built by shared-components-a); `.code` ('momo' | 'vnpay') is passed as `provider:`.
enum BookingErrorCode { dayTaken, phoneRequired, priceChanged, notEligible, deadlinePassed, conflict,
  permissionDenied, notFound, invalidArgument, network, unknown }
BookingErrorCode bookingErrorOf(Object error);          // BookingException.code → enum; FirebaseFunctionsException 'unavailable'/'deadline-exceeded' and SocketException → network

// booking_providers.dart
final bookingProvider = StreamProvider.autoDispose.family<Booking?, String>(
    (ref, id) => ref.watch(bookingRepositoryProvider).watchBooking(id));   // screens use this one

// fake_booking_repository.dart (test support)
BookingErrorCode? nextError;        // the next write call throws BookingException(<server code>) once
final createCalls = <({String photographerId, String serviceId, String day, String start, String placeName, String? note})>[];
final depositCalls = <({String bookingId, String provider})>[];
final fakeConfirms = <String>[]; final checkCalls = <String>[];
void remove(String id);              // deletes and emits null on watchBooking (draft cleaned up)
```

**Server gap closed in Task 1:** 4a's `createBookingDraft` does not compare the price the customer saw with the current package price, so `price_changed` can never reach the app (Review Focus 5). Task 1 adds an optional `expectedPrice` (integer VND) to the callable payload and to `validateCreateBookingDraftInput` in `packages/domain`; when present and different from the service's current price, `createBookingDraft` throws `DomainError('price_changed')` before any write (domain test "a changed price is refused with price_changed and nothing is written"; Functions unit test that the callable passes it through). The app always sends it (`createBooking(..., expectedPrice: price)` — add the named parameter to the port, adapter and fake).

Field names used below map to the real model: package price → `serviceSnapshot.price`, duration → `serviceSnapshot.durationMinutes`, deposit → `deposit`, remaining → `remaining`, place name → `place.name`; `createBooking(place: BookingPlace(name: …))`; `createDeposit(provider: provider.code)`; `confirmFakePayment(paymentId:)`; `checkDeposit(bookingId:)` returns `paid`.

Existing app pieces used as they are: `bookingPath` and `startBooking` (`lib/features/discovery/book_entry.dart`), `profilePackagesProvider` (`lib/features/photographer_profile/profile_providers.dart`, `ServiceSummary` with `id`, `name`, `priceVnd`, `durationMinutes`, `coverUrl`), `availabilityMonthProvider` and `calendarTodayProvider` (`lib/data/photographer/availability_providers.dart`), `currentContactProvider`, `userContactRepositoryProvider` (`lib/data/user/user_contact_providers.dart`), `safeReturnTo` (`lib/features/contact/return_to.dart`), `photographerProfileProvider` (`lib/data/photographer/public_profile_providers.dart`, for name and avatar), `externalLauncherProvider` (`lib/data/contact/contact_providers.dart`), `clockProvider`, core widgets `showAppSheet`, `StepProgress`, `AvailabilityCalendar`, `AvailabilityLegend`, `PhoneField`, `AppButton`, `AppChip`, `AppOptionTile`, `StatusBadge`, `GlassCard`, `NetworkPhoto`, `ScreenCode`, `ScreenCodes.bookService` (S04.01), `ScreenCodes.bookDateTime` (S04.02), `ScreenCodes.bookReview` (S04.03), `ScreenCodes.awaitingPayment` (S04.04) in `lib/core/screen_codes.dart`.

Core widgets built by `2026-10-02-shared-components-a.md` (use them, never recreate or restyle them): `SignatureLoader` (`LoaderSize`, `LoaderWave`), `AsyncView`, `AppSkeleton` + the `.skeleton()` of each component (`AppOptionTile.skeleton`, `AvailabilityCalendar.skeleton`, `BookingCard.skeleton`, `MoneyBreakdown.skeleton`), `ErrorState`, `BookingCard` + `BookingSummary` (core) and `bookingSummaryOf` (`lib/data/booking/booking_summary.dart`), `EscrowNotice`, `MoneyBreakdown` + `MoneyLine`/`MoneyLineStyle`, `ProviderPicker` + `PaymentProviderCode` (`lib/core/payments.dart`), `showConfirmSheet`.

## Global Constraints

- "**Điều kiện vào**: khách đăng nhập và **có số điện thoại hợp lệ**. Thiếu thì mở S04.05 trước, lưu xong quay lại đúng bước (`returnTo`). Vào từ S02.02 ("Đặt gói này") thì bỏ bước 1; vào từ S02.06 ("Đặt T7") thì có sẵn ngày và dịch vụ."
- "**Trạng thái luồng** giữ trong controller: `serviceId`, `date`, `start`, `end`, `place`, `note`, `phone`, `provider`. Quay lại không mất lựa chọn. Đóng sheet khi đã chọn gì đó hỏi xác nhận "Bỏ yêu cầu đặt lịch?". Không lưu nháp lên server cho tới khi tạo `draft` ở bước 4."
- "**Tiền**: tổng giá gói luôn nằm trên nút chính; cọc 30%, phần còn lại trả tại buổi chụp." "số tiền cọc làm tròn đến đồng, `cọc + còn lại = giá`."
- S04.01: "`servicesProvider(uid)` (chỉ `active`), sắp theo giá"; "một gói duy nhất → chọn sẵn; không có gói → "Nhiếp ảnh gia chưa đăng gói" và đóng sheet; gói đổi giá trong lúc đặt → báo "Giá gói đã đổi" và cập nhật tổng."
- S04.02: "không chọn được ngày đã đặt/nghỉ/quá khứ, ngày "Chờ" xem được nhưng không chọn, kèm "1 người đang chờ""; "mốc 30 phút từ 06:00 đến 20:00 trừ `durationMinutes`"; "chưa chọn ngày → nút vô hiệu; hết giờ trống trong ngày → "Hôm đó đã hết giờ", chọn ngày khác; lỗi tải lịch → thử lại"; "ngày và giờ chọn không đổi khi quay lại; ngày chọn từ S02.06 được chọn sẵn".
- Bước 3: "Địa điểm tuỳ chọn tự do cần tên (≥ 3 ký tự)."
- S04.03: "đang gọi cổng → nút loading và vô hiệu mọi điều khiển; lỗi `day_taken` → quay S04.02 với ngày đó gạch và báo; lỗi `phone_required` → S04.05; lỗi mạng → giữ nguyên, "Thử lại""; "ghi chú tối đa 300 ký tự có đếm; SĐT kiểm tra định dạng khi rời ô"; "không gọi cổng khi SĐT sai hoặc thiếu; client không tin kết quả redirect, chỉ tin `bookings.status`".
- S04.04: "lắng nghe `bookings/{id}`; "Kiểm tra lại" gọi Function hỏi cổng"; "`paid` → chuyển; sau 30 phút `draft` bị dọn → báo "Yêu cầu đã hết hạn" và về S04.01"; "không tạo thanh toán thứ hai khi "Kiểm tra lại"; vòng chờ dừng khi giảm chuyển động bật (thay bằng biểu tượng tĩnh)".
- Strings (spec keys → ARB keys in `lib/l10n/app_vi.arb`, camelCase, Vietnamese with full diacritics, then `flutter gen-l10n`): `s05_title` "Chọn gói" → `bookChoosePackage`; `s05_with` "Đặt với {name}" → `bookWith`; `s05_continue` "Tiếp tục · {price}" → `bookContinuePrice`; `s06_legendFree` "Rảnh", `s06_legendBooked` "Đã đặt", `s06_legendPending` "Chờ" → reuse the existing `AvailabilityLegend` strings if present, else `bookLegendFree/Booked/Pending`; `s06_waiting` "{n} người đang chờ" → `bookWaiting`; `s06_endsAt` "{start}–{end}" → `bookEndsAt`; `s07_title` "Xem lại" → `bookReview`; `s07_note` "Ghi chú" → `bookNote`; `s07_phone` "SĐT của bạn" → `bookYourPhone`; `s07_deposit` "Đặt cọc hôm nay (30%)" → `bookDepositToday`; `s07_remaining` "Còn lại trả tại buổi chụp" → `bookRemaining`; `s07_policy` "Huỷ trước 48 giờ hoàn cọc 100%. Nhiếp ảnh gia phải nhận trong 24 giờ, nếu không tự hoàn cọc." → `bookPolicy`; `s07_escrow` "Tiền cọc được giữ an toàn trên ứng dụng và chỉ chuyển cho nhiếp ảnh gia sau khi buổi chụp hoàn thành." → `escrowNoticeDeposit`; `s07_pay` "Đặt cọc {amount}" → `bookPay`; `s08_title` "Đang chờ xác nhận thanh toán" → `payPendingTitle`; `s08_body` "Cổng thanh toán chưa báo về. Thường mất dưới một phút. Bạn có thể rời màn này, yêu cầu vẫn được giữ." → `payPendingBody`; `s08_check` "Kiểm tra lại" → `payCheckAgain`; `s08_changeProvider` "Đổi cổng thanh toán" → `payChangeProvider`. Other strings this plan adds are listed in the task that needs them.
- Loading (shared-components-a): every `AsyncValue` renders through `AsyncView` with the skeleton of the component that will appear; no `CircularProgressIndicator`, no hand-written `.when(loading:`. Screen-level waits use `SignatureLoader` (ripple by default); S04.04's wait for the payment gateway uses `SignatureLoader(wave: LoaderWave.vibration)`. Buttons in flight use `AppButton(loading: true)` (inline loader).
- Skeletons are white only (no aurora or other color, dark theme included); loaders and `AsyncView` have no colored backdrop. Both are owned by core: screens must not restyle, tint or wrap them in a colored container.
- Money is shown with the app's existing VND formatter (`formatMoney(int vnd)` in `lib/core/format.dart`) — never hand-built.
- CLAUDE.md: one primary action per screen (`AppButton.primary`); tokens only (`AppColors`, `AppSpace`, `AppRadius`); imports `package:photobooking/...`, features import `core/core.dart`; no `cloud_firestore`/`cloud_functions` in `lib/features/**`; every screen state wrapped in `ScreenCode`; a customer needs a phone number to book.
- Tests: phone-sized view (390 × 844, dpr 1, reset in `tearDown`) in the pump helper, plus the explicit 320 dp / text 1.3× layout tests the tasks name; every test `ProviderContainer`/`ProviderScope` gets `retry: (_, _) => null`; `AppButton` height is 48.
- Commands from `app_flutter/`: `../scripts/bin/flutter test --no-pub <paths>`, `../scripts/bin/flutter analyze --no-pub`, `../scripts/bin/dart format lib test`, `../scripts/bin/flutter gen-l10n`. Commits: Conventional Commits ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push.

## Decisions (where the spec is silent)

1. **Fake payments in the app.** Until plan I6 the server only has the fake gateway. The app reads `const bool.fromEnvironment('REAL_PAYMENTS')` through `realPaymentsProvider` (default `false`). With `false`, after `createDeposit` the app opens a small sheet "Cổng thanh toán giả (chỉ để thử)" with "Thanh toán thành công" (calls `confirmFakePayment`) and "Huỷ"; with `true` it opens `payUrl` with `externalLauncherProvider`. Either way it then goes to S04.04 and waits for the server status.
2. **S04.04 timing.** S04.04 is shown as soon as the customer comes back from the payment step (the mock's "after 5 minutes" is the moment the waiting copy matters; showing S04.04 at once keeps one place that waits). The copy names the chosen gateway ("Cổng MoMo chưa báo về…" in the mock): `payPendingBody` takes `{provider}`; the fake gateway reads "Cổng thử nghiệm".
3. **After `paid`.** S05.02 is built by plan 4c. Until then S04.04's paid state shows a success panel ("Đã gửi yêu cầu", the deposit and "{name} sẽ trả lời trong 24 giờ", the mock's S05.02 toast) with one primary button "Xem lịch đặt" → `/bookings`. Plan 4c replaces this panel with `context.go('/b/$id')`; the hook is `BookingPaidPanel` (Task 7), which 4c deletes.
4. **Place step.** No map in v1 of this sheet (no map package yet; the spec's "Bản đồ nhỏ" waits for the map work of plan I5). The step has a text field and up to three suggestion chips: the photographer's service-area city (`photographerProfileProvider` → `serviceArea.city` or equivalent field) and, when the customer came from S02.06, the area filter label passed as `area` in the query string (`bookingPath` gains an optional `area`). Record this as a deviation for the user.
5. **Phone on S04.03.** The field starts with the customer's saved number. If the customer edits it to another valid number, "Đặt cọc" first saves it with `userContactRepositoryProvider.save(...)` (the same call S04.05 uses), then creates the booking; the server reads the number from `users/{uid}/private/contact`, never from the booking payload.
6. **Provider choice** is core's `ProviderPicker` (two small outline buttons "MoMo" / "VNPay" as in the mock, single choice, MoMo selected by default), not radio tiles.
7. **Closing.** Back or the drag handle on step 1 with nothing chosen closes at once; with any choice made it asks "Bỏ yêu cầu đặt lịch?" through core's `showConfirmSheet(title: l10n.bookDiscardTitle, confirmLabel: l10n.bookDiscard, keepLabel: l10n.bookKeepGoing, danger: true)` ("Bỏ" in red inside the confirmation sheet, "Tiếp tục đặt" outline). Back on steps 2–4 goes to the previous step.

## Review Focus

1. The customer comes back from S04.05 (added a phone) → the sheet opens again on the same step with every earlier choice intact. Pinned by Task 2 ("restores the flow after the phone detour") and Task 6 ("phone_required sends to S04.05 with returnTo of the current flow").
2. The photographer's calendar changes while the customer is on S04.02 or S04.03 (the chosen day becomes pending/booked) → S04.02 un-selects it with the "Hôm đó vừa có người đặt" message; S04.03's submit getting `day_taken` lands on S04.02 with the day crossed. Pinned by Task 4 ("a chosen day that becomes pending is cleared") and Task 6 ("day_taken returns to S04.02 and marks the day").
3. Double tap on "Đặt cọc", or a tap while the request is in flight → exactly one `createBooking` and one `createDeposit`. Pinned by Task 6 ("double tap creates one booking and one deposit").
4. The payment step is abandoned (fake sheet "Huỷ", or the customer kills the app and opens `/b/:id/pay` later) → S04.04 still listens, "Kiểm tra lại" never creates a second payment, and a deleted draft shows "Yêu cầu đã hết hạn". Pinned by Task 7 ("check again calls checkDeposit only", "a removed draft shows expired with Đặt lại").
5. Service price changed between S04.01 and submit → the server refuses with `price_changed`, the sheet reloads packages, shows "Giá gói đã đổi" and the new total on the button, and never pays the old amount. Pinned by Task 6 ("price_changed refreshes the package and the total").

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/widgets/app_bottom_sheet.dart` (modify) | make the frame public as `AppSheetFrame` (used by the sheet route; not built by shared-components-a) |
| `lib/core/core.dart` (modify) | export `AppSheetFrame` |
| `lib/data/booking/payments_mode.dart` (create) | `realPaymentsProvider` |
| `lib/features/booking/booking_flow_state.dart` (create) | `BookingStep`, `BookingFlowState`, `BookingFlowArgs` |
| `lib/features/booking/booking_flow_controller.dart` (create) | `bookingFlowControllerProvider`, all choices, submit |
| `lib/features/booking/booking_sheet_page.dart` (create) | the non-opaque route page and the sheet scaffold (header, StepProgress, close confirmation) |
| `lib/features/booking/steps/service_step.dart`, `datetime_step.dart`, `place_step.dart`, `review_step.dart` (create) | S04.01, S04.02, place, S04.03 |
| `lib/features/booking/fake_payment_sheet.dart` (create) | the fake gateway sheet |
| `lib/features/booking/payment_pending_screen.dart` (create) | S04.04 + `BookingPaidPanel` |
| `lib/features/discovery/book_entry.dart` (modify) | `bookingPath(area:)` |
| `lib/app/router.dart` (modify) | `/u/:uid/book`, `/b/:id/pay` |
| `lib/l10n/app_vi.arb` (+ generated) | strings |
| `test/support/booking_world.dart` (create) | pump helper with fakes (booking, availability, contact, profile, packages, launcher, clock) |
| `test/core/widgets/app_bottom_sheet_test.dart` | `AppSheetFrame` |
| `test/features/booking/*_test.dart` | per task |
| `docs/design/ui-mock.html`, `docs/superpowers/specs/2026-10-01-remaining-screens.md` (modify, Task 8) | code table status; mock left as is unless the user asks |

---

### Task 1: Contract check, `AppSheetFrame`, payments mode

**Files:**
- Modify: `lib/core/widgets/app_bottom_sheet.dart`, `lib/core/core.dart`, `lib/l10n/app_vi.arb`, the 4a files named in "Additions this plan makes in Task 1", `packages/domain/src/booking_requests.ts`, `packages/domain/src/create_booking.ts`, `app_flutter/firebase/functions/src/callables/booking.ts` (expectedPrice)
- Create: `lib/data/booking/payments_mode.dart`
- Test: `test/core/widgets/app_bottom_sheet_test.dart` (extend if it exists)

`BookingCard`/`BookingSummary`/`bookingSummaryOf`, `EscrowNotice` and `PaymentProviderCode` already exist (shared-components-a); this task does not create or change them.

**Interfaces:**
- Consumes: 4a's `Booking`; core `PaymentProviderCode` (`lib/core/payments.dart`).
- Produces:
  - `class AppSheetFrame extends StatelessWidget { const AppSheetFrame({required Widget child}); }` — exactly today's private `_SheetFrame` (key `app-sheet`, 88 % max height, radius 28, blur, `AppColors.overlay` barrier stays in `showAppSheet`). `showAppSheet` uses it.
  - `final realPaymentsProvider = Provider<bool>((ref) => const bool.fromEnvironment('REAL_PAYMENTS'));`

- [ ] **Step 1: Add the 4a additions** (including the `expectedPrice` server change and its domain + Functions tests: `(cd packages/domain && npm test)`, `(cd app_flutter/firebase/functions && npm test && npm run typecheck)`) listed under "Additions this plan makes in Task 1", with tests in `test/data/booking/booking_rules_test.dart` ("daySlots: 120 minutes → 06:00 … 18:00, 25 slots; 480 → last 12:00; 900 → empty"; "endTimeFor 15:30 + 120 → 17:30"; "depositFor matches the shared fixture `packages/domain/test/fixtures/booking_policy.json`"; "bookingErrorOf maps every server code and network errors") and `test/data/booking/fake_booking_repository_test.dart` ("nextError throws once"; "remove emits null"; "calls are recorded"). Run `../scripts/bin/flutter test --no-pub test/data/booking` → PASS.
- [ ] **Step 2: Write the failing widget tests.**
  - `app_bottom_sheet_test.dart`: "showAppSheet still draws the frame (key app-sheet)" and "AppSheetFrame caps at 88 % of the height". (If shared-components-a added a `canDismiss` hook to `showAppSheet` for `ConfirmSheet`, keep it working: "showAppSheet with canDismiss false ignores the barrier tap" stays green.)
- [ ] **Step 3: Run them** → FAIL (missing class).
- [ ] **Step 4: Implement** `AppSheetFrame` and the provider; add ARB key `escrowNoticeDeposit` (the text callers pass to core's `EscrowNotice`; reuse if shared-components-a already added it); `flutter gen-l10n`; export `AppSheetFrame` from `core.dart`.
- [ ] **Step 5: Run** `../scripts/bin/flutter test --no-pub test/core/widgets test/data/booking` → PASS; `flutter analyze --no-pub` → no issues.
- [ ] **Step 6: Commit** `feat(booking): booking rule mirrors, expectedPrice, payments mode and a public AppSheetFrame`.

---

### Task 2: `BookingFlowController` and its state

**Files:**
- Create: `lib/features/booking/booking_flow_state.dart`, `lib/features/booking/booking_flow_controller.dart`
- Test: `test/features/booking/booking_flow_controller_test.dart`

**Interfaces:**
- Consumes: Contract members; `profilePackagesProvider`, `currentContactProvider`, `clockProvider`, `calendarTodayProvider`.
- Produces:

```dart
enum BookingStep { service, datetime, place, review }

@immutable
class BookingFlowArgs {          // from the route query; == by value (family key)
  const BookingFlowArgs({required this.photographerId, this.serviceId, this.day, this.area});
  final String photographerId;
  final String? serviceId;       // S02.02 / S02.06
  final String? day;             // yyyy-MM-dd from S02.06
  final String? area;            // S02.06 area filter label (Decision 4)
}

enum SubmitPhase { idle, creating, paying, done }

@immutable
class BookingFlowState {
  const BookingFlowState({
    required this.step,
    this.serviceId, this.priceVnd, this.durationMinutes, this.serviceName,
    this.day, this.start,
    this.placeName = '', this.note = '',
    this.phone,                    // E.164 or null; starts from the saved contact
    this.provider = PaymentProviderCode.momo,   // core (lib/core/payments.dart)
    this.phase = SubmitPhase.idle,
    this.error,                    // BookingErrorCode? of the last submit
    this.takenDays = const {},     // days refused with day_taken in this flow
    this.priceChanged = false,
    this.bookingId, this.paymentId,
  });
  // … fields as above …
  bool get hasChoices;             // any of serviceId (chosen by the user), day, start, placeName, note
  int? get depositVnd;             // depositFor(priceVnd).deposit
  String? get end;                 // endTimeFor(start, durationMinutes)
  bool get canContinue;            // per step: service chosen / day+start / place ≥ 3 graphemes / review: phone valid && !busy
  bool get busy => phase == SubmitPhase.creating || phase == SubmitPhase.paying;
  BookingFlowState copyWith({...});
}

final bookingFlowControllerProvider = NotifierProvider.autoDispose
    .family<BookingFlowController, BookingFlowState, BookingFlowArgs>(BookingFlowController.new);

class BookingFlowController extends Notifier<BookingFlowState> {
  BookingFlowController(this.args);
  final BookingFlowArgs args;
  @override BookingFlowState build();            // step: service, or datetime when args.serviceId is a valid active package
  void selectService(ServiceSummary s);          // sets id, price, duration, name; clears start if the duration changed
  void applyPackages(List<ServiceSummary> list); // pre-selects a single package or args.serviceId; marks priceChanged when the chosen price moved
  void selectDay(String day);                     // clears start when the day changes
  void selectStart(String start);
  void clearDay(String day, {required bool taken}); // calendar or server says the day is gone; taken → add to takenDays
  void setPlace(String name);
  void setNote(String note);                      // truncated to kNoteMaxLength graphemes
  void setPhone(String? e164);
  void setProvider(PaymentProviderCode p);
  void next();                                    // only when canContinue
  bool back();                                    // false on the first step (the page then asks to close)
  Future<void> submit();                          // Task 6
}
```

Keep the controller pure of widgets; `submit` is a stub that throws `UnimplementedError` until Task 6.

- [ ] **Step 1: Write the failing tests** (`ProviderContainer` with overrides: a fake packages list, `clockProvider`, `calendarTodayProvider`, `retry: (_, _) => null`):
  - "starts on the package step without arguments"
  - "skips the package step when serviceId is an active package" (args `serviceId: 's2'`, packages contain `s2` → step `datetime`, `serviceId == 's2'`)
  - "falls back to the package step when serviceId is unknown or hidden"
  - "a single package is pre-selected but the step still shows" (step `service`, `serviceId` set, `canContinue` true)
  - "preselects the day from S02.06 only when it is today or later" (args `day: yesterday` → `day == null`)
  - "changing the package to another duration clears the start time" (start `15:30`, select a 480-minute package → `start == null`)
  - "changing the day clears the start time"
  - "deposit and remaining always add up to the price" (prices 1, 4, 1_500_000, 1_234_567 → `deposit + remaining == price`, `deposit == floor(price*0.3)`)
  - "place needs at least 3 graphemes" ("Hồ" → false, "Hồ T" → true, "👨‍👩‍👧 x" counts 3)
  - "note is cut at 300 graphemes"
  - "back walks review → place → datetime → service and returns false on the first step; choices survive"
  - "next does nothing while canContinue is false"
  - "applyPackages marks priceChanged and updates the total when the chosen package's price moved"
  - "clearDay(taken: true) un-selects the day, remembers it in takenDays and goes back to datetime"
  - "restores the flow after the phone detour": keep the container alive while the router leaves for S04.05 and comes back (in the test: hold a listener, read the provider again with the same args) → same state. (The provider is auto-disposed; the sheet page keeps it alive with `ref.keepAlive()` while a detour route is on top — implement that link in `build` and close it in `dispose` of the page in Task 3.)
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.** Grapheme counting uses `String.characters.length` (package `characters`, already in Flutter).
- [ ] **Step 4: Run** `test/features/booking/booking_flow_controller_test.dart` → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat(booking): flow controller for the four booking steps`.

---

### Task 3: Route `/u/:uid/book`, the sheet page and S04.01

**Files:**
- Create: `lib/features/booking/booking_sheet_page.dart`, `lib/features/booking/steps/service_step.dart`, `test/support/booking_world.dart`
- Modify: `lib/app/router.dart`, `lib/features/discovery/book_entry.dart`, `lib/l10n/app_vi.arb`
- Test: `test/features/booking/booking_sheet_test.dart`, `test/features/booking/service_step_test.dart`, `test/app/discovery_routes_test.dart` (extend)

**Interfaces:**
- Consumes: Task 1 `AppSheetFrame`, Task 2 controller.
- Produces:
  - `GoRoute(path: '/u/:uid/book', pageBuilder: (c, s) => BookingSheetPage(args: BookingFlowArgs(photographerId: s.pathParameters['uid']!, serviceId: s.uri.queryParameters['serviceId'], day: s.uri.queryParameters['day'] ?? s.uri.queryParameters['date'], area: s.uri.queryParameters['area'])))` — registered **before** `/u/:uid` so the more specific path wins (go_router matches in order); `bookingPath` keeps writing `date` (3b4) and gains `String? area`.
  - `class BookingSheetPage extends Page<void>` creating a non-opaque route that shows the previous screen dimmed under the sheet:

```dart
class BookingSheetPage extends Page<void> {
  const BookingSheetPage({required this.args, super.key});
  final BookingFlowArgs args;

  @override
  Route<void> createRoute(BuildContext context) => PageRouteBuilder<void>(
    settings: this,
    opaque: false,
    barrierDismissible: false,          // closing goes through the confirmation (Decision 7)
    barrierColor: AppColors.overlay,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (_, _, _) => BookingSheet(args: args),
    transitionsBuilder: (_, animation, _, child) {
      final reduce = MediaQuery.of(_).disableAnimations;   // reduced motion: no slide
      if (reduce) return child;
      return SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic))
            .animate(animation),
        child: child,
      );
    },
  );
}
```

  - `class BookingSheet extends ConsumerStatefulWidget` — `Align(bottomCenter)` + `AppSheetFrame` + `PopScope(canPop: false, onPopInvokedWithResult: …)` that calls `controller.back()`; when it returns false and `state.hasChoices`, shows the close confirmation with core's `showConfirmSheet(context, title: l10n.bookDiscardTitle, confirmLabel: l10n.bookDiscard, keepLabel: l10n.bookKeepGoing, danger: true)` (red "Bỏ", outline "Tiếp tục đặt"; no custom sheet) and pops when it returns `true`, else pops. Header row per step: avatar 28 + "Đặt với {name}" (S04.01) or "{service} · {name}" (S04.02), `StepProgress(current: step.index + 1, total: 4, showCount: true)`. Body switches on `state.step`. Holds `ref.keepAlive()` link on the flow provider while a pushed route (S04.05) is on top (`RouteAware` or `ModalRoute.of(context)!.isCurrent` check), closes it in `dispose`.
  - Entry guard: on first build, if `currentContactProvider` resolves to null → `context.replace('/profile/phone?returnTo=${Uri.encodeComponent(GoRouterState.of(context).uri.toString())}')`. A loading contact shows the sheet with the current step's component skeleton (S04.01: `AppOptionTile.skeleton(withThumb: true)` ×3); an error is treated as no phone (fail closed, like `startBooking`).
  - S04.01 `ServiceStep`: header per mock; title `bookChoosePackage`; one `AppOptionTile`-style row per package (thumb 48 via `NetworkPhoto(coverUrl)`, name, short line "{editedCount} ảnh · …" from `ServiceSummary` fields that exist, price right); primary `AppButton.primary(label: l10n.bookContinuePrice(formatMoney(price)))` disabled until chosen; the list renders through `AsyncView(value: profilePackagesProvider(uid), skeleton: (_) => Column(children: [for (var i = 0; i < 3; i++) AppOptionTile.skeleton(withThumb: true)]), onRetry: () => ref.invalidate(profilePackagesProvider(uid)), isEmpty: (l) => l.isEmpty, empty: …)` — first load shows the skeleton rows, error shows core's `ErrorState` with retry, empty shows `EmptyState` "Nhiếp ảnh gia chưa đăng gói" (`bookNoPackages`) with "Đóng". `priceChanged` → inline banner `bookPriceChanged` "Giá gói đã đổi" above the list. Wrapped in `ScreenCode(ScreenCodes.bookService)`.
- `test/support/booking_world.dart`: `Future<void> pumpBookingRoute(WidgetTester t, {String path = '/u/p1/book', FakeBookingRepository? bookings, List<ServiceSummary> packages = …, Map<DateTime, AvailabilityDay> days = const {}, UserContact? contact = const UserContact(phone: '+84903123456'), DateTime? now})` — builds the real router (`screenRouterApp` from `test/support/screen_host.dart` if it fits, else a `GoRouter` with the real routes) with overrides for `bookingRepositoryProvider`, `availabilityRepositoryProvider` (`FakeAvailabilityRepository`), `userContactRepositoryProvider` (fake), `profilePackagesProvider`, `photographerProfileProvider`, `externalLauncherProvider` (recording fake), `clockProvider`, `calendarTodayProvider`, `realPaymentsProvider`; phone-sized view; returns handles for assertions.

- [ ] **Step 1: Write the failing tests:**
  - `discovery_routes_test.dart`: "/u/p1/book opens the booking sheet, /u/p1 still opens S03.01"; "date and serviceId query parameters reach the flow" (S02.06 link `bookingPath(..., date: d, serviceId: 's1')` → step `datetime`, day preselected).
  - `booking_sheet_test.dart`:
    - "the previous screen stays visible under the dimmed sheet" (push `/u/p1/book` from `/u/p1`: S03.01's `ScreenCode` still in the tree, `app-sheet` found).
    - "a customer without a phone is replaced by S04.05 with returnTo of the flow" (contact null → location `/profile/phone?returnTo=%2Fu%2Fp1%2Fbook…`).
    - "Back on step 1 without choices closes the sheet"; "Back on step 1 after choosing asks Bỏ yêu cầu đặt lịch?" → "Tiếp tục đặt" keeps it, "Bỏ" closes; "the barrier tap does not close".
    - "Back on step 2 goes to step 1 with the package still selected".
    - "reduced motion shows the sheet without the slide".
  - `service_step_test.dart`:
    - "lists active packages cheapest first with name and price" (unsorted input, a hidden package → not shown).
    - "the button shows the total and is disabled until a package is chosen".
    - "a single package is preselected and the button is enabled".
    - "no packages shows Nhiếp ảnh gia chưa đăng gói and Đóng closes".
    - "first load shows AppOptionTile.skeleton" (three skeleton rows, no `CircularProgressIndicator`).
    - "load error shows retry; retry reloads".
    - "Giá gói đã đổi banner appears when priceChanged".
    - "320 dp and 1.3× text, light and dark: no overflow; the button stays on screen".
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** route, page, sheet, S04.01, world helper, ARB keys `bookChoosePackage`, `bookWith`, `bookContinuePrice`, `bookNoPackages`, `bookPriceChanged`, `bookDiscardTitle` "Bỏ yêu cầu đặt lịch?", `bookDiscard` "Bỏ", `bookKeepGoing` "Tiếp tục đặt" (the three `showConfirmSheet` labels), `bookClose` "Đóng"; `flutter gen-l10n`.
- [ ] **Step 4: Run** the three test files and `test/app` → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat(booking): /u/:uid/book sheet route and S04.01 package step`.

---

### Task 4: S04.02 day and start time

**Files:**
- Create: `lib/features/booking/steps/datetime_step.dart`
- Modify: `lib/l10n/app_vi.arb`
- Test: `test/features/booking/datetime_step_test.dart`

**Interfaces:**
- Consumes: `availabilityMonthProvider((uid: photographerId, month: m))`, `calendarTodayProvider`, `daySlots`, `endTimeFor`, controller `selectDay`, `selectStart`, `clearDay`.
- Produces: `class DateTimeStep extends ConsumerStatefulWidget` with local state `DateTime month` (starts at the selected day's month or today's).

Behaviour:
- Header "{service} · {name}" + "2 / 4"; row "Tháng {m}" (`bookMonth`) + `AvailabilityLegend`.
- `AvailabilityCalendar(month:, states:, selected:, onSelect:, onMonthChanged:, minDate: today, maxDate: today + 365 days, today:)` where `states` maps the month's `AvailabilityDay`s to `DayState`, and days in `state.takenDays` are forced to `DayState.booked`. Tapping a `pending` day does not select it and shows the inline line `bookWaiting(1)` "1 người đang chờ" under the calendar; `off`/`booked`/past days are not tappable (the calendar already handles `editable: false`; check its API and pass what it needs).
- Below: "{Thứ 7, 12/10} · khung {2 giờ}" (`bookDayLine`, duration with `formatDuration(minutes, l10n)`), chips for `daySlots(duration)` (`AppChip` filter kind, selected = `state.start`), then `bookEndsAt(start, end)`. A day with no slots (duration > 14 h) shows `bookNoSlots` "Hôm đó đã hết giờ".
- Live calendar: when the month stream says the selected day became non-free, call `controller.clearDay(day, taken: false)` and show a SnackBar `bookDayGone` "Hôm đó vừa có người đặt, chọn ngày khác".
- The calendar renders through `AsyncView(value: availabilityMonthProvider(key), skeleton: (_) => AvailabilityCalendar.skeleton(), onRetry: () => ref.invalidate(availabilityMonthProvider(key)))`: first load shows the calendar skeleton, a stream error shows core's `ErrorState` with retry; a month change reloads with the previous month kept and the inline loader (AsyncView's reload rule).
- Primary "Tiếp tục · {price}" enabled only with day + start. `ScreenCode(ScreenCodes.bookDateTime)`.

- [ ] **Step 1: Write the failing tests** (world helper; seed days through `FakeAvailabilityRepository.seed`):
  - "free days are selectable; booked, off and past days are not".
  - "a pending day is not selectable and shows 1 người đang chờ".
  - "selecting a day shows the slot chips for the package duration" (120 minutes → first `06:00`, last `18:00`, 25 chips; 480 minutes → last `12:00`).
  - "choosing a chip shows 15:30–17:30 and enables Tiếp tục".
  - "the day from S02.06 is preselected and its month shown".
  - "moving to next month loads that month" (repository `watchRange` called with the next month's range).
  - "a chosen day that becomes pending is cleared with Hôm đó vừa có người đặt" (seed after selection → start cleared, button disabled, SnackBar).
  - "days refused with day_taken are crossed" (controller `takenDays` → the cell shows booked state).
  - "first load shows AvailabilityCalendar.skeleton".
  - "calendar error shows retry; retry resubscribes".
  - "320 dp, 1.3× text, light and dark: chips wrap, nothing overflows".
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**; ARB keys `bookMonth`, `bookWaiting`, `bookDayLine`, `bookEndsAt`, `bookNoSlots`, `bookDayGone`; gen-l10n.
- [ ] **Step 4: Run** → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat(booking): S04.02 day and time step on the live calendar`.

---

### Task 5: Place step and S04.03 review

**Files:**
- Create: `lib/features/booking/steps/place_step.dart`, `lib/features/booking/steps/review_step.dart`
- Modify: `lib/l10n/app_vi.arb`
- Test: `test/features/booking/place_step_test.dart`, `test/features/booking/review_step_test.dart`

**Interfaces:**
- Consumes: controller `setPlace`, `setNote`, `setPhone`, `setProvider`, `next`; core `BookingCard`/`BookingSummary`, `EscrowNotice`, `MoneyBreakdown`/`MoneyLine`, `ProviderPicker`, `AsyncView` (all from shared-components-a), `PhoneField`, `normalizePhone` (`lib/core/phone.dart`), `depositFor`.
- Produces: `PlaceStep`, `ReviewStep` widgets; `ReviewStep` calls `controller.submit()` (Task 6) from its primary button.

Place step: title `bookPlaceTitle` "Địa điểm", text field (max 120 graphemes, error `bookPlaceTooShort` "Nhập ít nhất 3 ký tự" shown after the first edit), suggestion chips (Decision 4) that fill the field, primary "Tiếp tục · {price}". Same layout family as S04.01.

S04.03 per mock and spec, top to bottom: title `bookReview` + "4 / 4"; core `BookingCard(data: BookingSummary(...))` built from the flow state (no booking exists yet, so the summary is constructed directly, not with `bookingSummaryOf`) with thumb from the package cover and the photographer name from `photographerProfileProvider` — that read goes through `AsyncView` with `skeleton: (_) => Column(children: [BookingCard.skeleton(), MoneyBreakdown.skeleton(lines: 3)])`; one row with two fields of equal height (`IntrinsicHeight`): note (`TextField`, counter "{n}/300", 3 lines) and phone (`PhoneField`, starts with the saved number formatted, validated on focus loss: error `phoneInvalid` existing key); the money table as core `MoneyBreakdown(lines: [MoneyLine(label: l10n.bookPackageLine(name), vnd: price), MoneyLine(label: l10n.bookDepositToday, vnd: deposit, style: MoneyLineStyle.strong), MoneyLine(label: l10n.bookRemaining, vnd: remaining, style: MoneyLineStyle.muted)])` (formatting and tabular figures are the widget's job); core `EscrowNotice(text: l10n.escrowNoticeDeposit)`; policy line `bookPolicy` (plain text per mock; `PolicyTable` is for S05.03); core `ProviderPicker(value: state.provider, onChanged: controller.setProvider)`; primary `AppButton.primary(label: l10n.bookPay(formatMoney(deposit)), loading: state.busy)` (inline loader). While `busy`, every control is disabled (`AbsorbPointer` over the form + the button's own loading state). `ScreenCode(ScreenCodes.bookReview)`.

- [ ] **Step 1: Write the failing tests:**
  - place: "Tiếp tục stays disabled under 3 characters and shows the hint after editing"; "a suggestion chip fills the field and enables Tiếp tục"; "the S02.06 area is offered as a chip"; "the field stops at 120 characters".
  - review:
    - "first load shows BookingCard.skeleton and MoneyBreakdown.skeleton" (profile still loading).
    - "shows the summary card, note and phone side by side, price, deposit 30 % and remaining" (price 1_500_000 → "450.000₫", "1.050.000₫" with the app formatter's exact output).
    - "deposit plus remaining equals the price for an odd price" (1_234_567 → 370_370 + 864_197).
    - "shows the escrow notice and the cancellation policy text".
    - "the note counter counts graphemes and stops at 300".
    - "an invalid phone shows the error on focus loss and disables Đặt cọc".
    - "the ProviderPicker has MoMo selected by default; tapping VNPay selects it".
    - "while submitting the button shows loading and the form ignores taps" (controller phase `creating`).
    - "320 dp and 1.3× text, light and dark: the two fields keep equal height and nothing overflows".
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**; ARB keys `bookPlaceTitle`, `bookPlaceTooShort`, `bookPlaceHint` "Tên địa điểm, ví dụ Bến Bạch Đằng", `bookReview`, `bookNote`, `bookNoteHint`, `bookYourPhone`, `bookPackageLine` "Gói {name}", `bookDepositToday`, `bookRemaining`, `bookPolicy`, `bookPay` (provider labels come from `ProviderPicker`; do not add `providerMomo`/`providerVnpay` unless shared-components-a left them to callers); gen-l10n.
- [ ] **Step 4: Run** → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat(booking): place step and S04.03 review with money and policy`.

---

### Task 6: Submit — create the draft, the deposit, the fake gateway, error handling

**Files:**
- Modify: `lib/features/booking/booking_flow_controller.dart`, `lib/features/booking/booking_sheet_page.dart`, `lib/l10n/app_vi.arb`
- Create: `lib/features/booking/fake_payment_sheet.dart`
- Test: `test/features/booking/submit_test.dart`

**Interfaces:**
- Consumes: `bookingRepositoryProvider`, `userContactRepositoryProvider`, `realPaymentsProvider`, `externalLauncherProvider`.
- Produces: `Future<void> BookingFlowController.submit()`; a one-shot outcome the sheet reacts to:

```dart
sealed class SubmitOutcome { const SubmitOutcome(); }
final class GoToPayment extends SubmitOutcome {     // sheet → fake sheet or external page, then S04.04
  const GoToPayment({required this.bookingId, required this.paymentId, required this.payUrl});
  final String bookingId; final String paymentId; final Uri payUrl;
}
final class NeedPhone extends SubmitOutcome { const NeedPhone(); }   // → S04.05 with returnTo
// day_taken, price_changed, network errors stay in state (error + step), no outcome.
```

Submit algorithm (sample; keep this order):

```dart
Future<void> submit() async {
  final s = state;
  if (s.busy || !s.canContinue) return;               // double tap and invalid form
  state = s.copyWith(phase: SubmitPhase.creating, error: null);
  try {
    final saved = await _savedPhone();                 // currentContactProvider.future
    if (s.phone != null && s.phone != saved) {
      await ref.read(userContactRepositoryProvider).save(/* phone: s.phone, keep other fields */);
    }
    final bookingId = s.bookingId ?? (await _repo.createBooking(
      photographerId: args.photographerId, serviceId: s.serviceId!, day: s.day!, start: s.start!,
      place: BookingPlace(name: s.placeName.trim()), note: s.note.trim().isEmpty ? null : s.note.trim(),
      expectedPrice: s.priceVnd!,
    )).id;
    state = state.copyWith(bookingId: bookingId, phase: SubmitPhase.paying);
    final checkout = await _repo.createDeposit(bookingId: bookingId, provider: s.provider.code);
    state = state.copyWith(paymentId: checkout.paymentId, phase: SubmitPhase.done);
    _outcomes.add(GoToPayment(bookingId: bookingId, paymentId: checkout.paymentId, payUrl: Uri.parse(checkout.payUrl)));
  } catch (e) {
    state = _onError(bookingErrorOf(e));               // see table
  }
}
```

A retry after a network error **reuses** `bookingId` (no second draft); the server replaces the customer's own draft anyway (4a Assumption 3), so a lost response is safe. `outcomes` is a broadcast `Stream<SubmitOutcome>` exposed by the controller (`Stream<SubmitOutcome> get outcomes`), closed in `ref.onDispose`.

| Server code | Controller state | Sheet reaction |
|---|---|---|
| `day_taken` | `clearDay(day, taken: true)`, `bookingId: null`, `phase: idle`, `error: dayTaken`, step `datetime` | SnackBar `bookDayTaken` "Ngày này vừa có người đặt. Chọn ngày khác." |
| `phone_required` | `phase: idle` | outcome `NeedPhone` → push `/profile/phone?returnTo=<current flow path with serviceId, day>`; the provider stays alive (Task 2) |
| `price_changed` | `bookingId: null`, `phase: idle`, step `service`; invalidate `profilePackagesProvider(uid)`; `applyPackages` then marks `priceChanged` | banner on S04.01, new total on the button |
| `deadline_passed`, `not_found` (draft cleaned up between steps) | `bookingId: null`, `phase: idle` | SnackBar `bookTryAgain` "Yêu cầu đã hết hạn, thử lại nhé."; stays on S04.03 |
| `not_eligible` (payments disabled on this backend) | `phase: idle` | SnackBar `bookPaymentsOff` "Thanh toán chưa mở trên máy chủ này." |
| `network`, `unknown`, others | `phase: idle`, `error` | SnackBar `bookNetworkError` "Không gửi được. Kiểm tra mạng rồi thử lại." with action "Thử lại" calling `submit()` |

Sheet reaction to `GoToPayment`: if `realPaymentsProvider` is false, `showAppSheet` with `FakePaymentSheet` ("Cổng thanh toán giả (chỉ để thử)", amount, primary "Thanh toán thành công" → `confirmFakePayment(paymentId)`, outline "Huỷ"); else `externalLauncherProvider.launch(payUrl)`. In every case afterwards: `context.replace('/b/$bookingId/pay')` (the sheet is gone; S04.04 owns the wait). A `confirmFakePayment` error is ignored here: S04.04 shows the real status.

- [ ] **Step 1: Write the failing tests** (world helper; drive the real S04.03 UI):
  - "Đặt cọc creates the booking with the chosen values, then the deposit with the chosen provider" (fake records  `{photographerId: 'p1', serviceId: 's1', day: '2026-10-12', start: '15:30', placeName: 'Bến Bạch Đằng', note: null}` and `createDeposit('b1', vnpay)`).
  - "double tap creates one booking and one deposit".
  - "fake mode: the fake gateway sheet confirms and S04.04 opens" (tap "Thanh toán thành công" → `fakeConfirms` contains `pay_booking_1`, location `/b/booking_1/pay`).
  - "fake mode: Huỷ on the fake sheet still opens S04.04 without confirming".
  - "real mode opens payUrl with the external launcher and opens S04.04".
  - "a changed phone is saved before the booking is created" (call order on the fakes: contact save, then createBooking).
  - "day_taken returns to S04.02 and marks the day" (fake `nextError = dayTaken` → step `datetime`, the day crossed, SnackBar text).
  - "phone_required sends to S04.05 with returnTo of the current flow" (location starts `/profile/phone?returnTo=` and decodes to `/u/p1/book?serviceId=s1&date=2026-10-12`).
  - "price_changed refreshes the package and the total" (after the error, packages return the new price → S04.01 banner, button "Tiếp tục · {new price}").
  - "a network error keeps everything and Thử lại reuses the same draft" (second attempt: no second `createBooking`, one more `createDeposit`).
  - "not_eligible shows Thanh toán chưa mở trên máy chủ này".
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**; ARB keys `bookDayTaken`, `bookTryAgain`, `bookPaymentsOff`, `bookNetworkError`, `actionRetry` (reuse if it exists), `fakePayTitle`, `fakePayBody` "Bản dùng thử: không có tiền thật nào được trừ.", `fakePayConfirm`, `actionCancel` (reuse); gen-l10n.
- [ ] **Step 4: Run** `test/features/booking` → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat(booking): submit the booking and deposit with the fake gateway`.

---

### Task 7: S04.04 payment wait `/b/:id/pay`

**Files:**
- Create: `lib/features/booking/payment_pending_screen.dart`
- Modify: `lib/app/router.dart`, `lib/l10n/app_vi.arb`
- Test: `test/features/booking/payment_pending_screen_test.dart`

**Interfaces:**
- Consumes: `bookingProvider(id)` (Task 1 addition), repository `checkDeposit`, `createDeposit`, `confirmFakePayment`, `realPaymentsProvider`; core `AsyncView`, `SignatureLoader`, `BookingCard` + `bookingSummaryOf` (`lib/data/booking/booking_summary.dart`), `ProviderPicker` (shared-components-a).
- Produces: `GoRoute(path: '/b/:id/pay', builder: (_, s) => PaymentPendingScreen(bookingId: s.pathParameters['id']!))` (outside the shell, like `/p/:postId`); `class BookingPaidPanel extends StatelessWidget` (Decision 3 — plan 4c deletes it).

States (each in its own `ScreenCode(ScreenCodes.awaitingPayment)`; the paid panel is part of S04.04 until 4c). The screen renders `AsyncView(value: bookingProvider(id), onRetry: () => ref.invalidate(bookingProvider(id)), data: …)`; the rows below are AsyncView's loading/error and the `data` builder's branches:

| `bookingProvider(id)` | UI |
|---|---|
| loading (first) | AsyncView's default screen loader (`SignatureLoader`, ripple: loading data) |
| `draft` | per mock: app bar "Thanh toán"; `SignatureLoader(wave: LoaderWave.vibration)` (waiting on the gateway; its reduced-motion still state is core's, nothing extra here); `payPendingTitle`; `payPendingBody(providerName)`; `BookingCard(data: bookingSummaryOf(b, photographerName: name, statusLabel: l10n.payAwaitingDeposit /* "Chờ cọc" */), size: BookingCardSize.compact)` (name from `photographerProfileProvider`; group A's `bookingSummaryOf` takes no `statusLabel` — if it still lacks one, add the optional `String? statusLabel` parameter to it in this task, with a test, rather than building `BookingSummary` by hand); primary "Kiểm tra lại" → `checkDeposit(bookingId: id)` (`AppButton(loading: true)` while in flight; SnackBar `payNotYet` "Chưa nhận được xác nhận, thử lại sau ít phút" when `paid == false`); outline small "Đổi cổng thanh toán" → `showAppSheet` holding core's `ProviderPicker` (current provider preselected) → `createDeposit(bookingId: id, provider: other.code)` → the same payment step as Task 6 (fake sheet or launcher), staying on S04.04 |
| status other than `draft` | `BookingPaidPanel`: check icon, "Đã gửi yêu cầu" (`payRequestSent`), "{name} sẽ trả lời trong 24 giờ" (`payReplyIn24h`), deposit line `escrowNoticeHeld(amount)` "Cọc {amount} đang được giữ an toàn", primary "Xem lịch đặt" → `context.go('/bookings')` |
| `null` (draft deleted after 30 min) | `EmptyState` "Yêu cầu đã hết hạn" (`payExpiredTitle`) + body `payExpiredBody` "Chưa nhận được tiền cọc trong 30 phút nên yêu cầu đã huỷ. Nếu tiền đã bị trừ, ứng dụng tự hoàn lại." + primary "Đặt lại" → `context.go(bookingPath(photographerId: lastKnown.photographerId, serviceId: lastKnown.serviceId))` (keep the last non-null booking in state; when there never was one, "Về trang chủ" → `/home`) |
| error | AsyncView's `ErrorState` with retry (`onRetry` above) |

The screen never calls `createDeposit` except from "Đổi cổng thanh toán", and never navigates on a payment page result: only the stream decides.

- [ ] **Step 1: Write the failing tests:**
  - "first load shows the screen SignatureLoader with ripple waves" (stream not yet emitted; no `CircularProgressIndicator`).
  - "a draft shows SignatureLoader with vibration waves".
  - "a draft shows the waiting title, the body naming the gateway and the compact card with Chờ cọc".
  - "check again calls checkDeposit only" (no `createDeposit`, no `createBooking` recorded).
  - "check again with no payment yet shows the not-yet message".
  - "the server confirming the payment switches to the paid panel without a tap" (`fake.confirmFakePayment(paymentId: 'pay_booking_1')` → "Đã gửi yêu cầu").
  - "Xem lịch đặt goes to /bookings".
  - "change provider creates a deposit with the other gateway and stays on S04.04".
  - "a removed draft shows expired with Đặt lại" (`fake.remove('booking_1')` → expired copy; tap → location `/u/p1/book?serviceId=s1`).
  - "opening /b/unknown/pay with no booking shows expired with Về trang chủ".
  - "reduced motion: the SignatureLoader is in its still state (no ticker)".
  - "320 dp and 1.3× text, light and dark: no overflow".
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**; ARB keys `payTitle` "Thanh toán", `payPendingTitle`, `payPendingBody` (with `{provider}`), `payProviderFake` "Cổng thử nghiệm", `payAwaitingDeposit`, `payCheckAgain`, `payNotYet`, `payChangeProvider`, `payRequestSent`, `payReplyIn24h`, `escrowNoticeHeld`, `payViewBookings` "Xem lịch đặt", `payExpiredTitle`, `payExpiredBody`, `payBookAgain` "Đặt lại", `payGoHome` "Về trang chủ"; gen-l10n.
- [ ] **Step 4: Run** → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat(booking): S04.04 waits for the server to confirm the deposit`.

---

### Task 8: End-to-end flow test, code table and handover

**Files:**
- Create: `test/features/booking/booking_flow_e2e_test.dart`
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` (status column of S04.01–S04.04), `docs/superpowers/plans/RUN-ORDER.md` (only if the controller asks; normally the merger does it)

**Interfaces:** consumes everything above; produces no new code.

- [ ] **Step 1: Write the end-to-end widget test** on the real router with the fakes: start on S03.01 (`/u/p1`), tap "Đặt lịch" (S03.01's bottom bar uses `startBooking`) → S04.01 → choose package → S04.02 → choose a free day and `15:30` → place "Bến Bạch Đằng" → S04.03 → "Đặt cọc 450.000₫" → fake sheet "Thanh toán thành công" → S04.04 → `fake.confirm` happens inside `confirmFakePayment` → paid panel → "Xem lịch đặt" → `/bookings`. Assert the recorded repository calls in order: `createBooking`, `createDeposit(momo)`, `confirmFakePayment`.
- [ ] **Step 2: Write** "the S02.06 entry skips nothing it should not": from `/action` (customer S02.06) tap a card's "Đặt T7" → S04.02 with the day and package preselected.
- [ ] **Step 3: Run** `../scripts/bin/flutter test --no-pub` (whole suite) and `flutter analyze --no-pub` → all pass.
- [ ] **Step 4: Update the code table** in `2026-10-01-remaining-screens.md`: S04.01, S04.02, S04.03 "✅ đã làm (4b) · bước địa điểm chưa có bản đồ", S04.04 "✅ đã làm (4b) · về S05.02 khi có plan 4c". Do not edit the mock.
- [ ] **Step 5: Commit** `test(booking): end-to-end booking with the fake gateway; mark S04.01–S04.04 built`.

---

## Interfaces for plans 4c–4e

- `BookingCard`, `BookingSummary`, `EscrowNotice`, `PaymentProviderCode` are core widgets/types from `2026-10-02-shared-components-a.md`, not from this plan. This plan adds `AppSheetFrame` (core), `escrowNoticeDeposit` (ARB) and, if missing, `bookingSummaryOf(statusLabel:)`.
- `BookingPaidPanel` (`lib/features/booking/payment_pending_screen.dart`) — plan 4c deletes it and makes S04.04's non-draft state `context.go('/b/$id')`.
- `bookingPath(photographerId:, serviceId:, date:, area:)` — S05.02 "Đặt lại" (4c) uses it.
- `realPaymentsProvider` — plan I6 flips the default when the real gateway exists.

## Self-review notes

- Spec coverage: entry condition (Task 3), state kept on back (Task 2), no server write before S04.03 (Task 6 only), S04.01 states (Task 3), S04.02 states and live calendar (Task 4), place ≥ 3 (Task 5), S04.03 money, escrow, policy, provider, busy, errors (Tasks 5–6), S04.04 listen/check/change/expired/reduced motion (Task 7). Not covered by design: map in the place step (Decision 4), analytics events `book_step{n}`, `book_submit`, `book_error` — there is no analytics port in the app yet; add them when the analytics plan exists.
- Every name used in a later task is defined in an earlier task or in "Contract with plan 4a".
