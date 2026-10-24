import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/content/provider_type.dart';

// S27 studio recruiting (#151): recruit posts, applications, the server-only
// counters and the refusal codes the recruit and collaboration callables
// answer with. Firestore parsing lives in `firestore_recruit_repository.dart`.

/// Studio post actions per Vietnam day (create + close), server
/// `STUDIO_POST_DAILY_ACTIONS`.
const kRecruitPostDailyActions = 5;

/// Studio collaboration actions per Vietnam day (invite, cancel invite,
/// accept or decline an application, end), server
/// `STUDIO_COLLAB_DAILY_ACTIONS`.
const kRecruitCollabDailyActions = 10;

/// Applications per Vietnam day, server `APPLY_DAILY`.
const kRecruitApplyDaily = 3;

/// Open posts a studio may have, server `MAX_OPEN_POSTS`.
const kRecruitMaxOpenPosts = 3;

/// Open applications a photographer may have, server
/// `MAX_OPEN_APPLICATIONS`.
const kRecruitMaxOpenApplications = 10;

/// A collaborator works per job; a member joins the studio (S26). Never an
/// employee kind (R4).
enum RecruitKind {
  collaborator('collaborator'),
  member('member');

  const RecruitKind(this.code);
  final String code;

  /// Unknown → null: the row is dropped.
  static RecruitKind? fromCode(Object? raw) {
    for (final k in values) {
      if (k.code == raw) return k;
    }
    return null;
  }
}

enum RecruitFrequency {
  occasional('occasional'),
  weekly('weekly'),
  seasonal('seasonal');

  const RecruitFrequency(this.code);
  final String code;

  /// Unknown → occasional, like the server mapping.
  static RecruitFrequency fromCode(Object? raw) {
    for (final f in values) {
      if (f.code == raw) return f;
    }
    return occasional;
  }
}

enum RecruitPostStatus {
  open('open'),
  closed('closed'),
  expired('expired');

  const RecruitPostStatus(this.code);
  final String code;

  /// Unknown → null: the row is dropped.
  static RecruitPostStatus? fromCode(Object? raw) {
    for (final s in values) {
      if (s.code == raw) return s;
    }
    return null;
  }
}

enum ApplicationStatus {
  applied('applied'),
  accepted('accepted'),
  declined('declined'),
  withdrawn('withdrawn'),
  expired('expired');

  const ApplicationStatus(this.code);
  final String code;

  /// Unknown → null: the row is dropped.
  static ApplicationStatus? fromCode(Object? raw) {
    for (final s in values) {
      if (s.code == raw) return s;
    }
    return null;
  }
}

/// The fee a post suggests: an amount per shoot, or "Thoả thuận".
sealed class FeeHint {
  const FeeHint();
}

/// Integer VND per shoot (1.000–100.000.000, steps of 1.000).
@immutable
final class PerShootFee extends FeeHint {
  const PerShootFee(this.amount);
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is PerShootFee && other.amount == amount;

  @override
  int get hashCode => amount.hashCode;

  @override
  String toString() => 'PerShootFee($amount)';
}

@immutable
final class NegotiableFee extends FeeHint {
  const NegotiableFee();

  @override
  bool operator ==(Object other) => other is NegotiableFee;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'NegotiableFee()';
}

