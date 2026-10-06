import 'dart:async';

import 'package:photobooking/data/notifications/app_notification.dart';

abstract class NotificationRepository {
  /// Live newest rows (limit 30 by default); [NotificationPage.next] is null
  /// when fewer than [limit] rows exist.
  Stream<NotificationPage> watchFirstPage(
    String uid, {
    NotificationTab? tab,
    int limit = 30,
  });

  Future<NotificationPage> page(
    String uid, {
    NotificationTab? tab,
    required NotificationCursor after,
    int limit = 30,
  });

  /// `users/{uid}/private/inbox.unreadCount` (server-written, owner-only);
  /// 0 when absent.
  Stream<int> watchUnreadCount(String uid);

  /// The newest row, one-shot (no listener).
  Future<AppNotification?> latest(String uid);

  /// One write batch setting `readAt` (server time) on [ids].
  Future<void> markRead(String uid, Iterable<String> ids);

  /// Callable `markAllNotificationsRead`.
  Future<void> markAllRead();

  /// `/b/:id` and `/chat/:id` cost one document read; any other target is
  /// assumed to exist.
  Future<bool> targetExists(String target);
}

/// In-memory repository for tests and previews.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository([List<AppNotification> rows = const []])
    : _rows = List.of(rows);

  final List<AppNotification> _rows;
  final _changes = StreamController<void>.broadcast();

  /// Targets that no longer exist.
  final Set<String> goneTargets = {};

  /// Calls made, for assertions: `markRead:a,b`, `markAllRead`, ...
  final calls = <String>[];

  /// Makes [markRead] fail for more than one id (a batch), not for one.
  bool failBatches = false;

  /// Open [watchFirstPage] listeners.
  int listeners = 0;

  Object? failWith;

  DateTime Function() now = () => DateTime.now().toUtc();

  List<AppNotification> _filtered(NotificationTab? tab) =>
      _rows.where((n) => tab == null || n.tab == tab).toList()..sort(
        (a, b) => b.createdAt != a.createdAt
            ? b.createdAt.compareTo(a.createdAt)
            : b.id.compareTo(a.id),
      );

  NotificationPage _page(List<AppNotification> all, int limit) {
    final items = all.take(limit).toList();
    return NotificationPage(
      items: items,
      next: items.length >= limit && items.isNotEmpty
          ? NotificationCursor(
              createdAt: items.last.createdAt,
              id: items.last.id,
            )
          : null,
    );
  }

  void add(AppNotification n) {
    _rows.add(n);
    _changes.add(null);
  }

  @override
  Stream<NotificationPage> watchFirstPage(
    String uid, {
    NotificationTab? tab,
    int limit = 30,
  }) {
    late StreamController<NotificationPage> c;
    StreamSubscription<void>? sub;
    c = StreamController<NotificationPage>(
      onListen: () {
        listeners++;
        calls.add('watchFirstPage:${tab?.name ?? 'all'}');
        c.add(_page(_filtered(tab), limit));
        sub = _changes.stream.listen(
          (_) => c.add(_page(_filtered(tab), limit)),
        );
      },
      onCancel: () async {
        listeners--;
        await sub?.cancel();
      },
    );
    return c.stream;
  }

  @override
  Future<NotificationPage> page(
    String uid, {
    NotificationTab? tab,
    required NotificationCursor after,
    int limit = 30,
  }) async {
    final all = _filtered(tab).where((n) {
      final c = n.createdAt.compareTo(after.createdAt);
      return c < 0 || (c == 0 && n.id.compareTo(after.id) < 0);
    }).toList();
    return _page(all, limit);
  }

  @override
  Stream<int> watchUnreadCount(String uid) async* {
    yield _rows.where((n) => n.unread).length;
    await for (final _ in _changes.stream) {
      yield _rows.where((n) => n.unread).length;
    }
  }

  @override
  Future<AppNotification?> latest(String uid) async {
    final all = _filtered(null);
    return all.isEmpty ? null : all.first;
  }

  @override
  Future<void> markRead(String uid, Iterable<String> ids) async {
    final failure = failWith;
    if (failure != null) {
      throw failure;
    }
    if (failBatches && ids.length > 1) {
      throw StateError('batch failed');
    }
    final set = ids.toSet();
    calls.add('markRead:${set.join(',')}');
    for (var i = 0; i < _rows.length; i++) {
      if (set.contains(_rows[i].id)) {
        _rows[i] = _rows[i].markedRead(now());
      }
    }
    _changes.add(null);
  }

  @override
  Future<void> markAllRead() async {
    final failure = failWith;
    if (failure != null) {
      throw failure;
    }
    calls.add('markAllRead');
    for (var i = 0; i < _rows.length; i++) {
      _rows[i] = _rows[i].markedRead(now());
    }
    _changes.add(null);
  }

  @override
  Future<bool> targetExists(String target) async =>
      !goneTargets.contains(target);
}
