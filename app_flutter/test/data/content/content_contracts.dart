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
  fixturePost(
    'c',
    age: const Duration(hours: 3),
    kind: PostKind.realShoot,
    authorId: 'u9',
  ),
  fixturePost('d', age: const Duration(hours: 4), photographerId: 'p2'),
  fixturePost('e', age: const Duration(hours: 5)),
];

typedef PostRepoFactory = Future<PostRepository> Function(
  List<PostSummary> seed,
);

void postRepositoryContract(String name, PostRepoFactory create) {
  group('PostRepository contract: $name', () {
    List<String> ids(PostPage p) => p.posts.map((e) => e.id).toList();

    Future<List<String>> walk(
      Future<PostPage> Function(String? cursor) fetch,
    ) async {
      final out = <String>[];
      String? cursor;
      for (var guard = 0; guard < 100; guard++) {
        final page = await fetch(cursor);
        out.addAll(ids(page));
        cursor = page.nextCursor;
        if (cursor == null) {
          return out;
        }
      }
      fail('paging did not terminate');
    }

    test('feed is newest first', () async {
      final repo = await create(contractPosts());
      expect(ids(await repo.feed()), ['a', 'b', 'c', 'd', 'e']);
    });

    test(
      'pages are disjoint, complete, and the last one has no cursor',
      () async {
        final repo = await create(contractPosts());
        final p1 = await repo.feed(limit: 2);
        expect(ids(p1), ['a', 'b']);
        expect(p1.nextCursor, isNotNull);
        final p2 = await repo.feed(limit: 2, cursor: p1.nextCursor);
        expect(ids(p2), ['c', 'd']);
        final p3 = await repo.feed(limit: 2, cursor: p2.nextCursor);
        expect(ids(p3), ['e']);
        expect(p3.nextCursor, isNull);
      },
    );

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
      expect(
        ids(await repo.feed(kind: PostKind.realShoot, specialtyId: 'wedding')),
        isEmpty,
      );
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

    test(
      'a page size over 50 is clamped and the cursor reaches the rest',
      () async {
        final many = [
          for (var i = 0; i < 60; i++)
            fixturePost('m$i', age: Duration(minutes: i + 1)),
        ];
        final repo = await create(many);
        final page = await repo.feed(limit: 1000);
        expect(page.posts, hasLength(50));
        expect(page.nextCursor, isNotNull);
        final page2 = await repo.feed(limit: 1000, cursor: page.nextCursor);
        expect(page2.posts, hasLength(10));
        expect(page2.nextCursor, isNull);
      },
    );

    test('a page size of 0 or below returns exactly one post', () async {
      final repo = await create(contractPosts());
      expect((await repo.feed(limit: 0)).posts, hasLength(1));
      expect((await repo.feed(limit: -5)).posts, hasLength(1));
      expect((await repo.byPhotographer('p1', limit: 0)).posts, hasLength(1));
    });

    test(
      'posts with the same time order by id descending, across pages',
      () async {
        final tied = [
          for (final id in ['t1', 't2', 't3', 't4', 't5'])
            fixturePost(id, age: const Duration(hours: 1)),
          fixturePost('old', age: const Duration(hours: 9)),
        ];
        final repo = await create(tied);
        final full = ids(await repo.feed());
        expect(full, ['t5', 't4', 't3', 't2', 't1', 'old']);
        expect(ids(await repo.feed()), full, reason: 'stable between calls');
        expect(await walk((c) => repo.feed(limit: 2, cursor: c)), full);
        expect(await walk((c) => repo.feed(limit: 3, cursor: c)), full);
      },
    );

    test(
      'walking with a kind filter is complete with others interleaved',
      () async {
        final repo = await create(_interleaved());
        final expected = [
          for (var i = 0; i < 12; i++)
            if (i % 3 == 0) 'x$i',
        ];
        expect(
          await walk(
            (c) => repo.feed(kind: PostKind.realShoot, limit: 3, cursor: c),
          ),
          expected,
        );
        expect(
          await walk(
            (c) => repo.feed(kind: PostKind.realShoot, limit: 1, cursor: c),
          ),
          expected,
        );
      },
    );

    test(
      'walking with a specialty filter is complete with others interleaved',
      () async {
        final repo = await create(_interleaved());
        final expected = [
          for (var i = 0; i < 12; i++)
            if (i % 2 == 0) 'x$i',
        ];
        expect(
          await walk(
            (c) => repo.feed(specialtyId: 'wedding', limit: 2, cursor: c),
          ),
          expected,
        );
      },
    );

    test(
      'walking byPhotographer is complete with others interleaved',
      () async {
        final repo = await create(_interleaved());
        final expected = [
          for (var i = 0; i < 12; i++)
            if (i % 4 == 0) 'x$i',
        ];
        expect(
          await walk((c) => repo.byPhotographer('p2', limit: 2, cursor: c)),
          expected,
        );
      },
    );

    test(
      'an unknown or stale cursor gives an empty page without a cursor',
      () async {
        final repo = await create(contractPosts());
        final feed = await repo.feed(cursor: 'no-such-post');
        expect(feed.posts, isEmpty);
        expect(feed.nextCursor, isNull);
        final mine = await repo.byPhotographer('p1', cursor: 'no-such-post');
        expect(mine.posts, isEmpty);
        expect(mine.nextCursor, isNull);
      },
    );
  });
}

