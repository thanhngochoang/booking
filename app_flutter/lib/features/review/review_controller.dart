import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photobooking/core/ulid.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/content_providers.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';
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

/// What still blocks the submit button, in the order the screen names it.
enum ReviewBlock { verdict, reason, text }

/// The two blocks of a studio booking's review (#136 Decision 21): the
/// member who shot it and the studio.
enum ReviewSubject { assignee, studio }

@immutable
class ReviewState {
  const ReviewState({
    this.verdict,
    this.hits = 0,
    this.reasons = const {},
    this.text = '',
    this.photos = const [],
    this.postId,
    this.phase = ReviewPhase.idle,
    this.error,
    this.isConflict = false,
    this.submittedShare,
    this.studioVerdict,
    this.studioHits = 0,
    this.studioReasons = const {},
    this.studioText = '',
  });

  /// The side picked on the pad; null exactly when [hits] is 0.
  final Verdict? verdict;
  final int hits;

  /// Reasons ticked on the brick side. Kept when the customer switches to
  /// tomato and back, but only sent with a brick.
  final Set<ReviewReason> reasons;
  final String text;
  final List<SharedPhotoTile> photos;
  final String? postId;
  final ReviewPhase phase;

  /// The last submit failure; the screen maps it to a localized message.
  final Object? error;
  final bool isConflict;

  /// Which submit is running (or ran last): true for "chia sẻ", false for
  /// "chỉ đánh giá"; null before the first submit.
  final bool? submittedShare;

  /// The studio block of a studio booking (same rules as the member block,
  /// its own brick reasons); unused on an individual booking.
  final Verdict? studioVerdict;
  final int studioHits;
  final Set<StudioReviewReason> studioReasons;
  final String studioText;

  static ReviewBlock? _missingOf(Verdict? v, bool noReason, String text) {
    if (v == null) return ReviewBlock.verdict;
    if (v == Verdict.brick && noReason) return ReviewBlock.reason;
    if (text.trim().characters.length < ReviewController.minTextLength ||
        text.characters.length > ReviewController.maxTextLength) {
      return ReviewBlock.text;
    }
    return null;
  }

  /// The first thing still missing, or null when the review can be sent
  /// (the member block of a studio booking).
  ReviewBlock? get missing => _missingOf(verdict, reasons.isEmpty, text);

  /// The same for the studio block.
  ReviewBlock? get studioMissing =>
      _missingOf(studioVerdict, studioReasons.isEmpty, studioText);

  /// On a studio booking, the first block still incomplete (the member's,
  /// then the studio's); null when both can be sent.
  ReviewSubject? get missingSubject => missing != null
      ? ReviewSubject.assignee
      : (studioMissing != null ? ReviewSubject.studio : null);

  bool get canSubmitReviewOnly =>
      missing == null && phase != ReviewPhase.submitting;

  /// "Gửi 2 đánh giá": both blocks complete.
  bool get canSubmitTwo => canSubmitReviewOnly && studioMissing == null;

  bool get canSubmitWithShare => canSubmitReviewOnly && _photosReady;

  bool get canSubmitTwoWithShare => canSubmitTwo && _photosReady;

  bool get _photosReady =>
      photos.isNotEmpty &&
      !photos.any(
        (p) =>
            p.status == SharedPhotoStatus.uploading ||
            p.status == SharedPhotoStatus.failed,
      );

  int get photoCount => photos.length;

  ReviewState copyWith({
    Verdict? verdict,
    bool clearVerdict = false,
    int? hits,
    Set<ReviewReason>? reasons,
    String? text,
    List<SharedPhotoTile>? photos,
    String? postId,
    ReviewPhase? phase,
    Object? error,
    bool? isConflict,
    bool? submittedShare,
    Verdict? studioVerdict,
    bool clearStudioVerdict = false,
    int? studioHits,
    Set<StudioReviewReason>? studioReasons,
    String? studioText,
  }) {
    return ReviewState(
      verdict: clearVerdict ? null : verdict ?? this.verdict,
      hits: hits ?? this.hits,
      reasons: reasons ?? this.reasons,
      text: text ?? this.text,
      photos: photos ?? this.photos,
      postId: postId ?? this.postId,
      phase: phase ?? this.phase,
      error: error,
      isConflict: isConflict ?? this.isConflict,
      submittedShare: submittedShare ?? this.submittedShare,
      studioVerdict: clearStudioVerdict
          ? null
          : studioVerdict ?? this.studioVerdict,
      studioHits: studioHits ?? this.studioHits,
      studioReasons: studioReasons ?? this.studioReasons,
      studioText: studioText ?? this.studioText,
    );
  }
}

