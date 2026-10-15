// lib/data/user/http_user_contact_repository.dart
import 'dart:async';

import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/http/local_watch.dart';
import 'package:photobooking/data/http/wire.dart';
import 'package:photobooking/data/user/user_contact_repository.dart';

/// UserContactRepository over the self-hosted API (user_contacts, owner only).
class HttpUserContactRepository implements UserContactRepository {
  HttpUserContactRepository({required this.api});
  final ApiClient api;
  final _writes =
      StreamController<({String uid, UserContact? contact})>.broadcast();

  Future<UserContact?> _get(String uid) async {
    try {
      return userContactFromJson(await api.get(ApiPaths.userContact(uid)));
    } on ApiException catch (e) {
      if (e.code == 'not_found') return null;
      rethrow;
    }
  }

  @override
  Stream<UserContact?> watch(String uid) => fetchThenLocal(
    () => _get(uid),
    _writes.stream.where((w) => w.uid == uid).map((w) => w.contact),
  );

  /// One PUT: the server keeps or resets `phoneVerified` itself, so there is
  /// no read-before-write like the Firestore adapter needs.
  @override
  Future<void> save(
    String uid, {
    required String phone,
    required bool allowZalo,
    required bool allowWhatsApp,
  }) async {
    final json = await api.put(
      ApiPaths.userContact(uid),
      saveContactBody(
        phone: phone,
        allowZalo: allowZalo,
        allowWhatsApp: allowWhatsApp,
      ),
    );
    _writes.add((uid: uid, contact: userContactFromJson(json)));
  }

  void dispose() => _writes.close();
}
