# Flutter Foundation (Sub-project 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A runnable Flutter app in `app_flutter/` where a user can sign in (email, Google, Facebook), pick a role, and land on five role-aware tabs that show designed empty states.

**Architecture:** Feature-first Flutter app with Riverpod 2 for state, go_router with a stateful shell for the five tabs, and a `data/` layer of repositories (Firebase implementations plus in-memory fakes for tests). Theme is generated from `design-system/tokens.json` by a Dart script so the design system stays the single source of truth. Firestore security rules are tested against the emulator.

**Tech Stack:** Flutter stable (≥ 3.32), Dart 3, flutter_riverpod, go_router, freezed + json_serializable, firebase_core / firebase_auth / cloud_firestore, google_sign_in, flutter_facebook_auth, Firebase Emulator Suite, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-30-photography-marketplace-design.md` (sections 1, 3, 9, 10, 11, 12 row 1)

## Global Constraints

- Code lives in `app_flutter/` inside this repo; the legacy Java app under `app/` is untouched.
- Toolchain is project-local and needs no admin rights: Flutter SDK in `.flutter/`, Android SDK in `.android-sdk/`, JDK 17 via `scripts/env.sh`. All three directories are gitignored.
- Android `applicationId` stays `com.thanhbk.timnhay` so the existing Firebase project and `app/google-services.json` are reused. iOS bundle id `com.thanhbk.timnhay`.
- State management is Riverpod 2 `AsyncNotifier`/`Notifier`; no BLoC. UI never calls a repository directly, only a controller/provider.
- Navigation is go_router with `StatefulShellRoute.indexedStack`; tab paths are fixed: `/home`, `/explore`, `/action`, `/bookings`, `/profile`. Labels and screens depend on role.
- Every user-visible string is Vietnamese and lives in `lib/l10n/app_vi.arb`; no hard-coded UI strings in widgets.
- Colors, spacing, radius and type sizes come only from `lib/core/theme/tokens.g.dart` (generated). No literal `Color(0x…)` or magic dp in feature code.
- Firestore: clients may create/update only their own `users/{uid}` and `photographers/{uid}`; `bookings` are read-only for clients in this sub-project.
- Fonts: Be Vietnam Pro (body) and Fraunces (display) bundled in `assets/fonts/`.
- Minimum SDKs: Android 23, iOS 13.
- Responsive: every screen renders without overflow at 320, 360, 390 and 430 logical px wide and on tablets ≥ 600 (use `LayoutBuilder`; two columns for lists on tablets in later sub-projects). System text scale up to 1.3 must not clip. Sibling boxes in one `Row` (kpi tiles, fields, buttons) use `IntrinsicHeight` + `Expanded` so they grow with content and share one height. Long text wraps; no `TextOverflow.ellipsis` on primary content. Widget tests for screens run at `Size(320, 640)` and `Size(430, 932)` with `textScaler` 1.3.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

## Review Focus

1. A user whose `users/{uid}` document is missing (first sign-in, or deleted by admin) must land on role selection, never on a crashed home tab. Test in Task 7 (`UserRepository.ensureProfile`) and Task 9 (redirect with `role == null`).
2. Signing out while on a deep tab must return to `/login` and clear cached profile state so a second account does not see the first account's role. Test in Task 9 (`RouterNotifier` redirect on `null` user) and Task 10 (profile tab sign-out widget test).
3. Google or Facebook sign-in cancelled by the user must not show an error dialog and must re-enable the buttons. Test in Task 8 (`AuthError.cancelled` maps to no message).
4. Wrong password / unknown email / weak password / email already in use must show specific Vietnamese messages, not the raw Firebase text. Test in Task 7 (`mapAuthException`).
5. Firestore rules must reject a client that tries to write another user's document or to set `role` to a value outside `customer|photographer`. Test in Task 11.

---

## File Structure

```
scripts/install-flutter.sh                 downloads Flutter SDK into .flutter/ (no admin)
scripts/env.sh                             (modify) adds .flutter/bin to PATH
scripts/fetch-fonts.sh                     downloads TTFs into app_flutter/assets/fonts/
design-system/tokens.json                  (modify) warm neutrals + font families
app_flutter/
  pubspec.yaml
  analysis_options.yaml
  l10n.yaml
  lib/
    main.dart                              bootstrap: Firebase.initializeApp, ProviderScope, MyApp
    app/app.dart                           MaterialApp.router, theme, localization
    app/router.dart                        GoRouter, StatefulShellRoute, RouterNotifier (redirects)
    app/tabs.dart                          AppTab enum, TabSpec, tabsFor(role)
    core/theme/tokens.g.dart               GENERATED from design-system/tokens.json
    core/theme/app_theme.dart              ThemeData light/dark from tokens
    core/widgets/empty_state.dart          EmptyState(title, body, action)
    core/widgets/status_badge.dart         StatusBadge(BookingStatus)
    core/widgets/app_button.dart           AppButton.primary/outline/text
    data/user/user_profile.dart            UserProfile (freezed), UserRole enum
    data/user/user_repository.dart         abstract + FirestoreUserRepository + FakeUserRepository
    data/auth/auth_repository.dart         abstract + FirebaseAuthRepository + FakeAuthRepository
    data/auth/auth_error.dart              AuthError enum + mapAuthException
    data/auth/auth_providers.dart          authRepositoryProvider, authStateProvider, currentProfileProvider
    features/auth/login_screen.dart
    features/auth/register_screen.dart
    features/auth/auth_controller.dart     AsyncNotifier for sign-in/register actions
    features/onboarding/role_screen.dart   choose customer / photographer
    features/shell/tab_shell.dart          NavigationBar with role-aware TabSpecs
    features/shell/placeholder_tabs.dart   HomeTab, ExploreTab, ActionTab, BookingsTab, ProfileTab (empty states)
    firebase_options.dart                  from flutterfire configure (or manual)
    l10n/app_vi.arb
  tool/gen_tokens.dart                     tokens.json -> tokens.g.dart
  test/…                                   mirrors lib/
  firebase/firestore.rules, firebase.json, firestore.indexes.json
  firebase/rules-test/package.json, rules.test.mjs
.github/workflows/flutter.yml
```

---

### Task 1: Project-local Flutter SDK and project scaffold

**Files:**
- Create: `scripts/install-flutter.sh`
- Modify: `scripts/env.sh` (append PATH line)
- Modify: `.gitignore` (add `/.flutter`)
- Create: `app_flutter/` via `flutter create`

**Interfaces:**
- Produces: `app_flutter/` Flutter project with org `com.thanhbk`, project name `nhiep_anh_gia`, platforms android + ios.

- [ ] **Step 1: Write the installer script**

```bash
# scripts/install-flutter.sh
#!/usr/bin/env bash
# Installs Flutter stable into ./.flutter (no admin rights). Re-run to keep; delete .flutter to reset.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/.flutter"
if [ -x "$DEST/bin/flutter" ]; then echo "Flutter already in $DEST"; exit 0; fi
ARCH="$(uname -m)"; case "$ARCH" in arm64) A="arm64";; *) A="x64";; esac
# Resolve latest stable from the official release index.
JSON="$(curl -sSL https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json)"
REL="$(printf '%s' "$JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); h=d['current_release']['stable']; r=[x for x in d['releases'] if x['hash']==h and x.get('dart_sdk_arch')=='$A'][0]; print(d['base_url']+'/'+r['archive'])")"
echo "Downloading $REL"
TMP="$(mktemp -d)"; curl -sSL -o "$TMP/flutter.zip" "$REL"
unzip -q "$TMP/flutter.zip" -d "$ROOT" && rm -rf "$TMP"
"$DEST/bin/flutter" --version
```

- [ ] **Step 2: Wire PATH and gitignore**

Append to `scripts/env.sh` (after the `export PATH=` line):

```bash
export PATH="$ROOT/.flutter/bin:$PATH"
export PUB_CACHE="$ROOT/.pub-cache"
```

Append to `.gitignore`:

```
/.flutter
/.pub-cache
```

- [ ] **Step 3: Install and verify**

Run: `chmod +x scripts/install-flutter.sh && scripts/install-flutter.sh && source scripts/env.sh && flutter doctor -v`
Expected: `Flutter (Channel stable, 3.x)`; Android toolchain found at `.android-sdk`; Xcode line may be a warning on this machine (iOS builds are done later on a machine with Xcode). If `flutter doctor` says "Android license status unknown", run `flutter doctor --android-licenses` and accept.

- [ ] **Step 4: Create the project**

Run:
```bash
source scripts/env.sh
flutter create --org com.thanhbk --project-name nhiep_anh_gia --platforms android,ios app_flutter
```
Then set the Android application id: in `app_flutter/android/app/build.gradle.kts` change `applicationId = "com.thanhbk.nhiep_anh_gia"` to `applicationId = "com.thanhbk.timnhay"`, and `minSdk = 23`.

- [ ] **Step 5: Verify the scaffold builds and its default test passes**

Run: `cd app_flutter && flutter test`
Expected: `All tests passed!` (1 test).

- [ ] **Step 6: Commit**

```bash
git add scripts/install-flutter.sh scripts/env.sh .gitignore app_flutter
git commit -m "chore(flutter): scaffold app_flutter with project-local Flutter SDK

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Dependencies, lints, folder layout, bootstrap

**Files:**
- Modify: `app_flutter/pubspec.yaml`
- Modify: `app_flutter/analysis_options.yaml`
- Create: `app_flutter/l10n.yaml`, `app_flutter/lib/l10n/app_vi.arb`
- Create: `app_flutter/lib/main.dart`, `app_flutter/lib/app/app.dart`
- Test: `app_flutter/test/app/app_test.dart`

**Interfaces:**
- Produces: `MyApp` widget (`lib/app/app.dart`) taking a `GoRouter router`; `bootstrap()` in `main.dart`. Localization class `AppLocalizations` (generated) reachable as `context.l10n`.

- [ ] **Step 1: Add dependencies**

Run inside `app_flutter/`:
```bash
flutter pub add flutter_riverpod go_router freezed_annotation json_annotation firebase_core firebase_auth cloud_firestore google_sign_in flutter_facebook_auth intl
flutter pub add --dev build_runner freezed json_serializable flutter_lints mocktail
```
(`flutter pub add` resolves the newest compatible versions; do not hand-pin.)

- [ ] **Step 2: Enable localization**

`app_flutter/l10n.yaml`:
```yaml
arb-dir: lib/l10n
template-arb-file: app_vi.arb
output-localization-file: app_localizations.dart
nullable-getter: false
```
In `pubspec.yaml` under `flutter:` add `generate: true`, and under `dependencies:` add `flutter_localizations:\n    sdk: flutter`.

