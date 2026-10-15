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
  Future<RecommendationPage> recommendPhotographers(
    RecommendationQuery query,
  ) => _run(
    () => const RecommendationPage(
      items: [],
      requestId: 'remote',
      algorithm: 'rules-v1',
      algorithmVersion: '1.0.0',
    ),
  );

  @override
  Future<RecommendationPage> similar(String photographerId, {int limit = 8}) =>
      _run(
        () => const RecommendationPage(
          items: [],
          requestId: 'remote',
          algorithm: 'rules-v1',
          algorithmVersion: '1.0.0',
        ),
      );

  @override
  Future<PostRecommendationPage> recommendPosts(
    PostRecommendationQuery query,
  ) => _run(
    () => const PostRecommendationPage(
      items: [],
      requestId: 'remote',
      algorithm: 'rules-v1',
      algorithmVersion: '1.0.0',
    ),
  );

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
    final repo = ResilientRecommendationRepository(
      primary: remote,
      fallback: _local(),
    );
    final page = await repo.recommendPhotographers(const RecommendationQuery());
    expect(page.requestId, 'remote');
    expect(page.usedFallback, isFalse);
    final posts = await repo.recommendPosts(const PostRecommendationQuery());
    expect(posts.requestId, 'remote');
    expect((await repo.similar('p1')).requestId, 'remote');
  });

  test('an error falls back to the local ranking and flags the page', () async {
    final remote = _Remote()..mode = _Mode.throws;
    final repo = ResilientRecommendationRepository(
      primary: remote,
      fallback: _local(),
    );
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
    expect(
      DateTime.now().difference(started),
      lessThan(const Duration(seconds: 2)),
    );
    expect(remote.calls, 1, reason: 'no retry loop');
  });

  test('the default deadline is 800 ms', () {
    final repo = ResilientRecommendationRepository(
      primary: _Remote(),
      fallback: _local(),
    );
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
      RecommendationSignal(
        type: SignalType.click,
        requestId: 'r',
        photographerId: 'p1',
        at: fixtureNow,
      ),
    ];
    await repo.sendFeedback(signals);
    remote.mode = _Mode.hangs;
    await repo.sendFeedback(signals);
    expect(remote.feedbackCalls, 2, reason: 'one attempt each, no retry');
  });
}
