# Final battery and performance pass

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Run this plan once, after every feature plan is done.

**Goal:** All battery, idle, blur-budget, image-memory, read-cost and performance checks that used to sit at the end of each plan, run once over the finished app, plus one device build and profiling run (Genymotion / real phone).

**How to use:** each section below is the former last task of a plan, moved here unchanged (file paths and APIs may have moved since; adapt to the code as it is). Run them as tasks in this order, then Task Z. This plan runs after the iOS enablement plan, which itself runs after all feature plans.

## From 2026-10-01-step2c-skills.md

#### Former task 14: Battery and performance check

**Files:**
- Create: `test/battery/skills_battery_test.dart`
- Reference (written by the screen-codes plan, iOS section by the iOS-enablement plan; do not rewrite): `docs/testing/battery-and-performance.md`

**Interfaces:**
- Consumes: `expectIdle` (`test/support/idle.dart`), `expectBlurBudget` (`test/support/blur.dart`), `skillsApp`, `SkillsWorld`, `fixturePost`, `skillsControllerProvider`, `ownPostsProvider`.
- Produces: no production code unless a check fails (then fix the code, keep the test).

What is checked: S38/S39 and S40 schedule no frames at rest (no ticker, no repeating timer, no blinking caret because nothing autofocuses); S38 has exactly one blur (the completeness `GlassCard`) and S40 open adds only the sheet's frame (two in total, budget 4), none inside a chip, level row or grid tile; one skills read per visit and no polling; the evidence grid is lazy and decodes at tile size (Task 9 tests); providers die when the screen closes; the skills code has no listener or timer.

- [ ] **Step 1: Write the tests**

```dart
// test/battery/skills_battery_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/skills/own_posts_controller.dart';
import 'package:photobooking/features/skills/skills_controller.dart';

import '../support/blur.dart';
import '../support/content_fixtures.dart';
import '../support/idle.dart';
import '../support/skills_app.dart';
import '../support/skills_world.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<SkillsWorld> _world() => SkillsWorld.create(posts: (uid) => [
  for (var i = 0; i < 40; i++) fixturePost('m$i', photographerId: uid, age: Duration(minutes: i + 1)),
]);

void main() {
  testWidgets('S38/S39: idle at rest and after edits; one blur; one read', (tester) async {
    _phone(tester);
    final w = await _world();
    await tester.pumpWidget(skillsApp(w, initialLocation: '/setup/3'));
    await expectIdle(tester);
    expectBlurBudget(max: 1);
    await tester.ensureVisible(find.byKey(const Key('specialty-portrait')));
    await tester.tap(find.byKey(const Key('specialty-portrait')));
    await expectIdle(tester);
    final basic = find.descendant(of: find.byKey(const Key('level-portrait')), matching: find.text('Cơ bản'));
    await tester.ensureVisible(basic);
    await tester.tap(basic);
    FocusManager.instance.primaryFocus?.unfocus();
    await expectIdle(tester);
    expect(find.descendant(of: find.byType(SkillChip), matching: find.byType(BackdropFilter)), findsNothing);
    expect(find.descendant(of: find.byType(LevelSelector), matching: find.byType(BackdropFilter)), findsNothing);
    expect(w.skills.loadCalls, 1, reason: 'one read per visit, no polling');
  });

  testWidgets('S40 open: idle, sheet frame is the only extra blur, no blur in tiles', (tester) async {
    _phone(tester);
    final w = await _world();
    await tester.pumpWidget(skillsApp(w, initialLocation: '/setup/3'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('specialty-portrait')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('evidence-edit-portrait')));
    await tester.tap(find.byKey(const Key('evidence-edit-portrait')));
    await expectIdle(tester);
    expectBlurBudget(max: 2);
    expect(find.descendant(of: find.byType(EvidencePicker), matching: find.byType(BackdropFilter)), findsNothing);
    await tester.tap(find.byKey(const Key('evidence-m0')));
    await expectIdle(tester);
  });

  testWidgets('closing S40 and S38 disposes their providers', (tester) async {
    _phone(tester);
    final w = await _world();
    await tester.pumpWidget(skillsApp(w, initialLocation: '/start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open skills'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('specialty-portrait')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('evidence-edit-portrait')));
    await tester.tap(find.byKey(const Key('evidence-edit-portrait')));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
      listen: false,
    );
    expect(container.exists(ownPostsProvider), isTrue);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(container.exists(ownPostsProvider), isFalse, reason: 'sheet closed');
    await tester.tap(find.byKey(const Key('specialty-portrait')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('open skills'), findsOneWidget);
    expect(container.exists(skillsControllerProvider), isFalse, reason: 'screen closed');
  });

  test('the skills code opens no listener and runs no timer', () {
    for (final dir in ['lib/data/skills', 'lib/features/skills']) {
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
        final src = f.readAsStringSync();
        for (final banned in ['.snapshots(', 'Timer.periodic', 'Stream.periodic', 'AnimationController(']) {
          expect(src, isNot(contains(banned)), reason: '${f.path}: $banned');
        }
      }
    }
    expect(File('lib/data/skills/skills_repository.dart').readAsStringSync(), isNot(contains('Stream<')));
  });
}
```

(The third test ticks and unticks "Chân dung" so the draft equals what the screen opened with; Back then leaves without the confirmation sheet.)

- [ ] **Step 2: Run them**

Run: `flutter test test/battery/skills_battery_test.dart`
Expected: PASS. These are guard tests: they pass now and fail as soon as someone adds a running animation, a listener or extra blur. If `expectIdle` fails, set `debugPrintScheduleFrameStacks = true;` at the start of the test to see who scheduled the frame and fix that code (a `SnackBar` is not shown in these tests; a focused text field would blink, so nothing may autofocus). If `container.exists` is not available in the pinned Riverpod version, use `container.getAllProviderElements().any((e) => e.origin == skillsControllerProvider)` instead.

- [ ] **Step 3: Run the whole suite**

Run: `dart format lib test && flutter analyze && flutter test`
Expected: analyze clean; every test passes.

- [ ] **Step 4: Manual profiling on real devices**

Follow `docs/testing/battery-and-performance.md` on a mid-range Android phone in profile mode (Genymotion is fine for the frame checks, battery numbers need a real phone), and its iOS section on an iPhone (profile build from Xcode; if the iOS-enablement plan has not run yet, record "iOS: pending iOS enablement" in the PR and do the Android part). Record the result table from that document in the PR description. Any value over a threshold blocks the merge: fix it in this plan's code, add a test that would have caught it, and re-measure.

Screens and scenario:
1. Idle frames and CPU: S38 at `/setup/3` with three genres chosen (30 seconds untouched); S38 scrolled to the S39 part; S40 open with at least 30 posts in the grid.
2. Scroll: fling the S40 grid of 40+ posts to the end and back three times (Android `gfxinfo` janky < 5%, p90 ≤ 16 ms; iOS Animation Hitches as the guide says). The photos must come from the cache on the second pass (no new network requests in DevTools Network).
3. Battery (10 minutes): open `/profile/skills`, tick and untick genres, set levels, open S40 and pick photos twice, save, leave, then keep the app idle on the profile. Check: no wake lock; no Firestore listener left after leaving (DevTools Network shows no open `Listen` channel for `photographers`; only one `get` of `photographers/{uid}` per visit and one write per save).
4. Memory: PSS after scrolling S40 (< 250 MB on Android); on iOS the Allocations total stays flat after closing S40 three times.

- [ ] **Step 5: Commit**

```bash
git add test/battery/skills_battery_test.dart
git commit -m "test(skills): battery guards for S38/S39/S40

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:**
  - 3e.1 structured data: every value is a catalogue id with a Vietnamese label (Task 1); labels change without touching data.
  - 3e.2 limits: 6 genres, 3 "Chuyên sâu", level 3 needs ≥ 1 evidence, 1–3 evidence posts, styles ≤ 4, extras ≤ 8, audiences ≤ 4, ≥ 1 language, years 0–50 — pure validation and edits (Task 3), the controller and screen messages (Tasks 10, 12), Firestore rules (Task 6). Completeness with the exact weights and a next-step hint (Task 4, shown by `CompletenessMeter` in Tasks 7 and 12). Retired catalogue items stay on old profiles but cannot be chosen (Tasks 1, 3). Draft saved on every change, asked on exit (Tasks 10, 12).
  - 3e.3 data shape `photographers/{uid}.skills {schemaVersion, specialties[{id, level, years?, evidencePostIds}], styles, extras, languages, audiences, yearsExperience}` (Task 2), written with a merge that keeps the server's `completeness` (Task 5); public read already allowed; only the owner writes; rules check ids, limits and level-3 evidence and forbid client writes to `completeness`/`skills.updatedAt` (Task 6).
  - 3e.6 inputs for `rules-v1`: the levels (1/2/3), the "level 3 without evidence" state, `audiences` and `extras` are stored exactly as the scorer reads them (Task 2); plan 3b1's `photographerSummaryFrom` already reads `skills.specialties[].id` and `skills.styles`.
  - 3e.9: no change; the skills feed S01/S03/S04 through the recommender plans.
  - §4 widgets `SkillChip`, `LevelSelector` (arrow keys, "Chân dung, mức Chuyên sâu"), `EvidencePicker`, `CompletenessMeter` (Tasks 7–9); `SegmentedTabs` look reused inside `LevelSelector`.
  - §5 / photographer.md: S38 (step 3/4, intro, meter, "n / 6", level rows with default "Thành thạo", "Chuyên sâu tối đa 3", evidence rows with "Chỉnh", yellow warning and blocked "Tiếp tục", "Tối đa 6 thể loại", 4th expert refused keeping the old level, no genre → button off, unticking a genre with evidence asks); S39 (styles, extras, languages, audiences, years; "Chọn ít nhất 1 ngôn ngữ" on "Tiếp tục" with scroll to the section); S40 (title "Minh chứng · {name}", "n / 3", body text, 3-column own posts, "Xong" blocked for level 3 without a photo, empty "Đăng bài trước" leading to S21, deleted posts removed from evidence). Routes `/setup/3`, `/profile/skills`, `/profile/skills/evidence?skill=…`; "Tiếp tục" pushes `/setup/4`; edit mode returns to the profile (Task 12). Analytics `skills_save{specialties, expert}`, `skills_step{n}`, `skill_evidence_set{skillId, count}`, `screen_view{code}` through a callback provider.
  - §7: validation tests for limits, unknown ids and level 3 without evidence (Task 3 table, Task 6 rules tests).
  - **Not covered on purpose:** reading `taxonomy/skills` from Firestore / Remote Config (the provider is the seam; built-in list today), the `onPhotographerWrite` Function (completeness, evidence ownership, recommender re-index — backend plan), the "Kỹ năng" row on the profile and S03's skill display and evidence badges (plan 2d, through `photographerSkillsProvider` and `PhotographerSkills.evidencePostIds`), S22's "Hoàn thiện kỹ năng" rule (step 5), per-genre years in the UI (kept in data, not edited), a role guard on the routes (no route in the app has one yet; rules already refuse writes from non-photographers).
- **Deviations from the spec, all written back in Task 13:** the draft is autosaved on the device, not in Firestore (Firestore only ever holds valid skills, which lets the rules be strict); completeness is computed on the device until the Function exists; ids are unique per group (`couple` is both a genre and an audience in the seed list) and the data-model open question is recorded; evidence ownership is enforced by the picker and the future Function, not by rules (rules' 10-read limit); `LevelSelector` draws its own segments; the evidence limit message is shown inside the sheet instead of a `SnackBar`; a new photographer starts with "Tiếng Việt" ticked.
- **Placeholders:** none; every step has the full code or the exact text to insert.
- **Type consistency:** `SkillGroup`, `TaxonomyItem`, `TaxonomyCatalog`, `builtInSkillCatalog`, `SkillLevels`, `SkillLimits`, `SpecialtySkill`, `PhotographerSkills`, `skillsToMap`/`skillsFromMap`, `SkillIssue(Code)`, `SkillEdit(Rejection)`, `with*` edit functions, `CompletenessStep`/`Hint`/`Report`, `SkillsRepository`/`FakeSkillsRepository` (`seed`, `stored`, `loadCalls`, `saveCalls`, `failLoadWith`, `failSaveWith`), `skillsRepositoryProvider`, `skillCatalogProvider`, `photographerSkillsProvider`, `SkillsDraftStore.keyFor`, `SkillsEditorState` (`dirty`, `unsaved`, `canSubmit`, `hasIssue`), `SkillsController` methods, `OwnPostsController.pageSize`, `showEvidenceSheet`, `SkillsMode`, `SkillsScreen(mode, openEvidenceFor)` and the widget keys are spelled the same in code, tests and the Interfaces section.
- **Risks to watch:** the long rules expression (Task 6 Step 4 says how to split it if the emulator hits a limit); `fake_cloud_firestore` deep-merge behaviour (Task 5 Step 4); `retry:` on `autoDispose` providers and `ProviderContainer.exists` in the pinned Riverpod 3 version (fallbacks given in Tasks 10 and 14); plan 3a2 must not be re-run after this plan, since it would overwrite `builtin_taxonomy.dart` without `kExtras`/`kLanguages`/`kAudiences` (it runs before this plan in the stated order); plan 2d must register `/setup/1` and `/setup/2` as literal paths (or put a `/setup/:step` route after the literal ones) so it does not shadow `/setup/3`.
- **Battery and performance (Task 14):** idle tests for S38/S39 at rest and after edits and for S40 open; blur budget measured (1 on S38, 2 with S40) with no blur inside chips, level rows or grid tiles; one read per visit and no listeners or timers anywhere in the skills code (source check); every provider `autoDispose` without retry and proven disposed when S40 and S38 close; evidence grid lazy with tile-size decoding (Task 9); manual Android and iOS profiling per `docs/testing/battery-and-performance.md` recorded in the PR.

## From 2026-10-02-mock-parity-1.md

#### Former task 12: Battery and performance check
Files: `test/battery/mock_parity_battery_test.dart`, `docs/testing/battery-and-performance.md`.
- [ ] Idle check (`expectIdle`) and blur budget (`expectBlurBudget(max: 4)`) for S13, S35, S36, S34, S42 after the changes; `AppOptionTile` and the new button sizes add no BackdropFilter or ticker. Append a short section to the guide ("device profiling pending").

## From 2026-10-01-step2d1-photographer-setup-calendar.md

#### Former task 10: Battery and performance check

**Files:**
- Create: `test/battery/photographer_setup_battery_test.dart`
- Reference (do not rewrite): `test/support/idle.dart` (screen-codes plan), `test/support/blur.dart` (3a1), `docs/testing/battery-and-performance.md` (Android and iOS sections)

**Interfaces:**
- Consumes: `expectIdle`, `expectBlurBudget`, `PhotographerWorld`, `MyCalendarScreen.debugBuildCount`, the fakes' `watchers`.
- Produces: no production code; a test file that fails if any S24/S20 screen keeps scheduling frames at rest, uses more than 4 `BackdropFilter`s, keeps a Firestore listener after it closes, opens a second month listener, or rebuilds the S20 shell on a month switch; and a static check for timers and animation controllers in this plan's code.

- [ ] **Step 1: Write the tests**

```dart
// test/battery/photographer_setup_battery_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/service_package.dart';
import 'package:photobooking/features/calendar/my_calendar_screen.dart';
import 'package:photobooking/features/photographer_setup/setup_intro_screen.dart';
import 'package:photobooking/features/photographer_setup/setup_packages_screen.dart';

import '../support/blur.dart';
import '../support/idle.dart';
import '../support/photographer_world.dart';

final _routes = <RouteBase>[
  GoRoute(path: '/setup/1', builder: (_, _) => const SetupIntroScreen()),
  GoRoute(path: '/setup/2', builder: (_, _) => const SetupPackagesScreen()),
  GoRoute(path: '/work/calendar', builder: (_, _) => const MyCalendarScreen()),
];

Future<PhotographerWorld> _world() async {
  final w = PhotographerWorld();
  await w.init();
  w.packages.seed(w.uid, const ServicePackage(id: 'a', name: 'Chân dung 2 giờ', priceVnd: 1500000, durationMinutes: 120));
  w.availability.seed(w.uid, AvailabilityDay(day: DateTime.utc(2026, 10, 10), state: DayState.booked, bookingId: 'b1'));
  return w;
}

Future<void> _settleSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('S24 step 1 is idle at rest and after typing', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/1', routes: _routes));
    await tester.pumpAndSettle();
    await expectIdle(tester);
    expectBlurBudget();
    await tester.enterText(find.byKey(const Key('setup-bio')), 'Ánh sáng tự nhiên.');
    FocusManager.instance.primaryFocus?.unfocus();
    await expectIdle(tester);
  });

  testWidgets('S24 step 2 listens to the packages only while open; the sheet stays in budget', (tester) async {
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/setup/2', routes: _routes));
    await tester.pumpAndSettle();
    expect(w.packages.watchers, 1);
    await expectIdle(tester);
    expectBlurBudget();
    await tester.tap(find.byKey(const Key('package-hide-a')));
    await tester.pumpAndSettle();
    expectBlurBudget();
    await tester.tap(find.byKey(const Key('package-hide-keep')));
    await tester.pumpAndSettle();
    w.router.go('/home');
    await tester.pumpAndSettle();
    expect(w.packages.watchers, 0);
  });

  testWidgets('S20: one month listener, idle, no shell rebuild on month switch, closed on leave', (tester) async {
    final h = tester.ensureSemantics();
    final w = await _world();
    await tester.pumpWidget(w.app(location: '/work/calendar', routes: _routes));
    await tester.pumpAndSettle();
    expect(w.availability.watchers, 1);
    await expectIdle(tester);
    expectBlurBudget();
    final builds = MyCalendarScreen.debugBuildCount;
    for (final m in ['Tháng 11', 'Tháng 12', 'Tháng 11']) {
      await tester.tap(find.text(m));
      await tester.pumpAndSettle();
      expect(w.availability.watchers, 1);
    }
    expect(MyCalendarScreen.debugBuildCount, builds);
    await tester.tap(find.text('Tháng 10'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('13 tháng 10, rảnh'));
    await _settleSnackBars(tester);
    await expectIdle(tester);
    w.router.go('/home');
    await tester.pumpAndSettle();
    expect(w.availability.watchers, 0);
    h.dispose();
  });

  test('no timers, periodic streams or animation controllers in this plan', () {
    final files = [
      ...Directory('lib/features/photographer_setup').listSync(recursive: true),
      ...Directory('lib/features/calendar').listSync(recursive: true),
      File('lib/core/widgets/availability_calendar.dart'),
      File('lib/core/calendar_days.dart'),
      File('lib/core/vnd_input.dart'),
    ].whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final banned in ['Timer(', 'Timer.periodic', 'Stream.periodic', 'AnimationController']) {
        expect(src, isNot(contains(banned)), reason: '${f.path} uses $banned');
      }
    }
  });

  test('the Firestore adapters are the only Firebase importers of this plan', () {
    final offenders = [
      ...Directory('lib/features/photographer_setup').listSync(recursive: true),
      ...Directory('lib/features/calendar').listSync(recursive: true),
      File('lib/data/photographer/availability_repository.dart'),
      File('lib/data/photographer/photographer_intro.dart'),
      File('lib/data/photographer/service_package.dart'),
      File('lib/data/photographer/availability_providers.dart'),
      File('lib/data/photographer/photographer_setup_providers.dart'),
    ].whereType<File>().where((f) => f.readAsStringSync().contains('package:cloud_firestore/'));
    expect(offenders.map((f) => f.path), isEmpty);
  });
}
```

- [ ] **Step 2: Run them**

Run: `flutter test test/battery/photographer_setup_battery_test.dart`
Expected: PASS. If one fails, fix this plan's code (never the threshold): a leftover listener means a provider is not `autoDispose` or the screen watches it from a long-lived widget; a shell rebuild on month switch means something in `_MyCalendarScreenState.build` watches the month provider; a frame at rest means an indeterminate progress indicator or a snackbar is still animating (pump it away first, as `_settleSnackBars` does).

- [ ] **Step 3: Run the whole suite**

Run: `flutter analyze && flutter test`
Expected: analyze clean, all tests pass.

- [ ] **Step 4: Manual profiling on real devices (Android and iOS)**

Follow `docs/testing/battery-and-performance.md` for these screens: S24 step 1, S24 step 2 (with the hide sheet open once), S20 (switch months five times, mark and undo three days, one range). Android: a real phone in `--profile` mode for frames, CPU at rest, wake locks and memory (Genymotion is fine for the frame checks only). iOS: the iOS section of the guide (Instruments: Animation Hitches, Energy Log, Allocations) on a real iPhone; if iOS still cannot be built on this machine, record "iOS: not measured, blocked by iOS enablement" in the PR. Battery scenario (10 minutes): finish steps 1 and 2 with two packages, open S20, mark a week off with a range, undo it, then leave the app idle on S20 for the rest of the time. Also check in DevTools (Performance → "Highlight repaints") that tapping a day repaints only the calendar grid and the day panel, and that switching months does not repaint the app bar. Record the filled-in result table in the PR description; any value over a threshold blocks the merge: fix it here, add a test that would have caught it, and re-measure.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add test/battery/photographer_setup_battery_test.dart
git commit -m "test(perf): idle, listener and rebuild guards for S24 and S20

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** S24 step 1 (name, bio ≤ 300, equipment ≤ 8) with device draft and resume at the saved step (Tasks 6, 9); S24 step 2 package list and form (name, price in whole VND > 0, duration from 1/2/3/4/6/8 h, edited photos, delivery days), "≥ 1 gói mới sang bước 3", add/edit/hide with a red confirmation inside a sheet, draft of the half-filled form (Task 7); `StepProgress` n/4 on both steps; packages repository with rules on values (Tasks 4, 5); S20 month grid with the four states, legend, "Đánh dấu nghỉ", snackbar + "Hoàn tác", booked/pending read-only with "Ngày này đã có lịch", past days read-only, range without dragging, event days → S27 (Tasks 2, 8); availability repository and rules (`off` only from the client, server owns `booked`/`pending`; read for every signed-in user as 3b3 expects) (Tasks 3, 5); `AvailabilityCalendar` ready for S03 and S06 (editable vs booking mode, 44dp cells, semantics, swipe + arrows) (Task 2); "Chưa xong thì không đổi được vai trò" interpreted as: switching to photographer opens the setup until `onboardingComplete` (the role itself has to switch first because rules only let a photographer write `photographers/{uid}`) (Task 9).
- **Deviations (flagged):** (1) specialties and years of experience are not asked in step 1: S38/S39 (plan 2c) own them in `photographers/{uid}.skills` (`skills.yearsExperience` is the one source of truth; S03 in plan 2d2 reads years from `PhotographerSkills`), and writing years earlier through `SkillsRepository` would be refused by 2c's rules (a `skills` map needs 1–6 genres); (2) avatar comes with plan 2d2 and the cover photo with a later media plan (the rules do not allow `coverUrl` on `photographers/{uid}` yet; S03 falls back to the avatar for its hero); (3) "thoát giữa chừng hỏi lưu nháp" became "never lose anything" (automatic device draft, no question), which removes a dialog without losing data; (4) S20 shows a day panel with links instead of the `BookingCard`/`EventCard` list, which needs booking read models from step 4/5; (5) S20 cannot go to past months (they are read-only and would only add listeners); the three month tabs slide inside "this month … +12"; (6) analytics `calendar_off{count}` is not sent: there is no analytics port yet (2c's `skillsAnalyticsProvider` is specific to skills); (7) the legacy top-level `photographers/{uid}.yearsExperience` that `photographerClientFields()` still allows is never written by this plan.
- **Cross-plan expectations:** `/setup/3` (2c) and `/setup/4` (2b) are separate literal routes; `/b/:id` (step 4) and `/events/:id/manage` (events plan) are linked by path only; the server (step 4 `transitionBooking`, events) must write `availability/{uid}/days/{yyyy-MM-dd}` with `state` `pending`/`booked` and `bookingId`/`eventId`, and must refuse a booking on an `off` day (`day_taken`); `startingPrice` (min active package price) is computed by `onPhotographerWrite`, not by this plan; plan 3c's "Thêm gói" pushes `/setup/2` (registered here); plan 3b3's `AvailabilityLookup` reads the same documents (its `DayAvailability` and this plan's `DayState` share the codes; 3b3 may map to `DayState` later); plan 3c finds `lib/core/ulid.dart` already present if Task 1 added it, and must not add it twice; 2c's "Quay lại" on `/setup/3` goes back to (or to) `/setup/2`, registered here; step 5 (S19) keeps the `open-calendar` entry when it replaces `BookingsTab`.
- **Placeholders:** none. Every conditional step (the borrowed ULID file, `screen_codes_applied_test.dart`) names the exact check and the exact code to use.
- **Type consistency:** `DayState`, `AvailabilityDay`, `AvailabilityMonth`, `availabilityMonthProvider`, `calendarTodayProvider`, `PhotographerIntro`, `ServicePackage`/`ServicePackageInput`, `packageToFirestore` (same shape as 3b1's `serviceFromFirestore`), `SetupDraftStore`/`IntroDraft`/`PackageDraft`, `setupResumePath`, `photographerOnlyRedirect`, `validateIntro`/`IntroResult`, `validatePackage`/`PackageCheck`, `freeDaysBetween`, `monthWindow`, `MyCalendarScreen.debugBuildCount` and every widget key are spelled the same in tests and code.
- **Risks:** (a) calendar cells are 44dp tall but only ≈ 41dp wide at 320dp (7 columns), slightly under the 44dp rule; the whole cell is the target with no gaps, and widening is impossible without dropping a column; (b) Firestore rule `string.size()` counts characters while Dart `length` counts UTF-16 units; for Vietnamese (precomposed) they agree, a decomposed paste could differ by a few characters near 300; (c) the snackbar "Hoàn tác" depends on the SDK's action-snackbar timing (`persist`); the tests do not rely on auto-hide; (d) `orderBy(FieldPath.documentId).startAt/endAt` on a subcollection is a supported query, but is only exercised against the emulator by the manual run (there is no `fake_cloud_firestore` here); the rules tests and the fake contract cover the rest.
- **Battery and performance:** Task 10 checks idle frames on S24 1/2 and S20, the blur budget (≤ 4, sheet included), listener release on leaving (packages, availability), one month listener at a time, no shell rebuild on month switch, no timers/animation controllers, Firebase isolation; Step 4 is the manual Android and iOS profiling per `docs/testing/battery-and-performance.md`. The only long-lived listener added is `myIntroProvider` (own profile on S30), which the guide allows.

## From 2026-10-01-step2d2-photographer-profile.md

#### Former task 8: Spec alignment, battery and performance check

**Files:**
- Create: `test/battery/photographer_profile_battery_test.dart`
- Modify: `docs/superpowers/specs/screens/discovery.md`, `docs/superpowers/specs/screens/account.md`, `docs/superpowers/specs/components/shared-components.md`
- Reference (do not rewrite): `test/support/idle.dart`, `test/support/blur.dart`, `docs/testing/battery-and-performance.md`

**Interfaces:**
- Consumes: `ProfileWorld`, `expectIdle`, `expectBlurBudget`, the fakes' `watchers`/`loads`, `ImageBackdrop`.
- Produces: no production code; tests that fail if S03 keeps scheduling frames at rest, exceeds the blur budget (sheet included), blurs inside the scroll view or with a `BackdropFilter`, builds off-screen portfolio tiles, keeps the availability listener after leaving the tab or the screen, or if this plan's code uses timers or animation controllers; and the spec text below.

- [ ] **Step 1: Write the tests**

```dart
// test/battery/photographer_profile_battery_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';
import 'package:photobooking/data/photographer/public_profile.dart';
import 'package:photobooking/data/user/user_profile.dart';

