# Shared components A: signature loading, skeletons, AsyncView and the widgets the booking screens reuse — Implementation Plan

> **Battery/performance (2026-10-02, user):** no battery, idle, blur-budget or performance steps here; they run once in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Functional animation tests (ticker stops when inactive, reduced motion) stay.

> **No emulator steps:** this plan changes no rules or Functions.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only where easy to get wrong.

**Goal:** Every data fetch in the app shows the app's own loading (a skeleton shaped like the component that will appear, or the signature aperture loader with one wave kind for screen-level waits), and the widgets that the booking, chat and review screens need exist once in `lib/core/widgets/` before those screens are built.

**Architecture:** One `SignatureLoader` (aperture + ripple **or** vibration waves) replaces `ApertureLoader` and every `CircularProgressIndicator`. `AppSkeleton` primitives get the white sweep and one shared controller (`AppSkeletonScope`), and each data component gains a `.skeleton()` constructor with the real component's exact size. `AsyncView<T>` is the only way a feature renders an `AsyncValue` (first load → skeleton or loader, reload keeps data, error → `ErrorState`, empty → `EmptyState`); a source test keeps features from writing their own loading. Then the reusable widgets found in the mock (spec "Component rút ra từ mock") are built with their skeletons. Plans 4b–4e then only compose these.

**Tech Stack:** Flutter, Riverpod 3 (only `AsyncView` takes an `AsyncValue`; widgets stay Riverpod-free), CustomPainter.

**Spec:** `docs/superpowers/specs/components/shared-components.md` — SignatureLoader, AsyncView, AppSkeleton and per-component skeletons, ErrorState/OfflineBanner, SectionHeader, BookingCard, StatusTimeline, and every entry under "Component rút ra từ mock" (EscrowNotice, MoneyBreakdown, PolicyTable, ReasonPicker, ProviderPicker, ConfirmSheet, CountdownRing/CountdownText, ChatBubble/ChatComposer/ConversationRow); section 7 (build order, group A). Visual reference: `docs/design/ui-components.html` (gallery; one tile per component with its skeleton) and `docs/design/ui-mock.html`.

**Prerequisite:** every plan marked done in `RUN-ORDER.md` (4a included). Runs **before** plans 4b–4e.

## Global Constraints

- SignatureLoader (spec, verbatim): "lá khẩu của logo đóng mở ở giữa, quanh đó **một** loại sóng lăn ra, chọn bằng tham số (không bao giờ hiện cả hai cùng lúc)": **ripple** "3 vòng đồng tâm nở từ 38% tới 100% kích thước rồi mờ dần, lệch nhịp 0,8 s, màu `primary`" for loading data; **vibration** "2 vòng gợn hình sin, `r(θ) = R + a·sin(nθ)` (`n = 12, a = 2,4%` và `n = 9, a = 3,2%`), vừa nở ra vừa xoay qua lại ±4–6° như dây rung, màu cyan `focus` và hồng `#FF45D0`, lệch 1,2 s" for waiting on another party. Sizes `screen` 150, `block` 96, `inline` 56 (no waves). No colored background (user, 2026-10-02): no `CtaSurface` disc, gradient or shadow behind the aperture; blades and a thin ring stroked in **the wave's color** (ripple: `primary`; vibration: cyan `focus`) on transparent. Aperture: 8 blades, 2.4 s cycle, close 0–45 %, hold to 55 %, open by 100 %, `Curves.easeInOutCubic`. Reduced motion: open aperture, one faint still ring, no waves.
- Skeletons (spec, user 2026-10-02): **white only, no multiple colors, dark theme included** — blocks white at low alpha in dark (white 8 %), light neutral grey `#E6E3DE` in light (user: "ở nền sáng thì skeleton xám một chút"), a white sweep (dark: white 14 %; light: white 85 %) moving diagonally over 1.6 s, one `AnimationController` per screen; no aurora gradient; "cùng radius, khoảng cách và chiều cao với component thật nên bố cục không nhảy"; reduced motion: still; one "Đang tải" semantics label per group, blocks excluded.
- AsyncView anti-flash (UX review): first-load skeleton/loader appears only after 150 ms and, once shown, stays at least 400 ms.
- AsyncView (spec): reuses `SignatureLoader` itself for loading without a skeleton; the loader area is exactly the outer wave circle (150 or 96 per `loaderSize`), centred, with no box, card, border or gradient around it; error and empty also sit on the bare screen; first load → `skeleton` if given else `SignatureLoader(size: loaderSize)` (ripple); reload with data → keep data + inline loader at the top corner; error → `ErrorState(message: errorMessage(e, l10n), onRetry)`, with old data → keep data + one SnackBar; empty → `empty`.
- No `CircularProgressIndicator` anywhere in `lib/` after this plan (buttons and `ContactDial` use `SignatureLoader(size: inline)`); no hand-written `.when(loading:` in `lib/features/**`.
- CLAUDE.md: tokens only (`AppColors`, `AppSpace`, `AppRadius`, `AppText`); strings in `app_vi.arb`; `package:photobooking/...` imports; widgets in `lib/core/widgets/` exported from `core/core.dart`; one primary action per screen; cancel/decline is a red button inside a confirmation sheet (→ `ConfirmSheet`).
- Each widget: widget tests (states, semantics, 320 dp and 1.3× text in light and dark without overflow), and for each `.skeleton()`: **same size as the real widget** at 390 and 320 dp (`tester.getSize` equal).
- Commands from `app_flutter/`: `../scripts/bin/flutter test --no-pub <paths>`, `../scripts/bin/flutter analyze --no-pub`, `../scripts/bin/dart format lib test`, `../scripts/bin/flutter gen-l10n`. Gallery: after a component's look changes, update `scripts/tools/build_ui_components.py` and run `python3 scripts/tools/build_ui_components.py` from the repo root. Commits: Conventional Commits ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push.

