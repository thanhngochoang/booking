// test/data/content/cached_photographer_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/content/cached_photographer_repository.dart';
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';

import '../../support/content_fixtures.dart';

class RecordingPhotographerRepository implements PhotographerRepository {
  RecordingPhotographerRepository(this.seed);

  final List<PhotographerSummary> seed;
  int candidateCalls = 0;
  int summaryCalls = 0;
  int freeThisWeekCalls = 0;
  Object? failCandidatesWith;

  @override
  Future<List<PhotographerSummary>> candidates({int limit = 200}) async {
    candidateCalls++;
    if (failCandidatesWith != null) {
      throw failCandidatesWith!;
    }
    return seed.take(limit).toList();
  }

  @override
  Future<Map<String, PhotographerSummary>> summaries(Iterable<String> ids) async {
    summaryCalls++;
    final set = ids.toSet();
    return {for (final p in seed) if (set.contains(p.id)) p.id: p};
  }

  @override
  Future<List<PhotographerSummary>> freeThisWeek({
    required DateTime now,
    int limit = 12,
  }) async {
    freeThisWeekCalls++;
    return seed.take(limit).toList();
  }

  @override
  Future<List<PhotographerSummary>> membersOf(
    String studioId, {
    int limit = 10,
  }) async => [
    for (final p in seed)
      if (p.studioId == studioId) p,
  ];
}

void main() {
  group('CachedPhotographerRepository', () {
    test('pages and filter changes reuse one pool read', () async {
      final inner = RecordingPhotographerRepository([
        fixturePhotographer('p1'),
        fixturePhotographer('p2'),
      ]);
      DateTime now = DateTime(2026, 10, 1, 10, 0);
      final cached = CachedPhotographerRepository(inner, clock: () => now);

      // Call 1
      final res1 = await cached.candidates(limit: 200);
      expect(res1.length, 2);
      expect(inner.candidateCalls, 1);

      // Call 2 (different limit, within 10 min)
      now = now.add(const Duration(minutes: 5));
      final res2 = await cached.candidates(limit: 1);
      expect(res2.length, 1);
      expect(inner.candidateCalls, 1);

      // Call 3 (within 10 min)
      now = now.add(const Duration(minutes: 4));
      final res3 = await cached.candidates(limit: 200);
      expect(res3.length, 2);
      expect(inner.candidateCalls, 1);
    });

    test('the pool is read again after ten minutes', () async {
      final inner = RecordingPhotographerRepository([fixturePhotographer('p1')]);
      DateTime now = DateTime(2026, 10, 1, 10, 0);
      final cached = CachedPhotographerRepository(inner, clock: () => now);

      await cached.candidates();
      expect(inner.candidateCalls, 1);

      // Advance 10 minutes and 1 second
      now = now.add(const Duration(minutes: 10, seconds: 1));
      await cached.candidates();
      expect(inner.candidateCalls, 2);
    });

    test('concurrent callers share one read', () async {
      final inner = RecordingPhotographerRepository([fixturePhotographer('p1')]);
      DateTime now = DateTime(2026, 10, 1, 10, 0);
      final cached = CachedPhotographerRepository(inner, clock: () => now);

      final futures = [
        cached.candidates(),
        cached.candidates(),
        cached.candidates(),
      ];
      final results = await Future.wait(futures);

      expect(inner.candidateCalls, 1);
      expect(results[0].length, 1);
      expect(results[1].length, 1);
      expect(results[2].length, 1);
    });

    test('a failed read is not cached', () async {
      final inner = RecordingPhotographerRepository([fixturePhotographer('p1')])
        ..failCandidatesWith = Exception('network error');
      DateTime now = DateTime(2026, 10, 1, 10, 0);
      final cached = CachedPhotographerRepository(inner, clock: () => now);

      await expectLater(cached.candidates(), throwsA(isA<Exception>()));
      expect(inner.candidateCalls, 1);

      // Next call after clearing failure should read inner again
      inner.failCandidatesWith = null;
      final res = await cached.candidates();
      expect(res.length, 1);
      expect(inner.candidateCalls, 2);
    });

    test('invalidate forces a new read', () async {
      final inner = RecordingPhotographerRepository([fixturePhotographer('p1')]);
      DateTime now = DateTime(2026, 10, 1, 10, 0);
      final cached = CachedPhotographerRepository(inner, clock: () => now);

      await cached.candidates();
      expect(inner.candidateCalls, 1);

      cached.invalidate();

      await cached.candidates();
      expect(inner.candidateCalls, 2);
    });

    test('summaries and freeThisWeek pass through', () async {
      final inner = RecordingPhotographerRepository([fixturePhotographer('p1')]);
      DateTime now = DateTime(2026, 10, 1, 10, 0);
      final cached = CachedPhotographerRepository(inner, clock: () => now);

      final s = await cached.summaries(['p1']);
      expect(s.containsKey('p1'), isTrue);
      expect(inner.summaryCalls, 1);

      final f = await cached.freeThisWeek(now: now);
      expect(f.length, 1);
      expect(inner.freeThisWeekCalls, 1);
    });
  });
}