import '../support/blur.dart';
import '../support/content_fixtures.dart';
import '../support/idle.dart';
import '../support/profile_world.dart';

void main() {
  testWidgets('S03 is idle on every tab and stays in the blur budget', (tester) async {
    usePhoneFor(tester);
    final w = ProfileWorld();
    await w.init();
    w.profiles.add(PhotographerProfile(
      summary: fixturePhotographer('p1', name: 'Minh Trí', verified: true, coverUrl: 'https://img.test/cover.jpg'),
      intro: const PhotographerIntro(onboardingComplete: true),
    ));
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    await expectIdle(tester);
    expectBlurBudget();
    for (final tab in ['Gói', 'Lịch', 'Đánh giá', 'Portfolio']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      await expectIdle(tester);
      expectBlurBudget();
    }
  });

  testWidgets('the hero blur sits behind the scroll view, never inside it, and is not a BackdropFilter', (tester) async {
    usePhoneFor(tester, height: 844);
    final w = ProfileWorld();
    await w.init();
    w.profiles.add(PhotographerProfile(
      summary: fixturePhotographer('p1', coverUrl: 'https://img.test/cover.jpg'),
      intro: const PhotographerIntro(onboardingComplete: true),
    ));
    await tester.pumpWidget(w.app('/u/p1'));
    await tester.pumpAndSettle();
    expect(find.byType(ImageBackdrop), findsOneWidget);
    expect(find.descendant(of: find.byType(CustomScrollView), matching: find.byType(ImageFiltered)), findsNothing);
    expect(find.descendant(of: find.byType(ImageBackdrop), matching: find.byType(BackdropFilter)), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('image-backdrop-layer')), findsOneWidget);
  });

  testWidgets('the owner sheet keeps the budget', (tester) async {
    usePhoneFor(tester);
    final w = ProfileWorld(role: UserRole.photographer);
    await w.init();
    w.profiles.add(PhotographerProfile(summary: fixturePhotographer(w.uid), intro: const PhotographerIntro()));
    await tester.pumpWidget(w.app('/u/${w.uid}'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-edit')));
    await tester.pumpAndSettle();
    expectBlurBudget();
    await expectIdle(tester);
  });

  testWidgets('the portfolio builds only what is on screen', (tester) async {
    usePhoneFor(tester, height: 700);
    final w = ProfileWorld();
    await w.init();
    for (var i = 0; i < 20; i++) {
      w.discovery.posts.add(fixturePost('m$i', photographerId: 'p9', age: Duration(minutes: i + 1)));
    }
    w.profiles.add(PhotographerProfile(summary: fixturePhotographer('p9'), intro: const PhotographerIntro(onboardingComplete: true)));
    await tester.pumpWidget(w.app('/u/p9'));
    await tester.pumpAndSettle();
    final built = find.byWidgetPredicate((widget) {
      final k = widget.key;
      return k is ValueKey<String> && k.value.startsWith('portfolio-m');
    });
    expect(built.evaluate().length, lessThan(12), reason: '20 posts loaded, only the visible rows built');
  });

  testWidgets('the availability listener lives only while the calendar tab is shown', (tester) async {
    usePhoneFor(tester);
    final w = ProfileWorld();
    await w.init();
    await tester.pumpWidget(w.app('/u/p1?tab=calendar'));
    await tester.pumpAndSettle();
    expect(w.availability.watchers, 1);
    await tester.fling(find.byType(AvailabilityCalendar), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(w.availability.watchers, 1, reason: 'one month at a time');
    w.router.go('/home');
    await tester.pumpAndSettle();
    expect(w.availability.watchers, 0);
  });

  test('no timers, periodic streams or animation controllers in this plan', () {
    final files = [
      ...Directory('lib/features/photographer_profile').listSync(recursive: true),
      File('lib/core/widgets/image_backdrop.dart'),
      File('lib/features/settings/avatar_controller.dart'),
      File('lib/features/settings/avatar_editor.dart'),
    ].whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final banned in ['Timer(', 'Timer.periodic', 'Stream.periodic', 'AnimationController', 'BackdropFilter']) {
        expect(src, isNot(contains(banned)), reason: '${f.path} uses $banned');
      }
    }
  });
}
```

- [ ] **Step 2: Run them**

Run: `flutter test test/battery/photographer_profile_battery_test.dart`
Expected: PASS. If the idle check fails on the first frame, `AppSkeleton` may still pulse because a provider has not resolved: make sure every provider of the screen is overridden in `ProfileWorld` (a real Firestore provider never resolves in tests). Fix the code, never the threshold.

- [ ] **Step 3: Align the specs (write exactly this)**

- `docs/superpowers/specs/screens/discovery.md`, S03: set **Thông tin** to "`/u/:uid` · cả hai · sub‑project 2 · **Đã có** (kế hoạch 2d2)"; append to **Bố cục** "Bản đầu: chưa có nút chia sẻ (chưa có tên miền liên kết); portfolio là lưới vuông 2 cột (masonry để sau); hàng huy hiệu ẩn cho tới bước 6 (chưa có `BadgeChip`); ảnh minh chứng kỹ năng có dấu nhỏ trên ô; số năm kinh nghiệm lấy từ `skills.yearsExperience` (S39)"; append to **Dữ liệu** "Đọc một lần (`users/{uid}` + `photographers/{uid}`), không giữ listener; tab Lịch chỉ nghe tháng đang xem; "Nhắn tin hỏi trước" mở `/u/{uid}/ask` (bước 4 tạo hoặc mở chat `inquiry` rồi thay bằng `/chat/:chatId`)"; append to **Trạng thái** "Lỗi tải → "Không tải được hồ sơ." + Thử lại; không có hồ sơ → "Không tìm thấy hồ sơ.""
- `docs/superpowers/specs/screens/account.md`, S30: append to **Hành vi hiện tại** "Đã thêm (kế hoạch 2d1/2d2): thẻ "Hoàn thiện hồ sơ nhiếp ảnh gia" khi chưa xong thiết lập; hàng "Số điện thoại" (→ S33, không hiện trạng thái để không giữ listener dữ liệu riêng), với NAG "Kỹ năng" kèm `CompletenessMeter` và "Xem hồ sơ công khai"; ảnh đại diện dùng `AppAvatar`. Hàng huy hiệu chờ bước 6."; S42: append "Đã thêm "Đổi ảnh đại diện" (kế hoạch 2d2): chọn một ảnh từ thư viện, tải lên `avatars/{uid}/{ulid}.jpg`, `users/{uid}` lưu `avatarUrl` và `avatarPath`, xoá ảnh cũ; khung tròn cắt ảnh khi hiển thị (chưa có bước cắt ảnh riêng)."
- `docs/superpowers/specs/components/shared-components.md`, BlurScrim và ImageBackdrop: append to the `ImageBackdrop` bullet "Đã có trong code (kế hoạch 2d2): giải mã ảnh ở ¼ bề rộng, `ImageFiltered` (không `BackdropFilter`) trong `RepaintBoundary`, nằm sau `CustomScrollView`; bật tương phản cao → chỉ còn nền aurora. Chưa có nhánh máy yếu (`isLowRamDevice` cần plugin thông tin thiết bị)."

- [ ] **Step 4: Manual profiling on real devices (Android and iOS)**

Follow `docs/testing/battery-and-performance.md` for S03 (visitor, with a cover photo; owner), S30 and S42. Android: real phone, `--profile`: idle frames on S03 for 30 s, then scroll the portfolio to the end and back three times (Janky < 5 %, p90 ≤ 16 ms), CPU at rest, PSS after scrolling 60 portfolio photos (< 250 MB). In DevTools turn on "Highlight repaints" and check that scrolling S03 never repaints the blurred hero and that switching calendar months repaints only the calendar. iOS: the guide's iOS section on a real iPhone (Animation Hitches while scrolling, Energy Log at rest, Allocations after 60 photos); if iOS still cannot be built on this machine, record "iOS: not measured, blocked by iOS enablement". Battery scenario (10 minutes): open three profiles from Home, switch every tab, scroll each portfolio, open "Lịch" and change months, change the avatar once on S42, then leave the app idle on S30. Confirm no Firestore listener stays open after leaving S03 (DevTools Network: no open `Listen` channel for `availability`). Record the result table in the PR; any value over a threshold blocks the merge.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add test/battery/photographer_profile_battery_test.dart ../docs/superpowers/specs
git commit -m "test(perf): S03 idle, blur, lazy grid and listener guards; align specs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** S03 (spec §5, discovery.md): hero with `ImageBackdrop` (§1.2), avatar over the photo, name + `VerifiedMark` only when `verified` (§3d.1), genres · area, "Theo dõi", four `StatTile`s with "—" for unknown values, bio, `SegmentedTabs` Portfolio / Gói / Lịch / Đánh giá, read-only `AvailabilityCalendar`, reviews empty state, "Thợ ảnh tương tự" (§3e.9), evidence badge on portfolio photos (S40 acceptance), fixed bar with "Nhắn tin hỏi trước" (locked `ContactDial`, no external channels before booking, §3b.1) and "Đặt lịch · từ {giá}" through the S33 phone gate, "Nhiếp ảnh gia chưa đăng gói", unpublished profiles hidden from others, owner sees "Chỉnh sửa hồ sơ" → S24/S38/S42/S34 and the completeness meter, no phone number anywhere (test), the bar never covers content (`bottomNavigationBar`) (Tasks 1–4); S42 avatar change with immediate avatar-style button update (Tasks 5–6); S30 "Số điện thoại" → S33, "Kỹ năng" with `CompletenessMeter` → S38, "Xem hồ sơ công khai" → S03 (Task 7).
- **Deviations (flagged):** (1) no share button on S03 (no link domain; same choice as 3b4 for S02); (2) portfolio is a square 2-column grid, masonry later; (3) the badges row is hidden until step 6 builds `BadgeChip` (spec: "Chưa có huy hiệu → ẩn hàng"), so no placeholder; (4) `ImageBackdrop` has the high-contrast fallback but no low-RAM branch (needs a device-info plugin); (5) no crop step for the avatar: the circle crops on display and the file is uploaded at the picker's 2048 px; (6) the S30 phone row shows no "number saved" state, to avoid a shell-long listener on private data; (7) "Nhắn tin hỏi trước" pushes `/u/{uid}/ask`, a route step 4 must implement (open or create the `inquiry` chat, respecting `acceptInquiries`); (8) analytics events of S03 (`photographer_open`, `inquiry_open`, `book_start`, `profile_tab`) are not sent: no analytics port exists yet (2b logs `contact_tapped` through its own callback); (9) the starting price is computed on the device from active packages until `onPhotographerWrite` writes `startingPrice` for everyone.
- **Cross-plan expectations:** step 4 adds `book` and `ask` as children of `/u/:uid`; step 6 adds the badges row (S03, S30) and the reviews tab content; plan 2c's names are used as given by its "Interfaces for other plans" (`photographerSkillsProvider`, `skillCatalogProvider`, `skillsCompleteness(...).percent`, `CompletenessMeter`, `skillsLevel*` strings); 3c's Storage test "every other Storage path is closed" is edited to use `misc/…` because `avatars/` is now open; `ctaAvatarProvider` replaces the inline avatar logic of `main.dart`.
- **Placeholders:** none. The two "if a file is named differently" notes (2b's contact fakes, 3b1's stats field names) say exactly what to align and that the other plan's names win.
- **Type consistency:** `PhotographerProfile`, `PublicProfileRepository`, `photographerProfileProvider`, `ProfileSection`/`profileSectionFromQuery`, `inquiryPath`, `startingPriceOf`, `responseLabel`, `skillLevelLabel`, `PortfolioState`/`PortfolioController`/`portfolioProvider`, `profilePackagesProvider`, `similarPhotographersProvider`, `ProfileHeader`, `PortfolioSliver`, `ServicesSliver`, `CalendarSliver`, `ReviewsSliver`, `ProfileBottomBar`, `PhotographerProfileScreen`, `UserRepository.setAvatar`, `avatarControllerProvider`, `AvatarEditor`, `ctaAvatarProvider`, `ProfileWorld`, and every widget key are spelled the same in tests and code.
- **Risks:** (a) `NetworkImage` inside `ImageBackdrop` in widget tests resolves to the test HTTP client's 400 and falls back to the aurora through `errorBuilder`; if a test reports an image error, give `ProfileWorld` profiles without `coverUrl`/`avatarUrl` except where the test needs the hero; (b) `AsyncNotifierProvider.autoDispose.family` with a constructor argument is the Riverpod 3 form; if the installed version differs, use the generated-free form the other plans use for families; (c) the 4-tile stats row at 320dp relies on `StatTile`'s `FittedBox` (value and label shrink, never wrap); (d) Storage rules use `request.resource.size < 5 MB + 1`, the same boundary style as 3c.
- **Battery and performance:** Task 8 checks idle frames on every S03 tab and with the owner sheet, the blur budget, that the hero blur is outside the scroll view and not a `BackdropFilter`, lazy portfolio building, one availability listener released on leaving the tab and the screen, and no timers/animation controllers/`BackdropFilter` in this plan's code; Step 4 is the manual Android and iOS profiling per `docs/testing/battery-and-performance.md`, including "Highlight repaints" for the hero and the calendar month switch. S03 reads its data once (no listeners) except the calendar month; portfolio photos are decoded at tile size by `NetworkPhoto`; the hero is decoded at ¼ width.

## From 2026-10-01-step3b3-recommendations.md

#### Former task 6: Battery and performance check

**Files:**
- Create (if missing): `test/support/idle.dart`, `test/support/blur.dart`
- Create: `test/battery/recommendation_battery_test.dart`
- Reference (written by the screen-codes plan, do not rewrite): `docs/testing/battery-and-performance.md`

**Interfaces:**
- Consumes: `LocalRecommender`, `ResilientRecommendationRepository`, fakes, `recommendation_models.dart`.
- Produces: no production code. This plan adds no widget, so there is no `expectIdle` or blur test; the helpers are created if missing so later plans find them.

What is checked: the location privacy rule (no coordinates anywhere in the recommender types, no `LocationRepository` dependency), bounded reads, no listeners or timers, no retry loop, and a generous time budget for ranking the full candidate pool.

- [ ] **Step 1: Write the tests**

If `test/support/idle.dart` or `test/support/blur.dart` is missing, create it with exactly the code given in plan 3a1 Task 7.

```dart
// test/battery/recommendation_battery_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/local_recommender.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';

import '../support/content_fixtures.dart';

