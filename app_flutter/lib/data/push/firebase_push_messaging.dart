import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:photobooking/data/push/push_messaging.dart';

PushOpen? _open(RemoteMessage m) {
  final target = m.data['target'];
  if (target is! String || target.isEmpty) {
    return null;
  }
  final id = m.data['notificationId'];
  return PushOpen(target: target, notificationId: id is String ? id : null);
}

class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging({FirebaseMessaging? messaging}) : _override = messaging;

  final FirebaseMessaging? _override;
  FirebaseMessaging get _fm => _override ?? FirebaseMessaging.instance;

  @override
  Future<String?> token() async {
    try {
      return await _fm.getToken();
    } on Object {
      // No Play services, or offline: registration is retried on refresh.
      return null;
    }
  }

  @override
  Stream<String> get tokenRefresh => _fm.onTokenRefresh;

  @override
  Stream<PushOpen> get opened => FirebaseMessaging.onMessageOpenedApp
      .map(_open)
      .where((o) => o != null)
      .cast<PushOpen>();

  @override
  Future<PushOpen?> initialOpen() async {
    final m = await _fm.getInitialMessage();
    return m == null ? null : _open(m);
  }
}
