import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/push/notification_permission.dart';
import 'package:photobooking/data/push/push_registration.dart';

import '../../support/fake_push.dart';

void main() {
  late FakePushMessaging messaging;
  late FakeNotificationPermission permission;
  late FakeDeviceRegistry devices;
  late String? uid;
  late PushRegistration reg;

  setUp(() {
    messaging = FakePushMessaging();
    permission = FakeNotificationPermission();
    devices = FakeDeviceRegistry();
    uid = 'u1';
    reg = PushRegistration(
      messaging: messaging,
      permission: permission,
      devices: devices,
      uid: () => uid,
      signOutFromAuth: () async => devices.log.add('signOut'),
      unregisterTimeout: const Duration(milliseconds: 50),
    );
  });

  tearDown(() => reg.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('no token registration while not granted', () async {
    for (final s in [
      NotificationPermissionStatus.notDetermined,
      NotificationPermissionStatus.denied,
      NotificationPermissionStatus.permanentlyDenied,
    ]) {
      permission.current = s;
      reg.start();
      await reg.refresh();
      messaging.emitRefresh('tok-2');
      await settle();
    }
    expect(messaging.tokenCalls, 0);
    expect(devices.registered, isEmpty);
  });

  test('no registration while signed out', () async {
    permission.current = NotificationPermissionStatus.granted;
    uid = null;
    reg.start();
    await settle();
    messaging.emitRefresh('tok-2');
    await settle();
    expect(messaging.tokenCalls, 0);
    expect(devices.registered, isEmpty);
  });

  test('granted registers the token and re-registers on refresh', () async {
    permission.current = NotificationPermissionStatus.granted;
    reg.start();
    await settle();
    expect(devices.registered, ['u1:tok-1']);

    messaging.emitRefresh('tok-2');
    await settle();
    expect(devices.registered, ['u1:tok-1', 'u1:tok-2']);
  });

  test('refresh() after a grant registers', () async {
    reg.start();
    await settle();
    expect(devices.registered, isEmpty);

    permission.current = NotificationPermissionStatus.granted;
    await reg.refresh();
    expect(devices.registered, ['u1:tok-1']);
  });

  test('signOut unregisters before signing out', () async {
    await reg.signOut();
    expect(devices.unregistered, ['u1']);
    expect(devices.log, ['unregister', 'signOut']);
  });

  test('signOut still signs out when unregister fails or hangs', () async {
    devices.failUnregister = StateError('offline');
    await reg.signOut();
    expect(devices.log, ['unregister', 'signOut']);

    devices.log.clear();
    devices.failUnregister = null;
    devices.holdUnregister = Completer<void>();
    await reg.signOut();
    expect(devices.log, ['unregister', 'signOut']);
  });

  test(
    'signOut deletes the FCM token, and a failing delete does not block',
    () async {
      await reg.signOut();
      expect(messaging.deleteCalls, 1);

      messaging.failDelete = StateError('x');
      devices.log.clear();
      await reg.signOut();
      expect(devices.log, ['unregister', 'signOut']);
    },
  );
}