`app_flutter/lib/l10n/app_vi.arb`:
```json
{
  "@@locale": "vi",
  "appName": "Cộng đồng nhiếp ảnh gia",
  "tabHome": "Trang chủ",
  "tabExplore": "Khám phá",
  "tabFind": "Tìm thợ ảnh",
  "tabCreate": "Đăng bài",
  "tabBookings": "Đặt lịch",
  "tabWork": "Công việc",
  "tabProfile": "Hồ sơ",
  "loginTitle": "Đăng nhập",
  "registerTitle": "Tạo tài khoản",
  "emailLabel": "Email",
  "passwordLabel": "Mật khẩu",
  "passwordConfirmLabel": "Nhập lại mật khẩu",
  "displayNameLabel": "Tên hiển thị",
  "loginButton": "Đăng nhập",
  "registerButton": "Đăng ký",
  "continueWithGoogle": "Tiếp tục với Google",
  "continueWithFacebook": "Tiếp tục với Facebook",
  "noAccountRegister": "Chưa có tài khoản? Đăng ký",
  "haveAccountLogin": "Đã có tài khoản? Đăng nhập",
  "signOut": "Đăng xuất",
  "errorEmailInvalid": "Email không hợp lệ.",
  "errorPasswordShort": "Mật khẩu cần ít nhất 8 ký tự.",
  "errorPasswordMismatch": "Mật khẩu nhập lại không khớp.",
  "errorNameEmpty": "Vui lòng nhập tên hiển thị.",
  "authErrorWrongPassword": "Email hoặc mật khẩu không đúng.",
  "authErrorUserNotFound": "Không tìm thấy tài khoản với email này.",
  "authErrorEmailInUse": "Email này đã được dùng. Hãy đăng nhập.",
  "authErrorWeakPassword": "Mật khẩu quá yếu. Dùng ít nhất 8 ký tự.",
  "authErrorNetwork": "Không có kết nối. Kiểm tra mạng rồi thử lại.",
  "authErrorUnknown": "Đăng nhập không thành công. Thử lại sau.",
  "roleTitle": "Bạn muốn làm gì?",
  "roleCustomerTitle": "Thuê nhiếp ảnh gia",
  "roleCustomerBody": "Khám phá ảnh đẹp, đặt lịch chụp trong vài chạm.",
  "rolePhotographerTitle": "Nhận chụp",
  "rolePhotographerBody": "Đăng ảnh, nhận yêu cầu, quản lý lịch và doanh thu.",
  "roleContinue": "Tiếp tục",
  "emptyHomeTitle": "Ảnh đẹp sẽ xuất hiện ở đây",
  "emptyHomeBody": "Theo dõi nhiếp ảnh gia bạn thích để bắt đầu.",
  "emptyExploreTitle": "Khám phá theo dịch vụ và địa điểm",
  "emptyExploreBody": "Chân dung, cưới, gia đình, kỷ yếu và hơn thế.",
  "emptyFindTitle": "Tìm nhiếp ảnh gia rảnh đúng ngày bạn cần",
  "emptyFindBody": "Chọn địa điểm, ngày và dịch vụ để so sánh.",
  "emptyCreateTitle": "Cho mọi người thấy bạn chụp gì",
  "emptyCreateBody": "Mỗi bài đăng gắn một gói dịch vụ để khách đặt ngay.",
  "emptyBookingsTitle": "Buổi chụp tiếp theo bắt đầu từ đây",
  "emptyBookingsBody": "Yêu cầu và lịch chụp của bạn sẽ hiện ở đây.",
  "emptyWorkTitle": "Chưa có yêu cầu nào",
  "emptyWorkBody": "Hoàn thiện hồ sơ và đăng ảnh để được tìm thấy.",
  "profileRoleCustomer": "Khách hàng",
  "profileRolePhotographer": "Nhiếp ảnh gia",
  "statusRequested": "Đã gửi",
  "statusAccepted": "Đã nhận",
  "statusDeclined": "Từ chối",
  "statusExpired": "Hết hạn",
  "statusCancelled": "Đã huỷ",
  "statusUpcoming": "Sắp tới",
  "statusCompleted": "Hoàn thành",
  "statusReviewed": "Đã đánh giá"
}
```

- [ ] **Step 3: Lints and l10n extension**

`app_flutter/analysis_options.yaml`:
```yaml
include: package:flutter_lints/flutter.yaml
analyzer:
  exclude: [lib/**/*.g.dart, lib/**/*.freezed.dart, lib/l10n/*.dart]
linter:
  rules:
    prefer_const_constructors: true
    avoid_print: true
    require_trailing_commas: true
```

`app_flutter/lib/core/l10n_ext.dart`:
```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

- [ ] **Step 4: Write the failing app test**

`app_flutter/test/app/app_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nhiep_anh_gia/app/app.dart';

void main() {
  testWidgets('MyApp renders the route given by the router', (tester) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, __) => const Text('ok'))],
    );
    await tester.pumpWidget(MyApp(router: router));
    await tester.pumpAndSettle();
    expect(find.text('ok'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Run it to verify it fails**

Run: `cd app_flutter && flutter test test/app/app_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:nhiep_anh_gia/app/app.dart'`.

- [ ] **Step 6: Implement app and bootstrap**

`app_flutter/lib/app/app.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.router, this.theme, this.darkTheme});
  final GoRouter router;
  final ThemeData? theme;
  final ThemeData? darkTheme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appName,
      routerConfig: router,
      theme: theme,
      darkTheme: darkTheme,
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}
```

`app_flutter/lib/main.dart` (router, theme and Firebase are wired in Tasks 3, 5, 6; keep this minimal now):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: _Root()));
}

class _Root extends ConsumerWidget {
  const _Root();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, __) => const Scaffold())],
    );
    return MyApp(router: router);
  }
}
```

- [ ] **Step 7: Generate l10n and run the test**

Run: `flutter gen-l10n && flutter test test/app/app_test.dart && flutter analyze`
Expected: PASS; `No issues found!`.

- [ ] **Step 8: Commit**

```bash
git add app_flutter
git commit -m "feat(flutter): dependencies, lints, Vietnamese l10n and app bootstrap

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Design tokens → Dart theme

**Files:**
- Modify: `design-system/tokens.json` (add warm neutrals + fonts)
- Create: `app_flutter/tool/gen_tokens.dart`
- Create: `app_flutter/lib/core/theme/tokens.g.dart` (generated, committed)
- Create: `app_flutter/lib/core/theme/app_theme.dart`
- Create: `scripts/fetch-fonts.sh`, `app_flutter/assets/fonts/*.ttf`
- Test: `app_flutter/test/core/theme/tokens_test.dart`, `app_flutter/test/core/theme/app_theme_test.dart`

**Interfaces:**
- Produces: `class AppColors { static const Color primary; background; backgroundSubtle; surface; surfaceMuted; foreground; foregroundSecondary; foregroundMuted; foregroundDisabled; foregroundInverse; primaryPressed; primarySubtle; destructive; success; warning; error; info; border; borderStrong; divider; bookingWaiting; bookingAccepted; bookingDenied; bookingOpened; bookingClosed; … }` (one static per semantic color token, camelCase), `class AppColorsDark` (same names, dark overrides falling back to light), `class AppSpace { static const double s1=4 … s16=64 }`, `class AppRadius { sm, md, lg, full }`, `class AppText { xs, sm, base, md, lg, xl, xxl }`, `class AppFonts { display='Fraunces'; body='Be Vietnam Pro' }`.
- Produces: `ThemeData buildLightTheme()`, `ThemeData buildDarkTheme()` in `app_theme.dart`.

- [ ] **Step 1: Extend tokens.json**

In `design-system/tokens.json`:
- Under `primitive.color` add
  ```json
  "sand": {
    "50":  { "$value": "#F4F1EC", "$type": "color" },
    "100": { "$value": "#EDE9E3", "$type": "color" },
    "200": { "$value": "#E3DFD8", "$type": "color" },
    "300": { "$value": "#CFCAC1", "$type": "color" }
  }
  ```
- Change semantic: `background` → `{primitive.color.sand.50}`, `background-subtle` → `{primitive.color.sand.100}`, `surface-muted` → `{primitive.color.sand.100}`, `border` → `{primitive.color.sand.200}`, `border-strong` → `{primitive.color.sand.300}`, `divider` → `{primitive.color.sand.200}`.
- Add top-level `"font": { "display": { "$value": "Fraunces", "$type": "fontFamily" }, "body": { "$value": "Be Vietnam Pro", "$type": "fontFamily" } }` inside `primitive`.
- Regenerate CSS: `node ~/.claude/skills/design-system/scripts/generate-tokens.cjs --config design-system/tokens.json -o design-system/tokens.css`.

- [ ] **Step 2: Write the failing tokens test**

`app_flutter/test/core/theme/tokens_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/core/theme/tokens.g.dart';

void main() {
  test('semantic colors resolve primitive references', () {
    expect(AppColors.primary, const Color(0xFF05749F));
    expect(AppColors.background, const Color(0xFFF4F1EC));
    expect(AppColors.overlay, const Color(0x6A000000));
  });
  test('dark overrides differ from light and fall back when absent', () {
    expect(AppColorsDark.background, const Color(0xFF1C1C1C));
    expect(AppColorsDark.destructive, AppColors.destructive);
  });
  test('spacing is a 4dp grid', () {
    expect(AppSpace.s1, 4);
    expect(AppSpace.s4, 16);
    expect(AppSpace.s16, 64);
  });
  test('fonts and radius', () {
    expect(AppFonts.display, 'Fraunces');
    expect(AppRadius.md, 8);
    expect(AppText.base, 14);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/core/theme/tokens_test.dart`
Expected: FAIL, `tokens.g.dart` does not exist.

- [ ] **Step 4: Write the generator**

`app_flutter/tool/gen_tokens.dart`:
```dart
// Usage: dart run tool/gen_tokens.dart  (run from app_flutter/)
// Reads ../design-system/tokens.json and writes lib/core/theme/tokens.g.dart
import 'dart:convert';
import 'dart:io';

late Map<String, dynamic> root;

dynamic resolve(dynamic v) {
  if (v is String && v.startsWith('{') && v.endsWith('}')) {
    dynamic cur = root;
    for (final k in v.substring(1, v.length - 1).split('.')) {
      cur = (cur as Map<String, dynamic>)[k];
    }
    return resolve((cur as Map<String, dynamic>)[r'$value']);
  }
  return v;
}

String camel(String s) {
  final parts = s.split(RegExp(r'[-_]'));
  return parts.first + parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

String color(String hex) {
  var h = hex.replaceFirst('#', '').toUpperCase();
  if (h.length == 6) h = 'FF$h';
  return 'Color(0x$h)';
}

double dim(String v) => double.parse(v.replaceAll(RegExp(r'[a-z]+$'), ''));

void main() {
  root = jsonDecode(File('../design-system/tokens.json').readAsStringSync()) as Map<String, dynamic>;
  final sem = root['semantic'] as Map<String, dynamic>;
  final semColors = sem['color'] as Map<String, dynamic>;
  final dark = ((root['dark'] as Map<String, dynamic>)['semantic'] as Map<String, dynamic>)['color'] as Map<String, dynamic>;
  final prim = root['primitive'] as Map<String, dynamic>;
  final b = StringBuffer('// GENERATED by tool/gen_tokens.dart from design-system/tokens.json. Do not edit.\n')
    ..writeln("import 'package:flutter/material.dart';\n")
    ..writeln('class AppColors {\n  AppColors._();');
  for (final e in semColors.entries) {
    b.writeln('  static const Color ${camel(e.key)} = ${color(resolve(e.value[r'$value']) as String)};');
  }
  b.writeln('}\n\nclass AppColorsDark {\n  AppColorsDark._();');
  for (final e in semColors.entries) {
    final d = dark[e.key];
    b.writeln(d == null
        ? '  static const Color ${camel(e.key)} = AppColors.${camel(e.key)};'
        : '  static const Color ${camel(e.key)} = ${color(resolve(d[r'$value']) as String)};');
  }
  b.writeln('}\n\nclass AppSpace {\n  AppSpace._();');
  for (final e in (prim['spacing'] as Map<String, dynamic>).entries) {
    b.writeln('  static const double s${e.key} = ${dim(e.value[r'$value'] as String)};');
  }
  b.writeln('}\n\nclass AppRadius {\n  AppRadius._();');
  for (final e in (prim['radius'] as Map<String, dynamic>).entries) {
    b.writeln('  static const double ${camel(e.key)} = ${dim(e.value[r'$value'] as String)};');
  }
  b.writeln('}\n\nclass AppText {\n  AppText._();');
  for (final e in (prim['fontSize'] as Map<String, dynamic>).entries) {
    final name = e.key == '2xl' ? 'xxl' : e.key;
    b.writeln('  static const double $name = ${dim(e.value[r'$value'] as String)};');
  }
  b.writeln('}\n\nclass AppFonts {\n  AppFonts._();');
  for (final e in (prim['font'] as Map<String, dynamic>).entries) {
    b.writeln("  static const String ${e.key} = '${e.value[r'$value']}';");
  }
  b.writeln('}');
  File('lib/core/theme/tokens.g.dart').writeAsStringSync(b.toString());
  stdout.writeln('wrote lib/core/theme/tokens.g.dart');
}
```

