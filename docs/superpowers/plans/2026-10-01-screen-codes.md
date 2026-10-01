# Screen Codes (Build step 0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every screen carries its `Sxx` code, and a debug-only switch in Settings shows the code as a small tag at the top-left of the screen.

**Architecture:** `ScreenCodes` holds the 46 codes as constants, with a test that keeps them identical to the spec table. `ScreenCode` is a core widget that draws the tag when `kDebugMode` and an inherited `ScreenCodeScope` says "visible" (same pattern as `CtaAvatarScope`, so `core/` never imports `features/`). The switch is a `Notifier<bool>` persisted in `SharedPreferences`, wired into `MyApp` from `main.dart`.

**Tech Stack:** Flutter, Riverpod 3 (`Notifier`), `shared_preferences`, `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` sections 2 and 2.1 (also `docs/superpowers/specs/components/shared-components.md`, entry "ScreenCode").

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`.
- Imports are `package:photobooking/...` only; features import `package:photobooking/core/core.dart`, not files inside `core/` (CLAUDE.md).
- Files inside `core/` import each other directly, not through `core.dart`.
- Screen codes run `S01`–`S46`, are never renumbered, and the Dart constants must match the table in section 2 of the main spec.
- The tag is shown only when `kDebugMode && showScreenCodes`; in release `ScreenCode` returns `child` unchanged (no extra node).
- Tag look: background `#FF2D95`, white text, monospace 11, radius 6, `IgnorePointer`, below the status bar (`SafeArea`), top-left.
- UI strings live in `lib/l10n/app_vi.arb` (Vietnamese, with full diacritics); regenerate with `flutter gen-l10n`; no hard-coded UI text.
- No `Color(0x…)` or magic dp in feature code; use `AppColors`/`AppSpace`/`AppRadius`. The tag colour is the only literal and lives in `screen_code.dart` with a comment, because the mock fixes it and it is not a theme colour.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Splash and Session-error screens get no code.

## File Structure

| File | Responsibility |
|------|----------------|
| `lib/core/screen_codes.dart` (create) | `ScreenCodes` constants + `ScreenCodes.all` |
| `lib/core/widgets/screen_code.dart` (create) | `ScreenCodeScope` (inherited flag) and `ScreenCode` (the tag) |
| `lib/core/core.dart` (modify) | export the two files above |
| `lib/features/settings/show_screen_codes_controller.dart` (create) | persisted on/off switch |
| `lib/app/app.dart` (modify) | `showScreenCodes` param → `ScreenCodeScope` |
| `lib/main.dart` (modify) | feed the switch into `MyApp` |
| `lib/features/settings/settings_screen.dart` (modify) | debug-only switch row |
| `lib/l10n/app_vi.arb` (modify) | three new strings |
| six existing screens (modify) | wrap with `ScreenCode` |
| `test/core/screen_codes_test.dart`, `test/core/widgets/screen_code_test.dart`, `test/features/settings/settings_test.dart` | tests |

---

### Task 1: `ScreenCodes` constants, kept in sync with the spec

**Files:**
- Create: `lib/core/screen_codes.dart`
- Modify: `lib/core/core.dart`
- Test: `test/core/screen_codes_test.dart`

**Interfaces:**
- Produces: `abstract final class ScreenCodes` with one `static const String` per screen (names below) and `static const List<String> all` (S01…S46 in order). Later tasks use `ScreenCodes.login`, `.role`, `.register`, `.profile`, `.settings`, `.editProfile`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/screen_codes_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/screen_codes.dart';

