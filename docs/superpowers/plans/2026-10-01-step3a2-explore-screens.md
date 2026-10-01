# Step 3a2: Explore, Nearby Events and Area Picker (S13, S35, S36) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Explore tab shows the real S13 / S35 screens: location asked only when the user taps "Cho phép", "Để sau" remembered for 7 days, a manual area picker (S36), nearby events sorted by distance with radius and time filters, category tiles that lead to the Find screen, and the Explore tab badge with the "new events since you last looked" count.

**Architecture:** A `LocationController` (Riverpod `Notifier`) holds the permission state, an in-memory `ApproxLocation` and the saved manual area, and a pure function `resolveExplore` turns that state into one of six modes (`loading`, `ask`, `requesting`, `locating`, `chooseArea`, `nearby`). The events backend belongs to the later events plan, so nearby events come through a `NearbyEventsRepository` port with a fake and an empty production default. Only geohash prefixes (never coordinates) are passed to that port. `ExploreScreen` replaces the `ExploreTab` placeholder.

**Tech Stack:** Flutter, Riverpod 3, go_router, `shared_preferences`, `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3c, §3d.3 (Explore tab badge), §5 (S13, S35, S36), §7; `docs/superpowers/specs/screens/discovery.md` (S13, S35, S36); `docs/superpowers/specs/components/shared-components.md` (`ErrorState`, `AppSkeleton`, `LocationRepository`).

**Prerequisite:** `docs/superpowers/plans/2026-10-01-step3a1-location-foundations.md` is done (geo helpers, `AppChip`, `SegmentedTabs`, `showAppSheet`, `SliverAdaptiveRows`, `LocationPromptCard`, `LocationRepository`), plus the screen-codes and core-display-widgets plans (`ScreenCode`, `FreeTag`, `hostWidget`).

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Run `dart format lib test` before each commit (`require_trailing_commas` is a lint and `flutter analyze` fails on infos).
- Imports are `package:photobooking/...` only; features and `data/` import `package:photobooking/core/core.dart`; files inside `core/` import each other directly.
- No Firebase import anywhere in this plan. The events backend (Firestore adapter, rules, indexes) is the later events plan; here events come from a port with a fake.
- **Privacy (spec 3c.2):** exact coordinates exist only inside `ApproxLocation` / `ExploreOrigin` in memory. They are not written to `SharedPreferences`, not passed to any repository, not logged (`toString` is redacted). What is persisted: the saved area `{id, name, geohash5}`, `locationDeferredUntil` and `exploreSeenAt`. What is passed to the events port: geohash prefixes of length 2 to 5.
- No hard-coded UI text: Vietnamese strings with full diacritics in `lib/l10n/app_vi.arb`, then `flutter gen-l10n`. Free events show the tag "Không thu phí", never "0₫".
- Blur budget: at most 4 `BackdropFilter`s per screen and none inside another; list rows never blur (`NearbyEventTile` uses a translucent fill). Platform changes cover Android and iOS; this plan adds none (the manifests are checked in plan 3a1). iOS cannot be built on this machine yet (separate "iOS enablement" plan).
- One primary action per screen. No deprecated Flutter API (`flutter analyze` fails on infos). Layouts tested at width 320 and text scale 1.3.
- In widget tests every provider that reaches a platform or the network is overridden (`sharedPreferencesProvider`, `locationRepositoryProvider`, `nearbyEventsRepositoryProvider`, `authRepositoryProvider`, `userRepositoryProvider`) and `ProviderScope(retry: (_, _) => null)` is used so a failing provider does not leave a retry timer behind.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/data/clock/clock.dart` (create) | `clockProvider` (injectable "now", UTC) |
| `lib/data/location/area.dart` (create) | `AreaOption`, `SavedArea`, `AreaRepository`, `BuiltInAreaRepository`, `builtInAreas` |
| `lib/data/taxonomy/builtin_taxonomy.dart` (create) | `TaxonomyOption`, `kSpecialties`, `kStyles`, label lookups (built-in fallback of the future `taxonomy` collection) |
| `lib/features/explore/location_controller.dart` (create) | providers for the repositories, `LocationState`, `LocationController`, `ExploreMode`, `ExploreOrigin`, `resolveExplore`, `exploreResolutionProvider`, `areasProvider` |
| `lib/data/events/event_summary.dart` (create) | `EventType`, `EventStatus`, `EventSummary` read model |
| `lib/data/events/nearby_events_repository.dart` (create) | port, `FakeNearbyEventsRepository`, `EmptyNearbyEventsRepository`, provider |
| `lib/core/format.dart` (modify) | add `formatMoney` |
| `lib/features/explore/nearby_events.dart` (create) | `NearbyFilters`, `NearbyEvent`, `selectNearby`, filter controller, `nearbyEventsProvider`, `upcomingEventsProvider` |
| `lib/features/explore/explore_badge.dart` (create) | `exploreSeenAtProvider`, `exploreBadgeCountProvider` |
| `lib/features/shell/tab_badges.dart`, `tab_shell.dart` (modify) | Explore badge, mark seen on opening the tab |
| `lib/core/widgets/error_state.dart`, `app_skeleton.dart` (create) | minimal `ErrorState`, `AppSkeleton` |
| `lib/core/text_fold.dart` (create) | `foldVietnamese` (accent-insensitive search) |
| `lib/features/explore/area_picker_sheet.dart` (create) | S36 |
| `lib/features/explore/explore_links.dart`, `event_routes.dart` (create) | URL contract with the Find screen; "events routes exist" switch |
| `lib/features/explore/widgets/event_tile.dart` (create) | `NearbyEventTile` (stand-in until `EventCard` exists) |
| `lib/features/explore/explore_screen.dart` (create) | S13 / S35 |
| `lib/features/shell/placeholder_tabs.dart`, `lib/app/router.dart` (modify) | remove `ExploreTab`, route to `ExploreScreen` |
| `lib/l10n/app_vi.arb` (modify) | strings listed per task |
| `test/support/screen_host.dart`, `test/support/explore_world.dart` (create) | shared harness and fakes for Explore tests |
| `test/support/idle.dart`, `test/support/blur.dart` (create if missing) | idle and blur-budget helpers (Task 8) |
| `test/battery/explore_battery_test.dart` (create) | battery and performance checks (Task 8) |
| tests | listed per task |

---

### Task 1: Clock, areas, saved area and built-in taxonomy

**Files:**
- Create: `lib/data/clock/clock.dart`, `lib/data/location/area.dart`, `lib/data/taxonomy/builtin_taxonomy.dart`, `test/data/location/area_test.dart`, `test/data/taxonomy/builtin_taxonomy_test.dart`

**Interfaces:**
- Produces:
  - `final clockProvider = Provider<DateTime Function()>(...)` returning a UTC `DateTime`.
  - `class AreaOption { const AreaOption({required String id, required String name, required double lat, required double lng}); String get geohash5; SavedArea toSaved(); }` with value `==`.
  - `class SavedArea { const SavedArea({required String id, required String name, required String geohash5}); Map<String, dynamic> toJson(); factory SavedArea.fromJson(Map<String, dynamic>); ({double lat, double lng}) get center; }` — `fromJson` throws `FormatException` for a missing field or a geohash that is not 5 characters.
  - `abstract class AreaRepository { Future<List<AreaOption>> list(); }`, `class BuiltInAreaRepository implements AreaRepository` (`const`), `const List<AreaOption> builtInAreas` (12 entries, ids such as `hcm-q1`).
  - `class TaxonomyOption { const TaxonomyOption(this.id, this.labelVi); }`, `const kSpecialties`, `const kStyles`, `String specialtyLabel(String id)`, `String styleLabel(String id)` (return the id itself for unknown codes so old data still renders).

The area centres are district centres, not user positions, so they are plain constants. The labels are data (they mirror the `taxonomy` documents of the data model), not UI chrome, so they are not in the ARB file; plan 2c's real taxonomy repository replaces these lists.

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/location/area_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/location/area.dart';

void main() {
  test('built-in areas: unique ids, 12 entries, valid centres', () {
    expect(builtInAreas.length, greaterThan(8), reason: 'S36 shows search above 8');
    expect(builtInAreas.map((a) => a.id).toSet(), hasLength(builtInAreas.length));
    for (final a in builtInAreas) {
      expect(a.name.trim(), isNotEmpty);
      expect(a.geohash5, hasLength(5));
      expect(a.lat, inInclusiveRange(8, 24), reason: a.name);
      expect(a.lng, inInclusiveRange(102, 110), reason: a.name);
    }
    expect(builtInAreas.map((a) => a.name), contains('Quận 1, TP.HCM'));
  });

  test('the repository returns the built-in list', () async {
    expect(await const BuiltInAreaRepository().list(), builtInAreas);
  });

  test('a saved area keeps name, id and geohash5 only', () {
    final saved = builtInAreas.first.toSaved();
    final json = saved.toJson();
    expect(json.keys.toSet(), {'id', 'name', 'geohash5'});
    expect(SavedArea.fromJson(json), saved);
  });

  test('the centre of a saved area is inside its own cell', () {
    final a = builtInAreas.first;
    final c = a.toSaved().center;
    expect((c.lat - a.lat).abs(), lessThan(0.05));
    expect((c.lng - a.lng).abs(), lessThan(0.05));
  });

  test('fromJson rejects broken data', () {
    expect(() => SavedArea.fromJson({'id': 'x'}), throwsFormatException);
    expect(
      () => SavedArea.fromJson({'id': 'x', 'name': 'X', 'geohash5': 'abc'}),
      throwsFormatException,
    );
    expect(
      () => SavedArea.fromJson({'id': 'x', 'name': 'X', 'geohash5': 'zzzza'}),
      throwsFormatException,
      reason: '"a" is not a geohash character',
    );
  });
}
```

```dart
// test/data/taxonomy/builtin_taxonomy_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';

