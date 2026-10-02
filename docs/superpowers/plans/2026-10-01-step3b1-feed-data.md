# Step 3b1: Feed Read Models, Repositories and Firestore Adapters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The data the discovery screens read: `PhotographerSummary`, `PostSummary`, `ServiceSummary` and `Reason` read models; ports for posts, likes/saves/follows, photographers and services; in-memory fakes; Firestore adapters; Firestore rules and indexes for reading posts and for the viewer's own likes, saves and follows. All of it is covered by one contract test per port that runs against both the fake and the Firestore adapter.

**Architecture:** Plain immutable Dart classes in `lib/data/content/` (no Firebase types). Ports are abstract classes; `fake_content_repositories.dart` has the fakes; `firestore_*.dart` are the only files that import `cloud_firestore`. Reads are one-shot `get()` calls with a hard page size (no `snapshots()` listeners), so no screen can leave a listener open. Pagination uses the id of the last document as the cursor. The viewer's likes, saves and follows are documents named `{uid}_{targetId}`; counters are written by Cloud Functions, never by the client.

**Tech Stack:** Flutter, Riverpod 3, `cloud_firestore`, `fake_cloud_firestore` (dev), Firestore rules + `@firebase/rules-unit-testing`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3e.9, §5 (S01, S02, S04), §7; `docs/superpowers/specs/screens/discovery.md`; `docs/superpowers/specs/data-model/README.md` (ids, UTC instants, integer VND, string enum codes, no Firebase types in the domain), `domain-model.md` (`Post`, `Photographer`, `Service`, `Like`, `Save`, `Follow`), `relational-schema.md` §2.3; the Firestore layout in `docs/superpowers/specs/2026-09-30-photography-marketplace-design.md` §5.

