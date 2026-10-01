# Step 3b4: Home, Photo Detail and Find Photographer (S01, S02, S04) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The three discovery screens run on real data: Home (S01) with category chips, the large photo card, "Rảnh tuần này", "Buổi chụp thật" and paging; Photo detail (S02) with like, save, follow and "Đặt gói này"; Find photographer (S04) with filter chips, sort, reasons and the local fallback note. The `HomeTab` placeholder and the customer half of `ActionTab` are replaced.

**Architecture:** Screens are `ConsumerStatefulWidget`s that read Riverpod controllers and never call repositories directly. Ranking comes from `recommendationRepositoryProvider` (3b3), content from the 3b1 repositories, cards from 3b2, location from the 3a2 `exploreResolutionProvider` (no extra permission prompt; only an already granted fix or a saved area is used). Likes, saves and follows are optimistic and revert on failure (`EngagementController`, `FollowController`). "Đặt" goes through `startBooking`, which opens the add-phone screen (S33, plan 2a) first when the customer has no number, and then the booking route (step 4).

**Tech Stack:** Flutter, Riverpod 3, go_router, `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/screens/discovery.md` (S01, S02, S04), `docs/superpowers/specs/2026-10-01-remaining-screens.md` §3b.1 (phone gate), §3e.9, §5, §6, §7; mock `docs/design/ui-mock.html` (`data-code="S01"`, `S02`, `S04`).

**Prerequisite:** plans `step3a1-location-foundations`, `step3a2-explore-screens`, `step3b1-feed-data`, `step3b2-feed-cards`, `step3b3-recommendations` are done; `2026-10-01-step2a-phone-and-customer-contact.md` is done (`currentContactProvider`, route `/profile/phone?returnTo=`, `FakeUserContactRepository`); the screen-codes and core-display-widgets plans are done. Routes of other plans are linked by path only: `/u/:uid` (S03, plan 2d), `/u/:uid/book` (step 4), `/profile/phone` (2a). Until a route exists, tapping its link shows go_router's error page; tests use stub routes.

## Global Constraints

- Run every command from `app_flutter/` after `source ../scripts/env.sh && export HOME="$PWD/../.home" && export PATH="$PWD/../.flutter/bin:$PATH"`. Run `dart format lib test` before each commit (`require_trailing_commas` is a lint and `flutter analyze` fails on infos).
- Imports are `package:photobooking/...` only; features import `package:photobooking/core/core.dart`; screens use controllers and providers, never `FirebaseFirestore`.
- No hard-coded UI text: Vietnamese strings with full diacritics in `lib/l10n/app_vi.arb`, then `flutter gen-l10n`. Free events and prices follow the format helpers; no raw hex or magic numbers.
- **Blur budget:** these screens use no `BackdropFilter` except inside `showAppSheet` frames; at most 4 per screen and none nested. List items (cards) never blur.
- **Battery:** nothing animates at rest; lists are lazy (`SliverAdaptiveRows`, `SliverList`, `SliverGrid`); photos go through `NetworkPhoto` (display-size decode); no listener outlives its screen (`autoDispose` providers, future-based repositories); the screens never ask for location permission.
- Likes, saves and follows change the screen immediately and revert with a snackbar when the write fails. Counters are server-owned; the screen shows the post's count plus the viewer's own +1.
- One primary action per screen: S01 has none (the empty state's button only when empty), S02 has "Đặt gói này" (or "Xem các gói khác"), S04 has none (the empty state's "Xoá bộ lọc" only when empty).
- Layouts tested at width 320 and text scale 1.3; two columns from 600dp on S01 (below the first card) and S04. Interactive controls have a 48dp touch target.
- iOS: no platform configuration is added; iOS cannot be built on this machine yet (separate "iOS enablement" plan).
- Commits use Conventional Commits and end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## File Structure

| File | Responsibility |
|---|---|
| `lib/features/discovery/engagement_controller.dart` (create) | `EngagementView`, `EngagementController`/`engagementProvider`, `FollowController`/`followProvider` |
| `lib/features/discovery/book_entry.dart` (create) | `bookingPath`, `startBooking` (phone gate) |
| `lib/features/discovery/photographer_meta.dart` (create) | `areaRatingMeta`, `freeThisWeekLabel` |
| `lib/features/home/home_controller.dart`, `home_screen.dart` (create) | S01 |
| `lib/features/photo/photo_detail_controller.dart`, `photo_detail_screen.dart` (create) | S02 |
| `lib/features/find/find_controller.dart`, `find_sheets.dart`, `find_screen.dart` (create) | S04 |
| `lib/core/widgets/option_row.dart` (create) | `OptionRow` (single-choice row for sheets) |
| `lib/core/format.dart` (modify) | `formatDuration` |
| `lib/features/shell/placeholder_tabs.dart`, `lib/app/router.dart` (modify) | remove `HomeTab`, route S01/S02/S04 |
| `test/features/responsive_test.dart` (modify) | drop the removed `HomeTab` |
| `lib/l10n/app_vi.arb` (modify) | strings listed per task |
| `test/support/discovery_world.dart` (create) | fakes and overrides shared by the screen tests |
| tests | listed per task; `test/battery/discovery_screens_battery_test.dart` |

---

### Task 1: Engagement, booking entry, shared helpers and the test world

**Files:**
- Create: `lib/features/discovery/engagement_controller.dart`, `lib/features/discovery/book_entry.dart`, `lib/features/discovery/photographer_meta.dart`, `test/support/discovery_world.dart`, `test/features/discovery/engagement_controller_test.dart`, `test/features/discovery/book_entry_test.dart`, `test/features/discovery/photographer_meta_test.dart`
- Modify: `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `authRepositoryProvider`, `postEngagementRepositoryProvider`, `currentContactProvider` (2a), `FakeUserContactRepository`/`userContactRepositoryProvider` (2a), `UserContact`.
- Produces:
  - `class EngagementView { const EngagementView({bool liked = false, bool saved = false, int likeCount = 0, int saveCount = 0}); copyWith }`
  - `class EngagementController extends Notifier<Map<String, EngagementView>>` with `Future<void> seed(Iterable<PostSummary> posts)` (counts at once; the viewer's saved marks for the list in one batch; a failed batch is ignored), `Future<void> load(PostSummary post)` (liked and saved for one post), `Future<bool> toggleLike(String postId)`, `Future<bool> toggleSave(String postId)` (optimistic, revert and return false on failure, a second tap while the first is in flight is ignored, counts never below 0, false when signed out or the post was never seeded); `engagementProvider`.
  - `class FollowController extends Notifier<Map<String, bool>>` with `Future<void> load(String photographerId)`, `Future<bool> toggle(String photographerId)`; `followProvider`.
  - `String bookingPath({required String photographerId, String? serviceId, DateTime? date})` → `/u/p1/book?serviceId=s1&date=2026-10-12`; `Future<void> startBooking(BuildContext context, WidgetRef ref, {required String photographerId, String? serviceId, DateTime? date})` — pushes `bookingPath(...)`, or, when the customer has no phone number, `/profile/phone?returnTo=<encoded bookingPath>` (spec 3b.1).
  - `String areaRatingMeta(PhotographerSummary p, AppLocalizations l)` → `Quận 3 · ★ 4,9 (58) · 112 buổi` (only the parts that exist); `String? freeThisWeekLabel(PhotographerSummary p, DateTime now, AppLocalizations l)` → `Rảnh T7 này` when the next free day is within the next 7 Vietnamese days, else null.
  - l10n: `homePillFree(day)` "Rảnh {day} này", `engagementError` "Chưa thực hiện được. Thử lại nhé.", `back` "Quay lại".
  - Test world: `DiscoveryWorld` (below) with `init()`, `overrides`, the fakes as public fields, and the data lists `discoveryPhotographers()`, `discoveryPosts()`, `discoveryServices()`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/support/discovery_world.dart
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/events/nearby_events_repository.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/local_recommender.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_fixtures.dart';

/// p1 free Sat 3 Oct, p2 free Fri 2 Oct, p3 free Sun 4 Oct, p4 no free day.
List<PhotographerSummary> discoveryPhotographers() => [
  fixturePhotographer('p1', name: 'Minh Trí', verified: true, specialties: const ['portrait', 'wedding'], styles: const ['natural_light'], nextFreeDate: '2026-10-03', areaLabel: 'Quận 3', startingPrice: 1500000),
  fixturePhotographer('p2', name: 'Hồng Nhung', specialties: const ['wedding'], rating: 4.7, reviews: 64, completed: 80, nextFreeDate: '2026-10-02', areaLabel: 'Quận 1', startingPrice: 8000000, lat: 10.80, lng: 106.70),
  fixturePhotographer('p3', name: 'Quốc Bảo', specialties: const ['family'], styles: const ['film'], rating: 4.5, reviews: 20, completed: 40, nextFreeDate: '2026-10-04', areaLabel: 'Thủ Đức', startingPrice: 1200000, lat: 10.85, lng: 106.75),
  fixturePhotographer('p4', name: 'Thu Hà', specialties: const ['graduation'], rating: 4.2, reviews: 9, completed: 20, areaLabel: 'Quận 7', startingPrice: 3000000, lat: 10.73, lng: 106.72),
];

/// Newest first: a, b, c, d, e work posts; two real-shoot posts by customers.
List<PostSummary> discoveryPosts() => [
  fixturePost('a', photographerId: 'p1', serviceId: 's1', specialtyId: 'portrait', age: const Duration(hours: 1), likes: 214, saves: 37),
  fixturePost('b', photographerId: 'p2', serviceId: 't1', specialtyId: 'wedding', age: const Duration(hours: 2)),
  fixturePost('c', photographerId: 'p3', serviceId: 'u1', specialtyId: 'family', age: const Duration(hours: 3)),
  fixturePost('d', photographerId: 'p4', serviceId: 'v1', specialtyId: 'graduation', age: const Duration(hours: 4)),
  fixturePost('e', photographerId: 'p1', serviceId: 's1', specialtyId: 'portrait', age: const Duration(hours: 5), images: 2),
  fixturePost('r1', kind: PostKind.realShoot, authorId: 'cu1', photographerId: 'p1', serviceId: 's1', age: const Duration(minutes: 30), caption: 'Cảm ơn Minh Trí'),
  fixturePost('r2', kind: PostKind.realShoot, authorId: 'cu2', photographerId: 'p2', serviceId: 't1', age: const Duration(minutes: 40)),
];

List<ServiceSummary> discoveryServices() => [
  fixtureService('s1'),
  fixtureService('s2', name: 'Cặp đôi nửa ngày', price: 3200000, specialtyId: 'couple'),
  fixtureService('sOld', name: 'Gói cũ', active: false),
  fixtureService('t1', photographerId: 'p2', name: 'Cưới cả ngày', price: 8000000, specialtyId: 'wedding'),
  fixtureService('u1', photographerId: 'p3', name: 'Gia đình 1 giờ', price: 1200000, specialtyId: 'family', durationMinutes: 60),
  fixtureService('v1', photographerId: 'p4', name: 'Kỷ yếu', price: 3000000, specialtyId: 'graduation'),
];

/// Fakes and provider overrides for a signed-in user using the discovery
/// screens. Location defaults to "denied forever": no prompt, no fix.
class DiscoveryWorld {
  DiscoveryWorld({
    List<PostSummary>? posts,
    List<PhotographerSummary>? photographers,
    List<ServiceSummary>? services,
    this.role = UserRole.customer,
    this.hasPhone = true,
    LocationPermissionStatus status = LocationPermissionStatus.deniedForever,
    this.prefsValues = const {},
    this.recommenderFactory,
  }) : posts = FakePostRepository(posts ?? discoveryPosts()),
       photographers = FakePhotographerRepository(photographers ?? discoveryPhotographers()),
       services = FakeServiceRepository(services ?? discoveryServices()),
       engagement = FakePostEngagementRepository(),
       availability = FakeAvailabilityLookup(),
       location = FakeLocationRepository(status: status),
       contacts = FakeUserContactRepository();

  final FakePostRepository posts;
  final FakePhotographerRepository photographers;
  final FakeServiceRepository services;
  final FakePostEngagementRepository engagement;
  final FakeAvailabilityLookup availability;
  final FakeLocationRepository location;
  final FakeUserContactRepository contacts;
  final UserRole role;
  final bool hasPhone;
  final Map<String, Object> prefsValues;

  /// Builds the recommender used by the screens; defaults to a
  /// [LocalRecommender] over the fakes above.
  final RecommendationRepository Function(DiscoveryWorld world)? recommenderFactory;

  late SharedPreferences prefs;
  late FakeAuthRepository auth;
  late String uid;
  late RecommendationRepository recommender;
  late List<Override> overrides;

  LocalRecommender localRecommender() => LocalRecommender(
    posts: posts,
    photographers: photographers,
    availability: availability,
    clock: () => fixtureNow,
  );

  Future<void> init() async {
    SharedPreferences.setMockInitialValues(prefsValues);
    prefs = await SharedPreferences.getInstance();
    auth = FakeAuthRepository();
    final users = FakeUserRepository();
    final u = await auth.registerWithEmail('a@b.vn', 'password1', 'Lan Anh');
    await users.ensureProfile(u);
    await users.setRole(u.uid, role);
    uid = u.uid;
    if (hasPhone) {
      contacts.seed(u.uid, const UserContact(phone: '+84903123456'));
    }
    recommender = recommenderFactory?.call(this) ?? localRecommender();
    overrides = [
      sharedPreferencesProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(() => fixtureNow),
      authRepositoryProvider.overrideWithValue(auth),
      userRepositoryProvider.overrideWithValue(users),
      userContactRepositoryProvider.overrideWithValue(contacts),
      locationRepositoryProvider.overrideWithValue(location),
      nearbyEventsRepositoryProvider.overrideWithValue(FakeNearbyEventsRepository()),
      postRepositoryProvider.overrideWithValue(posts),
      postEngagementRepositoryProvider.overrideWithValue(engagement),
      photographerRepositoryProvider.overrideWithValue(photographers),
      serviceRepositoryProvider.overrideWithValue(services),
      availabilityLookupProvider.overrideWithValue(availability),
      recommendationRepositoryProvider.overrideWithValue(recommender),
    ];
  }
}
```

```dart
// test/features/discovery/engagement_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';

import '../../support/content_fixtures.dart';

Future<(ProviderContainer, FakePostEngagementRepository, String?)> _make({
  bool signedIn = true,
}) async {
  final auth = FakeAuthRepository();
  String? uid;
  if (signedIn) {
    uid = (await auth.registerWithEmail('a@b.vn', 'password1', 'Lan')).uid;
  }
  final repo = FakePostEngagementRepository();
  final c = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      postEngagementRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(c.dispose);
  return (c, repo, uid);
}

void main() {
  group('seed and load', () {
    test('seed takes the counts from the posts and the saved marks in one batch', () async {
      final (c, repo, uid) = await _make();
      await repo.setSaved(uid!, 'a', true);
      await c.read(engagementProvider.notifier).seed([
        fixturePost('a', likes: 3, saves: 1),
        fixturePost('b', likes: 9),
      ]);
      final s = c.read(engagementProvider);
      expect(s['a'], isA<EngagementView>());
      expect((s['a']!.likeCount, s['a']!.saveCount, s['a']!.saved), (3, 1, true));
      expect((s['b']!.likeCount, s['b']!.saved), (9, false));
    });

    test('a failing batch is ignored: counts stay, marks stay false', () async {
      final (c, repo, _) = await _make();
      repo.failWith = StateError('offline');
      await c.read(engagementProvider.notifier).seed([fixturePost('a', likes: 3)]);
      expect(c.read(engagementProvider)['a']!.likeCount, 3);
      expect(c.read(engagementProvider)['a']!.saved, isFalse);
    });

    test('seeding again keeps what the viewer already did', () async {
      final (c, _, _) = await _make();
      final n = c.read(engagementProvider.notifier);
      await n.seed([fixturePost('a', likes: 3)]);
      await n.toggleLike('a');
      await n.seed([fixturePost('a', likes: 3)]);
      expect(c.read(engagementProvider)['a']!.liked, isTrue);
      expect(c.read(engagementProvider)['a']!.likeCount, 4);
    });

    test('load reads liked and saved for one post', () async {
      final (c, repo, uid) = await _make();
      await repo.setLiked(uid!, 'a', true);
      await repo.setSaved(uid, 'a', true);
      await c.read(engagementProvider.notifier).load(fixturePost('a', likes: 5, saves: 2));
      final v = c.read(engagementProvider)['a']!;
      expect((v.liked, v.saved, v.likeCount, v.saveCount), (true, true, 5, 2));
    });
  });

  group('toggle', () {
    test('a like is shown at once and stored; undoing restores the count', () async {
      final (c, repo, uid) = await _make();
      final n = c.read(engagementProvider.notifier);
      await n.seed([fixturePost('a', likes: 3)]);
      final pending = n.toggleLike('a');
      expect(c.read(engagementProvider)['a']!.liked, isTrue, reason: 'optimistic');
      expect(c.read(engagementProvider)['a']!.likeCount, 4);
      expect(await pending, isTrue);
      expect((await repo.engagementFor(uid!, 'a')).liked, isTrue);
      expect(await n.toggleLike('a'), isTrue);
      expect(c.read(engagementProvider)['a']!.likeCount, 3);
      expect((await repo.engagementFor(uid, 'a')).liked, isFalse);
    });

    test('a failed write puts everything back and says so', () async {
      final (c, repo, _) = await _make();
      final n = c.read(engagementProvider.notifier);
      await n.seed([fixturePost('a', likes: 3)]);
      repo.failWith = StateError('offline');
      expect(await n.toggleLike('a'), isFalse);
      final v = c.read(engagementProvider)['a']!;
      expect((v.liked, v.likeCount), (false, 3));
      expect(await n.toggleSave('a'), isFalse);
      expect(c.read(engagementProvider)['a']!.saved, isFalse);
    });

    test('a second tap while the first is in flight is ignored', () async {
      final (c, repo, _) = await _make();
      final n = c.read(engagementProvider.notifier);
      await n.seed([fixturePost('a', likes: 3)]);
      final first = n.toggleLike('a');
      final second = n.toggleLike('a');
      await Future.wait([first, second]);
      expect(repo.writeCalls, 1);
      expect(c.read(engagementProvider)['a']!.liked, isTrue);
    });

    test('like and save are independent, and counts never go below zero', () async {
      final (c, _, _) = await _make();
      final n = c.read(engagementProvider.notifier);
      await n.seed([fixturePost('a', likes: 0, saves: 0)]);
      await n.toggleSave('a');
      var v = c.read(engagementProvider)['a']!;
      expect((v.saved, v.saveCount, v.liked), (true, 1, false));
      await n.toggleSave('a');
      await n.toggleSave('a');
      await n.toggleSave('a');
      v = c.read(engagementProvider)['a']!;
      expect(v.saveCount, greaterThanOrEqualTo(0));
    });

    test('nothing happens when signed out or for an unknown post', () async {
      final (c, repo, _) = await _make(signedIn: false);
      final n = c.read(engagementProvider.notifier);
      await n.seed([fixturePost('a')]);
      expect(await n.toggleLike('a'), isFalse);
      expect(repo.writeCalls, 0);
      final (c2, _, _) = await _make();
      expect(await c2.read(engagementProvider.notifier).toggleLike('ghost'), isFalse);
    });
  });

  group('follow', () {
    test('load, toggle and revert', () async {
      final (c, repo, uid) = await _make();
      await repo.setFollowing(uid!, 'p1', true);
      final n = c.read(followProvider.notifier);
      await n.load('p1');
      expect(c.read(followProvider)['p1'], isTrue);
      expect(await n.toggle('p1'), isTrue);
      expect(c.read(followProvider)['p1'], isFalse);
      repo.failWith = StateError('offline');
      expect(await n.toggle('p1'), isFalse);
      expect(c.read(followProvider)['p1'], isFalse, reason: 'back to the value before the failed tap');
    });
  });
}
```

