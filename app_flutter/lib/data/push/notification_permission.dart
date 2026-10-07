enum NotificationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  notDetermined,
}

/// The OS notification permission.
abstract class NotificationPermissionPort {
  Future<NotificationPermissionStatus> status();

  /// Shows the OS dialog when it can; returns the resulting status.
  Future<NotificationPermissionStatus> request();

  Future<void> openSettings();
}
