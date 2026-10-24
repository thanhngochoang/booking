import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/booking/booking.dart';
import 'package:photobooking/data/booking/booking_status.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_providers.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/location/location_repository.dart';
import 'package:photobooking/data/media/image_picker_port.dart';
import 'package:photobooking/data/media/media_uploader.dart';
import 'package:photobooking/data/media/media_providers.dart';
import 'package:photobooking/data/photographer/availability_providers.dart';
import 'package:photobooking/data/photographer/availability_repository.dart';
import 'package:photobooking/data/photographer/public_profile_providers.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/features/booking/booking_features.dart';
import 'package:photobooking/features/booking/booking_parties.dart';
import 'package:photobooking/features/explore/location_controller.dart';
import 'package:photobooking/features/safety/report_sheet.dart';
import 'package:photobooking/l10n/app_localizations_vi.dart';

import '../../support/booking_fixtures.dart';
import '../../support/booking_world.dart';
import '../../support/fake_chat_repository.dart';

Booking _booking({
  String id = 'b1',
  BookingStatus status = BookingStatus.accepted,
  String day = '2026-10-12',
  String start = '15:30',
  String end = '17:30',
  String place = 'Bến Bạch Đằng',
}) {
  return makeTestBooking(
    id: id,
    status: status,
    day: day,
    start: start,
    end: end,
    serviceSnapshot: const BookingServiceSnapshot(
      name: 'Chân dung 2 giờ',
      price: 1500000,
      durationMinutes: 120,
    ),
    place: BookingPlace(name: place),
  );
}

