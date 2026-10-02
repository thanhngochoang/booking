# Step 3b3: RecommendationRepository, LocalRecommender and the Contract Suite Implementation Plan

> **Battery/performance (2026-10-02, user):** this plan has no battery, idle, blur-budget or performance task or test steps. All of that runs once at the end in `docs/superpowers/plans/2026-10-02-final-battery-performance.md`. Skip any such step inside a task (e.g. `expectIdle`, `expectBlurBudget`, listener counters, profiling); keep the functional tests.

> **Rules emulator tests (2026-10-02, user):** do not run the Firestore/Storage rules tests on the emulator (`app_flutter/firebase/rules-test`, `npm test`, `npm run test:*`) while executing this plan; the sandbox cannot run them. Still write or update the rules and their test files as the task says, but skip every step that runs them and every `Expected:` that depends on them; CI (`flutter.yml`, `firebase-deploy.yml`) runs them on push and blocks deploy on failure. Record the skip in the ledger.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The port the Home and Find screens use to order photographers and posts (`RecommendationRepository`), an on-device `LocalRecommender` that ranks by smoothed rating, distance and availability and explains each result, a `ResilientRecommendationRepository` that falls back to it when a remote implementation fails or is slow, and one contract test suite that the future remote implementation (step 3r) must also pass.

**Architecture:** Plain Dart in `lib/data/recommendation/`. The query carries a `geohash6` (a cell of about 1.2 km), never coordinates, matching `services/recommender/api/openapi.yaml`. `LocalRecommender` reads candidate photographers and posts through the 3b1 ports and the day state through a small `AvailabilityLookup` port. Reason texts come from the ARB file through the generated Vietnamese localizations class, so the local texts and the server's texts look alike. Step 3r only has to add `RemoteRecommendationRepository` and override one provider.

**Tech Stack:** Flutter, Riverpod 3, `cloud_firestore` (one adapter file), `fake_cloud_firestore` (dev), `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3e.1, §3e.4 (fallback), §3e.5 (API), §3e.6 (components and reasons), §3e.9 (integration points), §7 ("LocalRecommender và RemoteRecommendationRepository cùng qua bộ test hợp đồng"); `docs/superpowers/specs/components/shared-components.md` ("RecommendationRepository"); `services/recommender/api/openapi.yaml`; `docs/superpowers/specs/screens/discovery.md` (S01, S04).

**Prerequisite:** plan `2026-10-01-step3b1-feed-data.md` is done (`PostRepository`, `PhotographerRepository`, fakes, fixtures, `fake_cloud_firestore`); `2026-10-01-step3b2-feed-cards.md` is done (`formatDay`, `formatRating`); plans 3a1 and 3a2 are done (`formatDistance`, `specialtyLabel`, `clockProvider`).

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Run `dart format lib test` before each commit (`require_trailing_commas` is a lint and `flutter analyze` fails on infos).
- Imports are `package:photobooking/...` only; `data/` imports `package:photobooking/core/core.dart`.
- **Privacy:** a recommendation query holds a `geohash6` and filters, never latitude or longitude, and the recommender port has no dependency on `LocationRepository`. Signals carry a photographer id, a rank and a timestamp, no phone, no position, no message text.
- **Firebase isolation:** only `lib/data/recommendation/firestore_availability_lookup.dart` imports `cloud_firestore`.
- **Bounded work:** the candidate pool is at most 200 photographers; with a chosen date at most 60 day documents are read; a posts page is at most 50.
- Data conventions: a calendar day is a `yyyy-MM-dd` key; instants are UTC; money is integer VND; enum codes are strings.
- No hard-coded UI text: reason texts are ARB strings; Vietnamese with full diacritics; `flutter gen-l10n` after editing.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/vn_time.dart` (modify) | add `dayKeyOf(DateTime)` |
| `lib/data/recommendation/recommendation_models.dart` (create) | query, result, signal types and the `RecommendationRepository` port |
| `lib/data/recommendation/availability_lookup.dart` (create) | `DayAvailability`, `AvailabilityLookup`, `FakeAvailabilityLookup` |
| `lib/data/recommendation/firestore_availability_lookup.dart` (create) | Firestore adapter for `availability/{uid}/days/{day}` |
| `lib/data/recommendation/local_recommender.dart` (create) | `LocalRecommender` |
| `lib/data/recommendation/resilient_recommendation_repository.dart` (create) | timeout and fallback wrapper |
| `lib/data/recommendation/recommendation_providers.dart` (create) | providers |
| `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs` (modify) | day documents readable by signed-in users |
| `lib/l10n/app_vi.arb` (modify) | six reason strings |
| `test/data/recommendation/*` , `test/battery/recommendation_battery_test.dart` | tests and the shared contract |

---

### Task 1: Query, result and signal types, and the port

**Files:**
- Create: `lib/data/recommendation/recommendation_models.dart`, `test/data/recommendation/recommendation_models_test.dart`
- Modify: `lib/core/vn_time.dart`, `test/core/vn_time_test.dart`

**Interfaces:**
- Produces (`vn_time.dart`): `String dayKeyOf(DateTime date)` — `yyyy-MM-dd` from the calendar fields of [date] (no time zone conversion).
- Produces (`recommendation_models.dart`):
  - `enum RecommendationSort { best, near, price, rating }`
  - `class RecommendationQuery` — `const RecommendationQuery({String? specialtyId, String? styleId, DateTime? date, String? geohash6, int? budgetMax, RecommendationSort sort = RecommendationSort.best, int limit = 20, String? cursor, List<String> excludeIds = const []})`, `copyWith`, value equality. [date] is a calendar date; only its year, month and day are read.
  - `class RecommendedPhotographer { const RecommendedPhotographer({required PhotographerSummary photographer, required int rank, required double score, List<Reason> reasons = const [], double? distanceKm}); }`
  - `class RecommendationPage { const RecommendationPage({required List<RecommendedPhotographer> items, required String requestId, required String algorithm, required String algorithmVersion, String? nextCursor, bool usedFallback = false}); RecommendationPage markFallback(); }`
  - `class PostRecommendationQuery { const PostRecommendationQuery({String? specialtyId, String? geohash6, int limit = 20, String? cursor}); }`
  - `class RecommendedPost { const RecommendedPost({required PostSummary post, required PhotographerSummary photographer, required int rank, List<Reason> reasons = const []}); }`
  - `class PostRecommendationPage { const PostRecommendationPage({required List<RecommendedPost> items, required String requestId, required String algorithm, required String algorithmVersion, String? nextCursor, bool usedFallback = false}); PostRecommendationPage markFallback(); }`
  - `enum SignalType { impression, click, inquiry, booking }`; `class RecommendationSignal { const RecommendationSignal({required SignalType type, required String requestId, required String photographerId, int? rank, String? algorithmVersion, required DateTime at}); }`
  - `abstract class RecommendationRepository { Future<RecommendationPage> recommendPhotographers(RecommendationQuery query); Future<RecommendationPage> similar(String photographerId, {int limit = 8}); Future<PostRecommendationPage> recommendPosts(PostRecommendationQuery query); Future<void> sendFeedback(List<RecommendationSignal> signals); }`

- [ ] **Step 1: Write the failing tests**

Append to `test/core/vn_time_test.dart` inside `main()`:

```dart
  test('dayKeyOf reads the calendar fields without converting time zones', () {
    expect(dayKeyOf(DateTime.utc(2026, 10, 12)), '2026-10-12');
    expect(dayKeyOf(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    expect(dayKeyOf(DateTime.utc(999, 3, 4)), '0999-03-04');
  });
```

```dart
// test/data/recommendation/recommendation_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';

import '../../support/content_fixtures.dart';

void main() {
  test('a query has sensible defaults and no coordinates', () {
    const q = RecommendationQuery();
    expect(q.sort, RecommendationSort.best);
    expect(q.limit, 20);
    expect(q.excludeIds, isEmpty);
    expect(q.geohash6, isNull);
  });

  test('copyWith changes only what is given; equality is by value', () {
    final a = RecommendationQuery(
      specialtyId: 'portrait',
      date: DateTime.utc(2026, 10, 12),
      geohash6: 'w3gvk1',
      budgetMax: 2000000,
      excludeIds: const ['p1'],
    );
    final b = a.copyWith(limit: 5);
    expect(b.limit, 5);
    expect(b.specialtyId, 'portrait');
    expect(b.excludeIds, ['p1']);
    expect(a, a.copyWith());
    expect(a, isNot(b));
    expect(a.hashCode, a.copyWith().hashCode);
  });

  test('copyWith can clear the cursor to restart a search', () {
    final a = const RecommendationQuery().copyWith(cursor: '20');
    expect(a.cursor, '20');
    expect(a.copyWith(clearCursor: true).cursor, isNull);
  });

  test('markFallback flags a page and keeps everything else', () {
    final page = RecommendationPage(
      items: [
        RecommendedPhotographer(photographer: fixturePhotographer('p1'), rank: 1, score: 0.9),
      ],
      requestId: 'r1',
      algorithm: 'rules-v1',
      algorithmVersion: '1.0.0',
      nextCursor: '1',
    );
    expect(page.usedFallback, isFalse);
    final flagged = page.markFallback();
    expect(flagged.usedFallback, isTrue);
    expect(flagged.requestId, 'r1');
    expect(flagged.nextCursor, '1');
    expect(flagged.items, hasLength(1));
  });

  test('signal types match the API enum', () {
    expect(SignalType.values.map((t) => t.name), ['impression', 'click', 'inquiry', 'booking']);
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/core/vn_time_test.dart test/data/recommendation/recommendation_models_test.dart`
Expected: FAIL (`dayKeyOf` and the model library are undefined).

