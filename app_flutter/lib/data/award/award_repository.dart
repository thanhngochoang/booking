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

  /// Where one proof image of an award is uploaded. [fileId] must be fresh for
  /// every upload (a new ULID): storage rules refuse overwriting a file, so an
  /// approved award's evidence cannot be swapped after review.
  String proofPath(String uid, String awardId, String fileId);
}

/// In-memory repository for widget tests. It does not model server limits
/// unless [failWith] is set.
class FakeAwardRepository implements AwardRepository {
  FakeAwardRepository({this.uid = 'p1', List<Award> awards = const []})
    : _awards = List.of(awards);

  /// The signed-in owner: `create` stores awards under this uid.
  final String uid;

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
    List<Award> now() =>
        _awards.where(where).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
        photographerId: uid,
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
    final i = _awards.indexWhere((a) => a.id == d.awardId);
    if (i >= 0) {
      final old = _awards[i];
      _awards[i] = Award(
        id: old.id,
        photographerId: old.photographerId,
        competition: d.competition,
        year: d.year,
        category: d.category,
        result: d.result,
        workPostId: d.workPostId,
        status: AwardStatus.pending,
        createdAt: old.createdAt,
      );
      _changes.add(null);
    }
  }

  @override
  Future<void> delete(String awardId) async {
    _check();
    calls.add('delete:$awardId');
    _awards.removeWhere((a) => a.id == awardId);
    _changes.add(null);
  }

  @override
  String proofPath(String uid, String awardId, String fileId) =>
      'awardProofs/$uid/$awardId/$fileId.jpg';
}
