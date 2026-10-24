import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/collab/collab_repository.dart';
import 'package:photobooking/data/recruit/firestore_recruit_repository.dart'
    show callRecruitFunction, recruitDateOf;
import 'package:photobooking/data/recruit/recruit_post.dart';

String _text(Object? v) => v is String ? v : '';
String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

/// `studio_collaborations/{studioId}_{uid}` (or a `history` copy); null
/// without its parties, a known status or `createdAt`.
Collaboration? collaborationFrom(String id, Map<String, dynamic> d) {
  final studioId = _str(d['studioId']);
  final collaboratorId = _str(d['collaboratorId']);
  final status = CollabStatus.fromCode(d['status']);
  final createdAt = recruitDateOf(d['createdAt']);
  if (studioId == null ||
      collaboratorId == null ||
      status == null ||
      createdAt == null) {
    return null;
  }
  final studio = _map(d['studio']);
  final collaborator = _map(d['collaborator']);
  final fee = d['defaultFee'];
  return Collaboration(
    id: id,
    studioId: studioId,
    collaboratorId: collaboratorId,
    studioName: _text(studio['name']),
    studioAvatarUrl: _str(studio['avatarUrl']),
    collaboratorName: _text(collaborator['name']),
    collaboratorAvatarUrl: _str(collaborator['avatarUrl']),
    status: status,
    defaultFee: fee is num ? fee.toInt() : null,
    activeAt: recruitDateOf(d['activeAt']),
    expiresAt: recruitDateOf(d['expiresAt']) ?? createdAt,
    endedAt: recruitDateOf(d['endedAt']),
  );
}

/// `collab_jobs/{bookingId}_{uid}`; null without its parties, a known offer
/// status or the offer dates. The pay record is the nested `pay` map.
CollabJob? collabJobFrom(String id, Map<String, dynamic> d) {
  final bookingId = _str(d['bookingId']);
  final studioId = _str(d['studioId']);
  final collaboratorId = _str(d['collaboratorId']);
  final offerStatus = OfferStatus.fromCode(d['offerStatus']);
  final offerAt = recruitDateOf(d['offerAt']);
  final offerExpiresAt = recruitDateOf(d['offerExpiresAt']);
  if (bookingId == null ||
      studioId == null ||
      collaboratorId == null ||
      offerStatus == null ||
      offerAt == null ||
      offerExpiresAt == null) {
    return null;
  }
  final shoot = _map(d['shoot']);
  final pay = _map(d['pay']);
  final fee = d['agreedFee'];
  return CollabJob(
    id: id,
    bookingId: bookingId,
    studioId: studioId,
    collaboratorId: collaboratorId,
    studioName: _text(d['studioName']),
    collaboratorName: _text(d['collaboratorName']),
    day: _text(shoot['day']),
    start: _text(shoot['start']),
    end: _text(shoot['end']),
    serviceName: _text(shoot['serviceName']),
    placeName: _text(shoot['placeName']),
    agreedFee: fee is num ? fee.toInt() : 0,
    offerStatus: offerStatus,
    offerExpiresAt: offerExpiresAt,
    acceptedAt: recruitDateOf(d['acceptedAt']),
    payStatus: PayStatus.fromCode(d['payStatus']),
    payDueAt: recruitDateOf(pay['dueAt']),
    paidOn: _str(pay['paidOn']),
    payMethod: CollabPayMethod.fromCode(pay['method']),
    reportedAt: recruitDateOf(pay['reportedAt']),
    updatedAt: recruitDateOf(d['updatedAt']) ?? offerAt,
  );
}

/// `studio_collaborations` and `collab_jobs` listeners plus the nine
/// collaboration callables (Task 5).
class FirestoreCollabRepository implements CollabRepository {
  FirestoreCollabRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _override = firestore,
       _customFunctions = functions;

  final FirebaseFirestore? _override;
  final FirebaseFunctions? _customFunctions;

  FirebaseFirestore get _db => _override ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _customFunctions ??
      FirebaseFunctions.instanceFor(region: functionsRegion);

  static final _openStatuses = [
    CollabStatus.invited.code,
    CollabStatus.active.code,
  ];

  Future<Object?> _call(String name, Map<String, Object?> data) =>
      callRecruitFunction(_functions, name, data);

