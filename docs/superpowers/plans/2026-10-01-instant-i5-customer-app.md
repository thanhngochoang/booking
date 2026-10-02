# Instant I5: "Chụp ngay" Customer App (S47–S51, S55) Implementation Plan

> **Battery/performance (2026-10-02, user):** this plan has no battery, idle, blur-budget or performance task or test steps. All of that runs once at the end in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Skip any such step inside a task (e.g. `expectIdle`, `expectBlurBudget`, listener counters, profiling); keep the functional tests.

> **Rules emulator tests (2026-10-02, user):** do not run the Firestore/Storage rules tests on the emulator (`app_flutter/firebase/rules-test`, `npm test`, `npm run test:*`) while executing this plan; the sandbox cannot run them. Still write or update the rules and their test files as the task says, but skip every step that runs them and every `Expected:` that depends on them; CI (`flutter.yml`, `firebase-deploy.yml`) runs them on push and blocks deploy on failure. Record the skip in the ledger.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A customer taps "Chụp ngay" on Home or Find, picks a package and a kind of shoot, pins the meet point on a Goong map (current location, drag, or address search), pays the fixed price, watches the search (S48), follows the photographer on the map with an ETA and contact unlocked (S49), sees the shoot timer and confirms completion (S50), gets an automatic refund when nobody accepts and can retry or book normally (S51), and can cancel at any step after seeing the refund from a dry run (S55).