- [ ] **Step 3: Implement**

Append to `lib/core/vn_time.dart`:

```dart
/// `yyyy-MM-dd` from the calendar fields of [date]. Unlike [vnDateKey] it does
/// not convert from an instant: pass a date that already is the Vietnamese
/// calendar date (a date-picker value, `parseDayKey`, `toVn(...)`).
String dayKeyOf(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';
}
```

```dart
// lib/data/recommendation/recommendation_models.dart
import 'package:flutter/foundation.dart';

import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/reason.dart';

/// "Phù hợp nhất" is the recommender's own order; the others are applied by
/// the plain query path (spec S04).
enum RecommendationSort { best, near, price, rating }

@immutable
class RecommendationQuery {
  const RecommendationQuery({
    this.specialtyId,
    this.styleId,
    this.date,
    this.geohash6,
    this.budgetMax,
    this.sort = RecommendationSort.best,
    this.limit = 20,
    this.cursor,
    this.excludeIds = const [],
  });

  final String? specialtyId;

  /// A style code (`natural_light`, ...); photographers must list it.
  final String? styleId;

  /// A calendar date (Vietnam); only year, month and day are read.
  final DateTime? date;

  /// 6-character geohash of the searcher's area (about 1.2 km). Never
  /// coordinates.
  final String? geohash6;

  /// Integer VND.
  final int? budgetMax;
  final RecommendationSort sort;
  final int limit;
  final String? cursor;
  final List<String> excludeIds;

  RecommendationQuery copyWith({
    String? specialtyId,
    String? styleId,
    DateTime? date,
    String? geohash6,
    int? budgetMax,
    RecommendationSort? sort,
    int? limit,
    String? cursor,
    bool clearCursor = false,
    List<String>? excludeIds,
  }) => RecommendationQuery(
    specialtyId: specialtyId ?? this.specialtyId,
    styleId: styleId ?? this.styleId,
    date: date ?? this.date,
    geohash6: geohash6 ?? this.geohash6,
    budgetMax: budgetMax ?? this.budgetMax,
    sort: sort ?? this.sort,
    limit: limit ?? this.limit,
    cursor: clearCursor ? null : (cursor ?? this.cursor),
    excludeIds: excludeIds ?? this.excludeIds,
  );

  @override
  bool operator ==(Object other) =>
      other is RecommendationQuery &&
      other.specialtyId == specialtyId &&
      other.styleId == styleId &&
      other.date == date &&
      other.geohash6 == geohash6 &&
      other.budgetMax == budgetMax &&
      other.sort == sort &&
      other.limit == limit &&
      other.cursor == cursor &&
      listEquals(other.excludeIds, excludeIds);

  @override
  int get hashCode => Object.hash(
    specialtyId,
    styleId,
    date,
    geohash6,
    budgetMax,
    sort,
    limit,
    cursor,
    Object.hashAll(excludeIds),
  );
}

@immutable
class RecommendedPhotographer {
  const RecommendedPhotographer({
    required this.photographer,
    required this.rank,
    required this.score,
    this.reasons = const [],
    this.distanceKm,
  });

  final PhotographerSummary photographer;

  /// 1-based position across pages.
  final int rank;

  /// 0..1; only meaningful for comparing within one response.
  final double score;
  final List<Reason> reasons;

  /// From the searcher's cell centre; null when either side has no position.
  final double? distanceKm;
}

@immutable
class RecommendationPage {
  const RecommendationPage({
    required this.items,
    required this.requestId,
    required this.algorithm,
    required this.algorithmVersion,
    this.nextCursor,
    this.usedFallback = false,
  });

  final List<RecommendedPhotographer> items;
  final String requestId;
  final String algorithm;
  final String algorithmVersion;
  final String? nextCursor;

  /// True when the remote recommender failed or was too slow and this page was
  /// ranked on the device instead.
  final bool usedFallback;

  RecommendationPage markFallback() => RecommendationPage(
    items: items,
    requestId: requestId,
    algorithm: algorithm,
    algorithmVersion: algorithmVersion,
    nextCursor: nextCursor,
    usedFallback: true,
  );
}

@immutable
class PostRecommendationQuery {
  const PostRecommendationQuery({
    this.specialtyId,
    this.geohash6,
    this.limit = 20,
    this.cursor,
  });

  final String? specialtyId;
  final String? geohash6;
  final int limit;
  final String? cursor;
}

@immutable
class RecommendedPost {
  const RecommendedPost({
    required this.post,
    required this.photographer,
    required this.rank,
    this.reasons = const [],
  });

  final PostSummary post;
  final PhotographerSummary photographer;
  final int rank;
  final List<Reason> reasons;
}

@immutable
class PostRecommendationPage {
  const PostRecommendationPage({
    required this.items,
    required this.requestId,
    required this.algorithm,
    required this.algorithmVersion,
    this.nextCursor,
    this.usedFallback = false,
  });

  final List<RecommendedPost> items;
  final String requestId;
  final String algorithm;
  final String algorithmVersion;
  final String? nextCursor;
  final bool usedFallback;

  PostRecommendationPage markFallback() => PostRecommendationPage(
    items: items,
    requestId: requestId,
    algorithm: algorithm,
    algorithmVersion: algorithmVersion,
    nextCursor: nextCursor,
    usedFallback: true,
  );
}

enum SignalType { impression, click, inquiry, booking }

/// One thing the user did with a recommendation. No position, no phone, no
/// message text (spec 3e.7).
@immutable
class RecommendationSignal {
  const RecommendationSignal({
    required this.type,
    required this.requestId,
    required this.photographerId,
    this.rank,
    this.algorithmVersion,
    required this.at,
  });

  final SignalType type;
  final String requestId;
  final String photographerId;
  final int? rank;
  final String? algorithmVersion;
  final DateTime at;
}

/// The only way screens ask for ranked photographers and posts. Implemented
/// on the device by `LocalRecommender` and, in step 3r, by a remote client of
/// the `recommend` callable.
abstract class RecommendationRepository {
  Future<RecommendationPage> recommendPhotographers(RecommendationQuery query);

  /// Photographers similar to [photographerId] (S03 "Thợ ảnh tương tự").
  Future<RecommendationPage> similar(String photographerId, {int limit = 8});

  /// Order for the Home feed (S01 "Dành cho bạn").
  Future<PostRecommendationPage> recommendPosts(PostRecommendationQuery query);

  /// Never throws: feedback must not break a screen.
  Future<void> sendFeedback(List<RecommendationSignal> signals);
}
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/core/vn_time_test.dart test/data/recommendation && flutter analyze`
Expected: PASS; analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/core lib/data/recommendation test/core test/data/recommendation
git commit -m "feat(recommendation): RecommendationRepository port and query/result types

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `AvailabilityLookup` with a fake, a Firestore adapter and the rule

**Files:**
- Create: `lib/data/recommendation/availability_lookup.dart`, `lib/data/recommendation/firestore_availability_lookup.dart`, `test/data/recommendation/availability_lookup_test.dart`
- Modify: `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs`

**Interfaces:**
- Produces:
  - `enum DayAvailability { pending, booked, off }` (a day with no document is free and is simply absent from results).
  - `abstract class AvailabilityLookup { Future<Map<String, DayAvailability>> on(String dayKey, Iterable<String> photographerIds); }` — keys are photographer ids that have a non-free state on [dayKey].
  - `FakeAvailabilityLookup` with `set(photographerId, dayKey, DayAvailability)`, `List<List<String>> requested` (the id lists passed to `on`), `Object? failWith`.
  - `FirestoreAvailabilityLookup({FirebaseFirestore? db})` reading `availability/{uid}/days/{yyyy-MM-dd}.state` (`pending`, `booked`, `off`; an unknown state counts as `booked`).
  - `availabilityLookupProvider` is added in Task 5.
- Rule: `availability/{uid}/days/{day}` readable by any signed-in user. Writes stay with the calendar plan (2d) and the server. If a `match /availability/{uid}/days/{day}` block already exists, make sure it allows `read: if signedIn()` and add nothing else.

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/recommendation/availability_lookup_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/firestore_availability_lookup.dart';

void lookupContract(String name, Future<AvailabilityLookup> Function() create) {
  group('AvailabilityLookup contract: $name', () {
    test('reports only the non-free states, for the asked day and ids', () async {
      final lookup = await create();
      final r = await lookup.on('2026-10-12', ['p1', 'p2', 'p3', 'p4']);
      expect(r, {
        'p1': DayAvailability.booked,
        'p2': DayAvailability.pending,
        'p3': DayAvailability.off,
      });
    });

    test('another day is free for everybody; no ids is an empty answer', () async {
      final lookup = await create();
      expect(await lookup.on('2026-10-13', ['p1', 'p2']), isEmpty);
      expect(await lookup.on('2026-10-12', const []), isEmpty);
    });
  });
}

