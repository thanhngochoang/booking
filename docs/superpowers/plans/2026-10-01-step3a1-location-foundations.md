# Step 3a1: Location Foundations (geo, chips, sheet, prompt card, LocationRepository) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Everything the Explore screens (plan 3a2) and the later discovery screens (3b4, 3c) need below the screen level: geohash and distance maths, Vietnam-time helpers, `AppChip`, `SegmentedTabs`, a minimal `showAppSheet`, `SliverAdaptiveRows`, `LocationPromptCard`, and the `LocationRepository` port with a fake and a `geolocator` adapter (permission state machine inputs).

**Architecture:** Pure Dart in `lib/core/` (`geo.dart`, `vn_time.dart`, `format.dart`) with exhaustive unit tests. Stateless widgets in `lib/core/widgets/`, themed only through `Theme`, `AppColors`/`AppColorsDark`, `AppSpace`. The location port lives in `lib/data/location/`; the only file that touches `package:geolocator` is `geolocator_location_repository.dart`, and it does so through a small `LocationGateway` so the permission logic is unit-testable with a fake gateway. The exact coordinates never leave `ApproxLocation` objects held in memory; this plan stores nothing.

**Tech Stack:** Flutter, Riverpod 3 (used from 3a2), `geolocator`, `shared_preferences` (only the "already asked" flag), `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` sections 3c (location), 4 (shared components), 6 (step 3), 7 (tests: location permission state machine, geohash neighbours and distance); `docs/superpowers/specs/components/shared-components.md` entries `AppChip`, `SegmentedTabs`, `AppBottomSheet`, `LocationPromptCard`, `LocationRepository`, "Định dạng"; `docs/superpowers/specs/screens/discovery.md` (S13, S35, S36).

**Prerequisite:** `docs/superpowers/plans/2026-10-01-screen-codes.md` and `docs/superpowers/plans/2026-10-01-core-display-widgets.md` are done (this plan uses the `hostWidget` test helper from `test/core/widgets/widget_host.dart`, `GlassCard`, `AppButton`, `AppColors`, `AppSpace`, `AppText`, `AppRadius`, `controlRadius`).

## How step 3 is split

Spec step 3 (S01, S02, S04, S13, S21, S35, S36) is seven plans, in this order. Each leaves the app building with all tests green.

| Plan | Content | Screens |
|---|---|---|
| **3a1 (this)** | geo maths, `AppChip`, `SegmentedTabs`, `showAppSheet`, `SliverAdaptiveRows`, `LocationPromptCard`, `LocationRepository` | none |
| 3a2 | areas, location controller (permission state machine), nearby-events port with a fake, S36, S13/S35, Explore tab badge | S13, S35, S36 |
| 3b1 | read models (`PhotographerSummary`, `PostSummary`, `ServiceSummary`, `Reason`), repository ports, fakes, Firestore adapters, rules | none |
| 3b2 | `NetworkPhoto`, `AppAvatar`, formatters, `ReasonChips`, `PhotoCard`, `PhotographerCard` | none |
| 3b3 | `RecommendationRepository`, `LocalRecommender`, shared contract test, resilient wrapper | none |
| 3b4 | S01 Home, S02 Photo detail, S04 Find photographer, routes | S01, S02, S04 |
| 3c | S21 Create post, image upload port, post write path, rules | S21 |

Events (`EventCard`, S15–S18, S25–S27) and the photographer profile S03 (plan 2d) are not part of step 3; the cards and screens here link to their routes.

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Run `dart format lib test` before each commit (`require_trailing_commas` is a lint and `flutter analyze` fails on infos).
- Imports are `package:photobooking/...` only; features and `data/` import `package:photobooking/core/core.dart`; files inside `core/` import each other directly.
- `cloud_firestore` / `firebase_*` stay out of this plan entirely. `package:geolocator` may appear only in `lib/data/location/geolocator_location_repository.dart`.
- No hard-coded UI text: Vietnamese strings with full diacritics in `lib/l10n/app_vi.arb`, then `flutter gen-l10n`. Colours, spacing and radii from `AppColors`/`AppColorsDark`, `AppSpace`, `AppRadius`, `AppText`; no raw hex.
- No deprecated Flutter API (`flutter analyze` fails on infos): use `Color.withValues(alpha:)`, `WidgetStateProperty`, no `Radio.groupValue`.
- Location privacy (spec 3c.2): exact coordinates stay on the device and are never written anywhere in this plan (not to `SharedPreferences`, not to logs; `ApproxLocation.toString()` is redacted). Only geohash cells and the area name may leave an `ApproxLocation`.
- Every platform-specific change covers Android and iOS: the iOS `Info.plist` reason strings are in Vietnamese, iOS never asks for "Always" location, and a test reads both `ios/Runner/Info.plist` and `android/app/src/main/AndroidManifest.xml` (Task 7). Building for iOS is not possible on this machine yet; the plist edits are verified by that test until the separate "iOS enablement" plan lands.
- Interactive controls have a 48dp touch target; meaning never rests on colour alone; layouts are tested at width 320 and text scale 1.3.
- Data conventions (`data-model/README.md`): instants are UTC `DateTime`s; ids are opaque strings; enum codes are strings.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/geo.dart` (create) | geohash encode/decode/neighbour cells, haversine, `roundKm`, `geohashPrecisionForRadiusKm` |
| `lib/core/vn_time.dart` (create) | Vietnam wall-clock helpers: `toVn`, `isVnWeekend`, `endOfVnWeek`, `vnDateKey`, `parseDayKey` |
| `lib/core/format.dart` (create) | `formatDistance` (3b2 adds money/day formatters to this file) |
| `lib/core/widgets/app_chip.dart` (create) | `AppChip`, `AppChipKind` |
| `lib/core/widgets/segmented_tabs.dart` (create) | `SegmentedTabs`, `SegmentOption` |
| `lib/core/widgets/app_bottom_sheet.dart` (create) | `showAppSheet` (minimal: glass frame, grab handle, 88% max height) |
| `lib/core/widgets/sliver_adaptive_rows.dart` (create) | one column below 600dp, two from 600dp |
| `lib/core/widgets/location_prompt_card.dart` (create) | `LocationPromptCard`, `LocationPromptState` |
| `lib/core/core.dart` (modify) | export the new files |
| `lib/data/location/location_repository.dart` (create) | `LocationPermissionStatus`, `ApproxLocation`, `LocationRepository`, `FakeLocationRepository` |
| `lib/data/location/geolocator_location_repository.dart` (create) | `RawPermission`, `LocationGateway`, `GeolocatorLocationRepository`, `GeolocatorGateway` |
| `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist` (modify) | `geolocator`, coarse-location permission, iOS usage text |
| `lib/l10n/app_vi.arb` (modify) | five strings |
| `test/support/idle.dart`, `test/support/blur.dart`, `test/battery/location_foundations_battery_test.dart` | idle, blur-budget and battery checks (Task 7) |
| `test/core/geo_test.dart`, `vn_time_test.dart`, `format_test.dart`, `test/core/widgets/app_chip_test.dart`, `segmented_tabs_test.dart`, `app_bottom_sheet_test.dart`, `sliver_adaptive_rows_test.dart`, `location_prompt_card_test.dart`, `test/data/location/location_repository_test.dart` | tests |

---

### Task 1: Geo maths, Vietnam time and distance formatting

**Files:**
- Create: `lib/core/geo.dart`, `lib/core/vn_time.dart`, `lib/core/format.dart`, `test/core/geo_test.dart`, `test/core/vn_time_test.dart`, `test/core/format_test.dart`
- Modify: `lib/core/core.dart`

**Interfaces:**
- Produces (`geo.dart`):
  - `String encodeGeohash(double lat, double lng, {int precision = 9})`
  - `({double lat, double lng}) decodeGeohash(String hash)` — cell centre; throws `ArgumentError` for characters outside the geohash alphabet.
  - `List<String> geohashCells(String hash)` — the cell itself first, then its (up to 8) neighbours, all of the same length, no duplicates.
  - `double haversineKm(double lat1, double lng1, double lat2, double lng2)`
  - `double roundKm(double km)` — nearest 0.1 km.
  - `int geohashPrecisionForRadiusKm(double radiusKm)` — the longest geohash whose 3x3 block still covers the radius from any point of the centre cell: `<= 4` → 5, `<= 17` → 4, `<= 140` → 3, else 2.
- Produces (`vn_time.dart`): `DateTime toVn(DateTime instant)`, `bool isVnWeekend(DateTime instant)`, `DateTime endOfVnWeek(DateTime instant)`, `String vnDateKey(DateTime instant)`, `DateTime? parseDayKey(String key)`.
- Produces (`format.dart`): `String formatDistance(double km)` → `1,2 km`.

Spec 3c.2 fixes the query cell at geohash length 5 (about 4.9 km) plus eight neighbours, but the radius chips go to 25 and 50 km; nine 5-character cells cover only about 4 km around the user. `geohashPrecisionForRadiusKm` is the correction: 3a2 queries with a shorter geohash when the radius is larger. The same geohash prefix still works on the `events (location.geohash, startAt)` index because stored hashes are longer than the query prefix.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/geo_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/geo.dart';

void main() {
  group('geohash', () {
    test('encodes the reference points', () {
      expect(encodeGeohash(42.6, -5.6, precision: 5), 'ezs42');
      expect(encodeGeohash(57.64911, 10.40744, precision: 11), 'u4pruydqqvj');
    });

    test('default precision is 9', () {
      expect(encodeGeohash(10.7769, 106.7009), hasLength(9));
    });

    test('decode returns the cell centre and round-trips', () {
      final c = decodeGeohash('ezs42');
      expect(c.lat, closeTo(42.605, 0.003));
      expect(c.lng, closeTo(-5.603, 0.003));
      expect(encodeGeohash(c.lat, c.lng, precision: 5), 'ezs42');
    });

    test('decode rejects characters outside the alphabet', () {
      expect(() => decodeGeohash('ezs4a'), throwsArgumentError);
    });

    test('cells are the hash plus eight distinct neighbours', () {
      final cells = geohashCells('ezs42');
      expect(cells.first, 'ezs42');
      expect(cells.toSet(), hasLength(9));
      expect(cells.every((c) => c.length == 5), isTrue);
    });

    test('a point 1.2 cell widths away in any direction is in the block', () {
      final c = decodeGeohash('ezs42');
      const w = 360 / 8192; // width of a 5-character cell in degrees
      final cells = geohashCells('ezs42');
      for (final (dx, dy) in [
        (1.2, 0.0),
        (-1.2, 0.0),
        (0.0, 1.2),
        (0.0, -1.2),
        (1.2, 1.2),
        (-1.2, -1.2),
      ]) {
        final p = encodeGeohash(c.lat + dy * w, c.lng + dx * w, precision: 5);
        expect(cells, contains(p), reason: 'dx=$dx dy=$dy');
      }
    });

    test('a point two cells away is not in the block', () {
      final c = decodeGeohash('ezs42');
      const w = 360 / 8192;
      final far = encodeGeohash(c.lat, c.lng + 2.2 * w, precision: 5);
      expect(geohashCells('ezs42'), isNot(contains(far)));
    });

    test('longitude wraps across the antimeridian and poles are skipped', () {
      final edge = encodeGeohash(10.0, 179.99, precision: 4);
      final cells = geohashCells(edge);
      expect(cells.toSet(), hasLength(9));
      final pole = encodeGeohash(89.99, 10.0, precision: 4);
      expect(geohashCells(pole).length, lessThan(9));
    });
  });

  group('distance', () {
    test('haversine matches known city pairs', () {
      expect(haversineKm(48.8566, 2.3522, 51.5074, -0.1278), closeTo(343.5, 2));
      expect(
        haversineKm(21.0285, 105.8542, 10.7769, 106.7009),
        closeTo(1138, 15),
      );
    });

    test('0.01 degree of latitude is about 1.11 km, and zero is zero', () {
      expect(haversineKm(10.0, 106.0, 10.01, 106.0), closeTo(1.112, 0.005));
      expect(haversineKm(10.0, 106.0, 10.0, 106.0), 0);
    });

    test('roundKm rounds to the nearest 0.1', () {
      expect(roundKm(1.24), 1.2);
      expect(roundKm(1.26), 1.3);
      expect(roundKm(0), 0);
    });
  });

  group('geohashPrecisionForRadiusKm', () {
    test('shorter hashes for bigger radii', () {
      expect(geohashPrecisionForRadiusKm(3), 5);
      expect(geohashPrecisionForRadiusKm(10), 4);
      expect(geohashPrecisionForRadiusKm(25), 3);
      expect(geohashPrecisionForRadiusKm(50), 3);
      expect(geohashPrecisionForRadiusKm(300), 2);
    });
  });
}
```

