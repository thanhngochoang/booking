import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:photobooking/data/media/image_compressor.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/media/upload_flow.dart';

export 'package:photobooking/data/media/upload_flow.dart'
    show SettableMetadataLike, uploadCompressed;

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
            contentType: meta.contentType, // contentType: 'image/jpeg'
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

