import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/delivery/delivery.dart';
import 'package:photobooking/data/delivery/delivery_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';

class FirestoreDeliveryRepository implements DeliveryRepository {
  FirestoreDeliveryRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    this.uploader,
    this.urlResolver,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _customFunctions = functions;

  final FirebaseFirestore _db;
  final FirebaseFunctions? _customFunctions;
  final MediaUploader? uploader;
  final MediaUrlResolver? urlResolver;

  FirebaseFunctions get _functions =>
      _customFunctions ??
      FirebaseFunctions.instanceFor(region: functionsRegion);

  Future<T> _call<T>(
    String name,
    Map<String, dynamic> data,
    T Function(dynamic) parse,
  ) async {
    try {
      final res = await _functions.httpsCallable(name).call(data);
      return parse(res.data);
    } catch (e) {
      throw DeliveryException(deliveryErrorOf(e).name);
    }
  }

  @override
  Stream<List<DeliveryRound>> watchRounds(String bookingId) {
    return _db
        .collection('bookings')
        .doc(bookingId)
        .collection('deliveries')
        .orderBy('round', descending: true)
        .limit(5)
        .snapshots()
        .map(
          (qs) => qs.docs
              .map((d) => deliveryRoundFromFirestore(d.data()))
              .whereType<DeliveryRound>()
              .toList(),
        );
  }

  @override
  Stream<DeliveryLink?> watchLink(String bookingId) {
    return _db
        .collection('bookings')
        .doc(bookingId)
        .collection('private')
        .doc('delivery')
        .snapshots()
        .map((snap) => deliveryLinkFromFirestore(snap.data()))
        .handleError((_) => null);
  }

  @override
  Stream<List<StagedSample>> watchStagedSamples(String bookingId) {
    return _db
        .collection('bookings')
        .doc(bookingId)
        .collection('deliverySamples')
        .snapshots()
        .map(
          (qs) => qs.docs
              .map((d) => stagedSampleFromFirestore(d.id, d.data()))
              .whereType<StagedSample>()
              .toList(),
        );
  }

  @override
  Stream<UploadEvent> uploadSample({
    required String bookingId,
    required String uploaderId,
    required String fileId,
    required PickedImage image,
  }) {
    final storagePath = 'deliveryUploads/$bookingId/$uploaderId/$fileId.jpg';
    if (uploader != null) {
      return uploader!.upload(
        image,
        storagePath: storagePath,
        purpose: ImagePurpose.deliverySample,
      );
    }
    throw UnimplementedError('MediaUploader is required for uploadSample');
  }

  @override
  Future<void> discardSample({
    required String bookingId,
    required String uploaderId,
    required String fileId,
  }) async {
    final storagePath = 'deliveryUploads/$bookingId/$uploaderId/$fileId.jpg';
    if (uploader != null) {
      await uploader!.delete(storagePath);
    }
  }

  @override
  Future<int> submit({
    required String bookingId,
    required List<String> sampleIds,
    required String link,
    required int photoCount,
    String? note,
  }) async {
    return _call(
      'submitDelivery',
      {
        'bookingId': bookingId,
        'sampleIds': sampleIds,
        'link': link,
        'photoCount': photoCount,
        'note': ?note,
      },
      (raw) => ((raw as Map)['round'] as num).toInt(),
    );
  }

  @override
  Future<void> approve(String bookingId) async {
    await _call(
      'approveDelivery',
      {'bookingId': bookingId},
      (_) => null,
    );
  }

  @override
  Future<void> requestRevision({
    required String bookingId,
    String? note,
    List<DeliveryPhotoNote> photoNotes = const [],
    bool extra = false,
  }) async {
    await _call(
      'requestRevision',
      {
        'bookingId': bookingId,
        'note': ?note,
        'photoNotes': photoNotes
            .map((p) => {'sampleIndex': p.sampleIndex, 'note': p.note})
            .toList(),
        'extra': extra,
      },
      (_) => null,
    );
  }

  @override
  Future<void> answerExtraRound({
    required String bookingId,
    required bool grant,
  }) async {
    await _call(
      'answerExtraRound',
      {'bookingId': bookingId, 'grant': grant},
      (_) => null,
    );
  }

  @override
  Future<String> imageUrl(String storagePath) async {
    if (urlResolver != null) {
      return urlResolver!.downloadUrl(storagePath);
    }
    return storagePath;
  }
}
