import 'dart:async';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/collab/collaboration.dart';
import 'package:photobooking/data/recruit/recruit_post.dart';

export 'package:photobooking/data/collab/collaboration.dart';

/// The instants (UTC) where Vietnam month [month] of [year] starts and the
/// next one starts.
(DateTime, DateTime) vnMonthRange(int year, int month) => (
  fromVnWallClock(DateTime.utc(year, month)),
  fromVnWallClock(DateTime.utc(year, month + 1)),
);

/// Collaborations and per-job offers (S27.06–S27.07). Reads are direct
/// (rules: the two parties); every write is a callable, refused with
/// [RecruitError].
abstract class CollabRepository {
  /// The studio's invited and active collaborations, newest first (≤ 60).
  Stream<List<Collaboration>> watchAsStudio(String studioId);

  /// The photographer's invited and active collaborations, newest first
  /// (≤ 20).
  Stream<List<Collaboration>> watchAsCollaborator(String uid);

  /// The studio's jobs, last changed first.
  Stream<List<CollabJob>> watchJobsAsStudio(String studioId, {int limit = 50});

  /// The collaborator's jobs, last changed first.
  Stream<List<CollabJob>> watchJobsAsCollaborator(String uid, {int limit = 50});

  /// The latest relationship of studio [studioId] with each of
  /// [collaboratorIds], whatever its status (S26.02-collab reads the
  /// 3-day cooldown of an ended one); missing pairs are left out.
  Future<List<Collaboration>> pairsOf(
    String studioId,
    List<String> collaboratorIds,
  );

  /// Jobs whose pay fell due in Vietnam month [month] of [year] (CSV export).
  Future<List<CollabJob>> jobsDueInMonth(String studioId, int year, int month);

  Future<void> invite(String collaboratorId, {int? defaultFee});
  Future<void> cancelInvite(String collaboratorId);
  Future<void> respondInvite(
    String studioId, {
    required bool accept,
    required bool acceptTerms,
  });

  /// The collaborator passes [studioId]; the studio passes [collaboratorId].
  Future<void> end({String? studioId, String? collaboratorId});

  /// [fee] null clears the suggestion.
  Future<void> setDefaultFee(String collaboratorId, int? fee);
  Future<OfferStatus> respondOffer(String bookingId, {required bool accept});

  /// [paidOn] is the Vietnam calendar date the studio paid (a date-picker
  /// value; its fields are used as is).
  Future<void> reportPaid(
    String bookingId,
    String collaboratorId, {
    required DateTime paidOn,
    required CollabPayMethod method,
  });
  Future<void> confirmPay(String bookingId, {required bool received});

  /// Returns the chat id (`collab_{studioId}_{collaboratorId}`).
  Future<String> openChat({String? studioId, String? collaboratorId});
}

/// `{studioId}` or `{collaboratorId}`, whichever is given.
Map<String, Object?> collabPartyPayload({
  String? studioId,
  String? collaboratorId,
}) => {'studioId': ?studioId, 'collaboratorId': ?collaboratorId};

