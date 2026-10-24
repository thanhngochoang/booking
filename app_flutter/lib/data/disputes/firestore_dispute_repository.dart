import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:photobooking/data/backend/backend_config.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/disputes/dispute_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';

/// Reads `disputes` directly (the rule admits the two parties only, so a list
/// must filter on `parties`); opens through the `openDispute` callable;
/// evidence lives in Storage under `disputeEvidence/{uid}/{disputeId}/`.
class FirestoreDisputeRepository implements DisputeRepository {
  FirestoreDisputeRepository({
    required this.uid,
    required this.uploader,
    required this.urls,
    FirebaseFirestore? db,
    FirebaseFunctions? functions,
  }) : _dbOverride = db,
       _functionsOverride = functions;

  /// The signed-in user; null when signed out.
  final String? uid;
  final MediaUploader uploader;
  final MediaUrlResolver urls;
  final FirebaseFirestore? _dbOverride;
  final FirebaseFunctions? _functionsOverride;

  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: functionsRegion);

  CollectionReference<Map<String, dynamic>> get _disputes =>
      _db.collection('disputes');

  String _me() {
    final me = uid;
    if (me == null) {
      throw const DisputeError('permission_denied');
    }
    return me;
  }

  @override
  String evidencePath(String disputeId, String fileId) =>
      'disputeEvidence/${_me()}/$disputeId/$fileId.jpg';

  @override
  Stream<UploadEvent> uploadEvidence(PickedImage image, String storagePath) =>
      uploader.upload(
        image,
        storagePath: storagePath,
        purpose: ImagePurpose.document,
      );

  @override
  Future<void> deleteEvidence(String storagePath) =>
      uploader.delete(storagePath);

  @override
  Future<String> open(DisputeDraft draft) async {
    final data = await _call('openDispute', {
      'disputeId': draft.disputeId,
      'subjectType': draft.subjectType.code,
      'subjectId': draft.subjectId,
      'eventId': ?draft.eventId,
      'reason': draft.reason.code,
      'description': draft.description,
      'evidencePaths': draft.evidencePaths,
    });
    final id = data is Map ? data['disputeId'] : null;
    return id is String && id.isNotEmpty ? id : draft.disputeId;
  }

  @override
  Stream<Dispute?> watch(String disputeId) {
    if (!_validId(disputeId)) {
      return Stream.value(null);
    }
    return disputeSnapshots(_disputes.doc(disputeId).snapshots());
  }

  @override
  Future<List<Dispute>> mine({int limit = 10}) async {
    final me = uid;
    if (me == null) {
      return const [];
    }
    final snap = await _disputes
        .where('parties', arrayContains: me)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return [for (final d in snap.docs) Dispute.fromFirestore(d.id, d.data())];
  }

  @override
  Future<String> evidenceUrl(String storagePath) =>
      urls.downloadUrl(storagePath);

  /// `openDispute` runs with the payment options (30 s on the server): the
  /// client waits a little longer, so a slow commit is not reported as a
  /// failure (a retry with the same id would still be answered unchanged).
  static const _paymentTimeout = Duration(seconds: 35);

  /// Like `callEventFunction`: `details.code` → [DisputeError], an unreachable
  /// backend → `DisputeError('network')`.
  Future<Object?> _call(String name, Map<String, Object?> data) async {
    try {
      final r = await _functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: _paymentTimeout),
          )
          .call<Object?>(data);
      return r.data;
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      if (details is Map && details['code'] is String) {
        throw DisputeError(details['code'] as String);
      }
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const DisputeError('network');
      }
      throw DisputeError(e.message ?? e.code);
    }
  }
}

/// `disputes/{id}` snapshots → disputes. A missing dispute has no `parties`
/// to admit the reader, so the rule refuses it: `permission-denied` becomes
/// null, and S18.02 shows "not found" for both cases. Other errors pass.
@visibleForTesting
Stream<Dispute?> disputeSnapshots(
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots,
) => snapshots.transform(
  StreamTransformer<DocumentSnapshot<Map<String, dynamic>>, Dispute?>.fromHandlers(
    handleData: (snap, sink) {
      final d = snap.data();
      sink.add(d == null ? null : Dispute.fromFirestore(snap.id, d));
    },
    handleError: (e, st, sink) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        sink.add(null);
      } else {
        sink.addError(e, st);
      }
    },
  ),
);

bool _validId(String id) => id.isNotEmpty && !id.contains('/');
