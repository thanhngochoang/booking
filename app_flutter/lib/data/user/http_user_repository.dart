// lib/data/user/http_user_repository.dart
import 'dart:async';

import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/http/api_client.dart';
import 'package:photobooking/data/http/local_watch.dart';
import 'package:photobooking/data/http/wire.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';

/// UserRepository over the self-hosted API (users table).
class HttpUserRepository implements UserRepository {
  HttpUserRepository({required this.api});
  final ApiClient api;
  final _writes =
      StreamController<({String uid, UserProfile? profile})>.broadcast();

  void _emit(String uid, UserProfile p) => _writes.add((uid: uid, profile: p));

  Future<UserProfile?> _get(String uid) async {
    try {
      return profileFromJson(await api.get(ApiPaths.user(uid)));
    } on ApiException catch (e) {
      if (e.code == 'not_found') return null;
      rethrow;
    }
  }

  @override
  Stream<UserProfile?> watch(String uid) => fetchThenLocal(
    () => _get(uid),
    _writes.stream.where((w) => w.uid == uid).map((w) => w.profile),
  );

  @override
  Future<UserProfile> ensureProfile(AuthUser user) async {
    final p = profileFromJson(
      await api.post(ApiPaths.me, ensureProfileBody(user)),
    ).copyWith(email: user.email);
    _emit(user.uid, p);
    return p;
  }

  @override
  Future<void> setRole(String uid, UserRole role) async {
    _emit(
      uid,
      profileFromJson(
        await api.put(ApiPaths.userRole(uid), setRoleBody(role)),
      ),
    );
  }

  /// Safe to race ensureProfile, like the Firestore adapter: creates the
  /// profile when it does not exist yet.
  @override
  Future<void> setDisplayName(String uid, String name) async {
    Object? json;
    try {
      json = await api.patch(ApiPaths.user(uid), updateUserBody(name));
    } on ApiException catch (e) {
      if (e.code != 'not_found') rethrow;
      await api.post(ApiPaths.me, updateUserBody(name));
      json = await api.patch(ApiPaths.user(uid), updateUserBody(name));
    }
    _emit(uid, profileFromJson(json));
  }

  @override
  Future<String?> setAvatar(
    String uid, {
    required String url,
    required String storagePath,
  }) async {
    throw UnimplementedError(
      'setAvatar is not supported on the phase 2 HTTP adapter',
    );
  }

  void dispose() => _writes.close();
}
