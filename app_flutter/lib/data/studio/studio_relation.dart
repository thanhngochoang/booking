import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:photobooking/core/core.dart';

/// Status of a `studio_members/{id}` relation (#136 Contract). `invited`,
/// `requested` and `active` are open; the others are history.
enum RelationStatus {
  invited,
  requested,
  active,
  declined,
  cancelled,
  expired,
  left,
  removed;

  bool get isOpen => this == invited || this == requested || this == active;

  static RelationStatus? fromCode(Object? c) {
    for (final s in values) {
      if (s.name == c) return s;
    }
    return null;
  }
}

/// Who started the relation: the studio invites, a photographer requests.
enum RelationInitiator { studio, member }

/// A studio ↔ member relation, readable by those two parties only. Names and
/// avatars are snapshots taken when it was created.
@immutable
class StudioRelation {
  const StudioRelation({
    required this.id,
    required this.studioId,
    required this.memberId,
    required this.status,
    this.initiatedBy = RelationInitiator.studio,
    required this.createdAt,
    required this.expiresAt,
    this.joinedAt,
    this.studioName = '',
    this.studioAvatarUrl,
    this.memberName = '',
    this.memberAvatarUrl,
  });

  final String id;
  final String studioId;
  final String memberId;
  final RelationStatus status;
  final RelationInitiator initiatedBy;
  final DateTime createdAt;

  /// When an open invite or request lapses (created + 7 days).
  final DateTime expiresAt;
  final DateTime? joinedAt;

  /// '' when the user had no display name.
  final String studioName;
  final String? studioAvatarUrl;
  final String memberName;
  final String? memberAvatarUrl;

  bool get isOpen => status.isOpen;

  StudioRelation copyWith({RelationStatus? status, DateTime? joinedAt}) =>
      StudioRelation(
        id: id,
        studioId: studioId,
        memberId: memberId,
        status: status ?? this.status,
        initiatedBy: initiatedBy,
        createdAt: createdAt,
        expiresAt: expiresAt,
        joinedAt: joinedAt ?? this.joinedAt,
        studioName: studioName,
        studioAvatarUrl: studioAvatarUrl,
        memberName: memberName,
        memberAvatarUrl: memberAvatarUrl,
      );

  @override
  bool operator ==(Object other) =>
      other is StudioRelation &&
      other.id == id &&
      other.studioId == studioId &&
      other.memberId == memberId &&
      other.status == status &&
      other.initiatedBy == initiatedBy &&
      other.createdAt == createdAt &&
      other.expiresAt == expiresAt &&
      other.joinedAt == joinedAt &&
      other.studioName == studioName &&
      other.studioAvatarUrl == studioAvatarUrl &&
      other.memberName == memberName &&
      other.memberAvatarUrl == memberAvatarUrl;

  @override
  int get hashCode => Object.hash(
    id,
    studioId,
    memberId,
    status,
    initiatedBy,
    createdAt,
    expiresAt,
    joinedAt,
    studioName,
    studioAvatarUrl,
    memberName,
    memberAvatarUrl,
  );
}

/// Membership actions left today for one side (`studio_quota/{uid}`).
@immutable
class StudioQuota {
  const StudioQuota({required this.left, required this.max});

  final int left;
  final int max;

  bool get exhausted => left <= 0;

  @override
  bool operator ==(Object other) =>
      other is StudioQuota && other.left == left && other.max == max;

  @override
  int get hashCode => Object.hash(left, max);

  @override
  String toString() => 'StudioQuota($left/$max)';
}

/// Daily membership actions (Decision 4): a studio invites, cancels invites,
/// approves and removes; a member requests, cancels requests and leaves.
const kStudioDailyActions = 5;
const kMemberDailyActions = 3;

/// Most members of a studio without and with a business record, counting
/// open invites (Decision 3).
const kStudioMaxMembers = 3;
const kStudioMaxMembersVerified = 30;

/// Most open invites of one studio (Decision 3).
const kStudioMaxPendingInvites = 5;

int studioMaxMembers({required bool businessVerified}) =>
    businessVerified ? kStudioMaxMembersVerified : kStudioMaxMembers;

/// Counts over a studio's open relations (S26.01, S26.02, S09.02).
extension StudioRelationCounts on Iterable<StudioRelation> {
  /// Members in the studio now.
  int get activeCount => where((r) => r.status == RelationStatus.active).length;

  /// Invites the studio sent that are still waiting.
  int get openInvites =>
      where((r) => r.status == RelationStatus.invited).length;

  /// Members plus open invites have reached [max]: no invite or approval
  /// fits (the server answers `studio_full`).
  bool atCap(int max) => activeCount + openInvites >= max;
}

/// Where a photographer found by the invite search stands for this studio.
enum InviteState {
  invitable('invitable'),
  inStudio('in_studio'),
  cooldown('cooldown'),
  invited('invited'),
  member('member');

  const InviteState(this.code);
  final String code;

  static InviteState? fromCode(Object? c) {
    for (final s in values) {
      if (s.code == c) return s;
    }
    return null;
  }
}

