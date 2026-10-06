import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/data/push/device_registry.dart';

const _installKey = 'pushInstallId';

/// A random 16-hex install id kept in preferences (rules: 8-40 alphanumerics).
String installIdFrom(SharedPreferences prefs, {Random? random}) {
  final saved = prefs.getString(_installKey);
  if (saved != null && RegExp(r'^[A-Za-z0-9]{8,40}$').hasMatch(saved)) {
    return saved;
  }
  final r = random ?? Random.secure();
  final id = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  prefs.setString(_installKey, id);
  return id;
}

/// `devices/{uid}_{installId}` with `{userId, provider, token, platform,
/// lastSeenAt}`, exactly the keys the rules allow.
class FirestoreDeviceRegistry implements DeviceRegistry {
  FirestoreDeviceRegistry({
    required this.prefs,
    FirebaseFirestore? db,
    this.platform,
  }) : _override = db;

  final SharedPreferences prefs;

  /// `android` or `ios`; the running platform when null.
  final String? platform;
  final FirebaseFirestore? _override;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  String get _platformName =>
      platform ??
      (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('devices').doc('${uid}_${installIdFrom(prefs)}');

  @override
  Future<void> register({required String uid, required String token}) =>
      _doc(uid).set({
        'userId': uid,
        'provider': 'fcm',
        'token': token,
        'platform': _platformName,
        'lastSeenAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> unregister(String uid) => _doc(uid).delete();
}
