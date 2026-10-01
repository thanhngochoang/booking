import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../auth/auth_repository.dart';
import 'user_profile.dart';

abstract class UserRepository {
  Stream<UserProfile?> watch(String uid);

  /// Creates users/{uid} with role null when missing; never overwrites.
  Future<UserProfile> ensureProfile(AuthUser user);

  /// Sets the role; also creates photographers/{uid} for photographers.
  Future<void> setRole(String uid, UserRole role);
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
      ...profile.toJson()..remove('uid'),
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
      batch.set(
        _db.collection('photographers').doc(uid),
        {
          'onboardingComplete': false,
          'verified': false,
          'specialties': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }
}

class FakeUserRepository implements UserRepository {
  final _profiles = <String, UserProfile>{};
  final photographerDocs = <String>{};
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
    final p = _profiles[uid]!.copyWith(role: role);
    _profiles[uid] = p;
    if (role == UserRole.photographer) photographerDocs.add(uid);
    _c(uid).add(p);
  }
}
