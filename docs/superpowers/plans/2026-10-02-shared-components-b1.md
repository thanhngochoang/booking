# Shared components B1: events, tickets, badges and notifications widgets — Implementation Plan

> **Battery/performance (2026-10-02, user):** no battery, idle, blur-budget or performance steps here; they run once in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Functional animation tests (reduced motion) stay.

> **No emulator steps:** this plan changes no rules or Functions.

> **Lanes (2026-10-02):** lane 2 (`lane/core`), step 7, after plan A is fully merged. Task 6 edits `lib/features/explore/**`, which no lane-1 plan of steps 1–7 touches; that is the one agreed exception to lane 1 owning `lib/features/**` (see `RUN-ORDER.md` → "Two parallel lanes").

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Detail level (user, 2026-10-02):** exact interfaces, tests listed by name with expected behaviour, sample code only where easy to get wrong.

**Goal:** The widgets that the events (S11, S12), badges (S03.02) and notifications (S17) screens need exist in `lib/core/widgets/` with their skeletons, so the later screen plans only compose them.

**Architecture:** Core widgets take plain view-data classes defined next to them (no import from `lib/data`), the same rule plan A used for `BookingCard`/`BookingSummary`. Mapping from data entities (the existing `EventSummary`) lives in `lib/data/**`. Each data widget has `.skeleton()` with the real widget's exact size. The explore screen's temporary `NearbyEventTile` is replaced by `EventCard(size: row)`.

**Tech Stack:** Flutter, `qr_flutter` (new dependency, for `TicketCard`), CustomPainter none.

**Spec:** `docs/superpowers/specs/components/shared-components.md` sections EventCard và DateBlock, TicketCard, BadgeChip, BadgeTile, NotificationRow, NotificationBell, PermissionPrimer, plus FreeTag và FreeBanner (FreeTag exists; FreeBanner is checked) and AppSkeleton (per-component skeleton rules, white only). Screen behaviour that shapes the widgets: `docs/superpowers/specs/screens/events.md` (S11.01, S11.02, S11.04, S12.02, S12.03), `screens/account.md` (S03.02, S17.01, S17.03), `screens/discovery.md` (S02.03, S02.04). Visual reference: `docs/design/ui-components.html` tiles `eventcard`, `ticketcard`, `badgechip`, `badgetile`, `notificationrow`, `notificationbell`, `permissionprimer`, and the mock screens S11.01, S11.04, S03.02, S17.01, S17.03.

**Prerequisite:** plan `2026-10-02-shared-components-a.md` done (SignatureLoader, `AppSkeleton` white sweep, `AsyncView`, source rules test). Group B2 (`SwipeDeck`, `MatchOverlay`, `OfferStack`, `MapPreview`) is a separate plan written after the user approves the instant-booking spec.

## Contract with merged code (read before Task 1)

- `lib/data/events/event_summary.dart`: `EventSummary` (id, title, hostName, hostVerified, `EventType type`, `startsAt` UTC, locationName, lat/lng, `priceVnd` int, capacity, registeredCount, heldCount, `EventStatus status`, coverUrl; `isFree`, `seatsLeft`), `EventType` with `code`, `tag` (`#workshop`), `label(l10n)`, `EventStatus`.
- `lib/features/explore/widgets/event_tile.dart`: `NearbyEventTile({event, distanceLabel, onTap})`, the stand-in for `EventCard(size: row)`; used in `explore_screen.dart` (S02.04 list, S02.03 section). Its date block, semantics (`eventDateSpoken`, `eventMonthShort`) and seat copy are the reference for `DateBlock` and the row layout.
- Existing core widgets reused, not recreated: `FreeTag` (`free_tag.dart`), `CapacityBar`, `GlassCard(highlight)`, `AppAvatar`, `TabBadge` (number formatting "9+"), `AppBottomSheet`/`showAppSheet`, `AppButton`, `StatusBadge`, `toVn()` (`vn_time.dart`), `formatMoney`.
- If a member named here does not exist, stop and report instead of guessing.

## Global Constraints

