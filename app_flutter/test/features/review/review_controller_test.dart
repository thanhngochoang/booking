import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/review/review_providers.dart';
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
      final controller =
          container.read(reviewControllerProvider('b1').notifier);

      expect(container.read(reviewControllerProvider('b1')).canSubmitReviewOnly,
          isFalse);

      controller.setRating(5);
      expect(container.read(reviewControllerProvider('b1')).canSubmitReviewOnly,
          isFalse);

      controller.setText('Ngắn'); // 4 chars < 10
      expect(container.read(reviewControllerProvider('b1')).canSubmitReviewOnly,
          isFalse);

      controller.setText('Một nhận xét dài hơn mười ký tự');
      expect(container.read(reviewControllerProvider('b1')).canSubmitReviewOnly,
          isTrue);

      controller.setRating(0);
      expect(container.read(reviewControllerProvider('b1')).canSubmitReviewOnly,
          isFalse);
    });

    test('picking photos uploads each with progress under posts/{uid}/{postId}/',
        () async {
      final picker = FakeImagePicker([
        const [
          PickedImage(path: '/tmp/1.jpg', name: '1.jpg'),
          PickedImage(path: '/tmp/2.jpg', name: '2.jpg'),
        ],
      ]);

      final container = createContainer(picker: picker);
      await pumpEventQueue();
      final controller =
          container.read(reviewControllerProvider('b1').notifier);

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
    });

    test('a failed tile blocks sharing but not review-only', () async {
      fakeUploader.failNames.add('fail.jpg');
      final picker = FakeImagePicker([
        const [
          PickedImage(path: '/tmp/fail.jpg', name: 'fail.jpg'),
        ],
      ]);

      final container = createContainer(picker: picker);
      await pumpEventQueue();
      final controller =
          container.read(reviewControllerProvider('b1').notifier);
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
        const [
          PickedImage(path: '/tmp/1.jpg', name: '1.jpg'),
        ],
      ]);

      final container = createContainer(picker: picker);
      await pumpEventQueue();
      final controller =
          container.read(reviewControllerProvider('b1').notifier);
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

    test('remove deletes that file', () async {
      final picker = FakeImagePicker([
        const [
          PickedImage(path: '/tmp/1.jpg', name: '1.jpg'),
        ],
      ]);

      final container = createContainer(picker: picker);
      await pumpEventQueue();
      final controller =
          container.read(reviewControllerProvider('b1').notifier);

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
      final controller =
          container.read(reviewControllerProvider('b1').notifier);

      await controller.pickPhotos();

      final state = container.read(reviewControllerProvider('b1'));
      expect(state.photos, hasLength(10));
    });
  });
}
