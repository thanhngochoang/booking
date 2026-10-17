import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'delivery.freezed.dart';
part 'delivery.g.dart';

@freezed
abstract class DeliverySampleRef with _$DeliverySampleRef {
  const factory DeliverySampleRef({
    required String fileId,
    required String path,
    required String thumbPath,
    required int width,
    required int height,
  }) = _DeliverySampleRef;

  factory DeliverySampleRef.fromJson(Map<String, dynamic> json) =>
      _$DeliverySampleRefFromJson(json);
}

@freezed
abstract class DeliveryDecision with _$DeliveryDecision {
  const factory DeliveryDecision({
    required String kind, // 'approve' | 'request_revision'
    String? note,
    @Default(<DeliveryPhotoNote>[]) List<DeliveryPhotoNote> photoNotes,
    required DateTime at,
    @Default(false) bool auto,
    @Default(false) bool extra,
  }) = _DeliveryDecision;

  factory DeliveryDecision.fromJson(Map<String, dynamic> json) =>
      _$DeliveryDecisionFromJson(json);
}

@freezed
abstract class DeliveryPhotoNote with _$DeliveryPhotoNote {
  const factory DeliveryPhotoNote({
    required int sampleIndex,
    required String note,
  }) = _DeliveryPhotoNote;

  factory DeliveryPhotoNote.fromJson(Map<String, dynamic> json) =>
      _$DeliveryPhotoNoteFromJson(json);
}

@freezed
abstract class DeliveryRound with _$DeliveryRound {
  const factory DeliveryRound({
    required String bookingId,
    required int round,
    required List<DeliverySampleRef> samples,
    required int photoCount,
    required String linkHost,
    String? note,
    required DateTime submittedAt,
    required String submittedBy,
    DeliveryDecision? decision,
  }) = _DeliveryRound;

  factory DeliveryRound.fromJson(Map<String, dynamic> json) =>
      _$DeliveryRoundFromJson(json);
}

@freezed
abstract class DeliveryLink with _$DeliveryLink {
  const factory DeliveryLink({
    required String link,
    required int round,
    DateTime? unlockedAt,
  }) = _DeliveryLink;

  factory DeliveryLink.fromJson(Map<String, dynamic> json) =>
      _$DeliveryLinkFromJson(json);
}

enum SampleStatus { ready, failed }

@freezed
abstract class StagedSample with _$StagedSample {
  const factory StagedSample({
    required String fileId,
    required SampleStatus status,
    String? path,
    String? thumbPath,
    String? failure,
  }) = _StagedSample;

  factory StagedSample.fromJson(Map<String, dynamic> json) =>
      _$StagedSampleFromJson(json);
}

DateTime? _toDateTime(Object? val) {
  if (val is Timestamp) return val.toDate().toUtc();
  if (val is DateTime) return val.toUtc();
  if (val is String) return DateTime.tryParse(val)?.toUtc();
  return null;
}

DeliveryRound? deliveryRoundFromFirestore(Map<String, dynamic>? data) {
  if (data == null) return null;
  try {
    final bookingId = data['bookingId'] as String? ?? '';
    final round = (data['round'] as num?)?.toInt() ?? 1;
    final photoCount = (data['photoCount'] as num?)?.toInt() ?? 0;
    final linkHost = data['linkHost'] as String? ?? '';
    final note = data['note'] as String?;
    final submittedAt = _toDateTime(data['submittedAt']) ?? DateTime.now().toUtc();
    final submittedBy = data['submittedBy'] as String? ?? '';

    final samplesRaw = data['samples'];
    final samples = <DeliverySampleRef>[];
    if (samplesRaw is List) {
      for (final s in samplesRaw) {
        if (s is Map) {
          samples.add(
            DeliverySampleRef(
              fileId: s['fileId'] as String? ?? '',
              path: s['path'] as String? ?? '',
              thumbPath: s['thumbPath'] as String? ?? '',
              width: (s['width'] as num?)?.toInt() ?? 0,
              height: (s['height'] as num?)?.toInt() ?? 0,
            ),
          );
        }
      }
    }

    DeliveryDecision? decision;
    final decRaw = data['decision'];
    if (decRaw is Map) {
      final decAt = _toDateTime(decRaw['at']);
      if (decAt != null) {
        final pNotesRaw = decRaw['photoNotes'];
        final photoNotes = <DeliveryPhotoNote>[];
        if (pNotesRaw is List) {
          for (final pn in pNotesRaw) {
            if (pn is Map && pn['sampleIndex'] is num && pn['note'] is String) {
              photoNotes.add(
                DeliveryPhotoNote(
                  sampleIndex: (pn['sampleIndex'] as num).toInt(),
                  note: pn['note'] as String,
                ),
              );
            }
          }
        }
        decision = DeliveryDecision(
          kind: decRaw['kind'] as String? ?? 'approve',
          note: decRaw['note'] as String?,
          photoNotes: photoNotes,
          at: decAt,
          auto: decRaw['auto'] as bool? ?? false,
          extra: decRaw['extra'] as bool? ?? false,
        );
      }
    }

    return DeliveryRound(
      bookingId: bookingId,
      round: round,
      samples: samples,
      photoCount: photoCount,
      linkHost: linkHost,
      note: note,
      submittedAt: submittedAt,
      submittedBy: submittedBy,
      decision: decision,
    );
  } catch (_) {
    return null;
  }
}

DeliveryLink? deliveryLinkFromFirestore(Map<String, dynamic>? data) {
  if (data == null) return null;
  try {
    final link = data['link'] as String?;
    if (link == null) return null;
    return DeliveryLink(
      link: link,
      round: (data['round'] as num?)?.toInt() ?? 1,
      unlockedAt: _toDateTime(data['unlockedAt']),
    );
  } catch (_) {
    return null;
  }
}

StagedSample? stagedSampleFromFirestore(String fileId, Map<String, dynamic>? data) {
  if (data == null) return null;
  try {
    final statusStr = data['status'] as String?;
    final status = statusStr == 'ready' ? SampleStatus.ready : SampleStatus.failed;
    return StagedSample(
      fileId: fileId,
      status: status,
      path: data['path'] as String?,
      thumbPath: data['thumbPath'] as String?,
      failure: data['failure'] as String?,
    );
  } catch (_) {
    return null;
  }
}
