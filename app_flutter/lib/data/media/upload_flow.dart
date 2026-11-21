import 'dart:async';

import 'package:photobooking/data/media/image_compressor.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';

/// Object metadata the adapter sets, without `firebase_storage` types so the
/// flow can be tested.
typedef SettableMetadataLike = ({
  String contentType,
  String cacheControl,
  Map<String, String> custom,
});

/// Return type of [put] in [uploadCompressed] when an uploader provides
/// additional metadata like a Phase 2 file ID.
class UploadPutResult {
  const UploadPutResult({
    required this.url,
    this.storagePath,
    this.fileId,
  });

  final String url;
  final String? storagePath;
  final String? fileId;
}

/// The adapter's flow: compress, upload the compressed
/// file (never the picked one), report the compressed size, and delete the temp
/// file after success, failure and cancel.
///
/// [put] uploads the file at `localPath` with the metadata, reports progress
/// through `onProgress`, and returns the download URL (as [String],
/// [UploadPutResult], or a record). [onCancelUpload] runs when the listener
/// cancels, to stop an upload still in flight.
Stream<UploadEvent> uploadCompressed({
  required ImageCompressor compressor,
  required PickedImage image,
  required ImagePurpose purpose,
  required String storagePath,
  required Future<Object?> Function(
    String localPath,
    SettableMetadataLike meta,
    void Function(double fraction) onProgress,
  )
  put,
  required Future<void> Function(String path) deleteLocal,
  void Function()? onCancelUpload,
}) {
  late final StreamController<UploadEvent> controller;
  var cancelled = false;
  String? tempPath;

  Future<void> cleanup() async {
    final path = tempPath;
    tempPath = null;
    if (path == null) {
      return;
    }
    try {
      await deleteLocal(path);
    } on Object {
      // A leftover cache file is not worth failing the upload for.
    }
  }

  Future<void> run() async {
    try {
      final compressed = await compressor.compress(image, purpose);
      tempPath = compressed.path;
      if (cancelled) {
        return;
      }
      final result = await put(
        compressed.path,
        (
          contentType: 'image/jpeg',
          cacheControl: purpose.cacheControl,
          custom: {'purpose': purpose.code},
        ),
        (fraction) {
          if (!cancelled) {
            controller.add(UploadEvent.progress(fraction));
          }
        },
      );
      if (!cancelled) {
        final (url, effectivePath, fileId) = switch (result) {
          final UploadPutResult r => (
            r.url,
            r.storagePath ?? r.fileId ?? storagePath,
            r.fileId,
          ),
          final String u => (u, storagePath, null),
          _ => throw StateError('Unexpected put result: $result'),
        };

        controller.add(
          UploadEvent.done(
            UploadedMedia(
              url: url,
              storagePath: effectivePath,
              fileId: fileId,
              width: compressed.width,
              height: compressed.height,
              sizeBytes: compressed.sizeBytes,
            ),
          ),
        );
      }
    } on Object catch (e, st) {
      if (!cancelled) {
        controller.addError(e, st);
      }
    } finally {
      await cleanup();
      if (!cancelled) {
        await controller.close();
      }
    }
  }

  controller = StreamController<UploadEvent>(
    onListen: () => unawaited(run()),
    onCancel: () async {
      cancelled = true;
      onCancelUpload?.call();
      await cleanup();
    },
  );
  return controller.stream;
}
