import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/studio/studio_repository.dart';

/// `studio_members` and `studio_quota` listeners plus the S26 callables.
class FirestoreStudioRepository implements StudioRepository {
  FirestoreStudioRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    DateTime Function()? clock,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _customFunctions = functions,
       _clock = clock ?? (() => DateTime.now().toUtc());

  final FirebaseFirestore _db;
  final FirebaseFunctions? _customFunctions;
  final DateTime Function() _clock;

  FirebaseFunctions get _functions =>
      _customFunctions ??
      FirebaseFunctions.instanceFor(region: functionsRegion);

  static const _openStatuses = ['invited', 'requested', 'active'];

  /// Index `studio_members (<party>, status, createdAt desc)`; the rules let
  /// each party read only its own relations.
  Stream<List<StudioRelation>> _relations(String field, String uid) => _db
      .collection('studio_members')
      .where(field, isEqualTo: uid)
      .where('status', whereIn: _openStatuses)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (qs) => [
          for (final d in qs.docs) ?studioRelationFrom(d.id, d.data()),
        ],
      );

  @override
  Stream<List<StudioRelation>> watchStudioRelations(String studioId) =>
      _relations('studioId', studioId);

  @override
  Stream<List<StudioRelation>> watchMemberRelations(String memberId) =>
      _relations('memberId', memberId);

  @override
  Stream<StudioQuota> watchQuota(String uid, {required bool studio}) => _db
      .collection('studio_quota')
      .doc(uid)
      .snapshots()
      .map((s) => studioQuotaFrom(s.data(), studio: studio, now: _clock()));

  Future<Object?> _call(String name, Map<String, Object?> data) async {
    try {
      final res = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          )
          .call<Object?>(data);
      return res.data;
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      throw StudioError(
        details is Map && details['code'] is String
            ? details['code'] as String
            : e.code,
      );
    }
  }

  Map<String, dynamic> _map(Object? raw) =>
      raw is Map ? raw.cast<String, dynamic>() : const {};

  Future<String> _relationId(String name, Map<String, Object?> data) async {
    final id = _map(await _call(name, data))['relationId'];
    if (id is! String) throw const StudioError('invalid_response');
    return id;
  }

  @override
  Future<String> invite(String memberId) =>
      _relationId('inviteMember', {'memberId': memberId});

  @override
  Future<void> cancelInvite(String relationId) =>
      _call('cancelInvite', {'relationId': relationId});

  @override
  Future<String> requestToJoin(String studioId) =>
      _relationId('requestToJoin', {'studioId': studioId});

  @override
  Future<void> cancelJoinRequest(String relationId) =>
      _call('cancelJoinRequest', {'relationId': relationId});

  @override
  Future<void> respondInvite(String relationId, {required bool accept}) =>
      _call('respondInvite', {'relationId': relationId, 'accept': accept});

  @override
  Future<void> respondJoinRequest(String relationId, {required bool accept}) =>
      _call('respondJoinRequest', {'relationId': relationId, 'accept': accept});

  @override
  Future<void> leave() => _call('leaveStudio', {});

  @override
  Future<void> remove(String memberId) =>
      _call('removeMember', {'memberId': memberId});

  @override
  Future<List<InviteCandidate>> search(String query) async {
    final rows = _map(
      await _call('searchPhotographersToInvite', {'query': query}),
    )['rows'];
    return [
      if (rows is List)
        for (final r in rows)
          if (r is Map) ?inviteCandidateFrom(r.cast<String, dynamic>()),
    ];
  }

  @override
  Future<({DateTime deadline, List<AssignmentOption> options})>
  assignmentOptions(String bookingId) async {
    final res = _map(
      await _call('assignmentOptions', {'bookingId': bookingId}),
    );
    final raw = res['deadline'];
    final deadline = raw is String ? DateTime.tryParse(raw)?.toUtc() : null;
    if (deadline == null) throw const StudioError('invalid_response');
    final options = res['options'];
    return (
      deadline: deadline,
      options: [
        if (options is List)
          for (final o in options)
            if (o is Map) ?assignmentOptionFrom(o.cast<String, dynamic>()),
      ],
    );
  }
}