```dart
// test/features/discovery/book_entry_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/features/discovery/book_entry.dart';

import '../../support/discovery_world.dart';
import '../../support/screen_host.dart';

class _Button extends ConsumerWidget {
  const _Button({this.serviceId, this.date});
  final String? serviceId;
  final DateTime? date;
  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
    onPressed: () => startBooking(context, ref, photographerId: 'p1', serviceId: serviceId, date: date),
    child: const Text('đặt'),
  );
}

Future<Widget> _app(DiscoveryWorld w, {String? serviceId, DateTime? date}) async {
  await w.init();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: _Button(serviceId: serviceId, date: date))),
      GoRoute(path: '/u/:id/book', builder: (_, s) => Text('book ${s.uri}')),
      GoRoute(path: '/profile/phone', builder: (_, s) => Text('phone ${s.uri.queryParameters['returnTo']}')),
    ],
  );
  return screenRouterApp(router: router, overrides: w.overrides);
}

void main() {
  test('bookingPath carries the service and the day', () {
    expect(bookingPath(photographerId: 'p1'), '/u/p1/book');
    expect(bookingPath(photographerId: 'p1', serviceId: 's1'), '/u/p1/book?serviceId=s1');
    expect(
      bookingPath(photographerId: 'p1', serviceId: 's1', date: DateTime.utc(2026, 10, 12)),
      '/u/p1/book?serviceId=s1&date=2026-10-12',
    );
    expect(bookingPath(photographerId: 'p1', date: DateTime(2026, 1, 5)), '/u/p1/book?date=2026-01-05');
  });

  testWidgets('with a phone number the booking opens straight away', (tester) async {
    await tester.pumpWidget(await _app(DiscoveryWorld(), serviceId: 's1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('đặt'));
    await tester.pumpAndSettle();
    expect(find.text('book /u/p1/book?serviceId=s1'), findsOneWidget);
  });

  testWidgets('without a phone number S33 comes first, with the booking as returnTo', (tester) async {
    await tester.pumpWidget(
      await _app(DiscoveryWorld(hasPhone: false), serviceId: 's1', date: DateTime.utc(2026, 10, 12)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('đặt'));
    await tester.pumpAndSettle();
    expect(find.text('phone /u/p1/book?serviceId=s1&date=2026-10-12'), findsOneWidget);
  });
}
```

```dart
// test/features/discovery/photographer_meta_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/features/discovery/photographer_meta.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

import '../../support/content_fixtures.dart';

void main() {
  final l = AppLocalizationsVi();

  test('area, rating with count and sessions, joined by dots', () {
    expect(areaRatingMeta(fixturePhotographer('p1', areaLabel: 'Quận 3'), l), 'Quận 3 · ★ 4,9 (58) · 112 buổi');
  });

  test('missing parts are left out', () {
    const bare = PhotographerSummary(id: 'x', displayName: 'Mới');
    expect(areaRatingMeta(bare, l), '');
    expect(areaRatingMeta(fixturePhotographer('p', areaLabel: null, reviews: 0, completed: 0), l), '');
    expect(areaRatingMeta(fixturePhotographer('p', areaLabel: 'Quận 1', reviews: 0, completed: 5), l), 'Quận 1 · 5 buổi');
  });

  group('freeThisWeekLabel (today is Thursday 1 Oct 2026, Vietnam time)', () {
    String? label(String? day) =>
        freeThisWeekLabel(fixturePhotographer('p', nextFreeDate: day), fixtureNow, l);

    test('free within the next 7 days names the weekday', () {
      expect(label('2026-10-03'), 'Rảnh T7 này');
      expect(label('2026-10-04'), 'Rảnh CN này');
      expect(label('2026-10-01'), 'Rảnh T5 này', reason: 'today counts');
    });

    test('later, past or unknown days give no pill', () {
      expect(label('2026-10-08'), isNull);
      expect(label('2026-09-30'), isNull);
      expect(label(null), isNull);
      expect(label('not-a-day'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/discovery`
Expected: FAIL (the three libraries and `homePillFree` do not exist).

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb` (comma after the previous last entry), then `flutter gen-l10n`:

```json
  "homePillFree": "Rảnh {day} này",
  "@homePillFree": {
    "placeholders": {
      "day": {"type": "String"}
    }
  },
  "engagementError": "Chưa thực hiện được. Thử lại nhé.",
  "back": "Quay lại"
```

```dart
// lib/features/discovery/engagement_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/post_summary.dart';

@immutable
class EngagementView {
  const EngagementView({
    this.liked = false,
    this.saved = false,
    this.likeCount = 0,
    this.saveCount = 0,
  });

  final bool liked;
  final bool saved;
  final int likeCount;
  final int saveCount;

  EngagementView copyWith({
    bool? liked,
    bool? saved,
    int? likeCount,
    int? saveCount,
  }) => EngagementView(
    liked: liked ?? this.liked,
    saved: saved ?? this.saved,
    likeCount: likeCount ?? this.likeCount,
    saveCount: saveCount ?? this.saveCount,
  );
}

int _plusMinus(int count, bool on) => on ? count + 1 : (count > 0 ? count - 1 : 0);

/// The viewer's likes and saves, keyed by post id, with optimistic updates.
/// Counts shown are the post's server count plus the viewer's own change.
class EngagementController extends Notifier<Map<String, EngagementView>> {
  final _busy = <String>{};

  @override
  Map<String, EngagementView> build() => const {};

  String? get _uid => ref.read(authRepositoryProvider).currentUser?.uid;
  PostEngagementRepository get _repo => ref.read(postEngagementRepositoryProvider);

  /// Registers counts for [posts] and fetches the viewer's saved marks for the
  /// whole list in one batch. A failed batch only leaves the bookmarks empty.
  Future<void> seed(Iterable<PostSummary> posts) async {
    final list = posts.toList();
    final next = Map.of(state);
    for (final p in list) {
      next.putIfAbsent(
        p.id,
        () => EngagementView(likeCount: p.likeCount, saveCount: p.saveCount),
      );
    }
    state = next;
    final uid = _uid;
    if (uid == null || list.isEmpty) {
      return;
    }
    try {
      final saved = await _repo.savedAmong(uid, list.map((p) => p.id));
      if (!ref.mounted) {
        return;
      }
      final updated = Map.of(state);
      for (final p in list) {
        final v = updated[p.id];
        if (v != null) {
          updated[p.id] = v.copyWith(saved: saved.contains(p.id));
        }
      }
      state = updated;
    } catch (_) {
      // Bookmarks are a nicety; the feed works without them.
    }
  }

  /// Counts, liked and saved for a single post (the detail screen).
  Future<void> load(PostSummary post) async {
    final next = Map.of(state);
    next.putIfAbsent(
      post.id,
      () => EngagementView(likeCount: post.likeCount, saveCount: post.saveCount),
    );
    state = next;
    final uid = _uid;
    if (uid == null) {
      return;
    }
    try {
      final e = await _repo.engagementFor(uid, post.id);
      if (!ref.mounted) {
        return;
      }
      state = {
        ...state,
        post.id: state[post.id]!.copyWith(liked: e.liked, saved: e.saved),
      };
    } catch (_) {
      // Keep the counts; the buttons start in the "off" state.
    }
  }

  Future<bool> toggleLike(String postId) => _toggle(postId, like: true);
  Future<bool> toggleSave(String postId) => _toggle(postId, like: false);

  Future<bool> _toggle(String postId, {required bool like}) async {
    final uid = _uid;
    final before = state[postId];
    if (uid == null || before == null) {
      return false;
    }
    final key = '${like ? 'like' : 'save'}:$postId';
    if (!_busy.add(key)) {
      return true;
    }
    final want = like ? !before.liked : !before.saved;
    state = {
      ...state,
      postId: like
          ? before.copyWith(liked: want, likeCount: _plusMinus(before.likeCount, want))
          : before.copyWith(saved: want, saveCount: _plusMinus(before.saveCount, want)),
    };
    try {
      if (like) {
        await _repo.setLiked(uid, postId, want);
      } else {
        await _repo.setSaved(uid, postId, want);
      }
      return true;
    } catch (_) {
      if (ref.mounted) {
        final now = state[postId] ?? before;
        state = {
          ...state,
          postId: like
              ? now.copyWith(liked: before.liked, likeCount: before.likeCount)
              : now.copyWith(saved: before.saved, saveCount: before.saveCount),
        };
      }
      return false;
    } finally {
      _busy.remove(key);
    }
  }
}

final engagementProvider =
    NotifierProvider<EngagementController, Map<String, EngagementView>>(
      EngagementController.new,
    );

/// Whether the viewer follows a photographer, with optimistic toggling.
class FollowController extends Notifier<Map<String, bool>> {
  final _busy = <String>{};

  @override
  Map<String, bool> build() => const {};

  String? get _uid => ref.read(authRepositoryProvider).currentUser?.uid;

  Future<void> load(String photographerId) async {
    final uid = _uid;
    if (uid == null) {
      return;
    }
    try {
      final following = await ref
          .read(postEngagementRepositoryProvider)
          .isFollowing(uid, photographerId);
      if (ref.mounted) {
        state = {...state, photographerId: following};
      }
    } catch (_) {
      // Shown as "not following" until a tap says otherwise.
    }
  }

  Future<bool> toggle(String photographerId) async {
    final uid = _uid;
    if (uid == null || !_busy.add(photographerId)) {
      return uid != null;
    }
    final before = state[photographerId] ?? false;
    state = {...state, photographerId: !before};
    try {
      await ref
          .read(postEngagementRepositoryProvider)
          .setFollowing(uid, photographerId, !before);
      return true;
    } catch (_) {
      if (ref.mounted) {
        state = {...state, photographerId: before};
      }
      return false;
    } finally {
      _busy.remove(photographerId);
    }
  }
}

final followProvider = NotifierProvider<FollowController, Map<String, bool>>(
  FollowController.new,
);
```

```dart
// lib/features/discovery/book_entry.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/user/user_contact_providers.dart';

/// `/u/<photographer>/book?serviceId=…&date=yyyy-MM-dd`. The booking screens
/// (step 4) read these two parameters; both are optional.
String bookingPath({
  required String photographerId,
  String? serviceId,
  DateTime? date,
}) {
  final query = {
    if (serviceId != null) 'serviceId': serviceId,
    if (date != null) 'date': dayKeyOf(date),
  };
  return Uri(
    path: '/u/$photographerId/book',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

/// Starts a booking from S02, S03 or S04. A customer without a phone number
/// is sent to S33 first and comes back to the booking (spec 3b.1); reading the
/// contact fails closed, so a failure also goes through S33.
Future<void> startBooking(
  BuildContext context,
  WidgetRef ref, {
  required String photographerId,
  String? serviceId,
  DateTime? date,
}) async {
  final path = bookingPath(
    photographerId: photographerId,
    serviceId: serviceId,
    date: date,
  );
  Object? contact;
  try {
    contact = await ref.read(currentContactProvider.future);
  } catch (_) {
    contact = null;
  }
  if (!context.mounted) {
    return;
  }
  if (contact == null) {
    context.push('/profile/phone?returnTo=${Uri.encodeComponent(path)}');
  } else {
    context.push(path);
  }
}
```

```dart
// lib/features/discovery/photographer_meta.dart
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/l10n/app_localizations.dart';

/// "Quận 3 · ★ 4,9 (58) · 112 buổi": only the parts that exist.
String areaRatingMeta(PhotographerSummary p, AppLocalizations l) => [
  if (p.areaLabel != null && p.areaLabel!.isNotEmpty) p.areaLabel!,
  if (p.hasRating) '★ ${formatRating(p.ratingAvg)} (${p.reviewCount})',
  if (p.completedCount > 0) l.photographerSessions(p.completedCount),
].join(' · ');

/// "Rảnh T7 này" when the next free day is within the next 7 Vietnamese days.
String? freeThisWeekLabel(
  PhotographerSummary p,
  DateTime now,
  AppLocalizations l,
) {
  final key = p.nextFreeDate;
  final day = p.nextFreeDay;
  if (key == null || day == null) {
    return null;
  }
  final inWindow =
      key.compareTo(vnDateKey(now)) >= 0 &&
      key.compareTo(vnDateKey(now.add(const Duration(days: 7)))) < 0;
  return inWindow ? l.homePillFree(weekdayLabel(day.weekday)) : null;
}
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/features/discovery && flutter analyze`
Expected: PASS (engagement 10, booking 3, meta 4); analyze clean. `startBooking`'s `currentContactProvider` and the `/profile/phone` route come from plan 2a.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/discovery lib/l10n test/support/discovery_world.dart test/features/discovery
git commit -m "feat(discovery): optimistic engagement, booking entry with phone gate, shared helpers

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: S01 Home

**Files:**
- Create: `lib/features/home/home_controller.dart`, `lib/features/home/home_screen.dart`, `test/features/home/home_controller_test.dart`, `test/features/home/home_screen_test.dart`
- Modify: `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `recommendationRepositoryProvider` (`recommendPosts`), `engagementProvider`, `freeThisWeek`/`feed` of the content repositories, `exploreResolutionProvider` (its `origin.geohash6`, read once per load, never watched), `PhotoCard`, `PhotoPill`, `AppAvatar`, `VerifiedName`, `ReasonChips`, `AppChip`, `AppSkeleton`, `ErrorState`, `EmptyState`, `areaRatingMeta`, `freeThisWeekLabel`, `specialtyLabel`, `formatMoney`.
- Produces:
  - `class HomeFeedState { String? category; List<RecommendedPost> items; String? cursor; bool loadingMore; copyWith }`; `class HomeFeedController extends AsyncNotifier<HomeFeedState>` with `Future<void> selectCategory(String? specialtyId)` (shows the skeleton, reloads), `refresh()` (keeps the old feed if the reload fails), `loadMore()` (appends; a failure only stops the spinner); `homeFeedProvider`. Page size 20 (spec).
  - `freeThisWeekProvider` (`FutureProvider.autoDispose<List<PhotographerSummary>>`), `class FeedPost { post, photographer }`, `realShootsProvider` (`FutureProvider.autoDispose<List<FeedPost>>`, six newest customer posts with their photographer).
  - `HomeScreen({super.key})` wrapped in `ScreenCode(ScreenCodes.home)`. Keys: `home-chip-all`, `home-chip-<specialty>`, `post-<id>` (large card), `save-<id>`, `author-<id>` (the name row under a card), `free-<photographerId>`, `real-<postId>`.
  - l10n: `homeGreeting(name)` "Chào {name}", `homeTitle` "Hôm nay chụp gì?", `homeForYou` "Dành cho bạn", `homeFreeThisWeek` "Rảnh tuần này", `homeRealShoots` "Buổi chụp thật", `homeFromCustomers` "Từ khách hàng", `homeRealShootBy(name)` "Chụp bởi {name}", `homeEmptyTitle`, `homeEmptyBody`, `homeEmptyAction`, `homeLoadError`, `photoSave` "Lưu ảnh", `photoUnsave` "Bỏ lưu".

Layout (top to bottom): greeting and title; category chips (`Dành cho bạn`, `Chân dung`, `Cưới`, `Gia đình`, `Kỷ yếu`; context style); the first post as a 4:5 `PhotoCard` (green "Rảnh T7 này" pill when the photographer is free within a week, "Chân dung · từ 1,5M" pill, a save button, tap opens S02), under it a tappable name row (opens S03) and up to two reason chips; "Rảnh tuần này" as a horizontal row of 120dp 3:4 cards (tap opens S03; "Xem tất cả" opens S04 for customers); "Buổi chụp thật" as a two-column grid of customer photos (tap opens S02); then the remaining posts as large cards, two columns from 600dp, loading the next page when the end is near. Each chip keeps its own scroll position. Pull down refreshes. The bell and chat icons of the mock are not built (no notification or chat list exists yet).

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/home/home_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/home/home_controller.dart';

import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';

class _Spy extends DelegatingRecommender {
  _Spy(super.inner);
  final List<PostRecommendationQuery> queries = [];
  @override
  Future<PostRecommendationPage> recommendPosts(PostRecommendationQuery q) {
    queries.add(q);
    return super.recommendPosts(q);
  }
}

Future<(ProviderContainer, DiscoveryWorld, _Spy)> _make({DiscoveryWorld? world}) async {
  _Spy? spy;
  final use = world ??
      DiscoveryWorld(recommenderFactory: (x) => spy = _Spy(x.localRecommender()));
  await use.init();
  final c = ProviderContainer(overrides: use.overrides);
  addTearDown(c.dispose);
  return (c, use, spy ?? _Spy(use.recommender));
}

void main() {
  test('the first page is the recommender\'s order and seeds engagement', () async {
    final (c, _, spy) = await _make();
    final s = await c.read(homeFeedProvider.future);
    expect(s.category, isNull);
    expect(s.items.map((e) => e.post.id), ['a', 'b', 'c', 'e', 'd']);
    expect(spy.queries.single.limit, 20);
    expect(spy.queries.single.specialtyId, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(engagementProvider).keys, containsAll(['a', 'b']));
    expect(c.read(engagementProvider)['a']!.likeCount, 214);
  });

  test('selecting a category reloads with that specialty', () async {
    final (c, _, spy) = await _make();
    await c.read(homeFeedProvider.future);
    await c.read(homeFeedProvider.notifier).selectCategory('wedding');
    final s = c.read(homeFeedProvider).requireValue;
    expect(s.category, 'wedding');
    expect(s.items.map((e) => e.post.id), ['b']);
    expect(spy.queries.last.specialtyId, 'wedding');
    await c.read(homeFeedProvider.notifier).selectCategory(null);
    expect(c.read(homeFeedProvider).requireValue.items, hasLength(5));
  });

  test('loadMore appends the next page once and stops at the end', () async {
    final many = DiscoveryWorld(
      posts: [for (var i = 0; i < 45; i++) fixturePost('m$i', photographerId: 'p1', age: Duration(minutes: i + 1), specialtyId: 'portrait')],
    );
    final (c, _, _) = await _make(world: many);
    final n = c.read(homeFeedProvider.notifier);
    var s = await c.read(homeFeedProvider.future);
    expect(s.items, hasLength(20));
    expect(s.cursor, isNotNull);
    await Future.wait([n.loadMore(), n.loadMore()]);
    s = c.read(homeFeedProvider).requireValue;
    expect(s.items, hasLength(40), reason: 'two taps at once load one page');
    await n.loadMore();
    s = c.read(homeFeedProvider).requireValue;
    expect(s.items, hasLength(45));
    expect(s.cursor, isNull);
    expect(s.loadingMore, isFalse);
    await n.loadMore();
    expect(c.read(homeFeedProvider).requireValue.items, hasLength(45));
  });

  test('a failed loadMore keeps the feed and the cursor for a retry', () async {
    final many = DiscoveryWorld(
      posts: [for (var i = 0; i < 30; i++) fixturePost('m$i', photographerId: 'p1', age: Duration(minutes: i + 1))],
    );
    final (c, w, _) = await _make(world: many);
    await c.read(homeFeedProvider.future);
    w.posts.failWith = StateError('offline');
    await c.read(homeFeedProvider.notifier).loadMore();
    final s = c.read(homeFeedProvider).requireValue;
    expect(s.items, hasLength(20));
    expect(s.cursor, isNotNull);
    expect(s.loadingMore, isFalse);
  });

  test('refresh reloads, and keeps the old feed when the reload fails', () async {
    final (c, w, _) = await _make();
    await c.read(homeFeedProvider.future);
    w.posts.add(fixturePost('new', photographerId: 'p1', age: const Duration(seconds: 1)));
    await c.read(homeFeedProvider.notifier).refresh();
    expect(c.read(homeFeedProvider).requireValue.items.first.post.id, 'new');
    w.posts.failWith = StateError('offline');
    await c.read(homeFeedProvider.notifier).refresh();
    expect(c.read(homeFeedProvider).requireValue.items.first.post.id, 'new');
  });

  test('a failing first load is an error state', () async {
    final w = DiscoveryWorld();
    w.posts.failWith = StateError('offline');
    final (c, _, _) = await _make(world: w);
    await expectLater(c.read(homeFeedProvider.future), throwsStateError);
  });

  test('free this week lists photographers free in the next 7 days, soonest first', () async {
    final (c, _, _) = await _make();
    final list = await c.read(freeThisWeekProvider.future);
    expect(list.map((p) => p.id), ['p2', 'p1', 'p3']);
  });

  test('real shoots are customer posts with their photographer', () async {
    final (c, _, _) = await _make();
    final list = await c.read(realShootsProvider.future);
    expect(list.map((f) => f.post.id), ['r1', 'r2']);
    expect(list.map((f) => f.photographer.displayName), ['Minh Trí', 'Hồng Nhung']);
  });
}
```

The spy needs a delegating base class; add it to `test/support/discovery_world.dart`:

```dart
/// Forwards to [inner]; tests subclass it to spy on one method.
class DelegatingRecommender implements RecommendationRepository {
  DelegatingRecommender(this.inner);
  final RecommendationRepository inner;
  @override
  Future<RecommendationPage> recommendPhotographers(RecommendationQuery query) =>
      inner.recommendPhotographers(query);
  @override
  Future<RecommendationPage> similar(String photographerId, {int limit = 8}) =>
      inner.similar(photographerId, limit: limit);
  @override
  Future<PostRecommendationPage> recommendPosts(PostRecommendationQuery query) =>
      inner.recommendPosts(query);
  @override
  Future<void> sendFeedback(List<RecommendationSignal> signals) =>
      inner.sendFeedback(signals);
}
```

```dart
// test/features/home/home_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/recommendation/resilient_recommendation_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/home/home_screen.dart';

import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';
import '../../support/screen_host.dart';

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/p/:id', builder: (_, s) => Text('post ${s.pathParameters['id']}')),
    GoRoute(path: '/u/:id', builder: (_, s) => Text('profile ${s.pathParameters['id']}')),
    GoRoute(path: '/action', builder: (_, _) => const Text('find')),
    GoRoute(path: '/explore', builder: (_, _) => const Text('explore')),
  ],
);

