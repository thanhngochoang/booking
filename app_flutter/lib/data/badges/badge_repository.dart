import 'dart:async';

import 'package:photobooking/data/badges/badge.dart';

abstract class BadgeRepository {
  /// The catalogue, ordered by `order`; the provider caches it.
  Future<List<BadgeDefinition>> catalog();

  Stream<List<EarnedBadge>> watchEarned(String uid);

  /// Owner only: other users' progress is not readable.
  Stream<Map<String, BadgeProgressEntry>> watchProgress(String uid);
}

/// In-memory repository for tests and previews.
class FakeBadgeRepository implements BadgeRepository {
  FakeBadgeRepository({
    List<BadgeDefinition> catalog = const [],
    Map<String, List<EarnedBadge>> earned = const {},
    Map<String, Map<String, BadgeProgressEntry>> progress = const {},
  }) : _catalog = List.of(catalog),
       _earned = {for (final e in earned.entries) e.key: List.of(e.value)},
       _progress = {for (final e in progress.entries) e.key: Map.of(e.value)};

  final List<BadgeDefinition> _catalog;
  final Map<String, List<EarnedBadge>> _earned;
  final Map<String, Map<String, BadgeProgressEntry>> _progress;
  final _changes = StreamController<void>.broadcast();

  /// How many times [catalog] was read.
  int catalogReads = 0;

  void earn(String uid, EarnedBadge b) {
    (_earned[uid] ??= []).add(b);
    _changes.add(null);
  }

  @override
  Future<List<BadgeDefinition>> catalog() async {
    catalogReads++;
    return List.of(_catalog)..sort((a, b) => a.order.compareTo(b.order));
  }

  @override
  Stream<List<EarnedBadge>> watchEarned(String uid) async* {
    yield List.of(_earned[uid] ?? const []);
    await for (final _ in _changes.stream) {
      yield List.of(_earned[uid] ?? const []);
    }
  }

  @override
  Stream<Map<String, BadgeProgressEntry>> watchProgress(String uid) =>
      Stream.value(Map.of(_progress[uid] ?? const {}));
}
