// lib/features/create_post/post_composer.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/content/post_publisher.dart';
import 'package:photobooking/data/content/post_summary.dart';
import 'package:photobooking/data/content/service_summary.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/features/create_post/create_post_providers.dart';
import 'package:photobooking/features/settings/theme_mode_controller.dart';

enum ComposerImageStatus { local, uploading, uploaded, failed }

@immutable
class ComposerImage {
  const ComposerImage({
    required this.key,
    required this.picked,
    this.status = ComposerImageStatus.local,
    this.progress = 0,
    this.media,
  });

  /// Stable id inside the form; also the file name in Storage.
  final String key;
  final PickedImage picked;
  final ComposerImageStatus status;
  final double progress;
  final UploadedMedia? media;

  ComposerImage copyWith({
    ComposerImageStatus? status,
    double? progress,
    UploadedMedia? media,
  }) => ComposerImage(
    key: key,
    picked: picked,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    media: media ?? this.media,
  );
}

@immutable
class ComposerState {
  const ComposerState({
    required this.draftId,
    this.images = const [],
    this.caption = '',
    this.serviceId,
    this.specialtyId,
    this.locationName,
    this.styleId,
    this.inPortfolio = true,
    this.publishing = false,
  });

  /// The id the post will have (a ULID), fixed for the life of the form so a
  /// retried publish overwrites instead of duplicating.
  final String draftId;
  final List<ComposerImage> images;
  final String caption;
  final String? serviceId;
  final String? specialtyId;
  final String? locationName;
  final String? styleId;
  final bool inPortfolio;
  final bool publishing;

  bool get canPublish =>
      images.isNotEmpty &&
      serviceId != null &&
      !publishing &&
      caption.length <= PostComposerController.maxCaption;

  ComposerState copyWith({
    List<ComposerImage>? images,
    String? caption,
    bool? inPortfolio,
    bool? publishing,
  }) => ComposerState(
    draftId: draftId,
    images: images ?? this.images,
    caption: caption ?? this.caption,
    serviceId: serviceId,
    specialtyId: specialtyId,
    locationName: locationName,
    styleId: styleId,
    inPortfolio: inPortfolio ?? this.inPortfolio,
    publishing: publishing ?? this.publishing,
  );

  ComposerState withService(String? id, String? specialty) => ComposerState(
    draftId: draftId,
    images: images,
    caption: caption,
    serviceId: id,
    specialtyId: specialty,
    locationName: locationName,
    styleId: styleId,
    inPortfolio: inPortfolio,
    publishing: publishing,
  );

  ComposerState withLocation(String? v) => ComposerState(
    draftId: draftId,
    images: images,
    caption: caption,
    serviceId: serviceId,
    specialtyId: specialtyId,
    locationName: v,
    styleId: styleId,
    inPortfolio: inPortfolio,
    publishing: publishing,
  );

  ComposerState withStyle(String? v) => ComposerState(
    draftId: draftId,
    images: images,
    caption: caption,
    serviceId: serviceId,
    specialtyId: specialtyId,
    locationName: locationName,
    styleId: v,
    inPortfolio: inPortfolio,
    publishing: publishing,
  );
}

enum PublishOutcome { published, imageFailed, publishFailed, notReady }

@immutable
class PostPublishResult {
  const PostPublishResult(this.outcome, [this.postId]);
  final PublishOutcome outcome;
  final String? postId;
}

class PostComposerController extends Notifier<ComposerState> {
  static const maxImages = 10;
  static const maxCaption = 2000;

  final _busy = <String>{};

