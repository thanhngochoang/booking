import 'package:flutter/foundation.dart';

import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/photographer/photographer_intro.dart';

/// What S03.01 shows about a photographer: the discovery summary (name, avatar,
/// verified, stats, area, starting price) plus the intro of setup step 1.
/// Built only from public documents; contact numbers are never part of it.
@immutable
class PhotographerProfile {
  const PhotographerProfile({
    required this.summary,
    this.intro = const PhotographerIntro(),
  });

  final PhotographerSummary summary;
  final PhotographerIntro intro;

  String get id => summary.id;

  /// Setup finished (S08.05 sets `onboardingComplete`); only then is the
  /// profile shown to other people.
  bool get published => intro.onboardingComplete;
}

abstract class PublicProfileRepository {
  /// One-shot read; null when [uid] has no photographer document.
  Future<PhotographerProfile?> load(String uid);
}

class FakePublicProfileRepository implements PublicProfileRepository {
  FakePublicProfileRepository([Iterable<PhotographerProfile> seed = const []]) {
    seed.forEach(add);
  }

  final _profiles = <String, PhotographerProfile>{};
  Object? failWith;
  int loads = 0;

  void add(PhotographerProfile p) => _profiles[p.id] = p;

  @override
  Future<PhotographerProfile?> load(String uid) async {
    loads++;
    final error = failWith;
    if (error != null) {
      throw error;
    }
    return _profiles[uid];
  }
}