- CLAUDE.md: tokens only (`AppColors`/`AppColorsDark`, `AppSpace`, `AppRadius`, `AppFonts`); strings in `app_vi.arb`; `package:photobooking/...` imports; widgets in `lib/core/widgets/` exported from `core/core.dart`; core never imports `lib/data/**` or `lib/features/**`.
- Free events show `FreeTag` ("Không thu phí"), never "0₫" (CLAUDE.md).
- Skeletons (plan A, user): white only (dark: white 8 % blocks, light: neutral grey `#E6E3DE`), white sweep, built from `AppSkeleton.box/line/circle` under `AppSkeletonScope`; **same size as the real widget** at 390 and 320 dp.
- Text never relies on color alone: seats "Còn 3 chỗ"/"Hết chỗ", unread has a label, badge locked state has text.
- Each widget: widget tests for states and semantics, 320 dp and 1.3× text in light and dark without overflow; list rows never use `BackdropFilter` (translucent fill + hairline, as `NearbyEventTile` does).
- Commands from `app_flutter/`: `../scripts/bin/flutter test --no-pub <paths>`, `../scripts/bin/flutter analyze --no-pub`, `../scripts/bin/dart format lib test`, `../scripts/bin/flutter gen-l10n`. Adding `qr_flutter` needs `../scripts/bin/flutter pub get` with `pub.dev` reachable (sandbox: `allowed_domains: pub.dev, storage.googleapis.com`); if it cannot reach pub.dev, stop and tell the user. Commits: Conventional Commits ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push.

## Decisions

1. View data in core: `EventCardData`, `TicketCardData`, `BadgeView`/`BadgeProgress`, `NotificationRowData`. Mappers in data: `eventCardDataOf(EventSummary, l10n?)` in `lib/data/events/event_card_data_of.dart`. Ticket, badge and notification entities do not exist yet; their mappers come with their screen plans.
2. `EventType` stays in `lib/data/events/`; `EventCardData` carries the already-built `typeTag` (`#workshop`) and `typeLabel` strings so core does not import data.
3. `NotificationRowData.type` is a core enum `NotificationKind` (booking, payment, chat, event, badge, system) that picks the icon and tone; the S17 plan maps server codes onto it.
4. `PermissionPrimerPolicy` (7-day snooze, never on app start) is pure logic in core with an injected clock and a tiny storage port (`PrimerStore { DateTime? lastSnoozed; Future<void> snooze(DateTime) }`); the shared-preferences adapter comes with the S17 plan. The OS permission call is not in core.
5. `NotificationBell` reads nothing itself: `unread` comes from the caller (spec: `unreadCountProvider` lives in the S17 plan).

## Review Focus

1. `EventCard` row with a long title, 1.3× text and 320 dp → title wraps, the price column keeps its width, seats text stays visible. Pinned by Task 2 layout tests.
2. Free event anywhere → `FreeTag`, never "0₫" or an empty price. Pinned by Task 2 ("free event shows FreeTag in row, featured and compact").
3. Ticket in the past → dimmed, no QR (a past QR must not be scannable at the door). Pinned by Task 3.
4. Notification unread state readable without color; long-press and semantic custom actions both reach "Đánh dấu đã đọc / Tắt loại thông báo này". Pinned by Task 5.
5. Every `.skeleton()` equals its widget's size; a skeleton that differs makes the list jump. Pinned by every size test.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/widgets/date_block.dart` (create) | `DateBlock` |
| `lib/core/widgets/event_card.dart` (create) | `EventCardData`, `EventCardSize`, `EventCard` + skeleton |
| `lib/core/widgets/free_tag.dart` (modify only if `FreeBanner` is missing) | `FreeBanner` |
| `lib/core/widgets/ticket_card.dart` (create) | `TicketCardData`, `TicketCard` + skeleton |
| `lib/core/widgets/badge_chip.dart`, `badge_tile.dart` (create) | `BadgeView`, `BadgeProgress`, `BadgeChip`, `BadgeRow`, `BadgeTile` + skeletons |
| `lib/core/widgets/notification_row.dart`, `notification_bell.dart` (create) | `NotificationKind`, `NotificationRowData`, `NotificationRow`, `NotificationBell` |
| `lib/core/widgets/permission_primer.dart`, `lib/core/permission_primer_policy.dart` (create) | primer content, snooze policy |
| `lib/core/core.dart` (modify) | exports |
| `lib/data/events/event_card_data_of.dart` (create) | `EventSummary` → `EventCardData` |
| `lib/features/explore/widgets/event_tile.dart` (delete), `lib/features/explore/explore_screen.dart` (modify) | switch to `EventCard` |
| `lib/l10n/app_vi.arb` (modify) | new strings, one block at the end |
| `pubspec.yaml`, `pubspec.lock` | `qr_flutter` |
| `test/core/widgets/*_test.dart`, `test/core/permission_primer_policy_test.dart`, `test/data/events/event_card_data_of_test.dart`, `test/features/explore/*` (update) | tests |
| `scripts/tools/build_ui_components.py`, `docs/design/ui-components.html`, `shared-components.md` | gallery and spec in step |