void main() {
  lookupContract('fake', () async {
    return FakeAvailabilityLookup()
      ..set('p1', '2026-10-12', DayAvailability.booked)
      ..set('p2', '2026-10-12', DayAvailability.pending)
      ..set('p3', '2026-10-12', DayAvailability.off)
      ..set('p4', '2026-10-14', DayAvailability.booked);
  });

  lookupContract('firestore', () async {
    final db = FakeFirebaseFirestore();
    Future<void> day(String uid, String key, String state) =>
        db.collection('availability').doc(uid).collection('days').doc(key).set({'state': state});
    await day('p1', '2026-10-12', 'booked');
    await day('p2', '2026-10-12', 'pending');
    await day('p3', '2026-10-12', 'off');
    await day('p4', '2026-10-14', 'booked');
    return FirestoreAvailabilityLookup(db: db);
  });

  test('the fake records what was asked, and can fail', () async {
    final fake = FakeAvailabilityLookup();
    await fake.on('2026-10-12', ['a', 'b']);
    expect(fake.requested, [['a', 'b']]);
    fake.failWith = StateError('offline');
    expect(() => fake.on('2026-10-12', ['a']), throwsStateError);
  });

  test('an unknown state in the database is treated as booked (safe side)', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('availability').doc('p1').collection('days').doc('2026-10-12').set({'state': 'weird'});
    final r = await FirestoreAvailabilityLookup(db: db).on('2026-10-12', ['p1']);
    expect(r['p1'], DayAvailability.booked);
  });

  test('duplicate ids are read once', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('availability').doc('p1').collection('days').doc('2026-10-12').set({'state': 'off'});
    final r = await FirestoreAvailabilityLookup(db: db).on('2026-10-12', ['p1', 'p1']);
    expect(r, {'p1': DayAvailability.off});
  });
}
```

Append to `firebase/rules-test/rules.test.mjs`:

```js
// ---- availability days: readable by signed-in users, not writable by strangers ----
test('availability days can be read by any signed-in user, including a missing day', async () => {
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'availability/pa/days/2026-10-12'), { state: 'booked' }));
  const db = env.authenticatedContext('viewer').firestore();
  await assertSucceeds(getDoc(doc(db, 'availability/pa/days/2026-10-12')));
  await assertSucceeds(getDoc(doc(db, 'availability/pa/days/2026-10-13')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'availability/pa/days/2026-10-12')));
});

test('a stranger cannot book or free someone else\'s day', async () => {
  const db = env.authenticatedContext('viewer').firestore();
  await assertFails(setDoc(doc(db, 'availability/pa/days/2026-10-12'), { state: 'off' }));
});
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/data/recommendation/availability_lookup_test.dart`; from `firebase/rules-test`: `npm test`
Expected: FAIL (library missing; rules deny the read).

- [ ] **Step 3: Implement**

```dart
// lib/data/recommendation/availability_lookup.dart

/// A day that is not free. A free day has no document and is absent from the
/// lookup result.
enum DayAvailability { pending, booked, off }

/// Reads the calendar state of many photographers on one day, for ranking and
/// for dropping people who are not free on the day a customer picked.
abstract class AvailabilityLookup {
  Future<Map<String, DayAvailability>> on(
    String dayKey,
    Iterable<String> photographerIds,
  );
}

class FakeAvailabilityLookup implements AvailabilityLookup {
  final _states = <String, Map<String, DayAvailability>>{};

  /// The id lists passed to [on], one entry per call.
  final List<List<String>> requested = [];
  Object? failWith;

  void set(String photographerId, String dayKey, DayAvailability state) {
    (_states[dayKey] ??= {})[photographerId] = state;
  }

  @override
  Future<Map<String, DayAvailability>> on(
    String dayKey,
    Iterable<String> photographerIds,
  ) async {
    if (failWith != null) {
      throw failWith!;
    }
    final ids = photographerIds.toList();
    requested.add(ids);
    final day = _states[dayKey] ?? const {};
    return {
      for (final id in ids.toSet())
        if (day[id] != null) id: day[id]!,
    };
  }
}
```

```dart
// lib/data/recommendation/firestore_availability_lookup.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/recommendation/availability_lookup.dart';

