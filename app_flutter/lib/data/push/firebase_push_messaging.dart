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

// firebase_messaging 17 deprecates the FCM-token API in favour of register()/onRegistered, which
// yield a Firebase Installation ID (FID) instead of a token. The Cloud Functions send to FCM
// tokens, so this adapter keeps the token API until the backend moves to FID direct-send.
class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging({FirebaseMessaging? messaging}) : _override = messaging;

  final FirebaseMessaging? _override;
  FirebaseMessaging get _fm => _override ?? FirebaseMessaging.instance;

  @override
  Future<String?> token() async {
    try {
      // ignore: deprecated_member_use
      return await _fm.getToken();
    } on Object {
      // No Play services, or offline: registration is retried on refresh.
      return null;
    }
  }

  @override
  // ignore: deprecated_member_use
  Future<void> deleteToken() => _fm.deleteToken();

  @override
  // ignore: deprecated_member_use
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
