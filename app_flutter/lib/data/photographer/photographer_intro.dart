import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:photobooking/data/content/provider_type.dart';

/// Step 1 of profile setup (S08.01): what a customer reads first. Lives on the
/// public `photographers/{uid}` document; no contact data here.
@immutable
class PhotographerIntro {
  const PhotographerIntro({
    this.bio = '',
    this.equipment = const [],
    this.onboardingComplete = false,
    this.acceptingOrders = false,
    this.verified = false,
    this.businessVerified = false,
    this.providerType = ProviderType.individual,
    this.studioId,
  });

  final String bio;
  final List<String> equipment;

  /// Set by setup step 4/4 (plan 2b); read here, never written.
  final bool onboardingComplete;

  /// Customers can book and ask for quotes (server-written `acceptingOrders`;
  /// a document without it reads `verified && onboardingComplete`, as
  /// `photographerSummaryFrom`). Read here, never written.
  final bool acceptingOrders;

  /// Identity verified and approved by staff (S21); server-written.
  final bool verified;

  /// Studio business record approved (S21.04); server-written.
  final bool businessVerified;

  /// Individual, artist (server-set) or studio; changed through the
  /// `setProviderType` callable, never written here.
  final ProviderType providerType;

  /// The studio this photographer is an active member of (server-written,
  /// #136); null when independent.
  final String? studioId;

  @override
  bool operator ==(Object other) =>
      other is PhotographerIntro &&
      other.bio == bio &&
      listEquals(other.equipment, equipment) &&
      other.onboardingComplete == onboardingComplete &&
      other.acceptingOrders == acceptingOrders &&
      other.verified == verified &&
      other.businessVerified == businessVerified &&
      other.providerType == providerType &&
      other.studioId == studioId;

  @override
  int get hashCode => Object.hash(
    bio,
    Object.hashAll(equipment),
    onboardingComplete,
    acceptingOrders,
    verified,
    businessVerified,
    providerType,
    studioId,
  );
}

PhotographerIntro introFromFirestore(Map<String, dynamic> d) {
  final bio = d['bio'];
  final equipment = d['equipment'];
  final onboardingComplete = d['onboardingComplete'] == true;
  final accepting = d['acceptingOrders'];
  final verified = d['verified'] == true;
  return PhotographerIntro(
    bio: bio is String ? bio : '',
    equipment: [
      if (equipment is List)
        for (final e in equipment)
          if (e is String) e,
    ],
    onboardingComplete: onboardingComplete,
    acceptingOrders: accepting is bool
        ? accepting
        : verified && onboardingComplete,
    verified: verified,
    businessVerified: d['businessVerified'] == true,
    providerType: ProviderType.fromCode(d['providerType']),
    studioId: d['studioId'] is String && (d['studioId'] as String).isNotEmpty
        ? d['studioId'] as String
        : null,
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
      acceptingOrders: old.acceptingOrders,
      verified: old.verified,
      businessVerified: old.businessVerified,
      providerType: old.providerType,
      studioId: old.studioId,
    );
    _changes.add(uid);
  }
}
