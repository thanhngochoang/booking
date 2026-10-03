# Handover ledger — b1/7-L2 (Shared Components B1)

Unit: `b1/7-L2` (Lane 2 Step 7)  
Branch: `plan/b1-7-L2-shared-components`  
Target: `develop`  
Plan: `docs/superpowers/plans/2026-10-02-shared-components-b1.md`

## Scope Completed

### 1. Task 1: `DateBlock`
- Created `app_flutter/lib/core/widgets/date_block.dart`.
- Supports `DateBlockSize` (`regular` 46×52, `compact` 38×44) and `DateBlockFormat` (`regular`, `compact`).
- `DateBlock.skeleton()` provides consistent loading placeholder with configurable sizing and key pass-through.
- Exported in `app_flutter/lib/core/core.dart`.
- Tests in `app_flutter/test/core/widgets/date_block_test.dart` (5 tests passing).

### 2. Task 2: `EventCard` & Data Mapper
- Created `app_flutter/lib/core/widgets/event_card.dart`.
- `EventCardData` immutable view-data model with title, hostName, placeName, category, day, priceVnd, spotsLeft, coverUrl, and distanceKm.
- Data mapper `eventCardDataOf(Event e, AppLocalizations l)` for seamless conversion from domain entity to card view model.
- Sizes: `EventCardSize.row`, `EventCardSize.featured`, `EventCardSize.compact` (176dp).
- Integrates `DateBlock`, `FreeTag` (for zero price), and spots left indicator ("Còn {n} chỗ" / "Hết chỗ").
- `EventCard.skeleton()` provides matching skeleton for each size.
- Exported in `app_flutter/lib/core/core.dart`.
- Tests in `app_flutter/test/core/widgets/event_card_test.dart` (6 tests passing).

### 3. Task 3: `TicketCard` with QR
- Created `app_flutter/lib/core/widgets/ticket_card.dart`.
- `TicketCardData` view-data model and `TicketState` enum (`registered`, `attended`, `cancelled`).
- 112dp QR code rendered via `qr_flutter` (error correction level M) on white background with copyable ticket code.
- GlassCard styling: highlighted for `registered`, muted for `attended`/`cancelled`.
- Action buttons: "Chỉ đường", "Thêm vào lịch", "Huỷ vé", "Chia sẻ".
- `TicketCard.skeleton()` with matching card structure and QR placeholder.
- Exported in `app_flutter/lib/core/core.dart`.
- Tests in `app_flutter/test/core/widgets/ticket_card_test.dart` (6 tests passing).

### 4. Task 4: `BadgeChip`, `BadgeRow`, `BadgeTile`
- Created `app_flutter/lib/core/widgets/badge_chip.dart` and `app_flutter/lib/core/widgets/badge_tile.dart`.
- Models: `BadgeView` (code, name, condition, earned), `BadgeProgress` (current, total), and `badgeIconOf(String code)` helper.
- `BadgeChip`: compact chip with CtaSurface icon disc when earned (or muted disc when locked), glass background, and `BadgeChip.skeleton()`.
- `BadgeRow`: Wrap layout displaying up to `max` chips (default 3) followed by "Tất cả" action button, and `BadgeRow.skeleton({int count})`.
- `BadgeTile`: Large badge tile with 36dp disc, semibold title, condition description, `CapacityBar` progress indicator, and "MỚI" indicator dot.
- Exported in `app_flutter/lib/core/core.dart`.
- Tests in `app_flutter/test/core/widgets/badge_chip_test.dart` (6 tests) and `app_flutter/test/core/widgets/badge_tile_test.dart` (4 tests).

### 5. Task 5: `NotificationRow` and `NotificationBell`
- Created `app_flutter/lib/core/widgets/notification_row.dart` and `app_flutter/lib/core/widgets/notification_bell.dart`.
- Models: `NotificationKind` (`booking`, `payment`, `chat`, `event`, `badge`, `system`), and `NotificationRowData`.
- `NotificationRow`: unread purple indicator, semantic kind icons, max 2-line body, relative time label, avatar grouping (up to 3 avatars), long press modal menu with options ("Đánh dấu đã đọc", "Tắt loại thông báo này"), `customSemanticsActions`, and `NotificationRow.skeleton()`.
- `NotificationBell`: 36dp bell icon with 48dp hit target, badge count ("9+" for >= 10, hidden at 0), contextual semantics labels.
- Localized strings added to `app_flutter/lib/l10n/app_vi.arb`.
- Exported in `app_flutter/lib/core/core.dart`.
- Tests in `app_flutter/test/core/widgets/notification_row_test.dart` (8 tests) and `app_flutter/test/core/widgets/notification_bell_test.dart` (5 tests).

### 6. Task 6: `PermissionPrimer`, Snooze Policy & Explore Migration
- Created `app_flutter/lib/core/permission_primer_policy.dart` with `PrimerStore` interface and `PermissionPrimerPolicy` (7-day snooze, app-start suppression).
- Created `app_flutter/lib/core/widgets/permission_primer.dart` with bell icon, contextual title, benefit list, `AppButton.primary` "Bật thông báo", and "Để sau" button.
- Deleted obsolete `app_flutter/lib/features/explore/widgets/event_tile.dart` and test `event_tile_test.dart`.
- Migrated `app_flutter/lib/features/explore/screens/explore_screen.dart` to use `EventCard(size: EventCardSize.row)` and `EventCard.skeleton(size: EventCardSize.row)`.
- Updated explore feature tests and battery source code audits.
- Exported both in `app_flutter/lib/core/core.dart`.
- Tests in `app_flutter/test/core/permission_primer_policy_test.dart` (4 tests) and `app_flutter/test/core/widgets/permission_primer_test.dart` (2 tests).

### 7. Task 7: Gallery and Spec Alignment
- Updated `scripts/tools/build_ui_components.py` with tiles for `DateBlock`, `EventCard`, `TicketCard`, `BadgeChip · BadgeRow · BadgeTile`, `NotificationRow · NotificationBell`, and `PermissionPrimer`.
- Regenerated `docs/design/ui-components.html` (35 components total).
- Updated `docs/superpowers/specs/components/shared-components.md` to reflect all built components as "Đã có", added view-data class references, and split Section 7 Group B into B1 (done) and B2 (pending).
- Checked off all tasks in progress ledger.

## Verification
- `flutter analyze`: 0 issues found.
- `flutter test`: all core widget and explore feature tests pass cleanly.
