import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/chat/chat.dart';
import 'package:photobooking/data/chat/chat_providers.dart';
import 'package:photobooking/data/clock/clock.dart';
import 'package:photobooking/data/user/user_profile.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/chat/chat_list_screen.dart';

import '../../support/fake_chat_repository.dart';
import '../../support/screen_host.dart';

final _testNow = DateTime.utc(2026, 10, 5, 10, 0);

void main() {
  late FakeChatRepository fakeChat;
  late FakeUserRepository fakeUsers;
  late FakeAuthRepository fakeAuth;

  setUp(() async {
    fakeChat = FakeChatRepository(currentUserId: 'c1');
    fakeUsers = FakeUserRepository();
    fakeAuth = FakeAuthRepository();

    await fakeUsers.ensureProfile(
      const AuthUser(uid: 'c1', displayName: 'Khách A'),
    );
    await fakeUsers.setRole('c1', UserRole.customer);

    await fakeUsers.ensureProfile(
      const AuthUser(uid: 'p1', displayName: 'Minh Trí'),
    );
    await fakeUsers.setRole('p1', UserRole.photographer);

    await fakeUsers.ensureProfile(
      const AuthUser(uid: 'p2', displayName: 'Hồng Nhung'),
    );
    await fakeUsers.setRole('p2', UserRole.photographer);
  });

  Future<GoRouter> pumpChatList(
    WidgetTester tester, {
    String currentUid = 'c1',
    List<Override> extraOverrides = const [],
    Brightness brightness = Brightness.dark,
    double textScale = 1.0,
    Size viewSize = const Size(390, 844),
  }) async {
    fakeChat.currentUserId = currentUid;
    late GoRouter router;
    router = GoRouter(
      initialLocation: '/chats',
      routes: [
        GoRoute(
          path: '/chats',
          builder: (_, _) => const ChatListScreen(),
        ),
        GoRoute(
          path: '/chat/:id',
          builder: (_, s) => Scaffold(
            body: Text('chat ${s.pathParameters['id']}'),
          ),
        ),
        GoRoute(
          path: '/action',
          builder: (_, _) => const Scaffold(
            body: Text('action screen'),
          ),
        ),
      ],
    );

    final overrides = <Override>[
      authRepositoryProvider.overrideWithValue(fakeAuth),
      authStateProvider.overrideWith(
        (ref) => Stream.value(AuthUser(uid: currentUid)),
      ),
      currentProfileProvider.overrideWith(
        (ref) => fakeUsers.watch(currentUid),
      ),
      userRepositoryProvider.overrideWithValue(fakeUsers),
      clockProvider.overrideWithValue(() => _testNow),
      chatRepositoryProvider.overrideWithValue(fakeChat),
      ...extraOverrides,
    ];

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: viewSize,
        ),
        child: screenRouterApp(
          router: router,
          overrides: overrides,
          brightness: brightness,
          textScale: textScale,
        ),
      ),
    );
    await tester.pump();
    return router;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('first load shows ConversationRow.skeleton six times', (
    tester,
  ) async {
    final never = StreamController<List<ChatListItem>>();
    addTearDown(never.close);

    await pumpChatList(
      tester,
      extraOverrides: [
        myChatsProvider.overrideWith((ref) => never.stream),
      ],
    );

    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Tin nhắn'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('conversation_row_skeleton')),
      findsNWidgets(6),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('lists chats newest first with preview and unread badge', (
    tester,
  ) async {
    final t1 = ChatThread(
      id: 'chat_booking_1',
      kind: ChatKind.booking,
      customerId: 'c1',
      photographerId: 'p1',
      bookingId: 'b1',
      lastMessageAt: DateTime.utc(2026, 10, 5, 9, 41),
      lastMessagePreview: 'Đẹp rồi. 15:30 gặp ở cổng công viên Bạch Đằng.',
    );
    final t2 = ChatThread(
      id: 'chat_inquiry_2',
      kind: ChatKind.inquiry,
      customerId: 'c1',
      photographerId: 'p2',
      lastMessageAt: DateTime.utc(2026, 10, 5, 8, 30),
      lastMessagePreview: 'Gói cưới cả ngày có kèm album không chị?',
    );

    fakeChat.seedThread(t1);
    fakeChat.seedThread(t2);
    fakeChat.seedUnread(t1.id, 2);

    await pumpChatList(tester);
    await settle(tester);

    expect(find.text('Minh Trí'), findsOneWidget);
    expect(find.text('Hồng Nhung'), findsOneWidget);
    expect(
      find.text('Đẹp rồi. 15:30 gặp ở cổng công viên Bạch Đằng.'),
      findsOneWidget,
    );
    expect(
      find.text('Gói cưới cả ngày có kèm album không chị?'),
      findsOneWidget,
    );

    // Unread count
    expect(find.text('2'), findsOneWidget);

    // Booking has StatusBadge
    expect(find.text('Đã đặt'), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);

    // Order: Minh Trí (09:41) is above Hồng Nhung (08:30)
    final pos1 = tester.getTopLeft(find.text('Minh Trí')).dy;
    final pos2 = tester.getTopLeft(find.text('Hồng Nhung')).dy;
    expect(pos1, lessThan(pos2));
  });

  testWidgets('tapping opens the conversation', (tester) async {
    final t1 = ChatThread(
      id: 'chat_booking_1',
      kind: ChatKind.booking,
      customerId: 'c1',
      photographerId: 'p1',
      lastMessageAt: DateTime.utc(2026, 10, 5, 9, 41),
      lastMessagePreview: 'Xin chào',
    );
    fakeChat.seedThread(t1);

    final router = await pumpChatList(tester);
    await settle(tester);

    await tester.tap(find.text('Minh Trí'));
    await settle(tester);

    expect(find.text('chat chat_booking_1'), findsOneWidget);
    expect(router.state.uri.toString(), '/chat/chat_booking_1');
  });

  testWidgets('empty state differs by role', (tester) async {
    // 1. Customer: shows "Chưa có cuộc trò chuyện nào" + "Tìm nhiếp ảnh gia"
    await pumpChatList(tester, currentUid: 'c1');
    await settle(tester);

    expect(find.text('Chưa có cuộc trò chuyện nào'), findsOneWidget);
    expect(find.text('Tìm nhiếp ảnh gia'), findsOneWidget);

    await tester.tap(find.text('Tìm nhiếp ảnh gia'));
    await settle(tester);
    expect(find.text('action screen'), findsOneWidget);

    // 2. Photographer: shows "Chưa có cuộc trò chuyện nào", no button
    await pumpChatList(tester, currentUid: 'p1');
    await settle(tester);

    expect(find.text('Chưa có cuộc trò chuyện nào'), findsOneWidget);
    expect(find.text('Tìm nhiếp ảnh gia'), findsNothing);
  });

  testWidgets('a new message reorders the list live', (tester) async {
    final t1 = ChatThread(
      id: 'chat_1',
      kind: ChatKind.inquiry,
      customerId: 'c1',
      photographerId: 'p1',
      lastMessageAt: DateTime.utc(2026, 10, 5, 8, 0),
      lastMessagePreview: 'Tin từ p1',
    );
    final t2 = ChatThread(
      id: 'chat_2',
      kind: ChatKind.inquiry,
      customerId: 'c1',
      photographerId: 'p2',
      lastMessageAt: DateTime.utc(2026, 10, 5, 7, 0),
      lastMessagePreview: 'Tin từ p2',
    );

    fakeChat.seedThread(t1);
    fakeChat.seedThread(t2);

    await pumpChatList(tester);
    await settle(tester);

    // Initially t1 is above t2
    var p1Dy = tester.getTopLeft(find.text('Minh Trí')).dy;
    var p2Dy = tester.getTopLeft(find.text('Hồng Nhung')).dy;
    expect(p1Dy, lessThan(p2Dy));

    // New message for t2 at 09:00 -> reorders live
    fakeChat.seedThread(
      t2.copyWith(
        lastMessageAt: DateTime.utc(2026, 10, 5, 9, 0),
        lastMessagePreview: 'Tin mới nhất!',
      ),
    );
    await settle(tester);

    expect(find.text('Tin mới nhất!'), findsOneWidget);
    p1Dy = tester.getTopLeft(find.text('Minh Trí')).dy;
    p2Dy = tester.getTopLeft(find.text('Hồng Nhung')).dy;
    expect(p2Dy, lessThan(p1Dy));
  });

  testWidgets('320 dp, 1.3×', (tester) async {
    final t1 = ChatThread(
      id: 'chat_1',
      kind: ChatKind.booking,
      customerId: 'c1',
      photographerId: 'p1',
      lastMessageAt: DateTime.utc(2026, 10, 5, 9, 41),
      lastMessagePreview:
          'Một tin nhắn xem trước cực kỳ dài để kiểm tra độ co giãn trên màn nhỏ và chữ lớn',
    );
    fakeChat.seedThread(t1);
    fakeChat.seedUnread(t1.id, 99);

    for (final brightness in [Brightness.dark, Brightness.light]) {
      await pumpChatList(
        tester,
        brightness: brightness,
        textScale: 1.3,
        viewSize: const Size(320, 640),
      );
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Minh Trí'), findsOneWidget);
      expect(find.text('Đã đặt'), findsOneWidget);
    }
  });
}