**Architecture:** One `InstantBookingRepository` port (HTTP adapter over phase 2's `ApiClient` pointed at `DISPATCH_URL`, plus a fake) for packages, request creation, cancel and confirm; realtime state comes only from the read-only Firestore mirror of plan I4 (`instantRequestProvider`, `instantTrackProvider`). A keep-alive `InstantDraft` holds the customer's choices across the S33 phone detour and the S51 retry. `InstantBookController` (S47) takes one medium-accuracy fix, reverse-geocodes with Goong, quotes, creates the request and hands the `paymentUrl` to a `PaymentLauncher` port (debug: `fake://` handled in-app by calling the dev endpoint; real gateways are plan I6). A single route `/instant/:id` shows S48, S49, S50 or S51 from the mirror status, each in its own `ScreenCode`. Address search uses a `PlaceSearch` port with a Goong Autocomplete adapter whose errors never carry the key. A two-party integration test runs customer and photographer containers against one in-memory dispatch fake.

**Tech Stack:** Flutter, Riverpod 3, go_router, `http` (Goong; dispatch via `ApiClient`), `maplibre_gl` through plan I4's `AppMap`, `flutter_test`, `fake_async`, `http/testing.dart` `MockClient`.

**Spec:** `docs/superpowers/specs/2026-10-01-instant-booking-design.md` (§2.1, §3, §4, §5, §6, §8, §9, §10, §11); contract `services/dispatch/api/openapi.yaml` (customer paths `GET /v1/health`, `GET /v1/packages`, `POST /v1/requests`, `POST /v1/requests/{id}/cancel`, `POST /v1/requests/{id}/confirm-complete`, `POST /v1/dev/payments/{id}/succeed`; `InstantRequestMirror`, `InstantTrackMirror`; error codes `phone_required`, `outside_service_area`, `price_changed`); mock `docs/design/ui-mock.html` screens `data-code="S47"` … `"S51"`, `"S55"`; `docs/superpowers/specs/screens/README.md`; `docs/superpowers/specs/components/shared-components.md` (ApertureLoader, ContactDial, AppBottomSheet).

**Prerequisite (all done first; exact APIs used are listed per task under "Consumes"):**

- `docs/superpowers/plans/2026-10-01-instant-i4-photographer-app.md` (all tasks): `instant_models.dart` / `instant_wire.dart` (`LatLng`, `MeetPoint`, `PackagesQuote`, `InstantPackage`, `CreatedRequest`, `CancelQuote`, `InstantRequestView`, `InstantTrack`, `InstantStatus`, `InstantGenre`, `InstantPackageCode`, `PaymentProvider`, `DispatchError`, `DispatchException`, `DispatchPaths`, `dispatchGuard`, `createRequestBody`, `cancelBody`, `packagesQuoteFromJson`, `createdRequestFromJson`, `cancelQuoteFromJson`), `fakePackagesQuote`, `DisabledDispatch`, `dispatchApiClientProvider`, `FakeInstantMirror`, `instantMirrorProvider`, `instantRequestProvider`, `instantTrackProvider`, `TrackingLocationSource`/`FakeTrackingLocationSource`/`FixAccuracy`, `trackingLocationProvider`, `InstantNotifier`/`FakeInstantNotifier`/`LocalInstantNotifier`/`InstantTap`, `InstantPush`/`PushMessages`/`FakePushMessages`, `instantNotifierProvider`, `pushMessagesProvider`, `fcm_background.dart`, `wireInstantNavigation`, `genreLabel`, `packageLabel`, `AppMap`/`MapMarker`/`AppMapScope`, `GoongConfig`, `TickingBuilder`, `CountdownRing`, `ApertureLoader`, `AppButton.danger`, `showInstantCancelSheet`/`InstantCancelRole`, `InstantMilestones`/`Milestone`, `instantErrorText`, `ContactSubject.instant`, `InstantWorld`, `FakeMapEngine`, the photographer screens and the l10n keys of I4.
- `docs/superpowers/plans/2026-10-01-screen-codes.md`: `ScreenCodes.instantRequest` (S47), `.instantSearching` (S48), `.instantTracking` (S49), `.instantInProgress` (S50), `.instantNoMatch` (S51), `.instantCancel` (S55); `expectIdle`; `docs/testing/battery-and-performance.md`.
- `docs/superpowers/plans/2026-10-01-core-display-widgets.md`: `hostWidget`, `VerifiedName(String name, {TextStyle? style})`.
- `docs/superpowers/plans/2026-10-01-step2a-phone-and-customer-contact.md`: `currentContactProvider` (`StreamProvider.autoDispose<UserContact?>`), route `/profile/phone?returnTo=…` (S33 goes to `returnTo` with `context.go` after saving), `FakeUserContactRepository`.
- `docs/superpowers/plans/2026-10-01-step2b-contact-dial-and-channels.md`: `PhotographerContactAction({required String photographerId, required ContactAccess access, required String source, ContactSubject? subject, ContactDialStyle style, VoidCallback? onInquiry})`, `ContactDialStyle.labeled`, `photographerContactRepositoryProvider`, `FakePhotographerContactRepository.seed(uid, {channels, numbers, area})`, `ContactChannels`.
- `docs/superpowers/plans/2026-10-01-step3a1-location-foundations.md`: `AppChip`, `showAppSheet`, `formatDistance`, `toVn`, `LocationRepository`/`FakeLocationRepository`/`LocationPermissionStatus`, `test/support/blur.dart`.
- `docs/superpowers/plans/2026-10-01-step3a2-explore-screens.md`: `formatMoney`, `clockProvider`, `locationRepositoryProvider`, `ErrorState`, `AppSkeleton`, `screenApp`/`screenRouterApp`.
- `docs/superpowers/plans/2026-10-01-step3b2-feed-cards.md`: `AppAvatar({String? url, required String name, AppAvatarSize size})`.
- `docs/superpowers/plans/2026-10-01-step3b4-home-detail-find.md`: `HomeScreen` (`lib/features/home/home_screen.dart`), `FindPhotographerScreen` (`lib/features/find/find_screen.dart`), `test/support/discovery_world.dart` (`DiscoveryWorld`), route `/action` (S04).
- `docs/superpowers/plans/2026-10-01-backend-phase2-selfhosted-postgres.md` Task 8: `ApiClient`, `MockApi`, `apiError`, `StaticIdTokenSource`; the `http` package.
- Plan I3 (dispatch service with `PAYMENTS=fake`) only for the manual end-to-end run (Task 15). Plan I6 implements a real `PaymentLauncher` (MoMo/VNPay) behind the port defined in Task 2; S12 "Đánh giá" for an instant request (`/instant/:id/review`) belongs to the review plan and is linked by path.

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Run `dart format lib test` before each commit (`flutter analyze` fails on infos).
- Imports are `package:photobooking/...` only; features import `package:photobooking/core/core.dart`, never files inside `core/`; files inside `core/` import each other directly.
- **Firebase isolation:** no `cloud_firestore` / `firebase_*` import in this plan's features or core; the mirror is read through I4's `InstantMirror` port; `package:http` appears only in `lib/data/instant/goong_place_search.dart` (dispatch calls go through `ApiClient`).
- **Data conventions** (`data-model/README.md`): ids opaque strings, instants UTC, money integer VND, enum string codes, no Firebase type outside adapters. Request bodies are built only by I4's `instant_wire.dart` (checked against `openapi.yaml`).
- **UI strings** only in `lib/l10n/app_vi.arb` (Vietnamese with full diacritics), then `flutter gen-l10n`; keys camelCase with the `instant…` prefix (I4's convention). Free events are not involved here; prices use `formatMoney` (`690.000₫`; short `690K` only on the package tiles).
- **Theme:** `AppColors`/`AppColorsDark`/`AppSpace`/`AppRadius`; no raw hex in features.
- **One primary action per screen** (`AppButton.primary`): S47 "Thanh toán {giá} và tìm", S48 none (the red text "Huỷ yêu cầu"), S49 none, S50 "Xác nhận hoàn thành" (then "Đánh giá"), S51 "Thử lại". Cancel is a red text button that opens S55; the confirmation inside the sheet is the red `AppButton.danger`, never the gradient, and the refund is shown in words first.
- **Money and contact rules (product decisions, do not weaken):** the customer pays in full before the search and the money is held in escrow until completion (shown on S47); phone/Zalo/WhatsApp open only after payment (S49 shows `PhotographerContactAction` with `ContactAccess.unlocked` only once the request is `assigned`); a customer needs a phone number to request (S33 first, `phone_required` handled); phone numbers never go into `users/{uid}` or any `instant_*` document; the exact meet point is sent only by the customer's explicit choice.
- **Location and battery:** the customer's location is read **once** per S47 visit (medium accuracy, with a deadline) and reused through the draft; no stream on the customer side; the map exists only on S47 and S49 (S54 in I4); the pulse and the aperture wait run only while searching / waiting and are still under reduced motion; `TickingBuilder` is the only per-second clock and runs only while it is on screen; every mirror listener is `autoDispose` and closes with its screen.
- **Goong keys** come from `--dart-define=GOONG_API_KEY=…` / `GOONG_MAPTILES_KEY=…` (I4's `GoongConfig`), are restricted to the app's package name / bundle id in the Goong console, and never reach a log, an exception text or analytics.
- Interactive controls have a 48dp touch target; meaning never rests on colour alone; every map pin has a text label; widget tests run at 390dp and at 320dp with text scale 1.3, dark and light.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/data/instant/instant_booking_repository.dart` (create) | `InstantBookingRepository` port, `DisabledInstantBooking`, `FakeInstantBookingRepository` |
| `lib/data/instant/http_instant_booking_repository.dart` (create) | HTTP adapter |
| `lib/data/instant/payment_launcher.dart` (create) | `PaymentLauncher` port, `DevFakePaymentLauncher`, `UnavailablePaymentLauncher`, `FakePaymentLauncher` |
| `lib/data/instant/place_search.dart` (create) | `PlaceSearch` port, `PlaceSuggestion`, `PlaceSearchException`, `FakePlaceSearch` |
| `lib/data/instant/goong_place_search.dart` (create) | Goong Autocomplete / Place Detail / Geocode adapter |
| `lib/data/instant/instant_providers.dart` (modify, I4) | `instantBookingRepositoryProvider`, `paymentLauncherProvider`, `placeSearchProvider`, `instantAvailableProvider` |
| `lib/core/widgets/search_pulse.dart` (create) | `SearchPulse` (rings around `ApertureLoader`) |
| `lib/features/instant/instant_draft.dart` (create) | `InstantDraft`, `instantDraftProvider` |
| `lib/features/instant/instant_customer_rules.dart` (create) | grace, stale track, late cancel, elapsed, defaults |
| `lib/features/instant/instant_book_controller.dart` (create) | S47 controller, `InstantSubmitResult` |
| `lib/features/instant/meet_point_search_sheet.dart` (create) | address search sheet and its controller |
| `lib/features/instant/instant_book_screen.dart` (create) | S47 |
| `lib/features/instant/customer_only.dart` (create) | role guard |
| `lib/features/instant/instant_customer_actions.dart` (create) | cancel quote / cancel / confirm |
| `lib/features/instant/instant_request_screen.dart` (create) | `/instant/:id` status switch |
| `lib/features/instant/views/instant_searching_view.dart`, `instant_tracking_view.dart`, `instant_shoot_view.dart`, `instant_no_match_view.dart`, `instant_closed_view.dart` (create) | S48 (+ payment states), S49, S50 (+ completed), S51, closed states |
| `lib/features/instant/instant_entry.dart` (create) | `InstantHomeCard` (S01), `InstantFindButton` (S04) |
| `lib/features/home/home_screen.dart`, `lib/features/find/find_screen.dart` (modify, 3b4) | entry points |
| `lib/data/instant/instant_push.dart`, `instant_notifier.dart`, `local_instant_notifier.dart`, `fcm_background.dart` (modify, I4) | customer pushes and notifications |
| `lib/features/instant_work/instant_navigation.dart` (modify, I4) | open `/instant/:id` from customer notifications |
| `lib/app/router.dart` (modify) | `/instant`, `/instant/:id`, `/instant/:id/cancel` |
| `lib/l10n/app_vi.arb` (modify) | strings listed per task |
| `docs/superpowers/specs/2026-10-01-instant-booking-design.md`, `components/shared-components.md`, `docs/testing/battery-and-performance.md` (modify) | align docs |
| `test/support/instant_customer_world.dart`, `test/support/instant_customer_screens.dart`, `test/support/fake_dispatch_server.dart` (create) | customer fakes, router harness, two-party fake service |
| tests | listed per task; `test/integration/instant_two_party_test.dart`, `test/battery/instant_customer_battery_test.dart` |

---

### Task 1: `InstantBookingRepository` (packages, create, cancel, confirm, health)

**Files:**
- Create: `lib/data/instant/instant_booking_repository.dart`, `lib/data/instant/http_instant_booking_repository.dart`, `test/data/instant/instant_booking_repository_test.dart`
- Modify: `lib/data/instant/instant_providers.dart`

**Interfaces:**
- Consumes: I4 Task 1 (`dispatchGuard`, `DispatchPaths`, `createRequestBody`, `cancelBody`, mappers), I4 Task 2 (`dispatchApiClientProvider`, `fakePackagesQuote`), `MockApi`, `apiError`.
- Produces:
  - `abstract class InstantBookingRepository { Future<bool> healthy(); Future<PackagesQuote> packages({LatLng? near, String? cityId}); Future<CreatedRequest> create({required String packageId, required InstantGenre genre, required MeetPoint meetPoint, required String note, required bool expand, required int expectedAmountVnd, required PaymentProvider provider}); Future<CancelQuote> cancel(String requestId, {required bool dryRun, String? reason}); Future<void> confirmComplete(String requestId); }`.
  - `HttpInstantBookingRepository({required ApiClient api})`; `DisabledInstantBooking` (`healthy()` false, other calls throw `DispatchError.disabled`).
  - `FakeInstantBookingRepository({PackagesQuote? quote})` with `quote`, `healthyValue`, `packagesCalls`, `created` (`List<Map<String, Object?>>`, the exact request bodies), `nextRequestId`, `createError`, `cancelQuote`, `cancelCalls` (`'quote RQ1'` / `'cancel RQ1'`), `cancelError`, `confirmCalls`.
  - `instantBookingRepositoryProvider` (`Provider<InstantBookingRepository>`).

- [ ] **Step 1: Write the failing test**

```dart
// test/data/instant/instant_booking_repository_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/fake_instant_repositories.dart';
import 'package:photobooking/data/instant/http_instant_booking_repository.dart';
import 'package:photobooking/data/instant/instant_booking_repository.dart';
import 'package:photobooking/data/instant/instant_models.dart';

import '../http/mock_api.dart';

const _meet = MeetPoint(lat: 10.7745, lng: 106.6926, address: 'Công viên Tao Đàn');

const _packagesJson = {
  'cityId': 'hcm',
  'cityName': 'TP. Hồ Chí Minh',
  'priceListVersion': 3,
  'surge': 1.0,
  'typicalMatchMinutes': 4,
  'packages': [
    {'id': 'PK60', 'code': 'p60', 'durationMin': 60, 'photos': 30, 'priceVnd': 690000, 'payoutVnd': 552000},
  ],
};

Future<CreatedRequest> _create(InstantBookingRepository repo) => repo.create(
  packageId: 'PK60',
  genre: InstantGenre.couple,
  meetPoint: _meet,
  note: 'Áo dài trắng',
  expand: true,
  expectedAmountVnd: 690000,
  provider: PaymentProvider.fake,
);

void main() {
  group('HttpInstantBookingRepository', () {
    test('health reads ok', () async {
      final api = MockApi({'GET /v1/health': (_) => (200, {'ok': true, 'redis': true, 'postgres': true})});
      expect(await HttpInstantBookingRepository(api: api.api()).healthy(), isTrue);
    });

    test('packages near a point sends lat/lng; by city sends cityId', () async {
      final queries = <Map<String, String>>[];
      final api = MockApi({
        'GET /v1/packages': (r) {
          queries.add(r.url.queryParameters);
          return (200, _packagesJson);
        },
      });
      final repo = HttpInstantBookingRepository(api: api.api());
      final q = await repo.packages(near: const LatLng(10.77, 106.69));
      await repo.packages(cityId: 'hcm');
      expect(q.typicalMatchMinutes, 4);
      expect(queries, [
        {'lat': '10.77', 'lng': '106.69'},
        {'cityId': 'hcm'},
      ]);
    });

    test('create posts exactly the contract body and returns the payment URL', () async {
      final api = MockApi({
        'POST /v1/requests': (r) {
          expect(jsonDecode(r.body), {
            'packageId': 'PK60',
            'genre': 'couple',
            'meetPoint': {'lat': 10.7745, 'lng': 106.6926, 'address': 'Công viên Tao Đàn'},
            'note': 'Áo dài trắng',
            'expand': true,
            'expectedAmountVnd': 690000,
            'provider': 'fake',
          });
          return (201, {'requestId': 'RQ1', 'amountVnd': 690000, 'paymentUrl': 'fake://pay/RQ1'});
        },
      });
      final c = await _create(HttpInstantBookingRepository(api: api.api()));
      expect((c.requestId, c.amountVnd, c.paymentUrl.toString()), ('RQ1', 690000, 'fake://pay/RQ1'));
    });

    test('phone_required, outside_service_area and price_changed map to their codes', () async {
      for (final code in ['phone_required', 'outside_service_area', 'price_changed']) {
        final api = MockApi({'POST /v1/requests': (_) => (422, apiError(code))});
        await expectLater(
          _create(HttpInstantBookingRepository(api: api.api())),
          throwsA(isA<DispatchException>().having((e) => e.error.code, 'code', code)),
        );
      }
    });

    test('cancel dry run and confirm-complete', () async {
      final api = MockApi({
        'POST /v1/requests/RQ1/cancel': (r) {
          expect(jsonDecode(r.body), {'dryRun': true});
          return (200, {'rule': 'free_grace', 'refundVnd': 690000, 'photographerVnd': 0, 'platformVnd': 0, 'graceEndsAt': '2026-10-01T08:23:00.000Z'});
        },
        'POST /v1/requests/RQ1/confirm-complete': (_) => (204, null),
      });
      final repo = HttpInstantBookingRepository(api: api.api());
      final q = await repo.cancel('RQ1', dryRun: true);
      expect(q.graceEndsAt, DateTime.utc(2026, 10, 1, 8, 23));
      await repo.confirmComplete('RQ1');
      expect(api.calls, ['POST /v1/requests/RQ1/cancel', 'POST /v1/requests/RQ1/confirm-complete']);
    });
  });

  test('DisabledInstantBooking: unhealthy, every call refused', () async {
    const d = DisabledInstantBooking();
    expect(await d.healthy(), isFalse);
    await expectLater(d.packages(cityId: 'hcm'), throwsA(isA<DispatchException>()));
  });

  test('the fake records the exact bodies and can fail with a code', () async {
    final fake = FakeInstantBookingRepository(quote: fakePackagesQuote());
    final c = await _create(fake);
    expect(c.requestId, 'RQ1');
    expect(fake.created.single['genre'], 'couple');
    fake.createError = DispatchError.priceChanged;
    await expectLater(_create(fake), throwsA(isA<DispatchException>()));
    await fake.cancel('RQ1', dryRun: true);
    await fake.cancel('RQ1', dryRun: false);
    expect(fake.cancelCalls, ['quote RQ1', 'cancel RQ1']);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/instant/instant_booking_repository_test.dart`
Expected: FAIL to compile, the two files do not exist.

- [ ] **Step 3: Implement**

```dart
// lib/data/instant/instant_booking_repository.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/fake_instant_repositories.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_wire.dart';

/// The customer side of the dispatch service (S47–S51, S55). Status changes
/// are never written here: the app reads them from the mirror.
abstract class InstantBookingRepository {
  /// `GET /v1/health`; false hides "Chụp ngay" (spec §10).
  Future<bool> healthy();

  /// Packages and price at [near] (or in [cityId]); `outside_service_area`
  /// when no open city covers the point.
  Future<PackagesQuote> packages({LatLng? near, String? cityId});

  /// `phone_required`, `outside_service_area`, `price_changed` (spec §6).
  Future<CreatedRequest> create({
    required String packageId,
    required InstantGenre genre,
    required MeetPoint meetPoint,
    required String note,
    required bool expand,
    required int expectedAmountVnd,
    required PaymentProvider provider,
  });

  Future<CancelQuote> cancel(String requestId, {required bool dryRun, String? reason});
  Future<void> confirmComplete(String requestId);
}

class DisabledInstantBooking implements InstantBookingRepository {
  const DisabledInstantBooking();

  Never _off() => throw const DispatchException(DispatchError.disabled);

  @override
  Future<bool> healthy() async => false;
  @override
  Future<PackagesQuote> packages({LatLng? near, String? cityId}) async => _off();
  @override
  Future<CreatedRequest> create({
    required String packageId,
    required InstantGenre genre,
    required MeetPoint meetPoint,
    required String note,
    required bool expand,
    required int expectedAmountVnd,
    required PaymentProvider provider,
  }) async => _off();
  @override
  Future<CancelQuote> cancel(String requestId, {required bool dryRun, String? reason}) async => _off();
  @override
  Future<void> confirmComplete(String requestId) async => _off();
}

class FakeInstantBookingRepository implements InstantBookingRepository {
  FakeInstantBookingRepository({PackagesQuote? quote}) : quote = quote ?? fakePackagesQuote();

  PackagesQuote quote;
  bool healthyValue = true;
  int packagesCalls = 0;
  DispatchError? packagesError;
  final created = <Map<String, Object?>>[];
  String nextRequestId = 'RQ1';
  DispatchError? createError;
  CancelQuote cancelQuote = const CancelQuote(rule: CancelRule.freeSearching, refundVnd: 690000, photographerVnd: 0, platformVnd: 0);
  final cancelCalls = <String>[];
  DispatchError? cancelError;
  final confirmCalls = <String>[];

  @override
  Future<bool> healthy() async => healthyValue;

  @override
  Future<PackagesQuote> packages({LatLng? near, String? cityId}) async {
    packagesCalls++;
    final e = packagesError;
    if (e != null) {
      throw DispatchException(e, status: 422);
    }
    return quote;
  }

  @override
  Future<CreatedRequest> create({
    required String packageId,
    required InstantGenre genre,
    required MeetPoint meetPoint,
    required String note,
    required bool expand,
    required int expectedAmountVnd,
    required PaymentProvider provider,
  }) async {
    created.add(createRequestBody(
      packageId: packageId,
      genre: genre,
      meetPoint: meetPoint,
      note: note,
      expand: expand,
      expectedAmountVnd: expectedAmountVnd,
      provider: provider,
    ));
    final e = createError;
    if (e != null) {
      throw DispatchException(e, status: 422);
    }
    return CreatedRequest(
      requestId: nextRequestId,
      amountVnd: expectedAmountVnd,
      paymentUrl: Uri.parse('fake://pay/$nextRequestId'),
    );
  }

  @override
  Future<CancelQuote> cancel(String requestId, {required bool dryRun, String? reason}) async {
    cancelCalls.add(dryRun ? 'quote $requestId' : 'cancel $requestId');
    final e = cancelError;
    if (e != null && !dryRun) {
      throw DispatchException(e, status: 409);
    }
    return cancelQuote;
  }

  @override
  Future<void> confirmComplete(String requestId) async => confirmCalls.add(requestId);
}
```

```dart
// lib/data/instant/http_instant_booking_repository.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/instant/instant_booking_repository.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_wire.dart';

class HttpInstantBookingRepository implements InstantBookingRepository {
  HttpInstantBookingRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  @override
  Future<bool> healthy() => dispatchGuard(() async {
    final j = await _api.get(DispatchPaths.health);
    return j is Map && j['ok'] == true;
  });

  @override
  Future<PackagesQuote> packages({LatLng? near, String? cityId}) {
    if (near == null && cityId == null) {
      throw ArgumentError('packages needs a point or a city');
    }
    final query = cityId != null ? {'cityId': cityId} : {'lat': '${near!.lat}', 'lng': '${near.lng}'};
    return dispatchGuard(() async => packagesQuoteFromJson(await _api.get(DispatchPaths.packages, query: query)));
  }

  @override
  Future<CreatedRequest> create({
    required String packageId,
    required InstantGenre genre,
    required MeetPoint meetPoint,
    required String note,
    required bool expand,
    required int expectedAmountVnd,
    required PaymentProvider provider,
  }) => dispatchGuard(() async => createdRequestFromJson(
    await _api.post(
      DispatchPaths.requests,
      createRequestBody(
        packageId: packageId,
        genre: genre,
        meetPoint: meetPoint,
        note: note,
        expand: expand,
        expectedAmountVnd: expectedAmountVnd,
        provider: provider,
      ),
    ),
  ));

  @override
  Future<CancelQuote> cancel(String requestId, {required bool dryRun, String? reason}) =>
      dispatchGuard(() async => cancelQuoteFromJson(
        await _api.post(DispatchPaths.cancel(requestId), cancelBody(dryRun: dryRun, reason: reason)),
      ));

  @override
  Future<void> confirmComplete(String requestId) =>
      dispatchGuard(() => _api.post(DispatchPaths.confirmComplete(requestId), const {}));
}
```

Append to `lib/data/instant/instant_providers.dart` (imports `http_instant_booking_repository.dart`, `instant_booking_repository.dart`):

```dart
final instantBookingRepositoryProvider = Provider<InstantBookingRepository>((ref) {
  final api = ref.watch(dispatchApiClientProvider);
  return api == null ? const DisabledInstantBooking() : HttpInstantBookingRepository(api: api);
});
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/instant && flutter analyze`
Expected: PASS (7 new tests; I4's contract test still passes: every path used here is already in `dispatchOperations`).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/data/instant test/data/instant
git commit -m "feat(instant): customer booking repository over the dispatch API, with a fake

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `PaymentLauncher` port (fake:// in debug; real gateways in plan I6)

**Files:**
- Create: `lib/data/instant/payment_launcher.dart`, `test/data/instant/payment_launcher_test.dart`
- Modify: `lib/data/instant/instant_providers.dart`

**Interfaces:**
- Consumes: `ApiClient`, `dispatchGuard`, `DispatchPaths.devPaymentSucceed`, `CreatedRequest`, `PaymentProvider`, `dispatchApiClientProvider`, `MockApi`.
- Produces:
  - `enum PaymentStart { completedInApp, openedExternally, unavailable, failed }`.
  - `abstract class PaymentLauncher { PaymentProvider get provider; bool get available; Future<PaymentStart> open(CreatedRequest request); }` — the result only says whether the payment UI was started; whether money was taken is decided by the gateway webhook and read from the mirror (`pending_payment` → `searching` or `payment_failed`), never from a redirect (spec §4).
  - `DevFakePaymentLauncher({required ApiClient api, bool enabled = kDebugMode})` (`provider` = `fake`; for `fake://pay/<id>` calls `POST /v1/dev/payments/{id}/succeed`).
  - `const UnavailablePaymentLauncher()` (release builds until I6: `available` false, so the entry points stay hidden).
  - `FakePaymentLauncher({bool available = true, PaymentStart result = PaymentStart.completedInApp, PaymentProvider provider = PaymentProvider.fake})` with `opened` (`List<CreatedRequest>`) and `hold` (`Completer<void>?`, keeps `open` pending in tests).
  - `paymentLauncherProvider` (debug + `DISPATCH_URL` → `DevFakePaymentLauncher`; otherwise `UnavailablePaymentLauncher`). Plan I6 replaces only this provider's body.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/instant/payment_launcher_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/payment_launcher.dart';

import '../http/mock_api.dart';

CreatedRequest _req(String url) => CreatedRequest(requestId: 'RQ1', amountVnd: 690000, paymentUrl: Uri.parse(url));

void main() {
  test('debug: fake://pay is completed in the app through the dev endpoint', () async {
    final api = MockApi({'POST /v1/dev/payments/RQ1/succeed': (_) => (204, null)});
    final launcher = DevFakePaymentLauncher(api: api.api(), enabled: true);
    expect((launcher.available, launcher.provider), (true, PaymentProvider.fake));
    expect(await launcher.open(_req('fake://pay/RQ1')), PaymentStart.completedInApp);
    expect(api.calls, ['POST /v1/dev/payments/RQ1/succeed']);
  });

  test('a real gateway URL is not handled here (plan I6)', () async {
    final api = MockApi();
    final launcher = DevFakePaymentLauncher(api: api.api(), enabled: true);
    expect(await launcher.open(_req('https://pay.momo.vn/x')), PaymentStart.failed);
    expect(api.requests, isEmpty);
  });

  test('release builds: not available, nothing is called', () async {
    final api = MockApi();
    final launcher = DevFakePaymentLauncher(api: api.api(), enabled: false);
    expect(launcher.available, isFalse);
    expect(await launcher.open(_req('fake://pay/RQ1')), PaymentStart.failed);
    expect(api.requests, isEmpty);
    expect(const UnavailablePaymentLauncher().available, isFalse);
    expect(await const UnavailablePaymentLauncher().open(_req('fake://pay/RQ1')), PaymentStart.unavailable);
  });

  test('the dev endpoint missing (PAYMENTS is not fake) is a failure, not a crash', () async {
    final api = MockApi({'POST /v1/dev/payments/RQ1/succeed': (_) => (404, null)});
    expect(await DevFakePaymentLauncher(api: api.api(), enabled: true).open(_req('fake://pay/RQ1')), PaymentStart.failed);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/instant/payment_launcher_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

```dart
// lib/data/instant/payment_launcher.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_wire.dart';

enum PaymentStart { completedInApp, openedExternally, unavailable, failed }

/// Opens the payment for a created request. Plan I6 adds MoMo/VNPay; this
/// plan has the debug fake only. The outcome of the payment is never taken
/// from here: the mirror moves to `searching` (paid) or `payment_failed`.
abstract class PaymentLauncher {
  /// Sent as `provider` in `POST /v1/requests`.
  PaymentProvider get provider;

  /// False hides "Chụp ngay" in this build.
  bool get available;

  Future<PaymentStart> open(CreatedRequest request);
}

/// Debug builds with `PAYMENTS=fake` on the service: `fake://pay/<id>` is
/// "paid" by calling the dev endpoint, as the fake gateway would.
class DevFakePaymentLauncher implements PaymentLauncher {
  DevFakePaymentLauncher({required ApiClient api, this.enabled = kDebugMode}) : _api = api;
  final ApiClient _api;
  final bool enabled;

  @override
  PaymentProvider get provider => PaymentProvider.fake;

  @override
  bool get available => enabled;

  @override
  Future<PaymentStart> open(CreatedRequest request) async {
    if (!enabled || request.paymentUrl.scheme != 'fake') {
      return PaymentStart.failed;
    }
    try {
      await dispatchGuard(() => _api.post(DispatchPaths.devPaymentSucceed(request.requestId), const {}));
      return PaymentStart.completedInApp;
    } on DispatchException {
      return PaymentStart.failed;
    }
  }
}

class UnavailablePaymentLauncher implements PaymentLauncher {
  const UnavailablePaymentLauncher();

  @override
  PaymentProvider get provider => PaymentProvider.momo;

  @override
  bool get available => false;

  @override
  Future<PaymentStart> open(CreatedRequest request) async => PaymentStart.unavailable;
}

class FakePaymentLauncher implements PaymentLauncher {
  FakePaymentLauncher({
    this.available = true,
    this.result = PaymentStart.completedInApp,
    this.provider = PaymentProvider.fake,
  });

  @override
  bool available;
  @override
  final PaymentProvider provider;
  PaymentStart result;
  final opened = <CreatedRequest>[];
  Completer<void>? hold;

  @override
  Future<PaymentStart> open(CreatedRequest request) async {
    opened.add(request);
    await hold?.future;
    return result;
  }
}
```

Append to `lib/data/instant/instant_providers.dart` (imports `package:flutter/foundation.dart`, `payment_launcher.dart`):

```dart
/// Debug + DISPATCH_URL: the fake gateway. Release: unavailable until plan I6
/// replaces this body with the real MoMo/VNPay launcher.
final paymentLauncherProvider = Provider<PaymentLauncher>((ref) {
  final api = ref.watch(dispatchApiClientProvider);
  if (api != null && kDebugMode) {
    return DevFakePaymentLauncher(api: api);
  }
  return const UnavailablePaymentLauncher();
});
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/instant/payment_launcher_test.dart && flutter analyze`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/data/instant test/data/instant/payment_launcher_test.dart
git commit -m "feat(instant): PaymentLauncher port with the debug fake gateway

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Address search with Goong (`PlaceSearch`)

**Files:**
- Create: `lib/data/instant/place_search.dart`, `lib/data/instant/goong_place_search.dart`, `test/data/instant/goong_place_search_test.dart`
- Modify: `lib/data/instant/instant_providers.dart`

**Interfaces:**
- Consumes: `GoongConfig` (I4, `apiKey`, `hasApiKey`), `MeetPoint`, `LatLng`, `package:http` + `http/testing.dart`.
- Produces:
  - `class PlaceSuggestion { const PlaceSuggestion({required String placeId, required String title, String? subtitle}); }`, `class PlaceSearchException implements Exception` (text never contains a URL or key).
  - `abstract class PlaceSearch { Future<List<PlaceSuggestion>> suggest(String input, {LatLng? near, required String sessionToken}); Future<MeetPoint?> details(String placeId, {required String sessionToken}); Future<String?> addressAt(LatLng at); }`.
  - `GoongPlaceSearch({required GoongConfig config, http.Client? client, Duration timeout = const Duration(seconds: 8)})` — `GET https://rsapi.goong.io/Place/AutoComplete?input&location&limit=6&sessiontoken&api_key`, `GET /Place/Detail?place_id&sessiontoken&api_key`, `GET /Geocode?latlng&api_key`; fewer than 2 characters → no request; addresses cut to 200 characters (contract `MeetPoint.address`).
  - `FakePlaceSearch` (`suggestions` map by query, `places` map by id, `addressFor`, `fail`, counters `suggestCalls`, `detailsCalls`, `addressCalls`).
  - `placeSearchProvider` (`Provider<PlaceSearch>`).

Goong endpoint shapes used (Goong Places API docs, https://docs.goong.io/rest/): AutoComplete `{predictions: [{place_id, description, structured_formatting: {main_text, secondary_text}}], status}`; Detail `{result: {formatted_address, name, geometry: {location: {lat, lng}}}, status}`; Geocode `{results: [{formatted_address}], status}`. If the live API answers with a different shape when first run against a real key (Task 15), adapt the three parsing functions only and add the observed JSON to this test.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/instant/goong_place_search_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/goong_place_search.dart';
import 'package:photobooking/data/instant/place_search.dart';

const _key = 'SECRET-GOONG-KEY';
const _config = GoongConfig(mapKey: 'm', apiKey: _key);

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('autocomplete: key, bias and session token in the query; titles from structured_formatting', () async {
    late Uri seen;
    final search = GoongPlaceSearch(
      config: _config,
      client: MockClient((r) async {
        seen = r.url;
        return _json({
          'status': 'OK',
          'predictions': [
            {
              'place_id': 'g1',
              'description': 'Công viên Tao Đàn, Quận 1',
              'structured_formatting': {'main_text': 'Công viên Tao Đàn', 'secondary_text': 'Quận 1, TP. Hồ Chí Minh'},
            },
          ],
        });
      }),
    );
    final list = await search.suggest('Tao Đàn', near: const LatLng(10.77, 106.69), sessionToken: 's1');
    expect(seen.host, 'rsapi.goong.io');
    expect(seen.path, '/Place/AutoComplete');
    expect(seen.queryParameters, {
      'input': 'Tao Đàn',
      'location': '10.77,106.69',
      'limit': '6',
      'sessiontoken': 's1',
      'api_key': _key,
    });
    expect((list.single.placeId, list.single.title, list.single.subtitle), ('g1', 'Công viên Tao Đàn', 'Quận 1, TP. Hồ Chí Minh'));
  });

  test('fewer than two characters sends nothing', () async {
    var calls = 0;
    final search = GoongPlaceSearch(config: _config, client: MockClient((_) async {
      calls++;
      return _json({});
    }));
    expect(await search.suggest(' T ', sessionToken: 's'), isEmpty);
    expect(calls, 0);
  });

  test('details become a meet point; reverse geocoding gives an address', () async {
    final search = GoongPlaceSearch(
      config: _config,
      client: MockClient((r) async => switch (r.url.path) {
        '/Place/Detail' => _json({
          'status': 'OK',
          'result': {
            'formatted_address': '55C Nguyễn Thị Minh Khai, Quận 1',
            'name': 'Công viên Tao Đàn',
            'geometry': {'location': {'lat': 10.7745, 'lng': 106.6926}},
          },
        }),
        '/Geocode' => _json({'status': 'OK', 'results': [{'formatted_address': '${'Đường ' * 60}Quận 1'}]}),
        _ => _json({}, 404),
      }),
    );
    final p = await search.details('g1', sessionToken: 's1');
    expect((p!.lat, p.lng, p.address), (10.7745, 106.6926, '55C Nguyễn Thị Minh Khai, Quận 1'));
    final a = await search.addressAt(const LatLng(10.7745, 106.6926));
    expect(a!.length, lessThanOrEqualTo(200));
  });

  test('errors never carry the URL or the key', () async {
    final search = GoongPlaceSearch(
      config: _config,
      client: MockClient((r) async => throw http.ClientException('boom', r.url)),
    );
    try {
      await search.suggest('Tao Đàn', sessionToken: 's');
      fail('should throw');
    } on PlaceSearchException catch (e) {
      expect(e.toString(), isNot(contains(_key)));
      expect(e.toString(), isNot(contains('rsapi')));
    }
    final bad = GoongPlaceSearch(config: _config, client: MockClient((_) async => _json({'error': 'quota'}, 429)));
    await expectLater(bad.addressAt(const LatLng(1, 2)), throwsA(isA<PlaceSearchException>()));
  });

  test('no key configured: nothing is sent', () async {
    var calls = 0;
    final search = GoongPlaceSearch(
      config: const GoongConfig(mapKey: '', apiKey: ''),
      client: MockClient((_) async {
        calls++;
        return _json({});
      }),
    );
    await expectLater(search.suggest('Tao Đàn', sessionToken: 's'), throwsA(isA<PlaceSearchException>()));
    expect(calls, 0);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/instant/goong_place_search_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement**

```dart
// lib/data/instant/place_search.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';

class PlaceSuggestion {
  const PlaceSuggestion({required this.placeId, required this.title, this.subtitle});
  final String placeId;
  final String title;
  final String? subtitle;
}

/// Any search failure. Deliberately empty: a transport error's text would
/// contain the request URL, and with it the API key.
class PlaceSearchException implements Exception {
  const PlaceSearchException();

  @override
  String toString() => 'PlaceSearchException';
}

/// Address search and reverse geocoding for the meet point (S47).
abstract class PlaceSearch {
  Future<List<PlaceSuggestion>> suggest(String input, {LatLng? near, required String sessionToken});
  Future<MeetPoint?> details(String placeId, {required String sessionToken});
  Future<String?> addressAt(LatLng at);
}

class FakePlaceSearch implements PlaceSearch {
  final suggestions = <String, List<PlaceSuggestion>>{};
  final places = <String, MeetPoint>{};
  String Function(LatLng at)? addressFor;
  bool fail = false;
  int suggestCalls = 0;
  int detailsCalls = 0;
  int addressCalls = 0;

  @override
  Future<List<PlaceSuggestion>> suggest(String input, {LatLng? near, required String sessionToken}) async {
    suggestCalls++;
    if (fail) {
      throw const PlaceSearchException();
    }
    return suggestions[input.trim()] ?? const [];
  }

  @override
  Future<MeetPoint?> details(String placeId, {required String sessionToken}) async {
    detailsCalls++;
    if (fail) {
      throw const PlaceSearchException();
    }
    return places[placeId];
  }

  @override
  Future<String?> addressAt(LatLng at) async {
    addressCalls++;
    if (fail) {
      throw const PlaceSearchException();
    }
    return addressFor?.call(at);
  }
}
```

```dart
// lib/data/instant/goong_place_search.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/place_search.dart';

class GoongPlaceSearch implements PlaceSearch {
  GoongPlaceSearch({required GoongConfig config, http.Client? client, this.timeout = const Duration(seconds: 8)})
    : _config = config,
      _http = client ?? http.Client();

  static const _host = 'rsapi.goong.io';
  final GoongConfig _config;
  final http.Client _http;
  final Duration timeout;

  static String _cut(String s) => s.length > 200 ? s.substring(0, 200) : s;

  Future<Map<String, dynamic>> _get(String path, Map<String, String> query) async {
    if (!_config.hasApiKey) {
      throw const PlaceSearchException();
    }
    final uri = Uri.https(_host, path, {...query, 'api_key': _config.apiKey});
    try {
      final res = await _http.get(uri).timeout(timeout);
      if (res.statusCode != 200) {
        throw const PlaceSearchException();
      }
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      if (json is! Map<String, dynamic>) {
        throw const PlaceSearchException();
      }
      return json;
    } on PlaceSearchException {
      rethrow;
    } on Object {
      // ClientException.toString() includes the URL, i.e. the key.
      throw const PlaceSearchException();
    }
  }

  @override
  Future<List<PlaceSuggestion>> suggest(String input, {LatLng? near, required String sessionToken}) async {
    final q = input.trim();
    if (q.length < 2) {
      return const [];
    }
    final j = await _get('/Place/AutoComplete', {
      'input': q,
      if (near != null) 'location': '${near.lat},${near.lng}',
      'limit': '6',
      'sessiontoken': sessionToken,
    });
    final list = j['predictions'];
    if (list is! List) {
      return const [];
    }
    return [
      for (final p in list.whereType<Map<String, dynamic>>())
        if (p['place_id'] is String)
          PlaceSuggestion(
            placeId: p['place_id'] as String,
            title: (p['structured_formatting'] as Map?)?['main_text'] as String? ?? '${p['description'] ?? ''}',
            subtitle: (p['structured_formatting'] as Map?)?['secondary_text'] as String?,
          ),
    ];
  }

  @override
  Future<MeetPoint?> details(String placeId, {required String sessionToken}) async {
    final j = await _get('/Place/Detail', {'place_id': placeId, 'sessiontoken': sessionToken});
    final r = j['result'];
    if (r is! Map) {
      return null;
    }
    final loc = (r['geometry'] as Map?)?['location'] as Map?;
    final lat = loc?['lat'];
    final lng = loc?['lng'];
    final address = r['formatted_address'] ?? r['name'];
    if (lat is! num || lng is! num || address is! String) {
      return null;
    }
    return MeetPoint(lat: lat.toDouble(), lng: lng.toDouble(), address: _cut(address));
  }

  @override
  Future<String?> addressAt(LatLng at) async {
    final j = await _get('/Geocode', {'latlng': '${at.lat},${at.lng}'});
    final results = j['results'];
    if (results is! List || results.isEmpty) {
      return null;
    }
    final a = (results.first as Map?)?['formatted_address'];
    return a is String ? _cut(a) : null;
  }
}
```

Append to `lib/data/instant/instant_providers.dart` (imports `package:photobooking/core/core.dart`, `goong_place_search.dart`, `place_search.dart`):

```dart
final placeSearchProvider = Provider<PlaceSearch>(
  (ref) => GoongPlaceSearch(config: GoongConfig.fromEnvironment()),
);
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/instant/goong_place_search_test.dart && flutter analyze`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/data/instant test/data/instant/goong_place_search_test.dart
git commit -m "feat(instant): Goong address search and reverse geocoding that never leak the key

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `SearchPulse` (S48 rings around the `ApertureLoader`)

**Files:**
- Create: `lib/core/widgets/search_pulse.dart`, `test/core/widgets/search_pulse_test.dart`
- Modify: `lib/core/core.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `ApertureLoader` (I4 Task 8: `const ApertureLoader({double size = 66, bool active = true, String? semanticsLabel})`), `hostWidget`, `expectIdle`.
- Produces: `const SearchPulse({super.key, required bool active, double size = 200, String? semanticsLabel})` — the 66dp `ApertureLoader` (CTA gradient disc, white aperture) in the centre and three rings radiating from it, one `AnimationController` (2.4 s, matching the aperture's cycle) for the rings; the rings and the aperture run only while `active`, `TickerMode` is on and animations are allowed; otherwise both stop and the rings are drawn still; one `Semantics` label for the whole ("Đang tìm"); `RepaintBoundary`, no blur. l10n `instantSearching` "Đang tìm".

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/search_pulse_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import '../../support/idle.dart';
import 'widget_host.dart';

void main() {
  testWidgets('the centre is the aperture on the CTA fill, not a camera or the photo logo', (tester) async {
    await tester.pumpWidget(hostWidget(const Center(child: SearchPulse(active: true, semanticsLabel: 'Đang tìm'))));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ApertureLoader), findsOneWidget);
    expect(find.descendant(of: find.byType(SearchPulse), matching: find.byType(CtaSurface)), findsOneWidget);
    expect(tester.widget<ApertureMark>(find.byType(ApertureMark)).color, Colors.white);
    expect(find.byIcon(Icons.camera_alt_outlined), findsNothing);
    expect(find.byType(AppLogo), findsNothing);
  });

  testWidgets('active: two tickers (rings and aperture), one accessible label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const Center(child: SearchPulse(active: true, semanticsLabel: 'Đang tìm'))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, 2);
    expect(find.bySemanticsLabel('Đang tìm'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('inactive: idle', (tester) async {
    await tester.pumpWidget(hostWidget(const Center(child: SearchPulse(active: false))));
    await expectIdle(tester);
  });

  testWidgets('turning it off stops both animations', (tester) async {
    await tester.pumpWidget(hostWidget(const Center(child: SearchPulse(active: true))));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(hostWidget(const Center(child: SearchPulse(active: false))));
    await expectIdle(tester);
  });

  testWidgets('reduced motion: idle even while searching', (tester) async {
    await tester.pumpWidget(hostWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Center(child: SearchPulse(active: true, semanticsLabel: 'Đang tìm')),
      ),
    ));
    await expectIdle(tester);
  });

  testWidgets('fits 320dp at 1.3x in both themes', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(hostWidget(const SearchPulse(active: false), width: 320, textScale: 1.3, brightness: b));
      expect(tester.takeException(), isNull);
    }
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/search_pulse_test.dart`
Expected: FAIL to compile, `SearchPulse` undefined.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb`: `"instantSearching": "Đang tìm",` then `flutter gen-l10n`.

```dart
// lib/core/widgets/search_pulse.dart
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/aperture_loader.dart';

const _centre = 66.0;

/// S48: rings radiating from the brand aperture while the service looks for
/// a photographer. Still (and costing nothing) when [active] is false, when
/// the screen is not visible, or under reduced motion.
class SearchPulse extends StatefulWidget {
  const SearchPulse({super.key, required this.active, this.size = 200, this.semanticsLabel});

  final bool active;
  final double size;
  final String? semanticsLabel;

  @override
  State<SearchPulse> createState() => _SearchPulseState();
}

class _SearchPulseState extends State<SearchPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  bool get _run => widget.active && TickerMode.of(context) && !MediaQuery.disableAnimationsOf(context);

  void _sync() {
    if (_run && !_c.isAnimating) {
      _c.repeat();
    } else if (!_run && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SearchPulse old) {
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
    final ring = dark ? AppColorsDark.primary : AppColors.primary;
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: _RingsPainter(progress: _c, moving: _c.isAnimating, color: ring),
              ),
            ),
            ExcludeSemantics(child: ApertureLoader(active: widget.active)),
          ],
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.progress, required this.moving, required this.color}) : super(repaint: progress);
  final Animation<double> progress;
  final bool moving;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    for (var i = 0; i < 3; i++) {
      final t = moving ? (progress.value + i / 3) % 1 : 0.25 + i * 0.25;
      final r = lerpDouble(_centre / 2, maxR, t)!;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: (1 - t) * 0.45);
      canvas.drawCircle(centre, r, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.moving != moving || old.color != color;
}
```

In `lib/core/core.dart` add `export 'package:photobooking/core/widgets/search_pulse.dart';`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/search_pulse_test.dart && flutter analyze`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core lib/l10n test/core/widgets/search_pulse_test.dart
git commit -m "feat(core): SearchPulse, rings around the aperture loader for S48

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The draft, customer rules and `InstantBookController` (S47 logic)

**Files:**
- Create: `lib/features/instant/instant_draft.dart`, `lib/features/instant/instant_customer_rules.dart`, `lib/features/instant/instant_book_controller.dart`, `test/support/instant_customer_world.dart`, `test/features/instant/instant_customer_rules_test.dart`, `test/features/instant/instant_book_controller_test.dart`
- Modify: `test/support/instant_world.dart` (I4: optional phone), `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: Tasks 1–3; I4 `trackingLocationProvider`, `FixAccuracy`, `distanceMeters`, `InstantWorld`; 3a2 `locationRepositoryProvider`; 2a `currentContactProvider`; 2b `photographerContactRepositoryProvider`, `FakePhotographerContactRepository`, `ContactChannels`.
- Produces:
  - `class InstantDraft` (`package` = `p60`, `genre` = `portrait`, `meetPoint`, `note` (≤ 140), `expand` = false, `lastRequestId`, `lastQuote`), `class InstantDraftController extends Notifier<InstantDraft>` with `setPackage`, `setGenre`, `setMeetPoint`, `setNote`, `setExpand`, `setLastRequest(String id)`, `setLastQuote(PackagesQuote q)`; `instantDraftProvider` (keep-alive: survives S33 and S51 → S47).
  - Rules: `instantDefaultCenter` (Quận 1), `searchWindow` (10 min), `staleTrackAfter` (3 min), `lateFreeCancelAfter` (15 min), `requoteAfterKm` (3), `ignoreMoveBelowM` (15); `String formatClock(Duration)` (`1:12`), `Duration searchElapsed(InstantRequestView, DateTime now)`, `Duration? graceLeft(InstantRequestView, DateTime now)`, `bool trackStale(InstantTrack?, InstantRequestView, DateTime now)`, `bool photographerLate(InstantRequestView, int? firstEtaMinutes, DateTime now)`, `Duration shootRemaining(InstantRequestView, DateTime now)`, `bool customerCanCancel(InstantStatus)`, `bool canConfirmComplete(InstantRequestView, DateTime now)`.
  - `sealed class InstantSubmitResult` with `InstantSubmitNeedsPhone`, `InstantSubmitStarted(String requestId)`, `InstantSubmitPriceChanged(int amountVnd)`, `InstantSubmitFailed(DispatchError error)`.
  - `class InstantBookState` (`quote`, `loadingQuote`, `locating`, `locationDenied`, `submitting`, `outsideArea`, `quoteError`, `cameraToken`).
  - `class InstantBookController extends Notifier<InstantBookState>` with `Future<void> start()`, `Future<void> moveMeetPoint(LatLng at)`, `Future<void> choosePlace(MeetPoint p)`, `Future<void> useMyLocation()`, `Future<InstantSubmitResult> submit()`; `instantBookProvider` (`NotifierProvider.autoDispose`).
  - Test support `InstantCustomerWorld` (extends `InstantWorld` as a customer: `booking`, `payment`, `places`, `photographerContacts`, `meet`, `request(InstantStatus, {…})`, `track({Duration age, double northMeters})`).
  - l10n: `instantMeetPointHere` "Vị trí của bạn", `instantMeetPointPinned` "Điểm đã ghim".

Behaviour: S47 takes **one** medium fix (with the OS permission only when needed), names it by reverse geocoding (or "Vị trí của bạn"), and quotes there; with a meet point already in the draft (back from S33, retry from S51) it takes no fix. Moving the pin less than 15 m is ignored (camera settling); moving more re-names the point and re-quotes only beyond 3 km. Submit: no phone → S33; `phone_required` → S33; `price_changed` → re-quote and say the new price; `outside_service_area` → banner; payment launcher unavailable or failed → message; otherwise the request id for `/instant/:id`.

- [ ] **Step 1: Make the shared world's phone optional**

In `test/support/instant_world.dart` (plan I4): change the constructor to `InstantWorld({this.role = UserRole.photographer, this.withPhone = true});`, add the field `final bool withPhone;`, and in `init()` wrap the seeding line as `if (withPhone) { contacts.seed(uid, const UserContact(phone: '+84903123456')); }`.

- [ ] **Step 2: Write the failing tests**

```dart
// test/support/instant_customer_world.dart
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:photobooking/data/instant/instant_booking_repository.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/instant/payment_launcher.dart';
import 'package:photobooking/data/instant/place_search.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/photographer/photographer_contact_providers.dart';
import 'package:photobooking/data/photographer/photographer_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';

import 'instant_world.dart';

const _p1 = InstantPhotographer(
  uid: 'p1',
  displayName: 'Minh Trí',
  verified: true,
  rating: 4.9,
  completedShoots: 112,
);

const _withPhotographer = {
  InstantStatus.assigned,
  InstantStatus.enRoute,
  InstantStatus.arrived,
  InstantStatus.inProgress,
  InstantStatus.completed,
  InstantStatus.noShowCustomer,
  InstantStatus.disputed,
};

/// The customer side of Chụp ngay, on top of plan I4's world.
class InstantCustomerWorld extends InstantWorld {
  InstantCustomerWorld({super.withPhone, super.role = UserRole.customer});

  final booking = FakeInstantBookingRepository();
  final payment = FakePaymentLauncher();
  final places = FakePlaceSearch();
  final photographerContacts = FakePhotographerContactRepository();
  final meet = const MeetPoint(lat: 10.7745, lng: 106.6926, address: 'Công viên Tao Đàn, Quận 1');

  @override
  Future<void> init() async {
    await super.init();
    places.addressFor = (_) => 'Công viên Tao Đàn, Quận 1';
    location.current = LocationFix(lat: meet.lat, lng: meet.lng, accuracyM: 25, at: now);
    photographerContacts.seed('p1', channels: const ContactChannels(call: true, zalo: true));
  }

  @override
  List<Override> get overrides => [
    ...super.overrides,
    instantBookingRepositoryProvider.overrideWithValue(booking),
    paymentLauncherProvider.overrideWithValue(payment),
    placeSearchProvider.overrideWithValue(places),
    photographerContactRepositoryProvider.overrideWithValue(photographerContacts),
  ];

  InstantRequestView request(
    InstantStatus status, {
    String id = 'RQ1',
    DateTime? graceEndsAt,
    int? eta = 9,
    DateTime? assignedAt,
    DateTime? startedAt,
    DateTime? finishedAt,
    int? refundVnd,
    bool expand = false,
    int round = 1,
    int? radiusKm = 3,
    bool etaEstimated = false,
  }) {
    final has = _withPhotographer.contains(status);
    final arrived = status == InstantStatus.arrived || status == InstantStatus.inProgress || status == InstantStatus.completed;
    return InstantRequestView(
      id: id,
      status: status,
      customerId: uid,
      photographerId: has ? 'p1' : null,
      photographer: has ? _p1 : null,
      packageCode: InstantPackageCode.p60,
      genre: InstantGenre.portrait,
      amountVnd: 690000,
      expand: expand,
      round: round,
      radiusKm: radiusKm,
      searchEndsAt: status == InstantStatus.searching ? now.add(const Duration(minutes: 8, seconds: 48)) : null,
      etaMinutes: has ? eta : null,
      etaEstimated: etaEstimated,
      graceEndsAt: graceEndsAt,
      meetPoint: has ? meet : null,
      requestedAt: now.subtract(const Duration(minutes: 2)),
      assignedAt: has ? (assignedAt ?? now.subtract(const Duration(minutes: 1))) : null,
      arrivedAt: arrived ? now.subtract(const Duration(minutes: 5)) : null,
      startedAt: startedAt,
      finishedAt: finishedAt,
      refundVnd: refundVnd,
      updatedAt: now,
    );
  }

  /// The photographer [northMeters] north of the meet point, [age] old.
  InstantTrack track({Duration age = Duration.zero, double northMeters = 900}) => InstantTrack(
    lat: meet.lat + northMeters / 111195,
    lng: meet.lng,
    accuracyM: 8,
    at: now.subtract(age),
  );
}
```

(`FakePhotographerContactRepository` and its `seed(uid, {channels, numbers, area})` come from plan 2b's `lib/data/photographer/photographer_contact_repository.dart`.)

```dart
// test/features/instant/instant_customer_rules_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/instant_customer_rules.dart';

import '../../support/instant_customer_world.dart';

void main() {
  late InstantCustomerWorld w;
  setUp(() async {
    w = InstantCustomerWorld();
    await w.init();
  });

  test('clock text', () {
    expect(formatClock(const Duration(seconds: 72)), '1:12');
    expect(formatClock(const Duration(minutes: 38, seconds: 12)), '38:12');
    expect(formatClock(const Duration(seconds: -5)), '0:00');
  });

  test('search elapsed counts from the start of the 10-minute window', () {
    expect(searchElapsed(w.request(InstantStatus.searching), w.now), const Duration(minutes: 1, seconds: 12));
  });

  test('grace is left only before graceEndsAt', () {
    final v = w.request(InstantStatus.enRoute, graceEndsAt: w.now.add(const Duration(seconds: 100)));
    expect(graceLeft(v, w.now), const Duration(seconds: 100));
    expect(graceLeft(v, w.now.add(const Duration(seconds: 100))), isNull);
  });

  test('no new position for more than 3 minutes while on the way is stale', () {
    final v = w.request(InstantStatus.enRoute);
    expect(trackStale(w.track(age: const Duration(minutes: 2)), v, w.now), isFalse);
    expect(trackStale(w.track(age: const Duration(minutes: 4)), v, w.now), isTrue);
    expect(trackStale(null, w.request(InstantStatus.arrived), w.now), isFalse);
  });

  test('late = more than 15 minutes after the first ETA', () {
    final v = w.request(InstantStatus.enRoute, assignedAt: w.now.subtract(const Duration(minutes: 25)));
    expect(photographerLate(v, 9, w.now), isTrue);
    expect(photographerLate(v, 12, w.now), isFalse);
    expect(photographerLate(v, null, w.now), isFalse);
  });

  test('shoot time left and when completion can be confirmed', () {
    final started = w.request(InstantStatus.inProgress, startedAt: w.now.subtract(const Duration(minutes: 21, seconds: 48)));
    expect(shootRemaining(started, w.now), const Duration(minutes: 38, seconds: 12));
    expect(canConfirmComplete(started, w.now), isFalse);
    expect(canConfirmComplete(started, w.now.add(const Duration(minutes: 39))), isTrue);
    final finished = w.request(InstantStatus.inProgress, startedAt: w.now, finishedAt: w.now);
    expect(canConfirmComplete(finished, w.now), isTrue);
  });

  test('the customer may cancel before the shoot starts', () {
    expect(
      InstantStatus.values.where(customerCanCancel).toSet(),
      {InstantStatus.searching, InstantStatus.assigned, InstantStatus.enRoute, InstantStatus.arrived},
    );
  });
}
```

```dart
// test/features/instant/instant_book_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/fake_instant_repositories.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/payment_launcher.dart';
import 'package:photobooking/data/instant/tracking_location.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/instant/instant_book_controller.dart';
import 'package:photobooking/features/instant/instant_customer_rules.dart';
import 'package:photobooking/features/instant/instant_draft.dart';

import '../../support/instant_customer_world.dart';

void main() {
  late InstantCustomerWorld w;
  setUp(() async {
    w = InstantCustomerWorld();
    await w.init();
  });

  Future<ProviderContainer> started({InstantCustomerWorld? world}) async {
    final c = ProviderContainer(overrides: (world ?? w).overrides);
    addTearDown(c.dispose);
    c.listen(instantBookProvider, (_, _) {});
    await c.read(instantBookProvider.notifier).start();
    return c;
  }

  test('start: one medium fix, named by reverse geocoding, quoted there', () async {
    final c = await started();
    expect(w.location.currentFixCalls, 1);
    expect(w.location.accuracies, [FixAccuracy.medium]);
    expect(c.read(instantDraftProvider).meetPoint!.address, 'Công viên Tao Đàn, Quận 1');
    expect(c.read(instantBookProvider).quote!.byCode(InstantPackageCode.p60)!.priceVnd, 690000);
    expect(w.booking.packagesCalls, 1);
    expect(c.read(instantBookProvider).cameraToken, 1);
  });

  test('a meet point already in the draft: no GPS at all', () async {
    final c = ProviderContainer(overrides: w.overrides);
    addTearDown(c.dispose);
    c.read(instantDraftProvider.notifier).setMeetPoint(w.meet);
    c.listen(instantBookProvider, (_, _) {});
    await c.read(instantBookProvider.notifier).start();
    expect(w.location.currentFixCalls, 0);
    expect(w.permission.requestCalls, 0);
  });

  test('location refused: quote at the default centre, ask to search', () async {
    w.permission = FakeLocationRepository(status: LocationPermissionStatus.denied, statusAfterRequest: LocationPermissionStatus.denied);
    final c = await started();
    expect(c.read(instantBookProvider).locationDenied, isTrue);
    expect(c.read(instantDraftProvider).meetPoint, isNull);
    expect(c.read(instantBookProvider).quote, isNotNull);
  });

  test('dragging the pin: under 15 m ignored; further renames; beyond 3 km re-quotes', () async {
    final c = await started();
    final ctl = c.read(instantBookProvider.notifier);
    w.places.addressCalls = 0;
    await ctl.moveMeetPoint(LatLng(w.meet.lat + 10 / 111195, w.meet.lng));
    expect(w.places.addressCalls, 0);
    w.places.addressFor = (_) => 'Hồ Con Rùa, Quận 3';
    await ctl.moveMeetPoint(LatLng(w.meet.lat + 800 / 111195, w.meet.lng));
    expect(c.read(instantDraftProvider).meetPoint!.address, 'Hồ Con Rùa, Quận 3');
    expect(w.booking.packagesCalls, 1);
    await ctl.moveMeetPoint(LatLng(w.meet.lat + 5000 / 111195, w.meet.lng));
    expect(w.booking.packagesCalls, 2);
  });

  test('submit without a phone number goes to S33 and creates nothing', () async {
    final noPhone = InstantCustomerWorld(withPhone: false);
    await noPhone.init();
    final c = await started(world: noPhone);
    expect(await c.read(instantBookProvider.notifier).submit(), isA<InstantSubmitNeedsPhone>());
    expect(noPhone.booking.created, isEmpty);
  });

  test('submit: the exact request, the payment opened, the request id', () async {
    final c = await started();
    c.read(instantDraftProvider.notifier)
      ..setGenre(InstantGenre.couple)
      ..setNote('Áo dài trắng')
      ..setExpand(true);
    final r = await c.read(instantBookProvider.notifier).submit();
    expect((r as InstantSubmitStarted).requestId, 'RQ1');
    expect(w.booking.created.single, {
      'packageId': 'PK60',
      'genre': 'couple',
      'meetPoint': {'lat': w.meet.lat, 'lng': w.meet.lng, 'address': 'Công viên Tao Đàn, Quận 1'},
      'note': 'Áo dài trắng',
      'expand': true,
      'expectedAmountVnd': 690000,
      'provider': 'fake',
    });
    expect(w.payment.opened.single.requestId, 'RQ1');
    expect(c.read(instantDraftProvider).lastRequestId, 'RQ1');
  });

  test('phone_required from the service also goes to S33', () async {
    final c = await started();
    w.booking.createError = DispatchError.phoneRequired;
    expect(await c.read(instantBookProvider.notifier).submit(), isA<InstantSubmitNeedsPhone>());
  });

  test('price_changed: re-quote and tell the new price', () async {
    final c = await started();
    w.booking.createError = DispatchError.priceChanged;
    w.booking.quote = PackagesQuote(
      cityId: 'hcm',
      cityName: 'TP. Hồ Chí Minh',
      priceListVersion: 3,
      surge: 1.05,
      packages: [
        for (final p in fakePackagesQuote().packages)
          InstantPackage(id: p.id, code: p.code, durationMin: p.durationMin, photos: p.photos, priceVnd: p.code == InstantPackageCode.p60 ? 720000 : p.priceVnd, payoutVnd: p.payoutVnd),
      ],
    );
    final r = await c.read(instantBookProvider.notifier).submit();
    expect((r as InstantSubmitPriceChanged).amountVnd, 720000);
    expect(c.read(instantBookProvider).quote!.byCode(InstantPackageCode.p60)!.priceVnd, 720000);
  });

  test('outside_service_area turns the banner on', () async {
    final c = await started();
    w.booking.createError = DispatchError.outsideServiceArea;
    expect(await c.read(instantBookProvider.notifier).submit(), isA<InstantSubmitFailed>());
    expect(c.read(instantBookProvider).outsideArea, isTrue);
  });

  test('no payment in this build, or the payment did not open', () async {
    final c = await started();
    w.payment.available = false;
    expect((await c.read(instantBookProvider.notifier).submit() as InstantSubmitFailed).error, DispatchError.disabled);
    w.payment
      ..available = true
      ..result = PaymentStart.failed;
    expect((await c.read(instantBookProvider.notifier).submit() as InstantSubmitFailed).error, DispatchError.unknown);
  });

  test('the default centre is Quận 1', () {
    expect(instantDefaultCenter, const LatLng(10.7769, 106.7009));
  });
}
```

- [ ] **Step 3: Run and see them fail**

Run: `flutter test test/features/instant`
Expected: FAIL to compile (draft, rules and controller missing).

- [ ] **Step 4: Implement**

Strings (`lib/l10n/app_vi.arb`, then `flutter gen-l10n`):

```json
  "instantMeetPointHere": "Vị trí của bạn",
  "instantMeetPointPinned": "Điểm đã ghim",
```

```dart
// lib/features/instant/instant_draft.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/instant/instant_models.dart';

const _keep = Object();

/// What the customer chose on S47. Kept for the whole session so S33 (add a
/// phone) and S51 ("Thử lại") come back to the same choices.
class InstantDraft {
  const InstantDraft({
    this.package = InstantPackageCode.p60,
    this.genre = InstantGenre.portrait,
    this.meetPoint,
    this.note = '',
    this.expand = false,
    this.lastRequestId,
    this.lastQuote,
  });

  final InstantPackageCode package;
  final InstantGenre genre;
  final MeetPoint? meetPoint;
  final String note;
  final bool expand;
  final String? lastRequestId;
  final PackagesQuote? lastQuote;

  InstantDraft copyWith({
    InstantPackageCode? package,
    InstantGenre? genre,
    Object? meetPoint = _keep,
    String? note,
    bool? expand,
    Object? lastRequestId = _keep,
    Object? lastQuote = _keep,
  }) => InstantDraft(
    package: package ?? this.package,
    genre: genre ?? this.genre,
    meetPoint: identical(meetPoint, _keep) ? this.meetPoint : meetPoint as MeetPoint?,
    note: note ?? this.note,
    expand: expand ?? this.expand,
    lastRequestId: identical(lastRequestId, _keep) ? this.lastRequestId : lastRequestId as String?,
    lastQuote: identical(lastQuote, _keep) ? this.lastQuote : lastQuote as PackagesQuote?,
  );
}

class InstantDraftController extends Notifier<InstantDraft> {
  @override
  InstantDraft build() => const InstantDraft();

  void setPackage(InstantPackageCode c) => state = state.copyWith(package: c);
  void setGenre(InstantGenre g) => state = state.copyWith(genre: g);
  void setMeetPoint(MeetPoint p) => state = state.copyWith(meetPoint: p);
  void setNote(String n) => state = state.copyWith(note: n.length > 140 ? n.substring(0, 140) : n);
  void setExpand(bool on) => state = state.copyWith(expand: on);
  void setLastRequest(String id) => state = state.copyWith(lastRequestId: id);
  void setLastQuote(PackagesQuote q) => state = state.copyWith(lastQuote: q);
}

final instantDraftProvider = NotifierProvider<InstantDraftController, InstantDraft>(InstantDraftController.new);
```

```dart
// lib/features/instant/instant_customer_rules.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';

/// Where S47's map starts when the location is unknown (Quận 1, TP. HCM).
const instantDefaultCenter = LatLng(10.7769, 106.7009);

/// Spec §3.2: the whole search takes at most 10 minutes.
const searchWindow = Duration(minutes: 10);

/// Spec §10: no position for 3 minutes → "Đang chờ cập nhật vị trí";
/// 15 minutes past the first ETA → free cancel.
const staleTrackAfter = Duration(minutes: 3);
const lateFreeCancelAfter = Duration(minutes: 15);

/// A new quote only when the pin moves this far (city surge rarely differs
/// inside 3 km; the service checks the price again anyway: price_changed).
const requoteAfterKm = 3.0;

/// The camera settling after a programmatic move is not a pin move.
const ignoreMoveBelowM = 15.0;

String formatClock(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

Duration searchElapsed(InstantRequestView v, DateTime now) {
  final start = v.searchEndsAt?.subtract(searchWindow) ?? v.requestedAt;
  final d = now.difference(start);
  return d.isNegative ? Duration.zero : d;
}

Duration? graceLeft(InstantRequestView v, DateTime now) {
  final g = v.graceEndsAt;
  if (g == null) {
    return null;
  }
  final d = g.difference(now);
  return d > Duration.zero ? d : null;
}

bool trackStale(InstantTrack? t, InstantRequestView v, DateTime now) {
  if (!v.status.onTheWay) {
    return false;
  }
  final last = t?.at ?? v.assignedAt;
  return last != null && now.difference(last) > staleTrackAfter;
}

bool photographerLate(InstantRequestView v, int? firstEtaMinutes, DateTime now) {
  final assigned = v.assignedAt;
  if (!v.status.onTheWay || assigned == null || firstEtaMinutes == null) {
    return false;
  }
  return now.isAfter(assigned.add(Duration(minutes: firstEtaMinutes)).add(lateFreeCancelAfter));
}

Duration shootRemaining(InstantRequestView v, DateTime now) {
  final started = v.startedAt;
  if (started == null) {
    return Duration(minutes: v.durationMin);
  }
  final d = started.add(Duration(minutes: v.durationMin)).difference(now);
  return d.isNegative ? Duration.zero : d;
}

bool customerCanCancel(InstantStatus s) =>
    s == InstantStatus.searching || s == InstantStatus.assigned || s == InstantStatus.enRoute || s == InstantStatus.arrived;

bool canConfirmComplete(InstantRequestView v, DateTime now) =>
    v.status == InstantStatus.inProgress && (v.finishedAt != null || shootRemaining(v, now) == Duration.zero);
```

```dart
// lib/features/instant/instant_book_controller.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/instant/payment_launcher.dart';
import 'package:photobooking/data/instant/place_search.dart';
import 'package:photobooking/data/instant/tracking_location.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/instant/instant_customer_rules.dart';
import 'package:photobooking/features/instant/instant_draft.dart';
import 'package:photobooking/features/instant_common/instant_services.dart';
import 'package:photobooking/l10n/app_localizations.dart';

sealed class InstantSubmitResult {
  const InstantSubmitResult();
}

final class InstantSubmitNeedsPhone extends InstantSubmitResult {
  const InstantSubmitNeedsPhone();
}

final class InstantSubmitStarted extends InstantSubmitResult {
  const InstantSubmitStarted(this.requestId);
  final String requestId;
}

final class InstantSubmitPriceChanged extends InstantSubmitResult {
  const InstantSubmitPriceChanged(this.amountVnd);
  final int amountVnd;
}

final class InstantSubmitFailed extends InstantSubmitResult {
  const InstantSubmitFailed(this.error);
  final DispatchError error;
}

const _keep = Object();

class InstantBookState {
  const InstantBookState({
    this.quote,
    this.loadingQuote = true,
    this.locating = false,
    this.locationDenied = false,
    this.submitting = false,
    this.outsideArea = false,
    this.quoteError,
    this.cameraToken = 0,
  });

  final PackagesQuote? quote;
  final bool loadingQuote;
  final bool locating;
  final bool locationDenied;
  final bool submitting;
  final bool outsideArea;
  final DispatchError? quoteError;

  /// Bumped when the camera must jump to the draft's meet point.
  final int cameraToken;

  InstantBookState copyWith({
    Object? quote = _keep,
    bool? loadingQuote,
    bool? locating,
    bool? locationDenied,
    bool? submitting,
    bool? outsideArea,
    Object? quoteError = _keep,
    int? cameraToken,
  }) => InstantBookState(
    quote: identical(quote, _keep) ? this.quote : quote as PackagesQuote?,
    loadingQuote: loadingQuote ?? this.loadingQuote,
    locating: locating ?? this.locating,
    locationDenied: locationDenied ?? this.locationDenied,
    submitting: submitting ?? this.submitting,
    outsideArea: outsideArea ?? this.outsideArea,
    quoteError: identical(quoteError, _keep) ? this.quoteError : quoteError as DispatchError?,
    cameraToken: cameraToken ?? this.cameraToken,
  );
}

class InstantBookController extends Notifier<InstantBookState> {
  final AppLocalizations _l = lookupAppLocalizations(const Locale('vi'));
  LatLng? _quotedAt;

  @override
  InstantBookState build() {
    // Keeps the private contact listener alive while S47 is open, so submit
    // can read it without a second subscription.
    ref.listen(currentContactProvider, (_, _) {});
    return const InstantBookState();
  }

  InstantDraftController get _draft => ref.read(instantDraftProvider.notifier);

  Future<void> start() async {
    if (ref.read(instantDraftProvider).meetPoint == null) {
      await _locate();
    }
    await _quote();
  }

  Future<void> _locate() async {
    state = state.copyWith(locating: true);
    final repo = ref.read(locationRepositoryProvider);
    var s = await repo.permissionStatus();
    if (s == LocationPermissionStatus.notAsked || s == LocationPermissionStatus.denied) {
      s = await repo.request();
    }
    if (s != LocationPermissionStatus.granted) {
      state = state.copyWith(locating: false, locationDenied: true);
      return;
    }
    final fix = await ref.read(trackingLocationProvider).currentFix(accuracy: FixAccuracy.medium);
    if (fix == null) {
      state = state.copyWith(locating: false);
      return;
    }
    final address = await _addressAt(fix.latLng) ?? _l.instantMeetPointHere;
    _draft.setMeetPoint(MeetPoint(lat: fix.lat, lng: fix.lng, address: address));
    state = state.copyWith(locating: false, locationDenied: false, cameraToken: state.cameraToken + 1);
  }

  Future<String?> _addressAt(LatLng at) async {
    try {
      return await ref.read(placeSearchProvider).addressAt(at);
    } on PlaceSearchException {
      return null;
    }
  }

  Future<void> _quote({bool force = false}) async {
    final at = ref.read(instantDraftProvider).meetPoint?.latLng ?? instantDefaultCenter;
    final last = _quotedAt;
    if (!force && state.quote != null && last != null && distanceMeters(last, at) < requoteAfterKm * 1000) {
      return;
    }
    state = state.copyWith(loadingQuote: true, quoteError: null, outsideArea: false);
    try {
      final q = await ref.read(instantBookingRepositoryProvider).packages(near: at);
      _quotedAt = at;
      _draft.setLastQuote(q);
      state = state.copyWith(quote: q, loadingQuote: false);
    } on DispatchException catch (e) {
      state = state.copyWith(
        loadingQuote: false,
        quoteError: e.error,
        outsideArea: e.error == DispatchError.outsideServiceArea,
      );
    }
  }

  Future<void> moveMeetPoint(LatLng at) async {
    final current = ref.read(instantDraftProvider).meetPoint;
    if (current != null && distanceMeters(current.latLng, at) < ignoreMoveBelowM) {
      return;
    }
    final address = await _addressAt(at) ?? _l.instantMeetPointPinned;
    _draft.setMeetPoint(MeetPoint(lat: at.lat, lng: at.lng, address: address));
    await _quote();
  }

  Future<void> choosePlace(MeetPoint p) async {
    _draft.setMeetPoint(p);
    state = state.copyWith(cameraToken: state.cameraToken + 1);
    await _quote();
  }

  Future<void> useMyLocation() async {
    await _locate();
    await _quote();
  }

  Future<InstantSubmitResult> submit() async {
    if (state.submitting) {
      return const InstantSubmitFailed(DispatchError.conflict);
    }
    final draft = ref.read(instantDraftProvider);
    final pkg = state.quote?.byCode(draft.package);
    final meet = draft.meetPoint;
    if (pkg == null || meet == null) {
      return const InstantSubmitFailed(DispatchError.invalidArgument);
    }
    final launcher = ref.read(paymentLauncherProvider);
    if (!launcher.available) {
      return const InstantSubmitFailed(DispatchError.disabled);
    }
    if (await ref.read(currentContactProvider.future) == null) {
      return const InstantSubmitNeedsPhone();
    }
    state = state.copyWith(submitting: true);
    try {
      final created = await ref.read(instantBookingRepositoryProvider).create(
        packageId: pkg.id,
        genre: draft.genre,
        meetPoint: meet,
        note: draft.note,
        expand: draft.expand,
        expectedAmountVnd: pkg.priceVnd,
        provider: launcher.provider,
      );
      _draft.setLastRequest(created.requestId);
      final started = await launcher.open(created);
      if (started == PaymentStart.completedInApp || started == PaymentStart.openedExternally) {
        return InstantSubmitStarted(created.requestId);
      }
      return const InstantSubmitFailed(DispatchError.unknown);
    } on DispatchException catch (e) {
      switch (e.error) {
        case DispatchError.phoneRequired:
          return const InstantSubmitNeedsPhone();
        case DispatchError.priceChanged:
          await _quote(force: true);
          final price = state.quote?.byCode(draft.package)?.priceVnd;
          return price == null ? InstantSubmitFailed(e.error) : InstantSubmitPriceChanged(price);
        case DispatchError.outsideServiceArea:
          state = state.copyWith(outsideArea: true);
          return InstantSubmitFailed(e.error);
        default:
          return InstantSubmitFailed(e.error);
      }
    } finally {
      state = state.copyWith(submitting: false);
    }
  }
}

final instantBookProvider = NotifierProvider.autoDispose<InstantBookController, InstantBookState>(
  InstantBookController.new,
);
```

- [ ] **Step 5: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/features/instant test/features/instant_work && flutter analyze`
Expected: PASS (7 + 11 new tests; I4's tests still pass with the optional phone).

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/features/instant lib/l10n test/support test/features/instant
git commit -m "feat(instant): customer draft, S47 controller with one location fix, phone gate and price change

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: S47 screen, meet-point search sheet and the `/instant` route

**Files:**
- Create: `lib/features/instant/customer_only.dart`, `lib/features/instant/meet_point_search_sheet.dart`, `lib/features/instant/instant_book_screen.dart`, `lib/features/instant/instant_request_screen.dart` (placeholder, replaced in Task 7), `test/support/instant_customer_screens.dart`, `test/features/instant/instant_book_screen_test.dart`, `test/features/instant/meet_point_search_sheet_test.dart`
- Modify: `lib/app/router.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: Task 5; I4 `AppMap`, `ApertureLoader`, `instantErrorText`, `genreLabel`, `packageLabel`; 3a1 `AppChip`, `showAppSheet`; 3a2 `AppSkeleton`, `formatMoney`; `currentProfileProvider`, `AppTab`.
- Produces:
  - `const CustomerOnly({super.key, required Widget child})`.
  - `Future<MeetPoint?> showMeetPointSearch(BuildContext context, {LatLng? near})`; `MeetPointSearchController` (`NotifierProvider.autoDispose`, debounced 300 ms, ≥ 2 characters, one Goong session token per sheet). Keys: `meet-search-field`, `meet-result-<placeId>`, `meet-search-empty`, `meet-search-error`.
  - `const InstantBookScreen({super.key})` (S47, route `/instant`). Keys: `instant-search`, `instant-map`, `instant-package-<code>`, `instant-genre-<code>`, `instant-expand`, `instant-note`, `instant-escrow`, `instant-outside`, `instant-regular`, `instant-pay`, `instant-paying`.
  - Test support `instantCustomerApp(InstantCustomerWorld w, {required String location, Brightness brightness, double textScale})` with stubs `/profile/phone`, `/action` ("find"), `/home`, `/chat/:chatId`, `/instant/:id/review`.
  - l10n listed in Step 3.

Layout (mock S47): app bar "Chụp ngay" / "Nhiếp ảnh gia tới chỗ bạn trong khoảng 30–90 phút"; a search field "Tìm địa chỉ" (opens the sheet); the 180dp map with a fixed centre pin "Điểm hẹn · {địa chỉ}" (drag the map under it) and "Về vị trí của tôi"; the location hint when location is off; the outside-area banner with "Đặt lịch thường"; three package tiles (duration, photos, short price; "1 giờ" preselected); genre chips (five); "Mở rộng tìm kiếm" (off) with its explanation; the note (≤ 140); the escrow line with the typical match time when known; the one primary "Thanh toán {giá} và tìm". While the request is created and the payment opens, a scrim with the `ApertureLoader` ("Đang mở thanh toán") covers the screen and the button shows its spinner.

- [ ] **Step 1: Write the failing tests**

```dart
// test/support/instant_customer_screens.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/instant/instant_book_screen.dart';
import 'package:photobooking/features/instant/instant_request_screen.dart';

import 'instant_customer_world.dart';
import 'screen_host.dart';

/// The customer routes of plan I5 plus stubs for the routes they link to.
Widget instantCustomerApp(
  InstantCustomerWorld w, {
  required String location,
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
}) {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/instant',
        builder: (_, _) => const InstantBookScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, s) => InstantRequestScreen(requestId: s.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'cancel',
                builder: (_, s) => InstantRequestScreen(requestId: s.pathParameters['id']!, openCancel: true),
              ),
              GoRoute(path: 'review', builder: (_, s) => Text('review ${s.pathParameters['id']}')),
            ],
          ),
        ],
      ),
      GoRoute(path: '/profile/phone', builder: (_, s) => Text('phone ${s.uri.queryParameters['returnTo']}')),
      GoRoute(path: '/action', builder: (_, _) => const Text('find')),
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

```dart
// test/features/instant/instant_book_screen_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/fake_instant_repositories.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/place_search.dart';
import 'package:photobooking/data/location/location_repository.dart';

import 'package:photobooking/features/instant/instant_book_screen.dart';

import '../../support/instant_customer_screens.dart';
import '../../support/instant_customer_world.dart';

void main() {
  late InstantCustomerWorld w;
  setUp(() async {
    w = InstantCustomerWorld();
    await w.init();
  });

  Future<void> open(WidgetTester tester, {Brightness b = Brightness.dark, double scale = 1}) async {
    await tester.pumpWidget(instantCustomerApp(w, location: '/instant', brightness: b, textScale: scale));
    await tester.pumpAndSettle();
  }

  testWidgets('packages, kind of shoot, meet point, expand off, escrow with typical time, one primary', (tester) async {
    await open(tester);
    expect(find.text('Chụp ngay'), findsOneWidget);
    expect(find.text('Nhiếp ảnh gia tới chỗ bạn trong khoảng 30–90 phút'), findsOneWidget);
    expect(find.byKey(const Key('fake-map')), findsOneWidget);
    expect(find.text('Điểm hẹn · Công viên Tao Đàn, Quận 1'), findsOneWidget);
    for (final t in ['30 phút', '15 ảnh', '390K', '1 giờ', '30 ảnh', '690K', '2 giờ', '60 ảnh']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(tester.getSemantics(find.byKey(const Key('instant-package-p60'))), containsSemantics(isSelected: true));
    expect(find.text('Sự kiện nhỏ'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('instant-expand'))).value, isFalse);
    expect(
      find.text('Tiền được giữ an toàn và hoàn 100% nếu không có người nhận. Thường có người nhận trong khoảng 4 phút.'),
      findsOneWidget,
    );
    expect(find.text('Thanh toán 690.000₫ và tìm'), findsOneWidget);
    expect(find.byType(CtaSurface), findsOneWidget);
  });

  testWidgets('no typical time yet: that sentence is left out', (tester) async {
    w.booking.quote = fakePackagesQuote(typicalMatchMinutes: null);
    await open(tester);
    expect(find.text('Tiền được giữ an toàn và hoàn 100% nếu không có người nhận.'), findsOneWidget);
  });

  testWidgets('choosing 2 giờ changes the price on the button', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('instant-package-p120')));
    await tester.pump();
    expect(find.text('Thanh toán 1.190.000₫ và tìm'), findsOneWidget);
  });

  testWidgets('pay: request created, payment opened, then the status route', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('instant-genre-couple')));
    await tester.tap(find.byKey(const Key('instant-expand')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('instant-pay')));
    await tester.pumpAndSettle();
    expect(w.booking.created.single['genre'], 'couple');
    expect(w.booking.created.single['expand'], true);
    expect(w.payment.opened.single.requestId, 'RQ1');
    expect(find.byType(InstantBookScreenMarker), findsNothing);
  });

  testWidgets('while creating and opening the payment: the aperture wait covers the screen', (tester) async {
    w.payment.hold = Completer<void>();
    await open(tester);
    await tester.tap(find.byKey(const Key('instant-pay')));
    await tester.pump();
    expect(find.byKey(const Key('instant-paying')), findsOneWidget);
    expect(find.byType(ApertureLoader), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'only the button spinner');
    w.payment.hold!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('no phone number: S33 first, coming back here', (tester) async {
    final noPhone = InstantCustomerWorld(withPhone: false);
    await noPhone.init();
    await tester.pumpWidget(instantCustomerApp(noPhone, location: '/instant'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('instant-pay')));
    await tester.pumpAndSettle();
    expect(find.text('phone /instant'), findsOneWidget);
    expect(noPhone.booking.created, isEmpty);
  });

  testWidgets('price changed: the new price is said and shown on the button', (tester) async {
    await open(tester);
    w.booking.createError = DispatchError.priceChanged;
    w.booking.quote = PackagesQuote(
      cityId: 'hcm',
      cityName: 'TP. Hồ Chí Minh',
      priceListVersion: 3,
      surge: 1.05,
      packages: [
        for (final p in fakePackagesQuote().packages)
          InstantPackage(id: p.id, code: p.code, durationMin: p.durationMin, photos: p.photos, priceVnd: p.code == InstantPackageCode.p60 ? 720000 : p.priceVnd, payoutVnd: p.payoutVnd),
      ],
    );
    await tester.tap(find.byKey(const Key('instant-pay')));
    await tester.pumpAndSettle();
    expect(find.text('Giá vừa đổi thành 720.000₫. Kiểm tra rồi bấm lại.'), findsOneWidget);
    expect(find.text('Thanh toán 720.000₫ và tìm'), findsOneWidget);
  });

  testWidgets('outside the service area: a banner and a way to book normally', (tester) async {
    w.booking.packagesError = DispatchError.outsideServiceArea;
    await open(tester);
    expect(find.text('Chụp ngay chưa có ở khu vực này.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.descendant(of: find.byKey(const Key('instant-pay')), matching: find.byType(FilledButton))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('instant-regular')));
    await tester.pumpAndSettle();
    expect(find.text('find'), findsOneWidget);
  });

  testWidgets('location off: a hint; dragging the map pins the point and names it', (tester) async {
    w.permission = FakeLocationRepository(status: LocationPermissionStatus.denied, statusAfterRequest: LocationPermissionStatus.denied);
    await open(tester);
    expect(find.text('Bật vị trí hoặc tìm địa chỉ để ghim điểm hẹn.'), findsOneWidget);
    w.places.addressFor = (_) => 'Hồ Con Rùa, Quận 3';
    w.map.settleCamera(const LatLng(10.7827, 106.6958));
    await tester.pumpAndSettle();
    expect(find.text('Điểm hẹn · Hồ Con Rùa, Quận 3'), findsOneWidget);
  });

  testWidgets('searching an address moves the pin there', (tester) async {
    w.places.suggestions['Tao Đàn'] = const [PlaceSuggestion(placeId: 'g1', title: 'Công viên Tao Đàn', subtitle: 'Quận 1')];
    w.places.places['g1'] = const MeetPoint(lat: 10.7745, lng: 106.6926, address: 'Cổng Trương Định, Công viên Tao Đàn');
    await open(tester);
    await tester.tap(find.byKey(const Key('instant-search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('meet-search-field')), 'Tao Đàn');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('meet-result-g1')));
    await tester.pumpAndSettle();
    expect(find.text('Điểm hẹn · Cổng Trương Định, Công viên Tao Đàn'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x (${b.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, b: b, scale: 1.3);
      expect(tester.takeException(), isNull);
    });
  }
}
```

(`InstantBookScreenMarker` is a private-free marker: add `class InstantBookScreenMarker extends StatelessWidget { const InstantBookScreenMarker({super.key}); @override Widget build(BuildContext context) => const SizedBox.shrink(); }` at the end of `instant_book_screen.dart` and put one in the S47 tree, so tests can tell that S47 is gone after paying.)

```dart
// test/features/instant/meet_point_search_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/instant/place_search.dart';

import '../../support/instant_customer_screens.dart';
import '../../support/instant_customer_world.dart';

void main() {
  late InstantCustomerWorld w;
  setUp(() async {
    w = InstantCustomerWorld();
    await w.init();
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(instantCustomerApp(w, location: '/instant'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('instant-search')));
    await tester.pumpAndSettle();
  }

  testWidgets('typing is debounced: one request per pause', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byKey(const Key('meet-search-field')), 'T');
    await tester.enterText(find.byKey(const Key('meet-search-field')), 'Ta');
    await tester.enterText(find.byKey(const Key('meet-search-field')), 'Tao');
    await tester.pump(const Duration(milliseconds: 350));
    expect(w.places.suggestCalls, 1);
  });

  testWidgets('nothing found and errors say what to do', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byKey(const Key('meet-search-field')), 'zzzz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.byKey(const Key('meet-search-empty')), findsOneWidget);
    w.places.fail = true;
    await tester.enterText(find.byKey(const Key('meet-search-field')), 'Tao Đàn');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.byKey(const Key('meet-search-error')), findsOneWidget);
  });

  testWidgets('results show title and area', (tester) async {
    w.places.suggestions['Bến Thành'] = const [PlaceSuggestion(placeId: 'g2', title: 'Chợ Bến Thành', subtitle: 'Quận 1')];
    await openSheet(tester);
    await tester.enterText(find.byKey(const Key('meet-search-field')), 'Bến Thành');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Chợ Bến Thành'), findsOneWidget);
    expect(find.text('Quận 1'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/instant/instant_book_screen_test.dart test/features/instant/meet_point_search_sheet_test.dart`
Expected: FAIL to compile (screen, sheet, guard and the placeholder status screen missing).

- [ ] **Step 3: Implement**

Strings (`lib/l10n/app_vi.arb`, then `flutter gen-l10n`):

```json
  "instantTitle": "Chụp ngay",
  "instantSubtitle": "Nhiếp ảnh gia tới chỗ bạn trong khoảng 30–90 phút",
  "instantPackagePhotos": "{photos} ảnh",
  "@instantPackagePhotos": {"placeholders": {"photos": {"type": "int"}}},
  "instantPackageSemantics": "Gói {duration}, {photos} ảnh, {price}",
  "@instantPackageSemantics": {"placeholders": {"duration": {"type": "String"}, "photos": {"type": "int"}, "price": {"type": "String"}}},
  "instantGenreTitle": "Kiểu chụp",
  "instantMeetPoint": "Điểm hẹn · {address}",
  "@instantMeetPoint": {"placeholders": {"address": {"type": "String"}}},
  "instantSearchAddress": "Tìm địa chỉ",
  "instantSearchHint": "Nhập tên đường, địa điểm",
  "instantSearchEmpty": "Không thấy địa chỉ này. Thử tên khác hoặc kéo bản đồ.",
  "instantSearchError": "Chưa tìm được địa chỉ. Kéo bản đồ để ghim điểm hẹn.",
  "instantLocationHint": "Bật vị trí hoặc tìm địa chỉ để ghim điểm hẹn.",
  "instantNoteLabel": "Ghi chú cho nhiếp ảnh gia",
  "instantNoteHint": "Ví dụ: mình mặc áo dài trắng, đứng cạnh hồ",
  "instantExpandTitle": "Mở rộng tìm kiếm",
  "instantExpandBody": "Tìm cả nhiếp ảnh gia khác ở gần nếu chưa có người nhận",
  "instantEscrow": "Tiền được giữ an toàn và hoàn 100% nếu không có người nhận.",
  "instantTypicalMatch": "Thường có người nhận trong khoảng {minutes} phút.",
  "@instantTypicalMatch": {"placeholders": {"minutes": {"type": "int"}}},
  "instantPay": "Thanh toán {price} và tìm",
  "@instantPay": {"placeholders": {"price": {"type": "String"}}},
  "instantPayNoPrice": "Thanh toán và tìm",
  "instantOpeningPayment": "Đang mở thanh toán",
  "instantPriceChanged": "Giá vừa đổi thành {price}. Kiểm tra rồi bấm lại.",
  "@instantPriceChanged": {"placeholders": {"price": {"type": "String"}}},
  "instantOutsideArea": "Chụp ngay chưa có ở khu vực này.",
  "instantBookRegular": "Đặt lịch thường",
  "instantPaymentUnavailable": "Chưa thanh toán được trong bản này. Thử lại sau.",
  "instantPaymentOpenError": "Chưa mở được thanh toán. Thử lại nhé.",
```

```dart
// lib/features/instant/customer_only.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';

/// `/instant…` is for customers (screens README "Vai trò").
class CustomerOnly extends ConsumerWidget {
  const CustomerOnly({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentProfileProvider).value?.role;
    if (role == null) {
      return const SizedBox.shrink();
    }
    if (role != UserRole.customer) {
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
// lib/features/instant/meet_point_search_sheet.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/instant/place_search.dart';

const _debounce = Duration(milliseconds: 300);

class MeetPointSearchState {
  const MeetPointSearchState({this.query = '', this.results = const [], this.loading = false, this.failed = false, this.searched = false});
  final String query;
  final List<PlaceSuggestion> results;
  final bool loading;
  final bool failed;
  final bool searched;
}

/// One Goong "session" per open sheet; a request only after a 300 ms pause.
class MeetPointSearchController extends Notifier<MeetPointSearchState> {
  Timer? _timer;
  late final String _session = List.generate(16, (_) => Random.secure().nextInt(36).toRadixString(36)).join();
  LatLng? near;

  @override
  MeetPointSearchState build() {
    ref.onDispose(() => _timer?.cancel());
    return const MeetPointSearchState();
  }

  void query(String text) {
    _timer?.cancel();
    state = MeetPointSearchState(query: text, results: state.results);
    if (text.trim().length < 2) {
      state = MeetPointSearchState(query: text);
      return;
    }
    _timer = Timer(_debounce, () => _run(text));
  }

  Future<void> _run(String text) async {
    state = MeetPointSearchState(query: text, results: state.results, loading: true);
    try {
      final r = await ref.read(placeSearchProvider).suggest(text, near: near, sessionToken: _session);
      if (state.query == text) {
        state = MeetPointSearchState(query: text, results: r, searched: true);
      }
    } on PlaceSearchException {
      state = MeetPointSearchState(query: text, failed: true, searched: true);
    }
  }

  Future<MeetPoint?> choose(PlaceSuggestion s) async {
    try {
      return await ref.read(placeSearchProvider).details(s.placeId, sessionToken: _session);
    } on PlaceSearchException {
      state = MeetPointSearchState(query: state.query, failed: true, searched: true);
      return null;
    }
  }
}

final meetPointSearchProvider = NotifierProvider.autoDispose<MeetPointSearchController, MeetPointSearchState>(
  MeetPointSearchController.new,
);

Future<MeetPoint?> showMeetPointSearch(BuildContext context, {LatLng? near}) => showAppSheet<MeetPoint>(
  context,
  builder: (_) => ScreenCode(ScreenCodes.instantRequest, label: 'search', child: _MeetPointSearchSheet(near: near)),
);

class _MeetPointSearchSheet extends ConsumerStatefulWidget {
  const _MeetPointSearchSheet({this.near});
  final LatLng? near;

  @override
  ConsumerState<_MeetPointSearchSheet> createState() => _MeetPointSearchSheetState();
}

class _MeetPointSearchSheetState extends ConsumerState<_MeetPointSearchSheet> {
  @override
  void initState() {
    super.initState();
    ref.read(meetPointSearchProvider.notifier).near = widget.near;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = ref.watch(meetPointSearchProvider);
    final ctl = ref.read(meetPointSearchProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s2, AppSpace.s4, AppSpace.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('meet-search-field'),
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: l.instantSearchAddress,
              hintText: l.instantSearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
            onChanged: ctl.query,
          ),
          const SizedBox(height: AppSpace.s2),
          if (s.failed)
            Padding(
              key: const Key('meet-search-error'),
              padding: const EdgeInsets.all(AppSpace.s3),
              child: Text(l.instantSearchError),
            )
          else if (s.searched && s.results.isEmpty)
            Padding(
              key: const Key('meet-search-empty'),
              padding: const EdgeInsets.all(AppSpace.s3),
              child: Text(l.instantSearchEmpty),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in s.results)
                    ListTile(
                      key: Key('meet-result-${r.placeId}'),
                      leading: const Icon(Icons.place_outlined),
                      title: Text(r.title),
                      subtitle: r.subtitle == null ? null : Text(r.subtitle!),
                      onTap: () async {
                        final p = await ctl.choose(r);
                        if (p != null && context.mounted) {
                          Navigator.of(context).pop(p);
                        }
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

```dart
// lib/features/instant/instant_book_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_labels.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/features/instant/customer_only.dart';
import 'package:photobooking/features/instant/instant_book_controller.dart';
import 'package:photobooking/features/instant/instant_customer_rules.dart';
import 'package:photobooking/features/instant/instant_draft.dart';
import 'package:photobooking/features/instant/meet_point_search_sheet.dart';
import 'package:photobooking/features/instant_common/instant_errors.dart';

/// S47: package, kind of shoot, meet point, "Mở rộng tìm kiếm", fixed price.
class InstantBookScreen extends ConsumerStatefulWidget {
  const InstantBookScreen({super.key});

  @override
  ConsumerState<InstantBookScreen> createState() => _InstantBookScreenState();
}

class _InstantBookScreenState extends ConsumerState<InstantBookScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(instantBookProvider.notifier).start();
      }
    });
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _pay() async {
    final l = context.l10n;
    final r = await ref.read(instantBookProvider.notifier).submit();
    if (!mounted) {
      return;
    }
    switch (r) {
      case InstantSubmitNeedsPhone():
        context.push('/profile/phone?returnTo=${Uri.encodeComponent('/instant')}');
      case InstantSubmitStarted(:final requestId):
        context.go('/instant/$requestId');
      case InstantSubmitPriceChanged(:final amountVnd):
        _snack(l.instantPriceChanged(formatMoney(amountVnd)));
      case InstantSubmitFailed(:final error):
        if (error == DispatchError.outsideServiceArea) {
          return;
        }
        _snack(switch (error) {
          DispatchError.disabled => l.instantPaymentUnavailable,
          DispatchError.unknown => l.instantPaymentOpenError,
          _ => instantErrorText(error, l),
        });
    }
  }

  Future<void> _search(LatLng? near) async {
    final p = await showMeetPointSearch(context, near: near);
    if (p != null && mounted) {
      await ref.read(instantBookProvider.notifier).choosePlace(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final s = ref.watch(instantBookProvider);
    final draft = ref.watch(instantDraftProvider);
    ref.watch(currentContactProvider);
    final ctl = ref.read(instantBookProvider.notifier);
    final draftCtl = ref.read(instantDraftProvider.notifier);
    final quote = s.quote;
    final pkg = quote?.byCode(draft.package);
    final meet = draft.meetPoint;
    final muted = dark ? AppColorsDark.foregroundSecondary : AppColors.foregroundSecondary;
    final typical = quote?.typicalMatchMinutes;

    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.instantTitle),
            Text(l.instantSubtitle, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.s4),
          children: [
            const InstantBookScreenMarker(),
            Material(
              color: dark ? AppColorsDark.surfaceMuted : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: InkWell(
                key: const Key('instant-search'),
                borderRadius: BorderRadius.circular(AppRadius.full),
                onTap: () => _search(meet?.latLng),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s3),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: muted),
                      const SizedBox(width: AppSpace.s2),
                      Expanded(child: Text(l.instantSearchAddress, style: theme.textTheme.bodyMedium?.copyWith(color: muted))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: SizedBox(
                key: const Key('instant-map'),
                height: 180,
                child: AppMap(
                  center: meet?.latLng ?? instantDefaultCenter,
                  semanticsLabel: l.instantMapLabel,
                  cameraToken: s.cameraToken,
                  centerPinLabel: l.instantMeetPoint(meet?.address ?? l.instantMeetPointPinned),
                  onCameraIdle: ctl.moveMeetPoint,
                  onMyLocation: ctl.useMyLocation,
                ),
              ),
            ),
            if (s.locationDenied)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s2),
                child: Text(l.instantLocationHint, style: theme.textTheme.bodySmall),
              ),
            if (s.outsideArea)
              Padding(
                key: const Key('instant-outside'),
                padding: const EdgeInsets.only(top: AppSpace.s3),
                child: Row(
                  children: [
                    Expanded(child: Text(l.instantOutsideArea)),
                    TextButton(
                      key: const Key('instant-regular'),
                      onPressed: () => context.go('/action'),
                      child: Text(l.instantBookRegular),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpace.s4),
            if (quote == null && s.loadingQuote)
              const AppSkeleton.box(height: 96)
            else if (quote != null)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, p) in quote.packages.indexed) ...[
                      if (i > 0) const SizedBox(width: AppSpace.s2),
                      Expanded(
                        child: _PackageTile(
                          package: p,
                          selected: p.code == draft.package,
                          onTap: () => draftCtl.setPackage(p.code),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: AppSpace.s4),
            Semantics(header: true, child: Text(l.instantGenreTitle, style: theme.textTheme.titleSmall)),
            const SizedBox(height: AppSpace.s2),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final g in InstantGenre.values) ...[
                    AppChip(
                      key: Key('instant-genre-${g.code}'),
                      label: genreLabel(g, l),
                      selected: draft.genre == g,
                      onChanged: (_) => draftCtl.setGenre(g),
                    ),
                    const SizedBox(width: AppSpace.s2),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s2),
            CheckboxListTile(
              key: const Key('instant-expand'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: draft.expand,
              onChanged: (v) => draftCtl.setExpand(v ?? false),
              title: Text(l.instantExpandTitle),
              subtitle: Text(l.instantExpandBody),
            ),
            TextFormField(
              key: const Key('instant-note'),
              initialValue: draft.note,
              maxLength: 140,
              onChanged: draftCtl.setNote,
              decoration: InputDecoration(labelText: l.instantNoteLabel, hintText: l.instantNoteHint),
            ),
            const SizedBox(height: AppSpace.s2),
            Row(
              key: const Key('instant-escrow'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, size: 18, color: muted),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: Text(
                    typical == null ? l.instantEscrow : '${l.instantEscrow} ${l.instantTypicalMatch(typical)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: AppButton.primary(
            pkg == null ? l.instantPayNoPrice : l.instantPay(formatMoney(pkg.priceVnd)),
            key: const Key('instant-pay'),
            loading: s.submitting,
            onPressed: pkg != null && meet != null && !s.outsideArea ? _pay : null,
          ),
        ),
      ),
    );

    return CustomerOnly(
      child: ScreenCode(
        ScreenCodes.instantRequest,
        child: Stack(
          children: [
            scaffold,
            if (s.submitting)
              Positioned.fill(
                key: const Key('instant-paying'),
                child: ColoredBox(
                  color: AppColors.overlay,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ApertureLoader(semanticsLabel: l.instantOpeningPayment),
                        const SizedBox(height: AppSpace.s3),
                        Text(l.instantOpeningPayment, style: theme.textTheme.titleSmall?.copyWith(color: AppColors.foregroundInverse)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({required this.package, required this.selected, required this.onTap});
  final InstantPackage package;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = dark ? AppColorsDark.primary : AppColors.primary;
    return Semantics(
      key: Key('instant-package-${package.code.code}'),
      button: true,
      selected: selected,
      label: l.instantPackageSemantics(packageLabel(package.code), package.photos, formatMoney(package.priceVnd)),
      child: ExcludeSemantics(
        child: Material(
          color: selected ? (dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle) : (dark ? AppColorsDark.surfaceMuted : AppColors.surface),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: selected ? primary : (dark ? AppColorsDark.border : AppColors.border), width: selected ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  children: [
                    Text(packageLabel(package.code), style: theme.textTheme.titleSmall),
                    Text(l.instantPackagePhotos(package.photos), style: theme.textTheme.bodySmall),
                    const SizedBox(height: AppSpace.s1),
                    Text(
                      formatMoney(package.priceVnd, short: true),
                      style: theme.textTheme.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets tests tell that S47 is (or is no longer) on screen.
class InstantBookScreenMarker extends StatelessWidget {
  const InstantBookScreenMarker({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

(`formatMoney(1190000, short: true)` is `1,2M` per plan 3a2's rounding; the mock's `1,19M` is a mock detail, the tiles use the shared formatter.)

Create the placeholder `lib/features/instant/instant_request_screen.dart` (Task 7 replaces it):

```dart
import 'package:flutter/material.dart';

class InstantRequestScreen extends StatelessWidget {
  const InstantRequestScreen({super.key, required this.requestId, this.openCancel = false});
  final String requestId;
  final bool openCancel;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

`lib/app/router.dart`: import `instant_book_screen.dart` and `instant_request_screen.dart`, and add next to the other top-level routes:

```dart
      GoRoute(
        path: '/instant',
        builder: (_, _) => const InstantBookScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => InstantRequestScreen(requestId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'cancel',
                builder: (_, state) => InstantRequestScreen(requestId: state.pathParameters['id']!, openCancel: true),
              ),
            ],
          ),
        ],
      ),
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/features/instant && flutter analyze`
Expected: PASS (12 + 3 new tests).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/instant lib/app/router.dart lib/l10n test/support test/features/instant
git commit -m "feat(instant): S47 Chụp ngay with packages, meet-point map and Goong search

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: `/instant/:id` status switch, S48 and the customer S55

**Files:**
- Create: `lib/features/instant/instant_customer_actions.dart`, `lib/features/instant/views/instant_pill.dart`, `lib/features/instant/views/instant_searching_view.dart`, `lib/features/instant/views/instant_tracking_view.dart`, `lib/features/instant/views/instant_shoot_view.dart`, `lib/features/instant/views/instant_no_match_view.dart`, `lib/features/instant/views/instant_closed_view.dart` (the last four as placeholders, replaced in Tasks 8–10), `test/features/instant/instant_request_screen_test.dart`
- Modify (replace the placeholder): `lib/features/instant/instant_request_screen.dart`; modify `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `instantRequestProvider` (I4), `showInstantCancelSheet`/`InstantCancelRole` (I4 Task 11), `SearchPulse` (Task 4), `ApertureLoader`, `TickingBuilder`, `clockProvider`, `instantDraftProvider`, `customerCanCancel`, `searchElapsed`, `formatClock`, `genreLabel`, `packageLabel`, `instantNotifierProvider`, `pushMessagesProvider`, `ErrorState`, `EmptyState`.
- Produces:
  - `class InstantCustomerActions { Future<CancelQuote> quoteCancel(String id); Future<CancelQuote> cancel(String id); Future<void> confirmComplete(String id); }`, `instantCustomerActionsProvider`.
  - `enum InstantPillTone { waiting, good }`, `const InstantPill(String text, {Key? key, InstantPillTone tone = InstantPillTone.good})`.
  - `const InstantRequestScreen({super.key, required String requestId, bool openCancel = false})` — loading → `ApertureLoader`; missing → message; `pending_payment` → `InstantPaymentPendingView` (S48 · `payment`); `payment_failed` → `InstantPaymentFailedView` (S47 · `payment_failed`, "Thử lại" back to S47 with the draft); `searching` → `InstantSearchingView` (S48); `assigned`/`en_route`/`arrived` → `InstantTrackingView` (S49); `in_progress`/`completed` → `InstantShootView` (S50); `no_match` → `InstantNoMatchView` (S51); the other final states → `InstantClosedView`. `openCancel` (route `/instant/:id/cancel`) opens S55 once the request can be cancelled.
  - `const InstantSearchingView({super.key, required InstantRequestView view, required VoidCallback onCancel})`. Keys: `searching-meta`, `searching-card`, `instant-cancel`.
  - Placeholder constructors for Tasks 8–10: `InstantTrackingView({required InstantRequestView view, required VoidCallback onCancel})`, `InstantShootView({required InstantRequestView view})`, `InstantNoMatchView({required InstantRequestView view})`, `InstantClosedView({required InstantRequestView view})`.
  - l10n listed in Step 3.

Layout (mock S48): "Đang tìm nhiếp ảnh gia" centred, no back arrow; `SearchPulse` (active only in this view, so it stops as soon as the status changes); "Đang mời người phù hợp gần bạn"; "Đã tìm 1:12 · bán kính 3 km · vòng ưu tiên" (one tick per second, radius and round from the mirror); the request card "Chân dung · 1 giờ" / "Công viên Tao Đàn · 690.000₫ đã thanh toán" with the "Đang tìm" pill; the note that the app may be left and the 10-minute refund; the red text "Huỷ yêu cầu" (→ S55). On first show it asks for notification permission (the "assigned" push), once.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/instant/instant_request_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/instant_draft.dart';
import 'package:photobooking/features/instant/instant_request_screen.dart';

import 'package:photobooking/data/user/user_profile.dart';

import '../../support/instant_customer_screens.dart';
import '../../support/instant_customer_world.dart';

void main() {
  late InstantCustomerWorld w;
  setUp(() async {
    w = InstantCustomerWorld();
    await w.init();
  });

  Future<void> open(WidgetTester tester, {String at = '/instant/RQ1', Brightness b = Brightness.dark, double scale = 1}) async {
    await tester.pumpWidget(instantCustomerApp(w, location: at, brightness: b, textScale: scale));
    await tester.pump();
    await tester.pump();
  }

  Future<void> tick(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      w.now = w.now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('no such request: says so', (tester) async {
    await open(tester);
    expect(find.text('Không tìm thấy yêu cầu này.'), findsOneWidget);
  });

  testWidgets('waiting for the gateway: the aperture wait; paid → S48', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.pendingPayment));
    await open(tester);
    expect(find.text('Đang chờ xác nhận thanh toán'), findsWidgets);
    expect(find.byType(ApertureLoader), findsOneWidget);
    w.mirror.setRequest('RQ1', w.request(InstantStatus.searching));
    await tester.pump();
    expect(find.byType(SearchPulse), findsOneWidget);
  });

  testWidgets('payment failed: "Thử lại" goes back to S47 with the choices kept', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.paymentFailed));
    await open(tester);
    expect(find.text('Thanh toán chưa thành công'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chụp ngay'), findsOneWidget);
  });

  testWidgets('S48: pulse, elapsed time to the second, radius and round, the paid request, red cancel', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.searching));
    await open(tester);
    final c = ProviderScope.containerOf(tester.element(find.byType(InstantRequestScreen)));
    c.read(instantDraftProvider.notifier)
      ..setMeetPoint(w.meet)
      ..setLastRequest('RQ1');
    await tester.pump();
    expect(find.text('Đang tìm nhiếp ảnh gia'), findsOneWidget);
    expect(find.text('Đang mời người phù hợp gần bạn'), findsOneWidget);
    expect(find.text('Đã tìm 1:12 · bán kính 3 km · vòng ưu tiên'), findsOneWidget);
    await tick(tester, 1);
    expect(find.text('Đã tìm 1:13 · bán kính 3 km · vòng ưu tiên'), findsOneWidget);
    expect(find.text('Chân dung · 1 giờ'), findsOneWidget);
    expect(find.text('Công viên Tao Đàn, Quận 1 · 690.000₫ đã thanh toán'), findsOneWidget);
    expect(find.text('Đang tìm'), findsOneWidget);
    expect(find.text('Huỷ yêu cầu'), findsOneWidget);
    expect(find.byType(CtaSurface), findsOneWidget, reason: 'only the aperture disc; no gradient button');
    expect(w.notifier.permissionRequests, 1);
    expect(w.push.permissionRequests, 1);
  });

  testWidgets('round 2 reads "vòng mở rộng"', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.searching, round: 2, radiusKm: 10, expand: true));
    await open(tester);
    expect(find.text('Đã tìm 1:12 · bán kính 10 km · vòng mở rộng'), findsOneWidget);
  });

  testWidgets('someone accepted: the pulse and the clock stop at once', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.searching));
    await open(tester);
    expect(TickingBuilder.debugActiveCount, 1);
    w.mirror.setRequest('RQ1', w.request(InstantStatus.assigned));
    await tester.pump();
    expect(find.byType(SearchPulse), findsNothing);
  });

  testWidgets('S55 from S48: the dry run first, then the red confirmation cancels', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.searching));
    await open(tester);
    await tester.tap(find.byKey(const Key('instant-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Đang tìm, hoặc 2 phút đầu sau khi có người nhận (bây giờ)'), findsOneWidget);
    expect(find.text('Bạn sẽ được hoàn 690.000₫.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-confirm')));
    await tester.pumpAndSettle();
    expect(w.booking.cancelCalls, ['quote RQ1', 'cancel RQ1']);
  });

  testWidgets('/instant/:id/cancel opens S55 directly', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.searching));
    await open(tester, at: '/instant/RQ1/cancel');
    await tester.pumpAndSettle();
    expect(find.text('Huỷ chụp ngay?'), findsOneWidget);
  });

  testWidgets('a photographer opening a customer route is sent home', (tester) async {
    final p = InstantCustomerWorld(role: UserRole.photographer);
    await p.init();
    p.mirror.setRequest('RQ1', p.request(InstantStatus.searching));
    await tester.pumpWidget(instantCustomerApp(p, location: '/instant/RQ1'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('S48 fits 320dp at 1.3x (${b.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      w.mirror.setRequest('RQ1', w.request(InstantStatus.searching));
      await open(tester, b: b, scale: 1.3);
      expect(tester.takeException(), isNull);
    });
  }
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/instant/instant_request_screen_test.dart`
Expected: FAIL (placeholder screen).

- [ ] **Step 3: Implement**

Strings (`lib/l10n/app_vi.arb`, then `flutter gen-l10n`):

```json
  "instantSearchingTitle": "Đang tìm nhiếp ảnh gia",
  "instantSearchingHeading": "Đang mời người phù hợp gần bạn",
  "instantSearchingMeta": "Đã tìm {elapsed} · bán kính {radius} km · {round}",
  "@instantSearchingMeta": {"placeholders": {"elapsed": {"type": "String"}, "radius": {"type": "int"}, "round": {"type": "String"}}},
  "instantSearchingMetaShort": "Đã tìm {elapsed}",
  "@instantSearchingMetaShort": {"placeholders": {"elapsed": {"type": "String"}}},
  "instantRoundPriority": "vòng ưu tiên",
  "instantRoundExpanded": "vòng mở rộng",
  "instantRequestSummary": "{genre} · {duration}",
  "@instantRequestSummary": {"placeholders": {"genre": {"type": "String"}, "duration": {"type": "String"}}},
  "instantPaidAt": "{place} · {amount} đã thanh toán",
  "@instantPaidAt": {"placeholders": {"place": {"type": "String"}, "amount": {"type": "String"}}},
  "instantPaid": "{amount} đã thanh toán",
  "@instantPaid": {"placeholders": {"amount": {"type": "String"}}},
  "instantSearchingBadge": "Đang tìm",
  "instantSearchingNote": "Bạn có thể thoát app; chúng tôi báo ngay khi có người nhận. Quá 10 phút chưa có ai, tiền tự hoàn đủ.",
  "instantCancelRequest": "Huỷ yêu cầu",
  "instantWaitingPayment": "Đang chờ xác nhận thanh toán",
  "instantPaymentFailedTitle": "Thanh toán chưa thành công",
  "instantPaymentFailedBody": "Chưa trừ tiền. Lựa chọn của bạn vẫn còn, thử lại nhé.",
  "instantTryAgain": "Thử lại",
  "instantRequestMissing": "Không tìm thấy yêu cầu này.",
```

(The S48 test expects `find.text('Đang tìm')` once: the pill. The pulse's label "Đang tìm" is a `Semantics` label, not a `Text`.)

```dart
// lib/features/instant/instant_customer_actions.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/instant/instant_booking_repository.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';

/// What the customer may do to a request; the result shows up in the mirror.
class InstantCustomerActions {
  const InstantCustomerActions(this._repo);
  final InstantBookingRepository _repo;

  Future<CancelQuote> quoteCancel(String id) => _repo.cancel(id, dryRun: true);
  Future<CancelQuote> cancel(String id) => _repo.cancel(id, dryRun: false);
  Future<void> confirmComplete(String id) => _repo.confirmComplete(id);
}

final instantCustomerActionsProvider = Provider<InstantCustomerActions>(
  (ref) => InstantCustomerActions(ref.watch(instantBookingRepositoryProvider)),
);
```

```dart
// lib/features/instant/views/instant_pill.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';

enum InstantPillTone { waiting, good }

/// "Đang tìm", "Đang đến", "Đang chụp": text on a soft fill (not colour alone).
class InstantPill extends StatelessWidget {
  const InstantPill(this.text, {super.key, this.tone = InstantPillTone.good});
  final String text;
  final InstantPillTone tone;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: tone == InstantPillTone.waiting ? AppColors.warningSubtle : AppColors.successSubtle,
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3, vertical: AppSpace.s1),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.foreground, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
```

```dart
// lib/features/instant/views/instant_searching_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/instant/instant_labels.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/instant_customer_rules.dart';
import 'package:photobooking/features/instant/instant_draft.dart';
import 'package:photobooking/features/instant/views/instant_pill.dart';
import 'package:photobooking/features/instant_common/instant_services.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// S48: the search, with a clock and a way out.
class InstantSearchingView extends ConsumerStatefulWidget {
  const InstantSearchingView({super.key, required this.view, required this.onCancel});
  final InstantRequestView view;
  final VoidCallback onCancel;

  @override
  ConsumerState<InstantSearchingView> createState() => _InstantSearchingViewState();
}

class _InstantSearchingViewState extends ConsumerState<InstantSearchingView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askNotifications());
  }

  /// "Chúng tôi báo ngay khi có người nhận" needs notifications (Android 13+, iOS).
  Future<void> _askNotifications() async {
    try {
      final n = ref.read(instantNotifierProvider);
      await n.init(lookupAppLocalizations(const Locale('vi')));
      await n.requestPermissions();
      await ref.read(pushMessagesProvider).requestPermission();
    } on Object {
      // No plugin (tests on desktop): nothing to ask.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final v = widget.view;
    final draft = ref.watch(instantDraftProvider);
    final place = v.meetPoint?.address ?? (draft.lastRequestId == v.id ? draft.meetPoint?.address : null);
    final money = formatMoney(v.amountVnd);
    final round = v.round == 2 ? l.instantRoundExpanded : l.instantRoundPriority;
    return ScreenCode(
      ScreenCodes.instantSearching,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(automaticallyImplyLeading: false, centerTitle: true, title: Text(l.instantSearchingTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s5),
            children: [
              Center(child: SearchPulse(active: true, semanticsLabel: l.instantSearching)),
              const SizedBox(height: AppSpace.s4),
              Text(l.instantSearchingHeading, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpace.s1),
              TickingBuilder(
                active: true,
                builder: (_) {
                  final elapsed = formatClock(searchElapsed(v, ref.read(clockProvider)()));
                  return Text(
                    v.radiusKm == null ? l.instantSearchingMetaShort(elapsed) : l.instantSearchingMeta(elapsed, v.radiusKm!, round),
                    key: const Key('searching-meta'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                  );
                },
              ),
              const SizedBox(height: AppSpace.s5),
              DecoratedBox(
                key: const Key('searching-card'),
                decoration: BoxDecoration(
                  color: dark ? AppColorsDark.surfaceMuted : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.instantRequestSummary(genreLabel(v.genre, l), packageLabel(v.packageCode)), style: theme.textTheme.titleSmall),
                            Text(place == null ? l.instantPaid(money) : l.instantPaidAt(place, money), style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpace.s2),
                      InstantPill(l.instantSearchingBadge, tone: InstantPillTone.waiting),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s4),
              Text(l.instantSearchingNote, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s3),
            child: TextButton(
              key: const Key('instant-cancel'),
              onPressed: widget.onCancel,
              child: Text(l.instantCancelRequest, style: TextStyle(color: dark ? AppColorsDark.destructive : AppColors.destructive)),
            ),
          ),
        ),
      ),
    );
  }
}

/// S48 before the gateway confirmed: the aperture wait, nothing to do.
class InstantPaymentPendingView extends StatelessWidget {
  const InstantPaymentPendingView({super.key, required this.view});
  final InstantRequestView view;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ScreenCode(
      ScreenCodes.instantSearching,
      label: 'payment',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ApertureLoader(semanticsLabel: l.instantWaitingPayment),
              const SizedBox(height: AppSpace.s3),
              Text(l.instantWaitingPayment, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// The gateway refused or was cancelled (spec §10): back to S47, choices kept.
class InstantPaymentFailedView extends StatelessWidget {
  const InstantPaymentFailedView({super.key, required this.view});
  final InstantRequestView view;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ScreenCode(
      ScreenCodes.instantRequest,
      label: 'payment_failed',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(),
        body: EmptyState(
          key: const Key('payment-failed'),
          title: l.instantPaymentFailedTitle,
          body: l.instantPaymentFailedBody,
          actionLabel: l.instantTryAgain,
          onAction: () => context.go('/instant'),
        ),
      ),
    );
  }
}
```

Placeholders (replaced in Tasks 8, 9, 10):

```dart
// lib/features/instant/views/instant_tracking_view.dart
import 'package:flutter/material.dart';

import 'package:photobooking/data/instant/instant_models.dart';

class InstantTrackingView extends StatelessWidget {
  const InstantTrackingView({super.key, required this.view, required this.onCancel});
  final InstantRequestView view;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
```

and the same shape for `InstantShootView({required this.view})` in `instant_shoot_view.dart`, `InstantNoMatchView({required this.view})` in `instant_no_match_view.dart`, `InstantClosedView({required this.view})` in `instant_closed_view.dart`.

```dart
// lib/features/instant/instant_request_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/instant/customer_only.dart';
import 'package:photobooking/features/instant/instant_customer_actions.dart';
import 'package:photobooking/features/instant/instant_customer_rules.dart';
import 'package:photobooking/features/instant/views/instant_closed_view.dart';
import 'package:photobooking/features/instant/views/instant_no_match_view.dart';
import 'package:photobooking/features/instant/views/instant_searching_view.dart';
import 'package:photobooking/features/instant/views/instant_shoot_view.dart';
import 'package:photobooking/features/instant/views/instant_tracking_view.dart';
import 'package:photobooking/features/instant_common/instant_cancel_sheet.dart';

/// `/instant/:id`: one route, the screen follows the mirror's status
/// (spec §8). Each state carries its own screen code.
class InstantRequestScreen extends ConsumerStatefulWidget {
  const InstantRequestScreen({super.key, required this.requestId, this.openCancel = false});
  final String requestId;
  final bool openCancel;

  @override
  ConsumerState<InstantRequestScreen> createState() => _InstantRequestScreenState();
}

class _InstantRequestScreenState extends ConsumerState<InstantRequestScreen> {
  bool _cancelShown = false;

  Future<void> _cancel(InstantRequestView v) async {
    final actions = ref.read(instantCustomerActionsProvider);
    await showInstantCancelSheet(
      context,
      role: InstantCancelRole.customer,
      quote: () => actions.quoteCancel(v.id),
      confirm: () => actions.cancel(v.id),
      photographerName: v.photographer?.displayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(instantRequestProvider(widget.requestId));
    final v = async.value;
    if (widget.openCancel && !_cancelShown && v != null && customerCanCancel(v.status)) {
      _cancelShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _cancel(v);
        }
      });
    }
    final Widget child;
    if (async.isLoading && !async.hasValue) {
      child = ScreenCode(
        ScreenCodes.instantSearching,
        label: 'loading',
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: ApertureLoader(semanticsLabel: l.instantLoading)),
        ),
      );
    } else if (async.hasError || v == null) {
      child = ScreenCode(
        ScreenCodes.instantSearching,
        label: 'missing',
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(),
          body: ErrorState(
            message: async.hasError ? l.instantActionError : l.instantRequestMissing,
            onRetry: async.hasError ? () => ref.invalidate(instantRequestProvider(widget.requestId)) : null,
          ),
        ),
      );
    } else {
      child = switch (v.status) {
        InstantStatus.pendingPayment => InstantPaymentPendingView(view: v),
        InstantStatus.paymentFailed => InstantPaymentFailedView(view: v),
        InstantStatus.searching => InstantSearchingView(view: v, onCancel: () => _cancel(v)),
        InstantStatus.assigned ||
        InstantStatus.enRoute ||
        InstantStatus.arrived => InstantTrackingView(view: v, onCancel: () => _cancel(v)),
        InstantStatus.inProgress || InstantStatus.completed => InstantShootView(view: v),
        InstantStatus.noMatch => InstantNoMatchView(view: v),
        InstantStatus.cancelledByCustomer ||
        InstantStatus.noShowCustomer ||
        InstantStatus.disputed => InstantClosedView(view: v),
      };
    }
    return CustomerOnly(child: child);
  }
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter gen-l10n && flutter test test/features/instant && flutter analyze`
Expected: PASS (11 new tests).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/instant lib/l10n test/features/instant
git commit -m "feat(instant): /instant/:id status switch, S48 search with pulse and clock, customer cancel sheet

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: S49 "Đang đến" (map, ETA, grace, stale position, late, contact)

**Files:**
- Modify (replace the placeholder): `lib/features/instant/views/instant_tracking_view.dart`; modify `lib/l10n/app_vi.arb`
- Create: `test/features/instant/instant_tracking_view_test.dart`

**Interfaces:**
- Consumes: `instantTrackProvider` (I4), `AppMap`/`MapMarker`, `AppAvatar` (3b2), `VerifiedName`, `PhotographerContactAction` + `ContactDialStyle.labeled` (2b), `ContactSubject.instant` (I4), `TickingBuilder`, `graceLeft`, `trackStale`, `photographerLate`, `formatClock`, `InstantPill`.
- Produces: `const InstantTrackingView({super.key, required InstantRequestView view, required VoidCallback onCancel})` (S49). Keys: `tracking-map`, `tracking-headline`, `tracking-meta`, `tracking-stale`, `tracking-chat`, `instant-cancel`. l10n listed in Step 3.

Layout (mock S49): the 250dp map edge to edge (pins "Bạn" at the meet point and "Minh Trí · 9 phút" at the photographer's last position; the photographer pin glides between points, jumps under reduced motion; "Về vị trí của tôi" refits; while there is no position, only "Bạn"); the photographer card (avatar, name with the verified mark, "★ 4,9 · 112 buổi · đến trong khoảng 9 phút", "(ước tính)" when the ETA is estimated, pill "Đang đến" / "Đã đến"); the headline "Minh Trí đã nhận · đến trong khoảng 9 phút" or "Đã đến điểm hẹn"; "Đang chờ cập nhật vị trí" when no position came for 3 minutes; the note to compare the avatar on meeting; outline "Nhắn tin" and the labelled contact dial (unlocked: the request is paid); the red cancel text: "Huỷ (miễn phí thêm 1:40)" during the grace period, "Huỷ miễn phí vì nhiếp ảnh gia trễ" 15 minutes past the first ETA, otherwise "Huỷ yêu cầu". One clock: once a second during the grace period, every 15 s otherwise (stale check), none once arrived.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/instant/instant_tracking_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/contact/contact_action.dart';

import '../../support/instant_customer_screens.dart';
import '../../support/instant_customer_world.dart';

void main() {
  late InstantCustomerWorld w;
  setUp(() async {
    w = InstantCustomerWorld();
    await w.init();
  });

  Future<void> open(WidgetTester tester, {Brightness b = Brightness.dark, double scale = 1}) async {
    await tester.pumpWidget(instantCustomerApp(w, location: '/instant/RQ1', brightness: b, textScale: scale));
    await tester.pump();
    await tester.pump();
  }

  Future<void> tick(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      w.now = w.now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('map with labelled pins, the card, ETA, contact unlocked', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.enRoute));
    w.mirror.setTrack('RQ1', w.track());
    await open(tester);
    expect(find.byKey(const Key('fake-map')), findsOneWidget);
    expect(w.map.last!.markers.map((m) => m.label), ['Bạn', 'Minh Trí · 9 phút']);
    expect(w.map.last!.fitMarkers, isTrue);
    expect(find.text('Minh Trí đã nhận · đến trong khoảng 9 phút'), findsOneWidget);
    expect(find.text('★ 4,9 · 112 buổi · đến trong khoảng 9 phút'), findsOneWidget);
    expect(find.text('Đang đến'), findsOneWidget);
    expect(find.byType(PhotographerContactAction), findsOneWidget);
    expect(find.byType(CtaSurface), findsNothing, reason: 'S49 has no primary action');
    await tester.tap(find.byKey(const Key('tracking-chat')));
    await tester.pumpAndSettle();
    expect(find.text('chat RQ1'), findsOneWidget);
  });

  testWidgets('a new position moves the photographer pin (the engine glides it)', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.enRoute));
    w.mirror.setTrack('RQ1', w.track(northMeters: 900));
    await open(tester);
    final before = w.map.last!.markers.last.at;
    w.mirror.setTrack('RQ1', w.track(northMeters: 600));
    await tester.pump();
    expect(w.map.last!.markers.last.at, isNot(before));
    expect(w.map.last!.markerAnimation, greaterThan(Duration.zero));
  });

  testWidgets('estimated ETA says so', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.enRoute, etaEstimated: true));
    await open(tester);
    expect(find.text('★ 4,9 · 112 buổi · đến trong khoảng 9 phút (ước tính)'), findsOneWidget);
  });

  testWidgets('grace period: the free-cancel countdown ticks to the second, then plain cancel', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.assigned, graceEndsAt: w.now.add(const Duration(seconds: 100))));
    await open(tester);
    expect(find.text('Huỷ (miễn phí thêm 1:40)'), findsOneWidget);
    await tick(tester, 1);
    expect(find.text('Huỷ (miễn phí thêm 1:39)'), findsOneWidget);
    await tick(tester, 100);
    expect(find.text('Huỷ yêu cầu'), findsOneWidget);
  });

  testWidgets('no position for over 3 minutes: "Đang chờ cập nhật vị trí"', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.enRoute));
    w.mirror.setTrack('RQ1', w.track(age: const Duration(minutes: 4)));
    await open(tester);
    expect(find.byKey(const Key('tracking-stale')), findsOneWidget);
    expect(find.text('Đang chờ cập nhật vị trí'), findsOneWidget);
  });

  testWidgets('15 minutes past the first ETA: free cancel', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.enRoute, assignedAt: w.now.subtract(const Duration(minutes: 25))));
    w.mirror.setTrack('RQ1', w.track());
    await open(tester);
    expect(find.text('Huỷ miễn phí vì nhiếp ảnh gia trễ'), findsOneWidget);
  });

  testWidgets('cancel after the grace period shows the 80 % refund and the travel fee', (tester) async {
    w.booking.cancelQuote = const CancelQuote(rule: CancelRule.enRouteFee, refundVnd: 552000, photographerVnd: 138000, platformVnd: 0);
    w.mirror.setRequest('RQ1', w.request(InstantStatus.enRoute));
    await open(tester);
    await tester.tap(find.byKey(const Key('instant-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Bạn sẽ được hoàn 552.000₫; 138.000₫ là phí đi lại trả cho Minh Trí.'), findsOneWidget);
    expect(find.text('Huỷ và hoàn 552.000₫'), findsOneWidget);
  });

  testWidgets('arrived: "Đã đến điểm hẹn", no photographer pin, no clock', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.arrived));
    await open(tester);
    expect(find.text('Đã đến điểm hẹn'), findsOneWidget);
    expect(w.map.last!.markers.map((m) => m.label), ['Bạn']);
    expect(TickingBuilder.debugActiveCount, 0);
    expect(w.mirror.listenersOf('instant_tracks/RQ1'), 0, reason: 'no track listener once arrived');
  });

  testWidgets('the track listener closes when the screen does', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.enRoute));
    await open(tester);
    expect(w.mirror.listenersOf('instant_tracks/RQ1'), 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(w.mirror.listenersOf('instant_tracks/RQ1'), 0);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x (${b.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      w.mirror.setRequest('RQ1', w.request(InstantStatus.enRoute, graceEndsAt: w.now.add(const Duration(seconds: 100))));
      w.mirror.setTrack('RQ1', w.track(age: const Duration(minutes: 4)));
      await open(tester, b: b, scale: 1.3);
      expect(tester.takeException(), isNull);
    });
  }
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/instant/instant_tracking_view_test.dart`
Expected: FAIL (placeholder view).

