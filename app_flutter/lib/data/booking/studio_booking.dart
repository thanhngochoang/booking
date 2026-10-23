import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:photobooking/core/core.dart';

part 'studio_booking.freezed.dart';
part 'studio_booking.g.dart';

/// Whether the studio has named who shoots a studio booking (#136).
enum StudioAssignStatus { unassigned, assigned }

/// Why the customer may cancel a studio booking with a 100% refund
/// (Decision 12).
enum StudioFaultKind {
  @JsonValue('assign_overdue')
  assignOverdue('assign_overdue'),
  @JsonValue('change_declined')
  changeDeclined('change_declined'),
  @JsonValue('change_expired')
  changeExpired('change_expired'),
  @JsonValue('late_reassign')
  lateReassign('late_reassign');

  const StudioFaultKind(this.code);
  final String code;

  static StudioFaultKind? fromCode(Object? c) {
    for (final k in values) {
      if (k.code == c) return k;
    }
    return null;
  }
}

/// The customer's one request to change the assignee (S26.05).
enum ChangeRequestStatus { pending, reassigned, declined, expired }

/// One line of the assignment log; `assigneeKind` is `member` (S27 adds
/// `collaborator` without migration).
@freezed
abstract class StudioAssignment with _$StudioAssignment {
  const factory StudioAssignment({
    required String assigneeId,
    @Default('member') String assigneeKind,
    required DateTime at,
    required String by,
    String? reason,
    @Default(false) bool late,
  }) = _StudioAssignment;

  factory StudioAssignment.fromJson(Map<String, dynamic> json) =>
      _$StudioAssignmentFromJson(json);
}

@freezed
abstract class StudioChangeRequest with _$StudioChangeRequest {
  const factory StudioChangeRequest({
    required DateTime at,
    String? note,
    required DateTime respondBy,
    @Default(ChangeRequestStatus.pending) ChangeRequestStatus status,
    String? declineReason,
    DateTime? answeredAt,
  }) = _StudioChangeRequest;

  factory StudioChangeRequest.fromJson(Map<String, dynamic> json) =>
      _$StudioChangeRequestFromJson(json);
}

@freezed
abstract class StudioFault with _$StudioFault {
  const factory StudioFault({
    required StudioFaultKind kind,
    required DateTime at,
  }) = _StudioFault;

  factory StudioFault.fromJson(Map<String, dynamic> json) =>
      _$StudioFaultFromJson(json);
}

/// The studio part of a booking (`isStudio == true`); individual bookings
/// have none. The studio stays the booking's `photographerId`; the assignee
/// is who shoots.
@freezed
abstract class StudioBookingInfo with _$StudioBookingInfo {
  const StudioBookingInfo._();

  const factory StudioBookingInfo({
    /// Who shoots; kept after "Trả việc" until the studio reassigns.
    String? assigneeId,
    String? assigneeKind,
    @Default(StudioAssignStatus.unassigned) StudioAssignStatus assignStatus,
    required DateTime assignDeadline,

    /// Set once by the sweep when the deadline passed unassigned; stays as
    /// history after a late assignment.
    @Default(false) bool assignOverdue,
    DateTime? assignedAt,
    @Default(<StudioAssignment>[]) List<StudioAssignment> assignments,

    /// Reminders the studio got (`h48`, `h26`), for "Đã nhắc … lúc …".
    @Default(<String>[]) List<String> remindersSent,
    StudioChangeRequest? changeRequest,
    StudioFault? studioFault,

    /// "Trả việc": when and why the assignee handed the job back.
    DateTime? returnedAt,
    String? returnReason,
  }) = _StudioBookingInfo;

  bool get isAssigned => assigneeId != null;
  bool get isReturned => returnedAt != null;

  factory StudioBookingInfo.fromJson(Map<String, dynamic> json) =>
      _$StudioBookingInfoFromJson(json);
}

DateTime? _date(Object? v) {
  if (v is Timestamp) return v.toDate().toUtc();
  if (v is DateTime) return v.toUtc();
  if (v is String) return DateTime.tryParse(v)?.toUtc();
  return null;
}

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

Map<String, dynamic>? _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

/// The instant a booking starts: [day] `yyyy-MM-dd` at [start] `HH:mm`,
/// Vietnam wall clock; null when either is malformed.
DateTime? _startInstant(String day, String start) {
  final d = parseDayKey(day);
  final parts = start.split(':');
  if (d == null || parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return fromVnWallClock(DateTime.utc(d.year, d.month, d.day, h, m));
}

/// The studio fields of a `bookings/{id}` document (Firestore or a callable
/// answer with ISO dates); null unless `isStudio == true`. A missing
/// `assignDeadline` (never written by the server) reads as the booking's
/// start, the latest the deadline can be.
StudioBookingInfo? studioBookingInfoFrom(Map<String, dynamic> data) {
  if (data['isStudio'] != true) return null;
  final deadline =
      _date(data['assignDeadline']) ??
      _startInstant(_str(data['day']) ?? '', _str(data['start']) ?? '');
  if (deadline == null) return null;

  final assignments = <StudioAssignment>[];
  final rawAssignments = data['assignments'];
  if (rawAssignments is List) {
    for (final raw in rawAssignments) {
      final a = _map(raw);
      final id = _str(a?['assigneeId']);
      final at = _date(a?['at']);
      if (a == null || id == null || at == null) continue;
      assignments.add(
        StudioAssignment(
          assigneeId: id,
          assigneeKind: _str(a['assigneeKind']) ?? 'member',
          at: at,
          by: _str(a['by']) ?? '',
          reason: _str(a['reason']),
          late: a['late'] == true,
        ),
      );
    }
  }

  StudioChangeRequest? changeRequest;
  final cr = _map(data['changeRequest']);
  final crAt = _date(cr?['at']);
  final crRespondBy = _date(cr?['respondBy']);
  if (cr != null && crAt != null && crRespondBy != null) {
    changeRequest = StudioChangeRequest(
      at: crAt,
      note: _str(cr['note']),
      respondBy: crRespondBy,
      status: ChangeRequestStatus.values.firstWhere(
        (s) => s.name == cr['status'],
        orElse: () => ChangeRequestStatus.pending,
      ),
      declineReason: _str(cr['declineReason']),
      answeredAt: _date(cr['answeredAt']),
    );
  }

  StudioFault? fault;
  final rawFault = _map(data['studioFault']);
  final faultKind = StudioFaultKind.fromCode(rawFault?['kind']);
  final faultAt = _date(rawFault?['at']);
  if (faultKind != null && faultAt != null) {
    fault = StudioFault(kind: faultKind, at: faultAt);
  }

  final returned = _map(data['assignmentReturned']);
  final rawReminders = data['assignRemindersSent'];

  return StudioBookingInfo(
    assigneeId: _str(data['assigneeId']),
    assigneeKind: _str(data['assigneeKind']),
    assignStatus: data['assignStatus'] == 'assigned'
        ? StudioAssignStatus.assigned
        : StudioAssignStatus.unassigned,
    assignDeadline: deadline,
    assignOverdue: data['assignOverdue'] == true,
    assignedAt: _date(data['assignedAt']),
    assignments: assignments,
    remindersSent: [
      if (rawReminders is List)
        for (final r in rawReminders)
          if (r == 'h48' || r == 'h26') r as String,
    ],
    changeRequest: changeRequest,
    studioFault: fault,
    returnedAt: _date(returned?['at']),
    returnReason: _str(returned?['reason']),
  );
}
