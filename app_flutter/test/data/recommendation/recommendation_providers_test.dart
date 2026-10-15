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
        postRepositoryProvider.overrideWithValue(
          FakePostRepository([fixturePost('a')]),
        ),
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

  test(
    'the default recommender is the local one, built from the content ports',
    () async {
      final c = make();
      expect(c.read(recommendationRepositoryProvider), isA<LocalRecommender>());
      final page = await c
          .read(recommendationRepositoryProvider)
          .recommendPhotographers(const RecommendationQuery());
      expect(page.items.single.photographer.id, 'p1');
      final posts = await c
          .read(recommendationRepositoryProvider)
          .recommendPosts(const PostRecommendationQuery());
      expect(posts.items.single.post.id, 'a');
    },
  );

  test('the repository is the same object as localRecommenderProvider until overridden', () {
    final c = make();
    expect(
      c.read(recommendationRepositoryProvider),
      same(c.read(localRecommenderProvider)),
    );
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