**Prerequisite:** plans `2026-10-01-step3a1-location-foundations.md` (geo and Vietnam-time helpers in `core.dart`) and `2026-10-01-step3a2-explore-screens.md` are done. The screen-codes and core-display-widgets plans are done (the `test/core/widgets/widget_host.dart` helper is not used here).

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Run `dart format lib test` before each commit (`require_trailing_commas` is a lint and `flutter analyze` fails on infos).
- Imports are `package:photobooking/...` only; `data/` imports `package:photobooking/core/core.dart`, never files inside `core/`.
- **Firebase isolation:** `cloud_firestore` may be imported only by `lib/data/content/firestore_post_repository.dart` and `lib/data/content/firestore_photographer_repository.dart` (and `content_providers.dart`, which only names the adapter classes). Read models, ports and fakes import no Firebase package.
- Data conventions (`data-model/README.md`): ids are opaque strings; instants are UTC `DateTime`s; money is an `int` of VND; enums are string codes; a calendar day is a `yyyy-MM-dd` string in Vietnam time (`vnDateKey`).
- No client write may touch counters or verification: `likeCount`, `saveCount`, `followerCount`, `stats.*`, `verified` are server-owned; rules in Task 5 enforce it.
- Reads are bounded: every list query has a `limit` and page size is clamped to 50; there are no `snapshots()` listeners in this plan.
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/data/content/reason.dart` (create) | `ReasonCode`, `Reason` |
| `lib/data/content/photographer_summary.dart` (create) | `PhotographerSummary` |
| `lib/data/content/post_summary.dart` (create) | `PostKind`, `PostImage`, `PostSummary`, `PostPage` |
| `lib/data/content/service_summary.dart` (create) | `ServiceSummary` |
| `lib/data/content/content_repositories.dart` (create) | ports `PostRepository`, `PostEngagementRepository`, `PhotographerRepository`, `ServiceRepository`, value `PostEngagement` |
| `lib/data/content/fake_content_repositories.dart` (create) | the four fakes |
| `lib/data/content/firestore_post_repository.dart` (create) | `postFromFirestore`, `FirestorePostRepository`, `FirestoreEngagementRepository` |
| `lib/data/content/firestore_photographer_repository.dart` (create) | `photographerSummaryFrom`, `serviceFromFirestore`, `FirestorePhotographerRepository`, `FirestoreServiceRepository` |
| `lib/data/content/content_providers.dart` (create) | the four repository providers |
| `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs`, `firebase/firestore.indexes.json` (modify) | posts read, likes/saves/follows, indexes |
| `pubspec.yaml` (modify) | `fake_cloud_firestore` (dev) |
| `test/support/content_fixtures.dart` (create) | `fixturePost`, `fixturePhotographer`, `fixtureService`, `fixtureNow` |
| `test/data/content/content_contracts.dart` (create) | shared contract tests |
| `test/data/content/*_test.dart`, `test/battery/feed_data_battery_test.dart` | tests |

---

### Task 1: Read models and test fixtures

**Files:**
- Create: `lib/data/content/reason.dart`, `lib/data/content/photographer_summary.dart`, `lib/data/content/post_summary.dart`, `lib/data/content/service_summary.dart`, `test/support/content_fixtures.dart`, `test/data/content/content_models_test.dart`

**Interfaces:**
- Produces:
  - `enum ReasonCode { skillMatch, near, freeOnDate, topRated, fastReply, newTalent }` with `String get code` (`skill_match`, `near`, `free_on_date`, `top_rated`, `fast_reply`, `new_talent`) and `static ReasonCode? fromCode(String? code)`; `class Reason { const Reason({required ReasonCode code, required String text}); }` with value equality.
  - `class PhotographerSummary` — `const PhotographerSummary({required String id, required String displayName, String? avatarUrl, String? coverUrl, bool verified = false, List<String> specialtyIds = const [], List<String> styleIds = const [], String? areaLabel, double? lat, double? lng, double ratingAvg = 0, int reviewCount = 0, int completedCount = 0, int? responseMinutes, int? startingPriceVnd, String? nextFreeDate, DateTime? createdAt})`; getters `hasRating`, `hasGeo`, `heroUrl` (cover, else avatar), `nextFreeDay` (`DateTime?`, UTC midnight of `nextFreeDate`).
  - `enum PostKind { work, realShoot, eventShare }` (`code`: `work`, `real_shoot`, `event_share`; `fromCode` unknown → `work`); `class PostImage { const PostImage({required String url, String? blurHash, int? width, int? height}); }`; `class PostSummary` — `const PostSummary({required String id, required PostKind kind, required String authorId, required String photographerId, required String serviceId, String? bookingId, required List<PostImage> images, String caption = '', String? locationName, String? styleId, String? specialtyId, List<String> hashtags = const [], bool inPortfolio = false, int likeCount = 0, int saveCount = 0, required DateTime createdAt})` with getter `cover`; `class PostPage { const PostPage({List<PostSummary> posts = const [], String? nextCursor}); }`.
  - `class ServiceSummary` — `const ServiceSummary({required String id, required String photographerId, required String name, String? specialtyId, required int priceVnd, required int durationMinutes, int? photoCount, int? editedCount, int? deliveryDays, String? coverUrl, bool active = true})`.
  - Test fixtures: `fixtureNow` (`2026-10-01T05:00Z`), `fixturePost(id, {…})`, `fixturePhotographer(id, {…})`, `fixtureService(id, {…})`.

`specialtyId` on a post is denormalised at publish time from the chosen service (plan 3c) so the Home category chips can filter the feed with one indexed query.

- [ ] **Step 1: Write the failing test and fixtures**

```dart
// test/support/content_fixtures.dart
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';

/// Thursday 1 Oct 2026, 12:00 in Vietnam.
final fixtureNow = DateTime.utc(2026, 10, 1, 5);

PostSummary fixturePost(
  String id, {
  PostKind kind = PostKind.work,
  String photographerId = 'p1',
  String? authorId,
  String serviceId = 's1',
  String caption = 'Chiều muộn ở bến Bạch Đằng #chandung',
  Duration age = const Duration(hours: 1),
  String? specialtyId,
  String? styleId,
  String? locationName = 'Bến Bạch Đằng',
  int likes = 0,
  int saves = 0,
  int images = 1,
  bool inPortfolio = true,
  List<String> hashtags = const ['chandung'],
}) => PostSummary(
  id: id,
  kind: kind,
  authorId: authorId ?? photographerId,
  photographerId: photographerId,
  serviceId: serviceId,
  images: [
    for (var i = 0; i < images; i++)
      PostImage(
        url: 'https://img.test/$id-$i.jpg',
        blurHash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
        width: 1200,
        height: 1600,
      ),
  ],
  caption: caption,
  locationName: locationName,
  styleId: styleId,
  specialtyId: specialtyId,
  hashtags: hashtags,
  inPortfolio: inPortfolio,
  likeCount: likes,
  saveCount: saves,
  createdAt: fixtureNow.subtract(age),
);

PhotographerSummary fixturePhotographer(
  String id, {
  String name = 'Minh Trí',
  bool verified = false,
  List<String> specialties = const ['portrait'],
  List<String> styles = const [],
  double rating = 4.9,
  int reviews = 58,
  int completed = 112,
  int? startingPrice = 1500000,
  String? nextFreeDate,
  double? lat = 10.7769,
  double? lng = 106.7009,
  int? responseMinutes = 60,
  Duration createdAgo = const Duration(days: 200),
  String? areaLabel = 'Quận 1',
  String? avatarUrl,
  String? coverUrl,
}) => PhotographerSummary(
  id: id,
  displayName: name,
  avatarUrl: avatarUrl ?? 'https://img.test/avatar-$id.jpg',
  coverUrl: coverUrl,
  verified: verified,
  specialtyIds: specialties,
  styleIds: styles,
  areaLabel: areaLabel,
  lat: lat,
  lng: lng,
  ratingAvg: rating,
  reviewCount: reviews,
  completedCount: completed,
  responseMinutes: responseMinutes,
  startingPriceVnd: startingPrice,
  nextFreeDate: nextFreeDate,
  createdAt: fixtureNow.subtract(createdAgo),
);

ServiceSummary fixtureService(
  String id, {
  String photographerId = 'p1',
  String name = 'Chân dung 2 giờ',
  int price = 1500000,
  String? specialtyId = 'portrait',
  int durationMinutes = 120,
  bool active = true,
}) => ServiceSummary(
  id: id,
  photographerId: photographerId,
  name: name,
  specialtyId: specialtyId,
  priceVnd: price,
  durationMinutes: durationMinutes,
  photoCount: 40,
  editedCount: 40,
  deliveryDays: 5,
  active: active,
);
```

```dart
// test/data/content/content_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/reason.dart';

import '../../support/content_fixtures.dart';

void main() {
  group('Reason', () {
    test('codes round-trip and unknown codes are null', () {
      for (final c in ReasonCode.values) {
        expect(ReasonCode.fromCode(c.code), c);
      }
      expect(ReasonCode.skillMatch.code, 'skill_match');
      expect(ReasonCode.freeOnDate.code, 'free_on_date');
      expect(ReasonCode.fromCode('???'), isNull);
      expect(ReasonCode.fromCode(null), isNull);
    });

    test('has value equality', () {
      expect(
        const Reason(code: ReasonCode.near, text: '1,2 km'),
        const Reason(code: ReasonCode.near, text: '1,2 km'),
      );
      expect(
        const Reason(code: ReasonCode.near, text: '1,2 km'),
        isNot(const Reason(code: ReasonCode.near, text: '2 km')),
      );
    });
  });

  group('PhotographerSummary', () {
    test('rating, geo, hero and next free day', () {
      final p = fixturePhotographer('p1', nextFreeDate: '2026-10-03');
      expect(p.hasRating, isTrue);
      expect(p.hasGeo, isTrue);
      expect(p.heroUrl, p.avatarUrl, reason: 'no cover: the avatar stands in');
      expect(p.nextFreeDay, DateTime.utc(2026, 10, 3));
    });

    test('a new photographer has no rating, no geo and no free day', () {
      const p = PhotographerSummary(id: 'p9', displayName: 'Mới');
      expect(p.hasRating, isFalse);
      expect(p.hasGeo, isFalse);
      expect(p.heroUrl, isNull);
      expect(p.nextFreeDay, isNull);
    });

    test('a cover wins over the avatar; a malformed day is ignored', () {
      final p = fixturePhotographer('p1', coverUrl: 'https://img.test/c.jpg', nextFreeDate: '12/10');
      expect(p.heroUrl, 'https://img.test/c.jpg');
      expect(p.nextFreeDay, isNull);
    });
  });

  group('PostSummary', () {
    test('kind codes round-trip; unknown becomes work', () {
      expect(PostKind.fromCode('real_shoot'), PostKind.realShoot);
      expect(PostKind.fromCode('event_share'), PostKind.eventShare);
      expect(PostKind.realShoot.code, 'real_shoot');
      expect(PostKind.fromCode('???'), PostKind.work);
      expect(PostKind.fromCode(null), PostKind.work);
    });

    test('the cover is the first image', () {
      final p = fixturePost('a', images: 3);
      expect(p.images, hasLength(3));
      expect(p.cover.url, 'https://img.test/a-0.jpg');
    });

    test('an empty page has no cursor', () {
      const page = PostPage();
      expect(page.posts, isEmpty);
      expect(page.nextCursor, isNull);
    });
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/content/content_models_test.dart`
Expected: FAIL, the model libraries do not exist.

- [ ] **Step 3: Implement**

```dart
// lib/data/content/reason.dart

/// Why a photographer or post is recommended (spec 3e.1, "giải thích được").
enum ReasonCode {
  skillMatch('skill_match'),
  near('near'),
  freeOnDate('free_on_date'),
  topRated('top_rated'),
  fastReply('fast_reply'),
  newTalent('new_talent');

  const ReasonCode(this.code);
  final String code;

  static ReasonCode? fromCode(String? code) {
    for (final c in values) {
      if (c.code == code) {
        return c;
      }
    }
    return null;
  }
}

class Reason {
  const Reason({required this.code, required this.text});
  final ReasonCode code;

  /// Short Vietnamese sentence, ready to show.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is Reason && other.code == code && other.text == text;

  @override
  int get hashCode => Object.hash(code, text);
}
```

```dart
// lib/data/content/photographer_summary.dart
import 'package:photobooking/core/core.dart';

/// What a card or a ranking needs to know about a photographer. Built from the
/// public `users/{uid}` and `photographers/{uid}` documents.
class PhotographerSummary {
  const PhotographerSummary({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.coverUrl,
    this.verified = false,
    this.specialtyIds = const [],
    this.styleIds = const [],
    this.areaLabel,
    this.lat,
    this.lng,
    this.ratingAvg = 0,
    this.reviewCount = 0,
    this.completedCount = 0,
    this.responseMinutes,
    this.startingPriceVnd,
    this.nextFreeDate,
    this.createdAt,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? coverUrl;
  final bool verified;

  /// Taxonomy codes (`portrait`, `wedding`, ...), strongest first.
  final List<String> specialtyIds;

  /// Style codes (`natural_light`, `film`, ...).
  final List<String> styleIds;

  /// City or district shown on cards, e.g. "Quận 1".
  final String? areaLabel;

  /// Centre of the service area; null when the photographer has not set one.
  final double? lat;
  final double? lng;
  final double ratingAvg;
  final int reviewCount;
  final int completedCount;

  /// Median reply time in minutes, when known.
  final int? responseMinutes;

  /// Integer VND, the cheapest active service.
  final int? startingPriceVnd;

  /// First free day as `yyyy-MM-dd` (Vietnam calendar day), computed by the
  /// server into `stats.nextFreeDate`.
  final String? nextFreeDate;
  final DateTime? createdAt;

  bool get hasRating => reviewCount > 0;
  bool get hasGeo => lat != null && lng != null;
  String? get heroUrl => coverUrl ?? avatarUrl;
  DateTime? get nextFreeDay =>
      nextFreeDate == null ? null : parseDayKey(nextFreeDate!);
}
```

```dart
// lib/data/content/post_summary.dart

enum PostKind {
  work('work'),
  realShoot('real_shoot'),
  eventShare('event_share');

  const PostKind(this.code);
  final String code;

  static PostKind fromCode(String? code) => values.firstWhere(
    (k) => k.code == code,
    orElse: () => PostKind.work,
  );
}

class PostImage {
  const PostImage({required this.url, this.blurHash, this.width, this.height});
  final String url;

  /// Placeholder hash stored with the post; decoding it is a later
  /// enhancement of `PhotoCard`.
  final String? blurHash;
  final int? width;
  final int? height;
}

class PostSummary {
  const PostSummary({
    required this.id,
    required this.kind,
    required this.authorId,
    required this.photographerId,
    required this.serviceId,
    this.bookingId,
    required this.images,
    this.caption = '',
    this.locationName,
    this.styleId,
    this.specialtyId,
    this.hashtags = const [],
    this.inPortfolio = false,
    this.likeCount = 0,
    this.saveCount = 0,
    required this.createdAt,
  });

  final String id;
  final PostKind kind;

  /// The photographer for `work` posts, the customer for `real_shoot`.
  final String authorId;
  final String photographerId;
  final String serviceId;
  final String? bookingId;
  final List<PostImage> images;
  final String caption;
  final String? locationName;
  final String? styleId;

  /// Specialty of the service this post is tagged with.
  final String? specialtyId;

  /// Lower-case tags without `#`, extracted from the caption.
  final List<String> hashtags;
  final bool inPortfolio;
  final int likeCount;
  final int saveCount;
  final DateTime createdAt;

  PostImage get cover => images.first;
}

class PostPage {
  const PostPage({this.posts = const [], this.nextCursor});
  final List<PostSummary> posts;

  /// Pass it back to load the next page; null on the last page.
  final String? nextCursor;
}
```

```dart
// lib/data/content/service_summary.dart

/// A bookable package (`photographers/{uid}/services/{id}`).
class ServiceSummary {
  const ServiceSummary({
    required this.id,
    required this.photographerId,
    required this.name,
    this.specialtyId,
    required this.priceVnd,
    required this.durationMinutes,
    this.photoCount,
    this.editedCount,
    this.deliveryDays,
    this.coverUrl,
    this.active = true,
  });

  final String id;
  final String photographerId;
  final String name;
  final String? specialtyId;

  /// Integer VND, always greater than zero.
  final int priceVnd;
  final int durationMinutes;
  final int? photoCount;
  final int? editedCount;
  final int? deliveryDays;
  final String? coverUrl;
  final bool active;
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/content/content_models_test.dart && flutter analyze`
Expected: PASS (8 tests); analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/data/content test/support test/data/content
git commit -m "feat(data): feed read models and test fixtures

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Ports and in-memory fakes, with the shared contract

**Files:**
- Create: `lib/data/content/content_repositories.dart`, `lib/data/content/fake_content_repositories.dart`, `test/data/content/content_contracts.dart`, `test/data/content/fake_content_repositories_test.dart`

**Interfaces:**
- Produces (`content_repositories.dart`):
  - `abstract class PostRepository { Future<PostPage> feed({PostKind? kind, String? specialtyId, String? cursor, int limit = 20}); Future<PostPage> byPhotographer(String photographerId, {String? cursor, int limit = 20}); Future<PostSummary?> byId(String postId); }` — newest first; `limit` is clamped to 1–50; `nextCursor` is non-null exactly when more posts exist.
  - `class PostEngagement { const PostEngagement({bool liked = false, bool saved = false}); }`
  - `abstract class PostEngagementRepository { Future<PostEngagement> engagementFor(String uid, String postId); Future<Set<String>> savedAmong(String uid, Iterable<String> postIds); Future<void> setLiked(String uid, String postId, bool liked); Future<void> setSaved(String uid, String postId, bool saved); Future<bool> isFollowing(String uid, String photographerId); Future<void> setFollowing(String uid, String photographerId, bool following); }` — setters are idempotent.
  - `abstract class PhotographerRepository { Future<Map<String, PhotographerSummary>> summaries(Iterable<String> ids); Future<List<PhotographerSummary>> freeThisWeek({required DateTime now, int limit = 12}); Future<List<PhotographerSummary>> candidates({int limit = 200}); }` — `freeThisWeek` returns photographers whose `nextFreeDate` is in `[today, today + 7 days)` (Vietnam days), soonest first then best rated.
  - `abstract class ServiceRepository { Future<ServiceSummary?> byId(String photographerId, String serviceId); Future<List<ServiceSummary>> activeFor(String photographerId); }`
- Produces (`fake_content_repositories.dart`): `FakePostRepository([List<PostSummary>])` with `add(PostSummary)` and `Object? failWith`; `FakePostEngagementRepository` with `Object? failWith`, `int writeCalls`, `int readCalls`; `FakePhotographerRepository([List<PhotographerSummary>])` with `failWith`; `FakeServiceRepository([List<ServiceSummary>])` with `add`, `failWith`. All `failWith` fields make every call throw it.
- Produces (`content_contracts.dart`): `postRepositoryContract`, `engagementContract`, `photographerRepositoryContract`, `serviceRepositoryContract` — each takes `(String name, Future<Port> Function(seed) create)` and registers a `group` of tests. Task 3 and 4 run the same functions against the Firestore adapters.

- [ ] **Step 1: Write the contract and the failing fake test**

```dart
// test/data/content/content_contracts.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';

import '../../support/content_fixtures.dart';

List<PostSummary> contractPosts() => [
  fixturePost('a', age: const Duration(hours: 1), likes: 3, images: 2),
  fixturePost('b', age: const Duration(hours: 2), specialtyId: 'wedding'),
  fixturePost('c', age: const Duration(hours: 3), kind: PostKind.realShoot, authorId: 'u9'),
  fixturePost('d', age: const Duration(hours: 4), photographerId: 'p2'),
  fixturePost('e', age: const Duration(hours: 5)),
];

typedef PostRepoFactory = Future<PostRepository> Function(List<PostSummary> seed);

void postRepositoryContract(String name, PostRepoFactory create) {
  group('PostRepository contract: $name', () {
    List<String> ids(PostPage p) => p.posts.map((e) => e.id).toList();

    test('feed is newest first', () async {
      final repo = await create(contractPosts());
      expect(ids(await repo.feed()), ['a', 'b', 'c', 'd', 'e']);
    });

    test('pages are disjoint, complete, and the last one has no cursor', () async {
      final repo = await create(contractPosts());
      final p1 = await repo.feed(limit: 2);
      expect(ids(p1), ['a', 'b']);
      expect(p1.nextCursor, isNotNull);
      final p2 = await repo.feed(limit: 2, cursor: p1.nextCursor);
      expect(ids(p2), ['c', 'd']);
      final p3 = await repo.feed(limit: 2, cursor: p2.nextCursor);
      expect(ids(p3), ['e']);
      expect(p3.nextCursor, isNull);
    });

    test('an exactly full last page has no cursor either', () async {
      final repo = await create(contractPosts());
      final all = await repo.feed(limit: 5);
      expect(ids(all), ['a', 'b', 'c', 'd', 'e']);
      expect(all.nextCursor, isNull);
    });

    test('filters by kind and by specialty', () async {
      final repo = await create(contractPosts());
      expect(ids(await repo.feed(kind: PostKind.realShoot)), ['c']);
      expect(ids(await repo.feed(specialtyId: 'wedding')), ['b']);
      expect(ids(await repo.feed(kind: PostKind.realShoot, specialtyId: 'wedding')), isEmpty);
    });

    test('byPhotographer lists that photographer only, newest first', () async {
      final repo = await create(contractPosts());
      expect(ids(await repo.byPhotographer('p2')), ['d']);
      expect(ids(await repo.byPhotographer('p1')), ['a', 'b', 'c', 'e']);
      expect(ids(await repo.byPhotographer('nobody')), isEmpty);
    });

    test('byId finds a post with its images and counters, or null', () async {
      final repo = await create(contractPosts());
      final a = (await repo.byId('a'))!;
      expect(a.images, hasLength(2));
      expect(a.images.first.url, 'https://img.test/a-0.jpg');
      expect(a.images.first.blurHash, isNotNull);
      expect(a.likeCount, 3);
      expect(a.kind, PostKind.work);
      expect(a.createdAt, fixtureNow.subtract(const Duration(hours: 1)));
      expect(await repo.byId('missing'), isNull);
    });

    test('a page size over 50 is clamped', () async {
      final many = [
        for (var i = 0; i < 60; i++)
          fixturePost('m$i', age: Duration(minutes: i + 1)),
      ];
      final repo = await create(many);
      final page = await repo.feed(limit: 1000);
      expect(page.posts, hasLength(50));
      expect(page.nextCursor, isNotNull);
    });
  });
}

void engagementContract(String name, Future<PostEngagementRepository> Function() create) {
  group('PostEngagementRepository contract: $name', () {
    test('starts empty; like and save are independent and reversible', () async {
      final repo = await create();
      expect((await repo.engagementFor('u1', 'a')).liked, isFalse);
      await repo.setLiked('u1', 'a', true);
      var e = await repo.engagementFor('u1', 'a');
      expect((e.liked, e.saved), (true, false));
      await repo.setSaved('u1', 'a', true);
      e = await repo.engagementFor('u1', 'a');
      expect((e.liked, e.saved), (true, true));
      await repo.setLiked('u1', 'a', false);
      e = await repo.engagementFor('u1', 'a');
      expect((e.liked, e.saved), (false, true));
    });

    test('setters are idempotent', () async {
      final repo = await create();
      await repo.setLiked('u1', 'a', true);
      await repo.setLiked('u1', 'a', true);
      await repo.setLiked('u1', 'a', false);
      await repo.setLiked('u1', 'a', false);
      expect((await repo.engagementFor('u1', 'a')).liked, isFalse);
    });

    test('savedAmong returns only the saved ones among those asked', () async {
      final repo = await create();
      await repo.setSaved('u1', 'a', true);
      await repo.setSaved('u1', 'c', true);
      await repo.setSaved('u2', 'b', true);
      expect(await repo.savedAmong('u1', ['a', 'b', 'c']), {'a', 'c'});
      expect(await repo.savedAmong('u1', const []), isEmpty);
    });

    test('users do not see each other\'s likes', () async {
      final repo = await create();
      await repo.setLiked('u1', 'a', true);
      expect((await repo.engagementFor('u2', 'a')).liked, isFalse);
    });

    test('follow and unfollow', () async {
      final repo = await create();
      expect(await repo.isFollowing('u1', 'p1'), isFalse);
      await repo.setFollowing('u1', 'p1', true);
      expect(await repo.isFollowing('u1', 'p1'), isTrue);
      expect(await repo.isFollowing('u2', 'p1'), isFalse);
      await repo.setFollowing('u1', 'p1', false);
      expect(await repo.isFollowing('u1', 'p1'), isFalse);
    });
  });
}

List<PhotographerSummary> contractPhotographers() => [
  fixturePhotographer('p1', name: 'Minh Trí', verified: true, nextFreeDate: '2026-10-03', rating: 4.9, startingPrice: 1500000, styles: const ['natural_light', 'film']),
  fixturePhotographer('p2', name: 'Hồng Nhung', nextFreeDate: '2026-10-01', rating: 4.5),
  fixturePhotographer('p3', name: 'Quốc Bảo', nextFreeDate: '2026-10-03', rating: 4.95),
  fixturePhotographer('p4', name: 'Thu Hà', nextFreeDate: '2026-10-08'),
  fixturePhotographer('p5', name: 'Gia Bảo', nextFreeDate: '2026-09-30'),
  fixturePhotographer('p6', name: 'Bích Ngọc'),
];

typedef PhotographerRepoFactory = Future<PhotographerRepository> Function(List<PhotographerSummary> seed);

void photographerRepositoryContract(String name, PhotographerRepoFactory create) {
  group('PhotographerRepository contract: $name', () {
    test('summaries returns the asked ids that exist, with their fields', () async {
      final repo = await create(contractPhotographers());
      final m = await repo.summaries(['p1', 'p4', 'ghost']);
      expect(m.keys.toSet(), {'p1', 'p4'});
      final p1 = m['p1']!;
      expect(p1.displayName, 'Minh Trí');
      expect(p1.verified, isTrue);
      expect(p1.specialtyIds, ['portrait']);
      expect(p1.styleIds, ['natural_light', 'film']);
      expect(p1.ratingAvg, 4.9);
      expect(p1.reviewCount, 58);
      expect(p1.completedCount, 112);
      expect(p1.startingPriceVnd, 1500000);
      expect(p1.nextFreeDate, '2026-10-03');
      expect(p1.areaLabel, 'Quận 1');
      expect(p1.lat, closeTo(10.7769, 1e-6));
      expect(p1.lng, closeTo(106.7009, 1e-6));
      expect(await repo.summaries(const []), isEmpty);
    });

    test('freeThisWeek is the Vietnamese day window [today, today + 7), soonest then best rated', () async {
      final repo = await create(contractPhotographers());
      final free = await repo.freeThisWeek(now: fixtureNow);
      expect(free.map((p) => p.id), ['p2', 'p3', 'p1']);
    });

    test('freeThisWeek honours the limit', () async {
      final repo = await create(contractPhotographers());
      expect(await repo.freeThisWeek(now: fixtureNow, limit: 1), hasLength(1));
    });

    test('candidates honours the limit', () async {
      final repo = await create(contractPhotographers());
      expect(await repo.candidates(limit: 3), hasLength(3));
      expect((await repo.candidates()).length, 6);
    });
  });
}

typedef ServiceRepoFactory = Future<ServiceRepository> Function(List<ServiceSummary> seed);

List<ServiceSummary> contractServices() => [
  fixtureService('s1'),
  fixtureService('s2', name: 'Cặp đôi nửa ngày', price: 3200000, specialtyId: 'couple'),
  fixtureService('s3', name: 'Gói cũ', active: false),
  fixtureService('t1', photographerId: 'p2', name: 'Cưới cả ngày', price: 8000000, specialtyId: 'wedding'),
];

void serviceRepositoryContract(String name, ServiceRepoFactory create) {
  group('ServiceRepository contract: $name', () {
    test('byId finds one service with its details, only under its photographer', () async {
      final repo = await create(contractServices());
      final s = (await repo.byId('p1', 's2'))!;
      expect(s.name, 'Cặp đôi nửa ngày');
      expect(s.priceVnd, 3200000);
      expect(s.specialtyId, 'couple');
      expect(s.durationMinutes, 120);
      expect(s.photoCount, 40);
      expect(s.deliveryDays, 5);
      expect(s.active, isTrue);
      expect(await repo.byId('p2', 's2'), isNull);
      expect(await repo.byId('p1', 'nope'), isNull);
    });

    test('an inactive service can still be found by id but is not listed', () async {
      final repo = await create(contractServices());
      expect((await repo.byId('p1', 's3'))!.active, isFalse);
      final listed = await repo.activeFor('p1');
      expect(listed.map((s) => s.id).toSet(), {'s1', 's2'});
    });
  });
}
```

```dart
// test/data/content/fake_content_repositories_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';

import 'content_contracts.dart';

void main() {
  postRepositoryContract('fake', (seed) async => FakePostRepository(seed));
  engagementContract('fake', () async => FakePostEngagementRepository());
  photographerRepositoryContract('fake', (seed) async => FakePhotographerRepository(seed));
  serviceRepositoryContract('fake', (seed) async => FakeServiceRepository(seed));

  test('failWith makes every call throw, for testing error states', () async {
    final posts = FakePostRepository()..failWith = StateError('offline');
    expect(() => posts.feed(), throwsStateError);
    expect(() => posts.byId('a'), throwsStateError);
    final eng = FakePostEngagementRepository()..failWith = StateError('offline');
    expect(() => eng.setLiked('u', 'a', true), throwsStateError);
    expect(eng.writeCalls, 0);
    final ph = FakePhotographerRepository()..failWith = StateError('offline');
    expect(() => ph.candidates(), throwsStateError);
    final sv = FakeServiceRepository()..failWith = StateError('offline');
    expect(() => sv.activeFor('p1'), throwsStateError);
  });

  test('add makes a new post show at the top of the feed', () async {
    final posts = FakePostRepository(contractPosts());
    posts.add(fixturePostNewest());
    expect((await posts.feed()).posts.first.id, 'new');
  });

  test('reads are counted too', () async {
    final eng = FakePostEngagementRepository();
    await eng.engagementFor('u', 'a');
    await eng.savedAmong('u', ['a', 'b']);
    await eng.isFollowing('u', 'p1');
    expect(eng.readCalls, 3);
  });

  test('writes are counted so tests can assert optimistic behaviour', () async {
    final eng = FakePostEngagementRepository();
    await eng.setLiked('u', 'a', true);
    await eng.setSaved('u', 'a', true);
    await eng.setFollowing('u', 'p1', true);
    expect(eng.writeCalls, 3);
  });
}
```

Add to `test/data/content/content_contracts.dart` (bottom) the helper used above:

```dart
PostSummary fixturePostNewest() =>
    fixturePost('new', age: const Duration(seconds: 1));
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/content/fake_content_repositories_test.dart`
Expected: FAIL, the port and fake libraries do not exist.

- [ ] **Step 3: Implement**

```dart
// lib/data/content/content_repositories.dart
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';

/// Page sizes are clamped to this by every implementation.
const kMaxPageSize = 50;

/// [limit] forced into `1..max` (an `int`, unlike `num.clamp`).
int clampPageSize(int limit, [int max = kMaxPageSize]) =>
    limit < 1 ? 1 : (limit > max ? max : limit);

abstract class PostRepository {
  /// Newest first. [limit] is clamped to 1..[kMaxPageSize].
  Future<PostPage> feed({
    PostKind? kind,
    String? specialtyId,
    String? cursor,
    int limit = 20,
  });

  Future<PostPage> byPhotographer(
    String photographerId, {
    String? cursor,
    int limit = 20,
  });

  /// Null when the post does not exist or was removed.
  Future<PostSummary?> byId(String postId);
}

class PostEngagement {
  const PostEngagement({this.liked = false, this.saved = false});
  final bool liked;
  final bool saved;
}

/// The viewer's own likes, saves and follows. Counters on posts are written
/// by the server; the client only writes these marker documents.
abstract class PostEngagementRepository {
  Future<PostEngagement> engagementFor(String uid, String postId);
  Future<Set<String>> savedAmong(String uid, Iterable<String> postIds);
  Future<void> setLiked(String uid, String postId, bool liked);
  Future<void> setSaved(String uid, String postId, bool saved);
  Future<bool> isFollowing(String uid, String photographerId);
  Future<void> setFollowing(String uid, String photographerId, bool following);
}

abstract class PhotographerRepository {
  /// Photographers by id; unknown ids are absent from the result.
  Future<Map<String, PhotographerSummary>> summaries(Iterable<String> ids);

  /// Photographers whose next free day lies in `[today, today + 7 days)`
  /// (Vietnam calendar days), soonest first, then best rated.
  Future<List<PhotographerSummary>> freeThisWeek({
    required DateTime now,
    int limit = 12,
  });

  /// Published photographers, for ranking on the device when the recommender
  /// service is not available.
  Future<List<PhotographerSummary>> candidates({int limit = 200});
}

abstract class ServiceRepository {
  Future<ServiceSummary?> byId(String photographerId, String serviceId);
  Future<List<ServiceSummary>> activeFor(String photographerId);
}
```

```dart
// lib/data/content/fake_content_repositories.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';

class FakePostRepository implements PostRepository {
  FakePostRepository([List<PostSummary> posts = const []])
    : _posts = List.of(posts);

  final List<PostSummary> _posts;

  /// When set, every call throws it.
  Object? failWith;

  void add(PostSummary post) => _posts.add(post);

  List<PostSummary> get _newestFirst {
    final list = List.of(_posts)
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return list;
  }

  PostPage _page(List<PostSummary> sorted, String? cursor, int limit) {
    final n = clampPageSize(limit);
    var start = 0;
    if (cursor != null) {
      final i = sorted.indexWhere((p) => p.id == cursor);
      start = i < 0 ? sorted.length : i + 1;
    }
    final rest = sorted.skip(start).toList();
    final page = rest.take(n).toList();
    return PostPage(
      posts: page,
      nextCursor: rest.length > n ? page.last.id : null,
    );
  }

  @override
  Future<PostPage> feed({
    PostKind? kind,
    String? specialtyId,
    String? cursor,
    int limit = 20,
  }) async {
    if (failWith != null) {
      throw failWith!;
    }
    final filtered = _newestFirst
        .where((p) => kind == null || p.kind == kind)
        .where((p) => specialtyId == null || p.specialtyId == specialtyId)
        .toList();
    return _page(filtered, cursor, limit);
  }

  @override
  Future<PostPage> byPhotographer(
    String photographerId, {
    String? cursor,
    int limit = 20,
  }) async {
    if (failWith != null) {
      throw failWith!;
    }
    final filtered = _newestFirst
        .where((p) => p.photographerId == photographerId)
        .toList();
    return _page(filtered, cursor, limit);
  }

  @override
  Future<PostSummary?> byId(String postId) async {
    if (failWith != null) {
      throw failWith!;
    }
    for (final p in _posts) {
      if (p.id == postId) {
        return p;
      }
    }
    return null;
  }
}

class FakePostEngagementRepository implements PostEngagementRepository {
  final _liked = <String>{};
  final _saved = <String>{};
  final _following = <String>{};

  Object? failWith;

  /// Number of successful writes, for asserting optimistic behaviour.
  int writeCalls = 0;

  /// Number of reads (`engagementFor`, `savedAmong`, `isFollowing`), for
  /// asserting how much a screen reads.
  int readCalls = 0;

  String _k(String uid, String id) => '${uid}_$id';

  void _check() {
    if (failWith != null) {
      throw failWith!;
    }
  }

  @override
  Future<PostEngagement> engagementFor(String uid, String postId) async {
    _check();
    readCalls++;
    return PostEngagement(
      liked: _liked.contains(_k(uid, postId)),
      saved: _saved.contains(_k(uid, postId)),
    );
  }

  @override
  Future<Set<String>> savedAmong(String uid, Iterable<String> postIds) async {
    _check();
    readCalls++;
    return {for (final id in postIds) if (_saved.contains(_k(uid, id))) id};
  }

  @override
  Future<void> setLiked(String uid, String postId, bool liked) async {
    _check();
    writeCalls++;
    liked ? _liked.add(_k(uid, postId)) : _liked.remove(_k(uid, postId));
  }

  @override
  Future<void> setSaved(String uid, String postId, bool saved) async {
    _check();
    writeCalls++;
    saved ? _saved.add(_k(uid, postId)) : _saved.remove(_k(uid, postId));
  }

  @override
  Future<bool> isFollowing(String uid, String photographerId) async {
    _check();
    readCalls++;
    return _following.contains(_k(uid, photographerId));
  }

  @override
  Future<void> setFollowing(
    String uid,
    String photographerId,
    bool following,
  ) async {
    _check();
    writeCalls++;
    following
        ? _following.add(_k(uid, photographerId))
        : _following.remove(_k(uid, photographerId));
  }
}

class FakePhotographerRepository implements PhotographerRepository {
  FakePhotographerRepository([List<PhotographerSummary> photographers = const []])
    : _all = List.of(photographers);

  final List<PhotographerSummary> _all;
  Object? failWith;

  void add(PhotographerSummary p) => _all.add(p);

  @override
  Future<Map<String, PhotographerSummary>> summaries(Iterable<String> ids) async {
    if (failWith != null) {
      throw failWith!;
    }
    final wanted = ids.toSet();
    return {
      for (final p in _all)
        if (wanted.contains(p.id)) p.id: p,
    };
  }

  @override
  Future<List<PhotographerSummary>> freeThisWeek({
    required DateTime now,
    int limit = 12,
  }) async {
    if (failWith != null) {
      throw failWith!;
    }
    final from = vnDateKey(now);
    final to = vnDateKey(now.add(const Duration(days: 7)));
    final list = _all.where((p) {
      final d = p.nextFreeDate;
      return d != null && d.compareTo(from) >= 0 && d.compareTo(to) < 0;
    }).toList()
      ..sort((a, b) {
        final byDay = a.nextFreeDate!.compareTo(b.nextFreeDate!);
        return byDay != 0 ? byDay : b.ratingAvg.compareTo(a.ratingAvg);
      });
    return list.take(limit).toList();
  }

  @override
  Future<List<PhotographerSummary>> candidates({int limit = 200}) async {
    if (failWith != null) {
      throw failWith!;
    }
    return _all.take(clampPageSize(limit, 200)).toList();
  }
}

class FakeServiceRepository implements ServiceRepository {
  FakeServiceRepository([List<ServiceSummary> services = const []])
    : _all = List.of(services);

  final List<ServiceSummary> _all;
  Object? failWith;

  void add(ServiceSummary s) => _all.add(s);

  @override
  Future<ServiceSummary?> byId(String photographerId, String serviceId) async {
    if (failWith != null) {
      throw failWith!;
    }
    for (final s in _all) {
      if (s.photographerId == photographerId && s.id == serviceId) {
        return s;
      }
    }
    return null;
  }

  @override
  Future<List<ServiceSummary>> activeFor(String photographerId) async {
    if (failWith != null) {
      throw failWith!;
    }
    return _all.where((s) => s.photographerId == photographerId && s.active).toList();
  }
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/content && flutter analyze`
Expected: PASS (models 8, fake contracts 7 + 5 + 4 + 2, extras 4); analyze clean. The `content_contracts.dart` file has no `main`, so `flutter test` skips it as a test entry point.

- [ ] **Step 5: Commit**

```bash
git add lib/data/content test/data/content
git commit -m "feat(data): content repository ports, fakes and shared contract tests

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Firestore adapter for posts and the viewer's engagement

**Files:**
- Create: `lib/data/content/firestore_post_repository.dart`, `test/data/content/firestore_post_repository_test.dart`
- Modify: `pubspec.yaml` (via `flutter pub add`)

**Interfaces:**
- Consumes: ports from Task 2; contracts from Task 2.
- Produces:
  - `PostSummary? postFromFirestore(String id, Map<String, dynamic> data)` — null when `photographerId`, `serviceId` or `imageUrls` are missing, or when the post is soft-deleted (`deletedAt` present).
  - `class FirestorePostRepository implements PostRepository` with `FirestorePostRepository({FirebaseFirestore? db})`; collection `posts`; ordering `createdAt` descending; cursor = id of the last post of the page; fetches `limit + 1` documents to know whether another page exists.
  - `class FirestoreEngagementRepository implements PostEngagementRepository`, documents `likes/{uid}_{postId}` `{userId, postId, createdAt}`, `saves/{uid}_{postId}` (same shape), `follows/{uid}_{photographerId}` `{userId, photographerId, createdAt}`.

Post document shape read here (original spec §5 plus the fields this step needs): `photographerId`, `serviceId`, `authorId`, `kind`, `imageUrls[]`, `imageMeta[{blurHash,w,h}]`, `caption`, `location.name`, `style`, `specialty`, `hashtags[]`, `inPortfolio`, `likeCount`, `saveCount`, `bookingId`, `createdAt`, `deletedAt`.

- [ ] **Step 1: Add the dev dependency and write the failing tests**

```bash
flutter pub add --dev fake_cloud_firestore
flutter pub get
```

Expected: resolves. `fake_cloud_firestore` must be compatible with the pinned `cloud_firestore ^6.10.0`; if pub reports a conflict, stop and report it instead of downgrading `cloud_firestore`.

```dart
// test/data/content/firestore_post_repository_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/firestore_post_repository.dart';
import 'package:photobooking/data/content/post_summary.dart';

import '../../support/content_fixtures.dart';
import 'content_contracts.dart';

Map<String, dynamic> postDoc(PostSummary p) => {
  'kind': p.kind.code,
  'authorId': p.authorId,
  'photographerId': p.photographerId,
  'serviceId': p.serviceId,
  if (p.bookingId != null) 'bookingId': p.bookingId,
  'imageUrls': [for (final i in p.images) i.url],
  'imageMeta': [
    for (final i in p.images) {'blurHash': i.blurHash, 'w': i.width, 'h': i.height},
  ],
  'caption': p.caption,
  if (p.locationName != null) 'location': {'name': p.locationName},
  if (p.styleId != null) 'style': p.styleId,
  if (p.specialtyId != null) 'specialty': p.specialtyId,
  'hashtags': p.hashtags,
  'inPortfolio': p.inPortfolio,
  'likeCount': p.likeCount,
  'saveCount': p.saveCount,
  'createdAt': Timestamp.fromDate(p.createdAt),
};

Future<FakeFirebaseFirestore> seededDb(List<PostSummary> posts) async {
  final db = FakeFirebaseFirestore();
  for (final p in posts) {
    await db.collection('posts').doc(p.id).set(postDoc(p));
  }
  return db;
}

void main() {
  postRepositoryContract('firestore', (seed) async {
    return FirestorePostRepository(db: await seededDb(seed));
  });
  engagementContract('firestore', () async {
    return FirestoreEngagementRepository(db: FakeFirebaseFirestore());
  });

  group('postFromFirestore', () {
    final full = {
      'kind': 'real_shoot',
      'authorId': 'u9',
      'photographerId': 'p1',
      'serviceId': 's1',
      'bookingId': 'b1',
      'imageUrls': ['https://img.test/1.jpg', 'https://img.test/2.jpg'],
      'imageMeta': [
        {'blurHash': 'LEHV6nWB2yk8', 'w': 800, 'h': 1000},
      ],
      'caption': 'Cảm ơn Minh Trí',
      'location': {'name': 'Bến Bạch Đằng', 'geohash': 'w3gv'},
      'style': 'natural_light',
      'specialty': 'portrait',
      'hashtags': ['chandung'],
      'inPortfolio': true,
      'likeCount': 214,
      'saveCount': 37.0,
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 30, 10)),
    };

    test('maps every field, tolerating numbers and short imageMeta', () {
      final p = postFromFirestore('x', full)!;
      expect(p.kind, PostKind.realShoot);
      expect(p.authorId, 'u9');
      expect(p.bookingId, 'b1');
      expect(p.images, hasLength(2));
      expect(p.images[0].blurHash, 'LEHV6nWB2yk8');
      expect(p.images[0].width, 800);
      expect(p.images[1].blurHash, isNull);
      expect(p.locationName, 'Bến Bạch Đằng');
      expect(p.styleId, 'natural_light');
      expect(p.specialtyId, 'portrait');
      expect(p.hashtags, ['chandung']);
      expect(p.likeCount, 214);
      expect(p.saveCount, 37);
      expect(p.createdAt, DateTime.utc(2026, 9, 30, 10));
      expect(p.createdAt.isUtc, isTrue);
    });

    test('defaults: kind work, author = photographer, zero counters', () {
      final p = postFromFirestore('y', {
        'photographerId': 'p1',
        'serviceId': 's1',
        'imageUrls': ['https://img.test/1.jpg'],
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 9, 30)),
      })!;
      expect(p.kind, PostKind.work);
      expect(p.authorId, 'p1');
      expect(p.likeCount, 0);
      expect(p.caption, '');
      expect(p.hashtags, isEmpty);
    });

    test('a pending server timestamp reads as "now", not a crash', () {
      final before = DateTime.now().toUtc();
      final p = postFromFirestore('z', {...full, 'createdAt': null})!;
      expect(p.createdAt.isBefore(before.subtract(const Duration(seconds: 1))), isFalse);
    });

    test('malformed or deleted posts are skipped', () {
      expect(postFromFirestore('a', {...full, 'photographerId': null}), isNull);
      expect(postFromFirestore('b', {...full, 'serviceId': null}), isNull);
      expect(postFromFirestore('c', {...full, 'imageUrls': <String>[]}), isNull);
      expect(postFromFirestore('d', {...full, 'deletedAt': Timestamp.now()}), isNull);
    });
  });

  group('FirestorePostRepository', () {
    test('deleted posts never show up in the feed, the profile or by id', () async {
      final db = await seededDb(contractPosts());
      await db.collection('posts').doc('a').update({'deletedAt': Timestamp.now()});
      final repo = FirestorePostRepository(db: db);
      expect((await repo.feed()).posts.map((p) => p.id), ['b', 'c', 'd', 'e']);
      expect((await repo.byPhotographer('p1')).posts.map((p) => p.id), ['b', 'c', 'e']);
      expect(await repo.byId('a'), isNull);
    });

    test('a malformed document is skipped without breaking the page', () async {
      final db = await seededDb(contractPosts());
      await db.collection('posts').doc('broken').set({
        'photographerId': 'p1',
        'createdAt': Timestamp.fromDate(fixtureNow),
      });
      final repo = FirestorePostRepository(db: db);
      expect((await repo.feed()).posts.map((p) => p.id), ['a', 'b', 'c', 'd', 'e']);
    });

    test('a cursor that no longer exists starts from the top instead of failing', () async {
      final repo = FirestorePostRepository(db: await seededDb(contractPosts()));
      final page = await repo.feed(limit: 2, cursor: 'vanished');
      expect(page.posts.map((p) => p.id), ['a', 'b']);
    });
  });

  group('FirestoreEngagementRepository documents', () {
    test('write the documents the rules expect, and delete them on undo', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreEngagementRepository(db: db);
      await repo.setLiked('u1', 'a', true);
      await repo.setSaved('u1', 'a', true);
      await repo.setFollowing('u1', 'p1', true);
      final like = await db.collection('likes').doc('u1_a').get();
      expect(like.data()!['userId'], 'u1');
      expect(like.data()!['postId'], 'a');
      expect(like.data()!.containsKey('createdAt'), isTrue);
      expect((await db.collection('saves').doc('u1_a').get()).exists, isTrue);
      final follow = await db.collection('follows').doc('u1_p1').get();
      expect(follow.data()!['photographerId'], 'p1');
      await repo.setLiked('u1', 'a', false);
      expect((await db.collection('likes').doc('u1_a').get()).exists, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/content/firestore_post_repository_test.dart`
Expected: FAIL, `firestore_post_repository.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/data/content/firestore_post_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/post_summary.dart';

int _int(Object? v) => v is num ? v.toInt() : 0;

DateTime _instant(Object? v) =>
    v is Timestamp ? v.toDate().toUtc() : DateTime.now().toUtc();

/// Maps a `posts/{id}` document. Returns null for documents that cannot be
/// shown: soft-deleted, or missing the photographer, the service or any image.
PostSummary? postFromFirestore(String id, Map<String, dynamic> d) {
  if (d['deletedAt'] != null) {
    return null;
  }
  final photographerId = d['photographerId'];
  final serviceId = d['serviceId'];
  final urls = d['imageUrls'];
  if (photographerId is! String ||
      serviceId is! String ||
      urls is! List ||
      urls.isEmpty) {
    return null;
  }
  final meta = d['imageMeta'] is List ? d['imageMeta'] as List : const [];
  final images = <PostImage>[
    for (var i = 0; i < urls.length; i++)
      PostImage(
        url: urls[i] as String,
        blurHash: i < meta.length && meta[i] is Map
            ? (meta[i] as Map)['blurHash'] as String?
            : null,
        width: i < meta.length && meta[i] is Map
            ? ((meta[i] as Map)['w'] as num?)?.toInt()
            : null,
        height: i < meta.length && meta[i] is Map
            ? ((meta[i] as Map)['h'] as num?)?.toInt()
            : null,
      ),
  ];
  final location = d['location'];
  return PostSummary(
    id: id,
    kind: PostKind.fromCode(d['kind'] as String?),
    authorId: (d['authorId'] as String?) ?? photographerId,
    photographerId: photographerId,
    serviceId: serviceId,
    bookingId: d['bookingId'] as String?,
    images: images,
    caption: (d['caption'] as String?) ?? '',
    locationName: location is Map ? location['name'] as String? : null,
    styleId: d['style'] as String?,
    specialtyId: d['specialty'] as String?,
    hashtags: [
      if (d['hashtags'] is List) ...(d['hashtags'] as List).whereType<String>(),
    ],
    inPortfolio: d['inPortfolio'] == true,
    likeCount: _int(d['likeCount']),
    saveCount: _int(d['saveCount']),
    createdAt: _instant(d['createdAt']),
  );
}

class FirestorePostRepository implements PostRepository {
  FirestorePostRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('posts');

  Future<PostPage> _page(
    Query<Map<String, dynamic>> base,
    String? cursor,
    int limit,
  ) async {
    final n = clampPageSize(limit);
    var q = base.orderBy('createdAt', descending: true);
    if (cursor != null) {
      final at = await _posts.doc(cursor).get();
      if (at.exists) {
        q = q.startAfterDocument(at);
      }
    }
    final snap = await q.limit(n + 1).get();
    final docs = snap.docs;
    final hasMore = docs.length > n;
    final pageDocs = hasMore ? docs.take(n).toList() : docs;
    final posts = <PostSummary>[
      for (final d in pageDocs)
        if (postFromFirestore(d.id, d.data()) case final p?) p,
    ];
    return PostPage(
      posts: posts,
      nextCursor: hasMore ? pageDocs.last.id : null,
    );
  }

  @override
  Future<PostPage> feed({
    PostKind? kind,
    String? specialtyId,
    String? cursor,
    int limit = 20,
  }) {
    Query<Map<String, dynamic>> q = _posts;
    if (kind != null) {
      q = q.where('kind', isEqualTo: kind.code);
    }
    if (specialtyId != null) {
      q = q.where('specialty', isEqualTo: specialtyId);
    }
    return _page(q, cursor, limit);
  }

  @override
  Future<PostPage> byPhotographer(
    String photographerId, {
    String? cursor,
    int limit = 20,
  }) => _page(
    _posts.where('photographerId', isEqualTo: photographerId),
    cursor,
    limit,
  );

  @override
  Future<PostSummary?> byId(String postId) async {
    final snap = await _posts.doc(postId).get();
    final data = snap.data();
    return data == null ? null : postFromFirestore(snap.id, data);
  }
}

class FirestoreEngagementRepository implements PostEngagementRepository {
  FirestoreEngagementRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(
    String collection,
    String uid,
    String id,
  ) => _db.collection(collection).doc('${uid}_$id');

  Future<void> _set(
    DocumentReference<Map<String, dynamic>> ref,
    bool on,
    Map<String, dynamic> data,
  ) async {
    if (on) {
      await ref.set({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await ref.delete();
    }
  }

  @override
  Future<PostEngagement> engagementFor(String uid, String postId) async {
    final results = await Future.wait([
      _doc('likes', uid, postId).get(),
      _doc('saves', uid, postId).get(),
    ]);
    return PostEngagement(liked: results[0].exists, saved: results[1].exists);
  }

  @override
  Future<Set<String>> savedAmong(String uid, Iterable<String> postIds) async {
    final ids = postIds.toSet().toList();
    final snaps = await Future.wait([
      for (final id in ids) _doc('saves', uid, id).get(),
    ]);
    return {
      for (var i = 0; i < ids.length; i++)
        if (snaps[i].exists) ids[i],
    };
  }

  @override
  Future<void> setLiked(String uid, String postId, bool liked) => _set(
    _doc('likes', uid, postId),
    liked,
    {'userId': uid, 'postId': postId},
  );

  @override
  Future<void> setSaved(String uid, String postId, bool saved) => _set(
    _doc('saves', uid, postId),
    saved,
    {'userId': uid, 'postId': postId},
  );

  @override
  Future<bool> isFollowing(String uid, String photographerId) async =>
      (await _doc('follows', uid, photographerId).get()).exists;

  @override
  Future<void> setFollowing(String uid, String photographerId, bool following) =>
      _set(_doc('follows', uid, photographerId), following, {
        'userId': uid,
        'photographerId': photographerId,
      });
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/content/firestore_post_repository_test.dart && flutter analyze`
Expected: PASS (7 + 5 contract tests, 4 mapping, 3 repository, 1 engagement); analyze clean. If `FieldValue.serverTimestamp()` is rejected by the fake, replace it in the test setup with `FakeFirebaseFirestore`'s supported equivalent only inside the test (never change the adapter): the fake supports `serverTimestamp` in current versions. 

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/data/content test/data/content
git commit -m "feat(data): Firestore post feed and engagement adapters

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Firestore adapter for photographers and services

**Files:**
- Create: `lib/data/content/firestore_photographer_repository.dart`, `test/data/content/firestore_photographer_repository_test.dart`

**Interfaces:**
- Consumes: ports and contracts from Task 2; `vnDateKey` from `core.dart`.
- Produces:
  - `PhotographerSummary photographerSummaryFrom({required String id, Map<String, dynamic>? user, required Map<String, dynamic> photographer})` — name and avatar from the public `users/{id}` document; everything else from `photographers/{id}`: `verified`, `coverUrl`, `skills.specialties[].id` (else the flat `specialties` list), `skills.styles` (else the flat `styles` list), `serviceArea.city`, `serviceArea.geo` (a `GeoPoint`), `stats.{rating, reviewCount, completedCount, responseMinutes, nextFreeDate}`, `startingPrice`, `createdAt`.
  - `ServiceSummary? serviceFromFirestore(String id, String photographerId, Map<String, dynamic> d)` — fields `name`, `specialty`, `price`, `durationMinutes`, `deliverables.{photoCount, editedCount, deliveryDays}`, `coverUrl`, `active` (default true); null when `name` or `price` is missing or the price is not above zero.
  - `FirestorePhotographerRepository({FirebaseFirestore? db})`, `FirestoreServiceRepository({FirebaseFirestore? db})`.
- `summaries` fetches the two documents per id in parallel (callers pass at most one page of ids); `freeThisWeek` queries `onboardingComplete == true` with `stats.nextFreeDate` in the window and returns the best-rated first within a day; `candidates` queries published photographers (`onboardingComplete == true`) with a limit.

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/content/firestore_photographer_repository_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/firestore_photographer_repository.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';

import '../../support/content_fixtures.dart';
import 'content_contracts.dart';

Future<void> seedPhotographer(
  FakeFirebaseFirestore db,
  PhotographerSummary p, {
  bool complete = true,
}) async {
  await db.collection('users').doc(p.id).set({
    'displayName': p.displayName,
    if (p.avatarUrl != null) 'avatarUrl': p.avatarUrl,
  });
  await db.collection('photographers').doc(p.id).set({
    'onboardingComplete': complete,
    'verified': p.verified,
    'specialties': p.specialtyIds,
    'styles': p.styleIds,
    if (p.coverUrl != null) 'coverUrl': p.coverUrl,
    'serviceArea': {
      'city': p.areaLabel,
      if (p.hasGeo) 'geo': GeoPoint(p.lat!, p.lng!),
      'radiusKm': 20,
    },
    'stats': {
      'rating': p.ratingAvg,
      'reviewCount': p.reviewCount,
      'completedCount': p.completedCount,
      if (p.responseMinutes != null) 'responseMinutes': p.responseMinutes,
      if (p.nextFreeDate != null) 'nextFreeDate': p.nextFreeDate,
    },
    if (p.startingPriceVnd != null) 'startingPrice': p.startingPriceVnd,
    if (p.createdAt != null) 'createdAt': Timestamp.fromDate(p.createdAt!),
  });
}

Future<void> seedService(FakeFirebaseFirestore db, ServiceSummary s) =>
    db.collection('photographers').doc(s.photographerId).collection('services').doc(s.id).set({
      'name': s.name,
      if (s.specialtyId != null) 'specialty': s.specialtyId,
      'price': s.priceVnd,
      'durationMinutes': s.durationMinutes,
      'deliverables': {
        'photoCount': s.photoCount,
        'editedCount': s.editedCount,
        'deliveryDays': s.deliveryDays,
      },
      'active': s.active,
    });

void main() {
  photographerRepositoryContract('firestore', (seed) async {
    final db = FakeFirebaseFirestore();
    for (final p in seed) {
      await seedPhotographer(db, p);
    }
    return FirestorePhotographerRepository(db: db);
  });

  serviceRepositoryContract('firestore', (seed) async {
    final db = FakeFirebaseFirestore();
    for (final s in seed) {
      await seedService(db, s);
    }
    return FirestoreServiceRepository(db: db);
  });

  group('photographerSummaryFrom', () {
    test('takes the name from users and the rest from photographers', () {
      final p = photographerSummaryFrom(
        id: 'p1',
        user: {'displayName': 'Minh Trí', 'avatarUrl': 'https://img.test/a.jpg'},
        photographer: {
          'verified': true,
          'coverUrl': 'https://img.test/c.jpg',
          'specialties': ['family'],
          'skills': {
            'specialties': [
              {'id': 'wedding', 'level': 3},
              {'id': 'portrait', 'level': 2},
            ],
            'styles': ['film'],
          },
          'styles': ['minimal'],
          'serviceArea': {'city': 'Quận 3', 'geo': const GeoPoint(10.78, 106.68)},
          'stats': {'rating': 4, 'reviewCount': 12.0, 'completedCount': 30, 'responseMinutes': 45, 'nextFreeDate': '2026-10-05'},
          'startingPrice': 2000000,
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
        },
      );
      expect(p.displayName, 'Minh Trí');
      expect(p.avatarUrl, 'https://img.test/a.jpg');
      expect(p.verified, isTrue);
      expect(p.specialtyIds, ['wedding', 'portrait'], reason: 'skills win over the flat list');
      expect(p.styleIds, ['film']);
      expect(p.areaLabel, 'Quận 3');
      expect(p.lat, 10.78);
      expect(p.ratingAvg, 4.0);
      expect(p.reviewCount, 12);
      expect(p.startingPriceVnd, 2000000);
      expect(p.createdAt, DateTime.utc(2026, 1, 2));
    });

    test('falls back to the flat specialties and survives a bare document', () {
      final p = photographerSummaryFrom(
        id: 'p2',
        user: null,
        photographer: {'specialties': ['family', 'couple'], 'styles': ['minimal']},
      );
      expect(p.styleIds, ['minimal']);
      expect(p.displayName, '');
      expect(p.specialtyIds, ['family', 'couple']);
      expect(p.hasGeo, isFalse);
      expect(p.hasRating, isFalse);
      expect(p.verified, isFalse);
      expect(p.nextFreeDate, isNull);
    });
  });

  group('serviceFromFirestore', () {
    test('maps deliverables and defaults to active', () {
      final s = serviceFromFirestore('s1', 'p1', {
        'name': 'Cưới cả ngày',
        'specialty': 'wedding',
        'price': 8000000,
        'durationMinutes': 480,
        'deliverables': {'photoCount': 300, 'editedCount': 120, 'deliveryDays': 14},
        'coverUrl': 'https://img.test/s.jpg',
      })!;
      expect((s.name, s.priceVnd, s.durationMinutes), ('Cưới cả ngày', 8000000, 480));
      expect((s.photoCount, s.editedCount, s.deliveryDays), (300, 120, 14));
      expect(s.active, isTrue);
      expect(s.photographerId, 'p1');
    });

    test('rejects a service without a name or with a non-positive price', () {
      expect(serviceFromFirestore('s', 'p', {'price': 1}), isNull);
      expect(serviceFromFirestore('s', 'p', {'name': 'x', 'price': 0}), isNull);
      expect(serviceFromFirestore('s', 'p', {'name': 'x'}), isNull);
    });
  });

  group('FirestorePhotographerRepository', () {
    test('candidates and free-this-week only list published photographers', () async {
      final db = FakeFirebaseFirestore();
      await seedPhotographer(db, fixturePhotographer('p1', nextFreeDate: '2026-10-02'));
      await seedPhotographer(db, fixturePhotographer('hidden', nextFreeDate: '2026-10-02'), complete: false);
      final repo = FirestorePhotographerRepository(db: db);
      expect((await repo.candidates()).map((p) => p.id), ['p1']);
      expect((await repo.freeThisWeek(now: fixtureNow)).map((p) => p.id), ['p1']);
    });

    test('summaries still resolve an unpublished author (their old posts keep a name)', () async {
      final db = FakeFirebaseFirestore();
      await seedPhotographer(db, fixturePhotographer('old', name: 'Cũ'), complete: false);
      final m = await FirestorePhotographerRepository(db: db).summaries(['old']);
      expect(m['old']!.displayName, 'Cũ');
    });

    test('a photographer document without a user document gets an empty name, not a crash', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('photographers').doc('p9').set({'onboardingComplete': true});
      final m = await FirestorePhotographerRepository(db: db).summaries(['p9']);
      expect(m['p9']!.displayName, '');
    });
  });
}
```

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/content/firestore_photographer_repository_test.dart`
Expected: FAIL, the adapter does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/data/content/firestore_photographer_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';

double _double(Object? v) => v is num ? v.toDouble() : 0;
int _int(Object? v) => v is num ? v.toInt() : 0;
int? _intOrNull(Object? v) => v is num ? v.toInt() : null;

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};

PhotographerSummary photographerSummaryFrom({
  required String id,
  Map<String, dynamic>? user,
  required Map<String, dynamic> photographer,
}) {
  final skills = _map(photographer['skills']);
  final skillIds = [
    if (skills['specialties'] is List)
      for (final s in skills['specialties'] as List)
        if (s is Map && s['id'] is String) s['id'] as String,
  ];
  final flat = [
    if (photographer['specialties'] is List)
      ...(photographer['specialties'] as List).whereType<String>(),
  ];
  final skillStyles = [
    if (skills['styles'] is List) ...(skills['styles'] as List).whereType<String>(),
  ];
  final flatStyles = [
    if (photographer['styles'] is List)
      ...(photographer['styles'] as List).whereType<String>(),
  ];
  final area = _map(photographer['serviceArea']);
  final geo = area['geo'];
  final stats = _map(photographer['stats']);
  final created = photographer['createdAt'];
  return PhotographerSummary(
    id: id,
    displayName: (user?['displayName'] as String?) ?? '',
    avatarUrl: user?['avatarUrl'] as String?,
    coverUrl: photographer['coverUrl'] as String?,
    verified: photographer['verified'] == true,
    specialtyIds: skillIds.isNotEmpty ? skillIds : flat,
    styleIds: skillStyles.isNotEmpty ? skillStyles : flatStyles,
    areaLabel: area['city'] as String?,
    lat: geo is GeoPoint ? geo.latitude : null,
    lng: geo is GeoPoint ? geo.longitude : null,
    ratingAvg: _double(stats['rating']),
    reviewCount: _int(stats['reviewCount']),
    completedCount: _int(stats['completedCount']),
    responseMinutes: _intOrNull(stats['responseMinutes']),
    startingPriceVnd: _intOrNull(photographer['startingPrice']),
    nextFreeDate: stats['nextFreeDate'] as String?,
    createdAt: created is Timestamp ? created.toDate().toUtc() : null,
  );
}

ServiceSummary? serviceFromFirestore(
  String id,
  String photographerId,
  Map<String, dynamic> d,
) {
  final name = d['name'];
  final price = _intOrNull(d['price']);
  if (name is! String || price == null || price <= 0) {
    return null;
  }
  final deliverables = _map(d['deliverables']);
  return ServiceSummary(
    id: id,
    photographerId: photographerId,
    name: name,
    specialtyId: d['specialty'] as String?,
    priceVnd: price,
    durationMinutes: _int(d['durationMinutes']),
    photoCount: _intOrNull(deliverables['photoCount']),
    editedCount: _intOrNull(deliverables['editedCount']),
    deliveryDays: _intOrNull(deliverables['deliveryDays']),
    coverUrl: d['coverUrl'] as String?,
    active: d['active'] != false,
  );
}

class FirestorePhotographerRepository implements PhotographerRepository {
  FirestorePhotographerRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Future<PhotographerSummary?> _load(String id) async {
    final (p, u) = await (
      _db.collection('photographers').doc(id).get(),
      _db.collection('users').doc(id).get(),
    ).wait;
    final data = p.data();
    return data == null
        ? null
        : photographerSummaryFrom(id: id, user: u.data(), photographer: data);
  }

  Future<List<PhotographerSummary>> _fromQuery(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    final users = await Future.wait([
      for (final d in snap.docs) _db.collection('users').doc(d.id).get(),
    ]);
    return [
      for (var i = 0; i < snap.docs.length; i++)
        photographerSummaryFrom(
          id: snap.docs[i].id,
          user: users[i].data(),
          photographer: snap.docs[i].data(),
        ),
    ];
  }

  @override
  Future<Map<String, PhotographerSummary>> summaries(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    final loaded = await Future.wait([for (final id in unique) _load(id)]);
    return {
      for (var i = 0; i < unique.length; i++)
        if (loaded[i] != null) unique[i]: loaded[i]!,
    };
  }

  @override
  Future<List<PhotographerSummary>> freeThisWeek({
    required DateTime now,
    int limit = 12,
  }) async {
    final from = vnDateKey(now);
    final to = vnDateKey(now.add(const Duration(days: 7)));
    final snap = await _db
        .collection('photographers')
        .where('onboardingComplete', isEqualTo: true)
        .where('stats.nextFreeDate', isGreaterThanOrEqualTo: from)
        .where('stats.nextFreeDate', isLessThan: to)
        .orderBy('stats.nextFreeDate')
        .limit(clampPageSize(limit))
        .get();
    final list = await _fromQuery(snap);
    // Firestore orders by day; best rated first within a day.
    list.sort((a, b) {
      final byDay = a.nextFreeDate!.compareTo(b.nextFreeDate!);
      return byDay != 0 ? byDay : b.ratingAvg.compareTo(a.ratingAvg);
    });
    return list;
  }

  @override
  Future<List<PhotographerSummary>> candidates({int limit = 200}) async {
    final snap = await _db
        .collection('photographers')
        .where('onboardingComplete', isEqualTo: true)
        .limit(clampPageSize(limit, 200))
        .get();
    return _fromQuery(snap);
  }
}

class FirestoreServiceRepository implements ServiceRepository {
  FirestoreServiceRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _services(String photographerId) =>
      _db.collection('photographers').doc(photographerId).collection('services');

  @override
  Future<ServiceSummary?> byId(String photographerId, String serviceId) async {
    final snap = await _services(photographerId).doc(serviceId).get();
    final data = snap.data();
    return data == null ? null : serviceFromFirestore(snap.id, photographerId, data);
  }

  @override
  Future<List<ServiceSummary>> activeFor(String photographerId) async {
    final snap = await _services(photographerId)
        .where('active', isEqualTo: true)
        .limit(kMaxPageSize)
        .get();
    return [
      for (final d in snap.docs)
        if (serviceFromFirestore(d.id, photographerId, d.data()) case final s?) s,
    ];
  }
}
```

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/content/firestore_photographer_repository_test.dart && flutter analyze`
Expected: PASS; analyze clean. If `freeThisWeek` fails only because the fake cannot filter on the dotted path `stats.nextFreeDate`, keep the query to `where('onboardingComplete', isEqualTo: true)` plus `orderBy('stats.nextFreeDate')` and filter the window in Dart (`from <= day < to`) before returning; the contract result is unchanged. A real Firestore handles the dotted path natively, and the index in Task 5 covers it.

- [ ] **Step 5: Commit**

```bash
git add lib/data/content test/data/content
git commit -m "feat(data): Firestore photographer and service adapters

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Providers, Firestore rules and indexes

**Files:**
- Create: `lib/data/content/content_providers.dart`, `test/data/content/content_providers_test.dart`
- Modify: `firebase/firestore.rules`, `firebase/rules-test/rules.test.mjs`, `firebase/firestore.indexes.json`

**Interfaces:**
- Produces: `postRepositoryProvider`, `postEngagementRepositoryProvider`, `photographerRepositoryProvider`, `serviceRepositoryProvider` (each a `Provider` of its port, default = the Firestore adapter; tests override with the fakes).
- Rules: `posts/{id}` readable by any signed-in user and not writable by clients (plan 3c adds creation); `likes`, `saves`, `follows` documents named `{uid}_{targetId}` that only their owner may read, create and delete, with a fixed field set; no updates.
- Indexes: `posts (kind, createdAt desc)`, `posts (kind, specialty, createdAt desc)`, `posts (photographerId, createdAt desc)`, `photographers (onboardingComplete, stats.nextFreeDate)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/content/content_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';

void main() {
  test('every provider can be replaced by a fake', () async {
    final posts = FakePostRepository();
    final eng = FakePostEngagementRepository();
    final ph = FakePhotographerRepository();
    final sv = FakeServiceRepository();
    final c = ProviderContainer(
      overrides: [
        postRepositoryProvider.overrideWithValue(posts),
        postEngagementRepositoryProvider.overrideWithValue(eng),
        photographerRepositoryProvider.overrideWithValue(ph),
        serviceRepositoryProvider.overrideWithValue(sv),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(postRepositoryProvider), same(posts));
    expect(c.read(postEngagementRepositoryProvider), same(eng));
    expect(c.read(photographerRepositoryProvider), same(ph));
    expect(c.read(serviceRepositoryProvider), same(sv));
  });
}
```

Append to `firebase/rules-test/rules.test.mjs`:

```js
// ---- discovery: posts, likes, saves, follows ----
test('any signed-in user reads posts; nobody writes them from the client yet', async () => {
  await env.withSecurityRulesDisabled(async (c) =>
    setDoc(doc(c.firestore(), 'posts/post1'), { photographerId: 'p1', serviceId: 's1', imageUrls: ['x'] }));
  const db = env.authenticatedContext('v1').firestore();
  await assertSucceeds(getDoc(doc(db, 'posts/post1')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'posts/post1')));
  await assertFails(setDoc(doc(db, 'posts/post2'), { photographerId: 'v1', serviceId: 's1', imageUrls: ['x'] }));
  await assertFails(updateDoc(doc(db, 'posts/post1'), { likeCount: 9999 }));
});

for (const [col, field, extra] of [['likes', 'postId', 'post1'], ['saves', 'postId', 'post1'], ['follows', 'photographerId', 'p1']]) {
  test(`${col}: the owner creates, reads (even a missing doc) and deletes their own marker`, async () => {
    const db = env.authenticatedContext('v1').firestore();
    const ref = doc(db, `${col}/v1_${extra}`);
    await assertSucceeds(getDoc(ref)); // a missing document must be readable to know "not liked"
    await assertSucceeds(setDoc(ref, { userId: 'v1', [field]: extra, createdAt: serverTimestamp() }));
    await assertSucceeds(getDoc(ref));
    await assertSucceeds(deleteDoc(ref));
  });

  test(`${col}: nobody else's marker can be read, created, changed or deleted`, async () => {
    await env.withSecurityRulesDisabled(async (c) =>
      setDoc(doc(c.firestore(), `${col}/v2_${extra}`), { userId: 'v2', [field]: extra }));
    const db = env.authenticatedContext('v1').firestore();
    await assertFails(getDoc(doc(db, `${col}/v2_${extra}`)));
    await assertFails(setDoc(doc(db, `${col}/v2_${extra}`), { userId: 'v2', [field]: extra, createdAt: serverTimestamp() }));
    await assertFails(deleteDoc(doc(db, `${col}/v2_${extra}`)));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), `${col}/v1_${extra}`)));
  });

  test(`${col}: a marker must match its document id and carry only the expected fields`, async () => {
    const db = env.authenticatedContext('v1').firestore();
    await assertFails(setDoc(doc(db, `${col}/v1_other`), { userId: 'v1', [field]: extra, createdAt: serverTimestamp() })); // id/target mismatch
    await assertFails(setDoc(doc(db, `${col}/v1_${extra}`), { userId: 'v2', [field]: extra, createdAt: serverTimestamp() })); // wrong owner
    await assertFails(setDoc(doc(db, `${col}/v1_${extra}`), { userId: 'v1', [field]: extra, createdAt: serverTimestamp(), weight: 5 })); // extra field
    await assertSucceeds(setDoc(doc(db, `${col}/v1_${extra}`), { userId: 'v1', [field]: extra, createdAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(db, `${col}/v1_${extra}`), { userId: 'v1' })); // markers are never updated
  });
}

test('a client cannot touch counters on posts or users through likes', async () => {
  const db = env.authenticatedContext('v1').firestore();
  await assertFails(updateDoc(doc(db, 'users/v1'), { savedCount: 10 }));
});
```

Make sure the top import line of `rules.test.mjs` includes `deleteDoc` and `serverTimestamp`:
`import { doc, setDoc, getDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp } from 'firebase/firestore';`

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/data/content/content_providers_test.dart` (FAIL: provider file missing). Then from `firebase/rules-test`: `npm ci && npm test`
Expected: the new rule tests FAIL (collections fall to the deny-all rule). If the emulator cannot run in this sandbox, say so in the report and rely on the CI job "Firestore rules tests (emulator)".

- [ ] **Step 3: Implement**

```dart
// lib/data/content/content_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/firestore_photographer_repository.dart';
import 'package:photobooking/data/content/firestore_post_repository.dart';

final postRepositoryProvider = Provider<PostRepository>(
  (ref) => FirestorePostRepository(),
);

final postEngagementRepositoryProvider = Provider<PostEngagementRepository>(
  (ref) => FirestoreEngagementRepository(),
);

final photographerRepositoryProvider = Provider<PhotographerRepository>(
  (ref) => FirestorePhotographerRepository(),
);

final serviceRepositoryProvider = Provider<ServiceRepository>(
  (ref) => FirestoreServiceRepository(),
);
```

In `firebase/firestore.rules`, add this helper next to the other functions and the three blocks above the final catch-all `match /{document=**}`:

```
    // likes/saves/follows: markers named {uid}_{targetId}, owned by uid. Reads
    // key off the document id, because a missing document has no `resource`
    // and "not liked yet" must be answerable.
    function markerId(uid, id) { return uid + '_' + id; }
    function ownMarkerName(docId) {
      return signedIn() && docId.matches(request.auth.uid + '_.+');
    }
    function validMarker(docId, targetField) {
      let d = request.resource.data;
      return d.keys().hasOnly(['userId', targetField, 'createdAt'])
        && d.userId == request.auth.uid
        && d[targetField] is string
        && docId == markerId(request.auth.uid, d[targetField]);
    }
```

```
    // Posts are read by any signed-in user. Creation is added with the Create
    // Post screen; counters are always written by Cloud Functions.
    match /posts/{postId} {
      allow read: if signedIn();
      allow write: if false;
    }

    match /likes/{docId} {
      allow read: if ownMarkerName(docId);
      allow create: if ownMarkerName(docId) && validMarker(docId, 'postId');
      allow delete: if ownMarkerName(docId);
      allow update: if false;
    }
    match /saves/{docId} {
      allow read: if ownMarkerName(docId);
      allow create: if ownMarkerName(docId) && validMarker(docId, 'postId');
      allow delete: if ownMarkerName(docId);
      allow update: if false;
    }
    match /follows/{docId} {
      allow read: if ownMarkerName(docId);
      allow create: if ownMarkerName(docId) && validMarker(docId, 'photographerId');
      allow delete: if ownMarkerName(docId);
      allow update: if false;
    }
```

Replace `firebase/firestore.indexes.json` with (keeping any index entries other plans already added; merge, do not drop them):

```json
{
  "indexes": [
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "kind", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "kind", "order": "ASCENDING" },
        { "fieldPath": "specialty", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "photographerId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "photographers",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "onboardingComplete", "order": "ASCENDING" },
        { "fieldPath": "stats.nextFreeDate", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

The feed without a `kind` filter and without a specialty (`feed()` with no arguments) orders by `createdAt` alone, which Firestore serves from its automatic single-field index. `feed(specialtyId:)` without `kind` is not used by any screen.

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/data/content && flutter analyze` then from `firebase/rules-test`: `npm test`
Expected: Dart tests pass; all rules tests pass, old and new (the new ones add 1 + 3 x 3 + 1 = 11). If a "missing document is readable" case fails, the `read` rule must depend only on the document id (it does); do not add `resource.data` to it.

- [ ] **Step 5: Commit**

```bash
git add lib/data/content test/data/content firebase
git commit -m "feat(data): content providers, rules for posts and markers, indexes

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Battery and performance check

**Files:**
- Create (if missing): `test/support/idle.dart`, `test/support/blur.dart`
- Create: `test/battery/feed_data_battery_test.dart`
- Reference (written by the screen-codes plan, do not rewrite): `docs/testing/battery-and-performance.md`

**Interfaces:**
- Consumes: the ports, fakes and adapters of Tasks 2 to 5.
- Produces: no production code. This plan adds no widget or screen, so there is no `expectIdle` or blur test here; the shared helpers are created now so later plans find them.

What is checked: no Firestore or stream listener exists in this layer (so none can outlive a screen), every list query is bounded by a cap whatever the caller asks for, and the viewer's markers cost one document write each.

- [ ] **Step 1: Write the tests**

If either helper file is missing, create it exactly as in plan 3a1 Task 7 (`test/support/idle.dart` with `expectIdle`, `test/support/blur.dart` with `expectBlurBudget`):

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
// test/battery/feed_data_battery_test.dart
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/firestore_photographer_repository.dart';
import 'package:photobooking/data/content/firestore_post_repository.dart';

import '../data/content/firestore_photographer_repository_test.dart' show seedPhotographer, seedService;
import '../data/content/firestore_post_repository_test.dart' show seededDb;
import '../support/content_fixtures.dart';

void main() {
  test('the data layer opens no listener and runs no timer', () {
    for (final f in Directory('lib/data/content').listSync().whereType<File>()) {
      final src = f.readAsStringSync();
      expect(src, isNot(contains('.snapshots(')), reason: f.path);
      expect(src, isNot(contains('Timer.periodic')), reason: f.path);
      expect(src, isNot(contains('StreamController')), reason: f.path);
    }
    final ports = File('lib/data/content/content_repositories.dart').readAsStringSync();
    expect(ports, isNot(contains('Stream<')));
  });

  test('a huge page request is clamped to 50 posts', () async {
    final posts = [
      for (var i = 0; i < 80; i++) fixturePost('m$i', age: Duration(minutes: i + 1)),
    ];
    final repo = FirestorePostRepository(db: await seededDb(posts));
    expect((await repo.feed(limit: 100000)).posts, hasLength(50));
    expect((await repo.byPhotographer('p1', limit: 100000)).posts, hasLength(50));
  });

  test('candidates are capped at 200 and free-this-week at 50', () async {
    final db = FakeFirebaseFirestore();
    for (var i = 0; i < 230; i++) {
      await seedPhotographer(db, fixturePhotographer('c$i', nextFreeDate: '2026-10-03'));
    }
    final repo = FirestorePhotographerRepository(db: db);
    expect(await repo.candidates(limit: 100000), hasLength(200));
    expect(await repo.freeThisWeek(now: fixtureNow, limit: 100000), hasLength(50));
  });

  test('a photographer\'s service list is capped at 50', () async {
    final db = FakeFirebaseFirestore();
    for (var i = 0; i < 70; i++) {
      await seedService(db, fixtureService('s$i'));
    }
    expect(await FirestoreServiceRepository(db: db).activeFor('p1'), hasLength(50));
  });

  test('a like is one document write and an undo one delete', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestoreEngagementRepository(db: db);
    await repo.setLiked('u1', 'a', true);
    expect((await db.collection('likes').get()).docs, hasLength(1));
    await repo.setLiked('u1', 'a', false);
    expect((await db.collection('likes').get()).docs, isEmpty);
  });
}
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/battery/feed_data_battery_test.dart`
Expected: PASS (5 tests). A failure means someone added a listener or an unbounded query to the adapters; fix the adapter, do not loosen the test.

- [ ] **Step 3: Fix anything the run found**

For example add the missing `.limit(...)` to a new query. Re-run Step 2.

- [ ] **Step 4: Manual profiling**

Follow `docs/testing/battery-and-performance.md` (written by the screen-codes plan; do not rewrite it). This plan has no UI, so profile it through the screens of plan 3b4 when they land; until then run the Firestore emulator suite and record the read counts of one Home load (expected: one feed page query, at most 2 documents per distinct author) in this plan's PR description.

- Android: mid-range device, `flutter run --profile`, DevTools Network and Performance.
- iOS: Xcode Instruments (Network and Energy Log) on a real iPhone, or the Debug Navigator gauges in the Simulator; Energy Impact must read "Low" at rest. Prerequisite: iOS cannot be built on this machine yet (no Xcode, no CocoaPods, no iOS Firebase configuration); that is a separate "iOS enablement" plan, so until it lands record "iOS: not measured, blocked by iOS enablement".

Record the results in the PR description with the table template of the guide; add the iOS rows with the iPhone model in the Thiết bị column and Energy Impact in place of the Android-only columns.

- [ ] **Step 5: Commit**

```bash
git add test/support test/battery
git commit -m "test: bounded-read and no-listener checks for the feed data layer

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** read models for S01/S02/S04 (§5, §3e.9: `PhotographerSummary` with rating, sessions, price-from, `nextFreeDate`; `PostSummary` with kind, images, specialty, counters; `ServiceSummary`); likes/saves/follows as owner-only marker documents (spec original §5); counters never client-written (rules + docs); soft-deleted posts hidden; cursor pagination 20/page with a 50 cap (S01 "phân trang 20/lần"); `freeThisWeek` = `stats.nextFreeDate` within 7 days (S01 "Rảnh tuần này"); contract tests run against fake and Firestore adapter (§7 and data-model README §7.3); Firebase imports confined to two adapter files plus the provider wiring.
- **Deviations (flagged):** (1) `PostSummary.specialtyId` (field `specialty` on the post) is new: the original post schema has no specialty, so Home category chips would need a join; plan 3c writes it. (2) Image URLs are stored on the post as in the original spec; the data-model's `MediaUrlResolver` migration stays a later concern. (3) Free-day and candidate queries read photographer documents directly; at scale they are replaced by the recommender service (plan 3r) without changing the ports.
- **Placeholders:** none. **Type consistency:** `PostRepository.feed/byPhotographer/byId`, `PostPage.nextCursor`, `PostEngagementRepository` method names, `PhotographerRepository.summaries/freeThisWeek(now:)/candidates`, `ServiceRepository.byId(photographerId, serviceId)/activeFor`, `fixturePost/fixturePhotographer/fixtureService`, `postFromFirestore`, `photographerSummaryFrom`, `serviceFromFirestore` are the names plans 3b2 to 3c use.
- **Battery and performance (Task 6):** no listeners and no timers in the layer, bounded queries (50 posts, 200 candidates, 50 services), no listeners, one write per marker; shared helpers `expectIdle` and `expectBlurBudget` created for later plans; manual Android and iOS profiling recorded per `docs/testing/battery-and-performance.md`.
- **Risks:** `fake_cloud_firestore` support for dotted field paths in `where`/`orderBy` (Task 4 Step 4 gives the Dart-side fallback) and for `FieldValue.serverTimestamp()`; the rules tests need the Firestore emulator (Java, Node) and are covered by the CI job if the sandbox cannot run them; the composite index for `photographers` must be deployed (`firebase deploy --only firestore:indexes`) before `freeThisWeek` works against production.
