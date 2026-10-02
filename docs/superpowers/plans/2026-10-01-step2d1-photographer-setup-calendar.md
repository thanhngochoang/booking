# Step 2d1: Photographer Setup Steps 1–2 and the Availability Calendar (S24, S20) Implementation Plan

> **Battery/performance (2026-10-02, user):** this plan has no battery, idle, blur-budget or performance task or test steps. All of that runs once at the end in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Skip any such step inside a task (e.g. `expectIdle`, `expectBlurBudget`, listener counters, profiling); keep the functional tests.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new photographer fills in an introduction (name, bio, equipment) and at least one service package (name, price in VND, duration, edited photos, delivery days) in setup steps 1/4 and 2/4 without losing anything when they leave halfway, and manages their days off on "Lịch của tôi" (S20), a month grid with the four day states that customers will see in the same `AvailabilityCalendar` later (S03, S06).

**Architecture:** Plain Dart helpers in `lib/core/` (`calendar_days.dart`, `vnd_input.dart`, `package_meta.dart`) and one new stateless core widget, `AvailabilityCalendar` (+ `AvailabilityLegend`, `DayState`), driven only by its arguments so S20, S03 and S06 share it. Three ports in `lib/data/photographer/` (`AvailabilityRepository`, `PhotographerIntroRepository`, `ServicePackageRepository`), each with an in-memory fake that counts its open listeners and a Firestore adapter (the only files importing `cloud_firestore`). Firestore rules validate exactly what the client may write: `off` days only, the intro fields, and package values. Screens live in `lib/features/photographer_setup/` (S24, next to plan 2b's S34) and `lib/features/calendar/` (S20); controllers are `AsyncNotifier`s, screens never call a repository. Unsaved input of the setup flow is kept per user in `SharedPreferences` (`SetupDraftStore`), saved data goes to Firestore on "Tiếp tục" / "Thêm gói này".

**Tech Stack:** Flutter, Riverpod 3, go_router, `shared_preferences` (present), `cloud_firestore` (adapters only), Firestore rules + `@firebase/rules-unit-testing` (Node), `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` §1, §1.2, §4 (`AvailabilityCalendar`, `StepProgress`), §5 (S20, S24), §6 step 2, §7; `docs/superpowers/specs/screens/photographer.md` (S20, S24) and `screens/README.md` (conventions); `docs/superpowers/specs/components/shared-components.md` (`AvailabilityCalendar`, `StepProgress`, `SegmentedTabs`, `AppChip`, `AppBottomSheet`); `docs/superpowers/specs/data-model/README.md` §2 (ULID ids, UTC instants, `LocalDate`, integer VND, string enum codes), `domain-model.md` (`Photographer`, `Service`, `AvailabilityDay`, `DayState`, invariants 1 and 3), `relational-schema.md` §2.2 and §3 (`photographers/{uid}/services/{id}`, `availability/{uid}/days/{yyyy-mm-dd}`); the original `2026-09-30-photography-marketplace-design.md` §5 (`availability` documents: no document = free; `booked`/`pending` written by `transitionBooking`); mock `docs/design/ui-mock.html` (`data-code="S20"`, `"S24"`).

**Prerequisite (run order):** screen-codes → core-display-widgets → 2a → 2b → 3a1 → 3a2 → 3b1 → 3b2 → 2c → **2d1 (this plan)** → 3b3 → 3b4 → 3c → 2d2. This is the order plan 2c fixes; every plan before 2d1 must be done. This plan uses, without redefining them:

- screen-codes: `ScreenCode(String code, {Key? key, String? label, required Widget child})`, `ScreenCodes.setupProfile` (`S24`), `ScreenCodes.myCalendar` (`S20`), `test/support/idle.dart` (`Future<void> expectIdle(WidgetTester tester)`), `docs/testing/battery-and-performance.md`.
- core-display-widgets: `const StepProgress({super.key, required int current, required int total, String? label})` (renders "n / N"), `hostWidget(Widget child, {Brightness brightness = Brightness.dark, double width = 390, double textScale = 1.0})` in `test/core/widgets/widget_host.dart`.
- 2b: the `photographers/{uid}` rules block with `validServiceArea()`, `validContactChannels(uid)` and `private/{docId}`; the route `/setup/4` (S34).
- 3a1: `toVn`, `vnDateKey`, `parseDayKey` (`lib/core/vn_time.dart`), `AppChip`/`AppChipKind`, `SegmentedTabs`/`SegmentOption`, `Future<T?> showAppSheet<T>(BuildContext, {required WidgetBuilder builder})`, `test/support/blur.dart` (`void expectBlurBudget({int max = 4})`).
- 3a2: `String formatMoney(int vnd, {bool short = false})` in `lib/core/format.dart`; l10n `retry` ("Thử lại", already in the ARB).
- 2c: the routes `/setup/3` (S38, setup step 3/4) and `/profile/skills`; `photographers/{uid}.skills` and its rules, owned by 2c. **Years of experience live in `skills.yearsExperience` and are edited only on S39 (plan 2c)**; this plan does not ask for them (see Self-Review).

One helper belongs to a later plan: `newUlid` (plan 3c, Task 1). Task 1 adds it **only when it is missing, with exactly the code and tests of plan 3c**, so when 3c runs its step finds the identical file and only its other changes remain.

**Plans that come after this one and rely on it:** 3b3 (`AvailabilityLookup` reads the same `availability/{uid}/days/{day}` documents; this plan already adds their read rule), 3b4 (S04 date picker can switch to `AvailabilityCalendar`), 3c ("Thêm gói" in S21 pushes `/setup/2`), and 2d2 (S03, S30 and S42 hooks).

## How plan 2d is split

| Plan | Content | Screens | Runs |
|---|---|---|---|
| **2d1 (this)** | calendar days, VND input, `AvailabilityCalendar`, availability / intro / package repositories and rules, S24 steps 1–2, S20, setup entry points | S20, S24 | after 2c |
| 2d2 | `ImageBackdrop`, public profile read model, S03 `/u/:uid`, avatar upload (S42 and S24 step 1), S30 rows (phone, skills, public profile) | S03, S30, S42 | after 3c (it reuses the 3b1–3b4 read models and cards, 2c's skills and the 3c media ports) |

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Run `dart format lib test` before each commit (`require_trailing_commas` is a lint and `flutter analyze` fails on infos).
- Imports are `package:photobooking/...` only (lint `always_use_package_imports`); features and `data/` import `package:photobooking/core/core.dart`; files inside `core/` import each other directly.
- **Firebase isolation:** `cloud_firestore` appears only in `lib/data/photographer/firestore_availability_repository.dart`, `firestore_photographer_intro_repository.dart`, `firestore_service_package_repository.dart` (and the existing adapters). Models, ports, fakes, controllers and screens import no Firebase package. Adapters take `FirebaseFirestore? db` and resolve `FirebaseFirestore.instance` lazily, so a test that forgets an override gets an `AsyncError`, not a crash at provider creation.
- **Data conventions** (`data-model/README.md`): new package ids are ULIDs made on the device (`newUlid`); a calendar day is a `LocalDate`, held in Dart as a UTC-midnight `DateTime` and stored as the document id `yyyy-MM-dd` (`vnDateKey`); money is an `int` of VND, always `> 0` for a package, never a `double`; enum codes are strings (`off`, `pending`, `booked`; free = no document); no Firebase type leaves an adapter.
- **Who writes what:** the photographer writes only `off` days (create and delete, never update) and never touches `booked`/`pending` days, which the server writes from bookings and events; the client never writes `startingPrice`, `stats.*`, `verified`, `onboardingComplete: true` (that is 2b's S34) or deletes a package (it hides it with `active: false`, so posts and past bookings keep a valid `serviceId`).
- **Theme and UI:** `AuroraBackground` + transparent `Scaffold`; colours from `Theme`/`AppColors`/`AppColorsDark`, sizes from `AppSpace`/`AppRadius`/`AppText`; no raw hex. One `AppButton.primary` per screen ("Tiếp tục" on S24, "Đánh dấu nghỉ" on S20); hiding a package is a red button inside a confirmation sheet. At most 4 `BackdropFilter`s per screen, none nested, no blur on list rows. Touch targets ≥ 48dp (calendar cells 44dp tall, see Risks). No hard-coded UI text: Vietnamese strings with full diacritics in `lib/l10n/app_vi.arb`, then `flutter gen-l10n`.
- **Tests:** every screen and the calendar widget are tested at 320dp width and 1.3× text in light and dark (`tester.takeException()` is null); widget tests use `ProviderScope(retry: (_, _) => null, …)` so a failing provider leaves no retry timer; every provider that reaches Firebase is overridden with a fake.
- **Battery:** no `Timer`, `Stream.periodic` or `AnimationController` in this plan's code; Firestore listeners are `autoDispose` and live only while their screen is open (the own-profile intro stream used by S30 is the one allowed long-lived listener, per `docs/testing/battery-and-performance.md`); S20 keeps one month listener at a time.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/calendar_days.dart` (create) | `calendarDay`, `monthOf`, `addMonths`, `lastDayOfMonth`, `vnToday`, `monthGrid`, `daysBetween` |
| `lib/core/vnd_input.dart` (create) | `parseVnd`, `groupVnd`, `VndInputFormatter` |
| `lib/core/package_meta.dart` (create) | `durationLabel`, `packageMeta` (shared by S24 and S03) |
| `lib/core/ulid.dart` (create only if missing) | `newUlid`/`ulidTime` (verbatim from plan 3c) |
| `lib/core/widgets/availability_calendar.dart` (create) | `DayState`, `weekdayCode`, `AvailabilityCalendar`, `AvailabilityLegend` |
| `lib/core/core.dart` (modify) | exports |
| `lib/data/photographer/availability_repository.dart` (create) | `AvailabilityDay`, mapping, `AvailabilityRepository`, `FakeAvailabilityRepository` |
| `lib/data/photographer/firestore_availability_repository.dart` (create) | Firestore adapter |
| `lib/data/photographer/availability_providers.dart` (create) | `availabilityRepositoryProvider`, `availabilityMonthProvider`, `calendarTodayProvider` |
| `lib/data/photographer/photographer_intro.dart` (create) | `PhotographerIntro`, mapping, `PhotographerIntroRepository`, `FakePhotographerIntroRepository` |
| `lib/data/photographer/firestore_photographer_intro_repository.dart` (create) | Firestore adapter |
| `lib/data/photographer/service_package.dart` (create) | `ServicePackageInput`, `ServicePackage`, mapping, `ServicePackageRepository`, `FakeServicePackageRepository` |
| `lib/data/photographer/firestore_service_package_repository.dart` (create) | Firestore adapter |
| `lib/data/photographer/photographer_setup_providers.dart` (create) | repository providers, `myIntroProvider`, `myPackagesProvider` |
| `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs` (modify) | availability days, intro fields, package values |
| `lib/features/photographer_setup/setup_draft_store.dart` (create) | `IntroDraft`, `PackageDraft`, `SetupDraftStore`, `setupDraftStoreProvider`, `setupResumePath` |
| `lib/features/photographer_setup/intro_logic.dart` (create) | step 1 validation |
| `lib/features/photographer_setup/setup_intro_controller.dart`, `setup_intro_screen.dart` (create) | S24 step 1 |
| `lib/features/photographer_setup/package_logic.dart` (create) | step 2 validation |
| `lib/features/photographer_setup/setup_packages_controller.dart`, `setup_packages_screen.dart` (create) | S24 step 2 |
| `lib/features/calendar/my_calendar_controller.dart`, `my_calendar_screen.dart` (create) | S20 |
| `lib/app/router.dart` (modify) | `/setup`, `/setup/1`, `/setup/2`, `/work/calendar`, `photographerOnlyRedirect` |
| `lib/features/shell/placeholder_tabs.dart` (modify) | S30 setup card and post-switch redirect, calendar entry on the photographer's work tab |
| `lib/l10n/app_vi.arb` (modify) | strings (listed per task) |
| `docs/superpowers/specs/screens/photographer.md`, `components/shared-components.md` (modify) | align S20/S24 and the calendar API with what was built |
| `test/support/photographer_world.dart` (create) | fakes, overrides, router app, `usePhone` |
| tests | listed per task; `test/battery/photographer_setup_battery_test.dart` |

---

### Task 1: Calendar days, VND input, and the borrowed ULID helper

**Files:**
- Create: `lib/core/calendar_days.dart`, `lib/core/vnd_input.dart`, `test/core/calendar_days_test.dart`, `test/core/vnd_input_test.dart`
- Create only if missing: `lib/core/ulid.dart`, `test/core/ulid_test.dart`
- Modify: `lib/core/core.dart`

**Interfaces:**
- Consumes: `DateTime toVn(DateTime instant)` (3a1, `lib/core/vn_time.dart`).
- Produces:
  - `DateTime calendarDay(DateTime d)` → `DateTime.utc(d.year, d.month, d.day)`; `DateTime monthOf(DateTime d)`; `DateTime addMonths(DateTime month, int n)`; `DateTime lastDayOfMonth(DateTime month)`; `DateTime vnToday(DateTime nowUtc)`; `List<DateTime> monthGrid(DateTime month)` (42 days, Monday first); `List<DateTime> daysBetween(DateTime a, DateTime b)` (inclusive, either order).
  - `int? parseVnd(String text)` (digits only, at most 10, else null); `String groupVnd(int vnd)` → `3.200.000`; `class VndInputFormatter extends TextInputFormatter { const VndInputFormatter(); }`.
  - When missing: `String newUlid({DateTime? now, math.Random? random})`, `DateTime? ulidTime(String id)` (plan 3c Task 1 code).

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/calendar_days_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/calendar_days.dart';

void main() {
  test('calendarDay and monthOf drop the time and keep the date', () {
    expect(calendarDay(DateTime.utc(2026, 10, 12, 23, 59)), DateTime.utc(2026, 10, 12));
    expect(calendarDay(DateTime(2026, 10, 12, 1)), DateTime.utc(2026, 10, 12));
    expect(monthOf(DateTime.utc(2026, 10, 12)), DateTime.utc(2026, 10));
  });

  test('addMonths and lastDayOfMonth cross years and leap days', () {
    expect(addMonths(DateTime.utc(2026, 12), 1), DateTime.utc(2027, 1));
    expect(addMonths(DateTime.utc(2026, 1), -1), DateTime.utc(2025, 12));
    expect(lastDayOfMonth(DateTime.utc(2028, 2)), DateTime.utc(2028, 2, 29));
    expect(lastDayOfMonth(DateTime.utc(2026, 10)), DateTime.utc(2026, 10, 31));
  });

  test('vnToday reads the Vietnamese wall calendar', () {
    expect(vnToday(DateTime.utc(2026, 9, 30, 18)), DateTime.utc(2026, 10, 1));
    expect(vnToday(DateTime.utc(2026, 9, 30, 16, 59)), DateTime.utc(2026, 9, 30));
  });

  test('monthGrid is six Monday-first weeks around the month', () {
    final g = monthGrid(DateTime.utc(2026, 10));
    expect(g, hasLength(42));
    expect(g.first, DateTime.utc(2026, 9, 28)); // 1 Oct 2026 is a Thursday
    expect(g[3], DateTime.utc(2026, 10, 1));
    expect(g.last, DateTime.utc(2026, 11, 8));
    expect(g.every((d) => d.isUtc && d.hour == 0), isTrue);
    expect(monthGrid(DateTime.utc(2026, 6)).first, DateTime.utc(2026, 6, 1)); // a Monday
  });

  test('daysBetween is inclusive and order-free', () {
    expect(daysBetween(DateTime.utc(2026, 10, 3), DateTime.utc(2026, 10, 1)), [
      DateTime.utc(2026, 10, 1),
      DateTime.utc(2026, 10, 2),
      DateTime.utc(2026, 10, 3),
    ]);
    expect(daysBetween(DateTime.utc(2026, 10, 31), DateTime.utc(2026, 11, 1)), hasLength(2));
    expect(daysBetween(DateTime.utc(2026, 10, 5), DateTime.utc(2026, 10, 5)), [DateTime.utc(2026, 10, 5)]);
  });
}
```

```dart
// test/core/vnd_input_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/vnd_input.dart';

void main() {
  test('parseVnd reads the digits only', () {
    expect(parseVnd('3.200.000'), 3200000);
    expect(parseVnd(' 1500000 ₫'), 1500000);
    expect(parseVnd(''), isNull);
    expect(parseVnd('abc'), isNull);
    expect(parseVnd('12345678901'), isNull, reason: 'more than 10 digits');
  });

  test('groupVnd groups thousands with dots', () {
    expect(groupVnd(1500000), '1.500.000');
    expect(groupVnd(500), '500');
    expect(groupVnd(0), '0');
  });

  testWidgets('VndInputFormatter keeps a money field grouped', (tester) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: TextField(controller: c, inputFormatters: const [VndInputFormatter()]),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '3200000');
    expect(c.text, '3.200.000');
    await tester.enterText(find.byType(TextField), '00a15');
    expect(c.text, '15');
    await tester.enterText(find.byType(TextField), '123456789012');
    expect(c.text, '1.234.567.890');
    await tester.enterText(find.byType(TextField), '');
    expect(c.text, '');
  });
}
```

If `lib/core/ulid.dart` does not exist, also create `test/core/ulid_test.dart` with exactly the content of plan 3c Task 1 Step 1 (`test/core/ulid_test.dart`, five tests).

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/calendar_days_test.dart test/core/vnd_input_test.dart`
Expected: FAIL, `package:photobooking/core/calendar_days.dart` and `vnd_input.dart` not found.

- [ ] **Step 3: Implement**

```dart
// lib/core/calendar_days.dart
import 'package:photobooking/core/vn_time.dart';

/// Calendar days are plain dates on the Vietnamese wall calendar
/// (`LocalDate` in the data model). In Dart they are UTC-midnight
/// `DateTime`s, so two days compare and hash by date alone; `vnDateKey(day)`
/// gives their `yyyy-MM-dd` key.
DateTime calendarDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// The first day of [d]'s month.
DateTime monthOf(DateTime d) => DateTime.utc(d.year, d.month);

/// [month] moved by [n] months (negative goes back); always the 1st.
DateTime addMonths(DateTime month, int n) => DateTime.utc(month.year, month.month + n);

DateTime lastDayOfMonth(DateTime month) => DateTime.utc(month.year, month.month + 1, 0);

/// Today on the Vietnamese calendar for the instant [nowUtc].
DateTime vnToday(DateTime nowUtc) => calendarDay(toVn(nowUtc));

/// The 42 days (six weeks, Monday first) a month grid shows for [month].
List<DateTime> monthGrid(DateTime month) {
  final first = monthOf(month);
  final lead = first.weekday - DateTime.monday;
  return [
    for (var i = 0; i < 42; i++) DateTime.utc(first.year, first.month, 1 - lead + i),
  ];
}

/// Every day from [a] to [b], both included, oldest first.
List<DateTime> daysBetween(DateTime a, DateTime b) {
  final start = calendarDay(a.isBefore(b) ? a : b);
  final end = calendarDay(a.isBefore(b) ? b : a);
  return [
    for (var d = start; !d.isAfter(end); d = DateTime.utc(d.year, d.month, d.day + 1)) d,
  ];
}
```

```dart
// lib/core/vnd_input.dart
import 'package:flutter/services.dart';

/// Whole đồng typed in a money field (dots, spaces and `₫` ignored); null
/// when there are no digits or more than 10 of them.
int? parseVnd(String text) {
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty || digits.length > 10) {
    return null;
  }
  return int.parse(digits);
}

/// `3200000` → `3.200.000`: the inside of a money field, without `₫`.
String groupVnd(int vnd) {
  final s = vnd.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) {
      out.write('.');
    }
    out.write(s[i]);
  }
  return out.toString();
}

/// Keeps a money field as grouped digits while typing or pasting; at most
/// 10 digits, leading zeros dropped.
class VndInputFormatter extends TextInputFormatter {
  const VndInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 10 ? digits.substring(0, 10) : digits;
    final text = capped.isEmpty ? '' : groupVnd(int.parse(capped));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
```

Borrowed helper (only when missing): if `lib/core/ulid.dart` does not exist, create it with exactly the code of plan 3c Task 1 Step 3 (`// lib/core/ulid.dart`, `newUlid` and `ulidTime`) and add `export 'package:photobooking/core/ulid.dart';` to `core.dart`.

Add to `lib/core/core.dart` (keep alphabetical order with the existing exports):

```dart
export 'package:photobooking/core/calendar_days.dart';
export 'package:photobooking/core/vnd_input.dart';
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core && flutter analyze`
Expected: PASS (calendar days 5, VND input 3, plus the five ULID tests if they were added); analyze clean.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core test/core
git commit -m "feat(core): calendar days and VND input helpers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `AvailabilityCalendar`, `DayState` and the legend

**Files:**
- Create: `lib/core/widgets/availability_calendar.dart`, `test/core/widgets/availability_calendar_test.dart`
- Modify: `lib/core/core.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `calendarDay`, `monthOf`, `addMonths`, `monthGrid` (Task 1); `ctaGradientFor` (`cta_surface.dart`); `hostWidget`.
- Produces:
  - `enum DayState { free, pending, booked, off }`; `extension DayStateLabel on DayState { String label(AppLocalizations l); }`; `String weekdayCode(int weekday)` → `mon` … `sun`.
  - `const AvailabilityCalendar({super.key, required DateTime month, required Map<DateTime, DayState> states, DateTime? selected, ValueChanged<DateTime>? onSelect, ValueChanged<DateTime>? onLongPress, bool editable = false, ValueChanged<DateTime>? onMonthChanged, DateTime? minDate, DateTime? maxDate, DateTime? today, Set<DateTime> eventDays = const {}, DateTime? rangeStart, bool showHeader = true})` — the shared-components API plus `onLongPress` (range start, the alternative to dragging), `maxDate`, `today`, `eventDays` (dot under days with an event), `rangeStart` (ring on the range's first day) and `showHeader`. All days are calendar days (UTC midnight). A cell calls `onSelect`/`onLongPress` only when it is in the shown month, inside `[minDate, maxDate]`, and either `editable` is true or its state is `free` (booking mode: "Chờ" days are visible but not selectable). Swipe left/right and the header arrows call `onMonthChanged` within the bounds. Each cell is 44dp tall with `Semantics` "12 tháng 10, rảnh" (`, có sự kiện`, `, hôm nay` appended).
  - `const AvailabilityLegend({super.key})` — the four states with their labels.
  - l10n: `calendarMonthTitle(month, year)` "Tháng {month}, {year}", `calendarMonthShort(month)` "Tháng {month}", `calendarPrevMonth` "Tháng trước", `calendarNextMonth` "Tháng sau", `calendarWeekdayShort(weekday)` (T2 … CN), `calendarWeekdayLong(weekday)` (Thứ 2 … Chủ nhật), `calendarDayTitle(weekday, day, month)` "{weekday}, {day}/{month}", `dayStateFree` "Rảnh", `dayStatePending` "Chờ nhận", `dayStateBooked` "Đã đặt", `dayStateOff` "Nghỉ", `calendarDaySemantics(day, month, state)` "{day} tháng {month}, {state}", `calendarHasEvent` "có sự kiện", `calendarToday` "hôm nay".

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/availability_calendar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

final _oct = DateTime.utc(2026, 10);
DateTime _d(int day) => DateTime.utc(2026, 10, day);
final _states = {_d(10): DayState.booked, _d(11): DayState.pending, _d(12): DayState.off};

Widget _cal({
  bool editable = false,
  ValueChanged<DateTime>? onSelect,
  ValueChanged<DateTime>? onLongPress,
  ValueChanged<DateTime>? onMonthChanged,
  DateTime? minDate,
  DateTime? maxDate,
  Set<DateTime> eventDays = const {},
}) => AvailabilityCalendar(
  month: _oct,
  states: _states,
  editable: editable,
  onSelect: onSelect,
  onLongPress: onLongPress,
  onMonthChanged: onMonthChanged,
  minDate: minDate,
  maxDate: maxDate,
  today: _d(1),
  eventDays: eventDays,
);

void main() {
  testWidgets('shows the month, the weekdays and every state in words', (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(_cal()));
    expect(find.text('Tháng 10, 2026'), findsOneWidget);
    for (final w in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']) {
      expect(find.text(w), findsOneWidget);
    }
    expect(find.bySemanticsLabel('10 tháng 10, đã đặt'), findsOneWidget);
    expect(find.bySemanticsLabel('11 tháng 10, chờ nhận'), findsOneWidget);
    expect(find.bySemanticsLabel('12 tháng 10, nghỉ'), findsOneWidget);
    expect(find.bySemanticsLabel('13 tháng 10, rảnh'), findsOneWidget);
    expect(find.bySemanticsLabel('1 tháng 10, rảnh, hôm nay'), findsOneWidget);
    expect(find.bySemanticsLabel('28 tháng 9, rảnh'), findsNothing, reason: 'days of other months are decoration');
    h.dispose();
  });

  testWidgets('booking mode selects free days only', (tester) async {
    final h = tester.ensureSemantics();
    final picked = <DateTime>[];
    await tester.pumpWidget(hostWidget(_cal(onSelect: picked.add)));
    await tester.tap(find.bySemanticsLabel('13 tháng 10, rảnh'));
    await tester.tap(find.bySemanticsLabel('10 tháng 10, đã đặt'));
    await tester.tap(find.bySemanticsLabel('11 tháng 10, chờ nhận'));
    await tester.tap(find.bySemanticsLabel('12 tháng 10, nghỉ'));
    expect(picked, [_d(13)]);
    h.dispose();
  });

  testWidgets('editable mode reports every day and long presses', (tester) async {
    final h = tester.ensureSemantics();
    final picked = <DateTime>[];
    final held = <DateTime>[];
    await tester.pumpWidget(
      hostWidget(_cal(editable: true, onSelect: picked.add, onLongPress: held.add)),
    );
    await tester.tap(find.bySemanticsLabel('12 tháng 10, nghỉ'));
    await tester.tap(find.bySemanticsLabel('10 tháng 10, đã đặt'));
    await tester.longPress(find.bySemanticsLabel('20 tháng 10, rảnh'));
    expect(picked, [_d(12), _d(10)]);
    expect(held, [_d(20)]);
    h.dispose();
  });

  testWidgets('days before minDate cannot be picked', (tester) async {
    final h = tester.ensureSemantics();
    final picked = <DateTime>[];
    await tester.pumpWidget(hostWidget(_cal(editable: true, onSelect: picked.add, minDate: _d(5))));
    await tester.tap(find.bySemanticsLabel('3 tháng 10, rảnh'));
    await tester.tap(find.bySemanticsLabel('5 tháng 10, rảnh'));
    expect(picked, [_d(5)]);
    h.dispose();
  });

  testWidgets('swipe and arrows change the month inside the bounds', (tester) async {
    final months = <DateTime>[];
    await tester.pumpWidget(hostWidget(_cal(onMonthChanged: months.add)));
    await tester.fling(find.byType(AvailabilityCalendar), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tháng trước'));
    expect(months, [DateTime.utc(2026, 11), DateTime.utc(2026, 9)]);

    months.clear();
    await tester.pumpWidget(
      hostWidget(_cal(onMonthChanged: months.add, minDate: _d(1), maxDate: _d(31))),
    );
    await tester.fling(find.byType(AvailabilityCalendar), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(months, isEmpty);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left_rounded)).onPressed, isNull);
  });

  testWidgets('event days are marked and said', (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(_cal(eventDays: {_d(15)})));
    expect(find.bySemanticsLabel('15 tháng 10, rảnh, có sự kiện'), findsOneWidget);
    h.dispose();
  });

  testWidgets('the legend names the four states', (tester) async {
    await tester.pumpWidget(hostWidget(const AvailabilityLegend()));
    for (final t in ['Rảnh', 'Đã đặt', 'Chờ nhận', 'Nghỉ']) {
      expect(find.text(t), findsOneWidget);
    }
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text, cells stay 44dp tall (${b.name})', (tester) async {
      final h = tester.ensureSemantics();
      await tester.pumpWidget(
        hostWidget(
          Column(children: [_cal(editable: true, onSelect: (_) {}), const AvailabilityLegend()]),
          brightness: b,
          width: 320,
          textScale: 1.3,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.bySemanticsLabel('13 tháng 10, rảnh')).height, greaterThanOrEqualTo(44));
      h.dispose();
    });
  }
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/availability_calendar_test.dart`
Expected: FAIL, `AvailabilityCalendar` and `DayState` undefined.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb`, then run `flutter gen-l10n`:

```json
  "calendarMonthTitle": "Tháng {month}, {year}",
  "@calendarMonthTitle": {"placeholders": {"month": {"type": "String"}, "year": {"type": "String"}}},
  "calendarMonthShort": "Tháng {month}",
  "@calendarMonthShort": {"placeholders": {"month": {"type": "String"}}},
  "calendarPrevMonth": "Tháng trước",
  "calendarNextMonth": "Tháng sau",
  "calendarWeekdayShort": "{weekday, select, mon{T2} tue{T3} wed{T4} thu{T5} fri{T6} sat{T7} other{CN}}",
  "@calendarWeekdayShort": {"placeholders": {"weekday": {"type": "String"}}},
  "calendarWeekdayLong": "{weekday, select, mon{Thứ 2} tue{Thứ 3} wed{Thứ 4} thu{Thứ 5} fri{Thứ 6} sat{Thứ 7} other{Chủ nhật}}",
  "@calendarWeekdayLong": {"placeholders": {"weekday": {"type": "String"}}},
  "calendarDayTitle": "{weekday}, {day}/{month}",
  "@calendarDayTitle": {"placeholders": {"weekday": {"type": "String"}, "day": {"type": "String"}, "month": {"type": "String"}}},
  "dayStateFree": "Rảnh",
  "dayStatePending": "Chờ nhận",
  "dayStateBooked": "Đã đặt",
  "dayStateOff": "Nghỉ",
  "calendarDaySemantics": "{day} tháng {month}, {state}",
  "@calendarDaySemantics": {"placeholders": {"day": {"type": "String"}, "month": {"type": "String"}, "state": {"type": "String"}}},
  "calendarHasEvent": "có sự kiện",
  "calendarToday": "hôm nay",
```

```dart
// lib/core/widgets/availability_calendar.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:photobooking/core/calendar_days.dart';
import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// State of one day on a photographer's calendar. A day with no stored
/// record is [free]; `off` is set by the photographer, `pending` and `booked`
/// only by the server (bookings and events).
enum DayState { free, pending, booked, off }

extension DayStateLabel on DayState {
  String label(AppLocalizations l) => switch (this) {
    DayState.free => l.dayStateFree,
    DayState.pending => l.dayStatePending,
    DayState.booked => l.dayStateBooked,
    DayState.off => l.dayStateOff,
  };
}

/// `mon` … `sun`, the keys of the weekday select messages in the ARB file.
String weekdayCode(int weekday) =>
    const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'][weekday - 1];

Color _secondary(ThemeData t) => t.brightness == Brightness.dark
    ? AppColorsDark.foregroundSecondary
    : AppColors.foregroundSecondary;

/// Month grid, Monday first, with the four day states (spec §4): free,
/// pending (dashed primary ring), booked (struck through), off (muted fill).
/// The selected day is filled with the theme gradient.
///
/// Used read-only on S03, for picking a day on S06 (`editable: false`: only
/// free days answer), and for marking days off on S20 (`editable: true`:
/// every day in bounds answers and the screen decides). Times are not part
/// of the grid. All dates are calendar days (UTC midnight, see
/// `calendar_days.dart`).
class AvailabilityCalendar extends StatelessWidget {
  const AvailabilityCalendar({
    super.key,
    required this.month,
    required this.states,
    this.selected,
    this.onSelect,
    this.onLongPress,
    this.editable = false,
    this.onMonthChanged,
    this.minDate,
    this.maxDate,
    this.today,
    this.eventDays = const {},
    this.rangeStart,
    this.showHeader = true,
  });

  /// Any day of the month to show.
  final DateTime month;

  /// Non-free days; missing days are free.
  final Map<DateTime, DayState> states;
  final DateTime? selected;
  final ValueChanged<DateTime>? onSelect;

  /// Starts a range on S20 (the alternative to dragging: press and hold the
  /// first day, then tap the last).
  final ValueChanged<DateTime>? onLongPress;
  final bool editable;
  final ValueChanged<DateTime>? onMonthChanged;
  final DateTime? minDate;
  final DateTime? maxDate;
  final DateTime? today;

  /// Days with an event of the photographer: a dot under the number.
  final Set<DateTime> eventDays;
  final DateTime? rangeStart;
  final bool showHeader;

  static const cellHeight = 44.0;

  bool _inBounds(DateTime d) =>
      (minDate == null || !d.isBefore(calendarDay(minDate!))) &&
      (maxDate == null || !d.isAfter(calendarDay(maxDate!)));

  bool _canPrev(DateTime m) =>
      minDate == null || !addMonths(m, -1).isBefore(monthOf(minDate!));

  bool _canNext(DateTime m) =>
      maxDate == null || !addMonths(m, 1).isAfter(monthOf(maxDate!));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final m = monthOf(month);
    final days = monthGrid(m);
    final sel = selected == null ? null : calendarDay(selected!);
    final now = today == null ? null : calendarDay(today!);
    final range = rangeStart == null ? null : calendarDay(rangeStart!);

    VoidCallback? answer(ValueChanged<DateTime>? cb, DateTime d, DayState s) {
      if (cb == null || d.month != m.month || !_inBounds(d)) {
        return null;
      }
      if (!editable && s != DayState.free) {
        return null;
      }
      return () => cb(d);
    }

    final weekdays = Row(
      children: [
        for (var i = DateTime.monday; i <= DateTime.sunday; i++)
          Expanded(
            child: Center(
              child: Text(
                l.calendarWeekdayShort(weekdayCode(i)),
                style: theme.textTheme.labelSmall?.copyWith(color: _secondary(theme)),
              ),
            ),
          ),
      ],
    );

    Widget grid = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var w = 0; w < 6; w++)
          Row(
            children: [
              for (final d in days.sublist(w * 7, w * 7 + 7))
                Expanded(
                  child: _DayCell(
                    day: d,
                    state: states[d] ?? DayState.free,
                    inMonth: d.month == m.month,
                    inBounds: _inBounds(d),
                    selected: d == sel,
                    today: d == now,
                    hasEvent: eventDays.contains(d),
                    rangeStart: d == range,
                    onTap: answer(onSelect, d, states[d] ?? DayState.free),
                    onLongPress: answer(onLongPress, d, states[d] ?? DayState.free),
                  ),
                ),
            ],
          ),
      ],
    );
    final change = onMonthChanged;
    if (change != null) {
      grid = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (e) {
          final v = e.primaryVelocity ?? 0;
          if (v < -150 && _canNext(m)) {
            change(addMonths(m, 1));
          } else if (v > 150 && _canPrev(m)) {
            change(addMonths(m, -1));
          }
        },
        child: grid,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Row(
            children: [
              IconButton(
                tooltip: l.calendarPrevMonth,
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: change != null && _canPrev(m) ? () => change(addMonths(m, -1)) : null,
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l.calendarMonthTitle('${m.month}', '${m.year}'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(fontFamily: AppFonts.display),
                  ),
                ),
              ),
              IconButton(
                tooltip: l.calendarNextMonth,
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: change != null && _canNext(m) ? () => change(addMonths(m, 1)) : null,
              ),
            ],
          ),
        weekdays,
        const SizedBox(height: AppSpace.s1),
        grid,
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.state,
    required this.inMonth,
    required this.inBounds,
    required this.selected,
    required this.today,
    required this.hasEvent,
    required this.rangeStart,
    required this.onTap,
    required this.onLongPress,
  });

  final DateTime day;
  final DayState state;
  final bool inMonth;
  final bool inBounds;
  final bool selected;
  final bool today;
  final bool hasEvent;
  final bool rangeStart;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = _secondary(theme);
    var fg = scheme.onSurface;
    BoxDecoration? fill;
    TextDecoration? line;
    switch (state) {
      case DayState.free || DayState.pending:
        break;
      case DayState.off:
        fill = BoxDecoration(color: scheme.onSurface.withValues(alpha: 0.12), shape: BoxShape.circle);
        fg = muted;
      case DayState.booked:
        line = TextDecoration.lineThrough;
        fg = muted;
    }
    if (selected) {
      fill = BoxDecoration(gradient: ctaGradientFor(theme.brightness), shape: BoxShape.circle);
      fg = Colors.white;
    }
    Widget disc = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: fill,
      child: Text(
        '${day.day}',
        style: TextStyle(
          fontSize: AppText.base,
          fontWeight: today ? FontWeight.w700 : FontWeight.w500,
          color: fg,
          decoration: line,
          decorationColor: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    if (state == DayState.pending && !selected) {
      disc = CustomPaint(foregroundPainter: _DashedRing(scheme.primary), child: disc);
    }
    final ring = rangeStart
        ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.primary, width: 2))
        : today && !selected
        ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: muted))
        : null;
    Widget cell = SizedBox(
      height: AvailabilityCalendar.cellHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (ring != null) Container(width: 40, height: 40, decoration: ring),
          disc,
          if (hasEvent)
            Positioned(
              bottom: 2,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
    if (!inMonth) {
      return ExcludeSemantics(child: Opacity(opacity: 0.3, child: cell));
    }
    if (!inBounds) {
      cell = Opacity(opacity: 0.45, child: cell);
    }
    final said = [
      state.label(l).toLowerCase(),
      if (hasEvent) l.calendarHasEvent,
      if (today) l.calendarToday,
    ].join(', ');
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      selected: selected,
      label: l.calendarDaySemantics('${day.day}', '${day.month}', said),
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        onLongPress: onLongPress,
        radius: AvailabilityCalendar.cellHeight / 2,
        child: cell,
      ),
    );
  }
}