- [ ] **Step 3: Implement**

Strings (`lib/l10n/app_vi.arb`, then `flutter gen-l10n`):

```json
  "instantAssignedTitle": "{name} đã nhận · đến trong khoảng {minutes} phút",
  "@instantAssignedTitle": {"placeholders": {"name": {"type": "String"}, "minutes": {"type": "int"}}},
  "instantAssignedTitleShort": "{name} đã nhận",
  "@instantAssignedTitleShort": {"placeholders": {"name": {"type": "String"}}},
  "instantArrivedTitle": "Đã đến điểm hẹn",
  "instantRatingShoots": "★ {rating} · {shoots} buổi",
  "@instantRatingShoots": {"placeholders": {"rating": {"type": "String"}, "shoots": {"type": "int"}}},
  "instantShoots": "{shoots} buổi",
  "@instantShoots": {"placeholders": {"shoots": {"type": "int"}}},
  "instantEta": "đến trong khoảng {minutes} phút",
  "@instantEta": {"placeholders": {"minutes": {"type": "int"}}},
  "instantEtaEstimated": "(ước tính)",
  "instantOnTheWay": "Đang đến",
  "instantPhotographerMarker": "{name} · {minutes} phút",
  "@instantPhotographerMarker": {"placeholders": {"name": {"type": "String"}, "minutes": {"type": "int"}}},
  "instantVerifyFace": "Đối chiếu ảnh đại diện khi gặp. Vị trí của {name} chỉ hiện trong lúc đang đến.",
  "@instantVerifyFace": {"placeholders": {"name": {"type": "String"}}},
  "instantWaitingLocation": "Đang chờ cập nhật vị trí",
  "instantCancelFreeFor": "Huỷ (miễn phí thêm {time})",
  "@instantCancelFreeFor": {"placeholders": {"time": {"type": "String"}}},
  "instantCancelLateFree": "Huỷ miễn phí vì nhiếp ảnh gia trễ",
```

