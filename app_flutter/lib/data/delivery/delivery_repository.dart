import 'dart:io' show SocketException;

import 'package:photobooking/data/delivery/delivery.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';

enum DeliveryErrorCode {
  notReady,
  notEligible,
  conflict,
  permissionDenied,
  notFound,
  invalidArgument,
  network,
  unknown,
}

class DeliveryException implements Exception {
  const DeliveryException(this.code);
  final String code;

  @override
  String toString() => 'DeliveryException($code)';
}

DeliveryErrorCode deliveryErrorOf(Object error) {
  if (error is SocketException) {
    return DeliveryErrorCode.network;
  }
  if (error is DeliveryException) {
    return _codeToDeliveryError(error.code);
  }
  final errType = error.runtimeType.toString();
  if (errType.contains('FunctionsException')) {
    dynamic dyn = error;
    try {
      final code = dyn.code;
      if (code == 'unavailable' || code == 'deadline-exceeded') {
        return DeliveryErrorCode.network;
      }
      final details = dyn.details;
      if (details is Map && details['code'] is String) {
        return _codeToDeliveryError(details['code'] as String);
      }
      if (dyn.message is String) {
        return _codeToDeliveryError(dyn.message as String);
      }
    } catch (_) {}
  }
  return DeliveryErrorCode.unknown;
}

DeliveryErrorCode _codeToDeliveryError(String code) {
  switch (code) {
    case 'not_ready':
      return DeliveryErrorCode.notReady;
    case 'not_eligible':
      return DeliveryErrorCode.notEligible;
    case 'conflict':
      return DeliveryErrorCode.conflict;
    case 'permission_denied':
    case 'permission-denied':
      return DeliveryErrorCode.permissionDenied;
    case 'not_found':
    case 'not-found':
      return DeliveryErrorCode.notFound;
    case 'invalid_argument':
    case 'invalid-argument':
      return DeliveryErrorCode.invalidArgument;
    case 'unavailable':
    case 'deadline-exceeded':
    case 'network':
      return DeliveryErrorCode.network;
    default:
      return DeliveryErrorCode.unknown;
  }
}

abstract class DeliveryRepository {
  Stream<List<DeliveryRound>> watchRounds(String bookingId);
  Stream<DeliveryLink?> watchLink(String bookingId);
  Stream<List<StagedSample>> watchStagedSamples(String bookingId);
  Stream<UploadEvent> uploadSample({
    required String bookingId,
    required String uploaderId,
    required String fileId,
    required PickedImage image,
  });
  Future<void> discardSample({
    required String bookingId,
    required String uploaderId,
    required String fileId,
  });
  Future<int> submit({
    required String bookingId,
    required List<String> sampleIds,
    required String link,
    required int photoCount,
    String? note,
  });
  Future<void> approve(String bookingId);
  Future<void> requestRevision({
    required String bookingId,
    String? note,
    List<DeliveryPhotoNote> photoNotes = const [],
    bool extra = false,
  });
  Future<void> answerExtraRound({
    required String bookingId,
    required bool grant,
  });
  Future<String> imageUrl(String storagePath);
}