```dart
// test/core/vn_time_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/vn_time.dart';

void main() {
  test('toVn adds seven hours and stays a UTC-labelled value', () {
    final vn = toVn(DateTime.utc(2026, 10, 1, 5));
    expect((vn.hour, vn.day), (12, 1));
  });

  test('weekend is decided on the Vietnamese calendar day', () {
    expect(isVnWeekend(DateTime.utc(2026, 10, 3, 5)), isTrue); // Sat noon
    expect(isVnWeekend(DateTime.utc(2026, 10, 2, 17, 30)), isTrue); // Sat 00:30 VN
    expect(isVnWeekend(DateTime.utc(2026, 10, 4, 17, 30)), isFalse); // Mon 00:30 VN
    expect(isVnWeekend(DateTime.utc(2026, 10, 1, 5)), isFalse); // Thu
  });

  test('the week ends at Monday 00:00 in Vietnam', () {
    // Thursday 12:00 VN -> Monday 5 Oct 00:00 VN = Sunday 17:00 UTC.
    expect(
      endOfVnWeek(DateTime.utc(2026, 10, 1, 5)),
      DateTime.utc(2026, 10, 4, 17),
    );
    // Sunday 23:00 VN is still this week.
    expect(
      endOfVnWeek(DateTime.utc(2026, 10, 4, 16)),
      DateTime.utc(2026, 10, 4, 17),
    );
    // Monday 00:30 VN belongs to the next week.
    expect(
      endOfVnWeek(DateTime.utc(2026, 10, 4, 17, 30)),
      DateTime.utc(2026, 10, 11, 17),
    );
  });

  test('vnDateKey and parseDayKey', () {
    expect(vnDateKey(DateTime.utc(2026, 10, 4, 17)), '2026-10-05');
    expect(vnDateKey(DateTime.utc(2026, 10, 4, 16, 59)), '2026-10-04');
    expect(parseDayKey('2026-10-12'), DateTime.utc(2026, 10, 12));
    for (final bad in ['', '2026-13-01', '2026-02-30', '12/10/2026', '2026-1-1']) {
      expect(parseDayKey(bad), isNull, reason: bad);
    }
  });
}
```

```dart
// test/core/format_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/format.dart';

void main() {
  test('distance has one decimal, a comma and the unit', () {
    expect(formatDistance(1.24), '1,2 km');
    expect(formatDistance(12), '12,0 km');
    expect(formatDistance(0.04), '0,1 km', reason: 'never shows 0,0 km');
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/core/geo_test.dart test/core/vn_time_test.dart test/core/format_test.dart`
Expected: FAIL, "Target of URI doesn't exist" for the three libraries.

- [ ] **Step 3: Implement**

```dart
// lib/core/geo.dart
import 'dart:math' as math;

const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

/// Standard geohash of [lat], [lng] with [precision] characters.
String encodeGeohash(double lat, double lng, {int precision = 9}) {
  assert(precision >= 1 && precision <= 12);
  var latMin = -90.0;
  var latMax = 90.0;
  var lngMin = -180.0;
  var lngMax = 180.0;
  final cLat = lat.clamp(-90.0, 90.0);
  final cLng = lng.clamp(-180.0, 180.0);
  final out = StringBuffer();
  var evenBit = true; // the first bit is longitude
  var bit = 0;
  var ch = 0;
  while (out.length < precision) {
    if (evenBit) {
      final mid = (lngMin + lngMax) / 2;
      if (cLng >= mid) {
        ch = (ch << 1) | 1;
        lngMin = mid;
      } else {
        ch = ch << 1;
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (cLat >= mid) {
        ch = (ch << 1) | 1;
        latMin = mid;
      } else {
        ch = ch << 1;
        latMax = mid;
      }
    }
    evenBit = !evenBit;
    bit++;
    if (bit == 5) {
      out.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return out.toString();
}

({double lat, double lng, double latErr, double lngErr}) _decodeBox(
  String hash,
) {
  var latMin = -90.0;
  var latMax = 90.0;
  var lngMin = -180.0;
  var lngMax = 180.0;
  var evenBit = true;
  for (final c in hash.toLowerCase().split('')) {
    final idx = _base32.indexOf(c);
    if (idx < 0) {
      throw ArgumentError.value(hash, 'hash', 'not a geohash');
    }
    for (var n = 4; n >= 0; n--) {
      final bit = (idx >> n) & 1;
      if (evenBit) {
        final mid = (lngMin + lngMax) / 2;
        if (bit == 1) {
          lngMin = mid;
        } else {
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (bit == 1) {
          latMin = mid;
        } else {
          latMax = mid;
        }
      }
      evenBit = !evenBit;
    }
  }
  return (
    lat: (latMin + latMax) / 2,
    lng: (lngMin + lngMax) / 2,
    latErr: (latMax - latMin) / 2,
    lngErr: (lngMax - lngMin) / 2,
  );
}

/// Centre of the cell named by [hash].
({double lat, double lng}) decodeGeohash(String hash) {
  final b = _decodeBox(hash);
  return (lat: b.lat, lng: b.lng);
}

/// [hash] followed by its neighbours, all of the same length. Cells past a pole
/// do not exist and are skipped; longitude wraps at the antimeridian.
List<String> geohashCells(String hash) {
  final b = _decodeBox(hash);
  final neighbours = <String>{};
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      final lat = b.lat + dy * 2 * b.latErr;
      if (lat > 90 || lat < -90) {
        continue;
      }
      var lng = b.lng + dx * 2 * b.lngErr;
      if (lng > 180) {
        lng -= 360;
      }
      if (lng < -180) {
        lng += 360;
      }
      neighbours.add(encodeGeohash(lat, lng, precision: hash.length));
    }
  }
  return [hash, ...neighbours.where((c) => c != hash)];
}

/// Great-circle distance in kilometres.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0088;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(a)));
}

/// Nearest 0.1 km, the precision shown in the UI.
double roundKm(double km) => (km * 10).round() / 10;

/// Longest geohash length whose 3x3 block still covers [radiusKm] around any
/// point of the centre cell. Cell heights are about 4.9, 19.5, 156 and 1250 km
/// for lengths 5, 4, 3 and 2; widths shrink with latitude, so the thresholds
/// keep a margin that holds up to the latitude of northern Vietnam.
int geohashPrecisionForRadiusKm(double radiusKm) {
  if (radiusKm <= 4) {
    return 5;
  }
  if (radiusKm <= 17) {
    return 4;
  }
  if (radiusKm <= 140) {
    return 3;
  }
  return 2;
}
```

