import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';

class FirebaseMediaUploader implements MediaUploader {
  FirebaseMediaUploader({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;
  final FirebaseStorage _storage;

  @override
  Stream<UploadEvent> upload(
    PickedImage image, {
    required String storagePath,
  }) async* {
    final ref = _storage.ref(storagePath);
    // Streamed from disk: a 10-photo post never holds the photos in memory.
    final task = ref.putFile(
      File(image.path),
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      ),
    );
    var last = 0.0;
    await for (final s in task.snapshotEvents) {
      if (s.totalBytes <= 0) {
        continue;
      }
      final fraction = s.bytesTransferred / s.totalBytes;
      // At most one update per 5 percent, so the screen is not rebuilt for
      // every chunk.
      if (fraction - last >= 0.05 && fraction < 1) {
        last = fraction;
        yield UploadEvent.progress(fraction);
      }
    }
    await task; // throws when the upload failed
    yield UploadEvent.done(
      UploadedMedia(url: await ref.getDownloadURL(), storagePath: storagePath),
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
