import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/user/user_profile.dart';

/// Fields written to users/{uid}. Every signed-in user can read that doc,
/// so the email (already in Firebase Auth) is never stored there.
Map<String, dynamic> profileToFirestore(UserProfile p) => p.toJson()
  ..remove('uid')
  ..remove('email');

abstract class UserRepository {
  Stream<UserProfile?> watch(String uid);

  /// Creates users/{uid} with role null when missing; never overwrites.
  Future<UserProfile> ensureProfile(AuthUser user);

  /// Sets the role. The first switch to photographer creates
  /// photographers/{uid}; later switches keep that doc (and its onboarding
  /// progress) untouched, so people can move between modes freely.
  Future<void> setRole(String uid, UserRole role);

  /// Creates or updates users/{uid}.displayName; safe to race ensureProfile.
  Future<void> setDisplayName(String uid, String name);

  /// Points users/{uid} at a newly uploaded avatar ([url] for display,
  /// [storagePath] so it can be deleted later). Returns the previous
  /// storage path, or null when the old photo was not uploaded by the app.
  Future<String?> setAvatar(
    String uid, {
    required String url,
    required String storagePath,
  });
}

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Stream<UserProfile?> watch(String uid) => _doc(uid).snapshots().map(
    (s) => s.data() == null
        ? null
        : UserProfile.fromJson({...s.data()!, 'uid': uid}),
  );

  @override
  Future<UserProfile> ensureProfile(AuthUser user) async {
    final snap = await _doc(user.uid).get();
    if (snap.exists) {
      return UserProfile.fromJson({...snap.data()!, 'uid': user.uid});
    }
    final profile = UserProfile(
      uid: user.uid,
      displayName:
          user.displayName ?? user.email?.split('@').first ?? 'Người dùng',
      avatarUrl: user.photoUrl,
      email: user.email,
    );
    await _doc(user.uid).set({
      ...profileToFirestore(profile),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return profile;
  }

  @override
  Future<void> setRole(String uid, UserRole role) async {
    final batch = _db.batch();
    batch.update(_doc(uid), {
      'role': role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (role == UserRole.photographer) {
      final photographer = _db.collection('photographers').doc(uid);
      // Re-setting these on a returning photographer would reset their
      // onboarding, and rules reject touching `verified` once it is true.
      if (!(await photographer.get()).exists) {
        batch.set(photographer, {
          'onboardingComplete': false,
          'verified': false,
          'specialties': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  @override
  Future<void> setDisplayName(String uid, String name) => _doc(uid).set({
    'displayName': name,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  @override
  Future<String?> setAvatar(
    String uid, {
    required String url,
    required String storagePath,
  }) async {
    final old = (await _doc(uid).get()).data()?['avatarPath'];
    await _doc(uid).set({
      'avatarUrl': url,
      'avatarPath': storagePath,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return old is String ? old : null;
  }
}

class FakeUserRepository implements UserRepository {
  FakeUserRepository({this.failEnsure = false, this.failSetRole = false});
  final bool failEnsure;
  final bool failSetRole;
  final _profiles = <String, UserProfile>{};
  final photographerDocs = <String>{};
  final avatarPaths = <String, String>{};
  bool failSetAvatar = false;
  final _controllers = <String, StreamController<UserProfile?>>{};

  StreamController<UserProfile?> _c(String uid) => _controllers.putIfAbsent(
    uid,
    () => StreamController<UserProfile?>.broadcast(),
  );

  @override
  Stream<UserProfile?> watch(String uid) async* {
    yield _profiles[uid];
    yield* _c(uid).stream;
  }

  @override
  Future<UserProfile> ensureProfile(AuthUser user) async {
    if (failEnsure) throw StateError('unavailable');
    final existing = _profiles[user.uid];
    if (existing != null) return existing;
    final p = UserProfile(
      uid: user.uid,
      displayName: user.displayName ?? 'Người dùng',
      email: user.email,
      avatarUrl: user.photoUrl,
    );
    _profiles[user.uid] = p;
    _c(user.uid).add(p);
    return p;
  }

  @override
  Future<void> setRole(String uid, UserRole role) async {
    if (failSetRole) throw StateError('unavailable');
    final p = _profiles[uid]!.copyWith(role: role);
    _profiles[uid] = p;
    if (role == UserRole.photographer) photographerDocs.add(uid);
    _c(uid).add(p);
  }

  @override
  Future<void> setDisplayName(String uid, String name) async {
    final p = (_profiles[uid] ?? UserProfile(uid: uid, displayName: name))
        .copyWith(displayName: name);
    _profiles[uid] = p;
    _c(uid).add(p);
  }

  @override
  Future<String?> setAvatar(
    String uid, {
    required String url,
    required String storagePath,
  }) async {
    if (failSetAvatar) throw StateError('unavailable');
    final old = avatarPaths[uid];
    avatarPaths[uid] = storagePath;
    final p =
        (_profiles[uid] ?? UserProfile(uid: uid, displayName: 'Người dùng'))
            .copyWith(avatarUrl: url);
    _profiles[uid] = p;
    _c(uid).add(p);
    return old;
  }

  /// Simulates an admin deleting users/{uid} while the app is open.
  void deleteProfile(String uid) {
    _profiles.remove(uid);
    _c(uid).add(null);
  }
}
