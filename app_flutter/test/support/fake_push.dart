import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:photobooking/data/push/push_providers.dart';

import 'package:photobooking/data/push/device_registry.dart';
import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_messaging.dart';

class FakePushMessaging implements PushMessaging {
  FakePushMessaging({this.currentToken = 'tok-1', this.initial});

  String? currentToken;
  PushOpen? initial;
  final _refresh = StreamController<String>.broadcast();
  final _opened = StreamController<PushOpen>.broadcast();

  /// How many times [token] was asked for.
  int tokenCalls = 0;

  /// How many times [deleteToken] was called.
  int deleteCalls = 0;
  Object? failDelete;

  @override
  Future<void> deleteToken() async {
    deleteCalls++;
    final f = failDelete;
    if (f != null) {
      throw f;
    }
  }

  void emitRefresh(String token) => _refresh.add(token);

  void emitOpened(PushOpen open) => _opened.add(open);

  @override
  Future<String?> token() async {
    tokenCalls++;
    return currentToken;
  }

  @override
  Stream<String> get tokenRefresh => _refresh.stream;

  @override
  Stream<PushOpen> get opened => _opened.stream;

  @override
  Future<PushOpen?> initialOpen() async {
    final i = initial;
    initial = null;
    return i;
  }
}

class FakeNotificationPermission implements NotificationPermissionPort {
  FakeNotificationPermission([
    this.current = NotificationPermissionStatus.notDetermined,
  ]);

  NotificationPermissionStatus current;

  /// What [request] turns the status into.
  NotificationPermissionStatus onRequest = NotificationPermissionStatus.granted;

  int requests = 0;
  int settingsOpened = 0;

  /// Makes [status] and [request] throw.
  Object? failWith;

  @override
  Future<NotificationPermissionStatus> status() async {
    final f = failWith;
    if (f != null) {
      throw f;
    }
    return current;
  }

  @override
  Future<NotificationPermissionStatus> request() async {
    final f = failWith;
    if (f != null) {
      throw f;
    }
    requests++;
    current = onRequest;
    return current;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

class FakeDeviceRegistry implements DeviceRegistry {
  /// `uid:token` for every register call.
  final registered = <String>[];

  /// uids passed to unregister.
  final unregistered = <String>[];

  /// Shared with the test's sign-out stub to check the order of calls.
  final List<String> log = [];

  Object? failUnregister;
  Completer<void>? holdUnregister;

  @override
  Future<void> register({required String uid, required String token}) async {
    registered.add('$uid:$token');
    log.add('register');
  }

  @override
  Future<void> unregister(String uid) async {
    unregistered.add(uid);
    log.add('unregister');
    final hold = holdUnregister;
    if (hold != null) {
      await hold.future;
    }
    final failure = failUnregister;
    if (failure != null) {
      throw failure;
    }
  }
}

/// A permission that is already granted, so no screen under test shows the
/// S17.03 primer — unless [extra] overrides the permission itself.
List<Override> grantedNotificationPermissionUnless(List<Override> extra) {
  final custom = extra.any((o) {
    try {
      final origin = (o as dynamic).origin;
      return origin == notificationPermissionProvider ||
          origin?.toString() == notificationPermissionProvider.toString();
    } catch (_) {
      return false;
    }
  });
  return [
    if (!custom)
      notificationPermissionProvider.overrideWithValue(
        FakeNotificationPermission(NotificationPermissionStatus.granted),
      ),
  ];
}