void main() {
  group('privacy and cost of what this layer asks for', () {
    final files = Directory('lib/data/recommendation')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    test('no coordinates in the query or the signals, and no location dependency', () {
      final models = File('lib/data/recommendation/recommendation_models.dart').readAsStringSync();
      for (final banned in ['latitude', 'longitude', 'double lat', 'double lng', 'LocationRepository', 'ApproxLocation']) {
        expect(models, isNot(contains(banned)), reason: banned);
      }
      final local = File('lib/data/recommendation/local_recommender.dart').readAsStringSync();
      expect(local, isNot(contains('LocationRepository')));
      expect(local, isNot(contains('ApproxLocation')));
    });

    test('no listener, timer, ticker or retry loop in the layer', () {
      expect(files, isNotEmpty);
      for (final f in files) {
        final src = f.readAsStringSync();
        for (final banned in ['.snapshots(', 'Timer.periodic', 'Stream<', 'StreamController', 'while (true)']) {
          expect(src, isNot(contains(banned)), reason: '${f.path}: $banned');
        }
      }
    });
  });

  test('ranking a full pool of 200 photographers is cheap', () async {
    final many = [
      for (var i = 0; i < 200; i++)
        fixturePhotographer('p${i.toString().padLeft(3, '0')}', reviews: i, rating: 3 + (i % 20) / 10, lat: 10.7 + i / 1000, lng: 106.7),
    ];
    final availability = FakeAvailabilityLookup();
    final r = LocalRecommender(
      posts: FakePostRepository(),
      photographers: FakePhotographerRepository(many),
      availability: availability,
      clock: () => fixtureNow,
    );
    final watch = Stopwatch()..start();
    final page = await r.recommendPhotographers(
      RecommendationQuery(date: DateTime.utc(2026, 10, 12), geohash6: 'w3gvk1', limit: 50),
    );
    watch.stop();
    expect(page.items, hasLength(50));
    expect(watch.elapsedMilliseconds, lessThan(500), reason: 'ranking 200 candidates is a few ms');
    expect(availability.requested.single.length, lessThanOrEqualTo(LocalRecommender.maxDatedCandidates));
  });

  test('a candidate pool request is capped at 200, posts at 50 and similar at the page cap', () async {
    final many = [for (var i = 0; i < 300; i++) fixturePhotographer('q$i')];
    final r = LocalRecommender(
      posts: FakePostRepository([for (var i = 0; i < 80; i++) fixturePost('m$i', age: Duration(minutes: i + 1))]),
      photographers: FakePhotographerRepository(many),
      availability: FakeAvailabilityLookup(),
      clock: () => fixtureNow,
    );
    expect((await r.recommendPhotographers(const RecommendationQuery(limit: 1000))).items.length, lessThanOrEqualTo(50));
    expect((await r.similar('q0', limit: 1000)).items.length, lessThanOrEqualTo(50));
    expect((await r.recommendPosts(const PostRecommendationQuery(limit: 1000))).items.length, lessThanOrEqualTo(50));
  });
}
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/battery/recommendation_battery_test.dart`
Expected: PASS (4 tests). A failure names the culprit: a coordinate type slipped into the query, a listener was added, or a read is no longer bounded; fix the code, not the test.

- [ ] **Step 3: Fix anything the run found**

Re-run Step 2 until green.

- [ ] **Step 4: Manual profiling**

Follow `docs/testing/battery-and-performance.md` (written by the screen-codes plan; do not rewrite it) once plan 3b4 puts Find on screen: (1) pick a date and search 10 times in a row on a mid-range device: ranking plus day reads must stay under 400 ms (the remote deadline's budget) with at most 60 day-document reads per search; (2) put the phone in airplane mode and confirm the fallback note appears only when a remote recommender is configured; (3) leave Find open for 5 minutes and confirm no background work.

- Android: mid-range device, `flutter run --profile`, DevTools Performance and Network.
- iOS: Xcode Instruments (Time Profiler, Network and Energy Log) on a real iPhone, or the Simulator's Debug Navigator gauges; Energy Impact must read "Low" at rest. Prerequisite: iOS cannot be built on this machine yet (no Xcode, no CocoaPods, no iOS Firebase configuration); that is a separate "iOS enablement" plan, so until it lands record "iOS: not measured, blocked by iOS enablement".

Record the results in the PR description with the table template of the guide; add the iOS rows with the iPhone model in the Thiết bị column and Energy Impact in place of the Android-only columns.

- [ ] **Step 5: Commit**

```bash
git add test/support test/battery
git commit -m "test: privacy and cost checks for the recommendation layer

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** §3e.4 port with `LocalRecommender` fallback and the 800 ms deadline (`ResilientRecommendationRepository`); §3e.5 query shape (`specialty`, `date`, `geohash6`, `budgetMax`, `limit`, `cursor`, `excludeIds`) and response shape (`requestId`, `algorithm`, `algorithmVersion`, `items[rank, score, reasons]`, `nextCursor`); §3e.6 reasons `skill_match`, `near`, `free_on_date`, `top_rated`, `fast_reply`, `new_talent` with Vietnamese texts, at most 3; Bayesian smoothing `m = 10`, `C = 4.3`; geo `exp(-d/8)`; "luôn có đường lui" and the S04 fallback note (`usedFallback`); §3e.9 integration points (S01 `recommendPosts`, S03 `similar`, S04 `recommendPhotographers` with sorts); §3e.7 signals (impression, click, inquiry, booking, no PII) and the `sendFeedback` best-effort contract; §7 one contract suite for Local and Remote (run here for `LocalRecommender` and the resilient wrapper; step 3r runs it for `RemoteRecommendationRepository`).
- **Deviations (flagged):** (1) `LocalRecommender` is the simplified "stars and distance" fallback of spec 3e.4, not a port of `rules-v1` (no style, audience, MMR diversity or A/B); it keeps the same output shape. (2) `budgetMax` is a hard filter locally (the spec's `price` component is soft); an unknown price passes. (3) Local `recommendPosts` reorders within one fetched page (free-in-14-days first) instead of ranking the whole catalogue. (4) The rating filter chip of S04 ("★ 4.5+") is applied by the Find screen on the returned items, because the API context has no `minRating`.
- **Placeholders:** none. **Type consistency:** `RecommendationQuery`/`RecommendationPage`/`RecommendedPhotographer`/`PostRecommendationQuery`/`PostRecommendationPage`/`RecommendedPost`/`RecommendationSignal`/`SignalType`, `RecommendationRepository` method names, `LocalRecommender` constructor, `DayAvailability`/`AvailabilityLookup.on(dayKey, ids)`, `recommendationRepositoryProvider`, `localRecommenderProvider`, `availabilityLookupProvider`, `recommendationRepositoryContract(name, factory)`/`RecommendationWorld`/`contractWorld()` are the names plans 3b4 and 3r use.
- **Battery and performance (Task 6):** no coordinates and no location dependency in the layer, no listeners, timers or retry loops, bounded reads (pool 200, dated reads 60, pages 50), a time budget for ranking 200 candidates, manual Android and iOS profiling table per `docs/testing/battery-and-performance.md`.
- **Risks:** reading 60 day documents per dated search is the main read cost until the recommender service takes over (step 3r); the `availability` rule must coexist with the calendar plan's owner write rules (Task 2 Step 3 note).

## From 2026-10-01-step3b4-home-detail-find.md

#### Former task 6: Battery and performance check

**Files:**
- Create (if missing): `test/support/idle.dart`, `test/support/blur.dart`
- Create: `test/battery/discovery_screens_battery_test.dart`
- Reference (written by the screen-codes plan, do not rewrite): `docs/testing/battery-and-performance.md`

**Interfaces:**
- Consumes: `expectIdle`, `expectBlurBudget`, `DiscoveryWorld`, `testPhotoScope`, the three screens.
- Produces: no production code (`FakePostEngagementRepository.readCalls`, added in plan 3b1, counts the reads).

What is checked: Home, Photo detail and Find leave the frame loop once loaded; no blur outside sheets; every photo is decoded at display size; long lists build only what is on screen; the screens never ask for location and share one fix; opening a screen costs a fixed, small number of reads; no stream or timer exists in these features.

- [ ] **Step 1: Write the tests**

If `test/support/idle.dart` or `test/support/blur.dart` is missing, create it with exactly the code given in plan 3a1 Task 7.

```dart
// test/battery/discovery_screens_battery_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/find/find_screen.dart';
import 'package:photobooking/features/home/home_screen.dart';
import 'package:photobooking/features/photo/photo_detail_screen.dart';

import '../support/blur.dart';
import '../support/content_fixtures.dart';
import '../support/discovery_world.dart';
import '../support/idle.dart';
import '../support/photo_scope.dart';
import '../support/screen_host.dart';

GoRouter _router(String start) => GoRouter(
  initialLocation: start,
  routes: [
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/find', builder: (_, _) => const FindPhotographerScreen()),
    GoRoute(path: '/p/:id', builder: (_, s) => PhotoDetailScreen(postId: s.pathParameters['id']!)),
    GoRoute(path: '/u/:id', builder: (_, _) => const Text('profile')),
  ],
);

Future<GoRouter> _open(WidgetTester tester, DiscoveryWorld w, String start) async {
  await w.init();
  final router = _router(start);
  await tester.pumpWidget(screenRouterApp(router: router, overrides: w.overrides));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('a loaded screen leaves the frame loop', () {
    testWidgets('Home', (tester) async {
      await _open(tester, DiscoveryWorld(), '/home');
      expect(find.byKey(const Key('post-a')), findsOneWidget);
      await expectIdle(tester);
      expectBlurBudget(max: 0);
    });

    testWidgets('Photo detail', (tester) async {
      await _open(tester, DiscoveryWorld(), '/p/e');
      await expectIdle(tester);
      expectBlurBudget(max: 0);
    });

    testWidgets('Find, and Find with a filter sheet open', (tester) async {
      await _open(tester, DiscoveryWorld(), '/find');
      await expectIdle(tester);
      expectBlurBudget(max: 0);
      await tester.tap(find.byKey(const Key('find-service')));
      await expectIdle(tester);
      expectBlurBudget(max: 1);
    });
  });

  group('photos are decoded at the size they are shown', () {
    testWidgets('Home, detail and Find request bounded decode widths', (tester) async {
      tester.view.physicalSize = const Size(1170, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      for (final start in ['/home', '/p/e', '/find']) {
        final log = <PhotoRequest>[];
        final w = DiscoveryWorld();
        await w.init();
        // Hosted under a photo scope that records every request.
        await tester.pumpWidget(
          screenApp(
            home: testPhotoScope(
              log: log,
              child: switch (start) {
                '/home' => const HomeScreen(),
                '/p/e' => const PhotoDetailScreen(postId: 'e'),
                _ => const FindPhotographerScreen(),
              },
            ),
            overrides: w.overrides,
          ),
        );
        await tester.pumpAndSettle();
        expect(log, isNotEmpty, reason: start);
        for (final r in log) {
          expect(r.cacheWidth, isNotNull, reason: '${r.url} on $start');
          expect(r.cacheWidth!, lessThanOrEqualTo(1200), reason: 'full width at 390 dp x 3 is 1170 px');
        }
        // Avatars are told apart by their fixture URL (PhotoCard and the
        // PhotographerCard hero are retry:false too, so `retry` says nothing).
        expect(
          log.where((r) => r.url.contains('/avatar-')).every((r) => r.cacheWidth! <= 200),
          isTrue,
          reason: 'avatars are decoded at 48 dp or less',
        );
      }
    });
  });

  group('long lists build only what is on screen', () {
    testWidgets('Home with 200 posts', (tester) async {
      final w = DiscoveryWorld(
        posts: [for (var i = 0; i < 200; i++) fixturePost('m$i', photographerId: 'p1', age: Duration(minutes: i + 1))],
      );
      await _open(tester, w, '/home');
      expect(find.byType(PhotoCard).evaluate().length, lessThan(25));
    });

    testWidgets('Find with a full page of 20 photographers', (tester) async {
      final w = DiscoveryWorld(
        photographers: [for (var i = 0; i < 60; i++) fixturePhotographer('q$i', name: 'Thợ $i', reviews: 10 + i)],
      );
      await _open(tester, w, '/find');
      expect(find.byType(PhotographerCard).evaluate().length, lessThan(10));
    });
  });

  group('location and reads', () {
    testWidgets('none of the screens ever asks for permission', (tester) async {
      final w = DiscoveryWorld(status: LocationPermissionStatus.notAsked);
      final router = await _open(tester, w, '/home');
      router.go('/find');
      await tester.pumpAndSettle();
      router.go('/p/a');
      await tester.pumpAndSettle();
      expect(w.location.requestCalls, 0);
      expect(w.location.locationCalls, 0);
    });

    testWidgets('with permission granted, Home and Find share one fix', (tester) async {
      final w = DiscoveryWorld(status: LocationPermissionStatus.granted);
      w.location.location = ApproxLocation(lat: 10.7769, lng: 106.7009, capturedAt: fixtureNow);
      final router = await _open(tester, w, '/home');
      router.go('/find');
      await tester.pumpAndSettle();
      router.go('/home');
      await tester.pumpAndSettle();
      expect(w.location.locationCalls, 1);
    });

    testWidgets('Home does one batch of reads for the viewer\'s bookmarks, no writes', (
      tester,
    ) async {
      final w = DiscoveryWorld();
      await _open(tester, w, '/home');
      expect(w.engagement.readCalls, 1);
      expect(w.engagement.writeCalls, 0);
    });

    testWidgets('the detail screen reads the viewer\'s marks once and follow once', (
      tester,
    ) async {
      final w = DiscoveryWorld();
      await _open(tester, w, '/p/a');
      expect(w.engagement.readCalls, 2);
      expect(w.engagement.writeCalls, 0);
    });
  });

  test('no listener, polling or timer in the discovery features', () {
    for (final dir in ['home', 'photo', 'find', 'discovery', 'explore']) {
      for (final f in Directory('lib/features/$dir').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) {
          continue;
        }
        final src = f.readAsStringSync();
        for (final banned in ['StreamProvider', '.snapshots(', 'Timer(', 'Timer.periodic', 'Stream.periodic', 'AnimationController']) {
          expect(src, isNot(contains(banned)), reason: '${f.path}: $banned');
        }
      }
    }
  });
}
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/battery/discovery_screens_battery_test.dart`
Expected: PASS (13 tests). A failure names the culprit. An idle failure means a spinner or controller is alive after loading; a decode failure means a `NetworkPhoto` has an unbounded width or a card shows a photo twice as wide as its box; a read-count failure means a screen fetches more than the fixed set; fix the code, not the test.

- [ ] **Step 3: Fix anything the run found**

Re-run Step 2 until green.

- [ ] **Step 4: Manual profiling**

Follow `docs/testing/battery-and-performance.md` (written by the screen-codes plan; do not rewrite it) on a mid-range Android phone in profile mode, with at least 100 posts and 50 photographers in the project:

1. Home: scroll to the end and back three times, switch each chip once, pull to refresh; then leave it idle for 5 minutes.
2. Photo detail: open ten photos in a row from Home, swipe a three-image post, like and unlike.
3. Find: change each filter once, switch the four sorts, open a date sheet; then idle for 5 minutes.
4. Grant location once from Explore and confirm Home and Find add no second GPS use (`dumpsys batterystats`, GPS ≤ 15 seconds in total).

- Android: `flutter run --profile`; `adb shell dumpsys gfxinfo`, `top`, `batterystats` and `meminfo` as in the guide (idle frames ≤ 5 per 30 s, janky frames < 5 %, p90 ≤ 16 ms, CPU idle < 3 %, PSS < 250 MB).
- iOS: Xcode Instruments (Time Profiler, Allocations and Energy Log) on a real iPhone, or the Simulator's Debug Navigator CPU, Memory and Energy gauges; Energy Impact must read "Low" at rest and memory must plateau while scrolling the feed. Prerequisite: iOS cannot be built on this machine yet (no Xcode, no CocoaPods, no iOS Firebase configuration); that is a separate "iOS enablement" plan, so until it lands record "iOS: not measured, blocked by iOS enablement".

Record the results in the PR description with the table template of the guide; add the iOS rows with the iPhone model in the Thiết bị column and Energy Impact in place of the Android-only columns.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add test/support test/battery
git commit -m "test: idle, blur, decode-size and read-count checks for Home, Photo detail and Find

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** S01 — greeting and title, category chips (Dành cho bạn, Chân dung, Cưới, Gia đình, Kỷ yếu), 4:5 card with the pills "Rảnh T7 này" and "Chân dung · từ 1,5M", "Rảnh tuần này" (3:4, 120dp, "Xem tất cả" to S04), "Buổi chụp thật", reasons (at most two), pages of 20, pull to refresh, per-chip scroll position, empty state with the way to Explore, error with retry, two columns from 600dp, optimistic save with undo (Tasks 1, 2). S02 — gallery with dots and double-tap like, author row with tick and follow, counts, location, package card (faded and "Xem các gói khác" when retired), "Thêm của …", real-shoot line, removed-post state, "Đặt gói này" through the phone gate to the booking with the package chosen (Tasks 1, 3). S04 — filter chips for area, day, service, price and rating with sheets, sorts, count line, `PhotographerCard` with reasons and "Đặt {thứ}", fallback note, empty state, links from Explore (`specialty`, `style`, `area`), two columns, paging (Task 4). Routes and tabs (Task 5); battery and performance (Task 6).
- **Deviations (flagged):** (1) the bell and chat icons of S01 are not built; (2) share and report on S02 are not built (no link domain, no report backend); (3) the author name sits in a row under the large card, not over the photo, so that the whole photo can open S02 while the name opens S03; (4) the date filter uses Flutter's `CalendarDatePicker` in a sheet until plan 2d's `AvailabilityCalendar` exists; (5) the impression signal is not sent (needs visibility tracking), only `click`; (6) "nới bán kính" hint of the S04 empty state is not offered because the recommender has no radius; (7) the rating chip is applied on the device because the API context has no `minRating`; (8) a style filter was added to `PhotographerSummary` and `RecommendationQuery` so the Explore "Phong cách" tiles lead somewhere real.
- **Cross-plan dependencies:** `/u/:uid` (S03, plan 2d) and `/u/:uid/book` (step 4) are linked by path; until they exist the links show go_router's error page and the screens' tests use stub routes. `currentContactProvider`, `FakeUserContactRepository` and `/profile/phone?returnTo=` come from plan 2a. Plan 3c replaces the photographer half of `ActionTab`.
- **Placeholders:** none. **Type consistency:** `EngagementController.seed/load/toggleLike/toggleSave`, `FollowController.load/toggle`, `bookingPath`/`startBooking`, `areaRatingMeta`/`freeThisWeekLabel`, `HomeFeedController.selectCategory/refresh/loadMore`, `postDetailProvider`, `FindFilters`/`FindFiltersController`, `FindResults`/`FindResultsController.sendClick`, `Picked<T>`, `OptionRow`, `DiscoveryWorld` and the widget keys are named identically in tests and code.
- **Battery and performance (Task 6):** idle after load on all three screens (and Find with a sheet), blur budget 0 outside sheets, decode width on every photo (avatars at most 200 px), lazy lists, no permission prompt and one shared fix, fixed read counts, no stream or timer in the feature folders, and the manual Android and iOS table per `docs/testing/battery-and-performance.md`.
- **Risks:** the scroll-restore test depends on estimated sliver extents (Task 2 Step 4 says how to relax it); `CalendarDatePicker` digit lookup in the date test (Task 4 Step 4); a customer without a profile yet sees an empty middle tab for a moment (by design: no query runs before the role is known).

## From 2026-10-01-step3c-create-post.md

#### Former task 8: Battery and performance check

**Files:**
- Create (if missing): `test/support/idle.dart`, `test/support/blur.dart`
- Create: `test/battery/create_post_battery_test.dart`
- Reference (written by the screen-codes plan, do not rewrite): `docs/testing/battery-and-performance.md`

**Interfaces:**
- Consumes: `expectIdle`, `expectBlurBudget`, `_Create`-style setup (copied into this file), the composer, the screen.
- Produces: no production code.

What is checked: the form is idle at rest in every state (empty, with photos, with failed and uploaded tiles, with a sheet open); a running upload costs one spinner and determinate progress, no other animation; uploads are strictly one at a time and rebuild the screen a bounded number of times; the screen holds file paths and decodes previews at tile size, never bytes; no timers or streams; no location or camera access; the platform files ask for the photo library only (Task 1).

- [ ] **Step 1: Write the tests**

If `test/support/idle.dart` or `test/support/blur.dart` is missing, create it with exactly the code given in plan 3a1 Task 7.

```dart
// test/battery/create_post_battery_test.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/create_post/create_post_providers.dart';
import 'package:photobooking/features/create_post/create_post_screen.dart';
import 'package:photobooking/features/create_post/post_composer.dart';

import '../support/blur.dart';
import '../support/content_fixtures.dart';
import '../support/discovery_world.dart';
import '../support/idle.dart';
import '../support/screen_host.dart';

PickedImage img(int i) => PickedImage(path: '/tmp/none-$i.jpg', name: '$i.jpg');

Future<(DiscoveryWorld, FakeMediaUploader, FakePostPublisher)> _open(
  WidgetTester tester, {
  int photos = 3,
  MediaUploader? uploader,
}) async {
  final w = DiscoveryWorld(role: UserRole.photographer);
  await w.init();
  w.services.add(fixtureService('s1', photographerId: w.uid));
  final fake = FakeMediaUploader();
  final publisher = FakePostPublisher(posts: w.posts, clock: () => fixtureNow);
  await tester.pumpWidget(
    screenApp(
      home: CreatePostScreen(onAddService: () {}, onPublished: (_) {}),
      overrides: [
        ...w.overrides,
        imagePickerProvider.overrideWithValue(FakeImagePicker([[for (var i = 0; i < photos; i++) img(i)]])),
        mediaUploaderProvider.overrideWithValue(uploader ?? fake),
        postPublisherProvider.overrideWithValue(publisher),
      ],
    ),
  );
  await tester.pumpAndSettle();
  return (w, fake, publisher);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CreatePostScreen)));

void main() {
  group('the form is idle at rest', () {
    testWidgets('empty', (tester) async {
      await _open(tester);
      await expectIdle(tester);
      expectBlurBudget(max: 0);
    });

    testWidgets('with photos, one failed and one uploaded', (tester) async {
      final (_, uploader, _) = await _open(tester);
      await tester.tap(find.byKey(const Key('create-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-service')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Chân dung 2 giờ'));
      await tester.pumpAndSettle();
      uploader.failNames.add('1.jpg');
      await tester.tap(find.byKey(const Key('create-publish')));
      await tester.pumpAndSettle();
      final statuses = _container(tester).read(postComposerProvider).images.map((i) => i.status).toList();
      expect(statuses, [ComposerImageStatus.uploaded, ComposerImageStatus.failed, ComposerImageStatus.local]);
      await expectIdle(tester);
      expectBlurBudget(max: 0);
    });

    testWidgets('with the package sheet open', (tester) async {
      await _open(tester);
      await tester.tap(find.byKey(const Key('create-service')));
      await expectIdle(tester);
      expectBlurBudget(max: 1);
    });
  });

  testWidgets('while a photo uploads: determinate progress and one spinner, nothing else moves', (
    tester,
  ) async {
    final slow = _Slow();
    await _open(tester, photos: 1, uploader: slow);
    await tester.tap(find.byKey(const Key('create-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-service')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Chân dung 2 giờ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-publish')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, isNotNull, reason: 'an indeterminate bar would animate forever');
    expect(tester.binding.transientCallbackCount, lessThanOrEqualTo(1), reason: 'only the button spinner');
    slow.finish();
    await tester.pumpAndSettle();
  });

  testWidgets('ten photos upload strictly one at a time with a bounded number of rebuilds', (
    tester,
  ) async {
    final (_, uploader, _) = await _open(tester, photos: 10);
    await tester.tap(find.byKey(const Key('create-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-service')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Chân dung 2 giờ'));
    await tester.pumpAndSettle();
    var states = 0;
    _container(tester).listen(postComposerProvider, (_, _) => states++);
    await tester.tap(find.byKey(const Key('create-publish')));
    await tester.pumpAndSettle();
    expect(uploader.maxConcurrent, 1);
    expect(uploader.uploaded, hasLength(10));
    // per photo: start, two progress steps, done; plus publishing on/off and the reset.
    expect(states, lessThanOrEqualTo(10 * 4 + 6));
  });

  group('source audit', () {
    String read(String path) => File(path).readAsStringSync();

    test('previews are decoded at tile size and no image bytes are held', () {
      final screen = read('lib/features/create_post/create_post_screen.dart');
      expect(screen, contains('Image.file('));
      expect(screen, contains('cacheWidth: cacheWidth'));
      for (final f in [
        'lib/features/create_post/post_composer.dart',
        'lib/features/create_post/create_post_screen.dart',
        'lib/data/media/media_uploader.dart',
      ]) {
        final src = read(f);
        expect(src, isNot(contains('readAsBytes')), reason: f);
        expect(src, isNot(contains('Uint8List')), reason: f);
      }
    });

    test('no timer, ticker, stream provider or listener in the feature', () {
      for (final f in Directory('lib/features/create_post').listSync().whereType<File>()) {
        final src = f.readAsStringSync();
        for (final banned in ['Timer', 'AnimationController', 'StreamProvider', '.snapshots(', 'Stream.periodic']) {
          expect(src, isNot(contains(banned)), reason: '${f.path}: $banned');
        }
      }
    });

    test('Create post never touches location or the camera', () {
      for (final f in Directory('lib/features/create_post').listSync().whereType<File>()) {
        final src = f.readAsStringSync();
        expect(src, isNot(contains('LocationRepository')), reason: f.path);
        expect(src, isNot(contains('ImageSource.camera')), reason: f.path);
      }
      expect(read('lib/data/media/plugin_image_picker.dart'), isNot(contains('ImageSource.camera')));
    });

    test('the picker scales and re-encodes before the app ever sees the file', () {
      final src = read('lib/data/media/plugin_image_picker.dart');
      expect(src, contains('2048'));
      expect(src, contains('imageQuality'));
    });

    test('the permission files are checked by the platform test', () {
      expect(File('test/platform/media_platform_config_test.dart').existsSync(), isTrue);
    });
  });
}

class _Slow implements MediaUploader {
  final _gate = Completer<void>();
  void finish() => _gate.complete();

  @override
  Stream<UploadEvent> upload(PickedImage image, {required String storagePath}) async* {
    yield const UploadEvent.progress(0.4);
    await _gate.future;
    yield UploadEvent.done(UploadedMedia(url: 'https://storage.test/$storagePath', storagePath: storagePath));
  }

  @override
  Future<void> delete(String storagePath) async {}
}
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/battery/create_post_battery_test.dart test/platform`
Expected: PASS (9 + 3 tests). A failure names the culprit: an idle failure means a spinner, skeleton or controller is alive while nothing happens (a failed tile must not show a spinner); a state-count failure means progress events rebuild the screen too often; a source failure means bytes, a timer or a camera path crept in. Fix the code, not the test.

- [ ] **Step 3: Fix anything the run found**

Re-run Step 2 until green.

- [ ] **Step 4: Manual profiling**

Follow `docs/testing/battery-and-performance.md` (written by the screen-codes plan; do not rewrite it) on a mid-range Android phone in profile mode:

1. Pick 10 photos taken with the phone's camera (about 12 MP each) and publish on mobile data: watch memory (PSS) while the previews load and during the upload (< 250 MB, and no growth after the post is published), the mobile radio (active only during uploads, `batterystats`), and that no wake lock is held.
2. Leave the filled form open for 5 minutes (idle frames ≤ 5 per 30 s, CPU < 3 %).
3. Publish, then confirm the new post is first on Home and the photos load at tile size from Storage.
4. Kill the app between "photos uploaded" and "post created" once and note any leftover objects under `posts/{uid}/{draftId}/`: they are the known orphan case and are cleaned by a server job later, not by this plan.

- Android: `flutter run --profile`; `adb shell dumpsys gfxinfo`, `top`, `batterystats` and `meminfo` as in the guide.
- iOS: Xcode Instruments (Allocations, Time Profiler and Energy Log) on a real iPhone, or the Simulator's Debug Navigator CPU, Memory and Energy gauges; peak memory while picking 10 photos must stay bounded and Energy Impact must read "Low" at rest. Prerequisite: iOS cannot be built on this machine yet (no Xcode, no CocoaPods, no iOS Firebase configuration); that is a separate "iOS enablement" plan, so until it lands record "iOS: not measured, blocked by iOS enablement".

Record the results in the PR description with the table template of the guide; add the iOS rows with the iPhone model in the Thiết bị column and Energy Impact in place of the Android-only columns.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add test/support test/battery
git commit -m "test: idle, upload-order, memory and permission checks for Create post

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** S21 — photo grid up to 10 with a "+" tile, reorder with up/down buttons, remove; caption; package required (accent border, error under the field, "Thêm gói" when none); place and style; "Thêm vào portfolio"; "Đăng" disabled until a photo and a package exist; per-photo progress and a separate retry; text draft saved on the device; published once for feed and portfolio (post document plus `photographers/{uid}.portfolio`); the new post is first on Home (`pinToTop`); no orphan photos from removed or abandoned uploads (delete on removal; uploads only at publish time; same id on retry). Hashtags are extracted and stored (spec 3.7: "only store them"). Storage resize to 2048 px and quality 85 happen in the picker; rules for post creation and for Storage with tests.
- **Deviations (flagged):** (1) images are re-encoded as JPEG quality 85, not WebP (the picker cannot encode WebP; a WebP encoder is a later optimisation). (2) The draft saves text only, not photos (temporary picker files may be gone). (3) Reordering uses the up and down buttons; dragging is not built (the spec allows the buttons as the alternative). (4) The "Bài đăng / Sự kiện" tabs and S25 are not here (events plan). (5) Photos uploaded and then abandoned by killing the app stay in Storage until a server cleanup exists. (6) Post location stores the place name only, no geohash (privacy: no coordinates are involved in posting).
- **Cross-plan dependencies:** `/setup/2` (plan 2d) for "Thêm gói"; plan 3b4's `HomeFeedController` gains `pinToTop`; the posts rules block from plan 3b1 is replaced by the create rule; `firebase/firebase.json` and the rules test script now start the Storage emulator (the CI job in `.github/workflows/flutter.yml` runs `npm test` and needs no change).
- **Placeholders:** none. **Type consistency:** `PickedImage`, `ImagePickerPort.pickImages(max:)`, `UploadedMedia`/`UploadEvent`/`MediaUploader`, `PostDraft`/`PostPublisher`, `ComposerState`/`ComposerImage`/`PostPublishResult`/`PublishOutcome`, `postComposerProvider`, `CreatePostScreen(onAddService, onPublished)`, the keys `create-*`, `newUlid`, `extractHashtags` are named identically in tests and code.
- **Battery and performance (Task 8):** idle in every form state, one spinner and determinate progress while uploading, strictly sequential uploads with a bounded number of rebuilds, no bytes in memory (`putFile` from disk, previews decoded at tile size), no timers or streams, no location or camera, permission files asserted for Android and iOS (Task 1), manual Android and iOS profiling per `docs/testing/battery-and-performance.md`.
- **Risks:** `image_picker` and `firebase_storage` versions (Task 1 Step 1 checks they resolve); the Storage emulator in the rules test script; `Image.file` with a missing file in widget tests relies on `errorBuilder`; the exact count of transient callbacks while a button spinner runs (Task 8 uses `<= 1`).

## From 2026-10-01-backend-phase1-firebase-local.md

#### Former task 9: Performance check

**Files:**
- Create: `app_flutter/firebase/functions/test/perf/get_contact_link.perf.test.ts`, `app_flutter/test/data/backend/backend_call_budget_test.dart`
- Modify: `app_flutter/README.md` (budget table)

**Interfaces:**
- Consumes: everything above; npm script `test:perf` (Task 4).
- Produces: the budgets below, asserted where they can be measured locally.

| What | Measured where | Budget | When |
|---|---|---|---|
| Firestore reads per `getContactLink` | domain test (fakes) + emulator read-count test (real adapters) | unlocked ≤ 3 documents in ≤ 2 round trips; refused at the subject: 1 document, 1 round trip; malformed: 0 | now (Tasks 3, 6) |
| Firestore writes per call | integration + perf | exactly 1 (`ContactAccessLog`) per well-formed request, also under 10 concurrent calls; 0 for malformed | now |
| Request / response size | perf test | ≤ 128 bytes each (measured: request 63 B, response 48 B) | now |
| Bundle `lib/index.js` | perf test | < 150 KB, Firebase SDKs external (measured: about 10 KB) | now |
| Emulator latency, warm p95 | perf test | < 500 ms (measured: p95 about 14 ms). Smoke budget only: catches an extra round trip, a sleep or a heavy import; the emulator has no network hop and no cold-start isolation, so it says nothing about production | now |
| Emulator first call | perf test | < 5 s (measured: about 0.6 s, worker start) | now |
| Production warm p95 (server execution) | Cloud Monitoring, cloud deploy plan | < 300 ms | later |
| Production end-to-end p95 from a Vietnamese phone | client trace, cloud deploy plan | < 600 ms | later |
| Cold start | Cloud Monitoring, cloud deploy plan | p95 < 2.5 s; `minInstances: 0` at launch; set `minInstances: 1` on `getContactLink` only if cold starts exceed 5 % of calls | later |
| Region | `CALLABLE_OPTIONS.region`, client `functionsRegion` (tests compare both) | `asia-southeast1`; the Firestore database should be in the same region (check in the cloud deploy plan) | now |
| Client | Flutter tests below + 2b `ContactLauncher` | one `getContactLink` call per tap, no prefetch, no polling, no automatic retry; 10 s client timeout = server timeout | now |

- [ ] **Step 1: Write the budget tests**

```ts
// app_flutter/firebase/functions/test/perf/get_contact_link.perf.test.ts
import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { statSync } from 'node:fs';
import { deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { applySeed } from '../../seed/apply.js';
import { callCallable, emulatorProject, resetEmulators, signIn } from '../../seed/emulator_client.js';
import { LAN, SEED_PASSWORD } from '../../seed/fixtures.js';

// Local smoke budgets. The emulator runs the function in a local Node worker with no network hop,
// so these numbers only catch regressions (an extra round trip, a sleep, a heavy import);
// production latency and cold starts are measured in the cloud deploy plan.
const LOCAL_FIRST_CALL_MS = 5_000;
const LOCAL_WARM_P95_MS = 500;
const WARM_CALLS = 50;
const MAX_PAYLOAD_BYTES = 128;
const MAX_BUNDLE_BYTES = 150_000;
const DATA = { bookingId: 'seed-booking-accepted', channel: 'zalo' };

let app: App;
let db: Firestore;
let token: string;

before(async () => {
  await resetEmulators();
  app = initializeApp({ projectId: emulatorProject() }, 'perf-test');
  db = getFirestore(app);
  await applySeed(db, getAuth(app), new Date());
  token = await signIn('lan.customer@seed.test', SEED_PASSWORD);
});
after(async () => {
  await deleteApp(app);
});

const percentile = (sorted: number[], p: number): number =>
  sorted[Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)] ?? Number.NaN;

test('latency on the emulator stays inside the smoke budget', async () => {
  const t0 = performance.now();
  const first = await callCallable('getContactLink', DATA, token);
  const firstMs = performance.now() - t0;
  assert.equal(first.status, 200, first.text);
  for (let i = 0; i < 5; i++) await callCallable('getContactLink', DATA, token);
  const samples: number[] = [];
  for (let i = 0; i < WARM_CALLS; i++) {
    const start = performance.now();
    const res = await callCallable('getContactLink', DATA, token);
    samples.push(performance.now() - start);
    assert.equal(res.status, 200, res.text);
  }
  samples.sort((a, b) => a - b);
  const p50 = percentile(samples, 50);
  const p95 = percentile(samples, 95);
  console.log(`getContactLink (emulator): first ${firstMs.toFixed(0)} ms, p50 ${p50.toFixed(0)} ms, p95 ${p95.toFixed(0)} ms over ${WARM_CALLS} warm calls`);
  assert.ok(firstMs < LOCAL_FIRST_CALL_MS, `first call ${firstMs.toFixed(0)} ms`);
  assert.ok(p95 < LOCAL_WARM_P95_MS, `p95 ${p95.toFixed(0)} ms`);
});

test('request and response stay tiny', async () => {
  const requestBytes = Buffer.byteLength(JSON.stringify({ data: DATA }));
  const res = await callCallable('getContactLink', DATA, token);
  const responseBytes = Buffer.byteLength(res.text);
  console.log(`getContactLink payload: request ${requestBytes} B, response ${responseBytes} B`);
  assert.ok(requestBytes <= MAX_PAYLOAD_BYTES, `${requestBytes} B`);
  assert.ok(responseBytes <= MAX_PAYLOAD_BYTES, `${responseBytes} B`);
});

test('exactly one log write per call, also under 10 concurrent calls', async () => {
  const count = async () =>
    (await db.collection('contact_access_log').where('requesterId', '==', LAN).count().get()).data().count;
  const before = await count();
  const results = await Promise.all(Array.from({ length: 10 }, () => callCallable('getContactLink', DATA, token)));
  for (const r of results) assert.equal(r.status, 200, r.text);
  assert.equal(await count(), before + 10);
});

test('the bundle stays small for fast cold starts', () => {
  const bytes = statSync('lib/index.js').size;
  console.log(`lib/index.js: ${bytes} B (firebase-admin and firebase-functions are external)`);
  assert.ok(bytes < MAX_BUNDLE_BYTES, `${bytes} B`);
});
```

```dart
// test/data/backend/backend_call_budget_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('getContactLink is called from one data adapter at most', () {
    final callers = _dartFiles('lib')
        .where((f) => f.readAsStringSync().contains("'getContactLink'"))
        .map((f) => f.path)
        .toList();
    expect(callers.length, lessThanOrEqualTo(1), reason: '$callers');
    for (final path in callers) {
      expect(path, startsWith('lib/data/'));
    }
  });

  test('nothing that talks to callables or the contact link polls', () {
    final polling = RegExp(r'Timer\.periodic|Stream\.periodic');
    final offenders = _dartFiles('lib')
        .where((f) {
          final s = f.readAsStringSync();
          final talksToServer =
              s.contains('httpsCallable') ||
              s.contains('ContactLinkRepository') ||
              s.contains('ContactLauncher');
          return talksToServer && polling.hasMatch(s);
        })
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
```

- [ ] **Step 2: Run and record**

This task measures code that already exists, so these tests are guards and are expected to pass on the first run. If one fails, it is a real regression: fix the code, not the budget.

Run (from `app_flutter/firebase/functions`, outside the sandbox): `npm run test:perf`
Expected (numbers from a dry run on an Apple-silicon Mac; yours will differ but must stay inside the budgets):

```
getContactLink (emulator): first 604 ms, p50 12 ms, p95 14 ms over 50 warm calls
getContactLink payload: request 63 B, response 48 B
lib/index.js: 10414 B (firebase-admin and firebase-functions are external)
ℹ tests 4
ℹ pass 4
ℹ fail 0
```

Run (from `app_flutter/`): `flutter test test/data/backend`
Expected: PASS (9 tests: 7 from Task 8, 2 here).

If plan 2b is done, also run `flutter test test/data/contact` and confirm its launcher tests still assert one `FakeContactLinkRepository.requests` entry per open (one call per tap).

- [ ] **Step 3: Write the budgets down**

Append to the "Local backend (Firebase Emulator Suite)" section of `app_flutter/README.md`:

```markdown
### Performance budgets (getContactLink)

| What | Budget | Checked by |
|---|---|---|
| Firestore reads | ≤ 3 documents in ≤ 2 round trips (locked: 1) | `packages/domain` tests, `test/integration/read_budget.test.ts` |
| Firestore writes | exactly 1 `contact_access_log` row per well-formed call | integration + perf tests |
| Payload | request and response ≤ 128 B | `npm run test:perf` |
| Bundle | `lib/index.js` < 150 KB | `npm run test:perf` |
| Emulator warm p95 | < 500 ms (smoke only, not a production number) | `npm run test:perf` |
| Production warm p95 / cold start | < 300 ms / < 2.5 s, `minInstances: 0` until measured | cloud deploy plan (Cloud Monitoring) |
| Client | one call per tap, no polling, 10 s timeout, region `asia-southeast1` | `test/data/backend/*` |
```

- [ ] **Step 4: Commit**

```bash
git add app_flutter/firebase/functions/test/perf app_flutter/test/data/backend/backend_call_budget_test.dart app_flutter/README.md
git commit -m "perf(functions): getContactLink read, write, payload, bundle and latency budgets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Goal coverage:** one command with import/export, watch build and first-run seed (Task 7); all emulators plus UI configured in the existing `firebase.json` (Task 4); seed with verified/unverified photographers, contact flags, private numbers, a customer with and one without a phone, and accepted/requested/cancelled/completed bookings (Task 5); debug app wiring for Android emulator, Genymotion, iOS Simulator and real devices, with debug-only Android cleartext, iOS `NSAllowsLocalNetworking` and platform-file tests (Task 8); `getContactLink` (Tasks 2–3 rules, 4 plumbing, 6 wiring) and reusable `makeRequirePhone` (Tasks 2, 6) with tests; performance budgets (Task 9); docs, `CLAUDE.md` and CI (Task 7). Later plans are listed in "Out of scope".
- **Contract match with plan 2b:** request `{bookingId | registrationId, channel: call|zalo|whatsapp}` (`parseContactLinkRequest`, strict); response `{url}` only (handler and integration test check the whole body); URLs byte-identical to `contactUriFor`, including `zaloPhone ?? phone`, `whatsappPhone ?? phone`, `wa.me` without `+` (domain tests plus a TS port of `isAllowedContactUri`); errors with `details.code` and message `contact_locked` for locked, `permission_denied` / `not_found` / `invalid_argument` otherwise (`linkErrorFromCode` maps all of them to "unavailable"); unlock window identical to `contactAccessForBooking` (30 days inclusive, unknown completion locked, `reviewed` included); one `ContactAccessLog` row per well-formed request with `granted` true or false; no number logged.
- **Placeholders:** none. Every file is given in full; the only conditional step is the 2b adapter edit in Task 8, which also updates 2b's plan text and is guarded by a test either way.
- **Type consistency:** `GetContactLinkDeps`, `BookingRecord`, `RegistrationRecord`, `PhotographerContact`, `ContactAccessLogEntry`, `CallableInput`, `CALLABLE_OPTIONS`, `REGION`/`functionsRegion`, `EmulatorConfig` ports and the seed ids are named identically in code, tests, README and the plan tables.
- **Verified, not assumed:** the expected outputs (test counts 25/41/53, 15/21 unit, 15 integration, 4 perf, the 404 text, the callable error body, the export/import log lines, the measured latencies and sizes) come from a dry run of this exact code in a scratch copy of the repo layout, with the existing `firestore.rules` and rules tests passing against the new `firebase.json`. That dry run is also how two traps were found and fixed in the plan: `set -e` aborting on `scripts/env.sh`, and the Functions emulator's Unix socket being blocked by the Claude sandbox. The Dart emulator APIs and their `automaticHostMapping` parameters were checked in the sources of cloud_firestore 6.10.0, firebase_auth 6.7.0, cloud_functions 6.5.0 and firebase_storage 13.6.0; the Dart code of Task 8/9 was not compiled in the dry run.
- **Risks to watch:** (1) Using the app's real project id with the emulators: safe while every SDK is routed locally (seed guard, debug-only wiring); firebase-tools prints "You are not currently authenticated" and is fine without a login. If a developer needs a `demo-*` id, the app cannot follow on Android (native auto-init), so keep the default. (2) `firebase-functions` 7 / `firebase-admin` 14 exist; upgrading belongs to the cloud deploy plan together with a newer `firebase-tools`. (3) The functions bundle relies on esbuild resolving the `paths` alias; `npm run build` fails loudly if it does not, and the deployable `lib/index.js` never references `packages/`. (4) Cloud deploy is not exercised here: `predeploy` builds, but App Check, IAM and the Firestore database location are decided in the cloud plan. (5) A real iPhone over the LAN shows the local-network permission prompt; refusing it blocks the emulators until it is re-enabled in Settings.

## From 2026-10-01-backend-phase2-selfhosted-postgres.md

#### Former task 11: Performance check

**Files:**
- Create: `services/api/test/perf-explain.test.ts`, `services/api/test/payload.test.ts`, `services/api/perf/k6-slice.js`, `app_flutter/test/data/http/http_battery_test.dart`
- Modify: `services/api/docker-compose.yml`

**Interfaces:**
- Consumes: `profileQuery`, `contactQuery` (Tasks 4–5), `channelsQuery`, `numbersQuery`, `serviceAreaQuery` (Task 6), `bookingContactQuery`, `seedContractWorld`, `contractWorld` (Task 7); `MockApi` and the HTTP adapters (Task 8).
- Produces: index-scan assertions for every slice query; byte budgets per endpoint; gzip and keep-alive checks; a k6 run with p95 thresholds; client tests for one request per action, no polling, one keep-alive client.

Budgets (local, `docker compose` on a developer machine, 200 requests/s for 30 s, `LOG_LEVEL=warn`):

| Operation | p95 | Response bytes | Why |
|---|---|---|---|
| `getUser`, `getUserContact`, `getContactChannels`, `getContactNumbers` | < 20 ms | ≤ 256 / 256 / 128 / 160 | one primary-key lookup each |
| `saveUserContact` | < 30 ms | ≤ 256 | one upsert + trigger |
| `getContactLink` | < 35 ms | ≤ 96 | one 4-table PK/index read + one log insert |
| all | `http_req_failed` < 0.1 % | | pool exhaustion or 5xx would show here |

Pool: `DB_POOL_MAX=10` (default). By Little's law 200 req/s × ~2 ms of database time ≈ 0.4 busy connections, so 10 absorbs bursts with a wide margin, and PostgreSQL's default `max_connections = 100` leaves room for several API instances, the migrator and Adminer. Payloads stay under the 1 KiB gzip threshold, so they are sent uncompressed (compressing ~100 bytes costs more CPU than it saves radio time); larger responses of later plans are gzipped automatically.

- [ ] **Step 1: Write the server tests**

```ts
// services/api/test/perf-explain.test.ts
import { CompiledQuery, sql, type Compilable } from 'kysely';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { bookingContactQuery } from '../src/repos/contact-links.js';
import { channelsQuery, numbersQuery, serviceAreaQuery } from '../src/repos/photographers.js';
import { contactQuery, profileQuery } from '../src/repos/users.js';
import { resetDb, testDb } from './helpers.js';

interface PlanNode {
  'Node Type': string;
  'Relation Name'?: string;
  'Index Name'?: string;
  Plans?: PlanNode[];
}

const db = testDb();
const nodes = (n: PlanNode): PlanNode[] => [n, ...(n.Plans ?? []).flatMap(nodes)];

async function explain(q: Compilable): Promise<PlanNode[]> {
  const c = q.compile();
  const r = await db.executeQuery<{ 'QUERY PLAN': Array<{ Plan: PlanNode }> }>(
    CompiledQuery.raw(`explain (format json) ${c.sql}`, [...c.parameters]),
  );
  return nodes(r.rows[0]!['QUERY PLAN'][0]!.Plan);
}

beforeAll(async () => {
  await resetDb(db);
  // Realistic sizes so the planner's choice means something: 20k users, 2k photographers, 50k bookings.
  await sql`insert into files (id, storage_provider, storage_key, mime_type, size_bytes)
    select 'f' || g, 'external', 'https://x.test/' || g, 'image/*', 0 from generate_series(1, 20000) g`.execute(db);
  await sql`insert into users (id, display_name, role, avatar_file_id)
    select 'u' || g, 'User ' || g, case when g % 10 = 0 then 'photographer' else 'customer' end, 'f' || g
    from generate_series(1, 20000) g`.execute(db);
  await sql`insert into user_contacts (user_id, phone_e164)
    select 'u' || g, '+849' || lpad(g::text, 8, '0') from generate_series(1, 20000) g`.execute(db);
  await sql`insert into photographers (user_id, onboarding_complete, service_city, service_radius_km)
    select 'u' || g, true, 'Hà Nội', 20 from generate_series(10, 20000, 10) g`.execute(db);
  await sql`insert into photographer_contact_channels (photographer_id, call_enabled, zalo_enabled)
    select 'u' || g, true, true from generate_series(10, 20000, 10) g`.execute(db);
  await sql`insert into photographer_contact_numbers (photographer_id, phone_e164)
    select 'u' || g, '+848' || lpad(g::text, 8, '0') from generate_series(10, 20000, 10) g`.execute(db);
  await sql`insert into services (id, photographer_id, name, duration_minutes, price)
    select 's' || g, 'u' || g, 'Gói', 120, 1000000 from generate_series(10, 20000, 10) g`.execute(db);
  await sql`insert into bookings (id, customer_id, photographer_id, service_id, service_name, service_price,
      service_duration_minutes, day, start_time, end_time, status, deposit_amount, remaining_amount)
    select 'b' || g, 'u' || (g % 20000 + 1), 'u' || ((g % 2000 + 1) * 10), 's' || ((g % 2000 + 1) * 10), 'Gói', 1000000,
      120, date '2026-01-01' + (g % 365), time '09:00', time '11:00', 'completed', 300000, 700000
    from generate_series(1, 50000) g`.execute(db);
  await sql`insert into booking_events (id, booking_id, status, at)
    select 'e' || g, 'b' || g, 'completed', now() - (g % 60) * interval '1 day' from generate_series(1, 50000) g`.execute(db);
  await sql`analyze`.execute(db);
}, 120_000);

afterAll(async () => {
  await resetDb(db);
  await db.destroy();
});

const INDEX_NODES = new Set(['Index Scan', 'Index Only Scan', 'Bitmap Index Scan']);

describe('slice queries use the indexes of relational-schema.md', () => {
  it.each<[string, () => Compilable, string[]]>([
    ['getUser', () => profileQuery(db, 'u123'), ['users_pkey', 'files_pkey']],
    ['getUserContact', () => contactQuery(db, 'u123'), ['user_contacts_pkey']],
    ['getContactChannels', () => channelsQuery(db, 'u120'), ['photographer_contact_channels_pkey', 'photographers_pkey']],
    ['getContactNumbers', () => numbersQuery(db, 'u120'), ['photographer_contact_numbers_pkey']],
    ['getServiceArea', () => serviceAreaQuery(db, 'u120'), ['photographers_pkey']],
    [
      'getContactLink',
      () => bookingContactQuery(db, 'b123'),
      ['bookings_pkey', 'ix_booking_events_booking', 'photographer_contact_channels_pkey', 'photographer_contact_numbers_pkey'],
    ],
  ])('%s: index scans only, no sequential scan', async (_op, build, indexes) => {
    const plan = await explain(build());
    expect(plan.filter((n) => n['Node Type'] === 'Seq Scan').map((n) => n['Relation Name'])).toEqual([]);
    const used = plan.filter((n) => INDEX_NODES.has(n['Node Type'])).map((n) => n['Index Name']);
    expect(used).toEqual(expect.arrayContaining(indexes));
  });
});
```

```ts
// services/api/test/payload.test.ts
import type { FastifyInstance, InjectOptions } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { contractWorld, seedContractWorld } from '../src/tools/contract-world.js';
import { bearer, resetDb, testApp, testDb } from './helpers.js';

const db = testDb();
let app: FastifyInstance;
const P = 'ctr_photographer';
const C = contractWorld.customer;

beforeAll(async () => {
  app = await testApp({ db });
  app.get('/test/big', { config: { public: true } }, async () => ({ text: 'x'.repeat(4096) }));
  await resetDb(db);
  await seedContractWorld(db, new Date());
  await app.inject({
    method: 'PUT', url: `/v1/users/${C}/contact`, headers: await bearer(C),
    payload: { phone: '+84903123456', allowZalo: true, allowWhatsApp: false },
  });
});
afterAll(async () => {
  await app.close();
  await db.destroy();
});

describe('payloads, compression, keep-alive', () => {
  it('every slice response stays within its byte budget', async () => {
    const asC = await bearer(C);
    const asP = await bearer(P);
    const cases: Array<[string, InjectOptions, number]> = [
      ['health', { method: 'GET', url: '/v1/health' }, 64],
      ['getUser', { method: 'GET', url: `/v1/users/${P}`, headers: asC }, 256],
      ['getUserContact', { method: 'GET', url: `/v1/users/${C}/contact`, headers: asC }, 256],
      ['getContactChannels', { method: 'GET', url: `/v1/photographers/${P}/contact-channels`, headers: asC }, 128],
      ['getContactNumbers', { method: 'GET', url: `/v1/photographers/${P}/contact-numbers`, headers: asP }, 160],
      ['getServiceArea', { method: 'GET', url: `/v1/photographers/${P}/service-area`, headers: asC }, 96],
      ['getContactLink', { method: 'POST', url: '/v1/contact-links', headers: asC, payload: { bookingId: 'ctr_b_accepted', channel: 'whatsapp' } }, 96],
    ];
    for (const [op, req, budget] of cases) {
      const res = await app.inject(req);
      expect(res.statusCode, op).toBe(200);
      expect(res.rawPayload.byteLength, op).toBeLessThanOrEqual(budget);
    }
  });

  it('responses above 1 KiB are gzipped; small ones are sent as they are', async () => {
    const big = await app.inject({ method: 'GET', url: '/test/big', headers: { 'accept-encoding': 'gzip' } });
    expect(big.headers['content-encoding']).toBe('gzip');
    expect(big.rawPayload.byteLength).toBeLessThan(200);
    const small = await app.inject({ method: 'GET', url: '/v1/health', headers: { 'accept-encoding': 'gzip' } });
    expect(small.headers['content-encoding']).toBeUndefined();
  });

  it('keeps idle connections open for 65 s (longer than typical mobile load balancers)', () => {
    expect(app.server.keepAliveTimeout).toBe(65_000);
  });
});
```

- [ ] **Step 2: Run them**

Run: `npm test -- test/perf-explain.test.ts test/payload.test.ts`
Expected: PASS (6 + 3). If a plan shows `Seq Scan`, the query does not match an index of `relational-schema.md`: rewrite the query (the schema is the source of truth); add an index only together with a `relational-schema.md` edit and a new migration. If a body is over budget, a field crept in: check it against the response schema.

- [ ] **Step 3: Write the client battery tests**

```dart
// test/data/http/http_battery_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/http_contact_link_repository.dart';
import 'package:photobooking/data/photographer/http_photographer_contact_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/user/http_user_contact_repository.dart';

import 'mock_api.dart';

const _contact = {
  'phone': '+84903123456',
  'phoneVerified': false,
  'allowZalo': true,
  'allowWhatsApp': false,
  'updatedAt': '2026-10-01T00:00:00.000Z',
};

void main() {
  test('one request per user action', () async {
    final api = MockApi({
      'PUT /v1/users/u1/contact': (_) => (200, _contact),
      'PUT /v1/photographers/p1/contact-setup': (_) => (204, null),
      'POST /v1/contact-links': (_) => (200, {'url': 'tel:+84903123456'}),
    });
    await HttpUserContactRepository(api: api.api())
        .save('u1', phone: '+84903123456', allowZalo: true, allowWhatsApp: false);
    await HttpPhotographerContactRepository(api: api.api()).completeContactSetup(
      'p1',
      area: const ServiceArea(city: 'Hà Nội', radiusKm: 20),
      channels: const ContactChannels(call: true),
      numbers: const ContactNumbers(phone: '+84903123456'),
    );
    await HttpContactLinkRepository(api: api.api())
        .link(subject: const ContactSubject.booking('b1'), channel: ContactChannel.call);
    expect(api.calls, [
      'PUT /v1/users/u1/contact',
      'PUT /v1/photographers/p1/contact-setup',
      'POST /v1/contact-links',
    ]);
  });

  test('no polling: an open watch costs one GET however long it stays open', () async {
    final api = MockApi({'GET /v1/users/u1/contact': (_) => (200, _contact)});
    final sub = HttpUserContactRepository(api: api.api()).watch('u1').listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(api.calls, ['GET /v1/users/u1/contact']);
    await sub.cancel();
  });

  test('the HTTP layer schedules no timers', () {
    final files = [
      ...Directory('lib/data/http').listSync().whereType<File>(),
      File('lib/data/user/http_user_repository.dart'),
      File('lib/data/user/http_user_contact_repository.dart'),
      File('lib/data/photographer/http_photographer_contact_repository.dart'),
      File('lib/data/contact/http_contact_link_repository.dart'),
    ];
    for (final f in files) {
      expect(f.readAsStringSync(), isNot(matches(RegExp(r'Timer|Stream\.periodic'))), reason: f.path);
    }
  });

  test('keep-alive and gzip are left to dart:io: no Connection or Accept-Encoding override', () async {
    final api = MockApi({
      'GET /v1/x': (r) {
        expect(r.headers.keys.map((k) => k.toLowerCase()), isNot(contains('connection')));
        expect(r.headers.keys.map((k) => k.toLowerCase()), isNot(contains('accept-encoding')));
        return (200, <String, Object?>{});
      },
    });
    await api.api().get('/v1/x');
    final io = HttpClient();
    expect(io.autoUncompress, isTrue); // dart:io sends Accept-Encoding: gzip and inflates replies
    io.close();
  });
}
```

- [ ] **Step 4: Run them**

Run (from `app_flutter/`): `flutter test test/data/http/http_battery_test.dart && flutter analyze`
Expected: `+4: All tests passed!`; analyze clean.

- [ ] **Step 5: Measure latency with k6**

In `services/api/docker-compose.yml` add the service:

```yaml
  k6:
    image: grafana/k6:0.54.0
    profiles: [perf]
    command: ["run", "/perf/k6-slice.js"]
    environment:
      API_URL: http://api:8787
      FIREBASE_PROJECT_ID: ${FIREBASE_PROJECT_ID:-demo-nag}
    volumes:
      - ./perf:/perf:ro
    depends_on:
      api: { condition: service_healthy }
```

```js
// services/api/perf/k6-slice.js
// Latency budget of the first self-hosted slice (plan Task 11). Needs AUTH_MODE=firebase-emulator
// and the contract world: docker compose run --rm api node dist/tools/seed-contract.js
import http from 'k6/http';
import { check } from 'k6';
import encoding from 'k6/encoding';

const BASE = __ENV.API_URL || 'http://api:8787';
const PROJECT = __ENV.FIREBASE_PROJECT_ID || 'demo-nag';
const CUSTOMER = 'ctr_customer';
const PHOTOGRAPHER = 'ctr_photographer';
const CONTACT = JSON.stringify({ phone: '+84903123456', allowZalo: true, allowWhatsApp: false });

function emulatorToken(uid) {
  const now = Math.floor(Date.now() / 1000);
  const enc = (o) => encoding.b64encode(JSON.stringify(o), 'rawurl');
  return `${enc({ alg: 'none', typ: 'JWT' })}.${enc({
    iss: `https://securetoken.google.com/${PROJECT}`, aud: PROJECT, sub: uid, user_id: uid,
    iat: now, auth_time: now, exp: now + 3600, firebase: { sign_in_provider: 'password', identities: {} },
  })}.`;
}

const asCustomer = { authorization: `Bearer ${emulatorToken(CUSTOMER)}`, 'content-type': 'application/json' };
const asPhotographer = { authorization: `Bearer ${emulatorToken(PHOTOGRAPHER)}` };
const params = (headers, op) => ({ headers, tags: { op } });

export const options = {
  scenarios: {
    slice: { executor: 'constant-arrival-rate', rate: 200, timeUnit: '1s', duration: '30s', preAllocatedVUs: 40, maxVUs: 100 },
  },
  thresholds: {
    http_req_failed: ['rate<0.001'],
    'http_req_duration{op:getUser}': ['p(95)<20'],
    'http_req_duration{op:getUserContact}': ['p(95)<20'],
    'http_req_duration{op:getContactChannels}': ['p(95)<20'],
    'http_req_duration{op:getContactNumbers}': ['p(95)<20'],
    'http_req_duration{op:saveUserContact}': ['p(95)<30'],
    'http_req_duration{op:getContactLink}': ['p(95)<35'],
  },
};

export function setup() {
  const r = http.put(`${BASE}/v1/users/${CUSTOMER}/contact`, CONTACT, { headers: asCustomer });
  if (r.status !== 200) throw new Error(`seed the contract world first (PUT contact answered ${r.status})`);
}

export default function () {
  const pick = Math.random();
  let res;
  if (pick < 0.3) res = http.get(`${BASE}/v1/users/${PHOTOGRAPHER}`, params(asCustomer, 'getUser'));
  else if (pick < 0.5) res = http.get(`${BASE}/v1/photographers/${PHOTOGRAPHER}/contact-channels`, params(asCustomer, 'getContactChannels'));
  else if (pick < 0.65) res = http.get(`${BASE}/v1/users/${CUSTOMER}/contact`, params(asCustomer, 'getUserContact'));
  else if (pick < 0.7) res = http.put(`${BASE}/v1/users/${CUSTOMER}/contact`, CONTACT, params(asCustomer, 'saveUserContact'));
  else if (pick < 0.8) res = http.get(`${BASE}/v1/photographers/${PHOTOGRAPHER}/contact-numbers`, params(asPhotographer, 'getContactNumbers'));
  else res = http.post(`${BASE}/v1/contact-links`, JSON.stringify({ bookingId: 'ctr_b_accepted', channel: 'zalo' }), params(asCustomer, 'getContactLink'));
  check(res, { '2xx': (r) => r.status >= 200 && r.status < 300 });
}
```

Run (from `services/api/`):

```bash
LOG_LEVEL=warn docker compose up --build -d
docker compose run --rm api node dist/tools/seed-contract.js
docker compose --profile perf run --rm k6; echo "k6 exit: $?"
docker compose down
```

Expected: k6 prints a `✓` next to every threshold line (`http_req_duration{op:getContactLink}…: p(95)=…ms` below 35, the others below 20/30, `http_req_failed…: 0.00%`) and `k6 exit: 0`. A failed threshold makes k6 exit 99: run it twice more; if the median of three runs still fails, profile before changing a budget (`EXPLAIN ANALYZE` the slow operation's query from Step 1, check `docker stats` for CPU throttling of the `api` container). Record the three runs' p95 per operation in the PR description.

- [ ] **Step 6: Manual check on a real Android phone**

Run the app against the stack (`AUTH_MODE=firebase FIREBASE_PROJECT_ID=<projectId from lib/firebase_options.dart> docker compose up -d`, then `flutter run --dart-define=BACKEND=selfhosted --dart-define=BASE_URL=http://<laptop LAN IP>:8787`). Open S42, save a number, open S34 and finish it, open a booking with Liên hệ and pick Zalo, then leave the app idle on Settings for 5 minutes. In `docker compose logs api` (set `LOG_LEVEL=info`) count the requests: one per action above, and **none** during the idle 5 minutes. In Android Studio's Network Inspector, all requests reuse the same connection (no new TCP handshake after the first). Record both in the PR description.

- [ ] **Step 7: Commit**

```bash
git add services/api app_flutter/test/data/http/http_battery_test.dart
git commit -m "perf(api): index-scan, payload, gzip and keep-alive checks, k6 latency budget, client battery tests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:**
  - data-model README §1 (domain independent of Firebase: rules imported from phase 1's pure module; ports unchanged on the client), §2.1 (ULID for new ids, Firebase uids kept, `auth_identities`), §2.2 (`timestamptz`, ISO UTC on the wire, `date` as `yyyy-MM-dd`), §2.3 (`bigint` → safe JS integer), §2.4 (string enum codes with `CHECK`), §2.6 (no URLs with tokens: `files` + `external` provider), §2.8 (camelCase wire, snake_case columns, stable error codes), §3 (`IdentityProvider` as a JWKS verifier, `Repository<T>` HTTP adapters), §4 (matrix rows of the slice tested table-driven: Tasks 5–7), §5 (`set_role`, `get_contact_link`), §6 step 2 (export/import with counts and checksums: Task 10) and step 4 (API, adapter chosen per repository: Tasks 1–9), §7.1 (Firebase imports only in adapters: untouched), §7.3 (one contract suite for Fake, Firestore, HTTP: Task 9), §7.4 (id/instant/money/enum conventions tested: Tasks 2–3), §7.5 (ids kept, counts and SHA-256: Task 10), §7.6 (matrix tests), §8 Q1–Q3 answered (PostgreSQL 16 + Kysely, TypeScript, ULID), Q5 deferred with a reason (Firebase Auth stays IdP until step 5).
  - relational-schema.md §1–§2 for `files`, `users`, `user_contacts`, `auth_identities`, `taxonomy_items`, `photographers`, `photographer_contact_channels`, `photographer_contact_numbers`, `services`, `bookings`, `booking_events`, `contact_access_log` (DDL verbatim, migration test column by column, constraints and indexes tested), §3 mapping for the slice, §5 order.
  - domain-model.md §5 "Mở khoá liên hệ" (`requested | accepted | upcoming | completed ≤ 30 days`; Task 3 shim tests, Task 7 world matrix), `ContactAccessLog` written once per answered request without numbers, invariant 10 (phone only in `user_contacts` / `photographer_contact_numbers`; contract test on schema names, body scans in Tasks 5–7).
  - Main spec §3b.1–§3b.4: contact channels only after booking, numbers never public, `contact_locked`, URL shapes identical to plan 2b's `contactUriFor` (cross-checked in Task 9), Vietnamese E.164 for customer and Zalo numbers, international for WhatsApp, `phoneVerified` server-only. §3g (escrow) and §6 order are respected by keeping money out of this slice.
  - Plans 2a/2b: every port method (`watch`, `save`, `ensureProfile`, `setRole`, `setDisplayName`, `watchChannels`, `watchNumbers`, `watchServiceArea`, `completeContactSetup`, `link`) has an HTTP implementation; the request/response/error contract of 2b's "Out of scope" section is served unchanged (`{bookingId|registrationId, channel}` → `{url}`, `code: contact_locked`, other codes generic).
- **Deviations (decided, recorded here and in the PR):**
  1. Cluster order: README §6 step 4 lists "nội dung → hồ sơ → …"; this slice takes identity/profile/contact first because client plans 2a/2b already define those ports, and content follows as the next plan.
  2. Two transport-only error codes (`unauthenticated`, `internal`) are added; `domain-model.md` §4 is edited in Task 3.
  3. The error body is flat `{code, message, requestId}` (the recommender's `Error` shape plus `requestId`) rather than nested under `error`.
  4. The Dart client is hand-written with a drift test instead of generated (decision 8).
  5. `registrationId` answers `not_found` until the events plan creates `event_registrations` (still logged in `contact_access_log`).
  6. `contact_locked` uses HTTP 403; clients use the code, not the status.
  7. HTTP `watch` is one GET plus the adapter's own writes, not realtime; changes from another device appear on the next subscription (decision 11).
  8. `bookings.chat_id` has no FK yet; `devices` and `booking_contacts` are not in the slice.
  9. Avatars are `files` rows with `storage_provider = 'external'`, including Firebase Storage URLs, until the Storage plan converts them to keys.
  10. `auth_identities` is filled by `POST /v1/me`, not exported from Firebase Auth (that export belongs to step 5).
  11. The Firestore run of the contracts uses `fake_cloud_firestore` (adapter behaviour; rules keep their emulator tests); the callable `FunctionsContactLinkRepository` is covered by phase 1's emulator tests, not by Task 9.
  12. Re-running the import touches no unchanged row; a changed row gets `updated_at` = import time (the trigger), not the Firestore value.
- **Placeholders:** none. Every file has full content; generated files (`src/generated/api.ts`, lock files) are produced by the commands given.
- **Type consistency:** `Principal`, `IdentityVerifier`, `JwksVerifier`, `EmulatorVerifier`, `ApiError`/`ApiErrorCode`, `RouteDeps`, `operation()`, `PublicProfile`, `UserContactDto`, `ChannelsDto`/`NumbersDto`/`AreaDto`, `ContactLinkRow`/`decideContactLink`, `seedContractWorld`/`contractWorld`, query builders `profileQuery`/`contactQuery`/`channelsQuery`/`numbersQuery`/`serviceAreaQuery`/`bookingContactQuery` (reused verbatim by the EXPLAIN test), `loadSlice`/`exportSlice`/`SLICE_TABLES`; on the client `BackendConfig`/`SelfhostedRepo`, `IdTokenSource`, `ApiClient`/`ApiException`, `fetchThenLocal`, `ApiPaths`/`apiOperations` and the four `Http*Repository` classes are spelled the same in code, tests and providers. Operation ids in `openapi.yaml`, the server routes, the k6 tags and `apiOperations` match.
- **Risks to watch:**
  1. Phase 1's domain module layout and names (Task 3 Step 1 is the only adaptation point; the shim test pins behaviour).
  2. `node-pg-migrate` 7 SQL migrations and its ESM `runner` export: if `import { runner } from 'node-pg-migrate'` fails, use `import pgMigrate from 'node-pg-migrate'; const { runner } = pgMigrate;` in `migrate.ts` only.
  3. Ajv/fast-json-stringify handling of `nullable` with `enum` and of `oneOf` with `required`-only branches; the error and contract tests fail loudly if a schema compiles differently.
  4. `Dockerfile.dockerignore` re-include rules (BuildKit): if the build misses files, list them in the build output with `docker compose build --progress=plain` and widen the `!` patterns.
  5. `fake_cloud_firestore` compatibility with `cloud_firestore ^6.10.0` (fallback in Task 9 Step 1).
  6. `flutter test` and real sockets in the selfhosted suite (`HttpOverrides.global = null`; the file uses no `testWidgets`).
  7. k6 numbers depend on the host (Docker Desktop on macOS adds network latency): take the median of three runs and record them.
  8. Android cleartext is enabled in the debug manifest only; release builds refuse `http` in `BackendConfig`.
- **Battery and performance:** Task 11: index scans for every slice query on realistic volumes, byte budgets per endpoint, gzip above 1 KiB, 65 s keep-alive, pool of 10 with the reasoning, k6 p95 thresholds with the exact command, and client tests for one request per action, no polling, no timers and one keep-alive client; manual phone check of idle traffic.

## From 2026-10-01-instant-i2-dispatch-core.md

#### Former task 12: Performance check

**Files:**
- Create: `packages/dispatch-core/bench/run.ts`
- Modify: `.github/workflows/dispatch-core.yml`

**Interfaces:**
- Consumes: `dispatchScorerV1`, `rankCandidates`, `quotePrice`, `quoteCancel`, `transition`, `seededRng`.
- Produces: `npm run bench` (script already in `package.json` since Task 1) printing p50/p95 per hot path and exiting 1 when a threshold is missed.

Budgets (p95 over repeated runs, after a JIT warm-up). The matcher service of plan I3 must stay under 50 ms p95 per run *including* Redis and PostgreSQL; the pure ranking below takes a small, fixed share of that:

| Hot path | Size | Threshold p95 | Measured (Node 24, Apple M-series laptop) |
|---|---|---|---|
| `score` one candidate | 2,000 per sample | < 5 µs | 0.31 µs |
| `rankCandidates` | 50 candidates (one `GEOSEARCH` page, `candidateLimit`) | < 0.5 ms | 0.03 ms |
| `rankCandidates` | 2,000 candidates (a whole city, worst case) | < 15 ms | 1.7 ms |
| `quotePrice` | per call | < 1 µs | 0.007 µs |
| `quoteCancel` | per call | < 2 µs | 0.32 µs |
| `transition` | per call | < 1 µs | 0.025 µs |

Thresholds leave roughly 10× headroom over the measurement so CI runners do not flake, while an accidental O(n²) sort, a regex in the hot loop or a per-candidate allocation storm still fails. Battery and network: this package does no I/O, so it has no direct battery cost; its only effect on the phone is through plan I3 (no polling, small payloads; see I3's Task 16).

- [ ] **Step 1: Write the benchmark**

```ts
// packages/dispatch-core/bench/run.ts
// Micro-benchmarks of dispatch-core hot paths (plan I2, Task 12). Run: npm run bench
// Exits 1 when a threshold is missed. Thresholds leave ~10× headroom over a 2023 laptop so CI
// noise does not flake, while still catching an accidental O(n²) or a per-call allocation storm.
import {
  DEFAULT_CONFIG, dispatchScorerV1, quoteCancel, quotePrice, rankCandidates, seededRng, transition,
  type OnlineCandidate, type PhotographerFacts,
} from '../src/index.js';

const rng = seededRng(99);
const MEET = { lat: 10.7725, lng: 106.698 };

function photographer(i: number): OnlineCandidate {
  const f: PhotographerFacts = {
    uid: `p${String(i).padStart(5, '0')}`,
    onboardingComplete: true,
    hasPhone: true,
    verified: rng() < 0.7,
    ratingAvg: 3.5 + rng() * 1.5,
    reviewCount: Math.floor(rng() * 60),
    acceptedPriceListVersion: 3,
    helpReady: rng() < 0.2,
    reliability: { offers: 40, accepted: Math.floor(rng() * 40), cancelled: Math.floor(rng() * 3), noShow: 0 },
    specialtyLevels: rng() < 0.1 ? null : { portrait: (1 + Math.floor(rng() * 3)) as 1 | 2 | 3 },
  };
  const km = rng() * 10;
  const angle = rng() * 2 * Math.PI;
  return { facts: f, location: { lat: MEET.lat + (km / 111.2) * Math.cos(angle), lng: MEET.lng + (km / 109.4) * Math.sin(angle) } };
}

interface Result { name: string; p50: number; p95: number; unit: string; limit: number }

function sample(name: string, runs: number, unit: 'ms' | 'µs', limit: number, f: () => void, perCall = 1): Result {
  for (let i = 0; i < Math.min(50, runs); i++) f(); // warm up the JIT
  const times: number[] = [];
  for (let i = 0; i < runs; i++) {
    const t0 = performance.now();
    f();
    const dt = performance.now() - t0;
    times.push(unit === 'ms' ? dt : (dt * 1000) / perCall);
  }
  times.sort((a, b) => a - b);
  const pick = (q: number) => times[Math.min(times.length - 1, Math.floor(q * times.length))] ?? Number.NaN;
  return { name, p50: pick(0.5), p95: pick(0.95), unit, limit };
}

const c50 = Array.from({ length: 50 }, (_, i) => photographer(i));
const c2000 = Array.from({ length: 2_000 }, (_, i) => photographer(i));
const scorer = dispatchScorerV1(DEFAULT_CONFIG);
const empty = new Set<string>();
const T0 = new Date('2026-10-01T08:00:00.000Z');
const later = new Date(T0.getTime() + 5 * 60_000);

const results: Result[] = [
  sample('score one candidate', 2_000, 'µs', 5, () => {
    for (const c of c2000) scorer.score({ facts: c.facts, distanceKm: 2, etaMinutes: 9 }, { genre: 'portrait', round: 1 });
  }, 2_000),
  sample('rankCandidates, 50 candidates (one GEOSEARCH page)', 2_000, 'ms', 0.5, () => {
    rankCandidates({ meetPoint: MEET, genre: 'portrait', round: 1, radiusKm: 10, currentPriceListVersion: 3, candidates: c50, excluded: empty, busy: empty }, DEFAULT_CONFIG, rng);
  }),
  sample('rankCandidates, 2,000 candidates (whole city)', 200, 'ms', 15, () => {
    rankCandidates({ meetPoint: MEET, genre: 'portrait', round: 2, radiusKm: 10, currentPriceListVersion: 3, candidates: c2000, excluded: empty, busy: empty }, DEFAULT_CONFIG, rng);
  }),
  sample('quotePrice', 200, 'µs', 1, () => {
    for (let i = 0; i < 1_000; i++) quotePrice(500_000 + i, 120, DEFAULT_CONFIG);
  }, 1_000),
  sample('quoteCancel', 200, 'µs', 2, () => {
    for (let i = 0; i < 1_000; i++) {
      quoteCancel({ actor: 'customer', status: 'en_route', collectedVnd: 600_000 + i, assignedAt: T0, arrivedAt: null, lateDeadline: null, now: later }, DEFAULT_CONFIG);
    }
  }, 1_000),
  sample('transition', 200, 'µs', 1, () => {
    for (let i = 0; i < 1_000; i++) {
      transition({ status: 'searching', assignedAt: null, arrivedAt: null, finishedAt: null, completedAt: null }, 'accept', later, DEFAULT_CONFIG);
    }
  }, 1_000),
];

let failed = false;
for (const r of results) {
  const ok = r.p95 < r.limit;
  failed ||= !ok;
  console.log(`${ok ? '✓' : '✗'} ${r.name}: p50 ${r.p50.toFixed(3)} ${r.unit}, p95 ${r.p95.toFixed(3)} ${r.unit} (limit p95 < ${r.limit} ${r.unit})`);
}
if (failed) {
  console.error('dispatch-core benchmark thresholds missed');
  process.exit(1);
}
```

- [ ] **Step 2: Run it**

Run: `npm run bench`
Expected: six `✓` lines, for example `✓ rankCandidates, 50 candidates (one GEOSEARCH page): p50 0.013 ms, p95 0.030 ms (limit p95 < 0.5 ms)`, and exit code 0. A `✗` line means a regression: profile with `node --cpu-prof --import tsx bench/run.ts` before touching a threshold.

- [ ] **Step 3: Run the benchmark in CI**

In `.github/workflows/dispatch-core.yml`, after `- run: npm test` add:

```yaml
      - run: npm run bench
```

- [ ] **Step 4: Full check**

Run: `npm run typecheck && npm run lint && npm test && npm run bench`
Expected: clean; `ℹ tests 284`, `ℹ pass 284`, `ℹ fail 0`; six `✓` benchmark lines.

- [ ] **Step 5: Commit**

```bash
git add packages/dispatch-core .github/workflows/dispatch-core.yml
git commit -m "perf(dispatch-core): micro-benchmarks of the scorer, matcher core and money rules with CI thresholds

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:**
  - §3.1 state machine: every pair of the 12 statuses × 14 events is tested against a hand-written table (Task 3), including the time guards (2 h auto-complete, 15 min no-show, 24 h dispute) and `photographer_cancel` going back to `searching` without the photographer.
  - §3.2: 30 s offers, round 1 ≤ 5 min with 3 → 6 → 10 km only when nobody is left, round 2 only with `expand` (10 km, ≤ 5 min), total ≤ 10 min (Task 10); one open offer per photographer and never re-offer are inputs of `rankCandidates` (`busy`, `excluded`, Task 9) that plan I3 fills from Redis locks and `instant_offers`; tiers with the exact thresholds and "chưa đủ dữ liệu" fallbacks (Task 7); score formula, help-ready bonus in round 1 only, reasons for logs (Task 8); ETA estimate (Task 4).
  - §4: price × surge rounded to 1,000 ₫, locked by the caller; payout rate config (default 80 %); every row of the cancellation table; `refund + photographer + platform = amount` for every rule over ~20,000 amounts each (Tasks 5–6).
  - §2.1 "Thường có người nhận trong khoảng {n} phút" (median, hidden below 20 samples), §2.2 / §10 arrival ≤ 200 m or forced with poor GPS, §6 one location per 5 s, §9 presence TTL value (Tasks 2, 11).
  - §11 "Domain (unit, không hạ tầng)": all of it, plus the purity test and lint.
- **Placeholders:** none. Every file is complete; `package-lock.json` is produced by `npm install`.
- **Type consistency:** `DispatchConfig`, `ConfigBook`, `PhotographerFacts`, `OnlineCandidate`, `RankedCandidate`, `SearchState`, `SearchStep`, `EmptyOutcome`, `CancelContext`, `CancelQuote`, `MoneySplit`, `ScoreReason`, `Scorer`, `RequestSnapshot`, `TransitionPatch` are spelled the same in code, tests, benchmarks and in plan I3 (which imports them through `services/dispatch/src/domain/core.ts`). Enum strings are tested literally against the contract.
- **Deviations (decided, recorded in the PR):**
  1. `assigned → arrived` is allowed (a photographer already at the meet point may never post a location); the spec diagram only shows `en_route → arrived`.
  2. A customer cancelling after `arrived` pays the `en_route_fee` (20 %); the §4 table has no row for it.
  3. A customer cancelling before payment gets rule `free_searching` with 0 ₫ (nothing was collected); the contract's `CancelRule` has no separate code.
  4. A photographer may not cancel from `arrived` except by reporting a no-show after 15 minutes (`conflict` before); the diagram allows `photographer_cancel` only up to `en_route`.
  5. The 20 % travel fee and the 50 % no-show share are taken from the amount paid (surge included), and the platform takes nothing on cancellations; §4 says "20 % giá gói" and does not mention a platform share.
  6. Round 2 may start before the 5-minute mark when round 1 has nobody even at 10 km (decision 6).
  7. The initial ETA of the lateness rule is the offer's estimate (decision 10), which is the more lenient for the photographer than Goong's ETA; the product owner may want Goong's first ETA instead (needs a column).
  8. `photographer_fault` increments the `no_show` reliability counter; `photographer_cancel` increments `cancelled`.
  9. `DISPATCH_ERROR_CODES` includes `limit_exceeded`, which plan I3 Task 1 adds to the contract's `ErrorCode` (the 429 of `postLocation` had no code).
- **Deferred:** dispute resolution rules (only the 24 h window to open one is here); ETA from Goong (plan I3, behind a port); surge time windows ("hệ số cao điểm và khung giờ", open question 1: v1 has one surge per city); a shared package for the `Scorer` shape once `recommender-core` exists.
- **Risks to watch:**
  1. Float noise in ETA rounding (handled with a 1e-9 epsilon and tested at exactly 10 km); keep `estimateEta` the single place that rounds minutes.
  2. Per-city overrides can make `radiusKm` values other than 3/6/10: plan I3 relaxes the contract's `radiusKm` enum to an integer range for that reason.
  3. Benchmark thresholds depend on the machine; they are deliberately loose (about 10×) and measured on a laptop, not a CI runner.

## From 2026-10-01-instant-i3-dispatch-service.md

#### Former task 16: Performance check

**Files:**
- Create: `services/dispatch/perf/simulate.ts`, `services/dispatch/perf/k6-dispatch.js`, `services/dispatch/test/perf-explain.test.ts`, `services/dispatch/test/budget.test.ts`, `services/dispatch/test/payload.test.ts`
- Modify: `services/api/docker-compose.yml`, `services/dispatch/package.json`, `services/dispatch/README.md`

**Interfaces:**
- Consumes: the hot query builders `requestQuery`, `activeRequestQuery`, `offeredQuery`, `pendingOfferQuery`, `busyQuery`; `GET /internal/metrics` (`matcher_ms`, `first_offer_ms`); the dev catalog (Task 8).
- Produces: EXPLAIN assertions for the hot queries; Redis command budgets per step; Firestore write budget per request; payload byte budgets; the load harness (`npm run simulate -- seed | online | bots [min] | report`) and k6 scenario with thresholds.

Budgets:

| What | Where | Budget | Why |
|---|---|---|---|
| First offer after payment | load test (`report`) | p95 < 2 s | spec §11 |
| Matcher run (Redis + PostgreSQL + ranking) | load test (`/internal/metrics`) | p95 < 50 ms | spec §11 |
| Duplicate offers | load test (`report`) | 0 photographers with two overlapping open offers; 0 re-offers | spec §3.2, §11 |
| `createRequest`, `devPaymentSucceed` | k6 | p95 < 300 ms / < 200 ms; `http_req_failed` < 1 % | customer waits on these |
| Hot queries | `perf-explain.test.ts` (60k requests, 180k offers) | index scans only, no `Seq Scan` | §2.8 indexes (+ Task 1's `instant_requests_customer`) |
| Redis commands | `budget.test.ts` | presence update ≤ 8; create + pay ≤ 8; matcher run that offers ≤ 14; accept ≤ 12; location ≤ 6; arrive ≤ 6; start + finish + confirm ≤ 12; whole request ≤ 110 | one command server per city cluster; ~1,700 commands/s at 100 requests/min with 2,000 photographers refreshing presence |
| Firestore writes per request | `budget.test.ts` | ≤ 25 (one request doc per change, one offer doc + delete, 10 track writes + delete) | billing and the app's listener traffic |
| Payloads | `payload.test.ts` | packages ≤ 640 B, create ≤ 160 B, accept ≤ 220 B, cancel quote ≤ 160 B; mirror request ≤ 1,100 B, offer ≤ 400 B, track ≤ 140 B; FCM data < 512 B (Task 5; the offer carries the whole offer) | radio time on 3G/4G |

`GET /v1/packages` reads the 7-day median from a 10-minute Redis cache (`typical:{city}`), so its seq-scan-prone aggregate runs at most 6 times an hour per city; the city lookup (`ST_Covers` on a handful of rows) is exempt from the no-seq-scan rule.

**Battery and network impact on the app (for plans I4/I5):** no polling anywhere — status, offers and the photographer's position arrive through Firestore listeners on three small documents, and FCM only wakes the app (high priority only for offers and assignment). While on the way, the app sends a fix every 10–15 s (spec §9); the server accepts at most one per 5 s (429 `limit_exceeded` beyond, so a buggy client cannot drain the battery or the quota) and calls Goong at most once a minute. While available, the app re-sends presence only when it moved > 300 m or every 5 minutes, before `expiresAt` (10-minute TTL). The track document is deleted at arrival, so the customer's listener goes quiet and the map can stop.

- [ ] **Step 1: Write the server tests**

```ts
// services/dispatch/test/perf-explain.test.ts
import { CompiledQuery, sql, type Compilable } from 'kysely';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { busyQuery, offeredQuery, pendingOfferQuery } from '../src/matcher/matcher.js';
import { activeRequestQuery } from '../src/requests/create.js';
import { requestQuery } from '../src/requests/rows.js';
import { T0, resetAll, seedCatalog, testDb, testRedis } from './helpers.js';

interface PlanNode {
  'Node Type': string;
  'Relation Name'?: string;
  'Index Name'?: string;
  Plans?: PlanNode[];
}
const db = testDb();
const redis = testRedis();
const nodes = (n: PlanNode): PlanNode[] => [n, ...(n.Plans ?? []).flatMap(nodes)];

async function explain(q: Compilable): Promise<PlanNode[]> {
  const c = q.compile();
  const r = await db.executeQuery<{ 'QUERY PLAN': Array<{ Plan: PlanNode }> }>(CompiledQuery.raw(`explain (format json) ${c.sql}`, [...c.parameters]));
  return nodes(r.rows[0]!['QUERY PLAN'][0]!.Plan);
}

beforeAll(async () => {
  await resetAll(db, redis);
  await seedCatalog(db);
  // A busy month: 20k customers, 2k photographers, 60k requests, 180k offers.
  await sql`insert into users (id, display_name, role) select 'c' || g, 'C', 'customer' from generate_series(1, 20000) g`.execute(db);
  await sql`insert into users (id, display_name, role) select 'p' || g, 'P', 'photographer' from generate_series(1, 2000) g`.execute(db);
  await sql`insert into photographers (user_id, onboarding_complete) select 'p' || g, true from generate_series(1, 2000) g`.execute(db);
  await sql`insert into dispatch.instant_requests (id, customer_id, package_id, city_id, genre, meet_point, meet_address,
      amount_vnd, payout_vnd, status, photographer_id, requested_at, assigned_at)
    select 'r' || g, 'c' || (g % 20000 + 1), '01J9ZP60000000000000000000', case when g % 3 = 0 then 'hn' else 'hcm' end, 'portrait',
      'SRID=4326;POINT(106.698 10.7725)', 'x', 600000, 480000,
      case when g % 500 = 0 then 'en_route' when g % 7 = 0 then 'no_match' else 'completed' end,
      case when g % 500 = 0 then 'p' || (g / 500) when g % 7 = 0 then null else 'p' || (g % 2000 + 1) end,
      ${T0}::timestamptz - (g || ' minutes')::interval, ${T0}::timestamptz - (g || ' minutes')::interval + interval '6 minutes'
    from generate_series(1, 60000) g`.execute(db);
  await sql`insert into dispatch.instant_offers (id, request_id, photographer_id, round, score, reasons, offered_at, expires_at, outcome)
    select 'o' || g || '_' || k, 'r' || g, 'p' || ((g + k * 7) % 2000 + 1), 1, 0.5, '[]', ${T0}, ${T0}, 'declined'
    from generate_series(1, 60000) g, generate_series(1, 3) k`.execute(db);
  await sql`analyze`.execute(db);
}, 180_000);
afterAll(async () => {
  await resetAll(db, redis);
  redis.disconnect();
  await db.destroy();
});

const INDEX_NODES = new Set(['Index Scan', 'Index Only Scan', 'Bitmap Index Scan']);
const ids = Array.from({ length: 50 }, (_, i) => `p${i * 40 + 1}`);

describe('hot queries use the indexes of relational-schema.md §2.8', () => {
  it.each<[string, () => Compilable, string[]]>([
    ['load request (every operation)', () => requestQuery(db, 'r12345'), ['instant_requests_pkey', 'instant_packages_pkey']],
    ['one open request per customer (create)', () => activeRequestQuery(db, 'c123'), ['instant_requests_customer']],
    ['offered before (matcher)', () => offeredQuery(db, 'r12345'), ['instant_offers_request']],
    ['pending offer of a request (matcher)', () => pendingOfferQuery(db, 'r12345'), ['instant_offers_request']],
    ['busy photographers among 50 candidates (matcher)', () => busyQuery(db, ids), ['instant_requests_one_open_job']],
  ])('%s: no sequential scan on a large table', async (_name, build, indexes) => {
    const plan = await explain(build());
    expect(plan.filter((n) => n['Node Type'] === 'Seq Scan').map((n) => n['Relation Name'])).toEqual([]);
    expect(plan.filter((n) => INDEX_NODES.has(n['Node Type'])).map((n) => n['Index Name'])).toEqual(expect.arrayContaining(indexes));
  });
});
```

```ts
// services/dispatch/test/budget.test.ts
import type { FastifyInstance } from 'fastify';
import type { Redis } from 'ioredis';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import {
  HCM, addCustomer, addPhotographer, as, fixAt, north, online, paidRequest, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld, type TestWorld,
} from './helpers.js';

/** Counts every command our Redis client sends (BullMQ uses its own connection; ManualScheduler here). */
function counting(redis: Redis): { reset(): void; count(): number; names(): Record<string, number> } {
  const seen: Record<string, number> = {};
  const original = redis.sendCommand.bind(redis);
  redis.sendCommand = ((cmd: { name: string }, ...rest: unknown[]) => {
    seen[cmd.name] = (seen[cmd.name] ?? 0) + 1;
    return (original as (...a: unknown[]) => unknown)(cmd, ...rest);
  }) as typeof redis.sendCommand;
  return {
    reset: () => { for (const k of Object.keys(seen)) delete seen[k]; },
    count: () => Object.values(seen).reduce((a, b) => a + b, 0),
    names: () => ({ ...seen }),
  };
}

const db = testDb();
const redis = testRedis();
const meter = counting(redis);
let w: TestWorld;
let app: FastifyInstance;
beforeAll(async () => {
  await resetAll(db, redis);
  w = testWorld(db, redis);
  app = await testApp(w);
  await seedCatalog(db);
  await addCustomer(db, 'c1');
  for (let i = 0; i < 20; i++) await addPhotographer(db, `p${i}`);
});
afterAll(async () => {
  await app.close();
  redis.disconnect();
  await db.destroy();
});

describe('Redis and Firestore budget of one request (spec §5; Task 16)', () => {
  it('stays within the per-step command budgets and the mirror write budget', async () => {
    const steps: Record<string, number> = {};
    const measure = async (name: string, budget: number, f: () => Promise<unknown>) => {
      meter.reset();
      await f();
      steps[name] = meter.count();
      expect(meter.count(), `${name}: ${JSON.stringify(meter.names())}`).toBeLessThanOrEqual(budget);
    };
    for (let i = 0; i < 20; i++) await online(app, `p${i}`, north(HCM, 0.3 + i * 0.1), w.clock.now());
    await measure('presence update', 8, () => online(app, 'p0', north(HCM, 0.3), w.clock.now()));
    w.mirror.writes = 0;
    let id = '';
    await measure('create + pay', 8, async () => {
      id = await paidRequest(app, 'c1');
    });
    await measure('matcher run that offers', 14, () => w.runDue());
    const offer = await db.selectFrom('dispatch.instant_offers').select(['id', 'photographer_id']).where('request_id', '=', id).executeTakeFirstOrThrow();
    await measure('accept', 12, () => app.inject({ method: 'POST', url: `/v1/offers/${offer.id}/accept`, headers: as(offer.photographer_id) }));
    for (let i = 0; i < 10; i++) {
      await redis.del(`locgate:${id}`);
      await measure(`location ${i}`, 6, () => app.inject({ method: 'POST', url: `/v1/requests/${id}/location`, headers: as(offer.photographer_id), payload: fixAt(north(HCM, 0.3 - i * 0.02), w.clock.now()) }));
    }
    await measure('arrive', 6, () => app.inject({ method: 'POST', url: `/v1/requests/${id}/arrive`, headers: as(offer.photographer_id), payload: { fix: fixAt(HCM, w.clock.now()) } }));
    await measure('start + finish + confirm', 12, async () => {
      await app.inject({ method: 'POST', url: `/v1/requests/${id}/start`, headers: as(offer.photographer_id) });
      await app.inject({ method: 'POST', url: `/v1/requests/${id}/finish`, headers: as(offer.photographer_id) });
      await app.inject({ method: 'POST', url: `/v1/requests/${id}/confirm-complete`, headers: as('c1') });
    });
    const total = Object.entries(steps).filter(([k]) => k !== 'presence update').reduce((s, [, v]) => s + v, 0);
    expect(total, JSON.stringify(steps)).toBeLessThanOrEqual(110);
    // Firestore: one request doc per state change, one offer doc, ten track writes, one delete each.
    expect(w.mirror.writes).toBeLessThanOrEqual(25);
    console.log('redis commands per step', steps, 'mirror writes', w.mirror.writes);
  });
});
```

```ts
// services/dispatch/test/payload.test.ts
import type { FastifyInstance } from 'fastify';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import {
  HCM, PACKAGES, addCustomer, addPhotographer, as, north, online, resetAll, seedCatalog, testApp, testDb, testRedis, testWorld, type TestWorld,
} from './helpers.js';

const db = testDb();
const redis = testRedis();
let w: TestWorld;
let app: FastifyInstance;
beforeAll(async () => {
  await resetAll(db, redis);
  w = testWorld(db, redis);
  app = await testApp(w);
  await seedCatalog(db);
  await addCustomer(db, 'c1');
  await addPhotographer(db, 'p1');
  await online(app, 'p1', north(HCM, 0.5), w.clock.now());
});
afterAll(async () => {
  await app.close();
  redis.disconnect();
  await db.destroy();
});

const bytes = (v: unknown) => Buffer.byteLength(JSON.stringify(v));

describe('payload sizes (mobile radio time and Firestore document size; Task 16)', () => {
  it('API responses and mirror documents stay small', async () => {
    const pk = await app.inject({ method: 'GET', url: '/v1/packages?cityId=hcm', headers: as('c1') });
    expect(pk.rawPayload.byteLength).toBeLessThanOrEqual(640);
    const created = await app.inject({
      method: 'POST', url: '/v1/requests', headers: as('c1'),
      payload: { packageId: PACKAGES.p60, genre: 'portrait', meetPoint: { ...HCM, address: '12 Lê Lợi, Phường Bến Thành, Quận 1, Hồ Chí Minh' }, expand: false, expectedAmountVnd: 600_000, provider: 'fake' },
    });
    expect(created.rawPayload.byteLength).toBeLessThanOrEqual(160);
    const id = (created.json() as { requestId: string }).requestId;
    await app.inject({ method: 'POST', url: `/v1/dev/payments/${id}/succeed`, headers: as('c1') });
    await w.runDue();
    expect(bytes(w.mirror.offers.get('p1'))).toBeLessThanOrEqual(400);
    const offer = await db.selectFrom('dispatch.instant_offers').select('id').executeTakeFirstOrThrow();
    const acc = await app.inject({ method: 'POST', url: `/v1/offers/${offer.id}/accept`, headers: as('p1') });
    expect(acc.rawPayload.byteLength).toBeLessThanOrEqual(220);
    expect(bytes(w.mirror.requests.get(id))).toBeLessThanOrEqual(1_100);
    const quote = await app.inject({ method: 'POST', url: `/v1/requests/${id}/cancel`, headers: as('c1'), payload: { dryRun: true } });
    expect(quote.rawPayload.byteLength).toBeLessThanOrEqual(160);
    await app.inject({ method: 'POST', url: `/v1/requests/${id}/location`, headers: as('p1'), payload: { ...north(HCM, 0.4), accuracyM: 8, headingDeg: 180, speedMps: 6, at: w.clock.now().toISOString() } });
    expect(bytes(w.mirror.tracks.get(id))).toBeLessThanOrEqual(140);
  });
});
```

- [ ] **Step 2: Run them**

Run: `npm test -- test/perf-explain.test.ts test/budget.test.ts test/payload.test.ts`
Expected: PASS (5 + 1 + 1); the whole suite (`npm test`) now reports `Test Files  20 passed | 1 skipped (21)`, `Tests  100 passed | 3 skipped (103)`; `budget.test.ts` prints the commands per step and the mirror writes. If a plan shows `Seq Scan`, the query does not match an index of §2.8: rewrite the query; add an index only together with a `relational-schema.md` edit and a new migration. If a budget is exceeded, the printed per-command counts show which call crept in.

- [ ] **Step 3: Write the load harness and the k6 scenario**

```ts
// services/dispatch/perf/simulate.ts
// Load-test harness for services/dispatch (plan I3, Task 16; spec §11 "Tải").
//   npm run simulate -- seed      2,000 photographers in 3 cities, 1,200 customers with phones
//   npm run simulate -- online    every photographer PUT /v1/presence (emulator tokens)
//   npm run simulate -- bots 11   photographers answer offers for 11 minutes (accept 70 %, decline 15 %, ignore 15 %)
//   npm run simulate -- report    first-offer p95, matcher p95, duplicate offers; exit 1 on a missed threshold
// Env: DATABASE_URL (host port of the compose db), API_URL (default http://localhost:8090), FIREBASE_PROJECT_ID.
import { sql } from 'kysely';

import { createDb } from '../src/db/database.js';
import { seededRng } from '../src/domain/core.js';
import { DEV_CITIES, seedDev } from '../src/tools/seed-dev.js';

const API = process.env.API_URL ?? 'http://localhost:8090';
const PROJECT = process.env.FIREBASE_PROJECT_ID ?? 'demo-nag';
export const PHOTOGRAPHERS = 2_000;
export const CUSTOMERS = 1_200;
const pid = (i: number) => `sim_p_${String(i).padStart(4, '0')}`;
const cid = (i: number) => `sim_c_${String(i).padStart(4, '0')}`;
/** 50 % HCM, 35 % HN, 15 % DN. */
const cityOf = (i: number) => (i % 20 < 10 ? DEV_CITIES[0] : i % 20 < 17 ? DEV_CITIES[1] : DEV_CITIES[2]);

function token(uid: string): string {
  const now = Math.floor(Date.now() / 1000);
  const enc = (v: object) => Buffer.from(JSON.stringify(v)).toString('base64url');
  return `${enc({ alg: 'none', typ: 'JWT' })}.${enc({
    iss: `https://securetoken.google.com/${PROJECT}`, aud: PROJECT, sub: uid, user_id: uid, iat: now, auth_time: now, exp: now + 6 * 3600,
    firebase: { sign_in_provider: 'password', identities: {} },
  })}.`;
}

async function call(uid: string, method: string, path: string, body?: unknown): Promise<{ status: number; json: unknown }> {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: { authorization: `Bearer ${token(uid)}`, ...(body === undefined ? {} : { 'content-type': 'application/json' }) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, json: text ? (JSON.parse(text) as unknown) : null };
}

function spot(i: number) {
  const rng = seededRng(i + 1);
  const c = cityOf(i);
  const km = rng() * 8;
  const a = rng() * 2 * Math.PI;
  return { lat: c.center.lat + (km / 111.2) * Math.cos(a), lng: c.center.lng + (km / 109.0) * Math.sin(a) };
}

async function pool<T>(items: T[], size: number, f: (t: T) => Promise<void>): Promise<void> {
  let next = 0;
  await Promise.all(Array.from({ length: size }, async () => {
    while (next < items.length) await f(items[next++] as T);
  }));
}

const db = createDb(process.env.DATABASE_URL ?? 'postgres://nag:nag_local_only@localhost:5433/nag', 10);
const cmd = process.argv[2];

if (cmd === 'seed') {
  await seedDev(db);
  await sql`insert into users (id, display_name, role) select 'sim_c_' || lpad(g::text, 4, '0'), 'Khách ' || g, 'customer'
    from generate_series(0, ${sql.lit(CUSTOMERS - 1)}) g on conflict do nothing`.execute(db);
  await sql`insert into user_contacts (user_id, phone_e164) select 'sim_c_' || lpad(g::text, 4, '0'), '+8490' || lpad(g::text, 7, '0')
    from generate_series(0, ${sql.lit(CUSTOMERS - 1)}) g on conflict do nothing`.execute(db);
  await sql`insert into users (id, display_name, role) select 'sim_p_' || lpad(g::text, 4, '0'), 'Thợ ' || g, 'photographer'
    from generate_series(0, ${sql.lit(PHOTOGRAPHERS - 1)}) g on conflict do nothing`.execute(db);
  await sql`insert into photographers (user_id, onboarding_complete, verified, rating_avg, review_count)
    select 'sim_p_' || lpad(g::text, 4, '0'), true, g % 4 <> 0, 4.2 + (g % 8) / 10.0, g % 30
    from generate_series(0, ${sql.lit(PHOTOGRAPHERS - 1)}) g on conflict do nothing`.execute(db);
  await sql`insert into photographer_contact_numbers (photographer_id, phone_e164) select 'sim_p_' || lpad(g::text, 4, '0'), '+8491' || lpad(g::text, 7, '0')
    from generate_series(0, ${sql.lit(PHOTOGRAPHERS - 1)}) g on conflict do nothing`.execute(db);
  await sql`insert into dispatch.photographer_instant_settings (photographer_id, price_list_version_accepted, help_ready, updated_at)
    select 'sim_p_' || lpad(g::text, 4, '0'), 1, g % 5 = 0, now() from generate_series(0, ${sql.lit(PHOTOGRAPHERS - 1)}) g on conflict do nothing`.execute(db);
  console.log(`seeded ${PHOTOGRAPHERS} photographers, ${CUSTOMERS} customers, 3 cities`);
} else if (cmd === 'online') {
  let ok = 0;
  await pool([...Array(PHOTOGRAPHERS).keys()], 50, async (i) => {
    const r = await call(pid(i), 'PUT', '/v1/presence', { online: true, fix: { ...spot(i), accuracyM: 30, at: new Date().toISOString() } });
    if (r.status === 200) ok++;
  });
  console.log(`online: ${ok}/${PHOTOGRAPHERS}`);
} else if (cmd === 'bots') {
  const minutes = Number(process.argv[3] ?? 11);
  const end = Date.now() + minutes * 60_000;
  const seen = new Set<string>();
  const rng = seededRng(2026);
  const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
  let lastRefresh = Date.now();
  const trip = async (uid: string, requestId: string, meet: { lat: number; lng: number }, customer: string) => {
    await sleep(2_000);
    await call(uid, 'POST', `/v1/requests/${requestId}/location`, { ...meet, accuracyM: 10, at: new Date().toISOString() });
    await call(uid, 'POST', `/v1/requests/${requestId}/arrive`, { fix: { ...meet, accuracyM: 10, at: new Date().toISOString() } });
    await call(uid, 'POST', `/v1/requests/${requestId}/start`);
    await sleep(2_000);
    await call(uid, 'POST', `/v1/requests/${requestId}/finish`);
    await call(customer, 'POST', `/v1/requests/${requestId}/confirm-complete`);
  };
  while (Date.now() < end) {
    const pending = await db
      .selectFrom('dispatch.instant_offers as o')
      .innerJoin('dispatch.instant_requests as r', 'r.id', 'o.request_id')
      .select(['o.id', 'o.photographer_id', 'o.request_id', 'r.customer_id'])
      .where('o.outcome', '=', 'pending')
      .where('o.photographer_id', 'like', 'sim_p_%')
      .execute();
    for (const o of pending) {
      if (seen.has(o.id)) continue;
      seen.add(o.id);
      const roll = rng();
      const delay = 1_000 + rng() * 4_000;
      void (async () => {
        await sleep(delay);
        if (roll < 0.7) {
          const r = await call(o.photographer_id, 'POST', `/v1/offers/${o.id}/accept`);
          if (r.status === 200) {
            const meet = (r.json as { meetPoint: { lat: number; lng: number } }).meetPoint;
            await trip(o.photographer_id, o.request_id, meet, o.customer_id);
          }
        } else if (roll < 0.85) {
          await call(o.photographer_id, 'POST', `/v1/offers/${o.id}/decline`, { reason: 'busy' });
        }
      })();
    }
    if (Date.now() - lastRefresh > 4 * 60_000) {
      lastRefresh = Date.now();
      void pool([...Array(PHOTOGRAPHERS).keys()], 20, async (i) => {
        await call(pid(i), 'PUT', '/v1/presence', { online: true, fix: { ...spot(i), accuracyM: 30, at: new Date().toISOString() } });
      });
    }
    await sleep(300);
  }
  console.log(`bots: answered ${seen.size} offers`);
} else if (cmd === 'report') {
  const first = await sql<{ p50: number; p95: number; n: number }>`
    with starts as (
      select p.subject_id as request_id, min(l.at) as search_at from ledger_entries l join payments p on p.id = l.payment_id
      where l.type = 'deposit_received' and p.subject_type = 'instant_request' group by p.subject_id),
    firsts as (
      select o.request_id, min(o.offered_at) as first_at from dispatch.instant_offers o group by o.request_id)
    select percentile_cont(0.5) within group (order by extract(epoch from f.first_at - s.search_at) * 1000) as p50,
           percentile_cont(0.95) within group (order by extract(epoch from f.first_at - s.search_at) * 1000) as p95,
           count(*)::int as n
    from starts s join firsts f using (request_id)`.execute(db);
  const dup = await sql<{ n: number }>`
    select count(*)::int as n from dispatch.instant_offers a join dispatch.instant_offers b
      on a.photographer_id = b.photographer_id and a.id < b.id
     and a.offered_at < least(coalesce(b.decided_at, b.expires_at), b.expires_at)
     and b.offered_at < least(coalesce(a.decided_at, a.expires_at), a.expires_at)`.execute(db);
  const reoffer = await sql<{ n: number }>`
    select count(*)::int as n from (select request_id, photographer_id from dispatch.instant_offers group by 1, 2 having count(*) > 1) x`.execute(db);
  const statuses = await sql<{ status: string; n: number }>`select status, count(*)::int as n from dispatch.instant_requests group by status order by 2 desc`.execute(db);
  const metrics = (await (await fetch(`${API}/internal/metrics`)).json()) as Record<string, { p95: number; count: number }>;
  const f = first.rows[0] ?? { p50: Number.NaN, p95: Number.NaN, n: 0 };
  const checks: Array<[string, boolean, string]> = [
    ['first offer p95 < 2 s', Number(f.p95) < 2_000, `${Math.round(Number(f.p95))} ms over ${f.n} requests (p50 ${Math.round(Number(f.p50))} ms)`],
    ['matcher p95 < 50 ms', (metrics.matcher_ms?.p95 ?? Infinity) < 50, `${metrics.matcher_ms?.p95?.toFixed(1)} ms over ${metrics.matcher_ms?.count} runs`],
    ['no photographer holds two open offers', (dup.rows[0]?.n ?? 1) === 0, `${dup.rows[0]?.n} overlaps`],
    ['nobody offered the same request twice', (reoffer.rows[0]?.n ?? 1) === 0, `${reoffer.rows[0]?.n} pairs`],
  ];
  console.log('requests by status', Object.fromEntries(statuses.rows.map((r) => [r.status, r.n])));
  for (const [name, ok, detail] of checks) console.log(`${ok ? '✓' : '✗'} ${name}: ${detail}`);
  await db.destroy();
  process.exit(checks.every(([, ok]) => ok) ? 0 : 1);
} else {
  console.error('usage: simulate seed | online | bots [minutes] | report');
  process.exit(2);
}
await db.destroy();
```

