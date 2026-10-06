import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/data/award/award.dart';
import 'package:photobooking/data/award/award_repository.dart';
import 'package:photobooking/data/backend/backend_config.dart';

bool _validId(String id) => id.isNotEmpty && !id.contains('/');

DateTime _time(Object? v) =>
    v is Timestamp ? v.toDate().toUtc() : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

/// Parses an `awards` doc; null when it cannot be shown (missing fields or an
/// unknown result code).
Award? awardFromFirestore(String id, Map<String, dynamic> d) {
  final photographerId = d['photographerId'];
  final competition = d['competition'];
  final year = d['year'];
  final result = AwardResult.fromCode(d['result']);
  if (photographerId is! String ||
      competition is! String ||
      year is! num ||
      result == null) {
    return null;
  }
  return Award(
    id: id,
    photographerId: photographerId,
    competition: competition,
    year: year.toInt(),
    category: _str(d['category']),
    result: result,
    workPostId: _str(d['workPostId']),
    status: AwardStatus.fromCode(d['status']),
    reviewNote: _str(d['reviewNote']),
    createdAt: _time(d['createdAt']),
  );
}

/// Reads `awards` and `awardProofs` directly; writes go through the award
/// callables.
class FirestoreAwardRepository implements AwardRepository {
  FirestoreAwardRepository({
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  }) : _override = db,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  final FirebaseFirestore? _override;
  final FirebaseFunctions _functions;
  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;

  Future<Object?> _call(String name, Map<String, Object?> data) async {
    try {
      final r = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          )
          .call<Object?>(data);
      return r.data;
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final code = details is Map && details['code'] is String
          ? details['code'] as String
          : (e.message ?? e.code);
      throw AwardError(code);
    }
  }

  Stream<List<Award>> _watch(Query<Map<String, dynamic>> q) =>
      q.snapshots().map(
        (snap) => [
          for (final d in snap.docs) ?awardFromFirestore(d.id, d.data()),
        ],
      );

  @override
  Stream<List<Award>> watchMine(String uid) => _watch(
    _db
        .collection('awards')
        .where('photographerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true),
  );

  @override
  Stream<List<Award>> watchApproved(String photographerId) => _watch(
    _db
        .collection('awards')
        .where('photographerId', isEqualTo: photographerId)
        .where('status', isEqualTo: AwardStatus.approved.code)
        .orderBy('year', descending: true)
        .orderBy('createdAt', descending: true),
  );

  @override
  Future<AwardDraft?> loadDraft(String awardId) async {
    if (!_validId(awardId)) {
      return null;
    }
    final snap = await _db.collection('awards').doc(awardId).get();
    final data = snap.data();
    final award = data == null ? null : awardFromFirestore(snap.id, data);
    if (award == null) {
      return null;
    }
    final proof = (await _db.collection('awardProofs').doc(awardId).get())
        .data();
    final files = proof?['files'];
    final links = proof?['links'];
    return AwardDraft(
      awardId: awardId,
      competition: award.competition,
      year: award.year,
      category: award.category,
      result: award.result,
      workPostId: award.workPostId,
      proofPaths: [
        if (files is List)
          for (final f in files)
            if (f is Map && f['storagePath'] is String)
              f['storagePath'] as String,
      ],
      proofLinks: [
        if (links is List)
          for (final l in links)
            if (l is String) l,
      ],
    );
  }

  Map<String, Object?> _payload(AwardDraft d) => {
    'awardId': d.awardId,
    'competition': d.competition,
    'year': d.year,
    'category': ?d.category,
    'result': d.result.code,
    'workPostId': ?d.workPostId,
    'proofFiles': d.proofPaths,
    'proofLinks': d.proofLinks,
  };

  @override
  Future<void> create(AwardDraft d) async {
    await _call('createAward', _payload(d));
  }

  @override
  Future<void> update(AwardDraft d) async {
    await _call('updateAward', _payload(d));
  }

  @override
  Future<void> delete(String awardId) async {
    await _call('deleteAward', {'awardId': awardId});
  }

  @override
  String proofPath(String uid, String awardId, String fileId) =>
      'awardProofs/$uid/$awardId/$fileId.jpg';
}