- [ ] **Step 5: Generate and run the tokens test**

Run: `mkdir -p lib/core/theme && dart run tool/gen_tokens.dart && dart format lib/core/theme/tokens.g.dart && flutter test test/core/theme/tokens_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Fonts**

`scripts/fetch-fonts.sh`:
```bash
#!/usr/bin/env bash
# Downloads the two bundled fonts (OFL) from the google/fonts repository into app_flutter/assets/fonts.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
D="$ROOT/app_flutter/assets/fonts"; mkdir -p "$D"
B="https://raw.githubusercontent.com/google/fonts/main/ofl"
for w in Regular Medium SemiBold Bold; do curl -sSL -o "$D/BeVietnamPro-$w.ttf" "$B/bevietnampro/BeVietnamPro-$w.ttf"; done
curl -sSL -o "$D/Fraunces-Variable.ttf" "$B/fraunces/Fraunces%5BSOFT%2CWONK%2Copsz%2Cwght%5D.ttf"
curl -sSL -o "$D/OFL.txt" "$B/bevietnampro/OFL.txt"
ls -la "$D"
```
Run `chmod +x scripts/fetch-fonts.sh && scripts/fetch-fonts.sh`, then in `pubspec.yaml` under `flutter:`:
```yaml
  fonts:
    - family: Be Vietnam Pro
      fonts:
        - asset: assets/fonts/BeVietnamPro-Regular.ttf
        - asset: assets/fonts/BeVietnamPro-Medium.ttf
          weight: 500
        - asset: assets/fonts/BeVietnamPro-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/BeVietnamPro-Bold.ttf
          weight: 700
    - family: Fraunces
      fonts:
        - asset: assets/fonts/Fraunces-Variable.ttf
```

- [ ] **Step 7: Write the failing theme test**

`app_flutter/test/core/theme/app_theme_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/core/theme/app_theme.dart';
import 'package:nhiep_anh_gia/core/theme/tokens.g.dart';

void main() {
  test('light theme uses token colors and fonts', () {
    final t = buildLightTheme();
    expect(t.colorScheme.primary, AppColors.primary);
    expect(t.scaffoldBackgroundColor, AppColors.background);
    expect(t.textTheme.bodyMedium!.fontFamily, AppFonts.body);
    expect(t.textTheme.headlineMedium!.fontFamily, AppFonts.display);
    expect(t.useMaterial3, isTrue);
  });
  test('dark theme is dark and keeps the accent readable', () {
    final t = buildDarkTheme();
    expect(t.brightness, Brightness.dark);
    expect(t.colorScheme.primary, AppColorsDark.primary);
    expect(t.scaffoldBackgroundColor, AppColorsDark.background);
  });
}
```

- [ ] **Step 8: Run it to verify it fails**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: FAIL, `app_theme.dart` missing.

- [ ] **Step 9: Implement the theme**

`app_flutter/lib/core/theme/app_theme.dart`:
```dart
import 'package:flutter/material.dart';
import 'tokens.g.dart';

ThemeData buildLightTheme() => _build(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      background: AppColors.background,
      surface: AppColors.surface,
      surfaceMuted: AppColors.surfaceMuted,
      foreground: AppColors.foreground,
      foregroundSecondary: AppColors.foregroundSecondary,
      border: AppColors.border,
      error: AppColors.error,
    );

ThemeData buildDarkTheme() => _build(
      brightness: Brightness.dark,
      primary: AppColorsDark.primary,
      onPrimary: AppColorsDark.primaryForeground,
      background: AppColorsDark.background,
      surface: AppColorsDark.surface,
      surfaceMuted: AppColorsDark.surfaceMuted,
      foreground: AppColorsDark.foreground,
      foregroundSecondary: AppColorsDark.foregroundSecondary,
      border: AppColorsDark.border,
      error: AppColorsDark.error,
    );

ThemeData _build({
  required Brightness brightness,
  required Color primary,
  required Color onPrimary,
  required Color background,
  required Color surface,
  required Color surfaceMuted,
  required Color foreground,
  required Color foregroundSecondary,
  required Color border,
  required Color error,
}) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    secondary: surfaceMuted,
    onSecondary: foreground,
    error: error,
    onError: Colors.white,
    surface: surface,
    onSurface: foreground,
    outline: border,
  );
  TextStyle body(double size, {FontWeight w = FontWeight.w400, Color? c}) =>
      TextStyle(fontFamily: AppFonts.body, fontSize: size, fontWeight: w, color: c ?? foreground, height: 1.4);
  TextStyle display(double size) =>
      TextStyle(fontFamily: AppFonts.display, fontSize: size, fontWeight: FontWeight.w500, color: foreground, height: 1.15);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    fontFamily: AppFonts.body,
    textTheme: TextTheme(
      displayLarge: display(AppText.xxl),
      headlineMedium: display(AppText.xl),
      titleLarge: display(AppText.lg),
      titleMedium: body(AppText.md, w: FontWeight.w600),
      bodyLarge: body(AppText.md),
      bodyMedium: body(AppText.base),
      bodySmall: body(AppText.sm, c: foregroundSecondary),
      labelLarge: body(AppText.base, w: FontWeight.w600),
      labelSmall: body(AppText.xs, w: FontWeight.w500, c: foregroundSecondary),
    ),
    appBarTheme: AppBarTheme(backgroundColor: background, foregroundColor: foreground, elevation: 0, scrolledUnderElevation: 0),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSpace.s12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: body(AppText.base, w: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSpace.s12),
        side: BorderSide(color: border),
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s3, vertical: AppSpace.s3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: primary, width: 2)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => body(AppText.xs, w: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500),
      ),
    ),
    dividerColor: border,
  );
}
```

- [ ] **Step 10: Run tests and commit**

Run: `flutter test test/core/theme && flutter analyze`
Expected: PASS (6 tests), no issues.

```bash
git add design-system app_flutter scripts/fetch-fonts.sh
git commit -m "feat(flutter): generate theme from design tokens, bundle fonts

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: Core widgets: EmptyState, StatusBadge, AppButton

**Files:**
- Create: `app_flutter/lib/core/widgets/empty_state.dart`, `status_badge.dart`, `app_button.dart`
- Create: `app_flutter/lib/data/booking/booking_status.dart`
- Test: `app_flutter/test/core/widgets/empty_state_test.dart`, `status_badge_test.dart`

**Interfaces:**
- Produces: `EmptyState({required String title, required String body, String? actionLabel, VoidCallback? onAction, Widget? illustration})`; `enum BookingStatus { draft, requested, accepted, declined, expired, cancelled, upcoming, completed, reviewed }` with `Color color` and `String label(AppLocalizations)`; `StatusBadge(BookingStatus)`; `AppButton.primary(label, onPressed, {loading})`, `AppButton.outline(...)`, `AppButton.text(...)`.

- [ ] **Step 1: Write the failing widget tests**

`app_flutter/test/core/widgets/empty_state_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/core/widgets/empty_state.dart';

void main() {
  testWidgets('shows title, body and calls action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EmptyState(
          title: 'Tiêu đề',
          body: 'Nội dung',
          actionLabel: 'Làm gì đó',
          onAction: () => tapped = true,
        ),
      ),
    ));
    expect(find.text('Tiêu đề'), findsOneWidget);
    expect(find.text('Nội dung'), findsOneWidget);
    await tester.tap(find.text('Làm gì đó'));
    expect(tapped, isTrue);
  });
  testWidgets('hides the button when there is no action', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: EmptyState(title: 'a', body: 'b'))));
    expect(find.byType(FilledButton), findsNothing);
  });
}
```

`app_flutter/test/core/widgets/status_badge_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:nhiep_anh_gia/core/theme/tokens.g.dart';
import 'package:nhiep_anh_gia/core/widgets/status_badge.dart';
import 'package:nhiep_anh_gia/data/booking/booking_status.dart';

void main() {
  testWidgets('badge shows Vietnamese label and status color', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: StatusBadge(BookingStatus.accepted)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('ĐÃ NHẬN'), findsOneWidget);
    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    expect((box.decoration as BoxDecoration).color, AppColors.bookingAccepted);
  });
  test('every status has a color and a label key', () {
    for (final s in BookingStatus.values) {
      expect(s.color, isA<Color>());
    }
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/core/widgets`
Expected: FAIL, missing files.

- [ ] **Step 3: Implement**

`app_flutter/lib/data/booking/booking_status.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/theme/tokens.g.dart';

enum BookingStatus { draft, requested, accepted, declined, expired, cancelled, upcoming, completed, reviewed }

extension BookingStatusX on BookingStatus {
  Color get color => switch (this) {
        BookingStatus.draft || BookingStatus.requested => AppColors.bookingWaiting,
        BookingStatus.accepted => AppColors.bookingAccepted,
        BookingStatus.declined || BookingStatus.cancelled || BookingStatus.expired => AppColors.bookingDenied,
        BookingStatus.upcoming => AppColors.bookingOpened,
        BookingStatus.completed || BookingStatus.reviewed => AppColors.bookingClosed,
      };

  /// Text color on top of [color]; the warning yellow needs dark text.
  Color get onColor => this == BookingStatus.upcoming ? AppColors.foreground : AppColors.foregroundInverse;

  String label(AppLocalizations l) => switch (this) {
        BookingStatus.draft || BookingStatus.requested => l.statusRequested,
        BookingStatus.accepted => l.statusAccepted,
        BookingStatus.declined => l.statusDeclined,
        BookingStatus.expired => l.statusExpired,
        BookingStatus.cancelled => l.statusCancelled,
        BookingStatus.upcoming => l.statusUpcoming,
        BookingStatus.completed => l.statusCompleted,
        BookingStatus.reviewed => l.statusReviewed,
      };
}
```

`app_flutter/lib/core/widgets/status_badge.dart`:
```dart
import 'package:flutter/material.dart';
import '../l10n_ext.dart';
import '../theme/tokens.g.dart';
import '../../data/booking/booking_status.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final BookingStatus status;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: status.color, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2, vertical: AppSpace.s1),
        child: Text(
          status.label(context.l10n).toUpperCase(),
          style: TextStyle(fontSize: AppText.xs, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: status.onColor),
        ),
      ),
    );
  }
}
```

`app_flutter/lib/core/widgets/app_button.dart`:
```dart
import 'package:flutter/material.dart';

enum _Kind { primary, outline, text }

class AppButton extends StatelessWidget {
  const AppButton.primary(this.label, {super.key, required this.onPressed, this.loading = false}) : _kind = _Kind.primary;
  const AppButton.outline(this.label, {super.key, required this.onPressed, this.loading = false}) : _kind = _Kind.outline;
  const AppButton.text(this.label, {super.key, required this.onPressed, this.loading = false}) : _kind = _Kind.text;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final _Kind _kind;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : Text(label);
    final cb = loading ? null : onPressed;
    return switch (_kind) {
      _Kind.primary => FilledButton(onPressed: cb, child: child),
      _Kind.outline => OutlinedButton(onPressed: cb, child: child),
      _Kind.text => TextButton(onPressed: cb, child: child),
    };
  }
}
```