/// `recruitPosts/{id}`; read only by provider accounts (R3).
@immutable
class RecruitPost {
  const RecruitPost({
    required this.id,
    required this.studioId,
    required this.studioName,
    required this.studioAvatarUrl,
    required this.studioBusinessVerified,
    required this.kind,
    required this.title,
    required this.specialties,
    required this.areas,
    required this.frequency,
    required this.fee,
    required this.requirements,
    required this.status,
    required this.renewed,
    required this.applicationCount,
    required this.matchKeys,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String studioId;
  final String studioName;
  final String? studioAvatarUrl;
  final bool studioBusinessVerified;
  final RecruitKind kind;
  final String title;

  /// `kSpecialties` ids.
  final List<String> specialties;

  /// `builtInAreas` ids.
  final List<String> areas;
  final RecruitFrequency frequency;
  final FeeHint fee;
  final String requirements;
  final RecruitPostStatus status;
  final bool renewed;
  final int applicationCount;

  /// `a=<area>|s=<specialty>` for each area × specialty.
  final List<String> matchKeys;
  final DateTime createdAt;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      other is RecruitPost &&
      other.id == id &&
      other.studioId == studioId &&
      other.studioName == studioName &&
      other.studioAvatarUrl == studioAvatarUrl &&
      other.studioBusinessVerified == studioBusinessVerified &&
      other.kind == kind &&
      other.title == title &&
      listEquals(other.specialties, specialties) &&
      listEquals(other.areas, areas) &&
      other.frequency == frequency &&
      other.fee == fee &&
      other.requirements == requirements &&
      other.status == status &&
      other.renewed == renewed &&
      other.applicationCount == applicationCount &&
      listEquals(other.matchKeys, matchKeys) &&
      other.createdAt == createdAt &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(id, status, applicationCount, renewed);
}

/// `recruitApplications/{postId}_{applicantId}`.
@immutable
class RecruitApplication {
  const RecruitApplication({
    required this.id,
    required this.postId,
    required this.studioId,
    required this.applicantId,
    required this.kind,
    required this.postTitle,
    required this.applicantName,
    required this.applicantAvatarUrl,
    required this.status,
    required this.message,
    required this.samplePostIds,
    required this.createdAt,
    required this.expiresAt,
    required this.respondedAt,
  });

  final String id;
  final String postId;
  final String studioId;
  final String applicantId;
  final RecruitKind kind;
  final String postTitle;
  final String applicantName;
  final String? applicantAvatarUrl;
  final ApplicationStatus status;
  final String message;

  /// Up to three of the applicant's own posts.
  final List<String> samplePostIds;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;

  RecruitApplication copyWith({
    ApplicationStatus? status,
    DateTime? respondedAt,
  }) => RecruitApplication(
    id: id,
    postId: postId,
    studioId: studioId,
    applicantId: applicantId,
    kind: kind,
    postTitle: postTitle,
    applicantName: applicantName,
    applicantAvatarUrl: applicantAvatarUrl,
    status: status ?? this.status,
    message: message,
    samplePostIds: samplePostIds,
    createdAt: createdAt,
    expiresAt: expiresAt,
    respondedAt: respondedAt ?? this.respondedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is RecruitApplication &&
      other.id == id &&
      other.postId == postId &&
      other.studioId == studioId &&
      other.applicantId == applicantId &&
      other.kind == kind &&
      other.postTitle == postTitle &&
      other.applicantName == applicantName &&
      other.applicantAvatarUrl == applicantAvatarUrl &&
      other.status == status &&
      other.message == message &&
      listEquals(other.samplePostIds, samplePostIds) &&
      other.createdAt == createdAt &&
      other.expiresAt == expiresAt &&
      other.respondedAt == respondedAt;

  @override
  int get hashCode => Object.hash(
    id,
    postId,
    studioId,
    applicantId,
    kind,
    postTitle,
    applicantName,
    applicantAvatarUrl,
    status,
    message,
    Object.hashAll(samplePostIds),
    createdAt,
    expiresAt,
    respondedAt,
  );
}

/// Actions counted on the Vietnam day [day] (`yyyy-MM-dd`).
@immutable
class RecruitDaily {
  const RecruitDaily({required this.day, required this.count});
  final String day;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is RecruitDaily && other.day == day && other.count == count;

  @override
  int get hashCode => Object.hash(day, count);
}

/// `photographers/{uid}/private/recruit` (Decision 5), server-only; the
/// owner reads it to show limits and actions left today.
@immutable
class RecruitCounters {
  const RecruitCounters({
    this.openPostCount = 0,
    this.postActions,
    this.activeCollabCount = 0,
    this.pendingInviteCount = 0,
    this.collabActions,
    this.openApplicationCount = 0,
    this.applyActions,
    this.recruitBlockedUntil,
  });

  static const empty = RecruitCounters();

  final int openPostCount;
  final RecruitDaily? postActions;
  final int activeCollabCount;
  final int pendingInviteCount;
  final RecruitDaily? collabActions;
  final int openApplicationCount;
  final RecruitDaily? applyActions;
  final DateTime? recruitBlockedUntil;

  static int _left(RecruitDaily? d, DateTime now, int max) {
    if (d == null || d.day != vnDateKey(now)) return max;
    final left = max - d.count;
    return left < 0 ? 0 : left;
  }

  /// Post creates and closes left on the Vietnam day of [now].
  int postActionsLeft(DateTime now) =>
      _left(postActions, now, kRecruitPostDailyActions);

  /// Studio collaboration actions left on the Vietnam day of [now].
  int collabActionsLeft(DateTime now) =>
      _left(collabActions, now, kRecruitCollabDailyActions);

  /// Applications left on the Vietnam day of [now].
  int applyActionsLeft(DateTime now) =>
      _left(applyActions, now, kRecruitApplyDaily);

  /// No new posts, invites or collaborator assignments (Decision 15).
  bool isBlocked(DateTime now) {
    final until = recruitBlockedUntil;
    return until != null && now.isBefore(until);
  }

  @override
  bool operator ==(Object other) =>
      other is RecruitCounters &&
      other.openPostCount == openPostCount &&
      other.postActions == postActions &&
      other.activeCollabCount == activeCollabCount &&
      other.pendingInviteCount == pendingInviteCount &&
      other.collabActions == collabActions &&
      other.openApplicationCount == openApplicationCount &&
      other.applyActions == applyActions &&
      other.recruitBlockedUntil == recruitBlockedUntil;

  @override
  int get hashCode => Object.hash(
    openPostCount,
    postActions,
    activeCollabCount,
    pendingInviteCount,
    collabActions,
    openApplicationCount,
    applyActions,
    recruitBlockedUntil,
  );
}

/// What the signed-in account is, for recruit screens: `users/{uid}.role`
/// and the `photographers/{uid}` fields. A provider account (R3, Decision 2)
/// is role `photographer` with a photographer document.
@immutable
class ProviderFacts {
  const ProviderFacts({
    required this.role,
    required this.providerType,
    required this.acceptingOrders,
    required this.businessVerified,
    required this.recruitMatchKeys,
  });

  final String? role;
  final ProviderType providerType;
  final bool acceptingOrders;
  final bool businessVerified;
  final List<String> recruitMatchKeys;

  bool get isProviderAccount => role == 'photographer';
  bool get isStudio => providerType == ProviderType.studio;

  @override
  bool operator ==(Object other) =>
      other is ProviderFacts &&
      other.role == role &&
      other.providerType == providerType &&
      other.acceptingOrders == acceptingOrders &&
      other.businessVerified == businessVerified &&
      listEquals(other.recruitMatchKeys, recruitMatchKeys);

  @override
  int get hashCode => Object.hash(
    role,
    providerType,
    acceptingOrders,
    businessVerified,
    Object.hashAll(recruitMatchKeys),
  );
}

/// The S27.01 filter: one kind, one area, one specialty, or one studio
/// (S03.01 "Đang tuyển" opens the list for that studio).
@immutable
class RecruitFilter {
  const RecruitFilter({this.kind, this.area, this.specialty, this.studioId});

  final RecruitKind? kind;
  final String? area;
  final String? specialty;
  final String? studioId;

  /// The `filterKeys` value this filter matches; '' without one.
  String get key =>
      recruitFilterKey(kind: kind, area: area, specialty: specialty);

  bool get isEmpty =>
      kind == null && area == null && specialty == null && studioId == null;

  @override
  bool operator ==(Object other) =>
      other is RecruitFilter &&
      other.kind == kind &&
      other.area == area &&
      other.specialty == specialty &&
      other.studioId == studioId;

  @override
  int get hashCode => Object.hash(kind, area, specialty, studioId);
}

/// `k=<kind>|a=<area>|s=<specialty>` with the given parts in that order; ''
/// for no filter. Mirror of the domain's `recruitFilterKey` (recruit.ts).
String recruitFilterKey({RecruitKind? kind, String? area, String? specialty}) =>
    [
      if (kind != null) 'k=${kind.code}',
      if (area != null) 'a=$area',
      if (specialty != null) 's=$specialty',
    ].join('|');

/// `a=<area>|s=<specialty>`.
final _matchKeyPattern = RegExp(r'^a=(.+)\|s=(.+)$');

/// 2 when an area and a specialty of [p] match the viewer, 1 when one of
/// them does, 0 otherwise (Decision 7). [viewerMatchKeys] is the viewer's
/// `recruitMatchKeys` (`a=<area>|s=<specialty>`).
int recruitMatchScore(RecruitPost p, List<String> viewerMatchKeys) {
  final areas = <String>{};
  final specialties = <String>{};
  for (final k in viewerMatchKeys) {
    final m = _matchKeyPattern.firstMatch(k);
    if (m == null) continue;
    areas.add(m.group(1)!);
    specialties.add(m.group(2)!);
  }
  final area = p.areas.any(areas.contains);
  final specialty = p.specialties.any(specialties.contains);
  return (area ? 1 : 0) + (specialty ? 1 : 0);
}

/// The loaded posts ordered by match score, then newest first (Decision 7).
List<RecruitPost> sortByMatch(
  List<RecruitPost> posts,
  List<String> viewerMatchKeys,
) {
  final scored = [
    for (final p in posts) (p, recruitMatchScore(p, viewerMatchKeys)),
  ];
  scored.sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    return byScore != 0 ? byScore : b.$1.createdAt.compareTo(a.$1.createdAt);
  });
  return [for (final s in scored) s.$1];
}

/// A refusal of a recruit or collaboration callable (or the transport).
enum RecruitErrorCode {
  notAcceptingOrders,
  invalidArgument,
  limitExceeded,
  rateLimited,
  recruitBlocked,
  deadlinePassed,
  conflict,
  membershipConflict,
  cooldown,
  studioFull,
  collabFull,
  memberBusy,
  dayTaken,
  notFound,
  permissionDenied,
  notEligible,

