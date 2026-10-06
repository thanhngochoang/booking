import 'package:permission_handler/permission_handler.dart';

import 'package:photobooking/data/push/notification_permission.dart';

NotificationPermissionStatus _map(PermissionStatus s) => switch (s) {
  PermissionStatus.granted ||
  PermissionStatus.limited ||
  PermissionStatus.provisional => NotificationPermissionStatus.granted,
  PermissionStatus.permanentlyDenied ||
  PermissionStatus.restricted => NotificationPermissionStatus.permanentlyDenied,
  // Android reports "never asked" and "asked once, refused" alike.
  PermissionStatus.denied => NotificationPermissionStatus.denied,
};

class PermissionHandlerNotificationPermission
    implements NotificationPermissionPort {
  const PermissionHandlerNotificationPermission();

  @override
  Future<NotificationPermissionStatus> status() async =>
      _map(await Permission.notification.status);

  @override
  Future<NotificationPermissionStatus> request() async =>
      _map(await Permission.notification.request());

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
