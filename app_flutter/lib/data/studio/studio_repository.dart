import 'package:photobooking/data/studio/studio_relation.dart';

export 'package:photobooking/data/studio/studio_relation.dart';

/// A refused studio call; [code] is the server's (`membership_conflict`,
/// `cooldown`, `member_busy`, `studio_full`, `rate_limited`, `conflict`,
/// `deadline_passed`, `day_taken`, `not_accepting_orders`, ...) or the
/// transport's (`unavailable`, ...).
class StudioError implements Exception {
  const StudioError(this.code);
  final String code;

  @override
  String toString() => 'StudioError($code)';
}

/// Studio membership (S26.01–S26.03) and the assignment list of S26.04.
/// Relations are read by their two parties only; every change goes through
/// a callable. Booking-side studio actions live on `BookingRepository`.
abstract class StudioRepository {
  /// The studio's open relations (invited, requested, active), newest first.
  Stream<List<StudioRelation>> watchStudioRelations(String studioId);

  /// The photographer's open relations (invited, requested, active), newest
  /// first.
  Stream<List<StudioRelation>> watchMemberRelations(String memberId);

  /// Actions [uid] has left today, as a studio or as a member.
  Stream<StudioQuota> watchQuota(String uid, {required bool studio});

  /// Invites a photographer; returns the relation id.
  Future<String> invite(String memberId);
  Future<void> cancelInvite(String relationId);

  /// Asks to join a studio; returns the relation id.
  Future<String> requestToJoin(String studioId);
  Future<void> cancelJoinRequest(String relationId);
  Future<void> respondInvite(String relationId, {required bool accept});
  Future<void> respondJoinRequest(String relationId, {required bool accept});
  Future<void> leave();
  Future<void> remove(String memberId);

  /// Photographers whose name starts with [query] (2+ characters), each
  /// with its state for the calling studio; at most 20.
  Future<List<InviteCandidate>> search(String query);

  /// The members the studio can pick for [bookingId] and its deadline.
  Future<({DateTime deadline, List<AssignmentOption> options})>
  assignmentOptions(String bookingId);
}