`app_flutter/lib/core/widgets/empty_state.dart`:
```dart
import 'package:flutter/material.dart';
import '../theme/tokens.g.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.body, this.actionLabel, this.onAction, this.illustration});
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? illustration;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration ??
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary, shape: BoxShape.circle),
                ),
            const SizedBox(height: AppSpace.s4),
            Text(title, style: t.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.s2),
            Text(body, style: t.bodySmall, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpace.s4),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests and commit**

Run: `flutter test test/core/widgets && flutter analyze`
Expected: PASS (4 tests).

```bash
git add app_flutter
git commit -m "feat(flutter): core widgets EmptyState, StatusBadge, AppButton and BookingStatus

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: User model, role and tab specs

**Files:**
- Create: `app_flutter/lib/data/user/user_profile.dart` (+ generated `.freezed.dart`, `.g.dart`)
- Create: `app_flutter/lib/app/tabs.dart`
- Test: `app_flutter/test/data/user/user_profile_test.dart`, `app_flutter/test/app/tabs_test.dart`

**Interfaces:**
- Produces: `enum UserRole { customer, photographer }` (JSON values `"customer"`, `"photographer"`); `UserProfile({required String uid, UserRole? role, required String displayName, String? avatarUrl, String? email})` with `fromJson/toJson` and `bool get needsRole => role == null`.
- Produces: `enum AppTab { home, explore, action, bookings, profile }` with `String get path`; `class TabSpec { AppTab tab; String Function(AppLocalizations) label; IconData icon; }`; `List<TabSpec> tabsFor(UserRole role)`.

- [ ] **Step 1: Write the failing tests**

`app_flutter/test/data/user/user_profile_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/data/user/user_profile.dart';

void main() {
  test('round-trips JSON with role as snake string', () {
    const p = UserProfile(uid: 'u1', role: UserRole.photographer, displayName: 'Minh Trí');
    final json = p.toJson();
    expect(json['role'], 'photographer');
    expect(UserProfile.fromJson(json), p);
  });
  test('needsRole is true when role missing', () {
    expect(UserProfile.fromJson({'uid': 'u', 'displayName': 'x'}).needsRole, isTrue);
  });
}
```

`app_flutter/test/app/tabs_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/app/tabs.dart';
import 'package:nhiep_anh_gia/data/user/user_profile.dart';

void main() {
  test('paths are fixed and ordered', () {
    expect(AppTab.values.map((t) => t.path), ['/home', '/explore', '/action', '/bookings', '/profile']);
  });
  test('middle and bookings tabs change by role', () {
    final c = tabsFor(UserRole.customer);
    final p = tabsFor(UserRole.photographer);
    expect(c.length, 5);
    expect(c[2].labelKey, 'tabFind');
    expect(p[2].labelKey, 'tabCreate');
    expect(c[3].labelKey, 'tabBookings');
    expect(p[3].labelKey, 'tabWork');
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/data/user test/app/tabs_test.dart`
Expected: FAIL, missing files.

- [ ] **Step 3: Implement**

`app_flutter/lib/data/user/user_profile.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

enum UserRole {
  @JsonValue('customer')
  customer,
  @JsonValue('photographer')
  photographer,
}

@freezed
class UserProfile with _$UserProfile {
  const UserProfile._();
  const factory UserProfile({
    required String uid,
    UserRole? role,
    required String displayName,
    String? avatarUrl,
    String? email,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);

  bool get needsRole => role == null;
}
```

`app_flutter/lib/app/tabs.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../data/user/user_profile.dart';

enum AppTab {
  home('/home'),
  explore('/explore'),
  action('/action'),
  bookings('/bookings'),
  profile('/profile');

  const AppTab(this.path);
  final String path;
}

class TabSpec {
  const TabSpec({required this.tab, required this.labelKey, required this.icon, this.emphasized = false});
  final AppTab tab;
  /// Key in app_vi.arb; resolved with [label].
  final String labelKey;
  final IconData icon;
  final bool emphasized;

  String label(AppLocalizations l) => switch (labelKey) {
        'tabHome' => l.tabHome,
        'tabExplore' => l.tabExplore,
        'tabFind' => l.tabFind,
        'tabCreate' => l.tabCreate,
        'tabBookings' => l.tabBookings,
        'tabWork' => l.tabWork,
        'tabProfile' => l.tabProfile,
        _ => labelKey,
      };
}

List<TabSpec> tabsFor(UserRole role) {
  final isPhotographer = role == UserRole.photographer;
  return [
    const TabSpec(tab: AppTab.home, labelKey: 'tabHome', icon: Icons.home_outlined),
    const TabSpec(tab: AppTab.explore, labelKey: 'tabExplore', icon: Icons.explore_outlined),
    TabSpec(
      tab: AppTab.action,
      labelKey: isPhotographer ? 'tabCreate' : 'tabFind',
      icon: isPhotographer ? Icons.add : Icons.search,
      emphasized: true,
    ),
    TabSpec(
      tab: AppTab.bookings,
      labelKey: isPhotographer ? 'tabWork' : 'tabBookings',
      icon: Icons.calendar_today_outlined,
    ),
    const TabSpec(tab: AppTab.profile, labelKey: 'tabProfile', icon: Icons.person_outline),
  ];
}
```

- [ ] **Step 4: Generate code, run tests, commit**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/data/user test/app/tabs_test.dart && flutter analyze`
Expected: PASS (4 tests).

```bash
git add app_flutter
git commit -m "feat(flutter): UserProfile model with role and role-aware tab specs

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Firebase configuration

**Files:**
- Create: `app_flutter/lib/firebase_options.dart`
- Copy: `app/google-services.json` → `app_flutter/android/app/google-services.json`
- Modify: `app_flutter/android/settings.gradle.kts`, `app_flutter/android/app/build.gradle.kts` (google-services plugin), `app_flutter/android/app/src/main/res/values/strings.xml` (Facebook), `app_flutter/android/app/src/main/AndroidManifest.xml`
- Modify: `app_flutter/lib/main.dart`

**Interfaces:**
- Produces: `DefaultFirebaseOptions.currentPlatform`; `main()` initializes Firebase before `runApp`.

- [ ] **Step 1: Generate options**

Preferred (needs Firebase CLI logged in):
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project="$(python3 -c "import json;print(json.load(open('../app/google-services.json'))['project_info']['project_id'])")" \
  --platforms=android,ios --android-package-name=com.thanhbk.timnhay --ios-bundle-id=com.thanhbk.timnhay --yes
```
Fallback without CLI: create `lib/firebase_options.dart` by hand, copying values from `app/google-services.json` (`project_info.project_id`, `project_info.project_number` → `messagingSenderId`, `project_info.storage_bucket`, `client[0].client_info.mobilesdk_app_id` → `appId`, `client[0].api_key[0].current_key` → `apiKey`):
```dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => switch (defaultTargetPlatform) {
        TargetPlatform.android => android,
        TargetPlatform.iOS => ios,
        _ => throw UnsupportedError('Platform not configured'),
      };

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '<client[0].api_key[0].current_key>',
    appId: '<client[0].client_info.mobilesdk_app_id>',
    messagingSenderId: '<project_info.project_number>',
    projectId: '<project_info.project_id>',
    storageBucket: '<project_info.storage_bucket>',
  );

  // iOS app must be added in the Firebase console (bundle id com.thanhbk.timnhay); paste GoogleService-Info.plist values here.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '<IOS API_KEY>',
    appId: '<IOS GOOGLE_APP_ID>',
    messagingSenderId: '<project_info.project_number>',
    projectId: '<project_info.project_id>',
    storageBucket: '<project_info.storage_bucket>',
    iosBundleId: 'com.thanhbk.timnhay',
  );
}
```
Add `lib/firebase_options.dart` and `android/app/google-services.json` to `app_flutter/.gitignore` (they contain keys; the legacy repo already leaks them, do not add more copies).

- [ ] **Step 2: Android Gradle wiring**

`app_flutter/android/settings.gradle.kts` → inside `plugins { … }` add `id("com.google.gms.google-services") version "4.4.2" apply false`.
`app_flutter/android/app/build.gradle.kts` → in `plugins { … }` add `id("com.google.gms.google-services")`.
Copy config: `cp app/google-services.json app_flutter/android/app/google-services.json`.

- [ ] **Step 3: Facebook and Google sign-in Android config**

`app_flutter/android/app/src/main/res/values/strings.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="facebook_app_id">546233675712070</string>
    <string name="fb_login_protocol_scheme">fb546233675712070</string>
    <!-- Meta developer console > Settings > Advanced > Client token -->
    <string name="facebook_client_token"></string>
</resources>
```
In `AndroidManifest.xml` inside `<application>`:
```xml
<meta-data android:name="com.facebook.sdk.ApplicationId" android:value="@string/facebook_app_id"/>
<meta-data android:name="com.facebook.sdk.ClientToken" android:value="@string/facebook_client_token"/>
<activity android:name="com.facebook.FacebookActivity" android:configChanges="keyboard|keyboardHidden|screenLayout|shiftMode|screenSize|orientation" android:label="@string/app_name"/>
<activity android:name="com.facebook.CustomTabActivity" android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="@string/fb_login_protocol_scheme"/>
    </intent-filter>
</activity>
```
Google Sign-In on Android needs the debug SHA-1 registered in the Firebase console: run `cd app_flutter/android && ./gradlew signingReport | grep SHA1` and add it under Project settings → Android app → SHA certificate fingerprints, then re-download `google-services.json`.

- [ ] **Step 4: Initialize Firebase in main**

Replace `app_flutter/lib/main.dart`:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: _Root()));
}

class _Root extends ConsumerWidget {
  const _Root();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MyApp(router: router, theme: buildLightTheme(), darkTheme: buildDarkTheme());
  }
}
```
(`routerProvider` is written in Task 9; until then keep the Task 2 `_Root`. Do this step after Task 9 if executing strictly in order, or create a temporary `routerProvider` returning the Task 2 router.)

- [ ] **Step 5: Verify Android build**

Run: `cd app_flutter && flutter build apk --debug`
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`. If Gradle reports `PKIX path building failed`, `source scripts/env.sh` (truststore) and retry.

- [ ] **Step 6: Commit**

```bash
git add app_flutter
git commit -m "chore(flutter): Firebase, Google and Facebook sign-in platform config

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Auth and user repositories with fakes

**Files:**
- Create: `app_flutter/lib/data/auth/auth_error.dart`, `auth_repository.dart`, `auth_providers.dart`
- Create: `app_flutter/lib/data/user/user_repository.dart`
- Test: `app_flutter/test/data/auth/auth_error_test.dart`, `app_flutter/test/data/auth/fake_auth_repository_test.dart`, `app_flutter/test/data/user/fake_user_repository_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class AuthUser { final String uid; final String? email; final String? displayName; final String? photoUrl; }
  enum AuthError { cancelled, wrongPassword, userNotFound, emailInUse, weakPassword, network, unknown }
  class AuthException implements Exception { final AuthError error; }
  AuthError mapAuthException(Object e);
  abstract class AuthRepository {
    Stream<AuthUser?> authStateChanges();
    AuthUser? get currentUser;
    Future<AuthUser> signInWithEmail(String email, String password);
    Future<AuthUser> registerWithEmail(String email, String password, String displayName);
    Future<AuthUser> signInWithGoogle();   // throws AuthException(cancelled) on user cancel
    Future<AuthUser> signInWithFacebook();
    Future<void> signOut();
  }
  abstract class UserRepository {
    Stream<UserProfile?> watch(String uid);
    Future<UserProfile> ensureProfile(AuthUser user);   // creates users/{uid} with role null if missing
    Future<void> setRole(String uid, UserRole role);    // also creates photographers/{uid} when photographer
  }
  final authRepositoryProvider = Provider<AuthRepository>;
  final userRepositoryProvider = Provider<UserRepository>;
  final authStateProvider = StreamProvider<AuthUser?>;
  final currentProfileProvider = StreamProvider<UserProfile?>;   // null when signed out
  ```