void main() {
  test('codes are S01..S46, in order, with no gaps or repeats', () {
    final expected = [for (var i = 1; i <= 46; i++) 'S${i.toString().padLeft(2, '0')}'];
    expect(ScreenCodes.all, expected);
  });

  test('the code table in the main spec lists exactly these codes', () {
    final spec = File(
      '../docs/superpowers/specs/2026-10-01-remaining-screens.md',
    ).readAsStringSync();
    final inSpec = RegExp(r'^\| (S\d\d) \|', multiLine: true)
        .allMatches(spec)
        .map((m) => m.group(1)!)
        .toList();
    expect(inSpec, ScreenCodes.all);
  });

  test('existing screens use the codes the spec assigns them', () {
    expect(ScreenCodes.login, 'S28');
    expect(ScreenCodes.role, 'S29');
    expect(ScreenCodes.profile, 'S30');
    expect(ScreenCodes.settings, 'S31');
    expect(ScreenCodes.register, 'S41');
    expect(ScreenCodes.editProfile, 'S42');
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/core/screen_codes_test.dart`
Expected: FAIL, "Target of URI doesn't exist: 'package:photobooking/core/screen_codes.dart'".

- [ ] **Step 3: Implement**

```dart
// lib/core/screen_codes.dart
/// One code per screen, `S01`..`S46`. The single source in Dart; the table in
/// `docs/superpowers/specs/2026-10-01-remaining-screens.md` (section 2) and the
/// mock `docs/design/ui-mock.html` use the same codes.
///
/// Never renumber. A new screen takes the next number and is added to the spec
/// table first (a test compares the two).
abstract final class ScreenCodes {
  static const home = 'S01';
  static const photoDetail = 'S02';
  static const photographerProfile = 'S03';
  static const findPhotographer = 'S04';
  static const bookService = 'S05';
  static const bookDateTime = 'S06';
  static const bookReview = 'S07';
  static const awaitingPayment = 'S08';
  static const bookingDetail = 'S09';
  static const cancelBooking = 'S10';
  static const chat = 'S11';
  static const reviewAndShare = 'S12';
  static const exploreNoLocation = 'S13';
  static const bookings = 'S14';
  static const events = 'S15';
  static const eventDetail = 'S16';
  static const eventRegister = 'S17';
  static const eventTickets = 'S18';
  static const work = 'S19';
  static const myCalendar = 'S20';
  static const createPost = 'S21';
  static const workEmpty = 'S22';
  static const declineRequest = 'S23';
  static const setupProfile = 'S24';
  static const createEventInfo = 'S25';
  static const createEventSchedule = 'S26';
  static const manageEvent = 'S27';
  static const login = 'S28';
  static const role = 'S29';
  static const profile = 'S30';
  static const settings = 'S31';
  static const contactAfterBooking = 'S32';
  static const addPhone = 'S33';
  static const setupContact = 'S34';
  static const exploreNearby = 'S35';
  static const pickArea = 'S36';
  static const badges = 'S37';
  static const skillsPart1 = 'S38';
  static const skillsPart2 = 'S39';
  static const skillEvidence = 'S40';
  static const register = 'S41';
  static const editProfile = 'S42';
  static const earnings = 'S43';
  static const payoutAccount = 'S44';
  static const eventTimeline = 'S45';
  static const eventChat = 'S46';

  static const all = <String>[
    home, photoDetail, photographerProfile, findPhotographer, bookService,
    bookDateTime, bookReview, awaitingPayment, bookingDetail, cancelBooking,
    chat, reviewAndShare, exploreNoLocation, bookings, events, eventDetail,
    eventRegister, eventTickets, work, myCalendar, createPost, workEmpty,
    declineRequest, setupProfile, createEventInfo, createEventSchedule,
    manageEvent, login, role, profile, settings, contactAfterBooking, addPhone,
    setupContact, exploreNearby, pickArea, badges, skillsPart1, skillsPart2,
    skillEvidence, register, editProfile, earnings, payoutAccount,
    eventTimeline, eventChat,
  ];
}
```

In `lib/core/core.dart`, add (keep alphabetical, after `l10n_ext.dart`):

```dart
export 'package:photobooking/core/screen_codes.dart';
```

- [ ] **Step 4: Run it and see it pass**

Run: `flutter test test/core/screen_codes_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core/screen_codes.dart lib/core/core.dart test/core/screen_codes_test.dart
git commit -m "feat(core): ScreenCodes constants checked against the spec table

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `ScreenCode` widget and `ScreenCodeScope`

**Files:**
- Create: `lib/core/widgets/screen_code.dart`
- Modify: `lib/core/core.dart`
- Test: `test/core/widgets/screen_code_test.dart`

**Interfaces:**
- Produces:
  - `class ScreenCodeScope extends InheritedWidget` with `const ScreenCodeScope({super.key, required bool visible, required super.child})` and `static bool visibleOf(BuildContext context)` (false when no scope).
  - `class ScreenCode extends StatelessWidget` with `const ScreenCode(String code, {Key? key, String? label, required Widget child})`. Shows `code` or `code.label`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/widgets/screen_code_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

const _childKey = Key('child');

Widget _host({required bool visible, String? label}) => ScreenCodeScope(
  visible: visible,
  child: MaterialApp(
    home: Scaffold(
      body: ScreenCode(
        ScreenCodes.bookingDetail,
        label: label,
        child: const Center(
          child: SizedBox(key: _childKey, width: 120, height: 40),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('shows the code when the switch is on', (tester) async {
    await tester.pumpWidget(_host(visible: true));
    expect(find.text('S09'), findsOneWidget);
  });

  testWidgets('a sub-part shows code.label', (tester) async {
    await tester.pumpWidget(_host(visible: true, label: 'timeline'));
    expect(find.text('S09.timeline'), findsOneWidget);
  });

  testWidgets('shows nothing when the switch is off', (tester) async {
    await tester.pumpWidget(_host(visible: false));
    expect(find.text('S09'), findsNothing);
    expect(find.byKey(_childKey), findsOneWidget);
  });

  testWidgets('without a scope the tag is hidden', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ScreenCode('S09', child: SizedBox(key: _childKey)),
      ),
    );
    expect(find.text('S09'), findsNothing);
  });

  testWidgets('the tag does not change the child layout or block taps', (
    tester,
  ) async {
    await tester.pumpWidget(_host(visible: false));
    final off = tester.getRect(find.byKey(_childKey));
    await tester.pumpWidget(_host(visible: true));
    expect(tester.getRect(find.byKey(_childKey)), off);

    var taps = 0;
    await tester.pumpWidget(
      ScreenCodeScope(
        visible: true,
        child: MaterialApp(
          home: Scaffold(
            body: ScreenCode(
              'S09',
              child: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => taps++,
                  child: const SizedBox(key: _childKey, width: 200, height: 200),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Tap the top-left corner of the child, where the tag is drawn.
    await tester.tapAt(tester.getTopLeft(find.byKey(_childKey)) + const Offset(8, 8));
    expect(taps, 1);
  });

  testWidgets('the tag is not announced by screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(visible: true));
    expect(find.bySemanticsLabel('S09'), findsNothing);
    handle.dispose();
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/screen_code_test.dart`
Expected: FAIL, `ScreenCode` / `ScreenCodeScope` undefined.

- [ ] **Step 3: Implement**

```dart
// lib/core/widgets/screen_code.dart
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Whether [ScreenCode] tags are shown. Placed above the router by `MyApp`,
/// so `core/` does not depend on the settings feature.
class ScreenCodeScope extends InheritedWidget {
  const ScreenCodeScope({
    super.key,
    required this.visible,
    required super.child,
  });

  final bool visible;

  static bool visibleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScreenCodeScope>()?.visible ??
      false;

  @override
  bool updateShouldNotify(ScreenCodeScope old) => old.visible != visible;
}

/// Debug aid: draws the screen's code (`S09`, or `S09.timeline` with [label])
/// at the top-left so a change request can name the screen. In release builds,
/// or while the switch is off, it returns [child] untouched.
class ScreenCode extends StatelessWidget {
  const ScreenCode(this.code, {super.key, this.label, required this.child});

  final String code;

  /// Marks a part of a screen, shown as `code.label`.
  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode || !ScreenCodeScope.visibleOf(context)) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpace.s2,
                top: AppSpace.s1,
              ),
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: _Tag(label == null ? code : '$code.$label'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  // Fixed by the mock (docs/design/ui-mock.html, .scode); not a theme colour.
  static const _background = Color(0xFFFF2D95);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
```

In `lib/core/core.dart` add `export 'package:photobooking/core/widgets/screen_code.dart';` (after `glass_card.dart`).

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/screen_code_test.dart`
Expected: PASS, 6 tests. Then `flutter analyze` → no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/screen_code.dart lib/core/core.dart test/core/widgets/screen_code_test.dart
git commit -m "feat(core): ScreenCode debug tag and ScreenCodeScope

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Persisted switch and wiring into `MyApp`

**Files:**
- Create: `lib/features/settings/show_screen_codes_controller.dart`
- Modify: `lib/app/app.dart`, `lib/main.dart`
- Test: `test/features/settings/settings_test.dart` (append), `test/app/app_test.dart` (check for an existing file first with `ls test/app`; if it exists append there, else add the new test to the settings test file)

**Interfaces:**
- Consumes: `sharedPreferencesProvider` from `lib/features/settings/theme_mode_controller.dart`; `ScreenCodeScope` from Task 2.
- Produces: `showScreenCodesProvider` (`NotifierProvider<ShowScreenCodesController, bool>`; `.notifier.set(bool)`); `MyApp({bool showScreenCodes = false, …})`.

- [ ] **Step 1: Write the failing test** (append inside `main()` of `test/features/settings/settings_test.dart`; add the import `package:photobooking/features/settings/show_screen_codes_controller.dart` at the top)

```dart
  test('screen codes are off by default and the choice is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    expect(c.read(showScreenCodesProvider), isFalse);
    await c.read(showScreenCodesProvider.notifier).set(true);
    expect(prefs.getBool('showScreenCodes'), isTrue);

    final again = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(again.dispose);
    expect(again.read(showScreenCodesProvider), isTrue);
  });
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/settings/settings_test.dart`
Expected: FAIL, `show_screen_codes_controller.dart` not found.

- [ ] **Step 3: Implement**

```dart
// lib/features/settings/show_screen_codes_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/features/settings/theme_mode_controller.dart';

const _key = 'showScreenCodes';

/// Debug aid: show each screen's `Sxx` tag. Off by default; only offered in
/// debug builds (see the Settings screen) and ignored by `ScreenCode` in release.
class ShowScreenCodesController extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final showScreenCodesProvider =
    NotifierProvider<ShowScreenCodesController, bool>(
      ShowScreenCodesController.new,
    );
```

`lib/app/app.dart`: add a constructor parameter and wrap the builder.

```dart
    this.ctaAvatar,
    this.showScreenCodes = false,
  });
  ...
  /// Debug aid, see [ScreenCode].
  final bool showScreenCodes;
```

and replace the `builder:` with

```dart
      builder: (context, child) => ScreenCodeScope(
        visible: showScreenCodes,
        child: CtaAvatarScope(avatar: ctaAvatar, child: child ?? const SizedBox()),
      ),
```

`lib/main.dart`: add `import 'package:flutter/foundation.dart' show kDebugMode;` and `import 'package:photobooking/features/settings/show_screen_codes_controller.dart';`, then pass to `MyApp`:

```dart
      showScreenCodes: kDebugMode && ref.watch(showScreenCodesProvider),
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/features/settings/settings_test.dart && flutter analyze`
Expected: PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/show_screen_codes_controller.dart lib/app/app.dart lib/main.dart test/features/settings/settings_test.dart
git commit -m "feat(settings): persisted screen-code switch wired into MyApp

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Switch row in Settings (debug builds only)

**Files:**
- Modify: `lib/l10n/app_vi.arb`, `lib/features/settings/settings_screen.dart`, generated `lib/l10n/app_localizations*.dart`
- Test: `test/features/settings/settings_test.dart` (append)

**Interfaces:**
- Consumes: `showScreenCodesProvider` (Task 3).
- Produces: strings `settingsDeveloper`, `settingsShowScreenCodes`, `settingsShowScreenCodesBody`; a `SwitchListTile` with `Key('show-screen-codes')`.

- [ ] **Step 1: Write the failing test** (append inside `main()`)

```dart
  testWidgets('the screen-code switch is offered in debug and saves', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs));
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('show-screen-codes'));
    await tester.scrollUntilVisible(row, 200);
    expect(tester.widget<SwitchListTile>(row).value, isFalse);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(row).value, isTrue);
    expect(prefs.getBool('showScreenCodes'), isTrue);
  });
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/settings/settings_test.dart --plain-name "screen-code switch"`
Expected: FAIL, no widget with key `show-screen-codes`.

- [ ] **Step 3: Implement**

In `lib/l10n/app_vi.arb`, after `"settingsButtonPreview": "Xem trước nút",` add:

```json
  "settingsDeveloper": "Dành cho nhà phát triển",
  "settingsShowScreenCodes": "Hiện mã màn hình",
  "settingsShowScreenCodesBody": "Nhãn Sxx ở góc trên trái mỗi màn, để gọi tên màn khi cần chỉnh sửa.",
```

Run `flutter gen-l10n`.

In `settings_screen.dart` add `import 'package:flutter/foundation.dart' show kDebugMode;` and `import 'package:photobooking/features/settings/show_screen_codes_controller.dart';`, add `final showCodes = ref.watch(showScreenCodesProvider);` next to the other `ref.watch` lines, and append after the preview-button `Semantics(...)` (still inside the `ListView.children`):

```dart
              if (kDebugMode) ...[
                const SizedBox(height: AppSpace.s6),
                _SectionLabel(l.settingsDeveloper),
                GlassCard(
                  highlight: false,
                  child: SwitchListTile(
                    key: const Key('show-screen-codes'),
                    secondary: const Icon(Icons.pin_outlined),
                    title: Text(l.settingsShowScreenCodes),
                    subtitle: Text(l.settingsShowScreenCodesBody),
                    value: showCodes,
                    onChanged: (v) =>
                        ref.read(showScreenCodesProvider.notifier).set(v),
                  ),
                ),
              ],
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/features/settings/settings_test.dart && flutter analyze`
Expected: PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n lib/features/settings/settings_screen.dart test/features/settings/settings_test.dart
git commit -m "feat(settings): debug switch to show screen codes

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Put the codes on the six existing screens

**Files:**
- Modify: `lib/features/auth/login_screen.dart` (S28), `lib/features/onboarding/role_screen.dart` (S29), `lib/features/shell/placeholder_tabs.dart` `ProfileTab` (S30), `lib/features/settings/settings_screen.dart` (S31), `lib/features/auth/register_screen.dart` (S41), `lib/features/settings/edit_profile_screen.dart` (S42)
- Test: `test/features/screen_codes_applied_test.dart`

**Interfaces:**
- Consumes: `ScreenCode`, `ScreenCodeScope`, `ScreenCodes` from `core.dart`.

Pattern for each screen: wrap the widget returned from `build` in `ScreenCode(ScreenCodes.x, child: …)`; for the two screens that return `AnnotatedRegion(... child: …)` (login, register) wrap the `AnnotatedRegion`. The placeholder tabs already sit inside `TabShell`'s `Scaffold`, so on `ProfileTab` wrap its own `Scaffold`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/screen_codes_applied_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/auth/login_screen.dart';
import 'package:photobooking/features/auth/register_screen.dart';
import 'package:photobooking/features/onboarding/role_screen.dart';
import 'package:photobooking/features/settings/edit_profile_screen.dart';
import 'package:photobooking/features/settings/settings_screen.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';
import 'package:photobooking/l10n/app_localizations.dart';

Future<void> _show(WidgetTester tester, Widget screen) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
  await users.ensureProfile(u);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userRepositoryProvider.overrideWithValue(users),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: ScreenCodeScope(
        visible: true,
        child: MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  const cases = <(String, Widget)>[
    (ScreenCodes.login, LoginScreen()),
    (ScreenCodes.role, RoleScreen()),
    (ScreenCodes.profile, ProfileTab()),
    (ScreenCodes.settings, SettingsScreen()),
    (ScreenCodes.register, RegisterScreen()),
    (ScreenCodes.editProfile, EditProfileScreen()),
  ];
  for (final (code, screen) in cases) {
    testWidgets('$code is shown on ${screen.runtimeType}', (tester) async {
      await _show(tester, screen);
      expect(find.text(code), findsOneWidget);
    });
  }
}
```

If a screen needs extra providers or a `Scaffold` ancestor that this harness lacks (the analyzer or a thrown error will name it), copy that screen's setup from its existing test file instead of changing the screen.

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/screen_codes_applied_test.dart`
Expected: FAIL, six times, "Expected: exactly one matching candidate. Actual: no matches".

- [ ] **Step 3: Implement** (one wrap per file)

```dart
// login_screen.dart  (the existing `return AnnotatedRegion<SystemUiOverlayStyle>(`)
    return ScreenCode(
      ScreenCodes.login,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyleFor(theme),
        child: Scaffold(/* unchanged */),
      ),
    );

// register_screen.dart  (same shape)
    return ScreenCode(
      ScreenCodes.register,
      child: AnnotatedRegion<SystemUiOverlayStyle>(/* unchanged */),
    );

// role_screen.dart, settings_screen.dart, edit_profile_screen.dart
    return ScreenCode(
      ScreenCodes.role,            // ScreenCodes.settings / ScreenCodes.editProfile
      child: AuroraBackground(/* unchanged */),
    );

// placeholder_tabs.dart, ProfileTab.build
    return ScreenCode(
      ScreenCodes.profile,
      child: Scaffold(/* unchanged */),
    );
```

Run `dart format` on the six files so indentation matches. Imports already contain `package:photobooking/core/core.dart` in all six; add it where missing.

- [ ] **Step 4: Run the full suite**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all tests pass (the earlier 94 plus the new ones). Existing screen tests are unaffected because `ScreenCode` returns `child` when no scope is present.

- [ ] **Step 5: Manual check, then commit**

Run `/run` (or `flutter run -d <device>`), open Settings → "Dành cho nhà phát triển" → turn on "Hiện mã màn hình"; confirm `S31` appears at the top-left of Settings, `S30` on the Profile tab, and that turning it off removes the tags. Tab screens sit below the status bar only if the shell leaves a safe-area inset; if a tag overlaps the status bar on a tab, that is acceptable for a debug aid.

```bash
git add lib test
git commit -m "feat(ui): screen codes on S28-S31, S41, S42

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Battery and performance check

**Files:**
- Create: `test/support/idle.dart`, `docs/testing/battery-and-performance.md` (repo root `docs/`, not `app_flutter/`)
- Modify: `test/core/widgets/screen_code_test.dart`, `test/features/settings/settings_test.dart`

**Interfaces:**
- Produces: `Future<void> expectIdle(WidgetTester tester)` (every later plan's battery task uses it) and the profiling guide `docs/testing/battery-and-performance.md` (every later plan's manual step follows it).

- [ ] **Step 1: Write the helper and the failing-if-busy tests**

```dart
// test/support/idle.dart
import 'package:flutter_test/flutter_test.dart';

/// Fails when something keeps scheduling frames at rest (a running
/// animation, ticker or repeating timer drains battery).
Future<void> expectIdle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 2));
  expect(tester.binding.transientCallbackCount, 0,
      reason: 'an animation or ticker keeps running at rest');
  expect(tester.binding.hasScheduledFrame, isFalse,
      reason: 'a frame is scheduled while nothing changes');
}
```

Append to `main()` in `test/core/widgets/screen_code_test.dart` (add `import '../../support/idle.dart';`):

```dart
  testWidgets('a shown tag costs no frames at rest', (tester) async {
    await tester.pumpWidget(_host(visible: true));
    await expectIdle(tester);
  });
```

Append to `main()` in `test/features/settings/settings_test.dart` (add `import '../../support/idle.dart';`):

```dart
  testWidgets('settings with the screen-code switch on stays idle', (tester) async {
    SharedPreferences.setMockInitialValues({'showScreenCodes': true});
    final prefs = await SharedPreferences.getInstance();
    final (auth, users) = await _signedIn();
    await tester.pumpWidget(await _app(auth: auth, users: users, prefs: prefs));
    await expectIdle(tester);
  });
```

- [ ] **Step 2: Run them**

Run: `flutter test test/core/widgets/screen_code_test.dart test/features/settings/settings_test.dart`
Expected: PASS. These are guard tests: they pass now and fail as soon as someone adds an endless animation or timer. If one fails, find the ticker (`flutter test --plain-name ...` then `debugPrintScheduleFrameStacks = true;` at the start of the test prints who scheduled the frame) and fix the code, not the test.

- [ ] **Step 3: Write the profiling guide**

Create `docs/testing/battery-and-performance.md` with exactly this content:

```markdown
# Kiểm tra pin và hiệu năng

Áp dụng cho mọi kế hoạch có màn hoặc widget mới. Phần tự động nằm trong test của từng kế hoạch (`test/support/idle.dart`); tài liệu này là phần đo tay trước khi merge.

## Quy tắc khi viết code

- Không có gì chạy khi người dùng không làm gì: không `Timer.periodic`, không polling mạng, animation chỉ chạy khi có tương tác và dừng hẳn sau đó. Vòng quay chờ (`CircularProgressIndicator`) chỉ hiện trong lúc thật sự chờ.
- Tôn trọng giảm chuyển động (`MediaQuery.disableAnimations`): hiện/ẩn tức thì.
- Mờ nền (`BackdropFilter`) tốn GPU: tối đa 4 vùng mờ trên một màn; phần tử nằm trong vùng đã mờ (thẻ trong `GlassCard`, ô trong sheet) không mờ lại; ô danh sách và thẻ lưới không bao giờ dùng `BackdropFilter`, dùng nền trong mờ (màu có alpha).
- Danh sách dài dùng `ListView.builder`/`SliverList`, không `Column` chứa hết phần tử.
- Ảnh giải mã đúng kích thước hiển thị (`cacheWidth`/`memCacheWidth`), không tải ảnh gốc cho thumbnail.
- Lắng nghe Firestore/stream gắn với màn (`autoDispose`): rời màn là huỷ. Chỉ phiên đăng nhập và hồ sơ của mình được giữ suốt vòng đời app.
- Vị trí: hỏi một lần (`getCurrentPosition`, độ chính xác thấp/trung bình, có hạn chờ), dùng lại vị trí đã lưu trong 15 phút; không theo dõi liên tục, không xin quyền chạy nền.
- Không dịch vụ nền, không wakelock.

## Đo tay (thiết bị Android thật, bản profile)

Chuẩn bị (từ `app_flutter/`):

```bash
flutter run --profile -d <device-id>
```

Gói ứng dụng: `com.thanhbk.photobooking`.

1. **Khung hình khi đứng yên.** Mở màn cần đo, chờ 5 giây, rồi:
   ```bash
   adb shell dumpsys gfxinfo com.thanhbk.photobooking reset
   ```
   Để yên 30 giây, rồi:
   ```bash
   adb shell dumpsys gfxinfo com.thanhbk.photobooking | grep -E "Total frames rendered|Janky frames"
   ```
   Ngưỡng: **≤ 5 khung hình** trong 30 giây.
2. **Cuộn và chuyển màn.** `reset` như trên, cuộn hết danh sách và quay lại 3 lần, rồi đọc `gfxinfo`. Ngưỡng: **Janky frames < 5%**, **90th percentile ≤ 16 ms**. Khi vượt, mở DevTools (Performance) xem khung nào chậm ở luồng UI hay raster.
3. **CPU khi đứng yên.**
   ```bash
   adb shell top -b -n 5 -d 2 | grep photobooking
   ```
   Ngưỡng: **< 3% CPU** trung bình khi màn đứng yên.
4. **Pin (10 phút dùng thử theo kịch bản của kế hoạch).**
   ```bash
   adb shell dumpsys battery unplug
   adb shell dumpsys batterystats --reset
   ```
   Dùng app 10 phút theo kịch bản, rồi:
   ```bash
   adb shell dumpsys batterystats --charged com.thanhbk.photobooking > battery.txt
   adb shell dumpsys battery reset
   ```
   Trong `battery.txt` kiểm: **không có Wake lock** của app; **GPS ≤ 15 giây** cho mỗi lần hỏi vị trí; mạng di động không bật liên tục khi đứng yên. Muốn xem đồ thị: `adb bugreport bugreport.zip` rồi mở bằng Battery Historian.
5. **Bộ nhớ** sau khi lướt hết các màn của kế hoạch:
   ```bash
   adb shell dumpsys meminfo com.thanhbk.photobooking | grep "TOTAL PSS"
   ```
   Ngưỡng: **< 250 MB**.

## Mẫu ghi kết quả (dán vào mô tả PR)

| Màn / kịch bản | Khung hình đứng yên (30 s) | Janky % | p90 (ms) | CPU đứng yên | Wake lock | GPS (s) | PSS (MB) | Thiết bị |
|---|---|---|---|---|---|---|---|---|
| S… | | | | | | | | |
```

- [ ] **Step 4: Manual profiling on a real Android device**

Follow `docs/testing/battery-and-performance.md` for the screens listed below (Genymotion is fine for the frame checks, but battery numbers need a real phone). Record the filled-in result table from that document in the PR description. Any value over a threshold blocks the merge: fix it in this plan's code, add a test that would have caught it, and re-measure.

Screens: S31 Cài đặt with the switch on and off, S28 Đăng nhập. Scenario for step 4 of the guide: open each of the six coded screens, toggle the switch twice, leave the app idle on Settings for the rest of the 10 minutes.

- [ ] **Step 5: Commit**

```bash
git add test/support/idle.dart test/core/widgets/screen_code_test.dart test/features/settings/settings_test.dart ../docs/testing/battery-and-performance.md
git commit -m "test: idle-frame guard and battery/performance guide

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage (section 2.1):** constants in `core/screen_codes.dart` (Task 1); widget with tag look, `IgnorePointer`, `SafeArea`, release passthrough, `label` sub-codes (Task 2); `showScreenCodesProvider` persisted in `SharedPreferences` next to `themeMode` (Task 3); Settings switch rendered only under `kDebugMode` (Task 4); tests for shown / hidden / unchanged layout (Task 2). Applying codes to existing screens (build-order step 0) is Task 5. Not covered here by design: codes for placeholder tabs (Home, Explore, Action, Bookings), which get their code when their real screen is built.
- **Placeholders:** none.
- **Type consistency:** `ScreenCodeScope.visible` / `visibleOf`, `ScreenCode(code, {label, child})`, `showScreenCodesProvider`, `ScreenCodes.*` names are the same in every task.
- **Known limit:** the release-mode passthrough (`kDebugMode == false`) cannot be unit-tested because `kDebugMode` is a compile-time constant; it is a single guard clause in `ScreenCode.build`.
- **Battery and performance:** Task 6 adds `expectIdle`, idle tests for the tag and Settings, and `docs/testing/battery-and-performance.md` (rules, adb measurements, thresholds, PR result table).
