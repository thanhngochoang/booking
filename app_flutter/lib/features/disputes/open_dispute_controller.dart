// S18.01's form state: reason, description, evidence uploads and the submit.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/disputes/dispute.dart';
import 'package:photobooking/data/disputes/dispute_providers.dart';
import 'package:photobooking/data/disputes/dispute_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/features/disputes/dispute_entry.dart';

/// Limits of the server (Decision 5): description 10–1000 graphemes after
/// trim, at most 5 evidence photos.
const kDisputeDescriptionMin = 10;
const kDisputeDescriptionMax = 1000;
const kDisputeMaxPhotos = 5;

/// Uploads running at the same time (plan Task 11).
const _maxParallelUploads = 2;

/// One sheet: the dispute id minted when it opened (one per sheet, so a
/// retried submit is answered with the same dispute) and its subject.
@immutable
class OpenDisputeArgs {
  const OpenDisputeArgs({
    required this.disputeId,
    required this.subject,
    this.initialReason,
  });

  final String disputeId;
  final DisputeSubject subject;

  /// The reason set when the sheet opens (S05.02-askshot "Không diễn ra").
  final DisputeReason? initialReason;

  @override
  bool operator ==(Object other) =>
      other is OpenDisputeArgs && other.disputeId == disputeId;

  @override
  int get hashCode => disputeId.hashCode;
}

/// One evidence photo: picked from the gallery, then uploaded to [path].
@immutable
class EvidenceSlot {
  const EvidenceSlot({
    required this.key,
    required this.picked,
    this.path,
    this.progress = 0,
    this.failed = false,
  });

  final String key;
  final PickedImage picked;

  /// The Storage path once uploaded.
  final String? path;
  final double progress;
  final bool failed;

  bool get uploading => path == null && !failed;

  EvidenceSlot copyWith({
    Object? path = _keep,
    double? progress,
    bool? failed,
  }) => EvidenceSlot(
    key: key,
    picked: picked,
    path: identical(path, _keep) ? this.path : path as String?,
    progress: progress ?? this.progress,
    failed: failed ?? this.failed,
  );
}

const Object _keep = Object();

@immutable
class OpenDisputeState {
  const OpenDisputeState({
    this.reason,
    this.description = '',
    this.photos = const [],
    this.submitting = false,
    this.error,
  });

  final DisputeReason? reason;

  /// As typed (trimmed on submit).
  final String description;
  final List<EvidenceSlot> photos;
  final bool submitting;

  /// The last refusal: a domain code (`conflict`, `deadline_passed`, …) or
  /// `network`; cleared by the next edit or submit.
  final String? error;

  int get descriptionLength => description.trim().characters.length;

  bool get descriptionValid =>
      descriptionLength >= kDisputeDescriptionMin &&
      descriptionLength <= kDisputeDescriptionMax;

  bool get uploading => photos.any((p) => p.uploading);
  bool get hasFailedPhoto => photos.any((p) => p.failed);

  /// Something was entered: closing asks first.
  bool get dirty =>
      reason != null || description.trim().isNotEmpty || photos.isNotEmpty;

  bool get canSubmit =>
      reason != null &&
      descriptionValid &&
      !uploading &&
      !hasFailedPhoto &&
      !submitting;

  OpenDisputeState copyWith({
    DisputeReason? reason,
    String? description,
    List<EvidenceSlot>? photos,
    bool? submitting,
    Object? error = _keep,
  }) => OpenDisputeState(
    reason: reason ?? this.reason,
    description: description ?? this.description,
    photos: photos ?? this.photos,
    submitting: submitting ?? this.submitting,
    error: identical(error, _keep) ? this.error : error as String?,
  );
}

/// S18.01. Photos upload as they are picked (at most two at a time), each
/// under a fresh file id (Storage refuses overwrites, so a retry is a new
/// file). Uploads never sent with a dispute are deleted when the sheet goes
/// away; the Storage rule allows that only while the dispute does not exist.
class OpenDisputeController extends Notifier<OpenDisputeState> {
  OpenDisputeController(this.args);

  final OpenDisputeArgs args;

  /// Taken in [build] so the cleanup still works after dispose.
  late DisputeRepository _repo;

  /// True once the dispute exists: the uploads belong to it.
  bool _attached = false;

  /// Uploads finished in this sheet and still wanted.
  final Set<String> _livePaths = {};
  final Set<String> _deletedPaths = {};

  /// Slots whose upload has started (or is queued to start).
  final Set<String> _running = {};

  @override
  OpenDisputeState build() {
    _repo = ref.read(disputeRepositoryProvider);
    ref.onDispose(() {
      if (!_attached) {
        discard();
      }
    });
    return OpenDisputeState(reason: args.initialReason);
  }

  void setReason(DisputeReason reason) =>
      state = state.copyWith(reason: reason, error: null);

  void setDescription(String text) =>
      state = state.copyWith(description: text, error: null);

