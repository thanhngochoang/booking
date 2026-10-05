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
}