  String? get _uid => ref.read(authRepositoryProvider).currentUser?.uid;
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);
  String _draftKey(String uid) => 'postDraft:$uid';

  @override
  ComposerState build() {
    final uid = _uid;
    return (uid == null ? null : _restore(uid)) ??
        ComposerState(draftId: newUlid());
  }

  ComposerState? _restore(String uid) {
    final raw = _prefs.getString(_draftKey(uid));
    if (raw == null) {
      return null;
    }
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return ComposerState(
        draftId: newUlid(),
        caption: (m['caption'] as String?) ?? '',
        serviceId: m['serviceId'] as String?,
        specialtyId: m['specialtyId'] as String?,
        locationName: m['locationName'] as String?,
        styleId: m['styleId'] as String?,
        inPortfolio: m['inPortfolio'] as bool? ?? true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Text fields only: the picker's temporary photo files may be gone by the
  /// next session, so photos are not part of the draft.
  void _persist() {
    final uid = _uid;
    if (uid == null) {
      return;
    }
    final s = state;
    final empty =
        s.caption.isEmpty &&
        s.serviceId == null &&
        s.locationName == null &&
        s.styleId == null;
    if (empty) {
      unawaited(_prefs.remove(_draftKey(uid)));
      return;
    }
    unawaited(
      _prefs.setString(
        _draftKey(uid),
        jsonEncode({
          'caption': s.caption,
          'serviceId': s.serviceId,
          'specialtyId': s.specialtyId,
          'locationName': s.locationName,
          'styleId': s.styleId,
          'inPortfolio': s.inPortfolio,
        }),
      ),
    );
  }

  Future<void> pickImages() async {
    final room = maxImages - state.images.length;
    if (room <= 0 || state.publishing) {
      return;
    }
    final picked = await ref.read(imagePickerProvider).pickImages(max: room);
    if (!ref.mounted || picked.isEmpty) {
      return;
    }
    state = state.copyWith(
      images: [
        ...state.images,
        for (final p in picked.take(room))
          ComposerImage(key: newUlid(), picked: p),
      ],
    );
  }

  void removeImage(String key) {
    if (state.publishing) {
      return;
    }
    final i = state.images.indexWhere((e) => e.key == key);
    if (i < 0) {
      return;
    }
    final media = state.images[i].media;
    state = state.copyWith(images: [...state.images]..removeAt(i));
    if (media != null) {
      unawaited(_deleteQuietly(media.storagePath));
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await ref.read(mediaUploaderProvider).delete(path);
    } catch (_) {
      // An object we could not delete stays behind; nothing else depends on it.
    }
  }

  void moveImage(String key, int delta) {
    if (state.publishing) {
      return;
    }
    final list = [...state.images];
    final from = list.indexWhere((e) => e.key == key);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= list.length) {
      return;
    }
    list.insert(to, list.removeAt(from));
    state = state.copyWith(images: list);
  }

  void setCaption(String v) {
    state = state.copyWith(caption: v);
    _persist();
  }

  void setService(ServiceSummary? s) {
    state = state.withService(s?.id, s?.specialtyId);
    _persist();
  }

  void setLocation(String? v) {
    final t = v?.trim();
    state = state.withLocation(t == null || t.isEmpty ? null : t);
    _persist();
  }

  void setStyle(String? id) {
    state = state.withStyle(id);
    _persist();
  }

  void setInPortfolio(bool v) {
    state = state.copyWith(inPortfolio: v);
    _persist();
  }

  ComposerImage? _image(String key) {
    for (final i in state.images) {
      if (i.key == key) {
        return i;
      }
    }
    return null;
  }

  void _update(String key, ComposerImage Function(ComposerImage) f) {
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      images: [for (final i in state.images) i.key == key ? f(i) : i],
    );
  }

  Future<bool> _upload(String key, String uid) async {
    final img = _image(key);
    if (img == null) {
      return false;
    }
    _update(
      key,
      (i) => i.copyWith(status: ComposerImageStatus.uploading, progress: 0),
    );
    final path = 'posts/$uid/${state.draftId}/$key.jpg';
    try {
      await for (final e
          in ref
              .read(mediaUploaderProvider)
              .upload(img.picked, storagePath: path)) {
        final media = e.media;
        if (media != null) {
          _update(
            key,
            (i) => i.copyWith(
              status: ComposerImageStatus.uploaded,
              progress: 1,
              media: media,
            ),
          );
        } else {
          _update(key, (i) => i.copyWith(progress: e.fraction));
        }
      }
      return _image(key)?.status == ComposerImageStatus.uploaded;
    } catch (_) {
      _update(key, (i) => i.copyWith(status: ComposerImageStatus.failed));
      return false;
    }
  }

  /// Uploads one photo again (the "thử lại" on a failed tile).
  Future<void> retryImage(String key) async {
    final uid = _uid;
    final img = _image(key);
    if (uid == null || img == null || state.publishing || !_busy.add(key)) {
      return;
    }
    try {
      await _upload(key, uid);
    } finally {
      _busy.remove(key);
    }
  }

  Future<PostPublishResult> publish() async {
    final uid = _uid;
    if (uid == null || !state.canPublish) {
      return const PostPublishResult(PublishOutcome.notReady);
    }
    state = state.copyWith(publishing: true);
    for (final key in [for (final i in state.images) i.key]) {
      final img = _image(key);
      if (img == null || img.status == ComposerImageStatus.uploaded) {
        continue;
      }
      if (!await _upload(key, uid)) {
        if (ref.mounted) {
          state = state.copyWith(publishing: false);
        }
        return const PostPublishResult(PublishOutcome.imageFailed);
      }
    }
    if (!ref.mounted) {
      return const PostPublishResult(PublishOutcome.notReady);
    }
    final s = state;
    try {
      final post = await ref
          .read(postPublisherProvider)
          .publish(
            PostDraft(
              id: s.draftId,
              photographerId: uid,
              serviceId: s.serviceId!,
              specialtyId: s.specialtyId,
              images: [for (final i in s.images) PostImage(url: i.media!.url)],
              caption: s.caption.trim(),
              locationName: s.locationName,
              styleId: s.styleId,
              inPortfolio: s.inPortfolio,
            ),
          );
      await _prefs.remove(_draftKey(uid));
      if (ref.mounted) {
        state = ComposerState(draftId: newUlid(), inPortfolio: s.inPortfolio);
      }
      return PostPublishResult(PublishOutcome.published, post.id);
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(publishing: false);
      }
      return const PostPublishResult(PublishOutcome.publishFailed);
    }
  }
}

/// Kept while the app runs, so the form survives switching tabs.
final postComposerProvider =
    NotifierProvider<PostComposerController, ComposerState>(
      PostComposerController.new,
    );
