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

Future<(ProviderContainer, DiscoveryWorld, _Spy)> _make({
  DiscoveryWorld? world,
}) async {
  _Spy? spy;
  final use =
      world ??
      DiscoveryWorld(
        recommenderFactory: (x) => spy = _Spy(x.localRecommender()),
      );
  await use.init();
  final c = ProviderContainer(overrides: use.overrides, retry: (_, _) => null);
  addTearDown(c.dispose);
  return (c, use, spy ?? _Spy(use.recommender));
}

List<String> _ids(FindResults r) =>
    r.items.map((e) => e.photographer.id).toList();

void main() {
  test('filters are reset when another user signs in', () async {
    final (c, w, _) = await _make();
    c.listen(findFiltersProvider, (_, _) {});
    c.read(findFiltersProvider.notifier).setMinRating(4.5);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(findFiltersProvider).minRating, 4.5, reason: 'same user');
    await w.auth.signOut();
    await Future<void>.delayed(Duration.zero);
    await c.pump();
    expect(c.read(findFiltersProvider).minRating, isNull);
  });

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
      expect(
        (f.specialtyId, f.budgetMax, f.minRating, f.styleId, f.sort),
        ('wedding', 2000000, 4.5, 'film', RecommendationSort.price),
      );
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
      await c
          .read(locationControllerProvider.notifier)
          .chooseArea(builtInAreas.first);
      await c.read(findResultsProvider.future);
      expect(spy.queries.last.geohash6, hasLength(6));
      expect(
        spy.queries.last.geohash6,
        startsWith(builtInAreas.first.geohash5),
      );
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

    test(
      'the rating filter is applied here and skips pages it empties',
      () async {
        final world = DiscoveryWorld(
          photographers: [
            for (var i = 0; i < 20; i++)
              fixturePhotographer(
                'a${i.toString().padLeft(2, '0')}',
                rating: 4.7,
                reviews: 1000,
                completed: 500,
              ),
            for (var i = 0; i < 5; i++)
              fixturePhotographer(
                'b$i',
                rating: 4.85,
                reviews: 10,
                completed: 5,
              ),
          ],
        );
        final (c, _, _) = await _make(world: world);
        c.read(findFiltersProvider.notifier).setMinRating(4.8);
        final r = await c.read(findResultsProvider.future);
        expect(r.items, hasLength(5));
        expect(_ids(r).every((id) => id.startsWith('b')), isTrue);
      },
    );

    test('loadMore appends the next page once', () async {
      final world = DiscoveryWorld(
        photographers: [
          for (var i = 0; i < 30; i++)
            fixturePhotographer(
              'p${i.toString().padLeft(2, '0')}',
              reviews: 10 + i,
            ),
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

    test('a page that arrives after the filters changed is dropped', () async {
      final world = DiscoveryWorld(
        photographers: [
          for (var i = 0; i < 30; i++)
            fixturePhotographer(
              'p${i.toString().padLeft(2, '0')}',
              reviews: 10 + i,
            ),
        ],
      );
      final (c, _, _) = await _make(world: world);
      final n = c.read(findResultsProvider.notifier);
      await c.read(findResultsProvider.future);
      final pending = n.loadMore();
      c.read(findFiltersProvider.notifier).setMinRating(4.0);
      await pending;
      final r = await c.read(findResultsProvider.future);
      expect(r.items.length, lessThanOrEqualTo(20));
    });

    test('setDate keeps only the calendar day, at local midnight', () async {
      final (c, _, _) = await _make();
      c.read(findFiltersProvider.notifier).setDate(DateTime.utc(2026, 10, 3));
      expect(c.read(findFiltersProvider).date, DateTime(2026, 10, 3));
    });

    test('a failing query is an error', () async {
      final (c, w, _) = await _make();
      w.photographers.failWith = StateError('offline');
      await expectLater(c.read(findResultsProvider.future), throwsStateError);
    });

    test(
      'opening a profile sends a click signal with the request and rank',
      () async {
        final (c, _, spy) = await _make();
        final r = await c.read(findResultsProvider.future);
        c.read(findResultsProvider.notifier).sendClick(r.items[1]);
        await Future<void>.delayed(Duration.zero);
        final s = spy.signals.single;
        expect(
          (s.type, s.photographerId, s.rank, s.requestId),
          (SignalType.click, 'p2', 2, r.requestId),
        );
        expect(s.algorithmVersion, '1.0.0');
      },
    );
  });

  test('a stored area survives as prefs only (no coordinates)', () async {
    final (c, w, _) = await _make();
    await c
        .read(locationControllerProvider.notifier)
        .chooseArea(builtInAreas.first);
    final stored =
        jsonDecode(w.prefs.getString(LocationController.areaKey)!) as Map;
    expect(stored.keys.toSet(), {'id', 'name', 'geohash5'});
  });
}