## Decisions

1. `ApertureLoader` is renamed `SignatureLoader` (file `lib/core/widgets/signature_loader.dart`); `ApertureMark`/`AperturePainter` stay and are reused. A deprecated `typedef ApertureLoader = SignatureLoader;` is **not** kept: all call sites change in Task 1.
2. `AppSkeleton` keeps its file and name; `AppSkeletonScope` becomes the single shared controller (white sweep 1.6 s) instead of the 900 ms pulse. Existing `AppSkeleton` call sites in features are replaced by component skeletons in Task 4 where a component skeleton exists; plain `AppSkeleton.box/line` stay allowed inside `.skeleton()` constructors only (source test).
3. `MapPreview`, `SwipeDeck`, `MatchOverlay`, `OfferStack`, `EventCard`, `TicketCard`, `BadgeChip/Tile`, `NotificationRow/Bell`, `PermissionPrimer` are group B (spec section 7) — not in this plan.
4. `BookingCard` takes a plain `BookingSummary` value object (no dependency on `lib/data/booking`); a `BookingSummary.fromBooking(Booking, {photographerName, thumbUrl})` factory lives in `lib/data/booking/booking_summary.dart` so core stays independent of data.

## Review Focus

1. A list that reloads (pull to refresh, filter change) → data stays visible with only the small inline loader; no flash back to skeletons. Pinned by Task 3 ("reload keeps data and shows the inline loader").
2. A skeleton a few pixels taller than its card → the list jumps when data arrives. Pinned by every `.skeleton()` size test (Tasks 2, 5, 8, 9).
3. Reduced motion → no ticker runs anywhere a loader or skeleton is visible. Pinned by Tasks 1–2 ("reduced motion: no ticker").
4. ConfirmSheet tapped twice while `onConfirm` runs, or dismissed by drag mid-call → `onConfirm` runs once and the sheet cannot close until it finishes. Pinned by Task 6 ("double tap runs onConfirm once; sheet locked while running").
5. Countdown crossing the one-hour mark or reaching zero → switches to per-second ticks, then stops at 0 and calls `onExpired` once. Pinned by Task 7.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/widgets/signature_loader.dart` (rename from `aperture_loader.dart`) | `SignatureLoader`, `LoaderSize`, `LoaderWave`, `ApertureMark`, painters |
| `lib/core/widgets/app_skeleton.dart` (modify) | primitives + shared sweep scope |
| `lib/core/widgets/async_view.dart` (create) | `AsyncView<T>` |
| `lib/core/widgets/error_state.dart` (modify), `offline_banner.dart`, `section_header.dart` (create) | states |
| `lib/core/widgets/{photo_card,photographer_card,stat_tile,app_avatar,reason_chips,availability_calendar,capacity_bar,completeness_meter,app_option_tile}.dart` (modify) | `.skeleton()` |
| `lib/core/widgets/escrow_notice.dart`, `money_breakdown.dart`, `policy_table.dart` (create) | money widgets |
| `lib/core/widgets/reason_picker.dart`, `provider_picker.dart`, `confirm_sheet.dart` (create) | decisions |
| `lib/core/widgets/countdown.dart` (create) | `CountdownRing`, `CountdownText` |
| `lib/core/widgets/booking_card.dart`, `status_timeline.dart` (create); `lib/data/booking/booking_summary.dart` (create) | booking widgets |
| `lib/core/widgets/chat_bubble.dart`, `chat_composer.dart`, `conversation_row.dart` (create) | chat widgets |
| `lib/core/core.dart` (modify) | exports |
| `lib/features/**` (modify, Task 4) | move to `AsyncView` + skeletons |
| `test/core/widgets/*_test.dart`, `test/core/source_rules_test.dart` (create/extend) | tests |
| `scripts/tools/build_ui_components.py`, `docs/design/ui-components.html` | gallery kept in step |
| `docs/superpowers/specs/components/shared-components.md` (modify, last task) | mark "Đã có" |

---

### Task 1: `SignatureLoader` with one wave kind

**Files:** rename `lib/core/widgets/aperture_loader.dart` → `signature_loader.dart`; modify `app_button.dart`, `contact_dial.dart`, every call site of `ApertureLoader` (splash, contact setup, …), `core.dart`; tests `test/core/widgets/signature_loader_test.dart` (move/extend the aperture tests), `app_button_test.dart`, `contact_dial_test.dart`.

**Interfaces:**

```dart
enum LoaderSize { screen, block, inline }        // 150, 96, 56 logical px
enum LoaderWave { ripple, vibration }
class SignatureLoader extends StatefulWidget {
  const SignatureLoader({super.key, this.size = LoaderSize.screen, this.wave = LoaderWave.ripple,
      this.active = true, this.semanticsLabel});
}
```

Painting sample (one painter, one controller; `t` = controller value 0..1 over 2.4 s):

```dart
// ripple: three rings, phase-shifted by 1/3 of the cycle (0.8 s)
for (var i = 0; i < 3; i++) {
  final p = (t + i / 3) % 1.0;
  final r = lerpDouble(0.38, 1.0, Curves.easeOutCubic.transform(p))! * radius;
  canvas.drawCircle(center, r, ripplePaint..color = primary.withValues(alpha: 0.9 * (1 - p)));
}
// vibration: two sine rings r(θ) = R + a·sin(nθ), growing and rocking ±4–6°
for (final w in const [(n: 12, a: 0.024, phase: 0.17, swing: 5.0), (n: 9, a: 0.032, phase: 0.67, swing: 6.0)]) {
  final p = (t + w.phase) % 1.0;
  final scale = lerpDouble(0.4, 1.04, p)!;
  final angle = math.sin(p * math.pi * 5) * w.swing * math.pi / 180;   // rocks back and forth
  canvas.drawPath(_wavyPath(center, radius * scale, w.n, w.a * radius, angle), vibPaint(w) ..color = …withValues(alpha: 0.95 * (1 - p)));
}
```

- [ ] **Step 1: Failing tests:** "ripple draws three circles and no wavy ring" (inspect the painter through a `paint` recording / golden at t = 0.5); "vibration draws two wavy rings and no circles"; "inline size draws no waves"; "no filled disc or gradient behind the aperture; blade color equals the wave color (primary for ripple, focus for vibration)"; "one ticker while active; none when active is false"; "reduced motion: open aperture, one still ring, no waves, no ticker"; "semantics label is read"; goldens 3 frames × 2 waves × light/dark; "AsyncView first load without skeleton is a SignatureLoader whose size equals the outer wave circle, with no DecoratedBox/colored Container around it"; "AppButton loading shows the inline loader and no CircularProgressIndicator"; "ContactDial busy shows the inline loader".
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement**; replace every `ApertureLoader(` call (S04.04/S01.01 use `wave: vibration` only where the spec says "chờ một bên khác"; splash uses ripple). **Step 4: Run** → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat(core): SignatureLoader with ripple or vibration waves; no more spinners`.

---

### Task 2: Skeleton system and skeletons for the existing data widgets

**Files:** modify `app_skeleton.dart`, `photo_card.dart`, `photographer_card.dart`, `stat_tile.dart`, `app_avatar.dart`, `reason_chips.dart`, `availability_calendar.dart`, `capacity_bar.dart`, `completeness_meter.dart`, `app_option_tile.dart`; tests next to each widget's test file.

**Interfaces:**

```dart
class AppSkeletonScope extends StatefulWidget { const AppSkeletonScope({required Widget child}); }   // one 1.6 s sweep for its subtree
abstract final class AppSkeleton {
  static Widget box({double? width, required double height, double radius = AppRadius.sm});
  static Widget line({double widthFactor = 1, double height = 12});
  static Widget circle({required double size});
  /// Groups skeleton blocks under one "Đang tải" live region.
  static Widget group({required Widget child});
}
// One per data widget; same constructor defaults as the real widget so sizes match:
PhotoCard.skeleton({double aspect = 4 / 5});
PhotographerCard.skeleton();
StatTile.skeleton();
AppAvatar.skeleton({AppAvatarSize size = AppAvatarSize.md});
ReasonChips.skeleton({int count = 2});
AvailabilityCalendar.skeleton();
CapacityBar.skeleton();
CompletenessMeter.skeleton();
AppOptionTile.skeleton({bool withThumb = false});
```

- [ ] **Step 1: Failing tests:** "the sweep is one controller for many blocks under a scope"; "no hue in blocks or sweep (r == g == b): white in dark, light grey in light"; "reduced motion: still blocks, no ticker"; "a group reads 'Đang tải' once and hides block semantics"; for each widget: "skeleton has the same size as the real widget at 390 and 320 dp" (pump both in identical constraints, compare `tester.getSize`); goldens light/dark.
- [ ] **Step 2–4:** implement (ARB `loadingLabel` "Đang tải" — reuse if present); run → PASS.
- [ ] **Step 5: Commit** `feat(core): aurora skeleton sweep and a skeleton for each data widget`.

---

### Task 3: `AsyncView`, `ErrorState`, `OfflineBanner`, `SectionHeader`, source rules

**Files:** create `async_view.dart`, `offline_banner.dart`, `section_header.dart`; modify `error_state.dart`; create `test/core/source_rules_test.dart`.

**Interfaces:**

```dart
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.skeleton,
      this.loaderSize = LoaderSize.screen, this.loadingLabel, this.isEmpty, this.empty,
      this.onRetry, this.error});
  final AsyncValue<T> value;
  final Widget Function(BuildContext, T) data;
  final WidgetBuilder? skeleton;
  …
}
class OfflineBanner extends StatelessWidget { const OfflineBanner({super.key}); }   // "Đang xem dữ liệu đã lưu"
class SectionHeader extends StatelessWidget { const SectionHeader({required String title, String? actionLabel, VoidCallback? onAction}); }
String errorMessage(Object error, AppLocalizations l);   // if it does not exist yet: map BookingException/FirebaseException codes and network errors to ARB strings
```

Source rules test (reads files under `lib/`):

```dart
test('no CircularProgressIndicator in lib', () { … expect(offenders, isEmpty); });
test('features do not hand-write AsyncValue loading', () {
  // lib/features/**: no `.when(` with a `loading:` argument, no `AppSkeleton.` outside a `.skeleton(` builder
});
```

- [ ] **Step 1: Failing tests:** "first load shows the given skeleton"; "first load without skeleton shows the screen loader with ripple waves"; "reload keeps data and shows the inline loader"; "no flash: data within 150 ms shows no skeleton/loader at all; once shown, the skeleton stays at least 400 ms" (fake async + `tester.pump(Duration)`); "error shows ErrorState with retry calling onRetry"; "error with old data keeps the data and shows one SnackBar"; "empty shows the empty builder"; OfflineBanner text; SectionHeader action tap; source rules (expected to FAIL until Task 4 finishes — mark them `skip: 'enabled in Task 4'` here and remove the skip in Task 4).
- [ ] **Step 2–4:** implement; run → PASS (source rules skipped).
- [ ] **Step 5: Commit** `feat(core): AsyncView with skeleton or signature loading, error and empty states`.

---

### Task 4: Move every existing screen to `AsyncView` and component skeletons

**Files:** the features that render `AsyncValue` today (found with `grep -rln "\.when(\|AppSkeleton\|CircularProgressIndicator" lib/features`): `home/home_screen.dart`, `explore/explore_screen.dart`, `explore/area_picker_sheet.dart`, `find/find_screen.dart`, `photo/photo_detail_screen.dart`, `photographer_profile/photographer_profile_screen.dart`, `photographer_profile/widgets/profile_sections.dart`, `photographer_setup/contact_setup_screen.dart`, `photographer_setup/setup_packages_screen.dart`, `skills/skills_screen.dart`, `skills/evidence_sheet.dart`, `create_post/create_post_screen.dart`, `onboarding/splash_screen.dart`, plus any other the grep finds; their tests.

Rule per screen: lists and grids use the skeleton of the component they will show, repeated as many times as fit one phone screen (e.g. home: 1 large `PhotoCard.skeleton` + 3 small; find: 2 `PhotographerCard.skeleton`; S03 header: `AppAvatar.skeleton(lg)` + 4 `StatTile.skeleton`); a screen with no known shape uses the screen loader (ripple). Load-more at the end of a list: `SignatureLoader(size: inline)` centred.

- [ ] **Step 1:** remove the `skip` from the source rules test → FAIL (lists the offenders).
- [ ] **Step 2:** for each screen, replace the hand-written loading/error with `AsyncView` (keep each screen's existing empty and error copy); update its tests to expect the skeleton (`find.byWidgetPredicate` on the `.skeleton` key) or the loader.
- [ ] **Step 3: Run** the whole suite and the source rules → PASS; analyze clean.
- [ ] **Step 4: Commit** `refactor(features): every fetch renders through AsyncView with component skeletons`.

---

### Task 5: Money widgets — `EscrowNotice`, `MoneyBreakdown`, `PolicyTable`

**Interfaces:** exactly the spec entries:

```dart
class EscrowNotice extends StatelessWidget { const EscrowNotice({required String text}); static Widget skeleton(); }
enum MoneyLineStyle { normal, strong, muted }
@immutable class MoneyLine { const MoneyLine({required this.label, required this.vnd, this.style = MoneyLineStyle.normal}); }
class MoneyBreakdown extends StatelessWidget { const MoneyBreakdown({required List<MoneyLine> lines}); static Widget skeleton({int lines = 3}); }
@immutable class PolicyRow { const PolicyRow({required this.when, required this.outcome}); }
class PolicyTable extends StatelessWidget { const PolicyTable({required List<PolicyRow> rows, required int activeIndex}); static Widget skeleton({int rows = 3}); }
```

- [ ] **Step 1: Failing tests:** EscrowNotice "lock icon and text read as one container"; MoneyBreakdown "formats with formatMoney, strong row bold, muted row secondary color, numbers tabular"; PolicyTable "active row highlighted and announced 'Đang áp dụng'"; skeleton sizes; 320 dp/1.3×.
- [ ] **Step 2–4.** **Step 5: Commit** `feat(core): EscrowNotice, MoneyBreakdown and PolicyTable`.

---

### Task 6: Decision widgets — `ReasonPicker`, `ProviderPicker`, `ConfirmSheet`

**Interfaces:** spec entries. `ConfirmSheet` sample (the part easy to get wrong):

```dart
Future<bool> showConfirmSheet(BuildContext context, {required String title, String? body, Widget? content,
    required String confirmLabel, required String keepLabel, bool danger = true, Future<void> Function()? onConfirm,
    ValueListenable<bool>? confirmEnabled /* e.g. S06.03: disabled until a valid reason is chosen */}) {
  return showAppSheet<bool>(context, isDismissible: () => !running, builder: (_) => _ConfirmBody(...))
      .then((v) => v ?? false);
}
// _ConfirmBody: keep (outline, left) | confirm (danger red or primary, right). While onConfirm runs:
// running = true → confirm shows SignatureLoader(size: inline), both buttons disabled, PopScope(canPop: false),
// barrier and drag ignored; on success pop(true); on error SnackBar inside the sheet, running = false.
```

(If `showAppSheet` lacks a dismissible hook, add `bool Function()? canDismiss` to it in this task.)

`ProviderPicker` needs `PaymentProviderCode`; it is defined by plan 4b — **define it here** in `lib/core/payments.dart` (`enum PaymentProviderCode { momo, vnpay }` with `code`) and plan 4b imports it from core.

- [ ] **Step 1: Failing tests:** ReasonPicker chips and radio; "Lý do khác" field with min/max length; ProviderPicker single choice; ConfirmSheet "keep pops false without calling onConfirm"; "double tap runs onConfirm once; sheet locked while running" (drag/back ignored); "error keeps the sheet open with a SnackBar"; "danger uses the red button, never the gradient"; "confirmEnabled false disables confirm and updates when it flips"; 320 dp/1.3×.
- [ ] **Step 2–4.** **Step 5: Commit** `feat(core): ReasonPicker, ProviderPicker and ConfirmSheet`.
- [ ] **Step 6:** replace the existing hand-made confirmation sheets that match (sign-out on S09.02, discard draft on S10.01, …) with `showConfirmSheet`; tests updated. Commit `refactor(features): confirmation sheets use ConfirmSheet`.

---

### Task 7: `CountdownRing`, `CountdownText` and `UploadProgressRing`

**Interfaces:**

```dart
class CountdownRing extends StatefulWidget { const CountdownRing({required DateTime deadline, required Duration total, double size = 96, VoidCallback? onExpired}); }
class UploadProgressRing extends StatelessWidget { const UploadProgressRing({required double fraction, double size = 28}); }   // determinate ring for uploads (S05.05 share grid, S10.01), primary stroke on transparent; replaces any determinate CircularProgressIndicator
class CountdownText extends StatefulWidget { const CountdownText({required DateTime deadline, required Widget Function(BuildContext, Duration left) builder, VoidCallback? onExpired}); }
// Both read "now" from a `DateTime Function() now` parameter defaulting to DateTime.now (tests pass a fake clock),
// tick every second when left < 1 h, else every minute, stop at zero and call onExpired once.
// Screen readers: the label is readable on focus at any time; the live-region announcement fires only at 5 min, 1 min, 10 s and 0.
```

- [ ] **Step 1: Failing tests:** "ticks every minute above an hour and every second below"; "stops at zero and calls onExpired once"; "semantics timer reads 'Còn 47 giây'"; "announces (live region) only at 5 min, 1 min, 10 s and 0, never every tick"; "reduced motion: ring jumps per second, no interpolation"; "no ticker after expiry"; UploadProgressRing "draws fraction 0..1 clamped, semantics value '{n}%'".
- [ ] **Step 2–4.** **Step 5: Commit** `feat(core): CountdownRing and CountdownText`.

---

### Task 8: `BookingCard`, `StatusTimeline`

**Interfaces:**

```dart
// lib/core/widgets/booking_card.dart
@immutable class BookingSummary { const BookingSummary({required this.photographerName, required this.serviceName, this.thumbUrl,
    required this.day /*yyyy-MM-dd*/, required this.start, required this.end, required this.placeName, this.status, this.statusLabel}); }