/// One row of `searchPhotographersToInvite` (S26.02).
@immutable
class InviteCandidate {
  const InviteCandidate({
    required this.uid,
    this.name = '',
    this.avatarUrl,
    this.verified = false,
    this.tomatoPct,
    this.areaLabel,
    required this.state,
    this.studioName,
    this.availableFrom,
  });

  final String uid;
  final String name;
  final String? avatarUrl;
  final bool verified;
  final int? tomatoPct;
  final String? areaLabel;
  final InviteState state;

  /// [InviteState.inStudio]: the other studio's name.
  final String? studioName;

  /// [InviteState.cooldown]: when an invite works again.
  final DateTime? availableFrom;
}

/// How a member stands for one booking's day in S26.04.
enum AssignState { free, busy, off, unverified, current }

/// One row of `assignmentOptions` (S26.04).
@immutable
class AssignmentOption {
  const AssignmentOption({
    required this.uid,
    this.name = '',
    this.avatarUrl,
    this.tomatoPct,
    this.reviewCount = 0,
    required this.state,
    this.busyStart,
    this.busyEnd,
  });

  final String uid;
  final String name;
  final String? avatarUrl;
  final int? tomatoPct;
  final int reviewCount;
  final AssignState state;

  /// `HH:mm` of the booking that keeps the member busy; null for an all-day
  /// block.
  final String? busyStart;
  final String? busyEnd;

  /// Only a free member can be picked; the current assignee is shown, not
  /// picked again.
  bool get selectable => state == AssignState.free;
}

DateTime? _date(Object? v) {
  if (v is Timestamp) return v.toDate().toUtc();
  if (v is DateTime) return v.toUtc();
  if (v is String) return DateTime.tryParse(v)?.toUtc();
  return null;
}

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
int? _int(Object? v) => v is num ? v.toInt() : null;

/// `studio_members/{id}` → [StudioRelation]; null for a document the app
/// cannot use (unknown status, missing party or dates).
StudioRelation? studioRelationFrom(String id, Map<String, dynamic> d) {
  final status = RelationStatus.fromCode(d['status']);
  final studioId = _str(d['studioId']);
  final memberId = _str(d['memberId']);
  final createdAt = _date(d['createdAt']);
  final expiresAt = _date(d['expiresAt']);
  if (status == null ||
      studioId == null ||
      memberId == null ||
      createdAt == null ||
      expiresAt == null) {
    return null;
  }
  return StudioRelation(
    id: id,
    studioId: studioId,
    memberId: memberId,
    status: status,
    initiatedBy: d['initiatedBy'] == 'member'
        ? RelationInitiator.member
        : RelationInitiator.studio,
    createdAt: createdAt,
    expiresAt: expiresAt,
    joinedAt: _date(d['joinedAt']),
    studioName: d['studioName'] is String ? d['studioName'] as String : '',
    studioAvatarUrl: _str(d['studioAvatarUrl']),
    memberName: d['memberName'] is String ? d['memberName'] as String : '',
    memberAvatarUrl: _str(d['memberAvatarUrl']),
  );
}

/// `studio_quota/{uid}` → actions left on the Vietnam day of [now] for one
/// side; a count kept for another day no longer applies (server `quotaLeft`).
StudioQuota studioQuotaFrom(
  Map<String, dynamic>? d, {
  required bool studio,
  required DateTime now,
}) {
  final max = studio ? kStudioDailyActions : kMemberDailyActions;
  if (d == null || d['dayKey'] != vnDateKey(now)) {
    return StudioQuota(left: max, max: max);
  }
  final used = _int(d[studio ? 'studioActions' : 'memberActions']) ?? 0;
  final left = max - used;
  return StudioQuota(left: left < 0 ? 0 : left, max: max);
}

InviteCandidate? inviteCandidateFrom(Map<String, dynamic> d) {
  final uid = _str(d['uid']);
  final state = InviteState.fromCode(d['state']);
  if (uid == null || state == null) return null;
  return InviteCandidate(
    uid: uid,
    name: d['name'] is String ? d['name'] as String : '',
    avatarUrl: _str(d['avatarUrl']),
    verified: d['verified'] == true,
    tomatoPct: _int(d['tomatoPct']),
    areaLabel: _str(d['areaLabel']),
    state: state,
    studioName: _str(d['studioName']),
    availableFrom: _date(d['availableFrom']),
  );
}

AssignmentOption? assignmentOptionFrom(Map<String, dynamic> d) {
  final uid = _str(d['uid']);
  final state = AssignState.values
      .where((s) => s.name == d['state'])
      .firstOrNull;
  if (uid == null || state == null) return null;
  return AssignmentOption(
    uid: uid,
    name: d['name'] is String ? d['name'] as String : '',
    avatarUrl: _str(d['avatarUrl']),
    tomatoPct: _int(d['tomatoPct']),
    reviewCount: _int(d['reviewCount']) ?? 0,
    state: state,
    busyStart: _str(d['busyStart']),
    busyEnd: _str(d['busyEnd']),
  );
}
