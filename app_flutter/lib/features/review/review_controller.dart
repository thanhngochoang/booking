import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/review/review.dart';
import 'package:photobooking/data/review/review_providers.dart';
import 'package:photobooking/data/review/review_repository.dart';

enum SharedPhotoStatus { uploading, done, failed }

@immutable
class SharedPhotoTile {
  const SharedPhotoTile({
    required this.key,
    required this.local,
    this.status = SharedPhotoStatus.uploading,
    this.progress = 0.0,
    this.photo,
  });

  final String key;
  final PickedImage local;
  final SharedPhotoStatus status;
  final double progress;
  final ReviewPhoto? photo;

  SharedPhotoTile copyWith({
    SharedPhotoStatus? status,
    double? progress,
    ReviewPhoto? photo,
  }) {
    return SharedPhotoTile(
      key: key,
      local: local,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      photo: photo ?? this.photo,
    );
  }
}

enum ReviewPhase { idle, submitting, done, error }

@immutable
class ReviewState {
  const ReviewState({
    this.rating = 0,
    this.text = '',
    this.photos = const [],
    this.postId,
    this.phase = ReviewPhase.idle,
    this.errorMessage,
    this.isConflict = false,
  });

  final int rating;
  final String text;
  final List<SharedPhotoTile> photos;
  final String? postId;
  final ReviewPhase phase;
  final String? errorMessage;
  final bool isConflict;

  bool get canSubmitReviewOnly =>
      rating > 0 &&
      text.trim().length >= 10 &&
      text.length <= 1000 &&
      phase != ReviewPhase.submitting;

  bool get canSubmitWithShare =>
      canSubmitReviewOnly &&
      photos.isNotEmpty &&
      !photos.any(
        (p) =>
            p.status == SharedPhotoStatus.uploading ||
            p.status == SharedPhotoStatus.failed,
      );

  int get photoCount => photos.length;

  ReviewState copyWith({
    int? rating,
    String? text,
    List<SharedPhotoTile>? photos,
    String? postId,
    ReviewPhase? phase,
    String? errorMessage,
    bool? isConflict,
  }) {
    return ReviewState(
      rating: rating ?? this.rating,
      text: text ?? this.text,
      photos: photos ?? this.photos,
      postId: postId ?? this.postId,
      phase: phase ?? this.phase,
      errorMessage: errorMessage,
      isConflict: isConflict ?? this.isConflict,
    );
  }
}

class ReviewController extends Notifier<ReviewState> {
  ReviewController(this.bookingId);

  final String bookingId;

  static const int maxPhotos = 10;
  static const int minTextLength = 10;
  static const int maxTextLength = 1000;

  @override
  ReviewState build() {
    return const ReviewState();
  }

  void setRating(int val) {
    if (state.phase == ReviewPhase.submitting) return;
    state = state.copyWith(rating: val.clamp(0, 5));
  }

  void setText(String val) {
    if (state.phase == ReviewPhase.submitting) return;
    state = state.copyWith(text: val);
  }

  Future<void> pickPhotos() async {
    final room = maxPhotos - state.photos.length;
    if (room <= 0 || state.phase == ReviewPhase.submitting) return;

    final picked = await ref.read(imagePickerProvider).pickImages(max: room);
    if (picked.isEmpty) return;

    final postId = state.postId ?? newUlid();
    final allowed = picked.take(maxPhotos - state.photos.length).toList();
    final newTiles = allowed
        .map(
          (p) => SharedPhotoTile(
            key: newUlid(),
            local: p,
            status: SharedPhotoStatus.uploading,
            progress: 0.0,
          ),
        )
        .toList();

    state = state.copyWith(
      postId: postId,
      photos: [...state.photos, ...newTiles],
    );

    final futures = newTiles.map((t) => _uploadTile(t, postId));
    await Future.wait(futures);
  }