```dart
// lib/features/instant/views/instant_tracking_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/contact/contact_link_repository.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/features/contact/contact_action.dart';
import 'package:photobooking/features/instant/instant_customer_rules.dart';
import 'package:photobooking/features/instant/views/instant_pill.dart';

String _rating(double r) => r.toStringAsFixed(1).replaceAll('.', ',');

/// S49: the photographer on the map with the ETA, contact, and the
/// cancel rules spelled out on the button.
class InstantTrackingView extends ConsumerStatefulWidget {
  const InstantTrackingView({super.key, required this.view, required this.onCancel});
  final InstantRequestView view;
  final VoidCallback onCancel;

  @override
  ConsumerState<InstantTrackingView> createState() => _InstantTrackingViewState();
}

class _InstantTrackingViewState extends ConsumerState<InstantTrackingView> {
  /// The first ETA seen; "trễ quá 15 phút so với ETA ban đầu" counts from it.
  int? _firstEta;
  int _camera = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final v = widget.view;
    _firstEta ??= v.etaMinutes;
    final onTheWay = v.status.onTheWay;
    final arrived = v.status == InstantStatus.arrived;
    final track = onTheWay ? ref.watch(instantTrackProvider(v.id)).value : null;
    final p = v.photographer;
    final name = p?.displayName ?? l.instantThePhotographer;
    final meet = v.meetPoint;
    final eta = v.etaMinutes;
    final danger = dark ? AppColorsDark.destructive : AppColors.destructive;

    final meta = [
      if (p?.rating != null) l.instantRatingShoots(_rating(p!.rating!), p.completedShoots) else if (p != null) l.instantShoots(p.completedShoots),
      if (onTheWay && eta != null) [l.instantEta(eta), if (v.etaEstimated) l.instantEtaEstimated].join(' '),
    ].join(' · ');

    final inGrace = graceLeft(v, ref.read(clockProvider)()) != null;

    return ScreenCode(
      ScreenCodes.instantTracking,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: BackButton(onPressed: () => context.go(AppTab.home.path)),
        ),
        extendBodyBehindAppBar: true,
        body: Column(
          children: [
            if (meet != null)
              SizedBox(
                key: const Key('tracking-map'),
                height: 250,
                child: AppMap(
                  center: meet.latLng,
                  semanticsLabel: l.instantMapLabel,
                  fitMarkers: track != null,
                  cameraToken: _camera,
                  onMyLocation: () => setState(() => _camera++),
                  markers: [
                    MapMarker(id: 'me', at: meet.latLng, label: l.instantYou, kind: MapMarkerKind.self),
                    if (track != null)
                      MapMarker(
                        id: 'photographer',
                        at: track.latLng,
                        label: eta == null ? name : l.instantPhotographerMarker(name, eta),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: SafeArea(
                top: meet == null,
                child: TickingBuilder(
                  active: onTheWay,
                  period: inGrace ? const Duration(seconds: 1) : const Duration(seconds: 15),
                  builder: (context) {
                    final now = ref.read(clockProvider)();
                    final grace = graceLeft(v, now);
                    if (inGrace && grace == null) {
                      // Grace just ended: rebuild so the clock slows to 15 s.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {});
                        }
                      });
                    }
                    final late = photographerLate(v, _firstEta, now);
                    final stale = trackStale(track, v, now);
                    return ListView(
                      padding: const EdgeInsets.all(AppSpace.s4),
                      children: [
                        Row(
                          children: [
                            AppAvatar(url: p?.avatarUrl, name: name),
                            const SizedBox(width: AppSpace.s3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (p?.verified ?? false)
                                    VerifiedName(name, style: theme.textTheme.titleSmall)
                                  else
                                    Text(name, style: theme.textTheme.titleSmall),
                                  Text(meta, key: const Key('tracking-meta'), style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpace.s2),
                            InstantPill(arrived ? l.instantJobArrived : l.instantOnTheWay),
                          ],
                        ),
                        const SizedBox(height: AppSpace.s3),
                        Text(
                          arrived
                              ? l.instantArrivedTitle
                              : (eta == null ? l.instantAssignedTitleShort(name) : l.instantAssignedTitle(name, eta)),
                          key: const Key('tracking-headline'),
                          style: theme.textTheme.titleMedium,
                        ),
                        if (stale) ...[
                          const SizedBox(height: AppSpace.s2),
                          DecoratedBox(
                            key: const Key('tracking-stale'),
                            decoration: BoxDecoration(
                              color: AppColors.warningSubtle,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpace.s3),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_searching_rounded, size: 18, color: AppColors.foreground),
                                  const SizedBox(width: AppSpace.s2),
                                  Expanded(
                                    child: Text(
                                      l.instantWaitingLocation,
                                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.foreground),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpace.s2),
                        Text(l.instantVerifyFace(name), style: theme.textTheme.bodySmall),
                        const SizedBox(height: AppSpace.s3),
                        Row(
                          children: [
                            AppButton.outline(
                              l.instantMessage,
                              key: const Key('tracking-chat'),
                              onPressed: () => context.push('/chat/${v.id}'),
                            ),
                            const SizedBox(width: AppSpace.s2),
                            if (v.photographerId != null)
                              Expanded(
                                child: PhotographerContactAction(
                                  photographerId: v.photographerId!,
                                  access: ContactAccess.unlocked,
                                  source: ScreenCodes.instantTracking,
                                  subject: ContactSubject.instant(v.id),
                                  style: ContactDialStyle.labeled,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.s2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            key: const Key('instant-cancel'),
                            onPressed: widget.onCancel,
                            child: Text(
                              late
                                  ? l.instantCancelLateFree
                                  : grace != null
                                  ? l.instantCancelFreeFor(formatClock(grace))
                                  : l.instantCancelRequest,
                              style: TextStyle(color: danger),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

(`instantJobArrived`, `instantMessage`, `instantYou`, `instantMapLabel`, `instantThePhotographer` are I4's keys.)

- [ ] **Step 4: Run and see it pass**

Run: `flutter gen-l10n && flutter test test/features/instant && flutter analyze`
Expected: PASS (11 new tests).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/instant lib/l10n test/features/instant
git commit -m "feat(instant): S49 tracking with map, ETA, grace countdown, stale position and late free cancel

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: S50 "Đang chụp" and the completed state

**Files:**
- Modify (replace the placeholder): `lib/features/instant/views/instant_shoot_view.dart`; modify `lib/l10n/app_vi.arb`
- Create: `test/features/instant/instant_shoot_view_test.dart`

**Interfaces:**
- Consumes: `CountdownRing`, `TickingBuilder`, `InstantMilestones`/`Milestone`, `instantCustomerActionsProvider`, `shootRemaining`, `canConfirmComplete`, `instantDraftProvider` (`lastQuote` for the photo count), `AppAvatar`, `instantErrorText`, `toVn`, `genreLabel`, `packageLabel`, I4's `instantMilestoneAccepted` / `instantMilestoneArrived`.
- Produces: `const InstantShootView({super.key, required InstantRequestView view})` (S50; completed → `ScreenCode(S50, label: 'done')`). Keys: `shoot-ring`, `shoot-chat`, `shoot-confirm`, `shoot-done`. l10n listed in Step 3.

Layout (mock S50): "Đang chụp" with a chat icon; the ring with `38:12` / "còn lại" (one tick per second until finished or time is up); "Minh Trí đã báo hoàn thành." once finished; the card (avatar, "Minh Trí · Chân dung 1 giờ", "Bắt đầu 15:42 · Công viên Tao Đàn", pill "Đang chụp"); milestones "Đã nhận · 15:21", "Đã đến · 15:38", "Hoàn thành và giao 30 ảnh trong 48 giờ"; the note on auto-completion after 2 hours and reporting within 24 hours; the one primary "Xác nhận hoàn thành" (enabled when the photographer finished or the package time is over). Completed: "Buổi chụp đã hoàn thành" and the primary "Đánh giá" (→ `/instant/:id/review`, S12).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/instant/instant_shoot_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';

import '../../support/instant_customer_screens.dart';
import '../../support/instant_customer_world.dart';

void main() {
  late InstantCustomerWorld w;
  setUp(() async {
    w = InstantCustomerWorld();
    await w.init();
  });

  Future<void> open(WidgetTester tester, {Brightness b = Brightness.dark, double scale = 1}) async {
    await tester.pumpWidget(instantCustomerApp(w, location: '/instant/RQ1', brightness: b, textScale: scale));
    await tester.pump();
    await tester.pump();
  }

  FilledButton confirm(WidgetTester tester) => tester.widget<FilledButton>(
    find.descendant(of: find.byKey(const Key('shoot-confirm')), matching: find.byType(FilledButton)),
  );

  testWidgets('the shoot clock in numbers and words, the card, milestones; confirm waits', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.inProgress, startedAt: w.now.subtract(const Duration(minutes: 21, seconds: 48))));
    final handle = tester.ensureSemantics();
    await open(tester);
    expect(find.text('38:12'), findsOneWidget);
    expect(find.text('còn lại'), findsOneWidget);
    expect(find.bySemanticsLabel('Còn 38 phút'), findsOneWidget);
    expect(find.text('Minh Trí · Chân dung 1 giờ'), findsOneWidget);
    expect(find.text('Đang chụp'), findsWidgets);
    expect(find.text('Hoàn thành và giao ảnh trong 48 giờ'), findsOneWidget);
    expect(confirm(tester).onPressed, isNull);
    expect(TickingBuilder.debugActiveCount, 1);
    handle.dispose();
  });

  testWidgets('the photographer finished: the clock stops, confirming calls the service', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.inProgress, startedAt: w.now.subtract(const Duration(minutes: 50)), finishedAt: w.now));
    await open(tester);
    expect(find.text('Minh Trí đã báo hoàn thành.'), findsOneWidget);
    expect(TickingBuilder.debugActiveCount, 0);
    await tester.tap(find.byKey(const Key('shoot-confirm')));
    await tester.pump();
    expect(w.booking.confirmCalls, ['RQ1']);
  });

  testWidgets('time is up without "Hoàn thành": confirm is possible', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.inProgress, startedAt: w.now.subtract(const Duration(minutes: 59, seconds: 58))));
    await open(tester);
    expect(confirm(tester).onPressed, isNull);
    for (var i = 0; i < 3; i++) {
      w.now = w.now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
    expect(confirm(tester).onPressed, isNotNull);
    expect(TickingBuilder.debugActiveCount, 0);
  });

  testWidgets('the photo count comes from the quote seen on S47', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.inProgress, startedAt: w.now));
    await open(tester);
    expect(find.text('Hoàn thành và giao ảnh trong 48 giờ'), findsOneWidget);
  });

  testWidgets('completed: "Đánh giá" opens the review', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.completed, startedAt: w.now.subtract(const Duration(hours: 1)), finishedAt: w.now));
    await open(tester);
    expect(find.byKey(const Key('shoot-done')), findsOneWidget);
    await tester.tap(find.text('Đánh giá'));
    await tester.pumpAndSettle();
    expect(find.text('review RQ1'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x (${b.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      w.mirror.setRequest('RQ1', w.request(InstantStatus.inProgress, startedAt: w.now));
      await open(tester, b: b, scale: 1.3);
      expect(tester.takeException(), isNull);
    });
  }
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/instant/instant_shoot_view_test.dart`
Expected: FAIL (placeholder view).

