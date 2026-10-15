import 'dart:async';

import 'package:photobooking/data/notifications/notification_prefs.dart';

abstract class NotificationPrefsRepository {
  /// Live prefs; the defaults while the doc does not exist.
  Stream<PrefsSnapshot> watch(String uid);

  /// `set(toMap + updatedAt serverTimestamp)`.
  Future<void> save(String uid, NotificationPrefs prefs);
}

/// In-memory repository for tests and previews.
class FakeNotificationPrefsRepository implements NotificationPrefsRepository {
  FakeNotificationPrefsRepository([
    NotificationPrefs initial = NotificationPrefs.defaults,
  ]) : _current = initial;

  NotificationPrefs _current;
  final _changes = StreamController<void>.broadcast();

  /// Every saved value, oldest first.
  final saved = <NotificationPrefs>[];

  Object? failWith;

  /// Makes [watch] report the prefs as coming from the local cache.
  bool fromCache = false;

  NotificationPrefs get current => _current;

  @override
  Stream<PrefsSnapshot> watch(String uid) async* {
    yield PrefsSnapshot(_current, fromCache: fromCache);
    await for (final _ in _changes.stream) {
      yield PrefsSnapshot(_current, fromCache: fromCache);
    }
  }

  @override
  Future<void> save(String uid, NotificationPrefs prefs) async {
    final failure = failWith;
    if (failure != null) {
      throw failure;
    }
    saved.add(prefs);
    _current = prefs;
    _changes.add(null);
  }
}