```js
// services/dispatch/perf/k6-dispatch.js
// Customer load for services/dispatch (plan I3, Task 16; spec §11): 100 requests per minute for 10 minutes
// across 3 cities, each paid through the fake gateway. Run with `npm run simulate -- bots 11` alongside.
import http from 'k6/http';
import { check } from 'k6';
import exec from 'k6/execution';
import encoding from 'k6/encoding';

const BASE = __ENV.API_URL || 'http://dispatch:8090';
const PROJECT = __ENV.FIREBASE_PROJECT_ID || 'demo-nag';
const CITIES = [
  { id: 'hcm', lat: 10.7769, lng: 106.7009 },
  { id: 'hn', lat: 21.0278, lng: 105.8342 },
  { id: 'dn', lat: 16.0544, lng: 108.2022 },
];

function token(uid) {
  const now = Math.floor(Date.now() / 1000);
  const enc = (o) => encoding.b64encode(JSON.stringify(o), 'rawurl');
  return `${enc({ alg: 'none', typ: 'JWT' })}.${enc({
    iss: `https://securetoken.google.com/${PROJECT}`, aud: PROJECT, sub: uid, user_id: uid, iat: now, auth_time: now, exp: now + 3600,
    firebase: { sign_in_provider: 'password', identities: {} },
  })}.`;
}

export const options = {
  scenarios: {
    customers: { executor: 'constant-arrival-rate', rate: 100, timeUnit: '1m', duration: '10m', preAllocatedVUs: 20, maxVUs: 60 },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    'http_req_duration{op:createRequest}': ['p(95)<300'],
    'http_req_duration{op:devPaymentSucceed}': ['p(95)<200'],
  },
};

export function setup() {
  const prices = {};
  for (const c of CITIES) {
    const r = http.get(`${BASE}/v1/packages?cityId=${c.id}`, { headers: { authorization: `Bearer ${token('sim_c_0000')}` } });
    if (r.status !== 200) throw new Error(`seed first: GET /v1/packages ${c.id} answered ${r.status}`);
    const p60 = r.json('packages').find((p) => p.code === 'p60');
    prices[c.id] = { packageId: p60.id, amount: p60.priceVnd };
  }
  return prices;
}

export default function (prices) {
  const i = exec.scenario.iterationInTest;
  const uid = `sim_c_${String(i).padStart(4, '0')}`;
  const city = CITIES[i % 3];
  const jitter = (n) => (Math.random() - 0.5) * n;
  const headers = { authorization: `Bearer ${token(uid)}`, 'content-type': 'application/json' };
  const body = {
    packageId: prices[city.id].packageId, genre: 'portrait',
    meetPoint: { lat: city.lat + jitter(0.08), lng: city.lng + jitter(0.08), address: 'Điểm hẹn thử tải' },
    expand: i % 4 === 0, expectedAmountVnd: prices[city.id].amount, provider: 'fake',
  };
  const created = http.post(`${BASE}/v1/requests`, JSON.stringify(body), { headers, tags: { op: 'createRequest' } });
  if (!check(created, { 'created 201': (r) => r.status === 201 })) return;
  const id = created.json('requestId');
  const paid = http.post(`${BASE}/v1/dev/payments/${id}/succeed`, null, { headers: { authorization: headers.authorization }, tags: { op: 'devPaymentSucceed' } });
  check(paid, { 'paid 204': (r) => r.status === 204 });
}
```

