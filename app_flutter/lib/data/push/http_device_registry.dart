// lib/data/push/http_device_registry.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/http/wire.dart';
import 'package:photobooking/data/push/device_registry.dart';
import 'package:photobooking/data/push/firestore_device_registry.dart';

class HttpDeviceRegistry implements DeviceRegistry {
  HttpDeviceRegistry({
    required this.api,
    required this.prefs,
    this.platform,
  });

  final ApiClient api;
  final SharedPreferences prefs;
  final String? platform;

  String get _platformName =>
      platform ??
      (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

  @override
  Future<void> register({required String uid, required String token}) =>
      api.put(
        ApiPaths.device(installIdFrom(prefs)),
        registerDeviceBody(
          token: token,
          platform: _platformName,
          provider: 'fcm',
        ),
      );

  @override
  Future<void> unregister(String uid) async {
    try {
      await api.delete(ApiPaths.device(installIdFrom(prefs)));
    } on ApiException catch (e) {
      if (e.status == 404 || e.code == 'not_found') {
        return;
      }
      rethrow;
    }
  }
}
