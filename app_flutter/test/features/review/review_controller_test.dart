import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/review/review_providers.dart';
import 'package:photobooking/data/review/review_repository.dart';
import 'package:photobooking/features/review/review_controller.dart';

import '../../support/fake_review_repository.dart';

void main() {
  group('ReviewController', () {
    late FakeReviewRepository fakeReviews;
    late FakeMediaUploader fakeUploader;
    late FakeImagePicker fakePicker;
    late FakeAuthRepository fakeAuth;

    ProviderContainer createContainer({FakeImagePicker? picker}) {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuth),
          reviewRepositoryProvider.overrideWithValue(fakeReviews),
          mediaUploaderProvider.overrideWithValue(fakeUploader),
          imagePickerProvider.overrideWithValue(picker ?? fakePicker),
          authStateProvider.overrideWith(
            (ref) => Stream.value(const AuthUser(uid: 'c1')),
          ),
        ],
      );
      final sub = container.listen(reviewControllerProvider('b1'), (_, _) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      fakeReviews = FakeReviewRepository(currentUserId: 'c1');
      fakeUploader = FakeMediaUploader();
      fakePicker = FakeImagePicker();
      fakeAuth = FakeAuthRepository(initialUser: const AuthUser(uid: 'c1'));
    });

    test('submit is disabled without stars or with a short text', () async {
      final container = createContainer();
      await pumpEventQueue();
      final controller = container.read(
        reviewControllerProvider('b1').notifier,
      );

      expect(
        container.read(reviewControllerProvider('b1')).canSubmitReviewOnly,
        isFalse,
      );

      controller.setRating(5);
      expect(
        container.read(reviewControllerProvider('b1')).canSubmitReviewOnly,
        isFalse,
      );

      controller.setText('Ngắn'); // 4 chars < 10
      expect(
        container.read(reviewControllerProvider('b1')).canSubmitReviewOnly,
        isFalse,
      );

      controller.setText('Một nhận xét dài hơn mười ký tự');
      expect(
        container.read(reviewControllerProvider('b1')).canSubmitReviewOnly,
        isTrue,
      );

      controller.setRating(0);
      expect(
        container.read(reviewControllerProvider('b1')).canSubmitReviewOnly,
        isFalse,
      );
    });

    test(
      'picking photos uploads each with progress under posts/{uid}/{postId}/',
      () async {
        final picker = FakeImagePicker([
          const [
            PickedImage(path: '/tmp/1.jpg', name: '1.jpg'),
            PickedImage(path: '/tmp/2.jpg', name: '2.jpg'),
          ],
        ]);

        final container = createContainer(picker: picker);
        await pumpEventQueue();
        final controller = container.read(
          reviewControllerProvider('b1').notifier,
        );

        await controller.pickPhotos();

        final state = container.read(reviewControllerProvider('b1'));
        expect(state.photos, hasLength(2));
        expect(state.postId, isNotNull);

        // Verify each storage path starts with posts/c1/{postId}/
        for (final p in state.photos) {
          expect(p.photo, isNotNull);
          expect(p.photo!.storagePath, startsWith('posts/c1/${state.postId}/'));
          expect(p.status, SharedPhotoStatus.done);
        }
        expect(fakeUploader.uploadCalls, 2);
      },
    );

    test('a failed tile blocks sharing but not review-only', () async {
      fakeUploader.failNames.add('fail.jpg');
      final picker = FakeImagePicker([
        const [PickedImage(path: '/tmp/fail.jpg', name: 'fail.jpg')],
      ]);

      final container = createContainer(picker: picker);
      await pumpEventQueue();
      final controller = container.read(
        reviewControllerProvider('b1').notifier,
      );
      controller.setRating(5);
      controller.setText('Dịch vụ rất tốt và chuyên nghiệp');

      await controller.pickPhotos();

      final state = container.read(reviewControllerProvider('b1'));
      expect(state.photos.first.status, SharedPhotoStatus.failed);
      expect(state.canSubmitWithShare, isFalse);
      expect(state.canSubmitReviewOnly, isTrue);
    });

    test('review-only deletes uploaded files and sends no photos', () async {
      final picker = FakeImagePicker([
        const [PickedImage(path: '/tmp/1.jpg', name: '1.jpg')],
      ]);

      final container = createContainer(picker: picker);
      await pumpEventQueue();
      final controller = container.read(
        reviewControllerProvider('b1').notifier,
      );
      controller.setRating(5);
      controller.setText('Nhận xét không gửi kèm ảnh');

      await controller.pickPhotos();
      expect(fakeUploader.uploaded, hasLength(1));

      final success = await controller.submit(share: false);
      expect(success, isTrue);

      expect(fakeReviews.submitCalls, hasLength(1));
      final call = fakeReviews.submitCalls.first;
      expect(call['photos'], isEmpty);
      expect(call['postId'], isNull);

      // Verify file deleted
      expect(fakeUploader.deleted, hasLength(1));
    });

    test('a failed review-only submit keeps the uploaded files', () async {
      final picker = FakeImagePicker([
        const [PickedImage(path: '/tmp/1.jpg', name: '1.jpg')],
      ]);
      final container = createContainer(picker: picker);
      await pumpEventQueue();
      final controller = container.read(
        reviewControllerProvider('b1').notifier,
      );
      controller.setRating(5);
      controller.setText('Nhận xét không gửi kèm ảnh');
      await controller.pickPhotos();

      fakeReviews.nextError = ReviewErrorCode.network;
      expect(await controller.submit(share: false), isFalse);

      expect(fakeUploader.deleted, isEmpty);
      expect(fakeUploader.uploaded, hasLength(1));
      final state = container.read(reviewControllerProvider('b1'));
      expect(state.photos.single.status, SharedPhotoStatus.done);
      expect(state.error, isNotNull);
    });

    test(
      'review-only treats a conflict as success and deletes the files',
      () async {
        final picker = FakeImagePicker([
          const [PickedImage(path: '/tmp/1.jpg', name: '1.jpg')],
        ]);
        final container = createContainer(picker: picker);
        await pumpEventQueue();
        final controller = container.read(
          reviewControllerProvider('b1').notifier,
        );
        controller.setRating(5);
        controller.setText('Nhận xét không gửi kèm ảnh');
        await controller.pickPhotos();

        fakeReviews.nextError = ReviewErrorCode.conflict;
        expect(await controller.submit(share: false), isTrue);
        expect(fakeUploader.deleted, hasLength(1));
      },
    );

    group('uploads that outlive the listener', () {
      late _ManualUploader manual;

      ProviderContainer manualContainer() {
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            reviewRepositoryProvider.overrideWithValue(fakeReviews),
            mediaUploaderProvider.overrideWithValue(manual),
            imagePickerProvider.overrideWithValue(
              FakeImagePicker([
                const [PickedImage(path: '/tmp/1.jpg', name: '1.jpg')],
              ]),
            ),
            authStateProvider.overrideWith(
              (ref) => Stream.value(const AuthUser(uid: 'c1')),
            ),
          ],
        );
        container.listen(reviewControllerProvider('b1'), (_, _) {});
        addTearDown(container.dispose);
        return container;
      }

      Future<void> startUpload(ProviderContainer container) async {
        final controller = container.read(
          reviewControllerProvider('b1').notifier,
        );
        controller.setRating(5);
        controller.setText('Nhận xét không gửi kèm ảnh');
        unawaited(controller.pickPhotos());
        while (manual.pending.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      setUp(() => manual = _ManualUploader());

      test('review-only with an upload in flight: the file is deleted when it '
          'finishes after the screen is gone', () async {
        final container = manualContainer();
        await pumpEventQueue();
        await startUpload(container);
        final controller = container.read(
          reviewControllerProvider('b1').notifier,
        );
        expect(
          container.read(reviewControllerProvider('b1')).photos.single.status,
          SharedPhotoStatus.uploading,
        );

        expect(await controller.submit(share: false), isTrue);
        container.dispose();

        final path = manual.pending.keys.single;
        manual.finish(path);
        await pumpEventQueue();
        expect(manual.deleted, [path]);
      });

      test('leaving the screen with an upload in flight deletes the file '
          'when it finishes', () async {
        final container = manualContainer();
        await pumpEventQueue();
        await startUpload(container);

        container.dispose();
        final path = manual.pending.keys.single;
        manual.finish(path);
        await pumpEventQueue();
        expect(manual.deleted, [path]);
      });

      test('removing a tile while it uploads deletes the file when it '
          'finishes, and progress after the removal is ignored', () async {
        final container = manualContainer();
        await pumpEventQueue();
        await startUpload(container);
        final controller = container.read(
          reviewControllerProvider('b1').notifier,
        );
        final key = container
            .read(reviewControllerProvider('b1'))
            .photos
            .single
            .key;

        await controller.removePhoto(key);
        final path = manual.pending.keys.single;
        manual.progress(path, 0.5);
        manual.finish(path);
        await pumpEventQueue();

        expect(manual.deleted, [path]);
        expect(container.read(reviewControllerProvider('b1')).photos, isEmpty);
      });

      test('progress events update the tile while it is on screen', () async {
        final container = manualContainer();
        await pumpEventQueue();
        await startUpload(container);
        manual.progress(manual.pending.keys.single, 0.5);
        await pumpEventQueue();
        expect(
          container.read(reviewControllerProvider('b1')).photos.single.progress,
          0.5,
        );
      });
    });

    test(
      'leaving the screen deletes finished files that were not shared',
      () async {
        final picker = FakeImagePicker([
          const [PickedImage(path: '/tmp/1.jpg', name: '1.jpg')],
        ]);
        final container = createContainer(picker: picker);
        await pumpEventQueue();
        await container
            .read(reviewControllerProvider('b1').notifier)
            .pickPhotos();
        expect(fakeUploader.uploaded, hasLength(1));

        container.dispose();
        await pumpEventQueue();
        expect(fakeUploader.deleted, hasLength(1));
      },
    );

    test('files attached by a successful share are kept on leaving', () async {
      final picker = FakeImagePicker([
        const [PickedImage(path: '/tmp/1.jpg', name: '1.jpg')],
      ]);
      final container = createContainer(picker: picker);
      await pumpEventQueue();
      final controller = container.read(
        reviewControllerProvider('b1').notifier,
      );
      controller.setRating(5);
      controller.setText('Nhận xét kèm ảnh chia sẻ');
      await controller.pickPhotos();
      expect(await controller.submit(share: true), isTrue);

      container.dispose();
      await pumpEventQueue();
      expect(fakeUploader.deleted, isEmpty);
    });

    test(
      'a conflict on share means the files were not attached: deleted',
      () async {
        final picker = FakeImagePicker([
          const [PickedImage(path: '/tmp/1.jpg', name: '1.jpg')],
        ]);
        final container = createContainer(picker: picker);
        await pumpEventQueue();
        final controller = container.read(
          reviewControllerProvider('b1').notifier,
        );
        controller.setRating(5);
        controller.setText('Nhận xét kèm ảnh chia sẻ');
        await controller.pickPhotos();

        fakeReviews.nextError = ReviewErrorCode.conflict;
        expect(await controller.submit(share: true), isTrue);
        expect(fakeUploader.deleted, hasLength(1));

        container.dispose();
        await pumpEventQueue();
        expect(fakeUploader.deleted, hasLength(1)); // not deleted twice
      },
    );

    test('the text limits count characters, not UTF-16 units', () async {
      final container = createContainer();
      await pumpEventQueue();
      final controller = container.read(
        reviewControllerProvider('b1').notifier,
      );
      controller.setRating(5);

      // 5 emoji = 10 UTF-16 units but only 5 characters: too short.
      controller.setText('😀😀😀😀😀');
      expect(
        container.read(reviewControllerProvider('b1')).canSubmitReviewOnly,
        isFalse,
      );

      // 1000 emoji = 2000 units but 1000 characters: allowed.
      controller.setText('😀' * 1000);
      expect(
        container.read(reviewControllerProvider('b1')).canSubmitReviewOnly,
        isTrue,
      );
      controller.setText('😀' * 1001);
      expect(
        container.read(reviewControllerProvider('b1')).canSubmitReviewOnly,
        isFalse,
      );
    });

    test(
      'without a signed-in user nothing is uploaded and the tile fails',
      () async {
        fakeAuth = FakeAuthRepository();
        final picker = FakeImagePicker([
          const [PickedImage(path: '/tmp/1.jpg', name: '1.jpg')],
        ]);
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            reviewRepositoryProvider.overrideWithValue(fakeReviews),
            mediaUploaderProvider.overrideWithValue(fakeUploader),
            imagePickerProvider.overrideWithValue(picker),
            authStateProvider.overrideWith((ref) => Stream.value(null)),
          ],
        );
        final sub = container.listen(reviewControllerProvider('b1'), (_, _) {});
        addTearDown(sub.close);
        addTearDown(container.dispose);
        await pumpEventQueue();

        await container
            .read(reviewControllerProvider('b1').notifier)
            .pickPhotos();

        expect(fakeUploader.uploadCalls, 0);
        expect(
          container.read(reviewControllerProvider('b1')).photos.single.status,
          SharedPhotoStatus.failed,
        );
      },
    );

    test('remove deletes that file', () async {
      final picker = FakeImagePicker([
        const [PickedImage(path: '/tmp/1.jpg', name: '1.jpg')],
      ]);

      final container = createContainer(picker: picker);
      await pumpEventQueue();
      final controller = container.read(
        reviewControllerProvider('b1').notifier,
      );

      await controller.pickPhotos();
      final state = container.read(reviewControllerProvider('b1'));
      final key = state.photos.first.key;

      await controller.removePhoto(key);

      expect(container.read(reviewControllerProvider('b1')).photos, isEmpty);
      expect(fakeUploader.deleted, hasLength(1));
    });

    test('at most 10 photos', () async {
      final picker = FakeImagePicker([
        List.generate(
          12,
          (i) => PickedImage(path: '/tmp/$i.jpg', name: '$i.jpg'),
        ),
      ]);

      final container = createContainer(picker: picker);
      await pumpEventQueue();
      final controller = container.read(
        reviewControllerProvider('b1').notifier,
      );

      await controller.pickPhotos();

      final state = container.read(reviewControllerProvider('b1'));
      expect(state.photos, hasLength(10));
    });
  });
}

/// An uploader whose uploads are driven by the test and keep running after the
/// listener is gone, like a real upload task.
class _ManualUploader implements MediaUploader {
  final Map<String, StreamController<UploadEvent>> pending = {};
  final List<String> deleted = [];

  @override
  Stream<UploadEvent> upload(PickedImage image, {required String storagePath}) {
    final controller = StreamController<UploadEvent>();
    pending[storagePath] = controller;
    return controller.stream;
  }

  void progress(String path, double fraction) =>
      pending[path]!.add(UploadEvent.progress(fraction));

  void finish(String path) {
    pending[path]!
      ..add(
        UploadEvent.done(
          UploadedMedia(url: 'https://storage.test/$path', storagePath: path),
        ),
      )
      ..close();
  }

  @override
  Future<void> delete(String storagePath) async => deleted.add(storagePath);
}
