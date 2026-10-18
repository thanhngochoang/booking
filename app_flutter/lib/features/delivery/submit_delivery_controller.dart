import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/delivery/delivery.dart';
import 'package:photobooking/data/delivery/delivery_providers.dart';
import 'package:photobooking/data/delivery/delivery_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';

enum SampleTilePhase { uploading, processing, ready, failed }

@immutable
class SampleTileState {
  const SampleTileState({
    required this.fileId,
    required this.local,
    required this.phase,
    this.progress = 0.0,
    this.thumbPath,
  });

  final String fileId;
  final PickedImage local;
  final SampleTilePhase phase;
  final double progress;
  final String? thumbPath;

  SampleTileState copyWith({
    SampleTilePhase? phase,
    double? progress,
    String? thumbPath,
  }) {
    return SampleTileState(
      fileId: fileId,
      local: local,
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      thumbPath: thumbPath ?? this.thumbPath,
    );
  }
}

enum SubmitBlock {
  needSamples,
  tooManySamples,
  waitProcessing,
  invalidLink,
  invalidCount,
}

@immutable
class SubmitDeliveryState {
  const SubmitDeliveryState({
    this.tiles = const [],
    this.link = '',
    this.count = '',
    this.note = '',
    this.submitting = false,
    this.error,
  });

  final List<SampleTileState> tiles;
  final String link;
  final String count;
  final String note;
  final bool submitting;
  final Object? error;

  String? get linkError {
    if (link.trim().isEmpty) return null;
    final trimmed = link.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'invalid_link';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasAuthority ||
        !uri.host.contains('.') ||
        trimmed.contains(' ')) {
      return 'invalid_link';
    }
    return null;
  }

  String? get countError {
    if (count.trim().isEmpty) return null;
    final parsed = int.tryParse(count.trim());
    if (parsed == null || parsed <= 0) {
      return 'invalid_count';
    }
    return null;
  }

  SubmitBlock? get blocked {
    final readyCount =
        tiles.where((t) => t.phase == SampleTilePhase.ready).length;
    final hasProcessing = tiles.any(
      (t) =>
          t.phase == SampleTilePhase.uploading ||
          t.phase == SampleTilePhase.processing,
    );

    if (tiles.length < 3) {
      return SubmitBlock.needSamples;
    }
    if (tiles.length > 20) {
      return SubmitBlock.tooManySamples;
    }
    if (hasProcessing) {
      return SubmitBlock.waitProcessing;
    }
    if (readyCount < 3) {
      return SubmitBlock.needSamples;
    }
    if (link.trim().isEmpty || linkError != null) {
      return SubmitBlock.invalidLink;
    }
    if (count.trim().isEmpty || countError != null) {
      return SubmitBlock.invalidCount;
    }
    return null;
  }

  SubmitDeliveryState copyWith({
    List<SampleTileState>? tiles,
    String? link,
    String? count,
    String? note,
    bool? submitting,
    Object? error,
  }) {
    return SubmitDeliveryState(
      tiles: tiles ?? this.tiles,
      link: link ?? this.link,
      count: count ?? this.count,
      note: note ?? this.note,
      submitting: submitting ?? this.submitting,
      error: error,
    );
  }
}

