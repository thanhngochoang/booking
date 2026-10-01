import 'package:photobooking/data/skills/photographer_skills.dart';

/// Reads and writes `photographers/{uid}.skills`. One-shot reads only: the
/// skills change when their owner saves them, so no screen needs a listener.
abstract class SkillsRepository {
  /// [PhotographerSkills.empty] when the photographer has not saved any.
  Future<PhotographerSkills> load(String uid);

  /// Writes the client-owned part (never `completeness` or `updatedAt` inside
  /// `skills`). Callers validate with `validateSkills` first.
  Future<void> save(String uid, PhotographerSkills skills);
}

class FakeSkillsRepository implements SkillsRepository {
  final _stored = <String, PhotographerSkills>{};
  int loadCalls = 0;
  int saveCalls = 0;
  Object? failLoadWith;
  Object? failSaveWith;

  void seed(String uid, PhotographerSkills skills) => _stored[uid] = skills;

  PhotographerSkills? stored(String uid) => _stored[uid];

  @override
  Future<PhotographerSkills> load(String uid) async {
    loadCalls++;
    final failure = failLoadWith;
    if (failure != null) throw failure;
    return _stored[uid] ?? PhotographerSkills.empty;
  }

  @override
  Future<void> save(String uid, PhotographerSkills skills) async {
    saveCalls++;
    final failure = failSaveWith;
    if (failure != null) throw failure;
    _stored[uid] = skills;
  }
}
