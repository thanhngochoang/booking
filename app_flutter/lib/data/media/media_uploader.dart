import 'package:flutter/foundation.dart';

import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';

@immutable
class UploadedMedia {
  const UploadedMedia({
    required this.url,
    required this.storagePath,
    this.width,
    this.height,
    this.sizeBytes,
  });

  /// Download URL, stored on the post as `imageUrls[i]`.
  final String url;

  /// Where the object lives; kept so it can be deleted again.
  final String storagePath;

  /// Pixel size and byte size of the uploaded (compressed) file; null when the
  /// uploader did not measure it.
  final int? width;
  final int? height;
  final int? sizeBytes;
}

@immutable
class UploadEvent {
  const UploadEvent.progress(this.fraction) : media = null;
  const UploadEvent.done(UploadedMedia this.media) : fraction = 1;

  final double fraction;
  final UploadedMedia? media;
  bool get isDone => media != null;
}

abstract class MediaUploader {
  /// Uploads [image] to [storagePath]. The photo is resized and re-encoded as a
  /// JPEG for [purpose] and stripped of its metadata (EXIF, GPS) first, so a
  /// caller never compresses itself. Emits progress events and then one done
  /// event; a failure is a stream error.
  Stream<UploadEvent> upload(
    PickedImage image, {
    required String storagePath,
    required ImagePurpose purpose,
  });

  /// Removes an uploaded object. A missing object is not an error.
  Future<void> delete(String storagePath);
}

/// Turns the storage path of an uploaded object into a URL to show it from
/// (chat images store the path, not a URL).
abstract class MediaUrlResolver {
  Future<String> downloadUrl(String storagePath);
}

class FakeMediaUrlResolver implements MediaUrlResolver {
  @override
  Future<String> downloadUrl(String storagePath) async =>
      'https://storage.test/$storagePath';
}

class FakeMediaUploader implements MediaUploader {
  /// Names of images whose upload fails after a first progress event.
  final Set<String> failNames = {};

  /// Storage paths that currently hold an object.
  final List<String> uploaded = [];
  final List<String> deleted = [];

  /// Storage path -> the purpose it was uploaded with.
  final Map<String, ImagePurpose> purposes = {};
  int uploadCalls = 0;

  /// The most uploads that were open at the same time.
  int maxConcurrent = 0;
  Object? deleteFailure;
  int _open = 0;

  @override
  Stream<UploadEvent> upload(
    PickedImage image, {
    required String storagePath,
    required ImagePurpose purpose,
  }) async* {
    uploadCalls++;
    _open++;
    if (_open > maxConcurrent) {
      maxConcurrent = _open;
    }
    try {
      yield const UploadEvent.progress(0.2);
      await Future<void>.delayed(Duration.zero);
      if (failNames.contains(image.name)) {
        throw StateError('upload failed: ${image.name}');
      }
      yield const UploadEvent.progress(0.6);
      await Future<void>.delayed(Duration.zero);
      uploaded.add(storagePath);
      purposes[storagePath] = purpose;
      yield UploadEvent.done(
        UploadedMedia(
          url: 'https://storage.test/$storagePath',
          storagePath: storagePath,
        ),
      );
    } finally {
      _open--;
    }
  }

  @override
  Future<void> delete(String storagePath) async {
    if (deleteFailure != null) {
      throw deleteFailure!;
    }
    deleted.add(storagePath);
    uploaded.remove(storagePath);
  }
}
