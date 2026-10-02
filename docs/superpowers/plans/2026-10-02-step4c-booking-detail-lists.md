# Step 4c: Booking detail S05.02, cancel S05.03, customer list S05.01, photographer work S06.01 (+S06.02), decline S06.03 Implementation Plan

> **Battery/performance (2026-10-02, user):** no battery, idle, blur-budget or performance steps in this plan; they run once in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Keep the functional tests. (S06.01's countdown ticks are functional: test that they tick; do not profile them.)

> **Rules emulator tests (2026-10-02, user):** Task 1 changes `firestore.rules`. Write the rules and their tests in `app_flutter/firebase/rules-test/rules.test.mjs`, do not run them; CI runs them on push. Record the skip in the ledger.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** interfaces are exact; each task lists its tests by name with the expected behaviour; sample code only where it is easy to get wrong. Write the rest in the style of the surrounding files.

**Goal:** Both parties can follow and act on a booking after the deposit: the customer sees every booking grouped in S05.01 and the full detail with a 7-step timeline in S05.02 (contact, directions, cancel with the exact refund in S05.03, book again); the photographer sees today's shoot, new requests with a live deadline countdown and money tiles in S06.01 (or S06.02's single next step when empty), accepts, declines with a reason in S06.03, completes after the shoot and cancels when needed.

**Architecture:** All reads go through plan 4a's `BookingRepository` streams (`watchBooking`, `watchCustomerBookings`/`watchPhotographerBookings`, `watchBookingContact`, plus `watchEvents` added here), all writes through its `transitionBooking` call; screens never touch Firestore. Pure presentation rules live in `lib/features/booking/booking_view_rules.dart` (actions per status and role, timeline steps, booking code, S05.01 buckets, S06.01 dashboard numbers) and are unit-tested without widgets; widgets only render them. Time-dependent text (refund %, countdown) reads `clockProvider` through a small `nowTickerProvider` so tests control time. Chat ("Nhắn tin"), reschedule ("Đổi lịch") and review ("Đánh giá") are owned by plans 4d and 4e: this plan shows those buttons only when their feature flag says the target exists (`bookingFeaturesProvider`), so no button leads to a missing route.

**Tech Stack:** Flutter, Riverpod 3, go_router 18, existing core widgets (`ContactDial`, `SegmentedTabs`, `StatTile`, `EmptyState`, `AppOptionTile`, `AppChip`, `showAppSheet`, `TabBadge`) and the core widgets built by `2026-10-02-shared-components-a.md` (`AsyncView`, `SignatureLoader`, component `.skeleton()`s, `ErrorState`, `SectionHeader`, `BookingCard`/`BookingSummary`, `StatusTimeline`/`TimelineStep`, `EscrowNotice`, `MoneyBreakdown`, `PolicyTable`, `ReasonPicker`, `showConfirmSheet`, `CountdownText`).

**Spec:** `docs/superpowers/specs/screens/booking.md` (S05.02, S05.03, S05.01, S05.04); `docs/superpowers/specs/screens/photographer.md` (S06.01, S06.02, S06.03); `docs/superpowers/specs/2026-09-30-photography-marketplace-design.md` §6 (state machine, refund table, photographer cancel 100 %); `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3b (contact unlock, customer contact copy), §3d.3 (tab badge), §3g.6 (escrow lines on S05.02, "Đang giữ" on S06.01); `docs/superpowers/specs/components/shared-components.md` (`BookingCard`, `StatusTimeline`, `StatTile`, `ContactDial`, `AsyncView`, `AppSkeleton`, `PolicyTable`, `ReasonPicker`, `ConfirmSheet`, `CountdownRing`/`CountdownText`); mock `docs/design/ui-mock.html` `data-code="S05.02"`, `"S05.03"`, `"S05.01"`, `"S06.01"`, `"S06.02"`, `"S06.03"` (layout authority).

**Prerequisite:** plans 4a and 4b merged into `flutter-rewrite` (4b provides `BookingPaidPanel`, `bookingPath(area:)`, `test/support/booking_world.dart`), plan `2026-10-02-shared-components-a.md` done (RUN-ORDER row 8a2: provides `BookingCard`, `BookingSummary`, `bookingSummaryOf`, `StatusTimeline`, `EscrowNotice`, `MoneyBreakdown`, `PolicyTable`, `ReasonPicker`, `showConfirmSheet`, `CountdownText`/`CountdownRing`, `AsyncView` and the skeletons), plus every plan marked done in `RUN-ORDER.md`.

## Contract with plans 4a and 4b

Plan 4a is merged; its real Flutter API is listed in plan 4b's "Contract with plan 4a (merged code, 2026-10-02)" together with the additions plan 4b makes (`bookingProvider`, `bookingErrorOf`, `BookingErrorCode`, `daySlots`, fake call records, `nextError`, `remove`). This plan uses them and **adds in Task 1** (port + Firestore adapter + fake together, with tests):

```dart
// booking_repository.dart
enum BookingRole { customer, photographer }
enum BookingAction { accept, decline, cancel, complete }          // .code = name; passed as `action:`
/// `bookings/{id}/events`, oldest first (4a writes them; the read rule is added in Task 1).
Stream<List<BookingEventRecord>> watchEvents(String bookingId);    // new port member

// booking_providers.dart (auto-disposed variants for screens)
final myBookingsProvider = StreamProvider.autoDispose.family<List<Booking>, BookingRole>((ref, role) {
  final uid = ref.watch(authStateProvider).value?.uid;            // signed-in user
  if (uid == null) return const Stream.empty();
  final repo = ref.watch(bookingRepositoryProvider);
  return role == BookingRole.customer ? repo.watchCustomerBookings(uid) : repo.watchPhotographerBookings(uid);
});
final bookingEventsProvider = StreamProvider.autoDispose.family<List<BookingEventRecord>, String>(…watchEvents);
final bookingContactProvider = StreamProvider.autoDispose.family<BookingContactSnapshot?, String>(…watchBookingContact);

// booking_rules.dart
DateTime startsAtOf(Booking b) => BookingRules.parseBookingDateTime(b.day, b.start);
DateTime endsAtOf(Booking b) => BookingRules.parseBookingDateTime(b.day, b.end);
int refundPercentAt(Booking b, DateTime now) =>
    BookingRules.computeRefundPercent(startsAt: startsAtOf(b), cancelledAt: now, actorRole: 'customer');