- [ ] **Step 1: Write failing tests**

`app_flutter/test/data/auth/auth_error_test.dart`:
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/data/auth/auth_error.dart';

void main() {
  test('maps Firebase codes to AuthError', () {
    expect(mapAuthException(FirebaseAuthException(code: 'wrong-password')), AuthError.wrongPassword);
    expect(mapAuthException(FirebaseAuthException(code: 'invalid-credential')), AuthError.wrongPassword);
    expect(mapAuthException(FirebaseAuthException(code: 'user-not-found')), AuthError.userNotFound);
    expect(mapAuthException(FirebaseAuthException(code: 'email-already-in-use')), AuthError.emailInUse);
    expect(mapAuthException(FirebaseAuthException(code: 'weak-password')), AuthError.weakPassword);
    expect(mapAuthException(FirebaseAuthException(code: 'network-request-failed')), AuthError.network);
    expect(mapAuthException(FirebaseAuthException(code: 'something-else')), AuthError.unknown);
    expect(mapAuthException(const AuthException(AuthError.cancelled)), AuthError.cancelled);
    expect(mapAuthException(StateError('x')), AuthError.unknown);
  });
}
```

`app_flutter/test/data/auth/fake_auth_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/data/auth/auth_error.dart';
import 'package:nhiep_anh_gia/data/auth/auth_repository.dart';

void main() {
  test('register then sign in, stream emits user, sign out emits null', () async {
    final repo = FakeAuthRepository();
    final events = <String?>[];
    final sub = repo.authStateChanges().listen((u) => events.add(u?.uid));
    final u = await repo.registerWithEmail('a@b.vn', 'password1', 'Lan');
    expect(u.displayName, 'Lan');
    await repo.signOut();
    final again = await repo.signInWithEmail('a@b.vn', 'password1');
    expect(again.uid, u.uid);
    await repo.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(events, [null, u.uid, null, u.uid, null]);
    await sub.cancel();
  });
  test('wrong password and unknown email throw typed errors', () async {
    final repo = FakeAuthRepository();
    await repo.registerWithEmail('a@b.vn', 'password1', 'Lan');
    await repo.signOut();
    expect(() => repo.signInWithEmail('a@b.vn', 'nope'), throwsA(isA<AuthException>().having((e) => e.error, 'error', AuthError.wrongPassword)));
    expect(() => repo.signInWithEmail('x@b.vn', 'nope'), throwsA(isA<AuthException>().having((e) => e.error, 'error', AuthError.userNotFound)));
  });
  test('google cancel throws cancelled', () async {
    final repo = FakeAuthRepository(cancelSocial: true);
    expect(repo.signInWithGoogle, throwsA(isA<AuthException>().having((e) => e.error, 'error', AuthError.cancelled)));
  });
}
```

`app_flutter/test/data/user/fake_user_repository_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/data/auth/auth_repository.dart';
import 'package:nhiep_anh_gia/data/user/user_profile.dart';
import 'package:nhiep_anh_gia/data/user/user_repository.dart';

void main() {
  test('ensureProfile creates a role-less profile once', () async {
    final repo = FakeUserRepository();
    const user = AuthUser(uid: 'u1', email: 'a@b.vn', displayName: 'Lan');
    final p1 = await repo.ensureProfile(user);
    expect(p1.needsRole, isTrue);
    await repo.setRole('u1', UserRole.photographer);
    final p2 = await repo.ensureProfile(user);
    expect(p2.role, UserRole.photographer, reason: 'existing profile is not overwritten');
    expect(repo.photographerDocs, contains('u1'));
  });
  test('watch emits null for unknown uid then the profile', () async {
    final repo = FakeUserRepository();
    final first = await repo.watch('u9').first;
    expect(first, isNull);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/data`
Expected: FAIL, missing files.

- [ ] **Step 3: Implement auth error mapping**

`app_flutter/lib/data/auth/auth_error.dart`:
```dart
import 'package:firebase_auth/firebase_auth.dart';

enum AuthError { cancelled, wrongPassword, userNotFound, emailInUse, weakPassword, network, unknown }

class AuthException implements Exception {
  const AuthException(this.error);
  final AuthError error;
  @override
  String toString() => 'AuthException($error)';
}

AuthError mapAuthException(Object e) {
  if (e is AuthException) return e.error;
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'wrong-password' || 'invalid-credential' || 'invalid-email' => AuthError.wrongPassword,
      'user-not-found' => AuthError.userNotFound,
      'email-already-in-use' => AuthError.emailInUse,
      'weak-password' => AuthError.weakPassword,
      'network-request-failed' => AuthError.network,
      _ => AuthError.unknown,
    };
  }
  return AuthError.unknown;
}
```

- [ ] **Step 4: Implement auth repository (Firebase + fake)**

`app_flutter/lib/data/auth/auth_repository.dart`:
```dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_error.dart';

class AuthUser {
  const AuthUser({required this.uid, this.email, this.displayName, this.photoUrl});
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
}

abstract class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  AuthUser? get currentUser;
  Future<AuthUser> signInWithEmail(String email, String password);
  Future<AuthUser> registerWithEmail(String email, String password, String displayName);
  Future<AuthUser> signInWithGoogle();
  Future<AuthUser> signInWithFacebook();
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({fb.FirebaseAuth? auth, GoogleSignIn? google, FacebookAuth? facebook})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _google = google ?? GoogleSignIn(),
        _facebook = facebook ?? FacebookAuth.instance;
  final fb.FirebaseAuth _auth;
  final GoogleSignIn _google;
  final FacebookAuth _facebook;

  AuthUser _map(fb.User u) => AuthUser(uid: u.uid, email: u.email, displayName: u.displayName, photoUrl: u.photoURL);

  @override
  Stream<AuthUser?> authStateChanges() => _auth.authStateChanges().map((u) => u == null ? null : _map(u));

  @override
  AuthUser? get currentUser => _auth.currentUser == null ? null : _map(_auth.currentUser!);

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    try {
      final c = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return _map(c.user!);
    } catch (e) {
      throw AuthException(mapAuthException(e));
    }
  }

  @override
  Future<AuthUser> registerWithEmail(String email, String password, String displayName) async {
    try {
      final c = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await c.user!.updateDisplayName(displayName);
      return _map(c.user!).copyWithName(displayName);
    } catch (e) {
      throw AuthException(mapAuthException(e));
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) throw const AuthException(AuthError.cancelled);
    try {
      final g = await account.authentication;
      final cred = fb.GoogleAuthProvider.credential(idToken: g.idToken, accessToken: g.accessToken);
      final c = await _auth.signInWithCredential(cred);
      return _map(c.user!);
    } catch (e) {
      throw AuthException(mapAuthException(e));
    }
  }

  @override
  Future<AuthUser> signInWithFacebook() async {
    final result = await _facebook.login(permissions: const ['email', 'public_profile']);
    if (result.status == LoginStatus.cancelled) throw const AuthException(AuthError.cancelled);
    if (result.status != LoginStatus.success || result.accessToken == null) throw const AuthException(AuthError.unknown);
    try {
      final cred = fb.FacebookAuthProvider.credential(result.accessToken!.tokenString);
      final c = await _auth.signInWithCredential(cred);
      return _map(c.user!);
    } catch (e) {
      throw AuthException(mapAuthException(e));
    }
  }

  @override
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _google.signOut(), _facebook.logOut()]);
  }
}

extension on AuthUser {
  AuthUser copyWithName(String name) => AuthUser(uid: uid, email: email, displayName: name, photoUrl: photoUrl);
}

