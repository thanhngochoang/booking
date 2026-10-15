import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_providers.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/features/chat/chat_controller.dart';
import 'package:photobooking/features/explore/location_controller.dart';

import '../../support/fake_chat_repository.dart';

void main() {
  late FakeChatRepository fakeChat;
  late FakeAuthRepository fakeAuth;
  late FakeImagePicker fakePicker;
  late FakeLocationRepository fakeLocation;
  late ProviderContainer container;

  const chatId = 'cust1_photo1';

  setUp(() async {
    fakeChat = FakeChatRepository(currentUserId: 'cust1');
    fakeAuth = FakeAuthRepository();
    final user = await fakeAuth.registerWithEmail(
      'cust1@example.com',
      'password123',
      'Customer',
    );
    fakePicker = FakeImagePicker();
    fakeLocation = FakeLocationRepository();

    fakeChat.seedThread(
      ChatThread(
        id: chatId,
        kind: ChatKind.booking,
        customerId: user.uid,
        photographerId: 'photo1',
        bookingId: 'book1',
      ),
    );

    container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(fakeChat),
        authRepositoryProvider.overrideWithValue(fakeAuth),
        imagePickerProvider.overrideWithValue(fakePicker),
        locationRepositoryProvider.overrideWithValue(fakeLocation),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 5, 12, 0)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('sendText adds pending message and cleans up on stream sync', () async {
    final controller = container.read(chatControllerProvider(chatId).notifier);

    await controller.sendText('Hello photographer');

    var state = container.read(chatControllerProvider(chatId));
    expect(state.pendingMessages, hasLength(1));
    final pending = state.pendingMessages.first;
    expect(pending.body, 'Hello photographer');
    expect(pending.sendState, MessageSendState.sending);

    // Fake repo added it to messages
    final repoMsgs = fakeChat.messages[chatId] ?? [];
    expect(repoMsgs, hasLength(1));
    expect(repoMsgs.first.id, pending.id);

    // Sync with stream
    controller.syncWithStream(repoMsgs);
    state = container.read(chatControllerProvider(chatId));
    expect(state.pendingMessages, isEmpty);
  });

  test('failed sendText keeps pending message with failed state and retries with same clientId', () async {
    final controller = container.read(chatControllerProvider(chatId).notifier);
    fakeChat.failNext = ChatErrorCode.network;

    await controller.sendText('Will fail');

    var state = container.read(chatControllerProvider(chatId));
    expect(state.pendingMessages, hasLength(1));
    final failed = state.pendingMessages.first;
    expect(failed.sendState, MessageSendState.failed);
    final originalClientId = failed.id;

    // Retry
    await controller.retryMessage(failed);
    state = container.read(chatControllerProvider(chatId));
    final retried = state.pendingMessages.first;
    expect(retried.id, originalClientId);
    expect(retried.sendState, MessageSendState.sending);

    final repoMsgs = fakeChat.messages[chatId] ?? [];
    expect(repoMsgs, hasLength(1));
    expect(repoMsgs.first.id, originalClientId);
  });

  test('pickAndSendImage picks, sets busy, and creates pending image message', () async {
    final controller = container.read(chatControllerProvider(chatId).notifier);
    final testPicker = FakeImagePicker([
      [
        const PickedImage(
          path: '/tmp/test.jpg',
          name: 'test.jpg',
          sizeBytes: 100,
        )
      ]
    ]);
    container.updateOverrides([
      chatRepositoryProvider.overrideWithValue(fakeChat),
      authRepositoryProvider.overrideWithValue(fakeAuth),
      imagePickerProvider.overrideWithValue(testPicker),
      locationRepositoryProvider.overrideWithValue(fakeLocation),
      clockProvider.overrideWithValue(() => DateTime(2026, 10, 5, 12, 0)),
    ]);

    await controller.pickAndSendImage();

    final state = container.read(chatControllerProvider(chatId));
    expect(state.pendingMessages, hasLength(1));
    final msg = state.pendingMessages.first;
    expect(msg.type, MessageType.image);
    expect(msg.imagePath, '/tmp/test.jpg');
    expect(state.isUploadingImage, false);

    final repoMsgs = fakeChat.messages[chatId] ?? [];
    expect(repoMsgs, hasLength(1));
  });

  test('sendLocation sends location when granted, returns false when denied', () async {
    final controller = container.read(chatControllerProvider(chatId).notifier);
    fakeLocation.status = LocationPermissionStatus.denied;
    fakeLocation.statusAfterRequest = LocationPermissionStatus.denied;
    fakeLocation.position = null;

    final deniedResult = await controller.sendLocation();
    expect(deniedResult, false);
    expect(container.read(chatControllerProvider(chatId)).pendingMessages, isEmpty);

    fakeLocation.statusAfterRequest = LocationPermissionStatus.granted;
    fakeLocation.position = (lat: 10.7, lng: 106.6);
    final grantedResult = await controller.sendLocation();
    expect(grantedResult, true);

    final state = container.read(chatControllerProvider(chatId));
    expect(state.pendingMessages, hasLength(1));
    final locMsg = state.pendingMessages.first;
    expect(locMsg.type, MessageType.location);
    expect(locMsg.point?.lat, 10.7);
  });

  test('proposeReschedule and answerReschedule call repository', () async {
    final controller = container.read(chatControllerProvider(chatId).notifier);

    await controller.proposeReschedule(
      bookingId: 'book1',
      day: '2026-10-10',
      start: '09:00',
    );

    final msgs = fakeChat.messages[chatId] ?? [];
    expect(msgs, hasLength(1));
    expect(msgs.first.type, MessageType.system);
    expect(msgs.first.system?.kind, 'reschedule_proposal');
    final proposalMsgId = msgs.first.id;

    fakeChat.currentUserId = 'photo1';
    await controller.answerReschedule(proposalMsgId, accept: true);

    final updated = fakeChat.messages[chatId]!.first;
    expect(updated.system?.answer, 'accepted');
  });

  group('photos', () {
    const photo = PickedImage(
      path: '/tmp/photo.jpg',
      name: 'photo.jpg',
      sizeBytes: 100,
    );

    ChatController withPhoto() {
      container.updateOverrides([
        chatRepositoryProvider.overrideWithValue(fakeChat),
        authRepositoryProvider.overrideWithValue(fakeAuth),
        imagePickerProvider.overrideWithValue(
          FakeImagePicker([
            [photo],
            [photo],
          ]),
        ),
        locationRepositoryProvider.overrideWithValue(fakeLocation),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 5, 12, 0)),
      ]);
      return container.read(chatControllerProvider(chatId).notifier);
    }

    ChatMessage pending() =>
        container.read(chatControllerProvider(chatId)).pendingMessages.single;

    test('sending a photo uploads then posts the path', () async {
      final controller = withPhoto();

      await controller.pickAndSendImage();

      expect(fakeChat.uploads, hasLength(1));
      final up = fakeChat.uploads.single;
      expect(up.path, 'chats/$chatId/cust1/${up.clientId}.jpg');
      expect(fakeChat.imageSends, hasLength(1));
      expect(fakeChat.imageSends.single.path, up.path);
      expect(fakeChat.imageSends.single.clientId, up.clientId);
      expect(pending().id, up.clientId);
    });

    test('an upload failure marks the bubble failed', () async {
      final controller = withPhoto();
      fakeChat.failNext = ChatErrorCode.network;

      await controller.pickAndSendImage();

      expect(pending().sendState, MessageSendState.failed);
      expect(fakeChat.imageSends, isEmpty);
      expect(
        container.read(chatControllerProvider(chatId)).isUploadingImage,
        false,
      );
    });

    test('retry after an upload failure uploads again then posts', () async {
      final controller = withPhoto();
      fakeChat.failNext = ChatErrorCode.network;
      await controller.pickAndSendImage();
      expect(fakeChat.uploads, isEmpty);

      await controller.retryMessage(pending());

      expect(fakeChat.uploads, hasLength(1));
      expect(fakeChat.imageSends, hasLength(1));
      expect(fakeChat.imageSends.single.path, fakeChat.uploads.single.path);
    });

    test(
      'retry after a send failure posts the same path without uploading',
      () async {
        final controller = withPhoto();
        fakeChat.failNextSendImage = ChatErrorCode.network;
        await controller.pickAndSendImage();
        expect(pending().sendState, MessageSendState.failed);
        expect(fakeChat.uploads, hasLength(1));

        await controller.retryMessage(pending());

        expect(fakeChat.uploads, hasLength(1));
        expect(fakeChat.imageSendAttempts, hasLength(2));
        expect(
          fakeChat.imageSendAttempts[1].path,
          fakeChat.imageSendAttempts[0].path,
        );
        expect(
          fakeChat.imageSendAttempts[1].clientId,
          fakeChat.imageSendAttempts[0].clientId,
        );
        expect(fakeChat.imageSends, hasLength(1));
        expect(fakeChat.imageSends.single.path, fakeChat.uploads.single.path);
      },
    );

    test('localFileFor returns the picked file of a sent photo', () async {
      final controller = withPhoto();
      await controller.pickAndSendImage();
      final id = pending().id;

      expect(controller.localFileFor(id), '/tmp/photo.jpg');
      expect(controller.localFileFor('someone-elses'), isNull);

      // Still there once the stream has the message and pending is cleared.
      controller.syncWithStream(fakeChat.messages[chatId]!);
      expect(
        container.read(chatControllerProvider(chatId)).pendingMessages,
        isEmpty,
      );
      expect(controller.localFileFor(id), '/tmp/photo.jpg');
    });

    test('an image this screen did not pick stays failed on retry', () async {
      final controller = withPhoto();
      final foreign = ChatMessage(
        id: 'old',
        senderId: 'cust1',
        type: MessageType.image,
        imagePath: 'chats/$chatId/cust1/old.jpg',
        createdAt: DateTime(2026, 10, 5),
        sendState: MessageSendState.failed,
      );

      await controller.retryMessage(foreign);

      expect(fakeChat.uploads, isEmpty);
      expect(fakeChat.imageSendAttempts, isEmpty);
    });

    test('a not_eligible failure on a closed inquiry sets errorCode', () async {
      final controller = withPhoto();
      fakeChat.failNext = ChatErrorCode.notEligible;

      await controller.sendText('Xin chào lại');

      final state = container.read(chatControllerProvider(chatId));
      expect(state.errorCode, ChatErrorCode.notEligible);
      expect(state.errorSeq, 1);
      expect(state.pendingMessages.single.sendState, MessageSendState.failed);

      fakeChat.failNext = ChatErrorCode.notEligible;
      await controller.retryMessage(state.pendingMessages.single);
      expect(container.read(chatControllerProvider(chatId)).errorSeq, 2);
    });

    test('no state write after dispose', () async {
      final gate = Completer<void>();
      fakeChat.uploadGate = gate.future;
      final controller = withPhoto();
      final sub = container.listen(chatControllerProvider(chatId), (_, _) {});

      final sending = controller.pickAndSendImage();
      await Future<void>.delayed(Duration.zero);
      expect(sub.read().isUploadingImage, true);

      container.dispose();
      gate.complete();

      await sending; // must not throw
    });
  });
}
