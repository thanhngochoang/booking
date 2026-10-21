// test/support/studio_world.dart
import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_providers.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/content/fake_content_repositories.dart';
import 'package:photobooking/data/content/photographer_summary.dart';
import 'package:photobooking/data/content/provider_type.dart';
import 'package:photobooking/data/studio/studio_providers.dart';
import 'package:photobooking/data/studio/studio_repository.dart';

import 'booking_fixtures.dart';
import 'fake_booking_repository.dart';

/// Tuesday 21/10/2026 10:00 in Vietnam.
final studioNow = DateTime.utc(2026, 10, 21, 3);

/// A relation of studio [studioId] ("Studio Cúc") with [memberId] ("An").
StudioRelation makeRelation({
  String id = 'r1',
  String studioId = 'cuc',
  String memberId = 'an',
  RelationStatus status = RelationStatus.active,
  RelationInitiator initiatedBy = RelationInitiator.studio,
  DateTime? createdAt,
  DateTime? joinedAt,
  String studioName = 'Studio Cúc',
  String memberName = 'An',
}) {
  final created = createdAt ?? studioNow.subtract(const Duration(days: 2));
  return StudioRelation(
    id: id,
    studioId: studioId,
    memberId: memberId,
    status: status,
    initiatedBy: initiatedBy,
    createdAt: created,
    expiresAt: created.add(const Duration(days: 7)),
    joinedAt: joinedAt ?? (status == RelationStatus.active ? created : null),
    studioName: studioName,
    memberName: memberName,
  );
}

/// A studio booking of `cuc` for customer `c1` on 24/10 15:00–17:00,
/// assigned to [assigneeId] when given; [studio] replaces the whole part.
Booking makeStudioBooking({
  String id = 'sb1',
  String photographerId = 'cuc',
  BookingStatus status = BookingStatus.accepted,
  String? assigneeId,
  StudioBookingInfo? studio,
}) => makeTestBooking(
  id: id,
  photographerId: photographerId,
  day: '2026-10-24',
  start: '15:00',
  end: '17:00',
  status: status,
).copyWith(
  studio:
      studio ??
      StudioBookingInfo(
        assigneeId: assigneeId,
        assigneeKind: assigneeId == null ? null : 'member',
        assignStatus: assigneeId == null
            ? StudioAssignStatus.unassigned
            : StudioAssignStatus.assigned,
        // 24 h before the start.
        assignDeadline: DateTime.utc(2026, 10, 23, 8),
        assignedAt: assigneeId == null ? null : studioNow,
      ),
);

/// A studio's public summary: [memberCount] members, all assignable.
PhotographerSummary makeStudioSummary({
  String id = 'cuc',
  String name = 'Studio Cúc',
  int memberCount = 3,
  int? assignableMembers,
}) => PhotographerSummary(
  id: id,
  displayName: name,
  verified: true,
  businessVerified: true,
  acceptingOrders: true,
  providerType: ProviderType.studio,
  memberCount: memberCount,
  assignableMembers: assignableMembers ?? memberCount,
);

/// In-memory [StudioRepository]: relations by id, quotas by uid, canned
/// search rows and assignment options. Every call is recorded in [calls]
/// with the payload the Firestore adapter sends; [nextError] makes the next
/// call throw `StudioError(nextError)`. Membership calls change [relations]
/// the way the server would (status only; caps and quotas are the server's).
class FakeStudioRepository implements StudioRepository {
  FakeStudioRepository({this.uid = 'cuc', DateTime Function()? clock})
    : _clock = clock ?? (() => studioNow);

  /// The signed-in caller (studio or member, depending on the test).
  String uid;
  final DateTime Function() _clock;

  final relations = <String, StudioRelation>{};
  final quotas = <String, StudioQuota>{};
  List<InviteCandidate> searchRows = const [];
  DateTime assignDeadline = DateTime.utc(2026, 10, 23, 8);
  List<AssignmentOption> options = const [];
  final calls = <(String, Map<String, Object?>)>[];
  String? nextError;
  int _seq = 0;

  final _changes = StreamController<void>.broadcast();

  void seedRelation(StudioRelation r) {
    relations[r.id] = r;
    _changes.add(null);
  }

  void setQuota(String uid, StudioQuota q) {
    quotas[uid] = q;
    _changes.add(null);
  }

  Future<void> _record(String name, Map<String, Object?> payload) async {
    final err = nextError;
    if (err != null) {
      nextError = null;
      throw StudioError(err);
    }
    calls.add((name, payload));
  }

  void _set(String id, RelationStatus status) {
    final r = relations[id];
    if (r == null) return;
    relations[id] = r.copyWith(
      status: status,
      joinedAt: status == RelationStatus.active ? _clock() : null,
    );
    _changes.add(null);
  }

