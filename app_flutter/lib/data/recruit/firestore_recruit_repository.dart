import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/recruit/recruit_parse.dart';
import 'package:photobooking/data/recruit/recruit_repository.dart';

// ── parsing (Task 5's recruit_mapping.ts shapes) ──

/// A Timestamp (Firestore), a DateTime or an ISO string (callable answers);
/// UTC.
DateTime? recruitDateOf(Object? v) {
  if (v is Timestamp) return v.toDate().toUtc();
  if (v is DateTime) return v.toUtc();
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toUtc();
  return null;
}

FeeHint _feeOf(Object? raw) {
  final m = mapOf(raw);
  final amount = m['amount'];
  return m['type'] == 'per_shoot' && amount is num
      ? PerShootFee(amount.toInt())
      : const NegotiableFee();
}

/// `recruitPosts/{id}`; null without its studio, a known kind and status, or
/// its dates.
RecruitPost? recruitPostFrom(String id, Map<String, dynamic> d) {
  final studioId = nonEmptyOf(d['studioId']);
  final kind = RecruitKind.fromCode(d['kind']);
  final status = RecruitPostStatus.fromCode(d['status']);
  final createdAt = recruitDateOf(d['createdAt']);
  final expiresAt = recruitDateOf(d['expiresAt']);
  if (studioId == null ||
      kind == null ||
      status == null ||
      createdAt == null ||
      expiresAt == null) {
    return null;
  }
  final studio = mapOf(d['studio']);
  return RecruitPost(
    id: id,
    studioId: studioId,
    studioName: textOf(studio['name']),
    studioAvatarUrl: nonEmptyOf(studio['avatarUrl']),
    studioBusinessVerified: studio['businessVerified'] == true,
    kind: kind,
    title: textOf(d['title']),
    specialties: stringsOf(d['specialties']),
    areas: stringsOf(d['areas']),
    frequency: RecruitFrequency.fromCode(d['frequency']),
    fee: _feeOf(d['feeHint']),
    requirements: textOf(d['requirements']),
    status: status,
    renewed: d['renewed'] == true,
    applicationCount: intOf(d['applicationCount']),
    matchKeys: stringsOf(d['matchKeys']),
    createdAt: createdAt,
    expiresAt: expiresAt,
  );
}

/// `recruitApplications/{postId}_{uid}`; null without its parties, a known
/// kind and status, or its dates.
RecruitApplication? recruitApplicationFrom(String id, Map<String, dynamic> d) {
  final postId = nonEmptyOf(d['postId']);
  final studioId = nonEmptyOf(d['studioId']);
  final applicantId = nonEmptyOf(d['applicantId']);
  final kind = RecruitKind.fromCode(d['kind']);
  final status = ApplicationStatus.fromCode(d['status']);
  final createdAt = recruitDateOf(d['createdAt']);
  final expiresAt = recruitDateOf(d['expiresAt']);
  if (postId == null ||
      studioId == null ||
      applicantId == null ||
      kind == null ||
      status == null ||
      createdAt == null ||
      expiresAt == null) {
    return null;
  }
  final applicant = mapOf(d['applicant']);
  return RecruitApplication(
    id: id,
    postId: postId,
    studioId: studioId,
    applicantId: applicantId,
    kind: kind,
    postTitle: textOf(d['postTitle']),
    applicantName: textOf(applicant['name']),
    applicantAvatarUrl: nonEmptyOf(applicant['avatarUrl']),
    status: status,
    message: textOf(d['message']),
    samplePostIds: stringsOf(d['samplePostIds']),
    createdAt: createdAt,
    expiresAt: expiresAt,
    respondedAt: recruitDateOf(d['respondedAt']),
  );
}

RecruitDaily? _dailyOf(Object? raw) {
  final m = mapOf(raw);
  final day = m['day'];
  final count = m['count'];
  return day is String && count is num
      ? RecruitDaily(day: day, count: count.toInt())
      : null;
}