class FirestoreAvailabilityLookup implements AvailabilityLookup {
  FirestoreAvailabilityLookup({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DayAvailability _state(Object? raw) => switch (raw) {
    'pending' => DayAvailability.pending,
    'off' => DayAvailability.off,
    'booked' => DayAvailability.booked,
    // A state we do not know is treated as unavailable rather than offering a
    // day that may be taken.
    _ => DayAvailability.booked,
  };

  @override
  Future<Map<String, DayAvailability>> on(
    String dayKey,
    Iterable<String> photographerIds,
  ) async {
    final ids = photographerIds.toSet().toList();
    final snaps = await Future.wait([
      for (final id in ids)
        _db
            .collection('availability')
            .doc(id)
            .collection('days')
            .doc(dayKey)
            .get(),
    ]);
    return {
      for (var i = 0; i < ids.length; i++)
        if (snaps[i].exists) ids[i]: _state(snaps[i].data()?['state']),
    };
  }
}
```

In `firebase/firestore.rules`, above the final catch-all `match /{document=**}`, add (skip it if a block for this path already exists and just ensure it has `allow read: if signedIn();`):

```
    // Calendar days: anyone signed in may read them (customers pick a free day).
    // The owner's "off" days and the server's booked/pending days are written by
    // the calendar plan and Cloud Functions.
    match /availability/{uid}/days/{day} {
      allow read: if signedIn();
      allow write: if false;
    }
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter test test/data/recommendation/availability_lookup_test.dart && flutter analyze`; from `firebase/rules-test`: `npm test`
Expected: PASS (2 + 2 contract tests per implementation, 3 extra); all rules tests pass. If plan 2d has already added owner writes in a block for the same path, keep its write rules and only keep the `read` line from this block; the second rules test ("a stranger cannot...") then still holds.

- [ ] **Step 5: Commit**

```bash
git add lib/data/recommendation test/data/recommendation firebase
git commit -m "feat(recommendation): AvailabilityLookup port, fake, Firestore adapter and rule

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `LocalRecommender`

**Files:**
- Create: `lib/data/recommendation/local_recommender.dart`, `test/data/recommendation/local_recommender_test.dart`
- Modify: `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `PostRepository`, `PhotographerRepository`, `AvailabilityLookup`, `RecommendationRepository` and the types of Task 1, `formatDay`, `formatDistance`, `formatRating`, `specialtyLabel`, `decodeGeohash`, `haversineKm`, `vnDateKey`, `dayKeyOf`.
- Produces: `class LocalRecommender implements RecommendationRepository` with `LocalRecommender({required PostRepository posts, required PhotographerRepository photographers, required AvailabilityLookup availability, DateTime Function()? clock, AppLocalizations? strings})`; constants `algorithm = 'local-fallback'`, `version = '1.0.0'`, `candidatePool = 200`, `maxDatedCandidates = 60`.
- l10n: `reasonFreeOnDate(day)` "Rảnh {day}", `reasonSkillMatch(specialty)` "Chuyên {specialty}", `reasonNear(distance)` "Cách {distance}", `reasonTopRated(rating, count)` "★ {rating} · {count} đánh giá", `reasonFastReply` "Phản hồi nhanh", `reasonNewTalent` "Mới tham gia".

Rules (spec 3e.1 "luôn có đường lui", simplified from `rules-v1`):

- **Filters:** `excludeIds`; `specialtyId` and `styleId` (photographer lists them); `budgetMax` (`startingPriceVnd` unknown passes); with a `date`, photographers that are `booked` or `off` that day are dropped, `pending` ones stay with half the availability score.
- **Score** `= 0.5 * quality + 0.3 * geo + 0.2 * availability`. `quality = clamp01((smoothed - 3) / 2 + 0.05 * log10(1 + completed))` with the Bayesian rating `smoothed = (v*R + m*C) / (v + m)`, `m = 10`, `C = 4.3` (a photographer without reviews counts as `C`); `geo = exp(-d / 8)` with `d` km from the centre of the searcher's `geohash6` cell, `0.5` when either position is unknown; `availability = 1` free on the picked date, `0.5` pending, and without a date `1` if `nextFreeDate` is within 7 days else `0.4`.
- **Order:** `best` by score; `near` by distance (unknown last); `price` by `startingPriceVnd` ascending (unknown last); `rating` by smoothed rating. Ties by the better score, then id.
- **Reasons** (at most 3, in this priority): free on the date (picked, or the next free day within 7 days), specialty match, near (within 5 km), top rated (at least 10 reviews and smoothed 4.7 or more), fast reply (median reply at most 60 minutes), new (profile at most 30 days old).
- **Paging:** the cursor is the offset into the ranked list.
- **Posts** (`recommendPosts`): one page of `work` posts newest first from `PostRepository.feed`, authors joined, posts whose photographer has a free day in the next 14 days are moved to the front keeping order inside each group; posts without a known author are dropped; the page cursor is the repository's.
- **Similar:** photographers sharing at least one specialty with the target, ordered by `0.6 * Jaccard + 0.25 * closeness + 0.15 * quality`.
- **Feedback:** accepted and dropped (nothing is stored on the device).

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/recommendation/local_recommender_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/reason.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/local_recommender.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';

import '../../support/content_fixtures.dart';
import 'recommendation_contract.dart';

LocalRecommender make({
  List<PhotographerSummary> photographers = const [],
  List<PostSummary> posts = const [],
  FakeAvailabilityLookup? availability,
}) => LocalRecommender(
  posts: FakePostRepository(posts),
  photographers: FakePhotographerRepository(photographers),
  availability: availability ?? FakeAvailabilityLookup(),
  clock: () => fixtureNow,
);

List<String> ids(RecommendationPage p) => p.items.map((e) => e.photographer.id).toList();

// The 6-character cell around central Ho Chi Minh City; its centre is within
// about 600 m of the point.
final _hcm6 = encodeGeohash(10.7769, 106.7009, precision: 6);

void main() {
  recommendationRepositoryContract('local', (world) async {
    final availability = FakeAvailabilityLookup();
    world.unavailable.forEach((id, days) {
      for (final d in days) {
        availability.set(id, d, DayAvailability.booked);
      }
    });
    return LocalRecommender(
      posts: FakePostRepository(world.posts),
      photographers: FakePhotographerRepository(world.photographers),
      availability: availability,
      clock: () => fixtureNow,
    );
  });

  group('ranking', () {
    test('a well-reviewed photographer beats a perfect score from one review', () async {
      final r = make(
        photographers: [
          fixturePhotographer('few', rating: 5, reviews: 1, completed: 1),
          fixturePhotographer('many', rating: 4.9, reviews: 58, completed: 112),
        ],
      );
      expect(ids(await r.recommendPhotographers(const RecommendationQuery())), ['many', 'few']);
    });

    test('a closer photographer wins when quality is equal', () async {
      final r = make(
        photographers: [
          fixturePhotographer('far', lat: 21.0285, lng: 105.8542),
          fixturePhotographer('near', lat: 10.7869, lng: 106.7009),
        ],
      );
      final page = await r.recommendPhotographers(const RecommendationQuery(geohash6: _hcm6));
      expect(ids(page), ['near', 'far']);
      expect(page.items.first.distanceKm, lessThan(5));
      expect(page.items.last.distanceKm, greaterThan(1000));
    });

    test('without a position, distance is neutral and ties fall back to id', () async {
      final r = make(photographers: [fixturePhotographer('b'), fixturePhotographer('a')]);
      expect(ids(await r.recommendPhotographers(const RecommendationQuery())), ['a', 'b']);
    });

    test('free soon outranks free later at equal quality', () async {
      final r = make(
        photographers: [
          fixturePhotographer('later', nextFreeDate: '2026-11-20'),
          fixturePhotographer('soon', nextFreeDate: '2026-10-02'),
        ],
      );
      expect(ids(await r.recommendPhotographers(const RecommendationQuery())), ['soon', 'later']);
    });

    test('sort modes: near, price, rating', () async {
      final r = make(
        photographers: [
          fixturePhotographer('a', lat: 21.0285, lng: 105.8542, startingPrice: 900000, rating: 4.0, reviews: 30),
          fixturePhotographer('b', lat: 10.7869, lng: 106.7009, startingPrice: 3000000, rating: 4.9, reviews: 60),
          fixturePhotographer('c', lat: 10.9, lng: 106.7, startingPrice: null, rating: 4.5, reviews: 40),
        ],
      );
      Future<List<String>> by(RecommendationSort s) async =>
          ids(await r.recommendPhotographers(RecommendationQuery(sort: s, geohash6: _hcm6)));
      expect(await by(RecommendationSort.near), ['b', 'c', 'a']);
      expect(await by(RecommendationSort.price), ['a', 'b', 'c'], reason: 'unknown price last');
      expect(await by(RecommendationSort.rating), ['b', 'c', 'a']);
    });
  });

  group('filters', () {
    final pool = [
      fixturePhotographer('p', specialties: const ['portrait'], startingPrice: 1000000),
      fixturePhotographer('w', specialties: const ['wedding'], startingPrice: 8000000),
      fixturePhotographer('u', specialties: const ['portrait'], startingPrice: null),
    ];

    test('style keeps only photographers who list it', () async {
      final r = make(
        photographers: [
          fixturePhotographer('film', styles: const ['film']),
          fixturePhotographer('natural', styles: const ['natural_light']),
          fixturePhotographer('none'),
        ],
      );
      expect(ids(await r.recommendPhotographers(const RecommendationQuery(styleId: 'film'))), ['film']);
    });

    test('specialty and budget; an unknown price passes the budget', () async {
      final r = make(photographers: pool);
      expect(
        ids(await r.recommendPhotographers(const RecommendationQuery(specialtyId: 'portrait', budgetMax: 2000000))).toSet(),
        {'p', 'u'},
      );
      expect(ids(await r.recommendPhotographers(const RecommendationQuery(budgetMax: 2000000))).toSet(), {'p', 'u'});
    });

    test('a booked or day-off photographer is dropped for the picked date, a pending one stays', () async {
      final availability = FakeAvailabilityLookup()
        ..set('p', '2026-10-12', DayAvailability.booked)
        ..set('w', '2026-10-12', DayAvailability.off)
        ..set('u', '2026-10-12', DayAvailability.pending);
      final r = make(photographers: pool, availability: availability);
      final page = await r.recommendPhotographers(RecommendationQuery(date: DateTime.utc(2026, 10, 12)));
      expect(ids(page), ['u']);
      expect(page.items.single.reasons.map((e) => e.code), isNot(contains(ReasonCode.freeOnDate)),
          reason: 'pending is not "free"');
    });

    test('a pending photographer ranks below an equal free one', () async {
      final availability = FakeAvailabilityLookup()..set('x', '2026-10-12', DayAvailability.pending);
      final r = make(
        photographers: [fixturePhotographer('x'), fixturePhotographer('y')],
        availability: availability,
      );
      final page = await r.recommendPhotographers(RecommendationQuery(date: DateTime.utc(2026, 10, 12)));
      expect(ids(page), ['y', 'x']);
    });

    test('with a date at most 60 day documents are read, best quality first', () async {
      final availability = FakeAvailabilityLookup();
      final many = [
        for (var i = 0; i < 100; i++)
          fixturePhotographer('c${i.toString().padLeft(3, '0')}', reviews: 10 + i, rating: 4.9),
      ];
      final r = make(photographers: many, availability: availability);
      await r.recommendPhotographers(RecommendationQuery(date: DateTime.utc(2026, 10, 12)));
      expect(availability.requested.single, hasLength(60));
      expect(availability.requested.single, contains('c099'), reason: 'the most reviewed are kept');
      expect(availability.requested.single, isNot(contains('c000')));
    });

    test('no date means no availability reads', () async {
      final availability = FakeAvailabilityLookup();
      await make(photographers: pool, availability: availability)
          .recommendPhotographers(const RecommendationQuery());
      expect(availability.requested, isEmpty);
    });
  });

  group('reasons', () {
    Future<List<Reason>> reasonsFor(PhotographerSummary p, RecommendationQuery q) async =>
        (await make(photographers: [p]).recommendPhotographers(q)).items.single.reasons;

    test('free on the picked date, specialty and near come first, at most three', () async {
      final p = fixturePhotographer('p1', lat: 10.7869, lng: 106.7009, nextFreeDate: '2026-10-03', responseMinutes: 30);
      final reasons = await reasonsFor(
        p,
        RecommendationQuery(
          specialtyId: 'portrait',
          date: DateTime.utc(2026, 10, 3),
          geohash6: _hcm6,
        ),
      );
      expect(reasons.map((r) => r.code), [ReasonCode.freeOnDate, ReasonCode.skillMatch, ReasonCode.near]);
      expect(reasons[0].text, 'Rảnh T7 03/10');
      expect(reasons[1].text, 'Chuyên chân dung');
      expect(reasons[2].text, startsWith('Cách '));
      expect(reasons[2].text, endsWith(' km'));
    });

    test('without filters: next free day, top rated, fast reply', () async {
      final p = fixturePhotographer('p1', nextFreeDate: '2026-10-03', rating: 4.9, reviews: 58, responseMinutes: 45);
      final reasons = await reasonsFor(p, const RecommendationQuery());
      expect(reasons.map((r) => r.code), [ReasonCode.freeOnDate, ReasonCode.topRated, ReasonCode.fastReply]);
      expect(reasons[1].text, '★ 4,9 · 58 đánh giá');
      expect(reasons[2].text, 'Phản hồi nhanh');
    });

    test('a new profile gets the "Mới tham gia" reason, an old one does not', () async {
      final fresh = await reasonsFor(
        fixturePhotographer('n', reviews: 0, rating: 0, createdAgo: const Duration(days: 10), responseMinutes: 600),
        const RecommendationQuery(),
      );
      expect(fresh.map((r) => r.code), [ReasonCode.newTalent]);
      expect(fresh.single.text, 'Mới tham gia');
      final old = await reasonsFor(
        fixturePhotographer('o', reviews: 0, rating: 0, responseMinutes: 600),
        const RecommendationQuery(),
      );
      expect(old, isEmpty);
    });

    test('top rated needs a real sample', () async {
      final r = await reasonsFor(
        fixturePhotographer('t', rating: 5, reviews: 3, responseMinutes: 600),
        const RecommendationQuery(),
      );
      expect(r.map((e) => e.code), isNot(contains(ReasonCode.topRated)));
    });
  });

  group('paging', () {
    test('the cursor is an offset and ranks continue across pages', () async {
      final r = make(photographers: [for (var i = 0; i < 5; i++) fixturePhotographer('p$i', reviews: 10 + i)]);
      final p1 = await r.recommendPhotographers(const RecommendationQuery(limit: 2));
      expect(p1.nextCursor, '2');
      expect(p1.items.map((e) => e.rank), [1, 2]);
      final p2 = await r.recommendPhotographers(RecommendationQuery(limit: 2, cursor: p1.nextCursor));
      expect(p2.items.map((e) => e.rank), [3, 4]);
      final p3 = await r.recommendPhotographers(RecommendationQuery(limit: 2, cursor: p2.nextCursor));
      expect(p3.items.map((e) => e.rank), [5]);
      expect(p3.nextCursor, isNull);
    });

    test('a broken cursor restarts at the top', () async {
      final r = make(photographers: [fixturePhotographer('a'), fixturePhotographer('b')]);
      final page = await r.recommendPhotographers(const RecommendationQuery(cursor: 'oops'));
      expect(page.items.first.rank, 1);
    });

    test('identifies itself', () async {
      final page = await make().recommendPhotographers(const RecommendationQuery());
      expect(page.algorithm, 'local-fallback');
      expect(page.algorithmVersion, '1.0.0');
      expect(page.requestId, startsWith('local-'));
      expect(page.usedFallback, isFalse);
      expect(page.items, isEmpty);
    });
  });

  group('similar', () {
    test('shares a specialty, excludes itself, closest overlap first', () async {
      final r = make(
        photographers: [
          fixturePhotographer('me', specialties: const ['portrait', 'wedding']),
          fixturePhotographer('both', specialties: const ['portrait', 'wedding']),
          fixturePhotographer('one', specialties: const ['portrait', 'family']),
          fixturePhotographer('none', specialties: const ['food']),
        ],
      );
      final page = await r.similar('me');
      expect(ids(page), ['both', 'one']);
      expect(page.items.first.reasons.first.code, ReasonCode.skillMatch);
    });

    test('an unknown photographer has no similar ones, and the limit holds', () async {
      final r = make(photographers: [for (var i = 0; i < 12; i++) fixturePhotographer('p$i')]);
      expect((await r.similar('ghost')).items, isEmpty);
      expect((await r.similar('p0', limit: 3)).items, hasLength(3));
    });
  });

  group('recommendPosts', () {
    final photographers = [
      fixturePhotographer('soon', nextFreeDate: '2026-10-05'),
      fixturePhotographer('later', nextFreeDate: '2026-12-01'),
      fixturePhotographer('never'),
    ];
    final posts = [
      fixturePost('a', photographerId: 'later', age: const Duration(hours: 1)),
      fixturePost('b', photographerId: 'soon', age: const Duration(hours: 2)),
      fixturePost('c', photographerId: 'ghost', age: const Duration(hours: 3)),
      fixturePost('d', photographerId: 'never', age: const Duration(hours: 4)),
      fixturePost('e', photographerId: 'soon', age: const Duration(hours: 5)),
      fixturePost('shoot', photographerId: 'soon', kind: PostKind.realShoot, age: const Duration(minutes: 5)),
    ];

    test('photographers free in the next 14 days come first; others keep their order', () async {
      final page = await make(photographers: photographers, posts: posts)
          .recommendPosts(const PostRecommendationQuery());
      expect(page.items.map((e) => e.post.id), ['b', 'e', 'a', 'd']);
      expect(page.items.map((e) => e.rank), [1, 2, 3, 4]);
    });

    test('real-shoot posts and posts of unknown authors are not in the feed', () async {
      final page = await make(photographers: photographers, posts: posts)
          .recommendPosts(const PostRecommendationQuery());
      expect(page.items.map((e) => e.post.id), isNot(contains('shoot')));
      expect(page.items.map((e) => e.post.id), isNot(contains('c')));
    });

    test('boosted posts say why', () async {
      final page = await make(photographers: photographers, posts: posts)
          .recommendPosts(const PostRecommendationQuery());
      expect(page.items.first.reasons.single.code, ReasonCode.freeOnDate);
      expect(page.items.first.reasons.single.text, 'Rảnh T2 05/10');
      expect(page.items.last.reasons, isEmpty);
    });

    test('category filter and paging pass through to the post repository', () async {
      final tagged = [
        fixturePost('w1', photographerId: 'soon', specialtyId: 'wedding', age: const Duration(hours: 1)),
        fixturePost('w2', photographerId: 'soon', specialtyId: 'wedding', age: const Duration(hours: 2)),
        fixturePost('p1', photographerId: 'soon', specialtyId: 'portrait', age: const Duration(hours: 3)),
      ];
      final r = make(photographers: photographers, posts: tagged);
      final first = await r.recommendPosts(const PostRecommendationQuery(specialtyId: 'wedding', limit: 1));
      expect(first.items.map((e) => e.post.id), ['w1']);
      expect(first.nextCursor, isNotNull);
      final second = await r.recommendPosts(PostRecommendationQuery(specialtyId: 'wedding', limit: 1, cursor: first.nextCursor));
      expect(second.items.map((e) => e.post.id), ['w2']);
      expect(second.nextCursor, isNull);
    });
  });

  test('sendFeedback accepts anything and never throws', () async {
    final r = make();
    await r.sendFeedback(const []);
    await r.sendFeedback([
      RecommendationSignal(type: SignalType.click, requestId: 'r', photographerId: 'p1', rank: 1, at: fixtureNow),
    ]);
  });
}
```

```dart
// test/data/recommendation/recommendation_contract.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/reason.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';

import '../../support/content_fixtures.dart';

/// What every implementation is tested against: a fixed set of photographers,
/// posts and busy days. The remote implementation (step 3r) builds a stub
/// server over the same world.
class RecommendationWorld {
  RecommendationWorld({
    required this.photographers,
    required this.posts,
    required this.unavailable,
  });

  final List<PhotographerSummary> photographers;
  final List<PostSummary> posts;

  /// photographerId -> day keys on which that photographer is not free.
  final Map<String, Set<String>> unavailable;
}

RecommendationWorld contractWorld() => RecommendationWorld(
  photographers: [
    fixturePhotographer('p1', specialties: const ['portrait', 'wedding'], rating: 4.9, reviews: 58, startingPrice: 1500000, nextFreeDate: '2026-10-03'),
    fixturePhotographer('p2', specialties: const ['wedding'], rating: 4.5, reviews: 12, startingPrice: 8000000),
    fixturePhotographer('p3', specialties: const ['portrait'], rating: 4.95, reviews: 200, startingPrice: 2000000),
    fixturePhotographer('p4', specialties: const ['family'], rating: 3.9, reviews: 5, startingPrice: 1200000),
    fixturePhotographer('p5', specialties: const ['portrait'], rating: 0, reviews: 0, startingPrice: 1000000, createdAgo: const Duration(days: 10)),
    fixturePhotographer('p6', specialties: const ['portrait'], rating: 4.6, reviews: 30, startingPrice: 9000000),
  ],
  posts: [
    fixturePost('post1', photographerId: 'p1', age: const Duration(hours: 1)),
    fixturePost('post2', photographerId: 'p2', age: const Duration(hours: 2)),
    fixturePost('post3', photographerId: 'ghost', age: const Duration(hours: 3)),
  ],
  unavailable: {
    'p3': {'2026-10-12'},
  },
);

typedef RecommendationFactory = Future<RecommendationRepository> Function(RecommendationWorld world);

/// Invariants that hold for any ranking algorithm. A new implementation (the
/// remote client, a learned ranker) must pass these unchanged.
void recommendationRepositoryContract(String name, RecommendationFactory create) {
  group('RecommendationRepository contract: $name', () {
    late RecommendationRepository repo;
    setUp(() async => repo = await create(contractWorld()));

    List<String> ids(RecommendationPage p) => p.items.map((e) => e.photographer.id).toList();

    test('returns every candidate once, ranked 1..n, with response metadata', () async {
      final page = await repo.recommendPhotographers(const RecommendationQuery());
      expect(ids(page).toSet(), {'p1', 'p2', 'p3', 'p4', 'p5', 'p6'});
      expect(ids(page), hasLength(6));
      expect(page.items.map((e) => e.rank), [1, 2, 3, 4, 5, 6]);
      expect(page.requestId, isNotEmpty);
      expect(page.algorithm, isNotEmpty);
      expect(page.algorithmVersion, isNotEmpty);
      for (final item in page.items) {
        expect(item.score, inInclusiveRange(0, 1));
      }
    });

    test('scores never increase down the list for the default order', () async {
      final page = await repo.recommendPhotographers(const RecommendationQuery());
      final scores = page.items.map((e) => e.score).toList();
      for (var i = 1; i < scores.length; i++) {
        expect(scores[i], lessThanOrEqualTo(scores[i - 1]));
      }
    });

    test('a specialty keeps only photographers who offer it', () async {
      final page = await repo.recommendPhotographers(const RecommendationQuery(specialtyId: 'portrait'));
      expect(ids(page).toSet(), {'p1', 'p3', 'p5', 'p6'});
    });

    test('a busy photographer is absent on the picked day and present otherwise', () async {
      final busy = await repo.recommendPhotographers(RecommendationQuery(date: DateTime.utc(2026, 10, 12)));
      expect(ids(busy), isNot(contains('p3')));
      expect(ids(busy).toSet(), {'p1', 'p2', 'p4', 'p5', 'p6'});
      final other = await repo.recommendPhotographers(RecommendationQuery(date: DateTime.utc(2026, 10, 13)));
      expect(ids(other), contains('p3'));
    });

    test('a budget removes the expensive ones', () async {
      final page = await repo.recommendPhotographers(const RecommendationQuery(budgetMax: 3000000));
      expect(ids(page).toSet(), {'p1', 'p3', 'p4', 'p5'});
    });

    test('excluded ids are never returned', () async {
      final page = await repo.recommendPhotographers(const RecommendationQuery(excludeIds: ['p1', 'p3']));
      expect(ids(page).toSet(), {'p2', 'p4', 'p5', 'p6'});
    });

    test('pages are disjoint and together equal the unpaged order', () async {
      final all = ids(await repo.recommendPhotographers(const RecommendationQuery()));
      final seen = <String>[];
      String? cursor;
      var ranks = <int>[];
      do {
        final page = await repo.recommendPhotographers(RecommendationQuery(limit: 2, cursor: cursor));
        seen.addAll(ids(page));
        ranks = [...ranks, ...page.items.map((e) => e.rank)];
        cursor = page.nextCursor;
      } while (cursor != null);
      expect(seen, all);
      expect(ranks, [1, 2, 3, 4, 5, 6]);
    });

    test('every result has at most three reasons, each with a known code and a text', () async {
      final page = await repo.recommendPhotographers(
        RecommendationQuery(specialtyId: 'portrait', date: DateTime.utc(2026, 10, 3), geohash6: 'w3gvk1'),
      );
      for (final item in page.items) {
        expect(item.reasons.length, lessThanOrEqualTo(3));
        for (final r in item.reasons) {
          expect(ReasonCode.values, contains(r.code));
          expect(r.text.trim(), isNotEmpty);
        }
      }
    });

    test('similar never returns the photographer itself and respects the limit', () async {
      final page = await repo.similar('p1', limit: 3);
      expect(ids(page), isNot(contains('p1')));
      expect(page.items.length, lessThanOrEqualTo(3));
      expect(page.items.map((e) => e.rank), List.generate(page.items.length, (i) => i + 1));
    });

    test('post recommendations are known authors only, ranked 1..n', () async {
      final page = await repo.recommendPosts(const PostRecommendationQuery());
      final postIds = page.items.map((e) => e.post.id).toSet();
      expect(postIds, {'post1', 'post2'});
      expect(page.items.map((e) => e.rank), [1, 2]);
      expect(page.requestId, isNotEmpty);
      for (final item in page.items) {
        expect(item.photographer.id, item.post.photographerId);
      }
    });

    test('feedback is accepted for an empty and a normal batch without throwing', () async {
      await repo.sendFeedback(const []);
      await repo.sendFeedback([
        RecommendationSignal(type: SignalType.impression, requestId: 'r1', photographerId: 'p1', rank: 1, algorithmVersion: '1', at: fixtureNow),
        RecommendationSignal(type: SignalType.booking, requestId: 'r1', photographerId: 'p1', at: fixtureNow),
      ]);
    });
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/recommendation/local_recommender_test.dart`
Expected: FAIL, `LocalRecommender` and the reason strings are undefined.

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb` (comma after the previous last entry) and run `flutter gen-l10n`:

```json
  "reasonFreeOnDate": "Rảnh {day}",
  "@reasonFreeOnDate": {
    "placeholders": {
      "day": {"type": "String"}
    }
  },
  "reasonSkillMatch": "Chuyên {specialty}",
  "@reasonSkillMatch": {
    "placeholders": {
      "specialty": {"type": "String"}
    }
  },
  "reasonNear": "Cách {distance}",
  "@reasonNear": {
    "placeholders": {
      "distance": {"type": "String"}
    }
  },
  "reasonTopRated": "★ {rating} · {count} đánh giá",
  "@reasonTopRated": {
    "placeholders": {
      "rating": {"type": "String"},
      "count": {"type": "int"}
    }
  },
  "reasonFastReply": "Phản hồi nhanh",
  "reasonNewTalent": "Mới tham gia"
```

```dart
// lib/data/recommendation/local_recommender.dart
import 'dart:math' as math;

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/reason.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/l10n/app_localizations.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

double _unit(double x) => math.min(1.0, math.max(0.0, x));

/// Smoothed rating `(v*R + m*C) / (v + m)`: a handful of five-star reviews do
/// not beat a long record.
double smoothedRating(PhotographerSummary p) {
  const m = 10.0;
  const c = 4.3;
  final v = p.reviewCount.toDouble();
  final r = p.hasRating ? p.ratingAvg : c;
  return (v * r + m * c) / (v + m);
}

double _quality(PhotographerSummary p) {
  final base = (smoothedRating(p) - 3) / 2;
  final boost = 0.05 * (math.log(1 + p.completedCount) / math.ln10);
  return _unit(base + boost);
}

class _Scored {
  _Scored(this.p, this.score, this.distanceKm, this.day);
  final PhotographerSummary p;
  final double score;
  final double? distanceKm;
  final DayAvailability? day;
}

/// Ranks on the device with stars (smoothed), distance and availability. It is
/// the safety net when the remote recommender is down, slow or offline, and it
/// is what the app uses until the recommender service exists.
class LocalRecommender implements RecommendationRepository {
  LocalRecommender({
    required PostRepository posts,
    required PhotographerRepository photographers,
    required AvailabilityLookup availability,
    DateTime Function()? clock,
    AppLocalizations? strings,
  }) : _posts = posts,
       _photographers = photographers,
       _availability = availability,
       _now = clock ?? (() => DateTime.now().toUtc()),
       _l = strings ?? AppLocalizationsVi();

  static const algorithm = 'local-fallback';
  static const version = '1.0.0';
  static const candidatePool = 200;
  static const maxDatedCandidates = 60;

  final PostRepository _posts;
  final PhotographerRepository _photographers;
  final AvailabilityLookup _availability;
  final DateTime Function() _now;
  final AppLocalizations _l;

  String _requestId() => 'local-${_now().microsecondsSinceEpoch}';

  ({double lat, double lng})? _origin(String? geohash6) =>
      geohash6 == null ? null : decodeGeohash(geohash6);

  double? _distance(({double lat, double lng})? from, PhotographerSummary p) =>
      from == null || !p.hasGeo ? null : haversineKm(from.lat, from.lng, p.lat!, p.lng!);

  bool _freeSoon(PhotographerSummary p, DateTime now, {int days = 7}) {
    final d = p.nextFreeDate;
    if (d == null) {
      return false;
    }
    return d.compareTo(vnDateKey(now)) >= 0 &&
        d.compareTo(vnDateKey(now.add(Duration(days: days)))) < 0;
  }

  List<Reason> _reasons(
    PhotographerSummary p, {
    String? specialtyId,
    DateTime? date,
    double? distanceKm,
    DayAvailability? day,
    required DateTime now,
  }) {
    final out = <Reason>[];
    if (date != null) {
      if (day == null) {
        out.add(Reason(code: ReasonCode.freeOnDate, text: _l.reasonFreeOnDate(formatDay(date))));
      }
    } else if (_freeSoon(p, now)) {
      out.add(Reason(code: ReasonCode.freeOnDate, text: _l.reasonFreeOnDate(formatDay(p.nextFreeDay!))));
    }
    if (specialtyId != null && p.specialtyIds.contains(specialtyId)) {
      out.add(Reason(
        code: ReasonCode.skillMatch,
        text: _l.reasonSkillMatch(specialtyLabel(specialtyId).toLowerCase()),
      ));
    }
    if (distanceKm != null && distanceKm <= 5) {
      out.add(Reason(code: ReasonCode.near, text: _l.reasonNear(formatDistance(distanceKm))));
    }
    if (p.reviewCount >= 10 && smoothedRating(p) >= 4.7) {
      out.add(Reason(
        code: ReasonCode.topRated,
        text: _l.reasonTopRated(formatRating(p.ratingAvg), p.reviewCount),
      ));
    }
    if (p.responseMinutes != null && p.responseMinutes! <= 60) {
      out.add(Reason(code: ReasonCode.fastReply, text: _l.reasonFastReply));
    }
    final created = p.createdAt;
    if (created != null && now.difference(created) <= const Duration(days: 30)) {
      out.add(Reason(code: ReasonCode.newTalent, text: _l.reasonNewTalent));
    }
    return out.take(3).toList();
  }

  int _offset(String? cursor) => int.tryParse(cursor ?? '') ?? 0;

  @override
  Future<RecommendationPage> recommendPhotographers(RecommendationQuery q) async {
    final now = _now();
    var pool = (await _photographers.candidates(limit: candidatePool))
        .where((p) => !q.excludeIds.contains(p.id))
        .where((p) => q.specialtyId == null || p.specialtyIds.contains(q.specialtyId))
        .where((p) => q.styleId == null || p.styleIds.contains(q.styleId))
        .where((p) => q.budgetMax == null || p.startingPriceVnd == null || p.startingPriceVnd! <= q.budgetMax!)
        .toList();

    var day = const <String, DayAvailability>{};
    if (q.date != null) {
      pool.sort((a, b) {
        final byQuality = _quality(b).compareTo(_quality(a));
        return byQuality != 0 ? byQuality : a.id.compareTo(b.id);
      });
      if (pool.length > maxDatedCandidates) {
        pool = pool.sublist(0, maxDatedCandidates);
      }
      day = await _availability.on(dayKeyOf(q.date!), pool.map((p) => p.id));
      pool = pool
          .where((p) => day[p.id] != DayAvailability.booked && day[p.id] != DayAvailability.off)
          .toList();
    }

    final origin = _origin(q.geohash6);
    final scored = <_Scored>[];
    for (final p in pool) {
      final d = _distance(origin, p);
      final geo = d == null ? 0.5 : math.exp(-d / 8);
      final state = day[p.id];
      final availability = q.date != null
          ? (state == DayAvailability.pending ? 0.5 : 1.0)
          : (_freeSoon(p, now) ? 1.0 : 0.4);
      scored.add(_Scored(p, 0.5 * _quality(p) + 0.3 * geo + 0.2 * availability, d, state));
    }

    int byScore(_Scored a, _Scored b) {
      final s = b.score.compareTo(a.score);
      return s != 0 ? s : a.p.id.compareTo(b.p.id);
    }

    int nullsLast<T extends Comparable<T>>(T? a, T? b) {
      if (a == null && b == null) {
        return 0;
      }
      if (a == null) {
        return 1;
      }
      if (b == null) {
        return -1;
      }
      return a.compareTo(b);
    }

    scored.sort(switch (q.sort) {
      RecommendationSort.best => byScore,
      RecommendationSort.near => (a, b) {
        final c = nullsLast<double>(a.distanceKm, b.distanceKm);
        return c != 0 ? c : byScore(a, b);
      },
      RecommendationSort.price => (a, b) {
        final c = nullsLast<int>(a.p.startingPriceVnd, b.p.startingPriceVnd);
        return c != 0 ? c : byScore(a, b);
      },
      RecommendationSort.rating => (a, b) {
        final c = smoothedRating(b.p).compareTo(smoothedRating(a.p));
        return c != 0 ? c : byScore(a, b);
      },
    });

    final start = math.min(_offset(q.cursor), scored.length);
    final limit = clampPageSize(q.limit);
    final slice = scored.skip(start).take(limit).toList();
    final hasMore = start + slice.length < scored.length;
    return RecommendationPage(
      items: [
        for (var i = 0; i < slice.length; i++)
          RecommendedPhotographer(
            photographer: slice[i].p,
            rank: start + i + 1,
            score: _unit(slice[i].score),
            distanceKm: slice[i].distanceKm,
            reasons: _reasons(
              slice[i].p,
              specialtyId: q.specialtyId,
              date: q.date,
              distanceKm: slice[i].distanceKm,
              day: slice[i].day,
              now: now,
            ),
          ),
      ],
      requestId: _requestId(),
      algorithm: algorithm,
      algorithmVersion: version,
      nextCursor: hasMore ? '${start + slice.length}' : null,
    );
  }

  @override
  Future<RecommendationPage> similar(String photographerId, {int limit = 8}) async {
    final now = _now();
    final target = (await _photographers.summaries([photographerId]))[photographerId];
    RecommendationPage empty() => RecommendationPage(
      items: const [],
      requestId: _requestId(),
      algorithm: algorithm,
      algorithmVersion: version,
    );
    if (target == null) {
      return empty();
    }
    final mine = target.specialtyIds.toSet();
    final scored = <(PhotographerSummary, double, double?, String)>[];
    for (final p in await _photographers.candidates(limit: candidatePool)) {
      if (p.id == photographerId) {
        continue;
      }
      final theirs = p.specialtyIds.toSet();
      final common = mine.intersection(theirs);
      if (common.isEmpty) {
        continue;
      }
      final jaccard = common.length / mine.union(theirs).length;
      final d = target.hasGeo && p.hasGeo
          ? haversineKm(target.lat!, target.lng!, p.lat!, p.lng!)
          : null;
      final closeness = d == null ? 0.5 : math.exp(-d / 8);
      scored.add((p, 0.6 * jaccard + 0.25 * closeness + 0.15 * _quality(p), d, common.first));
    }
    scored.sort((a, b) {
      final s = b.$2.compareTo(a.$2);
      return s != 0 ? s : a.$1.id.compareTo(b.$1.id);
    });
    final top = scored.take(clampPageSize(limit)).toList();
    return RecommendationPage(
      items: [
        for (var i = 0; i < top.length; i++)
          RecommendedPhotographer(
            photographer: top[i].$1,
            rank: i + 1,
            score: _unit(top[i].$2),
            distanceKm: top[i].$3,
            reasons: [
              Reason(
                code: ReasonCode.skillMatch,
                text: _l.reasonSkillMatch(specialtyLabel(top[i].$4).toLowerCase()),
              ),
              if (top[i].$3 != null && top[i].$3! <= 5)
                Reason(code: ReasonCode.near, text: _l.reasonNear(formatDistance(top[i].$3!))),
            ],
          ),
      ],
      requestId: _requestId(),
      algorithm: algorithm,
      algorithmVersion: version,
    );
  }

  @override
  Future<PostRecommendationPage> recommendPosts(PostRecommendationQuery q) async {
    final now = _now();
    final page = await _posts.feed(
      kind: PostKind.work,
      specialtyId: q.specialtyId,
      cursor: q.cursor,
      limit: q.limit,
    );
    final authors = await _photographers.summaries(page.posts.map((p) => p.photographerId));
    final known = [
      for (final post in page.posts)
        if (authors[post.photographerId] != null) post,
    ];
    final boosted = known.where((p) => _freeSoon(authors[p.photographerId]!, now, days: 14));
    final rest = known.where((p) => !_freeSoon(authors[p.photographerId]!, now, days: 14));
    final ordered = [...boosted, ...rest];
    final origin = _origin(q.geohash6);
    return PostRecommendationPage(
      items: [
        for (var i = 0; i < ordered.length; i++)
          () {
            final author = authors[ordered[i].photographerId]!;
            final d = _distance(origin, author);
            final reasons = <Reason>[
              if (_freeSoon(author, now, days: 14))
                Reason(
                  code: ReasonCode.freeOnDate,
                  text: _l.reasonFreeOnDate(formatDay(author.nextFreeDay!)),
                ),
              if (d != null && d <= 5)
                Reason(code: ReasonCode.near, text: _l.reasonNear(formatDistance(d))),
            ];
            return RecommendedPost(
              post: ordered[i],
              photographer: author,
              rank: i + 1,
              reasons: reasons,
            );
          }(),
      ],
      requestId: _requestId(),
      algorithm: algorithm,
      algorithmVersion: version,
      nextCursor: page.nextCursor,
    );
  }

  @override
  Future<void> sendFeedback(List<RecommendationSignal> signals) async {
    // Nothing is stored on the device; the remote implementation sends these
    // to the service.
  }
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter gen-l10n && flutter test test/data/recommendation && flutter analyze`
Expected: PASS (11 contract tests plus about 25 specific tests); analyze clean. The tests compute their 6-character cell with `encodeGeohash`, so no hash literal can drift.

- [ ] **Step 5: Commit**

```bash
git add lib/data/recommendation lib/l10n test/data/recommendation
git commit -m "feat(recommendation): LocalRecommender with reasons and the shared contract suite

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `ResilientRecommendationRepository`

**Files:**
- Create: `lib/data/recommendation/resilient_recommendation_repository.dart`, `test/data/recommendation/resilient_recommendation_repository_test.dart`

**Interfaces:**
- Produces: `class ResilientRecommendationRepository implements RecommendationRepository` with `ResilientRecommendationRepository({required RecommendationRepository primary, required RecommendationRepository fallback, Duration timeout = const Duration(milliseconds: 800)})`. Each of `recommendPhotographers`, `similar`, `recommendPosts` calls `primary` with the timeout; on any error or timeout it calls `fallback` and returns that page marked `usedFallback`. `sendFeedback` calls `primary` only, with the timeout, and swallows every failure.

This is what step 3r wires in: `Resilient(primary: RemoteRecommendationRepository(...), fallback: LocalRecommender(...))`. The 800 ms deadline is spec 3e.4.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/recommendation/resilient_recommendation_repository_test.dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/local_recommender.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/recommendation/resilient_recommendation_repository.dart';

import '../../support/content_fixtures.dart';
import 'recommendation_contract.dart';

enum _Mode { works, throws, hangs }

/// A stand-in for the remote recommender whose behaviour the test chooses.
class _Remote implements RecommendationRepository {
  _Mode mode = _Mode.works;
  int calls = 0;
  int feedbackCalls = 0;

  Future<T> _run<T>(T Function() ok) async {
    calls++;
    switch (mode) {
      case _Mode.works:
        return ok();
      case _Mode.throws:
        throw StateError('server down');
      case _Mode.hangs:
        return Completer<T>().future;
    }
  }

  @override
  Future<RecommendationPage> recommendPhotographers(RecommendationQuery query) =>
      _run(() => const RecommendationPage(items: [], requestId: 'remote', algorithm: 'rules-v1', algorithmVersion: '1.0.0'));

  @override
  Future<RecommendationPage> similar(String photographerId, {int limit = 8}) =>
      _run(() => const RecommendationPage(items: [], requestId: 'remote', algorithm: 'rules-v1', algorithmVersion: '1.0.0'));

  @override
  Future<PostRecommendationPage> recommendPosts(PostRecommendationQuery query) =>
      _run(() => const PostRecommendationPage(items: [], requestId: 'remote', algorithm: 'rules-v1', algorithmVersion: '1.0.0'));

  @override
  Future<void> sendFeedback(List<RecommendationSignal> signals) async {
    feedbackCalls++;
    if (mode == _Mode.throws) {
      throw StateError('server down');
    }
    if (mode == _Mode.hangs) {
      await Completer<void>().future;
    }
  }
}

LocalRecommender _local() => LocalRecommender(
  posts: FakePostRepository(contractWorld().posts),
  photographers: FakePhotographerRepository(contractWorld().photographers),
  availability: FakeAvailabilityLookup(),
  clock: () => fixtureNow,
);

void main() {
  // The wrapper with a dead primary must still satisfy the whole contract.
  recommendationRepositoryContract('resilient (primary down)', (world) async {
    final availability = FakeAvailabilityLookup();
    world.unavailable.forEach((id, days) {
      for (final d in days) {
        availability.set(id, d, DayAvailability.booked);
      }
    });
    return ResilientRecommendationRepository(
      primary: _Remote()..mode = _Mode.throws,
      fallback: LocalRecommender(
        posts: FakePostRepository(world.posts),
        photographers: FakePhotographerRepository(world.photographers),
        availability: availability,
        clock: () => fixtureNow,
      ),
    );
  });

  test('a working primary is used as is, not flagged', () async {
    final remote = _Remote();
    final repo = ResilientRecommendationRepository(primary: remote, fallback: _local());
    final page = await repo.recommendPhotographers(const RecommendationQuery());
    expect(page.requestId, 'remote');
    expect(page.usedFallback, isFalse);
    final posts = await repo.recommendPosts(const PostRecommendationQuery());
    expect(posts.requestId, 'remote');
    expect((await repo.similar('p1')).requestId, 'remote');
  });

  test('an error falls back to the local ranking and flags the page', () async {
    final remote = _Remote()..mode = _Mode.throws;
    final repo = ResilientRecommendationRepository(primary: remote, fallback: _local());
    final page = await repo.recommendPhotographers(const RecommendationQuery());
    expect(page.usedFallback, isTrue);
    expect(page.algorithm, 'local-fallback');
    expect(page.items, isNotEmpty);
    final posts = await repo.recommendPosts(const PostRecommendationQuery());
    expect(posts.usedFallback, isTrue);
    expect((await repo.similar('p1')).usedFallback, isTrue);
  });

  test('a primary slower than the deadline is abandoned', () async {
    final remote = _Remote()..mode = _Mode.hangs;
    final repo = ResilientRecommendationRepository(
      primary: remote,
      fallback: _local(),
      timeout: const Duration(milliseconds: 30),
    );
    final started = DateTime.now();
    final page = await repo.recommendPhotographers(const RecommendationQuery());
    expect(page.usedFallback, isTrue);
    expect(DateTime.now().difference(started), lessThan(const Duration(seconds: 2)));
    expect(remote.calls, 1, reason: 'no retry loop');
  });

  test('the default deadline is 800 ms', () {
    final repo = ResilientRecommendationRepository(primary: _Remote(), fallback: _local());
    expect(repo.timeout, const Duration(milliseconds: 800));
  });

  test('feedback never throws and never waits for a slow server', () async {
    final remote = _Remote()..mode = _Mode.throws;
    final repo = ResilientRecommendationRepository(
      primary: remote,
      fallback: _local(),
      timeout: const Duration(milliseconds: 30),
    );
    final signals = [
      RecommendationSignal(type: SignalType.click, requestId: 'r', photographerId: 'p1', at: fixtureNow),
    ];
    await repo.sendFeedback(signals);
    remote.mode = _Mode.hangs;
    await repo.sendFeedback(signals);
    expect(remote.feedbackCalls, 2, reason: 'one attempt each, no retry');
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/recommendation/resilient_recommendation_repository_test.dart`
Expected: FAIL, the wrapper does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/data/recommendation/resilient_recommendation_repository.dart
import 'package:photobooking/data/recommendation/recommendation_models.dart';

/// Asks [primary] (the remote recommender) with a deadline and falls back to
/// [fallback] (the on-device ranking) when it fails or is too slow, so Home
/// and Find always show something (spec 3e.4).
///
/// There is no retry: one attempt per request, so a dead server costs one
/// deadline of waiting and no background work.
class ResilientRecommendationRepository implements RecommendationRepository {
  ResilientRecommendationRepository({
    required this.primary,
    required this.fallback,
    this.timeout = const Duration(milliseconds: 800),
  });

  final RecommendationRepository primary;
  final RecommendationRepository fallback;
  final Duration timeout;

  @override
  Future<RecommendationPage> recommendPhotographers(
    RecommendationQuery query,
  ) async {
    try {
      return await primary.recommendPhotographers(query).timeout(timeout);
    } catch (_) {
      return (await fallback.recommendPhotographers(query)).markFallback();
    }
  }

  @override
  Future<RecommendationPage> similar(String photographerId, {int limit = 8}) async {
    try {
      return await primary.similar(photographerId, limit: limit).timeout(timeout);
    } catch (_) {
      return (await fallback.similar(photographerId, limit: limit)).markFallback();
    }
  }

  @override
  Future<PostRecommendationPage> recommendPosts(
    PostRecommendationQuery query,
  ) async {
    try {
      return await primary.recommendPosts(query).timeout(timeout);
    } catch (_) {
      return (await fallback.recommendPosts(query)).markFallback();
    }
  }

  @override
  Future<void> sendFeedback(List<RecommendationSignal> signals) async {
    try {
      await primary.sendFeedback(signals).timeout(timeout);
    } catch (_) {
      // Feedback is best effort; the next screen must not notice.
    }
  }
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/recommendation && flutter analyze`
Expected: PASS (11 contract tests for the wrapper plus 5); analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/data/recommendation test/data/recommendation
git commit -m "feat(recommendation): resilient wrapper with an 800 ms deadline and local fallback

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Providers

**Files:**
- Create: `lib/data/recommendation/recommendation_providers.dart`, `test/data/recommendation/recommendation_providers_test.dart`

**Interfaces:**
- Consumes: `postRepositoryProvider`, `photographerRepositoryProvider` (3b1), `clockProvider` (3a2).
- Produces: `availabilityLookupProvider` (`Provider<AvailabilityLookup>`, default `FirestoreAvailabilityLookup`), `localRecommenderProvider` (`Provider<LocalRecommender>`), `recommendationRepositoryProvider` (`Provider<RecommendationRepository>`, default = the local recommender). Step 3r overrides `recommendationRepositoryProvider` with `ResilientRecommendationRepository(primary: RemoteRecommendationRepository(...), fallback: ref.watch(localRecommenderProvider))` and nothing else changes.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/recommendation/recommendation_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/local_recommender.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';

import '../../support/content_fixtures.dart';

void main() {
  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        postRepositoryProvider.overrideWithValue(FakePostRepository([fixturePost('a')])),
        photographerRepositoryProvider.overrideWithValue(
          FakePhotographerRepository([fixturePhotographer('p1')]),
        ),
        availabilityLookupProvider.overrideWithValue(FakeAvailabilityLookup()),
        clockProvider.overrideWithValue(() => fixtureNow),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('the default recommender is the local one, built from the content ports', () async {
    final c = make();
    expect(c.read(recommendationRepositoryProvider), isA<LocalRecommender>());
    final page = await c.read(recommendationRepositoryProvider).recommendPhotographers(const RecommendationQuery());
    expect(page.items.single.photographer.id, 'p1');
    final posts = await c.read(recommendationRepositoryProvider).recommendPosts(const PostRecommendationQuery());
    expect(posts.items.single.post.id, 'a');
  });

  test('the repository is the same object as localRecommenderProvider until overridden', () {
    final c = make();
    expect(c.read(recommendationRepositoryProvider), same(c.read(localRecommenderProvider)));
  });

  test('step 3r can swap the implementation with one override', () async {
    final local = LocalRecommender(
      posts: FakePostRepository(),
      photographers: FakePhotographerRepository(),
      availability: FakeAvailabilityLookup(),
    );
    final c = ProviderContainer(
      overrides: [recommendationRepositoryProvider.overrideWithValue(local)],
    );
    addTearDown(c.dispose);
    expect(c.read(recommendationRepositoryProvider), same(local));
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/recommendation/recommendation_providers_test.dart`
Expected: FAIL, the providers file does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/data/recommendation/recommendation_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/firestore_availability_lookup.dart';
import 'package:photobooking/data/recommendation/local_recommender.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';

final availabilityLookupProvider = Provider<AvailabilityLookup>(
  (ref) => FirestoreAvailabilityLookup(),
);

/// The on-device ranking. Kept separate so the remote wiring in step 3r can use
/// it as the fallback.
final localRecommenderProvider = Provider<LocalRecommender>(
  (ref) => LocalRecommender(
    posts: ref.watch(postRepositoryProvider),
    photographers: ref.watch(photographerRepositoryProvider),
    availability: ref.watch(availabilityLookupProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// What screens use. Until the recommender service exists this is the local
/// ranking.
final recommendationRepositoryProvider = Provider<RecommendationRepository>(
  (ref) => ref.watch(localRecommenderProvider),
);
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/recommendation && flutter analyze && flutter test`
Expected: PASS; analyze clean; the whole suite is green.

- [ ] **Step 5: Commit**

```bash
git add lib/data/recommendation test/data/recommendation
git commit -m "feat(recommendation): providers, local recommender as the default

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Battery and performance check (moved)

Moved to `docs/superpowers/plans/2026-10-02-final-battery-performance.md` (section "2026-10-01-step3b3-recommendations.md"). Nothing to do here.
