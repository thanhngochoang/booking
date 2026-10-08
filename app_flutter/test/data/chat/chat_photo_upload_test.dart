import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/chat/chat_photo_upload.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';

class _FailingUploader extends FakeMediaUploader {
  _FailingUploader(this.error);

  final Object error;

  @override
  Stream<UploadEvent> upload(
    PickedImage image, {
    required String storagePath,
    required ImagePurpose purpose,
  }) async* {
    yield const UploadEvent.progress(0.1);
    throw error;
  }
}

void main() {
  const image = PickedImage(path: '/tmp/a.heic', name: 'a.heic');

  test(
    'uploads with the chat purpose and finishes on the done event',
    () async {
      final uploader = FakeMediaUploader();

      await uploadChatPhoto(uploader, image, 'chats/c1/u1/m1.jpg');

      expect(uploader.purposes, {'chats/c1/u1/m1.jpg': ImagePurpose.chat});
    },
  );

  test('a failure is a ChatException: unauthorized → permissionDenied, other Firebase → network, else unknown', () async {
    Future<ChatErrorCode> codeOf(Object error) async {
      try {
        await uploadChatPhoto(
          _FailingUploader(error),
          image,
          'chats/c1/u1/m1.jpg',
        );
      } on ChatException catch (e) {
        return e.code;
      }
      fail('no ChatException for $error');
    }

    expect(
      await codeOf(
        FirebaseException(plugin: 'firebase_storage', code: 'unauthorized'),
      ),
      ChatErrorCode.permissionDenied,
    );
    expect(
      await codeOf(
        FirebaseException(plugin: 'firebase_storage', code: 'canceled'),
      ),
      ChatErrorCode.network,
    );
    expect(await codeOf(StateError('boom')), ChatErrorCode.unknown);
  });
}