  /// #198's BlockGate: the two accounts blocked each other.
  blocked,
  network,
  unknown,
}

/// [field] is the server's `details.field`; `<name>.contact` means contact
/// info in that text (Decision 11).
@immutable
class RecruitError implements Exception {
  const RecruitError(this.code, {this.field});

  final RecruitErrorCode code;
  final String? field;

  bool get isContact => field?.endsWith('.contact') ?? false;

  @override
  bool operator ==(Object other) =>
      other is RecruitError && other.code == code && other.field == field;

  @override
  int get hashCode => Object.hash(code, field);

  @override
  String toString() =>
      'RecruitError(${code.name}${field == null ? '' : ', $field'})';
}

const _serverCodes = <String, RecruitErrorCode>{
  'not_accepting_orders': RecruitErrorCode.notAcceptingOrders,
  'invalid_argument': RecruitErrorCode.invalidArgument,
  'limit_exceeded': RecruitErrorCode.limitExceeded,
  'rate_limited': RecruitErrorCode.rateLimited,
  'recruit_blocked': RecruitErrorCode.recruitBlocked,
  'deadline_passed': RecruitErrorCode.deadlinePassed,
  'conflict': RecruitErrorCode.conflict,
  'membership_conflict': RecruitErrorCode.membershipConflict,
  'cooldown': RecruitErrorCode.cooldown,
  'studio_full': RecruitErrorCode.studioFull,
  'collab_full': RecruitErrorCode.collabFull,
  'member_busy': RecruitErrorCode.memberBusy,
  'day_taken': RecruitErrorCode.dayTaken,
  'not_found': RecruitErrorCode.notFound,
  'permission_denied': RecruitErrorCode.permissionDenied,
  'not_eligible': RecruitErrorCode.notEligible,
  'blocked': RecruitErrorCode.blocked,
};

/// A server error code (`details.code`) → its [RecruitErrorCode]; unknown →
/// [RecruitErrorCode.unknown].
RecruitErrorCode recruitErrorCodeFrom(String code) =>
    _serverCodes[code] ?? RecruitErrorCode.unknown;

/// Any error of a recruit or collaboration call → [RecruitError]: a
/// [RecruitError] as is; a socket error or the `unavailable` /
/// `deadline-exceeded` transport codes → network; a callable refusal by its
/// `details.code` (and `details.field`), else by its message (like
/// `bookingErrorOf`); anything else unknown.
RecruitError recruitErrorOf(Object error) {
  if (error is RecruitError) return error;
  if (error is SocketException) {
    return const RecruitError(RecruitErrorCode.network);
  }
  if (error.runtimeType.toString().contains('FunctionsException')) {
    final dynamic e = error;
    try {
      final code = e.code;
      if (code == 'unavailable' || code == 'deadline-exceeded') {
        return const RecruitError(RecruitErrorCode.network);
      }
      final details = e.details;
      if (details is Map && details['code'] is String) {
        final field = details['field'];
        return RecruitError(
          recruitErrorCodeFrom(details['code'] as String),
          field: field is String ? field : null,
        );
      }
      final message = e.message;
      if (message is String) {
        return RecruitError(recruitErrorCodeFrom(message));
      }
    } on Object catch (_) {}
  }
  return const RecruitError(RecruitErrorCode.unknown);
}
