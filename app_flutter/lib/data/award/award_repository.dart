import 'dart:async';

import 'package:photobooking/data/award/award.dart';

/// Reads are direct; writes go through the award callables, which validate and
/// enforce the limits. Writes throw [AwardError] with the server code.
abstract class AwardRepository {
  /// The owner's awards of every status, newest first.
  Stream<List<Award>> watchMine(String uid);

  /// Approved awards of one photographer, newest year first.
  Stream<List<Award>> watchApproved(String photographerId);

  /// For editing: the award and its proof document (owner only). Null when the
  /// award does not exist.
  Future<AwardDraft?> loadDraft(String awardId);

  Future<void> create(AwardDraft d);
  Future<void> update(AwardDraft d);
  Future<void> delete(String awardId);

  /// Where proof image [index] of an award is uploaded.
  String proofPath(String uid, String awardId, int index);
}

/// In-memory repository for widget tests. It does not model server limits
/// unless [failWith] is set.
class FakeAwardRepository implements AwardRepository {
  FakeAwardRepository([List<Award> awards = const []])
    : _awards = List.of(awards);

  final List<Award> _awards;
  final _changes = StreamController<void>.broadcast();

  /// When set, every write throws it.
  AwardError? failWith;

  /// Writes made, as `name:awardId`, for assertions.
  final calls = <String>[];

  /// Every draft passed to `create` / `update`.
  final drafts = <AwardDraft>[];

  void _check() {
    final e = failWith;
    if (e != null) {
      throw e;
    }
  }

  void add(Award a) {
    _awards.add(a);
    _changes.add(null);
  }

  Stream<List<Award>> _watch(bool Function(Award) where) async* {
    List<Award> now() => _awards.where(where).toList();
    yield now();
    await for (final _ in _changes.stream) {
      yield now();
    }
  }

  @override
  Stream<List<Award>> watchMine(String uid) =>
      _watch((a) => a.photographerId == uid);

  @override
  Stream<List<Award>> watchApproved(String photographerId) => _watch(
    (a) =>
        a.photographerId == photographerId && a.status == AwardStatus.approved,
  );

  @override
  Future<AwardDraft?> loadDraft(String awardId) async {
    for (final a in _awards) {
      if (a.id == awardId) {
        return AwardDraft(
          awardId: a.id,
          competition: a.competition,
          year: a.year,
          category: a.category,
          result: a.result,
          workPostId: a.workPostId,
        );
      }
    }
    return null;
  }

  @override
  Future<void> create(AwardDraft d) async {
    _check();
    calls.add('create:${d.awardId}');
    drafts.add(d);
    add(
      Award(
        id: d.awardId,
        photographerId: 'me',
        competition: d.competition,
        year: d.year,
        category: d.category,
        result: d.result,
        workPostId: d.workPostId,
        status: AwardStatus.pending,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<void> update(AwardDraft d) async {
    _check();
    calls.add('update:${d.awardId}');
    drafts.add(d);
  }

  @override
  Future<void> delete(String awardId) async {
    _check();
    calls.add('delete:$awardId');
    _awards.removeWhere((a) => a.id == awardId);
    _changes.add(null);
  }

  @override
  String proofPath(String uid, String awardId, int index) =>
      'awardProofs/$uid/$awardId/$index.jpg';
}