class _DashedRing extends CustomPainter {
  const _DashedRing(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) / 2 - 1,
    );
    const dashes = 12;
    const sweep = math.pi * 2 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRing old) => old.color != color;
}

class _StrikePainter extends CustomPainter {
  const _StrikePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.85),
      Offset(size.width * 0.85, size.height * 0.15),
      Paint()
        ..color = color
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_StrikePainter old) => old.color != color;
}

/// The four day states with their names; meaning never rests on the swatch.
class AvailabilityLegend extends StatelessWidget {
  const AvailabilityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = _secondary(theme);
    Widget swatch(DayState s) {
      const size = 14.0;
      return switch (s) {
        DayState.free => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: muted)),
        ),
        DayState.pending => CustomPaint(
          size: const Size.square(size),
          painter: _DashedRing(scheme.primary),
        ),
        DayState.booked => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: muted)),
          child: CustomPaint(painter: _StrikePainter(muted)),
        ),
        DayState.off => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
      };
    }

    return Wrap(
      spacing: AppSpace.s4,
      runSpacing: AppSpace.s2,
      children: [
        for (final s in DayState.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              swatch(s),
              const SizedBox(width: AppSpace.s2),
              Text(s.label(l), style: theme.textTheme.bodySmall),
            ],
          ),
      ],
    );
  }
}
```

Export from `lib/core/core.dart`: `export 'package:photobooking/core/widgets/availability_calendar.dart';`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/availability_calendar_test.dart && flutter analyze`
Expected: PASS, 9 tests; analyze clean. If the fling test does not reach `onHorizontalDragEnd` because an `InkResponse` claims the gesture, keep `HitTestBehavior.translucent` and check the fling distance is larger than the touch slop (300 is); do not remove the tap targets.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core lib/l10n test/core/widgets/availability_calendar_test.dart
git commit -m "feat(core): AvailabilityCalendar with four day states and legend

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 3: Availability days: model, port, fake, Firestore adapter, providers

**Files:**
- Create: `lib/data/photographer/availability_repository.dart`, `lib/data/photographer/firestore_availability_repository.dart`, `lib/data/photographer/availability_providers.dart`, `test/data/photographer/availability_repository_test.dart`