/// `photographers/{uid}/private/recruit`; a missing doc or field is zero.
RecruitCounters recruitCountersFrom(Map<String, dynamic>? d) {
  if (d == null) return RecruitCounters.empty;
  return RecruitCounters(
    openPostCount: intOf(d['openPostCount']),
    postActions: _dailyOf(d['postActions']),
    activeCollabCount: intOf(d['activeCollabCount']),
    pendingInviteCount: intOf(d['pendingInviteCount']),
    collabActions: _dailyOf(d['collabActions']),
    openApplicationCount: intOf(d['openApplicationCount']),
    applyActions: _dailyOf(d['applyActions']),
    recruitBlockedUntil: recruitDateOf(d['recruitBlockedUntil']),
  );
}

/// `users/{uid}.role` + `photographers/{uid}`; null without a photographer
/// document.
ProviderFacts? providerFactsFrom({
  required String? role,
  required Map<String, dynamic>? photographer,
}) {
  if (photographer == null) return null;
  return ProviderFacts(
    role: role,
    providerType: ProviderType.fromCode(photographer['providerType']),
    acceptingOrders: photographer['acceptingOrders'] == true,
    businessVerified: photographer['businessVerified'] == true,
    recruitMatchKeys: stringsOf(photographer['recruitMatchKeys']),
    studioId: nonEmptyOf(photographer['studioId']),
  );
}

/// Shared by the recruit and collaboration adapters: one callable, refusals
/// mapped to [RecruitError] (`details.code`, `details.field`).
Future<Object?> callRecruitFunction(
  FirebaseFunctions functions,
  String name,
  Map<String, Object?> data,
) async {
  try {
    final r = await functions
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        )
        .call<Object?>(data);
    return r.data;
  } on FirebaseFunctionsException catch (e) {
    throw recruitErrorOf(e);
  }
}