- [ ] **Step 3: Implement**

Strings (`lib/l10n/app_vi.arb`, then `flutter gen-l10n`):

```json
  "instantShootingTitle": "Đang chụp",
  "instantRemaining": "còn lại",
  "instantRemainingMinutes": "Còn {minutes} phút",
  "@instantRemainingMinutes": {"placeholders": {"minutes": {"type": "int"}}},
  "instantShootCard": "{name} · {genre} {duration}",
  "@instantShootCard": {"placeholders": {"name": {"type": "String"}, "genre": {"type": "String"}, "duration": {"type": "String"}}},
  "instantStartedAt": "Bắt đầu {time} · {place}",
  "@instantStartedAt": {"placeholders": {"time": {"type": "String"}, "place": {"type": "String"}}},
  "instantShootingBadge": "Đang chụp",
  "instantMilestoneDeliver": "Hoàn thành và giao {photos} ảnh trong 48 giờ",
  "@instantMilestoneDeliver": {"placeholders": {"photos": {"type": "int"}}},
  "instantMilestoneDeliverShort": "Hoàn thành và giao ảnh trong 48 giờ",
  "instantConfirmNote": "Khi {name} bấm Hoàn thành, bạn xác nhận ở đây. Không xác nhận thì tự hoàn thành sau 2 giờ; có vấn đề thì báo trong 24 giờ.",
  "@instantConfirmNote": {"placeholders": {"name": {"type": "String"}}},
  "instantFinishedBy": "{name} đã báo hoàn thành.",
  "@instantFinishedBy": {"placeholders": {"name": {"type": "String"}}},
  "instantConfirmComplete": "Xác nhận hoàn thành",
  "instantCompletedTitle": "Buổi chụp đã hoàn thành",
  "instantCompletedBody": "Cảm ơn bạn. Ảnh sẽ được giao trong 48 giờ.",
  "instantReview": "Đánh giá",
```