  Stream<List<StudioRelation>> _watch(bool Function(StudioRelation) where) {
    List<StudioRelation> list() =>
        relations.values.where((r) => r.isOpen && where(r)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (() async* {
      yield list();
      yield* _changes.stream.map((_) => list());
    })();
  }

  @override
  Stream<List<StudioRelation>> watchStudioRelations(String studioId) =>
      _watch((r) => r.studioId == studioId);

  @override
  Stream<List<StudioRelation>> watchMemberRelations(String memberId) =>
      _watch((r) => r.memberId == memberId);

  @override
  Stream<StudioQuota> watchQuota(String uid, {required bool studio}) {
    final max = studio ? kStudioDailyActions : kMemberDailyActions;
    StudioQuota now() => quotas[uid] ?? StudioQuota(left: max, max: max);
    return (() async* {
      yield now();
      yield* _changes.stream.map((_) => now());
    })();
  }

  StudioRelation _new(String studioId, String memberId, RelationStatus s) {
    final r = makeRelation(
      id: 'rel_${++_seq}',
      studioId: studioId,
      memberId: memberId,
      status: s,
      initiatedBy: s == RelationStatus.requested
          ? RelationInitiator.member
          : RelationInitiator.studio,
      createdAt: _clock(),
    );
    seedRelation(r);
    return r;
  }

  @override
  Future<String> invite(String memberId) async {
    await _record('inviteMember', {'memberId': memberId});
    return _new(uid, memberId, RelationStatus.invited).id;
  }

  @override
  Future<void> cancelInvite(String relationId) async {
    await _record('cancelInvite', {'relationId': relationId});
    _set(relationId, RelationStatus.cancelled);
  }

  @override
  Future<String> requestToJoin(String studioId) async {
    await _record('requestToJoin', {'studioId': studioId});
    return _new(studioId, uid, RelationStatus.requested).id;
  }

  @override
  Future<void> cancelJoinRequest(String relationId) async {
    await _record('cancelJoinRequest', {'relationId': relationId});
    _set(relationId, RelationStatus.cancelled);
  }

  @override
  Future<void> respondInvite(String relationId, {required bool accept}) async {
    await _record('respondInvite', {'relationId': relationId, 'accept': accept});
    _set(relationId, accept ? RelationStatus.active : RelationStatus.declined);
  }

  @override
  Future<void> respondJoinRequest(
    String relationId, {
    required bool accept,
  }) async {
    await _record('respondJoinRequest', {
      'relationId': relationId,
      'accept': accept,
    });
    _set(relationId, accept ? RelationStatus.active : RelationStatus.declined);
  }

  @override
  Future<void> leave() async {
    await _record('leaveStudio', {});
    for (final r in relations.values.toList()) {
      if (r.memberId == uid && r.status == RelationStatus.active) {
        _set(r.id, RelationStatus.left);
      }
    }
  }

  @override
  Future<void> remove(String memberId) async {
    await _record('removeMember', {'memberId': memberId});
    for (final r in relations.values.toList()) {
      if (r.studioId == uid &&
          r.memberId == memberId &&
          r.status == RelationStatus.active) {
        _set(r.id, RelationStatus.removed);
      }
    }
  }

  @override
  Future<List<InviteCandidate>> search(String query) async {
    await _record('searchPhotographersToInvite', {'query': query});
    return searchRows;
  }

  @override
  Future<({DateTime deadline, List<AssignmentOption> options})>
  assignmentOptions(String bookingId) async {
    await _record('assignmentOptions', {'bookingId': bookingId});
    return (deadline: assignDeadline, options: options);
  }
}

/// Fakes for a studio screen: [studios] (relations, quota, search,
/// assignment options), [bookings] and [photographers] (public summaries,
/// `membersOf`), signed in as [uid] at [studioNow].
class StudioWorld {
  StudioWorld({String uid = 'cuc', DateTime? now})
    : this._(uid, now ?? studioNow);

  StudioWorld._(this.uid, this.now)
    : studios = FakeStudioRepository(uid: uid, clock: () => now),
      bookings = FakeBookingRepository(customerId: 'c1', clock: () => now),
      photographers = FakePhotographerRepository();

  final String uid;
  final DateTime now;
  final FakeStudioRepository studios;
  final FakeBookingRepository bookings;
  final FakePhotographerRepository photographers;

  List<Override> get overrides => [
    authStateProvider.overrideWith((ref) => Stream.value(AuthUser(uid: uid))),
    clockProvider.overrideWithValue(() => now),
    studioRepositoryProvider.overrideWithValue(studios),
    bookingRepositoryProvider.overrideWithValue(bookings),
    photographerRepositoryProvider.overrideWithValue(photographers),
  ];
}
