# app_flutter

Flutter client (Android first) for "Cộng đồng nhiếp ảnh gia".
Spec: `../docs/superpowers/specs/2026-09-30-photography-marketplace-design.md` ·
Plan: `../docs/superpowers/plans/2026-09-30-flutter-foundation.md`.

## Setup (no admin rights)

Step-by-step guide for a new machine (Vietnamese): `../docs/SETUP.md`.

From the repo root, once per machine:

```bash
scripts/setup.sh            # Android SDK, Flutter SDK, fonts into the repo
source scripts/env.sh       # every new shell
# Firebase: add Android app com.thanhbk.photobooking in the console and put its
# google-services.json in app_flutter/android/app/ (gitignored). See ../docs/FIREBASE-SETUP.md
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

Full Firebase setup (project, SHA‑1, providers, Firestore, rules): `../docs/FIREBASE-SETUP.md`.

`lib/firebase_options.dart` is gitignored. Recreate it from `android/app/google-services.json`
(fields `api_key`, `mobilesdk_app_id`, `project_number`, `project_id`, `storage_bucket`) or run
`flutterfire configure --project=time-96441 --platforms=android --android-package-name=com.thanhbk.photobooking`.

**Facebook login** needs `FACEBOOK_CLIENT_TOKEN` in the repo-root `.env` (copy `.env.example`;
Meta developer console → Settings → Advanced → Client token). Gradle injects it as
`@string/facebook_client_token`. Until it is set, the Facebook button shows the generic sign-in error.

## Tests

```bash
flutter analyze && flutter test
cd firebase/rules-test && npm install && npm test   # Firestore rules on the emulator (needs JDK 17+)
```

## Local backend (Firebase Emulator Suite)

One command from the repo root (Node 22+, JDK 17 via `scripts/env.sh`):

```bash
scripts/backend-local.sh            # start; reuses saved data, seeds on the first run
scripts/backend-local.sh --fresh    # wipe saved data, then seed
scripts/backend-local.sh --seed     # re-apply the seed on top of saved data
scripts/backend-local.sh --lan      # listen on 0.0.0.0 (Genymotion, real devices)
```

| Service | Port | Notes |
|---|---|---|
| Emulator UI | 4000 | http://127.0.0.1:4000 |
| Auth | 9099 | seed accounts: `firebase/functions/seed/README.md` (password `seed-password-1`) |
| Firestore | 8080 | rules from `firebase/firestore.rules` |
| Functions | 5001 | `asia-southeast1`, rebuilt by `node build.mjs --watch` |
| Storage | 9199 | rules from `firebase/storage.rules` (deny all for now) |

Data is saved to `firebase/.emulator-data/` (gitignored) on Ctrl-C. The emulator project id is the
app's own (`android/app/google-services.json`), because Android initialises Firebase natively with it;
override with `FIREBASE_PROJECT=…`.

Run the debug app against it (from `app_flutter/`):

| Target | Command | Backend flag |
|---|---|---|
| Android emulator | `flutter run --dart-define=USE_EMULATORS=true` (host `10.0.2.2`) | — |
| iOS Simulator | `flutter run --dart-define=USE_EMULATORS=true` (host `127.0.0.1`); needs the iOS enablement plan first | — |
| Genymotion | `flutter run --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=10.0.3.2` | `--lan` |
| Real Android/iOS device | `--dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=$(ipconfig getifaddr en0)` (same Wi-Fi) | `--lan` |
| Real Android via USB | `adb reverse tcp:9099 tcp:9099 && adb reverse tcp:8080 tcp:8080 && adb reverse tcp:5001 tcp:5001 && adb reverse tcp:9199 tcp:9199`, then `--dart-define=EMULATOR_HOST=127.0.0.1` | — |

Only debug builds honour `USE_EMULATORS`; the app logs `Firebase: using local emulators at <host>`.
When switching an installed app between the cloud and the emulators, clear its data first
(`adb shell pm clear com.thanhbk.photobooking`) so a cloud sign-in is not reused. App Check is not
enforced locally. Inside the Claude Code sandbox the Functions emulator cannot open its Unix socket;
run the script and the emulator tests outside it.

Backend tests:

```bash
(cd ../packages/domain && npm test)                                         # pure rules, no emulator
(cd firebase/functions && npm test && npm run test:integration)              # unit + emulator integration
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