/// `recruitPosts` / `recruitApplications` reads plus the seven recruit
/// callables (Task 5).
class FirestoreRecruitRepository implements RecruitRepository {
  FirestoreRecruitRepository({
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

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('recruitPosts');
  CollectionReference<Map<String, dynamic>> get _applications =>
      _db.collection('recruitApplications');

  Future<Object?> _call(String name, Map<String, Object?> data) =>
      callRecruitFunction(_functions, name, data);

  List<RecruitPost> _postsOf(QuerySnapshot<Map<String, dynamic>> s) => [
    for (final d in s.docs) ?recruitPostFrom(d.id, d.data()),
  ];

  /// Index `status + filterKeys CONTAINS + createdAt desc` (any filter) or
  /// `studioId + status + createdAt desc` (one studio) or `status +
  /// createdAt desc`.
  @override
  Future<RecruitPage> list(
    RecruitFilter filter, {
    Object? after,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> q = _posts.where(
      'status',
      isEqualTo: RecruitPostStatus.open.code,
    );
    final studioId = filter.studioId;
    if (studioId != null) {
      q = q.where('studioId', isEqualTo: studioId);
    } else if (filter.key.isNotEmpty) {
      q = q.where('filterKeys', arrayContains: filter.key);
    }
    q = q.orderBy('createdAt', descending: true);
    if (after is DocumentSnapshot) q = q.startAfterDocument(after);
    final snap = await q.limit(limit).get();
    return RecruitPage(
      items: _postsOf(snap),
      next: snap.docs.length < limit ? null : snap.docs.last,
    );
  }

  @override
  Future<RecruitPost?> get(String postId) async {
    if (postId.isEmpty || postId.contains('/')) return null;
    final snap = await _posts.doc(postId).get();
    final d = snap.data();
    return d == null ? null : recruitPostFrom(snap.id, d);
  }

  @override
  Future<int> openCountOf(String studioId) async {
    final agg = await _posts
        .where('studioId', isEqualTo: studioId)
        .where('status', isEqualTo: RecruitPostStatus.open.code)
        .count()
        .get();
    return agg.count ?? 0;
  }

  @override
  Stream<List<RecruitPost>> watchStudioPosts(
    String studioId, {
    int limit = 10,
  }) => _posts
      .where('studioId', isEqualTo: studioId)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(_postsOf);

  /// Index `studioId + postId + status + createdAt desc`.
  @override
  Future<List<RecruitApplication>> applicantsOf(
    String studioId,
    String postId, {
    int limit = 30,
  }) async {
    final snap = await _applications
        .where('studioId', isEqualTo: studioId)
        .where('postId', isEqualTo: postId)
        .where('status', isEqualTo: ApplicationStatus.applied.code)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return [for (final d in snap.docs) ?recruitApplicationFrom(d.id, d.data())];
  }

  /// A query, not a document listener: the rules read `resource.data`, so a
  /// listener on a missing application would be refused. Equality filters
  /// only (no composite index).
  @override
  Stream<RecruitApplication?> watchMyApplication(String postId, String uid) =>
      _applications
          .where('applicantId', isEqualTo: uid)
          .where('postId', isEqualTo: postId)
          .limit(1)
          .snapshots()
          .map(
            (s) => s.docs.isEmpty
                ? null
                : recruitApplicationFrom(s.docs.first.id, s.docs.first.data()),
          );

  @override
  Stream<RecruitCounters> watchCounters(String uid) => _db
      .collection('photographers')
      .doc(uid)
      .collection('private')
      .doc('recruit')
      .snapshots()
      .map((s) => recruitCountersFrom(s.data()));

  /// `users/{uid}` and `photographers/{uid}` listened together; emits once
  /// both have answered, then on every change of either.
  @override
  Stream<ProviderFacts?> watchMyProviderFacts(String uid) {
    late StreamController<ProviderFacts?> out;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? photoSub;
    var userSeen = false;
    var photoSeen = false;
    String? role;
    Map<String, dynamic>? photographer;

    void emit() {
      if (userSeen && photoSeen) {
        out.add(providerFactsFrom(role: role, photographer: photographer));
      }
    }

    out = StreamController<ProviderFacts?>(
      onListen: () {
        userSub = _db.collection('users').doc(uid).snapshots().listen((s) {
          final r = s.data()?['role'];
          role = r is String ? r : null;
          userSeen = true;
          emit();
        }, onError: out.addError);
        photoSub = _db.collection('photographers').doc(uid).snapshots().listen((
          s,
        ) {
          photographer = s.data();
          photoSeen = true;
          emit();
        }, onError: out.addError);
      },
      onCancel: () async {
        await userSub?.cancel();
        await photoSub?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<String> create(RecruitDraft d) async {
    final id = mapOf(
      await _call('createRecruitPost', recruitDraftPayload(d)),
    )['postId'];
    if (id is! String) {
      throw const RecruitError(RecruitErrorCode.unknown);
    }
    return id;
  }

  @override
  Future<void> update(String postId, RecruitDraft d) =>
      _call('updateRecruitPost', recruitDraftPayload(d, postId: postId));

  @override
  Future<void> close(String postId) =>
      _call('closeRecruitPost', {'postId': postId});

  @override
  Future<DateTime> renew(String postId) async {
    final at = recruitDateOf(
      mapOf(await _call('renewRecruitPost', {'postId': postId}))['expiresAt'],
    );
    if (at == null) throw const RecruitError(RecruitErrorCode.unknown);
    return at;
  }

  @override
  Future<void> apply(
    String postId, {
    required String message,
    required List<String> samplePostIds,
    required bool acceptTerms,
  }) => _call('applyToRecruitPost', {
    'postId': postId,
    'message': message,
    'samplePostIds': samplePostIds,
    'acceptTerms': acceptTerms,
  });

  @override
  Future<void> withdraw(String postId) =>
      _call('withdrawRecruitApplication', {'postId': postId});

  @override
  Future<void> respond(
    String postId,
    String applicantId, {
    required bool accept,
  }) => _call('respondRecruitApplication', {
    'postId': postId,
    'applicantId': applicantId,
    'accept': accept,
  });
}