```dart
// lib/features/instant/views/instant_shoot_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/instant/instant_labels.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/instant_customer_actions.dart';
import 'package:photobooking/features/instant/instant_customer_rules.dart';
import 'package:photobooking/features/instant/instant_draft.dart';
import 'package:photobooking/features/instant/views/instant_pill.dart';
import 'package:photobooking/features/instant_common/instant_errors.dart';
import 'package:photobooking/features/instant_common/instant_milestones.dart';

/// S50: the shoot clock and one button; then "Đánh giá" once completed.
class InstantShootView extends ConsumerStatefulWidget {
  const InstantShootView({super.key, required this.view});
  final InstantRequestView view;

  @override
  ConsumerState<InstantShootView> createState() => _InstantShootViewState();
}

class _InstantShootViewState extends ConsumerState<InstantShootView> {
  bool _timeUp = false;
  bool _confirming = false;

  String _time(DateTime? t) => t == null ? '' : DateFormat('HH:mm').format(toVn(t));

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    try {
      await ref.read(instantCustomerActionsProvider).confirmComplete(widget.view.id);
    } on DispatchException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(instantErrorText(e.error, context.l10n))));
      }
    } finally {
      if (mounted) {
        setState(() => _confirming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final v = widget.view;
    final p = v.photographer;
    final name = p?.displayName ?? l.instantThePhotographer;

    if (v.status == InstantStatus.completed) {
      return ScreenCode(
        ScreenCodes.instantInProgress,
        label: 'done',
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(),
          body: EmptyState(
            key: const Key('shoot-done'),
            title: l.instantCompletedTitle,
            body: l.instantCompletedBody,
            actionLabel: l.instantReview,
            onAction: () => context.push('/instant/${v.id}/review'),
          ),
        ),
      );
    }

    final photos = ref.watch(instantDraftProvider.select((d) => d.lastQuote?.byCode(v.packageCode)?.photos));
    final total = Duration(minutes: v.durationMin);
    final running = v.finishedAt == null && !_timeUp;

    return ScreenCode(
      ScreenCodes.instantInProgress,
      child: TickingBuilder(
        active: running,
        builder: (context) {
          final now = ref.read(clockProvider)();
          final left = shootRemaining(v, now);
          if (running && left == Duration.zero) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _timeUp = true);
              }
            });
          }
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              centerTitle: true,
              title: Text(l.instantShootingTitle),
              actions: [
                IconButton(
                  key: const Key('shoot-chat'),
                  tooltip: l.instantMessage,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  onPressed: () => context.push('/chat/${v.id}'),
                ),
              ],
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.s5),
                children: [
                  Center(
                    child: CountdownRing(
                      key: const Key('shoot-ring'),
                      remaining: left,
                      total: total,
                      unit: l.instantRemaining,
                      semanticsLabel: l.instantRemainingMinutes(left.inMinutes),
                    ),
                  ),
                  if (v.finishedAt != null) ...[
                    const SizedBox(height: AppSpace.s2),
                    Text(l.instantFinishedBy(name), textAlign: TextAlign.center, style: theme.textTheme.titleSmall),
                  ],
                  const SizedBox(height: AppSpace.s4),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: dark ? AppColorsDark.surfaceMuted : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.s3),
                      child: Row(
                        children: [
                          AppAvatar(url: p?.avatarUrl, name: name),
                          const SizedBox(width: AppSpace.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.instantShootCard(name, genreLabel(v.genre, l), packageLabel(v.packageCode)), style: theme.textTheme.titleSmall),
                                if (v.startedAt != null)
                                  Text(l.instantStartedAt(_time(v.startedAt), v.meetPoint?.address ?? ''), style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpace.s2),
                          InstantPill(l.instantShootingBadge),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s3),
                  InstantMilestones(
                    items: [
                      Milestone(l.instantMilestoneAccepted(_time(v.assignedAt)), done: true),
                      Milestone(l.instantMilestoneArrived(_time(v.arrivedAt)), done: true),
                      Milestone(
                        photos == null ? l.instantMilestoneDeliverShort : l.instantMilestoneDeliver(photos),
                        done: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s3),
                  Text(l.instantConfirmNote(name), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s4),
                child: AppButton.primary(
                  l.instantConfirmComplete,
                  key: const Key('shoot-confirm'),
                  loading: _confirming,
                  onPressed: canConfirmComplete(v, now) ? _confirm : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter gen-l10n && flutter test test/features/instant && flutter analyze`
Expected: PASS (7 new tests).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/instant lib/l10n test/features/instant
git commit -m "feat(instant): S50 shoot clock with confirmation and the completed state

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: S51 "Không tìm được người" and the closed states

**Files:**
- Modify (replace the placeholders): `lib/features/instant/views/instant_no_match_view.dart`, `lib/features/instant/views/instant_closed_view.dart`; modify `lib/l10n/app_vi.arb`
- Create: `test/features/instant/instant_no_match_view_test.dart`

**Interfaces:**
- Consumes: `instantDraftProvider`, `formatMoney`, `AppButton`, `EmptyState`, `AppTab`.
- Produces:
  - `const InstantNoMatchView({super.key, required InstantRequestView view})` (S51). Keys: `nomatch-title`, `nomatch-refund`, `nomatch-expand`, `nomatch-regular`, `nomatch-retry`.
  - `const InstantClosedView({super.key, required InstantRequestView view})`: `cancelled_by_customer` → S55 · `done` ("Đã huỷ yêu cầu", "Đã hoàn {số tiền}."), `no_show_customer` → S49 · `no_show`, `disputed` → S50 · `disputed`; "Về trang chủ". Key `closed-state`.
  - l10n listed in Step 3.

Layout (mock S51): back arrow and "Chụp ngay"; an empty-state block "Chưa tìm được nhiếp ảnh gia" and "Đã hoàn 690.000₫. Gần bạn lúc này ít người đang sẵn sàng." (refund first); "Mở rộng tìm kiếm" **ticked** with "Lần này tìm cả nhiếp ảnh gia khác ở gần."; outline "Đặt lịch thường với người bạn chọn" (→ `/action`, S04); the one primary "Thử lại" (→ S47 with the previous package, kind and meet point, and the chosen expand).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/instant/instant_no_match_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/instant_draft.dart';
import 'package:photobooking/features/instant/instant_request_screen.dart';

import '../../support/idle.dart';
import '../../support/instant_customer_screens.dart';
import '../../support/instant_customer_world.dart';

void main() {
  late InstantCustomerWorld w;
  setUp(() async {
    w = InstantCustomerWorld();
    await w.init();
  });

  Future<void> open(WidgetTester tester, InstantRequestView v, {Brightness b = Brightness.dark, double scale = 1}) async {
    w.mirror.setRequest('RQ1', v);
    await tester.pumpWidget(instantCustomerApp(w, location: '/instant/RQ1', brightness: b, textScale: scale));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('refund first, expand suggested, one primary', (tester) async {
    await open(tester, w.request(InstantStatus.noMatch, refundVnd: 690000));
    expect(find.text('Chưa tìm được nhiếp ảnh gia'), findsOneWidget);
    expect(find.text('Đã hoàn 690.000₫. Gần bạn lúc này ít người đang sẵn sàng.'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('nomatch-expand'))).value, isTrue);
    expect(find.byType(CtaSurface), findsOneWidget);
    await expectIdle(tester);
  });

  testWidgets('"Thử lại" keeps the choices and the expand answer', (tester) async {
    await open(tester, w.request(InstantStatus.noMatch, refundVnd: 690000));
    final c = ProviderScope.containerOf(tester.element(find.byType(InstantRequestScreen)));
    c.read(instantDraftProvider.notifier)
      ..setPackage(InstantPackageCode.p120)
      ..setMeetPoint(w.meet);
    await tester.tap(find.byKey(const Key('nomatch-retry')));
    await tester.pumpAndSettle();
    expect(c.read(instantDraftProvider).expand, isTrue);
    expect(find.text('Thanh toán 1.190.000₫ và tìm'), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('instant-expand'))).value, isTrue);
    expect(w.location.currentFixCalls, 0, reason: 'the meet point is kept');
  });

  testWidgets('unticking expand is respected', (tester) async {
    await open(tester, w.request(InstantStatus.noMatch, refundVnd: 690000));
    await tester.tap(find.byKey(const Key('nomatch-expand')));
    await tester.tap(find.byKey(const Key('nomatch-retry')));
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('instant-expand'))).value, isFalse);
  });

  testWidgets('"Đặt lịch thường" goes to Find', (tester) async {
    await open(tester, w.request(InstantStatus.noMatch, refundVnd: 690000));
    await tester.tap(find.byKey(const Key('nomatch-regular')));
    await tester.pumpAndSettle();
    expect(find.text('find'), findsOneWidget);
  });

  testWidgets('cancelled: what was refunded, and home', (tester) async {
    await open(tester, w.request(InstantStatus.cancelledByCustomer, refundVnd: 552000));
    expect(find.text('Đã huỷ yêu cầu'), findsOneWidget);
    expect(find.text('Đã hoàn 552.000₫.'), findsOneWidget);
    await tester.tap(find.text('Về trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x (${b.name})', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, w.request(InstantStatus.noMatch, refundVnd: 690000), b: b, scale: 1.3);
      expect(tester.takeException(), isNull);
    });
  }
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/instant/instant_no_match_view_test.dart`
Expected: FAIL (placeholders).

- [ ] **Step 3: Implement**

Strings (`lib/l10n/app_vi.arb`, then `flutter gen-l10n`):

```json
  "instantNoMatchTitle": "Chưa tìm được nhiếp ảnh gia",
  "instantNoMatchRefund": "Đã hoàn {amount}. Gần bạn lúc này ít người đang sẵn sàng.",
  "@instantNoMatchRefund": {"placeholders": {"amount": {"type": "String"}}},
  "instantExpandRetryBody": "Lần này tìm cả nhiếp ảnh gia khác ở gần.",
  "instantBookRegularLong": "Đặt lịch thường với người bạn chọn",
  "instantCancelledByYou": "Đã huỷ yêu cầu",
  "instantRefunded": "Đã hoàn {amount}.",
  "@instantRefunded": {"placeholders": {"amount": {"type": "String"}}},
  "instantNoShowTitle": "Bạn chưa có mặt ở điểm hẹn",
  "instantDisputedTitle": "Đang xử lý báo cáo",
  "instantDisputedBody": "Chúng tôi sẽ liên hệ bạn trong 24 giờ.",
  "instantBackHome": "Về trang chủ",
```

```dart
// lib/features/instant/views/instant_no_match_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/features/instant/instant_draft.dart';

/// S51: the refund first, then a retry with "Mở rộng" suggested, or a normal booking.
class InstantNoMatchView extends ConsumerStatefulWidget {
  const InstantNoMatchView({super.key, required this.view});
  final InstantRequestView view;

  @override
  ConsumerState<InstantNoMatchView> createState() => _InstantNoMatchViewState();
}