---

### Task 1: `DateBlock`

**Files:** create `lib/core/widgets/date_block.dart`; `core.dart`; test `test/core/widgets/date_block_test.dart`.

**Interface:**

```dart
class DateBlock extends StatelessWidget {
  const DateBlock({super.key, required this.day, this.size = 46});
  final DateTime day;   // UTC instant; displayed in Vietnam time via toVn()
  final double size;
  static Widget skeleton({double size = 46});
}
```

Layout and semantics exactly as `NearbyEventTile`'s date block (day Fraunces 20 tabular, month `eventMonthShort` 9,5 caps, `primarySubtle` fill, radius `AppRadius.lg`, `eventDateSpoken` label).

- [ ] **Step 1: Failing tests:** "23:30 UTC on the 11th shows 12 (Vietnam day)"; "reads 'Thứ …, 12 tháng 10'"; "skeleton has the same size"; light/dark goldens.
- [ ] **Steps 2–4:** implement; run → PASS. **Step 5: Commit** `feat(core): DateBlock`.

---

### Task 2: `EventCard` (row, featured, compact) and the data mapper

**Files:** create `event_card.dart`, `lib/data/events/event_card_data_of.dart`; `core.dart`; ARB; tests `test/core/widgets/event_card_test.dart`, `test/data/events/event_card_data_of_test.dart`.

**Interfaces:**

```dart
@immutable
class EventCardData {
  const EventCardData({required this.id, required this.title, required this.hostName, this.hostVerified = false,
      required this.typeTag, required this.typeLabel, required this.startsAt, this.placeName,
      required this.priceVnd, required this.seatsLeft, required this.soldOut, this.coverUrl});
  // priceVnd 0 = free; seatsLeft >= 0; soldOut also true when status is full
}
enum EventCardSize { row, featured, compact }
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.data, this.size = EventCardSize.row, this.distanceLabel, this.onTap});
  static Widget skeleton({EventCardSize size = EventCardSize.row});
}
// lib/data/events/event_card_data_of.dart
EventCardData eventCardDataOf(EventSummary e, AppLocalizations l);   // typeTag = e.type.tag, typeLabel = e.type.label(l)
```

Layouts (spec + gallery tile): row = `DateBlock` · title, "chủ · địa điểm" (with `distanceLabel` first when given), tag text in primary (no fill/border, semantics = `typeLabel`) · right column price (`formatMoney`) or `FreeTag`, then seats text ("Còn {n} chỗ"/"Hết chỗ"). Featured = cover 16:9 (`NetworkPhoto`), pill "{distance} · Còn {n} chỗ", overlay title + date line. Compact = 176 dp wide, cover 4:3, title 2 lines, date + price/`FreeTag`. Whole card one `MergeSemantics` button: "{title}, {date}, {place}, {price or Không thu phí}, {seats}".

- [ ] **Step 1: Failing tests:** "row shows date block, title, host · place, tag, price and seats"; "free event shows FreeTag in row, featured and compact, never '0₫'"; "sold out reads 'Hết chỗ'"; "distance label comes first in the place line"; "long title at 320 dp and 1.3× wraps without overflow, price column keeps its width"; "featured shows cover and pill"; "compact is 176 dp wide"; "one merged semantics node with the full sentence"; "tap calls onTap"; skeleton size equal for each size at 390 and 320 dp; mapper test: "maps EventSummary fields, seatsLeft and soldOut from status full".
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(core): EventCard in three sizes with skeletons`.

---

### Task 3: `TicketCard` with QR

**Files:** `pubspec.yaml`/`.lock` (`qr_flutter`), create `ticket_card.dart`; `core.dart`; ARB; test `test/core/widgets/ticket_card_test.dart`.

**Interface:**

```dart
enum TicketState { upcoming, pendingPayment, past, cancelled }
@immutable
class TicketCardData {
  const TicketCardData({required this.ticketCode, required this.eventTitle, required this.typeTag,
      required this.startsAt, required this.quantity, required this.state, this.placeName});
}
class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.ticket, this.onCancel, this.onDirections, this.onAddToCalendar, this.onPay});
  static Widget skeleton();
}
```

Upcoming: `GlassCard(highlight: true)`, tag, title, "{date time} · {n} vé", `StatusBadge`-style label, QR 112 dp on a white square (`QrImageView`, error correction M, `semanticsLabel` "Mã vé {code}"), the code as `SelectableText`, buttons row (Chỉ đường, Thêm vào lịch, Huỷ vé as text button in danger color → caller opens `showConfirmSheet`). Pending payment: no QR, "Chờ thanh toán" + `onPay` primary small. Past/cancelled: opacity 0.55, no QR, no buttons except none.

- [ ] **Step 1: Failing tests:** "upcoming shows QR encoding the ticket code and the selectable code"; "QR semantics reads 'Mã vé {code}'"; "past and cancelled are dimmed and have no QR"; "pending payment shows Chờ thanh toán and the pay button, no QR"; "cancel is a danger text button that calls onCancel" (no confirmation inside the widget); 320 dp/1.3×; skeleton size.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(core): TicketCard with QR`.

