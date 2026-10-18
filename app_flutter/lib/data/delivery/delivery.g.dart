// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeliverySampleRef _$DeliverySampleRefFromJson(Map<String, dynamic> json) =>
    _DeliverySampleRef(
      fileId: json['fileId'] as String,
      path: json['path'] as String,
      thumbPath: json['thumbPath'] as String,
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );

Map<String, dynamic> _$DeliverySampleRefToJson(_DeliverySampleRef instance) =>
    <String, dynamic>{
      'fileId': instance.fileId,
      'path': instance.path,
      'thumbPath': instance.thumbPath,
      'width': instance.width,
      'height': instance.height,
    };

_DeliveryDecision _$DeliveryDecisionFromJson(Map<String, dynamic> json) =>
    _DeliveryDecision(
      kind: json['kind'] as String,
      note: json['note'] as String?,
      photoNotes:
          (json['photoNotes'] as List<dynamic>?)
              ?.map(
                (e) => DeliveryPhotoNote.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <DeliveryPhotoNote>[],
      at: DateTime.parse(json['at'] as String),
      auto: json['auto'] as bool? ?? false,
      extra: json['extra'] as bool? ?? false,
    );

Map<String, dynamic> _$DeliveryDecisionToJson(_DeliveryDecision instance) =>
    <String, dynamic>{
      'kind': instance.kind,
      'note': instance.note,
      'photoNotes': instance.photoNotes,
      'at': instance.at.toIso8601String(),
      'auto': instance.auto,
      'extra': instance.extra,
    };

_DeliveryPhotoNote _$DeliveryPhotoNoteFromJson(Map<String, dynamic> json) =>
    _DeliveryPhotoNote(
      sampleIndex: (json['sampleIndex'] as num).toInt(),
      note: json['note'] as String,
    );

Map<String, dynamic> _$DeliveryPhotoNoteToJson(_DeliveryPhotoNote instance) =>
    <String, dynamic>{
      'sampleIndex': instance.sampleIndex,
      'note': instance.note,
    };

_DeliveryRound _$DeliveryRoundFromJson(Map<String, dynamic> json) =>
    _DeliveryRound(
      bookingId: json['bookingId'] as String,
      round: (json['round'] as num).toInt(),
      samples: (json['samples'] as List<dynamic>)
          .map((e) => DeliverySampleRef.fromJson(e as Map<String, dynamic>))
          .toList(),
      photoCount: (json['photoCount'] as num).toInt(),
      linkHost: json['linkHost'] as String,
      note: json['note'] as String?,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      submittedBy: json['submittedBy'] as String,
      decision: json['decision'] == null
          ? null
          : DeliveryDecision.fromJson(json['decision'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DeliveryRoundToJson(_DeliveryRound instance) =>
    <String, dynamic>{
      'bookingId': instance.bookingId,
      'round': instance.round,
      'samples': instance.samples,
      'photoCount': instance.photoCount,
      'linkHost': instance.linkHost,
      'note': instance.note,
      'submittedAt': instance.submittedAt.toIso8601String(),
      'submittedBy': instance.submittedBy,
      'decision': instance.decision,
    };

_DeliveryLink _$DeliveryLinkFromJson(Map<String, dynamic> json) =>
    _DeliveryLink(
      link: json['link'] as String,
      round: (json['round'] as num).toInt(),
      unlockedAt: json['unlockedAt'] == null
          ? null
          : DateTime.parse(json['unlockedAt'] as String),
    );

Map<String, dynamic> _$DeliveryLinkToJson(_DeliveryLink instance) =>
    <String, dynamic>{
      'link': instance.link,
      'round': instance.round,
      'unlockedAt': instance.unlockedAt?.toIso8601String(),
    };

_StagedSample _$StagedSampleFromJson(Map<String, dynamic> json) =>
    _StagedSample(
      fileId: json['fileId'] as String,
      status: $enumDecode(_$SampleStatusEnumMap, json['status']),
      path: json['path'] as String?,
      thumbPath: json['thumbPath'] as String?,
      failure: json['failure'] as String?,
    );

Map<String, dynamic> _$StagedSampleToJson(_StagedSample instance) =>
    <String, dynamic>{
      'fileId': instance.fileId,
      'status': _$SampleStatusEnumMap[instance.status]!,
      'path': instance.path,
      'thumbPath': instance.thumbPath,
      'failure': instance.failure,
    };

const _$SampleStatusEnumMap = {
  SampleStatus.ready: 'ready',
  SampleStatus.failed: 'failed',
};