In `services/dispatch/package.json` add the script:

```json
    "simulate": "node --import tsx perf/simulate.ts"
```

In `services/api/docker-compose.yml` add the service:

```yaml
  k6-dispatch:
    image: grafana/k6:0.54.0
    profiles: [perf]
    command: ["run", "/perf/k6-dispatch.js"]
    environment:
      API_URL: http://dispatch:8090
      FIREBASE_PROJECT_ID: ${FIREBASE_PROJECT_ID:-demo-nag}
    volumes:
      - ../dispatch/perf:/perf:ro
    depends_on:
      dispatch: { condition: service_healthy }
```

Append to `services/dispatch/README.md`:

````markdown
## Pin và mạng của ứng dụng

- Ứng dụng **không cần hỏi lại (polling)**: trạng thái, lời mời và vị trí đến qua listener Firestore (`instant_requests/{id}`, `instant_offers/{uid}`, `instant_tracks/{id}`); FCM chỉ đánh thức app.
- Vị trí khi đang đến: dịch vụ nhận tối đa 1 lần / 5 giây (429 `limit_exceeded`); ứng dụng gửi 10–15 giây một lần (spec §9). Khi sẵn sàng: gửi lại khi đi > 300 m hoặc 5 phút, trước `expiresAt` (TTL 10 phút).
- Goong Distance Matrix chỉ cho người đã nhận, tối đa 1 lần / phút / yêu cầu.
- Kiểm tra hiệu năng (plan I3 Task 16): `npm run simulate -- seed|online|bots|report` và k6 (`docker compose --profile perf run --rm k6-dispatch`).
````