```dart
// lib/core/vn_time.dart
/// Vietnam has no daylight saving, so wall-clock time is UTC+7 all year.
const _vnOffset = Duration(hours: 7);

/// A UTC-labelled `DateTime` whose fields read as Vietnam wall-clock time.
/// Use its `year/month/day/hour/weekday`; do not compare it with real instants.
DateTime toVn(DateTime instant) => instant.toUtc().add(_vnOffset);

bool isVnWeekend(DateTime instant) {
  final d = toVn(instant).weekday;
  return d == DateTime.saturday || d == DateTime.sunday;
}

/// The instant at which the Vietnamese week containing [instant] ends:
/// the next Monday 00:00 in Vietnam, returned as a UTC instant.
DateTime endOfVnWeek(DateTime instant) {
  final vn = toVn(instant);
  final startOfDay = DateTime.utc(vn.year, vn.month, vn.day);
  final daysToMonday = 8 - vn.weekday; // Mon -> 7, Sun -> 1
  return startOfDay.add(Duration(days: daysToMonday)).subtract(_vnOffset);
}

/// `yyyy-MM-dd` of the Vietnamese calendar day containing [instant].
String vnDateKey(DateTime instant) {
  final v = toVn(instant);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${v.year.toString().padLeft(4, '0')}-${two(v.month)}-${two(v.day)}';
}

/// Parses `yyyy-MM-dd` into a UTC midnight, or null if it is not a real date.
DateTime? parseDayKey(String key) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (m == null) {
    return null;
  }
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final date = DateTime.utc(y, mo, d);
  return (date.year == y && date.month == mo && date.day == d) ? date : null;
}
```

```dart
// lib/core/format.dart
import 'dart:math' as math;

import 'package:photobooking/core/geo.dart';

/// `1,2 km`: one decimal, a decimal comma, never `0,0 km`.
String formatDistance(double km) {
  final rounded = math.max(0.1, roundKm(km));
  return '${rounded.toStringAsFixed(1).replaceAll('.', ',')} km';
}
```

In `lib/core/core.dart` add, keeping the list alphabetical:

```dart
export 'package:photobooking/core/format.dart';
export 'package:photobooking/core/geo.dart';
export 'package:photobooking/core/vn_time.dart';
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/core/geo_test.dart test/core/vn_time_test.dart test/core/format_test.dart && flutter analyze`
Expected: PASS (geo 11 tests, vn_time 4, format 1); analyze clean. If the `u4pruydqqvj` or `ezs42` reference fails, the encoder is wrong (these are the published reference vectors), not the test; re-check bit order (longitude first).

- [ ] **Step 5: Commit**

```bash
git add lib/core test/core
git commit -m "feat(core): geohash, distance, Vietnam-time helpers

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `AppChip` and `SegmentedTabs`

**Files:**
- Create: `lib/core/widgets/app_chip.dart`, `lib/core/widgets/segmented_tabs.dart`, `test/core/widgets/app_chip_test.dart`, `test/core/widgets/segmented_tabs_test.dart`
- Modify: `lib/core/core.dart`

**Interfaces:**
- Consumes: `hostWidget`.
- Produces:
  - `enum AppChipKind { filter, context }`
  - `const AppChip({super.key, required String label, required bool selected, required ValueChanged<bool> onChanged, AppChipKind kind = AppChipKind.filter, Widget? leading})` — selected filter chip: solid `primary` fill; selected context chip: `primarySubtle` fill with primary text and border; 32dp pill inside a 48dp touch area.
  - `class SegmentOption<T> { const SegmentOption({required T value, required String label}); }`
  - `const SegmentedTabs<T>({super.key, required List<SegmentOption<T>> options, required T value, required ValueChanged<T> onChanged})` — equal-width segments in a field-coloured track, selected one on `primarySubtle` with a primary border, labels one line (`FittedBox(scaleDown)`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/widgets/app_chip_test.dart
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

Color _fill(WidgetTester tester) => tester
    .widget<Material>(
      find.descendant(
        of: find.byType(AppChip),
        matching: find.byType(Material),
      ),
    )
    .color!;

void main() {
  testWidgets('tapping reports the opposite of the current value', (
    tester,
  ) async {
    bool? seen;
    await tester.pumpWidget(
      hostWidget(
        AppChip(label: 'Cuối tuần', selected: false, onChanged: (v) => seen = v),
      ),
    );
    await tester.tap(find.text('Cuối tuần'));
    expect(seen, isTrue);

    await tester.pumpWidget(
      hostWidget(
        AppChip(label: 'Cuối tuần', selected: true, onChanged: (v) => seen = v),
      ),
    );
    await tester.tap(find.text('Cuối tuần'));
    expect(seen, isFalse);
  });

  testWidgets('selected filter chip is solid primary, context chip is subtle', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        AppChip(label: 'A', selected: true, onChanged: (_) {}),
      ),
    );
    expect(_fill(tester), AppColorsDark.primary);

    await tester.pumpWidget(
      hostWidget(
        AppChip(
          label: 'A',
          selected: true,
          kind: AppChipKind.context,
          onChanged: (_) {},
        ),
      ),
    );
    expect(_fill(tester), AppColorsDark.primarySubtle);

    await tester.pumpWidget(
      hostWidget(
        AppChip(
          label: 'A',
          selected: true,
          kind: AppChipKind.context,
          onChanged: (_) {},
        ),
        brightness: Brightness.light,
      ),
    );
    expect(_fill(tester), AppColors.primarySubtle);
  });

  testWidgets('keeps a 48dp touch target around a 32dp pill', (tester) async {
    await tester.pumpWidget(
      hostWidget(AppChip(label: 'A', selected: false, onChanged: (_) {})),
    );
    expect(tester.getSize(find.byType(AppChip)).height, greaterThanOrEqualTo(48));
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byType(AppChip),
              matching: find.byType(Material),
            ),
          )
          .height,
      32,
    );
  });

  testWidgets('semantics say button, selected and the label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(AppChip(label: 'Không thu phí', selected: true, onChanged: (_) {})),
    );
    final node = tester.getSemantics(find.byType(AppChip));
    expect(node.label, 'Không thu phí');
    expect(node.flagsCollection.isSelected, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('a leading widget is shown before the label', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        AppChip(
          label: 'Quận 1',
          selected: false,
          onChanged: (_) {},
          leading: const Icon(Icons.place_outlined, key: Key('lead')),
        ),
      ),
    );
    expect(find.byKey(const Key('lead')), findsOneWidget);
  });
}
```

```dart
// test/core/widgets/segmented_tabs_test.dart
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

const _options = [
  SegmentOption(value: 0, label: 'Dịch vụ'),
  SegmentOption(value: 1, label: 'Địa điểm'),
  SegmentOption(value: 2, label: 'Phong cách'),
  SegmentOption(value: 3, label: 'Thợ ảnh'),
];

void main() {
  testWidgets('tapping a segment reports its value', (tester) async {
    int? seen;
    await tester.pumpWidget(
      hostWidget(
        SegmentedTabs<int>(options: _options, value: 0, onChanged: (v) => seen = v),
      ),
    );
    await tester.tap(find.text('Phong cách'));
    expect(seen, 2);
  });

  testWidgets('four segments fit 320dp at 1.3x on one line each', (
    tester,
  ) async {
    await tester.pumpWidget(
      hostWidget(
        SegmentedTabs<int>(options: _options, value: 1, onChanged: (_) {}),
        width: 320,
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
    final heights = {
      for (final o in _options) tester.getSize(find.text(o.label)).height,
    };
    expect(heights.length, 1, reason: 'no label wraps to a second line');
  });

  testWidgets('the selected segment is exposed as selected', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        SegmentedTabs<int>(options: _options, value: 1, onChanged: (_) {}),
      ),
    );
    final selected = tester.getSemantics(find.bySemanticsLabel('Địa điểm'));
    final other = tester.getSemantics(find.bySemanticsLabel('Dịch vụ'));
    expect(selected.flagsCollection.isSelected, Tristate.isTrue);
    expect(other.flagsCollection.isSelected, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('segments are at least 48dp tall', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        SegmentedTabs<int>(options: _options, value: 0, onChanged: (_) {}),
      ),
    );
    expect(tester.getSize(find.byType(SegmentedTabs<int>)).height, greaterThanOrEqualTo(48));
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/core/widgets/app_chip_test.dart test/core/widgets/segmented_tabs_test.dart`
Expected: FAIL, `AppChip` / `SegmentedTabs` undefined.

