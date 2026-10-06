import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/notifications/app_notification.dart';
import 'package:photobooking/data/notifications/notification_providers.dart';
import 'package:photobooking/data/notifications/notification_repository.dart';

/// Rows per page; the live listener and every older page use it.
const notificationPageSize = 30;

/// How long read marks wait before they go out as one batch.
const notificationReadDebounce = Duration(seconds: 1);

/// The S17.01 filter; null is "Tất cả". Reset when the screen closes.
final notificationTabFilterProvider =
    StateProvider.autoDispose<NotificationTab?>((_) => null);

@immutable
class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.next,
    this.loadingMore = false,
    this.fromCache = false,
  });

  final List<AppNotification> items;

  /// Where the next older page starts; null at the end.
  final NotificationCursor? next;
  final bool loadingMore;

  /// The live page came from the local cache (offline).
  final bool fromCache;

  NotificationsState copyWith({
    List<AppNotification>? items,
    NotificationCursor? next,
    bool clearNext = false,
    bool? loadingMore,
    bool? fromCache,
  }) => NotificationsState(
    items: items ?? this.items,
    next: clearNext ? null : (next ?? this.next),
    loadingMore: loadingMore ?? this.loadingMore,
    fromCache: fromCache ?? this.fromCache,
  );
}

/// Restores the prefs a mute replaced.
class MuteUndo {
  const MuteUndo(this.undo);
  final Future<void> Function() undo;
}

/// S17.01 state: one live listener on the newest page of the current tab,
/// older pages appended on demand, read marks applied at once and written in
/// one batch after a second or when the screen closes.
class NotificationsController extends AsyncNotifier<NotificationsState> {
  /// Rows from older pages, newest first.
  final _older = <AppNotification>[];
  NotificationCursor? _olderNext;
  var _hasOlderPage = false;
  NotificationPage? _live;

  /// Shown as read before the server says so.
  final _marked = <String>{};
  final _pending = <String>{};
  Timer? _timer;
  bool _loadingMore = false;

  @override
  Future<NotificationsState> build() async {
    final tab = ref.watch(notificationTabFilterProvider);
    final uid = ref.watch(authStateProvider.select((a) => a.value?.uid));
    final repo = ref.watch(notificationRepositoryProvider);
    _older.clear();
    _olderNext = null;
    _hasOlderPage = false;
    _live = null;
    _marked.clear();
    _pending.clear();
    _loadingMore = false;
    if (uid == null) {
      return const NotificationsState();
    }
    final first = Completer<NotificationsState>();
    final sub = repo
        .watchFirstPage(uid, tab: tab, limit: notificationPageSize)
        .listen(
          (page) {
            _keepRowsPushedOut(page);
            _live = page;
            final next = _compose();
            if (first.isCompleted) {
              state = AsyncData(next);
            } else {
              first.complete(next);
            }
          },
          onError: (Object e, StackTrace s) {
            if (first.isCompleted) {
              state = AsyncError(e, s);
            } else {
              first.completeError(e, s);
            }
          },
        );
    ref.onDispose(() {
      unawaited(sub.cancel());
      _timer?.cancel();
      _timer = null;
      // Leaving flushes what is still waiting for the debounce.
      if (_pending.isNotEmpty) {
        final ids = _pending.toList();
        _pending.clear();
        unawaited(_write(repo, uid, ids));
      }
    });
    return first.future;
  }

  /// A new row shifts the oldest rows of the live window out of it; they stay
  /// on screen as part of the older rows instead of vanishing until a reload.
  void _keepRowsPushedOut(NotificationPage page) {
    final before = _live;
    if (before == null || page.items.isEmpty) {
      return;
    }
    final inWindow = {for (final n in page.items) n.id};
    final edge = page.items.last;
    final known = {for (final n in _older) n.id};
    var changed = false;
    for (final n in before.items) {
      if (!inWindow.contains(n.id) &&
          !known.contains(n.id) &&
          _isOlder(n, edge)) {
        _older.add(n);
        changed = true;
      }
    }
    if (changed) {
      _older.sort((a, b) => _isOlder(a, b) ? 1 : (_isOlder(b, a) ? -1 : 0));
    }
  }

