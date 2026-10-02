import 'dart:async';

import 'package:flutter/foundation.dart';

/// Step 1 of profile setup (S24): what a customer reads first. Lives on the
/// public `photographers/{uid}` document; no contact data here.
@immutable
class PhotographerIntro {
  const PhotographerIntro({
    this.bio = '',
    this.equipment = const [],
    this.onboardingComplete = false,
  });

  final String bio;
  final List<String> equipment;

  /// Set by setup step 4/4 (plan 2b); read here, never written.
  final bool onboardingComplete;

  @override
  bool operator ==(Object other) =>
      other is PhotographerIntro &&
      other.bio == bio &&
      listEquals(other.equipment, equipment) &&
      other.onboardingComplete == onboardingComplete;

  @override
  int get hashCode =>
      Object.hash(bio, Object.hashAll(equipment), onboardingComplete);
}

PhotographerIntro introFromFirestore(Map<String, dynamic> d) {
  final bio = d['bio'];
  final equipment = d['equipment'];
  return PhotographerIntro(
    bio: bio is String ? bio : '',
    equipment: [
      if (equipment is List)
        for (final e in equipment)
          if (e is String) e,
    ],
    onboardingComplete: d['onboardingComplete'] == true,
  );
}

Map<String, dynamic> introToFirestore({
  required String bio,
  required List<String> equipment,
}) => {'bio': bio, 'equipment': equipment};

abstract class PhotographerIntroRepository {
  /// The intro of [uid] now and after every change; null without a
  /// photographer document.
  Stream<PhotographerIntro?> watch(String uid);

  Future<PhotographerIntro?> get(String uid);

  /// Writes bio and equipment; nothing else on the document changes.
  Future<void> save(
    String uid, {
    required String bio,
    required List<String> equipment,
  });
}

class FakePhotographerIntroRepository implements PhotographerIntroRepository {
  FakePhotographerIntroRepository({this.failSave = false});

  bool failSave;
  int watchers = 0;
  int saves = 0;
  final _intros = <String, PhotographerIntro>{};
  final _changes = StreamController<String>.broadcast();

  void seed(String uid, PhotographerIntro intro) {
    _intros[uid] = intro;
    _changes.add(uid);
  }

  PhotographerIntro? stored(String uid) => _intros[uid];

  @override
  Stream<PhotographerIntro?> watch(String uid) {
    late final StreamController<PhotographerIntro?> out;
    StreamSubscription<String>? inner;
    out = StreamController<PhotographerIntro?>(
      onListen: () {
        watchers++;
        out.add(_intros[uid]);
        inner = _changes.stream
            .where((u) => u == uid)
            .listen((_) => out.add(_intros[uid]));
      },
      onCancel: () async {
        watchers--;
        await inner?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<PhotographerIntro?> get(String uid) async => _intros[uid];

  @override
  Future<void> save(
    String uid, {
    required String bio,
    required List<String> equipment,
  }) async {
    if (failSave) {
      throw StateError('unavailable');
    }
    saves++;
    final old = _intros[uid] ?? const PhotographerIntro();
    _intros[uid] = PhotographerIntro(
      bio: bio,
      equipment: List.unmodifiable(equipment),
      onboardingComplete: old.onboardingComplete,
    );
    _changes.add(uid);
  }
}