Future<Widget> _app(DiscoveryWorld w, {double textScale = 1, GoRouter? router}) async {
  await w.init();
  return screenRouterApp(
    router: router ?? _router(),
    overrides: w.overrides,
    textScale: textScale,
  );
}

Future<void> _pump(WidgetTester tester, DiscoveryWorld w, {double textScale = 1}) async {
  await tester.pumpWidget(await _app(w, textScale: textScale));
  await tester.pumpAndSettle();
}

double _left(WidgetTester t, Key k) => t.getTopLeft(find.byKey(k)).dx;

void main() {
  testWidgets('header, chips and the first post with its pills, name row and save button', (
    tester,
  ) async {
    await _pump(tester, DiscoveryWorld());
    expect(find.text('Chào Lan Anh'), findsOneWidget);
    expect(find.text('Hôm nay chụp gì?'), findsOneWidget);
    for (final label in ['Dành cho bạn', 'Chân dung', 'Cưới', 'Gia đình', 'Kỷ yếu']) {
      expect(find.text(label), findsOneWidget);
    }
    final card = find.byKey(const Key('post-a'));
    expect(card, findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Rảnh T7 này')), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Chân dung · từ 1,5M')), findsOneWidget);
    final author = find.byKey(const Key('author-a'));
    expect(find.descendant(of: author, matching: find.textContaining('Minh Trí', findRichText: true)), findsOneWidget);
    expect(find.descendant(of: author, matching: find.text('Quận 3 · ★ 4,9 (58) · 112 buổi')), findsOneWidget);
    expect(find.byType(VerifiedMark), findsWidgets);
    expect(find.byKey(const Key('save-a')), findsOneWidget);
  });

  testWidgets('reasons appear under the large card, at most two', (tester) async {
    await _pump(tester, DiscoveryWorld());
    expect(find.text('Rảnh T7 03/10'), findsWidgets);
  });

  testWidgets('"Rảnh tuần này" lists the free photographers, soonest first', (tester) async {
    await _pump(tester, DiscoveryWorld());
    expect(find.text('Rảnh tuần này'), findsOneWidget);
    expect(_left(tester, const Key('free-p2')), lessThan(_left(tester, const Key('free-p1'))));
    expect(_left(tester, const Key('free-p1')), lessThan(_left(tester, const Key('free-p3'))));
  });

  testWidgets('"Buổi chụp thật" shows the customers\' photos with the photographer', (
    tester,
  ) async {
    await _pump(tester, DiscoveryWorld());
    await tester.scrollUntilVisible(find.byKey(const Key('real-r1')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Buổi chụp thật'), findsOneWidget);
    expect(find.text('Từ khách hàng'), findsOneWidget);
    expect(find.text('Chụp bởi Minh Trí'), findsOneWidget);
  });

  testWidgets('taps: card to S02, name row to S03, small card to S03, "Xem tất cả" to S04', (
    tester,
  ) async {
    final w = DiscoveryWorld();
    final router = _router();
    await tester.pumpWidget(await _app(w, router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('post-a')));
    await tester.pumpAndSettle();
    expect(find.text('post a'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('author-a')));
    await tester.pumpAndSettle();
    expect(find.text('profile p1'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('free-p2')));
    await tester.pumpAndSettle();
    expect(find.text('profile p2'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xem tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('find'), findsOneWidget);
  });

  testWidgets('a photographer has no "Xem tất cả" (their middle tab is not Find)', (
    tester,
  ) async {
    await _pump(tester, DiscoveryWorld(role: UserRole.photographer));
    expect(find.text('Rảnh tuần này'), findsOneWidget);
    expect(find.text('Xem tất cả'), findsNothing);
  });

  testWidgets('saving is instant, undoable, and a failure says so', (tester) async {
    final w = DiscoveryWorld();
    await _pump(tester, w);
    expect(find.descendant(of: find.byKey(const Key('save-a')), matching: find.byIcon(Icons.bookmark_border)), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-a')));
    await tester.pump();
    expect(find.descendant(of: find.byKey(const Key('save-a')), matching: find.byIcon(Icons.bookmark)), findsOneWidget,
        reason: 'shown before the write finishes');
    await tester.pumpAndSettle();
    expect(w.engagement.writeCalls, 1);

    w.engagement.failWith = StateError('offline');
    await tester.tap(find.byKey(const Key('save-a')));
    await tester.pumpAndSettle();
    expect(find.text('Chưa thực hiện được. Thử lại nhé.'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('save-a')), matching: find.byIcon(Icons.bookmark)), findsOneWidget,
        reason: 'back to saved after the failed undo');
  });

  testWidgets('a category chip reloads the feed for that specialty and back', (tester) async {
    await _pump(tester, DiscoveryWorld());
    await tester.tap(find.byKey(const Key('home-chip-wedding')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-b')), findsOneWidget);
    expect(find.byKey(const Key('post-a')), findsNothing);
    await tester.tap(find.byKey(const Key('home-chip-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-a')), findsOneWidget);
  });

  testWidgets('an empty feed offers the way to Explore', (tester) async {
    final w = DiscoveryWorld(posts: const []);
    final router = _router();
    await tester.pumpWidget(await _app(w, router: router));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có ảnh nào quanh bạn'), findsOneWidget);
    await tester.tap(find.text('Khám phá nhiếp ảnh gia'));
    await tester.pumpAndSettle();
    expect(find.text('explore'), findsOneWidget);
  });

  testWidgets('an error shows the retry, which reloads', (tester) async {
    final w = DiscoveryWorld();
    w.posts.failWith = StateError('offline');
    await _pump(tester, w);
    expect(find.text('Không tải được ảnh. Kiểm tra mạng rồi thử lại.'), findsOneWidget);
    w.posts.failWith = null;
    await tester.tap(find.byKey(const Key('error-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-a')), findsOneWidget);
  });

  testWidgets('scrolling near the end loads the next page', (tester) async {
    final w = DiscoveryWorld(
      posts: [for (var i = 0; i < 45; i++) fixturePost('m${i.toString().padLeft(2, '0')}', photographerId: 'p1', age: Duration(minutes: i + 1), specialtyId: 'portrait')],
    );
    await _pump(tester, w);
    await tester.scrollUntilVisible(
      find.byKey(const Key('post-m44')),
      600,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 200,
    );
    expect(find.byKey(const Key('post-m44')), findsOneWidget);
  });

  testWidgets('each chip remembers its own scroll position', (tester) async {
    final w = DiscoveryWorld(
      posts: [for (var i = 0; i < 40; i++) fixturePost('m${i.toString().padLeft(2, '0')}', photographerId: 'p1', age: Duration(minutes: i + 1), specialtyId: 'portrait')],
    );
    await _pump(tester, w);
    double offset() => tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final saved = offset();
    expect(saved, greaterThan(500));
    await tester.tap(find.byKey(const Key('home-chip-portrait')));
    await tester.pumpAndSettle();
    expect(offset(), lessThan(saved), reason: 'the other chip starts at the top');
    await tester.tap(find.byKey(const Key('home-chip-all')));
    await tester.pumpAndSettle();
    expect(offset(), closeTo(saved, 40));
  });

  testWidgets('pull down reloads the feed', (tester) async {
    final w = DiscoveryWorld();
    await _pump(tester, w);
    w.posts.add(fixturePost('fresh', photographerId: 'p1', age: const Duration(seconds: 1), specialtyId: 'portrait'));
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-fresh')), findsOneWidget);
  });

  testWidgets('the local-fallback ranking is used silently when the remote one is down', (
    tester,
  ) async {
    final w = DiscoveryWorld(
      recommenderFactory: (x) => ResilientRecommendationRepository(
        primary: ThrowingRecommender(),
        fallback: x.localRecommender(),
      ),
    );
    await _pump(tester, w);
    expect(find.byKey(const Key('post-a')), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320x640 at 1.3x on ${b.name} with no blur', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final w = DiscoveryWorld();
      await w.init();
      await tester.pumpWidget(
        screenApp(
          home: const HomeScreen(),
          overrides: w.overrides,
          textScale: 1.3,
          brightness: b,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  }

  testWidgets('from 600dp the posts below the first card use two columns', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, DiscoveryWorld());
    await tester.scrollUntilVisible(find.byKey(const Key('post-c')), 300, scrollable: find.byType(Scrollable).first);
    final b = tester.getTopLeft(find.byKey(const Key('post-b')));
    final c = tester.getTopLeft(find.byKey(const Key('post-c')));
    expect(b.dy, c.dy);
    expect(c.dx, greaterThan(b.dx));
  });
}
```

The fallback test needs a recommender that always fails; add to `test/support/discovery_world.dart`:

```dart
/// Stands in for a remote recommender that is down.
class ThrowingRecommender implements RecommendationRepository {
  @override
  Future<RecommendationPage> recommendPhotographers(RecommendationQuery query) async =>
      throw StateError('down');
  @override
  Future<RecommendationPage> similar(String photographerId, {int limit = 8}) async =>
      throw StateError('down');
  @override
  Future<PostRecommendationPage> recommendPosts(PostRecommendationQuery query) async =>
      throw StateError('down');
  @override
  Future<void> sendFeedback(List<RecommendationSignal> signals) async =>
      throw StateError('down');
}
```

(`PostSummary`/`PostKind` imports in the screen test are used by fixtures only through `fixturePost`; remove unused imports if the analyzer reports them.)

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/features/home`
Expected: FAIL (`home_controller.dart`, `home_screen.dart`, the helper classes and the strings do not exist).

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb` (comma after the previous last entry), then `flutter gen-l10n`:

```json
  "homeGreeting": "Chào {name}",
  "@homeGreeting": {
    "placeholders": {
      "name": {"type": "String"}
    }
  },
  "homeTitle": "Hôm nay chụp gì?",
  "homeForYou": "Dành cho bạn",
  "homeFreeThisWeek": "Rảnh tuần này",
  "homeRealShoots": "Buổi chụp thật",
  "homeFromCustomers": "Từ khách hàng",
  "homeRealShootBy": "Chụp bởi {name}",
  "@homeRealShootBy": {
    "placeholders": {
      "name": {"type": "String"}
    }
  },
  "homeEmptyTitle": "Chưa có ảnh nào quanh bạn",
  "homeEmptyBody": "Khám phá nhiếp ảnh gia để thấy ảnh đẹp ở đây.",
  "homeEmptyAction": "Khám phá nhiếp ảnh gia",
  "homeLoadError": "Không tải được ảnh. Kiểm tra mạng rồi thử lại.",
  "photoSave": "Lưu ảnh",
  "photoUnsave": "Bỏ lưu"
```

```dart
// lib/features/home/home_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/explore/location_controller.dart';

@immutable
class HomeFeedState {
  const HomeFeedState({
    this.category,
    this.items = const [],
    this.cursor,
    this.loadingMore = false,
  });

  /// Specialty code of the chip, or null for "Dành cho bạn".
  final String? category;
  final List<RecommendedPost> items;
  final String? cursor;
  final bool loadingMore;

  HomeFeedState copyWith({
    List<RecommendedPost>? items,
    String? cursor,
    bool clearCursor = false,
    bool? loadingMore,
  }) => HomeFeedState(
    category: category,
    items: items ?? this.items,
    cursor: clearCursor ? null : (cursor ?? this.cursor),
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

class HomeFeedController extends AsyncNotifier<HomeFeedState> {
  static const pageSize = 20;

  RecommendationRepository get _recommender =>
      ref.read(recommendationRepositoryProvider);

  /// The cell of an already known position or saved area. Home never asks for
  /// location; it only uses what Explore has.
  String? get _geohash6 => ref.read(exploreResolutionProvider).origin?.geohash6;

  @override
  Future<HomeFeedState> build() => _loadFirst(null);

  Future<HomeFeedState> _loadFirst(String? category) async {
    final page = await _recommender.recommendPosts(
      PostRecommendationQuery(
        specialtyId: category,
        geohash6: _geohash6,
        limit: pageSize,
      ),
    );
    unawaited(ref.read(engagementProvider.notifier).seed(page.items.map((e) => e.post)));
    return HomeFeedState(
      category: category,
      items: page.items,
      cursor: page.nextCursor,
    );
  }

  Future<void> selectCategory(String? category) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadFirst(category));
  }

  /// Pull to refresh: the old feed stays if the reload fails.
  Future<void> refresh() async {
    final next = await AsyncValue.guard(() => _loadFirst(state.value?.category));
    if (ref.mounted && next.hasValue) {
      state = next;
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.cursor == null || current.loadingMore) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await _recommender.recommendPosts(
        PostRecommendationQuery(
          specialtyId: current.category,
          geohash6: _geohash6,
          limit: pageSize,
          cursor: current.cursor,
        ),
      );
      if (!ref.mounted) {
        return;
      }
      unawaited(ref.read(engagementProvider.notifier).seed(page.items.map((e) => e.post)));
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          items: [...latest.items, ...page.items],
          cursor: page.nextCursor,
          clearCursor: page.nextCursor == null,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData((state.value ?? current).copyWith(loadingMore: false));
      }
    }
  }
}

final homeFeedProvider =
    AsyncNotifierProvider<HomeFeedController, HomeFeedState>(
      HomeFeedController.new,
    );

/// "Rảnh tuần này": photographers whose next free day is within a week.
final freeThisWeekProvider =
    FutureProvider.autoDispose<List<PhotographerSummary>>(
      (ref) => ref
          .watch(photographerRepositoryProvider)
          .freeThisWeek(now: ref.watch(clockProvider)()),
    );

@immutable
class FeedPost {
  const FeedPost(this.post, this.photographer);
  final PostSummary post;
  final PhotographerSummary photographer;
}

/// "Buổi chụp thật": the newest photos customers shared after a shoot.
final realShootsProvider = FutureProvider.autoDispose<List<FeedPost>>((ref) async {
  final page = await ref
      .watch(postRepositoryProvider)
      .feed(kind: PostKind.realShoot, limit: 6);
  final authors = await ref
      .watch(photographerRepositoryProvider)
      .summaries(page.posts.map((p) => p.photographerId));
  return [
    for (final p in page.posts)
      if (authors[p.photographerId] != null) FeedPost(p, authors[p.photographerId]!),
  ];
});
```

```dart
// lib/features/home/home_screen.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/discovery/photographer_meta.dart';
import 'package:photobooking/features/home/home_controller.dart';

const _chipSpecialties = ['portrait', 'wedding', 'family', 'graduation'];

/// S01. Photos first: the large card, who is free this week, real shoots.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  final _offsets = <String?, double>{};
  String? _selected;
  double? _restoreTo;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 600) {
      ref.read(homeFeedProvider.notifier).loadMore();
    }
  }

  Future<void> _select(String? category) async {
    if (category == _selected) {
      return;
    }
    if (_scroll.hasClients) {
      _offsets[_selected] = _scroll.offset;
    }
    setState(() => _selected = category);
    _restoreTo = _offsets[category] ?? 0.0;
    await ref.read(homeFeedProvider.notifier).selectCategory(category);
    final target = _restoreTo;
    _restoreTo = null;
    if (target == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(
          math.min(_scroll.position.maxScrollExtent, math.max(0.0, target)),
        );
      }
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(freeThisWeekProvider);
    ref.invalidate(realShootsProvider);
    await ref.read(homeFeedProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final feed = ref.watch(homeFeedProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final customer = profile?.role != UserRole.photographer;

    List<Widget> body() {
      if (feed.isLoading) {
        return const [
          SliverPadding(
            padding: EdgeInsets.all(AppSpace.s4),
            sliver: SliverToBoxAdapter(child: AppSkeleton.card(height: 360)),
          ),
        ];
      }
      if (!feed.hasValue) {
        return [
          SliverToBoxAdapter(
            child: ErrorState(
              message: l.homeLoadError,
              onRetry: () =>
                  ref.read(homeFeedProvider.notifier).selectCategory(_selected),
            ),
          ),
        ];
      }
      final data = feed.requireValue;
      if (data.items.isEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              title: l.homeEmptyTitle,
              body: l.homeEmptyBody,
              actionLabel: l.homeEmptyAction,
              onAction: () => context.go(AppTab.explore.path),
            ),
          ),
        ];
      }
      final items = data.items;
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _PostBlock(item: items.first),
              ),
            ),
          ),
        ),
        _FreeThisWeekSection(customer: customer),
        const _RealShootsSection(),
        if (items.length > 1)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s5, AppSpace.s4, 0),
            sliver: SliverAdaptiveRows(
              itemCount: items.length - 1,
              itemBuilder: (_, i) => _PostBlock(item: items[i + 1]),
            ),
          ),
        if (data.loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpace.s4),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpace.s8)),
      ];
    }

    return ScreenCode(
      ScreenCodes.home,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s4,
                    AppSpace.s4,
                    AppSpace.s4,
                    AppSpace.s2,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.homeGreeting(profile?.displayName ?? ''),
                          style: theme.textTheme.bodySmall,
                        ),
                        Semantics(
                          header: true,
                          child: Text(l.homeTitle, style: theme.textTheme.headlineMedium),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                    child: Row(
                      children: [
                        AppChip(
                          key: const Key('home-chip-all'),
                          kind: AppChipKind.context,
                          label: l.homeForYou,
                          selected: _selected == null,
                          onChanged: (_) => _select(null),
                        ),
                        for (final id in _chipSpecialties) ...[
                          const SizedBox(width: AppSpace.s2),
                          AppChip(
                            key: Key('home-chip-$id'),
                            kind: AppChipKind.context,
                            label: specialtyLabel(id),
                            selected: _selected == id,
                            onChanged: (_) => _select(id),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: AppSpace.s2)),
                ...body(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s5, AppSpace.s4, AppSpace.s2),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A large post: photo with pills and a save button, the photographer's name
/// row, and the reasons it is recommended.
class _PostBlock extends ConsumerWidget {
  const _PostBlock({required this.item});
  final RecommendedPost item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final post = item.post;
    final p = item.photographer;
    final saved = ref.watch(
      engagementProvider.select((m) => m[post.id]?.saved ?? false),
    );
    final pill = freeThisWeekLabel(p, ref.watch(clockProvider)(), l);
    final specialty = post.specialtyId ?? (p.specialtyIds.isEmpty ? null : p.specialtyIds.first);
    final from = [
      if (specialty != null) specialtyLabel(specialty),
      ?priceFromLabel(p.startingPriceVnd, l),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhotoCard(
          key: Key('post-${post.id}'),
          imageUrl: post.cover.url,
          blurHash: post.cover.blurHash,
          aspect: 4 / 5,
          leadingPill: pill == null ? null : PhotoPill(label: pill, dot: true),
          trailingPill: from.isEmpty ? null : PhotoPill(label: from),
          action: IconButton(
            key: Key('save-${post.id}'),
            tooltip: saved ? l.photoUnsave : l.photoSave,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              foregroundColor: Colors.white,
            ),
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () async {
              final ok = await ref.read(engagementProvider.notifier).toggleSave(post.id);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(l.engagementError)));
              }
            },
          ),
          onTap: () => context.push('/p/${post.id}'),
        ),
        InkWell(
          key: Key('author-${post.id}'),
          onTap: () => context.push('/u/${p.id}'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s2),
              child: Row(
                children: [
                  AppAvatar(url: p.avatarUrl, name: p.displayName, size: AppAvatarSize.sm, decorative: true),
                  const SizedBox(width: AppSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        p.verified
                            ? VerifiedName(p.displayName, style: Theme.of(context).textTheme.titleMedium)
                            : Text(p.displayName, style: Theme.of(context).textTheme.titleMedium),
                        Text(areaRatingMeta(p, l), style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ReasonChips(reasons: item.reasons),
      ],
    );
  }
}

class _FreeThisWeekSection extends ConsumerWidget {
  const _FreeThisWeekSection({required this.customer});
  final bool customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ref.watch(freeThisWeekProvider).when(
      loading: () => const SliverToBoxAdapter(),
      error: (_, _) => const SliverToBoxAdapter(),
      data: (list) {
        final shown = list.where((p) => p.heroUrl != null).toList();
        if (shown.isEmpty) {
          return const SliverToBoxAdapter();
        }
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: _SectionTitle(
                title: l.homeFreeThisWeek,
                trailing: customer
                    ? TextButton(
                        onPressed: () => context.go(AppTab.action.path),
                        child: Text(l.exploreSeeAll),
                      )
                    : null,
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s2),
                  itemBuilder: (context, i) {
                    final p = shown[i];
                    final specialty = p.specialtyIds.isEmpty
                        ? null
                        : specialtyLabel(p.specialtyIds.first);
                    final from = [
                      ?specialty,
                      ?priceFromLabel(p.startingPriceVnd, l),
                    ].join(' · ');
                    return SizedBox(
                      width: 120,
                      child: PhotoCard(
                        key: Key('free-${p.id}'),
                        imageUrl: p.heroUrl!,
                        aspect: 3 / 4,
                        title: p.displayName,
                        subtitle: from.isEmpty ? null : from,
                        onTap: () => context.push('/u/${p.id}'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RealShootsSection extends ConsumerWidget {
  const _RealShootsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ref.watch(realShootsProvider).when(
      loading: () => const SliverToBoxAdapter(),
      error: (_, _) => const SliverToBoxAdapter(),
      data: (list) {
        if (list.isEmpty) {
          return const SliverToBoxAdapter();
        }
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: _SectionTitle(
                title: l.homeRealShoots,
                trailing: Text(l.homeFromCustomers, style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: AppSpace.s2,
                  crossAxisSpacing: AppSpace.s2,
                  childAspectRatio: 0.8,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final f = list[i];
                  return PhotoCard(
                    key: Key('real-${f.post.id}'),
                    imageUrl: f.post.cover.url,
                    aspect: 4 / 5,
                    title: l.homeRealShootBy(f.photographer.displayName),
                    onTap: () => context.push('/p/${f.post.id}'),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
```

(`?specialty` in the list is the null-aware element syntax of Dart 3.8; the repo pins Dart 3.13.)

- [ ] **Step 4: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/features/home && flutter analyze`
Expected: PASS (controller 8, screen 18); analyze clean. If the scroll-restore test is off by more than 40 px, the restore ran before the list had its full extent; wait one more frame (`await tester.pump()`) in the test only if the assertion `offset() < saved` already passed, otherwise fix `_select` to restore after the second frame. If `find.bySemanticsLabel('Lưu ảnh')` finds nothing, the IconButton `tooltip` is the label source; keep it.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/home lib/l10n test/features/home test/support/discovery_world.dart
git commit -m "feat(home): S01 Home with recommended posts, free this week and real shoots

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: S02 Photo detail

**Files:**
- Create: `lib/features/photo/photo_detail_controller.dart`, `lib/features/photo/photo_detail_screen.dart`, `test/features/photo/photo_detail_screen_test.dart`
- Modify: `lib/core/format.dart`, `test/core/format_test.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `postRepositoryProvider`, `photographerRepositoryProvider`, `serviceRepositoryProvider`, `engagementProvider`, `followProvider`, `startBooking`, `areaRatingMeta`, `NetworkPhoto`, `AppAvatar`, `VerifiedName`, `PhotoCard`, `AppButton`, `EmptyState`, `ErrorState`, `AppSkeleton`, `formatMoney`.
- Produces:
  - `String formatDuration(int minutes)` in `format.dart` → `45 phút`, `2 giờ`, `1 giờ 30 phút`.
  - `class PostDetail { PostSummary post; PhotographerSummary? photographer; ServiceSummary? service; List<PostSummary> more }` and `postDetailProvider` (`FutureProvider.autoDispose.family<PostDetail?, String>`): null when the post does not exist; a missing service or failed "more" query only leaves that part out; `more` is up to three other posts of the photographer.
  - `PhotoDetailScreen({super.key, required String postId})` wrapped in `ScreenCode(ScreenCodes.photoDetail)`. Keys: `photo-back`, `photo-gallery`, `like`, `save`, `follow`, `photo-profile`, `photo-book`, `service-card`, `more-<postId>`, `page-dot-<i>`.
  - l10n: `photoBook`, `photoViewProfile`, `photoFollow`, `photoFollowing`, `photoRealShootBy(name, service)`, `photoRemovedTitle`, `photoRemovedBody`, `photoBackHome`, `photoMoreOf(name)`, `photoMoreProfile`, `photoItemLabel(i)`, `photoOtherPackages`, `photoServiceInactive`, `photoLike`, `photoUnlike`, `photoPageOf(n, total)`, `photoLoadError`, `servicePhotos(n)`, `serviceDelivery(days)`.

Behaviour: the large 3:4 gallery pages through all images (dots when more than one; double tap likes, once); author row with name and tick, meta line and a follow button; caption; like and save with counts, location; the service card under the post (price, photos, delivery, duration; faded with "Gói này đã ngừng" when inactive); "Thêm của {tên}"; a fixed bottom bar with "Xem hồ sơ" and the one primary action: "Đặt gói này" (opens S33 first if the customer has no phone, then booking with the service chosen) or, when the package is gone, "Xem các gói khác" (S03, tab Gói). A removed post shows "Bài đăng không còn" and a way home. Share and report from the mock are not built (no link domain and no report backend yet).

- [ ] **Step 1: Write the failing tests**

Append to `test/core/format_test.dart` inside `main()`:

```dart
  test('formatDuration in hours and minutes', () {
    expect(formatDuration(45), '45 phút');
    expect(formatDuration(60), '1 giờ');
    expect(formatDuration(120), '2 giờ');
    expect(formatDuration(90), '1 giờ 30 phút');
    expect(formatDuration(480), '8 giờ');
  });
```

```dart
// test/features/photo/photo_detail_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/features/photo/photo_detail_screen.dart';

import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';
import '../../support/screen_host.dart';

GoRouter _router(String start) => GoRouter(
  initialLocation: start,
  routes: [
    GoRoute(path: '/home', builder: (_, _) => const Text('home')),
    GoRoute(path: '/p/:id', builder: (_, s) => PhotoDetailScreen(postId: s.pathParameters['id']!)),
    GoRoute(path: '/u/:id', builder: (_, s) => Text('profile ${s.pathParameters['id']} ${s.uri.query}')),
    GoRoute(path: '/u/:id/book', builder: (_, s) => Text('book ${s.uri}')),
    GoRoute(path: '/profile/phone', builder: (_, s) => Text('phone ${s.uri.queryParameters['returnTo']}')),
  ],
);

Future<GoRouter> _open(WidgetTester tester, DiscoveryWorld w, {String start = '/p/a', double textScale = 1}) async {
  await w.init();
  final router = _router(start);
  await tester.pumpWidget(screenRouterApp(router: router, overrides: w.overrides, textScale: textScale));
  await tester.pumpAndSettle();
  return router;
}

Finder _in(String key, Finder f) => find.descendant(of: find.byKey(Key(key)), matching: f);

void main() {
  testWidgets('shows the post, its author, counts, location and package', (tester) async {
    await _open(tester, DiscoveryWorld());
    expect(find.text('Chiều muộn ở bến Bạch Đằng #chandung'), findsOneWidget);
    expect(find.textContaining('Minh Trí', findRichText: true), findsWidgets);
    expect(find.byType(VerifiedMark), findsOneWidget);
    expect(find.text('Quận 3 · ★ 4,9 (58) · 112 buổi'), findsOneWidget);
    expect(_in('like', find.text('214')), findsOneWidget);
    expect(_in('save', find.text('37')), findsOneWidget);
    expect(find.text('Bến Bạch Đằng'), findsOneWidget);
    expect(_in('service-card', find.text('Chân dung 2 giờ')), findsOneWidget);
    expect(_in('service-card', find.text('1.500.000₫')), findsOneWidget);
    expect(_in('service-card', find.text('40 ảnh · giao sau 5 ngày · 2 giờ')), findsOneWidget);
  });

  testWidgets('"Thêm của" shows up to three other photos of the photographer', (tester) async {
    await _open(tester, DiscoveryWorld());
    await tester.scrollUntilVisible(find.text('Thêm của Minh Trí'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('more-r1')), findsOneWidget);
    expect(find.byKey(const Key('more-e')), findsOneWidget);
    expect(find.byKey(const Key('more-a')), findsNothing, reason: 'not the post being viewed');
  });

  testWidgets('like: instant, counted, undone by a second tap, reverted when the write fails', (
    tester,
  ) async {
    final w = DiscoveryWorld();
    await _open(tester, w);
    await tester.tap(find.byKey(const Key('like')));
    await tester.pump();
    expect(_in('like', find.text('215')), findsOneWidget);
    expect(_in('like', find.byIcon(Icons.favorite)), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('like')));
    await tester.pumpAndSettle();
    expect(_in('like', find.text('214')), findsOneWidget);

    w.engagement.failWith = StateError('offline');
    await tester.tap(find.byKey(const Key('like')));
    await tester.pumpAndSettle();
    expect(_in('like', find.text('214')), findsOneWidget);
    expect(find.text('Chưa thực hiện được. Thử lại nhé.'), findsOneWidget);
  });

  testWidgets('double tap on the photo likes it, and only likes it', (tester) async {
    final w = DiscoveryWorld();
    await _open(tester, w);
    final gallery = find.byKey(const Key('photo-gallery'));
    await tester.tap(gallery);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(gallery);
    await tester.pumpAndSettle();
    expect(_in('like', find.text('215')), findsOneWidget);
    await tester.tap(gallery);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(gallery);
    await tester.pumpAndSettle();
    expect(_in('like', find.text('215')), findsOneWidget, reason: 'a second double tap does not unlike');
  });

  testWidgets('save and follow toggle', (tester) async {
    final w = DiscoveryWorld();
    await _open(tester, w);
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(_in('save', find.text('38')), findsOneWidget);
    expect(find.text('Theo dõi'), findsOneWidget);
    await tester.tap(find.byKey(const Key('follow')));
    await tester.pumpAndSettle();
    expect(find.text('Đang theo dõi'), findsOneWidget);
    expect(w.engagement.writeCalls, 2);
  });

  testWidgets('a post with several photos pages through them with dots', (tester) async {
    await _open(tester, DiscoveryWorld(), start: '/p/e');
    double dot(int i) => ((tester.widget<DecoratedBox>(find.byKey(Key('page-dot-$i'))).decoration
            as BoxDecoration)
        .color!)
        .a;
    expect(dot(0), 1.0);
    expect(dot(1), 0.5);
    await tester.fling(find.byKey(const Key('photo-gallery')), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();
    expect(dot(0), 0.5);
    expect(dot(1), 1.0);
  });

  testWidgets('a single photo has no dots', (tester) async {
    await _open(tester, DiscoveryWorld());
    expect(find.byKey(const Key('page-dot-0')), findsNothing);
  });

  testWidgets('"Đặt gói này" opens the booking with the package, or S33 first without a phone', (
    tester,
  ) async {
    final router = await _open(tester, DiscoveryWorld());
    await tester.tap(find.byKey(const Key('photo-book')));
    await tester.pumpAndSettle();
    expect(find.text('book /u/p1/book?serviceId=s1'), findsOneWidget);
    router.pop();

    await _open(tester, DiscoveryWorld(hasPhone: false));
    await tester.tap(find.byKey(const Key('photo-book')));
    await tester.pumpAndSettle();
    expect(find.text('phone /u/p1/book?serviceId=s1'), findsOneWidget);
  });

  testWidgets('"Xem hồ sơ" opens S03', (tester) async {
    await _open(tester, DiscoveryWorld());
    await tester.tap(find.byKey(const Key('photo-profile')));
    await tester.pumpAndSettle();
    expect(find.text('profile p1 '), findsOneWidget);
  });

  testWidgets('a retired package is faded and the button leads to the other packages', (
    tester,
  ) async {
    final w = DiscoveryWorld(
      posts: [fixturePost('old', photographerId: 'p1', serviceId: 'sOld')],
    );
    await _open(tester, w, start: '/p/old');
    expect(find.text('Gói này đã ngừng'), findsOneWidget);
    expect(find.text('Đặt gói này'), findsNothing);
    await tester.tap(find.byKey(const Key('photo-book')));
    await tester.pumpAndSettle();
    expect(find.text('profile p1 tab=services'), findsOneWidget);
  });

  testWidgets('a customer\'s real-shoot photo says who shot it and with which package', (
    tester,
  ) async {
    await _open(tester, DiscoveryWorld(), start: '/p/r1');
    expect(find.text('Chụp bởi Minh Trí · gói Chân dung 2 giờ'), findsOneWidget);
  });

  testWidgets('a removed post says so and leads home', (tester) async {
    await _open(tester, DiscoveryWorld(), start: '/p/ghost');
    expect(find.text('Bài đăng không còn'), findsOneWidget);
    await tester.tap(find.text('Về trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a failing load shows the retry', (tester) async {
    final w = DiscoveryWorld();
    w.posts.failWith = StateError('offline');
    await _open(tester, w);
    expect(find.text('Không tải được bài đăng. Kiểm tra mạng rồi thử lại.'), findsOneWidget);
    w.posts.failWith = null;
    await tester.tap(find.byKey(const Key('error-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Chiều muộn ở bến Bạch Đằng #chandung'), findsOneWidget);
  });

  testWidgets('Back goes home when there is nothing to go back to', (tester) async {
    await _open(tester, DiscoveryWorld());
    await tester.tap(find.byKey(const Key('photo-back')));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320x640 at 1.3x on ${b.name} with no blur; the bottom buttons stack', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final w = DiscoveryWorld();
      await w.init();
      await tester.pumpWidget(
        screenRouterApp(router: _router('/p/a'), overrides: w.overrides, textScale: 1.3, brightness: b),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BackdropFilter), findsNothing);
      final profile = tester.getRect(find.byKey(const Key('photo-profile')));
      final book = tester.getRect(find.byKey(const Key('photo-book')));
      expect((profile.height, book.height), (52, 52));
      expect(book.top, greaterThanOrEqualTo(profile.bottom));
    });
  }
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/core/format_test.dart test/features/photo`
Expected: FAIL (`formatDuration`, the controller, the screen and the strings are undefined).

- [ ] **Step 3: Implement**

Append to `lib/core/format.dart`:

```dart
/// `45 phút`, `2 giờ`, `1 giờ 30 phút`.
String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) {
    return '$m phút';
  }
  return m == 0 ? '$h giờ' : '$h giờ $m phút';
}
```

Add to `lib/l10n/app_vi.arb` (comma after the previous last entry), then `flutter gen-l10n`:

```json
  "photoBook": "Đặt gói này",
  "photoViewProfile": "Xem hồ sơ",
  "photoFollow": "Theo dõi",
  "photoFollowing": "Đang theo dõi",
  "photoRealShootBy": "Chụp bởi {name} · gói {service}",
  "@photoRealShootBy": {
    "placeholders": {
      "name": {"type": "String"},
      "service": {"type": "String"}
    }
  },
  "photoRemovedTitle": "Bài đăng không còn",
  "photoRemovedBody": "Bài đăng này đã bị gỡ hoặc không tồn tại.",
  "photoBackHome": "Về trang chủ",
  "photoMoreOf": "Thêm của {name}",
  "@photoMoreOf": {
    "placeholders": {
      "name": {"type": "String"}
    }
  },
  "photoMoreProfile": "Hồ sơ",
  "photoItemLabel": "Ảnh {i}",
  "@photoItemLabel": {
    "placeholders": {
      "i": {"type": "int"}
    }
  },
  "photoOtherPackages": "Xem các gói khác",
  "photoServiceInactive": "Gói này đã ngừng",
  "photoLike": "Thích",
  "photoUnlike": "Bỏ thích",
  "photoPageOf": "Ảnh {n} trên {total}",
  "@photoPageOf": {
    "placeholders": {
      "n": {"type": "int"},
      "total": {"type": "int"}
    }
  },
  "photoLoadError": "Không tải được bài đăng. Kiểm tra mạng rồi thử lại.",
  "servicePhotos": "{n} ảnh",
  "@servicePhotos": {
    "placeholders": {
      "n": {"type": "int"}
    }
  },
  "serviceDelivery": "giao sau {days} ngày",
  "@serviceDelivery": {
    "placeholders": {
      "days": {"type": "int"}
    }
  }
```

```dart
// lib/features/photo/photo_detail_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';

@immutable
class PostDetail {
  const PostDetail({
    required this.post,
    this.photographer,
    this.service,
    this.more = const [],
  });

  final PostSummary post;
  final PhotographerSummary? photographer;

  /// The package the post is tagged with; null when it cannot be found.
  final ServiceSummary? service;

  /// Up to three other posts of the same photographer.
  final List<PostSummary> more;
}

Future<T?> _orNull<T>(Future<T> f) => f.then<T?>((v) => v, onError: (_) => null);

/// The post, its photographer, its package and more of the photographer's
/// work. Null when the post does not exist (or was removed).
final postDetailProvider = FutureProvider.autoDispose.family<PostDetail?, String>((
  ref,
  postId,
) async {
  final posts = ref.watch(postRepositoryProvider);
  final post = await posts.byId(postId);
  if (post == null) {
    return null;
  }
  final (authors, service, others) = await (
    _orNull(ref.watch(photographerRepositoryProvider).summaries([post.photographerId])),
    _orNull(ref.watch(serviceRepositoryProvider).byId(post.photographerId, post.serviceId)),
    _orNull(posts.byPhotographer(post.photographerId, limit: 7)),
  ).wait;
  return PostDetail(
    post: post,
    photographer: authors?[post.photographerId],
    service: service,
    more: (others?.posts ?? const <PostSummary>[])
        .where((p) => p.id != post.id)
        .take(3)
        .toList(),
  );
});
```

```dart
// lib/features/photo/photo_detail_screen.dart
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/discovery/engagement_controller.dart';
import 'package:photobooking/features/discovery/photographer_meta.dart';
import 'package:photobooking/features/photo/photo_detail_controller.dart';

/// S02: from one photo to the package it was shot with, and to booking it.
class PhotoDetailScreen extends ConsumerStatefulWidget {
  const PhotoDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends ConsumerState<PhotoDetailScreen> {
  final _pages = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual(postDetailProvider(widget.postId), (prev, next) {
      final d = next.value;
      if (d != null && prev?.value?.post.id != d.post.id) {
        ref.read(engagementProvider.notifier).load(d.post);
        ref.read(followProvider.notifier).load(d.post.photographerId);
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _like(String postId) async {
    final ok = await ref.read(engagementProvider.notifier).toggleLike(postId);
    if (!ok && mounted) {
      _toast(context.l10n.engagementError);
    }
  }

  Future<void> _save(String postId) async {
    final ok = await ref.read(engagementProvider.notifier).toggleSave(postId);
    if (!ok && mounted) {
      _toast(context.l10n.engagementError);
    }
  }

  Future<void> _follow(String photographerId) async {
    final ok = await ref.read(followProvider.notifier).toggle(photographerId);
    if (!ok && mounted) {
      _toast(context.l10n.engagementError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final detail = ref.watch(postDetailProvider(widget.postId));
    return ScreenCode(
      ScreenCodes.photoDetail,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: detail.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpace.s4),
                  child: AppSkeleton.card(height: 400),
                ),
                error: (_, _) => Center(
                  child: ErrorState(
                    message: l.photoLoadError,
                    onRetry: () => ref.invalidate(postDetailProvider(widget.postId)),
                  ),
                ),
                data: (d) => d == null
                    ? EmptyState(
                        title: l.photoRemovedTitle,
                        body: l.photoRemovedBody,
                        actionLabel: l.photoBackHome,
                        onAction: () => context.go(AppTab.home.path),
                      )
                    : _Content(
                        detail: d,
                        pages: _pages,
                        page: _page,
                        onPage: (i) => setState(() => _page = i),
                        onLike: () => _like(d.post.id),
                        onSave: () => _save(d.post.id),
                        onFollow: () => _follow(d.post.photographerId),
                      ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s2),
                child: IconButton(
                  key: const Key('photo-back'),
                  tooltip: l.back,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go(AppTab.home.path),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.detail,
    required this.pages,
    required this.page,
    required this.onPage,
    required this.onLike,
    required this.onSave,
    required this.onFollow,
  });

  final PostDetail detail;
  final PageController pages;
  final int page;
  final ValueChanged<int> onPage;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final post = detail.post;
    final author = detail.photographer;
    final service = detail.service;
    final view = ref.watch(engagementProvider.select((m) => m[post.id])) ??
        EngagementView(likeCount: post.likeCount, saveCount: post.saveCount);
    final following = ref.watch(followProvider.select((m) => m[post.photographerId] ?? false));
    final active = service != null && service.active;
    final stack = MediaQuery.textScalerOf(context).scale(16) > 18.4;

    final profileButton = AppButton.outline(
      l.photoViewProfile,
      key: const Key('photo-profile'),
      onPressed: () => context.push('/u/${post.photographerId}'),
    );
    final bookButton = AppButton.primary(
      active ? l.photoBook : l.photoOtherPackages,
      key: const Key('photo-book'),
      onPressed: () {
        final s = service;
        if (s != null && s.active) {
          startBooking(context, ref, photographerId: post.photographerId, serviceId: s.id);
        } else {
          context.push('/u/${post.photographerId}?tab=services');
        }
      },
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Gallery(
                post: post,
                pages: pages,
                page: page,
                onPage: onPage,
                onDoubleTap: () {
                  if (!view.liked) {
                    onLike();
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpace.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (author != null)
                      Row(
                        children: [
                          AppAvatar(url: author.avatarUrl, name: author.displayName, decorative: true),
                          const SizedBox(width: AppSpace.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                author.verified
                                    ? VerifiedName(author.displayName, style: theme.textTheme.titleMedium)
                                    : Text(author.displayName, style: theme.textTheme.titleMedium),
                                Text(areaRatingMeta(author, l), style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpace.s2),
                          AppButton.outline(
                            following ? l.photoFollowing : l.photoFollow,
                            key: const Key('follow'),
                            onPressed: onFollow,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
                            ),
                          ),
                        ],
                      ),
                    if (post.caption.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.s3),
                      Text(post.caption),
                    ],
                    if (post.kind == PostKind.realShoot && author != null) ...[
                      const SizedBox(height: AppSpace.s2),
                      Text(
                        l.photoRealShootBy(author.displayName, service?.name ?? ''),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppSpace.s3),
                    Row(
                      children: [
                        _CountButton(
                          key: const Key('like'),
                          icon: view.liked ? Icons.favorite : Icons.favorite_border,
                          count: view.likeCount,
                          label: view.liked ? l.photoUnlike : l.photoLike,
                          color: view.liked ? theme.colorScheme.error : null,
                          onTap: onLike,
                        ),
                        _CountButton(
                          key: const Key('save'),
                          icon: view.saved ? Icons.bookmark : Icons.bookmark_border,
                          count: view.saveCount,
                          label: view.saved ? l.photoUnsave : l.photoSave,
                          onTap: onSave,
                        ),
                        if (post.locationName != null)
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Icon(Icons.place_outlined, size: 16),
                                const SizedBox(width: AppSpace.s1),
                                Flexible(
                                  child: Text(post.locationName!, style: theme.textTheme.bodySmall),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (service != null) ...[
                      const SizedBox(height: AppSpace.s3),
                      _ServiceCard(service: service),
                    ],
                    if (detail.more.isNotEmpty && author != null) ...[
                      const SizedBox(height: AppSpace.s5),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                l.photoMoreOf(author.displayName),
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/u/${post.photographerId}'),
                            child: Text(l.photoMoreProfile),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s2),
                      Row(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpace.s2),
                            Expanded(
                              child: i < detail.more.length
                                  ? PhotoCard(
                                      key: Key('more-${detail.more[i].id}'),
                                      imageUrl: detail.more[i].cover.url,
                                      aspect: 1,
                                      // No visible text: name the card by the post's caption, else "Ảnh {i}".
                                      semanticLabel: detail.more[i].caption.isNotEmpty
                                          ? detail.more[i].caption
                                          : l.photoItemLabel(i + 1),
                                      onTap: () => context.push('/p/${detail.more[i].id}'),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s2, AppSpace.s4, AppSpace.s4),
            child: stack
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [profileButton, const SizedBox(height: AppSpace.s2), bookButton],
                  )
                : Row(
                    children: [
                      Expanded(flex: 4, child: profileButton),
                      const SizedBox(width: AppSpace.s2),
                      Expanded(flex: 6, child: bookButton),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.post,
    required this.pages,
    required this.page,
    required this.onPage,
    required this.onDoubleTap,
  });

  final PostSummary post;
  final PageController pages;
  final int page;
  final ValueChanged<int> onPage;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final n = post.images.length;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            key: const Key('photo-gallery'),
            onDoubleTap: onDoubleTap,
            child: PageView.builder(
              controller: pages,
              itemCount: n,
              onPageChanged: onPage,
              itemBuilder: (context, i) => NetworkPhoto(
                url: post.images[i].url,
                semanticLabel: l.photoPageOf(i + 1, n),
              ),
            ),
          ),
          if (n > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpace.s3,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < n; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: DecoratedBox(
                          key: Key('page-dot-$i'),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: i == page ? 1 : 0.5),
                          ),
                          child: const SizedBox.square(dimension: 6),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  const _CountButton({
    super.key,
    required this.icon,
    required this.count,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final int count;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $count',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color),
                const SizedBox(width: AppSpace.s1),
                Text(
                  '$count',
                  style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});
  final ServiceSummary service;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final photos = service.editedCount ?? service.photoCount;
    final details = [
      if (photos != null) l.servicePhotos(photos),
      if (service.deliveryDays != null) l.serviceDelivery(service.deliveryDays!),
      formatDuration(service.durationMinutes),
    ].join(' · ');
    return Opacity(
      opacity: service.active ? 1 : 0.5,
      child: Material(
        key: const Key('service-card'),
        color: scheme.secondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg + 8),
          side: BorderSide(color: service.active ? scheme.primary : scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name, style: theme.textTheme.titleMedium),
                    Text(details, style: theme.textTheme.bodySmall),
                    if (!service.active)
                      Text(
                        l.photoServiceInactive,
                        style: TextStyle(color: scheme.error, fontSize: AppText.sm),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s2),
              Text(
                formatMoney(service.priceVnd),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
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

Run: `flutter gen-l10n && flutter test test/core/format_test.dart test/features/photo && flutter analyze`
Expected: PASS (format 1 more, screen 17); analyze clean. If the double-tap test counts a single tap as a like, the `GestureDetector` is competing with the `PageView` drag: keep `onDoubleTap` on the `GestureDetector` around the `PageView` as written (taps do nothing, only double taps are recognised). If `find.text('profile p1 ')` fails because the stub prints `profile p1` without the trailing space, change the test string to match the stub's output (`'profile ${id} ${query}'` always has the trailing space when the query is empty).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core lib/features/photo lib/l10n test/core/format_test.dart test/features/photo
git commit -m "feat(photo): S02 photo detail with gallery, engagement, package and booking

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: S04 Find photographer

**Files:**
- Create: `lib/core/widgets/option_row.dart`, `lib/features/find/find_controller.dart`, `lib/features/find/find_sheets.dart`, `lib/features/find/find_screen.dart`, `test/core/widgets/option_row_test.dart`, `test/features/find/find_controller_test.dart`, `test/features/find/find_screen_test.dart`
- Modify: `lib/core/core.dart`, `lib/l10n/app_vi.arb`

**Interfaces:**
- Consumes: `recommendationRepositoryProvider`, `exploreResolutionProvider`, `locationControllerProvider`, `areasProvider`, `showAreaPicker` (3a2), `showAppSheet`, `AppChip`, `PhotographerCard`, `startBooking`, `freeThisWeekLabel`, `formatDay`, `formatDayMonth`, `weekdayLabel`, `formatMoney`, `formatRating`, `specialtyLabel`, `styleLabel`, `kSpecialties`, `toVn`.
- Produces:
  - `const OptionRow({super.key, required String label, required bool selected, required VoidCallback onTap, IconData? icon})` in `core/` — a single-choice row (radio icon, label that may wrap, 48dp high) for sheets; `Semantics(selected, inMutuallyExclusiveGroup)`.
  - `class FindFilters` (`specialtyId`, `styleId`, `date`, `budgetMax`, `minRating`, `sort`; `hasAny`; value equality) and `FindFiltersController` (`setSpecialty`, `setStyle`, `setDate`, `setBudget`, `setMinRating`, `setSort`, `clear()` which keeps the sort); `findFiltersProvider` (kept while the app runs, so the choices survive switching tabs).
  - `class FindResults { items, cursor, usedFallback, loadingMore, requestId, algorithmVersion }` and `FindResultsController extends AsyncNotifier<FindResults>`: rebuilds (skeleton, new query) when the filters or the area change; page size 20; `loadMore()`; the rating chip is applied on the device and skips up to three pages that it empties entirely; `sendClick(RecommendedPhotographer)` sends a `click` signal (best effort); `findResultsProvider`.
  - Sheets (`find_sheets.dart`): `class Picked<T> { const Picked(this.value); final T? value; }` (a null `value` means "clear"); `Future<Picked<String>?> pickSpecialty(BuildContext, {String? current})`, `Future<Picked<int>?> pickBudget(BuildContext, {int? current})`, `Future<Picked<double>?> pickMinRating(BuildContext, {double? current})`, `Future<Picked<DateTime>?> pickDate(BuildContext, {DateTime? current, required DateTime today})`. A dismissed sheet returns null and changes nothing.
  - `FindPhotographerScreen({super.key, String? initialSpecialty, String? initialStyle, String? initialArea})` wrapped in `ScreenCode(ScreenCodes.findPhotographer)`; the three parameters come from the query string of `/action` (the Explore tiles) and are applied when they change. Keys: `find-area`, `find-area-chip`, `find-date`, `find-service`, `find-style`, `find-price`, `find-rating`, `find-sort-best|near|price|rating`, `find-card-<id>`, `date-clear`, `date-done`.
  - l10n (all listed in Step 3).

Behaviour (spec S04): AppBar "Tìm thợ ảnh" with a pin that opens the area picker; filter chips (area, date, service, price, rating, plus a style chip when a style is set) that open sheets and show their value when set; sort chips (Phù hợp nhất, Gần tôi, Giá, Đánh giá); a count line ("12 nhiếp ảnh gia rảnh T7 12/10", with "+" when more pages exist); `PhotographerCard`s with up to two reason chips, "Hồ sơ" and "Đặt {thứ}"; the quiet note "Đang xếp theo sao và khoảng cách" when the remote recommender failed; empty state "Chưa có ai khớp bộ lọc" with "Xoá bộ lọc"; two columns from 600dp. The date picker is Flutter's `CalendarDatePicker` in a sheet until plan 2d's `AvailabilityCalendar` exists. The impression signal (a card seen for one second) is not sent yet.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/widgets/option_row_test.dart
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';

import 'widget_host.dart';

void main() {
  testWidgets('tapping calls onTap; the row is at least 48dp high', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      hostWidget(OptionRow(label: 'Quận 1', selected: false, onTap: () => taps++)),
    );
    await tester.tap(find.text('Quận 1'));
    expect(taps, 1);
    expect(tester.getSize(find.byType(OptionRow)).height, greaterThanOrEqualTo(48));
  });

  testWidgets('selected and unselected rows differ in icon and semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      hostWidget(
        Column(
          children: [
            OptionRow(label: 'A', selected: true, onTap: () {}),
            OptionRow(label: 'B', selected: false, onTap: () {}),
          ],
        ),
      ),
    );
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('A')).flagsCollection.isSelected, Tristate.isTrue);
    expect(tester.getSemantics(find.bySemanticsLabel('B')).flagsCollection.isSelected, Tristate.isFalse);
    handle.dispose();
  });

  testWidgets('a long label wraps instead of overflowing at 320dp, 1.3x', (tester) async {
    await tester.pumpWidget(
      hostWidget(
        OptionRow(
          label: 'Dưới 10 triệu đồng cho một buổi chụp kéo dài cả ngày ở hai địa điểm',
          selected: true,
          icon: Icons.payments_outlined,
          onTap: () {},
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
// test/features/find/find_controller_test.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/recommendation/resilient_recommendation_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/find/find_controller.dart';

import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';

class _Spy extends DelegatingRecommender {
  _Spy(super.inner);
  final queries = <RecommendationQuery>[];
  final signals = <RecommendationSignal>[];
  @override
  Future<RecommendationPage> recommendPhotographers(RecommendationQuery q) {
    queries.add(q);
    return super.recommendPhotographers(q);
  }

  @override
  Future<void> sendFeedback(List<RecommendationSignal> s) {
    signals.addAll(s);
    return super.sendFeedback(s);
  }
}

Future<(ProviderContainer, DiscoveryWorld, _Spy)> _make({DiscoveryWorld? world}) async {
  _Spy? spy;
  final use = world ??
      DiscoveryWorld(recommenderFactory: (x) => spy = _Spy(x.localRecommender()));
  await use.init();
  final c = ProviderContainer(overrides: use.overrides);
  addTearDown(c.dispose);
  return (c, use, spy ?? _Spy(use.recommender));
}

List<String> _ids(FindResults r) => r.items.map((e) => e.photographer.id).toList();

void main() {
  group('FindFilters', () {
    test('setters change one thing, clear keeps the sort', () async {
      final (c, _, _) = await _make();
      final n = c.read(findFiltersProvider.notifier);
      n.setSpecialty('wedding');
      n.setBudget(2000000);
      n.setMinRating(4.5);
      n.setStyle('film');
      n.setDate(DateTime(2026, 10, 3));
      n.setSort(RecommendationSort.price);
      final f = c.read(findFiltersProvider);
      expect((f.specialtyId, f.budgetMax, f.minRating, f.styleId, f.sort), ('wedding', 2000000, 4.5, 'film', RecommendationSort.price));
      expect(f.hasAny, isTrue);
      n.clear();
      final cleared = c.read(findFiltersProvider);
      expect(cleared.hasAny, isFalse);
      expect(cleared.sort, RecommendationSort.price);
    });

    test('a single filter can be cleared with null', () async {
      final (c, _, _) = await _make();
      final n = c.read(findFiltersProvider.notifier);
      n.setSpecialty('wedding');
      n.setSpecialty(null);
      expect(c.read(findFiltersProvider).specialtyId, isNull);
    });
  });

  group('FindResults', () {
    test('loads the first page in the recommender\'s order', () async {
      final (c, _, spy) = await _make();
      final r = await c.read(findResultsProvider.future);
      expect(_ids(r), ['p1', 'p2', 'p3', 'p4']);
      expect(r.cursor, isNull);
      expect(r.usedFallback, isFalse);
      expect(r.requestId, startsWith('local-'));
      expect(spy.queries.single.limit, 20);
    });

    test('a filter change runs a new query with that filter', () async {
      final (c, _, spy) = await _make();
      await c.read(findResultsProvider.future);
      c.read(findFiltersProvider.notifier).setSpecialty('wedding');
      c.read(findFiltersProvider.notifier).setBudget(9000000);
      final r = await c.read(findResultsProvider.future);
      expect(_ids(r), ['p1', 'p2']);
      expect(spy.queries.last.specialtyId, 'wedding');
      expect(spy.queries.last.budgetMax, 9000000);
    });

    test('a saved area becomes the geohash6 of the query', () async {
      final (c, _, spy) = await _make();
      await c.read(locationControllerProvider.notifier).chooseArea(builtInAreas.first);
      await c.read(findResultsProvider.future);
      expect(spy.queries.last.geohash6, hasLength(6));
      expect(spy.queries.last.geohash6, startsWith(builtInAreas.first.geohash5));
    });

    test('no location and no area: no geohash is sent', () async {
      final (c, _, spy) = await _make();
      await c.read(findResultsProvider.future);
      expect(spy.queries.single.geohash6, isNull);
    });

    test('the date goes to the query and drops a busy photographer', () async {
      final (c, w, spy) = await _make();
      w.availability.set('p2', '2026-10-03', DayAvailability.booked);
      c.read(findFiltersProvider.notifier).setDate(DateTime(2026, 10, 3));
      final r = await c.read(findResultsProvider.future);
      expect(_ids(r), isNot(contains('p2')));
      expect(spy.queries.last.date, DateTime(2026, 10, 3));
    });

    test('the rating filter is applied here and skips pages it empties', () async {
      final world = DiscoveryWorld(
        photographers: [
          for (var i = 0; i < 20; i++)
            fixturePhotographer('a${i.toString().padLeft(2, '0')}', rating: 4.7, reviews: 1000, completed: 500),
          for (var i = 0; i < 5; i++)
            fixturePhotographer('b$i', rating: 4.85, reviews: 10, completed: 5),
        ],
      );
      final (c, _, _) = await _make(world: world);
      c.read(findFiltersProvider.notifier).setMinRating(4.8);
      final r = await c.read(findResultsProvider.future);
      expect(r.items, hasLength(5));
      expect(_ids(r).every((id) => id.startsWith('b')), isTrue);
    });

    test('loadMore appends the next page once', () async {
      final world = DiscoveryWorld(
        photographers: [
          for (var i = 0; i < 30; i++) fixturePhotographer('p${i.toString().padLeft(2, '0')}', reviews: 10 + i),
        ],
      );
      final (c, _, _) = await _make(world: world);
      final n = c.read(findResultsProvider.notifier);
      var r = await c.read(findResultsProvider.future);
      expect(r.items, hasLength(20));
      expect(r.cursor, isNotNull);
      await Future.wait([n.loadMore(), n.loadMore()]);
      r = c.read(findResultsProvider).requireValue;
      expect(r.items, hasLength(30));
      expect(r.cursor, isNull);
      expect(r.loadingMore, isFalse);
    });

    test('a remote failure is flagged so the screen can say so', () async {
      final world = DiscoveryWorld(
        recommenderFactory: (x) => ResilientRecommendationRepository(
          primary: ThrowingRecommender(),
          fallback: x.localRecommender(),
        ),
      );
      final (c, _, _) = await _make(world: world);
      final r = await c.read(findResultsProvider.future);
      expect(r.usedFallback, isTrue);
      expect(r.items, isNotEmpty);
    });

    test('a failing query is an error', () async {
      final (c, w, _) = await _make();
      w.photographers.failWith = StateError('offline');
      await expectLater(c.read(findResultsProvider.future), throwsStateError);
    });

    test('opening a profile sends a click signal with the request and rank', () async {
      final (c, _, spy) = await _make();
      final r = await c.read(findResultsProvider.future);
      c.read(findResultsProvider.notifier).sendClick(r.items[1]);
      await Future<void>.delayed(Duration.zero);
      final s = spy.signals.single;
      expect((s.type, s.photographerId, s.rank, s.requestId), (SignalType.click, 'p2', 2, r.requestId));
      expect(s.algorithmVersion, '1.0.0');
    });
  });

  test('a stored area survives as prefs only (no coordinates)', () async {
    final (c, w, _) = await _make();
    await c.read(locationControllerProvider.notifier).chooseArea(builtInAreas.first);
    final stored = jsonDecode(w.prefs.getString(LocationController.areaKey)!) as Map;
    expect(stored.keys.toSet(), {'id', 'name', 'geohash5'});
  });
}
```

```dart
// test/features/find/find_screen_test.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/data/location/area.dart';
import 'package:photobooking/data/recommendation/availability_lookup.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/recommendation/resilient_recommendation_repository.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/find/find_screen.dart';

import '../../support/content_fixtures.dart';
import '../../support/discovery_world.dart';
import '../../support/screen_host.dart';

class _Spy extends DelegatingRecommender {
  _Spy(super.inner);
  final signals = <RecommendationSignal>[];
  @override
  Future<void> sendFeedback(List<RecommendationSignal> s) {
    signals.addAll(s);
    return super.sendFeedback(s);
  }
}

GoRouter _router({String start = '/action'}) => GoRouter(
  initialLocation: start,
  routes: [
    GoRoute(
      path: '/action',
      builder: (_, s) => FindPhotographerScreen(
        initialSpecialty: s.uri.queryParameters['specialty'],
        initialStyle: s.uri.queryParameters['style'],
        initialArea: s.uri.queryParameters['area'],
      ),
    ),
    GoRoute(path: '/u/:id', builder: (_, s) => Text('profile ${s.pathParameters['id']}')),
    GoRoute(path: '/u/:id/book', builder: (_, s) => Text('book ${s.uri}')),
    GoRoute(path: '/profile/phone', builder: (_, s) => Text('phone ${s.uri.queryParameters['returnTo']}')),
  ],
);

Future<GoRouter> _open(
  WidgetTester tester,
  DiscoveryWorld w, {
  String start = '/action',
  double textScale = 1,
}) async {
  await w.init();
  final router = _router(start: start);
  await tester.pumpWidget(screenRouterApp(router: router, overrides: w.overrides, textScale: textScale));
  await tester.pumpAndSettle();
  return router;
}

double _top(WidgetTester t, String id) => t.getTopLeft(find.byKey(Key('find-card-$id'))).dy;

Future<void> _choose(WidgetTester tester, String chipKey, String optionText) async {
  await tester.tap(find.byKey(Key(chipKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionText));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('title, chips, count and the cards in recommended order', (tester) async {
    await _open(tester, DiscoveryWorld());
    expect(find.text('Tìm thợ ảnh'), findsWidgets);
    for (final key in ['find-area-chip', 'find-date', 'find-service', 'find-price', 'find-rating']) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    expect(find.text('Chọn khu vực'), findsOneWidget, reason: 'no area yet');
    expect(find.text('4 nhiếp ảnh gia'), findsOneWidget);
    expect(_top(tester, 'p1'), lessThan(_top(tester, 'p2')));
    expect(_top(tester, 'p2'), lessThan(_top(tester, 'p3')));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('cards show at most two reasons and the ticked name', (tester) async {
    await _open(tester, DiscoveryWorld());
    final p1 = find.byKey(const Key('find-card-p1'));
    expect(find.descendant(of: p1, matching: find.textContaining('Minh Trí', findRichText: true)), findsOneWidget);
    expect(find.descendant(of: p1, matching: find.text('Rảnh T7 03/10')), findsOneWidget);
  });

  testWidgets('service sheet: choose "Cưới" and the list narrows', (tester) async {
    await _open(tester, DiscoveryWorld());
    await _choose(tester, 'find-service', 'Cưới');
    expect(find.descendant(of: find.byKey(const Key('find-service')), matching: find.text('Cưới')), findsOneWidget);
    expect(find.text('2 nhiếp ảnh gia'), findsOneWidget);
    expect(find.byKey(const Key('find-card-p3')), findsNothing);
  });

  testWidgets('budget and rating sheets', (tester) async {
    await _open(tester, DiscoveryWorld());
    await _choose(tester, 'find-price', 'Dưới 2M');
    expect(find.text('2 nhiếp ảnh gia'), findsOneWidget);
    await _choose(tester, 'find-rating', '★ 4,8+');
    expect(find.text('1 nhiếp ảnh gia'), findsOneWidget);
    expect(find.byKey(const Key('find-card-p1')), findsOneWidget);
  });

  testWidgets('sort by price puts the cheapest first', (tester) async {
    await _open(tester, DiscoveryWorld());
    await tester.tap(find.byKey(const Key('find-sort-price')));
    await tester.pumpAndSettle();
    expect(_top(tester, 'p3'), lessThan(_top(tester, 'p1')));
    expect(_top(tester, 'p1'), lessThan(_top(tester, 'p4')));
    expect(_top(tester, 'p4'), lessThan(_top(tester, 'p2')));
  });

  testWidgets('a picked day drops busy photographers and names the day on the buttons', (
    tester,
  ) async {
    final w = DiscoveryWorld();
    await w.init();
    w.availability.set('p2', '2026-10-03', DayAvailability.booked);
    final router = _router();
    await tester.pumpWidget(screenRouterApp(router: router, overrides: w.overrides));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('find-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.tap(find.byKey(const Key('date-done')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('find-date')), matching: find.text('T7 03/10')), findsOneWidget);
    expect(find.text('3 nhiếp ảnh gia rảnh T7 03/10'), findsOneWidget);
    expect(find.byKey(const Key('find-card-p2')), findsNothing);
    expect(find.descendant(of: find.byKey(const Key('find-card-p1')), matching: find.text('Rảnh 03/10')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('find-card-p1')), matching: find.text('Đặt T7')), findsOneWidget);

    await tester.tap(find.byKey(const Key('card-book-p1')));
    await tester.pumpAndSettle();
    expect(find.text('book /u/p1/book?date=2026-10-03'), findsOneWidget);
  });

  testWidgets('clearing the day from its sheet brings everyone back', (tester) async {
    await _open(tester, DiscoveryWorld());
    await tester.tap(find.byKey(const Key('find-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('date-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('find-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('date-clear')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('find-date')), matching: find.text('Ngày')), findsOneWidget);
  });

  testWidgets('dismissing a sheet changes nothing', (tester) async {
    await _open(tester, DiscoveryWorld());
    await tester.tap(find.byKey(const Key('find-service')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('4 nhiếp ảnh gia'), findsOneWidget);
  });

  testWidgets('no match: say so, offer to clear the filters, and clearing works', (tester) async {
    await _open(tester, DiscoveryWorld());
    await _choose(tester, 'find-service', 'Ẩm thực');
    expect(find.text('Chưa có ai khớp bộ lọc'), findsOneWidget);
    await tester.tap(find.text('Xoá bộ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('4 nhiếp ảnh gia'), findsOneWidget);
  });

  testWidgets('a down remote recommender shows the quiet fallback note', (tester) async {
    await _open(
      tester,
      DiscoveryWorld(
        recommenderFactory: (x) => ResilientRecommendationRepository(
          primary: ThrowingRecommender(),
          fallback: x.localRecommender(),
        ),
      ),
    );
    expect(find.text('Đang xếp theo sao và khoảng cách'), findsOneWidget);
    expect(find.byKey(const Key('find-card-p1')), findsOneWidget);
  });

  testWidgets('the local ranking alone shows no note', (tester) async {
    await _open(tester, DiscoveryWorld());
    expect(find.text('Đang xếp theo sao và khoảng cách'), findsNothing);
  });

  testWidgets('opening a profile sends a click signal; booking goes through the phone gate', (
    tester,
  ) async {
    late _Spy spy;
    final w = DiscoveryWorld(recommenderFactory: (x) => spy = _Spy(x.localRecommender()), hasPhone: false);
    await _open(tester, w);
    await tester.tap(find.byKey(const Key('card-book-p1')));
    await tester.pumpAndSettle();
    expect(find.text('phone /u/p1/book'), findsOneWidget);
    final router = _router();
    await tester.pumpWidget(screenRouterApp(router: router, overrides: w.overrides));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('card-profile-p2')));
    await tester.pumpAndSettle();
    expect(find.text('profile p2'), findsOneWidget);
    expect(spy.signals.single.photographerId, 'p2');
  });

  testWidgets('the pin in the bar opens the area picker, and an area becomes the chip', (
    tester,
  ) async {
    await _open(tester, DiscoveryWorld());
    await tester.tap(find.byKey(const Key('find-area')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn khu vực của bạn'), findsOneWidget);
    await tester.tap(find.byKey(const Key('area-hcm-q1')));
    await tester.tap(find.byKey(const Key('area-use')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('find-area-chip')), matching: find.text('Quận 1, TP.HCM')), findsOneWidget);
    expect(find.text('4 nhiếp ảnh gia'), findsOneWidget);
  });

  group('links from Explore', () {
    testWidgets('?specialty= applies a service filter', (tester) async {
      await _open(tester, DiscoveryWorld(), start: '/action?specialty=wedding');
      expect(find.descendant(of: find.byKey(const Key('find-service')), matching: find.text('Cưới')), findsOneWidget);
      expect(find.text('2 nhiếp ảnh gia'), findsOneWidget);
    });

    testWidgets('?style= applies a style filter with its own chip that clears on tap', (tester) async {
      await _open(tester, DiscoveryWorld(), start: '/action?style=film');
      expect(find.byKey(const Key('find-style')), findsOneWidget);
      expect(find.text('1 nhiếp ảnh gia'), findsOneWidget);
      await tester.tap(find.byKey(const Key('find-style')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('find-style')), findsNothing);
      expect(find.text('4 nhiếp ảnh gia'), findsOneWidget);
    });

    testWidgets('?area= selects that area for good', (tester) async {
      final w = DiscoveryWorld();
      await _open(tester, w, start: '/action?area=hcm-q1');
      final saved = jsonDecode(w.prefs.getString(LocationController.areaKey)!) as Map;
      expect(saved['id'], 'hcm-q1');
      expect(find.descendant(of: find.byKey(const Key('find-area-chip')), matching: find.text('Quận 1, TP.HCM')), findsOneWidget);
    });

    testWidgets('a new link while the screen is open changes the filter', (tester) async {
      final router = await _open(tester, DiscoveryWorld(), start: '/action?specialty=wedding');
      router.go('/action?specialty=family');
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('find-service')), matching: find.text('Gia đình')), findsOneWidget);
      expect(find.text('1 nhiếp ảnh gia'), findsOneWidget);
    });
  });

  testWidgets('paging: "20+" first, all after scrolling to the end', (tester) async {
    final w = DiscoveryWorld(
      photographers: [
        for (var i = 0; i < 30; i++) fixturePhotographer('p${i.toString().padLeft(2, '0')}', name: 'Thợ $i', reviews: 10 + i),
      ],
    );
    await _open(tester, w);
    expect(find.text('20+ nhiếp ảnh gia'), findsOneWidget);
    // More reviews rank higher, so p00 is the last card.
    await tester.scrollUntilVisible(find.byKey(const Key('find-card-p00')), 600, scrollable: find.byType(Scrollable).first, maxScrolls: 200);
    await tester.pumpAndSettle();
    expect(find.text('30 nhiếp ảnh gia'), findsOneWidget);
  });

  testWidgets('a failing load shows the retry', (tester) async {
    final w = DiscoveryWorld();
    await w.init();
    w.photographers.failWith = StateError('offline');
    await tester.pumpWidget(screenRouterApp(router: _router(), overrides: w.overrides));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được danh sách. Kiểm tra mạng rồi thử lại.'), findsOneWidget);
    w.photographers.failWith = null;
    await tester.tap(find.byKey(const Key('error-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('find-card-p1')), findsOneWidget);
  });

  for (final b in Brightness.values) {
    testWidgets('fits 320x640 at 1.3x on ${b.name}', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final w = DiscoveryWorld();
      await w.init();
      await tester.pumpWidget(
        screenRouterApp(router: _router(), overrides: w.overrides, textScale: 1.3, brightness: b),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('find-service')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'the sheet fits too');
    });
  }

  testWidgets('from 600dp the cards use two columns', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _open(tester, DiscoveryWorld());
    final a = tester.getTopLeft(find.byKey(const Key('find-card-p1')));
    final b = tester.getTopLeft(find.byKey(const Key('find-card-p2')));
    expect(a.dy, b.dy);
    expect(b.dx, greaterThan(a.dx));
  });
}
```

- [ ] **Step 2: Run and see them fail**

Run: `flutter test test/core/widgets/option_row_test.dart test/features/find`
Expected: FAIL (the widget, controllers, screen and strings do not exist).

- [ ] **Step 3: Implement**

Add to `lib/l10n/app_vi.arb` (comma after the previous last entry), then `flutter gen-l10n`:

```json
  "findDate": "Ngày",
  "findService": "Dịch vụ",
  "findPrice": "Giá",
  "findRating": "Đánh giá",
  "findNearMe": "Quanh bạn",
  "findCount": "{count} nhiếp ảnh gia",
  "@findCount": {
    "placeholders": {
      "count": {"type": "String"}
    }
  },
  "findCountOnDay": "{count} nhiếp ảnh gia rảnh {day}",
  "@findCountOnDay": {
    "placeholders": {
      "count": {"type": "String"},
      "day": {"type": "String"}
    }
  },
  "findSortBest": "Phù hợp nhất",
  "findSortNear": "Gần tôi",
  "findSortPrice": "Giá",
  "findSortRating": "Đánh giá",
  "findNoResult": "Chưa có ai khớp bộ lọc",
  "findNoResultBody": "Thử bỏ bớt bộ lọc hoặc chọn ngày khác.",
  "findClear": "Xoá bộ lọc",
  "findFallbackNote": "Đang xếp theo sao và khoảng cách",
  "findLoadError": "Không tải được danh sách. Kiểm tra mạng rồi thử lại.",
  "findBookDay": "Đặt {day}",
  "@findBookDay": {
    "placeholders": {
      "day": {"type": "String"}
    }
  },
  "findDateTitle": "Chọn ngày",
  "findDateClear": "Xoá ngày",
  "findDateDone": "Xong",
  "findServiceTitle": "Dịch vụ",
  "findServiceAll": "Tất cả dịch vụ",
  "findPriceTitle": "Ngân sách",
  "findPriceAny": "Mọi mức giá",
  "findPriceUnder": "Dưới {price}",
  "@findPriceUnder": {
    "placeholders": {
      "price": {"type": "String"}
    }
  },
  "findRatingTitle": "Đánh giá tối thiểu",
  "findRatingAny": "Mọi đánh giá",
  "findRatingMin": "★ {rating}+",
  "@findRatingMin": {
    "placeholders": {
      "rating": {"type": "String"}
    }
  }
```

```dart
// lib/core/widgets/option_row.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/theme/app_theme.dart';
import 'package:photobooking/core/theme/tokens.g.dart';

/// One choice in a single-choice list inside a sheet (service, budget, rating).
/// The label wraps; the row is at least 48dp high.
class OptionRow extends StatelessWidget {
  const OptionRow({
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
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
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

Export `option_row.dart` from `core.dart`.

```dart
// lib/features/find/find_controller.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/recommendation/recommendation_providers.dart';
import 'package:photobooking/features/explore/location_controller.dart';

@immutable
class FindFilters {
  const FindFilters({
    this.specialtyId,
    this.styleId,
    this.date,
    this.budgetMax,
    this.minRating,
    this.sort = RecommendationSort.best,
  });

  final String? specialtyId;
  final String? styleId;

  /// A calendar date (Vietnam); only year, month and day matter.
  final DateTime? date;
  final int? budgetMax;
  final double? minRating;
  final RecommendationSort sort;

  bool get hasAny =>
      specialtyId != null ||
      styleId != null ||
      date != null ||
      budgetMax != null ||
      minRating != null;

  @override
  bool operator ==(Object other) =>
      other is FindFilters &&
      other.specialtyId == specialtyId &&
      other.styleId == styleId &&
      other.date == date &&
      other.budgetMax == budgetMax &&
      other.minRating == minRating &&
      other.sort == sort;

  @override
  int get hashCode =>
      Object.hash(specialtyId, styleId, date, budgetMax, minRating, sort);
}

class FindFiltersController extends Notifier<FindFilters> {
  @override
  FindFilters build() => const FindFilters();

  FindFilters _with({
    Object? specialtyId = _keep,
    Object? styleId = _keep,
    Object? date = _keep,
    Object? budgetMax = _keep,
    Object? minRating = _keep,
    RecommendationSort? sort,
  }) => FindFilters(
    specialtyId: identical(specialtyId, _keep) ? state.specialtyId : specialtyId as String?,
    styleId: identical(styleId, _keep) ? state.styleId : styleId as String?,
    date: identical(date, _keep) ? state.date : date as DateTime?,
    budgetMax: identical(budgetMax, _keep) ? state.budgetMax : budgetMax as int?,
    minRating: identical(minRating, _keep) ? state.minRating : minRating as double?,
    sort: sort ?? state.sort,
  );

  static const _keep = Object();

  void setSpecialty(String? v) => state = _with(specialtyId: v);
  void setStyle(String? v) => state = _with(styleId: v);
  void setDate(DateTime? v) => state = _with(date: v);
  void setBudget(int? v) => state = _with(budgetMax: v);
  void setMinRating(double? v) => state = _with(minRating: v);
  void setSort(RecommendationSort v) => state = _with(sort: v);

  /// Removes every filter and keeps the chosen sort.
  void clear() => state = FindFilters(sort: state.sort);
}

/// Kept while the app runs, so the choices survive switching tabs.
final findFiltersProvider = NotifierProvider<FindFiltersController, FindFilters>(
  FindFiltersController.new,
);

@immutable
class FindResults {
  const FindResults({
    this.items = const [],
    this.cursor,
    this.usedFallback = false,
    this.loadingMore = false,
    this.requestId = '',
    this.algorithmVersion = '',
  });

  final List<RecommendedPhotographer> items;
  final String? cursor;
  final bool usedFallback;
  final bool loadingMore;
  final String requestId;
  final String algorithmVersion;

  FindResults copyWith({bool? loadingMore}) => FindResults(
    items: items,
    cursor: cursor,
    usedFallback: usedFallback,
    loadingMore: loadingMore ?? this.loadingMore,
    requestId: requestId,
    algorithmVersion: algorithmVersion,
  );
}

class FindResultsController extends AsyncNotifier<FindResults> {
  static const pageSize = 20;

  /// A rating filter that empties a whole page looks at the next pages, up to
  /// this many in a row.
  static const maxEmptyPages = 4;

  @override
  Future<FindResults> build() async {
    final filters = ref.watch(findFiltersProvider);
    final geohash6 = ref.watch(
      exploreResolutionProvider.select((r) => r.origin?.geohash6),
    );
    return _fetch(filters, geohash6, cursor: null, previous: const FindResults());
  }

  Future<FindResults> _fetch(
    FindFilters f,
    String? geohash6, {
    required String? cursor,
    required FindResults previous,
  }) async {
    final recommender = ref.read(recommendationRepositoryProvider);
    final collected = <RecommendedPhotographer>[];
    var page = await recommender.recommendPhotographers(
      _query(f, geohash6, cursor),
    );
    var usedFallback = previous.usedFallback || page.usedFallback;
    collected.addAll(_byRating(page.items, f));
    for (var i = 1; i < maxEmptyPages && collected.isEmpty && page.nextCursor != null; i++) {
      page = await recommender.recommendPhotographers(
        _query(f, geohash6, page.nextCursor),
      );
      usedFallback = usedFallback || page.usedFallback;
      collected.addAll(_byRating(page.items, f));
    }
    return FindResults(
      items: [...previous.items, ...collected],
      cursor: page.nextCursor,
      usedFallback: usedFallback,
      requestId: page.requestId,
      algorithmVersion: page.algorithmVersion,
    );
  }

  RecommendationQuery _query(FindFilters f, String? geohash6, String? cursor) =>
      RecommendationQuery(
        specialtyId: f.specialtyId,
        styleId: f.styleId,
        date: f.date,
        geohash6: geohash6,
        budgetMax: f.budgetMax,
        sort: f.sort,
        limit: pageSize,
        cursor: cursor,
      );

  List<RecommendedPhotographer> _byRating(
    List<RecommendedPhotographer> items,
    FindFilters f,
  ) => f.minRating == null
      ? items
      : items.where((i) => i.photographer.ratingAvg >= f.minRating!).toList();

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.cursor == null || current.loadingMore) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _fetch(
        ref.read(findFiltersProvider),
        ref.read(exploreResolutionProvider).origin?.geohash6,
        cursor: current.cursor,
        previous: current,
      );
      if (ref.mounted) {
        state = AsyncData(next);
      }
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData(current.copyWith(loadingMore: false));
      }
    }
  }

  /// "Click": the user opened this photographer from the list. Best effort.
  void sendClick(RecommendedPhotographer item) {
    final current = state.value;
    if (current == null) {
      return;
    }
    unawaited(
      ref.read(recommendationRepositoryProvider).sendFeedback([
        RecommendationSignal(
          type: SignalType.click,
          requestId: current.requestId,
          photographerId: item.photographer.id,
          rank: item.rank,
          algorithmVersion: current.algorithmVersion,
          at: ref.read(clockProvider)(),
        ),
      ]),
    );
  }
}

final findResultsProvider =
    AsyncNotifierProvider<FindResultsController, FindResults>(
      FindResultsController.new,
    );
```

```dart
// lib/features/find/find_sheets.dart
import 'package:flutter/material.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';

/// A sheet's answer. `null` returned by the sheet means "dismissed, change
/// nothing"; `Picked(null)` means "clear this filter".
class Picked<T> {
  const Picked(this.value);
  final T? value;
}

Widget _sheet(BuildContext context, String title, List<Widget> rows) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.s5, 0, AppSpace.s5, AppSpace.s2),
        child: Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(AppSpace.s3, 0, AppSpace.s3, AppSpace.s5),
          children: rows,
        ),
      ),
    ],
  );
}

Future<Picked<String>?> pickSpecialty(BuildContext context, {String? current}) {
  final l = context.l10n;
  return showAppSheet<Picked<String>>(
    context,
    builder: (sheet) => _sheet(sheet, l.findServiceTitle, [
      OptionRow(
        label: l.findServiceAll,
        selected: current == null,
        onTap: () => Navigator.of(sheet).pop(const Picked<String>(null)),
      ),
      for (final o in kSpecialties)
        OptionRow(
          label: o.labelVi,
          selected: current == o.id,
          onTap: () => Navigator.of(sheet).pop(Picked<String>(o.id)),
        ),
    ]),
  );
}

const _budgets = [1000000, 2000000, 5000000, 10000000];

Future<Picked<int>?> pickBudget(BuildContext context, {int? current}) {
  final l = context.l10n;
  return showAppSheet<Picked<int>>(
    context,
    builder: (sheet) => _sheet(sheet, l.findPriceTitle, [
      OptionRow(
        label: l.findPriceAny,
        selected: current == null,
        onTap: () => Navigator.of(sheet).pop(const Picked<int>(null)),
      ),
      for (final b in _budgets)
        OptionRow(
          label: l.findPriceUnder(formatMoney(b, short: true)),
          selected: current == b,
          onTap: () => Navigator.of(sheet).pop(Picked<int>(b)),
        ),
    ]),
  );
}

const _ratings = [4.0, 4.5, 4.8];

Future<Picked<double>?> pickMinRating(BuildContext context, {double? current}) {
  final l = context.l10n;
  return showAppSheet<Picked<double>>(
    context,
    builder: (sheet) => _sheet(sheet, l.findRatingTitle, [
      OptionRow(
        label: l.findRatingAny,
        selected: current == null,
        onTap: () => Navigator.of(sheet).pop(const Picked<double>(null)),
      ),
      for (final r in _ratings)
        OptionRow(
          label: l.findRatingMin(formatRating(r)),
          selected: current == r,
          onTap: () => Navigator.of(sheet).pop(Picked<double>(r)),
        ),
    ]),
  );
}

/// A month calendar from [today] for a year, with "Xoá ngày" and "Xong".
Future<Picked<DateTime>?> pickDate(
  BuildContext context, {
  DateTime? current,
  required DateTime today,
}) => showAppSheet<Picked<DateTime>>(
  context,
  builder: (sheet) => _DateSheet(current: current, today: today),
);

class _DateSheet extends StatefulWidget {
  const _DateSheet({required this.current, required this.today});
  final DateTime? current;
  final DateTime today;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _picked = widget.current ?? widget.today;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpace.s3, 0, AppSpace.s3, AppSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
            child: Semantics(
              header: true,
              child: Text(l.findDateTitle, style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          CalendarDatePicker(
            initialDate: _picked,
            firstDate: widget.today,
            lastDate: widget.today.add(const Duration(days: 365)),
            onDateChanged: (d) => setState(() => _picked = d),
          ),
          const SizedBox(height: AppSpace.s2),
          AppButton.outline(
            l.findDateClear,
            key: const Key('date-clear'),
            onPressed: widget.current == null
                ? null
                : () => Navigator.of(context).pop(const Picked<DateTime>(null)),
          ),
          const SizedBox(height: AppSpace.s2),
          AppButton.primary(
            l.findDateDone,
            key: const Key('date-done'),
            onPressed: () => Navigator.of(context).pop(
              Picked<DateTime>(DateTime(_picked.year, _picked.month, _picked.day)),
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
// lib/features/find/find_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/recommendation/recommendation_models.dart';
import 'package:photobooking/data/taxonomy/builtin_taxonomy.dart';
import 'package:photobooking/features/discovery/book_entry.dart';
import 'package:photobooking/features/discovery/photographer_meta.dart';
import 'package:photobooking/features/explore/area_picker_sheet.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/find/find_controller.dart';
import 'package:photobooking/features/find/find_sheets.dart';

/// S04: compare photographers by area, day, service, price and rating.
class FindPhotographerScreen extends ConsumerStatefulWidget {
  const FindPhotographerScreen({
    super.key,
    this.initialSpecialty,
    this.initialStyle,
    this.initialArea,
  });

  final String? initialSpecialty;
  final String? initialStyle;
  final String? initialArea;

  @override
  ConsumerState<FindPhotographerScreen> createState() => _FindPhotographerScreenState();
}

class _FindPhotographerScreenState extends ConsumerState<FindPhotographerScreen> {
  final _scroll = ScrollController();
  String? _applied;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 600) {
        ref.read(findResultsProvider.notifier).loadMore();
      }
    });
    _applyInitial();
  }

  @override
  void didUpdateWidget(FindPhotographerScreen old) {
    super.didUpdateWidget(old);
    _applyInitial();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Applies the filters that came with the link, once per distinct link.
  void _applyInitial() {
    final key = '${widget.initialSpecialty}|${widget.initialStyle}|${widget.initialArea}';
    if (key == '$_applied' || key == 'null|null|null') {
      _applied = key;
      return;
    }
    _applied = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final filters = ref.read(findFiltersProvider.notifier);
      if (widget.initialSpecialty != null) {
        filters.setSpecialty(widget.initialSpecialty);
      }
      if (widget.initialStyle != null) {
        filters.setStyle(widget.initialStyle);
      }
      final areaId = widget.initialArea;
      if (areaId != null) {
        final areas = await ref.read(areasProvider.future);
        final match = areas.where((a) => a.id == areaId);
        if (match.isNotEmpty && mounted) {
          await ref.read(locationControllerProvider.notifier).chooseArea(match.first);
        }
      }
    });
  }

  DateTime _today() {
    final vn = toVn(ref.read(clockProvider)());
    return DateTime(vn.year, vn.month, vn.day);
  }

  Future<void> _pickDate(FindFilters filters) async {
    final r = await pickDate(context, current: filters.date, today: _today());
    if (r != null) {
      ref.read(findFiltersProvider.notifier).setDate(r.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final filters = ref.watch(findFiltersProvider);
    final filterCtl = ref.read(findFiltersProvider.notifier);
    final results = ref.watch(findResultsProvider);
    final origin = ref.watch(exploreResolutionProvider.select((r) => r.origin));
    final now = ref.watch(clockProvider)();

    Widget chipRow(List<Widget> chips) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.s2),
            chips[i],
          ],
        ],
      ),
    );

    List<Widget> resultSlivers() {
      if (results.isLoading) {
        return const [
          SliverPadding(
            padding: EdgeInsets.all(AppSpace.s4),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  AppSkeleton.card(height: 280),
                  SizedBox(height: AppSpace.s3),
                  AppSkeleton.card(height: 280),
                ],
              ),
            ),
          ),
        ];
      }
      if (!results.hasValue) {
        return [
          SliverToBoxAdapter(
            child: ErrorState(
              message: l.findLoadError,
              onRetry: () => ref.invalidate(findResultsProvider),
            ),
          ),
        ];
      }
      final data = results.requireValue;
      if (data.items.isEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EmptyState(
                  title: l.findNoResult,
                  body: l.findNoResultBody,
                  actionLabel: filters.hasAny ? l.findClear : null,
                  onAction: filters.hasAny ? filterCtl.clear : null,
                ),
              ],
            ),
          ),
        ];
      }
      final count = '${data.items.length}${data.cursor != null ? '+' : ''}';
      final countText = filters.date == null
          ? l.findCount(count)
          : l.findCountOnDay(count, formatDay(filters.date!));
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpace.s4, AppSpace.s2, AppSpace.s4, AppSpace.s2),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(countText, style: theme.textTheme.bodySmall),
                if (data.usedFallback)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.s1),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14),
                        const SizedBox(width: AppSpace.s1),
                        Expanded(
                          child: Text(l.findFallbackNote, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
          sliver: SliverAdaptiveRows(
            itemCount: data.items.length,
            itemBuilder: (context, i) {
              final item = data.items[i];
              final p = item.photographer;
              final day = filters.date;
              return PhotographerCard(
                key: Key('find-card-${p.id}'),
                data: p,
                reasons: item.reasons,
                distanceKm: item.distanceKm,
                availabilityLabel: day != null
                    ? l.reasonFreeOnDate(formatDayMonth(day))
                    : freeThisWeekLabel(p, now, l),
                bookLabel: day == null ? null : l.findBookDay(weekdayLabel(day.weekday)),
                onProfile: () {
                  ref.read(findResultsProvider.notifier).sendClick(item);
                  context.push('/u/${p.id}');
                },
                onBook: () => startBooking(context, ref, photographerId: p.id, date: day),
              );
            },
          ),
        ),
        if (data.loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpace.s4),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpace.s8)),
      ];
    }

    return ScreenCode(
      ScreenCodes.findPhotographer,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l.tabFind),
          actions: [
            IconButton(
              key: const Key('find-area'),
              tooltip: l.locationChooseArea,
              icon: const Icon(Icons.place_outlined),
              onPressed: () => showAreaPicker(context),
            ),
          ],
        ),
        body: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: chipRow([
                AppChip(
                  key: const Key('find-area-chip'),
                  leading: const Icon(Icons.place_outlined),
                  label: origin == null
                      ? l.locationChooseArea
                      : (origin.areaName ?? l.findNearMe),
                  selected: origin != null,
                  onChanged: (_) => showAreaPicker(context),
                ),
                AppChip(
                  key: const Key('find-date'),
                  label: filters.date == null ? l.findDate : formatDay(filters.date!),
                  selected: filters.date != null,
                  onChanged: (_) => _pickDate(filters),
                ),
                AppChip(
                  key: const Key('find-service'),
                  label: filters.specialtyId == null
                      ? l.findService
                      : specialtyLabel(filters.specialtyId!),
                  selected: filters.specialtyId != null,
                  onChanged: (_) async {
                    final r = await pickSpecialty(context, current: filters.specialtyId);
                    if (r != null) {
                      filterCtl.setSpecialty(r.value);
                    }
                  },
                ),
                if (filters.styleId != null)
                  AppChip(
                    key: const Key('find-style'),
                    label: styleLabel(filters.styleId!),
                    selected: true,
                    onChanged: (_) => filterCtl.setStyle(null),
                  ),
                AppChip(
                  key: const Key('find-price'),
                  label: filters.budgetMax == null
                      ? l.findPrice
                      : l.findPriceUnder(formatMoney(filters.budgetMax!, short: true)),
                  selected: filters.budgetMax != null,
                  onChanged: (_) async {
                    final r = await pickBudget(context, current: filters.budgetMax);
                    if (r != null) {
                      filterCtl.setBudget(r.value);
                    }
                  },
                ),
                AppChip(
                  key: const Key('find-rating'),
                  label: filters.minRating == null
                      ? l.findRating
                      : l.findRatingMin(formatRating(filters.minRating!)),
                  selected: filters.minRating != null,
                  onChanged: (_) async {
                    final r = await pickMinRating(context, current: filters.minRating);
                    if (r != null) {
                      filterCtl.setMinRating(r.value);
                    }
                  },
                ),
              ]),
            ),
            SliverToBoxAdapter(
              child: chipRow([
                for (final (key, sort, label) in [
                  ('find-sort-best', RecommendationSort.best, l.findSortBest),
                  ('find-sort-near', RecommendationSort.near, l.findSortNear),
                  ('find-sort-price', RecommendationSort.price, l.findSortPrice),
                  ('find-sort-rating', RecommendationSort.rating, l.findSortRating),
                ])
                  AppChip(
                    key: Key(key),
                    kind: AppChipKind.context,
                    label: label,
                    selected: filters.sort == sort,
                    onChanged: (_) => filterCtl.setSort(sort),
                  ),
              ]),
            ),
            ...resultSlivers(),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run and see them pass**

Run: `flutter gen-l10n && flutter test test/core/widgets/option_row_test.dart test/features/find && flutter analyze`
Expected: PASS (option row 3, controller 13, screen about 22); analyze clean. If `find.text('3')` in the date test finds two widgets (a day number and the year), use `find.descendant(of: find.byType(CalendarDatePicker), matching: find.text('3'))` and exclude the header by tapping the cell inside the grid (`find.widgetWithText(InkResponse, '3')`). If "Đánh giá" appears twice (rating chip and sort chip) in a finder, use the chip keys as the tests already do.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core lib/features/find lib/l10n test/core/widgets/option_row_test.dart test/features/find
git commit -m "feat(find): S04 Find photographer with filter sheets, sorts, reasons and fallback note

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Routes, tabs and the placeholders that go away

**Files:**
- Modify: `lib/features/shell/placeholder_tabs.dart`, `lib/app/router.dart`, `test/features/responsive_test.dart`
- Create: `test/app/discovery_routes_test.dart`

**Interfaces:**
- Consumes: `HomeScreen`, `PhotoDetailScreen`, `FindPhotographerScreen`, `ExploreScreen` (3a2).
- Produces:
  - `HomeTab` is deleted; the Home branch is `HomeScreen`.
  - `ActionTab({super.key, String? specialty, String? style, String? area})`: customers get `FindPhotographerScreen(initialSpecialty: specialty, initialStyle: style, initialArea: area)`; photographers keep the "Cho mọi người thấy bạn chụp gì" placeholder until plan 3c replaces it; nothing is shown until the profile (and so the role) is known.
  - Route `/p/:postId` (outside the tab shell, so Back returns to where the photo was opened): `PhotoDetailScreen(postId: …)`.
  - The Action branch passes the `specialty`, `style` and `area` query parameters of `/action` to `ActionTab` (the URL contract used by the Explore tiles).

- [ ] **Step 1: Write the failing test and update the responsive test**

```dart
// test/app/discovery_routes_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/app/router.dart';
import 'package:photobooking/app/tabs.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/find/find_screen.dart';
import 'package:photobooking/features/shell/placeholder_tabs.dart';

import '../support/discovery_world.dart';
import '../support/screen_host.dart';

void _collect(Iterable<RouteBase> routes, List<String> out) {
  for (final r in routes) {
    if (r is GoRoute) {
      out.add(r.path);
      _collect(r.routes, out);
    } else if (r is StatefulShellRoute) {
      for (final b in r.branches) {
        _collect(b.routes, out);
      }
    } else {
      _collect(r.routes, out);
    }
  }
}

void main() {
  test('the router knows the five tabs and the photo route', () {
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );
    addTearDown(c.dispose);
    final paths = <String>[];
    _collect(c.read(routerProvider).configuration.routes, paths);
    expect(
      paths,
      containsAll([
        for (final t in AppTab.values) t.path,
        '/p/:postId',
        '/settings',
        '/login',
      ]),
    );
  });

  testWidgets('a customer\'s middle tab is Find, and it takes the filters of the link', (
    tester,
  ) async {
    final w = DiscoveryWorld();
    await w.init();
    await tester.pumpWidget(
      screenApp(home: const ActionTab(specialty: 'wedding'), overrides: w.overrides),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FindPhotographerScreen), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('find-service')), matching: find.text('Cưới')),
      findsOneWidget,
    );
  });

  testWidgets('a photographer\'s middle tab is still the create placeholder', (tester) async {
    final w = DiscoveryWorld(role: UserRole.photographer);
    await w.init();
    await tester.pumpWidget(screenApp(home: const ActionTab(), overrides: w.overrides));
    await tester.pumpAndSettle();
    expect(find.byType(FindPhotographerScreen), findsNothing);
    expect(find.text('Cho mọi người thấy bạn chụp gì'), findsOneWidget);
  });
}
```

In `test/features/responsive_test.dart` remove the `'home': () => const HomeTab(),` entry from `_screens` (the class no longer exists). The `'action'` entry stays: the test signs in as a photographer, so it exercises the placeholder branch.

- [ ] **Step 2: Run and see it fail**

Run: `flutter test test/app/discovery_routes_test.dart`
Expected: FAIL (`ActionTab` has no `specialty` parameter, there is no `/p/:postId` route).

- [ ] **Step 3: Implement**

In `lib/features/shell/placeholder_tabs.dart`: add `import 'package:photobooking/features/find/find_screen.dart';`, delete the whole `HomeTab` class, and replace `ActionTab` with:

```dart
class ActionTab extends ConsumerWidget {
  const ActionTab({super.key, this.specialty, this.style, this.area});

  /// Filters carried by the link `/action?specialty=…&style=…&area=…`.
  final String? specialty;
  final String? style;
  final String? area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentProfileProvider).value?.role;
    if (role == null) {
      return const SizedBox.shrink();
    }
    if (role == UserRole.customer) {
      return FindPhotographerScreen(
        initialSpecialty: specialty,
        initialStyle: style,
        initialArea: area,
      );
    }
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l.tabCreate)),
      body: EmptyState(title: l.emptyCreateTitle, body: l.emptyCreateBody),
    );
  }
}
```

In `lib/app/router.dart`: add

```dart
import 'package:photobooking/features/home/home_screen.dart';
import 'package:photobooking/features/photo/photo_detail_screen.dart';
```

add this route next to the other top-level routes (before the `StatefulShellRoute`):

```dart
      GoRoute(
        path: '/p/:postId',
        builder: (_, state) =>
            PhotoDetailScreen(postId: state.pathParameters['postId']!),
      ),
```

and replace the whole `StatefulShellRoute.indexedStack(...)` element with explicit branches (the loop over a list of tabs no longer works because the Action page needs the route state):

```dart
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => TabShell(shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppTab.home.path, builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppTab.explore.path, builder: (_, _) => const ExploreScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTab.action.path,
                builder: (_, state) => ActionTab(
                  specialty: state.uri.queryParameters['specialty'],
                  style: state.uri.queryParameters['style'],
                  area: state.uri.queryParameters['area'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppTab.bookings.path, builder: (_, _) => const BookingsTab()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: AppTab.profile.path, builder: (_, _) => const ProfileTab()),
            ],
          ),
        ],
      ),
```

(`ExploreScreen` is already imported from plan 3a2. `computeRedirect` is untouched: `/p/<id>` is not an auth or onboarding route, so a deep link before sign-in resumes after login through `?from=`.)

- [ ] **Step 4: Run and see it pass**

Run: `flutter test test/app test/features/responsive_test.dart test/features/shell && flutter analyze && flutter test`
Expected: PASS; analyze clean; the whole suite is green. If analyze reports an unused import of `HomeTab` somewhere, remove that import.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/app lib/features/shell test/app test/features/responsive_test.dart
git commit -m "feat(app): route Home, Photo detail and Find; the customer middle tab is Find

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Battery and performance check

**Files:**
- Create (if missing): `test/support/idle.dart`, `test/support/blur.dart`
- Create: `test/battery/discovery_screens_battery_test.dart`
- Reference (written by the screen-codes plan, do not rewrite): `docs/testing/battery-and-performance.md`

**Interfaces:**
- Consumes: `expectIdle`, `expectBlurBudget`, `DiscoveryWorld`, `testPhotoScope`, the three screens.
- Produces: no production code (`FakePostEngagementRepository.readCalls`, added in plan 3b1, counts the reads).

What is checked: Home, Photo detail and Find leave the frame loop once loaded; no blur outside sheets; every photo is decoded at display size; long lists build only what is on screen; the screens never ask for location and share one fix; opening a screen costs a fixed, small number of reads; no stream or timer exists in these features.

- [ ] **Step 1: Write the tests**

If `test/support/idle.dart` or `test/support/blur.dart` is missing, create it with exactly the code given in plan 3a1 Task 7.

```dart
// test/battery/discovery_screens_battery_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/features/find/find_screen.dart';
import 'package:photobooking/features/home/home_screen.dart';
import 'package:photobooking/features/photo/photo_detail_screen.dart';

import '../support/blur.dart';
import '../support/content_fixtures.dart';
import '../support/discovery_world.dart';
import '../support/idle.dart';
import '../support/photo_scope.dart';
import '../support/screen_host.dart';

GoRouter _router(String start) => GoRouter(
  initialLocation: start,
  routes: [
    GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
    GoRoute(path: '/find', builder: (_, _) => const FindPhotographerScreen()),
    GoRoute(path: '/p/:id', builder: (_, s) => PhotoDetailScreen(postId: s.pathParameters['id']!)),
    GoRoute(path: '/u/:id', builder: (_, _) => const Text('profile')),
  ],
);

Future<GoRouter> _open(WidgetTester tester, DiscoveryWorld w, String start) async {
  await w.init();
  final router = _router(start);
  await tester.pumpWidget(screenRouterApp(router: router, overrides: w.overrides));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('a loaded screen leaves the frame loop', () {
    testWidgets('Home', (tester) async {
      await _open(tester, DiscoveryWorld(), '/home');
      expect(find.byKey(const Key('post-a')), findsOneWidget);
      await expectIdle(tester);
      expectBlurBudget(max: 0);
    });

    testWidgets('Photo detail', (tester) async {
      await _open(tester, DiscoveryWorld(), '/p/e');
      await expectIdle(tester);
      expectBlurBudget(max: 0);
    });

    testWidgets('Find, and Find with a filter sheet open', (tester) async {
      await _open(tester, DiscoveryWorld(), '/find');
      await expectIdle(tester);
      expectBlurBudget(max: 0);
      await tester.tap(find.byKey(const Key('find-service')));
      await expectIdle(tester);
      expectBlurBudget(max: 1);
    });
  });

  group('photos are decoded at the size they are shown', () {
    testWidgets('Home, detail and Find request bounded decode widths', (tester) async {
      tester.view.physicalSize = const Size(1170, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      for (final start in ['/home', '/p/e', '/find']) {
        final log = <PhotoRequest>[];
        final w = DiscoveryWorld();
        await w.init();
        // Hosted under a photo scope that records every request.
        await tester.pumpWidget(
          screenApp(
            home: testPhotoScope(
              log: log,
              child: switch (start) {
                '/home' => const HomeScreen(),
                '/p/e' => const PhotoDetailScreen(postId: 'e'),
                _ => const FindPhotographerScreen(),
              },
            ),
            overrides: w.overrides,
          ),
        );
        await tester.pumpAndSettle();
        expect(log, isNotEmpty, reason: start);
        for (final r in log) {
          expect(r.cacheWidth, isNotNull, reason: '${r.url} on $start');
          expect(r.cacheWidth!, lessThanOrEqualTo(1200), reason: 'full width at 390 dp x 3 is 1170 px');
        }
        // Avatars are told apart by their fixture URL (PhotoCard and the
        // PhotographerCard hero are retry:false too, so `retry` says nothing).
        expect(
          log.where((r) => r.url.contains('/avatar-')).every((r) => r.cacheWidth! <= 200),
          isTrue,
          reason: 'avatars are decoded at 48 dp or less',
        );
      }
    });
  });

  group('long lists build only what is on screen', () {
    testWidgets('Home with 200 posts', (tester) async {
      final w = DiscoveryWorld(
        posts: [for (var i = 0; i < 200; i++) fixturePost('m$i', photographerId: 'p1', age: Duration(minutes: i + 1))],
      );
      await _open(tester, w, '/home');
      expect(find.byType(PhotoCard).evaluate().length, lessThan(25));
    });

    testWidgets('Find with a full page of 20 photographers', (tester) async {
      final w = DiscoveryWorld(
        photographers: [for (var i = 0; i < 60; i++) fixturePhotographer('q$i', name: 'Thợ $i', reviews: 10 + i)],
      );
      await _open(tester, w, '/find');
      expect(find.byType(PhotographerCard).evaluate().length, lessThan(10));
    });
  });

  group('location and reads', () {
    testWidgets('none of the screens ever asks for permission', (tester) async {
      final w = DiscoveryWorld(status: LocationPermissionStatus.notAsked);
      final router = await _open(tester, w, '/home');
      router.go('/find');
      await tester.pumpAndSettle();
      router.go('/p/a');
      await tester.pumpAndSettle();
      expect(w.location.requestCalls, 0);
      expect(w.location.locationCalls, 0);
    });

    testWidgets('with permission granted, Home and Find share one fix', (tester) async {
      final w = DiscoveryWorld(status: LocationPermissionStatus.granted);
      w.location.location = ApproxLocation(lat: 10.7769, lng: 106.7009, capturedAt: fixtureNow);
      final router = await _open(tester, w, '/home');
      router.go('/find');
      await tester.pumpAndSettle();
      router.go('/home');
      await tester.pumpAndSettle();
      expect(w.location.locationCalls, 1);
    });

    testWidgets('Home does one batch of reads for the viewer\'s bookmarks, no writes', (
      tester,
    ) async {
      final w = DiscoveryWorld();
      await _open(tester, w, '/home');
      expect(w.engagement.readCalls, 1);
      expect(w.engagement.writeCalls, 0);
    });

    testWidgets('the detail screen reads the viewer\'s marks once and follow once', (
      tester,
    ) async {
      final w = DiscoveryWorld();
      await _open(tester, w, '/p/a');
      expect(w.engagement.readCalls, 2);
      expect(w.engagement.writeCalls, 0);
    });
  });

  test('no listener, polling or timer in the discovery features', () {
    for (final dir in ['home', 'photo', 'find', 'discovery', 'explore']) {
      for (final f in Directory('lib/features/$dir').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) {
          continue;
        }
        final src = f.readAsStringSync();
        for (final banned in ['StreamProvider', '.snapshots(', 'Timer(', 'Timer.periodic', 'Stream.periodic', 'AnimationController']) {
          expect(src, isNot(contains(banned)), reason: '${f.path}: $banned');
        }
      }
    }
  });
}
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/battery/discovery_screens_battery_test.dart`
Expected: PASS (13 tests). A failure names the culprit. An idle failure means a spinner or controller is alive after loading; a decode failure means a `NetworkPhoto` has an unbounded width or a card shows a photo twice as wide as its box; a read-count failure means a screen fetches more than the fixed set; fix the code, not the test.

- [ ] **Step 3: Fix anything the run found**

Re-run Step 2 until green.

- [ ] **Step 4: Manual profiling**

Follow `docs/testing/battery-and-performance.md` (written by the screen-codes plan; do not rewrite it) on a mid-range Android phone in profile mode, with at least 100 posts and 50 photographers in the project:

1. Home: scroll to the end and back three times, switch each chip once, pull to refresh; then leave it idle for 5 minutes.
2. Photo detail: open ten photos in a row from Home, swipe a three-image post, like and unlike.
3. Find: change each filter once, switch the four sorts, open a date sheet; then idle for 5 minutes.
4. Grant location once from Explore and confirm Home and Find add no second GPS use (`dumpsys batterystats`, GPS ≤ 15 seconds in total).

- Android: `flutter run --profile`; `adb shell dumpsys gfxinfo`, `top`, `batterystats` and `meminfo` as in the guide (idle frames ≤ 5 per 30 s, janky frames < 5 %, p90 ≤ 16 ms, CPU idle < 3 %, PSS < 250 MB).
- iOS: Xcode Instruments (Time Profiler, Allocations and Energy Log) on a real iPhone, or the Simulator's Debug Navigator CPU, Memory and Energy gauges; Energy Impact must read "Low" at rest and memory must plateau while scrolling the feed. Prerequisite: iOS cannot be built on this machine yet (no Xcode, no CocoaPods, no iOS Firebase configuration); that is a separate "iOS enablement" plan, so until it lands record "iOS: not measured, blocked by iOS enablement".

Record the results in the PR description with the table template of the guide; add the iOS rows with the iPhone model in the Thiết bị column and Energy Impact in place of the Android-only columns.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add test/support test/battery
git commit -m "test: idle, blur, decode-size and read-count checks for Home, Photo detail and Find

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** S01 — greeting and title, category chips (Dành cho bạn, Chân dung, Cưới, Gia đình, Kỷ yếu), 4:5 card with the pills "Rảnh T7 này" and "Chân dung · từ 1,5M", "Rảnh tuần này" (3:4, 120dp, "Xem tất cả" to S04), "Buổi chụp thật", reasons (at most two), pages of 20, pull to refresh, per-chip scroll position, empty state with the way to Explore, error with retry, two columns from 600dp, optimistic save with undo (Tasks 1, 2). S02 — gallery with dots and double-tap like, author row with tick and follow, counts, location, package card (faded and "Xem các gói khác" when retired), "Thêm của …", real-shoot line, removed-post state, "Đặt gói này" through the phone gate to the booking with the package chosen (Tasks 1, 3). S04 — filter chips for area, day, service, price and rating with sheets, sorts, count line, `PhotographerCard` with reasons and "Đặt {thứ}", fallback note, empty state, links from Explore (`specialty`, `style`, `area`), two columns, paging (Task 4). Routes and tabs (Task 5); battery and performance (Task 6).
- **Deviations (flagged):** (1) the bell and chat icons of S01 are not built; (2) share and report on S02 are not built (no link domain, no report backend); (3) the author name sits in a row under the large card, not over the photo, so that the whole photo can open S02 while the name opens S03; (4) the date filter uses Flutter's `CalendarDatePicker` in a sheet until plan 2d's `AvailabilityCalendar` exists; (5) the impression signal is not sent (needs visibility tracking), only `click`; (6) "nới bán kính" hint of the S04 empty state is not offered because the recommender has no radius; (7) the rating chip is applied on the device because the API context has no `minRating`; (8) a style filter was added to `PhotographerSummary` and `RecommendationQuery` so the Explore "Phong cách" tiles lead somewhere real.
- **Cross-plan dependencies:** `/u/:uid` (S03, plan 2d) and `/u/:uid/book` (step 4) are linked by path; until they exist the links show go_router's error page and the screens' tests use stub routes. `currentContactProvider`, `FakeUserContactRepository` and `/profile/phone?returnTo=` come from plan 2a. Plan 3c replaces the photographer half of `ActionTab`.
- **Placeholders:** none. **Type consistency:** `EngagementController.seed/load/toggleLike/toggleSave`, `FollowController.load/toggle`, `bookingPath`/`startBooking`, `areaRatingMeta`/`freeThisWeekLabel`, `HomeFeedController.selectCategory/refresh/loadMore`, `postDetailProvider`, `FindFilters`/`FindFiltersController`, `FindResults`/`FindResultsController.sendClick`, `Picked<T>`, `OptionRow`, `DiscoveryWorld` and the widget keys are named identically in tests and code.
- **Battery and performance (Task 6):** idle after load on all three screens (and Find with a sheet), blur budget 0 outside sheets, decode width on every photo (avatars at most 200 px), lazy lists, no permission prompt and one shared fix, fixed read counts, no stream or timer in the feature folders, and the manual Android and iOS table per `docs/testing/battery-and-performance.md`.
- **Risks:** the scroll-restore test depends on estimated sliver extents (Task 2 Step 4 says how to relax it); `CalendarDatePicker` digit lookup in the date test (Task 4 Step 4); a customer without a profile yet sees an empty middle tab for a moment (by design: no query runs before the role is known).
