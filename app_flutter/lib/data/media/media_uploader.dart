import 'package:flutter/foundation.dart';

import 'package:photobooking/data/media/image_picker_port.dart';

@immutable
class UploadedMedia {
  const UploadedMedia({required this.url, required this.storagePath});

  /// Download URL, stored on the post as `imageUrls[i]`.
  final String url;

  /// Where the object lives; kept so it can be deleted again.
  final String storagePath;
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
  /// Uploads [image] to [storagePath]. Emits progress events and then one done
  /// event; a failure is a stream error.
  Stream<UploadEvent> upload(PickedImage image, {required String storagePath});

  /// Removes an uploaded object. A missing object is not an error.
  Future<void> delete(String storagePath);
}

class FakeMediaUploader implements MediaUploader {
  /// Names of images whose upload fails after a first progress event.
  final Set<String> failNames = {};

  /// Storage paths that currently hold an object.
  final List<String> uploaded = [];
  final List<String> deleted = [];
  int uploadCalls = 0;

  /// The most uploads that were open at the same time.
  int maxConcurrent = 0;
  Object? deleteFailure;
  int _open = 0;

  @override
  Stream<UploadEvent> upload(
    PickedImage image, {
    required String storagePath,
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
