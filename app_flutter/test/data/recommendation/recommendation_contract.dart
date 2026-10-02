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
    fixturePhotographer(
      'p1',
      specialties: const ['portrait', 'wedding'],
      rating: 4.9,
      reviews: 58,
      startingPrice: 1500000,
      nextFreeDate: '2026-10-03',
    ),
    fixturePhotographer(
      'p2',
      specialties: const ['wedding'],
      rating: 4.5,
      reviews: 12,
      startingPrice: 8000000,
    ),
    fixturePhotographer(
      'p3',
      specialties: const ['portrait'],
      rating: 4.95,
      reviews: 200,
      startingPrice: 2000000,
    ),
    fixturePhotographer(
      'p4',
      specialties: const ['family'],
      rating: 3.9,
      reviews: 5,
      startingPrice: 1200000,
    ),
    fixturePhotographer(
      'p5',
      specialties: const ['portrait'],
      rating: 0,
      reviews: 0,
      startingPrice: 1000000,
      createdAgo: const Duration(days: 10),
    ),
    fixturePhotographer(
      'p6',
      specialties: const ['portrait'],
      rating: 4.6,
      reviews: 30,
      startingPrice: 9000000,
    ),
  ],
  posts: [
    fixturePost('post1', photographerId: 'p1', age: const Duration(hours: 1)),
    fixturePost('post2', photographerId: 'p2', age: const Duration(hours: 2)),
    fixturePost(
      'post3',
      photographerId: 'ghost',
      age: const Duration(hours: 3),
    ),
  ],
  unavailable: {
    'p3': {'2026-10-12'},
  },
);

typedef RecommendationFactory = Future<RecommendationRepository> Function(
  RecommendationWorld world,
);

/// Invariants that hold for any ranking algorithm. A new implementation (the
/// remote client, a learned ranker) must pass these unchanged.
void recommendationRepositoryContract(
  String name,
  RecommendationFactory create,
) {
  group('RecommendationRepository contract: $name', () {
    late RecommendationRepository repo;
    setUp(() async => repo = await create(contractWorld()));

    List<String> ids(RecommendationPage p) =>
        p.items.map((e) => e.photographer.id).toList();

    test(
      'returns every candidate once, ranked 1..n, with response metadata',
      () async {
        final page = await repo.recommendPhotographers(
          const RecommendationQuery(),
        );
        expect(ids(page).toSet(), {'p1', 'p2', 'p3', 'p4', 'p5', 'p6'});
        expect(ids(page), hasLength(6));
        expect(page.items.map((e) => e.rank), [1, 2, 3, 4, 5, 6]);
        expect(page.requestId, isNotEmpty);
        expect(page.algorithm, isNotEmpty);
        expect(page.algorithmVersion, isNotEmpty);
        for (final item in page.items) {
          expect(item.score, inInclusiveRange(0, 1));
        }
      },
    );

    test('scores never increase down the list for the default order', () async {
      final page = await repo.recommendPhotographers(
        const RecommendationQuery(),
      );
      final scores = page.items.map((e) => e.score).toList();
      for (var i = 1; i < scores.length; i++) {
        expect(scores[i], lessThanOrEqualTo(scores[i - 1]));
      }
    });

    test('a specialty keeps only photographers who offer it', () async {
      final page = await repo.recommendPhotographers(
        const RecommendationQuery(specialtyId: 'portrait'),
      );
      expect(ids(page).toSet(), {'p1', 'p3', 'p5', 'p6'});
    });

    test(
      'a busy photographer is absent on the picked day and present otherwise',
      () async {
        final busy = await repo.recommendPhotographers(
          RecommendationQuery(date: DateTime.utc(2026, 10, 12)),
        );
        expect(ids(busy), isNot(contains('p3')));
        expect(ids(busy).toSet(), {'p1', 'p2', 'p4', 'p5', 'p6'});
        final other = await repo.recommendPhotographers(
          RecommendationQuery(date: DateTime.utc(2026, 10, 13)),
        );
        expect(ids(other), contains('p3'));
      },
    );

    test('a budget removes the expensive ones', () async {
      final page = await repo.recommendPhotographers(
        const RecommendationQuery(budgetMax: 3000000),
      );
      expect(ids(page).toSet(), {'p1', 'p3', 'p4', 'p5'});
    });

    test('excluded ids are never returned', () async {
      final page = await repo.recommendPhotographers(
        const RecommendationQuery(excludeIds: ['p1', 'p3']),
      );
      expect(ids(page).toSet(), {'p2', 'p4', 'p5', 'p6'});
    });

    test('pages are disjoint and together equal the unpaged order', () async {
      final all = ids(
        await repo.recommendPhotographers(const RecommendationQuery()),
      );
      final seen = <String>[];
      String? cursor;
      var ranks = <int>[];
      do {
        final page = await repo.recommendPhotographers(
          RecommendationQuery(limit: 2, cursor: cursor),
        );
        seen.addAll(ids(page));
        ranks = [...ranks, ...page.items.map((e) => e.rank)];
        cursor = page.nextCursor;
      } while (cursor != null);
      expect(seen, all);
      expect(ranks, [1, 2, 3, 4, 5, 6]);
    });

    test('every result has at most three reasons, each with a known code and a text', () async {
      final page = await repo.recommendPhotographers(
        RecommendationQuery(
          specialtyId: 'portrait',
          date: DateTime.utc(2026, 10, 3),
          geohash6: 'w3gvk1',
        ),
      );
      for (final item in page.items) {
        expect(item.reasons.length, lessThanOrEqualTo(3));
        for (final r in item.reasons) {
          expect(ReasonCode.values, contains(r.code));
          expect(r.text.trim(), isNotEmpty);
        }
      }
    });

    test(
      'similar never returns the photographer itself and respects the limit',
      () async {
        final page = await repo.similar('p1', limit: 3);
        expect(ids(page), isNot(contains('p1')));
        expect(page.items.length, lessThanOrEqualTo(3));
        expect(
          page.items.map((e) => e.rank),
          List.generate(page.items.length, (i) => i + 1),
        );
      },
    );

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

    test(
      'feedback is accepted for an empty and a normal batch without throwing',
      () async {
        await repo.sendFeedback(const []);
        await repo.sendFeedback([
          RecommendationSignal(
            type: SignalType.impression,
            requestId: 'r1',
            photographerId: 'p1',
            rank: 1,
            algorithmVersion: '1',
            at: fixtureNow,
          ),
          RecommendationSignal(
            type: SignalType.booking,
            requestId: 'r1',
            photographerId: 'p1',
            at: fixtureNow,
          ),
        ]);
      },
    );
  });
}