  /// [a] comes after [b] in newest-first order.
  bool _isOlder(AppNotification a, AppNotification b) {
    final c = a.createdAt.compareTo(b.createdAt);
    return c < 0 || (c == 0 && a.id.compareTo(b.id) < 0);
  }

  /// The live page replaces only the newest rows; older pages stay appended
  /// and every id appears once.
  NotificationsState _compose() {
    final live = _live!;
    final seen = <String>{};
    final rows = <AppNotification>[];
    for (final n in [...live.items, ..._older]) {
      if (seen.add(n.id)) {
        rows.add(_marked.contains(n.id) && n.unread ? n.markedRead(_now()) : n);
      }
    }
    return NotificationsState(
      items: rows,
      next: _hasOlderPage ? _olderNext : live.next,
      loadingMore: _loadingMore,
      fromCache: live.fromCache,
    );
  }

  DateTime _now() => ref.read(clockProvider)();

  void _publish() {
    if (_live != null && state.hasValue) {
      state = AsyncData(_compose());
    }
  }

  /// Loads the next 30 older rows; a no-op while loading or at the end.
  Future<void> loadMore() async {
    final current = state.value;
    final cursor = current?.next;
    final uid = ref.read(authStateProvider).value?.uid;
    if (current == null || cursor == null || _loadingMore || uid == null) {
      return;
    }
    _loadingMore = true;
    _publish();
    final tab = ref.read(notificationTabFilterProvider);
    try {
      final page = await ref
          .read(notificationRepositoryProvider)
          .page(uid, tab: tab, after: cursor, limit: notificationPageSize);
      _older.addAll(page.items);
      _olderNext = page.next;
      _hasOlderPage = true;
    } on Object {
      // Keeps the rows and the cursor: the next scroll or a refresh retries.
    } finally {
      _loadingMore = false;
      _publish();
    }
  }

  /// Dims the row now; the write goes out with the next batch.
  void markRead(String id) {
    if (!_marked.add(id)) {
      return;
    }
    _pending.add(id);
    _timer?.cancel();
    _timer = Timer(notificationReadDebounce, _flush);
    _publish();
  }

  void _flush() {
    _timer = null;
    final uid = ref.read(authStateProvider).value?.uid;
    if (_pending.isEmpty || uid == null) {
      return;
    }
    final ids = _pending.toList();
    _pending.clear();
    unawaited(_write(ref.read(notificationRepositoryProvider), uid, ids));
  }

  Future<void> _write(
    NotificationRepository repo,
    String uid,
    List<String> ids,
  ) async {
    try {
      await repo.markRead(uid, ids);
    } on Object {
      // The marks stay in the UI for this visit; the next open shows the
      // server's truth and the user can tap again.
    }
  }

  /// Callable `markAllNotificationsRead`, then every loaded row reads as read.
  /// Throws when the call fails so the screen can say so.
  Future<void> markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    final rows = state.value?.items ?? const <AppNotification>[];
    _marked.addAll(rows.map((n) => n.id));
    _pending.clear();
    _timer?.cancel();
    _timer = null;
    _publish();
  }

  /// Switches off push and in-app for the category of [n]. Null for booking
  /// rows (always on, Decision 7); otherwise a handle that restores the old
  /// settings.
  Future<MuteUndo?> mute(AppNotification n) async {
    if (n.category == NotificationCategory.booking) {
      return null;
    }
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) {
      return null;
    }
    final repo = ref.read(notificationPrefsRepositoryProvider);
    final before = (await repo.watch(uid).first).prefs;
    final muted = before.withChannel(n.category, push: false, inApp: false);
    await repo.save(uid, muted);
    return MuteUndo(() => repo.save(uid, before));
  }

  /// Pull to refresh: starts the listener again and reloads page one.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationsController,
      NotificationsState
    >(NotificationsController.new);