void main() {
  test('ids are unique stable codes and labels are Vietnamese text', () {
    for (final list in [kSpecialties, kStyles]) {
      expect(list.map((o) => o.id).toSet(), hasLength(list.length));
      for (final o in list) {
        expect(o.id, matches(RegExp(r'^[a-z_]+$')));
        expect(o.labelVi.trim(), isNotEmpty);
      }
    }
  });

  test('label lookups fall back to the code for unknown ids', () {
    expect(specialtyLabel('portrait'), 'Chân dung');
    expect(specialtyLabel('wedding'), 'Cưới');
    expect(specialtyLabel('underwater'), 'underwater');
    expect(styleLabel('natural_light'), 'Ánh sáng tự nhiên');
    expect(styleLabel('nope'), 'nope');
  });

  test('specialty codes match the data model catalogue', () {
    expect(kSpecialties.map((o) => o.id), [
      'portrait', 'wedding', 'couple', 'family', 'graduation', 'event',
      'product', 'travel', 'fashion', 'food', 'real_estate', 'newborn',
      'street', 'commercial',
    ]);
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/data/location/area_test.dart test/data/taxonomy/builtin_taxonomy_test.dart`
Expected: FAIL, libraries do not exist.

- [ ] **Step 3: Implement**

```dart
// lib/data/clock/clock.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Now" as a UTC instant. Tests override it to make time deterministic.
final clockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);
```

```dart
// lib/data/location/area.dart
import 'package:photobooking/core/core.dart';

/// A district or city the user can pick when location is off (S36).
class AreaOption {
  const AreaOption({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String name;

  /// Centre of the district; a public constant, not the user's position.
  final double lat;
  final double lng;

  String get geohash5 => encodeGeohash(lat, lng, precision: 5);

  SavedArea toSaved() => SavedArea(id: id, name: name, geohash5: geohash5);

  @override
  bool operator ==(Object other) =>
      other is AreaOption &&
      other.id == id &&
      other.name == name &&
      other.lat == lat &&
      other.lng == lng;

  @override
  int get hashCode => Object.hash(id, name, lat, lng);
}

/// What is remembered on the device: the area's name and its geohash cell.
class SavedArea {
  const SavedArea({
    required this.id,
    required this.name,
    required this.geohash5,
  });

  final String id;
  final String name;
  final String geohash5;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'geohash5': geohash5,
  };

  factory SavedArea.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final hash = json['geohash5'];
    if (id is! String || name is! String || hash is! String) {
      throw const FormatException('saved area is incomplete');
    }
    if (hash.length != 5) {
      throw const FormatException('geohash5 must have 5 characters');
    }
    try {
      decodeGeohash(hash);
    } on ArgumentError {
      throw const FormatException('geohash5 is not a geohash');
    }
    return SavedArea(id: id, name: name, geohash5: hash);
  }

  /// Centre of the cell, used as the origin for distances.
  ({double lat, double lng}) get center => decodeGeohash(geohash5);

  @override
  bool operator ==(Object other) =>
      other is SavedArea &&
      other.id == id &&
      other.name == name &&
      other.geohash5 == geohash5;

  @override
  int get hashCode => Object.hash(id, name, geohash5);
}

abstract class AreaRepository {
  Future<List<AreaOption>> list();
}

class BuiltInAreaRepository implements AreaRepository {
  const BuiltInAreaRepository();

  @override
  Future<List<AreaOption>> list() async => builtInAreas;
}

/// Used when the `taxonomy/areas` list cannot be loaded (spec S36, "lỗi tải
/// danh sách → dùng danh sách tích hợp sẵn").
const List<AreaOption> builtInAreas = [
  AreaOption(id: 'hcm-q1', name: 'Quận 1, TP.HCM', lat: 10.7769, lng: 106.7009),
  AreaOption(id: 'hcm-q3', name: 'Quận 3, TP.HCM', lat: 10.7840, lng: 106.6842),
  AreaOption(id: 'hcm-q7', name: 'Quận 7, TP.HCM', lat: 10.7340, lng: 106.7219),
  AreaOption(
    id: 'hcm-binh-thanh',
    name: 'Bình Thạnh, TP.HCM',
    lat: 10.8106,
    lng: 106.7091,
  ),
  AreaOption(
    id: 'hcm-thu-duc',
    name: 'Thủ Đức, TP.HCM',
    lat: 10.8494,
    lng: 106.7537,
  ),
  AreaOption(
    id: 'hn-hoan-kiem',
    name: 'Hoàn Kiếm, Hà Nội',
    lat: 21.0285,
    lng: 105.8542,
  ),
  AreaOption(
    id: 'hn-ba-dinh',
    name: 'Ba Đình, Hà Nội',
    lat: 21.0340,
    lng: 105.8190,
  ),
  AreaOption(
    id: 'hn-cau-giay',
    name: 'Cầu Giấy, Hà Nội',
    lat: 21.0333,
    lng: 105.7940,
  ),
  AreaOption(
    id: 'dn-hai-chau',
    name: 'Hải Châu, Đà Nẵng',
    lat: 16.0471,
    lng: 108.2208,
  ),
  AreaOption(id: 'hue', name: 'Huế', lat: 16.4637, lng: 107.5909),
  AreaOption(id: 'da-lat', name: 'Đà Lạt', lat: 11.9404, lng: 108.4583),
  AreaOption(id: 'nha-trang', name: 'Nha Trang', lat: 12.2388, lng: 109.1967),
];
```

```dart
// lib/data/taxonomy/builtin_taxonomy.dart
/// One entry of a stable-code catalogue (`taxonomy/skills/items/{id}`).
class TaxonomyOption {
  const TaxonomyOption(this.id, this.labelVi);
  final String id;
  final String labelVi;
}

/// Built-in copy of the specialty catalogue (data-model/domain-model.md §4).
/// The `taxonomy` repository of plan 2c supersedes it; ids never change.
const List<TaxonomyOption> kSpecialties = [
  TaxonomyOption('portrait', 'Chân dung'),
  TaxonomyOption('wedding', 'Cưới'),
  TaxonomyOption('couple', 'Cặp đôi'),
  TaxonomyOption('family', 'Gia đình'),
  TaxonomyOption('graduation', 'Kỷ yếu'),
  TaxonomyOption('event', 'Sự kiện'),
  TaxonomyOption('product', 'Sản phẩm'),
  TaxonomyOption('travel', 'Du lịch'),
  TaxonomyOption('fashion', 'Thời trang'),
  TaxonomyOption('food', 'Ẩm thực'),
  TaxonomyOption('real_estate', 'Bất động sản'),
  TaxonomyOption('newborn', 'Em bé'),
  TaxonomyOption('street', 'Đường phố'),
  TaxonomyOption('commercial', 'Thương mại'),
];

const List<TaxonomyOption> kStyles = [
  TaxonomyOption('natural_light', 'Ánh sáng tự nhiên'),
  TaxonomyOption('film', 'Film'),
  TaxonomyOption('minimal', 'Tối giản'),
  TaxonomyOption('editorial', 'Editorial'),
  TaxonomyOption('documentary', 'Tư liệu'),
];

String _label(List<TaxonomyOption> list, String id) {
  for (final o in list) {
    if (o.id == id) {
      return o.labelVi;
    }
  }
  return id;
}

String specialtyLabel(String id) => _label(kSpecialties, id);
String styleLabel(String id) => _label(kStyles, id);
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/data/location/area_test.dart test/data/taxonomy && flutter analyze`
Expected: PASS (5 + 3 tests); analyze clean. If the third `fromJson` case does not throw, `decodeGeohash` accepted a character it must reject: the alphabet excludes `a`, `i`, `l`, `o`.

- [ ] **Step 5: Commit**

```bash
git add lib/data test/data
git commit -m "feat(location): areas, saved area, clock and built-in taxonomy

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `LocationController` and the Explore mode resolution

**Files:**
- Create: `lib/features/explore/location_controller.dart`, `test/features/explore/location_controller_test.dart`

**Interfaces:**
- Consumes: `LocationRepository`, `ApproxLocation`, `FakeLocationRepository`, `GeolocatorLocationRepository`, `GeolocatorGateway` (3a1); `AreaOption`, `SavedArea`, `AreaRepository`, `BuiltInAreaRepository`, `builtInAreas` (Task 1); `clockProvider`; `sharedPreferencesProvider` from `lib/features/settings/theme_mode_controller.dart`.
- Produces (all in `location_controller.dart`):
  - `locationRepositoryProvider` (`Provider<LocationRepository>`, production = `GeolocatorLocationRepository(gateway: const GeolocatorGateway(), prefs: …)`), `areaRepositoryProvider` (`Provider<AreaRepository>`), `areasProvider` (`FutureProvider<List<AreaOption>>`, never errors: falls back to `builtInAreas`).
  - `class LocationState` — `loaded`, `permission`, `requesting`, `locating`, `location` (`ApproxLocation?`), `area` (`SavedArea?`), `deferredUntil` (`DateTime?`), `copyWith({…, bool clearLocation = false, bool clearArea = false})`.
  - `enum ExploreMode { loading, ask, requesting, locating, chooseArea, nearby }`.
  - `class ExploreOrigin { const ExploreOrigin({required double lat, required double lng, required bool fromDevice, String? areaName}); String get geohash5; String get geohash6; String cellPrefix(int precision); }` — value equality; redacted `toString`.
  - `class ExploreResolution { const ExploreResolution(ExploreMode mode, [ExploreOrigin? origin]); }`
  - `ExploreResolution resolveExplore(LocationState state, DateTime now)`.
  - `class LocationController extends Notifier<LocationState>` with `Future<void> refresh()`, `allow()`, `later()`, `chooseArea(AreaOption)`, `useDeviceLocation()`, `refreshLocation()`, `openSettings()`; constants `LocationController.areaKey = 'area'`, `deferredKey = 'locationDeferredUntil'`, `deferDays = 7`.
  - `locationControllerProvider` (`NotifierProvider<LocationController, LocationState>`), `exploreResolutionProvider` (`Provider<ExploreResolution>`).

Resolution rules: a saved manual area always wins (and needs no permission); otherwise `loaded == false` → `loading`; `requesting` → `requesting`; permission `granted` → `nearby` when there is a fix, `locating` while one is being fetched, else `chooseArea`; `notAsked` → `ask` unless "Để sau" was tapped less than 7 days ago (then `chooseArea`); `denied`, `deniedForever`, `serviceOff` → `chooseArea`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/explore/location_controller_test.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _t0 = DateTime.utc(2026, 10, 1, 5);
ApproxLocation _fix([DateTime? at]) =>
    ApproxLocation(lat: 10.7769, lng: 106.7009, capturedAt: at ?? _t0);

class _Clock {
  DateTime now = _t0;
}

class _Env {
  _Env(this.container, this.repo, this.prefs, this.clock);
  final ProviderContainer container;
  final LocationRepository repo;
  final SharedPreferences prefs;
  final _Clock clock;
  LocationController get ctrl =>
      container.read(locationControllerProvider.notifier);
  LocationState get state => container.read(locationControllerProvider);
  ExploreResolution get resolution => container.read(exploreResolutionProvider);
}

Future<_Env> _env({
  LocationRepository? repo,
  Map<String, Object> prefsValues = const {},
  List<Override> extra = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  final fake = repo ?? FakeLocationRepository();
  final clock = _Clock();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      locationRepositoryProvider.overrideWithValue(fake),
      clockProvider.overrideWithValue(() => clock.now),
      ...extra,
    ],
  );
  addTearDown(container.dispose);
  container.read(locationControllerProvider); // builds and starts refresh()
  await pumpEventQueue();
  return _Env(container, fake, prefs, clock);
}

/// A repository whose calls complete only when the test says so.
class _Gated extends FakeLocationRepository {
  _Gated({super.status, super.statusAfterRequest, super.location});
  final requestGate = Completer<void>();
  final locationGate = Completer<void>();
  @override
  Future<LocationPermissionStatus> request() async {
    await requestGate.future;
    return super.request();
  }

  @override
  Future<ApproxLocation?> currentApproxLocation({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await locationGate.future;
    return super.currentApproxLocation(timeout: timeout);
  }
}

void main() {
  group('first launch', () {
    test('not asked: the prompt card shows and nothing is requested', () async {
      final e = await _env();
      expect(e.resolution.mode, ExploreMode.ask);
      expect(e.resolution.origin, isNull);
      expect((e.repo as FakeLocationRepository).requestCalls, 0);
    });

    test('while the first status is being read the mode is loading', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          locationRepositoryProvider.overrideWithValue(FakeLocationRepository()),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(exploreResolutionProvider).mode, ExploreMode.loading);
    });
  });

  group('allow', () {
    test('granted with a fix: nearby from the device, request counted once', () async {
      final repo = FakeLocationRepository(location: _fix());
      final e = await _env(repo: repo);
      await e.ctrl.allow();
      expect(repo.requestCalls, 1);
      expect(e.state.requesting, isFalse);
      expect(e.resolution.mode, ExploreMode.nearby);
      expect(e.resolution.origin!.fromDevice, isTrue);
      expect(e.resolution.origin!.geohash5, _fix().geohash5);
    });

    test('shows requesting, then locating, while the platform works', () async {
      final repo = _Gated(location: _fix());
      final e = await _env(repo: repo);
      final done = e.ctrl.allow();
      await pumpEventQueue();
      expect(e.resolution.mode, ExploreMode.requesting);
      repo.requestGate.complete();
      await pumpEventQueue();
      expect(e.resolution.mode, ExploreMode.locating);
      repo.locationGate.complete();
      await done;
      expect(e.resolution.mode, ExploreMode.nearby);
    });

    test('denied: choose an area, and the OS is not asked again', () async {
      final repo = FakeLocationRepository(
        statusAfterRequest: LocationPermissionStatus.denied,
      );
      final e = await _env(repo: repo);
      await e.ctrl.allow();
      expect(e.state.permission, LocationPermissionStatus.denied);
      expect(e.resolution.mode, ExploreMode.chooseArea);
    });

    test('granted but no fix before the deadline: choose an area', () async {
      final e = await _env(repo: FakeLocationRepository()); // location == null
      await e.ctrl.allow();
      expect(e.state.permission, LocationPermissionStatus.granted);
      expect(e.resolution.mode, ExploreMode.chooseArea);
    });
  });

  group('other permission states', () {
    for (final s in [
      LocationPermissionStatus.denied,
      LocationPermissionStatus.deniedForever,
      LocationPermissionStatus.serviceOff,
    ]) {
      test('${s.name} resolves to choosing an area', () async {
        final e = await _env(repo: FakeLocationRepository(status: s));
        expect(e.resolution.mode, ExploreMode.chooseArea);
      });
    }

    test('already granted at start: nearby without any prompt', () async {
      final repo = FakeLocationRepository(
        status: LocationPermissionStatus.granted,
        location: _fix(),
      );
      final e = await _env(repo: repo);
      expect(e.resolution.mode, ExploreMode.nearby);
      expect(repo.requestCalls, 0);
    });

    test('openSettings goes to the repository', () async {
      final repo = FakeLocationRepository(
        status: LocationPermissionStatus.deniedForever,
      );
      final e = await _env(repo: repo);
      await e.ctrl.openSettings();
      expect(repo.openSettingsCalls, 1);
    });

    test('permission revoked in Settings: the fix is dropped on refresh', () async {
      final repo = FakeLocationRepository(
        status: LocationPermissionStatus.granted,
        location: _fix(),
      );
      final e = await _env(repo: repo);
      expect(e.resolution.mode, ExploreMode.nearby);
      repo.status = LocationPermissionStatus.deniedForever;
      await e.ctrl.refresh();
      expect(e.state.location, isNull);
      expect(e.resolution.mode, ExploreMode.chooseArea);
    });
  });

  group('"Để sau"', () {
    test('hides the card for 7 days and remembers across restarts', () async {
      final e = await _env();
      await e.ctrl.later();
      expect(e.resolution.mode, ExploreMode.chooseArea);
      expect(
        e.prefs.getString(LocationController.deferredKey),
        _t0.add(const Duration(days: 7)).toIso8601String(),
      );

      final again = await _env(prefsValues: {
        LocationController.deferredKey:
            _t0.add(const Duration(days: 7)).toIso8601String(),
      });
      expect(again.resolution.mode, ExploreMode.chooseArea);
    });

    test('after 7 days the card comes back', () async {
      final e = await _env();
      await e.ctrl.later();
      e.clock.now = _t0.add(const Duration(days: 7, seconds: 1));
      e.container.invalidate(exploreResolutionProvider);
      expect(e.resolution.mode, ExploreMode.ask);
    });
  });

  group('manual area', () {
    test('wins over the device, needs no permission, and stores no coordinates', () async {
      final repo = FakeLocationRepository(
        status: LocationPermissionStatus.granted,
        location: _fix(),
      );
      final e = await _env(repo: repo);
      await e.ctrl.chooseArea(builtInAreas.first);
      expect(e.resolution.mode, ExploreMode.nearby);
      expect(e.resolution.origin!.fromDevice, isFalse);
      expect(e.resolution.origin!.areaName, 'Quận 1, TP.HCM');

      final stored = jsonDecode(e.prefs.getString(LocationController.areaKey)!)
          as Map<String, dynamic>;
      expect(stored.keys.toSet(), {'id', 'name', 'geohash5'});
      expect(e.prefs.getKeys().any((k) => k.toLowerCase().contains('lat')), isFalse);
    });

    test('is restored on the next start, even when permission is denied', () async {
      final saved = builtInAreas[5].toSaved();
      final e = await _env(
        repo: FakeLocationRepository(status: LocationPermissionStatus.deniedForever),
        prefsValues: {LocationController.areaKey: jsonEncode(saved.toJson())},
      );
      expect(e.resolution.mode, ExploreMode.nearby);
      expect(e.resolution.origin!.areaName, 'Hoàn Kiếm, Hà Nội');
    });

    test('a corrupt stored value is ignored', () async {
      final e = await _env(prefsValues: {LocationController.areaKey: '{oops'});
      expect(e.state.area, isNull);
    });

    test('useDeviceLocation clears the area and goes back to the fix', () async {
      final repo = FakeLocationRepository(
        status: LocationPermissionStatus.granted,
        location: _fix(),
      );
      final e = await _env(repo: repo);
      await e.ctrl.chooseArea(builtInAreas.first);
      await e.ctrl.useDeviceLocation();
      expect(e.prefs.getString(LocationController.areaKey), isNull);
      expect(e.resolution.origin!.fromDevice, isTrue);
    });

    test('useDeviceLocation asks first when permission was never asked; a refusal keeps the area', () async {
      final repo = FakeLocationRepository(
        statusAfterRequest: LocationPermissionStatus.denied,
      );
      final e = await _env(repo: repo);
      await e.ctrl.chooseArea(builtInAreas.first);
      await e.ctrl.useDeviceLocation();
      expect(repo.requestCalls, 1);
      expect(e.state.area, isNotNull);
    });
  });

  group('fresh location', () {
    test('a fix older than 30 minutes is replaced on refreshLocation', () async {
      final repo = FakeLocationRepository(
        status: LocationPermissionStatus.granted,
        location: _fix(),
      );
      final e = await _env(repo: repo);
      expect(repo.locationCalls, 1);
      e.clock.now = _t0.add(const Duration(minutes: 31));
      repo.location = _fix(e.clock.now);
      await e.ctrl.refreshLocation();
      expect(repo.locationCalls, 2);
      expect(e.state.location!.capturedAt, e.clock.now);
    });

    test('a failed refresh keeps the previous fix while it is still usable', () async {
      final repo = FakeLocationRepository(
        status: LocationPermissionStatus.granted,
        location: _fix(),
      );
      final e = await _env(repo: repo);
      repo.location = null;
      await e.ctrl.refreshLocation();
      expect(e.state.location, isNotNull);
    });
  });

  test('ExploreOrigin never prints coordinates', () {
    const o = ExploreOrigin(lat: 10.7769, lng: 106.7009, fromDevice: true);
    expect(o.toString(), isNot(contains('10.77')));
    expect(o.cellPrefix(3), hasLength(3));
  });

  group('areasProvider', () {
    test('uses the repository list, and the built-in list when it fails', () async {
      final ok = await _env();
      expect(await ok.container.read(areasProvider.future), builtInAreas);

      final broken = await _env(
        extra: [areaRepositoryProvider.overrideWithValue(_Throwing())],
      );
      expect(await broken.container.read(areasProvider.future), builtInAreas);
    });
  });
}

class _Throwing implements AreaRepository {
  @override
  Future<List<AreaOption>> list() async => throw StateError('offline');
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/explore/location_controller_test.dart`
Expected: FAIL, `location_controller.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/explore/location_controller.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/geolocator_location_repository.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => GeolocatorLocationRepository(
    gateway: const GeolocatorGateway(),
    prefs: ref.watch(sharedPreferencesProvider),
  ),
);

final areaRepositoryProvider = Provider<AreaRepository>(
  (ref) => const BuiltInAreaRepository(),
);

/// The pickable areas; never fails, so S36 always has something to show.
final areasProvider = FutureProvider<List<AreaOption>>((ref) async {
  try {
    final list = await ref.watch(areaRepositoryProvider).list();
    return list.isEmpty ? builtInAreas : list;
  } catch (_) {
    return builtInAreas;
  }
});

@immutable
class LocationState {
  const LocationState({
    this.loaded = false,
    this.permission = LocationPermissionStatus.notAsked,
    this.requesting = false,
    this.locating = false,
    this.location,
    this.area,
    this.deferredUntil,
  });

  /// True once the permission status has been read at least once.
  final bool loaded;
  final LocationPermissionStatus permission;

  /// The OS dialog is open.
  final bool requesting;

  /// A fix is being fetched.
  final bool locating;
  final ApproxLocation? location;
  final SavedArea? area;
  final DateTime? deferredUntil;

  LocationState copyWith({
    bool? loaded,
    LocationPermissionStatus? permission,
    bool? requesting,
    bool? locating,
    ApproxLocation? location,
    bool clearLocation = false,
    SavedArea? area,
    bool clearArea = false,
    DateTime? deferredUntil,
  }) => LocationState(
    loaded: loaded ?? this.loaded,
    permission: permission ?? this.permission,
    requesting: requesting ?? this.requesting,
    locating: locating ?? this.locating,
    location: clearLocation ? null : (location ?? this.location),
    area: clearArea ? null : (area ?? this.area),
    deferredUntil: deferredUntil ?? this.deferredUntil,
  );
}

enum ExploreMode { loading, ask, requesting, locating, chooseArea, nearby }

/// Where "near me" is measured from. In memory only; see the privacy rules.
@immutable
class ExploreOrigin {
  const ExploreOrigin({
    required this.lat,
    required this.lng,
    required this.fromDevice,
    this.areaName,
  });

  final double lat;
  final double lng;
  final bool fromDevice;
  final String? areaName;

  String get geohash5 => cellPrefix(5);
  String get geohash6 => cellPrefix(6);
  String cellPrefix(int precision) =>
      encodeGeohash(lat, lng, precision: precision);

  @override
  bool operator ==(Object other) =>
      other is ExploreOrigin &&
      other.lat == lat &&
      other.lng == lng &&
      other.fromDevice == fromDevice &&
      other.areaName == areaName;

  @override
  int get hashCode => Object.hash(lat, lng, fromDevice, areaName);

  @override
  String toString() => 'ExploreOrigin(<redacted>)';
}

@immutable
class ExploreResolution {
  const ExploreResolution(this.mode, [this.origin]);
  final ExploreMode mode;
  final ExploreOrigin? origin;
}

ExploreResolution resolveExplore(LocationState s, DateTime now) {
  final area = s.area;
  if (area != null) {
    final c = area.center;
    return ExploreResolution(
      ExploreMode.nearby,
      ExploreOrigin(
        lat: c.lat,
        lng: c.lng,
        fromDevice: false,
        areaName: area.name,
      ),
    );
  }
  if (!s.loaded) {
    return const ExploreResolution(ExploreMode.loading);
  }
  if (s.requesting) {
    return const ExploreResolution(ExploreMode.requesting);
  }
  switch (s.permission) {
    case LocationPermissionStatus.granted:
      final fix = s.location;
      if (fix != null) {
        return ExploreResolution(
          ExploreMode.nearby,
          ExploreOrigin(lat: fix.lat, lng: fix.lng, fromDevice: true),
        );
      }
      return ExploreResolution(
        s.locating ? ExploreMode.locating : ExploreMode.chooseArea,
      );
    case LocationPermissionStatus.notAsked:
      final until = s.deferredUntil;
      return ExploreResolution(
        until != null && now.isBefore(until)
            ? ExploreMode.chooseArea
            : ExploreMode.ask,
      );
    case LocationPermissionStatus.denied:
    case LocationPermissionStatus.deniedForever:
    case LocationPermissionStatus.serviceOff:
      return const ExploreResolution(ExploreMode.chooseArea);
  }
}

class LocationController extends Notifier<LocationState> {
  static const areaKey = 'area';
  static const deferredKey = 'locationDeferredUntil';
  static const deferDays = 7;

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  LocationRepository get _repo => ref.read(locationRepositoryProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  LocationState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    Future.microtask(refresh);
    return LocationState(
      area: _readArea(prefs),
      deferredUntil: _readDeferred(prefs),
    );
  }