  Future<void> retryPhoto(String key) async {
    final idx = state.photos.indexWhere((p) => p.key == key);
    if (idx < 0) return;
    final tile = state.photos[idx];
    if (tile.status != SharedPhotoStatus.failed) return;

    final updated = tile.copyWith(
      status: SharedPhotoStatus.uploading,
      progress: 0.0,
    );
    final list = [...state.photos];
    list[idx] = updated;
    state = state.copyWith(photos: list);

    await _uploadTile(updated, state.postId ?? newUlid());
  }

  Future<void> removePhoto(String key) async {
    final idx = state.photos.indexWhere((p) => p.key == key);
    if (idx < 0) return;
    final tile = state.photos[idx];
    final list = [...state.photos]..removeAt(idx);
    state = state.copyWith(photos: list);

    if (tile.photo != null) {
      unawaited(_deleteQuietly(tile.photo!.storagePath));
    }
  }

  Future<void> _uploadTile(SharedPhotoTile tile, String postId) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid ??
        ref.read(authStateProvider).value?.uid ??
        'anonymous';
    final storagePath = 'posts/$uid/$postId/${tile.key}.jpg';

    try {
      await for (final event in ref
          .read(mediaUploaderProvider)
          .upload(tile.local, storagePath: storagePath)) {
        if (!ref.mounted) return;
        final currentIdx = state.photos.indexWhere((p) => p.key == tile.key);
        if (currentIdx < 0) {
          // Tile was removed while uploading
          if (event.media != null) {
            unawaited(_deleteQuietly(event.media!.storagePath));
          }
          return;
        }

        if (event.media != null) {
          final media = event.media!;
          final reviewPhoto = ReviewPhoto(
            url: media.url,
            storagePath: media.storagePath,
          );
          final updated = state.photos[currentIdx].copyWith(
            status: SharedPhotoStatus.done,
            progress: 1.0,
            photo: reviewPhoto,
          );
          final list = [...state.photos];
          list[currentIdx] = updated;
          state = state.copyWith(photos: list);
        } else {
          final updated = state.photos[currentIdx].copyWith(
            progress: event.fraction,
          );
          final list = [...state.photos];
          list[currentIdx] = updated;
          state = state.copyWith(photos: list);
        }
      }
    } catch (_) {
      if (!ref.mounted) return;
      final currentIdx = state.photos.indexWhere((p) => p.key == tile.key);
      if (currentIdx >= 0) {
        final updated = state.photos[currentIdx].copyWith(
          status: SharedPhotoStatus.failed,
        );
        final list = [...state.photos];
        list[currentIdx] = updated;
        state = state.copyWith(photos: list);
      }
    }
  }

  Future<bool> submit({required bool share}) async {
    if (state.phase == ReviewPhase.submitting) return false;
    state = state.copyWith(phase: ReviewPhase.submitting, errorMessage: null);

    try {
      if (!share) {
        // Delete uploaded files best-effort
        for (final p in state.photos) {
          if (p.photo != null) {
            unawaited(_deleteQuietly(p.photo!.storagePath));
          }
        }
        await ref.read(reviewRepositoryProvider).submit(
              bookingId: bookingId,
              rating: state.rating,
              text: state.text.trim(),
              postId: null,
              photos: const [],
            );
      } else {
        final photos = state.photos
            .where((p) => p.photo != null)
            .map((p) => p.photo!)
            .toList();
        await ref.read(reviewRepositoryProvider).submit(
              bookingId: bookingId,
              rating: state.rating,
              text: state.text.trim(),
              postId: state.postId,
              photos: photos,
            );
      }
      state = state.copyWith(phase: ReviewPhase.done);
      return true;
    } on ReviewException catch (e) {
      if (e.code == ReviewErrorCode.conflict) {
        // Double submit or lost response: treat as success
        state = state.copyWith(phase: ReviewPhase.done, isConflict: true);
        return true;
      }
      state = state.copyWith(
        phase: ReviewPhase.error,
        errorMessage: e.message ?? e.code.name,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        phase: ReviewPhase.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await ref.read(mediaUploaderProvider).delete(path);
    } catch (_) {}
  }
}

final reviewControllerProvider = NotifierProvider.autoDispose
    .family<ReviewController, ReviewState, String>(
  ReviewController.new,
);