/// In-memory implementation for tests and widget previews.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.cancelSocial = false});
  final bool cancelSocial;
  final _users = <String, ({String password, AuthUser user})>{};
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;
  int _seq = 0;

  void _emit(AuthUser? u) {
    _current = u;
    _controller.add(u);
  }

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    final rec = _users[email];
    if (rec == null) throw const AuthException(AuthError.userNotFound);
    if (rec.password != password) throw const AuthException(AuthError.wrongPassword);
    _emit(rec.user);
    return rec.user;
  }

  @override
  Future<AuthUser> registerWithEmail(String email, String password, String displayName) async {
    if (_users.containsKey(email)) throw const AuthException(AuthError.emailInUse);
    if (password.length < 8) throw const AuthException(AuthError.weakPassword);
    final user = AuthUser(uid: 'fake-${++_seq}', email: email, displayName: displayName);
    _users[email] = (password: password, user: user);
    _emit(user);
    return user;
  }

  Future<AuthUser> _social(String provider) async {
    if (cancelSocial) throw const AuthException(AuthError.cancelled);
    final user = AuthUser(uid: '$provider-${++_seq}', email: '$provider@example.com', displayName: 'Người dùng $provider');
    _emit(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithGoogle() => _social('google');
  @override
  Future<AuthUser> signInWithFacebook() => _social('facebook');

  @override
  Future<void> signOut() async => _emit(null);
}
```

- [ ] **Step 5: Implement user repository (Firestore + fake)**

`app_flutter/lib/data/user/user_repository.dart`:
```dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_repository.dart';
import 'user_profile.dart';

abstract class UserRepository {
  Stream<UserProfile?> watch(String uid);
  Future<UserProfile> ensureProfile(AuthUser user);
  Future<void> setRole(String uid, UserRole role);
}

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('users').doc(uid);

  @override
  Stream<UserProfile?> watch(String uid) =>
      _doc(uid).snapshots().map((s) => s.data() == null ? null : UserProfile.fromJson({...s.data()!, 'uid': uid}));

  @override
  Future<UserProfile> ensureProfile(AuthUser user) async {
    final snap = await _doc(user.uid).get();
    if (snap.exists) return UserProfile.fromJson({...snap.data()!, 'uid': user.uid});
    final profile = UserProfile(
      uid: user.uid,
      displayName: user.displayName ?? user.email?.split('@').first ?? 'Người dùng',
      avatarUrl: user.photoUrl,
      email: user.email,
    );
    await _doc(user.uid).set({
      ...profile.toJson()..remove('uid'),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return profile;
  }

  @override
  Future<void> setRole(String uid, UserRole role) async {
    final batch = _db.batch();
    batch.update(_doc(uid), {'role': role.name, 'updatedAt': FieldValue.serverTimestamp()});
    if (role == UserRole.photographer) {
      batch.set(_db.collection('photographers').doc(uid), {
        'onboardingComplete': false,
        'verified': false,
        'specialties': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }
}

class FakeUserRepository implements UserRepository {
  final _profiles = <String, UserProfile>{};
  final photographerDocs = <String>{};
  final _controllers = <String, StreamController<UserProfile?>>{};

  StreamController<UserProfile?> _c(String uid) =>
      _controllers.putIfAbsent(uid, () => StreamController<UserProfile?>.broadcast());

  @override
  Stream<UserProfile?> watch(String uid) async* {
    yield _profiles[uid];
    yield* _c(uid).stream;
  }

  @override
  Future<UserProfile> ensureProfile(AuthUser user) async {
    final existing = _profiles[user.uid];
    if (existing != null) return existing;
    final p = UserProfile(uid: user.uid, displayName: user.displayName ?? 'Người dùng', email: user.email, avatarUrl: user.photoUrl);
    _profiles[user.uid] = p;
    _c(user.uid).add(p);
    return p;
  }

  @override
  Future<void> setRole(String uid, UserRole role) async {
    final p = _profiles[uid]!.copyWith(role: role);
    _profiles[uid] = p;
    if (role == UserRole.photographer) photographerDocs.add(uid);
    _c(uid).add(p);
  }
}
```

- [ ] **Step 6: Providers**

`app_flutter/lib/data/auth/auth_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../user/user_profile.dart';
import '../user/user_repository.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => FirebaseAuthRepository());
final userRepositoryProvider = Provider<UserRepository>((ref) => FirestoreUserRepository());

final authStateProvider = StreamProvider<AuthUser?>((ref) => ref.watch(authRepositoryProvider).authStateChanges());

/// Profile of the signed-in user; ensures the users/{uid} doc exists on first sign-in.
final currentProfileProvider = StreamProvider<UserProfile?>((ref) async* {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    yield null;
    return;
  }
  final repo = ref.watch(userRepositoryProvider);
  await repo.ensureProfile(user);
  yield* repo.watch(user.uid);
});
```

- [ ] **Step 7: Run tests, commit**

Run: `flutter test test/data && flutter analyze`
Expected: PASS (6 tests).

```bash
git add app_flutter
git commit -m "feat(flutter): auth and user repositories with Firebase and fake implementations

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: Login and Register screens

**Files:**
- Create: `app_flutter/lib/features/auth/auth_controller.dart`, `login_screen.dart`, `register_screen.dart`, `auth_form_validators.dart`
- Test: `app_flutter/test/features/auth/auth_form_validators_test.dart`, `login_screen_test.dart`

**Interfaces:**
- Produces: `class AuthController extends AsyncNotifier<void>` with `signInEmail(email, password)`, `register(email, password, name)`, `google()`, `facebook()`; `authControllerProvider`; `String? validateEmail(String?, AppLocalizations)`, `validatePassword`, `validateConfirm(String? v, String other, AppLocalizations)`, `validateName`; `LoginScreen`, `RegisterScreen` routed at `/login`, `/register`.

- [ ] **Step 1: Failing tests**

`app_flutter/test/features/auth/auth_form_validators_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:nhiep_anh_gia/features/auth/auth_form_validators.dart';

void main() {
  late AppLocalizations l;
  setUpAll(() async => l = await AppLocalizations.delegate.load(const Locale('vi')));
  test('email', () {
    expect(validateEmail('', l), l.errorEmailInvalid);
    expect(validateEmail('abc', l), l.errorEmailInvalid);
    expect(validateEmail('a@b.vn', l), isNull);
  });
  test('password and confirm', () {
    expect(validatePassword('1234567', l), l.errorPasswordShort);
    expect(validatePassword('12345678', l), isNull);
    expect(validateConfirm('x', 'y', l), l.errorPasswordMismatch);
    expect(validateConfirm('y', 'y', l), isNull);
  });
  test('name', () {
    expect(validateName('  ', l), l.errorNameEmpty);
    expect(validateName('Lan', l), isNull);
  });
}
```
(add `import 'package:flutter/widgets.dart';` for `Locale`.)

`app_flutter/test/features/auth/login_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/data/auth/auth_providers.dart';
import 'package:nhiep_anh_gia/data/auth/auth_repository.dart';
import 'package:nhiep_anh_gia/features/auth/login_screen.dart';

Widget _wrap(Widget child, AuthRepository repo) => ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        locale: Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ).copyWithHome(child),
    );

extension on MaterialApp {
  MaterialApp copyWithHome(Widget home) => MaterialApp(
        locale: locale,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
        home: home,
      );
}

void main() {
  testWidgets('wrong password shows the specific Vietnamese message', (tester) async {
    final repo = FakeAuthRepository();
    await repo.registerWithEmail('a@b.vn', 'password1', 'Lan');
    await repo.signOut();
    await tester.pumpWidget(_wrap(const LoginScreen(), repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('email')), 'a@b.vn');
    await tester.enterText(find.byKey(const Key('password')), 'wrongpass');
    await tester.tap(find.byKey(const Key('login')));
    await tester.pumpAndSettle();
    expect(find.text('Email hoặc mật khẩu không đúng.'), findsOneWidget);
  });
  testWidgets('cancelled Google sign-in shows no error and re-enables buttons', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen(), FakeAuthRepository(cancelSocial: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('google')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    final btn = tester.widget<FilledButton>(find.byKey(const Key('login')));
    expect(btn.onPressed, isNotNull);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/auth`
Expected: FAIL, missing files.

- [ ] **Step 3: Validators**

`app_flutter/lib/features/auth/auth_form_validators.dart`:
```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? v, AppLocalizations l) => (v == null || !_email.hasMatch(v.trim())) ? l.errorEmailInvalid : null;
String? validatePassword(String? v, AppLocalizations l) => (v == null || v.length < 8) ? l.errorPasswordShort : null;
String? validateConfirm(String? v, String other, AppLocalizations l) => v != other ? l.errorPasswordMismatch : null;
String? validateName(String? v, AppLocalizations l) => (v == null || v.trim().isEmpty) ? l.errorNameEmpty : null;
```

- [ ] **Step 4: Controller**

`app_flutter/lib/features/auth/auth_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth/auth_error.dart';
import '../../data/auth/auth_providers.dart';

/// State is the last [AuthError] to show, or null. Loading while an action runs.
class AuthController extends AsyncNotifier<AuthError?> {
  @override
  Future<AuthError?> build() async => null;

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
    } on AuthException catch (e) {
      // A cancelled social login is not an error the user needs to read.
      state = AsyncData(e.error == AuthError.cancelled ? null : e.error);
    } catch (_) {
      state = const AsyncData(AuthError.unknown);
    }
  }

  Future<void> signInEmail(String email, String password) =>
      _run(() => ref.read(authRepositoryProvider).signInWithEmail(email.trim(), password));
  Future<void> register(String email, String password, String name) =>
      _run(() => ref.read(authRepositoryProvider).registerWithEmail(email.trim(), password, name.trim()));
  Future<void> google() => _run(() => ref.read(authRepositoryProvider).signInWithGoogle());
  Future<void> facebook() => _run(() => ref.read(authRepositoryProvider).signInWithFacebook());
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthError?>(AuthController.new);

String authErrorMessage(AuthError e, dynamic l) => switch (e) {
      AuthError.wrongPassword => l.authErrorWrongPassword as String,
      AuthError.userNotFound => l.authErrorUserNotFound as String,
      AuthError.emailInUse => l.authErrorEmailInUse as String,
      AuthError.weakPassword => l.authErrorWeakPassword as String,
      AuthError.network => l.authErrorNetwork as String,
      AuthError.cancelled || AuthError.unknown => l.authErrorUnknown as String,
    };
```
(Use `AppLocalizations` as the parameter type instead of `dynamic`; the `dynamic` above is only to keep the snippet short — write `AppLocalizations l` and drop the casts.)

- [ ] **Step 5: Login screen**

`app_flutter/lib/features/auth/login_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme/tokens.g.dart';
import '../../core/widgets/app_button.dart';
import 'auth_controller.dart';
import 'auth_form_validators.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(authControllerProvider);
    final loading = state.isLoading;
    ref.listen(authControllerProvider, (_, next) {
      final err = next.value;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(err, l))));
      }
    });
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpace.s10),
                Text(l.appName, style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: AppSpace.s8),
                TextFormField(
                  key: const Key('email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(labelText: l.emailLabel),
                  validator: (v) => validateEmail(v, l),
                ),
                const SizedBox(height: AppSpace.s3),
                TextFormField(
                  key: const Key('password'),
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(labelText: l.passwordLabel),
                  validator: (v) => validatePassword(v, l),
                ),
                const SizedBox(height: AppSpace.s5),
                AppButton.primary(
                  l.loginButton,
                  key: const Key('login'),
                  loading: loading,
                  onPressed: () {
                    if (_form.currentState!.validate()) {
                      ref.read(authControllerProvider.notifier).signInEmail(_email.text, _password.text);
                    }
                  },
                ),
                const SizedBox(height: AppSpace.s3),
                AppButton.outline(l.continueWithGoogle, key: const Key('google'), loading: loading,
                    onPressed: () => ref.read(authControllerProvider.notifier).google()),
                const SizedBox(height: AppSpace.s2),
                AppButton.outline(l.continueWithFacebook, key: const Key('facebook'), loading: loading,
                    onPressed: () => ref.read(authControllerProvider.notifier).facebook()),
                const SizedBox(height: AppSpace.s4),
                AppButton.text(l.noAccountRegister, onPressed: () => context.push('/register')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```
Note: `AppButton` constructors must accept `key` (they do, via `super.key`). Because `AppButton.primary` wraps a `FilledButton`, the test's `find.byKey(Key('login'))` finds the `AppButton`; change the test's last assertion to `tester.widget<AppButton>(find.byKey(const Key('login'))).loading == false` and keep `expect(find.byType(SnackBar), findsNothing)`.

- [ ] **Step 6: Register screen**

`app_flutter/lib/features/auth/register_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme/tokens.g.dart';
import '../../core/widgets/app_button.dart';
import 'auth_controller.dart';
import 'auth_form_validators.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final loading = ref.watch(authControllerProvider).isLoading;
    ref.listen(authControllerProvider, (_, next) {
      final err = next.value;
      if (err != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(err, l))));
    });
    return Scaffold(
      appBar: AppBar(title: Text(l.registerTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(key: const Key('name'), controller: _name, decoration: InputDecoration(labelText: l.displayNameLabel), validator: (v) => validateName(v, l)),
                const SizedBox(height: AppSpace.s3),
                TextFormField(key: const Key('email'), controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: l.emailLabel), validator: (v) => validateEmail(v, l)),
                const SizedBox(height: AppSpace.s3),
                TextFormField(key: const Key('password'), controller: _password, obscureText: true, decoration: InputDecoration(labelText: l.passwordLabel), validator: (v) => validatePassword(v, l)),
                const SizedBox(height: AppSpace.s3),
                TextFormField(key: const Key('confirm'), controller: _confirm, obscureText: true, decoration: InputDecoration(labelText: l.passwordConfirmLabel), validator: (v) => validateConfirm(v, _password.text, l)),
                const SizedBox(height: AppSpace.s5),
                AppButton.primary(l.registerButton, key: const Key('register'), loading: loading, onPressed: () {
                  if (_form.currentState!.validate()) {
                    ref.read(authControllerProvider.notifier).register(_email.text, _password.text, _name.text);
                  }
                }),
                const SizedBox(height: AppSpace.s3),
                AppButton.text(l.haveAccountLogin, onPressed: () => context.pop()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Run tests, commit**

Run: `flutter test test/features/auth && flutter analyze`
Expected: PASS (5 tests).

```bash
git add app_flutter
git commit -m "feat(flutter): login and register screens with typed auth errors

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: Router with auth and role redirects, onboarding role screen

**Files:**
- Create: `app_flutter/lib/app/router.dart`, `app_flutter/lib/features/onboarding/role_screen.dart`, `app_flutter/lib/features/onboarding/role_controller.dart`
- Create: `app_flutter/lib/features/shell/tab_shell.dart`, `app_flutter/lib/features/shell/placeholder_tabs.dart` (minimal here; finished in Task 10)
- Test: `app_flutter/test/app/router_test.dart`, `app_flutter/test/features/onboarding/role_screen_test.dart`

**Interfaces:**
- Produces: `final routerProvider = Provider<GoRouter>`; `String? computeRedirect({required bool signedIn, required bool profileLoaded, required bool needsRole, required String location})` (pure, unit-tested); `RoleScreen` at `/onboarding/role`; `TabShell(navigationShell)`; placeholder tab widgets `HomeTab, ExploreTab, ActionTab, BookingsTab, ProfileTab`.

- [ ] **Step 1: Failing tests**

`app_flutter/test/app/router_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/app/router.dart';

void main() {
  test('signed out users go to /login except on auth routes', () {
    expect(computeRedirect(signedIn: false, profileLoaded: true, needsRole: false, location: '/home'), '/login');
    expect(computeRedirect(signedIn: false, profileLoaded: true, needsRole: false, location: '/login'), isNull);
    expect(computeRedirect(signedIn: false, profileLoaded: true, needsRole: false, location: '/register'), isNull);
  });
  test('signed in without role goes to onboarding', () {
    expect(computeRedirect(signedIn: true, profileLoaded: true, needsRole: true, location: '/home'), '/onboarding/role');
    expect(computeRedirect(signedIn: true, profileLoaded: true, needsRole: true, location: '/onboarding/role'), isNull);
  });
  test('signed in with role leaves auth and onboarding routes', () {
    expect(computeRedirect(signedIn: true, profileLoaded: true, needsRole: false, location: '/login'), '/home');
    expect(computeRedirect(signedIn: true, profileLoaded: true, needsRole: false, location: '/onboarding/role'), '/home');
    expect(computeRedirect(signedIn: true, profileLoaded: true, needsRole: false, location: '/bookings'), isNull);
  });
  test('while the profile is loading nothing redirects', () {
    expect(computeRedirect(signedIn: true, profileLoaded: false, needsRole: false, location: '/home'), isNull);
  });
}
```

`app_flutter/test/features/onboarding/role_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/data/auth/auth_providers.dart';
import 'package:nhiep_anh_gia/data/auth/auth_repository.dart';
import 'package:nhiep_anh_gia/data/user/user_profile.dart';
import 'package:nhiep_anh_gia/data/user/user_repository.dart';
import 'package:nhiep_anh_gia/features/onboarding/role_screen.dart';

void main() {
  testWidgets('choosing photographer sets the role and creates photographer doc', (tester) async {
    final auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
    await users.ensureProfile(u);
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth), userRepositoryProvider.overrideWithValue(users)],
      child: const MaterialApp(
        locale: Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RoleScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role-photographer')));
    await tester.tap(find.byKey(const Key('role-continue')));
    await tester.pumpAndSettle();
    final p = await users.watch(u.uid).first;
    expect(p!.role, UserRole.photographer);
    expect(users.photographerDocs, contains(u.uid));
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/app/router_test.dart test/features/onboarding`
Expected: FAIL, missing files.

- [ ] **Step 3: Router**

`app_flutter/lib/app/router.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/onboarding/role_screen.dart';
import '../features/shell/placeholder_tabs.dart';
import '../features/shell/tab_shell.dart';
import 'tabs.dart';

const _authRoutes = {'/login', '/register'};
const _onboardingRoute = '/onboarding/role';

/// Pure redirect rule; see router_test.dart.
String? computeRedirect({
  required bool signedIn,
  required bool profileLoaded,
  required bool needsRole,
  required String location,
}) {
  final onAuth = _authRoutes.contains(location);
  if (!signedIn) return onAuth ? null : '/login';
  if (!profileLoaded) return null;
  if (needsRole) return location == _onboardingRoute ? null : _onboardingRoute;
  if (onAuth || location == _onboardingRoute) return AppTab.home.path;
  return null;
}

/// Rebuilds GoRouter's redirect when auth or profile changes.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(currentProfileProvider, (_, __) => notifyListeners());
  }
  final Ref ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final auth = ref.read(authStateProvider);
    final profile = ref.read(currentProfileProvider);
    final signedIn = auth.valueOrNull != null;
    final profileLoaded = !signedIn || (profile.hasValue && profile.value != null);
    return computeRedirect(
      signedIn: signedIn,
      profileLoaded: profileLoaded,
      needsRole: profile.valueOrNull?.needsRole ?? false,
      location: state.matchedLocation,
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);
  return GoRouter(
    initialLocation: AppTab.home.path,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: _onboardingRoute, builder: (_, __) => const RoleScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => TabShell(shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: AppTab.home.path, builder: (_, __) => const HomeTab())]),
          StatefulShellBranch(routes: [GoRoute(path: AppTab.explore.path, builder: (_, __) => const ExploreTab())]),
          StatefulShellBranch(routes: [GoRoute(path: AppTab.action.path, builder: (_, __) => const ActionTab())]),
          StatefulShellBranch(routes: [GoRoute(path: AppTab.bookings.path, builder: (_, __) => const BookingsTab())]),
          StatefulShellBranch(routes: [GoRoute(path: AppTab.profile.path, builder: (_, __) => const ProfileTab())]),
        ],
      ),
    ],
  );
});
```

- [ ] **Step 4: Role screen and controller**

`app_flutter/lib/features/onboarding/role_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth/auth_providers.dart';
import '../../data/user/user_profile.dart';

class RoleController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> choose(UserRole role) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(userRepositoryProvider).setRole(uid, role));
  }
}

final roleControllerProvider = AsyncNotifierProvider<RoleController, void>(RoleController.new);
```

`app_flutter/lib/features/onboarding/role_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme/tokens.g.dart';
import '../../core/widgets/app_button.dart';
import '../../data/user/user_profile.dart';
import 'role_controller.dart';

class RoleScreen extends ConsumerStatefulWidget {
  const RoleScreen({super.key});
  @override
  ConsumerState<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends ConsumerState<RoleScreen> {
  UserRole _selected = UserRole.customer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final loading = ref.watch(roleControllerProvider).isLoading;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpace.s8),
              Text(l.roleTitle, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpace.s6),
              _RoleCard(
                key: const Key('role-customer'),
                title: l.roleCustomerTitle,
                body: l.roleCustomerBody,
                icon: Icons.search,
                selected: _selected == UserRole.customer,
                onTap: () => setState(() => _selected = UserRole.customer),
              ),
              const SizedBox(height: AppSpace.s3),
              _RoleCard(
                key: const Key('role-photographer'),
                title: l.rolePhotographerTitle,
                body: l.rolePhotographerBody,
                icon: Icons.camera_alt_outlined,
                selected: _selected == UserRole.photographer,
                onTap: () => setState(() => _selected = UserRole.photographer),
              ),
              const Spacer(),
              AppButton.primary(
                l.roleContinue,
                key: const Key('role-continue'),
                loading: loading,
                onPressed: () => ref.read(roleControllerProvider.notifier).choose(_selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({super.key, required this.title, required this.body, required this.icon, required this.selected, required this.onTap});
  final String title;
  final String body;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.s4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySubtle : scheme.surface,
          border: Border.all(color: selected ? scheme.primary : scheme.outline, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: AppSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(body, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Minimal shell and placeholder tabs (completed in Task 10)**

`app_flutter/lib/features/shell/tab_shell.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/tabs.dart';
import '../../core/l10n_ext.dart';
import '../../data/auth/auth_providers.dart';
import '../../data/user/user_profile.dart';

class TabShell extends ConsumerWidget {
  const TabShell(this.shell, {super.key});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentProfileProvider).valueOrNull?.role ?? UserRole.customer;
    final specs = tabsFor(role);
    final l = context.l10n;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          for (final s in specs)
            NavigationDestination(
              icon: s.emphasized
                  ? CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary, child: Icon(s.icon))
                  : Icon(s.icon),
              label: s.label(l),
            ),
        ],
      ),
    );
  }
}
```

`app_flutter/lib/features/shell/placeholder_tabs.dart` (temporary bodies; Task 10 replaces with empty states):
```dart
import 'package:flutter/material.dart';

