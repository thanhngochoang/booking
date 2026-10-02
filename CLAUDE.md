# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Cộng đồng nhiếp ảnh gia" (applicationId `com.thanhbk.booking`) is a native Android app (Java, 2017) for booking photographers. Two roles share one app: customers find/book photographers and post open projects; photographers manage albums, accept/deny bookings and attend open projects. Both roles can chat 1‑1. There is no custom backend: everything goes through Firebase (Auth via Facebook/Google, Firestore, Realtime Database, Storage).

UI strings are Vietnamese. Java package is `com.paditech.mvpbase` (the app was scaffolded from a Paditech MVP template; `APIService`/`APIClient` and `FlickrManager` are leftover template code, not used by the core flows).

## Build / test

Legacy toolchain: Gradle 4.1 wrapper, Android Gradle Plugin 3.0.1, compileSdk 26, pre‑AndroidX Support Library, deprecated `compile` dependency syntax. It requires an old JDK (8) and Android Studio 3.x; expect it not to build with a current Android Studio/JDK without a full upgrade.

```bash
./gradlew assembleEnvTestDebug          # build debug APK (flavors: envReal, envTest)
./gradlew assembleEnvRealRelease
./gradlew installEnvTestDebug           # install on connected device
./gradlew testEnvTestDebugUnitTest      # JVM unit tests
./gradlew testEnvTestDebugUnitTest --tests com.paditech.mvpbase.ExampleUnitTest
./gradlew connectedEnvTestDebugAndroidTest   # instrumented tests (device required)
```

The two flavors are identical: both `Config.java` files (`app/src/envReal`, `app/src/envTest`) are empty and both use the same applicationId. Only the default example tests exist.

## Architecture

### Custom MVP framework (`common/mvp`)
Every screen is a triple in `screen/<name>/`:
- `XxxContact` — two nested interfaces: `ViewOps` (what the presenter can call on the view) and `PresenterViewOps` (what the view can call on the presenter).
- `XxxPresenter` — extends `FragmentPresenter<ViewOps>` or `ActivityPresenter<ViewOps>`; does all Firebase calls and reports back via `getView()`.
- `XxxFragment` / `XxxActivity` — extends `MVPFragment<PresenterViewOps>` / `MVPActivity<...>`, returns the presenter class from `onRegisterPresenter()`, uses ButterKnife for views, and accesses the presenter via `mPresenter`.

Presenters are instantiated by reflection through the `PresenterFactory` singleton, keyed by the view class's simple name, so a presenter needs a public no‑arg constructor. Progress/error dialogs are delegated from fragments to the host `MVPActivity`.

### Navigation
`LoginActivity` is the launcher. After login, `MainActivity` hosts all feature screens as fragments via `replaceFragment(...)`, driven by a navigation drawer whose items come from `MenuType.UserMenu` or `MenuType.PhotographerMenu` depending on `User.is_photographer`. Only a few flows (register, terms, update profile, full‑screen image view, multi‑image picker) are separate activities.

### Data flow
- **Firestore collections**: `users` (doc id = Firebase Auth uid), `booking`, `albums`, `chat_room`, `photographers_attended`. Models in `common/model` expose `getMaps()` for writes; fields not stored are marked `@Exclude`.
- **Realtime Database**: `chat_room/<id>/messages`, `user_devices`.
- **Storage**: `albums/`, `avatars/`, `image/` (chat images). Album uploads run in `UploadFileService` (an `IntentService`) and finish with an `UploadAlbumSuccess` EventBus event.
- **Realm** (`timnhay.realm`) is a local cache for `Booking` and `ChatRoom` only. `BaseApplication` attaches Firestore snapshot listeners once a user is authenticated, writes results into Realm, then posts `OnUpdateCalendarEvent` / `OnUpdateMessagesEvent` on EventBus. Screens such as Calendar and List Messenger read from Realm and refresh on those events rather than querying Firestore themselves. Realm models (`Booking`, `ChatRoom`) mark non‑persisted fields with `@Ignore` in addition to `@Exclude`.
- Booking lifecycle is the int `status` field mapped by `BookStatus` (WAITING=0, ACCEPTED=1, DENIED=2, OPENED=3, CLOSED=4); `Booking.is_photographer_project` distinguishes direct bookings from open projects that photographers attend. Price buckets for search live in `PriceEnum`.
- Current uid and login state come from `PrefUtil` (wraps Firebase Auth + SharedPreferences).

### Other notable pieces
- Date/time display formats are centralised in `common/utils/Constant.java`.
- Calendar screen uses `android-week-view` and can sync to Google Calendar via the Google Calendar API (`google_calendar_account` on `User`).
- Registration terms are the static HTML asset `app/src/main/assets/list_terms.html`.

## Flutter rewrite (`app_flutter/`, branch `flutter-rewrite`)

Everything above describes the legacy Java app, kept as reference. The rewrite is a Flutter app (package `photobooking`, Riverpod + go_router + freezed) on Firebase today, designed so the backend can later move to a self-hosted system. Design and specs are written in Vietnamese.

### Design and specs (read before building or changing a screen)