class ReviewController extends Notifier<ReviewState> {
  ReviewController(this.bookingId);

  final String bookingId;

  static const int maxPhotos = 10;
  static const int minTextLength = 10;
  static const int maxTextLength = 1000;

  /// Set once a review-only submit succeeded: uploads that are still running
  /// are dropped and their files deleted as they finish.
  bool _discardUploads = false;

  /// True once a share submit succeeded: the files now belong to the post.
  bool _filesAttached = false;

  /// Taken in [build] so cleanup still works after the provider is disposed.
  late MediaUploader _uploader;
  final Set<String> _deletedPaths = {};

  /// Storage paths of finished uploads still attached to a tile (state cannot
  /// be read while the provider is being disposed).
  final Set<String> _livePaths = {};

  @override
  ReviewState build() {
    _uploader = ref.read(mediaUploaderProvider);
    ref.onDispose(() {
      // Leaving the screen: files that were never attached to a post go.
      if (_filesAttached) return;
      for (final path in [..._livePaths]) {
        unawaited(_deleteQuietly(path));
      }
    });
    return const ReviewState();
  }

  /// The pad's change: a side and its hits (1..10), or null and 0 to clear.
  void setVerdict(Verdict? verdict, int hits) {
    if (state.phase == ReviewPhase.submitting) return;
    final cleared = verdict == null || hits <= 0;
    state = state.copyWith(
      verdict: cleared ? null : verdict,
      clearVerdict: cleared,
      hits: cleared ? 0 : hits.clamp(1, kReviewHitsMax),
    );
  }

  /// "Làm lại": drops the side and hits, keeps text and ticked reasons.
  void reset() => setVerdict(null, 0);

  void toggleReason(ReviewReason reason) {
    if (state.phase == ReviewPhase.submitting) return;
    final next = {...state.reasons};
    if (!next.remove(reason)) next.add(reason);
    state = state.copyWith(reasons: next);
  }

  void setText(String val) {
    if (state.phase == ReviewPhase.submitting) return;
    state = state.copyWith(text: val);
  }

  /// The studio block's pad (studio booking only).
  void setStudioVerdict(Verdict? verdict, int hits) {
    if (state.phase == ReviewPhase.submitting) return;
    final cleared = verdict == null || hits <= 0;
    state = state.copyWith(
      studioVerdict: cleared ? null : verdict,
      clearStudioVerdict: cleared,
      studioHits: cleared ? 0 : hits.clamp(1, kReviewHitsMax),
    );
  }

  void toggleStudioReason(StudioReviewReason reason) {
    if (state.phase == ReviewPhase.submitting) return;
    final next = {...state.studioReasons};
    if (!next.remove(reason)) next.add(reason);
    state = state.copyWith(studioReasons: next);
  }

  void setStudioText(String val) {
    if (state.phase == ReviewPhase.submitting) return;
    state = state.copyWith(studioText: val);
  }