---

### Task 4: `BadgeChip`, `BadgeRow`, `BadgeTile`

**Files:** create `badge_chip.dart`, `badge_tile.dart`; `core.dart`; ARB; tests.

**Interfaces:**

```dart
@immutable
class BadgeView { const BadgeView({required this.code, required this.name, required this.condition, required this.earned}); }
@immutable
class BadgeProgress { const BadgeProgress({required this.current, required this.total}); }
class BadgeChip extends StatelessWidget { const BadgeChip({super.key, required this.badge, this.onTap}); static Widget skeleton(); }
/// Up to [max] chips then "Tất cả" (Wrap). Profile rows use max 3, photographer cards max 2 and no "Tất cả".
class BadgeRow extends StatelessWidget { const BadgeRow({super.key, required this.badges, this.max = 3, this.onSeeAll}); static Widget skeleton({int count = 3}); }
class BadgeTile extends StatelessWidget { const BadgeTile({super.key, required this.badge, this.progress, this.isNew = false, this.onTap}); static Widget skeleton(); }
```

Icon: one glyph per `code` from the app icon set, falling back to a generic medal; earned = `CtaSurface` disc, not earned = grey disc + "Chưa đạt" text. Chip color is purple/gradient, never the blue of `VerifiedMark`.

- [ ] **Step 1: Failing tests:** chip "reads 'Huy hiệu {tên}'"; row "shows at most max chips and 'Tất cả' only with onSeeAll"; tile "earned uses the gradient disc", "not earned is grey with 'Chưa đạt' and, with progress, a CapacityBar and '3 / 5'", "isNew shows the 'Mới' dot with a label"; "unknown code uses the fallback icon"; grid of 2 columns at 320 dp/1.3× no overflow; skeleton sizes.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(core): badge chip, row and tile`.

---

### Task 5: `NotificationRow` and `NotificationBell`

**Files:** create `notification_row.dart`, `notification_bell.dart`; `core.dart`; ARB; tests.

**Interfaces:**

```dart
enum NotificationKind { booking, payment, chat, event, badge, system }
@immutable
class NotificationRowData {
  const NotificationRowData({required this.id, required this.kind, required this.title, required this.body,
      required this.timeLabel, required this.unread, this.thumbUrl, this.groupAvatars = const []});
  // timeLabel is already relative ("5 phút"); groupAvatars non-empty = grouped row, max 3 shown
}
class NotificationRow extends StatelessWidget {
  const NotificationRow({super.key, required this.item, required this.onTap, required this.onMarkRead, required this.onMuteKind});
  static Widget skeleton();
}
class NotificationBell extends StatelessWidget { const NotificationBell({super.key, required this.unread, required this.onTap}); }
```

Spec layout. Long-press opens a small menu (`showAppSheet` with two `AppOptionTile`-style rows) "Đánh dấu đã đọc" (hidden when read) / "Tắt loại thông báo này"; the same two are `Semantics.customSemanticsActions`. Bell: 36 dp icon, 48 dp target, red dot with count ("9+" like `TabBadge`), hidden at 0; label "Thông báo" or "{n} thông báo chưa đọc".

- [ ] **Step 1: Failing tests:** "unread shows the dot and reads 'Chưa đọc. {title}. {body}. {time}'"; "read row has no dot and no 'Chưa đọc'"; "one icon per kind"; "grouped row shows at most 3 avatars"; "long press offers mark read and mute; read rows only mute"; "custom semantics actions call onMarkRead/onMuteKind"; "body max 2 lines"; "row height ≥ 48"; bell "hidden dot at 0, '9+' at 10, labels per count, target 48"; skeleton size.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(core): notification row and bell`.