- **UI mock**: `docs/design/ui-mock.html`, a standalone page; open it in a browser. The "Debug" button shows each screen's code; add `#S12` to the URL to jump to a screen. Published copy: https://claude.ai/artifact/LptNpoqnt5KjQ5tUaPjYDM (private; the repo file is the source to edit).
- **Main spec**: `docs/superpowers/specs/2026-10-01-remaining-screens.md` (theme, screen-code table, events, contact, location, badges, recommender, escrow, open questions). It extends the original `2026-09-30-photography-marketplace-design.md`.
- **Per-screen specs**: `docs/superpowers/specs/screens/` (`README.md` has the template and cross-cutting conventions).
- **Shared widgets**: `docs/superpowers/specs/components/shared-components.md`.
- **Data model** (backend-agnostic, migration target): `docs/superpowers/specs/data-model/` (`README.md` conventions and ports, `domain-model.md`, `relational-schema.md`).
- **Recommender service contract**: `services/recommender/api/openapi.yaml`.
- **Screen codes**: screens are numbered `S01`–`S67` (S56–S62 reserved for job posts; S63–S65 notifications; S66 splash, S67 session error) in a single increasing sequence (S47–S55 are instant booking, `docs/superpowers/specs/2026-10-01-instant-booking-design.md`) (never renumber; new screens take the next number). When the user names a code ("fix S07"), find it in the mock and in `specs/screens/*.md`. Keep mock, spec and the code table in sync when one changes.

### Rules to follow

- **Theme**: dark aurora is the default; tokens come from `design-system/tokens.json` → `dart run tool/gen_tokens.dart` → `lib/core/theme/tokens.g.dart` (never edit the generated file). Use `AppColors`/`AppSpace`/`AppRadius`, not raw hex or numbers.
- **UI matches the mock**: `docs/design/ui-mock.html` (the committed artifact) is the authority for layout, section order, copy, component types and states; the specs stay the authority for behaviour. When they disagree, follow the mock (or update the mock if the spec is newer) and say so.
- **One primary action per screen**: `AppButton.primary` (filled by `CtaSurface`: theme gradient, or the user's blurred avatar). This means the screen's main CTA; a small primary button on each list card is allowed where the mock shows one (e.g. "Đặt" on `PhotographerCard`). Cancel/decline is a red button inside a confirmation sheet, never the gradient button.
- **Imports**: `package:photobooking/...` only (enforced by lint), and features import `core/core.dart`, not files inside `core/`.
- **Firebase isolation**: `cloud_firestore`/`firebase_*` may only appear in the data adapters, `firebase_options.dart` and `main.dart`; domain and features depend on repository interfaces. Follow the id, time, money and enum conventions in `data-model/README.md` (ULID/opaque ids, UTC instants, integer VND, string enum codes, no Firebase types in the domain).
- **Server code**: Cloud Functions live in `app_flutter/firebase/functions` (thin adapters: callables, Firestore access, wiring; region `asia-southeast1`); business rules live in `packages/domain` (TypeScript, no Firebase or Node imports, enforced by lint and a test) so a self-hosted server can reuse them. Seed accounts for the emulators are listed in `app_flutter/firebase/functions/seed/README.md` (test values only).
- **Strings** live in `lib/l10n/app_vi.arb` (run `flutter gen-l10n`); no hard-coded UI text. Free events show the tag "Không thu phí", never "0₫".
- **Money and contact rules** (product decisions, do not weaken): deposits and ticket money are held in escrow until the shoot/event is completed; phone, Zalo and WhatsApp channels unlock only after booking/ticket payment (before that, only in-app "inquiry" chat); a customer needs a phone number to book; phone numbers never go in the public `users/{uid}` document.

### Commands (run from `app_flutter/`)

```bash
source ../scripts/env.sh && export HOME="$PWD/../.home"   # project-local Flutter/JDK; HOME avoids tool-telemetry writes outside the sandbox
export PATH="$PWD/../.flutter/bin:$PATH"
flutter analyze && flutter test
dart run tool/gen_tokens.dart      # after editing design-system/tokens.json
flutter gen-l10n                   # after editing lib/l10n/app_vi.arb
../scripts/backend-local.sh        # local backend: Auth/Firestore/Functions/Storage emulators + UI :4000, seed; --fresh, --seed, --lan
flutter run --dart-define=USE_EMULATORS=true                                          # debug app → local backend (Android emulator 10.0.2.2, iOS Simulator 127.0.0.1)
flutter run --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=10.0.3.2     # Genymotion (backend with --lan); real device: the Mac's LAN IP
(cd ../packages/domain && npm test)                                                   # pure domain rules (TypeScript, no Firebase)
(cd firebase/functions && npm test && npm run test:integration)                       # Cloud Functions unit + emulator tests (outside the Claude sandbox)
```

Firebase rules/indexes live in `app_flutter/firebase/`. `.firebaserc` has aliases only, no default: `dev` = `booking-c1922`; `prod` is added once the production project exists (it is a separate project). From `app_flutter/firebase/rules-test/`: `npm test` (emulator; not run while executing plans, the sandbox cannot run it, CI runs it on push), `npm run deploy:rules:dev|prod`, `npm run deploy:storage:dev|prod`. CI (`.github/workflows/firebase-deploy.yml`) deploys Firestore and the Cloud Functions (job `deploy-functions`, after the domain and functions tests; the project must be on Blaze) to GitHub environment `dev` on push to `flutter-rewrite`/`develop` and to `production` on push to `main`; project id and key come from each environment (`FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT`), deploy is skipped while the id is unset; Storage only on manual run. Setup steps: `docs/FIREBASE-SETUP.md` (sections 6, 9, 10, 11).