class HomeTab extends StatelessWidget { const HomeTab({super.key}); @override Widget build(BuildContext c) => const SizedBox(); }
class ExploreTab extends StatelessWidget { const ExploreTab({super.key}); @override Widget build(BuildContext c) => const SizedBox(); }
class ActionTab extends StatelessWidget { const ActionTab({super.key}); @override Widget build(BuildContext c) => const SizedBox(); }
class BookingsTab extends StatelessWidget { const BookingsTab({super.key}); @override Widget build(BuildContext c) => const SizedBox(); }
class ProfileTab extends StatelessWidget { const ProfileTab({super.key}); @override Widget build(BuildContext c) => const SizedBox(); }
```

- [ ] **Step 6: Run tests, commit**

Run: `flutter test test/app test/features/onboarding && flutter analyze`
Expected: PASS (7 tests).

```bash
git add app_flutter
git commit -m "feat(flutter): router with auth/role redirects, onboarding role screen, tab shell

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: Role-aware empty-state tabs and profile sign-out

**Files:**
- Modify: `app_flutter/lib/features/shell/placeholder_tabs.dart`
- Test: `app_flutter/test/features/shell/placeholder_tabs_test.dart`

**Interfaces:**
- Consumes: `EmptyState`, `currentProfileProvider`, `authRepositoryProvider`, `tabsFor`.
- Produces: tabs render the role's empty state; `ProfileTab` shows display name, role label and a sign-out button with `Key('sign-out')`.

- [ ] **Step 1: Failing test**

`app_flutter/test/features/shell/placeholder_tabs_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nhiep_anh_gia/data/auth/auth_providers.dart';
import 'package:nhiep_anh_gia/data/auth/auth_repository.dart';
import 'package:nhiep_anh_gia/data/user/user_profile.dart';
import 'package:nhiep_anh_gia/data/user/user_repository.dart';
import 'package:nhiep_anh_gia/features/shell/placeholder_tabs.dart';

Future<(FakeAuthRepository, FakeUserRepository)> _signedIn(UserRole role) async {
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
  await users.ensureProfile(u);
  await users.setRole(u.uid, role);
  return (auth, users);
}

Widget _app(Widget home, FakeAuthRepository auth, FakeUserRepository users) => ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth), userRepositoryProvider.overrideWithValue(users)],
      child: MaterialApp(
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
  testWidgets('bookings tab shows work empty state for photographers', (tester) async {
    final (auth, users) = await _signedIn(UserRole.photographer);
    await tester.pumpWidget(_app(const BookingsTab(), auth, users));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có yêu cầu nào'), findsOneWidget);
  });
  testWidgets('bookings tab shows customer empty state for customers', (tester) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(_app(const BookingsTab(), auth, users));
    await tester.pumpAndSettle();
    expect(find.text('Buổi chụp tiếp theo bắt đầu từ đây'), findsOneWidget);
  });
  testWidgets('profile tab signs out', (tester) async {
    final (auth, users) = await _signedIn(UserRole.customer);
    await tester.pumpWidget(_app(const ProfileTab(), auth, users));
    await tester.pumpAndSettle();
    expect(find.text('Minh'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    expect(auth.currentUser, isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/shell`
Expected: FAIL, texts not found.

- [ ] **Step 3: Implement the tabs**