  Future<void> pickPhotos() async {
    final room = maxPhotos - state.photos.length;
    if (room <= 0 || state.phase == ReviewPhase.submitting) return;

    final picked = await ref.read(imagePickerProvider).pickImages(max: room);
    if (!ref.mounted || picked.isEmpty) return;

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
      _livePaths.remove(tile.photo!.storagePath);
      unawaited(_deleteQuietly(tile.photo!.storagePath));
    }
  }

  Future<void> _uploadTile(SharedPhotoTile tile, String postId) async {
    final uid =
        ref.read(authRepositoryProvider).currentUser?.uid ??
        ref.read(authStateProvider).value?.uid;
    if (uid == null) {
      // No signed-in user: never upload under a made-up owner.
      _markFailed(tile.key);
      return;
    }
    final storagePath = 'posts/$uid/$postId/${tile.key}.jpg';

    try {
      await for (final event in _uploader.upload(
        tile.local,
        storagePath: storagePath,
        purpose: ImagePurpose.share,
      )) {
        final media = event.media;
        final dropped =
            !ref.mounted ||
            _discardUploads ||
            state.photos.indexWhere((p) => p.key == tile.key) < 0;
        if (media != null) {
          if (dropped) {
            // Discarded, removed or left behind while it uploaded.
            unawaited(_deleteQuietly(media.storagePath));
            continue;
          }
          _livePaths.add(media.storagePath);
          _updateTile(
            tile.key,
            (t) => t.copyWith(
              status: SharedPhotoStatus.done,
              progress: 1.0,
              photo: ReviewPhoto(
                url: media.url,
                storagePath: media.storagePath,
              ),
            ),
          );
        } else if (!dropped) {
          _updateTile(tile.key, (t) => t.copyWith(progress: event.fraction));
        }
      }
    } catch (_) {
      _markFailed(tile.key);
    }
  }

  void _updateTile(
    String key,
    SharedPhotoTile Function(SharedPhotoTile) change,
  ) {
    final idx = state.photos.indexWhere((p) => p.key == key);
    if (idx < 0) return;
    final list = [...state.photos];
    list[idx] = change(list[idx]);
    state = state.copyWith(photos: list);
  }

  void _markFailed(String key) {
    if (!ref.mounted) return;
    final currentIdx = state.photos.indexWhere((p) => p.key == key);
    if (currentIdx >= 0) {
      final list = [...state.photos];
      list[currentIdx] = list[currentIdx].copyWith(
        status: SharedPhotoStatus.failed,
      );
      state = state.copyWith(photos: list);
    }
  }

  /// Brick reasons in the catalogue order; a tomato carries none.
  List<ReviewReason> get _reasons => state.verdict == Verdict.brick
      ? [
          for (final r in ReviewReason.values)
            if (state.reasons.contains(r)) r,
        ]
      : const [];

  /// The studio block as sent: brick reasons in the catalogue order.
  StudioReviewDraft? get _studioDraft {
    final v = state.studioVerdict;
    if (v == null) return null;
    return StudioReviewDraft(
      verdict: v,
      hits: state.studioHits,
      reasons: v == Verdict.brick
          ? [
              for (final r in StudioReviewReason.values)
                if (state.studioReasons.contains(r)) r,
            ]
          : const [],
      text: state.studioText.trim(),
    );
  }

  /// Sends the review; with [studio] (a studio booking) the studio block
  /// goes in the same call and both blocks must be complete.
  Future<bool> submit({required bool share, bool studio = false}) async {
    final verdict = state.verdict;
    if (state.phase == ReviewPhase.submitting || verdict == null) return false;
    final studioDraft = studio ? _studioDraft : null;
    if (studio && (studioDraft == null || state.studioMissing != null)) {
      return false;
    }
    final hits = state.hits;
    final reasons = _reasons;
    state = state.copyWith(
      phase: ReviewPhase.submitting,
      submittedShare: share,
    );

    try {
      if (!share) {
        await ref
            .read(reviewRepositoryProvider)
            .submit(
              bookingId: bookingId,
              verdict: verdict,
              hits: hits,
              reasons: reasons,
              text: state.text.trim(),
              postId: null,
              photos: const [],
              studio: studioDraft,
            );
        _discardSharedFiles();
      } else {
        final photos = state.photos
            .where((p) => p.photo != null)
            .map((p) => p.photo!)
            .toList();
        await ref
            .read(reviewRepositoryProvider)
            .submit(
              bookingId: bookingId,
              verdict: verdict,
              hits: hits,
              reasons: reasons,
              text: state.text.trim(),
              postId: state.postId,
              photos: photos,
              studio: studioDraft,
            );
        _filesAttached = true;
        // The server created the real-shoot post: S09.01 reads it again.
        if (ref.mounted) {
          ref.read(ownPostsChangedProvider.notifier).bump();
        }
      }
      state = state.copyWith(phase: ReviewPhase.done);
      return true;
    } on ReviewException catch (e) {
      if (e.code == ReviewErrorCode.conflict) {
        // Double submit or lost response: treat as success
        // The review already exists, so these files were not attached.
        _discardSharedFiles();
        state = state.copyWith(phase: ReviewPhase.done, isConflict: true);
        return true;
      }
      state = state.copyWith(phase: ReviewPhase.error, error: e);
      return false;
    } catch (e) {
      state = state.copyWith(phase: ReviewPhase.error, error: e);
      return false;
    }
  }

  /// After a successful review-only submit the picked files are not wanted:
  /// delete the finished ones and drop the uploads still running.
  void _discardSharedFiles() {
    _discardUploads = true;
    for (final p in state.photos) {
      if (p.photo != null) {
        unawaited(_deleteQuietly(p.photo!.storagePath));
      }
    }
  }

  Future<void> _deleteQuietly(String path) async {
    if (!_deletedPaths.add(path)) return;
    try {
      await _uploader.delete(path);
    } catch (_) {}
  }
}

final reviewControllerProvider = NotifierProvider.autoDispose
    .family<ReviewController, ReviewState, String>(ReviewController.new);
