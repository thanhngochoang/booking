# app_flutter

Flutter client (Android first) for "Cộng đồng nhiếp ảnh gia".
Spec: `../docs/superpowers/specs/2026-09-30-photography-marketplace-design.md` ·
Plan: `../docs/superpowers/plans/2026-09-30-flutter-foundation.md`.

## Setup (no admin rights)

From the repo root, once per machine:

```bash
scripts/setup.sh            # Android SDK, Flutter SDK, fonts into the repo
source scripts/env.sh       # every new shell
cp app/google-services.json app_flutter/android/app/   # Firebase Android config (gitignored)
```

Then:

```bash
cd app_flutter
flutter pub get
dart run tool/gen_tokens.dart                            # theme from ../design-system/tokens.json
dart run build_runner build --delete-conflicting-outputs # freezed / json
flutter gen-l10n
flutter run                                              # or: flutter build apk --debug
```

`lib/firebase_options.dart` is gitignored. Recreate it from `android/app/google-services.json`
(fields `api_key`, `mobilesdk_app_id`, `project_number`, `project_id`, `storage_bucket`) or run
`flutterfire configure --project=time-96441 --platforms=android --android-package-name=com.thanhbk.timnhay`.

## Tests

```bash
flutter analyze && flutter test
cd firebase/rules-test && npm install && npm test   # Firestore rules on the emulator (needs JDK 17+)
```

## Layout

| Folder | Holds |
|--------|-------|
| `lib/app` | `MyApp`, go_router config with auth/role redirects, tab specs |
| `lib/core` | theme generated from design tokens, shared widgets (EmptyState, StatusBadge, AppButton) |
| `lib/data` | models (freezed) and repositories: Firebase implementation + Fake for tests |
| `lib/features` | one folder per screen or flow: auth, onboarding, shell |
| `lib/l10n` | `app_vi.arb`, every user-visible string |
| `firebase` | Firestore rules, emulator config, rules tests |
| `tool` | code generators (`gen_tokens.dart`) |

## Rules

- Riverpod controllers only; widgets never call repositories directly.
- Strings live in `lib/l10n/app_vi.arb`. Colors, spacing, radius and type sizes come from
  `lib/core/theme/tokens.g.dart`; regenerate after editing `design-system/tokens.json`.
- Every screen ships with an empty state and a widget test using the Fake repositories,
  checked at 320 and 430 logical px wide with text scale 1.3.
- Sibling boxes in one row share a height and grow with their content; long text wraps.