- [ ] **Step 4: Run the load test (2,000 photographers, 3 cities, 100 requests/min for 10 min)**

```bash
cd services/api
LOG_LEVEL=warn docker compose up --build -d
cd ../dispatch
export DATABASE_URL=postgres://nag:nag_local_only@localhost:5433/nag API_URL=http://localhost:8090
npm run simulate -- seed
npm run simulate -- online
curl -s -X POST localhost:8090/internal/metrics/reset
npm run simulate -- bots 11 &          # photographers answer offers while k6 runs
(cd ../api && docker compose --profile perf run --rm k6-dispatch); echo "k6 exit: $?"
wait
npm run simulate -- report; echo "report exit: $?"
cd ../api && docker compose down
```

Expected: `online: 2000/2000`; k6 prints `✓` for `http_req_failed`, `http_req_duration{op:createRequest}` and `{op:devPaymentSucceed}` and `k6 exit: 0`; `report` prints `requests by status { completed: …, no_match: …, … }` and four `✓` lines (`first offer p95 < 2 s`, `matcher p95 < 50 ms`, `no photographer holds two open offers`, `nobody offered the same request twice`) and `report exit: 0`. Run the whole sequence three times and record the medians in the PR. If a threshold fails twice, profile before changing it: `EXPLAIN ANALYZE` the matcher queries from Step 1, `redis-cli --latency` against port 6380, and `docker stats` for CPU throttling of `dispatch`.