/// In-memory [CollabRepository] for tests, signed in as [uid]. Every write
/// is recorded in [calls] with the payload the Firestore adapter sends;
/// [failWith], while set, makes every write throw it. Writes change the
/// state the way the server would for the happy path.
class FakeCollabRepository implements CollabRepository {
  FakeCollabRepository({this.uid = 'cuc', DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc());

  /// The signed-in caller (studio or collaborator, depending on the test).
  String uid;
  final DateTime Function() _clock;

  final collaborations = <String, Collaboration>{};
  final jobs = <String, CollabJob>{};

  /// `(callable name, payload)` of every write.
  final calls = <(String, Map<String, Object?>)>[];

  /// When set, every write throws it.
  RecruitError? failWith;

  final _changes = StreamController<void>.broadcast();

  void seedCollaboration(Collaboration c) {
    collaborations[c.id] = c;
    _changes.add(null);
  }

  void seedJob(CollabJob j) {
    jobs[j.id] = j;
    _changes.add(null);
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

  static const _open = {CollabStatus.invited, CollabStatus.active};

  List<Collaboration> _collabs(bool Function(Collaboration) where, int max) =>
      (collaborations.values
              .where((c) => _open.contains(c.status) && where(c))
              .toList()
            ..sort(
              (a, b) => (b.activeAt ?? b.expiresAt).compareTo(
                a.activeAt ?? a.expiresAt,
              ),
            ))
          .take(max)
          .toList();

  List<CollabJob> _jobs(bool Function(CollabJob) where, int limit) =>
      (jobs.values.where(where).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
          .take(limit)
          .toList();

  @override
  Stream<List<Collaboration>> watchAsStudio(String studioId) =>
      _watch(() => _collabs((c) => c.studioId == studioId, 60));

  @override
  Stream<List<Collaboration>> watchAsCollaborator(String uid) =>
      _watch(() => _collabs((c) => c.collaboratorId == uid, 20));

  @override
  Stream<List<CollabJob>> watchJobsAsStudio(
    String studioId, {
    int limit = 50,
  }) => _watch(() => _jobs((j) => j.studioId == studioId, limit));

  @override
  Stream<List<CollabJob>> watchJobsAsCollaborator(
    String uid, {
    int limit = 50,
  }) => _watch(() => _jobs((j) => j.collaboratorId == uid, limit));

  @override
  Future<List<Collaboration>> pairsOf(
    String studioId,
    List<String> collaboratorIds,
  ) async => [
    for (final c in collaborations.values)
      if (c.studioId == studioId && collaboratorIds.contains(c.collaboratorId))
        c,
  ];

  @override
  Future<List<CollabJob>> jobsDueInMonth(
    String studioId,
    int year,
    int month,
  ) async {
    final (from, to) = vnMonthRange(year, month);
    final list = jobs.values.where((j) {
      final due = j.payDueAt;
      return j.studioId == studioId &&
          due != null &&
          !due.isBefore(from) &&
          due.isBefore(to);
    }).toList()..sort((a, b) => a.payDueAt!.compareTo(b.payDueAt!));
    return list;
  }

  void _setCollab(String id, CollabStatus status) {
    final c = collaborations[id];
    if (c == null) return;
    seedCollaboration(
      c.copyWith(
        status: status,
        activeAt: status == CollabStatus.active ? _clock() : null,
        endedAt: status == CollabStatus.ended ? _clock() : null,
      ),
    );
  }

  @override
  Future<void> invite(String collaboratorId, {int? defaultFee}) async {
    _record('inviteCollaborator', {
      'collaboratorId': collaboratorId,
      'defaultFee': ?defaultFee,
    });
    final now = _clock();
    seedCollaboration(
      Collaboration(
        id: '${uid}_$collaboratorId',
        studioId: uid,
        collaboratorId: collaboratorId,
        studioName: '',
        studioAvatarUrl: null,
        collaboratorName: '',
        collaboratorAvatarUrl: null,
        status: CollabStatus.invited,
        defaultFee: defaultFee,
        activeAt: null,
        expiresAt: now.add(const Duration(days: 7)),
        endedAt: null,
      ),
    );
  }

  @override
  Future<void> cancelInvite(String collaboratorId) async {
    _record('cancelCollabInvite', {'collaboratorId': collaboratorId});
    _setCollab('${uid}_$collaboratorId', CollabStatus.cancelled);
  }

  @override
  Future<void> respondInvite(
    String studioId, {
    required bool accept,
    required bool acceptTerms,
  }) async {
    _record('respondCollabInvite', {
      'studioId': studioId,
      'accept': accept,
      'acceptTerms': acceptTerms,
    });
    _setCollab(
      '${studioId}_$uid',
      accept ? CollabStatus.active : CollabStatus.declined,
    );
  }

  @override
  Future<void> end({String? studioId, String? collaboratorId}) async {
    _record(
      'endCollaboration',
      collabPartyPayload(studioId: studioId, collaboratorId: collaboratorId),
    );
    _setCollab(
      studioId != null ? '${studioId}_$uid' : '${uid}_$collaboratorId',
      CollabStatus.ended,
    );
  }

  @override
  Future<void> setDefaultFee(String collaboratorId, int? fee) async {
    _record('setCollabDefaultFee', {
      'collaboratorId': collaboratorId,
      'defaultFee': fee,
    });
    final c = collaborations['${uid}_$collaboratorId'];
    if (c != null) seedCollaboration(c.copyWith(defaultFee: () => fee));
  }

  void _patchJob(String id, CollabJob Function(CollabJob) patch) {
    final j = jobs[id];
    if (j != null) seedJob(patch(j));
  }

  @override
  Future<OfferStatus> respondOffer(
    String bookingId, {
    required bool accept,
  }) async {
    _record('respondCollabOffer', {'bookingId': bookingId, 'accept': accept});
    final status = accept ? OfferStatus.accepted : OfferStatus.declined;
    _patchJob(
      '${bookingId}_$uid',
      (j) => j.copyWith(
        offerStatus: status,
        acceptedAt: accept ? _clock() : null,
        updatedAt: _clock(),
      ),
    );
    return status;
  }

  @override
  Future<void> reportPaid(
    String bookingId,
    String collaboratorId, {
    required DateTime paidOn,
    required CollabPayMethod method,
  }) async {
    final day = dayKeyOf(paidOn);
    _record('reportCollabPaid', {
      'bookingId': bookingId,
      'collaboratorId': collaboratorId,
      'paidOn': day,
      'method': method.code,
    });
    _patchJob(
      '${bookingId}_$collaboratorId',
      (j) => j.copyWith(
        payStatus: PayStatus.paidReported,
        paidOn: day,
        payMethod: method,
        reportedAt: _clock(),
        updatedAt: _clock(),
      ),
    );
  }

  @override
  Future<void> confirmPay(String bookingId, {required bool received}) async {
    _record('confirmCollabPay', {'bookingId': bookingId, 'received': received});
    _patchJob(
      '${bookingId}_$uid',
      (j) => j.copyWith(
        payStatus: received ? PayStatus.received : PayStatus.disputed,
        updatedAt: _clock(),
      ),
    );
  }

  @override
  Future<String> openChat({String? studioId, String? collaboratorId}) async {
    _record(
      'openCollabChat',
      collabPartyPayload(studioId: studioId, collaboratorId: collaboratorId),
    );
    return studioId != null
        ? 'collab_${studioId}_$uid'
        : 'collab_${uid}_$collaboratorId';
  }
}