/// 12 posts, `x0` newest. Kind real_shoot when i % 3 == 0, specialty wedding
/// when i % 2 == 0, photographer p2 when i % 4 == 0 (else p1).
List<PostSummary> _interleaved() => [
  for (var i = 0; i < 12; i++)
    fixturePost(
      'x$i',
      age: Duration(minutes: i + 1),
      kind: i % 3 == 0 ? PostKind.realShoot : PostKind.work,
      specialtyId: i % 2 == 0 ? 'wedding' : 'portrait',
      photographerId: i % 4 == 0 ? 'p2' : 'p1',
    ),
];

void engagementContract(
  String name,
  Future<PostEngagementRepository> Function() create,
) {
  group('PostEngagementRepository contract: $name', () {
    test(
      'starts empty; like and save are independent and reversible',
      () async {
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
      },
    );

    test('setters are idempotent, checked after every call', () async {
      final repo = await create();
      Future<void> check(
        Future<void> Function(bool) set,
        Future<bool> Function() read,
      ) async {
        for (final v in [true, true, false, false]) {
          await set(v);
          expect(await read(), v);
        }
      }

      await check(
        (v) => repo.setLiked('u1', 'a', v),
        () async => (await repo.engagementFor('u1', 'a')).liked,
      );
      await check(
        (v) => repo.setSaved('u1', 'a', v),
        () async => (await repo.engagementFor('u1', 'a')).saved,
      );
      await check(
        (v) => repo.setFollowing('u1', 'p1', v),
        () => repo.isFollowing('u1', 'p1'),
      );
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
  fixturePhotographer(
    'p1',
    name: 'Minh Trí',
    verified: true,
    nextFreeDate: '2026-10-03',
    rating: 4.9,
    startingPrice: 1500000,
    styles: const ['natural_light', 'film'],
  ),
  fixturePhotographer(
    'p2',
    name: 'Hồng Nhung',
    nextFreeDate: '2026-10-01',
    rating: 4.5,
  ),
  fixturePhotographer(
    'p3',
    name: 'Quốc Bảo',
    nextFreeDate: '2026-10-03',
    rating: 4.95,
  ),
  fixturePhotographer('p4', name: 'Thu Hà', nextFreeDate: '2026-10-08'),
  fixturePhotographer('p5', name: 'Gia Bảo', nextFreeDate: '2026-09-30'),
  fixturePhotographer('p6', name: 'Bích Ngọc'),
];

typedef PhotographerRepoFactory = Future<PhotographerRepository> Function(
  List<PhotographerSummary> seed,
);

void photographerRepositoryContract(
  String name,
  PhotographerRepoFactory create,
) {
  group('PhotographerRepository contract: $name', () {
    test(
      'summaries returns the asked ids that exist, with their fields',
      () async {
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
      },
    );

    test('freeThisWeek is the Vietnamese day window [today, today + 7), soonest then best rated', () async {
      final repo = await create(contractPhotographers());
      final free = await repo.freeThisWeek(now: fixtureNow);
      expect(free.map((p) => p.id), ['p2', 'p3', 'p1']);
    });

    test(
      'freeThisWeek uses the Vietnamese day, not the UTC day (lower edge)',
      () async {
        final repo = await create(contractPhotographers());
        // 2026-10-01 01:00 in Vietnam: 09-30 is yesterday, 10-01 is today.
        final free = await repo.freeThisWeek(
          now: DateTime.utc(2026, 9, 30, 18),
        );
        expect(free.map((p) => p.id), ['p2', 'p3', 'p1']);
      },
    );

    test('freeThisWeek window ends before today + 7 (upper edge)', () async {
      final repo = await create(contractPhotographers());
      // 2026-10-08 01:00 in Vietnam: window [10-08, 10-15).
      final free = await repo.freeThisWeek(now: DateTime.utc(2026, 10, 7, 18));
      expect(free.map((p) => p.id), ['p4']);
      // 2026-10-07 23:00 in Vietnam: window [10-07, 10-14) already holds 10-08.
      final before = await repo.freeThisWeek(
        now: DateTime.utc(2026, 10, 7, 16),
      );
      expect(before.map((p) => p.id), ['p4']);
      // 2026-10-01 12:00: 10-08 is exactly today + 7, so it is out.
      final today = await repo.freeThisWeek(now: fixtureNow);
      expect(today.map((p) => p.id), isNot(contains('p4')));
    });

    test('freeThisWeek ties on day and rating go to the smaller id', () async {
      final repo = await create([
        fixturePhotographer('z', nextFreeDate: '2026-10-02', rating: 4.0),
        fixturePhotographer('a', nextFreeDate: '2026-10-02', rating: 4.0),
        fixturePhotographer('b', nextFreeDate: '2026-10-02', rating: 4.0),
      ]);
      final free = await repo.freeThisWeek(now: fixtureNow);
      expect(free.map((p) => p.id), ['a', 'b', 'z']);
    });

    test('freeThisWeek clamps its limit to at most 50', () async {
      final repo = await create([
        for (var i = 0; i < 55; i++)
          fixturePhotographer('f$i', nextFreeDate: '2026-10-02'),
      ]);
      expect(
        await repo.freeThisWeek(now: fixtureNow, limit: 1000),
        hasLength(50),
      );
    });

    test(
      'freeThisWeek honours the limit and clamps it to at least 1',
      () async {
        final repo = await create(contractPhotographers());
        expect(
          await repo.freeThisWeek(now: fixtureNow, limit: 1),
          hasLength(1),
        );
        expect(
          await repo.freeThisWeek(now: fixtureNow, limit: 0),
          hasLength(1),
        );
        expect(
          await repo.freeThisWeek(now: fixtureNow, limit: -1),
          hasLength(1),
        );
      },
    );

    test('summaries accepts more ids than a single whereIn allows', () async {
      final seed = [for (var i = 0; i < 35; i++) fixturePhotographer('q$i')];
      final repo = await create(seed);
      final m = await repo.summaries([
        for (var i = 0; i < 35; i++) 'q$i',
        'ghost',
      ]);
      expect(m.keys.toSet(), {for (var i = 0; i < 35; i++) 'q$i'});
    });

    test('candidates honours the limit', () async {
      final repo = await create(contractPhotographers());
      expect(await repo.candidates(limit: 3), hasLength(3));
      expect((await repo.candidates()).length, 6);
    });

    test('candidates clamps its limit to 1..200', () async {
      final repo = await create([
        for (var i = 0; i < 205; i++) fixturePhotographer('c$i'),
      ]);
      expect(await repo.candidates(limit: 0), hasLength(1));
      expect(await repo.candidates(limit: -1), hasLength(1));
      expect(await repo.candidates(limit: 1000), hasLength(200));
    });
  });
}

typedef ServiceRepoFactory = Future<ServiceRepository> Function(
  List<ServiceSummary> seed,
);

List<ServiceSummary> contractServices() => [
  fixtureService('s1'),
  fixtureService(
    's2',
    name: 'Cặp đôi nửa ngày',
    price: 3200000,
    specialtyId: 'couple',
  ),
  fixtureService('s3', name: 'Gói cũ', active: false),
  fixtureService(
    't1',
    photographerId: 'p2',
    name: 'Cưới cả ngày',
    price: 8000000,
    specialtyId: 'wedding',
  ),
];

void serviceRepositoryContract(String name, ServiceRepoFactory create) {
  group('ServiceRepository contract: $name', () {
    test(
      'byId finds one service with its details, only under its photographer',
      () async {
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
      },
    );

    test(
      'an inactive service can still be found by id but is not listed',
      () async {
        final repo = await create(contractServices());
        expect((await repo.byId('p1', 's3'))!.active, isFalse);
        final listed = await repo.activeFor('p1');
        expect(listed.map((s) => s.id).toSet(), {'s1', 's2'});
      },
    );

    test('activeFor clamps its limit to 1..50', () async {
      final repo = await create([
        for (var i = 0; i < 55; i++) fixtureService('v$i'),
      ]);
      expect(await repo.activeFor('p1'), hasLength(50));
      expect(await repo.activeFor('p1', limit: 0), hasLength(1));
      expect(await repo.activeFor('p1', limit: 1000), hasLength(50));
    });
  });
}

PostSummary fixturePostNewest() =>
    fixturePost('new', age: const Duration(seconds: 1));
