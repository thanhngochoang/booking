import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/notifications/app_notification.dart';
import 'package:photobooking/data/notifications/notification_prefs.dart';
import 'package:photobooking/data/notifications/notification_providers.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_providers.dart';
import 'package:photobooking/features/notifications/notifications_analytics.dart';

@immutable
class NotificationSettingsState {
  const NotificationSettingsState({
    required this.prefs,
    required this.fromCache,
    required this.os,
  });

  final NotificationPrefs prefs;

  /// The prefs came from the local cache (offline): switches are disabled.
  final bool fromCache;

  /// The OS permission, re-read when the app comes back to the foreground.
  final NotificationPermissionStatus os;

  NotificationSettingsState copyWith({
    NotificationPrefs? prefs,
    bool? fromCache,
    NotificationPermissionStatus? os,
  }) => NotificationSettingsState(
    prefs: prefs ?? this.prefs,
    fromCache: fromCache ?? this.fromCache,
    os: os ?? this.os,
  );
}

/// S17.02: live prefs, optimistic writes (a failed write puts the old value
/// back and throws so the screen can say so).
class NotificationSettingsController
    extends AsyncNotifier<NotificationSettingsState> {
  @override
  Future<NotificationSettingsState> build() async {
    final uid = ref.watch(authStateProvider.select((a) => a.value?.uid));
    final repo = ref.watch(notificationPrefsRepositoryProvider);
    final permission = ref.watch(notificationPermissionProvider);
    var os = NotificationPermissionStatus.notDetermined;
    try {
      os = await permission.status();
    } on Object {
      // Unknown: the banner stays hidden rather than guessing.
      os = NotificationPermissionStatus.granted;
    }
    if (uid == null) {
      return NotificationSettingsState(
        prefs: NotificationPrefs.defaults,
        fromCache: false,
        os: os,
      );
    }
    final first = Completer<NotificationSettingsState>();
    final sub = repo
        .watch(uid)
        .listen(
          (snap) {
            final current = state.value;
            final next = NotificationSettingsState(
              prefs: snap.prefs,
              fromCache: snap.fromCache,
              os: current?.os ?? os,
            );
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
    ref.onDispose(() => unawaited(sub.cancel()));
    return first.future;
  }

  void _log(String name, Map<String, Object> params) =>
      ref.read(notificationsAnalyticsProvider)(name, params);

  /// Shows [next] at once and writes it; on failure the old settings come back
  /// and the error is rethrown.
  Future<void> _write(NotificationPrefs next) async {
    final current = state.value;
    final uid = ref.read(authStateProvider).value?.uid;
    if (current == null || uid == null || current.prefs == next) {
      return;
    }
    state = AsyncData(current.copyWith(prefs: next));
    try {
      await ref.read(notificationPrefsRepositoryProvider).save(uid, next);
    } on Object {
      if (ref.mounted) {
        final latest = state.value;
        if (latest != null && latest.prefs == next) {
          state = AsyncData(latest.copyWith(prefs: current.prefs));
        }
      }
      rethrow;
    }
  }

  NotificationPrefs get _prefs => state.requireValue.prefs;

  Future<void> setChannel(
    NotificationCategory c, {
    bool? push,
    bool? inApp,
  }) async {
    await _write(_prefs.withChannel(c, push: push, inApp: inApp));
    if (push != null) {
      _log('notification_pref_change', {
        'category': c.name,
        'channel': 'push',
        'enabled': push,
      });
    }
    if (inApp != null) {
      _log('notification_pref_change', {
        'category': c.name,
        'channel': 'inApp',
        'enabled': inApp,
      });
    }
  }

  Future<void> setQuietEnabled(bool v) async {
    await _write(_prefs.withQuiet(enabled: v));
    _log('notification_quiet_hours_change', {'enabled': v});
  }

  Future<void> setQuietRange(String from, String to) =>
      _write(_prefs.withQuiet(from: from, to: to));

  Future<void> setReminder({bool? h24, bool? h2}) =>
      _write(_prefs.withReminders(h24: h24, h2: h2));

  /// Re-reads the OS permission (the app came back from the system settings).
  Future<void> refreshPermission() async {
    final current = state.value;
    if (current == null) {
      return;
    }
    try {
      final os = await ref.read(notificationPermissionProvider).status();
      if (ref.mounted && state.value != null) {
        state = AsyncData(state.value!.copyWith(os: os));
      }
    } on Object {
      // Keeps the last known status; a platform error must not escape.
    }
  }

  Future<void> openOsSettings() async {
    _log('notification_os_settings_open', {});
    await ref.read(notificationPermissionProvider).openSettings();
  }

  /// Asks the OS; a grant registers this device for push.
  Future<void> requestPermission() async {
    try {
      final os = await ref.read(notificationPermissionProvider).request();
      _log('notification_os_result', {
        'granted': os == NotificationPermissionStatus.granted,
      });
      if (ref.mounted && state.value != null) {
        state = AsyncData(state.value!.copyWith(os: os));
      }
      if (os == NotificationPermissionStatus.granted) {
        await ref.read(pushRegistrationProvider).refresh();
      }
    } on Object {
      // The switch stays as it was; a platform error must not escape.
    }
  }
}

final notificationSettingsControllerProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationSettingsController,
      NotificationSettingsState
    >(NotificationSettingsController.new);
