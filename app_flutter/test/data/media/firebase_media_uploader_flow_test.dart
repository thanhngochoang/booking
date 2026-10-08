import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:photobooking/data/media/firebase_media_uploader.dart';
import 'package:photobooking/data/media/image_compressor.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';

const _picked = PickedImage(
  path: '/picked/a.jpg',
  name: 'a.jpg',
  sizeBytes: 4000000,
);

/// A compressor that answers with a fixed temp file.
class _TempCompressor implements ImageCompressor {
  ImageCompressError? failWith;
  final List<(String, ImagePurpose)> calls = [];

  @override
  Future<CompressedImage> compress(
    PickedImage source,
    ImagePurpose purpose,
  ) async {
    calls.add((source.path, purpose));
    final error = failWith;
    if (error != null) throw ImageCompressException(error);
    return const CompressedImage(
      path: '/tmp/upload_X.jpg',
      width: 1600,
      height: 1067,
      sizeBytes: 281000,
    );
  }
}

class _Harness {
  final compressor = _TempCompressor();
  final putPaths = <String>[];
  final metas = <SettableMetadataLike>[];
  final deleted = <String>[];
  Completer<String>? gate;
  Object? putFailure;
  bool cancelUploadCalled = false;

  Stream<UploadEvent> run({
    ImagePurpose purpose = ImagePurpose.portfolio,
    String storagePath = 'posts/u1/p1/k.jpg',
  }) => uploadCompressed(
    compressor: compressor,
    image: _picked,
    purpose: purpose,
    storagePath: storagePath,
    put: (path, meta, onProgress) async {
      putPaths.add(path);
      metas.add(meta);
      onProgress(0.5);
      final g = gate;
      if (g != null) return g.future;
      final failure = putFailure;
      if (failure != null) throw failure;
      return 'https://storage.test/$storagePath';
    },
    deleteLocal: (path) async => deleted.add(path),
    onCancelUpload: () => cancelUploadCalled = true,
  );
}

void main() {
  test(
    'the adapter uploads the compressor\'s file, never the picked file',
    () async {
      final h = _Harness();
      await h.run().drain<void>();
      expect(h.compressor.calls, [('/picked/a.jpg', ImagePurpose.portfolio)]);
      expect(h.putPaths, ['/tmp/upload_X.jpg']);
      expect(h.putPaths, isNot(contains(_picked.path)));
    },
  );

  test('metadata is image/jpeg with the purpose\'s Cache-Control and customMetadata.purpose', () async {
    for (final purpose in ImagePurpose.values) {
      final h = _Harness();
      await h.run(purpose: purpose).drain<void>();
      expect(h.metas.single.contentType, 'image/jpeg');
      expect(h.metas.single.cacheControl, purpose.cacheControl);
      expect(h.metas.single.custom, {'purpose': purpose.code});
    }
  });

  test('progress is forwarded and done carries width, height and size from the compressor', () async {
    final h = _Harness();
    final events = await h.run().toList();
    expect(events.where((e) => !e.isDone).map((e) => e.fraction), [0.5]);
    final done = events.last.media!;
    expect(done.url, 'https://storage.test/posts/u1/p1/k.jpg');
    expect(done.storagePath, 'posts/u1/p1/k.jpg');
    expect(done.width, 1600);
    expect(done.height, 1067);
    expect(done.sizeBytes, 281000);
    expect(events.where((e) => e.isDone), hasLength(1));
  });

  test('the temp file is deleted after success', () async {
    final h = _Harness();
    await h.run().drain<void>();
    expect(h.deleted, ['/tmp/upload_X.jpg']);
  });

  test('the temp file is deleted after failure', () async {
    final h = _Harness()..putFailure = StateError('network');
    await expectLater(h.run().drain<void>(), throwsStateError);
    expect(h.deleted, ['/tmp/upload_X.jpg']);
  });

  test(
    'the temp file is deleted after cancel, and the upload task is cancelled',
    () async {
      final h = _Harness()..gate = Completer<String>();
      final seen = <UploadEvent>[];
      final sub = h.run().listen(seen.add);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(h.putPaths, ['/tmp/upload_X.jpg'], reason: 'upload is in flight');
      expect(h.deleted, isEmpty);
      await sub.cancel();
      expect(h.deleted, ['/tmp/upload_X.jpg']);
      expect(h.cancelUploadCalled, isTrue);
      // The put finishing later changes nothing.
      h.gate!.complete('https://late');
      await Future<void>.delayed(Duration.zero);
      expect(seen.any((e) => e.isDone), isFalse);
      expect(h.deleted, ['/tmp/upload_X.jpg'], reason: 'deleted exactly once');
    },
  );

  test('a compressor failure is a stream error with ImageCompressException and uploads nothing', () async {
    final h = _Harness();
    h.compressor.failWith = ImageCompressError.unreadable;
    await expectLater(
      h.run(),
      emitsError(
        isA<ImageCompressException>().having(
          (e) => e.code,
          'code',
          ImageCompressError.unreadable,
        ),
      ),
    );
    expect(h.putPaths, isEmpty);
    expect(h.deleted, isEmpty, reason: 'there is no temp file');
  });
}