- [ ] **Step 3: Implement**

```dart
// lib/core/widgets/app_chip.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Which look a selected chip takes (spec section 1).
enum AppChipKind {
  /// A filter: selected is a solid `primary` pill (S04, S15, S35).
  filter,

  /// A single choice or context (category row, style): selected is
  /// `primarySubtle` with a primary border and text (S01, S06, S25, S40).
  context,
}

/// Rounded choice pill: 32dp tall, 48dp touch area.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.kind = AppChipKind.filter,
    this.leading,
  });

  final String label;
  final bool selected;

  /// Called with the value the chip would take, i.e. `!selected`.
  final ValueChanged<bool> onChanged;
  final AppChipKind kind;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final (fill, text, edge) = !selected
        ? (scheme.secondary, scheme.onSurface, scheme.outlineVariant)
        : kind == AppChipKind.filter
        ? (scheme.primary, scheme.onPrimary, scheme.primary)
        : (subtle, scheme.primary, scheme.primary);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: () => onChanged(!selected),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Center(
          widthFactor: 1,
          child: Material(
            color: fill,
            shape: StadiumBorder(side: BorderSide(color: edge)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => onChanged(!selected),
              child: SizedBox(
                height: 32,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leading != null) ...[
                        IconTheme(
                          data: IconThemeData(color: text, size: 16),
                          child: leading!,
                        ),
                        const SizedBox(width: AppSpace.s1),
                      ],
                      Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          color: text,
                          fontSize: AppText.sm,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
```

```dart
// lib/core/widgets/segmented_tabs.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/app_theme.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label});
  final T value;
  final String label;
}

/// A row of equal segments of which exactly one is selected: S03, S13, S14,
/// S18, S19. Labels stay on one line and scale down instead of wrapping.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final subtle = dark ? AppColorsDark.primarySubtle : AppColors.primarySubtle;
    final secondary = dark
        ? AppColorsDark.foregroundSecondary
        : AppColors.foregroundSecondary;
    final radius = BorderRadius.circular(controlRadius);
    return Material(
      color: scheme.secondary,
      borderRadius: radius,
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: o.value == value,
                inMutuallyExclusiveGroup: true,
                label: o.label,
                excludeSemantics: true,
                onTap: () => onChanged(o.value),
                child: InkWell(
                  borderRadius: radius,
                  onTap: () => onChanged(o.value),
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.s1),
                      child: DecoratedBox(
                        decoration: o.value == value
                            ? BoxDecoration(
                                color: subtle,
                                borderRadius: BorderRadius.circular(
                                  controlRadius - AppSpace.s1,
                                ),
                                border: Border.all(color: scheme.primary),
                              )
                            : const BoxDecoration(),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s2,
                              ),
                              child: Text(
                                o.label,
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: AppText.base,
                                  fontWeight: FontWeight.w600,
                                  color: o.value == value
                                      ? scheme.primary
                                      : secondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

Export both from `core.dart` (`app_chip.dart`, `segmented_tabs.dart`).

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/core/widgets/app_chip_test.dart test/core/widgets/segmented_tabs_test.dart && flutter analyze`
Expected: PASS (5 + 4 tests); analyze clean. `SemanticsNode.flagsCollection.isSelected` is a `Tristate` (`isTrue` / `isFalse` / `none`) in the Flutter version this repo pins (3.47); `Tristate` comes from `dart:ui`.

- [ ] **Step 5: Commit**

```bash
git add lib/core test/core/widgets
git commit -m "feat(core): AppChip and SegmentedTabs

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `showAppSheet` (minimal `AppBottomSheet`)

**Files:**
- Create: `lib/core/widgets/app_bottom_sheet.dart`, `test/core/widgets/app_bottom_sheet_test.dart`
- Modify: `lib/core/core.dart`

**Interfaces:**
- Consumes: `hostWidget`.
- Produces: `Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder})`. The frame is a 92%-opaque `surface` glass panel (blur 24), radius 28 on top, grab handle, at most 88% of the screen height, bottom safe area and keyboard inset handled. Content that can be long must scroll itself (`ListView(shrinkWrap: true)` or `SingleChildScrollView`).

This is the smallest part of shared-components `AppBottomSheet` that S36, S04's filter sheets and S21's service picker need. Left for the first plan that needs them (booking sheets S05–S07, step 4): `BlurScrim` behind the sheet (the barrier here is the plain `AppColors.overlay` scrim) and the `confirmDismiss` prompt. `lib/features/contact/add_phone_screen.dart` (plan 2a) can move into this later.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/app_bottom_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

Widget _opener(WidgetBuilder content, {void Function(Object?)? onResult}) =>
    hostWidget(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final r = await showAppSheet<String>(context, builder: content);
            onResult?.call(r);
          },
          child: const Text('mở'),
        ),
      ),
    );

void main() {
  testWidgets('shows the content in a glass frame with a grab handle', (
    tester,
  ) async {
    await tester.pumpWidget(_opener((_) => const Text('Nội dung')));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung'), findsOneWidget);
    expect(find.byKey(const Key('app-sheet')), findsOneWidget);
    expect(find.byKey(const Key('app-sheet-handle')), findsOneWidget);
  });

  testWidgets('never taller than 88% of the screen, long content scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _opener(
        (_) => ListView(
          shrinkWrap: true,
          children: [for (var i = 0; i < 60; i++) ListTile(title: Text('Dòng $i'))],
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('app-sheet'))).height,
      lessThanOrEqualTo(568 * 0.88 + 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pop returns the value; tapping outside returns null', (
    tester,
  ) async {
    final results = <Object?>[];
    await tester.pumpWidget(
      _opener(
        (c) => TextButton(
          onPressed: () => Navigator.of(c).pop('xong'),
          child: const Text('chọn'),
        ),
        onResult: results.add,
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('chọn'));
    await tester.pumpAndSettle();
    expect(results, ['xong']);

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(results, ['xong', null]);
  });

  testWidgets('the handle is hidden from screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_opener((_) => const Text('Nội dung')));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('app-sheet-handle')),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/app_bottom_sheet_test.dart`
Expected: FAIL, `showAppSheet` undefined.

- [ ] **Step 3: Implement**

```dart
// lib/core/widgets/app_bottom_sheet.dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Opens [builder] in the app's glass bottom sheet and returns what it pops.
///
/// The sheet is at most 88% of the screen tall; content that can be long
/// scrolls itself. Dismissed by dragging down, tapping outside or Back.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: AppColors.overlay,
    builder: (sheetContext) => _SheetFrame(child: builder(sheetContext)),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});
  final Widget child;

  static const _radius = BorderRadius.vertical(top: Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
      child: ClipRRect(
        key: const Key('app-sheet'),
        borderRadius: _radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.92),
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
                      child: ExcludeSemantics(
                        key: const Key('app-sheet-handle'),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.outline,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: const SizedBox(width: 36, height: 4),
                        ),
                      ),
                    ),
                    Flexible(child: child),
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
```

Export from `core.dart`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/app_bottom_sheet_test.dart && flutter analyze`
Expected: PASS, 4 tests; analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/core test/core/widgets/app_bottom_sheet_test.dart
git commit -m "feat(core): minimal glass bottom sheet (showAppSheet)

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `SliverAdaptiveRows`

**Files:**
- Create: `lib/core/widgets/sliver_adaptive_rows.dart`, `test/core/widgets/sliver_adaptive_rows_test.dart`
- Modify: `lib/core/core.dart`

**Interfaces:**
- Consumes: `hostWidget`.
- Produces: `const SliverAdaptiveRows({super.key, required int itemCount, required IndexedWidgetBuilder itemBuilder, double gap = AppSpace.s3})` — a sliver that shows one item per row below 600dp and two per row from 600dp (spec section 5: "2 cột cho S01, S04, S13, S15, S35"). Rows are top-aligned; the second cell of an odd last row is empty. Items must not depend on a bounded height.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/sliver_adaptive_rows_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

Widget _list(double width, int count) => hostWidget(
  CustomScrollView(
    slivers: [
      SliverAdaptiveRows(
        itemCount: count,
        itemBuilder: (_, i) => SizedBox(
          key: Key('item$i'),
          height: 40,
          child: Text('Mục $i'),
        ),
      ),
    ],
  ),
  width: width,
);

void main() {
  testWidgets('one item per row on a phone', (tester) async {
    await tester.pumpWidget(_list(390, 3));
    final tops = [
      for (var i = 0; i < 3; i++) tester.getTopLeft(find.byKey(Key('item$i'))).dy,
    ];
    expect(tops.toSet(), hasLength(3));
    expect(tester.getTopLeft(find.byKey(const Key('item1'))).dx, 0);
  });

  testWidgets('two items per row from 600dp, odd last row is half empty', (
    tester,
  ) async {
    await tester.pumpWidget(_list(640, 3));
    final a = tester.getRect(find.byKey(const Key('item0')));
    final b = tester.getRect(find.byKey(const Key('item1')));
    final c = tester.getRect(find.byKey(const Key('item2')));
    expect(a.top, b.top);
    expect(b.left, greaterThan(a.right));
    expect(c.top, greaterThan(a.top));
    expect(c.left, 0);
    expect(a.width, closeTo(b.width, 0.01));
    expect(a.width, lessThan(640 / 2));
  });

  testWidgets('an empty list builds nothing and does not throw', (tester) async {
    await tester.pumpWidget(_list(640, 0));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/sliver_adaptive_rows_test.dart`