  static SavedArea? _readArea(SharedPreferences prefs) {
    final raw = prefs.getString(areaKey);
    if (raw == null) {
      return null;
    }
    try {
      return SavedArea.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static DateTime? _readDeferred(SharedPreferences prefs) {
    final raw = prefs.getString(deferredKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  /// Re-reads the permission (also on returning from the Settings app) and
  /// fetches a fix when allowed.
  Future<void> refresh() async {
    final status = await _repo.permissionStatus();
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      loaded: true,
      permission: status,
      clearLocation: status != LocationPermissionStatus.granted,
    );
    if (status == LocationPermissionStatus.granted) {
      await _locate();
    }
  }

  Future<void> _locate({bool force = false}) async {
    final current = state.location;
    if (!force && current != null && !current.isStale(_now())) {
      return;
    }
    state = state.copyWith(locating: true);
    final fresh = await _repo.currentApproxLocation();
    if (!ref.mounted) {
      return;
    }
    // Keep the previous fix when the new attempt fails (spec: use the old one).
    state = state.copyWith(locating: false, location: fresh ?? current);
  }

  /// The user tapped "Cho phép": the only place the OS dialog is opened.
  Future<void> allow() async {
    state = state.copyWith(requesting: true);
    final status = await _repo.request();
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      loaded: true,
      requesting: false,
      permission: status,
      clearLocation: status != LocationPermissionStatus.granted,
    );
    if (status == LocationPermissionStatus.granted) {
      await _locate(force: true);
    }
  }

  /// "Để sau": do not show the card again for [deferDays] days.
  Future<void> later() async {
    final until = _now().add(const Duration(days: deferDays));
    await _prefs.setString(deferredKey, until.toIso8601String());
    state = state.copyWith(deferredUntil: until);
  }

  Future<void> chooseArea(AreaOption option) async {
    final saved = option.toSaved();
    await _prefs.setString(areaKey, jsonEncode(saved.toJson()));
    state = state.copyWith(area: saved);
  }

  /// Back to "near me". Asks for permission first if it was never asked; if
  /// that is refused the chosen area stays.
  Future<void> useDeviceLocation() async {
    if (state.permission == LocationPermissionStatus.notAsked ||
        state.permission == LocationPermissionStatus.denied) {
      await allow();
      if (state.permission != LocationPermissionStatus.granted) {
        return;
      }
    }
    await _prefs.remove(areaKey);
    state = state.copyWith(clearArea: true);
    if (state.permission == LocationPermissionStatus.granted) {
      await _locate();
    }
  }

  /// Pull to refresh.
  Future<void> refreshLocation() async {
    await refresh();
    if (ref.mounted && state.permission == LocationPermissionStatus.granted) {
      await _locate(force: _isStale());
    }
  }

  bool _isStale() => state.location?.isStale(_now()) ?? true;

  Future<void> openSettings() => _repo.openSettings();
}

final locationControllerProvider =
    NotifierProvider<LocationController, LocationState>(
      LocationController.new,
    );

final exploreResolutionProvider = Provider<ExploreResolution>(
  (ref) => resolveExplore(
    ref.watch(locationControllerProvider),
    ref.watch(clockProvider)(),
  ),
);
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/features/explore/location_controller_test.dart && flutter analyze`
Expected: PASS (about 22 tests); analyze clean. The tests that read `exploreResolutionProvider` after moving the fake clock call `invalidate`, because the provider does not watch time; that is deliberate (a card should not appear while the user is looking at the screen).

- [ ] **Step 5: Commit**

```bash
git add lib/features/explore test/features/explore
git commit -m "feat(explore): location controller and Explore mode resolution

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Events read model, nearby port with a fake, selection logic, filters

**Files:**
- Create: `lib/data/events/event_summary.dart`, `lib/data/events/nearby_events_repository.dart`, `lib/features/explore/nearby_events.dart`, `test/data/events/nearby_events_repository_test.dart`, `test/features/explore/nearby_events_test.dart`
- Modify: `lib/core/format.dart`, `test/core/format_test.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Produces (`format.dart`): `String formatMoney(int vnd, {bool short = false})` → `1.500.000₫`; short: `250K`, `1,5M`, `8M`, `600K`; under 1000 → `500₫`.
- Produces (`event_summary.dart`):
  - `enum EventType { photoWalk, miniSession, workshop, cosplay, other }` with `String get code` (`photo_walk`, `mini_session`, `workshop`, `cosplay`, `other`) and `static EventType fromCode(String? code)` (unknown → `other`); `extension EventTypeX { String label(AppLocalizations l) }`.
  - `enum EventStatus { draft, open, full, closed, cancelled, completed }` with `code` (= the enum name) and `fromCode` (unknown → `closed`).
  - `class EventSummary` — `id`, `title`, `hostName`, `hostVerified`, `type`, `startsAt` (UTC), `locationName`, `geohash`, `lat`, `lng`, `priceVnd`, `capacity`, `registeredCount`, `heldCount`, `status`, `createdAt`, `coverUrl`; getters `isFree`, `seatsLeft`, `hasGeo`.
- Produces (`nearby_events_repository.dart`):
  - `abstract class NearbyEventsRepository { Future<List<EventSummary>> inCells(List<String> cells, {required DateTime from, int limit = 100}); Future<List<EventSummary>> upcoming({required DateTime from, int limit = 20}); Future<int> countCreatedSince({List<String>? cells, DateTime? since, int cap = 10}); }`
  - `FakeNearbyEventsRepository([List<EventSummary> events])` with `cellQueries` (list of the `cells` arguments received), `upcomingCalls`, `failWith` (`Object?`); `EmptyNearbyEventsRepository` (const); `nearbyEventsRepositoryProvider` (default `EmptyNearbyEventsRepository`; the events plan overrides it with the Firestore adapter).
- Produces (`nearby_events.dart`):
  - `class NearbyFilters` (`radiusKm = 25`, `thisWeek`, `weekend`, `freeOnly`; `copyWith`, value equality), `const kRadiusOptionsKm = [10.0, 25.0, 50.0]`.
  - `class NearbyEvent { const NearbyEvent({required EventSummary event, required double distanceKm}); }` (`distanceKm` already rounded to 0.1).
  - `List<NearbyEvent> selectNearby(List<EventSummary> events, {required double lat, required double lng, required NearbyFilters filters, required DateTime now})`.
  - `class NearbyFiltersController extends Notifier<NearbyFilters>` with `setRadius(double)`, `toggleThisWeek()`, `toggleWeekend()`, `toggleFree()`, `bool widen()` (next radius option; false if already the largest); `nearbyFiltersProvider`.
  - `nearbyEventsProvider` (`FutureProvider.autoDispose<List<NearbyEvent>>`), `upcomingEventsProvider` (`FutureProvider.autoDispose<List<EventSummary>>`).
- l10n: `eventTypePhotoWalk` "Photo walk", `eventTypeMiniSession` "Mini session", `eventTypeWorkshop` "Workshop", `eventTypeCosplay` "Cosplay", `eventTypeOther` "Khác", `eventSeatsLeft(n)` "Còn {n} chỗ", `eventSoldOut` "Hết chỗ", `eventMonthShort(month)` "T{month}".

Selection rules: only `open` and `full` events; start in the future; must have coordinates (events without geo stay out of "gần bạn" but remain in "Xem tất cả", spec 3c.2); distance is great-circle from the origin, the radius test uses the exact distance and the label shows it rounded; order is distance then start time; "Tuần này" means starting before the end of the Vietnamese week (Monday 00:00); "Cuối tuần" means a Vietnamese Saturday or Sunday within the next 7 days; "Không thu phí" means price 0.

- [ ] **Step 1: Write the failing tests**

Append to `test/core/format_test.dart` (inside `main`, add the import `import 'package:photobooking/core/format.dart';` is already present):

```dart
  test('formatMoney: full and short forms', () {
    expect(formatMoney(1500000), '1.500.000₫');
    expect(formatMoney(250000), '250.000₫');
    expect(formatMoney(500), '500₫');
    expect(formatMoney(1500000, short: true), '1,5M');
    expect(formatMoney(8000000, short: true), '8M');
    expect(formatMoney(250000, short: true), '250K');
    expect(formatMoney(600000, short: true), '600K');
    expect(formatMoney(1250, short: true), '1,3K');
    expect(formatMoney(999, short: true), '999₫');
    expect(formatMoney(12000000, short: true), '12M');
  });
```

```dart
// test/data/events/nearby_events_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';

final _now = DateTime.utc(2026, 10, 1, 5);

EventSummary event(
  String id, {
  double? lat = 10.78,
  double? lng = 106.70,
  int priceVnd = 250000,
  int capacity = 20,
  int registered = 5,
  int held = 0,
  EventStatus status = EventStatus.open,
  Duration startsIn = const Duration(days: 3),
  Duration createdAgo = const Duration(days: 1),
  String title = 'Photo walk',
}) => EventSummary(
  id: id,
  title: title,
  hostName: 'Quốc Bảo',
  hostVerified: true,
  type: EventType.photoWalk,
  startsAt: _now.add(startsIn),
  locationName: 'Công viên Bạch Đằng',
  geohash: lat == null ? null : encodeGeohash(lat, lng!),
  lat: lat,
  lng: lng,
  priceVnd: priceVnd,
  capacity: capacity,
  registeredCount: registered,
  heldCount: held,
  status: status,
  createdAt: _now.subtract(createdAgo),
);

void main() {
  group('EventSummary', () {
    test('free, seats left and geo flags', () {
      final e = event('a', priceVnd: 0, capacity: 10, registered: 6, held: 2);
      expect(e.isFree, isTrue);
      expect(e.seatsLeft, 2);
      expect(e.hasGeo, isTrue);
      expect(event('b', lat: null).hasGeo, isFalse);
      expect(event('c', capacity: 5, registered: 7).seatsLeft, 0);
    });

    test('codes round-trip and unknown codes are safe', () {
      expect(EventType.fromCode('mini_session'), EventType.miniSession);
      expect(EventType.fromCode('???'), EventType.other);
      expect(EventType.photoWalk.code, 'photo_walk');
      expect(EventStatus.fromCode('full'), EventStatus.full);
      expect(EventStatus.fromCode('???'), EventStatus.closed);
    });
  });

  group('FakeNearbyEventsRepository', () {
    test('inCells matches geohash prefixes, hides non-public and past events', () async {
      final repo = FakeNearbyEventsRepository([
        event('near'),
        event('far', lat: 21.03, lng: 105.85),
        event('draft', status: EventStatus.draft),
        event('past', startsIn: const Duration(days: -1)),
        event('nogeo', lat: null),
      ]);
      final cell = encodeGeohash(10.78, 106.70, precision: 3);
      final got = await repo.inCells([cell], from: _now);
      expect(got.map((e) => e.id), ['near']);
      expect(repo.cellQueries.single, [cell]);
    });

    test('upcoming lists public future events by start time', () async {
      final repo = FakeNearbyEventsRepository([
        event('b', startsIn: const Duration(days: 5)),
        event('a', startsIn: const Duration(days: 2)),
        event('x', status: EventStatus.cancelled),
      ]);
      expect((await repo.upcoming(from: _now)).map((e) => e.id), ['a', 'b']);
      expect(repo.upcomingCalls, 1);
    });

    test('countCreatedSince counts new events, within cells, capped', () async {
      final repo = FakeNearbyEventsRepository([
        for (var i = 0; i < 12; i++)
          event('e$i', createdAgo: Duration(hours: i + 1)),
        event('old', createdAgo: const Duration(days: 30)),
      ]);
      expect(await repo.countCreatedSince(), 10, reason: 'capped at 10');
      expect(
        await repo.countCreatedSince(since: _now.subtract(const Duration(hours: 3, minutes: 30))),
        3,
      );
      expect(await repo.countCreatedSince(cells: ['zzz']), 0);
    });

    test('failWith makes every call throw', () async {
      final repo = FakeNearbyEventsRepository()..failWith = StateError('offline');
      expect(() => repo.upcoming(from: _now), throwsStateError);
      expect(() => repo.inCells(['w'], from: _now), throwsStateError);
      expect(() => repo.countCreatedSince(), throwsStateError);
    });
  });

  test('the production default has no events', () async {
    const repo = EmptyNearbyEventsRepository();
    expect(await repo.inCells(['w'], from: _now), isEmpty);
    expect(await repo.upcoming(from: _now), isEmpty);
    expect(await repo.countCreatedSince(), 0);
  });
}
```

```dart
// test/features/explore/nearby_events_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/explore/nearby_events.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/events/nearby_events_repository_test.dart' show event;

// Thursday 1 Oct 2026, 12:00 in Vietnam. Origin: central Ho Chi Minh City.
final _now = DateTime.utc(2026, 10, 1, 5);
const _lat = 10.7769;
const _lng = 106.7009;

void main() {
  group('selectNearby', () {
    final a = event('a', lat: 10.7869, lng: 106.7009, title: 'A 1,1 km');
    final b = event('b', lat: 10.8369, lng: 106.7009, title: 'B 6,7 km');
    final c = event('c', lat: 11.0, lng: 106.7, title: 'C 24,8 km');
    final d = event('d', lat: 11.2, lng: 106.7, title: 'D 47 km');

    List<String> ids(List<NearbyEvent> r) => r.map((e) => e.event.id).toList();

    test('sorts by distance and rounds the label distance to 0.1 km', () {
      final r = selectNearby(
        [c, a, b],
        lat: _lat,
        lng: _lng,
        filters: const NearbyFilters(),
        now: _now,
      );
      expect(ids(r), ['a', 'b', 'c']);
      expect(r.map((e) => e.distanceKm), [1.1, 6.7, 24.8]);
    });

    test('radius limits the list; 50 km brings the far one in', () {
      final all = [a, b, c, d];
      expect(
        ids(selectNearby(all, lat: _lat, lng: _lng, filters: const NearbyFilters(), now: _now)),
        ['a', 'b', 'c'],
      );
      expect(
        ids(selectNearby(all, lat: _lat, lng: _lng, filters: const NearbyFilters(radiusKm: 10), now: _now)),
        ['a', 'b'],
      );
      expect(
        ids(selectNearby(all, lat: _lat, lng: _lng, filters: const NearbyFilters(radiusKm: 50), now: _now)),
        ['a', 'b', 'c', 'd'],
      );
    });

    test('equal distances fall back to the earlier start', () {
      final x = event('x', lat: 10.7869, lng: 106.7009, startsIn: const Duration(days: 4));
      final y = event('y', lat: 10.7869, lng: 106.7009, startsIn: const Duration(days: 2));
      final r = selectNearby([x, y], lat: _lat, lng: _lng, filters: const NearbyFilters(), now: _now);
      expect(ids(r), ['y', 'x']);
    });

    test('drops events without geo, cancelled, draft and past; keeps full ones', () {
      final r = selectNearby(
        [
          event('nogeo', lat: null),
          event('cancelled', lat: 10.78, lng: 106.70, status: EventStatus.cancelled),
          event('draft', lat: 10.78, lng: 106.70, status: EventStatus.draft),
          event('past', lat: 10.78, lng: 106.70, startsIn: const Duration(hours: -2)),
          event('full', lat: 10.78, lng: 106.70, status: EventStatus.full),
        ],
        lat: _lat,
        lng: _lng,
        filters: const NearbyFilters(),
        now: _now,
      );
      expect(ids(r), ['full']);
    });

    test('"Tuần này" ends at Monday 00:00 Vietnam time', () {
      final sundayNight = event('sun', lat: 10.78, lng: 106.70, startsIn: const Duration(days: 3, hours: 11)); // Sun 23:00 VN
      final mondayAfter = event('mon', lat: 10.78, lng: 106.70, startsIn: const Duration(days: 3, hours: 12, minutes: 30)); // Mon 00:30 VN
      final r = selectNearby(
        [sundayNight, mondayAfter],
        lat: _lat,
        lng: _lng,
        filters: const NearbyFilters(thisWeek: true),
        now: _now,
      );
      expect(ids(r), ['sun']);
    });

    test('"Cuối tuần" keeps Saturday and Sunday within the next 7 days', () {
      final sat = event('sat', lat: 10.78, lng: 106.70, startsIn: const Duration(days: 2)); // Sat 3 Oct
      final tue = event('tue', lat: 10.78, lng: 106.70, startsIn: const Duration(days: 5)); // Tue
      final nextSat = event('next', lat: 10.78, lng: 106.70, startsIn: const Duration(days: 9)); // Sat 10 Oct
      final r = selectNearby(
        [sat, tue, nextSat],
        lat: _lat,
        lng: _lng,
        filters: const NearbyFilters(weekend: true),
        now: _now,
      );
      expect(ids(r), ['sat']);
    });

    test('"Không thu phí" keeps price 0 only', () {
      final free = event('free', lat: 10.78, lng: 106.70, priceVnd: 0);
      final paid = event('paid', lat: 10.78, lng: 106.70);
      final r = selectNearby([free, paid], lat: _lat, lng: _lng, filters: const NearbyFilters(freeOnly: true), now: _now);
      expect(ids(r), ['free']);
    });
  });

  group('NearbyFiltersController', () {
    ProviderContainer make() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('defaults and toggles', () {
      final c = make();
      expect(c.read(nearbyFiltersProvider), const NearbyFilters());
      final n = c.read(nearbyFiltersProvider.notifier);
      n.toggleFree();
      n.toggleWeekend();
      n.toggleThisWeek();
      n.setRadius(10);
      expect(c.read(nearbyFiltersProvider), const NearbyFilters(radiusKm: 10, thisWeek: true, weekend: true, freeOnly: true));
      n.toggleFree();
      expect(c.read(nearbyFiltersProvider).freeOnly, isFalse);
    });

    test('widen steps 10 -> 25 -> 50 and then says no', () {
      final c = make();
      final n = c.read(nearbyFiltersProvider.notifier);
      n.setRadius(10);
      expect(n.widen(), isTrue);
      expect(c.read(nearbyFiltersProvider).radiusKm, 25);
      expect(n.widen(), isTrue);
      expect(c.read(nearbyFiltersProvider).radiusKm, 50);
      expect(n.widen(), isFalse);
      expect(c.read(nearbyFiltersProvider).radiusKm, 50);
    });
  });

  group('nearbyEventsProvider', () {
    Future<(ProviderContainer, FakeNearbyEventsRepository, SharedPreferences)> make({
      LocationPermissionStatus status = LocationPermissionStatus.granted,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = FakeNearbyEventsRepository([
        event('a', lat: 10.7869, lng: 106.7009),
        event('b', lat: 10.8369, lng: 106.7009),
        event('far', lat: 21.03, lng: 105.85),
      ]);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(() => _now),
          nearbyEventsRepositoryProvider.overrideWithValue(repo),
          locationRepositoryProvider.overrideWithValue(
            FakeLocationRepository(
              status: status,
              location: ApproxLocation(lat: _lat, lng: _lng, capturedAt: _now),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(locationControllerProvider);
      await pumpEventQueue();
      return (container, repo, prefs);
    }

    test('returns nearby events sorted by distance', () async {
      final (c, _, _) = await make();
      final r = await c.read(nearbyEventsProvider.future);
      expect(r.map((e) => e.event.id), ['a', 'b']);
    });

    test('without an origin there is nothing to query', () async {
      final (c, repo, _) = await make(status: LocationPermissionStatus.deniedForever);
      expect(await c.read(nearbyEventsProvider.future), isEmpty);
      expect(repo.cellQueries, isEmpty);
    });

    test('only geohash prefixes reach the repository, never coordinates', () async {
      final (c, repo, prefs) = await make();
      await c.read(nearbyEventsProvider.future);
      final cells = repo.cellQueries.single;
      expect(cells, hasLength(9));
      for (final cell in cells) {
        expect(cell.length, inInclusiveRange(2, 5));
        expect(cell, matches(RegExp(r'^[0-9bcdefghjkmnpqrstuvwxyz]+$')));
      }
      expect(cells.first, startsWith('w3'), reason: 'cell around Ho Chi Minh City');
      // The default radius (25 km) uses 3-character cells.
      expect(cells.every((x) => x.length == 3), isTrue);
      expect(prefs.getKeys(), isNot(contains('lat')));
    });

    test('a smaller radius queries longer, tighter cells', () async {
      final (c, repo, _) = await make();
      c.read(nearbyFiltersProvider.notifier).setRadius(10);
      await c.read(nearbyEventsProvider.future);
      expect(repo.cellQueries.last.every((x) => x.length == 4), isTrue);
    });

    test('changing a filter reloads with the new filter', () async {
      final (c, _, _) = await make();
      await c.read(nearbyEventsProvider.future);
      c.read(nearbyFiltersProvider.notifier).setRadius(10);
      final r = await c.read(nearbyEventsProvider.future);
      expect(r.map((e) => e.event.id), ['a', 'b']);
      c.read(nearbyFiltersProvider.notifier).toggleFree();
      expect(await c.read(nearbyEventsProvider.future), isEmpty);
    });

    test('upcomingEventsProvider lists events regardless of location', () async {
      final (c, repo, _) = await make(status: LocationPermissionStatus.deniedForever);
      final r = await c.read(upcomingEventsProvider.future);
      expect(r, hasLength(3));
      expect(repo.upcomingCalls, 1);
    });
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/core/format_test.dart test/data/events test/features/explore/nearby_events_test.dart`
Expected: FAIL (missing libraries, `formatMoney` undefined).

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb` (before the final `}`, comma after the previous entry), then `flutter gen-l10n`:

```json
  "eventTypePhotoWalk": "Photo walk",
  "eventTypeMiniSession": "Mini session",
  "eventTypeWorkshop": "Workshop",
  "eventTypeCosplay": "Cosplay",
  "eventTypeOther": "Khác",
  "eventSeatsLeft": "Còn {n} chỗ",
  "@eventSeatsLeft": {
    "placeholders": {
      "n": {"type": "int"}
    }
  },
  "eventSoldOut": "Hết chỗ",
  "eventMonthShort": "T{month}",
  "@eventMonthShort": {
    "placeholders": {
      "month": {"type": "int"}
    }
  }
```

Append to `lib/core/format.dart`:

```dart
/// `1.500.000₫`; with [short] `1,5M` / `250K` for small cards.
String formatMoney(int vnd, {bool short = false}) {
  String grouped(int n) {
    final s = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        out.write('.');
      }
      out.write(s[i]);
    }
    return out.toString();
  }

  String compact(double v, String unit) {
    final rounded = (v * 10).round() / 10;
    final text = rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toStringAsFixed(1).replaceAll('.', ',');
    return '$text$unit';
  }

  if (!short || vnd < 1000) {
    return '${grouped(vnd)}₫';
  }
  if (vnd >= 1000000) {
    return compact(vnd / 1000000, 'M');
  }
  return compact(vnd / 1000, 'K');
}
```

```dart
// lib/data/events/event_summary.dart
import 'dart:math' as math;

import 'package:photobooking/l10n/app_localizations.dart';

enum EventType {
  photoWalk('photo_walk'),
  miniSession('mini_session'),
  workshop('workshop'),
  cosplay('cosplay'),
  other('other');

  const EventType(this.code);
  final String code;

  static EventType fromCode(String? code) => values.firstWhere(
    (t) => t.code == code,
    orElse: () => EventType.other,
  );
}

extension EventTypeX on EventType {
  String label(AppLocalizations l) => switch (this) {
    EventType.photoWalk => l.eventTypePhotoWalk,
    EventType.miniSession => l.eventTypeMiniSession,
    EventType.workshop => l.eventTypeWorkshop,
    EventType.cosplay => l.eventTypeCosplay,
    EventType.other => l.eventTypeOther,
  };
}

enum EventStatus {
  draft,
  open,
  full,
  closed,
  cancelled,
  completed;

  String get code => name;

  static EventStatus fromCode(String? code) => values.firstWhere(
    (s) => s.name == code,
    orElse: () => EventStatus.closed,
  );
}

/// What a list or card needs to know about an event. The full `Event` entity
/// (registrations, hashtag, chat) arrives with the events plan.
class EventSummary {
  const EventSummary({
    required this.id,
    required this.title,
    required this.hostName,
    required this.hostVerified,
    required this.type,
    required this.startsAt,
    required this.priceVnd,
    required this.capacity,
    required this.registeredCount,
    required this.heldCount,
    required this.status,
    required this.createdAt,
    this.locationName,
    this.geohash,
    this.lat,
    this.lng,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String hostName;
  final bool hostVerified;
  final EventType type;

  /// UTC instant.
  final DateTime startsAt;
  final String? locationName;

  /// Venue geohash (9 characters in storage); null when the event has no geo.
  final String? geohash;
  final double? lat;
  final double? lng;

  /// Integer VND; 0 means free.
  final int priceVnd;
  final int capacity;
  final int registeredCount;
  final int heldCount;
  final EventStatus status;
  final DateTime createdAt;
  final String? coverUrl;

  bool get isFree => priceVnd == 0;
  int get seatsLeft => math.max(0, capacity - registeredCount - heldCount);
  bool get hasGeo => lat != null && lng != null;
}
```

```dart
// lib/data/events/nearby_events_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/events/event_summary.dart';

/// Reads events for Explore. The Firestore adapter (query by geohash prefix on
/// `events (location.geohash, startAt)`) is part of the events plan.
abstract class NearbyEventsRepository {
  /// Public events starting at or after [from] whose geohash starts with one
  /// of [cells] (prefixes of length 2 to 5). Only prefixes are passed in: the
  /// user's coordinates never reach a repository.
  Future<List<EventSummary>> inCells(
    List<String> cells, {
    required DateTime from,
    int limit = 100,
  });

  /// Public upcoming events anywhere, soonest first ("Sự kiện chụp ảnh").
  Future<List<EventSummary>> upcoming({
    required DateTime from,
    int limit = 20,
  });

  /// Events created after [since] (all of them when null), optionally inside
  /// [cells], at most [cap]: the number on the Explore tab.
  Future<int> countCreatedSince({
    List<String>? cells,
    DateTime? since,
    int cap = 10,
  });
}

bool _isPublic(EventSummary e) =>
    e.status == EventStatus.open || e.status == EventStatus.full;

class FakeNearbyEventsRepository implements NearbyEventsRepository {
  FakeNearbyEventsRepository([List<EventSummary> events = const []])
    : _events = List.of(events);

  final List<EventSummary> _events;

  /// Every `cells` argument received by [inCells], for privacy assertions.
  final List<List<String>> cellQueries = [];
  int upcomingCalls = 0;

  /// When set, every call throws it.
  Object? failWith;

  void add(EventSummary event) => _events.add(event);

  bool _inCells(EventSummary e, List<String>? cells) {
    if (cells == null) {
      return true;
    }
    final hash = e.geohash;
    return hash != null && cells.any(hash.startsWith);
  }

  @override
  Future<List<EventSummary>> inCells(
    List<String> cells, {
    required DateTime from,
    int limit = 100,
  }) async {
    if (failWith != null) {
      throw failWith!;
    }
    cellQueries.add(List.unmodifiable(cells));
    final out = _events
        .where((e) => _isPublic(e) && !e.startsAt.isBefore(from))
        .where((e) => _inCells(e, cells))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return out.take(limit).toList();
  }

  @override
  Future<List<EventSummary>> upcoming({
    required DateTime from,
    int limit = 20,
  }) async {
    if (failWith != null) {
      throw failWith!;
    }
    upcomingCalls++;
    final out = _events
        .where((e) => _isPublic(e) && !e.startsAt.isBefore(from))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return out.take(limit).toList();
  }

  @override
  Future<int> countCreatedSince({
    List<String>? cells,
    DateTime? since,
    int cap = 10,
  }) async {
    if (failWith != null) {
      throw failWith!;
    }
    final n = _events
        .where((e) => _isPublic(e) && _inCells(e, cells))
        .where((e) => since == null || e.createdAt.isAfter(since))
        .length;
    return n < cap ? n : cap;
  }
}

/// The production default until the events backend exists: no events.
class EmptyNearbyEventsRepository implements NearbyEventsRepository {
  const EmptyNearbyEventsRepository();

  @override
  Future<List<EventSummary>> inCells(
    List<String> cells, {
    required DateTime from,
    int limit = 100,
  }) async => const [];

  @override
  Future<List<EventSummary>> upcoming({
    required DateTime from,
    int limit = 20,
  }) async => const [];

  @override
  Future<int> countCreatedSince({
    List<String>? cells,
    DateTime? since,
    int cap = 10,
  }) async => 0;
}

final nearbyEventsRepositoryProvider = Provider<NearbyEventsRepository>(
  (ref) => const EmptyNearbyEventsRepository(),
);
```

```dart
// lib/features/explore/nearby_events.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';

/// Radius chips of S35.
const kRadiusOptionsKm = [10.0, 25.0, 50.0];

@immutable
class NearbyFilters {
  const NearbyFilters({
    this.radiusKm = 25,
    this.thisWeek = false,
    this.weekend = false,
    this.freeOnly = false,
  });

  final double radiusKm;
  final bool thisWeek;
  final bool weekend;
  final bool freeOnly;

  NearbyFilters copyWith({
    double? radiusKm,
    bool? thisWeek,
    bool? weekend,
    bool? freeOnly,
  }) => NearbyFilters(
    radiusKm: radiusKm ?? this.radiusKm,
    thisWeek: thisWeek ?? this.thisWeek,
    weekend: weekend ?? this.weekend,
    freeOnly: freeOnly ?? this.freeOnly,
  );

  @override
  bool operator ==(Object other) =>
      other is NearbyFilters &&
      other.radiusKm == radiusKm &&
      other.thisWeek == thisWeek &&
      other.weekend == weekend &&
      other.freeOnly == freeOnly;

  @override
  int get hashCode => Object.hash(radiusKm, thisWeek, weekend, freeOnly);
}

@immutable
class NearbyEvent {
  const NearbyEvent({required this.event, required this.distanceKm});
  final EventSummary event;

  /// Rounded to 0.1 km.
  final double distanceKm;
}

List<NearbyEvent> selectNearby(
  List<EventSummary> events, {
  required double lat,
  required double lng,
  required NearbyFilters filters,
  required DateTime now,
}) {
  final weekEnd = endOfVnWeek(now);
  final weekendHorizon = now.add(const Duration(days: 7));
  final matches = <(double, EventSummary)>[];
  for (final e in events) {
    if (e.status != EventStatus.open && e.status != EventStatus.full) {
      continue;
    }
    if (e.startsAt.isBefore(now) || !e.hasGeo) {
      continue;
    }
    final km = haversineKm(lat, lng, e.lat!, e.lng!);
    if (km > filters.radiusKm) {
      continue;
    }
    if (filters.thisWeek && !e.startsAt.isBefore(weekEnd)) {
      continue;
    }
    if (filters.weekend &&
        !(isVnWeekend(e.startsAt) && e.startsAt.isBefore(weekendHorizon))) {
      continue;
    }
    if (filters.freeOnly && !e.isFree) {
      continue;
    }
    matches.add((km, e));
  }
  matches.sort((a, b) {
    final byDistance = a.$1.compareTo(b.$1);
    return byDistance != 0 ? byDistance : a.$2.startsAt.compareTo(b.$2.startsAt);
  });
  return [
    for (final (km, e) in matches)
      NearbyEvent(event: e, distanceKm: roundKm(km)),
  ];
}

class NearbyFiltersController extends Notifier<NearbyFilters> {
  @override
  NearbyFilters build() => const NearbyFilters();

  void setRadius(double km) => state = state.copyWith(radiusKm: km);
  void toggleThisWeek() => state = state.copyWith(thisWeek: !state.thisWeek);
  void toggleWeekend() => state = state.copyWith(weekend: !state.weekend);
  void toggleFree() => state = state.copyWith(freeOnly: !state.freeOnly);

  /// Moves to the next larger radius; false when already at the largest.
  bool widen() {
    for (final km in kRadiusOptionsKm) {
      if (km > state.radiusKm) {
        state = state.copyWith(radiusKm: km);
        return true;
      }
    }
    return false;
  }
}

final nearbyFiltersProvider =
    NotifierProvider<NearbyFiltersController, NearbyFilters>(
      NearbyFiltersController.new,
    );

/// Events around the current origin. Distances are computed here, on the
/// device; the repository only ever sees geohash prefixes.
final nearbyEventsProvider = FutureProvider.autoDispose<List<NearbyEvent>>((
  ref,
) async {
  final origin = ref.watch(exploreResolutionProvider.select((r) => r.origin));
  if (origin == null) {
    return const [];
  }
  final filters = ref.watch(nearbyFiltersProvider);
  final now = ref.watch(clockProvider)();
  final precision = geohashPrecisionForRadiusKm(filters.radiusKm);
  final cells = geohashCells(origin.cellPrefix(precision));
  final events = await ref
      .watch(nearbyEventsRepositoryProvider)
      .inCells(cells, from: now);
  return selectNearby(
    events,
    lat: origin.lat,
    lng: origin.lng,
    filters: filters,
    now: now,
  );
});

/// "Sự kiện chụp ảnh" when there is no location: upcoming events anywhere.
final upcomingEventsProvider = FutureProvider.autoDispose<List<EventSummary>>((
  ref,
) {
  final now = ref.watch(clockProvider)();
  return ref.watch(nearbyEventsRepositoryProvider).upcoming(from: now);
});
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/core/format_test.dart test/data/events test/features/explore && flutter analyze`
Expected: PASS; analyze clean. The test file `nearby_events_test.dart` imports the `event(...)` builder from the repository test with `show event`; a test file importing another test file is fine because `main` is not run twice. If analyze complains about `formatMoney(1250, short: true)`, the expected `1,3K` comes from `(1.25 * 10).round() / 10 == 1.3` (round half away from zero).

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(explore): event read model, nearby port with fake, selection and filters

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Explore tab badge and "seen" marker

**Files:**
- Create: `lib/features/explore/explore_badge.dart`, `test/features/explore/explore_badge_test.dart`
- Modify: `lib/features/shell/tab_badges.dart`, `lib/features/shell/tab_shell.dart`

**Interfaces:**
- Consumes: `NearbyEventsRepository.countCreatedSince`, `exploreResolutionProvider`, `geohashCells`, `geohashPrecisionForRadiusKm`, `clockProvider`, `sharedPreferencesProvider`.
- Produces:
  - `class ExploreSeenAtController extends Notifier<DateTime?>` with `static const key = 'exploreSeenAt'` and `Future<void> markSeen()`; `exploreSeenAtProvider`.
  - `exploreBadgeCountProvider` (`FutureProvider<int>`): number of events created since `exploreSeenAt` (all events when never seen), inside the 25 km cells of the current origin, or everywhere when there is no location or area (spec 3d.3), capped at 10.
  - `tabBadgesProvider` now returns `{AppTab.explore: n}` when `n > 0` (still `Provider<Map<AppTab, int>>`; the Work badge is added by step 5 in the same function).
  - `TabShell`: choosing the Explore destination calls `markSeen()`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/explore/explore_badge_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/explore/explore_badge.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:photobooking/features/shell/tab_badges.dart';
import 'package:photobooking/features/shell/tab_shell.dart';
import 'package:photobooking/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/events/nearby_events_repository_test.dart' show event;

final _now = DateTime.utc(2026, 10, 1, 5);

/// Three events created 1h, 2h, 3h ago, one 20 days ago, all in Ho Chi Minh City.
FakeNearbyEventsRepository _repo({int newEvents = 3}) => FakeNearbyEventsRepository([
  for (var i = 0; i < newEvents; i++)
    event('e$i', createdAgo: Duration(hours: i + 1)),
  event('old', createdAgo: const Duration(days: 20)),
]);

Future<(ProviderContainer, SharedPreferences)> _make({
  Map<String, Object> prefsValues = const {},
  int newEvents = 3,
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => _now),
      nearbyEventsRepositoryProvider.overrideWithValue(_repo(newEvents: newEvents)),
      locationRepositoryProvider.overrideWithValue(FakeLocationRepository()),
    ],
  );
  addTearDown(c.dispose);
  return (c, prefs);
}

void main() {
  test('never seen: counts every public event, no location needed', () async {
    final (c, _) = await _make();
    expect(await c.read(exploreBadgeCountProvider.future), 4);
  });

  test('counts only events created after the last visit', () async {
    final (c, _) = await _make(
      prefsValues: {
        ExploreSeenAtController.key: _now
            .subtract(const Duration(hours: 2, minutes: 30))
            .toIso8601String(),
      },
    );
    expect(await c.read(exploreBadgeCountProvider.future), 2);
  });

  test('markSeen stores the time and clears the count', () async {
    final (c, prefs) = await _make();
    expect(await c.read(exploreBadgeCountProvider.future), 4);
    await c.read(exploreSeenAtProvider.notifier).markSeen();
    expect(prefs.getString(ExploreSeenAtController.key), _now.toIso8601String());
    expect(await c.read(exploreBadgeCountProvider.future), 0);
  });

  test('the count is capped at ten', () async {
    final (c, _) = await _make(newEvents: 14);
    expect(await c.read(exploreBadgeCountProvider.future), 10);
  });

  test('with an area chosen only that area is counted', () async {
    final (c, _) = await _make();
    // Hoàn Kiếm (Hanoi): the fake events are in Ho Chi Minh City.
    await c.read(locationControllerProvider.notifier).chooseArea(builtInAreas[5]);
    expect(await c.read(exploreBadgeCountProvider.future), 0);
  });

  test('tabBadgesProvider shows Explore only when there is something new', () async {
    final (c, _) = await _make();
    await c.read(exploreBadgeCountProvider.future);
    expect(c.read(tabBadgesProvider), {AppTab.explore: 4});
    await c.read(exploreSeenAtProvider.notifier).markSeen();
    await c.read(exploreBadgeCountProvider.future);
    expect(c.read(tabBadgesProvider), isEmpty);
  });

  testWidgets('choosing the Explore tab clears the badge and stores the time', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
    await users.ensureProfile(u);
    await users.setRole(u.uid, UserRole.customer);
    final router = GoRouter(
      initialLocation: AppTab.home.path,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => TabShell(shell),
          branches: [
            for (final t in AppTab.values)
              StatefulShellBranch(
                routes: [
                  GoRoute(path: t.path, builder: (_, _) => Text('page-${t.name}')),
                ],
              ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(() => _now),
          authRepositoryProvider.overrideWithValue(auth),
          userRepositoryProvider.overrideWithValue(users),
          nearbyEventsRepositoryProvider.overrideWithValue(_repo()),
          locationRepositoryProvider.overrideWithValue(FakeLocationRepository()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.text('Khám phá'));
    await tester.pumpAndSettle();
    expect(find.text('page-explore'), findsOneWidget);
    expect(find.text('4'), findsNothing);
    expect(prefs.getString(ExploreSeenAtController.key), _now.toIso8601String());
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/explore/explore_badge_test.dart`
Expected: FAIL, `explore_badge.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/explore/explore_badge.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

/// When the viewer last opened the Explore tab (spec 3d.3).
class ExploreSeenAtController extends Notifier<DateTime?> {
  static const key = 'exploreSeenAt';

  @override
  DateTime? build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(key);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> markSeen() async {
    final now = ref.read(clockProvider)();
    state = now;
    await ref.read(sharedPreferencesProvider).setString(key, now.toIso8601String());
  }
}

final exploreSeenAtProvider =
    NotifierProvider<ExploreSeenAtController, DateTime?>(
      ExploreSeenAtController.new,
    );

/// New events since the last visit: inside the 25 km cells of the current
/// origin, or everywhere while there is no location or area. At most 10, so
/// the tab shows "9+".
final exploreBadgeCountProvider = FutureProvider<int>((ref) {
  final seenAt = ref.watch(exploreSeenAtProvider);
  final origin = ref.watch(exploreResolutionProvider.select((r) => r.origin));
  final cells = origin == null
      ? null
      : geohashCells(origin.cellPrefix(geohashPrecisionForRadiusKm(25)));
  return ref
      .watch(nearbyEventsRepositoryProvider)
      .countCreatedSince(cells: cells, since: seenAt);
});
```

Replace `lib/features/shell/tab_badges.dart` with:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/features/explore/explore_badge.dart';

/// Count shown on each bottom-bar tab; a missing tab shows no badge.
///
/// Explore: new events since the viewer last opened it (cleared on visit).
/// Work (photographer): requests waiting for an answer (added by step 5).
final tabBadgesProvider = Provider<Map<AppTab, int>>((ref) {
  final explore = ref.watch(exploreBadgeCountProvider).value ?? 0;
  return {if (explore > 0) AppTab.explore: explore};
});
```

In `lib/features/shell/tab_shell.dart` add `import 'package:photobooking/features/explore/explore_badge.dart';` and replace the `onDestinationSelected` argument with:

```dart
          onDestinationSelected: (i) {
            if (specs[i].tab == AppTab.explore) {
              ref.read(exploreSeenAtProvider.notifier).markSeen();
            }
            shell.goBranch(i, initialLocation: i == shell.currentIndex);
          },
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/features/explore/explore_badge_test.dart && flutter analyze && flutter test`
Expected: PASS (7 tests); analyze clean; the whole suite is still green (`TabShell` is not mounted by other tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features test/features/explore
git commit -m "feat(explore): Explore tab badge for new events, cleared on opening the tab

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `ErrorState`, `AppSkeleton` and accent-insensitive search

**Files:**
- Create: `lib/core/widgets/error_state.dart`, `lib/core/widgets/app_skeleton.dart`, `lib/core/text_fold.dart`, `test/core/widgets/error_state_test.dart`, `test/core/widgets/app_skeleton_test.dart`, `test/core/text_fold_test.dart`
- Modify: `lib/core/core.dart`

**Interfaces:**
- Consumes: `hostWidget`, `AppButton`, l10n `retry` ("Thử lại", already in the ARB).
- Produces:
  - `const ErrorState({super.key, required String message, VoidCallback? onRetry})` — message, and an outline "Thử lại" button (key `error-retry`) only when `onRetry` is given.
  - `AppSkeleton.box({Key? key, double? width, required double height, double radius = AppRadius.lg})`, `AppSkeleton.line({Key? key, double? width, double height = 12})`, `AppSkeleton.card({Key? key, double height = 120})` — pulsing placeholder blocks; static under `MediaQuery.disableAnimations`; excluded from semantics.
  - `String foldVietnamese(String s)` — lower-case with Vietnamese diacritics removed (`đ` → `d`), for accent-insensitive search.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/widgets/error_state_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('shows the message and a retry button that works', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      hostWidget(ErrorState(message: 'Không có kết nối', onRetry: () => retried++)),
    );
    expect(find.text('Không có kết nối'), findsOneWidget);
    await tester.tap(find.byKey(const Key('error-retry')));
    expect(retried, 1);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('without a handler there is no button', (tester) async {
    await tester.pumpWidget(hostWidget(const ErrorState(message: 'Lỗi')));
    expect(find.byKey(const Key('error-retry')), findsNothing);
  });

  testWidgets('fits 320dp at 1.3x', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        ErrorState(
          message: 'Không tải được sự kiện. Kiểm tra mạng rồi thử lại nhé bạn.',
          onRetry: () {},
        ),
        width: 320,
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
```

```dart
// test/core/widgets/app_skeleton_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('box, line and card have the requested sizes', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        const Column(
          children: [
            AppSkeleton.box(key: Key('box'), width: 80, height: 40),
            AppSkeleton.line(key: Key('line'), width: 120),
            AppSkeleton.card(key: Key('card'), height: 90),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('box'))), const Size(80, 40));
    expect(tester.getSize(find.byKey(const Key('line'))), const Size(120, 12));
    expect(tester.getSize(find.byKey(const Key('card'))).height, 90);
  });

  testWidgets('pulses normally, is static under reduced motion', (tester) async {
    await tester.pumpWidget(
      hostWidget(const AppSkeleton.box(height: 20, width: 20)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(
      hostWidget(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const AppSkeleton.box(height: 20, width: 20),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('is hidden from screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(hostWidget(const AppSkeleton.line()));
    expect(
      find.descendant(
        of: find.byType(AppSkeleton),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
```

```dart
// test/core/text_fold_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/text_fold.dart';

void main() {
  test('removes Vietnamese diacritics and lower-cases', () {
    expect(foldVietnamese('Quận 1, TP.HCM'), 'quan 1, tp.hcm');
    expect(foldVietnamese('Đà Lạt'), 'da lat');
    expect(foldVietnamese('Thủ Đức'), 'thu duc');
    expect(foldVietnamese('HOÀN KIẾM'), 'hoan kiem');
    expect(foldVietnamese('Nguyễn Thị Phương'), 'nguyen thi phuong');
    expect(foldVietnamese('ửỡữ ẳẵ ệ ỵ ơ ư'), 'uou aa e y o u');
  });

  test('plain ASCII is only lower-cased', () {
    expect(foldVietnamese('Hello World 123'), 'hello world 123');
    expect(foldVietnamese(''), '');
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/core/widgets/error_state_test.dart test/core/widgets/app_skeleton_test.dart test/core/text_fold_test.dart`
Expected: FAIL (missing libraries).

- [ ] **Step 3: Implement**

```dart
// lib/core/text_fold.dart
const _groups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<String, String> _fold = {
  for (final e in _groups.entries)
    for (final c in e.value.split('')) c: e.key,
};

/// Lower-case, with Vietnamese accents removed: "Thủ Đức" -> "thu duc". Use
/// it on both sides of a search so "quan 1" finds "Quận 1".
String foldVietnamese(String s) =>
    s.toLowerCase().split('').map((c) => _fold[c] ?? c).join();
```

```dart
// lib/core/widgets/error_state.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_button.dart';

/// A short Vietnamese message and, when there is something to retry, a
/// "Thử lại" button.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.cloud_off_outlined, color: theme.colorScheme.error),
          const SizedBox(height: AppSpace.s3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpace.s4),
            AppButton.outline(
              context.l10n.retry,
              key: const Key('error-retry'),
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
```

```dart
// lib/core/widgets/app_skeleton.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Placeholder blocks shown while content loads. They have the shape of the
/// content they stand in for, pulse gently and stop under reduced motion.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton.box({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.lg,
  });

  const AppSkeleton.line({super.key, this.width, this.height = 12})
    : radius = AppRadius.md;

  const AppSkeleton.card({super.key, this.height = 120})
    : width = null,
      radius = AppRadius.lg + 8;

  final double? width;
  final double height;
  final double radius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.secondary;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Opacity(
          opacity: 0.55 + 0.45 * _c.value,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(widget.radius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Export `error_state.dart`, `app_skeleton.dart` and `text_fold.dart` from `core.dart`.

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/core/widgets/error_state_test.dart test/core/widgets/app_skeleton_test.dart test/core/text_fold_test.dart && flutter analyze`
Expected: PASS (3 + 3 + 2 tests); analyze clean. The static-under-reduced-motion assertion needs `_c.stop()` to leave `isAnimating` false; if `tester.hasRunningAnimations` stays true because of the first widget's ticker, the second `pumpWidget` replaces the whole tree, so the old controller is disposed.

- [ ] **Step 5: Commit**

```bash
git add lib/core test/core
git commit -m "feat(core): ErrorState, AppSkeleton and foldVietnamese

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: S36 area picker sheet

**Files:**
- Create: `lib/features/explore/area_picker_sheet.dart`, `test/support/screen_host.dart`, `test/features/explore/area_picker_sheet_test.dart`
- Modify: `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `showAppSheet`, `AppButton`, `foldVietnamese`, `ScreenCode`/`ScreenCodes.pickArea`, `LocationController`, `areasProvider`.
- Produces:
  - `Future<void> showAreaPicker(BuildContext context)` and `class AreaPickerSheet extends ConsumerStatefulWidget`.
  - Keys: `area-search`, `area-use-device`, `area-<id>` per row (for example `area-hcm-q1`), `area-open-settings`, `area-use`.
  - Test harness `screenApp({required Widget home, List<Override> overrides = const [], Brightness brightness = Brightness.dark, double textScale = 1.0})` and `screenRouterApp({required GoRouter router, … same options …})` in `test/support/screen_host.dart`.
  - l10n: `areaPickerTitle` "Chọn khu vực của bạn", `areaPickerBody` "Vị trí đang tắt. Chọn khu vực để xem sự kiện quanh đó, hoặc bật vị trí trong Cài đặt.", `areaPickerOpenSettings` "Mở Cài đặt để bật vị trí", `areaPickerUse` "Dùng khu vực này", `areaPickerUseDevice` "Dùng vị trí của tôi", `areaPickerSearch` "Tìm quận, thành phố", `areaPickerNoMatch` "Không tìm thấy khu vực".

Behaviour: radio-style rows (one selected), pre-selected with the saved area (or "Dùng vị trí của tôi" when location is on and no area is saved); a search field above 8 areas that ignores accents; "Dùng vị trí của tôi" appears while permission is `granted`, `notAsked` or `denied`; "Mở Cài đặt…" appears only for `deniedForever` (spec S36); the primary button is disabled until something is selected; closing without choosing changes nothing. The sheet is opened imperatively (`showAreaPicker`), not through a `/explore/area` route (see Self-Review).

- [ ] **Step 1: Write the failing test**

```dart
// test/support/screen_host.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// Hosts a screen the way the app does, with the given provider overrides.
/// `retry` is off so a failing provider does not leave a retry timer running.
Widget screenApp({
  required Widget home,
  List<Override> overrides = const [],
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
}) {
  return ProviderScope(
    retry: (_, _) => null,
    overrides: overrides,
    child: MaterialApp(
      theme: brightness == Brightness.dark ? buildDarkTheme() : buildLightTheme(),
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: home,
    ),
  );
}

/// Same, for screens that navigate.
Widget screenRouterApp({
  required GoRouter router,
  List<Override> overrides = const [],
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
}) {
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
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
  );
}
```

```dart
// test/features/explore/area_picker_sheet_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/area_picker_sheet.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/screen_host.dart';

final _t0 = DateTime.utc(2026, 10, 1, 5);

class _Throwing implements AreaRepository {
  @override
  Future<List<AreaOption>> list() async => throw StateError('offline');
}

Future<(Widget, SharedPreferences, FakeLocationRepository)> _app({
  LocationPermissionStatus status = LocationPermissionStatus.notAsked,
  Map<String, Object> prefsValues = const {},
  AreaRepository? areas,
  double width = 390,
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  final repo = FakeLocationRepository(
    status: status,
    location: ApproxLocation(lat: 10.7769, lng: 106.7009, capturedAt: _t0),
  );
  final widget = screenApp(
    textScale: textScale,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      locationRepositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(() => _t0),
      if (areas != null) areaRepositoryProvider.overrideWithValue(areas),
    ],
    home: Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAreaPicker(context),
            child: const Text('mở'),
          ),
        ),
      ),
    ),
  );
  return (widget, prefs, repo);
}

Future<void> _open(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  await tester.tap(find.text('mở'));
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, String key) => tester
        .widget<FilledButton>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(FilledButton),
          ),
        )
        .onPressed !=
    null;

void main() {
  testWidgets('lists the areas under the explanation, nothing chosen yet', (
    tester,
  ) async {
    final (app, _, _) = await _app();
    await _open(tester, app);
    expect(find.text('Chọn khu vực của bạn'), findsOneWidget);
    expect(
      find.text('Vị trí đang tắt. Chọn khu vực để xem sự kiện quanh đó, hoặc bật vị trí trong Cài đặt.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('area-hcm-q1')), findsOneWidget);
    expect(_enabled(tester, 'area-use'), isFalse);
  });

  testWidgets('choosing a row enables the button; confirming saves and closes', (
    tester,
  ) async {
    final (app, prefs, _) = await _app();
    await _open(tester, app);
    await tester.tap(find.byKey(const Key('area-hcm-q3')));
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'area-use'), isTrue);
    await tester.tap(find.byKey(const Key('area-use')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn khu vực của bạn'), findsNothing);
    final saved = jsonDecode(prefs.getString(LocationController.areaKey)!) as Map;
    expect(saved['id'], 'hcm-q3');
    expect(saved.containsKey('lat'), isFalse);
  });

  testWidgets('closing without choosing changes nothing', (tester) async {
    final (app, prefs, _) = await _app();
    await _open(tester, app);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(prefs.getString(LocationController.areaKey), isNull);
  });

  testWidgets('the saved area is preselected', (tester) async {
    final (app, _, _) = await _app(
      prefsValues: {
        LocationController.areaKey: jsonEncode(builtInAreas[5].toSaved().toJson()),
      },
    );
    await _open(tester, app);
    await tester.ensureVisible(find.byKey(const Key('area-hn-hoan-kiem')));
    await tester.pumpAndSettle();
    final selected = tester.getSemantics(find.byKey(const Key('area-hn-hoan-kiem')));
    expect(selected.label, contains('Hoàn Kiếm'));
    expect(_enabled(tester, 'area-use'), isTrue);
  });

  testWidgets('search ignores accents and shows a no-match message', (tester) async {
    final (app, _, _) = await _app();
    await _open(tester, app);
    expect(find.byKey(const Key('area-search')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('area-search')), 'quan 1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('area-hcm-q1')), findsOneWidget);
    expect(find.byKey(const Key('area-hcm-q3')), findsNothing);
    await tester.enterText(find.byKey(const Key('area-search')), 'xyz');
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy khu vực'), findsOneWidget);
  });

  testWidgets('open-settings button only for denied-forever, and it works', (
    tester,
  ) async {
    final (app, _, repo) = await _app(status: LocationPermissionStatus.deniedForever);
    await _open(tester, app);
    expect(find.byKey(const Key('area-use-device')), findsNothing);
    await tester.tap(find.byKey(const Key('area-open-settings')));
    expect(repo.openSettingsCalls, 1);

    final (plain, _, _) = await _app(status: LocationPermissionStatus.notAsked);
    await tester.pumpWidget(const SizedBox());
    await _open(tester, plain);
    expect(find.byKey(const Key('area-open-settings')), findsNothing);
  });

  testWidgets('"Dùng vị trí của tôi" is offered and switches back to the device', (
    tester,
  ) async {
    final (app, prefs, _) = await _app(
      status: LocationPermissionStatus.granted,
      prefsValues: {
        LocationController.areaKey: jsonEncode(builtInAreas.first.toSaved().toJson()),
      },
    );
    await _open(tester, app);
    await tester.tap(find.byKey(const Key('area-use-device')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('area-use')));
    await tester.pumpAndSettle();
    expect(prefs.getString(LocationController.areaKey), isNull);
  });

  testWidgets('a list that fails to load falls back to the built-in areas', (
    tester,
  ) async {
    final (app, _, _) = await _app(areas: _Throwing());
    await _open(tester, app);
    expect(find.byKey(const Key('area-hcm-q1')), findsOneWidget);
  });

  testWidgets('fits 320x568 at 1.3x with the main button always reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (app, _, _) = await _app(textScale: 1.3);
    await _open(tester, app);
    expect(tester.takeException(), isNull);
    final button = tester.getRect(find.byKey(const Key('area-use')));
    expect(button.height, 52);
    expect(button.bottom, lessThanOrEqualTo(568));
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/features/explore/area_picker_sheet_test.dart`
Expected: FAIL, `area_picker_sheet.dart` does not exist.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb` (comma after the previous last entry), then `flutter gen-l10n`:

```json
  "areaPickerTitle": "Chọn khu vực của bạn",
  "areaPickerBody": "Vị trí đang tắt. Chọn khu vực để xem sự kiện quanh đó, hoặc bật vị trí trong Cài đặt.",
  "areaPickerOpenSettings": "Mở Cài đặt để bật vị trí",
  "areaPickerUse": "Dùng khu vực này",
  "areaPickerUseDevice": "Dùng vị trí của tôi",
  "areaPickerSearch": "Tìm quận, thành phố",
  "areaPickerNoMatch": "Không tìm thấy khu vực"
```

```dart
// lib/features/explore/area_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';

const _deviceId = '__device__';

/// S36: pick a district or city when location is off. Opened from S13, S35
/// and S04.
Future<void> showAreaPicker(BuildContext context) =>
    showAppSheet<void>(context, builder: (_) => const AreaPickerSheet());

class AreaPickerSheet extends ConsumerStatefulWidget {
  const AreaPickerSheet({super.key});

  @override
  ConsumerState<AreaPickerSheet> createState() => _AreaPickerSheetState();
}

class _AreaPickerSheetState extends ConsumerState<AreaPickerSheet> {
  String? _selected;
  bool _seeded = false;
  String _query = '';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final location = ref.watch(locationControllerProvider);
    final areas = ref.watch(areasProvider).value ?? const <AreaOption>[];
    if (!_seeded && location.loaded) {
      _seeded = true;
      _selected =
          location.area?.id ??
          (location.permission == LocationPermissionStatus.granted &&
                  location.location != null
              ? _deviceId
              : null);
    }
    final offersDevice = switch (location.permission) {
      LocationPermissionStatus.granted ||
      LocationPermissionStatus.notAsked ||
      LocationPermissionStatus.denied => true,
      _ => false,
    };
    final folded = foldVietnamese(_query.trim());
    final shown = folded.isEmpty
        ? areas
        : areas.where((a) => foldVietnamese(a.name).contains(folded)).toList();

    return ScreenCode(
      ScreenCodes.pickArea,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s5,
              0,
              AppSpace.s5,
              AppSpace.s3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(l.areaPickerTitle, style: theme.textTheme.titleLarge),
                ),
                const SizedBox(height: AppSpace.s1),
                Text(l.areaPickerBody, style: theme.textTheme.bodySmall),
                if (areas.length > 8) ...[
                  const SizedBox(height: AppSpace.s3),
                  TextField(
                    key: const Key('area-search'),
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l.areaPickerSearch,
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
              children: [
                if (offersDevice && folded.isEmpty)
                  _AreaRow(
                    key: const Key('area-use-device'),
                    label: l.areaPickerUseDevice,
                    icon: Icons.my_location_outlined,
                    selected: _selected == _deviceId,
                    onTap: () => setState(() => _selected = _deviceId),
                  ),
                for (final a in shown)
                  _AreaRow(
                    key: Key('area-${a.id}'),
                    label: a.name,
                    selected: _selected == a.id,
                    onTap: () => setState(() => _selected = a.id),
                  ),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.s4),
                    child: Text(
                      l.areaPickerNoMatch,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpace.s5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (location.permission ==
                    LocationPermissionStatus.deniedForever) ...[
                  AppButton.outline(
                    l.areaPickerOpenSettings,
                    key: const Key('area-open-settings'),
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => ref
                        .read(locationControllerProvider.notifier)
                        .openSettings(),
                  ),
                  const SizedBox(height: AppSpace.s2),
                ],
                AppButton.primary(
                  l.areaPickerUse,
                  key: const Key('area-use'),
                  loading: _saving,
                  onPressed: _selected == null
                      ? null
                      : () => _confirm(areas),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(List<AreaOption> areas) async {
    final id = _selected;
    if (id == null) {
      return;
    }
    setState(() => _saving = true);
    final controller = ref.read(locationControllerProvider.notifier);
    if (id == _deviceId) {
      await controller.useDeviceLocation();
    } else {
      await controller.chooseArea(areas.firstWhere((a) => a.id == id));
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(controlRadius),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s3,
              vertical: AppSpace.s2,
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? scheme.primary : scheme.outline,
                ),
                const SizedBox(width: AppSpace.s3),
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: AppSpace.s2),
                ],
                Expanded(child: Text(label)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter gen-l10n && flutter test test/features/explore/area_picker_sheet_test.dart && flutter analyze`
Expected: PASS (9 tests); analyze clean. The "preselected" test scrolls the row into view first because rows below the fold have no semantics node.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(explore): S36 area picker sheet

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: S13 / S35 Explore screen, links and routing

**Files:**
- Create: `lib/features/explore/explore_links.dart`, `lib/features/explore/event_routes.dart`, `lib/features/explore/widgets/event_tile.dart`, `lib/features/explore/explore_screen.dart`, `test/features/explore/explore_links_test.dart`, `test/features/explore/widgets/event_tile_test.dart`, `test/features/explore/explore_screen_test.dart`
- Modify: `lib/features/shell/placeholder_tabs.dart` (delete `ExploreTab`), `lib/app/router.dart`, `lib/l10n/app_vi.arb`, `docs/superpowers/specs/2026-10-01-remaining-screens.md` (3c.2 note)

**Interfaces:**
- Consumes: everything from Tasks 1–6 and plan 3a1; `currentProfileProvider` (role), `FreeTag`, `formatMoney`, `formatDistance`, `toVn`.
- Produces:
  - `String findPhotographersPath({String? specialty, String? style, String? area})` → `/action`, `/action?specialty=portrait` … (URL contract: plan 3b4's Find screen reads these query parameters).
  - `eventRoutesReadyProvider` (`Provider<bool>`, default `false`), `eventListPath()` = `/events`, `eventPath(id)` = `/e/<id>`. The events plan overrides the default with `true`. While it is `false`, event rows are not tappable and "Xem tất cả" is hidden, so no tap leads to a missing route.
  - `NearbyEventTile({super.key, required EventSummary event, String? distanceLabel, VoidCallback? onTap})` (stand-in for `EventCard.row`, which arrives with the events plan).
  - `enum ExploreCategoryTab { services, places, styles, photographers }`, `ExploreScreen({super.key})`.
  - Keys: `explore-change`, `filter-radius-<km>` (10/25/50), `filter-this-week`, `filter-weekend`, `filter-free`, `explore-widen`, `explore-see-all`, `category-<tabname>-<id>`, `event-tile-<id>`.
  - l10n: `exploreAround(area)` "Quanh {area} · vị trí gần đúng", `exploreAroundMe` "Quanh bạn · vị trí gần đúng", `exploreChange` "Đổi", `exploreRadius(km)` "{km} km", `exploreThisWeek` "Tuần này", `exploreWeekend` "Cuối tuần", `exploreNearbyTitle` "Sự kiện gần bạn", `exploreEventsTitle` "Sự kiện chụp ảnh", `exploreSeeAll` "Xem tất cả", `exploreNoneNearby` "Chưa có sự kiện gần bạn", `exploreWiden` "Tăng bán kính", `exploreTabServices` "Dịch vụ", `exploreTabPlaces` "Địa điểm", `exploreTabStyles` "Phong cách", `explorePhotographersAll` "Xem tất cả nhiếp ảnh gia", `exploreLoadError` "Không tải được sự kiện. Kiểm tra mạng rồi thử lại." (the fourth tab reuses `tabFind`-style text: its label is `exploreTabPhotographers` "Thợ ảnh").

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/explore/explore_links_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/explore/explore_links.dart';

void main() {
  test('plain and filtered Find links', () {
    expect(findPhotographersPath(), '/action');
    expect(findPhotographersPath(specialty: 'portrait'), '/action?specialty=portrait');
    expect(findPhotographersPath(style: 'film'), '/action?style=film');
    expect(findPhotographersPath(area: 'hcm-q1'), '/action?area=hcm-q1');
    expect(
      findPhotographersPath(specialty: 'wedding', area: 'hn-hoan-kiem'),
      '/action?specialty=wedding&area=hn-hoan-kiem',
    );
  });
}
```

```dart
// test/features/explore/widgets/event_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/features/explore/widgets/event_tile.dart';

import '../../../core/widgets/widget_host.dart';
import '../../../data/events/nearby_events_repository_test.dart' show event;

void main() {
  testWidgets('shows date block, title, distance and place, price and seats', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        NearbyEventTile(
          event: event('a', title: 'Photo walk phố cổ', priceVnd: 250000, capacity: 20, registered: 17),
          distanceLabel: '1,2 km',
        ),
      ),
    );
    expect(find.text('04'), findsOneWidget, reason: 'Sunday 4 Oct in Vietnam time');
    expect(find.text('T10'), findsOneWidget);
    expect(find.text('Photo walk phố cổ'), findsOneWidget);
    expect(find.text('1,2 km · Công viên Bạch Đằng'), findsOneWidget);
    expect(find.text('250K'), findsOneWidget);
    expect(find.text('Còn 3 chỗ'), findsOneWidget);
    expect(find.text('Photo walk'), findsOneWidget, reason: 'type tag');
  });

  testWidgets('a free event shows the tag and never 0₫', (tester) async {
    await tester.pumpWidget(hostWidget(NearbyEventTile(event: event('a', priceVnd: 0))));
    expect(find.text('Không thu phí'), findsOneWidget);
    expect(find.textContaining('0₫'), findsNothing);
  });

  testWidgets('sold out says so in words', (tester) async {
    await tester.pumpWidget(
      hostWidget(NearbyEventTile(event: event('a', capacity: 5, registered: 5))),
    );
    expect(find.text('Hết chỗ'), findsOneWidget);
  });

  testWidgets('tapping calls onTap only when given', (tester) async {
    var taps = 0;
    await tester.pumpWidget(hostWidget(NearbyEventTile(event: event('a'), onTap: () => taps++)));
    await tester.tap(find.byType(NearbyEventTile));
    expect(taps, 1);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320dp at 1.3x on ${b.name}', (tester) async {
      await tester.pumpWidget(
        hostWidget(
          NearbyEventTile(
            event: event('a', title: 'Workshop ánh sáng tự nhiên buổi sáng sớm', priceVnd: 0),
            distanceLabel: '12,4 km',
          ),
          width: 320,
          textScale: 1.3,
          brightness: b,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
```

The date block shows the event's Vietnam calendar day: the fixture event starts at `2026-10-04 05:00Z`, which is Sunday 4 October 12:00 in Vietnam.

The shared world used by the screen tests here and by the battery test (Task 8):

```dart
// test/support/explore_world.dart
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/explore/event_routes.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/events/nearby_events_repository_test.dart' show event;

/// Thursday 1 Oct 2026, 12:00 in Vietnam.
final exploreNow = DateTime.utc(2026, 10, 1, 5);

/// Device position used by the tests: central Ho Chi Minh City.
const exploreFix = (lat: 10.7769, lng: 106.7009);

/// 1,1 km, 6,7 km, 24,8 km and 47 km from [exploreFix].
final exploreEvents = [
  event('near', title: 'Photo walk phố cổ', lat: 10.7869, lng: 106.7009),
  event('mid', title: 'Mini session mùa thu', lat: 10.8369, lng: 106.7009, priceVnd: 600000, startsIn: const Duration(days: 10)),
  event('free', title: 'Workshop ánh sáng', lat: 11.0, lng: 106.7, priceVnd: 0, startsIn: const Duration(days: 5)),
  event('out', title: 'Sự kiện xa', lat: 11.2, lng: 106.7, startsIn: const Duration(days: 2)),
];

/// Fakes and overrides for a signed-in user looking at Explore.
class ExploreWorld {
  ExploreWorld({
    LocationPermissionStatus status = LocationPermissionStatus.notAsked,
    LocationPermissionStatus afterRequest = LocationPermissionStatus.granted,
    List<EventSummary>? events,
    this.role = UserRole.customer,
    this.routesReady = false,
    this.prefsValues = const {},
  }) : location = FakeLocationRepository(
         status: status,
         statusAfterRequest: afterRequest,
         location: ApproxLocation(
           lat: exploreFix.lat,
           lng: exploreFix.lng,
           capturedAt: exploreNow,
         ),
       ),
       repo = FakeNearbyEventsRepository(events ?? exploreEvents);

  final FakeLocationRepository location;
  final FakeNearbyEventsRepository repo;
  final UserRole role;
  final bool routesReady;
  final Map<String, Object> prefsValues;
  late SharedPreferences prefs;
  late List<Override> overrides;

  Future<void> init() async {
    SharedPreferences.setMockInitialValues(prefsValues);
    prefs = await SharedPreferences.getInstance();
    final auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Minh');
    await users.ensureProfile(u);
    await users.setRole(u.uid, role);
    overrides = [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => exploreNow),
      authRepositoryProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(users),
      locationRepositoryProvider.overrideWithValue(location),
      nearbyEventsRepositoryProvider.overrideWithValue(repo),
      eventRoutesReadyProvider.overrideWithValue(routesReady),
    ];
  }
}
```

```dart
// test/features/explore/explore_screen_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/explore/explore_screen.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/explore/widgets/event_tile.dart';

import '../../support/explore_world.dart';
import '../../support/screen_host.dart';

Future<Widget> _app(
  ExploreWorld w, {
  double textScale = 1,
  GoRouter? router,
}) async {
  await w.init();
  return router == null
      ? screenApp(home: const ExploreScreen(), overrides: w.overrides, textScale: textScale)
      : screenRouterApp(router: router, overrides: w.overrides, textScale: textScale);
}

double _top(WidgetTester t, String text) => t.getTopLeft(find.text(text)).dy;

void main() {
  group('S13 before any location choice', () {
    testWidgets('asks nothing at start: only the card with Cho phép / Để sau', (
      tester,
    ) async {
      final w = ExploreWorld();
      await tester.pumpWidget(await _app(w));
      await tester.pumpAndSettle();
      expect(find.text('Sự kiện gần bạn'), findsOneWidget);
      expect(find.text('Cho phép'), findsOneWidget);
      expect(w.location.requestCalls, 0);
      expect(find.text('Quanh bạn · vị trí gần đúng'), findsNothing);
    });

    testWidgets('Cho phép asks the OS once and switches to the nearby layout', (
      tester,
    ) async {
      final w = ExploreWorld();
      await tester.pumpWidget(await _app(w));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-allow')));
      await tester.pumpAndSettle();
      expect(w.location.requestCalls, 1);
      expect(find.text('Quanh bạn · vị trí gần đúng'), findsOneWidget);
      expect(find.byType(NearbyEventTile), findsNWidgets(3), reason: 'default 25 km');
      expect(_top(tester, 'Photo walk phố cổ'), lessThan(_top(tester, 'Mini session mùa thu')));
      expect(_top(tester, 'Mini session mùa thu'), lessThan(_top(tester, 'Workshop ánh sáng')));
      expect(find.text('1,1 km · Công viên Bạch Đằng'), findsOneWidget);
    });

    testWidgets('Để sau turns the card into a chip and it stays away', (
      tester,
    ) async {
      final w = ExploreWorld();
      await tester.pumpWidget(await _app(w));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-later')));
      await tester.pumpAndSettle();
      expect(find.text('Cho phép'), findsNothing);
      expect(find.byKey(const Key('location-choose-area')), findsOneWidget);
      expect(w.location.requestCalls, 0);
    });

    testWidgets('picking an area from the chip shows its events', (tester) async {
      final w = ExploreWorld();
      await tester.pumpWidget(await _app(w));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-later')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-choose-area')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('area-hcm-q1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('area-use')));
      await tester.pumpAndSettle();
      expect(find.text('Quanh Quận 1, TP.HCM · vị trí gần đúng'), findsOneWidget);
      expect(find.byType(NearbyEventTile), findsWidgets);
    });

    testWidgets('upcoming events are listed when there is no location', (
      tester,
    ) async {
      final w = ExploreWorld(status: LocationPermissionStatus.denied);
      await tester.pumpWidget(await _app(w));
      await tester.pumpAndSettle();
      expect(find.text('Sự kiện chụp ảnh'), findsOneWidget);
      expect(find.byType(NearbyEventTile), findsWidgets);
      expect(w.repo.upcomingCalls, 1);
    });

    testWidgets('the events section disappears when there are none', (tester) async {
      final w = ExploreWorld(status: LocationPermissionStatus.denied, events: []);
      await tester.pumpWidget(await _app(w));
      await tester.pumpAndSettle();
      expect(find.text('Sự kiện chụp ảnh'), findsNothing);
    });
  });

  group('S36 from denied-forever', () {
    testWidgets('the picker offers the Settings shortcut', (tester) async {
      final w = ExploreWorld(status: LocationPermissionStatus.deniedForever);
      await tester.pumpWidget(await _app(w));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-choose-area')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('area-open-settings')), findsOneWidget);
    });
  });

  group('S35 nearby', () {
    Future<ExploreWorld> nearby(WidgetTester tester, {double textScale = 1}) async {
      final w = ExploreWorld(
        status: LocationPermissionStatus.granted,
        prefsValues: {
          LocationController.areaKey: jsonEncode(builtInAreas.first.toSaved().toJson()),
        },
      );
      await tester.pumpWidget(await _app(w, textScale: textScale));
      await tester.pumpAndSettle();
      return w;
    }

    testWidgets('radius chips filter, and the empty state offers a wider radius', (
      tester,
    ) async {
      await nearby(tester);
      expect(find.byType(NearbyEventTile), findsNWidgets(3));
      await tester.tap(find.byKey(const Key('filter-radius-10')));
      await tester.pumpAndSettle();
      expect(find.byType(NearbyEventTile), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('filter-free')));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có sự kiện gần bạn'), findsOneWidget);
      await tester.tap(find.byKey(const Key('explore-widen')));
      await tester.pumpAndSettle();
      expect(find.byType(NearbyEventTile), findsNWidgets(1), reason: '25 km, free only');
    });

    testWidgets('weekend and this-week chips narrow the list', (tester) async {
      await nearby(tester);
      await tester.tap(find.byKey(const Key('filter-weekend')));
      await tester.pumpAndSettle();
      expect(find.byType(NearbyEventTile), findsNWidgets(1));
      expect(find.text('Photo walk phố cổ'), findsOneWidget);
    });

    testWidgets('free events carry the tag, paid ones the short price', (tester) async {
      await nearby(tester);
      final free = find.descendant(
        of: find.byKey(const Key('event-tile-free')),
        matching: find.text('Không thu phí'),
      );
      expect(free, findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('event-tile-mid')), matching: find.text('600K')), findsOneWidget);
    });

    testWidgets('"Đổi" opens the area picker', (tester) async {
      await nearby(tester);
      await tester.tap(find.byKey(const Key('explore-change')));
      await tester.pumpAndSettle();
      expect(find.text('Chọn khu vực của bạn'), findsOneWidget);
    });

    testWidgets('fits 320x640 at 1.3x', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await nearby(tester, textScale: 1.3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('two columns from 600dp', (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await nearby(tester);
      final a = tester.getTopLeft(find.byKey(const Key('event-tile-near')));
      final b = tester.getTopLeft(find.byKey(const Key('event-tile-mid')));
      expect(a.dy, b.dy);
      expect(b.dx, greaterThan(a.dx));
    });
  });

  group('navigation', () {
    testWidgets('event rows and "Xem tất cả" stay inert until the event routes exist', (
      tester,
    ) async {
      await tester.pumpWidget(await _app(ExploreWorld(status: LocationPermissionStatus.denied)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('explore-see-all')), findsNothing);
      final tile = tester.widget<NearbyEventTile>(find.byType(NearbyEventTile).first);
      expect(tile.onTap, isNull);
    });

    testWidgets('with event routes ready, tapping a row and "Xem tất cả" navigate', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const ExploreScreen()),
          GoRoute(path: '/events', builder: (_, _) => const Text('events-list')),
          GoRoute(path: '/e/:id', builder: (_, s) => Text('event-${s.pathParameters['id']}')),
        ],
      );
      await tester.pumpWidget(
        await _app(ExploreWorld(status: LocationPermissionStatus.denied, routesReady: true), router: router),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('explore-see-all')));
      await tester.pumpAndSettle();
      expect(find.text('events-list'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event-tile-near')));
      await tester.pumpAndSettle();
      expect(find.text('event-near'), findsOneWidget);
    });

    testWidgets('a customer taps a service tile and lands on Find with the filter', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const ExploreScreen()),
          GoRoute(path: '/action', builder: (_, s) => Text('find ${s.uri.query}')),
        ],
      );
      await tester.pumpWidget(await _app(ExploreWorld(status: LocationPermissionStatus.denied), router: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('category-services-portrait')));
      await tester.pumpAndSettle();
      expect(find.text('find specialty=portrait'), findsOneWidget);
    });

    testWidgets('a photographer sees the tiles but they do not navigate', (tester) async {
      final w = ExploreWorld(status: LocationPermissionStatus.denied, role: UserRole.photographer);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const ExploreScreen()),
          GoRoute(path: '/action', builder: (_, _) => const Text('find')),
        ],
      );
      await tester.pumpWidget(await _app(w, router: router));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('category-services-portrait')));
      await tester.pumpAndSettle();
      expect(find.text('find'), findsNothing);
    });

    testWidgets('the four category tabs switch the tiles', (tester) async {
      await tester.pumpWidget(await _app(ExploreWorld(status: LocationPermissionStatus.denied)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Địa điểm'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category-places-hcm-q1')), findsOneWidget);
      await tester.tap(find.text('Phong cách'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category-styles-film')), findsOneWidget);
      await tester.tap(find.text('Thợ ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Xem tất cả nhiếp ảnh gia'), findsOneWidget);
    });
  });

  testWidgets('a failing events source shows the error state with retry', (tester) async {
    final w = ExploreWorld(status: LocationPermissionStatus.denied);
    w.repo.failWith = StateError('offline');
    await tester.pumpWidget(await _app(w));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được sự kiện. Kiểm tra mạng rồi thử lại.'), findsOneWidget);
    w.repo.failWith = null;
    await tester.tap(find.byKey(const Key('error-retry')));
    await tester.pumpAndSettle();
    expect(find.byType(NearbyEventTile), findsWidgets);
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/explore/explore_links_test.dart test/features/explore/widgets test/features/explore/explore_screen_test.dart`
Expected: FAIL (missing libraries).

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb` (comma after the previous last entry), then `flutter gen-l10n`:

```json
  "exploreAround": "Quanh {area} · vị trí gần đúng",
  "@exploreAround": {
    "placeholders": {
      "area": {"type": "String"}
    }
  },
  "exploreAroundMe": "Quanh bạn · vị trí gần đúng",
  "exploreChange": "Đổi",
  "exploreRadius": "{km} km",
  "@exploreRadius": {
    "placeholders": {
      "km": {"type": "int"}
    }
  },
  "exploreThisWeek": "Tuần này",
  "exploreWeekend": "Cuối tuần",
  "exploreNearbyTitle": "Sự kiện gần bạn",
  "exploreEventsTitle": "Sự kiện chụp ảnh",
  "exploreSeeAll": "Xem tất cả",
  "exploreNoneNearby": "Chưa có sự kiện gần bạn",
  "exploreWiden": "Tăng bán kính",
  "exploreTabServices": "Dịch vụ",
  "exploreTabPlaces": "Địa điểm",
  "exploreTabStyles": "Phong cách",
  "exploreTabPhotographers": "Thợ ảnh",
  "explorePhotographersAll": "Xem tất cả nhiếp ảnh gia",
  "exploreLoadError": "Không tải được sự kiện. Kiểm tra mạng rồi thử lại."
```

```dart
// lib/features/explore/explore_links.dart

/// Link from an Explore tile to the Find screen (S04). The Find screen reads
/// `specialty`, `style` and `area` from the query string (plan 3b4).
String findPhotographersPath({String? specialty, String? style, String? area}) {
  final query = {
    if (specialty != null) 'specialty': specialty,
    if (style != null) 'style': style,
    if (area != null) 'area': area,
  };
  return Uri(
    path: '/action',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}
```

```dart
// lib/features/explore/event_routes.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True once the routes `/events` (S15) and `/e/:eventId` (S16) exist. The
/// events plan overrides this default with `true` in the same change that
/// registers those routes; until then Explore shows events but does not
/// link to them.
final eventRoutesReadyProvider = Provider<bool>((ref) => false);

String eventListPath() => '/events';
String eventPath(String id) => '/e/$id';
```

```dart
// lib/features/explore/widgets/event_tile.dart
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/events/event_summary.dart';

/// A row for one event. Stand-in for `EventCard(size: row)` of the events
/// plan: same content (date block, title, place, type, price or "Không thu
/// phí", seats) without the cover image.
class NearbyEventTile extends StatelessWidget {
  const NearbyEventTile({
    super.key,
    required this.event,
    this.distanceLabel,
    this.onTap,
  });

  final EventSummary event;
  final String? distanceLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final vn = toVn(event.startsAt);
    final soldOut = event.status == EventStatus.full || event.seatsLeft == 0;
    final place = [
      if (distanceLabel != null) distanceLabel!,
      if (event.locationName != null) event.locationName!,
    ].join(' · ');
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        // A list row never blurs (one BackdropFilter per row would make a
        // long list janky): translucent fill and a hairline instead.
        child: Material(
          color: theme.colorScheme.secondary,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg + 8),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: subtle,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              vn.day.toString().padLeft(2, '0'),
                              style: const TextStyle(
                                fontFamily: AppFonts.display,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              l.eventMonthShort(vn.month),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title, style: theme.textTheme.titleMedium),
                        if (place.isNotEmpty)
                          Text(place, style: theme.textTheme.bodySmall),
                        const SizedBox(height: AppSpace.s1),
                        Wrap(
                          spacing: AppSpace.s3,
                          runSpacing: AppSpace.s1,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              event.type.label(l),
                              style: TextStyle(
                                fontSize: AppText.sm,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (event.isFree)
                              const FreeTag()
                            else
                              Text(
                                formatMoney(event.priceVnd, short: true),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            Text(
                              soldOut
                                  ? l.eventSoldOut
                                  : l.eventSeatsLeft(event.seatsLeft),
                              style: TextStyle(
                                fontSize: AppText.sm,
                                color: secondary,
                              ),
                            ),
                          ],
                        ),
                      ],
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
```

```dart
// lib/features/explore/explore_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/events/event_summary.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/explore/area_picker_sheet.dart';
import 'package:photobooking/features/explore/event_routes.dart';
import 'package:photobooking/features/explore/explore_links.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/explore/nearby_events.dart';
import 'package:photobooking/features/explore/widgets/event_tile.dart';

enum ExploreCategoryTab { services, places, styles, photographers }

/// S13 (no location chosen) and S35 (location or area chosen): one screen,
/// two layouts.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with WidgetsBindingObserver {
  ExploreCategoryTab _tab = ExploreCategoryTab.services;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the Settings app: pick up a permission change.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(locationControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final resolution = ref.watch(exploreResolutionProvider);
    final nearby = resolution.mode == ExploreMode.nearby;
    final isCustomer =
        ref.watch(currentProfileProvider).value?.role != UserRole.photographer;
    final controller = ref.read(locationControllerProvider.notifier);

    final category = _CategorySection(
      tab: _tab,
      onTab: (t) => setState(() => _tab = t),
      tappable: isCustomer,
    );
    final events = _EventsSection(nearby: nearby);

    return ScreenCode(
      nearby ? ScreenCodes.exploreNearby : ScreenCodes.exploreNoLocation,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(l.tabExplore)),
        body: RefreshIndicator(
          onRefresh: () async {
            await controller.refreshLocation();
            ref.invalidate(nearbyEventsProvider);
            ref.invalidate(upcomingEventsProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s4,
                  AppSpace.s2,
                  AppSpace.s4,
                  AppSpace.s6,
                ),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    ..._locationSlivers(context, resolution),
                    if (nearby) ...[events.build(context, ref), category.build(context, ref)]
                    else ...[category.build(context, ref), events.build(context, ref)],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _locationSlivers(
    BuildContext context,
    ExploreResolution resolution,
  ) {
    final l = context.l10n;
    final controller = ref.read(locationControllerProvider.notifier);
    switch (resolution.mode) {
      case ExploreMode.loading:
      case ExploreMode.locating:
        return const [
          SliverToBoxAdapter(child: AppSkeleton.box(height: 120)),
          _Gap(AppSpace.s5),
        ];
      case ExploreMode.ask:
      case ExploreMode.requesting:
      case ExploreMode.chooseArea:
        return [
          SliverToBoxAdapter(
            child: LocationPromptCard(
              state: switch (resolution.mode) {
                ExploreMode.ask => LocationPromptState.ask,
                ExploreMode.requesting => LocationPromptState.requesting,
                _ => LocationPromptState.denied,
              },
              onAllow: controller.allow,
              onLater: controller.later,
              onChooseArea: () => showAreaPicker(context),
            ),
          ),
          const _Gap(AppSpace.s5),
        ];
      case ExploreMode.nearby:
        final origin = resolution.origin!;
        final filters = ref.watch(nearbyFiltersProvider);
        final filterController = ref.read(nearbyFiltersProvider.notifier);
        return [
          SliverToBoxAdapter(
            child: Row(
              children: [
                const Icon(Icons.place_outlined, size: 18),
                const SizedBox(width: AppSpace.s2),
                Expanded(
                  child: Text(
                    origin.fromDevice
                        ? l.exploreAroundMe
                        : l.exploreAround(origin.areaName ?? ''),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  key: const Key('explore-change'),
                  onPressed: () => showAreaPicker(context),
                  child: Text(l.exploreChange),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final km in kRadiusOptionsKm) ...[
                    AppChip(
                      key: Key('filter-radius-${km.round()}'),
                      label: l.exploreRadius(km.round()),
                      selected: filters.radiusKm == km,
                      onChanged: (_) => filterController.setRadius(km),
                    ),
                    const SizedBox(width: AppSpace.s2),
                  ],
                  AppChip(
                    key: const Key('filter-this-week'),
                    label: l.exploreThisWeek,
                    selected: filters.thisWeek,
                    onChanged: (_) => filterController.toggleThisWeek(),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  AppChip(
                    key: const Key('filter-weekend'),
                    label: l.exploreWeekend,
                    selected: filters.weekend,
                    onChanged: (_) => filterController.toggleWeekend(),
                  ),
                  const SizedBox(width: AppSpace.s2),
                  AppChip(
                    key: const Key('filter-free'),
                    label: l.freeTag,
                    selected: filters.freeOnly,
                    onChanged: (_) => filterController.toggleFree(),
                  ),
                ],
              ),
            ),
          ),
          const _Gap(AppSpace.s4),
        ];
    }
  }
}

class _Gap extends StatelessWidget {
  const _Gap(this.height);
  final double height;

  @override
  Widget build(BuildContext context) =>
      SliverToBoxAdapter(child: SizedBox(height: height));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            key: const Key('explore-see-all'),
            onPressed: onSeeAll,
            child: Text(context.l10n.exploreSeeAll),
          ),
      ],
    );
  }
}

class _EventsSection {
  const _EventsSection({required this.nearby});
  final bool nearby;

  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final routesReady = ref.watch(eventRoutesReadyProvider);
    final distanceOf = <String, String>{};

    VoidCallback? tapFor(EventSummary e) =>
        routesReady ? () => context.push(eventPath(e.id)) : null;

    Widget tile(EventSummary e) => NearbyEventTile(
      key: Key('event-tile-${e.id}'),
      event: e,
      distanceLabel: distanceOf[e.id],
      onTap: tapFor(e),
    );

    final title = nearby ? l.exploreNearbyTitle : l.exploreEventsTitle;
    final header = SliverToBoxAdapter(
      child: _SectionTitle(
        title,
        onSeeAll: routesReady ? () => context.push(eventListPath()) : null,
      ),
    );
    const gap = _Gap(AppSpace.s3);
    const tail = _Gap(AppSpace.s5);

    Widget errorSliver(VoidCallback retry) => SliverToBoxAdapter(
      child: ErrorState(message: l.exploreLoadError, onRetry: retry),
    );

    Widget loadingSliver() => const SliverToBoxAdapter(
      child: Column(
        children: [
          AppSkeleton.card(height: 88),
          SizedBox(height: AppSpace.s3),
          AppSkeleton.card(height: 88),
        ],
      ),
    );

    if (nearby) {
      final async = ref.watch(nearbyEventsProvider);
      return SliverMainAxisGroup(
        slivers: [
          header,
          gap,
          ...async.when(
            loading: () => [loadingSliver()],
            error: (_, _) => [errorSliver(() => ref.invalidate(nearbyEventsProvider))],
            data: (items) {
              if (items.isEmpty) {
                return [_EmptyNearby(onWiden: () => ref.read(nearbyFiltersProvider.notifier).widen())];
              }
              for (final n in items) {
                distanceOf[n.event.id] = formatDistance(n.distanceKm);
              }
              return [
                SliverAdaptiveRows(
                  itemCount: items.length,
                  itemBuilder: (_, i) => tile(items[i].event),
                ),
              ];
            },
          ),
          tail,
        ],
      );
    }

    final async = ref.watch(upcomingEventsProvider);
    return async.when(
      loading: () => SliverMainAxisGroup(slivers: [header, gap, loadingSliver(), tail]),
      error: (_, _) => SliverMainAxisGroup(
        slivers: [header, gap, errorSliver(() => ref.invalidate(upcomingEventsProvider)), tail],
      ),
      data: (items) {
        if (items.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final shown = items.take(5).toList();
        return SliverMainAxisGroup(
          slivers: [
            header,
            gap,
            SliverAdaptiveRows(
              itemCount: shown.length,
              itemBuilder: (_, i) => tile(shown[i]),
            ),
            tail,
          ],
        );
      },
    );
  }
}

class _EmptyNearby extends ConsumerWidget {
  const _EmptyNearby({required this.onWiden});
  final bool Function() onWiden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final canWiden =
        ref.watch(nearbyFiltersProvider).radiusKm < kRadiusOptionsKm.last;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.exploreNoneNearby,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (canWiden) ...[
            const SizedBox(height: AppSpace.s3),
            AppButton.primary(
              l.exploreWiden,
              key: const Key('explore-widen'),
              onPressed: onWiden,
            ),
          ],
        ],
      ),
    );
  }
}

class _CategorySection {
  const _CategorySection({
    required this.tab,
    required this.onTab,
    required this.tappable,
  });

  final ExploreCategoryTab tab;
  final ValueChanged<ExploreCategoryTab> onTab;
  final bool tappable;

  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tiles = _tiles(context, ref);
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: SegmentedTabs<ExploreCategoryTab>(
            options: [
              SegmentOption(value: ExploreCategoryTab.services, label: l.exploreTabServices),
              SegmentOption(value: ExploreCategoryTab.places, label: l.exploreTabPlaces),
              SegmentOption(value: ExploreCategoryTab.styles, label: l.exploreTabStyles),
              SegmentOption(value: ExploreCategoryTab.photographers, label: l.exploreTabPhotographers),
            ],
            value: tab,
            onChanged: onTab,
          ),
        ),
        const _Gap(AppSpace.s3),
        SliverAdaptiveRows(
          itemCount: tiles.length,
          itemBuilder: (_, i) => tiles[i],
        ),
        const _Gap(AppSpace.s5),
      ],
    );
  }

  List<Widget> _tiles(BuildContext context, WidgetRef ref) {
    Widget tile(String id, String title, String path) => _CategoryTile(
      key: Key('category-${tab.name}-$id'),
      title: title,
      onTap: tappable ? () => context.go(path) : null,
    );
    switch (tab) {
      case ExploreCategoryTab.services:
        return [
          for (final o in kSpecialties)
            tile(o.id, o.labelVi, findPhotographersPath(specialty: o.id)),
        ];
      case ExploreCategoryTab.places:
        final areas = ref.watch(areasProvider).value ?? const <AreaOption>[];
        return [
          for (final a in areas) tile(a.id, a.name, findPhotographersPath(area: a.id)),
        ];
      case ExploreCategoryTab.styles:
        return [
          for (final o in kStyles)
            tile(o.id, o.labelVi, findPhotographersPath(style: o.id)),
        ];
      case ExploreCategoryTab.photographers:
        return [
          tile('all', context.l10n.explorePhotographersAll, findPhotographersPath()),
        ];
    }
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({super.key, required this.title, this.onTap});
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    return Semantics(
      button: onTap != null,
      label: title,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: subtle,
        borderRadius: BorderRadius.circular(AppRadius.lg + 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg + 8),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: theme.textTheme.titleLarge),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Router and placeholder changes:

1. `lib/features/shell/placeholder_tabs.dart`: delete the whole `ExploreTab` class.
2. `lib/app/router.dart`: add `import 'package:photobooking/features/explore/explore_screen.dart';` and replace `(AppTab.explore, const ExploreTab()),` with `(AppTab.explore, const ExploreScreen()),`.
3. The strings `emptyExploreTitle` and `emptyExploreBody` become unused; leave them in the ARB (removing them is a separate cleanup).
4. `docs/superpowers/specs/2026-10-01-remaining-screens.md`, section 3c.2, replace the sentence "Truy vấn dùng geohash độ dài 5 (±2,4 km) cùng 8 ô lân cận" with "Truy vấn dùng tiền tố geohash cùng 8 ô lân cận; độ dài tiền tố chọn theo bán kính (5 ký tự cho ≤ 4 km, 4 ký tự cho ≤ 17 km, 3 ký tự cho ≤ 140 km) để chín ô luôn phủ hết bán kính".

- [ ] **Step 4: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/features/explore && flutter analyze && flutter test`
Expected: all new tests pass (links 1, tile 8, screen about 18), the whole suite is green, analyze is clean. If a screen test reports "A RenderFlex overflowed" in `NearbyEventTile` at 320dp, the `Wrap` under the title is the place to fix (allow it to wrap), not the test. If `find.text('04')` fails, `toVn(event.startsAt).day` is not the Vietnamese day: re-check `toVn` in Task 1 of plan 3a1.

- [ ] **Step 5: Commit**

```bash
git add lib test docs/superpowers/specs/2026-10-01-remaining-screens.md
git commit -m "feat(explore): S13/S35 Explore screen with nearby events and area picker

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Battery and performance check

**Files:**
- Create (if missing): `test/support/idle.dart`, `test/support/blur.dart`
- Create: `test/battery/explore_battery_test.dart`
- Reference (written by the screen-codes plan, do not rewrite): `docs/testing/battery-and-performance.md`

**Interfaces:**
- Consumes: `ExploreWorld`, `exploreEvents`, `screenApp` (Tasks 6, 7), `expectIdle`, `expectBlurBudget`, `FakeLocationRepository.statusCalls/locationCalls/requestCalls`.
- Produces: no production code.

- [ ] **Step 1: Write the tests**

If `test/support/idle.dart` or `test/support/blur.dart` is missing (plan 3a1 creates them), create them with exactly:

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

```dart
// test/support/blur.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Blur is the most expensive effect on a phone. A screen may have at most
/// [max] BackdropFilters, and none may sit inside another one (a card in a
/// blurred panel must use a translucent fill, not blur again).
void expectBlurBudget({int max = 4}) {
  final all = find.byType(BackdropFilter).evaluate().length;
  expect(all, lessThanOrEqualTo(max),
      reason: '$all BackdropFilters; the budget is $max per screen');
  final nested = find.descendant(
    of: find.byType(BackdropFilter),
    matching: find.byType(BackdropFilter),
  );
  expect(nested, findsNothing,
      reason: 'a BackdropFilter inside another BackdropFilter');
}
```

```dart
// test/battery/explore_battery_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/explore/explore_screen.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/explore/widgets/event_tile.dart';

import '../data/events/nearby_events_repository_test.dart' show event;
import '../support/blur.dart';
import '../support/explore_world.dart';
import '../support/idle.dart';
import '../support/screen_host.dart';

Future<Widget> _screen(ExploreWorld w) async {
  await w.init();
  return screenApp(home: const ExploreScreen(), overrides: w.overrides);
}

/// Sends the lifecycle messages the OS sends when the app goes to the
/// background and comes back (for example from the Settings app).
Future<void> _backgroundAndBack(WidgetTester tester) async {
  for (final state in ['paused', 'resumed']) {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/lifecycle',
      const StringCodec().encodeMessage('AppLifecycleState.$state'),
      (_) {},
    );
    await tester.pump();
  }
}

final _savedArea = {
  LocationController.areaKey: jsonEncode(builtInAreas.first.toSaved().toJson()),
};

void main() {
  group('a settled Explore screen leaves the frame loop', () {
    testWidgets('asking for location', (tester) async {
      await tester.pumpWidget(await _screen(ExploreWorld()));
      await expectIdle(tester);
      expectBlurBudget(max: 1); // only the prompt card
    });

    testWidgets('nearby events', (tester) async {
      final w = ExploreWorld(status: LocationPermissionStatus.granted, prefsValues: _savedArea);
      await tester.pumpWidget(await _screen(w));
      await expectIdle(tester);
      expect(find.byType(NearbyEventTile), findsWidgets);
      expectBlurBudget(max: 0); // rows never blur
    });

    testWidgets('choosing an area', (tester) async {
      await tester.pumpWidget(await _screen(ExploreWorld(status: LocationPermissionStatus.denied)));
      await expectIdle(tester);
      expectBlurBudget(max: 0);
    });

    testWidgets('with the area sheet open', (tester) async {
      await tester.pumpWidget(await _screen(ExploreWorld(status: LocationPermissionStatus.denied)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('location-choose-area')));
      await expectIdle(tester);
      expectBlurBudget(max: 1); // the sheet frame
    });
  });

  group('location is requested once', () {
    testWidgets('pull to refresh, resume and filters reuse the fresh fix', (tester) async {
      final w = ExploreWorld(status: LocationPermissionStatus.granted);
      await tester.pumpWidget(await _screen(w));
      await tester.pumpAndSettle();
      expect(w.location.locationCalls, 1);
      expect(w.location.requestCalls, 0, reason: 'already granted: no dialog');

      await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      final statusBefore = w.location.statusCalls;
      await _backgroundAndBack(tester);
      await tester.pumpAndSettle();
      expect(w.location.statusCalls, greaterThan(statusBefore),
          reason: 'coming back re-reads the permission (the observer is alive)');
      await tester.tap(find.byKey(const Key('filter-radius-10')));
      await tester.pumpAndSettle();
      expect(w.location.locationCalls, 1, reason: 'a fix younger than 30 minutes is reused');
    });

    testWidgets('tapping "Cho phép" asks the OS once and takes one fix', (tester) async {
      final w = ExploreWorld();
      await tester.pumpWidget(await _screen(w));
      await tester.pumpAndSettle();
      expect(w.location.requestCalls, 0);
      await tester.tap(find.byKey(const Key('location-allow')));
      await tester.pumpAndSettle();
      expect((w.location.requestCalls, w.location.locationCalls), (1, 1));
    });
  });

  testWidgets('after the screen is gone nothing keeps running', (tester) async {
    final w = ExploreWorld(status: LocationPermissionStatus.granted, prefsValues: _savedArea);
    await tester.pumpWidget(await _screen(w));
    await tester.pumpAndSettle();
    final status = w.location.statusCalls;
    final fixes = w.location.locationCalls;
    final queries = w.repo.cellQueries.length;

    await tester.pumpWidget(screenApp(home: const SizedBox(), overrides: w.overrides));
    await _backgroundAndBack(tester);
    await tester.pump(const Duration(minutes: 5));
    expect(w.location.statusCalls, status, reason: 'the lifecycle observer was removed');
    expect(w.location.locationCalls, fixes);
    expect(w.repo.cellQueries.length, queries, reason: 'autoDispose providers stopped');
    await expectIdle(tester);
  });

  testWidgets('a long event list is built lazily', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final many = [
      for (var i = 0; i < 100; i++)
        event('n$i', lat: 10.7770 + i * 0.0001, lng: 106.7009, title: 'Sự kiện $i'),
    ];
    final w = ExploreWorld(
      status: LocationPermissionStatus.granted,
      prefsValues: _savedArea,
      events: many,
    );
    await tester.pumpWidget(await _screen(w));
    await tester.pumpAndSettle();
    expect(find.byType(NearbyEventTile).evaluate().length, lessThan(25));
  });

  group('source audit of what this plan added', () {
    test('no stream, ticker, periodic timer or controller in the Explore feature', () {
      final files = Directory('lib/features/explore')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(files, isNotEmpty);
      for (final f in files) {
        final src = f.readAsStringSync();
        for (final banned in ['Timer.periodic', 'Stream.periodic', 'AnimationController', 'Ticker', 'getPositionStream']) {
          expect(src, isNot(contains(banned)), reason: '${f.path}: $banned');
        }
      }
    });

    test('the events port is future-based, so there is no listener to leak', () {
      final src = File('lib/data/events/nearby_events_repository.dart').readAsStringSync();
      expect(src, isNot(contains('Stream<')));
    });

    test('Explore shows no network images, so there is nothing to decode oversize', () {
      for (final name in ['explore_screen.dart', 'widgets/event_tile.dart']) {
        final src = File('lib/features/explore/$name').readAsStringSync();
        expect(src, isNot(contains('Image.network')), reason: name);
        expect(src, isNot(contains('NetworkImage')), reason: name);
        expect(src, isNot(contains('NetworkPhoto')), reason: name);
      }
    });
  });
}
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/battery/explore_battery_test.dart`
Expected: PASS (11 tests). A failure names the culprit: an idle failure means a skeleton, spinner or controller is still alive at rest (a finished screen must show none); a blur failure means a list row or a card inside a panel blurs; a call-count failure means the controller fetches again without a reason (for example `_locate(force: true)` where `force: false` was meant).

- [ ] **Step 3: Fix anything the run found**

Change the code, never the thresholds, then re-run Step 2.

- [ ] **Step 4: Manual profiling**

Follow `docs/testing/battery-and-performance.md` (written by the screen-codes plan; do not rewrite it). Scenarios: (1) first visit to Explore on a fresh install: "Cho phép" once, then scroll 100 events and watch raster time; (2) Explore idle for 5 minutes in nearby mode; (3) switch the radius chip ten times; (4) open the area sheet ten times; (5) put the app in the background for a minute and return (one permission read, no new fix).

- Android: mid-range device, `flutter run --profile`, DevTools Performance and `adb shell dumpsys batterystats`.
- iOS: Xcode Instruments (Energy Log and Time Profiler) on a real iPhone, or the Debug Navigator CPU and Energy gauges in the Simulator; Energy Impact must read "Low" at rest. Prerequisite: iOS cannot be built on this machine yet (no Xcode, no CocoaPods, no iOS Firebase configuration); that is a separate "iOS enablement" plan, so until it lands record "iOS: not measured, blocked by iOS enablement".

Record the results in the PR description with the table template of the guide; add the iOS rows with the iPhone model in the Thiết bị column and Energy Impact in place of the Android-only columns.

- [ ] **Step 5: Commit**

```bash
git add test/support test/battery
git commit -m "test: battery, idle and location-call checks for Explore

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** S13 — no OS dialog until "Cho phép", "Để sau" remembered 7 days, `chooseArea` chip, four category tabs, "Sự kiện chụp ảnh" hidden when empty, tab badge cleared on opening (`exploreSeenAt`) (Tasks 2, 4, 7). S35 — "Quanh {khu vực} · vị trí gần đúng" + "Đổi", radius chips 10/25/50 (default 25), "Tuần này", "Cuối tuần", "Không thu phí", distance order, 0.1 km labels, empty state with "Tăng bán kính", pull to refresh, resume re-checks permission (Tasks 3, 7). S36 — radio list, search above 8 items, "Mở Cài đặt…" only for denied-forever, button disabled until a choice, area saved to `SharedPreferences` as `{id, name, geohash5}` and shared with S04/S15 through `locationControllerProvider`, built-in list on load failure (Tasks 1, 2, 6). Permission state machine for the five states (Task 2 tests). Privacy: no coordinates persisted, passed to repositories, or printed (tests in Tasks 2 and 3). §3d.3 badge, §7 tests: location state machine, geohash neighbours and distance, widget tests for `LocationPromptCard`, 320dp/1.3x.
- **Deviations from the spec (flagged):** (1) geohash prefix length follows the radius (spec 3c.2 text corrected in Task 7). (2) S36 is opened with `showAreaPicker(context)`, not a `/explore/area` route. (3) "Dùng vị trí của tôi" row added to S36 so a user who picked an area can go back to the device location. (4) No search bar and no bell on S13 (the results screen and the notification list have no S-code yet). (5) Category tiles have no photo and no "128 gói" counts (no source for either); photographers see the tiles but they are inert (Find is customer-only). (6) Event rows use `NearbyEventTile` without a cover; the featured large card and the compact horizontal cards arrive with `EventCard`. (7) No reverse geocoding: with a device fix the header says "Quanh bạn".
- **Placeholders:** none. **Type consistency:** `LocationController` method names, `ExploreMode`, `ExploreOrigin.cellPrefix/geohash5/geohash6`, `NearbyEventsRepository` signatures, `NearbyFilters`, `kRadiusOptionsKm`, `eventRoutesReadyProvider`, `findPhotographersPath`, widget keys and l10n keys are identical in tests and code. `screenApp` / `screenRouterApp` (Task 6) are reused by 3b4 and 3c.
- **Dependencies on other plans:** `/events` and `/e/:eventId` (events plan flips `eventRoutesReadyProvider`); plan 3b4's Find screen reads `specialty`, `style`, `area` from `/action`; `FakeUserRepository`/`FakeAuthRepository` come from the foundation work already in the repo.
- **Battery and performance (Task 8):** idle test for every Explore state, location requested once (one `request`, one `getCurrentPosition` per permission grant, reused for 30 minutes), no work after the screen is left (lifecycle observer removed, `autoDispose` providers stopped), lazy lists, blur budget (rows never blur), no streams or tickers in the feature, and a manual Android and iOS profiling table in the PR.
- **Risks:** Riverpod 3 specifics (`Ref.mounted`, `ProviderScope(retry:)`, `flutter_riverpod/misc.dart` for `Override`) were checked against the installed 3.4.3 sources; the widget-test timing of `pumpAndSettle` with `RefreshIndicator` and `BackdropFilter` should be run on CI once before merging.
