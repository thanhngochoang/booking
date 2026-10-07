import 'dart:async';

import 'package:photobooking/data/push/device_registry.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_messaging.dart';

/// Keeps this install's push token registered while a user is signed in and
/// the OS permission is granted. `token()` is never called before a grant.
class PushRegistration {
  PushRegistration({
    required this.messaging,
    required this.permission,
    required this.devices,
    required this.uid,
    required this.signOutFromAuth,
    this.unregisterTimeout = const Duration(seconds: 3),
  });

  final PushMessaging messaging;
  final NotificationPermissionPort permission;
  final DeviceRegistry devices;

  /// The signed-in uid right now, null when signed out.
  final String? Function() uid;
  final Future<void> Function() signOutFromAuth;
  final Duration unregisterTimeout;

  StreamSubscription<String>? _refreshSub;
  var _disposed = false;

  /// Registers now and again on every token refresh.
  void start() {
    _refreshSub ??= messaging.tokenRefresh.listen(
      (t) => unawaited(_register(t)),
    );
    unawaited(refresh());
  }

  void dispose() {
    _disposed = true;
    final sub = _refreshSub;
    _refreshSub = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
  }

  /// Registers the current token if signed in and permission is granted;
  /// call it after the user grants permission.
  Future<void> refresh() async {
    if (uid() == null) {
      return;
    }
    if (await permission.status() != NotificationPermissionStatus.granted) {
      return;
    }
    final token = await messaging.token();
    if (token != null) {
      await _register(token);
    }
  }

  Future<void> _register(String token) async {
    final u = uid();
    if (_disposed || u == null || token.isEmpty) {
      return;
    }
    // A refreshed token also needs the grant (the user may have revoked it).
    if (await permission.status() != NotificationPermissionStatus.granted) {
      return;
    }
    try {
      await devices.register(uid: u, token: token);
    } on Object {
      // Best effort: the next refresh or app start retries.
    }
  }

  /// Removes this install's record and token (best effort, short timeout),
  /// then signs out. A failing or slow unregister never blocks the sign-out.
  Future<void> signOut() async {
    final u = uid();
    if (u != null) {
      try {
        await devices.unregister(u).timeout(unregisterTimeout);
      } on Object {
        // Offline: the server drops the stale token on its first failed send.
      }
      try {
        // Stops the old account's pushes on this phone even when the record
        // could not be removed; the next sign-in gets a fresh token.
        await messaging.deleteToken().timeout(unregisterTimeout);
      } on Object {
        // Best effort.
      }
    }
    await signOutFromAuth();
  }
}