Expected: FAIL, `SliverAdaptiveRows` undefined.

- [ ] **Step 3: Implement**

```dart
// lib/core/widgets/sliver_adaptive_rows.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/tokens.g.dart';

/// Rows of one item below 600dp and two from 600dp, in a sliver.
class SliverAdaptiveRows extends StatelessWidget {
  const SliverAdaptiveRows({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.gap = AppSpace.s3,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double gap;

  static const wideBreakpoint = 600.0;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.crossAxisExtent >= wideBreakpoint ? 2 : 1;
        final rows = (itemCount / columns).ceil();
        return SliverList.separated(
          itemCount: rows,
          separatorBuilder: (_, _) => SizedBox(height: gap),
          itemBuilder: (context, row) {
            if (columns == 1) {
              return itemBuilder(context, row);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var k = 0; k < columns; k++) ...[
                  if (k > 0) SizedBox(width: gap),
                  Expanded(
                    child: row * columns + k < itemCount
                        ? itemBuilder(context, row * columns + k)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
```

Export from `core.dart`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/core/widgets/sliver_adaptive_rows_test.dart && flutter analyze`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/core test/core/widgets/sliver_adaptive_rows_test.dart
git commit -m "feat(core): SliverAdaptiveRows, two columns from 600dp

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `LocationPromptCard`

**Files:**
- Create: `lib/core/widgets/location_prompt_card.dart`, `test/core/widgets/location_prompt_card_test.dart`
- Modify: `lib/core/core.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `hostWidget`, `GlassCard`, `AppButton`, `AppChip`.
- Produces:
  - `enum LocationPromptState { ask, requesting, denied }`
  - `const LocationPromptCard({super.key, required LocationPromptState state, required VoidCallback onAllow, required VoidCallback onLater, VoidCallback? onChooseArea})` — `ask`: spectrum-bordered glass card with title, body, `Cho phép` (primary, key `location-allow`) and `Để sau` (outline, key `location-later`); `requesting`: same card without the spectrum border, the primary button loading and both disabled; `denied`: a single `Chọn khu vực` chip (key `location-choose-area`) calling `onChooseArea` (required, asserted, for this state). The widget never asks the OS for permission; the screen does that in `onAllow`.
  - l10n: `locationPromptTitle` "Sự kiện gần bạn", `locationPromptBody` "Cho phép dùng vị trí để gợi ý sự kiện trong bán kính 25 km. Vị trí chỉ xử lý trên máy.", `locationAllow` "Cho phép", `locationLater` "Để sau", `locationChooseArea` "Chọn khu vực".

- [ ] **Step 1: Write the failing test**

```dart
// test/core/widgets/location_prompt_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

Widget _card(
  LocationPromptState state, {
  VoidCallback? onAllow,
  VoidCallback? onLater,
  VoidCallback? onChoose,
  double width = 390,
  double textScale = 1,
  Brightness brightness = Brightness.dark,
}) => hostWidget(
  LocationPromptCard(
    state: state,
    onAllow: onAllow ?? () {},
    onLater: onLater ?? () {},
    onChooseArea: onChoose,
  ),
  width: width,
  textScale: textScale,
  brightness: brightness,
);

void main() {
  testWidgets('ask shows the explanation and both buttons', (tester) async {
    var allow = 0, later = 0;
    await tester.pumpWidget(
      _card(
        LocationPromptState.ask,
        onAllow: () => allow++,
        onLater: () => later++,
      ),
    );
    expect(find.text('Sự kiện gần bạn'), findsOneWidget);
    expect(
      find.text(
        'Cho phép dùng vị trí để gợi ý sự kiện trong bán kính 25 km. Vị trí chỉ xử lý trên máy.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('location-allow')));
    await tester.tap(find.byKey(const Key('location-later')));
    expect((allow, later), (1, 1));
  });

  testWidgets('only the ask state has the spectrum border', (tester) async {
    await tester.pumpWidget(_card(LocationPromptState.ask));
    expect(tester.widget<GlassCard>(find.byType(GlassCard)).highlight, isTrue);
    await tester.pumpWidget(_card(LocationPromptState.requesting));
    expect(tester.widget<GlassCard>(find.byType(GlassCard)).highlight, isFalse);
  });

  testWidgets('requesting disables both buttons and shows progress', (
    tester,
  ) async {
    var allow = 0;
    await tester.pumpWidget(
      _card(LocationPromptState.requesting, onAllow: () => allow++),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(const Key('location-allow')), warnIfMissed: false);
    expect(allow, 0);
  });

  testWidgets('denied collapses to a "Chọn khu vực" chip', (tester) async {
    var chosen = 0;
    await tester.pumpWidget(
      _card(LocationPromptState.denied, onChoose: () => chosen++),
    );
    expect(find.byType(GlassCard), findsNothing);
    expect(find.text('Cho phép'), findsNothing);
    await tester.tap(find.byKey(const Key('location-choose-area')));
    expect(chosen, 1);
  });

  testWidgets('denied without a handler is a programming error', (tester) async {
    expect(
      () => LocationPromptCard(
        state: LocationPromptState.denied,
        onAllow: () {},
        onLater: () {},
      ),
      throwsAssertionError,
    );
  });

  for (final b in Brightness.values) {
    testWidgets('ask fits 320dp at 1.3x on ${b.name}', (tester) async {
      await tester.pumpWidget(
        _card(LocationPromptState.ask, width: 320, textScale: 1.3, brightness: b),
      );
      expect(tester.takeException(), isNull);
      final allow = tester.getSize(find.byKey(const Key('location-allow')));
      final later = tester.getSize(find.byKey(const Key('location-later')));
      expect(allow.height, 52);
      expect(later.height, 52);
    });
  }
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/core/widgets/location_prompt_card_test.dart`
Expected: FAIL, `LocationPromptCard` undefined.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb` (before the final `}`, adding a comma after the previous last entry), then run `flutter gen-l10n`:

```json
  "locationPromptTitle": "Sự kiện gần bạn",
  "locationPromptBody": "Cho phép dùng vị trí để gợi ý sự kiện trong bán kính 25 km. Vị trí chỉ xử lý trên máy.",
  "locationAllow": "Cho phép",
  "locationLater": "Để sau",
  "locationChooseArea": "Chọn khu vực"
```

```dart
// lib/core/widgets/location_prompt_card.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/l10n_ext.dart';
import 'package:photobooking/core/theme/tokens.g.dart';
import 'package:photobooking/core/widgets/app_button.dart';
import 'package:photobooking/core/widgets/app_chip.dart';
import 'package:photobooking/core/widgets/glass_card.dart';

enum LocationPromptState { ask, requesting, denied }

/// Asks for location at the moment the user wants it (S13). It does not call
/// the OS permission dialog; the screen does that in [onAllow].
class LocationPromptCard extends StatelessWidget {
  const LocationPromptCard({
    super.key,
    required this.state,
    required this.onAllow,
    required this.onLater,
    this.onChooseArea,
  }) : assert(
         state != LocationPromptState.denied || onChooseArea != null,
         'denied needs onChooseArea',
       );