- [ ] **Step 5: Commit**

```bash
git add services/dispatch services/api/docker-compose.yml
git commit -m "perf(dispatch): EXPLAIN, Redis and Firestore budgets, payload sizes, load harness and k6 scenario

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:**
  - §2.1 customer flow: packages and typical match time (Task 8), phone check and price lock, payment then `searching` only on a verified webhook (Task 10), S48 radius/round/end in the mirror (Tasks 10–11), S49 photographer card, ETA, grace window (Task 12), arrival and shoot (Task 13), no-match refund (Task 11), S55 cancel with `dryRun` (Task 14). §2.2 photographer flow: S52 settings and presence with readiness reasons (Task 9), S53 offer doc with neighbourhood area, payout, distance, travel time, 30 s, high-priority push (Task 11), accept/decline (Task 12), S54 tracking, ≤ 200 m arrival or forced with reason (Task 13), one open job (index + Task 12 test).
  - §3.1 all transitions through `transition()` (plan I2) in every write path; §3.2 rounds, radius, 30 s, total 10 min, one open offer per photographer (`offerlock`), never re-offer (`excluded` + unique index) (Tasks 11, 15).
  - §4 prices, payout, escrow, the cancellation table, ledger entries and the invariant (Tasks 10, 13, 14; `heldVnd` checks in tests).
  - §5 modules presence / matcher / offers / tracking / payments / api, Redis GEO + `SET NX PX` + BullMQ, PostgreSQL row locks, Firestore read-only mirror, Goong only for the accepted photographer (Tasks 5–14); deployment in compose with schema `dispatch` (Tasks 6–7).
  - §6 every operation of the contract (contract test with an empty `PENDING` after Task 14) plus the webhook GET added in Task 1.
  - §7 DDL verbatim after the Task 1 fixes, indexes, no presence in PostgreSQL, one track document deleted at the end, Firestore rules (Task 4).
  - §9 presence TTL, location rate limit, no history (Tasks 9, 13, 16). §10 edge cases: payment failure and timeout, late payment refunded, two accepts, expiry at the boundary, lost FCM (mirror), Goong failure (estimate), outside area, price change, too far, auto-complete, restart (Tasks 10–15).
  - §11 service tests (concurrency, timers, TTL, restart) and load test with the three thresholds (Tasks 15–16); rules tests (Task 4).
- **Placeholders:** none. Generated files (`src/generated/api.ts`, `package-lock.json`) come from the commands given; `jobHandlers` starts empty in Task 6 by design and gains its handlers in Tasks 10–15.
- **Type consistency:** `Deps`/`RouteDeps`, `RequestRow`, `SearchRecord`, `TripRecord`, `MirrorWriter` and the three `*Mirror` types, `PushMessage`, `EtaProvider`/`AreaResolver`, `Scheduler`/`JobHandlers`/`JobName`, the `PaymentGateway` family (`CreatePaymentInput`, `WebhookRequest`, `PaymentEvent`, `WebhookOutcome`, `WebhookAck`, `RefundInput`, `RefundResult`, `PaymentGateways`), `CancelResult`, `AcceptResult`, `MatchResult` are spelled the same in code, tests, the load harness and this plan's interface lists. Every task's file set was type-checked as a staged tree while writing the plan.
- **Contract changes (Task 1):** `limit_exceeded` in `ErrorCode`; 404 on seven operations; `arrive` 422 documented; webhook path-level parameter, provider-defined 200/204, new `GET` (`paymentWebhookQuery`) for VNPay IPN; `radiusKm` integer 1..50 instead of an enum; a sentence on 400/401. Schema: `photographers(user_id)` FKs, `cities_boundary` and `instant_requests_customer` indexes, provider `fake`; domain-model `PaymentSubject` + `instant_request`, `PaymentProvider` + `fake`.
- **Deviations (decided, recorded in the PR):**
  1. The money tables of §2.4 are created here (api migration history) when the payments plan has not run yet.
  2. Instant payments use the ledger type `deposit_received` for the capture (the payment row's `subject_type` tells them apart); no new ledger type.
  3. The lateness rule uses the offer's estimated ETA (plan I2 decision 10).
  4. `typicalMatchMinutes` measures `assigned_at − requested_at` (includes the seconds spent paying): §2.8 stores no search start in PostgreSQL.
  5. Device tokens are read from Firestore `devices/{uid}_{installId}` (written by plan I4's app) until the push plan's `devices` table; without tokens, offers still reach an open app through the mirror (§10). The FCM data keys (offer = every `InstantOfferMirror` field) follow plan I4 Task 6; they are not in the OpenAPI contract.
  6. Customer phone and photographer profile are read from the phase 2 PostgreSQL tables only.
  7. `photographers.completed_count` (S49 "completedShoots") is not incremented by instant jobs (its owner is `transition_booking`); the escrow release (`escrow_released`) and disputes are not implemented here.
  8. Decline reasons are logged, not stored (§2.8 has no column).
- **Deferred to later plans:** real MoMo/VNPay gateways and the escrow release job (I6); the dispute endpoint (`completed → disputed` exists in the state machine; no API yet); device token registration (push plan); production deployment (Cloud Run, Memorystore with AOF, secrets for the Goong key and Firebase credentials); surge time windows (open question 1); production cities and price list (open questions 1–2).
- **Risks to watch:**
  1. PostgreSQL row locks and the per-customer advisory lock under load: the load test watches `http_req_failed` and the matcher p95; deadlocks would show as 500s (lock order is always request row, then offer row).
  2. BullMQ job id rules (no `:`; `name-key-dueMs`) and `maxRetriesPerRequest: null` on its connection; the BullMQ test fails loudly otherwise.
  3. Ajv / fast-json-stringify on the rewritten `nullable` schemas: the contract and mirror-schema tests cover every schema the app reads.
  4. `postgis/postgis:16-3.4-alpine` on Apple silicon runs under emulation in some Docker setups (slower, still correct); the load numbers must come from an amd64 host or be marked as emulated.
  5. The auth copy can drift from phase 2: the drift test fails the build when it does.
  6. Firestore costs scale with track writes (one every 10–15 s per active trip): the budget test pins them; a higher rate needs a WebSocket channel instead (spec §5).
  7. The Docker-dependent suites were not run while writing this plan (no Docker daemon in the authoring sandbox); the first executor run of Tasks 6–16 is their first real run.

## From 2026-10-01-instant-i5-customer-app.md

#### Former task 14: Align the specs and the battery guide

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-instant-booking-design.md`, `docs/superpowers/specs/components/shared-components.md`, `docs/testing/battery-and-performance.md`

**Interfaces:** none (documentation).

- [ ] **Step 1: Edit**

1. `2026-10-01-instant-booking-design.md`:
   - §2.1 step 2, after "Goong Autocomplete", add: "(bản đồ nhỏ ở S47 có ghim cố định giữa màn; kéo bản đồ dưới ghim để chọn điểm, tên điểm lấy bằng Goong Geocode)".
   - §2.1 step 4, replace "(dùng chung luồng thanh toán của bước 4; trước khi bước 4 xong dùng cổng giả như kế hoạch sự kiện)" with "(cổng `PaymentLauncher`: bản debug mở `fake://pay/<id>` ngay trong app bằng `POST /v1/dev/payments/{id}/succeed`; cổng thật MoMo/VNPay ở kế hoạch I6; kết quả chỉ tin bản sao Firestore, không tin redirect)".
   - §5 FCM paragraph (added by I4 Task 15): append "`type=assigned` có thể kèm `photographerName`, `etaMinutes` để app khách hiện 'Minh Trí đã nhận · đến trong khoảng 9 phút' khi app ở nền; `type=status` với `arrived`, `no_match` cũng hiện thông báo."
   - §8, under the screen table, add: "S47 cũng có bản đồ (mock S47); bản đồ chỉ dựng ở S47, S49, S54. S48 lấy giờ bắt đầu tìm từ `searchEndsAt − 10 phút`. S49 tính 'trễ quá 15 phút' từ ETA đầu tiên app thấy (máy chủ vẫn quyết định quy tắc huỷ qua `dryRun`). S50 lấy số ảnh của gói từ bảng giá đã xem ở S47."
   - §9, in the "Khách" row: "một lần ở S47 (`LocationAccuracy.medium`, hạn 10 giây), dùng lại qua bản nháp khi quay lại từ S33/S51".
2. `components/shared-components.md`: add under section 4 "### SearchPulse · Mới" ("`SearchPulse({required bool active, double size = 200, String? semanticsLabel})`: ba vòng toả quanh `ApertureLoader`; chạy chỉ khi `active`, màn đang hiện và không giảm chuyển động; một nhãn đọc 'Đang tìm'. S48.").
3. `docs/testing/battery-and-performance.md`, section "Đo tay Chụp ngay" (I4 Task 15): add rows

   ```markdown
   | D. Khách: S47 → S48 → S49 | Mở S47 (cho phép vị trí), trả bằng cổng giả, để S48 chạy 5 phút, rồi S49 30 phút khi nhiếp ảnh gia đang đến. | GPS chỉ bật một lần ở S47 (≤ 15 s); S48 khi giảm chuyển động ≤ 5 khung hình / 30 s; S49 đứng yên (nhiếp ảnh gia không đổi vị trí) ≤ 5 khung hình / 30 s; S49 30 phút ≤ 4 % pin (đề xuất, chốt sau lần đo đầu) |
   | E. Khách rời màn | Từ S49 về Trang chủ, để yên 5 phút. | Không còn listener `instant_tracks`/`instant_requests` (Firestore usage), không khung hình |
   ```
