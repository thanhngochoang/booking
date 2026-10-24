// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'studio_booking.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StudioAssignment _$StudioAssignmentFromJson(Map<String, dynamic> json) =>
    _StudioAssignment(
      assigneeId: json['assigneeId'] as String,
      assigneeKind: json['assigneeKind'] as String? ?? 'member',
      at: DateTime.parse(json['at'] as String),
      by: json['by'] as String,
      reason: json['reason'] as String?,
      late: json['late'] as bool? ?? false,
      offerExpiresAt: json['offerExpiresAt'] == null
          ? null
          : DateTime.parse(json['offerExpiresAt'] as String),
      acceptedAt: json['acceptedAt'] == null
          ? null
          : DateTime.parse(json['acceptedAt'] as String),
      declinedAt: json['declinedAt'] == null
          ? null
          : DateTime.parse(json['declinedAt'] as String),
    );

Map<String, dynamic> _$StudioAssignmentToJson(_StudioAssignment instance) =>
    <String, dynamic>{
      'assigneeId': instance.assigneeId,
      'assigneeKind': instance.assigneeKind,
      'at': instance.at.toIso8601String(),
      'by': instance.by,
      'reason': instance.reason,
      'late': instance.late,
      'offerExpiresAt': instance.offerExpiresAt?.toIso8601String(),
      'acceptedAt': instance.acceptedAt?.toIso8601String(),
      'declinedAt': instance.declinedAt?.toIso8601String(),
    };

_StudioChangeRequest _$StudioChangeRequestFromJson(Map<String, dynamic> json) =>
    _StudioChangeRequest(
      at: DateTime.parse(json['at'] as String),
      note: json['note'] as String?,
      respondBy: DateTime.parse(json['respondBy'] as String),
      status:
          $enumDecodeNullable(_$ChangeRequestStatusEnumMap, json['status']) ??
          ChangeRequestStatus.pending,
      declineReason: json['declineReason'] as String?,
      answeredAt: json['answeredAt'] == null
          ? null
          : DateTime.parse(json['answeredAt'] as String),
    );

Map<String, dynamic> _$StudioChangeRequestToJson(
  _StudioChangeRequest instance,
) => <String, dynamic>{
  'at': instance.at.toIso8601String(),
  'note': instance.note,
  'respondBy': instance.respondBy.toIso8601String(),
  'status': _$ChangeRequestStatusEnumMap[instance.status]!,
  'declineReason': instance.declineReason,
  'answeredAt': instance.answeredAt?.toIso8601String(),
};

const _$ChangeRequestStatusEnumMap = {
  ChangeRequestStatus.pending: 'pending',
  ChangeRequestStatus.reassigned: 'reassigned',
  ChangeRequestStatus.declined: 'declined',
  ChangeRequestStatus.expired: 'expired',
};

_StudioFault _$StudioFaultFromJson(Map<String, dynamic> json) => _StudioFault(
  kind: $enumDecode(_$StudioFaultKindEnumMap, json['kind']),
  at: DateTime.parse(json['at'] as String),
);

Map<String, dynamic> _$StudioFaultToJson(_StudioFault instance) =>
    <String, dynamic>{
      'kind': _$StudioFaultKindEnumMap[instance.kind]!,
      'at': instance.at.toIso8601String(),
    };

const _$StudioFaultKindEnumMap = {
  StudioFaultKind.assignOverdue: 'assign_overdue',
  StudioFaultKind.changeDeclined: 'change_declined',
  StudioFaultKind.changeExpired: 'change_expired',
  StudioFaultKind.lateReassign: 'late_reassign',
};

_StudioBookingInfo _$StudioBookingInfoFromJson(Map<String, dynamic> json) =>
    _StudioBookingInfo(
      assigneeId: json['assigneeId'] as String?,
      assigneeKind: json['assigneeKind'] as String?,
      assigneeAccepted: json['assigneeAccepted'] as bool? ?? false,
      assignStatus:
          $enumDecodeNullable(
            _$StudioAssignStatusEnumMap,
            json['assignStatus'],
          ) ??
          StudioAssignStatus.unassigned,
      assignDeadline: DateTime.parse(json['assignDeadline'] as String),
      assignOverdue: json['assignOverdue'] as bool? ?? false,
      assignedAt: json['assignedAt'] == null
          ? null
          : DateTime.parse(json['assignedAt'] as String),
      assignments:
          (json['assignments'] as List<dynamic>?)
              ?.map((e) => StudioAssignment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <StudioAssignment>[],
      remindersSent:
          (json['remindersSent'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      changeRequest: json['changeRequest'] == null
          ? null
          : StudioChangeRequest.fromJson(
              json['changeRequest'] as Map<String, dynamic>,
            ),
      studioFault: json['studioFault'] == null
          ? null
          : StudioFault.fromJson(json['studioFault'] as Map<String, dynamic>),
      returnedAt: json['returnedAt'] == null
          ? null
          : DateTime.parse(json['returnedAt'] as String),
      returnReason: json['returnReason'] as String?,
    );

Map<String, dynamic> _$StudioBookingInfoToJson(_StudioBookingInfo instance) =>
    <String, dynamic>{
      'assigneeId': instance.assigneeId,
      'assigneeKind': instance.assigneeKind,
      'assigneeAccepted': instance.assigneeAccepted,
      'assignStatus': _$StudioAssignStatusEnumMap[instance.assignStatus]!,
      'assignDeadline': instance.assignDeadline.toIso8601String(),
      'assignOverdue': instance.assignOverdue,
      'assignedAt': instance.assignedAt?.toIso8601String(),
      'assignments': instance.assignments,
      'remindersSent': instance.remindersSent,
      'changeRequest': instance.changeRequest,
      'studioFault': instance.studioFault,
      'returnedAt': instance.returnedAt?.toIso8601String(),
      'returnReason': instance.returnReason,
    };

const _$StudioAssignStatusEnumMap = {
  StudioAssignStatus.unassigned: 'unassigned',
  StudioAssignStatus.assigned: 'assigned',
};
