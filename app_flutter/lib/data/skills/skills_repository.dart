import 'package:photobooking/data/skills/photographer_skills.dart';
import 'package:photobooking/data/skills/skills_server_info.dart';

/// Reads and writes `photographers/{uid}.skills`. One-shot reads only: the
/// skills change when their owner saves them, so no screen needs a listener.
abstract class SkillsRepository {
  /// The skills ([PhotographerSkills.empty] when none are saved) and what the
  /// server wrote about them ([SkillsServerInfo.none] until scored).
  Future<SkillsSnapshot> load(String uid);

  /// Writes the client-owned part (never the server fields `completeness`,
  /// `completenessNext`, `completenessNextAfter`, `updatedAt`, `evidenceRemovedAt` inside `skills`).
  /// Callers validate with `validateSkills` first.
  Future<void> save(String uid, PhotographerSkills skills);
}

class FakeSkillsRepository implements SkillsRepository {
  final _stored = <String, PhotographerSkills>{};
  final _server = <String, SkillsServerInfo>{};
  int loadCalls = 0;
  int saveCalls = 0;
  Object? failLoadWith;
  Object? failSaveWith;

  /// When set, [save] waits for it (a save still in flight).
  Future<void>? holdSave;

  void seed(String uid, PhotographerSkills skills) => _stored[uid] = skills;

  /// What `onPhotographerWrite` would have written; kept across [save], like
  /// the merge write keeps the server fields.
  void seedServer(String uid, SkillsServerInfo info) => _server[uid] = info;

  PhotographerSkills? stored(String uid) => _stored[uid];

  @override
  Future<SkillsSnapshot> load(String uid) async {
    loadCalls++;
    final failure = failLoadWith;
    if (failure != null) throw failure;
    return SkillsSnapshot(
      _stored[uid] ?? PhotographerSkills.empty,
      _server[uid] ?? SkillsServerInfo.none,
    );
  }

  @override
  Future<void> save(String uid, PhotographerSkills skills) async {
    saveCalls++;
    final hold = holdSave;
    if (hold != null) await hold;
    final failure = failSaveWith;
    if (failure != null) throw failure;
    _stored[uid] = skills;
  }
}
