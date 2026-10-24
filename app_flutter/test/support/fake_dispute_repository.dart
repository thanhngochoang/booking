import 'dart:async';

import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/disputes/dispute_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';

import 'dispute_world.dart' show disputeNow;

/// In-memory [DisputeRepository] for widget tests. Uploads go through a
/// [FakeMediaUploader] (so `uploader.purposes` / `uploader.deleted` can be
/// asserted); `open` records the draft and, unless [failWith] is set, stores
/// an open dispute built from it, created at [clock] (the world's fake
/// clock; [disputeNow] when none is given).
class FakeDisputeRepository implements DisputeRepository {
  FakeDisputeRepository({
    this.uid = 'c1',
    FakeMediaUploader? uploader,
    Iterable<Dispute> disputes = const [],
    DateTime Function()? clock,
  }) : uploader = uploader ?? FakeMediaUploader(),
       clock = clock ?? (() => disputeNow) {
    for (final d in disputes) {
      _disputes[d.id] = d;
    }
  }

  /// The signed-in user: evidence paths and new disputes use it.
  final String uid;
  final FakeMediaUploader uploader;
  final DateTime Function() clock;

  final Map<String, Dispute> _disputes = {};
  final _changes = StreamController<String>.broadcast();

  /// Every draft passed to [open], in order (also the refused ones).
  final List<DisputeDraft> opened = [];

  /// When set, [open] throws it after recording the draft.
  DisputeError? failWith;

  /// When set, [mine] throws it.
  Object? mineError;

  /// Number of [mine] calls.
  int mineCalls = 0;

  /// Adds or replaces a dispute and tells its watchers.
  void put(Dispute d) {
    _disputes[d.id] = d;
    _changes.add(d.id);
  }

  @override
  String evidencePath(String disputeId, String fileId) =>
      'disputeEvidence/$uid/$disputeId/$fileId.jpg';

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
    opened.add(draft);
    final e = failWith;
    if (e != null) {
      throw e;
    }
    final existing = _disputes[draft.disputeId];
    if (existing != null) {
      return existing.id;
    }
    final now = clock().toUtc();
    put(
      Dispute(
        id: draft.disputeId,
        subjectType: draft.subjectType,
        subjectId: draft.subjectId,
        eventId: draft.eventId,
        customerId: uid,
        providerId: 'p1',
        reason: draft.reason,
        description: draft.description,
        evidencePaths: draft.evidencePaths,
        title: '',
        subtitle: '',
        amountHeld: 0,
        status: DisputeStatus.open,
        threadId: 'dispute_${draft.disputeId}',
        createdAt: now,
      ),
    );
    return draft.disputeId;
  }

  @override
  Stream<Dispute?> watch(String disputeId) async* {
    yield _disputes[disputeId];
    await for (final id in _changes.stream) {
      if (id == disputeId) {
        yield _disputes[disputeId];
      }
    }
  }

  @override
  Future<List<Dispute>> mine({int limit = 10}) async {
    mineCalls++;
    final e = mineError;
    if (e != null) {
      throw e;
    }
    final list =
        _disputes.values
            .where((d) => d.customerId == uid || d.providerId == uid)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }

  @override
  Future<String> evidenceUrl(String storagePath) async =>
      'https://storage.test/$storagePath';
}
