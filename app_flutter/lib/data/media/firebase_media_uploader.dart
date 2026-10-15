import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

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

class FirebaseMediaUploader implements MediaUploader {
  FirebaseMediaUploader({FirebaseStorage? storage, required this.compressor})
    : _storage = storage ?? FirebaseStorage.instance;
  final FirebaseStorage _storage;
  final ImageCompressor compressor;

  @override
  Stream<UploadEvent> upload(
    PickedImage image, {
    required String storagePath,
    required ImagePurpose purpose,
  }) {
    UploadTask? task;
    return uploadCompressed(
      compressor: compressor,
      image: image,
      purpose: purpose,
      storagePath: storagePath,
      put: (localPath, meta, onProgress) async {
        final ref = _storage.ref(storagePath);
        // Streamed from disk: a 10-photo post never holds the photos in memory.
        final t = ref.putFile(
          File(localPath),
          SettableMetadata(
            contentType: meta.contentType,
            cacheControl: purpose.cacheControl,
            customMetadata: meta.custom,
          ),
        );
        task = t;
        var last = 0.0;
        await for (final s in t.snapshotEvents) {
          if (s.totalBytes <= 0) {
            continue;
          }
          final fraction = s.bytesTransferred / s.totalBytes;
          // At most one update per 5 percent, so the screen is not rebuilt for
          // every chunk.
          if (fraction - last >= 0.05 && fraction < 1) {
            last = fraction;
            onProgress(fraction);
          }
        }
        await t; // throws when the upload failed
        return ref.getDownloadURL();
      },
      deleteLocal: (path) async {
        final f = File(path);
        if (f.existsSync()) {
          await f.delete();
        }
      },
      onCancelUpload: () => task?.cancel(),
    );
  }

  @override
  Future<void> delete(String storagePath) async {
    try {
      await _storage.ref(storagePath).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        rethrow;
      }
    }
  }
}

/// Turns a Storage path into a download URL (chat images store the path).
class FirebaseMediaUrlResolver implements MediaUrlResolver {
  FirebaseMediaUrlResolver({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;
  final FirebaseStorage _storage;

  @override
  Future<String> downloadUrl(String storagePath) =>
      _storage.ref(storagePath).getDownloadURL();
}

/// The adapter's flow without Firebase types: compress, upload the compressed
/// file (never the picked one), report the compressed size, and delete the temp
/// file after success, failure and cancel.
///
/// [put] uploads the file at `localPath` with the metadata, reports progress
/// through `onProgress`, and returns the download URL. [onCancelUpload] runs
/// when the listener cancels, to stop an upload still in flight.
@visibleForTesting
Stream<UploadEvent> uploadCompressed({
  required ImageCompressor compressor,
  required PickedImage image,
  required ImagePurpose purpose,
  required String storagePath,
  required Future<String> Function(
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
      final url = await put(
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
        controller.add(
          UploadEvent.done(
            UploadedMedia(
              url: url,
              storagePath: storagePath,
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
