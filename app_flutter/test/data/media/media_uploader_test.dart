import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';

const _img = PickedImage(path: '/tmp/a.jpg', name: 'a.jpg');

void main() {
  test(
    'a successful upload reports progress and ends with one done event',
    () async {
      final up = FakeMediaUploader();
      final events = await up
          .upload(_img, storagePath: 'posts/u1/p1/a.jpg')
          .toList();
      expect(
        events
            .where((e) => !e.isDone)
            .every((e) => e.fraction >= 0 && e.fraction <= 1),
        isTrue,
      );
      expect(events.where((e) => e.isDone), hasLength(1));
      expect(events.last.isDone, isTrue);
      expect(events.last.media!.storagePath, 'posts/u1/p1/a.jpg');
      expect(events.last.media!.url, startsWith('https://'));
      expect(up.uploaded, ['posts/u1/p1/a.jpg']);
      expect(up.uploadCalls, 1);
    },
  );

  test('a failing image gives a stream error after some progress and stores nothing', () async {
    final up = FakeMediaUploader()..failNames.add('a.jpg');
    final seen = <UploadEvent>[];
    await expectLater(
      up.upload(_img, storagePath: 'posts/u1/p1/a.jpg').map((e) {
        seen.add(e);
        return e;
      }).drain<void>(),
      throwsStateError,
    );
    expect(seen, isNotEmpty);
    expect(seen.any((e) => e.isDone), isFalse);
    expect(up.uploaded, isEmpty);
  });

  test('delete removes the object, is idempotent, and is recorded', () async {
    final up = FakeMediaUploader();
    await up.upload(_img, storagePath: 'posts/u1/p1/a.jpg').drain<void>();
    await up.delete('posts/u1/p1/a.jpg');
    await up.delete('posts/u1/p1/a.jpg');
    expect(up.uploaded, isEmpty);
    expect(up.deleted, ['posts/u1/p1/a.jpg', 'posts/u1/p1/a.jpg']);
  });

  test('the fake records the most uploads open at once', () async {
    final up = FakeMediaUploader();
    await up.upload(_img, storagePath: 'a').drain<void>();
    await up.upload(_img, storagePath: 'b').drain<void>();
    expect(up.maxConcurrent, 1);
    await Future.wait([
      up.upload(_img, storagePath: 'c').drain<void>(),
      up.upload(_img, storagePath: 'd').drain<void>(),
    ]);
    expect(up.maxConcurrent, 2);
  });

  test('the Storage adapter streams from disk and throttles progress', () {
    final src = File('lib/data/media/firebase_media_uploader.dart')
        .readAsStringSync();
    expect(src, contains('putFile'));
    expect(src, isNot(contains('putData')));
    expect(src, isNot(contains('readAsBytes')));
    expect(
      src,
      contains('0.05'),
      reason: 'progress in steps of at least 5 percent',
    );
    expect(src, contains("contentType: 'image/jpeg'"));
    expect(src, contains('object-not-found'));
    for (final banned in ['Timer', 'Stream.periodic']) {
      expect(src, isNot(contains(banned)));
    }
  });

  test(
    'firebase_storage is imported only by the Storage adapter and main.dart',
    () {
      final offenders = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where(
            (f) => f.readAsStringSync().contains('package:firebase_storage/'),
          )
          .map((f) => f.path)
          .toList();
      expect(
        offenders,
        unorderedEquals([
          'lib/data/media/firebase_media_uploader.dart',
          'lib/main.dart',
        ]),
      );
    },
  );
}
