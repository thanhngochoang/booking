// test/features/chat/inquiry_entry_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:photobooking/core/core.dart';
import 'package:photobooking/data/auth/auth_providers.dart';
import 'package:photobooking/data/auth/auth_repository.dart';
import 'package:photobooking/data/chat/chat_providers.dart';
import 'package:photobooking/data/chat/chat_repository.dart';
import 'package:photobooking/data/photographer/photographer_contact.dart';
import 'package:photobooking/data/user/user_repository.dart';
import 'package:photobooking/features/chat/inquiry_entry.dart';
import 'package:photobooking/features/photographer_profile/photographer_profile_screen.dart';
import 'package:photobooking/features/photographer_profile/profile_section.dart';

import '../../support/fake_chat_repository.dart';
import '../../support/profile_world.dart';
import '../../support/screen_host.dart';

class _BlockingChatRepo extends FakeChatRepository {
  _BlockingChatRepo(this.completer);
  final Completer<String> completer;

  @override
  Future<String> openInquiry(String photographerId) => completer.future;
}

void main() {
  testWidgets(
    'the inquiry entry shows SignatureLoader with ripple waves while opening',
    (tester) async {
      final completer = Completer<String>();
      final chatRepo = _BlockingChatRepo(completer);
      final authRepo = FakeAuthRepository();
      final user = await authRepo.registerWithEmail(
        'c1@test.vn',
        'pass1234',
        'Khách',
      );

      final router = GoRouter(
        initialLocation: '/u/p1/ask',
        routes: [
          GoRoute(
            path: '/u/:uid/ask',
            builder: (_, s) => InquiryEntry(
              photographerId: s.pathParameters['uid']!,
              serviceId: s.uri.queryParameters['serviceId'],
            ),
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (_, s) => Text('chat ${s.pathParameters['id']}'),
          ),
        ],
      );

      await tester.pumpWidget(
        screenRouterApp(
          router: router,
          overrides: [
            chatRepositoryProvider.overrideWithValue(chatRepo),
            authStateProvider.overrideWith((ref) => Stream.value(user)),
          ],
        ),
      );
      await tester.pump();

      final loaderFinder = find.byType(SignatureLoader);
      expect(loaderFinder, findsOneWidget);
      final loader = tester.widget<SignatureLoader>(loaderFinder);
      expect(loader.size, LoaderSize.screen);
      expect(loader.wave, LoaderWave.ripple);

      completer.complete('chat_123');
      await tester.pumpAndSettle();
      expect(find.text('chat chat_123'), findsOneWidget);
    },
  );

  testWidgets(
    'a photographer who turned inquiries off shows chưa nhận tin hỏi trước',
    (tester) async {
      final chatRepo = FakeChatRepository();
      chatRepo.failNext = ChatErrorCode.notEligible;

      final userRepo = FakeUserRepository();
      await userRepo.ensureProfile(
        const AuthUser(uid: 'p1', displayName: 'Minh Trí'),
      );

      final router = GoRouter(
        initialLocation: '/u/p1/ask',
        routes: [
          GoRoute(
            path: '/u/:uid',
            builder: (_, s) => Text('profile ${s.pathParameters['uid']}'),
          ),
          GoRoute(
            path: '/u/:uid/ask',
            builder: (_, s) => InquiryEntry(
              photographerId: s.pathParameters['uid']!,
              serviceId: s.uri.queryParameters['serviceId'],
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        screenRouterApp(
          router: router,
          overrides: [
            chatRepositoryProvider.overrideWithValue(chatRepo),
            userRepositoryProvider.overrideWithValue(userRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Minh Trí chưa nhận tin hỏi trước'), findsOneWidget);
      expect(find.text('Quay lại'), findsOneWidget);

      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('profile p1'), findsOneWidget);
    },
  );

  testWidgets('S03.01 Nhắn tin hỏi trước opens the inquiry chat', (
    tester,
  ) async {
    usePhoneFor(tester, width: 390, height: 1400);
    final w = ProfileWorld();
    await w.init();
    w.contacts.seed(
      'p1',
      channels: const ContactChannels(
        acceptInquiries: true,
        call: true,
        zalo: true,
      ),
    );

    final chatRepo = w.discovery.chat;
    chatRepo.currentUserId = w.uid;

    final router = GoRouter(
      initialLocation: '/u/p1',
      routes: [
        GoRoute(
          path: '/u/:uid/ask',
          builder: (_, s) => InquiryEntry(
            photographerId: s.pathParameters['uid']!,
            serviceId: s.uri.queryParameters['serviceId'],
          ),
        ),
        GoRoute(
          path: '/u/:uid',
          builder: (_, s) => PhotographerProfileScreen(
            uid: s.pathParameters['uid']!,
            initialSection: profileSectionFromQuery(
              s.uri.queryParameters['tab'],
            ),
          ),
        ),
        GoRoute(
          path: '/chat/:id',
          builder: (_, s) => Text('chat ${s.pathParameters['id']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      screenRouterApp(
        router: router,
        overrides: w.overrides,
      ),
    );
    await tester.pumpAndSettle();

    // S03.01 footer contact dial for visitors has "Nhắn tin hỏi trước"
    final dialButton = find.byKey(const Key('contact-dial-button'));
    expect(dialButton, findsOneWidget);
    await tester.tap(dialButton);
    await tester.pumpAndSettle();

    expect(find.text('chat ${w.uid}_p1'), findsOneWidget);
  });
}