Replace `app_flutter/lib/features/shell/placeholder_tabs.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n_ext.dart';
import '../../core/theme/tokens.g.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/auth/auth_providers.dart';
import '../../data/user/user_profile.dart';

UserRole _role(WidgetRef ref) => ref.watch(currentProfileProvider).valueOrNull?.role ?? UserRole.customer;

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(appBar: AppBar(title: Text(l.tabHome)), body: EmptyState(title: l.emptyHomeTitle, body: l.emptyHomeBody));
  }
}

class ExploreTab extends ConsumerWidget {
  const ExploreTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Scaffold(appBar: AppBar(title: Text(l.tabExplore)), body: EmptyState(title: l.emptyExploreTitle, body: l.emptyExploreBody));
  }
}

class ActionTab extends ConsumerWidget {
  const ActionTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final photographer = _role(ref) == UserRole.photographer;
    return Scaffold(
      appBar: AppBar(title: Text(photographer ? l.tabCreate : l.tabFind)),
      body: EmptyState(
        title: photographer ? l.emptyCreateTitle : l.emptyFindTitle,
        body: photographer ? l.emptyCreateBody : l.emptyFindBody,
      ),
    );
  }
}

class BookingsTab extends ConsumerWidget {
  const BookingsTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final photographer = _role(ref) == UserRole.photographer;
    return Scaffold(
      appBar: AppBar(title: Text(photographer ? l.tabWork : l.tabBookings)),
      body: EmptyState(
        title: photographer ? l.emptyWorkTitle : l.emptyBookingsTitle,
        body: photographer ? l.emptyWorkBody : l.emptyBookingsBody,
      ),
    );
  }
}

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final roleLabel = profile?.role == UserRole.photographer ? l.profileRolePhotographer : l.profileRoleCustomer;
    return Scaffold(
      appBar: AppBar(title: Text(l.tabProfile)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpace.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleAvatar(radius: 32, backgroundImage: profile?.avatarUrl == null ? null : NetworkImage(profile!.avatarUrl!)),
            const SizedBox(height: AppSpace.s3),
            Text(profile?.displayName ?? '', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
            Text(roleLabel, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            const Spacer(),
            AppButton.outline(l.signOut, key: const Key('sign-out'), onPressed: () => ref.read(authRepositoryProvider).signOut()),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run all tests, run the app**

Add to `placeholder_tabs_test.dart` a size sweep so the empty states never overflow:
```dart
  for (final size in const [Size(320, 640), Size(430, 932)]) {
    testWidgets('bookings tab fits $size at text scale 1.3', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (auth, users) = await _signedIn(UserRole.customer);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: _app(const BookingsTab(), auth, users),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
```

Run: `flutter test && flutter analyze`
Expected: all tests pass.
Run: `flutter run -d <device>` (or `flutter build apk --debug`) and manually: register → role screen → pick Nhận chụp → five tabs with Vietnamese labels, middle tab reads "Đăng bài", bookings tab reads "Công việc"; Hồ sơ → Đăng xuất → login screen.

- [ ] **Step 5: Commit**

```bash
git add app_flutter
git commit -m "feat(flutter): role-aware empty-state tabs and profile sign-out

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 11: Firestore security rules with emulator tests

**Files:**
- Create: `app_flutter/firebase/firebase.json`, `firestore.rules`, `firestore.indexes.json`
- Create: `app_flutter/firebase/rules-test/package.json`, `rules.test.mjs`

**Interfaces:**
- Produces: rules allowing `users/{uid}` and `photographers/{uid}` writes only by owner with `role in ['customer','photographer']`; public read of `users` and `photographers`; `bookings` read by participants only, no client writes.

- [ ] **Step 1: Failing rules tests**

`app_flutter/firebase/rules-test/package.json`:
```json
{
  "name": "rules-test",
  "private": true,
  "type": "module",
  "scripts": { "test": "firebase emulators:exec --only firestore --project demo-nag 'node --test rules.test.mjs'" },
  "devDependencies": { "@firebase/rules-unit-testing": "^4.0.0", "firebase-tools": "^13.0.0", "firebase": "^10.0.0" }
}
```

`app_flutter/firebase/rules-test/rules.test.mjs`:
```js
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc } from 'firebase/firestore';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nag',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(async () => env.cleanup());

test('user can create and update own profile with a valid role', async () => {
  const db = env.authenticatedContext('u1').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/u1'), { displayName: 'Lan', role: null }));
  await assertSucceeds(updateDoc(doc(db, 'users/u1'), { role: 'photographer' }));
});
test('user cannot write another user or an invalid role', async () => {
  const db = env.authenticatedContext('u1').firestore();
  await assertFails(setDoc(doc(db, 'users/u2'), { displayName: 'X' }));
  await assertFails(setDoc(doc(db, 'users/u1'), { displayName: 'Lan', role: 'admin' }));
});
test('anyone signed in can read profiles; anonymous cannot', async () => {
  await env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), 'users/u9'), { displayName: 'P' }));
  await assertSucceeds(getDoc(doc(env.authenticatedContext('u1').firestore(), 'users/u9')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/u9')));
});
test('photographer doc only by owner; bookings are read-only for clients', async () => {
  const db = env.authenticatedContext('u1').firestore();
  await assertSucceeds(setDoc(doc(db, 'photographers/u1'), { onboardingComplete: false }));
  await assertFails(setDoc(doc(db, 'photographers/u2'), { onboardingComplete: false }));
  await assertFails(setDoc(doc(db, 'bookings/b1'), { customerId: 'u1', status: 'requested' }));
  await env.withSecurityRulesDisabled(async (c) => setDoc(doc(c.firestore(), 'bookings/b2'), { customerId: 'u1', photographerId: 'u2', status: 'requested' }));
  await assertSucceeds(getDoc(doc(db, 'bookings/b2')));
  await assertFails(getDoc(doc(env.authenticatedContext('u3').firestore(), 'bookings/b2')));
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd app_flutter/firebase/rules-test && npm install && npm test`
Expected: FAIL (rules file missing → emulator refuses to start, or all writes denied).

- [ ] **Step 3: Write rules and emulator config**

`app_flutter/firebase/firebase.json`:
```json
{
  "firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" },
  "emulators": { "firestore": { "port": 8080 }, "auth": { "port": 9099 }, "ui": { "enabled": false } }
}
```
`app_flutter/firebase/firestore.indexes.json`: `{ "indexes": [], "fieldOverrides": [] }`

`app_flutter/firebase/firestore.rules`:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function signedIn() { return request.auth != null; }
    function isOwner(uid) { return signedIn() && request.auth.uid == uid; }
    function validRole() {
      return !('role' in request.resource.data)
        || request.resource.data.role == null
        || request.resource.data.role in ['customer', 'photographer'];
    }

    match /users/{uid} {
      allow read: if signedIn();
      allow create, update: if isOwner(uid) && validRole();
      allow delete: if false;
    }

    match /photographers/{uid} {
      allow read: if signedIn();
      allow create, update: if isOwner(uid) && !('verified' in request.resource.data.diff(resource == null ? {} : resource.data).affectedKeys());
      allow delete: if false;
      match /services/{serviceId} {
        allow read: if signedIn();
        allow write: if isOwner(uid);
      }
    }

    match /bookings/{bookingId} {
      allow read: if signedIn() && (resource.data.customerId == request.auth.uid || resource.data.photographerId == request.auth.uid);
      allow write: if false;   // only Cloud Functions (sub-project 4)
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

- [ ] **Step 4: Run rules tests**

Run: `npm test`
Expected: 4 passing. (Requires Java for the emulator: `source scripts/env.sh` first.)

- [ ] **Step 5: Commit**

```bash
git add app_flutter/firebase
git commit -m "feat(firebase): Firestore rules for users, photographers and bookings with emulator tests

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```
Add `app_flutter/firebase/rules-test/node_modules` to `.gitignore` before committing.

---

### Task 12: CI and developer docs

**Files:**
- Create: `.github/workflows/flutter.yml`
- Create: `app_flutter/README.md`
- Modify: `README.md` (Flutter section: setup commands)

- [ ] **Step 1: Workflow**

`.github/workflows/flutter.yml`:
```yaml
name: flutter
on:
  push: { branches: [flutter-rewrite, develop, main] }
  pull_request: { paths: ['app_flutter/**', '.github/workflows/flutter.yml'] }
jobs:
  test:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: app_flutter } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - uses: subosito/flutter-action@v2
        with: { channel: stable, cache: true }
      - run: flutter pub get
      - run: dart run tool/gen_tokens.dart
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter gen-l10n
      - run: flutter analyze
      - run: flutter test
      - name: Firestore rules tests
        working-directory: app_flutter/firebase/rules-test
        run: npm ci && npm test
      - name: Android debug build (no Firebase secrets in CI)
        if: ${{ false }}
        run: flutter build apk --debug
```
The Android build step stays disabled until `google-services.json` is provided via a repository secret (write it from `${{ secrets.GOOGLE_SERVICES_JSON }}` in a later sub-project).

- [ ] **Step 2: app_flutter/README.md**

```markdown
# app_flutter

Flutter client for "Cộng đồng nhiếp ảnh gia". Spec: `../docs/superpowers/specs/2026-09-30-photography-marketplace-design.md`.

## Setup (no admin rights)
    scripts/install-flutter.sh      # once
    scripts/install-sdk.sh          # once, Android SDK
    scripts/fetch-fonts.sh          # once
    source scripts/env.sh
    cd app_flutter && flutter pub get
    dart run tool/gen_tokens.dart && dart run build_runner build --delete-conflicting-outputs && flutter gen-l10n
    cp ../app/google-services.json android/app/   # Firebase Android config (not committed)
    flutter run

## Layout
lib/app (router, tabs, theme wiring) · lib/core (theme from design tokens, shared widgets) · lib/data (models + repositories, Firebase and fakes) · lib/features (one folder per screen/flow) · firebase/ (rules + emulator tests) · tool/ (code generators).

## Rules
- Riverpod controllers only; widgets never call repositories.
- Strings in lib/l10n/app_vi.arb. Colors/spacing from lib/core/theme/tokens.g.dart (regenerate after editing design-system/tokens.json).
- Every screen ships with an empty state and a widget test using the Fake repositories.
```

- [ ] **Step 3: Root README**

Under the "Viết lại bằng Flutter" section add: "Bắt đầu: xem `app_flutter/README.md`. CI: `.github/workflows/flutter.yml` chạy analyze, test và rules test."

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/flutter.yml app_flutter/README.md README.md
git commit -m "ci(flutter): analyze, test and rules tests on push; developer README

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Self-review notes

- Spec coverage for sub-project 1 (row 1 of §12): project (T1), theme from tokens (T3), router 5 tab by role (T5, T9, T10), Firebase init (T6), Auth email/Google/Facebook (T7, T8), onboarding role (T9), rules (T11), CI (T12). Empty states per role (T10). Vietnamese-only strings (T2 ARB).
- Review Focus 1 → T7 `ensureProfile` test + T9 `needsRole` redirect test. 2 → T9 signed-out redirect test + T10 sign-out test. 3 → T7 cancel test + T8 cancelled-Google widget test. 4 → T7 `mapAuthException` test. 5 → T11 rules tests.
- Type consistency: `AuthUser`, `AuthError`, `AuthException`, `UserProfile`, `UserRole`, `tabsFor`, `TabSpec.labelKey`, `computeRedirect`, `currentProfileProvider` are defined once and used with the same names in later tasks. `AppButton` constructors accept `key` via `super.key`. `AppColors.bookingWaiting/Accepted/Denied/Opened/Closed`, `primarySubtle`, `overlay`, `foregroundInverse` come from tokens.json semantic names via the camelCase rule in the generator.
- Known sequencing note: T6 step 4 references `routerProvider` from T9; executors doing tasks strictly in order keep the T2 `_Root` until T9 lands, then apply T6 step 4.