4. Run `git diff --stat ../docs` and read each hunk once.

- [ ] **Step 2: Commit**

```bash
git add ../docs/superpowers/specs ../docs/testing/battery-and-performance.md
git commit -m "docs(instant): customer flow details, payment port, SearchPulse and customer battery scenarios

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## From 2026-10-01-instant-i6-payments.md

#### Former task 18: Performance and battery check

**Files:**
- Create: `services/dispatch/test/payments/perf-payments.test.ts`, `app_flutter/test/battery/instant_payment_battery_test.dart`

**Interfaces:**
- Consumes: `liveWorld`, `createLive`, `postMomo`, `momoIpn` (Task 7); `unconfirmedQuery`, `openRefundsQuery`, `reconcilePayments`, `RECONCILE_*` (Task 8); `releaseDueQuery` (Task 9); app: `InstantCustomerWorld`, `instantCustomerApp`, `FakeInstantMirror.listenersOf` / `openListeners`, `TickingBuilder.debugActiveCount`, `withPayment`, `goBackground`, `goForeground` (Task 16).
- Produces: the budgets below, enforced by tests.

| What | Where | Budget | Why |
|---|---|---|---|
| IPN handling (verify + `handlePaymentEvent` + log + mirror) | `perf-payments.test.ts`, 300 IPNs, 20 concurrent, real PostgreSQL | p95 < 100 ms; exactly 1 mirror write per paid payment; duplicates and forged IPNs write nothing | MoMo expects an answer within seconds and retries otherwise; Firestore cost |
| Reconciliation tick | `perf-payments.test.ts` | ≤ 24 provider calls, ≤ 4 at once; < 2 s with a 200 ms provider; worst case 24 / 4 × 8 s = 48 s ≤ 0.8 × 60 s; an idle tick calls nobody | Never overlaps the next tick; no load on the providers when nothing is open |
| Money tick queries | `perf-payments.test.ts` (200k payments, 50k refunds) | index scans on `ix_payments_unconfirmed`, `ix_refunds_open`, `ix_payments_release_due`; no `Seq Scan` | Ticks run every 1–5 minutes forever |
| App while paying elsewhere | `instant_payment_battery_test.dart` | 0 `TickingBuilder`, 0 dispatch calls for 15 minutes, 0 mirror listeners in the background, 1 after resume | No polling (mirror only); nothing runs behind the payment app |

- [ ] **Step 1: Write the server tests**

```ts
// services/dispatch/test/payments/perf-payments.test.ts
import { CompiledQuery, sql, type Compilable } from 'kysely';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { releaseDueQuery } from '../../src/payments/escrow.js';
import {
  RECONCILE_BATCH, RECONCILE_CONCURRENCY, RECONCILE_EVERY_MS, openRefundsQuery, reconcilePayments, unconfirmedQuery,
} from '../../src/payments/reconcile.js';
import { T0, addCustomer, resetAll, seedCatalog, testDb, testRedis } from '../helpers.js';
import { createLive, liveWorld, postMomo, type LiveWorld } from './live-world.js';
import { momoIpn } from './provider-messages.js';

const db = testDb();
const redis = testRedis();
afterAll(async () => {
  redis.disconnect();
  await db.destroy();
});

describe('webhook latency (plan I6 Task 18)', () => {
  let w: LiveWorld;
  const paid: string[] = [];
  beforeAll(async () => {
    await resetAll(db, redis);
    w = await liveWorld(db, redis);
    await seedCatalog(db);
    for (let i = 0; i < 100; i++) {
      await addCustomer(db, `perf${i}`);
      paid.push((await createLive(w, `perf${i}`, 'momo')).paymentId);
    }
    w.deps.metrics.reset();
  }, 120_000);

  it('300 IPNs (100 paid, 100 duplicates, 100 forged), 20 at a time: p95 < 100 ms in process, one mirror write per payment', async () => {
    const ipns = [
      ...paid.map((id) => momoIpn(id, 600_000)),
      ...paid.map((id) => momoIpn(id, 600_000)),
      ...paid.map((id) => ({ ...momoIpn(id, 600_000), signature: '0'.repeat(64) })),
    ];
    const writesBefore = w.mirror.writes;
    for (let i = 0; i < ipns.length; i += 20) await Promise.all(ipns.slice(i, i + 20).map((b) => postMomo(w, b)));
    const s = w.deps.metrics.summary().webhook_ms;
    console.log('webhook_ms', s);
    expect(s?.count).toBe(300);
    expect(s?.p95 ?? Infinity).toBeLessThan(100);
    expect(w.mirror.writes - writesBefore).toBe(100);
    const outcomes = await db.selectFrom('payment_notifications').select(['outcome', sql<number>`count(*)::int`.as('n')]).groupBy('outcome').orderBy('outcome').execute();
    expect(outcomes).toEqual([
      { outcome: 'duplicate', n: 100 },
      { outcome: 'invalid_signature', n: 100 },
      { outcome: 'processed', n: 100 },
    ]);
  });
});

describe('reconciliation budget (plan I6 Task 18)', () => {
  it('a tick with every provider call timing out still ends before the next tick', () => {
    const worstCallMs = 8_000; // PAYMENT_HTTP_TIMEOUT_MS default
    expect((RECONCILE_BATCH / RECONCILE_CONCURRENCY) * worstCallMs).toBeLessThanOrEqual(0.8 * RECONCILE_EVERY_MS);
  });

  it('slow provider (200 ms): one tick makes at most the batch, never more than 4 at once, in under 2 s', async () => {
    await resetAll(db, redis);
    const w = await liveWorld(db, redis);
    await seedCatalog(db);
    for (let i = 0; i < 40; i++) {
      await addCustomer(db, `slow${i}`);
      await createLive(w, `slow${i}`, 'momo');
    }
    w.momo.slowBy(200);
    w.clock.advance(5 * 60_000);
    const started = Date.now();
    const r = await reconcilePayments(w.deps);
    const took = Date.now() - started;
    expect(r.checked).toBe(RECONCILE_BATCH);
    expect(w.momo.maxInFlight()).toBeLessThanOrEqual(RECONCILE_CONCURRENCY);
    expect(took).toBeLessThan(2_000);
  }, 60_000);

  it('an idle tick asks no provider and touches no row', async () => {
    await resetAll(db, redis);
    const w = await liveWorld(db, redis);
    w.clock.advance(60 * 60_000);
    expect(await reconcilePayments(w.deps)).toEqual({ checked: 0, paid: 0, failed: 0, waiting: 0, gaveUp: 0 });
    expect(w.momo.calls).toHaveLength(0);
  });
});

interface PlanNode {
  'Node Type': string;
  'Index Name'?: string;
  Plans?: PlanNode[];
}
const nodes = (n: PlanNode): PlanNode[] => [n, ...(n.Plans ?? []).flatMap(nodes)];
async function explain(q: Compilable): Promise<PlanNode[]> {
  const c = q.compile();
  const r = await db.executeQuery<{ 'QUERY PLAN': Array<{ Plan: PlanNode }> }>(CompiledQuery.raw(`explain (format json) ${c.sql}`, [...c.parameters]));
  return nodes(r.rows[0]!['QUERY PLAN'][0]!.Plan);
}

describe('money ticks use their partial indexes on a busy table (plan I6 Task 18)', () => {
  beforeAll(async () => {
    await resetAll(db, redis);
    // 200k settled instant payments, a handful still open.
    await sql`insert into payments (id, subject_type, subject_id, provider, amount, status, escrow_status, payee_id, release_after, released_at, idempotency_key, created_at)
      select 'pay' || g, 'instant_request', 'r' || g, 'momo', 600000, 'paid', 'paid_out', null, null, ${T0}::timestamptz - interval '30 days', 'k' || g,
             ${T0}::timestamptz - (g || ' seconds')::interval
      from generate_series(1, 200000) g`.execute(db);
    await sql`insert into refunds (id, payment_id, amount, status, created_at, updated_at)
      select 'ref' || g, 'pay' || g, 1000, 'done', ${T0}, ${T0} from generate_series(1, 50000) g`.execute(db);
    await sql`insert into payments (id, subject_type, subject_id, provider, amount, status, idempotency_key, created_at)
      select 'open' || g, 'instant_request', 'ro' || g, 'momo', 600000, 'created', 'ko' || g, ${T0} from generate_series(1, 20) g`.execute(db);
    await sql`analyze`.execute(db);
  }, 180_000);

  it.each<[string, () => Compilable, string]>([
    ['unconfirmed payments (payments-reconcile)', () => unconfirmedQuery(db, new Date(T0.getTime() + 3_600_000), ['momo', 'vnpay']), 'ix_payments_unconfirmed'],
    ['open refunds (payments-reconcile)', () => openRefundsQuery(db, new Date(T0.getTime() + 3_600_000)), 'ix_refunds_open'],
    ['release due (escrow-release)', () => releaseDueQuery(db, new Date(T0.getTime() + 3_600_000)), 'ix_payments_release_due'],
  ])('%s', async (_name, build, index) => {
    const plan = await explain(build());
    expect(plan.filter((n) => n['Node Type'] === 'Seq Scan')).toEqual([]);
    expect(plan.map((n) => n['Index Name'])).toContain(index);
  });
});
```

- [ ] **Step 2: Run them**

Run: `npm test -- test/payments/perf-payments.test.ts`
Expected: PASS (1 + 3 + 3); the console shows `webhook_ms { count: 300, p50: …, p95: … }`. Record p50/p95 in the PR. If p95 ≥ 100 ms, look at the queries of `handlePaymentEvent` and `composeRequestMirror` with `EXPLAIN ANALYZE` before touching the budget. Then run the whole suite: `npm run typecheck && npm test` (every I3 and I6 suite green).

- [ ] **Step 3: Write the app battery test**

```dart
// test/battery/instant_payment_battery_test.dart
// Plan I6 Task 18: while the customer pays in another app, this app runs no
// timer, makes no request and keeps no listener open; on return it reads the
// mirror once and shows the result.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';

import '../support/instant_customer_screens.dart';
import '../support/instant_customer_world.dart';
import '../support/instant_payment_support.dart';

void main() {
  late InstantCustomerWorld w;
  setUp(() async {
    w = InstantCustomerWorld();
    await w.init();
  });

  testWidgets('pending payment in the background: 0 timers, 0 HTTP calls, 0 mirror listeners; resume shows the result', (tester) async {
    w.mirror.setRequest('RQ1', withPayment(w.request(InstantStatus.pendingPayment), provider: PaymentProvider.momo, expiresAt: DateTime.utc(2026, 10, 1, 8, 15)));
    await tester.pumpWidget(instantCustomerApp(w, location: '/instant/RQ1'));
    await tester.pump();
    await tester.pump();
    expect(w.mirror.listenersOf('instant_requests/RQ1'), 1);
    expect(TickingBuilder.debugActiveCount, 0);
    final calls = (w.booking.healthCalls, w.booking.packagesCalls, w.booking.created.length, w.booking.cancelCalls.length, w.booking.confirmCalls.length);

    await goBackground(tester);
    expect(w.mirror.listenersOf('instant_requests/RQ1'), 0);
    // The IPN arrives while the customer is still in the MoMo app.
    w.mirror.setRequest('RQ1', w.request(InstantStatus.searching));
    await tester.pump(const Duration(minutes: 15));
    expect(TickingBuilder.debugActiveCount, 0);
    expect((w.booking.healthCalls, w.booking.packagesCalls, w.booking.created.length, w.booking.cancelCalls.length, w.booking.confirmCalls.length), calls);

    await goForeground(tester);
    await tester.pump();
    expect(w.mirror.listenersOf('instant_requests/RQ1'), 1);
    expect(find.text('Đang tìm nhiếp ảnh gia'), findsOneWidget);
    expect((w.booking.healthCalls, w.booking.packagesCalls, w.booking.created.length), (calls.$1, calls.$2, calls.$3));
  });

  testWidgets('leaving the screen closes everything', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.pendingPayment));
    await tester.pumpWidget(instantCustomerApp(w, location: '/instant/RQ1'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(w.mirror.openListeners, 0);
    expect(TickingBuilder.debugActiveCount, 0);
  });
}
```

- [ ] **Step 4: Run it**

Run: `flutter test test/battery/instant_payment_battery_test.dart && flutter test && flutter analyze`
Expected: PASS (2 tests), then the whole app suite and analyze clean.

- [ ] **Step 5: [người dùng] Manual battery and latency check**

On one Android and one iOS device with the staging build of Task 13, run the scenario of `docs/testing/battery-and-performance.md` "Chụp ngay: thanh toán" and fill one row per device in the PR (wake lock, network, time from IPN to S48 "Đang tìm").

- [ ] **Step 6: Commit**

```bash
git add services/dispatch/test app_flutter/test/battery
git commit -m "perf(payments): webhook latency, reconciliation budget, money tick indexes, no timers or listeners behind the payment app

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:**
  - Spec §4 "Thu tiền … chỉ chuyển `searching` khi cổng xác nhận (webhook, không tin redirect)": MoMo IPN and VNPay IPN verified (Tasks 3–4), the I3 flow unchanged (Task 7), the return page and the app ignore the query (Tasks 12, 15), S48 waits on the mirror (Task 16).
  - Spec §4 cancel table and no-match refunds: I3 computes them; the refunds now reach MoMo/VNPay with type full/partial, retries, resubmission, the manual queue (Tasks 3, 4, 7, 8, 11); `refund + photographer + platform = collected` re-checked after release and dispute resolution (Tasks 9, 10).
  - Spec §10: payment failure and cancel at the gateway (`payment_failed`, Tasks 3–4, 7), payment window (I3) plus reconciliation (Task 8), late money after close (Task 7), amount mismatch (Task 7), gateway down (Task 7).
  - Spec main §3g: `held → released` after completion + 24 h (Task 9), `released → paid_out` with a manual export (Task 11), disputes freeze the release and hold payouts (Task 10), refunds only from held money and never after release (Task 10), ledger entries for capture, refund, fee, release, payout and fee reversal (Tasks 7, 9–11), §3g.7 legal note carried as an open question.
  - data-model README §5 use cases: `handle_payment_notification`, `refund_payment`, `release_escrow`, `create_payout`, `open_dispute`, `resolve_dispute` for `instant_request`.
  - Scope items of the request: MoMo AIO v2 (captureWallet / payWithMethod), HMAC-SHA256, IPN 204, refund, query, sandbox endpoints (Task 3); VNPay 2.1.0 HMAC-SHA512 over the sorted query, GET IPN with RspCode, refund and querydr, sandbox (Task 4); vectors with field order (Task 2, reference table); sandbox cross-check (Task 13); secrets from env, `.env.example` test values (Task 5); app launcher, Android intent filters, iOS associated domains and URL scheme with platform-file tests, S47/S48 behaviour (Tasks 14–16); final performance and battery task (Task 18).
- **Placeholders:** none. Generated files (`src/generated/api.ts`, `lib/l10n/*.dart`, lock files) come from the commands given. The App Link host default `links.photobooking.invalid` is a deliberate non-resolving value until the domain is chosen (open question 4); the real value is configuration, not code.
- **Type consistency:** `PaymentGateway`, `CreatePaymentInput`, `CreatePaymentResult`, `WebhookRequest`, `WebhookVerification`, `PaymentEvent`, `WebhookOutcome`, `WebhookAck`, `RefundInput`, `RefundResult`, `gatewayRegistry`, `buildGateways` are I3's, unchanged; `PaymentStatusSource`, `PaymentQueryResult`, `MomoConfig`, `VnpayConfig`, `GatewayWiring`, `AppLinksConfig`, `ReconcileReport`, `RefundPollReport`, `ReleaseReport`, `DisputeDecision` are spelled the same in code, tests and interface lists; on the app side `PaymentConfig`, `GatewayPaymentLauncher`, `paymentChoiceProvider`, `paymentConfigProvider`, `ReturnLinkSource`, `FakeReturnLinkSource`, `appLinkConfigProvider`, `returnLinkSourceProvider`, `instantReturnTarget`, `wireInstantReturnLinks`, `appForegroundProvider`, `foregroundInstantRequestProvider`, `PaymentMethodPicker`, `paymentProviderLabel`, `withPayment`, `goBackground`, `goForeground` and every widget key match between code and tests. The server tree was type-checked as a whole while writing.
- **Deviations (decided, record in the PR):**
  1. `buildGateways` takes an optional `GatewayWiring` and a wider config `Pick`; I3's calls and tests still compile and pass.
  2. `vnp_IpAddr` is the server's IP (the port has no client IP); VNPay to confirm (Task 13).
  3. The reconciliation and refund follow-up need an extra optional port, `PaymentStatusSource`; `PaymentGateway` itself is unchanged.
  4. I3 code changed in small, listed places: `createRequest` (timer first, provider failure closes the request, payments `created_at` from the service clock), `handlePaymentEvent` (capture after `failed`), `executeRefund` (answers saved), `applySplit` (refund timestamps), `composeRequestMirror` (two fields), the webhook route (log and timing), `reconcile()` (two ticks), `createLogger` (query strings dropped, more redaction), `returnUrlFor` (https when configured).
  5. The contract gains `openDispute` and two optional mirror fields; no new `ErrorCode` (a provider outage is `internal` with `details.provider`).
  6. MoMo's in-app deeplink (`deeplink` in the create answer) is not used: the https `payUrl` hands over to the MoMo app itself, so `CreatePaymentResult` and the contract stay as they are.
  7. A payout "hold" is a status, not a ledger entry (no money moves); dispute fee reversals use `adjustment` with note `fee_reversal`.
  8. Releases and payouts here only cover `subject_type = 'instant_request'`; the bookings/events payments plan should take over `release_escrow` for every subject (one payee could otherwise get two payout batches).
  9. `orderExpireTime` is sent to MoMo and kept only if the sandbox accepts it (Task 13); the 15-minute window is enforced by the service anyway (I3 `payment-timeout` + full refund of late money).
- **Risks to watch:**
  1. Provider documentation drift (field order, codes, empty-value rule, querydr refund statuses): only Task 13 proves the integration; keep `PAYMENT_ENV=production` unset until its table is filled.
  2. VNPay hashes over decoded and re-encoded query values: safe for our ASCII order info and VNPay's alphanumeric fields; a value with characters `encodeURIComponent` keeps (`!'()*`) would break it; the cancelled-IPN check in Task 13 covers the real fields.
  3. Webhook endpoints are public: there is no rate limit here; put the dispatch host behind the platform's rate limiting / WAF and consider VNPay's IP allow-list.
  4. Universal Links do not always fire on a redirect inside Safari; the return page's button and the app's resume path (mirror on resume) cover it, and the customer can always reopen the app.
  5. `flutter_deeplinking_enabled=false` / `FlutterDeepLinkingEnabled=false` turn off Flutter's built-in link routing for every link: any later plan that relies on it must route through `ReturnLinkSource`.
  6. The payout CSV has no full account number (encrypted; S44 tooling not written): the manual bank run needs that tooling or the bank's saved beneficiaries.
  7. The Dart code of Tasks 14–16 was not compiled while writing (it builds on I4/I5 code not yet in the repo); the pure parts were run with the Dart SDK.
- **Open legal and product questions:**
  1. Legal (spec main §3g.7, open question 19): holding customers' money for third parties may be an intermediary payment service needing a State Bank of Vietnam licence, or must go through a provider's or bank's escrow product. Ask before `PAYMENT_ENV=production`; the code is ready for either, the contract with MoMo/VNPay is not.
  2. Merchant agreements: whether MoMo and VNPay allow marketplace collection with delayed payout to photographers, and their fees (the `fee_charged` entry assumes the platform keeps the gateway fee inside its 20%).
  3. VNPay `vnp_IpAddr`: server IP acceptable?
  4. The App Link host (a dedicated `links.` domain or the dispatch host) and who operates it.
  5. Dispute policy: who decides, deadlines for the photographer's answer, evidence, partial refunds, and what the customer sees (the app has no dispute button yet; the review/S12 plan should add it).
  6. Payout schedule and minimum amount, invoices / tax documents for photographers (personal income tax withholding), and the bank file format of the chosen bank.
  7. Refunds that MoMo/VNPay cannot send automatically (old transactions, closed wallets): the manual queue needs an ops owner and a time limit promised to customers.

## From 2026-10-01-ios-enablement.md

#### Former task 4: iOS section in the battery and performance guide

**Files:**
- Modify: `docs/testing/battery-and-performance.md` (repo root `docs/`)

**Interfaces:**
- Produces: an iOS procedure with commands and thresholds, and an `OS` column in the result table. Every plan's manual battery step then covers both platforms.

- [ ] **Step 1: Edit the guide**

Add after the Android section "Đo tay (thiết bị Android thật, bản profile)":

```markdown
## Đo tay trên iOS (iPhone thật, bản profile)

Chạy bản profile lên máy (cần Task 5–8 của kế hoạch bật iOS):

```bash
flutter run --profile -d <iphone-udid>
```

1. **Khung hình và CPU khi đứng yên.** Trong Xcode: Debug Navigator (⌘7) khi app đang chạy từ Xcode, hoặc dùng Instruments:
   ```bash
   xcrun xctrace record --template 'Time Profiler' --device <iphone-udid> --attach Runner --time-limit 30s --output idle.trace
   ```
   Mở `idle.trace`, xem luồng `io.flutter.1.ui` và `io.flutter.1.raster`. Ngưỡng: **CPU trung bình < 3%** khi màn đứng yên, không có khối hoạt động lặp lại.
2. **Năng lượng.** Instruments mẫu **Energy Log** (chỉ trên máy thật) hoặc đồng hồ "Energy Impact" trong Debug Navigator. Ngưỡng: **"Low" hoặc "None"** khi đứng yên; không có "Location" khi đã rời màn Khám phá; mũi tên vị trí trên thanh trạng thái tắt ngay sau khi lấy được vị trí.
3. **Cuộn.** Instruments mẫu **Animation Hitches**:
   ```bash
   xcrun xctrace record --template 'Animation Hitches' --device <iphone-udid> --attach Runner --time-limit 30s --output scroll.trace
   ```
   Cuộn hết danh sách 3 lần trong 30 giây. Ngưỡng: **hitch time ratio < 5 ms/s**. Máy ProMotion chạy 120 Hz (`CADisableMinimumFrameDurationOnPhone` đang bật), nên mỗi khung chỉ có 8,3 ms.
4. **Bộ nhớ.** Debug Navigator > Memory sau khi lướt hết các màn của kế hoạch. Ngưỡng: **< 250 MB**.

Simulator dùng được cho bước 1 và 3 (đo tương đối), không dùng để kết luận về pin.
```

Then change the result-table header to add `OS` as the first data column:

```markdown
| Màn / kịch bản | OS | Khung hình đứng yên (30 s) | Janky % / hitch ms/s | p90 (ms) | CPU đứng yên | Wake lock / Energy | GPS (s) | Bộ nhớ (MB) | Thiết bị |
|---|---|---|---|---|---|---|---|---|---|
| S… | Android | | | | | | | | |
| S… | iOS | | | | | | | | |
```

- [ ] **Step 2: Commit**

```bash
git add ../docs/testing/battery-and-performance.md
git commit -m "docs(testing): iOS energy, CPU and hitch measurements

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

If the screen-codes plan has not run yet (the guide does not exist), do this task right after that plan's Task 6.

---

## Task Z: Device build and profiling

- [ ] Build the debug APK and install it on the Genymotion device (uninstall the old `com.thanhbk.photobooking` first only with the user's OK — it was signed with another key).
- [ ] Run the manual profiling steps collected above (`adb shell dumpsys gfxinfo`, `top`, `batterystats`, `meminfo`) per `docs/testing/battery-and-performance.md` and record results there.
- [ ] iOS: run the iOS sections once the iOS enablement plan can build.