class _InstantNoMatchViewState extends ConsumerState<InstantNoMatchView> {
  bool _expand = true;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final v = widget.view;
    return ScreenCode(
      ScreenCodes.instantNoMatch,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.go(AppTab.home.path)),
          title: Text(l.instantTitle),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.s5),
            children: [
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s6),
                    child: Icon(Icons.travel_explore_rounded, size: 40, color: dark ? AppColorsDark.primary : AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s4),
              Text(l.instantNoMatchTitle, key: const Key('nomatch-title'), textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpace.s2),
              Text(
                l.instantNoMatchRefund(formatMoney(v.refundVnd ?? v.amountVnd)),
                key: const Key('nomatch-refund'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.s4),
              CheckboxListTile(
                key: const Key('nomatch-expand'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _expand,
                onChanged: (on) => setState(() => _expand = on ?? false),
                title: Text(l.instantExpandTitle),
                subtitle: Text(l.instantExpandRetryBody),
              ),
              const SizedBox(height: AppSpace.s3),
              AppButton.outline(l.instantBookRegularLong, key: const Key('nomatch-regular'), onPressed: () => context.go('/action')),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: AppButton.primary(
              l.instantTryAgain,
              key: const Key('nomatch-retry'),
              onPressed: () {
                ref.read(instantDraftProvider.notifier).setExpand(_expand);
                context.go('/instant');
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

```dart
// lib/features/instant/views/instant_closed_view.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';

/// Final states other than completed and no match.
class InstantClosedView extends StatelessWidget {
  const InstantClosedView({super.key, required this.view});
  final InstantRequestView view;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final refund = view.refundVnd == null ? '' : l.instantRefunded(formatMoney(view.refundVnd!));
    final (code, label, title, body) = switch (view.status) {
      InstantStatus.noShowCustomer => (ScreenCodes.instantTracking, 'no_show', l.instantNoShowTitle, refund),
      InstantStatus.disputed => (ScreenCodes.instantInProgress, 'disputed', l.instantDisputedTitle, l.instantDisputedBody),
      _ => (ScreenCodes.instantCancel, 'done', l.instantCancelledByYou, refund),
    };
    return ScreenCode(
      code,
      label: label,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(leading: BackButton(onPressed: () => context.go(AppTab.home.path))),
        body: EmptyState(
          key: const Key('closed-state'),
          title: title,
          body: body,
          actionLabel: l.instantBackHome,
          onAction: () => context.go(AppTab.home.path),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter gen-l10n && flutter test test/features/instant && flutter analyze`
Expected: PASS (7 new tests).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/instant lib/l10n test/features/instant
git commit -m "feat(instant): S51 no match with refund and retry, closed states

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Customer notifications ("đã có người nhận") and navigation

**Files:**
- Modify: `lib/data/instant/instant_push.dart`, `lib/data/instant/instant_notifier.dart`, `lib/data/instant/local_instant_notifier.dart`, `lib/data/instant/instant_labels.dart`, `lib/data/instant/fcm_background.dart`, `lib/features/instant_work/instant_navigation.dart` (all plan I4), `lib/l10n/app_vi.arb`, `test/data/instant/instant_push_test.dart`, `test/data/instant/instant_notifier_test.dart`
- Create: `test/features/instant/customer_navigation_test.dart`

**Interfaces:**
- Consumes: I4 Task 6 and Task 13 (`InstantPush`, `InstantNotifier`, `LocalInstantNotifier`, `instantBackgroundMessage`, `wireInstantNavigation`).
- Produces:
  - `AssignedPush(String requestId, {String? photographerName, int? etaMinutes})` (FCM keys `photographerName`, `etaMinutes`, optional).
  - `InstantTapKind.request` (id = request id) and `InstantNotifier.showRequestUpdate({required String requestId, required String title, required String body})`; `FakeInstantNotifier.updates` (`List<String>` of request ids).
  - `({String title, String body})? requestUpdateText(InstantPush p, AppLocalizations l)`: assigned → "Minh Trí đã nhận · đến trong khoảng 9 phút" / "Mở để xem nhiếp ảnh gia trên bản đồ."; status `arrived` → "Đã đến điểm hẹn"; status `no_match` → "Chưa tìm được nhiếp ảnh gia" / "Tiền đã được hoàn đủ. Mở để thử lại."; anything else → null.
  - Background (Android, app not visible): the handler shows these updates on channel `instant_updates`. Navigation: a tapped update, an opened FCM alert (iOS) or the launching notification opens `/instant/:id`; an `assigned` push received while the app is open opens `/instant/:id` too (unless already there).
  - l10n: `instantNotificationChannelUpdates` "Cập nhật chụp ngay", `instantAssignedGeneric` "Đã có nhiếp ảnh gia nhận", `instantAssignedBody` "Mở để xem nhiếp ảnh gia trên bản đồ.", `instantNoMatchNotification` "Tiền đã được hoàn đủ. Mở để thử lại.".

- [ ] **Step 1: Write the failing tests**

Append to `main()` in `test/data/instant/instant_push_test.dart`:

```dart
  test('assigned may carry the photographer name and ETA for the notification', () {
    final p = InstantPush.parse({'type': 'assigned', 'requestId': 'RQ1', 'photographerName': 'Minh Trí', 'etaMinutes': '9'})! as AssignedPush;
    expect((p.requestId, p.photographerName, p.etaMinutes), ('RQ1', 'Minh Trí', 9));
    final bare = InstantPush.parse({'type': 'assigned', 'requestId': 'RQ1'})! as AssignedPush;
    expect((bare.photographerName, bare.etaMinutes), (null, null));
  });

  test('customer update texts', () {
    final l = AppLocalizationsVi();
    expect(
      requestUpdateText(const AssignedPush('RQ1', photographerName: 'Minh Trí', etaMinutes: 9), l)!.title,
      'Minh Trí đã nhận · đến trong khoảng 9 phút',
    );
    expect(requestUpdateText(const AssignedPush('RQ1'), l)!.title, 'Đã có nhiếp ảnh gia nhận');
    expect(requestUpdateText(const StatusPush('RQ1', InstantStatus.arrived), l)!.title, 'Đã đến điểm hẹn');
    expect(requestUpdateText(const StatusPush('RQ1', InstantStatus.noMatch), l)!.body, 'Tiền đã được hoàn đủ. Mở để thử lại.');
    expect(requestUpdateText(const StatusPush('RQ1', InstantStatus.enRoute), l), isNull);
  });
```

Append to `main()` in `test/data/instant/instant_notifier_test.dart`:

```dart
  test('request updates use their own channel and open the request', () async {
    final n = FakeInstantNotifier();
    await n.showRequestUpdate(requestId: 'RQ1', title: 't', body: 'b');
    expect(n.updates, ['RQ1']);
    final src = File('lib/data/instant/local_instant_notifier.dart').readAsStringSync();
    expect(src, contains("'instant_updates'"));
    expect(src, contains("'request:"));
  });
```

```dart
// test/features/instant/customer_navigation_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_notifier.dart';
import 'package:photobooking/data/instant/instant_push.dart';
import 'package:photobooking/features/instant_work/instant_navigation.dart';

import '../../support/instant_customer_world.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const Text('home')),
      GoRoute(path: '/instant/:id', builder: (_, s) => Text('request ${s.pathParameters['id']}')),
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
  late InstantCustomerWorld w;
  setUp(() async {
    w = InstantCustomerWorld();
    await w.init();
  });

  Widget app() => ProviderScope(overrides: w.overrides, child: const _App());

  testWidgets('a tapped update opens the request', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    w.notifier.tap(const InstantTap(InstantTapKind.request, id: 'RQ1'));
    await tester.pumpAndSettle();
    expect(find.text('request RQ1'), findsOneWidget);
  });

  testWidgets('an opened FCM alert (iOS) opens the request', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    w.push.open(const StatusPush('RQ1', InstantStatus.noMatch));
    await tester.pumpAndSettle();
    expect(find.text('request RQ1'), findsOneWidget);
  });

  testWidgets('"assigned" while the app is open jumps to the request once', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    w.push.receive(const AssignedPush('RQ1', photographerName: 'Minh Trí', etaMinutes: 9));
    await tester.pumpAndSettle();
    expect(find.text('request RQ1'), findsOneWidget);
    w.push.receive(const AssignedPush('RQ1'));
    await tester.pumpAndSettle();
    expect(find.text('request RQ1'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/data/instant test/features/instant/customer_navigation_test.dart`
Expected: FAIL to compile (`requestUpdateText`, `showRequestUpdate`, `InstantTapKind.request`, the named `AssignedPush` arguments are missing).

- [ ] **Step 3: Implement**

Strings (`lib/l10n/app_vi.arb`, then `flutter gen-l10n`):

```json
  "instantNotificationChannelUpdates": "Cập nhật chụp ngay",
  "instantAssignedGeneric": "Đã có nhiếp ảnh gia nhận",
  "instantAssignedBody": "Mở để xem nhiếp ảnh gia trên bản đồ.",
  "instantNoMatchNotification": "Tiền đã được hoàn đủ. Mở để thử lại.",
```

1. `lib/data/instant/instant_push.dart`: replace `AssignedPush` with

   ```dart
   final class AssignedPush extends InstantPush {
     const AssignedPush(this.requestId, {this.photographerName, this.etaMinutes});
     final String requestId;
     final String? photographerName;
     final int? etaMinutes;
   }
   ```

   and its `parse` case with

   ```dart
           case 'assigned':
             final id = data['requestId'];
             if (id is! String) {
               return null;
             }
             final name = data['photographerName'];
             return AssignedPush(
               id,
               photographerName: name is String && name.isNotEmpty ? name : null,
               etaMinutes: int.tryParse('${data['etaMinutes'] ?? ''}'),
             );
   ```

2. `lib/data/instant/instant_notifier.dart`: `enum InstantTapKind { offer, keepAvailable, turnOff, request }`; add to `InstantNotifier`

   ```dart
     /// Customer side: "đã có người nhận", "đã đến", "không tìm được".
     Future<void> showRequestUpdate({required String requestId, required String title, required String body});
   ```

   and to `FakeInstantNotifier`: `final updates = <String>[];` and

   ```dart
     @override
     Future<void> showRequestUpdate({required String requestId, required String title, required String body}) async =>
         updates.add(requestId);
   ```

3. `lib/data/instant/local_instant_notifier.dart`: add `const _updatesChannel = 'instant_updates';`; in `_tapFrom`, before the `return null;`, add

   ```dart
     if (payload.startsWith('request:')) {
       return InstantTap(InstantTapKind.request, id: payload.substring(8));
     }
   ```

   and the method

   ```dart
     @override
     Future<void> showRequestUpdate({required String requestId, required String title, required String body}) => _plugin.show(
       notificationIdFor('request:$requestId'),
       title,
       body,
       NotificationDetails(
         android: AndroidNotificationDetails(
           _updatesChannel,
           _l.instantNotificationChannelUpdates,
           importance: Importance.high,
           priority: Priority.high,
           autoCancel: true,
         ),
         iOS: const DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentSound: true),
       ),
       payload: 'request:$requestId',
     );
   ```

4. `lib/data/instant/instant_labels.dart`: add (imports `instant_push.dart`)

   ```dart
   /// Text of a customer-side update, or null for statuses not worth a ping.
   ({String title, String body})? requestUpdateText(InstantPush p, AppLocalizations l) => switch (p) {
     AssignedPush(:final photographerName?, :final etaMinutes?) => (
       title: l.instantAssignedTitle(photographerName, etaMinutes),
       body: l.instantAssignedBody,
     ),
     AssignedPush(:final photographerName?) => (title: l.instantAssignedTitleShort(photographerName), body: l.instantAssignedBody),
     AssignedPush() => (title: l.instantAssignedGeneric, body: l.instantAssignedBody),
     StatusPush(status: InstantStatus.arrived) => (title: l.instantArrivedTitle, body: l.instantAssignedBody),
     StatusPush(status: InstantStatus.noMatch) => (title: l.instantNoMatchTitle, body: l.instantNoMatchNotification),
     _ => null,
   };
   ```

5. `lib/data/instant/fcm_background.dart`: replace the body after `final push = InstantPush.parse(message.data);` with

   ```dart
     if (push == null) {
       return;
     }
     WidgetsFlutterBinding.ensureInitialized();
     final l = lookupAppLocalizations(const Locale('vi'));
     final notifier = LocalInstantNotifier();
     await notifier.init(l);
     switch (push) {
       case OfferPush(:final offer):
         final text = offerNotificationText(offer, l, now: DateTime.now().toUtc());
         await notifier.showOffer(offerId: offer.offerId, title: text.title, body: text.body, expiresAt: offer.expiresAt);
       case AssignedPush(:final requestId) || StatusPush(:final requestId):
         final text = requestUpdateText(push, l);
         if (text != null) {
           await notifier.showRequestUpdate(requestId: requestId, title: text.title, body: text.body);
         }
     }
   ```

6. `lib/features/instant_work/instant_navigation.dart`: add

   ```dart
     void openRequest(String id) {
       final target = '/instant/$id';
       if (router.routerDelegate.currentConfiguration.uri.path != target) {
         router.push(target);
       }
     }
   ```

   add the case `case InstantTapKind.request: if (t.id != null) { openRequest(t.id!); }` to `onTap`'s switch; make `onPush` a switch:

   ```dart
     void onPush(InstantPush p) {
       switch (p) {
         case OfferPush(:final offer):
           openOffer(offer.offerId);
         case AssignedPush(:final requestId) || StatusPush(:final requestId):
           openRequest(requestId);
       }
     }
   ```

   and add a third subscription to `subs`: `push.foreground.listen((p) { if (p is AssignedPush) { openRequest(p.requestId); } }),`.

- [ ] **Step 4: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/data/instant test/features && flutter analyze`
Expected: PASS (2 + 1 + 3 new tests; I4's navigation and notifier tests unchanged).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/data/instant lib/features/instant_work/instant_navigation.dart lib/l10n test
git commit -m "feat(instant): customer updates as notifications and navigation to the request

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Entry points on S01 Home and S04 Find

**Files:**
- Create: `lib/features/instant/instant_entry.dart`, `test/features/instant/instant_entry_test.dart`
- Modify: `lib/data/instant/instant_providers.dart`, `lib/data/instant/instant_booking_repository.dart` (fake counts health calls), `lib/features/home/home_screen.dart`, `lib/features/find/find_screen.dart` (plan 3b4), `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `instantBookingRepositoryProvider`, `paymentLauncherProvider`, `currentProfileProvider`, `UserRole`, 3b4's `HomeScreen` and `FindPhotographerScreen`, `DiscoveryWorld`, `screenRouterApp`.
- Produces:
  - `instantAvailableProvider` (`FutureProvider<bool>`, kept for the app session: one `GET /v1/health` per session; false when the payment launcher is unavailable, the service is not configured or unhealthy, spec §10 "Nút Chụp ngay ẩn").
  - `const InstantHomeCard({super.key})` (key `home-instant`): a card at the top of S01 (under the greeting) "Chụp ngay" / "Nhiếp ảnh gia tới chỗ bạn trong khoảng 30–90 phút" → `/instant`; customers only.
  - `const InstantFindButton({super.key})` (key `find-instant`): an outline button above S04's filters "Chụp ngay · có người tới trong 30–90 phút" → `/instant` (S04 has no primary action, so this stays outline).
  - `FakeInstantBookingRepository.healthCalls`.
  - l10n `instantFindButton` "Chụp ngay · có người tới trong 30–90 phút".

- [ ] **Step 1: Write the failing test**

```dart
// test/features/instant/instant_entry_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/instant/instant_booking_repository.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/instant/payment_launcher.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/find/find_screen.dart';
import 'package:photobooking/features/home/home_screen.dart';
import 'package:photobooking/features/instant/instant_entry.dart';

import '../../support/discovery_world.dart';
import '../../support/instant_customer_world.dart';
import '../../support/screen_host.dart';

Widget _cards(InstantCustomerWorld w) => screenRouterApp(
  router: GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Column(children: [InstantHomeCard(), InstantFindButton()])),
      ),
      GoRoute(path: '/instant', builder: (_, _) => const Text('S47')),
    ],
  ),
  overrides: w.overrides,
);

void main() {
  testWidgets('customers see both entries when the service and payment are up; one health call', (tester) async {
    final w = InstantCustomerWorld();
    await w.init();
    await tester.pumpWidget(_cards(w));
    await tester.pumpAndSettle();
    expect(find.text('Nhiếp ảnh gia tới chỗ bạn trong khoảng 30–90 phút'), findsOneWidget);
    expect(find.text('Chụp ngay · có người tới trong 30–90 phút'), findsOneWidget);
    expect(w.booking.healthCalls, 1);
    await tester.tap(find.byKey(const Key('home-instant')));
    await tester.pumpAndSettle();
    expect(find.text('S47'), findsOneWidget);
  });

  testWidgets('hidden for photographers, when unhealthy, and without payment', (tester) async {
    final photographer = InstantCustomerWorld(role: UserRole.photographer);
    await photographer.init();
    await tester.pumpWidget(_cards(photographer));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-instant')), findsNothing);

    final down = InstantCustomerWorld();
    await down.init();
    down.booking.healthyValue = false;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_cards(down));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('find-instant')), findsNothing);

    final noPay = InstantCustomerWorld();
    await noPay.init();
    noPay.payment.available = false;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_cards(noPay));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-instant')), findsNothing);
  });

  testWidgets('S01 and S04 carry the entries', (tester) async {
    final d = DiscoveryWorld();
    await d.init();
    final overrides = [
      ...d.overrides,
      instantBookingRepositoryProvider.overrideWithValue(FakeInstantBookingRepository()),
      paymentLauncherProvider.overrideWithValue(FakePaymentLauncher()),
    ];
    await tester.pumpWidget(screenRouterApp(
      router: GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/action', builder: (_, _) => const FindPhotographerScreen()),
          GoRoute(path: '/instant', builder: (_, _) => const Text('S47')),
        ],
      ),
      overrides: overrides,
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-instant')), findsOneWidget);
  });

  testWidgets('S04 shows the Chụp ngay button above the filters', (tester) async {
    final d = DiscoveryWorld();
    await d.init();
    await tester.pumpWidget(screenRouterApp(
      router: GoRouter(
        initialLocation: '/action',
        routes: [
          GoRoute(path: '/action', builder: (_, _) => const FindPhotographerScreen()),
          GoRoute(path: '/instant', builder: (_, _) => const Text('S47')),
        ],
      ),
      overrides: [
        ...d.overrides,
        instantBookingRepositoryProvider.overrideWithValue(FakeInstantBookingRepository()),
        paymentLauncherProvider.overrideWithValue(FakePaymentLauncher()),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('find-instant')), findsOneWidget);
    await tester.tap(find.byKey(const Key('find-instant')));
    await tester.pumpAndSettle();
    expect(find.text('S47'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/instant/instant_entry_test.dart`
Expected: FAIL to compile (`instant_entry.dart`, `healthCalls`, `instantAvailableProvider` missing).

- [ ] **Step 3: Implement**

Add `"instantFindButton": "Chụp ngay · có người tới trong 30–90 phút",` to `lib/l10n/app_vi.arb`, then `flutter gen-l10n`.

In `FakeInstantBookingRepository` (Task 1) add `int healthCalls = 0;` and change `healthy()` to

```dart
  @override
  Future<bool> healthy() async {
    healthCalls++;
    return healthyValue;
  }
```

Append to `lib/data/instant/instant_providers.dart`:

```dart
/// Whether to offer "Chụp ngay" at all (spec §10: hidden when the service is
/// down). Kept for the app session: one health check, not one per screen.
final instantAvailableProvider = FutureProvider<bool>((ref) async {
  if (!ref.watch(paymentLauncherProvider).available) {
    return false;
  }
  try {
    return await ref.watch(instantBookingRepositoryProvider).healthy();
  } on Object {
    return false;
  }
});
```

```dart
// lib/features/instant/instant_entry.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';

bool _show(WidgetRef ref) =>
    ref.watch(currentProfileProvider).value?.role == UserRole.customer &&
    (ref.watch(instantAvailableProvider).value ?? false);

/// S01: the floating "Chụp ngay" card at the top of Home (spec §2.1).
class InstantHomeCard extends ConsumerWidget {
  const InstantHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_show(ref)) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = dark ? AppColorsDark.primary : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s2, AppSpace.s4, AppSpace.s2),
      child: Material(
        color: dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          key: const Key('home-instant'),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => context.push('/instant'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s4),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: primary),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.instantTitle, style: theme.textTheme.titleMedium),
                      Text(l.instantSubtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// S04: "Chụp ngay" above the list of photographers.
class InstantFindButton extends ConsumerWidget {
  const InstantFindButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_show(ref)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4, vertical: AppSpace.s2),
      child: AppButton.outline(
        context.l10n.instantFindButton,
        key: const Key('find-instant'),
        icon: const Icon(Icons.bolt_rounded),
        onPressed: () => context.push('/instant'),
      ),
    );
  }
}
```

`lib/features/home/home_screen.dart` (3b4): add `import 'package:photobooking/features/instant/instant_entry.dart';` and, in `build`'s `slivers:` list, right after the first `SliverPadding` (greeting and "homeTitle") and before the `SliverToBoxAdapter` with the chip row, insert `const SliverToBoxAdapter(child: InstantHomeCard()),`.

`lib/features/find/find_screen.dart` (3b4): add the same import and insert `const SliverToBoxAdapter(child: InstantFindButton()),` as the first element of the `CustomScrollView`'s `slivers:` (before the filter chip row).

- [ ] **Step 4: Run and see it pass**

Run: `flutter gen-l10n && flutter test test/features/instant test/features/home test/features/find && flutter analyze`
Expected: PASS (4 new tests; 3b4's own Home/Find tests still pass: without overrides `instantAvailableProvider` is false — `DISPATCH_URL` is empty in tests, so the payment launcher is unavailable and nothing is added).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/data/instant lib/features/instant lib/features/home lib/features/find lib/l10n test/features/instant
git commit -m "feat(instant): Chụp ngay entry on Home and Find, hidden when the service or payment is unavailable

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Two-party integration test against one fake dispatch service

**Files:**
- Create: `test/support/fake_dispatch_server.dart`, `test/integration/instant_two_party_test.dart`

**Interfaces:**
- Consumes: every port of I4 and I5 (`InstantBookingRepository`, `PresenceRepository`, `InstantJobRepository`, `PaymentLauncher`, `InstantMirror`/`FakeInstantMirror`), the controllers (`InstantBookController`, `InstantSessionController`, `InstantJobController`, `InstantCustomerActions`), I4/I5 fakes.
- Produces: `FakeDispatchServer({required DateTime Function() clock})` with `mirror`, `names` (uid → display name), `customer(uid)`, `presence(uid)`, `jobs(uid)`, `payments()`, `timeOut(requestId)`, `status(requestId)`; it applies the state machine of spec §3.1, the one-photographer-at-a-time and never-re-offer rules of §3.2, and the cancel table of §4 with integer VND that always adds up.

This is the spec §11 "App (integration, bản giả)" check: the full customer + photographer flow on two `ProviderContainer`s (the controllers, not the widgets, so it runs fast and deterministically), no match, a photographer cancelling and the search continuing with someone else, and the customer cancelling at each milestone.

- [ ] **Step 1: Write the fake service and the failing test**

```dart
// test/support/fake_dispatch_server.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/fake_instant_repositories.dart';
import 'package:photobooking/data/instant/instant_booking_repository.dart';
import 'package:photobooking/data/instant/instant_mirror.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_repositories.dart';
import 'package:photobooking/data/instant/payment_launcher.dart';

class _Req {
  _Req(this.id, this.customerId, this.pkg, this.genre, this.meet, this.expand, this.requestedAt);
  final String id;
  final String customerId;
  final InstantPackage pkg;
  final InstantGenre genre;
  final MeetPoint meet;
  final bool expand;
  final DateTime requestedAt;
  InstantStatus status = InstantStatus.pendingPayment;
  String? photographerId;
  final declined = <String>{};
  DateTime? assignedAt;
  DateTime? graceEndsAt;
  DateTime? arrivedAt;
  DateTime? startedAt;
  DateTime? finishedAt;
  int? refundVnd;
}

/// The dispatch service in memory: enough of spec §3–§4 to drive both apps.
class FakeDispatchServer {
  FakeDispatchServer({required this.clock});

  final DateTime Function() clock;
  final mirror = FakeInstantMirror();
  final quote = fakePackagesQuote();
  final names = <String, String>{};
  final _requests = <String, _Req>{};
  final _online = <String>[];
  final _busy = <String>{};
  final _offers = <String, (String requestId, String photographerId)>{};
  int _seq = 0;

  InstantBookingRepository customer(String uid) => _Customer(this, uid);
  PresenceRepository presence(String uid) => _Photographer(this, uid);
  InstantJobRepository jobs(String uid) => _Photographer(this, uid);
  PaymentLauncher payments() => _Gateway(this);

  InstantStatus status(String id) => _requests[id]!.status;

  void _publish(_Req r) {
    final hasP = r.photographerId != null;
    mirror.setRequest(r.id, InstantRequestView(
      id: r.id,
      status: r.status,
      customerId: r.customerId,
      photographerId: r.photographerId,
      photographer: hasP
          ? InstantPhotographer(uid: r.photographerId!, displayName: names[r.photographerId] ?? 'NAG', verified: true, completedShoots: 10, rating: 4.8)
          : null,
      packageCode: r.pkg.code,
      genre: r.genre,
      amountVnd: r.pkg.priceVnd,
      expand: r.expand,
      round: 1,
      radiusKm: 3,
      etaMinutes: hasP ? 9 : null,
      graceEndsAt: r.graceEndsAt,
      meetPoint: hasP ? r.meet : null,
      requestedAt: r.requestedAt,
      assignedAt: r.assignedAt,
      arrivedAt: r.arrivedAt,
      startedAt: r.startedAt,
      finishedAt: r.finishedAt,
      refundVnd: r.refundVnd,
      updatedAt: clock(),
    ));
  }

  void _offerNext(_Req r) {
    if (r.status != InstantStatus.searching) {
      return;
    }
    final free = _online.where((p) => !_busy.contains(p) && !r.declined.contains(p) && !_offers.values.any((o) => o.$2 == p));
    if (free.isEmpty) {
      return;
    }
    final p = free.first;
    final offerId = 'O${++_seq}';
    _offers[offerId] = (r.id, p);
    mirror.setOffer(p, InstantOffer(
      offerId: offerId,
      requestId: r.id,
      packageCode: r.pkg.code,
      genre: r.genre,
      payoutVnd: r.pkg.payoutVnd,
      distanceKm: 2.1,
      travelMinutes: 8,
      area: 'Phường Bến Thành, Quận 1',
      expiresAt: clock().add(const Duration(seconds: 30)),
    ));
  }

  void pay(String id) {
    final r = _requests[id]!;
    r.status = InstantStatus.searching;
    _publish(r);
    _offerNext(r);
  }

  /// 10 minutes without anyone: no match, full refund.
  void timeOut(String id) {
    final r = _requests[id]!;
    r
      ..status = InstantStatus.noMatch
      ..refundVnd = r.pkg.priceVnd;
    _offers.removeWhere((offerId, o) {
      if (o.$1 == id) {
        mirror.setOffer(o.$2, null);
      }
      return o.$1 == id;
    });
    _publish(r);
  }

  CancelQuote _quote(_Req r, {required bool byPhotographer}) {
    final amount = r.pkg.priceVnd;
    CancelQuote split(CancelRule rule, int refundPercent, int photographerPercent) {
      final refund = amount * refundPercent ~/ 100;
      final photographer = amount * photographerPercent ~/ 100;
      return CancelQuote(rule: rule, refundVnd: refund, photographerVnd: photographer, platformVnd: amount - refund - photographer, graceEndsAt: r.graceEndsAt);
    }

    if (byPhotographer) {
      return split(CancelRule.photographerCancel, 100, 0);
    }
    return switch (r.status) {
      InstantStatus.searching => split(CancelRule.freeSearching, 100, 0),
      InstantStatus.assigned || InstantStatus.enRoute =>
        clock().isBefore(r.graceEndsAt!) ? split(CancelRule.freeGrace, 100, 0) : split(CancelRule.enRouteFee, 80, 20),
      InstantStatus.arrived => split(CancelRule.noShow, 50, 50),
      _ => throw const DispatchException(DispatchError.conflict, status: 409),
    };
  }

  void _release(_Req r) {
    final p = r.photographerId;
    if (p != null) {
      _busy.remove(p);
    }
    mirror.setTrack(r.id, null);
  }
}

class _Customer implements InstantBookingRepository {
  _Customer(this.s, this.uid);
  final FakeDispatchServer s;
  final String uid;

  @override
  Future<bool> healthy() async => true;

  @override
  Future<PackagesQuote> packages({LatLng? near, String? cityId}) async => s.quote;

  @override
  Future<CreatedRequest> create({
    required String packageId,
    required InstantGenre genre,
    required MeetPoint meetPoint,
    required String note,
    required bool expand,
    required int expectedAmountVnd,
    required PaymentProvider provider,
  }) async {
    final pkg = s.quote.byId(packageId)!;
    if (pkg.priceVnd != expectedAmountVnd) {
      throw const DispatchException(DispatchError.priceChanged, status: 409);
    }
    final id = 'RQ${++s._seq}';
    final r = _Req(id, uid, pkg, genre, meetPoint, expand, s.clock());
    s._requests[id] = r;
    s._publish(r);
    return CreatedRequest(requestId: id, amountVnd: pkg.priceVnd, paymentUrl: Uri.parse('fake://pay/$id'));
  }

  @override
  Future<CancelQuote> cancel(String requestId, {required bool dryRun, String? reason}) async {
    final r = s._requests[requestId]!;
    final q = s._quote(r, byPhotographer: false);
    if (!dryRun) {
      s._release(r);
      r
        ..status = InstantStatus.cancelledByCustomer
        ..refundVnd = q.refundVnd;
      s._publish(r);
    }
    return q;
  }

  @override
  Future<void> confirmComplete(String requestId) async {
    final r = s._requests[requestId]!;
    r.status = InstantStatus.completed;
    s._release(r);
    s._publish(r);
  }
}

class _Photographer implements PresenceRepository, InstantJobRepository {
  _Photographer(this.s, this.uid);
  final FakeDispatchServer s;
  final String uid;

  _Req _mine(String id) {
    final r = s._requests[id]!;
    if (r.photographerId != uid) {
      throw const DispatchException(DispatchError.permissionDenied, status: 403);
    }
    return r;
  }

  @override
  Future<PresenceState> setPresence({required bool online, bool? helpReady, LocationFix? fix}) async {
    if (online && !s._online.contains(uid)) {
      s._online.add(uid);
      for (final r in s._requests.values) {
        s._offerNext(r);
      }
    } else if (!online) {
      s._online.remove(uid);
    }
    return PresenceState(online: online, helpReady: helpReady ?? false, cityId: 'hcm');
  }

  @override
  Future<InstantSettings> settings() async =>
      const InstantSettings(acceptedPriceListVersion: 3, currentPriceListVersion: 3, helpReady: false, eligible: true, reasons: []);

  @override
  Future<InstantSettings> updateSettings({int? acceptPriceListVersion, bool? helpReady}) => settings();

  @override
  Future<PackagesQuote> packagesNear(LatLng at) async => s.quote;

  @override
  Future<AcceptedJob> accept(String offerId) async {
    final o = s._offers.remove(offerId);
    if (o == null) {
      throw const DispatchException(DispatchError.offerExpired, status: 409);
    }
    s.mirror.setOffer(o.$2, null);
    final r = s._requests[o.$1]!;
    if (r.status != InstantStatus.searching) {
      throw const DispatchException(DispatchError.alreadyAssigned, status: 409);
    }
    final now = s.clock();
    r
      ..status = InstantStatus.assigned
      ..photographerId = uid
      ..assignedAt = now
      ..graceEndsAt = now.add(const Duration(minutes: 2));
    s._busy.add(uid);
    s._publish(r);
    return AcceptedJob(requestId: r.id, meetPoint: r.meet, customerName: 'Lan Anh');
  }

  @override
  Future<void> decline(String offerId, {DeclineReason? reason}) async {
    final o = s._offers.remove(offerId);
    if (o == null) {
      throw const DispatchException(DispatchError.offerExpired, status: 409);
    }
    s.mirror.setOffer(o.$2, null);
    final r = s._requests[o.$1]!..declined.add(uid);
    s._offerNext(r);
  }

  @override
  Future<void> postLocation(String requestId, LocationFix fix) async {
    final r = _mine(requestId);
    if (r.status == InstantStatus.assigned) {
      r.status = InstantStatus.enRoute;
      s._publish(r);
    }
    s.mirror.setTrack(requestId, InstantTrack(lat: fix.lat, lng: fix.lng, accuracyM: fix.accuracyM, at: fix.at));
  }

  @override
  Future<void> arrive(String requestId, {required LocationFix fix, bool force = false, String? reason}) async {
    final r = _mine(requestId);
    if (!force && distanceMeters(fix.latLng, r.meet.latLng) > 200) {
      throw const DispatchException(DispatchError.invalidArgument, status: 422);
    }
    r
      ..status = InstantStatus.arrived
      ..arrivedAt = s.clock();
    s.mirror.setTrack(requestId, null);
    s._publish(r);
  }

  @override
  Future<void> start(String requestId) async {
    final r = _mine(requestId)
      ..status = InstantStatus.inProgress
      ..startedAt = s.clock();
    s._publish(r);
  }

  @override
  Future<void> finish(String requestId) async {
    final r = _mine(requestId)..finishedAt = s.clock();
    s._busy.remove(uid);
    s._publish(r);
  }

  @override
  Future<CancelQuote> cancel(String requestId, {required bool dryRun, String? reason}) async {
    final r = _mine(requestId);
    final q = s._quote(r, byPhotographer: true);
    if (!dryRun) {
      s._release(r);
      r
        ..declined.add(uid)
        ..photographerId = null
        ..assignedAt = null
        ..graceEndsAt = null
        ..status = InstantStatus.searching;
      s._publish(r);
      s._offerNext(r);
    }
    return q;
  }
}

class _Gateway implements PaymentLauncher {
  _Gateway(this.s);
  final FakeDispatchServer s;

  @override
  PaymentProvider get provider => PaymentProvider.fake;

  @override
  bool get available => true;

  @override
  Future<PaymentStart> open(CreatedRequest request) async {
    s.pay(request.requestId);
    return PaymentStart.completedInApp;
  }
}
```

```dart
// test/integration/instant_two_party_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/instant/battery_level.dart';
import 'package:photobooking/data/instant/foreground_session.dart';
import 'package:photobooking/data/instant/instant_models.dart';
import 'package:photobooking/data/instant/instant_notifier.dart';
import 'package:photobooking/data/instant/instant_providers.dart';
import 'package:photobooking/data/instant/instant_push.dart';
import 'package:photobooking/data/instant/place_search.dart';
import 'package:photobooking/data/instant/tracking_location.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/instant/instant_book_controller.dart';
import 'package:photobooking/features/instant/instant_customer_actions.dart';
import 'package:photobooking/features/instant_common/instant_services.dart';
import 'package:photobooking/features/instant_work/instant_job_controller.dart';
import 'package:photobooking/features/instant_work/instant_session_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_dispatch_server.dart';

const _meet = MeetPoint(lat: 10.7745, lng: 106.6926, address: 'Công viên Tao Đàn, Quận 1');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late FakeDispatchServer server;
  late SharedPreferences prefs;

  setUp(() async {
    now = DateTime.utc(2026, 10, 1, 8);
    server = FakeDispatchServer(clock: () => now);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  LocationFix fixAt(double northMeters) =>
      LocationFix(lat: _meet.lat + northMeters / 111195, lng: _meet.lng, accuracyM: 8, at: now);

  Future<(ProviderContainer, String)> person(UserRole role, String name, List<Override> Function(String uid) extra) async {
    final auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final contacts = FakeUserContactRepository();
    final u = await auth.registerWithEmail('${name.hashCode}@example.vn', 'password1', name);
    await users.ensureProfile(u);
    await users.setRole(u.uid, role);
    contacts.seed(u.uid, const UserContact(phone: '+84903123456'));
    final c = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(users),
      userContactRepositoryProvider.overrideWithValue(contacts),
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => now),
      instantMirrorProvider.overrideWithValue(server.mirror),
      locationRepositoryProvider.overrideWithValue(FakeLocationRepository(status: LocationPermissionStatus.granted)),
      ...extra(u.uid),
    ]);
    addTearDown(c.dispose);
    return (c, u.uid);
  }

  Future<(ProviderContainer, String)> customer() => person(UserRole.customer, 'Lan Anh', (uid) => [
    instantBookingRepositoryProvider.overrideWithValue(server.customer(uid)),
    paymentLauncherProvider.overrideWithValue(server.payments()),
    placeSearchProvider.overrideWithValue(FakePlaceSearch()..addressFor = (_) => _meet.address),
    trackingLocationProvider.overrideWithValue(FakeTrackingLocationSource(current: fixAt(0))),
  ]);

  Future<(ProviderContainer, String, FakeTrackingLocationSource)> photographer(String name) async {
    final gps = FakeTrackingLocationSource(current: fixAt(-2000));
    final (c, uid) = await person(UserRole.photographer, name, (uid) => [
      presenceRepositoryProvider.overrideWithValue(server.presence(uid)),
      instantJobRepositoryProvider.overrideWithValue(server.jobs(uid)),
      trackingLocationProvider.overrideWithValue(gps),
      foregroundSessionProvider.overrideWithValue(FakeForegroundSession()),
      instantNotifierProvider.overrideWithValue(FakeInstantNotifier()),
      pushMessagesProvider.overrideWithValue(FakePushMessages()),
      batteryLevelProvider.overrideWithValue(FakeBatteryLevel(80)),
    ]);
    server.names[uid] = name;
    await c.read(instantSessionProvider.notifier).goOnline();
    return (c, uid, gps);
  }

  Future<String> request(ProviderContainer c) async {
    c.listen(instantBookProvider, (_, _) {});
    final book = c.read(instantBookProvider.notifier);
    await book.start();
    final r = await book.submit();
    return (r as InstantSubmitStarted).requestId;
  }

  test('the full flow: request, offer, accept, en route, arrive, shoot, finish, confirm', () async {
    final (p, _, gps) = await photographer('Minh Trí');
    final (c, _) = await customer();
    final seen = <InstantStatus>[];
    final id = await request(c);
    c.listen(instantRequestProvider(id), (_, next) {
      final s = next.value?.status;
      if (s != null && (seen.isEmpty || seen.last != s)) {
        seen.add(s);
      }
    }, fireImmediately: true);
    await pumpEventQueue();

    final offer = p.read(instantSessionProvider).pendingOffer!;
    expect(offer.requestId, id);
    expect(await p.read(instantJobProvider.notifier).accept(offer.offerId), isTrue);
    await pumpEventQueue();
    expect(c.read(instantRequestProvider(id)).value!.photographer!.displayName, 'Minh Trí');

    gps.moveRoute(fixAt(-1500));
    await pumpEventQueue();
    expect(server.status(id), InstantStatus.enRoute);
    c.listen(instantTrackProvider(id), (_, _) {});
    await pumpEventQueue();
    expect(c.read(instantTrackProvider(id)).value, isNotNull);

    now = now.add(const Duration(seconds: 12));
    gps.moveRoute(fixAt(80));
    await pumpEventQueue();
    expect(await p.read(instantJobProvider.notifier).arrive(), isTrue);
    expect(await p.read(instantJobProvider.notifier).start(), isTrue);
    expect(await p.read(instantJobProvider.notifier).finish(), isTrue);
    await c.read(instantCustomerActionsProvider).confirmComplete(id);
    await pumpEventQueue();

    expect(seen, containsAllInOrder([
      InstantStatus.searching,
      InstantStatus.assigned,
      InstantStatus.enRoute,
      InstantStatus.arrived,
      InstantStatus.inProgress,
      InstantStatus.completed,
    ]));
    expect(p.read(instantSessionProvider).online, isTrue, reason: 'available again after the job');
    expect(p.read(instantSessionProvider).activeRequestId, isNull);
    expect(gps.routeListeners, 0);
  });

  test('nobody available: no match after 10 minutes, full refund', () async {
    final (c, _) = await customer();
    final id = await request(c);
    expect(server.status(id), InstantStatus.searching);
    server.timeOut(id);
    c.listen(instantRequestProvider(id), (_, _) {});
    await pumpEventQueue();
    final v = c.read(instantRequestProvider(id)).value!;
    expect((v.status, v.refundVnd), (InstantStatus.noMatch, 690000));
  });

  test('a photographer cancels: the search goes on with someone else, never back to them', () async {
    final (p1, _, _) = await photographer('Minh Trí');
    final (c, _) = await customer();
    final id = await request(c);
    await pumpEventQueue();
    final first = p1.read(instantSessionProvider).pendingOffer!;
    await p1.read(instantJobProvider.notifier).accept(first.offerId);
    final (p2, _, _) = await photographer('Hồng Nhung');
    await p1.read(instantJobProvider.notifier).confirmCancel();
    await pumpEventQueue();
    expect(server.status(id), InstantStatus.searching);
    expect(p2.read(instantSessionProvider).pendingOffer?.requestId, id);
    expect(p1.read(instantSessionProvider).pendingOffer, isNull);
  });

  test('the customer cancels at each milestone; refund + payout + platform always equal the price', () async {
    Future<CancelQuote> cancelAt(Future<void> Function(ProviderContainer p, String id, FakeTrackingLocationSource gps) reach) async {
      server = FakeDispatchServer(clock: () => now);
      final (p, _, gps) = await photographer('Minh Trí');
      final (c, _) = await customer();
      final id = await request(c);
      await pumpEventQueue();
      await reach(p, id, gps);
      final actions = c.read(instantCustomerActionsProvider);
      final dry = await actions.quoteCancel(id);
      final done = await actions.cancel(id);
      expect(done, dry, reason: 'the dry run is what is applied');
      expect(dry.totalVnd, 690000);
      expect(server.status(id), InstantStatus.cancelledByCustomer);
      return dry;
    }

    Future<void> accept(ProviderContainer p) async {
      await p.read(instantJobProvider.notifier).accept(p.read(instantSessionProvider).pendingOffer!.offerId);
    }

    expect((await cancelAt((_, _, _) async {})).rule, CancelRule.freeSearching);
    expect((await cancelAt((p, _, _) => accept(p))).rule, CancelRule.freeGrace);
    final enRoute = await cancelAt((p, _, gps) async {
      await accept(p);
      gps.moveRoute(fixAt(-1500));
      await pumpEventQueue();
      now = now.add(const Duration(minutes: 3));
    });
    expect((enRoute.rule, enRoute.refundVnd, enRoute.photographerVnd), (CancelRule.enRouteFee, 552000, 138000));
    final arrived = await cancelAt((p, _, gps) async {
      await accept(p);
      gps.moveRoute(fixAt(50));
      await pumpEventQueue();
      await p.read(instantJobProvider.notifier).arrive();
    });
    expect((arrived.rule, arrived.refundVnd, arrived.photographerVnd), (CancelRule.noShow, 345000, 345000));
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/integration/instant_two_party_test.dart`
Expected: PASS (4 tests) once Tasks 1–12 and plan I4 are in. If a status is missed in `seen`, check that the customer container listens to the mirror before the photographer acts (the fake mirror only replays the current value on listen). A failure here is a real integration bug between the two controllers: fix the controller, not the fake, unless the fake breaks spec §3–§4.

- [ ] **Step 3: Commit**

```bash
dart format test
git add test/support/fake_dispatch_server.dart test/integration/instant_two_party_test.dart
git commit -m "test(instant): customer and photographer end to end on one fake dispatch service

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Align the specs and the battery guide (moved)

Moved to `docs/superpowers/plans/2026-10-02-final-battery-performance.md` (section "2026-10-01-instant-i5-customer-app.md"). Nothing to do here.


### Task 15: Battery and performance check

**Files:**
- Create: `test/battery/instant_customer_battery_test.dart`
- Reference: `test/support/idle.dart` (`expectIdle`), `test/support/blur.dart` (`expectBlurBudget`), `docs/testing/battery-and-performance.md` (with its iOS section and the Chụp ngay section)

**Interfaces:**
- Consumes: `InstantCustomerWorld`, `instantCustomerApp`, `FakeMapEngine`, `TickingBuilder.debugActiveCount`.
- Produces: this plan's battery gate (no production API).

What is checked: the customer side never opens a location stream and takes at most one fix per S47 visit (none when the draft already has the meet point); the pulse animates only while searching and is idle under reduced motion, and the only clock left is the 1 Hz search timer; leaving S48 for S49 stops both; S49 at rest (no grace, no new position) schedules no frames and its clock ticks every 15 s, not every second; S50 has one clock until finished; S51 and the closed states are idle; the map is built on S47 and S49 only; every mirror listener closes with the screen; one health check per session; at most four blurs per screen, none nested.

- [ ] **Step 1: Write the tests**

```dart
// test/battery/instant_customer_battery_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/instant/instant_models.dart';

import '../support/blur.dart';
import '../support/idle.dart';
import '../support/instant_customer_screens.dart';
import '../support/instant_customer_world.dart';

void main() {
  late InstantCustomerWorld w;
  setUp(() async {
    w = InstantCustomerWorld();
    await w.init();
  });

  Future<void> open(WidgetTester tester, String at) async {
    await tester.pumpWidget(instantCustomerApp(w, location: at));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('S47: one medium fix, no stream, the map, idle at rest, no blur', (tester) async {
    await open(tester, '/instant');
    await tester.pumpAndSettle();
    expect(w.location.currentFixCalls, 1);
    expect(w.location.activeStreams, 0);
    expect(w.map.builds, greaterThan(0));
    await expectIdle(tester);
    expectBlurBudget();
  });

  testWidgets('S48 under reduced motion: no animation, only the 1 Hz search clock; S49 stops it', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    w.mirror.setRequest('RQ1', w.request(InstantStatus.searching));
    await open(tester, '/instant/RQ1');
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);
    expect(TickingBuilder.debugActiveCount, 1);
    expect(w.map.builds, 0, reason: 'no map on S48');
    w.mirror.setRequest('RQ1', w.request(InstantStatus.enRoute));
    await tester.pump();
    expect(find.byType(SearchPulse), findsNothing);
  });

  testWidgets('S48 animated: the pulse runs only while searching', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.searching));
    await open(tester, '/instant/RQ1');
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    w.mirror.setRequest('RQ1', w.request(InstantStatus.noMatch, refundVnd: 690000));
    await expectIdle(tester);
    expect(TickingBuilder.debugActiveCount, 0);
  });

  testWidgets('S49 at rest: no frames; the clock ticks every 15 s, not every second', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.enRoute));
    w.mirror.setTrack('RQ1', w.track());
    await open(tester, '/instant/RQ1');
    await expectIdle(tester);
    expect(TickingBuilder.debugActiveCount, 1);
    final builds = w.map.builds;
    await tester.pump(const Duration(seconds: 10));
    expect(w.map.builds, builds, reason: 'nothing rebuilds the map between 15 s ticks');
    expectBlurBudget();
  });

  testWidgets('S50: one clock until finished; S51: idle; neither builds a map', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.inProgress, startedAt: w.now));
    await open(tester, '/instant/RQ1');
    expect(TickingBuilder.debugActiveCount, 1);
    w.mirror.setRequest('RQ1', w.request(InstantStatus.inProgress, startedAt: w.now, finishedAt: w.now));
    await tester.pump();
    expect(TickingBuilder.debugActiveCount, 0);
    w.mirror.setRequest('RQ1', w.request(InstantStatus.noMatch, refundVnd: 690000));
    await expectIdle(tester);
    expect(w.map.builds, 0);
  });

  testWidgets('every mirror listener closes with the screen; no location stream at any point', (tester) async {
    w.mirror.setRequest('RQ1', w.request(InstantStatus.enRoute));
    await open(tester, '/instant/RQ1');
    expect(w.mirror.listenersOf('instant_requests/RQ1'), 1);
    expect(w.mirror.listenersOf('instant_tracks/RQ1'), 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(w.mirror.openListeners, 0);
    expect(w.location.activeStreams, 0);
  });

  testWidgets('back to S47 from S33 or S51 takes no new fix', (tester) async {
    await open(tester, '/instant');
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await open(tester, '/instant');
    await tester.pumpAndSettle();
    expect(w.location.currentFixCalls, 1, reason: 'a fresh ProviderScope here; in the app the draft survives');
  });
}
```

(The last test uses a new `ProviderScope` per `pumpWidget`, so it shows the per-visit cost; the draft-reuse case — no fix at all — is covered by Task 5's controller test "a meet point already in the draft".)

- [ ] **Step 2: Run the tests**

Run: `flutter test test/battery/instant_customer_battery_test.dart`
Expected: PASS (7 tests). A failure names the culprit (a ticker at rest, a clock that did not stop, a listener that outlived its screen, a location stream on the customer side); remove the cause, never loosen the test.

- [ ] **Step 3: Fix anything the run found, then run everything**

Run: `flutter analyze && flutter test`
Expected: analyze clean; the whole suite passes (I4's, I5's and the earlier plans').

- [ ] **Step 4: Manual profiling on real devices (Android and iOS)**

Follow `docs/testing/battery-and-performance.md`: the general steps for S47–S51 and S55 (frames at rest, scrolling S47, CPU at rest, memory), then the Chụp ngay scenarios of I4 (A–C, with a second phone as photographer) and this plan (D–E). Build with `flutter run --profile --dart-define=DISPATCH_URL=http://<host>:8090 --dart-define=GOONG_MAPTILES_KEY=<key> --dart-define=GOONG_API_KEY=<key>` against plan I3's local service with `PAYMENTS=fake`.

