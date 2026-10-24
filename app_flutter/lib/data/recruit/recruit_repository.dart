import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:photobooking/data/recruit/recruit_post.dart';

export 'package:photobooking/data/recruit/recruit_post.dart';

/// The editable fields of a post (S27.04). `kind` is fixed after creation:
/// `update` does not send it.
@immutable
class RecruitDraft {
  const RecruitDraft({
    required this.kind,
    required this.title,
    required this.specialties,
    required this.areas,
    required this.frequency,
    required this.fee,
    required this.requirements,
  });

  final RecruitKind kind;
  final String title;
  final List<String> specialties;
  final List<String> areas;
  final RecruitFrequency frequency;
  final FeeHint fee;
  final String requirements;

  @override
  bool operator ==(Object other) =>
      other is RecruitDraft &&
      other.kind == kind &&
      other.title == title &&
      listEquals(other.specialties, specialties) &&
      listEquals(other.areas, areas) &&
      other.frequency == frequency &&
      other.fee == fee &&
      other.requirements == requirements;

  @override
  int get hashCode => Object.hash(kind, title, frequency, fee, requirements);
}

/// One page of S27.01; [next] is the cursor of the following page (null on
/// the last one). Opaque to callers.
@immutable
class RecruitPage {
  const RecruitPage({required this.items, this.next});
  final List<RecruitPost> items;
  final Object? next;
}

/// Recruit posts and applications (S27.01–S27.05). Reads are direct (rules:
/// provider accounts read posts, the two parties read an application);
/// every write is a callable, refused with [RecruitError].
abstract class RecruitRepository {
  /// Open posts matching [filter], newest first, [limit] per page (`get`).
  Future<RecruitPage> list(
    RecruitFilter filter, {
    Object? after,
    int limit = 20,
  });

  Future<RecruitPost?> get(String postId);

  /// Open posts of a studio (count aggregation; S03.01 "Đang tuyển").
  Future<int> openCountOf(String studioId);

  /// The studio's posts of every status, newest first (S27.05).
  Stream<List<RecruitPost>> watchStudioPosts(String studioId, {int limit = 10});

  /// `applied` applications of one post, newest first (S27.05).
  Future<List<RecruitApplication>> applicantsOf(
    String studioId,
    String postId, {
    int limit = 30,
  });

  /// The caller's application to [postId], or null (S27.02).
  Stream<RecruitApplication?> watchMyApplication(String postId, String uid);

  /// `photographers/{uid}/private/recruit`; zeros when missing.
  Stream<RecruitCounters> watchCounters(String uid);

  /// Null when the account has no photographer document.
  Stream<ProviderFacts?> watchMyProviderFacts(String uid);

  /// Returns the new post id.
  Future<String> create(RecruitDraft d);
  Future<void> update(String postId, RecruitDraft d);
  Future<void> close(String postId);

  /// Returns the new expiry.
  Future<DateTime> renew(String postId);
  Future<void> apply(
    String postId, {
    required String message,
    required List<String> samplePostIds,
    required bool acceptTerms,
  });
  Future<void> withdraw(String postId);
  Future<void> respond(
    String postId,
    String applicantId, {
    required bool accept,
  });
}

/// The callable payload of a draft (shared by the adapter and the fake).
Map<String, Object?> recruitDraftPayload(RecruitDraft d, {String? postId}) => {
  'postId': ?postId,
  if (postId == null) 'kind': d.kind.code,
  'title': d.title,
  'specialties': d.specialties,
  'areas': d.areas,
  'frequency': d.frequency.code,
  'feeHint': switch (d.fee) {
    PerShootFee(:final amount) => {'type': 'per_shoot', 'amount': amount},
    NegotiableFee() => {'type': 'negotiable'},
  },
  'requirements': d.requirements,
};