enum BookingCardSize { normal, compact }
class BookingCard extends StatelessWidget { const BookingCard({required BookingSummary data, BookingCardSize size = BookingCardSize.normal,
    Widget? actions, bool highlight = false, VoidCallback? onTap}); static Widget skeleton({BookingCardSize size = BookingCardSize.normal}); }
// lib/data/booking/booking_summary.dart
BookingSummary bookingSummaryOf(Booking b, {required String photographerName, String? thumbUrl, String? statusLabel /* e.g. "Chờ cọc" on S04.04 */});
// lib/core/widgets/status_timeline.dart
enum TimelineStepState { done, current, upcoming, stopped }
@immutable class TimelineStep { const TimelineStep({required this.title, this.subtitle, required this.state}); }
class StatusTimeline extends StatelessWidget { const StatusTimeline({required List<TimelineStep> steps}); static Widget skeleton({int steps = 3}); }
```

Layout and copy per spec and mock (gallery tiles "BookingCard", "StatusTimeline"). Semantics for the timeline: "Bước {n} trong {total}, {state}".

- [ ] **Step 1: Failing tests:** BookingCard normal/compact, status badge, `statusLabel` override, actions row, tap; `bookingSummaryOf` maps the 4a `Booking`; StatusTimeline states incl. stopped in danger color and semantics; skeleton sizes; 320 dp/1.3×.
- [ ] **Step 2–4.** **Step 5: Commit** `feat(core): BookingCard and StatusTimeline with skeletons`.

---

### Task 9: Chat widgets — `ChatBubble`, `ChatComposer`, `ConversationRow`

**Interfaces:** spec entries:

```dart
sealed class ChatBubbleContent { const ChatBubbleContent(); }
final class TextContent extends ChatBubbleContent { const TextContent(this.text); final String text; }
final class ImageContent extends ChatBubbleContent { const ImageContent(this.url); final String url; }
final class LocationContent extends ChatBubbleContent { const LocationContent({required this.label, required this.mapUrl}); }
final class SystemContent extends ChatBubbleContent { const SystemContent(this.text, {this.actions = const []}); final List<Widget> actions; }
enum BubbleSendState { sent, sending, failed }
class ChatBubble extends StatelessWidget { const ChatBubble({required ChatBubbleContent content, required bool mine,
    BubbleSendState state = BubbleSendState.sent, String? senderName, VoidCallback? onRetry}); static Widget skeleton({bool mine = false}); }
