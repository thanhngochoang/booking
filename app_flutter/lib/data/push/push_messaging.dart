import 'package:flutter/foundation.dart';

/// A tap on a push: where it points and which inbox row it belongs to.
@immutable
class PushOpen {
  const PushOpen({required this.target, this.notificationId});

  final String target;
  final String? notificationId;
}

/// The push transport (FCM). Foreground messages are not surfaced: the inbox
/// and the tab badge update live from Firestore.
abstract class PushMessaging {
  /// The device token, or null when none is available.
  Future<String?> token();

  Stream<String> get tokenRefresh;

  /// Taps on a push while the app is in the background.
  Stream<PushOpen> get opened;

  /// The push that cold-started the app, once.
  Future<PushOpen?> initialOpen();
}