/// In-memory [RecruitRepository] for tests, signed in as [uid]. Every write
/// is recorded in [calls] with the payload the Firestore adapter sends;
/// [failWith], while set, makes every write throw it. Writes change the
/// state the way the server would for the happy path (no limits or quotas
/// unless a test sets [failWith]).
class FakeRecruitRepository implements RecruitRepository {
  FakeRecruitRepository({this.uid = 'hoa', DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc());

  /// The signed-in caller (studio or applicant, depending on the test).
  String uid;
  final DateTime Function() _clock;

  final posts = <String, RecruitPost>{};
  final applications = <String, RecruitApplication>{};
  final counters = <String, RecruitCounters>{};
  final facts = <String, ProviderFacts?>{};

  /// `(callable name, payload)` of every write.
  final calls = <(String, Map<String, Object?>)>[];

  /// Every draft passed to `create` / `update`.
  final drafts = <RecruitDraft>[];

  /// The `filterKeys` value (or `studio:<id>`) of every `list` call.
  final listedKeys = <String>[];

  /// The `after` cursor of every `list` call (null = first page).
  final listedCursors = <Object?>[];

  /// The post id of every `get` call.
  final getCalls = <String>[];

  /// The studio id of every `openCountOf` call.
  final openCountCalls = <String>[];

  /// When set, every write throws it.
  RecruitError? failWith;

  /// When set, `list` and `get` throw it (a failed read).
  Object? readError;

  int _seq = 0;
  final _changes = StreamController<void>.broadcast();

  void _changed() => _changes.add(null);

  void seedPost(RecruitPost p) {
    posts[p.id] = p;
    _changed();
  }

  void seedApplication(RecruitApplication a) {
    applications[a.id] = a;
    _changed();
  }

  void setCounters(String uid, RecruitCounters c) {
    counters[uid] = c;
    _changed();
  }

  void setFacts(String uid, ProviderFacts? f) {
    facts[uid] = f;
    _changed();
  }

  Stream<T> _watch<T>(T Function() now) async* {
    yield now();
    yield* _changes.stream.map((_) => now());
  }

  void _record(String name, Map<String, Object?> payload) {
    final e = failWith;
    if (e != null) throw e;
    calls.add((name, payload));
  }

  bool _matches(RecruitPost p, RecruitFilter f) {
    if (f.studioId != null) return p.studioId == f.studioId;
    return (f.kind == null || p.kind == f.kind) &&
        (f.area == null || p.areas.contains(f.area)) &&
        (f.specialty == null || p.specialties.contains(f.specialty));
  }

  @override
  Future<RecruitPage> list(
    RecruitFilter filter, {
    Object? after,
    int limit = 20,
  }) async {
    final err = readError;
    if (err != null) throw err;
    listedKeys.add(
      filter.studioId != null ? 'studio:${filter.studioId}' : filter.key,
    );
    listedCursors.add(after);
    final all =
        posts.values
            .where((p) => p.status == RecruitPostStatus.open)
            .where((p) => _matches(p, filter))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final start = after is int ? after : 0;
    final items = all.skip(start).take(limit).toList();
    final end = start + items.length;
    return RecruitPage(items: items, next: end < all.length ? end : null);
  }

  @override
  Future<RecruitPost?> get(String postId) async {
    getCalls.add(postId);
    final err = readError;
    if (err != null) throw err;
    return posts[postId];
  }

  @override
  Future<int> openCountOf(String studioId) async {
    openCountCalls.add(studioId);
    return posts.values
        .where(
          (p) => p.studioId == studioId && p.status == RecruitPostStatus.open,
        )
        .length;
  }

  @override
  Stream<List<RecruitPost>> watchStudioPosts(
    String studioId, {
    int limit = 10,
  }) => _watch(
    () =>
        (posts.values.where((p) => p.studioId == studioId).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
            .take(limit)
            .toList(),
  );

  @override
  Future<List<RecruitApplication>> applicantsOf(
    String studioId,
    String postId, {
    int limit = 30,
  }) async =>
      (applications.values
              .where(
                (a) =>
                    a.studioId == studioId &&
                    a.postId == postId &&
                    a.status == ApplicationStatus.applied,
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
          .take(limit)
          .toList();

  @override
  Stream<RecruitApplication?> watchMyApplication(String postId, String uid) =>
      _watch(() => applications['${postId}_$uid']);

  @override
  Stream<RecruitCounters> watchCounters(String uid) =>
      _watch(() => counters[uid] ?? RecruitCounters.empty);

  @override
  Stream<ProviderFacts?> watchMyProviderFacts(String uid) =>
      _watch(() => facts[uid]);

  @override
  Future<String> create(RecruitDraft d) async {
    _record('createRecruitPost', recruitDraftPayload(d));
    drafts.add(d);
    final now = _clock();
    final id = 'post_${++_seq}';
    seedPost(
      RecruitPost(
        id: id,
        studioId: uid,
        studioName: '',
        studioAvatarUrl: null,
        studioBusinessVerified: false,
        kind: d.kind,
        title: d.title,
        specialties: d.specialties,
        areas: d.areas,
        frequency: d.frequency,
        fee: d.fee,
        requirements: d.requirements,
        status: RecruitPostStatus.open,
        renewed: false,
        applicationCount: 0,
        matchKeys: [
          for (final a in d.areas)
            for (final s in d.specialties) 'a=$a|s=$s',
        ],
        createdAt: now,
        expiresAt: now.add(const Duration(days: 30)),
      ),
    );
    return id;
  }

  RecruitPost _with(
    RecruitPost p, {
    RecruitDraft? d,
    RecruitPostStatus? status,
    bool? renewed,
    DateTime? expiresAt,
  }) => RecruitPost(
    id: p.id,
    studioId: p.studioId,
    studioName: p.studioName,
    studioAvatarUrl: p.studioAvatarUrl,
    studioBusinessVerified: p.studioBusinessVerified,
    kind: p.kind,
    title: d?.title ?? p.title,
    specialties: d?.specialties ?? p.specialties,
    areas: d?.areas ?? p.areas,
    frequency: d?.frequency ?? p.frequency,
    fee: d?.fee ?? p.fee,
    requirements: d?.requirements ?? p.requirements,
    status: status ?? p.status,
    renewed: renewed ?? p.renewed,
    applicationCount: p.applicationCount,
    matchKeys: p.matchKeys,
    createdAt: p.createdAt,
    expiresAt: expiresAt ?? p.expiresAt,
  );

  @override
  Future<void> update(String postId, RecruitDraft d) async {
    _record('updateRecruitPost', recruitDraftPayload(d, postId: postId));
    drafts.add(d);
    final p = posts[postId];
    if (p != null) seedPost(_with(p, d: d));
  }

  @override
  Future<void> close(String postId) async {
    _record('closeRecruitPost', {'postId': postId});
    final p = posts[postId];
    if (p != null) seedPost(_with(p, status: RecruitPostStatus.closed));
  }

  @override
  Future<DateTime> renew(String postId) async {
    _record('renewRecruitPost', {'postId': postId});
    final p = posts[postId];
    final expiresAt = (p?.expiresAt ?? _clock()).add(const Duration(days: 30));
    if (p != null) seedPost(_with(p, renewed: true, expiresAt: expiresAt));
    return expiresAt;
  }

  @override
  Future<void> apply(
    String postId, {
    required String message,
    required List<String> samplePostIds,
    required bool acceptTerms,
  }) async {
    _record('applyToRecruitPost', {
      'postId': postId,
      'message': message,
      'samplePostIds': samplePostIds,
      'acceptTerms': acceptTerms,
    });
    final p = posts[postId];
    final now = _clock();
    seedApplication(
      RecruitApplication(
        id: '${postId}_$uid',
        postId: postId,
        studioId: p?.studioId ?? '',
        applicantId: uid,
        kind: p?.kind ?? RecruitKind.collaborator,
        postTitle: p?.title ?? '',
        applicantName: '',
        applicantAvatarUrl: null,
        status: ApplicationStatus.applied,
        message: message,
        samplePostIds: samplePostIds,
        createdAt: now,
        expiresAt: now.add(const Duration(days: 7)),
        respondedAt: null,
      ),
    );
  }

  void _setApplication(String id, ApplicationStatus status, {DateTime? at}) {
    final a = applications[id];
    if (a != null) seedApplication(a.copyWith(status: status, respondedAt: at));
  }

  @override
  Future<void> withdraw(String postId) async {
    _record('withdrawRecruitApplication', {'postId': postId});
    _setApplication('${postId}_$uid', ApplicationStatus.withdrawn);
  }

  @override
  Future<void> respond(
    String postId,
    String applicantId, {
    required bool accept,
  }) async {
    _record('respondRecruitApplication', {
      'postId': postId,
      'applicantId': applicantId,
      'accept': accept,
    });
    _setApplication(
      '${postId}_$applicantId',
      accept ? ApplicationStatus.accepted : ApplicationStatus.declined,
      at: _clock(),
    );
  }
}