class ChatComposer extends StatefulWidget { const ChatComposer({required ValueChanged<String> onSend, VoidCallback? onPickImage, bool enabled = true, String? disabledReason,
    bool busy = false /* image upload in flight: image button shows the inline SignatureLoader */}); }
class ConversationRow extends StatelessWidget { const ConversationRow({required String name, String? avatarUrl, required String preview,
    required String timeLabel, int unread = 0, Widget? badge, VoidCallback? onTap}); static Widget skeleton(); }
```

- [ ] **Step 1: Failing tests:** mine/theirs alignment and colors; image and location bubbles; system bubble centred with actions; sending dims with a clock; failed shows "Gửi lại" and calls onRetry; composer does not send empty/whitespace, clears after send, shows `disabledReason`; busy shows the inline loader on the image button and blocks a second pick; ConversationRow unread badge read as "{n} tin chưa đọc"; skeleton sizes; 320 dp/1.3×.
- [ ] **Step 2–4.** **Step 5: Commit** `feat(core): chat bubble, composer and conversation row`.

---

### Task 10: Gallery and spec in step

**Files:** `scripts/tools/build_ui_components.py`, `docs/design/ui-components.html`, `docs/superpowers/specs/components/shared-components.md`.

- [ ] **Step 1:** where a built widget differs from its gallery tile (size, copy, layout), update the tile in the builder to match the code (the code follows the spec; the gallery documents it), run `python3 scripts/tools/build_ui_components.py` from the repo root.
- [ ] **Step 2:** in the spec, change "· Mới" to "· Đã có" for every widget built in this plan; group A in section 7 marked done.
- [ ] **Step 3: Commit** `docs(components): gallery and spec match the built group A widgets`.

## Interfaces for plans 4b–4e

- Use, do not recreate: `SignatureLoader` (`wave: vibration` on S04.04 payment wait and S13.03), `AsyncView` + `.skeleton()` for every fetch, `BookingCard`/`BookingSummary`/`bookingSummaryOf`, `StatusTimeline`, `EscrowNotice`, `MoneyBreakdown`, `PolicyTable`, `ReasonPicker`, `ProviderPicker` + `PaymentProviderCode` (core), `showConfirmSheet`, `CountdownRing`/`CountdownText`, `ChatBubble`/`ChatComposer`/`ConversationRow`, `SectionHeader`, `OfflineBanner`.

## Self-review notes

- Spec coverage (group A): every widget listed in spec section 7 group A has a task (SectionHeader and OfflineBanner in Task 3). Group B is listed under Decisions and waits for its own plan.
- Plan 4b's Task 1 originally created BookingCard and EscrowNotice, and 4c's Task 1 created StatusTimeline; those plans are edited to consume these instead (see RUN-ORDER note).