int refundAmountAt(Booking b, DateTime now) => b.deposit * refundPercentAt(b, now) ~/ 100;
```

Names used below map to the real model and API: list groups → `BookingTab` (`upcoming`, `pending`, `history`) and `BookingRules.groupBookingsByTab` (this plan's "Đã xong" tab is `BookingTab.history`); a transition → `transitionBooking(bookingId:, action: action.code, reason:)`; the contact copy → `watchBookingContact` / `bookingContactProvider`; refunded amount → `depositRefunded ?? 0`; deposit → `deposit`; price → `serviceSnapshot.price`; place → `place.name`; escrow → `escrowStatus` (enum `EscrowStatus`).

From `2026-10-02-shared-components-a.md` (core, exported by `core/core.dart`; use, never recreate or restyle): `AsyncView`, `SignatureLoader`/`LoaderWave`, `BookingCard`, `BookingCardSize`, `BookingSummary` and `bookingSummaryOf(Booking, {photographerName, thumbUrl})` (`lib/data/booking/booking_summary.dart`), `StatusTimeline`/`TimelineStep`/`TimelineStepState` (semantics "Bước {n} trong {total}, {state}" built in), `EscrowNotice`, `MoneyBreakdown`/`MoneyLine`/`MoneyLineStyle`, `PolicyTable`/`PolicyRow`, `ReasonPicker`/`ReasonPickerStyle`, `showConfirmSheet`, `CountdownText`, `SectionHeader`, `StatTile.skeleton`. From plan 4b: `BookingPaidPanel`, `bookingPath`, `pumpBookingRoute` in `test/support/booking_world.dart`, ARB `escrowNoticeHeld`. From earlier plans: `ContactDial({required ContactAccess access, required ContactChannels channels, required ValueChanged<ContactChannel> onSelected, ContactDialStyle style, bool busy})` (`lib/core/widgets/contact_dial.dart`), `ContactChannel`, `ContactNumbers`, `contactUriFor` (`lib/data/contact/contact_link_repository.dart`), `externalLauncherProvider`, `contactLauncherProvider` (customer → photographer through `getContactLink`), `photographerProfileProvider`, `userRepositoryProvider` (`watch(uid)` → `displayName`, `avatarUrl`), `currentProfileProvider` (role), `tabBadgesProvider` (`lib/features/shell/tab_badges.dart`), `ScreenCodes.bookingDetail` (S05.02), `cancelBooking` (S05.03), `bookings` (S05.01), `work` (S06.01), `workEmpty` (S06.02), `declineRequest` (S06.03), `clockProvider`, `calendarTodayProvider`, `formatMoney`, `formatDayMonth`, `weekdayLabel`.

Known 4a gap fixed here (Task 1): 4a writes the timeline to `bookings/{id}/events/{eventId}` but `firestore.rules` has no match for it, so the catch-all denies clients and S05.02's timeline could never load. Task 1 adds a read rule for the two parties.

## Global Constraints

- S05.02: "**Dữ liệu**: `bookingProvider(id)` lắng nghe thời gian thực"; "Phía NAG hiển thị số khách chỉ sau cọc (qua `ContactDial`)"; "theo `status` … hành động hiện khác nhau; hôm diễn ra → nút "Chỉ đường"; sau `endTime` NAG có "Hoàn thành"". Action table:

  | Trạng thái | Hành động khách | Hành động NAG |
  |---|---|---|
  | `requested` | Liên hệ, Huỷ | Nhận, Từ chối (S06.03) |
  | `accepted`/`upcoming` | Liên hệ, Đổi lịch, Chỉ đường, Huỷ | Liên hệ, Đổi lịch, Hoàn thành (sau giờ), Huỷ |
  | `declined`/`expired`/`cancelled` | Đặt lại | — |
  | `completed` | Đánh giá (S05.05) | — |
  | `reviewed` | Xem đánh giá | — |

- S05.02 strings: `s09_title` "Buổi chụp #{code}", `s09_contact` "Liên hệ", `s09_reschedule` "Đổi lịch", `s09_cancel` "Huỷ yêu cầu · hoàn cọc {pct}%", `s09_directions` "Chỉ đường"; escrow lines "khách: "Cọc {số tiền} đang được giữ an toàn"; NAG: "Cọc {số tiền} đang được giữ, chuyển cho bạn sau khi hoàn thành""; "timeline đúng thứ tự và thời điểm; số hoàn trên nút huỷ khớp bảng chính sách theo giờ hiện tại; trạng thái đổi theo thời gian thực không cần tải lại".
- S05.03: "bảng hoàn cọc 3 dòng (≥ 48 giờ 100% · 24–48 giờ 50% · < 24 giờ 0%) với **dòng đang áp dụng được tô**; "Bạn sẽ nhận lại {số tiền}"; chip lý do (Đổi kế hoạch, Tìm được thợ khác, Lý do khác); hai nút: "Giữ lịch" (viền, bên trái) và "Huỷ buổi chụp" (đỏ, bên phải)"; "huỷ thành công → đóng, S05.02 hiện `cancelled`, toast "Đã huỷ. Hoàn {số tiền} trong 3–5 ngày""; "nút đỏ chỉ có trong sheet này; hoàn đúng theo thời điểm; chạm ngoài sheet không huỷ". Strings `s10_title` "Huỷ buổi chụp?", `s10_refund` "Bạn sẽ nhận lại {amount}", `s10_keep` "Giữ lịch", `s10_confirm` "Huỷ buổi chụp".
- S05.01: "`SegmentedTabs` Sắp tới / Đang chờ / Đã xong **và** cấp trên cùng "Buổi chụp | Vé sự kiện""; "danh sách `BookingCard` có hàng hành động dưới thẻ gần nhất (Chỉ đường, Nhắn tin) hoặc "Đánh giá" cho buổi chưa review"; "mỗi nhóm trống có hành động riêng ("Tìm nhiếp ảnh gia" / "Chưa có yêu cầu chờ" / "Chưa có buổi nào xong"); offline đọc cache"; "chạm thẻ → S05.02; nhóm theo đúng `status`; badge đúng màu và chữ". Strings `s14_title` "Đặt lịch", `s14_upcoming` "Sắp tới", `s14_pending` "Đang chờ", `s14_done` "Đã xong", `s14_review` "Đánh giá".
- S06.01: "tiêu đề "Thứ 5, 10/10" + biểu tượng lịch; **thẻ buổi hôm nay** (`BookingCard` lớn, viền spectrum, ảnh phủ chữ, nút "Nhắn tin" và "Chỉ đường"); section "Yêu cầu mới" kèm số; thẻ yêu cầu (avatar khách, gói, ngày giờ, địa điểm, giá, ghi chú trích, "đã cọc 450K", `ContactDial`, nút "Từ chối" và "Nhận · còn 22 giờ"); hàng `StatTile` ×3 (Tháng này · **Đang giữ** · Buổi sắp tới)"; "không có buổi hôm nay → ẩn thẻ; không yêu cầu → "Không có yêu cầu mới"; toàn bộ trống → S06.02; yêu cầu quá `acceptDeadline` → thẻ biến mất và toast "Yêu cầu {tên} đã hết hạn, đã hoàn cọc"; offline … nút Nhận/Từ chối vô hiệu"; "đếm ngược cập nhật mỗi phút (mỗi giây khi còn < 1 giờ)"; "ba ô số liệu cùng một hàng, cùng chiều cao, nhãn không xuống dòng ở 320dp và chữ 1,3×; chấm số tab khớp số yêu cầu". Strings `s19_today` "Hôm nay", `s19_requests` "Yêu cầu mới", `s19_accept` "Nhận · còn {time}", `s19_decline` "Từ chối", `s19_month` "Tháng này", `s19_held` "Đang giữ", `s19_upcoming` "Buổi sắp tới".
- S06.02: "`EmptyState`: minh hoạ tròn, "Buổi chụp tiếp theo bắt đầu từ đây", một câu dựa vào số ảnh hiện có, một nút"; "chưa đủ 6 ảnh → "Thêm ảnh vào portfolio" (→ S10.01); chưa có gói → "Thêm gói" (→ S08.01); `completeness` < 70 → "Hoàn thiện kỹ năng" (→ S08.02); còn lại → "Chia sẻ hồ sơ""; strings `s22_title`, `s22_bodyPortfolio` "Hồ sơ có 6 ảnh và 1 gói được đặt nhiều gấp 3 lần. Bạn đang có {n} ảnh.", `s22_addPhotos` "Thêm ảnh vào portfolio".
- S06.03: "lý do chọn đơn (Kín lịch hôm đó, Ngoài khu vực phục vụ, Gói không phù hợp nhu cầu, Lý do khác → ô nhập ngắn); dòng "{tên} được hoàn cọc {số tiền} và nhận lý do này."; "Quay lại" (viền) + "Từ chối" (đỏ)"; "chưa chọn lý do → nút đỏ vô hiệu; "Lý do khác" cần ≥ 5 ký tự; đang gọi → loading; thành công → toast và thẻ biến khỏi S06.01"; strings `s23_title` "Từ chối yêu cầu của {name}?", `s23_reasonBusy`, `s23_reasonArea`, `s23_reasonService`, `s23_reasonOther`, `s23_refundNote` "{name} được hoàn cọc {amount} và nhận lý do này.", `s23_confirm` "Từ chối".
- S05.04 (contact): "một kênh khả dụng → bấm nút mở thẳng kênh đó, không bung; không kênh ngoài nào → ẩn nút Liên hệ"; customer side uses `getContactLink` (no number in the app); photographer side reads `customerContact` (the contact copy) — 4a Assumption 18.
- Spec keys map to camelCase ARB keys in `lib/l10n/app_vi.arb` (prefixes `detail*`, `cancel*`, `bookings*`, `work*`, `decline*`); full Vietnamese diacritics; `flutter gen-l10n`.
- CLAUDE.md: one primary action per screen (S05.02's two main buttons "Nhắn tin" + "Liên hệ" are outline/dial per the mock; the only `AppButton.primary` on S05.02 is the photographer's "Nhận" / "Hoàn thành" or the customer's "Đặt lại"/"Đánh giá" when present); cancel/decline is a red button inside a confirmation sheet, never the gradient; tokens only; `package:photobooking/...` imports; features import `core/core.dart`; no Firebase in features; every screen state in `ScreenCode`.
- Loading (shared-components-a): every `AsyncValue` renders through `AsyncView` with the skeleton of the component that will appear (S05.01: 3× `BookingCard.skeleton()`; S05.02: `StatusTimeline.skeleton()` + `BookingCard.skeleton()`; S06.01: `BookingCard.skeleton()` ×2 + 3× `StatTile.skeleton()`); no `CircularProgressIndicator`, no hand-written `.when(loading:`. A screen-level wait with no known shape uses `SignatureLoader` (ripple). Buttons in flight use `AppButton(loading: true)` or `showConfirmSheet`'s own running state.
- Skeletons are white only (no aurora or other color, dark theme included); loaders and `AsyncView` have no colored backdrop. Both are owned by core: screens must not restyle, tint or wrap them in a colored container.
- Cancel and decline (S05.03, S06.03, the photographer cancel) are `showConfirmSheet` with `PolicyTable` / `ReasonPicker` / `MoneyBreakdown` as its `content`; deadlines (S06.01 and S05.02 "Nhận · còn {time}") tick through `CountdownText`. No hand-made confirmation sheet or timer.
- Tests: phone-sized view (390 × 844, dpr 1) in pump helpers; explicit 320 dp / 1.3× tests where named; `retry: (_, _) => null` on every test container/scope; `AppButton` height 48.
- Commands from `app_flutter/` as in plan 4b. Commits: Conventional Commits ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push.

## Decisions (where the spec is silent)

1. **Booking code** "#A1F3" = the last 4 characters of the booking id, upper-cased (ULIDs are base32, so the code is readable). Pure function `bookingCode(String id)`.
2. **Timeline (7 steps)**, per mock: 1 "Đã gửi & đặt cọc" (`requested` event; sub-line date-time · deposit), 2 "Chờ {photographer} nhận" (sub-line "Thường trong 1 giờ"; while `requested` it is the current step), 3 "Đã xác nhận" (`accepted`; sub-line "Nhắn tin để chốt chi tiết"), 4 "Sắp tới · {T7 12/10}" (`upcoming`; "Nhắc trước 24 giờ"), 5 "Buổi chụp" (current between `startsAt` and `endsAt` or after `endsAt` until completed), 6 "Hoàn thành" ("Trả {remaining} tại chỗ" before; completion time after), 7 "Đánh giá & chia sẻ ảnh" (`reviewed`). For `declined`/`expired`/`cancelled` the timeline stops at the last reached step and adds a final red-text step "Đã từ chối" / "Hết hạn, đã hoàn cọc" / "Đã huỷ · hoàn {amount}". The steps are rendered by core's `StatusTimeline` (built by shared-components-a); this plan only computes the `TimelineStep` list.
3. **Directions** opens `https://www.google.com/maps/search/?api=1&query=<place name>` through `externalLauncherProvider` (no coordinates in v1; Google Maps opens on Android and iOS, and a browser otherwise). Shown on the booking day (Vietnam) and the day before for `accepted`/`upcoming`; S05.01 shows it on the nearest upcoming card.
4. **Photographer contact to the customer** (S05.02, S06.01): `ContactDial` with channels from the contact copy (`call` when `phone != null`, `zalo` when `allowZalo`, `whatsapp` when `allowWhatsApp`), URL built locally with `contactUriFor` from the copy's number (the rules already let only this photographer read it, only while unlocked). When the copy is null (locked/redacted) the button is hidden.
5. **Photographer cancel** reuses the S05.03 sheet (`showConfirmSheet`) in a photographer variant: title "Huỷ buổi chụp với {customer}?", no `PolicyTable`, the line "{customer} được hoàn cọc {amount} (100%).", reason chips "Ốm/việc gấp", "Thiết bị gặp sự cố", "Lý do khác"; same two buttons.
6. **"Tháng này"** = sum of `serviceSnapshot.price` of the photographer's bookings `completed`/`reviewed` with `completedAt` in the current Vietnamese month (payments are not readable by clients in 4a). **"Đang giữ"** = sum of `deposit − (depositRefunded ?? 0)` over bookings whose `escrowStatus` is `held`, `partially_refunded` or `disputed`. **"Buổi sắp tới"** = count of `accepted` + `upcoming`. Money tiles use `formatMoney(v, short: true)` ("12,4M"). Tapping "Đang giữ" does nothing until S06.05 exists (no dead route).
7. **Feature flags for later plans:** `final bookingFeaturesProvider = Provider<BookingFeatures>((_) => const BookingFeatures(chat: false, reschedule: false, review: false));`. "Nhắn tin" shows when `chat && booking.chatId != null`; "Đổi lịch" menu item when `reschedule`; "Đánh giá"/"Xem đánh giá" when `review`. Plans 4d and 4e flip their flag and add the routes.
8. **S05.01 top level "Buổi chụp | Vé sự kiện"** is hidden until event tickets exist (S11.04, events plan); the hook is one boolean in the screen (`showTickets: false`).
9. **S06.01 "Sự kiện của tôi"** section is hidden until events exist.
10. **S04.04 after paid** (plan 4b Decision 3): this plan deletes `BookingPaidPanel` and makes S04.04's non-draft state `context.go('/b/$id')`; S05.02 shows the toast "Cọc {amount} đang được giữ an toàn. {name} sẽ trả lời trong 24 giờ." once when opened with `?paid=1`.
11. **Expired-request toast on S06.01** fires when a booking that was `requested` in the previous emission arrives as `expired` (customer name from the contact copy cached in the view model).
12. **Accept** calls `transitionBooking(action: 'accept')` then stays on/opens S05.02 (the spec's "rồi mở chat" belongs to plan 4d, which changes the destination when `chat` is on).

## Review Focus

1. The policy boundary passes while S05.02 or S05.03 is open (e.g. 48 h before start ticks by) → the button text and S05.03's highlighted row and amount update without reopening; the server's answer is the truth if they still disagree. Pinned by Task 4 ("the refund line follows the clock across 48 h") and Task 3 ("cancel button percent updates when the clock passes 48 h").
2. The photographer taps "Nhận" exactly when the deadline passes or the customer cancels at the same time → the server refuses (`deadline_passed`/`not_eligible`), the card disappears or updates from the stream, and a clear SnackBar explains; no stale enabled button remains. Pinned by Task 6 ("accept refused with deadline_passed shows the expired message and the card leaves").
3. Contact copy becomes unreadable (cancelled, or 30 days after completion) while S05.02 is open → the photographer's Liên hệ disappears instead of failing on tap. Pinned by Task 3 ("photographer contact hides when the copy becomes null").
4. A customer with many bookings across statuses, including drafts and a booking in the past still `accepted` (system has not swept yet) → drafts never listed, each status in the right S05.01 group, sorted as Assumption 15 says. Pinned by Task 2 ("buckets and ordering") and Task 5 ("drafts never appear").
5. 320 dp with 1.3× text on S06.01 → the three tiles stay on one row with equal height and single-line labels; the request card's two buttons stay side by side or wrap without overflow. Pinned by Task 6 ("320 dp 1.3×: tiles one row, equal height").

---

## File Structure

| File | Responsibility |
|---|---|
| `app_flutter/firebase/firestore.rules`, `rules-test/rules.test.mjs` (modify) | read rule for `bookings/{id}/events` |
| `lib/data/booking/*` (modify only if the contract check finds gaps) | 4a port/adapter/fake members |
| `lib/features/booking/booking_features.dart` (create) | `BookingFeatures`, `bookingFeaturesProvider`, `nowTickerProvider` |
| `lib/features/booking/booking_view_rules.dart` (create) | pure rules: actions, timeline, code, buckets, dashboard numbers, countdown text |
| `lib/features/booking/booking_detail_screen.dart` (create) | S05.02 |
| `lib/features/booking/cancel_sheet.dart` (create) | S05.03 (customer) + photographer variant |
| `lib/features/booking/decline_sheet.dart` (create) | S06.03 |
| `lib/features/booking/my_bookings_screen.dart` (create) | S05.01 |
| `lib/features/work/work_screen.dart`, `work_dashboard.dart`, `work_empty.dart` (create) | S06.01, its view model, S06.02 |
| `lib/features/booking/payment_pending_screen.dart` (modify) | remove `BookingPaidPanel`, go to S05.02 |
| `lib/features/shell/placeholder_tabs.dart`, `tab_badges.dart` (modify) | `/bookings` shows S05.01 or S06.01; work badge |
| `lib/app/router.dart` (modify) | `/b/:id`, `/b/:id/cancel`, `/b/:id/decline` |
| `lib/l10n/app_vi.arb` (+ generated) | strings |
| `test/support/booking_world.dart` (extend) | seeding helpers for both roles |
| `test/features/booking/*`, `test/features/work/*` | per task |

---

### Task 1: Contract check, events read rule, flags and ticker

**Files:**
- Modify: `app_flutter/firebase/firestore.rules`, `app_flutter/firebase/rules-test/rules.test.mjs`; 4a files only if gaps are found
- Create: `lib/features/booking/booking_features.dart`
- Test: `test/features/booking/booking_features_test.dart`

`StatusTimeline`/`TimelineStep` already exist in core (shared-components-a); this task does not create or change them.

**Interfaces:**
- Produces:

```dart
@immutable class BookingFeatures { const BookingFeatures({required this.chat, required this.reschedule, required this.review}); final bool chat, reschedule, review; }
final bookingFeaturesProvider = Provider<BookingFeatures>((ref) => const BookingFeatures(chat: false, reschedule: false, review: false));

/// "Now" that re-emits every [period]; widgets showing time-dependent text watch it.
final nowTickerProvider = StreamProvider.autoDispose.family<DateTime, Duration>((ref, period) async* {
  final now = ref.watch(clockProvider);
  yield now();
  yield* Stream.periodic(period, (_) => now());
});
```

Rules addition (inside `match /bookings/{bookingId}`):

```
match /events/{eventId} {
  allow read: if signedIn()
    && (get(/databases/$(database)/documents/bookings/$(bookingId)).data.customerId == request.auth.uid
        || get(/databases/$(database)/documents/bookings/$(bookingId)).data.photographerId == request.auth.uid);
  allow write: if false;
}
```

- [ ] **Step 1: Add the Task 1 additions** listed under "Contract" with tests (`test/data/booking/booking_events_test.dart`: "watchEvents maps bookings/{id}/events oldest first" with `fake_cloud_firestore`; "myBookingsProvider follows the role and the signed-in user"; "refundPercentAt at 48 h, 47 h 59 min, 24 h, 23 h 59 min"); `../scripts/bin/flutter test --no-pub test/data/booking` → PASS.
- [ ] **Step 2: Write rules tests** (do not run): "booking events are readable by both parties and nobody else"; "clients cannot write booking events".
- [ ] **Step 3: Write failing widget/unit tests:**
  - `booking_features_test.dart`: "all flags are off by default"; "nowTickerProvider emits the clock now and again after each period" (fake async).
- [ ] **Step 4: Run** → FAIL. **Step 5: Implement** + rules + ARB; gen-l10n. **Step 6: Run** → PASS; analyze clean.
- [ ] **Step 7: Commit** `feat(booking): booking feature flags, a now ticker and a read rule for booking events`.

---

### Task 2: Pure view rules

**Files:**
- Create: `lib/features/booking/booking_view_rules.dart`
- Test: `test/features/booking/booking_view_rules_test.dart`

**Interfaces:**
- Consumes: contract types, `BookingFeatures`, core `TimelineStep`/`TimelineStepState`.
- Produces:

```dart
String bookingCode(String id);                                  // Decision 1

enum DetailAction { contact, message, reschedule, directions, cancel, accept, decline, complete, bookAgain, review, viewReview }
/// Actions shown on S05.02 for [role] at [now], already filtered by [features] and Decision 3's day window.
List<DetailAction> detailActions(Booking b, BookingRole role, DateTime now, BookingFeatures features);

/// The 7 (or fewer + stopped) steps of Decision 2. Text comes from [l]; times from [events].
List<TimelineStep> timelineSteps(Booking b, List<BookingEventRecord> events, DateTime now, AppLocalizations l,
    {required String photographerName});

/// S05.01: bookings of one group, drafts removed, sorted per 4a Assumption 15.
List<Booking> bucket(List<Booking> all, BookingTab tab);   // uses BookingRules.groupBookingsByTab, then sorts per 4a Assumption 15

@immutable class WorkDashboard {
  final Booking? today;                 // accepted/upcoming on today's Vietnamese date, earliest start
  final List<Booking> requests;         // requested, soonest acceptDeadline first
  final int monthRevenueVnd, heldVnd, upcomingCount;   // Decision 6
  bool get isEmpty;                     // no today, no requests, no upcoming
}
WorkDashboard workDashboard(List<Booking> mine, DateTime now);

/// "22 giờ" / "45 phút" / "59 giây" for "Nhận · còn {time}"; null when zero or negative.
/// Called from core's `CountdownText(builder: (c, left) => …)`, which owns the ticking
/// (every minute, every second under an hour) — no tick logic in this file.
String? countdownLabel(Duration left, AppLocalizations l);
```

- [ ] **Step 1: Write the failing tests:**
  - "booking code is the last 4 id characters upper-cased".
  - `detailActions`, one test per table row and role: requested/customer → `[contact, cancel]`; requested/photographer → `[accept, decline]`; accepted/customer the day before → `[contact, directions, cancel]` (reschedule absent while flag off, present when on); accepted/photographer before `endsAt` → `[contact, cancel]`, after `endsAt` → `[contact, complete]` and no cancel after `startsAt`; declined/expired/cancelled customer → `[bookAgain]`, photographer → `[]`; completed customer → `[]` with review off, `[review]` with review on; reviewed → `[viewReview]` with review on; `message` only when chat on and `chatId != null`; customer cancel absent at or after `startsAt`.
  - `timelineSteps`: "requested: step 1 done with time and deposit, step 2 current"; "accepted: steps 1–3 done, 4 upcoming with the date"; "upcoming during the shoot: step 5 current"; "completed: 1–6 done with completion time, 7 upcoming"; "reviewed: all done"; "cancelled after acceptance: steps 1–3 done then a stopped 'Đã huỷ · hoàn 225.000₫'"; "expired: stopped 'Hết hạn, đã hoàn cọc'".
  - `bucket`: "buckets and ordering" — mixed list (draft, requested ×2, accepted, upcoming, completed, reviewed, declined, expired, cancelled) → upcoming `[upcoming(nearer), accepted(later)]` by start ascending, pending by start ascending, done by `updatedAt` descending; drafts in none.
  - `workDashboard`: "today is the earliest accepted/upcoming booking on today's date"; "requests sorted by deadline, expired ones excluded"; "month revenue counts completed this Vietnamese month only (boundary 00:00 +07:00)"; "held sums deposit minus refunded for held, partially refunded and disputed"; "isEmpty when nothing is happening even if old completed bookings exist".
  - `countdownLabel`: "22 giờ, 45 phút, 59 giây, then null".
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** (+ ARB keys used by the timeline steps and countdown labels — `StatusTimeline`'s own semantics strings come from core: `timelineSent`, `timelineWaiting`, `timelineWaitingHint` "Thường trong 1 giờ", `timelineConfirmed`, `timelineConfirmedHint`, `timelineUpcoming`, `timelineUpcomingHint` "Nhắc trước 24 giờ", `timelineShoot`, `timelineDone`, `timelinePayAtShoot` "Trả {amount} tại chỗ", `timelineReview` "Đánh giá & chia sẻ ảnh", `timelineDeclined`, `timelineExpired`, `timelineCancelled`, `countdownHours`, `countdownMinutes`, `countdownSeconds`). **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(booking): pure rules for booking actions, timeline, lists and the work dashboard`.

---

### Task 3: S05.02 booking detail `/b/:id`

**Files:**
- Create: `lib/features/booking/booking_detail_screen.dart`
- Modify: `lib/app/router.dart`, `lib/features/booking/payment_pending_screen.dart`, `lib/l10n/app_vi.arb`, `test/support/booking_world.dart`
- Test: `test/features/booking/booking_detail_screen_test.dart`, `test/features/booking/payment_pending_screen_test.dart` (update)

**Interfaces:**
- Consumes: `bookingProvider(id)`, `bookingEventsProvider`, `bookingContactProvider`, repository `transitionBooking`; `photographerProfileProvider`, `userRepositoryProvider`, `currentProfileProvider` (role via `booking.customerId == uid`), `contactLauncherProvider`, `externalLauncherProvider`, `nowTickerProvider(const Duration(minutes: 1))`, Task 2 rules, `ContactDial`; core `AsyncView`, `StatusTimeline`, `BookingCard` + `bookingSummaryOf`, `EscrowNotice`, `CountdownText` (shared-components-a).
- Produces: `GoRoute(path: '/b/:id', builder: (_, s) => BookingDetailScreen(bookingId: s.pathParameters['id']!, justPaid: s.uri.queryParameters['paid'] == '1'))`, plus `/b/:id/cancel` and `/b/:id/decline` building the same screen with `openSheet: DetailSheet.cancel | DetailSheet.decline` (the sheet opens after the first frame). Routes sit outside the shell.

Layout per mock: app bar Back + "Buổi chụp #{code}" + `…` menu (only when it has items: "Đổi lịch" when the flag is on); toast line (Decision 10, once); `EscrowNotice` while deposit is held (customer `escrowNoticeHeld(amount)`, photographer `escrowNoticeHeldPhotographer(amount)` "Cọc {amount} đang được giữ, chuyển cho bạn sau khi hoàn thành"); `BookingCard(data: bookingSummaryOf(b, photographerName: …))` with `StatusBadge`; `StatusTimeline(steps: timelineSteps(…))`; actions: the row "Nhắn tin" (outline, flag) + `ContactDial` "Liên hệ"; the primary button for `accept` ("Nhận · còn {time}" — the label is built inside `CountdownText(deadline: b.acceptDeadline!, builder: (c, left) => AppButton.primary(label: l10n.detailAccept(countdownLabel(left, l10n)!), loading: accepting))`), `complete` ("Hoàn thành"), `bookAgain` ("Đặt lại" → `bookingPath`), `review` (flag); decline as outline "Từ chối" → S06.03; cancel as a red **text** button "Huỷ yêu cầu · hoàn cọc {pct}%" (customer, from `refundPercentAt`) or "Huỷ buổi chụp" (photographer) → S05.03. Every state in `ScreenCode(ScreenCodes.bookingDetail)`. The booking renders through `AsyncView(value: bookingProvider(id), skeleton: (_) => Column(children: [BookingCard.skeleton(), StatusTimeline.skeleton(steps: 7)]), onRetry: () => ref.invalidate(bookingProvider(id)), data: …)`; the timeline part reads `bookingEventsProvider` through its own `AsyncView` with `StatusTimeline.skeleton(steps: 7)`; not found / not a party → `EmptyState` "Không tìm thấy buổi chụp" with "Về trang chủ"; stream error → AsyncView's `ErrorState` with retry. In-flight transitions show `AppButton(loading: true)` on the tapped button. `transitionBooking` errors → SnackBar by code (`deadline_passed` "Yêu cầu đã hết hạn", `not_eligible` "Không còn thực hiện được thao tác này", `conflict` "Buổi chụp vừa thay đổi, đã tải lại", network "Không gửi được. Thử lại nhé.").

S04.04 change: replace `BookingPaidPanel` with `context.go('/b/$id?paid=1')` on the first non-draft emission; delete the panel and its strings/tests that only it used.

- [ ] **Step 1: Write the failing tests** (seed bookings through the fake; both roles):
  - "first load shows BookingCard.skeleton and StatusTimeline.skeleton" (no `CircularProgressIndicator`).
  - "customer, requested: title #code, toast after payment, held escrow line, card with Đã gửi, timeline step 2 current, Liên hệ dial and the cancel text with 100%".
  - "cancel button percent updates when the clock passes 48 h" (advance the fake clock past `startsAt − 48 h` and pump the ticker → "50%").
  - "customer Liên hệ asks the server for the link (contactLauncher) and never shows a number".
  - "photographer, requested: Nhận with countdown is the only primary button; Từ chối opens S06.03" (S06.03 sheet content asserted in Task 6).
  - "photographer accept calls transitionBooking(accept) and the screen follows the stream to accepted".
  - "photographer contact uses the contact copy channels and builds tel:/zalo.me locally" (copy with `allowZalo: true` → dial shows Gọi and Zalo; tap Gọi → launcher received `tel:+84903123456`).
  - "photographer contact hides when the copy becomes null" (fake emits null).
  - "Hoàn thành appears for the photographer only after the end time and calls transitionBooking(complete)".
  - "Chỉ đường appears on the booking day and opens Google Maps search for the place".
  - "declined shows Đặt lại which opens the booking sheet for the same package".
  - "Nhắn tin and Đổi lịch stay hidden while their flags are off; appear when on (chatId present)".
  - "deadline_passed from accept shows Yêu cầu đã hết hạn".
  - "a booking of someone else shows Không tìm thấy buổi chụp".
  - "/b/b1/cancel opens S05.02 with the cancel sheet".
  - "320 dp, 1.3× text, light and dark: no overflow; the dial does not cover the primary button".
  - S04.04 update: "the server confirming the payment opens S05.02 with the paid toast".
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** (+ ARB `detailTitle`, `detailPaidToast`, `escrowNoticeHeldPhotographer`, `detailContact`, `detailMessage`, `detailReschedule`, `detailDirections`, `detailCancelCustomer`, `detailCancelPhotographer`, `detailAccept`, `detailDecline`, `detailComplete`, `detailBookAgain`, `detailReview`, `detailViewReview`, `detailNotFound`, error strings). **Step 4: Run** → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat(booking): S05.02 booking detail with timeline and role actions`.

---

### Task 4: S05.03 cancel sheet (customer and photographer)

**Files:**
- Create: `lib/features/booking/cancel_sheet.dart`
- Modify: `lib/features/booking/booking_detail_screen.dart`, `lib/l10n/app_vi.arb`
- Test: `test/features/booking/cancel_sheet_test.dart`

**Interfaces:**
- Consumes: `refundPercentAt`, `refundAmountAt`, `startsAtOf` (Task 1), repository `transitionBooking(action: 'cancel', reason:)`, `nowTickerProvider(const Duration(minutes: 1))`; core `showConfirmSheet`, `PolicyTable`/`PolicyRow`, `ReasonPicker`, `MoneyBreakdown`/`MoneyLine` (shared-components-a).
- Produces: `Future<bool?> showCancelSheet(BuildContext context, {required Booking booking, required BookingRole role, required String counterpartName})` — returns true after a successful cancel; S05.02 then shows the toast `cancelDoneToast` "Đã huỷ. Hoàn {amount} trong 3–5 ngày" (customer) or `cancelDonePhotographer` "Đã huỷ. {name} được hoàn cọc 100%".

`showCancelSheet` is a thin wrapper over core's `showConfirmSheet(context, title: …, content: _CancelContent(…), confirmLabel: l10n.cancelConfirm, keepLabel: l10n.cancelKeep, danger: true, onConfirm: () => repo.transitionBooking(bookingId: b.id, action: 'cancel', reason: reason.value))` — no sheet of its own. `_CancelContent` is a small `ConsumerStatefulWidget` that watches `nowTickerProvider` and writes the chosen reason into a `ValueNotifier<String?>` the `onConfirm` closure reads.

Customer variant per mock, inside `content`: `PolicyTable(rows: [PolicyRow(when: l10n.cancelRow100(dd/MM HH:mm) /* "Trước {dd/MM HH:mm} hơn 48 giờ" */, outcome: l10n.cancelRefund100), PolicyRow(when: l10n.cancelRow50 /* "Trong 24–48 giờ" */, outcome: l10n.cancelRefund50), PolicyRow(when: l10n.cancelRow0 /* "Dưới 24 giờ" */, outcome: l10n.cancelRefund0 /* "Không hoàn" */)], activeIndex: {100: 0, 50: 1, 0: 2}[refundPercentAt(b, now)]!)`; `MoneyBreakdown(lines: [MoneyLine(label: l10n.cancelYouGetBack /* "Bạn sẽ nhận lại" */, vnd: refundAmountAt(b, now), style: MoneyLineStyle.strong)])`; `ReasonPicker(reasons: [cancelReasonPlans, cancelReasonFound, cancelReasonOther], style: ReasonPickerStyle.chips, otherLabel: l10n.cancelReasonOther, otherMaxLength: 200, …)` (optional). Bottom row is ConfirmSheet's: "Giữ lịch" (outline, left) + "Huỷ buổi chụp" (red, right, its inline loader while `onConfirm` runs; the sheet is locked meanwhile). Barrier tap and drag never cancel (`showConfirmSheet` returns false). Photographer variant per Decision 5 (same wrapper, `PolicyTable` omitted, `MoneyBreakdown` line "{customer} được hoàn cọc" with the full deposit, its own reasons). Errors → ConfirmSheet's SnackBar inside the sheet, sheet stays.

- [ ] **Step 1: Write the failing tests:**
  - "uses showConfirmSheet with PolicyTable, MoneyBreakdown and ReasonPicker (no hand-made sheet)".
  - "highlights the 100 % row more than 48 h before and shows the full deposit back" (`PolicyTable.activeIndex == 0`).
  - "exactly 48 h before still highlights 100 %; 47 h 59 min highlights 50 % and halves the amount".
  - "under 24 h highlights Không hoàn and shows 0₫ back".
  - "the refund line follows the clock across 48 h" (sheet open, advance clock → highlight and amount change).
  - "Giữ lịch closes without calling the server; tapping outside does not cancel".
  - "double tap on Huỷ buổi chụp sends one transition".
  - "Huỷ buổi chụp sends the chosen reason and closes with true" (fake records a `transitionBooking(bookingId: 'b1', action: 'cancel', reason: 'Đổi kế hoạch')` call).
  - "Lý do khác sends the typed text, capped at 200".
  - "a server error keeps the sheet open with a SnackBar".
  - "photographer variant shows 100 % refund to the customer and its own reasons".
  - "320 dp, 1.3×: rows and buttons fit".
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** (+ ARB `cancelTitle`, `cancelRow100`, `cancelRow50`, `cancelRow0`, `cancelRefund100`, `cancelRefund50`, `cancelRefund0`, `cancelYouGetBack` "Bạn sẽ nhận lại" (label for `MoneyLine`, no placeholder), `cancelReasonPlans` "Đổi kế hoạch", `cancelReasonFound` "Tìm được thợ khác", `cancelReasonOther` "Lý do khác", `cancelKeep`, `cancelConfirm`, `cancelTitlePhotographer`, `cancelRefundPhotographer`, `cancelReasonSick` "Ốm/việc gấp", `cancelReasonGear` "Thiết bị gặp sự cố", `cancelDoneToast`, `cancelDonePhotographer`). **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(booking): S05.03 cancel sheet with the live refund policy`.

---

### Task 5: S05.01 customer bookings and the `/bookings` tab

**Files:**
- Create: `lib/features/booking/my_bookings_screen.dart`
- Modify: `lib/features/shell/placeholder_tabs.dart` (`BookingsTab` → S05.01 for customers, S06.01 for photographers after Task 6; until then photographers keep the current empty state), `lib/l10n/app_vi.arb`
- Test: `test/features/booking/my_bookings_screen_test.dart`, `test/features/shell/*` (update expectations that assumed the empty state)

**Interfaces:**
- Consumes: `myBookingsProvider(BookingRole.customer)` (Task 1), Task 2 `bucket`, `detailActions` for the nearest card's row, core `AsyncView`, `BookingCard` + `bookingSummaryOf` (shared-components-a), `SegmentedTabs`, `photographerProfileProvider` (names/avatars per card; watch per visible card).
- Produces: `class MyBookingsScreen extends ConsumerStatefulWidget` (tab root: `centerTitle: false`, `tabRootTitleStyle`, title `bookingsTitle` "Đặt lịch", chat icon only when the chat flag is on).

Per mock: segmented "Sắp tới / Đang chờ / Đã xong" (selected tab remembered in the widget state); list of `BookingCard`s; the first card of "Sắp tới" gets the row "Chỉ đường" (outline small) + "Nhắn tin" (flag); cards in "Đã xong" that are `completed` get "Đánh giá" (flag). Tap → `/b/:id`. Empty per group: "Sắp tới" → `EmptyState` "Chưa có buổi chụp sắp tới" + "Tìm nhiếp ảnh gia" (→ `/action`); "Đang chờ" → "Chưa có yêu cầu chờ"; "Đã xong" → "Chưa có buổi nào xong". The list renders through `AsyncView(value: myBookingsProvider(BookingRole.customer), skeleton: (_) => Column(children: [for (var i = 0; i < 3; i++) BookingCard.skeleton()]), onRetry: …, isEmpty: …, empty: …)` — first load shows three card skeletons, a reload keeps the list with the inline loader, error shows core's `ErrorState` with retry. A card whose photographer name is still loading shows `BookingCard.skeleton()` in its slot. `ScreenCode(ScreenCodes.bookings)`.

- [ ] **Step 1: Write the failing tests:**
  - "first load shows BookingCard.skeleton three times" (stream not yet emitted; no `CircularProgressIndicator`).
  - "groups bookings into the three tabs with the right badges" (seed one per status).
  - "drafts never appear".
  - "the nearest upcoming card has Chỉ đường; Nhắn tin only with the chat flag".
  - "completed cards get Đánh giá only with the review flag".
  - "tapping a card opens /b/:id".
  - "each empty tab shows its own message; Sắp tới offers Tìm nhiếp ảnh gia".
  - "a new booking arriving on the stream appears without reload".
  - "photographers still see the work tab content, not S05.01" (role photographer → no `ScreenCodes.bookings`).
  - "320 dp, 1.3×: segmented control and cards fit".
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** (+ ARB `bookingsTitle`, `bookingsUpcoming`, `bookingsPending`, `bookingsDone`, `bookingsReview`, `bookingsEmptyUpcoming`, `bookingsFindPhotographer`, `bookingsEmptyPending`, `bookingsEmptyDone`). **Step 4: Run** → PASS (whole `test/features/shell` too).
- [ ] **Step 5: Commit** `feat(booking): S05.01 customer bookings grouped by status`.

---

### Task 6: S06.01 work, S06.02 empty, S06.03 decline, work tab badge

**Files:**
- Create: `lib/features/work/work_screen.dart`, `lib/features/work/work_dashboard.dart`, `lib/features/work/work_empty.dart`, `lib/features/booking/decline_sheet.dart`
- Modify: `lib/features/shell/placeholder_tabs.dart`, `lib/features/shell/tab_badges.dart`, `lib/l10n/app_vi.arb`
- Test: `test/features/work/work_screen_test.dart`, `test/features/work/work_empty_test.dart`, `test/features/booking/decline_sheet_test.dart`, `test/features/shell/tab_badges_test.dart` (extend)

**Interfaces:**
- Consumes: `myBookingsProvider(BookingRole.photographer)`, Task 2 `workDashboard`, `countdownLabel`, `transitionBooking`, core `AsyncView`, `BookingCard`, `StatTile.skeleton`, `SectionHeader`, `CountdownText`, `showConfirmSheet`, `ReasonPicker`, `MoneyBreakdown` (shared-components-a), `bookingContactProvider` (names on request cards), `userRepositoryProvider` (customer avatar), S06.02 inputs: the photographer's portfolio size from `portfolioProvider(uid)` (`lib/features/photographer_profile/profile_providers.dart`, plan 2d2), `myPackagesProvider` (count of active packages), `SkillsServerInfo.completeness` (`lib/data/skills/skills_server_info.dart`; null = not scored yet, treat as < 70).
- Produces:
  - `final workDashboardProvider = Provider.autoDispose<AsyncValue<WorkDashboard>>(…)` combining the stream with `nowTickerProvider(const Duration(minutes: 1))`.
  - `class WorkScreen extends ConsumerWidget` (tab root; title "Công việc" with the date subtitle "Thứ 5, 10/10"; calendar icon → `/work/calendar`, the existing key `open-calendar`).
  - `class WorkEmptyState extends ConsumerWidget` (S06.02).
  - `Future<bool?> showDeclineSheet(BuildContext context, {required Booking booking, required String customerName})`.
  - `tabBadgesProvider` adds `AppTab.bookings: requests.length` for photographers when > 0.

S06.01 per mock, rendered through `AsyncView(value: ref.watch(workDashboardProvider), skeleton: (_) => Column(children: [BookingCard.skeleton(), BookingCard.skeleton(), Row(children: [for (var i = 0; i < 3; i++) Expanded(child: StatTile.skeleton())])]), onRetry: …)`: today card (core `BookingCard(size: normal, highlight: true)`; group A's card has no photo-overlay variant, so highlight only — see the interface gap note in Self-review) with "Nhắn tin" (flag) + "Chỉ đường"; section "Yêu cầu mới {n}" (core `SectionHeader`); request cards: avatar, customer name, "{service} · {T7 12/10 15:30} · {place}", price short ("1,5M"), quoted note excerpt (1 line) and "đã cọc {450K}", `ContactDial` from the copy, buttons "Từ chối" (outline small → S06.03) + "Nhận · còn {time}" (primary small; the per-card small primary is allowed like `PhotographerCard`'s "Đặt"; `AppButton(loading: true)` while accepting), its label built in core's `CountdownText(deadline: b.acceptDeadline!, builder: (c, left) => … countdownLabel(left, l10n) …)` (ticks every minute, every second in the last hour; no ticker of this plan's own); tiles row (`IntrinsicHeight` + three `StatTile`s); "Không có yêu cầu mới" when the section is empty; whole dashboard empty → `WorkEmptyState`. Accept → `transitionBooking(action: 'accept')` → `context.push('/b/$id')` (Decision 12). Expired toast per Decision 11. Offline (Firestore `hasPendingWrites`/`isFromCache` is not visible through the port; use the app's existing connectivity signal if there is one, else skip the offline-disable rule and note it in the ledger).

S06.02: `EmptyState` with the circular illustration, title `workEmptyTitle` "Buổi chụp tiếp theo bắt đầu từ đây", body and one button chosen by the spec rule (portfolio < 6 → body `workEmptyBodyPortfolio(n)` + "Thêm ảnh vào portfolio" → `/action`; no active package → "Thêm gói" → `/setup/2`; completeness < 70 → "Hoàn thiện kỹ năng" → `/profile/skills`; else "Chia sẻ hồ sơ" → system share of the public profile link if a share helper exists, else `/u/{uid}`). Segmented "Yêu cầu / Sắp tới / Đã xong" from the mock is shown above it only when there is something to show; with everything empty only the empty state shows (spec: "toàn bộ trống → S06.02"). Its inputs (portfolio, packages, completeness) are read through `AsyncView` with no skeleton (no known shape → core's screen `SignatureLoader`, ripple).

S06.03 per mock and spec, a thin wrapper over core's `showConfirmSheet(context, title: l10n.declineTitle(name), content: _DeclineContent(…), confirmLabel: l10n.declineConfirm, keepLabel: l10n.declineBack, danger: true, onConfirm: …)`: `content` = `ReasonPicker(reasons: [declineReasonBusy, declineReasonArea, declineReasonService, declineReasonOther], style: ReasonPickerStyle.radio, otherLabel: l10n.declineReasonOther, otherMinLength: 5, otherMaxLength: 200, …)` ("Lý do khác" reveals the short field) and the refund line `declineRefundNote(name, amount)` (a sentence per mock, plain text); "Quay lại" (outline) + "Từ chối" (red, disabled until a valid reason — `showConfirmSheet(..., confirmEnabled: reasonValid)` from shared-components-a — inline loader while `onConfirm` runs); success → close true, S06.01 toast `declineDoneToast` "Đã từ chối. {name} được hoàn cọc." and the card disappears through the stream. Sends the reason text (for the three fixed reasons, their label).

- [ ] **Step 1: Write the failing tests:**
  - work: "first load shows BookingCard.skeleton and three StatTile.skeleton"; "shows today's shoot card, the requests section with its count, and the three tiles"; "accept calls transitionBooking(accept) and opens S05.02"; "the countdown shows 22 giờ and switches to seconds in the last hour" (advance the fake clock passed to `CountdownText.now`); "accept refused with deadline_passed shows the expired message and the card leaves" (fake: error then emits the booking as expired); "an expired request disappears with Yêu cầu {tên} đã hết hạn, đã hoàn cọc"; "no requests shows Không có yêu cầu mới"; "everything empty shows S06.02"; "320 dp 1.3×: tiles one row, equal height, labels on one line"; "request contact uses the copy channels".
  - work_empty: one test per rule branch (2 photos → portfolio body with n=2 and Thêm ảnh; 8 photos no package → Thêm gói; 8 photos, package, completeness 50 → Hoàn thiện kỹ năng; all fine → Chia sẻ hồ sơ); "exactly one primary button".
  - decline: "uses showConfirmSheet with a radio ReasonPicker (no hand-made sheet)"; "Từ chối is disabled until a reason is chosen"; "Lý do khác needs at least 5 characters"; "sends the fixed reason label"; "shows the refund line with the full deposit"; "Quay lại closes without calling"; "server error keeps the sheet with a SnackBar".
  - tab badges: "the work tab shows the number of requests for photographers"; "customers get no bookings badge".
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement** (+ ARB `workTitle`, `workDateTitle`, `workToday`, `workRequests`, `workAcceptIn`, `workDecline`, `workMonth`, `workHeld`, `workUpcoming`, `workNoRequests`, `workDepositPaid` "đã cọc {amount}", `workRequestExpired`, `workEmptyTitle`, `workEmptyBodyPortfolio`, `workEmptyAddPhotos`, `workEmptyAddPackage`, `workEmptySkills`, `workEmptyShare`, `declineTitle`, `declineReasonBusy`, `declineReasonArea`, `declineReasonService`, `declineReasonOther`, `declineOtherHint`, `declineRefundNote`, `declineBack` "Quay lại", `declineConfirm`, `declineDoneToast`). **Step 4: Run** → PASS (+ `test/features/shell`).
- [ ] **Step 5: Commit** `feat(work): S06.01 work dashboard, S06.02 next step, S06.03 decline sheet and the work badge`.

---

### Task 7: End-to-end both sides, code table

**Files:**
- Create: `test/features/booking/booking_lifecycle_e2e_test.dart`
- Modify: `docs/superpowers/specs/2026-10-01-remaining-screens.md` (status of S05.02, S05.03, S05.01, S06.01, S06.02, S06.03)

- [ ] **Step 1: Write the end-to-end widget test** with one `FakeBookingRepository` shared by two app instances (or one app switching the signed-in user through `FakeAuthRepository`): customer books (4b flow) → S05.02 requested → photographer S06.01 shows the request with countdown → accept → customer S05.02 shows accepted with step 3 done → clock moves past `endsAt` → photographer completes on S05.02 → customer S05.01 "Đã xong" lists it. A second scenario: photographer declines with "Kín lịch hôm đó" → customer S05.02 shows the stopped step and "Đặt lại".
- [ ] **Step 2: Run** the whole suite and analyze → all pass.
- [ ] **Step 3: Update the code table:** S05.02 "✅ đã làm (4c) · Nhắn tin/Đổi lịch/Đánh giá chờ 4d–4e", S05.03, S05.01 "✅ đã làm (4c) · ẩn tab Vé sự kiện tới khi có S11.04", S06.01 "✅ đã làm (4c) · ẩn Sự kiện của tôi", S06.02 "✅ đã làm (4c)", S06.03 "✅ đã làm (4c)". Do not edit the mock.
- [ ] **Step 4: Commit** `test(booking): customer and photographer lifecycle end to end; mark S05.02, S05.03, S05.01, S06.01, S06.02, S06.03 built`.

---

## Interfaces for plans 4d–4e

- `bookingFeaturesProvider` — 4d sets `chat: true` (and `reschedule: true` with its system message), 4e sets `review: true`; both add their routes (`/chat/:chatId`, `/b/:id/review`).
- `DetailAction.message`, `.reschedule`, `.review`, `.viewReview` — already rendered by S05.02/S05.01/S06.01 when the flags are on: 4d/4e only provide the destinations (`context.push('/chat/${b.chatId}')`, `context.push('/b/${b.id}/review')`), wired in one place: `BookingDetailScreen._onAction`, `MyBookingsScreen._onReview`, `WorkScreen._onMessage`.
- Accept destination (Decision 12) — 4d changes it to the chat when `chat` is on.
- `StatusTimeline` step 7 — 4e's review completes it.

## Self-review notes

- Spec coverage: S05.02 table rows (Task 2 + 3), escrow lines (Task 3), timeline (Tasks 2–3; widget from shared-components-a), live refund (Tasks 3–4), S05.03 (Task 4), S05.01 groups, actions, empties (Task 5), S06.01 sections, countdown, tiles, expiry toast, badge (Task 6), S06.02 rule (Task 6), S06.03 (Task 6), S05.04 contact both sides (Task 3, 6). Interface gaps with shared-components-a: (a) resolved: shared-components-a now has `showConfirmSheet(confirmEnabled:)`; (b) S06.01's today card wants the mock's photo-overlay look, but `BookingCard` has only `normal`/`compact` — shipped as `highlight: true` until a `BookingCardSize.hero` exists. Not covered by design: S06.01 "Sự kiện của tôi" and S05.01 "Vé sự kiện" (events plan), "Đang giữ" → S06.05 (later), analytics events (no analytics port), push notifications on decline (S17 plan).