class SubmitDeliveryController
    extends Notifier<SubmitDeliveryState> {
  SubmitDeliveryController(this.booking);

  final Booking booking;

  final Map<String, StreamSubscription> _uploadSubs = {};
  StreamSubscription<List<StagedSample>>? _stagedSub;

  @override
  SubmitDeliveryState build() {
    _initStagedListener();
    ref.onDispose(() {
      for (final s in _uploadSubs.values) {
        s.cancel();
      }
      _uploadSubs.clear();
      _stagedSub?.cancel();
    });
    return const SubmitDeliveryState();
  }

  void _initStagedListener() {
    _stagedSub = ref
        .read(deliveryRepositoryProvider)
        .watchStagedSamples(booking.id)
        .listen(_onStagedSamplesUpdated);
  }

  void _onStagedSamplesUpdated(List<StagedSample> samples) {
    final sampleMap = {for (final s in samples) s.fileId: s};
    final newTiles = <SampleTileState>[];
    var changed = false;

    for (final tile in state.tiles) {
      final staged = sampleMap[tile.fileId];
      if (staged == null) {
        newTiles.add(tile);
        continue;
      }
      if (staged.status == SampleStatus.ready) {
        if (tile.phase != SampleTilePhase.ready ||
            tile.thumbPath != staged.thumbPath) {
          changed = true;
          newTiles.add(
            tile.copyWith(
              phase: SampleTilePhase.ready,
              thumbPath: staged.thumbPath,
            ),
          );
        } else {
          newTiles.add(tile);
        }
      } else if (staged.status == SampleStatus.failed) {
        if (tile.phase != SampleTilePhase.failed) {
          changed = true;
          newTiles.add(tile.copyWith(phase: SampleTilePhase.failed));
        } else {
          newTiles.add(tile);
        }
      } else {
        newTiles.add(tile);
      }
    }

    if (changed) {
      state = state.copyWith(tiles: newTiles);
    }
  }

  Future<void> pickPhotos() async {
    final picker = ref.read(imagePickerProvider);
    final remainingSlots = 20 - state.tiles.length;
    if (remainingSlots <= 0) return;

    final picked = await picker.pickImages(max: remainingSlots);
    if (picked.isEmpty) return;

    final uid = ref.read(authStateProvider).value?.uid ?? booking.photographerId;
    final repo = ref.read(deliveryRepositoryProvider);

    final newTiles = List<SampleTileState>.from(state.tiles);

    for (final img in picked) {
      final fileId = newUlid();
      final tile = SampleTileState(
        fileId: fileId,
        local: img,
        phase: SampleTilePhase.uploading,
      );
      newTiles.add(tile);
      _startUpload(repo: repo, uid: uid, fileId: fileId, img: img);
    }

    state = state.copyWith(tiles: newTiles);
  }

  void _startUpload({
    required DeliveryRepository repo,
    required String uid,
    required String fileId,
    required PickedImage img,
  }) {
    _uploadSubs[fileId]?.cancel();
    _uploadSubs[fileId] = repo
        .uploadSample(
          bookingId: booking.id,
          uploaderId: uid,
          fileId: fileId,
          image: img,
        )
        .listen(
          (event) {
            if (event.isDone) {
              _updateTile(
                fileId,
                (t) => t.copyWith(
                  phase: SampleTilePhase.processing,
                  progress: 1.0,
                ),
              );
            } else {
              _updateTile(
                fileId,
                (t) => t.copyWith(
                  phase: SampleTilePhase.uploading,
                  progress: event.fraction,
                ),
              );
            }
          },
          onError: (_) {
            _updateTile(
              fileId,
              (t) => t.copyWith(phase: SampleTilePhase.failed),
            );
          },
        );
  }

  void retryTile(String fileId) {
    final idx = state.tiles.indexWhere((t) => t.fileId == fileId);
    if (idx == -1) return;
    final oldTile = state.tiles[idx];
    final uid = ref.read(authStateProvider).value?.uid ?? booking.photographerId;
    final repo = ref.read(deliveryRepositoryProvider);

    _uploadSubs[fileId]?.cancel();
    _uploadSubs.remove(fileId);

    final newFileId = newUlid();
    final newTile = SampleTileState(
      fileId: newFileId,
      local: oldTile.local,
      phase: SampleTilePhase.uploading,
    );

    final newTiles = List<SampleTileState>.from(state.tiles);
    newTiles[idx] = newTile;
    state = state.copyWith(tiles: newTiles);

    _startUpload(repo: repo, uid: uid, fileId: newFileId, img: oldTile.local);
  }

  void removeTile(String fileId) {
    _uploadSubs[fileId]?.cancel();
    _uploadSubs.remove(fileId);

    final uid = ref.read(authStateProvider).value?.uid ?? booking.photographerId;
    final repo = ref.read(deliveryRepositoryProvider);
    unawaited(
      repo.discardSample(
        bookingId: booking.id,
        uploaderId: uid,
        fileId: fileId,
      ),
    );

    final newTiles = state.tiles.where((t) => t.fileId != fileId).toList();
    state = state.copyWith(tiles: newTiles);
  }

  void _updateTile(
    String fileId,
    SampleTileState Function(SampleTileState) update,
  ) {
    final newTiles = [
      for (final t in state.tiles)
        if (t.fileId == fileId) update(t) else t,
    ];
    state = state.copyWith(tiles: newTiles);
  }

  void setLink(String link) {
    state = state.copyWith(link: link);
  }

  void setCount(String count) {
    state = state.copyWith(count: count);
  }

  void setNote(String note) {
    state = state.copyWith(note: note);
  }

  Future<int?> submit() async {
    if (state.blocked != null || state.submitting) return null;
    state = state.copyWith(submitting: true, error: null);

    final readyIds = [
      for (final t in state.tiles)
        if (t.phase == SampleTilePhase.ready) t.fileId,
    ];

    final photoCount = int.parse(state.count.trim());
    final link = state.link.trim();
    final note = state.note.trim().isEmpty ? null : state.note.trim();

    try {
      final round = await ref.read(deliveryRepositoryProvider).submit(
            bookingId: booking.id,
            sampleIds: readyIds,
            link: link,
            photoCount: photoCount,
            note: note,
          );
      state = state.copyWith(submitting: false);
      return round;
    } catch (e) {
      state = state.copyWith(submitting: false, error: e);
      return null;
    }
  }
}

final submitDeliveryControllerProvider = NotifierProvider.autoDispose
    .family<SubmitDeliveryController, SubmitDeliveryState, Booking>(
  SubmitDeliveryController.new,
);
