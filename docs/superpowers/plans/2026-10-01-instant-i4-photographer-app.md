# Instant I4: "Chụp ngay" Photographer App (S13.08, S14) Implementation Plan

> **Rules emulator tests (2026-10-02, user):** do not run the Firestore/Storage rules tests on the emulator (`app_flutter/firebase/rules-test`, `npm test`, `npm run test:*`) while executing this plan; the sandbox cannot run them. Still write or update the rules and their test files as the task says, but skip every step that runs them and every `Expected:` that depends on them; CI (`flutter.yml`, `firebase-deploy.yml`) runs them on push and blocks deploy on failure. Record the skip in the ledger.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A photographer can switch on "Live Shutter" (S14.01) after accepting the package price list, receive a 30-second offer full screen even when the app is in the background (S14.02), accept it, drive to the customer with live location sharing and an external "Chỉ đường" (S14.03), mark "Đã đến" / "Bắt đầu chụp" / "Hoàn thành", or cancel with the amount shown first (S13.08), and the phone stops using GPS as soon as it is not needed.

**Architecture:** Everything the app sends goes over HTTPS to the dispatch service (`services/dispatch/api/openapi.yaml`) through the existing `ApiClient` + `IdTokenSource` of backend phase 2 (a second `ApiClient` instance pointed at `DISPATCH_URL`, no second HTTP client class). Two ports, `PresenceRepository` and `InstantJobRepository`, have an HTTP adapter and an in-memory fake. Realtime state is read only from the Firestore mirror (`instant_offers/{uid}`, `instant_requests/{id}`, `instant_tracks/{id}`) behind a read-only `InstantMirror` port. A keep-alive `InstantSessionController` owns presence (one medium-accuracy fix, then a 300 m distance-filtered stream and a 5-minute network heartbeat that reuses the last fix), the Android foreground service with the "Tắt" action, the offer listener, the 30-minute auto-off prompt and the low-battery prompt. A keep-alive `InstantJobController` owns one accepted job: a high-accuracy route stream throttled to one post every 10–15 s while `assigned`/`en_route`, stopped the moment the job is `arrived`, finished, cancelled or the photographer goes offline. Platform plugins (geolocator, flutter_foreground_task, flutter_local_notifications, firebase_messaging, battery_plus, maplibre_gl) each sit behind a small port with a fake, so every behaviour, including battery properties, is unit-tested.

**Tech Stack:** Flutter, Riverpod 3, go_router, `http` (via phase 2's `ApiClient`), `cloud_firestore` (mirror and device adapters only), `geolocator` (already added by 3a1), new `flutter_foreground_task`, `flutter_local_notifications`, `firebase_messaging`, `battery_plus`, `maplibre_gl`; dev: `fake_async`, `yaml`; Firestore rules + `@firebase/rules-unit-testing`; `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-01-instant-booking-design.md` (§2.2, §3, §5, §6, §8, §9, §10, §11); contract `services/dispatch/api/openapi.yaml` (paths, schemas, enums, error codes; the Dart wire layer is checked against it by a test); mock `docs/design/ui-mock.html` screens `data-code="S14.01"`, `"S14.02"`, `"S14.03"`, `"S13.08"`; `docs/superpowers/specs/screens/README.md` (per-screen conventions); `docs/superpowers/specs/components/shared-components.md`; `docs/superpowers/specs/data-model/README.md` (ids, UTC instants, integer VND, string enums, `Device` entity in `domain-model.md`).

**Prerequisite (all done first; exact APIs used are listed per task under "Consumes"):**

- `docs/superpowers/plans/2026-10-01-screen-codes.md`: `ScreenCode`, `ScreenCodes.instantAvailability` (S14.01), `.instantOffer` (S14.02), `.instantJob` (S14.03), `.instantCancel` (S13.08); `test/support/idle.dart` (`expectIdle`); `docs/testing/battery-and-performance.md`.
- `docs/superpowers/plans/2026-10-01-core-display-widgets.md`: `hostWidget` in `test/core/widgets/widget_host.dart`.
- `docs/superpowers/plans/2026-10-01-step2a-phone-and-customer-contact.md`: route `/profile/phone?returnTo=…`, `UserContact`, `FakeUserContactRepository`, `userContactRepositoryProvider`.
- `docs/superpowers/plans/2026-10-01-step2b-contact-dial-and-channels.md`: `ContactChannel`, `ContactAccess`, `ContactAction`, `ContactSubject` (`lib/data/contact/contact_link_repository.dart`), `FakeContactLinkRepository`, `ExternalLauncher`/`FakeExternalLauncher` (`lib/data/contact/external_launcher.dart`), `contactLinkRepositoryProvider`, `externalLauncherProvider` (`lib/data/contact/contact_providers.dart`); Android `<queries>` block.
- `docs/superpowers/plans/2026-10-01-step3a1-location-foundations.md`: `haversineKm` (`core/geo.dart`), `formatDistance` (`core/format.dart`), `toVn` (`core/vn_time.dart`), `AppChip`, `showAppSheet`, `LocationRepository`/`LocationPermissionStatus`/`FakeLocationRepository`, `test/support/blur.dart` (`expectBlurBudget`), `test/battery/location_foundations_battery_test.dart` (relaxed in Task 4).
- `docs/superpowers/plans/2026-10-01-step3a2-explore-screens.md`: `formatMoney`, `clockProvider` (`lib/data/clock/clock.dart`), `locationRepositoryProvider` (`lib/features/explore/location_controller.dart`), `ErrorState`, `AppSkeleton`, `test/support/screen_host.dart` (`screenApp`, `screenRouterApp`).
- `docs/superpowers/plans/2026-10-01-step3b4-home-detail-find.md`: `formatDuration` (`core/format.dart`).
- `docs/superpowers/plans/2026-10-01-backend-phase2-selfhosted-postgres.md` Task 8 (`ApiClient`, `ApiException`, `IdTokenSource`, `StaticIdTokenSource`, `idTokenSourceProvider` in `lib/data/http/api_providers.dart`, `test/data/http/mock_api.dart` `MockApi`/`apiError`) and Task 9 (the `yaml` dev dependency and the drift-test pattern).
- `docs/superpowers/plans/2026-10-01-backend-phase1-firebase-local.md`: `firebase/firestore.rules` and `firebase/rules-test/` (rules tests in Task 3).
- `docs/superpowers/plans/2026-10-01-ios-enablement.md` Task 1 (`test/platform/ios_config_test.dart`, relaxed in Task 4). If it has not run, skip that sub-step and note it in the PR.
- Instant plan I3 (dispatch service) is needed only for the manual end-to-end run in Task 16; every automated test uses fakes or `MockApi`. Plan 2d (photographer profile, route `/setup/1`) is linked by path only.

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Run `dart format lib test` before each commit (`flutter analyze` fails on infos).
- Imports are `package:photobooking/...` only; features import `package:photobooking/core/core.dart`, never files inside `core/`; files inside `core/` import each other directly.
- **Firebase isolation:** `cloud_firestore` and `firebase_*` (including `firebase_messaging`) appear only in `lib/data/**` adapters (`firestore_instant_mirror.dart`, `firestore_device_registry.dart`, `firebase_push_messages.dart`), `firebase_options.dart` and `main.dart`. Domain models (`instant_models.dart`) and features use the ports. Other plugins likewise appear only in their adapter file: `geolocator` in `geolocator_tracking_location.dart` (and 3a1's adapter), `flutter_foreground_task` in `foreground_task_session.dart` (+ `main.dart`), `flutter_local_notifications` in `local_instant_notifier.dart`, `battery_plus` in `battery_level.dart`, `maplibre_gl` in `lib/core/map/maplibre_map_engine.dart` (+ `main.dart`).
- **Data conventions** (`data-model/README.md`): ids are opaque strings (ULIDs from the service), instants are UTC `DateTime` and ISO 8601 `…Z` on the wire, money is integer VND (`int`), enums are the contract's string codes. No Firebase type (`Timestamp`, `GeoPoint`) leaves an adapter.
- **The contract is the source of truth:** paths, JSON keys, enum codes and error codes are exactly those of `services/dispatch/api/openapi.yaml`; `test/data/instant/dispatch_contract_test.dart` (Task 1) fails when they drift. The app never writes `instant_*` documents; it only reads the mirror.
- **UI strings** only in `lib/l10n/app_vi.arb` (Vietnamese with full diacritics), then `flutter gen-l10n`; keys are camelCase with an `instant…` prefix (the convention of the existing arb, as in plan 2b). Code that runs without a `BuildContext` (session controller, background isolate) uses `lookupAppLocalizations(const Locale('vi'))`.
- **Theme:** colours, spacing, radii from `AppColors`/`AppColorsDark`/`AppSpace`/`AppRadius`; no raw hex in features. Secondary text uses `AppColorsDark.foregroundSecondary` / `AppColors.foregroundSecondary`.
- **One primary action per screen** (`AppButton.primary`). Cancel and decline are never the gradient button: the screen shows a red text or outline button that opens a sheet, and the sheet's confirmation is `AppButton.danger` (red, added in Task 7). The amount refunded is always shown in words before the confirmation.
- **Contact rules (product decisions, do not weaken):** phone/Zalo/WhatsApp open only after payment (an assigned instant request is paid, so S14.03 may show `ContactAction` with `ContactAccess.unlocked`); the app never shows or stores a phone number; phone numbers never go into the public `users/{uid}` document (or any `instant_*` mirror). The exact meet-point address is shown only after "Nhận" (S14.02 shows the area and distance only).
- **Location and battery (spec §9, a deliberate exception to the "no background service" rule of `docs/testing/battery-and-performance.md`, documented there in Task 15):** location runs only while the photographer is available or en route; idle presence uses medium accuracy (≈100 m), a 300 m distance filter and a 5-minute heartbeat that re-sends the last fix without a new GPS fix; en route uses high accuracy, posted every 10–15 s (never faster than the service's 1 per 5 s); GPS stops on `arrived`, on finish/cancel and when going offline. Android: foreground service type `location` with the persistent notification "Đang nhận việc chụp ngay" and a "Tắt" action, `ACCESS_FINE_LOCATION` + `FOREGROUND_SERVICE_LOCATION`, **never** `ACCESS_BACKGROUND_LOCATION`, no wake lock. iOS: "When In Use" only, `allowsBackgroundLocationUpdates` + `showsBackgroundLocationIndicator` while sharing, `UIBackgroundModes` = `location` only, **never** `NSLocationAlways*`.
- Interactive controls have a 48dp touch target (S14.02 "Nhận việc" is at least 56dp); meaning never rests on colour alone; every map pin has a text label; animations honour `MediaQuery.disableAnimationsOf`. Widget tests run at 390dp and at 320dp with text scale 1.3, in dark and light themes.
- The Goong map key comes from `--dart-define=GOONG_MAPTILES_KEY=…` (restricted by package name / bundle id in the Goong console), is never logged and never appears in an exception text.
- Commits use Conventional Commits and end with `Co-Authored-By: TonyH <thanhngochoangbk@gmail.com>`.

## Packages (added with `flutter pub add`, each behind one adapter)

| Package | Why this one | Where |
|---|---|---|
| `geolocator` (exists, ≥ 12) | Already the location plugin of 3a1; `getPositionStream` with `AndroidSettings(distanceFilter, intervalDuration)` / `AppleSettings(allowBackgroundLocationUpdates, showBackgroundLocationIndicator, pauseLocationUpdatesAutomatically)` covers both idle presence and en-route tracking, so no second location plugin. | `geolocator_tracking_location.dart` |
| `flutter_foreground_task` | Android 14 requires a typed foreground service for location while the app is not visible; this package declares `foregroundServiceType="location"`, shows an ongoing notification with **action buttons** (the "Tắt" action; geolocator's own foreground notification has no buttons) and runs no Dart loop when `eventAction` is `nothing()`, so it costs nothing beyond the notification. | `foreground_task_session.dart` |
| `flutter_local_notifications` | The only maintained plugin with Android full-screen intents (`fullScreenIntent`, `category: call`, `requestFullScreenIntentPermission`) **and** iOS `InterruptionLevel.timeSensitive`, plus notification actions for "Vẫn nhận" / "Tắt". | `local_instant_notifier.dart` |
| `firebase_messaging` | The service sends FCM (spec §5); it gives the device token, foreground messages, a background isolate handler and "opened from notification". | `firebase_push_messages.dart`, `fcm_background.dart` |
| `battery_plus` | One `batteryLevel` read on each 5-minute heartbeat (no stream, no extra wake-up) for the < 15 % prompt. | `battery_level.dart` |
| `maplibre_gl` | Spec decision: Goong tiles are Mapbox-style compatible; MapLibre renders them natively with its own tile cache, and lets us move a marker without rebuilding the map. | `lib/core/map/maplibre_map_engine.dart` |
| dev `fake_async` | Drives the 5-minute heartbeat, 30-minute auto-off and 10–15 s route throttle deterministically in unit tests. | tests |
| dev `yaml` (exists after phase 2 Task 9) | Reads `openapi.yaml` in the contract drift test. | tests |

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/lat_lng.dart` (create) | `LatLng`, `lerpLatLng`, `distanceMeters` |
| `lib/core/widgets/ticking_builder.dart` (create) | `TickingBuilder` (1 Hz rebuild only while `active`, counted for tests) |
| `lib/core/widgets/countdown_ring.dart` (create) | `CountdownRing` (number + ring, semantics) |
| `lib/core/widgets/app_button.dart` (modify) | `AppButton.danger` |
| `lib/core/widgets/app_map.dart` (create) | `AppMap`, `AppMapScope`, `AppMapEngine`, `AppMapView`, `MapMarker`, `MapMarkerKind` |
| `lib/core/map/goong_config.dart` (create) | `GoongConfig` (keys from dart-defines, redacted) |
| `lib/core/map/maplibre_map_engine.dart` (create) | `MaplibreMapEngine` (Goong style, markers, interpolation) |
| `lib/core/core.dart` (modify) | exports (not the maplibre engine) |
| `lib/data/http/api_client.dart` (modify, phase 2) | `get(path, {query})`, `uriFor(path, {query})` |
| `lib/data/instant/instant_models.dart` (create) | enums, value types, `DispatchException` |
| `lib/data/instant/instant_wire.dart` (create) | `DispatchPaths`, `dispatchOperations`, JSON mappers, `dispatchGuard` |
| `lib/data/instant/dispatch_config.dart` (create) | `DispatchConfig` (`DISPATCH_URL`) |
| `lib/data/instant/instant_repositories.dart` (create) | `PresenceRepository`, `InstantJobRepository` ports |
| `lib/data/instant/http_instant_repositories.dart` (create) | HTTP adapters, `DisabledDispatch` |
| `lib/data/instant/fake_instant_repositories.dart` (create) | fakes |
| `lib/data/instant/instant_mirror.dart` (create) | `InstantMirror` port, `FakeInstantMirror` |
| `lib/data/instant/firestore_instant_mirror.dart` (create) | read-only Firestore adapter |
| `lib/data/instant/instant_providers.dart` (create) | dispatch client, repositories, mirror providers |
| `lib/data/instant/tracking_location.dart` (create) | `TrackingLocationSource`, `FixAccuracy`, `FakeTrackingLocationSource` |
| `lib/data/instant/geolocator_tracking_location.dart` (create) | geolocator adapter |
| `lib/data/instant/foreground_session.dart` (create) | `ForegroundSession` port, fake, no-op (iOS) |
| `lib/data/instant/foreground_task_session.dart` (create) | flutter_foreground_task adapter |
| `lib/data/instant/battery_level.dart` (create) | `BatteryLevel`, battery_plus adapter, fake |
| `lib/data/instant/instant_notifier.dart` (create) | `InstantNotifier` port, `InstantTap`, fake, `notificationIdFor` |
| `lib/data/instant/local_instant_notifier.dart` (create) | flutter_local_notifications adapter |
| `lib/data/instant/instant_push.dart` (create) | `InstantPush` parsing, `PushMessages`, `DeviceRegistry` ports and fakes |
| `lib/data/instant/firebase_push_messages.dart`, `firestore_device_registry.dart`, `fcm_background.dart` (create) | FCM adapter, `devices/{id}` writer, background handler |
| `lib/data/instant/instant_labels.dart` (create) | genre/package labels and the offer notification text (no `BuildContext`) |
| `lib/features/instant_common/instant_services.dart` (create) | platform service providers |
| `lib/features/instant_common/instant_cancel_sheet.dart` (create) | S13.08 sheet (customer and photographer) |
| `lib/features/instant_common/instant_milestones.dart` (create) | the "Đã nhận · 15:21" milestone list (S13.06, S14.03) |
| `lib/features/instant_work/instant_rules.dart` (create) | presence/route send policies, arrive radius, directions URIs |
| `lib/features/instant_work/instant_session_controller.dart` (create) | presence, foreground service, offers, auto-off, battery |
| `lib/features/instant_work/instant_job_controller.dart` (create) | accept/decline, route tracking, arrive/start/finish/cancel |
| `lib/features/instant_work/instant_navigation.dart` (create) | notification taps and new offers → routes |
| `lib/features/instant_work/photographer_only.dart` (create) | role guard for `/work/instant…` |
| `lib/features/instant_work/instant_availability_screen.dart` (create) | S14.01 |
| `lib/features/instant_work/instant_work_card.dart` (create) | entry card on the Công việc tab |
| `lib/features/instant_work/instant_offer_screen.dart` (create) | S14.02 |
| `lib/features/instant_work/instant_job_screen.dart` (create) | S14.03 |
| `lib/features/shell/placeholder_tabs.dart`, `lib/app/router.dart`, `lib/main.dart` (modify) | entry card, routes, plugin wiring |
| `lib/data/contact/contact_link_repository.dart` (modify, plan 2b) | `ContactSubject.instant` |
| `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs` (modify) | `instant_*` read-only rules, `devices/{id}` owner rules |
| `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `ios/Runner/Runner.entitlements`, `ios/Runner/AppDelegate.swift` (modify/create) | permissions, service, full-screen intent, background mode, time-sensitive |
| `test/battery/location_foundations_battery_test.dart` (modify, 3a1), `test/platform/ios_config_test.dart` (modify, iOS enablement) | relax only what Chụp ngay needs |
| `docs/superpowers/specs/2026-10-01-instant-booking-design.md`, `docs/superpowers/specs/components/shared-components.md`, `docs/testing/battery-and-performance.md` (modify) | align docs |
| `test/support/instant_world.dart`, `test/support/fake_map_engine.dart` (create) | shared fakes and overrides (plan I5 extends them) |
| tests | listed per task; `test/battery/instant_photographer_battery_test.dart` |

---

### Task 1: Value types and the dispatch wire format

**Files:**
- Create: `lib/core/lat_lng.dart`, `lib/data/instant/instant_models.dart`, `lib/data/instant/instant_wire.dart`, `test/core/lat_lng_test.dart`, `test/data/instant/instant_wire_test.dart`, `test/data/instant/dispatch_contract_test.dart`
- Modify: `lib/core/core.dart`, `lib/data/http/api_client.dart`, `test/data/http/api_client_test.dart`

**Interfaces:**
- Consumes: `haversineKm(double lat1, double lng1, double lat2, double lng2)` (3a1, `core/geo.dart`); `ApiClient`, `ApiException(int status, String code)` (phase 2 Task 8); `MockApi` (`test/data/http/mock_api.dart`).
- Produces:
  - `class LatLng { const LatLng(double lat, double lng); }` (value equality, redacted `toString`), `LatLng lerpLatLng(LatLng a, LatLng b, double t)`, `double distanceMeters(LatLng a, LatLng b)`.
  - Enums with `String code` and `static X? fromCode(String?)`: `InstantGenre` (`portrait, couple, family, small_event, product`), `InstantPackageCode` (`p30, p60, p120`, plus `int minutes`), `InstantStatus` (12 codes, `bool get onTheWay`, `bool get isFinal`), `CancelRule`, `DeclineReason`, `PaymentProvider`, `EligibilityReason`; `DispatchError` (the 14 contract `ErrorCode`s plus client-only `network`, `malformed`, `disabled`, `unknown`; `static DispatchError fromCode(String?)` never null).
  - Value classes: `MeetPoint({lat, lng, address})`, `LocationFix({lat, lng, accuracyM, at, headingDeg?, speedMps?})`, `InstantPackage`, `PackagesQuote` (`byId`, `byCode`), `CreatedRequest`, `CancelQuote` (`totalVnd`, `refundPercent`), `PresenceState`, `InstantSettings` (`priceListAccepted`), `AcceptedJob`, `InstantPhotographer`, `InstantRequestView` (the `InstantRequestMirror`), `InstantTrack`, `InstantOffer` (`remaining(now)`, `isExpired(now)`); `class DispatchException implements Exception { const DispatchException(DispatchError error, {int status = 0}); }`.
  - `instant_wire.dart`: `DispatchPaths`, `dispatchOperations`, `String isoUtc(DateTime)`, mappers `packagesQuoteFromJson`, `createdRequestFromJson`, `cancelQuoteFromJson`, `presenceFromJson`, `settingsFromJson`, `acceptedJobFromJson`, `requestViewFromMap`, `trackFromMap`, `offerFromMap`; bodies `createRequestBody`, `cancelBody`, `locationFixToJson`, `arriveBody`, `presenceBody`, `settingsBody`, `declineBody`; `Future<T> dispatchGuard<T>(Future<T> Function() call)`.
  - `ApiClient.get(String path, {Map<String, String>? query})` and `ApiClient.uriFor(String path, {Map<String, String>? query})` (backwards compatible).

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/lat_lng_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

void main() {
  test('value equality and a redacted toString', () {
    expect(const LatLng(10.77, 106.69), const LatLng(10.77, 106.69));
    expect(const LatLng(10.77, 106.69).toString(), isNot(contains('10.77')));
  });

  test('lerp goes from a to b', () {
    const a = LatLng(10, 106);
    const b = LatLng(11, 107);
    expect(lerpLatLng(a, b, 0), a);
    expect(lerpLatLng(a, b, 1), b);
    expect(lerpLatLng(a, b, 0.5), const LatLng(10.5, 106.5));
  });

  test('distanceMeters uses the great circle', () {
    // About 111 m per 0.001 degree of latitude.
    final d = distanceMeters(const LatLng(10.0, 106.0), const LatLng(10.001, 106.0));
    expect(d, closeTo(111, 2));
  });
}
```

```dart
// test/data/instant/instant_wire_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_wire.dart';

final _t = DateTime.utc(2026, 10, 1, 8, 30);
final _fix = LocationFix(lat: 10.7769, lng: 106.6927, accuracyM: 12, at: _t);

void main() {
  test('enum codes are the contract strings', () {
    expect(InstantGenre.smallEvent.code, 'small_event');
    expect(InstantGenre.fromCode('small_event'), InstantGenre.smallEvent);
    expect(InstantStatus.fromCode('in_progress'), InstantStatus.inProgress);
    expect(InstantStatus.fromCode('cancelled_by_customer'), InstantStatus.cancelledByCustomer);
    expect(InstantStatus.fromCode('nope'), isNull);
    expect(CancelRule.fromCode('free_grace'), CancelRule.freeGrace);
    expect(EligibilityReason.fromCode('price_list_not_accepted'), EligibilityReason.priceListNotAccepted);
    expect(DeclineReason.genreMismatch.code, 'genre_mismatch');
    expect(InstantPackageCode.p120.minutes, 120);
    expect(DispatchError.fromCode('offer_expired'), DispatchError.offerExpired);
    expect(DispatchError.fromCode('something new'), DispatchError.unknown);
  });

  test('status groups', () {
    expect(InstantStatus.assigned.onTheWay, isTrue);
    expect(InstantStatus.enRoute.onTheWay, isTrue);
    expect(InstantStatus.arrived.onTheWay, isFalse);
    expect(InstantStatus.completed.isFinal, isTrue);
    expect(InstantStatus.noMatch.isFinal, isTrue);
    expect(InstantStatus.inProgress.isFinal, isFalse);
  });

  test('packages response maps; typicalMatchMinutes may be null', () {
    final q = packagesQuoteFromJson({
      'cityId': 'hcm',
      'cityName': 'TP. Hồ Chí Minh',
      'priceListVersion': 3,
      'surge': 1,
      'typicalMatchMinutes': null,
      'packages': [
        {'id': 'PK60', 'code': 'p60', 'durationMin': 60, 'photos': 30, 'priceVnd': 690000, 'payoutVnd': 552000},
      ],
    });
    expect(q.priceListVersion, 3);
    expect(q.surge, 1.0);
    expect(q.typicalMatchMinutes, isNull);
    expect(q.byId('PK60')!.payoutVnd, 552000);
    expect(q.byCode(InstantPackageCode.p60)!.photos, 30);
    expect(q.byId('nope'), isNull);
  });

  test('a body that is not the contract shape is "malformed"', () {
    expect(
      () => packagesQuoteFromJson({'cityId': 'hcm'}),
      throwsA(isA<DispatchException>().having((e) => e.error, 'error', DispatchError.malformed)),
    );
    expect(
      () => settingsFromJson({'currentPriceListVersion': 3, 'helpReady': false, 'eligible': true, 'reasons': ['flying']}),
      throwsA(isA<DispatchException>()),
    );
  });

  test('create request body has exactly the contract keys; an empty note is left out', () {
    final body = createRequestBody(
      packageId: 'PK60',
      genre: InstantGenre.portrait,
      meetPoint: const MeetPoint(lat: 10.77, lng: 106.69, address: 'Công viên Tao Đàn'),
      note: '  ',
      expand: false,
      expectedAmountVnd: 690000,
      provider: PaymentProvider.fake,
    );
    expect(body, {
      'packageId': 'PK60',
      'genre': 'portrait',
      'meetPoint': {'lat': 10.77, 'lng': 106.69, 'address': 'Công viên Tao Đàn'},
      'expand': false,
      'expectedAmountVnd': 690000,
      'provider': 'fake',
    });
  });

  test('location fix: ISO UTC instant; null heading and speed are left out', () {
    expect(locationFixToJson(_fix), {
      'lat': 10.7769,
      'lng': 106.6927,
      'accuracyM': 12.0,
      'at': '2026-10-01T08:30:00.000Z',
    });
    final moving = LocationFix(lat: 1, lng: 2, accuracyM: 5, at: _t, headingDeg: 90, speedMps: 8);
    expect(locationFixToJson(moving)['headingDeg'], 90.0);
    expect(locationFixToJson(moving)['speedMps'], 8.0);
  });

  test('presence, settings, cancel, arrive and decline bodies', () {
    expect(presenceBody(online: false), {'online': false});
    expect(presenceBody(online: true, helpReady: true, fix: _fix)['fix'], locationFixToJson(_fix));
    expect(settingsBody(acceptPriceListVersion: 3), {'acceptPriceListVersion': 3});
    expect(settingsBody(helpReady: true), {'helpReady': true});
    expect(cancelBody(dryRun: true), {'dryRun': true});
    expect(cancelBody(dryRun: false, reason: 'Kẹt xe'), {'dryRun': false, 'reason': 'Kẹt xe'});
    expect(arriveBody(fix: _fix), {'fix': locationFixToJson(_fix), 'force': false});
    expect(arriveBody(fix: _fix, force: true, reason: 'GPS yếu')['reason'], 'GPS yếu');
    expect(declineBody(null), <String, Object?>{});
    expect(declineBody(DeclineReason.tooFar), {'reason': 'too_far'});
  });

  test('responses: presence, settings, accept, cancel quote', () {
    final p = presenceFromJson({'online': true, 'helpReady': false, 'cityId': 'hcm', 'expiresAt': '2026-10-01T08:40:00.000Z'});
    expect(p.expiresAt, DateTime.utc(2026, 10, 1, 8, 40));
    final s = settingsFromJson({
      'acceptedPriceListVersion': 2,
      'currentPriceListVersion': 3,
      'helpReady': false,
      'eligible': false,
      'reasons': ['price_list_not_accepted', 'no_phone'],
    });
    expect(s.priceListAccepted, isFalse);
    expect(s.reasons, [EligibilityReason.priceListNotAccepted, EligibilityReason.noPhone]);
    final a = acceptedJobFromJson({
      'requestId': 'R1',
      'meetPoint': {'lat': 10.77, 'lng': 106.69, 'address': '55C Nguyễn Thị Minh Khai'},
      'customerName': 'Lan Anh',
    });
    expect(a.meetPoint.address, '55C Nguyễn Thị Minh Khai');
    final q = cancelQuoteFromJson({'rule': 'en_route_fee', 'refundVnd': 552000, 'photographerVnd': 138000, 'platformVnd': 0, 'graceEndsAt': null});
    expect(q.totalVnd, 690000);
    expect(q.refundPercent, 80);
  });

  test('mirror maps accept ISO strings and DateTime values', () {
    final base = {
      'status': 'en_route',
      'customerId': 'c1',
      'photographerId': 'p1',
      'photographer': {'uid': 'p1', 'displayName': 'Minh Trí', 'avatarUrl': null, 'verified': true, 'rating': 4.9, 'completedShoots': 112},
      'packageCode': 'p60',
      'genre': 'portrait',
      'amountVnd': 690000,
      'expand': false,
      'round': 1,
      'radiusKm': 3,
      'etaMinutes': 9,
      'etaEstimated': false,
      'graceEndsAt': DateTime.utc(2026, 10, 1, 8, 23),
      'meetPoint': {'lat': 10.77, 'lng': 106.69, 'address': 'Công viên Tao Đàn'},
      'requestedAt': '2026-10-01T08:15:00.000Z',
      'assignedAt': '2026-10-01T08:21:00.000Z',
      'updatedAt': '2026-10-01T08:22:00.000Z',
    };
    final v = requestViewFromMap(base);
    expect(v.status, InstantStatus.enRoute);
    expect(v.photographer!.displayName, 'Minh Trí');
    expect(v.graceEndsAt, DateTime.utc(2026, 10, 1, 8, 23));
    expect(v.assignedAt, DateTime.utc(2026, 10, 1, 8, 21));
    expect(v.meetPoint!.address, 'Công viên Tao Đàn');
    expect(v.arrivedAt, isNull);
    expect(v.durationMin, 60);

    final o = offerFromMap({
      'offerId': 'O1',
      'requestId': 'R1',
      'packageCode': 'p60',
      'genre': 'portrait',
      'payoutVnd': 552000,
      'distanceKm': 2.1,
      'travelMinutes': 8,
      'area': 'Phường Bến Thành, Quận 1',
      'note': null,
      'expiresAt': '2026-10-01T08:30:30.000Z',
    });
    expect(o.remaining(_t), const Duration(seconds: 30));
    expect(o.isExpired(_t.add(const Duration(seconds: 30))), isTrue);

    final t = trackFromMap({'lat': 10.78, 'lng': 106.70, 'accuracyM': 8, 'headingDeg': null, 'at': _t});
    expect(t.at, _t);
  });

  test('ApiException becomes DispatchException with the contract code', () async {
    Matcher error(DispatchError e, int status) => throwsA(
      isA<DispatchException>().having((x) => x.error, 'error', e).having((x) => x.status, 'status', status),
    );
    await expectLater(dispatchGuard<void>(() async => throw const ApiException(409, 'offer_expired')), error(DispatchError.offerExpired, 409));
    await expectLater(dispatchGuard<void>(() async => throw const ApiException(0, ApiException.network)), error(DispatchError.network, 0));
    await expectLater(dispatchGuard<void>(() async => throw const ApiException(500, 'unknown')), error(DispatchError.unknown, 500));
    expect(await dispatchGuard(() async => 7), 7);
  });

  test('DispatchException text has no body or URL', () {
    expect(const DispatchException(DispatchError.notEligible, status: 422).toString(), 'DispatchException(not_eligible, 422)');
  });
}
```

```dart
// test/data/instant/dispatch_contract_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_wire.dart';
import 'package:yaml/yaml.dart';

/// The hand-written client against services/dispatch/api/openapi.yaml: when
/// the contract changes, this fails until the app follows.
void main() {
  final doc = loadYaml(File('../services/dispatch/api/openapi.yaml').readAsStringSync()) as YamlMap;
  final paths = doc['paths'] as YamlMap;
  final schemas = (doc['components'] as YamlMap)['schemas'] as YamlMap;

  YamlMap schema(String name) => schemas[name] as YamlMap;
  List<String> enumOf(YamlMap s) => [for (final v in s['enum'] as List) '$v'];

  /// Properties and required keys of a schema, following `allOf` and `$ref`.
  (Set<String>, Set<String>) shape(YamlMap s) {
    if (s.containsKey(r'$ref')) {
      return shape(schema((s[r'$ref'] as String).split('/').last));
    }
    final props = <String>{};
    final required = <String>{};
    for (final part in (s['allOf'] as List?) ?? const []) {
      final (p, r) = shape(part as YamlMap);
      props.addAll(p);
      required.addAll(r);
    }
    props.addAll(((s['properties'] as YamlMap?)?.keys ?? const []).cast<String>());
    required.addAll(((s['required'] as List?) ?? const []).cast<String>());
    return (props, required);
  }

  void checkBody(String name, Map<String, Object?> body) {
    final (props, required) = shape(schema(name));
    expect(props.containsAll(body.keys), isTrue, reason: '$name has no ${body.keys.toSet().difference(props)}');
    expect(body.keys.toSet().containsAll(required), isTrue, reason: '$name needs ${required.difference(body.keys.toSet())}');
  }

  final fix = LocationFix(lat: 10.77, lng: 106.69, accuracyM: 10, at: DateTime.utc(2026, 10, 1), headingDeg: 1, speedMps: 2);

  test('every call the app makes exists in the contract', () {
    for (final (method, path) in dispatchOperations) {
      final item = paths[path] as YamlMap?;
      expect(item, isNotNull, reason: path);
      expect(item![method.toLowerCase()], isNotNull, reason: '$method $path');
    }
  });

  test('DispatchPaths builds exactly those paths', () {
    String fill(String template) => template.replaceAll(RegExp(r'\{\w+\}'), 'id1');
    expect(
      {
        DispatchPaths.health,
        DispatchPaths.packages,
        DispatchPaths.requests,
        DispatchPaths.cancel('id1'),
        DispatchPaths.confirmComplete('id1'),
        DispatchPaths.location('id1'),
        DispatchPaths.arrive('id1'),
        DispatchPaths.start('id1'),
        DispatchPaths.finish('id1'),
        DispatchPaths.presence,
        DispatchPaths.instantSettings,
        DispatchPaths.accept('id1'),
        DispatchPaths.decline('id1'),
        DispatchPaths.devPaymentSucceed('id1'),
      },
      {for (final (_, p) in dispatchOperations) fill(p)},
    );
  });

  test('every enum matches the contract, in order', () {
    expect([for (final v in InstantGenre.values) v.code], enumOf(schema('Genre')));
    expect([for (final v in InstantPackageCode.values) v.code], enumOf(schema('PackageCode')));
    expect([for (final v in InstantStatus.values) v.code], enumOf(schema('InstantRequestStatus')));
    expect([for (final v in CancelRule.values) v.code], enumOf(schema('CancelRule')));
    expect([for (final v in DeclineReason.values) v.code], enumOf(schema('DeclineReason')));
    expect([for (final v in PaymentProvider.values) v.code], enumOf(schema('PaymentProvider')));
    expect(
      [for (final v in DispatchError.values) if (!v.clientOnly) v.code],
      enumOf(schema('ErrorCode')),
    );
    final reasons = ((schema('InstantSettings')['properties'] as YamlMap)['reasons'] as YamlMap)['items'] as YamlMap;
    expect([for (final v in EligibilityReason.values) v.code], enumOf(reasons));
  });

  test('request bodies use only contract properties and carry every required one', () {
    checkBody(
      'CreateRequestBody',
      createRequestBody(
        packageId: 'P',
        genre: InstantGenre.family,
        meetPoint: const MeetPoint(lat: 1, lng: 2, address: 'a'),
        note: 'n',
        expand: true,
        expectedAmountVnd: 1,
        provider: PaymentProvider.fake,
      ),
    );
    checkBody('MeetPoint', const {'lat': 1.0, 'lng': 2.0, 'address': 'a'});
    checkBody('CancelBody', cancelBody(dryRun: true, reason: 'r'));
    checkBody('LocationFix', locationFixToJson(fix));
    checkBody('ArriveBody', arriveBody(fix: fix, force: true, reason: 'r'));
    checkBody('PresenceBody', presenceBody(online: true, helpReady: true, fix: fix));
    checkBody('InstantSettingsBody', settingsBody(acceptPriceListVersion: 3, helpReady: true));
  });

  test('mirror mappers read a document that has only the required fields', () {
    final (_, reqRequired) = shape(schema('InstantRequestMirror'));
    final minimal = <String, Object?>{
      'status': 'searching',
      'customerId': 'c1',
      'packageCode': 'p30',
      'genre': 'couple',
      'amountVnd': 390000,
      'expand': false,
      'round': 1,
      'requestedAt': '2026-10-01T08:00:00.000Z',
      'updatedAt': '2026-10-01T08:00:00.000Z',
    };
    expect(minimal.keys.toSet(), reqRequired);
    expect(requestViewFromMap(minimal).status, InstantStatus.searching);

    final (_, trackRequired) = shape(schema('InstantTrackMirror'));
    final track = {'lat': 1.0, 'lng': 2.0, 'accuracyM': 5.0, 'at': '2026-10-01T08:00:00.000Z'};
    expect(track.keys.toSet(), trackRequired);
    expect(trackFromMap(track).accuracyM, 5.0);

    final (_, offerRequired) = shape(schema('InstantOfferMirror'));
    final offer = {
      'offerId': 'O1',
      'requestId': 'R1',
      'packageCode': 'p30',
      'genre': 'product',
      'payoutVnd': 312000,
      'distanceKm': 1.0,
      'travelMinutes': 4,
      'area': 'Quận 1',
      'expiresAt': '2026-10-01T08:00:30.000Z',
    };
    expect(offer.keys.toSet(), offerRequired);
    expect(offerFromMap(offer).note, isNull);
  });
}
```

Append to `main()` in `test/data/http/api_client_test.dart`:

```dart
  test('get sends query parameters; uriFor keeps the path prefix', () async {
    final api = MockApi({
      'GET /v1/packages': (r) {
        expect(r.url.queryParameters, {'lat': '10.77', 'lng': '106.69'});
        return (200, {'ok': true});
      },
    });
    expect(await api.api().get('/v1/packages', query: {'lat': '10.77', 'lng': '106.69'}), {'ok': true});
    final prefixed = ApiClient(
      baseUrl: Uri.parse('https://h.example/dispatch/'),
      tokens: const StaticIdTokenSource('t'),
    );
    expect(
      prefixed.uriFor('/v1/packages', query: {'cityId': 'hcm'}).toString(),
      'https://h.example/dispatch/v1/packages?cityId=hcm',
    );
    prefixed.close();
  });
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/core/lat_lng_test.dart test/data/instant test/data/http/api_client_test.dart`
Expected: FAIL to compile (`lat_lng.dart`, `instant_models.dart`, `instant_wire.dart` missing; `get` has no `query`). If `package:yaml` is not found, phase 2 Task 9 has not run: `flutter pub add dev:yaml` and re-run.

- [ ] **Step 3: Implement**

```dart
// lib/core/lat_lng.dart
import 'package:photobooking/core/geo.dart';

/// A WGS84 coordinate. Shared by the map widget and the instant flow.
class LatLng {
  const LatLng(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is LatLng && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  /// Redacted like `ApproxLocation`: coordinates never reach a log by accident.
  @override
  String toString() => 'LatLng(<redacted>)';
}

LatLng lerpLatLng(LatLng a, LatLng b, double t) =>
    LatLng(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);

double distanceMeters(LatLng a, LatLng b) =>
    haversineKm(a.lat, a.lng, b.lat, b.lng) * 1000;
```

In `lib/core/core.dart` add `export 'package:photobooking/core/lat_lng.dart';` after the `geo.dart` export.

```dart
// lib/data/instant/instant_models.dart
import 'package:photobooking/core/core.dart';

T? _byCode<T extends Enum>(List<T> values, String? code, String Function(T) codeOf) {
  if (code == null) {
    return null;
  }
  for (final v in values) {
    if (codeOf(v) == code) {
      return v;
    }
  }
  return null;
}

/// `Genre` in services/dispatch/api/openapi.yaml.
enum InstantGenre {
  portrait('portrait'),
  couple('couple'),
  family('family'),
  smallEvent('small_event'),
  product('product');

  const InstantGenre(this.code);
  final String code;
  static InstantGenre? fromCode(String? code) => _byCode(values, code, (v) => v.code);
}

/// `PackageCode`. [minutes] is the shoot length the code stands for; the
/// mirror documents carry only the code.
enum InstantPackageCode {
  p30('p30', 30),
  p60('p60', 60),
  p120('p120', 120);

  const InstantPackageCode(this.code, this.minutes);
  final String code;
  final int minutes;
  static InstantPackageCode? fromCode(String? code) => _byCode(values, code, (v) => v.code);
}

/// `InstantRequestStatus`; transitions are made only by the service.
enum InstantStatus {
  pendingPayment('pending_payment'),
  paymentFailed('payment_failed'),
  searching('searching'),
  assigned('assigned'),
  enRoute('en_route'),
  arrived('arrived'),
  inProgress('in_progress'),
  completed('completed'),
  noMatch('no_match'),
  cancelledByCustomer('cancelled_by_customer'),
  noShowCustomer('no_show_customer'),
  disputed('disputed');

  const InstantStatus(this.code);
  final String code;
  static InstantStatus? fromCode(String? code) => _byCode(values, code, (v) => v.code);

  /// The photographer is on the way: the only time their position is shared.
  bool get onTheWay => this == InstantStatus.assigned || this == InstantStatus.enRoute;

  /// Nothing the apps can change any more.
  bool get isFinal => switch (this) {
    InstantStatus.completed ||
    InstantStatus.noMatch ||
    InstantStatus.cancelledByCustomer ||
    InstantStatus.noShowCustomer ||
    InstantStatus.disputed ||
    InstantStatus.paymentFailed => true,
    _ => false,
  };
}

enum CancelRule {
  freeSearching('free_searching'),
  freeGrace('free_grace'),
  enRouteFee('en_route_fee'),
  noShow('no_show'),
  photographerFault('photographer_fault'),
  photographerCancel('photographer_cancel');

  const CancelRule(this.code);
  final String code;
  static CancelRule? fromCode(String? code) => _byCode(values, code, (v) => v.code);
}

enum DeclineReason {
  tooFar('too_far'),
  busy('busy'),
  genreMismatch('genre_mismatch'),
  other('other');

  const DeclineReason(this.code);
  final String code;
  static DeclineReason? fromCode(String? code) => _byCode(values, code, (v) => v.code);
}

enum PaymentProvider {
  momo('momo'),
  vnpay('vnpay'),
  fake('fake');

  const PaymentProvider(this.code);
  final String code;
  static PaymentProvider? fromCode(String? code) => _byCode(values, code, (v) => v.code);
}

/// `InstantSettings.reasons` items (also `not_eligible.details.reasons`).
enum EligibilityReason {
  profileIncomplete('profile_incomplete'),
  noPhone('no_phone'),
  priceListNotAccepted('price_list_not_accepted'),
  outsideCity('outside_city'),
  locationDenied('location_denied');

  const EligibilityReason(this.code);
  final String code;
  static EligibilityReason? fromCode(String? code) => _byCode(values, code, (v) => v.code);
}

/// `ErrorCode` of the contract, plus codes only this app produces.
enum DispatchError {
  phoneRequired('phone_required'),
  contactLocked('contact_locked'),
  invalidArgument('invalid_argument'),
  permissionDenied('permission_denied'),
  notFound('not_found'),
  conflict('conflict'),
  noMatch('no_match'),
  offerExpired('offer_expired'),
  alreadyAssigned('already_assigned'),
  notEligible('not_eligible'),
  outsideServiceArea('outside_service_area'),
  priceChanged('price_changed'),
  unauthenticated('unauthenticated'),
  internal('internal'),
  network('network', clientOnly: true),
  malformed('malformed', clientOnly: true),
  disabled('disabled', clientOnly: true),
  unknown('unknown', clientOnly: true);

  const DispatchError(this.code, {this.clientOnly = false});
  final String code;

  /// Never sent by the service: no connection, an unexpected body, the
  /// service not configured in this build, or a code this app does not know.
  final bool clientOnly;

  static DispatchError fromCode(String? code) =>
      _byCode(values, code, (v) => v.code) ?? DispatchError.unknown;
}

/// A failed dispatch call. Carries no body and no URL, so nothing private
/// reaches a log.
class DispatchException implements Exception {
  const DispatchException(this.error, {this.status = 0});
  final DispatchError error;
  final int status;

  @override
  String toString() => 'DispatchException(${error.code}, $status)';
}

class MeetPoint {
  const MeetPoint({required this.lat, required this.lng, required this.address});
  final double lat;
  final double lng;
  final String address;

  LatLng get latLng => LatLng(lat, lng);

  @override
  bool operator ==(Object other) =>
      other is MeetPoint && other.lat == lat && other.lng == lng && other.address == address;

  @override
  int get hashCode => Object.hash(lat, lng, address);

  @override
  String toString() => 'MeetPoint(<redacted>)';
}

class LocationFix {
  const LocationFix({
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.at,
    this.headingDeg,
    this.speedMps,
  });

  final double lat;
  final double lng;
  final double accuracyM;
  final DateTime at;
  final double? headingDeg;
  final double? speedMps;

  LatLng get latLng => LatLng(lat, lng);

  (double, double, double, DateTime, double?, double?) get _key =>
      (lat, lng, accuracyM, at, headingDeg, speedMps);

  @override
  bool operator ==(Object other) => other is LocationFix && other._key == _key;

  @override
  int get hashCode => _key.hashCode;

  @override
  String toString() => 'LocationFix(<redacted>)';
}

class InstantPackage {
  const InstantPackage({
    required this.id,
    required this.code,
    required this.durationMin,
    required this.photos,
    required this.priceVnd,
    required this.payoutVnd,
  });
  final String id;
  final InstantPackageCode code;
  final int durationMin;
  final int photos;
  final int priceVnd;
  final int payoutVnd;
}

class PackagesQuote {
  const PackagesQuote({
    required this.cityId,
    required this.cityName,
    required this.priceListVersion,
    required this.surge,
    required this.packages,
    this.typicalMatchMinutes,
  });
  final String cityId;
  final String cityName;
  final int priceListVersion;
  final double surge;
  final int? typicalMatchMinutes;
  final List<InstantPackage> packages;

  InstantPackage? byId(String id) {
    for (final p in packages) {
      if (p.id == id) {
        return p;
      }
    }
    return null;
  }

  InstantPackage? byCode(InstantPackageCode code) {
    for (final p in packages) {
      if (p.code == code) {
        return p;
      }
    }
    return null;
  }
}

class CreatedRequest {
  const CreatedRequest({required this.requestId, required this.amountVnd, required this.paymentUrl});
  final String requestId;
  final int amountVnd;
  final Uri paymentUrl;
}

class CancelQuote {
  const CancelQuote({
    required this.rule,
    required this.refundVnd,
    required this.photographerVnd,
    required this.platformVnd,
    this.graceEndsAt,
  });
  final CancelRule rule;
  final int refundVnd;
  final int photographerVnd;
  final int platformVnd;
  final DateTime? graceEndsAt;

  /// What the customer paid (spec §4: the three parts always add up).
  int get totalVnd => refundVnd + photographerVnd + platformVnd;

  int get refundPercent => totalVnd == 0 ? 100 : (refundVnd * 100 / totalVnd).round();

  (CancelRule, int, int, int, DateTime?) get _key =>
      (rule, refundVnd, photographerVnd, platformVnd, graceEndsAt);

  @override
  bool operator ==(Object other) => other is CancelQuote && other._key == _key;

  @override
  int get hashCode => _key.hashCode;
}

class PresenceState {
  const PresenceState({required this.online, required this.helpReady, this.cityId, this.expiresAt});
  final bool online;
  final bool helpReady;
  final String? cityId;
  final DateTime? expiresAt;
}

class InstantSettings {
  const InstantSettings({
    required this.currentPriceListVersion,
    required this.helpReady,
    required this.eligible,
    required this.reasons,
    this.acceptedPriceListVersion,
  });
  final int? acceptedPriceListVersion;
  final int currentPriceListVersion;
  final bool helpReady;
  final bool eligible;
  final List<EligibilityReason> reasons;

  bool get priceListAccepted => acceptedPriceListVersion == currentPriceListVersion;

  InstantSettings copyWith({int? acceptedPriceListVersion, bool? helpReady, bool? eligible, List<EligibilityReason>? reasons}) =>
      InstantSettings(
        acceptedPriceListVersion: acceptedPriceListVersion ?? this.acceptedPriceListVersion,
        currentPriceListVersion: currentPriceListVersion,
        helpReady: helpReady ?? this.helpReady,
        eligible: eligible ?? this.eligible,
        reasons: reasons ?? this.reasons,
      );
}

class AcceptedJob {
  const AcceptedJob({required this.requestId, required this.meetPoint, required this.customerName});
  final String requestId;
  final MeetPoint meetPoint;
  final String customerName;
}

/// `PhotographerCard` of the mirror (named apart from the 3b2 widget).
class InstantPhotographer {
  const InstantPhotographer({
    required this.uid,
    required this.displayName,
    required this.verified,
    required this.completedShoots,
    this.avatarUrl,
    this.rating,
  });
  final String uid;
  final String displayName;
  final String? avatarUrl;
  final bool verified;
  final double? rating;
  final int completedShoots;
}

/// `InstantRequestMirror` (`instant_requests/{id}`), read-only.
class InstantRequestView {
  const InstantRequestView({
    required this.id,
    required this.status,
    required this.customerId,
    required this.packageCode,
    required this.genre,
    required this.amountVnd,
    required this.expand,
    required this.round,
    required this.requestedAt,
    required this.updatedAt,
    this.photographerId,
    this.photographer,
    this.radiusKm,
    this.searchEndsAt,
    this.etaMinutes,
    this.etaEstimated = false,
    this.graceEndsAt,
    this.meetPoint,
    this.assignedAt,
    this.arrivedAt,
    this.startedAt,
    this.finishedAt,
    this.refundVnd,
  });

  final String id;
  final InstantStatus status;
  final String customerId;
  final String? photographerId;
  final InstantPhotographer? photographer;
  final InstantPackageCode packageCode;
  final InstantGenre genre;
  final int amountVnd;
  final bool expand;
  final int round;
  final int? radiusKm;
  final DateTime? searchEndsAt;
  final int? etaMinutes;
  final bool etaEstimated;
  final DateTime? graceEndsAt;
  final MeetPoint? meetPoint;
  final DateTime requestedAt;
  final DateTime? assignedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int? refundVnd;
  final DateTime updatedAt;

  int get durationMin => packageCode.minutes;
}

/// `InstantTrackMirror` (`instant_tracks/{id}`): the latest point while en route.
class InstantTrack {
  const InstantTrack({required this.lat, required this.lng, required this.accuracyM, required this.at, this.headingDeg});
  final double lat;
  final double lng;
  final double accuracyM;
  final double? headingDeg;
  final DateTime at;

  LatLng get latLng => LatLng(lat, lng);
}

/// `InstantOfferMirror` (`instant_offers/{uid}`): area and distance only.
class InstantOffer {
  const InstantOffer({
    required this.offerId,
    required this.requestId,
    required this.packageCode,
    required this.genre,
    required this.payoutVnd,
    required this.distanceKm,
    required this.travelMinutes,
    required this.area,
    required this.expiresAt,
    this.note,
  });
  final String offerId;
  final String requestId;
  final InstantPackageCode packageCode;
  final InstantGenre genre;
  final int payoutVnd;
  final double distanceKm;
  final int travelMinutes;
  final String area;
  final String? note;
  final DateTime expiresAt;

  Duration remaining(DateTime now) {
    final d = expiresAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);
}
```

```dart
// lib/data/instant/instant_wire.dart
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/instant/instant_models.dart';

/// Paths of services/dispatch/api/openapi.yaml.
abstract final class DispatchPaths {
  static const health = '/v1/health';
  static const packages = '/v1/packages';
  static const requests = '/v1/requests';
  static String _request(String id) => '/v1/requests/${Uri.encodeComponent(id)}';
  static String cancel(String id) => '${_request(id)}/cancel';
  static String confirmComplete(String id) => '${_request(id)}/confirm-complete';
  static String location(String id) => '${_request(id)}/location';
  static String arrive(String id) => '${_request(id)}/arrive';
  static String start(String id) => '${_request(id)}/start';
  static String finish(String id) => '${_request(id)}/finish';
  static const presence = '/v1/presence';
  static const instantSettings = '/v1/instant-settings';
  static String _offer(String id) => '/v1/offers/${Uri.encodeComponent(id)}';
  static String accept(String id) => '${_offer(id)}/accept';
  static String decline(String id) => '${_offer(id)}/decline';
  static String devPaymentSucceed(String id) =>
      '/v1/dev/payments/${Uri.encodeComponent(id)}/succeed';
}

/// Every (method, contract path) the app calls; dispatch_contract_test.dart
/// checks each against openapi.yaml. The payment webhook is server-to-server.
const dispatchOperations = <(String, String)>[
  ('GET', '/v1/health'),
  ('GET', '/v1/packages'),
  ('POST', '/v1/requests'),
  ('POST', '/v1/requests/{requestId}/cancel'),
  ('POST', '/v1/requests/{requestId}/confirm-complete'),
  ('POST', '/v1/requests/{requestId}/location'),
  ('POST', '/v1/requests/{requestId}/arrive'),
  ('POST', '/v1/requests/{requestId}/start'),
  ('POST', '/v1/requests/{requestId}/finish'),
  ('PUT', '/v1/presence'),
  ('GET', '/v1/instant-settings'),
  ('PUT', '/v1/instant-settings'),
  ('POST', '/v1/offers/{offerId}/accept'),
  ('POST', '/v1/offers/{offerId}/decline'),
  ('POST', '/v1/dev/payments/{requestId}/succeed'),
];

/// Turns an [ApiException] into a [DispatchException] with the contract code.
Future<T> dispatchGuard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on ApiException catch (e) {
    throw DispatchException(DispatchError.fromCode(e.code), status: e.status);
  }
}

Never _bad() => throw const DispatchException(DispatchError.malformed);

Map<String, dynamic> _obj(Object? json) =>
    json is Map ? json.cast<String, dynamic>() : _bad();

String _str(Map<String, dynamic> m, String k) => m[k] is String ? m[k] as String : _bad();

String? _strOrNull(Map<String, dynamic> m, String k) =>
    m[k] == null ? null : (m[k] is String ? m[k] as String : _bad());

int _int(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v is int) {
    return v;
  }
  if (v is num && v == v.roundToDouble()) {
    return v.toInt();
  }
  _bad();
}

int? _intOrNull(Map<String, dynamic> m, String k) => m[k] == null ? null : _int(m, k);

double _num(Map<String, dynamic> m, String k) => m[k] is num ? (m[k] as num).toDouble() : _bad();

double? _numOrNull(Map<String, dynamic> m, String k) => m[k] == null ? null : _num(m, k);

bool _bool(Map<String, dynamic> m, String k) => m[k] is bool ? m[k] as bool : _bad();

T _enum<T>(T? value) => value ?? _bad();

DateTime? _instantOrNull(Object? v) {
  if (v == null) {
    return null;
  }
  if (v is DateTime) {
    return v.toUtc();
  }
  if (v is String) {
    return DateTime.tryParse(v)?.toUtc() ?? _bad();
  }
  _bad();
}

DateTime _instant(Map<String, dynamic> m, String k) => _instantOrNull(m[k]) ?? _bad();

/// ISO 8601 in UTC with milliseconds, e.g. `2026-10-01T08:30:00.000Z`.
String isoUtc(DateTime t) => t.toUtc().toIso8601String();

MeetPoint _meetPoint(Object? json) {
  final m = _obj(json);
  return MeetPoint(lat: _num(m, 'lat'), lng: _num(m, 'lng'), address: _str(m, 'address'));
}

Map<String, Object?> _meetPointJson(MeetPoint p) => {'lat': p.lat, 'lng': p.lng, 'address': p.address};

PackagesQuote packagesQuoteFromJson(Object? json) {
  final m = _obj(json);
  final list = m['packages'] is List ? m['packages'] as List : _bad();
  return PackagesQuote(
    cityId: _str(m, 'cityId'),
    cityName: _str(m, 'cityName'),
    priceListVersion: _int(m, 'priceListVersion'),
    surge: _num(m, 'surge'),
    typicalMatchMinutes: _intOrNull(m, 'typicalMatchMinutes'),
    packages: [
      for (final raw in list)
        () {
          final p = _obj(raw);
          return InstantPackage(
            id: _str(p, 'id'),
            code: _enum(InstantPackageCode.fromCode(p['code'] as String?)),
            durationMin: _int(p, 'durationMin'),
            photos: _int(p, 'photos'),
            priceVnd: _int(p, 'priceVnd'),
            payoutVnd: _int(p, 'payoutVnd'),
          );
        }(),
    ],
  );
}

Map<String, Object?> createRequestBody({
  required String packageId,
  required InstantGenre genre,
  required MeetPoint meetPoint,
  required String note,
  required bool expand,
  required int expectedAmountVnd,
  required PaymentProvider provider,
}) => {
  'packageId': packageId,
  'genre': genre.code,
  'meetPoint': _meetPointJson(meetPoint),
  if (note.trim().isNotEmpty) 'note': note.trim(),
  'expand': expand,
  'expectedAmountVnd': expectedAmountVnd,
  'provider': provider.code,
};

CreatedRequest createdRequestFromJson(Object? json) {
  final m = _obj(json);
  return CreatedRequest(
    requestId: _str(m, 'requestId'),
    amountVnd: _int(m, 'amountVnd'),
    paymentUrl: Uri.tryParse(_str(m, 'paymentUrl')) ?? _bad(),
  );
}

Map<String, Object?> cancelBody({required bool dryRun, String? reason}) => {
  'dryRun': dryRun,
  if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
};

CancelQuote cancelQuoteFromJson(Object? json) {
  final m = _obj(json);
  return CancelQuote(
    rule: _enum(CancelRule.fromCode(m['rule'] as String?)),
    refundVnd: _int(m, 'refundVnd'),
    photographerVnd: _int(m, 'photographerVnd'),
    platformVnd: _int(m, 'platformVnd'),
    graceEndsAt: _instantOrNull(m['graceEndsAt']),
  );
}

Map<String, Object?> locationFixToJson(LocationFix f) => {
  'lat': f.lat,
  'lng': f.lng,
  'accuracyM': f.accuracyM,
  if (f.headingDeg != null) 'headingDeg': f.headingDeg,
  if (f.speedMps != null) 'speedMps': f.speedMps,
  'at': isoUtc(f.at),
};

Map<String, Object?> arriveBody({required LocationFix fix, bool force = false, String? reason}) => {
  'fix': locationFixToJson(fix),
  'force': force,
  if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
};

Map<String, Object?> presenceBody({required bool online, bool? helpReady, LocationFix? fix}) => {
  'online': online,
  if (helpReady != null) 'helpReady': helpReady,
  if (fix != null) 'fix': locationFixToJson(fix),
};

PresenceState presenceFromJson(Object? json) {
  final m = _obj(json);
  return PresenceState(
    online: _bool(m, 'online'),
    helpReady: _bool(m, 'helpReady'),
    cityId: _strOrNull(m, 'cityId'),
    expiresAt: _instantOrNull(m['expiresAt']),
  );
}

Map<String, Object?> settingsBody({int? acceptPriceListVersion, bool? helpReady}) => {
  if (acceptPriceListVersion != null) 'acceptPriceListVersion': acceptPriceListVersion,
  if (helpReady != null) 'helpReady': helpReady,
};

InstantSettings settingsFromJson(Object? json) {
  final m = _obj(json);
  final reasons = m['reasons'] is List ? m['reasons'] as List : _bad();
  return InstantSettings(
    acceptedPriceListVersion: _intOrNull(m, 'acceptedPriceListVersion'),
    currentPriceListVersion: _int(m, 'currentPriceListVersion'),
    helpReady: _bool(m, 'helpReady'),
    eligible: _bool(m, 'eligible'),
    reasons: [for (final r in reasons) _enum(EligibilityReason.fromCode(r is String ? r : null))],
  );
}

AcceptedJob acceptedJobFromJson(Object? json) {
  final m = _obj(json);
  return AcceptedJob(
    requestId: _str(m, 'requestId'),
    meetPoint: _meetPoint(m['meetPoint']),
    customerName: _str(m, 'customerName'),
  );
}

Map<String, Object?> declineBody(DeclineReason? reason) => {
  if (reason != null) 'reason': reason.code,
};

InstantPhotographer _photographer(Object? json) {
  final m = _obj(json);
  return InstantPhotographer(
    uid: _str(m, 'uid'),
    displayName: _str(m, 'displayName'),
    avatarUrl: _strOrNull(m, 'avatarUrl'),
    verified: _bool(m, 'verified'),
    rating: _numOrNull(m, 'rating'),
    completedShoots: _int(m, 'completedShoots'),
  );
}

/// [m] is a plain map: the Firestore adapter turns Timestamps into DateTime
/// before calling this; ISO strings are accepted too.
InstantRequestView requestViewFromMap(Map<String, dynamic> m, {String id = ''}) => InstantRequestView(
  id: id,
  status: _enum(InstantStatus.fromCode(m['status'] as String?)),
  customerId: _str(m, 'customerId'),
  photographerId: _strOrNull(m, 'photographerId'),
  photographer: m['photographer'] == null ? null : _photographer(m['photographer']),
  packageCode: _enum(InstantPackageCode.fromCode(m['packageCode'] as String?)),
  genre: _enum(InstantGenre.fromCode(m['genre'] as String?)),
  amountVnd: _int(m, 'amountVnd'),
  expand: _bool(m, 'expand'),
  round: _int(m, 'round'),
  radiusKm: _intOrNull(m, 'radiusKm'),
  searchEndsAt: _instantOrNull(m['searchEndsAt']),
  etaMinutes: _intOrNull(m, 'etaMinutes'),
  etaEstimated: m['etaEstimated'] == true,
  graceEndsAt: _instantOrNull(m['graceEndsAt']),
  meetPoint: m['meetPoint'] == null ? null : _meetPoint(m['meetPoint']),
  requestedAt: _instant(m, 'requestedAt'),
  assignedAt: _instantOrNull(m['assignedAt']),
  arrivedAt: _instantOrNull(m['arrivedAt']),
  startedAt: _instantOrNull(m['startedAt']),
  finishedAt: _instantOrNull(m['finishedAt']),
  refundVnd: _intOrNull(m, 'refundVnd'),
  updatedAt: _instant(m, 'updatedAt'),
);

InstantTrack trackFromMap(Map<String, dynamic> m) => InstantTrack(
  lat: _num(m, 'lat'),
  lng: _num(m, 'lng'),
  accuracyM: _num(m, 'accuracyM'),
  headingDeg: _numOrNull(m, 'headingDeg'),
  at: _instant(m, 'at'),
);

InstantOffer offerFromMap(Map<String, dynamic> m) => InstantOffer(
  offerId: _str(m, 'offerId'),
  requestId: _str(m, 'requestId'),
  packageCode: _enum(InstantPackageCode.fromCode(m['packageCode'] as String?)),
  genre: _enum(InstantGenre.fromCode(m['genre'] as String?)),
  payoutVnd: _int(m, 'payoutVnd'),
  distanceKm: _num(m, 'distanceKm'),
  travelMinutes: _int(m, 'travelMinutes'),
  area: _str(m, 'area'),
  note: _strOrNull(m, 'note'),
  expiresAt: _instant(m, 'expiresAt'),
);
```

In `lib/data/http/api_client.dart` (phase 2) make three backwards-compatible edits:

1. Replace `Future<Object?> get(String path) => _send('GET', path);` with
   ```dart
   Future<Object?> get(String path, {Map<String, String>? query}) =>
       _send('GET', path, null, query);
   ```
2. Replace the whole `uriFor` method with
   ```dart
   Uri uriFor(String path, {Map<String, String>? query}) {
     final prefix = _base.path.endsWith('/')
         ? _base.path.substring(0, _base.path.length - 1)
         : _base.path;
     return _base.replace(
       path: '$prefix$path',
       queryParameters: query == null || query.isEmpty ? null : query,
     );
   }
   ```
3. Give `_send` a fourth optional parameter and pass it through: change its signature to `Future<Object?> _send(String method, String path, [Map<String, Object?>? body, Map<String, String>? query]) async {`, change both `_once(method, path, body, forceRefresh: …)` calls to `_once(method, path, body, query: query, forceRefresh: …)`, change `_once`'s signature to `Future<http.Response> _once(String method, String path, Map<String, Object?>? body, {Map<String, String>? query, required bool forceRefresh}) async {`, and inside `_once` build the request with `http.Request(method, uriFor(path, query: query))`.

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/core/lat_lng_test.dart test/data/instant test/data/http && flutter analyze`
Expected: PASS (3 + 10 + 5 new tests; the phase 2 HTTP tests still pass); analyze clean. If the contract test reports an enum or key mismatch, the Dart side is wrong: fix `instant_models.dart`/`instant_wire.dart`, never the YAML.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core/lat_lng.dart lib/core/core.dart lib/data/instant lib/data/http/api_client.dart test/core/lat_lng_test.dart test/data/instant test/data/http/api_client_test.dart pubspec.yaml pubspec.lock
git commit -m "feat(instant): dispatch wire format checked against the openapi contract

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `DispatchConfig`, `PresenceRepository` and `InstantJobRepository`

**Files:**
- Create: `lib/data/instant/dispatch_config.dart`, `lib/data/instant/instant_repositories.dart`, `lib/data/instant/http_instant_repositories.dart`, `lib/data/instant/fake_instant_repositories.dart`, `lib/data/instant/instant_providers.dart`, `test/data/instant/dispatch_config_test.dart`, `test/data/instant/http_instant_repositories_test.dart`, `test/data/instant/fake_instant_repositories_test.dart`

**Interfaces:**
- Consumes: Task 1; `ApiClient`, `idTokenSourceProvider` (`lib/data/http/api_providers.dart`), `MockApi`, `apiError`.
- Produces:
  - `class DispatchConfig { const DispatchConfig.disabled(); factory DispatchConfig.parse(String url, {bool release = kReleaseMode}); factory DispatchConfig.fromEnvironment(); final Uri? baseUrl; bool get enabled; }` (dart-define `DISPATCH_URL`; empty = disabled; release needs https).
  - `abstract class PresenceRepository { Future<PresenceState> setPresence({required bool online, bool? helpReady, LocationFix? fix}); Future<InstantSettings> settings(); Future<InstantSettings> updateSettings({int? acceptPriceListVersion, bool? helpReady}); Future<PackagesQuote> packagesNear(LatLng at); }`
  - `abstract class InstantJobRepository { Future<AcceptedJob> accept(String offerId); Future<void> decline(String offerId, {DeclineReason? reason}); Future<void> postLocation(String requestId, LocationFix fix); Future<void> arrive(String requestId, {required LocationFix fix, bool force = false, String? reason}); Future<void> start(String requestId); Future<void> finish(String requestId); Future<CancelQuote> cancel(String requestId, {required bool dryRun, String? reason}); }`
  - `HttpPresenceRepository({required ApiClient api})`, `HttpInstantJobRepository({required ApiClient api})`, `DisabledDispatch` (implements both; every call throws `DispatchException(DispatchError.disabled)`).
  - `FakePresenceRepository({InstantSettings? settings, PackagesQuote? packages})` with `settingsValue`, `packagesValue`, `presenceCalls` (`List<PresenceCall>`), `settingsCalls`, `packagesCalls`, `failPresenceWith`, `failSettingsWith`; `FakeInstantJobRepository` with `calls` (`List<String>`), `posted` (`List<LocationFix>`), `job` (the `AcceptedJob` returned by accept), `acceptError`, `arriveError`, `postError`, `quote`, `cancelError`.
  - Providers (`instant_providers.dart`): `dispatchConfigProvider`, `dispatchApiClientProvider` (`Provider<ApiClient?>`, null when disabled), `presenceRepositoryProvider`, `instantJobRepositoryProvider`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/instant/dispatch_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/dispatch_config.dart';

void main() {
  test('empty means the feature is off in this build', () {
    expect(DispatchConfig.parse('').enabled, isFalse);
  });

  test('an http(s) URL turns it on', () {
    final c = DispatchConfig.parse('http://10.0.2.2:8090', release: false);
    expect(c.enabled, isTrue);
    expect(c.baseUrl, Uri.parse('http://10.0.2.2:8090'));
  });

  test('bad values fail loudly; release builds need https', () {
    expect(() => DispatchConfig.parse('ftp://x'), throwsArgumentError);
    expect(() => DispatchConfig.parse('not a url'), throwsArgumentError);
    expect(() => DispatchConfig.parse('http://x', release: true), throwsArgumentError);
    expect(DispatchConfig.parse('https://dispatch.example.vn', release: true).enabled, isTrue);
  });
}
```

```dart
// test/data/instant/http_instant_repositories_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/http_instant_repositories.dart';
import 'package:photobooking/data/instant/instant_models.dart';

import '../http/mock_api.dart';

final _fix = LocationFix(lat: 10.77, lng: 106.69, accuracyM: 9, at: DateTime.utc(2026, 10, 1, 8));

const _settings = {
  'acceptedPriceListVersion': 3,
  'currentPriceListVersion': 3,
  'helpReady': true,
  'eligible': true,
  'reasons': <String>[],
};

void main() {
  group('HttpPresenceRepository', () {
    test('PUT /v1/presence sends the fix and reads the TTL', () async {
      final api = MockApi({
        'PUT /v1/presence': (r) {
          final body = jsonDecode(r.body) as Map<String, Object?>;
          expect(body['online'], true);
          expect((body['fix']! as Map)['accuracyM'], 9);
          return (200, {'online': true, 'helpReady': false, 'cityId': 'hcm', 'expiresAt': '2026-10-01T08:10:00.000Z'});
        },
      });
      final p = await HttpPresenceRepository(api: api.api()).setPresence(online: true, fix: _fix);
      expect(p.expiresAt, DateTime.utc(2026, 10, 1, 8, 10));
    });

    test('not_eligible is a DispatchException with that code', () async {
      final api = MockApi({'PUT /v1/presence': (_) => (422, apiError('not_eligible'))});
      await expectLater(
        HttpPresenceRepository(api: api.api()).setPresence(online: true),
        throwsA(isA<DispatchException>().having((e) => e.error, 'error', DispatchError.notEligible)),
      );
    });

    test('settings: GET, then PUT with the accepted version', () async {
      final api = MockApi({
        'GET /v1/instant-settings': (_) => (200, _settings),
        'PUT /v1/instant-settings': (r) {
          expect(jsonDecode(r.body), {'acceptPriceListVersion': 3});
          return (200, _settings);
        },
      });
      final repo = HttpPresenceRepository(api: api.api());
      expect((await repo.settings()).priceListAccepted, isTrue);
      await repo.updateSettings(acceptPriceListVersion: 3);
      expect(api.calls, ['GET /v1/instant-settings', 'PUT /v1/instant-settings']);
    });

    test('packagesNear sends lat and lng as query parameters', () async {
      final api = MockApi({
        'GET /v1/packages': (r) {
          expect(r.url.queryParameters, {'lat': '10.77', 'lng': '106.69'});
          return (200, {'cityId': 'hcm', 'cityName': 'TP. Hồ Chí Minh', 'priceListVersion': 3, 'surge': 1.0, 'packages': <Object>[]});
        },
      });
      final q = await HttpPresenceRepository(api: api.api()).packagesNear(const LatLng(10.77, 106.69));
      expect(q.cityName, 'TP. Hồ Chí Minh');
    });
  });

  group('HttpInstantJobRepository', () {
    test('accept returns the exact meet point; offer_expired and already_assigned map', () async {
      final api = MockApi({
        'POST /v1/offers/O1/accept': (_) => (200, {
          'requestId': 'R1',
          'meetPoint': {'lat': 10.77, 'lng': 106.69, 'address': '55C Nguyễn Thị Minh Khai'},
          'customerName': 'Lan Anh',
        }),
        'POST /v1/offers/O2/accept': (_) => (409, apiError('offer_expired')),
        'POST /v1/offers/O3/accept': (_) => (409, apiError('already_assigned')),
      });
      final repo = HttpInstantJobRepository(api: api.api());
      expect((await repo.accept('O1')).customerName, 'Lan Anh');
      Matcher error(DispatchError e) => throwsA(isA<DispatchException>().having((x) => x.error, 'error', e));
      await expectLater(repo.accept('O2'), error(DispatchError.offerExpired));
      await expectLater(repo.accept('O3'), error(DispatchError.alreadyAssigned));
    });

    test('decline sends the optional reason', () async {
      final bodies = <Object?>[];
      final api = MockApi({
        'POST /v1/offers/O1/decline': (r) {
          bodies.add(jsonDecode(r.body));
          return (204, null);
        },
      });
      final repo = HttpInstantJobRepository(api: api.api());
      await repo.decline('O1');
      await repo.decline('O1', reason: DeclineReason.busy);
      expect(bodies, [<String, Object?>{}, {'reason': 'busy'}]);
    });

    test('location, arrive (force with reason), start, finish', () async {
      final api = MockApi({
        'POST /v1/requests/R1/location': (r) {
          expect((jsonDecode(r.body) as Map)['at'], '2026-10-01T08:00:00.000Z');
          return (204, null);
        },
        'POST /v1/requests/R1/arrive': (r) {
          final b = jsonDecode(r.body) as Map;
          expect(b['force'], true);
          expect(b['reason'], 'GPS yếu');
          return (204, null);
        },
        'POST /v1/requests/R1/start': (_) => (204, null),
        'POST /v1/requests/R1/finish': (_) => (204, null),
      });
      final repo = HttpInstantJobRepository(api: api.api());
      await repo.postLocation('R1', _fix);
      await repo.arrive('R1', fix: _fix, force: true, reason: 'GPS yếu');
      await repo.start('R1');
      await repo.finish('R1');
      expect(api.calls, [
        'POST /v1/requests/R1/location',
        'POST /v1/requests/R1/arrive',
        'POST /v1/requests/R1/start',
        'POST /v1/requests/R1/finish',
      ]);
    });

    test('a 429 on location is a DispatchException the caller can ignore', () async {
      final api = MockApi({'POST /v1/requests/R1/location': (_) => (429, apiError('conflict'))});
      await expectLater(
        HttpInstantJobRepository(api: api.api()).postLocation('R1', _fix),
        throwsA(isA<DispatchException>().having((e) => e.status, 'status', 429)),
      );
    });

    test('cancel dry run returns the quote', () async {
      final api = MockApi({
        'POST /v1/requests/R1/cancel': (r) {
          expect(jsonDecode(r.body), {'dryRun': true});
          return (200, {'rule': 'photographer_cancel', 'refundVnd': 690000, 'photographerVnd': 0, 'platformVnd': 0, 'graceEndsAt': null});
        },
      });
      final q = await HttpInstantJobRepository(api: api.api()).cancel('R1', dryRun: true);
      expect(q.rule, CancelRule.photographerCancel);
      expect(q.refundVnd, 690000);
    });
  });

  test('DisabledDispatch refuses every call with "disabled"', () async {
    const d = DisabledDispatch();
    await expectLater(
      d.settings(),
      throwsA(isA<DispatchException>().having((e) => e.error, 'error', DispatchError.disabled)),
    );
    await expectLater(d.accept('O1'), throwsA(isA<DispatchException>()));
  });
}
```

```dart
// test/data/instant/fake_instant_repositories_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/fake_instant_repositories.dart';
import 'package:photobooking/data/instant/instant_models.dart';

void main() {
  test('fake presence records calls and can refuse', () async {
    final repo = FakePresenceRepository();
    await repo.setPresence(online: true, helpReady: false);
    expect(repo.presenceCalls.single.online, isTrue);
    repo.failPresenceWith = DispatchError.notEligible;
    await expectLater(repo.setPresence(online: true), throwsA(isA<DispatchException>()));
    expect(repo.presenceCalls, hasLength(2));
  });

  test('fake settings accept the price list', () async {
    final repo = FakePresenceRepository();
    expect(repo.settingsValue.priceListAccepted, isFalse);
    final s = await repo.updateSettings(acceptPriceListVersion: repo.settingsValue.currentPriceListVersion);
    expect(s.priceListAccepted, isTrue);
    expect(s.reasons, isNot(contains(EligibilityReason.priceListNotAccepted)));
  });

  test('fake jobs record every call in order', () async {
    final repo = FakeInstantJobRepository();
    final job = await repo.accept('O1');
    await repo.postLocation(job.requestId, LocationFix(lat: 1, lng: 2, accuracyM: 5, at: DateTime.utc(2026)));
    await repo.arrive(job.requestId, fix: repo.posted.single, force: true);
    expect(repo.calls, ['accept O1', 'location R1', 'arrive R1 force']);
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/data/instant`
Expected: FAIL to compile, the new files do not exist.

- [ ] **Step 3: Implement**

```dart
// lib/data/instant/dispatch_config.dart
import 'package:flutter/foundation.dart';

/// Where the dispatch service is. Set at build time:
/// `--dart-define=DISPATCH_URL=http://10.0.2.2:8090` (emulator → host).
/// Empty: Chụp ngay is not offered in this build.
class DispatchConfig {
  const DispatchConfig.disabled() : baseUrl = null;
  const DispatchConfig._(this.baseUrl);

  factory DispatchConfig.parse(String url, {bool release = kReleaseMode}) {
    if (url.isEmpty) {
      return const DispatchConfig.disabled();
    }
    final uri = Uri.tryParse(url);
    final ok = uri != null && (uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty;
    if (!ok) {
      throw ArgumentError.value(url, 'DISPATCH_URL', 'must be an http(s) URL');
    }
    if (release && !uri.isScheme('https')) {
      throw ArgumentError.value(url, 'DISPATCH_URL', 'release builds need https');
    }
    return DispatchConfig._(uri);
  }

  factory DispatchConfig.fromEnvironment() =>
      DispatchConfig.parse(const String.fromEnvironment('DISPATCH_URL'));

  final Uri? baseUrl;
  bool get enabled => baseUrl != null;
}
```

```dart
// lib/data/instant/instant_repositories.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';

/// Photographer availability (S14.01). Errors are [DispatchException]s.
abstract class PresenceRepository {
  /// `PUT /v1/presence`; `not_eligible` when a condition is missing.
  Future<PresenceState> setPresence({required bool online, bool? helpReady, LocationFix? fix});

  Future<InstantSettings> settings();

  Future<InstantSettings> updateSettings({int? acceptPriceListVersion, bool? helpReady});

  /// Package price list (customer price and payout) of the city at [at].
  Future<PackagesQuote> packagesNear(LatLng at);
}

/// One offer and the job it becomes (S14.02, S14.03, S13.08).
abstract class InstantJobRepository {
  /// `offer_expired` or `already_assigned` when another photographer won.
  Future<AcceptedJob> accept(String offerId);
  Future<void> decline(String offerId, {DeclineReason? reason});

  /// While en route only; the service accepts at most one per 5 s (429).
  Future<void> postLocation(String requestId, LocationFix fix);

  /// The service checks ≤ 200 m, or logs [force] with [reason].
  Future<void> arrive(String requestId, {required LocationFix fix, bool force = false, String? reason});
  Future<void> start(String requestId);
  Future<void> finish(String requestId);
  Future<CancelQuote> cancel(String requestId, {required bool dryRun, String? reason});
}
```

```dart
// lib/data/instant/http_instant_repositories.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_repositories.dart';
import 'package:photobooking/data/instant/instant_wire.dart';

class HttpPresenceRepository implements PresenceRepository {
  HttpPresenceRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  @override
  Future<PresenceState> setPresence({required bool online, bool? helpReady, LocationFix? fix}) =>
      dispatchGuard(() async => presenceFromJson(
        await _api.put(DispatchPaths.presence, presenceBody(online: online, helpReady: helpReady, fix: fix)),
      ));

  @override
  Future<InstantSettings> settings() =>
      dispatchGuard(() async => settingsFromJson(await _api.get(DispatchPaths.instantSettings)));

  @override
  Future<InstantSettings> updateSettings({int? acceptPriceListVersion, bool? helpReady}) =>
      dispatchGuard(() async => settingsFromJson(
        await _api.put(
          DispatchPaths.instantSettings,
          settingsBody(acceptPriceListVersion: acceptPriceListVersion, helpReady: helpReady),
        ),
      ));

  @override
  Future<PackagesQuote> packagesNear(LatLng at) => dispatchGuard(() async => packagesQuoteFromJson(
    await _api.get(DispatchPaths.packages, query: {'lat': '${at.lat}', 'lng': '${at.lng}'}),
  ));
}

class HttpInstantJobRepository implements InstantJobRepository {
  HttpInstantJobRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  @override
  Future<AcceptedJob> accept(String offerId) => dispatchGuard(
    () async => acceptedJobFromJson(await _api.post(DispatchPaths.accept(offerId), const {})),
  );

  @override
  Future<void> decline(String offerId, {DeclineReason? reason}) =>
      dispatchGuard(() => _api.post(DispatchPaths.decline(offerId), declineBody(reason)));

  @override
  Future<void> postLocation(String requestId, LocationFix fix) =>
      dispatchGuard(() => _api.post(DispatchPaths.location(requestId), locationFixToJson(fix)));

  @override
  Future<void> arrive(String requestId, {required LocationFix fix, bool force = false, String? reason}) =>
      dispatchGuard(() => _api.post(
        DispatchPaths.arrive(requestId),
        arriveBody(fix: fix, force: force, reason: reason),
      ));

  @override
  Future<void> start(String requestId) =>
      dispatchGuard(() => _api.post(DispatchPaths.start(requestId), const {}));

  @override
  Future<void> finish(String requestId) =>
      dispatchGuard(() => _api.post(DispatchPaths.finish(requestId), const {}));

  @override
  Future<CancelQuote> cancel(String requestId, {required bool dryRun, String? reason}) =>
      dispatchGuard(() async => cancelQuoteFromJson(
        await _api.post(DispatchPaths.cancel(requestId), cancelBody(dryRun: dryRun, reason: reason)),
      ));
}

/// Used when `DISPATCH_URL` is empty: the feature is hidden, and any call
/// that slips through fails with [DispatchError.disabled].
class DisabledDispatch implements PresenceRepository, InstantJobRepository {
  const DisabledDispatch();

  Never _off() => throw const DispatchException(DispatchError.disabled);

  @override
  Future<PresenceState> setPresence({required bool online, bool? helpReady, LocationFix? fix}) async => _off();
  @override
  Future<InstantSettings> settings() async => _off();
  @override
  Future<InstantSettings> updateSettings({int? acceptPriceListVersion, bool? helpReady}) async => _off();
  @override
  Future<PackagesQuote> packagesNear(LatLng at) async => _off();
  @override
  Future<AcceptedJob> accept(String offerId) async => _off();
  @override
  Future<void> decline(String offerId, {DeclineReason? reason}) async => _off();
  @override
  Future<void> postLocation(String requestId, LocationFix fix) async => _off();
  @override
  Future<void> arrive(String requestId, {required LocationFix fix, bool force = false, String? reason}) async => _off();
  @override
  Future<void> start(String requestId) async => _off();
  @override
  Future<void> finish(String requestId) async => _off();
  @override
  Future<CancelQuote> cancel(String requestId, {required bool dryRun, String? reason}) async => _off();
}
```

```dart
// lib/data/instant/fake_instant_repositories.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_repositories.dart';

typedef PresenceCall = ({bool online, bool? helpReady, LocationFix? fix});

/// The price list the fakes and tests use (mock S14.01 values).
PackagesQuote fakePackagesQuote({int version = 3, int? typicalMatchMinutes = 4}) => PackagesQuote(
  cityId: 'hcm',
  cityName: 'TP. Hồ Chí Minh',
  priceListVersion: version,
  surge: 1.0,
  typicalMatchMinutes: typicalMatchMinutes,
  packages: const [
    InstantPackage(id: 'PK30', code: InstantPackageCode.p30, durationMin: 30, photos: 15, priceVnd: 390000, payoutVnd: 312000),
    InstantPackage(id: 'PK60', code: InstantPackageCode.p60, durationMin: 60, photos: 30, priceVnd: 690000, payoutVnd: 552000),
    InstantPackage(id: 'PK120', code: InstantPackageCode.p120, durationMin: 120, photos: 60, priceVnd: 1190000, payoutVnd: 952000),
  ],
);

class FakePresenceRepository implements PresenceRepository {
  FakePresenceRepository({InstantSettings? settings, PackagesQuote? packages})
    : settingsValue = settings ??
          const InstantSettings(
            currentPriceListVersion: 3,
            helpReady: false,
            eligible: false,
            reasons: [EligibilityReason.priceListNotAccepted],
          ),
      packagesValue = packages ?? fakePackagesQuote();

  InstantSettings settingsValue;
  PackagesQuote packagesValue;
  final presenceCalls = <PresenceCall>[];
  int settingsCalls = 0;
  int packagesCalls = 0;
  DispatchError? failPresenceWith;
  DispatchError? failSettingsWith;

  @override
  Future<PresenceState> setPresence({required bool online, bool? helpReady, LocationFix? fix}) async {
    presenceCalls.add((online: online, helpReady: helpReady, fix: fix));
    final fail = failPresenceWith;
    if (fail != null && online) {
      throw DispatchException(fail, status: 422);
    }
    return PresenceState(online: online, helpReady: helpReady ?? settingsValue.helpReady, cityId: 'hcm');
  }

  @override
  Future<InstantSettings> settings() async {
    settingsCalls++;
    final fail = failSettingsWith;
    if (fail != null) {
      throw DispatchException(fail);
    }
    return settingsValue;
  }

  @override
  Future<InstantSettings> updateSettings({int? acceptPriceListVersion, bool? helpReady}) async {
    var s = settingsValue;
    if (acceptPriceListVersion != null) {
      final reasons = [...s.reasons]..remove(EligibilityReason.priceListNotAccepted);
      s = s.copyWith(acceptedPriceListVersion: acceptPriceListVersion, reasons: reasons, eligible: reasons.isEmpty);
    }
    if (helpReady != null) {
      s = s.copyWith(helpReady: helpReady);
    }
    return settingsValue = s;
  }

  @override
  Future<PackagesQuote> packagesNear(LatLng at) async {
    packagesCalls++;
    return packagesValue;
  }
}

class FakeInstantJobRepository implements InstantJobRepository {
  FakeInstantJobRepository({AcceptedJob? job})
    : job = job ??
          const AcceptedJob(
            requestId: 'R1',
            meetPoint: MeetPoint(lat: 10.7745, lng: 106.6926, address: 'Cổng Trương Định, Công viên Tao Đàn, 55C Nguyễn Thị Minh Khai, Quận 1'),
            customerName: 'Lan Anh',
          );

  AcceptedJob job;
  final calls = <String>[];
  final posted = <LocationFix>[];
  final postedAt = <DateTime>[];
  DateTime Function()? clock;
  DispatchError? acceptError;
  DispatchError? arriveError;
  DispatchError? postError;
  DispatchError? cancelError;
  CancelQuote quote = const CancelQuote(rule: CancelRule.photographerCancel, refundVnd: 690000, photographerVnd: 0, platformVnd: 0);

  @override
  Future<AcceptedJob> accept(String offerId) async {
    calls.add('accept $offerId');
    final e = acceptError;
    if (e != null) {
      throw DispatchException(e, status: 409);
    }
    return job;
  }

  @override
  Future<void> decline(String offerId, {DeclineReason? reason}) async {
    calls.add(reason == null ? 'decline $offerId' : 'decline $offerId ${reason.code}');
  }

  @override
  Future<void> postLocation(String requestId, LocationFix fix) async {
    calls.add('location $requestId');
    posted.add(fix);
    postedAt.add((clock ?? () => fix.at)());
    final e = postError;
    if (e != null) {
      throw DispatchException(e, status: 429);
    }
  }

  @override
  Future<void> arrive(String requestId, {required LocationFix fix, bool force = false, String? reason}) async {
    calls.add(force ? 'arrive $requestId force' : 'arrive $requestId');
    final e = arriveError;
    if (e != null) {
      throw DispatchException(e, status: 422);
    }
  }

  @override
  Future<void> start(String requestId) async => calls.add('start $requestId');

  @override
  Future<void> finish(String requestId) async => calls.add('finish $requestId');

  @override
  Future<CancelQuote> cancel(String requestId, {required bool dryRun, String? reason}) async {
    calls.add(dryRun ? 'quote $requestId' : 'cancel $requestId');
    final e = cancelError;
    if (e != null && !dryRun) {
      throw DispatchException(e, status: 409);
    }
    return quote;
  }
}
```

```dart
// lib/data/instant/instant_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/http/api_providers.dart';
import 'package:photobooking/data/instant/dispatch_config.dart';
import 'package:photobooking/data/instant/http_instant_repositories.dart';
import 'package:photobooking/data/instant/instant_repositories.dart';

final dispatchConfigProvider = Provider<DispatchConfig>(
  (ref) => DispatchConfig.fromEnvironment(),
);

/// The phase 2 [ApiClient] class, a second instance for the dispatch
/// service, sharing the Firebase ID token source. Null when disabled.
final dispatchApiClientProvider = Provider<ApiClient?>((ref) {
  final base = ref.watch(dispatchConfigProvider).baseUrl;
  if (base == null) {
    return null;
  }
  final client = ApiClient(baseUrl: base, tokens: ref.watch(idTokenSourceProvider));
  ref.onDispose(client.close);
  return client;
});

final presenceRepositoryProvider = Provider<PresenceRepository>((ref) {
  final api = ref.watch(dispatchApiClientProvider);
  return api == null ? const DisabledDispatch() : HttpPresenceRepository(api: api);
});

final instantJobRepositoryProvider = Provider<InstantJobRepository>((ref) {
  final api = ref.watch(dispatchApiClientProvider);
  return api == null ? const DisabledDispatch() : HttpInstantJobRepository(api: api);
});
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/data/instant && flutter analyze`
Expected: PASS (3 + 9 + 3 new tests); analyze clean.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/data/instant test/data/instant
git commit -m "feat(instant): presence and job repositories over the dispatch API, with fakes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Read-only mirror listeners and Firestore rules

**Files:**
- Create: `lib/data/instant/instant_mirror.dart`, `lib/data/instant/firestore_instant_mirror.dart`, `test/data/instant/instant_mirror_test.dart`
- Modify: `lib/data/instant/instant_providers.dart`, `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs`

**Interfaces:**
- Consumes: `requestViewFromMap`, `trackFromMap`, `offerFromMap` (Task 1).
- Produces:
  - `abstract class InstantMirror { Stream<InstantRequestView?> request(String requestId); Stream<InstantTrack?> track(String requestId); Stream<InstantOffer?> offerFor(String photographerId); }` (null = no document).
  - `Object? plainFirestoreValue(Object? v)` (Timestamp → UTC DateTime, recursively) and `FirestoreInstantMirror({FirebaseFirestore? db})`.
  - `FakeInstantMirror` with `setRequest(String id, InstantRequestView?)`, `setTrack(String id, InstantTrack?)`, `setOffer(String uid, InstantOffer?)`, `int listenersOf(String path)` (`instant_requests/R1`, `instant_tracks/R1`, `instant_offers/p1`) and `int get openListeners`.
  - Providers: `instantMirrorProvider`, `instantRequestProvider` (`StreamProvider.autoDispose.family<InstantRequestView?, String>`), `instantTrackProvider` (`StreamProvider.autoDispose.family<InstantTrack?, String>`).
  - Rules: no client writes to `instant_requests`, `instant_tracks`, `instant_offers`; `instant_requests/{id}` readable only by its `customerId` and `photographerId`; `instant_tracks/{id}` readable by the same two (looked up on the request); `instant_offers/{uid}` only by `uid`; `devices/{deviceId}` (Task 6) owner-only with a fixed shape.

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/instant/instant_mirror_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_mirror.dart';
import 'package:photobooking/data/instant/instant_models.dart';

InstantRequestView view(InstantStatus s) => InstantRequestView(
  id: 'R1',
  status: s,
  customerId: 'c1',
  packageCode: InstantPackageCode.p60,
  genre: InstantGenre.portrait,
  amountVnd: 690000,
  expand: false,
  round: 1,
  requestedAt: DateTime.utc(2026, 10, 1, 8),
  updatedAt: DateTime.utc(2026, 10, 1, 8),
);

void main() {
  test('the fake emits the current value on listen, then every change', () async {
    final m = FakeInstantMirror()..setRequest('R1', view(InstantStatus.searching));
    final seen = <InstantStatus?>[];
    final sub = m.request('R1').listen((v) => seen.add(v?.status));
    await pumpEventQueue();
    m.setRequest('R1', view(InstantStatus.assigned));
    m.setRequest('R1', null);
    await pumpEventQueue();
    expect(seen, [InstantStatus.searching, InstantStatus.assigned, null]);
    await sub.cancel();
  });

  test('the fake counts open listeners per path', () async {
    final m = FakeInstantMirror();
    final a = m.offerFor('p1').listen((_) {});
    final b = m.track('R1').listen((_) {});
    await pumpEventQueue();
    expect(m.listenersOf('instant_offers/p1'), 1);
    expect(m.listenersOf('instant_tracks/R1'), 1);
    expect(m.openListeners, 2);
    await a.cancel();
    await b.cancel();
    expect(m.openListeners, 0);
  });
}
```

Append to `firebase/rules-test/rules.test.mjs`:

```js
const instantRequest = {
  status: 'en_route', customerId: 'ic1', photographerId: 'ip1', packageCode: 'p60', genre: 'portrait',
  amountVnd: 690000, expand: false, round: 1, requestedAt: '2026-10-01T08:00:00.000Z', updatedAt: '2026-10-01T08:00:00.000Z',
};

async function seedInstant() {
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, 'instant_requests/IR1'), instantRequest);
    await setDoc(doc(db, 'instant_tracks/IR1'), { lat: 10.77, lng: 106.69, accuracyM: 8, at: '2026-10-01T08:00:00.000Z' });
    await setDoc(doc(db, 'instant_offers/ip2'), { offerId: 'O1', requestId: 'IR2', expiresAt: '2026-10-01T08:00:30.000Z' });
  });
}

test('instant mirror: the customer and the photographer of a request read it and its track', async () => {
  await seedInstant();
  for (const uid of ['ic1', 'ip1']) {
    const db = env.authenticatedContext(uid).firestore();
    await assertSucceeds(getDoc(doc(db, 'instant_requests/IR1')));
    await assertSucceeds(getDoc(doc(db, 'instant_tracks/IR1')));
  }
});

test('instant mirror: nobody else reads a request or a track', async () => {
  await seedInstant();
  const other = env.authenticatedContext('stranger').firestore();
  await assertFails(getDoc(doc(other, 'instant_requests/IR1')));
  await assertFails(getDoc(doc(other, 'instant_tracks/IR1')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'instant_requests/IR1')));
});

test('instant mirror: an offer is read only by its photographer', async () => {
  await seedInstant();
  await assertSucceeds(getDoc(doc(env.authenticatedContext('ip2').firestore(), 'instant_offers/ip2')));
  await assertFails(getDoc(doc(env.authenticatedContext('ip1').firestore(), 'instant_offers/ip2')));
});

test('instant mirror: clients never write any instant_* document', async () => {
  await seedInstant();
  const customer = env.authenticatedContext('ic1').firestore();
  const photographer = env.authenticatedContext('ip1').firestore();
  await assertFails(updateDoc(doc(customer, 'instant_requests/IR1'), { status: 'completed' }));
  await assertFails(setDoc(doc(photographer, 'instant_tracks/IR1'), { lat: 1, lng: 2, accuracyM: 1, at: 'x' }));
  await assertFails(setDoc(doc(photographer, 'instant_offers/ip1'), { offerId: 'O9' }));
  await assertFails(setDoc(doc(customer, 'instant_requests/NEW'), instantRequest));
});

test('devices: a user registers and refreshes their own push token only', async () => {
  const db = env.authenticatedContext('du1').firestore();
  const good = { userId: 'du1', provider: 'fcm', token: 'tok-123', platform: 'android', lastSeenAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(db, 'devices/du1_ABCDEFGH12'), good));
  await assertSucceeds(getDoc(doc(db, 'devices/du1_ABCDEFGH12')));
  await assertFails(setDoc(doc(db, 'devices/du2_ABCDEFGH12'), { ...good, userId: 'du2' }));
  await assertFails(setDoc(doc(db, 'devices/du1_ABCDEFGH12'), { ...good, extra: 1 }));
  await assertFails(setDoc(doc(db, 'devices/du1_ABCDEFGH12'), { ...good, platform: 'web' }));
  await assertFails(getDoc(doc(env.authenticatedContext('du2').firestore(), 'devices/du1_ABCDEFGH12')));
});
```

(If `serverTimestamp` or `updateDoc` is not yet imported at the top of `rules.test.mjs`, add them to the existing `firebase/firestore` import.)

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/data/instant/instant_mirror_test.dart`
Expected: FAIL to compile, `instant_mirror.dart` missing.
Run (from `firebase/rules-test`): `npm test`
Expected: the read tests FAIL (no rule allows `instant_*` reads; the default denies). If the emulator cannot run in this sandbox, say so in the report and rely on the CI job "Firestore rules tests (emulator)".

- [ ] **Step 3: Implement**

```dart
// lib/data/instant/instant_mirror.dart
import 'dart:async';

import 'package:photobooking/data/instant/instant_models.dart';

/// The realtime, read-only copy the dispatch service keeps in Firestore
/// (openapi `*Mirror` schemas). The app never writes it.
abstract class InstantMirror {
  /// `instant_requests/{id}`; null when there is no document.
  Stream<InstantRequestView?> request(String requestId);

  /// `instant_tracks/{id}`; only exists while the photographer is on the way.
  Stream<InstantTrack?> track(String requestId);

  /// `instant_offers/{uid}`: the one pending offer, or null.
  Stream<InstantOffer?> offerFor(String photographerId);
}

class FakeInstantMirror implements InstantMirror {
  final _values = <String, Object?>{};
  final _controllers = <String, StreamController<Object?>>{};
  final _listeners = <String, int>{};

  StreamController<Object?> _c(String path) =>
      _controllers.putIfAbsent(path, () => StreamController<Object?>.broadcast());

  void _set(String path, Object? value) {
    _values[path] = value;
    _c(path).add(value);
  }

  void setRequest(String id, InstantRequestView? v) => _set('instant_requests/$id', v);
  void setTrack(String id, InstantTrack? t) => _set('instant_tracks/$id', t);
  void setOffer(String uid, InstantOffer? o) => _set('instant_offers/$uid', o);

  int listenersOf(String path) => _listeners[path] ?? 0;
  int get openListeners => _listeners.values.fold(0, (a, b) => a + b);

  Stream<T?> _watch<T>(String path) {
    late final StreamController<T?> out;
    StreamSubscription<Object?>? inner;
    out = StreamController<T?>(
      onListen: () {
        _listeners[path] = listenersOf(path) + 1;
        out.add(_values[path] as T?);
        inner = _c(path).stream.listen((v) => out.add(v as T?));
      },
      onCancel: () async {
        _listeners[path] = listenersOf(path) - 1;
        await inner?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Stream<InstantRequestView?> request(String requestId) => _watch('instant_requests/$requestId');

  @override
  Stream<InstantTrack?> track(String requestId) => _watch('instant_tracks/$requestId');

  @override
  Stream<InstantOffer?> offerFor(String photographerId) => _watch('instant_offers/$photographerId');
}
```

```dart
// lib/data/instant/firestore_instant_mirror.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/instant/instant_mirror.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_wire.dart';

/// Timestamps become UTC DateTimes so the pure mappers never see a
/// Firebase type; ISO strings written by the service pass through.
Object? plainFirestoreValue(Object? v) {
  if (v is Timestamp) {
    return v.toDate().toUtc();
  }
  if (v is Map) {
    return {for (final e in v.entries) '${e.key}': plainFirestoreValue(e.value)};
  }
  if (v is List) {
    return [for (final x in v) plainFirestoreValue(x)];
  }
  return v;
}

class FirestoreInstantMirror implements InstantMirror {
  FirestoreInstantMirror({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Stream<T?> _doc<T>(String collection, String id, T Function(Map<String, dynamic>, String) map) =>
      _db.collection(collection).doc(id).snapshots().map((s) {
        final d = s.data();
        if (d == null) {
          return null;
        }
        return map(plainFirestoreValue(d)! as Map<String, dynamic>, s.id);
      });

  @override
  Stream<InstantRequestView?> request(String requestId) =>
      _doc('instant_requests', requestId, (m, id) => requestViewFromMap(m, id: id));

  @override
  Stream<InstantTrack?> track(String requestId) =>
      _doc('instant_tracks', requestId, (m, _) => trackFromMap(m));

  @override
  Stream<InstantOffer?> offerFor(String photographerId) =>
      _doc('instant_offers', photographerId, (m, _) => offerFromMap(m));
}
```

Append to `lib/data/instant/instant_providers.dart` (add imports `firestore_instant_mirror.dart`, `instant_mirror.dart`, `instant_models.dart`):

```dart
final instantMirrorProvider = Provider<InstantMirror>((ref) => FirestoreInstantMirror());

/// Lives only while a screen watches it (spec §9: listeners close with the screen).
final instantRequestProvider = StreamProvider.autoDispose.family<InstantRequestView?, String>(
  (ref, id) => ref.watch(instantMirrorProvider).request(id),
);

final instantTrackProvider = StreamProvider.autoDispose.family<InstantTrack?, String>(
  (ref, id) => ref.watch(instantMirrorProvider).track(id),
);
```

In `firebase/firestore.rules`, inside `match /databases/{database}/documents`, add:

```
    // Chụp ngay mirror (docs/superpowers/specs/2026-10-01-instant-booking-design.md §7):
    // written only by the dispatch service (Admin SDK); read by the two parties.
    function instantParty(data) {
      return signedIn() && (request.auth.uid == data.customerId
        || request.auth.uid == data.get('photographerId', null));
    }

    match /instant_requests/{requestId} {
      allow read: if instantParty(resource.data);
      allow write: if false;
    }

    match /instant_tracks/{requestId} {
      allow read: if instantParty(get(/databases/$(database)/documents/instant_requests/$(requestId)).data);
      allow write: if false;
    }

    match /instant_offers/{photographerId} {
      allow read: if isOwner(photographerId);
      allow write: if false;
    }

    // Push tokens (domain-model Device): one document per install, owner only.
    match /devices/{deviceId} {
      allow read, delete: if signedIn() && resource.data.userId == request.auth.uid;
      allow create, update: if signedIn()
        && request.resource.data.userId == request.auth.uid
        && deviceId.matches('^' + request.auth.uid + '_[A-Za-z0-9]{8,40}$')
        && request.resource.data.keys().hasOnly(['userId', 'provider', 'token', 'platform', 'lastSeenAt'])
        && request.resource.data.provider == 'fcm'
        && request.resource.data.platform in ['android', 'ios']
        && request.resource.data.token is string
        && request.resource.data.token.size() > 0
        && request.resource.data.token.size() < 4096;
    }
```

(`signedIn()` and `isOwner()` already exist in the rules file from earlier plans.)

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/data/instant && flutter analyze`, then (from `firebase/rules-test`) `npm test`
Expected: PASS (2 new Dart tests; 5 new rules tests, old ones unchanged).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/data/instant test/data/instant firebase/firestore.rules firebase/rules-test/rules.test.mjs
git commit -m "feat(instant): read-only Firestore mirror listeners and their rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Location for Chụp ngay (tracking source, send rules, permissions)

**Files:**
- Create: `lib/data/instant/tracking_location.dart`, `lib/data/instant/geolocator_tracking_location.dart`, `lib/features/instant_work/instant_rules.dart`, `test/data/instant/tracking_location_test.dart`, `test/features/instant_work/instant_rules_test.dart`, `test/platform/instant_permissions_test.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `test/battery/location_foundations_battery_test.dart` (3a1), `test/platform/ios_config_test.dart` (iOS enablement Task 1)

**Interfaces:**
- Consumes: `LocationFix`, `MeetPoint` (Task 1); `LatLng`, `distanceMeters`; `geolocator` ≥ 12 (3a1).
- Produces:
  - `enum FixAccuracy { low, medium, high }`; `abstract class TrackingLocationSource { Future<LocationFix?> currentFix({FixAccuracy accuracy = FixAccuracy.medium, Duration timeout = const Duration(seconds: 10)}); Stream<LocationFix> presenceUpdates({int distanceM = 300}); Stream<LocationFix> routeUpdates({Duration interval = const Duration(seconds: 12)}); }`.
  - `FakeTrackingLocationSource({LocationFix? current})` with `currentFixCalls`, `accuracies`, `presenceListeners`, `routeListeners`, `presenceFixes`, `routeFixes`, `activeStreams`, `movePresence(LocationFix)`, `moveRoute(LocationFix)`.
  - `const GeolocatorTrackingLocation()` (presence: `LocationAccuracy.medium` ≈ 100 m, distance filter 300 m, Android interval 5 min; route: `LocationAccuracy.high`, Android interval 12 s; iOS `allowBackgroundLocationUpdates` and `showBackgroundLocationIndicator` true for both streams, `pauseLocationUpdatesAutomatically` false).
  - `instant_rules.dart`: constants `presenceMinMoveM = 300.0`, `presenceHeartbeat = Duration(minutes: 5)`, `routeMinInterval = Duration(seconds: 10)`, `arriveRadiusM = 200.0`, `poorGpsAccuracyM = 100.0`; `bool shouldSendPresence({LocationFix? lastSent, DateTime? lastSentAt, required LocationFix next, required DateTime now})`, `bool heartbeatDue({DateTime? lastSentAt, required DateTime now})`, `bool shouldPostRoute({DateTime? lastPostAt, required DateTime now})`, `double? metersTo(LocationFix? fix, MeetPoint point)`, `bool canArrive(LocationFix? fix, MeetPoint point)`, `bool gpsPoor(LocationFix? fix)`, `List<Uri> directionsUris(MeetPoint point, TargetPlatform platform)`.
  - Android: `ACCESS_FINE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`; `<queries>` for `geo:`. iOS: `UIBackgroundModes` = `location`, a reworded `NSLocationWhenInUseUsageDescription`.

Accuracy names: the spec's "thấp (~100 m)" for idle presence is geolocator's `LocationAccuracy.medium` (Android `PRIORITY_BALANCED_POWER_ACCURACY`, iOS `kCLLocationAccuracyHundredMeters`); geolocator's `low` is about a kilometre and too coarse to rank by ETA.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/instant_work/instant_rules_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant_work/instant_rules.dart';

final _t0 = DateTime.utc(2026, 10, 1, 8);
LocationFix fix(double dLatMeters, {double accuracy = 10, Duration after = Duration.zero}) => LocationFix(
  lat: 10.7745 + dLatMeters / 111195,
  lng: 106.6926,
  accuracyM: accuracy,
  at: _t0.add(after),
);
const _meet = MeetPoint(lat: 10.7745, lng: 106.6926, address: 'Cổng Trương Định');

void main() {
  group('idle presence', () {
    test('the first fix is always sent', () {
      expect(shouldSendPresence(lastSent: null, lastSentAt: null, next: fix(0), now: _t0), isTrue);
    });
    test('moving more than 300 m sends, less does not', () {
      expect(shouldSendPresence(lastSent: fix(0), lastSentAt: _t0, next: fix(350), now: _t0.add(const Duration(minutes: 1))), isTrue);
      expect(shouldSendPresence(lastSent: fix(0), lastSentAt: _t0, next: fix(120), now: _t0.add(const Duration(minutes: 1))), isFalse);
    });
    test('the heartbeat is due after 5 minutes without a send', () {
      expect(heartbeatDue(lastSentAt: _t0, now: _t0.add(const Duration(minutes: 4))), isFalse);
      expect(heartbeatDue(lastSentAt: _t0, now: _t0.add(const Duration(minutes: 5))), isTrue);
      expect(heartbeatDue(lastSentAt: null, now: _t0), isTrue);
    });
  });

  test('en route: at most one post per 10 s', () {
    expect(shouldPostRoute(lastPostAt: null, now: _t0), isTrue);
    expect(shouldPostRoute(lastPostAt: _t0, now: _t0.add(const Duration(seconds: 9))), isFalse);
    expect(shouldPostRoute(lastPostAt: _t0, now: _t0.add(const Duration(seconds: 10))), isTrue);
  });

  group('arrive', () {
    test('enabled within 200 m, not beyond', () {
      expect(canArrive(fix(150), _meet), isTrue);
      expect(canArrive(fix(250), _meet), isFalse);
      expect(canArrive(null, _meet), isFalse);
      expect(metersTo(fix(150), _meet), closeTo(150, 2));
    });
    test('GPS is poor above 100 m accuracy or without a fix', () {
      expect(gpsPoor(fix(0, accuracy: 30)), isFalse);
      expect(gpsPoor(fix(0, accuracy: 140)), isTrue);
      expect(gpsPoor(null), isTrue);
    });
  });

  group('directions open an external maps app', () {
    test('Android: geo: first (any maps app), Google Maps on the web as fallback', () {
      final uris = directionsUris(_meet, TargetPlatform.android);
      expect(uris.first.scheme, 'geo');
      expect(uris.first.toString(), startsWith('geo:10.7745,106.6926?q='));
      expect(uris.last.host, 'www.google.com');
      expect(uris.last.queryParameters['destination'], '10.7745,106.6926');
    });
    test('iOS: Apple Maps first, Google Maps fallback', () {
      final uris = directionsUris(_meet, TargetPlatform.iOS);
      expect(uris.first.host, 'maps.apple.com');
      expect(uris.first.queryParameters['daddr'], '10.7745,106.6926');
      expect(uris.last.host, 'www.google.com');
    });
  });
}
```

```dart
// test/data/instant/tracking_location_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/tracking_location.dart';

void main() {
  final f = LocationFix(lat: 10.77, lng: 106.69, accuracyM: 10, at: DateTime.utc(2026, 10, 1));

  test('the fake delivers fixes only to open streams and counts them', () async {
    final src = FakeTrackingLocationSource(current: f);
    expect(await src.currentFix(accuracy: FixAccuracy.medium), f);
    expect(src.accuracies, [FixAccuracy.medium]);
    src.movePresence(f);
    expect(src.presenceFixes, 0, reason: 'no listener, no fix');
    final seen = <LocationFix>[];
    final sub = src.routeUpdates().listen(seen.add);
    await pumpEventQueue();
    src.moveRoute(f);
    await pumpEventQueue();
    expect((src.routeListeners, src.routeFixes, seen.length), (1, 1, 1));
    await sub.cancel();
    expect(src.activeStreams, 0);
  });

  test('the geolocator adapter: medium + 300 m for presence, high for the route, background indicator on iOS', () {
    final src = File('lib/data/instant/geolocator_tracking_location.dart').readAsStringSync();
    expect(src, contains('LocationAccuracy.medium'));
    expect(src, contains('LocationAccuracy.high'));
    expect(src, contains('distanceFilter: distanceM'));
    expect(src, contains('allowBackgroundLocationUpdates: background'));
    expect(src, contains('showBackgroundLocationIndicator: background'));
    expect(src, contains('pauseLocationUpdatesAutomatically: false'));
    for (final banned in ['requestPermission', 'LocationPermission.always', 'enableWakeLock: true', 'Timer.periodic']) {
      expect(src, isNot(contains(banned)), reason: banned);
    }
  });
}
```

```dart
// test/platform/instant_permissions_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chụp ngay needs precise location while in use and a typed foreground
/// service; it must never ask for background ("Always") location.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  test('Android: fine location and the location foreground service, never background location', () {
    for (final p in [
      'android.permission.ACCESS_COARSE_LOCATION',
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.FOREGROUND_SERVICE"',
      'android.permission.FOREGROUND_SERVICE_LOCATION',
    ]) {
      expect(manifest, contains(p), reason: p);
    }
    expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    expect(manifest, contains('<data android:scheme="geo"/>'));
  });

  test('iOS: when in use only, background mode location and nothing else', () {
    expect(plist, contains('<key>NSLocationWhenInUseUsageDescription</key>'));
    expect(plist, isNot(contains('NSLocationAlways')));
    final modes = RegExp(r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>', dotAll: true).firstMatch(plist);
    expect(modes, isNotNull);
    final values = RegExp(r'<string>([^<]+)</string>').allMatches(modes!.group(1)!).map((m) => m.group(1)).toList();
    expect(values, ['location']);
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/instant_work/instant_rules_test.dart test/data/instant/tracking_location_test.dart test/platform/instant_permissions_test.dart`
Expected: FAIL (missing files; manifest has no FINE / FOREGROUND_SERVICE_LOCATION; plist has no `UIBackgroundModes`).

- [ ] **Step 3: Implement**

```dart
// lib/data/instant/tracking_location.dart
import 'dart:async';

import 'package:photobooking/data/instant/instant_models.dart';

enum FixAccuracy { low, medium, high }

/// Location for Chụp ngay only (the rest of the app uses the one-shot,
/// coarse `LocationRepository` of plan 3a1). Streams run only while a
/// listener is attached; cancelling the subscription turns GPS off.
abstract class TrackingLocationSource {
  /// One fix, or null on failure or after [timeout].
  Future<LocationFix?> currentFix({
    FixAccuracy accuracy = FixAccuracy.medium,
    Duration timeout = const Duration(seconds: 10),
  });

  /// Idle presence: about 100 m accuracy, a fix only after moving
  /// [distanceM]; silent while standing still.
  Stream<LocationFix> presenceUpdates({int distanceM = 300});

  /// En route: high accuracy about every [interval].
  Stream<LocationFix> routeUpdates({Duration interval = const Duration(seconds: 12)});
}

class FakeTrackingLocationSource implements TrackingLocationSource {
  FakeTrackingLocationSource({this.current});

  LocationFix? current;
  int currentFixCalls = 0;
  final accuracies = <FixAccuracy>[];
  int presenceListeners = 0;
  int routeListeners = 0;
  int presenceFixes = 0;
  int routeFixes = 0;
  final _presence = StreamController<LocationFix>.broadcast();
  final _route = StreamController<LocationFix>.broadcast();

  int get activeStreams => presenceListeners + routeListeners;

  void movePresence(LocationFix f) {
    current = f;
    if (presenceListeners > 0) {
      presenceFixes++;
      _presence.add(f);
    }
  }

  void moveRoute(LocationFix f) {
    current = f;
    if (routeListeners > 0) {
      routeFixes++;
      _route.add(f);
    }
  }

  Stream<LocationFix> _counted(StreamController<LocationFix> source, void Function(int) delta) {
    late final StreamController<LocationFix> out;
    StreamSubscription<LocationFix>? inner;
    out = StreamController<LocationFix>(
      onListen: () {
        delta(1);
        inner = source.stream.listen(out.add);
      },
      onCancel: () async {
        delta(-1);
        await inner?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<LocationFix?> currentFix({FixAccuracy accuracy = FixAccuracy.medium, Duration timeout = const Duration(seconds: 10)}) async {
    currentFixCalls++;
    accuracies.add(accuracy);
    return current;
  }

  @override
  Stream<LocationFix> presenceUpdates({int distanceM = 300}) =>
      _counted(_presence, (d) => presenceListeners += d);

  @override
  Stream<LocationFix> routeUpdates({Duration interval = const Duration(seconds: 12)}) =>
      _counted(_route, (d) => routeListeners += d);
}
```

```dart
// lib/data/instant/geolocator_tracking_location.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/tracking_location.dart';

/// geolocator streams for Chụp ngay. Permission is asked elsewhere (S14.01,
/// through plan 3a1's `LocationRepository`), never "Always". On Android the
/// streams keep running in the background because `ForegroundSession`
/// (Task 5) holds a foreground service of type location.
class GeolocatorTrackingLocation implements TrackingLocationSource {
  const GeolocatorTrackingLocation();

  static LocationAccuracy _accuracy(FixAccuracy a) => switch (a) {
    FixAccuracy.low => LocationAccuracy.low,
    FixAccuracy.medium => LocationAccuracy.medium,
    FixAccuracy.high => LocationAccuracy.high,
  };

  static LocationSettings _settings({
    required LocationAccuracy accuracy,
    int distanceM = 0,
    Duration? interval,
    bool background = false,
    Duration? timeLimit,
  }) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceM,
        intervalDuration: interval,
        timeLimit: timeLimit,
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceM,
        timeLimit: timeLimit,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: background,
        showBackgroundLocationIndicator: background,
      );
    }
    return LocationSettings(accuracy: accuracy, distanceFilter: distanceM, timeLimit: timeLimit);
  }

  static LocationFix _fix(Position p) => LocationFix(
    lat: p.latitude,
    lng: p.longitude,
    accuracyM: p.accuracy,
    at: p.timestamp.toUtc(),
    headingDeg: p.heading >= 0 ? p.heading : null,
    speedMps: p.speed >= 0 ? p.speed : null,
  );

  @override
  Future<LocationFix?> currentFix({
    FixAccuracy accuracy = FixAccuracy.medium,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: _settings(accuracy: _accuracy(accuracy), timeLimit: timeout),
      ).timeout(timeout);
      return _fix(p);
    } on Object {
      return null;
    }
  }

  @override
  Stream<LocationFix> presenceUpdates({int distanceM = 300}) => Geolocator.getPositionStream(
    locationSettings: _settings(
      accuracy: LocationAccuracy.medium,
      distanceM: distanceM,
      interval: const Duration(minutes: 5),
      background: true,
    ),
  ).map(_fix).handleError((Object _) {});

  @override
  Stream<LocationFix> routeUpdates({Duration interval = const Duration(seconds: 12)}) =>
      Geolocator.getPositionStream(
        locationSettings: _settings(
          accuracy: LocationAccuracy.high,
          interval: interval,
          background: true,
        ),
      ).map(_fix).handleError((Object _) {});
}
```

```dart
// lib/features/instant_work/instant_rules.dart
import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';

/// Spec §9: idle presence is re-sent after moving more than 300 m, or every
/// 5 minutes so the service's 10-minute TTL never runs out.
const presenceMinMoveM = 300.0;
const presenceHeartbeat = Duration(minutes: 5);

/// En route fixes are posted every 10–15 s; the service limits to 1 / 5 s.
const routeMinInterval = Duration(seconds: 10);

/// "Đã đến" is enabled within 200 m; above 100 m of GPS accuracy the
/// photographer may confirm with a reason instead (spec §10).
const arriveRadiusM = 200.0;
const poorGpsAccuracyM = 100.0;

bool shouldSendPresence({
  required LocationFix? lastSent,
  required DateTime? lastSentAt,
  required LocationFix next,
  required DateTime now,
}) {
  if (lastSent == null || lastSentAt == null) {
    return true;
  }
  return distanceMeters(lastSent.latLng, next.latLng) > presenceMinMoveM ||
      heartbeatDue(lastSentAt: lastSentAt, now: now);
}

/// A few seconds of slack so a timer that fires a little early still counts.
bool heartbeatDue({required DateTime? lastSentAt, required DateTime now}) =>
    lastSentAt == null || now.difference(lastSentAt) >= presenceHeartbeat - const Duration(seconds: 5);

bool shouldPostRoute({required DateTime? lastPostAt, required DateTime now}) =>
    lastPostAt == null || now.difference(lastPostAt) >= routeMinInterval;

double? metersTo(LocationFix? fix, MeetPoint point) =>
    fix == null ? null : distanceMeters(fix.latLng, point.latLng);

bool canArrive(LocationFix? fix, MeetPoint point) {
  final d = metersTo(fix, point);
  return d != null && d <= arriveRadiusM;
}

bool gpsPoor(LocationFix? fix) => fix == null || fix.accuracyM > poorGpsAccuracyM;

/// External maps apps, best first; the screen opens the first one the
/// device can handle. Android `geo:` lets the person pick Goong, Google Maps
/// or any installed maps app.
List<Uri> directionsUris(MeetPoint point, TargetPlatform platform) {
  final ll = '${point.lat},${point.lng}';
  final google = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': ll,
    'travelmode': 'driving',
  });
  return switch (platform) {
    TargetPlatform.android => [
      Uri.parse('geo:$ll?q=${Uri.encodeComponent('$ll(${point.address})')}'),
      google,
    ],
    TargetPlatform.iOS => [
      Uri.https('maps.apple.com', '/', {'daddr': ll, 'dirflg': 'd'}),
      google,
    ],
    _ => [google],
  };
}
```

Platform files:

1. `android/app/src/main/AndroidManifest.xml`: after the `ACCESS_COARSE_LOCATION` line (3a1) add
   ```xml
       <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
       <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
       <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
   ```
   and inside the existing `<queries>` element (plan 2b added `tel` and `https`) add
   ```xml
           <intent>
               <action android:name="android.intent.action.VIEW"/>
               <data android:scheme="geo"/>
           </intent>
   ```
2. `ios/Runner/Info.plist`: replace the `<string>` after `<key>NSLocationWhenInUseUsageDescription</key>` with
   `<string>Chúng tôi dùng vị trí gần đúng của bạn để gợi ý sự kiện quanh đây. Khi bạn bật Chụp ngay, vị trí được gửi tạm thời để nhận lời mời và để khách thấy bạn đang đến; không lưu lịch sử vị trí.</string>`
   and before the closing `</dict>` of the top-level dictionary add
   ```xml
   	<key>UIBackgroundModes</key>
   	<array>
   		<string>location</string>
   	</array>
   ```
3. Relax plan 3a1's battery test (deliberate exception, spec §9). In `test/battery/location_foundations_battery_test.dart`:
   - replace the whole test `'Android asks for approximate location only'` with
     ```dart
         test('Android asks for location while in use only (precise is for Chụp ngay), never background', () {
           final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
           expect(manifest, contains('ACCESS_COARSE_LOCATION'));
           expect(manifest, contains('ACCESS_FINE_LOCATION'));
           expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
         });
     ```
   - in the iOS test, change `expect(reason, contains('không được lưu lên máy chủ'));` to `expect(reason, contains('không lưu lịch sử vị trí'));`, and replace the two lines after `// No background mode may include location.` with
     ```dart
           // Only Chụp ngay's background location (spec §9); no other mode.
           final modes = RegExp(
             r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>',
             dotAll: true,
           ).firstMatch(plist);
           final values = RegExp(r'<string>([^<]+)</string>')
               .allMatches(modes?.group(1) ?? '')
               .map((m) => m.group(1))
               .toList();
           expect(values, anyOf(isEmpty, equals(['location'])));
     ```
   The adapter audit (`'the adapter source has no stream, no high accuracy, no background'`) is unchanged: it reads only 3a1's `geolocator_location_repository.dart`, which stays one-shot and coarse.
4. Relax the iOS enablement test. In `test/platform/ios_config_test.dart` replace the test `'no background location or background modes'` with
   ```dart
     test('background modes: only location (Chụp ngay), never "Always" location', () {
       expect(plist.contains('NSLocationAlwaysAndWhenInUseUsageDescription'), isFalse);
       expect(plist.contains('NSLocationAlwaysUsageDescription'), isFalse);
       final modes = RegExp(r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>', dotAll: true)
           .firstMatch(plist)
           ?.group(1);
       final values = RegExp(r'<string>([^<]+)</string>')
           .allMatches(modes ?? '')
           .map((m) => m.group(1))
           .toList();
       expect(values, ['location']);
     });
   ```
   and in that plan's file `docs/superpowers/plans/2026-10-01-ios-enablement.md`, Global Constraints, change "no background modes are added by this plan." to "no background modes are added by this plan; plan I4 (Chụp ngay) adds `location` only, and the test allows exactly that." If the iOS enablement plan has not run (no `test/platform/ios_config_test.dart`), skip this sub-step and say so in the PR.

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/features/instant_work test/data/instant test/platform test/battery && flutter analyze`
Expected: PASS (instant rules 9, tracking 2, permissions 2; the relaxed 3a1 and iOS tests pass). Then `flutter build apk --debug` succeeds (manifest merge).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/data/instant lib/features/instant_work test android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist ../docs/superpowers/plans/2026-10-01-ios-enablement.md
git commit -m "feat(instant): presence and route location with send rules; precise in-use location and iOS background location only

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Foreground service with "Tắt", and battery level

**Files:**
- Create: `lib/data/instant/foreground_session.dart`, `lib/data/instant/foreground_task_session.dart`, `lib/data/instant/battery_level.dart`, `test/data/instant/foreground_session_test.dart`
- Modify: `pubspec.yaml`, `pubspec.lock`, `android/app/src/main/AndroidManifest.xml`, `lib/main.dart`, `test/platform/instant_permissions_test.dart`

**Interfaces:**
- Produces:
  - `abstract class ForegroundSession { Future<void> start({required String channelName, required String title, required String text, required String stopLabel}); Future<void> stop(); bool get running; Stream<void> get stopPressed; void dispose(); }`.
  - `FakeForegroundSession` (`starts`, `stops`, `lastTitle`, `lastText`, `lastStopLabel`, `pressStop()`), `NoopForegroundSession` (iOS: tracks `running`, never emits).
  - `ForegroundTaskSession` (Android, `flutter_foreground_task`: service type location, low-importance ongoing notification, one button id `instant_off`, `ForegroundTaskEventAction.nothing()`, no wake lock), `@pragma('vm:entry-point') void instantForegroundCallback()`.
  - `abstract class BatteryLevel { Future<int?> percent(); }`, `BatteryPlusLevel`, `FakeBatteryLevel(int? value)` with `reads`.

- [ ] **Step 1: Add the packages**

```bash
flutter pub add flutter_foreground_task battery_plus
flutter pub deps --style=compact | grep -E "^- (flutter_foreground_task|battery_plus) "
```

Expected: `flutter_foreground_task 9.x` (or newer) and `battery_plus 6.x` (or newer). The adapter below uses the 9.x API (`ForegroundTaskOptions(eventAction: ForegroundTaskEventAction.nothing())`, `startService(serviceTypes: …, notificationButtons: …, callback: …)`, `addTaskDataCallback`, `sendDataToMain`). If pub resolves an older major, run `flutter pub upgrade --major-versions flutter_foreground_task`; if a newer major renamed a parameter, adapt only `foreground_task_session.dart` (the fake carries every test) and note it in the PR.

- [ ] **Step 2: Write the failing tests**

```dart
// test/data/instant/foreground_session_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/battery_level.dart';
import 'package:photobooking/data/instant/foreground_session.dart';

void main() {
  test('the fake records start, stop and the "Tắt" button', () async {
    final s = FakeForegroundSession();
    var pressed = 0;
    s.stopPressed.listen((_) => pressed++);
    await s.start(channelName: 'Chụp ngay', title: 'Đang nhận việc chụp ngay', text: 't', stopLabel: 'Tắt');
    expect((s.running, s.starts, s.lastTitle, s.lastStopLabel), (true, 1, 'Đang nhận việc chụp ngay', 'Tắt'));
    s.pressStop();
    await pumpEventQueue();
    expect(pressed, 1);
    await s.stop();
    expect((s.running, s.stops), (false, 1));
  });

  test('starting twice keeps one service', () async {
    final s = FakeForegroundSession();
    await s.start(channelName: 'c', title: 't', text: 'x', stopLabel: 'Tắt');
    await s.start(channelName: 'c', title: 't', text: 'x', stopLabel: 'Tắt');
    expect(s.starts, 1);
  });

  test('the adapter is a location service with a button, no wake lock, no repeating task', () {
    final src = File('lib/data/instant/foreground_task_session.dart').readAsStringSync();
    expect(src, contains('ForegroundServiceTypes.location'));
    expect(src, contains('NotificationButton('));
    expect(src, contains('ForegroundTaskEventAction.nothing()'));
    expect(src, contains('allowWakeLock: false'));
    expect(src, contains('allowWifiLock: false'));
    expect(src, isNot(contains('ForegroundTaskEventAction.repeat')));
  });

  test('battery: one read per call', () async {
    final b = FakeBatteryLevel(14);
    expect(await b.percent(), 14);
    expect(b.reads, 1);
  });
}
```

Append to `main()` in `test/platform/instant_permissions_test.dart`:

```dart
  test('Android: the foreground service is declared with type location', () {
    expect(manifest, contains('com.pravera.flutter_foreground_task.service.ForegroundService'));
    expect(
      RegExp(r'ForegroundService"[^>]*android:foregroundServiceType="location"', dotAll: true).hasMatch(manifest),
      isTrue,
    );
    expect(manifest, isNot(contains('android.permission.WAKE_LOCK')));
  });
```

- [ ] **Step 3: Run and see them fail**

Run: `flutter test test/data/instant/foreground_session_test.dart test/platform/instant_permissions_test.dart`
Expected: FAIL (files missing; no service in the manifest).

- [ ] **Step 4: Implement**

```dart
// lib/data/instant/foreground_session.dart
import 'dart:async';

/// The Android foreground service that lets location run while the app is
/// not visible (required since Android 14). Started only while available
/// or en route; its ongoing notification has one action, "Tắt".
abstract class ForegroundSession {
  Future<void> start({
    required String channelName,
    required String title,
    required String text,
    required String stopLabel,
  });
  Future<void> stop();
  bool get running;

  /// The notification's "Tắt" button.
  Stream<void> get stopPressed;
  void dispose();
}

class FakeForegroundSession implements ForegroundSession {
  final _stop = StreamController<void>.broadcast();
  bool _running = false;
  int starts = 0;
  int stops = 0;
  String? lastTitle;
  String? lastText;
  String? lastStopLabel;

  @override
  bool get running => _running;

  @override
  Future<void> start({required String channelName, required String title, required String text, required String stopLabel}) async {
    if (_running) {
      return;
    }
    _running = true;
    starts++;
    lastTitle = title;
    lastText = text;
    lastStopLabel = stopLabel;
  }

  @override
  Future<void> stop() async {
    if (!_running) {
      return;
    }
    _running = false;
    stops++;
  }

  void pressStop() => _stop.add(null);

  @override
  Stream<void> get stopPressed => _stop.stream;

  @override
  void dispose() => _stop.close();
}

/// iOS: background location only needs `allowsBackgroundLocationUpdates`
/// (the blue status-bar indicator is the visible sign); no service exists.
class NoopForegroundSession implements ForegroundSession {
  bool _running = false;

  @override
  bool get running => _running;

  @override
  Future<void> start({required String channelName, required String title, required String text, required String stopLabel}) async =>
      _running = true;

  @override
  Future<void> stop() async => _running = false;

  @override
  Stream<void> get stopPressed => const Stream.empty();

  @override
  void dispose() {}
}
```

```dart
// lib/data/instant/foreground_task_session.dart
import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'package:photobooking/data/instant/foreground_session.dart';

const _stopButtonId = 'instant_off';

/// Runs in the service's isolate. It does nothing on a schedule
/// (`eventAction: nothing()`); it only forwards the "Tắt" button.
@pragma('vm:entry-point')
void instantForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_InstantTaskHandler());
}

class _InstantTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == _stopButtonId) {
      FlutterForegroundTask.sendDataToMain(_stopButtonId);
    }
  }
}

class ForegroundTaskSession implements ForegroundSession {
  ForegroundTaskSession() {
    FlutterForegroundTask.addTaskDataCallback(_onData);
  }

  final _stop = StreamController<void>.broadcast();
  bool _initialised = false;
  bool _running = false;

  void _onData(Object data) {
    if (data == _stopButtonId) {
      _stop.add(null);
    }
  }

  @override
  bool get running => _running;

  @override
  Stream<void> get stopPressed => _stop.stream;

  @override
  Future<void> start({required String channelName, required String title, required String text, required String stopLabel}) async {
    if (_running) {
      return;
    }
    if (!_initialised) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'instant_session',
          channelName: channelName,
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          onlyAlertOnce: true,
        ),
        iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: false,
          allowWifiLock: false,
        ),
      );
      _initialised = true;
    }
    await FlutterForegroundTask.startService(
      serviceId: 4701,
      serviceTypes: [ForegroundServiceTypes.location],
      notificationTitle: title,
      notificationText: text,
      notificationButtons: [NotificationButton(id: _stopButtonId, text: stopLabel)],
      callback: instantForegroundCallback,
    );
    _running = true;
  }

  @override
  Future<void> stop() async {
    if (!_running) {
      return;
    }
    await FlutterForegroundTask.stopService();
    _running = false;
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    _stop.close();
  }
}
```

```dart
// lib/data/instant/battery_level.dart
import 'package:battery_plus/battery_plus.dart';

/// Read once per presence heartbeat (every 5 minutes); never a stream.
abstract class BatteryLevel {
  Future<int?> percent();
}

class BatteryPlusLevel implements BatteryLevel {
  BatteryPlusLevel({Battery? battery}) : _battery = battery ?? Battery();
  final Battery _battery;

  @override
  Future<int?> percent() async {
    try {
      return await _battery.batteryLevel;
    } on Object {
      return null;
    }
  }
}

class FakeBatteryLevel implements BatteryLevel {
  FakeBatteryLevel(this.value);
  int? value;
  int reads = 0;

  @override
  Future<int?> percent() async {
    reads++;
    return value;
  }
}
```

`android/app/src/main/AndroidManifest.xml`: inside `<application>`, before the `flutterEmbedding` meta-data, add

```xml
        <service
            android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
            android:foregroundServiceType="location"
            android:exported="false" />
```

`lib/main.dart`: add `import 'package:flutter_foreground_task/flutter_foreground_task.dart';` and, right after `WidgetsFlutterBinding.ensureInitialized();`, call `FlutterForegroundTask.initCommunicationPort();`.

- [ ] **Step 5: Run and see them pass**

Run: `flutter test test/data/instant test/platform && flutter analyze && flutter build apk --debug`
Expected: PASS (4 + 1 new tests); the debug APK builds (manifest merge and plugin registration).

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add pubspec.yaml pubspec.lock lib/data/instant lib/main.dart android/app/src/main/AndroidManifest.xml test/data/instant test/platform
git commit -m "feat(instant): location foreground service with a Tắt action, battery level port

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Offer notifications, FCM messages and device registration

**Files:**
- Create: `lib/data/instant/instant_labels.dart`, `lib/data/instant/instant_notifier.dart`, `lib/data/instant/local_instant_notifier.dart`, `lib/data/instant/instant_push.dart`, `lib/data/instant/firebase_push_messages.dart`, `lib/data/instant/firestore_device_registry.dart`, `lib/data/instant/fcm_background.dart`, `ios/Runner/Runner.entitlements`, `test/data/instant/instant_push_test.dart`, `test/data/instant/instant_notifier_test.dart`
- Modify: `pubspec.yaml`, `pubspec.lock`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/AppDelegate.swift`, `ios/Runner.xcodeproj/project.pbxproj` (entitlements path, through Xcode or by hand), `lib/main.dart`, `lib/l10n/app_vi.arb`, `test/platform/instant_permissions_test.dart`

**Interfaces:**
- Consumes: `InstantOffer`, `offerFromMap`, `InstantStatus`, `formatMoney`, `formatDuration`, `formatDistance`, `AppLocalizations`/`lookupAppLocalizations`.
- Produces:
  - `instant_labels.dart`: `String genreLabel(InstantGenre g, AppLocalizations l)`, `String packageLabel(InstantPackageCode c)` (`formatDuration(c.minutes)`), `({String title, String body}) offerNotificationText(InstantOffer o, AppLocalizations l, {required DateTime now})`.
  - `instant_notifier.dart`: `enum InstantTapKind { offer, keepAvailable, turnOff }`, `class InstantTap { const InstantTap(InstantTapKind kind, {String? id}); }`, `int notificationIdFor(String key)` (stable FNV-1a, 31 bits), `abstract class InstantNotifier { Future<void> init(AppLocalizations l); Future<bool> requestPermissions(); Future<void> showOffer({required String offerId, required String title, required String body, required DateTime expiresAt}); Future<void> cancelOffer(String offerId); Future<void> showStillAvailable({required String title, required String body, required String keepLabel, required String offLabel}); Future<void> showLowBattery({required String title, required String body, required String offLabel}); Future<void> cancelPrompts(); Stream<InstantTap> get taps; Future<InstantTap?> launchTap(); void dispose(); }`, `FakeInstantNotifier` (`offers`, `prompts`, `cancelled`, `permissionRequests`, `tap(InstantTap)`, `launch`).
  - `LocalInstantNotifier` (`flutter_local_notifications`): Android channel `instant_offers` (max importance, full-screen intent, `category: call`, `timeoutAfter` until expiry), channel `instant_prompts` with actions; iOS `InterruptionLevel.timeSensitive` for offers, a category with "Vẫn nhận" / "Tắt".
  - `instant_push.dart`: `sealed class InstantPush` with `OfferPush(InstantOffer offer)`, `AssignedPush(String requestId)`, `StatusPush(String requestId, InstantStatus status)` and `static InstantPush? parse(Map<String, Object?> data)`; `abstract class PushMessages { Future<void> requestPermission(); Future<String?> token(); Stream<String> get tokenRefresh; Stream<InstantPush> get foreground; Stream<InstantPush> get opened; Future<InstantPush?> initial(); }`, `FakePushMessages`; `abstract class DeviceRegistry { Future<void> register({required String uid, required String token}); }`, `FakeDeviceRegistry` (`registered`).
  - `FirebasePushMessages`, `FirestoreDeviceRegistry({required SharedPreferences prefs, FirebaseFirestore? db})` (`devices/{uid}_{installId}`), `String installIdFrom(SharedPreferences prefs, {Random? random})`, `Map<String, Object?> deviceFields({required String uid, required String token, required String platform})`.
  - `@pragma('vm:entry-point') Future<void> instantBackgroundMessage(RemoteMessage message)` (shows the offer notification from the background isolate on Android).
  - FCM data contract this app reads (all values strings, as FCM requires): `type=offer` + every `InstantOfferMirror` field (`offerId`, `requestId`, `packageCode`, `genre`, `payoutVnd`, `distanceKm`, `travelMinutes`, `area`, optional `note`, `expiresAt`); `type=assigned` + `requestId`; `type=status` + `requestId`, `status`. Android messages are data-only with `priority: high`; iOS offers carry an APNs alert with `interruption-level: time-sensitive` (the OS shows it; the app does not need a background mode). Task 15 writes this into spec §5 for plan I3.
  - l10n: `instantGenrePortrait` "Chân dung", `instantGenreCouple` "Cặp đôi", `instantGenreFamily` "Gia đình", `instantGenreSmallEvent` "Sự kiện nhỏ", `instantGenreProduct` "Sản phẩm", `instantOfferNotificationTitle(payout)` "Lời mời chụp ngay · {payout}", `instantAcceptWithin(seconds)` "Nhận việc trong {seconds} giây", `instantOfferNotificationBody(area, accept)` "{area} · {accept}", `instantNotificationChannelOffers` "Lời mời chụp ngay", `instantNotificationChannelPrompts` "Nhắc nhở chụp ngay", `instantStillAvailableKeep` "Vẫn nhận", `instantTurnOff` "Tắt".

- [ ] **Step 1: Add the packages**

```bash
flutter pub add firebase_messaging flutter_local_notifications
flutter pub deps --style=compact | grep -E "^- (firebase_messaging|flutter_local_notifications) "
```

Expected: `firebase_messaging` compatible with the existing `firebase_core` 4.x, and `flutter_local_notifications 19.x` (or newer; `requestFullScreenIntentPermission` and `InterruptionLevel` exist since 17). Android: `flutter_local_notifications` needs core library desugaring; if the build says so, add to `android/app/build.gradle.kts` `compileOptions { isCoreLibraryDesugaringEnabled = true }` and `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }`.

- [ ] **Step 2: Write the failing tests**

```dart
// test/data/instant/instant_push_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_labels.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_push.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

const _offerData = {
  'type': 'offer',
  'offerId': 'O1',
  'requestId': 'R1',
  'packageCode': 'p60',
  'genre': 'portrait',
  'payoutVnd': '552000',
  'distanceKm': '2.1',
  'travelMinutes': '8',
  'area': 'Phường Bến Thành, Quận 1',
  'expiresAt': '2026-10-01T08:30:30.000Z',
};

void main() {
  test('an offer message carries the whole offer (all FCM values are strings)', () {
    final p = InstantPush.parse(_offerData);
    expect(p, isA<OfferPush>());
    final o = (p! as OfferPush).offer;
    expect((o.offerId, o.payoutVnd, o.distanceKm, o.travelMinutes, o.note), ('O1', 552000, 2.1, 8, null));
  });

  test('assigned and status messages', () {
    expect((InstantPush.parse({'type': 'assigned', 'requestId': 'R1'})! as AssignedPush).requestId, 'R1');
    final s = InstantPush.parse({'type': 'status', 'requestId': 'R1', 'status': 'arrived'})! as StatusPush;
    expect(s.status, InstantStatus.arrived);
  });

  test('anything else is ignored, never thrown', () {
    expect(InstantPush.parse({'type': 'chat'}), isNull);
    expect(InstantPush.parse({'type': 'offer', 'offerId': 'O1'}), isNull);
    expect(InstantPush.parse({'type': 'status', 'requestId': 'R1', 'status': 'flying'}), isNull);
  });

  test('offer notification text: payout, area and the seconds left', () {
    final l = AppLocalizationsVi();
    final o = (InstantPush.parse(_offerData)! as OfferPush).offer;
    final t = offerNotificationText(o, l, now: DateTime.utc(2026, 10, 1, 8, 30, 8));
    expect(t.title, 'Lời mời chụp ngay · 552.000₫');
    expect(t.body, 'Phường Bến Thành, Quận 1 · Nhận việc trong 22 giây');
    expect(genreLabel(InstantGenre.smallEvent, l), 'Sự kiện nhỏ');
  });

  test('the fake push source and registry', () async {
    final push = FakePushMessages(tokenValue: 'tok');
    final registry = FakeDeviceRegistry();
    await registry.register(uid: 'p1', token: (await push.token())!);
    expect(registry.registered, [('p1', 'tok')]);
  });
}
```

```dart
// test/data/instant/instant_notifier_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/firestore_device_registry.dart';
import 'package:photobooking/data/instant/instant_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('notification ids are stable and positive', () {
    expect(notificationIdFor('offer:O1'), notificationIdFor('offer:O1'));
    expect(notificationIdFor('offer:O1'), isNot(notificationIdFor('offer:O2')));
    expect(notificationIdFor('offer:O1'), greaterThan(0));
  });

  test('the fake records offers, prompts and taps', () async {
    final n = FakeInstantNotifier();
    final taps = <InstantTap>[];
    n.taps.listen(taps.add);
    await n.showOffer(offerId: 'O1', title: 't', body: 'b', expiresAt: DateTime.utc(2026));
    await n.cancelOffer('O1');
    n.tap(const InstantTap(InstantTapKind.keepAvailable));
    await pumpEventQueue();
    expect(n.offers, ['O1']);
    expect(n.cancelled, ['O1']);
    expect(taps.single.kind, InstantTapKind.keepAvailable);
  });

  test('the local adapter uses a full-screen intent on Android and time-sensitive on iOS', () {
    final src = File('lib/data/instant/local_instant_notifier.dart').readAsStringSync();
    expect(src, contains('fullScreenIntent: true'));
    expect(src, contains('AndroidNotificationCategory.call'));
    expect(src, contains('timeoutAfter:'));
    expect(src, contains('InterruptionLevel.timeSensitive'));
    expect(src, contains('requestFullScreenIntentPermission'));
  });

  test('install id: random, kept in preferences, safe for the devices rule', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = installIdFrom(prefs);
    expect(installIdFrom(prefs), a);
    expect(RegExp(r'^[A-Za-z0-9]{8,40}$').hasMatch(a), isTrue);
    expect(deviceFields(uid: 'p1', token: 'tok', platform: 'android').keys.toSet(), {'userId', 'provider', 'token', 'platform'});
  });
}
```

Append to `main()` in `test/platform/instant_permissions_test.dart`:

```dart
  test('Android: notifications and the full-screen offer over the lock screen', () {
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android.permission.USE_FULL_SCREEN_INTENT'));
    expect(manifest, contains('android:showWhenLocked="true"'));
    expect(manifest, contains('android:turnScreenOn="true"'));
  });

  test('iOS: time-sensitive notifications are entitled', () {
    final ent = File('ios/Runner/Runner.entitlements').readAsStringSync();
    expect(ent, contains('com.apple.developer.usernotifications.time-sensitive'));
  });
```

- [ ] **Step 3: Run and see them fail**

Run: `flutter test test/data/instant/instant_push_test.dart test/data/instant/instant_notifier_test.dart test/platform/instant_permissions_test.dart`
Expected: FAIL (files, strings and manifest entries missing).

- [ ] **Step 4: Implement**

Strings for `lib/l10n/app_vi.arb` (then `flutter gen-l10n`):

```json
  "instantGenrePortrait": "Chân dung",
  "instantGenreCouple": "Cặp đôi",
  "instantGenreFamily": "Gia đình",
  "instantGenreSmallEvent": "Sự kiện nhỏ",
  "instantGenreProduct": "Sản phẩm",
  "instantOfferNotificationTitle": "Lời mời chụp ngay · {payout}",
  "@instantOfferNotificationTitle": {"placeholders": {"payout": {"type": "String"}}},
  "instantAcceptWithin": "Nhận việc trong {seconds} giây",
  "@instantAcceptWithin": {"placeholders": {"seconds": {"type": "int"}}},
  "instantOfferNotificationBody": "{area} · {accept}",
  "@instantOfferNotificationBody": {"placeholders": {"area": {"type": "String"}, "accept": {"type": "String"}}},
  "instantNotificationChannelOffers": "Lời mời chụp ngay",
  "instantNotificationChannelPrompts": "Nhắc nhở chụp ngay",
  "instantStillAvailableKeep": "Vẫn nhận",
  "instantTurnOff": "Tắt",
```

```dart
// lib/data/instant/instant_labels.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/l10n/app_localizations.dart';

String genreLabel(InstantGenre g, AppLocalizations l) => switch (g) {
  InstantGenre.portrait => l.instantGenrePortrait,
  InstantGenre.couple => l.instantGenreCouple,
  InstantGenre.family => l.instantGenreFamily,
  InstantGenre.smallEvent => l.instantGenreSmallEvent,
  InstantGenre.product => l.instantGenreProduct,
};

/// `30 phút`, `1 giờ`, `2 giờ`.
String packageLabel(InstantPackageCode c) => formatDuration(c.minutes);

/// Shown by the background isolate too, so it takes no BuildContext.
({String title, String body}) offerNotificationText(
  InstantOffer o,
  AppLocalizations l, {
  required DateTime now,
}) {
  final seconds = (o.remaining(now).inMilliseconds / 1000).ceil();
  return (
    title: l.instantOfferNotificationTitle(formatMoney(o.payoutVnd)),
    body: l.instantOfferNotificationBody(o.area, l.instantAcceptWithin(seconds)),
  );
}
```

```dart
// lib/data/instant/instant_notifier.dart
import 'dart:async';

import 'package:photobooking/l10n/app_localizations.dart';

enum InstantTapKind { offer, keepAvailable, turnOff }

class InstantTap {
  const InstantTap(this.kind, {this.id});
  final InstantTapKind kind;

  /// The offer id for [InstantTapKind.offer].
  final String? id;

  @override
  bool operator ==(Object other) => other is InstantTap && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// Same id in every isolate (String.hashCode is not guaranteed to be).
int notificationIdFor(String key) {
  var h = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xffffffff;
  }
  final id = h & 0x7fffffff;
  return id == 0 ? 1 : id;
}

/// Local notifications of Chụp ngay: the offer (full screen / time
/// sensitive), "Vẫn muốn nhận việc?" and the low-battery prompt.
abstract class InstantNotifier {
  Future<void> init(AppLocalizations l);

  /// Android 13 notifications and Android 14 full-screen intents; iOS alert
  /// and sound. Returns whether notifications may be shown.
  Future<bool> requestPermissions();

  Future<void> showOffer({required String offerId, required String title, required String body, required DateTime expiresAt});
  Future<void> cancelOffer(String offerId);
  Future<void> showStillAvailable({required String title, required String body, required String keepLabel, required String offLabel});
  Future<void> showLowBattery({required String title, required String body, required String offLabel});
  Future<void> cancelPrompts();

  Stream<InstantTap> get taps;

  /// The notification that launched the app, if any.
  Future<InstantTap?> launchTap();
  void dispose();
}

class FakeInstantNotifier implements InstantNotifier {
  final _taps = StreamController<InstantTap>.broadcast();
  final offers = <String>[];
  final cancelled = <String>[];
  final prompts = <String>[];
  int permissionRequests = 0;
  int promptCancels = 0;
  InstantTap? launch;

  void tap(InstantTap t) => _taps.add(t);

  @override
  Future<void> init(AppLocalizations l) async {}

  @override
  Future<bool> requestPermissions() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> showOffer({required String offerId, required String title, required String body, required DateTime expiresAt}) async =>
      offers.add(offerId);

  @override
  Future<void> cancelOffer(String offerId) async => cancelled.add(offerId);

  @override
  Future<void> showStillAvailable({required String title, required String body, required String keepLabel, required String offLabel}) async =>
      prompts.add('still_available');

  @override
  Future<void> showLowBattery({required String title, required String body, required String offLabel}) async =>
      prompts.add('low_battery');

  @override
  Future<void> cancelPrompts() async => promptCancels++;

  @override
  Stream<InstantTap> get taps => _taps.stream;

  @override
  Future<InstantTap?> launchTap() async => launch;

  @override
  void dispose() => _taps.close();
}
```

```dart
// lib/data/instant/local_instant_notifier.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:photobooking/data/instant/instant_notifier.dart';
import 'package:photobooking/l10n/app_localizations.dart';

const _offersChannel = 'instant_offers';
const _promptsChannel = 'instant_prompts';
const _promptCategory = 'instant_prompt';
const _stillAvailableId = 4702;
const _lowBatteryId = 4703;

InstantTap? _tapFrom(NotificationResponse r) {
  final action = r.actionId;
  if (action == 'keep') {
    return const InstantTap(InstantTapKind.keepAvailable);
  }
  if (action == 'off') {
    return const InstantTap(InstantTapKind.turnOff);
  }
  final payload = r.payload ?? '';
  if (payload.startsWith('offer:')) {
    return InstantTap(InstantTapKind.offer, id: payload.substring(6));
  }
  if (payload == 'prompt') {
    return const InstantTap(InstantTapKind.keepAvailable);
  }
  return null;
}

/// Actions that do not open the UI are not used: every action opens the app
/// so the main isolate handles it.
@pragma('vm:entry-point')
void instantNotificationBackgroundTap(NotificationResponse r) {}

class LocalInstantNotifier implements InstantNotifier {
  LocalInstantNotifier({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<InstantTap>.broadcast();
  bool _ready = false;
  late AppLocalizations _l;

  @override
  Future<void> init(AppLocalizations l) async {
    _l = l;
    if (_ready) {
      return;
    }
    await _plugin.initialize(
      InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              _promptCategory,
              actions: [
                DarwinNotificationAction.plain('keep', l.instantStillAvailableKeep, options: {DarwinNotificationActionOption.foreground}),
                DarwinNotificationAction.plain('off', l.instantTurnOff, options: {DarwinNotificationActionOption.foreground}),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final t = _tapFrom(r);
        if (t != null) {
          _taps.add(t);
        }
      },
      onDidReceiveBackgroundNotificationResponse: instantNotificationBackgroundTap,
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ok = await android?.requestNotificationsPermission() ?? true;
      await android?.requestFullScreenIntentPermission();
      return ok;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true, badge: false) ?? false;
  }

  @override
  Future<void> showOffer({required String offerId, required String title, required String body, required DateTime expiresAt}) async {
    final left = expiresAt.difference(DateTime.now().toUtc());
    if (left <= Duration.zero) {
      return;
    }
    await _plugin.show(
      notificationIdFor('offer:$offerId'),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _offersChannel,
          _l.instantNotificationChannelOffers,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
          visibility: NotificationVisibility.public,
          timeoutAfter: left.inMilliseconds,
          autoCancel: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBanner: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: 'offer:$offerId',
    );
  }

  @override
  Future<void> cancelOffer(String offerId) => _plugin.cancel(notificationIdFor('offer:$offerId'));

  NotificationDetails _prompt(String keepLabel, String offLabel, {bool keep = true}) => NotificationDetails(
    android: AndroidNotificationDetails(
      _promptsChannel,
      _l.instantNotificationChannelPrompts,
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        if (keep) AndroidNotificationAction('keep', keepLabel, showsUserInterface: true),
        AndroidNotificationAction('off', offLabel, showsUserInterface: true),
      ],
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      categoryIdentifier: _promptCategory,
    ),
  );

  @override
  Future<void> showStillAvailable({required String title, required String body, required String keepLabel, required String offLabel}) =>
      _plugin.show(_stillAvailableId, title, body, _prompt(keepLabel, offLabel), payload: 'prompt');

  @override
  Future<void> showLowBattery({required String title, required String body, required String offLabel}) =>
      _plugin.show(_lowBatteryId, title, body, _prompt('', offLabel, keep: false), payload: 'prompt');

  @override
  Future<void> cancelPrompts() async {
    await _plugin.cancel(_stillAvailableId);
    await _plugin.cancel(_lowBatteryId);
  }

  @override
  Stream<InstantTap> get taps => _taps.stream;

  @override
  Future<InstantTap?> launchTap() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    final r = details?.notificationResponse;
    if (details?.didNotificationLaunchApp != true || r == null) {
      return null;
    }
    return _tapFrom(r);
  }

  @override
  void dispose() => _taps.close();
}
```

```dart
// lib/data/instant/instant_push.dart
import 'dart:async';

import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_wire.dart';

/// An FCM data message of the dispatch service (spec §5; keys in Task 6 of
/// plan I4). Unknown or incomplete messages parse to null.
sealed class InstantPush {
  const InstantPush();

  static InstantPush? parse(Map<String, Object?> data) {
    try {
      switch (data['type']) {
        case 'offer':
          final m = <String, dynamic>{...data};
          for (final k in ['payoutVnd', 'travelMinutes']) {
            m[k] = int.parse('${data[k]}');
          }
          m['distanceKm'] = double.parse('${data['distanceKm']}');
          return OfferPush(offerFromMap(m));
        case 'assigned':
          final id = data['requestId'];
          return id is String ? AssignedPush(id) : null;
        case 'status':
          final id = data['requestId'];
          final status = InstantStatus.fromCode(data['status'] as String?);
          return id is String && status != null ? StatusPush(id, status) : null;
      }
    } on Object {
      return null;
    }
    return null;
  }
}

final class OfferPush extends InstantPush {
  const OfferPush(this.offer);
  final InstantOffer offer;
}

final class AssignedPush extends InstantPush {
  const AssignedPush(this.requestId);
  final String requestId;
}

final class StatusPush extends InstantPush {
  const StatusPush(this.requestId, this.status);
  final String requestId;
  final InstantStatus status;
}

abstract class PushMessages {
  Future<void> requestPermission();
  Future<String?> token();
  Stream<String> get tokenRefresh;

  /// Messages received while the app is in the foreground.
  Stream<InstantPush> get foreground;

  /// A system notification (iOS alert) tapped while the app was running.
  Stream<InstantPush> get opened;

  /// The system notification that launched the app.
  Future<InstantPush?> initial();
}

class FakePushMessages implements PushMessages {
  FakePushMessages({this.tokenValue = 'fake-token'});
  String? tokenValue;
  InstantPush? initialValue;
  final _refresh = StreamController<String>.broadcast();
  final _foreground = StreamController<InstantPush>.broadcast();
  final _opened = StreamController<InstantPush>.broadcast();
  int permissionRequests = 0;

  void receive(InstantPush p) => _foreground.add(p);
  void open(InstantPush p) => _opened.add(p);
  void refreshToken(String t) {
    tokenValue = t;
    _refresh.add(t);
  }

  @override
  Future<void> requestPermission() async => permissionRequests++;
  @override
  Future<String?> token() async => tokenValue;
  @override
  Stream<String> get tokenRefresh => _refresh.stream;
  @override
  Stream<InstantPush> get foreground => _foreground.stream;
  @override
  Stream<InstantPush> get opened => _opened.stream;
  @override
  Future<InstantPush?> initial() async => initialValue;
}

/// Where the service finds a user's push tokens (domain-model `Device`).
abstract class DeviceRegistry {
  Future<void> register({required String uid, required String token});
}

class FakeDeviceRegistry implements DeviceRegistry {
  final registered = <(String, String)>[];

  @override
  Future<void> register({required String uid, required String token}) async =>
      registered.add((uid, token));
}
```

```dart
// lib/data/instant/firebase_push_messages.dart
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:photobooking/data/instant/instant_push.dart';

class FirebasePushMessages implements PushMessages {
  FirebasePushMessages({FirebaseMessaging? messaging}) : _injected = messaging;
  final FirebaseMessaging? _injected;

  /// Resolved on first use, so building the provider never needs Firebase
  /// (widget tests that read the router do not initialise it).
  FirebaseMessaging get _m => _injected ?? FirebaseMessaging.instance;

  static Stream<InstantPush> _parsed(Stream<RemoteMessage> s) => s
      .map((m) => InstantPush.parse(m.data))
      .where((p) => p != null)
      .cast<InstantPush>();

  @override
  Future<void> requestPermission() async {
    await _m.requestPermission(alert: true, sound: true, badge: false);
  }

  @override
  Future<String?> token() async {
    try {
      return await _m.getToken();
    } on Object {
      return null;
    }
  }

  @override
  Stream<String> get tokenRefresh => _m.onTokenRefresh;

  @override
  Stream<InstantPush> get foreground => _parsed(FirebaseMessaging.onMessage);

  @override
  Stream<InstantPush> get opened => _parsed(FirebaseMessaging.onMessageOpenedApp);

  @override
  Future<InstantPush?> initial() async {
    final m = await _m.getInitialMessage();
    return m == null ? null : InstantPush.parse(m.data);
  }
}
```

```dart
// lib/data/instant/firestore_device_registry.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/instant/instant_push.dart';

const _installKey = 'installId';
const _alphabet = 'ABCDEFGHJKMNPQRSTVWXYZabcdefghjkmnpqrstvwxyz23456789';

/// A random id for this installation, created once and kept locally.
String installIdFrom(SharedPreferences prefs, {Random? random}) {
  final existing = prefs.getString(_installKey);
  if (existing != null) {
    return existing;
  }
  final r = random ?? Random.secure();
  final id = List.generate(20, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
  prefs.setString(_installKey, id);
  return id;
}

Map<String, Object?> deviceFields({required String uid, required String token, required String platform}) => {
  'userId': uid,
  'provider': 'fcm',
  'token': token,
  'platform': platform,
};

/// `devices/{uid}_{installId}`, owner-only (rules in Task 3).
class FirestoreDeviceRegistry implements DeviceRegistry {
  FirestoreDeviceRegistry({required SharedPreferences prefs, FirebaseFirestore? db})
    : _prefs = prefs,
      _db = db ?? FirebaseFirestore.instance;
  final SharedPreferences _prefs;
  final FirebaseFirestore _db;

  @override
  Future<void> register({required String uid, required String token}) async {
    final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    await _db.collection('devices').doc('${uid}_${installIdFrom(_prefs)}').set({
      ...deviceFields(uid: uid, token: token, platform: platform),
      'lastSeenAt': FieldValue.serverTimestamp(),
    });
  }
}
```

```dart
// lib/data/instant/fcm_background.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'package:photobooking/data/instant/instant_labels.dart';
import 'package:photobooking/data/instant/instant_push.dart';
import 'package:photobooking/data/instant/local_instant_notifier.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Android, app in the background or killed: the service sends a high
/// priority data message; this isolate turns it into the full-screen offer
/// notification. iOS offers arrive as an APNs alert the OS shows itself.
@pragma('vm:entry-point')
Future<void> instantBackgroundMessage(RemoteMessage message) async {
  if (message.notification != null) {
    return;
  }
  final push = InstantPush.parse(message.data);
  if (push is! OfferPush) {
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  final l = lookupAppLocalizations(const Locale('vi'));
  final notifier = LocalInstantNotifier();
  await notifier.init(l);
  final text = offerNotificationText(push.offer, l, now: DateTime.now().toUtc());
  await notifier.showOffer(
    offerId: push.offer.offerId,
    title: text.title,
    body: text.body,
    expiresAt: push.offer.expiresAt,
  );
}
```

Platform files:

1. `android/app/src/main/AndroidManifest.xml`: add
   ```xml
       <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
       <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
   ```
   and add `android:showWhenLocked="true"` and `android:turnScreenOn="true"` to the `.MainActivity` `<activity>` element (the full-screen offer shows over the lock screen; Flutter draws S14.02 once the activity starts).
2. Create `ios/Runner/Runner.entitlements`:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
   	<key>aps-environment</key>
   	<string>development</string>
   	<key>com.apple.developer.usernotifications.time-sensitive</key>
   	<true/>
   </dict>
   </plist>
   ```
   and point the Runner target at it: in `ios/Runner.xcodeproj/project.pbxproj` add `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` to the Debug, Release and Profile `buildSettings` of the Runner target (or in Xcode: Signing & Capabilities → + Push Notifications, + Time Sensitive Notifications, which writes the same). A real device build also needs the APNs key uploaded to Firebase (Firebase console → Cloud Messaging); that is a **[người dùng]** step listed in Task 16.
3. `ios/Runner/AppDelegate.swift`: inside `application(_:didFinishLaunchingWithOptions:)`, before `return super.application(…)`, add
   ```swift
       if #available(iOS 10.0, *) {
         UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
       }
   ```
   (and `import UserNotifications` at the top if Xcode asks), as `flutter_local_notifications` requires for foreground presentation.
4. `lib/main.dart`: add `import 'package:firebase_messaging/firebase_messaging.dart';` and `import 'package:photobooking/data/instant/fcm_background.dart';`; right after `Firebase.initializeApp` has completed (after the `.wait` line) call `FirebaseMessaging.onBackgroundMessage(instantBackgroundMessage);`.

- [ ] **Step 5: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/data/instant test/platform && flutter analyze && flutter build apk --debug`
Expected: PASS (5 + 4 + 2 new tests); the APK builds.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add pubspec.yaml pubspec.lock lib/data/instant lib/main.dart lib/l10n android ios test
git commit -m "feat(instant): full-screen and time-sensitive offer notifications, FCM parsing, device tokens

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Shared widgets: `TickingBuilder`, `CountdownRing`, `AppButton.danger`, `AppMap`

**Files:**
- Create: `lib/core/widgets/ticking_builder.dart`, `lib/core/widgets/countdown_ring.dart`, `lib/core/widgets/app_map.dart`, `lib/core/map/goong_config.dart`, `lib/core/map/maplibre_map_engine.dart`, `test/support/fake_map_engine.dart`, `test/core/widgets/ticking_builder_test.dart`, `test/core/widgets/countdown_ring_test.dart`, `test/core/widgets/app_map_test.dart`, `test/core/widgets/app_button_danger_test.dart`
- Modify: `lib/core/widgets/app_button.dart`, `lib/core/core.dart`, `lib/main.dart`, `pubspec.yaml`, `pubspec.lock`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `hostWidget`; `LatLng`, `lerpLatLng`; `AppColors`; `CtaSurface` untouched.
- Produces:
  - `const TickingBuilder({super.key, required bool active, required WidgetBuilder builder, Duration period = const Duration(seconds: 1)})`; `@visibleForTesting static int get debugActiveCount` (timers alive in the whole app).
  - `const CountdownRing({super.key, required Duration remaining, required Duration total, required String unit, required String semanticsLabel, double size = 132})` — whole seconds rounded up; `ss` when `total ≤ 1 min`, else `m:ss`; ring fraction `remaining / total`; one `Semantics` label, the drawing excluded.
  - `const AppButton.danger(String label, {Key? key, required VoidCallback? onPressed, bool loading = false, Widget? icon, ButtonStyle? style})` — filled `AppColors.destructive`, white text, same height as the primary.
  - `enum MapMarkerKind { self, other, meetPoint }`, `class MapMarker { const MapMarker({required String id, required LatLng at, required String label, MapMarkerKind kind = MapMarkerKind.other}); }`, `class AppMapView` (what an engine draws: `center`, `zoom`, `markers`, `fitMarkers`, `cameraToken`, `markerAnimation`, `dark`, `onCameraIdle`), `abstract class AppMapEngine { Widget build(BuildContext, AppMapView); }`, `class AppMapScope extends InheritedWidget { const AppMapScope({super.key, required AppMapEngine engine, required super.child}); static AppMapEngine? of(BuildContext) }`, `const AppMap({super.key, required LatLng center, required String semanticsLabel, double zoom = 15, List<MapMarker> markers = const [], bool fitMarkers = false, int cameraToken = 0, ValueChanged<LatLng>? onCameraIdle, String? centerPinLabel, VoidCallback? onMyLocation})` — without a scope it draws a placeholder ("Bản đồ chưa sẵn sàng"); the centre pin and the "Về vị trí của tôi" button are Flutter overlays; `markerAnimation` is zero under reduced motion.
  - `class GoongConfig { const GoongConfig({required String mapKey, required String apiKey}); factory GoongConfig.fromEnvironment(); bool get hasMapKey; bool get hasApiKey; String styleUrl({required bool dark}); String get apiKey; }` (`toString` redacted; plan I5 uses `apiKey` for Places).
  - `const MaplibreMapEngine(GoongConfig config)` (not exported from `core.dart`; only `main.dart` imports it).
  - Test support: `FakeMapEngine` (`builds`, `last`, `settleCamera(LatLng)`, draws `Key('fake-map')`).
  - l10n: `mapUnavailable` "Bản đồ chưa sẵn sàng", `mapMyLocation` "Về vị trí của tôi".

- [ ] **Step 1: Add the package**

```bash
flutter pub add maplibre_gl
flutter pub deps --style=compact | grep -E "^- maplibre_gl "
```

Expected: `maplibre_gl 0.2x`. The engine uses `MapLibreMap` / `MapLibreMapController` (names since 0.20); if pub resolves an older version where they are `MaplibreMap` / `MaplibreMapController`, upgrade (`flutter pub upgrade --major-versions maplibre_gl`) rather than renaming.

- [ ] **Step 2: Write the failing tests**

```dart
// test/support/fake_map_engine.dart
import 'package:flutter/material.dart';
import 'package:photobooking/core/core.dart';

/// Stands in for MapLibre in widget tests (a platform view cannot render
/// there). Counts builds so battery tests can prove where a map exists.
class FakeMapEngine implements AppMapEngine {
  int builds = 0;
  AppMapView? last;

  @override
  Widget build(BuildContext context, AppMapView view) {
    builds++;
    last = view;
    return const SizedBox.expand(key: Key('fake-map'));
  }

  /// The person stopped dragging the map at [at].
  void settleCamera(LatLng at) => last?.onCameraIdle?.call(at);
}
```

```dart
// test/core/widgets/ticking_builder_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/idle.dart';
import 'widget_host.dart';

void main() {
  testWidgets('rebuilds once per second only while active', (tester) async {
    var builds = 0;
    Widget host(bool active) => hostWidget(
      TickingBuilder(active: active, builder: (_) {
        builds++;
        return const SizedBox();
      }),
    );
    await tester.pumpWidget(host(true));
    expect(TickingBuilder.debugActiveCount, 1);
    final before = builds;
    await tester.pump(const Duration(seconds: 3));
    expect(builds - before, inInclusiveRange(1, 3));
    await tester.pumpWidget(host(false));
    expect(TickingBuilder.debugActiveCount, 0);
    final after = builds;
    await tester.pump(const Duration(seconds: 5));
    expect(builds, after);
    await expectIdle(tester);
  });

  testWidgets('removing it stops the timer', (tester) async {
    await tester.pumpWidget(hostWidget(TickingBuilder(active: true, builder: (_) => const SizedBox())));
    await tester.pumpWidget(hostWidget(const SizedBox()));
    expect(TickingBuilder.debugActiveCount, 0);
  });
}
```

```dart
// test/core/widgets/countdown_ring_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('shows whole seconds, rounded up, with a unit and one label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const CountdownRing(
      remaining: Duration(milliseconds: 21400),
      total: Duration(seconds: 30),
      unit: 'giây',
      semanticsLabel: 'Còn 22 giây',
    )));
    expect(find.text('22'), findsOneWidget);
    expect(find.text('giây'), findsOneWidget);
    expect(find.bySemanticsLabel('Còn 22 giây'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('long durations read m:ss; negative is zero', (tester) async {
    await tester.pumpWidget(hostWidget(const CountdownRing(
      remaining: Duration(minutes: 38, seconds: 12),
      total: Duration(hours: 1),
      unit: 'còn lại',
      semanticsLabel: 'Còn 38 phút',
    )));
    expect(find.text('38:12'), findsOneWidget);
    await tester.pumpWidget(hostWidget(const CountdownRing(
      remaining: Duration(seconds: -3),
      total: Duration(seconds: 30),
      unit: 'giây',
      semanticsLabel: 'Hết giờ',
    )));
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('fits 320dp at 1.3x in light and dark', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(hostWidget(
        const CountdownRing(remaining: Duration(seconds: 30), total: Duration(seconds: 30), unit: 'giây', semanticsLabel: 'Còn 30 giây'),
        width: 320,
        textScale: 1.3,
        brightness: b,
      ));
      expect(tester.takeException(), isNull);
    }
  });
}
```

```dart
// test/core/widgets/app_button_danger_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('danger is a red filled button, never the gradient', (tester) async {
    var taps = 0;
    await tester.pumpWidget(hostWidget(AppButton.danger('Huỷ và hoàn 552.000₫', onPressed: () => taps++)));
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style!.backgroundColor!.resolve(const {}), AppColors.destructive);
    expect(find.byType(CtaSurface), findsNothing);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 1);
  });

  testWidgets('loading shows a white spinner and ignores taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(hostWidget(AppButton.danger('Huỷ', loading: true, onPressed: () => taps++)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 0);
  });
}
```

```dart
// test/core/widgets/app_map_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/fake_map_engine.dart';
import '../../support/idle.dart';
import 'widget_host.dart';

const _here = LatLng(10.7745, 106.6926);

Widget _map({AppMapEngine? engine, bool reduce = false, VoidCallback? onMyLocation, String? pin}) {
  final map = SizedBox(
    height: 200,
    child: AppMap(
      center: _here,
      semanticsLabel: 'Bản đồ',
      markers: const [
        MapMarker(id: 'me', at: _here, label: 'Bạn', kind: MapMarkerKind.self),
        MapMarker(id: 'p', at: LatLng(10.78, 106.70), label: 'Minh Trí · 9 phút'),
      ],
      centerPinLabel: pin,
      onMyLocation: onMyLocation,
    ),
  );
  final inner = engine == null ? map : AppMapScope(engine: engine, child: map);
  return hostWidget(
    reduce ? MediaQuery(data: const MediaQueryData(disableAnimations: true), child: inner) : inner,
  );
}

void main() {
  testWidgets('without an engine it shows a placeholder, not a crash', (tester) async {
    await tester.pumpWidget(_map());
    expect(find.text('Bản đồ chưa sẵn sàng'), findsOneWidget);
  });

  testWidgets('the engine gets the markers; every pin has a text label for screen readers', (tester) async {
    final engine = FakeMapEngine();
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_map(engine: engine));
    expect(engine.last!.markers.map((m) => m.label), ['Bạn', 'Minh Trí · 9 phút']);
    expect(find.bySemanticsLabel(RegExp('Bạn, Minh Trí · 9 phút')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('markers glide normally and jump under reduced motion', (tester) async {
    final engine = FakeMapEngine();
    await tester.pumpWidget(_map(engine: engine));
    expect(engine.last!.markerAnimation, greaterThan(Duration.zero));
    await tester.pumpWidget(_map(engine: engine, reduce: true));
    expect(engine.last!.markerAnimation, Duration.zero);
  });

  testWidgets('"Về vị trí của tôi" is a labelled 48dp button; the centre pin has a label', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_map(engine: FakeMapEngine(), onMyLocation: () => taps++, pin: 'Điểm hẹn · Công viên Tao Đàn'));
    final button = find.byTooltip('Về vị trí của tôi');
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    await tester.tap(button);
    expect(taps, 1);
    expect(find.text('Điểm hẹn · Công viên Tao Đàn'), findsOneWidget);
  });

  testWidgets('a map at rest schedules no frames', (tester) async {
    await tester.pumpWidget(_map(engine: FakeMapEngine()));
    await expectIdle(tester);
  });

  test('Goong config never prints its keys', () {
    const c = GoongConfig(mapKey: 'MAPKEY123', apiKey: 'APIKEY456');
    expect(c.toString(), isNot(contains('MAPKEY123')));
    expect(c.toString(), isNot(contains('APIKEY456')));
    expect(c.styleUrl(dark: true), contains('goong_map_dark.json?api_key=MAPKEY123'));
    expect(c.styleUrl(dark: false), contains('goong_map_web.json'));
    expect(const GoongConfig(mapKey: '', apiKey: '').hasMapKey, isFalse);
  });
}
```

- [ ] **Step 3: Run and see them fail**

Run: `flutter test test/core/widgets/ticking_builder_test.dart test/core/widgets/countdown_ring_test.dart test/core/widgets/app_button_danger_test.dart test/core/widgets/app_map_test.dart`
Expected: FAIL to compile (`TickingBuilder`, `CountdownRing`, `AppButton.danger`, `AppMap`, `GoongConfig` undefined).

- [ ] **Step 4: Implement**

Strings (`lib/l10n/app_vi.arb`, then `flutter gen-l10n`):

```json
  "mapUnavailable": "Bản đồ chưa sẵn sàng",
  "mapMyLocation": "Về vị trí của tôi",
```

```dart
// lib/core/widgets/ticking_builder.dart
import 'dart:async';

import 'package:flutter/widgets.dart';

/// Rebuilds [builder] every [period] while [active], for clocks that must
/// move (offer countdown, search timer, shoot timer). The only sanctioned
/// periodic timer in the UI: it stops the moment [active] is false or the
/// widget leaves the tree (docs/testing/battery-and-performance.md).
class TickingBuilder extends StatefulWidget {
  const TickingBuilder({
    super.key,
    required this.active,
    required this.builder,
    this.period = const Duration(seconds: 1),
  });

  final bool active;
  final WidgetBuilder builder;
  final Duration period;

  /// Timers alive in the whole app; tests prove screens stop ticking.
  @visibleForTesting
  static int get debugActiveCount => _TickingBuilderState._active;

  @override
  State<TickingBuilder> createState() => _TickingBuilderState();
}

class _TickingBuilderState extends State<TickingBuilder> {
  static int _active = 0;
  Timer? _timer;

  void _start() {
    _active++;
    _timer = Timer.periodic(widget.period, (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _stop() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
      _active--;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _start();
    }
  }

  @override
  void didUpdateWidget(TickingBuilder old) {
    super.didUpdateWidget(old);
    if (!widget.active || old.period != widget.period) {
      _stop();
    }
    if (widget.active && _timer == null) {
      _start();
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
```

```dart
// lib/core/widgets/countdown_ring.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// A countdown shown as a number **and** a ring (never colour alone).
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.remaining,
    required this.total,
    required this.unit,
    required this.semanticsLabel,
    this.size = 132,
  });

  final Duration remaining;
  final Duration total;

  /// Small text under the number: "giây", "còn lại".
  final String unit;
  final String semanticsLabel;
  final double size;

  int get _seconds => remaining.isNegative ? 0 : (remaining.inMilliseconds / 1000).ceil();

  String get _text {
    final s = _seconds;
    if (total <= const Duration(minutes: 1)) {
      return '$s';
    }
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fraction = total.inMilliseconds == 0
        ? 0.0
        : (remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              fraction: fraction,
              track: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
              color: dark ? AppColorsDark.primary : AppColors.primary,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _text,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(unit, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.track, required this.color});
  final double fraction;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arc, 0, math.pi * 2, false, base);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * fraction, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.track != track || old.color != color;
}
```

`lib/core/widgets/app_button.dart` (edits):

1. `enum _Kind { primary, outline, text }` → `enum _Kind { primary, outline, text, danger }`.
2. After the `AppButton.text` constructor add:
   ```dart
     /// Destructive confirmation inside a sheet ("Huỷ và hoàn …", "Từ chối
     /// lời mời"). Never the screen's gradient button.
     const AppButton.danger(
       this.label, {
       super.key,
       required this.onPressed,
       this.loading = false,
       this.icon,
       this.style,
     }) : _kind = _Kind.danger;
   ```
3. In `build`, after `final onGradient = _kind == _Kind.primary;` add `final onFill = onGradient || _kind == _Kind.danger;` and in the spinner use `color: onFill ? Colors.white : style?.foregroundColor?.resolve(const {}),`.
4. Add a case to the final `switch`:
   ```dart
         _Kind.danger => FilledButton(
           onPressed: cb,
           style: FilledButton.styleFrom(
             backgroundColor: AppColors.destructive,
             foregroundColor: AppColors.destructiveForeground,
             disabledBackgroundColor: AppColors.destructive.withValues(alpha: 0.4),
             disabledForegroundColor: AppColors.destructiveForeground,
           ).merge(style),
           child: child,
         ),
   ```

```dart
// lib/core/map/goong_config.dart
/// Goong keys, from `--dart-define=GOONG_MAPTILES_KEY=…` (map tiles) and
/// `--dart-define=GOONG_API_KEY=…` (Places, plan I5). Both are restricted to
/// the app's package name / bundle id in the Goong console. Never logged.
class GoongConfig {
  const GoongConfig({required String mapKey, required String apiKey})
    : _mapKey = mapKey,
      _apiKey = apiKey;

  factory GoongConfig.fromEnvironment() => const GoongConfig(
    mapKey: String.fromEnvironment('GOONG_MAPTILES_KEY'),
    apiKey: String.fromEnvironment('GOONG_API_KEY'),
  );

  final String _mapKey;
  final String _apiKey;

  bool get hasMapKey => _mapKey.isNotEmpty;
  bool get hasApiKey => _apiKey.isNotEmpty;

  /// For building request URLs only; never print it.
  String get apiKey => _apiKey;

  String styleUrl({required bool dark}) =>
      'https://tiles.goong.io/assets/${dark ? 'goong_map_dark' : 'goong_map_web'}.json?api_key=$_mapKey';

  @override
  String toString() => 'GoongConfig(<redacted>)';
}
```

```dart
// lib/core/widgets/app_map.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/lat_lng.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

enum MapMarkerKind { self, other, meetPoint }

/// A pin. [label] is drawn next to it and read by screen readers.
class MapMarker {
  const MapMarker({required this.id, required this.at, required this.label, this.kind = MapMarkerKind.other});
  final String id;
  final LatLng at;
  final String label;
  final MapMarkerKind kind;

  @override
  bool operator ==(Object other) =>
      other is MapMarker && other.id == id && other.at == at && other.label == label && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, at, label, kind);
}

/// What an engine draws, decided by [AppMap].
class AppMapView {
  const AppMapView({
    required this.center,
    required this.zoom,
    required this.markers,
    required this.fitMarkers,
    required this.cameraToken,
    required this.markerAnimation,
    required this.dark,
    this.onCameraIdle,
  });
  final LatLng center;
  final double zoom;
  final List<MapMarker> markers;

  /// Frame every marker (S13.05, S14.03) instead of [center].
  final bool fitMarkers;

  /// When it changes the engine moves the camera (to [center] or the fit).
  final int cameraToken;

  /// How long a moved marker glides; zero under reduced motion.
  final Duration markerAnimation;
  final bool dark;
  final ValueChanged<LatLng>? onCameraIdle;
}

abstract class AppMapEngine {
  Widget build(BuildContext context, AppMapView view);
}

/// Provided once in `main.dart` (MapLibre + Goong); tests provide a fake.
class AppMapScope extends InheritedWidget {
  const AppMapScope({super.key, required this.engine, required super.child});
  final AppMapEngine engine;

  static AppMapEngine? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppMapScope>()?.engine;

  @override
  bool updateShouldNotify(AppMapScope old) => old.engine != engine;
}

/// The one map widget of the app. Only S13.01, S13.05 and S14.03 build it.
class AppMap extends StatelessWidget {
  const AppMap({
    super.key,
    required this.center,
    required this.semanticsLabel,
    this.zoom = 15,
    this.markers = const [],
    this.fitMarkers = false,
    this.cameraToken = 0,
    this.onCameraIdle,
    this.centerPinLabel,
    this.onMyLocation,
  });

  final LatLng center;
  final String semanticsLabel;
  final double zoom;
  final List<MapMarker> markers;
  final bool fitMarkers;
  final int cameraToken;
  final ValueChanged<LatLng>? onCameraIdle;

  /// A fixed pin at the centre (drag the map under it) with this label.
  final String? centerPinLabel;
  final VoidCallback? onMyLocation;

  @override
  Widget build(BuildContext context) {
    final engine = AppMapScope.of(context);
    final view = AppMapView(
      center: center,
      zoom: zoom,
      markers: markers,
      fitMarkers: fitMarkers,
      cameraToken: cameraToken,
      markerAnimation: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 900),
      dark: Theme.of(context).brightness == Brightness.dark,
      onCameraIdle: onCameraIdle,
    );
    final labels = [?centerPinLabel, for (final m in markers) m.label].join(', ');
    return Semantics(
      container: true,
      label: labels.isEmpty ? semanticsLabel : '$semanticsLabel. $labels',
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: engine == null ? const _MapPlaceholder() : engine.build(context, view),
          ),
          if (centerPinLabel != null)
            IgnorePointer(child: ExcludeSemantics(child: _CenterPin(label: centerPinLabel!))),
          if (onMyLocation != null)
            Positioned(
              right: AppSpace.s3,
              bottom: AppSpace.s3,
              child: _MyLocationButton(onPressed: onMyLocation!),
            ),
        ],
      ),
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? AppColorsDark.surfaceMuted : AppColors.surfaceMuted,
      child: Center(
        child: Text(context.l10n.mapUnavailable, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

class _CenterPin extends StatelessWidget {
  const _CenterPin({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Center(
      child: FractionalTranslation(
        // The pin's tip, not its middle, marks the centre.
        translation: const Offset(0, -0.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: dark ? AppColorsDark.surface : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3, vertical: AppSpace.s1),
                child: Text(label, style: theme.textTheme.labelMedium),
              ),
            ),
            Icon(Icons.place_rounded, size: 36, color: dark ? AppColorsDark.primary : AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _MyLocationButton extends StatelessWidget {
  const _MyLocationButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? AppColorsDark.surface : AppColors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        tooltip: context.l10n.mapMyLocation,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        icon: const Icon(Icons.my_location_rounded),
        onPressed: onPressed,
      ),
    );
  }
}
```

(`[?centerPinLabel, …]` is a null-aware list element, Dart ≥ 3.8; the SDK here is 3.13.)

```dart
// lib/core/map/maplibre_map_engine.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'package:photobooking/core/lat_lng.dart';
import 'package:photobooking/core/map/goong_config.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_map.dart';

/// MapLibre with Goong's Mapbox-compatible style. Markers are circles with a
/// text label; a moved marker glides (≈10 updates per second for
/// [AppMapView.markerAnimation]) without rebuilding the map.
class MaplibreMapEngine implements AppMapEngine {
  const MaplibreMapEngine(this.config);
  final GoongConfig config;

  @override
  Widget build(BuildContext context, AppMapView view) =>
      config.hasMapKey ? _GoongMap(config: config, view: view) : const SizedBox.expand();
}

class _GoongMap extends StatefulWidget {
  const _GoongMap({required this.config, required this.view});
  final GoongConfig config;
  final AppMapView view;

  @override
  State<_GoongMap> createState() => _GoongMapState();
}

class _GoongMapState extends State<_GoongMap> with SingleTickerProviderStateMixin {
  ml.MapLibreMapController? _c;
  bool _styleReady = false;
  final _circles = <String, ml.Circle>{};
  final _symbols = <String, ml.Symbol>{};
  final _shown = <String, LatLng>{};
  final _labels = <String, String>{};
  Map<String, (LatLng, LatLng)> _moves = const {};
  late final AnimationController _anim = AnimationController(vsync: this)..addListener(_step);
  DateTime _lastStep = DateTime.fromMillisecondsSinceEpoch(0);

  static ml.LatLng _ml(LatLng p) => ml.LatLng(p.lat, p.lng);

  static String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static String _colorFor(MapMarkerKind k) => switch (k) {
    MapMarkerKind.self => _hex(AppColors.ctaStart),
    MapMarkerKind.other => _hex(AppColors.ctaMid),
    MapMarkerKind.meetPoint => _hex(AppColors.ctaEnd),
  };

  @override
  void didUpdateWidget(_GoongMap old) {
    super.didUpdateWidget(old);
    if (!_styleReady) {
      return;
    }
    _sync();
    if (old.view.cameraToken != widget.view.cameraToken) {
      _moveCamera();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _onStyleLoaded() async {
    _styleReady = true;
    await _sync();
    if (widget.view.fitMarkers) {
      await _moveCamera();
    }
  }

  Future<void> _sync() async {
    final c = _c;
    if (c == null) {
      return;
    }
    final next = {for (final m in widget.view.markers) m.id: m};
    for (final id in _shown.keys.toList()) {
      if (!next.containsKey(id)) {
        await c.removeCircle(_circles.remove(id)!);
        await c.removeSymbol(_symbols.remove(id)!);
        _shown.remove(id);
        _labels.remove(id);
      }
    }
    final moves = <String, (LatLng, LatLng)>{};
    for (final m in next.values) {
      final was = _shown[m.id];
      if (was == null) {
        _circles[m.id] = await c.addCircle(ml.CircleOptions(
          geometry: _ml(m.at),
          circleRadius: 8,
          circleColor: _colorFor(m.kind),
          circleStrokeColor: _hex(AppColors.foregroundInverse),
          circleStrokeWidth: 3,
        ));
        _symbols[m.id] = await c.addSymbol(ml.SymbolOptions(
          geometry: _ml(m.at),
          textField: m.label,
          textSize: 12,
          textAnchor: 'top',
          textOffset: const Offset(0, 1.2),
          textColor: _hex(AppColors.foreground),
          textHaloColor: _hex(AppColors.surface),
          textHaloWidth: 1.5,
        ));
        _shown[m.id] = m.at;
        _labels[m.id] = m.label;
        continue;
      }
      if (_labels[m.id] != m.label) {
        await c.updateSymbol(_symbols[m.id]!, ml.SymbolOptions(textField: m.label));
        _labels[m.id] = m.label;
      }
      if (was != m.at) {
        moves[m.id] = (was, m.at);
      }
    }
    if (moves.isEmpty) {
      return;
    }
    if (widget.view.markerAnimation == Duration.zero) {
      for (final e in moves.entries) {
        await _place(e.key, e.value.$2);
      }
      return;
    }
    _moves = moves;
    _anim.duration = widget.view.markerAnimation;
    await _anim.forward(from: 0);
  }

  void _step() {
    final now = DateTime.now();
    final last = _anim.value >= 1;
    if (!last && now.difference(_lastStep) < const Duration(milliseconds: 100)) {
      return;
    }
    _lastStep = now;
    final t = Curves.easeInOut.transform(_anim.value);
    for (final e in _moves.entries) {
      _place(e.key, lerpLatLng(e.value.$1, e.value.$2, t));
    }
  }

  Future<void> _place(String id, LatLng p) async {
    final c = _c;
    final circle = _circles[id];
    final symbol = _symbols[id];
    if (c == null || circle == null || symbol == null) {
      return;
    }
    _shown[id] = p;
    await c.updateCircle(circle, ml.CircleOptions(geometry: _ml(p)));
    await c.updateSymbol(symbol, ml.SymbolOptions(geometry: _ml(p)));
  }

  Future<void> _moveCamera() async {
    final c = _c;
    if (c == null) {
      return;
    }
    final v = widget.view;
    if (v.fitMarkers && v.markers.length >= 2) {
      final lats = v.markers.map((m) => m.at.lat);
      final lngs = v.markers.map((m) => m.at.lng);
      await c.animateCamera(ml.CameraUpdate.newLatLngBounds(
        ml.LatLngBounds(
          southwest: ml.LatLng(lats.reduce(math.min), lngs.reduce(math.min)),
          northeast: ml.LatLng(lats.reduce(math.max), lngs.reduce(math.max)),
        ),
        left: 48,
        top: 48,
        right: 48,
        bottom: 48,
      ));
    } else {
      await c.animateCamera(ml.CameraUpdate.newLatLngZoom(_ml(v.center), v.zoom));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    return ml.MapLibreMap(
      styleString: widget.config.styleUrl(dark: v.dark),
      initialCameraPosition: ml.CameraPosition(target: _ml(v.center), zoom: v.zoom),
      onMapCreated: (c) => _c = c,
      onStyleLoadedCallback: _onStyleLoaded,
      trackCameraPosition: true,
      onCameraIdle: () {
        final t = _c?.cameraPosition?.target;
        if (t != null) {
          v.onCameraIdle?.call(LatLng(t.latitude, t.longitude));
        }
      },
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      compassEnabled: false,
      myLocationEnabled: false,
    );
  }
}
```

`lib/core/core.dart`: add exports (alphabetical with the others) for `core/map/goong_config.dart`, `core/widgets/app_map.dart`, `core/widgets/countdown_ring.dart`, `core/widgets/ticking_builder.dart`. Do **not** export `maplibre_map_engine.dart`.

`lib/main.dart`: add `import 'package:photobooking/core/map/maplibre_map_engine.dart';` and wrap the `MyApp(...)` returned by `_Root.build` in
`AppMapScope(engine: MaplibreMapEngine(GoongConfig.fromEnvironment()), child: MyApp(...))` (create the engine once as a `static final` field of `_Root` so rebuilds keep the same instance).

- [ ] **Step 5: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/core && flutter analyze`
Expected: PASS (2 + 3 + 2 + 6 new tests; the existing `AppButton` tests unchanged). If `toARGB32` is reported missing, the Flutter SDK is older than 3.27: use `c.value & 0xFFFFFF` there only.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add pubspec.yaml pubspec.lock lib/core lib/main.dart lib/l10n test/core test/support/fake_map_engine.dart
git commit -m "feat(core): TickingBuilder, CountdownRing, AppButton.danger and AppMap over MapLibre + Goong

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: `ApertureLoader` and `ApertureMark` (screen-level wait)

> **Done ahead of this plan (2026-10-02)**, together with the splash and S08.05 loading states. Skip this task when executing I4; `ApertureLoader` is already exported from `core/core.dart`. Two fixes against the code below were applied: the hold uses `t <= 0.55` (at exactly 0.55 the eased curve gives 0.9999993 and failed the 1e-9 check), and `TickerMode.of` became `TickerMode.valuesOf(context).enabled` (deprecated since Flutter 3.35). CI runs `flutter test --exclude-tags golden`; the `golden` tag is declared in `dart_test.yaml`.

**Files:**
- Create: `lib/core/widgets/aperture_loader.dart`, `test/core/widgets/aperture_loader_test.dart`, `test/core/widgets/goldens/` (generated)
- Modify: `lib/core/core.dart`

**Interfaces:**
- Consumes: `CtaSurface` (`lib/core/widgets/cta_surface.dart`, `CtaSurface({required Widget child, required BorderRadius borderRadius})`), `hostWidget`, `expectIdle`.
- Produces (spec: `shared-components.md` "ApertureLoader · Mới"):
  - `const ApertureMark({super.key, double size = 34, double closure = 0, Color? color})` — one `CustomPainter` drawing `design-system/brand/logo-mono.svg` (circle r 42 in a 100 box, 8 quadratic blades: blade k, `t = k·45° − 90°`, start = centre + 10·dir(t), control = centre + 33·dir(t + 32°), end on the rim = centre + 42·dir(t + 118°); stroke 4.2, round caps); `closure` 0 → 1 rotates each blade about its rim end by 0 → −18°. Default colour `colorScheme.onSurface`.
  - `const ApertureLoader({super.key, double size = 66, bool active = true, String? semanticsLabel})` — a `CtaSurface`-filled circle with the primary button's shadow and a white `ApertureMark` (34/66 of the size); one `AnimationController` (2.4 s, `Curves.easeInOutCubic`, open → closed, held closed 45–55 %, → open, repeating) that runs only while `active`, `TickerMode` is on and animations are not disabled; otherwise it stops completely and shows the open mark; `RepaintBoundary` around it; `Semantics(label: semanticsLabel)`.
  - `double apertureClosureAt(double t)` (the cycle curve, for tests).

Used by plan I4 for the S14.03 resume wait and by plan I5 (S13.03 centre, S13.01 while creating a request and opening payment). Buttons keep `AppButton.loading`; lists keep `AppSkeleton`.

- [x] **Step 1: Write the failing test**

```dart
// test/core/widgets/aperture_loader_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/idle.dart';
import 'widget_host.dart';

void main() {
  test('the cycle: open, closed and held 45–55 %, open again', () {
    expect(apertureClosureAt(0), 0);
    expect(apertureClosureAt(0.45), closeTo(1, 1e-9));
    expect(apertureClosureAt(0.5), 1);
    expect(apertureClosureAt(0.55), closeTo(1, 1e-9));
    expect(apertureClosureAt(1), closeTo(0, 1e-9));
    expect(apertureClosureAt(0.2), inExclusiveRange(0, 1));
  });

  testWidgets('while active there is exactly one ticker; the mark is white on the CTA fill', (tester) async {
    await tester.pumpWidget(hostWidget(const Center(child: ApertureLoader(semanticsLabel: 'Đang tìm'))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, 1);
    expect(find.byType(CtaSurface), findsOneWidget);
    expect(tester.widget<ApertureMark>(find.byType(ApertureMark)).color, Colors.white);
    expect(find.bySemanticsLabel('Đang tìm'), findsOneWidget);
  });

  testWidgets('inactive: stopped, open, idle', (tester) async {
    await tester.pumpWidget(hostWidget(const Center(child: ApertureLoader(active: false))));
    await expectIdle(tester);
    expect(tester.widget<ApertureMark>(find.byType(ApertureMark)).closure, 0);
  });

  testWidgets('switching active off stops the controller', (tester) async {
    await tester.pumpWidget(hostWidget(const Center(child: ApertureLoader())));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(hostWidget(const Center(child: ApertureLoader(active: false))));
    await expectIdle(tester);
  });

  testWidgets('reduced motion: static and open, still labelled', (tester) async {
    await tester.pumpWidget(hostWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Center(child: ApertureLoader(semanticsLabel: 'Đang chờ thanh toán')),
      ),
    ));
    await expectIdle(tester);
    expect(tester.widget<ApertureMark>(find.byType(ApertureMark)).closure, 0);
    expect(find.bySemanticsLabel('Đang chờ thanh toán'), findsOneWidget);
  });

  testWidgets('a muted TickerMode (screen not visible) runs no ticker', (tester) async {
    await tester.pumpWidget(hostWidget(const TickerMode(enabled: false, child: Center(child: ApertureLoader()))));
    await expectIdle(tester);
  });

  for (final b in Brightness.values) {
    for (final closure in [0.0, 0.5, 1.0]) {
      testWidgets('golden: closure $closure, ${b.name}', tags: ['golden'], (tester) async {
        await tester.pumpWidget(hostWidget(
          Center(
            child: RepaintBoundary(
              key: const Key('mark'),
              child: SizedBox.square(
                dimension: 100,
                child: ColoredBox(
                  color: b == Brightness.dark ? AppColorsDark.background : AppColors.background,
                  child: Center(child: ApertureMark(size: 80, closure: closure)),
                ),
              ),
            ),
          ),
          brightness: b,
        ));
        await expectLater(
          find.byKey(const Key('mark')),
          matchesGoldenFile('goldens/aperture_mark_${(closure * 10).round()}_${b.name}.png'),
        );
      });
    }
  }
}
```

- [x] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/aperture_loader_test.dart`
Expected: FAIL to compile, `ApertureLoader` undefined.

- [x] **Step 3: Implement**

```dart
// lib/core/widgets/aperture_loader.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/cta_surface.dart';

const _cycle = Duration(milliseconds: 2400);

/// Closure (0 open … 1 closed) at [t] ∈ [0, 1] of one 2.4 s cycle:
/// close over 0–45 %, hold to 55 %, open again by 100 %.
double apertureClosureAt(double t) {
  const ease = Curves.easeInOutCubic;
  if (t <= 0.45) {
    return ease.transform(t / 0.45);
  }
  if (t < 0.55) {
    return 1;
  }
  return ease.transform((1 - t) / 0.45);
}

/// The monochrome aperture of `design-system/brand/logo-mono.svg`, drawn in
/// one painter. [closure] turns each blade about its rim end by up to −18°.
class ApertureMark extends StatelessWidget {
  const ApertureMark({super.key, this.size = 34, this.closure = 0, this.color});

  final double size;
  final double closure;
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: AperturePainter(
        closure: closure,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

class AperturePainter extends CustomPainter {
  const AperturePainter({required this.closure, required this.color});
  final double closure;
  final Color color;

  static double _rad(double deg) => deg * math.pi / 180;
  static Offset _dir(double rad) => Offset(math.cos(rad), math.sin(rad));
  static Offset _about(Offset q, Offset pivot, double a) {
    final d = q - pivot;
    return pivot + Offset(d.dx * math.cos(a) - d.dy * math.sin(a), d.dx * math.sin(a) + d.dy * math.cos(a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    const c = Offset(50, 50);
    canvas.drawCircle(c, 42, stroke);
    final turn = _rad(-18 * closure.clamp(0.0, 1.0));
    final blades = Path();
    for (var k = 0; k < 8; k++) {
      final t = _rad(k * 45.0 - 90);
      final end = c + _dir(t + _rad(118)) * 42;
      final start = _about(c + _dir(t) * 10, end, turn);
      final control = _about(c + _dir(t + _rad(32)) * 33, end, turn);
      blades
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    }
    canvas.drawPath(blades, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(AperturePainter old) => old.closure != closure || old.color != color;
}

/// The app's screen-level wait (S13.03 searching, S13.01 opening payment, S14.03
/// resuming…). Runs only while [active] and visible; reduced motion shows
/// the open mark, still.
class ApertureLoader extends StatefulWidget {
  const ApertureLoader({super.key, this.size = 66, this.active = true, this.semanticsLabel});

  final double size;
  final bool active;
  final String? semanticsLabel;

  @override
  State<ApertureLoader> createState() => _ApertureLoaderState();
}

class _ApertureLoaderState extends State<ApertureLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: _cycle);

  void _sync() {
    final run = widget.active && TickerMode.of(context) && !MediaQuery.disableAnimationsOf(context);
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ApertureLoader old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(widget.size / 2);
    return Semantics(
      label: widget.semanticsLabel,
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Same glow as the primary button (_GradientFill in app_button.dart).
            boxShadow: [
              BoxShadow(
                color: dark ? AppColors.ctaMid.withValues(alpha: 0.35) : AppColors.ctaLightStart.withValues(alpha: 0.25),
                blurRadius: dark ? 18 : 12,
                offset: Offset(0, dark ? 8 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: SizedBox.square(
              dimension: widget.size,
              child: CtaSurface(
                borderRadius: radius,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (_, _) => ApertureMark(
                      size: widget.size * 34 / 66,
                      closure: _c.isAnimating ? apertureClosureAt(_c.value) : 0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

In `lib/core/core.dart` add `export 'package:photobooking/core/widgets/aperture_loader.dart';`.

- [x] **Step 4: Generate the goldens once, look at them, then run normally**

Run: `flutter test --update-goldens --tags golden test/core/widgets/aperture_loader_test.dart`, open the six PNGs under `test/core/widgets/goldens/` and check against `design-system/brand/logo-mono.svg` (closure 0 must look identical to the SVG; 1 shows the blades turned towards the centre). Then `flutter test test/core/widgets/aperture_loader_test.dart && flutter analyze`.
Expected: PASS (6 behaviour tests + 6 goldens). Goldens differ slightly between macOS and Linux font/AA stacks; there is no text in them, but if CI on Linux reports pixel diffs, regenerate them in CI's image and commit those, or run goldens only locally with `--exclude-tags golden` in CI (note which in the PR).

- [x] **Step 5: Commit**

```bash
dart format lib test
git add lib/core/widgets/aperture_loader.dart lib/core/core.dart test/core/widgets/aperture_loader_test.dart test/core/widgets/goldens
git commit -m "feat(core): ApertureLoader, the brand aperture wait

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: `InstantSessionController` (availability, presence, offers, auto-off, battery)

**Files:**
- Create: `lib/features/instant_common/instant_services.dart`, `lib/features/instant_work/instant_session_controller.dart`, `test/support/instant_world.dart`, `test/features/instant_work/instant_session_controller_test.dart`, `test/features/instant_common/push_registration_test.dart`
- Modify: `lib/data/instant/instant_providers.dart` (`instantOfferProvider`), `lib/main.dart` (watch `pushRegistrationProvider`), `lib/l10n/app_vi.arb`, `pubspec.yaml`, `pubspec.lock` (dev `fake_async`)

**Interfaces:**
- Consumes: Tasks 1–6; `authRepositoryProvider`, `authStateProvider`, `userRepositoryProvider` (`lib/data/auth/auth_providers.dart`), `FakeAuthRepository`, `FakeUserRepository`; `clockProvider`; `locationRepositoryProvider`, `FakeLocationRepository`, `LocationPermissionStatus`; `sharedPreferencesProvider` (`lib/features/settings/theme_mode_controller.dart`); 2a `userContactRepositoryProvider`, `FakeUserContactRepository`, `UserContact`; 2b `externalLauncherProvider`, `FakeExternalLauncher`, `contactLinkRepositoryProvider`, `FakeContactLinkRepository`.
- Produces:
  - Providers (`instant_services.dart`): `trackingLocationProvider`, `foregroundSessionProvider` (Android `ForegroundTaskSession`, iOS `NoopForegroundSession`), `batteryLevelProvider`, `instantNotifierProvider`, `pushMessagesProvider`, `deviceRegistryProvider`, `pushRegistrationProvider` (`Provider<void>`: registers the token for the signed-in user, again on refresh).
  - `instantOfferProvider` (`StreamProvider.autoDispose<InstantOffer?>`, the signed-in photographer's `instant_offers/{uid}`).
  - Constants `autoOffAfter = Duration(minutes: 30)`, `autoOffAnswerWindow = Duration(minutes: 5)`, `lowBatteryPercent = 15`.
  - `class InstantSessionState` (`online`, `switching`, `settings`, `packages`, `locationGranted`, `activeRequestId`, `pendingOffer`, `askStillAvailable`, `askLowBattery`, `autoTurnedOff`, `error`; getters `helpReady`, `reasons` (server reasons + `locationDenied` from the phone), `canGoOnline`).
  - `class InstantSessionController extends Notifier<InstantSessionState>` with `Future<void> refresh()`, `Future<bool> requestLocation()`, `Future<void> acceptPriceList()`, `Future<void> setHelpReady(bool on)`, `Future<bool> goOnline()`, `Future<void> goOffline({bool auto = false})`, `Future<void> keepAvailable()`, `void dismissLowBattery()`, `void appHidden()`, `void appShown()`, `Future<void> jobStarted(String requestId, {bool routeSharing = true})`, `Future<void> setRouteSharing(bool on)`, `Future<void> jobEnded()`; `instantSessionProvider` (keep-alive `NotifierProvider`).
  - Test support `InstantWorld` (all fakes, `init()`, `overrides`, `now`, `advance(FakeAsync, Duration)`, `fixAt(double northMeters, {double accuracy})`, `offer({String id, Duration ttl})`, `view(InstantStatus)`, `eligibleSettings`).
  - l10n: `instantForegroundChannel`, `instantForegroundTitle`, `instantForegroundText`, `instantStillAvailableTitle`, `instantStillAvailableBody`, `instantLowBatteryTitle`, `instantLowBatteryBody`.

Behaviour (spec §2.2, §9): going online asks for location permission (when in use) and notification permission, takes **one** medium fix (or reuses one taken by S14.01 in the last minute), calls `PUT /v1/presence`, starts the foreground service, a 300 m presence stream and a 5-minute heartbeat that re-sends the last fix (no GPS fix), and listens to `instant_offers/{uid}`. While a job is active, idle presence and the offer listener pause (one offer at a time) and resume after it if still online. Going offline (switch, "Tắt" in the notification, auto-off, `not_eligible`) cancels every stream and timer, stops the service and sends `online: false`. In the background for 30 minutes → "Vẫn muốn nhận việc?" notification; no answer in 5 minutes → off; opening the app counts as an answer. Battery below 15 % → one prompt per session.

- [ ] **Step 1: Add the dev dependency**

```bash
flutter pub add dev:fake_async
```

- [ ] **Step 2: Write the failing tests**

```dart
// test/support/instant_world.dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/contact/external_launcher.dart';
import 'package:photobooking/data/instant/battery_level.dart';
import 'package:photobooking/data/instant/fake_instant_repositories.dart';
import 'package:photobooking/data/instant/foreground_session.dart';
import 'package:photobooking/data/instant/instant_mirror.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_notifier.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/instant/instant_push.dart';
import 'package:photobooking/data/instant/tracking_location.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/instant_common/instant_services.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_map_engine.dart';

const eligibleSettings = InstantSettings(
  acceptedPriceListVersion: 3,
  currentPriceListVersion: 3,
  helpReady: false,
  eligible: true,
  reasons: [],
);

/// Every port of Chụp ngay as a fake, signed in as a photographer with a
/// phone number. Plan I5 extends this world for the customer side.
class InstantWorld {
  InstantWorld({this.role = UserRole.photographer});

  final UserRole role;
  final auth = FakeAuthRepository();
  final users = FakeUserRepository();
  final contacts = FakeUserContactRepository();
  final presence = FakePresenceRepository();
  final jobs = FakeInstantJobRepository();
  final mirror = FakeInstantMirror();
  final location = FakeTrackingLocationSource();
  FakeLocationRepository permission = FakeLocationRepository(status: LocationPermissionStatus.granted);
  final foreground = FakeForegroundSession();
  final notifier = FakeInstantNotifier();
  final push = FakePushMessages();
  final devices = FakeDeviceRegistry();
  final battery = FakeBatteryLevel(80);
  final launcher = FakeExternalLauncher();
  final links = FakeContactLinkRepository();
  final map = FakeMapEngine();
  DateTime now = DateTime.utc(2026, 10, 1, 8, 15);
  late String uid;
  late SharedPreferences prefs;

  Future<void> init() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final u = await auth.registerWithEmail('nag@example.vn', 'password1', 'Minh Trí');
    uid = u.uid;
    await users.ensureProfile(u);
    await users.setRole(uid, role);
    contacts.seed(uid, const UserContact(phone: '+84903123456'));
    jobs.clock = () => now;
    location.current = fixAt(-1500);
  }

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(auth),
    userRepositoryProvider.overrideWithValue(users),
    userContactRepositoryProvider.overrideWithValue(contacts),
    sharedPreferencesProvider.overrideWithValue(prefs),
    clockProvider.overrideWithValue(() => now),
    presenceRepositoryProvider.overrideWithValue(presence),
    instantJobRepositoryProvider.overrideWithValue(jobs),
    instantMirrorProvider.overrideWithValue(mirror),
    locationRepositoryProvider.overrideWithValue(permission),
    trackingLocationProvider.overrideWithValue(location),
    foregroundSessionProvider.overrideWithValue(foreground),
    instantNotifierProvider.overrideWithValue(notifier),
    pushMessagesProvider.overrideWithValue(push),
    deviceRegistryProvider.overrideWithValue(devices),
    batteryLevelProvider.overrideWithValue(battery),
    externalLauncherProvider.overrideWithValue(launcher),
    contactLinkRepositoryProvider.overrideWithValue(links),
  ];

  /// Moves fake time in 1 s steps so periodic timers see the right clock.
  void advance(FakeAsync async, Duration d) {
    const step = Duration(seconds: 1);
    for (var t = Duration.zero; t < d; t += step) {
      now = now.add(step);
      async.elapse(step);
    }
    async.flushMicrotasks();
  }

  /// A fix [northMeters] north of the job's meet point (Công viên Tao Đàn).
  LocationFix fixAt(double northMeters, {double accuracy = 12}) => LocationFix(
    lat: jobs.job.meetPoint.lat + northMeters / 111195,
    lng: jobs.job.meetPoint.lng,
    accuracyM: accuracy,
    at: now,
  );

  InstantOffer offer({String id = 'O1', Duration ttl = const Duration(seconds: 30)}) => InstantOffer(
    offerId: id,
    requestId: 'R1',
    packageCode: InstantPackageCode.p60,
    genre: InstantGenre.portrait,
    payoutVnd: 552000,
    distanceKm: 2.1,
    travelMinutes: 8,
    area: 'Phường Bến Thành, Quận 1',
    note: 'Chụp chân dung ở hồ, mình mặc áo dài trắng.',
    expiresAt: now.add(ttl),
  );

  InstantRequestView view(InstantStatus status, {String id = 'R1'}) => InstantRequestView(
    id: id,
    status: status,
    customerId: 'c1',
    photographerId: uid,
    packageCode: InstantPackageCode.p60,
    genre: InstantGenre.portrait,
    amountVnd: 690000,
    expand: false,
    round: 1,
    meetPoint: jobs.job.meetPoint,
    requestedAt: now.subtract(const Duration(minutes: 6)),
    assignedAt: now.subtract(const Duration(minutes: 1)),
    updatedAt: now,
  );
}
```

```dart
// test/features/instant_work/instant_session_controller_test.dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/tracking_location.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/instant_work/instant_session_controller.dart';

import '../../support/instant_world.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late InstantWorld w;

  setUp(() async {
    w = InstantWorld();
    await w.init();
    w.presence.settingsValue = eligibleSettings;
  });

  ProviderContainer container() {
    final c = ProviderContainer(overrides: w.overrides);
    addTearDown(c.dispose);
    return c;
  }

  InstantSessionState state(ProviderContainer c) => c.read(instantSessionProvider);
  InstantSessionController session(ProviderContainer c) => c.read(instantSessionProvider.notifier);

  test('going online: one fix, presence on, the foreground notification, one offer listener', () {
    fakeAsync((async) {
      final c = container();
      session(c).goOnline();
      async.flushMicrotasks();
      expect(state(c).online, isTrue);
      expect(w.location.currentFixCalls, 1);
      expect(w.location.accuracies, [FixAccuracy.medium]);
      expect(w.presence.presenceCalls.last.online, isTrue);
      expect(w.presence.presenceCalls.last.fix, isNotNull);
      expect(w.foreground.running, isTrue);
      expect(w.foreground.lastTitle, 'Đang nhận việc chụp ngay');
      expect(w.foreground.lastStopLabel, 'Tắt');
      expect((w.location.presenceListeners, w.location.routeListeners), (1, 0));
      expect(w.mirror.listenersOf('instant_offers/${w.uid}'), 1);
      expect(w.notifier.permissionRequests, 1);
    });
  });

  test('standing still for 30 minutes: no new GPS fix, one presence refresh per 5 minutes', () {
    fakeAsync((async) {
      final c = container();
      session(c).goOnline();
      async.flushMicrotasks();
      final before = w.presence.presenceCalls.length;
      w.advance(async, const Duration(minutes: 30));
      expect(w.location.currentFixCalls, 1);
      expect(w.location.presenceFixes, 0);
      final refreshes = w.presence.presenceCalls.skip(before).toList();
      expect(refreshes, hasLength(6));
      expect(refreshes.every((p) => p.online && p.fix == w.location.current), isTrue);
    });
  });

  test('moving: more than 300 m is sent at once, less waits for the heartbeat', () {
    fakeAsync((async) {
      final c = container();
      session(c).goOnline();
      async.flushMicrotasks();
      final before = w.presence.presenceCalls.length;
      w.advance(async, const Duration(minutes: 1));
      w.location.movePresence(w.fixAt(-1100));
      async.flushMicrotasks();
      expect(w.presence.presenceCalls.length - before, 1, reason: '400 m from the last sent fix');
      w.advance(async, const Duration(seconds: 30));
      w.location.movePresence(w.fixAt(-1000));
      async.flushMicrotasks();
      expect(w.presence.presenceCalls.length - before, 1, reason: 'only 100 m more');
    });
  });

  test('going offline stops GPS, the service, the listener and the heartbeat, and tells the service', () {
    fakeAsync((async) {
      final c = container();
      session(c).goOnline();
      async.flushMicrotasks();
      session(c).goOffline();
      async.flushMicrotasks();
      expect(state(c).online, isFalse);
      expect(w.location.activeStreams, 0);
      expect(w.foreground.running, isFalse);
      expect(w.mirror.openListeners, 0);
      expect(w.presence.presenceCalls.last.online, isFalse);
      final n = w.presence.presenceCalls.length;
      w.advance(async, const Duration(minutes: 20));
      expect(w.presence.presenceCalls.length, n);
    });
  });

  test('"Tắt" in the notification turns availability off', () {
    fakeAsync((async) {
      final c = container();
      session(c).goOnline();
      async.flushMicrotasks();
      w.foreground.pressStop();
      async.flushMicrotasks();
      expect(state(c).online, isFalse);
      expect(w.foreground.running, isFalse);
    });
  });

  test('30 minutes in the background asks "Vẫn muốn nhận việc?"; 5 more minutes turns it off', () {
    fakeAsync((async) {
      final c = container();
      session(c).goOnline();
      async.flushMicrotasks();
      session(c).appHidden();
      w.advance(async, const Duration(minutes: 29));
      expect(w.notifier.prompts, isEmpty);
      w.advance(async, const Duration(minutes: 1));
      expect(w.notifier.prompts, ['still_available']);
      expect(state(c).askStillAvailable, isTrue);
      w.advance(async, const Duration(minutes: 5));
      expect(state(c).online, isFalse);
      expect(state(c).autoTurnedOff, isTrue);
      expect(w.location.activeStreams, 0);
      expect(w.foreground.running, isFalse);
    });
  });

  test('"Vẫn nhận" keeps it on and asks again 30 minutes later', () {
    fakeAsync((async) {
      final c = container();
      session(c).goOnline();
      async.flushMicrotasks();
      session(c).appHidden();
      w.advance(async, const Duration(minutes: 30));
      session(c).keepAvailable();
      w.advance(async, const Duration(minutes: 10));
      expect(state(c).online, isTrue);
      w.advance(async, const Duration(minutes: 20));
      expect(w.notifier.prompts, ['still_available', 'still_available']);
    });
  });

  test('opening the app resets the 30-minute clock', () {
    fakeAsync((async) {
      final c = container();
      session(c).goOnline();
      async.flushMicrotasks();
      session(c).appHidden();
      w.advance(async, const Duration(minutes: 20));
      session(c).appShown();
      session(c).appHidden();
      w.advance(async, const Duration(minutes: 20));
      expect(w.notifier.prompts, isEmpty);
    });
  });

  test('battery below 15 %: one prompt per session, a notification only in the background', () {
    fakeAsync((async) {
      final c = container();
      session(c).goOnline();
      async.flushMicrotasks();
      expect(state(c).askLowBattery, isFalse);
      session(c).appHidden();
      w.battery.value = 12;
      w.advance(async, const Duration(minutes: 5));
      expect(state(c).askLowBattery, isTrue);
      expect(w.notifier.prompts, ['low_battery']);
      w.advance(async, const Duration(minutes: 10));
      expect(w.notifier.prompts, ['low_battery']);
    });
  });

  test('not_eligible: stays offline, nothing runs, the reasons come from the service', () {
    fakeAsync((async) {
      final c = container();
      w.presence.failPresenceWith = DispatchError.notEligible;
      w.presence.settingsValue = const InstantSettings(
        acceptedPriceListVersion: 3,
        currentPriceListVersion: 3,
        helpReady: false,
        eligible: false,
        reasons: [EligibilityReason.noPhone],
      );
      session(c).goOnline();
      async.flushMicrotasks();
      expect(state(c).online, isFalse);
      expect(state(c).reasons, [EligibilityReason.noPhone]);
      expect(state(c).error, DispatchError.notEligible);
      expect((w.foreground.running, w.location.activeStreams, w.mirror.openListeners), (false, 0, 0));
    });
  });

  test('location refused: no presence call and the phone adds location_denied', () {
    fakeAsync((async) {
      w.permission = FakeLocationRepository(
        status: LocationPermissionStatus.denied,
        statusAfterRequest: LocationPermissionStatus.denied,
      );
      final c = container();
      session(c).goOnline();
      async.flushMicrotasks();
      expect(state(c).online, isFalse);
      expect(w.presence.presenceCalls, isEmpty);
      expect(state(c).reasons, contains(EligibilityReason.locationDenied));
      expect(w.location.currentFixCalls, 0);
    });
  });

  test('an offer becomes pendingOffer; in the background also a full-screen notification; gone clears it', () {
    fakeAsync((async) {
      final c = container();
      session(c).goOnline();
      async.flushMicrotasks();
      session(c).appHidden();
      w.mirror.setOffer(w.uid, w.offer());
      async.flushMicrotasks();
      expect(state(c).pendingOffer!.offerId, 'O1');
      expect(w.notifier.offers, ['O1']);
      w.mirror.setOffer(w.uid, null);
      async.flushMicrotasks();
      expect(state(c).pendingOffer, isNull);
      expect(w.notifier.cancelled, ['O1']);
    });
  });

  test('a job pauses idle presence and offers; ending it resumes them', () {
    fakeAsync((async) {
      final c = container();
      session(c).goOnline();
      async.flushMicrotasks();
      session(c).jobStarted('R1');
      async.flushMicrotasks();
      expect((w.location.presenceListeners, w.mirror.listenersOf('instant_offers/${w.uid}')), (0, 0));
      expect(w.foreground.running, isTrue, reason: 'route sharing keeps the service');
      session(c).setRouteSharing(false);
      async.flushMicrotasks();
      expect(w.foreground.running, isFalse, reason: 'arrived: no location needed');
      session(c).jobEnded();
      async.flushMicrotasks();
      expect((w.location.presenceListeners, w.mirror.listenersOf('instant_offers/${w.uid}')), (1, 1));
      expect(w.foreground.running, isTrue);
    });
  });

  test('accepting the price list and "Sẵn sàng hỗ trợ"', () {
    fakeAsync((async) {
      w.presence.settingsValue = const InstantSettings(
        acceptedPriceListVersion: 2,
        currentPriceListVersion: 3,
        helpReady: false,
        eligible: false,
        reasons: [EligibilityReason.priceListNotAccepted],
      );
      final c = container();
      session(c).refresh();
      async.flushMicrotasks();
      expect(state(c).canGoOnline, isFalse);
      expect(state(c).packages, isNotNull);
      session(c).acceptPriceList();
      async.flushMicrotasks();
      expect(state(c).settings!.priceListAccepted, isTrue);
      expect(state(c).canGoOnline, isTrue);
      session(c).setHelpReady(true);
      async.flushMicrotasks();
      expect(state(c).helpReady, isTrue);
    });
  });
}
```

```dart
// test/features/instant_common/push_registration_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/instant_common/instant_services.dart';

import '../../support/instant_world.dart';

void main() {
  test('the signed-in user\'s token is registered, and again after a refresh', () async {
    final w = InstantWorld();
    await w.init();
    final c = ProviderContainer(overrides: w.overrides);
    addTearDown(c.dispose);
    c.listen(pushRegistrationProvider, (_, _) {});
    await pumpEventQueue();
    expect(w.devices.registered, [(w.uid, 'fake-token')]);
    w.push.refreshToken('tok-2');
    await pumpEventQueue();
    expect(w.devices.registered.last, (w.uid, 'tok-2'));
  });
}
```

- [ ] **Step 3: Run and see them fail**

Run: `flutter test test/features/instant_work/instant_session_controller_test.dart test/features/instant_common`
Expected: FAIL to compile (`instant_services.dart`, `instant_session_controller.dart` missing).

- [ ] **Step 4: Implement**

Strings (`lib/l10n/app_vi.arb`, then `flutter gen-l10n`):

```json
  "instantForegroundChannel": "Chụp ngay",
  "instantForegroundTitle": "Đang nhận việc chụp ngay",
  "instantForegroundText": "Vị trí chỉ được chia sẻ khi bạn sẵn sàng hoặc đang đến.",
  "instantStillAvailableTitle": "Vẫn muốn nhận việc?",
  "instantStillAvailableBody": "Bạn đã bật Live Shutter 30 phút mà chưa mở app. Không trả lời trong 5 phút thì sẽ tự tắt.",
  "instantLowBatteryTitle": "Pin yếu",
  "instantLowBatteryBody": "Pin dưới 15%. Tắt Live Shutter để tiết kiệm pin?",
```

```dart
// lib/features/instant_common/instant_services.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/instant/battery_level.dart';
import 'package:photobooking/data/instant/firebase_push_messages.dart';
import 'package:photobooking/data/instant/firestore_device_registry.dart';
import 'package:photobooking/data/instant/foreground_session.dart';
import 'package:photobooking/data/instant/foreground_task_session.dart';
import 'package:photobooking/data/instant/geolocator_tracking_location.dart';
import 'package:photobooking/data/instant/instant_notifier.dart';
import 'package:photobooking/data/instant/instant_push.dart';
import 'package:photobooking/data/instant/local_instant_notifier.dart';
import 'package:photobooking/data/instant/tracking_location.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

final trackingLocationProvider = Provider<TrackingLocationSource>(
  (ref) => const GeolocatorTrackingLocation(),
);

final foregroundSessionProvider = Provider<ForegroundSession>((ref) {
  final s = defaultTargetPlatform == TargetPlatform.android
      ? ForegroundTaskSession()
      : NoopForegroundSession();
  ref.onDispose(s.dispose);
  return s;
});

final batteryLevelProvider = Provider<BatteryLevel>((ref) => BatteryPlusLevel());

final instantNotifierProvider = Provider<InstantNotifier>((ref) {
  final n = LocalInstantNotifier();
  ref.onDispose(n.dispose);
  return n;
});

final pushMessagesProvider = Provider<PushMessages>((ref) => FirebasePushMessages());

final deviceRegistryProvider = Provider<DeviceRegistry>(
  (ref) => FirestoreDeviceRegistry(prefs: ref.watch(sharedPreferencesProvider)),
);

/// Keeps `devices/{uid}_{install}` current for the signed-in user so the
/// dispatch service can push offers and status changes. Watched by `_Root`.
final pushRegistrationProvider = Provider<void>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return;
  }
  final push = ref.watch(pushMessagesProvider);
  final registry = ref.watch(deviceRegistryProvider);
  Future<void> register(String? token) async {
    if (token == null) {
      return;
    }
    try {
      await registry.register(uid: user.uid, token: token);
    } on Object {
      // Tried again at the next start or token refresh.
    }
  }

  push.token().then(register);
  final sub = push.tokenRefresh.listen(register);
  ref.onDispose(sub.cancel);
});
```

Append to `lib/data/instant/instant_providers.dart` (import `package:photobooking/data/auth/auth_providers.dart`):

```dart
/// The signed-in photographer's pending offer (S14.02 reads it directly, so a
/// cold start from a notification works even before the session is online).
final instantOfferProvider = StreamProvider.autoDispose<InstantOffer?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) {
    return Stream.value(null);
  }
  return ref.watch(instantMirrorProvider).offerFor(uid);
});
```

```dart
// lib/features/instant_work/instant_session_controller.dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/instant/instant_labels.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/instant/instant_push.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/instant_common/instant_services.dart';
import 'package:photobooking/features/instant_work/instant_rules.dart';
import 'package:photobooking/l10n/app_localizations.dart';

const autoOffAfter = Duration(minutes: 30);
const autoOffAnswerWindow = Duration(minutes: 5);
const lowBatteryPercent = 15;

const _keep = Object();

class InstantSessionState {
  const InstantSessionState({
    this.online = false,
    this.switching = false,
    this.settings,
    this.packages,
    this.locationGranted = true,
    this.activeRequestId,
    this.pendingOffer,
    this.askStillAvailable = false,
    this.askLowBattery = false,
    this.autoTurnedOff = false,
    this.error,
  });

  final bool online;
  final bool switching;
  final InstantSettings? settings;
  final PackagesQuote? packages;
  final bool locationGranted;
  final String? activeRequestId;
  final InstantOffer? pendingOffer;
  final bool askStillAvailable;
  final bool askLowBattery;
  final bool autoTurnedOff;
  final DispatchError? error;

  bool get helpReady => settings?.helpReady ?? false;

  /// The service's reasons, plus the one only the phone knows.
  List<EligibilityReason> get reasons => [
    ...?settings?.reasons.where((r) => r != EligibilityReason.locationDenied),
    if (!locationGranted) EligibilityReason.locationDenied,
  ];

  bool get canGoOnline => settings != null && reasons.isEmpty;

  InstantSessionState copyWith({
    bool? online,
    bool? switching,
    Object? settings = _keep,
    Object? packages = _keep,
    bool? locationGranted,
    Object? activeRequestId = _keep,
    Object? pendingOffer = _keep,
    bool? askStillAvailable,
    bool? askLowBattery,
    bool? autoTurnedOff,
    Object? error = _keep,
  }) => InstantSessionState(
    online: online ?? this.online,
    switching: switching ?? this.switching,
    settings: identical(settings, _keep) ? this.settings : settings as InstantSettings?,
    packages: identical(packages, _keep) ? this.packages : packages as PackagesQuote?,
    locationGranted: locationGranted ?? this.locationGranted,
    activeRequestId: identical(activeRequestId, _keep) ? this.activeRequestId : activeRequestId as String?,
    pendingOffer: identical(pendingOffer, _keep) ? this.pendingOffer : pendingOffer as InstantOffer?,
    askStillAvailable: askStillAvailable ?? this.askStillAvailable,
    askLowBattery: askLowBattery ?? this.askLowBattery,
    autoTurnedOff: autoTurnedOff ?? this.autoTurnedOff,
    error: identical(error, _keep) ? this.error : error as DispatchError?,
  );
}

/// Owns "Live Shutter" for the whole app lifetime (keep-alive): the
/// screens only show it. Every location stream, timer and listener it starts
/// is cancelled in [goOffline] and [jobStarted].
class InstantSessionController extends Notifier<InstantSessionState> {
  final AppLocalizations _l = lookupAppLocalizations(const Locale('vi'));
  StreamSubscription<LocationFix>? _presenceSub;
  StreamSubscription<InstantOffer?>? _offerSub;
  StreamSubscription<void>? _stopSub;
  StreamSubscription<InstantPush>? _pushSub;
  AppLifecycleListener? _life;
  Timer? _heartbeat;
  Timer? _idle;
  Timer? _answer;
  LocationFix? _lastFix;
  LocationFix? _lastSent;
  DateTime? _lastSentAt;
  bool _background = false;
  bool _batteryAsked = false;
  bool _routeSharing = false;

  DateTime _now() => ref.read(clockProvider)();
  String? get _uid => ref.read(authRepositoryProvider).currentUser?.uid;

  @override
  InstantSessionState build() {
    _stopSub = ref.read(foregroundSessionProvider).stopPressed.listen((_) => goOffline());
    _pushSub = ref.read(pushMessagesProvider).foreground.listen(_onPush);
    _life = AppLifecycleListener(onHide: appHidden, onShow: appShown);
    ref.onDispose(_teardown);
    return const InstantSessionState();
  }

  LocationFix? _freshFix() {
    final f = _lastFix;
    return f != null && _now().difference(f.at) < const Duration(minutes: 1) ? f : null;
  }

  /// S14.01 opened: settings, permission, and the price list where the
  /// photographer is (one fix, reused by [goOnline]).
  Future<void> refresh() async {
    final status = await ref.read(locationRepositoryProvider).permissionStatus();
    final granted = status == LocationPermissionStatus.granted;
    try {
      final settings = await ref.read(presenceRepositoryProvider).settings();
      state = state.copyWith(settings: settings, locationGranted: granted, error: null);
    } on DispatchException catch (e) {
      state = state.copyWith(locationGranted: granted, error: e.error);
      return;
    }
    if (!granted || state.packages != null) {
      return;
    }
    final fix = _freshFix() ?? await ref.read(trackingLocationProvider).currentFix();
    if (fix == null) {
      return;
    }
    _lastFix = fix;
    try {
      state = state.copyWith(packages: await ref.read(presenceRepositoryProvider).packagesNear(fix.latLng));
    } on DispatchException catch (e) {
      state = state.copyWith(error: e.error);
    }
  }

  /// "When in use" only; a permanent refusal opens the OS settings.
  Future<bool> requestLocation() async {
    final repo = ref.read(locationRepositoryProvider);
    var s = await repo.permissionStatus();
    if (s == LocationPermissionStatus.notAsked || s == LocationPermissionStatus.denied) {
      s = await repo.request();
    }
    if (s == LocationPermissionStatus.deniedForever || s == LocationPermissionStatus.serviceOff) {
      await repo.openSettings();
    }
    final ok = s == LocationPermissionStatus.granted;
    state = state.copyWith(locationGranted: ok);
    if (ok) {
      await refresh();
    }
    return ok;
  }

  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
      state = state.copyWith(error: null);
    } on DispatchException catch (e) {
      state = state.copyWith(error: e.error);
    }
  }

  Future<void> acceptPriceList() async {
    final s = state.settings;
    if (s == null) {
      return;
    }
    await _guard(() async {
      state = state.copyWith(
        settings: await ref.read(presenceRepositoryProvider).updateSettings(acceptPriceListVersion: s.currentPriceListVersion),
      );
    });
  }

  Future<void> setHelpReady(bool on) => _guard(() async {
    state = state.copyWith(settings: await ref.read(presenceRepositoryProvider).updateSettings(helpReady: on));
    if (state.online && state.activeRequestId == null) {
      await _send(_lastFix);
    }
  });

  Future<bool> goOnline() async {
    if (state.online || state.switching) {
      return state.online;
    }
    final uid = _uid;
    if (uid == null) {
      return false;
    }
    state = state.copyWith(switching: true, error: null, autoTurnedOff: false);
    try {
      if (!await requestLocation()) {
        return false;
      }
      final notifier = ref.read(instantNotifierProvider);
      await notifier.init(_l);
      await notifier.requestPermissions();
      final fix = _freshFix() ?? await ref.read(trackingLocationProvider).currentFix();
      _lastFix = fix ?? _lastFix;
      await ref.read(presenceRepositoryProvider).setPresence(online: true, helpReady: state.helpReady, fix: fix);
      _lastSent = fix;
      _lastSentAt = _now();
      state = state.copyWith(online: true);
      await _startIdleSharing();
      _offerSub ??= ref.read(instantMirrorProvider).offerFor(uid).listen(_onOffer);
      await _checkBattery();
      if (_background) {
        _armIdleTimer();
      }
      return true;
    } on DispatchException catch (e) {
      if (e.error == DispatchError.notEligible) {
        await refresh();
      }
      state = state.copyWith(error: e.error);
      return false;
    } finally {
      state = state.copyWith(switching: false);
    }
  }

  Future<void> goOffline({bool auto = false}) async {
    final was = state.online;
    _stopIdleSharing();
    await _offerSub?.cancel();
    _offerSub = null;
    _idle?.cancel();
    _idle = null;
    _answer?.cancel();
    _answer = null;
    state = state.copyWith(
      online: false,
      pendingOffer: null,
      askStillAvailable: false,
      askLowBattery: false,
      autoTurnedOff: auto && was,
    );
    await _syncForeground();
    await ref.read(instantNotifierProvider).cancelPrompts();
    if (was) {
      try {
        await ref.read(presenceRepositoryProvider).setPresence(online: false);
      } on DispatchException {
        // The service's 10-minute TTL ends presence anyway.
      }
    }
  }

  bool get _needsForeground => (state.online && state.activeRequestId == null) || _routeSharing;

  Future<void> _syncForeground() async {
    final fg = ref.read(foregroundSessionProvider);
    if (_needsForeground && !fg.running) {
      await fg.start(
        channelName: _l.instantForegroundChannel,
        title: _l.instantForegroundTitle,
        text: _l.instantForegroundText,
        stopLabel: _l.instantTurnOff,
      );
    } else if (!_needsForeground && fg.running) {
      await fg.stop();
    }
  }

  Future<void> _startIdleSharing() async {
    await _syncForeground();
    _presenceSub ??= ref
        .read(trackingLocationProvider)
        .presenceUpdates(distanceM: presenceMinMoveM.round())
        .listen((f) {
          _lastFix = f;
          if (shouldSendPresence(lastSent: _lastSent, lastSentAt: _lastSentAt, next: f, now: _now())) {
            _send(f);
          }
        });
    _heartbeat ??= Timer.periodic(presenceHeartbeat, (_) => _onHeartbeat());
  }

  void _stopIdleSharing() {
    _presenceSub?.cancel();
    _presenceSub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Future<void> _onHeartbeat() async {
    if (heartbeatDue(lastSentAt: _lastSentAt, now: _now())) {
      await _send(_lastFix);
    }
    await _checkBattery();
  }

  /// Re-sends presence with the last known fix; never asks for a new one.
  Future<void> _send(LocationFix? fix) async {
    try {
      await ref.read(presenceRepositoryProvider).setPresence(online: true, helpReady: state.helpReady, fix: fix);
      _lastSent = fix ?? _lastSent;
      _lastSentAt = _now();
    } on DispatchException catch (e) {
      if (e.error == DispatchError.notEligible) {
        await goOffline();
        await refresh();
      }
    }
  }

  void _onOffer(InstantOffer? o) {
    final prev = state.pendingOffer;
    if (o == null || o.isExpired(_now()) || state.activeRequestId != null) {
      if (prev != null) {
        ref.read(instantNotifierProvider).cancelOffer(prev.offerId);
      }
      state = state.copyWith(pendingOffer: null);
      return;
    }
    if (prev?.offerId == o.offerId) {
      return;
    }
    state = state.copyWith(pendingOffer: o);
    if (_background) {
      final t = offerNotificationText(o, _l, now: _now());
      ref.read(instantNotifierProvider).showOffer(offerId: o.offerId, title: t.title, body: t.body, expiresAt: o.expiresAt);
    }
  }

  void _onPush(InstantPush p) {
    if (p is OfferPush) {
      _onOffer(p.offer);
    }
  }

  void appHidden() {
    _background = true;
    if (state.online) {
      _armIdleTimer();
    }
  }

  void appShown() {
    _background = false;
    _idle?.cancel();
    _idle = null;
    if (state.askStillAvailable) {
      keepAvailable();
    }
  }

  void _armIdleTimer() {
    _idle?.cancel();
    _idle = Timer(autoOffAfter, _askStillAvailable);
  }

  Future<void> _askStillAvailable() async {
    if (!state.online) {
      return;
    }
    state = state.copyWith(askStillAvailable: true);
    await ref.read(instantNotifierProvider).showStillAvailable(
      title: _l.instantStillAvailableTitle,
      body: _l.instantStillAvailableBody,
      keepLabel: _l.instantStillAvailableKeep,
      offLabel: _l.instantTurnOff,
    );
    _answer?.cancel();
    _answer = Timer(autoOffAnswerWindow, () => goOffline(auto: true));
  }

  Future<void> keepAvailable() async {
    _answer?.cancel();
    _answer = null;
    state = state.copyWith(askStillAvailable: false);
    await ref.read(instantNotifierProvider).cancelPrompts();
    if (_background && state.online) {
      _armIdleTimer();
    }
  }

  Future<void> _checkBattery() async {
    if (_batteryAsked) {
      return;
    }
    final p = await ref.read(batteryLevelProvider).percent();
    if (p == null || p >= lowBatteryPercent) {
      return;
    }
    _batteryAsked = true;
    state = state.copyWith(askLowBattery: true);
    if (_background) {
      await ref.read(instantNotifierProvider).showLowBattery(
        title: _l.instantLowBatteryTitle,
        body: _l.instantLowBatteryBody,
        offLabel: _l.instantTurnOff,
      );
    }
  }

  void dismissLowBattery() => state = state.copyWith(askLowBattery: false);

  /// An offer was accepted: one job at a time, so idle presence and the
  /// offer listener pause. [routeSharing] keeps the foreground service.
  Future<void> jobStarted(String requestId, {bool routeSharing = true}) async {
    _routeSharing = routeSharing;
    _stopIdleSharing();
    await _offerSub?.cancel();
    _offerSub = null;
    state = state.copyWith(activeRequestId: requestId, pendingOffer: null);
    await _syncForeground();
  }

  Future<void> setRouteSharing(bool on) async {
    _routeSharing = on;
    await _syncForeground();
  }

  /// Back to how availability was before the job (spec §2.2.4).
  Future<void> jobEnded() async {
    _routeSharing = false;
    state = state.copyWith(activeRequestId: null);
    final uid = _uid;
    if (state.online && uid != null) {
      await _startIdleSharing();
      _offerSub ??= ref.read(instantMirrorProvider).offerFor(uid).listen(_onOffer);
      await _send(_lastFix);
    }
    await _syncForeground();
  }

  void _teardown() {
    _stopIdleSharing();
    _offerSub?.cancel();
    _stopSub?.cancel();
    _pushSub?.cancel();
    _idle?.cancel();
    _answer?.cancel();
    _life?.dispose();
  }
}

final instantSessionProvider = NotifierProvider<InstantSessionController, InstantSessionState>(
  InstantSessionController.new,
);
```

`lib/main.dart`: in `_Root.build` add `ref.watch(pushRegistrationProvider);` as the first line (import `package:photobooking/features/instant_common/instant_services.dart`).

- [ ] **Step 5: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/features/instant_work test/features/instant_common && flutter analyze`
Expected: PASS (14 + 1 tests). If a timer test is off by one heartbeat, check that `advance` moves the world's clock with the fake timers (it must, in 1 s steps), not the assertion.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add pubspec.yaml pubspec.lock lib/features/instant_common lib/features/instant_work lib/data/instant/instant_providers.dart lib/main.dart lib/l10n test/support/instant_world.dart test/features
git commit -m "feat(instant): availability session with presence heartbeat, foreground service, offers, auto-off and low-battery prompt

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: `InstantJobController` (accept, route tracking, arrive / start / finish / cancel)

**Files:**
- Create: `lib/features/instant_work/instant_job_controller.dart`, `test/features/instant_work/instant_job_controller_test.dart`

**Interfaces:**
- Consumes: Tasks 1–4, 9; `externalLauncherProvider` / `ExternalLauncher.canOpen(Uri)`, `.open(Uri)` (2b).
- Produces:
  - `enum InstantJobEnd { finished, cancelled, closed }`.
  - `class InstantJobState` (`requestId`, `meetPoint`, `customerName`, `status`, `lastFix`, `busy`, `error`, `ended`, `endedRequestId`; `bool get active`).
  - `class InstantJobController extends Notifier<InstantJobState>` with `Future<bool> accept(String offerId)`, `Future<bool> decline(String offerId, {DeclineReason? reason})`, `Future<void> resume(String requestId)`, `Future<bool> arrive({bool force = false, String? reason})`, `Future<bool> start()`, `Future<bool> finish()`, `Future<CancelQuote> quoteCancel()`, `Future<CancelQuote> confirmCancel()`, `Future<bool> openDirections(TargetPlatform platform)`; `instantJobProvider` (keep-alive `NotifierProvider`).

Behaviour: accepting starts the route stream at once (the service moves `assigned → en_route` on the first post); each fix updates `lastFix`; one post per ≥ 10 s (12 s Android interval → posts every 12 s); a 429 or network error is ignored (the next fix retries). The route stream stops on a successful "Đã đến", on a mirror status that is not on the way, on finish, cancel or a final status. Finish and cancel end the job and hand availability back to the session.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/instant_work/instant_job_controller_test.dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant_work/instant_job_controller.dart';
import 'package:photobooking/features/instant_work/instant_session_controller.dart';

import '../../support/instant_world.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late InstantWorld w;

  setUp(() async {
    w = InstantWorld();
    await w.init();
    w.presence.settingsValue = eligibleSettings;
  });

  ProviderContainer online(FakeAsync async) {
    final c = ProviderContainer(overrides: w.overrides);
    addTearDown(c.dispose);
    c.read(instantSessionProvider.notifier).goOnline();
    async.flushMicrotasks();
    return c;
  }

  InstantJobController job(ProviderContainer c) => c.read(instantJobProvider.notifier);

  test('accepting starts the route: posts every 10–15 s, never faster', () {
    fakeAsync((async) {
      final c = online(async);
      job(c).accept('O1');
      async.flushMicrotasks();
      expect(c.read(instantJobProvider).requestId, 'R1');
      expect((w.location.routeListeners, w.location.presenceListeners), (1, 0));
      for (var i = 1; i <= 20; i++) {
        w.advance(async, const Duration(seconds: 3));
        w.location.moveRoute(w.fixAt(-1500 + i * 30.0, accuracy: 6));
        async.flushMicrotasks();
      }
      final at = w.jobs.postedAt;
      expect(at.length, inInclusiveRange(4, 6));
      for (var i = 1; i < at.length; i++) {
        final gap = at[i].difference(at[i - 1]);
        expect(gap, greaterThanOrEqualTo(const Duration(seconds: 10)));
        expect(gap, lessThanOrEqualTo(const Duration(seconds: 15)));
      }
    });
  });

  test('"Đã đến" stops GPS and the foreground service at once; nothing is posted afterwards', () {
    fakeAsync((async) {
      final c = online(async);
      job(c).accept('O1');
      async.flushMicrotasks();
      w.location.moveRoute(w.fixAt(120));
      async.flushMicrotasks();
      job(c).arrive();
      async.flushMicrotasks();
      expect(w.jobs.calls, contains('arrive R1'));
      expect(c.read(instantJobProvider).status, InstantStatus.arrived);
      expect(w.location.activeStreams, 0);
      expect(w.foreground.running, isFalse);
      final posts = w.jobs.posted.length;
      w.advance(async, const Duration(minutes: 2));
      w.location.moveRoute(w.fixAt(10));
      expect(w.jobs.posted.length, posts);
    });
  });

  test('arrive refused by the service (too far) keeps tracking and reports the error', () {
    fakeAsync((async) {
      final c = online(async);
      job(c).accept('O1');
      async.flushMicrotasks();
      w.location.moveRoute(w.fixAt(600));
      async.flushMicrotasks();
      w.jobs.arriveError = DispatchError.invalidArgument;
      job(c).arrive();
      async.flushMicrotasks();
      expect(c.read(instantJobProvider).error, DispatchError.invalidArgument);
      expect(w.location.routeListeners, 1);
    });
  });

  test('a forced arrival sends the reason', () {
    fakeAsync((async) {
      final c = online(async);
      job(c).accept('O1');
      async.flushMicrotasks();
      w.location.moveRoute(w.fixAt(400, accuracy: 160));
      async.flushMicrotasks();
      job(c).arrive(force: true, reason: 'Đang đứng ở cổng chính');
      async.flushMicrotasks();
      expect(w.jobs.calls, contains('arrive R1 force'));
    });
  });

  test('start and finish; finishing hands availability back to the session', () {
    fakeAsync((async) {
      final c = online(async);
      job(c).accept('O1');
      async.flushMicrotasks();
      w.location.moveRoute(w.fixAt(50));
      async.flushMicrotasks();
      job(c).arrive();
      async.flushMicrotasks();
      job(c).start();
      async.flushMicrotasks();
      expect(c.read(instantJobProvider).status, InstantStatus.inProgress);
      job(c).finish();
      async.flushMicrotasks();
      final s = c.read(instantJobProvider);
      expect((s.active, s.ended, s.endedRequestId), (false, InstantJobEnd.finished, 'R1'));
      expect(c.read(instantSessionProvider).activeRequestId, isNull);
      expect(w.location.presenceListeners, 1, reason: 'still online: idle presence again');
      expect(w.mirror.listenersOf('instant_requests/R1'), 0);
    });
  });

  test('the customer cancelling (mirror) ends the job and stops GPS', () {
    fakeAsync((async) {
      final c = online(async);
      job(c).accept('O1');
      async.flushMicrotasks();
      w.mirror.setRequest('R1', w.view(InstantStatus.cancelledByCustomer));
      async.flushMicrotasks();
      expect(c.read(instantJobProvider).ended, InstantJobEnd.closed);
      expect(w.location.routeListeners, 0);
    });
  });

  test('resume after a restart follows the mirror: en route tracks, arrived stops', () {
    fakeAsync((async) {
      final c = ProviderContainer(overrides: w.overrides);
      addTearDown(c.dispose);
      w.mirror.setRequest('R1', w.view(InstantStatus.enRoute));
      job(c).resume('R1');
      async.flushMicrotasks();
      expect(c.read(instantJobProvider).meetPoint, w.jobs.job.meetPoint);
      expect(w.location.routeListeners, 1);
      w.mirror.setRequest('R1', w.view(InstantStatus.arrived));
      async.flushMicrotasks();
      expect(w.location.routeListeners, 0);
    });
  });

  test('offer_expired on accept: no job, no GPS', () {
    fakeAsync((async) {
      final c = online(async);
      w.jobs.acceptError = DispatchError.offerExpired;
      job(c).accept('O1');
      async.flushMicrotasks();
      expect(c.read(instantJobProvider).error, DispatchError.offerExpired);
      expect(c.read(instantJobProvider).active, isFalse);
      expect(w.location.routeListeners, 0);
    });
  });

  test('cancel: a dry-run quote first, then the cancel ends the job', () {
    fakeAsync((async) {
      final c = online(async);
      job(c).accept('O1');
      async.flushMicrotasks();
      CancelQuote? q;
      job(c).quoteCancel().then((v) => q = v);
      async.flushMicrotasks();
      expect(q!.refundVnd, 690000);
      job(c).confirmCancel();
      async.flushMicrotasks();
      expect(w.jobs.calls.where((x) => x.startsWith('quote') || x.startsWith('cancel')), ['quote R1', 'cancel R1']);
      expect(c.read(instantJobProvider).ended, InstantJobEnd.cancelled);
    });
  });

  test('directions open the first maps app the phone can handle', () {
    fakeAsync((async) {
      final c = online(async);
      job(c).accept('O1');
      async.flushMicrotasks();
      job(c).openDirections(TargetPlatform.android);
      async.flushMicrotasks();
      expect(w.launcher.opened.single.scheme, 'geo');
    });
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/instant_work/instant_job_controller_test.dart`
Expected: FAIL to compile, `instant_job_controller.dart` missing.

- [ ] **Step 3: Implement**

```dart
// lib/features/instant_work/instant_job_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_providers.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/instant/tracking_location.dart';
import 'package:photobooking/features/instant_common/instant_services.dart';
import 'package:photobooking/features/instant_work/instant_rules.dart';
import 'package:photobooking/features/instant_work/instant_session_controller.dart';

enum InstantJobEnd { finished, cancelled, closed }

const _keep = Object();

class InstantJobState {
  const InstantJobState({
    this.requestId,
    this.meetPoint,
    this.customerName,
    this.status,
    this.lastFix,
    this.busy = false,
    this.error,
    this.ended,
    this.endedRequestId,
  });

  final String? requestId;
  final MeetPoint? meetPoint;
  final String? customerName;
  final InstantStatus? status;
  final LocationFix? lastFix;
  final bool busy;
  final DispatchError? error;
  final InstantJobEnd? ended;
  final String? endedRequestId;

  bool get active => requestId != null;

  InstantJobState copyWith({
    Object? meetPoint = _keep,
    Object? status = _keep,
    Object? lastFix = _keep,
    bool? busy,
    Object? error = _keep,
  }) => InstantJobState(
    requestId: requestId,
    meetPoint: identical(meetPoint, _keep) ? this.meetPoint : meetPoint as MeetPoint?,
    customerName: customerName,
    status: identical(status, _keep) ? this.status : status as InstantStatus?,
    lastFix: identical(lastFix, _keep) ? this.lastFix : lastFix as LocationFix?,
    busy: busy ?? this.busy,
    error: identical(error, _keep) ? this.error : error as DispatchError?,
    ended: ended,
    endedRequestId: endedRequestId,
  );
}

/// One accepted job, kept alive while the photographer drives (the app may
/// be in the background). Owns the high-accuracy route stream.
class InstantJobController extends Notifier<InstantJobState> {
  StreamSubscription<LocationFix>? _route;
  StreamSubscription<InstantRequestView?>? _mirror;
  DateTime? _lastPostAt;

  @override
  InstantJobState build() {
    ref.onDispose(() {
      _route?.cancel();
      _mirror?.cancel();
    });
    return const InstantJobState();
  }

  InstantSessionController get _session => ref.read(instantSessionProvider.notifier);

  Future<bool> accept(String offerId) async {
    if (state.busy) {
      return false;
    }
    state = state.copyWith(busy: true, error: null);
    try {
      final job = await ref.read(instantJobRepositoryProvider).accept(offerId);
      await _begin(job.requestId, meetPoint: job.meetPoint, customerName: job.customerName, tracking: true);
      return true;
    } on DispatchException catch (e) {
      state = state.copyWith(busy: false, error: e.error);
      return false;
    }
  }

  /// True when the offer is gone either way (declined, expired, taken).
  Future<bool> decline(String offerId, {DeclineReason? reason}) async {
    try {
      await ref.read(instantJobRepositoryProvider).decline(offerId, reason: reason);
      return true;
    } on DispatchException catch (e) {
      state = state.copyWith(error: e.error);
      return e.error == DispatchError.offerExpired || e.error == DispatchError.notFound;
    }
  }

  /// S14.03 opened after a restart: follow the mirror; tracking starts only if
  /// the photographer is still on the way.
  Future<void> resume(String requestId) async {
    if (state.requestId == requestId) {
      return;
    }
    await _begin(requestId, tracking: false);
  }

  Future<void> _begin(String requestId, {MeetPoint? meetPoint, String? customerName, required bool tracking}) async {
    await _stopStreams();
    state = InstantJobState(
      requestId: requestId,
      meetPoint: meetPoint,
      customerName: customerName,
      status: tracking ? InstantStatus.assigned : null,
    );
    await _session.jobStarted(requestId, routeSharing: tracking);
    if (tracking) {
      _startRoute();
    }
    _mirror = ref.read(instantMirrorProvider).request(requestId).listen(_onView);
  }

  void _onView(InstantRequestView? v) {
    if (v == null || state.requestId == null) {
      return;
    }
    state = state.copyWith(status: v.status, meetPoint: state.meetPoint ?? v.meetPoint);
    if (v.status.isFinal) {
      _end(InstantJobEnd.closed);
      return;
    }
    if (v.status.onTheWay) {
      if (_route == null) {
        _startRoute();
      }
    } else {
      _stopRoute();
    }
  }

  void _startRoute() {
    _session.setRouteSharing(true);
    _route = ref.read(trackingLocationProvider).routeUpdates(interval: const Duration(seconds: 12)).listen(_onFix);
  }

  void _stopRoute() {
    final r = _route;
    if (r == null) {
      return;
    }
    r.cancel();
    _route = null;
    _session.setRouteSharing(false);
  }

  Future<void> _onFix(LocationFix f) async {
    state = state.copyWith(lastFix: f);
    final id = state.requestId;
    final now = ref.read(clockProvider)();
    if (id == null || !shouldPostRoute(lastPostAt: _lastPostAt, now: now)) {
      return;
    }
    _lastPostAt = now;
    try {
      await ref.read(instantJobRepositoryProvider).postLocation(id, f);
    } on DispatchException {
      // 429 or offline: the next fix tries again.
    }
  }

  Future<bool> _act(Future<void> Function(String id) call, {required void Function() then}) async {
    final id = state.requestId;
    if (id == null || state.busy) {
      return false;
    }
    state = state.copyWith(busy: true, error: null);
    try {
      await call(id);
      state = state.copyWith(busy: false);
      then();
      return true;
    } on DispatchException catch (e) {
      state = state.copyWith(busy: false, error: e.error);
      return false;
    }
  }

  Future<bool> arrive({bool force = false, String? reason}) async {
    final fix = state.lastFix ?? await ref.read(trackingLocationProvider).currentFix(accuracy: FixAccuracy.high);
    if (fix == null) {
      state = state.copyWith(error: DispatchError.invalidArgument);
      return false;
    }
    return _act(
      (id) => ref.read(instantJobRepositoryProvider).arrive(id, fix: fix, force: force, reason: reason),
      then: () {
        _stopRoute();
        state = state.copyWith(status: InstantStatus.arrived);
      },
    );
  }

  Future<bool> start() => _act(
    (id) => ref.read(instantJobRepositoryProvider).start(id),
    then: () => state = state.copyWith(status: InstantStatus.inProgress),
  );

  Future<bool> finish() => _act(
    (id) => ref.read(instantJobRepositoryProvider).finish(id),
    then: () => _end(InstantJobEnd.finished),
  );

  Future<CancelQuote> quoteCancel() =>
      ref.read(instantJobRepositoryProvider).cancel(state.requestId!, dryRun: true);

  Future<CancelQuote> confirmCancel() async {
    final q = await ref.read(instantJobRepositoryProvider).cancel(state.requestId!, dryRun: false);
    await _end(InstantJobEnd.cancelled);
    return q;
  }

  Future<bool> openDirections(TargetPlatform platform) async {
    final point = state.meetPoint;
    if (point == null) {
      return false;
    }
    final launcher = ref.read(externalLauncherProvider);
    for (final uri in directionsUris(point, platform)) {
      if (await launcher.canOpen(uri) && await launcher.open(uri)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _stopStreams() async {
    _stopRoute();
    await _mirror?.cancel();
    _mirror = null;
    _lastPostAt = null;
  }

  Future<void> _end(InstantJobEnd how) async {
    final id = state.requestId;
    if (id == null) {
      return;
    }
    await _stopStreams();
    state = InstantJobState(ended: how, endedRequestId: id);
    await _session.jobEnded();
  }
}

final instantJobProvider = NotifierProvider<InstantJobController, InstantJobState>(InstantJobController.new);
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/features/instant_work && flutter analyze`
Expected: PASS (10 new tests plus Task 9's).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/instant_work test/features/instant_work
git commit -m "feat(instant): job controller with throttled route sharing that stops on arrival

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: S13.08 cancel sheet, milestones and error texts (shared with plan I5)

**Files:**
- Create: `lib/features/instant_common/instant_cancel_sheet.dart`, `lib/features/instant_common/instant_milestones.dart`, `lib/features/instant_common/instant_errors.dart`, `test/features/instant_common/instant_cancel_sheet_test.dart`, `test/features/instant_common/instant_milestones_test.dart`
- Modify: `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `showAppSheet` (3a1), `AppButton.danger` (Task 7), `AppSkeleton.box` (3a2), `formatMoney`, `CancelQuote`, `CancelRule`, `DispatchException`, `ScreenCode`, `ScreenCodes.instantCancel`, `hostWidget`, `expectIdle`, `expectBlurBudget`.
- Produces:
  - `enum InstantCancelRole { customer, photographer }`; `Future<bool> showInstantCancelSheet(BuildContext context, {required InstantCancelRole role, required Future<CancelQuote> Function() quote, required Future<Object?> Function() confirm, String? photographerName})` (true when cancelled); `class InstantCancelSheet extends StatefulWidget` (same parameters). Keys: `cancel-row-free`, `cancel-row-en-route`, `cancel-row-no-show`, `cancel-row-late`, `cancel-amount`, `cancel-confirm`, `cancel-keep`, `cancel-retry`.
  - Customer layout (mock S13.08): title "Huỷ chụp ngay?"; the three rules with "Hoàn 100% / 80% / 50%" (plus "Nhiếp ảnh gia trễ quá 15 phút · Hoàn 100%" when that is the current rule), the current one highlighted and marked "(bây giờ)"; the amounts from the dry run in words; red "Huỷ và hoàn {số tiền}"; text "Giữ yêu cầu". Photographer layout: "Huỷ việc này?", "Khách được hoàn {số tiền}. Huỷ sau khi nhận làm giảm điểm tin cậy.", red "Huỷ việc này", text "Giữ việc". A `conflict`/`invalid_argument` on confirm (the state changed) re-quotes and says so.
  - `class Milestone { const Milestone(String label, {required bool done}); }`, `const InstantMilestones({super.key, required List<Milestone> items})`.
  - `String instantErrorText(DispatchError e, AppLocalizations l)`.
  - l10n listed in Step 3.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/instant_common/instant_cancel_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant_common/instant_cancel_sheet.dart';

import '../../core/widgets/widget_host.dart';
import '../../support/blur.dart';
import '../../support/idle.dart';

const _enRoute = CancelQuote(rule: CancelRule.enRouteFee, refundVnd: 552000, photographerVnd: 138000, platformVnd: 0);
const _free = CancelQuote(rule: CancelRule.freeGrace, refundVnd: 690000, photographerVnd: 0, platformVnd: 0);

class _Calls {
  int quotes = 0;
  int confirms = 0;
  bool? result;
}

Widget _host(
  _Calls calls, {
  InstantCancelRole role = InstantCancelRole.customer,
  List<Object> quotes = const [_enRoute],
  Object? confirmError,
  Brightness brightness = Brightness.dark,
  double width = 390,
  double textScale = 1,
}) => hostWidget(
  Builder(
    builder: (context) => TextButton(
      onPressed: () async {
        calls.result = await showInstantCancelSheet(
          context,
          role: role,
          photographerName: 'Minh Trí',
          quote: () async {
            final q = quotes[calls.quotes.clamp(0, quotes.length - 1)];
            calls.quotes++;
            if (q is CancelQuote) {
              return q;
            }
            throw q;
          },
          confirm: () async {
            calls.confirms++;
            if (confirmError != null) {
              throw confirmError;
            }
            return null;
          },
        );
      },
      child: const Text('open'),
    ),
  ),
  brightness: brightness,
  width: width,
  textScale: textScale,
);

void main() {
  testWidgets('customer: the current rule is marked, the amounts come from the dry run', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_host(calls));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Huỷ chụp ngay?'), findsOneWidget);
    expect(find.text('Nhiếp ảnh gia đang đến (bây giờ)'), findsOneWidget);
    expect(find.text('Hoàn 80%'), findsOneWidget);
    expect(find.text('Hoàn 100%'), findsOneWidget);
    expect(find.text('Hoàn 50%'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('cancel-amount'))).data,
      'Bạn sẽ được hoàn 552.000₫; 138.000₫ là phí đi lại trả cho Minh Trí.',
    );
    expect(find.text('Huỷ và hoàn 552.000₫'), findsOneWidget);
    expect(calls.quotes, 1);
  });

  testWidgets('confirm cancels and closes with true; "Giữ yêu cầu" closes with false', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_host(calls, quotes: const [_free]));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('cancel-amount'))).data, 'Bạn sẽ được hoàn 690.000₫.');
    await tester.tap(find.byKey(const Key('cancel-keep')));
    await tester.pumpAndSettle();
    expect((calls.result, calls.confirms), (false, 0));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-confirm')));
    await tester.pumpAndSettle();
    expect((calls.result, calls.confirms), (true, 1));
  });

  testWidgets('a failed quote offers "Thử lại"', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_host(calls, quotes: [const DispatchException(DispatchError.network), _free]));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa tính được số tiền hoàn. Thử lại nhé.'), findsOneWidget);
    expect(find.byKey(const Key('cancel-confirm')), findsNothing);
    await tester.tap(find.byKey(const Key('cancel-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Huỷ và hoàn 690.000₫'), findsOneWidget);
  });

  testWidgets('the state changed meanwhile: re-quote and say so', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_host(
      calls,
      quotes: const [_free, _enRoute],
      confirmError: const DispatchException(DispatchError.conflict, status: 409),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Trạng thái vừa thay đổi. Kiểm tra lại số tiền.'), findsOneWidget);
    expect(find.text('Huỷ và hoàn 552.000₫'), findsOneWidget);
    expect(calls.result, isNull, reason: 'still open');
  });

  testWidgets('photographer: what the customer gets back and the reliability warning', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_host(
      calls,
      role: InstantCancelRole.photographer,
      quotes: const [CancelQuote(rule: CancelRule.photographerCancel, refundVnd: 690000, photographerVnd: 0, platformVnd: 0)],
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Huỷ việc này?'), findsOneWidget);
    expect(find.text('Khách được hoàn 690.000₫. Huỷ sau khi nhận làm giảm điểm tin cậy.'), findsOneWidget);
    expect(find.text('Huỷ việc này'), findsOneWidget);
    expect(find.text('Giữ việc'), findsOneWidget);
    expect(find.byKey(const Key('cancel-row-free')), findsNothing);
  });

  testWidgets('the confirmation is red, never the gradient; idle; one blur', (tester) async {
    final calls = _Calls();
    await tester.pumpWidget(_host(calls));
    await tester.tap(find.text('open'));
    await expectIdle(tester);
    expect(find.descendant(of: find.byKey(const Key('cancel-confirm')), matching: find.byType(FilledButton)), findsOneWidget);
    expect(find.byKey(const Key('cancel-confirm')).evaluate().single.widget.runtimeType.toString(), 'AppButton');
    expectBlurBudget(max: 1);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x (${b.name})', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(_host(calls, brightness: b, width: 320, textScale: 1.3));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
```

```dart
// test/features/instant_common/instant_milestones_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/instant_common/instant_milestones.dart';

import '../../core/widgets/widget_host.dart';

void main() {
  testWidgets('done and pending steps differ by icon and text, not colour alone', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const InstantMilestones(items: [
      Milestone('Đã nhận · 15:21', done: true),
      Milestone('Đã đến (bật khi còn cách 200 m)', done: false),
    ])));
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
    expect(tester.getSemantics(find.text('Đã nhận · 15:21')), containsSemantics(isChecked: true));
    handle.dispose();
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/instant_common`
Expected: FAIL to compile (files missing).

- [ ] **Step 3: Implement**

Strings (`lib/l10n/app_vi.arb`, then `flutter gen-l10n`):

```json
  "instantCancelTitle": "Huỷ chụp ngay?",
  "instantCancelJobTitle": "Huỷ việc này?",
  "instantCancelRuleFree": "Đang tìm, hoặc 2 phút đầu sau khi có người nhận",
  "instantCancelRuleEnRoute": "Nhiếp ảnh gia đang đến",
  "instantCancelRuleNoShow": "Đã đến, bạn không có mặt sau 15 phút",
  "instantCancelRuleLate": "Nhiếp ảnh gia trễ quá 15 phút",
  "instantRefundPercent": "Hoàn {percent}%",
  "@instantRefundPercent": {"placeholders": {"percent": {"type": "int"}}},
  "instantNow": "(bây giờ)",
  "instantCancelRefundOnly": "Bạn sẽ được hoàn {refund}.",
  "@instantCancelRefundOnly": {"placeholders": {"refund": {"type": "String"}}},
  "instantCancelRefundFee": "Bạn sẽ được hoàn {refund}; {fee} là phí đi lại trả cho {name}.",
  "@instantCancelRefundFee": {"placeholders": {"refund": {"type": "String"}, "fee": {"type": "String"}, "name": {"type": "String"}}},
  "instantThePhotographer": "nhiếp ảnh gia",
  "instantCancelConfirm": "Huỷ và hoàn {refund}",
  "@instantCancelConfirm": {"placeholders": {"refund": {"type": "String"}}},
  "instantCancelKeep": "Giữ yêu cầu",
  "instantCancelJobBody": "Khách được hoàn {refund}. Huỷ sau khi nhận làm giảm điểm tin cậy.",
  "@instantCancelJobBody": {"placeholders": {"refund": {"type": "String"}}},
  "instantCancelJobConfirm": "Huỷ việc này",
  "instantCancelJobKeep": "Giữ việc",
  "instantCancelQuoteError": "Chưa tính được số tiền hoàn. Thử lại nhé.",
  "instantCancelChanged": "Trạng thái vừa thay đổi. Kiểm tra lại số tiền.",
  "instantActionError": "Chưa thực hiện được. Thử lại nhé.",
  "instantRetry": "Thử lại",
  "instantNetworkError": "Không có kết nối. Thử lại khi có mạng.",
  "instantUnavailable": "Chụp ngay đang tạm dừng. Thử lại sau.",
  "instantOfferExpired": "Lời mời đã hết hạn",
  "instantOfferTaken": "Yêu cầu đã có người nhận",
  "instantNotEligibleTitle": "Cần hoàn tất để bật",
```

```dart
// lib/features/instant_common/instant_errors.dart
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Vietnamese text for a dispatch error (the service's message is English,
/// for logs). Plan I5 handles its own codes (phone_required, price_changed,
/// outside_service_area) before falling back to this.
String instantErrorText(DispatchError e, AppLocalizations l) => switch (e) {
  DispatchError.network => l.instantNetworkError,
  DispatchError.disabled || DispatchError.internal || DispatchError.unknown || DispatchError.malformed => l.instantUnavailable,
  DispatchError.offerExpired => l.instantOfferExpired,
  DispatchError.alreadyAssigned => l.instantOfferTaken,
  DispatchError.notEligible => l.instantNotEligibleTitle,
  _ => l.instantActionError,
};
```

```dart
// lib/features/instant_common/instant_milestones.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';

class Milestone {
  const Milestone(this.label, {required this.done});
  final String label;
  final bool done;
}

/// "Đã nhận · 15:21 / Đã đến / Bắt đầu chụp · Hoàn thành" (S13.06, S14.03).
class InstantMilestones extends StatelessWidget {
  const InstantMilestones({super.key, required this.items});
  final List<Milestone> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final done = dark ? AppColorsDark.success : AppColors.success;
    final muted = dark ? AppColorsDark.foregroundSecondary : AppColors.foregroundSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s1),
            child: MergeSemantics(
              child: Semantics(
                checked: m.done,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      m.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: m.done ? done : muted,
                    ),
                    const SizedBox(width: AppSpace.s2),
                    Expanded(
                      child: Text(
                        m.label,
                        style: m.done
                            ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
                            : theme.textTheme.bodyMedium?.copyWith(color: muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

```dart
// lib/features/instant_common/instant_cancel_sheet.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';

enum InstantCancelRole { customer, photographer }

/// S13.08. The amount always comes from the service's dry run and is shown in
/// words before the red confirmation.
Future<bool> showInstantCancelSheet(
  BuildContext context, {
  required InstantCancelRole role,
  required Future<CancelQuote> Function() quote,
  required Future<Object?> Function() confirm,
  String? photographerName,
}) async =>
    await showAppSheet<bool>(
      context,
      builder: (_) => ScreenCode(
        ScreenCodes.instantCancel,
        child: InstantCancelSheet(role: role, quote: quote, confirm: confirm, photographerName: photographerName),
      ),
    ) ??
    false;

class InstantCancelSheet extends StatefulWidget {
  const InstantCancelSheet({
    super.key,
    required this.role,
    required this.quote,
    required this.confirm,
    this.photographerName,
  });

  final InstantCancelRole role;
  final Future<CancelQuote> Function() quote;
  final Future<Object?> Function() confirm;
  final String? photographerName;

  @override
  State<InstantCancelSheet> createState() => _InstantCancelSheetState();
}

class _InstantCancelSheetState extends State<InstantCancelSheet> {
  CancelQuote? _quote;
  bool _loading = true;
  bool _confirming = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? message}) async {
    setState(() {
      _loading = true;
      _message = message;
    });
    try {
      final q = await widget.quote();
      if (mounted) {
        setState(() {
          _quote = q;
          _loading = false;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _quote = null;
          _loading = false;
          _message = context.l10n.instantCancelQuoteError;
        });
      }
    }
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    try {
      await widget.confirm();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on DispatchException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _confirming = false);
      if (e.error == DispatchError.conflict || e.error == DispatchError.invalidArgument) {
        await _load(message: context.l10n.instantCancelChanged);
      } else {
        setState(() => _message = context.l10n.instantActionError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final customer = widget.role == InstantCancelRole.customer;
    final q = _quote;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpace.s5, AppSpace.s2, AppSpace.s5, AppSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(customer ? l.instantCancelTitle : l.instantCancelJobTitle, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: AppSpace.s3),
          if (_loading)
            const AppSkeleton.box(height: 140)
          else if (q == null) ...[
            Text(_message ?? l.instantCancelQuoteError),
            const SizedBox(height: AppSpace.s3),
            AppButton.outline(l.instantRetry, key: const Key('cancel-retry'), onPressed: _load),
          ] else ...[
            if (customer) ..._customerRows(q, l),
            if (_message != null) ...[
              Text(_message!, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpace.s2),
            ],
            Text(
              customer ? _amountText(q, l) : l.instantCancelJobBody(formatMoney(q.refundVnd)),
              key: const Key('cancel-amount'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpace.s4),
            AppButton.danger(
              customer ? l.instantCancelConfirm(formatMoney(q.refundVnd)) : l.instantCancelJobConfirm,
              key: const Key('cancel-confirm'),
              loading: _confirming,
              onPressed: _confirm,
            ),
          ],
          const SizedBox(height: AppSpace.s2),
          AppButton.text(
            customer ? l.instantCancelKeep : l.instantCancelJobKeep,
            key: const Key('cancel-keep'),
            onPressed: _confirming ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  String _amountText(CancelQuote q, AppLocalizations l) => q.photographerVnd > 0
      ? l.instantCancelRefundFee(
          formatMoney(q.refundVnd),
          formatMoney(q.photographerVnd),
          widget.photographerName ?? l.instantThePhotographer,
        )
      : l.instantCancelRefundOnly(formatMoney(q.refundVnd));

  List<Widget> _customerRows(CancelQuote q, AppLocalizations l) {
    final rows = <(String, Set<CancelRule>, String, int)>[
      ('cancel-row-free', {CancelRule.freeSearching, CancelRule.freeGrace}, l.instantCancelRuleFree, 100),
      ('cancel-row-en-route', {CancelRule.enRouteFee}, l.instantCancelRuleEnRoute, 80),
      ('cancel-row-no-show', {CancelRule.noShow}, l.instantCancelRuleNoShow, 50),
      if (q.rule == CancelRule.photographerFault)
        ('cancel-row-late', {CancelRule.photographerFault}, l.instantCancelRuleLate, 100),
    ];
    return [
      for (final (key, rules, label, percent) in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s2),
          child: _RuleRow(
            key: Key(key),
            label: rules.contains(q.rule) ? '$label ${l.instantNow}' : label,
            percent: rules.contains(q.rule) ? q.refundPercent : percent,
            current: rules.contains(q.rule),
          ),
        ),
    ];
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({super.key, required this.label, required this.percent, required this.current});
  final String label;
  final int percent;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = dark ? AppColorsDark.primary : AppColors.primary;
    return Semantics(
      selected: current,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: current ? (dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle) : null,
          border: Border.all(color: current ? primary : (dark ? AppColorsDark.border : AppColors.border)),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3, vertical: AppSpace.s2),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
              const SizedBox(width: AppSpace.s2),
              Text(
                context.l10n.instantRefundPercent(percent),
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/features/instant_common && flutter analyze`
Expected: PASS (8 + 1 tests). `AppSkeleton.box` pulses only while the quote loads; the idle test runs after it resolved.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/instant_common lib/l10n test/features/instant_common
git commit -m "feat(instant): S13.08 cancel sheet with dry-run amounts and a red confirmation

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: S14.01 "Live Shutter", routes and the Công việc entry card

**Files:**
- Create: `lib/features/instant_work/photographer_only.dart`, `lib/features/instant_work/instant_availability_screen.dart`, `lib/features/instant_work/instant_work_card.dart`, `test/support/instant_screens.dart`, `test/features/instant_work/instant_availability_screen_test.dart`, `test/features/instant_work/instant_work_card_test.dart`
- Modify: `lib/app/router.dart`, `lib/features/shell/placeholder_tabs.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `instantSessionProvider` (Task 9), `instantErrorText` (Task 11), `packageLabel` (Task 6), `GlassCard`, `AppButton`, `AppSkeleton`, `formatMoney`, `currentProfileProvider`, `AppTab`, `UserRole`, `dispatchConfigProvider`, `screenRouterApp`.
- Produces:
  - `const PhotographerOnly({super.key, required Widget child})` (customers are sent to `/home`).
  - `const InstantAvailabilityScreen({super.key})` (S14.01, route `/work/instant`). Keys: `instant-online` (the `SwitchListTile`), `instant-help`, `instant-accept-prices`, `instant-off-today`, `instant-reason-<code>`, `instant-reason-fix-<code>`, `instant-package-<code>`, `instant-still-banner`, `instant-battery-banner`.
  - `const InstantWorkCard({super.key})` (key `instant-work-card`), shown at the top of the photographer's Công việc tab (`BookingsTab` until S06.01 replaces it).
  - Routes: `/work/instant` with children `offer/:offerId` (Task 13) and `:id` (Task 14).
  - Test support `instantScreenApp(InstantWorld w, {required String location, Brightness brightness, double textScale})` with stub routes `/profile/phone`, `/setup/1`, `/home`, `/chat/:chatId`.
  - l10n listed in Step 3.

Layout (mock S14.01, top to bottom): app bar "Chụp ngay"; banners (still available, low battery, auto-off) when relevant; highlighted `GlassCard` "Live Shutter" + switch; when conditions are missing, the reasons with a "Sửa"/"Cho phép" action each; card "Sẵn sàng hỗ trợ" + switch (enabled once the price list is accepted); "Bảng giá gói" + "Bản 3 · đã đồng ý"; one row per package "1 giờ · 30 ảnh / Khách trả 690.000₫ / Bạn nhận 552.000₫"; the note about the 30-minute check and reliability. Bottom: the one primary "Đồng ý bảng giá bản {n}" while the current version is not accepted, otherwise (when on) the outline "Tắt khi xong việc hôm nay". One blur (the highlighted card).

- [ ] **Step 1: Write the failing tests**

```dart
// test/support/instant_screens.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/instant_work/instant_availability_screen.dart';
import 'package:photobooking/features/instant_work/instant_job_screen.dart';
import 'package:photobooking/features/instant_work/instant_offer_screen.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';

import 'instant_world.dart';
import 'screen_host.dart';

/// The photographer routes of plan I4 plus stubs for the routes they link to.
Widget instantScreenApp(
  InstantWorld w, {
  required String location,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
}) {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/work/instant',
        builder: (_, _) => const InstantAvailabilityScreen(),
        routes: [
          GoRoute(path: 'offer/:offerId', builder: (_, s) => InstantOfferScreen(offerId: s.pathParameters['offerId']!)),
          GoRoute(path: ':id', builder: (_, s) => InstantJobScreen(requestId: s.pathParameters['id']!)),
        ],
      ),
      GoRoute(path: '/bookings', builder: (_, _) => const BookingsTab()),
      GoRoute(path: '/profile/phone', builder: (_, s) => Text('phone ${s.uri.queryParameters['returnTo']}')),
      GoRoute(path: '/setup/1', builder: (_, _) => const Text('setup')),
      GoRoute(path: '/home', builder: (_, _) => const Text('home')),
      GoRoute(path: '/chat/:chatId', builder: (_, s) => Text('chat ${s.pathParameters['chatId']}')),
    ],
  );
  return AppMapScope(
    engine: w.map,
    child: screenRouterApp(router: router, overrides: w.overrides, brightness: brightness, textScale: textScale),
  );
}
```

(Tasks 13 and 14 create `instant_offer_screen.dart` and `instant_job_screen.dart`; until then create both files with a placeholder `class InstantOfferScreen extends StatelessWidget { const InstantOfferScreen({super.key, required this.offerId}); final String offerId; @override Widget build(BuildContext context) => const SizedBox(); }` and the same for `InstantJobScreen({required String requestId})`, so this task compiles. Tasks 13 and 14 replace them.)

```dart
// test/features/instant_work/instant_availability_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/user/user_profile.dart';

import '../../support/instant_screens.dart';
import '../../support/instant_world.dart';

void main() {
  late InstantWorld w;

  setUp(() async {
    w = InstantWorld();
    await w.init();
  });

  SwitchListTile online(WidgetTester tester) => tester.widget<SwitchListTile>(find.byKey(const Key('instant-online')));

  testWidgets('not accepted yet: the price list with payouts, one primary "Đồng ý bảng giá bản 3", switch disabled', (tester) async {
    await tester.pumpWidget(instantScreenApp(w, location: '/work/instant'));
    await tester.pumpAndSettle();
    expect(find.text('Live Shutter'), findsOneWidget);
    expect(find.text('Bản 3 · chưa đồng ý'), findsOneWidget);
    expect(find.text('1 giờ · 30 ảnh'), findsOneWidget);
    expect(find.text('Khách trả 690.000₫'), findsOneWidget);
    expect(find.text('552.000₫'), findsOneWidget);
    expect(find.text('Đồng ý bảng giá bản 3'), findsOneWidget);
    expect(find.byType(CtaSurface), findsOneWidget, reason: 'one primary action');
    expect(online(tester).onChanged, isNull);
    expect(find.byKey(const Key('instant-reason-price_list_not_accepted')), findsOneWidget);
  });

  testWidgets('accepting enables the switch; switching on goes online with the notification', (tester) async {
    await tester.pumpWidget(instantScreenApp(w, location: '/work/instant'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('instant-accept-prices')));
    await tester.pumpAndSettle();
    expect(find.text('Bản 3 · đã đồng ý'), findsOneWidget);
    expect(online(tester).onChanged, isNotNull);
    await tester.tap(find.byKey(const Key('instant-online')));
    await tester.pumpAndSettle();
    expect(online(tester).value, isTrue);
    expect(w.foreground.running, isTrue);
    expect(find.text('Tắt khi xong việc hôm nay'), findsOneWidget);
    expect(find.byType(CtaSurface), findsNothing, reason: 'the accept button is gone; turning off is an outline');
    await tester.tap(find.byKey(const Key('instant-off-today')));
    await tester.pumpAndSettle();
    expect(online(tester).value, isFalse);
    expect(w.foreground.running, isFalse);
  });

  testWidgets('missing conditions say what to do: phone goes to S04.05 and comes back', (tester) async {
    w.presence.settingsValue = const InstantSettings(
      acceptedPriceListVersion: 3,
      currentPriceListVersion: 3,
      helpReady: false,
      eligible: false,
      reasons: [EligibilityReason.noPhone, EligibilityReason.profileIncomplete],
    );
    await tester.pumpWidget(instantScreenApp(w, location: '/work/instant'));
    await tester.pumpAndSettle();
    expect(find.text('Thêm số điện thoại'), findsOneWidget);
    expect(find.text('Hoàn tất hồ sơ nhiếp ảnh gia'), findsOneWidget);
    await tester.tap(find.byKey(const Key('instant-reason-fix-no_phone')));
    await tester.pumpAndSettle();
    expect(find.text('phone /work/instant'), findsOneWidget);
  });

  testWidgets('location not allowed: "Cho phép" asks the OS, then the price list appears', (tester) async {
    w.presence.settingsValue = eligibleSettings;
    w.permission = FakeLocationRepositoryForScreens.notAsked();
    await tester.pumpWidget(instantScreenApp(w, location: '/work/instant'));
    await tester.pumpAndSettle();
    expect(find.text('Cho phép dùng vị trí khi dùng app'), findsOneWidget);
    expect(find.text('1 giờ · 30 ảnh'), findsNothing);
    await tester.tap(find.byKey(const Key('instant-reason-fix-location_denied')));
    await tester.pumpAndSettle();
    expect(w.permission.requestCalls, 1);
    expect(find.text('1 giờ · 30 ảnh'), findsOneWidget);
  });

  testWidgets('"Sẵn sàng hỗ trợ" is saved', (tester) async {
    w.presence.settingsValue = eligibleSettings;
    await tester.pumpWidget(instantScreenApp(w, location: '/work/instant'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('instant-help')));
    await tester.pumpAndSettle();
    expect(w.presence.settingsValue.helpReady, isTrue);
  });

  testWidgets('a customer who opens the route is sent home', (tester) async {
    final customer = InstantWorld(role: UserRole.customer);
    await customer.init();
    await tester.pumpWidget(instantScreenApp(customer, location: '/work/instant'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x (${b.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(instantScreenApp(w, location: '/work/instant', brightness: b, textScale: 1.3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
```

Add to `test/support/instant_world.dart` (bottom of the file; it only names the 3a1 fake's constructor arguments for readability):

```dart
abstract final class FakeLocationRepositoryForScreens {
  static FakeLocationRepository notAsked() => FakeLocationRepository(
    status: LocationPermissionStatus.notAsked,
    statusAfterRequest: LocationPermissionStatus.granted,
  );
}
```

```dart
// test/features/instant_work/instant_work_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/instant_work/instant_availability_screen.dart';

import '../../support/instant_screens.dart';
import '../../support/instant_world.dart';

void main() {
  testWidgets('the Công việc tab starts with the Chụp ngay card; it opens S14.01', (tester) async {
    final w = InstantWorld();
    await w.init();
    await tester.pumpWidget(instantScreenApp(w, location: '/bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Bật để nhận việc chụp ngay ở gần'), findsOneWidget);
    await tester.tap(find.byKey(const Key('instant-work-card')));
    await tester.pumpAndSettle();
    expect(find.byType(InstantAvailabilityScreen), findsOneWidget);
  });
}
```

(The card hides when `presenceRepositoryProvider` is `DisabledDispatch`, i.e. `DISPATCH_URL` is empty; the test world overrides the repository with the fake, so it shows.)

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/instant_work/instant_availability_screen_test.dart test/features/instant_work/instant_work_card_test.dart`
Expected: FAIL to compile (screen, card and guard missing).

- [ ] **Step 3: Implement**

Strings (`lib/l10n/app_vi.arb`, then `flutter gen-l10n`):

```json
  "instantWorkTitle": "Chụp ngay",
  "instantAvailableTitle": "Live Shutter",
  "instantAvailableBody": "Nhận lời mời ở gần bạn. Vị trí được dùng khi bật.",
  "instantHelpReadyTitle": "Sẵn sàng hỗ trợ",
  "instantHelpReadyBody": "Được ưu tiên mời cả việc gấp, xa hơn một chút.",
  "instantPriceListTitle": "Bảng giá gói",
  "instantPriceListAccepted": "Bản {version} · đã đồng ý",
  "@instantPriceListAccepted": {"placeholders": {"version": {"type": "int"}}},
  "instantPriceListNew": "Bản {version} · chưa đồng ý",
  "@instantPriceListNew": {"placeholders": {"version": {"type": "int"}}},
  "instantAcceptPriceList": "Đồng ý bảng giá bản {version}",
  "@instantAcceptPriceList": {"placeholders": {"version": {"type": "int"}}},
  "instantPackageLine": "{duration} · {photos} ảnh",
  "@instantPackageLine": {"placeholders": {"duration": {"type": "String"}, "photos": {"type": "int"}}},
  "instantCustomerPays": "Khách trả {price}",
  "@instantCustomerPays": {"placeholders": {"price": {"type": "String"}}},
  "instantYouGet": "Bạn nhận",
  "instantIdleNote": "Bật lâu không mở app, chúng tôi hỏi lại sau 30 phút. Huỷ sau khi nhận làm giảm điểm tin cậy.",
  "instantTurnOffToday": "Tắt khi xong việc hôm nay",
  "instantReasonProfileIncomplete": "Hoàn tất hồ sơ nhiếp ảnh gia",
  "instantReasonNoPhone": "Thêm số điện thoại",
  "instantReasonPriceList": "Đồng ý bảng giá gói hiện hành",
  "instantReasonOutsideCity": "Bạn đang ở ngoài thành phố đã mở Chụp ngay",
  "instantReasonLocation": "Cho phép dùng vị trí khi dùng app",
  "instantFix": "Sửa",
  "instantAllow": "Cho phép",
  "instantAutoOff": "Đã tự tắt Live Shutter vì bạn chưa trả lời.",
  "instantWorkCardOn": "Đang bật · nhận lời mời gần bạn",
  "instantWorkCardOff": "Bật để nhận việc chụp ngay ở gần",
```

```dart
// lib/features/instant_work/photographer_only.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';

/// `/work/instant…` is for photographers (screens README "Vai trò").
class PhotographerOnly extends ConsumerWidget {
  const PhotographerOnly({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentProfileProvider).value?.role;
    if (role == null) {
      return const SizedBox.shrink();
    }
    if (role != UserRole.photographer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(AppTab.home.path);
        }
      });
      return const SizedBox.shrink();
    }
    return child;
  }
}
```

```dart
// lib/features/instant_work/instant_availability_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_labels.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant_common/instant_errors.dart';
import 'package:photobooking/features/instant_work/instant_session_controller.dart';
import 'package:photobooking/features/instant_work/photographer_only.dart';

/// S14.01: the availability switch, "Sẵn sàng hỗ trợ" and the price list.
class InstantAvailabilityScreen extends ConsumerStatefulWidget {
  const InstantAvailabilityScreen({super.key});

  @override
  ConsumerState<InstantAvailabilityScreen> createState() => _InstantAvailabilityScreenState();
}

class _InstantAvailabilityScreenState extends ConsumerState<InstantAvailabilityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(instantSessionProvider.notifier).refresh();
      }
    });
  }

  String _reasonText(EligibilityReason r, AppLocalizations l) => switch (r) {
    EligibilityReason.profileIncomplete => l.instantReasonProfileIncomplete,
    EligibilityReason.noPhone => l.instantReasonNoPhone,
    EligibilityReason.priceListNotAccepted => l.instantReasonPriceList,
    EligibilityReason.outsideCity => l.instantReasonOutsideCity,
    EligibilityReason.locationDenied => l.instantReasonLocation,
  };

  /// What fixes a reason, or null when the person cannot fix it here.
  (String, VoidCallback)? _fix(EligibilityReason r, AppLocalizations l) => switch (r) {
    EligibilityReason.noPhone => (
      l.instantFix,
      () => context.push('/profile/phone?returnTo=${Uri.encodeComponent('/work/instant')}'),
    ),
    EligibilityReason.profileIncomplete => (l.instantFix, () => context.push('/setup/1')),
    EligibilityReason.locationDenied => (
      l.instantAllow,
      () => ref.read(instantSessionProvider.notifier).requestLocation(),
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final s = ref.watch(instantSessionProvider);
    final session = ref.read(instantSessionProvider.notifier);
    ref.listen(instantSessionProvider.select((x) => x.error), (prev, next) {
      if (next != null && next != prev && next != DispatchError.notEligible) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(instantErrorText(next, l))));
      }
    });
    final settings = s.settings;
    final quote = s.packages;
    final accepted = settings?.priceListAccepted ?? false;
    final Widget? bottom = settings != null && !accepted
        ? AppButton.primary(
            l.instantAcceptPriceList(settings.currentPriceListVersion),
            key: const Key('instant-accept-prices'),
            onPressed: session.acceptPriceList,
          )
        : s.online
        ? AppButton.outline(l.instantTurnOffToday, key: const Key('instant-off-today'), onPressed: session.goOffline)
        : null;
    final dark = theme.brightness == Brightness.dark;
    final muted = dark ? AppColorsDark.foregroundSecondary : AppColors.foregroundSecondary;
    final plainCard = BoxDecoration(
      color: dark ? AppColorsDark.surfaceMuted : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: dark ? AppColorsDark.border : AppColors.border),
    );

    return PhotographerOnly(
      child: ScreenCode(
        ScreenCodes.instantAvailability,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(l.instantWorkTitle)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.s4),
              children: [
                if (s.askStillAvailable)
                  _Banner(
                    key: const Key('instant-still-banner'),
                    text: l.instantStillAvailableTitle,
                    action: l.instantStillAvailableKeep,
                    onAction: session.keepAvailable,
                  ),
                if (s.askLowBattery)
                  _Banner(
                    key: const Key('instant-battery-banner'),
                    text: l.instantLowBatteryBody,
                    action: l.instantTurnOff,
                    onAction: session.goOffline,
                    onClose: session.dismissLowBattery,
                  ),
                if (s.autoTurnedOff)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s3),
                    child: Text(l.instantAutoOff, style: theme.textTheme.bodySmall),
                  ),
                GlassCard(
                  child: SwitchListTile(
                    key: const Key('instant-online'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s2),
                    title: Text(l.instantAvailableTitle, style: theme.textTheme.titleMedium),
                    subtitle: Text(l.instantAvailableBody),
                    value: s.online,
                    onChanged: s.switching || (!s.online && !s.canGoOnline)
                        ? null
                        : (v) => v ? session.goOnline() : session.goOffline(),
                  ),
                ),
                for (final r in s.reasons)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s2),
                    child: Row(
                      key: Key('instant-reason-${r.code}'),
                      children: [
                        Icon(Icons.error_outline_rounded, size: 18, color: muted),
                        const SizedBox(width: AppSpace.s2),
                        Expanded(child: Text(_reasonText(r, l))),
                        if (_fix(r, l) case (final label, final onTap))
                          TextButton(key: Key('instant-reason-fix-${r.code}'), onPressed: onTap, child: Text(label)),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpace.s3),
                DecoratedBox(
                  decoration: plainCard,
                  child: SwitchListTile(
                    key: const Key('instant-help'),
                    title: Text(l.instantHelpReadyTitle),
                    subtitle: Text(l.instantHelpReadyBody),
                    value: s.helpReady,
                    onChanged: accepted ? session.setHelpReady : null,
                  ),
                ),
                const SizedBox(height: AppSpace.s5),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(l.instantPriceListTitle, style: theme.textTheme.titleMedium),
                      ),
                    ),
                    if (settings != null)
                      Text(
                        accepted
                            ? l.instantPriceListAccepted(settings.currentPriceListVersion)
                            : l.instantPriceListNew(settings.currentPriceListVersion),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.s2),
                if (quote == null && s.locationGranted && settings != null && s.error == null)
                  const AppSkeleton.box(height: 150)
                else if (quote != null)
                  for (final p in quote.packages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s2),
                      child: DecoratedBox(
                        key: Key('instant-package-${p.code.code}'),
                        decoration: plainCard,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3, vertical: AppSpace.s2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.instantPackageLine(packageLabel(p.code), p.photos), style: theme.textTheme.titleSmall),
                                    Text(l.instantCustomerPays(formatMoney(p.priceVnd)), style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(l.instantYouGet, style: theme.textTheme.bodySmall),
                                  Text(
                                    formatMoney(p.payoutVnd),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                const SizedBox(height: AppSpace.s3),
                Text(l.instantIdleNote, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          bottomNavigationBar: bottom == null
              ? null
              : SafeArea(
                  child: Padding(padding: const EdgeInsets.all(AppSpace.s4), child: bottom),
                ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text, required this.action, required this.onAction, this.onClose});
  final String text;
  final String action;
  final VoidCallback onAction;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? AppColorsDark.warningSubtle : AppColors.warningSubtle,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpace.s3),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.foreground),
              const SizedBox(width: AppSpace.s2),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.foreground),
                ),
              ),
              TextButton(onPressed: onAction, child: Text(action)),
              if (onClose != null)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.foreground),
                  onPressed: onClose,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

(The warning banner keeps dark text on `warningSubtle` in both themes, as the token pair is light-only; `AppColorsDark.warningSubtle` equals the light value.)

```dart
// lib/features/instant_work/instant_work_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/http_instant_repositories.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant_work/instant_session_controller.dart';

/// Top of the Công việc tab: on/off at a glance, opens S14.01. Hidden when the
/// dispatch service is not configured in this build.
class InstantWorkCard extends ConsumerWidget {
  const InstantWorkCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(presenceRepositoryProvider) is DisabledDispatch) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final theme = Theme.of(context);
    final online = ref.watch(instantSessionProvider.select((s) => s.online));
    final dark = theme.brightness == Brightness.dark;
    return Material(
      color: dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        key: const Key('instant-work-card'),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push('/work/instant'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, color: dark ? AppColorsDark.primary : AppColors.primary),
              const SizedBox(width: AppSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.instantWorkTitle, style: theme.textTheme.titleMedium),
                    Text(online ? l.instantWorkCardOn : l.instantWorkCardOff, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
```

`lib/features/shell/placeholder_tabs.dart`: add `import 'package:photobooking/features/instant_work/instant_work_card.dart';` and in `BookingsTab.build` replace the `body:` with

```dart
      body: photographer
          ? Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s2, AppSpace.s4, 0),
                  child: InstantWorkCard(),
                ),
                Expanded(child: EmptyState(title: l.emptyWorkTitle, body: l.emptyWorkBody)),
              ],
            )
          : EmptyState(title: l.emptyBookingsTitle, body: l.emptyBookingsBody),
```

(Step 5's S06.01 plan keeps `InstantWorkCard` as the first card of the Công việc tab; note this in that plan when it is written.)

`lib/app/router.dart`: add imports for the three instant work screens and, next to the other top-level routes (before the `StatefulShellRoute`):

```dart
      GoRoute(
        path: '/work/instant',
        builder: (_, _) => const InstantAvailabilityScreen(),
        routes: [
          GoRoute(
            path: 'offer/:offerId',
            builder: (_, state) => InstantOfferScreen(offerId: state.pathParameters['offerId']!),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => InstantJobScreen(requestId: state.pathParameters['id']!),
          ),
        ],
      ),
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/features/instant_work test/features/shell test/app && flutter analyze`
Expected: PASS (8 + 1 new tests; the shell tests still pass because customers see the old body).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/instant_work lib/features/shell lib/app/router.dart lib/l10n test/support test/features/instant_work
git commit -m "feat(instant): S14.01 availability with price list and the Công việc entry card

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: S14.02 offer screen and offer navigation

**Files:**
- Create: `lib/features/instant_work/instant_navigation.dart`, `test/features/instant_work/instant_offer_screen_test.dart`, `test/features/instant_work/instant_navigation_test.dart`
- Modify (replace the placeholder): `lib/features/instant_work/instant_offer_screen.dart`; modify `lib/app/router.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `instantOfferProvider` (Task 9), `instantJobProvider` (Task 10), `instantSessionProvider`, `TickingBuilder`, `CountdownRing`, `AppButton.danger`, `AppChip`, `showAppSheet`, `genreLabel`, `packageLabel`, `formatMoney`, `formatDistance`, `clockProvider`, `InstantNotifier.taps`/`launchTap`, `PushMessages.opened`/`initial`.
- Produces:
  - `const InstantOfferScreen({super.key, required String offerId})` (S14.02). Keys: `offer-countdown`, `offer-accept` (≥ 56dp), `offer-decline`, `decline-reason-<code>`, `decline-confirm`, `decline-keep`, `offer-expired`.
  - `void wireInstantNavigation(Ref ref, GoRouter router)`: opens `/work/instant/offer/:id` for a new pending offer, a tapped offer notification (also the one that launched the app) and an opened FCM offer; "Vẫn nhận" → `keepAvailable()`, "Tắt" → `goOffline()`. Called by `routerProvider`.
  - l10n listed in Step 3.

Layout (mock S14.02): app bar "Lời mời chụp ngay" (no back arrow; the decision is the way out); the countdown ring with whole seconds and "giây"; the payout in large type and "Bạn nhận · Chân dung 1 giờ · 30 ảnh"; a card with the area ("Khu vực Phường Bến Thành, Quận 1") and "2,1 km · khoảng 8 phút · địa chỉ hiện khi bạn nhận"; the customer's note; bottom: outline "Từ chối" (34 %) and the primary "Nhận việc" (56dp). Expired or missing offer → "Lời mời đã hết hạn" and a way back to S14.01.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/instant_work/instant_offer_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant_work/instant_job_screen.dart';
import 'package:photobooking/features/instant_work/instant_offer_screen.dart';
import 'package:photobooking/features/instant_work/instant_session_controller.dart';

import '../../support/instant_screens.dart';
import '../../support/instant_world.dart';

void main() {
  late InstantWorld w;

  setUp(() async {
    w = InstantWorld();
    await w.init();
    w.presence.settingsValue = eligibleSettings;
    w.mirror.setOffer(w.uid, w.offer());
  });

  Future<void> tick(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      w.now = w.now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('payout, package, area and distance only, the note; 30 seconds', (tester) async {
    await tester.pumpWidget(instantScreenApp(w, location: '/work/instant/offer/O1'));
    await tester.pump();
    expect(find.text('552.000₫'), findsOneWidget);
    expect(find.text('Bạn nhận · Chân dung 1 giờ'), findsOneWidget);
    expect(find.text('Khu vực Phường Bến Thành, Quận 1'), findsOneWidget);
    expect(find.text('2,1 km · khoảng 8 phút · địa chỉ hiện khi bạn nhận'), findsOneWidget);
    expect(find.text('Ghi chú của khách: “Chụp chân dung ở hồ, mình mặc áo dài trắng.”'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.textContaining('Nguyễn Thị Minh Khai'), findsNothing, reason: 'no exact address before accepting');
  });

  testWidgets('with the price list loaded the summary has the photos', (tester) async {
    await tester.pumpWidget(instantScreenApp(w, location: '/work/instant/offer/O1'));
    final c = ProviderScope.containerOf(tester.element(find.byType(InstantOfferScreen)));
    await c.read(instantSessionProvider.notifier).refresh();
    await tester.pump();
    expect(find.text('Bạn nhận · Chân dung 1 giờ · 30 ảnh'), findsOneWidget);
  });

  testWidgets('the countdown is right to the second, in numbers and in words', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(instantScreenApp(w, location: '/work/instant/offer/O1'));
    await tester.pump();
    await tick(tester, 8);
    expect(find.text('22'), findsOneWidget);
    expect(find.bySemanticsLabel('Còn 22 giây'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('"Nhận việc" is at least 56dp and the only gradient button; accepting opens S14.03', (tester) async {
    await tester.pumpWidget(instantScreenApp(w, location: '/work/instant/offer/O1'));
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('offer-accept'))).height, greaterThanOrEqualTo(56));
    expect(find.byType(CtaSurface), findsOneWidget);
    await tester.tap(find.byKey(const Key('offer-accept')));
    await tester.pump();
    await tester.pump();
    expect(w.jobs.calls, ['accept O1']);
    expect(find.byType(InstantJobScreen), findsOneWidget);
  });

  testWidgets('someone else was faster: a message and back to S14.01', (tester) async {
    w.jobs.acceptError = DispatchError.alreadyAssigned;
    await tester.pumpWidget(instantScreenApp(w, location: '/work/instant/offer/O1'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('offer-accept')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Yêu cầu đã có người nhận'), findsOneWidget);
  });

  testWidgets('"Từ chối" opens a sheet; the red confirmation sends the optional reason', (tester) async {
    await tester.pumpWidget(instantScreenApp(w, location: '/work/instant/offer/O1'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('offer-decline')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Từ chối lời mời?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('decline-reason-busy')));
    await tester.pump();
    final confirm = find.descendant(of: find.byKey(const Key('decline-confirm')), matching: find.byType(FilledButton));
    expect(tester.widget<FilledButton>(confirm).style!.backgroundColor!.resolve(const {}), AppColors.destructive);
    await tester.tap(find.byKey(const Key('decline-confirm')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(w.jobs.calls, ['decline O1 busy']);
  });

  testWidgets('at zero the timer stops and the screen says the offer expired', (tester) async {
    await tester.pumpWidget(instantScreenApp(w, location: '/work/instant/offer/O1'));
    await tester.pump();
    expect(TickingBuilder.debugActiveCount, 1);
    await tick(tester, 31);
    await tester.pump();
    expect(find.byKey(const Key('offer-expired')), findsOneWidget);
    expect(find.text('Lời mời đã hết hạn'), findsOneWidget);
    expect(TickingBuilder.debugActiveCount, 0);
  });

  testWidgets('a different or missing offer is shown as expired', (tester) async {
    await tester.pumpWidget(instantScreenApp(w, location: '/work/instant/offer/O9'));
    await tester.pump();
    expect(find.byKey(const Key('offer-expired')), findsOneWidget);
    expect(TickingBuilder.debugActiveCount, 0);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x (${b.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(instantScreenApp(w, location: '/work/instant/offer/O1', brightness: b, textScale: 1.3));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
```

```dart
// test/features/instant_work/instant_navigation_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/instant/instant_notifier.dart';
import 'package:photobooking/data/instant/instant_push.dart';
import 'package:photobooking/features/instant_work/instant_navigation.dart';
import 'package:photobooking/features/instant_work/instant_session_controller.dart';

import '../../support/instant_world.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const Text('home')),
      GoRoute(path: '/work/instant/offer/:id', builder: (_, s) => Text('offer ${s.pathParameters['id']}')),
    ],
  );
  wireInstantNavigation(ref, router);
  return router;
});

class _App extends ConsumerWidget {
  const _App();
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(routerConfig: ref.watch(_routerProvider));
}

void main() {
  late InstantWorld w;
  setUp(() async {
    w = InstantWorld();
    await w.init();
    w.presence.settingsValue = eligibleSettings;
  });

  Widget app() => ProviderScope(overrides: w.overrides, child: const _App());

  testWidgets('a tapped offer notification opens S14.02', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    w.notifier.tap(const InstantTap(InstantTapKind.offer, id: 'O7'));
    await tester.pumpAndSettle();
    expect(find.text('offer O7'), findsOneWidget);
  });

  testWidgets('the notification that launched the app is followed', (tester) async {
    w.notifier.launch = const InstantTap(InstantTapKind.offer, id: 'O8');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('offer O8'), findsOneWidget);
  });

  testWidgets('a new pending offer while the app is open opens S14.02 once', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.text('home')));
    await c.read(instantSessionProvider.notifier).goOnline();
    w.mirror.setOffer(w.uid, w.offer(id: 'O3'));
    await tester.pumpAndSettle();
    expect(find.text('offer O3'), findsOneWidget);
  });

  testWidgets('an opened FCM offer (iOS alert) opens S14.02; "Tắt" turns availability off', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.text('home')));
    await c.read(instantSessionProvider.notifier).goOnline();
    w.push.open(OfferPush(w.offer(id: 'O4')));
    await tester.pumpAndSettle();
    expect(find.text('offer O4'), findsOneWidget);
    w.notifier.tap(const InstantTap(InstantTapKind.turnOff));
    await tester.pumpAndSettle();
    expect(c.read(instantSessionProvider).online, isFalse);
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/instant_work/instant_offer_screen_test.dart test/features/instant_work/instant_navigation_test.dart`
Expected: FAIL (placeholder screen; `instant_navigation.dart` missing).

- [ ] **Step 3: Implement**

Strings (`lib/l10n/app_vi.arb`, then `flutter gen-l10n`):

```json
  "instantOfferTitle": "Lời mời chụp ngay",
  "instantSeconds": "giây",
  "instantOfferRemaining": "Còn {seconds} giây",
  "@instantOfferRemaining": {"placeholders": {"seconds": {"type": "int"}}},
  "instantOfferSummary": "Bạn nhận · {genre} {duration} · {photos} ảnh",
  "@instantOfferSummary": {"placeholders": {"genre": {"type": "String"}, "duration": {"type": "String"}, "photos": {"type": "int"}}},
  "instantOfferSummaryShort": "Bạn nhận · {genre} {duration}",
  "@instantOfferSummaryShort": {"placeholders": {"genre": {"type": "String"}, "duration": {"type": "String"}}},
  "instantOfferArea": "Khu vực {area}",
  "@instantOfferArea": {"placeholders": {"area": {"type": "String"}}},
  "instantOfferDistance": "{distance} · khoảng {minutes} phút · địa chỉ hiện khi bạn nhận",
  "@instantOfferDistance": {"placeholders": {"distance": {"type": "String"}, "minutes": {"type": "int"}}},
  "instantOfferNote": "Ghi chú của khách: “{note}”",
  "@instantOfferNote": {"placeholders": {"note": {"type": "String"}}},
  "instantOfferAccept": "Nhận việc",
  "instantOfferDecline": "Từ chối",
  "instantOfferExpiredBody": "Lời mời chỉ giữ 30 giây. Bạn vẫn đang bật Live Shutter.",
  "instantBackToAvailability": "Về Chụp ngay",
  "instantDeclineTitle": "Từ chối lời mời?",
  "instantDeclineBody": "Lý do (không bắt buộc) giúp chúng tôi mời bạn đúng việc hơn.",
  "instantDeclineTooFar": "Xa quá",
  "instantDeclineBusy": "Đang bận",
  "instantDeclineGenre": "Không hợp kiểu chụp",
  "instantDeclineOther": "Lý do khác",
  "instantDeclineConfirm": "Từ chối lời mời",
  "instantDeclineKeep": "Xem lại lời mời",
  "instantLoading": "Đang tải",
```

```dart
// lib/features/instant_work/instant_offer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/instant/instant_labels.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant_common/instant_errors.dart';
import 'package:photobooking/features/instant_work/instant_job_controller.dart';
import 'package:photobooking/features/instant_work/instant_session_controller.dart';
import 'package:photobooking/features/instant_work/photographer_only.dart';

const _offerWindow = Duration(seconds: 30);

/// S14.02: one offer, 30 seconds, area and distance only.
class InstantOfferScreen extends ConsumerStatefulWidget {
  const InstantOfferScreen({super.key, required this.offerId});
  final String offerId;

  @override
  ConsumerState<InstantOfferScreen> createState() => _InstantOfferScreenState();
}

class _InstantOfferScreenState extends ConsumerState<InstantOfferScreen> {
  bool _expired = false;

  void _markExpired() {
    if (!_expired && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _expired = true);
        }
      });
    }
  }

  Future<void> _accept() async {
    final job = ref.read(instantJobProvider.notifier);
    if (await job.accept(widget.offerId) && mounted) {
      context.go('/work/instant/${ref.read(instantJobProvider).requestId}');
    }
  }

  Future<void> _decline() async {
    final choice = await showAppSheet<(bool, DeclineReason?)>(
      context,
      builder: (_) => const _DeclineSheet(),
    );
    if (choice == null || !choice.$1 || !mounted) {
      return;
    }
    await ref.read(instantJobProvider.notifier).decline(widget.offerId, reason: choice.$2);
    if (mounted) {
      context.go('/work/instant');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final offerAsync = ref.watch(instantOfferProvider);
    final offer = offerAsync.value;
    final busy = ref.watch(instantJobProvider.select((s) => s.busy));
    final photos = offer == null
        ? null
        : ref.watch(instantSessionProvider.select((s) => s.packages?.byCode(offer.packageCode)?.photos));
    ref.listen(instantJobProvider.select((s) => s.error), (prev, next) {
      if (next != null && next != prev) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(instantErrorText(next, l))));
        if (next == DispatchError.offerExpired || next == DispatchError.alreadyAssigned) {
          setState(() => _expired = true);
        }
      }
    });
    final now = ref.read(clockProvider)();
    final live = offer != null && offer.offerId == widget.offerId && !_expired && !offer.isExpired(now);

    Widget body;
    if (offerAsync.isLoading && !offerAsync.hasValue) {
      body = Center(child: ApertureLoader(semanticsLabel: l.instantLoading));
    } else if (!live) {
      body = EmptyState(
        key: const Key('offer-expired'),
        title: l.instantOfferExpired,
        body: l.instantOfferExpiredBody,
        actionLabel: l.instantBackToAvailability,
        onAction: () => context.go('/work/instant'),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.all(AppSpace.s5),
        children: [
          Center(
            child: TickingBuilder(
              active: true,
              builder: (context) {
                final left = offer.remaining(ref.read(clockProvider)());
                if (left == Duration.zero) {
                  _markExpired();
                }
                final seconds = (left.inMilliseconds / 1000).ceil();
                return CountdownRing(
                  key: const Key('offer-countdown'),
                  remaining: left,
                  total: _offerWindow,
                  unit: l.instantSeconds,
                  semanticsLabel: l.instantOfferRemaining(seconds),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            formatMoney(offer.payoutVnd),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          Text(
            photos == null
                ? l.instantOfferSummaryShort(genreLabel(offer.genre, l), packageLabel(offer.packageCode))
                : l.instantOfferSummary(genreLabel(offer.genre, l), packageLabel(offer.packageCode), photos),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpace.s4),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark ? AppColorsDark.surfaceMuted : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s3),
              child: Row(
                children: [
                  const Icon(Icons.place_outlined),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.instantOfferArea(offer.area), style: theme.textTheme.titleSmall),
                        Text(
                          l.instantOfferDistance(formatDistance(offer.distanceKm), offer.travelMinutes),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (offer.note case final note? when note.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpace.s3),
            Text(l.instantOfferNote(note.trim()), style: theme.textTheme.bodySmall),
          ],
        ],
      );
    }

    return PhotographerOnly(
      child: ScreenCode(
        ScreenCodes.instantOffer,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(automaticallyImplyLeading: false, centerTitle: true, title: Text(l.instantOfferTitle)),
          body: SafeArea(child: body),
          bottomNavigationBar: !live
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 34,
                          child: AppButton.outline(
                            l.instantOfferDecline,
                            key: const Key('offer-decline'),
                            onPressed: busy ? null : _decline,
                          ),
                        ),
                        const SizedBox(width: AppSpace.s3),
                        Expanded(
                          flex: 66,
                          child: SizedBox(
                            height: 56,
                            child: AppButton.primary(
                              l.instantOfferAccept,
                              key: const Key('offer-accept'),
                              loading: busy,
                              onPressed: _accept,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _DeclineSheet extends StatefulWidget {
  const _DeclineSheet();

  @override
  State<_DeclineSheet> createState() => _DeclineSheetState();
}

class _DeclineSheetState extends State<_DeclineSheet> {
  DeclineReason? _reason;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final reasons = [
      (DeclineReason.tooFar, l.instantDeclineTooFar),
      (DeclineReason.busy, l.instantDeclineBusy),
      (DeclineReason.genreMismatch, l.instantDeclineGenre),
      (DeclineReason.other, l.instantDeclineOther),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.s5, AppSpace.s2, AppSpace.s5, AppSpace.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(l.instantDeclineTitle, style: theme.textTheme.titleLarge)),
          const SizedBox(height: AppSpace.s2),
          Text(l.instantDeclineBody, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpace.s3),
          Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: [
              for (final (r, label) in reasons)
                AppChip(
                  key: Key('decline-reason-${r.code}'),
                  label: label,
                  selected: _reason == r,
                  onChanged: (on) => setState(() => _reason = on ? r : null),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          AppButton.danger(
            l.instantDeclineConfirm,
            key: const Key('decline-confirm'),
            onPressed: () => Navigator.of(context).pop((true, _reason)),
          ),
          const SizedBox(height: AppSpace.s2),
          AppButton.text(
            l.instantDeclineKeep,
            key: const Key('decline-keep'),
            onPressed: () => Navigator.of(context).pop((false, null)),
          ),
        ],
      ),
    );
  }
}
```

```dart
// lib/features/instant_work/instant_navigation.dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/data/instant/instant_notifier.dart';
import 'package:photobooking/data/instant/instant_push.dart';
import 'package:photobooking/features/instant_common/instant_services.dart';
import 'package:photobooking/features/instant_work/instant_session_controller.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Offers reach S14.02 from four places: the mirror while the app is open, a
/// tapped local notification (Android full-screen / heads-up), the
/// notification that launched the app, and an opened FCM alert (iOS).
void wireInstantNavigation(Ref ref, GoRouter router) {
  void openOffer(String id) {
    final target = '/work/instant/offer/$id';
    if (router.routerDelegate.currentConfiguration.uri.path != target) {
      router.push(target);
    }
  }

  void onTap(InstantTap t) {
    final session = ref.read(instantSessionProvider.notifier);
    switch (t.kind) {
      case InstantTapKind.offer:
        if (t.id != null) {
          openOffer(t.id!);
        }
      case InstantTapKind.keepAvailable:
        session.keepAvailable();
      case InstantTapKind.turnOff:
        session.goOffline();
    }
  }

  void onPush(InstantPush p) {
    if (p is OfferPush) {
      openOffer(p.offer.offerId);
    }
  }

  ref.listen(instantSessionProvider.select((s) => s.pendingOffer?.offerId), (prev, next) {
    if (next != null && next != prev) {
      openOffer(next);
    }
  });

  final notifier = ref.read(instantNotifierProvider);
  final push = ref.read(pushMessagesProvider);
  final subs = <StreamSubscription<Object?>>[
    notifier.taps.listen(onTap),
    push.opened.listen(onPush),
  ];
  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
  });
  () async {
    try {
      await notifier.init(lookupAppLocalizations(const Locale('vi')));
      final launched = await notifier.launchTap();
      if (launched != null) {
        onTap(launched);
      }
      final initial = await push.initial();
      if (initial != null) {
        onPush(initial);
      }
    } on Object {
      // No notification plugin (tests, desktop): nothing launched the app.
    }
  }();
}
```

`lib/app/router.dart`: add `import 'package:photobooking/features/instant_work/instant_navigation.dart';`, and in `routerProvider` replace `return GoRouter(…);` with `final router = GoRouter(…);` followed by `wireInstantNavigation(ref, router);` and `return router;`.

- [ ] **Step 4: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/features/instant_work test/app && flutter analyze`
Expected: PASS (10 + 4 new tests; `test/app/router_test.dart` keeps passing because the fakes it overrides do not include the notifier: add `instantNotifierProvider.overrideWithValue(FakeInstantNotifier())`, `pushMessagesProvider.overrideWithValue(FakePushMessages())`, `foregroundSessionProvider.overrideWithValue(FakeForegroundSession())` to the `ProviderContainer`s of `test/app/router_test.dart` and `test/app/discovery_routes_test.dart` if they read `routerProvider`, otherwise they would build the real plugins).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/instant_work lib/app/router.dart lib/l10n test
git commit -m "feat(instant): S14.02 offer with a 30-second countdown and offer navigation from notifications

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: S14.03 job screen (map, "Chỉ đường", milestones, state buttons, contact)

**Files:**
- Modify (replace the placeholder): `lib/features/instant_work/instant_job_screen.dart`
- Modify: `lib/data/contact/contact_link_repository.dart` (plan 2b: `ContactSubject.instant`), `test/data/contact/contact_link_repository_test.dart`, `lib/l10n/app_vi.arb`
- Create: `test/features/instant_work/instant_job_screen_test.dart`

**Interfaces:**
- Consumes: `instantJobProvider`, `instantRequestProvider`, `AppMap`, `MapMarker`, `ApertureLoader`, `InstantMilestones`, `showInstantCancelSheet`, `canArrive`, `gpsPoor`, `metersTo`, `ContactAction` (`ContactAction({required ContactAccess access, required List<ContactChannel> channels, required String source, ContactSubject? subject, ContactDialStyle style, VoidCallback? onInquiry})`), `formatDistance`, `toVn`, `genreLabel`, `packageLabel`.
- Produces:
  - `const ContactSubject.instant(String id)` with `ContactSubjectType.instant`; `callableData` sends `{instantRequestId, channel}`.
  - `const InstantJobScreen({super.key, required String requestId})` (S14.03). Keys: `job-map`, `job-directions`, `job-arrive`, `job-arrive-force`, `arrive-reason`, `arrive-force-confirm`, `job-start`, `job-finish`, `job-cancel`, `job-chat`, `job-done`.
  - l10n listed in Step 3.

Layout (mock S14.03): app bar "Đang đến" / "Đã đến" / "Đang chụp" with "Lan Anh · Chân dung 1 giờ" under it, a chat icon (→ `/chat/:requestId`) and the call dial; a 160dp `AppMap` while on the way or arrived (pins "Bạn" and the customer's name, fitted; "Về vị trí của tôi" refits); the exact address with the distance and "Chỉ đường" (opens the first maps app that can: Android `geo:`, iOS Apple Maps, else Google Maps on the web); milestones "Đã nhận · 15:21", "Đã đến (bật khi còn cách 200 m)", "Bắt đầu chụp · Hoàn thành"; the note about the notification while sharing; a red text "Huỷ việc" (→ S13.08 photographer); bottom primary by state: "Đã đến" (disabled beyond 200 m with "Còn cách 0,6 km…"; when GPS accuracy is worse than 100 m an extra text button "Tôi đã đến nơi (GPS yếu)" opens a reason sheet and sends `force`), then "Bắt đầu chụp", then "Hoàn thành". After finishing or cancelling, a short summary and "Về Chụp ngay".

- [ ] **Step 1: Write the failing tests**

Append to `test/data/contact/contact_link_repository_test.dart`:

```dart
  test('an instant request is its own contact subject', () {
    expect(
      callableData(const ContactSubject.instant('R1'), ContactChannel.call),
      {'instantRequestId': 'R1', 'channel': 'call'},
    );
    expect(const ContactSubject.instant('R1'), isNot(const ContactSubject.booking('R1')));
  });
```

```dart
// test/features/instant_work/instant_job_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';

import '../../support/blur.dart';
import '../../support/instant_screens.dart';
import '../../support/instant_world.dart';

void main() {
  late InstantWorld w;

  setUp(() async {
    w = InstantWorld();
    await w.init();
    w.presence.settingsValue = eligibleSettings;
    w.mirror.setRequest('R1', w.view(InstantStatus.enRoute));
  });

  Future<void> open(WidgetTester tester, {Brightness b = Brightness.dark, double scale = 1}) async {
    await tester.pumpWidget(instantScreenApp(w, location: '/work/instant/R1', brightness: b, textScale: scale));
    await tester.pump();
    await tester.pump();
  }

  FilledButton primary(WidgetTester tester, String key) => tester.widget<FilledButton>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(FilledButton)),
  );

  testWidgets('en route and far: map with labelled pins, the address, "Đã đến" disabled with the distance', (tester) async {
    await open(tester);
    w.location.moveRoute(w.fixAt(600));
    await tester.pump();
    expect(find.byKey(const Key('fake-map')), findsOneWidget);
    expect(w.map.last!.markers.map((m) => m.label), containsAll(['Bạn', 'Khách']));
    expect(find.textContaining('Cổng Trương Định'), findsOneWidget);
    expect(find.text('Đang đến'), findsOneWidget);
    expect(primary(tester, 'job-arrive').onPressed, isNull);
    expect(find.textContaining('Còn cách 0,6 km'), findsOneWidget);
    expect(find.byKey(const Key('job-arrive-force')), findsNothing, reason: 'GPS is good');
  });

  testWidgets('within 200 m "Đã đến" works; then the GPS stops and "Bắt đầu chụp" is next', (tester) async {
    await open(tester);
    w.location.moveRoute(w.fixAt(150));
    await tester.pump();
    await tester.tap(find.byKey(const Key('job-arrive')));
    await tester.pump();
    await tester.pump();
    expect(w.jobs.calls, contains('arrive R1'));
    expect(w.location.routeListeners, 0);
    expect(find.byKey(const Key('job-start')), findsOneWidget);
    await tester.tap(find.byKey(const Key('job-start')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('job-finish')), findsOneWidget);
    expect(find.byKey(const Key('fake-map')), findsNothing, reason: 'no map while shooting');
    await tester.tap(find.byKey(const Key('job-finish')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('job-done')), findsOneWidget);
  });

  testWidgets('poor GPS: confirm arrival with a reason', (tester) async {
    await open(tester);
    w.location.moveRoute(w.fixAt(400, accuracy: 180));
    await tester.pump();
    await tester.tap(find.byKey(const Key('job-arrive-force')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byKey(const Key('arrive-reason')), 'Đang đứng ở cổng chính');
    await tester.tap(find.byKey(const Key('arrive-force-confirm')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(w.jobs.calls, contains('arrive R1 force'));
  });

  testWidgets('"Chỉ đường" opens an external maps app', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('job-directions')));
    await tester.pump();
    expect(w.launcher.opened, hasLength(1));
  });

  testWidgets('"Huỷ việc" shows the photographer sheet and cancels after the red confirmation', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('job-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Khách được hoàn 690.000₫. Huỷ sau khi nhận làm giảm điểm tin cậy.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-confirm')));
    await tester.pumpAndSettle();
    expect(w.jobs.calls, containsAllInOrder(['quote R1', 'cancel R1']));
    expect(find.byKey(const Key('job-done')), findsOneWidget);
    expect(w.location.activeStreams, 0);
  });

  testWidgets('chat and call for the customer; the call goes through the instant subject', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('job-chat')), findsOneWidget);
    await tester.tap(find.byKey(const Key('job-chat')));
    await tester.pumpAndSettle();
    expect(find.text('chat R1'), findsOneWidget);
  });

  testWidgets('one blur at most; the map is the only platform view', (tester) async {
    await open(tester);
    expectBlurBudget();
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x (${b.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, b: b, scale: 1.3);
      w.location.moveRoute(w.fixAt(600, accuracy: 180));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/instant_work/instant_job_screen_test.dart test/data/contact/contact_link_repository_test.dart`
Expected: FAIL (placeholder screen; no `ContactSubject.instant`).

- [ ] **Step 3: Implement**

In `lib/data/contact/contact_link_repository.dart` (plan 2b):

1. `enum ContactSubjectType { booking, registration }` → `enum ContactSubjectType { booking, registration, instant }`.
2. Add the constructor `const ContactSubject.instant(this.id) : type = ContactSubjectType.instant;` (doc: "a paid Chụp ngay request; either party may call the other while it is assigned…in progress").
3. In `callableData`, add the case `ContactSubjectType.instant => 'instantRequestId',`.

(The server side — the `getContactLink` callable of phase 1 and `POST /v1/contact-links` of phase 2 — must accept `instantRequestId`, unlock it while the request is `assigned`…`in_progress` and for 30 days after `completed`, and return the other party's number. Until it does, the call fails with "Không mở được liên hệ" and the chat still works; Task 15 records this in the spec.)

Strings (`lib/l10n/app_vi.arb`, then `flutter gen-l10n`):

```json
  "instantJobEnRoute": "Đang đến",
  "instantJobArrived": "Đã đến",
  "instantJobInProgress": "Đang chụp",
  "instantJobSubtitle": "{name} · {genre} {duration}",
  "@instantJobSubtitle": {"placeholders": {"name": {"type": "String"}, "genre": {"type": "String"}, "duration": {"type": "String"}}},
  "instantCustomer": "Khách",
  "instantYou": "Bạn",
  "instantMapLabel": "Bản đồ đường đi",
  "instantDirections": "Chỉ đường",
  "instantDirectionsError": "Không mở được ứng dụng bản đồ.",
  "instantMilestoneAccepted": "Đã nhận · {time}",
  "@instantMilestoneAccepted": {"placeholders": {"time": {"type": "String"}}},
  "instantMilestoneArrivePending": "Đã đến (bật khi còn cách 200 m)",
  "instantMilestoneArrived": "Đã đến · {time}",
  "@instantMilestoneArrived": {"placeholders": {"time": {"type": "String"}}},
  "instantMilestoneStartFinish": "Bắt đầu chụp · Hoàn thành",
  "instantMilestoneStarted": "Bắt đầu chụp · {time}",
  "@instantMilestoneStarted": {"placeholders": {"time": {"type": "String"}}},
  "instantSharingNote": "Thông báo “Đang nhận việc chụp ngay” hiện trong lúc chia sẻ vị trí. Tới nơi là dừng.",
  "instantArrive": "Đã đến",
  "instantArriveFar": "Còn cách {distance}. Nút Đã đến bật khi bạn cách điểm hẹn 200 m.",
  "@instantArriveFar": {"placeholders": {"distance": {"type": "String"}}},
  "instantArriveForce": "Tôi đã đến nơi (GPS yếu)",
  "instantArriveForceTitle": "Xác nhận đã đến",
  "instantArriveForceBody": "GPS đang kém nên chưa đo được khoảng cách. Ghi lý do để chúng tôi lưu lại.",
  "instantArriveReasonLabel": "Lý do",
  "instantArriveForceConfirm": "Xác nhận đã đến",
  "instantStart": "Bắt đầu chụp",
  "instantFinish": "Hoàn thành",
  "instantFinishedTitle": "Đã báo hoàn thành",
  "instantFinishedBody": "Khách xác nhận, hoặc tự hoàn thành sau 2 giờ. Bạn có thể nhận việc tiếp.",
  "instantCancelledTitle": "Đã huỷ việc",
  "instantCancelledBody": "Khách được hoàn tiền đầy đủ.",
  "instantClosedTitle": "Yêu cầu đã kết thúc",
  "instantClosedBody": "Khách đã huỷ hoặc yêu cầu đã đóng.",
  "instantCancelJob": "Huỷ việc",
  "instantMessage": "Nhắn tin",
```

```dart
// lib/features/instant_work/instant_job_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/instant/instant_labels.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/contact/contact_action.dart';
import 'package:photobooking/features/instant_common/instant_cancel_sheet.dart';
import 'package:photobooking/features/instant_common/instant_errors.dart';
import 'package:photobooking/features/instant_common/instant_milestones.dart';
import 'package:photobooking/features/instant_work/instant_job_controller.dart';
import 'package:photobooking/features/instant_work/instant_rules.dart';
import 'package:photobooking/features/instant_work/photographer_only.dart';

/// S14.03: on the way, arrived, shooting. The route stream lives in
/// [InstantJobController]; this screen only shows it.
class InstantJobScreen extends ConsumerStatefulWidget {
  const InstantJobScreen({super.key, required this.requestId});
  final String requestId;

  @override
  ConsumerState<InstantJobScreen> createState() => _InstantJobScreenState();
}

class _InstantJobScreenState extends ConsumerState<InstantJobScreen> {
  int _camera = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final job = ref.read(instantJobProvider);
      if (mounted && job.requestId != widget.requestId && job.endedRequestId != widget.requestId) {
        ref.read(instantJobProvider.notifier).resume(widget.requestId);
      }
    });
  }

  String _time(DateTime? t) => t == null ? '' : DateFormat('HH:mm').format(toVn(t));

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _forceArrive() async {
    final reason = await showAppSheet<String>(context, builder: (_) => const _ForceArriveSheet());
    if (reason != null && mounted) {
      await ref.read(instantJobProvider.notifier).arrive(force: true, reason: reason);
    }
  }

  Future<void> _directions() async {
    final ok = await ref.read(instantJobProvider.notifier).openDirections(defaultTargetPlatform);
    if (!ok && mounted) {
      _snack(context.l10n.instantDirectionsError);
    }
  }

  Future<void> _cancel() async {
    final job = ref.read(instantJobProvider.notifier);
    await showInstantCancelSheet(
      context,
      role: InstantCancelRole.photographer,
      quote: job.quoteCancel,
      confirm: job.confirmCancel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final job = ref.watch(instantJobProvider);
    final view = ref.watch(instantRequestProvider(widget.requestId)).value;
    ref.listen(instantJobProvider.select((s) => s.error), (prev, next) {
      if (next != null && next != prev) {
        _snack(instantErrorText(next, l));
      }
    });

    Widget scaffold({required Widget body, Widget? bottom, String? title, String? subtitle, List<Widget> actions = const []}) =>
        PhotographerOnly(
          child: ScreenCode(
            ScreenCodes.instantJob,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: title == null
                    ? null
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title),
                          if (subtitle != null) Text(subtitle, style: theme.textTheme.bodySmall),
                        ],
                      ),
                actions: actions,
              ),
              body: SafeArea(child: body),
              bottomNavigationBar: bottom == null
                  ? null
                  : SafeArea(child: Padding(padding: const EdgeInsets.all(AppSpace.s4), child: bottom)),
            ),
          ),
        );

    if (job.endedRequestId == widget.requestId) {
      final (title, body) = switch (job.ended) {
        InstantJobEnd.finished => (l.instantFinishedTitle, l.instantFinishedBody),
        InstantJobEnd.cancelled => (l.instantCancelledTitle, l.instantCancelledBody),
        _ => (l.instantClosedTitle, l.instantClosedBody),
      };
      return scaffold(
        body: EmptyState(
          key: const Key('job-done'),
          title: title,
          body: body,
          actionLabel: l.instantBackToAvailability,
          onAction: () => context.go('/work/instant'),
        ),
      );
    }

    final meet = job.meetPoint ?? view?.meetPoint;
    if (job.requestId != widget.requestId || meet == null) {
      return scaffold(body: Center(child: ApertureLoader(semanticsLabel: l.instantLoading)));
    }

    final status = job.status ?? view?.status ?? InstantStatus.assigned;
    final fix = job.lastFix;
    final customer = job.customerName ?? l.instantCustomer;
    final onTheWay = status.onTheWay;
    final arrived = status == InstantStatus.arrived;
    final shooting = status == InstantStatus.inProgress;
    final meters = metersTo(fix, meet);
    final danger = theme.brightness == Brightness.dark ? AppColorsDark.destructive : AppColors.destructive;

    final Widget bottom;
    if (onTheWay) {
      final near = canArrive(fix, meet);
      bottom = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!near && meters != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s2),
              child: Text(l.instantArriveFar(formatDistance(meters / 1000)), style: theme.textTheme.bodySmall),
            ),
          AppButton.primary(
            l.instantArrive,
            key: const Key('job-arrive'),
            loading: job.busy,
            onPressed: near ? () => ref.read(instantJobProvider.notifier).arrive() : null,
          ),
          if (!near && gpsPoor(fix))
            AppButton.text(l.instantArriveForce, key: const Key('job-arrive-force'), onPressed: _forceArrive),
        ],
      );
    } else if (arrived) {
      bottom = AppButton.primary(
        l.instantStart,
        key: const Key('job-start'),
        loading: job.busy,
        onPressed: () => ref.read(instantJobProvider.notifier).start(),
      );
    } else {
      bottom = AppButton.primary(
        l.instantFinish,
        key: const Key('job-finish'),
        loading: job.busy,
        onPressed: () => ref.read(instantJobProvider.notifier).finish(),
      );
    }

    final duration = view == null ? '' : packageLabel(view.packageCode);
    final genre = view == null ? '' : genreLabel(view.genre, l);
    return scaffold(
      title: shooting ? l.instantJobInProgress : (arrived ? l.instantJobArrived : l.instantJobEnRoute),
      subtitle: view == null ? customer : l.instantJobSubtitle(customer, genre, duration),
      actions: [
        IconButton(
          key: const Key('job-chat'),
          tooltip: l.instantMessage,
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          onPressed: () => context.push('/chat/${widget.requestId}'),
        ),
        ContactAction(
          access: ContactAccess.unlocked,
          channels: const [ContactChannel.call],
          source: ScreenCodes.instantJob,
          subject: ContactSubject.instant(widget.requestId),
        ),
        const SizedBox(width: AppSpace.s2),
      ],
      bottom: bottom,
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.s4),
        children: [
          if (!shooting)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: SizedBox(
                key: const Key('job-map'),
                height: 160,
                child: AppMap(
                  center: meet.latLng,
                  semanticsLabel: l.instantMapLabel,
                  fitMarkers: true,
                  cameraToken: _camera,
                  onMyLocation: () => setState(() => _camera++),
                  markers: [
                    MapMarker(id: 'meet', at: meet.latLng, label: customer, kind: MapMarkerKind.meetPoint),
                    if (fix != null) MapMarker(id: 'me', at: fix.latLng, label: l.instantYou, kind: MapMarkerKind.self),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpace.s3),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meet.address, style: theme.textTheme.titleSmall),
                    if (meters != null)
                      Text(formatDistance(meters / 1000), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              AppButton.outline(l.instantDirections, key: const Key('job-directions'), onPressed: _directions),
            ],
          ),
          const SizedBox(height: AppSpace.s3),
          InstantMilestones(
            items: [
              Milestone(l.instantMilestoneAccepted(_time(view?.assignedAt)), done: true),
              Milestone(
                arrived || shooting ? l.instantMilestoneArrived(_time(view?.arrivedAt)) : l.instantMilestoneArrivePending,
                done: arrived || shooting,
              ),
              Milestone(
                shooting ? l.instantMilestoneStarted(_time(view?.startedAt)) : l.instantMilestoneStartFinish,
                done: shooting,
              ),
            ],
          ),
          if (onTheWay) ...[
            const SizedBox(height: AppSpace.s3),
            Text(l.instantSharingNote, style: theme.textTheme.bodySmall),
          ],
          if (!shooting)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('job-cancel'),
                onPressed: _cancel,
                child: Text(l.instantCancelJob, style: TextStyle(color: danger)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ForceArriveSheet extends StatefulWidget {
  const _ForceArriveSheet();

  @override
  State<_ForceArriveSheet> createState() => _ForceArriveSheetState();
}

class _ForceArriveSheetState extends State<_ForceArriveSheet> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.s5, AppSpace.s2, AppSpace.s5, AppSpace.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(l.instantArriveForceTitle, style: Theme.of(context).textTheme.titleLarge)),
          const SizedBox(height: AppSpace.s2),
          Text(l.instantArriveForceBody),
          const SizedBox(height: AppSpace.s3),
          TextField(
            key: const Key('arrive-reason'),
            controller: _reason,
            maxLength: 140,
            decoration: InputDecoration(labelText: l.instantArriveReasonLabel),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpace.s3),
          AppButton.primary(
            l.instantArriveForceConfirm,
            key: const Key('arrive-force-confirm'),
            onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.of(context).pop(_reason.text.trim()),
          ),
        ],
      ),
    );
  }
}
```

(`ContactAccess`, `ContactChannel` come from `core.dart`; `ContactAction` from 2b's `lib/features/contact/contact_action.dart`.)

- [ ] **Step 4: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/features/instant_work test/data/contact && flutter analyze`
Expected: PASS (1 + 9 new tests).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/instant_work lib/data/contact lib/l10n test
git commit -m "feat(instant): S14.03 job screen with directions, milestones, arrive within 200 m and the cancel sheet

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: Align the specs and the battery guide with what was built

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-instant-booking-design.md`, `docs/superpowers/specs/components/shared-components.md`, `docs/testing/battery-and-performance.md`

**Interfaces:** none (documentation).

- [ ] **Step 1: Edit**

1. `2026-10-01-instant-booking-design.md`:
   - §5, after "**Gọi dịch vụ**", add: "Ứng dụng đọc địa chỉ dịch vụ từ `--dart-define=DISPATCH_URL` (trống thì ẩn Chụp ngay) và dùng chung `ApiClient` + ID token của backend giai đoạn 2. **FCM** (dữ liệu là chuỗi): `type=offer` kèm mọi trường của `InstantOfferMirror`; `type=assigned` + `requestId`; `type=status` + `requestId`, `status`. Android gửi data-only `priority: high` (app tự hiện thông báo toàn màn); iOS gửi kèm alert APNs `interruption-level: time-sensitive`. **Token thiết bị**: `devices/{uid}_{installId}` `{userId, provider: 'fcm', token, platform, lastSeenAt}` (thực thể `Device`), chỉ chủ ghi; dịch vụ đọc bằng Admin SDK."
   - §8, under the screen table, add: "S14.02 lấy số ảnh của gói từ bảng giá đã tải ở S14.01 (bản sao lời mời không có số ảnh). S14.03 liên hệ khách qua `ContactSubject.instant` (`getContactLink({instantRequestId, channel})`); máy chủ cần mở khoá khi yêu cầu ở `assigned`…`in_progress` và 30 ngày sau `completed`, trả số của bên kia; trước khi có, chỉ kênh Nhắn tin hoạt động. Nút Nhắn tin mở `/chat/{requestId}` (phòng chat do I3 tạo khi `assigned`)."
   - §9, under the table, add: "Tên độ chính xác: '~100 m' là `LocationAccuracy.medium` của geolocator (Android balanced, iOS hundred meters). Sẵn sàng: luồng lọc 300 m + nhịp 5 phút gửi lại điểm cũ (không lấy điểm mới). Bấm 'Tắt' trên thông báo khi đang đến: tắt sẵn sàng sau chuyến, vẫn chia sẻ vị trí tới khi 'Đã đến'. Mở app được tính là trả lời 'Vẫn muốn nhận việc?'."
   - §13, add open question 7: "Android 14+: quyền `USE_FULL_SCREEN_INTENT` chỉ tự cấp cho app gọi điện/báo thức; app này xin người dùng bật ở Cài đặt (S14.01 khi bật Sẵn sàng), nếu không thì lời mời là thông báo nổi ưu tiên cao. Cần kiểm chính sách Google Play trước khi phát hành."
2. `components/shared-components.md`: add under section 4 (after ApertureLoader) entries "### TickingBuilder · Mới" ("Dựng lại mỗi giây khi `active`; dừng hẳn khi tắt hoặc rời cây. `Timer.periodic` duy nhất được phép trong UI. Dùng S13.03, S13.05, S13.06, S14.02."), "### CountdownRing · Mới" ("`CountdownRing({remaining, total, unit, semanticsLabel, size})`: số giây làm tròn lên + vòng; không chỉ bằng màu; một nhãn đọc. S13.06, S14.02."), "### AppMap · Mới" ("`AppMap({center, semanticsLabel, zoom, markers, fitMarkers, cameraToken, onCameraIdle, centerPinLabel, onMyLocation})` trên `AppMapScope` (MapLibre + Goong ở app, bản giả trong test). Mọi ghim có nhãn chữ; nút 'Về vị trí của tôi' 48dp; ghim trượt 0,9 s, tắt khi giảm chuyển động. Chỉ S13.01, S13.05, S14.03."); in "### AppButton · Đã có" append "Biến thể `AppButton.danger` (đỏ, đặc) chỉ dùng cho xác nhận huỷ/từ chối trong sheet."; change "### ApertureLoader · Mới" to "### ApertureLoader · Mới (kế hoạch I4 Task 8)".
3. `docs/testing/battery-and-performance.md`:
   - In "Quy tắc khi viết code", change the first bullet's "không `Timer.periodic`" to "không `Timer.periodic` (trừ `TickingBuilder` khi đồng hồ đang hiện trên màn)", and the last bullet to "Không dịch vụ nền, không wakelock (ngoại lệ duy nhất: Chụp ngay, mục dưới)."
   - Append:

   ```markdown
   ## Ngoại lệ có chủ đích: Chụp ngay

   Theo spec `2026-10-01-instant-booking-design.md` §9; chỉ cho nhiếp ảnh gia đang bật "Live Shutter" hoặc đang đến điểm hẹn.

   | Trạng thái | Vị trí | Chạy nền | Mạng |
   |---|---|---|---|
   | Sẵn sàng, không có việc | luồng ~100 m, chỉ báo khi đi > 300 m | Android: foreground service loại `location`, thông báo "Đang nhận việc chụp ngay" có nút "Tắt"; iOS: `allowsBackgroundLocationUpdates`, chấm xanh | `PUT /v1/presence` khi đi > 300 m hoặc 5 phút một lần (gửi lại điểm cũ) |
   | Đang đến | luồng độ chính xác cao | như trên | `POST …/location` 10–15 giây một lần |
   | Đã đến, đang chụp, tắt sẵn sàng | tắt | tắt | không |

   - Không `ACCESS_BACKGROUND_LOCATION`, không "Luôn luôn" trên iOS (`UIBackgroundModes` chỉ có `location`), không wakelock.
   - Bản đồ (MapLibre) chỉ dựng ở S13.01, S13.05, S14.03; ghim di chuyển nội suy, không vẽ lại cả bản đồ.

   ### Đo tay Chụp ngay (máy thật, bản profile, Android và iOS)

   | Kịch bản | Cách làm | Ngưỡng |
   |---|---|---|
   | A. Sẵn sàng 1 giờ không có việc | Sạc đầy, rút sạc; Android: `adb shell dumpsys battery unplug` và `adb shell dumpsys batterystats --reset`; iOS: Instruments mẫu Energy Log. Bật Sẵn sàng ở S14.01, khoá màn, để yên 60 phút. | **≤ 3 % pin**; Android `batterystats`: không Wake lock của app, GPS chỉ bật khi di chuyển; iOS Energy Impact "Low" phần lớn thời gian |
   | B. Đang đến 30 phút | Dịch vụ chạy local (I3); tạo yêu cầu từ máy khách, nhận ở máy nhiếp ảnh gia, di chuyển 30 phút rồi "Đã đến". | **≤ 6 % pin**; log dịch vụ có 120–180 lần `POST …/location` |
   | C. GPS tắt | Bật Sẵn sàng rồi tắt; và đang đến rồi "Đã đến". | **GPS tắt trong 10 giây**: Android biểu tượng vị trí mất, `adb shell dumpsys location \| grep -A3 photobooking` không còn yêu cầu; iOS chấm xanh/mũi tên mất |

   Ghi kết quả vào bảng mẫu với các dòng "Chụp ngay A/B/C", cột GPS ghi số giây GPS bật.
   ```
4. Run `git diff --stat ../docs` and read each hunk once.

- [ ] **Step 2: Commit**

```bash
git add ../docs/superpowers/specs ../docs/testing/battery-and-performance.md
git commit -m "docs(instant): FCM payload, device tokens, contact subject and the Chụp ngay battery exception

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: Battery and performance check

**Files:**
- Create: `test/battery/instant_photographer_battery_test.dart`
- Reference: `test/support/idle.dart` (`expectIdle`), `test/support/blur.dart` (`expectBlurBudget`), `docs/testing/battery-and-performance.md` (with the iOS section of the iOS enablement plan and the Chụp ngay section of Task 15)

**Interfaces:**
- Consumes: `InstantWorld`, `instantScreenApp`, `FakeMapEngine`, `TickingBuilder.debugActiveCount`, the session and job controllers.
- Produces: the battery gate of this plan (no new production API).

What is checked: screens at rest schedule no frames (S14.01 off and on, S14.03 en route, S13.08 open); the only ticking clock is S14.02's and only while the offer is live; idle presence takes at most one GPS fix per 5 minutes when not moving (in fact one in total) and refreshes presence every 5 minutes; en route posts every 10–15 s; zero location streams and zero posts after "Đã đến" or going offline; the foreground service runs only while needed; every Firestore listener closes with its owner; the map exists only on S14.03 in this plan; at most four blurs per screen, none nested; `Timer.periodic` appears only in `TickingBuilder` and the presence heartbeat.

- [ ] **Step 1: Write the tests**

```dart
// test/battery/instant_photographer_battery_test.dart
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant_work/instant_job_controller.dart';
import 'package:photobooking/features/instant_work/instant_session_controller.dart';

import '../support/blur.dart';
import '../support/idle.dart';
import '../support/instant_screens.dart';
import '../support/instant_world.dart';

void main() {
  late InstantWorld w;

  setUp(() async {
    w = InstantWorld();
    await w.init();
    w.presence.settingsValue = eligibleSettings;
  });

  group('screens at rest', () {
    testWidgets('S14.01 off and on: no frames, one blur, no map', (tester) async {
      await tester.pumpWidget(instantScreenApp(w, location: '/work/instant'));
      await expectIdle(tester);
      expectBlurBudget();
      await tester.tap(find.byKey(const Key('instant-online')));
      await expectIdle(tester);
      expect(TickingBuilder.debugActiveCount, 0);
      expect(w.map.builds, 0);
    });

    testWidgets('S14.02: exactly one ticking clock while live, none after expiry or leaving', (tester) async {
      w.mirror.setOffer(w.uid, w.offer());
      await tester.pumpWidget(instantScreenApp(w, location: '/work/instant/offer/O1'));
      await tester.pump();
      expect(TickingBuilder.debugActiveCount, 1);
      expect(tester.binding.transientCallbackCount, 0, reason: 'the ring is stepped once a second, not animated');
      expect(w.map.builds, 0);
      for (var i = 0; i < 31; i++) {
        w.now = w.now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      await expectIdle(tester);
      expect(TickingBuilder.debugActiveCount, 0);
    });

    testWidgets('S14.03 en route: the map is built here, at rest no frames; S13.08 open stays idle with one blur', (tester) async {
      w.mirror.setRequest('R1', w.view(InstantStatus.enRoute));
      await tester.pumpWidget(instantScreenApp(w, location: '/work/instant/R1'));
      await tester.pump();
      w.location.moveRoute(w.fixAt(600));
      await expectIdle(tester);
      expect(w.map.builds, greaterThan(0));
      expectBlurBudget();
      await tester.tap(find.byKey(const Key('job-cancel')));
      await expectIdle(tester);
      expectBlurBudget(max: 1);
    });

    testWidgets('S14.03 resuming under reduced motion: the aperture wait is still', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(instantScreenApp(w, location: '/work/instant/R9'));
      await expectIdle(tester);
      expect(find.byType(ApertureLoader), findsOneWidget);
    });
  });

  group('location and network, counted with fakes', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    ProviderContainer container() {
      final c = ProviderContainer(overrides: w.overrides);
      addTearDown(c.dispose);
      return c;
    }

    test('available for 1 hour without moving: one GPS fix in total, presence every 5 minutes', () {
      fakeAsync((async) {
        final c = container();
        c.read(instantSessionProvider.notifier).goOnline();
        async.flushMicrotasks();
        final start = w.presence.presenceCalls.length;
        w.advance(async, const Duration(hours: 1));
        expect(w.location.currentFixCalls, 1);
        expect(w.location.presenceFixes, 0);
        expect(w.location.routeListeners, 0);
        expect(w.presence.presenceCalls.length - start, 12);
        expect(w.foreground.starts, 1, reason: 'one service for the whole hour');
      });
    });

    test('en route: posts every 10–15 s; after "Đã đến" no stream, no post, no service', () {
      fakeAsync((async) {
        final c = container();
        c.read(instantSessionProvider.notifier).goOnline();
        async.flushMicrotasks();
        c.read(instantJobProvider.notifier).accept('O1');
        async.flushMicrotasks();
        for (var i = 1; i <= 100; i++) {
          w.advance(async, const Duration(seconds: 3));
          w.location.moveRoute(w.fixAt(1500 - i * 14.0, accuracy: 6));
          async.flushMicrotasks();
        }
        final at = w.jobs.postedAt;
        for (var i = 1; i < at.length; i++) {
          final gap = at[i].difference(at[i - 1]).inSeconds;
          expect(gap, inInclusiveRange(10, 15));
        }
        c.read(instantJobProvider.notifier).arrive();
        async.flushMicrotasks();
        final posts = w.jobs.posted.length;
        w.advance(async, const Duration(minutes: 10));
        expect(w.location.activeStreams, 0);
        expect(w.jobs.posted.length, posts);
        expect(w.foreground.running, isFalse);
      });
    });

    test('offline: zero streams, zero listeners, no heartbeat, service stopped', () {
      fakeAsync((async) {
        final c = container();
        final s = c.read(instantSessionProvider.notifier);
        s.goOnline();
        async.flushMicrotasks();
        s.goOffline();
        async.flushMicrotasks();
        final calls = w.presence.presenceCalls.length;
        w.advance(async, const Duration(minutes: 30));
        expect((w.location.activeStreams, w.mirror.openListeners, w.foreground.running), (0, 0, false));
        expect(w.presence.presenceCalls.length, calls);
      });
    });

    test('a finished job closes its mirror listener', () {
      fakeAsync((async) {
        final c = container();
        c.read(instantSessionProvider.notifier).goOnline();
        async.flushMicrotasks();
        final job = c.read(instantJobProvider.notifier);
        job.accept('O1');
        async.flushMicrotasks();
        expect(w.mirror.listenersOf('instant_requests/R1'), 1);
        w.location.moveRoute(w.fixAt(20));
        async.flushMicrotasks();
        job.arrive();
        async.flushMicrotasks();
        job.start();
        async.flushMicrotasks();
        job.finish();
        async.flushMicrotasks();
        expect(w.mirror.listenersOf('instant_requests/R1'), 0);
      });
    });
  });

  testWidgets('S14.02\'s offer listener closes when the screen does (session offline)', (tester) async {
    w.mirror.setOffer(w.uid, w.offer());
    await tester.pumpWidget(instantScreenApp(w, location: '/work/instant/offer/O1'));
    await tester.pump();
    expect(w.mirror.listenersOf('instant_offers/${w.uid}'), 1);
    await tester.tap(find.byKey(const Key('offer-decline')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('decline-confirm')));
    await tester.pumpAndSettle();
    expect(w.mirror.listenersOf('instant_offers/${w.uid}'), 0);
  });

  test('Timer.periodic only in TickingBuilder and the presence heartbeat', () {
    final offenders = <String>[];
    for (final dir in ['lib/features/instant_work', 'lib/features/instant_common', 'lib/data/instant']) {
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        if (f.readAsStringSync().contains('Timer.periodic')) {
          offenders.add(f.path);
        }
      }
    }
    expect(offenders.toSet(), {'lib/features/instant_work/instant_session_controller.dart'});
    for (final f in ['lib/core/widgets/countdown_ring.dart', 'lib/core/widgets/app_map.dart', 'lib/core/widgets/aperture_loader.dart']) {
      expect(File(f).readAsStringSync(), isNot(contains('Timer.periodic')), reason: f);
    }
  });
}
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/battery/instant_photographer_battery_test.dart`
Expected: PASS (10 tests). These encode properties the earlier tasks were built to have. A failure names the culprit: an idle failure means a ticker or timer runs at rest (find it with `debugPrintScheduleFrameStacks = true;` and remove the cause, never loosen the test); a location count failure means a stream was not cancelled or a fix is taken where the last one should be reused.

- [ ] **Step 3: Fix anything the run found**

Only code changes that remove the cause. Re-run Step 2, then the whole suite: `flutter analyze && flutter test`.

- [ ] **Step 4: Manual profiling on real devices (Android and iOS)**

Follow `docs/testing/battery-and-performance.md`: the general steps for S14.01, S14.02, S14.03 and the S13.08 sheet (frames at rest, CPU at rest, memory), then the three Chụp ngay scenarios of Task 15 with their thresholds (spec §9): **A** available 1 hour ≤ 3 % battery; **B** en route 30 minutes ≤ 6 %; **C** GPS off within 10 s after "Đã đến" and after switching availability off. Build with `flutter run --profile --dart-define=DISPATCH_URL=http://<host>:8090 --dart-define=GOONG_MAPTILES_KEY=<key>` against the local dispatch service of plan I3 (fake payments) and a second phone (or the customer flow of plan I5) to create requests.

Also check by hand, once per platform:
- Android 14: Settings → Apps → the app → "Full screen notifications" (allow, then deny) — with the screen locked an offer opens S14.02 over the lock screen when allowed, and is a heads-up notification with sound when denied; the persistent notification "Đang nhận việc chụp ngay" shows "Tắt", and "Tắt" switches availability off.
- iOS: the blue location indicator shows only while available or en route; an offer with the app in the background arrives as a time-sensitive notification and opens S14.02. **[người dùng]** steps before the iOS run: upload the APNs key in Firebase console → Cloud Messaging; enable Push Notifications and Time Sensitive Notifications for the App ID; restrict the Goong keys to `com.thanhbk.photobooking` in the Goong console.

Record the filled-in result table (Android and iOS rows, plus "Chụp ngay A/B/C") in the PR description. Any value over a threshold blocks the merge: fix it in this plan's code, add a test that would have caught it, and re-measure. Until the iOS enablement plan's device tasks are done, write "iOS: not measured, blocked by iOS enablement" in the iOS rows.

- [ ] **Step 5: Commit**

```bash
dart format test
git add test/battery/instant_photographer_battery_test.dart
git commit -m "test(instant): battery gate for availability, offers and en-route tracking

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** §2.2 S14.01 conditions (profile, phone, current price list, open city, location permission → `reasons` with fixes; Task 12), "Sẵn sàng hỗ trợ" (Tasks 9, 12), price list with customer price and payout and the accepted version saved (`PUT /v1/instant-settings`; Tasks 2, 9, 12); S14.02 full screen even in the background (Android full-screen intent and heads-up, iOS time-sensitive; FCM data and mirror listener; Tasks 6, 9, 13), package, genre, distance, travel time, payout, area only, note, 30 s countdown in number and ring, "Nhận" ≥ 56dp, "Từ chối" with optional reason (Task 13); S14.03 exact address after accepting, "Chỉ đường" to an external maps app, "Đã đến" ≤ 200 m or confirmed with a reason when GPS is poor, "Bắt đầu chụp", "Hoàn thành", chat and contact (Tasks 4, 10, 14); one job at a time, availability restored afterwards (Tasks 9, 10); §3 statuses and the mirror (Tasks 1, 3); §6 every photographer call (`/presence`, `/instant-settings`, `/offers/{id}/accept|decline`, `/requests/{id}/location|arrive|start|finish|cancel`) and the new error codes (Tasks 1, 2), checked against `openapi.yaml` (Task 1); §7 mirror read-only rules (Task 3); §8 S13.08, S14 with screen codes, red cancel in a sheet, amounts in words, map pins with text labels, "Về vị trí của tôi" (Tasks 7, 11–14); §9 location table, Android foreground service with "Tắt", no background permission, iOS background location indicator and `UIBackgroundModes` location, auto-off 30 + 5 minutes, battery < 15 %, map only on S14.03 (S13.01/S13.05 in I5), privacy (Tasks 4–9, 14–16); §10 `already_assigned`, `offer_expired`, FCM late (mirror), GPS loss handled by the customer side (I5), arrive > 200 m refused (Tasks 10, 13, 14); §11 widget tests at 320dp/1.3×/light/dark, `expectIdle`, S14.02 countdown to the second, rules tests (all tasks, Task 16).
- **Deviations (flagged, not hidden):** (1) phase 2's `ApiClient.get`/`uriFor` gain an optional `query` (needed for `GET /v1/packages?lat&lng`; backwards compatible). (2) The FCM data keys and the `devices/{uid}_{installId}` token collection are not in the contract; this plan defines them and Task 15 writes them into spec §5 for I3. (3) `ContactSubject.instant` needs server support in `getContactLink` / `POST /v1/contact-links`; until then only "Nhắn tin" works on S14.03, and the photographer can only offer "Gọi" (the customer's Zalo/WhatsApp flags are private). (4) S14.02 takes the photo count from the price list loaded on S14.01 (the offer mirror has none) and falls back to "Bạn nhận · Chân dung 1 giờ". (5) After a restart S14.03 shows "Khách" instead of the customer's name (not in the mirror). (6) "Nhắn tin" links to `/chat/{requestId}` by path; no chat plan exists yet. (7) The `instant_*` rules are written here; if plan I3 already ships them, keep one copy. (8) `ACCESS_FINE_LOCATION` is now declared for the whole app, so Android 12+ shows the precise/approximate choice in Explore too; 3a1's tests and the iOS reason text are relaxed accordingly. (9) Opening the app counts as answering "Vẫn muốn nhận việc?"; "Tắt" in the notification during a trip turns availability off for after the trip but keeps sharing until "Đã đến". (10) `ApertureLoader` (spec'd for S13.03) is built here (Task 8) because S14.02/S14.03 need it first; plan I5 consumes it. (11) The Google Maps fallback of spec §1 is not built; if Goong fails, the map shows the placeholder and the rest of S14.03 works.
- **Placeholders:** none (Task 12 creates two temporary screen stubs that Tasks 13 and 14 replace in this plan).
- **Type consistency:** `LatLng`, `LocationFix`, `MeetPoint`, `InstantOffer`, `InstantRequestView`, `InstantTrack`, `CancelQuote`, `DispatchError`/`DispatchException`, `PresenceRepository`, `InstantJobRepository`, `InstantMirror`, `TrackingLocationSource`, `ForegroundSession`, `InstantNotifier`/`InstantTap`, `PushMessages`/`InstantPush`, `DeviceRegistry`, `InstantSessionController`/`instantSessionProvider`, `InstantJobController`/`instantJobProvider`, `instantRequestProvider`, `instantTrackProvider`, `instantOfferProvider`, `AppMap`/`MapMarker`/`AppMapScope`, `TickingBuilder`, `CountdownRing`, `ApertureLoader`, `AppButton.danger`, `showInstantCancelSheet`/`InstantCancelRole`, `InstantMilestones`/`Milestone`, `instantErrorText`, `InstantWorld`, `instantScreenApp`, `FakeMapEngine` and every widget key are spelled the same in tests and code; plan I5 uses them by these names.
- **Risks:** Android 14 restricts full-screen intents to calling/alarm apps (the user must allow it; otherwise a heads-up notification) and Google Play policy must be checked (spec §13 Q7); iOS background offers depend on I3 sending an APNs alert with `time-sensitive` and on the entitlement; `flutter_foreground_task` and `maplibre_gl` APIs change between majors (Step 1 of Tasks 5 and 7 pins and checks them; only the adapter files would change); geolocator streams in the background on Android rely on the foreground service started by another plugin, verified only on a device (Task 16 scenario A); MapLibre's platform view on low-end Android is the main frame-time risk on S14.03; golden images differ between macOS and Linux (Task 8 Step 4); several tests read platform files as text (manifest, plist, adapters), which is brittle by design.
- **Battery and performance:** Task 16 adds idle tests for S14.01/S14.02/S14.03/S13.08, one ticking clock only while an offer is live, fake-counted GPS fixes, streams, posts and listeners for available, en-route, arrived and offline, the map only on S14.03, the blur budget, a `Timer.periodic` audit, and the manual scenarios A/B/C with the spec §9 thresholds on Android and iOS.