  /// Index `studio_collaborations (<party>, status, updatedAt desc)`.
  Stream<List<Collaboration>> _collaborations(
    String field,
    String uid,
    int limit,
  ) => _db
      .collection('studio_collaborations')
      .where(field, isEqualTo: uid)
      .where('status', whereIn: _openStatuses)
      .orderBy('updatedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [for (final d in s.docs) ?collaborationFrom(d.id, d.data())]);

  List<CollabJob> _jobsOf(QuerySnapshot<Map<String, dynamic>> s) => [
    for (final d in s.docs) ?collabJobFrom(d.id, d.data()),
  ];

  /// Index `collab_jobs (<party>, updatedAt desc)`.
  Stream<List<CollabJob>> _jobs(String field, String uid, int limit) => _db
      .collection('collab_jobs')
      .where(field, isEqualTo: uid)
      .orderBy('updatedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(_jobsOf);

  @override
  Stream<List<Collaboration>> watchAsStudio(String studioId) =>
      _collaborations('studioId', studioId, 60);

  @override
  Stream<List<Collaboration>> watchAsCollaborator(String uid) =>
      _collaborations('collaboratorId', uid, 20);

  @override
  Stream<List<CollabJob>> watchJobsAsStudio(
    String studioId, {
    int limit = 50,
  }) => _jobs('studioId', studioId, limit);

  @override
  Stream<List<CollabJob>> watchJobsAsCollaborator(
    String uid, {
    int limit = 50,
  }) => _jobs('collaboratorId', uid, limit);

  /// Index `collab_jobs (studioId, pay.dueAt)`.
  @override
  Future<List<CollabJob>> jobsDueInMonth(
    String studioId,
    int year,
    int month,
  ) async {
    final (from, to) = vnMonthRange(year, month);
    final snap = await _db
        .collection('collab_jobs')
        .where('studioId', isEqualTo: studioId)
        .where('pay.dueAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('pay.dueAt', isLessThan: Timestamp.fromDate(to))
        .orderBy('pay.dueAt')
        .get();
    return _jobsOf(snap);
  }

  @override
  Future<void> invite(String collaboratorId, {int? defaultFee}) => _call(
    'inviteCollaborator',
    {'collaboratorId': collaboratorId, 'defaultFee': ?defaultFee},
  );

  @override
  Future<void> cancelInvite(String collaboratorId) =>
      _call('cancelCollabInvite', {'collaboratorId': collaboratorId});

  @override
  Future<void> respondInvite(
    String studioId, {
    required bool accept,
    required bool acceptTerms,
  }) => _call('respondCollabInvite', {
    'studioId': studioId,
    'accept': accept,
    'acceptTerms': acceptTerms,
  });

  @override
  Future<void> end({String? studioId, String? collaboratorId}) => _call(
    'endCollaboration',
    collabPartyPayload(studioId: studioId, collaboratorId: collaboratorId),
  );

  @override
  Future<void> setDefaultFee(String collaboratorId, int? fee) => _call(
    'setCollabDefaultFee',
    {'collaboratorId': collaboratorId, 'defaultFee': fee},
  );

  @override
  Future<OfferStatus> respondOffer(
    String bookingId, {
    required bool accept,
  }) async {
    final status = OfferStatus.fromCode(
      _map(
        await _call('respondCollabOffer', {
          'bookingId': bookingId,
          'accept': accept,
        }),
      )['offerStatus'],
    );
    if (status == null) throw const RecruitError(RecruitErrorCode.unknown);
    return status;
  }

  @override
  Future<void> reportPaid(
    String bookingId,
    String collaboratorId, {
    required DateTime paidOn,
    required CollabPayMethod method,
  }) => _call('reportCollabPaid', {
    'bookingId': bookingId,
    'collaboratorId': collaboratorId,
    'paidOn': dayKeyOf(paidOn),
    'method': method.code,
  });

  @override
  Future<void> confirmPay(String bookingId, {required bool received}) =>
      _call('confirmCollabPay', {'bookingId': bookingId, 'received': received});

  @override
  Future<String> openChat({String? studioId, String? collaboratorId}) async {
    final id = _map(
      await _call(
        'openCollabChat',
        collabPartyPayload(studioId: studioId, collaboratorId: collaboratorId),
      ),
    )['chatId'];
    if (id is! String) throw const RecruitError(RecruitErrorCode.unknown);
    return id;
  }
}