---

### Task 6: `PermissionPrimer` and its snooze policy; explore uses `EventCard`

**Files:** create `permission_primer.dart`, `lib/core/permission_primer_policy.dart`; delete `lib/features/explore/widgets/event_tile.dart`; modify `explore_screen.dart`; tests `test/core/widgets/permission_primer_test.dart`, `test/core/permission_primer_policy_test.dart`, update `test/features/explore/*` that find `NearbyEventTile`.

**Interfaces:**

```dart
class PermissionPrimer extends StatelessWidget {
  const PermissionPrimer({super.key, required this.title, required this.benefit, required this.onEnable, required this.onLater});
}
abstract interface class PrimerStore { DateTime? get lastSnoozed; Future<void> snooze(DateTime at); }
class PermissionPrimerPolicy {
  const PermissionPrimerPolicy({required this.store, required this.now, this.snoozeFor = const Duration(days: 7)});
  /// False on app start (`atAppStart: true`) and within [snoozeFor] of the last "Để sau".
  bool shouldAsk({required bool atAppStart});
  Future<void> later();   // store.snooze(now())
}
```

Primer: bell icon, title, benefit line, `AppButton.primary` "Bật thông báo", text button "Để sau"; the widget is content only (the caller wraps it in `showAppSheet`).

Explore: replace `NearbyEventTile(event: e, distanceLabel: …, onTap: …)` with `EventCard(data: eventCardDataOf(e, l), distanceLabel: …, onTap: …)`; the S02.03 horizontal section uses `EventCard(size: compact)` if the mock shows cards there (check mock S02.03), otherwise row. Loading of those lists already goes through `AsyncView` after plan A; switch its skeleton to `EventCard.skeleton(...)`.

- [ ] **Step 1: Failing tests:** primer "one primary button 'Bật thông báo', 'Để sau' calls onLater"; policy "never asks at app start", "asks when never snoozed", "does not ask within 7 days of later()", "asks again after 7 days" (fake clock and in-memory store); explore tests updated to find `EventCard` and its skeleton; existing explore behaviour tests still pass.
- [ ] **Steps 2–4:** implement; run the whole suite (source rules included) → PASS; analyze clean.
- [ ] **Step 5: Commit** `feat(core): permission primer and snooze policy; explore lists use EventCard`.

---

### Task 7: Gallery and spec in step

**Files:** `scripts/tools/build_ui_components.py`, `docs/design/ui-components.html`, `docs/superpowers/specs/components/shared-components.md`.

- [ ] **Step 1:** where a built widget differs from its gallery tile, update the tile to match; add a `DateBlock` and `BadgeRow` tile if missing; run `python3 scripts/tools/build_ui_components.py` from the repo root.
- [ ] **Step 2:** spec: "· Mới" → "· Đã có" for EventCard và DateBlock, TicketCard, BadgeChip, BadgeTile, NotificationRow, NotificationBell, PermissionPrimer; record the view-data class names (Decision 1) under each entry; section 7 group B split into B1 (done) and B2 (instant, pending).
- [ ] **Step 3: Commit** `docs(components): gallery and spec match the built group B1 widgets`.

## Interfaces for later plans

- Events plans (S11, S12, S02.03/S02.04): `EventCard`/`EventCardData`/`eventCardDataOf`, `DateBlock`, `TicketCard`/`TicketCardData`/`TicketState`, `FreeTag`/`FreeBanner`, `CapacityBar`.
- Badges plan (S03.02, S03.01, S09.01, cards): `BadgeView`, `BadgeProgress`, `BadgeChip`, `BadgeRow`, `BadgeTile`.
- Notifications plan (S17): `NotificationKind`, `NotificationRowData`, `NotificationRow`, `NotificationBell`, `PermissionPrimer`, `PermissionPrimerPolicy`, `PrimerStore` (adapter there).

## Self-review notes

- Spec coverage: every group-B entry that is not instant-specific has a task; FreeTag and CapacityBar already exist and are reused; FreeBanner is checked in File Structure (create only if missing).
- No data entities for tickets, badges or notifications exist yet; the plan deliberately stops at view data so it does not pre-empt those designs.
