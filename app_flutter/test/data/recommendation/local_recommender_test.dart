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

List<String> ids(RecommendationPage p) =>
    p.items.map((e) => e.photographer.id).toList();

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
    test(
      'a well-reviewed photographer beats a perfect score from one review',
      () async {
        final r = make(
          photographers: [
            fixturePhotographer('few', rating: 5, reviews: 1, completed: 1),
            fixturePhotographer(
              'many',
              rating: 4.9,
              reviews: 58,
              completed: 112,
            ),
          ],
        );
        expect(
          ids(await r.recommendPhotographers(const RecommendationQuery())),
          ['many', 'few'],
        );
      },
    );

    test('a closer photographer wins when quality is equal', () async {
      final r = make(
        photographers: [
          fixturePhotographer('far', lat: 21.0285, lng: 105.8542),
          fixturePhotographer('near', lat: 10.7869, lng: 106.7009),
        ],
      );
      final page = await r.recommendPhotographers(
        RecommendationQuery(geohash6: _hcm6),
      );
      expect(ids(page), ['near', 'far']);
      expect(page.items.first.distanceKm, lessThan(5));
      expect(page.items.last.distanceKm, greaterThan(1000));
    });

    test(
      'without a position, distance is neutral and ties fall back to id',
      () async {
        final r = make(
          photographers: [fixturePhotographer('b'), fixturePhotographer('a')],
        );
        expect(
          ids(await r.recommendPhotographers(const RecommendationQuery())),
          ['a', 'b'],
        );
      },
    );

    test('free soon outranks free later at equal quality', () async {
      final r = make(
        photographers: [
          fixturePhotographer('later', nextFreeDate: '2026-11-20'),
          fixturePhotographer('soon', nextFreeDate: '2026-10-02'),
        ],
      );
      expect(ids(await r.recommendPhotographers(const RecommendationQuery())), [
        'soon',
        'later',
      ]);
    });

    test('sort modes: near, price, rating', () async {
      final r = make(
        photographers: [
          fixturePhotographer(
            'a',
            lat: 21.0285,
            lng: 105.8542,
            startingPrice: 900000,
            rating: 4.0,
            reviews: 30,
          ),
          fixturePhotographer(
            'b',
            lat: 10.7869,
            lng: 106.7009,
            startingPrice: 3000000,
            rating: 4.9,
            reviews: 60,
          ),
          fixturePhotographer(
            'c',
            lat: 10.9,
            lng: 106.7,
            startingPrice: null,
            rating: 4.5,
            reviews: 40,
          ),
        ],
      );
      Future<List<String>> by(RecommendationSort s) async => ids(
        await r.recommendPhotographers(
          RecommendationQuery(sort: s, geohash6: _hcm6),
        ),
      );
      expect(await by(RecommendationSort.near), ['b', 'c', 'a']);
      expect(await by(RecommendationSort.price), [
        'a',
        'b',
        'c',
      ], reason: 'unknown price last');
      expect(await by(RecommendationSort.rating), ['b', 'c', 'a']);
    });
  });

  group('filters', () {
    final pool = [
      fixturePhotographer(
        'p',
        specialties: const ['portrait'],
        startingPrice: 1000000,
      ),
      fixturePhotographer(
        'w',
        specialties: const ['wedding'],
        startingPrice: 8000000,
      ),
      fixturePhotographer(
        'u',
        specialties: const ['portrait'],
        startingPrice: null,
      ),
    ];

    test('style keeps only photographers who list it', () async {
      final r = make(
        photographers: [
          fixturePhotographer('film', styles: const ['film']),
          fixturePhotographer('natural', styles: const ['natural_light']),
          fixturePhotographer('none'),
        ],
      );
      expect(
        ids(
          await r.recommendPhotographers(
            const RecommendationQuery(styleId: 'film'),
          ),
        ),
        ['film'],
      );
    });

    test('specialty and budget; an unknown price passes the budget', () async {
      final r = make(photographers: pool);
      expect(
        ids(
          await r.recommendPhotographers(
            const RecommendationQuery(
              specialtyId: 'portrait',
              budgetMax: 2000000,
            ),
          ),
        ).toSet(),
        {'p', 'u'},
      );
      expect(
        ids(
          await r.recommendPhotographers(
            const RecommendationQuery(budgetMax: 2000000),
          ),
        ).toSet(),
        {'p', 'u'},
      );
    });

    test('a booked or day-off photographer is dropped for the picked date, a pending one stays', () async {
      final availability = FakeAvailabilityLookup()
        ..set('p', '2026-10-12', DayAvailability.booked)
        ..set('w', '2026-10-12', DayAvailability.off)
        ..set('u', '2026-10-12', DayAvailability.pending);
      final r = make(photographers: pool, availability: availability);
      final page = await r.recommendPhotographers(
        RecommendationQuery(date: DateTime.utc(2026, 10, 12)),
      );
      expect(ids(page), ['u']);
      expect(
        page.items.single.reasons.map((e) => e.code),
        isNot(contains(ReasonCode.freeOnDate)),
        reason: 'pending is not "free"',
      );
    });

    test('a pending photographer ranks below an equal free one', () async {
      final availability = FakeAvailabilityLookup()
        ..set('x', '2026-10-12', DayAvailability.pending);
      final r = make(
        photographers: [fixturePhotographer('x'), fixturePhotographer('y')],
        availability: availability,
      );
      final page = await r.recommendPhotographers(
        RecommendationQuery(date: DateTime.utc(2026, 10, 12)),
      );
      expect(ids(page), ['y', 'x']);
    });

    test(
      'with a date at most 60 day documents are read, best quality first',
      () async {
        final availability = FakeAvailabilityLookup();
        final many = [
          for (var i = 0; i < 100; i++)
            fixturePhotographer(
              'c${i.toString().padLeft(3, '0')}',
              reviews: 10 + i,
              rating: 4.9,
            ),
        ];
        final r = make(photographers: many, availability: availability);
        await r.recommendPhotographers(
          RecommendationQuery(date: DateTime.utc(2026, 10, 12)),
        );
        expect(availability.requested.single, hasLength(60));
        expect(
          availability.requested.single,
          contains('c099'),
          reason: 'the most reviewed are kept',
        );
        expect(availability.requested.single, isNot(contains('c000')));
      },
    );

    test('no date means no availability reads', () async {
      final availability = FakeAvailabilityLookup();
      await make(
        photographers: pool,
        availability: availability,
      ).recommendPhotographers(const RecommendationQuery());
      expect(availability.requested, isEmpty);
    });
  });

  group('reasons', () {
    Future<List<Reason>> reasonsFor(
      PhotographerSummary p,
      RecommendationQuery q,
    ) async =>
        (await make(photographers: [p]).recommendPhotographers(q))
            .items
            .single
            .reasons;

    test(
      'free on the picked date, specialty and near come first, at most three',
      () async {
        final p = fixturePhotographer(
          'p1',
          lat: 10.7869,
          lng: 106.7009,
          nextFreeDate: '2026-10-03',
          responseMinutes: 30,
        );
        final reasons = await reasonsFor(
          p,
          RecommendationQuery(
            specialtyId: 'portrait',
            date: DateTime.utc(2026, 10, 3),
            geohash6: _hcm6,
          ),
        );
        expect(reasons.map((r) => r.code), [
          ReasonCode.freeOnDate,
          ReasonCode.skillMatch,
          ReasonCode.near,
        ]);
        expect(reasons[0].text, 'Rảnh T7 03/10');
        expect(reasons[1].text, 'Chuyên chân dung');
        expect(reasons[2].text, startsWith('Cách '));
        expect(reasons[2].text, endsWith(' km'));
      },
    );

    test('without filters: next free day, top rated, fast reply', () async {
      final p = fixturePhotographer(
        'p1',
        nextFreeDate: '2026-10-03',
        rating: 4.9,
        reviews: 58,
        responseMinutes: 45,
      );
      final reasons = await reasonsFor(p, const RecommendationQuery());
      expect(reasons.map((r) => r.code), [
        ReasonCode.freeOnDate,
        ReasonCode.topRated,
        ReasonCode.fastReply,
      ]);
      expect(reasons[1].text, '★ 4,9 · 58 đánh giá');
      expect(reasons[2].text, 'Phản hồi nhanh');
    });

    test(
      'a new profile gets the "Mới tham gia" reason, an old one does not',
      () async {
        final fresh = await reasonsFor(
          fixturePhotographer(
            'n',
            reviews: 0,
            rating: 0,
            createdAgo: const Duration(days: 10),
            responseMinutes: 600,
          ),
          const RecommendationQuery(),
        );
        expect(fresh.map((r) => r.code), [ReasonCode.newTalent]);
        expect(fresh.single.text, 'Mới tham gia');
        final old = await reasonsFor(
          fixturePhotographer('o', reviews: 0, rating: 0, responseMinutes: 600),
          const RecommendationQuery(),
        );
        expect(old, isEmpty);
      },
    );

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
      final r = make(
        photographers: [
          for (var i = 0; i < 5; i++)
            fixturePhotographer('p$i', reviews: 10 + i),
        ],
      );
      final p1 = await r.recommendPhotographers(
        const RecommendationQuery(limit: 2),
      );
      expect(p1.nextCursor, '2');
      expect(p1.items.map((e) => e.rank), [1, 2]);
      final p2 = await r.recommendPhotographers(
        RecommendationQuery(limit: 2, cursor: p1.nextCursor),
      );
      expect(p2.items.map((e) => e.rank), [3, 4]);
      final p3 = await r.recommendPhotographers(
        RecommendationQuery(limit: 2, cursor: p2.nextCursor),
      );
      expect(p3.items.map((e) => e.rank), [5]);
      expect(p3.nextCursor, isNull);
    });

    test('a broken cursor restarts at the top', () async {
      final r = make(
        photographers: [fixturePhotographer('a'), fixturePhotographer('b')],
      );
      final page = await r.recommendPhotographers(
        const RecommendationQuery(cursor: 'oops'),
      );
      expect(page.items.first.rank, 1);
    });

    test('identifies itself', () async {
      final page = await make().recommendPhotographers(
        const RecommendationQuery(),
      );
      expect(page.algorithm, 'local-fallback');
      expect(page.algorithmVersion, '1.0.0');
      expect(page.requestId, startsWith('local-'));
      expect(page.usedFallback, isFalse);
      expect(page.items, isEmpty);
    });
  });

  group('similar', () {
    test(
      'shares a specialty, excludes itself, closest overlap first',
      () async {
        final r = make(
          photographers: [
            fixturePhotographer(
              'me',
              specialties: const ['portrait', 'wedding'],
            ),
            fixturePhotographer(
              'both',
              specialties: const ['portrait', 'wedding'],
            ),
            fixturePhotographer(
              'one',
              specialties: const ['portrait', 'family'],
            ),
            fixturePhotographer('none', specialties: const ['food']),
          ],
        );
        final page = await r.similar('me');
        expect(ids(page), ['both', 'one']);
        expect(page.items.first.reasons.first.code, ReasonCode.skillMatch);
      },
    );

    test(
      'an unknown photographer has no similar ones, and the limit holds',
      () async {
        final r = make(
          photographers: [
            for (var i = 0; i < 12; i++) fixturePhotographer('p$i'),
          ],
        );
        expect((await r.similar('ghost')).items, isEmpty);
        expect((await r.similar('p0', limit: 3)).items, hasLength(3));
      },
    );
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
      fixturePost(
        'shoot',
        photographerId: 'soon',
        kind: PostKind.realShoot,
        age: const Duration(minutes: 5),
      ),
    ];

    test('photographers free in the next 14 days come first; others keep their order', () async {
      final page = await make(
        photographers: photographers,
        posts: posts,
      ).recommendPosts(const PostRecommendationQuery());
      expect(page.items.map((e) => e.post.id), ['b', 'e', 'a', 'd']);
      expect(page.items.map((e) => e.rank), [1, 2, 3, 4]);
    });

    test(
      'real-shoot posts and posts of unknown authors are not in the feed',
      () async {
        final page = await make(
          photographers: photographers,
          posts: posts,
        ).recommendPosts(const PostRecommendationQuery());
        expect(page.items.map((e) => e.post.id), isNot(contains('shoot')));
        expect(page.items.map((e) => e.post.id), isNot(contains('c')));
      },
    );

    test('boosted posts say why', () async {
      final page = await make(
        photographers: photographers,
        posts: posts,
      ).recommendPosts(const PostRecommendationQuery());
      expect(page.items.first.reasons.single.code, ReasonCode.freeOnDate);
      expect(page.items.first.reasons.single.text, 'Rảnh T2 05/10');
      expect(page.items.last.reasons, isEmpty);
    });

    test(
      'category filter and paging pass through to the post repository',
      () async {
        final tagged = [
          fixturePost(
            'w1',
            photographerId: 'soon',
            specialtyId: 'wedding',
            age: const Duration(hours: 1),
          ),
          fixturePost(
            'w2',
            photographerId: 'soon',
            specialtyId: 'wedding',
            age: const Duration(hours: 2),
          ),
          fixturePost(
            'p1',
            photographerId: 'soon',
            specialtyId: 'portrait',
            age: const Duration(hours: 3),
          ),
        ];
        final r = make(photographers: photographers, posts: tagged);
        final first = await r.recommendPosts(
          const PostRecommendationQuery(specialtyId: 'wedding', limit: 1),
        );
        expect(first.items.map((e) => e.post.id), ['w1']);
        expect(first.nextCursor, isNotNull);
        final second = await r.recommendPosts(
          PostRecommendationQuery(
            specialtyId: 'wedding',
            limit: 1,
            cursor: first.nextCursor,
          ),
        );
        expect(second.items.map((e) => e.post.id), ['w2']);
        expect(second.nextCursor, isNull);
      },
    );
  });

  test('sendFeedback accepts anything and never throws', () async {
    final r = make();
    await r.sendFeedback(const []);
    await r.sendFeedback([
      RecommendationSignal(
        type: SignalType.click,
        requestId: 'r',
        photographerId: 'p1',
        rank: 1,
        at: fixtureNow,
      ),
    ]);
  });
}
