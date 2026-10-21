// lib/data/content/cached_photographer_repository.dart
import 'package:photobooking/data/content/content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';

class CachedPhotographerRepository
    implements PhotographerRepository, PhotographerPoolCache {
  CachedPhotographerRepository(
    this.inner, {
    required this.clock,
    this.ttl = const Duration(minutes: 10),
  });

  final PhotographerRepository inner;
  final DateTime Function() clock;
  final Duration ttl;

  Future<List<PhotographerSummary>>? _inflight;
  ({DateTime at, int limit, List<PhotographerSummary> items})? _pool;

  @override
  void invalidate() {
    _pool = null;
  }

  @override
  Future<List<PhotographerSummary>> candidates({int limit = 200}) {
    final now = clock();
    final p = _pool;
    if (p != null && p.limit >= limit && now.difference(p.at) < ttl) {
      return Future.value(p.items.take(limit).toList());
    }
    return _inflight ??= inner.candidates(limit: limit).then((items) {
      _pool = (at: clock(), limit: limit, items: items);
      return items;
    }).whenComplete(() => _inflight = null);
  }

  @override
  Future<Map<String, PhotographerSummary>> summaries(Iterable<String> ids) =>
      inner.summaries(ids);

  @override
  Future<List<PhotographerSummary>> freeThisWeek({
    required DateTime now,
    int limit = 12,
  }) =>
      inner.freeThisWeek(now: now, limit: limit);

  @override
  Future<List<PhotographerSummary>> membersOf(
    String studioId, {
    int limit = 10,
  }) => inner.membersOf(studioId, limit: limit);
}