Also check by hand, once per platform: Goong tiles load in light and dark (the style follows the theme); address search returns Vietnamese results near the pin; the key restriction works (a build with another package name gets 403 from Goong); with reduced motion on (Android: Remove animations; iOS: Reduce Motion) S48's rings and aperture stand still and S49's pin jumps instead of gliding; the "Minh Trí đã nhận" notification arrives with the app in the background.

Record the filled-in result table (Android and iOS rows, "Chụp ngay D/E") in the PR description. Any value over a threshold blocks the merge. Until the iOS enablement device tasks are done, write "iOS: not measured, blocked by iOS enablement".

- [ ] **Step 5: Commit**

```bash
dart format test
git add test/battery/instant_customer_battery_test.dart
git commit -m "test(instant): battery gate for the customer screens

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** §2.1 entry points on S01 (card) and S04 (button) (Task 12); S47 packages, five kinds of shoot, meet point defaulting to the current location with drag and Goong Autocomplete, note ≤ 140, "Mở rộng tìm kiếm" off by default, fixed price on the button, typical match time hidden when unknown, escrow note (Tasks 3, 5, 6); missing phone → S33 via `/profile/phone?returnTo=/instant` and back (Tasks 5, 6); pay → S48 (Tasks 2, 6, 7); S49 map, ETA, photographer card, "Nhắn tin" and `ContactDial` unlocked after payment (Task 8); arrived → S50 shoot timer, confirm, auto-completion note, review link (Task 9); no match → S51 with the refund first, retry with the previous choices and expand suggested, or "Đặt lịch thường" (Task 10); S55 at any step before the shoot with the dry-run amounts and a red confirmation (Tasks 7, 8, I4 Task 11); §3.1 one route switching on the mirror status, each state in its own screen code (Task 7); §4 cancel table amounts add up, tested end to end (Task 13); §5 HTTPS + Firebase ID token through the shared `ApiClient`, Firestore mirror read only (Tasks 1, 7, 8); §6 customer calls and the `phone_required` / `outside_service_area` / `price_changed` errors (Tasks 1, 5, 6); §8 Vietnamese strings ("Chụp ngay", "Nhiếp ảnh gia tới chỗ bạn trong khoảng 30–90 phút", "Mở rộng tìm kiếm", "Tìm cả nhiếp ảnh gia khác ở gần nếu chưa có người nhận", "Thanh toán {giá} và tìm", "Tiền được giữ an toàn và hoàn 100% nếu không có người nhận.", "Đang tìm nhiếp ảnh gia gần bạn" → the mock's "Đang mời người phù hợp gần bạn", "{tên} đã nhận · đến trong khoảng {n} phút", "Đã đến điểm hẹn", "Chưa tìm được nhiếp ảnh gia. Đã hoàn {số tiền}."), map pins with labels, "Về vị trí của tôi", reduced motion stops the pulse and the pin glide (Tasks 4, 6–10); §9 customer location once at S47, map only on S47/S49, interpolated pin, privacy (Tasks 5, 8, 15); §10 payment failed keeps the choices, lost connection resumes from the mirror, three minutes without a position, late beyond 15 minutes → free cancel, Goong down → map placeholder with ETA and contact still working, outside service area, price change, service down hides the entry (Tasks 6–8, 12); §11 widget tests at 320dp/1.3×/light/dark, `expectIdle` with the pulse only while searching and idle under reduced motion, S55 amounts from the dry run, the two-party integration with no match, photographer cancel and customer cancel at each milestone (all tasks, 13, 15).
- **Deviations (flagged, not hidden):** (1) S47 builds a live map (the mock shows one; dragging needs it), so "map only on S49/S54" becomes "S47, S49, S54"; the battery test checks S48, S50, S51 have none. (2) The pin is fixed at the centre and the map is dragged under it (more accessible and robust than dragging a marker); spec text updated in Task 14. (3) The S48 centre is plan I4's `ApertureLoader` (coordinator decision), not a camera icon or the colour logo; `SearchPulse` adds the rings. (4) The FCM `assigned` message gains optional `photographerName` and `etaMinutes` for the background notification; plan I3 must send them (spec §5 updated). (5) Tiles show short prices (`1,2M` from the shared formatter where the mock has `1,19M`). (6) Release builds hide "Chụp ngay" until plan I6 ships a real `PaymentLauncher`. (7) "Late beyond 15 minutes" is measured from the first ETA this screen saw; the service still decides the rule through the dry run. (8) S48's elapsed time starts at `searchEndsAt − 10 min` (the mirror has no `paidAt`). (9) S12 for an instant request is linked by path (`/instant/:id/review`), and "Nhắn tin" by `/chat/:id`; neither screen exists yet. (10) An `assigned` push received in the foreground navigates to `/instant/:id` (ride-app behaviour) instead of showing a banner.
- **Placeholders:** none in the final code (Tasks 6 and 7 create temporary screen/view stubs that Tasks 7–10 replace within this plan).
- **Type consistency:** `InstantBookingRepository`, `FakeInstantBookingRepository` (`created`, `cancelCalls`, `confirmCalls`, `healthCalls`, `createError`, `packagesError`), `PaymentLauncher`/`PaymentStart`/`FakePaymentLauncher`, `PlaceSearch`/`PlaceSuggestion`/`FakePlaceSearch`/`PlaceSearchException`, `instantBookingRepositoryProvider`, `paymentLauncherProvider`, `placeSearchProvider`, `instantAvailableProvider`, `SearchPulse`, `InstantDraft`/`instantDraftProvider`, `InstantBookController`/`instantBookProvider`/`InstantSubmitResult`, `InstantCustomerActions`, `InstantRequestScreen`, the five views, `InstantHomeCard`, `InstantFindButton`, `InstantCustomerWorld`, `instantCustomerApp`, `FakeDispatchServer` and all widget keys are spelled the same in tests and code; the I4 names consumed are those I4 produces.
- **Risks:** Goong endpoint paths and JSON shapes are taken from Goong's public REST docs and must be confirmed with a real key (Task 3 says where to adapt); MapLibre platform views do not render in widget tests, so everything map-related is tested through `FakeMapEngine` and checked by hand on devices; `currentContactProvider` is `autoDispose` (plan 2a Task 8), kept alive by S47's controller with `ref.listen`; plan 3b4's Home/Find screens are modified by inserting one sliver each, so a later restructure of those screens must keep the entries; the fake dispatch service implements only what the apps need of spec §3–§4 and is not a substitute for I3's tests.
- **Battery and performance:** Task 15 adds idle tests for S47–S51 and S55 (via I4's sheet tests), counts fixes and location streams on the customer side, checks that the pulse runs only while searching and not under reduced motion, that clocks stop when the state changes, that S49 ticks every 15 s at rest, that the map exists only on S47/S49, that mirror listeners close with the screen, one health check per session, and the blur budget; the manual scenarios D/E join I4's A/B/C with spec §9 thresholds on Android and iOS.