**Interfaces:**
- Consumes: `DayState` (Task 2), `calendarDay`, `monthOf`, `lastDayOfMonth`, `vnToday` (Task 1), `vnDateKey`, `parseDayKey` (3a1), `authRepositoryProvider`.
- Produces:
  - `class AvailabilityDay { const AvailabilityDay({required DateTime day, required DayState state, String? bookingId, String? eventId}); }` with value equality.
  - `AvailabilityDay? availabilityDayFromFirestore(String id, Map<String, dynamic> d)` — null when the id is not a real `yyyy-MM-dd` date; `off`/`pending`/`booked` map to their state, anything else (or no `state`) counts as `booked` (same rule as plan 3b3's `AvailabilityLookup`); `Map<String, dynamic> offDayToFirestore()` → `{'state': 'off'}`.
  - `abstract class AvailabilityRepository { Stream<Map<DateTime, AvailabilityDay>> watchRange(String uid, {required DateTime from, required DateTime to}); Future<void> markOff(String uid, Iterable<DateTime> days); Future<void> clearOff(String uid, Iterable<DateTime> days); }` — `watchRange` emits the non-free days in `[from, to]` (inclusive) now and after every change; `markOff` skips days that already have a record; `clearOff` removes only `off` records.
  - `FakeAvailabilityRepository({bool failWrites = false})` with `seed(String uid, AvailabilityDay day)`, `Map<DateTime, AvailabilityDay> stored(String uid)`, `int watchers` (open `watchRange` subscriptions), `int writes`.
  - `FirestoreAvailabilityRepository({FirebaseFirestore? db})` on `availability/{uid}/days/{yyyy-MM-dd}` (ordered by document id, so no index is needed).
  - `availabilityRepositoryProvider` (`Provider<AvailabilityRepository>`), `typedef AvailabilityMonth = ({String uid, DateTime month})`, `availabilityMonthProvider` (`StreamProvider.autoDispose.family<Map<DateTime, AvailabilityDay>, AvailabilityMonth>`), `calendarTodayProvider` (`Provider<DateTime>`, `vnToday(DateTime.now().toUtc())`; tests override it).

- [ ] **Step 1: Write the failing test**

```dart
// test/data/photographer/availability_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';

DateTime _d(int day) => DateTime.utc(2026, 10, day);

void main() {
  group('mapping', () {
    test('documents become days; unknown or missing states count as booked', () {
      expect(
        availabilityDayFromFirestore('2026-10-12', {'state': 'off'}),
        AvailabilityDay(day: _d(12), state: DayState.off),
      );
      final pending = availabilityDayFromFirestore('2026-10-13', {'state': 'pending', 'bookingId': 'b1'})!;
      expect((pending.state, pending.bookingId), (DayState.pending, 'b1'));
      expect(availabilityDayFromFirestore('2026-10-15', {'state': 'booked', 'eventId': 'e1'})!.eventId, 'e1');
      expect(availabilityDayFromFirestore('2026-10-14', {'state': 'weird'})!.state, DayState.booked);
      expect(availabilityDayFromFirestore('2026-10-14', {})!.state, DayState.booked);
      expect(availabilityDayFromFirestore('2026-13-01', {'state': 'off'}), isNull);
      expect(availabilityDayFromFirestore('x', {'state': 'off'}), isNull);
    });

    test('the client writes nothing but the off state', () {
      expect(offDayToFirestore(), {'state': 'off'});
    });
  });

  group('FakeAvailabilityRepository', () {
    test('watchRange emits the slice now and after each change', () async {
      final repo = FakeAvailabilityRepository()
        ..seed('p1', AvailabilityDay(day: _d(10), state: DayState.booked, bookingId: 'b1'))
        ..seed('p1', AvailabilityDay(day: DateTime.utc(2026, 11, 2), state: DayState.off));
      final seen = <Map<DateTime, AvailabilityDay>>[];
      final sub = repo.watchRange('p1', from: _d(1), to: _d(31)).listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      expect(seen.single.keys, [_d(10)]);
      await repo.markOff('p1', [_d(12)]);
      await Future<void>.delayed(Duration.zero);
      expect(seen.last.keys.toSet(), {_d(10), _d(12)});
      await sub.cancel();
    });

    test('markOff never overwrites a booked day; clearOff keeps it too', () async {
      final repo = FakeAvailabilityRepository()
        ..seed('p1', AvailabilityDay(day: _d(10), state: DayState.booked));
      await repo.markOff('p1', [_d(10), _d(11)]);
      expect(repo.stored('p1')[_d(10)]!.state, DayState.booked);
      expect(repo.stored('p1')[_d(11)]!.state, DayState.off);
      await repo.clearOff('p1', [_d(10), _d(11)]);
      expect(repo.stored('p1').keys, [_d(10)]);
    });

    test('days are normalised to calendar days and users stay separate', () async {
      final repo = FakeAvailabilityRepository();
      await repo.markOff('p1', [DateTime.utc(2026, 10, 12, 9, 30)]);
      expect(repo.stored('p1').keys, [_d(12)]);
      expect(repo.stored('p2'), isEmpty);
    });

    test('counts open listeners and fails writes on request', () async {
      final repo = FakeAvailabilityRepository(failWrites: true);
      final sub = repo.watchRange('p1', from: _d(1), to: _d(31)).listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(repo.watchers, 1);
      await expectLater(repo.markOff('p1', [_d(3)]), throwsStateError);
      expect(repo.stored('p1'), isEmpty);
      await sub.cancel();
      expect(repo.watchers, 0);
    });
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/photographer/availability_repository_test.dart`
Expected: FAIL, `availability_repository.dart` not found.

- [ ] **Step 3: Implement**

```dart
// lib/data/photographer/availability_repository.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';

/// One non-free day of a photographer (`AvailabilityDay` in the data model).
/// [day] is a calendar day (UTC midnight). `booked` and `pending` carry the
/// booking or event that took the day; only the server writes them.
@immutable
class AvailabilityDay {
  const AvailabilityDay({required this.day, required this.state, this.bookingId, this.eventId});

  final DateTime day;
  final DayState state;
  final String? bookingId;
  final String? eventId;

  @override
  bool operator ==(Object other) =>
      other is AvailabilityDay &&
      other.day == day &&
      other.state == state &&
      other.bookingId == bookingId &&
      other.eventId == eventId;

  @override
  int get hashCode => Object.hash(day, state, bookingId, eventId);
}

/// `availability/{uid}/days/{yyyy-MM-dd}` → [AvailabilityDay]. A document
/// whose state the app does not know blocks the day (counted as booked).
AvailabilityDay? availabilityDayFromFirestore(String id, Map<String, dynamic> d) {
  final day = parseDayKey(id);
  if (day == null) {
    return null;
  }
  final state = switch (d['state']) {
    'off' => DayState.off,
    'pending' => DayState.pending,
    _ => DayState.booked,
  };
  final booking = d['bookingId'];
  final event = d['eventId'];
  return AvailabilityDay(
    day: day,
    state: state,
    bookingId: booking is String ? booking : null,
    eventId: event is String ? event : null,
  );
}

/// The only fields a photographer writes on a day (plus the server time).
Map<String, dynamic> offDayToFirestore() => {'state': 'off'};

abstract class AvailabilityRepository {
  /// Non-free days of [uid] from [from] to [to] (calendar days, inclusive):
  /// now, and again after every change.
  Stream<Map<DateTime, AvailabilityDay>> watchRange(
    String uid, {
    required DateTime from,
    required DateTime to,
  });

  /// Marks [days] off. Days that already have a record are left alone.
  Future<void> markOff(String uid, Iterable<DateTime> days);

  /// Frees [days] that are off; booked and pending days stay.
  Future<void> clearOff(String uid, Iterable<DateTime> days);
}

class FakeAvailabilityRepository implements AvailabilityRepository {
  FakeAvailabilityRepository({this.failWrites = false});

  bool failWrites;

  /// Open [watchRange] subscriptions, so tests can prove screens stop listening.
  int watchers = 0;
  int writes = 0;

  final _days = <String, Map<DateTime, AvailabilityDay>>{};
  final _changes = StreamController<String>.broadcast();

  void seed(String uid, AvailabilityDay day) {
    (_days[uid] ??= {})[calendarDay(day.day)] = day;
    _changes.add(uid);
  }

  Map<DateTime, AvailabilityDay> stored(String uid) => Map.unmodifiable(_days[uid] ?? const {});

  Map<DateTime, AvailabilityDay> _slice(String uid, DateTime from, DateTime to) => {
    for (final e in (_days[uid] ?? const <DateTime, AvailabilityDay>{}).entries)
      if (!e.key.isBefore(calendarDay(from)) && !e.key.isAfter(calendarDay(to))) e.key: e.value,
  };

  @override
  Stream<Map<DateTime, AvailabilityDay>> watchRange(
    String uid, {
    required DateTime from,
    required DateTime to,
  }) {
    late final StreamController<Map<DateTime, AvailabilityDay>> out;
    StreamSubscription<String>? inner;
    out = StreamController<Map<DateTime, AvailabilityDay>>(
      onListen: () {
        watchers++;
        out.add(_slice(uid, from, to));
        inner = _changes.stream
            .where((u) => u == uid)
            .listen((_) => out.add(_slice(uid, from, to)));
      },
      onCancel: () async {
        watchers--;
        await inner?.cancel();
      },
    );
    return out.stream;
  }

  void _check() {
    if (failWrites) {
      throw StateError('unavailable');
    }
    writes++;
  }

  @override
  Future<void> markOff(String uid, Iterable<DateTime> days) async {
    _check();
    final map = _days[uid] ??= {};
    for (final raw in days) {
      final d = calendarDay(raw);
      map.putIfAbsent(d, () => AvailabilityDay(day: d, state: DayState.off));
    }
    _changes.add(uid);
  }

  @override
  Future<void> clearOff(String uid, Iterable<DateTime> days) async {
    _check();
    final map = _days[uid] ??= {};
    for (final raw in days) {
      final d = calendarDay(raw);
      if (map[d]?.state == DayState.off) {
        map.remove(d);
      }
    }
    _changes.add(uid);
  }
}
```

```dart
// lib/data/photographer/firestore_availability_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';

/// `availability/{uid}/days/{yyyy-MM-dd}`; no document means free.
class FirestoreAvailabilityRepository implements AvailabilityRepository {
  FirestoreAvailabilityRepository({FirebaseFirestore? db}) : _override = db;

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _days(String uid) =>
      _db.collection('availability').doc(uid).collection('days');

  @override
  Stream<Map<DateTime, AvailabilityDay>> watchRange(
    String uid, {
    required DateTime from,
    required DateTime to,
  }) => _days(uid)
      // Day keys sort like dates, so a document-id range is a date range.
      .orderBy(FieldPath.documentId)
      .startAt([vnDateKey(calendarDay(from))])
      .endAt([vnDateKey(calendarDay(to))])
      .snapshots()
      .map(
        (s) => {
          for (final doc in s.docs)
            if (availabilityDayFromFirestore(doc.id, doc.data()) case final d?) d.day: d,
        },
      );

  @override
  Future<void> markOff(String uid, Iterable<DateTime> days) async {
    final batch = _db.batch();
    for (final d in days) {
      batch.set(_days(uid).doc(vnDateKey(calendarDay(d))), {
        ...offDayToFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> clearOff(String uid, Iterable<DateTime> days) async {
    final batch = _db.batch();
    for (final d in days) {
      batch.delete(_days(uid).doc(vnDateKey(calendarDay(d))));
    }
    await batch.commit();
  }
}
```

The caller passes only days it saw as free (`markOff`) or off (`clearOff`); a day the server took in between makes the rules refuse the whole batch, which the S20 controller reports as a failed save.

```dart
// lib/data/photographer/availability_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/firestore_availability_repository.dart';

final availabilityRepositoryProvider = Provider<AvailabilityRepository>(
  (ref) => FirestoreAvailabilityRepository(),
);

/// Whose calendar and which month (any day of it).
typedef AvailabilityMonth = ({String uid, DateTime month});

/// The non-free days of one photographer's month. Listens only while a
/// screen shows that month (S20, S03 "Lịch", later S06).
final availabilityMonthProvider = StreamProvider.autoDispose
    .family<Map<DateTime, AvailabilityDay>, AvailabilityMonth>((ref, key) {
      final m = monthOf(key.month);
      return ref
          .watch(availabilityRepositoryProvider)
          .watchRange(key.uid, from: m, to: lastDayOfMonth(m));
    });

/// Today on the Vietnamese calendar; tests override it.
final calendarTodayProvider = Provider<DateTime>(
  (ref) => vnToday(DateTime.now().toUtc()),
);
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/photographer/availability_repository_test.dart && flutter analyze`
Expected: PASS, 6 tests; analyze clean.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/data/photographer test/data/photographer
git commit -m "feat(data): availability days port, fake and Firestore adapter

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Photographer intro and service packages: models, ports, fakes, adapters, providers

**Files:**
- Create: `lib/data/photographer/photographer_intro.dart`, `lib/data/photographer/firestore_photographer_intro_repository.dart`, `lib/data/photographer/service_package.dart`, `lib/data/photographer/firestore_service_package_repository.dart`, `lib/data/photographer/photographer_setup_providers.dart`, `test/data/photographer/photographer_intro_test.dart`, `test/data/photographer/service_package_test.dart`

**Interfaces:**
- Consumes: `newUlid` (Task 1), `authRepositoryProvider`.
- Produces (`photographer_intro.dart`):
  - `class PhotographerIntro { const PhotographerIntro({String bio = '', List<String> equipment = const [], bool onboardingComplete = false}); }` with value equality. Years of experience are not here: they live in `photographers/{uid}.skills.yearsExperience` (plan 2c's `PhotographerSkills`), the single source of truth.
  - `PhotographerIntro introFromFirestore(Map<String, dynamic> d)` (missing or wrongly typed fields fall back to the defaults); `Map<String, dynamic> introToFirestore({required String bio, required List<String> equipment})` → `{bio, equipment}`.
  - `abstract class PhotographerIntroRepository { Stream<PhotographerIntro?> watch(String uid); Future<PhotographerIntro?> get(String uid); Future<void> save(String uid, {required String bio, required List<String> equipment}); }` — `save` never touches `onboardingComplete` or `skills`.
  - `FakePhotographerIntroRepository({bool failSave = false})` with `seed`, `stored`, `watchers`, `saves`; `FirestorePhotographerIntroRepository({FirebaseFirestore? db})` on `photographers/{uid}`.
- Produces (`service_package.dart`):
  - `const kPackageDurationsMinutes = [60, 120, 180, 240, 360, 480]` (spec S24: 1, 2, 3, 4, 6, 8 giờ).
  - `class ServicePackageInput { const ServicePackageInput({required String name, required int priceVnd, required int durationMinutes, int? editedCount, int? deliveryDays}); }`; `class ServicePackage { const ServicePackage({required String id, required String name, required int priceVnd, required int durationMinutes, int? editedCount, int? deliveryDays, bool active = true}); ServicePackageInput get input; ServicePackage copyWith({bool? active}); }`; both with value equality.
  - `Map<String, dynamic> packageToFirestore(ServicePackageInput p)` → `{name, price, durationMinutes, deliverables: {editedCount?, deliveryDays?}}` — the exact shape plan 3b1's `serviceFromFirestore` reads; `ServicePackage? packageFromFirestore(String id, Map<String, dynamic> d)` (null when `name`, `price > 0` or `durationMinutes` is missing).
  - `abstract class ServicePackageRepository { Stream<List<ServicePackage>> watchMine(String uid); Future<ServicePackage> add(String uid, ServicePackageInput input); Future<void> update(String uid, String id, ServicePackageInput input); Future<void> hide(String uid, String id); }` — `watchMine` lists active and hidden packages, oldest first (ULID order).
  - `FakeServicePackageRepository({bool failWrites = false})` with `seed(String uid, ServicePackage p)`, `List<ServicePackage> stored(String uid)`, `watchers`, `writes`; `FirestoreServicePackageRepository({FirebaseFirestore? db})` on `photographers/{uid}/services/{ulid}` (adds `active: true`, `createdAt`, `updatedAt`).
- Produces (`photographer_setup_providers.dart`): `photographerIntroRepositoryProvider`, `servicePackageRepositoryProvider`, `myIntroProvider` (`StreamProvider.autoDispose<PhotographerIntro?>`, the signed-in user's own intro), `myPackagesProvider` (`StreamProvider.autoDispose<List<ServicePackage>>`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/photographer/photographer_intro_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';

void main() {
  test('reads what is there and falls back for the rest', () {
    expect(
      introFromFirestore({
        'bio': 'Ánh sáng tự nhiên.',
        'equipment': ['Sony A7 IV', 3, 'Godox V1'],
        'onboardingComplete': true,
        'verified': true,
        'skills': {'yearsExperience': 6},
      }),
      const PhotographerIntro(
        bio: 'Ánh sáng tự nhiên.',
        equipment: ['Sony A7 IV', 'Godox V1'],
        onboardingComplete: true,
      ),
    );
    expect(introFromFirestore({'bio': 12, 'equipment': 'Sony'}), const PhotographerIntro());
  });

  test('writes only the two intro fields', () {
    expect(introToFirestore(bio: 'B', equipment: const ['X']), {
      'bio': 'B',
      'equipment': ['X'],
    });
  });

  test('the fake keeps the onboarding flag, streams changes and counts listeners', () async {
    final repo = FakePhotographerIntroRepository()
      ..seed('p1', const PhotographerIntro(onboardingComplete: true, bio: 'Cũ'));
    final seen = <PhotographerIntro?>[];
    final sub = repo.watch('p1').listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    expect(repo.watchers, 1);
    await repo.save('p1', bio: 'Mới', equipment: const ['Sony']);
    await Future<void>.delayed(Duration.zero);
    expect(
      seen.last,
      const PhotographerIntro(bio: 'Mới', equipment: ['Sony'], onboardingComplete: true),
    );
    expect(await repo.get('p2'), isNull);
    await sub.cancel();
    expect(repo.watchers, 0);
  });

  test('a failing save throws and stores nothing', () async {
    final repo = FakePhotographerIntroRepository(failSave: true);
    await expectLater(repo.save('p1', bio: 'x', equipment: const []), throwsStateError);
    expect(repo.stored('p1'), isNull);
  });
}
```

```dart
// test/data/photographer/service_package_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/service_package.dart';

const _input = ServicePackageInput(
  name: 'Chân dung 2 giờ',
  priceVnd: 1500000,
  durationMinutes: 120,
  editedCount: 40,
  deliveryDays: 3,
);

void main() {
  test('writes the document shape the discovery read model expects', () {
    expect(packageToFirestore(_input), {
      'name': 'Chân dung 2 giờ',
      'price': 1500000,
      'durationMinutes': 120,
      'deliverables': {'editedCount': 40, 'deliveryDays': 3},
    });
    expect(
      packageToFirestore(const ServicePackageInput(name: 'A b', priceVnd: 1, durationMinutes: 60)),
      {'name': 'A b', 'price': 1, 'durationMinutes': 60, 'deliverables': <String, dynamic>{}},
    );
  });

  test('reads packages back, hidden ones included; broken ones are dropped', () {
    expect(
      packageFromFirestore('s1', {...packageToFirestore(_input), 'active': false}),
      const ServicePackage(
        id: 's1',
        name: 'Chân dung 2 giờ',
        priceVnd: 1500000,
        durationMinutes: 120,
        editedCount: 40,
        deliveryDays: 3,
        active: false,
      ),
    );
    expect(packageFromFirestore('s2', {'name': 'X', 'price': 0, 'durationMinutes': 60}), isNull);
    expect(packageFromFirestore('s3', {'name': 'X', 'price': 1.5, 'durationMinutes': 60}), isNull);
    expect(packageFromFirestore('s4', {'price': 100, 'durationMinutes': 60}), isNull);
    expect(packageFromFirestore('s5', {'name': 'X', 'price': 100})!.durationMinutes, 60,
        reason: 'old documents without a duration default to one hour');
  });

  test('the fake adds, updates and hides in creation order', () async {
    final repo = FakeServicePackageRepository();
    final lists = <List<ServicePackage>>[];
    final sub = repo.watchMine('p1').listen(lists.add);
    final a = await repo.add('p1', _input);
    final b = await repo.add('p1', const ServicePackageInput(name: 'Cặp đôi', priceVnd: 3200000, durationMinutes: 240));
    await repo.update('p1', a.id, const ServicePackageInput(name: 'Chân dung', priceVnd: 1800000, durationMinutes: 120));
    await repo.hide('p1', b.id);
    await Future<void>.delayed(Duration.zero);
    expect(lists.last.map((p) => (p.name, p.priceVnd, p.active)), [
      ('Chân dung', 1800000, true),
      ('Cặp đôi', 3200000, false),
    ]);
    expect(repo.watchers, 1);
    await sub.cancel();
    expect(repo.watchers, 0);
    expect(repo.stored('p2'), isEmpty);
  });

  test('failing writes throw and change nothing', () async {
    final repo = FakeServicePackageRepository(failWrites: true);
    await expectLater(repo.add('p1', _input), throwsStateError);
    expect(repo.stored('p1'), isEmpty);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/photographer/photographer_intro_test.dart test/data/photographer/service_package_test.dart`
Expected: FAIL, files not found.

- [ ] **Step 3: Implement**

```dart
// lib/data/photographer/photographer_intro.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

/// Step 1 of profile setup (S24): what a customer reads first. Lives on the
/// public `photographers/{uid}` document; no contact data here.
@immutable
class PhotographerIntro {
  const PhotographerIntro({
    this.bio = '',
    this.equipment = const [],
    this.onboardingComplete = false,
  });

  final String bio;
  final List<String> equipment;

  /// Set by setup step 4/4 (plan 2b); read here, never written.
  final bool onboardingComplete;

  @override
  bool operator ==(Object other) =>
      other is PhotographerIntro &&
      other.bio == bio &&
      listEquals(other.equipment, equipment) &&
      other.onboardingComplete == onboardingComplete;

  @override
  int get hashCode => Object.hash(bio, Object.hashAll(equipment), onboardingComplete);
}

PhotographerIntro introFromFirestore(Map<String, dynamic> d) {
  final bio = d['bio'];
  final equipment = d['equipment'];
  return PhotographerIntro(
    bio: bio is String ? bio : '',
    equipment: [
      if (equipment is List)
        for (final e in equipment)
          if (e is String) e,
    ],
    onboardingComplete: d['onboardingComplete'] == true,
  );
}

Map<String, dynamic> introToFirestore({required String bio, required List<String> equipment}) => {
  'bio': bio,
  'equipment': equipment,
};

abstract class PhotographerIntroRepository {
  /// The intro of [uid] now and after every change; null without a
  /// photographer document.
  Stream<PhotographerIntro?> watch(String uid);

  Future<PhotographerIntro?> get(String uid);

  /// Writes bio and equipment; nothing else on the document changes.
  Future<void> save(String uid, {required String bio, required List<String> equipment});
}

class FakePhotographerIntroRepository implements PhotographerIntroRepository {
  FakePhotographerIntroRepository({this.failSave = false});

  bool failSave;
  int watchers = 0;
  int saves = 0;
  final _intros = <String, PhotographerIntro>{};
  final _changes = StreamController<String>.broadcast();

  void seed(String uid, PhotographerIntro intro) {
    _intros[uid] = intro;
    _changes.add(uid);
  }

  PhotographerIntro? stored(String uid) => _intros[uid];

  @override
  Stream<PhotographerIntro?> watch(String uid) {
    late final StreamController<PhotographerIntro?> out;
    StreamSubscription<String>? inner;
    out = StreamController<PhotographerIntro?>(
      onListen: () {
        watchers++;
        out.add(_intros[uid]);
        inner = _changes.stream.where((u) => u == uid).listen((_) => out.add(_intros[uid]));
      },
      onCancel: () async {
        watchers--;
        await inner?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<PhotographerIntro?> get(String uid) async => _intros[uid];

  @override
  Future<void> save(String uid, {required String bio, required List<String> equipment}) async {
    if (failSave) {
      throw StateError('unavailable');
    }
    saves++;
    final old = _intros[uid] ?? const PhotographerIntro();
    _intros[uid] = PhotographerIntro(
      bio: bio,
      equipment: List.unmodifiable(equipment),
      onboardingComplete: old.onboardingComplete,
    );
    _changes.add(uid);
  }
}
```

```dart
// lib/data/photographer/firestore_photographer_intro_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/photographer/photographer_intro.dart';

class FirestorePhotographerIntroRepository implements PhotographerIntroRepository {
  FirestorePhotographerIntroRepository({FirebaseFirestore? db}) : _override = db;

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('photographers').doc(uid);

  @override
  Stream<PhotographerIntro?> watch(String uid) => _doc(uid).snapshots().map(
    (s) => s.data() == null ? null : introFromFirestore(s.data()!),
  );

  @override
  Future<PhotographerIntro?> get(String uid) async {
    final s = await _doc(uid).get();
    return s.data() == null ? null : introFromFirestore(s.data()!);
  }

  @override
  Future<void> save(String uid, {required String bio, required List<String> equipment}) =>
      _doc(uid).set({
        ...introToFirestore(bio: bio, equipment: equipment),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
}
```

```dart
// lib/data/photographer/service_package.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

/// Durations a package can have (spec S24: 1, 2, 3, 4, 6 or 8 hours).
const kPackageDurationsMinutes = [60, 120, 180, 240, 360, 480];

/// What the photographer types for a package. Money is whole VND.
@immutable
class ServicePackageInput {
  const ServicePackageInput({
    required this.name,
    required this.priceVnd,
    required this.durationMinutes,
    this.editedCount,
    this.deliveryDays,
  });

  final String name;
  final int priceVnd;
  final int durationMinutes;
  final int? editedCount;
  final int? deliveryDays;

  @override
  bool operator ==(Object other) =>
      other is ServicePackageInput &&
      other.name == name &&
      other.priceVnd == priceVnd &&
      other.durationMinutes == durationMinutes &&
      other.editedCount == editedCount &&
      other.deliveryDays == deliveryDays;

  @override
  int get hashCode => Object.hash(name, priceVnd, durationMinutes, editedCount, deliveryDays);
}

/// One of the photographer's own packages (`Service` in the data model),
/// as the owner edits it. Customers read the same documents through plan
/// 3b1's `ServiceSummary`.
@immutable
class ServicePackage {
  const ServicePackage({
    required this.id,
    required this.name,
    required this.priceVnd,
    required this.durationMinutes,
    this.editedCount,
    this.deliveryDays,
    this.active = true,
  });

  final String id;
  final String name;
  final int priceVnd;
  final int durationMinutes;
  final int? editedCount;
  final int? deliveryDays;

  /// Hidden packages stay in Firestore so posts and bookings keep a valid
  /// `serviceId`; customers never see them.
  final bool active;

  ServicePackageInput get input => ServicePackageInput(
    name: name,
    priceVnd: priceVnd,
    durationMinutes: durationMinutes,
    editedCount: editedCount,
    deliveryDays: deliveryDays,
  );

  ServicePackage copyWith({bool? active}) => ServicePackage(
    id: id,
    name: name,
    priceVnd: priceVnd,
    durationMinutes: durationMinutes,
    editedCount: editedCount,
    deliveryDays: deliveryDays,
    active: active ?? this.active,
  );

  static ServicePackage from(String id, ServicePackageInput i, {bool active = true}) =>
      ServicePackage(
        id: id,
        name: i.name,
        priceVnd: i.priceVnd,
        durationMinutes: i.durationMinutes,
        editedCount: i.editedCount,
        deliveryDays: i.deliveryDays,
        active: active,
      );

  @override
  bool operator ==(Object other) =>
      other is ServicePackage && other.id == id && other.active == active && other.input == input;

  @override
  int get hashCode => Object.hash(id, active, input);
}

/// `photographers/{uid}/services/{id}` fields written by the client.
Map<String, dynamic> packageToFirestore(ServicePackageInput p) => {
  'name': p.name,
  'price': p.priceVnd,
  'durationMinutes': p.durationMinutes,
  'deliverables': {'editedCount': ?p.editedCount, 'deliveryDays': ?p.deliveryDays},
};

ServicePackage? packageFromFirestore(String id, Map<String, dynamic> d) {
  final name = d['name'];
  final price = d['price'];
  final duration = d['durationMinutes'];
  if (name is! String || price is! int || price <= 0) {
    return null;
  }
  final raw = d['deliverables'];
  final del = raw is Map ? raw : const {};
  final edited = del['editedCount'];
  final days = del['deliveryDays'];
  return ServicePackage(
    id: id,
    name: name,
    priceVnd: price,
    durationMinutes: duration is int ? duration : 60,
    editedCount: edited is int ? edited : null,
    deliveryDays: days is int ? days : null,
    active: d['active'] != false,
  );
}

abstract class ServicePackageRepository {
  /// The photographer's packages, active and hidden, oldest first; live.
  Stream<List<ServicePackage>> watchMine(String uid);

  Future<ServicePackage> add(String uid, ServicePackageInput input);
  Future<void> update(String uid, String id, ServicePackageInput input);

  /// Sets `active: false`; packages are never deleted from the client.
  Future<void> hide(String uid, String id);
}

class FakeServicePackageRepository implements ServicePackageRepository {
  FakeServicePackageRepository({this.failWrites = false});

  bool failWrites;
  int watchers = 0;
  int writes = 0;
  int _seq = 0;
  final _packages = <String, List<ServicePackage>>{};
  final _changes = StreamController<String>.broadcast();

  void seed(String uid, ServicePackage p) {
    (_packages[uid] ??= []).add(p);
    _changes.add(uid);
  }

  List<ServicePackage> stored(String uid) => List.unmodifiable(_packages[uid] ?? const []);

  @override
  Stream<List<ServicePackage>> watchMine(String uid) {
    late final StreamController<List<ServicePackage>> out;
    StreamSubscription<String>? inner;
    out = StreamController<List<ServicePackage>>(
      onListen: () {
        watchers++;
        out.add(stored(uid));
        inner = _changes.stream.where((u) => u == uid).listen((_) => out.add(stored(uid)));
      },
      onCancel: () async {
        watchers--;
        await inner?.cancel();
      },
    );
    return out.stream;
  }

  void _check() {
    if (failWrites) {
      throw StateError('unavailable');
    }
    writes++;
  }

  void _replace(String uid, String id, ServicePackage Function(ServicePackage) change) {
    final list = _packages[uid] ?? [];
    final i = list.indexWhere((p) => p.id == id);
    if (i < 0) {
      throw StateError('no package $id');
    }
    list[i] = change(list[i]);
    _changes.add(uid);
  }

  @override
  Future<ServicePackage> add(String uid, ServicePackageInput input) async {
    _check();
    final p = ServicePackage.from('pkg-${++_seq}', input);
    seed(uid, p);
    return p;
  }

  @override
  Future<void> update(String uid, String id, ServicePackageInput input) async {
    _check();
    _replace(uid, id, (old) => ServicePackage.from(id, input, active: old.active));
  }

  @override
  Future<void> hide(String uid, String id) async {
    _check();
    _replace(uid, id, (old) => old.copyWith(active: false));
  }
}
```

```dart
// lib/data/photographer/firestore_service_package_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/service_package.dart';

class FirestoreServicePackageRepository implements ServicePackageRepository {
  FirestoreServicePackageRepository({FirebaseFirestore? db}) : _override = db;

  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('photographers').doc(uid).collection('services');

  @override
  Stream<List<ServicePackage>> watchMine(String uid) => _col(uid)
      // ULID ids sort by creation time.
      .orderBy(FieldPath.documentId)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            if (packageFromFirestore(d.id, d.data()) case final p?) p,
        ],
      );

  @override
  Future<ServicePackage> add(String uid, ServicePackageInput input) async {
    final id = newUlid();
    await _col(uid).doc(id).set({
      ...packageToFirestore(input),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ServicePackage.from(id, input);
  }

  @override
  Future<void> update(String uid, String id, ServicePackageInput input) =>
      _col(uid).doc(id).update({
        ...packageToFirestore(input),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> hide(String uid, String id) => _col(uid).doc(id).update({
    'active': false,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
```

```dart
// lib/data/photographer/photographer_setup_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/firestore_photographer_intro_repository.dart';
import 'package:photobooking/data/photographer/firestore_service_package_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/service_package.dart';

final photographerIntroRepositoryProvider = Provider<PhotographerIntroRepository>(
  (ref) => FirestorePhotographerIntroRepository(),
);

final servicePackageRepositoryProvider = Provider<ServicePackageRepository>(
  (ref) => FirestoreServicePackageRepository(),
);

/// The signed-in photographer's own intro (S30 setup card). Own-profile
/// data, the one kind of listener allowed to live as long as the tab shell.
final myIntroProvider = StreamProvider.autoDispose<PhotographerIntro?>((ref) {
  final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
  if (uid == null) {
    return Stream.value(null);
  }
  return ref.watch(photographerIntroRepositoryProvider).watch(uid);
});

/// The signed-in photographer's packages, while S24 step 2 is open.
final myPackagesProvider = StreamProvider.autoDispose<List<ServicePackage>>((ref) {
  final uid = ref.watch(authRepositoryProvider).currentUser?.uid;
  if (uid == null) {
    return Stream.value(const []);
  }
  return ref.watch(servicePackageRepositoryProvider).watchMine(uid);
});
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/photographer && flutter analyze`
Expected: PASS (intro 4, packages 4, availability 6); analyze clean. `'key': ?value` in `packageToFirestore` is a null-aware map entry (Dart 3.8+, the SDK constraint is `^3.13`; the codebase already uses null-aware elements such as `?child` in `AuroraBackground`).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/data/photographer test/data/photographer
git commit -m "feat(data): photographer intro and service package repositories

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Firestore rules for days off, the intro and packages

**Files:**
- Modify: `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs`

**Interfaces:**
- Produces:
  - `availability/{uid}/days/{day}`: read by any signed-in user (plan 3b3 expects exactly this); created only by `uid` with the photographer role, with `day` a `yyyy-MM-dd` id, keys only `state`/`updatedAt` and `state == 'off'`; never updated by a client; deleted only by `uid` when the stored state is `off`.
  - `photographers/{uid}`: `validIntro()` — `bio` string ≤ 300, `equipment` list ≤ 8 (added to the existing create/update conditions; `skills`, including `skills.yearsExperience`, stays under plan 2c's rules).
  - `photographers/{uid}/services/{serviceId}`: create/update only by `uid` with the photographer role and `validService()` — keys only `name, specialty, price, durationMinutes, deliverables, coverUrl, active, createdAt, updatedAt`; `name` 2–60 characters; `price` int `1..1 000 000 000`; `durationMinutes` in `[60, 120, 180, 240, 360, 480]`; `deliverables` keys `photoCount, editedCount, deliveryDays`, ints `0..2000`, `0..2000`, `0..90`; `active` bool. Delete refused.

- [ ] **Step 1: Write the failing tests**

In `firebase/rules-test/rules.test.mjs` extend the `firebase/firestore` import to `import { doc, setDoc, getDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp } from 'firebase/firestore';` (keep any names other plans already added), then append:

```js
// ---- Plan 2d1: days off, intro, packages ----
const dayPath = (uid, day) => `availability/${uid}/days/${day}`;
const asCustomer = (uid) => env.withSecurityRulesDisabled(async (c) =>
  setDoc(doc(c.firestore(), `users/${uid}`), { displayName: uid, role: 'customer' }));

test('a photographer marks a free day off and frees it again', async () => {
  await asPhotographer('cal1');
  const db = env.authenticatedContext('cal1').firestore();
  const r = doc(db, dayPath('cal1', '2026-10-12'));
  await assertSucceeds(setDoc(r, { state: 'off', updatedAt: serverTimestamp() }));
  await assertSucceeds(getDoc(r));
  await assertSucceeds(deleteDoc(r));
});

test('booked and pending days belong to the server', async () => {
  await asPhotographer('cal2');
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), dayPath('cal2', '2026-10-13')), { state: 'booked', bookingId: 'b1' }));
  const db = env.authenticatedContext('cal2').firestore();
  await assertFails(setDoc(doc(db, dayPath('cal2', '2026-10-14')), { state: 'booked' }));
  await assertFails(setDoc(doc(db, dayPath('cal2', '2026-10-14')), { state: 'pending' }));
  await assertFails(deleteDoc(doc(db, dayPath('cal2', '2026-10-13'))));
  await assertFails(setDoc(doc(db, dayPath('cal2', '2026-10-13')), { state: 'off' }), 'an overwrite is an update');
  await assertFails(setDoc(doc(db, dayPath('cal2', '2026-10-15')), { state: 'off', bookingId: 'x' }));
  await assertFails(setDoc(doc(db, dayPath('cal2', '12-10-2026')), { state: 'off' }));
});

test('only the photographer edits their calendar; every signed-in user reads it', async () => {
  await asPhotographer('cal3');
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), dayPath('cal3', '2026-10-16')), { state: 'off' }));
  const other = env.authenticatedContext('cal4').firestore();
  await assertSucceeds(getDoc(doc(other, dayPath('cal3', '2026-10-16'))));
  await assertFails(setDoc(doc(other, dayPath('cal3', '2026-10-17')), { state: 'off' }));
  await assertFails(deleteDoc(doc(other, dayPath('cal3', '2026-10-16'))));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), dayPath('cal3', '2026-10-16'))));
  await asCustomer('cal5');
  await assertFails(setDoc(doc(env.authenticatedContext('cal5').firestore(), dayPath('cal5', '2026-10-18')), { state: 'off' }));
});

const svcPath = (uid, id) => `photographers/${uid}/services/${id}`;
const svc = (o = {}) => ({
  name: 'Chân dung 2 giờ', price: 1500000, durationMinutes: 120,
  deliverables: { editedCount: 40, deliveryDays: 3 }, active: true, ...o,
});

test('a photographer adds, edits and hides own packages, and never deletes them', async () => {
  await asPhotographer('sv1');
  const db = env.authenticatedContext('sv1').firestore();
  const r = doc(db, svcPath('sv1', '01JB0Z8K3V5N6Q7R8S9T0V1W2X'));
  await assertSucceeds(setDoc(r, { ...svc(), createdAt: serverTimestamp(), updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(r, { price: 1800000, updatedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(r, { active: false }));
  await assertFails(deleteDoc(r));
});

test('package values are checked', async () => {
  await asPhotographer('sv2');
  const r = doc(env.authenticatedContext('sv2').firestore(), svcPath('sv2', 's1'));
  for (const bad of [
    svc({ price: 0 }), svc({ price: 1500.5 }), svc({ price: '1500000' }), svc({ price: 1000000001 }),
    svc({ durationMinutes: 90 }), svc({ name: 'A' }), svc({ name: 'x'.repeat(61) }),
    svc({ deliverables: { editedCount: -1 } }), svc({ deliverables: { deliveryDays: 91 } }),
    svc({ deliverables: { extra: 1 } }), svc({ active: 'yes' }), svc({ note: 'x' }), svc({ startingPrice: 1 }),
  ]) {
    await assertFails(setDoc(r, bad));
  }
  await assertSucceeds(setDoc(r, svc({ deliverables: {} })));
});

test('nobody else, and no customer, writes packages; everyone signed in reads them', async () => {
  await asPhotographer('sv3');
  await assertFails(setDoc(doc(env.authenticatedContext('sv4').firestore(), svcPath('sv3', 's1')), svc()));
  await asCustomer('sv5');
  await assertFails(setDoc(doc(env.authenticatedContext('sv5').firestore(), svcPath('sv5', 's1')), svc()));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('sv4').firestore(), svcPath('sv3', 's1'))));
});

test('the step 1 intro is length-checked', async () => {
  await asPhotographer('in1');
  const db = env.authenticatedContext('in1').firestore();
  await assertSucceeds(setDoc(doc(db, 'photographers/in1'), { onboardingComplete: false, verified: false, specialties: [] }));
  await assertSucceeds(updateDoc(doc(db, 'photographers/in1'), {
    bio: 'Ánh sáng tự nhiên.', equipment: ['Sony A7 IV'], updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db, 'photographers/in1'), { bio: 'x'.repeat(301) }));
  await assertFails(updateDoc(doc(db, 'photographers/in1'), { bio: 42 }));
  await assertFails(updateDoc(doc(db, 'photographers/in1'), { equipment: Array.from({ length: 9 }, (_, i) => `M${i}`) }));
  await assertFails(updateDoc(doc(db, 'photographers/in1'), { equipment: 'Sony' }));
});
```

- [ ] **Step 2: Run and see it fail**

Run (from `firebase/rules-test`; needs Node, Java and the emulator): `npm ci && npm test`
Expected: the new tests FAIL (no rule matches `availability/…`, so the first test fails at its first write; the bad packages succeed because `services` only checks the owner). If the emulator cannot run in this sandbox, say so in the report and rely on the CI job "Firestore rules tests (emulator)".

- [ ] **Step 3: Implement**

In `firebase/firestore.rules`, add next to the other functions:

```
    // photographers/{uid} fields of setup step 1 (S24).
    function validIntro() {
      let d = request.resource.data;
      return (!('bio' in d) || (d.bio is string && d.bio.size() <= 300))
        && (!('equipment' in d) || (d.equipment is list && d.equipment.size() <= 8));
    }

    // photographers/{uid}/services/{id}: whole VND above zero, a duration from
    // the fixed list, no server fields. Packages are hidden (active: false),
    // never deleted, so posts and bookings keep a valid serviceId.
    function validService() {
      let d = request.resource.data;
      let del = d.get('deliverables', {});
      return d.keys().hasOnly(['name', 'specialty', 'price', 'durationMinutes', 'deliverables',
                               'coverUrl', 'active', 'createdAt', 'updatedAt'])
        && d.name is string && d.name.size() >= 2 && d.name.size() <= 60
        && d.price is int && d.price > 0 && d.price <= 1000000000
        && d.durationMinutes in [60, 120, 180, 240, 360, 480]
        && d.get('active', true) is bool
        && del is map
        && del.keys().hasOnly(['photoCount', 'editedCount', 'deliveryDays'])
        && del.get('photoCount', 0) is int && del.get('photoCount', 0) >= 0 && del.get('photoCount', 0) <= 2000
        && del.get('editedCount', 0) is int && del.get('editedCount', 0) >= 0 && del.get('editedCount', 0) <= 2000
        && del.get('deliveryDays', 0) is int && del.get('deliveryDays', 0) >= 0 && del.get('deliveryDays', 0) <= 90;
    }
```

In the `match /photographers/{uid}` block (as plans 2b and 2c left it) append `&& validIntro()` to the `allow create, update` condition, keeping every existing condition (2b's `validServiceArea()` / `validContactChannels(uid)`, 2c's `skills` check) untouched, and replace only the `services` sub-block with:

```
      match /services/{serviceId} {
        allow read: if signedIn();
        allow create, update: if isOwner(uid) && hasPhotographerRole(uid) && validService();
        allow delete: if false;
      }
```

Leave 2b's `private/{docId}` sub-block as it is.

Above the final catch-all `match /{document=**}` add (plan 3b3 runs later and only checks that this block lets every signed-in user read):

```
    // availability/{uid}/days/{yyyy-MM-dd}; no document means free. The
    // photographer only marks free days off and frees them again; booked and
    // pending days come from bookings and events (server only).
    match /availability/{uid}/days/{day} {
      allow read: if signedIn();
      allow create: if isOwner(uid)
        && hasPhotographerRole(uid)
        && day.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
        && request.resource.data.keys().hasOnly(['state', 'updatedAt'])
        && request.resource.data.state == 'off';
      allow update: if false;
      allow delete: if isOwner(uid) && resource.data.state == 'off';
    }
```

- [ ] **Step 4: Run and see it pass**

Run (from `firebase/rules-test`): `npm test`
Expected: all rules tests pass, old and new. If `let del = d.get('deliverables', {})` is rejected, inline `d.get('deliverables', {})` in each condition; if the emulator says `day` is shadowed, rename the wildcard to `{dayKey}` and use `dayKey.matches(...)`. Fix the rule, never the test.

- [ ] **Step 5: Commit**

```bash
git add firebase/firestore.rules firebase/rules-test/rules.test.mjs
git commit -m "feat(rules): days off, intro limits and package validation

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 6: S24 step 1 "Giới thiệu", draft store, `/setup` routes

**Files:**
- Create: `lib/features/photographer_setup/setup_draft_store.dart`, `lib/features/photographer_setup/intro_logic.dart`, `lib/features/photographer_setup/setup_intro_controller.dart`, `lib/features/photographer_setup/setup_intro_screen.dart`, `test/support/photographer_world.dart`, `test/features/photographer_setup/setup_draft_store_test.dart`, `test/features/photographer_setup/intro_logic_test.dart`, `test/features/photographer_setup/setup_intro_screen_test.dart`
- Modify: `lib/app/router.dart`, `test/app/router_test.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `photographerIntroRepositoryProvider`, `FakePhotographerIntroRepository`, `PhotographerIntro` (Task 4); `servicePackageRepositoryProvider`, `FakeServicePackageRepository`; `availabilityRepositoryProvider`, `FakeAvailabilityRepository`, `calendarTodayProvider` (Task 3); `userRepositoryProvider.setDisplayName`, `currentProfileProvider`, `authRepositoryProvider`; `sharedPreferencesProvider` (`lib/features/settings/theme_mode_controller.dart`); `StepProgress`, `GlassCard`, `AppButton`, `ScreenCode`, `ScreenCodes.setupProfile`; `validateName`'s message `l.errorNameEmpty`; `AppTab.home.path`.
- Produces:
  - `class IntroDraft { const IntroDraft({String displayName = '', String bio = '', List<String> equipment = const []}); }`, `class PackageDraft { const PackageDraft({String name = '', String price = '', int? durationMinutes, String edited = '', String delivery = ''}); bool get isEmpty; }` (both with `toJson`/`fromJson` and value equality).
  - `class SetupDraftStore { SetupDraftStore(SharedPreferences prefs); IntroDraft? intro(String uid); Future<void> saveIntro(String uid, IntroDraft d); Future<void> clearIntro(String uid); PackageDraft? package(String uid); Future<void> savePackage(String uid, PackageDraft d); Future<void> clearPackage(String uid); int step(String uid); Future<void> setStep(String uid, int step); }` (keys `setup.intro.<uid>`, `setup.package.<uid>`, `setup.step.<uid>`), `setupDraftStoreProvider`, `String setupResumePath(int step)` (`/setup/1` … `/setup/4`).
  - `intro_logic.dart`: `kBioMaxLength = 300`, `kEquipmentMax = 8`, `kEquipmentItemMax = 40`; `enum IntroField { name, bio }`, `enum IntroError { nameRequired, bioRequired, bioTooLong }`; `class IntroInput`, `class IntroResult` (`errors`, `displayName`, `bio`, `equipment`, `ok`); `List<String> cleanEquipment(Iterable<String> raw)`; `IntroResult validateIntro(IntroInput input)`; `String introErrorText(IntroError e, AppLocalizations l)`.
  - `setupIntroControllerProvider` (`AsyncNotifierProvider.autoDispose<SetupIntroController, bool>`), `.save(IntroResult r)`: display name to `users/{uid}`, intro to `photographers/{uid}`, clears the intro draft, saved step becomes at least 2; value true once saved.
  - `SetupIntroScreen` at `/setup/1`; `/setup` redirects to `setupResumePath(store.step(uid))`; `String? photographerOnlyRedirect(UserRole? role)` in `router.dart` (null for photographers, `/home` otherwise) guards `/setup`, `/setup/1`, `/setup/2`, `/work/calendar`.
  - Widget keys: `setup-name`, `setup-bio`, `setup-equipment-field`, `setup-equipment-add`, `equipment-<name>`, `setup-next`.
  - Test support: `PhotographerWorld` (fakes, `overrides`, `app({required String location, required List<RouteBase> routes, …})`, `router`, `today`) and `void usePhone(WidgetTester tester, {double width = 390, double height = 800})`.
  - l10n: `setupTitle` "Hồ sơ nhiếp ảnh gia", `setupStepIntro` "Giới thiệu", `setupIntroHeading` "Giới thiệu bản thân", `setupIntroHint` "Khách đọc phần này trước khi đặt lịch. Viết ngắn, nói rõ bạn chụp kiểu gì.", `setupBioLabel` "Giới thiệu ngắn", `setupBioHint` "Ánh sáng tự nhiên, ít dàn dựng. Chuyên chân dung ngoài trời ở Sài Gòn.", `setupEquipmentLabel` "Thiết bị (không bắt buộc)", `setupEquipmentHint` "Ví dụ: Sony A7 IV", `setupEquipmentAdd` "Thêm thiết bị", `setupEquipmentRemove(item)` "Xoá {item}", `setupEquipmentFull` "Tối đa 8 thiết bị.", `setupNext` "Tiếp tục", `setupBack` "Quay lại", `setupSaveError` "Không lưu được. Kiểm tra mạng rồi thử lại.", `introBioRequired` "Viết vài dòng giới thiệu", `introBioTooLong` "Tối đa 300 ký tự".

Specialties and years of experience are **not** asked here: setup step 3/4 (S38/S39, plan 2c) collects them into `photographers/{uid}.skills` (`specialties` with levels and evidence, `yearsExperience`), the single source of truth. Writing years from step 1 through `SkillsRepository` is not possible either: 2c's rules accept a `skills` map only with 1–6 genres, which do not exist before step 3. Avatar and cover photo are added to this step by plan 2d2 (avatar) and a later media plan (cover); see Self-Review.

- [ ] **Step 1: Write the failing tests**

```dart
// test/support/photographer_world.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Thursday 1 Oct 2026 on the Vietnamese calendar.
final worldToday = DateTime.utc(2026, 10, 1);

/// A signed-in photographer with in-memory repositories, for the screens of
/// plan 2d1.
class PhotographerWorld {
  PhotographerWorld({this.role = UserRole.photographer, this.prefsValues = const {}});

  final UserRole role;
  final Map<String, Object> prefsValues;
  final intro = FakePhotographerIntroRepository();
  final packages = FakeServicePackageRepository();
  final availability = FakeAvailabilityRepository();
  final users = FakeUserRepository();
  final auth = FakeAuthRepository();
  DateTime today = worldToday;
  late SharedPreferences prefs;
  late String uid;
  late GoRouter router;

  Future<void> init() async {
    SharedPreferences.setMockInitialValues(prefsValues);
    prefs = await SharedPreferences.getInstance();
    final u = await auth.registerWithEmail('tri@b.vn', 'password1', 'Minh Trí');
    await users.ensureProfile(u);
    await users.setRole(u.uid, role);
    uid = u.uid;
  }

  List<Override> get overrides => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    authRepositoryProvider.overrideWithValue(auth),
    userRepositoryProvider.overrideWithValue(users),
    photographerIntroRepositoryProvider.overrideWithValue(intro),
    servicePackageRepositoryProvider.overrideWithValue(packages),
    availabilityRepositoryProvider.overrideWithValue(availability),
    calendarTodayProvider.overrideWithValue(today),
  ];

  /// Destinations the screens of this plan link to, shown as their path.
  static const stubPaths = [
    '/home',
    '/setup/3',
    '/setup/4',
    '/settings/profile',
    '/b/:id',
    '/events/:id/manage',
  ];

  Widget app({
    required String location,
    required List<RouteBase> routes,
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
  }) {
    final taken = routes.whereType<GoRoute>().map((r) => r.path).toSet();
    router = GoRouter(
      initialLocation: location,
      routes: [
        ...routes,
        for (final p in stubPaths)
          if (!taken.contains(p)) GoRoute(path: p, builder: (_, s) => Text('stub ${s.uri}')),
      ],
    );
    return ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        theme: brightness == Brightness.dark ? buildDarkTheme() : buildLightTheme(),
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    );
  }
}

/// Sets the test window to a phone [width] logical pixels wide.
void usePhone(WidgetTester tester, {double width = 390, double height = 800}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
```

```dart
// test/features/photographer_setup/setup_draft_store_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('drafts and the step are kept per user and survive a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SetupDraftStore(prefs);
    const intro = IntroDraft(displayName: 'Minh Trí', bio: 'Ánh sáng', equipment: ['Sony']);
    const pkg = PackageDraft(name: 'Chân dung', price: '1.500.000', durationMinutes: 120);
    await store.saveIntro('u1', intro);
    await store.savePackage('u1', pkg);
    await store.setStep('u1', 2);
    final again = SetupDraftStore(prefs);
    expect(again.intro('u1'), intro);
    expect(again.package('u1'), pkg);
    expect(again.step('u1'), 2);
    expect(again.intro('u2'), isNull);
    expect(again.step('u2'), 1);
    await again.clearIntro('u1');
    await again.clearPackage('u1');
    expect(again.intro('u1'), isNull);
    expect(again.package('u1'), isNull);
  });

  test('a broken draft is ignored', () async {
    SharedPreferences.setMockInitialValues({'setup.intro.u1': '{not json'});
    final store = SetupDraftStore(await SharedPreferences.getInstance());
    expect(store.intro('u1'), isNull);
  });

  test('resume paths', () {
    expect(setupResumePath(1), '/setup/1');
    expect(setupResumePath(2), '/setup/2');
    expect(setupResumePath(3), '/setup/3');
    expect(setupResumePath(4), '/setup/4');
    expect(setupResumePath(9), '/setup/1');
    expect(const PackageDraft().isEmpty, isTrue);
    expect(const PackageDraft(durationMinutes: 60).isEmpty, isFalse);
  });
}
```

```dart
// test/features/photographer_setup/intro_logic_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/photographer_setup/intro_logic.dart';

IntroResult _v({String name = 'Minh Trí', String bio = 'Ánh sáng tự nhiên.', List<String> eq = const []}) =>
    validateIntro(IntroInput(displayName: name, bio: bio, equipment: eq));

void main() {
  test('a complete intro is trimmed and accepted', () {
    final r = _v(name: '  Minh Trí ', bio: ' Ánh sáng. ', eq: const [' Sony A7 IV ']);
    expect(r.ok, isTrue);
    expect((r.displayName, r.bio, r.equipment), ('Minh Trí', 'Ánh sáng.', ['Sony A7 IV']));
  });

  test('name and bio are required, bio at most 300 characters', () {
    expect(_v(name: ' ').errors, {IntroField.name: IntroError.nameRequired});
    expect(_v(bio: '').errors, {IntroField.bio: IntroError.bioRequired});
    expect(_v(bio: 'x' * 301).errors, {IntroField.bio: IntroError.bioTooLong});
    expect(_v(bio: 'x' * 300).ok, isTrue);
  });

  test('equipment is trimmed, de-duplicated, cut and capped', () {
    expect(cleanEquipment(['Sony A7', 'sony a7', '  ', 'Godox']), ['Sony A7', 'Godox']);
    expect(cleanEquipment(['x' * 41]).single, hasLength(40));
    expect(cleanEquipment([for (var i = 0; i < 10; i++) 'M$i']), hasLength(8));
  });
}
```

```dart
// test/features/photographer_setup/setup_intro_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';
import 'package:photobooking/features/photographer_setup/setup_intro_screen.dart';

import '../../support/photographer_world.dart';

final _routes = <RouteBase>[
  GoRoute(path: '/setup/1', builder: (_, _) => const SetupIntroScreen()),
  GoRoute(path: '/setup/2', builder: (_, _) => const Text('step 2')),
];

Future<PhotographerWorld> _world() async {
  final w = PhotographerWorld();
  await w.init();
  return w;
}

Finder _key(String k) => find.byKey(Key(k));

void main() {
  testWidgets('prefills the name and the saved intro, shows step 1 of 4', (tester) async {
    final w = await _world();
    w.intro.seed(w.uid, const PhotographerIntro(bio: 'Chân dung ngoài trời', equipment: ['Sony A7 IV']));
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('Minh Trí'), findsOneWidget);
    expect(find.text('Chân dung ngoài trời'), findsOneWidget);
    expect(_key('equipment-Sony A7 IV'), findsOneWidget);
  });

  testWidgets('says what is missing and saves nothing', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    await tester.enterText(_key('setup-name'), ' ');
    await tester.tap(_key('setup-next'));
    await tester.pumpAndSettle();
    expect(find.text('Viết vài dòng giới thiệu'), findsOneWidget);
    expect(find.text('Vui lòng nhập tên hiển thị.'), findsOneWidget);
    expect(w.intro.saves, 0);
    expect(find.text('step 2'), findsNothing);
  });

  testWidgets('saves name, intro and equipment, then opens step 2', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    await tester.enterText(_key('setup-name'), 'Minh Trí Studio');
    await tester.enterText(_key('setup-bio'), 'Ánh sáng tự nhiên, ít dàn dựng.');
    await tester.enterText(_key('setup-equipment-field'), 'Sony A7 IV');
    await tester.tap(_key('setup-equipment-add'));
    await tester.pump();
    await tester.tap(_key('setup-next'));
    await tester.pumpAndSettle();
    expect(
      w.intro.stored(w.uid),
      const PhotographerIntro(bio: 'Ánh sáng tự nhiên, ít dàn dựng.', equipment: ['Sony A7 IV']),
    );
    expect((await w.users.watch(w.uid).first)!.displayName, 'Minh Trí Studio');
    expect(SetupDraftStore(w.prefs).step(w.uid), 2);
    expect(SetupDraftStore(w.prefs).intro(w.uid), isNull, reason: 'the draft is cleared once saved');
    expect(find.text('step 2'), findsOneWidget);
  });

  testWidgets('typing is kept as a draft and comes back after leaving', (tester) async {
    final w = await _world();
    w.intro.seed(w.uid, const PhotographerIntro(bio: 'Bản đã lưu'));
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    await tester.enterText(_key('setup-bio'), 'Nháp chưa lưu');
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    expect(find.text('Nháp chưa lưu'), findsOneWidget);
    expect(find.text('Bản đã lưu'), findsNothing);
  });

  testWidgets('equipment stops at eight and ignores duplicates', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    for (final name in ['Sony A7', 'sony a7', 'M1', 'M2', 'M3', 'M4', 'M5', 'M6', 'M7']) {
      await tester.enterText(_key('setup-equipment-field'), name);
      await tester.tap(_key('setup-equipment-add'));
      await tester.pump();
    }
    expect(find.byType(InputChip), findsNWidgets(8));
    expect(tester.widget<IconButton>(_key('setup-equipment-add')).onPressed, isNull);
    expect(find.text('Tối đa 8 thiết bị.'), findsOneWidget);
    await tester.tap(find.byTooltip('Xoá M7'));
    await tester.pump();
    expect(find.byType(InputChip), findsNWidgets(7));
  });

  testWidgets('a failed save keeps the form and says so', (tester) async {
    final w = await _world();
    w.intro.failSave = true;
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    await tester.enterText(_key('setup-bio'), 'Ánh sáng tự nhiên.');
    await tester.tap(_key('setup-next'));
    await tester.pumpAndSettle();
    expect(find.text('Không lưu được. Kiểm tra mạng rồi thử lại.'), findsOneWidget);
    expect(find.text('step 2'), findsNothing);
    expect(find.text('Ánh sáng tự nhiên.'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      usePhone(tester, width: 320, height: 640);
      final w = await _world();
      w.intro.seed(w.uid, PhotographerIntro(bio: 'x' * 300, equipment: const ['Sony A7 IV', 'Godox V1', 'Sigma 35mm f/1.4 Art']));
      await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes, brightness: b, textScale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
```

Append to `test/app/router_test.dart` inside `main()` (add `import 'package:photobooking/data/user/user_profile.dart';` if missing):

```dart
  test('photographer-only routes send everyone else home', () {
    expect(photographerOnlyRedirect(UserRole.photographer), isNull);
    expect(photographerOnlyRedirect(UserRole.customer), '/home');
    expect(photographerOnlyRedirect(null), '/home');
  });
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/photographer_setup test/app/router_test.dart`
Expected: FAIL to compile, `setup_draft_store.dart`, `intro_logic.dart`, `setup_intro_screen.dart` and `photographerOnlyRedirect` do not exist.

- [ ] **Step 3: Implement**

Add the strings of the Interfaces list to `lib/l10n/app_vi.arb` (with `"@setupEquipmentRemove": {"placeholders": {"item": {"type": "String"}}}`) and run `flutter gen-l10n`.

```dart
// lib/features/photographer_setup/setup_draft_store.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/features/settings/theme_mode_controller.dart';

String _s(Object? v) => v is String ? v : '';

/// Step 1 as typed, before "Tiếp tục" saves it.
@immutable
class IntroDraft {
  const IntroDraft({this.displayName = '', this.bio = '', this.equipment = const []});

  final String displayName;
  final String bio;
  final List<String> equipment;

  Map<String, Object> toJson() => {
    'displayName': displayName,
    'bio': bio,
    'equipment': equipment,
  };

  static IntroDraft? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final eq = raw['equipment'];
    return IntroDraft(
      displayName: _s(raw['displayName']),
      bio: _s(raw['bio']),
      equipment: [
        if (eq is List)
          for (final e in eq)
            if (e is String) e,
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is IntroDraft &&
      other.displayName == displayName &&
      other.bio == bio &&
      listEquals(other.equipment, equipment);

  @override
  int get hashCode => Object.hash(displayName, bio, Object.hashAll(equipment));
}

/// The package form of step 2 as typed, before "Thêm gói này".
@immutable
class PackageDraft {
  const PackageDraft({this.name = '', this.price = '', this.durationMinutes, this.edited = '', this.delivery = ''});

  final String name;
  final String price;
  final int? durationMinutes;
  final String edited;
  final String delivery;

  bool get isEmpty =>
      name.isEmpty && price.isEmpty && durationMinutes == null && edited.isEmpty && delivery.isEmpty;

  Map<String, Object?> toJson() => {
    'name': name,
    'price': price,
    'durationMinutes': durationMinutes,
    'edited': edited,
    'delivery': delivery,
  };

  static PackageDraft? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final d = raw['durationMinutes'];
    return PackageDraft(
      name: _s(raw['name']),
      price: _s(raw['price']),
      durationMinutes: d is int ? d : null,
      edited: _s(raw['edited']),
      delivery: _s(raw['delivery']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PackageDraft &&
      other.name == name &&
      other.price == price &&
      other.durationMinutes == durationMinutes &&
      other.edited == edited &&
      other.delivery == delivery;

  @override
  int get hashCode => Object.hash(name, price, durationMinutes, edited, delivery);
}

/// What the photographer typed in setup but has not saved yet, and the step
/// to come back to, kept on this device per user (spec S24 "lưu nháp mỗi
/// bước", "thoát và quay lại tiếp tục đúng bước"). Saved data is in
/// Firestore; this never holds anything the server needs.
class SetupDraftStore {
  SetupDraftStore(this._prefs);

  final SharedPreferences _prefs;

  String _key(String what, String uid) => 'setup.$what.$uid';

  Object? _read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) {
      return null;
    }
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  IntroDraft? intro(String uid) => IntroDraft.fromJson(_read(_key('intro', uid)));

  Future<void> saveIntro(String uid, IntroDraft d) =>
      _prefs.setString(_key('intro', uid), jsonEncode(d.toJson()));

  Future<void> clearIntro(String uid) => _prefs.remove(_key('intro', uid));

  PackageDraft? package(String uid) => PackageDraft.fromJson(_read(_key('package', uid)));

  Future<void> savePackage(String uid, PackageDraft d) =>
      _prefs.setString(_key('package', uid), jsonEncode(d.toJson()));

  Future<void> clearPackage(String uid) => _prefs.remove(_key('package', uid));

  int step(String uid) => _prefs.getInt(_key('step', uid)) ?? 1;

  Future<void> setStep(String uid, int step) => _prefs.setInt(_key('step', uid), step);
}

final setupDraftStoreProvider = Provider<SetupDraftStore>(
  (ref) => SetupDraftStore(ref.watch(sharedPreferencesProvider)),
);

/// Where `/setup` resumes. Steps 3 (S38, plan 2c) and 4 (S34, plan 2b) are
/// other plans' routes.
String setupResumePath(int step) => switch (step) {
  2 => '/setup/2',
  3 => '/setup/3',
  4 => '/setup/4',
  _ => '/setup/1',
};
```

```dart
// lib/features/photographer_setup/intro_logic.dart
import 'package:flutter/foundation.dart';

import 'package:photobooking/l10n/app_localizations.dart';

const kBioMaxLength = 300;
const kEquipmentMax = 8;
const kEquipmentItemMax = 40;

enum IntroField { name, bio }

enum IntroError { nameRequired, bioRequired, bioTooLong }

@immutable
class IntroInput {
  const IntroInput({required this.displayName, required this.bio, this.equipment = const []});

  final String displayName;
  final String bio;
  final List<String> equipment;
}

/// Cleaned values and the problems found; save only when [ok].
@immutable
class IntroResult {
  const IntroResult({
    required this.errors,
    required this.displayName,
    required this.bio,
    this.equipment = const [],
  });

  final Map<IntroField, IntroError> errors;
  final String displayName;
  final String bio;
  final List<String> equipment;

  bool get ok => errors.isEmpty;
}

/// Trims, drops empty and duplicate (ignoring case) names, cuts each to
/// [kEquipmentItemMax] characters and keeps the first [kEquipmentMax].
List<String> cleanEquipment(Iterable<String> raw) {
  final seen = <String>{};
  final out = <String>[];
  for (final e in raw) {
    var t = e.trim();
    if (t.isEmpty) {
      continue;
    }
    if (t.length > kEquipmentItemMax) {
      t = t.substring(0, kEquipmentItemMax).trim();
    }
    if (seen.add(t.toLowerCase())) {
      out.add(t);
    }
    if (out.length == kEquipmentMax) {
      break;
    }
  }
  return out;
}

IntroResult validateIntro(IntroInput input) {
  final errors = <IntroField, IntroError>{};
  final name = input.displayName.trim();
  final bio = input.bio.trim();
  if (name.isEmpty) {
    errors[IntroField.name] = IntroError.nameRequired;
  }
  if (bio.isEmpty) {
    errors[IntroField.bio] = IntroError.bioRequired;
  } else if (bio.length > kBioMaxLength) {
    errors[IntroField.bio] = IntroError.bioTooLong;
  }
  return IntroResult(
    errors: errors,
    displayName: name,
    bio: bio,
    equipment: cleanEquipment(input.equipment),
  );
}

String introErrorText(IntroError e, AppLocalizations l) => switch (e) {
  IntroError.nameRequired => l.errorNameEmpty,
  IntroError.bioRequired => l.introBioRequired,
  IntroError.bioTooLong => l.introBioTooLong,
};
```

```dart
// lib/features/photographer_setup/setup_intro_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/features/photographer_setup/intro_logic.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';

/// Saves setup step 1. Its value turns true once a save went through.
class SetupIntroController extends AsyncNotifier<bool> {
  @override
  bool build() => false;

  Future<void> save(IntroResult r) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null || !r.ok) {
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(userRepositoryProvider).setDisplayName(uid, r.displayName);
      await ref
          .read(photographerIntroRepositoryProvider)
          .save(uid, bio: r.bio, equipment: r.equipment);
      final drafts = ref.read(setupDraftStoreProvider);
      await drafts.clearIntro(uid);
      if (drafts.step(uid) < 2) {
        await drafts.setStep(uid, 2);
      }
      return true;
    });
  }
}

final setupIntroControllerProvider =
    AsyncNotifierProvider.autoDispose<SetupIntroController, bool>(SetupIntroController.new);
```

```dart
// lib/features/photographer_setup/setup_intro_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/features/photographer_setup/intro_logic.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';
import 'package:photobooking/features/photographer_setup/setup_intro_controller.dart';

/// S24, setup step 1/4: name, short bio, equipment (years and genres are
/// step 3, plan 2c).
/// Everything typed is kept as a device draft until "Tiếp tục" saves it.
class SetupIntroScreen extends ConsumerStatefulWidget {
  const SetupIntroScreen({super.key});

  @override
  ConsumerState<SetupIntroScreen> createState() => _SetupIntroScreenState();
}

class _SetupIntroScreenState extends ConsumerState<SetupIntroScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _equipmentField = TextEditingController();
  List<String> _equipment = const [];
  Map<IntroField, IntroError> _errors = const {};

  /// The person typed something: a late load must not overwrite it.
  bool _touched = false;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = ref.read(authRepositoryProvider).currentUser?.uid;
    final uid = _uid;
    final draft = uid == null ? null : ref.read(setupDraftStoreProvider).intro(uid);
    if (draft != null) {
      _apply(draft);
      _touched = true;
    } else {
      _prefill();
    }
  }

  Future<void> _prefill() async {
    final uid = _uid;
    if (uid == null) {
      return;
    }
    var name = '';
    PhotographerIntro? intro;
    try {
      name = (await ref.read(currentProfileProvider.future))?.displayName ?? '';
      intro = await ref.read(photographerIntroRepositoryProvider).get(uid);
    } catch (_) {
      // Offline or no document yet: start from what is known.
    }
    if (!mounted || _touched) {
      return;
    }
    setState(
      () => _apply(
        IntroDraft(
          displayName: name,
          bio: intro?.bio ?? '',
          equipment: intro?.equipment ?? const [],
        ),
      ),
    );
  }

  void _apply(IntroDraft d) {
    _name.text = d.displayName;
    _bio.text = d.bio;
    _equipment = [...d.equipment];
  }

  void _changed() {
    _touched = true;
    final uid = _uid;
    if (uid == null) {
      return;
    }
    ref
        .read(setupDraftStoreProvider)
        .saveIntro(
          uid,
          IntroDraft(displayName: _name.text, bio: _bio.text, equipment: _equipment),
        );
  }

  void _addEquipment() {
    final next = cleanEquipment([..._equipment, _equipmentField.text]);
    _equipmentField.clear();
    if (next.length == _equipment.length) {
      return;
    }
    setState(() => _equipment = next);
    _changed();
  }

  void _removeEquipment(String item) {
    setState(() => _equipment = [..._equipment]..remove(item));
    _changed();
  }

  void _next() {
    final r = validateIntro(
      IntroInput(displayName: _name.text, bio: _bio.text, equipment: _equipment),
    );
    setState(() => _errors = r.errors);
    if (r.ok) {
      ref.read(setupIntroControllerProvider.notifier).save(r);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _equipmentField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final saving = ref.watch(setupIntroControllerProvider).isLoading;
    ref.listen(setupIntroControllerProvider, (prev, next) {
      if (next.isLoading || !(prev?.isLoading ?? false)) {
        return;
      }
      if (next.hasError) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.setupSaveError)));
      } else if (next.value ?? false) {
        context.push('/setup/2');
      }
    });
    String? err(IntroField f) => _errors[f] == null ? null : introErrorText(_errors[f]!, l);
    final full = _equipment.length >= kEquipmentMax;

    return ScreenCode(
      ScreenCodes.setupProfile,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.setupTitle)),
          body: SafeArea(
            top: false,
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.s5),
              children: [
                StepProgress(current: 1, total: 4, label: l.setupStepIntro),
                const SizedBox(height: AppSpace.s4),
                GlassCard(
                  highlight: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(l.setupIntroHeading, style: theme.textTheme.titleLarge),
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Text(l.setupIntroHint, style: theme.textTheme.bodySmall),
                        const SizedBox(height: AppSpace.s4),
                        TextField(
                          key: const Key('setup-name'),
                          controller: _name,
                          enabled: !saving,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: l.displayNameLabel,
                            errorText: err(IntroField.name),
                          ),
                          onChanged: (_) => _changed(),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        TextField(
                          key: const Key('setup-bio'),
                          controller: _bio,
                          enabled: !saving,
                          minLines: 3,
                          maxLines: 6,
                          maxLength: kBioMaxLength,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: l.setupBioLabel,
                            hintText: l.setupBioHint,
                            alignLabelWithHint: true,
                            errorText: err(IntroField.bio),
                          ),
                          onChanged: (_) => _changed(),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        Text(l.setupEquipmentLabel, style: theme.textTheme.titleSmall),
                        const SizedBox(height: AppSpace.s2),
                        if (_equipment.isNotEmpty) ...[
                          Wrap(
                            spacing: AppSpace.s2,
                            runSpacing: AppSpace.s2,
                            children: [
                              for (final e in _equipment)
                                InputChip(
                                  key: Key('equipment-$e'),
                                  label: Text(e),
                                  deleteButtonTooltipMessage: l.setupEquipmentRemove(e),
                                  onDeleted: saving ? null : () => _removeEquipment(e),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.s2),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('setup-equipment-field'),
                                controller: _equipmentField,
                                enabled: !saving && !full,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(hintText: l.setupEquipmentHint),
                                onSubmitted: (_) => _addEquipment(),
                              ),
                            ),
                            const SizedBox(width: AppSpace.s2),
                            IconButton.filledTonal(
                              key: const Key('setup-equipment-add'),
                              tooltip: l.setupEquipmentAdd,
                              icon: const Icon(Icons.add_rounded),
                              onPressed: saving || full ? null : _addEquipment,
                            ),
                          ],
                        ),
                        if (full) ...[
                          const SizedBox(height: AppSpace.s1),
                          Text(l.setupEquipmentFull, style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(AppSpace.s5, AppSpace.s2, AppSpace.s5, AppSpace.s4),
            child: AppButton.primary(
              l.setupNext,
              key: const Key('setup-next'),
              loading: saving,
              onPressed: _next,
            ),
          ),
        ),
      ),
    );
  }
}
```

In `lib/app/router.dart`:

1. Add imports `package:photobooking/data/user/user_profile.dart`, `package:photobooking/features/photographer_setup/setup_draft_store.dart`, `package:photobooking/features/photographer_setup/setup_intro_screen.dart`.
2. Add, next to `computeRedirect`:

```dart
/// S20 and S24 are for photographers only (spec screens/README.md "Vai trò").
String? photographerOnlyRedirect(UserRole? role) =>
    role == UserRole.photographer ? null : AppTab.home.path;