  final LocationPromptState state;
  final VoidCallback onAllow;
  final VoidCallback onLater;
  final VoidCallback? onChooseArea;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (state == LocationPromptState.denied) {
      return Align(
        alignment: Alignment.centerLeft,
        child: AppChip(
          key: const Key('location-choose-area'),
          label: l.locationChooseArea,
          selected: false,
          leading: const Icon(Icons.place_outlined),
          onChanged: (_) => onChooseArea!(),
        ),
      );
    }
    final theme = Theme.of(context);
    final requesting = state == LocationPromptState.requesting;
    final subtle = theme.brightness == Brightness.dark
        ? AppColorsDark.primarySubtle
        : AppColors.primarySubtle;
    final allowButton = AppButton.primary(
      l.locationAllow,
      key: const Key('location-allow'),
      loading: requesting,
      onPressed: requesting ? null : onAllow,
    );
    final laterButton = AppButton.outline(
      l.locationLater,
      key: const Key('location-later'),
      onPressed: requesting ? null : onLater,
    );
    return GlassCard(
      highlight: !requesting,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: subtle, shape: BoxShape.circle),
                  child: SizedBox.square(
                    dimension: 40,
                    child: ExcludeSemantics(
                      child: Icon(
                        Icons.place_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l.locationPromptTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s1),
                      Text(l.locationPromptBody, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s4),
            // Side by side normally; stacked when large text would wrap a label.
            if (MediaQuery.textScalerOf(context).scale(16) > 18.4)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [allowButton, const SizedBox(height: AppSpace.s2), laterButton],
              )
            else
              Row(
                children: [
                  Expanded(child: allowButton),
                  const SizedBox(width: AppSpace.s2),
                  Expanded(child: laterButton),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
```

Export from `core.dart`.

- [ ] **Step 4: Run and see it pass**

Run: `flutter gen-l10n && flutter test test/core/widgets/location_prompt_card_test.dart && flutter analyze`
Expected: PASS, 7 tests (the `for` loop adds two). At text scale 1.3 the buttons are stacked, so both stay exactly 52dp tall.

- [ ] **Step 5: Commit**

```bash
git add lib/core lib/l10n test/core/widgets/location_prompt_card_test.dart
git commit -m "feat(core): LocationPromptCard for asking location at the right moment

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: `LocationRepository` port, fake and geolocator adapter

**Files:**
- Create: `lib/data/location/location_repository.dart`, `lib/data/location/geolocator_location_repository.dart`, `test/data/location/location_repository_test.dart`
- Modify: `pubspec.yaml` (via `flutter pub add`), `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`

**Interfaces:**
- Consumes: `encodeGeohash` from `core.dart`.
- Produces (`location_repository.dart`, no plugin import):
  - `enum LocationPermissionStatus { notAsked, granted, denied, deniedForever, serviceOff }`
  - `class ApproxLocation { const ApproxLocation({required double lat, required double lng, required DateTime capturedAt}); String get geohash5; String get geohash6; bool isStale(DateTime now) }` — stale after 30 minutes; `toString()` is redacted so coordinates cannot reach a log by accident.
  - `abstract class LocationRepository { Future<LocationPermissionStatus> permissionStatus(); Future<LocationPermissionStatus> request(); Future<ApproxLocation?> currentApproxLocation({Duration timeout = const Duration(seconds: 8)}); Future<void> openSettings(); }`
  - `class FakeLocationRepository implements LocationRepository` with public mutable `status`, `statusAfterRequest` (default granted), `location`, and counters `statusCalls`, `requestCalls`, `locationCalls`, `openSettingsCalls`. `request()` only changes the status from `notAsked` or `denied` (the OS dialog is not shown again for the other states).
- Produces (`geolocator_location_repository.dart`):
  - `enum RawPermission { denied, deniedForever, granted }`
  - `abstract class LocationGateway { Future<bool> serviceEnabled(); Future<RawPermission> checkPermission(); Future<RawPermission> requestPermission(); Future<({double lat, double lng})> lowAccuracyPosition(Duration timeout); Future<bool> openAppSettings(); }`
  - `class GeolocatorGateway implements LocationGateway` (thin, uses `Geolocator`; not unit tested).
  - `class GeolocatorLocationRepository implements LocationRepository` with `GeolocatorLocationRepository({required LocationGateway gateway, required SharedPreferences prefs, DateTime Function()? now})`, `static const askedKey = 'locationAsked'`.

Why the adapter keeps an "already asked" flag: on Android `checkPermission()` reports `denied` both before the first request and after one refusal, and the spec needs to tell "not asked yet" (show the prompt card) from "refused" (show the area chip). The flag is set when `request()` runs and is the only thing this plan persists.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/location/location_repository_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/location/geolocator_location_repository.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Gateway implements LocationGateway {
  bool service = true;
  RawPermission raw = RawPermission.denied;
  RawPermission afterRequest = RawPermission.granted;
  Object? positionError;
  bool hang = false;
  int settingsCalls = 0;

  @override
  Future<bool> serviceEnabled() async => service;
  @override
  Future<RawPermission> checkPermission() async => raw;
  @override
  Future<RawPermission> requestPermission() async => raw = afterRequest;
  @override
  Future<({double lat, double lng})> lowAccuracyPosition(
    Duration timeout,
  ) async {
    if (hang) {
      await Completer<void>().future;
    }
    if (positionError != null) {
      throw positionError!;
    }
    return (lat: 10.7769, lng: 106.7009);
  }

  @override
  Future<bool> openAppSettings() async {
    settingsCalls++;
    return true;
  }
}

Future<(GeolocatorLocationRepository, _Gateway, SharedPreferences)> _make() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final gateway = _Gateway();
  final repo = GeolocatorLocationRepository(
    gateway: gateway,
    prefs: prefs,
    now: () => DateTime.utc(2026, 10, 1, 5),
  );
  return (repo, gateway, prefs);
}

void main() {
  group('ApproxLocation', () {
    final loc = ApproxLocation(
      lat: 10.7769,
      lng: 106.7009,
      capturedAt: DateTime.utc(2026, 10, 1, 5),
    );
    test('derives geohash5 and geohash6 prefixes', () {
      expect(loc.geohash6, startsWith(loc.geohash5));
      expect(loc.geohash5, hasLength(5));
      expect(loc.geohash6, hasLength(6));
    });
    test('is stale after 30 minutes', () {
      expect(loc.isStale(DateTime.utc(2026, 10, 1, 5, 29)), isFalse);
      expect(loc.isStale(DateTime.utc(2026, 10, 1, 5, 31)), isTrue);
    });
    test('toString never prints coordinates', () {
      expect(loc.toString(), isNot(contains('10.77')));
      expect(loc.toString(), isNot(contains('106.70')));
    });
  });

  group('FakeLocationRepository', () {
    test('request only moves notAsked or denied', () async {
      final fake = FakeLocationRepository();
      expect(await fake.request(), LocationPermissionStatus.granted);
      final forever = FakeLocationRepository(
        status: LocationPermissionStatus.deniedForever,
      );
      expect(await forever.request(), LocationPermissionStatus.deniedForever);
      final off = FakeLocationRepository(status: LocationPermissionStatus.serviceOff);
      expect(await off.request(), LocationPermissionStatus.serviceOff);
      expect(fake.requestCalls, 1);
    });
  });

  group('GeolocatorLocationRepository.permissionStatus', () {
    test('service off wins over everything', () async {
      final (repo, gateway, _) = await _make();
      gateway.service = false;
      gateway.raw = RawPermission.granted;
      expect(await repo.permissionStatus(), LocationPermissionStatus.serviceOff);
    });

    test('denied before any request is "not asked", after one it is "denied"', () async {
      final (repo, gateway, _) = await _make();
      expect(await repo.permissionStatus(), LocationPermissionStatus.notAsked);
      gateway.afterRequest = RawPermission.denied;
      expect(await repo.request(), LocationPermissionStatus.denied);
      expect(await repo.permissionStatus(), LocationPermissionStatus.denied);
    });

    test('granted and denied-forever map straight through', () async {
      final (repo, gateway, _) = await _make();
      gateway.raw = RawPermission.granted;
      expect(await repo.permissionStatus(), LocationPermissionStatus.granted);
      gateway.raw = RawPermission.deniedForever;
      expect(await repo.permissionStatus(), LocationPermissionStatus.deniedForever);
    });
  });

  group('GeolocatorLocationRepository.request', () {
    test('records that we asked, and returns the new status', () async {
      final (repo, gateway, prefs) = await _make();
      gateway.afterRequest = RawPermission.granted;
      expect(await repo.request(), LocationPermissionStatus.granted);
      expect(prefs.getBool(GeolocatorLocationRepository.askedKey), isTrue);
    });

    test('does not show a dialog when the service is off', () async {
      final (repo, gateway, prefs) = await _make();
      gateway.service = false;
      expect(await repo.request(), LocationPermissionStatus.serviceOff);
      expect(prefs.getBool(GeolocatorLocationRepository.askedKey), isNull);
    });

    test('a refusal that cannot be asked again is denied-forever', () async {
      final (repo, gateway, _) = await _make();
      gateway.afterRequest = RawPermission.deniedForever;
      expect(await repo.request(), LocationPermissionStatus.deniedForever);
    });
  });

  group('GeolocatorLocationRepository.currentApproxLocation', () {
    test('returns the fix stamped with the injected clock', () async {
      final (repo, _, _) = await _make();
      final loc = await repo.currentApproxLocation();
      expect(loc!.capturedAt, DateTime.utc(2026, 10, 1, 5));
      expect(loc.geohash5, hasLength(5));
    });

    test('gives null when the platform throws', () async {
      final (repo, gateway, _) = await _make();
      gateway.positionError = StateError('no fix');
      expect(await repo.currentApproxLocation(), isNull);
    });

    test('gives null when no fix arrives within the timeout', () async {
      final (repo, gateway, _) = await _make();
      gateway.hang = true;
      final loc = await repo.currentApproxLocation(
        timeout: const Duration(milliseconds: 20),
      );
      expect(loc, isNull);
    });

    test('openSettings goes to the OS app settings', () async {
      final (repo, gateway, _) = await _make();
      await repo.openSettings();
      expect(gateway.settingsCalls, 1);
    });
  });

  test('the repository stores no coordinates', () async {
    final (repo, _, prefs) = await _make();
    await repo.request();
    await repo.currentApproxLocation();
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key).toString();
      expect(value, isNot(contains('10.77')), reason: key);
      expect(value, isNot(contains('106.70')), reason: key);
    }
    expect(prefs.getKeys(), {GeolocatorLocationRepository.askedKey});
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/location/location_repository_test.dart`
Expected: FAIL, the two libraries do not exist.

- [ ] **Step 3: Implement**

Add the package and check what was resolved:

```bash
flutter pub add geolocator
flutter pub deps --style=compact | grep -E "^- geolocator "
```

Expected: a line like `- geolocator 14.x.y`. This plan's `GeolocatorGateway` uses the `LocationSettings`-based API (`locationSettings:`), so the version must be 12 or newer; if it is older, stop and ask.

Platform permissions (approximate location only):

1. `android/app/src/main/AndroidManifest.xml`: after the `INTERNET` line add
   `    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>`
2. `ios/Runner/Info.plist`: before the closing `</dict>` of the top-level dictionary (the `</dict>` just above `</plist>`), add
   ```xml
   	<key>NSLocationWhenInUseUsageDescription</key>
   	<string>Chúng tôi dùng vị trí gần đúng của bạn để gợi ý sự kiện quanh đây. Vị trí không được lưu lên máy chủ.</string>
   ```

```dart
// lib/data/location/location_repository.dart
import 'package:photobooking/core/core.dart';

/// Where the OS permission stands, as the UI needs to tell the cases apart.
enum LocationPermissionStatus {
  /// Never asked: show the prompt card (S13).
  notAsked,
  granted,

  /// Refused once; can still be asked again by the OS.
  denied,

  /// Refused for good: only the Settings app can change it.
  deniedForever,

  /// The device's location switch is off.
  serviceOff,
}

/// A coarse fix kept in memory only. Never persisted, never sent: only the
/// geohash cells derived from it may leave the device (spec 3c.2).
class ApproxLocation {
  const ApproxLocation({
    required this.lat,
    required this.lng,
    required this.capturedAt,
  });

  final double lat;
  final double lng;
  final DateTime capturedAt;

  static const maxAge = Duration(minutes: 30);

  String get geohash5 => encodeGeohash(lat, lng, precision: 5);
  String get geohash6 => encodeGeohash(lat, lng, precision: 6);

  bool isStale(DateTime now) => now.difference(capturedAt) > maxAge;

  @override
  String toString() => 'ApproxLocation(<redacted>)';
}

abstract class LocationRepository {
  Future<LocationPermissionStatus> permissionStatus();

  /// Shows the OS dialog when the OS allows it and returns the new status.
  Future<LocationPermissionStatus> request();

  /// Low-accuracy fix, or null when none arrives within [timeout] or the
  /// platform fails.
  Future<ApproxLocation?> currentApproxLocation({
    Duration timeout = const Duration(seconds: 8),
  });

  /// Opens the OS settings page of this app.
  Future<void> openSettings();
}

class FakeLocationRepository implements LocationRepository {
  FakeLocationRepository({
    this.status = LocationPermissionStatus.notAsked,
    this.statusAfterRequest = LocationPermissionStatus.granted,
    this.location,
  });

  LocationPermissionStatus status;

  /// What `request()` leaves behind when it is allowed to ask.
  LocationPermissionStatus statusAfterRequest;
  ApproxLocation? location;

  int statusCalls = 0;
  int requestCalls = 0;
  int locationCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<LocationPermissionStatus> permissionStatus() async {
    statusCalls++;
    return status;
  }

  @override
  Future<LocationPermissionStatus> request() async {
    requestCalls++;
    if (status == LocationPermissionStatus.notAsked ||
        status == LocationPermissionStatus.denied) {
      status = statusAfterRequest;
    }
    return status;
  }

  @override
  Future<ApproxLocation?> currentApproxLocation({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    locationCalls++;
    return location;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCalls++;
  }
}
```

```dart
// lib/data/location/geolocator_location_repository.dart
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/location/location_repository.dart';

enum RawPermission { denied, deniedForever, granted }

/// The few platform calls the repository needs, so the permission logic can
/// be tested without a device.
abstract class LocationGateway {
  Future<bool> serviceEnabled();
  Future<RawPermission> checkPermission();
  Future<RawPermission> requestPermission();

  /// Throws on failure or timeout.
  Future<({double lat, double lng})> lowAccuracyPosition(Duration timeout);
  Future<bool> openAppSettings();
}

class GeolocatorGateway implements LocationGateway {
  const GeolocatorGateway();

  RawPermission _map(LocationPermission p) => switch (p) {
    LocationPermission.always ||
    LocationPermission.whileInUse => RawPermission.granted,
    LocationPermission.deniedForever => RawPermission.deniedForever,
    LocationPermission.denied ||
    LocationPermission.unableToDetermine => RawPermission.denied,
  };

  @override
  Future<bool> serviceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<RawPermission> checkPermission() async =>
      _map(await Geolocator.checkPermission());

  @override
  Future<RawPermission> requestPermission() async =>
      _map(await Geolocator.requestPermission());

  @override
  Future<({double lat, double lng})> lowAccuracyPosition(
    Duration timeout,
  ) async {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: timeout,
      ),
    );
    return (lat: p.latitude, lng: p.longitude);
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}

class GeolocatorLocationRepository implements LocationRepository {
  GeolocatorLocationRepository({
    required LocationGateway gateway,
    required SharedPreferences prefs,
    DateTime Function()? now,
  }) : _gateway = gateway,
       _prefs = prefs,
       _now = now ?? (() => DateTime.now().toUtc());

  /// Set the first time we show the OS dialog. The platform reports "denied"
  /// both before the first request and after one refusal; this flag tells
  /// the two apart.
  static const askedKey = 'locationAsked';

  final LocationGateway _gateway;
  final SharedPreferences _prefs;
  final DateTime Function() _now;

  @override
  Future<LocationPermissionStatus> permissionStatus() async {
    if (!await _gateway.serviceEnabled()) {
      return LocationPermissionStatus.serviceOff;
    }
    return switch (await _gateway.checkPermission()) {
      RawPermission.granted => LocationPermissionStatus.granted,
      RawPermission.deniedForever => LocationPermissionStatus.deniedForever,
      RawPermission.denied =>
        _prefs.getBool(askedKey) == true
            ? LocationPermissionStatus.denied
            : LocationPermissionStatus.notAsked,
    };
  }

  @override
  Future<LocationPermissionStatus> request() async {
    if (!await _gateway.serviceEnabled()) {
      return LocationPermissionStatus.serviceOff;
    }
    final result = await _gateway.requestPermission();
    await _prefs.setBool(askedKey, true);
    return switch (result) {
      RawPermission.granted => LocationPermissionStatus.granted,
      RawPermission.deniedForever => LocationPermissionStatus.deniedForever,
      RawPermission.denied => LocationPermissionStatus.denied,
    };
  }

  @override
  Future<ApproxLocation?> currentApproxLocation({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final p = await _gateway.lowAccuracyPosition(timeout).timeout(timeout);
      return ApproxLocation(lat: p.lat, lng: p.lng, capturedAt: _now());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> openSettings() async {
    await _gateway.openAppSettings();
  }
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/location && flutter analyze && flutter test`
Expected: the new tests pass (3 + 1 + 3 + 3 + 4 + 1 = 15 including groups), the whole suite stays green and analyze is clean. If `flutter analyze` flags `LocationSettings(accuracy:, timeLimit:)` or `getCurrentPosition(locationSettings:)`, the installed `geolocator` is older than 12: do not edit the test, upgrade the dependency (`flutter pub upgrade geolocator`).

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist lib/data/location test/data/location
git commit -m "feat(location): LocationRepository port, fake and geolocator adapter

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Battery and performance check

**Files:**
- Create (if missing): `test/support/idle.dart`, `test/support/blur.dart`
- Create: `test/battery/location_foundations_battery_test.dart`
- Reference (written by the screen-codes plan, do not rewrite): `docs/testing/battery-and-performance.md`

**Interfaces:**
- Consumes: `hostWidget`, `AppChip`, `SegmentedTabs`, `LocationPromptCard`, `SliverAdaptiveRows`, `showAppSheet`, `GeolocatorLocationRepository`, `LocationGateway`.
- Produces: `Future<void> expectIdle(WidgetTester tester)` and `void expectBlurBudget({int max = 4})` (shared by every later plan) and a battery test file for this plan.

What is checked: nothing keeps scheduling frames once a widget is at rest; the location adapter takes one low-accuracy fix per request (never a stream, never background, never high accuracy) and the manifests ask for approximate location only; lists build lazily; at most four `BackdropFilter`s are alive in one scene and none sits inside another (list items and grid cards never blur; they use a translucent fill).

- [ ] **Step 1: Write the tests**

If `test/support/idle.dart` does not exist (the screen-codes plan creates it; create it only when missing), create it with exactly:

```dart
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

If `test/support/blur.dart` does not exist, create it with exactly:

```dart
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
// test/battery/location_foundations_battery_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/location/geolocator_location_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/widgets/widget_host.dart';
import '../support/blur.dart';
import '../support/idle.dart';

class _CountingGateway implements LocationGateway {
  int positionCalls = 0;
  int requestCalls = 0;
  Duration? lastTimeout;

  @override
  Future<bool> serviceEnabled() async => true;
  @override
  Future<RawPermission> checkPermission() async => RawPermission.granted;
  @override
  Future<RawPermission> requestPermission() async {
    requestCalls++;
    return RawPermission.granted;
  }

  @override
  Future<({double lat, double lng})> lowAccuracyPosition(Duration timeout) async {
    positionCalls++;
    lastTimeout = timeout;
    return (lat: 10.7769, lng: 106.7009);
  }

  @override
  Future<bool> openAppSettings() async => true;
}

void main() {
  group('widgets at rest do not keep the frame loop running', () {
    testWidgets('AppChip and SegmentedTabs', (tester) async {
      await tester.pumpWidget(
        hostWidget(
          Column(
            children: [
              AppChip(label: 'Cuối tuần', selected: true, onChanged: (_) {}),
              SegmentedTabs<int>(
                options: const [
                  SegmentOption(value: 0, label: 'Dịch vụ'),
                  SegmentOption(value: 1, label: 'Địa điểm'),
                ],
                value: 0,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      );
      await expectIdle(tester);
    });

    for (final state in [LocationPromptState.ask, LocationPromptState.denied]) {
      testWidgets('LocationPromptCard ${state.name}', (tester) async {
        await tester.pumpWidget(
          hostWidget(
            LocationPromptCard(
              state: state,
              onAllow: () {},
              onLater: () {},
              onChooseArea: () {},
            ),
          ),
        );
        await expectIdle(tester);
        expectBlurBudget(max: 1);
      });
    }

    testWidgets('SliverAdaptiveRows and an open sheet', (tester) async {
      await tester.pumpWidget(
        hostWidget(
          Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () => showAppSheet<void>(
                    context,
                    builder: (_) => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Nội dung'),
                    ),
                  ),
                  child: const Text('mở'),
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverAdaptiveRows(
                        itemCount: 20,
                        itemBuilder: (_, i) => SizedBox(height: 40, child: Text('Mục $i')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await expectIdle(tester);
      await tester.tap(find.text('mở'));
      await expectIdle(tester);
      expectBlurBudget(max: 1); // the sheet frame is the only blur
    });
  });

  testWidgets('SliverAdaptiveRows builds only what is on screen', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      hostWidget(
        CustomScrollView(
          slivers: [
            SliverAdaptiveRows(
              itemCount: 2000,
              itemBuilder: (_, i) => SizedBox(height: 60, child: Text('Mục $i')),
            ),
          ],
        ),
      ),
    );
    final built = find.textContaining('Mục ').evaluate().length;
    expect(built, lessThan(40), reason: 'a lazy list, not a Column of all items');
  });

  group('location is a one-shot, low-accuracy, foreground request', () {
    test('one gateway position call per fix, with a deadline, and none for status', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = _CountingGateway();
      final repo = GeolocatorLocationRepository(gateway: gateway, prefs: prefs);
      await repo.permissionStatus();
      expect(gateway.positionCalls, 0, reason: 'checking permission never reads a position');
      await repo.currentApproxLocation();
      expect(gateway.positionCalls, 1);
      expect(gateway.lastTimeout, const Duration(seconds: 8));
      await repo.request();
      expect(gateway.requestCalls, 1);
    });

    test('the adapter source has no stream, no high accuracy, no background', () {
      final src = File('lib/data/location/geolocator_location_repository.dart').readAsStringSync();
      expect(src, contains('getCurrentPosition'));
      expect(src, contains('LocationAccuracy.low'));
      expect(src, contains('timeLimit'));
      for (final banned in [
        'getPositionStream',
        'getServiceStatusStream',
        'LocationAccuracy.high',
        'LocationAccuracy.best',
        'LocationAccuracy.medium',
        'requestAlways',
        'foregroundNotificationConfig',
        'Timer.periodic',
      ]) {
        expect(src, isNot(contains(banned)), reason: banned);
      }
    });

    test('the port has no stream either', () {
      final src = File('lib/data/location/location_repository.dart').readAsStringSync();
      expect(src, isNot(contains('Stream<')));
    });

    test('Android asks for approximate location only', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('ACCESS_COARSE_LOCATION'));
      for (final banned in [
        'ACCESS_FINE_LOCATION',
        'ACCESS_BACKGROUND_LOCATION',
        'FOREGROUND_SERVICE_LOCATION',
      ]) {
        expect(manifest, isNot(contains(banned)), reason: banned);
      }
    });

    test('iOS asks for when-in-use location only, with a Vietnamese reason', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist, contains('<key>NSLocationWhenInUseUsageDescription</key>'));
      final reason = RegExp(
        r'<key>NSLocationWhenInUseUsageDescription</key>\s*<string>([^<]+)</string>',
      ).firstMatch(plist)!.group(1)!;
      expect(reason, contains('vị trí gần đúng'));
      expect(reason, contains('không được lưu lên máy chủ'));
      for (final banned in [
        'NSLocationAlwaysAndWhenInUseUsageDescription',
        'NSLocationAlwaysUsageDescription',
        'NSLocationTemporaryUsageDescriptionDictionary',
      ]) {
        expect(plist, isNot(contains(banned)), reason: banned);
      }
      // No background mode may include location.
      final modes = RegExp(
        r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(plist);
      expect(modes?.group(1) ?? '', isNot(contains('location')));
    });
  });
}
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/battery/location_foundations_battery_test.dart`
Expected: PASS (10 tests). These tests encode properties the earlier tasks were built to have. A failure names the culprit: an idle failure means a widget starts a ticker or timer (find and stop it; do not loosen the test); a "banned" failure means the adapter drifted from the one-shot design.

- [ ] **Step 3: Fix anything the run found**

Only code changes that remove the cause (for example, a `Timer.periodic` in an adapter, a repeating animation in a widget that is not loading). Re-run Step 2 until green.

- [ ] **Step 4: Manual profiling**

Follow `docs/testing/battery-and-performance.md` (written by the screen-codes plan; do not rewrite it). Scenarios for this plan, once 3a2 puts the pieces on screen: (1) open Explore, tap "Cho phép", accept: the location indicator must disappear within seconds, and a second visit within 30 minutes must not light it again; (2) leave Explore open for 5 minutes untouched and note the battery or energy delta and that the timeline shows no frames; (3) open and close the area sheet ten times and check that raster time stays under 16 ms.

- Android: mid-range device, `flutter run --profile`, DevTools Performance and `adb shell dumpsys batterystats`.
- iOS: Xcode Instruments (Energy Log and Time Profiler) on a real iPhone, or the Debug Navigator CPU and Energy gauges in the Simulator; Energy Impact must read "Low" at rest and the location arrow must not stay in the status bar after the fix. Prerequisite: iOS cannot be built on this machine yet (no Xcode, no CocoaPods, no iOS Firebase configuration); that is the job of a separate "iOS enablement" plan, so until it lands record "iOS: not measured, blocked by iOS enablement" in the table.

Record the results in the PR description with the table template of the guide; add the iOS rows with the iPhone model in the Thiết bị column and Energy Impact in place of the Android-only columns.

- [ ] **Step 5: Commit**

```bash
git add test/support test/battery
git commit -m "test: battery and idle checks for location foundations

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** 3c.1 permission states (`notAsked / granted / denied / deniedForever / serviceOff`) and "never ask at app start" (the card never calls the OS; only `request()` does; Task 5, 6); 3c.2 coarse accuracy (`LocationAccuracy.low`, `ACCESS_COARSE_LOCATION`, iOS when-in-use text with the spec's Vietnamese wording), 30-minute staleness (`ApproxLocation.isStale`), 8-second deadline (`currentApproxLocation` default), exact coordinates stay in memory (redacted `toString`, test that nothing but the asked flag is persisted), geohash neighbours and haversine (Task 1); §4 components `AppChip` (two kinds, 32/48dp), `SegmentedTabs`, `LocationPromptCard` (three states, spectrum only on `ask`, buttons stack under large text), `AppBottomSheet` (minimal), `LocationRepository` (Task 2–6); §5 "2 cột ≥ 600dp" (`SliverAdaptiveRows`); §7 location state machine inputs, geohash neighbours and distance tests; `formatDistance` from "Định dạng".
- **Deviations from the spec (flagged, not hidden):** (1) query geohash length is chosen from the radius (`geohashPrecisionForRadiusKm`) because spec 3c.2's fixed length 5 cannot cover the 25 and 50 km chips; update 3c.2 when 3a2 lands. (2) `showAppSheet` has no `BlurScrim` and no `confirmDismiss` yet. (3) `formatDistance` lives in `format.dart` created here; 3b2 appends the money/day formatters to the same file.
- **Placeholders:** none. **Type consistency:** `LocationPermissionStatus`, `ApproxLocation(lat,lng,capturedAt)`, `geohash5/geohash6`, `LocationRepository` method names, `FakeLocationRepository` fields, `LocationPromptState`, `LocationPromptCard` keys (`location-allow`, `location-later`, `location-choose-area`), `AppChip`/`AppChipKind`, `SegmentedTabs`/`SegmentOption`, `showAppSheet`, `SliverAdaptiveRows` are the names plans 3a2, 3b4 and 3c use.
- **Deferred to later plans:** the location controller and the saved area (3a2); the S36 sheet content (3a2); `AppSkeleton`, `ErrorState`, `SectionHeader` (added by the first screen plan that needs them, 3a2 for the Explore screen); `BlurScrim`, `AppAvatar` (3b2).
- **Battery and performance (Task 7):** idle tests (`expectIdle`) for every widget this plan adds, a one-shot/low-accuracy/coarse-permission audit of the location adapter and the platform manifests, lazy lists, and the blur budget (at most 4 per screen, none nested); manual profiling follows `docs/testing/battery-and-performance.md`.
- **Risks:** `geolocator` major version (Task 6 Step 3 check); the iOS and Android permission edits are covered only by the file-reading test in Task 7; the real dialogs need a manual run on a device (deny twice, then "Mở Cài đặt"), and the iOS run waits for the "iOS enablement" plan.
