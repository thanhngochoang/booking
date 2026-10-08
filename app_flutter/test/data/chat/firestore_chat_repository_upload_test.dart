import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photobooking/data/chat/firestore_chat_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/image_purpose.dart';
import 'package:photobooking/data/media/media_uploader.dart';

class _Auth extends Mock implements FirebaseAuth {}

class _User extends Mock implements User {}

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock implements HttpsCallableResult<dynamic> {}

void main() {
  test('chat images are uploaded as .jpg with the chat purpose', () async {
    final auth = _Auth();
    final user = _User();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('u1');
    final functions = _MockFunctions();
    final callable = _MockCallable();
    final result = _MockResult();
    when(() => result.data).thenReturn({'id': 'c1'});
    when(
      () => functions.httpsCallable(any(), options: any(named: 'options')),
    ).thenReturn(callable);
    when(() => callable.call<dynamic>(any())).thenAnswer((_) async => result);
    final uploader = FakeMediaUploader();
    final repo = FirestoreChatRepository(
      firestore: FakeFirebaseFirestore(),
      functions: functions,
      auth: auth,
      mediaUploader: uploader,
    );

    await repo.sendImage(
      'chat1',
      const PickedImage(path: '/tmp/a.heic', name: 'a.heic'),
      clientId: 'c1',
    );

    expect(uploader.purposes, {'chats/chat1/u1/c1.jpg': ImagePurpose.chat});
    final sent =
        verify(() => callable.call<dynamic>(captureAny())).captured.single
            as Map;
    expect((sent['message'] as Map)['imagePath'], 'chats/chat1/u1/c1.jpg');
  });
}