  /// Opens the gallery for the room left (5 − count) and uploads the picks.
  Future<void> pick() async {
    final room = kDisputeMaxPhotos - state.photos.length;
    if (room <= 0 || state.submitting) {
      return;
    }
    final picked = await ref.read(imagePickerProvider).pickImages(max: room);
    if (!ref.mounted || picked.isEmpty) {
      return;
    }
    // The gallery may ignore `max`; the room may also have shrunk meanwhile.
    final allowed = picked.take(kDisputeMaxPhotos - state.photos.length);
    state = state.copyWith(
      photos: [
        ...state.photos,
        for (final p in allowed) EvidenceSlot(key: newUlid(), picked: p),
      ],
      error: null,
    );
    _startUploads();
  }

  /// Uploads [key] again after a failure.
  void retry(String key) {
    final slot = _slot(key);
    if (slot == null || !slot.failed || state.submitting) {
      return;
    }
    _update(key, (s) => s.copyWith(failed: false, progress: 0));
    _startUploads();
  }

  /// Drops [key]; an uploaded file is deleted (it was never sent).
  void remove(String key) {
    final slot = _slot(key);
    if (slot == null || state.submitting) {
      return;
    }
    state = state.copyWith(
      photos: [
        for (final s in state.photos)
          if (s.key != key) s,
      ],
      error: null,
    );
    final path = slot.path;
    if (path != null && _livePaths.remove(path)) {
      unawaited(_deleteQuietly(path));
    }
    _startUploads();
  }

  /// Sends the dispute; resolves to its id, or null when refused ([error]
  /// says why).
  Future<String?> submit() async {
    final s = state;
    final reason = s.reason;
    if (!s.canSubmit || reason == null) {
      return null;
    }
    state = s.copyWith(submitting: true, error: null);
    final subject = args.subject;
    final draft = DisputeDraft(
      disputeId: args.disputeId,
      subjectType: switch (subject) {
        BookingDisputeSubject() => DisputeSubjectType.booking,
        TicketDisputeSubject() => DisputeSubjectType.ticket,
      },
      subjectId: switch (subject) {
        BookingDisputeSubject(:final bookingId) => bookingId,
        TicketDisputeSubject(:final registrationId) => registrationId,
      },
      eventId: switch (subject) {
        BookingDisputeSubject() => null,
        TicketDisputeSubject(:final eventId) => eventId,
      },
      reason: reason,
      description: s.description.trim(),
      evidencePaths: [
        for (final p in s.photos)
          if (p.path != null) p.path!,
      ],
    );
    try {
      final id = await _repo.open(draft);
      _attached = true;
      if (ref.mounted) {
        state = state.copyWith(submitting: false);
      }
      return id;
    } on DisputeError catch (e) {
      if (ref.mounted) {
        state = state.copyWith(submitting: false, error: e.code);
      }
      return null;
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(submitting: false, error: 'network');
      }
      return null;
    }
  }

  /// Deletes every photo uploaded in this sheet (closing without sending).
  void discard() {
    if (_attached) {
      return;
    }
    for (final path in [..._livePaths]) {
      unawaited(_deleteQuietly(path));
    }
    _livePaths.clear();
  }

  EvidenceSlot? _slot(String key) =>
      state.photos.where((s) => s.key == key).firstOrNull;

  void _update(String key, EvidenceSlot Function(EvidenceSlot) change) {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      photos: [for (final s in state.photos) s.key == key ? change(s) : s],
    );
  }

  /// Starts waiting uploads while fewer than two run.
  void _startUploads() {
    if (!ref.mounted) {
      return;
    }
    for (final slot in state.photos) {
      if (_running.length >= _maxParallelUploads) {
        return;
      }
      if (slot.uploading && _running.add(slot.key)) {
        unawaited(_upload(slot));
      }
    }
  }

  Future<void> _upload(EvidenceSlot slot) async {
    // A fresh file id for every attempt: Storage refuses overwrites.
    String? path;
    try {
      path = _repo.evidencePath(args.disputeId, newUlid());
      var done = false;
      await for (final event in _repo.uploadEvidence(slot.picked, path)) {
        final media = event.media;
        final dropped = !ref.mounted || _slot(slot.key) == null;
        if (media != null) {
          done = true;
          if (dropped) {
            // Removed or closed while it uploaded.
            unawaited(_deleteQuietly(media.storagePath));
            continue;
          }
          _livePaths.add(media.storagePath);
          _update(
            slot.key,
            (s) => s.copyWith(path: media.storagePath, progress: 1),
          );
        } else if (!dropped) {
          _update(slot.key, (s) => s.copyWith(progress: event.fraction));
        }
      }
      if (!done) {
        // The stream ended with neither a result nor an error.
        _update(slot.key, (s) => s.copyWith(failed: true));
      }
    } catch (_) {
      if (path != null) {
        unawaited(_deleteQuietly(path));
      }
      _update(slot.key, (s) => s.copyWith(failed: true));
    } finally {
      _running.remove(slot.key);
      _startUploads();
    }
  }

  Future<void> _deleteQuietly(String path) async {
    if (!_deletedPaths.add(path)) {
      return;
    }
    try {
      await _repo.deleteEvidence(path);
    } catch (_) {}
  }
}

final openDisputeControllerProvider = NotifierProvider.autoDispose
    .family<OpenDisputeController, OpenDisputeState, OpenDisputeArgs>(
      OpenDisputeController.new,
    );