void main() {
  late FakeChatRepository fakeChat;
  late FakeImagePicker fakePicker;
  late FakeLocationRepository fakeLocation;

  setUp(() {
    fakeChat = FakeChatRepository(currentUserId: 'c1');
    fakePicker = FakeImagePicker();
    fakeLocation = FakeLocationRepository();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    String chatId = 'c1_p1',
    String? path,
    String signedInUid = 'c1',
    Booking? booking,
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
    Size viewSize = const Size(390, 844),
    DateTime? now,
  }) async {
    final b = booking ?? _booking();
    final fakeBookingRepo = RecordingBookingRepository()..seedBooking(b);

    await pumpBookingRoute(
      tester,
      path: path ?? '/chat/$chatId',
      signedInUid: signedInUid,
      bookings: fakeBookingRepo,
      brightness: brightness,
      textScale: textScale,
      viewSize: viewSize,
      now: now,
      extraOverrides: [
        mediaUrlResolverProvider.overrideWithValue(FakeMediaUrlResolver()),
        chatRepositoryProvider.overrideWithValue(fakeChat),
        imagePickerProvider.overrideWithValue(fakePicker),
        locationRepositoryProvider.overrideWithValue(fakeLocation),
        bookingFeaturesProvider.overrideWithValue(
          const BookingFeatures(chat: true, reschedule: true, review: true),
        ),
        availabilityMonthProvider.overrideWith(
          (ref, arg) => Stream.value(<DateTime, AvailabilityDay>{}),
        ),
        partyProfileProvider.overrideWith((ref, uid) async* {
          yield UserProfile(
            uid: uid,
            displayName: switch (uid) {
              'p1' => 'Photographer Pro',
              'm1' => 'Thợ Minh',
              _ => 'Customer C',
            },
            avatarUrl: null,
            role: uid == 'c1' ? UserRole.customer : UserRole.photographer,
          );
        }),
        photographerProfileProvider.overrideWith((ref, uid) async {
          return bookingProfile;
        }),
      ],
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'first load shows ChatBubble.skeleton alternating mine/theirs and BookingCard.skeleton(compact)',
    (tester) async {
      final threadCompleter = Completer<ChatThread?>();
      await pumpBookingRoute(
        tester,
        path: '/chat/c1_p1',
        signedInUid: 'c1',
        extraOverrides: [
          chatThreadProvider('c1_p1').overrideWith((_) => threadCompleter.future.asStream()),
          chatRepositoryProvider.overrideWithValue(fakeChat),
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_BookingCardSkeleton'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ChatBubbleSkeleton'), findsNWidgets(6));
    },
  );

  testWidgets(
    'messages render as core ChatBubble and the input is core ChatComposer',
    (tester) async {
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.booking,
          customerId: 'c1',
          photographerId: 'p1',
          bookingId: 'b1',
        ),
      );
      fakeChat.seedMessages('c1_p1', [
        ChatMessage(
          id: 'm1',
          senderId: 'c1',
          type: MessageType.text,
          body: 'Hello',
          createdAt: DateTime(2026, 10, 5, 10, 0),
        ),
      ]);

      await pumpScreen(tester);

      expect(find.byType(ChatBubble), findsOneWidget);
      expect(find.byType(ChatComposer), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is ScreenCode && w.code == ScreenCodes.chat), findsOneWidget);
    },
  );

  testWidgets(
    'booking chat shows pinned booking card with current status, and tapping opens S05.02',
    (tester) async {
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.booking,
          customerId: 'c1',
          photographerId: 'p1',
          bookingId: 'b1',
        ),
      );

      await pumpScreen(tester, booking: _booking(status: BookingStatus.accepted));

      expect(find.byType(BookingCard), findsOneWidget);
      expect(find.textContaining('Chân dung 2 giờ'), findsOneWidget);

      await tester.tap(find.byType(BookingCard));
      await tester.pumpAndSettle();

      expect(find.byWidgetPredicate((w) => w is ScreenCode && w.code == ScreenCodes.bookingDetail), findsOneWidget);
    },
  );

  testWidgets(
    'inquiry chat shows photographer card and no reschedule chip',
    (tester) async {
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.inquiry,
          customerId: 'c1',
          photographerId: 'p1',
        ),
      );

      await pumpScreen(tester);

      expect(find.byType(BookingCard), findsNothing);
      expect(find.text('Photographer Pro'), findsWidgets);
      expect(find.text('Đổi lịch'), findsNothing);
    },
  );

  testWidgets(
    'sends a text and shows it as sending, then sent when the stream has it',
    (tester) async {
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.booking,
          customerId: 'c1',
          photographerId: 'p1',
          bookingId: 'b1',
        ),
      );

      await pumpScreen(tester);

      final input = find.byType(TextField);
      await tester.enterText(input, 'New test message');
      await tester.pump();

      final sendBtn = find.bySemanticsLabel('Gửi tin nhắn');
      await tester.tap(sendBtn);
      await tester.pump();

      expect(find.text('New test message'), findsOneWidget);
    },
  );

  testWidgets(
    'empty or whitespace text cannot be sent',
    (tester) async {
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.booking,
          customerId: 'c1',
          photographerId: 'p1',
          bookingId: 'b1',
        ),
      );

      await pumpScreen(tester);

      final input = find.byType(TextField);
      await tester.enterText(input, '   ');
      await tester.pump();

      final sendBtn = find.bySemanticsLabel('Gửi tin nhắn');
      await tester.tap(sendBtn, warnIfMissed: false);
      await tester.pump();

      expect(fakeChat.messages['c1_p1'], isNull);
    },
  );

  testWidgets(
    'a failed send keeps the bubble with Gửi lại and retries with the same clientId',
    (tester) async {
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.booking,
          customerId: 'c1',
          photographerId: 'p1',
          bookingId: 'b1',
        ),
      );
      fakeChat.failNext = ChatErrorCode.network;

      await pumpScreen(tester);

      final input = find.byType(TextField);
      await tester.enterText(input, 'Failed message');
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Gửi tin nhắn'));
      await tester.pumpAndSettle();

      expect(find.text('Gửi lại'), findsOneWidget);

      await tester.tap(find.text('Gửi lại'));
      await tester.pumpAndSettle();

      expect(find.text('Gửi lại'), findsNothing);
      expect(fakeChat.messages['c1_p1'], hasLength(1));
    },
  );

  testWidgets(
    'fourth unanswered inquiry message is blocked with the explanation',
    (tester) async {
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.inquiry,
          customerId: 'c1',
          photographerId: 'p1',
          customerMessagesBeforeReply: 3,
          photographerRepliedAt: null,
        ),
      );

      await pumpScreen(tester);

      expect(
        find.text('Bạn đã gửi 3 tin. Chờ Photographer Pro trả lời để nhắn tiếp.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'photo: picks one image, uploads, sends; the bubble shows the image',
    (tester) async {
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.booking,
          customerId: 'c1',
          photographerId: 'p1',
          bookingId: 'b1',
        ),
      );
      fakePicker = FakeImagePicker([
        [
          const PickedImage(
            path: 'https://cdn.example.com/photo.webp',
            name: 'photo.webp',
          )
        ]
      ]);

      await pumpScreen(tester);

      await tester.tap(find.bySemanticsLabel('Chọn ảnh'));
      await tester.pumpAndSettle();

      expect(fakeChat.messages['c1_p1'], hasLength(1));
      expect(find.byType(ChatBubble), findsOneWidget);
    },
  );

  testWidgets(
    'location: asks permission on tap, sends point; denied shows SnackBar and sends nothing',
    (tester) async {
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.booking,
          customerId: 'c1',
          photographerId: 'p1',
          bookingId: 'b1',
        ),
      );
      fakeLocation.status = LocationPermissionStatus.denied;
      fakeLocation.statusAfterRequest = LocationPermissionStatus.denied;

      await pumpScreen(tester);

      await tester.tap(find.text('Gửi vị trí'));
      await tester.pumpAndSettle();

      expect(find.text('Không thể lấy vị trí. Vui lòng cấp quyền vị trí.'), findsOneWidget);
      expect(fakeChat.messages['c1_p1'], isNull);

      fakeLocation.statusAfterRequest = LocationPermissionStatus.granted;
      fakeLocation.position = (lat: 10.7, lng: 106.6);

      await tester.tap(find.text('Gửi vị trí'));
      await tester.pumpAndSettle();

      expect(fakeChat.messages['c1_p1'], hasLength(1));
      expect(find.textContaining('Vị trí của'), findsOneWidget);
    },
  );

  testWidgets(
    'Xác nhận địa điểm prefills/sends Chốt địa điểm: {place}',
    (tester) async {
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.booking,
          customerId: 'c1',
          photographerId: 'p1',
          bookingId: 'b1',
        ),
      );

      await pumpScreen(tester, booking: _booking(place: 'Hồ Con Rùa'));

      final confirmChip = find.text('Xác nhận địa điểm');
      await tester.ensureVisible(confirmChip);
      await tester.tap(confirmChip);
      await tester.pumpAndSettle();

      expect(find.text('Chốt địa điểm: Hồ Con Rùa'), findsOneWidget);
    },
  );

  testWidgets(
    'Đổi lịch opens date sheet; sending creates a proposal; counterpart sees Chấp nhận/Từ chối; accepting updates date',
    (tester) async {
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.booking,
          customerId: 'c1',
          photographerId: 'p1',
          bookingId: 'b1',
        ),
      );

      await pumpScreen(tester);

      final rescheduleChip = find.text('Đổi lịch');
      await tester.ensureVisible(rescheduleChip);
      await tester.tap(rescheduleChip);
      await tester.pumpAndSettle();

      expect(find.byType(AvailabilityCalendar), findsOneWidget);

      await tester.tap(find.text('15').first);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reschedule-confirm-btn')));
      await tester.pumpAndSettle();

      expect(fakeChat.messages['c1_p1'], hasLength(1));
      expect(find.textContaining('Đề nghị đổi sang'), findsOneWidget);

      // As photographer: counterpart sees Chấp nhận/Từ chối
      fakeChat.currentUserId = 'p1';
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpScreen(tester, signedInUid: 'p1');

      expect(find.text('Chấp nhận'), findsOneWidget);
      expect(find.text('Từ chối'), findsOneWidget);

      await tester.tap(find.text('Chấp nhận'));
      await tester.pumpAndSettle();

      expect(find.text('Đã đổi lịch thành công'), findsOneWidget);
    },
  );

  testWidgets(
    'declining a reschedule proposal asks through showConfirmSheet and cancels on keep',
    (tester) async {
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.booking,
          customerId: 'c1',
          photographerId: 'p1',
          bookingId: 'b1',
        ),
      );
      fakeChat.seedMessages('c1_p1', [
        ChatMessage(
          id: 'm_prop',
          senderId: 'c1',
          type: MessageType.system,
          system: const SystemPayload(
            kind: 'reschedule_proposal',
            proposal: RescheduleProposal(
              day: '2026-10-20',
              start: '09:00',
              end: '11:00',
              byRole: 'customer',
            ),
          ),
          createdAt: DateTime(2026, 10, 5, 10, 0),
        ),
      ]);

      fakeChat.currentUserId = 'p1';
      await pumpScreen(tester, signedInUid: 'p1');

      await tester.tap(find.text('Từ chối'));
      await tester.pumpAndSettle();

      expect(find.text('Từ chối đề nghị đổi lịch?'), findsOneWidget);

      // Tap keep (Huỷ)
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();

      expect(fakeChat.messages['c1_p1']!.first.system?.answer, isNull);
    },
  );

  testWidgets(
    'read-only chat hides the input',
    (tester) async {
      fakeChat.seedThread(
        ChatThread(
          id: 'c1_p1',
          kind: ChatKind.booking,
          customerId: 'c1',
          photographerId: 'p1',
          bookingId: 'b1',
          readOnlyAt: DateTime(2026, 10, 1),
        ),
      );

      await pumpScreen(tester);

      expect(find.byType(ChatComposer), findsNothing);
      expect(find.text('Cuộc trò chuyện chỉ còn để đọc.'), findsOneWidget);
    },
  );

  testWidgets(
    '320 dp and 1.3x text, light and dark: no overflow',
    (tester) async {
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.booking,
          customerId: 'c1',
          photographerId: 'p1',
          bookingId: 'b1',
        ),
      );

      for (final brightness in [Brightness.light, Brightness.dark]) {
        await pumpScreen(
          tester,
          brightness: brightness,
          textScale: 1.3,
          viewSize: const Size(320, 640),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  group('photos', () {
    const bookingThread = ChatThread(
      id: 'c1_p1',
      kind: ChatKind.booking,
      customerId: 'c1',
      photographerId: 'p1',
      bookingId: 'b1',
    );
    const photo = PickedImage(path: '/tmp/photo.jpg', name: 'photo.jpg');

    ImageContent bubbleImage(WidgetTester tester) =>
        tester.widget<ChatBubble>(find.byType(ChatBubble)).content
            as ImageContent;

    testWidgets('an incoming image shows the resolved download URL', (
      tester,
    ) async {
      fakeChat.seedThread(bookingThread);
      fakeChat.seedMessages('c1_p1', [
        ChatMessage(
          id: 'm1',
          senderId: 'p1',
          type: MessageType.image,
          imagePath: 'chats/c1_p1/p1/m1.jpg',
          createdAt: DateTime(2026, 10, 5, 10, 0),
        ),
      ]);

      await pumpScreen(tester);

      expect(bubbleImage(tester).url, 'https://storage.test/chats/c1_p1/p1/m1.jpg');
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is NetworkPhoto &&
              w.url == 'https://storage.test/chats/c1_p1/p1/m1.jpg',
        ),
        findsOneWidget,
      );
    });

    testWidgets('my sent image keeps the local file after the message arrives', (
      tester,
    ) async {
      fakeChat.seedThread(bookingThread);
      fakePicker = FakeImagePicker([
        [photo],
      ]);

      await pumpScreen(tester);
      await tester.tap(find.bySemanticsLabel('Chọn ảnh'));
      await tester.pumpAndSettle();

      // The stream now holds the message (with its storage path) and the
      // pending copy is gone.
      expect(fakeChat.messages['c1_p1'], hasLength(1));
      expect(fakeChat.messages['c1_p1']!.single.imagePath, startsWith('chats/'));
      expect(find.byType(ChatBubble), findsOneWidget);
      final image = bubbleImage(tester);
      expect(image.localPath, '/tmp/photo.jpg');
      expect(image.url, isEmpty);
      expect(find.byType(NetworkPhoto), findsNothing);
    });

    testWidgets('a failed photo shows "Gửi lại" and tapping it resends', (
      tester,
    ) async {
      fakeChat.seedThread(bookingThread);
      fakePicker = FakeImagePicker([
        [photo],
      ]);
      fakeChat.failNextSendImage = ChatErrorCode.network;

      await pumpScreen(tester);
      await tester.tap(find.bySemanticsLabel('Chọn ảnh'));
      await tester.pumpAndSettle();

      expect(find.text('Gửi lại'), findsOneWidget);
      expect(fakeChat.messages['c1_p1'], isNull);

      await tester.tap(find.text('Gửi lại'));
      await tester.pumpAndSettle();

      expect(find.text('Gửi lại'), findsNothing);
      expect(fakeChat.uploads, hasLength(1)); // not uploaded again
      expect(fakeChat.messages['c1_p1'], hasLength(1));
    });
  });

  group('inquiry', () {
    final stale = worldBookingToday.subtract(const Duration(days: 15));
    ChatThread closedInquiry() => ChatThread(
      id: 'c1_p1',
      kind: ChatKind.inquiry,
      customerId: 'c1',
      photographerId: 'p1',
      lastMessageAt: stale,
      createdAt: stale,
    );

    testWidgets(
      'a closed inquiry shows "Cuộc trò chuyện đã đóng. Gửi tin để mở lại." and the composer stays enabled',
      (tester) async {
        fakeChat.seedThread(closedInquiry());

        await pumpScreen(tester);

        expect(
          find.text('Cuộc trò chuyện đã đóng. Gửi tin để mở lại.'),
          findsOneWidget,
        );
        expect(tester.widget<TextField>(find.byType(TextField)).enabled, true);
      },
    );

    testWidgets('an inquiry with no message closes from createdAt', (
      tester,
    ) async {
      fakeChat.seedThread(
        ChatThread(
          id: 'c1_p1',
          kind: ChatKind.inquiry,
          customerId: 'c1',
          photographerId: 'p1',
          createdAt: stale,
        ),
      );

      await pumpScreen(tester);

      expect(
        find.text('Cuộc trò chuyện đã đóng. Gửi tin để mở lại.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a refused reopen shows "Nhiếp ảnh gia đang tạm tắt nhận tin hỏi trước."',
      (tester) async {
        fakeChat.seedThread(closedInquiry());
        fakeChat.failNext = ChatErrorCode.notEligible;

        await pumpScreen(tester);
        await tester.enterText(find.byType(TextField), 'Chào bạn');
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Gửi tin nhắn'));
        await tester.pumpAndSettle();

        expect(
          find.text('Nhiếp ảnh gia đang tạm tắt nhận tin hỏi trước.'),
          findsOneWidget,
        );
        expect(find.text('Gửi lại'), findsOneWidget);
      },
    );

    testWidgets('the … menu shows "Xem hồ sơ" for a customer in an inquiry and opens /u/:photographerId', (
      tester,
    ) async {
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.inquiry,
          customerId: 'c1',
          photographerId: 'p1',
        ),
      );

      await pumpScreen(tester);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Xem hồ sơ'), findsOneWidget);

      await tester.tap(find.text('Xem hồ sơ'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is ScreenCode && w.code == ScreenCodes.photographerProfile,
        ),
        findsOneWidget,
      );
    });

    testWidgets('an inquiry chat shows the … menu with report and block for the photographer', (
      tester,
    ) async {
      fakeChat.currentUserId = 'p1';
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.inquiry,
          customerId: 'c1',
          photographerId: 'p1',
        ),
      );

      await pumpScreen(tester, signedInUid: 'p1');

      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    });

    testWidgets('a booking chat keeps "Xem buổi chụp" in the … menu', (
      tester,
    ) async {
      fakeChat.seedThread(
        const ChatThread(
          id: 'c1_p1',
          kind: ChatKind.booking,
          customerId: 'c1',
          photographerId: 'p1',
          bookingId: 'b1',
        ),
      );

      await pumpScreen(tester);
      final moreFinder = find.byKey(const Key('chat-more'));
      expect(moreFinder, findsOneWidget);
      await tester.tap(moreFinder);
      await tester.pumpAndSettle();

      expect(find.text('Xem buổi chụp'), findsOneWidget);
      expect(find.text('Xem hồ sơ'), findsNothing);
    });
  });

  group('a studio booking chat (#136)', () {
    Booking studioBooking() => _booking().copyWith(
      studio: StudioBookingInfo(
        assigneeId: 'm1',
        assignStatus: StudioAssignStatus.assigned,
        assignDeadline: DateTime.utc(2026, 10, 11, 8, 30),
      ),
    );

    void seedThreeMembers({String? assigneeId = 'm1'}) {
      fakeChat.seedThread(
        ChatThread(
          id: 'c1_p1',
          kind: ChatKind.booking,
          customerId: 'c1',
          photographerId: 'p1',
          assigneeId: assigneeId,
          bookingId: 'b1',
        ),
      );
      fakeChat.seedMessages('c1_p1', [
        ChatMessage(
          id: 'm_c',
          senderId: 'c1',
          type: MessageType.text,
          body: 'from customer',
          createdAt: DateTime(2026, 10, 5, 10, 0),
        ),
        ChatMessage(
          id: 'm_p',
          senderId: 'p1',
          type: MessageType.text,
          body: 'from studio',
          createdAt: DateTime(2026, 10, 5, 10, 1),
        ),
        ChatMessage(
          id: 'm_m',
          senderId: 'm1',
          type: MessageType.text,
          body: 'from assignee',
          createdAt: DateTime(2026, 10, 5, 10, 2),
        ),
      ]);
    }

    /// Text of each bubble → the name shown above it (null on mine).
    Map<String, String?> senders(WidgetTester tester) => {
      for (final b in tester.widgetList<ChatBubble>(find.byType(ChatBubble)))
        if (b.content case TextContent(:final text)) text: b.senderName,
    };

    for (final (viewer, expected) in [
      (
        'p1',
        {'from customer': 'Customer C', 'from studio': null, 'from assignee': 'Thợ Minh'},
      ),
      (
        'm1',
        {'from customer': 'Customer C', 'from studio': 'Photographer Pro', 'from assignee': null},
      ),
      (
        'c1',
        {'from customer': null, 'from studio': 'Photographer Pro', 'from assignee': 'Thợ Minh'},
      ),
    ]) {
      testWidgets('each message is named after its sender for $viewer', (tester) async {
        fakeChat.currentUserId = viewer;
        seedThreeMembers();
        await pumpScreen(tester, signedInUid: viewer, booking: studioBooking());
        expect(senders(tester), expected);
      });
    }

    testWidgets('the report sheet names the assignee, not the customer, for the studio', (tester) async {
      fakeChat.currentUserId = 'p1';
      seedThreeMembers();
      await pumpScreen(tester, signedInUid: 'p1', booking: studioBooking());
      await tester.longPress(find.text('from assignee'));
      await tester.pumpAndSettle();
      final sheet = tester.widget<ReportSheet>(find.byType(ReportSheet));
      expect(sheet.target.ownerName, 'Thợ Minh');
    });

    testWidgets('a two-member chat still names the counterpart', (tester) async {
      seedThreeMembers(assigneeId: null);
      await pumpScreen(tester);
      expect(senders(tester)['from studio'], 'Photographer Pro');
      expect(senders(tester)['from customer'], isNull);
    });

    testWidgets('no "Đổi lịch" chip on a studio booking', (tester) async {
      seedThreeMembers();
      await pumpScreen(tester, booking: studioBooking());
      expect(find.text('Gửi vị trí'), findsOneWidget);
      expect(find.text('Đổi lịch'), findsNothing);
    });
  });

  testWidgets('a missing chat shows "Không tìm thấy cuộc trò chuyện"', (
    tester,
  ) async {
    await pumpScreen(tester, chatId: 'gone');

    expect(find.text('Không tìm thấy cuộc trò chuyện'), findsOneWidget);
    expect(find.text('...'), findsNothing);
  });

  testWidgets('the collab chat screen has no ContactDial and no booking bar', (
    tester,
  ) async {
    // S27 Decision 16: studio p1 (customer slot) and collaborator m1.
    fakeChat.currentUserId = 'p1';
    fakeChat.seedThread(
      const ChatThread(
        id: 'collab_p1_m1',
        kind: ChatKind.collab,
        customerId: 'p1',
        photographerId: 'm1',
      ),
    );
    await pumpScreen(tester, chatId: 'collab_p1_m1', signedInUid: 'p1');

    expect(find.text('Thợ Minh'), findsOneWidget);
    expect(find.byType(ContactDial), findsNothing);
    expect(find.byType(BookingCard), findsNothing);
    // Not the inquiry card with the collaborator's services either.
    expect(find.text(bookingProfile.summary.displayName), findsNothing);
    expect(find.byKey(const Key('chat-collab-card')), findsOneWidget);
    expect(find.byType(ChatComposer), findsOneWidget);
  });

  testWidgets('an ended collab chat is read-only: the note, no composer', (
    tester,
  ) async {
    // S27 Decision 16: endCollaboration sets readOnlyAt; the chat stays
    // readable for 30 days.
    fakeChat.currentUserId = 'p1';
    fakeChat.seedThread(
      ChatThread(
        id: 'collab_p1_m1',
        kind: ChatKind.collab,
        customerId: 'p1',
        photographerId: 'm1',
        readOnlyAt: DateTime.utc(2026, 10, 1),
      ),
    );
    await pumpScreen(
      tester,
      chatId: 'collab_p1_m1',
      signedInUid: 'p1',
      now: DateTime.utc(2026, 10, 5),
    );

    expect(find.text(AppLocalizationsVi().chatReadOnly), findsOneWidget);
    expect(find.byType(ChatComposer), findsNothing);
    expect(find.byKey(const Key('chat-collab-card')), findsOneWidget);
  });
}