```

3. Inside `routerProvider`, before `return GoRouter(`, add
`String? photographersOnly() => photographerOnlyRedirect(ref.read(currentProfileProvider).value?.role);`
and in the top-level `routes` list, before `StatefulShellRoute.indexedStack(`:

```dart
      GoRoute(
        path: '/setup',
        redirect: (_, _) {
          final away = photographersOnly();
          if (away != null) {
            return away;
          }
          final uid = ref.read(authRepositoryProvider).currentUser?.uid;
          return setupResumePath(uid == null ? 1 : ref.read(setupDraftStoreProvider).step(uid));
        },
      ),
      GoRoute(
        path: '/setup/1',
        redirect: (_, _) => photographersOnly(),
        builder: (_, _) => const SetupIntroScreen(),
      ),
```

(`/setup/3` is plan 2c's and `/setup/4` plan 2b's; they are separate literal routes, so no `/setup/:step` pattern is registered here.)

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/features/photographer_setup test/app && flutter analyze`
Expected: PASS (draft store 3, logic 3, screen 8, router +1); analyze clean. The name message is the existing `errorNameEmpty` string ("Vui lòng nhập tên hiển thị.").

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib test
git commit -m "feat(setup): S24 step 1 intro with device draft and /setup resume

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: S24 step 2 "Gói dịch vụ"

**Files:**
- Create: `lib/core/package_meta.dart`, `lib/features/photographer_setup/package_logic.dart`, `lib/features/photographer_setup/setup_packages_controller.dart`, `lib/features/photographer_setup/setup_packages_screen.dart`, `test/core/package_meta_test.dart`, `test/features/photographer_setup/package_logic_test.dart`, `test/features/photographer_setup/setup_packages_screen_test.dart`
- Modify: `lib/core/core.dart`, `lib/app/router.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `ServicePackage`, `ServicePackageInput`, `kPackageDurationsMinutes`, `myPackagesProvider`, `servicePackageRepositoryProvider` (Task 4); `SetupDraftStore`, `PackageDraft`, `setupDraftStoreProvider` (Task 6); `parseVnd`, `groupVnd`, `VndInputFormatter` (Task 1); `formatMoney`; `AppChip`, `AppChipKind`, `showAppSheet` (3a1); `StepProgress`, `GlassCard`, `AppButton`.
- Produces:
  - `String durationLabel(int minutes, AppLocalizations l)` → `2 giờ`, `1,5 giờ`; `String packageMeta(AppLocalizations l, {required int durationMinutes, int? editedCount, int? deliveryDays})` → `2 giờ · 40 ảnh · giao 3 ngày` (plan 2d2 uses it on S03).
  - `package_logic.dart`: `kPackageNameMin = 2`, `kPackageNameMax = 60`, `kPriceMaxVnd = 1000000000`, `kCountMax = 2000`, `kDeliveryMaxDays = 90`; `enum PackageField { name, price, duration, edited, delivery }`, `enum PackageError { nameLength, priceRequired, priceTooHigh, durationRequired, countInvalid, daysInvalid }`; `class PackageForm`; `class PackageCheck { Map<PackageField, PackageError> errors; ServicePackageInput? input; bool get ok; }`; `PackageCheck validatePackage(PackageForm f)`; `PackageForm packageFormOf(ServicePackage p)`; `String packageErrorText(PackageError e, AppLocalizations l)`.
  - `setupPackagesControllerProvider` (`AsyncNotifierProvider.autoDispose<SetupPackagesController, void>`) with `Future<bool> add(ServicePackageInput)`, `Future<bool> save(String id, ServicePackageInput)`, `Future<bool> hide(String id)` (true when it went through; add/save clear the package draft).
  - `SetupPackagesScreen` at `/setup/2` (photographers only). "Tiếp tục" is enabled with at least one active package, stores step 3 and pushes `/setup/3`; "Quay lại" pops, or goes to `/setup/1`.
  - Widget keys: `package-name`, `package-price`, `duration-<minutes>`, `package-edited`, `package-delivery`, `package-submit`, `package-cancel-edit`, `package-<id>`, `package-hide-<id>`, `package-hide-confirm`, `package-hide-keep`, `setup-back`, `setup-next`.
  - l10n: `setupStepServices` "Gói dịch vụ", `setupServicesHeading` "Gói dịch vụ", `setupServiceHint` "Khách đặt theo gói. Cần ít nhất một gói để hồ sơ hiện trong Tìm thợ ảnh.", `setupNoPackages` "Chưa có gói nào. Thêm gói đầu tiên bên dưới.", `setupNeedPackage` "Thêm ít nhất một gói để tiếp tục.", `setupPackagesLoadError` "Không tải được danh sách gói.", `packageNewHeading` "Thêm gói", `packageEditHeading` "Sửa gói", `packageNameLabel` "Tên gói", `packageNameHint` "Ví dụ: Chân dung 2 giờ", `packagePriceLabel` "Giá (₫)", `packageDurationLabel` "Thời lượng", `durationHours(hours)` "{hours} giờ", `packageEditedLabel` "Số ảnh hậu kỳ", `packageDeliveryLabel` "Giao sau (ngày)", `packagePhotos(count)` "{count} ảnh", `packageDelivery(days)` plural "giao trong ngày" / "giao {days} ngày", `packageAdd` "Thêm gói này", `packageSave` "Lưu gói", `packageCancelEdit` "Huỷ sửa", `packageHideTooltip(name)` "Ẩn gói {name}", `packageHideTitle` "Ẩn gói này?", `packageHideBody` "Khách sẽ không thấy và không đặt được gói này nữa. Bài đăng cũ vẫn giữ nguyên.", `packageHideConfirm` "Ẩn gói", `packageKeep` "Giữ lại", `packageAdded` "Đã thêm gói.", `packageSaved` "Đã lưu gói.", `packageHidden` "Đã ẩn gói.", `packageNameLength` "Nhập tên gói từ 2 đến 60 ký tự", `packagePriceRequired` "Nhập giá lớn hơn 0", `packagePriceTooHigh` "Giá tối đa 1.000.000.000₫", `packageDurationRequired` "Chọn thời lượng", `packageCountInvalid` "Nhập số từ 0 đến 2000", `packageDaysInvalid` "Nhập số ngày từ 0 đến 90".

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/package_meta_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

void main() {
  final l = AppLocalizationsVi();
  test('duration in hours, Vietnamese decimal comma', () {
    expect(durationLabel(120, l), '2 giờ');
    expect(durationLabel(90, l), '1,5 giờ');
  });
  test('package line joins only what is known', () {
    expect(packageMeta(l, durationMinutes: 120, editedCount: 40, deliveryDays: 3), '2 giờ · 40 ảnh · giao 3 ngày');
    expect(packageMeta(l, durationMinutes: 240), '4 giờ');
    expect(packageMeta(l, durationMinutes: 60, deliveryDays: 0), '1 giờ · giao trong ngày');
  });
}
```

```dart
// test/features/photographer_setup/package_logic_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/features/photographer_setup/package_logic.dart';

void main() {
  test('a complete form becomes an input with whole VND', () {
    final c = validatePackage(const PackageForm(name: ' Chân dung 2 giờ ', priceText: '1.500.000', durationMinutes: 120, editedText: '40', deliveryText: '3'));
    expect(c.ok, isTrue);
    expect(c.input, const ServicePackageInput(name: 'Chân dung 2 giờ', priceVnd: 1500000, durationMinutes: 120, editedCount: 40, deliveryDays: 3));
  });

  test('every rule has its own message', () {
    expect(validatePackage(const PackageForm()).errors, {
      PackageField.name: PackageError.nameLength,
      PackageField.price: PackageError.priceRequired,
      PackageField.duration: PackageError.durationRequired,
    });
    PackageCheck one(PackageForm f) => validatePackage(f);
    const ok = PackageForm(name: 'Gói', priceText: '1', durationMinutes: 60);
    expect(one(const PackageForm(name: 'G', priceText: '1', durationMinutes: 60)).errors.keys, [PackageField.name]);
    expect(one(PackageForm(name: 'x' * 61, priceText: '1', durationMinutes: 60)).errors.keys, [PackageField.name]);
    expect(one(const PackageForm(name: 'Gói', priceText: '0', durationMinutes: 60)).errors, {PackageField.price: PackageError.priceRequired});
    expect(one(const PackageForm(name: 'Gói', priceText: '1.000.000.001', durationMinutes: 60)).errors, {PackageField.price: PackageError.priceTooHigh});
    expect(one(const PackageForm(name: 'Gói', priceText: '1', durationMinutes: 90)).errors, {PackageField.duration: PackageError.durationRequired});
    expect(one(const PackageForm(name: 'Gói', priceText: '1', durationMinutes: 60, editedText: '2001')).errors, {PackageField.edited: PackageError.countInvalid});
    expect(one(const PackageForm(name: 'Gói', priceText: '1', durationMinutes: 60, deliveryText: '91')).errors, {PackageField.delivery: PackageError.daysInvalid});
    expect(one(ok).ok, isTrue);
  });

  test('editing starts from the stored values', () {
    final f = packageFormOf(const ServicePackage(id: 's1', name: 'Cặp đôi', priceVnd: 3200000, durationMinutes: 240, editedCount: 80));
    expect((f.name, f.priceText, f.durationMinutes, f.editedText, f.deliveryText), ('Cặp đôi', '3.200.000', 240, '80', ''));
  });
}
```

```dart
// test/features/photographer_setup/setup_packages_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';
import 'package:photobooking/features/photographer_setup/setup_packages_screen.dart';

import '../../support/photographer_world.dart';

final _routes = <RouteBase>[
  GoRoute(path: '/setup/1', builder: (_, _) => const Text('step 1')),
  GoRoute(path: '/setup/2', builder: (_, _) => const SetupPackagesScreen()),
];

const _portrait = ServicePackage(id: 'a', name: 'Chân dung 2 giờ', priceVnd: 1500000, durationMinutes: 120, editedCount: 40, deliveryDays: 3);

Future<PhotographerWorld> _world({List<ServicePackage> seed = const []}) async {
  final w = PhotographerWorld();
  await w.init();
  for (final p in seed) {
    w.packages.seed(w.uid, p);
  }
  return w;
}

Finder _key(String k) => find.byKey(Key(k));

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.descendant(of: _key(key), matching: find.byType(FilledButton))).onPressed != null;

Future<void> _fill(WidgetTester tester, {String name = 'Cặp đôi nửa ngày', String price = '3200000', int minutes = 240}) async {
  await tester.enterText(_key('package-name'), name);
  await tester.enterText(_key('package-price'), price);
  await tester.ensureVisible(_key('duration-$minutes'));
  await tester.tap(_key('duration-$minutes'));
  await tester.pump();
}

void main() {
  testWidgets('without a package, "Tiếp tục" waits and says why', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('Chưa có gói nào. Thêm gói đầu tiên bên dưới.'), findsOneWidget);
    expect(find.text('Thêm ít nhất một gói để tiếp tục.'), findsOneWidget);
    expect(_enabled(tester, 'setup-next'), isFalse);
  });

  testWidgets('adds a package that shows at once and unlocks the next step', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await _fill(tester);
    expect(find.text('3.200.000'), findsOneWidget, reason: 'the price field groups thousands');
    await tester.enterText(_key('package-edited'), '80');
    await tester.enterText(_key('package-delivery'), '5');
    await tester.ensureVisible(_key('package-submit'));
    await tester.tap(_key('package-submit'));
    await tester.pumpAndSettle();
    expect(find.text('Đã thêm gói.'), findsOneWidget);
    expect(w.packages.stored(w.uid).single.input, const ServicePackageInput(name: 'Cặp đôi nửa ngày', priceVnd: 3200000, durationMinutes: 240, editedCount: 80, deliveryDays: 5));
    expect(find.text('4 giờ · 80 ảnh · giao 5 ngày'), findsOneWidget);
    expect(find.text('3,2M'), findsOneWidget);
    expect(tester.widget<TextField>(_key('package-name')).controller!.text, isEmpty, reason: 'the form is ready for the next one');
    expect(_enabled(tester, 'setup-next'), isTrue);
  });

  testWidgets('says what is wrong and stores nothing', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('package-submit'));
    await tester.tap(_key('package-submit'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập tên gói từ 2 đến 60 ký tự'), findsOneWidget);
    expect(find.text('Nhập giá lớn hơn 0'), findsOneWidget);
    expect(find.text('Chọn thời lượng'), findsOneWidget);
    expect(w.packages.writes, 0);
  });

  testWidgets('edits a package from the list', (tester) async {
    final w = await _world(seed: const [_portrait]);
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_key('package-a'));
    await tester.pump();
    expect(tester.widget<TextField>(_key('package-name')).controller!.text, 'Chân dung 2 giờ');
    await tester.enterText(_key('package-price'), '1800000');
    await tester.ensureVisible(_key('package-submit'));
    expect(find.text('Lưu gói'), findsOneWidget);
    await tester.tap(_key('package-submit'));
    await tester.pumpAndSettle();
    expect(w.packages.stored(w.uid).single.priceVnd, 1800000);
    expect(find.text('Đã lưu gói.'), findsOneWidget);
  });

  testWidgets('hiding asks first; "Giữ lại" keeps the package', (tester) async {
    final w = await _world(seed: const [_portrait]);
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_key('package-hide-a'));
    await tester.pumpAndSettle();
    expect(find.text('Ẩn gói này?'), findsOneWidget);
    await tester.tap(_key('package-hide-keep'));
    await tester.pumpAndSettle();
    expect(w.packages.stored(w.uid).single.active, isTrue);

    await tester.tap(_key('package-hide-a'));
    await tester.pumpAndSettle();
    await tester.tap(_key('package-hide-confirm'));
    await tester.pumpAndSettle();
    expect(w.packages.stored(w.uid).single.active, isFalse);
    expect(_key('package-a'), findsNothing);
    expect(find.text('Đã ẩn gói.'), findsOneWidget);
    expect(_enabled(tester, 'setup-next'), isFalse);
  });

  testWidgets('"Tiếp tục" remembers step 3 and opens it; "Quay lại" goes to step 1', (tester) async {
    final w = await _world(seed: const [_portrait]);
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_key('setup-next'));
    await tester.pumpAndSettle();
    expect(find.text('stub /setup/3'), findsOneWidget);
    expect(SetupDraftStore(w.prefs).step(w.uid), 3);

    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_key('setup-back'));
    await tester.pumpAndSettle();
    expect(find.text('step 1'), findsOneWidget);
  });

  testWidgets('a half-filled form comes back after leaving', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await _fill(tester, name: 'Gia đình', price: '2000000', minutes: 180);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_key('package-name')).controller!.text, 'Gia đình');
    expect(tester.widget<TextField>(_key('package-price')).controller!.text, '2.000.000');
  });

  testWidgets('a failed save keeps the form and says so', (tester) async {
    final w = await _world();
    w.packages.failWrites = true;
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    await _fill(tester);
    await tester.ensureVisible(_key('package-submit'));
    await tester.tap(_key('package-submit'));
    await tester.pumpAndSettle();
    expect(find.text('Không lưu được. Kiểm tra mạng rồi thử lại.'), findsOneWidget);
    expect(tester.widget<TextField>(_key('package-name')).controller!.text, 'Cặp đôi nửa ngày');
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      usePhone(tester, width: 320, height: 640);
      final w = await _world(seed: const [
        _portrait,
        ServicePackage(id: 'b', name: 'Cưới cả ngày, hai thợ, album in cao cấp', priceVnd: 18000000, durationMinutes: 480, editedCount: 300, deliveryDays: 30),
      ]);
      await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes, brightness: b, textScale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/core/package_meta_test.dart test/features/photographer_setup`
Expected: FAIL to compile, `package_meta.dart`, `package_logic.dart` and `setup_packages_screen.dart` do not exist.

- [ ] **Step 3: Implement**

Add the strings of the Interfaces list to `lib/l10n/app_vi.arb`; the ones with placeholders:

```json
  "durationHours": "{hours} giờ",
  "@durationHours": {"placeholders": {"hours": {"type": "String"}}},
  "packagePhotos": "{count} ảnh",
  "@packagePhotos": {"placeholders": {"count": {"type": "int"}}},
  "packageDelivery": "{days, plural, =0{giao trong ngày} other{giao {days} ngày}}",
  "@packageDelivery": {"placeholders": {"days": {"type": "int"}}},
  "packageHideTooltip": "Ẩn gói {name}",
  "@packageHideTooltip": {"placeholders": {"name": {"type": "String"}}},
```

Run `flutter gen-l10n`.

```dart
// lib/core/package_meta.dart
import 'package:photobooking/l10n/app_localizations.dart';

/// `2 giờ`, or `1,5 giờ` for a duration that is not whole hours.
String durationLabel(int minutes, AppLocalizations l) => minutes % 60 == 0
    ? l.durationHours('${minutes ~/ 60}')
    : l.durationHours((minutes / 60).toStringAsFixed(1).replaceAll('.', ','));

/// The line under a package name: `2 giờ · 40 ảnh · giao 3 ngày`, with only
/// the parts that are known.
String packageMeta(
  AppLocalizations l, {
  required int durationMinutes,
  int? editedCount,
  int? deliveryDays,
}) => [
  durationLabel(durationMinutes, l),
  if (editedCount != null && editedCount > 0) l.packagePhotos(editedCount),
  if (deliveryDays != null) l.packageDelivery(deliveryDays),
].join(' · ');
```

Export from `core.dart`: `export 'package:photobooking/core/package_meta.dart';`.

```dart
// lib/features/photographer_setup/package_logic.dart
import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/l10n/app_localizations.dart';

const kPackageNameMin = 2;
const kPackageNameMax = 60;
const kPriceMaxVnd = 1000000000;
const kCountMax = 2000;
const kDeliveryMaxDays = 90;

enum PackageField { name, price, duration, edited, delivery }

enum PackageError { nameLength, priceRequired, priceTooHigh, durationRequired, countInvalid, daysInvalid }

/// The package form as typed.
@immutable
class PackageForm {
  const PackageForm({
    this.name = '',
    this.priceText = '',
    this.durationMinutes,
    this.editedText = '',
    this.deliveryText = '',
  });

  final String name;
  final String priceText;
  final int? durationMinutes;
  final String editedText;
  final String deliveryText;
}

@immutable
class PackageCheck {
  const PackageCheck(this.errors, this.input);

  final Map<PackageField, PackageError> errors;

  /// Set only when there are no errors.
  final ServicePackageInput? input;

  bool get ok => input != null;
}

PackageCheck validatePackage(PackageForm f) {
  final errors = <PackageField, PackageError>{};
  final name = f.name.trim();
  if (name.length < kPackageNameMin || name.length > kPackageNameMax) {
    errors[PackageField.name] = PackageError.nameLength;
  }
  final price = parseVnd(f.priceText);
  if (price == null || price <= 0) {
    errors[PackageField.price] = PackageError.priceRequired;
  } else if (price > kPriceMaxVnd) {
    errors[PackageField.price] = PackageError.priceTooHigh;
  }
  final duration = f.durationMinutes;
  if (duration == null || !kPackageDurationsMinutes.contains(duration)) {
    errors[PackageField.duration] = PackageError.durationRequired;
  }
  int? optional(String text, int max, PackageField field, PackageError error) {
    final t = text.trim();
    if (t.isEmpty) {
      return null;
    }
    final v = int.tryParse(t);
    if (v == null || v < 0 || v > max) {
      errors[field] = error;
      return null;
    }
    return v;
  }

  final edited = optional(f.editedText, kCountMax, PackageField.edited, PackageError.countInvalid);
  final delivery = optional(f.deliveryText, kDeliveryMaxDays, PackageField.delivery, PackageError.daysInvalid);
  if (errors.isNotEmpty) {
    return PackageCheck(errors, null);
  }
  return PackageCheck(
    const {},
    ServicePackageInput(
      name: name,
      priceVnd: price!,
      durationMinutes: duration!,
      editedCount: edited,
      deliveryDays: delivery,
    ),
  );
}

PackageForm packageFormOf(ServicePackage p) => PackageForm(
  name: p.name,
  priceText: groupVnd(p.priceVnd),
  durationMinutes: p.durationMinutes,
  editedText: p.editedCount?.toString() ?? '',
  deliveryText: p.deliveryDays?.toString() ?? '',
);

String packageErrorText(PackageError e, AppLocalizations l) => switch (e) {
  PackageError.nameLength => l.packageNameLength,
  PackageError.priceRequired => l.packagePriceRequired,
  PackageError.priceTooHigh => l.packagePriceTooHigh,
  PackageError.durationRequired => l.packageDurationRequired,
  PackageError.countInvalid => l.packageCountInvalid,
  PackageError.daysInvalid => l.packageDaysInvalid,
};
```

```dart
// lib/features/photographer_setup/setup_packages_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';

/// Writes the photographer's packages from S24 step 2. Each call answers
/// whether it went through; the screen shows the message.
class SetupPackagesController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> add(ServicePackageInput input) => _run((repo, uid) async {
    await repo.add(uid, input);
    await ref.read(setupDraftStoreProvider).clearPackage(uid);
  });

  Future<bool> save(String id, ServicePackageInput input) => _run((repo, uid) async {
    await repo.update(uid, id, input);
    await ref.read(setupDraftStoreProvider).clearPackage(uid);
  });

  Future<bool> hide(String id) => _run((repo, uid) => repo.hide(uid, id));

  Future<bool> _run(Future<void> Function(ServicePackageRepository repo, String uid) job) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      return false;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => job(ref.read(servicePackageRepositoryProvider), uid));
    return !state.hasError;
  }
}

final setupPackagesControllerProvider =
    AsyncNotifierProvider.autoDispose<SetupPackagesController, void>(SetupPackagesController.new);
```

```dart
// lib/features/photographer_setup/setup_packages_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/photographer_setup_providers.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/features/photographer_setup/package_logic.dart';
import 'package:photobooking/features/photographer_setup/setup_draft_store.dart';
import 'package:photobooking/features/photographer_setup/setup_packages_controller.dart';

/// S24, setup step 2/4: the packages customers book. At least one active
/// package is needed to go on. The form is kept as a device draft until a
/// package is added.
class SetupPackagesScreen extends ConsumerStatefulWidget {
  const SetupPackagesScreen({super.key});

  @override
  ConsumerState<SetupPackagesScreen> createState() => _SetupPackagesScreenState();
}

class _SetupPackagesScreenState extends ConsumerState<SetupPackagesScreen> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _edited = TextEditingController();
  final _delivery = TextEditingController();
  int? _duration;
  String? _editingId;
  Map<PackageField, PackageError> _errors = const {};
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = ref.read(authRepositoryProvider).currentUser?.uid;
    final uid = _uid;
    final d = uid == null ? null : ref.read(setupDraftStoreProvider).package(uid);
    if (d != null) {
      _name.text = d.name;
      _price.text = d.price;
      _duration = d.durationMinutes;
      _edited.text = d.edited;
      _delivery.text = d.delivery;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _edited.dispose();
    _delivery.dispose();
    super.dispose();
  }

  PackageForm get _form => PackageForm(
    name: _name.text,
    priceText: _price.text,
    durationMinutes: _duration,
    editedText: _edited.text,
    deliveryText: _delivery.text,
  );

  void _changed() {
    final uid = _uid;
    if (uid == null || _editingId != null) {
      return; // edits of a saved package are not drafts
    }
    final f = _form;
    ref
        .read(setupDraftStoreProvider)
        .savePackage(
          uid,
          PackageDraft(
            name: f.name,
            price: f.priceText,
            durationMinutes: f.durationMinutes,
            edited: f.editedText,
            delivery: f.deliveryText,
          ),
        );
  }

  void _clearForm() {
    setState(() {
      _name.clear();
      _price.clear();
      _edited.clear();
      _delivery.clear();
      _duration = null;
      _editingId = null;
      _errors = const {};
    });
  }

  void _edit(ServicePackage p) {
    final f = packageFormOf(p);
    setState(() {
      _editingId = p.id;
      _name.text = f.name;
      _price.text = f.priceText;
      _duration = f.durationMinutes;
      _edited.text = f.editedText;
      _delivery.text = f.deliveryText;
      _errors = const {};
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final check = validatePackage(_form);
    setState(() => _errors = check.errors);
    final input = check.input;
    if (input == null) {
      return;
    }
    final c = ref.read(setupPackagesControllerProvider.notifier);
    final editing = _editingId;
    final ok = editing == null ? await c.add(input) : await c.save(editing, input);
    if (!mounted) {
      return;
    }
    _snack(ok ? (editing == null ? l.packageAdded : l.packageSaved) : l.setupSaveError);
    if (ok) {
      _clearForm();
    }
  }

  Future<void> _confirmHide(ServicePackage p) async {
    final l = context.l10n;
    final yes = await showAppSheet<bool>(context, builder: (_) => const _HideSheet());
    if (yes != true || !mounted) {
      return;
    }
    final ok = await ref.read(setupPackagesControllerProvider.notifier).hide(p.id);
    if (!mounted) {
      return;
    }
    _snack(ok ? l.packageHidden : l.setupSaveError);
    if (ok && _editingId == p.id) {
      _clearForm();
    }
  }

  Future<void> _next() async {
    final uid = _uid;
    if (uid == null) {
      return;
    }
    final store = ref.read(setupDraftStoreProvider);
    if (store.step(uid) < 3) {
      await store.setStep(uid, 3);
    }
    if (mounted) {
      context.push('/setup/3');
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/setup/1');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final packages = ref.watch(myPackagesProvider);
    final active = [
      for (final p in packages.value ?? const <ServicePackage>[])
        if (p.active) p,
    ];
    final saving = ref.watch(setupPackagesControllerProvider).isLoading;
    String? err(PackageField f) => _errors[f] == null ? null : packageErrorText(_errors[f]!, l);
    final editing = _editingId != null;

    final list = packages.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpace.s5),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.setupPackagesLoadError),
            TextButton(onPressed: () => ref.invalidate(myPackagesProvider), child: Text(l.retry)),
          ],
        ),
      ),
      data: (_) => active.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpace.s5),
              child: Text(l.setupNoPackages, style: theme.textTheme.bodySmall),
            )
          : Column(
              children: [
                for (var i = 0; i < active.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _PackageRow(
                    package: active[i],
                    editing: active[i].id == _editingId,
                    onEdit: saving ? null : () => _edit(active[i]),
                    onHide: saving ? null : () => _confirmHide(active[i]),
                  ),
                ],
              ],
            ),
    );

    return ScreenCode(
      ScreenCodes.setupProfile,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.setupTitle)),
          body: SafeArea(
            top: false,
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.s5),
              children: [
                StepProgress(current: 2, total: 4, label: l.setupStepServices),
                const SizedBox(height: AppSpace.s4),
                Semantics(
                  header: true,
                  child: Text(l.setupServicesHeading, style: theme.textTheme.titleLarge),
                ),
                const SizedBox(height: AppSpace.s2),
                Text(l.setupServiceHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpace.s4),
                GlassCard(highlight: false, child: list),
                const SizedBox(height: AppSpace.s4),
                GlassCard(
                  highlight: false,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          editing ? l.packageEditHeading : l.packageNewHeading,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpace.s3),
                        TextField(
                          key: const Key('package-name'),
                          controller: _name,
                          enabled: !saving,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: l.packageNameLabel,
                            hintText: l.packageNameHint,
                            errorText: err(PackageField.name),
                          ),
                          onChanged: (_) => _changed(),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        TextField(
                          key: const Key('package-price'),
                          controller: _price,
                          enabled: !saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [VndInputFormatter()],
                          decoration: InputDecoration(
                            labelText: l.packagePriceLabel,
                            suffixText: '₫',
                            errorText: err(PackageField.price),
                          ),
                          onChanged: (_) => _changed(),
                        ),
                        const SizedBox(height: AppSpace.s3),
                        Text(l.packageDurationLabel, style: theme.textTheme.titleSmall),
                        const SizedBox(height: AppSpace.s2),
                        Wrap(
                          spacing: AppSpace.s2,
                          runSpacing: AppSpace.s2,
                          children: [
                            for (final m in kPackageDurationsMinutes)
                              AppChip(
                                key: Key('duration-$m'),
                                label: durationLabel(m, l),
                                kind: AppChipKind.context,
                                selected: _duration == m,
                                onChanged: (_) {
                                  if (saving) {
                                    return;
                                  }
                                  setState(() => _duration = m);
                                  _changed();
                                },
                              ),
                          ],
                        ),
                        if (err(PackageField.duration) case final e?) ...[
                          const SizedBox(height: AppSpace.s1),
                          Text(e, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                        ],
                        const SizedBox(height: AppSpace.s3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('package-edited'),
                                controller: _edited,
                                enabled: !saving,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                decoration: InputDecoration(
                                  labelText: l.packageEditedLabel,
                                  errorText: err(PackageField.edited),
                                  errorMaxLines: 2,
                                ),
                                onChanged: (_) => _changed(),
                              ),
                            ),
                            const SizedBox(width: AppSpace.s3),
                            Expanded(
                              child: TextField(
                                key: const Key('package-delivery'),
                                controller: _delivery,
                                enabled: !saving,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(2),
                                ],
                                decoration: InputDecoration(
                                  labelText: l.packageDeliveryLabel,
                                  errorText: err(PackageField.delivery),
                                  errorMaxLines: 2,
                                ),
                                onChanged: (_) => _changed(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.s4),
                        AppButton.outline(
                          editing ? l.packageSave : l.packageAdd,
                          key: const Key('package-submit'),
                          icon: Icon(editing ? Icons.check_rounded : Icons.add_rounded),
                          loading: saving,
                          onPressed: _submit,
                        ),
                        if (editing)
                          AppButton.text(
                            l.packageCancelEdit,
                            key: const Key('package-cancel-edit'),
                            onPressed: _clearForm,
                          ),
                      ],
                    ),
                  ),
                ),
                if (active.isEmpty && packages.hasValue) ...[
                  const SizedBox(height: AppSpace.s3),
                  Text(l.setupNeedPackage, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(AppSpace.s5, AppSpace.s2, AppSpace.s5, AppSpace.s4),
            child: Row(
              children: [
                Expanded(
                  child: AppButton.outline(l.setupBack, key: const Key('setup-back'), onPressed: _back),
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: AppButton.primary(
                    l.setupNext,
                    key: const Key('setup-next'),
                    onPressed: active.isEmpty || saving ? null : _next,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PackageRow extends StatelessWidget {
  const _PackageRow({required this.package, required this.editing, required this.onEdit, required this.onHide});

  final ServicePackage package;
  final bool editing;
  final VoidCallback? onEdit;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final p = package;
    return Material(
      color: editing ? theme.colorScheme.primary.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        key: Key('package-${p.id}'),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s3, AppSpace.s1, AppSpace.s3),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: theme.textTheme.titleSmall),
                    Text(
                      packageMeta(l, durationMinutes: p.durationMinutes, editedCount: p.editedCount, deliveryDays: p.deliveryDays),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Text(
                formatMoney(p.priceVnd, short: true),
                style: theme.textTheme.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              IconButton(
                key: Key('package-hide-${p.id}'),
                tooltip: l.packageHideTooltip(p.name),
                icon: const Icon(Icons.visibility_off_outlined),
                onPressed: onHide,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmation before hiding a package; the red button lives only here.
class _HideSheet extends StatelessWidget {
  const _HideSheet();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.s5, AppSpace.s2, AppSpace.s5, AppSpace.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.packageHideTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpace.s2),
          Text(l.packageHideBody),
          const SizedBox(height: AppSpace.s5),
          FilledButton(
            key: const Key('package-hide-confirm'),
            style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.packageHideConfirm),
          ),
          const SizedBox(height: AppSpace.s2),
          AppButton.outline(
            l.packageKeep,
            key: const Key('package-hide-keep'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
```

In `lib/app/router.dart` add `import 'package:photobooking/features/photographer_setup/setup_packages_screen.dart';` and, after the `/setup/1` route:

```dart
      GoRoute(
        path: '/setup/2',
        redirect: (_, _) => photographersOnly(),
        builder: (_, _) => const SetupPackagesScreen(),
      ),
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/core/package_meta_test.dart test/features/photographer_setup && flutter analyze`
Expected: PASS (meta 2, logic 3, screen 10, plus Task 6's tests); analyze clean. If `find.text('3.200.000')` also matches the list row, it cannot: the row shows the short form `3,2M`. If `_enabled` cannot find a `FilledButton` under the key, the key sits on `AppButton`; the descendant finder handles that.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib test
git commit -m "feat(setup): S24 step 2 service packages with edit, hide and draft

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 8: S20 "Lịch của tôi"

**Files:**
- Create: `lib/features/calendar/my_calendar_controller.dart`, `lib/features/calendar/my_calendar_screen.dart`, `test/features/calendar/my_calendar_controller_test.dart`, `test/features/calendar/my_calendar_screen_test.dart`
- Modify: `lib/app/router.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `AvailabilityCalendar`, `AvailabilityLegend`, `DayState`, `weekdayCode` (Task 2); `AvailabilityDay`, `availabilityRepositoryProvider`, `availabilityMonthProvider`, `calendarTodayProvider`, `FakeAvailabilityRepository` (Task 3); `calendarDay`, `monthOf`, `addMonths`, `lastDayOfMonth`, `daysBetween` (Task 1); `SegmentedTabs`, `SegmentOption` (3a1); `ScreenCodes.myCalendar`; `PhotographerWorld`, `usePhone` (Task 6).
- Produces:
  - `List<DateTime> freeDaysBetween(DateTime a, DateTime b, Map<DateTime, AvailabilityDay> known, {required DateTime from})` — days of the range from [from] on that have no record.
  - `List<DateTime> monthWindow(DateTime month, {required DateTime first, required DateTime last})` — three consecutive months containing [month], clamped to `[first, last]`.
  - `calendarEditControllerProvider` (`AsyncNotifierProvider.autoDispose<CalendarEditController, void>`) with `Future<bool> markOff(List<DateTime> days)`, `Future<bool> clearOff(List<DateTime> days)` (true when saved).
  - `MyCalendarScreen` at `/work/calendar` (photographers only), with `@visibleForTesting static int debugBuildCount` (builds of the screen shell; switching months must not change it).
  - Behaviour (spec S20): months from this month to 12 months ahead, three month tabs; tap a free day from today on → off at once with "Đã đánh dấu nghỉ" + "Hoàn tác"; tap an off day → free again with "Đã bỏ nghỉ" + "Hoàn tác"; tap a booked/pending day → "Ngày này đã có lịch" and the day panel links to `/b/{bookingId}` (step 4 route); a day with an event links to `/events/{eventId}/manage` (S27, events plan); press and hold a free day, then tap the last day → every free day between is off ("Đã đánh dấu nghỉ {n} ngày" + "Hoàn tác"); past days are read-only; the selected day's panel has "Đánh dấu nghỉ" (primary) or "Bỏ nghỉ".
  - Widget keys: `month-tabs`, `mark-off`, `clear-off`, `open-booking`, `open-event`, `calendar-retry`.
  - l10n: `myCalendarTitle` "Lịch của tôi", `calendarMarkOff` "Đánh dấu nghỉ", `calendarClearOff` "Bỏ nghỉ", `calendarUndo` "Hoàn tác", `calendarHint` "Chạm ngày trống để đánh dấu Nghỉ. Khách sẽ không đặt được ngày đó.", `calendarRangeHint` "Chạm ngày cuối để đánh dấu nghỉ cả khoảng.", `calendarHasPlan` "Ngày này đã có lịch", `calendarMarkedOff` "Đã đánh dấu nghỉ", `calendarMarkedOffMany(count)` "Đã đánh dấu nghỉ {count} ngày", `calendarClearedOff` "Đã bỏ nghỉ", `calendarOpenBooking` "Xem lịch hẹn", `calendarOpenEvent` "Quản lý sự kiện", `calendarSaveError` "Không lưu được lịch. Thử lại nhé.", `calendarLoadError` "Không tải được lịch.", `calendarPickDay` "Chọn một ngày để xem chi tiết.".

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/calendar/my_calendar_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/features/calendar/my_calendar_controller.dart';

import '../../support/photographer_world.dart';

DateTime _d(int day) => DateTime.utc(2026, 10, day);

void main() {
  test('freeDaysBetween keeps only free days from today on, in either order', () {
    final known = {_d(11): AvailabilityDay(day: _d(11), state: DayState.booked)};
    expect(freeDaysBetween(_d(12), _d(9), known, from: _d(10)), [_d(10), _d(12)]);
  });

  test('monthWindow is three months, clamped to the bounds', () {
    final first = DateTime.utc(2026, 10);
    final last = DateTime.utc(2027, 10);
    expect(monthWindow(DateTime.utc(2026, 10), first: first, last: last),
        [DateTime.utc(2026, 10), DateTime.utc(2026, 11), DateTime.utc(2026, 12)]);
    expect(monthWindow(DateTime.utc(2027, 2), first: first, last: last),
        [DateTime.utc(2027, 1), DateTime.utc(2027, 2), DateTime.utc(2027, 3)]);
    expect(monthWindow(DateTime.utc(2027, 10), first: first, last: last),
        [DateTime.utc(2027, 8), DateTime.utc(2027, 9), DateTime.utc(2027, 10)]);
  });

  test('the controller writes for the signed-in photographer and reports failures', () async {
    final w = PhotographerWorld();
    await w.init();
    final c = ProviderContainer(overrides: w.overrides, retry: (_, _) => null);
    addTearDown(c.dispose);
    final sub = c.listen(calendarEditControllerProvider, (_, _) {});
    addTearDown(sub.close);
    final edit = c.read(calendarEditControllerProvider.notifier);
    expect(await edit.markOff([_d(12), _d(13)]), isTrue);
    expect(w.availability.stored(w.uid).keys.toSet(), {_d(12), _d(13)});
    expect(await edit.clearOff([_d(12)]), isTrue);
    expect(w.availability.stored(w.uid).keys, [_d(13)]);
    w.availability.failWrites = true;
    expect(await edit.markOff([_d(20)]), isFalse);
  });
}
```

```dart
// test/features/calendar/my_calendar_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/features/calendar/my_calendar_screen.dart';

import '../../support/photographer_world.dart';

DateTime _d(int day) => DateTime.utc(2026, 10, day);
final _routes = <RouteBase>[
  GoRoute(path: '/work/calendar', builder: (_, _) => const MyCalendarScreen()),
];

Future<PhotographerWorld> _world() async {
  final w = PhotographerWorld();
  await w.init();
  w.availability
    ..seed(w.uid, AvailabilityDay(day: _d(10), state: DayState.booked, bookingId: 'b1'))
    ..seed(w.uid, AvailabilityDay(day: _d(11), state: DayState.pending, bookingId: 'b2'))
    ..seed(w.uid, AvailabilityDay(day: _d(12), state: DayState.off))
    ..seed(w.uid, AvailabilityDay(day: _d(15), state: DayState.booked, eventId: 'e1'));
  return w;
}

Finder _day(String label) => find.bySemanticsLabel(label);

void main() {
  testWidgets('shows the month with its four states and the legend', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    expect(find.text('Lịch của tôi'), findsOneWidget);
    expect(_day('10 tháng 10, đã đặt'), findsOneWidget);
    expect(_day('11 tháng 10, chờ nhận'), findsOneWidget);
    expect(_day('12 tháng 10, nghỉ'), findsOneWidget);
    expect(_day('15 tháng 10, đã đặt, có sự kiện'), findsOneWidget);
    expect(find.text('Chạm ngày trống để đánh dấu Nghỉ. Khách sẽ không đặt được ngày đó.'), findsOneWidget);
    h.dispose();
  });

  testWidgets('a tap marks a free day off, and "Hoàn tác" frees it again', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_day('13 tháng 10, rảnh'));
    await tester.pumpAndSettle();
    expect(w.availability.stored(w.uid)[_d(13)]!.state, DayState.off);
    expect(find.text('Đã đánh dấu nghỉ'), findsOneWidget);
    expect(_day('13 tháng 10, nghỉ'), findsOneWidget);
    expect(find.text('Thứ 3, 13/10'), findsOneWidget);
    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();
    expect(w.availability.stored(w.uid)[_d(13)], isNull);
    h.dispose();
  });

  testWidgets('a tap on an off day frees it', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_day('12 tháng 10, nghỉ'));
    await tester.pumpAndSettle();
    expect(w.availability.stored(w.uid)[_d(12)], isNull);
    expect(find.text('Đã bỏ nghỉ'), findsOneWidget);
    h.dispose();
  });

  testWidgets('booked and pending days cannot be marked and link to the booking', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_day('10 tháng 10, đã đặt'));
    await tester.pumpAndSettle();
    expect(find.text('Ngày này đã có lịch'), findsWidgets);
    expect(w.availability.writes, 0);
    expect(find.byKey(const Key('mark-off')), findsNothing);
    await tester.tap(find.byKey(const Key('open-booking')));
    await tester.pumpAndSettle();
    expect(find.text('stub /b/b1'), findsOneWidget);
    h.dispose();
  });

  testWidgets('an event day opens the event', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_day('15 tháng 10, đã đặt, có sự kiện'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-event')));
    await tester.pumpAndSettle();
    expect(find.text('stub /events/e1/manage'), findsOneWidget);
    h.dispose();
  });

  testWidgets('hold the first day, tap the last: the free days between are off', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    await tester.longPress(_day('9 tháng 10, rảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Chạm ngày cuối để đánh dấu nghỉ cả khoảng.'), findsOneWidget);
    await tester.tap(_day('13 tháng 10, rảnh'));
    await tester.pumpAndSettle();
    final stored = w.availability.stored(w.uid);
    expect([for (final d in [9, 10, 11, 12, 13]) stored[_d(d)]!.state],
        [DayState.off, DayState.booked, DayState.pending, DayState.off, DayState.off]);
    expect(find.text('Đã đánh dấu nghỉ 2 ngày'), findsOneWidget);
    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();
    expect(w.availability.stored(w.uid)[_d(9)], isNull);
    expect(w.availability.stored(w.uid)[_d(12)]!.state, DayState.off, reason: 'undo only frees the days it marked');
    h.dispose();
  });

  testWidgets('the panel button does the same as tapping the day', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    w.today = _d(1);
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    expect(find.text('Thứ 5, 1/10'), findsOneWidget, reason: 'today is selected first');
    await tester.tap(find.byKey(const Key('mark-off')));
    await tester.pumpAndSettle();
    expect(w.availability.stored(w.uid)[_d(1)]!.state, DayState.off);
    await tester.tap(find.byKey(const Key('clear-off')));
    await tester.pumpAndSettle();
    expect(w.availability.stored(w.uid)[_d(1)], isNull);
    h.dispose();
  });

  testWidgets('past days are read-only', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    w.today = _d(14);
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_day('13 tháng 10, rảnh'));
    await tester.pumpAndSettle();
    expect(w.availability.writes, 0);
    h.dispose();
  });

  testWidgets('switching months keeps one listener and does not rebuild the screen', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    expect(w.availability.watchers, 1);
    final builds = MyCalendarScreen.debugBuildCount;
    await tester.tap(find.text('Tháng 11'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tháng 12'));
    await tester.pumpAndSettle();
    expect(w.availability.watchers, 1);
    expect(MyCalendarScreen.debugBuildCount, builds);
    expect(find.text('Tháng 1'), findsOneWidget, reason: 'the tabs slide with the month');
  });

  testWidgets('a failed save says so and changes nothing', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    w.availability.failWrites = true;
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    await tester.tap(_day('13 tháng 10, rảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Không lưu được lịch. Thử lại nhé.'), findsOneWidget);
    expect(_day('13 tháng 10, rảnh'), findsOneWidget);
    h.dispose();
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x text (${b.name})', (tester) async {
      usePhone(tester, width: 320, height: 640);
      final w = await _world();
      await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes, brightness: b, textScale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/calendar`
Expected: FAIL to compile, `my_calendar_controller.dart` and `my_calendar_screen.dart` do not exist.

- [ ] **Step 3: Implement**

Add the strings of the Interfaces list to `lib/l10n/app_vi.arb` (with `"@calendarMarkedOffMany": {"placeholders": {"count": {"type": "int"}}}`) and run `flutter gen-l10n`.

```dart
// lib/features/calendar/my_calendar_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';

/// Days from [a] to [b] (either order) that are on or after [from] and
/// have no record yet: what a range press may mark off.
List<DateTime> freeDaysBetween(
  DateTime a,
  DateTime b,
  Map<DateTime, AvailabilityDay> known, {
  required DateTime from,
}) => [
  for (final d in daysBetween(a, b))
    if (!d.isBefore(calendarDay(from)) && !known.containsKey(d)) d,
];

/// The three month tabs around [month], kept inside [first]..[last].
List<DateTime> monthWindow(DateTime month, {required DateTime first, required DateTime last}) {
  var start = addMonths(monthOf(month), -1);
  if (start.isBefore(monthOf(first))) {
    start = monthOf(first);
  }
  if (addMonths(start, 2).isAfter(monthOf(last))) {
    start = addMonths(monthOf(last), -2);
  }
  return [start, addMonths(start, 1), addMonths(start, 2)];
}

/// Marks days off / frees them for the signed-in photographer (S20).
class CalendarEditController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> markOff(List<DateTime> days) => _run((repo, uid) => repo.markOff(uid, days));

  Future<bool> clearOff(List<DateTime> days) => _run((repo, uid) => repo.clearOff(uid, days));

  Future<bool> _run(Future<void> Function(AvailabilityRepository repo, String uid) write) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      return false;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => write(ref.read(availabilityRepositoryProvider), uid));
    return !state.hasError;
  }
}

final calendarEditControllerProvider =
    AsyncNotifierProvider.autoDispose<CalendarEditController, void>(CalendarEditController.new);
```

```dart
// lib/features/calendar/my_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/features/calendar/my_calendar_controller.dart';

/// S20 "Lịch của tôi": the photographer marks days off; booked and pending
/// days come from bookings and events and are read-only here.
///
/// The month, the selected day and a range start are `ValueNotifier`s, so
/// switching months rebuilds only the month part, never this shell, and
/// only one month listener is open at a time.
class MyCalendarScreen extends ConsumerStatefulWidget {
  const MyCalendarScreen({super.key});

  /// Builds of the screen shell (debug builds only); a battery test checks
  /// that month switches do not add to it.
  @visibleForTesting
  static int debugBuildCount = 0;

  @override
  ConsumerState<MyCalendarScreen> createState() => _MyCalendarScreenState();
}

class _MyCalendarScreenState extends ConsumerState<MyCalendarScreen> {
  late final DateTime _today = ref.read(calendarTodayProvider);
  late final DateTime _first = monthOf(_today);
  late final DateTime _last = addMonths(_first, 12);
  late final ValueNotifier<DateTime> _month = ValueNotifier(_first);
  late final ValueNotifier<DateTime?> _selected = ValueNotifier(_today);
  final ValueNotifier<DateTime?> _rangeStart = ValueNotifier(null);

  @override
  void dispose() {
    _month.dispose();
    _selected.dispose();
    _rangeStart.dispose();
    super.dispose();
  }

  void _setMonth(DateTime m) {
    final target = monthOf(m);
    _month.value = target.isBefore(_first) ? _first : (target.isAfter(_last) ? _last : target);
    _rangeStart.value = null;
    _selected.value = null;
  }

  void _toast(String text, {String? action, VoidCallback? onAction}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: action == null || onAction == null
              ? null
              : SnackBarAction(label: action, onPressed: onAction),
        ),
      );
  }

  Future<void> _mark(List<DateTime> days, {required bool off, bool undoable = true}) async {
    final l = context.l10n;
    final edit = ref.read(calendarEditControllerProvider.notifier);
    final ok = off ? await edit.markOff(days) : await edit.clearOff(days);
    if (!mounted) {
      return;
    }
    if (!ok) {
      _toast(l.calendarSaveError);
      return;
    }
    if (!undoable) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      return;
    }
    final text = !off
        ? l.calendarClearedOff
        : days.length == 1
        ? l.calendarMarkedOff
        : l.calendarMarkedOffMany(days.length);
    _toast(text, action: l.calendarUndo, onAction: () => _mark(days, off: !off, undoable: false));
  }

  void _onDay(DateTime day, Map<DateTime, AvailabilityDay> known) {
    final l = context.l10n;
    _selected.value = day;
    final start = _rangeStart.value;
    if (start != null) {
      _rangeStart.value = null;
      final days = freeDaysBetween(start, day, known, from: _today);
      if (days.isNotEmpty) {
        _mark(days, off: true);
      }
      return;
    }
    if (day.isBefore(_today)) {
      return;
    }
    final record = known[day];
    if (record?.eventId != null) {
      return; // the panel offers "Quản lý sự kiện"
    }
    switch (record?.state ?? DayState.free) {
      case DayState.free:
        _mark([day], off: true);
      case DayState.off:
        _mark([day], off: false);
      case DayState.booked || DayState.pending:
        _toast(l.calendarHasPlan);
    }
  }

  void _onLongPress(DateTime day, Map<DateTime, AvailabilityDay> known) {
    if (day.isBefore(_today) || known.containsKey(day)) {
      return;
    }
    _rangeStart.value = day;
    _selected.value = day;
    _toast(context.l10n.calendarRangeHint);
  }

  @override
  Widget build(BuildContext context) {
    assert(() {
      MyCalendarScreen.debugBuildCount++;
      return true;
    }());
    // Keeps the edit controller alive across awaits without rebuilding.
    ref.listen(calendarEditControllerProvider, (_, _) {});
    final l = context.l10n;
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    return ScreenCode(
      ScreenCodes.myCalendar,
      child: AuroraBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.myCalendarTitle)),
          body: SafeArea(
            top: false,
            child: uid == null
                ? const SizedBox.shrink()
                : ValueListenableBuilder<DateTime>(
                    valueListenable: _month,
                    builder: (context, month, _) => _MonthView(
                      key: ValueKey(month),
                      uid: uid,
                      month: month,
                      today: _today,
                      first: _first,
                      last: _last,
                      selected: _selected,
                      rangeStart: _rangeStart,
                      onMonth: _setMonth,
                      onDay: _onDay,
                      onLongPress: _onLongPress,
                      onMark: (day, off) => _mark([day], off: off),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MonthView extends ConsumerWidget {
  const _MonthView({
    super.key,
    required this.uid,
    required this.month,
    required this.today,
    required this.first,
    required this.last,
    required this.selected,
    required this.rangeStart,
    required this.onMonth,
    required this.onDay,
    required this.onLongPress,
    required this.onMark,
  });

  final String uid;
  final DateTime month;
  final DateTime today;
  final DateTime first;
  final DateTime last;
  final ValueNotifier<DateTime?> selected;
  final ValueNotifier<DateTime?> rangeStart;
  final ValueChanged<DateTime> onMonth;
  final void Function(DateTime day, Map<DateTime, AvailabilityDay> known) onDay;
  final void Function(DateTime day, Map<DateTime, AvailabilityDay> known) onLongPress;
  final void Function(DateTime day, bool off) onMark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final key = (uid: uid, month: month);
    final days = ref.watch(availabilityMonthProvider(key));
    final known = days.value ?? const <DateTime, AvailabilityDay>{};
    final states = {for (final e in known.entries) e.key: e.value.state};
    final events = {
      for (final e in known.entries)
        if (e.value.eventId != null) e.key,
    };
    final window = monthWindow(month, first: first, last: last);

    Widget calendar = ValueListenableBuilder<DateTime?>(
      valueListenable: selected,
      builder: (context, sel, _) => ValueListenableBuilder<DateTime?>(
        valueListenable: rangeStart,
        builder: (context, start, _) => AvailabilityCalendar(
          month: month,
          states: states,
          selected: sel,
          editable: true,
          showHeader: false,
          minDate: today,
          maxDate: lastDayOfMonth(last),
          today: today,
          eventDays: events,
          rangeStart: start,
          onSelect: (d) => onDay(d, known),
          onLongPress: (d) => onLongPress(d, known),
          onMonthChanged: onMonth,
        ),
      ),
    );
    if (!days.hasValue) {
      calendar = IgnorePointer(child: Opacity(opacity: 0.5, child: calendar));
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpace.s4),
      children: [
        SegmentedTabs<DateTime>(
          key: const Key('month-tabs'),
          options: [
            for (final m in window) SegmentOption(value: m, label: l.calendarMonthShort('${m.month}')),
          ],
          value: month,
          onChanged: onMonth,
        ),
        const SizedBox(height: AppSpace.s3),
        GlassCard(
          highlight: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.calendarMonthTitle('${month.month}', '${month.year}'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(fontFamily: AppFonts.display),
                ),
                const SizedBox(height: AppSpace.s2),
                calendar,
                const SizedBox(height: AppSpace.s3),
                const AvailabilityLegend(),
                if (days.hasError) ...[
                  const SizedBox(height: AppSpace.s2),
                  Text(l.calendarLoadError, style: theme.textTheme.bodySmall),
                  TextButton(
                    key: const Key('calendar-retry'),
                    onPressed: () => ref.invalidate(availabilityMonthProvider(key)),
                    child: Text(l.retry),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        ValueListenableBuilder<DateTime?>(
          valueListenable: selected,
          builder: (context, sel, _) => _DayPanel(
            day: sel,
            record: sel == null ? null : known[sel],
            today: today,
            onMark: onMark,
          ),
        ),
        const SizedBox(height: AppSpace.s3),
        Text(l.calendarHint, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _DayPanel extends StatelessWidget {
  const _DayPanel({required this.day, required this.record, required this.today, required this.onMark});

  final DateTime? day;
  final AvailabilityDay? record;
  final DateTime today;
  final void Function(DateTime day, bool off) onMark;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final d = day;
    if (d == null) {
      return Text(l.calendarPickDay, style: theme.textTheme.bodyMedium);
    }
    final state = record?.state ?? DayState.free;
    final past = d.isBefore(today);
    final bookingId = record?.bookingId;
    final eventId = record?.eventId;
    return GlassCard(
      highlight: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l.calendarDayTitle(l.calendarWeekdayLong(weekdayCode(d.weekday)), '${d.day}', '${d.month}'),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpace.s1),
            Text(state.label(l), style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpace.s3),
            if (eventId != null)
              AppButton.outline(
                l.calendarOpenEvent,
                key: const Key('open-event'),
                icon: const Icon(Icons.event_outlined),
                onPressed: () => context.push('/events/$eventId/manage'),
              )
            else if (state == DayState.booked || state == DayState.pending) ...[
              Text(l.calendarHasPlan),
              if (bookingId != null) ...[
                const SizedBox(height: AppSpace.s2),
                AppButton.outline(
                  l.calendarOpenBooking,
                  key: const Key('open-booking'),
                  icon: const Icon(Icons.receipt_long_outlined),
                  onPressed: () => context.push('/b/$bookingId'),
                ),
              ],
            ] else if (!past && state == DayState.off)
              AppButton.outline(
                l.calendarClearOff,
                key: const Key('clear-off'),
                onPressed: () => onMark(d, false),
              )
            else if (!past)
              AppButton.primary(
                l.calendarMarkOff,
                key: const Key('mark-off'),
                onPressed: () => onMark(d, true),
              ),
          ],
        ),
      ),
    );
  }
}
```

In `lib/app/router.dart` add `import 'package:photobooking/features/calendar/my_calendar_screen.dart';` and, after the `/setup/2` route:

```dart
      GoRoute(
        path: '/work/calendar',
        redirect: (_, _) => photographersOnly(),
        builder: (_, _) => const MyCalendarScreen(),
      ),
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/features/calendar && flutter analyze`
Expected: PASS (controller 3, screen 12); analyze clean. If the "Hoàn tác" action is not found because the SDK keeps action snackbars until dismissed and the previous snackbar is still shown, the `hideCurrentSnackBar()` in `_toast` handles it; if the action snackbar never auto-hides in this SDK (`SnackBar.persist`), leave it, it is static and does not affect the idle checks.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib test
git commit -m "feat(calendar): S20 my calendar with days off, ranges and undo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Entry points (S30, work tab) and spec alignment

**Files:**
- Modify: `lib/features/shell/placeholder_tabs.dart`, `lib/l10n/app_vi.arb`, `test/features/shell/placeholder_tabs_test.dart`, `test/features/responsive_test.dart`, `test/features/screen_codes_applied_test.dart` (only if the file exists), `docs/superpowers/specs/screens/photographer.md`, `docs/superpowers/specs/components/shared-components.md`

**Interfaces:**
- Consumes: `myIntroProvider`, `photographerIntroRepositoryProvider`, `FakePhotographerIntroRepository`, `PhotographerIntro` (Task 4); `roleSwitchControllerProvider`; `GoRouter.maybeOf`.
- Produces:
  - `ProfileTab` (S30): for a photographer whose `onboardingComplete` is false, a highlighted card "Hoàn thiện hồ sơ nhiếp ảnh gia" with "Tiếp tục thiết lập" (key `continue-setup`) → `/setup`. After a successful switch to photographer, if setup is not complete, the tab pushes `/setup` (spec S30 "chuyển sang NAG khi hồ sơ chưa xong → mở S24"). No router above (old tests) → nothing is pushed.
  - `BookingsTab` (photographer): AppBar action (key `open-calendar`, tooltip "Lịch của tôi") → `/work/calendar`. Plan "step 5" (S19) replaces this tab and must keep the entry.
  - l10n: `profileSetupTitle` "Hoàn thiện hồ sơ nhiếp ảnh gia", `profileSetupBody` "Còn vài bước nữa để khách tìm thấy và đặt lịch với bạn.", `profileSetupContinue` "Tiếp tục thiết lập".

- [ ] **Step 1: Write the failing tests**

In `test/features/shell/placeholder_tabs_test.dart`:

1. Add imports `package:go_router/go_router.dart`, `package:photobooking/data/photographer/photographer_intro.dart`, `package:photobooking/data/photographer/photographer_setup_providers.dart`.
2. In `_app`, add `photographerIntroRepositoryProvider.overrideWithValue(FakePhotographerIntroRepository())` to `overrides` and `retry: (_, _) => null` to the `ProviderScope`.
3. Append to `main()`:

```dart
  Widget routed(
    FakeAuthRepository auth,
    FakeUserRepository users,
    FakePhotographerIntroRepository intro, {
    String initial = '/profile',
  }) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/profile', builder: (_, _) => const ProfileTab()),
        GoRoute(path: '/bookings', builder: (_, _) => const BookingsTab()),
        GoRoute(path: '/setup', builder: (_, _) => const Text('setup')),
        GoRoute(path: '/work/calendar', builder: (_, _) => const Text('calendar')),
      ],
    );
    return ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        photographerIntroRepositoryProvider.overrideWithValue(intro),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('a photographer with unfinished setup is offered to continue it', (tester) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    final intro = FakePhotographerIntroRepository()..seed(auth.currentUser!.uid, const PhotographerIntro());
    await tester.pumpWidget(routed(auth, users, intro));
    await tester.pumpAndSettle();
    expect(find.text('Hoàn thiện hồ sơ nhiếp ảnh gia'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('continue-setup')));
    await tester.tap(find.byKey(const Key('continue-setup')));
    await tester.pumpAndSettle();
    expect(find.text('setup'), findsOneWidget);
  });

  testWidgets('the setup card is gone once setup is complete', (tester) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    final intro = FakePhotographerIntroRepository()
      ..seed(auth.currentUser!.uid, const PhotographerIntro(onboardingComplete: true));
    await tester.pumpWidget(routed(auth, users, intro));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('continue-setup')), findsNothing);
  });

  testWidgets('switching to photographer opens setup while it is unfinished', (tester) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(routed(auth, users, FakePhotographerIntroRepository()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('switch-role')));
    await tester.tap(find.byKey(const Key('switch-role')));
    await tester.pumpAndSettle();
    expect(find.text('setup'), findsOneWidget);
  });

  testWidgets('photographers open their calendar from the work tab', (tester) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    await tester.pumpWidget(routed(auth, users, FakePhotographerIntroRepository(), initial: '/bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-calendar')));
    await tester.pumpAndSettle();
    expect(find.text('calendar'), findsOneWidget);
  });

  testWidgets('customers have no calendar entry', (tester) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(routed(auth, users, FakePhotographerIntroRepository(), initial: '/bookings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-calendar')), findsNothing);
  });
```

In `test/features/responsive_test.dart` (and `test/features/screen_codes_applied_test.dart` if it exists) add the import `package:photobooking/data/photographer/photographer_intro.dart` and `package:photobooking/data/photographer/photographer_setup_providers.dart`, the override `photographerIntroRepositoryProvider.overrideWithValue(FakePhotographerIntroRepository())` and `retry: (_, _) => null` on the `ProviderScope`.

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/shell/placeholder_tabs_test.dart`
Expected: the five new tests FAIL (no card, no push, no calendar action).

- [ ] **Step 3: Implement**

Add the three strings to `lib/l10n/app_vi.arb`, run `flutter gen-l10n`.

In `lib/features/shell/placeholder_tabs.dart`:

1. Imports: `package:photobooking/data/photographer/photographer_intro.dart`, `package:photobooking/data/photographer/photographer_setup_providers.dart`.
2. Add this top-level helper:

```dart
/// After switching to photographer: open the setup while it is unfinished
/// (spec S30). Without a router above (some widget tests) it does nothing.
Future<void> _openSetupIfUnfinished(BuildContext context, WidgetRef ref) async {
  final uid = ref.read(authRepositoryProvider).currentUser?.uid;
  if (uid == null) {
    return;
  }
  PhotographerIntro? intro;
  try {
    intro = await ref.read(photographerIntroRepositoryProvider).get(uid);
  } catch (_) {
    return; // offline: the card on this tab still offers it
  }
  if (!context.mounted || (intro?.onboardingComplete ?? false)) {
    return;
  }
  GoRouter.maybeOf(context)?.push('/setup');
}
```

3. In `BookingsTab.build`, give the `AppBar` the action (photographers only):

```dart
      appBar: AppBar(
        title: Text(photographer ? l.tabWork : l.tabBookings),
        actions: [
          if (photographer)
            IconButton(
              key: const Key('open-calendar'),
              tooltip: l.myCalendarTitle,
              icon: const Icon(Icons.event_available_outlined),
              onPressed: () => context.push('/work/calendar'),
            ),
        ],
      ),
```

4. In `ProfileTab.build`:
   - after `final isPhotographer = …;` add
     `final setupOpen = isPhotographer && !(ref.watch(myIntroProvider).value?.onboardingComplete ?? true);`
   - in the `ref.listen(roleSwitchControllerProvider, …)` callback, after the snackbar is shown, add
     `if (!next.hasError && next.value == UserRole.photographer) { _openSetupIfUnfinished(context, ref); }`
   - in the column, between the role label and the existing role-switch `GlassCard`, insert:

```dart
                    if (setupOpen) ...[
                      const SizedBox(height: AppSpace.s6),
                      GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.s4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(l.profileSetupTitle, style: theme.textTheme.titleMedium),
                              const SizedBox(height: AppSpace.s1),
                              Text(l.profileSetupBody, style: theme.textTheme.bodySmall),
                              const SizedBox(height: AppSpace.s4),
                              AppButton.outline(
                                l.profileSetupContinue,
                                key: const Key('continue-setup'),
                                icon: const Icon(Icons.arrow_forward_rounded),
                                onPressed: () => context.push('/setup'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
```

   (The spectrum-edged card is the screen's one highlighted card; the role card stays `highlight: false`.)

Spec alignment (write exactly this):

- `docs/superpowers/specs/screens/photographer.md`, S24: append to **Bố cục bước 1** "(bản đầu: tên hiển thị, giới thiệu ≤ 300 ký tự, thiết bị ≤ 8; ảnh đại diện thêm ở kế hoạch 2d2; ảnh bìa để kế hoạch media sau; thể loại và số năm kinh nghiệm chọn ở S38/S39, lưu trong `skills`)"; replace "thoát giữa chừng hỏi lưu nháp" in **Trạng thái** with "thoát giữa chừng không mất dữ liệu: mọi thứ đã gõ được lưu nháp trên máy theo từng người dùng, dữ liệu đã lưu nằm trên Firestore; vào lại `/setup` tiếp tục đúng bước"; append to **Dữ liệu** "Gói không bị xoá mà ẩn (`active: false`) để bài đăng và booking cũ còn trỏ đúng gói; giá là số nguyên VND > 0, thời lượng 60/120/180/240/360/480 phút".
- same file, S20: append to **Dữ liệu** "Tài liệu `availability/{uid}/days/{yyyy-MM-dd}` (không có = rảnh); nhiếp ảnh gia chỉ tạo/xoá `off`; `booked`/`pending` do máy chủ ghi kèm `bookingId`/`eventId`"; replace the **Bố cục** item "danh sách booking/sự kiện trong ngày (`BookingCard`/`EventCard`)" with "khung ngày đã chọn: trạng thái, nút "Đánh dấu nghỉ"/"Bỏ nghỉ", hoặc liên kết "Xem lịch hẹn" (`/b/{id}`) / "Quản lý sự kiện" (S27) — danh sách `BookingCard` của ngày thêm ở bước 5 khi có dữ liệu booking"; append to **Tương tác** "Chọn khoảng: nhấn giữ ngày đầu rồi chạm ngày cuối (thay cho kéo); tháng xem được từ tháng này tới 12 tháng sau".
- `docs/superpowers/specs/components/shared-components.md`, AvailabilityCalendar: replace the constructor line with `AvailabilityCalendar({required DateTime month, required Map<DateTime, DayState> states, DateTime? selected, ValueChanged<DateTime>? onSelect, ValueChanged<DateTime>? onLongPress, bool editable = false, ValueChanged<DateTime>? onMonthChanged, DateTime? minDate, DateTime? maxDate, DateTime? today, Set<DateTime> eventDays = const {}, DateTime? rangeStart, bool showHeader = true})` and append "Ngày là ngày lịch (UTC 00:00, khoá `yyyy-MM-dd`). Ô cao 44dp, rộng bằng 1/7 hàng (≈ 41dp ở 320dp). `AvailabilityLegend` hiện bốn trạng thái kèm chữ. Đã có trong code (kế hoạch 2d1)."

- [ ] **Step 4: Run the whole suite**

Run: `flutter analyze && flutter test`
Expected: analyze clean; every test passes, old and new. If an older test that pumps `ProfileTab` as a photographer fails with a pending timer, it is missing the `photographerIntroRepositoryProvider` override or `retry: (_, _) => null`; add both there.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib test ../docs/superpowers/specs
git commit -m "feat(shell): setup card and calendar entry; align S20/S24 specs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Battery and performance check (moved)

Moved to `docs/superpowers/plans/2026-10-02-final-battery-performance.md` (section "2026-10-01-step2d1-photographer-setup-calendar.md"). Nothing to do here.
